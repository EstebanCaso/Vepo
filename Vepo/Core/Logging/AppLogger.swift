import OSLog

enum AppLogger {
    static let ble = Logger(subsystem: "com.vepo.app", category: "BLE")
    static let detection = Logger(subsystem: "com.vepo.app", category: "Detection")
    static let persistence = Logger(subsystem: "com.vepo.app", category: "Persistence")
    static let notifications = Logger(subsystem: "com.vepo.app", category: "Notifications")
    static let ui = Logger(subsystem: "com.vepo.app", category: "UI")
}
