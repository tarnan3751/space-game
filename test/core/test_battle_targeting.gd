extends TestCase
## Target selection: units by preference, path or straight distance and id; defences by class,
## range, distance and id, keeping their target.

const Fixtures := preload("res://test/support/fixtures.gd")


func test_ground_by_path_air_by_straight_line() -> void:
	# Turret 2 is the nearer in a straight line but walled in; turret 3 is open. The hunter walks
	# to the open one; the bomber flies to the nearer.
	var buildings := [["command_center", 0, 18], ["turret", 6, 10], ["turret", 6, 17]]
	for cell: Vector2i in [Vector2i(5, 9), Vector2i(6, 9), Vector2i(7, 9), Vector2i(5, 10), Vector2i(7, 10),
			Vector2i(5, 11), Vector2i(6, 11), Vector2i(7, 11)]:
		buildings.append(["wall", cell.x, cell.y])
	var sim := Fixtures.battle(buildings, {"hunter": 1, "bomber": 1},
		[Fixtures.deploy(0, "hunter", 13, 11), Fixtures.deploy(0, "bomber", 13, 11)])
	sim.step()
	assert_eq(sim.unit_target(1), 3, "ground: the open turret")
	assert_eq(sim.unit_target(2), 2, "air: the nearer")


func test_preferences_and_their_fallback() -> void:
	var buildings := [["command_center", 8, 8], ["silo", 16, 16], ["turret", 16, 0], ["wall", 3, 10]]
	var sim := Fixtures.battle(buildings, {"raider": 1, "hunter": 1, "breaker": 1, "melee": 1}, [
		Fixtures.deploy(0, "raider", 4, 4), Fixtures.deploy(0, "hunter", 4, 4),
		Fixtures.deploy(0, "breaker", 4, 4), Fixtures.deploy(0, "melee", 4, 4)])
	sim.step()
	assert_eq(sim.unit_target(1), 2, "a raider goes for the silo")
	assert_eq(sim.unit_target(2), 3, "a hunter for the turret")
	assert_eq(sim.unit_target(3), 4, "a breaker for the wall")
	assert_eq(sim.unit_target(4), 1, "a melee for the nearest, never a wall")
	sim = Fixtures.battle([["command_center", 8, 8], ["wall", 3, 3]], {"hunter": 1, "raider": 1},
		[Fixtures.deploy(0, "hunter", 0, 0), Fixtures.deploy(0, "raider", 0, 0)])
	sim.step()
	assert_eq(sim.unit_target(1), 1, "no defence standing: any building")
	assert_eq(sim.unit_target(2), 1, "no resource building standing: any building")


func test_traps_are_never_targets() -> void:
	var sim := Fixtures.battle([["command_center", 15, 15], ["mine", 3, 0]], {"drone": 1},
		[Fixtures.deploy(0, "drone", 0, 0)])
	sim.step()
	assert_eq(sim.unit_target(1), 1)


func test_ties_go_to_the_lowest_id() -> void:
	var sim := Fixtures.battle([["command_center", 0, 18], ["academy", 13, 10], ["academy", 7, 10]],
		{"drone": 1, "melee": 1}, [Fixtures.deploy(0, "drone", 10, 10), Fixtures.deploy(0, "melee", 10, 10)])
	sim.step()
	assert_eq(sim.unit_target(1), 2, "air: equal distances, the lower id")
	assert_eq(sim.unit_target(2), 2, "ground: equal paths, the lower id")


func test_a_new_target_when_the_target_falls() -> void:
	var sim := Fixtures.battle([["command_center", 0, 18], ["academy", 10, 10]], {"melee": 1},
		[Fixtures.deploy(0, "melee", 12, 12)])
	sim.step()
	assert_eq(sim.unit_target(1), 2)
	_step_until(sim, func() -> bool: return sim.is_destroyed(2))
	assert_eq(sim.unit_target(1), 2, "still on it until its next update")
	sim.step()
	assert_eq(sim.unit_target(1), 1)


func test_a_search_in_the_tick_of_a_fall_sees_it() -> void:
	# Melee 1 fells the academy (id 2) at some tick; melee 2, deployed beside it on that tick,
	# finds the Command Center in the same tick rather than a fallen academy or nothing.
	var buildings := [["command_center", 0, 18], ["academy", 10, 10]]
	var probe := Fixtures.battle(buildings, {"melee": 1}, [Fixtures.deploy(0, "melee", 12, 10)])
	_step_until(probe, func() -> bool: return probe.is_destroyed(2))
	var fell_at := probe.tick - 1
	var sim := Fixtures.battle(buildings, {"melee": 2}, [Fixtures.deploy(0, "melee", 12, 10),
		Fixtures.deploy(fell_at, "melee", 12, 11)])
	for i: int in fell_at + 1:
		sim.step()
	assert_true(sim.is_destroyed(2), "the academy fell on tick %d" % fell_at)
	assert_eq(sim.unit_target(2), 1, "the new unit has the Command Center")
	assert_eq(sim.unit_state(2), BattleArmy.WALKING)
	assert_eq(sim.unit_target(1), 2, "the one that felled it has spent its turn this tick")
	sim.step()
	assert_eq(sim.unit_target(1), 1, "and looks again on the next")


func test_an_unrevealed_sentry_is_the_last_resort() -> void:
	var sim := Fixtures.battle([["command_center", 16, 16], ["sentry", 4, 0]], {"drone": 1},
		[Fixtures.deploy(0, "drone", 0, 0)])
	sim.step()
	assert_eq(sim.unit_target(1), 1, "the sentry is unseen: the Command Center")
	sim = Fixtures.battle([["sentry", 10, 10]], {"melee": 1}, [Fixtures.deploy(0, "melee", 0, 0)])
	sim.step()
	assert_eq(sim.unit_target(1), 1, "nothing else standing: the unseen sentry")


func test_defences_hit_their_class_in_range() -> void:
	# A turret hits ground only: the drone beside it is left alone, the melee in range is hit.
	var sim := Fixtures.battle([["command_center", 0, 18], ["turret", 10, 10]], {"drone": 1, "melee": 1},
		[Fixtures.deploy(0, "drone", 12, 12), Fixtures.deploy(0, "melee", 8, 12)])
	sim.step()
	assert_eq(sim.unit_hp(1), 50, "the drone untouched")
	assert_eq(sim.unit_hp(2), 90, "the melee hit for 10")
	sim = Fixtures.battle([["command_center", 0, 18], ["turret", 10, 10]], {"melee": 1},
		[Fixtures.deploy(0, "melee", 10, 15)])
	sim.step()
	assert_eq(sim.unit_hp(1), 100, "out of range")


func test_a_defence_keeps_its_target() -> void:
	# The tower hits the nearest unit, then keeps on it while it stays alive and in range, though
	# another comes nearer.
	var sim := Fixtures.battle([["command_center", 0, 18], ["tower", 10, 10]], {"hunter": 2},
		[Fixtures.deploy(0, "hunter", 14, 10), Fixtures.deploy(1, "hunter", 18, 10)])
	sim.step()
	assert_eq(sim.combat.aim[1], 0, "the only one in range")
	_step_until(sim, func() -> bool: return sim.unit_position(2).x < sim.unit_position(1).x)
	sim.step()
	assert_eq(sim.combat.aim[1], 0, "kept")


func _step_until(sim: BattleSim, done: Callable) -> void:
	var guard := 0
	while not done.call() and not sim.is_over() and guard < 5000:
		sim.step()
		guard += 1
