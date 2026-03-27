import Foundation

/// Pure signal processing functions for IMU data.
/// Stateless — all state (buffers) is managed by the caller.
enum SignalProcessor {

    // MARK: - Magnitude Calculations

    /// Euclidean magnitude of a 3-axis vector.
    static func magnitude(x: Double, y: Double, z: Double) -> Double {
        (x * x + y * y + z * z).squareRoot()
    }

    // MARK: - Rolling Mean Smoothing

    /// Computes the rolling mean of the most recent values in a buffer.
    /// - Parameters:
    ///   - buffer: Array of recent values (newest last)
    ///   - windowSize: Number of samples to average
    /// - Returns: Mean of the last `windowSize` values, or all values if buffer is smaller
    static func rollingMean(buffer: [Double], windowSize: Int) -> Double {
        guard !buffer.isEmpty else { return 0.0 }
        let window = buffer.suffix(max(1, windowSize))
        return window.reduce(0.0, +) / Double(window.count)
    }

    // MARK: - Tilt Angle Estimation

    /// Estimates tilt angle from accelerometer data using atan2.
    /// Returns the angle between the bottle's z-axis and the gravity vector.
    /// 0° = upright, 90° = horizontal, 180° = inverted.
    ///
    /// - Parameters:
    ///   - accX: X-axis acceleration (m/s²)
    ///   - accY: Y-axis acceleration (m/s²)
    ///   - accZ: Z-axis acceleration (m/s²)
    /// - Returns: Tilt angle in degrees (0–180)
    static func tiltAngleFromAccelerometer(
        accX: Double,
        accY: Double,
        accZ: Double
    ) -> Double {
        let mag = magnitude(x: accX, y: accY, z: accZ)
        guard mag > 0.01 else { return 0.0 }

        // Angle between z-axis and gravity vector
        let cosAngle = accZ / mag
        let clampedCos = min(max(cosAngle, -1.0), 1.0)
        return acos(clampedCos) * (180.0 / .pi)
    }

    // MARK: - Complementary Filter

    /// Fuses accelerometer and gyroscope tilt estimates.
    /// Gyroscope is responsive but drifts; accelerometer is stable but noisy.
    ///
    /// - Parameters:
    ///   - previousAngle: Last fused angle estimate (degrees)
    ///   - gyroRate: Current gyroscope angular rate on tilt axis (°/s)
    ///   - accelAngle: Current accelerometer-derived angle (degrees)
    ///   - dt: Time delta since last sample (seconds)
    ///   - alpha: Filter coefficient (0–1). Higher = more gyro weight.
    /// - Returns: Fused tilt angle estimate (degrees)
    static func complementaryFilter(
        previousAngle: Double,
        gyroRate: Double,
        accelAngle: Double,
        dt: Double,
        alpha: Double = SensorConstants.complementaryFilterAlpha
    ) -> Double {
        alpha * (previousAngle + gyroRate * dt) + (1.0 - alpha) * accelAngle
    }

    // MARK: - Pattern Detection

    /// Detects if current motion is a shake pattern (high multi-axis gyro).
    static func isShakePattern(gyroX: Double, gyroY: Double, gyroZ: Double) -> Bool {
        magnitude(x: gyroX, y: gyroY, z: gyroZ) > SensorConstants.shakeGyroThreshold
    }

    /// Checks if acceleration magnitude is within the resting range.
    static func isResting(accelerationMagnitude: Double, gyroMagnitude: Double) -> Bool {
        SensorConstants.restingAccelerationRange.contains(accelerationMagnitude)
            && gyroMagnitude < SensorConstants.restingGyroThreshold
    }
}
