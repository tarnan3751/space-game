# Data format

The JSON under `data/` and the save file. `Catalog` (`core-economy.md`) loads and validates the
game data; the server will load the same files. Change numbers here, not in code. The tests
load their own copy of the same shape from `test/support/fixtures/`, never `data/`.

Godot parses every JSON number as a float; `Catalog` converts whole numbers to `int` on load.
A non-whole number stays a float and fails validation wherever an int is required.

## `data/rules.json`

```json
{
  "resources": [
    { "id": "metal", "name": "Metal", "color": "a8c0dc" },
    { "id": "crystal", "name": "Crystal", "color": "e2a4ff" },
    { "id": "antimatter", "name": "Antimatter", "color": "b48cff" }
  ],
  "categories": [
    { "id": "resources", "name": "Resources" },
    { "id": "army", "name": "Army" },
    { "id": "defense", "name": "Defence" },
    { "id": "traps", "name": "Traps" }
  ],
  "grid": { "width": 48, "height": 48 },
  "menu_order": ["drone_bay", "metal_extractor", "crystal_harvester", "antimatter_siphon",
                 "metal_silo", "crystal_silo", "antimatter_vault", "hangar", "cadet_academy",
                 "...", "mega_mine", "barrier_wall"],
  "start": {
    "resources": { "metal": 750, "crystal": 750, "antimatter": 0 },
    "buildings": [
      { "type": "command_center", "cell": [22, 22], "level": 1 },
      { "type": "drone_bay", "cell": [28, 23], "level": 1 }
    ]
  }
}
```

`menu_order` is abbreviated here; the file lists every type but the Command Center.

| Field | What |
| --- | --- |
| `resources` | The resources, in the order production is paid out and the HUD shows them. Each is `{ "id", "name", "color" }`: the id that costs, rates and saves use; the display name (defaults to the id); and the HUD colour as a hex string without `#` (optional; the HUD falls back to its text colour). Must not be empty. |
| `categories` | The build-menu categories in tab order, each `{ "id", "name" }` (the name defaults to the id). Every type but the Command Center belongs to one. `core`, the Command Center's category, is never listed. |
| `grid` | `width` and `height` in cells, both positive. |
| `menu_order` | The build menu's types in order: every type except `command_center`, exactly once. Within a category, this is the order the HUD lists them. |
| `start.resources` | Starting amounts; each is capped at the starting base's capacity. A resource left out starts at 0. |
| `start.buildings` | Placed finished at `level` (default 1, and one of the type's levels) when a new base is created. `cell` is the footprint's top-left. An entry of an unknown type is a load error; one that does not fit the grid is skipped. |

## `data/buildings.json`

An object keyed by building type. Each type:

```json
"flak_mine": {
  "name": "Flak Mine",
  "size": 1,
  "category": "traps",
  "hidden": true,
  "targets": "air",
  "max_count": [0, 0, 0, 2, 4],
  "levels": [
    { "cost": { "metal": 4000 }, "build_seconds": 60, "requires_cc": 4, "damage": 100,
      "range_cells": 3 },
    { "cost": { "metal": 10000 }, "build_seconds": 180, "requires_cc": 4, "damage": 130,
      "range_cells": 3 },
    { "cost": { "metal": 25000, "antimatter": 20 }, "build_seconds": 360, "requires_cc": 5,
      "damage": 160, "range_cells": 3 }
  ]
}
```

| Field | What |
| --- | --- |
| `name` | Display name. Defaults to the type key. |
| `size` | Footprint side in cells, 1 to 8. Buildings are square. |
| `category` | Required. One of `rules.categories`; `core` for `command_center`, and only for it. |
| `hidden` | Optional, default `false`. Hidden from an attacker until it triggers: the traps and the Cloaked Sentry. Display only until the battle sim. |
| `targets` | Optional: `"ground"`, `"air"` or `"both"`, on the defences and traps that attack. Display only until the battle sim. |
| `max_count` | How many a base may own at each Command Center level: exactly one whole, non-negative entry per Command Center level (entry 0 is level 1). It is 0 below the type's unlock level (level 1's `requires_cc`) and above 0 at it. |
| `levels` | One entry per level, level 1 first. Must not be empty; its length is the type's max level. |

