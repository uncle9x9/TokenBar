#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/TokenBar.app"

if [ ! -d "$APP_DIR" ]; then
    echo "==> App bundle not found, packaging first..."
    "$ROOT_DIR/Scripts/package_app.sh"
fi

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_DIR/Contents/Info.plist" 2>/dev/null || echo "0.32.4")
DMG_NAME="TokenBar-${VERSION}.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"
LATEST_DMG_PATH="$DIST_DIR/TokenBar.dmg"
VOL_NAME="TokenBar"

echo "==> Preparing DMG staging environment for TokenBar v${VERSION}..."
STAGING_DIR="$(mktemp -d -t tokenbar-dmg-XXXXXX)"
trap 'rm -rf "$STAGING_DIR"' EXIT

cp -R "$APP_DIR" "$STAGING_DIR/TokenBar.app"
ln -s /Applications "$STAGING_DIR/Applications"

# Set volume icon if available
if [ -f "$ROOT_DIR/Resources/AppIcon/TokenBar.icns" ]; then
    cp "$ROOT_DIR/Resources/AppIcon/TokenBar.icns" "$STAGING_DIR/.VolumeIcon.icns"
    if command -v SetFile >/dev/null 2>&1; then
        SetFile -a C "$STAGING_DIR" 2>/dev/null || true
        SetFile -a V "$STAGING_DIR/.VolumeIcon.icns" 2>/dev/null || true
    fi
fi

echo "==> Creating compressed disk image (UDZO)..."
rm -f "$DMG_PATH" "$LATEST_DMG_PATH"

hdiutil create \
    -volname "$VOL_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

ln -sf "$DMG_NAME" "$LATEST_DMG_PATH"

echo "==> DMG successfully created:"
echo "    - $DMG_PATH"
echo "    - $LATEST_DMG_PATH"
