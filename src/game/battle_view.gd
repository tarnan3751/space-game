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
## battle): a pinch or a two-finger pan moves the camera. With a unit type selected (select_unit,
## the attack HUD's deploy bar), the ground shows where it cannot go in red (the deploy mask, one
## texel a cell, BaseView.set_deploy_mask), a tap on the field deploys one there, and a drag deploys
## one on every cell it crosses, one a tick at most (Clash's smear); with none selected a drag pans.
## A refusal is told through `deploy_failed`, and a refusal for the zone flashes the red brighter.
## With an ability selected instead (select_ability, the abilities bar), the red zone hides, a tap
## casts it at the cell (anywhere on the field), a drag pans, and a refusal is told through
## `cast_failed`. The abilities' effects come from the sim's ABILITY and STRIKE_LAND events: a
## swarm's dome, an EMP's ring and the defences it disabled dimmed until they wake, a strike's
## marker until it lands and its blast and smoke.
##
## main.gd makes it, adds it in place of the base's view with its BattleHud, and frees both on
## `finished`, which leave() emits (the result panel's Return) with the setup and the sim's result;
## `ended` tells the HUD the battle is over.

signal finished(setup: Dictionary, result: Dictionary)
## The sim stepped (one or more ticks this frame): the attack HUD (series B's BattleHud) refreshes
## on it.
signal stepped
## The battle ended (BattleSim.is_over), with its result.
signal ended(result: Dictionary)
## A deploy was refused (BattleSim's code: blocked, none_left, battle_over).
signal deploy_failed(error: String)
## A cast was refused (BattleSim's code: blocked, none_left, battle_over).
signal cast_failed(error: String)

## Seconds of battle a tick is, and the most ticks one frame steps.
const TICK_SECONDS := 1.0 / BattleSim.TICKS_PER_SECOND
const MAX_STEPS_PER_FRAME := 4
## The speeds a player runs the view at, 1 and 2 times real time, which the attack HUD's speed
## button (series B's BattleHud) steps through. `speed` 0, which the harness sets while it
## measures, pauses it: no tick is stepped and the effects' clock stands still.
const SPEEDS: Array[int] = [1, 2]
## The deploy mask's strength while a type is selected, after a refusal for the zone, and how long
## that flash takes to fade back.
const MASK_STRENGTH := 0.32
const MASK_FLASH := 0.75
const MASK_FLASH_SECONDS := 0.5
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
## The abilities' tints: the swarm's dome, the EMP's ring, the strike's marker and its blast.
const SWARM_GLOW := MaterialKit.NANITE_GREEN
const EMP_RING := MaterialKit.ARC_BLUE
const STRIKE_MARKER := MaterialKit.DEFENCE
const STRIKE_BLAST := Color("ff6a3d")
const STRIKE_CORE := Color("fff6e0")
## A strike's blast lasts this long (the other impacts IMPACT_SECONDS).
const STRIKE_BLAST_SECONDS := 0.6

