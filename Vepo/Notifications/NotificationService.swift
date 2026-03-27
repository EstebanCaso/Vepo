import UserNotifications
import OSLog

/// Manages local push notifications for hydration reminders.
/// Schedules a gentle reminder when too much time passes without a drink event.
final class NotificationService: NotificationServiceProtocol, @unchecked Sendable {
    private let center = UNUserNotificationCenter.current()
    private let categoryIdentifier = "HYDRATION_REMINDER"
    private let requestIdentifier = "vepo_hydration_reminder"

    init() {
        registerCategory()
    }

    // MARK: - Permission

    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            AppLogger.notifications.info("Notification permission: \(granted ? "granted" : "denied")")
            return granted
        } catch {
            AppLogger.notifications.error("Permission request failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Scheduling

    func scheduleReminder(afterMinutes minutes: Int) async {
        await cancelPendingReminders()

        let content = UNMutableNotificationContent()
        content.title = "Time for a sip"
        content.body = "It's been a while since your last drink. Consider taking a sip."
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier
        // Interrupt level allows delivery during Focus Mode
        content.interruptionLevel = .timeSensitive

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(minutes * 60),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: requestIdentifier,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            AppLogger.notifications.info("Reminder scheduled for \(minutes) minutes from now")
        } catch {
            AppLogger.notifications.error("Failed to schedule: \(error.localizedDescription)")
        }
    }

    func cancelPendingReminders() async {
        center.removePendingNotificationRequests(
            withIdentifiers: [requestIdentifier]
        )
        AppLogger.notifications.debug("Pending reminders cancelled")
    }

    /// Resets the reminder timer — called after each detected drink event.
    func resetTimer(afterMinutes minutes: Int) async {
        await scheduleReminder(afterMinutes: minutes)
    }

    // MARK: - Category Registration

    /// Registers notification category for Focus Mode pass-through.
    private func registerCategory() {
        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [],
            intentIdentifiers: [],
            options: [.allowInCarPlay]
        )
        center.setNotificationCategories([category])
    }
}
