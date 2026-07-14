#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TAG="${1:-}"

if [[ ! "$TAG" =~ '^v[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
    echo "Release-Tag muss dem Format vX.Y.Z entsprechen: $TAG" >&2
    exit 1
fi

VERSION="$($ROOT/scripts/build-app.sh --print-version)"
BUILD_VERSION="$($ROOT/scripts/build-app.sh --print-build-version)"
DMG_NAME="$($ROOT/scripts/build-app.sh --print-dmg-name)"
EXPECTED_URL="https://github.com/bekla050/AudioFallback/releases/download/$TAG/$DMG_NAME"

if [[ "${TAG#v}" != "$VERSION" ]]; then
    echo "Tag $TAG passt nicht zur App-Version $VERSION" >&2
    exit 1
fi
if [[ ! "$BUILD_VERSION" =~ '^[1-9][0-9]*$' ]]; then
    echo "CFBundleVersion muss eine positive Ganzzahl sein: $BUILD_VERSION" >&2
    exit 1
fi
if ! grep -Fq "[$DMG_NAME]($EXPECTED_URL)" "$ROOT/README.md"; then
    echo "README-Download-Link passt nicht zu $TAG und $DMG_NAME" >&2
    exit 1
fi

echo "Release-Konfiguration gültig: $TAG (Build $BUILD_VERSION)"
