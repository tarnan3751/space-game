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
preload("res://test/support/fixtures.gd")`, then `Fixtures.catalog()` or
`Fixtures.new_base(start_time)` (`data-format.md` describes the fixture base). The one
exception is `test_catalog.gd`, whose `test_shipped_*` tests load the real `data/` on purpose:
the data is valid, the start layout fits, every level's price fits the storage a base can reach
when that level unlocks, and no curve (cost, `build_seconds`, `hp`, `produces`, `storage`,
`capacity`) goes down from one level to the next.

| File | Covers |
| --- | --- |
| `test/core/test_base_grid.gd` | Bounds, occupancy, own cells counting as free. |
| `test/core/test_base_state.gd` | Start layout, place and its refusals, the Command Center level checked before the limit, instant buildings, walls, timers, upgrades and their rules, moves, bad commands, the `changed` signal, the clock going backwards, the save round trip, a save from before the third resource, dropping buildings that no longer fit. |
| `test/core/test_catalog.gd` | The shipped data (validity, start layout, affordability, curves), int conversion, level, count, resource, category and display-field lookups, one validation message per rule. |
| `test/core/test_production.gd` | Production starting at completion, carried remainders, tick-size independence, storage caps, caps rising when a silo finishes, busy buildings not producing, a third resource. |
| `test/core/test_seeded_rng.gd` | The frozen sequences for seeds 1 and 12345, range bounds, the zero seed. **These expected values never change.** |

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
   save (`--save-path=` under a temp directory), with no `SCRIPT ERROR` or `ERROR:` line.

It runs in about ten seconds. Every commit of a delivered series passes it; the reviewer runs it
again; the landing script runs it after the series is applied.

## The harness: `tools/harness/`

A scripted driver that boots the real scene on an isolated save, runs a scenario that acts
through `PlacementController`, the input signals and `BaseState`, and writes a log and
screenshots. `tools/harness/run.sh <scenario>` runs headless (logic checks);
`--rendered` opens a window and saves screenshots. `tools/harness/README.md` documents the
driver, the clock, the isolation and how to write a scenario; `scenarios/place_and_build.gd` is
the example.

## The texture generator: `tools/gen_textures.gd`

A headless `SceneTree` script that draws the material kit's sixteen layers into
`assets/textures/kit/` from one seed, byte-identical run to run:
`$GODOT --headless --path . -s res://tools/gen_textures.gd`, after an import. The gate does not
run it; the PNGs are committed. `art-style.md`, **The material kit**, says what each layer holds
and how to add one.

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
