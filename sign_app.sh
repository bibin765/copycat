#!/bin/bash
# Signs CopyCat.app inside-out, including the embedded Sparkle.framework helpers.
#
# Usage: ./sign_app.sh <identity> <app-path> [entitlements]
#   <identity> = "-" for ad-hoc (local dev), or a "Developer ID Application: …" name.
set -euo pipefail

IDENTITY="$1"
APP="$2"
ENTITLEMENTS="${3:-}"

FLAGS=(--force --sign "$IDENTITY")
# Real certificates get Hardened Runtime + a secure timestamp (required to notarize).
if [ "$IDENTITY" != "-" ]; then
    FLAGS+=(--options runtime --timestamp)
fi

FW="${APP}/Contents/Frameworks/Sparkle.framework"
if [ -d "$FW" ]; then
    V="${FW}/Versions/B"
    # Inside-out: helpers first, then the framework.
    codesign "${FLAGS[@]}" "${V}/XPCServices/Downloader.xpc"
    codesign "${FLAGS[@]}" "${V}/XPCServices/Installer.xpc"
    codesign "${FLAGS[@]}" "${V}/Updater.app"
    codesign "${FLAGS[@]}" "${V}/Autoupdate"
    codesign "${FLAGS[@]}" "$FW"
fi

# Main app last (entitlements only apply with a real identity).
if [ -n "$ENTITLEMENTS" ] && [ "$IDENTITY" != "-" ]; then
    codesign "${FLAGS[@]}" --entitlements "$ENTITLEMENTS" "$APP"
else
    codesign "${FLAGS[@]}" "$APP"
fi
