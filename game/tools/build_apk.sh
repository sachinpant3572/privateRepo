#!/usr/bin/env bash
# Exports a debug APK (arm64) to game/build/solvera-prototype-debug.apk.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
godot --headless --import >/dev/null 2>&1
godot --headless --export-debug "Android" build/solvera-prototype-debug.apk 2>&1 | grep -E "Signed|ERROR" || true
ls -la build/solvera-prototype-debug.apk
