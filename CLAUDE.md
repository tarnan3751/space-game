# Space Game (placeholder name)

A mobile space base-builder in the style of Clash of Clans. Players build and upgrade a base,
send expeditions into procedurally generated fields to gather resources (PvE), and attack
other players' saved bases, which defend themselves with AI (async PvP).

Target: native iOS and Android, light enough for mid-range phones. Solo developer + Claude.

This file is the **map**: what the project is, where each area lives, the commands, the
conventions and the workflow. How each area works is in its **reference file** under
`docs/reference/`; the scope, status, roadmap and decisions are in `docs/project_overview.md`.
Read this file, then the reference file of every area a task touches, then the header comments
of the modules involved. A section named in bold is a heading of this file or of a doc.

## Status

**Milestone 1 (offline base) is built**: placement, timers, builders, economy, save with offline
progress, models built in code. So is step 2, base polish, and the comic-style kit (toon light,
ink outlines, a generated material kit) with every model rebuilt onto it, and the upgrade pass to
Command Center 10: ten levels, every one modelled, in five tiers, on the 48×48 field, with save
version 2 (`docs/plans/upgrade-pass.md` is its record). Everything after it is planned. `docs/project_overview.md` holds the roadmap (§2.2), the known limitations (§2.3) and
the decisions (§3). Balance numbers in `data/` are fast dev values, not tuned.

## Stack (pinned)

- **Godot 4.7.x stable**, statically typed **GDScript**. Not C#: Godot still marks C# on
  iOS/Android experimental.
- **GL Compatibility** renderer, for the widest range of phones.
- **No addons, no npm.** Tests, gate and harness are our own, in `tools/`.
- Later: **Nakama** server with its TypeScript runtime, in `server/`.

Check before writing engine calls. Godot 3 syntax and APIs are the most common mistake here.
Run `tools/dump_api.sh` once, then look up exact signatures in `.godot-api/`
(e.g. `find .godot-api -name Camera3D.xml`).

## Commands

`GODOT` names the engine binary; every tools script falls back to `godot` on `PATH`, then
`/Applications/Godot.app/Contents/MacOS/Godot`:
`export GODOT=/Applications/Godot.app/Contents/MacOS/Godot`

| What | Command |
|---|---|
| The gate (import, tests, check-only, headless boot) | `tools/gates.sh` |
| Run all tests | `tools/run_tests.sh` |
| Run some tests | `tools/run_tests.sh production` (matches `file::method`) |
| Compile-check one script (read the output; exit code is 0 either way) | `$GODOT --headless --path . --check-only -s res://src/core/base_state.gd` |
| Behaviour check through the harness | `tools/harness/run.sh place_and_build [--rendered]` |
| Land a delivered series | `tools/land_series.sh <patch-dir> <base-commit> <tree-hash>` |
| Run the game (the owner only: it opens the real save) | `$GODOT --path .` (debug build: free one-second builds; `-- --no-cheats` for the real numbers) |
| Dump engine API | `tools/dump_api.sh` |
| Regenerate the material kit's textures (after an import) | `$GODOT --headless --path . -s res://tools/gen_textures.gd` |

**Any Godot run writes files**: the `.godot/` cache, `*.uid` files beside new scripts, and,
run normally, the save under `user://`. The gate and the harness boot the game on an isolated
save through `--save-path=<file>` (a user argument after `--`, honoured by `main.gd`).

**Run the gate after every change**, and at least the tests after every change to `src/core`
or `data/`.

## Where things live

