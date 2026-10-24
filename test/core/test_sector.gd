extends TestCase
## A base's sector (docs/reference/expeditions.md): its seeds and its save shape.

const Fixtures := preload("res://test/support/fixtures.gd")


func test_the_sector_seed_comes_from_the_creation_time() -> void:
	assert_eq(Sector.seed_from_time(1700000000), Sector.seed_from_time(1700000000))
	assert_true(Sector.seed_from_time(1700000000) != Sector.seed_from_time(1700000001))
	assert_eq(Sector.seed_from_time(0), Sector.mix(Sector.SEED_SALT, 0))
	var seed_value := Sector.seed_from_time(-5)
	assert_true(seed_value >= 0 and seed_value <= 0xFFFFFFFF, "a 32-bit seed even from a negative time")


func test_every_field_has_its_own_seed() -> void:
	var sector := Sector.new()
	sector.sector_seed = 99
	var seeds := {}
	for index: int in 6:
		seeds[sector.field_seed(index)] = true
	sector.epoch = 1
	for index: int in 6:
		seeds[sector.field_seed(index)] = true
	assert_eq(seeds.size(), 12)
	assert_eq(sector.field_seed(3), Sector.field_seed_of(99, 1, 3))


func test_cleared_fields_stay_sorted_and_unique() -> void:
	var sector := Sector.new()
	sector.clear_field(4)
	sector.clear_field(1)
	sector.clear_field(4)
	assert_eq(sector.cleared, PackedInt32Array([1, 4]))
	assert_true(sector.is_cleared(1))
	assert_false(sector.is_cleared(2))


func test_a_sector_round_trips() -> void:
	var catalog := Fixtures.expedition_catalog()
	var sector := Sector.new()
	sector.sector_seed = 1234
	sector.epoch = 3
	sector.last_scan = 500
	sector.clear_field(5)
	sector.clear_field(0)
	sector.snapshot(4, {"metal": 9000, "crystal": 8000, "antimatter": 400})
	var saved := sector.to_dict()
	assert_eq(saved, {"seed": 1234, "epoch": 3, "cleared": [0, 5], "last_scan": 500, "cc": 4,
		"capacity": {"metal": 9000, "crystal": 8000, "antimatter": 400}})
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(saved))
	assert_eq(Sector.from_dict(catalog, parsed, 500).to_dict(), saved)


func test_a_dirty_sector_is_cleaned_on_load() -> void:
	var catalog := Fixtures.expedition_catalog()
	var sector := Sector.from_dict(catalog, {"seed": 5, "epoch": -2, "cleared": [7, 2, 2, -1, 1],
		"cc": 40, "capacity": {"metal": 100, "gold": 5, "crystal": -3}, "last_scan": 800}, 600)
	assert_eq(sector.epoch, 0)
	assert_eq(sector.cleared, PackedInt32Array([1, 2]))
	assert_eq(sector.cc, 10)
	assert_eq(sector.capacity, {"metal": 100, "crystal": 0, "antimatter": 0})
	assert_eq(sector.last_scan, 600, "a last scan ahead of now is brought back to now")
	assert_eq(Sector.from_dict(catalog, {"last_scan": 400}, 600).last_scan, 400, "one behind is kept")


func test_cleared_entries_that_are_not_field_indices_are_dropped() -> void:
	var catalog := Fixtures.expedition_catalog()
	var sector := Sector.from_dict(catalog, {"cleared": ["x", 0.5, -1, 99, 2]}, 0)
	assert_eq(sector.cleared, PackedInt32Array([2]))
	var parsed: Dictionary = JSON.parse_string('{"cleared": [3.0, 1]}')
	assert_eq(Sector.from_dict(catalog, parsed, 0).cleared, PackedInt32Array([1, 3]), "JSON floats that are whole count")
