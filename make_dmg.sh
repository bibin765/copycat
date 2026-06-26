#!/bin/bash
# Builds dist/CopyCat.dmg — a drag-to-Applications installer window.
# Assumes build/CopyCat.app already exists and is signed.
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="CopyCat"
VOL="${APP_NAME}"
APP="build/${APP_NAME}.app"
DIST="dist"
DMG="${DIST}/${APP_NAME}.dmg"
BG="icon/dmg_background.png"

[ -d "${APP}" ] || { echo "✗ ${APP} not found — run ./build_app.sh first"; exit 1; }
mkdir -p "${DIST}"
rm -f "${DMG}"

# Regenerate the DMG window background if it's missing (it's git-ignored).
[ -f "${BG}" ] || swift icon/make_dmg_bg.swift "${BG}" >/dev/null 2>&1 || true

STAGE="$(mktemp -d)"
cp -R "${APP}" "${STAGE}/"
ln -s /Applications "${STAGE}/Applications"
if [ -f "${BG}" ]; then
    mkdir -p "${STAGE}/.background"
    cp "${BG}" "${STAGE}/.background/bg.png"
fi

RW="$(mktemp -u).dmg"
hdiutil create -srcfolder "${STAGE}" -volname "${VOL}" -fs HFS+ -format UDRW -ov "${RW}" >/dev/null

MOUNT="/Volumes/${VOL}"
hdiutil detach "${MOUNT}" >/dev/null 2>&1 || true
hdiutil attach "${RW}" -noautoopen -mountpoint "${MOUNT}" >/dev/null

# Arrange the window (best-effort — needs Finder automation; the DMG still works
# as a plain drag-install if this is skipped).
if [ -f "${BG}" ]; then
osascript >/dev/null 2>&1 <<OSA || echo "  (Finder layout skipped — DMG still functional)"
tell application "Finder"
  tell disk "${VOL}"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {300, 150, 900, 550}
    set opts to the icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 112
    set background picture of opts to file ".background:bg.png"
    set position of item "${APP_NAME}.app" of container window to {150, 200}
    set position of item "Applications" of container window to {450, 200}
    update without registering applications
    delay 1
    close
  end tell
end tell
OSA
fi

sync
hdiutil detach "${MOUNT}" >/dev/null 2>&1 || true
hdiutil convert "${RW}" -format UDZO -imagekey zlib-level=9 -o "${DMG}" >/dev/null
rm -f "${RW}"
rm -rf "${STAGE}"

echo "✓ Built ${DMG}"
