import CoreBluetooth

/// BLE service and characteristic UUIDs for ESP32 communication.
/// These must match the firmware-side GATT configuration.
enum BLEConstants {
    /// GATT service UUID advertised by the ESP32 bottle
    static let serviceUUID = CBUUID(string: "12345678-1234-1234-1234-123456789ABC")

    /// Notify characteristic for IMU sensor data stream
    static let sensorCharacteristicUUID = CBUUID(string: "12345678-1234-1234-1234-123456789ABD")

    /// Expected byte length of a single sensor packet:
    /// 6 floats (4 bytes each) + 1 UInt32 timestamp = 28 bytes
    static let expectedPacketSize = 28

    /// Scan timeout before stopping (seconds)
    static let scanTimeout: TimeInterval = 30

    /// Auto-reconnect base delay (seconds), doubles on each retry
    static let reconnectBaseDelay: TimeInterval = 1.0

    /// Maximum reconnect attempts before giving up
    static let maxReconnectAttempts = 5

    /// Device name prefix to filter during scanning
    static let deviceNamePrefix = "Vepo"
}
