extends TestCase
## The battle as a whole: its end, destruction and stars, loot, commands, the result and
## determinism.

const Fixtures := preload("res://test/support/fixtures.gd")


func test_the_timer_ends_it() -> void:
	# A drone does 10 a second to a Command Center of 1000: the 60 s run out first.
	var sim := Fixtures.battle([["command_center", 10, 10]], {"drone": 1}, [Fixtures.deploy(0, "drone", 0, 0)])
	sim.run_to_end()
	assert_eq(sim.tick, 1200)
	assert_eq(sim.ticks_total(), 1200)
	assert_eq(sim.seconds_left(), 0)
	assert_false(sim.is_destroyed(1))


func test_full_destruction_ends_it() -> void:
	var sim := Fixtures.battle([["academy", 10, 10], ["wall", 2, 2]], {"melee": 2},
		[Fixtures.deploy(0, "melee", 13, 10)])
	sim.run_to_end()
	assert_true(sim.is_destroyed(1))
	assert_false(sim.is_destroyed(2), "walls do not count")
	assert_eq(sim.destruction_pct(), 100)
	assert_eq(sim.stars(), 2, "50% and 100%; there is no Command Center")
	assert_true(sim.tick < 1200)


func test_no_army_left_ends_it() -> void:
	var sim := Fixtures.battle([["command_center", 10, 10]], {})
	sim.step()
	assert_true(sim.is_over())
	assert_eq(sim.tick, 1)


func test_a_surrender_ends_it_on_its_tick() -> void:
	var sim := Fixtures.battle([["command_center", 10, 10]], {"melee": 1},
		[Fixtures.deploy(0, "melee", 0, 0), {"op": "surrender", "tick": 5}])
	sim.run_to_end()
	assert_eq(sim.tick, 5)
	var result := sim.result()
	assert_eq(result["ticks"], 5)
	assert_eq(result["commands"], [Fixtures.deploy(0, "melee", 0, 0), {"op": "surrender", "tick": 5}])
	assert_eq(sim.command(Fixtures.deploy(5, "melee", 0, 1)), BattleSim.ERR_OVER)


func test_destruction_and_stars() -> void:
	var sim := Fixtures.battle([["command_center", 0, 0], ["academy", 5, 5], ["academy", 7, 7],
		["academy", 9, 9], ["wall", 15, 15], ["mine", 12, 12]], {"drone": 1}, [Fixtures.deploy(0, "drone", 19, 0)])
	assert_eq(sim.stars(), 0)
	sim.combat.damage_building(0, 5000)
	sim.step()
	assert_eq(sim.destruction_pct(), 25)
	assert_eq(sim.stars(), 1, "the Command Center")
	sim.combat.damage_building(1, 5000)
	sim.combat.damage_building(4, 5000)
	sim.step()
	assert_eq(sim.destruction_pct(), 50, "the wall does not count")
	assert_eq(sim.stars(), 2)
	sim.combat.damage_building(2, 5000)
	sim.combat.damage_building(3, 5000)
	sim.step()
	assert_eq(sim.destruction_pct(), 100)
	assert_eq(sim.stars(), 3)
	assert_true(sim.is_over())


