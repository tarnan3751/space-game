extends RefCounted
## A small hand-made catalog for logic tests, so rebalancing data/ never breaks them.
## Use with: const Fixtures := preload("res://test/support/fixtures.gd")
##
## Fixture base (10x10 grid, starts with 500 metal / 500 crystal / 0 antimatter):
##   id 1  command_center  2x2 at (0,0)  storage 1000/1000 (no antimatter), L2 costs 400 metal, 100 s
##   id 2  drone_bay       1x1 at (3,0)  one builder
##   extractor 2x2: 100 crystal, 60 s, makes 3600 metal/h (1 per second)
##   harvester 1x1: 50 metal, instant, makes 1800 crystal/h (1 per 2 seconds), max 1
##   silo      2x2: 100 metal, 30 s, +1000 metal storage
##   siphon    1x1: 50 crystal, instant, makes 3600 antimatter/h, stores 100 antimatter, max 1
##   hangar    2x2: 100 metal, 30 s, capacity 20 (L2 30, needs CC 2); houses the army
##   academy   1x1: 10 metal, instant, trains every unit (L2 20 metal, 10 s), max 2
##   foundry   1x1: 10 metal, instant, makes the abilities, capacity 2 (L2 20 metal, 10 s,
##             capacity 3), max 1
##   lab       2x2: 100 metal, 30 s, needs CC 2 (max_count 0 at CC 1); researches (L2 200 metal, 60 s)
##   mine      1x1: 20 metal, instant, hidden, targets ground, max 2
##   wall      1x1: 10 metal, instant, max 25
##
## Battle fixtures (docs/reference/battle.md): every non-trap type above has hp; rules.battle is
## 60 s, loot 50% of each resource, wall "wall", traps the "traps" category, wall cost 8000, search
## cells 1000 (a search on the 20x20 field settles at most 400, so a few at once fit a tick; the
## budget tests set a smaller one on the catalog).
## The 1x1 battle types, each hp 300 at level 1 (Fixtures.battle_catalog):
##   turret  ground, damage 10, range 3, every 1000 ms     tower  both, damage 5, range 4, 500 ms
##   mortar  ground, damage 20, range 6, 2000 ms, splash 1000, shell 1000 ms
##   shield  range 3, pool 100, regen 20/s after 1000 ms   well   air, range 4, 2000 ms, hold 1000 ms
##   emp     ground, damage 5, range 3, 1000 ms, stun 500 ms
##   sentry  hidden, both, damage 10, range 2, 500 ms
##   air_mine  trap, air, damage 50, range 1      throw_trap  trap, ground, range 1, throw 3 cells
## Battle units (battle_units.json, merged after units.json by battle_catalog, so catalog()'s unit
## list stays grunt, flyer, walker), housing 1 each:
##   melee   ground any, speed 1000, hp 100, damage 10, 1000 ms, reach 500 (L2 hp 150, damage 15)
##   gunner  ground any, speed 1000, hp 60, damage 5, 500 ms, reach 3000
##   breaker ground wall, speed 2000, hp 20, damage 40, reach 500, splash 1000, x10 on walls, self-destructs
##   raider  ground resource, speed 2000, hp 80, damage 10, 1000 ms, reach 500, x2 on resources
##   hunter  ground defense, speed 500, hp 1000, damage 30, 2000 ms, reach 800
##   drone   air any, speed 2000, hp 50, damage 10, 1000 ms, reach 2000
##   bomber  air defense, speed 1000, hp 200, damage 100, 3000 ms, reach 500, splash 1000
##
## Fixture units (all trained by the academy):
##   grunt  ground, housing 1, 10 s, 10 crystal (L2: research 100 crystal, 60 s, lab 1; trains for 20)
##   flyer  air, housing 2, 20 s, 20 crystal (L2: research 200 crystal, 120 s, lab 2; trains for 30)
##   walker ground, housing 5, 30 s, 50 crystal, needs academy level 2, one level
##
## Fixture abilities (abilities.json, all made by the foundry; catalog(), catalog_with_grid and
## battle_catalog load them, expedition_catalog does not):
##   swarm   swarm, 10 s, foundry 1, radius 2000, 10 crystal, heals 40/s for 1000 ms
##           (L2: research 100 crystal, 60 s, lab 1; makes for 20; heals 80/s for 1000 ms)
##   burst   emp, 20 s, foundry 1, radius 2000, 20 crystal, disables for 1000 ms, one level
##   strike  strike, 30 s, foundry 2, radius 1000, 30 crystal, 100 damage after 500 ms
##           (L2: research 200 crystal, 120 s, lab 2; makes for 40; 150 damage)
##
## The expedition catalog (Fixtures.expedition_catalog; docs/reference/expeditions.md): its own
## rules and buildings, on a 40x40 field, with ten Command Center levels so an outpost can be laid
## out at every level, and the units and battle units above. rules.expedition is the shipped
## block (easy, even, hard, two fields each); rules.battle is the battle fixtures'. The roster:
##   command_center 3x3 (storage, antimatter from level 4)   drone_bay 1x1
##   extractor, harvester 2x2 (metal, crystal)   siphon 2x2 (antimatter, from CC 4)
##   silo, crystal_silo 2x2 (storage)   vault 2x2 (antimatter storage, from CC 4)
##   hangar 3x3   academy 2x2 (trains every unit)   lab 2x2 (from CC 2)
##   turret 2x2 ground, range 4   cannon 2x2 both, range 8 (from CC 2)   shield 2x2 (from CC 3)
##   sentry 1x1 hidden (from CC 4)   mine 1x1 trap (from CC 2)   mega_mine 2x2 trap (from CC 5)
##   wall 1x1, 30 at CC 1 up to 120 at CC 10, storing 5 antimatter: walls hold no loot share,
##     so none of it counts

