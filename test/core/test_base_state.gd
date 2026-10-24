extends TestCase
## Placement, limits, construction timers, upgrades, moves and save/load.

const Fixtures := preload("res://test/support/fixtures.gd")

const CC_ID := 1
const BAY_ID := 2


func test_new_base_uses_start_layout() -> void:
	var state := Fixtures.new_base()
	assert_eq(state.buildings.size(), 2)
	assert_eq(state.cc_level(), 1)
	assert_eq(state.resources["metal"], 500)
	assert_eq(state.resources["crystal"], 500)
	assert_eq(state.capacity("metal"), 1000)
	assert_eq(state.builders_free(), 1)
	assert_eq(state.grid.occupant_at(Vector2i(1, 1)), CC_ID)


func test_place_charges_cost_and_uses_a_builder() -> void:
	var state := Fixtures.new_base(1000)
	assert_eq(state.apply(_place("extractor", 5, 5), 1000), "")
	assert_eq(state.resources["crystal"], 400)
	assert_eq(state.builders_free(), 0)
	var extractor: BuildingState = state.buildings[3]
	assert_true(extractor.is_busy())
	assert_eq(extractor.level, 0)
	assert_eq(extractor.finish_at, 1060)


func test_place_rejects_overlap_and_out_of_bounds() -> void:
	var state := Fixtures.new_base()
	assert_eq(state.apply(_place("extractor", 0, 0), 0), BaseState.ERR_BLOCKED)
	assert_eq(state.apply(_place("extractor", 9, 9), 0), BaseState.ERR_BLOCKED)
	assert_eq(state.resources["crystal"], 500, "a failed command must not charge")


func test_place_rejects_without_free_builder() -> void:
	var state := Fixtures.new_base()
	assert_eq(state.apply(_place("extractor", 5, 5), 0), "")
	assert_eq(state.apply(_place("extractor", 7, 7), 0), BaseState.ERR_NO_BUILDER)


func test_place_rejects_without_funds() -> void:
	var state := Fixtures.new_base()
	state.resources["crystal"] = 50
	assert_eq(state.apply(_place("extractor", 5, 5), 0), BaseState.ERR_FUNDS)


func test_instant_buildings_skip_builders_but_respect_limits() -> void:
	var state := Fixtures.new_base()
	assert_eq(state.apply(_place("harvester", 9, 9), 0), "")
	assert_eq(state.buildings[3].level, 1)
	assert_eq(state.builders_free(), 1)
	assert_eq(state.apply(_place("harvester", 8, 8), 0), BaseState.ERR_LIMIT)


func test_a_type_locked_by_the_command_center_reads_as_locked_not_maxed() -> void:
	# The lab needs CC 2, and max_count at CC 1 is 0: the level gate is reported first.
	var state := Fixtures.new_base()
	assert_eq(state.check_can_build("lab"), BaseState.ERR_CC_LEVEL)
	assert_eq(state.apply(_place("lab", 5, 5), 0), BaseState.ERR_CC_LEVEL)
	state.apply({"op": "upgrade", "id": CC_ID}, 0)
	state.advance_to(100)
	assert_eq(state.check_can_build("lab"), "")
	assert_eq(state.apply(_place("lab", 5, 5), 100), "")
	assert_eq(state.check_can_build("lab"), BaseState.ERR_LIMIT)


func test_walls_place_instantly_without_a_builder_up_to_their_count() -> void:
	var state := Fixtures.new_base()
	assert_eq(state.apply(_place("extractor", 5, 2), 0), "")
	assert_eq(state.builders_free(), 0, "the only drone is busy")
	var limit := state.catalog.max_count("wall", 1)
	for i: int in limit:
		assert_eq(state.apply(_place("wall", i % 10, 5 + i / 10), 0), "", "wall %d" % i)
	assert_eq(state.count_of("wall"), limit)
	assert_eq(state.buildings[state.last_added_id].level, 1, "built at once")
	assert_eq(state.resources["metal"], 500 - 10 * limit)
	assert_eq(state.apply(_place("wall", 9, 9), 0), BaseState.ERR_LIMIT)


