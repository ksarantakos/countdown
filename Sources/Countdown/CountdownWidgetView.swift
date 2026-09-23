#if canImport(SwiftUI)
import SwiftUI

public struct CountdownWidgetView: View {
    public let snapshot: CountdownSnapshot

    public init(snapshot: CountdownSnapshot) {
        self.snapshot = snapshot
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(snapshot.title)
                .font(.headline)

            switch snapshot.display {
            case .remaining(let remaining):
                Text(remaining.primaryText)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text(remaining.secondaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .forever(let message):
                Text(message)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
    }
}

private extension TimeRemaining {
    var primaryText: String {
        "\(days)d \(hours)h"
    }

    var secondaryText: String {
        "\(minutes)m \(seconds)s remaining"
    }
}

#if canImport(WidgetKit) && os(macOS)
import WidgetKit

public struct CountdownWidgetEntry: TimelineEntry {
    public let date: Date
    public let snapshot: CountdownSnapshot

    public init(date: Date, snapshot: CountdownSnapshot) {
        self.date = date
        self.snapshot = snapshot
    }
}

public struct CountdownWidgetProvider: TimelineProvider {
    public init() {}

    public func placeholder(in context: Context) -> CountdownWidgetEntry {
        sampleEntry(at: Date())
    }

    public func getSnapshot(in context: Context, completion: @escaping (CountdownWidgetEntry) -> Void) {
        completion(sampleEntry(at: Date()))
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<CountdownWidgetEntry>) -> Void) {
        let now = Date()
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 1, to: now) ?? now.addingTimeInterval(60)
        let timeline = Timeline(entries: [sampleEntry(at: now)], policy: .after(refreshDate))
        completion(timeline)
    }

    private func sampleEntry(at date: Date) -> CountdownWidgetEntry {
        CountdownWidgetEntry(
            date: date,
            snapshot: CountdownCalculator.snapshot(
                title: "World of Warcraft",
                mode: .forever(message: "WoW forever"),
                now: date
            )
        )
    }
}

@available(macOS 14.0, *)
public struct CountdownWidget: Widget {
    public let kind = "CountdownWidget"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CountdownWidgetProvider()) { entry in
            CountdownWidgetView(snapshot: entry.snapshot)
        }
        .configurationDisplayName("Countdown")
        .description("Shows a countdown or a forever label for ongoing events.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
#endif
#endif
