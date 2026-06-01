#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_EXEC="USBStatus"
APP_DISPLAY="USB Status"
BUNDLE_ID="dev.yasusu.usbstatus"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_DISPLAY.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_EXEC"
INFO_PLIST="$APP_CONTENTS/Info.plist"
INSTALL_BUNDLE="/Applications/$APP_DISPLAY.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
ICON_SOURCE="$ROOT_DIR/Sources/USBStatus/Resources/Icons/cable.svg"
MENU_BAR_ICON_SOURCE="$ROOT_DIR/Sources/USBStatus/Resources/Icons/typec_icon.png"

stop_running() {
  pkill -x "$APP_EXEC" >/dev/null 2>&1 || true
}

build_bundle() {
  stop_running
  swift build -c release
  local build_binary
  build_binary="$(swift build -c release --show-bin-path)/$APP_EXEC"

  rm -rf "$APP_BUNDLE"
  mkdir -p "$APP_MACOS" "$APP_RESOURCES"
  cp "$build_binary" "$APP_BINARY"
  chmod +x "$APP_BINARY"

  local iconset="$DIST_DIR/AppIcon.iconset"
  rm -rf "$iconset"
  swift "$ROOT_DIR/Tools/IconGenerator.swift" "$ICON_SOURCE" "$iconset"
  /usr/bin/iconutil -c icns "$iconset" -o "$APP_RESOURCES/AppIcon.icns"
  mkdir -p "$APP_RESOURCES/Icons"
  cp "$ICON_SOURCE" "$APP_RESOURCES/Icons/cable.svg"
  cp "$MENU_BAR_ICON_SOURCE" "$APP_RESOURCES/Icons/typec_icon.png"

  cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_DISPLAY</string>
  <key>CFBundleExecutable</key>
  <string>$APP_EXEC</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_DISPLAY</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

  /usr/bin/xattr -cr "$APP_BUNDLE"
  /usr/bin/codesign --force --sign - "$APP_BUNDLE" >/dev/null
}

open_bundle() {
  /usr/bin/open -n "$APP_BUNDLE"
}

install_bundle() {
  build_bundle
  stop_running
  rm -rf "$INSTALL_BUNDLE"
  cp -R "$APP_BUNDLE" "$INSTALL_BUNDLE"
  /usr/bin/xattr -cr "$INSTALL_BUNDLE"
  "$LSREGISTER" -f "$INSTALL_BUNDLE"
}

open_installed_bundle() {
  /usr/bin/open -n "$INSTALL_BUNDLE"
}

verify_process() {
  sleep 2
  pgrep -x "$APP_EXEC" >/dev/null
}

case "$MODE" in
  run)
    build_bundle
    open_bundle
    ;;
  --verify|verify)
    build_bundle
    open_bundle
    verify_process
    ;;
  --install|install)
    install_bundle
    ;;
  --install-run|install-run)
    install_bundle
    open_installed_bundle
    ;;
  --install-verify|install-verify)
    install_bundle
    open_installed_bundle
    verify_process
    ;;
  --debug|debug)
    build_bundle
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    build_bundle
    open_bundle
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_EXEC\""
    ;;
  --telemetry|telemetry)
    build_bundle
    open_bundle
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  *)
    echo "usage: $0 [run|--verify|--install|--install-run|--install-verify|--debug|--logs|--telemetry]" >&2
    exit 2
    ;;
esac
