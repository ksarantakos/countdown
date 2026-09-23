import Foundation

public enum CelebrationDecision: Equatable, Sendable {
    case none
    case celebrate
    /// The launch passed too long ago; mark it handled without effects.
    case markSilently
}

/// Once at launch, with catch-up within six hours.
public enum CelebrationPolicy {
    public static let catchUpWindow: TimeInterval = 6 * 3_600

    public static func decide(
        now: Date,
        target: Date,
        alreadyCelebrated: Bool,
        catchUpWindow: TimeInterval = catchUpWindow
    ) -> CelebrationDecision {
        guard now >= target, !alreadyCelebrated else { return .none }
        return now.timeIntervalSince(target) <= catchUpWindow ? .celebrate : .markSilently
    }
}

/// Applies `CelebrationPolicy` against a persisted flag keyed by the target instant.
public final class CelebrationTracker {
    public let target: Date
    private let store: KeyValueStore

    public init(target: Date, store: KeyValueStore) {
        self.target = target
        self.store = store
    }

    public var flagKey: String { "celebrated.\(LaunchTarget.key(for: target))" }

    public var hasCelebrated: Bool { store.object(forKey: flagKey) as? Bool ?? false }

    /// Evaluates the policy. The flag is written before `celebrate` runs (best-effort: a crash
    /// during effects is unlikely to repeat them, but UserDefaults persistence isn't guaranteed).
    @discardableResult
    public func evaluate(now: Date, celebrate: () -> Void) -> CelebrationDecision {
        let decision = CelebrationPolicy.decide(now: now, target: target, alreadyCelebrated: hasCelebrated)
        switch decision {
        case .none:
            break
        case .celebrate:
            store.set(true, forKey: flagKey)
            celebrate()
        case .markSilently:
            store.set(true, forKey: flagKey)
        }
        return decision
    }
}
