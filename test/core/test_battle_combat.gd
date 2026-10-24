extends TestCase
## Damage in battle: unit attacks, splash and self-destruction; defences, shells, shields, the
## gravity well, the EMP, the cloaked sentry and the traps.

const Fixtures := preload("res://test/support/fixtures.gd")


func test_a_unit_hits_every_fire_ms_from_arrival() -> void:
	# One cell to walk (ticks 0 to 19), the first hit on arrival at tick 19, the next 20 later.
	var sim := Fixtures.battle([["command_center", 0, 18], ["lab", 10, 10]], {"melee": 1})
	sim.command(Fixtures.deploy(0, "melee", 13, 10))
	_step(sim, 19)
	assert_eq(sim.building_hp(2), 200)
	sim.step()
	assert_eq(sim.building_hp(2), 190)
	_step(sim, 19)
	assert_eq(sim.building_hp(2), 190)
	sim.step()
	assert_eq(sim.building_hp(2), 180)


func test_damage_percent_and_level() -> void:
	var sim := Fixtures.battle([["command_center", 0, 18], ["silo", 10, 10]], {"raider": 1})
	sim.command(Fixtures.deploy(0, "raider", 13, 10))
	_step_until(sim, func() -> bool: return sim.unit_state(1) == BattleArmy.ATTACKING)
	sim.step()
	assert_eq(sim.building_hp(2), 280, "x2 against a resource building")
	sim = Fixtures.battle([["command_center", 0, 18], ["lab", 10, 10]], {"melee": 1}, [], {}, {"melee": 2})
	sim.command(Fixtures.deploy(0, "melee", 13, 10))
	_step_until(sim, func() -> bool: return sim.unit_state(1) == BattleArmy.ATTACKING)
	sim.step()
	assert_eq(sim.building_hp(2), 185, "level 2 hits for 15")
	assert_eq(sim.unit_hp(1), 150)


func test_splash_hits_every_building_near_the_target() -> void:
	# The bomber's target is the turret; the wall beside it is within 1000 of its centre, the
	# far academy is not.
	var sim := Fixtures.battle([["command_center", 0, 18], ["turret", 10, 10], ["wall", 11, 10],
		["academy", 13, 10]], {"bomber": 1}, [Fixtures.deploy(0, "bomber", 10, 16)])
	_step_until(sim, func() -> bool: return sim.building_hp(2) < 300)
	assert_eq(sim.building_hp(2), 200)
	assert_eq(sim.building_hp(3), 0, "the wall took the splash")
	assert_true(sim.is_destroyed(3))
	assert_eq(sim.building_hp(4), 100)


func test_a_self_destructing_unit_is_spent_by_its_hit() -> void:
	var sim := Fixtures.battle([["command_center", 0, 18], ["wall", 10, 10]], {"breaker": 1},
		[Fixtures.deploy(0, "breaker", 13, 10)])
	_step_until(sim, func() -> bool: return sim.is_destroyed(2))
	assert_eq(sim.unit_state(1), BattleArmy.DEAD)
	assert_eq(sim.unit_hp(1), 0)
	assert_true(sim.is_over(), "no unit standing and none left")
	assert_eq(sim.result()["deployed"], {"breaker": 1})


func test_a_defence_fires_every_fire_ms() -> void:
	var sim := Fixtures.battle([["command_center", 0, 18], ["turret", 10, 10]], {"hunter": 1},
		[Fixtures.deploy(0, "hunter", 10, 13)])
	_step(sim, 1)
	assert_eq(sim.unit_hp(1), 990)
	_step(sim, 19)
	assert_eq(sim.unit_hp(1), 990)
	_step(sim, 1)
	assert_eq(sim.unit_hp(1), 980)


func test_a_shell_lands_later_where_it_was_aimed() -> void:
	# The mortar fires at tick 0; the shell lands at tick 20 on the cell aimed at. The hunter
	# that stood there is hit, as is the melee walking in; nobody far away is.
	var sim := Fixtures.battle([["command_center", 0, 18], ["mortar", 10, 10]], {"hunter": 1},
		[Fixtures.deploy(0, "hunter", 10, 15)])
	_step(sim, 20)
	assert_eq(sim.unit_hp(1), 1000, "in flight")
	var landed := false
	sim.step()
	for i: int in sim.events.count:
		landed = landed or sim.events.kind[i] == BattleEvents.SHELL_LAND
	assert_true(landed)
	# The hunter walks 25 units a tick: 500 off its cell centre, within the splash.
	assert_eq(sim.unit_hp(1), 980)
	# A fast unit gets out of the way: the drone is air, so use a raider at speed 2000.
	sim = Fixtures.battle([["command_center", 0, 18], ["mortar", 10, 10], ["silo", 2, 15]], {"raider": 1},
		[Fixtures.deploy(0, "raider", 10, 15)])
	_step(sim, 21)
	assert_eq(sim.unit_hp(1), 80, "the raider ran 2000 units: out of the 1000 splash")


