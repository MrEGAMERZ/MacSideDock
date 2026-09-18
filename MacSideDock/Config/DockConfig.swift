import Foundation

nonisolated enum DisplayName: Sendable {
    static func withoutExtension(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return raw }
        let url = URL(fileURLWithPath: trimmed)
        let ext = url.pathExtension.lowercased()
        guard ["app", "dmg", "pkg", "bundle", "service", "appex"].contains(ext) else {
            return trimmed
        }
        return url.deletingPathExtension().lastPathComponent
    }
}

nonisolated enum DockEdge: String, Codable, CaseIterable, Identifiable, Sendable {
    case left
    case right

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .left: return "Left"
        case .right: return "Right"
        }
    }
}

nonisolated struct PinnedFolder: Codable, Equatable, Sendable, Identifiable {
    var path: String
    var bookmark: Data?

    var id: String { path }

    var name: String {
        DisplayName.withoutExtension(URL(fileURLWithPath: path).lastPathComponent)
    }
}

nonisolated struct DockConfig: Codable, Equatable, Sendable {
    var version: Int
    var edge: DockEdge
    var autoHide: Bool
    var reserveScreenSpace: Bool
    var iconSize: Double
    var magnification: Double
    var pinnedApps: [String]
    var showRecents: Bool
    var recentsLimit: Int
    var pinnedFolders: [PinnedFolder]
    var showRunningIndicators: Bool
    var lastMagnification: Double

    static let schemaVersion = 3
    static let minimumIconSize = 24.0
    static let maximumIconSize = 96.0
    static let minimumMagnification = 1.0
    static let maximumMagnification = 3.0
    static let minimumRecentsLimit = 3
    static let maximumRecentsLimit = 12
    static let minimumPinnedApps = 1
    static let maximumPinnedApps = 10

    static let `default` = DockConfig(
        version: schemaVersion,
        edge: .left,
        autoHide: true,
        reserveScreenSpace: false,
        iconSize: 48,
        magnification: 1.8,
        pinnedApps: [
            "com.apple.finder",
            "com.apple.Safari",
            "com.apple.mail",
            "com.apple.Notes",
            "com.apple.systempreferences"
        ],
        showRecents: true,
        recentsLimit: 6,
        pinnedFolders: [],
        showRunningIndicators: true,
        lastMagnification: 1.8
    )

    var shouldAutoHide: Bool {
        autoHide && !reserveScreenSpace
    }

    var clampedIconSize: Double {
        min(max(iconSize, Self.minimumIconSize), Self.maximumIconSize)
    }

    var clampedMagnification: Double {
        min(max(magnification, Self.minimumMagnification), Self.maximumMagnification)
    }

    var isMagnificationOn: Bool {
        clampedMagnification > 1.01
    }

    init(
        version: Int,
        edge: DockEdge,
        autoHide: Bool,
        reserveScreenSpace: Bool,
        iconSize: Double,
        magnification: Double,
        pinnedApps: [String],
        showRecents: Bool = true,
        recentsLimit: Int = 6,
        pinnedFolders: [PinnedFolder] = [],
        showRunningIndicators: Bool = true,
        lastMagnification: Double = 1.8
    ) {
        self.version = version
        self.edge = edge
        self.autoHide = autoHide
        self.reserveScreenSpace = reserveScreenSpace
        self.iconSize = iconSize
        self.magnification = magnification
        self.pinnedApps = Self.clampedPinnedApps(pinnedApps)
        self.showRecents = showRecents
        self.recentsLimit = recentsLimit
        self.pinnedFolders = Self.uniqueFolders(pinnedFolders)
        self.showRunningIndicators = showRunningIndicators
        self.lastMagnification = lastMagnification
        clampMetrics()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? Self.schemaVersion
        edge = try container.decodeIfPresent(DockEdge.self, forKey: .edge) ?? .left
        autoHide = try container.decodeIfPresent(Bool.self, forKey: .autoHide) ?? true
        reserveScreenSpace = try container.decodeIfPresent(Bool.self, forKey: .reserveScreenSpace) ?? false
        iconSize = try container.decodeIfPresent(Double.self, forKey: .iconSize) ?? Self.default.iconSize
        magnification = try container.decodeIfPresent(Double.self, forKey: .magnification) ?? Self.default.magnification
        pinnedApps = Self.clampedPinnedApps(Self.decodePinnedApps(container))
        showRecents = try container.decodeIfPresent(Bool.self, forKey: .showRecents) ?? true
        recentsLimit = try container.decodeIfPresent(Int.self, forKey: .recentsLimit) ?? 6
        pinnedFolders = try container.decodeIfPresent([PinnedFolder].self, forKey: .pinnedFolders) ?? []
        pinnedFolders = Self.uniqueFolders(pinnedFolders)
        showRunningIndicators = try container.decodeIfPresent(Bool.self, forKey: .showRunningIndicators) ?? true
        lastMagnification = try container.decodeIfPresent(Double.self, forKey: .lastMagnification) ?? Self.default.lastMagnification
        clampMetrics()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(edge, forKey: .edge)
        try container.encode(autoHide, forKey: .autoHide)
        try container.encode(reserveScreenSpace, forKey: .reserveScreenSpace)
        try container.encode(iconSize, forKey: .iconSize)
        try container.encode(magnification, forKey: .magnification)
        try container.encode(pinnedApps, forKey: .pinnedApps)
        try container.encode(showRecents, forKey: .showRecents)
        try container.encode(recentsLimit, forKey: .recentsLimit)
        try container.encode(pinnedFolders, forKey: .pinnedFolders)
        try container.encode(showRunningIndicators, forKey: .showRunningIndicators)
        try container.encode(lastMagnification, forKey: .lastMagnification)
    }

    mutating func pin(_ bundleIdentifier: String, at index: Int? = nil) {
        let id = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return }
        let alreadyPinned = pinnedApps.contains(id)
        guard alreadyPinned || pinnedApps.count < Self.maximumPinnedApps else { return }
        var apps = pinnedApps.filter { $0 != id }
        let insertion = min(max(index ?? apps.count, 0), apps.count)
        apps.insert(id, at: insertion)
        pinnedApps = Self.clampedPinnedApps(apps)
    }

    @discardableResult
    mutating func unpin(_ bundleIdentifier: String) -> Bool {
        guard pinnedApps.count > Self.minimumPinnedApps else { return false }
        let before = pinnedApps.count
        pinnedApps.removeAll { $0 == bundleIdentifier }
        if pinnedApps.isEmpty {
            pinnedApps = [Self.default.pinnedApps.first ?? "com.apple.finder"]
        }
        return pinnedApps.count < before
    }

    mutating func movePinnedApp(from source: Int, to destination: Int) {
        guard pinnedApps.indices.contains(source) else { return }
        var apps = pinnedApps
        let item = apps.remove(at: source)
        var adjusted = destination
        if source < destination {
            adjusted -= 1
        }
        adjusted = min(max(adjusted, 0), apps.count)
        apps.insert(item, at: adjusted)
        pinnedApps = apps
    }

    mutating func pinFolder(_ folder: PinnedFolder, at index: Int? = nil) {
        var folders = pinnedFolders.filter { $0.path != folder.path }
        let insertion = min(max(index ?? folders.count, 0), folders.count)
        folders.insert(folder, at: insertion)
        pinnedFolders = folders
    }

    mutating func unpinFolder(_ path: String) {
        pinnedFolders.removeAll { $0.path == path }
    }

    mutating func setMagnification(_ value: Double) {
        magnification = value
        if value > 1.01 {
            lastMagnification = value
        }
    }

    mutating func toggleMagnification() {
        if isMagnificationOn {
            lastMagnification = clampedMagnification
            magnification = 1
        } else {
            magnification = min(max(lastMagnification, 1.5), Self.maximumMagnification)
        }
    }

    mutating func toggleHiding() {
        autoHide.toggle()
        if autoHide {
            reserveScreenSpace = false
        }
    }

    /// Ensures pinned app count stays within the public min/max.
    mutating func sanitize() {
        pinnedApps = Self.clampedPinnedApps(pinnedApps)
        clampMetrics()
    }

    private mutating func clampMetrics() {
        iconSize = min(max(iconSize, Self.minimumIconSize), Self.maximumIconSize)
        magnification = min(max(magnification, Self.minimumMagnification), Self.maximumMagnification)
        recentsLimit = min(max(recentsLimit, Self.minimumRecentsLimit), Self.maximumRecentsLimit)
        lastMagnification = min(max(lastMagnification, 1.5), Self.maximumMagnification)
        if lastMagnification <= 1.01 {
            lastMagnification = Self.default.lastMagnification
        }
        if version < 1 {
            version = Self.schemaVersion
        }
        pinnedApps = Self.clampedPinnedApps(pinnedApps)
    }

    private static func uniqueFolders(_ folders: [PinnedFolder]) -> [PinnedFolder] {
        var seen = Set<String>()
        return folders.filter { folder in
            let path = folder.path.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty, seen.insert(path).inserted else { return false }
            return true
        }
    }

    private static func uniqueBundleIDs(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        return ids.filter { id in
            let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { return false }
            return true
        }
    }

    /// Keeps at least one app and at most `maximumPinnedApps`.
    private static func clampedPinnedApps(_ ids: [String]) -> [String] {
        var apps = Array(uniqueBundleIDs(ids).prefix(maximumPinnedApps))
        if apps.isEmpty {
            apps = [Self.default.pinnedApps.first ?? "com.apple.finder"]
        }
        return apps
    }

    private static func decodePinnedApps(_ container: KeyedDecodingContainer<CodingKeys>) -> [String] {
        if let ids = try? container.decode([String].self, forKey: .pinnedApps) {
            return uniqueBundleIDs(ids)
        }
        if let objects = try? container.decode([PinnedAppObject].self, forKey: .pinnedApps) {
            return uniqueBundleIDs(objects.map(\.bundleIdentifier))
        }
        return `default`.pinnedApps
    }

    private struct PinnedAppObject: Codable {
        var bundleIdentifier: String
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case edge
        case autoHide
        case reserveScreenSpace
        case iconSize
        case magnification
        case pinnedApps
        case showRecents
        case recentsLimit
        case pinnedFolders
        case showRunningIndicators
        case lastMagnification
    }
}
