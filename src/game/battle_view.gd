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
## (BattleEffects, each kind one MultiMesh). A defence whose head carries a muzzle socket (every
## defence with a direction: the laser turret, missile battery, plasma mortar, flak cannon, cloaked
## sentry, railgun, ion beam and orbital cannon) turns it towards its target
## (BattleSim.building_target) at its type's AIM_TURN rate, pitching its barrels at the unit's
## drawn height (PITCH_LIMITS) or, a lobbing gun, by its range (LOB_ELEVATION), and goes back to its
## idle scan a while after its target is gone (BuildingView.aim_at, idle_aim); its shots leave its muzzle sockets in
## turn (its weapon record's, MUZZLES for most), each kicking the head back (BuildingView.fired) and
## held (the sim's hit is instant; the shot is the view's) until the head faces its target within
## AIM_READY, AIM_HOLD at most, so a shot never leaves a barrel turned away. A defence with its
## muzzle socket on its body (the arc tower, the EMP tower, the gravity well) fires from it without
## aiming; any other defence's shots leave its centre, MUZZLE_SHARE of its height up. While an EMP
## burst has a defence disabled its moving parts hold their pose, and they snap back to the clock
## when it wakes (_woke), in a flash of energy. Every shot, shell, hit, spring and death is drawn by
## the weapon record of the type that made it (Weapons, BattleEffects.fire and land). A hit whitens
## a building for a moment and shakes it; a fallen building collapses (it sinks, tilts and shakes in
## dust) and is replaced by its rubble (BuildingModels.create_rubble), popping up with debris and a
## smoke column; a fallen wall leaves the merged mesh for a low strip with chunks and dust. A hidden
## sentry shows once revealed, fading in over REVEAL_SECONDS (BuildingView.set_reveal) in a
## shimmer; a trap stays hidden (a view of its own made at setup) until it springs, when it pops up
## and goes off. A shield generator's pool is a faint dome while it is up. The camera is the base's IsoCamera, free over the field. An
## expedition's battle (`rival`) draws the defender as a rival colony: its buildings and walls take
## the faction tint (MaterialKit.rival), the units and the rubble never do.
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
## How long a revealed defence takes to fade in (BuildingView.set_reveal).
const REVEAL_SECONDS := 0.3
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
## How far from a building's centre towards the unit its hits land, a share of its footprint.
const HIT_FACE := 0.48
## The muzzle sockets a defence's shots leave in turn, as many as its model has (its weapon
## record's, Weapons).
const MUZZLES: Array[String] = Weapons.DEFENCE_MUZZLES
## How fast an aiming head turns towards its target (the share of the way a second, as an
## exponential rate) per type, and for any other type; how fast it goes back to its idle swing.
## Fast for the light guns, slower for the heavy ones.
const AIM_TURN := {
	"laser_turret": 10.0, "cloaked_sentry": 10.0, "flak_cannon": 6.0, "railgun": 5.0, "ion_beam": 5.0,
	"missile_battery": 3.0, "plasma_mortar": 2.0, "orbital_cannon": 1.5,
}
const AIM_TURN_DEFAULT := 4.0
const AIM_RETURN := 3.0
## How far a direct-fire defence's barrels pitch (BuildingView.can_pitch), per type: the lowest and
## the highest elevation they reach, degrees over level; they aim at the target's drawn middle
## (BattleUnits.aim_point, an aircraft's height and a hovering machine's lift in it).
const PITCH_LIMITS := {
	"laser_turret": Vector2(-15, 45), "flak_cannon": Vector2(0, 75), "cloaked_sentry": Vector2(-15, 45),
	"missile_battery": Vector2(0, 60), "railgun": Vector2(0, 20), "ion_beam": Vector2(-15, 45),
}
## A lobbing defence's elevation by its target's range, per type: degrees at its full range and at
## its foot, straight between; and how fast it gets there (as AIM_TURN).
const LOB_ELEVATION := {"orbital_cannon": Vector2(20, 70), "plasma_mortar": Vector2(45, 70)}
## The share of a lobbing gun's range its far elevation is reached at, per type (1 for any other):
## the orbital cannon's 50 cells reach past the field's farthest unit (about 34 cells), so its whole
## span is spread over 0.7 of them.
const LOB_REACH := {"orbital_cannon": 0.7}
const LOB_TURN := 1.5
## How close (radians) an aiming head must face its target before its held shot leaves, and the
## longest a shot is held (seconds of battle).
const AIM_READY := 0.12
const AIM_HOLD := 0.4
## A wreck's fireball, its share of the way through the death, and the socket a death's effects
## follow.
const WRECK_BLAST := 0.3
const DEATH_SOCKET := "muzzle"
## A punch: how long after the blow it lands at the fist, its ring's size against the record's
## impact size, its white flash's.
const PUNCH_DELAY := 0.06
const PUNCH_RING := 1.5
const PUNCH_FLASH := 0.3
## The effects' tints and sizes: the laser turret's shots and the ranger's (the rig scenario tells
## them apart by these), the impact a defence's shot makes on a unit at least, a mine's blast, a
## gravity well's pull, a fall's dust.
const DEFENCE_SHOT := MaterialKit.DEFENCE
const UNIT_SHOT := MaterialKit.ENERGY
const DEFENCE_IMPACT := 0.3
const MINE_BLAST := MaterialKit.HAZARD
const WELL_PULL := MaterialKit.ANTIMATTER
const FALL_DUST := Color("c9c2e0")
## A falling building's collapse: how long it takes, how far it sinks (a share of its height) and
## tilts (degrees); its rubble's pop from a share of its size, how long that takes, and how long its
## smoke column rises.
const COLLAPSE_SECONDS := 0.35
const COLLAPSE_SINK := 0.6
const COLLAPSE_TILT := 12.0
const RUBBLE_FROM := 0.6
const RUBBLE_POP := 0.15
const SMOKE_COLUMN_SECONDS := 4.0
## A stunned unit's crackle, its size.
const STUN_SIZE := 0.4
## A crashing aircraft's smoke trail: a puff this often, this big, from the first of these sockets
## its model has (its middle with none).
const CRASH_STEP := 0.06
const CRASH_PUFF := 0.18
const CRASH_SOCKETS: Array[String] = ["exhaust", "muzzle"]
## A sprung trap: how long its model takes to pop up before it goes off, how long a grav trap's
## funnel spins and how fast, and how long it takes to sink away after.
const TRAP_POP := 0.15
const FUNNEL_SECONDS := 0.6
const FUNNEL_SPIN := 14.0
const FUNNEL_SINK := 0.2
## A camera shake's strength (world units) and length for a mega mine.
const QUAKE := 0.18
const QUAKE_SECONDS := 0.45
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
## Set before setup: the defender is a rival colony (an expedition), its buildings and walls
## tinted.
var rival: bool = false
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
## The drawn defences with an aiming head, and per defence with muzzle sockets the next one a shot
## leaves.
var _aimers := PackedInt32Array()
var _next_muzzle: Dictionary[int, int] = {}
## Per aiming defence with a shot held until its head faces its target: the unit, and when it fired.
var _held_shots: Dictionary[int, int] = {}
var _held_since: Dictionary[int, float] = {}
## The standing walls' levels by cell, rebuilt into the merged mesh at the end of a frame they fell in.
var _walls: Dictionary[Vector2i, int] = {}
var _walls_changed: bool = false
## Per building hit lately: when its flash and its shake end, until when its bar shows, its bar's
## fill; and the ids done this frame, reused.
var _flash_until: Dictionary[int, float] = {}
var _shake_until: Dictionary[int, float] = {}
var _bar_until: Dictionary[int, float] = {}
var _bars: Dictionary[int, float] = {}
## Per hidden defence revealed lately, when it was: it fades in over REVEAL_SECONDS.
var _reveal_at: Dictionary[int, float] = {}
var _done := PackedInt32Array()
## The shield generators.
var _shields := PackedInt32Array()
## The defences an EMP burst has disabled, dimmed until the sim wakes them, and the ids done this
## step, reused.
var _disabled: Dictionary[int, bool] = {}
var _woken := PackedInt32Array()
## The buildings collapsing (their views, out of _views) and when each fell; the rubble popping up
## and when each began.
var _collapsing: Dictionary[int, BuildingView] = {}
var _collapse_at: Dictionary[int, float] = {}
var _rubble_pop: Dictionary[int, Node3D] = {}
var _rubble_at: Dictionary[int, float] = {}
## The crashing aircraft: when each comes to rest, and when it leaves its next puff.
var _crashing: Dictionary[int, float] = {}
var _crash_puff: Dictionary[int, float] = {}
## The traps, each a hidden view shown while it springs, and when each sprang.
var _traps: Dictionary[int, BuildingView] = {}
var _sprung: Dictionary[int, float] = {}
## The camera shake: its strength and when it started and ends (-1: none).
var _quake: float = 0.0
var _quake_from: float = 0.0
var _quake_until: float = -1.0
## Each building's weapon record (Weapons), traps' included.
var _weapons: Dictionary[int, Weapons.Weapon] = {}
## The dying units with a death's effects to draw, and when each died; the wrecks whose fireball
## is drawn.
var _dying: Dictionary[int, float] = {}
var _wrecked: Dictionary[int, bool] = {}
## The punches still to land, at which building, and when.
var _blows: Dictionary[int, int] = {}
var _blow_at: Dictionary[int, float] = {}
## Units found in a defence's reach (_in_reach), reused.
var _found := PackedInt32Array()
## Per unit type brought: its splash (world units).
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
		_weapons[id] = Weapons.of(type)
		var centre := field.cell_to_world(cell, size)
		_centres[id] = Vector2(centre.x, centre.z)
		match catalog.battle_class(type):
			Catalog.CLASS_WALL:
				_walls[cell] = level
				walls += 1
			Catalog.CLASS_TRAP:
				# Hidden until it springs; made now so its meshes are built before the battle.
				var trap := BuildingView.new()
				trap.setup(id, type, level, size, BuildingModels.tier_of(catalog, type, level))
				trap.position = centre
				trap.visible = false
				if rival:
					trap.set_rival(true)
				root.add_child(trap)
				_traps[id] = trap
			_:
				var view := BuildingView.new()
				view.setup(id, type, level, size, BuildingModels.tier_of(catalog, type, level))
				view.position = centre
				root.add_child(view)
				view.visible = sim.is_revealed(id)
				if rival:
					view.set_rival(true)
				_views[id] = view
				_muzzles[id] = maxf(0.6, view.site_height() * MUZZLE_SHARE)
				if view.can_aim():
					_aimers.append(id)
				var stats := catalog.level_stats(type, level)
				if int(stats.get("shield_hp", 0)) > 0:
					_shields.append(id)
	field.walls.rebuild_cells(catalog, _walls)
	if rival:
		# The override, not a surface's: the merged mesh is replaced each time a wall falls.
		field.walls.body.material_override = MaterialKit.rival()

	effects = BattleEffects.new()
	effects.setup(walls, area)
	effects.arrived = _on_arrived
	add_child(effects)
	for id: int in _shields:
		var range_cells := _stat(id, "range_cells")
		effects.add_shield(id, Vector3(_centres[id].x, 0.0, _centres[id].y), float(range_cells))
		effects.set_shield(id, sim.shield_hp(id), 0.0)

	var attacker: Dictionary = setup_data.get("attacker", {})
	for unit: String in units_brought():
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
	_land_blows()
	_trail_crashes()
	_finish_deaths()
	_aim_defences(shown)
	_draw_buildings(shown)
	_draw_traps()
	_draw_collapses()
	_shake_camera()
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


