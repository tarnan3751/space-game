extends HarnessScenario
## The battle's effects as frame strips (docs/reference/battle-view.md, **Shots and impacts**,
## **The field and the buildings**), for the animation audit, each battle a practice battle opened
## through main.open_battle, its HUD hidden and no unit selected; abilities cast through
## BattleView.cast and units deployed through BattleView.deploy (no touch).
##
## The abilities: a Laser Turret and a Metal Silo at SILO_LEVEL, two Hover Tanks attacking the
## silo from beside it inside the turret's range, one of each ability brought. "swarm-dome"
## (SWARM_FRAMES at SWARM_STEP_MS) from a Repair Swarm cast on the tanks; "emp-ring" (8 at 50 ms)
## from an EMP Burst cast on the turret, then "emp-grey" (EMP_FRAMES at EMP_STEP_MS) over its
## stun and its waking, and "emp-wake" (WAKE_FRAMES at 50 ms, close) from just before it wakes from
## a second burst: its wake flash; "strike-marker" (8 at 100 ms) from an Orbital Strike cast on the silo,
## "strike-land" (LAND_FRAMES at 50 ms) from LAND_LEAD_TICKS before it lands, the bolt, the
## fireball and the rings, and "strike-smoke" (8 at 150 ms) after it.
##
## The shield: a Shield Generator beside a silo a Hover Tank attacks: "shield-hit" (8 at 100 ms)
## as its shots land on the pool, "shield-drop" (8 at 100 ms) from just before the shot that
## empties it. The rubble: a Hover Tank fells a Drone Bay; "rubble-settle" (12 at 100 ms) from the
## fall, "smoke-column" (8 at 250 ms) framed up the column SMOKE_DELAY_SECONDS later.
##
## Checks: every cast is accepted, the turret is shown disabled, the strike hits the silo, the
## shield's pool empties and the drone bay falls.

const SEED := 20261024
const UNIT := "hover_tank"
const SILO := "metal_silo"
const SILO_LEVEL := 10
const SILO_CELL := Vector2i(30, 22)
const TURRET := "laser_turret"
const TURRET_CELL := Vector2i(30, 26)
const UNIT_CELLS: Array[Vector2i] = [Vector2i(34, 23), Vector2i(34, 24)]
const ZOOM := 6.0
const WIDE_ZOOM := 8.0
const SWARM_FRAMES := 8
const SWARM_STEP_MS := 250
const EMP_FRAMES := 8
const EMP_STEP_MS := 500
## The close strip of the turret waking from a second EMP burst: its view, how many ticks before
## the wake it starts, its frames.
const WAKE_ZOOM := 4.0
const WAKE_LEAD_TICKS := 2
const WAKE_FRAMES := 8
const LAND_FRAMES := 16
const LAND_LEAD_TICKS := 12
const SHIELD := "shield_generator"
const SHIELD_CELL := Vector2i(30, 26)
const LEAD_MS := 100
const FALL_TARGET := "drone_bay"
const FALL_CELL := Vector2i(24, 24)
const FAR_CELL := Vector2i(4, 4)
const SMOKE_DELAY_SECONDS := 2.0
const WAIT_TICKS := 1200

var _catalog: Catalog


func run(main: MainScript) -> void:
	_catalog = main.catalog
	await _abilities(main)
	await _shield(main)
	await _rubble(main)


## The three abilities over a turret, a silo and two tanks.
func _abilities(main: MainScript) -> void:
	var buildings := [
		{"id": 1, "type": SILO, "level": SILO_LEVEL, "cell": [SILO_CELL.x, SILO_CELL.y]},
		{"id": 2, "type": TURRET, "level": 1, "cell": [TURRET_CELL.x, TURRET_CELL.y]},
	]
	var stock := {}
	for ability: String in _catalog.ability_types():
		stock[ability] = 2 if ability == "emp_burst" else 1
	if not _open(main, buildings, {UNIT: 3}, stock):
		return
	var view: BattleView = main.battle
	for cell: Vector2i in UNIT_CELLS:
		check(view.deploy(UNIT, cell) == "", "a hover tank deployed on %s" % cell)
	await _until(view, func() -> bool:
		return view.sim.unit_hp(1) < view.sim.unit_max_hp(1) or view.sim.unit_hp(2) < view.sim.unit_max_hp(2))

	# The swarm, on the tanks.
	var tanks := view.field.cell_to_world(UNIT_CELLS[0], 1)
	frame_world(main, ZOOM, tanks)
	await frames(2)
	check(view.cast("repair_swarm", UNIT_CELLS[0]) == "", "the repair swarm is cast on the tanks")
	await strip("swarm-dome", SWARM_FRAMES, SWARM_STEP_MS)

	# The EMP, on the turret: its ring, then the grey over the stun and the waking.
	var turret := view.building_centre(2)
	frame_world(main, ZOOM, turret)
	await frames(2)
	check(view.cast("emp_burst", TURRET_CELL + Vector2i.ONE) == "", "the EMP burst is cast on the turret")
	await strip("emp-ring", 8, 50)
	await _until(view, func() -> bool: return view.is_shown_disabled(2))
	check(view.is_shown_disabled(2), "the turret is shown disabled")
	var wakes := view.sim.combat.disabled_until[view.sim.layout.index_of(2)]
	await strip("emp-grey", EMP_FRAMES, EMP_STEP_MS)

	# The EMP again, and the turret waking from it close up: its flash.
	await _until(view, func() -> bool: return view.sim.tick > wakes + 2)
	frame_world(main, WAKE_ZOOM, turret + Vector3(0.0, 0.6, 0.0))
	await frames(2)
	check(view.cast("emp_burst", TURRET_CELL + Vector2i.ONE) == "", "the EMP burst is cast on the turret again")
	await _until(view, func() -> bool: return view.is_shown_disabled(2))
	wakes = view.sim.combat.disabled_until[view.sim.layout.index_of(2)]
	await _until(view, func() -> bool: return view.sim.tick >= wakes - WAKE_LEAD_TICKS)
	await strip("emp-wake", WAKE_FRAMES, 50)
	var ended := view.sim.tick
	await _until(view, func() -> bool: return not view.is_shown_disabled(2))
	check(not view.is_shown_disabled(2), "the turret woke on tick %d (the emp-wake strip ended on tick %d)" % [wakes, ended])

	# The strike, on the silo: the marker, the landing, the smoke.
	var silo := view.building_centre(1)
	frame_world(main, WIDE_ZOOM, silo + Vector3(0.0, 1.5, 0.0))
	await frames(2)
	var hull := view.sim.building_hp(1)
	var cast_tick := view.sim.tick
	check(view.cast("orbital_strike", SILO_CELL + Vector2i.ONE) == "", "the orbital strike is cast on the silo")
	var delay := int(_catalog.ability_level_stats("orbital_strike", 1).get("delay_ms", 0)) / BattleSim.TICK_MS
	await strip("strike-marker", 8, 100)
	await _until(view, func() -> bool: return view.sim.tick >= cast_tick + delay - LAND_LEAD_TICKS)
	await strip("strike-land", LAND_FRAMES, 50)
	await strip("strike-smoke", 8, 150)
	await _until(view, func() -> bool: return view.sim.tick > cast_tick + delay)
	check(view.sim.building_hp(1) < hull - 400, "the strike hit the silo (hull %d from %d)" % [view.sim.building_hp(1), hull])
	await _leave(main)


