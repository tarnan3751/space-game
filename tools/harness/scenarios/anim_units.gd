extends HarnessScenario
## The units' animation as frame strips (docs/reference/battle-view.md, **Units**), for the
## animation audit: every unit type in the catalog's order, each in a battle of its own opened
## through main.open_battle (a practice battle: nothing applied), one unit at LEVEL against one
## target, a Metal Silo at TARGET_LEVEL (its sturdiest, so it stands through every strip) on
## TARGET_CELL. The unit is deployed through
## BattleView.deploy (no touch) on the cell up and to the screen's right of the target, WALK_UNITS
## beyond its reach, so it walks or flies across the screen before it fires.
##
## The battle HUD is hidden. Strips, each logged with its camera size: "<unit>-move" (MOVE_FRAMES at
## MOVE_STEP_MS), framed on the unit where it will be half-way through the strip, at its MOVE_ZOOM,
## or for the infantry (INFANTRY) cropped to the centre half of the window at a view INFANTRY_VIEW
## high; "<unit>-fire" (FIRE_FRAMES at FIRE_STEP_MS), framed with frame_span on the unit and its
## target's middle (FIRE_MARGIN, at least FIRE_MIN; cropped for the infantry), starting
## FIRE_LEAD_MS before its second shot (the breacher, which blows itself up on its first, as it
## closes in).
##
## Close strips, cropped, at CLOSE_ZOOM times the model's height (camera size 3 to 6), for the
## limbs: "<unit>-close-bank" for a hovering type (BANKERS), from its deploy, where it turns about
## 90 degrees onto its course (CLOSE_FRAMES at CLOSE_STEP_MS); "<unit>-close-move" after the
## settle, framed on the middle of its path (CLOSE_FRAMES at CLOSE_STEP_MS), before the wide move
## strip; "<unit>-close-fire" after the wide fire strip, from just before a shot, over two shots
## (CLOSE_FIRE_FRAMES, the step two shots' time over them, CLOSE_FIRE_STEP_MS at most), but for a
## recoiling type (KICKERS), whose kick and return a slow step would miss, one shot at
## DEATH_CLOSE_FRAMES and DEATH_CLOSE_STEP_MS; and
## "<unit>-close-death" (DEATH_CLOSE_FRAMES at DEATH_CLOSE_STEP_MS), staged on the unit attacking
## in place (framed lower and wider by its model's lowest point, so a falling aircraft stays in the
## tile) through BattleUnits.die (the view's death; the sim's unit lives on, unseen). The breacher,
## which blows itself up on its first blow, has neither: its fire strip, as long as a close death
## strip (DEATH_CLOSE_FRAMES at DEATH_CLOSE_STEP_MS), holds its blast and its death.
##
## Then the effects lane's block, for every unit type: "<unit>-impact" (IMPACT_FRAMES at
## IMPACT_STEP_MS), a close strip (IMPACT_VIEW across, cropped) on the near side of the target as
## the unit's second shot leaves and lands (its projectile, its impact; the brawler's punch, the
## breacher's charge); and "<unit>-death" (DEATH_FRAMES at DEATH_STEP_MS): the unit walks or flies
## on two Railguns (DEATH_TURRET at DEATH_TURRET_LEVEL, which hit ground and air) and is shot down,
## the battle run at WAIT_SPEED until one shot is left in it; the strip, close on the unit
## (DEATH_VIEW, cropped), starts then, and the ticks it ran over are logged beside the tick the
## unit died on: the sim's death, so its effects (BattleView, the weapon record's) show.
##
## Checks: each battle opens, the unit moves in its move strip, fires (its target's hull drops, or
## the breacher is gone), hits in its impact strip and each death strip's unit is shot down; a hovering type banks as it
## turns, a twin-weaponed walker's or brawler's blows alternate sides (its drawn state's parity), and a staged death
## is no longer drawn after its death's seconds. Headless the strips are skipped and the checks
## still run. Each battle is ended (surrender) and left before the next.

