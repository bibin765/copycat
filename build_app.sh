#!/bin/bash
# Builds CopyCat.app — a menu-bar-only macOS app bundle.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="CopyCat"
BUNDLE_ID="com.upbrew.copycat"
VERSION="${COPYCAT_VERSION:-1.0}"
BUILD_DIR=".build/release"
APP_DIR="build/${APP_NAME}.app"
CONTENTS="${APP_DIR}/Contents"

# Sparkle auto-update settings (override via env when releasing).
SU_FEED_URL="${COPYCAT_FEED_URL:-https://upbrew.com/copycat/appcast.xml}"
SU_PUBLIC_KEY="${COPYCAT_ED_KEY:-y6+Dp954UiDEDQapWu8Q+T0aRj9btkpUTYKj+cch00o=}"

echo "▸ Compiling (release)…"
swift build -c release

echo "▸ Assembling ${APP_NAME}.app…"
rm -rf "${APP_DIR}"
mkdir -p "${CONTENTS}/MacOS" "${CONTENTS}/Resources" "${CONTENTS}/Frameworks"

cp "${BUILD_DIR}/${APP_NAME}" "${CONTENTS}/MacOS/${APP_NAME}"

# Embed Sparkle.framework for auto-updates.
SPARKLE_FW="$(find .build -maxdepth 3 -name Sparkle.framework -type d | head -1)"
if [ -n "${SPARKLE_FW}" ]; then
    cp -R "${SPARKLE_FW}" "${CONTENTS}/Frameworks/Sparkle.framework"
else
    echo "⚠︎  Sparkle.framework not found in .build — run 'swift build -c release' first."
fi

# App icon — generate it on first build if missing.
if [ ! -f "icon/AppIcon.icns" ]; then
    echo "▸ Generating app icon…"
    ( cd icon && ./build_icon.sh >/dev/null 2>&1 ) || true
fi
if [ -f "icon/AppIcon.icns" ]; then
    cp "icon/AppIcon.icns" "${CONTENTS}/Resources/AppIcon.icns"
    ICON_PLIST_ENTRY="<key>CFBundleIconFile</key><string>AppIcon</string>"
else
    echo "⚠︎  icon/AppIcon.icns not found — run icon/build_icon.sh to add an icon."
    ICON_PLIST_ENTRY=""
fi

cat > "${CONTENTS}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>SUFeedURL</key>
    <string>${SU_FEED_URL}</string>
    <key>SUPublicEDKey</key>
    <string>${SU_PUBLIC_KEY}</string>
    <key>SUEnableAutomaticChecks</key>
    <true/>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    ${ICON_PLIST_ENTRY}
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>CopyCat</string>
</dict>
</plist>
PLIST

# Ad-hoc sign (inside-out, incl. Sparkle) so it runs locally without a certificate.
echo "▸ Code signing (ad-hoc)…"
chmod +x sign_app.sh
./sign_app.sh - "${APP_DIR}" >/dev/null 2>&1 || true

echo "✓ Built ${APP_DIR}"
echo "  Run it:   open \"${APP_DIR}\""
echo "  Install:  cp -R \"${APP_DIR}\" /Applications/"
