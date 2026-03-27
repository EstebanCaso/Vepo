import Testing
@testable import Vepo

@Suite("SignalProcessor")
struct SignalProcessorTests {

    // MARK: - Magnitude

    @Test("Acceleration magnitude for gravity-only reading")
    func magnitudeAtRest() {
        let mag = SignalProcessor.magnitude(x: 0, y: 0, z: 9.81)
        #expect(abs(mag - 9.81) < 0.01)
    }

    @Test("Magnitude of zero vector")
    func magnitudeZero() {
        let mag = SignalProcessor.magnitude(x: 0, y: 0, z: 0)
        #expect(mag == 0.0)
    }

    @Test("Magnitude with multi-axis values")
    func magnitudeMultiAxis() {
        // 3-4-5 triangle scaled: sqrt(3² + 4² + 0²) = 5
        let mag = SignalProcessor.magnitude(x: 3, y: 4, z: 0)
        #expect(abs(mag - 5.0) < 0.001)
    }

    // MARK: - Rolling Mean

    @Test("Rolling mean of empty buffer returns zero")
    func rollingMeanEmpty() {
        let result = SignalProcessor.rollingMean(buffer: [], windowSize: 5)
        #expect(result == 0.0)
    }

    @Test("Rolling mean with full window")
    func rollingMeanFull() {
        let buffer = [1.0, 2.0, 3.0, 4.0, 5.0]
        let result = SignalProcessor.rollingMean(buffer: buffer, windowSize: 5)
        #expect(abs(result - 3.0) < 0.001)
    }

    @Test("Rolling mean with partial window")
    func rollingMeanPartial() {
        let buffer = [10.0, 20.0, 30.0]
        // Window of 2: average of last 2 = (20 + 30) / 2 = 25
        let result = SignalProcessor.rollingMean(buffer: buffer, windowSize: 2)
        #expect(abs(result - 25.0) < 0.001)
    }

    // MARK: - Tilt Angle

    @Test("Tilt angle when upright (z pointing up) is ~0 degrees")
    func tiltUpright() {
        let angle = SignalProcessor.tiltAngleFromAccelerometer(
            accX: 0, accY: 0, accZ: 9.81
        )
        #expect(angle < 5.0)
    }

    @Test("Tilt angle when horizontal is ~90 degrees")
    func tiltHorizontal() {
        let angle = SignalProcessor.tiltAngleFromAccelerometer(
            accX: 9.81, accY: 0, accZ: 0
        )
        #expect(abs(angle - 90.0) < 5.0)
    }

    @Test("Tilt angle when inverted is ~180 degrees")
    func tiltInverted() {
        let angle = SignalProcessor.tiltAngleFromAccelerometer(
            accX: 0, accY: 0, accZ: -9.81
        )
        #expect(abs(angle - 180.0) < 5.0)
    }

    @Test("Tilt angle at ~45 degrees")
    func tilt45Degrees() {
        // At 45°, x and z components are roughly equal
        let component = 9.81 / 2.0.squareRoot()
        let angle = SignalProcessor.tiltAngleFromAccelerometer(
            accX: component, accY: 0, accZ: component
        )
        #expect(abs(angle - 45.0) < 2.0)
    }

    // MARK: - Complementary Filter

    @Test("Complementary filter with zero gyro rate preserves accel angle")
    func complementaryFilterZeroGyro() {
        let result = SignalProcessor.complementaryFilter(
            previousAngle: 0,
            gyroRate: 0,
            accelAngle: 45.0,
            dt: 0.02,
            alpha: 0.98
        )
        // With zero gyro: 0.98 * (0 + 0) + 0.02 * 45 = 0.9
        #expect(abs(result - 0.9) < 0.01)
    }

    @Test("Complementary filter converges toward accel angle over time")
    func complementaryFilterConvergence() {
        var angle = 0.0
        let targetAngle = 45.0
        // Simulate 100 samples with no gyro rotation
        for _ in 0..<100 {
            angle = SignalProcessor.complementaryFilter(
                previousAngle: angle,
                gyroRate: 0,
                accelAngle: targetAngle,
                dt: 0.02,
                alpha: 0.98
            )
        }
        // After 100 iterations, should approach target
        #expect(abs(angle - targetAngle) < 20.0)
    }

    // MARK: - Pattern Detection

    @Test("Normal motion is not classified as shake")
    func normalMotionNotShake() {
        let isShake = SignalProcessor.isShakePattern(
            gyroX: 10, gyroY: 10, gyroZ: 10
        )
        #expect(!isShake)
    }

    @Test("High multi-axis gyro is classified as shake")
    func highGyroIsShake() {
        let isShake = SignalProcessor.isShakePattern(
            gyroX: 150, gyroY: 150, gyroZ: 100
        )
        #expect(isShake)
    }

    @Test("Resting state detection — stationary bottle")
    func restingDetection() {
        let isResting = SignalProcessor.isResting(
            accelerationMagnitude: 9.81,
            gyroMagnitude: 1.0
        )
        #expect(isResting)
    }

    @Test("Moving bottle is not resting")
    func movingNotResting() {
        let isResting = SignalProcessor.isResting(
            accelerationMagnitude: 15.0,
            gyroMagnitude: 50.0
        )
        #expect(!isResting)
    }
}
