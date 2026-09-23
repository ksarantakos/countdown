import SwiftUI
import WidgetKit
import CountdownCore

struct CountdownWidgetView: View {
    let entry: CountdownEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch entry.state {
        case .counting(_, let days, let timerEnd):
            switch family {
            case .systemMedium: MediumLayout(days: days, timer: entry.date...timerEnd)
            case .systemLarge: LargeLayout(days: days, timer: entry.date...timerEnd)
            default: SmallLayout(days: days, timer: entry.date...timerEnd)
            }
        case .live:
            LiveLayout(family: family)
        }
    }
}

// MARK: - Pieces

private struct Wordmark: View {
    var size: CGFloat
    @Environment(\.widgetRenderingMode) private var renderingMode
    var body: some View {
        Text("WoW Forever")
            .font(Theme.display(size, weight: .bold))
            .tracking(size * 0.06)
            .foregroundStyle(Theme.carved)
            .shadow(color: renderingMode == .fullColor ? .black.opacity(0.6) : .clear, radius: 0, y: 1)
            .lineLimit(1)
            .fixedSize()
            .cinzelCapBox(size)
    }
}

private struct DaysNumeral: View {
    var days: Int
    var size: CGFloat
    @Environment(\.widgetRenderingMode) private var renderingMode
    var body: some View {
        let fullColor = renderingMode == .fullColor
        Text(days, format: .number.grouping(.never))
            .font(Theme.display(size, weight: .black))
            .foregroundStyle(Theme.goldLeaf)
            .shadow(color: fullColor ? Theme.gold600.opacity(0.55) : .clear, radius: size * 0.1)
            .shadow(color: fullColor ? .black.opacity(0.5) : .clear, radius: 0, y: 2)
            .widgetAccentable()
            .contentTransition(.numericText(countsDown: true))
            .fixedSize()
            .cinzelCapBox(size)
    }
}

private struct CapsLabel: View {
    var text: String
    var size: CGFloat
    var body: some View {
        Text(text)
            .font(Theme.label(size, weight: .semibold))
            .tracking(size * 0.3)
            .foregroundStyle(Theme.beige300.opacity(0.75))
            .fixedSize()
            .openSansCapBox(size)
    }
}

/// System-rendered H:MM:SS that ticks live inside the widget.
private struct LiveTimer: View {
    var interval: ClosedRange<Date>
    var size: CGFloat
    @Environment(\.widgetRenderingMode) private var renderingMode
    var body: some View {
        Text(timerInterval: interval, countsDown: true)
            .font(Theme.display(size, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(Theme.carved)
            .shadow(color: renderingMode == .fullColor ? .black.opacity(0.6) : .clear, radius: 0, y: 1)
            .multilineTextAlignment(.center)
            .cinzelCapBox(size)
    }
}

private struct LaunchCaption: View {
    var size: CGFloat
    var body: some View {
        Text("Nov 4 · 3:00 PM PT")
            .font(Theme.label(size, weight: .medium))
            .foregroundStyle(Theme.beige200.opacity(0.85))
            .fixedSize()
            .openSansCapBox(size)
    }
}

private func daysLabel(_ days: Int) -> String { days == 1 ? "DAY" : "DAYS" }

// MARK: - Layouts
// Spacing is between visible glyphs (see cinzelCapBox), so these numbers are what you see.

private struct SmallLayout: View {
    var days: Int
    var timer: ClosedRange<Date>
    var body: some View {
        VStack(spacing: 0) {
            Wordmark(size: 15)
            Ornament(width: 96).padding(.top, 7)
            DaysNumeral(days: days, size: 58).padding(.top, 14)
            CapsLabel(text: daysLabel(days), size: 8).padding(.top, 9)
            LiveTimer(interval: timer, size: 20).padding(.top, 13)
        }
    }
}

private struct MediumLayout: View {
    var days: Int
    var timer: ClosedRange<Date>
    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                Wordmark(size: 19)
                Ornament(width: 120).padding(.top, 9)
                CapsLabel(text: "LAUNCH", size: 8).padding(.top, 14)
                LaunchCaption(size: 12).padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.trailing, 14)

            LinearGradient(colors: [.clear, Theme.beige400.opacity(0.8), .clear], startPoint: .top, endPoint: .bottom)
                .frame(width: 1)
                .padding(.vertical, 14)

            VStack(spacing: 0) {
                DaysNumeral(days: days, size: 60)
                CapsLabel(text: daysLabel(days), size: 8).padding(.top, 9)
                LiveTimer(interval: timer, size: 22).padding(.top, 14)
            }
            // The numerals need far less width than the wordmark; give the extra to the left column.
            .frame(width: 124)
            .padding(.leading, 8)
        }
    }
}

private struct LargeLayout: View {
    var days: Int
    var timer: ClosedRange<Date>
    var body: some View {
        VStack(spacing: 0) {
            Wordmark(size: 26)
            Ornament(width: 180).padding(.top, 11)
            Medallion {
                VStack(spacing: 0) {
                    DaysNumeral(days: days, size: 70)
                    CapsLabel(text: daysLabel(days), size: 9).padding(.top, 10)
                }
                .padding(.top, 4)
            }
            .frame(width: 164, height: 164)
            .padding(.top, 14)
            LiveTimer(interval: timer, size: 32).padding(.top, 18)
            CapsLabel(text: "HOURS  ·  MINUTES  ·  SECONDS", size: 8).padding(.top, 13)
            LaunchCaption(size: 12).padding(.top, 20)
        }
    }
}

