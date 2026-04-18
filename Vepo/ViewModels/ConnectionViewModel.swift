import CoreBluetooth
import Foundation
import Observation

/// ViewModel for the BLE connection screen.
/// Holds observable state synced from BLEManager via callback.
@Observable
final class ConnectionViewModel {
    private let bleManager: BLEManager
    private let hapticService: HapticService

    // MARK: - Observable State (synced from BLEManager)

    var connectionState: BLEConnectionState = .idle
    var discoveredDevices: [DiscoveredDevice] = []
    var lastDiscoveredServices: [DiscoveredService] = []
    var bluetoothState: CBManagerState = .unknown

    // MARK: - View-Local State

    /// Set true the first time the user initiates a scan, so the empty-state
    /// card only shows after they've actually tried (not on first launch).
    var hasAttemptedScan: Bool = false
    var showDiagnostics: Bool = false

    var isScanning: Bool {
        connectionState == .scanning
    }

    var statusMessage: String {
        switch connectionState {
        case .idle:
            "Tap scan to find your Vepo bottle"
        case .scanning:
            "Looking for your bottle..."
        case .connecting:
            "Connecting..."
        case .discoveringServices:
            "Almost ready..."
        case .connected:
            "Connected and monitoring"
        case .disconnected(let reason):
            reason ?? "Disconnected"
        }
    }

    /// Vepo-candidate devices first, then everything else, each group sorted
    /// by RSSI descending (closest first).
    var sortedDevices: [DiscoveredDevice] {
        discoveredDevices.sorted { lhs, rhs in
            if lhs.isVepoCandidate != rhs.isVepoCandidate { return lhs.isVepoCandidate }
            return lhs.rssi > rhs.rssi
        }
    }

    /// True after a scan finished and surfaced no devices — drives the
    /// "No bottles found" empty-state card on the connection screen.
    var showsEmptyResults: Bool {
        hasAttemptedScan
            && !isScanning
            && discoveredDevices.isEmpty
            && !connectionState.isActive
    }

    // MARK: - Init

    init(bleManager: BLEManager, hapticService: HapticService = HapticService()) {
        self.bleManager = bleManager
        self.hapticService = hapticService

        // Sync initial state
        self.connectionState = bleManager.connectionState
        self.discoveredDevices = bleManager.discoveredDevices
        self.lastDiscoveredServices = bleManager.lastDiscoveredServices
        self.bluetoothState = bleManager.bluetoothState

        // Subscribe to changes
        bleManager.onStateChanged = { [weak self] in
            guard let self else { return }
            self.connectionState = bleManager.connectionState
            self.discoveredDevices = bleManager.discoveredDevices
            self.lastDiscoveredServices = bleManager.lastDiscoveredServices
            self.bluetoothState = bleManager.bluetoothState
        }
    }

    // MARK: - Actions

    func startScan(permissive: Bool = false) async {
        hasAttemptedScan = true
        await bleManager.startScanning(permissive: permissive)
    }

    func stopScan() {
        bleManager.stopScanning()
    }

    func connect(to device: DiscoveredDevice) async {
        await bleManager.connect(to: device.peripheral)
        hapticService.playConnectionFeedback()
    }

    func disconnect() {
        bleManager.disconnect()
    }

    func openDiagnostics() {
        showDiagnostics = true
    }
}
