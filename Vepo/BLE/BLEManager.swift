import CoreBluetooth
import Foundation
import OSLog

/// Manages the full BLE lifecycle: scanning, connecting, discovering services,
/// subscribing to sensor data, and auto-reconnecting on disconnect.
@Observable
final class BLEManager: NSObject, BLEManagerProtocol, @unchecked Sendable {
    // MARK: - Published State

    private(set) var connectionState: BLEConnectionState = .idle
    private(set) var discoveredPeripherals: [CBPeripheral] = []

    // MARK: - Sensor Stream (created once, stored)

    let sensorReadings: AsyncStream<SensorReading>

    // MARK: - Private

    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var sensorCharacteristic: CBCharacteristic?
    private var sensorContinuation: AsyncStream<SensorReading>.Continuation?
    private var reconnectAttempts = 0
    private var shouldAutoReconnect = true

    // MARK: - Init

    override init() {
        // Create the stream once — all callers share the same stream
        var storedContinuation: AsyncStream<SensorReading>.Continuation?
        sensorReadings = AsyncStream { continuation in
            storedContinuation = continuation
        }
        super.init()
        sensorContinuation = storedContinuation
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: - Public API

    func startScanning() async {
        guard centralManager.state == .poweredOn else {
            AppLogger.ble.warning("Cannot scan — Bluetooth not powered on")
            return
        }
        discoveredPeripherals = []
        connectionState = .scanning
        centralManager.scanForPeripherals(
            withServices: [BLEConstants.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        AppLogger.ble.info("Started scanning for Vepo bottles")

        // Auto-stop scan after timeout
        try? await Task.sleep(for: .seconds(BLEConstants.scanTimeout))
        if connectionState == .scanning {
            stopScanning()
        }
    }

    func stopScanning() {
        centralManager.stopScan()
        if connectionState == .scanning {
            connectionState = .idle
        }
        AppLogger.ble.info("Stopped scanning")
    }

    func connect(to peripheral: CBPeripheral) async {
        stopScanning()
        connectionState = .connecting
        connectedPeripheral = peripheral
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
        AppLogger.ble.info("Connecting to \(peripheral.name ?? "unknown")")
    }

    func disconnect() {
        shouldAutoReconnect = false
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        cleanup()
    }

    // MARK: - Private Helpers

    private func cleanup() {
        sensorCharacteristic = nil
        connectedPeripheral = nil
        reconnectAttempts = 0
    }

    private func attemptReconnect(to peripheral: CBPeripheral) {
        guard shouldAutoReconnect,
              reconnectAttempts < BLEConstants.maxReconnectAttempts else {
            connectionState = .disconnected(reason: "Max reconnection attempts reached")
            cleanup()
            return
        }

        reconnectAttempts += 1
        let delay = BLEConstants.reconnectBaseDelay * pow(2.0, Double(reconnectAttempts - 1))
        AppLogger.ble.info("Reconnect attempt \(self.reconnectAttempts) in \(delay)s")

        Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            self?.centralManager.connect(peripheral, options: nil)
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            AppLogger.ble.info("Bluetooth powered on")
        case .poweredOff:
            connectionState = .disconnected(reason: "Bluetooth is off")
        case .unauthorized:
            connectionState = .disconnected(reason: "Bluetooth permission denied")
        case .unsupported:
            connectionState = .disconnected(reason: "Bluetooth not supported")
        default:
            break
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredPeripherals.append(peripheral)
            AppLogger.ble.info("Discovered: \(peripheral.name ?? "unnamed") RSSI: \(RSSI)")
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectionState = .discoveringServices
        reconnectAttempts = 0
        shouldAutoReconnect = true
        peripheral.discoverServices([BLEConstants.serviceUUID])
        AppLogger.ble.info("Connected to \(peripheral.name ?? "unknown")")
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        AppLogger.ble.error("Connection failed: \(error?.localizedDescription ?? "unknown")")
        attemptReconnect(to: peripheral)
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        connectionState = .disconnected(reason: error?.localizedDescription)
        AppLogger.ble.info("Disconnected from \(peripheral.name ?? "unknown")")
        attemptReconnect(to: peripheral)
    }
}

// MARK: - CBPeripheralDelegate

extension BLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: {
            $0.uuid == BLEConstants.serviceUUID
        }) else {
            AppLogger.ble.error("Vepo service not found")
            return
        }
        peripheral.discoverCharacteristics(
            [BLEConstants.sensorCharacteristicUUID],
            for: service
        )
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard let characteristic = service.characteristics?.first(where: {
            $0.uuid == BLEConstants.sensorCharacteristicUUID
        }) else {
            AppLogger.ble.error("Sensor characteristic not found")
            return
        }
        sensorCharacteristic = characteristic
        peripheral.setNotifyValue(true, for: characteristic)
        connectionState = .connected
        AppLogger.ble.info("Subscribed to sensor data stream")
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard characteristic.uuid == BLEConstants.sensorCharacteristicUUID,
              let data = characteristic.value else { return }

        do {
            let reading = try SensorPacketParser.parse(data)
            sensorContinuation?.yield(reading)
        } catch {
            AppLogger.ble.debug("Packet parse error: \(error)")
        }
    }
}
