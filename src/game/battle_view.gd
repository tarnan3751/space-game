class_name BattleView
extends Node3D
## The battle scene (docs/reference/battle-view.md): a BattleSim driven at its fixed tick and
## drawn. It owns the sim, made from a setup (docs/reference/battle.md), and steps it once for
## every 50 ms of battle shown (TICK_SECONDS, `speed` times as fast), at most MAX_STEPS_PER_FRAME a
## frame, so a slow frame slows the battle rather than skipping the sim's order. Between steps it
## reads the sim and never changes it: deploys and the surrender go in through command() at the
## current tick, as the sim's own surface takes them. Positions, headings and health are
## interpolated in the view only, between the last two ticks.
##
## The scene: the defender's field in the landscape of the battle's seed (a BaseView of its own,
## the grid off), its walls in the field's merged WallMesh, every other building a BuildingView at
## its level and tier, the units (BattleUnits, a MultiMesh pair a type) and the effects
## (BattleEffects, each kind one MultiMesh). A hit whitens a building for a moment and shakes it; a
## fallen building is replaced by its rubble (BuildingModels.create_rubble) with its smoke, a
## fallen wall leaves the merged mesh for a low strip. A hidden sentry shows once revealed; traps
## never show, but a mine going off leaves a flash and a scorch mark. A shield generator's pool is
## a faint dome while it is up. The camera is the base's IsoCamera, free over the field.
##
## Input comes from a WorldInput of its own (main.gd takes the base's out of the tree for the
## battle): a pinch or a two-finger pan moves the camera, a drag pans it, and a tap on the field
## deploys one unit of `deploy_unit` there (the first type with units left by default).
##
## main.gd makes it, adds it in place of the base's view and frees it on `finished`, which it
## emits END_HOLD_SECONDS after the battle ends, with the setup and the sim's result.

signal finished(setup: Dictionary, result: Dictionary)
## The sim stepped (one or more ticks this frame): the attack HUD (series B's BattleHud) refreshes
## on it.
signal stepped

## Seconds of battle a tick is, and the most ticks one frame steps.
const TICK_SECONDS := 1.0 / BattleSim.TICKS_PER_SECOND
const MAX_STEPS_PER_FRAME := 4
## The speeds a player runs the view at, 1 and 2 times real time, which the attack HUD's speed
## button (series B's BattleHud) steps through. `speed` 0, which the harness sets while it
## measures, pauses it: no tick is stepped and the effects' clock stands still.
const SPEEDS: Array[int] = [1, 2]
## How long the field stays after the end before `finished`.
const END_HOLD_SECONDS := 3.0
## A hit's flash and shake on a building, and how far it shakes.
const FLASH_SECONDS := 0.08
const SHAKE_SECONDS := 0.18
const SHAKE := 0.05
## How long a building's health bar shows after its last hit, and how high over it.
const BAR_SECONDS := 3.0
const BAR_OVER := 0.4
## Where a shot leaves a defence and hits a building: a share of the model's height.
const MUZZLE_SHARE := 0.75
const HIT_HEIGHT := 0.6
## A unit's reach (field units) up to which its hits are drawn as a blow (an impact at the
## target), not a bolt.
const MELEE_REACH := 1000
## The effects' tints and sizes: the defences' shots, the units', a shell's landing, a mine's blast,
## a gravity well's pull, a fall's dust.
const DEFENCE_SHOT := MaterialKit.DEFENCE
const UNIT_SHOT := MaterialKit.ENERGY
const SHELL_BLAST := Color("ff8a3d")
const MINE_BLAST := MaterialKit.HAZARD
const WELL_PULL := MaterialKit.ANTIMATTER
const FALL_DUST := Color("c9c2e0")
const SCORCH_RADIUS := 0.7

## The battle being run; read only.
var sim: BattleSim
## The setup it was made from.
var battle_setup: Dictionary = {}
var catalog: Catalog
## 1 or 2 (SPEEDS): ticks a 50 ms of real time; 0 pauses (the harness's measuring).
var speed: int = 1
## The unit type a tap deploys; "" deploys the first type with units left.
var deploy_unit: String = ""
var camera: IsoCamera
## The defender's field: ground, scenery, the merged walls.
var field: BaseView
var input: WorldInput
var units: BattleUnits
var effects: BattleEffects

