# Core and economy

How `src/core/` works: the catalog, the base state and its commands, time and production, the
grid, and the seeded generator. The conventions it follows are in `CLAUDE.md`, **Architecture
rules**; the data it reads is in `data-format.md`.

Everything here `extends RefCounted`, never reads a clock, holds integers only, and uses
`SeededRng` for randomness. Time arrives as unix seconds (`int`).

## Catalog (`catalog.gd`)

Read-only game data, loaded from `data/rules.json` and `data/buildings.json` by
`Catalog.load_default()`, or from two JSON strings by `Catalog.from_json(rules, buildings)`
(the tests' fixtures use this). JSON numbers that are whole are converted to `int` on load,
recursively (`_ints`); everything the catalog hands out is `int`. The one exception to
read-only is `apply_dev_cheats()`, below.

| Member | What |
| --- | --- |
| `load_error: String` | Empty when the data validated cleanly, else the problems joined by `; `. `main.gd` refuses to start on a non-empty one. |
| `resources: PackedStringArray` | The resource ids in `rules.resources` order. That order is the order production is paid and the HUD lists them. |
| `resource_name(id)`, `resource_color(id)` | A resource's display name (the id when it has none) and its HUD colour as a hex string (`""` when it has none). Core hands out no `Color`. |
| `categories: PackedStringArray` | The build-menu category ids in `rules.categories` order, the tab order. |
| `category_name(id)` | A category's display name, the id when it has none. |
| `CORE_CATEGORY` | `"core"`, the Command Center's category; never a build-menu category. |
| `grid_size: Vector2i` | `rules.grid`. |
| `menu_order: PackedStringArray` | `rules.menu_order`: every type but the Command Center, in build-menu order. |
| `start: Dictionary` | `rules.start`: starting resources and buildings. |
| `HQ_TYPE` | `"command_center"`, the building whose level gates everything. |
| `has_type`, `types()`, `display_name`, `size_of` (default 1) | Per-type lookups. |
| `category_of(type)`, `is_hidden(type)`, `targets_of(type)` | The type's `category`, `hidden` (default `false`) and `targets` (`""` when it has none). The last two are display only until the battle sim. |
| `max_level(type)` | The number of entries in the type's `levels`. |
| `level_stats(type, level)` | The stats dictionary for a 1-based level, or a shared, read-only empty dictionary when the type or level does not exist (callers only read it). |
| `max_count(type, cc_level)` | `max_count[cc_level - 1]`, with `cc_level` clamped into the list; `0` when the list is empty. |
| `max_cc_level()` | The Command Center's level count, which is the length of every `max_count` list. |
| `apply_dev_cheats()` | The dev cheats, which `main.gd` applies once after loading in a debug build unless `--no-cheats` is given (`input-camera.md`): rewrites every level of every type in place to `cost` `{}` and `build_seconds` `min(build_seconds, 1)`: a level that takes time takes one second, and an instant one (walls, the drone bay) stays instant, so it still needs no builder. Nothing else changes (`requires_cc`, `max_count`, `storage`, `produces`, `builders`), so levels still unlock in order. `BaseState` never knows, so a save made under the cheats is an ordinary save. |

Validation (`_read`, `_validate_building`) is listed in `data-format.md`.

## BaseState (`base_state.gd`)

The authoritative model of one player's base. One per player; `main.gd` holds one.

| Member | What |
| --- | --- |
| `catalog`, `grid` | The catalog it was built from and its `BaseGrid`. |
| `now: int` | The unix time the state has been advanced to. |
| `resources: Dictionary[String, int]` | Current amounts per resource. |
| `buildings: Dictionary[int, BuildingState]` | By id. Ids start at 1 and never repeat. |
| `last_added_id: int` | Id of the most recently placed building; not saved. The controller selects it after a place. |
| `_remainders: Dictionary[String, int]` | Unpaid production per resource in resource-seconds (amount × 3600). Saved. |
| `_next_id: int` | The next id to hand out. Saved. |
| `signal changed` | Emitted after anything visible changed: by `apply` on success, by `advance_to` when a timer completed or a resource amount changed. |

`BaseState.create_new(catalog, start_time)` lays out `catalog.start`: each listed building is
added finished at its listed level (one that is unknown or does not fit is skipped), then each
starting resource is set to `min(listed, capacity)`.

### Commands

`apply(command, at_time) -> String` first calls `advance_to(at_time)`, then dispatches on
`command["op"]`, and returns `""` on success or one of the error codes below. On success it
emits `changed`. A failed command changes nothing and charges nothing. The three ops, with the
`check_*` function the UI uses to ask the same question without acting:

| Command | Check | Does |
| --- | --- | --- |
| `{"op": "place", "type": String, "cell": [x, y]}` | `check_place(type, cell)` | Pays level 1's cost, adds the building with the next id, starts construction to level 1. |
| `{"op": "move", "id": int, "cell": [x, y]}` | `check_move(id, cell)` | Vacates the old footprint, sets the cell, occupies the new one. Free, instant, allowed while busy. |
| `{"op": "upgrade", "id": int}` | `check_upgrade(id)` | Pays the next level's cost and starts work to that level. |

`"cell"` may also be a `Vector2i`; anything else becomes `(-1, -1)` and fails as `blocked`.

Checks, in the order they are made:

- `check_can_build(type)` (the build menu's question, independent of where): `unknown_type`;
  `needs_command_center_level` when level 1's `requires_cc` exceeds `cc_level()`;
  `limit_reached` when `count_of(type) >= catalog.max_count(type, cc_level())`; then the rest
  of level 1's requirements. The Command Center level comes before the limit, so a type whose
  `max_count` is 0 at the current level reads as locked, not as maxed.
- `check_place(type, cell)`: `check_can_build`, then `blocked` unless `grid.is_free(cell, size)`.
- `check_move(id, cell)`: `unknown_building`; `blocked` unless the footprint is free ignoring the
  building's own cells.
- `check_upgrade(id)`: `unknown_building`; `busy` while it is under construction or upgrading;
  `max_level` at the top level; then the level requirements of the next level.
- Level requirements (`_check_level_requirements(stats)`): `needs_command_center_level` when
  `requires_cc` (default 1) exceeds `cc_level()`; `no_free_builder` when `build_seconds > 0`
  and `builders_free() <= 0`; `insufficient_resources` unless `can_afford(cost)`.

| Constant | Code |
| --- | --- |
| `ERR_UNKNOWN_OP` | `unknown_op` |
| `ERR_UNKNOWN_TYPE` | `unknown_type` |
| `ERR_UNKNOWN_BUILDING` | `unknown_building` |
| `ERR_BLOCKED` | `blocked` |
| `ERR_LIMIT` | `limit_reached` |
| `ERR_CC_LEVEL` | `needs_command_center_level` |
| `ERR_NO_BUILDER` | `no_free_builder` |
| `ERR_FUNDS` | `insufficient_resources` |
| `ERR_BUSY` | `busy` |
| `ERR_MAX_LEVEL` | `max_level` |

`Hud.ERROR_TEXT` maps these to player-facing text (`hud.md`).

### Buildings, levels and builders

A `BuildingState` (`building_state.gd`) is `id`, `type`, `cell` (top-left of the footprint),
`level`, `target_level` and `finish_at`. `level` is the finished level, `0` while first being
constructed. It is busy (`is_busy()`) while `target_level > level`; then `finish_at` is the unix
second it completes. Idle, `target_level == level` and `finish_at == 0`.

`_start_work(building, to_level)` sets `target_level` and `finish_at = now + build_seconds`;
when `build_seconds` is `0` the building completes at once (`_complete`: `level = target_level`,
`finish_at = 0`). An instant building therefore never occupies a builder, and the builder check
is skipped for it.

Builders: `builders_total()` sums the `builders` stat of every finished building (level ≥ 1) at
its current level; `builders_busy()` counts busy buildings; `builders_free()` is the
difference. `cc_level()` is the Command Center's level, at least 1, and 1 when there is none.
`count_of(type)` counts buildings of a type, busy ones included.

### Time and production

`advance_to(time)` moves the base forward. Earlier or equal times are ignored, so a clock that
goes backwards cannot undo anything. It finds the earliest completion at or before `time`
(`_next_completion`: lowest `finish_at`, ties broken by lowest id, so the order is the same on
every device), pays production for the stretch up to it, completes it, and repeats; then pays
production for the rest of the interval and sets `now`. A building that completes mid-interval
therefore produces only after it completes, and an upgrade that completes mid-interval produces
at the old rate before and the new rate after.

`_accumulate(seconds)` pays production for a stretch at the current rates, resource by resource
in catalog order:

```
pending   = remainder + rate_per_hour * seconds      (resource-seconds)
gained    = pending / 3600                           (integer division)
remainder = pending % 3600
amount    = max(amount, min(capacity, amount + gained))
```

Carrying the remainder is what makes a tick every second and a tick once a day pay the same
total (`test_production.gd`, `test_many_small_ticks_equal_one_big_tick`). Full storage stops
production but never removes what is there, so lowering a cap (a data change) leaves an amount
above it in place. The remainder keeps accumulating while storage is full; only the whole units
are discarded.

`production_per_hour(res)` sums the `produces` stat of every finished, idle building: a busy
building (constructing or upgrading) does not produce. `capacity(res)` sums the `storage` stat of
every finished building at its current level, busy or not, so storage keeps working during an
upgrade. `seconds_left(id)` is `finish_at - now`, floored at 0.

### Save and load

`to_dict()` returns the save, version 1:

```
{"version": 1, "now": int, "next_id": int,
 "resources": {res: int}, "remainders": {res: int},
 "buildings": [{"id", "type", "cell": [x, y], "level", "target_level", "finish_at"}, ...]}
```

Buildings are listed in id order, so the output is canonical and two states with the same
contents serialise to the same text (the tests compare `JSON.stringify` of two states).

`BaseState.from_dict(catalog, data)` rebuilds a state from parsed JSON (floats included;
everything is converted with `int()`). A building whose type the catalog no longer has, or whose
footprint overlaps another or overflows the grid (a data change since the save), is dropped
rather than corrupt the grid. `_next_id` becomes the larger of the saved value and the highest
loaded id plus one. `last_added_id` is not saved. Missing keys take defaults (`now` 0, `next_id`
1, amounts 0), so a save written by an older shape still loads.

`main.gd` calls `advance_to(now)` on the loaded state, which is the offline progress.

## BaseGrid (`base_grid.gd`)

Occupancy of one base: a `PackedInt32Array` of `width * height` cells holding the id of the
building on each cell, `0` for empty. A building at `cell` with footprint `size` covers
`cell.x .. cell.x + size - 1` and the same in `y`.

| Method | What |
| --- | --- |
| `in_bounds(cell, size)` | The whole footprint lies inside the grid. |
| `is_free(cell, size, ignore_id = 0)` | In bounds and every cell empty, cells owned by `ignore_id` counting as empty (so a building may move onto its own old spot). |
| `occupant_at(cell)` | The id on a cell, `0` for empty or out of bounds. |
| `occupy(id, cell, size)`, `vacate(cell, size)` | Write a footprint. |

`BaseState` keeps the grid consistent with `buildings`: `_add_building` occupies, `_move`
vacates then occupies, `from_dict` occupies only what fits. Nothing removes a building yet.

## SeededRng (`seeded_rng.gd`)

A 32-bit xorshift generator. The seed is masked to 32 bits; a zero seed becomes `0x9E3779B9`.
`next_u32()` returns the next value in `[0, 2^32)`; `range_int(low, high)` an integer in the
inclusive range (modulo bias accepted; `low` when `high <= low`); `chance(numerator,
denominator)` is true with that probability using integers only.

The same seed gives the same sequence on every device and on the server, and
`test_seeded_rng.gd` freezes the first values of seeds 1 and 12345: those expectations never
change. Today the generator draws the scenery (`BaseView`, seed 7): the terrain's noise, its
mesas, craters and channel, the rocks and the crystal outcrops; expeditions and the battle sim
will draw from it.
