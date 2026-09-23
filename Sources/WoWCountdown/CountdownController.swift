import AppKit
import Combine
import CountdownCore

/// The single clock. Views and the menu bar observe it; it owns the celebration trigger.
@MainActor
final class CountdownController: ObservableObject {
    @Published private(set) var remaining: Remaining

    let target: Date
    let isDemo: Bool
    var onCelebrate: (() -> Void)?

    private let tracker: CelebrationTracker
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []

    init(target: Date, isDemo: Bool, store: KeyValueStore) {
        self.target = target
        self.isDemo = isDemo
        self.tracker = CelebrationTracker(target: target, store: store)
        self.remaining = Remaining(now: Date(), target: target)
    }

    /// "Nov 4, 3:00 PM PST", or the local demo target time.
    var targetCaption: String {
        let formatter = DateFormatter()
        if isDemo {
            formatter.dateFormat = "'Demo target' h:mm:ss a"
        } else {
            formatter.timeZone = LaunchTarget.timeZone
            formatter.dateFormat = "MMM d · h:mm a zzz"
        }
        return formatter.string(from: target)
    }

    func start() {
        tick()
        scheduleTimer()
        let resync: @Sendable (Notification) -> Void = { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
                self?.scheduleTimer()
            }
        }
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main, using: resync))
        observers.append(NotificationCenter.default.addObserver(
            forName: .NSSystemClockDidChange, object: nil, queue: .main, using: resync))
    }

    /// Fires just after each wall-clock second so the rounded-up display changes on the boundary.
    private func scheduleTimer() {
        timer?.invalidate()
        let next = Date(timeIntervalSinceReferenceDate: Date().timeIntervalSinceReferenceDate.rounded(.down) + 1.02)
        let timer = Timer(fire: next, interval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = 0.05
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        let now = Date()
        let remaining = Remaining(now: now, target: target)
        if remaining != self.remaining { self.remaining = remaining }
        tracker.evaluate(now: now) { onCelebrate?() }
    }
}