func test_construction_finishes_exactly_at_finish_time() -> void:
	var state := Fixtures.new_base(1000)
	state.apply(_place("extractor", 5, 5), 1000)
	state.advance_to(1059)
	assert_true(state.buildings[3].is_busy())
	assert_eq(state.seconds_left(3), 1)
	state.advance_to(1060)
	assert_false(state.buildings[3].is_busy())
	assert_eq(state.buildings[3].level, 1)
	assert_eq(state.builders_free(), 1)


func test_upgrade_command_center_raises_storage() -> void:
	var state := Fixtures.new_base()
	assert_eq(state.apply({"op": "upgrade", "id": CC_ID}, 0), "")
	assert_eq(state.resources["metal"], 100)
	assert_eq(state.capacity("metal"), 1000, "storage keeps working during an upgrade")
	state.advance_to(100)
	assert_eq(state.cc_level(), 2)
	assert_eq(state.capacity("metal"), 2000)


func test_upgrade_rules() -> void:
	var state := Fixtures.new_base()
	state.apply(_place("extractor", 5, 5), 0)
	assert_eq(state.apply({"op": "upgrade", "id": 3}, 0), BaseState.ERR_BUSY)
	state.advance_to(60)
	assert_eq(state.apply({"op": "upgrade", "id": 3}, 60), BaseState.ERR_CC_LEVEL)
	assert_eq(state.apply({"op": "upgrade", "id": BAY_ID}, 60), BaseState.ERR_MAX_LEVEL)
	assert_eq(state.apply({"op": "upgrade", "id": 99}, 60), BaseState.ERR_UNKNOWN_BUILDING)


func test_move_building() -> void:
	var state := Fixtures.new_base()
	assert_eq(state.apply({"op": "move", "id": BAY_ID, "cell": [8, 8]}, 0), "")
	assert_eq(state.buildings[BAY_ID].cell, Vector2i(8, 8))
	assert_eq(state.grid.occupant_at(Vector2i(3, 0)), 0)
	assert_eq(state.grid.occupant_at(Vector2i(8, 8)), BAY_ID)
	assert_eq(state.apply({"op": "move", "id": BAY_ID, "cell": [1, 1]}, 0), BaseState.ERR_BLOCKED)


func test_move_can_overlap_own_footprint() -> void:
	var state := Fixtures.new_base()
	state.apply(_place("extractor", 5, 5), 0)
	assert_eq(state.apply({"op": "move", "id": 3, "cell": [6, 5]}, 0), "")
	assert_eq(state.grid.occupant_at(Vector2i(5, 5)), 0)
	assert_eq(state.grid.occupant_at(Vector2i(7, 6)), 3)


func test_bad_commands_are_rejected() -> void:
	var state := Fixtures.new_base()
	assert_eq(state.apply({"op": "teleport"}, 0), BaseState.ERR_UNKNOWN_OP)
	assert_eq(state.apply({"op": "place", "type": "extractor"}, 0), BaseState.ERR_BLOCKED)
	assert_eq(state.apply(_place("castle", 5, 5), 0), BaseState.ERR_UNKNOWN_TYPE)


func test_changed_signal_fires_on_success_only() -> void:
	var state := Fixtures.new_base()
	var hits := [0]
	state.changed.connect(func() -> void: hits[0] += 1)
	state.apply(_place("extractor", 0, 0), 0)
	assert_eq(hits[0], 0)
	state.apply(_place("extractor", 5, 5), 0)
	assert_eq(hits[0], 1)


func test_clock_going_backwards_is_ignored() -> void:
	var state := Fixtures.new_base(1000)
	state.advance_to(500)
	assert_eq(state.now, 1000)


