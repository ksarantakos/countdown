import SwiftUI
import CountdownCore

/// Phase 1 placeholder layout; Phase 2 replaces the styling.
struct WidgetView: View {
    @ObservedObject var countdown: CountdownController

    var body: some View {
        let remaining = countdown.remaining
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Text("WoW Forever")
                    .font(.system(size: 20, weight: .bold, design: .serif))
                if countdown.isDemo {
                    Text("DEMO")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange, in: Capsule())
                }
            }
            if remaining.isLive {
                Text("NOW LIVE")
                    .font(.system(size: 44, weight: .heavy, design: .serif))
            } else {
                HStack(spacing: 18) {
                    unit(remaining.days, "DAYS")
                    unit(remaining.hours, "HRS")
                    unit(remaining.minutes, "MIN")
                    unit(remaining.seconds, "SEC")
                }
            }
            Text(countdown.targetCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: WidgetWindowController.size.width, height: WidgetWindowController.size.height)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color(white: 0.08).opacity(0.92)))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color(red: 0.78, green: 0.68, blue: 0.53), lineWidth: 1))
        .environment(\.colorScheme, .dark)
    }

    private func unit(_ value: Int, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value, format: .number.grouping(.never))
                .font(.system(size: 36, weight: .semibold, design: .serif))
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