## Seconds of battle shown so far, `speed` times as fast as real time, run on after the end.
var _clock: float = 0.0
var _accumulator: float = 0.0
## Each building in the battle: its type, its footprint's top-left cell, its size and its centre
## (world x and z).
var _types: Dictionary[int, String] = {}
var _levels: Dictionary[int, int] = {}
var _cells: Dictionary[int, Vector2i] = {}
var _sizes: Dictionary[int, int] = {}
var _centres: Dictionary[int, Vector2] = {}
## The drawn buildings (not walls, not traps) and where each shot leaves it (its muzzle's height).
var _views: Dictionary[int, BuildingView] = {}
var _muzzles: Dictionary[int, float] = {}
## The standing walls' levels by cell, rebuilt into the merged mesh at the end of a frame they fell in.
var _walls: Dictionary[Vector2i, int] = {}
var _walls_changed: bool = false
## Per building hit lately: when its flash and its shake end, until when its bar shows, its bar's
## fill; and the ids done this frame, reused.
var _flash_until: Dictionary[int, float] = {}
var _shake_until: Dictionary[int, float] = {}
var _bar_until: Dictionary[int, float] = {}
var _bars: Dictionary[int, float] = {}
var _done := PackedInt32Array()
## The shield generators.
var _shields := PackedInt32Array()
## Arc towers, whose shots are lightning.
var _arc_towers: Dictionary[int, bool] = {}
## Per unit type brought: its reach at the attacker's level (field units) and its splash (world
## units).
var _reach: Dictionary[String, int] = {}
var _splash: Dictionary[String, float] = {}
## When the battle ended on the clock, -1 while it runs, and the real seconds since.
var _ended_at: float = -1.0
var _held: float = 0.0
var _finished: bool = false
## The sim's step time: total and longest, in microseconds, and the steps counted.
var _step_usec: int = 0
var _step_usec_max: int = 0
var _step_slowest: int = 0
var _steps: int = 0
## Commands to send at their ticks (script_commands), in tick order, and the next one.
var _script: Array[Dictionary] = []
var _next_script: int = 0


## Makes the battle from `setup` on `battle_catalog`, its field and its scene; "" or why the setup
## was refused (BattleSim.setup_error). Call before adding to the tree; `iso_camera` is the
## scene's camera.
func setup(battle_catalog: Catalog, setup_data: Dictionary, iso_camera: IsoCamera) -> String:
	catalog = battle_catalog
	battle_setup = setup_data
	camera = iso_camera
	sim = BattleSim.create(catalog, setup_data)
	if sim.setup_error != "":
		return sim.setup_error
	var grid := catalog.grid_size
	field = BaseView.new()
	add_child(field)
	field.setup(grid, BattleMath.whole(setup_data.get("seed", 0)) & SeededRng.MASK_32)
	var area := AABB(Vector3(-grid.x * 0.5 - 2.0, -2.0, -grid.y * 0.5 - 2.0),
		Vector3(grid.x + 4.0, 16.0, grid.y + 4.0))

	var listed := {}
	var defender: Dictionary = setup_data.get("defender", {})
	for entry: Variant in defender.get("buildings", []):
		var building: Dictionary = entry
		listed[BattleMath.whole(building.get("id"))] = building
	var walls := 0
	var root := Node3D.new()
	add_child(root)
	for id: int in sim.building_ids():
		var building: Dictionary = listed[id]
		var type := str(building["type"])
		var level := BattleMath.whole(building["level"])
		var cell := BattleMath.cell_from(building["cell"])
		var size := catalog.size_of(type)
		_types[id] = type
		_levels[id] = level
		_cells[id] = cell
		_sizes[id] = size
		var centre := field.cell_to_world(cell, size)
		_centres[id] = Vector2(centre.x, centre.z)
		match catalog.battle_class(type):
			Catalog.CLASS_WALL:
				_walls[cell] = level
				walls += 1
			Catalog.CLASS_TRAP:
				pass
			_:
				var view := BuildingView.new()
				view.setup(id, type, level, size, BuildingModels.tier_of(catalog, type, level))
				view.position = centre
				root.add_child(view)
				view.visible = sim.is_revealed(id)
				_views[id] = view
				_muzzles[id] = maxf(0.6, view.site_height() * MUZZLE_SHARE)
				var stats := catalog.level_stats(type, level)
				if int(stats.get("shield_hp", 0)) > 0:
					_shields.append(id)
				if type == "arc_tower":
					_arc_towers[id] = true
	field.walls.rebuild_cells(catalog, _walls)

	effects = BattleEffects.new()
	effects.setup(walls, area)
	effects.arrived = _on_arrived
	add_child(effects)
	for id: int in _shields:
		var range_cells := _stat(id, "range_cells")
		effects.add_shield(id, Vector3(_centres[id].x, 0.0, _centres[id].y), float(range_cells))
		effects.set_shield(id, sim.shield_hp(id), 0.0)

	var attacker: Dictionary = setup_data.get("attacker", {})
	var levels: Dictionary = attacker.get("unit_levels", {})
	for unit: String in units_brought():
		var level := clampi(BattleMath.whole(levels.get(unit, 1)), 1, catalog.unit_max_level(unit))
		_reach[unit] = int(catalog.unit_level_stats(unit, level).get("range_units", 0))
		_splash[unit] = catalog.unit_splash(unit) / 1000.0
	units = BattleUnits.new()
	units.setup(sim, catalog, attacker.get("army", {}), attacker.get("unit_levels", {}), grid, _centres, area)
	add_child(units)

	input = WorldInput.new()
	add_child(input)
	input.tapped.connect(_on_tapped)
	input.dragged.connect(func(at: Vector2, delta: Vector2) -> void: camera.pan(at, delta))
	input.pinched.connect(func(factor: float, at: Vector2) -> void: camera.zoom_at(factor, at))
	input.panned.connect(func(at: Vector2, delta: Vector2) -> void: camera.pan(at, delta))
	return ""