const RULES := "res://test/support/fixtures/rules.json"
const BUILDINGS := "res://test/support/fixtures/buildings.json"
const UNITS := "res://test/support/fixtures/units.json"
const ABILITIES := "res://test/support/fixtures/abilities.json"
const BATTLE_UNITS := "res://test/support/fixtures/battle_units.json"
const EXPEDITION_RULES := "res://test/support/fixtures/expedition_rules.json"
const EXPEDITION_BUILDINGS := "res://test/support/fixtures/expedition_buildings.json"


static func catalog() -> Catalog:
	return Catalog.from_json(
		FileAccess.get_file_as_string(RULES),
		FileAccess.get_file_as_string(BUILDINGS),
		FileAccess.get_file_as_string(UNITS),
		FileAccess.get_file_as_string(ABILITIES)
	)


## The fixture catalog on a field of `size`, its rules otherwise unchanged.
static func catalog_with_grid(size: Vector2i) -> Catalog:
	var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RULES))
	rules["grid"] = {"width": size.x, "height": size.y}
	return Catalog.from_json(JSON.stringify(rules), FileAccess.get_file_as_string(BUILDINGS),
		FileAccess.get_file_as_string(UNITS), FileAccess.get_file_as_string(ABILITIES))


## The fixture catalog with the battle units merged in, on a field of `size` (20x20 by default).
static func battle_catalog(size: Vector2i = Vector2i(20, 20)) -> Catalog:
	var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RULES))
	rules["grid"] = {"width": size.x, "height": size.y}
	var units: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(UNITS))
	units.merge(JSON.parse_string(FileAccess.get_file_as_string(BATTLE_UNITS)))
	return Catalog.from_json(JSON.stringify(rules), FileAccess.get_file_as_string(BUILDINGS),
		JSON.stringify(units), FileAccess.get_file_as_string(ABILITIES))


## The expedition catalog: its rules and buildings, with the battle units merged in as
## battle_catalog does. `change` may edit the parsed rules first.
static func expedition_catalog(change: Callable = Callable()) -> Catalog:
	var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EXPEDITION_RULES))
	if change.is_valid():
		change.call(rules)
	var units: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(UNITS))
	units.merge(JSON.parse_string(FileAccess.get_file_as_string(BATTLE_UNITS)))
	return Catalog.from_json(JSON.stringify(rules), FileAccess.get_file_as_string(EXPEDITION_BUILDINGS),
		JSON.stringify(units))


static func new_base(start_time: int = 0) -> BaseState:
	return BaseState.create_new(catalog(), start_time)


## The fixture base with a finished hangar (id 3, 2x2 at (0, 3), housing 20) and an academy
## (id 4, at (9, 9)), at time 30 with 390 metal and 500 crystal.
static func army_base() -> BaseState:
	var state := new_base(0)
	state.apply({"op": "place", "type": "hangar", "cell": [0, 3]}, 0)
	state.advance_to(30)
	state.apply({"op": "place", "type": "academy", "cell": [9, 9]}, 30)
	return state


## The army base with a foundry (id 5, at (5, 5), level 1, capacity 2), at time 30 with 380
## metal and 500 crystal.
static func foundry_base() -> BaseState:
	var state := army_base()
	state.apply({"op": "place", "type": "foundry", "cell": [5, 5]}, 30)
	return state


## A battle setup on the battle catalog: `buildings` as [type, x, y] or [type, x, y, level], given
## ids 1, 2, ... in order; `army` as {unit: count}.
static func battle_setup(buildings: Array, army: Dictionary, commands: Array = [],
		resources: Dictionary = {}, unit_levels: Dictionary = {}) -> Dictionary:
	var entries := []
	for i: int in buildings.size():
		var entry: Array = buildings[i]
		var level: int = entry[3] if entry.size() > 3 else 1
		entries.append({"id": i + 1, "type": entry[0], "level": level, "cell": [entry[1], entry[2]]})
	return {
		"seed": 1,
		"attacker": {"army": army, "unit_levels": unit_levels, "abilities": {}},
		"defender": {"buildings": entries, "resources": resources},
		"commands": commands,
	}


## A deploy command.
static func deploy(tick: int, unit: String, x: int, y: int) -> Dictionary:
	return {"op": "deploy", "tick": tick, "unit": unit, "cell": [x, y]}


## A battle on the battle catalog (20x20) from battle_setup's arguments.
static func battle(buildings: Array, army: Dictionary, commands: Array = [],
		resources: Dictionary = {}, unit_levels: Dictionary = {}) -> BattleSim:
	return BattleSim.create(battle_catalog(), battle_setup(buildings, army, commands, resources, unit_levels))