func test_loot_is_spread_by_storage_and_taken_as_buildings_fall() -> void:
	# 50% of 1001 metal is 500, over the Command Center (1000 storage), the silo (1000) and the
	# extractor (an hour of 3600): 89, 89 and 321, the leftover 1 to the lowest id. 50% of the
	# 500 crystal is 250, all on the Command Center (the only crystal holder).
	var sim := Fixtures.battle([["command_center", 0, 0], ["silo", 5, 5], ["extractor", 10, 10], ["academy", 15, 15]],
		{"drone": 1}, [Fixtures.deploy(0, "drone", 19, 0)], {"metal": 1001, "crystal": 500, "antimatter": 7})
	assert_eq(sim.loot(), {"metal": 0, "crystal": 0, "antimatter": 0} as Dictionary[String, int])
	sim.combat.damage_building(2, 5000)
	sim.step()
	assert_eq(sim.loot()["metal"], 321)
	sim.combat.damage_building(3, 5000)
	sim.step()
	assert_eq(sim.loot()["metal"], 321, "the academy holds nothing")
	sim.combat.damage_building(0, 5000)
	sim.step()
	assert_eq(sim.loot(), {"metal": 411, "crystal": 250, "antimatter": 0} as Dictionary[String, int],
		"no antimatter holder: none to take")
	sim.combat.damage_building(1, 5000)
	sim.step()
	assert_eq(sim.loot()["metal"], 500)
	assert_eq(sim.result()["loot"], {"antimatter": 0, "crystal": 250, "metal": 500})


func test_command_refusals() -> void:
	var sim := Fixtures.battle([["command_center", 10, 10]], {"melee": 1})
	assert_eq(sim.command(Fixtures.deploy(3, "melee", 0, 0)), BattleSim.ERR_BAD_TICK)
	assert_eq(sim.command({"op": "dance", "tick": 0}), BattleSim.ERR_UNKNOWN_OP)
	assert_eq(sim.command({"op": "ability", "tick": 0, "ability": "ghost", "cell": [0, 0]}),
		BattleSim.ERR_UNKNOWN_ABILITY)
	assert_eq(sim.command(Fixtures.deploy(0, "ghost", 0, 0)), BattleSim.ERR_UNKNOWN_UNIT)
	assert_eq(sim.command(Fixtures.deploy(0, "melee", 10, 10)), BattleSim.ERR_BLOCKED)
	assert_eq(sim.command({"op": "deploy", "unit": "melee", "cell": "here"}), BattleSim.ERR_BLOCKED)
	assert_eq(sim.result()["commands"], [], "refused commands are not logged")
	assert_eq(sim.command({"op": "deploy", "unit": "melee", "cell": [0, 0]}), "", "no tick: this one")
	assert_eq(sim.result()["commands"], [Fixtures.deploy(0, "melee", 0, 0)])


func test_an_ability_left_keeps_a_battle_without_units_going() -> void:
	# No unit standing and none to deploy, but a burst left: the battle runs until it is used.
	var setup := Fixtures.battle_setup([["command_center", 10, 10]], {})
	setup["attacker"]["abilities"] = {"burst": 1}
	var sim := BattleSim.create(Fixtures.battle_catalog(), setup)
	for i: int in 50:
		sim.step()
	assert_false(sim.is_over())
	assert_eq(sim.left_to_use("burst"), 1)
	assert_eq(sim.command({"op": "ability", "tick": 50, "ability": "burst", "cell": [10, 10]}), "")
	sim.step()
	assert_true(sim.is_over(), "nothing left to deploy or use")
	assert_eq(sim.tick, 51)
	assert_eq(sim.result()["abilities_used"], {"burst": 1})


func test_the_result_shape() -> void:
	var result := BattleSim.run(Fixtures.battle_catalog(), Fixtures.battle_setup([["academy", 10, 10]],
		{"melee": 2, "drone": 1}, [Fixtures.deploy(0, "melee", 13, 10)]))
	assert_eq(result.keys(), ["abilities_used", "commands", "deployed", "destruction", "hash", "loot", "stars", "ticks"])
	assert_eq(result["deployed"], {"melee": 1})
	assert_eq(result["abilities_used"], {})


func test_the_same_setup_gives_the_same_battle() -> void:
	var setup := _rich_setup()
	var first := BattleSim.create(Fixtures.battle_catalog(), setup)
	var second := BattleSim.create(Fixtures.battle_catalog(), setup.duplicate(true))
	assert_eq(first.setup_error, "")
	var differ := 0
	while not first.is_over():
		first.step()
		second.step()
		if first.state_hash() != second.state_hash():
			differ += 1
	assert_eq(differ, 0, "the same hash at every tick")
	assert_true(second.is_over())
	assert_eq(JSON.stringify(first.result()), JSON.stringify(second.result()))
	assert_true(first.unit_count() == 12 and first.destruction_pct() > 0, "the battle did something")


