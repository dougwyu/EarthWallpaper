#!/bin/bash
set -e

echo "=== EarthWallpaper Installer ==="
cd "$(dirname "$0")"

# xplanet
if command -v xplanet &>/dev/null; then
    echo "✓ xplanet found at $(command -v xplanet)"
else
    echo "Installing xplanet..."
    brew install xplanet
fi

# xcodegen
if ! command -v xcodegen &>/dev/null; then
    echo "Installing xcodegen..."
    brew install xcodegen
fi

# Regenerate project (safe to re-run)
echo "Generating Xcode project..."
xcodegen generate

# Build
echo "Building (Release)..."
xcodebuild \
    -scheme EarthWallpaper \
    -configuration Release \
    -derivedDataPath build \
    -destination "platform=macOS" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    build 2>&1 | grep -E "error:|warning:.*error|BUILD SUCCEEDED|BUILD FAILED" || true

APP_PATH=$(find build -name "EarthWallpaper.app" -type d 2>/dev/null | head -1)
if [ -z "$APP_PATH" ]; then
    echo "ERROR: Build failed — EarthWallpaper.app not found in build/"
    exit 1
fi

# Install
echo "Installing to /Applications..."
rm -rf /Applications/EarthWallpaper.app
cp -r "$APP_PATH" /Applications/EarthWallpaper.app

echo ""
echo "✓ Installed: /Applications/EarthWallpaper.app"
echo ""
echo "Launching..."
open /Applications/EarthWallpaper.app

echo ""
echo "=== Done! ==="
echo ""
echo "A globe icon should now appear in your menu bar."
echo "To assign a key to 'Show Desktop':"
echo "  System Settings → Keyboard → Keyboard Shortcuts → Mission Control → Show Desktop"
