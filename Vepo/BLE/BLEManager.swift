import CoreBluetooth
import Foundation
import OSLog

/// Manages the full BLE lifecycle: scanning, connecting, discovering services,
/// subscribing to sensor data, and auto-reconnecting on disconnect.
///
/// Note: Cannot use @Observable because NSObject subclass is required for
/// CoreBluetooth delegates. State changes are pushed via onStateChanged callback.
final class BLEManager: NSObject, BLEManagerProtocol, @unchecked Sendable {
    // MARK: - Published State

    private(set) var connectionState: BLEConnectionState = .idle {
        didSet { onStateChanged?() }
    }
    private(set) var discoveredDevices: [DiscoveredDevice] = [] {
        didSet { onStateChanged?() }
    }
    /// Snapshot of services + characteristics from the most recently
    /// connected peripheral. Surfaces what the ESP32 actually exposes so
    /// users can correct UUID mismatches via the diagnostics panel.
    private(set) var lastDiscoveredServices: [DiscoveredService] = [] {
        didSet { onStateChanged?() }
    }
    private(set) var bluetoothState: CBManagerState = .unknown {
        didSet { onStateChanged?() }
    }

    /// Called whenever any of the published state above changes.
    /// ConnectionViewModel observes via this callback.
    var onStateChanged: (() -> Void)?

    // MARK: - Streams (created once, stored)

    /// Raw IMU readings — only emitted by firmware that sends the legacy
    /// 28-byte binary IMU packet. The current Vepo firmware emits
    /// pre-detected events through `bottleMessages` instead.
    let sensorReadings: AsyncStream<SensorReading>

    /// High-level bottle messages (DRINK / TERMO_READY / unknown).
    /// This is the primary stream for the current firmware.
    let bottleMessages: AsyncStream<BottleMessage>

    // MARK: - Private

    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var sensorCharacteristic: CBCharacteristic?
    private var sensorContinuation: AsyncStream<SensorReading>.Continuation?
    private var bottleContinuation: AsyncStream<BottleMessage>.Continuation?
    private var reconnectAttempts = 0
    private var shouldAutoReconnect = true
    private var pendingCharacteristicDiscoveries = 0

    // MARK: - Init

    override init() {
        var storedSensorContinuation: AsyncStream<SensorReading>.Continuation?
        sensorReadings = AsyncStream { continuation in
            storedSensorContinuation = continuation
        }
        var storedBottleContinuation: AsyncStream<BottleMessage>.Continuation?
        bottleMessages = AsyncStream { continuation in
            storedBottleContinuation = continuation
        }
        super.init()
        sensorContinuation = storedSensorContinuation
        bottleContinuation = storedBottleContinuation
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: - Public API

    /// Start scanning. When `permissive` is true, discover *every* nearby BLE
    /// device (no service-UUID filter) — used by the diagnostics panel and
    /// when the user can't find their bottle via the default filtered scan.
    func startScanning(permissive: Bool = false) async {
        guard centralManager.state == .poweredOn else {
            AppLogger.ble.warning("Cannot scan — Bluetooth not powered on (state: \(self.bluetoothState.rawValue))")
            return
        }
        discoveredDevices = []
        lastDiscoveredServices = []
        connectionState = .scanning

        let serviceFilter: [CBUUID]? = permissive ? nil : [BLEConstants.serviceUUID]
        // Allow duplicates in permissive mode so RSSI updates as the user moves around.
        centralManager.scanForPeripherals(
            withServices: serviceFilter,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: permissive]
        )
        if permissive {
            AppLogger.ble.info("Started permissive scan (all nearby BLE devices)")
        } else {
            AppLogger.ble.info("Started filtered scan for service \(BLEConstants.serviceUUID.uuidString)")
        }

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
        AppLogger.ble.info("Stopped scanning (\(self.discoveredDevices.count) devices found)")
    }

