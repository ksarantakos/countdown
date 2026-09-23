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

    @Test func dayBoundaryEntries() {
        let now = target - 1.5 * day
        let (entries, complete) = WidgetTimeline.entries(target: target, now: now)
        #expect(complete)
        #expect(entries == [
            .counting(start: now, days: 1, timerEnd: target - day),
            .counting(start: target - day, days: 0, timerEnd: target),
            .live(start: target),
        ])
    }

    @Test func exactBoundaryStartsNextDay() {
        let (entries, _) = WidgetTimeline.entries(target: target, now: target - 2 * day)
        #expect(entries.first == .counting(start: target - 2 * day, days: 1, timerEnd: target - day))
    }

    @Test func finalSecondsAndLive() {
        #expect(WidgetTimeline.entries(target: target, now: target - 5).entries.first == .counting(start: target - 5, days: 0, timerEnd: target))
        #expect(WidgetTimeline.entries(target: target, now: target + 5).entries == [.live(start: target + 5)])
    }

    @Test func cappedTimelineIsIncomplete() {
        let (entries, complete) = WidgetTimeline.entries(target: target, now: target - 42.3 * day, limit: 10)
        #expect(entries.count == 10)
        #expect(!complete)
        #expect(entries.first == .counting(start: target - 42.3 * day, days: 42, timerEnd: target - 42 * day))
    }

    @Test func realCountdownFitsInOneTimeline() {
        let (entries, complete) = WidgetTimeline.entries(target: target, now: target - 42.3 * day)
        #expect(complete)
        #expect(entries.count == 44)  // today + 42 boundaries + live
    }
}
