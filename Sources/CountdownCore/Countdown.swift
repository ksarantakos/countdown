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

/// WidgetKit timeline for the widget's live countdown.
///
/// The widget shows the day count statically and hours/minutes/seconds with the system timer
/// (`Text(timerInterval:countsDown:)`), which ticks live but rounds up and drops leading zeros:
/// `12:34:56`, `4:59:56`, `49:56`, `9:45`, `0:45`. Each day is split where the system format loses
/// a digit, and each piece carries a static prefix so the display always reads `HH:MM:SS`.
public enum WidgetTimeline {
    public struct Countdown: Equatable, Sendable {
        public let start: Date
        public let days: Int
        /// The live timer counts down to this: the end of the current day.
        public let timerEnd: Date
        /// Static text placed before the system timer.
        public let prefix: String

        public init(start: Date, days: Int, timerEnd: Date, prefix: String) {
            self.start = start
            self.days = days
            self.timerEnd = timerEnd
            self.prefix = prefix
        }

        /// Clamped so it stays valid in the final second of a day, after `timerEnd`.
        public var timerRange: ClosedRange<Date> { min(start, timerEnd)...timerEnd }
    }

    public enum Entry: Equatable, Sendable {
        case counting(Countdown)
        case live(start: Date)

        public var start: Date {
            switch self {
            case .counting(let countdown): return countdown.start
            case .live(let start): return start
            }
        }
    }

    /// The prefix that turns the system timer's text for `seconds` into `HH:MM:SS`.
    public static func timerPrefix(displayedSeconds seconds: Int) -> String {
        switch seconds {
        case 36_000...: return ""
        case 3_600...: return "0"
        case 600...: return "00:"
        default: return "00:0"
        }
    }

    /// Where each prefix starts, as seconds before the end of the day, and the value the timer shows then.
    /// With rounding up, the timer shows 9:59:59 once 35,999 s or fewer remain, and so on.
    private static let steps: [TimeInterval] = [86_399, 35_999, 3_599, 599]

    /// Day `k` is shown while the rounded-up time left is between `k·86400` and `k·86400 + 86399`
    /// seconds, matching `Remaining`. Returns `complete == false` when capped at `limit`, in which
    /// case the widget should request a new timeline after the last entry.
    public static func entries(target: Date, now: Date, limit: Int = 60) -> (entries: [Entry], complete: Bool) {
        guard now < target else { return ([.live(start: now)], true) }
        let day: TimeInterval = 86_400
        var days = Int(target.timeIntervalSince(now).rounded(.up)) / Int(day)
        var entries: [Entry] = []
        while days >= 0 {
            let end = target - Double(days) * day
            // The day's last piece runs until the next day starts, one second after `end`, or until launch.
            let dayOver = days == 0 ? target : end + 1
            for (index, offset) in steps.enumerated() {
                let pieceEnd = index + 1 < steps.count ? end - steps[index + 1] : dayOver
                guard pieceEnd > now else { continue }
                guard entries.count < limit else { return (entries, false) }
                entries.append(.counting(Countdown(
                    start: max(end - offset, now),
                    days: days,
                    timerEnd: end,
                    prefix: timerPrefix(displayedSeconds: Int(offset))
                )))
            }
            days -= 1
        }
        entries.append(.live(start: target))
        return (entries, true)
    }
}
