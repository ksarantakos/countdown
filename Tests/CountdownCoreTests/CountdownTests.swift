import Foundation
import Testing
@testable import CountdownCore

@Suite struct CountdownTests {
    @Test func targetIsDSTCorrectUTC() {
        #expect(LaunchTarget.key(for: LaunchTarget.date) == "2026-11-04T23:00:00Z")
    }

    @Test func fractionalSecondBeforeZeroShowsOneSecond() {
        let r = Remaining(now: LaunchTarget.date - 0.4, target: LaunchTarget.date)
        #expect(!r.isLive)
        #expect(r.totalSeconds == 1)
        #expect(r.compactText == "0d 00:00:01")
    }

    @Test func exactZeroIsLive() {
        let r = Remaining(now: LaunchTarget.date, target: LaunchTarget.date)
        #expect(r.isLive)
        #expect(r.compactText == "LIVE")
    }

    @Test func elapsedText() {
        let t = LaunchTarget.date
        #expect(ElapsedText.since(t, now: t + 20) == "Launched just now")
        #expect(ElapsedText.since(t, now: t + 5 * 60) == "Launched 5m ago")
        #expect(ElapsedText.since(t, now: t + 2 * 3_600 + 14 * 60) == "Launched 2h 14m ago")
        #expect(ElapsedText.since(t, now: t + 3 * 86_400 + 4 * 3_600) == "Launched 3d 4h ago")
    }

    @Test func breakdown() {
        let seconds: TimeInterval = 42 * 86_400 + 6 * 3_600 + 13 * 60 + 2
        let r = Remaining(now: LaunchTarget.date - seconds, target: LaunchTarget.date)
        #expect([r.days, r.hours, r.minutes, r.seconds] as [Int] == [42, 6, 13, 2])
        #expect(r.compactText == "42d 06:13:02")
    }
}

@Suite struct CelebrationTests {
    let target = LaunchTarget.date

    @Test func beforeTargetDoesNothing() {
        let tracker = CelebrationTracker(target: target, store: InMemoryStore())
        var count = 0
        #expect(tracker.evaluate(now: target - 1) { count += 1 } == .none)
        #expect(count == 0)
        #expect(!tracker.hasCelebrated)
    }

    @Test func sleepAcrossLaunchCelebratesOnce() {
        let tracker = CelebrationTracker(target: target, store: InMemoryStore())
        var count = 0
        tracker.evaluate(now: target - 60) { count += 1 }  // last seen before launch
        tracker.evaluate(now: target + 2 * 3_600) { count += 1 }  // wake 2 h after
        tracker.evaluate(now: target + 2 * 3_600 + 1) { count += 1 }
        #expect(count == 1)
    }

    @Test func wakingTooLateMarksSilently() {
        let store = InMemoryStore()
        let tracker = CelebrationTracker(target: target, store: store)
        var count = 0
        #expect(tracker.evaluate(now: target + 10 * 3_600) { count += 1 } == .markSilently)
        #expect(count == 0)
        #expect(tracker.hasCelebrated)
    }

    @Test func relaunchAfterCelebratingDoesNotCelebrate() {
        let store = InMemoryStore()
        CelebrationTracker(target: target, store: store).evaluate(now: target + 5) {}
        var count = 0
        let relaunched = CelebrationTracker(target: target, store: store)
        #expect(relaunched.evaluate(now: target + 60) { count += 1 } == .none)
        #expect(count == 0)
    }

    @Test func flagIsWrittenBeforeEffectsStart() {
        let store = InMemoryStore()
        let tracker = CelebrationTracker(target: target, store: store)
        var flagSeenDuringEffect: Bool?
        tracker.evaluate(now: target) { flagSeenDuringEffect = tracker.hasCelebrated }
        #expect(flagSeenDuringEffect == true)
    }

    @Test func flagForDifferentTargetDoesNotSuppress() {
        let store = InMemoryStore()
        CelebrationTracker(target: target - 86_400, store: store).evaluate(now: target - 86_000) {}
        var count = 0
        CelebrationTracker(target: target, store: store).evaluate(now: target) { count += 1 }
        #expect(count == 1)
    }

    @Test func catchUpWindowBoundary() {
        #expect(CelebrationPolicy.decide(now: target + 6 * 3_600, target: target, alreadyCelebrated: false) == .celebrate)
        #expect(CelebrationPolicy.decide(now: target + 6 * 3_600 + 1, target: target, alreadyCelebrated: false) == .markSilently)
    }
}

