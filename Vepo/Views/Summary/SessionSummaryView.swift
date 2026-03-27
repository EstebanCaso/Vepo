import SwiftUI

/// Main dashboard — the first thing the user sees.
/// Shows live counter hero, today's stats, and connection status at a glance.
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
                        .staggeredAppear(index: 0)

                    // Hero: Live counter ring
                    LiveCounterView(
                        timeSinceLastDrink: viewModel.timeSinceLastDrink,
                        urgencyLevel: viewModel.urgencyLevel
                    )
                    .staggeredAppear(index: 1)

                    // Stats cards
                    statsRow

                    // Last drink info pill
                    if let lastDrink = viewModel.lastDrinkTime {
                        lastDrinkPill(time: lastDrink.shortTimeString)
                            .staggeredAppear(index: 5)
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
        .padding(.vertical, VepoTheme.Spacing.xxs + 2)
        .background(connectionStatusColor.opacity(0.1))
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule().strokeBorder(connectionStatusColor.opacity(0.2), lineWidth: 0.5)
        )
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
            .staggeredAppear(index: 2)

            StatCard(
                icon: "clock.arrow.2.circlepath",
                label: "Longest Gap",
                value: viewModel.longestGapToday > 0
                    ? viewModel.longestGapToday.relativeDisplay
                    : "\u{2014}",
                color: VepoTheme.Colors.warning
            )
            .staggeredAppear(index: 3)

            StatCard(
                icon: "chart.line.uptrend.xyaxis",
                label: "Avg Interval",
                value: viewModel.averageInterval > 0
                    ? viewModel.averageInterval.relativeDisplay
                    : "\u{2014}",
                color: VepoTheme.Colors.success
            )
            .staggeredAppear(index: 4)
        }
    }

    // MARK: - Last Drink Pill

    private func lastDrinkPill(time: String) -> some View {
        HStack(spacing: VepoTheme.Spacing.xs) {
            Image(systemName: "clock")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(VepoTheme.Colors.accent)

            Text("Last drink: \(time)")
                .font(VepoTheme.Typography.subheadline)
                .foregroundStyle(VepoTheme.Colors.textSecondary)
        }
        .padding(.horizontal, VepoTheme.Spacing.md)
        .padding(.vertical, VepoTheme.Spacing.xs)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule().strokeBorder(VepoTheme.Colors.glassBorder, lineWidth: 0.5)
        )
    }
}
