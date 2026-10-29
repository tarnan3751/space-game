#!/usr/bin/env bash
# The gate: everything a change must pass before it is reported, reviewed or landed
# (CLAUDE.md, **Agent workflow**). Runs, in order:
#   1. import       $GODOT --headless --import   (registers class_name scripts, refreshes .godot/)
#   2. tests        tools/run_tests.sh
#   3. check-only   $GODOT --check-only on every .gd under src/, test/ and tools/
#   4. boot         scenes/main.tscn headless for 240 frames on an isolated save, quitting by
#                   main's own quiet quit (--quit-frames), with no SCRIPT ERROR or ERROR line
# Prints one line per gate, the failing gate's output in full, and exits non-zero when
# any gate fails. The main scene boot uses --save-path, so the real save is never read.
# Set GODOT to the engine binary; it falls back to `godot` on PATH, then the macOS app.
set -uo pipefail

cd "$(dirname "$0")/.."
if [ -z "${GODOT:-}" ]; then
  if command -v godot >/dev/null 2>&1; then GODOT=godot
  else GODOT=/Applications/Godot.app/Contents/MacOS/Godot; fi
fi
export GODOT
if ! command -v "$GODOT" >/dev/null 2>&1 && [ ! -x "$GODOT" ]; then
  echo "Godot not found. Install Godot 4.7 and set GODOT=/path/to/godot" >&2
  exit 2
fi

BOOT_FRAMES=240
scratch="$(mktemp -d "${TMPDIR:-/tmp}/space-game-gates.XXXXXX")"
trap 'rm -rf "$scratch"' EXIT
failed=0

# report <name> <status> <detail> [<output-file>]
report() {
  local name="$1" status="$2" detail="$3" output="${4:-}"
  printf 'gate %-11s %s%s\n' "$name" "$status" "${detail:+ ($detail)}"
  if [ "$status" != "ok" ]; then
    failed=1
    if [ -n "$output" ] && [ -s "$output" ]; then
      sed 's/^/    /' "$output"
    fi
  fi
}

has_errors() {
  grep -qE "SCRIPT ERROR|Parse Error|Failed to load script|^ERROR:" "$1"
}

# 1. Import ---------------------------------------------------------------------------
"$GODOT" --headless --path . --import >"$scratch/import.txt" 2>&1
if [ $? -eq 0 ] && ! has_errors "$scratch/import.txt"; then
  report import ok ""
else
  report import FAILED "" "$scratch/import.txt"
fi

# 2. Tests ----------------------------------------------------------------------------
tools/run_tests.sh >"$scratch/tests.txt" 2>&1
tests_status=$?
summary="$(grep -E '^[0-9]+ passed, [0-9]+ failed' "$scratch/tests.txt" | tail -1)"
if [ $tests_status -eq 0 ]; then
  report tests ok "$summary"
else
  report tests FAILED "$summary" "$scratch/tests.txt"
fi

# 3. check-only on every script -------------------------------------------------------
# --check-only exits 0 even on a parse error, so the output is what decides.
: >"$scratch/check.txt"
count=0
bad=0
while IFS= read -r file; do
  count=$((count + 1))
  res="res://${file#./}"
  "$GODOT" --headless --path . --check-only -s "$res" >"$scratch/check-one.txt" 2>&1
  if has_errors "$scratch/check-one.txt"; then
    bad=$((bad + 1))
    { echo "== $res"; cat "$scratch/check-one.txt"; } >>"$scratch/check.txt"
  fi
done < <(find src test tools -name '*.gd' | sort)
if [ $bad -eq 0 ]; then
  report check-only ok "$count scripts"
else
  report check-only FAILED "$bad of $count scripts" "$scratch/check.txt"
fi

# 4. Headless boot of the main scene --------------------------------------------------
# main quits itself after BOOT_FRAMES (--quit-frames), through the game's own quit; --quit-after
# is only a backstop so a boot that never quits cannot hang the gate, and fails it.
"$GODOT" --headless --path . --quit-after "$((BOOT_FRAMES * 4))" -- \
  "--save-path=$scratch/boot-save.json" "--quit-frames=$BOOT_FRAMES" >"$scratch/boot.txt" 2>&1
boot_status=$?
if [ $boot_status -eq 0 ] && ! has_errors "$scratch/boot.txt" \
    && grep -q "^main: quitting after $BOOT_FRAMES frames" "$scratch/boot.txt"; then
  report boot ok "$BOOT_FRAMES frames, no errors"
else
  report boot FAILED "exit $boot_status" "$scratch/boot.txt"
fi

if [ $failed -eq 0 ]; then
  echo "gates: all passed"
else
  echo "gates: FAILED"
fi
exit $failed
