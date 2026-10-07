#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
APP_DIR="$ROOT_DIR/dist/Mini-Terminal.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
cp "$BIN_DIR/Mini-Terminal" "$MACOS_DIR/Mini-Terminal"
chmod +x "$MACOS_DIR/Mini-Terminal"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Mini-Terminal</string>
    <key>CFBundleIdentifier</key>
    <string>com.nao.mini-terminal</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Mini-Terminal</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.3.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>en</string>
        <string>ja</string>
        <string>zh-Hans</string>
        <string>zh-Hant</string>
        <string>ko</string>
        <string>es</string>
        <string>fr</string>
        <string>de</string>
        <string>pt</string>
    </array>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP_DIR"
echo "$APP_DIR"
