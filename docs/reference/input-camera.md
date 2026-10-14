# Input and camera

How `src/game/` turns touches into commands and draws the base: `main.gd`, `IsoCamera`,
`WorldInput`, `PlacementController`, `BaseView`, `BuildingView`, `BuildingModels`, `Palette`
and `LowPolyMesh`. The HUD is in `hud.md`. This layer reads `BaseState` and never mutates it except through
`PlacementController.apply` calls (`CLAUDE.md`, **Architecture rules**).

## The scene (`main.gd`)

`scenes/main.tscn` is one `Node3D` with `main.gd`; everything else is built in `_ready`:

1. `Catalog.load_default()`; a non-empty `load_error` is pushed as an error and the scene stops.
2. The environment: a `WorldEnvironment` (flat dark background, coloured ambient light, filmic
   tonemap), a warm sun `DirectionalLight3D` with shadows, and a cool fill light from the other
   side.
3. `BaseView` (ground, scenery, building views), `IsoCamera` (made current), `WorldInput`,
   `Hud`, then `PlacementController`, which is given the view, the camera and the clock
   (`placement.clock = _now`) and connected to the input signals.
4. The HUD's signals are wired to the controller (`build_pressed` → `begin_place`,
   `confirm_pressed` → `confirm_place`, `cancel_pressed` → `cancel_place`, `upgrade_pressed` →
   `upgrade_selected`, `close_pressed` → `select(0)`, `reset_pressed` → `_reset_base`); the
   controller's `selection_changed` and `placing_changed` refresh the HUD and `command_failed`
   shows a toast.
5. The state is loaded or created (`_load_or_create`) and installed (`_set_state`: disconnects
   the old state's `changed`, connects the new one, hands it to the controller, cancels any
   placement and selection, clears and syncs the view).
6. A 1 s `Timer` ticks: `state.advance_to(_now())`, `base_view.sync(state)`, the HUD refresh
   (timer labels change every second), and a save every `SAVE_EVERY_TICKS` (10) ticks.

`_now()` is the device clock (`Time.get_unix_time_from_system()`); the server will own time
later. `state.changed` → `_on_state_changed`: sync the view, `placement.refresh()` (re-checks
the ghost), refresh the HUD. The save is written on `NOTIFICATION_WM_CLOSE_REQUEST` and
`NOTIFICATION_APPLICATION_PAUSED` too.

**The save path.** `save_path` is `user://base.json` unless a `--save-path=<file>` user
argument (after `--` on the command line, read from `OS.get_cmdline_user_args()`) names
another file. The gate's headless boot and the harness pass one, so a tool run never opens
the owner's save. Loading parses the JSON, calls `BaseState.from_dict`, then `advance_to(now)`
for offline progress; an unreadable file starts a new base with a warning. `_reset_base`
(the debug button) creates a new base and saves at once.

## IsoCamera (`iso_camera.gd`)

A `Camera3D` with a fixed angle: orthographic, pitch −35°, yaw 45°, placed 60 units back
along its own axis from `focus`, the ground point it looks at. It never rotates, so every
building's silhouette is constant and the base stays readable on a phone.

| Member | What |
| --- | --- |
| `size` | The orthographic size: 24 at start, clamped between 10 (closest) and 44. |
| `focus` | Kept inside `bounds`, the world x/z rectangle `setup(area)` receives (`BaseView.area()`, the buildable grid). |
| `ground_point(screen_pos) -> Variant` | Where a screen point hits the y = 0 plane, as a `Vector3`, or `null`. Callers test `typeof(p) == TYPE_VECTOR3`. |
| `pan(screen_pos, screen_delta)` | Moves `focus` so the ground under the finger follows the finger. |
| `zoom_at(factor, screen_pos)` | `factor > 1` zooms in; the ground point under `screen_pos` stays put. |

`_apply()` clamps the focus and rebuilds the transform from the fixed basis.

## WorldInput (`world_input.gd`)

Turns the events the HUD did not consume into gestures. It uses `_unhandled_input`, so any HUD
`Control` that is not `MOUSE_FILTER_IGNORE` gets the touch first and the world never sees it
(`hud.md`, the touch rule). Mouse clicks arrive as touches because
`input_devices/pointing/emulate_touch_from_mouse` is on, so desktop and phone share one path.