## The camera is the base's: a shake still on leaves no offset behind.
func _exit_tree() -> void:
	if camera != null:
		camera.h_offset = 0.0
		camera.v_offset = 0.0


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


## The defences an EMP burst disabled whose time is up wake (_woke).
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
			_woke(id)


## Drawn defence `id` wakes from an EMP burst: it loses its grey and its moving parts snap back to
## the clock (BuildingView.set_disabled), with a flash of energy over it, a ring and a glow.
func _woke(id: int) -> void:
	_views[id].set_disabled(false)
	var centre := _centres[id]
	var top := Vector3(centre.x, _muzzles[id], centre.y)
	var size := 0.4 + 0.2 * _sizes[id]
	effects.flash(top, size, MaterialKit.ENERGY, _clock)
	effects.ring_flash(top, size * 1.4, MaterialKit.ENERGY, _clock, 0.3)
	effects.glow(Vector3(centre.x, 0.0, centre.y), size * 1.5, MaterialKit.ENERGY, _clock, 0.4)


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
				if _aimers.has(source):
					if _held_shots.has(source):
						_release_shot(source)
					_held_shots[source] = target
					_held_since[source] = _clock
				else:
					_fire_defence(source, target)
			BattleEvents.SHELL:
				var lands := _point(events.to_x[i], events.to_y[i])
				var seconds := (events.land_tick[i] - (sim.tick - 1)) * TICK_SECONDS
				effects.fire(_weapons[source], _muzzle(source), lands, 0, 0, 0.0, _clock, true,
					maxf(seconds, TICK_SECONDS))
			BattleEvents.SHELL_LAND:
				var splash := float(_stat(source, "splash_units")) / 1000.0
				effects.land(_weapons[source], _point(events.to_x[i], events.to_y[i]), maxf(splash, 0.6), _clock)
			BattleEvents.HOLD:
				_hold(source, _point(events.from_x[i], events.from_y[i]))
			BattleEvents.DETONATE:
				_spring(source, _point(events.from_x[i], events.from_y[i]))
			BattleEvents.THROW:
				units.throw_unit(target, Vector2i(events.from_x[i], events.from_y[i]), _clock)
			BattleEvents.REVEAL:
				if _views.has(source):
					_views[source].visible = true
					_reveal(source)
					_decloak(source)
			BattleEvents.FALL:
				_fall(source)
				_mask_changed = true
			BattleEvents.DEATH:
				units.die(target, _clock)
				_death(target)
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


