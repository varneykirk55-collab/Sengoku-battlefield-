#!/usr/bin/env bash
# Imports the project and runs every automated test headless.
#   tools/test.sh            all tests
#   tools/test.sh audio      only test files / methods containing "audio"
# Fails if any test fails OR if any GDScript runtime error was printed during the run.
set -uo pipefail
cd "$(dirname "$0")/.."
G=tools/godot.sh
LOG="$(mktemp)"
# Fresh checkouts need two import passes before every resource resolves.
"$G" --headless --path . --import >/dev/null 2>&1 || true
"$G" --headless --path . --import >/dev/null 2>&1 || true
SENGOKU_TEST="${1:-}" "$G" --headless --path . --fixed-fps 60 res://tests/test_runner.tscn >"$LOG" 2>&1
CODE=$?
grep -E '^(PASS|FAIL|====)|SCRIPT ERROR|Parse Error' "$LOG"
if grep -q "SCRIPT ERROR" "$LOG"; then
  echo "Script errors during the run:" && grep -A2 "SCRIPT ERROR" "$LOG" | head -40
  CODE=1
fi
cp "$LOG" "${SENGOKU_TEST_LOG:-/dev/null}" 2>/dev/null || true
rm -f "$LOG"
exit $CODE
