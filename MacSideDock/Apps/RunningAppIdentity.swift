import AppKit
import CoreTransferable
import Foundation
import UniformTypeIdentifiers

nonisolated enum RunningAppIdentity: Sendable {
    /// System Settings and a few other apps have shipped under more than one ID.
    private static let aliases: [String: Set<String>] = [
        "com.apple.systempreferences": [
            "com.apple.systempreferences",
            "com.apple.Preferences",
            "com.apple.Settings"
        ],
        "com.apple.Safari": [
            "com.apple.Safari"
        ]
    ]

    static func idsMatching(_ bundleIdentifier: String) -> Set<String> {
        var ids: Set<String> = [bundleIdentifier]
        for (canonical, group) in aliases where canonical == bundleIdentifier || group.contains(bundleIdentifier) {
            ids.insert(canonical)
            ids.formUnion(group)
        }
        return ids
    }

    static func isRunning(_ bundleIdentifier: String, in running: Set<String>) -> Bool {
        !idsMatching(bundleIdentifier).isDisjoint(with: running)
    }

    static func isFrontmost(_ bundleIdentifier: String, frontmost: String?) -> Bool {
        guard let frontmost else { return false }
        return idsMatching(bundleIdentifier).contains(frontmost)
    }
}

nonisolated struct DockPinnedAppID: Codable, Transferable, Equatable, Sendable {
    var bundleIdentifier: String

    static let contentType = UTType(exportedAs: "com.mohammadrehan.macsidedock.pinned-app")

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(contentType: contentType) { value in
            Data(value.bundleIdentifier.utf8)
        } importing: { data in
            DockPinnedAppID(
                bundleIdentifier: String(decoding: data, as: UTF8.self)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }

    static func itemProvider(for bundleIdentifier: String) -> NSItemProvider {
        let provider = NSItemProvider()
        provider.registerDataRepresentation(
            forTypeIdentifier: contentType.identifier,
            visibility: .ownProcess
        ) { completion in
            completion(Data(bundleIdentifier.utf8), nil)
            return nil
        }
        return provider
    }

    static func isValidBundleID(_ raw: String) -> Bool {
        let id = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty, !id.contains("/"), !id.contains("\\") else { return false }
        let parts = id.split(separator: ".")
        guard parts.count >= 2, parts.allSatisfy({ part in
            !part.isEmpty && part.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" }
        }) else { return false }
        return !id.lowercased().hasSuffix(".textclipping")
    }
}

enum DockDropParser {
    static func urlsFromDragPasteboard() -> [URL] {
        let pasteboard = NSPasteboard(name: .drag)
        if let urls = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL], !urls.isEmpty {
            return urls.filter { !isFinderClipping($0) }
        }
        if let paths = pasteboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] {
            return paths.map { URL(fileURLWithPath: $0) }.filter { !isFinderClipping($0) }
        }
        return []
    }

    static func isFinderClipping(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ext == "textclipping"
    }
}