func test_save_round_trip_through_json() -> void:
	var state := Fixtures.new_base(0)
	state.apply(_place("harvester", 9, 9), 0)
	state.apply(_place("extractor", 5, 5), 10)
	state.advance_to(45)
	var json := JSON.stringify(state.to_dict())
	var restored := BaseState.from_dict(Fixtures.catalog(), JSON.parse_string(json))
	assert_eq(JSON.stringify(restored.to_dict()), json)
	assert_eq(restored.grid.occupant_at(Vector2i(6, 6)), 4)
	restored.advance_to(70)
	state.advance_to(70)
	assert_eq(JSON.stringify(restored.to_dict()), JSON.stringify(state.to_dict()))


func test_load_drops_buildings_that_no_longer_fit() -> void:
	# A save written before data changes: one extractor overflows the grid, one overlaps the CC.
	var data := Fixtures.new_base().to_dict()
	var saved: Array = data["buildings"]
	saved.append({"id": 3, "type": "extractor", "cell": [9, 9], "level": 1, "target_level": 1})
	saved.append({"id": 4, "type": "extractor", "cell": [1, 1], "level": 1, "target_level": 1})
	var state := BaseState.from_dict(Fixtures.catalog(), data)
	assert_eq(state.buildings.size(), 2)
	assert_eq(state.grid.occupant_at(Vector2i(1, 1)), CC_ID)
	assert_eq(state.count_of("extractor"), 0)


func test_save_from_before_the_third_resource_loads() -> void:
	# The shape every save had before antimatter existed: two resources, version 1.
	var data := {
		"version": 1, "now": 100, "next_id": 3,
		"resources": {"metal": 400, "crystal": 300},
		"remainders": {"metal": 0, "crystal": 1800},
		"buildings": [
			{"id": 1, "type": "command_center", "cell": [0, 0], "level": 1, "target_level": 1, "finish_at": 0},
			{"id": 2, "type": "drone_bay", "cell": [3, 0], "level": 1, "target_level": 1, "finish_at": 0},
		],
	}
	var state := BaseState.from_dict(Fixtures.catalog(), data)
	assert_eq(state.buildings.size(), 2)
	var saved := state.to_dict()
	assert_eq(saved["resources"], {"metal": 400, "crystal": 300, "antimatter": 0})
	assert_eq(saved["remainders"], {"metal": 0, "crystal": 1800, "antimatter": 0})
	assert_eq(saved["version"], 3)


func test_version_1_save_is_centred_on_a_grown_field() -> void:
	# A version 1 save was laid out on 40x40; on 48x48 every building moves by (4, 4), the two at
	# the old field's far edge included, and nothing else changes.
	var catalog := Fixtures.catalog_with_grid(Vector2i(48, 48))
	var data := _version_1_save()
	var state := BaseState.from_dict(catalog, data)
	assert_eq(state.buildings.size(), 4)
	var cells: Array[Vector2i] = [Vector2i(4, 4), Vector2i(7, 4), Vector2i(42, 42), Vector2i(43, 40)]
	for id: int in range(1, 5):
		assert_eq(state.buildings[id].cell, cells[id - 1], "building %d" % id)
	assert_eq(state.grid.occupant_at(Vector2i(43, 43)), 3, "the extractor covers its shifted footprint")
	assert_eq(state.grid.occupant_at(Vector2i(43, 40)), 4)
	assert_eq(state.grid.occupant_at(Vector2i(39, 36)), 0, "the wall's old cell is free")
	var saved := state.to_dict()
	assert_eq(saved["version"], 3)
	assert_eq(saved["grid"], {"width": 48, "height": 48})
	assert_eq(saved["now"], 100)
	assert_eq(saved["next_id"], 5)
	assert_eq(saved["resources"], {"metal": 400, "crystal": 300, "antimatter": 7})
	assert_eq(saved["remainders"], {"metal": 0, "crystal": 1800, "antimatter": 0})
	var extractor: Dictionary = (saved["buildings"] as Array)[2]
	assert_eq(extractor, {"id": 3, "type": "extractor", "cell": [42, 42], "level": 1, "target_level": 2,
		"finish_at": 150})


func test_save_with_no_version_loads_as_version_1() -> void:
	var catalog := Fixtures.catalog_with_grid(Vector2i(48, 48))
	var data := _version_1_save()
	data.erase("version")
	var state := BaseState.from_dict(catalog, data)
	assert_eq(state.buildings[1].cell, Vector2i(4, 4))
	assert_eq(state.buildings[3].cell, Vector2i(42, 42))


