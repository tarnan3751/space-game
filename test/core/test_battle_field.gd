extends TestCase
## The battle's layout and its deploy zone: what a setup accepts, where units may be deployed and
## how the zone opens as buildings fall.

const Fixtures := preload("res://test/support/fixtures.gd")


func test_isqrt_is_the_floor_of_the_root() -> void:
	for n: int in [0, 1, 2, 3, 4, 8, 9, 15, 16, 999999, 1000000, 1000001, 1999396, 2000000]:
		var r := BattleMath.isqrt(n)
		assert_true(r * r <= n and (r + 1) * (r + 1) > n, "isqrt(%d) = %d" % [n, r])
	for n: int in [4194303, 4194304, 4194305, 4608000000, 4608000001, 2147395600, 2147483647, 99999999999]:
		var r := BattleMath.isqrt(n)
		assert_true(r * r <= n and (r + 1) * (r + 1) > n, "isqrt(%d) = %d" % [n, r])
	for k: int in range(1, 3000):
		var r := BattleMath.isqrt(k * k - 1)
		assert_eq(r, k - 1, "just under %d squared" % k)
		assert_eq(BattleMath.isqrt(k * k), k)


func test_a_layout_is_built_in_id_order() -> void:
	var catalog := Fixtures.battle_catalog()
	var layout := BattleLayout.new()
	var entries := [
		{"id": 7, "type": "turret", "level": 1, "cell": [5, 5], "target_level": 1},
		{"id": 2, "type": "command_center", "level": 2.0, "cell": [0.0, 0.0]},
		{"id": 4, "type": "academy", "level": 0, "cell": [9, 9]},
		{"id": 3, "type": "wall", "level": 1, "cell": [12, 12]},
	]
	assert_eq(layout.build(catalog, entries, catalog.grid_size), "")
	assert_eq(layout.ids, PackedInt32Array([2, 3, 7]), "id order; the level-0 academy left out")
	assert_eq(layout.index_of(7), 2)
	assert_eq(layout.index_of(4), -1)
	assert_eq(layout.classes, PackedInt32Array([BattleLayout.HQ, BattleLayout.WALL, BattleLayout.DEFENSE]))
	assert_eq(layout.max_hp[0], 1000)
	assert_eq(layout.reach[2], 3000)
	assert_eq(layout.targets[2], BattleLayout.GROUND)
	assert_eq(Vector4i(layout.x0[0], layout.y0[0], layout.x1[0], layout.y1[0]), Vector4i(0, 0, 2000, 2000))
	assert_eq(Vector2i(layout.cx[0], layout.cy[0]), Vector2i(1000, 1000))
	assert_eq(layout.counted, 2, "walls do not count")
	assert_eq(layout.hq_index, 0)


func test_a_layout_refuses_what_it_cannot_lay_out() -> void:
	var catalog := Fixtures.battle_catalog()
	var cases := {
		"unknown type 'castle'": [{"id": 1, "type": "castle", "level": 1, "cell": [0, 0]}],
		"has no level 3": [{"id": 1, "type": "command_center", "level": 3, "cell": [0, 0]}],
		"needs a cell [x, y]": [{"id": 1, "type": "academy", "level": 1, "cell": [0]}],
		"not a new positive whole number": [{"id": 0, "type": "academy", "level": 1, "cell": [0, 0]}],
		"off the field or over another": [{"id": 1, "type": "command_center", "level": 1, "cell": [19, 0]}],
		"is not an object": ["academy"],
	}
	for reason: String in cases:
		var error := BattleLayout.new().build(catalog, cases[reason], catalog.grid_size)
		assert_true(error.contains(reason), "%s: %s" % [reason, error])
	var overlap := [{"id": 1, "type": "command_center", "level": 1, "cell": [0, 0]},
		{"id": 2, "type": "academy", "level": 1, "cell": [1, 1]}]
	assert_true(BattleLayout.new().build(catalog, overlap, catalog.grid_size).contains("building 2 is off the field or over another"))
	var twice := [{"id": 1, "type": "academy", "level": 1, "cell": [0, 0]},
		{"id": 1, "type": "academy", "level": 1, "cell": [5, 5]}]
	assert_true(BattleLayout.new().build(catalog, twice, catalog.grid_size).contains("not a new positive whole number"))


func test_the_field_holds_buildings_walls_and_no_traps() -> void:
	var field := _field([["command_center", 5, 5], ["wall", 15, 15], ["mine", 12, 12]])
	assert_eq(field.kind_at(Vector2i(6, 6)), BattleField.BUILDING)
	assert_eq(field.kind_at(Vector2i(15, 15)), BattleField.WALL)
	assert_eq(field.kind_at(Vector2i(12, 12)), BattleField.FREE, "units walk over traps")
	assert_eq(field.kind_at(Vector2i(-1, 0)), BattleField.BUILDING, "off the field is closed")
	assert_eq(field.building[6 * 20 + 6], 1)
	assert_eq(field.building[15 * 20 + 15], 2)


