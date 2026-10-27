extends TestCase
## Ground pathing: round buildings, round or through walls, no corner cutting, the air pick, and
## the search budget in cells with a search in flight.

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


func test_the_reach_maps_are_built_at_setup() -> void:
	# melee (any, 500), breaker (wall, 500), hunter (defense, 800), drone (air: none); each ground
	# type its set and the two fallbacks at its reach.
	var commands := [Fixtures.deploy(0, "melee", 0, 0), Fixtures.deploy(0, "breaker", 19, 0),
		Fixtures.deploy(0, "hunter", 0, 19), Fixtures.deploy(0, "drone", 19, 19)]
	var sim := Fixtures.battle([["command_center", 9, 9], ["turret", 4, 4], ["wall", 14, 14]],
		{"melee": 1, "breaker": 1, "hunter": 1, "drone": 1, "gunner": 0}, commands)
	assert_eq(sim.pathing.map_count(), 6, "the gunner brought none: no map for its reach")
	for set_id: int in [BattlePathing.SET_ANY, BattlePathing.SET_WALL, BattlePathing.SET_ANY_HIDDEN]:
		assert_true(sim.pathing.map_for(set_id, 500) < 6, "set %d at 500 is there" % set_id)
	for set_id: int in [BattlePathing.SET_ANY, BattlePathing.SET_DEFENSE, BattlePathing.SET_ANY_HIDDEN]:
		assert_true(sim.pathing.map_for(set_id, 800) < 6, "set %d at 800 is there" % set_id)
	assert_eq(sim.pathing.map_count(), 6, "asking for them built none")
	while not sim.is_over():
		sim.step()
	assert_eq(sim.pathing.map_count(), 6, "no tick built one")


func test_a_map_is_right_when_a_building_falls_in_the_tick_it_would_be_built() -> void:
	# Built lazily, a map first asked for in the pass where a unit had just felled a building left
	# that building out, and passing the fall on then took its stamp off again: every cell in its
	# reach ended one count low. Built at setup, every map counts the standing candidates.
	var commands := [Fixtures.deploy(0, "gunner", 12, 10), Fixtures.deploy(180, "gunner", 12, 10),
		Fixtures.deploy(180, "hunter", 0, 11), Fixtures.deploy(200, "hunter", 0, 11),
		Fixtures.deploy(220, "hunter", 0, 12)]
	var sim := Fixtures.battle([["academy", 10, 10], ["command_center", 10, 12]], {"gunner": 2, "hunter": 3},
		commands)
	while not sim.is_over():
		sim.step()
	assert_eq(sim.state_hash(), 4102097120, "the battle as it plays with every map right")
	var pathing := sim.pathing
	var layout := sim.layout
	var wrong := 0
	for m: int in pathing.map_count():
		var set_id := pathing.map_set(m)
		var reach: int = pathing._map_reach[m]
		for cell: int in sim.field.width * sim.field.height:
			var px := BattleMath.centre(cell % sim.field.width)
			var py := BattleMath.centre(cell / sim.field.width)
			var n := 0
			for b: int in layout.count:
				if pathing.is_candidate(b, set_id) and BattleMath.dist2_to_rect(px, py, layout.x0[b], layout.y0[b],
						layout.x1[b], layout.y1[b]) <= reach * reach:
					n += 1
			if pathing.reach_count(m, cell) != n:
				wrong += 1
	assert_eq(wrong, 0, "every map's count at every cell is the standing candidates in reach")


func test_the_air_pick_is_the_nearest_standing_candidate() -> void:
	# nearest() against is_candidate and the distance to every building, over every set and a grid
	# of points, with a building fallen and the sentry unseen, then seen.
	var catalog := Fixtures.battle_catalog()
	var layout := BattleLayout.new()
	layout.build(catalog, Fixtures.battle_setup([["command_center", 9, 9], ["turret", 4, 4], ["academy", 15, 4],
		["sentry", 4, 15], ["wall", 12, 12], ["wall", 13, 12], ["mine", 16, 16], ["silo", 2, 9]],
		{})["defender"]["buildings"], catalog.grid_size)
	var field := BattleField.new(catalog.grid_size)
	field.place_all(layout)
	var pathing := BattlePathing.new(field, layout, catalog.wall_cost_units)
	layout.take(2, 100000)
	var wrong := 0
	for round: int in 2:
		for set_id: int in BattlePathing.SET_ANY_HIDDEN + 1:
			for py: int in range(500, 20000, 1500):
				for px: int in range(500, 20000, 1500):
					var best := -1
					var best_d2 := 0
					for b: int in layout.count:
						if not pathing.is_candidate(b, set_id):
							continue
						var d2 := BattleMath.dist2_to_rect(px, py, layout.x0[b], layout.y0[b], layout.x1[b],
							layout.y1[b])
						if best < 0 or d2 < best_d2:
							best = b
							best_d2 = d2
					if pathing.nearest(px, py, set_id) != best:
						wrong += 1
		layout.reveal(3)
	assert_eq(wrong, 0, "the same pick as the scan of every building")
	assert_eq(pathing.nearest(500, 500, BattlePathing.SET_RESOURCE), 7, "the silo")
	assert_eq(pathing.nearest(500, 500, BattlePathing.SET_ANY), 1, "the turret, the academy fallen")


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


