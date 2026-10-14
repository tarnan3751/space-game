# Starbase (working title)

A mobile space base-builder in the style of Clash of Clans. Players build and upgrade a base,
send expeditions into procedurally generated fields to gather resources (PvE), and attack
other players' saved bases, which defend themselves with AI (async PvP).

Target: native iOS and Android, light enough for mid-range phones. Solo developer + Claude.

## Status

**Milestone 1 (offline base) — done.** Fixed isometric camera with touch pan and pinch zoom,
grid placement with a ghost and Place/Cancel, select and drag-to-move, construction and upgrade
timers, drone (builder) limits, Command Center level gates, integer resource production with
storage caps, local save with offline progress. All buildings are placeholder primitive models.

Next up is the roadmap below. Balance numbers in `data/` are fast dev values, not tuned.

## Stack (pinned)

- **Godot 4.7.x stable**, statically typed **GDScript**. Not C#: Godot still marks C# on
  iOS/Android experimental.
- **GL Compatibility** renderer, for the widest range of phones.
- **No addons.** Tests use our own runner in `tools/`.
- Later: **Nakama** server with its TypeScript runtime, in `server/`.

Check before writing engine calls. Godot 3 syntax and APIs are the most common mistake here.
Run `tools/dump_api.sh` once, then look up exact signatures in `.godot-api/`
(e.g. `find .godot-api -name Camera3D.xml`).

## Commands

Set `GODOT` to the engine binary first if `godot` isn't on PATH:
`export GODOT=/Applications/Godot.app/Contents/MacOS/Godot`

| What | Command |
|---|---|
| Run all tests | `tools/run_tests.sh` |
| Run some tests | `tools/run_tests.sh production` (matches `file::method`) |
| Compile-check one script | `$GODOT --headless --path . --check-only -s res://src/core/base_state.gd` |
| Run the game | `$GODOT --path .` |
| Dump engine API | `tools/dump_api.sh` |

`run_tests.sh` imports the project first, because headless runs don't register new
`class_name` scripts until an import. It fails if Godot logs any `SCRIPT ERROR`.

**Run the tests after every change to `src/core` or `data/`.**

## Architecture rules

The game is split into two layers. Keeping them apart is what makes server-side
validation and replayable PvP possible later, so treat these as hard rules.

### `src/core/` is pure logic

- `extends RefCounted`, never `Node`. No scenes, no rendering, no input.
- **Never read a clock.** Time comes in as unix seconds (`int`) via `advance_to(t)` and `apply(cmd, t)`.
- **Integers only** for anything that affects game state. Rates are per hour. Remainders are carried
  in "resource-seconds" so tick size never changes the result.
- **No `randi()`/`randf()`.** Use `SeededRng`; the same seed must give the same numbers everywhere.
- Deterministic order: when order matters, sort by id (see `_next_completion`).
- Every state change goes through `BaseState.apply(command, time)`. Commands are plain
  dictionaries (`{"op": "place", "type": ..., "cell": [x, y]}`) because these become the
  server RPCs. Add new actions as new ops with a matching `check_*` function for the UI.
- New behaviour gets a test in `test/core/`. Logic tests use the fixture catalog in
  `test/support/fixtures/`, never the real `data/`, so rebalancing never breaks them.

### `src/game/` is presentation

- Reads `BaseState`, draws it, turns gestures into commands. Never mutates state directly.
- `PlacementController` is the only place that calls `apply()`.
- Scenes are built in code. `scenes/main.tscn` is one node with `main.gd`. Don't hand-write
  big `.tscn` files; their resource ids are easy to break.
- Input: `WorldInput` uses `_unhandled_input`, so HUD controls get touches first. Mouse clicks
  arrive as touches (`emulate_touch_from_mouse`), so there is one code path for desktop and phone.
  Any HUD `Control` that isn't `MOUSE_FILTER_IGNORE` blocks touches to the world, so
  layout-only containers must be set to IGNORE.

### `data/` is game data

- `rules.json` (resources, grid, start layout, build menu) and `buildings.json` (per-level
  cost, build_seconds, hp, produces, storage, builders, requires_cc, max_count per CC level).
- The server will load the same files. Change numbers here, not in code.
- `Catalog` converts JSON numbers to ints on load (Godot parses all JSON numbers as float).
  `test_shipped_data_is_valid` checks the real files.

## Folder layout

```
data/            game data shared with the server
scenes/          main.tscn only
src/core/        catalog, base_state, building_state, base_grid, seeded_rng
src/game/        main, iso_camera, world_input, placement_controller, base_view,
                 building_view, building_models, hud, format, ground.gdshader
test/core/       test_*.gd (one file per core area)
test/support/    TestCase base class, fixtures and fixture JSON
tools/           run_tests.sh, test_runner.gd, dump_api.sh
assets/          real models/audio later (Kenney/Quaternius CC0, Blender)
server/          Nakama TypeScript runtime later (.gdignore keeps Godot out)
```

## GDScript gotchas for this project

- `:=` can't infer a type from a Variant. Indexing an untyped Array/Dictionary or calling
  `.get()` returns Variant, so write the type: `var n: int = dict["k"]`. This is a compile error, not a warning.
- Typed dictionaries (`Dictionary[String, int]`) and typed loop variables (`for id: int in ...`) are used throughout.
- Godot 3 → 4: `Spatial`→`Node3D`, `instance()`→`instantiate()`, `yield`→`await`,
  `export`→`@export`, `connect("sig", self, "m")`→`sig.connect(m)`, `PoolStringArray`→`PackedStringArray`,
  `set_shader_param`→`set_shader_parameter`.
- Packed arrays are passed by value; return them instead of filling an argument.
- Integer division is intentional in core, so that warning is turned off in `project.godot`.
- Comparing a Vector3 Variant with `null`: use `typeof(x) == TYPE_VECTOR3` instead.

## Seeing the game

Claude can't see the screen. After visual or input changes, ask the user for a screenshot.
Or set up godot-mcp-runtime (screenshots, simulated input, live GDScript), after reviewing its source.
Headless (`--headless`) runs catch script errors but render nothing.

## Roadmap

1. ~~Offline base: placement, timers, economy~~ (milestone 1)
2. Base polish: walls (1x1, drag-to-paint), building info art, safe-area margins for notches,
   edge auto-scroll while dragging, real low-poly models in `assets/`.
3. Seeded PvE expeditions: a field generated from a seed with `SeededRng` (asteroids, deposits,
   hazards), returns loot into `BaseState` through a new command.
4. Deterministic battle sim in `src/core/battle/`: fixed-point integer positions (1 cell = 1000
   units), fixed tick, replay = seed + base layout + list of deploy commands. Test it headless
   against AI-built bases; same inputs must give byte-identical results.
5. Server: Nakama with accounts, base storage, and command validation. Battles are verified by
   replaying them in headless Godot running the same `src/core` code.
6. PvP matchmaking, attack log, revenge, shields.

## Decisions

- **Godot over Unity/three.js:** text scenes and scripts an agent can edit, free, native mobile export.
- **One battle sim, not two.** Never port the sim to TypeScript; the server runs headless Godot for replays.
- **Economy validation on the server is still open:** port the small economy rules to TypeScript
  (checked against shared golden test cases) or run headless Godot. Decide in step 5.
- **The local clock is trusted only until the server exists.** Changing device time can cheat today.

## Export notes

- Exclude `test/*`, `tools/*`, `server/*` in export presets.
- If `data/*.json` goes missing in an export, add it to the preset's include filter.
- Commit the `*.uid` files Godot generates next to scripts.
