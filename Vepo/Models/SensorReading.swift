import Foundation

/// Raw IMU sensor reading from ESP32 via BLE.
/// Plain struct — not persisted to SwiftData (high frequency, transient).
struct SensorReading: Sendable, Equatable {
    let timestamp: Date
    let accX: Double   // m/s²
    let accY: Double   // m/s²
    let accZ: Double   // m/s²
    let gyroX: Double  // °/s
    let gyroY: Double  // °/s
    let gyroZ: Double  // °/s

    /// Acceleration magnitude: sqrt(ax² + ay² + az²)
    var accelerationMagnitude: Double {
        (accX * accX + accY * accY + accZ * accZ).squareRoot()
    }

    /// Gyroscope magnitude: sqrt(gx² + gy² + gz²)
    var gyroMagnitude: Double {
        (gyroX * gyroX + gyroY * gyroY + gyroZ * gyroZ).squareRoot()
    }
}
