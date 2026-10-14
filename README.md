# Space Game

A Clash-style space base builder for iOS and Android, built with Godot 4.7.

## Quick start

1. Install [Godot 4.7](https://godotengine.org/download) (the standard build, not .NET).
2. Open this folder in Godot, or run it from a terminal:
   ```
   export GODOT=/Applications/Godot.app/Contents/MacOS/Godot   # macOS path
   $GODOT --path .
   ```
3. Run the tests, or the whole gate (import, tests, compile check, headless boot):
   ```
   tools/run_tests.sh
   tools/gates.sh
   ```
4. See a change without clicking through it: `tools/harness/run.sh place_and_build --rendered`
   runs a scripted scenario on an isolated save and writes screenshots (`tools/harness/README.md`).

## Controls

| Action | Phone | Desktop |
|---|---|---|
| Pan | drag the ground | click-drag the ground |
| Zoom | pinch | scroll wheel / trackpad pinch |
| Select | tap a building | click a building |
| Move | drag the selected building | same |
| Build | tap a build button, drag the ghost, tap Place | same |

Debug builds show a **Reset base** button. The save lives in Godot's `user://base.json`.

See `CLAUDE.md` for the architecture, rules and the agent workflow, `docs/project_overview.md`
for the status, roadmap and decisions, and `docs/reference/` for how each area works.
