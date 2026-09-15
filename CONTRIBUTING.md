# Contributing to Mac Side Dock

Thank you for wanting to work on this. Mac Side Dock is meant to feel like it shipped with the Mac: quiet, precise, and a little invisible until you need it.

If a change makes the dock noisier, more permission-hungry, or less like the system Dock, it probably does not belong here.

## What we are building

A **secondary Dock** on the left or right edge of every display. Pin apps, browse recents, peek folders, auto-hide, magnify on hover.

We are not building a widget shelf, a window manager, or a Sidebar clone.

## Before you start

1. Read the [README](README.md) and [FEATURES.md](FEATURES.md).
2. Run the app from Xcode on your machine. The feel is the product.
3. Open an issue for anything larger than a small fix, so we do not duplicate work.

## Build

Requires **macOS 26.5+** and **Xcode 26**.

```bash
open MacSideDock.xcodeproj
```

Scheme: **MacSideDock**. Debug is unsandboxed on purpose, so dropping apps and folders behaves like a normal Mac app. Release (and `./scripts/make-dmg.sh`) is sandboxed.

Tests:

```bash
xcodebuild -scheme MacSideDock -destination 'platform=macOS' test
```

Or Product → Test in Xcode.

## Where to change things

| You want to touch… | Start here |
| :--- | :--- |
| Icon size, hover scale, neighbors spreading | `Dock/DockMagnification.swift` |
| Auto-hide timing and edge reveal | `Dock/DockRevealLogic.swift`, `Dock/EdgeMouseMonitor.swift` |
| Glass, layout, drop, reorder | `Dock/DockView.swift`, `Dock/DockGlass.swift` |
| Click / launch / hide | `Apps/AppClickAction.swift`, `Apps/AppLaunchService.swift` |
| Recents | `Apps/RecentsStore.swift`, `Apps/RecentsLogic.swift` |
| Folders | `Dock/FolderPeekView.swift`, `Apps/FolderAccess.swift` |
| JSON keys and defaults | `Config/DockConfig.swift` |
| Settings or menu bar | `Preferences/PreferencesView.swift`, `Preferences/StatusItemController.swift` |
| Per-display panels | `Dock/DockPanelManager.swift`, `Dock/DockPanelController.swift` |

If you add a user-facing capability, add it to `Preferences/FeatureCatalog.swift` and [FEATURES.md](FEATURES.md) in the same PR.

## How to work

- Match the file you are in. Swift, SwiftUI, and AppKit are already mixed on purpose: AppKit for panels and events, SwiftUI for the dock chrome.
- Keep logic that can be tested (`DockMagnification`, `DockRevealLogic`, `DockConfig`) free of AppKit where it already is.
- Do not add Accessibility, Screen Recording, or Input Monitoring for a core feature.
- Do not replace the JSON config with a hidden binary store.
- Prefer a small PR that one person can review in one sitting.

## Pull requests

1. Branch from the default branch.
2. Describe the user-visible change in the PR body: what you did, how you tried it.
3. Include a screenshot or a short screen recording when the dock’s look or motion changes.
4. Update tests when you change config, magnification, or reveal policy.

## Good first issues

These help the project without requiring a full map of the animation code:

- **App icon** — `MacSideDock/Assets.xcassets/AppIcon.appiconset` has no images yet. A Liquid Glass–aware macOS icon would immediately make the project look finished.
- **README gallery** — real captures of the running dock, Settings, and folder peek, to replace the illustration.
- **Homebrew cask** — once a GitHub Release exists.
- **Localization** — Settings and menu bar copy.
- **Empty-state polish** — the dock with no pinned apps yet.

## What will be declined

- Live window previews that require Screen Recording
- Media, calendar, or weather tiles
- Window snapping or a window switcher
- Electron, overlays that steal key focus, or anything that fights the system Dock instead of sitting beside it

If you believe one of those should exist, open an issue first. Do not send a surprise PR.

## Conduct

Be kind, be specific, and assume the other person is trying to make the Dock feel better. Harassment or personal attacks are not acceptable.

Questions that start with “I ran this on my display and…” are always welcome.
