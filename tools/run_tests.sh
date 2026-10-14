#!/usr/bin/env bash
# Runs the headless test suite.
#   tools/run_tests.sh              run everything
#   tools/run_tests.sh base_state   run tests whose "file::method" contains the text
# Set GODOT to the engine binary if `godot` isn't on PATH, e.g. on macOS:
#   export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
set -uo pipefail

GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."

if ! command -v "$GODOT" >/dev/null 2>&1; then
  echo "Godot not found. Install Godot 4.7 and set GODOT=/path/to/godot" >&2
  exit 2
fi

# A headless run never scans the project, so class_name scripts added since the
# last import aren't registered yet. Importing first refreshes that cache.
"$GODOT" --headless --path . --import >/dev/null 2>&1

output="$("$GODOT" --headless --path . -s res://tools/test_runner.gd -- "$@" 2>&1)"
status=$?
echo "$output"

# Script errors don't stop the runner (Godot logs them and carries on),
# so treat any logged script error as a failure.
if grep -qE "SCRIPT ERROR|Parse Error|Failed to load script" <<<"$output"; then
  echo "FAILED: Godot reported script errors (see above)." >&2
  exit 1
fi
exit $status
