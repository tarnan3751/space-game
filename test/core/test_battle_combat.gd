extends TestCase
## Damage in battle: unit attacks, splash and self-destruction; defences and the cloaked sentry.

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


func test_a_cloaked_sentry_reveals_and_fires_at_once() -> void:
	# The hunter walks from the top to the Command Center below, past the sentry.
	var sim := Fixtures.battle([["command_center", 10, 17], ["sentry", 10, 10]], {"hunter": 1},
		[Fixtures.deploy(0, "hunter", 10, 3)])
	sim.step()
	assert_false(sim.is_revealed(2))
	assert_eq(sim.unit_target(1), 1, "unseen, so not a target")
	_step_until(sim, func() -> bool: return sim.is_revealed(2))
	assert_eq(sim.unit_hp(1), 990, "fired on the tick it was revealed")


func _step(sim: BattleSim, ticks: int) -> void:
	for i: int in ticks:
		sim.step()


func _step_until(sim: BattleSim, done: Callable) -> void:
	var guard := 0
	while not done.call() and not sim.is_over() and guard < 5000:
		sim.step()
		guard += 1
