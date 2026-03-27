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
    var discoveredPeripherals: [CBPeripheral] = []

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

    // MARK: - Init

    init(bleManager: BLEManager, hapticService: HapticService = HapticService()) {
        self.bleManager = bleManager
        self.hapticService = hapticService

        // Sync initial state
        self.connectionState = bleManager.connectionState
        self.discoveredPeripherals = bleManager.discoveredPeripherals

        // Subscribe to changes
        bleManager.onStateChanged = { [weak self] in
            guard let self else { return }
            self.connectionState = bleManager.connectionState
            self.discoveredPeripherals = bleManager.discoveredPeripherals
        }
    }

    // MARK: - Actions

    func startScan() async {
        await bleManager.startScanning()
    }

    func stopScan() {
        bleManager.stopScanning()
    }

    func connect(to peripheral: CBPeripheral) async {
        await bleManager.connect(to: peripheral)
        hapticService.playConnectionFeedback()
    }

    func disconnect() {
        bleManager.disconnect()
    }
}
