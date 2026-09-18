import AppKit

enum AppInfoResolver {
    static func url(for bundleIdentifier: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
    }

    static func name(for bundleIdentifier: String) -> String {
        if let url = url(for: bundleIdentifier) {
            if let label = bundleLabel(for: url) {
                return DisplayName.withoutExtension(label)
            }
            return DisplayName.withoutExtension(FileManager.default.displayName(atPath: url.path))
        }
        return DisplayName.withoutExtension(bundleIdentifier)
    }

    private static func bundleLabel(for url: URL) -> String? {
        guard let bundle = Bundle(url: url) else { return nil }
        let keys = ["CFBundleDisplayName", "CFBundleName"]
        for key in keys {
            if let value = bundle.localizedInfoDictionary?[key] as? String, !value.isEmpty {
                return value
            }
            if let value = bundle.infoDictionary?[key] as? String, !value.isEmpty {
                return value
            }
        }
        return nil
    }

    static func icon(for bundleIdentifier: String) -> NSImage {
        if let url = url(for: bundleIdentifier) {
            return FolderAccess.sizedWorkspaceIcon(for: url.path)
        }
        return NSImage(systemSymbolName: "questionmark.app.dashed", accessibilityDescription: nil)
            ?? NSImage(named: NSImage.applicationIconName)
            ?? NSImage()
    }

    nonisolated static func bundleIdentifier(forAppURL url: URL) -> String? {
        var current = (try? URL(resolvingAliasFileAt: url, options: [.withoutUI, .withoutMounting])) ?? url
        current = current.resolvingSymlinksInPath()
        var walker = current
        while true {
            if let id = bundleID(at: walker) {
                return id
            }
            let parent = walker.deletingLastPathComponent()
            guard parent.path != walker.path else { break }
            walker = parent
        }
        return nil
    }

    private nonisolated static func bundleID(at url: URL) -> String? {
        if url.pathExtension == "app", let id = Bundle(url: url)?.bundleIdentifier {
            return id
        }
        let isApp = (try? url.resourceValues(forKeys: [.isApplicationKey]).isApplication) ?? false
        if isApp {
            return Bundle(url: url)?.bundleIdentifier
        }
        return nil
    }
}
