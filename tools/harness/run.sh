#!/usr/bin/env bash
# Runs one harness scenario (tools/harness/README.md).
#   tools/harness/run.sh <scenario>                 headless: logic checks only
#   tools/harness/run.sh <scenario> --rendered      opens a window and saves screenshots
#   tools/harness/run.sh <scenario> --out <dir>     output directory (default tools/harness/out/<scenario>)
# The save file is <out>/base.json, never user://base.json. The output directory is
# emptied first, so every run starts from a new base. Exits non-zero when a check fails
# or Godot logs a script error.
set -uo pipefail

cd "$(dirname "$0")/../.."
if [ -z "${GODOT:-}" ]; then
  if command -v godot >/dev/null 2>&1; then GODOT=godot
  else GODOT=/Applications/Godot.app/Contents/MacOS/Godot; fi
fi
if ! command -v "$GODOT" >/dev/null 2>&1 && [ ! -x "$GODOT" ]; then
  echo "Godot not found. Install Godot 4.7 and set GODOT=/path/to/godot" >&2
  exit 2
fi

scenario=""
mode="--headless"
out=""
while [ $# -gt 0 ]; do
  case "$1" in
    --rendered) mode="" ;;
    --headless) mode="--headless" ;;
    --out) out="$2"; shift ;;
    -*) echo "unknown option $1" >&2; exit 2 ;;
    *) scenario="$1" ;;
  esac
  shift
done
if [ -z "$scenario" ]; then
  echo "usage: tools/harness/run.sh <scenario> [--rendered] [--out <dir>]" >&2
  echo "scenarios:" >&2
  ls tools/harness/scenarios/*.gd 2>/dev/null | sed 's#.*/##; s#\.gd$##; s#^#  #' >&2
  exit 2
fi
if [ ! -f "tools/harness/scenarios/$scenario.gd" ]; then
  echo "no scenario tools/harness/scenarios/$scenario.gd" >&2
  exit 2
fi
if [ -z "$out" ]; then out="tools/harness/out/$scenario"; fi
rm -rf "$out"
mkdir -p "$out"
out="$(cd "$out" && pwd)"

# The driver needs class_name scripts (HarnessScenario, the game's classes) registered.
"$GODOT" --headless --path . --import >/dev/null 2>&1

output="$("$GODOT" $mode --path . -s res://tools/harness/driver.gd -- \
  "--scenario=$scenario" "--out=$out" "--save-path=$out/base.json" 2>&1)"
status=$?
echo "$output"
if grep -qE "SCRIPT ERROR|Parse Error|Failed to load script" <<<"$output"; then
  echo "FAILED: Godot reported script errors (see above)." >&2
  exit 1
fi
echo "output in $out"
exit $status
