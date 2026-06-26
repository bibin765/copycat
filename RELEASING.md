# Releasing CopyCat

CopyCat ships as a **signed + notarized** `.dmg` attached to a GitHub Release, with
optional Sparkle auto-updates. Building from source needs nothing special; cutting
a public release needs an Apple Developer account.

## Build from source (no account needed)

```bash
./build_app.sh        # -> build/CopyCat.app (ad-hoc signed, runs locally)
open build/CopyCat.app
```

## Cut a notarized release

### One-time setup
1. **Apple Developer Program** ($99/yr) → create a **Developer ID Application**
   certificate (Xcode → Settings → Accounts → Manage Certificates → +).
2. Store notarization credentials once:
   ```bash
   xcrun notarytool store-credentials CopyCatNotary \
     --apple-id "you@example.com" --team-id "YOURTEAMID" \
     --password "app-specific-password"
   ```

### Release
```bash
export DEV_ID_APP="Developer ID Application: Your Name (YOURTEAMID)"
export AC_PROFILE=CopyCatNotary
export COPYCAT_VERSION="1.0"                  # bump every release
export COPYCAT_FEED_URL="https://github.com/upbrew/copycat/releases/latest/download/appcast.xml"
./release.sh
```
Produces **`dist/CopyCat.dmg`** — signed, notarized, stapled. Attach it to a
GitHub Release.

```bash
gh release create v1.0 dist/CopyCat.dmg --title "CopyCat 1.0" --notes "First release"
```

## Sparkle auto-updates (optional)

The EdDSA **public key is embedded** in the bundle (`build_app.sh`); the **private
key lives in your keychain** (created via Sparkle's `generate_keys`). Keep it safe.

For each release, generate/append the appcast and attach it too:
```bash
./.build/artifacts/sparkle/Sparkle/bin/generate_appcast dist/
gh release upload v1.0 dist/appcast.xml dist/CopyCat.dmg
```
Point `COPYCAT_FEED_URL` at wherever you host `appcast.xml` (a GitHub Release asset
or GitHub Pages both work).

## Regenerating art

```bash
icon/build_icon.sh                 # -> icon/AppIcon.icns
swift icon/make_banner.swift       # -> assets/banner.png, assets/social.png
```
