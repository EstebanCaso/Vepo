import SwiftUI

/// Reusable stat display card with icon, label, and value.
/// Tinted glassmorphic background matching semantic color.
struct StatCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: VepoTheme.Spacing.xs) {
            // Icon in a tinted circle
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.15))
                .clipShape(Circle())
                .accessibilityHidden(true)

            Text(value)
                .font(VepoTheme.Typography.title2)
                .foregroundStyle(VepoTheme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(VepoTheme.Typography.caption)
                .foregroundStyle(VepoTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .vepoTintedCardStyle(tint: color)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}