private struct LiveLayout: View {
    var family: WidgetFamily
    @Environment(\.widgetRenderingMode) private var renderingMode
    var body: some View {
        let big: CGFloat = family == .systemSmall ? 30 : family == .systemMedium ? 44 : 54
        VStack(spacing: 0) {
            Wordmark(size: big * 0.45)
            Ornament(width: big * 3).padding(.top, big * 0.25)
            Text("NOW LIVE")
                .font(Theme.display(big, weight: .black))
                .foregroundStyle(Theme.goldLeaf)
                .shadow(color: renderingMode == .fullColor ? Theme.gold400.opacity(0.7) : .clear, radius: big * 0.25)
                .widgetAccentable()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .cinzelCapBox(big)
                .padding(.top, big * 0.4)
            (Text("Launched ") + Text(LaunchTarget.date, style: .relative) + Text(" ago"))
                .font(Theme.label(big * 0.26, weight: .medium))
                .foregroundStyle(Theme.beige200.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.top, big * 0.35)
        }
    }
}

// MARK: - Frame and background

/// Bronze octagonal frame around a glowing teal disc, with hour ticks.
/// Outside full color (monochrome/vibrant desktop, accented), fills would render as solid
/// white slabs, so only outlines are drawn.
private struct Medallion<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(\.widgetRenderingMode) private var renderingMode
    var body: some View {
        ZStack {
            if renderingMode == .fullColor {
                Octagon().fill(Theme.bronze)
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                Octagon().stroke(Theme.beige200.opacity(0.5), lineWidth: 0.75).padding(3)
                Circle()
                    .fill(RadialGradient(colors: [Theme.sectionBottom, Theme.teal600, Theme.teal800], center: .center, startRadius: 0, endRadius: 70))
                    .padding(14)
                Circle().stroke(Theme.beige600, lineWidth: 2).padding(14)
                HourTicks().stroke(Theme.beige200.opacity(0.45), lineWidth: 1).padding(19)
            } else {
                Octagon().stroke(.white.opacity(0.55), lineWidth: 1.5)
                Octagon().stroke(.white.opacity(0.25), lineWidth: 0.75).padding(4)
                Circle().stroke(.white.opacity(0.35), lineWidth: 1).padding(14)
                HourTicks().stroke(.white.opacity(0.3), lineWidth: 1).padding(19)
            }
            content
        }
    }
}

private struct Octagon: Shape {
    func path(in rect: CGRect) -> Path {
        let r = min(rect.width, rect.height) / 2
        let c = CGPoint(x: rect.midX, y: rect.midY)
        return Path { p in
            for i in 0..<8 {
                let angle = Double(i) * .pi / 4 + .pi / 8
                let point = CGPoint(x: c.x + r * cos(angle), y: c.y + r * sin(angle))
                i == 0 ? p.move(to: point) : p.addLine(to: point)
            }
            p.closeSubpath()
        }
    }
}

private struct HourTicks: Shape {
    func path(in rect: CGRect) -> Path {
        let r = min(rect.width, rect.height) / 2
        let c = CGPoint(x: rect.midX, y: rect.midY)
        return Path { p in
            for i in 0..<24 {
                let angle = Double(i) * .pi / 12
                let inner = r - (i % 6 == 0 ? 7 : 4)
                p.move(to: CGPoint(x: c.x + inner * cos(angle), y: c.y + inner * sin(angle)))
                p.addLine(to: CGPoint(x: c.x + r * cos(angle), y: c.y + r * sin(angle)))
            }
        }
    }
}

/// Deep teal with a central disc glow, vignette, and a bronze inner frame with corner studs.
struct WidgetBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.sectionTop, Theme.teal800], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Theme.sectionBottom.opacity(0.55), .clear], center: .center, startRadius: 0, endRadius: 220)
            RadialGradient(colors: [.clear, .black.opacity(0.45)], center: .center, startRadius: 90, endRadius: 320)
            GeometryReader { geo in
                let inset: CGFloat = 7
                let frame = geo.size
                ZStack {
                    ContainerRelativeShape()
                        .inset(by: inset)
                        .stroke(Theme.bronze, lineWidth: 1.25)
                    ContainerRelativeShape()
                        .inset(by: inset + 3.5)
                        .stroke(Theme.beige500.opacity(0.35), lineWidth: 0.5)
                    ForEach(0..<4, id: \.self) { i in
                        Diamond().fill(Theme.goldLeaf)
                            .frame(width: 7, height: 7)
                            .position(
                                x: i % 2 == 0 ? frame.width / 2 : (i == 1 ? inset : frame.width - inset),
                                y: i % 2 == 1 ? frame.height / 2 : (i == 0 ? inset : frame.height - inset)
                            )
                    }
                }
            }
        }
    }
}

#Preview(as: .systemLarge) {
    CountdownWidget()
} timeline: {
    CountdownEntry(date: .now, state: .counting(start: .now, days: 42, timerEnd: .now + 12_000))
    CountdownEntry(date: .now, state: .live(start: .now))
}
