import Testing
import Foundation
import SwiftData
@testable import Vepo

@Suite("SessionViewModel")
struct SessionViewModelTests {

    /// Creates an in-memory data store and view model for testing
    @MainActor
    private func makeTestComponents() throws -> (LocalDataStore, DrinkDetector, SessionViewModel) {
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
        let store = LocalDataStore(modelContainer: container)
        let detector = DrinkDetector()
        let viewModel = SessionViewModel(dataStore: store, drinkDetector: detector)
        return (store, detector, viewModel)
    }

    @Test("Initial state has zero values")
    @MainActor
    func initialState() throws {
        let (_, _, vm) = try makeTestComponents()
        #expect(vm.totalEventsToday == 0)
        #expect(vm.longestGapToday == 0)
        #expect(vm.averageInterval == 0)
        #expect(vm.lastDrinkTime == nil)
    }

    @Test("Refresh stats counts today's events")
    @MainActor
    func refreshStatsCountsEvents() async throws {
        let (store, _, vm) = try makeTestComponents()

        for i in 0..<3 {
            let event = DrinkEvent(
                timestamp: Date.now.addingTimeInterval(Double(-i) * 600),
                eventDuration: 2.5,
                timeSinceLastDrink: i > 0 ? 600 : nil
            )
            try await store.saveDrinkEvent(event)
        }

        await vm.refreshStats()
        #expect(vm.totalEventsToday == 3)
    }

    @Test("Longest gap is computed correctly")
    @MainActor
    func longestGapComputation() async throws {
        let (store, _, vm) = try makeTestComponents()

        let event1 = DrinkEvent(
            timestamp: Date.now.addingTimeInterval(-1200),
            eventDuration: 2.0,
            timeSinceLastDrink: nil
        )
        let event2 = DrinkEvent(
            timestamp: Date.now.addingTimeInterval(-600),
            eventDuration: 2.0,
            timeSinceLastDrink: 600
        )
        let event3 = DrinkEvent(
            timestamp: .now,
            eventDuration: 2.0,
            timeSinceLastDrink: 1800
        )

        try await store.saveDrinkEvent(event1)
        try await store.saveDrinkEvent(event2)
        try await store.saveDrinkEvent(event3)

        await vm.refreshStats()
        #expect(vm.longestGapToday == 1800)
    }

    @Test("Urgency level scales from 0 to 1")
    @MainActor
    func urgencyLevelScaling() throws {
        let (_, _, vm) = try makeTestComponents()

        vm.timeSinceLastDrink = 0
        #expect(vm.urgencyLevel == 0.0)

        vm.timeSinceLastDrink = 1800  // 30 minutes
        #expect(abs(vm.urgencyLevel - 0.5) < 0.01)

        vm.timeSinceLastDrink = 3600  // 60 minutes
        #expect(vm.urgencyLevel == 1.0)

        vm.timeSinceLastDrink = 7200  // 120 minutes — caps at 1.0
        #expect(vm.urgencyLevel == 1.0)
    }
}