const LEVEL := 1
const SEED := 20261024
const TARGET := "metal_silo"
const TARGET_LEVEL := 10
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
## The death strips' killer (it hits ground and air, hard enough to end a titan inside WAIT_TICKS),
## their frames and the least view, and the speed the battle runs at while a strip waits.
const DEATH_TURRET := "railgun"
const DEATH_TURRET_LEVEL := 7
const DEATH_FRAMES := 16
const DEATH_STEP_MS := 80
const DEATH_VIEW := 3.5
const WAIT_SPEED := 2
## The impact strips: frames, step and the least view.
const IMPACT_FRAMES := 14
const IMPACT_STEP_MS := 70
const IMPACT_VIEW := 3.0
## How close the self-destructing unit is to its reach when its impact strip starts, field units.
const CHARGE_UNITS := 120
## The close strips: the camera's size per unit of the model's height (cropped to its centre
## half), and its least and most; the frames and their steps.
const CLOSE_ZOOM := 2.4
const CLOSE_MIN := 3.0
const CLOSE_MAX := 6.0
const CLOSE_FRAMES := 12
const CLOSE_STEP_MS := 60
const CLOSE_FIRE_FRAMES := 16
const CLOSE_FIRE_STEP_MS := 320
## The types whose shots kick a gun back (Rig.AIM's kick, the slides).
const KICKERS: Array[String] = ["ranger", "siege_walker", "hover_tank", "titan"]
const DEATH_CLOSE_FRAMES := 12
const DEATH_CLOSE_STEP_MS := 70
## The hovering types, which bank, and the least bank (radians) a turn onto its course must show.
const BANKERS: Array[String] = ["jet_trooper", "skimmer", "hover_tank", "gunship", "bomber"]
const BANK_SEEN := 0.1
## The types with a weapon on each side whose rig takes turns (the brawler's punches, the walkers'
## recoils), by the parity in their drawn state.
const TWINS: Array[String] = ["brawler", "siege_walker", "titan"]
## The types that close in to attack, whose close fire strip would stand in the silo's shadow on
## the screen's right: deployed on its lit side instead.
const LIT_SIDE: Array[String] = ["brawler"]
## The longest wait for any one moment, in ticks (a minute of battle).
const WAIT_TICKS := 1200

var _catalog: Catalog


func run(main: MainScript) -> void:
	_catalog = main.catalog
	var types := _catalog.unit_types()
	check(types.size() == 11, "the catalog has eleven unit types (%d)" % types.size())
	for unit: String in types:
		await _move_and_fire(main, unit)
	for unit: String in types:
		await _impact(main, unit)
	for unit: String in types:
		await _death(main, unit)


## One `unit` against the target: its move strip, then its fire strip.
func _move_and_fire(main: MainScript, unit: String) -> void:
	var size := _catalog.size_of(TARGET)
	var target := {"id": 1, "type": TARGET, "level": TARGET_LEVEL, "cell": [TARGET_CELL.x, TARGET_CELL.y]}
	if not _open(main, [target], unit):
		return
	var view: BattleView = main.battle
	var reach := int(_catalog.unit_level_stats(unit, LEVEL).get("range_units", 0))
	var cell := _start_cell(reach + WALK_UNITS, size, LIT_SIDE.has(unit))
	check(view.deploy(unit, cell) == "", "%s deployed on %s" % [unit, cell])
	var close := clampf(CLOSE_ZOOM * UnitModels.meshes(unit, Parts.Tier.BASE).body.get_aabb().size.y, CLOSE_MIN, CLOSE_MAX)
	if BANKERS.has(unit):
		await _until(view, func() -> bool: return view.units.drawn() > 0)
		var start := view.units.aim_point(1)
		var aim := view.building_centre(1)
		var course := Vector3(aim.x - start.x, 0.0, aim.z - start.z).normalized()
		frame_world(main, close, start + course * _catalog.unit_speed(unit) / 1000.0 * CLOSE_FRAMES * CLOSE_STEP_MS / 2000.0)
		var banked := [0.0]
		var watch := func() -> void: banked[0] = maxf(banked[0], absf(view.units.drawn_state(1).r - Rig.BANK_BASE))
		main.get_tree().process_frame.connect(watch)
		var until := view.clock() + CLOSE_FRAMES * CLOSE_STEP_MS / 1000.0
		await strip("%s-close-bank" % unit, CLOSE_FRAMES, CLOSE_STEP_MS, true)
		await _until(view, func() -> bool: return view.clock() >= until)
		main.get_tree().process_frame.disconnect(watch)
		check(banked[0] >= BANK_SEEN, "%s banked into its turn (%.2f radians at most)" % [unit, banked[0]])
	await _until(view, func() -> bool: return view.sim.tick >= SETTLE_TICKS)
	var crop := INFANTRY.has(unit)
	var close_from := view.units.aim_point(1)
	var close_goal := view.building_centre(1)
	var close_heading := Vector3(close_goal.x - close_from.x, 0.0, close_goal.z - close_from.z).normalized()
	var close_travel := _catalog.unit_speed(unit) / 1000.0 * CLOSE_FRAMES * CLOSE_STEP_MS / 1000.0
	frame_world(main, close, close_from + close_heading * close_travel * 0.5)
	await strip("%s-close-move" % unit, CLOSE_FRAMES, CLOSE_STEP_MS, true)
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
	if self_destructs:
		await strip("%s-fire" % unit, DEATH_CLOSE_FRAMES, DEATH_CLOSE_STEP_MS, crop)
	else:
		await strip("%s-fire" % unit, FIRE_FRAMES, FIRE_STEP_MS, crop)
	await _until(view, func() -> bool: return view.sim.building_hp(1) < hull)
	check(view.sim.building_hp(1) < hull, "%s hit the %s (hull %d of %d)" % [unit, TARGET, view.sim.building_hp(1), hull])
	if not self_destructs:
		await _close_fire_and_death(main, unit, close)
	await _leave(main)


