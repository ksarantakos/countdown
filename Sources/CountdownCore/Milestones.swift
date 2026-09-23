import Foundation

public struct Milestone: Equatable, Sendable {
    public let id: String
    public let fireDate: Date
    public let title: String
    public let body: String

    public init(id: String, fireDate: Date, title: String, body: String) {
        self.id = id
        self.fireDate = fireDate
        self.title = title
        self.body = body
    }
}

public enum Milestones {
    public static let idPrefix = "milestone."
    public static let title = "WoW Forever"

    private static let day: TimeInterval = 86_400
    private static let hour: TimeInterval = 3_600

    static let schedule: [(key: String, before: TimeInterval, body: String)] = [
        ("30d", 30 * day, "30 days until launch — Nov 4, 3:00 PM PT."),
        ("14d", 14 * day, "Two weeks until launch — Nov 4, 3:00 PM PT."),
        ("7d", 7 * day, "One week until launch — Nov 4, 3:00 PM PT."),
        ("3d", 3 * day, "3 days until launch — Nov 4, 3:00 PM PT."),
        ("1d", 1 * day, "Launch is tomorrow at 3:00 PM PT."),
        ("12h", 12 * hour, "12 hours until launch."),
        ("1h", 1 * hour, "1 hour until launch. Time to patch up."),
        ("10m", 10 * 60, "10 minutes until launch!"),
        ("launch", 0, "WoW Forever is live!"),
    ]

    /// Milestones still in the future, soonest first.
    public static func upcoming(target: Date, now: Date) -> [Milestone] {
        schedule
            .map { Milestone(id: idPrefix + $0.key, fireDate: target - $0.before, title: title, body: $0.body) }
            .filter { $0.fireDate > now }
            .sorted { $0.fireDate < $1.fireDate }
    }
}

public struct ReconcilePlan: Equatable, Sendable {
    /// Pending milestone ids that are no longer wanted.
    public var remove: [String] = []
    /// Wanted milestones with no pending request.
    public var add: [Milestone] = []
    /// Wanted milestones whose pending request differs in date or content.
    public var replace: [Milestone] = []

    public init(remove: [String] = [], add: [Milestone] = [], replace: [Milestone] = []) {
        self.remove = remove
        self.add = add
        self.replace = replace
    }

    public var isEmpty: Bool { remove.isEmpty && add.isEmpty && replace.isEmpty }
}

public enum NotificationReconciler {
    /// Diffs the desired milestones against pending requests. Non-milestone ids are ignored.
    /// A pending request with an unknown fire date should be passed with `.distantPast` so it's replaced.
    public static func plan(desired: [Milestone], pending: [Milestone]) -> ReconcilePlan {
        let ours = pending.filter { $0.id.hasPrefix(Milestones.idPrefix) }
        let pendingByID = Dictionary(ours.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let desiredIDs = Set(desired.map(\.id))

        var plan = ReconcilePlan()
        plan.remove = pendingByID.keys.filter { !desiredIDs.contains($0) }.sorted()
        for milestone in desired {
            if let existing = pendingByID[milestone.id] {
                if !matches(existing, milestone) { plan.replace.append(milestone) }
            } else {
                plan.add.append(milestone)
            }
        }
        return plan
    }

    private static func matches(_ a: Milestone, _ b: Milestone) -> Bool {
        a.title == b.title && a.body == b.body && abs(a.fireDate.timeIntervalSince(b.fireDate)) < 1
    }
}
