import Foundation
import SwiftData

/// A detected drinking event — persisted via SwiftData.
@Model
final class DrinkEvent {
    var id: UUID
    var timestamp: Date
    var eventDuration: TimeInterval        // Duration of the drink sequence (seconds)
    var timeSinceLastDrink: TimeInterval?  // Gap since previous event (seconds), nil if first

    @Relationship(inverse: \HydrationSession.events)
    var session: HydrationSession?

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        eventDuration: TimeInterval,
        timeSinceLastDrink: TimeInterval? = nil,
        session: HydrationSession? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.eventDuration = eventDuration
        self.timeSinceLastDrink = timeSinceLastDrink
        self.session = session
    }
}