func test_a_replay_after_a_json_round_trip_is_the_same() -> void:
	# The server gets the setup as JSON text, whose parse sorts the keys.
	var catalog := Fixtures.battle_catalog()
	var setup := _rich_setup()
	var whole := BattleSim.run(catalog, setup)
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(setup))
	assert_eq(JSON.stringify(BattleSim.run(catalog, parsed)), JSON.stringify(whole))


func test_the_army_s_key_order_does_not_matter() -> void:
	var catalog := Fixtures.battle_catalog()
	var setup := _rich_setup()
	var whole := BattleSim.run(catalog, setup)
	var army: Dictionary = setup["attacker"]["army"]
	var reversed := {}
	var keys := army.keys()
	keys.reverse()
	for unit: Variant in keys:
		reversed[unit] = army[unit]
	var other := setup.duplicate(true)
	other["attacker"]["army"] = reversed
	assert_true(JSON.stringify(reversed.keys()) != JSON.stringify(army.keys()), "a different order")
	assert_eq(JSON.stringify(BattleSim.run(catalog, other)), JSON.stringify(whole), "the same result and hash")


func test_the_hash_covers_the_state_that_does_not_show() -> void:
	# A change to any of these, invisible in positions and hulls, changes the hash.
	var changes := {
		"movement carry": func(sim: BattleSim) -> void: sim.army._carry[0] += 1,
		"path position": func(sim: BattleSim) -> void: sim.army._path_pos[0] += 1,
		"a path cell": func(sim: BattleSim) -> void: sim.army._paths[0][1] += 1,
		"wanting a target": func(sim: BattleSim) -> void: sim.army._wants[0] = 1,
		"left to deploy": func(sim: BattleSim) -> void: sim.army.left[0] += 1,
		"a shield's quiet time": func(sim: BattleSim) -> void: sim.combat._quiet[4] += 50,
		"a shell's landing": func(sim: BattleSim) -> void: sim.combat._shell_land[0] += 1,
	}
	for name: String in changes:
		var sim := BattleSim.create(Fixtures.battle_catalog(), _rich_setup())
		for i: int in 30:
			sim.step()
		assert_true(sim.combat.shell_count > 0, "a shell is in flight")
		var before := sim.state_hash()
		changes[name].call(sim)
		assert_true(sim.state_hash() != before, name)


func test_stepped_live_and_replayed_battles_agree() -> void:
	var setup := _rich_setup()
	var catalog := Fixtures.battle_catalog()
	var whole := BattleSim.run(catalog, setup)
	# Fed live through command(), tick by tick, as the view will.
	var live_setup := setup.duplicate(true)
	var commands: Array = live_setup["commands"]
	live_setup["commands"] = []
	var live := BattleSim.create(catalog, live_setup)
	var next := 0
	while not live.is_over():
		while next < commands.size() and int(commands[next]["tick"]) == live.tick:
			assert_eq(live.command(commands[next]), "")
			next += 1
		live.step()
	assert_eq(JSON.stringify(live.result()), JSON.stringify(whole))
	# Replayed from the logged commands.
	var replay_setup := setup.duplicate(true)
	replay_setup["commands"] = whole["commands"]
	assert_eq(JSON.stringify(BattleSim.run(catalog, replay_setup)), JSON.stringify(whole))
	# The seed is unused by today's rules.
	var other_seed := setup.duplicate(true)
	other_seed["seed"] = 99
	assert_eq(JSON.stringify(BattleSim.run(catalog, other_seed)), JSON.stringify(whole))


