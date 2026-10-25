extends HarnessScenario
## The defences' aim, kick, EMP freeze and reveal as frame strips (docs/reference/battle-view.md,
## **Aim and muzzles**; docs/reference/art-style.md, **Moving parts**): every defence that aims
## (AIMERS, each at level 1 and the four with their aiming part rebuilt at their top level too), in
## a practice battle of its own opened through main.open_battle, its HUD hidden.
##
## The field: the defence on DEFENCE_CELL and a Metal Silo off to its upper right, and a unit
## deployed off to its upper left that makes for the silo, so it crosses the defence's arc inside its
## range: a Dune Runner on the ground (it goes for resources, so it passes the defence by), a
## Gunship in the air for the flak cannon (further up, so the silo is nearer it than the gun), at
## UNIT_LEVEL. The army brings UNITS, the next deployed at the same spot whenever the last falls.
##
## Per defence and level, two strips cropped to the centre half of the window, on the defence's head:
## - "<type>-<level>-aim" (AIM_FRAMES at AIM_STEP_MS, camera AIM_ZOOM), from the deploy: the head
##   turning from its idle scan towards the unit as it crosses. Checks: the defence aims
##   (BuildingView.can_aim), its muzzle turns more than MIN_SWEEP degrees over the strip and at some
##   frame faces the unit within BattleView.AIM_READY, and it is not kicked before its first shot.
## - "<type>-<level>-fire" (FIRE_FRAMES at FIRE_STEP_MS, camera FIRE_ZOOM), started FIRE_LEAD_MS before
##   the defence's next shot (its cooldown in the sim): the shot and the kick back along the barrel.
##   Shot once more ("-fire-again") when no kick showed in it. Checks: a kick of at least MIN_KICK
##   of its full travel is seen, and the defence kicks no more
##   often than it fires (BuildingView.fired, counted against the bolts and shells it fires).
##
## Then "emp-freeze": a level 6 missile battery (its launcher and its radar turning) aiming at a Dune
## Runner, an EMP Burst cast on it, the strip (EMP_FRAMES at EMP_STEP_MS) over the stun and the wake.
## Checks: while it is disabled no moving part moves (the muzzle socket and the radar stand still
## from frame to frame); once awake they move again. And "reveal": a cloaked sentry hidden until the
## Dune Runner comes within its range, the strip (REVEAL_FRAMES at REVEAL_STEP_MS) over its fade in.
## Checks: it shows every step of the fade (BuildingView.reveal_step) and ends as itself.

const SEED := 20261025
const AIMERS: Array[String] = ["laser_turret", "missile_battery", "plasma_mortar", "flak_cannon", "cloaked_sentry",
	"railgun", "ion_beam", "orbital_cannon"]
## The defences shot at their top level too: their aiming part was rebuilt with what rides it.
const TOP_LEVEL: Array[String] = ["plasma_mortar", "flak_cannon", "ion_beam", "orbital_cannon"]
const DECOY := "metal_silo"
const DEFENCE_CELL := Vector2i(24, 26)
## Offsets in cells from the defence's centre cell: where the unit is deployed and the silo stands.
const GROUND_FROM := Vector2i(-5, -4)
const GROUND_SILO := Vector2i(3, -5)
const AIR_FROM := Vector2i(-4, -8)
const AIR_SILO := Vector2i(4, -9)
const GROUND_UNIT := "dune_runner"
const AIR_UNIT := "gunship"
## The units' level (the Dune Runner's top, so it lives through a few shots) and how many the army
## brings: a new one is deployed whenever the last has fallen (_resupply).
const UNIT_LEVEL := 7
const UNITS := 8
const AIM_FRAMES := 16
const AIM_STEP_MS := 200
const AIM_ZOOM := 9.0
const FIRE_FRAMES := 12
const FIRE_STEP_MS := 50
const FIRE_ZOOM := 7.0
const FIRE_LEAD_MS := 100
## A fire strip is shot again ("<type>-<level>-fire-again") when no kick showed in it: the unit it
## was due at fell, or a slow frame let the shot slip past the strip.
const FIRE_ATTEMPTS := 2
const MIN_SWEEP := 25.0
const MIN_KICK := 0.3
const EMP_DEFENCE := "missile_battery"
const EMP_LEVEL := 6
const EMP := "emp_burst"
const EMP_FRAMES := 16
const EMP_STEP_MS := 250
const SENTRY := "cloaked_sentry"
const REVEAL_FRAMES := 8
const REVEAL_STEP_MS := 60
## How near (field units) the unit comes to the sentry before its reveal strip starts: its range
## and a cell.
const REVEAL_LEAD := 1000
const WAIT_TICKS := 1200
const DEFENCE := 2

