#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/.build/release"
APP_DIR="$ROOT_DIR/Tracker.app"
BIN_DIR="$APP_DIR/Contents/MacOS"
RES_DIR="$APP_DIR/Contents/Resources"
PLIST_PATH="$APP_DIR/Contents/Info.plist"
ICON_PNG_PATH="$ROOT_DIR/Assets/AppIcon.png"
ICONSET_DIR="$ROOT_DIR/.build/AppIcon.iconset"
ICON_ICNS_PATH="$RES_DIR/AppIcon.icns"

cd "$ROOT_DIR"
swift build -c release

mkdir -p "$BIN_DIR" "$RES_DIR"
cp "$BUILD_DIR/Tracker" "$BIN_DIR/Tracker"
chmod +x "$BIN_DIR/Tracker"

if [[ -f "$ICON_PNG_PATH" ]]; then
  rm -rf "$ICONSET_DIR"
  mkdir -p "$ICONSET_DIR"
  sips -z 16 16 "$ICON_PNG_PATH" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
  sips -z 32 32 "$ICON_PNG_PATH" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 "$ICON_PNG_PATH" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
  sips -z 64 64 "$ICON_PNG_PATH" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "$ICON_PNG_PATH" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
  sips -z 256 256 "$ICON_PNG_PATH" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$ICON_PNG_PATH" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
  sips -z 512 512 "$ICON_PNG_PATH" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$ICON_PNG_PATH" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
  sips -z 1024 1024 "$ICON_PNG_PATH" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null
  iconutil -c icns "$ICONSET_DIR" -o "$ICON_ICNS_PATH"
fi

cat > "$PLIST_PATH" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>Tracker</string>
  <key>CFBundleIdentifier</key>
  <string>com.arne.tracker</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Arne Daily Tracker</string>
  <key>CFBundleDisplayName</key>
  <string>Arne Daily Tracker</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
</dict>
</plist>
EOF

echo "Built app bundle at: $APP_DIR"
echo "If Finder still shows an old icon: touch \"$APP_DIR\" && killall Finder"