func test_a_big_battle_runs_to_its_end() -> void:
	var setup := _big_setup()
	assert_eq((setup["defender"]["buildings"] as Array).size(), 151)
	var result := BattleSim.run(Fixtures.battle_catalog(Vector2i(48, 48)), setup)
	assert_false(result.is_empty())
	var deployed := 0
	for unit: String in result["deployed"]:
		deployed += int(result["deployed"][unit])
	assert_eq(deployed, 280)
	assert_true(int(result["destruction"]) > 0)


func test_the_hash_at_every_tick_is_pinned() -> void:
	# Pinned values: a change to the pathing's speed must not move them; only a change to what a
	# battle does may, under a brief that says so. Building the reach maps at setup left them as
	# they were: no map of these battles was first built in the window that miscounted one
	# (test_battle_pathing's test_a_map_is_right_when_a_building_falls_in_the_tick_it_would_be_built).
	var sim := BattleSim.create(Fixtures.battle_catalog(), _rich_setup())
	var chain := 2166136261
	while not sim.is_over():
		sim.step()
		chain = BattleMath.mix(chain, sim.state_hash())
	assert_eq([sim.tick, sim.state_hash(), chain], [1200, 2555368207, 1486836163], "the rich battle")
	var big := BattleSim.run(Fixtures.battle_catalog(Vector2i(48, 48)), _big_setup())
	assert_eq([big["ticks"], big["hash"]], [1154, 296948820], "the big battle")


## A battle with every kind of unit and defence on the 20x20 fixture field.
func _rich_setup() -> Dictionary:
	var buildings := [["command_center", 9, 9], ["turret", 5, 5], ["tower", 14, 5], ["mortar", 5, 14],
		["shield", 12, 12], ["well", 14, 14], ["emp", 7, 12], ["sentry", 12, 7], ["silo", 2, 9],
		["extractor", 16, 9], ["mine", 9, 3], ["air_mine", 10, 16], ["throw_trap", 3, 12]]
	for x: int in range(7, 13):
		buildings.append(["wall", x, 7 if x != 12 else 8])
	var army := {"melee": 3, "gunner": 2, "breaker": 2, "raider": 1, "hunter": 1, "drone": 2, "bomber": 1}
	var commands := [Fixtures.deploy(0, "melee", 0, 0), Fixtures.deploy(0, "melee", 0, 0),
		Fixtures.deploy(0, "breaker", 9, 0), Fixtures.deploy(3, "gunner", 19, 0), Fixtures.deploy(3, "raider", 0, 19),
		Fixtures.deploy(10, "hunter", 19, 19), Fixtures.deploy(10, "drone", 19, 10), Fixtures.deploy(20, "drone", 0, 10),
		Fixtures.deploy(20, "bomber", 10, 19), Fixtures.deploy(40, "melee", 19, 3), Fixtures.deploy(60, "gunner", 3, 19),
		Fixtures.deploy(80, "breaker", 0, 6)]
	return Fixtures.battle_setup(buildings, army, commands, {"metal": 800, "crystal": 600, "antimatter": 0})


## The big battle's setup: 151 buildings and 280 units on a 48x48 field.
func _big_setup() -> Dictionary:
	var buildings := [["command_center", 22, 22]]
	var types := ["turret", "tower", "mortar", "academy", "shield", "emp", "well", "sentry", "mine", "air_mine"]
	var i := 0
	for y: int in range(2, 46, 3):
		for x: int in range(2, 46, 3):
			if buildings.size() >= 121 or (x >= 20 and x <= 26 and y >= 20 and y <= 26):
				continue
			buildings.append([types[i % types.size()], x, y])
			i += 1
	for x: int in range(10, 40):
		buildings.append(["wall", x, 1])
	var army := {"melee": 100, "gunner": 80, "drone": 60, "bomber": 20, "breaker": 20}
	var commands := []
	var n := 0
	for unit: String in army:
		for k: int in army[unit]:
			commands.append(Fixtures.deploy(n / 10, unit, (n * 7) % 48, 47))
			n += 1
	return Fixtures.battle_setup(buildings, army, commands)
