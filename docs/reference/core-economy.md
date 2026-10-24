# Core and economy

How `src/core/` works: the catalog, the base state and its commands, time and production, the
grid, and the seeded generator. The conventions it follows are in `CLAUDE.md`, **Architecture
rules**; the data it reads is in `data-format.md`.

Everything here `extends RefCounted`, never reads a clock, holds integers only, and uses
`SeededRng` for randomness. Time arrives as unix seconds (`int`).

## Catalog (`catalog.gd`)

Read-only game data, loaded from `data/rules.json`, `data/buildings.json` and `data/units.json`
by `Catalog.load_default()`, or from JSON strings by `Catalog.from_json(rules, buildings,
units = "{}")` (the tests' fixtures use this; left out, `units` is no unit types, and an empty
string, a missing file, is a load error). JSON numbers that are whole are converted to `int` on load,
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
| `housing_type`, `research_type` | `rules.army`: the building type whose `capacity` houses the army (`hangar`) and the one that researches unit levels (`research_lab`). `""` when the rules have none. |
| `unit_order`, `unit_types()` | The unit type ids in `units.json` order, the training menu's order. |
| `has_unit`, `unit_name` (the id when it has none), `unit_producer`, `unit_producer_level`, `unit_class`, `unit_crew`, `unit_housing`, `unit_train_seconds` | Per-unit lookups. `unit_class` is `ground` or `air`; `unit_crew` is `human`, `piloted` or `autonomous`, display and models only. |
| `units_of_producer(building_type)` | The unit types a building type trains, in `units.json` order. It builds a new array, so it is for the HUD, not for a per-frame check. |
| `unit_max_level(type)`, `unit_level_stats(type, level)` | A unit's level count, and the stats of a 1-based level, the same shared read-only empty dictionary as `level_stats` when the type or level does not exist. |
| `apply_dev_cheats()` | The dev cheats, which `main.gd` applies once after loading in a debug build unless `--no-cheats` is given (`input-camera.md`): rewrites every level of every type in place to `cost` `{}` and `build_seconds` `min(build_seconds, 1)`: a level that takes time takes one second, and an instant one (walls, the drone bay) stays instant, so it still needs no builder. Every unit's `train_seconds` becomes `min(train_seconds, 1)`, every level's `train_cost` and `research_cost` `{}`, and every `research_seconds` `min(research_seconds, 1)`. Nothing else changes (`requires_cc`, `max_count`, `storage`, `produces`, `builders`, `producer_level`, `requires_lab`, `housing`), so levels and units still unlock in order. `BaseState` never knows, so a save made under the cheats is an ordinary save. One quirk follows, in development builds only: a unit queued under the cheats (paid `{}`) and cancelled in a later `--no-cheats` run refunds the catalog's `train_cost` at its paid level, not the nothing it was charged. |

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
| `army: Dictionary[String, int]` | Units housed, per unit type; every catalog unit has an entry, 0 by default. |
| `unit_levels: Dictionary[String, int]` | Each unit type's level, for the whole type; every catalog unit has an entry, 1 by default. |
| `training: Dictionary[int, TrainingQueue]` | Training queues by producer building id (**The army**). A queue stays when it empties. |
| `research_unit: String`, `research_done_at: int` | The unit type being researched to its next level (`""` when none) and the unix second it completes. |
| `signal changed` | Emitted after anything visible changed: by `apply` on success, by `advance_to` when a timer completed or a resource amount changed. |

`BaseState.create_new(catalog, start_time)` lays out `catalog.start`: each listed building is
added finished at its listed level (one that is unknown or does not fit is skipped), then each
starting resource is set to `min(listed, capacity)`.

### Commands

`apply(command, at_time) -> String` first calls `advance_to(at_time)`, then dispatches on
`command["op"]`, and returns `""` on success or one of the error codes below. On success it
emits `changed`. A failed command changes nothing and charges nothing. The ops, with the
`check_*` function the UI uses to ask the same question without acting:

