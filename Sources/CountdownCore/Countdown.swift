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

public enum ElapsedText {
    /// "Launched just now", "Launched 5m ago", "Launched 2h 14m ago", "Launched 3d 4h ago".
    public static func since(_ target: Date, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(target)))
        let days = seconds / 86_400
        let hours = seconds % 86_400 / 3_600
        let minutes = seconds % 3_600 / 60
        switch seconds {
        case ..<60: return "Launched just now"
        case ..<3_600: return "Launched \(minutes)m ago"
        case ..<86_400: return "Launched \(hours)h \(minutes)m ago"
        default: return "Launched \(days)d \(hours)h ago"
        }
    }
}

/// WidgetKit timeline: one entry per day boundary, then a live entry at the target.
public enum WidgetTimeline {
    public enum Entry: Equatable, Sendable {
        /// Shows `days` statically and a live timer counting down to `timerEnd`.
        case counting(start: Date, days: Int, timerEnd: Date)
        case live(start: Date)

        public var start: Date {
            switch self {
            case .counting(let start, _, _), .live(let start): return start
            }
        }
    }

    /// Boundaries are `target - k·86400`. Returns `complete == false` when capped at `limit`,
    /// in which case the widget should request a new timeline after the last entry.
    public static func entries(target: Date, now: Date, limit: Int = 90) -> (entries: [Entry], complete: Bool) {
        guard now < target else { return ([.live(start: now)], true) }
        let day: TimeInterval = 86_400
        let current = Int((target.timeIntervalSince(now) / day).rounded(.up)) - 1
        var entries: [Entry] = [.counting(start: now, days: current, timerEnd: target - Double(current) * day)]
        var days = current - 1
        while days >= 0, entries.count < limit {
            entries.append(.counting(start: target - Double(days + 1) * day, days: days, timerEnd: target - Double(days) * day))
            days -= 1
        }
        guard days < 0 else { return (entries, false) }
        entries.append(.live(start: target))
        return (entries, true)
    }
}
