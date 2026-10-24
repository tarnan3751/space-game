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


# --- The base's sector -----------------------------------------------------------

func test_a_new_base_seeds_its_sector_from_its_creation_time() -> void:
	var state := _base(1000)
	assert_eq(state.sector.sector_seed, Sector.seed_from_time(1000))
	assert_eq(state.sector.epoch, 0)
	assert_eq(state.sector.cleared, PackedInt32Array())
	assert_eq(state.sector.cc, 1)
	assert_eq(state.sector.capacity, {"metal": 1000, "crystal": 1000, "antimatter": 0})
	assert_eq(_base(1000).sector.to_dict(), state.sector.to_dict(), "the same time, the same sector")
	assert_true(_base(1001).sector.sector_seed != state.sector.sector_seed)


func test_the_first_scan_is_free_then_the_cooldown_holds() -> void:
	var state := _base(1000)
	assert_eq(state.scan_seconds_left(), 0)
	assert_eq(state.check_scan(), "")
	assert_eq(state.apply({"op": "scan"}, 1000), "")
	assert_eq(state.sector.epoch, 1)
	assert_eq(state.sector.last_scan, 1000)
	state.advance_to(1010)
	assert_eq(state.scan_seconds_left(), 50)
	assert_eq(state.check_scan(), BaseState.ERR_SCAN_COOLDOWN)
	var before := JSON.stringify(state.to_dict())
	assert_eq(state.apply({"op": "scan"}, 1010), BaseState.ERR_SCAN_COOLDOWN)
	assert_eq(JSON.stringify(state.to_dict()), before, "a refused scan changes nothing")
	state.advance_to(1059)
	assert_eq(state.scan_seconds_left(), 1)
	assert_eq(state.apply({"op": "scan"}, 1060), "")
	assert_eq(state.sector.epoch, 2)
	assert_eq(state.scan_seconds_left(), 60)


func test_a_scan_starts_new_fields_against_the_base_as_it_is() -> void:
	var state := _base(1000)
	state.sector.clear_field(2)
	var seeds_before: Array = []
	for field: Dictionary in state.sector_fields():
		seeds_before.append(field["seed"])
	# A silo built since: the capacity grows, but the fields keep the old snapshot until a scan.
	assert_eq(state.apply({"op": "place", "type": "silo", "cell": [1, 1]}, 1000), "")
	state.advance_to(1000)
	assert_eq(state.capacity("metal"), 3000)
	assert_eq(state.sector.capacity["metal"], 1000)
	assert_eq(state.apply({"op": "scan"}, 1000), "")
	assert_eq(state.sector.cleared, PackedInt32Array(), "nothing cleared in a new epoch")
	assert_eq(state.sector.capacity["metal"], 3000)
	var fields := state.sector_fields()
	for index: int in fields.size():
		assert_true(fields[index]["seed"] != seeds_before[index], "field %d has a new seed" % index)


func test_sector_fields_describe_every_field() -> void:
	var state := _base(1000)
	state.sector.clear_field(3)
	var fields := state.sector_fields()
	assert_eq(fields.size(), 6)
	var bands := PackedStringArray()
	var levels: Array[int] = []
	for index: int in fields.size():
		var field: Dictionary = fields[index]
		assert_eq(field["index"], index)
		assert_eq(field["cleared"], index == 3)
		assert_eq(field["seed"], state.sector.field_seed(index))
		bands.append(str(field["band"]))
		levels.append(int(field["cc"]))
	assert_eq(bands, PackedStringArray(["easy", "easy", "even", "even", "hard", "hard"]))
	assert_eq(levels, [1, 1, 1, 1, 2, 2] as Array[int], "easy clamped at 1, hard one up")
	# Loot: 15%, 25% and 40% of 1000 metal and crystal; no antimatter storage, so none.
	assert_eq(fields[0]["loot"], {"metal": 150, "crystal": 150, "antimatter": 0})
	assert_eq(fields[2]["loot"], {"metal": 250, "crystal": 250, "antimatter": 0})
	assert_eq(fields[4]["loot"], {"metal": 400, "crystal": 400, "antimatter": 0})


func test_generate_reads_the_sector() -> void:
	var state := _base(1000)
	var field := OutpostGenerator.generate(state.catalog, state, 4)
	var direct := OutpostGenerator.generate_field(state.catalog, state.sector.sector_seed, 0, 4, 1,
		state.sector.capacity)
	assert_eq(JSON.stringify(field), JSON.stringify(direct))
	assert_eq(OutpostGenerator.generate(state.catalog, state, 6), {})


func test_the_sector_round_trips_through_the_save() -> void:
	var state := _base(1000)
	state.apply({"op": "scan"}, 1000)
	state.sector.clear_field(1)
	var json := JSON.stringify(state.to_dict())
	var restored := BaseState.from_dict(state.catalog, JSON.parse_string(json))
	assert_eq(JSON.stringify(restored.to_dict()), json)
	assert_eq(restored.sector.epoch, 1)
	assert_eq(restored.sector.cleared, PackedInt32Array([1]))


func test_a_last_scan_ahead_of_the_saved_time_is_brought_back() -> void:
	# A clock set back after a scan: the cooldown runs from the save's now, not from the future.
	var state := _base(1000)
	state.apply({"op": "scan"}, 1000)
	var data := state.to_dict()
	data["sector"]["last_scan"] = 900000
	var loaded := BaseState.from_dict(state.catalog, data)
	assert_eq(loaded.sector.last_scan, 1000)
	assert_eq(loaded.scan_seconds_left(), 60)


func test_a_version_4_save_migrates_its_sector_from_its_now() -> void:
	var data := _base(1000).to_dict()
	data["version"] = 4
	data["now"] = 5000
	data.erase("sector")
	var state := BaseState.from_dict(Fixtures.expedition_catalog(), data)
	assert_eq(state.sector.sector_seed, Sector.seed_from_time(5000))
	assert_eq(state.sector.epoch, 0)
	assert_eq(state.sector.cc, 1)
	assert_eq(state.sector.capacity["metal"], 1000)
	assert_eq(state.to_dict()["version"], 5)
	data.erase("now")
	assert_eq(BaseState.from_dict(Fixtures.expedition_catalog(), data).sector.sector_seed, Sector.seed_from_time(0))


func test_a_catalog_without_expeditions_has_no_fields_and_still_scans() -> void:
	var state := Fixtures.new_base(0)
	assert_eq(state.sector_fields(), [] as Array[Dictionary])
	assert_eq(state.apply({"op": "scan"}, 10), "")
	assert_eq(state.apply({"op": "scan"}, 10), "", "no cooldown without the rules")


func _base(time: int) -> BaseState:
	return BaseState.create_new(Fixtures.expedition_catalog(), time)
