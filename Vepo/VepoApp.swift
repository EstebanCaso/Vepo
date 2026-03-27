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

        let dataStore = LocalDataStore(modelContainer: modelContainer)

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
            dataStore: dataStore,
            drinkDetector: detector
        ))
        self._eventLogVM = State(initialValue: EventLogViewModel(
            dataStore: dataStore
        ))
        self._settingsVM = State(initialValue: SettingsViewModel(
            dataStore: dataStore,
            notificationService: notifications
        ))

        // Wire drink detection pipeline
        detector.onDrinkDetected = { event in
            Task {
                try? await dataStore.saveDrinkEvent(event)

                let settings = try? await dataStore.loadSettings()
                let minutes = settings?.reminderWaitMinutes ?? 60
                await notifications.resetTimer(afterMinutes: minutes)

                haptics.playDrinkConfirmation()
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(connectionVM)
                .environment(sessionVM)
                .environment(eventLogVM)
                .environment(settingsVM)
                .task {
                    if let mock = mockBLEManager {
                        // Mock mode: auto-connect and feed simulated data
                        AppLogger.ble.info("Running in MOCK BLE mode")
                        await mock.simulateConnect()
                        await drinkDetector.startProcessing(mock.sensorReadings)
                    } else {
                        // Real mode: wait for BLE connection
                        await drinkDetector.startProcessing(bleManager.sensorReadings)
                    }
                }
                .task {
                    _ = await notificationService.requestPermission()
                }
        }
        .modelContainer(modelContainer)
    }
}