    func connect(to peripheral: CBPeripheral) async {
        stopScanning()
        connectionState = .connecting
        connectedPeripheral = peripheral
        peripheral.delegate = self
        lastDiscoveredServices = []
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
        pendingCharacteristicDiscoveries = 0
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

    /// After ALL services + characteristics have been discovered, look for
    /// the configured Vepo characteristic and subscribe. If not present,
    /// surface the discovered shape so the user can correct BLEConstants.
    private func subscribeToVepoCharacteristic() {
        guard let peripheral = connectedPeripheral else { return }

        let services = peripheral.services ?? []
        guard let service = services.first(where: { $0.uuid == BLEConstants.serviceUUID }) else {
            let uuids = services.map { $0.uuid.uuidString }.joined(separator: ", ")
            AppLogger.ble.error("Vepo service \(BLEConstants.serviceUUID.uuidString) not present. Discovered: [\(uuids)]")
            failDiscovery(
                peripheral: peripheral,
                reason: "Vepo service not found on this device. Open BLE Diagnostics to inspect what it exposes."
            )
            return
        }

        guard let characteristic = service.characteristics?.first(where: {
            $0.uuid == BLEConstants.sensorCharacteristicUUID
        }) else {
            let uuids = (service.characteristics ?? []).map { $0.uuid.uuidString }.joined(separator: ", ")
            AppLogger.ble.error("Vepo characteristic \(BLEConstants.sensorCharacteristicUUID.uuidString) missing. Service exposes: [\(uuids)]")
            failDiscovery(
                peripheral: peripheral,
                reason: "Sensor characteristic not found. Open BLE Diagnostics to inspect this device."
            )
            return
        }

        sensorCharacteristic = characteristic
        peripheral.setNotifyValue(true, for: characteristic)
        AppLogger.ble.info("Subscribing to sensor data stream...")
    }

    /// Cancel an unusable connection without triggering auto-reconnect.
    /// Preserves `lastDiscoveredServices` so the diagnostic panel can still
    /// display what the device exposed.
    private func failDiscovery(peripheral: CBPeripheral, reason: String) {
        shouldAutoReconnect = false
        centralManager.cancelPeripheralConnection(peripheral)
        connectionState = .disconnected(reason: reason)
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state
        switch central.state {
        case .poweredOn:
            AppLogger.ble.info("Bluetooth powered on")
        case .poweredOff:
            connectionState = .disconnected(reason: "Bluetooth is off")
        case .unauthorized:
            connectionState = .disconnected(reason: "Bluetooth permission denied — enable it in Settings → Vepo")
        case .unsupported:
            connectionState = .disconnected(reason: "Bluetooth not supported on this device")
        case .resetting:
            connectionState = .disconnected(reason: "Bluetooth is resetting")
        case .unknown:
            break
        @unknown default:
            break
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let advertisedUUIDs = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]) ?? []
        let advertisedName = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name
        let isCandidate = advertisedUUIDs.contains(BLEConstants.serviceUUID)
            || (advertisedName?.lowercased().hasPrefix(BLEConstants.deviceNamePrefix.lowercased()) ?? false)

        let device = DiscoveredDevice(
            peripheral: peripheral,
            name: advertisedName,
            rssi: RSSI.intValue,
            advertisedServiceUUIDs: advertisedUUIDs,
            isVepoCandidate: isCandidate
        )

        if let idx = discoveredDevices.firstIndex(where: { $0.id == peripheral.identifier }) {
            // Update RSSI on subsequent discoveries (when allowDuplicates is on).
            discoveredDevices[idx] = device
        } else {
            discoveredDevices.append(device)
            let uuidsStr = advertisedUUIDs.map { $0.uuidString }.joined(separator: ", ")
            AppLogger.ble.info("Discovered: \(advertisedName ?? "unnamed") RSSI: \(RSSI) candidate: \(isCandidate) UUIDs: [\(uuidsStr)]")
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectionState = .discoveringServices
        reconnectAttempts = 0
        shouldAutoReconnect = true
        // Discover ALL services so the diagnostic panel can show what the ESP32 exposes.
        peripheral.discoverServices(nil)
        AppLogger.ble.info("Connected to \(peripheral.name ?? "unknown") — discovering services...")
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
        if let error {
            AppLogger.ble.error("Service discovery error: \(error.localizedDescription)")
            connectionState = .disconnected(reason: "Service discovery failed")
            return
        }
        let services = peripheral.services ?? []
        let uuids = services.map { $0.uuid.uuidString }.joined(separator: ", ")
        AppLogger.ble.info("Discovered \(services.count) services: [\(uuids)]")

        // Seed the diagnostic snapshot with empty characteristic lists,
        // populated as each didDiscoverCharacteristicsFor callback returns.
        lastDiscoveredServices = services.map {
            DiscoveredService(uuid: $0.uuid, characteristicUUIDs: [])
        }

        guard !services.isEmpty else {
            failDiscovery(peripheral: peripheral, reason: "Device exposed no services")
            return
        }

        pendingCharacteristicDiscoveries = services.count
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        if let error {
            AppLogger.ble.error("Characteristic discovery error for \(service.uuid.uuidString): \(error.localizedDescription)")
        }
        let chars = service.characteristics ?? []
        let charUUIDs = chars.map { $0.uuid.uuidString }.joined(separator: ", ")
        AppLogger.ble.info("Service \(service.uuid.uuidString) characteristics: [\(charUUIDs)]")

        if let idx = lastDiscoveredServices.firstIndex(where: { $0.uuid == service.uuid }) {
            lastDiscoveredServices[idx] = DiscoveredService(
                uuid: service.uuid,
                characteristicUUIDs: chars.map { $0.uuid }
            )
        }

        pendingCharacteristicDiscoveries -= 1
        if pendingCharacteristicDiscoveries <= 0 {
            subscribeToVepoCharacteristic()
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error {
            AppLogger.ble.error("Notification subscription failed: \(error.localizedDescription)")
            connectionState = .disconnected(reason: "Sensor subscription failed")
            return
        }
        if characteristic.uuid == BLEConstants.sensorCharacteristicUUID, characteristic.isNotifying {
            connectionState = .connected
            AppLogger.ble.info("Subscribed to sensor data — connected and streaming")
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard characteristic.uuid == BLEConstants.sensorCharacteristicUUID,
              let data = characteristic.value else { return }

        // Current firmware: high-level bottle messages (DRINK | TERMO_READY).
        if let message = BottleMessageParser.parse(data) {
            bottleContinuation?.yield(message)
            switch message {
            case .drink(_, let angle, let total):
                AppLogger.ble.info("Bottle DRINK event ang=\(angle) total=\(total)")
            case .ready(let reportedAt):
                AppLogger.ble.info("Bottle ready (reported \(reportedAt))")
            case .unknown(let raw):
                AppLogger.ble.debug("Unknown bottle message: \(raw)")
            }
            return
        }

        // Legacy firmware: raw IMU binary stream.
        do {
            let reading = try SensorPacketParser.parse(data)
            sensorContinuation?.yield(reading)
        } catch {
            AppLogger.ble.debug("Packet parse error: \(error)")
        }
    }
}
