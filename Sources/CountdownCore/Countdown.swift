import Foundation

public enum LaunchTarget {
    public static let timeZone = TimeZone(identifier: "America/Los_Angeles")!

    /// WoW Forever launch: Nov 4, 2026, 3:00 PM Pacific. DST ends Nov 1, so this is PST (23:00 UTC).
    public static let date: Date = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: 2026, month: 11, day: 4, hour: 15))!
    }()

    /// Stable identifier for a target instant, e.g. "2026-11-04T23:00:00Z".
    public static func key(for date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}

/// Time left until the target, in whole seconds.
///
/// Positive intervals are rounded **up**, so the display reads 00:00:01 until the
/// instant of launch and never shows all zeros early.
public struct Remaining: Equatable, Sendable {
    public let totalSeconds: Int
    public let isLive: Bool

    public init(now: Date, target: Date) {
        let interval = target.timeIntervalSince(now)
        if interval > 0 {
            totalSeconds = Int(interval.rounded(.up))
            isLive = false
        } else {
            totalSeconds = 0
            isLive = true
        }
    }

    public var days: Int { totalSeconds / 86_400 }
    public var hours: Int { totalSeconds % 86_400 / 3_600 }
    public var minutes: Int { totalSeconds % 3_600 / 60 }
    public var seconds: Int { totalSeconds % 60 }

    /// "42d 06:13:02", or "LIVE" once the target has passed.
    public var compactText: String {
        if isLive { return "LIVE" }
        return String(format: "%dd %02d:%02d:%02d", days, hours, minutes, seconds)
    }
}
