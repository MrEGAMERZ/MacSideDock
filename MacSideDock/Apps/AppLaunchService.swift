import AppKit

enum AppLaunchService {
    static func handleClick(bundleIdentifier: String) {
        let matches = NSWorkspace.shared.runningApplications.filter { $0.bundleIdentifier == bundleIdentifier }
        let isRunning = matches.contains { !$0.isTerminated }
        let isActive = matches.contains { $0.isActive }

        switch AppClickAction.resolve(isRunning: isRunning, isActive: isActive) {
        case .launch:
            launch(bundleIdentifier)
        case .activate:
            matches.first(where: { !$0.isTerminated })?.activate()
        case .hide:
            matches.forEach { $0.hide() }
        }
    }

    static func launch(_ bundleIdentifier: String) {
        guard let url = AppInfoResolver.url(for: bundleIdentifier) else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            if let error {
                NSLog("SIDEDOCK: failed to open \(bundleIdentifier): \(error.localizedDescription)")
            }
        }
    }

    static func hide(_ bundleIdentifier: String) {
        running(bundleIdentifier).forEach { $0.hide() }
    }

    static func reveal(_ bundleIdentifier: String) {
        running(bundleIdentifier).first?.activate()
    }

    static func isHidden(_ bundleIdentifier: String) -> Bool {
        running(bundleIdentifier).contains { $0.isHidden }
    }

    static func running(_ bundleIdentifier: String) -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier == bundleIdentifier && !$0.isTerminated
        }
    }

    static func revealInFinder(_ bundleIdentifier: String) {
        guard let url = AppInfoResolver.url(for: bundleIdentifier) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
