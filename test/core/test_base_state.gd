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
	assert_eq(saved["version"], 1)


func _place(type: String, x: int, y: int) -> Dictionary:
	return {"op": "place", "type": type, "cell": [x, y]}
