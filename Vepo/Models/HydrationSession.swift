import Foundation
import SwiftData

/// A continuous usage session — tracks a period where the bottle is active.
@Model
final class HydrationSession {
    var id: UUID
    var startTime: Date
    var endTime: Date?

    @Relationship(deleteRule: .cascade)
    var events: [DrinkEvent]

    /// Whether this session is still active (no end time set)
    var isActive: Bool {
        endTime == nil
    }

    /// Total number of drink events in this session
    var eventCount: Int {
        events.count
    }

    /// Longest gap between consecutive drink events (seconds), nil if fewer than 2 events
    var longestGap: TimeInterval? {
        let gaps = events.compactMap(\.timeSinceLastDrink)
        return gaps.max()
    }

    init(
        id: UUID = UUID(),
        startTime: Date = .now,
        endTime: Date? = nil,
        events: [DrinkEvent] = []
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.events = events
    }
}