## The close fire strip of `unit` attacking in place, over two shots, then its staged death, both
## framed at `close` on the unit.
func _close_fire_and_death(main: MainScript, unit: String, close: float) -> void:
	var view: BattleView = main.battle
	var fire_ms := int(_catalog.unit_level_stats(unit, LEVEL).get("fire_ms", 1000))
	var step := clampi(fire_ms * 2 / CLOSE_FIRE_FRAMES, CLOSE_STEP_MS, CLOSE_FIRE_STEP_MS)
	await _until(view, func() -> bool: return view.sim.army.cooldown[0] > FIRE_LEAD_MS)
	await _until(view, func() -> bool: return view.sim.army.cooldown[0] <= FIRE_LEAD_MS)
	frame_world(main, close, view.units.aim_point(1))
	var sides := [false, false]
	var watch := func() -> void:
		var state := view.units.drawn_state(1)
		if state.g < 0.0:
			sides[1 if state.r >= 2.0 else 0] = true
	main.get_tree().process_frame.connect(watch)
	if KICKERS.has(unit):
		await strip("%s-close-fire" % unit, DEATH_CLOSE_FRAMES, DEATH_CLOSE_STEP_MS, true)
	else:
		await strip("%s-close-fire" % unit, CLOSE_FIRE_FRAMES, step, true)
	if TWINS.has(unit):
		await _until(view, func() -> bool: return sides[0] and sides[1])
	main.get_tree().process_frame.disconnect(watch)
	if TWINS.has(unit):
		check(sides[0] and sides[1], "%s's shots alternate sides (left %s, right %s)" % [unit, sides[0], sides[1]])
	var at := view.units.aim_point(1)
	var low := UnitModels.meshes(unit, Parts.Tier.BASE).body.get_aabb().position.y
	frame_world(main, close + low, at - Vector3(0.0, low * 0.5, 0.0))
	view.units.die(1, view.clock())
	var shown := view.units.drawn()
	await strip("%s-close-death" % unit, DEATH_CLOSE_FRAMES, DEATH_CLOSE_STEP_MS, true)
	var until := view.clock() + view.units.death_seconds(1)
	await _until(view, func() -> bool: return view.clock() >= until)
	await frames(2)
	check(view.units.drawn() == shown - 1, "%s's staged death played out in %.2f s (%d drawn, %d before)"
		% [unit, view.units.death_seconds(1), view.units.drawn(), shown])


# --- The effects' strips -----------------------------------------------------------

