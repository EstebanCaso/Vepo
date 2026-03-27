import UserNotifications
import OSLog

/// Manages local push notifications for hydration reminders.
/// Respects notification type, active hours, and pause settings.
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

    /// Schedules a reminder respecting notification type and active hours.
    func scheduleReminder(
        afterMinutes minutes: Int,
        notificationType: NotificationType = .both,
        activeStartHour: Int = 0,
        activeEndHour: Int = 24
    ) async {
        await cancelPendingReminders()

        // Calculate the fire date
        let fireDate = Date.now.addingTimeInterval(TimeInterval(minutes * 60))

        // If fire date is outside active hours, push to next active window
        let adjustedFireDate = adjustForActiveHours(
            fireDate: fireDate,
            startHour: activeStartHour,
            endHour: activeEndHour
        )

        let content = UNMutableNotificationContent()
        content.title = "Time for a sip"
        content.body = "It's been a while since your last drink. Consider taking a sip."
        content.categoryIdentifier = categoryIdentifier
        content.interruptionLevel = .timeSensitive

        // Respect notification type preference
        switch notificationType {
        case .vibration:
            // No sound — iOS will still vibrate for .timeSensitive
            content.sound = nil
        case .visual:
            // Silent notification — visual banner only
            content.sound = nil
        case .both:
            content.sound = .default
        }

        let interval = adjustedFireDate.timeIntervalSince(.now)
        guard interval > 0 else { return }

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: interval,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: requestIdentifier,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            AppLogger.notifications.info("Reminder scheduled for \(Int(interval / 60)) minutes from now (type: \(notificationType.rawValue))")
        } catch {
            AppLogger.notifications.error("Failed to schedule: \(error.localizedDescription)")
        }
    }

    /// Legacy convenience — schedules with default type/hours.
    func scheduleReminder(afterMinutes minutes: Int) async {
        await scheduleReminder(
            afterMinutes: minutes,
            notificationType: .both,
            activeStartHour: 0,
            activeEndHour: 24
        )
    }

    func cancelPendingReminders() async {
        center.removePendingNotificationRequests(
            withIdentifiers: [requestIdentifier]
        )
        AppLogger.notifications.debug("Pending reminders cancelled")
    }

    /// Resets the reminder timer with full settings context.
    func resetTimer(
        afterMinutes minutes: Int,
        notificationType: NotificationType = .both,
        activeStartHour: Int = 0,
        activeEndHour: Int = 24
    ) async {
        await scheduleReminder(
            afterMinutes: minutes,
            notificationType: notificationType,
            activeStartHour: activeStartHour,
            activeEndHour: activeEndHour
        )
    }

    /// Legacy convenience.
    func resetTimer(afterMinutes minutes: Int) async {
        await scheduleReminder(afterMinutes: minutes)
    }

    // MARK: - Active Hours Logic

    /// If the fire date falls outside active hours, push it to the next active window.
    /// e.g. active 8-22, fire at 23:30 → push to 08:00 next day.
    private func adjustForActiveHours(
        fireDate: Date,
        startHour: Int,
        endHour: Int
    ) -> Date {
        // If hours cover the full day, no adjustment needed
        guard startHour != 0 || endHour != 24 else { return fireDate }
        guard startHour < endHour else { return fireDate }

        let calendar = Calendar.current
        let fireHour = calendar.component(.hour, from: fireDate)

        if fireHour >= startHour && fireHour < endHour {
            // Within active hours — no change
            return fireDate
        }

        // Outside active hours — schedule for the next active start
        if fireHour >= endHour {
            // Past end hour today → next day at startHour
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: fireDate),
                  let nextStart = calendar.date(
                      bySettingHour: startHour, minute: 0, second: 0, of: tomorrow
                  ) else { return fireDate }
            return nextStart
        } else {
            // Before start hour today → today at startHour
            guard let todayStart = calendar.date(
                bySettingHour: startHour, minute: 0, second: 0, of: fireDate
            ) else { return fireDate }
            return todayStart
        }
    }

    // MARK: - Category Registration

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
