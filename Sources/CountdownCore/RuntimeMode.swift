import Foundation

public enum RuntimeMode: Equatable, Sendable {
    case normal
    /// Counts down to now + `seconds`, with all state kept in memory.
    case demo(seconds: TimeInterval)

    public struct ArgumentError: Error, CustomStringConvertible {
        public let description: String
    }

    public static func parse(_ arguments: [String]) throws -> RuntimeMode {
        guard let index = arguments.firstIndex(of: "--demo-seconds") else { return .normal }
        guard index + 1 < arguments.count,
              let seconds = TimeInterval(arguments[index + 1]),
              seconds.isFinite, seconds >= 0
        else {
            throw ArgumentError(description: "--demo-seconds requires a non-negative number of seconds")
        }
        return .demo(seconds: seconds)
    }

    public var isDemo: Bool {
        if case .demo = self { return true }
        return false
    }

    /// The real launch date, or a demo target rounded up to a whole second so it ticks in phase with the clock.
    public func target(now: Date) -> Date {
        switch self {
        case .normal:
            return LaunchTarget.date
        case .demo(let seconds):
            return Date(timeIntervalSinceReferenceDate: (now.timeIntervalSinceReferenceDate + seconds).rounded(.up))
        }
    }

    /// Demo mode never touches the persistent store.
    public func makeStore(persistent: @autoclosure () -> KeyValueStore) -> KeyValueStore {
        switch self {
        case .normal: return persistent()
        case .demo: return InMemoryStore()
        }
    }
}