var _catalog: Catalog
## Sampled each frame while a defence is watched (_watch): the most of a kick seen, the kicks begun
## (a rise of recoil_share from 0), the defence's shots (a new fired time), the muzzle's headings.
var _watched: BuildingView = null
var _max_kick := 0.0
var _kicks := 0
var _last_kick := 0.0
var _shots := 0
var _last_fired := -INF
var _kicked_before_shot := false
var _headings := PackedFloat32Array()
var _best_error := INF
## The EMP strip's defence, its radar, and what _watch_frozen counts: the frames it was disabled,
## those of them its parts moved, the frames they moved after it woke, and the last poses.
var _frozen_view: BattleView = null
var _frozen: BuildingView = null
var _frozen_radar: Node3D = null
var _frozen_frames := 0
var _frozen_moves := 0
var _awake_moves := 0
var _last_muzzle := Vector3.ZERO
var _last_radar := Transform3D.IDENTITY


func run(main: MainScript) -> void:
	_catalog = main.catalog
	main.get_tree().process_frame.connect(_sample.bind(main))
	for type: String in AIMERS:
		await _aim(main, type, 1)
		if TOP_LEVEL.has(type):
			await _aim(main, type, _catalog.max_level(type))
	await _emp_freeze(main)
	await _reveal(main)
	main.get_tree().process_frame.disconnect(_sample)


## The aim and fire strips of `type` at `level`.
func _aim(main: MainScript, type: String, level: int) -> void:
	var air := _catalog.targets_of(type) == "air"
	if not _open(main, type, level, AIR_UNIT if air else GROUND_UNIT, air):
		return
	var view: BattleView = main.battle
	var defence: BuildingView = view._views[DEFENCE]
	check(defence.can_aim(), "the %s %d aims (its muzzle is on a moving part)" % [type, level])
	_watch(defence)
	frame_world(main, AIM_ZOOM, _head(view, defence))
	await frames(3)
	_deploy(view, air)
	await _strip(main, "%s-%d-aim" % [type, level], AIM_FRAMES, AIM_STEP_MS, true)
	var sweep := _sweep()
	check(sweep >= MIN_SWEEP, "the %s %d's muzzle turned %.0f degrees over the strip (at least %.0f)" % [type, level, sweep,
		MIN_SWEEP])
	check(_best_error <= BattleView.AIM_READY, "the %s %d faced the unit within %.2f radians (best %.2f)" % [type, level,
		BattleView.AIM_READY, _best_error])
	check(not _kicked_before_shot, "the %s %d was not kicked before it fired" % [type, level])
	var index := view.sim.layout.index_of(DEFENCE)
	var due := func() -> bool:
		return view.sim.building_target(DEFENCE) != 0 and view.sim.combat.cooldown[index] <= FIRE_LEAD_MS \
			and view.sim.combat.cooldown[index] > 0
	_max_kick = 0.0
	for attempt: int in FIRE_ATTEMPTS:
		await _until(view, due)
		frame_world(main, FIRE_ZOOM, _head(view, defence))
		await _strip(main, "%s-%d-fire%s" % [type, level, "" if attempt == 0 else "-again"], FIRE_FRAMES, FIRE_STEP_MS, true)
		if _max_kick >= MIN_KICK:
			break
	check(_max_kick >= MIN_KICK, "the %s %d kicked back as it fired (%.2f of its travel at most)" % [type, level, _max_kick])
	check(_kicks <= _shots, "the %s %d kicked %d times for %d shots" % [type, level, _kicks, _shots])
	_watch(null)
	await _leave(main)