func test_version_2_save_loads_where_it_was() -> void:
	var catalog := Fixtures.catalog_with_grid(Vector2i(48, 48))
	var state := BaseState.from_dict(catalog, _version_1_save())
	var json := JSON.stringify(state.to_dict())
	var restored := BaseState.from_dict(catalog, JSON.parse_string(json))
	assert_eq(JSON.stringify(restored.to_dict()), json)
	assert_eq(restored.buildings[3].cell, Vector2i(42, 42))


func test_version_1_save_on_a_field_that_did_not_grow_stays_put() -> void:
	# The fixture's field is 10x10, smaller than a version 1 save's: nothing moves.
	var data := {"version": 1, "buildings": [
		{"id": 1, "type": "command_center", "cell": [0, 0], "level": 1, "target_level": 1, "finish_at": 0},
		{"id": 2, "type": "drone_bay", "cell": [9, 9], "level": 1, "target_level": 1, "finish_at": 0},
	]}
	var state := BaseState.from_dict(Fixtures.catalog(), data)
	assert_eq(state.buildings[1].cell, Vector2i(0, 0))
	assert_eq(state.buildings[2].cell, Vector2i(9, 9))


func test_counts_follow_place_move_and_upgrade() -> void:
	var state := Fixtures.new_base()
	assert_eq(state.count_of("extractor"), 0)
	assert_eq(state.count_of(Catalog.HQ_TYPE), 1)
	assert_eq(state.count_of("drone_bay"), 1)
	assert_eq(state.cc_level(), 1)
	assert_eq(state.builders_total(), 1)
	assert_eq(state.apply(_place("extractor", 5, 5), 0), "")
	assert_eq(state.count_of("extractor"), 1, "a building under construction counts")
	assert_eq(state.builders_busy(), 1)
	assert_eq(state.apply({"op": "move", "id": 3, "cell": [7, 7]}, 0), "")
	assert_eq(state.count_of("extractor"), 1)
	assert_eq(state.apply({"op": "upgrade", "id": CC_ID}, 60), "")
	assert_eq(state.builders_busy(), 1, "an upgrade occupies a builder")
	assert_eq(state.cc_level(), 1, "the level rises only when the upgrade completes")
	state.advance_to(160)
	assert_eq(state.cc_level(), 2)
	assert_eq(state.count_of(Catalog.HQ_TYPE), 1)
	assert_eq(state.builders_busy(), 0)
	assert_eq(state.builders_free(), 1)


func test_counts_survive_a_save_round_trip() -> void:
	var state := Fixtures.new_base()
	state.apply(_place("extractor", 5, 5), 0)
	state.apply(_place("mine", 9, 9), 0)
	var restored := BaseState.from_dict(Fixtures.catalog(), JSON.parse_string(JSON.stringify(state.to_dict())))
	for type: String in ["extractor", "mine", "drone_bay", Catalog.HQ_TYPE, "wall"]:
		assert_eq(restored.count_of(type), state.count_of(type), type)
	assert_eq(restored.cc_level(), state.cc_level())
	assert_eq(restored.builders_free(), state.builders_free())


func test_a_load_that_drops_buildings_counts_only_what_it_kept() -> void:
	var data := Fixtures.new_base().to_dict()
	var saved: Array = data["buildings"]
	# A level 2 Command Center that overflows the grid is dropped, so the level stays 1;
	# a second one that fits comes after the first, and the first one sets the level.
	saved.append({"id": 3, "type": Catalog.HQ_TYPE, "cell": [9, 9], "level": 2, "target_level": 2})
	saved.append({"id": 4, "type": Catalog.HQ_TYPE, "cell": [5, 5], "level": 2, "target_level": 2})
	saved.append({"id": 5, "type": "extractor", "cell": [1, 1], "level": 1, "target_level": 1})
	var state := BaseState.from_dict(Fixtures.catalog(), data)
	assert_eq(state.count_of(Catalog.HQ_TYPE), 2)
	assert_eq(state.cc_level(), 1)
	assert_eq(state.count_of("extractor"), 0)


