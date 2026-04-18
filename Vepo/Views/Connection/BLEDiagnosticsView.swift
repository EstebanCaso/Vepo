import SwiftUI
import CoreBluetooth
import UIKit

/// Developer diagnostic sheet for BLE troubleshooting.
///
/// Shows the live Bluetooth power state, every nearby BLE device with its
/// advertised service UUIDs and RSSI, and (after connecting) the full
/// service/characteristic tree the peripheral exposes. Designed to make
/// "I can't find my bottle" trivially debuggable.
struct BLEDiagnosticsView: View {
    @Environment(ConnectionViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: VepoTheme.Spacing.lg) {
                    bluetoothStatePill
                    scanControls
                    devicesSection

                    if !viewModel.lastDiscoveredServices.isEmpty {
                        servicesSection
                    }

                    footerHint
                }
                .padding(VepoTheme.Layout.screenPadding)
            }
            .background(VepoTheme.Colors.background)
            .navigationTitle("BLE Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Bluetooth State

    private var bluetoothStatePill: some View {
        HStack(spacing: VepoTheme.Spacing.sm) {
            Circle()
                .fill(bluetoothStateColor)
                .frame(width: 10, height: 10)
            Text(bluetoothStateLabel)
                .font(VepoTheme.Typography.subheadline)
                .foregroundStyle(VepoTheme.Colors.textPrimary)
            Spacer()
        }
        .vepoCardStyle()
    }

    private var bluetoothStateLabel: String {
        switch viewModel.bluetoothState {
        case .poweredOn: "Bluetooth: Powered On"
        case .poweredOff: "Bluetooth: Off — enable it in Control Center"
        case .unauthorized: "Bluetooth: Permission denied — Settings → Vepo"
        case .unsupported: "Bluetooth: Not supported on this device"
        case .resetting: "Bluetooth: Resetting…"
        case .unknown: "Bluetooth: Unknown (initializing…)"
        @unknown default: "Bluetooth: Unrecognized state"
        }
    }

    private var bluetoothStateColor: Color {
        switch viewModel.bluetoothState {
        case .poweredOn: VepoTheme.Colors.connected
        case .resetting, .unknown: VepoTheme.Colors.warning
        default: VepoTheme.Colors.alert
        }
    }

    // MARK: - Scan Controls

    private var scanControls: some View {
        VStack(alignment: .leading, spacing: VepoTheme.Spacing.sm) {
            VepoSectionHeader(title: "Scan")

            HStack(spacing: VepoTheme.Spacing.sm) {
                if viewModel.isScanning {
                    VepoButton("Stop Scan", icon: "stop.fill", style: .secondary) {
                        viewModel.stopScan()
                    }
                } else {
                    VepoButton("Scan All Devices", icon: "dot.radiowaves.left.and.right") {
                        Task { await viewModel.startScan(permissive: true) }
                    }
                }

                if viewModel.connectionState == .connected {
                    VepoButton("Disconnect", icon: "xmark.circle", style: .ghost) {
                        viewModel.disconnect()
                    }
                }
            }

            Text("Permissive scan ignores the configured Vepo service UUID and lists every nearby BLE device — useful for finding your bottle when its firmware advertises different UUIDs.")
                .font(VepoTheme.Typography.caption)
                .foregroundStyle(VepoTheme.Colors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Devices

    private var devicesSection: some View {
        VStack(alignment: .leading, spacing: VepoTheme.Spacing.sm) {
            VepoSectionHeader(title: "Discovered Devices (\(viewModel.discoveredDevices.count))")

            if viewModel.discoveredDevices.isEmpty {
                Text(viewModel.isScanning ? "Scanning…" : "No devices yet. Tap \"Scan All Devices\" above.")
                    .font(VepoTheme.Typography.subheadline)
                    .foregroundStyle(VepoTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .vepoCardStyle()
            } else {
                ForEach(viewModel.sortedDevices) { device in
                    deviceRow(device)
                }
            }
        }
    }

    private func deviceRow(_ device: DiscoveredDevice) -> some View {
        Button {
            Task { await viewModel.connect(to: device) }
        } label: {
            VStack(alignment: .leading, spacing: VepoTheme.Spacing.xs) {
                HStack {
                    Text(device.displayName)
                        .font(VepoTheme.Typography.headline)
                        .foregroundStyle(VepoTheme.Colors.textPrimary)
                    if device.isVepoCandidate {
                        Text("Vepo")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(VepoTheme.Colors.accent.opacity(0.15))
                            .foregroundStyle(VepoTheme.Colors.accent)
                            .clipShape(Capsule())
                    }
                    Spacer()
                    Text("\(device.rssi) dBm")
                        .font(VepoTheme.Typography.caption.monospacedDigit())
                        .foregroundStyle(VepoTheme.Colors.textSecondary)
                }

                Text("ID: \(device.peripheral.identifier.uuidString)")
                    .font(VepoTheme.Typography.caption.monospaced())
                    .foregroundStyle(VepoTheme.Colors.textTertiary)

                if device.advertisedServiceUUIDs.isEmpty {
                    Text("Advertised services: (none)")
                        .font(VepoTheme.Typography.caption)
                        .foregroundStyle(VepoTheme.Colors.textTertiary)
                } else {
                    ForEach(device.advertisedServiceUUIDs, id: \.uuidString) { uuid in
                        uuidLine(label: "Adv:", uuid: uuid.uuidString)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .vepoCardStyle()
        }
        .buttonStyle(VepoPressFeedback())
    }

    // MARK: - Discovered Services (after connect)

    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: VepoTheme.Spacing.sm) {
            VepoSectionHeader(title: "Discovered Services")

            Text("These are the services and characteristics the connected device exposes. Paste the matching UUIDs into BLEConstants.swift.")
                .font(VepoTheme.Typography.caption)
                .foregroundStyle(VepoTheme.Colors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(viewModel.lastDiscoveredServices) { service in
                serviceCard(service)
            }
        }
    }

    private func serviceCard(_ service: DiscoveredService) -> some View {
        VStack(alignment: .leading, spacing: VepoTheme.Spacing.xs) {
            uuidLine(label: "Service:", uuid: service.uuid.uuidString, highlight: service.uuid == BLEConstants.serviceUUID)

            if service.characteristicUUIDs.isEmpty {
                Text("(no characteristics discovered yet)")
                    .font(VepoTheme.Typography.caption)
                    .foregroundStyle(VepoTheme.Colors.textTertiary)
            } else {
                ForEach(service.characteristicUUIDs, id: \.uuidString) { uuid in
                    uuidLine(
                        label: "Char:",
                        uuid: uuid.uuidString,
                        highlight: uuid == BLEConstants.sensorCharacteristicUUID
                    )
                    .padding(.leading, VepoTheme.Spacing.md)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .vepoCardStyle()
    }

    // MARK: - Helpers

    private func uuidLine(label: String, uuid: String, highlight: Bool = false) -> some View {
        HStack(spacing: VepoTheme.Spacing.xs) {
            Text(label)
                .font(VepoTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(VepoTheme.Colors.textSecondary)
            Text(uuid)
                .font(VepoTheme.Typography.caption.monospaced())
                .foregroundStyle(highlight ? VepoTheme.Colors.connected : VepoTheme.Colors.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            if highlight {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(VepoTheme.Colors.connected)
            }
            Button {
                UIPasteboard.general.string = uuid
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 12))
                    .foregroundStyle(VepoTheme.Colors.accent)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Copy UUID")
        }
    }

    private var footerHint: some View {
        VStack(alignment: .leading, spacing: VepoTheme.Spacing.xs) {
            Text("Configured UUIDs (from BLEConstants.swift)")
                .font(VepoTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(VepoTheme.Colors.textSecondary)
            Text("Service: \(BLEConstants.serviceUUID.uuidString)")
                .font(VepoTheme.Typography.caption.monospaced())
                .foregroundStyle(VepoTheme.Colors.textTertiary)
            Text("Char:    \(BLEConstants.sensorCharacteristicUUID.uuidString)")
                .font(VepoTheme.Typography.caption.monospaced())
                .foregroundStyle(VepoTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .vepoCardStyle()
    }
}
