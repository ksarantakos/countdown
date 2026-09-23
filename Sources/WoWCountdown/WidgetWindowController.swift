import AppKit
import SwiftUI
import CountdownCore

@MainActor
final class WidgetWindowController {
    static let size = CGSize(width: 360, height: 220)

    private let window: DesktopWidgetWindow
    private let settings: AppSettings
    private var screenObserver: NSObjectProtocol?

    init(countdown: CountdownController, settings: AppSettings) {
        self.settings = settings
        let handle = DragHandleView(frame: NSRect(origin: .zero, size: Self.size))
        let hosting = NSHostingView(rootView: WidgetView(countdown: countdown))
        hosting.frame = handle.bounds
        hosting.autoresizingMask = [.width, .height]
        handle.addSubview(hosting)
        window = DesktopWidgetWindow(contentView: handle, size: Self.size)
        handle.onDragEnded = { [weak self] in self?.dragEnded() }
    }

    var isVisible: Bool { settings.widgetVisible }

    func start() {
        applyPlacement()
        if settings.widgetVisible { window.orderFrontRegardless() }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyPlacement() }
        }
    }

    func setVisible(_ visible: Bool) {
        settings.widgetVisible = visible
        if visible {
            applyPlacement()
            window.orderFrontRegardless()
        } else {
            window.orderOut(nil)
        }
    }

    func resetPosition() {
        settings.placement = nil
        applyPlacement()
    }

    /// Restores the saved position on its screen (or the primary), clamped on-screen.
    /// Fallbacks don't overwrite the saved placement, so reconnecting a display restores it.
    private func applyPlacement() {
        guard let frame = Placement.frame(for: Self.size, saved: settings.placement, screens: Self.screens()) else { return }
        window.setFrame(frame, display: true)
        Log.widget.debug("Placed widget at \(NSStringFromRect(frame), privacy: .public)")
    }

    private func dragEnded() {
        let screens = Self.screens()
        guard let screen = Placement.screen(for: window.frame, among: screens) else { return }
        let clamped = Placement.clamp(window.frame, into: screen.visibleFrame)
        if clamped != window.frame { window.setFrame(clamped, display: true, animate: true) }
        settings.placement = Placement.saved(for: clamped, on: screen)
    }

    /// Primary display first.
    private static func screens() -> [ScreenInfo] {
        NSScreen.screens.map { screen in
            let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            return ScreenInfo(id: number?.uint32Value ?? 0, name: screen.localizedName, visibleFrame: screen.visibleFrame)
        }
    }
}