## Unit `unit`, standing at the field point (x, y), hits `building`: by its weapon record, a blow
## at the building's side (a brawler's punch: a ring, sparks and dust, the building shaken), the
## breacher's charge going off there, or its shot (BattleUnits.shoot, its record's projectile from
## its next socket); a splash makes the impact as wide.
func _unit_hit(unit: int, building: int, x: int, y: int) -> void:
	var type := sim.unit_type(unit)
	var weapon := Weapons.of(type)
	var splash: float = _splash.get(type, 0.0)
	var centre: Vector2 = _centres.get(building, Vector2.ZERO)
	var from := _ground(x, y)
	# Its near face, not its middle, so the impact shows outside it; a bomb on the side under it.
	var near := centre + (from - centre).limit_length(_sizes.get(building, 1) * HIT_FACE)
	var hit_at := Vector3(near.x, HIT_HEIGHT, near.y)
	if weapon.kind == Weapons.Kind.BOMB:
		hit_at.y = HIT_HEIGHT * 0.5
	match weapon.kind:
		Weapons.Kind.MELEE:
			# Drawn at the fist as the punch lands (_land_blows), a moment after the blow.
			_blows[unit] = building
			_blow_at[unit] = _clock + PUNCH_DELAY
		Weapons.Kind.CHARGE:
			var size := maxf(weapon.impact_size, splash)
			var side := near + (from - near).normalized() * BattleEffects.stand_off(weapon, size)
			var at := Vector3(side.x, 0.3, side.y)
			effects.land(weapon, at, size, _clock)
			effects.debris(at, 4, 0.5, 0.1, _clock, MaterialKit.WALL, MaterialKit.HULL_DARK)
			_on_arrived(building, 0)
		_:
			units.shoot(unit, hit_at, building, maxf(0.3, splash), _clock)


