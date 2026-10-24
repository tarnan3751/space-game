extends TestCase
## The attacker's abilities in the battle sim (docs/reference/battle.md, **Abilities**): the
## command, the swarm, the EMP burst and the strike, at exact numbers, and determinism with them.

const Fixtures := preload("res://test/support/fixtures.gd")


func test_ability_command_refusals() -> void:
	var sim := _battle([["command_center", 10, 10]], {"melee": 1}, {"strike": 1})
	assert_eq(sim.command(_use(0, "orbital_strike", 0, 0)), BattleSim.ERR_UNKNOWN_ABILITY)
	assert_eq(sim.command(_use(0, "swarm", 0, 0)), BattleSim.ERR_NONE_LEFT, "none brought")
	assert_eq(sim.command(_use(0, "strike", 20, 0)), BattleSim.ERR_BLOCKED)
	assert_eq(sim.command(_use(0, "strike", -1, 3)), BattleSim.ERR_BLOCKED)
	assert_eq(sim.command({"op": "ability", "ability": "strike", "cell": "here"}), BattleSim.ERR_BLOCKED)
	assert_eq(sim.command(_use(3, "strike", 10, 10)), BattleSim.ERR_BAD_TICK)
	assert_eq(sim.check_ability("strike", Vector2i(10, 10)), "", "on a building is allowed")
	assert_eq(sim.result()["commands"], [], "refused commands are not logged")
	assert_eq(sim.left_to_use("strike"), 1)
	assert_eq(sim.command(_use(0, "strike", 10, 10)), "")
	assert_eq(sim.result()["commands"], [_use(0, "strike", 10, 10)])
	assert_eq(sim.left_to_use("strike"), 0)
	assert_eq(sim.left_to_use("ghost"), 0)
	assert_eq(sim.command(_use(0, "strike", 10, 10)), BattleSim.ERR_NONE_LEFT)
	sim.command({"op": "surrender", "tick": 0})
	assert_eq(sim.check_ability("strike", Vector2i(0, 0)), BattleSim.ERR_OVER)
	assert_eq(sim.command(_use(0, "strike", 0, 0)), BattleSim.ERR_OVER)


func test_levels_are_clamped_and_unknown_ones_refused() -> void:
	var setup := _setup([["command_center", 10, 10]], {}, {"strike": 1, "swarm": 0})
	setup["attacker"]["ability_levels"] = {"strike": 9}
	var sim := BattleSim.create(Fixtures.battle_catalog(), setup)
	assert_eq(sim.setup_error, "")
	sim.command(_use(0, "strike", 10, 10))
	for i: int in 11:
		sim.step()
	assert_eq(sim.building_hp(1), 1000 - 150, "level 2's damage")


func test_a_strike_lands_after_its_delay_on_what_its_radius_holds() -> void:
	# The strike's point is (10500, 10500), its radius 1000: the footprints at (9, 9), (11, 10)
	# and (10, 11) are within 707, 500 and 500; the turret at (12, 10) is 1500 away; the mine at
	# (10, 9) is 500 away but a trap.
	var buildings := [["turret", 9, 9], ["sentry", 11, 10], ["wall", 10, 11], ["turret", 12, 10],
		["mine", 10, 9], ["command_center", 0, 0]]
	var sim := _battle(buildings, {}, {"strike": 1}, [_use(0, "strike", 10, 10)])
	sim.step()
	assert_eq(_kinds(sim), [BattleEvents.ABILITY])
	assert_eq(sim.events.land_tick[0], 10)
	assert_eq(sim.events.source[0], 3, "the strike is the catalog's third ability")
	assert_eq(Vector2i(sim.events.to_x[0], sim.events.to_y[0]), Vector2i(10500, 10500))
	for i: int in 9:
		sim.step()
	assert_eq(sim.building_hp(1), 300, "nothing before the delay")
	assert_false(sim.is_over(), "a strike on its way keeps the battle going")
	sim.step()
	assert_true(BattleEvents.STRIKE_LAND in _kinds(sim))
	assert_eq(sim.building_hp(1), 200)
	assert_eq(sim.building_hp(2), 200)
	assert_false(sim.is_revealed(2), "a hidden building is hit, not revealed")
	assert_true(sim.is_destroyed(3), "the wall's 100 hull")
	assert_eq(sim.building_hp(4), 300, "outside the radius")
	assert_false(sim.is_destroyed(5), "a trap is not hit")
	assert_eq(sim.building_hp(6), 1000)
	assert_true(sim.is_over(), "nothing left to deploy or use, and no unit standing")


