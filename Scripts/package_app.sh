#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/TokenBar.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "==> Building TokenBar release binary..."
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
    TMPDIR="$ROOT_DIR/.build/tmp" \
    CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/ModuleCache" \
    swift build -c release --cache-path "$ROOT_DIR/.build/cache"

RELEASE_BIN="$ROOT_DIR/.build/release/TokenBar"
if [ ! -f "$RELEASE_BIN" ]; then
    RELEASE_BIN="$ROOT_DIR/.build/arm64-apple-macosx/release/TokenBar"
fi

echo "==> Packaging TokenBar.app..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$RELEASE_BIN" "$MACOS_DIR/TokenBar"
chmod +x "$MACOS_DIR/TokenBar"

# Finder, Dock, and application switcher icon.
cp "$ROOT_DIR/Resources/AppIcon/TokenBar.icns" "$RESOURCES_DIR/TokenBar.icns"

# Copy SVG icons
cp "$ROOT_DIR/Sources/TokenBarCore/Resources/ProviderIcons/"*.svg "$RESOURCES_DIR/"

# Copy SPM resource bundle if present
if [ -d "$ROOT_DIR/.build/arm64-apple-macosx/release/TokenBar_TokenBarCore.bundle" ]; then
    cp -R "$ROOT_DIR/.build/arm64-apple-macosx/release/TokenBar_TokenBarCore.bundle" "$RESOURCES_DIR/"
fi

cat > "$CONTENTS_DIR/Info.plist" << 'PLIST_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>TokenBar</string>
    <key>CFBundleIdentifier</key>
    <string>com.uncle9x9.TokenBar</string>
    <key>CFBundleName</key>
    <string>TokenBar</string>
    <key>CFBundleDisplayName</key>
    <string>TokenBar</string>
    <key>CFBundleIconFile</key>
    <string>TokenBar</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.32.4</string>
    <key>CFBundleVersion</key>
    <string>324</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 TokenBar Authors. MIT License.</string>
</dict>
</plist>
PLIST_EOF

echo "==> Signing TokenBar.app (ad-hoc)..."
codesign -s - --force --deep "$APP_DIR"

echo "==> TokenBar.app successfully packaged at: $APP_DIR"
