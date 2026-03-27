import Foundation
import SwiftData
import OSLog

/// Actor-based SwiftData persistence layer.
/// Thread-safe by design — all access goes through the actor's serial executor.
@ModelActor
actor LocalDataStore: DataStoreProtocol {

    // MARK: - Drink Events

    func saveDrinkEvent(_ event: DrinkEvent) throws {
        modelContext.insert(event)
        try modelContext.save()
        AppLogger.persistence.info("Saved drink event at \(event.timestamp)")
    }

    func fetchEvents(for date: Date) throws -> [DrinkEvent] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }

        let predicate = #Predicate<DrinkEvent> { event in
            event.timestamp >= startOfDay && event.timestamp < endOfDay
        }
        let descriptor = FetchDescriptor<DrinkEvent>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchLatestEvent() throws -> DrinkEvent? {
        var descriptor = FetchDescriptor<DrinkEvent>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func deleteEvent(_ event: DrinkEvent) throws {
        modelContext.delete(event)
        try modelContext.save()
    }

    // MARK: - Sessions

    func fetchCurrentSession() throws -> HydrationSession? {
        let predicate = #Predicate<HydrationSession> { session in
            session.endTime == nil
        }
        let descriptor = FetchDescriptor<HydrationSession>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).first
    }

    func startNewSession() throws -> HydrationSession {
        let session = HydrationSession()
        modelContext.insert(session)
        try modelContext.save()
        AppLogger.persistence.info("Started new session \(session.id)")
        return session
    }

    func endSession(_ session: HydrationSession) throws {
        session.endTime = .now
        try modelContext.save()
        AppLogger.persistence.info("Ended session \(session.id)")
    }

    // MARK: - Settings

    func loadSettings() throws -> UserSettings {
        let descriptor = FetchDescriptor<UserSettings>()
        if let existing = try modelContext.fetch(descriptor).first {
            return existing
        }
        let defaults = UserSettings()
        modelContext.insert(defaults)
        try modelContext.save()
        return defaults
    }

    func saveSettings(_ settings: UserSettings) throws {
        try modelContext.save()
        AppLogger.persistence.info("Settings saved")
    }
}
