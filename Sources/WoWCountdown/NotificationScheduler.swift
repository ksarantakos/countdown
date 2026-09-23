import AppKit
import UserNotifications
import CountdownCore

/// Silent milestone notifications, reconciled against what's already pending.
@MainActor
final class NotificationScheduler: NSObject, UNUserNotificationCenterDelegate {
    enum State: Equatable {
        case unknown
        case demo
        case unavailable(String)
        case denied
        case scheduled(count: Int)
        case failed(String)
    }

    private(set) var state: State = .unknown
    private let target: Date
    private let isDemo: Bool

    init(target: Date, isDemo: Bool) {
        self.target = target
        self.isDemo = isDemo
        super.init()
        if isDemo {
            state = .demo
        } else if Bundle.main.bundleIdentifier == nil {
            state = .unavailable("not running from the app bundle")
        } else {
            UNUserNotificationCenter.current().delegate = self
        }
    }

    /// Requests authorization if undetermined, then reconciles pending milestones.
    func refresh() async {
        guard !isDemo, Bundle.main.bundleIdentifier != nil else { return }
        let center = UNUserNotificationCenter.current()
        var status = await center.notificationSettings().authorizationStatus
        if status == .notDetermined {
            do {
                _ = try await center.requestAuthorization(options: [.alert])
            } catch {
                state = .failed(error.localizedDescription)
                Log.notifications.error("Authorization request failed: \(error.localizedDescription, privacy: .public)")
                return
            }
            status = await center.notificationSettings().authorizationStatus
        }
        switch status {
        case .authorized, .provisional:
            await reconcile(center)
        case .denied:
            state = .denied
            Log.notifications.notice("Notifications denied by the user")
        default:
            state = .unavailable("authorization status \(status.rawValue)")
        }
    }

    private func reconcile(_ center: UNUserNotificationCenter) async {
        let desired = Milestones.upcoming(target: target, now: Date())
        let pending = await center.pendingNotificationRequests().map { request in
            Milestone(
                id: request.identifier,
                fireDate: (request.content.userInfo["fireDate"] as? Double).map(Date.init(timeIntervalSince1970:)) ?? .distantPast,
                title: request.content.title,
                body: request.content.body
            )
        }
        let plan = NotificationReconciler.plan(desired: desired, pending: pending)
        if !plan.remove.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: plan.remove)
        }
        do {
            // Adding with an existing identifier replaces that pending request.
            for milestone in plan.add + plan.replace {
                try await center.add(Self.request(for: milestone))
            }
        } catch {
            state = .failed(error.localizedDescription)
            Log.notifications.error("Scheduling failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        let scheduled = await center.pendingNotificationRequests()
            .filter { $0.identifier.hasPrefix(Milestones.idPrefix) }
        state = .scheduled(count: scheduled.count)
        Log.notifications.notice("Reconciled: removed \(plan.remove, privacy: .public), added \(plan.add.map(\.id), privacy: .public), replaced \(plan.replace.map(\.id), privacy: .public)")
        for request in scheduled.sorted(by: { $0.identifier < $1.identifier }) {
            let next = (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
            Log.notifications.notice("Pending \(request.identifier, privacy: .public) → \(next.map(LaunchTarget.key(for:)) ?? "nil", privacy: .public)")
        }
    }

    private static func request(for milestone: Milestone) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = milestone.title
        content.body = milestone.body
        content.sound = nil  // Silent: the only audio is the launch fanfare.
        content.userInfo = ["fireDate": milestone.fireDate.timeIntervalSince1970]

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = LaunchTarget.timeZone
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: milestone.fireDate)
        components.timeZone = LaunchTarget.timeZone
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: milestone.id, content: content, trigger: trigger)
    }

    static func openSettings() {
        let id = Bundle.main.bundleIdentifier ?? ""
        let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(id)")!
        NSWorkspace.shared.open(url)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }
}
