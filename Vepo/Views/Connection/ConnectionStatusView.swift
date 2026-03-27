import SwiftUI
import CoreBluetooth

/// BLE connection management screen.
/// Shows connection state with visual indicators, scan/pair controls, and discovered peripherals.
struct ConnectionStatusView: View {
    @Environment(ConnectionViewModel.self) private var viewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: VepoTheme.Spacing.lg) {
                    // Status indicator
                    statusSection
                        .staggeredAppear(index: 0)

                    // Action button
                    actionButton
                        .staggeredAppear(index: 1)

                    // Discovered peripherals
                    if !viewModel.discoveredPeripherals.isEmpty {
                        peripheralsList
                    }

                    // Help text
                    helpText
                        .staggeredAppear(index: 2)
                }
                .padding(VepoTheme.Layout.screenPadding)
            }
            .background(VepoTheme.Colors.background)
            .navigationTitle("Bottle")
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

            ForEach(Array(viewModel.discoveredPeripherals.enumerated()), id: \.element.identifier) { index, peripheral in
                peripheralRow(peripheral)
                    .staggeredAppear(index: index + 3)
            }
        }
    }

    private func peripheralRow(_ peripheral: CBPeripheral) -> some View {
        Button {
            Task { await viewModel.connect(to: peripheral) }
        } label: {
            HStack(spacing: VepoTheme.Spacing.sm) {
                Image(systemName: "waterbottle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(VepoTheme.Colors.accent)
                    .frame(width: 36, height: 36)
                    .background(VepoTheme.Colors.accent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: VepoTheme.Radius.small))

                VStack(alignment: .leading, spacing: 2) {
                    Text(peripheral.name ?? "Unknown Bottle")
                        .font(VepoTheme.Typography.headline)
                        .foregroundStyle(VepoTheme.Colors.textPrimary)

                    Text(peripheral.identifier.uuidString.prefix(8) + "...")
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
        .accessibilityLabel("Connect to \(peripheral.name ?? "unknown bottle")")
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
