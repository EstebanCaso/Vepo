import Foundation

/// Parses raw BLE data packets into SensorReading structs.
///
/// Expected packet format (28 bytes, little-endian):
/// - Bytes  0-3:  acc_x  (Float32)
/// - Bytes  4-7:  acc_y  (Float32)
/// - Bytes  8-11: acc_z  (Float32)
/// - Bytes 12-15: gyro_x (Float32)
/// - Bytes 16-19: gyro_y (Float32)
/// - Bytes 20-23: gyro_z (Float32)
/// - Bytes 24-27: timestamp_ms (UInt32) — milliseconds since ESP32 boot
enum SensorPacketParser {

    enum ParseError: Error, Sendable {
        case invalidLength(expected: Int, actual: Int)
        case invalidData
    }

    /// Parse a raw Data packet into a SensorReading.
    /// - Parameter data: Raw bytes from BLE characteristic
    /// - Returns: Parsed SensorReading with current Date as timestamp
    static func parse(_ data: Data) throws -> SensorReading {
        guard data.count == BLEConstants.expectedPacketSize else {
            throw ParseError.invalidLength(
                expected: BLEConstants.expectedPacketSize,
                actual: data.count
            )
        }

        let accX = readFloat(from: data, offset: 0)
        let accY = readFloat(from: data, offset: 4)
        let accZ = readFloat(from: data, offset: 8)
        let gyroX = readFloat(from: data, offset: 12)
        let gyroY = readFloat(from: data, offset: 16)
        let gyroZ = readFloat(from: data, offset: 20)

        guard accX.isFinite, accY.isFinite, accZ.isFinite,
              gyroX.isFinite, gyroY.isFinite, gyroZ.isFinite else {
            throw ParseError.invalidData
        }

        return SensorReading(
            timestamp: .now,
            accX: Double(accX),
            accY: Double(accY),
            accZ: Double(accZ),
            gyroX: Double(gyroX),
            gyroY: Double(gyroY),
            gyroZ: Double(gyroZ)
        )
    }

    /// Reads a little-endian Float32 from Data at the given byte offset.
    private static func readFloat(from data: Data, offset: Int) -> Float {
        data.withUnsafeBytes { buffer in
            buffer.loadUnaligned(fromByteOffset: offset, as: Float.self)
        }
    }
}
