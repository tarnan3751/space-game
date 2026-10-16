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
##   hangar    2x2: 100 metal, 30 s, capacity 20 (L2 30, needs CC 2)
##   lab       2x2: 100 metal, 30 s, needs CC 2 (max_count 0 at CC 1)
##   mine      1x1: 20 metal, instant, hidden, targets ground, max 2
##   wall      1x1: 10 metal, instant, max 25

const RULES := "res://test/support/fixtures/rules.json"
const BUILDINGS := "res://test/support/fixtures/buildings.json"


static func catalog() -> Catalog:
	return Catalog.from_json(
		FileAccess.get_file_as_string(RULES),
		FileAccess.get_file_as_string(BUILDINGS)
	)


## The fixture catalog on a field of `size`, its rules otherwise unchanged.
static func catalog_with_grid(size: Vector2i) -> Catalog:
	var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RULES))
	rules["grid"] = {"width": size.x, "height": size.y}
	return Catalog.from_json(JSON.stringify(rules), FileAccess.get_file_as_string(BUILDINGS))


static func new_base(start_time: int = 0) -> BaseState:
	return BaseState.create_new(catalog(), start_time)