## One `unit` against the target, from close by: its impact strip, close on the side of the target
## it hits, from just before its second shot.
func _impact(main: MainScript, unit: String) -> void:
	var size := _catalog.size_of(TARGET)
	var target := {"id": 1, "type": TARGET, "level": TARGET_LEVEL, "cell": [TARGET_CELL.x, TARGET_CELL.y]}
	if not _open(main, [target], unit):
		return
	var view: BattleView = main.battle
	var reach := int(_catalog.unit_level_stats(unit, LEVEL).get("range_units", 0))
	check(view.deploy(unit, _start_cell(reach + 1000, size)) == "", "%s deployed by the %s" % [unit, TARGET])
	var hull := view.sim.building_hp(1)
	view.speed = WAIT_SPEED
	if _catalog.unit_self_destructs(unit):
		var rect := Rect2i(TARGET_CELL * 1000, Vector2i.ONE * size * 1000)
		await _until(view, func() -> bool: return view.sim.unit_state(1) == BattleArmy.WALKING)
		await _until(view, func() -> bool:
			return _gap(view.sim.unit_position(1), rect) <= reach + CHARGE_UNITS or view.sim.unit_state(1) != BattleArmy.WALKING)
	else:
		await _until(view, func() -> bool: return view.sim.unit_state(1) == BattleArmy.ATTACKING)
		hull = view.sim.building_hp(1)
		await _until(view, func() -> bool: return view.sim.army.cooldown[0] > FIRE_LEAD_MS)
		await _until(view, func() -> bool: return view.sim.army.cooldown[0] <= FIRE_LEAD_MS * 2)
	view.speed = 1
	var at := view.units.aim_point(1)
	var centre := view.building_centre(1) + Vector3(0.0, 0.6, 0.0)
	var side := centre + (Vector3(at.x, centre.y, at.z) - centre).normalized() * size * 0.5
	frame_span(main, side, side, FIRE_MARGIN, IMPACT_VIEW, true)
	await strip("%s-impact" % unit, IMPACT_FRAMES, IMPACT_STEP_MS, true)
	await _until(view, func() -> bool: return view.sim.building_hp(1) < hull)
	check(view.sim.building_hp(1) < hull, "%s hit the %s in its impact strip (hull %d of %d)" % [unit, TARGET,
		view.sim.building_hp(1), hull])
	await _leave(main)


## One `unit` walking or flying on the Railgun, shot down: its death strip.
func _death(main: MainScript, unit: String) -> void:
	var size := _catalog.size_of(DEATH_TURRET)
	var turret := {"id": 1, "type": DEATH_TURRET, "level": DEATH_TURRET_LEVEL, "cell": [TARGET_CELL.x, TARGET_CELL.y]}
	var second := {"id": 2, "type": DEATH_TURRET, "level": DEATH_TURRET_LEVEL,
		"cell": [TARGET_CELL.x - size - 1, TARGET_CELL.y + size + 1]}
	if not _open(main, [turret, second], unit):
		return
	var view: BattleView = main.battle
	var reach := int(_catalog.unit_level_stats(unit, LEVEL).get("range_units", 0))
	var damage := int(_catalog.level_stats(DEATH_TURRET, DEATH_TURRET_LEVEL).get("damage", 0))
	check(view.deploy(unit, _start_cell(reach + 1000, size)) == "", "%s deployed in the turret's range" % unit)
	view.speed = WAIT_SPEED
	await _until(view, func() -> bool: return view.sim.unit_hp(1) <= damage)
	view.speed = 1
	var at := view.units.aim_point(1)
	frame_span(main, Vector3(at.x, at.y * 0.5, at.z), Vector3(at.x, at.y * 0.5, at.z), FIRE_MARGIN, DEATH_VIEW, true)
	var started := view.sim.tick
	await strip("%s-death" % unit, DEATH_FRAMES, DEATH_STEP_MS, true)
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


## The deploy cell up and to the screen's right of the footprint at TARGET_CELL of `size`, or with
## `lit` down and to its left, on the side the sun lights, at least `distance` field units from its
## nearest corner, and outside the deploy zone.
func _start_cell(distance: int, size: int, lit: bool = false) -> Vector2i:
	var steps := maxi(1, ceili((distance / sqrt(2.0) - 500.0) / 1000.0))
	if lit:
		return Vector2i(TARGET_CELL.x - 1 - steps, TARGET_CELL.y + size + steps)
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
