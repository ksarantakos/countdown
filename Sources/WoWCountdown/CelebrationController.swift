import AppKit
import SwiftUI

/// Click-through fireworks overlay on every screen, plus the fanfare.
@MainActor
final class CelebrationController {
    enum Kind {
        case launch, preview

        var title: String { "WoW Forever" }
        var subtitle: String { self == .launch ? "IS NOW LIVE" : "LAUNCH CELEBRATION PREVIEW" }
    }

    static let duration: TimeInterval = 12

    private var windows: [NSWindow] = []
    private let fanfare = Fanfare()
    private var dismissTask: Task<Void, Never>?

    func play(_ kind: Kind) {
        dismiss()
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let start = Date()
        for (index, screen) in NSScreen.screens.enumerated() {
            let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.setFrame(screen.frame, display: false)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: FireworksView(
                start: start, duration: Self.duration, seed: UInt64(index + 1) &* 7919,
                title: kind.title, subtitle: kind.subtitle, reduceMotion: reduceMotion))
            window.orderFrontRegardless()
            windows.append(window)
        }
        fanfare.play()
        Log.app.notice("Celebration started (\(kind == .launch ? "launch" : "preview", privacy: .public), reduce motion: \(reduceMotion, privacy: .public))")
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.duration))
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        windows.forEach { $0.orderOut(nil) }
        windows = []
    }
}
