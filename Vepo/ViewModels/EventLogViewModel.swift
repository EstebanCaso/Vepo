import Foundation
import SwiftData

/// ViewModel for the drink event log.
/// Fetches and groups events by date for display.
@Observable
final class EventLogViewModel {
    private let dataStore: LocalDataStore

    // MARK: - State

    var events: [DrinkEvent] = []
    var selectedDate: Date = .now
    var isLoading = false

    /// Events grouped by hour for section headers
    var groupedByHour: [(hour: String, events: [DrinkEvent])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: events) { event in
            calendar.component(.hour, from: event.timestamp)
        }
        return grouped
            .sorted { $0.key > $1.key }
            .map { hour, events in
                let date = calendar.date(
                    bySettingHour: hour, minute: 0, second: 0,
                    of: selectedDate
                ) ?? selectedDate
                return (hour: Date.hourFormatter.string(from: date), events: events)
            }
    }

    var isEmpty: Bool {
        events.isEmpty && !isLoading
    }

    // MARK: - Init

    init(dataStore: LocalDataStore) {
        self.dataStore = dataStore
    }

    // MARK: - Actions

    func loadEvents() async {
        isLoading = true
        do {
            events = try await dataStore.fetchEvents(for: selectedDate)
        } catch {
            AppLogger.persistence.error("Failed to load events: \(error.localizedDescription)")
            events = []
        }
        isLoading = false
    }

    func selectDate(_ date: Date) async {
        selectedDate = date
        await loadEvents()
    }
}
