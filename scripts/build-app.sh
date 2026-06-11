#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/.build/release/AudioFallback.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

cd "$ROOT"
swift build -c release
BUILD_DIR="$(swift build -c release --show-bin-path)"

rm -rf "$APP"
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"
cp "$BUILD_DIR/AudioFallback" "$MACOS/AudioFallback"
find "$BUILD_DIR" -maxdepth 1 -name "*.bundle" -exec cp -R {} "$RESOURCES/" \;

cat > "$CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>AudioFallback</string>
    <key>CFBundleIdentifier</key>
    <string>app.audiofallback</string>
    <key>CFBundleName</key>
    <string>AudioFallback</string>
    <key>CFBundleDisplayName</key>
    <string>AudioFallback</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>en</string>
        <string>de</string>
        <string>fr</string>
        <string>es</string>
        <string>it</string>
        <string>pt-BR</string>
        <string>zh-Hans</string>
        <string>ja</string>
        <string>ko</string>
        <string>nl</string>
    </array>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.1</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "$APP"
