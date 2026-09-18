import AppKit
import ServiceManagement

enum LaunchAtLogin {
    private static let configuredKey = "didConfigureLoginItem"

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else if SMAppService.mainApp.status == .enabled {
            try SMAppService.mainApp.unregister()
        }
    }

    static func enableOnFirstLaunch() {
        guard AppInstallLocation.canRegisterLoginItem(Bundle.main.bundleURL) else { return }
        guard !UserDefaults.standard.bool(forKey: configuredKey) else { return }
        do {
            try setEnabled(true)
            UserDefaults.standard.set(true, forKey: configuredKey)
        } catch {
            NSLog("SIDEDOCK: launch at login not enabled yet: \(error.localizedDescription)")
        }
    }
}
