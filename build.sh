#!/usr/bin/env bash
set -e

echo "🔨 Building NotchDrop native binary..."
swiftc -O -target arm64-apple-macos13.0 \
  -framework Cocoa \
  -framework QuartzCore \
  -framework QuickLookUI \
  -framework QuickLookThumbnailing \
  Sources/*.swift \
  -o NotchDrop

echo "📦 Packaging /Applications/NotchDrop.app..."
mkdir -p /Applications/NotchDrop.app/Contents/MacOS
mkdir -p /Applications/NotchDrop.app/Contents/Resources
cp NotchDrop /Applications/NotchDrop.app/Contents/MacOS/
cp Resources/Info.plist /Applications/NotchDrop.app/Contents/
chmod +x /Applications/NotchDrop.app/Contents/MacOS/NotchDrop

echo "✅ NotchDrop build and install complete!"
echo "🚀 Launching NotchDrop.app..."
killall -9 NotchDrop 2>/dev/null || true
open /Applications/NotchDrop.app
