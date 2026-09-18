import AppKit

final class StatusItemController {
    private var statusItem: NSStatusItem?

    func start() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = Self.menuBarImage()
            button.toolTip = AppBrand.name
        }
        item.menu = buildMenu()
        statusItem = item
    }

    func stop() {
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
    }

    func reloadMenu() {
        statusItem?.menu = buildMenu()
    }

    private static func menuBarImage() -> NSImage {
        if let image = NSImage(named: "MenuBarIcon") {
            image.isTemplate = true
            image.size = NSSize(width: 18, height: 18)
            return image
        }
        let fallback = NSImage(systemSymbolName: "rectangle.lefthalf.inset.filled", accessibilityDescription: AppBrand.name)
            ?? NSImage(systemSymbolName: "dock.rectangle", accessibilityDescription: AppBrand.name)
            ?? NSImage()
        fallback.isTemplate = true
        return fallback
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: "")
        settings.target = self
        menu.addItem(settings)

        let login = NSMenuItem(
            title: "Open at Login",
            action: #selector(toggleLogin),
            keyEquivalent: ""
        )
        login.target = self
        login.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(login)

        let recents = NSMenuItem(
            title: "Show Recent Applications",
            action: #selector(toggleRecents),
            keyEquivalent: ""
        )
        recents.target = self
        recents.state = DockConfigStore.shared.config.showRecents ? .on : .off
        menu.addItem(recents)

        menu.addItem(.separator())

        let config = NSMenuItem(title: "Show Config in Finder", action: #selector(revealConfig), keyEquivalent: "")
        config.target = self
        menu.addItem(config)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit \(AppBrand.name)", action: #selector(quit), keyEquivalent: "")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    @objc private func openSettings() {
        DockSettingsWindow.show()
    }

    @objc private func toggleLogin() {
        do {
            try LaunchAtLogin.setEnabled(!LaunchAtLogin.isEnabled)
        } catch {
            NSLog("\(AppBrand.name): login item error: \(error.localizedDescription)")
        }
        reloadMenu()
    }

    @objc private func toggleRecents() {
        DockConfigStore.shared.update { $0.showRecents.toggle() }
        reloadMenu()
    }

    @objc private func revealConfig() {
        let url = DockConfigStore.shared.fileURL
        DockConfigStore.shared.persist()
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
