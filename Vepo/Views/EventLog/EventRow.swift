import SwiftUI

/// Single drink event row — shows timestamp, duration pill, and interval with accent bar.
struct EventRow: View {
    let event: DrinkEvent

    var body: some View {
        HStack(spacing: VepoTheme.Spacing.sm) {
            // Left accent bar — colored by gap urgency
            RoundedRectangle(cornerRadius: 2)
                .fill(accentBarColor)
                .frame(width: 3, height: 40)

            // Time and duration
            VStack(alignment: .leading, spacing: VepoTheme.Spacing.xxs) {
                Text(event.timestamp.shortTimeString)
                    .font(VepoTheme.Typography.title3)
                    .foregroundStyle(VepoTheme.Colors.textPrimary)

                // Duration pill
                Text(event.eventDuration.durationDisplay)
                    .font(VepoTheme.Typography.caption)
                    .foregroundStyle(VepoTheme.Colors.textSecondary)
                    .padding(.horizontal, VepoTheme.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(VepoTheme.Colors.disabled.opacity(0.3))
                    .clipShape(Capsule())
            }

            Spacer()

            // Interval since previous drink
            if let gap = event.timeSinceLastDrink {
                VStack(alignment: .trailing, spacing: VepoTheme.Spacing.xxs) {
                    Text(gap.relativeDisplay)
                        .font(VepoTheme.Typography.headline)
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

    // MARK: - Colors

    private var accentBarColor: Color {
        if let gap = event.timeSinceLastDrink {
            return gapColor(for: gap)
        }
        return VepoTheme.Colors.accent
    }

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