func test_a_search_in_slices_is_the_whole_search() -> void:
	# begin() and advance() a few cells at a time give the path, the pick and the cells settled of
	# one find(), on a field that does not change between the slices.
	var buildings := [["command_center", 15, 9], ["academy", 4, 15], ["turret", 16, 2]]
	for y: int in range(3, 17):
		buildings.append(["wall", 10, y])
	var pathing := _pathing(buildings)
	var wrong := 0
	for set_id: int in [BattlePathing.SET_HQ, BattlePathing.SET_ANY, BattlePathing.SET_DEFENSE]:
		var m := pathing.map_for(set_id, 500)
		for start: int in [_cell(0, 0), _cell(3, 10), _cell(19, 19), _cell(12, 18)]:
			var before := pathing.settled
			var whole := pathing.find(start, m)
			var whole_found := pathing.found
			var whole_cells := pathing.settled - before
			for slice: int in [1, 3, 17]:
				before = pathing.settled
				pathing.begin(start, m)
				var slices := 0
				while pathing.searching:
					var used := pathing.advance(slice)
					if used > slice:
						wrong += 1
					slices += 1
				if pathing.path != whole or pathing.found != whole_found or pathing.settled - before != whole_cells:
					wrong += 1
				if whole_cells > slice and slices < 2:
					wrong += 1
	assert_eq(wrong, 0, "every sliced search is its whole search")


func test_searches_share_a_budget_of_cells() -> void:
	# Three units far from the only building on the 48x48 field, at 200 cells a tick: no tick
	# settles more, the searches finish one after another in id order, and each path is the one a
	# whole search gives on the field as it stands.
	var catalog := Fixtures.battle_catalog(Vector2i(48, 48))
	catalog.search_cells = 200
	var commands := [Fixtures.deploy(0, "melee", 0, 0), Fixtures.deploy(0, "melee", 0, 12),
		Fixtures.deploy(0, "melee", 12, 0)]
	var setup := Fixtures.battle_setup([["command_center", 38, 38]], {"melee": 3}, commands)
	var sim := BattleSim.create(catalog, setup)
	var walking_at := PackedInt32Array([-1, -1, -1])
	var over := 0
	while walking_at.has(-1) and sim.tick < 200:
		var before := sim.pathing.settled
		sim.step()
		if sim.pathing.settled - before > 200:
			over += 1
		for u: int in 3:
			if walking_at[u] < 0 and sim.unit_state(u + 1) == BattleArmy.WALKING:
				walking_at[u] = sim.tick
	assert_eq(over, 0, "no tick settles more than its budget")
	assert_true(walking_at[0] > 1, "the first search takes more than a tick: %s" % walking_at)
	assert_true(walking_at[0] <= walking_at[1] and walking_at[1] <= walking_at[2], "in id order: %s" % walking_at)
	var whole := BattleSim.create(catalog, setup)
	var m := whole.pathing.map_for(BattlePathing.SET_ANY, 500)
	for u: int in 3:
		var at := Vector2i(commands[u]["cell"][0], commands[u]["cell"][1])
		assert_eq(sim.army._paths[u], whole.pathing.find(at.y * 48 + at.x, m), "unit %d's path" % (u + 1))
	# Six on one cell share one search.
	commands = []
	for i: int in 6:
		commands.append(Fixtures.deploy(0, "melee", 0, 0))
	sim = Fixtures.battle([["command_center", 15, 9]], {"melee": 6}, commands)
	sim.step()
	assert_eq(sim.pathing.searches, 1, "one cell, one type: one search")
	assert_eq(sim.unit_state(6), BattleArmy.WALKING)


