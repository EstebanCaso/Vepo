import Foundation

/// Protocol for notification scheduling — enables DI and testability.
protocol NotificationServiceProtocol: Sendable {
    func requestPermission() async -> Bool
    func scheduleReminder(afterMinutes minutes: Int) async
    func cancelPendingReminders() async
    func resetTimer(afterMinutes minutes: Int) async
}