| Signal | When |
| --- | --- |
| `tapped(screen_pos)` | A single finger lifted within `TAP_SLOP_PX` (12) of where it landed, with no second finger during the gesture and the touch not cancelled. |
| `drag_started(screen_pos)` | A single finger moved past the slop; the position is where it landed. |
| `dragged(screen_pos, screen_delta)` | Each further move; the first carries the delta from the press. |
| `drag_ended(screen_pos)` | The dragging finger lifted, or a second finger landed. |
| `pinched(factor, screen_pos)` | Two fingers: the ratio of their distance to the previous one, at their midpoint. Also the mouse wheel (`WHEEL_ZOOM_STEP` 1.12 per notch) and the trackpad magnify gesture. |
| `panned(screen_pos, screen_delta)` | Two fingers: the midpoint's movement. Also the trackpad pan gesture (`InputEventPanGesture`, scaled by 8 and negated). |

Once a second finger lands, the rest of that gesture can never become a tap or a drag
(`_multi_touch`). A drag that began on the world keeps the drag events even when the finger
passes over a HUD panel: `_input` (which runs before the HUD) catches `InputEventScreenDrag`
for a finger it is already tracking and marks it handled.

## PlacementController (`placement_controller.gd`)

The only game-layer code that calls `BaseState.apply()`. It interprets the gestures above as
camera moves, selection, placement and building moves.

| Member | What |
| --- | --- |
| `state`, `base_view`, `camera` | Set by `main.gd`. |
| `clock: Callable` | Returns the unix time in seconds for every command it applies; `main._now` in the game, the harness's clock under the harness. |
| `selected_id` | The selected building, `0` for none. `select(id)` updates the view's selection tile and emits `selection_changed`. |
| `placing_type` | The type being placed, `""` when not. `is_placing()`, `ghost_is_valid()`. |
| `signal selection_changed`, `signal placing_changed` | Selection changed; placement began, ended or the ghost moved. `main.gd` refreshes the HUD on both. |
| `signal command_failed(error)` | A command returned an error code; the HUD shows it as a toast. |