## The punches due by now: each at the fist that throws it (the brawler's `muzzle`, or `muzzle_2`
## on an odd blow, by its drawn state's parity, BattleUnits.socket_point): a ring PUNCH_RING times
## its record's impact size, sparks, a short white flash and dust at its feet; the building shakes.
func _land_blows() -> void:
	if _blow_at.is_empty():
		return
	_done.clear()
	for unit: int in _blow_at:
		if _clock < _blow_at[unit]:
			continue
		_done.append(unit)
		var weapon := Weapons.of(sim.unit_type(unit))
		var fist := units.socket_point(unit, "muzzle_2" if units.drawn_state(unit).r >= 2.0 else "muzzle")
		effects.impact(fist, weapon.impact_size * PUNCH_RING, weapon.color, _clock)
		effects.sparks(fist, weapon.impact_size * PUNCH_RING, weapon.color.lerp(Color.WHITE, 0.5), _clock)
		effects.flash(fist, PUNCH_FLASH, Color.WHITE, _clock)
		effects.puff(Vector3(fist.x, 0.1, fist.z), 0.2, Weapons.DUST, _clock, 0.6, 0.3)
		_on_arrived(_blows[unit], 0)
	for unit: int in _done:
		_blow_at.erase(unit)
		_blows.erase(unit)


## Unit `unit` died: by its weapon record's death, past the body's own fall (BattleUnits, over
## its death_seconds): a wreck's fireball as it rolls, smoke and a scorch left; a crash's smoke
## trailing from it as it spirals down (_trail_crashes) and its blast where it comes to rest; a
## small blast at the end; a figure nothing more.
func _death(unit: int) -> void:
	var weapon := Weapons.of(sim.unit_type(unit))
	if weapon.death == Weapons.Death.NONE:
		return
	_dying[unit] = _clock
	if weapon.death == Weapons.Death.CRASH:
		_crashing[unit] = _clock + units.death_seconds(unit)


