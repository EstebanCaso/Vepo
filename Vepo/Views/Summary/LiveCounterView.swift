import SwiftUI

/// Large ticking counter showing time since last drink.
/// Color shifts gradually: green → amber → coral as time increases.
struct LiveCounterView: View {
    let timeSinceLastDrink: TimeInterval
    let urgencyLevel: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: VepoTheme.Spacing.xs) {
            Text("Time since last drink")
                .font(VepoTheme.Typography.subheadline)
                .foregroundStyle(VepoTheme.Colors.textSecondary)

            Text(timeSinceLastDrink.counterDisplay)
                .font(VepoTheme.Typography.counter)
                .foregroundStyle(counterColor)
                .contentTransition(.numericText())
                .animation(
                    reduceMotion ? .none : VepoTheme.Motion.quick,
                    value: timeSinceLastDrink
                )
                .accessibilityLabel(counterAccessibilityLabel)

            // Subtle progress arc
            ZStack {
                Circle()
                    .stroke(
                        VepoTheme.Colors.disabled.opacity(0.3),
                        lineWidth: 4
                    )

                Circle()
                    .trim(from: 0, to: min(urgencyLevel, 1.0))
                    .stroke(
                        counterColor,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(
                        reduceMotion ? .none : VepoTheme.Motion.gentle,
                        value: urgencyLevel
                    )
            }
            .frame(width: 200, height: 200)
            .overlay {
                // Water drop icon in center
                Image(systemName: dropIcon)
                    .font(.system(size: 32))
                    .foregroundStyle(counterColor.opacity(0.6))
                    .accessibilityHidden(true)
            }
        }
        .vepoElevatedStyle()
    }

    // MARK: - Computed

    /// Gradual color shift: green (0) → amber (0.5) → coral (1.0)
    private var counterColor: Color {
        if urgencyLevel < 0.5 {
            // Green to amber
            return Color(
                hue: lerp(from: 0.38, to: 0.1, t: urgencyLevel * 2),  // green to amber hue
                saturation: 0.5,
                brightness: 0.75
            )
        } else {
            // Amber to coral (muted, not harsh red)
            return Color(
                hue: lerp(from: 0.1, to: 0.03, t: (urgencyLevel - 0.5) * 2),
                saturation: lerp(from: 0.5, to: 0.55, t: (urgencyLevel - 0.5) * 2),
                brightness: 0.78
            )
        }
    }

    private var dropIcon: String {
        urgencyLevel < 0.3 ? "drop.fill" : "drop.halffull"
    }

    private var counterAccessibilityLabel: String {
        let minutes = Int(timeSinceLastDrink) / 60
        let seconds = Int(timeSinceLastDrink) % 60
        if minutes > 0 {
            return "\(minutes) minutes and \(seconds) seconds since last drink"
        }
        return "\(seconds) seconds since last drink"
    }

    /// Linear interpolation helper
    private func lerp(from a: Double, to b: Double, t: Double) -> Double {
        a + (b - a) * max(0, min(1, t))
    }
}
