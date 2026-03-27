import SwiftUI
import SwiftData

/// Preview and debug helpers for running the app without a physical ESP32 bottle.
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

    /// Creates a fully wired set of view models using mock data.
    /// Uses MockBLEManager to avoid CBCentralManager crash in previews.
    @MainActor
    static func makePreviewEnvironment() -> (
        connectionVM: ConnectionViewModel,
        sessionVM: SessionViewModel,
        eventLogVM: EventLogViewModel,
        settingsVM: SettingsViewModel
    ) {
        let container = previewContainer
        let dataStore = LocalDataStore(modelContainer: container)
        // Use a real BLEManager but don't scan — previews just show static state
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
    @State private var connectionVM: ConnectionViewModel?
    @State private var sessionVM: SessionViewModel?
    @State private var eventLogVM: EventLogViewModel?
    @State private var settingsVM: SettingsViewModel?
    @State private var didSetup = false

    func body(content: Content) -> some View {
        Group {
            if let connectionVM, let sessionVM, let eventLogVM, let settingsVM {
                content
                    .environment(connectionVM)
                    .environment(sessionVM)
                    .environment(eventLogVM)
                    .environment(settingsVM)
            } else {
                ProgressView()
            }
        }
        .modelContainer(PreviewHelpers.previewContainer)
        .task {
            guard !didSetup else { return }
            didSetup = true
            let env = PreviewHelpers.makePreviewEnvironment()
            connectionVM = env.connectionVM
            sessionVM = env.sessionVM
            eventLogVM = env.eventLogVM
            settingsVM = env.settingsVM
        }
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