## The field's buildable area in world x and z, for the camera's bounds.
func area() -> Rect2:
	return field.area()


## Sends `cmd` to the sim at the current tick (BattleSim.command): "" or the refusal's code.
func command(cmd: Dictionary) -> String:
	var sent := cmd.duplicate()
	sent["tick"] = sim.tick
	return sim.command(sent)


## Deploys one `unit` on `cell` now: "" or the refusal's code.
func deploy(unit: String, cell: Vector2i) -> String:
	return command({"op": "deploy", "unit": unit, "cell": [cell.x, cell.y]})


## Ends the battle on this tick.
func surrender() -> String:
	return command({"op": "surrender"})


## Commands to send each at its own tick, as a player would at that moment (the harness's
## scripted attack): sorted by tick, sent through command() before the step of their tick.
func script_commands(commands: Array[Dictionary]) -> void:
	_script = commands.duplicate()
	_script.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["tick"]) < int(b["tick"]))
	_next_script = 0


## The sim's step time so far: (average, longest) in milliseconds.
func step_ms() -> Vector2:
	if _steps == 0:
		return Vector2.ZERO
	return Vector2(_step_usec / 1000.0 / _steps, _step_usec_max / 1000.0)


## The tick whose step took longest so far.
func slowest_tick() -> int:
	return _step_slowest


## Seconds of battle shown so far.
func clock() -> float:
	return _clock


func _process(delta: float) -> void:
	var shown := delta * speed
	_clock += shown
	if not sim.is_over():
		_accumulator += shown
		var steps := 0
		while _accumulator >= TICK_SECONDS and steps < MAX_STEPS_PER_FRAME and not sim.is_over():
			_step()
			_accumulator -= TICK_SECONDS
			steps += 1
		if steps == MAX_STEPS_PER_FRAME:
			_accumulator = minf(_accumulator, TICK_SECONDS)
		if steps > 0:
			stepped.emit()
	if sim.is_over() and _ended_at < 0.0:
		_ended_at = _clock
		_accumulator = TICK_SECONDS
	var alpha := clampf(_accumulator / TICK_SECONDS, 0.0, 1.0)
	effects.begin_bars()
	units.draw(alpha, _clock, shown, effects, camera.size >= BattleUnits.FAR_ZOOM)
	_draw_buildings(shown)
	effects.end_bars()
	effects.draw(_clock)
	if _walls_changed:
		_walls_changed = false
		field.walls.rebuild_cells(catalog, _walls)
	if _ended_at >= 0.0 and not _finished:
		_held += delta
		if _held >= END_HOLD_SECONDS:
			_finished = true
			finished.emit(battle_setup, sim.result())


