# Expeditions

How `src/core/expedition/` works: the sector of fields a base can raid, and the outpost generator
that lays out a rival colony on each field for the battle sim (`battle.md`) to fight. This is
`docs/vision.md` §3.4 in core; the sector map screen and the outpost's faction tint are the game
layer's, later. The data is `rules.expedition` (`data-format.md`).

Everything here `extends RefCounted`, like the rest of `src/core`: no clock, integers only, ties
broken by order, and every draw from one `SeededRng` per field.

## Modules

| File | Class | Holds |
| --- | --- | --- |
| `sector.gd` | `Sector` | A base's sector: its seed, the epoch, the fields cleared this epoch, the last scan, and the snapshot of the base the epoch's fields are laid out against; the seeds; the save shape. |
| `outpost_generator.gd` | `OutpostGenerator` | A field's layout, its band, its loot; the summary the map shows; the battle setup for a field. |

## The sector

A sector is not stored as fields: field `index` of `epoch` is derived from the sector's seed, so
the save holds only `{seed, epoch, cleared, last_scan, cc, capacity}`.

- **The seed**: `Sector.seed_from_time(t)` mixes `SEED_SALT` with the unix time the base was
  created (`BaseState.create_new`), or, for a save from before the sector existed, its saved
  `now` (0 when it has none). Never `randi()`.
- **Field seeds**: `Sector.field_seed_of(seed, epoch, index)` mixes `FIELD_SALT` with the three,
  32-bit FNV-1a steps like the battle hash's. It seeds the generator and is the battle's `seed`
  (and the view's scenery seed).
- **The snapshot**: `cc` and `capacity` are the player's Command Center level and storage
  capacity when the epoch began (at the base's creation, at the migration of an older save, then
  at each scan). Fields are laid out against them, not against the live base, so a field stays
  the same while the base grows, a battle's defender can be laid out again to check it, and the
  server can lay it out from the save.
- **The fields**: `rules.expedition.bands` in order, each covering `fields` indices (two easy, two
  even, two hard in the shipped data); `Catalog.expedition_field_count()` is their sum.
- `cleared` is sorted; `clear_field(i)` keeps it so. `from_dict(catalog, data, now)` cleans a
  loaded sector: the level clamped into the Command Center's, cleared entries kept only when
  they are whole field indices (0 to the field count less one), once each, capacity for the
  catalog's resources only, and `last_scan` brought back to `now` when it is later, so a clock
  set back costs at most one cooldown.

## The base's sector

`BaseState.sector` holds it (`core-economy.md`, **Expeditions**): `create_new` seeds it and takes
the snapshot, `from_dict` migrates an older save, `{"op": "scan"}` (`check_scan`,
`scan_cooldown`) starts the next epoch once `rules.expedition.scan_seconds` have passed since the
last (the first scan is free), and `sector_fields()` and `scan_seconds_left()` are the map's
queries. `OutpostGenerator.generate(catalog, state, index)` lays out a field of the base's sector.

## The outpost generator

`OutpostGenerator.generate_field(catalog, sector_seed, epoch, index, player_cc, capacity)` lays
out one field; it is a pure function of its inputs and the catalog, and the same inputs give the
same dictionary, byte for byte, in `JSON.stringify` (`test_outpost_generator.gd`). An index that
is not a field gives `{}`.

```
{"seed": int, "index": int, "band": "even", "cc": int,
 "defender": {"buildings": [{"id", "type", "level", "cell": [x, y]}...], "resources": {res: n}},
 "loot": {res: n}, "deposits": [id...], "hazards": [id...],
 "rings": [{"rect": [x, y, width, height], "gaps": [[x, y]...]}...], "dropped": n}
```

`defender` is the battle setup's (`battle.md`, **The setup and the commands**), with ids 1..n in
placement order; `OutpostGenerator.battle_setup(field, army, unit_levels)` builds the whole setup
with no commands. `rings` are the wall rings, inner first, each with the middle cell of every gap;
`dropped` counts the buildings no room was left for (0 on the shipped data at every level, which
`test_shipped_data_lays_out_every_field` checks).

### The plan

- **Band**: `catalog.expedition_band(index)`.
- **Outpost Command Center**: the player's (`cc`) plus the band's `cc_offset`, clamped to 1..the
  top level (`outpost_cc`).
- **Counts** (`plan`): one Command Center; every other type `density_pct` of its `max_count` at
  that level, rounded half up, never above it, so a type allowed once still appears in easy.
  Walls are counted the same way.
- **Levels** (`outpost_level`): the highest level whose `requires_cc` the outpost's Command Center
  allows, plus the band's `level_offset` (−1 for easy), never below 1.
- **Roles**, from `Catalog.battle_class` and the level's stats, never from type names: the hq; the
  wall; traps; defences; storages (resource class with `storage`); collectors (resource class
  without); other (the army buildings, the lab, the drone bay).

### The layout, step by step

Every footprint stays inside the **margin box**, the field less `margin` cells on every side, so
a deploy zone exists all round. The rectangles are nested squares round a centre drawn from the
field's middle with `jitter`; from the inside out:

1. **Deposits** are the band's `deposits` storages, taken from the storages (the type with the
   most copies left each time, its last copy), so every count stays within `max_count`.
