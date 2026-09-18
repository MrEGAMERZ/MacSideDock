# Changelog

All notable changes to SIDEDOCK are documented here.

## 1.0.0 — 2026-09-18

First public release.

### Product
- Vertical glass side dock on the left or right edge, one panel per display
- Pin 1–10 apps; drag from Finder to add; drag to reorder; right-click to remove
- Hover magnification with neighbor push; name tags aligned outside the glass
- Auto-hide on edge approach (no Accessibility / Screen Recording)
- Recents, pinned folders with peek, running indicators
- Menu bar extra: Settings, Open at Login, Recents, Reveal Config, Quit
- Settings window (menu-bar only — no Cmd+,)
- JSON config at `~/.config/sidedock/config.json` (reads legacy `mac-side-dock` path)

### Brand
- App name **SIDEDOCK**, app icon, menu bar template icon
- Settings About / Dock preview images from live screenshots

### Packaging
- DMG script: `./scripts/make-dmg.sh` → `dist/SIDEDOCK-1.0.0.dmg`
- Release builds are unsandboxed so Finder drops and config paths work

### Fixes
- Folder drops no longer crash Debug builds (sandbox bookmark misuse)
- Removing apps no longer resurrects earlier removals (config watcher race)
- Dock glass width stays fixed while icons magnify
