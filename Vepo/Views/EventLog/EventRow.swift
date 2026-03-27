import SwiftUI

/// Single drink event row — shows timestamp, duration, and interval.
struct EventRow: View {
    let event: DrinkEvent

    var body: some View {
        HStack {
            // Time and duration
            VStack(alignment: .leading, spacing: VepoTheme.Spacing.xxs) {
                Text(event.timestamp.shortTimeString)
                    .font(VepoTheme.Typography.headline)
                    .foregroundStyle(VepoTheme.Colors.textPrimary)

                Text("Duration: \(event.eventDuration.durationDisplay)")
                    .font(VepoTheme.Typography.caption)
                    .foregroundStyle(VepoTheme.Colors.textSecondary)
            }

            Spacer()

            // Interval since previous drink
            if let gap = event.timeSinceLastDrink {
                VStack(alignment: .trailing, spacing: VepoTheme.Spacing.xxs) {
                    Text(gap.relativeDisplay)
                        .font(VepoTheme.Typography.subheadline)
                        .foregroundStyle(gapColor(for: gap))

                    Text("since previous")
                        .font(VepoTheme.Typography.caption)
                        .foregroundStyle(VepoTheme.Colors.textTertiary)
                }
            } else {
                Text("First today")
                    .font(VepoTheme.Typography.caption)
                    .foregroundStyle(VepoTheme.Colors.textTertiary)
            }
        }
        .padding(.vertical, VepoTheme.Spacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    /// Muted color based on gap length
    private func gapColor(for gap: TimeInterval) -> Color {
        let minutes = gap / 60
        if minutes < 30 {
            return VepoTheme.Colors.success
        } else if minutes < 60 {
            return VepoTheme.Colors.warning
        } else {
            return VepoTheme.Colors.alert
        }
    }

    private var accessibilityText: String {
        var text = "Drink at \(event.timestamp.shortTimeString), lasted \(event.eventDuration.durationDisplay)"
        if let gap = event.timeSinceLastDrink {
            text += ", \(gap.relativeDisplay) after previous"
        }
        return text
    }
}
