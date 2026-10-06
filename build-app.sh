#!/bin/zsh
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
SOURCE_DIR="$PROJECT_ROOT/src/PaperwhiteReader"
APP_DIR="$PROJECT_ROOT/deliverables/legacy-prototype/Paperwhite Reader.app"

cd "$SOURCE_DIR"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
mkdir -p "$APP_DIR/Contents/MacOS"
cp "$BIN_DIR/PaperwhiteReader" "$APP_DIR/Contents/MacOS/PaperwhiteReader"
cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>PaperwhiteReader</string>
  <key>CFBundleIdentifier</key><string>com.scott.paperwhite-reader</string>
  <key>CFBundleName</key><string>Paperwhite Reader</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
codesign --force --deep --sign - "$APP_DIR"
echo "Built $APP_DIR"
