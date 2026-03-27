import SwiftUI

// MARK: - VepoCard

struct VepoCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .vepoCardStyle()
    }
}

// MARK: - VepoButton

struct VepoButton: View {
    let title: String
    let icon: String?
    let style: VepoButtonStyle
    let action: () -> Void

    enum VepoButtonStyle {
        case primary
        case secondary
        case ghost
    }

    init(
        _ title: String,
        icon: String? = nil,
        style: VepoButtonStyle = .primary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: VepoTheme.Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.body)
                }
                Text(title)
                    .font(VepoTheme.Typography.headline)
            }
            .frame(minHeight: VepoTheme.Layout.minTouchTarget)
            .padding(.horizontal, VepoTheme.Spacing.lg)
            .foregroundStyle(foregroundColor)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: VepoTheme.Radius.medium))
            .overlay {
                if style == .secondary {
                    RoundedRectangle(cornerRadius: VepoTheme.Radius.medium)
                        .strokeBorder(VepoTheme.Colors.accent, lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(VepoPressFeedback())
        .accessibilityLabel(title)
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: .white
        case .secondary: VepoTheme.Colors.accent
        case .ghost: VepoTheme.Colors.accent
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: VepoTheme.Colors.accent
        case .secondary: .clear
        case .ghost: .clear
        }
    }
}

// MARK: - Press Feedback Button Style

struct VepoPressFeedback: SwiftUI.ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(
                reduceMotion ? .none : VepoTheme.Motion.quick,
                value: configuration.isPressed
            )
    }
}

// MARK: - VepoLabel

struct VepoLabel: View {
    let text: String
    let icon: String
    let color: Color

    init(_ text: String, icon: String, color: Color = VepoTheme.Colors.textSecondary) {
        self.text = text
        self.icon = icon
        self.color = color
    }

    var body: some View {
        Label {
            Text(text)
                .font(VepoTheme.Typography.subheadline)
                .foregroundStyle(VepoTheme.Colors.textSecondary)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(color)
        }
    }
}

// MARK: - VepoSectionHeader

struct VepoSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(VepoTheme.Typography.title3)
            .foregroundStyle(VepoTheme.Colors.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - VepoEmptyState

struct VepoEmptyState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: VepoTheme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(VepoTheme.Colors.textTertiary)
                .accessibilityHidden(true)

            Text(title)
                .font(VepoTheme.Typography.title3)
                .foregroundStyle(VepoTheme.Colors.textPrimary)

            Text(message)
                .font(VepoTheme.Typography.body)
                .foregroundStyle(VepoTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(VepoTheme.Spacing.xl)
    }
}