func test_a_shield_absorbs_and_recharges() -> void:
	# The shield (pool 100) covers the lab beside it, not itself.
	var sim := Fixtures.battle([["command_center", 0, 18], ["lab", 10, 10], ["shield", 12, 10]],
		{"melee": 1}, [Fixtures.deploy(0, "melee", 9, 13)])
	_step_until(sim, func() -> bool: return sim.shield_hp(3) < 100)
	assert_eq(sim.shield_hp(3), 90)
	assert_eq(sim.building_hp(2), 200)
	_step_until(sim, func() -> bool: return sim.shield_hp(3) == 0)
	sim.step()
	assert_eq(sim.building_hp(2), 200, "the last hit drained the pool")
	_step(sim, 20)
	assert_eq(sim.building_hp(2), 190, "an empty pool lets damage through")
	var sim2 := Fixtures.battle([["command_center", 0, 18], ["shield", 10, 10]], {"melee": 1},
		[Fixtures.deploy(0, "melee", 10, 13)])
	_step_until(sim2, func() -> bool: return sim2.unit_state(1) == BattleArmy.ATTACKING)
	sim2.step()
	assert_eq(sim2.building_hp(2), 290, "a generator does not cover itself")
	assert_eq(sim2.shield_hp(2), 100)


func test_a_shield_recharges_after_its_delay() -> void:
	var sim := Fixtures.battle([["command_center", 0, 18], ["lab", 10, 10], ["shield", 12, 10]], {"melee": 1})
	sim.combat.damage_building(1, 50)
	assert_eq(sim.shield_hp(3), 50)
	_step(sim, 20)
	assert_eq(sim.shield_hp(3), 50, "nothing in the first 1000 ms")
	_step(sim, 10)
	assert_eq(sim.shield_hp(3), 60, "then 20 a second")
	_step(sim, 100)
	assert_eq(sim.shield_hp(3), 100, "up to the pool")


func test_two_shields_drain_the_lower_id_first_and_fall() -> void:
	# Both cover the lab and each other (centres 2.8 cells apart, range 3).
	var sim := Fixtures.battle([["command_center", 0, 18], ["lab", 10, 10], ["shield", 12, 10],
		["shield", 10, 12]], {"melee": 1})
	sim.combat.damage_building(1, 150)
	assert_eq(sim.shield_hp(3), 0, "the lower id drained first")
	assert_eq(sim.shield_hp(4), 50)
	assert_eq(sim.building_hp(2), 200)
	sim.combat.damage_building(2, 80)
	assert_eq(sim.shield_hp(4), 0, "the other covers the first")
	assert_eq(sim.building_hp(3), 270)
	sim.combat.damage_building(3, 300)
	assert_true(sim.is_destroyed(4))
	assert_eq(sim.shield_hp(4), 0, "gone with its generator")
	sim.combat.damage_building(1, 10)
	assert_eq(sim.building_hp(2), 190, "nothing left to shield the lab")


func test_a_gravity_well_holds_air_units() -> void:
	# The well fires at tick 0 and holds the drone for 1000 ms: it does not move.
	var sim := Fixtures.battle([["command_center", 0, 18], ["well", 10, 10]], {"drone": 1},
		[Fixtures.deploy(0, "drone", 10, 13)])
	sim.step()
	var held_at := sim.unit_position(1)
	assert_eq(sim.unit_state(1), BattleArmy.HELD)
	_step(sim, 20)
	assert_eq(sim.unit_position(1), held_at)
	sim.step()
	assert_true(sim.unit_position(1) != held_at, "free again after 20 ticks")


func test_a_held_unit_still_attacks() -> void:
	var sim := Fixtures.battle([["command_center", 0, 18], ["well", 10, 10]], {"drone": 1},
		[Fixtures.deploy(0, "drone", 10, 12)])
	_step(sim, 1)
	assert_eq(sim.building_hp(2), 290, "in reach (2000) at once, and held")
	_step(sim, 20)
	assert_eq(sim.building_hp(2), 280)


func test_an_emp_stuns_ground_units() -> void:
	# The EMP hits the melee for 5 and stuns it for 500 ms; the melee walking at it stops.
	var sim := Fixtures.battle([["command_center", 0, 18], ["emp", 10, 10]], {"melee": 1},
		[Fixtures.deploy(0, "melee", 10, 13)])
	sim.step()
	assert_eq(sim.unit_hp(1), 95)
	assert_eq(sim.unit_state(1), BattleArmy.STUNNED)
	var at := sim.unit_position(1)
	_step(sim, 10)
	assert_eq(sim.unit_position(1), at, "no move while stunned")
	sim.step()
	assert_true(sim.unit_position(1) != at)


