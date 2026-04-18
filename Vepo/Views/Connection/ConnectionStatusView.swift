import SwiftUI
import CoreBluetooth

/// BLE connection management screen.
/// Shows connection state with visual indicators, scan/pair controls, and discovered peripherals.
struct ConnectionStatusView: View {
    @Environment(ConnectionViewModel.self) private var viewModel

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            ScrollView {
                VStack(spacing: VepoTheme.Spacing.lg) {
                    statusSection
                        .staggeredAppear(index: 0)

                    actionButton
                        .staggeredAppear(index: 1)

                    if !viewModel.discoveredDevices.isEmpty {
                        peripheralsList
                    } else if viewModel.showsEmptyResults {
                        emptyResultsCard
                            .staggeredAppear(index: 2)
                    }

                    helpText
                        .staggeredAppear(index: 3)
                }
                .padding(VepoTheme.Layout.screenPadding)
            }
            .background(VepoTheme.Colors.background)
            .navigationTitle("Bottle")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.openDiagnostics()
                    } label: {
                        Image(systemName: "stethoscope")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .accessibilityLabel("Open BLE Diagnostics")
                }
            }
            .sheet(isPresented: $viewModel.showDiagnostics) {
                BLEDiagnosticsView()
                    .environment(viewModel)
            }
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(spacing: VepoTheme.Spacing.md) {
            PulsingIndicator(state: viewModel.connectionState)
                .frame(width: 90, height: 90)

            Text(viewModel.statusMessage)
                .font(VepoTheme.Typography.body)
                .foregroundStyle(VepoTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, VepoTheme.Spacing.lg)
        .padding(.horizontal, VepoTheme.Layout.cardPadding)
        .background(statusTintColor.opacity(0.05))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: VepoTheme.Radius.xlarge))
        .overlay(
            RoundedRectangle(cornerRadius: VepoTheme.Radius.xlarge)
                .strokeBorder(statusTintColor.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(
            color: VepoTheme.Shadow.elevated.color,
            radius: VepoTheme.Shadow.elevated.radius,
            x: VepoTheme.Shadow.elevated.x,
            y: VepoTheme.Shadow.elevated.y
        )
    }

    private var statusTintColor: Color {
        switch viewModel.connectionState {
        case .connected: VepoTheme.Colors.connected
        case .scanning, .connecting, .discoveringServices: VepoTheme.Colors.scanning
        default: VepoTheme.Colors.disconnected
        }
    }

    // MARK: - Action Button

    private var actionButton: some View {
        Group {
            switch viewModel.connectionState {
            case .idle, .disconnected:
                VepoButton("Scan for Bottle", icon: "magnifyingglass") {
                    Task { await viewModel.startScan() }
                }

            case .scanning:
                VepoButton("Stop Scanning", icon: "stop.fill", style: .secondary) {
                    viewModel.stopScan()
                }

            case .connected:
                VepoButton("Disconnect", icon: "xmark.circle", style: .ghost) {
                    viewModel.disconnect()
                }

            default:
                EmptyView()
            }
        }
    }

    // MARK: - Peripherals List

    private var peripheralsList: some View {
        VStack(alignment: .leading, spacing: VepoTheme.Spacing.sm) {
            VepoSectionHeader(title: "Nearby Bottles")

            ForEach(Array(viewModel.sortedDevices.enumerated()), id: \.element.id) { index, device in
                peripheralRow(device)
                    .staggeredAppear(index: index + 3)
            }
        }
    }

    private func peripheralRow(_ device: DiscoveredDevice) -> some View {
        Button {
            Task { await viewModel.connect(to: device) }
        } label: {
            HStack(spacing: VepoTheme.Spacing.sm) {
                Image(systemName: "waterbottle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(VepoTheme.Colors.accent)
                    .frame(width: 36, height: 36)
                    .background(VepoTheme.Colors.accent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: VepoTheme.Radius.small))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: VepoTheme.Spacing.xs) {
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
                    }

                    HStack(spacing: VepoTheme.Spacing.xs) {
                        Image(systemName: rssiIcon(for: device.rssi))
                            .font(.system(size: 10, weight: .medium))
                        Text("\(device.rssi) dBm")
                        Text("·")
                        Text(device.peripheral.identifier.uuidString.prefix(8) + "...")
                    }
                    .font(VepoTheme.Typography.caption)
                    .foregroundStyle(VepoTheme.Colors.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VepoTheme.Colors.textTertiary)
            }
            .vepoCardStyle()
        }
        .buttonStyle(VepoPressFeedback())
        .accessibilityLabel("Connect to \(device.displayName), signal \(device.rssi) dBm")
    }

    private func rssiIcon(for rssi: Int) -> String {
        if rssi >= -75 { return "wifi" }
        if rssi >= -90 { return "wifi.exclamationmark" }
        return "wifi.slash"
    }

    // MARK: - Empty Results

    private var emptyResultsCard: some View {
        VStack(alignment: .leading, spacing: VepoTheme.Spacing.sm) {
            VepoSectionHeader(title: "No bottles found")

            Text("Make sure your Vepo bottle is powered on and within ~10 meters. If it's on but still doesn't appear, open BLE Diagnostics to see every nearby device.")
                .font(VepoTheme.Typography.subheadline)
                .foregroundStyle(VepoTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VepoButton("Open BLE Diagnostics", icon: "stethoscope", style: .secondary) {
                viewModel.openDiagnostics()
            }
            .padding(.top, VepoTheme.Spacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .vepoCardStyle()
    }

    // MARK: - Help Text

    private var helpText: some View {
        Text("Make sure your Vepo bottle is turned on and nearby.")
            .font(VepoTheme.Typography.footnote)
            .foregroundStyle(VepoTheme.Colors.textTertiary)
            .multilineTextAlignment(.center)
            .padding(.top, VepoTheme.Spacing.md)
    }
}
