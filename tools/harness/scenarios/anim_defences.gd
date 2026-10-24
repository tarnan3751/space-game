extends HarnessScenario
## The defences' animation as frame strips (docs/reference/battle-view.md, **Shots and impacts**),
## for the animation audit: every building type with a targets class in the catalog's order (the
## guns and the traps; walls and the shield generator have none), each at level 1 in a practice
## battle of its own opened through main.open_battle, its HUD hidden and no unit selected.
##
## The field: a Metal Silo at DECOY_LEVEL on DECOY_CELL, the defence beside the unit's cell, below
## it on the screen (DEFENCE_CELL; a trap on the unit's own cell, UNIT_CELL), and one unit of the class the defence
## targets (a Hover Tank on the ground, a Gunship in the air) deployed on UNIT_CELL, next to the
## silo, which it attacks without moving, inside every gun's range. The camera is framed with
## frame_span on the defence's head and the unit (MARGIN, at least MIN_VIEW) and the strip is
## cropped to the centre half of the window; the strip
## "<defence>-fire" (FIRE_FRAMES at FIRE_STEP_MS, or STEPS's for the slow ones: the shells, the
## well's pull, the grav trap's throw) starts DEPLOY_DELAY_TICKS before the deploy (sent through
## BattleView.script_commands), so it holds the empty field, the unit's arrival and the defence's
## first shot. Checks: the defence acted on the unit (its hull dropped, it was held, or the trap
## went off).
##
## Then "building-fall": a Hover Tank on a Drone Bay, the strip (FALL_FRAMES at FALL_STEP_MS)
## started FALL_LEAD_MS before the shot that fells it: the flash, the fall, the dust and the rubble. And
## "wall-break": a Breacher at BREACHER_LEVEL (its blast is more than a level 1 wall's hull) on a
## Barrier Wall, the strip started as it closes in. Each of those layouts keeps a silo far off, so
## the battle does not end at the fall.

const SEED := 20261024
const LEVEL := 1
const DECOY := "metal_silo"
const DECOY_LEVEL := 1
const DECOY_CELL := Vector2i(30, 22)
const UNIT_CELL := Vector2i(34, 23)
const DEFENCE_CELL := Vector2i(33, 26)
const GROUND_UNIT := "hover_tank"
const AIR_UNIT := "gunship"
## Ticks from the strip's start to the deploy, so the first frames show the field before the unit.
const DEPLOY_DELAY_TICKS := 3
const FIRE_FRAMES := 8
const FIRE_STEP_MS := 50
## [frames, step ms] for the defences whose shot takes longer than FIRE_FRAMES at FIRE_STEP_MS.
const STEPS := {
	"plasma_mortar": [10, 150],
	"orbital_cannon": [12, 200],
	"gravity_well": [8, 100],
	"grav_trap": [8, 100],
}
## The margin round a fire strip's two ends and the least height of the view its cropped tile
## shows (frame_span).
const MARGIN := 1.5
const MIN_VIEW := 4.5
## The fall and the wall's break.
const FALL_TARGET := "drone_bay"
const FALL_CELL := Vector2i(24, 24)
const FAR_CELL := Vector2i(4, 4)
const FALL_FRAMES := 12
const FALL_STEP_MS := 100
## How long before the felling shot the fall strip starts, so the shot is in it.
const FALL_LEAD_MS := 250
const FALL_ZOOM := 6.0
const WALL := "barrier_wall"
const BREACHER := "breacher"
const BREACHER_LEVEL := 4
const BREAK_FRAMES := 12
const BREAK_STEP_MS := 50
const BREAK_ZOOM := 5.0
const CLOSING_UNITS := 400
const WAIT_TICKS := 1200

var _catalog: Catalog


func run(main: MainScript) -> void:
	_catalog = main.catalog
	var shot := 0
	for type: String in _catalog.types():
		if _catalog.targets_of(type) == "":
			continue
		await _fire(main, type)
		shot += 1
	check(shot >= 15, "%d defences and traps shot" % shot)
	await _building_fall(main)
	await _wall_break(main)


