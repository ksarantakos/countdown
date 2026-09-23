import AppKit
import CountdownCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let mode: RuntimeMode
    private var countdown: CountdownController!
    private var notifications: NotificationScheduler!
    private var widget: WidgetWindowController!
    private var statusItem: StatusItemController!
    private var wakeObserver: NSObjectProtocol?

    init(mode: RuntimeMode) {
        self.mode = mode
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !mode.isDemo, anotherInstanceIsRunning() {
            Alerts.show(title: "WoW Forever Countdown is already running", message: "Use its menu bar item to show the widget.")
            NSApp.terminate(nil)
            return
        }

        let store = mode.makeStore(persistent: UserDefaults.standard)
        let settings = AppSettings(store: store)

        countdown = CountdownController(target: mode.target(now: Date()), isDemo: mode.isDemo, store: store)
        countdown.onCelebrate = {
            // Phase 2 adds fireworks and the fanfare here.
            Log.app.notice("Launch celebration triggered")
        }
        notifications = NotificationScheduler(target: countdown.target, isDemo: mode.isDemo)
        widget = WidgetWindowController(countdown: countdown, settings: settings)
        statusItem = StatusItemController(countdown: countdown, widget: widget, notifications: notifications)

        Log.app.notice("Launched (demo: \(self.mode.isDemo, privacy: .public)), target \(LaunchTarget.key(for: self.countdown.target), privacy: .public), resources: \(ResourceLocator.bundle?.bundlePath ?? "MISSING", privacy: .public)")

        countdown.start()
        widget.start()
        Task { await notifications.refresh() }

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                Task { await self.notifications.refresh() }
            }
        }
    }

    private func anotherInstanceIsRunning() -> Bool {
        guard let id = Bundle.main.bundleIdentifier else { return false }
        return NSRunningApplication.runningApplications(withBundleIdentifier: id)
            .contains { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
    }
}

@MainActor
enum Alerts {
    static func show(title: String, message: String, style: NSAlert.Style = .informational) {
        let alert = NSAlert()
        alert.alertStyle = style
        alert.messageText = title
        alert.informativeText = message
        NSApp.activate()
        alert.runModal()
    }
}
