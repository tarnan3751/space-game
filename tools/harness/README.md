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
skipped and the run checks logic only. It is the mode for a gate-style check, and any number
of headless runs may go at once. **Rendered** (`--rendered`) opens the game window at the
project's 1280x720 and saves each screenshot from the window's viewport texture.

Godot stops drawing a window that is fully covered, and a window that is not drawn leaves every
later screenshot repeating its last frame, so `run.sh` guards rendered runs three ways:

- The window is kept on top (`--always-on-top`), so the terminal that launched it does not
  cover it.
- Rendered runs take turns on a machine: `run.sh` holds the lock directory
  `${TMPDIR:-/tmp}/space-game-harness-rendered.lock` (made with `mkdir`, which is atomic) for
  the run and removes it on exit, a failure or an interrupt. Another rendered run prints that
  it is waiting and polls every two seconds for up to twenty minutes, then fails; a lock older
  than fifteen minutes was left by a run that died and is taken over. A lane just runs `run.sh`
  and waits. Headless runs take no lock.
- A rendered run whose screenshots are all byte-identical fails. Two identical in a row print a
  warning only, since a scenario may mean to show that nothing changed.

A run exits 0 only when every `check()` passed, Godot logged no `SCRIPT ERROR`, and a rendered
run's screenshots are not all identical. The last lines of `log.txt` are `HARNESS PASS:
<scenario>` or `HARNESS FAIL: <scenario>, N failed check(s)` followed by each failed check.

## How a run is isolated

- **The save.** `run.sh` passes `--save-path=<out>/base.json` after `--`; `main.gd` reads it
  from `OS.get_cmdline_user_args()` and loads and saves there instead of `user://base.json`.
  The driver refuses a save path under `user://`. This is the only way to boot the game in a
  clone: `$GODOT --path .` without the argument opens the owner's real save.
- **The numbers.** `run.sh` also passes `--no-cheats`. Without it, a debug build (the editor
  binary the harness runs on) applies the dev cheats (`Catalog.apply_dev_cheats`: every level
  free and built in one second at most) and the HUD shows the resources as infinite; with it,
  `main.cheats` is false and every scenario runs on the real costs and times.
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
| `main.placement` | `begin_place(type)`, `confirm_place()`, `cancel_place()`, `select(id)`, `upgrade_selected()`, `is_placing()`, `is_painting()`, `ghost_is_valid()`, `ghost_cell()`, `selected_id` |
| `main.world_input` signals | `tapped`, `drag_started`, `dragged`, `drag_ended`, `pinched`, `panned`; emit them to simulate a gesture (`tap_cell` below does) |
| `main.hud` signals | `build_pressed`, `confirm_pressed`, `cancel_pressed`, `upgrade_pressed`, `close_pressed`, `reset_pressed`; emit them to press a button |
| `main.hud` queries | `build_button()`, `is_menu_open()`, `build_panel()`, `close_button()`, `tab_button(category)`, `entry_button(type)`, `entry_status(type)`, `resource_panel(res)`, `resource_fill(res)`, `place_button()`, `drones_panel()` (the `DroneRing`: `free_count()`, `total_count()`), `reset_button()` (`docs/reference/hud.md`); `apply_safe_area(inset)` to try a notch-like inset |
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
- `await open_build_menu(main)` — presses the HUD's Build button (unless the build panel is
  already open), waits for the panel to slide up and checks that it is open. A scenario that
  picks a building from the menu opens it this way first.

A scenario never reads a clock, never writes outside the output directory, and never calls
`BaseState.apply` for something the player does through `PlacementController` (the point is
to exercise that path). Reading a private member (`_ghost_cell`) is a sign the controller
needs a query, not a reason to reach in.

`scenarios/place_and_build.gd` does all of this: it screenshots the fresh base, begins
placing a Metal Extractor, confirms it, checks the cost, the drone and the construction
timer, advances to one second before completion and then past it, and screenshots the
built extractor.

