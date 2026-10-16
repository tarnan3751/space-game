# The upgrade pass: Command Center 10

The plan for the pass the owner asked for on 2026-10-16: the Command Center goes to level 10,
every type gains levels, the maxed base shares a look, and upgrades at the high tiers are
bigger, taller and flashier. Every brief of the pass points here for its decisions; the
reference files are updated as each slice lands. Status: **approved** by the owner on
2026-10-16, with the field at 48×48 (§6, §7).

## 1. Constraints (the owner's)

- The Command Center and the Barrier Wall reach level 10. Every other type gains levels, but
  not necessarily one at every Command Center level (Clash-style).
- **A type's footprint never changes.** Within it a model may fill more of the pad, grow
  taller, gain decoration, animation, and escorts (robots, ships, soldiers) as moving parts.
- At the top, every building shares a cohesive theme, the way today's maxed buildings share
  gold plating and trim; the levels unlocked at each Command Center band share a theme too.
- Verticality is an upgrade axis at the high levels, strongest on the Command Center, on a
  few other types, never excessive.

## 2. Tiers: one theme per Command Center band

A level's **tier** is set by the Command Center level it requires (`requires_cc` in the data),
so the theme is data-driven and the same rule applies to every type:

| Tier | Levels requiring CC | Look | Shared elements |
| --- | --- | --- | --- |
| Base | 1–4 | As today: hull-light masses, the category accent, gunmetal machinery | — |
| Gold | 5 | As today's top: core-gold trim on rims, caps and crowns | gold trim |
| Chrome | 6–7 | Polished chrome plating (a new kit layer, brushed highlights) with cyan light strips; more mass, a second storey or mast; stronger emissives | chrome plates, cyan strips, a chrome cap on the signature element |
| Obsidian | 8–9 | Dark obsidian armour (new layer) veined with violet antimatter energy (new layer: energy veins, FLOW), crystal inlays; hovering parts (rings, plates) on HOLO or BOB; taller | obsidian plates, violet veins, one hovering element |
| Crown | 10 | Obsidian base, **gold filigree** over it, a violet antimatter core glowing in the body, a crowning element (spire, halo, banner or beacon beam) and an **escort**: a moving part that patrols or orbits (a guard drone, a hover skiff, two troopers on a round) | gold filigree, antimatter core, crown, escort |

So a maxed base reads black-and-gold with violet cores and crowns, which continues today's
gold and ties the top tier to antimatter, the rare resource spent only there. The escorts come
from three shared `Parts` helpers (drone, skiff, trooper pair) so they look alike across types.

Implementation: `Parts.tier` (BASE, GOLD, CHROME, OBSIDIAN, CROWN), derived from the level's
`requires_cc` by one mapping in `BuildingModels`, replaces every per-file `level >= N` gold
literal. The Command Center's tier is set by its own level (its level k requires Command
Center k−1 by its own rule), every other type's by its level's `requires_cc`. Existing models
render identically after the refactor (the gallery's triangle counts are the proof), except
the two trap tops that were gold at Command Center 4 (Proximity Mine 3, Gravity Trap 2), which
become Base; their next levels (Command Center 6 and 7) are Chrome, so those two types have no
gold tier.

## 2a. The style, at every tier

Every new level is drawn in the project's pulp sci-fi comic style, as the existing models are
(`docs/reference/art-style.md`): chunky, readable masses with exaggerated proportions, a few
big shapes before many small ones, bold saturated accents against light hulls, ink outlines,
the three-band toon light with halftoned shadows, glows that pop. The owner asked for this
explicitly on 2026-10-16: the new models must fit the vibrant, comic-like style of the whole
game. The tiers change the palette, never the style:

- **Chrome** is bright white with a cool cyan cast and cyan light strips, never grey or dull.
- **Obsidian** is ink-black glass that stays vibrant through saturated violet veins, bright
  glints and gold or cyan accents; at least a third of a model's visible surface stays bright
  or glowing, and the dark plating never reads as a muddy or realistic metal.
- **Crown** is the loudest tier: gold filigree, a violet core, a crown and an escort, drawn
  bigger and bolder than anything below it.

A level that reads as grim, grey, realistic or cluttered with small detail fails its review,
whatever its budgets say. Each batch's rendered gallery shots are judged for this first.

## 3. The level map

For each type: its maximum level at Command Center 1…10 (0 = locked) and how many a base may
own at each. The ramp follows Clash of Clans' shape (a level at most Command Center levels for
the staples, every second or third for the late types) compressed to ten. Every type's final
level requires Command Center 10, so every maxed building is Crown tier.

