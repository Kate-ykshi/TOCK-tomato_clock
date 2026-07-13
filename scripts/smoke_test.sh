#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/TOCK.app"
EXECUTABLE_PATH="$APP_DIR/Contents/MacOS/TOCK"
INFO_PLIST="$APP_DIR/Contents/Info.plist"
RESOURCES_DIR="$APP_DIR/Contents/Resources"

"$ROOT_DIR/scripts/check_timer_engine.sh"
"$ROOT_DIR/scripts/package_app.sh"

if [[ ! -d "$APP_DIR" ]]; then
  echo "Missing app bundle: $APP_DIR" >&2
  exit 1
fi

if [[ ! -x "$EXECUTABLE_PATH" ]]; then
  echo "Missing executable: $EXECUTABLE_PATH" >&2
  exit 1
fi

if [[ ! -f "$INFO_PLIST" ]]; then
  echo "Missing Info.plist: $INFO_PLIST" >&2
  exit 1
fi

BUNDLE_EXECUTABLE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$INFO_PLIST")"
BUNDLE_IDENTIFIER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO_PLIST")"
BUNDLE_ICON="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$INFO_PLIST")"

if [[ "$BUNDLE_EXECUTABLE" != "TOCK" ]]; then
  echo "Unexpected CFBundleExecutable: $BUNDLE_EXECUTABLE" >&2
  exit 1
fi

if [[ -z "$BUNDLE_IDENTIFIER" ]]; then
  echo "Missing CFBundleIdentifier" >&2
  exit 1
fi

if [[ -z "$BUNDLE_ICON" ]]; then
  echo "Missing CFBundleIconFile" >&2
  exit 1
fi

ICON_PATH="$RESOURCES_DIR/${BUNDLE_ICON%.icns}.icns"
if [[ ! -f "$ICON_PATH" ]]; then
  echo "Missing app icon: $ICON_PATH" >&2
  exit 1
fi

if ! file "$ICON_PATH" | grep -q "Mac OS X icon"; then
  echo "App icon is not a valid icns file: $ICON_PATH" >&2
  exit 1
fi

echo "Smoke test passed: $APP_DIR"
