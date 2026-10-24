extends TestCase
## The battle as a whole: its end, destruction and stars, and commands.

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


func test_command_refusals() -> void:
	var sim := Fixtures.battle([["command_center", 10, 10]], {"melee": 1})
	assert_eq(sim.command(Fixtures.deploy(3, "melee", 0, 0)), BattleSim.ERR_BAD_TICK)
	assert_eq(sim.command({"op": "dance", "tick": 0}), BattleSim.ERR_UNKNOWN_OP)
	assert_eq(sim.command({"op": "ability", "tick": 0, "ability": "orbital_strike", "cell": [0, 0]}),
		BattleSim.ERR_UNKNOWN_ABILITY)
	assert_eq(sim.command(Fixtures.deploy(0, "ghost", 0, 0)), BattleSim.ERR_UNKNOWN_UNIT)
	assert_eq(sim.command(Fixtures.deploy(0, "melee", 10, 10)), BattleSim.ERR_BLOCKED)
	assert_eq(sim.command({"op": "deploy", "unit": "melee", "cell": "here"}), BattleSim.ERR_BLOCKED)
	assert_eq(sim.result()["commands"], [], "refused commands are not logged")
	assert_eq(sim.command({"op": "deploy", "unit": "melee", "cell": [0, 0]}), "", "no tick: this one")
	assert_eq(sim.result()["commands"], [Fixtures.deploy(0, "melee", 0, 0)])