| Type | Max level at CC 1…10 | Count at CC 1…10 | New models |
| --- | --- | --- | --- |
| command_center | 1,2,3,4,5,6,7,8,9,10 | 1 at every level | 5 |
| drone_bay | 1,1,1,1,1,2,2,2,2,3 | 2,3,4,5,5,5,5,5,5,5 | 2 |
| metal_extractor | 1,2,3,4,5,6,7,8,9,10 | 2,3,4,5,6,6,6,7,7,7 | 5 |
| crystal_harvester | 1,2,3,4,5,6,7,8,9,10 | 2,3,4,5,6,6,6,7,7,7 | 5 |
| antimatter_siphon | 0,0,0,2,3,4,5,6,7,8 | 0,0,0,1,2,2,3,3,3,3 | 5 |
| metal_silo | 1,2,3,4,5,6,7,8,9,10 | 1,2,3,4,4,4,4,4,4,4 | 5 |
| crystal_silo | 1,2,3,4,5,6,7,8,9,10 | 1,2,3,4,4,4,4,4,4,4 | 5 |
| antimatter_vault | 0,0,0,2,3,4,5,6,7,8 | 0,0,0,1,2,2,2,2,2,2 | 5 |
| hangar | 1,2,3,4,5,6,7,8,9,10 | 1,1,2,2,3,3,4,4,4,4 | 5 |
| cadet_academy | 1,2,3,4,5,6,7,8,9,10 | 1,2,2,3,4,4,4,4,4,4 | 5 |
| fabricator | 0,2,3,4,5,6,7,8,9,10 | 0,1,2,2,2,2,3,3,3,3 | 5 |
| heavy_fabricator | 0,0,0,2,3,4,5,6,7,8 | 0,0,0,1,2,2,2,2,2,2 | 5 |
| research_lab | 0,2,3,4,5,6,7,8,9,10 | 0,1,1,1,1,1,1,1,1,1 | 5 |
| nanite_foundry | 0,0,2,3,4,5,6,6,7,8 | 0,0,1,1,1,1,1,1,1,1 | 4 |
| drydock | 0,0,0,0,2,3,4,5,6,7 | 0,0,0,0,1,1,1,1,1,1 | 5 |
| alliance_beacon | 0,0,1,2,3,4,5,6,6,7 | 0,0,1,1,1,1,1,1,1,1 | 4 |
| laser_turret | 1,2,3,4,5,6,7,8,9,10 | 1,2,3,4,5,5,6,6,6,6 | 5 |
| missile_battery | 0,2,3,4,5,6,7,8,9,10 | 0,1,2,3,4,4,5,5,6,6 | 5 |
| plasma_mortar | 0,0,2,3,4,5,6,6,7,8 | 0,0,1,2,3,3,4,4,4,4 | 4 |
| shield_generator | 0,0,2,3,4,5,5,6,7,8 | 0,0,1,1,2,2,2,2,3,3 | 4 |
| flak_cannon | 0,0,0,2,4,5,6,7,7,8 | 0,0,0,1,2,2,3,3,4,4 | 4 |
| arc_tower | 0,0,0,2,4,5,6,6,7,8 | 0,0,0,1,2,2,3,3,4,4 | 4 |
| cloaked_sentry | 0,0,0,2,3,4,5,6,6,7 | 0,0,0,1,2,2,3,3,4,4 | 4 |
| gravity_well | 0,0,0,0,3,4,4,5,5,6 | 0,0,0,0,1,1,2,2,2,2 | 3 |
| emp_tower | 0,0,0,0,3,3,4,4,5,6 | 0,0,0,0,1,1,1,2,2,2 | 3 |
| railgun | 0,0,0,0,3,4,5,5,6,7 | 0,0,0,0,1,1,2,2,3,3 | 4 |
| ion_beam | 0,0,0,0,2,3,3,4,5,6 | 0,0,0,0,1,1,1,2,2,2 | 4 |
| orbital_cannon | 0,0,0,0,2,2,3,3,4,5 | 0,0,0,0,1,1,1,1,1,1 | 3 |
| barrier_wall | 1,2,3,4,5,6,7,8,9,10 | 25,50,75,100,150,175,200,225,250,250 | 5 |
| proximity_mine | 0,1,2,3,3,4,4,5,5,6 | 0,2,4,6,6,6,6,6,6,6 | 3 |
| grav_trap | 0,0,1,2,2,2,3,3,4,5 | 0,0,2,4,6,6,6,6,6,6 | 3 |
| flak_mine | 0,0,0,2,3,3,4,4,4,5 | 0,0,0,2,4,4,4,5,5,5 | 2 |
| mega_mine | 0,0,0,0,2,3,3,4,4,5 | 0,0,0,0,2,2,3,3,4,4 | 3 |

