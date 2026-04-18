import SwiftUI

/// Compact 24-hour bar chart of today's drinks.
/// Each column = one hour; bar height scales with that hour's drink count.
/// The current hour is highlighted; empty hours show a faint baseline tick.
struct DailyRhythmView: View {
    let hourlyCounts: [Int]
    let currentHour: Int

    private let columnHeight: CGFloat = 44

    var body: some View {
        let maxCount = max(hourlyCounts.max() ?? 1, 1)

        VStack(alignment: .leading, spacing: VepoTheme.Spacing.xs) {
            HStack(spacing: 3) {
                ForEach(0..<24, id: \.self) { hour in
                    bar(for: hour, maxCount: maxCount)
                }
            }
            .frame(height: columnHeight)

            HStack {
                Text("12 AM")
                Spacer()
                Text("12 PM")
                Spacer()
                Text("11 PM")
            }
            .font(VepoTheme.Typography.caption.monospacedDigit())
            .foregroundStyle(VepoTheme.Colors.textTertiary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today's hourly drink rhythm")
        .accessibilityValue(rhythmAccessibilityValue)
    }

    private func bar(for hour: Int, maxCount: Int) -> some View {
        let count = hourlyCounts[safe: hour] ?? 0
        let isCurrent = hour == currentHour
        let normalized = CGFloat(count) / CGFloat(maxCount)
        let height = max(normalized * columnHeight, count > 0 ? 6 : 2)
        let color: Color = count == 0
            ? VepoTheme.Colors.disabled.opacity(0.4)
            : (isCurrent ? VepoTheme.Colors.accent : VepoTheme.Colors.accent.opacity(0.65))

        return VStack {
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(color)
                .frame(height: height)
        }
        .frame(maxWidth: .infinity)
    }

    private var rhythmAccessibilityValue: String {
        let total = hourlyCounts.reduce(0, +)
        return "\(total) drinks across the day"
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
