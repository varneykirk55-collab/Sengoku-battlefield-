#!/usr/bin/env bash
# Re-bakes data/maps/battlefield_nav.res from the battlefield layout.
set -euo pipefail
cd "$(dirname "$0")/.."
tools/godot.sh --headless --path . --import >/dev/null 2>&1 || true
tools/godot.sh --headless --path . res://tools/nav/bake_navmesh.tscn 2>&1 | grep -E '\[navbake\]|ERROR|SCRIPT'
