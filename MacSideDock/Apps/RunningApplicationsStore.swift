import AppKit
import Observation

@Observable
final class RunningApplicationsStore {
    private(set) var runningBundleIDs: Set<String> = []
    private(set) var frontmostBundleID: String?

    @ObservationIgnored
    private var observations: [NSObjectProtocol] = []

    init() {
        refresh()
        let center = NSWorkspace.shared.notificationCenter
        let names: [NSNotification.Name] = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.didHideApplicationNotification,
            NSWorkspace.didUnhideApplicationNotification
        ]
        observations = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.refresh()
                }
            }
        }
    }

    deinit {
        observations.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
    }

    func isRunning(_ bundleIdentifier: String) -> Bool {
        RunningAppIdentity.isRunning(bundleIdentifier, in: runningBundleIDs)
    }

    func isFrontmost(_ bundleIdentifier: String) -> Bool {
        RunningAppIdentity.isFrontmost(bundleIdentifier, frontmost: frontmostBundleID)
    }

    func refresh() {
        let apps = NSWorkspace.shared.runningApplications
        runningBundleIDs = Set(apps.compactMap { app in
            guard !app.isTerminated, app.activationPolicy == .regular, let id = app.bundleIdentifier else { return nil }
            return id
        })
        frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
}