## The battle being run; read only.
var sim: BattleSim
## The setup it was made from.
var battle_setup: Dictionary = {}
var catalog: Catalog
## 1 or 2 (SPEEDS): ticks a 50 ms of real time; 0 pauses (the harness's measuring).
var speed: int = 1
## The unit type selected to deploy (select_unit); "" for none.
var deploy_unit: String = ""
## The ability selected to cast (select_ability); "" for none. One of this and deploy_unit at most.
var cast_ability: String = ""
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
## The defences an EMP burst has disabled, dimmed until the sim wakes them, and the ids done this
## step, reused.
var _disabled: Dictionary[int, bool] = {}
var _woken := PackedInt32Array()
## Arc towers, whose shots are lightning.
var _arc_towers: Dictionary[int, bool] = {}
## Per unit type brought: its reach at the attacker's level (field units) and its splash (world
## units).
var _reach: Dictionary[String, int] = {}
var _splash: Dictionary[String, float] = {}
## When the battle ended on the clock, -1 while it runs.
var _ended_at: float = -1.0
var _finished: bool = false
## The deploy mask, one texel a cell (255 where a unit cannot go), its texture, whether a fall
## changed it this frame, and when a refusal for the zone flashed it.
var _mask_image: Image
var _mask: ImageTexture
var _mask_changed: bool = false
var _mask_flash_at: float = -10.0
## A drag deploying (a smear): whether one is under way, the last cell it reached, and the cells
## it crossed still to deploy on, one a tick.
var _smearing: bool = false
var _smear_cell: Vector2i = Vector2i(-1, -1)
var _smear: Array[Vector2i] = []
## Every cell this drag has reached, so crossing one again deploys nothing more.
var _smear_seen: Dictionary[Vector2i, bool] = {}
## Buildings fallen so far, walls included: the HUD reads the loot again when it moves.
var _falls: int = 0
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
	input.drag_started.connect(_on_drag_started)
	input.dragged.connect(_on_dragged)
	input.drag_ended.connect(func(_at: Vector2) -> void: _smearing = false)
	input.pinched.connect(func(factor: float, at: Vector2) -> void: camera.zoom_at(factor, at))
	input.panned.connect(func(at: Vector2, delta: Vector2) -> void: camera.pan(at, delta))
	_mask_image = Image.create(grid.x, grid.y, false, Image.FORMAT_L8)
	_mask = ImageTexture.create_from_image(_mask_image)
	_update_mask()
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
		_smear.clear()
		select_unit("")
		select_ability("")
		ended.emit(sim.result())
	var alpha := clampf(_accumulator / TICK_SECONDS, 0.0, 1.0)
	effects.begin_bars()
	units.draw(alpha, _clock, shown, effects, camera.size >= BattleUnits.FAR_ZOOM)
	_draw_buildings(shown)
	effects.end_bars()
	effects.draw(_clock)
	if _walls_changed:
		_walls_changed = false
		field.walls.rebuild_cells(catalog, _walls)
	if _mask_changed:
		_mask_changed = false
		_update_mask()
	if deploy_unit != "":
		var flash := clampf(1.0 - (_clock - _mask_flash_at) / (MASK_FLASH_SECONDS * maxi(speed, 1)), 0.0, 1.0)
		field.set_deploy_mask(_mask, lerpf(MASK_STRENGTH, MASK_FLASH, flash))


## Selects the unit type a tap or a drag deploys, "" for none: the red zone shows while one is.
## Letting the type go ends a smear under way; the rest of that drag pans.
func select_unit(unit: String) -> void:
	deploy_unit = unit
	_smear.clear()
	if unit == "":
		_smearing = false
	else:
		cast_ability = ""
	field.set_deploy_mask(_mask, MASK_STRENGTH if unit != "" else 0.0)


## Selects the ability a tap casts, "" for none; it lets the unit type go, so the red zone hides
## (an ability may be cast anywhere on the field) and a drag pans.
func select_ability(ability: String) -> void:
	cast_ability = ability
	if ability != "":
		select_unit("")


## Casts one `ability` on `cell` now: "" or the refusal's code.
func cast(ability: String, cell: Vector2i) -> String:
	return command({"op": "ability", "ability": ability, "cell": [cell.x, cell.y]})


## Buildings fallen so far, walls included; it moves only when the loot can have.
func falls() -> int:
	return _falls


## Whether the cell is red in the deploy mask now (a unit cannot be deployed on it).
func is_masked(cell: Vector2i) -> bool:
	return _mask_image.get_pixel(cell.x, cell.y).r > 0.5


## Leaves the battle once it is over (the result panel's Return): `finished`, once.
func leave() -> void:
	if _finished or not sim.is_over():
		return
	_finished = true
	finished.emit(battle_setup, sim.result())


