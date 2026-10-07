#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
APP_DIR="$ROOT_DIR/dist/Mini-Terminal.app"
mkdir -p "$ROOT_DIR/dist"
STAGE_ROOT="$(mktemp -d "$ROOT_DIR/dist/.build-XXXXXX")"
STAGED_APP="$STAGE_ROOT/Mini-Terminal.app"
CONTENTS_DIR="$STAGED_APP/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

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
    <string>0.4.0</string>
    <key>CFBundleVersion</key>
    <string>4</string>
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

# Verify the staged bundle before replacing the runnable app. Keep the previous
# local bundle for rollback; this script never terminates a running process.
SOURCE_REVISION="$(git rev-parse HEAD)"
SOURCE_DIRTY=false
if ! git diff --quiet HEAD -- Sources Package.swift scripts/build-app.sh ||
   [ -n "$(git ls-files --others --exclude-standard -- Sources Package.swift scripts/build-app.sh)" ]; then
    SOURCE_DIRTY=true
fi
/usr/libexec/PlistBuddy -c "Add :MiniTerminalSourceRevision string $SOURCE_REVISION" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Add :MiniTerminalSourceDirty bool $SOURCE_DIRTY" "$CONTENTS_DIR/Info.plist"
plutil -lint "$CONTENTS_DIR/Info.plist"
codesign --force --deep --sign - "$STAGED_APP"
codesign --verify --deep --strict "$STAGED_APP"
if [ -e "$APP_DIR" ]; then
    BACKUP_ROOT="$(mktemp -d "$ROOT_DIR/dist/.previous-XXXXXX")"
    mv "$APP_DIR" "$BACKUP_ROOT/Mini-Terminal.app"
fi
mv "$STAGED_APP" "$APP_DIR"
rmdir "$STAGE_ROOT"
echo "$APP_DIR"
