#!/usr/bin/env bash
# Exports the same content as the Windows build for Linux and runs its self-check headless,
# proving the packaged build finds all of its audio. (The Windows .exe itself can't run here.)
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="$(tools/setup.sh --templates)"
rm -rf build/linux && mkdir -p build/linux
"$GODOT" --headless --path . --export-release "Linux (verification)" build/linux/SengokuBattlefield.x86_64 >/dev/null 2>&1
build/linux/SengokuBattlefield.x86_64 --headless --fixed-fps 60 -- --selfcheck 2>&1 | grep '\[selfcheck\]'
exit "${PIPESTATUS[0]}"
