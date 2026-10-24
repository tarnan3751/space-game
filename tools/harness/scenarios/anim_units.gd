extends HarnessScenario
## The units' animation as frame strips (docs/reference/battle-view.md, **Units**), for the
## animation audit: every unit type in the catalog's order, each in a battle of its own opened
## through main.open_battle (a practice battle: nothing applied), one unit at LEVEL against one
## target, a Metal Silo at TARGET_LEVEL on TARGET_CELL. The unit is deployed through
## BattleView.deploy (no touch) on the cell up and to the screen's right of the target, WALK_UNITS
## beyond its reach, so it walks or flies across the screen before it fires.
##
## The battle HUD is hidden. Strips, each logged with its camera size: "<unit>-move" (MOVE_FRAMES at
## MOVE_STEP_MS), framed on the unit where it will be half-way through the strip, at its MOVE_ZOOM,
## or for the infantry (INFANTRY) cropped to the centre half of the window at a view INFANTRY_VIEW
## high; "<unit>-fire" (FIRE_FRAMES at FIRE_STEP_MS), framed with frame_span on the unit and its
## target's middle (FIRE_MARGIN, at least FIRE_MIN; cropped for the infantry), starting
## FIRE_LEAD_MS before its second shot (the breacher, which blows itself up on its first, as it
## closes in). Then "<unit>-death" for an
## infantry and a vehicle (DEATHS): the unit walks on a Laser Turret (DEATH_TURRET_LEVEL) and is
## shot down; the strip (DEATH_FRAMES at FIRE_STEP_MS, framed as a fire strip) starts just before the turret's last shot,
## and the ticks it ran over are logged beside the tick the unit died on.
##
## Checks: each battle opens, the unit moves in its move strip, fires (its target's hull drops, or
## the breacher is gone) and each death strip's unit is shot down. Headless the strips are
## skipped and the checks still run. Each battle is ended (surrender) and left before the next.

const LEVEL := 1
const SEED := 20261024
const TARGET := "metal_silo"
const TARGET_LEVEL := 1
const TARGET_CELL := Vector2i(22, 22)
## Field units beyond its reach the unit starts, so it moves for over a second.
const WALK_UNITS := 4000
## Ticks after the deploy before the move strip: the heading turned and the gait eased in.
const SETTLE_TICKS := 6
const MOVE_FRAMES := 8
const MOVE_STEP_MS := 100
const FIRE_FRAMES := 8
const FIRE_STEP_MS := 50
const FIRE_LEAD_MS := 100
## Camera sizes: a unit alone, by its size (MOVE_ZOOM, UNIT_ZOOM for one not listed), so it
## fills about a sixth of the frame's height; the infantry, cropped, and the height of the view
## its tile shows; the margin round a unit and its target in a fire strip and the least view.
const MOVE_ZOOM := {"titan": 7.0, "gunship": 6.0, "bomber": 6.0, "siege_walker": 5.0, "hover_tank": 5.0}
const UNIT_ZOOM := 4.0
const INFANTRY: Array[String] = ["ranger", "breacher", "jet_trooper", "brawler"]
const INFANTRY_VIEW := 2.5
const FIRE_MARGIN := 1.5
const FIRE_MIN := 4.5
## How close the self-destructing unit is to its reach when its fire strip starts, field units.
const CLOSING_UNITS := 400
## The unit types shot dying, an infantry and a vehicle, and their killer.
const DEATHS: Array[String] = ["ranger", "dune_runner"]
const DEATH_TURRET := "laser_turret"
const DEATH_TURRET_LEVEL := 1
const DEATH_FRAMES := 12
## The longest wait for any one moment, in ticks (a minute of battle).
const WAIT_TICKS := 1200

var _catalog: Catalog


func run(main: MainScript) -> void:
	_catalog = main.catalog
	var types := _catalog.unit_types()
	check(types.size() == 11, "the catalog has eleven unit types (%d)" % types.size())
	for unit: String in types:
		await _move_and_fire(main, unit)
	for unit: String in DEATHS:
		await _death(main, unit)


