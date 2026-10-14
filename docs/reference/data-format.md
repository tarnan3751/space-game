# Data format

The JSON under `data/` and the save file. `Catalog` (`core-economy.md`) loads and validates the
game data; the server will load the same files. Change numbers here, not in code. The tests
load their own copy of the same shape from `test/support/fixtures/`, never `data/`.

Godot parses every JSON number as a float; `Catalog` converts whole numbers to `int` on load.
A non-whole number stays a float and fails validation wherever an int is required.

## `data/rules.json`

```json
{
  "resources": ["metal", "crystal"],
  "grid": { "width": 40, "height": 40 },
  "menu_order": ["metal_extractor", "crystal_harvester", "metal_silo", "crystal_silo",
                 "drone_bay", "laser_turret"],
  "start": {
    "resources": { "metal": 750, "crystal": 750 },
    "buildings": [
      { "type": "command_center", "cell": [18, 18], "level": 1 },
      { "type": "drone_bay", "cell": [24, 19], "level": 1 }
    ]
  }
}
```

| Field | What |
| --- | --- |
| `resources` | The resource names, in the order production is paid out and the HUD shows them. Must not be empty. |
| `grid` | `width` and `height` in cells, both positive. |
| `menu_order` | The build bar's buttons, top to bottom. Every entry must be a type in `buildings.json`. |
| `start.resources` | Starting amounts; each is capped at the starting base's capacity. |
| `start.buildings` | Placed finished at `level` (default 1) when a new base is created. `cell` is the footprint's top-left. An entry of an unknown type is a load error; one that does not fit the grid is skipped. |

## `data/buildings.json`

An object keyed by building type. Each type:

```json
"metal_extractor": {
  "name": "Metal Extractor",
  "size": 3,
  "max_count": [2, 4, 6],
  "levels": [
    { "cost": { "crystal": 150 }, "build_seconds": 10, "hp": 400, "produces": { "metal": 1800 } },
    { "cost": { "crystal": 400 }, "build_seconds": 60, "hp": 500, "produces": { "metal": 3600 } },
    { "cost": { "crystal": 1200 }, "build_seconds": 300, "hp": 650, "requires_cc": 2,
      "produces": { "metal": 7200 } }
  ]
}
```

| Field | What |
| --- | --- |
| `name` | Display name. Defaults to the type key. |
| `size` | Footprint side in cells, 1 to 8. Buildings are square. |
| `max_count` | How many a base may own, indexed by Command Center level (entry 0 is level 1). A level beyond the list uses the last entry. Must not be empty. |
| `levels` | One entry per level, level 1 first. Must not be empty; its length is the type's max level. |

Per level:

| Field | Used by | What |
| --- | --- | --- |
| `cost` | core | `{resource: int}` paid when construction or the upgrade to this level starts. `{}` is free. |
| `build_seconds` | core | Required, a whole non-negative number. `0` completes at once and needs no builder. |
| `requires_cc` | core | The Command Center level needed to start this level. Default 1. |
| `produces` | core | `{resource: int}` per hour while the building is at this level and idle. |
| `storage` | core | `{resource: int}` added to the base's capacity while the building is at this level, busy or not. |
| `builders` | core | Builders (drones) this level supplies. |
| `hp` | HUD | Shown as "Hull". Reserved for the battle sim. |
| `damage`, `range_cells` | HUD | Shown as "Damage / Range" when `damage` exists. Reserved for the battle sim. |
| `fire_ms` | nothing yet | Reserved for the battle sim. |

The type `command_center` must exist: its level is `cc_level()`. One type's `size` applies to
every level; a building cannot change footprint when it upgrades.

### Validation

`Catalog.load_error` collects every problem; the game refuses to start on any:

- `rules.resources` empty; `rules.grid` without a positive width and height.
- No `command_center` in `buildings.json`.
- A `menu_order` or `start.buildings` entry naming an unknown type.
- Per type: `size` outside 1–8; `max_count` empty; `levels` empty.
- Per level: `build_seconds` missing, negative or not whole; a `cost`, `produces` or `storage`
  entry naming an unknown resource or holding a non-whole number.

`test_catalog.gd` checks the shipped files load cleanly and that the start layout fits.

## The shipped data

Two resources (metal, crystal), a 40×40 grid, seven types: `command_center` (4×4, three
levels, the storage), `metal_extractor` and `crystal_harvester` (3×3, produce), `metal_silo` and
`crystal_silo` (3×3, storage), `drone_bay` (2×2, instant, one builder) and `laser_turret` (3×3,
`damage`/`range_cells`/`fire_ms`, nothing yet). The values are fast development values, not
tuned.

## The fixture catalog (`test/support/fixtures/`)

The same two files in miniature for logic tests: a 10×10 grid, 500/500 to start, a 2×2 Command
Center at (0, 0) (storage 1000/1000; level 2 costs 400 metal and takes 100 s), a 1×1 drone bay at
(3, 0) with one builder, and three types chosen for round numbers: `extractor` (2×2, 100
crystal, 60 s, 3600 metal/h = 1 per second), `harvester` (1×1, 50 metal, instant, 1800
crystal/h = 1 per 2 s, max 1) and `silo` (2×2, 100 metal, 30 s, +1000 metal storage).
`test/support/fixtures.gd` loads it (`Fixtures.catalog()`, `Fixtures.new_base(start_time)`).
Rebalancing `data/` never touches it.

## The save file

`user://base.json` by default; a `--save-path=<file>` user argument (after `--` on the command
line) replaces it, which is how the gate and the harness keep off the real save. Written by
`main.gd` as the pretty-printed `BaseState.to_dict()`:

```json
{
  "version": 1,
  "now": 1760400000,
  "next_id": 4,
  "resources": { "metal": 750, "crystal": 600 },
  "remainders": { "metal": 0, "crystal": 0 },
  "buildings": [
    { "id": 1, "type": "command_center", "cell": [18, 18], "level": 1, "target_level": 1, "finish_at": 0 }
  ]
}
```

Saved every 10 ticks (10 s) and when the window closes or the app is paused. On load, buildings
of unknown types or that no longer fit are dropped, missing keys take defaults, and the state is
advanced to the current time for offline progress. An unreadable file starts a new base. A
change to this shape keeps old saves loading or bumps `version` with a migration (`CLAUDE.md`,
**Agent workflow**, tier A).