func test_a_search_in_flight_goes_on_over_a_fall() -> void:
	# At 10 cells a tick, a hunter's search across the 48x48 field for the only turret has settled
	# the cells beside a silo when four raiders fell it: the search goes on over the opened field
	# to the standing turret, by a path every step of which is walkable on the field as it then
	# stands, and the battle replays to the same hash at every tick.
	var catalog := Fixtures.battle_catalog(Vector2i(48, 48))
	catalog.search_cells = 10
	var commands := []
	for i: int in 4:
		commands.append(Fixtures.deploy(0, "raider", 2, 28))
	commands.append(Fixtures.deploy(0, "hunter", 0, 24))
	var setup := Fixtures.battle_setup([["silo", 5, 27], ["turret", 40, 10]], {"raider": 4, "hunter": 1}, commands)
	var sim := BattleSim.create(catalog, setup)
	var twin := BattleSim.create(catalog, setup)
	var pathing := sim.pathing
	var differ := 0
	var fell_in_flight := false
	var beside_settled := false
	while sim.unit_state(5) != BattleArmy.WALKING and sim.tick < 1000:
		var standing := not sim.is_destroyed(1)
		sim.step()
		twin.step()
		if sim.state_hash() != twin.state_hash():
			differ += 1
		if standing and sim.is_destroyed(1):
			fell_in_flight = pathing.searching and pathing.map_set(pathing.search_map) == BattlePathing.SET_DEFENSE
			for cell: Vector2i in [Vector2i(4, 27), Vector2i(4, 28), Vector2i(5, 26), Vector2i(6, 26),
					Vector2i(7, 27), Vector2i(7, 28), Vector2i(5, 29), Vector2i(6, 29)]:
				if pathing._done[pathing._grown(cell.y * 48 + cell.x)] == pathing._search_stamp:
					beside_settled = true
			var before := sim.state_hash()
			pathing._search_settled += 1
			assert_true(sim.state_hash() != before, "the hash covers the search in flight")
			pathing._search_settled -= 1
	assert_true(fell_in_flight, "the silo fell while the hunter's search was in flight")
	assert_true(beside_settled, "with cells beside the silo already settled")
	assert_eq(sim.unit_state(5), BattleArmy.WALKING)
	assert_eq(sim.unit_target(5), 2, "the standing turret")
	var path := sim.army._paths[4]
	var bad := 0
	for k: int in path.size():
		if sim.field.kind[path[k]] == BattleField.BUILDING:
			bad += 1
		if k == 0:
			continue
		var dx := path[k] % 48 - path[k - 1] % 48
		var dy := path[k] / 48 - path[k - 1] / 48
		if absi(dx) > 1 or absi(dy) > 1:
			bad += 1
		elif dx != 0 and dy != 0 and (sim.field.kind[path[k - 1] + dx] != BattleField.FREE
				or sim.field.kind[path[k - 1] + dy * 48] != BattleField.FREE):
			bad += 1
	assert_eq(bad, 0, "every step walkable on the changed field")
	while not sim.is_over():
		sim.step()
		twin.step()
		if sim.state_hash() != twin.state_hash():
			differ += 1
	assert_eq(differ, 0, "the same hash at every tick")
	var replay := setup.duplicate(true)
	replay["commands"] = sim.result()["commands"]
	assert_eq(JSON.stringify(BattleSim.run(catalog, replay)), JSON.stringify(sim.result()), "the replay")


func test_a_search_in_flight_is_dropped_when_its_set_has_nothing_standing() -> void:
	# At 5 cells a tick, a hunter's search for the only turret is in flight when four melee fell
	# the turret: the search is dropped rather than settling every cell it reaches for nothing,
	# and the hunter takes the Command Center.
	var catalog := Fixtures.battle_catalog(Vector2i(48, 48))
	catalog.search_cells = 5
	var commands := []
	for i: int in 4:
		commands.append(Fixtures.deploy(0, "melee", 7, 10))
	commands.append(Fixtures.deploy(0, "hunter", 0, 47))
	var sim := BattleSim.create(catalog, Fixtures.battle_setup([["turret", 10, 10], ["command_center", 40, 40]],
		{"melee": 4, "hunter": 1}, commands))
	var pathing := sim.pathing
	var in_flight_at_fall := false
	var defence_search_after := 0
	while not sim.is_destroyed(1) and sim.tick < 1000:
		in_flight_at_fall = pathing.searching and pathing.map_set(pathing.search_map) == BattlePathing.SET_DEFENSE
		sim.step()
	assert_true(sim.is_destroyed(1), "the turret fell")
	assert_true(in_flight_at_fall, "with the hunter's search for it in flight")
	for i: int in 3:
		if pathing.searching and pathing.map_set(pathing.search_map) == BattlePathing.SET_DEFENSE:
			defence_search_after += 1
		sim.step()
		if pathing.searching and pathing.map_set(pathing.search_map) == BattlePathing.SET_DEFENSE:
			defence_search_after += 1
	assert_eq(defence_search_after, 0, "the search for a defence is dropped")
	_step_until(sim, func() -> bool: return sim.unit_state(5) == BattleArmy.WALKING)
	assert_eq(sim.unit_target(5), 2, "the hunter takes the Command Center")


func test_no_search_runs_when_nothing_stands() -> void:
	# Four units round the only building (a shield generator, which does not fire), hitting it in
	# id order: the hit that fells it leaves the units after the hitter wanting another target in
	# that tick, and none stands, so none searches (a search would settle every cell it can reach).
	var commands := [Fixtures.deploy(0, "melee", 8, 10), Fixtures.deploy(0, "melee", 12, 10),
		Fixtures.deploy(0, "melee", 10, 8), Fixtures.deploy(0, "melee", 10, 12)]
	var sim := Fixtures.battle([["shield", 10, 10], ["wall", 2, 2]], {"melee": 4}, commands)
	var searches := 0
	while not sim.is_over():
		searches = sim.pathing.searches
		sim.step()
	assert_true(sim.is_destroyed(1))
	assert_eq(sim.pathing.searches, searches, "the last tick searched nothing")
	var waiting := 0
	for id: int in [1, 2, 3, 4]:
		if sim.unit_state(id) == BattleArmy.IDLE:
			waiting += 1
	assert_true(waiting > 0, "a unit that noticed the fall waits")


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
