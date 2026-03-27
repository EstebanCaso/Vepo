import Foundation
import SwiftData

/// ViewModel for the session summary dashboard.
/// Tracks live stats and the ticking time-since-last-drink counter.
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

    /// Color intensity based on time since last drink (0.0 = just drank, 1.0 = overdue)
    var urgencyLevel: Double {
        let thresholdSeconds: Double = 60 * 60  // 60 minutes
        return min(timeSinceLastDrink / thresholdSeconds, 1.0)
    }

    // MARK: - Init

    init(dataStore: LocalDataStore, drinkDetector: DrinkDetector) {
        self.dataStore = dataStore
        self.drinkDetector = drinkDetector
    }

    // MARK: - Lifecycle

    func start() async {
        await refreshStats()
        startLiveCounter()

        drinkDetector.onDrinkDetected = { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshStats()
            }
        }
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
            updateTimeSinceLastDrink()
        } catch {
            AppLogger.persistence.error("Failed to refresh stats: \(error.localizedDescription)")
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
