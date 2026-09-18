#!/bin/zsh
# Build a drag-to-Applications installer DMG for SIDEDOCK.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export DEVELOPER_DIR
XCODEBUILD="$DEVELOPER_DIR/usr/bin/xcodebuild"

BUILD_DIR="$ROOT/build"
DIST_DIR="$ROOT/dist"
APP_NAME="SIDEDOCK"
SCHEME="MacSideDock"
VOLUME="$APP_NAME"

rm -rf "$BUILD_DIR"
mkdir -p "$DIST_DIR"

IDENTITY="${CODE_SIGN_IDENTITY:--}"

echo "==> Archiving Release"
"$XCODEBUILD" archive \
  -project "$ROOT/MacSideDock.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath "$BUILD_DIR/SIDEDOCK.xcarchive" \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  CODE_SIGN_IDENTITY="$IDENTITY" \
  CODE_SIGNING_ALLOWED=YES \
  ENABLE_APP_SANDBOX=NO

APP="$BUILD_DIR/SIDEDOCK.xcarchive/Products/Applications/${APP_NAME}.app"
if [[ ! -d "$APP" ]]; then
  echo "Archived app not found at $APP" >&2
  exit 1
fi

codesign --verify --verbose=2 "$APP" || true

VERSION="$( /usr/bin/defaults read "$APP/Contents/Info.plist" CFBundleShortVersionString )"
STAGE="$BUILD_DIR/dmg"
RW_DMG="$BUILD_DIR/${APP_NAME}-rw.dmg"
FINAL_DMG="$DIST_DIR/${APP_NAME}-${VERSION}.dmg"
LINK_DMG="$DIST_DIR/${APP_NAME}.dmg"
MOUNT="/Volumes/${VOLUME}"

rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/${APP_NAME}.app"
ln -s /Applications "$STAGE/Applications"
mkdir -p "$STAGE/.background"
python3 "$ROOT/scripts/dmg/make-background.py" "$STAGE/.background/background.png"
xattr -cr "$STAGE/${APP_NAME}.app" || true

if [[ -d "$MOUNT" ]]; then
  hdiutil detach "$MOUNT" -quiet || hdiutil detach "$MOUNT" -force || true
fi

rm -f "$RW_DMG" "$FINAL_DMG"
echo "==> Creating disk image"
hdiutil create \
  -volname "$VOLUME" \
  -srcfolder "$STAGE" \
  -ov \
  -fs HFS+ \
  -format UDRW \
  "$RW_DMG"

DEVICE="$(hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG" | awk '/Apple_HFS/ { print $1 }')"
if [[ -z "${DEVICE}" ]]; then
  echo "Failed to mount $RW_DMG" >&2
  exit 1
fi

# Hide the backdrop folder so only the two icons show.
if [[ -d "$MOUNT/.background" ]]; then
  SetFile -a V "$MOUNT/.background" 2>/dev/null || chflags hidden "$MOUNT/.background"
fi

echo "==> Laying out Finder window"
osascript <<EOF || echo "Finder layout skipped (window will still install)."
tell application "Finder"
  tell disk "$VOLUME"
    open
    delay 1
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {200, 120, 860, 520}
    set opts to icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 128
    try
      set background picture of opts to file ".background:background.png"
    end try
    set position of item "$APP_NAME.app" of container window to {160, 190}
    set position of item "Applications" of container window to {500, 190}
    close
    open
    update without registering applications
    delay 2
  end tell
end tell
EOF

sync
hdiutil detach "$DEVICE" -quiet || hdiutil detach "$MOUNT" -force

echo "==> Compressing"
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$FINAL_DMG"
rm -f "$RW_DMG"
ln -sf "$(basename "$FINAL_DMG")" "$LINK_DMG"

echo "Created $FINAL_DMG"
echo "Open it, drag ${APP_NAME} onto Applications, then launch it once."
