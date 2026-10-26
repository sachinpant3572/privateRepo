#!/usr/bin/env bash
# Exports a debug APK (arm64) to game/build/port-lafitte-debug.apk.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
godot --headless --import >/dev/null 2>&1
godot --headless --export-debug "Android" build/port-lafitte-debug.apk 2>&1 | grep -E "Signed|ERROR" || true
ls -la build/port-lafitte-debug.apk