## The dying units' effects, where each is drawn now (its `muzzle` socket as drawn,
## BattleUnits.socket_point, which turns with the body as it rolls or spirals; once its fall is
## over, where the fall left it), at the height of its model's middle as built
## (BattleUnits.rest_point, without an aircraft's flight lift), which sizes them too: a wreck's
## fireball and glow WRECK_BLAST of the way through its death, then at its end a scorch where it
## came to rest and dark smoke; a crash's blast, glow and scorch where it comes to rest; a small
## blast at the end of the rest.
func _finish_deaths() -> void:
	if _dying.is_empty():
		return
	_done.clear()
	for unit: int in _dying:
		var weapon := Weapons.of(sim.unit_type(unit))
		var seconds := units.death_seconds(unit)
		var since := _clock - _dying[unit]
		var middle := units.rest_point(unit)
		var at := units.socket_point(unit, DEATH_SOCKET)
		at.y = middle.y
		var ground := Vector3(at.x, 0.0, at.z)
		var size := clampf(middle.y * 1.4, 0.45, 1.4)
		if weapon.death == Weapons.Death.WRECK and since >= seconds * WRECK_BLAST and not _wrecked.has(unit):
			_wrecked[unit] = true
			effects.blast(at, size, 0, _clock)
			effects.glow(ground, size * 1.2, Weapons.BLAST_RIM, _clock, 0.4)
		if since < seconds:
			continue
		_done.append(unit)
		match weapon.death:
			Weapons.Death.WRECK:
				effects.scorch(ground, size * 0.5)
				for k: int in 3:
					effects.puff(ground + Parts.around(size * 0.2, 120.0 * k, 0.3), size * 0.3, Weapons.DARK_SMOKE,
						_clock + 0.2 * k, 1.5, 1.0)
			Weapons.Death.CRASH:
				effects.blast(ground + Vector3.UP * 0.2, size, 1, _clock, true)
				effects.glow(ground, size * 1.4, Weapons.BLAST_RIM, _clock, 0.4)
			Weapons.Death.BLAST:
				effects.blast(at, size * 0.6, 0, _clock)
	for unit: int in _done:
		_dying.erase(unit)
		_wrecked.erase(unit)


## The crashing aircraft: a puff of smoke from each, where it is drawn now (its `exhaust` socket as
## last drawn, else its `muzzle`, else its middle: BattleUnits.socket_point, so the trail follows
## its spiral down), every CRASH_STEP, until it comes to rest.
func _trail_crashes() -> void:
	if _crashing.is_empty():
		return
	_done.clear()
	for unit: int in _crashing:
		if _clock >= _crashing[unit]:
			_done.append(unit)
			continue
		if _clock >= _crash_puff.get(unit, 0.0):
			_crash_puff[unit] = _clock + CRASH_STEP
			effects.puff(units.socket_point(unit, _crash_socket(unit)), CRASH_PUFF, Weapons.SMOKE, _clock, 0.9, 0.3)
	for unit: int in _done:
		_crashing.erase(unit)
		_crash_puff.erase(unit)


## The first of CRASH_SOCKETS unit `unit`'s model has, or the last (socket_point gives its middle
## for one it lacks).
func _crash_socket(unit: int) -> String:
	for name: String in CRASH_SOCKETS:
		if units.has_socket(unit, name):
			return name
	return CRASH_SOCKETS[-1]


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


## Building `id` fell: a wall leaves the merged mesh for its strip with chunks and dust, a trap is
## gone, any other building collapses (COLLAPSE_SECONDS: it sinks, tilts and shakes in a ring of
## dust, _draw_collapses) and is then replaced by its rubble, popping up with debris thrown out and a
## column of smoke.
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
			effects.debris(at + Vector3(0, 0.3, 0), 3, 0.3, 0.1, _clock, MaterialKit.WALL, MaterialKit.HULL_DARK)
			for k: int in 2:
				effects.puff(at + Parts.around(0.25, 180.0 * k + 45.0, 0.1), 0.25, Weapons.DUST, _clock, 0.8, 0.4)
			return
		Catalog.CLASS_TRAP:
			return
	if _held_shots.has(id):
		_release_shot(id)
	if _views.has(id):
		_collapsing[id] = _views[id]
		_collapse_at[id] = _clock
		_views.erase(id)
	_reveal_at.erase(id)
	_flash_until.erase(id)
	_shake_until.erase(id)
	_bar_until.erase(id)
	_bars.erase(id)
	effects.impact(at + Vector3(0, 0.1, 0), size * 0.75, FALL_DUST, _clock, COLLAPSE_SECONDS + 0.2)
	for k: int in 4 + size:
		effects.puff(at + Parts.around(size * 0.45, 360.0 * k / (4 + size), 0.1), 0.2 + 0.08 * size, Weapons.DUST,
			_clock + 0.04 * k, 0.9, 0.35)
	if _shields.has(id):
		effects.set_shield(id, 0, _clock)


