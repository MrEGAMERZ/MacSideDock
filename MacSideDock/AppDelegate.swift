import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let panelManager = DockPanelManager()
    private let statusItem = StatusItemController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        if AppInstall.handleFirstLaunchRelocation() {
            return
        }
        NSApp.setActivationPolicy(.accessory)
        LaunchAtLogin.enableOnFirstLaunch()
        RecentsStore.shared.start()
        statusItem.start()
        panelManager.start()
        stripSystemSettingsCommand()
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusItem.stop()
        RecentsStore.shared.stop()
        panelManager.stop()
    }

    /// Accessory app: clicking the app in Finder should not open Settings.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Removes the system “Settings…” / Cmd+, item so Settings is menu-bar only.
    private func stripSystemSettingsCommand() {
        DispatchQueue.main.async {
            guard let mainMenu = NSApp.mainMenu else { return }
            for item in mainMenu.items {
                guard let submenu = item.submenu else { continue }
                let victims = submenu.items.filter { entry in
                    let title = entry.title
                    if title.localizedCaseInsensitiveContains("Settings")
                        || title.localizedCaseInsensitiveContains("Preferences") {
                        return true
                    }
                    return entry.keyEquivalent == ","
                }
                victims.forEach { submenu.removeItem($0) }
            }
        }
    }
}
