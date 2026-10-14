#!/usr/bin/env bash
# Dumps the exact engine API of the installed Godot into .godot-api/ (gitignored),
# so signatures can be checked instead of guessed:
#   find .godot-api -name Camera3D.xml
# Re-run after upgrading Godot.
set -euo pipefail

GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."

rm -rf .godot-api
mkdir -p .godot-api
# Keep the editor from scanning or importing the dump.
touch .godot-api/.gdignore
"$GODOT" --headless --doctool .godot-api >/dev/null
echo "API reference written to .godot-api/ ($("$GODOT" --version))"
