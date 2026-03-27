import Foundation
import Observation
import OSLog

/// Orchestrates drink event detection by processing a stream of SensorReadings
/// through the FSM and signal processing pipeline.
///
/// Confined to @MainActor for thread safety — all state mutations happen on main.
/// Emits detected events via an AsyncStream (multicast-safe).
@MainActor
@Observable
final class DrinkDetector {
    // MARK: - Published State

    private(set) var currentState: DrinkDetectionState = .idle
    private(set) var lastEventTimestamp: Date?

    // MARK: - Event Stream (multicast — multiple consumers can each iterate)

    let drinkEvents: AsyncStream<DrinkEvent>
    private let eventContinuation: AsyncStream<DrinkEvent>.Continuation

    // MARK: - Internal State

    private var fusedTiltAngle: Double = 0.0
    private var lastReadingTimestamp: Date?
    private var liftStartTime: Date?
    private var accelBuffer: [Double] = []
    private var gyroBuffer: [Double] = []
    private let bufferCapacity = 50  // ~1 second at 50Hz

    // MARK: - Init

    nonisolated init() {
        let (stream, continuation) = AsyncStream.makeStream(of: DrinkEvent.self)
        self.drinkEvents = stream
        self.eventContinuation = continuation
    }

    // MARK: - Processing

    /// Process a single sensor reading through the FSM pipeline.
    func process(_ reading: SensorReading) {
        // Reject shake patterns immediately
        if SignalProcessor.isShakePattern(
            gyroX: reading.gyroX,
            gyroY: reading.gyroY,
            gyroZ: reading.gyroZ
        ) {
            resetToIdle()
            return
        }

        // Update signal buffers
        updateBuffers(with: reading)

        // Compute processed signals
        let accMag = reading.accelerationMagnitude
        let gyroMag = reading.gyroMagnitude
        let dt = computeDeltaTime(reading.timestamp)
        let accelTilt = SignalProcessor.tiltAngleFromAccelerometer(
            accX: reading.accX,
            accY: reading.accY,
            accZ: reading.accZ
        )
        fusedTiltAngle = SignalProcessor.complementaryFilter(
            previousAngle: fusedTiltAngle,
            gyroRate: reading.gyroX,  // Primary tilt axis
            accelAngle: accelTilt,
            dt: dt
        )

        lastReadingTimestamp = reading.timestamp

        // FSM transition logic
        transition(
            accMag: accMag,
            gyroMag: gyroMag,
            tiltAngle: fusedTiltAngle,
            timestamp: reading.timestamp
        )
    }

    /// Start consuming an async stream of sensor readings.
    /// Hops each reading to @MainActor for thread-safe processing.
    func startProcessing(_ readings: AsyncStream<SensorReading>) async {
        for await reading in readings {
            process(reading)
        }
    }

    // MARK: - FSM Transitions

    private func transition(
        accMag: Double,
        gyroMag: Double,
        tiltAngle: Double,
        timestamp: Date
    ) {
        switch currentState {
        case .idle:
            if accMag > SensorConstants.liftAccelerationThreshold {
                liftStartTime = timestamp
                currentState = .pickedUp(since: timestamp)
                AppLogger.detection.debug("State: idle → pickedUp")
            }

        case .pickedUp(let since):
            let elapsed = timestamp.timeIntervalSince(since)
            if elapsed > SensorConstants.maxEventDuration {
                resetToIdle()
                return
            }

            if tiltAngle > SensorConstants.tiltAngleThreshold {
                currentState = .tilted(since: timestamp, peakAngle: tiltAngle)
                AppLogger.detection.debug("State: pickedUp → tilted (angle: \(tiltAngle, format: .fixed(precision: 1))°)")
            }

            if SignalProcessor.isResting(accelerationMagnitude: accMag, gyroMagnitude: gyroMag) {
                resetToIdle()
            }

        case .tilted(let since, let peakAngle):
            let updatedPeak = max(peakAngle, tiltAngle)

            if let liftStart = liftStartTime {
                let totalElapsed = timestamp.timeIntervalSince(liftStart)
                if totalElapsed > SensorConstants.maxEventDuration {
                    resetToIdle()
                    return
                }
            }

            let tiltDuration = timestamp.timeIntervalSince(since)

            if SignalProcessor.isResting(accelerationMagnitude: accMag, gyroMagnitude: gyroMag),
               tiltDuration >= SensorConstants.tiltDurationMinimum {
                let totalDuration = liftStartTime.map { timestamp.timeIntervalSince($0) } ?? tiltDuration
                currentState = .putDown(since: timestamp, totalDuration: totalDuration)
                AppLogger.detection.debug("State: tilted → putDown (duration: \(totalDuration, format: .fixed(precision: 1))s, peak: \(updatedPeak, format: .fixed(precision: 1))°)")
                validateAndEmitEvent(totalDuration: totalDuration, timestamp: timestamp)
            } else {
                currentState = .tilted(since: since, peakAngle: updatedPeak)
            }

        case .putDown:
            resetToIdle()
        }
    }

    // MARK: - Event Validation & Emission

    private func validateAndEmitEvent(totalDuration: TimeInterval, timestamp: Date) {
        guard totalDuration >= SensorConstants.minEventDuration,
              totalDuration <= SensorConstants.maxEventDuration else {
            AppLogger.detection.debug("Event rejected: duration \(totalDuration, format: .fixed(precision: 1))s outside valid range")
            resetToIdle()
            return
        }

        let timeSinceLast = lastEventTimestamp.map { timestamp.timeIntervalSince($0) }

        let event = DrinkEvent(
            timestamp: timestamp,
            eventDuration: totalDuration,
            timeSinceLastDrink: timeSinceLast
        )

        lastEventTimestamp = timestamp
        eventContinuation.yield(event)
        AppLogger.detection.info("Drink event detected: duration=\(totalDuration, format: .fixed(precision: 1))s")

        resetToIdle()
    }

    // MARK: - Helpers

    private func resetToIdle() {
        currentState = .idle
        liftStartTime = nil
        fusedTiltAngle = 0.0
        lastReadingTimestamp = nil  // Prevents stale dt on reconnect (MEDIUM-5 fix)
    }

    private func updateBuffers(with reading: SensorReading) {
        accelBuffer.append(reading.accelerationMagnitude)
        gyroBuffer.append(reading.gyroMagnitude)
        if accelBuffer.count > bufferCapacity {
            accelBuffer.removeFirst()
        }
        if gyroBuffer.count > bufferCapacity {
            gyroBuffer.removeFirst()
        }
    }

    private func computeDeltaTime(_ timestamp: Date) -> Double {
        guard let last = lastReadingTimestamp else { return 0.02 }  // Default 50Hz
        return timestamp.timeIntervalSince(last)
    }
}
