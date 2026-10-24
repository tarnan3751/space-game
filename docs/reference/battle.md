# Battle sim

How `src/core/battle/` works: a deterministic battle of an attacker's army against a defended
layout on the field, run from a setup that is exactly its replay. It is the one battle sim of
`docs/vision.md` §2: expeditions (step 6) run it against a generated outpost, PvP (Milestone 3)
against a player's saved base, and the server will replay it in headless Godot. The data it
reads is in `data-format.md` (`rules.battle`, the buildings' battle fields and classes, the
units' battle fields); applying a result to the attacker's base is `raid_result`
(`core-economy.md`). The battle view and its HUD are step 5. The abilities the attacker brings
are made in the Nanite Foundry (`core-economy.md`, **The Foundry**; their data in
`data-format.md`, `abilities.json`).

Everything here `extends RefCounted`, like the rest of `src/core`: no clock, integers only, ties
broken by id.

## Units of measure and time

- **Field units**: 1 cell = 1000, so a cell's centre is `cell * 1000 + 500`. A building's
  footprint is the rectangle `[cell * 1000, (cell + size) * 1000]` on each axis.
- **Distances** are compared squared (the largest on 48×48 is 4.6e9, inside 64 bits). Moving
  along a line takes an integer square root (`BattleMath.isqrt`). No float enters a battle.
- **Ticks**: 20 a second (`BattleSim.TICKS_PER_SECOND`, 50 ms). A battle lasts
  `rules.battle.seconds` × 20 ticks. Speeds are field units a second; a unit moves
  `speed × 50 / 1000` a tick with the remainder carried, the way production carries
  resource-seconds. Cooldowns are milliseconds counted down 50 a tick.
- **Randomness**: none. The setup's `seed` seeds a `SeededRng` (`BattleSim.rng`) kept for rules
  to come; **no rule draws from it yet**, so two seeds give the same battle. `tools/sim_battles.gd`
  varies its scripted attack by seed instead.

## Modules

| File | Class | Holds |
| --- | --- | --- |
| `battle_sim.gd` | `BattleSim` | The setup, the tick loop, commands, the end, destruction, stars, loot, the hash and the result. The only surface the view reads. |
| `battle_layout.gd` | `BattleLayout` | The defender's buildings in id order (index 0 is the lowest id): type, cell, class, the level's stats as ints, the hull, fallen and revealed flags. |
| `battle_field.gd` | `BattleField` | Per cell: free, wall or building (`kind`), what stands there, and the deploy zone's cover count. |
| `battle_pathing.gd` | `BattlePathing` | The ground search and the reach maps (**Pathing**). |
| `battle_army.gd` | `BattleArmy` | The units in deploy order (a unit's id is its index + 1): stats at the attacker's levels, positions, targets, paths; the unit phase; the unit buckets the defences search. |
| `battle_combat.gd` | `BattleCombat` | The defences' cooldowns and targets, shells in flight, shields, statuses, traps and the EMP's disabled timers; `damage_building`; the defence phase. |
| `battle_abilities.gd` | `BattleAbilities` | The abilities brought, left and used, the swarms at work and the strikes on their way; the ability phase (**Abilities**). |
| `battle_events.gd` | `BattleEvents` | The last tick's events, for the view (**What the view reads**). |
| `battle_math.gd` | `BattleMath` | Cell centres, `isqrt`, the squared distance to a rectangle, whole-number and cell parsing. |

State lives in packed arrays of the class that writes them, never written from another object:
an array written through a chain (`layout.hp[i] = v`) is copied first. Each array is sized at
setup, so a tick allocates nothing in the steady state but the paths it searches.

## The setup and the commands

```
{"seed": int,
 "attacker": {"army": {unit: count}, "unit_levels": {unit: level},
              "abilities": {ability: count}, "ability_levels": {ability: level}},
 "defender": {"buildings": [{"id", "type", "level", "cell": [x, y]}, ...],
              "resources": {resource: int}},
 "commands": [command, ...]}
```

- `BattleSim.create(catalog, setup)` builds a battle; `setup_error` is `""` or why it was
  refused (no `rules.battle`; an unknown building type or unit; a level the type does not have;
  an id that is not a new positive whole number; a footprint off the field or over another; an
  unknown ability; a negative count or stored amount; more than `BattleSim.MAX_UNITS` (2,000)
  units or `MAX_ABILITIES` (200) abilities in all, checked before anything is sized by them, so
  a setup from elsewhere cannot size the battle at will; abilities or ability levels not objects; commands whose ticks are not whole and in order). A refused
  battle never runs. `BattleSim.run(catalog, setup)` runs one to its end and returns `result()`
  (`{}` when refused). The step 4 plan's `bad_setup` code became this: a refusal is a non-empty
  `setup_error`, the reason in words, not a code.
- **Defender buildings** take a save's building shape (other keys ignored). A level-0 building
  (under first construction) is left out; one upgrading fights at its finished level.
- **Attacker levels** are clamped into each unit's levels, 1 when left out; so are the abilities'
  levels. `abilities` is how many of each the attacker brings (the base's stock), taken in sorted
  id order like the army.
- **Commands** in `setup.commands` are applied at the start of their tick, in list order; the
  view sends them live through `command(cmd)` at the current tick. A command naming a tick must
  name the current one. `command` returns `""` or a code, and accepted commands are logged
  with the tick they ran on: the log is the replay.

| Command | Refusals |
| --- | --- |
| `{"op": "deploy", "tick": t, "unit": String, "cell": [x, y]}` | `battle_over`, `bad_tick`, `unknown_unit` (not a catalog unit), `none_left` (none of it left in the army, or none brought), `blocked` (off the field or in the deploy zone) |
| `{"op": "ability", "tick": t, "ability": String, "cell": [x, y]}` | `battle_over`, `bad_tick`, `unknown_ability` (not a catalog ability), `none_left` (none of it left, or none brought), `blocked` (off the field); anywhere in the field is allowed, buildings included (**Abilities**) |
| `{"op": "surrender", "tick": t}` | `battle_over`, `bad_tick`; ends the battle on its tick |
| anything else | `unknown_op` |

`check_deploy(unit, cell)` and `check_ability(ability, cell)` ask the question without acting.

**The deploy zone** is every standing footprint, walls included, grown by one cell; traps are
left out, since they are hidden, so a deploy on a trap's cell is allowed and the trap goes off
that tick if the unit's class matches. The zone opens as buildings fall: each cell counts the
grown footprints covering it, and a fall lowers the count over its own grown footprint only,
so a cell under two footprints opens when both have fallen. A unit is deployed at its cell's
centre.

## A tick

1. The commands due.
2. **The ability phase** (`BattleAbilities.tick`): the strikes due land, in the order they were
   called, then the swarms at work heal, in the order they were cast; the falls are passed on.
3. **The unit phase, first half** (`BattleArmy.act`), units in id order, a stunned one
   skipped: a unit with a target walks along its path (ground) or flies straight at it (air,
   not while held), and in reach attacks every `fire_ms`; a unit whose target has fallen drops
   it and wants another.
4. The falls of the first half are passed on: the field frees the cells and lifts the deploy
   zone, the reach maps forget the building, its loot share is taken. (The units' fallback
   counts drop the moment a building falls.)
5. **The unit phase, second half** (`BattleArmy.aim_and_act`), units in id order: every unit
   wanting a target, the newly deployed included, gets one (**Targeting**), so its search sees
   the falls of this tick's first half, and acts on it at once. A target that falls in this
   half is noticed by the units on it in the next tick's first half; its falls are passed on
   in turn.
6. The unit buckets are rebuilt.
7. **The defence phase** (`BattleCombat.tick`): shells due land; each defence in id order
   reveals itself if hidden and a unit is in range, then fires if its cooldown allows; each trap
   goes off if a unit of its class is in range; the shields recharge. A disabled defence skips
   all of it (**Abilities**).
8. Its falls and reveals are passed on, the clock moves, and the end is checked.

The battle ends after a tick at the timer, at 100% destruction (when anything counts), or when
no unit stands, none is left to deploy, no ability is left to use and no strike is on its way;
or at once on a surrender.

## Pathing

A ground unit's search finds its target and its path together: Dijkstra over the cells from the
unit's cell.

- An orthogonal step costs 1000, a diagonal 1414.
- A non-trap building's cells are closed, the target's included: no unit's reach is under 500
  (`BattleArmy.MIN_REACH`), and a cell orthogonally next to a footprint is 500 from it.
- A wall cell is open at `rules.battle.wall_cost_units` more (8000 in the shipped data, eight
  cells' walk), so a short detour is walked round and a long one is broken through.
- A diagonal step is allowed only when both cells beside it are free of buildings and walls:
  no corner cutting.
- The search stops at the cost of the first cell it settles from which a candidate is in reach.
  Of the cells at that cost, the one whose pick (the nearest candidate in reach, then the lowest
  id) has the lowest id wins. The heap orders by cost, then cell index.
- If the path walks into a wall, it is cut at the cell before it and that wall becomes the
  target: a blocking wall is in reach from any of its eight neighbours. When it falls, the unit
  searches again.
- A unit that finds nothing waits, IDLE, and searches again after the next fall.

**Reach maps.** "A candidate in reach" is read from a map per (candidate set, reach): per cell,
the number of standing candidates within that reach of the cell's centre. Every map the army can
ask for is built at setup: for each ground type brought, its own set and the two fallbacks
(**Targeting**: `any`, then `any` with the unrevealed) at its reach, so no tick builds one. A map
is kept up to date: a fall removes the building's stamp, a reveal adds it, about a hundred cells
each, a row's span in reach found by an integer square root. The maps live side by side in one
array of the pathing's own. The search runs on the field grown by a border of closed cells, so a
step needs no bounds check; a cell keeps its order there, so ties break as on the field.

**Budget.** At most `BattleArmy.PATHS_PER_TICK` = 4 searches run a tick; units waiting are
served in id order. Units asking the same map from the same cell in a tick share one search, so
a stack deployed on one cell costs one. A search reaches at most every cell once (2,304 on
48×48).

Paths are searched again only when the target falls, when a thrown unit lands, and after a
fall for a unit that found nothing; never per tick.

## Targeting

**Unit candidates** are standing, revealed buildings of the class the unit `prefers`
(`data-format.md`, **Battle classes**): `any` is every class but walls and traps; `defense`,
`resource`, `hq` and `wall` are that class. With none of its class standing, a unit takes `any`;
with nothing of that standing either, the unrevealed buildings too, so the hidden sentry is
found at last.

- Ground units pick by path cost (**Pathing**), air units by straight distance to the footprint,
  ties to the lowest id.
- A unit keeps its target until it falls; defences do not distract it. Units overlap freely.
- An air unit flies at its target's nearest point and stops in reach.

**Defences** hit the nearest unit of their `targets` class within `range_cells × 1000` of their
centre, then the lowest unit id, and keep that target while it is alive and in range. A
defence fires when its cooldown is spent, and a ready one with nothing in range stays ready.
The nearest-unit search reads the unit buckets (4×4 cells) its range touches.

## Damage and the specials

- **Unit hits**: `damage × damage_pct[class] / 100` of the target's class, at the attacker's
  level. The first lands on arrival, then one every `fire_ms` (at least one tick). With
  `splash_units`, every standing building whose footprint is within that of the target's centre
  takes the hit at its own class's percent, walls included. A `self_destruct` unit dies with its
  first hit, splash included.
- **Defence hits**: `damage`, one unit. Every type without a special below is this.

| Type | Fields | Rule |
| --- | --- | --- |
| `plasma_mortar`, `orbital_cannon` | `splash_units`, `shell_ms` | The shell is aimed at the target's position and lands `shell_ms` later, hitting every unit of the defence's class within `splash_units` of that point: a unit that has walked out is missed. |
| `shield_generator` | `shield_hp`, `shield_regen`, `shield_delay_ms`, `range_cells` | A pool that absorbs any damage to the buildings whose centre is within `range_cells` of the generator's. It covers neither walls, nor traps, nor the generator itself, so a raid can pop it. Overlapping pools drain lowest id first. A pool recharges `shield_regen` a second (carried per tick) once `shield_delay_ms` have passed since it last absorbed, up to `shield_hp`, and is gone when its generator falls. |
| `gravity_well` | `hold_ms`, `fire_ms` | When an air unit is in range, it holds every air unit in range for `hold_ms`: a held unit does not move but still attacks. |
| `emp_tower` | `stun_ms` | Its hit stuns the unit for `stun_ms`: no move, no attack, its cooldown paused. A stun or a hold over another keeps the later end. |
| `cloaked_sentry` | `hidden` | Unseen, it neither fires nor is targeted; it is revealed when a unit of a class it targets comes within range, and fires that tick. It counts for destruction throughout. |
| `proximity_mine`, `flak_mine`, `mega_mine` | `damage`, `range_cells` | On the first tick a unit of its class is within `range_cells` of its centre, it hits every unit of that class there, then is gone. |
| `grav_trap` | `throw_cells`, `range_cells` | Goes off the same way and throws every ground unit in range up to `throw_cells` cells opposite to its heading (away from the trap when it has none), in one of the eight directions, stopping on the last free cell before a building, a wall or the edge; the unit lands on that cell's centre and searches again. No damage. |
| `barrier_wall` | `hp` | Blocks ground units (**Pathing**); air units fly over. |

Traps never block, are never targets and never count for destruction.

## Abilities

An ability is used at the centre of its command's cell, at the start of its tick, and acts by its
`effect` (`data-format.md`, `abilities.json`) at the attacker's level of it. Distances are
squared field units, as everywhere; the ms fields are floored to ticks (`ms / 50`).

| Effect | Rule |
| --- | --- |
| `swarm` (the Repair Swarm) | For `duration_ms / 50` ticks from its own, in each tick's ability phase, it heals every living unit, ground or air, within `radius_units` of its point by `heal_per_second × 50 / 1000`, the remainder carried per swarm from tick to tick as the shields' recharge is, up to the unit's hull. Swarms over one another each heal. |
| `emp` (the EMP Burst) | At once, every standing defence (class `defense`: the guns, the gravity well, the EMP tower, the shield generator and the cloaked sentry; not traps) whose centre is within `radius_units` is disabled until `tick + stun_ms / 50` (a later end kept): while disabled it skips the defence phase, so it neither reveals itself nor fires, its cooldown and target held as a stunned unit's; a shield generator neither recharges nor counts its delay, though its pool still absorbs. Shells already fired still land. |
| `strike` (the Orbital Strike) | It lands `delay_ms / 50` ticks later, in that tick's ability phase: `damage` to every standing building whose footprint is within `radius_units` of its point, walls and hidden buildings included (a hidden one is not revealed by it), traps left out, through `damage_building`, so shields absorb it; then `damage` to every living attacking unit within the radius too, ground or air: a strike hurts the attacker's own units. Its falls are passed on before the unit phase. |

`BattleCombat.disabled_until` (per building) and the swarms and strikes of `BattleAbilities`
(fixed lists sized at setup for every ability brought) are the only state the abilities add; a
tick allocates nothing for them. An emp and a strike read every building once; a swarm reads
every unit once a tick.

## Destruction, stars and loot

- **Destruction** is the buildings destroyed out of those that count (neither walls nor traps),
  as a whole percent rounded down.
- **Stars**: one at 50%, one for the Command Center destroyed, one at 100%.
- **Loot**: each resource's loot is `stored × loot_pct / 100` of the defender's `resources`,
  spread over the buildings that hold it, weighed by their `storage` of it plus one hour of their
  `produces` of it (so a collector counts as an hour of its output), rounded down, the rest one
  by one to the lowest ids. A building's share is taken when it falls; one that stands keeps it.
  The cap by the attacker's storage is applied by `raid_result`.
- An expedition's outpost (`expeditions.md`) supplies `defender.resources` from its loot
  profile, sized so that `loot_pct` of it is the profile's target; a loot deposit is a storage
  building of the outpost outside its walls, so it takes its share by the same rule.

## The result

```
{"abilities_used": {ability: n}, "commands": [accepted commands], "deployed": {unit: n},
 "destruction": int, "hash": int, "loot": {resource: n}, "stars": int, "ticks": int}
```

Every key and sub-key is in sorted order, so equal battles give equal text. `deployed` counts
the units deployed (all are spent, alive or not), `abilities_used` the abilities used (only those
above 0; `{}` when none), `ticks` the ticks run, `hash` the final
`state_hash()`.

## What the view reads

| Member | What |
| --- | --- |
| `tick`, `ticks_total()`, `seconds_left()`, `is_over()` | The clock. |
| `step()`, `run_to_end()`, `command(cmd)`, `check_deploy(unit, cell)`, `is_deploy_cell(cell)`, `left_to_deploy(unit)` | Running it and the deploy bar. |
| `check_ability(ability, cell)`, `left_to_use(ability)` | The abilities bar. |
| `unit_count()`; per unit id: `unit_type`, `unit_position` (field units), `unit_heading` (the last move, not normalised), `unit_hp`, `unit_max_hp`, `unit_state`, `unit_target` (a building id, 0 for none) | Units. `unit_state` is one of `BattleArmy.IDLE`, `WALKING`, `ATTACKING`, `DEAD`, `STUNNED`, `HELD`. |
| `building_ids()`; per building id: `building_hp`, `building_max_hp`, `is_destroyed`, `is_revealed`, `shield_hp`, `building_disabled` (an EMP burst has it off now) | Buildings. |
| `destruction_pct()`, `stars()`, `loot()` | Progress. |
| `events` (`BattleEvents`) | The last tick's events, the first `count` of its arrays: `UNIT_HIT`, `SHOT`, `SHELL` (with its `land_tick`), `SHELL_LAND`, `HOLD`, `DETONATE`, `THROW`, `REVEAL`, `FALL`, `DEATH`, each with a source and target id and from and to points; and `ABILITY` (an ability used at `to`: a swarm's cloud until its `land_tick`, a burst's flash with the defences waking at it, a strike's incoming marker landing at it) and `STRIKE_LAND` (the blast at `to`), their source the ability's place in `catalog.ability_types()` plus one. A live ability command keeps its event for the tick it runs on: only an accepted ability command clears the last tick's events before adding its own (as the next tick does); a deploy or a refused command leaves the last tick's events in place. |
| `state_hash()`, `result()` | Determinism and the end. |

## Determinism and performance

The same setup gives the same `result()` text and the same `state_hash()` at every tick: ties go
through id order or the heap's (cost, cell) order, the setup's dictionary order does not matter
(the defender's buildings are taken in id order and the attacker's unit types and abilities in
sorted order, so a setup sent as JSON, whose parse sorts its keys, replays to the same hash), and
nothing reads a clock or draws a random number. The hash covers the abilities' state too: what
is left and used, every swarm (point, end, heal, radius, carry), every strike on its way (point,
landing tick, damage, radius) and every building's disabled timer. A battle stepped tick by tick,
fed its commands live, or replayed from its logged commands gives the same result
(`test_battle_sim.gd`, and with abilities `test_battle_abilities.gd`). Until the reach maps were
built at setup, a map first built in a pass where a unit had just felled a building counted every
cell in that building's reach one low (the fall was left out, then taken off again), so a replay
recorded before then whose first build of a map fell in that window does not reproduce; none
exists outside a base's local raid log.

**Budget**: a full 180 s battle with 280 housing of units against a maxed layout simulates
headless in well under 2 s on the development Mac, so the view can run it at real time with
headroom on a phone. Measured on 2026-10-24 on the template base (363 buildings, 92 of them
counted, 250 walls, 21 traps), with the machine shared with other runs (load average 7 to 10):

- `tools/sim_battles.gd`, ten seeds of its default army (100 Rangers, 40 Brawlers, 20 Jet
  Troopers, 5 Hover Tanks and 2 Gunships, the Hangars' 280 housing): 145 to 357 ms at the tool's
  default level 3, 145 to 472 ms at level 8 (each unit's top level at most); most armies die
  before the timer.
- The `battle` scenario's full 180 s battle (3,600 ticks), the same army at its top levels: 455
  to 494 ms.
- The worst case found, 280 Rangers given a thousand times their hull so all of them walk and
  fight for the whole 180 s: 1.1 to 1.6 s.

Most of the worst case is the unit phase (walking, attack cooldowns and about 530 path searches),
then the defences' nearest-unit searches.

**A tick's cost** is flat but for the searches. The reach maps are built at setup, about 0.5 to
1.3 ms each on the template base, so a six-map army (the `battle` scenario's) adds about 5.5 ms
to a setup of about 5.4 ms; the first tick, which used to build them, costs 1.5 to 1.7 ms. A
search costs about 15 µs and about 1.6 µs a cell it settles, 0.5 to 0.75 ms for a group deployed
far from the buildings, so a tick's ceiling is `PATHS_PER_TICK` full searches: 2.3 to 3.3 ms on
the Mac (the `battle` scenario checks its slowest tick under 3.5 ms), about 8 to 16 ms on a phone
three to five times slower. Measured headless, the faster of two runs per tick, load average 5 to
9. If the phone measurement needs it, the next lever is the search budget, lowered or counted in
settled cells instead of searches: a rule change, since it moves when units start walking. Two
other levers are not built yet: idle defences sleeping while the unit buckets their range touches
are empty, and per-segment walking state, so a walking unit does not recompute its segment every
tick.

## Tools

- `tools/harness/scenarios/battle.gd` (headless): a scripted attack of five of the eleven unit
  types (Rangers, Brawlers, Jet Troopers, Hover Tanks, Gunships; 280 housing) and one Orbital
  Strike (called at tick 40 on the first defence, which must have lost hull when it lands) on the
  template base, logged (duration, destruction, stars, loot, wall time), run twice to check it
  repeats, and its result applied to a copy of the game's base, the units and the strike spent.
- `tools/sim_battles.gd`: N seeds of a scripted attack against the template base or a save
  file, with abilities when `--abilities` names them, one CSV row each (`testing-tools.md`).
