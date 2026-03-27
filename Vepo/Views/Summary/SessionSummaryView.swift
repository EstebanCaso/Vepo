import SwiftUI

/// Main dashboard — the first thing the user sees.
/// Shows live counter, today's stats, and connection status at a glance.
struct SessionSummaryView: View {
    @Environment(SessionViewModel.self) private var viewModel
    @Environment(ConnectionViewModel.self) private var connectionVM
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: VepoTheme.Spacing.lg) {
                    // Connection status pill
                    connectionBadge

                    // Hero: Live counter
                    LiveCounterView(
                        timeSinceLastDrink: viewModel.timeSinceLastDrink,
                        urgencyLevel: viewModel.urgencyLevel
                    )
                    .padding(.vertical, VepoTheme.Spacing.md)

                    // Stats cards
                    statsRow

                    // Last drink info
                    if let lastDrink = viewModel.lastDrinkTime {
                        VepoLabel(
                            "Last drink: \(lastDrink.shortTimeString)",
                            icon: "clock",
                            color: VepoTheme.Colors.accent
                        )
                    }
                }
                .padding(VepoTheme.Layout.screenPadding)
            }
            .background(VepoTheme.Colors.background)
            .navigationTitle("Vepo")
            .task {
                await viewModel.start()
            }
        }
    }

    // MARK: - Connection Badge

    private var connectionBadge: some View {
        HStack(spacing: VepoTheme.Spacing.xs) {
            Circle()
                .fill(connectionStatusColor)
                .frame(width: 8, height: 8)

            Text(connectionVM.connectionState.displayName)
                .font(VepoTheme.Typography.caption)
                .foregroundStyle(VepoTheme.Colors.textSecondary)
        }
        .padding(.horizontal, VepoTheme.Spacing.sm)
        .padding(.vertical, VepoTheme.Spacing.xxs)
        .background(VepoTheme.Colors.surfaceElevated)
        .clipShape(Capsule())
        .accessibilityLabel("Bottle status: \(connectionVM.connectionState.displayName)")
    }

    private var connectionStatusColor: Color {
        switch connectionVM.connectionState {
        case .connected: VepoTheme.Colors.connected
        case .scanning, .connecting, .discoveringServices: VepoTheme.Colors.scanning
        default: VepoTheme.Colors.disconnected
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: VepoTheme.Spacing.sm) {
            StatCard(
                icon: "drop.fill",
                label: "Today",
                value: "\(viewModel.totalEventsToday)",
                color: VepoTheme.Colors.accent
            )

            StatCard(
                icon: "clock.arrow.2.circlepath",
                label: "Longest Gap",
                value: viewModel.longestGapToday > 0
                    ? viewModel.longestGapToday.relativeDisplay
                    : "—",
                color: VepoTheme.Colors.warning
            )

            StatCard(
                icon: "chart.line.uptrend.xyaxis",
                label: "Avg Interval",
                value: viewModel.averageInterval > 0
                    ? viewModel.averageInterval.relativeDisplay
                    : "—",
                color: VepoTheme.Colors.success
            )
        }
    }
}
