#!/usr/bin/env bash
# Build a universal (arm64 + x86_64) release of Pane, wrap it in a .app
# bundle, ad-hoc codesign it (required for the binary to run at all on
# Apple Silicon), and package it into a .dmg ready for GitHub Releases.

set -euo pipefail

cd "$(dirname "$0")"

VERSION="${VERSION:-0.1.0}"

# Fetch Sparkle CLI tools (sign_update, generate_appcast, etc.) on first run.
# The signing key itself lives in the user's Keychain, not on disk.
SPARKLE_DIR="$PWD/.sparkle-tools"
if [ ! -x "$SPARKLE_DIR/bin/sign_update" ]; then
    echo "==> Fetching Sparkle CLI tools (one-time)"
    mkdir -p "$SPARKLE_DIR"
    SPARKLE_URL=$(curl -sL https://api.github.com/repos/sparkle-project/Sparkle/releases/latest \
        | grep '"browser_download_url".*tar\.xz' | head -1 | cut -d'"' -f4)
    if [ -z "$SPARKLE_URL" ]; then
        echo "ERROR: couldn't find Sparkle release tarball URL" >&2
        exit 1
    fi
    curl -sL "$SPARKLE_URL" | tar -xJ -C "$SPARKLE_DIR"
fi

echo "==> Building universal release ($VERSION)"
swift build -c release --arch arm64 --arch x86_64

BIN_PATH="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"
BIN="$BIN_PATH/LiquidGlassNotes"

if [ ! -f "$BIN" ]; then
    echo "ERROR: built binary not found at $BIN" >&2
    exit 1
fi

DIST_DIR="dist"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

APP_DIR="$DIST_DIR/Pane.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
FRAMEWORKS="$CONTENTS/Frameworks"
mkdir -p "$MACOS" "$RESOURCES" "$FRAMEWORKS"

cp "$BIN" "$MACOS/Pane"

if [ -d "$BIN_PATH/Sparkle.framework" ]; then
    cp -R "$BIN_PATH/Sparkle.framework" "$FRAMEWORKS/Sparkle.framework"
    install_name_tool -add_rpath @executable_path/../Frameworks "$MACOS/Pane" 2>/dev/null || true
fi

ICNS_SRC="Assets/Icon/Pane.icns"
if [ -f "$ICNS_SRC" ]; then
    cp "$ICNS_SRC" "$RESOURCES/Pane.icns"
fi

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Pane</string>
    <key>CFBundleIconFile</key>
    <string>Pane</string>
    <key>CFBundleIdentifier</key>
    <string>com.marcus.LiquidGlassNotes</string>
    <key>CFBundleName</key>
    <string>Pane</string>
    <key>CFBundleDisplayName</key>
    <string>Pane</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>SUFeedURL</key>
    <string>https://marcusa27.github.io/pane/appcast.xml</string>
    <key>SUPublicEDKey</key>
    <string>HipTMpz8varSLhIdTIb8Siedvp27m1xb1j95bUcqZ9M=</string>
    <key>SUEnableAutomaticChecks</key>
    <true/>
</dict>
</plist>
PLIST

echo "==> Ad-hoc signing"
codesign --force --deep --sign - "$APP_DIR"

echo "==> Verifying arches"
lipo -info "$MACOS/Pane"

echo "==> Building DMG"
STAGE="$DIST_DIR/dmg-stage"
rm -rf "$STAGE"
mkdir "$STAGE"
cp -R "$APP_DIR" "$STAGE/Pane.app"
ln -s /Applications "$STAGE/Applications"

DMG_PATH="$DIST_DIR/Pane-$VERSION.dmg"
hdiutil create -volname "Pane" -srcfolder "$STAGE" -ov -format UDZO -quiet "$DMG_PATH"
rm -rf "$STAGE"

echo "==> Signing update with EdDSA"
SIG_OUT="$("$SPARKLE_DIR/bin/sign_update" "$DMG_PATH")"
echo "$SIG_OUT"
EDSIG=$(echo "$SIG_OUT" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')
LEN=$(echo "$SIG_OUT" | sed -n 's/.*length="\([^"]*\)".*/\1/p')
if [ -z "$EDSIG" ] || [ -z "$LEN" ]; then
    echo "ERROR: sign_update did not produce signature/length" >&2
    exit 1
fi

echo "==> Regenerating docs/appcast.xml"
mkdir -p docs
DATE_RFC=$(date -u +"%a, %d %b %Y %H:%M:%S +0000")
cat > docs/appcast.xml <<APPCAST
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
        <title>Pane</title>
        <link>https://marcusa27.github.io/pane/appcast.xml</link>
        <description>Updates for Pane.</description>
        <language>en</language>
        <item>
            <title>Version $VERSION</title>
            <pubDate>$DATE_RFC</pubDate>
            <sparkle:version>$VERSION</sparkle:version>
            <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
            <enclosure url="https://github.com/MarcusA27/pane/releases/download/v$VERSION/Pane-$VERSION.dmg"
                       sparkle:edSignature="$EDSIG"
                       length="$LEN"
                       type="application/octet-stream" />
        </item>
    </channel>
</rss>
APPCAST

echo
echo "Done."
echo "  App:     $APP_DIR"
echo "  DMG:     $DMG_PATH"
echo "  appcast: docs/appcast.xml"
echo
echo "Next: commit docs/appcast.xml, tag v$VERSION, push, and create the GitHub Release."
ls -lh "$DMG_PATH"
