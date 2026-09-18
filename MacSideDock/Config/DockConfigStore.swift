import Darwin
import Foundation
import Observation

@Observable
final class DockConfigStore {
    static let shared = DockConfigStore()

    private(set) var config: DockConfig
    let fileURL: URL

    private var directorySource: DispatchSourceFileSystemObject?
    private var directoryDescriptor: Int32 = -1
    private var isWriting = false
    private var lastWrittenData: Data?
    /// Ignore FS events briefly after our own write. Atomic saves fire delayed
    /// directory notifications that otherwise reload a stale snapshot and
    /// resurrect apps the user just removed.
    private var ignoreExternalReloadUntil: Date?

    static var modernFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config")
            .appendingPathComponent(AppBrand.configDirectoryName)
            .appendingPathComponent("config.json")
    }

    static var legacyFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config")
            .appendingPathComponent(AppBrand.legacyConfigDirectoryName)
            .appendingPathComponent("config.json")
    }

    /// Always writes under `~/.config/sidedock/`. Loads legacy once if needed.
    static var defaultFileURL: URL { modernFileURL }

    /// `…/sidedock/config.json` → `…/mac-side-dock/config.json` (same parent).
    static func legacySibling(of writeURL: URL) -> URL {
        writeURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(AppBrand.legacyConfigDirectoryName)
            .appendingPathComponent("config.json")
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    static let decoder = JSONDecoder()

    init(fileURL: URL = DockConfigStore.defaultFileURL, watch: Bool = true) {
        self.fileURL = fileURL
        let fm = FileManager.default
        let sourceURL: URL
        if fm.fileExists(atPath: fileURL.path) {
            sourceURL = fileURL
        } else {
            let legacy = Self.legacySibling(of: fileURL)
            sourceURL = fm.fileExists(atPath: legacy.path) ? legacy : fileURL
        }
        var loaded = Self.load(from: sourceURL)
        loaded.sanitize()
        self.config = loaded
        if watch {
            startWatching()
        }
        let needsMigrate = sourceURL != fileURL
        let needsClamp = loaded.pinnedApps.count > DockConfig.maximumPinnedApps
            || loaded.pinnedApps.count < DockConfig.minimumPinnedApps
        if needsMigrate || needsClamp || !fm.fileExists(atPath: fileURL.path) {
            persist()
        }
    }

    deinit {
        stopWatching()
    }

    func replace(_ newConfig: DockConfig) {
        config = newConfig
        persist()
    }

    func update(_ mutate: (inout DockConfig) -> Void) {
        var next = config
        mutate(&next)
        next.sanitize()
        replace(next)
    }

    func pin(_ bundleIdentifier: String, at index: Int? = nil) {
        update { $0.pin(bundleIdentifier, at: index) }
    }

    @discardableResult
    func unpin(_ bundleIdentifier: String) -> Bool {
        var removed = false
        update { removed = $0.unpin(bundleIdentifier) }
        return removed
    }

    func movePinnedApp(from source: Int, to destination: Int) {
        update { $0.movePinnedApp(from: source, to: destination) }
    }

    func pinFolder(_ folder: PinnedFolder, at index: Int? = nil) {
        update { $0.pinFolder(folder, at: index) }
    }

    func unpinFolder(_ path: String) {
        update { $0.unpinFolder(path) }
    }

    func reloadFromDisk() {
        config = Self.load(from: fileURL, fallback: config)
    }

    func persist() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try Self.encoder.encode(config)
            isWriting = true
            lastWrittenData = data
            ignoreExternalReloadUntil = Date().addingTimeInterval(1.0)
            try data.write(to: fileURL, options: .atomic)
            // Keep the write shield up across the rename notification.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.isWriting = false
            }
        } catch {
            isWriting = false
            NSLog("SIDEDOCK: failed to save config: \(error.localizedDescription)")
        }
    }

    private static func load(from url: URL, fallback: DockConfig? = nil) -> DockConfig {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else {
            let created = DockConfig.default
            do {
                try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                let data = try encoder.encode(created)
                try data.write(to: url, options: .atomic)
            } catch {
                NSLog("SIDEDOCK: failed to write default config: \(error.localizedDescription)")
            }
            return created
        }

        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(DockConfig.self, from: data)
        } catch {
            NSLog("SIDEDOCK: invalid config at \(url.path), keeping previous/defaults: \(error.localizedDescription)")
            return fallback ?? .default
        }
    }

    private func startWatching() {
        let directory = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let fd = open(directory.path, O_EVTONLY)
        guard fd >= 0 else { return }
        directoryDescriptor = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .attrib],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.handleDirectoryChange()
        }
        source.setCancelHandler { [weak self] in
            guard let self, self.directoryDescriptor >= 0 else { return }
            close(self.directoryDescriptor)
            self.directoryDescriptor = -1
        }
        directorySource = source
        source.resume()
    }

    private func stopWatching() {
        directorySource?.cancel()
        directorySource = nil
    }

    private func handleDirectoryChange() {
        if isWriting { return }
        if let until = ignoreExternalReloadUntil, Date() < until { return }
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if data == lastWrittenData { return }
        do {
            let decoded = try Self.decoder.decode(DockConfig.self, from: data)
            lastWrittenData = data
            if decoded != config {
                config = decoded
            }
        } catch {
            NSLog("SIDEDOCK: ignored invalid live config edit: \(error.localizedDescription)")
        }
    }
}
