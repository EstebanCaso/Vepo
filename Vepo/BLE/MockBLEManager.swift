import CoreBluetooth
import Foundation
import Observation
import OSLog

/// Mock BLE manager that generates simulated sensor data.
/// Use this to test the full UI pipeline without a physical ESP32 bottle.
///
/// Simulates:
/// - Connection state transitions
/// - Periodic resting readings (gravity only)
/// - Drink events at configurable intervals
/// - Random noise for realistic sensor behavior
@Observable
final class MockBLEManager: @unchecked Sendable {
    // MARK: - Published State

    private(set) var connectionState: BLEConnectionState = .idle
    private(set) var discoveredPeripherals: [CBPeripheral] = []

    // MARK: - Configuration

    /// How often to simulate a drink event (seconds)
    var drinkEventInterval: TimeInterval = 45

    /// Sensor sample rate (Hz)
    var sampleRate: Double = 50

    /// Whether the mock is actively generating data
    private(set) var isSimulating = false

    // MARK: - Stream

    let sensorReadings: AsyncStream<SensorReading>
    private var sensorContinuation: AsyncStream<SensorReading>.Continuation?
    private var simulationTask: Task<Void, Never>?
    private var lastDrinkTime: Date = .now

    init() {
        var storedContinuation: AsyncStream<SensorReading>.Continuation?
        sensorReadings = AsyncStream { continuation in
            storedContinuation = continuation
        }
        sensorContinuation = storedContinuation
    }

    // MARK: - Simulated Actions

    func startScanning() async {
        connectionState = .scanning
        AppLogger.ble.info("[Mock] Scanning...")

        // Simulate scan delay
        try? await Task.sleep(for: .seconds(1.5))
        connectionState = .idle
        AppLogger.ble.info("[Mock] Scan complete — use connect() to simulate connection")
    }

    func stopScanning() {
        connectionState = .idle
    }

    /// Simulates connecting and starts the sensor data stream
    func simulateConnect() async {
        connectionState = .connecting
        AppLogger.ble.info("[Mock] Connecting...")

        try? await Task.sleep(for: .seconds(0.8))
        connectionState = .discoveringServices

        try? await Task.sleep(for: .seconds(0.5))
        connectionState = .connected
        AppLogger.ble.info("[Mock] Connected — starting sensor simulation")

        startSimulation()
    }

    func disconnect() {
        stopSimulation()
        connectionState = .disconnected(reason: "User disconnected")
    }

    // MARK: - Simulation Engine

    private func startSimulation() {
        guard !isSimulating else { return }
        isSimulating = true
        lastDrinkTime = .now

        simulationTask = Task { [weak self] in
            guard let self else { return }
            let interval = 1.0 / sampleRate

            while !Task.isCancelled {
                let now = Date.now
                let timeSinceDrink = now.timeIntervalSince(lastDrinkTime)

                let reading: SensorReading

                if timeSinceDrink >= drinkEventInterval,
                   timeSinceDrink < drinkEventInterval + 3.0 {
                    // Simulate a drink event over ~3 seconds
                    let phase = timeSinceDrink - drinkEventInterval
                    reading = simulateDrinkPhase(phase: phase, timestamp: now)

                    if phase >= 2.8 {
                        lastDrinkTime = now
                    }
                } else {
                    // Normal resting state with noise
                    reading = simulateResting(timestamp: now)
                }

                sensorContinuation?.yield(reading)
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    private func stopSimulation() {
        simulationTask?.cancel()
        simulationTask = nil
        isSimulating = false
    }

    // MARK: - Simulated Readings

    /// Resting state: gravity on z-axis + small random noise
    private func simulateResting(timestamp: Date) -> SensorReading {
        SensorReading(
            timestamp: timestamp,
            accX: gaussianNoise(stddev: 0.3),
            accY: gaussianNoise(stddev: 0.3),
            accZ: 9.81 + gaussianNoise(stddev: 0.2),
            gyroX: gaussianNoise(stddev: 1.5),
            gyroY: gaussianNoise(stddev: 1.5),
            gyroZ: gaussianNoise(stddev: 1.5)
        )
    }

    /// Simulates a drink motion sequence:
    /// Phase 0.0–0.5s: Lift (acceleration spike)
    /// Phase 0.5–2.0s: Tilt (sustained angle, gyro rotation)
    /// Phase 2.0–3.0s: Return (back to resting)
    private func simulateDrinkPhase(phase: Double, timestamp: Date) -> SensorReading {
        if phase < 0.5 {
            // Lift phase: upward acceleration spike
            let liftIntensity = sin(phase / 0.5 * .pi) // Peaks at 0.25s
            return SensorReading(
                timestamp: timestamp,
                accX: gaussianNoise(stddev: 0.5),
                accY: gaussianNoise(stddev: 0.5),
                accZ: 9.81 + 5.0 * liftIntensity + gaussianNoise(stddev: 0.3),
                gyroX: 20.0 * liftIntensity + gaussianNoise(stddev: 2.0),
                gyroY: gaussianNoise(stddev: 2.0),
                gyroZ: gaussianNoise(stddev: 2.0)
            )
        } else if phase < 2.0 {
            // Tilt phase: bottle tilted ~60° on x-axis
            let tiltAngleRad = 60.0 * (.pi / 180.0)
            let accX = 9.81 * sin(tiltAngleRad) + gaussianNoise(stddev: 0.4)
            let accZ = 9.81 * cos(tiltAngleRad) + gaussianNoise(stddev: 0.4)
            return SensorReading(
                timestamp: timestamp,
                accX: accX,
                accY: gaussianNoise(stddev: 0.3),
                accZ: accZ,
                gyroX: 5.0 + gaussianNoise(stddev: 3.0),  // Slow sustained rotation
                gyroY: gaussianNoise(stddev: 2.0),
                gyroZ: gaussianNoise(stddev: 2.0)
            )
        } else {
            // Return phase: tilting back upright
            let returnProgress = (phase - 2.0) / 1.0  // 0→1 over 1 second
            let remainingTilt = (1.0 - returnProgress) * 60.0 * (.pi / 180.0)
            return SensorReading(
                timestamp: timestamp,
                accX: 9.81 * sin(remainingTilt) + gaussianNoise(stddev: 0.3),
                accY: gaussianNoise(stddev: 0.3),
                accZ: 9.81 * cos(remainingTilt) + gaussianNoise(stddev: 0.2),
                gyroX: -15.0 * (1.0 - returnProgress) + gaussianNoise(stddev: 2.0),
                gyroY: gaussianNoise(stddev: 1.5),
                gyroZ: gaussianNoise(stddev: 1.5)
            )
        }
    }

    // MARK: - Noise Generator

    /// Box-Muller transform for Gaussian noise
    private func gaussianNoise(mean: Double = 0, stddev: Double) -> Double {
        let u1 = Double.random(in: 0.001...1.0)
        let u2 = Double.random(in: 0.001...1.0)
        let z = (-2.0 * log(u1)).squareRoot() * cos(2.0 * .pi * u2)
        return mean + z * stddev
    }
}