## A level 6 missile battery frozen by an EMP Burst while it aims, and waking.
func _emp_freeze(main: MainScript) -> void:
	if not _open(main, EMP_DEFENCE, EMP_LEVEL, GROUND_UNIT, false, {EMP: 1}):
		return
	var view: BattleView = main.battle
	var defence: BuildingView = view._views[DEFENCE]
	frame_world(main, AIM_ZOOM, _head(view, defence))
	_deploy(view, false)
	await _until(view, func() -> bool: return view.sim.building_target(DEFENCE) != 0)
	var centre := view.building_centre(DEFENCE)
	var cell := view.field.world_to_cell(centre)
	view.script_commands([{"op": "ability", "tick": view.sim.tick + 2, "ability": EMP, "cell": [cell.x, cell.y]}])
	var radar := _radar(defence)
	_frozen_view = view
	_frozen = defence
	_frozen_radar = radar
	_frozen_frames = 0
	_frozen_moves = 0
	_awake_moves = 0
	_last_muzzle = defence.socket_point("muzzle")
	_last_radar = radar.transform if radar != null else Transform3D.IDENTITY
	main.get_tree().process_frame.connect(_watch_frozen)
	await _strip(main, "emp-freeze", EMP_FRAMES, EMP_STEP_MS, true)
	await _until(view, func() -> bool: return _frozen_frames > 0 and not view.is_shown_disabled(DEFENCE))
	await frames(10)
	main.get_tree().process_frame.disconnect(_watch_frozen)
	var frozen_frames := _frozen_frames
	var frozen_moves := _frozen_moves
	var awake_moves := _awake_moves
	check(radar != null, "the level %d missile battery has a turning radar" % EMP_LEVEL)
	check(frozen_frames > 1, "the EMP burst disabled the missile battery (%d frames)" % frozen_frames)
	check(frozen_moves == 0, "no moving part moved while it was disabled (%d frames moved)" % frozen_moves)
	check(awake_moves > 0, "its moving parts moved again once it woke (%d frames)" % awake_moves)
	await _leave(main)


## A cloaked sentry fading in as it is revealed.
func _reveal(main: MainScript) -> void:
	if not _open(main, SENTRY, 1, GROUND_UNIT, false):
		return
	var view: BattleView = main.battle
	var defence: BuildingView = view._views[DEFENCE]
	check(not defence.visible, "the cloaked sentry is hidden")
	frame_world(main, FIRE_ZOOM, _head(view, defence))
	_deploy(view, false)
	var reach := int(_catalog.level_stats(SENTRY, 1).get("range_cells", 0)) * 1000 + REVEAL_LEAD
	var centre := view.building_centre(DEFENCE)
	var near := func() -> bool:
		if view.sim.unit_count() == 0:
			return false
		var at := view.sim.unit_position(1)
		var grid := _catalog.grid_size
		var gap := Vector2(at.x / 1000.0 - grid.x * 0.5 - centre.x, at.y / 1000.0 - grid.y * 0.5 - centre.z)
		return gap.length() * 1000.0 <= reach or view.sim.is_revealed(DEFENCE)
	await _until(view, near)
	var steps := {}
	var watch := func() -> void:
		steps[defence.reveal_step()] = true
	main.get_tree().process_frame.connect(watch)
	await _strip(main, "reveal", REVEAL_FRAMES, REVEAL_STEP_MS, true)
	await _until(view, func() -> bool: return view.sim.is_revealed(DEFENCE))
	await main.get_tree().create_timer(BattleView.REVEAL_SECONDS + 0.2).timeout
	main.get_tree().process_frame.disconnect(watch)
	check(defence.visible, "the cloaked sentry was revealed")
	for step: int in BuildingView.REVEAL_STEPS:
		check(steps.has(step), "it showed step %d of its fade in" % step)
	check(defence.reveal_step() == -1, "it ends as itself")
	await _leave(main)


## Each frame of the EMP strip: whether the frozen defence's muzzle or radar moved, while it is
## disabled and after.
func _watch_frozen() -> void:
	var muzzle := _frozen.socket_point("muzzle")
	var turned := _frozen_radar.transform if _frozen_radar != null else Transform3D.IDENTITY
	var moved := muzzle.distance_to(_last_muzzle) > 0.0001 or not turned.is_equal_approx(_last_radar)
	if _frozen_view.is_shown_disabled(DEFENCE):
		_frozen_frames += 1
		if moved and _frozen_frames > 1:
			_frozen_moves += 1
	elif _frozen_frames > 0 and moved:
		_awake_moves += 1
	_last_muzzle = muzzle
	_last_radar = turned


## Opens a practice battle of the defence `type` at `level` and the silo against UNITS `unit`s at
## UNIT_LEVEL (and `abilities`), its HUD hidden and no unit selected; false if it is refused.
func _open(main: MainScript, type: String, level: int, unit: String, air: bool, abilities: Dictionary = {}) -> bool:
	var silo := _centre_cell(type) + (AIR_SILO if air else GROUND_SILO)
	var setup := {
		"seed": SEED,
		"attacker": {"army": {unit: UNITS}, "unit_levels": {unit: mini(UNIT_LEVEL, _catalog.unit_max_level(unit))},
			"abilities": abilities, "ability_levels": {}},
		"defender": {"buildings": [
			{"id": 1, "type": DECOY, "level": 1, "cell": [silo.x, silo.y]},
			{"id": DEFENCE, "type": type, "level": level, "cell": [DEFENCE_CELL.x, DEFENCE_CELL.y]},
		], "resources": {}},
		"commands": [],
	}
	var error := main.open_battle(setup, true)
	check(error == "", "the battle opens for the %s %d: '%s'" % [type, level, error])
	if error != "":
		return false
	main.battle_hud.visible = false
	main.battle.select_unit("")
	return true


