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
hangar and an academy, at time 30; `data-format.md` describes the fixture base),
`Fixtures.foundry_base()` (the army base with a foundry) or
`Fixtures.battle_catalog(size)` (the fixture catalog with the battle units merged in), or
`Fixtures.expedition_catalog(change)` (the expedition catalog: a 40×40 field and ten Command
Center levels, its rules optionally changed first). The exceptions are `test_catalog.gd`, whose
`test_shipped_*` tests load the real `data/` on purpose, and the data check
`test_outpost_generator.gd::test_shipped_data_lays_out_every_field`. The shipped-data tests check:
the data is valid, the start layout fits, every level's price fits the storage a base can reach
when that level unlocks, and no curve (cost, `build_seconds`, `hp`, `produces`, `storage`,
`capacity`) goes down from one level to the next.

| File | Covers |
| --- | --- |
| `test/core/test_base_grid.gd` | Bounds, occupancy, own cells counting as free. |
| `test/core/test_battle_combat.gd` | Battle damage: unit cadence, damage percent and level, splash, self-destruction; defence cadence, shells landing late where aimed, shields (absorbing, recharging after their delay, the lower id first, gone with their generator, not covering themselves), the gravity well's hold, the EMP's stun, the later end kept, the cloaked sentry, mines once for their class, the throw trap. |
| `test/core/test_battle_field.gd` | The deploy zone (grown footprints, walls in, traps out), the deploy refusals, a deploy on a trap, units at cell centres in deploy order, the zone opening as buildings fall (a cell under two footprints opening when both have), level-0 buildings left out, every setup refusal. |
| `test/core/test_battle_pathing.gd` | A straight walk, round a building, no corner cutting, a short detour round walls, a long wall line broken through, a shut-in target waited for, the search budget and shared searches. |
| `test/core/test_battle_sim.gd` | The end (timer, 100%, no army, surrender), destruction and stars, loot spread and taken, command refusals, the result's shape, determinism (the same hash at every tick, stepped, live and replayed battles agreeing, the seed unused), a 150-building, 280-unit battle on 48×48. |
| `test/core/test_battle_targeting.gd` | Ground by path and air by straight line, preferences and their fallback, traps never targets, ties to the lowest id, a new target after a fall, the unrevealed sentry as the last resort, defences by class and range, keeping their target. |
| `test/core/test_base_state.gd` | Start layout, place and its refusals, the Command Center level checked before the limit, instant buildings, walls, timers, upgrades and their rules, moves, bad commands, the `changed` signal, the clock going backwards, the save round trip, a save from before the third resource, a version 1 save centred on a grown field (`Fixtures.catalog_with_grid`) and left in place on one that did not grow, dropping buildings that no longer fit, the army's save round trip mid-way (queues running and paused, a research), saving leaving the catalog's unit order alone, version 1 and 2 saves loading with no army, army entries that no longer fit dropped or clamped (an army above the housing kept, waiting), the abilities' save round trip (stock, levels, a making queue, an ability research), a version 5 save loading with no abilities, and ability entries that no longer fit dropped or clamped (a stock above the capacity kept, waiting). |
| `test/core/test_catalog.gd` | The shipped data (validity, start layout, affordability, curves, final levels at the top Command Center, counts; for units, prices and housing within reach, curves, final levels at the top lab; for abilities, prices within reach, curves, five levels with the last at the top lab), int conversion, level, count, resource, category, display-field, unit and ability lookups, a catalog with no abilities file and a missing one, one validation message per rule (units, abilities, `rules.army` and `rules.battle` included), the battle classes and a catalog without battle rules, the shipped battle data (a hull on every type but the traps, each special's fields at every level), the dev cheats (every level free and one second at most, nothing else changed; units free to train and research in one second at most; abilities free to make and research in one second at most; a base building what it could not afford). |
| `test/core/test_foundry.gd` | Making abilities: queue and pay, made one after another into the stock, the queue limit counting the stock and every queue, a huge count refused before it is multiplied, every refusal through its check and `apply`, no Foundry, `making_queue_of` handing out a copy, an upgrading Foundry pausing and resuming (its capacity rising when it completes), a made ability waiting for room and stocked when the capacity rises, cancel and its refund at the level paid, cancelling the head, a refund stopping at storage, cancel refusals, the dev cheats, the same commands giving the same state, and one-second ticks equal to one big tick with making and training. |
| `test/core/test_expedition_raid.gd` | An expedition's `raid_result`: a star clears the field (until a scan), none leaves it open, every `bad_expedition` (another epoch, an index out of range or missing, a cleared field, not an object, a moved building, more stored, another seed) through its check and `apply` changing nothing, a command parsed from JSON still matching, the log keeping the field's inputs (which lay it out again) and not its layout, a raid without the key unchanged. |
| `test/core/test_outpost_generator.gd` | The generator: the same inputs giving the same JSON, another index, epoch or seed differing, the field seed, no field past the last; every band at every Command Center level valid (no overlap, inside the margin, ids in order, a battle sets up, nothing dropped, counts within `max_count`, levels as the band says), the outpost level clamped, rings with exactly their band's gaps, a ring short of walls left open, deposits and hazards outside the walls, traps inside the rings and on every gap, the loot a full raid takes, no loot without capacity or a holder, the summary agreeing, the battle setup, a crowded field ending valid with drops counted; and the shipped data laying out every field at every level with nothing dropped, the hard rings closed. |
| `test/core/test_raid_result.gd` | `raid_result`: a real battle's result applied (units spent, loot home), loot capped by storage and never removing, every refusal through its check and `apply` changing nothing, a waiting unit housed in the room a raid frees, the last five raids kept, the save round trip, a version 3 save loading with none. |
| `test/core/test_production.gd` | Production starting at completion, carried remainders, tick-size independence, storage caps, caps rising when a silo finishes, busy buildings not producing, a third resource. |
| `test/core/test_research.gd` | Research: no lab, pay and level up (training at the new price), max level, lab level gating (an upgrade under way not counting), research going on while the lab upgrades, one at a time, the unit unlocked first, funds, the dev cheats; an ability's level (made at the new price, a queued one refunding its paid level), its refusals, the Foundry needed, one slot shared by units and abilities, its dev cheats; and one-second ticks equal to one big tick with a building, the research and a unit finishing in one second. |
| `test/core/test_sector.gd` | The sector: its seed from the creation time, a seed per field and epoch, cleared fields sorted and unique, its save shape and cleaning on load; in the base, a new base's sector, the free first scan and the cooldown (refusals through `check_scan` and `apply` changing nothing), a scan's new fields against the base as it is (the snapshot held until then), `sector_fields`, `generate` reading the sector, the save round trip, a version 4 save migrating from its `now`, and a catalog without expeditions. |
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

`scenarios/battle.gd` runs a scripted attack on the template base through the battle sim,
headless, and applies its result to a copy of the base (`battle.md`, **Tools**);
`scenarios/battle_view.gd` runs the same attack through the battle view on the Practice raid,
measures its cost and checks its result against a headless run (`battle-view.md`).
`scenarios/expedition.gd` lays out the template base's six expedition fields, fights the even
one with the same army and applies the result with the expedition key, then scans, headless
(`expeditions.md`).

Two scenarios check every model of the roster against the art style's contract
(`art-style.md`, **Budget and checks**): `model_gallery` (instances, outlines, kit layers,
triangle budgets, reach and height per type and level, with screenshots of every page, row and
row's first model) and `model_clash`, headless, the clash rule's check: no two moving parts of a
model cross over their whole motion, rigid and with BOB applied, and the poses at which each
touches the static body counted for review.

## Batch battles: `tools/sim_battles.gd`

```
$GODOT --headless --path . -s res://tools/sim_battles.gd -- [--seeds=10] \
    [--army=ranger:100,brawler:40] [--level=3] [--layout=<save.json>] [--out=<file.csv>]
```

A headless `SceneTree` script, run after an import, for balance (`battle.md`): N seeds of a
scripted attack on the shipped data against the template base (`TemplateBase`), or the layout
and resources of a save file, which it only reads. Each seed draws one to four deploy points and
each unit's deploy tick in the first three seconds from the tool's own `SeededRng`. It writes
one CSV row a seed (seed, ticks, destruction, stars, loot per resource, units deployed, wall
time in ms) to `--out` or stdout. The gate does not run it.

## Outposts: `tools/gen_outposts.gd`

```
$GODOT --headless --path . -s res://tools/gen_outposts.gd -- [--cc=5] [--seed=1] [--epoch=0] \
    [--index=2] [--out=<file.json>] [--ascii]
```

A headless `SceneTree` script, run after an import, for inspecting the outpost generator
(`expeditions.md`) and for the views that draw outposts: it lays out a sector's fields on the
shipped data for a player's Command Center level (`--cc`, the capacity a base of that level holds
with every storage at its count and best level) and sector seed, every field or `--index`, and
writes `{"fields": [...]}` as JSON to `--out` or stdout. `--ascii` prints each field as a map
instead of the JSON on stdout (H the Command Center, S storage, C collector, O other, D defence,
T trap, # wall, $ deposit, ! hazard). A line per field on stderr gives its band, level, counts,
loot and wall time. The gate does not run it.

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
