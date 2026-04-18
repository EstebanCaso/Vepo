import Foundation
import Observation
import SwiftData

/// ViewModel for the session summary dashboard.
/// Tracks live stats and the ticking time-since-last-drink counter.
@MainActor
@Observable
final class SessionViewModel {
    private let dataStore: LocalDataStore
    private let drinkDetector: DrinkDetector
    private var timerTask: Task<Void, Never>?

    // MARK: - Live State

    var totalEventsToday: Int = 0
    var longestGapToday: TimeInterval = 0
    var averageInterval: TimeInterval = 0
    var timeSinceLastDrink: TimeInterval = 0
    var lastDrinkTime: Date?
    var reminderThresholdMinutes: Int = 60

    /// Most recent events today (newest first), capped to 4 for the dashboard list.
    var recentEvents: [DrinkEvent] = []

    /// Drink count per hour of the day (24 entries, index = hour 0–23).
    /// Drives the small "today's rhythm" bar chart.
    var hourlyCountsToday: [Int] = Array(repeating: 0, count: 24)

    /// Color intensity based on time since last drink (0.0 = just drank, 1.0 = overdue)
    var urgencyLevel: Double {
        let thresholdSeconds = Double(reminderThresholdMinutes) * 60
        guard thresholdSeconds > 0 else { return 0.0 }
        return min(timeSinceLastDrink / thresholdSeconds, 1.0)
    }

    // MARK: - Init

    init(dataStore: LocalDataStore, drinkDetector: DrinkDetector) {
        self.dataStore = dataStore
        self.drinkDetector = drinkDetector
    }

    // MARK: - Lifecycle

    func start() async {
        // Guard against re-entry
        guard timerTask == nil else { return }

        await refreshStats()
        await loadThreshold()
        startLiveCounter()
    }

    func stop() {
        timerTask?.cancel()
        timerTask = nil
    }

    // MARK: - Stats

    func refreshStats() async {
        do {
            let todayEvents = try await dataStore.fetchEvents(for: .now)

            totalEventsToday = todayEvents.count

            let gaps = todayEvents.compactMap(\.timeSinceLastDrink)
            longestGapToday = gaps.max() ?? 0

            if gaps.count > 1 {
                averageInterval = gaps.reduce(0, +) / Double(gaps.count)
            } else {
                averageInterval = 0
            }

            lastDrinkTime = todayEvents.first?.timestamp
            recentEvents = Array(todayEvents.prefix(4))

            // Bucket today's events by hour of day for the rhythm bar chart.
            let calendar = Calendar.current
            var counts = Array(repeating: 0, count: 24)
            for event in todayEvents {
                let hour = calendar.component(.hour, from: event.timestamp)
                if (0..<24).contains(hour) { counts[hour] += 1 }
            }
            hourlyCountsToday = counts

            updateTimeSinceLastDrink()
        } catch {
            AppLogger.persistence.error("Failed to refresh stats: \(error.localizedDescription)")
        }
    }

    private func loadThreshold() async {
        do {
            let settings = try await dataStore.loadSettings()
            reminderThresholdMinutes = settings.reminderWaitMinutes
        } catch {
            AppLogger.persistence.error("Failed to load threshold: \(error.localizedDescription)")
        }
    }

    // MARK: - Live Counter

    private func startLiveCounter() {
        timerTask?.cancel()
        timerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.updateTimeSinceLastDrink()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func updateTimeSinceLastDrink() {
        if let lastDrink = lastDrinkTime {
            timeSinceLastDrink = Date.now.timeIntervalSince(lastDrink)
        } else {
            timeSinceLastDrink = 0
        }
    }
}