func test_a_strike_goes_through_the_shields_and_its_falls_are_passed_on() -> void:
	var buildings := [["academy", 5, 5], ["turret", 13, 13], ["shield", 15, 15], ["command_center", 0, 18]]
	var sim := _battle(buildings, {"melee": 1}, {"strike": 2},
		[_use(0, "strike", 5, 5), _use(0, "strike", 13, 13)])
	assert_false(sim.is_deploy_cell(Vector2i(5, 4)))
	for i: int in 11:
		sim.step()
	assert_true(sim.is_destroyed(1), "the academy's 100 hull")
	assert_true(sim.is_deploy_cell(Vector2i(5, 4)), "its fall opened the deploy zone")
	assert_eq(sim.destruction_pct(), 25)
	assert_eq(sim.shield_hp(3), 0, "the shield took the strike")
	assert_eq(sim.building_hp(2), 300)


func test_a_strike_hits_the_attacker_s_units_too() -> void:
	# Melee A (level 2, 150 hull) walks from (15, 15) and is still within 1000 of the point when
	# the strike lands at tick 10; the drone (50 hull) deployed at tick 9 dies; melee B is far.
	var commands := [Fixtures.deploy(0, "melee", 15, 15), Fixtures.deploy(0, "melee", 19, 0),
		_use(0, "strike", 15, 15), Fixtures.deploy(9, "drone", 15, 15)]
	var sim := _battle([["academy", 2, 2]], {"melee": 2, "drone": 1}, {"strike": 1}, commands,
		{"melee": 2})
	for i: int in 11:
		sim.step()
	assert_eq(sim.unit_hp(1), 50)
	assert_eq(sim.unit_hp(2), 150, "outside the radius")
	assert_eq(sim.unit_state(3), BattleArmy.DEAD)
	assert_true(BattleEvents.DEATH in _kinds(sim))


func test_a_swarm_heals_over_its_duration_up_to_the_hull() -> void:
	# The strike leaves melee A at 50 at tick 10; a swarm cast on it that tick heals 40 a second,
	# 2 a tick for 20 ticks (10 to 29): 90. A second, at level 2 (80 a second, 4 a tick), stops at
	# the hull, 150. The dead drone is not healed.
	var commands := [Fixtures.deploy(0, "melee", 15, 15), _use(0, "strike", 15, 15),
		Fixtures.deploy(9, "drone", 15, 15)]
	var setup := _setup([["academy", 2, 2]], {"melee": 1, "drone": 1}, {"strike": 1, "swarm": 2}, commands,
		{"melee": 2})
	var sim := BattleSim.create(Fixtures.battle_catalog(), setup)
	for i: int in 10:
		sim.step()
	assert_eq(sim.command(_use(10, "swarm", _cell_of(sim, 1).x, _cell_of(sim, 1).y)), "")
	sim.step()
	assert_eq(sim.unit_hp(1), 52, "struck to 50, then the first heal")
	assert_eq(sim.events.land_tick[0], 30, "the cloud lasts until tick 30")
	for i: int in 19:
		sim.step()
	assert_eq(sim.unit_hp(1), 90)
	for i: int in 10:
		sim.step()
	assert_eq(sim.unit_hp(1), 90, "the swarm is spent")
	assert_eq(sim.unit_hp(2), 0)
	assert_eq(sim.unit_state(2), BattleArmy.DEAD)

	setup["attacker"]["ability_levels"] = {"swarm": 2}
	sim = BattleSim.create(Fixtures.battle_catalog(), setup)
	for i: int in 10:
		sim.step()
	sim.command(_use(10, "swarm", _cell_of(sim, 1).x, _cell_of(sim, 1).y))
	for i: int in 30:
		sim.step()
	assert_eq(sim.unit_hp(1), 130, "50 and 20 ticks of 4")
	sim.command(_use(40, "swarm", _cell_of(sim, 1).x, _cell_of(sim, 1).y))
	for i: int in 30:
		sim.step()
	assert_eq(sim.unit_hp(1), 150, "no more than the hull")
	assert_eq(sim.result()["abilities_used"], {"strike": 1, "swarm": 2})
	assert_eq(JSON.stringify(sim.result()["abilities_used"]), '{"strike":1,"swarm":2}', "sorted")


