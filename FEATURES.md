# Features

Mapped from the original product idea to code. Same list appears in **Settings → Features**.

## Shipped

| Feature | Code |
|---|---|
| Floating vertical panel, left/right, per screen | `Dock/DockPanelController.swift` |
| Pin apps (visible when not running) | `Config/DockConfig.swift` |
| Click launch / focus / hide | `Apps/AppClickAction.swift` |
| Hover magnification (120fps, correct Y) | `Dock/DockMagnification.swift` |
| Auto-hide on edge approach, no Accessibility | `Dock/DockRevealLogic.swift`, `Dock/EdgeMouseMonitor.swift` |
| Drag-and-drop pin + reorder | `Dock/DockView.swift` |
| JSON config + live reload | `Config/DockConfigStore.swift` |
| Launch at login (`SMAppService`, on by default) | `Apps/LaunchAtLogin.swift` |
| Menu bar icon → Settings, login, recents, quit | `Preferences/StatusItemController.swift` |
| Recently used apps | `Apps/RecentsStore.swift` |
| Folder pin + hover peek | `Dock/FolderPeekView.swift` |
| App icon + menu bar icon | `Assets.xcassets/AppIcon`, `MenuBarIcon` |
| Hover name tags | `Dock/DockNameTag.swift` |

## Partial

| Feature | Why |
|---|---|
| Reserve screen space | Always-visible mode works. macOS has no public API to shrink other apps' `visibleFrame`. |

## Not built (idea doc out of v1, still out)

- Live window previews (needs Screen Recording)
- Media controls
- Calendar
- Window snapping
- Window switcher

## Distribution backlog

- README gallery photos of the running dock
- Localization (Settings + menu bar)
- Homebrew cask (needs a GitHub Release)
- Developer ID signing + notarization
- App Store (sandbox + Apple Developer Program)
- Sparkle / auto-update
