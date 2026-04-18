import Foundation

/// High-level messages emitted by the Vepo ESP32 firmware over the
/// Nordic-UART characteristic.
///
/// The firmware performs drink detection on-device and only transmits the
/// finished events as line-protocol ASCII (e.g. `DRINK|2026-04-09 10:01:31|ang=39.5|total=1\n`),
/// so the iOS app does NOT need to run an IMU FSM for this firmware version —
/// it just consumes these messages.
enum BottleMessage: Sendable, Equatable {
    /// Bottle finished booting and is streaming. Carries the wall-clock the
    /// bottle reports for itself (currently unused since the bottle clock
    /// isn't synced — keep for future debugging).
    case ready(reportedAt: String)

    /// A completed drink event detected by the bottle's on-device FSM.
    /// `tiltAngle` is the peak tilt in degrees, `totalSinceBoot` is the
    /// firmware's running counter. We use the iOS receive time as the
    /// authoritative timestamp.
    case drink(receivedAt: Date, tiltAngle: Double, totalSinceBoot: Int)

    /// Any line we don't yet recognize. Kept so the diagnostic log still
    /// surfaces the raw payload without exploding.
    case unknown(raw: String)
}

/// Parser for the bottle's line-protocol over Nordic UART.
///
/// Wire format (one packet per line, `\n` terminated):
///   - `TERMO_READY|<yyyy-MM-dd HH:mm:ss>`
///   - `DRINK|<yyyy-MM-dd HH:mm:ss>|ang=<float>|total=<int>`
///
/// Forward-compatible: unknown leading tokens map to `.unknown(raw:)` so
/// new firmware messages don't crash older app builds.
enum BottleMessageParser {

    static func parse(_ data: Data) -> BottleMessage? {
        guard let raw = String(data: data, encoding: .utf8) else { return nil }
        let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { return nil }

        let parts = line.split(separator: "|", omittingEmptySubsequences: false)
            .map { String($0) }
        guard let head = parts.first else { return .unknown(raw: line) }

        switch head {
        case "TERMO_READY":
            let reported = parts.count > 1 ? parts[1] : ""
            return .ready(reportedAt: reported)

        case "DRINK":
            // parts[1] = bottle timestamp (ignored — bottle clock not synced)
            // parts[2..] = key=value pairs (ang=..., total=...)
            let kv = keyValuePairs(in: parts.dropFirst(2))
            let angle = kv["ang"].flatMap(Double.init) ?? 0.0
            let total = kv["total"].flatMap(Int.init) ?? 0
            return .drink(receivedAt: .now, tiltAngle: angle, totalSinceBoot: total)

        default:
            return .unknown(raw: line)
        }
    }

    private static func keyValuePairs<S: Sequence>(in tokens: S) -> [String: String]
        where S.Element == String {
        var out: [String: String] = [:]
        for token in tokens {
            guard let eq = token.firstIndex(of: "=") else { continue }
            let key = String(token[..<eq])
            let value = String(token[token.index(after: eq)...])
            out[key] = value
        }
        return out
    }
}
