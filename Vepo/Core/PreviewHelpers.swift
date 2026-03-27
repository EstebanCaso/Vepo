import SwiftUI
import SwiftData

/// Preview and debug helpers for running the app without a physical ESP32 bottle.
/// Use `#if DEBUG` to ensure none of this ships in production.
#if DEBUG

enum PreviewHelpers {

    /// Creates an in-memory ModelContainer for previews
    static var previewContainer: ModelContainer {
        let schema = Schema([
            DrinkEvent.self,
            HydrationSession.self,
            UserSettings.self,
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Preview ModelContainer failed: \(error)")
        }
    }

    /// Sample drink events for previews
    static var sampleEvents: [DrinkEvent] {
        let now = Date.now
        return [
            DrinkEvent(
                timestamp: now.addingTimeInterval(-120),
                eventDuration: 2.8,
                timeSinceLastDrink: 1800
            ),
            DrinkEvent(
                timestamp: now.addingTimeInterval(-1920),
                eventDuration: 3.1,
                timeSinceLastDrink: 2400
            ),
            DrinkEvent(
                timestamp: now.addingTimeInterval(-4320),
                eventDuration: 2.5,
                timeSinceLastDrink: nil
            ),
        ]
    }

    /// Creates a fully wired set of view models using mock data
    static func makePreviewEnvironment() -> (
        connectionVM: ConnectionViewModel,
        sessionVM: SessionViewModel,
        eventLogVM: EventLogViewModel,
        settingsVM: SettingsViewModel
    ) {
        let container = previewContainer
        let dataStore = LocalDataStore(modelContainer: container)
        let bleManager = BLEManager()
        let detector = DrinkDetector()
        let notifications = NotificationService()
        let haptics = HapticService()

        return (
            connectionVM: ConnectionViewModel(bleManager: bleManager, hapticService: haptics),
            sessionVM: SessionViewModel(dataStore: dataStore, drinkDetector: detector),
            eventLogVM: EventLogViewModel(dataStore: dataStore),
            settingsVM: SettingsViewModel(dataStore: dataStore, notificationService: notifications)
        )
    }
}

// MARK: - Preview View Modifier

/// Wraps a view with all required @Environment objects for previews
struct PreviewEnvironmentModifier: ViewModifier {
    let env = PreviewHelpers.makePreviewEnvironment()

    func body(content: Content) -> some View {
        content
            .environment(env.connectionVM)
            .environment(env.sessionVM)
            .environment(env.eventLogVM)
            .environment(env.settingsVM)
            .modelContainer(PreviewHelpers.previewContainer)
    }
}

extension View {
    func withPreviewEnvironment() -> some View {
        modifier(PreviewEnvironmentModifier())
    }
}

// MARK: - Preview Providers

#Preview("Summary") {
    SessionSummaryView()
        .withPreviewEnvironment()
}

#Preview("Event Log") {
    EventLogView()
        .withPreviewEnvironment()
}

#Preview("Connection") {
    ConnectionStatusView()
        .withPreviewEnvironment()
}

#Preview("Settings") {
    SettingsView()
        .withPreviewEnvironment()
}

#Preview("Full App") {
    ContentView()
        .withPreviewEnvironment()
}

#endif