`scenarios/dev_cheats.gd` checks the dev cheats, which `--no-cheats` keeps off: it checks that
`main.cheats` is false, empties the base's resources, checks that the first menu type that takes
time to build is unaffordable, applies `main.catalog.apply_dev_cheats()` itself, and places that
type through `PlacementController`: it builds for one second on the only drone. Meanwhile a
12-cell paint stroke of Barrier Wall places 12 walls, since instant levels stay instant. Then it
checks that nothing was spent and that one `advance(1)` later the building is finished at level
1. It takes no screenshots, so it is meant to run headless.

`scenarios/model_gallery.gd` shows every building model: one `BuildingView` per type and level
in the catalog, laid out on the grid in rows by category (`"core"`, then
`catalog.categories`), under a node of its own, with the base's own views hidden. The roster
does not fit on the grid at once, so rows that do not fit start a new page. Each page gets an
overview screenshot (at the widest zoom, held for 2.1 seconds so that the frame rate, which
counts the last whole second, covers one with the page already set up, after which it says the
draw calls and the frame rate there), each row a close-up, and each row's first building a detail
shot at the closest zoom (camera size 10), where outlines, bands and textures can be read; all
are framed through `camera.zoom_at` and `camera.pan`. The frame rate is only meaningful when
nothing else is loading the machine.
In both modes it checks every model: one or two body `MeshInstance3D` (the static body and the
spinning part), each with an outline instance beside it on `MaterialKit.ink()` that casts no
shadow; no vertex's kit layer (`UV2.x`) beyond the kit's last; and the body triangles within the
budget for its footprint (`docs/reference/art-style.md`, **Budgets**: 600 for 1x1, 2,000 for
2x2, 3,000 for 3x3, 5,000 for 4x4 and 5x5, 250 for a wall piece); and its reach in x and z
within half its footprint plus 0.15 units (`EXTENT_SLACK`): the static body's bounds, and a
spinning part's sweep (its vertices' largest distance from the pivot axis plus the pivot's
offset from the centre), both at the model's scale. A failure says by how much it reaches over;
nothing checks the height.

`scenarios/view_states.gd` checks the comic style's view states on a fresh base, each with a
close-up screenshot: the selected Command Center's outlines in gold (and the override cleared on
deselecting), the placement ghost's body tinted valid on a free spot and invalid on the Command
Center with its outline left plain ink, and a new building's scaffold. It first says the fresh base's draw calls and frame rate.

`scenarios/environment.gd` checks the ground and the scenery on a fresh base
(`docs/reference/art-style.md`, **Environment**): the terrain, the curb, the rocks and the crystal
outcrops are each a body with an ink outline on `MaterialKit.ink()` that casts no shadow, the
terrain's and the curb's bodies casting none either; the terrain's triangles are within 35,000; no
vertex of an outcrop lies within 4 units of the field; along each side of the field, 3 units out,
at 40 evenly spaced points, the terrain's heights spread by more than 0.1 (the ground is uneven)
and never pass 0.4 (it stays low by the curb), and the distance out at which its relief is full
(`BaseView.blend_end`) spreads by more than 3 units (the edge wanders; the terrain before the
wandering edge fails both, its ground there 0.83 to 0.88 high and its relief full 3 out
everywhere); and at the widest zoom, in a 1560x720 window (a 19.5:9 phone) and with the focus at
each corner of its bounds, the ray from every corner of the screen meets the terrain, so the clear
colour never shows: marched in half-unit steps over `BaseView.terrain_height`, it must enter the
terrain's extent above the ground (not under its raised outer edge) and meet the ground before it
leaves. Those checks are worked out from `BaseView` and the camera's transform, so they hold
headless. It screenshots the start zoom, the closest zoom on the field (its marks and the grid),
the closest zoom on a point where four of the field texture's tiles meet (`tile-corner`, where
nothing should show the tiles' edges), a wider stretch of the field at camera size 12 (`tiles`),
the curb at the middle of each side of the field at size 16 (`edge-top-left`, `edge-top-right`,
`edge-bottom-right`, `edge-bottom-left`, by the screen corner each side faces), the widest zoom in
the wide window, and a crater and an outcrop each centred; for the curb, the crater and the
outcrop it widens the camera's bounds to the terrain's, since the player cannot centre the view
off the field.

