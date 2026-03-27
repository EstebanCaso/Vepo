import Testing
import Foundation
@testable import Vepo

/// End-to-end integration tests: raw BLE bytes → SensorPacketParser → DrinkDetector → DrinkEvent.
/// Verifies the full pipeline works as a connected chain, not just individual units.
@Suite("Pipeline Integration")
struct IntegrationTests {

    // MARK: - Helpers

    /// Creates a realistic 28-byte BLE packet from sensor values.
    private func makePacket(
        accX: Float, accY: Float, accZ: Float,
        gyroX: Float, gyroY: Float, gyroZ: Float,
        timestampMs: UInt32 = 1000
    ) -> Data {
        var data = Data(capacity: 28)
        withUnsafeBytes(of: accX) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: accY) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: accZ) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: gyroX) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: gyroY) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: gyroZ) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: timestampMs) { data.append(contentsOf: $0) }
        return data
    }

    // MARK: - Tests

    @Test("Raw bytes → SensorPacketParser → DrinkDetector → DrinkEvent")
    @MainActor
    func fullPipelineBytesToEvent() async throws {
        let detector = DrinkDetector()

        var detectedEvents: [DrinkEvent] = []
        let collectTask = Task { @MainActor in
            for await event in detector.drinkEvents {
                detectedEvents.append(event)
                break
            }
        }

        let startTime = Date.now

        // Phase 1: Lift — raw bytes for an acceleration spike
        let liftPacket = makePacket(accX: 0, accY: 0, accZ: 15.0, gyroX: 0, gyroY: 0, gyroZ: 0)
        let liftReading = try SensorPacketParser.parse(liftPacket)
        #expect(liftReading.accZ > 14.0, "Parser should preserve accZ value")

        let liftInput = SensorReading(
            timestamp: startTime,
            accX: liftReading.accX, accY: liftReading.accY, accZ: liftReading.accZ,
            gyroX: liftReading.gyroX, gyroY: liftReading.gyroY, gyroZ: liftReading.gyroZ
        )
        detector.process(liftInput)

        // Phase 2: Tilt — 50 readings at 50Hz with realistic noise
        let tiltAngleRad: Float = 60.0 * (.pi / 180.0)
        let accXTilt = 9.81 * sin(tiltAngleRad)
        let accZTilt = 9.81 * cos(tiltAngleRad)

        for i in 1...50 {
            let noise = Float.random(in: -0.3...0.3)
            let packet = makePacket(
                accX: accXTilt + noise, accY: noise, accZ: accZTilt + noise,
                gyroX: 30.0 + Float.random(in: -3...3),
                gyroY: Float.random(in: -2...2),
                gyroZ: Float.random(in: -2...2),
                timestampMs: UInt32(i * 20)
            )
            let reading = try SensorPacketParser.parse(packet)
            let timedReading = SensorReading(
                timestamp: startTime.addingTimeInterval(Double(i) * 0.02),
                accX: reading.accX, accY: reading.accY, accZ: reading.accZ,
                gyroX: reading.gyroX, gyroY: reading.gyroY, gyroZ: reading.gyroZ
            )
            detector.process(timedReading)
        }

        // Phase 3: Return to rest — parsed from raw bytes
        let restPacket = makePacket(accX: 0, accY: 0, accZ: 9.81, gyroX: 0, gyroY: 0, gyroZ: 0)
        let restReading = try SensorPacketParser.parse(restPacket)
        let restInput = SensorReading(
            timestamp: startTime.addingTimeInterval(2.5),
            accX: restReading.accX, accY: restReading.accY, accZ: restReading.accZ,
            gyroX: restReading.gyroX, gyroY: restReading.gyroY, gyroZ: restReading.gyroZ
        )
        detector.process(restInput)

        try? await Task.sleep(for: .milliseconds(100))
        collectTask.cancel()

        #expect(!detectedEvents.isEmpty, "Pipeline should emit a DrinkEvent from raw bytes")
        if let event = detectedEvents.first {
            #expect(event.eventDuration >= SensorConstants.minEventDuration)
            #expect(event.eventDuration <= SensorConstants.maxEventDuration)
        }
    }

    @Test("Parser rejects corrupt packet, detector continues unaffected")
    @MainActor
    func corruptPacketDoesNotBreakDetector() throws {
        let detector = DrinkDetector()

        // Feed a valid lift reading
        let validPacket = makePacket(accX: 0, accY: 0, accZ: 15.0, gyroX: 0, gyroY: 0, gyroZ: 0)
        let reading = try SensorPacketParser.parse(validPacket)
        let timedReading = SensorReading(
            timestamp: .now,
            accX: reading.accX, accY: reading.accY, accZ: reading.accZ,
            gyroX: reading.gyroX, gyroY: reading.gyroY, gyroZ: reading.gyroZ
        )
        detector.process(timedReading)

        // Corrupt packet should throw — detector not involved
        let corruptData = Data([0x00, 0x01, 0x02])
        #expect(throws: SensorPacketParser.ParseError.self) {
            _ = try SensorPacketParser.parse(corruptData)
        }

        // Detector should still be in pickedUp state (not crashed/reset)
        if case .pickedUp = detector.currentState {
            // correct — still in pickedUp after corrupt packet was rejected by parser
        } else {
            Issue.record("Expected .pickedUp, got \(detector.currentState)")
        }
    }

    @Test("Noisy realistic sensor data produces valid event")
    @MainActor
    func noisyRealisticDataProducesEvent() async {
        let detector = DrinkDetector()

        var detectedEvents: [DrinkEvent] = []
        let collectTask = Task { @MainActor in
            for await event in detector.drinkEvents {
                detectedEvents.append(event)
                break
            }
        }

        let startTime = Date.now

        // Lift with noise (realistic ESP32 output)
        for i in 0..<10 {
            let liftIntensity = sin(Double(i) / 10.0 * .pi)
            detector.process(SensorReading(
                timestamp: startTime.addingTimeInterval(Double(i) * 0.02),
                accX: Double.random(in: -0.5...0.5),
                accY: Double.random(in: -0.5...0.5),
                accZ: 9.81 + 5.0 * liftIntensity + Double.random(in: -0.3...0.3),
                gyroX: 20.0 * liftIntensity + Double.random(in: -2...2),
                gyroY: Double.random(in: -2...2),
                gyroZ: Double.random(in: -2...2)
            ))
        }

        // Tilt at ~60° with gyro noise (1.5 seconds = 75 readings)
        // Sustained ~15°/s rotation is realistic for holding a bottle tilted
        let tiltAngleRad = 60.0 * (.pi / 180.0)
        for i in 10..<85 {
            detector.process(SensorReading(
                timestamp: startTime.addingTimeInterval(Double(i) * 0.02),
                accX: 9.81 * sin(tiltAngleRad) + Double.random(in: -0.4...0.4),
                accY: Double.random(in: -0.3...0.3),
                accZ: 9.81 * cos(tiltAngleRad) + Double.random(in: -0.4...0.4),
                gyroX: 15.0 + Double.random(in: -3...3),
                gyroY: Double.random(in: -2...2),
                gyroZ: Double.random(in: -2...2)
            ))
        }

        // Return to rest over 0.5s (25 readings)
        for i in 85..<110 {
            let returnProgress = Double(i - 85) / 25.0
            let remainingTilt = (1.0 - returnProgress) * tiltAngleRad
            detector.process(SensorReading(
                timestamp: startTime.addingTimeInterval(Double(i) * 0.02),
                accX: 9.81 * sin(remainingTilt) + Double.random(in: -0.3...0.3),
                accY: Double.random(in: -0.3...0.3),
                accZ: 9.81 * cos(remainingTilt) + Double.random(in: -0.2...0.2),
                gyroX: -15.0 * (1.0 - returnProgress) + Double.random(in: -2...2),
                gyroY: Double.random(in: -1.5...1.5),
                gyroZ: Double.random(in: -1.5...1.5)
            ))
        }

        // Final resting readings
        for i in 110..<115 {
            detector.process(SensorReading(
                timestamp: startTime.addingTimeInterval(Double(i) * 0.02),
                accX: Double.random(in: -0.3...0.3),
                accY: Double.random(in: -0.3...0.3),
                accZ: 9.81 + Double.random(in: -0.2...0.2),
                gyroX: Double.random(in: -1.5...1.5),
                gyroY: Double.random(in: -1.5...1.5),
                gyroZ: Double.random(in: -1.5...1.5)
            ))
        }

        try? await Task.sleep(for: .milliseconds(100))
        collectTask.cancel()

        #expect(!detectedEvents.isEmpty, "Noisy realistic data should still produce a drink event")
    }
}