138 new level models in all (the existing 121 are re-plumbed, not redrawn). The counts at
Command Center 1–5 are today's.

## 4. The model contract per tier

Today's ceilings are nearly used up (most top models within 30 triangles of 3,000), so the
budgets scale by tier. The gallery and `wall_junctions` check these per level.

| Footprint | Base / Gold | Chrome | Obsidian | Crown |
| --- | --- | --- | --- | --- |
| 1×1 trap | 600 | 840 | 1,080 | 1,320 |
| 2×2 | 2,000 | 2,800 | 3,600 | 4,400 |
| 3×3 | 3,000 | 4,200 | 5,400 | 6,600 |
| 4×4, 5×5 | 5,000 | 7,000 | 9,000 | 11,000 |
| wall piece | 250 | 300 | 350 | 400 |

- Moving parts: 3 (8 instances) through Obsidian; **4 at Crown** (10 instances), the fourth
  reserved for the escort. Draw calls, not triangles, are the phone's cost, so the fourth part
  is used only where the type's story needs it.
- Height: Base and Gold as today (a 3×3 about 1.6–2.2 units, the Command Center 3.2). As
  guidance, Chrome about 1.3×, Obsidian 1.6×, Crown 2× the type's Gold height; the hard caps
  govern: **7 units for the Command Center and 5 for every other type** (the camera's scene top
  is 13 with the construction drone hovering 3.5 above a site). The Command Center is the one
  type given more than the guidance, since verticality there is the owner's ask: 3.90, 4.40,
  5.20, 6.00 and 6.94 at levels 6–10. Verticality is given to: the Command Center
  (stacked storeys and a spire from 8), the Alliance Beacon, the Research Lab, the Hangar's
  control tower, the Antimatter Siphon's pylons, the Metal Silo, the Railgun, the Shield
  Generator, the Orbital Cannon, the Drydock's gantry. The rest grow in mass and detail.
- Extent (footprint + 0.15), chamfers, side counts, foundation, outlines, the animation
  contract and "each level reads as the same building grown" stay as written.
- The template base's framing takes the tallest model in a band instead of a fixed 4 units.

## 5. The economy to ten levels

Rules, applied by the data brief and checked by the shipped-data tests:

- Reachable storage per main resource at Command Center 6–10: 250k, 500k, 1M, 2M, 4M
  (Command Center plus silos); antimatter 5k, 10k, 20k, 40k, 80k.
- Costs rise about ×2.2 per level from today's top values; army and defences metal plus a
  quarter crystal; antimatter on every Crown level (and on Obsidian levels of army, defence
  and trap types), 1,000–20,000 at the top. The Barrier Wall pays no antimatter at any level
  (metal only); traps pay a reduced band, 100–500 on Obsidian levels and 500–2,000 on Crown
  levels. Every price fits reachable storage at its level's `requires_cc`.
- The Command Center: levels 6–10 cost 60k/25k, 150k/60k, 350k/150k + 1k antimatter,
  800k/350k + 3k, 2M/800k + 10k (metal/crystal), in 75, 90, 105, 120, 150 minutes.
- Production per hour continues ×1.4 a level; silo storage ×1.8; vault ×2; Hangar and Beacon
  capacity +5 a level; hp, damage rise; `range_cells` and `fire_ms` stay per type.
- Build times stay on the dev scale: 20–40 minutes at the top levels, the Command Center's as
  above. The later retune stays parked.
- The meters abbreviate from one million ("1.2M"); cards and the info panel keep full numbers.

## 6. The field

At the counts above a maxed base owns about 130 buildings and 250 walls: 1,100 cells, 69% of
the 40×40 field, and the template base needs about 46 rows with its fences. Options:

