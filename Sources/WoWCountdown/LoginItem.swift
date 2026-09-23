import AppKit
import ServiceManagement

/// Launch at login, treated as system-managed state: always read from `SMAppService`.
@MainActor
enum LoginItem {
    static var status: SMAppService.Status { SMAppService.mainApp.status }

    static func toggle() {
        let service = SMAppService.mainApp
        do {
            switch service.status {
            case .enabled:
                try service.unregister()
            case .requiresApproval:
                SMAppService.openSystemSettingsLoginItems()
            default:
                try service.register()
                if service.status == .requiresApproval {
                    Alerts.show(
                        title: "Approve Launch at Login",
                        message: "macOS needs your approval. Enable WoW Forever Countdown in System Settings → General → Login Items."
                    )
                    SMAppService.openSystemSettingsLoginItems()
                }
            }
        } catch {
            Alerts.show(title: "Couldn't change Launch at Login", message: error.localizedDescription, style: .warning)
        }
    }
}
