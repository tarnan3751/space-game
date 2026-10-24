extends TestCase
## The outpost generator (docs/reference/expeditions.md) on the expedition fixture catalog, and,
## as a data check, on the shipped data.

const Fixtures := preload("res://test/support/fixtures.gd")

var catalog: Catalog


func before_each() -> void:
	catalog = Fixtures.expedition_catalog()


func test_the_same_inputs_give_the_same_field() -> void:
	var first := JSON.stringify(_field(4, 5))
	assert_eq(JSON.stringify(_field(4, 5)), first)
	assert_true(JSON.stringify(_field(5, 5)) != first, "another index differs")
	var capacity := _capacity(5)
	assert_true(JSON.stringify(OutpostGenerator.generate_field(catalog, 7, 1, 4, 5, capacity)) != first,
		"another epoch differs")
	assert_true(JSON.stringify(OutpostGenerator.generate_field(catalog, 8, 0, 4, 5, capacity)) != first,
		"another sector seed differs")


func test_the_field_seed_is_the_sectors() -> void:
	var field := _field(2, 3)
	assert_eq(field["seed"], Sector.field_seed_of(7, 0, 2))
	assert_eq(field["index"], 2)
	assert_eq(field["band"], "even")


func test_an_index_that_is_not_a_field_gives_nothing() -> void:
	assert_eq(_field(6, 3), {})
	assert_eq(_field(-1, 3), {})
	var sector := Sector.new()
	assert_eq(OutpostGenerator.summary(catalog, sector, 6), {})


func test_every_band_at_every_level_is_a_valid_outpost() -> void:
	for cc: int in range(1, 11):
		for index: int in catalog.expedition_field_count():
			var field := _field(index, cc)
			_check_valid(catalog, field, "cc %d field %d" % [cc, index])
			assert_eq(field["dropped"], 0, "cc %d field %d drops nothing" % [cc, index])
			_check_counts_and_levels(field, cc, "cc %d field %d" % [cc, index])


func test_the_outpost_level_follows_the_band_and_is_clamped() -> void:
	var expected := {1: [1, 1, 2], 5: [4, 5, 6], 10: [9, 10, 10]}
	for cc: int in expected:
		var levels: Array = expected[cc]
		for band: int in 3:
			assert_eq(_field(band * 2, cc)["cc"], levels[band], "player cc %d, band %d" % [cc, band])


func test_walls_ring_the_compound_closed_or_gapped_by_band() -> void:
	for cc: int in range(2, 11):
		for index: int in catalog.expedition_field_count():
			var field := _field(index, cc)
			var band := catalog.expedition_band(index)
			var rings: Array = field["rings"]
			assert_true(not rings.is_empty(), "cc %d field %d has a ring" % [cc, index])
			var walls := _wall_cells(catalog, field)
			for ring: Dictionary in rings:
				var runs := _open_runs(ring, walls)
				var label := "cc %d field %d ring %s" % [cc, index, ring["rect"]]
				assert_eq(runs, int(band["wall_gaps"]), label)
				for gap: Variant in ring["gaps"]:
					assert_false(walls.has(Vector2i(int(gap[0]), int(gap[1]))), "%s: gap %s is open" % [label, gap])


func test_a_ring_short_of_walls_is_left_open_rather_than_overlapping() -> void:
	# Easy at Command Center 1: 18 walls, and the ring round a 3x3 Command Center needs 20.
	var field := _field(0, 1)
	_check_valid(catalog, field, "easy at cc 1")
	var rings: Array = field["rings"]
	assert_eq(rings.size(), 1)
	assert_true(_open_runs(rings[0], _wall_cells(catalog, field)) >= 2, "still open at its gaps")


func test_deposits_and_hazards_stand_outside_the_walls() -> void:
	for cc: int in [3, 6, 10]:
		for index: int in catalog.expedition_field_count():
			var field := _field(index, cc)
			var band := catalog.expedition_band(index)
			var deposits: Array = field["deposits"]
			var hazards: Array = field["hazards"]
			assert_eq(deposits.size(), int(band["deposits"]), "cc %d field %d deposits" % [cc, index])
			assert_eq(hazards.size(), int(band["deposits"]) * int(band["hazards"]),
				"cc %d field %d hazards" % [cc, index])
			var rings: Array = field["rings"]
			var last: Array = (rings[rings.size() - 1] as Dictionary)["rect"]
			var walled := Rect2i(int(last[0]), int(last[1]), int(last[2]), int(last[3]))
			for building: Dictionary in _buildings(field):
				var id: int = building["id"]
				if not deposits.has(id) and not hazards.has(id):
					continue
				var type: String = building["type"]
				var label := "cc %d field %d %s %d" % [cc, index, type, id]
				var storage: Dictionary = catalog.level_stats(type, int(building["level"])).get("storage", {})
				if deposits.has(id):
					assert_true(not storage.is_empty(), "%s is a storage" % label)
				else:
					assert_eq(catalog.battle_class(type), Catalog.CLASS_DEFENSE, "%s is a defence" % label)
				assert_false(walled.intersects(_footprint(catalog, building)), "%s is outside the walls" % label)


