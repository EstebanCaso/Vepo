import Foundation
import OSLog

/// Parses raw BLE data packets into SensorReading structs.
///
/// The Vepo ESP32 firmware uses Nordic UART Service (NUS) — a serial-over-BLE
/// transport — and sends IMU data as ASCII text (typically CSV like
/// "ax,ay,az,gx,gy,gz\n" or with a leading timestamp). Packet length therefore
/// varies with number precision (~32–48 bytes), not the fixed 28-byte binary
/// struct originally assumed.
///
/// Parsing strategy:
/// 1. Try ASCII: pull every signed decimal number out of the string and use
///    the first 6 as accX, accY, accZ, gyroX, gyroY, gyroZ.
/// 2. Auto-convert g → m/s² when the resting magnitude looks like g-units
///    (most IMUs report acceleration in g's by default).
/// 3. Fall back to the legacy 28-byte little-endian binary layout for any
///    firmware that emits it.
enum SensorPacketParser {

    enum ParseError: Error, Sendable {
        case invalidLength(expected: Int, actual: Int)
        case invalidData
    }

    /// Acceleration magnitude below this threshold (m/s²) is interpreted as
    /// g-units and rescaled. At rest a real m/s² reading is ~9.81; a g reading
    /// is ~1.0, so 3.0 cleanly separates the two without false positives.
    private static let gUnitsThreshold: Double = 3.0
    private static let gToMetersPerSecondSquared: Double = 9.80665

    /// Logged at most once per distinct raw-packet length so we can inspect
    /// unfamiliar firmware output without flooding the console.
    nonisolated(unsafe) private static var loggedLengths: Set<Int> = []
    private static let logQueue = DispatchQueue(label: "com.vepo.parser.log")

    /// Parse a raw Data packet into a SensorReading.
    static func parse(_ data: Data) throws -> SensorReading {
        logFirstSampleOfLength(data)

        if let reading = parseASCII(data) {
            return reading
        }

        if data.count == BLEConstants.expectedPacketSize {
            return try parseBinary(data)
        }

        throw ParseError.invalidLength(
            expected: BLEConstants.expectedPacketSize,
            actual: data.count
        )
    }

    // MARK: - ASCII (CSV) path

    private static func parseASCII(_ data: Data) -> SensorReading? {
        guard let raw = String(data: data, encoding: .utf8) else { return nil }
        let numbers = extractNumbers(from: raw)
        guard numbers.count >= 6 else { return nil }

        var accX = numbers[0]
        var accY = numbers[1]
        var accZ = numbers[2]
        let gyroX = numbers[3]
        let gyroY = numbers[4]
        let gyroZ = numbers[5]

        guard accX.isFinite, accY.isFinite, accZ.isFinite,
              gyroX.isFinite, gyroY.isFinite, gyroZ.isFinite else {
            return nil
        }

        // If acceleration is reported in g's (typical IMU default), convert
        // so downstream thresholds (which assume m/s²) keep working.
        let mag = (accX * accX + accY * accY + accZ * accZ).squareRoot()
        if mag < gUnitsThreshold {
            accX *= gToMetersPerSecondSquared
            accY *= gToMetersPerSecondSquared
            accZ *= gToMetersPerSecondSquared
        }

        return SensorReading(
            timestamp: .now,
            accX: accX,
            accY: accY,
            accZ: accZ,
            gyroX: gyroX,
            gyroY: gyroY,
            gyroZ: gyroZ
        )
    }

    /// Extracts every signed decimal number from a free-form ASCII string,
    /// in order. Tolerates CSV, whitespace, labels ("IMU:"), and trailing
    /// timestamps — we only consume the first six matches.
    private static func extractNumbers(from string: String) -> [Double] {
        let pattern = #"-?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(string.startIndex..., in: string)
        return regex.matches(in: string, range: range).compactMap { match in
            guard let r = Range(match.range, in: string) else { return nil }
            return Double(string[r])
        }
    }

    // MARK: - Binary (legacy) path

    private static func parseBinary(_ data: Data) throws -> SensorReading {
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

    private static func readFloat(from data: Data, offset: Int) -> Float {
        data.withUnsafeBytes { buffer in
            buffer.loadUnaligned(fromByteOffset: offset, as: Float.self)
        }
    }

    // MARK: - Diagnostic logging

    private static func logFirstSampleOfLength(_ data: Data) {
        let length = data.count
        let shouldLog: Bool = logQueue.sync {
            guard !loggedLengths.contains(length) else { return false }
            loggedLengths.insert(length)
            return true
        }
        guard shouldLog else { return }

        let hex = data.prefix(64).map { String(format: "%02x", $0) }.joined(separator: " ")
        let ascii = String(data: data, encoding: .utf8)?
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r") ?? "(non-UTF8)"
        AppLogger.ble.info("Sensor packet sample (\(length)B) hex: \(hex) ascii: \(ascii)")
    }
}
