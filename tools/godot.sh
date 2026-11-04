#!/usr/bin/env bash
# Runs the project's pinned Godot version: tools/godot.sh <godot args...>
set -euo pipefail
GODOT="${GODOT:-$("$(dirname "$0")/setup.sh")}"
exec "$GODOT" "$@"
