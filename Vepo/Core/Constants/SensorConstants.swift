import Foundation

/// All sensor thresholds for drink detection.
/// Each value includes rationale and units for calibration reference.
enum SensorConstants {

    // MARK: - Lift Detection

    /// Acceleration magnitude spike to detect bottle pickup.
    /// At rest, |a| ≈ 9.81 m/s² (gravity). A lift produces a transient spike.
    /// 12.0 m/s² filters out desk vibrations (~10.0) while catching deliberate lifts.
    static let liftAccelerationThreshold: Double = 12.0  // m/s²

    // MARK: - Tilt / Drinking Detection

    /// Minimum tilt angle to classify as a drinking posture.
    /// Typical drinking tilt is 45°–90° from vertical.
    /// 45° excludes casual tilting (looking at label, adjusting grip).
    static let tiltAngleThreshold: Double = 45.0  // degrees

    /// Minimum duration the tilt must be sustained to count as drinking.
    /// Filters accidental bumps and brief tilts.
    static let tiltDurationMinimum: TimeInterval = 0.5  // seconds

    // MARK: - Resting State (Put Down)

    /// Acceleration magnitude range indicating the bottle is at rest.
    /// Pure gravity ≈ 9.81 m/s², allowing ±1.0 for sensor noise.
    static let restingAccelerationRange: ClosedRange<Double> = 9.0...11.0  // m/s²

    /// Maximum gyroscope magnitude for "at rest" classification.
    /// Below 5 °/s means negligible rotation — bottle is stationary.
    static let restingGyroThreshold: Double = 5.0  // °/s

    // MARK: - Event Timing

    /// Minimum total duration for a valid drink sequence (lift → tilt → return).
    /// Too-fast sequences are likely bumps or accidental knocks.
    static let minEventDuration: TimeInterval = 2.0  // seconds

    /// Maximum total duration for a valid drink sequence.
    /// Beyond 5 seconds likely indicates carrying/walking, not drinking.
    static let maxEventDuration: TimeInterval = 5.0  // seconds

    // MARK: - Signal Processing

    /// Rolling mean window size for noise smoothing.
    /// 0.5s balances responsiveness with noise reduction at typical 50Hz sample rate.
    static let smoothingWindowSize: TimeInterval = 0.5  // seconds

    /// Complementary filter coefficient (α) for tilt estimation.
    /// Higher α = more weight on gyroscope (responsive, drifts).
    /// Lower α = more weight on accelerometer (stable, noisy).
    /// 0.98 is standard for short-duration motion detection.
    static let complementaryFilterAlpha: Double = 0.98

    // MARK: - Shake Rejection

    /// Gyroscope magnitude threshold for rejecting shake/jitter patterns.
    /// Rapid multi-axis rotation above this value indicates shaking, not drinking.
    static let shakeGyroThreshold: Double = 200.0  // °/s
}
