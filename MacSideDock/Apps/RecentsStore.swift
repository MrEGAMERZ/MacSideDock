import AppKit
import Observation

@Observable
final class RecentsStore {
    static let shared = RecentsStore()

    private(set) var bundleIDs: [String] = []
    private let fileURL: URL
    private var observer: NSObjectProtocol?

    init(fileURL: URL = RecentsStore.defaultFileURL, observeWorkspace: Bool = true) {
        self.fileURL = fileURL
        self.bundleIDs = Self.load(from: fileURL)
        if observeWorkspace {
            start()
        }
    }

    static var defaultFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .appendingPathComponent("Application Support")
            .appendingPathComponent("MacSideDock")
            .appendingPathComponent("recents.json")
    }

    func visible(excluding pinned: [String], limit: Int) -> [String] {
        RecentsLogic.visible(ids: bundleIDs, excluding: pinned, limit: limit)
    }

    func record(_ bundleIdentifier: String, ignoring ignored: Set<String>, limit: Int) {
        RecentsLogic.record(bundleIdentifier, into: &bundleIDs, ignoring: ignored, limit: max(limit, 12))
        persist()
    }

    func start() {
        guard observer == nil else { return }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.activationPolicy == .regular,
                  let id = app.bundleIdentifier
            else { return }
            Task { @MainActor in
                self?.recordLaunch(id)
            }
        }
    }

    func stop() {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            self.observer = nil
        }
    }

    private func recordLaunch(_ bundleIdentifier: String) {
        var ignored = Set<String>()
        if let own = Bundle.main.bundleIdentifier {
            ignored.insert(own)
        }
        record(bundleIdentifier, ignoring: ignored, limit: 24)
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(bundleIDs)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("SIDEDOCK: failed to save recents: \(error.localizedDescription)")
        }
    }

    private static func load(from url: URL) -> [String] {
        guard let data = try? Data(contentsOf: url),
              let ids = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return ids
    }
}
