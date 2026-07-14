#!/bin/zsh
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Verwendung: scripts/build-dmg.sh APP_PATH DMG_PATH" >&2
    exit 64
fi

APP_PATH="$1"
DMG_PATH="$2"
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

if [[ ! -d "$APP_PATH" ]]; then
    echo "App-Bundle nicht gefunden: $APP_PATH" >&2
    exit 1
fi

mkdir -p "$(dirname "$DMG_PATH")"
ditto "$APP_PATH" "$STAGING/AudioFallback.app"
ln -s /Applications "$STAGING/Applications"
rm -f "$DMG_PATH"
hdiutil create -volname "AudioFallback" -srcfolder "$STAGING" -format UDZO -ov "$DMG_PATH"
