# Roadmap

SIDEDOCK is a secondary Dock for the unused left or right edge of a Mac. This file is the contract with contributors: what v1 is, what it is not, and what we will take PRs for.

If your idea is in **Out of scope**, open a Discussion first. Do not send a surprise PR.

## v1 — shipped

The core Dock mechanic. This is the product.

- [x] Vertical glass panel on the left or right, one per display
- [x] Pin apps so they stay visible when not running
- [x] Click to launch, focus, or hide
- [x] Hover magnification
- [x] Auto-hide, revealed by moving the pointer to the screen edge
- [x] Drag apps in from Finder; drag to reorder
- [x] Recently used apps
- [x] Pinned folders with hover peek
- [x] Plaintext JSON config at `~/.config/sidedock/config.json`
- [x] Open at Login on first install
- [x] Menu bar extra for Settings and Quit
- [x] DMG: drag to Applications
- [x] App icon (asset catalog + menu bar template)
- [x] Icon name on hover (name tags beside icons)

No Accessibility. No Screen Recording. No live window previews.

## Partial

- [ ] Reserve screen space — always-visible mode works. macOS has no public API to shrink other apps’ `visibleFrame`.

## Next (good PRs)

These keep it a Dock. Pick one; keep the diff small.

- [ ] Photographs of the running app for the README
- [ ] Localization of Settings and the menu bar
- [ ] Homebrew cask, once a GitHub Release exists
- [ ] Developer ID signing + notarization for the DMG

## Out of scope

These were considered and left out on purpose. They need extra permissions, or they turn the Dock into a sidebar of utilities.

- Live window previews (Screen Recording)
- Media controls
- Calendar
- Window snapping
- Window switcher
- Widgets, Now Playing, weather

## Later, not now

- App Store (sandbox + Apple Developer Program)
- Sparkle or similar auto-update

See [FEATURES.md](FEATURES.md) for the idea-to-code map.
