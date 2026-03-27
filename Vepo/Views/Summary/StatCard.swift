import SwiftUI

/// Reusable stat display card with icon, label, and value.
struct StatCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: VepoTheme.Spacing.xs) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .accessibilityHidden(true)

            Text(value)
                .font(VepoTheme.Typography.title3)
                .foregroundStyle(VepoTheme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(label)
                .font(VepoTheme.Typography.caption)
                .foregroundStyle(VepoTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .vepoCardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}
