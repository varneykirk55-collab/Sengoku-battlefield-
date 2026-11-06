#!/usr/bin/env bash
# Capture fixed-angle environment shots.
# Usage: SHOT_OUT_DIR=/abs/path SHOT_TAG=before tools/env_screenshot.sh
set -euo pipefail
cd "$(dirname "$0")/.."
: "${SHOT_OUT_DIR:?set SHOT_OUT_DIR}"
export SHOT_TAG="${SHOT_TAG:-shot}"
export SHOT_WAIT="${SHOT_WAIT:-1.0}"
xvfb-run -a -s "-screen 0 1600x900x24" tools/godot.sh --path . --rendering-driver opengl3 --resolution 1600x900 \
  res://tools/capture/env_capture.tscn 2>&1 | grep -E '\[env_capture\]|ERROR|SCRIPT' || true