## One `unit` against the target: its move strip, then its fire strip.
func _move_and_fire(main: MainScript, unit: String) -> void:
	var size := _catalog.size_of(TARGET)
	var target := {"id": 1, "type": TARGET, "level": TARGET_LEVEL, "cell": [TARGET_CELL.x, TARGET_CELL.y]}
	if not _open(main, [target], unit):
		return
	var view: BattleView = main.battle
	var reach := int(_catalog.unit_level_stats(unit, LEVEL).get("range_units", 0))
	var cell := _start_cell(reach + WALK_UNITS, size)
	check(view.deploy(unit, cell) == "", "%s deployed on %s" % [unit, cell])
	await _until(view, func() -> bool: return view.sim.tick >= SETTLE_TICKS)
	var crop := INFANTRY.has(unit)
	var zoom: float = INFANTRY_VIEW * 2.0 if crop else MOVE_ZOOM.get(unit, UNIT_ZOOM)
	var at := view.units.aim_point(1)
	var goal := view.building_centre(1)
	var heading := Vector3(goal.x - at.x, 0.0, goal.z - at.z).normalized()
	var travel := _catalog.unit_speed(unit) / 1000.0 * MOVE_FRAMES * MOVE_STEP_MS / 1000.0
	frame_world(main, zoom, at + heading * travel * 0.5)
	var from := view.sim.unit_position(1)
	await strip("%s-move" % unit, MOVE_FRAMES, MOVE_STEP_MS, crop)
	await _until(view, func() -> bool: return view.sim.unit_position(1) != from)
	check(view.sim.unit_position(1) != from, "%s moved (from %s to %s)" % [unit, from, view.sim.unit_position(1)])

	# The fire strip, framed as it closes in and started before its second shot (the breacher's
	# first, which is its last).
	var rect := Rect2i(TARGET_CELL * 1000, Vector2i.ONE * size * 1000)
	var self_destructs := _catalog.unit_self_destructs(unit)
	await _until(view, func() -> bool:
		return _gap(view.sim.unit_position(1), rect) <= reach + 1500 or view.sim.unit_state(1) == BattleArmy.ATTACKING)
	var hull := view.sim.building_hp(1)
	if self_destructs:
		await _until(view, func() -> bool:
			return _gap(view.sim.unit_position(1), rect) <= reach + CLOSING_UNITS or view.sim.unit_state(1) != BattleArmy.WALKING)
	else:
		await _until(view, func() -> bool: return view.sim.unit_state(1) == BattleArmy.ATTACKING)
		await _until(view, func() -> bool: return view.sim.army.cooldown[0] > FIRE_LEAD_MS)
		await _until(view, func() -> bool: return view.sim.army.cooldown[0] <= FIRE_LEAD_MS)
	at = view.units.aim_point(1)
	goal = view.building_centre(1) + Vector3(0.0, 0.6, 0.0)
	frame_span(main, at, goal, FIRE_MARGIN, FIRE_MIN, crop)
	await strip("%s-fire" % unit, FIRE_FRAMES, FIRE_STEP_MS, crop)
	await _until(view, func() -> bool: return view.sim.building_hp(1) < hull)
	check(view.sim.building_hp(1) < hull, "%s hit the %s (hull %d of %d)" % [unit, TARGET, view.sim.building_hp(1), hull])
	await _leave(main)


## One `unit` walking on a Laser Turret, shot down: its death strip.
func _death(main: MainScript, unit: String) -> void:
	var size := _catalog.size_of(DEATH_TURRET)
	var turret := {"id": 1, "type": DEATH_TURRET, "level": DEATH_TURRET_LEVEL, "cell": [TARGET_CELL.x, TARGET_CELL.y]}
	if not _open(main, [turret], unit):
		return
	var view: BattleView = main.battle
	var reach := int(_catalog.unit_level_stats(unit, LEVEL).get("range_units", 0))
	var damage := int(_catalog.level_stats(DEATH_TURRET, DEATH_TURRET_LEVEL).get("damage", 0))
	check(view.deploy(unit, _start_cell(reach + 1000, size)) == "", "%s deployed in the turret's range" % unit)
	await _until(view, func() -> bool: return view.sim.unit_hp(1) <= damage * 2)
	await _until(view, func() -> bool:
		return view.sim.unit_hp(1) <= damage and view.sim.combat.cooldown[0] <= FIRE_LEAD_MS)
	var at := view.units.aim_point(1)
	var turret_top := view.building_centre(1) + Vector3(0.0, 1.0, 0.0)
	var crop := INFANTRY.has(unit)
	frame_span(main, at, turret_top, FIRE_MARGIN, FIRE_MIN, crop)
	var started := view.sim.tick
	await strip("%s-death" % unit, DEATH_FRAMES, FIRE_STEP_MS, crop)
	var ended := view.sim.tick
	await _until(view, func() -> bool: return view.sim.unit_state(1) == BattleArmy.DEAD)
	check(view.sim.unit_state(1) == BattleArmy.DEAD, "the %s was shot down by tick %d (the strip ran from tick %d to %d)"
		% [unit, view.sim.tick, started, ended])
	await _leave(main)


## Opens a practice battle of `buildings` against one `unit` at LEVEL, its HUD hidden and no unit
## selected (no red zone), so the strips show only the field; false if it is refused. The army brings a second, never deployed, so the
## battle does not end (and its result panel open) when the first falls.
func _open(main: MainScript, buildings: Array, unit: String) -> bool:
	var setup := {
		"seed": SEED,
		"attacker": {"army": {unit: 2}, "unit_levels": {unit: LEVEL}, "abilities": {}, "ability_levels": {}},
		"defender": {"buildings": buildings, "resources": {}},
		"commands": [],
	}
	var error := main.open_battle(setup, true)
	check(error == "", "the battle for %s opens: '%s'" % [unit, error])
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


## The deploy cell up and to the screen's right of the footprint at TARGET_CELL of `size`, at
## least `distance` field units from its nearest corner, and outside the deploy zone.
func _start_cell(distance: int, size: int) -> Vector2i:
	var steps := maxi(1, ceili((distance / sqrt(2.0) - 500.0) / 1000.0))
	return Vector2i(TARGET_CELL.x + size + steps, TARGET_CELL.y - 1 - steps)


## The distance in field units from `at` to the rectangle `rect` (field units).
func _gap(at: Vector2i, rect: Rect2i) -> int:
	var dx := maxi(maxi(rect.position.x - at.x, at.x - rect.end.x), 0)
	var dy := maxi(maxi(rect.position.y - at.y, at.y - rect.end.y), 0)
	return int(sqrt(float(dx * dx + dy * dy)))


## Waits a frame at a time until `done` holds, the battle ends or WAIT_TICKS pass.
func _until(view: BattleView, done: Callable) -> void:
	var limit := view.sim.tick + WAIT_TICKS
	while not done.call() and not view.sim.is_over() and view.sim.tick < limit:
		await frames(1)
