#!/bin/zsh
set -euo pipefail

APP_VERSION="0.3.0"
BUILD_VERSION="5"
DMG_NAME="AudioFallback-${APP_VERSION}.dmg"

case "${1:-}" in
    --print-version)
        echo "$APP_VERSION"
        exit 0
        ;;
    --print-build-version)
        echo "$BUILD_VERSION"
        exit 0
        ;;
    --print-dmg-name)
        echo "$DMG_NAME"
        exit 0
        ;;
    "")
        ;;
    *)
        echo "Unbekannte Option: $1" >&2
        exit 64
        ;;
esac

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/.build/release/AudioFallback.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
FRAMEWORKS="$CONTENTS/Frameworks"

cd "$ROOT"
swift build -c release
BUILD_DIR="$(swift build -c release --show-bin-path)"

rm -rf "$APP"
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"
mkdir -p "$FRAMEWORKS"
cp "$BUILD_DIR/AudioFallback" "$MACOS/AudioFallback"
find "$BUILD_DIR" -maxdepth 1 -name "*.bundle" -exec cp -R {} "$RESOURCES/" \;

SPARKLE_FRAMEWORK="$(find "$ROOT/.build/artifacts" \
    -type d \
    -path '*/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework' \
    -print -quit)"
if [[ -z "$SPARKLE_FRAMEWORK" ]]; then
    echo "Sparkle.framework wurde unter .build/artifacts nicht gefunden" >&2
    exit 1
fi
ditto "$SPARKLE_FRAMEWORK" "$FRAMEWORKS/Sparkle.framework"

cat > "$CONTENTS/Info.plist" <<PLIST
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
    <string>$APP_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>SUFeedURL</key>
    <string>https://github.com/bekla050/AudioFallback/releases/latest/download/appcast.xml</string>
    <key>SUPublicEDKey</key>
    <string>iAIs1MYTW9kxpXK+DXdhWBFr6geSS14RG0CwZR3DFgs=</string>
    <key>SUEnableAutomaticChecks</key>
    <true/>
    <key>SUScheduledCheckInterval</key>
    <integer>86400</integer>
</dict>
</plist>
PLIST

echo "$APP"
