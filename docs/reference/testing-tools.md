# Testing and tools

The test runner, the fixtures, the gate, the harness, the landing script and the API dump:
everything under `test/` and `tools/`. No addons; all of it is the project's own.

Every script takes the engine binary from `GODOT`, then `godot` on `PATH`, then
`/Applications/Godot.app/Contents/MacOS/Godot`. **Any Godot run writes files**: the `.godot/`
cache (gitignored), `*.uid` files beside new scripts (committed), and, when the game runs
normally, the save under `user://`. That is why agents run Godot only in their own clones, and
only through the scripts below (`CLAUDE.md`, **Agent workflow**).

## Tests

`tools/run_tests.sh [filter]` imports the project (a headless run never scans it, so
`class_name` scripts added since the last import are not registered until an import), then runs
`tools/test_runner.gd`, a `SceneTree` script. The runner finds every `res://test/**/test_*.gd`,
which must extend `TestCase`, and runs each method whose name starts with `test_` (sorted) on a
fresh instance, calling `before_each()` first. A filter runs only the tests whose `file::method`
(`test_production::test_storage_caps_production`) contains it. The output is one `RUN` line per
test, `FAIL:` lines under a failing one, and `N passed, M failed`; the exit code is 1 on any
failure or when nothing matched. The shell script also fails on any `SCRIPT ERROR`, since Godot
logs a script error and carries on.

`TestCase` (`test/support/base_test.gd`) records failures instead of stopping, so one test can
report several problems: `assert_eq(actual, expected, message)` is strict about type (int 5 and
float 5.0 differ), `assert_true`, `assert_false`.

Logic tests build their state from the fixture catalog, never `data/`: `const Fixtures :=
preload("res://test/support/fixtures.gd")`, then `Fixtures.catalog()`,
`Fixtures.catalog_with_grid(size)` (the same rules on another field),
`Fixtures.new_base(start_time)`, `Fixtures.army_base()` (the fixture base with a finished
hangar and an academy, at time 30; `data-format.md` describes the fixture base) or
`Fixtures.battle_catalog(size)` (the fixture catalog with the battle units merged in). The one
exception is `test_catalog.gd`, whose `test_shipped_*` tests load the real `data/` on purpose:
the data is valid, the start layout fits, every level's price fits the storage a base can reach
when that level unlocks, and no curve (cost, `build_seconds`, `hp`, `produces`, `storage`,
`capacity`) goes down from one level to the next.