2. **The draws**, in this order: a shuffle of the storages, the other buildings, the defences and
   the collectors (Fisher-Yates); the jitter on x and y; the spiral's rotation and mirror (below).
   **Hazards** are then the first `hazards` × deposits defences of the shuffled list.
3. **The compound**: the Command Center, then the storages, then the other buildings. Its side is
   the square root of their area times `slack_pct`, and at least the Command Center's size plus
   two. While ring 1 round it would need more walls than the outpost has (less its gaps), the last
   member moves out to the middle band. The Command Center sits at the compound's centre; the
   members, largest first, at the first cell of a spiral from the centre where they fit inside the
   compound, packed tight; a member that does not fit moves out too.
4. **Ring 1**: walls along the square round the compound, clockwise from a drawn cell, with the
   band's `wall_gaps` runs of `wall_gap_cells` cells left open, evenly spaced. When the walls run
   out first (easy at the lowest levels), the rest of the ring is open.
5. **Ring 2**, round the middle band, when the walls left cover it with its gaps; otherwise there
   is none and the walls left are not placed. Both rings go down before anything outside the
   compound, and every gap cell is reserved (only a trap may take it), so nothing sits on a ring
   or closes a gap.
6. **The middle band** between the rings: its depth holds `slack_pct` of the area of the moved
   members and the defences with `spacing`, giving way first to the outer zone's need, then to the
   box. The moved members, largest first, take the first spiral cells from the compound's centre
   inside the band; then the defences, sorted by `range_cells` (ties in their shuffled order):
   the shorter-ranged half on the track two cells outside ring 1, the longer-ranged half further
   out, each at a slot spread evenly along its track from a drawn start, at the first spiral cell
   from its slot that fits with `spacing` free cells round it (walls and traps do not count).
7. **The outer zone**, outside the outermost ring: the deposits are put at drawn places among the
   collectors, and slots are spread along the track two cells outside ring 2 (outside the square
   ring 2 would take when it is not built). The deposits go
   first, each with its hazards on the nearest free spiral cells, then the collectors.
8. **Traps**: one 1×1 trap on the middle cell of each gap, inner ring first; the rest on drawn
   free cells inside the outermost ring, then inside the middle band when those run out (the
   candidates listed once per size in cell order; a drawn cell that no longer fits is struck off).

**The spiral** visits the square rings round its anchor outwards, each ring in the field's drawn
rotation (0–3 quarter turns) and mirror, so it visits every cell of its area once and every
search ends. **The fallback**: a building with no room in its zone is searched for over the whole
margin box with no spacing, from the same anchor; one that still finds none is dropped. A zone
that had no room for a size is remembered as full for that size and larger (the field only
fills), so a crowded field does not search it again.

### The loot profile

Per resource, the **target** is the band's `loot_pct` of the snapshot's capacity, when a placed
building other than a wall or a trap (which hold no loot share in the battle) stores or produces
it and `rules.battle.loot_pct` is not 0;
otherwise 0 (antimatter, for one, while the player stores none). The outpost's `resources` are
`ceil(target × 100 / loot_pct)`, so `floor(stored × loot_pct / 100)`, what the battle spreads over
the buildings that hold it (`battle.md`, **Destruction, stars and loot**), is the target exactly:
a raid that destroys every holder takes it. A deposit is a storage, so it takes its share by the
same rule.

`OutpostGenerator.summary(catalog, sector, index)` gives `{index, band, cc, loot, seed}` from
the plan alone, without laying the field out: the loot counts a type as held when its planned
count is above 0, walls and traps left out as in the field.

### Cost

Laying out a field takes 1 to 15 ms headless on the development Mac on the shipped data, the
hard fields at the top levels the most; the six fields at Command Center 10 take about 55 to 95
ms (`tools/gen_outposts.gd` prints the times). Nothing lays a field out per frame: the map
reads the summaries, and a field is laid out when it is opened, fought or checked.

## Tools

`tools/gen_outposts.gd` writes a sector's fields as JSON and can print each as a map
(`testing-tools.md`).