**Placing** (`begin_place(type)`): any placement is cancelled and the selection cleared; a
`BuildingView` with id 0 is created as the ghost (level 1's model), lifted, and the ground's
cell grid is brightened (`BaseView.set_grid_highlight`); its starting cell is the footprint
centred on the screen centre's ground point (the grid centre when the centre is off the ground),
moved to the nearest free spot searching outward in square rings (`_find_free_cell`). While
placing, a tap moves the ghost so the footprint is centred on the tapped cell, and a drag that
starts on the ghost carries it (with the grab offset); a drag elsewhere pans. Every move
(`_set_ghost_cell`) clamps the cell into the grid, asks `state.check_place` and colours the
footprint VALID or INVALID, and emits `placing_changed`. `confirm_place()` applies
`{"op": "place", "type", "cell"}` at `clock.call()`, and on success ends placement and selects
`state.last_added_id`; on failure emits `command_failed`. `cancel_place()` frees the ghost and
dims the grid again. `refresh()` re-checks the ghost after the state changed (resources,
builders).

**Selecting and moving.** A tap on a building selects it, a tap on empty ground deselects. Only
the selected building can be dragged (as in Clash); a drag on anything else pans the camera. A
building drag lifts the view, follows the finger with the grab offset, clamps into the grid and
colours the footprint by `state.check_move`; on release, if the cell changed, it applies
`{"op": "move", "id", "cell"}` and then re-syncs the view (which also drops a failed move back).
`upgrade_selected()` applies `{"op": "upgrade", "id"}`.

Pinches go to `camera.zoom_at`, two-finger pans and camera drags to `camera.pan`.

## BaseView (`base_view.gd`)

Draws the base and owns the cell ↔ world mapping: 1 cell = 1 world unit, the grid centred on
the origin, cell (x, y) on world (x, z).

| Method | What |
| --- | --- |
| `cell_to_world(cell, size)` | The world centre of a footprint whose top-left cell is `cell`. |
| `world_to_cell(point)` | The cell under a ground point (floor). |
| `footprint_cell_at(point, size)` | The top-left cell of a `size` footprint centred as closely as possible on a point (round). |
| `area()` | The buildable area as a `Rect2` in world x/z; the camera's bounds. |
| `sync(state)` | Makes `views` match `state.buildings`: frees views whose building is gone, changed type or has a new finished level (except the `dragging_id` view, which keeps its model until it is dropped), creates missing ones, pushes `show_status` to each, and for all but `dragging_id` sets the position, un-lifts, and shows the SELECTED tile on `selected_id`. |
| `set_grid_highlight(on)` | Brightens the ground's cell lines (`GRID_LINES_PLACING`) or dims them back (`GRID_LINES`); `PlacementController` calls it as placement begins and ends. |
| `clear()` | Frees every view (used when the state is replaced). |

`setup(size)` builds the scenery, one draw call per part, the terrain and rocks drawn from
`SeededRng.new(SCENERY_SEED)` (7) so every player's base sits in the same landscape:

- **The ground**: a `PlaneMesh` of the grid's size with `ground.gdshader`: the palette's
  regolith (`base_color`, from `Palette.color`) with a slight tone variation per cell and a cell
  grid whose `line_strength` is faint by default and brighter while placing; `grid_size` is a
  uniform.
- **The terrain**: one flat-shaded `ArrayMesh` annulus from the grid's edge out to
  ±`TERRAIN_EXTENT` (90) on a `TERRAIN_STEP` (2) lattice that includes both grid edges. Heights
  come from value noise, rise gently with distance and dip into three to five craters; along the
  grid's edge they are pinned to y = 0, so the terrain meets the ground with no seam. Faces are
  coloured by height band (regolith, darker regolith, rock, dark rock, crater floors) from the
  palette. It covers the view at the widest zoom with the focus anywhere on the grid, and casts no
  shadows.
- **The rocks**: `ROCK_COUNT` (40) irregular low-poly rocks merged into one mesh, sitting on the
  terrain, never inside the grid.

## BuildingView (`building_view.gd`) and BuildingModels (`building_models.gd`)

A `BuildingView` is one building's visual: the model for its finished level, a scaffold shown
instead while `level` is 0, a footprint tile (`Footprint.NONE / SELECTED / VALID / INVALID`, the
last three translucent cyan, green and red), and a billboard `Label3D` timer ("Building 10s",
"Lv 2 1m 00s") shown while busy. `setup(id, type, level, size)` builds it for one level (level
1's model while the level is 0); `building_level` records it, and `BaseView.sync` replaces the
view when the finished level changes, so a building mid-upgrade shows its current level until
the upgrade finishes. `show_status(level, busy, target_level, seconds_left)` is what
`BaseView.sync` pushes each tick. `set_lifted(true)` raises the model by 0.35 while it is
dragged or is the ghost. The node carrying `BuildingModels.SPIN_META` spins in `_process` while
the building is finished and idle; a view with nothing to spin turns processing off in `_ready`,
so walls and traps cost nothing per frame.

`BuildingModels.create(type, level, size)` returns a `Node3D` holding one static
`MeshInstance3D` and at most one spinning one (the radar, the drone, the drill, the harvester
arm, the siphon and gravity well rings, the flak and laser heads): at most two draw calls a
building. The models are flat-shaded low-poly, one per type and level of the 32-type roster;
`MODELS` gives each type the footprint its models are built for and its level count. A level
above that shows the top model, a catalog size other than the footprint scales the model, and
an unknown type gets a hull block with a hazard stripe and one warning. Meshes are built once
per type and level and cached in a static dictionary; the nodes are per view. Each category
shares a look (resources on square slabs, army halls and domes with big doors, defences on
octagonal plinths, traps nearly flush with the ground, walls as blocks); level 1 is plain, each
level adds a part or an accent, and the top level carries gold. Budgets: 500 triangles a model,
40 for traps and walls. `create_scaffold(size)` is one cached mesh in hazard colours. The
contract any model keeps, built or imported: origin at the footprint centre on the ground, +Y
up, fitting inside `size × size` cells.

## Palette (`palette.gd`) and LowPolyMesh (`low_poly_mesh.gd`)

`Palette` is the one colour table every low-poly mesh is painted from: about 25 named entries
(hulls, metals, white, window, paints, hazard yellow, gold, the glows, regolith, rock and
crater tones) laid out in 8×8 cells of an albedo `ImageTexture` generated at run time; the glow
entries also light their cell of an emission texture, and their albedo is darkened so the light
does not wash their hue out. `uv(name)` is a cell's centre, `color(name)` the colour itself (the
ground shader's), and `material()` the one shared `StandardMaterial3D` (albedo and emission
textures, nearest filtering, roughness 1) on every building, the terrain and the rocks. A
painted texture later changes this file only.

`LowPolyMesh` accumulates flat-shaded faces into one `ArrayMesh` surface: each face has its own
vertices and normal and UVs at one palette cell. Parts: `box`, `wedge`, `strut`, `prism`,
`cone`, `pyramid`, `dome`, `orb`, `ring`, `disc` and the general `lathe`, each placed by the
centre of its base (an orb's centre) and Euler degrees; `triangle` and `polygon` add single
faces (the terrain and rocks use them). Bottom faces are left out, since the camera always looks
down. `to_mesh()` returns the mesh with the palette material.

## Format (`format.gd`)

Display formatting shared by the views and the HUD: `amount(12345)` → `"12,345"`;
`duration(75)` → `"1m 15s"`, `duration(4000)` → `"1h 06m"`; `cost({"metal": 150})` →
`"150 Metal"`, an empty cost → `"Free"`.
