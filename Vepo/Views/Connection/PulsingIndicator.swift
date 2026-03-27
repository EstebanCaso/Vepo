import SwiftUI

/// Animated status indicator dot.
/// Grey = disconnected, pulsing teal = scanning, solid green = connected.
struct PulsingIndicator: View {
    let state: BLEConnectionState

    @State private var isPulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Outer pulse ring (scanning only)
            if state == .scanning, !reduceMotion {
                Circle()
                    .fill(VepoTheme.Colors.scanning.opacity(0.2))
                    .scaleEffect(isPulsing ? 1.8 : 1.0)
                    .opacity(isPulsing ? 0 : 0.6)
                    .animation(
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: false),
                        value: isPulsing
                    )
            }

            // Inner circle
            Circle()
                .fill(indicatorColor)
                .frame(width: innerSize, height: innerSize)

            // Icon overlay
            Image(systemName: iconName)
                .font(.system(size: innerSize * 0.35, weight: .medium))
                .foregroundStyle(.white)
        }
        .onAppear {
            isPulsing = state == .scanning
        }
        .onChange(of: state) { _, newState in
            isPulsing = newState == .scanning
        }
        .accessibilityLabel("Connection status: \(state.displayName)")
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
        state == .connected ? 56 : 48
    }
}