| Command | Check | Does |
| --- | --- | --- |
| `{"op": "place", "type": String, "cell": [x, y]}` | `check_place(type, cell)` | Pays level 1's cost, adds the building with the next id, starts construction to level 1. |
| `{"op": "move", "id": int, "cell": [x, y]}` | `check_move(id, cell)` | Vacates the old footprint, sets the cell, occupies the new one. Free, instant, allowed while busy. |
| `{"op": "upgrade", "id": int}` | `check_upgrade(id)` | Pays the next level's cost and starts work to that level. |
| `{"op": "train", "id": int, "unit": String, "count": int}` | `check_train(id, unit, count)` | Pays `count` times the unit's `train_cost` at its current level and queues `count` of it at producer `id`. `count` is optional (1); all or nothing. |
| `{"op": "cancel_training", "id": int, "unit": String}` | `check_cancel_training(id, unit)` | Removes the newest queued `unit` from producer `id`'s queue and refunds its `train_cost` at the level it was paid for, up to storage. |
| `{"op": "research", "unit": String}` | `check_research(unit)` | Pays the unit's next level's `research_cost` and starts its research, `research_seconds` long. |

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
- `check_train(id, unit, count = 1)`: `unknown_unit`; `unknown_building`; `not_a_producer`
  unless the building's type is the unit's `producer`; `bad_count` below 1;
  `needs_producer_level` while the building's finished level is below the unit's
  `producer_level` (a building under first construction is level 0); `not_enough_housing`
  when `count` exceeds `housing_capacity()` (checked before anything is multiplied by `count`,
  so no product can overflow) or unless `housing_used() + housing_queued() + count × housing
  <= housing_capacity()`;
  `insufficient_resources` unless `can_afford(train_cost, count)`.
- `check_cancel_training(id, unit)`: `unknown_building`; `not_queued` unless the building's
  queue holds the unit.
- `check_research(unit)`: `unknown_unit`; `max_level` at the unit's top level;
  `needs_producer_level` unless `is_unit_unlocked(unit)`; `needs_lab_level` while
  `lab_level()` is below the next level's `requires_lab`; `busy` while a research runs;
  `insufficient_resources`.
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
| `ERR_UNKNOWN_UNIT` | `unknown_unit` |
| `ERR_NOT_PRODUCER` | `not_a_producer` |
| `ERR_BAD_COUNT` | `bad_count` |
| `ERR_PRODUCER_LEVEL` | `needs_producer_level` |
| `ERR_HOUSING` | `not_enough_housing` |
| `ERR_NOT_QUEUED` | `not_queued` |
| `ERR_LAB_LEVEL` | `needs_lab_level` |

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

The building checks allocate nothing per call, measured with a malloc counter on the
development Mac: the HUD runs them every frame while a ghost is dragged, and the server will run
them per command. Neither does `advance_to` while no timer completes, and the building ops
allocate only the building a place adds. So the queries above iterate `for id: int in
buildings` (not `buildings.values()`, which builds an Array), and the lookups on these paths
default to shared read-only constants instead of a `{}` or `[]` literal. The army's hot paths
(`advance_to` with no event, `_next_training`, `check_train`, `check_cancel_training`,
`check_research`, the housing sums, `lab_level`, `is_unit_unlocked`, `training_status`,
`training_seconds_left`) allocate nothing by construction, verified by reading, not with the
malloc counter. `queue_of` and `Catalog.units_of_producer` build a new array per call and are
for the HUD on `changed`, not per frame. A `train` grows its queue's packed arrays and creates
the queue on a producer's first train, and a unit finishing removes it from its queue.

### The army: training and housing

Each producer building trains from a queue of its own, a `TrainingQueue`
(`training_queue.gd`): `building_id`; `units`, the queued unit types oldest first, `units[0]`
being the head, the one in training; `paid_levels`, the level each was paid for; and the head's
clock, `done_at` (the unix second it completes, while running) or `left` (its seconds still to
go, while stopped). Several producers of one type train side by side, each from its own queue;
a command names the building. A building trains a unit from the moment its finished level
reaches the unit's `producer_level`.

- **Time runs only while the producer is idle.** An `upgrade` of the producer stops its queue
  with the time left; the upgrade completing restarts it from there. A queued unit while the
  producer is busy waits in line as usual.
- **A head is housed when it finishes, if there is room**; otherwise it waits (`left` 0) and
  the queue behind it with it, until there is room, then is housed at once, whether or not its
  producer has become busy since: a busy producer only stops the clock, and the next head then
  waits for the upgrade with its full time. When room appears, the lowest-id queue whose head
  fits is housed first, and a lower id whose head does not fit is passed over (one housing free,
  a flyer waiting at id 4 and a grunt at id 5: the grunt is housed).
- `_resume_training()` brings every queue in line after each successful command and after each
  completion in `advance_to`, in two passes: the pause and resume pass, which stops a busy
  producer's running head and starts an idle producer's stopped one, treats each queue on its
  own, so its order does not matter; the housing pass then goes by producer id as above.
- **The queue limit is the housing**: the army plus every queue, the new units included, must
  fit `housing_capacity()`, so a queue always fits when it finishes and only an army above the
  housing (a save after a data change lowered it) waits. This is revisited when battles spend
  units: queueing the next army while the first is out is a change to that check alone.
- **Cancel** refunds the newest queued unit of the type at the level it was paid for, up to
  storage, never removing what is there. Cancelling the head starts the next unit from the
  beginning.

