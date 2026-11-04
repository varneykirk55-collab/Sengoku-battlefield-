#!/usr/bin/env bash
# Runs a headless AI battle and prints a report. SIM_SECONDS / SIM_SOLDIERS env vars.
set -uo pipefail
cd "$(dirname "$0")/.."
tools/godot.sh --headless --path . --import >/dev/null 2>&1 || true
tools/godot.sh --headless --path . --fixed-fps 60 res://tools/sim/battle_sim.tscn 2>&1 | grep -E '\[sim\]|SCRIPT ERROR|at: ' | head -60
