import Testing
import Foundation
@testable import Vepo

@Suite("BottleMessageParser")
struct BottleMessageParserTests {

    @Test("Parses TERMO_READY heartbeat")
    func parsesReady() throws {
        let raw = "TERMO_READY|2026-04-09 10:01:25\n"
        let message = try #require(BottleMessageParser.parse(Data(raw.utf8)))

        guard case .ready(let reportedAt) = message else {
            Issue.record("Expected .ready, got \(message)")
            return
        }
        #expect(reportedAt == "2026-04-09 10:01:25")
    }

    @Test("Parses DRINK event with angle and total")
    func parsesDrink() throws {
        let raw = "DRINK|2026-04-09 10:01:31|ang=39.5|total=1\n"
        let message = try #require(BottleMessageParser.parse(Data(raw.utf8)))

        guard case .drink(_, let angle, let total) = message else {
            Issue.record("Expected .drink, got \(message)")
            return
        }
        #expect(angle == 39.5)
        #expect(total == 1)
    }

    @Test("DRINK timestamp is iOS receive time, not bottle clock")
    func drinkUsesReceiveTime() throws {
        let raw = "DRINK|1990-01-01 00:00:00|ang=50|total=2\n"
        let before = Date.now
        let message = try #require(BottleMessageParser.parse(Data(raw.utf8)))
        let after = Date.now

        guard case .drink(let receivedAt, _, _) = message else {
            Issue.record("Expected .drink, got \(message)")
            return
        }
        #expect(receivedAt >= before && receivedAt <= after)
    }

    @Test("Unknown opcode falls through as .unknown")
    func unknownOpcode() throws {
        let raw = "BATTERY|85\n"
        let message = try #require(BottleMessageParser.parse(Data(raw.utf8)))

        guard case .unknown(let raw) = message else {
            Issue.record("Expected .unknown, got \(message)")
            return
        }
        #expect(raw == "BATTERY|85")
    }

    @Test("Empty data returns nil")
    func emptyData() {
        #expect(BottleMessageParser.parse(Data()) == nil)
    }

    @Test("Whitespace-only payload returns nil")
    func whitespaceOnly() {
        #expect(BottleMessageParser.parse(Data("   \n".utf8)) == nil)
    }
}