func _step() -> void:
	while _next_script < _script.size() and int(_script[_next_script]["tick"]) <= sim.tick:
		var scripted := _script[_next_script]
		_next_script += 1
		if int(scripted["tick"]) == sim.tick:
			sim.command(scripted)
	var started := Time.get_ticks_usec()
	sim.step()
	var spent := Time.get_ticks_usec() - started
	_step_usec += spent
	if spent > _step_usec_max:
		_step_usec_max = spent
		_step_slowest = sim.tick - 1
	_steps += 1
	units.after_step()
	_read_events()
	for id: int in _shields:
		effects.set_shield(id, sim.shield_hp(id), _clock)


## The last tick's events (BattleEvents) turned into effects, flashes, falls and deaths.
func _read_events() -> void:
	var events := sim.events
	for i: int in events.count:
		var source := events.source[i]
		var target := events.target[i]
		match events.kind[i]:
			BattleEvents.UNIT_HIT:
				_unit_hit(source, target, events.from_x[i], events.from_y[i])
			BattleEvents.SHOT:
				var from := _muzzle(source)
				var to := units.aim_point(target)
				if _arc_towers.has(source):
					effects.lightning(from, to, _clock)
					effects.impact(to, 0.3, MaterialKit.ARC_BLUE, _clock)
					units.hit(target, _clock)
				else:
					effects.bolt(from, to, DEFENCE_SHOT, _clock, 0.0, 0.3, 0, target)
			BattleEvents.SHELL:
				var lands := _point(events.to_x[i], events.to_y[i])
				var seconds := (events.land_tick[i] - (sim.tick - 1)) * TICK_SECONDS
				effects.bolt(_muzzle(source), lands, SHELL_BLAST, _clock, maxf(seconds, TICK_SECONDS), 0.0)
			BattleEvents.SHELL_LAND:
				var splash := float(_stat(source, "splash_units")) / 1000.0
				effects.impact(_point(events.to_x[i], events.to_y[i]), maxf(splash, 0.6), SHELL_BLAST, _clock)
			BattleEvents.HOLD:
				effects.impact(_point(events.from_x[i], events.from_y[i]), float(_stat(source, "range_cells")) * 0.5,
					WELL_PULL, _clock)
			BattleEvents.DETONATE:
				var at := _point(events.from_x[i], events.from_y[i])
				effects.impact(at, maxf(1.0, float(_stat(source, "range_cells"))), MINE_BLAST, _clock)
				if _stat(source, "damage") > 0:
					effects.scorch(at, SCORCH_RADIUS * _sizes.get(source, 1))
			BattleEvents.THROW:
				units.throw_unit(target, Vector2i(events.from_x[i], events.from_y[i]), _clock)
			BattleEvents.REVEAL:
				if _views.has(source):
					_views[source].visible = true
					effects.impact(_point(events.from_x[i], events.from_y[i]), 1.0, DEFENCE_SHOT, _clock)
			BattleEvents.FALL:
				_fall(source)
			BattleEvents.DEATH:
				units.die(target, _clock)


## Unit `unit`, standing at the field point (x, y), hits `building`: a bolt from it, or a blow at
## the building for a short reach; a splash makes the impact as wide.
func _unit_hit(unit: int, building: int, x: int, y: int) -> void:
	var type := sim.unit_type(unit)
	var reach: int = _reach.get(type, 0)
	var splash: float = _splash.get(type, 0.0)
	var centre: Vector2 = _centres.get(building, Vector2.ZERO)
	var hit_at := Vector3(centre.x, HIT_HEIGHT, centre.y)
	if reach <= MELEE_REACH:
		var from := _ground(x, y)
		var side := from.lerp(centre, 0.45)
		effects.impact(Vector3(side.x, HIT_HEIGHT * 0.6, side.y), maxf(0.3, splash), UNIT_SHOT, _clock)
		_on_arrived(building, 0)
		return
	effects.bolt(units.aim_point(unit), hit_at, UNIT_SHOT, _clock, 0.0, maxf(0.3, splash), building, 0)


## A bolt reached `building` or `unit` (0 for none): it flashes, a building shakes and shows its bar.
func _on_arrived(building: int, unit: int) -> void:
	if unit != 0:
		units.hit(unit, _clock)
	if building != 0 and _views.has(building):
		_flash_until[building] = _clock + FLASH_SECONDS
		_shake_until[building] = _clock + SHAKE_SECONDS
		_bar_until[building] = _clock + BAR_SECONDS
		if not _bars.has(building):
			_bars[building] = 1.0


