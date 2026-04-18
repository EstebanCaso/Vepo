import CoreBluetooth

/// BLE service and characteristic UUIDs for ESP32 communication.
///
/// These must match the firmware-side GATT configuration AND be included
/// in the ESP32's advertising packet (iOS scans by *advertised* UUIDs, not
/// just by what's exposed in the GATT database).
///
/// To find the real values for your bottle: power it on, open the in-app
/// "BLE Diagnostics" sheet, tap your device, and copy the Service /
/// Characteristic UUIDs that appear under "Discovered services".
enum BLEConstants {
    // Nordic UART Service (NUS) — used by the Vepo ESP32 firmware.
    // Service exposes a notify characteristic (TX, server -> client) for the
    // sensor data stream and a write characteristic (RX) for host commands.
    static let serviceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    /// NUS TX characteristic — notifies sensor packets to the iOS app.
    static let sensorCharacteristicUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")

    /// Expected byte length of a single sensor packet:
    /// 6 floats (4 bytes each) + 1 UInt32 timestamp = 28 bytes
    static let expectedPacketSize = 28

    /// Scan timeout before stopping (seconds)
    static let scanTimeout: TimeInterval = 30

    /// Auto-reconnect base delay (seconds), doubles on each retry
    static let reconnectBaseDelay: TimeInterval = 1.0

    /// Maximum reconnect attempts before giving up
    static let maxReconnectAttempts = 5

    /// Device name prefix used to flag Vepo-candidate peripherals during scan.
    static let deviceNamePrefix = "Vepo"
}
