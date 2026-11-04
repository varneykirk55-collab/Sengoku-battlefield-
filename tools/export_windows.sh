#!/usr/bin/env bash
# Exports the Windows build and zips it: tools/export_windows.sh [version-label]
# Output: build/windows/SengokuBattlefield.exe and dist/SengokuBattlefield-<label>-Windows.zip
set -euo pipefail
cd "$(dirname "$0")/.."
LABEL="${1:-dev}"
GODOT="$(tools/setup.sh --templates)"
rm -rf build/windows && mkdir -p build/windows dist
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "Windows Desktop" build/windows/SengokuBattlefield.exe
test -s build/windows/SengokuBattlefield.exe
(cd build/windows && zip -qr "../../dist/SengokuBattlefield-${LABEL}-Windows.zip" .)
ls -lh build/windows "dist/SengokuBattlefield-${LABEL}-Windows.zip"
