# Input and camera

How `src/game/` turns touches into commands and draws the base: `main.gd` (with `TemplateBase`),
`IsoCamera`, `WorldInput`, `PlacementController`, `BaseView`, `BuildingView`, `BuildingModels`
and `WallMesh`. The HUD is in `hud.md`; how the models, the ground and the scenery look (the
material kit, `LowPolyMesh`, the shaders, the outlines, the view states, the wall pieces) is in
`art-style.md`. This layer reads `BaseState` and never mutates it except through
`PlacementController.apply` calls (`CLAUDE.md`, **Architecture rules**).

## The scene (`main.gd`)

`scenes/main.tscn` is one `Node3D` with `main.gd`; everything else is built in `_ready`:

1. `Catalog.load_default()`; a non-empty `load_error` is pushed as an error and the scene stops.
   In a debug build (`OS.is_debug_build()`) without a `--no-cheats` user argument
   (`NO_CHEATS_ARG`), `cheats` is set and `catalog.apply_dev_cheats()` makes every level free
   and one second at most (`core-economy.md`); the HUD is told through `hud.cheats` (`hud.md`).
2. The environment: a `WorldEnvironment` (deep space background, cool ambient light, linear
   tonemap) and one warm key light, a `DirectionalLight3D` with a hard single-split shadow
   (`art-style.md`, **Light and shading**).
3. `BaseView` (ground, scenery, building views), `IsoCamera` (made current), `WorldInput`,
   `Hud`, then `PlacementController`, which is given the view, the camera and the clock
   (`placement.clock = _now`) and connected to the input signals.