func test_traps_hide_inside_the_rings_and_on_the_gaps() -> void:
	var field := _field(2, 6)
	var rings: Array = field["rings"]
	var last: Array = (rings[rings.size() - 1] as Dictionary)["rect"]
	var walled := Rect2i(int(last[0]), int(last[1]), int(last[2]), int(last[3]))
	var traps := 0
	var on_gaps := 0
	var gaps: Array = (rings[0] as Dictionary)["gaps"]
	for building: Dictionary in _buildings(field):
		if catalog.battle_class(str(building["type"])) != Catalog.CLASS_TRAP:
			continue
		traps += 1
		assert_true(walled.encloses(_footprint(catalog, building)), "trap %d inside the rings" % building["id"])
		if gaps.has(building["cell"]):
			on_gaps += 1
	assert_true(traps > 0, "the field has traps")
	assert_eq(on_gaps, gaps.size(), "a trap on each gap")


func test_the_loot_is_what_a_full_raid_takes() -> void:
	for cc: int in [1, 4, 10]:
		var capacity := _capacity(cc)
		for index: int in catalog.expedition_field_count():
			var field := _field(index, cc)
			var band := catalog.expedition_band(index)
			var defender: Dictionary = field["defender"]
			var stored: Dictionary = defender["resources"]
			var loot: Dictionary = field["loot"]
			for res: String in catalog.resources:
				var label := "cc %d field %d %s" % [cc, index, res]
				assert_eq(int(stored[res]) * catalog.loot_pct(res) / 100, loot[res], label)
				if _holds(field, res):
					assert_eq(loot[res], capacity[res] * int(band["loot_pct"]) / 100, label)
				else:
					assert_eq(loot[res], 0, label + " (nothing holds it)")


func test_no_capacity_or_no_holder_gives_no_loot() -> void:
	# A player with no antimatter storage; and an outpost at Command Center 1, which holds none.
	var capacity: Dictionary[String, int] = {"metal": 4000, "crystal": 4000, "antimatter": 0}
	var field := OutpostGenerator.generate_field(catalog, 7, 0, 4, 9, capacity)
	assert_true(_holds(field, "antimatter"), "a Command Center 10 outpost holds antimatter")
	assert_eq(field["loot"]["antimatter"], 0)
	assert_eq(field["defender"]["resources"]["antimatter"], 0)
	capacity["antimatter"] = 1000
	field = OutpostGenerator.generate_field(catalog, 7, 0, 0, 1, capacity)
	assert_false(_holds(field, "antimatter"))
	assert_eq(field["loot"], {"metal": 600, "crystal": 600, "antimatter": 0})
	assert_eq(field["defender"]["resources"]["antimatter"], 0)


func test_the_summary_agrees_with_the_field() -> void:
	var sector := Sector.new()
	sector.sector_seed = 7
	sector.snapshot(6, _capacity(6))
	for index: int in catalog.expedition_field_count():
		var field := _field(index, 6)
		var summary := OutpostGenerator.summary(catalog, sector, index)
		assert_eq(summary["band"], field["band"], "field %d" % index)
		assert_eq(summary["cc"], field["cc"], "field %d" % index)
		assert_eq(summary["loot"], field["loot"], "field %d" % index)
		assert_eq(summary["seed"], field["seed"], "field %d" % index)


func test_walls_and_traps_hold_no_loot_in_the_summary_or_the_field() -> void:
	# The fixture's walls store antimatter; at these levels at most the Command Center else does.
	var sector := Sector.new()
	sector.sector_seed = 7
	var capacity: Dictionary[String, int] = {"metal": 4000, "crystal": 4000, "antimatter": 500}
	for cc: int in [1, 2]:
		sector.snapshot(cc, capacity)
		for index: int in catalog.expedition_field_count():
			var field := OutpostGenerator.generate_field(catalog, 7, 0, index, cc, capacity)
			var summary := OutpostGenerator.summary(catalog, sector, index)
			assert_eq(summary["loot"], field["loot"], "cc %d field %d" % [cc, index])
			if not _holds(field, "antimatter"):
				assert_eq(field["loot"]["antimatter"], 0, "cc %d field %d: the walls hold none" % [cc, index])


