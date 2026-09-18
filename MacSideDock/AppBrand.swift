import Foundation

enum AppBrand {
    static let name = "SIDEDOCK"
    /// Public config folder under `~/.config/`.
    static let configDirectoryName = "sidedock"
    /// Older builds wrote here; still read once for migration.
    static let legacyConfigDirectoryName = "mac-side-dock"
}
