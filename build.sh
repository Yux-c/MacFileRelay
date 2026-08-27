#!/usr/bin/env bash
set -e

echo "🔨 Building ShakeDrop native binary..."
swiftc -O -target arm64-apple-macos13.0 \
  -framework Cocoa \
  -framework QuartzCore \
  -framework QuickLookUI \
  -framework QuickLookThumbnailing \
  Sources/*.swift \
  -o ShakeDrop

echo "📦 Packaging /Applications/ShakeDrop.app..."
mkdir -p /Applications/ShakeDrop.app/Contents/MacOS
mkdir -p /Applications/ShakeDrop.app/Contents/Resources
cp ShakeDrop /Applications/ShakeDrop.app/Contents/MacOS/
cp Resources/Info.plist /Applications/ShakeDrop.app/Contents/
chmod +x /Applications/ShakeDrop.app/Contents/MacOS/ShakeDrop

echo "✅ ShakeDrop build and install complete!"
echo "🚀 Launching ShakeDrop.app..."
killall -9 ShakeDrop 2>/dev/null || true
killall -9 NotchDrop 2>/dev/null || true
rm -rf /Applications/NotchDrop.app 2>/dev/null || true
open /Applications/ShakeDrop.app
