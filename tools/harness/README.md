# Harness

A scripted driver for behaviour checks: it boots the real game scene on an isolated save,
runs a scenario that acts on it the way a player does, and writes a log and screenshots.
It is how a developer or reviewer verifies a change in a clone without touching the owner's
save, and how the coordinator sees a change without clicking through it. It is not a test
runner: logic has tests under `test/`; the harness checks what the tests cannot, the wiring
between `src/core`, `src/game` and the scene.

- `driver.gd` — a `SceneTree` script (`HarnessDriver`). Boots `scenes/main.tscn`, installs
  the harness clock, runs one scenario, writes `log.txt` and the screenshots, quits with
  exit code 0 when every check passed.
- `scenario.gd` — `HarnessScenario`, the base class every scenario extends: `run(main)` plus
  the helpers below.
- `scenarios/*.gd` — one scenario per file, named by its file: `place_and_build.gd` is the
  worked example.
- `run.sh` — the wrapper that imports the project, picks the output directory and the save
  file, runs the driver and fails on any script error.

## Running

```
tools/harness/run.sh place_and_build                 # headless: logic checks only
tools/harness/run.sh place_and_build --rendered      # a window; screenshots are saved
tools/harness/run.sh place_and_build --out <dir>     # output elsewhere
tools/harness/run.sh                                 # lists the scenarios
```

`GODOT` names the engine binary; without it, `godot` on `PATH`, then the macOS app bundle.
Output goes to `tools/harness/out/<scenario>/` (gitignored) unless `--out` says otherwise:
`log.txt`, `NN-<name>.png` per screenshot in a rendered run, and `base.json`, the run's
save file. The directory is emptied before each run, so every run starts from a new base
laid out from `data/rules.json`.

**Headless** (`--headless`, the default) renders nothing: `screenshot()` logs that it was
skipped and the run checks logic only. It is the mode for a gate-style check and the only
mode two lanes may run at once. **Rendered** (`--rendered`) opens the game window at the
project's 1280x720 and saves each screenshot from the window's viewport texture. It takes
the display, so only one rendered run happens on a machine at a time.

A run exits 0 only when every `check()` passed and Godot logged no `SCRIPT ERROR`. The
last lines of `log.txt` are `HARNESS PASS: <scenario>` or `HARNESS FAIL: <scenario>, N
failed check(s)` followed by each failed check.

## How a run is isolated

- **The save.** `run.sh` passes `--save-path=<out>/base.json` after `--`; `main.gd` reads it
  from `OS.get_cmdline_user_args()` and loads and saves there instead of `user://base.json`.
  The driver refuses a save path under `user://`. This is the only way to boot the game in a
  clone: `$GODOT --path .` without the argument opens the owner's real save.
- **The clock.** The driver's clock starts 1,000,000 s ahead of the device clock and moves
  only when a scenario calls `advance()`. It replaces `PlacementController.clock`, so every
  command a scenario applies carries harness time, and the game's own one-second tick, which
  advances the state to device time, is ignored by `BaseState.advance_to` because that time
  is in the past. A run is therefore repeatable to the second whatever the machine's speed.
  The fresh base is advanced to the harness clock once at boot; a new base has no producing
  building, so nothing is paid out by that jump.
- **The engine's own files.** Like any Godot run, a harness run writes the `.godot/` cache
  and any missing `*.uid` files in the tree it runs in. That is why the harness, like the
  gates, is run in a lane's own clone and never in the main tree by anyone but the
  coordinator.

## Writing a scenario

A scenario is a script in `scenarios/` that extends `HarnessScenario` and overrides
`run(main: MainScript) -> void`, where `main` is the root node of `scenes/main.tscn`
(`MainScript` is `main.gd` preloaded; it has no `class_name`). `run` may `await`. Act
through the game layer as the player would, and read the state through `BaseState`:

| Through | What |
|---|---|
| `main.placement` | `begin_place(type)`, `confirm_place()`, `cancel_place()`, `select(id)`, `upgrade_selected()`, `is_placing()`, `ghost_is_valid()`, `selected_id` |
| `main.world_input` signals | `tapped`, `drag_started`, `dragged`, `drag_ended`, `pinched`, `panned`; emit them to simulate a gesture (`tap_cell` below does) |
| `main.hud` signals | `build_pressed`, `confirm_pressed`, `cancel_pressed`, `upgrade_pressed`, `close_pressed`, `reset_pressed`; emit them to press a button |
| `main.hud` queries | `tab_button(category)`, `entry_button(type)`, `entry_status(type)`, `resource_panel(res)`, `place_button()`, `drones_panel()`, `reset_button()` (`docs/reference/hud.md`); `apply_safe_area(inset)` to try a notch-like inset |
| `main.state` | the `BaseState`: `buildings`, `resources`, `capacity()`, `builders_free()`, `seconds_left(id)`, `check_*` |
| `main.camera`, `main.base_view` | `IsoCamera` and `BaseView`, for cell and screen mapping |

Helpers on `HarnessScenario`:

- `check(condition, message)` — records a failure and carries on, like the tests' asserts.
- `say(text)` — a line in `log.txt` and on stdout.
- `now()` — the harness clock in unix seconds.
- `advance(seconds)` — moves the clock and calls `BaseState.advance_to`, as the game's tick
  does; construction finishes and production is paid exactly as it would over real time.
- `await frames(n)` — waits `n` frames, so the views and the HUD catch up with a state change
  before a screenshot or a check of a view.
- `await screenshot(name)` — saves `NN-name.png` in a rendered run, logs a skip headless.
- `tap_cell(main, cell)` — emits `WorldInput.tapped` at the screen position of a cell's
  centre, so `PlacementController` handles it exactly as a real tap.

A scenario never reads a clock, never writes outside the output directory, and never calls
`BaseState.apply` for something the player does through `PlacementController` (the point is
to exercise that path). Reading a private member (`_ghost_cell`) is a sign the controller
needs a query, not a reason to reach in.

`scenarios/place_and_build.gd` does all of this: it screenshots the fresh base, begins
placing a Metal Extractor, confirms it, checks the cost, the drone and the construction
timer, advances to one second before completion and then past it, and screenshots the
built extractor.

`scenarios/model_gallery.gd` shows every building model: one `BuildingView` per type and level
in the catalog, laid out on the grid in rows by category (`"core"`, then
`catalog.categories`), under a node of its own, with the base's own views hidden. The roster
does not fit on the grid at once, so rows that do not fit start a new page. Each page gets an
overview screenshot and each row a close-up, framed through `camera.zoom_at` and `camera.pan`.
In both modes it checks every model against the budget: at most two `MeshInstance3D` and at
most 500 triangles, 40 for traps and walls (`category_of`).

`scenarios/hud_menu.gd` checks the HUD on a fresh base: antimatter hidden in the top bar,
every menu type in exactly one tab and in menu order, an entry's built/max and a locked
entry's "Needs Command Center N", that taps on a tab and an entry and a drag across the
strip act on the menu without reaching the world, and that Place follows the ghost onto the
Command Center and off it. It screenshots each tab, the Command Center's info panel, and the
HUD under a notch-like inset (44 at the top, 34 at the bottom). Last, it grows the base to
Command Center 4 with every collector that level allows, fills the storage, and checks that
antimatter shows and that the debug button clears the Drones panel on the widest top bar.
Where a check is about touch routing, a scenario sends real events with
`Input.parse_input_event` (`InputEventScreenTouch`, `InputEventScreenDrag`): they arrive in
window pixels, so map a HUD point through `get_viewport().get_final_transform()`. They are
delivered headless too, so those checks run in both modes.
