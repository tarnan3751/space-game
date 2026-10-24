extends TestCase
## Ground pathing: round buildings, round or through walls, no corner cutting, and the search
## budget.

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


func test_a_straight_walk_to_an_open_target() -> void:
	var sim := Fixtures.battle([["command_center", 10, 10]], {"melee": 1}, [Fixtures.deploy(0, "melee", 2, 10)])
	sim.step()
	assert_eq(sim.unit_state(1), BattleArmy.WALKING)
	assert_eq(sim.unit_target(1), 1)
	_step_until(sim, func() -> bool: return sim.unit_state(1) == BattleArmy.ATTACKING)
	assert_eq(sim.unit_position(1), Vector2i(9500, 10500), "stops on the cell next to the footprint")
	# Seven cells at a cell a second (50 units a tick), from the first tick.
	assert_eq(sim.tick, 140)


func test_walking_round_a_building() -> void:
	# A lab (2x2) between the unit and the hunter's turret: the path goes round it.
	var sim := Fixtures.battle([["turret", 14, 10], ["lab", 8, 9], ["command_center", 0, 18]], {"hunter": 1},
		[Fixtures.deploy(0, "hunter", 4, 10)])
	sim.step()
	var path := sim.army._paths[0]
	assert_false(path.is_empty())
	for cell: int in path:
		var at := Vector2i(cell % 20, cell / 20)
		assert_false(at.x >= 8 and at.x <= 9 and at.y >= 9 and at.y <= 10, "%s is inside the lab" % at)
	assert_eq(sim.unit_target(1), 1)


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


func test_a_short_detour_round_walls_is_taken() -> void:
	# Three walls across the way: walking round costs a few cells, less than one wall's 8000.
	var sim := Fixtures.battle([["command_center", 14, 9], ["wall", 8, 9], ["wall", 8, 10], ["wall", 8, 11]],
		{"melee": 1}, [Fixtures.deploy(0, "melee", 3, 10)])
	sim.step()
	assert_eq(sim.unit_target(1), 1, "the Command Center, not a wall")
	_step_until(sim, func() -> bool: return sim.unit_state(1) == BattleArmy.ATTACKING)
	assert_eq(sim.unit_target(1), 1)
	for id: int in [2, 3, 4]:
		assert_false(sim.is_destroyed(id))


func test_a_long_wall_line_is_broken_through() -> void:
	# A wall right across the field: the unit attacks the wall in its way, then walks on.
	var buildings := [["command_center", 15, 9]]
	for y: int in 20:
		buildings.append(["wall", 10, y])
	var sim := Fixtures.battle(buildings, {"melee": 1}, [Fixtures.deploy(0, "melee", 3, 10)])
	sim.step()
	var wall := sim.unit_target(1)
	assert_true(wall >= 2, "a wall is the target")
	_step_until(sim, func() -> bool: return sim.is_destroyed(wall))
	assert_eq(sim.unit_position(1), Vector2i(9500, 10500), "it broke the wall in front of it")
	sim.step()
	sim.step()
	assert_eq(sim.unit_target(1), 1, "then goes on to the Command Center")
	_step_until(sim, func() -> bool: return sim.unit_state(1) == BattleArmy.ATTACKING)
	assert_eq(sim.unit_target(1), 1)


func test_a_shut_in_target_waits_for_a_gap() -> void:
	# The turret is ringed by academies: the hunter (prefers defences) finds no way and waits;
	# two melee units break an academy, and the hunter walks in.
	var buildings := [["turret", 10, 10], ["command_center", 0, 18]]
	for cell: Vector2i in [Vector2i(9, 9), Vector2i(10, 9), Vector2i(11, 9), Vector2i(9, 10), Vector2i(11, 10),
			Vector2i(9, 11), Vector2i(10, 11), Vector2i(11, 11)]:
		buildings.append(["academy", cell.x, cell.y])
	var sim := Fixtures.battle(buildings, {"hunter": 1, "melee": 2},
		[Fixtures.deploy(0, "hunter", 10, 3), Fixtures.deploy(0, "melee", 3, 10), Fixtures.deploy(0, "melee", 3, 10)])
	sim.step()
	assert_eq(sim.unit_target(1), 0, "nothing reachable")
	assert_eq(sim.unit_state(1), BattleArmy.IDLE)
	_step_until(sim, func() -> bool: return sim.unit_target(1) != 0)
	assert_eq(sim.unit_target(1), 1, "a gap opened: the turret")


func test_searches_are_budgeted_and_shared() -> void:
	var commands := []
	for i: int in 6:
		commands.append(Fixtures.deploy(0, "melee", 0, i * 3))
	var sim := Fixtures.battle([["command_center", 15, 9]], {"melee": 6}, commands)
	sim.step()
	assert_eq(sim.pathing.searches, BattleArmy.PATHS_PER_TICK)
	assert_eq(sim.unit_state(5), BattleArmy.IDLE, "the fifth waits its turn")
	assert_eq(sim.unit_state(4), BattleArmy.WALKING)
	sim.step()
	assert_eq(sim.pathing.searches, 6)
	assert_eq(sim.unit_state(6), BattleArmy.WALKING)
	commands = []
	for i: int in 6:
		commands.append(Fixtures.deploy(0, "melee", 0, 0))
	sim = Fixtures.battle([["command_center", 15, 9]], {"melee": 6}, commands)
	sim.step()
	assert_eq(sim.pathing.searches, 1, "one cell, one type: one search")
	assert_eq(sim.unit_state(6), BattleArmy.WALKING)


func _step_until(sim: BattleSim, done: Callable) -> void:
	var guard := 0
	while not done.call() and not sim.is_over() and guard < 5000:
		sim.step()
		guard += 1


func _pathing(buildings: Array) -> BattlePathing:
	var catalog := Fixtures.battle_catalog()
	var layout := BattleLayout.new()
	layout.build(catalog, Fixtures.battle_setup(buildings, {})["defender"]["buildings"], catalog.grid_size)
	var field := BattleField.new(catalog.grid_size)
	field.place_all(layout)
	return BattlePathing.new(field, layout, catalog.wall_cost_units)


static func _cell(x: int, y: int) -> int:
	return y * 20 + x
