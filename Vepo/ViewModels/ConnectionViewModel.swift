import CoreBluetooth
import Foundation

/// ViewModel for the BLE connection screen.
/// Wraps BLEManager and exposes connection state for SwiftUI.
@Observable
final class ConnectionViewModel {
    private let bleManager: BLEManager
    private let hapticService: HapticService

    // MARK: - State

    var connectionState: BLEConnectionState {
        bleManager.connectionState
    }

    var discoveredPeripherals: [CBPeripheral] {
        bleManager.discoveredPeripherals
    }

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
