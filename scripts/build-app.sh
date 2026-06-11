#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/.build/release/AudioFallback.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"

cd "$ROOT"
swift build -c release

rm -rf "$APP"
mkdir -p "$MACOS"
cp "$ROOT/.build/release/AudioFallback" "$MACOS/AudioFallback"

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
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
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