@Suite struct RuntimeModeTests {
    final class SpyStore: KeyValueStore {
        var writes: [String] = []
        func object(forKey key: String) -> Any? { nil }
        func set(_ value: Any?, forKey key: String) { writes.append(key) }
    }

    @Test func parsesDemoSeconds() throws {
        #expect(try RuntimeMode.parse(["app"]) == .normal)
        #expect(try RuntimeMode.parse(["app", "--demo-seconds", "10"]) == .demo(seconds: 10))
        #expect(throws: RuntimeMode.ArgumentError.self) { try RuntimeMode.parse(["app", "--demo-seconds"]) }
        #expect(throws: RuntimeMode.ArgumentError.self) { try RuntimeMode.parse(["app", "--demo-seconds", "-3"]) }
        #expect(throws: RuntimeMode.ArgumentError.self) { try RuntimeMode.parse(["app", "--demo-seconds", "abc"]) }
    }

    @Test func demoWritesNothingToPersistentStore() {
        let spy = SpyStore()
        let mode = RuntimeMode.demo(seconds: 0)
        let now = Date()
        let store = mode.makeStore(persistent: spy)
        CelebrationTracker(target: mode.target(now: now), store: store).evaluate(now: now + 1) {}
        #expect(spy.writes.isEmpty)
    }

    @Test func normalUsesPersistentStoreAndRealTarget() {
        let spy = SpyStore()
        #expect(RuntimeMode.normal.makeStore(persistent: spy) === spy)
        #expect(RuntimeMode.normal.target(now: Date()) == LaunchTarget.date)
    }
}

@Suite struct MilestoneTests {
    let target = LaunchTarget.date

    @Test func skipsPastDates() {
        let upcoming = Milestones.upcoming(target: target, now: target - 2 * 86_400)
        #expect(upcoming.map(\.id) == ["milestone.1d", "milestone.12h", "milestone.1h", "milestone.10m", "milestone.launch"])
        #expect(Milestones.upcoming(target: target, now: target).isEmpty)
    }

    @Test func reconcileAddsReplacesRemovesAndKeeps() {
        let desired = Milestones.upcoming(target: target, now: target - 2 * 86_400)
        let unchanged = desired[0]
        let moved = desired[1]
        let reworded = desired[2]
        let pending = [
            unchanged,
            Milestone(id: moved.id, fireDate: moved.fireDate + 60, title: moved.title, body: moved.body),
            Milestone(id: reworded.id, fireDate: reworded.fireDate, title: reworded.title, body: "old text"),
            Milestone(id: "milestone.30d", fireDate: target - 30 * 86_400, title: "x", body: "y"),  // stale
            Milestone(id: "someone-else", fireDate: target, title: "x", body: "y"),  // not ours
        ]
        let plan = NotificationReconciler.plan(desired: desired, pending: pending)
        #expect(plan.remove == ["milestone.30d"])
        #expect(plan.replace.map(\.id) == [moved.id, reworded.id])
        #expect(plan.add.map(\.id) == desired.dropFirst(3).map(\.id))
        #expect(NotificationReconciler.plan(desired: desired, pending: desired).isEmpty)
    }

    @Test func unknownPendingDateIsReplaced() {
        let desired = Milestones.upcoming(target: target, now: target - 60)
        let pending = desired.map { Milestone(id: $0.id, fireDate: .distantPast, title: $0.title, body: $0.body) }
        #expect(NotificationReconciler.plan(desired: desired, pending: pending).replace == desired)
    }
}

@Suite struct WidgetTimelineTests {
    let target = LaunchTarget.date
    let day: TimeInterval = 86_400

