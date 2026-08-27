#!/usr/bin/env bash
set -e

echo "🔨 Building MacFileRelay (Mac 文件中转站) native binary..."
swiftc -O -target arm64-apple-macos13.0 \
  -framework Cocoa \
  -framework QuartzCore \
  -framework QuickLookUI \
  -framework QuickLookThumbnailing \
  Sources/*.swift \
  -o MacFileRelay

echo "📦 Packaging /Applications/MacFileRelay.app..."
mkdir -p /Applications/MacFileRelay.app/Contents/MacOS
mkdir -p /Applications/MacFileRelay.app/Contents/Resources
cp MacFileRelay /Applications/MacFileRelay.app/Contents/MacOS/
cp Resources/Info.plist /Applications/MacFileRelay.app/Contents/
chmod +x /Applications/MacFileRelay.app/Contents/MacOS/MacFileRelay

echo "✅ Build and install complete!"
echo "🚀 Launching MacFileRelay.app..."
killall -9 MacFileRelay 2>/dev/null || true
killall -9 ShakeDrop 2>/dev/null || true
killall -9 NotchDrop 2>/dev/null || true
rm -rf /Applications/ShakeDrop.app /Applications/NotchDrop.app 2>/dev/null || true
open /Applications/MacFileRelay.app