| File | Covers |
| --- | --- |
| `test/core/test_base_grid.gd` | Bounds, occupancy, own cells counting as free. |
| `test/core/test_base_state.gd` | Start layout, place and its refusals, the Command Center level checked before the limit, instant buildings, walls, timers, upgrades and their rules, moves, bad commands, the `changed` signal, the clock going backwards, the save round trip, a save from before the third resource, a version 1 save centred on a grown field (`Fixtures.catalog_with_grid`) and left in place on one that did not grow, dropping buildings that no longer fit, the army's save round trip mid-way (queues running and paused, a research), saving leaving the catalog's unit order alone, version 1 and 2 saves loading with no army, and army entries that no longer fit dropped or clamped (an army above the housing kept, waiting). |
| `test/core/test_catalog.gd` | The shipped data (validity, start layout, affordability, curves, final levels at the top Command Center, counts; for units, prices and housing within reach, curves, final levels at the top lab), int conversion, level, count, resource, category, display-field and unit lookups, one validation message per rule (units, `rules.army` and `rules.battle` included), the battle classes and a catalog without battle rules, the shipped battle data (a hull on every type but the traps, each special's fields at every level), the dev cheats (every level free and one second at most, nothing else changed; units free to train and research in one second at most; a base building what it could not afford). |
| `test/core/test_production.gd` | Production starting at completion, carried remainders, tick-size independence, storage caps, caps rising when a silo finishes, busy buildings not producing, a third resource. |
| `test/core/test_research.gd` | Research: no lab, pay and level up (training at the new price), max level, lab level gating (an upgrade under way not counting), research going on while the lab upgrades, one at a time, the unit unlocked first, funds, the dev cheats, and one-second ticks equal to one big tick with a building, the research and a unit finishing in one second. |
| `test/core/test_seeded_rng.gd` | The frozen sequences for seeds 1 and 12345, range bounds, the zero seed. **These expected values never change.** |
| `test/core/test_training.gd` | Training: queue and pay, units finishing in order, all-or-nothing counts, every refusal through its check and `apply`, a huge count refused before it is multiplied, `queue_of` handing out a copy, no Hangar, a producer under construction, the queue limit, two producers side by side, a busy producer pausing and resuming, an army above the housing waiting for a Hangar (and a Hangar being upgraded keeping its housing), a finished unit housed while its producer upgrades, the lowest id that fits housed first, a unit and a Hangar finishing in the same second, cancel and its refund, refusals, production untouched, the same commands giving the same state, and one-second ticks equal to one big tick. |

A core change ships with a test here. A new test file is `test/core/test_<area>.gd`.

## The gate: `tools/gates.sh`

One command, four gates, in order; one line each, the failing gate's output in full, exit
non-zero on any failure:

1. **import** — `--import`, registering `class_name` scripts.
2. **tests** — `tools/run_tests.sh`.
3. **check-only** — `--check-only -s` on every `.gd` under `src/`, `test/` and `tools/`. Godot
   exits 0 from `--check-only` even on a parse error, so the gate reads the output for
   `SCRIPT ERROR`, `Parse Error` and `Failed to load script`.
4. **boot** — `scenes/main.tscn` headless for 240 frames (`--quit-after 240`) on an isolated
   save (`--save-path=` under a temp directory), with no `SCRIPT ERROR` or `ERROR:` line. It
   passes no `--no-cheats` on purpose: it boots with the dev cheats on, as the owner's debug
   runs do, which makes it the automated run of `main.gd`'s real cheat path, and its isolated
   save makes that harmless.

It runs in about ten seconds. Every commit of a delivered series passes it; the reviewer runs it
again; the landing script runs it after the series is applied.

## The harness: `tools/harness/`

A scripted driver that boots the real scene on an isolated save, runs a scenario that acts
through `PlacementController`, the input signals and `BaseState`, and writes a log and
screenshots. `tools/harness/run.sh <scenario>` runs headless (logic checks);
`--rendered` opens a window and saves screenshots. `run.sh` passes `--no-cheats` beside
`--save-path`, so a debug build's dev cheats (`core-economy.md`, `apply_dev_cheats`) stay off
and every scenario runs on the real numbers; `scenarios/dev_cheats.gd` applies them itself and
checks them. `tools/harness/README.md` documents the driver, the clock, the isolation and how to
write a scenario; `scenarios/place_and_build.gd` is the example.

Two scenarios check every model of the roster against the art style's contract
(`art-style.md`, **Budget and checks**): `model_gallery` (instances, outlines, kit layers,
triangle budgets, reach and height per type and level, with screenshots of every page, row and
row's first model) and `model_clash`, headless, the clash rule's check: no two moving parts of a
model cross over their whole motion, rigid and with BOB applied, and the poses at which each
touches the static body counted for review.

## The texture generator: `tools/gen_textures.gd`

A headless `SceneTree` script that draws the material kit's twenty layers into
`assets/textures/kit/` and the ground's field texture into `assets/textures/field.png` from one
seed, byte-identical run to run:
`$GODOT --headless --path . -s res://tools/gen_textures.gd`, after an import. The gate does not
run it; the PNGs are committed. `art-style.md`, **The material kit**, says what each layer holds
and how to add one, and **Environment** what the field texture holds.

## Landing: `tools/land_series.sh`

```
tools/land_series.sh <patch-dir> <base-commit> <tree-hash> [--dry-run]
```

The coordinator's landing step for a developer's `git format-patch` series (`CLAUDE.md`,
**Agent workflow**). It refuses unless the working tree is clean, HEAD is the base commit and
the branch is `main`; checks each message (no trailers, no period at the end of the subject);
applies the patches with `git am`; checks `HEAD^{tree}` against the reported tree hash and, on
a mismatch or a patch that does not apply, resets `main` back to the base; then runs
`tools/gates.sh` and leaves the commits in place for the owner to push. `--dry-run` applies,
checks and resets without running the gates. A gate failure leaves the commits in place and
prints the `git reset --hard` that undoes them.

## The engine API: `tools/dump_api.sh`

Writes the installed engine's own API reference (`--doctool`) to `.godot-api/` (gitignored,
with a `.gdignore` so the editor never scans it). Look signatures up there instead of guessing:
`find .godot-api -name Camera3D.xml`, then grep the XML. Re-run after upgrading Godot. Godot 3
syntax and older 4.x APIs are the most common mistake in this project.

## Compile-checking one script

```
$GODOT --headless --path . --check-only -s res://src/core/base_state.gd
```

Remember that the exit code is 0 either way; read the output.

## Seeing the game

The coordinator drives the running game through the `godot` MCP server (`CLAUDE.md`, **Seeing
the game**): `run_project` launches it on the main tree and the `game_*` tools take screenshots,
simulate touches and evaluate GDScript in the live tree. It runs the game normally, on the real
save, which is why only the coordinator uses it. While it runs it injects a
`McpInteractionServer` autoload (`mcp_interaction_server.gd`, gitignored) and removes it on
stop; never commit it.