func test_failed_commands_leave_counts_unchanged() -> void:
	var state := Fixtures.new_base()
	assert_eq(state.apply(_place("extractor", 0, 0), 0), BaseState.ERR_BLOCKED)
	assert_eq(state.apply(_place("castle", 7, 7), 0), BaseState.ERR_UNKNOWN_TYPE)
	assert_eq(state.count_of("extractor"), 0)
	state.apply(_place("extractor", 5, 5), 0)
	assert_eq(state.apply(_place("extractor", 7, 7), 0), BaseState.ERR_NO_BUILDER)
	assert_eq(state.apply({"op": "move", "id": 3, "cell": [0, 0]}, 0), BaseState.ERR_BLOCKED)
	assert_eq(state.apply({"op": "upgrade", "id": 3}, 0), BaseState.ERR_BUSY)
	assert_eq(state.apply({"op": "upgrade", "id": CC_ID}, 0), BaseState.ERR_NO_BUILDER)
	assert_eq(state.count_of("extractor"), 1)
	assert_eq(state.count_of(Catalog.HQ_TYPE), 1)
	assert_eq(state.cc_level(), 1)
	assert_eq(state.builders_busy(), 1)
	assert_eq(state.buildings.size(), 3)


func test_a_base_without_a_command_center_reads_as_level_one() -> void:
	var data := {"buildings": [
		{"id": 2, "type": "drone_bay", "cell": [3, 0], "level": 1, "target_level": 1, "finish_at": 0},
	]}
	var state := BaseState.from_dict(Fixtures.catalog(), data)
	assert_eq(state.count_of(Catalog.HQ_TYPE), 0)
	assert_eq(state.cc_level(), 1)
	assert_eq(state.builders_free(), 1)


func test_save_round_trip_with_the_army() -> void:
	# Mid-way through everything: a queue running, one paused by an upgrade, a research.
	var state := Fixtures.army_base()
	state.resources["metal"] = 1000
	state.apply({"op": "upgrade", "id": CC_ID}, 30)
	state.advance_to(130)
	state.apply(_place("lab", 5, 5), 130)
	state.apply(_place("academy", 8, 9), 160)
	state.apply({"op": "train", "id": 4, "unit": "grunt", "count": 3}, 160)
	state.apply({"op": "train", "id": 4, "unit": "flyer"}, 160)
	state.apply({"op": "train", "id": 6, "unit": "grunt", "count": 2}, 160)
	state.apply({"op": "research", "unit": "grunt"}, 165)
	state.apply({"op": "upgrade", "id": 6}, 175)
	state.advance_to(180)
	var saved := state.to_dict()
	assert_eq(saved["version"], BaseState.SAVE_VERSION)
	assert_eq(saved["army"], {"grunt": 3})
	assert_eq(saved["research"], {"unit": "grunt", "done_at": 225})
	assert_eq(saved["training"], [
		{"building": 4, "units": ["grunt", "flyer"], "paid_levels": [1, 1], "done_at": 190, "left": 0},
		{"building": 6, "units": ["grunt"], "paid_levels": [1], "done_at": 0, "left": 5},
	])
	var json := JSON.stringify(saved)
	var restored := BaseState.from_dict(Fixtures.catalog(), JSON.parse_string(json))
	assert_eq(JSON.stringify(restored.to_dict()), json)
	assert_eq(restored.training_status(6), BaseState.TRAINING_PAUSED)
	restored.advance_to(400)
	state.advance_to(400)
	assert_eq(JSON.stringify(restored.to_dict()), JSON.stringify(state.to_dict()))
	assert_eq(restored.unit_level("grunt"), 2)
	assert_eq(restored.army_count("grunt"), 5)
	assert_eq(restored.army_count("flyer"), 1)


