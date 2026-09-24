import SwiftUI
import WidgetKit
import CountdownCore

struct CountdownEntry: TimelineEntry {
    let date: Date
    let state: WidgetTimeline.Entry
}

struct CountdownProvider: TimelineProvider {
    let target = LaunchTarget.date

    func placeholder(in context: Context) -> CountdownEntry {
        let now = Date()
        return CountdownEntry(date: now, state: WidgetTimeline.entries(target: target, now: now, maxDays: 1).entries[0])
    }

    func getSnapshot(in context: Context, completion: @escaping (CountdownEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CountdownEntry>) -> Void) {
        let (states, complete) = WidgetTimeline.entries(target: target, now: Date())
        let entries = states.map { CountdownEntry(date: $0.start, state: $0) }
        // Every date is absolute, so a complete timeline never needs a reload.
        completion(Timeline(entries: entries, policy: complete ? .never : .atEnd))
    }
}

@main
struct WoWCountdownWidgetBundle: WidgetBundle {
    var body: some Widget {
        CountdownWidget()
    }
}

struct CountdownWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WoWForeverCountdown", provider: CountdownProvider()) { entry in
            CountdownWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetBackground() }
        }
        .configurationDisplayName("WoW Forever Countdown")
        .description("Counts down to launch: Nov 4, 3:00 PM PT.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