func test_stun_and_hold_keep_the_later_end() -> void:
	var sim := Fixtures.battle([["command_center", 0, 18]], {"melee": 1}, [Fixtures.deploy(0, "melee", 10, 10)])
	sim.step()
	sim.army.stun(0, 30)
	sim.army.stun(0, 20)
	assert_eq(sim.army.stun_until[0], 30)


func test_a_cloaked_sentry_reveals_and_fires_at_once() -> void:
	# The hunter walks from the top to the Command Center below, past the sentry.
	var sim := Fixtures.battle([["command_center", 10, 17], ["sentry", 10, 10]], {"hunter": 1},
		[Fixtures.deploy(0, "hunter", 10, 3)])
	sim.step()
	assert_false(sim.is_revealed(2))
	assert_eq(sim.unit_target(1), 1, "unseen, so not a target")
	_step_until(sim, func() -> bool: return sim.is_revealed(2))
	assert_eq(sim.unit_hp(1), 990, "fired on the tick it was revealed")


func test_mines_go_off_once_for_their_class() -> void:
	var sim := Fixtures.battle([["command_center", 0, 18], ["mine", 10, 10], ["air_mine", 10, 12]],
		{"melee": 3, "drone": 1}, [Fixtures.deploy(0, "drone", 10, 12), Fixtures.deploy(0, "melee", 10, 10),
		Fixtures.deploy(0, "melee", 10, 10), Fixtures.deploy(0, "melee", 14, 10)])
	sim.step()
	assert_true(sim.is_destroyed(2), "the ground mine went off")
	assert_eq(sim.unit_hp(2), 50)
	assert_eq(sim.unit_hp(3), 50, "every ground unit in range")
	assert_eq(sim.unit_hp(4), 100, "not one out of range")
	assert_true(sim.is_destroyed(3), "the air mine went off for the drone on it")
	assert_eq(sim.unit_hp(1), 0)
	_step(sim, 40)
	assert_eq(sim.unit_hp(2), 50, "once")
	assert_eq(sim.destruction_pct(), 0, "traps do not count")


func test_a_throw_trap_throws_ground_units_back() -> void:
	# The melee walks east onto the trap and is thrown three cells west.
	var sim := Fixtures.battle([["command_center", 16, 9], ["throw_trap", 8, 10]], {"melee": 1},
		[Fixtures.deploy(0, "melee", 6, 10)])
	_step_until(sim, func() -> bool: return sim.is_destroyed(2))
	assert_true(sim.unit_position(1).x <= 4500, "thrown west: %s" % sim.unit_position(1))
	assert_eq(sim.unit_position(1).y, 10500)
	# Thrown straight: west from a heading east, stopping before a building or the field's edge.
	sim = Fixtures.battle([["command_center", 16, 9], ["academy", 5, 10]], {"melee": 2},
		[Fixtures.deploy(0, "melee", 8, 3), Fixtures.deploy(0, "melee", 1, 3)])
	sim.step()
	sim.army.x[0] = 8500
	sim.army.y[0] = 10500
	sim.army.heading_x[0] = 1000
	sim.army.heading_y[0] = 0
	sim.army.throw_unit(0, 9000, 10500, 3)
	assert_eq(sim.unit_position(1), Vector2i(6500, 10500), "stopped before the academy at 5")
	sim.army.x[1] = 1500
	sim.army.y[1] = 3500
	sim.army.heading_x[1] = 400
	sim.army.heading_y[1] = 300
	sim.army.throw_unit(1, 2000, 3500, 3)
	assert_eq(sim.unit_position(2), Vector2i(500, 2500), "a diagonal throw, stopped by the edge")
	assert_eq(sim.unit_state(2), BattleArmy.IDLE, "and it looks for a target again")
	# The reviewer's case: walls at (11, 10) and (10, 11), a unit at (10, 10) heading up and left is
	# thrown down and right, and stops before the joint between the walls.
	sim = Fixtures.battle([["command_center", 0, 18], ["wall", 11, 10], ["wall", 10, 11]], {"melee": 1},
		[Fixtures.deploy(0, "melee", 16, 16)])
	sim.step()
	sim.army.x[0] = 10500
	sim.army.y[0] = 10500
	sim.army.heading_x[0] = -5
	sim.army.heading_y[0] = -5
	sim.army.throw_unit(0, 10000, 10000, 3)
	assert_eq(sim.unit_position(1), Vector2i(10500, 10500), "no corner cutting through the joint")


func _step(sim: BattleSim, ticks: int) -> void:
	for i: int in ticks:
		sim.step()


func _step_until(sim: BattleSim, done: Callable) -> void:
	var guard := 0
	while not done.call() and not sim.is_over() and guard < 5000:
		sim.step()
		guard += 1
