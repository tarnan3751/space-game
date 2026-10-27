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
tools/harness/run.sh place_and_build --timeout 60    # fail if still running after 60 s
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
- A rendered run fails when any screenshot is byte-identical to any earlier one, so a window
  that stops drawing part-way is caught too. A shot meant to show that nothing changed is taken
  with `screenshot(name, true)`: the log line ends in `(may repeat)` and `run.sh` exempts it.

A run exits 0 only when every `check()` passed, Godot logged no `SCRIPT ERROR`, and no rendered
screenshot repeats an earlier one unless it may. The last lines of `log.txt` are `HARNESS PASS:
<scenario>` or `HARNESS FAIL: <scenario>, N failed check(s)` followed by each failed check. A
scenario that does not parse ends the run at once with `HARNESS FAIL: <scenario>, script failed
to load` and exit code 1. A watchdog ends a scenario still running 300 seconds after it started
(the driver's `HARNESS_TIMEOUT_SECONDS`; `--timeout <s>` sets another) with `HARNESS FAIL:
<scenario>, timed out after N s (last check: <message>)` and exit code 1, so one awaiting a
signal that never comes cannot hang the run; the longest real run, `battle_view`, takes under two
minutes. A runtime error inside `run()` ends the scenario where it happened;
Godot logs it as a `SCRIPT ERROR`, which fails the run in `run.sh`.

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
| `main.placement` | `begin_place(type)`, `confirm_place()`, `cancel_place()`, `select(id)`, `upgrade_selected()`, `train(id, unit)`, `cancel_training(id, unit)`, `research(unit)`, `make(id, ability)`, `cancel_making(id, ability)`, `research_ability(ability)`, `scan()`, `raid_result(setup, result, expedition)`, `is_placing()`, `is_painting()`, `ghost_is_valid()`, `ghost_cell()`, `selected_id` |
| `main.world_input` signals | `tapped`, `drag_started`, `dragged`, `drag_ended`, `pinched`, `panned`; emit them to simulate a gesture (`tap_cell` below does) |
| `main.hud` signals | `build_pressed`, `confirm_pressed`, `cancel_pressed`, `upgrade_pressed`, `close_pressed`, `reset_pressed`, `template_pressed`, `practice_pressed`, `train_pressed`, `cancel_training_pressed`, `research_pressed`, `make_pressed`, `cancel_making_pressed`, `research_ability_pressed`, `expedition_pressed`; emit them to press a button |
| `main.hud` queries | `build_button()`, `is_menu_open()`, `build_panel()`, `close_button()`, `tab_button(category)`, `entry_button(type)`, `entry_status(type)`, `entry_preview(type)`, `previews_done()`, `entry_strip()`, `resource_panel(res)`, `resource_fill(res)`, `place_button()`, `drones_panel()` (the `DroneRing`: `free_count()`, `total_count()`), `reset_button()`, `template_button()`, `practice_button()`, `action_button()`, `army_panel()`, `is_training_open()`, `is_research_open()`, `army_close_button()`, `army_title()`, `housing_text()`, `housing_bar()`, `housing_fill()`, `train_card(unit)`, `train_card_info(unit)`, `queue_shown()`, `queue_entry(index)`, `queue_head_status()`, `research_card(unit)`, `research_card_lines(unit)`, `research_line()`, `is_making_open()`, `make_card(ability)`, `make_card_info(ability)`, `research_ability_card(ability)`, `research_ability_card_lines(ability)`, `info_detail()`, `toast_text()`, `expedition_button()`, `expedition_badge()` (`docs/reference/hud.md`); `apply_safe_area(inset)` to try a notch-like inset |
| `main.state` | the `BaseState`: `buildings`, `resources`, `capacity()`, `builders_free()`, `seconds_left(id)`, `check_*` |
| `main.camera`, `main.base_view` | `IsoCamera` and `BaseView`, for cell and screen mapping |
| `main.sector_map` | the `SectorMap`: `open(state)`, `close()`, `show_field(index)`, `is_open()`, `is_detail_open()`, `detail_index()`, `detail_field()`, `card(index)`, `card_cleared(index)`, `card_lines(index)`, `scan_button()`, `close_button()`, `attack_button()`, `hint_shown()`, `minimap()` (`drawn()`, `walls_drawn()`), `card_thumbnail(index)`, `layouts_done()`, its signals `scan_pressed`, `attack_pressed`, `closed`; `main.open_sector_map()` (`docs/reference/hud.md`, **Sector map**) |
| `main.open_battle(setup, practice, expedition = {})`, `main.practice_setup()`, `main.battle`, `main.battle_hud` | a battle in the base's place and its `BattleView` while it runs: `sim` (read only), `script_commands(list)`, `deploy(unit, cell)`, `select_unit(unit)`, `surrender()`, `leave()`, `speed`, `deploy_unit`, `is_masked(cell)`, `input` (its own `WorldInput`), `field` (its `BaseView`, `deploy_strength()`), `units`, `step_ms()`, `slowest_tick()`, `clock()`, `finished` (`docs/reference/battle-view.md`); and its `BattleHud`'s queries (`docs/reference/hud.md`, **Battle HUD**) |

Helpers on `HarnessScenario`:

- `check(condition, message)` — records a failure and carries on, like the tests' asserts.
- `say(text)` — a line in `log.txt` and on stdout.
- `now()` — the harness clock in unix seconds.
- `advance(seconds)` — moves the clock and calls `BaseState.advance_to`, as the game's tick
  does; construction finishes and production is paid exactly as it would over real time.
- `await frames(n)` — waits `n` frames, so the views and the HUD catch up with a state change
  before a screenshot or a check of a view.
- `await screenshot(name, may_repeat = false)` — saves `NN-name.png` in a rendered run, logs a
  skip headless. `may_repeat` exempts the shot from the guard against repeated frames.
- `await strip(name, count, step_ms, crop = false)` — a frame strip: `count` frames of the window about
  `step_ms` of real time apart, each downscaled to 640x360 and laid out in reading order four to
  a row, saved as one `NN-name.png` numbered with the screenshots. A frame is taken on the first
  frame at least `step_ms` less 4 ms after the last (the driver's `STRIP_EARLY_MS`), so the log
  line, `strip NN-name.png (8 frames, 100 ms, 0 identical; camera size 7.0; gaps 100 99 ... ms)`,
  gives the gaps measured, the camera's size and how many frames were byte-identical to the one
  before: a still subject or a stalled one, a signal for whoever reads the strip. Frames inside a
  strip may repeat; the composed PNG is one shot to the guard against repeated frames, like a
  screenshot. `crop` takes the centre half of the window each way instead of the whole (the log
  line says "centre half"), twice the pixels on a close subject. A count under 1 fails a check
  and saves nothing. Headless runs log and skip it.
- `fix_clock(time)`, `release_clock()` — holds the animation clock (`Motion.clock()`, and through
  `main.gd` the shaders' `anim_time`) at `time` seconds from the next frame on, so every moving
  part and surface effect stands at that moment, the same in every run and on every tree: two
  trees' shots at the same fixed clock compare pixel for pixel. A strip under a fixed clock
  repeats its frames. `release_clock()` lets it run on real time again.
- `frame_world(main, size, world_pos)` — sets the camera to `size` with `world_pos` at the
  screen's centre, the framing every close-up shares. A size under the camera's own closest zoom
  (`IsoCamera.MIN_ZOOM_SIZE`, 10) is set directly, as no gesture can, so a unit can be framed at
  size 4 to 8.
- `frame_span(main, a, b, margin, minimum, crop = false)` — frames two world points together:
  the camera centred between them, sized so the strip's tile shows their projected span (the
  larger of its height and its width over the screen's aspect) plus `margin`, and at least
  `minimum` high; twice that for a strip that will crop (`crop`). Returns the size set.
- `await frame_settled(main, size, world_pos, seconds, count)` — `frame_world`, then waits
  `seconds` and `count` frames, so the window (a frame or more behind the scene) has caught up
  before a shot.
- `zoom_to(main, size, world_pos, share = Vector2(0.5, 0.5))` — zooms to `size` about the
  screen's centre and pans `world_pos` to the screen's `share` (its centre by default) through
  the calls a pinch and a drag make (`IsoCamera.zoom_at`, `pan`), so the size stays within the
  camera's own zoom range, unlike `frame_world`.
- `await shot_at(main, name, at, size)` — `zoom_to` on `at`, then the screenshot `name` six
  frames later.
- `await wait_seconds(main, seconds)` — waits `seconds` and 50 ms more, then two frames: a timed
  HUD change (a panel sliding, a toast) has finished and drawn.
- `tap_cell(main, cell)` — emits `WorldInput.tapped` at the screen position of a cell's
  centre, so `PlacementController` handles it exactly as a real tap.
- `touch_screen(main, point, pressed)`, `await tap_screen(main, point)` — a finger down or up,
  and a tap (down, two frames, up, two frames), at a point in the HUD's coordinates, through
  `Input.parse_input_event` as a real touch arrives (mapped through the viewport's final
  transform), so the HUD's controls take it before the world does.
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

`scenarios/format.gd` checks `Format` (`docs/reference/input-camera.md`, **Format**): durations
from seconds to days ("45s", "1m 15s", "18h 30m", "2d 18h", and the edges between them), amounts
and the meters' short form, each against its text. Headless; it acts on nothing in the game.

`scenarios/battle.gd` runs the battle sim on the real data (`docs/reference/battle.md`): the
five of the eleven unit types (100 Rangers, 40 Brawlers, 20 Jet Troopers, 5 Hover Tanks and 2
Gunships, the Hangars' 280 housing) at their top levels, deployed in three groups on the
template base (`TemplateBase`), two in the open pockets it leaves inside and one below it, with
one Orbital Strike at its top level called at tick 40 on the template's first defence (stepped
to its landing in a second copy, which must show the defence's hull lowered), run
to the end and logged (battle seconds and ticks,
destruction, stars, loot, and the wall time of the run, which the scenario reads as the
performance budget's measure, never the sim); each tick's step is timed in both runs and the
faster kept, and the slowest tick must be under 2.0 ms (`TICK_BUDGET_MS`, the searches' 300 cells
a tick and a deploy wave with room to spare), logged rather than failed while the average tick says the machine is loaded
(over 0.4 ms); the same setup run again must repeat its result and hash, and the result applied with `raid_result` to a copy of the game's base given the
army and the strike must spend the units deployed and the strike and bring the loot home up to
storage. `main.state` itself
is untouched, since no player action leads to a raid yet. Headless; no screenshots.

`scenarios/expedition.gd` runs an expedition on the real data
(`docs/reference/expeditions.md`): a copy of the template base with a fixed sector seed lays out
its six fields, each logged (band, outpost level, counts, rings, deposits, hazards, loot, and the
wall time, read in the scenario, never in the generator) and checked to drop nothing and to set
up a battle; the battle scenario's army attacks the even field from the middles of the four
edges, and the result is applied with `raid_result` and the expedition key: the field must be
cleared exactly when the attack took a star (which one it gets is the development balance's, so
it is logged), and the raid logged with the field's inputs, not its layout; then the first scan
must start epoch 1 with every field new and the next scan wait. `main.state` is untouched.
Headless; no screenshots.

`scenarios/make_abilities.gd` drives the Foundry's HUD (`docs/reference/hud.md`, **Making panel**,
**Research panel**) on the Template base: the Nanite Foundry selected by a tap, its info panel's
"Stock N / C" line and Make; the making page's cards in stock 0; two abilities queued from their
cards, paid for and shown in the queue strip with the head's time; the newest cancelled from the
strip and refunded; the first made into the stock, on its card and on the stock line; then the
Research Lab's research page with the abilities after the units, the Repair Swarm's level 2
researched from its card, paid for and on the progress line, a unit's research refused while it
runs, and the level reached. Screenshots: the info panel, the making page, the stock, the research
page scrolled to the abilities.

`scenarios/expedition_flow.gd` drives the expedition flow in the game (`docs/reference/hud.md`,
**Sector map**; `docs/reference/battle-view.md`, **Expeditions**) on the debug build's Template
base, pressed through its button, its sector seed set to 20261024 so the run repeats. A second
finger is held on the world as the Expedition button is pressed and lifted while the map is open.
The Expedition button, its badge counting six open fields, opens
the sector map with the world's input out of the tree; the first scan is free and starts epoch 1,
Scan then counts down and a scan pressed while it recharges is refused with "The scanner is still cooling down", and once the harness clock has
moved through the cooldown (`advance`) Scan reads "SCAN" again;
each card shows its field's band and outpost, and, once the six fields are laid out, its outpost's
thumbnail. The easy field's card opens its detail, whose field
is the generator's layout and whose minimap draws every building but the walls (drawn apart) and the
traps; Attack with the Hangars empty is refused with "Train some units first". Then `main.state` is
given the battle scenario's army at its top levels, one of the first ability in stock and half of
every storage (set directly, as the
`expedition` scenario sets its copy's: training 167 units would take its real time), and Attack
opens the battle: the map closed, the field's seed the landscape's, and every defender building's
toon body and the merged walls on `MaterialKit.rival` (or, for the moment of a hit,
`hit_flash_rival`) while nothing else in the battle carries it, checked at the start and at tick
300, and the battle brings the army and the stock at their levels. The army is deployed in four
waves from the middles of the field's edges through
`script_commands` and run at 2x to its end, and the result panel's Return (`BattleHud`) leaves it.
Back on the base it checks the raid applied and logged
with the field's inputs, the field cleared exactly when a star was taken (which it gets is the
development balance's), the deployed units spent, the loot banked up to storage, the toast (the
stars and what came home), and the map open again with the card stamped and disabled; for a cleared
field, that its detail does not open and that its result applied again is refused with "That
expedition does not add up". Close gives the world its input back, the first real tap on the world after it is a
tap (the finger held at Expedition forgotten), and the badge counts the fields still open. Then the
green faction at Command Center 10: the even field's battle (Command Center 10, one EMP burst in
stock) opened tinted, shot at its start paused and framed on its buildings' middle at camera size
26; the EMP cast on a defence, every defender body checked still on a rival material while the
disabled ones are grey (`disabled_rival`) and again once they wake; then ended; and the
practice raid on the template opened with no tint anywhere and shot the same way. Rendered, the
share of the shots' middles (800×400, clear of the HUD) in the green band (hue 0.17 to 0.47,
saturation 0.35 and value 0.25 at least) must be at least twice the practice's and 0.03 above it;
both are logged (about 0.24 against under 0.01). Screenshots: the map with its thumbnails, the
detail with its minimap, the battle at tick 300 framed on the outpost's Command Center, the map
after it, the even field tinted and the practice. About 100 s headless.

`scenarios/battle_view.gd` drives the battle view and its attack HUD
(`docs/reference/battle-view.md`, `docs/reference/hud.md`, **Battle HUD**) on the debug build's
Practice raid: the Practice raid button with the Hangars empty is refused with its toast; then the
practice setup on the template base, given the battle scenario's army at its top levels and a seed
other than the base's (the field checked to stand in another landscape), is opened through
`main.open_battle` (the base's view and input out of the tree, its HUD hidden, the `BattleHud` shown
with the first card selected and the red zone up). Through the HUD: the Ranger's card, a tap
deploying one, a tap in the zone refused with "Can't deploy there", a drag over four cells deploying
one a tick. The rest of the army goes down in the battle scenario's three groups from tick 60, each
spread over the deploy cells within two of its point, sent live through `script_commands`. Rendered
only, once the whole army is down, the battle is paused (`speed` 0) and measured at the widest zoom
in a 1600×900 window, as `template_base` measures the base: the draw calls, primitives and render
CPU a frame against the same ceilings (1,600, 2.1 million, 6 ms), with the slowest frame's process
time, the frame rate and the units drawn. At tick 200, through the abilities bar (two of each
ability brought): the orbital strike cast on the nearest defence (its marker, its blast, the
defence's hull down after it lands), an EMP burst on the standing defence farthest from the army
(disabled in the sim and dimmed), a repair swarm on a living unit (its dome), the cards counting
down. Then the top bar checked against
the sim, the speed button to 2x, at tick 1,000 End, Keep fighting, End again and End battle, the
result panel in the deploy bar's place, and Return. Screenshots: tick 0, the smear, tick 200, the
strike's marker and blast, the EMP, the swarm, tick 1,000, the confirmation, the result panel and
the base after it. It checks the sim's step under 5 ms on average and logs its longest and the tick
it fell on; the result against a headless `BattleSim.run` of the setup with the commands the view
sent (equal text, hash included); every unit deployed; the result panel's abilities used; something
fallen; the base back with the toast "Practice: nothing applied", the camera where it was and its
save as it was but for its clock. About a minute headless, under two rendered.

`scenarios/model_gallery.gd` shows every building model: one `BuildingView` per type and level
in the catalog, laid out on the grid in rows by category (`"core"`, then
`catalog.categories`), under a node of its own, with the base's own views hidden. The roster
does not fit on the grid at once, so rows that do not fit start a new page. Each page gets an
overview screenshot (at the widest zoom, held for 2.1 seconds so that the frame rate, which
counts the last whole second, covers one with the page already set up, after which it says the
draw calls, the frame rate and the render thread's CPU time for the frame there), each row a
close-up at camera size 20, in even parts no wider than 20 cells (`ROW_PART_CELLS`; a part holds
the models whose centres fall in it), and each row's first building a detail shot at the closest
zoom (camera size 10), where outlines, bands and textures can be read; all are framed through
`camera.zoom_at` and `camera.pan`. Each close-up and detail shot checks, in both modes, that
every model in it has its footprint's corners and its top on the screen and outside the Build
button. The frame rate is only meaningful when
nothing else is loading the machine.
In both modes it checks every model, built for its level's tier (`BuildingModels.tier_of`): one
body `MeshInstance3D` and up to `Parts.max_moving(tier)` more (the moving parts that stay nodes:
three at most, four at Crown; the folded ones are in the body), each with an outline instance beside it on `MaterialKit.ink()` that casts
no shadow, unless every vertex of it carries a flag that is never outlined (`Surf.NO_OUTLINE`:
FLICKER, JITTER, HOLO); no vertex's kit layer (`UV2.x`) beyond the kit's last; the body
triangles, every surface counted, within the budget for its footprint and tier
(`docs/reference/art-style.md`, **Budgets**: at Base and Gold 600 for 1x1, 2,000 for 2x2, 3,000
for 3x3, 5,000 for 4x4 and 5x5, 250 for a wall piece, rising at Chrome, Obsidian and Crown); its
reach in x and z within half its footprint plus
0.15 units (`EXTENT_SLACK`): the static body's bounds, and each moving part's reach over its
whole motion, at the model's scale, a part folded into the body read back from its vertices'
`CUSTOM0` and `CUSTOM3` (`Motion.from_channels`). A SPIN part's vertices sweep circles about its axis (each
reaches its circle's centre's offset plus its radius from the pivot, so the part reaches the
pivot's x plus that in x and the pivot's z plus that in z);
a SWING part's bounds are turned every 5 degrees from -amplitude to +amplitude, both ends
included; a SLIDE part's are shifted to both ends. A failure says by how much it reaches over.
And its top within its height cap, 7 units for the Command Center and 5 for every other type:
the body's bounds, and each moving part's bounds' corners over its whole motion (turned every 5
degrees through a SPIN's whole turn or a SWING's range, shifted to a SLIDE's ends). Each model's
line names its tier, its budget and its top. For the Command Center it also checks that the dome with its gold ring,
and from L8 the ring hovering over it, reach no further out than the lip of the storey they ride
(`CoreModels.dome_fit`), its line saying the three radii.

`scenarios/model_clash.gd` is the clash rule's check (`docs/reference/art-style.md`, **The clash
rule**), headless, with no screenshots. For every type and level in the catalog, built for its
level's tier as the gallery builds it, and for every unit type at Base and at Crown
(`UnitModels.create`, as `unit_gallery` builds it), it reads back the static body and each moving part (each
node carrying `BuildingModels.MOVE_META`, and each part of the body that moves in the shaders,
`Surf.MOVE`, as a part moving about its pivot as `Motion.from_channels` decodes it from `CUSTOM0` and
`CUSTOM3`: a building's idle parts folded into its body, the gunship's rotors), every surface, holograms included, and tests whether
an edge of one's triangles crosses a triangle of the other (`Geometry3D.segment_intersects_triangle`),
only inside the overlap of their posed bounds and through a spatial hash of 0.25-unit cells. Every
pair of moving parts is posed together on the clock, as `BuildingView` poses them
(`Motion.transform_at`): sampled at the smaller step of the two (a SPIN every 10 degrees, a
SWING's period over 16, a SLIDE's over 8) over the longer cycle, or the turn of one SPIN
against another about a parallel axis, at most 60 seconds; any crossing fails the model, its
line naming the pair, the time and the point. Each moving part is also posed against the body,
a SPIN every 10 degrees, a SWING at nine poses and a SLIDE at five from -amplitude to
+amplitude, and the poses at which it touches the body are counted on its line but never
failed: a built-in mount, a pivot sunk in the body, is allowed contact, and telling a mount
from a clash is the review's call. A second pass applies BOB wherever either side has it, each
flagged vertex lifted along Y as `effects.gdshaderinc` lifts it (0.08 times the sine of the
2.4-second period plus its phase), on the clock with the parts' poses, at least eight samples a
BOB period: a pair crossing there fails too, and the body's are counted. A moving part that rides
another (`BuildingModels.RIDES_META`, `Parts.riding`) is posed on the clock carried by it, as
`BuildingView` carries it, and is not paired with it: its poses touching it are counted ("on its
carrier"), as a mount's with the body. An aiming part (one with a `muzzle` socket) is also turned
through a whole turn about +Y, every 10 degrees, about its pivot or the pivot of the part it
rides (which turns it), and, when it pitches (a `trunnion` socket), at every 10 degrees of its
travel (`BattleView.PITCH_LIMITS` or `LOB_ELEVATION`), both ends included, at each, against the
body, its touching poses counted as its "aim sweep", never failed: battle turns it anywhere. A
pitching part's poses across its travel are also tested against the part that turns it (turned
with it) and every other moving part (one riding the same carrier turned with it, any other at rest; one riding the
pitching part moves with it and is left out), counted per part as its "pitch sweep": the laser
turret's and the flak cannon's barrels against their head, which they are mounted in, touch at
every pose; the barrels against the flak cannon's radar, the railgun's rails against its ring and
the mortar's barrel against its loader arm, and the orbital cannon's gun against its mount and the
spire turning with it, are what the review reads. The last line says the
models, moving parts and pairs and how many pairs crossed: every model of the roster passes, with
no pair crossing. The whole roster takes about half a minute.

`scenarios/model_audit.gd` lists geometric defects and triangles never seen, for a fix pass; its
checks are informational, so it fails only on a script error. Headless, it builds every building
type at every level for its level's tier, every unit type at every tier near and far
(`UnitModels.build` at detail 1 and `UnitModels.FAR_DETAIL`), and the colonist and the automaton at
stance, reads back the body and each moving part, and splits each into parts: triangles joined
across an edge exactly two triangles of one surface share, so a part stacked flush on another stays
apart. The probes cast rays through a physics space of the model's own (`PhysicsServer3D`): parts
crossing each other (each edge, shrunk 0.0005 at its ends, cast against the body; the length of each
part's edges inside the other, sampled every 0.02, inside meaning rays along +X and +Z both cross it
an odd number of times), piercing (an edge through the other part and out of its far side) and
poking (a piercing end sticking out under 0.03); faces sharing a plane with another part's, facing
the same way (`zfight`); parts floating (lowest point over 0.02 up, bounds grown 0.02 meeting no
other part's; tagged `bob` or `holo` when meant to) or under the ground (below -0.01); parts never
seen (`hidden`); duplicate (same corners, same winding) and degenerate triangles; each moving part
against the body, its edges cast against the body, the body's edges against it and a corner of each
body part near it tested for being inside it (`brush` when it touches only in motion, `mount` when
it touches at rest within 0.15 of its axis, `seat` otherwise); an aiming part's pitch sweep against
the other moving parts, counted by `model_clash`'s own sweep (`aim`; the part that turns it is left
out, it carries it); and round parts, a part swept over an arc included (its axis through the
circumcentre of three corners of one level, else their mean; levels and rings grouped where
neighbours lie within 0.002), with more sides than their radius needs on a 1080-pixel-high screen
(chords within half a pixel, at least 10 sides for a smooth-shaded part and 8 for a flat one,
an even count, as `LowPolyMesh` caps them) at the closest zoom the model is drawn at (`play=`: a
building, a unit's near version and a figure at the base camera's closest, size 10; a unit's far
version at 20, where the battle swaps it in) and at the widest, 44 (`wide=`). The moving parts are
posed as `Motion.transform_at` poses them, turned or shifted rather than sampled on the clock: at
rest and every 10 degrees of a spin's turn or a swing's range, both ends, a slide at five poses. A
rider is posed only with its carrier at rest, BOB is not applied, and a part that moves in the
shaders (`Surf.MOVE`: a building's idle part folded into its body, the gunship's rotors) is read
back as a moving part of its own, its pivot and Motion decoded from `CUSTOM0` and `CUSTOM3`: the pairs of
moving parts, BOB and riders carried are `model_clash`'s. A triangle is seen when, from one of
sixteen headings at the camera's pitch, it faces the camera and a ray from one of four points on it
towards the camera meets nothing opaque; the unseen ones are counted by kind (`ground`, `onpart`,
`air` for faces that face down at every heading; `inner`, `buried`, `occluded`), and `fixed=` counts
those unseen from the base camera's one heading. The log is the list: a `MODEL` line per model, a
`FIND` line per finding, both `key=value` (`kind=`, part `a=` and `b=` named by soup, index, bounds'
centre and size, triangles and kit layer, `count=`, `tris=`, `at=` the point), `KNOWN` for contacts
on record, and `SUMMARY` lines: totals, the top twenty models by waste (unseen, duplicate and
degenerate triangles and the rounds' surplus) and the top ten by triangles. The thresholds are
constants at the top of the scenario. The whole roster takes about three minutes headless. A
headless run writes the flagged models (brush, aim, below, float but not bob or holo, zfight, dup,
seat), with each finding's point, to `out/model_audit.flags`, stamped with the MD5s of the sources
its findings depend on (`src/game/models/`, `low_poly_mesh.gd`, `unit_models.gd`,
`building_models.gd`, `surf.gd`, `motion.gd`, `battle_view.gd`, `data/buildings.json`,
`data/units.json`, this scenario and `model_clash.gd`); a rendered run reads it, or audits first
when it is missing or its stamp differs, saying so in the log, and writes it, and shoots the
highest-scoring flagged model of each type close at four headings,
`<type>-<level>-<tier>-h<degrees>`, a marker over each finding drawn through the geometry in its
kind's colour (red brush and aim, orange seat, cyan zfight, magenta float and below, yellow dup).
Run the headless pass first, so the rendered one holds the display only for the shots.

`scenarios/effects.gd` is the animation rig (`docs/reference/art-style.md`, **Animation**): a
test part for each surface effect and each kind of moving part, built with `LowPolyMesh` and
`Parts` and assembled by `BuildingModels.instantiate`, in two rows across the screen with the
base's own views hidden. The first row: a PULSE orb, eight BLINK lamps round a ring at phases
k/8, FLICKER sparks, a FLOW pipe on the pipe layer, a FLOW_U disc on the hazard layer, a BOB orb,
an arc of UNLIT, FLICKER and JITTER strips between two posts, and a HOLO prism on a pedestal,
plain and with the pedestal ghost-tinted. The second row: moving parts that SPIN about Y, SWING
about X (SMOOTH), SLIDE along X (HAMMER) and along Z (RECOIL), and a turning cluster of FLICKER
sparks, which has no outline. Each moves on the clock alone, so each is folded into its body and
outline and the shaders move it (`docs/reference/art-style.md`, **Folded parts**). In both modes it checks each part's surface count
(two for a hologram, its second on `MaterialKit.holo()` and never overridden), the flag bits on
every vertex, UV2 stored uncompressed, at most eight instances, the outlines (the BOB orb's
carries UV2 and colour, the arc's holds its posts only, the spark cluster has none), that a
phase read back from the mesh decodes as the shaders do (0.5 exactly, every k/8 within half a
1/254 step), and that every moving part is folded: no node of its own, `FOLDS_META` on its root,
its kind and easing on its body's vertices and, but for the sparks, its outline's. Rendered, it frames the rig at camera size 10, waits half
a second and ten frames, screenshots it at 0.0, 0.3 and 0.9 seconds, and checks that each part's
region of the screen (1.5 units square round it) changed between the first two shots, or between
any two for the flickering parts, which can be off in two shots, and for the PULSE orb, whose
real-time 1.6 s pulse can read the same in two shots 0.3 s apart that straddle its peak.

`scenarios/kit_swatches.gd` is the tiers' reference (`docs/reference/art-style.md`, **Tiers**): on
the field, the base's own views hidden, a row of ten swatches across the screen, each a chamfered
cube and a drum beside it (the surface's smooth version where it has one), in the order Base
hull-light, plate, gunmetal, gold trim, chrome, cyan strip, obsidian, veins, filigree, core glow,
and before them a 3x3 pad with the four escorts (`Parts.escort_drone`, `escort_skiff`,
`escort_troopers`, `escort_guard`) orbiting it, folded into the pad's body and moved by the shaders,
and left of the pad the shared effects: a lightning arc between two posts on `Parts.spark`
(the slow LIGHTNING crackle) beside a cluster of point sparks on plain FLICKER (the fast one), and
right of it a stack with `Parts.puffs` rising from its mouth. It logs each swatch by index with
its layer and flags and checks that every swatch's layer is within the kit, that each escort is at
most 300 body triangles (the troopers, two colonists, 3,000) and reaches no further round the pad
than its extent (1.65), and that the escorts are folded (no node of their own, one motion each on
the pad body's vertices). Rendered, it frames the row and the pad at the
closest zoom (camera size 10) and screenshots them, then again 0.3 and 1.0 seconds later, so FLOW,
PULSE, the flickers and the orbits show.

`scenarios/figures.gd` is the humanoid design study (`docs/reference/art-style.md`, **Figures**):
on the field, the base's own views hidden, a row of figures (`Figures`), each on a small concrete
pad and turned 25 degrees off the camera, the striding ones in profile, walking towards the
screen's left, so the stride shows: the colonist at 3, 3.5 and 4.25 heads in the stance, the
3.5-head colonist mid-stride, the automaton in the stance and mid-stride, and at the end of the
row a level 1 Cadet Academy for scale. It logs each figure's body triangles, its top and its
lowest point over its pad, and checks that every figure is within the study budget (1,500), that
its lowest point is on its pad (within 0.005, so no foot sinks or floats) and that each stance
figure stands its height (0.8 for the colonist, 0.9 for the automaton to its head with the antenna
above). It reads the ink factor every outline vertex carries back from the outline meshes (1 -
UV.x) and checks it on each figure's outline, its pad's and the academy's. Rendered, it shoots the row at camera size 24 (the gameplay view) and 10, the primary
colonist and the automaton at size 4 (set directly, under the camera's closest zoom), and the row
at size 10 with every figure turned 180 degrees so the backs show.

`scenarios/unit_gallery.gd` is the unit models' gallery (`docs/reference/art-style.md`,
**Units**): on the field, the base's own views hidden, every unit type in the catalog's order, each
on a concrete pad and turned 25 degrees off the camera, in five rows, one per tier, Base nearest the
screen's bottom, a level 1 Cadet Academy at the end of each row for scale; the gunship's rotors are
spun by the shaders (`LowPolyMesh.set_motion`), and any moving part it turns itself each frame, as the
effects rig does. It logs a seated colonist's triangles with and
without its legs (the pilots'). In both modes it checks every type at every tier: the triangles of the body and the moving parts within the unit's budget, at most
`UnitModels.MAX_MOVING` moving parts and one body instance, each with an outline on
`MaterialKit.ink()` casting no shadow, every vertex's kit layer within the kit, the height, width
and length (a spinning part's whole round included, a spin tag's about its pivot) within 20% of the size table, a flying unit's
lowest point within 20% of its hover height, and that no point, BOB's lift taken off where it bobs,
dips below its pad; each unit's line says its triangles, instances and extent. Each shot recentres
the camera on the units showing, a little left of and below the screen's middle (never so far left
that the first unit comes within 8 px of the screen's left edge), and checks in both
modes that every unit showing is on the screen and clear of the HUD's Build, Template base and Reset
base buttons. Rendered, it shoots the five rows at camera size 24 (the silhouettes and the tiers
side by side), each tier's row alone at size 10 in two halves (the seven smaller units, then the
four big machines), each unit alone at size 4 at Base and at Crown (set directly, under the
camera's closest zoom), and the Base row at size 10 in two halves with every unit turned 180
degrees.

`scenarios/rig.gd` proves the part rig, sockets and defence aim (`docs/reference/art-style.md`,
**Rig** and **Sockets**; `docs/reference/battle-view.md`, **Aim and muzzles**) on the ranger and
the laser turret. First a row of rangers on the field, the base's own views hidden, each an instance
of one MultiMesh (the shaders read a pose from `INSTANCE_CUSTOM` only there) in a fixed state:
standing, walking at three phases, aiming half and fully raised, and a shot's kick at two moments,
in profile. In both modes it poses every vertex of the ranger's mesh on the CPU through `Rig`
(the shaders' mirror) and checks that the forward leg is the one each walking phase says, that no
point dips below the ground, and that the muzzle socket points 30 degrees down as built, level
when aimed and up at a kick. It also poses every unit type's model through `Rig` at walking (but
for a hovering type, whose x is its bank), aimed, kicked on either side's turn, punching and banked
states, and checks that a ground type stays above the ground (within a stepping foot's slack) and
that every socket stays on its part, a slide's socket kicked back on its own side's turn only.
Then a battle (`main.open_battle`, practice): a level 3 laser turret
and the Command Center against six rangers deployed by script. At the start of each frame it reads
the projectile started last frame (`BattleEffects.bolts_fired`, `last_bolt_from`, `last_bolt_color`) and
checks that a turret's starts at one of its muzzle sockets (within the hit shake), alternating
between the two, with the head facing its target within 10 degrees, and that a ranger's starts in
front of its ranger, towards the building it attacks, at its rifle and away from its middle.
Rendered, it shoots the row at camera size 24, 8 and 4, the rangers walking in at 24 and 10, the
battle paused a frame after a turret shot at 24 and 10 (the head turned, the flash at a barrel
tip), and a ranger close at size 6 after its shot.

`scenarios/view_states.gd` checks the comic style's view states on a fresh base, each with a
close-up screenshot: the selected Command Center's outlines in gold (and the override cleared on
deselecting), the placement ghost's body tinted valid on a free spot and invalid on the Command
Center with its outline left plain ink (a body whose surface 0 is a hologram passes with no
override, since a ghost leaves holograms alone), and a new building's scaffold; the cell grid hidden
with the selection, shown with the ghost and hidden again once it is placed. It first says the fresh
base's draw calls and frame rate.

`scenarios/environment.gd` checks the ground and the scenery on a fresh base
(`docs/reference/art-style.md`, **Environment**): the terrain, the perimeter, the rocks and the
crystal outcrops are each a body with an ink outline on `MaterialKit.ink()` that casts no shadow,
the terrain's body casting none either; the perimeter's body casts a shadow and is two surfaces,
the toon's and the holograms' (its fence); the background is a sky (`BG_SKY`) drawn by a
`ShaderMaterial`; no vertex of a rock or of the rubble lies within the perimeter's reach out of the
field (its own vertices' farthest, beside the sides and in the corners' quadrants, the corner
pylons' footings included), which the rocks' placement rule does not ensure; the terrain's
triangles are within 40,000; no
vertex of an outcrop lies within 4 units of the field; along each side of the field, 3.8 units out,
at 40 evenly spaced points, the terrain's heights spread by more than 0.1 (the ground is uneven)
and never pass 0.4 (it stays low by the curb), and the distance out at which its relief is full
(`BaseView.blend_end`) spreads by more than 3 units (the edge wanders; the terrain before the
wandering edge fails both, its ground there 0.83 to 0.88 high and its relief full 3 out
everywhere); and at the widest zoom, in a 1560x720 window (a 19.5:9 phone) and with the focus at
each corner of its bounds, the ray from every corner of the screen meets the terrain, so the sky
never shows: marched in half-unit steps over `BaseView.terrain_height`, it must enter the
terrain's extent above the ground (not under its raised outer edge) and meet the ground before it
leaves; and in a 1400x400 window (3.5:1), focused on the field's nearest corner, it does not, so
that view shows the sky. Those checks are worked out from `BaseView` and the camera's transform, so they hold
headless. One check runs rendered only (headless it logs that it skipped): on the widest shot in
the 1560x720 window, the average colour of an 80x40 pixel box round the centre of each of the
field's four quarters (clear of the buildings) and round two flat stretches of the ring agree
within 0.01 in HSL lightness and 0.02 in saturation, so the field renders in the ring's shade
(**Colour**); it prints both. It screenshots the start zoom, the two far sides at the start zoom
(`far-sides`, focused 20 in from the field's far corner, the frame the edge-step check reads), the closest zoom on the field (its marks; the grid is hidden),
the closest zoom on a point where four of the field texture's tiles meet (`tile-corner`, where
nothing should show the tiles' edges), a wider stretch of the field at camera size 12 (`tiles`),
the perimeter at the middle of each side of the field at size 16 (`edge-top-left`, `edge-top-right`,
`edge-bottom-right`, `edge-bottom-left`, by the screen corner each side faces), the middle of the
+z side and the +x +z corner of the perimeter at the closest zoom (`perimeter-side`,
`perimeter-corner`), the widest zoom in the wide window and in the 3.5:1 one on the nearest
corner (`widest-wider`: stars beyond the ring, no bare colour), the widest zoom in a 1600x400
window on the field's left corner (`widest-haze`: the sky's haze band beyond the ring's lower
left), a crater and an outcrop each centred,
the first mesa's wall where it faces the camera at the closest zoom (`mesa`, its foot and its rim)
and the mesa at size 24 (`mesas`); for the perimeter, the crater, the outcrop and the mesa it
widens the camera's bounds to the terrain's, since the player cannot centre the view off the
field.

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

`scenarios/hud_layout.gd` checks the HUD's layout on a fresh base. The top bar's row holds the
resource meters and then the drone ring, and nothing else. Under a notch-like safe-area
inset (48 at the sides, 44 at the top, 34 at the bottom) with the build panel open on the
defence tab, the top bar, the Build button, the tabs and the first card keep inside the inset
less `Hud.MARGIN`, while the panel reaches the screen's sides and bottom edge; it screenshots
that. Back on the whole screen, a real one-finger drag across the card strip scrolls it and
presses nothing. Last, it presses Build, resizes the window to 1280x900 two frames into the
opening slide, and checks that the panel ends open on the new bottom edge, and screenshots it.

`scenarios/train_units.gd` checks the training and research HUD (`docs/reference/hud.md`,
**Army panel**) on the debug build's Template base, pressed through its button, so every
producer and the Research Lab are at their top level and the Hangars are built. It centres a Cadet
Academy above where the panel opens, selects it with `tap_cell`, and checks that its info panel
reads "Housing 0 / capacity" and offers Train, which opens the training panel on the screen's
bottom edge, titled with the academy's name and level, its header's housing line reading the
base's housing with the bar filled to match, and showing exactly its units' cards with an empty
queue. It queues two Rangers and a Breacher from the cards, the first by a real
touch, and checks the queue in `BaseState` and on the strip, the crystal paid and the head's time
left; cancels from the strip's second entry, which removes the newest Ranger, and checks the queue,
the refund and the "Refunded" toast; advances two seconds and, after the game's one-second tick,
checks the head's countdown (the HUD's tick path, with no state change); advances until the head
trains and checks the army, the header's
housing line and bar and the Ranger card's count. Then it selects the Research Lab, which closes the
training panel, opens Research and checks the progress line, that exactly the unlocked units'
cards show, the Ranger card's lines, a research of the Ranger paid for and named on the progress
line and its card, a second research refused with "Research already running" and nothing paid,
and the level reached once the research finishes. Last, a real tap on the panel's header reaches
nothing behind it, and a real tap on a building above the panel selects it and closes the panel;
then a tap selects a Hangar, whose info panel reads "Army housed used / capacity".
Then it presses Reset base, places a Cadet Academy and finishes it at level 1: with no Hangar its
info panel and the training header both read "No Hangar: build one to house units", the header
with no bar; the Breacher's card is disabled reading "Needs Cadet Academy 2", and a real touch on
it queues nothing; a Ranger is refused with "Not enough room in the Hangars"; the panel's
close button shows the info panel again with the academy still selected; and Build over the
reopened panel closes it, clears the selection and opens the build panel. No tap on the panels
reaches the world (a counter on `WorldInput.tapped`). It screenshots the academy's info panel with
Train, the training panel with the queue, after the first unit trained, the research panel with a
research running, the building selected outside, the Hangar's info panel, and the level 1
academy's locked cards.

`scenarios/paint_walls.gd` checks wall painting and the edge scroll on a fresh base: Barrier Wall
from the menu enters paint mode with Done on the place bar; a drag along a row of twelve cells
places twelve walls at level 1's cost, drawn as one merged wall mesh whose triangles are its twelve
pieces' (an end piece at each end, ten joined both ways), with an outline instance that casts no
shadow; a tap places one and a tap on a wall nothing; a fast drag across the row fills the cells it
jumped and skips the wall; with no metal a drag places nothing and shows one toast; the brush is
VALID on the wall it just placed and INVALID with no metal; a drag held at the right edge scrolls
the camera and paints under the finger; a drag past the count limit stops there with one toast; Done
ends the mode with the walls kept. The cell grid shows with the brush and is hidden after Done. Then
the ghost of a 3x3 type and the selected drone bay are each held near the right edge: the camera
scrolls right, each stays under the finger, and the bay drops there; the grid is hidden with the bay
selected, shown while it is dragged and hidden once it drops. Last, a drag of the bay that a second
finger interrupts by pressing Close, then Reset base, ends at once (the grid hidden) and moves
nothing, on the old base or the new one. It screenshots the brush, the painted row and a close-up of
it at the closest zoom, the place bar with Done, the field after Done (`after-done`), and the ghost
and the bay at the edge. A held drag scrolls for a number of frames, so how far depends on the frame
rate; the checks hold at any distance.

`scenarios/wall_junctions.gd` checks walls that connect. It grows a fresh base to Command
Center 10, paints a straight run, a corner, a T, a cross, a ramp (a run whose walls end at
levels 1 to 10) and a two-level L and T (arms that stop at level 1, 2 or 3) by tapping, and
upgrades them together a level at a time to level 10. At each level it checks the merged wall mesh: every
wall view hides its model, the mask of a named cell in each shape (`WallMesh.mask_at`), every
wall's mask against the rule (four-connected, any levels), the mesh's triangles against the sum
of its pieces', and the outline's triangles against the sum of its pieces' outlines, each
outlining its steps down to neighbours whose solid segment is lower (by height: a level 5
wall's low slab is the lowest); at levels 3, 5, 7 and 10 named walls of the two-level shapes
show, or do not show, those steps' extra ink triangles, an L3 beside an L5 inking and the L5
not; and at level 10 every ramp wall's steps are the ones `RAMP_STEPS` names (each level steps
down to the one below it, but level 1 and level 5, and level 4 to both sides), each pair of
adjacent levels logged with its two solid tops. It
checks every piece's body is the same whatever its lower mask. It screenshots the pattern at the closest
zoom (level 1 also with the paint brush beside it). It checks that a wall's own model,
which the brush and the gallery show, is the lone post (its triangles logged), and that every
piece of every level and mask is within its level's tier's budget for a wall piece (250 at Base
and Gold, 300 at Chrome, 350 at Obsidian, 400 at Crown; the largest logged per level). Last, it selects the cross's centre,
which stays merged with no gold outline (its own model, whose outlines turn gold, stays hidden),
and lifts it: the mesh drops it and its neighbours' joints, its own post shows, and carried back
and dropped it rejoins the cross; screenshots show it selected and in the air.

`scenarios/construction_drone.gd` checks the builder drone (`docs/reference/art-style.md`,
**Construction drone**) on the real build times. A Metal Silo placed on a fresh base gets a
drone of four instances over its scaffold and its view processes; the drone descends on arrival
(its height half a second apart), moves on round the site, and fires within ten seconds, the
beam running from the drone down to a point on the site within the footprint (plus the models'
0.15 slack) and the work band, its lowest point clearing the site's top by `CLEARANCE`, and the
timer label above the drone and `LABEL_OVER_DRONE` above the highest point it reaches. Advanced
past completion and synced, the finished silo's new view has no drone and processes only for its
moving parts (the plunger pump), while the old drone leaves under the base view, starting clear of the finished model, climbs and
frees itself. Then, with the metal and the crystal topped up by the scenario (the start's
amounts and caps do not cover both), the Command Center goes to level 2 and an upgrade of the
silo gets a drone again, clear of the model on its orbit a second in and firing at it with the
same checks, the label's included. Last, with the upgrade finished, a Metal Extractor is placed
(its cost topped up) and selected, a drag on it begins through `WorldInput`'s signals, and it
finishes while the drag holds: synced, the dragged view is kept and shows the finished model,
and its drone leaves, starting clear of that model's top (`site_height()`, which includes the
drag's lift); dropped one cell along x, the new view has no drone, the building and its view are
at the drop cell, and the grid's occupancy matches every footprint. Last, a view of the first
type whose level 1 has no moving part, finished, does not process. It screenshots the drone
arriving, firing at the scaffold (twice, a fifth of a second apart, to compare the sparks, the
rotors and the beam's flow), leaving, firing at the upgrading silo, and leaving the dragged
extractor, at camera size 10.

`scenarios/template_base.gd` checks the debug build's Template base (`TemplateBase`,
`docs/reference/input-camera.md`): it presses the HUD's button (`template_button()`) and checks
that every type is there at its count for the top Command Center level (`max_count` at
`max_cc_level()`), all at their top level and finished; that no two footprints overlap and all
lie inside the grid (on a `BaseGrid` of its own); that every wall has another wall beside it,
so each is part of a fence; that every resource is at its cap; that every drone is free, on
the ring too; that the base was saved to the run's own file while `user://base.json`'s
modification time stayed the same; that every moving part of every model that is a node (carrying
`BuildingModels.MOVE_META`) moves: sampled every four frames for 1.5 seconds, a part
passes once any sample differs from its first pose, so a hammer's hold or a period that divides
the gap cannot hide it, but for the aiming parts that are still at idle by design (an idle Motion
of a zero swing, slide or spin, carried by none that moves: the railgun's rails, the orbital
cannon's mount and the tower riding it), which move only as they aim in battle; and that no model's
folded parts are held (`BuildingModels.hold`) and each carries a motion that moves (its spin's rate
or its swing's or slide's amplitude, decoded with `Motion.from_channels`). Once the "Template base" toast has faded (2.5 seconds after the press),
rendered only (headless it logs that it skipped), it measures the whole base in a 1600x900
window at the widest zoom (camera size 44) and at the start zoom (24), each held 2.1 seconds and
then sampled every frame for three seconds through `Performance.get_monitor`: the most draw
calls (`RENDER_TOTAL_DRAW_CALLS_IN_FRAME`) and primitives (`RENDER_TOTAL_PRIMITIVES_IN_FRAME`) in
a frame and the render thread's CPU time a frame on average (measured on the root viewport, as
`model_gallery` does), each checked against a ceiling (1,600, 2.1 million, 6 ms) set well over
the measured figures (`docs/reference/art-style.md`, **Cost**), and the slowest frame's process
time (`TIME_PROCESS`, the slowest of the last second) and the frame rate (`TIME_FPS`), logged
only, since they are only as good as the machine is quiet. Then
it screenshots the whole base at the widest zoom in a 1560x720 window, then each category's
band with the fence under it (the Command Center's with the first category's; the walls are the
fences, so they are left out of the Defence band's frame), a band wider than 16 cells in even parts, each part centred and at camera
size 16 or as far out as it takes for the part, as tall as the band's tallest model (each
view's `site_height()`, said in the log), to fill no more
than 70% of the screen, so none runs under the HUD or off the screen; each part again a second
later where a part turns in it, to compare the two.

`scenarios/profile.gd` is the performance profile, to re-run after every change made for cost: the
Template base idle at camera sizes 44, 24 and 10, again at 44 with the sun's shadow off, the
sector map open, the training panel open, and the Practice raid on it with the battle scenario's
army at every type's top level, deployed in three groups from tick 1 and sampled live at sizes 44
and 24 round ticks 200 and 1,000, again at 44 with the shadow off. Rendered, each sample is a
1600×900 window with vsync off, held a second (three after the shadow goes off), then sampled every
frame for three seconds: the frame's interval split into the main thread's part, the drawing and
the wait after it (`RenderingServer.frame_pre_draw` and `frame_post_draw`), the `Performance`
monitors, the shadow pass's primitives (`viewport_get_render_info`; the Compatibility renderer
counts its draw calls as 0, so the shadow's draws are the difference the shadow-off sample makes),
the render thread's CPU time (its GPU time reads 0 on this renderer), and the CPU time a frame of
each system `Profile` times (`src/game/profile.gd`: a static `enabled` flag only this scenario sets,
each timed entry point adding its microseconds under its key: `BuildingView._process` over every
view, `BattleView._process` by section, the sim's step, `BattleUnits`' buffer uploads,
`BattleEffects.draw` by list group). It also times `Hud.refresh`, `BaseView.sync`, the whole
`changed` chain and a second's production paid, the save's JSON, the sector map's outposts and
MultiMesh buffer uploads, and logs the triangles and draws a frame by source (the buildings' bodies,
outlines and moving parts, the walls, the scenery; the units, each effect list, the rubble) and
each battle tick's alpha-blended fill (the effects' and the holograms' projected triangles, in
screens' worth); the meshes it counts are let go after each split and fill, so one the battle has
since replaced (the merged walls', rebuilt as walls fall) is not kept alive in the video memory it
reads. The log ends with a table, one row a sample, and a note on the nested systems:
`battle_view` holds `battle_steps` (which holds `sim_step`), `units_draw` (which holds
`units_upload`), `deaths`, `aim_defences`, `draw_buildings`, `bars_upload`, `effects_draw` (which
holds every `fx_*`) and `walls_mask`, so the columns are not summed; `building_views` is apart.
Each rendered sample checks that the window drew at least 99% of its frames (`frame_post_draw`
fired between one process and the next), so a window that stops drawing fails the run, and the
effect lists' member names it reads through `get()` are checked to resolve. Headless it skips the
samples and checks the wiring. It checks no cost against a ceiling: the numbers are read.

The `anim_*` scenarios shoot every moving thing in the game as frame strips, the evidence for
the animation audit; each frame is framed with `frame_world` and every strip's line in the log
names its camera size. Their checks only make sure each subject did what its strip is meant to
hold; the strips are read by eye. The battles are practice battles opened through
`main.open_battle` with a hand-made setup (`docs/reference/battle.md`, **The setup and the
commands**), the battle HUD hidden and no unit selected, units deployed and abilities cast
through `BattleView.deploy` and `cast` or `script_commands`, never a touch; each army brings one
unit more than the scenario deploys, so a battle never ends and opens its result panel during a
strip. Each battle is surrendered and left before the next.

- `scenarios/anim_units.gd`: every unit type at level 1 against a level 10 Metal Silo (its
  sturdiest, so it stands through every strip), deployed beyond its reach on the screen's right
  (the brawler, which closes in, on the lit side to the screen's left, out of the silo's shadow):
  `<unit>-move` (8 frames, 100 ms) framed close on the unit (camera size 4 to 7 by its size; the
  four infantry cropped at size 5), `<unit>-fire` (8, 50 ms) framed with `frame_span` on the unit
  and the silo (cropped for the infantry), from just before its second shot (the breacher's first,
  as it closes in, 12 frames at 70 ms, holding its blast and its death). The close strips, cropped, at 2.4 times the
  model's height (camera size 3 to 6), for the limbs: `<unit>-close-bank` for a hovering type (12,
  60 ms) from its deploy, turning about 90 degrees onto its course; `<unit>-close-move` (12, 60
  ms) before the wide move strip; `<unit>-close-fire` (16 frames over two shots, 320 ms a frame at
  most; for the ranger, the siege walker, the hover tank and the titan, whose guns kick, 12 at 70
  ms over one shot, so the kick and the return show) after the wide fire strip; and
  `<unit>-close-death` (12, 70 ms), staged on the unit attacking in place through
  `BattleUnits.die`, framed lower and wider by its lowest point's height as drawn so a falling
  aircraft stays in the tile (none for the breacher). It checks that each hovering type banks into its
  turn, that the brawler's, the siege walker's and the titan's blows alternate sides (their drawn
  state's parity), and that a staged death plays out in `death_seconds`.
  Then, for every type, `<unit>-impact` (14, 70 ms), close (camera size 6, cropped) on the near
  side of the silo from just before its second shot (the breacher's charge as it reaches the
  silo): its projectile arriving and its impact; and `<unit>-death` (16, 80 ms, close on the
  unit, cropped) from when one shot is left in it, two level 7 Railguns shooting it down (the
  sim's death, so its effects show), the battle run at speed 2 while it waits, the ticks the
  strip ran over logged beside the tick it died by.
- `scenarios/anim_defences.gd`: every type with a targets class (the guns and the traps) at
  level 1 beside a level 1 Metal Silo, a Hover Tank (a Gunship for an air defence) deployed by
  the silo, two cells from the defence, three ticks into `<type>-fire` (8, 50 ms; the plasma mortar 10 at 150 ms, the orbital cannon
  12 at 200 ms, the grav trap 8 at 100 ms, the gravity well, at level 5 so it holds 2.5 s, 24 at
  100 ms), framed with `frame_span` on the defence's head and the unit and cropped; then
  `gravity_well-release` (8, 80 ms, from 6 ticks before its hold ends: the vortex fading out),
  and later `gravity_well-three` (16, 100 ms: the well holding three gunships at once, a vortex to
  each and its glow and swirl once; it checks all three are held); and for a defence `<type>-impact` (8, 50 ms; the
  missile battery 10 at 60 ms, the plasma mortar 10 at 120 ms, the orbital cannon 12 at 200 ms,
  the gravity well 8 at 150 ms), close on the unit (camera size 6, cropped) from its next shot (a
  new projectile in the defence's colour): the projectile arriving and its impact; then
  `building-fall` (12, 100 ms, from 250 ms before a Hover Tank's last shot on a Drone Bay: the
  collapse, the rubble popping up, debris and smoke) and `wall-break` (12, 50 ms: a level 4
  Breacher on a Barrier Wall). It first checks that every armed type (one that targets, holds,
  throws or shields) and every unit has a weapon record of its own (`Weapons.has`).
- `scenarios/anim_aim.gd`: every defence that aims, at level 1 (and the plasma mortar, flak
  cannon, ion beam and orbital cannon at their top level), with a Metal Silo off to its upper
  right and a level 7 Dune Runner (a Gunship for the flak cannon) deployed off to its upper left,
  crossing its arc on the way to the silo (the next one deployed whenever the last falls):
  `<type>-<level>-aim` (16, 200 ms, camera size 9, cropped) from the deploy, the head turning
  towards the unit, checked to turn at least 25 degrees and face it within `AIM_READY`, and not
  to kick before its first shot; `<type>-<level>-fire` (12, 50 ms, size 7, cropped) from 100 ms
  before its next shot, checked to kick back at least 0.3 of its travel and no more often than
  it fires. Then `emp-freeze` (16, 250 ms): a level 6 missile battery aiming when an EMP Burst
  lands on it, checked that no moving part moves while it is disabled and that they move again
  once it wakes (the launcher's muzzle socket, and its radar, folded into the body, by the clock it
  is drawn at: the body's hold while set, else the clock); and `reveal` (8, 60 ms): a cloaked sentry as the unit comes within its range,
  checked to show every step of its fade in and end as itself. Before those, per pitching
  defence (at level 1, and the laser turret, flak cannon and ion beam at their top level too),
  `<type>-<level>-pitch` (16, 300 ms; the orbital cannon's 700 ms; size 9, cropped): a unit
  deployed off to the screen's right comes at it (a Bomber for the guns that shoot at the air, a
  Brawler for the laser turret, the cloaked sentry and the plasma mortar, a Hover Tank from far
  off for the orbital cannon), checked that the barrels' elevation sweeps at least 15 degrees (or
  0.9 of the way to the elevation they want at the end, if that is less) and ends within
  `AIM_READY` of it; against the Bomber, that the elevation they want rises at least 5 degrees as
  it closes and that they never point lower than 5 degrees at it. Headless, each strip still takes
  its time, so the checks read the battle it would have shown.
- `scenarios/anim_base.gd`: the construction drone over a Metal Silo placed on the fresh base,
  `drone-arrive` and `drone-laser` (8, 150 ms, camera size 6), then at its next shots
  `drone-beam` (framed on the beam at camera size 10, cropped) and `drone-sparks` (on the work
  point at size 4, cropped); then every type but the walls and the traps at level 1, its middle
  level and its top level, each a view of the scenario's own alone at the field's middle (the
  base's views hidden), `<type>-<level>` (8, 150 ms, cropped), framed on the moving part its
  idle reads by at that level at the camera size its `FOCUS` entry gives (by level band, 4.5 to
  10; a type without one, the defences, on its middle at 2.6 a cell). Checks: the drone fires three times, and every view
  shot showed its model.
- `scenarios/anim_effects.gd`: `swarm-dome` (8, 250 ms), `emp-ring` (8, 50 ms) and `emp-grey`
  (8, 500 ms: the stun and the waking), `emp-wake` (8, 50 ms, camera size 4, from two ticks before
  the turret wakes from a second burst: its wake flash), `strike-marker` (8, 100 ms), `strike-land` (16, 50 ms,
  from 12 ticks before it lands) and `strike-smoke` (8, 150 ms); `shield-hit` and `shield-drop`
  (8, 100 ms) on a shield generator's pool; `rubble-settle` (12, 100 ms) from a Drone Bay's fall
  and `smoke-column` (8, 250 ms) two seconds later.
- `scenarios/anim_identity.gd`: the models' poses at fixed clocks (`fix_clock`), for comparing
  two trees' animation shot for shot: every type but the wall at level 1, its middle level and its
  top level, each alone at the field's middle (the base's views hidden), framed on its middle at
  2.6 a cell, and the gunship at Base and at Crown, each a screenshot `<type>-<level>-<k>` at the
  clocks 0.37, 2.9 and 7.41 seconds (repeats allowed). Run it rendered on each tree into its own
  `--out` and compare the shots of the same name (`Image.compute_image_metrics`): a part moved
  differently shows as a difference at a known clock. Checks: every view showed its model.

Each runs in about one to four minutes rendered, inside the watchdog's 300 seconds.
