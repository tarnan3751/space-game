extends TestCase
## Ground pathing: round buildings, round or through walls, no corner cutting, and the reach
## maps.

const Fixtures := preload("res://test/support/fixtures.gd")


func test_a_search_ends_next_to_the_nearest_candidate() -> void:
	var pathing := _pathing([["command_center", 10, 10], ["academy", 2, 2]])
	var m := pathing.map_for(BattlePathing.SET_HQ, 500)
	var path := pathing.find(_cell(4, 10), m)
	assert_eq(path, PackedInt32Array([_cell(4, 10), _cell(5, 10), _cell(6, 10), _cell(7, 10), _cell(8, 10),
		_cell(9, 10)]))
	assert_eq(pathing.found, 0)
	assert_eq(pathing.find(_cell(9, 10), m), PackedInt32Array([_cell(9, 10)]), "already in reach")
	m = pathing.map_for(BattlePathing.SET_ANY, 500)
	pathing.find(_cell(4, 4), m)
	assert_eq(pathing.found, 1, "any: the academy is the nearer")


func test_a_search_walks_round_a_short_wall_and_through_a_long_one() -> void:
	var short := _pathing([["command_center", 14, 9], ["wall", 8, 9], ["wall", 8, 10], ["wall", 8, 11]])
	var path := short.find(_cell(3, 10), short.map_for(BattlePathing.SET_HQ, 500))
	for cell: int in path:
		assert_true(cell % 20 != 8 or cell / 20 < 9 or cell / 20 > 11, "round the walls")
	var buildings := [["command_center", 15, 9]]
	for y: int in 20:
		buildings.append(["wall", 10, y])
	var long := _pathing(buildings)
	path = long.find(_cell(3, 10), long.map_for(BattlePathing.SET_HQ, 500))
	assert_true(path.has(_cell(10, 10)), "straight through the wall in its way")


func test_reach_maps_follow_falls_and_reveals() -> void:
	var catalog := Fixtures.battle_catalog()
	var layout := BattleLayout.new()
	layout.build(catalog, Fixtures.battle_setup([["academy", 10, 10], ["sentry", 4, 4]], {})["defender"]["buildings"],
		catalog.grid_size)
	var field := BattleField.new(catalog.grid_size)
	field.place_all(layout)
	var pathing := BattlePathing.new(field, layout, catalog.wall_cost_units)
	var m := pathing.map_for(BattlePathing.SET_ANY, 500)
	assert_eq(pathing.reach_count(m, _cell(11, 10)), 1)
	assert_eq(pathing.reach_count(m, _cell(5, 4)), 0, "the sentry is unseen")
	layout.reveal(1)
	pathing.building_revealed(1)
	assert_eq(pathing.reach_count(m, _cell(5, 4)), 1)
	layout.take(0, 1000)
	pathing.building_fell(0)
	assert_eq(pathing.reach_count(m, _cell(11, 10)), 0)
	assert_eq(pathing.map_for(BattlePathing.SET_ANY, 500), m, "one map per set and reach")
	assert_eq(pathing.map_count(), 1)


func test_no_corner_cutting() -> void:
	# A diagonal line of academies from (0, 9) to (9, 0) shuts the top-left corner in: only a
	# step between two diagonal blockers would leave it.
	var buildings := [["command_center", 15, 15]]
	for i: int in 10:
		buildings.append(["academy", i, 9 - i])
	var pathing := _pathing(buildings)
	var m := pathing.map_for(BattlePathing.SET_HQ, 500)
	assert_true(pathing.find(0, m).is_empty(), "shut in")
	assert_false(pathing.find(19 * 20 + 19, m).is_empty(), "the far corner gets there")


func _pathing(buildings: Array) -> BattlePathing:
	var catalog := Fixtures.battle_catalog()
	var layout := BattleLayout.new()
	layout.build(catalog, Fixtures.battle_setup(buildings, {})["defender"]["buildings"], catalog.grid_size)
	var field := BattleField.new(catalog.grid_size)
	field.place_all(layout)
	return BattlePathing.new(field, layout, catalog.wall_cost_units)


static func _cell(x: int, y: int) -> int:
	return y * 20 + x