func test_a_fall_lifts_the_zone_cell_by_cell() -> void:
	# Two walls a cell apart: the cell between is under both grown footprints.
	var catalog := Fixtures.battle_catalog()
	var layout := _layout([["command_center", 0, 0], ["wall", 10, 10], ["wall", 12, 10]])
	var field := BattleField.new(catalog.grid_size)
	field.place_all(layout)
	assert_eq(field.cover[10 * 20 + 11], 2)
	field.remove(layout, 1)
	assert_false(field.is_deploy_cell(Vector2i(11, 10)), "the other wall still covers it")
	assert_true(field.is_deploy_cell(Vector2i(9, 10)))
	assert_eq(field.kind_at(Vector2i(10, 10)), BattleField.FREE)
	field.remove(layout, 2)
	assert_true(field.is_deploy_cell(Vector2i(11, 10)))
	assert_false(field.is_deploy_cell(Vector2i(2, 2)), "the Command Center still stands")


func test_the_deploy_zone_is_every_footprint_grown_by_one() -> void:
	var field := _field([["command_center", 5, 5], ["wall", 15, 15], ["mine", 12, 12]])
	for cell: Vector2i in [Vector2i(4, 4), Vector2i(7, 7), Vector2i(5, 6), Vector2i(14, 14), Vector2i(16, 15)]:
		assert_false(field.is_deploy_cell(cell), "%s is in the zone" % cell)
	for cell: Vector2i in [Vector2i(3, 3), Vector2i(8, 8), Vector2i(8, 5), Vector2i(13, 13), Vector2i(12, 12)]:
		assert_true(field.is_deploy_cell(cell), "%s is outside it" % cell)
	assert_false(field.is_deploy_cell(Vector2i(20, 0)), "off the field")


func test_a_battle_deploys_outside_the_zone() -> void:
	var sim := Fixtures.battle([["command_center", 5, 5], ["wall", 15, 15], ["mine", 12, 12]], {"melee": 1})
	assert_eq(sim.setup_error, "")
	for cell: Vector2i in [Vector2i(4, 4), Vector2i(7, 7), Vector2i(5, 6), Vector2i(14, 14), Vector2i(16, 15)]:
		assert_false(sim.is_deploy_cell(cell), "%s is in the zone" % cell)
	for cell: Vector2i in [Vector2i(3, 3), Vector2i(8, 8), Vector2i(8, 5), Vector2i(13, 13)]:
		assert_true(sim.is_deploy_cell(cell), "%s is outside it" % cell)
	assert_true(sim.is_deploy_cell(Vector2i(12, 12)), "a trap is hidden, so it makes no zone")
	assert_true(sim.is_deploy_cell(Vector2i(11, 11)))


func test_check_deploy_codes() -> void:
	var sim := Fixtures.battle([["command_center", 5, 5]], {"melee": 1, "gunner": 0})
	assert_eq(sim.check_deploy("ghost", Vector2i(0, 0)), BattleSim.ERR_UNKNOWN_UNIT)
	assert_eq(sim.check_deploy("drone", Vector2i(0, 0)), BattleSim.ERR_NONE_LEFT, "not in the army")
	assert_eq(sim.check_deploy("gunner", Vector2i(0, 0)), BattleSim.ERR_NONE_LEFT)
	assert_eq(sim.check_deploy("melee", Vector2i(-1, 0)), BattleSim.ERR_BLOCKED)
	assert_eq(sim.check_deploy("melee", Vector2i(20, 0)), BattleSim.ERR_BLOCKED)
	assert_eq(sim.check_deploy("melee", Vector2i(4, 5)), BattleSim.ERR_BLOCKED)
	assert_eq(sim.check_deploy("melee", Vector2i(0, 0)), "")
	assert_eq(sim.command(Fixtures.deploy(0, "melee", 4, 5)), BattleSim.ERR_BLOCKED, "the command agrees")
	assert_eq(sim.unit_count(), 0, "a refused deploy places nothing")
	assert_eq(sim.command(Fixtures.deploy(0, "melee", 0, 0)), "")
	assert_eq(sim.check_deploy("melee", Vector2i(0, 1)), BattleSim.ERR_NONE_LEFT)
	assert_eq(sim.left_to_deploy("melee"), 0)


func test_a_deployed_unit_stands_at_its_cell_centre() -> void:
	var sim := Fixtures.battle([["command_center", 10, 10]], {"melee": 2, "gunner": 1})
	sim.command(Fixtures.deploy(0, "gunner", 2, 3))
	sim.command(Fixtures.deploy(0, "melee", 0, 0))
	assert_eq(sim.unit_count(), 2)
	assert_eq(sim.unit_type(1), "gunner", "ids in deploy order")
	assert_eq(sim.unit_type(2), "melee")
	assert_eq(sim.unit_position(1), Vector2i(2500, 3500))
	assert_eq(sim.unit_hp(2), 100)
	assert_eq(sim.unit_max_hp(2), 100)


