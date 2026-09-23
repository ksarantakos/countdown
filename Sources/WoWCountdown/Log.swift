import os

enum Log {
    static let subsystem = "com.ksarantakos.wowcountdown"
    static let app = Logger(subsystem: subsystem, category: "app")
    static let notifications = Logger(subsystem: subsystem, category: "notifications")
    static let widget = Logger(subsystem: subsystem, category: "widget")
}