## One defence or trap `type` acting on a unit of its class.
func _fire(main: MainScript, type: String) -> void:
	var trap := _catalog.battle_class(type) == Catalog.CLASS_TRAP
	var unit := AIR_UNIT if _catalog.targets_of(type) == "air" else GROUND_UNIT
	var cell := UNIT_CELL if trap else DEFENCE_CELL
	var buildings := [
		{"id": 1, "type": DECOY, "level": DECOY_LEVEL, "cell": [DECOY_CELL.x, DECOY_CELL.y]},
		{"id": 2, "type": type, "level": LEVEL, "cell": [cell.x, cell.y]},
	]
	if not _open(main, buildings, unit, LEVEL):
		return
	var view: BattleView = main.battle
	var size := _catalog.size_of(type)
	var head := view.field.cell_to_world(cell, size) + Vector3(0.0, 1.5 if not trap else 0.0, 0.0)
	var at := view.field.cell_to_world(UNIT_CELL, 1) + Vector3(0.0, 0.5, 0.0)
	frame_span(main, head, at, MARGIN, MIN_VIEW, true)
	await frames(3)
	var steps: Array = STEPS.get(type, [FIRE_FRAMES, FIRE_STEP_MS])
	var deploy: Array[Dictionary] = [{"op": "deploy", "tick": view.sim.tick + DEPLOY_DELAY_TICKS, "unit": unit,
		"cell": [UNIT_CELL.x, UNIT_CELL.y]}]
	view.script_commands(deploy)
	await strip("%s-fire" % type, int(steps[0]), int(steps[1]), true)
	await _until(view, func() -> bool: return view.sim.unit_count() > 0)
	check(view.sim.unit_count() == 1, "a %s deployed by the %s" % [unit, type])
	var acted := func() -> bool:
		return view.sim.unit_hp(1) < view.sim.unit_max_hp(1) or view.sim.army.hold_until[0] > 0 \
			or view.sim.is_destroyed(2)
	await _until(view, acted)
	check(acted.call(), "the %s acted on the %s (hull %d of %d)" % [type, unit, view.sim.unit_hp(1),
		view.sim.unit_max_hp(1)])
	await _leave(main)


## A Hover Tank fells a Drone Bay.
func _building_fall(main: MainScript) -> void:
	var buildings := [
		{"id": 1, "type": FALL_TARGET, "level": 1, "cell": [FALL_CELL.x, FALL_CELL.y]},
		{"id": 2, "type": DECOY, "level": 1, "cell": [FAR_CELL.x, FAR_CELL.y]},
	]
	if not _open(main, buildings, GROUND_UNIT, LEVEL):
		return
	var view: BattleView = main.battle
	var size := _catalog.size_of(FALL_TARGET)
	var damage := int(_catalog.unit_level_stats(GROUND_UNIT, LEVEL).get("damage", 0))
	check(view.deploy(GROUND_UNIT, FALL_CELL + Vector2i(size + 1, -1)) == "", "a hover tank deployed by the drone bay")
	frame_world(main, FALL_ZOOM, view.building_centre(1) + Vector3(0.0, 0.5, 0.0))
	var due := func() -> bool:
		return view.sim.building_hp(1) <= damage and view.sim.unit_state(1) == BattleArmy.ATTACKING \
			and view.sim.army.cooldown[0] <= FALL_LEAD_MS
	await _until(view, due)
	await strip("building-fall", FALL_FRAMES, FALL_STEP_MS)
	await _until(view, func() -> bool: return view.sim.is_destroyed(1))
	check(view.sim.is_destroyed(1), "the drone bay fell")
	await _leave(main)


## A Breacher blows up a Barrier Wall.
func _wall_break(main: MainScript) -> void:
	var buildings := [
		{"id": 1, "type": WALL, "level": 1, "cell": [FALL_CELL.x, FALL_CELL.y]},
		{"id": 2, "type": DECOY, "level": 1, "cell": [FAR_CELL.x, FAR_CELL.y]},
	]
	if not _open(main, buildings, BREACHER, BREACHER_LEVEL):
		return
	var view: BattleView = main.battle
	var reach := int(_catalog.unit_level_stats(BREACHER, BREACHER_LEVEL).get("range_units", 0))
	check(view.deploy(BREACHER, FALL_CELL + Vector2i(4, -3)) == "", "a breacher deployed near the wall")
	frame_world(main, BREAK_ZOOM, view.field.cell_to_world(FALL_CELL + Vector2i(1, -1), 1))
	var rect := Rect2i(FALL_CELL * 1000, Vector2i(1000, 1000))
	await _until(view, func() -> bool: return view.sim.unit_state(1) == BattleArmy.WALKING)
	await _until(view, func() -> bool:
		return _gap(view.sim.unit_position(1), rect) <= reach + CLOSING_UNITS or view.sim.unit_state(1) != BattleArmy.WALKING)
	await strip("wall-break", BREAK_FRAMES, BREAK_STEP_MS)
	await _until(view, func() -> bool: return view.sim.is_destroyed(1))
	check(view.sim.is_destroyed(1), "the wall fell")
	await _leave(main)


## Opens a practice battle of `buildings` against `unit` at `level`, its HUD hidden and no unit
## selected (no red zone), so the strips show only the field; false if it is refused. The army
## brings a second, never deployed, so the battle does not end when the first falls.
func _open(main: MainScript, buildings: Array, unit: String, level: int) -> bool:
	var setup := {
		"seed": SEED,
		"attacker": {"army": {unit: 2}, "unit_levels": {unit: level}, "abilities": {}, "ability_levels": {}},
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