func _step() -> void:
	while _next_script < _script.size() and int(_script[_next_script]["tick"]) <= sim.tick:
		var scripted := _script[_next_script]
		_next_script += 1
		if int(scripted["tick"]) == sim.tick:
			sim.command(scripted)
	_deploy_smear()
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
	_wake_defences()


## The defences an EMP burst disabled whose time is up lose their grey.
func _wake_defences() -> void:
	if _disabled.is_empty():
		return
	_woken.clear()
	for id: int in _disabled:
		if sim.is_destroyed(id) or not sim.building_disabled(id):
			_woken.append(id)
	for id: int in _woken:
		_disabled.erase(id)
		if _views.has(id):
			_views[id].set_disabled(false)


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
				_mask_changed = true
			BattleEvents.DEATH:
				units.die(target, _clock)
			BattleEvents.ABILITY:
				_ability_used(source, events.to_x[i], events.to_y[i], events.land_tick[i])
			BattleEvents.STRIKE_LAND:
				var at := _point(events.to_x[i], events.to_y[i])
				var radius := _ability_radius(source)
				effects.strike_landed(at, radius, _under_strike(at, radius, true).x, _clock, STRIKE_BLAST_SECONDS, STRIKE_CORE,
					STRIKE_BLAST)


## An ability (its place in catalog.ability_types() plus one, `index`) used at the field point
## (x, y), its effect lasting to tick `until`: a swarm's dome; an EMP's ring and the defences it
## disabled dimmed; a strike's marker until it lands.
func _ability_used(index: int, x: int, y: int, until: int) -> void:
	var ability := catalog.ability_types()[index - 1]
	var at := _point(x, y)
	var radius := _ability_radius(index)
	var seconds := maxf(float(until - (sim.tick - 1)) * TICK_SECONDS, TICK_SECONDS)
	match catalog.ability_effect(ability):
		"swarm":
			effects.swarm(at, radius, _clock, seconds, SWARM_GLOW)
		"emp":
			effects.impact(at, radius, EMP_RING, _clock)
			for id: int in _views:
				if not _disabled.has(id) and sim.building_disabled(id):
					_disabled[id] = true
					_views[id].set_disabled(true)
		_:
			var under := _under_strike(at, radius)
			effects.strike_marker(at, radius, maxf(radius, under.y), under.x, _clock, seconds, STRIKE_MARKER)


## Under a strike at `at`, `radius` across: (the top of the tallest drawn standing building it
## reaches, a ground ring's radius that stands out round that building's footprint); (0, 0) on
## open ground. Read at the cast and at the landing, never a frame; at the landing (`landing`) the
## buildings it has just felled count, since their falls are read after it.
func _under_strike(at: Vector3, radius: float, landing: bool = false) -> Vector2:
	var under := Vector2.ZERO
	for id: int in _views:
		var centre := _centres[id]
		var half := _sizes[id] * 0.5
		if absf(centre.x - at.x) <= radius + half and absf(centre.y - at.z) <= radius + half \
				and (landing or not sim.is_destroyed(id)) and _views[id].visible:
			under.x = maxf(under.x, _muzzles[id] / MUZZLE_SHARE)
			under.y = maxf(under.y, half * 1.6)
	return under


## An ability's radius in world units, by its place in catalog.ability_types() plus one.
func _ability_radius(index: int) -> float:
	return catalog.ability_radius(catalog.ability_types()[index - 1]) / 1000.0


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
	_falls += 1
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


## A tap on the field deploys one unit of the selected type on the cell under it.
func _on_tapped(screen_pos: Vector2) -> void:
	var cell := _cell_at(screen_pos)
	if cell.x < 0:
		return
	if cast_ability != "":
		var refused := cast(cast_ability, cell)
		if refused != "":
			cast_failed.emit(refused)
		return
	if deploy_unit == "":
		return
	_report(deploy(deploy_unit, cell))


