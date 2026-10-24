#!/usr/bin/env bash
# The beatability matrix (docs/plans/retune.md): tools/sim_battles.gd against the expedition
# fields for each Command Center level given, each band (field 0 easy, 2 even, 4 hard) and each
# deploy strategy, with a full army of that level at its researched levels and no abilities.
# Prints sim_battles' summary line per run; the CSVs go to <out>. Run after an import
# (tools/gates.sh does one), from anywhere:
#   tools/sim_matrix.sh [--seeds=20] [--out=<dir>] [cc ...]     (cc defaults to 3 5 7 10)
# Set GODOT to the engine binary; it falls back to `godot` on PATH, then the macOS app.
set -uo pipefail

cd "$(dirname "$0")/.."
if [ -z "${GODOT:-}" ]; then
  if command -v godot >/dev/null 2>&1; then GODOT=godot
  else GODOT=/Applications/Godot.app/Contents/MacOS/Godot; fi
fi
if ! command -v "$GODOT" >/dev/null 2>&1 && [ ! -x "$GODOT" ]; then
  echo "Godot not found. Install Godot 4.7 and set GODOT=/path/to/godot" >&2
  exit 2
fi

seeds=20
out=tools/harness/out/sim_matrix
levels=()
for arg in "$@"; do
  case "$arg" in
    --seeds=*) seeds="${arg#--seeds=}" ;;
    --out=*) out="${arg#--out=}" ;;
    *) levels+=("$arg") ;;
  esac
done
[ ${#levels[@]} -eq 0 ] && levels=(3 5 7 10)
mkdir -p "$out"

# The army of a Command Center level: its Hangars' full housing (70, 88, 135, 150, 220, 230, 280).
army() {
  case "$1" in
    1) echo "ranger:20" ;;
    2) echo "ranger:20,breacher:2,brawler:3" ;;
    3) echo "ranger:30,breacher:4,brawler:12,dune_runner:4" ;;
    4) echo "siege_walker:1,jet_trooper:6,breacher:4,brawler:12,ranger:30,dune_runner:4" ;;
    5) echo "hover_tank:2,siege_walker:2,gunship:1,breacher:6,brawler:15,jet_trooper:10,ranger:35" ;;
    6) echo "hover_tank:3,siege_walker:2,gunship:1,bomber:1,breacher:6,brawler:18,jet_trooper:10,skimmer:3,ranger:24" ;;
    7) echo "titan:1,hover_tank:4,siege_walker:2,gunship:2,bomber:2,breacher:8,brawler:20,jet_trooper:10,skimmer:5,ranger:33" ;;
    8) echo "titan:1,hover_tank:4,siege_walker:2,gunship:2,bomber:2,breacher:8,brawler:20,jet_trooper:10,skimmer:5,ranger:43" ;;
    *) echo "titan:2,hover_tank:5,siege_walker:2,gunship:2,bomber:3,breacher:8,brawler:20,jet_trooper:10,skimmer:10,ranger:44" ;;
  esac
}

status=0
for cc in "${levels[@]}"; do
  for band in 0:easy 2:even 4:hard; do
    index="${band%%:*}"
    for strategy in edge two_edges waves random; do
      csv="$out/cc${cc}_${band#*:}_${strategy}.csv"
      line="$("$GODOT" --headless --path . -s res://tools/sim_battles.gd -- --seeds="$seeds" \
        --outpost="$index" --cc="$cc" --strategy="$strategy" --army="$(army "$cc")" \
        --out="$csv" 2>&1 >/dev/null | grep "^sim_battles:")"
      [ -z "$line" ] && status=1
      echo "CC $cc ${band#*:} ${line#sim_battles: }"
    done
  done
done
exit $status