## Deploys the first unit off the defence's upper left, on the nearest cell that takes it.
func _deploy(view: BattleView, air: bool) -> void:
	var unit := AIR_UNIT if air else GROUND_UNIT
	var from := _centre_cell(view.building_type(DEFENCE)) + (AIR_FROM if air else GROUND_FROM)
	for k: int in 5:
		if view.deploy(unit, from + Vector2i(-k, -k)) == "":
			return
	check(false, "a %s deployed near %s" % [unit, from])


## The cell under the defence's centre.
func _centre_cell(type: String) -> Vector2i:
	var size := _catalog.size_of(type)
	return DEFENCE_CELL + Vector2i(size / 2, size / 2)


## The defence's head: its muzzle socket, or its centre at its height.
func _head(view: BattleView, defence: BuildingView) -> Vector3:
	if defence.has_socket("muzzle"):
		return defence.socket_point("muzzle").lerp(defence.global_position + Vector3(0, defence.site_height() * 0.6, 0), 0.3)
	return view.building_centre(DEFENCE) + Vector3(0, defence.site_height() * 0.6, 0)


## The missile battery's radar: its moving part spinning about +Y with no muzzle on it.
func _radar(defence: BuildingView) -> Node3D:
	for child: Node in defence.get_child(0).get_children():
		if child.has_meta(BuildingModels.MOVE_META) and not child.has_meta(BuildingModels.SOCKETS_META):
			var motion: Motion = child.get_meta(BuildingModels.MOVE_META)
			if motion.kind == Motion.Kind.SPIN:
				return child as Node3D
	return null


## Starts sampling `defence` each frame (null stops it).
func _watch(defence: BuildingView) -> void:
	_watched = defence
	_max_kick = 0.0
	_kicks = 0
	_last_kick = 0.0
	_shots = 0
	_last_fired = -INF
	_kicked_before_shot = false
	_headings.clear()
	_best_error = INF


## Each frame: the watched defence's kick, its shots, its muzzle's heading and how far it is from
## facing its target.
func _sample(main: MainScript) -> void:
	if _watched == null or not is_instance_valid(_watched) or main.battle == null:
		return
	var view: BattleView = main.battle
	_resupply(view)
	var kick := _watched.recoil_share()
	if _watched._fired_at != _last_fired:
		_last_fired = _watched._fired_at
		_shots += 1
	if kick > 0.0 and _last_kick == 0.0:
		_kicks += 1
		if _shots == 0:
			_kicked_before_shot = true
	_last_kick = kick
	_max_kick = maxf(_max_kick, kick)
	var facing := _watched.socket_direction("muzzle")
	_headings.append(atan2(facing.x, facing.z))
	var target := view.sim.building_target(DEFENCE)
	if target != 0 and view.sim.unit_state(target) != BattleArmy.DEAD:
		_best_error = minf(_best_error, _watched.aim_error(view.units.aim_point(target)))


## Deploys the next unit once every one deployed has fallen, while any are left.
func _resupply(view: BattleView) -> void:
	if view.sim.is_over() or view.sim.unit_count() == 0:
		return
	for unit: int in range(1, view.sim.unit_count() + 1):
		if view.sim.unit_state(unit) != BattleArmy.DEAD:
			return
	var air := view.sim.unit_type(1) == AIR_UNIT
	if view.sim.left_to_deploy(AIR_UNIT if air else GROUND_UNIT) > 0:
		_deploy(view, air)


## Degrees between the muzzle's headings furthest apart since the watch began.
func _sweep() -> float:
	if _headings.is_empty():
		return 0.0
	var first := _headings[0]
	var low := 0.0
	var high := 0.0
	for heading: float in _headings:
		var off := angle_difference(first, heading)
		low = minf(low, off)
		high = maxf(high, off)
	return rad_to_deg(high - low)


## A strip (strip()) that also takes its time headless, where no frame is saved, so the battle
## runs through what the strip would show before the checks read it.
func _strip(main: MainScript, name: String, count: int, step_ms: int, crop: bool) -> void:
	var started := Time.get_ticks_msec()
	await strip(name, count, step_ms, crop)
	while Time.get_ticks_msec() - started < count * step_ms:
		await main.get_tree().process_frame


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
