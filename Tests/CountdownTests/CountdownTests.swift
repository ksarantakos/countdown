import Foundation
import Testing
@testable import Countdown

@Test func breaksFutureTimeIntoComponents() async throws {
    let now = Date(timeIntervalSince1970: 0)
    let target = now.addingTimeInterval((86_400) + (2 * 3_600) + (3 * 60) + 4)

    let remaining = CountdownCalculator.timeRemaining(to: target, from: now)

    #expect(remaining == TimeRemaining(days: 1, hours: 2, minutes: 3, seconds: 4))
}

@Test func clampsPastDatesToZero() async throws {
    let now = Date(timeIntervalSince1970: 1_000)
    let target = now.addingTimeInterval(-30)

    let remaining = CountdownCalculator.timeRemaining(to: target, from: now)

    #expect(remaining == TimeRemaining(days: 0, hours: 0, minutes: 0, seconds: 0))
}

@Test func supportsForeverStateForOngoingEvents() async throws {
    let snapshot = CountdownCalculator.snapshot(
        title: "World of Warcraft",
        mode: .forever(message: "WoW forever"),
        now: Date(timeIntervalSince1970: 0)
    )

    #expect(
        snapshot == CountdownSnapshot(
            title: "World of Warcraft",
            display: .forever("WoW forever")
        )
    )
}