- **48×48 (recommended).** 48% fill (Clash is near 60% of 44×44). Pylon spacing stays
  symmetric (12 plates a side). The template fits with today's gap rule (46 of the 48 rows at the Command Center 10 counts). The
  start layout moves to the centre (22, 22); old saves get a **version 2** migration that
  shifts cells by (4, 4) so a base stays centred (tier A, a plan first); the field's tile hash
  is re-checked for 12×12 tiles (no identical neighbours), the scenery constants for mesas and
  craters re-checked against the wider field, the widest zoom kept at 44, which shows the whole
  perimeter at 16:9 with a tight margin (4:3 tablets clip the side corners and are not a target),
  the scenarios' cell constants moved.
- 44×44: 57% fill, 11 plates a side; the template just fits (about 43 rows) and has no room
  for a later type.
- Keep 40×40: the counts at 8–10 drop by about a fifth and walls cap at 200, and the template
  packs copies of a type without gaps.

## 7. The owner's decisions (2026-10-16)

1. **The field grows to 48×48**, under two conditions: the perimeter (kerb, pylons and the
   hologram fence) stays intact and continuous round the new field, and the outside
   environment keeps the look it has now: the terrain ring as wide as today, the same
   character of dunes, craters, mesas and the dry channel, re-checked rendered against
   before-and-after shots. The owner likes the environment as it is, so the field slice is
   careful: the ring's reach constants grow with the field, the scenery placement is checked to
   still place every feature, and the ground's tile variation is re-checked across 12×12
   tiles.
2. The level map (§3), the tier themes (§2) and the budgets (§4) proceed as proposed.

## 8. The work, in slices

Tier B unless marked. Two lanes run at once on disjoint areas; each slice is one brief, one
review, one landing.

**Phase 1, foundations (parallel: B1 with B2; then A1).**

- **B1 Tier plumbing and contract**: `Parts.tier` from `requires_cc`, the gold literals
  replaced (identical renders proven by the gallery), per-tier budgets and moving-part caps in
  the gallery and `wall_junctions`, the three new kit layers (chrome, obsidian, energy veins)
  generated and the kit count updated, the escort helpers in `Parts`, the meter abbreviation,
  the template framing by band height, the contract text in `art-style.md`. Landed.
- **B2 Economy to ten levels**: the Command Center 6–10, every type's new levels and
  ten-entry `max_count`, the data-format reference (table, curve, reachable storage). Levels
  above a type's modelled top show its top model until its batch lands. Landed.
- **A1 The field** (tier A for the save migration): as §6 decides. Landed.

**Phase 2, models, two lanes at a time, in roughly this order** (each batch also writes its
model-table rows and proves budgets, reach and motion in the gallery, rendered):

| Batch | Types | New models |
| --- | --- | --- |
| M1 Core | Command Center 6–10 (landed) | 5 |
| M2 Walls | Barrier Wall 6–10, junctions, `wall_junctions` to ten (landed) | 5 |
| M3 Collectors | Drone Bay, Extractor, Harvester, Siphon (landed) | 17 |
| M4 Storages | Metal Silo, Crystal Silo, Vault (landed) | 15 |
| M5 Army A | Hangar, Cadet Academy, Fabricator, Heavy Fabricator (landed) | 20 |
| M6 Army B | Research Lab, Nanite Foundry, Drydock, Alliance Beacon (landed) | 18 |
| M7 Turrets A | Laser, Missile Battery, Plasma Mortar, Flak Cannon (landed) | 18 |
| M8 Turrets B | Shield, Arc Tower, Cloaked Sentry, Gravity Well, EMP Tower (landed) | 18 |
| M9 Heavy guns | Railgun, Ion Beam, Orbital Cannon | 11 |
| M10 Traps | the four traps (landed) | 11 |

**Phase 3, the maxed base**: the template base at Command Center 10 counts (fit proven,
screenshots of every band), the full base measured (draw calls, triangles, frame time on the
Mac; phones still unmeasured), the overview's status and the roadmap updated.

## 9. Risks

- **Draw calls.** A maxed base is about 130 buildings; at up to ten instances each it can
  reach 1,200 draw calls at the widest zoom, before the merged walls and the scenery. The
  fourth moving part is rationed, and the full base is measured in phase 3; a phone
  measurement is the parked item that decides whether the crown escorts stay.
- **Scale.** 138 models at the pace of the Cadet Academy is days of lane time; the batches
  land one by one, so the game stays playable at every landing.
- **Sources.** The Clash reference came from a current fan tracker, cross-checked; the wiki
  was unreachable, so the per-Town-Hall counts are our own.