## The collapsing buildings: each sinks COLLAPSE_SINK of its height and tilts COLLAPSE_TILT about a
## level axis of its own (from its id) while it shakes, over COLLAPSE_SECONDS; then its view is
## freed and its rubble (BuildingModels.create_rubble) pops up from RUBBLE_FROM of its size over
## RUBBLE_POP, with debris thrown out and its smoke column (BattleEffects.smoke_column).
func _draw_collapses() -> void:
	if not _collapsing.is_empty():
		_done.clear()
		for id: int in _collapsing:
			var view := _collapsing[id]
			var centre := _centres[id]
			var t := clampf((_clock - _collapse_at[id]) / COLLAPSE_SECONDS, 0.0, 1.0)
			if t >= 1.0:
				_done.append(id)
				continue
			var height: float = _muzzles.get(id, 1.0) / MUZZLE_SHARE
			var shake := SHAKE * 1.5 * (1.0 - t)
			view.position = Vector3(centre.x + shake * sin(_clock * 97.0), -COLLAPSE_SINK * height * t * t,
				centre.y + shake * cos(_clock * 83.0))
			var axis := Vector3(cos(id * 2.4), 0.0, sin(id * 2.4))
			view.basis = Basis(axis, deg_to_rad(COLLAPSE_TILT) * t * t)
		for id: int in _done:
			_settle(id)
	if not _rubble_pop.is_empty():
		_done.clear()
		for id: int in _rubble_pop:
			var t := clampf((_clock - _rubble_at[id]) / RUBBLE_POP, 0.0, 1.0)
			var size := lerpf(RUBBLE_FROM, 1.0, t) + 0.12 * sin(PI * t)
			_rubble_pop[id].scale = Vector3.ONE * size
			if t >= 1.0:
				_rubble_pop[id].scale = Vector3.ONE
				_done.append(id)
		for id: int in _done:
			_rubble_pop.erase(id)
			_rubble_at.erase(id)


## Collapsing building `id` is down: its view goes, its rubble pops up in its place with debris
## thrown out and a column of smoke.
func _settle(id: int) -> void:
	_collapsing[id].queue_free()
	_collapsing.erase(id)
	_collapse_at.erase(id)
	var size: int = _sizes.get(id, 1)
	var at := field.cell_to_world(_cells.get(id, Vector2i.ZERO), size)
	var rubble := BuildingModels.create_rubble(size)
	rubble.position = at
	rubble.scale = Vector3.ONE * RUBBLE_FROM
	add_child(rubble)
	_rubble_pop[id] = rubble
	_rubble_at[id] = _clock
	effects.debris(at + Vector3.UP * 0.3, mini(4 + size, 6), 0.35 * size, 0.1 + 0.03 * size, _clock,
		MaterialKit.HULL_DARK, MaterialKit.ARMY)
	effects.impact(at + Vector3(0, 0.1, 0), size * 0.6, FALL_DUST, _clock)
	effects.smoke_column(at, 0.3 + 0.1 * size, _clock, SMOKE_COLUMN_SECONDS)


## Trap `id` sprang at `at`: its model pops up out of the ground (TRAP_POP), then goes off by its
## weapon record: a mine's blast with its ring, scorch and debris (a mega mine's bigger, shaking the
## camera), a flak mine's flash up to each air unit over it bursting there, a grav trap's funnel
## spinning in a violet ring as it throws.
func _spring(id: int, at: Vector3) -> void:
	var weapon := _weapons[id]
	var reach := float(_stat(id, "range_cells"))
	var goes := _clock + TRAP_POP
	if _traps.has(id):
		_traps[id].visible = true
		_traps[id].scale = Vector3.ONE * 0.01
		_sprung[id] = _clock
	effects.glow(at, maxf(weapon.light, reach * 0.6), weapon.color, goes, 0.4)
	match weapon.kind:
		Weapons.Kind.MINE:
			effects.impact(at, maxf(1.0, reach), MINE_BLAST, goes)
			effects.land(weapon, at + Vector3.UP * 0.25, weapon.impact_size, goes)
			effects.scorch(at, weapon.impact_size * 0.45, goes)
			effects.debris(at + Vector3.UP * 0.15, 4, 0.6, 0.1, goes, MaterialKit.HULL_DARK, MaterialKit.HAZARD)
		Weapons.Kind.MEGA_MINE:
			effects.impact(at, maxf(1.0, reach), MINE_BLAST, goes)
			effects.land(weapon, at + Vector3.UP * 0.35, weapon.impact_size, goes)
			effects.debris(at + Vector3.UP * 0.2, 6, 0.9, 0.14, goes, MaterialKit.HULL_DARK, MaterialKit.HAZARD)
			_quake = QUAKE
			_quake_from = goes
			_quake_until = goes + QUAKE_SECONDS
		Weapons.Kind.FLAK_MINE:
			effects.impact(at, maxf(1.0, reach), weapon.color, goes)
			effects.flash(at + Vector3.UP * 0.3, 0.5, weapon.color, goes)
			for unit: int in _in_reach(id, reach):
				var over := units.aim_point(unit)
				effects.beam(at + Vector3.UP * 0.2, over, weapon.width, weapon.color, goes, 0.18, 2.0)
				effects.land(weapon, over, weapon.impact_size, goes + 0.05)
		Weapons.Kind.GRAV_TRAP:
			effects.impact(at, maxf(1.0, reach), MINE_BLAST, goes)
			effects.impact(at + Vector3.UP * 0.05, weapon.impact_size, weapon.color, _clock, FUNNEL_SECONDS)
			effects.ring_flash(at + Vector3.UP * 0.4, 0.8, weapon.color, goes, 0.35)


