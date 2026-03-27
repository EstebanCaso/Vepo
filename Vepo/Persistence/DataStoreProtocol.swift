import Foundation

/// Protocol for data persistence — enables DI and testability.
protocol DataStoreProtocol: Sendable {
    // MARK: - Drink Events

    func saveDrinkEvent(_ event: DrinkEvent) async throws
    func fetchEvents(for date: Date) async throws -> [DrinkEvent]
    func fetchLatestEvent() async throws -> DrinkEvent?
    func deleteEvent(_ event: DrinkEvent) async throws

    // MARK: - Sessions

    func fetchCurrentSession() async throws -> HydrationSession?
    func startNewSession() async throws -> HydrationSession
    func endSession(_ session: HydrationSession) async throws

    // MARK: - Settings

    func loadSettings() async throws -> UserSettings
    func saveSettings(_ settings: UserSettings) async throws
    func updateSettings(
        reminderWaitMinutes: Int?,
        notificationType: NotificationType?,
        isPaused: Bool?,
        activeStartHour: Int?,
        activeEndHour: Int?
    ) async throws
}
