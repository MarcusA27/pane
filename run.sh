#!/usr/bin/env bash
# Build LiquidGlassNotes and launch it from a real .app bundle so macOS treats
# it as a proper GUI app (keyboard focus, dock icon, event routing).

set -euo pipefail

cd "$(dirname "$0")"

CONFIG="${CONFIG:-debug}"
swift build -c "$CONFIG"

BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)"
APP_DIR="$BIN_PATH/Pane.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

rm -rf "$APP_DIR" "$BIN_PATH/LiquidGlassNotes.app"
mkdir -p "$MACOS" "$RESOURCES"

cp "$BIN_PATH/LiquidGlassNotes" "$MACOS/Pane"

ICNS_SRC="Assets/Icon/Pane.icns"
if [ -f "$ICNS_SRC" ]; then
    cp "$ICNS_SRC" "$RESOURCES/Pane.icns"
fi

cat > "$CONTENTS/Info.plist" <<'PLIST'
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
    <string>0.1</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

open "$APP_DIR"
echo "Launched: $APP_DIR"
