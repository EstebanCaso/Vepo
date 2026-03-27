import Foundation

/// Finite state machine states for drink event detection.
/// Each state carries associated data needed for transition decisions.
enum DrinkDetectionState: Sendable, Equatable {
    /// Bottle is stationary — waiting for motion
    case idle

    /// Bottle has been lifted (acceleration spike detected)
    /// - Parameter since: Timestamp when lift was first detected
    case pickedUp(since: Date)

    /// Bottle is tilted at a drinking angle
    /// - Parameters:
    ///   - since: Timestamp when tilt was first detected
    ///   - peakAngle: Maximum tilt angle observed during this phase
    case tilted(since: Date, peakAngle: Double)

    /// Bottle has been returned to rest — event complete, pending validation
    /// - Parameters:
    ///   - since: Timestamp when return was detected
    ///   - totalDuration: Duration from initial lift to put-down
    case putDown(since: Date, totalDuration: TimeInterval)

    var displayName: String {
        switch self {
        case .idle: "Idle"
        case .pickedUp: "Picked Up"
        case .tilted: "Drinking"
        case .putDown: "Put Down"
        }
    }
}