## Building `id` fell: a wall leaves the merged mesh for its strip, a trap is gone, any other
## building is replaced by its rubble with a burst of dust.
func _fall(id: int) -> void:
	var cell: Vector2i = _cells.get(id, Vector2i.ZERO)
	var size: int = _sizes.get(id, 1)
	var at := field.cell_to_world(cell, size)
	match catalog.battle_class(_types.get(id, "")):
		Catalog.CLASS_WALL:
			_walls.erase(cell)
			_walls_changed = true
			effects.wall_rubble(at)
			effects.impact(at + Vector3(0, 0.2, 0), 0.5, FALL_DUST, _clock)
			return
		Catalog.CLASS_TRAP:
			return
	if _views.has(id):
		_views[id].queue_free()
		_views.erase(id)
	_flash_until.erase(id)
	_shake_until.erase(id)
	_bar_until.erase(id)
	_bars.erase(id)
	var rubble := BuildingModels.create_rubble(size)
	rubble.position = at
	add_child(rubble)
	effects.impact(at + Vector3(0, 0.3, 0), size * 0.7, FALL_DUST, _clock)
	if _shields.has(id):
		effects.set_shield(id, 0, _clock)


## The flashes, shakes and bars of the buildings hit lately; `shown` seconds of battle after the
## last frame.
func _draw_buildings(shown: float) -> void:
	_done.clear()
	for id: int in _flash_until:
		var on := _clock < _flash_until[id]
		_views[id].set_flash(on)
		if not on:
			_done.append(id)
	for id: int in _done:
		_flash_until.erase(id)
	_done.clear()
	for id: int in _shake_until:
		var view := _views[id]
		var centre := _centres[id]
		if _clock < _shake_until[id]:
			view.position = Vector3(centre.x + SHAKE * sin(_clock * 97.0), 0.0, centre.y + SHAKE * cos(_clock * 83.0))
		else:
			view.position = Vector3(centre.x, 0.0, centre.y)
			_done.append(id)
	for id: int in _done:
		_shake_until.erase(id)
	_done.clear()
	var ease_bar := minf(1.0, BattleUnits.BAR_EASE * shown)
	for id: int in _bar_until:
		if _clock >= _bar_until[id]:
			_done.append(id)
			continue
		var left := float(sim.building_hp(id)) / maxf(1.0, float(sim.building_max_hp(id)))
		_bars[id] = lerpf(_bars[id], left, ease_bar)
		var centre := _centres[id]
		effects.bar(Vector3(centre.x, _muzzles[id] / MUZZLE_SHARE + BAR_OVER, centre.y), _bars[id], Hud.GOLD)
	for id: int in _done:
		_bar_until.erase(id)


## A tap on the field deploys one unit of `deploy_unit` (or the first type with units left) on the
## cell under it.
func _on_tapped(screen_pos: Vector2) -> void:
	var point: Variant = camera.ground_point(screen_pos)
	if typeof(point) != TYPE_VECTOR3:
		return
	var unit := deploy_unit
	if unit == "":
		for name: String in units_brought():
			if sim.left_to_deploy(name) > 0:
				unit = name
				break
	if unit != "":
		var ground: Vector3 = point
		deploy(unit, field.world_to_cell(ground))


## The unit types the attacker brought, in sorted order.
func units_brought() -> PackedStringArray:
	var names := PackedStringArray()
	var army: Dictionary = (battle_setup.get("attacker", {}) as Dictionary).get("army", {})
	for unit: String in army:
		if catalog.has_unit(unit) and int(army[unit]) > 0:
			names.append(unit)
	names.sort()
	return names


## Where a shot leaves building `id`.
func _muzzle(id: int) -> Vector3:
	var centre: Vector2 = _centres.get(id, Vector2.ZERO)
	return Vector3(centre.x, _muzzles.get(id, 1.0), centre.y)


## A field point's ground point in world x and z.
func _ground(x: int, y: int) -> Vector2:
	var grid := catalog.grid_size
	return Vector2(x / 1000.0 - grid.x * 0.5, y / 1000.0 - grid.y * 0.5)


## A field point on the ground, just over it.
func _point(x: int, y: int) -> Vector3:
	var at := _ground(x, y)
	return Vector3(at.x, 0.05, at.y)


## Building `id`'s `stat` at its level (0 when it has none).
func _stat(id: int, stat: String) -> int:
	return int(catalog.level_stats(_types.get(id, ""), _levels.get(id, 1)).get(stat, 0))