func test_a_burst_silences_a_defence_for_its_time() -> void:
	# The turret fires on tick 0 (cooldown 1000 ms), counts down to 800 by tick 4, is disabled
	# from tick 5 to 24 with its cooldown held, and fires at tick 40 instead of 20. The turret at
	# (16, 10), 6000 away, keeps firing every 20 ticks.
	var commands := [Fixtures.deploy(0, "melee", 10, 13), Fixtures.deploy(0, "melee", 16, 13)]
	var buildings := [["turret", 10, 10], ["turret", 16, 10], ["command_center", 0, 0]]
	var sim := _battle(buildings, {"melee": 2}, {"burst": 1}, commands)
	var shots := {1: [], 2: []}
	for t: int in 61:
		if t == 5:
			assert_eq(sim.command(_use(5, "burst", 10, 10)), "")
		sim.step()
		for e: int in sim.events.count:
			if sim.events.kind[e] == BattleEvents.SHOT:
				(shots[sim.events.source[e]] as Array).append(t)
			if sim.events.kind[e] == BattleEvents.ABILITY:
				assert_eq(sim.events.land_tick[e], 25, "the defences wake at tick 25")
		if t == 10:
			assert_true(sim.building_disabled(1))
			assert_false(sim.building_disabled(2))
			assert_eq(sim.combat.cooldown[0], 800, "the cooldown is held")
		if t == 24:
			assert_false(sim.building_disabled(1))
	assert_eq(shots[1], [0, 40, 60])
	assert_eq(shots[2], [0, 20, 40, 60])


func test_a_burst_pauses_a_shield_s_recharge() -> void:
	# The pool, drained to 40, recharges 1 a tick once 1000 ms (20 ticks) have passed since it
	# absorbed: from tick 20 without the burst, from tick 40 with it, the delay held while disabled.
	var pools: Array[int] = []
	for burst: bool in [false, true]:
		var commands := [Fixtures.deploy(0, "melee", 0, 19)]
		if burst:
			commands.append(_use(0, "burst", 10, 10))
		var sim := _battle([["shield", 10, 10], ["academy", 11, 10]], {"melee": 1}, {"burst": 1}, commands)
		sim.combat.damage_building(1, 60)
		for i: int in 45:
			sim.step()
		pools.append(sim.shield_hp(1))
	assert_eq(pools, [65, 45])
	# While disabled the pool still absorbs.
	var sim := _battle([["shield", 10, 10], ["academy", 11, 10]], {"melee": 1}, {"burst": 1},
		[Fixtures.deploy(0, "melee", 0, 19), _use(0, "burst", 10, 10)])
	for i: int in 5:
		sim.step()
	sim.combat.damage_building(1, 60)
	assert_eq(sim.shield_hp(1), 40)
	assert_eq(sim.building_hp(2), 100)


func test_a_burst_keeps_a_hidden_sentry_hidden() -> void:
	for burst: bool in [false, true]:
		var commands := [Fixtures.deploy(0, "melee", 10, 12)]
		if burst:
			commands.push_front(_use(0, "burst", 10, 10))
		var sim := _battle([["sentry", 10, 10]], {"melee": 1}, {"burst": 1}, commands)
		var revealed_at := -1
		for t: int in 30:
			sim.step()
			if revealed_at < 0 and sim.is_revealed(1):
				revealed_at = t
		assert_eq(revealed_at, 20 if burst else 0, "burst %s" % burst)


func test_abilities_left_keep_the_battle_going() -> void:
	var sim := _battle([["command_center", 10, 10]], {}, {"strike": 1})
	for i: int in 100:
		sim.step()
	assert_false(sim.is_over(), "no unit, but an ability left")
	sim.command(_use(100, "strike", 10, 10))
	for i: int in 10:
		sim.step()
	assert_false(sim.is_over(), "the strike lands at tick 110")
	sim.step()
	assert_true(sim.is_over())
	assert_eq(sim.tick, 111)
	var empty := _battle([["command_center", 10, 10]], {}, {"strike": 0})
	empty.step()
	assert_true(empty.is_over(), "none brought: over at once")


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
	assert_eq(JSON.stringify(first.result()), JSON.stringify(second.result()))
	assert_eq(first.result()["abilities_used"], {"burst": 1, "strike": 2, "swarm": 1})


func test_stepped_live_and_replayed_battles_agree() -> void:
	var catalog := Fixtures.battle_catalog()
	var setup := _rich_setup()
	var whole := BattleSim.run(catalog, setup)
	var stepped := BattleSim.create(catalog, setup)
	while not stepped.is_over():
		stepped.step()
	assert_eq(JSON.stringify(stepped.result()), JSON.stringify(whole), "stepped")
	# Fed live: the same commands sent through command() at their ticks, none scripted.
	var live_setup := setup.duplicate(true)
	live_setup["commands"] = []
	var live := BattleSim.create(catalog, live_setup)
	var commands: Array = setup["commands"]
	var next := 0
	while not live.is_over():
		while next < commands.size() and int((commands[next] as Dictionary)["tick"]) == live.tick:
			assert_eq(live.command(commands[next]), "")
			next += 1
		live.step()
	assert_eq(JSON.stringify(live.result()), JSON.stringify(whole), "live")
	var replay := setup.duplicate(true)
	replay["commands"] = whole["commands"]
	assert_eq(JSON.stringify(BattleSim.run(catalog, replay)), JSON.stringify(whole), "replayed from its log")