    /// What `Text(timerInterval:countsDown:)` shows (measured: rounds up; `4:59:56`, `49:56`, `9:45`, `0:45`).
    func systemTimerText(_ range: ClosedRange<Date>, at now: Date) -> String {
        let seconds = max(0, Int(range.upperBound.timeIntervalSince(max(now, range.lowerBound)).rounded(.up)))
        let h = seconds / 3_600, m = seconds % 3_600 / 60, s = seconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    /// What the widget would display at `now`, as "Nd HH:MM:SS" or "LIVE".
    func widgetText(_ entries: [WidgetTimeline.Entry], at now: Date) -> String {
        let active = entries.last { $0.start <= now }!
        switch active {
        case .live: return "LIVE"
        case .counting(let c): return "\(c.days)d " + c.prefix + systemTimerText(c.timerRange, at: now)
        }
    }

    @Test func prefixes() {
        #expect(WidgetTimeline.timerPrefix(displayedSeconds: 86_399) == "")
        #expect(WidgetTimeline.timerPrefix(displayedSeconds: 36_000) == "")
        #expect(WidgetTimeline.timerPrefix(displayedSeconds: 35_999) == "0")
        #expect(WidgetTimeline.timerPrefix(displayedSeconds: 3_600) == "0")
        #expect(WidgetTimeline.timerPrefix(displayedSeconds: 3_599) == "00:")
        #expect(WidgetTimeline.timerPrefix(displayedSeconds: 600) == "00:")
        #expect(WidgetTimeline.timerPrefix(displayedSeconds: 599) == "00:0")
        #expect(WidgetTimeline.timerPrefix(displayedSeconds: 0) == "00:0")
    }

    @Test func entriesForADayAndAHalf() {
        let now = target - 1.5 * day
        let (entries, complete) = WidgetTimeline.entries(target: target, now: now)
        #expect(complete)
        let end1 = target - day
        #expect(entries == [
            .counting(.init(start: now, days: 1, timerEnd: end1, prefix: "")),
            .counting(.init(start: end1 - 35_999, days: 1, timerEnd: end1, prefix: "0")),
            .counting(.init(start: end1 - 3_599, days: 1, timerEnd: end1, prefix: "00:")),
            .counting(.init(start: end1 - 599, days: 1, timerEnd: end1, prefix: "00:0")),
            .counting(.init(start: target - 86_399, days: 0, timerEnd: target, prefix: "")),
            .counting(.init(start: target - 35_999, days: 0, timerEnd: target, prefix: "0")),
            .counting(.init(start: target - 3_599, days: 0, timerEnd: target, prefix: "00:")),
            .counting(.init(start: target - 599, days: 0, timerEnd: target, prefix: "00:0")),
            .live(start: target),
        ])
    }

    /// The widget must always read exactly what the menu bar's `Remaining` reads, with leading zeros.
    @Test func widgetMatchesRemainingAroundEveryBoundary() {
        let start = target - 3 * day - 0.25
        let (entries, complete) = WidgetTimeline.entries(target: target, now: start, limit: 1_000)
        #expect(complete)
        var samples: [Date] = []
        for k in 0...3 {
            let end = target - Double(k) * day
            for offset in [86_400.0, 86_399, 36_000, 35_999, 3_600, 3_599, 600, 599, 60, 1, 0, -1] {
                for jitter in [-0.5, -0.001, 0, 0.001, 0.5] {
                    samples.append(end - offset + jitter)
                }
            }
        }
        samples += stride(from: 0.0, to: 3 * day, by: 997.3).map { start + $0 }
        for now in samples where now >= start {
            let remaining = Remaining(now: now, target: target)
            #expect(widgetText(entries, at: now) == remaining.compactText, "at \(now.timeIntervalSince(target)) s from launch")
        }
    }

    @Test func alwaysEightCharacterTimer() {
        let (entries, _) = WidgetTimeline.entries(target: target, now: target - 2 * day, limit: 1_000)
        for now in stride(from: target - 2 * day, to: target, by: 311.7).map({ $0 }) {
            let text = widgetText(entries, at: now)
            #expect(text.split(separator: " ").last?.count == 8, "\(text)")
        }
    }

    @Test func liveAndCapped() {
        #expect(WidgetTimeline.entries(target: target, now: target + 5).entries == [.live(start: target + 5)])
        let (entries, complete) = WidgetTimeline.entries(target: target, now: target - 42.3 * day, limit: 10)
        #expect(entries.count == 10)
        #expect(!complete)
    }

    @Test func finalSecondOfDayIsValid() {
        // Between the end of a day and the next day's first piece, the range must still be valid.
        let now = target - day + 0.5
        let (entries, _) = WidgetTimeline.entries(target: target, now: now)
        guard case .counting(let first) = entries[0] else { Issue.record("expected counting"); return }
        #expect(first.days == 1 && first.prefix == "00:0")
        #expect(first.timerRange.lowerBound <= first.timerRange.upperBound)
        #expect(widgetText(entries, at: now) == "1d 00:00:00")
    }
}