## A shield generator's pool over a silo, taking a tank's shots until it empties.
func _shield(main: MainScript) -> void:
	var buildings := [
		{"id": 1, "type": SILO, "level": SILO_LEVEL, "cell": [SILO_CELL.x, SILO_CELL.y]},
		{"id": 2, "type": SHIELD, "level": 1, "cell": [SHIELD_CELL.x, SHIELD_CELL.y]},
	]
	if not _open(main, buildings, {UNIT: 2}, {}):
		return
	var view: BattleView = main.battle
	var damage := int(_catalog.unit_level_stats(UNIT, 1).get("damage", 0))
	frame_world(main, WIDE_ZOOM, (view.building_centre(1) + view.building_centre(2)) * 0.5)
	check(view.deploy(UNIT, UNIT_CELLS[0]) == "", "a hover tank deployed by the silo")
	await _until(view, func() -> bool: return view.sim.shield_hp(2) < int(_catalog.level_stats(SHIELD, 1).get("shield_hp", 0)))
	await strip("shield-hit", 8, 100)
	var due := func() -> bool:
		return view.sim.shield_hp(2) <= damage and view.sim.army.cooldown[0] <= LEAD_MS
	await _until(view, due)
	await strip("shield-drop", 8, 100)
	await _until(view, func() -> bool: return view.sim.shield_hp(2) == 0)
	check(view.sim.shield_hp(2) == 0, "the shield's pool emptied")
	await _leave(main)


## A drone bay's rubble settling and its smoke rising.
func _rubble(main: MainScript) -> void:
	var buildings := [
		{"id": 1, "type": FALL_TARGET, "level": 1, "cell": [FALL_CELL.x, FALL_CELL.y]},
		{"id": 2, "type": SILO, "level": 1, "cell": [FAR_CELL.x, FAR_CELL.y]},
	]
	if not _open(main, buildings, {UNIT: 2}, {}):
		return
	var view: BattleView = main.battle
	var size := _catalog.size_of(FALL_TARGET)
	check(view.deploy(UNIT, FALL_CELL + Vector2i(size + 1, -1)) == "", "a hover tank deployed by the drone bay")
	var centre := view.building_centre(1)
	frame_world(main, ZOOM, centre + Vector3(0.0, 0.5, 0.0))
	await _until(view, func() -> bool: return view.sim.is_destroyed(1))
	check(view.sim.is_destroyed(1), "the drone bay fell")
	await strip("rubble-settle", 12, 100)
	await main.get_tree().create_timer(SMOKE_DELAY_SECONDS).timeout
	frame_world(main, ZOOM, centre + Vector3(0.0, 1.5, 0.0))
	await frames(2)
	await strip("smoke-column", 8, 250)
	await _leave(main)


## Opens a practice battle of `buildings` against `army` (level 1) bringing `abilities`, its HUD
## hidden and no unit selected; false if it is refused. Each army brings one unit more than the
## scenario deploys, so the battle does not end when the deployed fall.
func _open(main: MainScript, buildings: Array, army: Dictionary, abilities: Dictionary) -> bool:
	var setup := {
		"seed": SEED,
		"attacker": {"army": army, "unit_levels": {}, "abilities": abilities, "ability_levels": {}},
		"defender": {"buildings": buildings, "resources": {}},
		"commands": [],
	}
	var error := main.open_battle(setup, true)
	check(error == "", "the battle opens: '%s'" % error)
	if error != "":
		return false
	main.battle_hud.visible = false
	main.battle.select_unit("")
	return true


## Ends the battle if it runs and leaves it; the base comes back.
func _leave(main: MainScript) -> void:
	var view: BattleView = main.battle
	if not view.sim.is_over():
		view.surrender()
	await frames(2)
	view.leave()
	await frames(2)
	check(main.battle == null, "the battle was left")


## Waits a frame at a time until `done` holds, the battle ends or WAIT_TICKS pass.
func _until(view: BattleView, done: Callable) -> void:
	var limit := view.sim.tick + WAIT_TICKS
	while not done.call() and not view.sim.is_over() and view.sim.tick < limit:
		await frames(1)
