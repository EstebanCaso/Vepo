import Foundation
import OSLog

/// Orchestrates drink event detection by processing a stream of SensorReadings
/// through the FSM and signal processing pipeline.
@Observable
final class DrinkDetector: @unchecked Sendable {
    // MARK: - Published State

    private(set) var currentState: DrinkDetectionState = .idle
    private(set) var lastEventTimestamp: Date?

    // MARK: - Event Callback

    /// Called when a valid drink event is detected.
    var onDrinkDetected: ((DrinkEvent) -> Void)?

    // MARK: - Internal State

    private var fusedTiltAngle: Double = 0.0
    private var lastReadingTimestamp: Date?
    private var liftStartTime: Date?
    private var accelBuffer: [Double] = []
    private var gyroBuffer: [Double] = []
    private let bufferCapacity = 50  // ~1 second at 50Hz

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
            // Idle → PickedUp: acceleration spike above threshold
            if accMag > SensorConstants.liftAccelerationThreshold {
                liftStartTime = timestamp
                currentState = .pickedUp(since: timestamp)
                AppLogger.detection.debug("State: idle → pickedUp")
            }

        case .pickedUp(let since):
            // Check timeout — if too long in pickedUp without tilt, reset
            let elapsed = timestamp.timeIntervalSince(since)
            if elapsed > SensorConstants.maxEventDuration {
                resetToIdle()
                return
            }

            // PickedUp → Tilted: tilt angle exceeds drinking threshold
            if tiltAngle > SensorConstants.tiltAngleThreshold {
                currentState = .tilted(since: timestamp, peakAngle: tiltAngle)
                AppLogger.detection.debug("State: pickedUp → tilted (angle: \(tiltAngle, format: .fixed(precision: 1))°)")
            }

            // PickedUp → Idle: returned to rest without tilting
            if SignalProcessor.isResting(accelerationMagnitude: accMag, gyroMagnitude: gyroMag) {
                resetToIdle()
            }

        case .tilted(let since, let peakAngle):
            // Track peak angle
            let updatedPeak = max(peakAngle, tiltAngle)

            // Check total elapsed time from lift start
            if let liftStart = liftStartTime {
                let totalElapsed = timestamp.timeIntervalSince(liftStart)
                if totalElapsed > SensorConstants.maxEventDuration {
                    resetToIdle()
                    return
                }
            }

            // Check minimum tilt duration
            let tiltDuration = timestamp.timeIntervalSince(since)

            // Tilted → PutDown: returned to resting position after sufficient tilt
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
            // PutDown → Idle: always transition back after event processing
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
        onDrinkDetected?(event)
        AppLogger.detection.info("Drink event detected: duration=\(totalDuration, format: .fixed(precision: 1))s")

        resetToIdle()
    }

    // MARK: - Helpers

    private func resetToIdle() {
        currentState = .idle
        liftStartTime = nil
        fusedTiltAngle = 0.0
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
