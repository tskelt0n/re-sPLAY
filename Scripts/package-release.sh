#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

./build.sh
RELEASE_STAGE=$(mktemp -d /tmp/re-splay-release.XXXXXX)
trap 'rm -rf "$RELEASE_STAGE"' EXIT
ditto -x -k build/re-sPLAY-macOS27.zip "$RELEASE_STAGE"
RELEASE_APP="$RELEASE_STAGE/re-sPLAY.app"
RELEASE_VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$RELEASE_APP/Contents/Info.plist")
RELEASE_MIN_OS=$(/usr/libexec/PlistBuddy -c 'Print LSMinimumSystemVersion' "$RELEASE_APP/Contents/Info.plist")
RELEASE_ARCH=$(lipo -archs "$RELEASE_APP/Contents/MacOS/re-sPLAY")
[[ "$RELEASE_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
[[ "$RELEASE_MIN_OS" == "27.0" && "$RELEASE_ARCH" == "arm64" ]]
codesign --verify --deep --strict "$RELEASE_APP"
cp docs/INSTALL.md "$RELEASE_STAGE/INSTALL.md"

mkdir -p dist
RELEASE_FILE="re-sPLAY-v${RELEASE_VERSION}-macos27-arm64.zip"
ditto --norsrc --noextattr -c -k "$RELEASE_STAGE" "dist/$RELEASE_FILE"
unzip -t "dist/$RELEASE_FILE" >/dev/null
(cd dist && shasum -a 256 "$RELEASE_FILE" > SHA256SUMS.txt)
cp docs/INSTALL.md dist/INSTALL.md
echo "Release package: dist/$RELEASE_FILE"
echo "Checksum: dist/SHA256SUMS.txt"