func test_the_zone_opens_as_buildings_fall() -> void:
	# Two walls a cell apart: the cell between is covered by both and opens only when both fall.
	var sim := Fixtures.battle([["command_center", 0, 0], ["wall", 10, 10], ["wall", 12, 10]],
		{"breaker": 2, "melee": 1})
	var between := Vector2i(11, 10)
	assert_eq(sim.check_deploy("melee", between), BattleSim.ERR_BLOCKED)
	sim.command(Fixtures.deploy(0, "breaker", 6, 10))
	_step_until(sim, func() -> bool: return sim.is_destroyed(2) or sim.is_destroyed(3))
	assert_true(sim.is_destroyed(2) != sim.is_destroyed(3), "one wall down")
	assert_eq(sim.check_deploy("melee", between), BattleSim.ERR_BLOCKED, "the other still covers it")
	var open := Vector2i(9, 10) if sim.is_destroyed(2) else Vector2i(13, 10)
	assert_eq(sim.check_deploy("melee", open), "", "the fallen wall's own side opens")
	sim.command({"op": "deploy", "unit": "breaker", "cell": [16, 10]})
	_step_until(sim, func() -> bool: return sim.is_destroyed(2) and sim.is_destroyed(3))
	assert_eq(sim.check_deploy("melee", between), "", "both down: open")


func test_level_zero_buildings_are_left_out() -> void:
	var sim := Fixtures.battle([["command_center", 0, 0], ["academy", 10, 10, 0]], {"melee": 1})
	assert_eq(sim.setup_error, "")
	assert_eq(sim.building_ids(), PackedInt32Array([1]))
	assert_true(sim.is_deploy_cell(Vector2i(10, 10)))


func test_setup_refusals() -> void:
	var catalog := Fixtures.battle_catalog()
	var cases := {
		"unknown type 'tower_of_babel'": Fixtures.battle_setup([["tower_of_babel", 0, 0]], {}),
		"has no level 3": Fixtures.battle_setup([["command_center", 0, 0, 3]], {}),
		"off the field or over another": Fixtures.battle_setup([["command_center", 0, 0], ["academy", 1, 1]], {}),
		"is off the field": Fixtures.battle_setup([["command_center", 19, 0]], {}),
		"unknown unit 'ghost'": Fixtures.battle_setup([["command_center", 0, 0]], {"ghost": 1}),
		"bad count of melee": Fixtures.battle_setup([["command_center", 0, 0]], {"melee": -1}),
		"ticks must be whole and in order": Fixtures.battle_setup([["command_center", 0, 0]], {"melee": 2},
			[Fixtures.deploy(5, "melee", 9, 9), Fixtures.deploy(4, "melee", 9, 9)]),
	}
	for reason: String in cases:
		var sim := BattleSim.create(catalog, cases[reason])
		assert_true(sim.setup_error.contains(reason.replace("is off", "off")), "%s: %s" % [reason, sim.setup_error])
	var twice := Fixtures.battle_setup([["command_center", 0, 0], ["academy", 5, 5]], {})
	twice["defender"]["buildings"][1]["id"] = 1
	assert_true(BattleSim.create(catalog, twice).setup_error.contains("not a new positive whole number"))
	assert_true(BattleSim.create(Fixtures.catalog_with_grid(Vector2i(20, 20)),
		Fixtures.battle_setup([], {})).setup_error == "", "the plain fixture rules have battle rules too")
	var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Fixtures.RULES))
	rules.erase("battle")
	var bare := Catalog.from_json(JSON.stringify(rules), FileAccess.get_file_as_string(Fixtures.BUILDINGS),
		FileAccess.get_file_as_string(Fixtures.UNITS))
	assert_eq(BattleSim.create(bare, Fixtures.battle_setup([], {})).setup_error, "the catalog has no battle rules")
	assert_eq(BattleSim.run(bare, Fixtures.battle_setup([], {})), {})


func _step_until(sim: BattleSim, done: Callable) -> void:
	var guard := 0
	while not done.call() and not sim.is_over() and guard < 5000:
		sim.step()
		guard += 1


func _layout(buildings: Array) -> BattleLayout:
	var catalog := Fixtures.battle_catalog()
	var layout := BattleLayout.new()
	layout.build(catalog, Fixtures.battle_setup(buildings, {})["defender"]["buildings"], catalog.grid_size)
	return layout


func _field(buildings: Array) -> BattleField:
	var field := BattleField.new(Vector2i(20, 20))
	field.place_all(_layout(buildings))
	return field