| Area | Code | Reference |
|---|---|---|
| Core and economy: catalog, base state, commands, timers, production, grid, seeded RNG | `src/core/` | `docs/reference/core-economy.md` |
| Data format: `rules.json`, `buildings.json`, the fixtures, the save file | `data/`, `test/support/fixtures/` | `docs/reference/data-format.md` |
| Input and camera: the scene, camera, gestures, placement, views | `src/game/` (all but the HUD's and the art style's files) | `docs/reference/input-camera.md` |
| Art style: the look, light, colours, the material kit, `LowPolyMesh`, outlines, models, animation, the construction drone, view states | `src/game/models/`, `construction_drone.gd`, `src/game/*.gdshader*`, `material_kit.gd`, `surf.gd`, `motion.gd`, `low_poly_mesh.gd`, `assets/textures/kit/`, `assets/textures/*.png`, `tools/gen_textures.gd` | `docs/reference/art-style.md` |
| HUD: the theme and fonts, top bar (meters, drone ring), Build button and build panel, place bar, info panel, toasts | `src/game/hud.gd`, `hud_icon.gd`, `drone_ring.gd`, `meter.gdshader`, `format.gd`, `assets/fonts/` | `docs/reference/hud.md` |
| Testing and tools: runner, fixtures, gate, harness, landing, API dump | `test/`, `tools/` | `docs/reference/testing-tools.md`, `tools/harness/README.md` |

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
- `SeededRng` sequences and an existing test's expected values change only under a tier A
  brief that says so. A save format change (`to_dict`/`from_dict`) keeps old saves loading or
  bumps `"version"` with a migration.

### `src/game/` is presentation

- Reads `BaseState`, draws it, turns gestures into commands. Never mutates state directly.
- `PlacementController` is the only place that calls `apply()`.
- Scenes are built in code. `scenes/main.tscn` is one node with `main.gd`. Don't hand-write
  big `.tscn` files; their resource ids are easy to break.
- Input: `WorldInput` uses `_unhandled_input`, so HUD controls get touches first. Mouse clicks
  arrive as touches (`emulate_touch_from_mouse`), so there is one code path for desktop and phone.
  Any HUD `Control` that isn't `MOUSE_FILTER_IGNORE` blocks touches to the world, so
  layout-only containers must be set to IGNORE.
- Mobile cost: no allocation in `_process`, and a change does not multiply draw calls.

### `data/` is game data

- `rules.json` (resources with names and colours, build-menu categories, grid, start layout,
  build menu) and `buildings.json` (per type: size, category, hidden, targets, max_count per CC
  level; per level: cost, build_seconds, requires_cc, produces, storage, builders, capacity, hp,
  damage, range_cells, fire_ms).
- The server will load the same files. Change numbers here, not in code.
- `Catalog` converts JSON numbers to ints on load (Godot parses all JSON numbers as float).
  `test_shipped_data_is_valid` checks the real files.

## Folder layout

```
data/            game data shared with the server
docs/            project_overview.md (scope, status, roadmap, decisions); reference/ (one file per area)
scenes/          main.tscn only
src/core/        catalog, base_state, building_state, base_grid, seeded_rng
src/game/        main, template_base, iso_camera, world_input, placement_controller, base_view,
                 building_view, construction_drone, building_models, wall_mesh, low_poly_mesh, surf,
                 motion, material_kit, hud, hud_icon, drone_ring, format, model_preview, toon.gdshader,
                 toon_common.gdshaderinc, effects.gdshaderinc, ink.gdshader, holo.gdshader,
                 ground.gdshader, terrain.gdshader, field_marks.gdshaderinc, meter.gdshader
src/game/models/ parts (the model being built, shared helpers and surfaces), then one file of
                 model builders per category: core, resources, army, defense, traps; walls, the wall's own; and
                 drone, the construction drone and its laser
test/core/       test_*.gd (one file per core area)
test/support/    TestCase base class, fixtures and fixture JSON
tools/           run_tests.sh, test_runner.gd, gates.sh, land_series.sh, dump_api.sh,
                 gen_textures.gd
tools/harness/   driver.gd, scenario.gd, scenarios/, run.sh, README.md (output in out/, gitignored)
.claude/agents/  scout, researcher, developer, reviewer
assets/          textures/kit/ (the material kit, generated); textures/field.png and
                 terrain_rock.png (the ground's and the terrain's, generated); fonts/ (the HUD's two
                 fonts, each with its OFL.txt); real models/audio later
server/          Nakama TypeScript runtime later (.gdignore keeps Godot out)
```

## GDScript gotchas for this project

- `:=` can't infer a type from a Variant. Indexing an untyped Array/Dictionary or calling
  `.get()` returns Variant, so write the type: `var n: int = dict["k"]`. This is a compile error, not a warning.
