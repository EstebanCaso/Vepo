import SwiftUI
import CoreBluetooth

/// BLE connection management screen.
/// Shows connection state, scan/pair controls, and discovered peripherals.
struct ConnectionStatusView: View {
    @Environment(ConnectionViewModel.self) private var viewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: VepoTheme.Spacing.lg) {
                    // Status indicator
                    statusSection

                    // Action button
                    actionButton

                    // Discovered peripherals
                    if !viewModel.discoveredPeripherals.isEmpty {
                        peripheralsList
                    }

                    // Help text
                    helpText
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
                .frame(width: 80, height: 80)

            Text(viewModel.statusMessage)
                .font(VepoTheme.Typography.body)
                .foregroundStyle(VepoTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .vepoElevatedStyle()
        .frame(maxWidth: .infinity)
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

            ForEach(viewModel.discoveredPeripherals, id: \.identifier) { peripheral in
                peripheralRow(peripheral)
            }
        }
    }

    private func peripheralRow(_ peripheral: CBPeripheral) -> some View {
        Button {
            Task { await viewModel.connect(to: peripheral) }
        } label: {
            HStack {
                Image(systemName: "waterbottle")
                    .font(.title3)
                    .foregroundStyle(VepoTheme.Colors.accent)

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
                    .font(.caption)
                    .foregroundStyle(VepoTheme.Colors.textTertiary)
            }
            .padding(VepoTheme.Spacing.sm)
            .vepoCardStyle()
        }
        .buttonStyle(VepoPressFeedback())
        .accessibilityLabel("Connect to \(peripheral.name ?? "unknown bottle")")
    }

    // MARK: - Help Text

    private var helpText: some View {
        VStack(spacing: VepoTheme.Spacing.xs) {
            Text("Make sure your Vepo bottle is turned on and nearby.")
                .font(VepoTheme.Typography.footnote)
                .foregroundStyle(VepoTheme.Colors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, VepoTheme.Spacing.md)
    }
}