func test_a_json_round_trip_and_key_order_do_not_matter() -> void:
	var catalog := Fixtures.battle_catalog()
	var setup := _rich_setup()
	var whole := BattleSim.run(catalog, setup)
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(setup))
	assert_eq(JSON.stringify(BattleSim.run(catalog, parsed)), JSON.stringify(whole), "a JSON round trip")
	var other := setup.duplicate(true)
	other["attacker"]["abilities"] = {"swarm": 1, "strike": 2, "burst": 1}
	assert_true(JSON.stringify((other["attacker"]["abilities"] as Dictionary).keys())
		!= JSON.stringify((setup["attacker"]["abilities"] as Dictionary).keys()), "a different order")
	assert_eq(JSON.stringify(BattleSim.run(catalog, other)), JSON.stringify(whole), "the abilities' order")


func test_the_hash_covers_the_abilities() -> void:
	var changes := {
		"a swarm's carry": func(sim: BattleSim) -> void: sim.abilities._swarm_carry[0] += 1,
		"a strike's landing": func(sim: BattleSim) -> void: sim.abilities._strike_land[0] += 1,
		"a disabled timer": func(sim: BattleSim) -> void: sim.combat.disabled_until[0] += 1,
		"an ability left": func(sim: BattleSim) -> void: sim.abilities.left[0] += 1,
	}
	for name: String in changes:
		var sim := _battle([["turret", 10, 10], ["command_center", 0, 0]], {"melee": 1},
			{"burst": 1, "strike": 1, "swarm": 1},
			[Fixtures.deploy(0, "melee", 10, 13), _use(0, "burst", 10, 10), _use(0, "strike", 5, 5),
				_use(0, "swarm", 15, 15)])
		for i: int in 5:
			sim.step()
		assert_eq(sim.abilities.swarm_count, 1)
		assert_eq(sim.abilities.strike_count, 1)
		var before := sim.state_hash()
		changes[name].call(sim)
		assert_true(sim.state_hash() != before, name)


func _rich_setup() -> Dictionary:
	var buildings := [["command_center", 9, 9], ["turret", 5, 5], ["tower", 14, 5], ["mortar", 5, 14],
		["shield", 12, 12], ["well", 14, 14], ["emp", 7, 12], ["sentry", 12, 7], ["silo", 2, 9],
		["mine", 9, 3], ["air_mine", 10, 16]]
	for x: int in range(7, 13):
		buildings.append(["wall", x, 7 if x != 12 else 8])
	var army := {"melee": 4, "gunner": 2, "drone": 2, "bomber": 1}
	var commands := [Fixtures.deploy(0, "melee", 0, 0), Fixtures.deploy(0, "melee", 0, 0),
		Fixtures.deploy(3, "gunner", 19, 0), _use(5, "burst", 5, 5), Fixtures.deploy(10, "drone", 19, 10),
		_use(20, "strike", 12, 12), Fixtures.deploy(20, "bomber", 10, 19), _use(40, "swarm", 3, 3),
		Fixtures.deploy(40, "melee", 19, 3), _use(60, "strike", 9, 9), Fixtures.deploy(60, "gunner", 3, 19),
		Fixtures.deploy(80, "drone", 0, 10), Fixtures.deploy(80, "melee", 0, 6)]
	return _setup(buildings, army, {"burst": 1, "strike": 2, "swarm": 1}, commands, {}, {"metal": 800})


## A battle setup on the battle catalog with abilities brought.
static func _setup(buildings: Array, army: Dictionary, abilities: Dictionary, commands: Array = [],
		unit_levels: Dictionary = {}, resources: Dictionary = {}) -> Dictionary:
	var setup := Fixtures.battle_setup(buildings, army, commands, resources, unit_levels)
	setup["attacker"]["abilities"] = abilities
	return setup


static func _battle(buildings: Array, army: Dictionary, abilities: Dictionary, commands: Array = [],
		unit_levels: Dictionary = {}) -> BattleSim:
	return BattleSim.create(Fixtures.battle_catalog(), _setup(buildings, army, abilities, commands, unit_levels))


## An ability command, in the shape the sim logs it.
static func _use(tick: int, ability: String, x: int, y: int) -> Dictionary:
	return {"ability": ability, "cell": [x, y], "op": "ability", "tick": tick}


static func _cell_of(sim: BattleSim, unit: int) -> Vector2i:
	return sim.unit_position(unit) / BattleMath.CELL


static func _kinds(sim: BattleSim) -> Array:
	var kinds := []
	for e: int in sim.events.count:
		kinds.append(sim.events.kind[e])
	return kinds
