#!/usr/bin/env bash
# Imports the project and runs every automated test headless.
#   tools/test.sh            all tests
#   tools/test.sh audio      only test files / methods containing "audio"
set -euo pipefail
cd "$(dirname "$0")/.."
G=tools/godot.sh
# Fresh checkouts need two import passes before every resource resolves.
"$G" --headless --path . --import >/dev/null 2>&1 || true
"$G" --headless --path . --import >/dev/null 2>&1 || true
SENGOKU_TEST="${1:-}" "$G" --headless --path . --fixed-fps 60 res://tests/test_runner.tscn 2>&1 \
  | tee "${SENGOKU_TEST_LOG:-/dev/null}" \
  | grep -E '^(PASS|FAIL|====)|SCRIPT ERROR|Parse Error|ERROR:' ; exit "${PIPESTATUS[0]}"
