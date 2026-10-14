#!/usr/bin/env bash
# Runs one harness scenario (tools/harness/README.md).
#   tools/harness/run.sh <scenario>                 headless: logic checks only
#   tools/harness/run.sh <scenario> --rendered      opens a window and saves screenshots
#   tools/harness/run.sh <scenario> --out <dir>     output directory (default tools/harness/out/<scenario>)
# The save file is <out>/base.json, never user://base.json. The output directory is
# emptied first, so every run starts from a new base. Exits non-zero when a check fails
# or Godot logs a script error.
#
# A rendered run needs its window drawn, and Godot stops drawing a window that is fully
# covered, so rendered runs keep their window on top and take turns on a machine: each
# holds a lock directory under ${TMPDIR:-/tmp} (mkdir is atomic), waiting up to LOCK_WAIT
# seconds for it and taking over one older than LOCK_STALE seconds, left by a run that
# died. Headless runs take no lock. A rendered run whose screenshots are all byte-identical
# fails: its window stopped drawing. Two identical in a row only warn, since a scenario may
# mean to show that nothing changed.
set -uo pipefail

LOCK_DIR="${TMPDIR:-/tmp}/space-game-harness-rendered.lock"
LOCK_WAIT=1200
LOCK_POLL=2
LOCK_STALE=900

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

release_lock() {
  rm -f "$LOCK_DIR/owner"
  rmdir "$LOCK_DIR" 2>/dev/null
}

window=""
if [ -z "$mode" ]; then
  window="--always-on-top"
  waited=0
  until mkdir "$LOCK_DIR" 2>/dev/null; do
    # A lock that vanished between mkdir and stat is not stale: the next try takes it.
    if taken="$(stat -c %Y "$LOCK_DIR" 2>/dev/null || stat -f %m "$LOCK_DIR" 2>/dev/null)" \
        && [ $(( $(date +%s) - taken )) -gt $LOCK_STALE ]; then
      echo "harness: taking over a stale rendered-run lock ($LOCK_DIR)" >&2
      release_lock
      continue
    fi
    if [ $waited -ge $LOCK_WAIT ]; then
      echo "FAILED: another rendered run held $LOCK_DIR for ${LOCK_WAIT}s" >&2
      exit 2
    fi
    if [ $((waited % 30)) -eq 0 ]; then
      echo "harness: waiting for another rendered run to finish ($LOCK_DIR: $(cat "$LOCK_DIR/owner" 2>/dev/null))" >&2
    fi
    sleep $LOCK_POLL
    waited=$((waited + LOCK_POLL))
  done
  echo "$$ $(pwd) $scenario" > "$LOCK_DIR/owner"
  trap release_lock EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
fi

output="$("$GODOT" $mode $window --path . -s res://tools/harness/driver.gd -- \
  "--scenario=$scenario" "--out=$out" "--save-path=$out/base.json" 2>&1)"
status=$?
echo "$output"
if grep -qE "SCRIPT ERROR|Parse Error|Failed to load script" <<<"$output"; then
  echo "FAILED: Godot reported script errors (see above)." >&2
  exit 1
fi
if [ -z "$mode" ]; then
  shots=("$out"/*.png)
  if [ ${#shots[@]} -ge 2 ] && [ -e "${shots[0]}" ]; then
    frozen=1
    for shot in "${shots[@]:1}"; do
      if ! cmp -s "${shots[0]}" "$shot"; then
        frozen=0
        break
      fi
    done
    if [ $frozen -eq 1 ]; then
      echo "FAILED: all ${#shots[@]} screenshots are identical; the window stopped drawing (covered, minimised or on another Space?)." >&2
      exit 1
    fi
    for i in $(seq 1 $((${#shots[@]} - 1))); do
      if cmp -s "${shots[$((i - 1))]}" "${shots[$i]}"; then
        echo "harness: warning: $(basename "${shots[$i]}") is identical to the screenshot before it; was the window covered?" >&2
      fi
    done
  fi
fi
echo "output in $out"
exit $status
