import CoreHaptics
import OSLog

/// Provides subtle haptic feedback for drink detection confirmation.
/// Gracefully degrades on devices without haptic support.
final class HapticService: @unchecked Sendable {
    private var engine: CHHapticEngine?
    private var supportsHaptics: Bool

    init() {
        supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics

        guard supportsHaptics else {
            AppLogger.notifications.info("Device does not support haptics")
            return
        }

        do {
            engine = try CHHapticEngine()
            engine?.resetHandler = { [weak self] in
                self?.restartEngine()
            }
            try engine?.start()
        } catch {
            AppLogger.notifications.error("Haptic engine init failed: \(error.localizedDescription)")
            supportsHaptics = false
        }
    }

    /// Plays a subtle double-tap pattern for drink detection confirmation.
    /// Designed to be gentle and non-jarring for sensory-sensitive users.
    func playDrinkConfirmation() {
        guard supportsHaptics, let engine else { return }

        do {
            // Gentle double-tap: two soft transients with a brief pause
            let events: [CHHapticEvent] = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3),
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2),
                    ],
                    relativeTime: 0.12
                ),
            ]

            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            AppLogger.notifications.debug("Haptic play failed: \(error.localizedDescription)")
        }
    }

    /// Plays a gentle single pulse for connection events.
    func playConnectionFeedback() {
        guard supportsHaptics, let engine else { return }

        do {
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4),
                ],
                relativeTime: 0
            )
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            AppLogger.notifications.debug("Haptic play failed: \(error.localizedDescription)")
        }
    }

    private func restartEngine() {
        do {
            try engine?.start()
        } catch {
            AppLogger.notifications.error("Haptic engine restart failed: \(error.localizedDescription)")
            supportsHaptics = false
        }
    }
}
