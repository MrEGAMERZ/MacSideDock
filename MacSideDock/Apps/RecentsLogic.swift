import Foundation

nonisolated enum RecentsLogic: Sendable {
    static func record(
        _ bundleIdentifier: String,
        into ids: inout [String],
        ignoring ignored: Set<String>,
        limit: Int
    ) {
        let id = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty, !ignored.contains(id), limit > 0 else { return }
        ids.removeAll { $0 == id }
        ids.insert(id, at: 0)
        if ids.count > limit {
            ids = Array(ids.prefix(limit))
        }
    }

    static func visible(ids: [String], excluding pinned: [String], limit: Int) -> [String] {
        let pinnedSet = Set(pinned)
        return Array(ids.filter { !pinnedSet.contains($0) }.prefix(max(limit, 0)))
    }
}
