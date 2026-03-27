import Testing
import Foundation
@testable import Vepo

@Suite("DrinkDetector FSM")
struct DrinkDetectorTests {

    // MARK: - Helpers

    /// Creates a sensor reading with specified characteristics
    private func makeReading(
        accX: Double = 0, accY: Double = 0, accZ: Double = 9.81,
        gyroX: Double = 0, gyroY: Double = 0, gyroZ: Double = 0,
        at time: Date = .now
    ) -> SensorReading {
        SensorReading(
            timestamp: time,
            accX: accX, accY: accY, accZ: accZ,
            gyroX: gyroX, gyroY: gyroY, gyroZ: gyroZ
        )
    }

    /// Simulates a valid drink sequence: lift → tilt → return
    @MainActor
    private func simulateDrinkSequence(
        detector: DrinkDetector,
        startTime: Date = .now
    ) {
        // Phase 1: Lift (acceleration spike)
        detector.process(makeReading(
            accX: 0, accY: 0, accZ: 15.0,
            at: startTime
        ))

        // Phase 2: Tilt (sustained angle > 45°, gyro indicates rotation)
        // Complementary filter (α=0.98) needs ~47 readings at gyroX=30°/s
        // to converge past the 45° tilt threshold. 50 readings gives margin.
        let tiltComponent = 9.81 / 2.0.squareRoot()
        for i in 1...50 {  // ~1.0 seconds at 50Hz
            detector.process(makeReading(
                accX: tiltComponent, accY: 0, accZ: tiltComponent,
                gyroX: 30, gyroY: 0, gyroZ: 0,
                at: startTime.addingTimeInterval(Double(i) * 0.02)
            ))
        }

        // Phase 3: Return to rest
        detector.process(makeReading(
            accX: 0, accY: 0, accZ: 9.81,
            gyroX: 0, gyroY: 0, gyroZ: 0,
            at: startTime.addingTimeInterval(2.5)
        ))
    }

    // MARK: - Tests

    @Test("Starts in idle state")
    @MainActor
    func initialState() {
        let detector = DrinkDetector()
        #expect(detector.currentState == .idle)
    }

    @Test("Acceleration spike transitions from idle to pickedUp")
    @MainActor
    func idleToPickedUp() {
        let detector = DrinkDetector()

        detector.process(makeReading(accX: 0, accY: 0, accZ: 15.0))

        if case .pickedUp = detector.currentState {
            // correct
        } else {
            Issue.record("Expected .pickedUp, got \(detector.currentState)")
        }
    }

    @Test("Below-threshold motion stays in idle")
    @MainActor
    func belowThresholdStaysIdle() {
        let detector = DrinkDetector()

        // Slight desk vibration — below lift threshold
        detector.process(makeReading(accX: 0.5, accY: 0, accZ: 10.0))

        #expect(detector.currentState == .idle)
    }

    @Test("Valid drink sequence emits event via stream")
    @MainActor
    func validSequenceEmitsEvent() async {
        let detector = DrinkDetector()

        // Collect events from the stream in a background task
        var detectedEvents: [DrinkEvent] = []
        let collectTask = Task { @MainActor in
            for await event in detector.drinkEvents {
                detectedEvents.append(event)
                break  // Only need one
            }
        }

        simulateDrinkSequence(detector: detector)

        // Give the stream a moment to deliver
        try? await Task.sleep(for: .milliseconds(100))
        collectTask.cancel()

        #expect(!detectedEvents.isEmpty)
        if let event = detectedEvents.first {
            #expect(event.eventDuration >= SensorConstants.minEventDuration)
            #expect(event.eventDuration <= SensorConstants.maxEventDuration)
        }
    }

    @Test("Shake pattern resets to idle")
    @MainActor
    func shakeResetsToIdle() {
        let detector = DrinkDetector()

        // Start a lift
        detector.process(makeReading(accX: 0, accY: 0, accZ: 15.0))

        // Then shake
        detector.process(makeReading(
            accX: 5, accY: 5, accZ: 5,
            gyroX: 200, gyroY: 200, gyroZ: 100
        ))

        #expect(detector.currentState == .idle)
    }

    @Test("Sequence exceeding max duration does not emit event")
    @MainActor
    func tooLongSequenceRejected() async {
        let detector = DrinkDetector()

        var detectedEvents: [DrinkEvent] = []
        let collectTask = Task { @MainActor in
            for await event in detector.drinkEvents {
                detectedEvents.append(event)
            }
        }

        let startTime = Date.now

        // Lift
        detector.process(makeReading(
            accX: 0, accY: 0, accZ: 15.0,
            at: startTime
        ))

        // Hold tilted for too long (> 5 seconds)
        let tiltComponent = 9.81 / 2.0.squareRoot()
        for i in 1...300 {  // 6 seconds at 50Hz
            detector.process(makeReading(
                accX: tiltComponent, accY: 0, accZ: tiltComponent,
                gyroX: 30, gyroY: 0, gyroZ: 0,
                at: startTime.addingTimeInterval(Double(i) * 0.02)
            ))
        }

        // Return
        detector.process(makeReading(
            accX: 0, accY: 0, accZ: 9.81,
            at: startTime.addingTimeInterval(7.0)
        ))

        try? await Task.sleep(for: .milliseconds(100))
        collectTask.cancel()

        #expect(detectedEvents.isEmpty)
    }

    @Test("Returning to rest without tilt resets to idle")
    @MainActor
    func pickUpWithoutTiltResetsToIdle() {
        let detector = DrinkDetector()
        let startTime = Date.now

        // Lift
        detector.process(makeReading(
            accX: 0, accY: 0, accZ: 15.0,
            at: startTime
        ))

        // Immediately return to rest (no tilt)
        detector.process(makeReading(
            accX: 0, accY: 0, accZ: 9.81,
            gyroX: 0, gyroY: 0, gyroZ: 0,
            at: startTime.addingTimeInterval(0.5)
        ))

        #expect(detector.currentState == .idle)
    }
}