Per level:

| Field | Used by | What |
| --- | --- | --- |
| `cost` | core | `{resource: int}` paid when construction or the upgrade to this level starts. `{}` is free. |
| `build_seconds` | core | Required, a whole non-negative number. `0` completes at once and needs no builder. |
| `requires_cc` | core | The Command Center level needed to start this level, 1 to the Command Center's level count. Default 1. Level 1's is the type's unlock level. |
| `produces` | core | `{resource: int}` per hour while the building is at this level and idle. |
| `storage` | core | `{resource: int}` added to the base's capacity while the building is at this level, busy or not. |
| `builders` | core | Builders (drones) this level supplies. |
| `capacity` | HUD | Army capacity (the Hangar, the Alliance Beacon), shown as "Capacity". Unrelated to `BaseState.capacity(res)`, which is storage. Reserved for the army. |
| `hp` | HUD | Shown as "Hull". Reserved for the battle sim. |
| `damage`, `range_cells` | HUD | Shown as "Damage N   Range N", each part when the level has it. `range_cells` is the reach in cells, a trap's blast radius, or the Shield Generator's bubble radius. Reserved for the battle sim. |
| `fire_ms` | HUD | Milliseconds between shots, shown as "Fires every N s". Reserved for the battle sim. |

`builders`, `capacity`, `hp`, `damage`, `range_cells` and `fire_ms` are whole and non-negative
when present.

The type `command_center` must exist: its level is `cc_level()`. One type's `size` applies to
every level; a building cannot change footprint when it upgrades.

### Validation

`Catalog.load_error` collects every problem; the game refuses to start on any:

- A value of the wrong shape, reported rather than read: `rules.resources`,
  `rules.categories`, `rules.menu_order`, `rules.start.buildings`, and a type's `levels` and
  `max_count` must be lists; `rules.start`, `rules.start.resources`, each type, each level,
  each start entry, and each `cost`, `produces` and `storage` must be objects; a start entry's
  `cell` must be `[x, y]`; a starting amount must be whole and non-negative.
- `rules.resources` empty; a `rules.resources` or `rules.categories` entry without an id, or an
  id listed twice; a resource `color` that is not a hex colour; `rules.categories` listing
  `core`; `rules.grid` without a positive width and height.
- No `command_center` in `buildings.json`.
- A `menu_order` entry naming an unknown type, `command_center`, or a type twice; a type other
  than `command_center` missing from `menu_order`.
- A `start.buildings` entry naming an unknown type or a level the type does not have.
- Per type: `size` outside 1–8; `category` other than `core` for `command_center`, or not one
  of `rules.categories` for any other type; `hidden` not a bool; `targets` not ground, air or
  both; `levels` empty; `max_count` empty, not one entry per Command Center level, holding a
  negative or non-whole entry, or not 0 below level 1's `requires_cc` and above 0 at it.
- Per level: `build_seconds` missing, negative or not whole; `requires_cc` outside 1 to the
  Command Center's level count; `builders`, `capacity`, `hp`, `damage`, `range_cells` or
  `fire_ms` negative or not whole; a `cost`, `produces` or `storage` entry naming an unknown
  resource or holding a non-whole number.

`test_catalog.gd` checks that the shipped files load cleanly, that the start layout fits, that
every level's price fits the storage a base can reach when that level unlocks, that no curve
goes down from one level to the next, that every type's final level requires the top Command
Center level, and that no count goes down from one Command Center level to the next
(`testing-tools.md`).

## The shipped data

Three resources: metal, crystal, and antimatter (rare: unlocked at Command Center 4, produced
slowly, spent only on top-tier levels). A 48×48 grid, the Command Center with ten levels, and
32 types in four build-menu categories. The ids are final.

