import AppKit

enum AppInstall {
    private static let declinedMoveKey = "didDeclineMoveToApplications"

    /// Returns `true` when this process is quitting so the Applications copy can take over.
    @discardableResult
    static func handleFirstLaunchRelocation() -> Bool {
        let bundleURL = Bundle.main.bundleURL
        guard AppInstallLocation.shouldOfferMove(bundleURL) else { return false }
        guard !UserDefaults.standard.bool(forKey: declinedMoveKey) else { return false }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Move \(AppBrand.name) to the Applications folder?"
        alert.informativeText = "That way it can open at login and keep running after you eject the installer."
        alert.addButton(withTitle: "Move to Applications Folder")
        alert.addButton(withTitle: "Not Now")

        let response = alert.runModal()
        if response != .alertFirstButtonReturn {
            UserDefaults.standard.set(true, forKey: declinedMoveKey)
            NSApp.setActivationPolicy(.accessory)
            return false
        }

        do {
            let destination = try copyToApplications(from: bundleURL)
            relaunch(at: destination)
            return true
        } catch {
            let failure = NSAlert()
            failure.alertStyle = .warning
            failure.messageText = "Couldn’t move \(AppBrand.name)"
            failure.informativeText = error.localizedDescription + "\n\nDrag it into Applications yourself, then open it from there."
            failure.addButton(withTitle: "OK")
            failure.runModal()
            NSApp.setActivationPolicy(.accessory)
            return false
        }
    }

    private static func copyToApplications(from bundleURL: URL) throws -> URL {
        let fm = FileManager.default
        let name = bundleURL.lastPathComponent
        var destination = URL(fileURLWithPath: "/Applications", isDirectory: true)
            .appendingPathComponent(name)

        do {
            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }
            try fm.copyItem(at: bundleURL, to: destination)
        } catch {
            let homeApps = fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
            try fm.createDirectory(at: homeApps, withIntermediateDirectories: true)
            destination = homeApps.appendingPathComponent(name)
            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }
            try fm.copyItem(at: bundleURL, to: destination)
        }

        stripQuarantine(at: destination)
        return destination
    }

    private static func stripQuarantine(at url: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        process.arguments = ["-dr", "com.apple.quarantine", url.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }

    private static func relaunch(at url: URL) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            NSApp.terminate(nil)
        }
    }
}