func test_saving_leaves_the_unit_order_alone() -> void:
	var state := Fixtures.army_base()
	state.apply({"op": "train", "id": 4, "unit": "flyer"}, 30)
	state.advance_to(50)
	var saved := state.to_dict()
	assert_eq(saved["army"], {"flyer": 1})
	assert_eq(state.catalog.unit_types(), PackedStringArray(["grunt", "flyer", "walker"]), "units.json order")
	assert_eq(state.catalog.units_of_producer("academy"), PackedStringArray(["grunt", "flyer", "walker"]))


func test_saves_before_the_army_load_with_none() -> void:
	for version: int in [1, 2]:
		var data := _version_1_save()
		data["version"] = version
		var state := BaseState.from_dict(Fixtures.catalog_with_grid(Vector2i(48, 48)), data)
		assert_eq(state.army, {"grunt": 0, "flyer": 0, "walker": 0}, "version %d" % version)
		assert_eq(state.unit_levels, {"grunt": 1, "flyer": 1, "walker": 1}, "version %d" % version)
		assert_eq(state.training.size(), 0)
		assert_eq(state.research_unit, "")
		var saved := state.to_dict()
		assert_eq(saved["version"], 3)
		assert_eq(saved["army"], {})
		assert_eq(saved["unit_levels"], {})
		assert_eq(saved["research"], {})
		assert_eq(saved["training"], [])


func test_load_drops_army_entries_that_no_longer_fit() -> void:
	var data := Fixtures.army_base().to_dict()
	data["army"] = {"grunt": 25, "ghost": 3}
	data["unit_levels"] = {"grunt": 9, "ghost": 2}
	data["research"] = {"unit": "grunt", "done_at": 99}
	data["training"] = [
		{"building": 4, "units": ["ghost", "grunt", "walker"], "paid_levels": [1, 5, 1], "done_at": 35,
			"left": 0},
		{"building": 3, "units": ["grunt"], "paid_levels": [1], "done_at": 40, "left": 0},
		{"building": 77, "units": ["grunt"], "paid_levels": [1], "done_at": 40, "left": 0},
	]
	var state := BaseState.from_dict(Fixtures.catalog(), data)
	assert_eq(state.army, {"grunt": 25, "flyer": 0, "walker": 0}, "an army above the housing is kept")
	assert_eq(state.unit_level("grunt"), 2, "clamped to the top level")
	assert_eq(state.research_unit, "", "a unit at its top level is not researched")
	assert_eq(state.queue_of(4), PackedStringArray(["grunt", "walker"]))
	assert_eq(state.training[4].paid_levels, PackedInt32Array([2, 1]))
	assert_eq(state.training_seconds_left(4), 10, "the head was dropped: the next starts afresh")
	assert_false(state.training.has(3), "the hangar trains nothing")
	assert_false(state.training.has(77), "the building is gone")
	assert_eq(state.check_train(4, "grunt"), BaseState.ERR_HOUSING)
	state.advance_to(1000)
	assert_eq(state.army_count("grunt"), 25, "waits for room")
	assert_eq(state.training_status(4), BaseState.TRAINING_WAITING)


## A version 1 save: the fixture's Command Center and drone bay in its corner, an extractor
## upgrading in the old 40x40 field's far corner and a wall on its right edge.
func _version_1_save() -> Dictionary:
	return {
		"version": 1, "now": 100, "next_id": 5,
		"resources": {"metal": 400, "crystal": 300, "antimatter": 7},
		"remainders": {"metal": 0, "crystal": 1800, "antimatter": 0},
		"buildings": [
			{"id": 1, "type": "command_center", "cell": [0, 0], "level": 1, "target_level": 1, "finish_at": 0},
			{"id": 2, "type": "drone_bay", "cell": [3, 0], "level": 1, "target_level": 1, "finish_at": 0},
			{"id": 3, "type": "extractor", "cell": [38, 38], "level": 1, "target_level": 2, "finish_at": 150},
			{"id": 4, "type": "wall", "cell": [39, 36], "level": 1, "target_level": 1, "finish_at": 0},
		],
	}


func _place(type: String, x: int, y: int) -> Dictionary:
	return {"op": "place", "type": type, "cell": [x, y]}
