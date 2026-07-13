#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${1:-debug}"

if [[ "$CONFIGURATION" != "debug" && "$CONFIGURATION" != "release" ]]; then
  echo "Usage: scripts/package_app.sh [debug|release]" >&2
  exit 1
fi

BUILD_ARGS=(
  --disable-sandbox
  --cache-path "$ROOT_DIR/.build/swiftpm-cache"
)

if [[ "$CONFIGURATION" == "release" ]]; then
  BUILD_ARGS+=(-c release)
fi

export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/module-cache"

swift build "${BUILD_ARGS[@]}"
BIN_PATH="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"
EXECUTABLE_PATH="$BIN_PATH/TOCK"

if [[ ! -x "$EXECUTABLE_PATH" ]]; then
  echo "Built executable was not found at $EXECUTABLE_PATH" >&2
  exit 1
fi

APP_DIR="$ROOT_DIR/dist/TOCK.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$ROOT_DIR/Packaging/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$EXECUTABLE_PATH" "$MACOS_DIR/TOCK"
chmod +x "$MACOS_DIR/TOCK"

GENERATED_ICONSET_DIR="$ROOT_DIR/.build/TOCK.iconset"

if command -v python3 >/dev/null 2>&1; then
  rm -rf "$GENERATED_ICONSET_DIR"
  python3 "$ROOT_DIR/scripts/generate_icon.py" "$GENERATED_ICONSET_DIR" "$RESOURCES_DIR/TOCK.icns"
elif [[ -f "$ROOT_DIR/Assets/TOCK.icns" ]]; then
  cp "$ROOT_DIR/Assets/TOCK.icns" "$RESOURCES_DIR/TOCK.icns"
fi

if [[ -f "$ROOT_DIR/Assets/TOCK.svg" ]]; then
  cp "$ROOT_DIR/Assets/TOCK.svg" "$RESOURCES_DIR/TOCK.svg"
fi

echo "Packaged $APP_DIR"