## The sprung traps' models: popping up over TRAP_POP and gone as their blast covers them; a grav
## trap's funnel spinning for FUNNEL_SECONDS, then sinking away.
func _draw_traps() -> void:
	if _sprung.is_empty():
		return
	_done.clear()
	for id: int in _sprung:
		var view := _traps[id]
		var t := _clock - _sprung[id]
		var funnel := _weapons[id].kind == Weapons.Kind.GRAV_TRAP
		var ends := TRAP_POP + (FUNNEL_SECONDS + FUNNEL_SINK if funnel else 0.05)
		if t >= ends:
			view.visible = false
			_done.append(id)
			continue
		var up := clampf(t / (TRAP_POP * 0.6), 0.0, 1.0)
		var size := up * (1.0 + 0.2 * sin(PI * clampf(t / TRAP_POP, 0.0, 1.0)))
		if funnel:
			size *= clampf((ends - t) / FUNNEL_SINK, 0.0, 1.0)
			view.rotation.y = FUNNEL_SPIN * maxf(t - TRAP_POP * 0.5, 0.0)
		var centre := _centres[id]
		view.position = Vector3(centre.x, 0.12 * sin(PI * clampf(t / TRAP_POP, 0.0, 1.0)), centre.y)
		view.scale = Vector3.ONE * maxf(size, 0.01)
	for id: int in _done:
		_sprung.erase(id)


## Shakes the camera (its offsets) while a quake is on, easing out to exactly none at its end.
func _shake_camera() -> void:
	if _quake_until < 0.0:
		return
	if _clock >= _quake_until:
		_quake_until = -1.0
		camera.h_offset = 0.0
		camera.v_offset = 0.0
		return
	var left := clampf((_quake_until - _clock) / (_quake_until - _quake_from), 0.0, 1.0) if _clock >= _quake_from else 0.0
	camera.h_offset = _quake * left * sin(_clock * 91.0)
	camera.v_offset = _quake * left * cos(_clock * 77.0)


## Turns each aiming head towards its defence's target, `shown` seconds of battle after the last
## frame: held while the defence is disabled, back to its idle swing a while after it has none.
func _aim_defences(shown: float) -> void:
	for id: int in _aimers:
		if not _views.has(id):
			continue
		var view := _views[id]
		if not sim.building_disabled(id):
			var target := sim.building_target(id)
			if target != 0 and sim.unit_state(target) != BattleArmy.DEAD:
				var point := units.aim_point(target)
				var turn := float(AIM_TURN.get(_types[id], AIM_TURN_DEFAULT))
				var lobs := LOB_ELEVATION.has(_types[id])
				view.aim_at(point, _elevation(id, view, point), _clock, shown, turn, LOB_TURN if lobs else turn)
			else:
				view.idle_aim(_clock, shown, AIM_RETURN)
		if _held_shots.has(id) and (view.aim_error(units.aim_point(_held_shots[id])) <= AIM_READY
				or _clock - _held_since[id] >= AIM_HOLD or sim.building_disabled(id)):
			_release_shot(id)


## The elevation (radians over level) defence `id`'s barrels want for the world point `point`: a
## lobbing gun's by its range (LOB_ELEVATION), a direct-fire one's straight at it from its
## trunnion, within PITCH_LIMITS; the barrels' own for a type with neither.
func _elevation(id: int, view: BuildingView, point: Vector3) -> float:
	var type := _types[id]
	var from := view.pitch_origin()
	var across := Vector2(point.x - from.x, point.z - from.z).length()
	if LOB_ELEVATION.has(type):
		var lob: Vector2 = LOB_ELEVATION[type]
		var reach := float(_stat(id, "range_cells")) * float(LOB_REACH.get(type, 1.0))
		var share := clampf(across / maxf(1.0, reach), 0.0, 1.0)
		return deg_to_rad(lerpf(lob.y, lob.x, share))
	if not PITCH_LIMITS.has(type):
		return view.elevation()
	var limits: Vector2 = PITCH_LIMITS[type]
	return clampf(atan2(point.y - from.y, across), deg_to_rad(limits.x), deg_to_rad(limits.y))


## Fires defence `id`'s held shot: its weapon from its next muzzle socket, wherever its head is now,
## at the unit it hit. A defence that falls or is disabled while it holds one fires it at once.
func _release_shot(id: int) -> void:
	var target: int = _held_shots[id]
	_held_shots.erase(id)
	_fire_defence(id, target)


