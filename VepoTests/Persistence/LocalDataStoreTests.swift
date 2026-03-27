import Testing
import Foundation
import SwiftData
@testable import Vepo

@Suite("LocalDataStore")
struct LocalDataStoreTests {

    /// Creates an in-memory data store for testing
    private func makeTestStore() throws -> LocalDataStore {
        let schema = Schema([
            DrinkEvent.self,
            HydrationSession.self,
            UserSettings.self,
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        let container = try ModelContainer(for: schema, configurations: [config])
        return LocalDataStore(modelContainer: container)
    }

    // MARK: - Drink Events

    @Test("Save and fetch drink event")
    func saveAndFetchEvent() async throws {
        let store = try makeTestStore()
        let event = DrinkEvent(
            timestamp: .now,
            eventDuration: 3.0,
            timeSinceLastDrink: nil
        )

        try await store.saveDrinkEvent(event)
        let fetched = try await store.fetchEvents(for: .now)

        #expect(fetched.count == 1)
        #expect(fetched.first?.eventDuration == 3.0)
    }

    @Test("Fetch events filters by date")
    func fetchFiltersByDate() async throws {
        let store = try makeTestStore()

        // Event today
        let todayEvent = DrinkEvent(timestamp: .now, eventDuration: 2.0)
        try await store.saveDrinkEvent(todayEvent)

        // Event yesterday
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let yesterdayEvent = DrinkEvent(timestamp: yesterday, eventDuration: 2.5)
        try await store.saveDrinkEvent(yesterdayEvent)

        let todayResults = try await store.fetchEvents(for: .now)
        #expect(todayResults.count == 1)

        let yesterdayResults = try await store.fetchEvents(for: yesterday)
        #expect(yesterdayResults.count == 1)
    }

    @Test("Fetch latest event returns most recent")
    func fetchLatestEvent() async throws {
        let store = try makeTestStore()

        let earlier = DrinkEvent(
            timestamp: Date.now.addingTimeInterval(-60),
            eventDuration: 2.0
        )
        let later = DrinkEvent(
            timestamp: .now,
            eventDuration: 3.0
        )

        try await store.saveDrinkEvent(earlier)
        try await store.saveDrinkEvent(later)

        let latest = try await store.fetchLatestEvent()
        #expect(latest?.eventDuration == 3.0)
    }

    @Test("Delete event removes it")
    func deleteEvent() async throws {
        let store = try makeTestStore()
        let event = DrinkEvent(timestamp: .now, eventDuration: 2.0)
        try await store.saveDrinkEvent(event)

        try await store.deleteEvent(event)
        let fetched = try await store.fetchEvents(for: .now)
        #expect(fetched.isEmpty)
    }

    // MARK: - Sessions

    @Test("Start and fetch active session")
    func startAndFetchSession() async throws {
        let store = try makeTestStore()

        let session = try await store.startNewSession()
        let current = try await store.fetchCurrentSession()

        #expect(current != nil)
        #expect(current?.id == session.id)
        #expect(current?.isActive == true)
    }

    @Test("End session sets end time")
    func endSession() async throws {
        let store = try makeTestStore()

        let session = try await store.startNewSession()
        try await store.endSession(session)

        let current = try await store.fetchCurrentSession()
        #expect(current == nil)  // No active sessions
    }

    // MARK: - Settings

    @Test("Load settings returns defaults on first access")
    func loadDefaultSettings() async throws {
        let store = try makeTestStore()

        let settings = try await store.loadSettings()
        #expect(settings.reminderWaitMinutes == 60)
        #expect(settings.notificationType == .both)
        #expect(settings.isPaused == false)
    }

    @Test("Save and reload settings persists changes")
    func saveAndReloadSettings() async throws {
        let store = try makeTestStore()

        let settings = try await store.loadSettings()
        settings.reminderWaitMinutes = 30
        settings.notificationType = .vibration
        try await store.saveSettings(settings)

        let reloaded = try await store.loadSettings()
        #expect(reloaded.reminderWaitMinutes == 30)
        #expect(reloaded.notificationType == .vibration)
    }
}