Housing: `housing_capacity()` is the `capacity` of every finished building of
`catalog.housing_type` (the Hangar) at its current level, busy or not, like storage, so a Hangar
being upgraded keeps housing at its old level until the upgrade completes. `housing_used()` is
each type's count times its `housing`; units still in training are not housed and count only
in `housing_queued()`. An army above the housing is kept as it is.

Queries for the HUD: `army_count(unit)`, `unit_level(unit)`, `queue_of(id) ->
PackedStringArray`, `training_status(id)` (`TRAINING_IDLE`, `TRAINING_RUNNING`,
`TRAINING_PAUSED` while the head has time left and the producer is busy, `TRAINING_WAITING`
for a head that has trained and waits for room, busy producer or not),
`training_seconds_left(id)` (0 while waiting), and the three housing sums. `can_afford(cost,
times = 1)` answers for `times` of a price.

### The army: research

One research runs at a time, in the research building (`catalog.research_type`, the Research
Lab): `research_unit` and `research_done_at`. A unit's level belongs to its whole type
(`unit_levels`): the army trains at it, and a unit already queued keeps the price it was paid.
Researching level k + 1 needs the unit unlocked (`is_unit_unlocked`: some producer of its type
has a finished level of at least its `producer_level`) and `lab_level()`, the research
building's highest finished level (0 without one), at least that level's `requires_lab`. It
needs no builder, and the research building's own upgrade neither stops it nor counts until it
completes. When it completes, `unit_levels[unit]` rises by one and the slot empties. There is
no cancel. `research_seconds_left()` is the time left, 0 when none runs.

### Time and production

`advance_to(time)` moves the base forward. Earlier or equal times are ignored, so a clock that
goes backwards cannot undo anything. It finds the earliest completion at or before `time`, a
building (`_next_completion`: lowest `finish_at`, ties broken by lowest id), the research, or a
training head (`_next_training`: lowest `done_at`, ties broken by lowest producer id); in the
same second buildings come first, then the research, then training, so the order is the same on
every device; pays production for the
stretch up to it, completes it, brings the training queues in line, and repeats; then pays
production for the rest of the interval and sets `now`. Ticking every second or once gives the
same state (`test_training.gd`, `test_ticks_of_one_second_equal_one_big_tick`). A building that completes mid-interval
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

`to_dict()` returns the save, version 3 (`SAVE_VERSION`), with the field it was laid out on and
the army:

```
{"version": 3, "grid": {"width": int, "height": int}, "now": int, "next_id": int,
 "resources": {res: int}, "remainders": {res: int},
 "buildings": [{"id", "type", "cell": [x, y], "level", "target_level", "finish_at"}, ...],
 "army": {unit: int}, "unit_levels": {unit: int}, "research": {"unit", "done_at"} or {},
 "training": [{"building", "units": [unit, ...], "paid_levels": [int, ...], "done_at", "left"}, ...]}
```

Buildings and training queues are listed in id order, and `army` and `unit_levels` in sorted
unit order with only what differs from a new base (a count above 0, a level above 1); an empty
queue is left out. So the output is canonical and two states with the same
contents serialise to the same text (the tests compare `JSON.stringify` of two states).

`BaseState.from_dict(catalog, data)` rebuilds a state from parsed JSON (floats included;
everything is converted with `int()`). A building whose type the catalog no longer has, or whose
footprint overlaps another or overflows the grid (a data change since the save), is dropped
rather than corrupt the grid. `_next_id` becomes the larger of the saved value and the highest
loaded id plus one. `last_added_id` is not saved. Missing keys take defaults (`now` 0, `next_id`
1, amounts 0), so a save written by an older shape still loads. A version 1 save, or one with no
version, was laid out on the 40×40 field (`V1_FIELD`): before the fit check each of its buildings
moves by half the field's growth since, `(grid_size - V1_FIELD) / 2` floored at zero per axis,
(4, 4) on 48×48, so the base stays centred; a field that did not grow (the fixture's 10×10) moves
nothing. A version 2 save loads where it was; its `grid` is recorded for later migrations, not
read. A version 1 or 2 save has no army keys, so it loads with no army, every unit at level 1,
no queues and no research; the next save is version 3.

The army loads after the buildings (`_load_army`), and what a data change has made wrong is
dropped or clamped: an army count or level of a unit the catalog no longer has is dropped, a
level above a unit's top is clamped to it, a research of an unknown unit or of one at its top is
dropped, and a queue whose building is gone or already has a queue is dropped, as is a queued
unit its building no longer trains (a paid level is clamped into the unit's levels). A queue
whose head was dropped starts its new head afresh; one left empty is dropped. An army above the
housing is kept. `_resume_training()` then runs once, which leaves a consistent save as it was.

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
