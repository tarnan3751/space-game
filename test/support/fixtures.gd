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
##   lab       2x2: 100 metal, 30 s, needs CC 2 (max_count 0 at CC 1); researches (L2 200 metal, 60 s)
##   mine      1x1: 20 metal, instant, hidden, targets ground, max 2
##   wall      1x1: 10 metal, instant, max 25
##
## Fixture units (all trained by the academy):
##   grunt  ground, housing 1, 10 s, 10 crystal (L2: research 100 crystal, 60 s, lab 1; trains for 20)
##   flyer  air, housing 2, 20 s, 20 crystal (L2: research 200 crystal, 120 s, lab 2; trains for 30)
##   walker ground, housing 5, 30 s, 50 crystal, needs academy level 2, one level

const RULES := "res://test/support/fixtures/rules.json"
const BUILDINGS := "res://test/support/fixtures/buildings.json"
const UNITS := "res://test/support/fixtures/units.json"


static func catalog() -> Catalog:
	return Catalog.from_json(
		FileAccess.get_file_as_string(RULES),
		FileAccess.get_file_as_string(BUILDINGS),
		FileAccess.get_file_as_string(UNITS)
	)


## The fixture catalog on a field of `size`, its rules otherwise unchanged.
static func catalog_with_grid(size: Vector2i) -> Catalog:
	var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RULES))
	rules["grid"] = {"width": size.x, "height": size.y}
	return Catalog.from_json(JSON.stringify(rules), FileAccess.get_file_as_string(BUILDINGS),
		FileAccess.get_file_as_string(UNITS))


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
