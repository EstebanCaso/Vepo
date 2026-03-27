import SwiftUI
import SwiftData

/// Set to `true` to use simulated BLE data (no physical bottle needed).
/// Toggle via Xcode: Edit Scheme → Run → Arguments → Environment Variables → USE_MOCK_BLE=1
private let useMockBLE: Bool = {
    ProcessInfo.processInfo.environment["USE_MOCK_BLE"] == "1"
}()

@main
struct VepoApp: App {
    let modelContainer: ModelContainer

    // MARK: - Services

    private let dataStore: LocalDataStore
    private let bleManager: BLEManager
    private let mockBLEManager: MockBLEManager?
    private let drinkDetector: DrinkDetector
    private let notificationService: NotificationService
    private let hapticService: HapticService

    // MARK: - ViewModels

    @State private var connectionVM: ConnectionViewModel
    @State private var sessionVM: SessionViewModel
    @State private var eventLogVM: EventLogViewModel
    @State private var settingsVM: SettingsViewModel

    @MainActor
    init() {
        // SwiftData setup
        do {
            let schema = Schema([
                DrinkEvent.self,
                HydrationSession.self,
                UserSettings.self,
            ])
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error.localizedDescription)")
        }

        let store = LocalDataStore(modelContainer: modelContainer)
        self.dataStore = store

        // Initialize services
        let ble = BLEManager()
        let mock: MockBLEManager? = useMockBLE ? MockBLEManager() : nil
        let detector = DrinkDetector()
        let notifications = NotificationService()
        let haptics = HapticService()

        self.bleManager = ble
        self.mockBLEManager = mock
        self.drinkDetector = detector
        self.notificationService = notifications
        self.hapticService = haptics

        // Initialize ViewModels with DI
        self._connectionVM = State(initialValue: ConnectionViewModel(
            bleManager: ble,
            hapticService: haptics
        ))
        self._sessionVM = State(initialValue: SessionViewModel(
            dataStore: store,
            drinkDetector: detector
        ))
        self._eventLogVM = State(initialValue: EventLogViewModel(
            dataStore: store
        ))
        self._settingsVM = State(initialValue: SettingsViewModel(
            dataStore: store,
            notificationService: notifications
        ))

    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(connectionVM)
                .environment(sessionVM)
                .environment(eventLogVM)
                .environment(settingsVM)
                .task {
                    // Start a hydration session and begin processing
                    _ = try? await dataStore.startNewSession()

                    if let mock = mockBLEManager {
                        AppLogger.ble.info("Running in MOCK BLE mode")
                        await mock.simulateConnect()
                        await drinkDetector.startProcessing(mock.sensorReadings)
                    } else {
                        await drinkDetector.startProcessing(bleManager.sensorReadings)
                    }

                    // When the task is cancelled (view disappears), end the session
                    if let session = try? await dataStore.fetchCurrentSession() {
                        try? await dataStore.endSession(session)
                    }
                }
                .task {
                    // Persist events, reschedule notifications, haptic feedback
                    for await event in drinkDetector.drinkEvents {
                        // Link event to current session before saving
                        if let session = try? await dataStore.fetchCurrentSession() {
                            event.session = session
                        }
                        try? await dataStore.saveDrinkEvent(event)

                        // Load user settings for notification behavior
                        let settings = try? await dataStore.loadSettings()
                        let minutes = settings?.reminderWaitMinutes ?? 60
                        let notifType = settings?.notificationType ?? .both
                        let startHour = settings?.activeStartHour ?? 0
                        let endHour = settings?.activeEndHour ?? 24
                        let isPaused = settings?.isPaused ?? false

                        // Reschedule notification with full settings context
                        if !isPaused {
                            await notificationService.resetTimer(
                                afterMinutes: minutes,
                                notificationType: notifType,
                                activeStartHour: startHour,
                                activeEndHour: endHour
                            )
                        }

                        // Play haptic based on notification type preference
                        if notifType == .vibration || notifType == .both {
                            hapticService.playDrinkConfirmation()
                        }
                    }
                }
                .task {
                    _ = await notificationService.requestPermission()
                }
        }
        .modelContainer(modelContainer)
    }
}
