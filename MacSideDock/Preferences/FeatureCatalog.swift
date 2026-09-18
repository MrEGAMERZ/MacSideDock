import Foundation

nonisolated enum FeatureStatus: String, Sendable {
    case shipped
    case partial
    case notShipped
}

nonisolated struct FeatureItem: Identifiable, Sendable, Equatable {
    var id: String
    var title: String
    var status: FeatureStatus
    var code: String
    var detail: String
}

enum FeatureCatalog {
    static let items: [FeatureItem] = [
        FeatureItem(
            id: "edge-panel",
            title: "Floating vertical panel on left/right edge, per screen",
            status: .shipped,
            code: "Dock/DockPanelController.swift",
            detail: "NSPanel on every NSScreen, repositioned when displays change."
        ),
        FeatureItem(
            id: "pin-apps",
            title: "Pin apps so they stay visible when not running",
            status: .shipped,
            code: "Config/DockConfig.swift",
            detail: "JSON pinnedApps list, always rendered."
        ),
        FeatureItem(
            id: "click-launch",
            title: "Click to launch / focus; click again to hide",
            status: .shipped,
            code: "Apps/AppClickAction.swift",
            detail: "NSWorkspace launch, activate, or hide."
        ),
        FeatureItem(
            id: "magnify",
            title: "Hover magnification",
            status: .shipped,
            code: "Dock/DockMagnification.swift",
            detail: "Cosine falloff; magnified icons occupy real space so neighbors spread."
        ),
        FeatureItem(
            id: "autohide",
            title: "Auto-hide, reveal on edge approach",
            status: .shipped,
            code: "Dock/DockRevealLogic.swift",
            detail: "Global mouse monitor, SwiftUI spring reveal inside a fixed panel."
        ),
        FeatureItem(
            id: "drag-drop",
            title: "Drag-and-drop to pin and reorder apps",
            status: .shipped,
            code: "Dock/DockView.swift",
            detail: "Drop an app between icons; the list opens a slot like the system Dock."
        ),
        FeatureItem(
            id: "reserve-space",
            title: "Reserve screen space",
            status: .partial,
            code: "Config/DockConfig.swift",
            detail: "Always-visible mode. macOS has no public API to shrink other apps' visibleFrame."
        ),
        FeatureItem(
            id: "json-config",
            title: "Plaintext JSON config, live reload",
            status: .shipped,
            code: "Config/DockConfigStore.swift",
            detail: "~/.config/sidedock/config.json, directory watcher."
        ),
        FeatureItem(
            id: "login-item",
            title: "Launch at login",
            status: .shipped,
            code: "Apps/LaunchAtLogin.swift",
            detail: "SMAppService; enabled on first launch; toggle in menu bar and Settings."
        ),
        FeatureItem(
            id: "menu-bar",
            title: "Menu bar extra for Settings and quit",
            status: .shipped,
            code: "Preferences/StatusItemController.swift",
            detail: "Status item in the top menu bar."
        ),
        FeatureItem(
            id: "recents",
            title: "Recently used apps section",
            status: .shipped,
            code: "Apps/RecentsStore.swift",
            detail: "Tracks launches; shows unpinned recent apps on the dock."
        ),
        FeatureItem(
            id: "folders",
            title: "Pinned folders with peek",
            status: .shipped,
            code: "Dock/FolderPeekView.swift",
            detail: "Drop a folder onto the dock; hover to sneak the contents."
        ),
        FeatureItem(
            id: "no-a11y",
            title: "No Accessibility / Screen Recording permission",
            status: .shipped,
            code: "Dock/EdgeMouseMonitor.swift",
            detail: "Edge detect via NSEvent global monitor only."
        ),
        FeatureItem(
            id: "previews",
            title: "Live window previews",
            status: .notShipped,
            code: "",
            detail: "Needs Screen Recording. Out of v1; still out unless we take that permission."
        ),
        FeatureItem(
            id: "media",
            title: "Media controls",
            status: .notShipped,
            code: "",
            detail: "Not in the core Dock mechanic."
        ),
        FeatureItem(
            id: "calendar",
            title: "Calendar widget",
            status: .notShipped,
            code: "",
            detail: "Not in the core Dock mechanic."
        ),
        FeatureItem(
            id: "snapping",
            title: "Window snapping",
            status: .notShipped,
            code: "",
            detail: "Not in the core Dock mechanic."
        ),
        FeatureItem(
            id: "switcher",
            title: "Window switcher",
            status: .notShipped,
            code: "",
            detail: "Not in the core Dock mechanic."
        )
    ]

    static var shipped: [FeatureItem] { items.filter { $0.status == .shipped } }
    static var partial: [FeatureItem] { items.filter { $0.status == .partial } }
    static var notShipped: [FeatureItem] { items.filter { $0.status == .notShipped } }
}