| Category | Type | Name | Size | Unlock (CC) | Levels | `max_count` at CC 1–10 | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| core | `command_center` | Command Center | 4 | 1 | 10 | 1,1,1,1,1,1,1,1,1,1 | stores all three resources |
| resources | `drone_bay` | Drone Bay | 2 | 1 | 3 | 2,3,4,5,5,5,5,5,5,5 | one builder; instant |
| resources | `metal_extractor` | Metal Extractor | 3 | 1 | 10 | 2,3,4,5,6,6,6,7,7,7 | produces metal |
| resources | `crystal_harvester` | Crystal Harvester | 3 | 1 | 10 | 2,3,4,5,6,6,6,7,7,7 | produces crystal |
| resources | `antimatter_siphon` | Antimatter Siphon | 3 | 4 | 8 | 0,0,0,1,2,2,3,3,3,4 | produces antimatter |
| resources | `metal_silo` | Metal Silo | 3 | 1 | 10 | 1,2,3,4,4,4,4,4,4,4 | stores metal |
| resources | `crystal_silo` | Crystal Silo | 3 | 1 | 10 | 1,2,3,4,4,4,4,4,4,4 | stores crystal |
| resources | `antimatter_vault` | Antimatter Vault | 3 | 4 | 8 | 0,0,0,1,2,2,2,2,2,2 | stores antimatter |
| army | `hangar` | Hangar | 5 | 1 | 10 | 1,1,2,2,3,3,4,4,4,4 | capacity 20–70 |
| army | `cadet_academy` | Cadet Academy | 3 | 1 | 10 | 1,2,2,3,4,4,4,4,4,4 | |
| army | `fabricator` | Fabricator | 3 | 2 | 10 | 0,1,2,2,2,2,3,3,3,3 | |
| army | `heavy_fabricator` | Heavy Fabricator | 3 | 4 | 8 | 0,0,0,1,2,2,2,2,2,2 | |
| army | `research_lab` | Research Lab | 3 | 2 | 10 | 0,1,1,1,1,1,1,1,1,1 | |
| army | `nanite_foundry` | Nanite Foundry | 3 | 3 | 8 | 0,0,1,1,1,1,1,1,1,1 | |
| army | `drydock` | Drydock | 4 | 5 | 7 | 0,0,0,0,1,1,1,1,1,1 | |
| army | `alliance_beacon` | Alliance Beacon | 3 | 3 | 7 | 0,0,1,1,1,1,1,1,1,1 | capacity 10–40 |
| defense | `laser_turret` | Laser Turret | 3 | 1 | 10 | 1,2,3,4,5,5,6,6,6,6 | ground, range 7 |
| defense | `missile_battery` | Missile Battery | 3 | 2 | 10 | 0,1,2,3,4,4,5,5,6,6 | both, range 10 |
| defense | `plasma_mortar` | Plasma Mortar | 3 | 3 | 8 | 0,0,1,2,3,3,4,4,4,4 | ground, range 11 |
| defense | `shield_generator` | Shield Generator | 3 | 3 | 8 | 0,0,1,1,2,2,2,2,3,3 | bubble radius 5; no damage |
| defense | `flak_cannon` | Flak Cannon | 3 | 4 | 8 | 0,0,0,1,2,2,3,3,4,4 | air, range 10 |
| defense | `arc_tower` | Arc Tower | 3 | 4 | 8 | 0,0,0,1,2,2,3,3,4,4 | both, range 7 |
| defense | `cloaked_sentry` | Cloaked Sentry | 2 | 4 | 7 | 0,0,0,1,2,2,3,3,4,4 | hidden; both, range 6 |
| defense | `gravity_well` | Gravity Well | 2 | 5 | 6 | 0,0,0,0,1,1,2,2,2,2 | air, range 12; no damage |
| defense | `emp_tower` | EMP Tower | 3 | 5 | 6 | 0,0,0,0,1,1,1,2,2,2 | ground, range 6 |
| defense | `railgun` | Railgun | 3 | 5 | 7 | 0,0,0,0,1,1,2,2,3,3 | both, range 14 |
| defense | `ion_beam` | Ion Beam | 2 | 5 | 6 | 0,0,0,0,1,1,1,2,2,2 | both, range 9 |
| defense | `orbital_cannon` | Orbital Cannon | 4 | 5 | 5 | 0,0,0,0,1,1,1,1,1,1 | both, range 50 |
| defense | `barrier_wall` | Barrier Wall | 1 | 1 | 10 | 25,50,75,100,150,175,200,225,250,250 | instant at every level |
| traps | `proximity_mine` | Proximity Mine | 1 | 2 | 6 | 0,2,4,6,6,6,6,6,6,6 | hidden; ground, blast 2 |
| traps | `grav_trap` | Gravity Trap | 1 | 3 | 5 | 0,0,2,4,6,6,6,6,6,6 | hidden; ground, blast 1; no damage |
| traps | `flak_mine` | Flak Mine | 1 | 4 | 5 | 0,0,0,2,4,4,4,5,5,5 | hidden; air, blast 3 |
| traps | `mega_mine` | Mega Mine | 2 | 5 | 5 | 0,0,0,0,2,2,3,3,4,4 | hidden; ground, blast 3 |

