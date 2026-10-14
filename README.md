# Starbase

A Clash-style space base builder for iOS and Android, built with Godot 4.7.

## Quick start

1. Install [Godot 4.7](https://godotengine.org/download) (the standard build, not .NET).
2. Open this folder in Godot, or run it from a terminal:
   ```
   export GODOT=/Applications/Godot.app/Contents/MacOS/Godot   # macOS path
   $GODOT --path .
   ```
3. Run the tests:
   ```
   tools/run_tests.sh
   ```

## Controls

| Action | Phone | Desktop |
|---|---|---|
| Pan | drag the ground | click-drag the ground |
| Zoom | pinch | scroll wheel / trackpad pinch |
| Select | tap a building | click a building |
| Move | drag the selected building | same |
| Build | tap a build button, drag the ghost, tap Place | same |

Debug builds show a **Reset base** button. The save lives in Godot's `user://base.json`.

See `CLAUDE.md` for the architecture, rules and roadmap.