func test_a_field_sets_up_a_battle() -> void:
	var field := _field(4, 7)
	var setup := OutpostGenerator.battle_setup(field, {"melee": 3}, {"melee": 2})
	assert_eq(setup["seed"], field["seed"])
	assert_eq(setup["commands"], [])
	var sim := BattleSim.create(catalog, setup)
	assert_eq(sim.setup_error, "")
	assert_true(sim.is_deploy_cell(Vector2i(0, 0)), "the corner is in the deploy zone")
	assert_true(sim.is_deploy_cell(Vector2i(20, 1)), "so is the top edge's middle")


func test_a_battle_setup_carries_the_abilities_brought() -> void:
	var field := _field(4, 7)
	var none := OutpostGenerator.battle_setup(field, {"melee": 3}, {"melee": 2})
	assert_eq(none["attacker"]["abilities"], {}, "none brought by default")
	assert_eq(none["attacker"]["ability_levels"], {})
	var stock := {"strike": 2, "swarm": 1}
	var levels := {"strike": 2}
	var setup := OutpostGenerator.battle_setup(field, {"melee": 3}, {"melee": 2}, stock, levels)
	assert_eq(setup["attacker"]["abilities"], {"strike": 2, "swarm": 1})
	assert_eq(setup["attacker"]["ability_levels"], {"strike": 2})
	stock["strike"] = 0
	levels["strike"] = 1
	assert_eq(setup["attacker"]["abilities"]["strike"], 2, "a copy: the caller's stock can change after")
	assert_eq(setup["attacker"]["ability_levels"]["strike"], 2)
	var sim := BattleSim.create(Fixtures.battle_catalog(), OutpostGenerator.battle_setup(
		{"seed": 3, "defender": Fixtures.battle_setup([["command_center", 10, 10]], {})["defender"]},
		{"melee": 1}, {}, {"strike": 1}, {"strike": 2}))
	assert_eq(sim.setup_error, "", "the sim takes the abilities brought")
	assert_eq(sim.left_to_use("strike"), 1)


func test_a_crowded_field_still_ends_and_stays_valid() -> void:
	# The fixture roster at Command Center 10 on a 20x20 field: not everything fits.
	var small := Fixtures.expedition_catalog(func(rules: Dictionary) -> void:
		rules["grid"] = {"width": 20, "height": 20}
		rules["expedition"]["margin"] = 2
		rules["start"]["buildings"] = [])
	assert_eq(small.load_error, "")
	var field := OutpostGenerator.generate_field(small, 7, 0, 5, 10, _capacity(10))
	_check_valid(small, field, "crowded")
	var band := small.expedition_band(5)
	var planned := 0
	var counts := OutpostGenerator.plan(small, band, 10)
	for type: String in counts:
		planned += counts[type]
	var placed := _buildings(field).size()
	assert_true(field["dropped"] > 0, "some buildings are dropped")
	assert_true(placed + int(field["dropped"]) <= planned, "placed and dropped are the plan at most")


func test_shipped_data_lays_out_every_field() -> void:
	# The data check: every band at every Command Center level fits the shipped field with nothing
	# dropped, hard closed.
	var shipped := Catalog.load_default()
	assert_eq(shipped.load_error, "")
	var capacity: Dictionary[String, int] = {"metal": 100000, "crystal": 100000, "antimatter": 1000}
	for cc: int in range(1, shipped.max_cc_level() + 1):
		for index: int in shipped.expedition_field_count():
			var field := OutpostGenerator.generate_field(shipped, 11, 0, index, cc, capacity)
			var label := "shipped cc %d field %d" % [cc, index]
			_check_valid(shipped, field, label)
			assert_eq(field["dropped"], 0, label + " drops nothing")
			if str(field["band"]) == "hard":
				var walls := _wall_cells(shipped, field)
				for ring: Dictionary in field["rings"]:
					assert_eq(_open_runs(ring, walls), 0, label + " closed")


# --- Helpers -------------------------------------------------------------------

func _field(index: int, cc: int) -> Dictionary:
	return OutpostGenerator.generate_field(catalog, 7, 0, index, cc, _capacity(cc))


## A capacity that grows with the level and stores antimatter from level 4.
func _capacity(cc: int) -> Dictionary[String, int]:
	return {"metal": 2000 * cc, "crystal": 2000 * cc, "antimatter": 100 * cc if cc >= 4 else 0}


