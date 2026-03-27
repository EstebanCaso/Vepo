import Foundation
import SwiftData
import UserNotifications

/// ViewModel for user settings.
/// Loads/saves UserSettings from SwiftData and notifies the notification service.
@Observable
final class SettingsViewModel {
    private let dataStore: LocalDataStore
    private let notificationService: NotificationService

    // MARK: - State

    var reminderMinutes: Int = 60
    var notificationType: NotificationType = .both
    var isPaused: Bool = false
    var activeStartHour: Int = 8
    var activeEndHour: Int = 22
    var hasNotificationPermission: Bool = false

    // MARK: - Init

    init(dataStore: LocalDataStore, notificationService: NotificationService) {
        self.dataStore = dataStore
        self.notificationService = notificationService
    }

    // MARK: - Lifecycle

    func load() async {
        do {
            let settings = try await dataStore.loadSettings()
            reminderMinutes = settings.reminderWaitMinutes
            notificationType = settings.notificationType
            isPaused = settings.isPaused
            activeStartHour = settings.activeStartHour
            activeEndHour = settings.activeEndHour
        } catch {
            AppLogger.persistence.error("Failed to load settings: \(error.localizedDescription)")
        }

        // Check current permission status without re-prompting
        let settings2 = await UNUserNotificationCenter.current().notificationSettings()
        hasNotificationPermission = settings2.authorizationStatus == .authorized
    }

    func save() async {
        do {
            let settings = try await dataStore.loadSettings()
            settings.reminderWaitMinutes = reminderMinutes
            settings.notificationType = notificationType
            settings.isPaused = isPaused
            settings.activeStartHour = activeStartHour
            settings.activeEndHour = activeEndHour
            try await dataStore.saveSettings(settings)

            if !isPaused {
                await notificationService.resetTimer(
                    afterMinutes: reminderMinutes,
                    notificationType: notificationType,
                    activeStartHour: activeStartHour,
                    activeEndHour: activeEndHour
                )
            } else {
                await notificationService.cancelPendingReminders()
            }
        } catch {
            AppLogger.persistence.error("Failed to save settings: \(error.localizedDescription)")
        }
    }
}
