import Testing
import Foundation
@testable import Vepo

@Suite("SensorPacketParser")
struct SensorPacketParserTests {

    // MARK: - Helpers

    /// Creates a valid 28-byte sensor packet with known float values
    private func makePacket(
        accX: Float = 0, accY: Float = 0, accZ: Float = 9.81,
        gyroX: Float = 0, gyroY: Float = 0, gyroZ: Float = 0,
        timestampMs: UInt32 = 1000
    ) -> Data {
        var data = Data(capacity: 28)
        withUnsafeBytes(of: accX) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: accY) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: accZ) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: gyroX) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: gyroY) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: gyroZ) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: timestampMs) { data.append(contentsOf: $0) }
        return data
    }

    // MARK: - Valid Packets

    @Test("Parses valid gravity-only packet")
    func validGravityPacket() throws {
        let packet = makePacket(accX: 0, accY: 0, accZ: 9.81)
        let reading = try SensorPacketParser.parse(packet)

        #expect(abs(reading.accZ - 9.81) < 0.01)
        #expect(reading.accX == 0)
        #expect(reading.gyroX == 0)
    }

    @Test("Parses packet with all axes populated")
    func fullPacket() throws {
        let packet = makePacket(
            accX: 1.5, accY: -2.3, accZ: 9.1,
            gyroX: 45.0, gyroY: -10.0, gyroZ: 5.5
        )
        let reading = try SensorPacketParser.parse(packet)

        #expect(abs(reading.accX - 1.5) < 0.01)
        #expect(abs(reading.accY - (-2.3)) < 0.01)
        #expect(abs(reading.gyroX - 45.0) < 0.01)
    }

    // MARK: - Invalid Packets

    @Test("Rejects empty data")
    func rejectsEmptyData() {
        #expect(throws: SensorPacketParser.ParseError.self) {
            try SensorPacketParser.parse(Data())
        }
    }

    @Test("Rejects too-short packet")
    func rejectsTooShort() {
        let shortData = Data(repeating: 0, count: 20)
        #expect(throws: SensorPacketParser.ParseError.self) {
            try SensorPacketParser.parse(shortData)
        }
    }

    @Test("Rejects too-long packet")
    func rejectsTooLong() {
        let longData = Data(repeating: 0, count: 40)
        #expect(throws: SensorPacketParser.ParseError.self) {
            try SensorPacketParser.parse(longData)
        }
    }

    @Test("Rejects packet with NaN values")
    func rejectsNaN() {
        let packet = makePacket(accX: Float.nan)
        #expect(throws: SensorPacketParser.ParseError.self) {
            try SensorPacketParser.parse(packet)
        }
    }

    @Test("Rejects packet with infinity")
    func rejectsInfinity() {
        let packet = makePacket(accX: Float.infinity)
        #expect(throws: SensorPacketParser.ParseError.self) {
            try SensorPacketParser.parse(packet)
        }
    }

    // MARK: - Edge Cases

    @Test("Handles negative float values correctly")
    func negativeValues() throws {
        let packet = makePacket(accX: -5.0, accY: -3.0, accZ: -9.81)
        let reading = try SensorPacketParser.parse(packet)

        #expect(abs(reading.accX - (-5.0)) < 0.01)
        #expect(abs(reading.accZ - (-9.81)) < 0.01)
    }

    @Test("Handles zero packet")
    func zeroPacket() throws {
        let packet = makePacket(
            accX: 0, accY: 0, accZ: 0,
            gyroX: 0, gyroY: 0, gyroZ: 0
        )
        let reading = try SensorPacketParser.parse(packet)

        #expect(reading.accX == 0)
        #expect(reading.accelerationMagnitude == 0)
    }
}
