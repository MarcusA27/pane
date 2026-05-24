#!/usr/bin/env bash
# Build a universal (arm64 + x86_64) release of Pane, wrap it in a .app
# bundle, ad-hoc codesign it (required for the binary to run at all on
# Apple Silicon), and package it into a .dmg ready for GitHub Releases.

set -euo pipefail

cd "$(dirname "$0")"

VERSION="${VERSION:-0.1.0}"

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
mkdir -p "$MACOS" "$RESOURCES"

cp "$BIN" "$MACOS/Pane"

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

echo
echo "Done."
echo "  App: $APP_DIR"
echo "  DMG: $DMG_PATH"
ls -lh "$DMG_PATH"