## Defence `id` fires its weapon (its Weapons record, BattleEffects.fire) from its next muzzle at
## unit `target`, which flashes when it arrives; a stunning shot (the EMP tower's) leaves the unit
## crackling for its stun from when it arrives.
func _fire_defence(id: int, target: int) -> void:
	var weapon := _weapons[id]
	var from := _muzzle(id)
	var to := units.aim_point(target)
	effects.fire(weapon, from, to, 0, target, DEFENCE_IMPACT, _clock)
	var stun := float(_stat(id, "stun_ms")) / 1000.0
	if stun > 0.0:
		effects.stun(to, STUN_SIZE, weapon.color, _clock + from.distance_to(to) / weapon.speed, stun)


## A gravity well `id` at `at` pulled: a violet ring round it, and its vortex from its top to every
## unit it holds (the units of its targets' class in its reach), held as long as they are.
func _hold(id: int, at: Vector3) -> void:
	var range_cells := float(_stat(id, "range_cells"))
	effects.impact(at, range_cells * 0.5, WELL_PULL, _clock)
	var hold := float(_stat(id, "hold_ms")) / 1000.0
	var from := _muzzle(id)
	for unit: int in _in_reach(id, range_cells):
		effects.fire(_weapons[id], from, units.aim_point(unit), 0, 0, 0.0, _clock, false, hold)


## The cloaked sentry `id` shown: a shimmer round it as it decloaks, rings of energy and pale wisps.
func _decloak(id: int) -> void:
	var centre := _centres[id]
	var top := _muzzles[id] / MUZZLE_SHARE
	var at := Vector3(centre.x, top * 0.5, centre.y)
	effects.ring_flash(at, 0.9, MaterialKit.ENERGY, _clock, 0.3)
	effects.impact(Vector3(centre.x, 0.05, centre.y), 0.9, MaterialKit.ENERGY, _clock, 0.4)
	effects.impact(Vector3(centre.x, top * 0.6, centre.y), 0.6, MaterialKit.CORE_GLASS, _clock + 0.08, 0.35)
	for k: int in 3:
		effects.puff(Vector3(centre.x, 0.2, centre.y) + Parts.around(0.4, 120.0 * k, 0.0), 0.18, MaterialKit.CORE_GLASS,
			_clock + 0.05 * k, 0.5, 0.6)


## The live units of the class building `id` targets within `range_cells` of its centre (world
## units), in id order; the list is reused.
func _in_reach(id: int, range_cells: float) -> PackedInt32Array:
	_found.clear()
	var targets := catalog.targets_of(_types[id])
	var centre := _centres[id]
	for unit: int in range(1, sim.unit_count() + 1):
		if sim.unit_state(unit) == BattleArmy.DEAD:
			continue
		var unit_class := catalog.unit_class(sim.unit_type(unit))
		if targets != "both" and targets != unit_class:
			continue
		var at := units.aim_point(unit)
		if Vector2(at.x, at.z).distance_to(centre) <= range_cells:
			_found.append(unit)
	return _found


## Hidden defence `id`, just revealed, fades in (BuildingView.set_reveal) over REVEAL_SECONDS.
func _reveal(id: int) -> void:
	_reveal_at[id] = _clock
	_views[id].set_reveal(0.0)


## The reveals' fades, and the flashes, shakes and bars of the buildings hit lately; `shown` seconds
## of battle after the last frame.
func _draw_buildings(shown: float) -> void:
	_done.clear()
	for id: int in _reveal_at:
		var share := (_clock - _reveal_at[id]) / REVEAL_SECONDS
		_views[id].set_reveal(share)
		if share >= 1.0:
			_done.append(id)
	for id: int in _done:
		_reveal_at.erase(id)
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


## Where a shot leaves building `id`: its next muzzle socket (its weapon record's sockets in turn, as
## many as its model has), kicking an aiming head back by the record's `recoil` (BuildingView.fired),
## or its centre MUZZLE_SHARE of its height up when it has none.
func _muzzle(id: int) -> Vector3:
	var view: BuildingView = _views.get(id)
	var sockets := _weapons[id].sockets
	if view != null and not sockets.is_empty() and view.has_socket(sockets[0]):
		var k: int = _next_muzzle.get(id, 0)
		if k >= sockets.size() or not view.has_socket(sockets[k]):
			k = 0
		_next_muzzle[id] = k + 1
		# Read before the kick, which moves the socket back: the shot leaves where the muzzle was.
		var at := view.socket_point(sockets[k])
		view.fired(_clock, _weapons[id].recoil)
		return at
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
