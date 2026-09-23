import AppKit
import Combine
import ServiceManagement
import CountdownCore

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let countdown: CountdownController
    private let widget: WidgetWindowController
    private let notifications: NotificationScheduler
    private var cancellable: AnyCancellable?

    init(countdown: CountdownController, widget: WidgetWindowController, notifications: NotificationScheduler) {
        self.countdown = countdown
        self.widget = widget
        self.notifications = notifications
        super.init()

        if let button = item.button {
            button.image = NSImage(systemSymbolName: "hourglass", accessibilityDescription: "WoW Forever countdown")
            button.imagePosition = .imageLeading
            button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        }
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu

        cancellable = countdown.$remaining.sink { [weak self] remaining in
            guard let self else { return }
            self.item.button?.title = (self.countdown.isDemo ? "DEMO " : "") + remaining.compactText
        }
    }

    // Rebuilt on every open so login and notification states are always current.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let header = NSMenuItem(title: "WoW Forever · \(countdown.targetCaption)", action: nil, keyEquivalent: "")
        if let icon = ResourceLocator.image(named: "AppIcon") {
            icon.size = NSSize(width: 16, height: 16)
            header.image = icon
        } else {
            header.title += "  ⚠ resources missing"
        }
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        menu.addItem(action(widget.isVisible ? "Hide Widget" : "Show Widget", #selector(toggleWidget)))
        menu.addItem(action("Reset Widget Position", #selector(resetPosition)))
        menu.addItem(.separator())

        menu.addItem(loginMenuItem())
        menu.addItem(notificationsMenuItem())
        menu.addItem(.separator())

        menu.addItem(action("Quit", #selector(quit), key: "q"))

        Task { await notifications.refresh() }  // picks up changes made in System Settings
    }

    private func loginMenuItem() -> NSMenuItem {
        if countdown.isDemo {
            let item = NSMenuItem(title: "Launch at Login (demo)", action: nil, keyEquivalent: "")
            item.isEnabled = false
            return item
        }
        let item = action("Launch at Login", #selector(toggleLogin))
        switch LoginItem.status {
        case .enabled:
            item.state = .on
        case .requiresApproval:
            item.title = "Launch at Login — Approve in System Settings…"
            item.state = .mixed
        default:
            item.state = .off
        }
        return item
    }

    private func notificationsMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        item.isEnabled = false
        switch notifications.state {
        case .unknown:
            item.title = "Notifications: checking…"
        case .demo:
            item.title = "Notifications: disabled in demo"
        case .unavailable(let reason):
            item.title = "Notifications unavailable (\(reason))"
        case .denied:
            item.title = "Notifications Off — Open System Settings…"
            item.action = #selector(openNotificationSettings)
            item.target = self
            item.isEnabled = true
        case .scheduled(let count):
            item.title = "Milestone Notifications: \(count) scheduled"
        case .failed(let message):
            item.title = "Notifications error: \(message)"
        }
        return item
    }

    private func action(_ title: String, _ selector: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func toggleWidget() { widget.setVisible(!widget.isVisible) }
    @objc private func resetPosition() { widget.resetPosition() }
    @objc private func toggleLogin() { LoginItem.toggle() }
    @objc private func openNotificationSettings() { NotificationScheduler.openSettings() }
    @objc private func quit() { NSApp.terminate(nil) }
}
