# Release checklist (v1.x)

Use this before tagging and pushing a GitHub Release. Do not push until every box is checked.

## 1. Version
- [ ] Bump `MARKETING_VERSION` in `MacSideDock.xcodeproj` (semver, e.g. `1.0.1`)
- [ ] Bump `CURRENT_PROJECT_VERSION` (integer build number)
- [ ] Add a section to `CHANGELOG.md` with date and user-facing notes

## 2. Quality gate
```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
"$DEVELOPER_DIR/usr/bin/xcodebuild" \
  -project MacSideDock.xcodeproj -scheme MacSideDock \
  -configuration Release -destination 'generic/platform=macOS' \
  CODE_SIGNING_ALLOWED=NO build

"$DEVELOPER_DIR/usr/bin/xcodebuild" \
  -project MacSideDock.xcodeproj -scheme MacSideDock \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO \
  -only-testing:MacSideDockTests test
```
- [ ] Release build succeeds
- [ ] All `MacSideDockTests` pass
- [ ] Smoke on a real Mac: edge reveal, pin/unpin, folder drop, Settings via menu bar, Quit

## 3. Package
```bash
./scripts/make-dmg.sh
# Optional Developer ID:
# CODE_SIGN_IDENTITY="Developer ID Application: …" ./scripts/make-dmg.sh
```
- [ ] `dist/SIDEDOCK-<version>.dmg` opens; app installs to Applications
- [ ] App name shows as **SIDEDOCK**; version in About / Info matches changelog
- [ ] Config lives at `~/.config/sidedock/config.json`

## 4. Docs
- [ ] README install steps match the DMG name
- [ ] ROADMAP / FEATURES status still accurate
- [ ] No leftover “Mac Side Dock” user-facing strings in shipping UI

## 5. Ship
- [ ] Commit + tag `v1.0.0` (or new version)
- [ ] Push branch / tag when ready
- [ ] GitHub Release with DMG + changelog notes
- [ ] (Later) notarize, Homebrew cask, Sparkle

## Console noise in Xcode (ignore)

`com.apple.linkd.autoShortcut` Code 4097 and `AFIsDeviceGreymatterEligible` are system/App Intents plumbing. SIDEDOCK does not use App Intents; Apple’s tooling still probes `linkd`. Safe to ignore — not a SIDEDOCK bug.
