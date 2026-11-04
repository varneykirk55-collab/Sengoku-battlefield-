#!/usr/bin/env bash
# Renders a scene to PNG under a virtual display with software OpenGL.
# Usage: SHOT_SCENE=res://... SHOT_OUT=/abs/out.png [SHOT_WAIT=1.5] tools/screenshot.sh
set -euo pipefail
cd "$(dirname "$0")/.."
G=tools/godot.sh
xvfb-run -a -s "-screen 0 1600x900x24" "$G" --path . --rendering-driver opengl3 --resolution 1600x900 \
  res://tools/capture/capture.tscn 2>&1 | grep -E '\[capture\]|ERROR|SCRIPT' || true
