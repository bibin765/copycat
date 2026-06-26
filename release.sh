#!/bin/bash
# Builds, Developer-ID-signs (Hardened Runtime, incl. Sparkle), notarizes, and
# staples CopyCat — producing a notarized DMG for direct distribution.
#
# Required environment:
#   DEV_ID_APP  — e.g. "Developer ID Application: Your Name (TEAMID)"
#   AC_PROFILE  — your stored notarytool keychain profile (e.g. CopyCatNotary)
# Optional:
#   COPYCAT_VERSION   — version string baked into the bundle (default 1.0)
#   COPYCAT_FEED_URL  — Sparkle appcast URL
#
# Usage:  DEV_ID_APP="..." AC_PROFILE=CopyCatNotary ./release.sh
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="CopyCat"
APP="build/${APP_NAME}.app"
DIST="dist"
ZIP="${DIST}/${APP_NAME}.zip"
DMG="${DIST}/${APP_NAME}.dmg"

: "${DEV_ID_APP:?Set DEV_ID_APP to your 'Developer ID Application' identity}"
: "${AC_PROFILE:?Set AC_PROFILE to your stored notarytool keychain profile}"

echo "▸ Building app bundle (with Sparkle)…"
./build_app.sh >/dev/null

echo "▸ Signing inside-out with Developer ID + Hardened Runtime…"
./sign_app.sh "${DEV_ID_APP}" "${APP}" entitlements.plist
codesign --verify --strict --verbose=2 "${APP}"

echo "▸ Notarizing the app…"
mkdir -p "${DIST}"; rm -f "${ZIP}"
/usr/bin/ditto -c -k --keepParent "${APP}" "${ZIP}"
xcrun notarytool submit "${ZIP}" --keychain-profile "${AC_PROFILE}" --wait
xcrun stapler staple "${APP}"
rm -f "${ZIP}"

echo "▸ Building the DMG…"
./make_dmg.sh

echo "▸ Signing the DMG…"
codesign --force --sign "${DEV_ID_APP}" --timestamp "${DMG}"

echo "▸ Notarizing the DMG…"
xcrun notarytool submit "${DMG}" --keychain-profile "${AC_PROFILE}" --wait
xcrun stapler staple "${DMG}"

echo "▸ Gatekeeper assessment:"
spctl -a -vvv --type install "${DMG}" 2>&1 || true

echo "✓ Done — distributable: ${DMG}"