`scenarios/hud_menu.gd` checks the HUD on a fresh base. The top bar: antimatter hidden, each
meter's fill as wide as its track times amount over capacity (to a pixel) and the drone ring's
free and total drones. The build panel: closed at start with Build showing, and a tap where it
opens reaching the world; Build opens it on the first tab; a tap on each tab shows exactly that
category's cards; a locked card is disabled with its "Needs Command Center N"; taps on the panel's
empty top row, on a meter, on the drone ring and on the close button reach nothing behind them,
and the close button closes the panel. A card: Metal Extractor reads "0 / 2"; a finger on it shows
it pressed, and lifting it closes the panel and begins placing, with the place bar in place of
Build, which comes back on cancelling. A purchase (Crystal Harvester, through the menu, confirmed)
lowers the metal fill and busies the ring's one drone, both checked as at the start. Last, Build
over the new building's info panel clears the selection and opens the panel, and in a 1560x720
window the close button stays on screen. It screenshots the closed HUD, the open panel on each
tab, the card pressed, the place bar, the purchase (the meters after it, the busy ring and the new
building's info panel), and the open panel in the wide window. Where a check is about touch
routing, a scenario sends real events with `Input.parse_input_event` (`InputEventScreenTouch`,
`InputEventScreenDrag`): they arrive in window pixels, so map a HUD point through
`get_viewport().get_final_transform()`. They are delivered headless too, so those checks run in
both modes.

`scenarios/hud_layout.gd` checks the HUD's layout on a fresh base. Under a notch-like safe-area
inset (48 at the sides, 44 at the top, 34 at the bottom) with the build panel open on the
defence tab, the top bar, the Build button, the tabs and the first card keep inside the inset
less `Hud.MARGIN`, while the panel reaches the screen's sides and bottom edge; it screenshots
that. Back on the whole screen, a real one-finger drag across the card strip scrolls it and
presses nothing. Last, it presses Build, resizes the window to 1280x900 two frames into the
opening slide, and checks that the panel ends open on the new bottom edge, and screenshots it.

`scenarios/paint_walls.gd` checks wall painting and the edge scroll on a fresh base: Barrier
Wall from the menu enters paint mode with Done on the place bar; a drag along a row of twelve
cells places twelve walls at level 1's cost, drawn as one merged wall mesh whose triangles are
its twelve pieces' (an end piece at each end, ten joined both ways), with an outline instance
that casts no shadow; a tap places one and a tap on a wall nothing; a fast drag across the row
fills the cells it jumped and skips the wall; with no metal a drag places nothing and shows one
toast; the brush is VALID on the wall it just placed and INVALID with no metal; a drag held at
the right edge scrolls the camera and paints under the finger; a drag past the count limit stops
there with one toast; Done ends the mode with the walls kept. Then the ghost of a 3x3 type and
the selected drone bay are each held near the right edge: the camera scrolls right, each stays
under the finger, and the bay drops there. Last, a drag of the bay that a second finger
interrupts by pressing Close, then Reset base, ends at once and moves nothing, on the old base
or the new one. It screenshots the brush, the painted row and a close-up of it at the closest
zoom, the place bar with Done, and the ghost and the bay at the edge. A held drag scrolls for a
number of frames, so how far depends on the frame rate; the checks hold at any distance.

`scenarios/wall_junctions.gd` checks walls that connect. It grows a fresh base to Command
Center 5, paints a straight run, a corner, a T, a cross and a ramp (a run whose walls end at
levels 1 to 5) by tapping, and upgrades them together to level 3, then 5. At each level it
checks the merged wall mesh: every wall view hides its model, the mask of a named cell in each
shape (`WallMesh.mask_at`), every wall's mask against the rule (four-connected, any levels),
and the mesh's triangles against the sum of its pieces'; and it screenshots the pattern at the
closest zoom (level 1 also with the paint brush beside it). It checks that a wall's own model,
which the brush and the gallery show, is the lone post, and that every piece of every level
and mask is within the 250 body triangles of a wall piece. Last, it selects the cross's centre,
which stays merged with no gold outline (its own model, whose outlines turn gold, stays hidden),
and lifts it: the mesh drops it and its neighbours' joints, its own post shows, and carried back
and dropped it rejoins the cross; screenshots show it selected and in the air.
