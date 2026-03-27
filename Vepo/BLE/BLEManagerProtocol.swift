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

/// Protocol for BLE manager — enables DI and testability.
protocol BLEManagerProtocol: AnyObject, Sendable {
    var connectionState: BLEConnectionState { get }
    var sensorReadings: AsyncStream<SensorReading> { get }

    func startScanning() async
    func stopScanning()
    func connect(to peripheral: CBPeripheral) async
    func disconnect()
}