4. The HUD's signals are wired to the controller (`build_pressed` → `begin_place`,
   `confirm_pressed` → `confirm_place`, `cancel_pressed` → `cancel_place`, `upgrade_pressed` →
   `upgrade_selected`, `close_pressed` → `select(0)`, `reset_pressed` → `_reset_base`,
   `template_pressed` → `_template_base`); the controller's `selection_changed` refreshes the
   HUD, `placing_changed` calls `hud.refresh_placing` (`_on_placing_changed`; a ghost move
   updates only the Place button), and `command_failed` shows a toast.
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
(the debug row's Reset base) creates a new base and saves at once.

**The template base.** `_template_base` (the debug row's Template base, `hud.md`) installs a
showcase base the same way and saves at once: `TemplateBase.build(catalog, grid, now)`
(`template_base.gd`) returns a save dictionary (`data-format.md`, **The save file**), loaded
through `BaseState.from_dict`. Every type in the catalog, hidden ones included, is there at its
top level and finished, grouped by category, and every resource is at the cap of the base as
laid out, which a throwaway `BaseState` works out. The bands are `core`, then
`catalog.categories` in tab order, from the top of the field (cell y 0) down; in a band, one of
each type, in `menu_order`, runs left to right from x 0 a cell apart, wrapping to a new row a
cell below the row's tallest footprint when the next would pass the field's right edge. The
walls band (`PlacementController.PAINT_CATEGORY`) is an enclosure of its first type instead,
`WALL_SIZE` (12×6) with a run from the middle of its top side to the middle of its bottom, so it
shows corners, T junctions and straight runs; it narrows to a narrower field. The layout is
checked on a `BaseGrid` as it is made: a building that does not fit is left out, with an error
naming the first, rather than overlap. The `template_base` harness scenario checks it
(`tools/harness/README.md`).

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
| `nudge(world_delta)` | Adds a world offset to `focus`, clamped like every move: the edge scroll's move. |
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
camera moves, selection, placement, wall painting and building moves, and scrolls the camera
while a drag nears the screen's edge.

| Member | What |
| --- | --- |
| `state`, `base_view`, `camera` | Set by `main.gd`. |
| `clock: Callable` | Returns the unix time in seconds for every command it applies; `main._now` in the game, the harness's clock under the harness. |
| `selected_id` | The selected building, `0` for none. `select(id)` updates the view's selection tile and emits `selection_changed`; a change of selection ends a building drag in progress with no move (a second finger can press Close or Reset base). |
| `placing_type` | The type being placed, `""` when not. `is_placing()`, `ghost_is_valid()`, `ghost_cell()` (the ghost's top-left cell, the brush's while painting). |
| `is_painting()` | Placing a one-cell type of `PAINT_CATEGORY` (`"walls"`): the ghost is a brush (**Painting walls**). |
| `signal selection_changed`, `signal placing_changed` | Selection changed; placement began, ended or the ghost moved. `main.gd` refreshes the HUD on the first and calls `hud.refresh_placing` on the second (`hud.md`, **Refresh**). |
| `signal command_failed(error)` | A command returned an error code; the HUD shows it as a toast. |

**Placing** (`begin_place(type)`): any placement is cancelled and the selection cleared; a
`BuildingView` with id 0 is created as the ghost (level 1's model), lifted, and the ground's
cell grid is brightened (`BaseView.set_grid_highlight`); its starting cell is the footprint
centred on the screen centre's ground point (the grid centre when the centre is off the ground),
moved to the nearest free spot searching outward in square rings (`_find_free_cell`). While
placing (walls are painted instead, below), a tap moves the ghost so the footprint is centred on
the tapped cell, and a drag that starts on the ghost carries it (with the grab offset); a drag
elsewhere pans. Every move (`_set_ghost_cell`) clamps the cell into the grid, asks
`state.check_place` and colours the footprint VALID or INVALID, and emits `placing_changed`.
`confirm_place()` applies `{"op": "place", "type", "cell"}` at `clock.call()`, and on success
ends placement and selects `state.last_added_id`; on failure emits `command_failed`.
`cancel_place()` ends a ghost or paint drag in progress (a second finger can press Cancel or
Done), frees the ghost and dims the grid again. `refresh()` re-checks the ghost after the state
changed (resources, builders).

**Painting walls.** `begin_place(type)` of a one-cell type whose `category_of` is `"walls"`
enters paint mode: the ghost is a brush (a larger type of that category places normally). A tap
places a wall on the tapped cell at once, through the same `place` command, and moves the brush
there. A one-finger drag that starts on the grid is `Drag.PAINT`: it places a wall on the cell
it starts on, then on every cell the finger crosses, walking the straight line between two drag
events one orthogonal step at a time (`_paint_to`), so a fast drag leaves no gap and a diagonal
one is a staircase of touching walls. A drag that starts on the terrain around the grid pans,
and a two-finger pan still pans. A taken cell is skipped quietly (`blocked`); any other failure
(`insufficient_resources`, `limit_reached`) emits `command_failed` once a stroke, not once a
cell, and painting stays on, so the next stroke may succeed. The brush stays at the last cell
the finger reached. The cell under it is usually the wall it just placed, so its footprint
follows `check_can_build(type)`, not `check_place`: VALID while another wall can be built,
INVALID when out of metal or at the count limit; `ghost_is_valid()` reports the same while
painting. New walls are not selected. There is nothing to confirm: `confirm_place()` (the HUD's
Done) and `cancel_place()` both end the mode, and the walls stay.

**Selecting and moving.** A tap on a building selects it, a tap on empty ground deselects. Only
the selected building can be dragged (as in Clash); a drag on anything else pans the camera. A
building drag re-syncs the view as it starts (so a lifted wall leaves the merged wall mesh at
once, **Walls**), lifts the view, follows the finger with the grab offset, clamps into the grid
and colours the footprint by `state.check_move`; on release, if the cell changed, it applies
`{"op": "move", "id", "cell"}` and then re-syncs the view (which also drops a failed move back).
`upgrade_selected()` applies `{"op": "upgrade", "id"}`.

Pinches go to `camera.zoom_at`, two-finger pans and camera drags to `camera.pan`.

**Edge scroll.** A still finger sends no events, so the controller keeps the last finger
position of a `Drag.GHOST`, `Drag.BUILDING` or `Drag.PAINT` drag and runs `_process` only while
one is active (`set_process`, off in `_ready` and when the drag ends). Each frame, with the
finger within `EDGE_MARGIN` (8%) of the viewport's shorter side from an edge, the camera's
focus moves toward that edge's side through `camera.nudge`, so the view reveals what lies beyond
it: the depth into the margin (0 at its inner side, 1 at the edge, per axis, so a corner scrolls
diagonally) times `EDGE_SCROLL_SPEED` (0.6) viewport widths a second, a screen distance turned
into a ground offset, so the speed scales with zoom.
When the cell under the finger changes, the drag is followed again through the drag-event path
with a zero delta, so the ghost, the lifted building or the brush stays under the finger as the
world slides (and the brush paints the cells it reaches). A frame where that cell is unchanged
calls nothing in core and allocates nothing.

## BaseView (`base_view.gd`)

Draws the base and owns the cell ↔ world mapping: 1 cell = 1 world unit, the grid centred on
the origin, cell (x, y) on world (x, z).

| Method | What |
| --- | --- |
| `cell_to_world(cell, size)` | The world centre of a footprint whose top-left cell is `cell`. |
| `world_to_cell(point)` | The cell under a ground point (floor). |
| `footprint_cell_at(point, size)` | The top-left cell of a `size` footprint centred as closely as possible on a point (round). |
| `area()` | The buildable area as a `Rect2` in world x/z; the camera's bounds. |
| `sync(state)` | Makes `views` match `state.buildings`: frees views whose building is gone, changed type or has a new finished level (except the `dragging_id` view, which keeps its model until it is dropped), first handing a view's construction drone to the base view (`release_drone`) and, once the views are made, telling it to leave over the new view's site (`site_height()`), creates missing ones, pushes `show_status` to each, and for all but `dragging_id` sets the position, un-lifts, and shows the SELECTED tile on `selected_id`. Last it brings the merged wall mesh up to date (`_sync_walls`, **Walls**). |
| `walls` | The `WallMesh` that draws every finished wall but the dragged one. |
| `set_grid_highlight(on)` | Brightens the ground's cell lines (`GRID_LINES_PLACING`) or dims them back (`GRID_LINES`); `PlacementController` calls it as placement begins and ends. |
| `clear()` | Frees every view (used when the state is replaced). |
| `terrain`, `boundary`, `rocks`, `outcrops` | The scenery's body instances, each with its ink outline beside it (`terrain_outline`, `boundary_outline`, `rocks_outline`, `outcrops_outline`), which casts no shadow. |
| `craters`, `mesas`, `outcrop_spots` | The terrain's craters as (x, z, radius) and mesas as (x, z, radius, top height), and each crystal outcrop's centre on the ground. |

`setup(size)` builds the ground and the scenery once; the terrain, the rocks and the outcrops are
drawn from `SeededRng.new(SCENERY_SEED)` (7) in that order, so every player's base sits in the
same landscape. How each looks is in `art-style.md`, **Environment**:

- **The ground**: a `PlaneMesh` of the grid's size, flat at y = 0 (the camera picks against that
  plane), with `ground.gdshader` on the field texture (`assets/textures/field.png`, an atlas of
  four tiles loaded as an `Image` and mipmapped here) and the field's colour roles: one seamless
  plain, laid with the tiles each turned its own way, with inked craters, pits, pebbles, shards and
  cracks lit from `SUN_ACROSS`, and a cell grid whose `line_strength` is faint by default and
  brighter while placing; `grid_size` and `sun_across` are uniforms.
- **The perimeter** (`boundary`): a concrete kerb round the field, `CURB_GAP` (0.3) outside its
  edge, with a pylon every four cells and on each cut corner and a low rail-and-hologram fence
  between them (`art-style.md`, **Environment**); its body casts a shadow.
- **The terrain**: one smooth-shaded, indexed `ArrayMesh` from the field's edge out to
  ±`TERRAIN_EXTENT` (100), on a lattice of 1 unit within `TERRAIN_FINE_REACH` (50) of the centre
  and of `TERRAIN_COARSE` (2) beyond, cut to half a unit within `TERRAIN_MESA_REACH` (3) of a
  mesa's outline, drawn by `terrain.gdshader` (`MaterialKit.terrain()`, given the ground's field
  texture), whose inner edge lies on the field's at y = 0, so the two
  meet with no seam; it is within 0.03 of flat under the curb, reaches its relief between 4 and 11
  units out, wandering along the edge, and is roughened by a low rubble from 0.8 out.
  Its craters, mesas, channel and dunes are placed from the seed; it has its ink outline, receives
  shadows and casts none. `terrain_height(x, z)` is its height function, which the harness
  marches the view's rays over, and `blend_end(x, z)` how far out from the field its relief is full
  there, which the harness checks wanders along each side. At the widest zoom it fills the view
  with the focus anywhere on the grid on every aspect up to about 2.98:1 (a 19.5:9 phone is
  2.17:1); beyond that the clear colour shows.
- **The rocks**: `ROCK_COUNT` (80) chamfered rocks, some stacked, on the terrain clear of the
  curb, and `RUBBLE_ROCKS` (36) small ones strewn round the field 1.6 to 6.6 units out, all in one
  mesh with its outline.
- **The outcrops**: six to ten clusters of glowing crystal shards in one mesh with its outline,
  never within `OUTCROP_GAP` (4) of the field.

## BuildingView (`building_view.gd`) and BuildingModels (`building_models.gd`)

A `BuildingView` is one building's visual: the model for its finished level, a scaffold shown
instead while `level` is 0, a footprint tile (`Footprint.NONE / SELECTED / VALID / INVALID`, the
last three translucent cyan, green and red), and a billboard `Label3D` timer ("Building 10s",
"Lv 2 1m 00s") shown while busy, in the HUD's Lilita One (`Hud.BODY_FONT`, the same resource) and
text colour with an ink outline about 2 px wide at the starting zoom. A wall drawn by the merged
wall mesh hides its model
(`set_merged(true)`, **Walls**) and keeps the rest; `is_model_visible()` says whether the view
draws its own model. `setup(id, type, level, size)` builds it for one level (level 1's model
while the level is 0); `building_level` records it, and `BaseView.sync` replaces the view when
the finished level changes, so a building mid-upgrade shows its current level until the upgrade
finishes. `show_status(level, busy, target_level, seconds_left)` is what `BaseView.sync` pushes
each tick. `set_lifted(true)` raises the model by 0.35 while it is dragged or is the ghost. A
selected or dragged view's outlines turn gold; the placement ghost keeps plain ink outlines, and
its body takes the valid or invalid tint through `set_ghost(valid)` (`art-style.md`, **View
states**). The nodes carrying `BuildingModels.MOVE_META` (a `Motion` each) are collected once
in `setup`; `_process` sets each one's transform from `Motion.transform_at` on a clock that runs
only while the building is finished and idle, without allocating, so they stop during an
upgrade and resume where they stopped (the surface effects keep running: they come from the
shaders' `TIME`); a view with nothing to move turns processing off in `_ready`, so walls and
traps cost nothing per frame.

While the building is busy a `ConstructionDrone` works over the site (`art-style.md`,
**Construction drone**): `show_status` creates one the first time it reports `busy` with none
there, over the scaffold on a first build and over the model on an upgrade (an instant build is
never busy and gets none), and tells it to `leave(site_height())` once it reports the building
not busy. The view turns processing on while it has a drone and drives it from `_process`
(`advance(delta)`); when the drone has left and freed itself the view drops it and processes
only if something moves. A finished level replaces the view, so `BaseView.sync` first calls
`release_drone`, which re-parents the drone to the base view, where it keeps its place in the
world and drives itself; once the new view exists, `sync` tells it to leave over that view's
site (`site_height()`, the top of the scaffold or the model it shows), so its climb starts clear
of the finished model, and it frees itself after its climb. `drone()` returns the view's drone
(null when none), for the harness. `BaseView.clear()` frees the drones with the views.

`BuildingModels.create(type, level, size)` returns a `Node3D` holding the static body and its
ink outline, and up to three moving parts (the model table in `art-style.md` names each
type's: dishes, radars and gyro rings that spin, heads and launchers that scan, press arms,
doors and cranes that slide) with their outlines, each under a pivot node carrying `MOVE_META`:
at most eight `MeshInstance3D`, half of them at most outlines that cast no shadow
(`art-style.md`, **Animation**).
The models are built in code, one per type and level of the 32-type roster, each type's in its
category's file under `src/game/models/`; `MODELS` gives each type the footprint its models are
built for and its level count. A level above that shows the top model, a catalog size other than
the footprint scales the model, and an unknown type gets a hull block with a hazard stripe and
one warning. Meshes are built once per type and level and cached in a static dictionary; the
nodes are per view. `create_scaffold(size)` is one cached, outlined model in hazard stripes;
`create_drone()` and `create_drone_effect(part)` build and cache the construction drone and its
laser's beam and flare the same way. How a
model is built and what it must keep (the contract, the budgets, the vocabulary) is in
`art-style.md`, **Models**.

## Walls (`wall_mesh.gd`)

Finished walls are not drawn one model each: they are one merged mesh, a `WallMesh` that
`BaseView` owns, in which each wall is the piece of its level and neighbour mask, a post plus a
half-segment toward each orthogonal neighbour that is also a finished wall (the pieces, the mask
bits and the look per level are in `art-style.md`, **Walls**). Two adjacent walls meet on their
shared edge and each draws its own level's style, so a painted line reads as one barrier and
corners, T-junctions and crossings close. Walls connect four-connected, at any levels, never
diagonally; a wall under upgrade keeps its finished level's piece.

| `WallMesh` member | What |
| --- | --- |
| `body`, `outline` | Its two `MeshInstance3D`: the pieces' bodies and their ink outlines. The outline casts no shadow. |
| `draws(catalog, building)` | Static: whether the merged mesh draws a building, a wall (category `PlacementController.PAINT_CATEGORY`, `"walls"`) with `level >= 1`. Every type of that category is drawn as barrier pieces, so it must be 1x1. |
| `rebuild(state, skip_id)` | Collects every wall `draws` accepts but `skip_id`, computes each one's mask from the others' cells, and appends each piece's body and outline arrays, moved to its cell, into one `ArrayMesh` for each. The copy is the engine's bulk calls (`Transform3D * PackedVector3Array`, `append_array`), nothing per vertex in script. |
| `mask_at(cell)` | The mask of the wall drawn on a cell at the last rebuild, `-1` when none is. |

`BaseView.sync` ends with `_sync_walls`: every wall view the mesh draws gets
`BuildingView.set_merged(true)`, which hides its model but keeps the footprint tile, the label
and the lift; then the walls drawn, each `(x, y, level)` packed into a `PackedInt64Array` in id
order, are compared with the last rebuild's, and the mesh is rebuilt only when they differ (a
wall placed, moved, upgraded or lifted), never on the one-second tick alone. The rebuild is
deferred to the end of the frame, so a fast paint stroke that places several walls in one drag
event rebuilds once. The dragged wall (`dragging_id`) is the exception: the mesh skips it and
its view gets `set_merged(false)`, so its own post follows the finger, lifted with gold outlines
like any dragged building, while its neighbours lose their joints. The drag's start re-syncs the
view (`PlacementController`, **Selecting and moving**) and the drop's sync adds it back. A
selected wall's gold outlines belong to its hidden model, so a merged wall shows its footprint
tile only. The merged mesh costs a fixed handful of draw calls (the body, the outline, the
body's shadow) however many walls there are.

## Format (`format.gd`)

Display formatting shared by the views and the HUD: `amount(12345)` → `"12,345"`;
`duration(75)` → `"1m 15s"`, `duration(4000)` → `"1h 06m"`; `cost({"metal": 150}, catalog)` →
`"150 Metal"`, each resource named by `catalog.resource_name`, an empty cost → `"Free"`.
