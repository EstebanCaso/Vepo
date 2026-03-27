import SwiftUI

/// Large ticking counter showing time since last drink.
/// Hero section with gradient progress ring, glow effect, and urgency color shift.
/// Color shifts gradually: green → amber → coral as time increases.
struct LiveCounterView: View {
    let timeSinceLastDrink: TimeInterval
    let urgencyLevel: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let ringSize = VepoTheme.Layout.heroRingSize
    private let strokeWidth = VepoTheme.Layout.heroRingStroke

    var body: some View {
        VStack(spacing: VepoTheme.Spacing.sm) {
            // Hero ring with counter inside
            ZStack {
                // Subtle radial glow behind ring
                VepoTheme.Gradients.glow(color: counterColor)

                // Background ring track
                Circle()
                    .stroke(
                        VepoTheme.Colors.disabled.opacity(0.2),
                        lineWidth: strokeWidth
                    )

                // Glow layer — blurred copy of progress arc for soft neon effect
                progressArc
                    .blur(radius: 12)
                    .opacity(0.5)

                // Progress arc with angular gradient
                progressArc

                // Glowing endpoint dot
                endpointDot

                // Center content: counter + icon
                VStack(spacing: VepoTheme.Spacing.xxs) {
                    Text(timeSinceLastDrink.counterDisplay)
                        .font(VepoTheme.Typography.counterHero)
                        .foregroundStyle(counterColor)
                        .contentTransition(.numericText())
                        .animation(
                            reduceMotion ? .none : VepoTheme.Motion.quick,
                            value: timeSinceLastDrink
                        )
                        .accessibilityLabel(counterAccessibilityLabel)

                    Image(systemName: dropIcon)
                        .font(.system(size: 20, weight: .light))
                        .foregroundStyle(counterColor.opacity(0.5))
                        .scaleEffect(reduceMotion ? 1.0 : dropScale)
                        .animation(
                            reduceMotion ? .none : VepoTheme.Motion.gentle,
                            value: urgencyLevel
                        )
                        .accessibilityHidden(true)
                }
            }
            .frame(width: ringSize, height: ringSize)

            // Subtitle below ring
            Text("since last drink")
                .font(VepoTheme.Typography.subheadline)
                .foregroundStyle(VepoTheme.Colors.textTertiary)
        }
        .padding(.vertical, VepoTheme.Spacing.md)
    }

    // MARK: - Ring Components

    private var progressArc: some View {
        Circle()
            .trim(from: 0, to: min(urgencyLevel, 1.0))
            .stroke(
                VepoTheme.Gradients.ring(urgencyColor: counterColor),
                style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .animation(
                reduceMotion ? .none : VepoTheme.Motion.gentle,
                value: urgencyLevel
            )
    }

    /// Small glowing circle at the end of the progress arc
    private var endpointDot: some View {
        Circle()
            .fill(counterColor)
            .frame(width: strokeWidth + 4, height: strokeWidth + 4)
            .shadow(color: counterColor.opacity(0.6), radius: 6)
            .offset(y: -ringSize / 2)
            .rotationEffect(.degrees(360 * min(urgencyLevel, 1.0) - 90))
            .opacity(urgencyLevel > 0.01 ? 1 : 0)
            .animation(
                reduceMotion ? .none : VepoTheme.Motion.gentle,
                value: urgencyLevel
            )
    }

    // MARK: - Computed

    /// Gradual color shift: green (0) → amber (0.5) → coral (1.0)
    private var counterColor: Color {
        if urgencyLevel < 0.5 {
            return Color(
                hue: lerp(from: 0.38, to: 0.1, t: urgencyLevel * 2),
                saturation: 0.5,
                brightness: 0.75
            )
        } else {
            return Color(
                hue: lerp(from: 0.1, to: 0.03, t: (urgencyLevel - 0.5) * 2),
                saturation: lerp(from: 0.5, to: 0.55, t: (urgencyLevel - 0.5) * 2),
                brightness: 0.78
            )
        }
    }

    private var dropIcon: String {
        urgencyLevel < 0.3 ? "drop.fill" : "drop"
    }

    private var dropScale: CGFloat {
        urgencyLevel < 0.3 ? 1.0 : 0.9
    }

    private var counterAccessibilityLabel: String {
        let minutes = Int(timeSinceLastDrink) / 60
        let seconds = Int(timeSinceLastDrink) % 60
        if minutes > 0 {
            return "\(minutes) minutes and \(seconds) seconds since last drink"
        }
        return "\(seconds) seconds since last drink"
    }

    private func lerp(from a: Double, to b: Double, t: Double) -> Double {
        a + (b - a) * max(0, min(1, t))
    }
}
