#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_PATH="$ROOT_DIR/.build/timer_engine_check"

export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/module-cache"

swiftc \
  "$ROOT_DIR/Sources/TOCK/Models.swift" \
  "$ROOT_DIR/Sources/TOCK/TimerEngine.swift" \
  "$ROOT_DIR/scripts/check_timer_engine.swift" \
  -o "$OUTPUT_PATH"

"$OUTPUT_PATH"