- Typed dictionaries (`Dictionary[String, int]`) and typed loop variables (`for id: int in ...`) are used throughout.
- Tabs for indentation (`.editorconfig`).
- Godot 3 → 4: `Spatial`→`Node3D`, `instance()`→`instantiate()`, `yield`→`await`,
  `export`→`@export`, `connect("sig", self, "m")`→`sig.connect(m)`, `PoolStringArray`→`PackedStringArray`,
  `set_shader_param`→`set_shader_parameter`.
- Packed arrays are passed by value; return them instead of filling an argument.
- Integer division is intentional in core, so that warning is turned off in `project.godot`.
- Comparing a Vector3 Variant with `null`: use `typeof(x) == TYPE_VECTOR3` instead.
- A method named `log` shadows the built-in `log(float)` and fails to parse; pick another name.
- Commit the `*.uid` files Godot generates next to scripts.

## Seeing the game

The coordinator drives the running game through the `godot` MCP server
([tugcantopaloglu/godot-mcp](https://github.com/tugcantopaloglu/godot-mcp), cloned and built at
`~/Development/godot-mcp`, registered in Claude Code's local config, not in this repo).
`run_project` launches the game, then `game_*` tools take screenshots, simulate taps, drags and
touch gestures, read logs and evaluate GDScript in the live scene tree. While it runs, the MCP
injects a `McpInteractionServer` autoload (TCP on 127.0.0.1:9090) and removes it on stop; never
commit it. It runs the game normally, on the real save, on the main tree: it is the
coordinator's instance, never an agent's. Running normally, it runs with the dev cheats on, like
the owner's own runs, so what it builds is free and goes into the real save. Agents see the game
through the harness in their own clones. Headless (`--headless`) runs catch script errors but
render nothing.

## Agent workflow

Work on this repo is split across a coordinator and four project subagents (`.claude/agents/`).
The split is by judgment required, and by how much context each seat can afford to hold.

- **Coordinator** (the top-level session) — talks to the owner, makes product and feature
  decisions or escalates them, writes briefs (each naming its **tier**, below), approves plans
  where a plan is required, routes work and review findings, reads the real diff of every tier A
  change and of every fold, and lands series. It does not read large files itself (the scout
  does), and does not write feature code in the main tree: trivial edits only, when spawning an
  agent would cost more than the edit.
- **`developer`** (Opus) — works in a clone of its own (**Lanes**), implements the brief, runs
  `tools/gates.sh` at every commit, verifies behaviour through the harness in its clone, updates
  the docs the change invalidates, and delivers a patch series on the current `main` with the
  tree it reproduces. Never writes to the main working tree. Plans first only when the brief asks
  (tier A) or when it meets an open decision. **Continue the same agent from plan to
  implementation** (`SendMessage`); respawning loses what it learned planning.
- **`reviewer`** (Opus) — independent review of the series, applied in a clone of its own: the
  full pass for tier A, the targeted pass for tier B (**Tiers**). Report-only; it is given the
  code and the brief, never the developer's conclusions.
- **`scout`** / **`researcher`** (Sonnet) — read-only codebase lookups (including engine
  signatures from `.godot-api/`) and outside research (Godot 4.7 docs and issues, Nakama). Neither
  runs Godot. A load-bearing research fact (an engine behaviour, an API shape) is verified by Opus
  or the coordinator before a decision rests on it.

**Tiers.** Every brief names its tier, which sets the plan and the review:

- **A** — `src/core` state math or ordering, the save format, command shapes, the data schema,
  `SeededRng`, the future battle sim and server, and any change to an existing test's expected
  values. A plan before code, approved by the coordinator, who escalates product decisions to
  the owner; then the implementation; then the full review: determinism probed, old saves
  loaded, every gate, the harness driven headless and rendered.
- **B** — game-layer work (HUD, visuals, camera, input feel, models), tooling and the harness,
  new data entries and balance values. No plan round trip: the brief carries the decisions and
  the developer stops only at an open decision. The targeted review, about thirty minutes: the
  diff read, the gate run, the changed behaviour driven once in the harness.
- **C** — docs, comments, config. No reviewer: the gate and the coordinator's own read.

Small later-scope items are **batched** by area, up to about five a slice, one commit each, one
brief and one review.

**Briefs.** A brief is the whole of what an agent knows about the task, so it carries:

- **Title and tier.**
- **Goal** — what changes for the player or the tooling, in two or three sentences, and what
  is explicitly out of scope.
- **Decisions made** — every choice the coordinator has already settled (names, data values,
  placements, which op, which file), so the developer never has to guess; for tier A, the
  plan is where remaining choices surface.
- **Read** — `CLAUDE.md`, the reference files of the areas touched, and any module or doc the
  task depends on; the scout's findings when there are any, as `path:line`.
- **Verification** — the tests expected, and what the harness run must show (which scenario,
  headless or rendered, what the screenshots must contain).
- **Lane** — the clone to use, whether the lane holds the display (one rendered run at a time),
  and the base commit the series must be built on.
- **Delivery** — the plan format (tier A) or the report format, as the agent definition states.

**Lanes.** Every Godot run writes files in the tree it runs in (`.godot/`, `*.uid`, and a
normal run the real save), so the main working tree is the coordinator's and stays at `HEAD`:
no agent writes to it or its index. A developer or a reviewer works in a `git clone` of its own
under its scratch directory; there is nothing to install, and the first `tools/gates.sh` run
imports the project. Two developers may run at once on disjoint areas, under three rules: only
one **rendered** harness run happens on the machine at a time, which `tools/harness/run.sh
--rendered` enforces with a machine-wide lock, so a lane just runs it and waits (headless runs,
the gate and the tests run any time); the second lane rebases its series onto `main` before delivery; a lane's
docs changes stay within its area's reference file, the map only where a status line changes. A
lane boots the game only through the gate and the harness, which pass `--save-path`; **nobody
runs the game normally in a clone** (`$GODOT --path .`, headless or not, the editor included),
because that opens the owner's save. The `godot` MCP server is the coordinator's one instance.

**Review routing.** The reviewer's findings go back to the **same** developer (`SendMessage`),
which folds them into the series; the coordinator reads the fold's diff; then the reviewer
re-reviews. A FAIL loops until it passes; PASS WITH FIXES is folded and read, re-reviewed when
the fold touched core. Anything the developer did outside the brief (**Adjacent changes**) is
kept or vetoed by the coordinator, not the reviewer.

**Delivery and landing.** A series is `git format-patch` files on the current `main`, one
logical change per commit (refactors separate from features, an imperative sentence-case
subject, a body of plain paragraphs saying what and why, **no trailers**: no commit in this
repo carries one, the coordinator's own included), with the write-tree
hash it reproduces and the gate's tail per commit. Once the review's findings are folded and the
fold's diff read, the coordinator lands it with
`tools/land_series.sh <patch-dir> <base-commit> <tree-hash>` (clean tree and HEAD at the base
required; `git am`; the tree checked, with a rollback on mismatch; the gate run; the commits
left in place). The coordinator pushes `main` to `origin` after each landing.

Constraints:

- **Decisions come from `docs/project_overview.md`** (§1.2 philosophy, §3 decisions). An agent
  that finds an open decision stops and reports; it does not guess.
- **The layering rules above are not negotiable**, and neither are: data in `data/`, core
  changes with fixture tests, scenes built in code, no `:=` from a Variant, tabs, committed
  `*.uid` files, IGNORE on HUD layout containers, frozen `SeededRng` sequences and test
  expectations outside tier A, old saves loading.
- **Temporary instrumentation is tagged `[verify]`** and gone before a report:
  `grep -rn "\[verify\]" src test tools` returns nothing.

## Export notes

- Exclude `test/*`, `tools/*`, `server/*` in export presets.
- If `data/*.json` goes missing in an export, add it to the preset's include filter.
- The material kit's PNGs under `assets/textures/kit/`, and the field and rock textures beside
  it, are loaded by path (`MaterialKit`, `BaseView`), so a preset that exports selected resources
  only must include them.
- The HUD's fonts under `assets/fonts/` are imported resources (each `.ttf` with its `.import`),
  preloaded by `hud.gd`, so they export with it; the `OFL.txt` beside each is not a resource and
  needs the preset's include filter to ship.
- Commit the `*.uid` files Godot generates next to scripts.
- A debug export (a debug APK, for example) is a debug build, so it runs with the dev cheats on;
  check balance on a release export or with `--no-cheats`.
