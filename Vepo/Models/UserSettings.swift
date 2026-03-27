import Foundation
import SwiftData

/// User-configurable preferences — persisted as a singleton in SwiftData.
@Model
final class UserSettings {
    /// Minutes before a hydration reminder fires (default: 60)
    var reminderWaitMinutes: Int

    /// Type of notification to deliver
    var notificationTypeRaw: String

    /// Whether reminders are currently paused
    var isPaused: Bool

    /// Hour when daily reminders start (e.g. 8 for 8:00 AM)
    var activeStartHour: Int

    /// Hour when daily reminders stop (e.g. 22 for 10:00 PM)
    var activeEndHour: Int

    var notificationType: NotificationType {
        get { NotificationType(rawValue: notificationTypeRaw) ?? .both }
        set { notificationTypeRaw = newValue.rawValue }
    }

    init(
        reminderWaitMinutes: Int = 60,
        notificationType: NotificationType = .both,
        isPaused: Bool = false,
        activeStartHour: Int = 8,
        activeEndHour: Int = 22
    ) {
        self.reminderWaitMinutes = reminderWaitMinutes
        self.notificationTypeRaw = notificationType.rawValue
        self.isPaused = isPaused
        self.activeStartHour = activeStartHour
        self.activeEndHour = activeEndHour
    }
}

// MARK: - Notification Type

enum NotificationType: String, CaseIterable, Sendable {
    case vibration
    case visual
    case both

    var displayName: String {
        switch self {
        case .vibration: "Vibration only"
        case .visual: "Visual only"
        case .both: "Both"
        }
    }

    var icon: String {
        switch self {
        case .vibration: "iphone.radiowaves.left.and.right"
        case .visual: "bell"
        case .both: "bell.and.waves.left.and.right"
        }
    }
}
