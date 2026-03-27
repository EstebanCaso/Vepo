import SwiftUI

// MARK: - Vepo Design System
// Calming, accessibility-first design for autistic users.
// Muted teal/blue palette, SF Rounded headings, minimal cognitive load.

enum VepoTheme {

    // MARK: - Color Tokens (Semantic)

    enum Colors {
        // Primary surfaces
        static let background = Color(hex: 0xF0F4F8)        // Soft blue-grey — low-stimulation base
        static let surface = Color.white                      // Card/sheet surfaces
        static let surfaceElevated = Color(hex: 0xFAFCFE)   // Slightly lifted surface

        // Brand accent
        static let accent = Color(hex: 0x5BA4B5)            // Calm teal — primary interactive
        static let accentSoft = Color(hex: 0x5BA4B5).opacity(0.15) // Tinted backgrounds

        // Text hierarchy
        static let textPrimary = Color(hex: 0x2D3748)       // Warm dark grey — high readability
        static let textSecondary = Color(hex: 0x718096)      // Muted grey — supporting text
        static let textTertiary = Color(hex: 0xA0AEC0)       // Light grey — hints/placeholders

        // Semantic states (muted, not alarming)
        static let success = Color(hex: 0x68D391)            // Soft green — recent drink
        static let warning = Color(hex: 0xF6AD55)            // Gentle amber — time passing
        static let alert = Color(hex: 0xE8806A)              // Muted coral — long gap (NOT harsh red)

        // Interactive states
        static let buttonPressed = Color(hex: 0x4A8A99)      // Darker teal for press feedback
        static let disabled = Color(hex: 0xCBD5E0)           // Light grey for disabled elements

        // BLE connection states
        static let connected = Color(hex: 0x68D391)          // Green — connected
        static let scanning = Color(hex: 0x5BA4B5)           // Teal — scanning
        static let disconnected = Color(hex: 0xA0AEC0)       // Grey — disconnected
    }

    // MARK: - Typography

    enum Typography {
        // SF Rounded for headings — friendly, approachable, less clinical
        static let largeTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
        static let title = Font.system(.title, design: .rounded, weight: .semibold)
        static let title2 = Font.system(.title2, design: .rounded, weight: .semibold)
        static let title3 = Font.system(.title3, design: .rounded, weight: .medium)

        // SF Pro (default) for body — clean, readable
        static let headline = Font.system(.headline)
        static let body = Font.system(.body)
        static let callout = Font.system(.callout)
        static let subheadline = Font.system(.subheadline)
        static let footnote = Font.system(.footnote)
        static let caption = Font.system(.caption)

        // Monospaced for the live counter (tabular figures prevent layout shift)
        static let counter = Font.system(.largeTitle, design: .monospaced, weight: .light)
        static let counterSmall = Font.system(.title, design: .monospaced, weight: .light)
    }

    // MARK: - Spacing (8pt Grid System)

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Corner Radius

    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let pill: CGFloat = 100
    }

    // MARK: - Shadows (subtle, low-stimulation)

    enum Shadow {
        static let card = ShadowStyle(
            color: Color.black.opacity(0.06),
            radius: 8,
            x: 0,
            y: 2
        )
        static let elevated = ShadowStyle(
            color: Color.black.opacity(0.1),
            radius: 16,
            x: 0,
            y: 4
        )
    }

    // MARK: - Animation

    enum Motion {
        static let quick: Animation = .easeOut(duration: 0.15)
        static let standard: Animation = .easeOut(duration: 0.25)
        static let gentle: Animation = .easeInOut(duration: 0.4)
        static let spring: Animation = .spring(response: 0.35, dampingFraction: 0.7)
    }

    // MARK: - Layout

    enum Layout {
        static let minTouchTarget: CGFloat = 44  // Apple HIG minimum
        static let cardPadding: CGFloat = Spacing.md
        static let screenPadding: CGFloat = Spacing.md
    }
}

// MARK: - Shadow Style Helper

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Color Hex Initializer

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}

// MARK: - View Modifiers

extension View {
    func vepoCardStyle() -> some View {
        self
            .padding(VepoTheme.Layout.cardPadding)
            .background(VepoTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: VepoTheme.Radius.large))
            .shadow(
                color: VepoTheme.Shadow.card.color,
                radius: VepoTheme.Shadow.card.radius,
                x: VepoTheme.Shadow.card.x,
                y: VepoTheme.Shadow.card.y
            )
    }

    func vepoElevatedStyle() -> some View {
        self
            .padding(VepoTheme.Layout.cardPadding)
            .background(VepoTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: VepoTheme.Radius.large))
            .shadow(
                color: VepoTheme.Shadow.elevated.color,
                radius: VepoTheme.Shadow.elevated.radius,
                x: VepoTheme.Shadow.elevated.x,
                y: VepoTheme.Shadow.elevated.y
            )
    }

    /// Conditionally applies animation only when reduce motion is off
    func vepoAnimation(_ animation: Animation, reduceMotion: Bool) -> some View {
        self.animation(reduceMotion ? .none : animation, value: UUID())
    }
}
