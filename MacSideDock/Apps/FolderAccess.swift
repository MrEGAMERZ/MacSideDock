import AppKit
import Foundation

enum FolderAccess {
    static var isSandboxed: Bool {
        ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }

    static func bookmark(for url: URL) -> Data? {
        let resolved = url.resolvingSymlinksInPath()
        let options: URL.BookmarkCreationOptions = isSandboxed ? [.withSecurityScope] : []
        do {
            return try resolved.bookmarkData(
                options: options,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            NSLog("SIDEDOCK: bookmark failed for \(resolved.path): \(error.localizedDescription)")
            return nil
        }
    }

    static func resolve(_ folder: PinnedFolder) -> URL? {
        if let data = folder.bookmark {
            var stale = false
            let options: URL.BookmarkResolutionOptions = isSandboxed ? [.withSecurityScope] : []
            if let url = try? URL(
                resolvingBookmarkData: data,
                options: options,
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) {
                if isSandboxed {
                    _ = url.startAccessingSecurityScopedResource()
                }
                return url
            }
        }
        let url = URL(fileURLWithPath: folder.path, isDirectory: true)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return nil
        }
        return url
    }

    static func icon(for url: URL) -> NSImage {
        sizedWorkspaceIcon(for: url.path)
    }

    static func sizedWorkspaceIcon(for path: String) -> NSImage {
        let source = NSWorkspace.shared.icon(forFile: path)
        let icon = (source.copy() as? NSImage) ?? NSImage(size: NSSize(width: 128, height: 128))
        icon.size = NSSize(width: 128, height: 128)
        return icon
    }

    static func contents(of url: URL, limit: Int = 24) -> [URL] {
        let keys: [URLResourceKey] = [.isHiddenKey, .isDirectoryKey]
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: keys,
            options: [.skipsPackageDescendants]
        ) else { return [] }

        return items
            .filter { item in
                let hidden = (try? item.resourceValues(forKeys: [.isHiddenKey]).isHidden) ?? false
                return !hidden && item.lastPathComponent != ".DS_Store"
            }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .prefix(limit)
            .map { $0 }
    }

    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    static func folder(fromDroppedURL url: URL) -> PinnedFolder? {
        withSecurityAccess(to: url) { accessible in
            let resolved = accessible.resolvingSymlinksInPath()
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: resolved.path, isDirectory: &isDirectory),
                  isDirectory.boolValue,
                  resolved.pathExtension.lowercased() != "app"
            else { return nil }
            return PinnedFolder(path: resolved.path, bookmark: bookmark(for: resolved))
        }
    }

    /// Finder drops are often security-scoped. Access must start before path checks or bookmarking.
    @discardableResult
    static func withSecurityAccess<T>(to url: URL, _ body: (URL) -> T) -> T {
        let started = url.startAccessingSecurityScopedResource()
        defer {
            if started {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return body(url)
    }
}