## A drag with a type selected deploys along its way (a smear), starting on the cell it was
## pressed on; with none selected it pans.
func _on_drag_started(screen_pos: Vector2) -> void:
	_smearing = deploy_unit != "" and not sim.is_over()
	_smear_seen.clear()
	if _smearing:
		_smear_cell = _cell_at(screen_pos)
		if _smear_cell.x >= 0:
			_smear.append(_smear_cell)
			_smear_seen[_smear_cell] = true


func _on_dragged(screen_pos: Vector2, delta: Vector2) -> void:
	if not _smearing:
		camera.pan(screen_pos, delta)
		return
	var cell := _cell_at(screen_pos)
	if cell.x < 0 or cell == _smear_cell:
		return
	# Every cell on the way from the last one, so a fast stroke leaves no gaps.
	var from := _smear_cell if _smear_cell.x >= 0 else cell
	var steps := maxi(absi(cell.x - from.x), absi(cell.y - from.y))
	for k: int in range(1, steps + 1):
		var on := Vector2i(roundi(lerpf(from.x, cell.x, float(k) / steps)), roundi(lerpf(from.y, cell.y, float(k) / steps)))
		if not _smear_seen.has(on):
			_smear_seen[on] = true
			_smear.append(on)
	_smear_cell = cell


## Before a step: one unit on the first cell of the smear that takes one; cells refused for the
## zone are skipped, and running out of the type ends the smear (the rest of the drag pans).
func _deploy_smear() -> void:
	while not _smear.is_empty():
		var cell: Vector2i = _smear.pop_front()
		var error := deploy(deploy_unit, cell)
		if error == "":
			return
		if error != BattleSim.ERR_BLOCKED:
			_smear.clear()
			_smearing = false
			_report(error)
			return


## A refused deploy: told through deploy_failed; one refused for the zone flashes the red brighter.
func _report(error: String) -> void:
	if error == "":
		return
	if error == BattleSim.ERR_BLOCKED:
		_mask_flash_at = _clock
	deploy_failed.emit(error)


## The field cell under a screen point; (-1, -1) off the ground.
func _cell_at(screen_pos: Vector2) -> Vector2i:
	var point: Variant = camera.ground_point(screen_pos)
	if typeof(point) != TYPE_VECTOR3:
		return Vector2i(-1, -1)
	var ground: Vector3 = point
	return field.world_to_cell(ground)


## Rewrites the deploy mask from the sim: 255 on every cell a unit cannot be deployed on.
func _update_mask() -> void:
	var grid := catalog.grid_size
	for y: int in grid.y:
		for x: int in grid.x:
			_mask_image.set_pixel(x, y, Color.BLACK if sim.is_deploy_cell(Vector2i(x, y)) else Color.WHITE)
	_mask.update(_mask_image)


## The abilities the attacker brought (above 0), in the catalog's order.
func abilities_brought() -> PackedStringArray:
	var names := PackedStringArray()
	var stock: Dictionary = (battle_setup.get("attacker", {}) as Dictionary).get("abilities", {})
	for ability: String in catalog.ability_types():
		if BattleMath.whole(stock.get(ability, 0)) > 0:
			names.append(ability)
	return names


## Building `id`'s type, "" for none.
func building_type(id: int) -> String:
	return _types.get(id, "")


## Building `id`'s centre on the ground (world).
func building_centre(id: int) -> Vector3:
	var centre: Vector2 = _centres.get(id, Vector2.ZERO)
	return Vector3(centre.x, 0.0, centre.y)


## Whether building `id` is a drawn defence the attacker can see: a defence, not hidden now.
func is_revealed_defence(id: int) -> bool:
	return _views.has(id) and sim.is_revealed(id) and catalog.battle_class(_types[id]) == Catalog.CLASS_DEFENSE


## Whether building `id` shows as disabled now (an EMP burst).
func is_shown_disabled(id: int) -> bool:
	return _views.has(id) and _views[id].is_disabled()


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
