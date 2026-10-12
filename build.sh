#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
DEST="$PWD/build/re-sPLAY.app"
STAGE=$(mktemp -d /tmp/displayswitch-build.XXXXXX)
trap 'rm -rf "$STAGE"' EXIT
APP="$STAGE/re-sPLAY.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
xcrun swift Scripts/GenerateIcon.swift "$STAGE/AppIcon.iconset"
iconutil -c icns "$STAGE/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
cp LICENSE THIRD_PARTY_NOTICES.md "$APP/Contents/Resources/"
xcrun swiftc -swift-version 5 -O -target arm64-apple-macos27.0 Sources/*.swift -o "$APP/Contents/MacOS/re-sPLAY" -framework SwiftUI -framework AppKit -framework CoreGraphics -framework Carbon -framework ServiceManagement -framework IOKit
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>re-sPLAY</string>
<key>CFBundleIdentifier</key><string>local.DisplaySwitch</string>
<key>CFBundleName</key><string>re-sPLAY</string>
<key>CFBundleDisplayName</key><string>re-sPLAY</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.7.2</string>
<key>LSMinimumSystemVersion</key><string>27.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
xattr -cr "$APP"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
mkdir -p "$PWD/build"
ditto --norsrc --noextattr -c -k --keepParent "$APP" "$PWD/build/re-sPLAY-macOS27.zip"
ditto "$APP" "$DEST"
echo "Built $DEST"
echo "Archived $PWD/build/re-sPLAY-macOS27.zip"