func _buildings(field: Dictionary) -> Array:
	var defender: Dictionary = field["defender"]
	return defender["buildings"]


func _footprint(on: Catalog, building: Dictionary) -> Rect2i:
	var cell: Array = building["cell"]
	var size := on.size_of(str(building["type"]))
	return Rect2i(int(cell[0]), int(cell[1]), size, size)


## No overlap, every footprint inside the margin, ids 1..n in order, and a battle sets up.
func _check_valid(on: Catalog, field: Dictionary, label: String) -> void:
	var margin: int = on.expedition["margin"]
	var box := Rect2i(margin, margin, on.grid_size.x - 2 * margin, on.grid_size.y - 2 * margin)
	var grid := BaseGrid.new(on.grid_size.x, on.grid_size.y)
	var expected_id := 1
	for building: Dictionary in _buildings(field):
		var footprint := _footprint(on, building)
		var id: int = building["id"]
		assert_eq(id, expected_id, label + ": ids in order")
		expected_id += 1
		assert_true(box.encloses(footprint), "%s: %s %d inside the margin" % [label, building["type"], id])
		assert_true(grid.is_free(footprint.position, footprint.size.x), "%s: %s %d overlaps nothing" % [
			label, building["type"], id])
		grid.occupy(id, footprint.position, footprint.size.x)
	var sim := BattleSim.create(on, OutpostGenerator.battle_setup(field, {}, {}))
	assert_eq(sim.setup_error, "", label + ": a battle sets up")


## Counts within max_count at the outpost's level, and every level the band's.
func _check_counts_and_levels(field: Dictionary, player_cc: int, label: String) -> void:
	var band := catalog.expedition_band(int(field["index"]))
	var cc := clampi(player_cc + int(band["cc_offset"]), 1, 10)
	assert_eq(field["cc"], cc, label)
	var counts := {}
	for building: Dictionary in _buildings(field):
		var type: String = building["type"]
		counts[type] = int(counts.get(type, 0)) + 1
		var top := 0
		for level: int in range(1, catalog.max_level(type) + 1):
			if int(catalog.level_stats(type, level).get("requires_cc", 1)) <= cc:
				top = level
		assert_eq(building["level"], maxi(1, top + int(band["level_offset"])), "%s: %s level" % [label, type])
	for type: String in counts:
		assert_true(int(counts[type]) <= catalog.max_count(type, cc), "%s: %s count" % [label, type])
	assert_eq(counts.get(Catalog.HQ_TYPE, 0), 1, label + ": one Command Center")


func _wall_cells(on: Catalog, field: Dictionary) -> Dictionary:
	var walls := {}
	for building: Dictionary in _buildings(field):
		if on.battle_class(str(building["type"])) == Catalog.CLASS_WALL:
			var cell: Array = building["cell"]
			walls[Vector2i(int(cell[0]), int(cell[1]))] = true
	return walls


## The runs of non-wall cells round a ring's border.
func _open_runs(ring: Dictionary, walls: Dictionary) -> int:
	var rect: Array = ring["rect"]
	var x0: int = rect[0]
	var y0: int = rect[1]
	var x1: int = x0 + int(rect[2]) - 1
	var y1: int = y0 + int(rect[3]) - 1
	var border: Array[Vector2i] = []
	for x: int in range(x0, x1):
		border.append(Vector2i(x, y0))
	for y: int in range(y0, y1):
		border.append(Vector2i(x1, y))
	for x: int in range(x1, x0, -1):
		border.append(Vector2i(x, y1))
	for y: int in range(y1, y0, -1):
		border.append(Vector2i(x0, y))
	var runs := 0
	for i: int in border.size():
		var open := not walls.has(border[i])
		var before_open := not walls.has(border[i - 1])
		if open and not before_open:
			runs += 1
	if runs == 0 and not walls.has(border[0]):
		runs = 1
	return runs


## Whether a building of the field, not a wall or a trap, stores or produces `res`.
func _holds(field: Dictionary, res: String) -> bool:
	for building: Dictionary in _buildings(field):
		var battle_class := catalog.battle_class(str(building["type"]))
		if battle_class == Catalog.CLASS_WALL or battle_class == Catalog.CLASS_TRAP:
			continue
		var stats := catalog.level_stats(str(building["type"]), int(building["level"]))
		for key: String in ["storage", "produces"]:
			var amounts: Dictionary = stats.get(key, {})
			if int(amounts.get(res, 0)) > 0:
				return true
	return false
