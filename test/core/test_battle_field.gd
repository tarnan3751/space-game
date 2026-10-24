extends TestCase
## The battle's layout and its deploy zone: what a layout accepts, what stands on each cell and
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


func _layout(buildings: Array) -> BattleLayout:
	var catalog := Fixtures.battle_catalog()
	var layout := BattleLayout.new()
	layout.build(catalog, Fixtures.battle_setup(buildings, {})["defender"]["buildings"], catalog.grid_size)
	return layout


func _field(buildings: Array) -> BattleField:
	var field := BattleField.new(Vector2i(20, 20))
	field.place_all(_layout(buildings))
	return field
