import AppKit
import Observation

final class DockPanelManager {
    private let store: DockConfigStore
    private let runningApps: RunningApplicationsStore
    private let recents: RecentsStore
    private let mouseMonitor = EdgeMouseMonitor()
    private var controllers: [CGDirectDisplayID: DockPanelController] = [:]
    private var screenObserver: NSObjectProtocol?
    private var observationTask: Task<Void, Never>?

    init(
        store: DockConfigStore = .shared,
        runningApps: RunningApplicationsStore = RunningApplicationsStore(),
        recents: RecentsStore = .shared
    ) {
        self.store = store
        self.runningApps = runningApps
        self.recents = recents
    }

    func start() {
        rebuild()
        mouseMonitor.onMove = { [weak self] point in
            Task { @MainActor in
                self?.controllers.values.forEach { $0.handleMouse(at: point) }
            }
        }
        mouseMonitor.start()

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.rebuild()
        }

        observationTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await withCheckedContinuation { continuation in
                    let once = OnceResume(continuation)
                    withObservationTracking {
                        _ = self.store.config
                        _ = self.recents.bundleIDs
                    } onChange: {
                        once.resume()
                    }
                }
                guard !Task.isCancelled else { break }
                self.rebuild()
            }
        }
    }

    func stop() {
        observationTask?.cancel()
        mouseMonitor.stop()
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        controllers.values.forEach { $0.close() }
        controllers.removeAll()
    }

    private func rebuild() {
        let raw = NSScreen.screens.map {
            DockDisplayLayout.Screen(id: $0.displayID, frame: $0.frame)
        }
        let unique = DockDisplayLayout.uniqueScreens(raw)
        let ids = Set(unique.map(\.id))

        for (id, controller) in controllers where !ids.contains(id) {
            controller.close()
            controllers.removeValue(forKey: id)
        }

        let screensByID = Dictionary(uniqueKeysWithValues: NSScreen.screens.map { ($0.displayID, $0) })
        for entry in unique {
            guard let screen = screensByID[entry.id] ?? NSScreen.screens.first(where: {
                abs($0.frame.minX - entry.frame.minX) < 1 && abs($0.frame.minY - entry.frame.minY) < 1
            }) else { continue }

            if let existing = controllers[entry.id] {
                existing.applyLayout()
            } else {
                controllers[entry.id] = DockPanelController(
                    screen: screen,
                    store: store,
                    runningApps: runningApps,
                    recents: recents
                )
            }
        }
    }
}

/// `withObservationTracking` can fire `onChange` more than once. Resuming a
/// continuation twice aborts the process.
private final class OnceResume: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Never>?

    init(_ continuation: CheckedContinuation<Void, Never>) {
        self.continuation = continuation
    }

    func resume() {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume()
    }
}
