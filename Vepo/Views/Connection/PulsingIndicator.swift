import SwiftUI

/// Animated status indicator with multi-layer pulse and glow effects.
/// Grey = disconnected, pulsing teal = scanning, breathing green = connected.
struct PulsingIndicator: View {
    let state: BLEConnectionState

    @State private var isPulsing = false
    @State private var isBreathing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Outer pulse ring 2 — larger, slower (scanning only)
            if state == .scanning, !reduceMotion {
                Circle()
                    .fill(VepoTheme.Colors.scanning.opacity(0.1))
                    .scaleEffect(isPulsing ? 2.2 : 1.0)
                    .opacity(isPulsing ? 0 : 0.4)
                    .animation(
                        .easeOut(duration: 2.0).repeatForever(autoreverses: false).delay(0.75),
                        value: isPulsing
                    )
            }

            // Outer pulse ring 1 (scanning only)
            if state == .scanning, !reduceMotion {
                Circle()
                    .fill(VepoTheme.Colors.scanning.opacity(0.15))
                    .scaleEffect(isPulsing ? 1.8 : 1.0)
                    .opacity(isPulsing ? 0 : 0.6)
                    .animation(
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: false),
                        value: isPulsing
                    )
            }

            // Inner glow — radial gradient behind solid circle
            Circle()
                .fill(
                    RadialGradient(
                        colors: [indicatorColor.opacity(0.3), indicatorColor.opacity(0)],
                        center: .center,
                        startRadius: innerSize * 0.3,
                        endRadius: innerSize * 0.8
                    )
                )
                .frame(width: innerSize * 1.6, height: innerSize * 1.6)

            // Inner solid circle
            Circle()
                .fill(indicatorColor)
                .frame(width: innerSize, height: innerSize)
                .shadow(color: indicatorColor.opacity(0.3), radius: 8)
                .scaleEffect(breatheScale)

            // Icon overlay
            Image(systemName: iconName)
                .font(.system(size: innerSize * 0.32, weight: .medium))
                .foregroundStyle(.white)
                .scaleEffect(breatheScale)
        }
        .onAppear {
            isPulsing = state == .scanning
            if state == .connected, !reduceMotion {
                withAnimation(VepoTheme.Motion.breathe) { isBreathing = true }
            }
        }
        .onChange(of: state) { _, newState in
            withAnimation { isPulsing = newState == .scanning }
            if newState == .connected, !reduceMotion {
                withAnimation(VepoTheme.Motion.breathe) { isBreathing = true }
            } else {
                isBreathing = false
            }
        }
        .accessibilityLabel("Connection status: \(state.displayName)")
    }

    private var breatheScale: CGFloat {
        (state == .connected && isBreathing && !reduceMotion) ? 1.05 : 1.0
    }

    private var indicatorColor: Color {
        switch state {
        case .connected: VepoTheme.Colors.connected
        case .scanning, .connecting, .discoveringServices: VepoTheme.Colors.scanning
        default: VepoTheme.Colors.disconnected
        }
    }

    private var iconName: String {
        switch state {
        case .connected: "checkmark"
        case .scanning: "antenna.radiowaves.left.and.right"
        case .connecting, .discoveringServices: "ellipsis"
        default: "minus"
        }
    }

    private var innerSize: CGFloat {
        state == .connected ? 64 : 56
    }
}
