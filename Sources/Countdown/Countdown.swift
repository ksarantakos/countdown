import Foundation

public struct TimeRemaining: Equatable, Sendable {
    public let days: Int
    public let hours: Int
    public let minutes: Int
    public let seconds: Int

    public init(days: Int, hours: Int, minutes: Int, seconds: Int) {
        self.days = days
        self.hours = hours
        self.minutes = minutes
        self.seconds = seconds
    }
}

public enum CountdownDisplay: Equatable, Sendable {
    case remaining(TimeRemaining)
    case forever(String)
}

public struct CountdownSnapshot: Equatable, Sendable {
    public let title: String
    public let display: CountdownDisplay

    public init(title: String, display: CountdownDisplay) {
        self.title = title
        self.display = display
    }
}

public enum CountdownMode: Equatable, Sendable {
    case target(Date)
    case forever(message: String = "Forever")
}

public enum CountdownCalculator {
    public static func snapshot(
        title: String,
        mode: CountdownMode,
        now: Date = Date()
    ) -> CountdownSnapshot {
        switch mode {
        case .target(let target):
            return CountdownSnapshot(
                title: title,
                display: .remaining(timeRemaining(to: target, from: now))
            )
        case .forever(let message):
            return CountdownSnapshot(title: title, display: .forever(message))
        }
    }

    public static func timeRemaining(
        to target: Date,
        from now: Date = Date()
    ) -> TimeRemaining {
        let totalSeconds = max(0, Int(target.timeIntervalSince(now)))
        let days = totalSeconds / 86_400
        let hours = (totalSeconds % 86_400) / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        return TimeRemaining(
            days: days,
            hours: hours,
            minutes: minutes,
            seconds: seconds
        )
    }
}