The curve, which `test_catalog.gd` checks for affordability and for never going down:

- **Unlocks.** Levels and counts follow the level map in `docs/plans/upgrade-pass.md` §3; a
  level's tier (`art-style.md`, **Tiers**) is set by its `requires_cc`. Every type's final level
  requires Command Center 10, and no count goes down from one Command Center level to the next.
  The Command Center's level k requires k-1.
- **Costs** rise about ×2.5 per level to Command Center 5 and about ×2.2 per level beyond it,
  rounded to two significant figures. Collectors and storages cost the other main resource
  (the Extractor and the Siphon crystal, the Harvester and the Vault metal, each silo the other
  silo's resource, the Drone Bay metal); army and defences cost metal plus about a quarter as
  much crystal; traps and walls cost metal. The Command Center costs 1,500 metal to reach
  level 2, rising to 25,000 metal and 10,000 crystal for level 5, then 60,000/25,000,
  150,000/60,000, 350,000/150,000 + 1,000 antimatter, 800,000/350,000 + 3,000 and
  2,000,000/800,000 + 10,000 (metal/crystal) for levels 6 to 10.
- **Antimatter, by tier.** It first appears on the levels that require Command Center 5 of
  army, defence and trap types, and on the Siphon's and the Vault's top levels there: 20 to
  300. A type that pays it keeps paying it, at least as much each level. The Siphon and the
  Vault carry it ×2.2 a level, uncapped (up to 2,400 and 3,500 at Command Center 9). Army and
  defence types carry it ×2.2 too, but their Obsidian levels (requiring Command Center 8–9)
  are held to 200–2,000, at least a thousandth of their metal, so the cap flattens the top of
  that band; every Crown level (requiring Command Center 10) pays 2,000 to 19,000, at least a
  two-hundredth of its main price. Traps pay 100–500 on Obsidian and 500–2,000 on Crown
  levels; the Barrier Wall pays metal only.
- **Reachable storage** per main resource at Command Center 1–10 is 2,500, 9,500, 26,000,
  66,000, 120,000, 240,000, 480,000, 960,000, 2,000,000 and 3,840,000 (the Command Center plus
  its silos); antimatter is 500, 2,100, 4,200, 8,400, 16,800, 33,600 and 67,200 at 4–10 (the
  Command Center plus its vaults). Every price fits the storage at its level's `requires_cc`.
- **Build times** run from 10–30 s at level 1 of a cheap building to 10–20 min at the levels
  requiring Command Center 5; the levels requiring Command Center 6, 7, 8, 9 and 10 take 15,
  20, 25, 30 and 40 min for a 3×3 or bigger building and two thirds of that for a 2×2 one or a
  trap, never less than the type's level before. The Command Center takes 2, 10, 30, 60, 75,
  90, 105, 120 and 150 min to reach levels 2 to 10; walls and the Drone Bay are instant.
- **Production** per hour: Extractor and Harvester 1,800, 3,000, 4,500, 6,500, 9,000, 12,600,
  17,600, 24,600, 34,400, 48,200; Siphon 20, 40, 70, 105, 160, 240, 360, 540. **Storage**: silos
  1,500, 3,500, 7,000, 14,000, 25,000, 50,000, 100,000, 200,000, 420,000, 800,000 (level 9 is
  420,000 rather than a doubled 400,000 so that the Command Center's level 10 fits at 9); Vault
  100, 300, 800, 1,600, 3,200, 6,400, 12,800, 25,600; Command Center 1,000 to 640,000 of each
  main resource (doubling from level 4) and 200, 500, 1,000, 2,000, 4,000, 8,000, 16,000
  antimatter at levels 4–10. **Capacity**: Hangar 20 to 70, Alliance Beacon 10 to 40, +5 a level
  beyond Command Center 5.
- **Combat fields** (display only): `hp` and `damage` rise with level (beyond Command Center 5
  about ×1.15 and ×1.2 a level); `range_cells` and `fire_ms` are fixed per type and grow with
  tier. Traps have no `hp` or `fire_ms`.

**These are development values**, timed in seconds and minutes so a change can be seen in one
sitting. The retune to production time scales is a later change to `data/` alone.

## The fixture catalog (`test/support/fixtures/`)

The same two files in miniature for logic tests: three resources (metal, crystal, antimatter),
four categories (resources, army, traps, walls), a 10×10 grid, 500/500/0 to start, a 2×2
Command Center at (0, 0) with two levels (storage 1000/1000 and no antimatter; level 2 costs 400
metal and takes 100 s), a 1×1 drone bay at (3, 0) with one builder, and types chosen for round
numbers: `extractor` (2×2, 100 crystal, 60 s, 3600 metal/h = 1 per second), `harvester` (1×1,
50 metal, instant, 1800 crystal/h = 1 per 2 s, max 1), `silo` (2×2, 100 metal, 30 s, +1000
metal storage), `siphon` (1×1, 50 crystal, instant, 3600 antimatter/h, stores 100 antimatter),
`hangar` (2×2, `capacity` 20 then 30), `lab` (2×2, locked until Command Center 2), `mine` (1×1,
hidden, targets ground) and `wall` (1×1, instant, up to 25).
`test/support/fixtures.gd` loads it (`Fixtures.catalog()`, `Fixtures.new_base(start_time)`).
Rebalancing `data/` never touches it.

## The save file

`user://base.json` by default; a `--save-path=<file>` user argument (after `--` on the command
line) replaces it, which is how the gate and the harness keep off the real save. Written by
`main.gd` as the pretty-printed `BaseState.to_dict()`:

```json
{
  "version": 2,
  "grid": { "width": 48, "height": 48 },
  "now": 1760400000,
  "next_id": 4,
  "resources": { "metal": 750, "crystal": 600, "antimatter": 0 },
  "remainders": { "metal": 0, "crystal": 0, "antimatter": 0 },
  "buildings": [
    { "id": 1, "type": "command_center", "cell": [22, 22], "level": 1, "target_level": 1, "finish_at": 0 }
  ]
}
```

Saved every 10 ticks (10 s) and when the window closes or the app is paused. On load, buildings
of unknown types or that no longer fit are dropped, missing keys take defaults (a resource the
save does not list, such as antimatter in a save from before it existed, starts at 0), and the
state is advanced to the current time for offline progress. An unreadable file starts a new
base.

`grid` is the field the base was laid out on (`rules.json`'s `grid`), from version 2. A version
1 save has none: every version 1 save was laid out on the 40×40 field, so `BaseState.from_dict`
moves its buildings by half the field's growth since (floored at zero), (4, 4) on 48×48, and the
base stays centred; the next save is version 2. A save with no `version` reads as version 1. A change to this shape keeps old saves loading or bumps `version` with a migration
(`CLAUDE.md`, **Agent workflow**, tier A).
