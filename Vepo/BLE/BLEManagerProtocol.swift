import CoreBluetooth
import Foundation

/// BLE connection state machine
enum BLEConnectionState: Sendable, Equatable {
    case idle
    case scanning
    case connecting
    case discoveringServices
    case connected
    case disconnected(reason: String?)

    var displayName: String {
        switch self {
        case .idle: "Ready"
        case .scanning: "Scanning..."
        case .connecting: "Connecting..."
        case .discoveringServices: "Setting up..."
        case .connected: "Connected"
        case .disconnected: "Disconnected"
        }
    }

    var isConnected: Bool {
        self == .connected
    }

    var isActive: Bool {
        switch self {
        case .scanning, .connecting, .discoveringServices, .connected: true
        default: false
        }
    }
}

/// A peripheral discovered during scan, enriched with advertisement metadata.
struct DiscoveredDevice: Identifiable, @unchecked Sendable {
    let peripheral: CBPeripheral
    let name: String?
    let rssi: Int
    let advertisedServiceUUIDs: [CBUUID]
    /// True if the device advertises the Vepo service UUID OR has a name
    /// starting with the configured Vepo prefix. Used to surface the user's
    /// bottle at the top of the discovered-devices list.
    let isVepoCandidate: Bool

    var id: UUID { peripheral.identifier }
    var displayName: String { name ?? "Unknown Device" }
}

/// A service discovered on a connected peripheral, with its characteristics.
/// Captured for the diagnostic panel so users can see exactly what the
/// ESP32 firmware exposes and reconcile UUID mismatches.
struct DiscoveredService: Identifiable, @unchecked Sendable {
    let uuid: CBUUID
    let characteristicUUIDs: [CBUUID]

    var id: String { uuid.uuidString }
}

/// Protocol for BLE manager — enables DI and testability.
protocol BLEManagerProtocol: AnyObject, Sendable {
    var connectionState: BLEConnectionState { get }
    var sensorReadings: AsyncStream<SensorReading> { get }
    var bottleMessages: AsyncStream<BottleMessage> { get }

    func startScanning(permissive: Bool) async
    func stopScanning()
    func connect(to peripheral: CBPeripheral) async
    func disconnect()
}

extension BLEManagerProtocol {
    /// Convenience: filtered scan (matches the configured Vepo service UUID).
    func startScanning() async {
        await startScanning(permissive: false)
    }
}
