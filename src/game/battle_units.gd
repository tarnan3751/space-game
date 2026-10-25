class_name BattleUnits
extends Node3D
## The attacker's units in battle (docs/reference/battle-view.md): every unit of a type drawn from
## one MultiMesh of its body and one of its outline (UnitModels.meshes, in the tier of the
## attacker's level), so an army costs a few draws a type however many there are.
##
## Each instance's transform carries where the unit is and which way it faces, its custom data
## (INSTANCE_CUSTOM, effects.gdshaderinc) what the shaders animate: x the gait's phase in steps
## walked, y how much of the gait shows, z the hit flash, w the death's fade. A hovering type's x
## is Rig.BANK_BASE plus its bank in radians instead (Rig.BANK): its turn rate (the drawn
## heading's change a second) times BANK_GAIN, at most BANK_MAX, eased at BANK_EASE. A type whose mesh carries a channel that
## reads the aim (Rig.AIMING: the ranger's arms, a gun's slide, the brawler's punch, the bomber's bay)
## aims while it attacks: its gait eases out, then its aim's share rises to 1 (AIM_EASE), and while
## it shows y is minus that share and x the fire phase, 0 at a shot and 1 by the next, plus 2 after
## an odd shot (the shot's index, from 0, mod 2: the parity a twin weapon's sides take turns on,
## `muzzle` the left on even shots, `muzzle_2` the right on odd ones; Rig); leaving the attack, the
## aim eases out before the gait or the bank comes back, so nothing snaps. While it aims, a type
## whose aimed muzzle (on Rig.AIM) does not point straight ahead (the ranger's rifle, carried
## across its body) turns by the yaw of its level direction off +Z, so the muzzle points at its
## target; a muzzle within AIM_YAW_VERTICAL of straight up or down gives no yaw. A wheeled type steps at
## WHEEL_STRIDE, half its wheels' turn, so its wheels (Rig.WHEEL) roll with the ground. Positions are
## interpolated here only, between the sim's last two ticks (after_step keeps both); the sim is
## read, never changed. A walking ground unit hops (the gait) at a step per STRIDE of its height
## walked; a wheeled one only jolts (WHEELED); a hovering or flying one bobs by its own surface
## flags. A unit turns smoothly towards where it last moved, or towards the building it attacks.
## A unit's shots (shoot()) leave its muzzle socket where the model has one (Rig.posed, as the
## shaders pose the arm it is on) with a muzzle flash, or its middle; a blow that brings no shot (a
## melee unit's, read from the sim's UNIT_HIT events) starts the fire phase and counts as a shot all
## the same, so the brawler's fists punch in turn; socket_point() gives any of its
## sockets (`muzzle`, `muzzle_2`, `bay`, `exhaust`, …) as last drawn. An aiming unit's shot is held
## until its aim's share reaches AIM_READY, so a bolt never leaves a rifle still rising. A hit
## flashes it for HIT_SECONDS; a death shrinks, sinks and fades it over DEATH_SECONDS, after
## which it is drawn no more. A thrown unit (a grav trap) flies to where it landed on an arc.
## Damaged units show a health bar (BattleEffects.bar), its fill eased towards the hull left.
##
## From FAR_ZOOM out the MultiMeshes draw each type's far version (UnitModels.meshes, far: fewer
## sides), where a unit is a few dozen pixels tall: a full army in its near version would take the
## battle over the Cost ceilings (docs/reference/art-style.md), since every instance of a
## MultiMesh is drawn wherever the camera looks.

const DEATH_SECONDS := 0.3
const DEATH_SINK := 0.15
const HIT_SECONDS := 0.12
## How fast the gait's share follows walking or standing (a second), and how fast a unit turns
## (the share of the way a second, as an exponential rate).
const GAIT_EASE := 8.0
const TURN_RATE := 12.0
## A step's length as a share of the model's height, and the least movement a frame that counts
## as walking (world units).
const STRIDE := 0.45
const WALKING := 0.0005
## The gait's share for a ground unit on wheels: a jolt rather than a hop.
const WHEELED := {"dune_runner": 0.3}
## A wheeled type's step (world units): half its wheels' circumference, since Rig.WHEEL turns them
## half a turn a step.
const WHEEL_STRIDE := {"dune_runner": PI * UnitModels.VehicleModels.RUNNER_WHEEL}
## A hovering unit's bank: radians per radian a second of turn, the most either way (25 degrees
## in the air, 12 for a ground unit hovering low, whose hull would dip into the ground), and how
## fast it follows (the share of the way a second, as an exponential rate).
const BANK_GAIN := 0.2
const BANK_MAX := 0.4363
const BANK_MAX_GROUND := 0.2094
const BANK_EASE := 10.0
## The way a unit faces as it is deployed, before it turns onto its course (towards the camera's
## right): so every unit, an aircraft too, turns onto its course, banking if it hovers.
const DEPLOY_YAW := PI * 0.25
## A thrown unit's flight.
const THROW_SECONDS := 0.45
const THROW_HEIGHT := 1.6
## How fast a health bar's fill follows the hull, and how high over a unit's top it floats.
const BAR_EASE := 10.0
const BAR_OVER := 0.25
## The camera size from which the far versions are drawn.
const FAR_ZOOM := 20.0
## How fast a rigged unit's aim's share follows attacking or not (a second), the share from which
## its held shot is fired, and its muzzle flash's size.
const AIM_EASE := 10.0
## How near to vertical (radians) an aimed muzzle's direction gives its type no turn as it aims.
const AIM_YAW_VERTICAL := 0.5236
const AIM_READY := 0.9
const MUZZLE_FLASH := 0.14

var _sim: BattleSim
var _grid: Vector2i
## Each building's centre on the ground (world x and z), for a unit facing its target.
var _centres: Dictionary[int, Vector2] = {}

## Per unit type in the battle (its index in the sim's list of types): the MultiMeshes, the
## buffer they share, how many are drawn this frame, the gait's share while it walks, a step's
## length, the model's top and its middle's height (where shots hit and leave).
var _types := PackedStringArray()
var _type_of_name: Dictionary[String, int] = {}
var _bodies: Array[MultiMesh] = []
var _outlines: Array[MultiMesh] = []
var _near: Array[BuildingModels.Meshes] = []
var _far: Array[BuildingModels.Meshes] = []
## Whether the far versions are drawn now.
var _far_shown: bool = false
var _buffers: Array[BattleEffects.Instances] = []
var _drawn := PackedInt32Array()
var _hop := PackedFloat32Array()
var _stride := PackedFloat32Array()
var _top := PackedFloat32Array()
var _middle := PackedFloat32Array()
## Per type: whether it aims (its mesh carries a channel of Rig.AIMING), whether it hovers (its
## x carries its bank), the seconds between its shots, its sockets by name and its `muzzle` socket (null
## for none), and the yaw it turns by at full aim so that muzzle points ahead.
var _aims := PackedByteArray()
var _hovers := PackedByteArray()
var _bank_max := PackedFloat32Array()
var _fire_seconds := PackedFloat32Array()
var _sockets: Array[Dictionary] = []
var _muzzles: Array[LowPolyMesh.Socket] = []
var _aim_yaw := PackedFloat32Array()

## Per unit (id - 1), as many as the sim has deployed: its type, its place at the last two ticks
## and as last drawn (world x and z), its heading, gait phase and share, when its hit flash began,
## when it died (-1 alive), when a throw began (-1 none) and from where, its health bar's fill.
var _count := 0
var _type := PackedInt32Array()
var _prev := PackedVector2Array()
var _cur := PackedVector2Array()
var _shown := PackedVector2Array()
var _yaw := PackedFloat32Array()
var _phase := PackedFloat32Array()
var _gait := PackedFloat32Array()
var _flash_at := PackedFloat32Array()
var _death_at := PackedFloat32Array()
var _throw_at := PackedFloat32Array()
var _throw_from := PackedVector2Array()
var _bar := PackedFloat32Array()
## Per unit: its aim's share, its bank, how many shots it has fired, when its last shot left (-1
## none), its instance state and transform as last drawn (Rig), and the shot it holds until it is
## ready (shoot()): when it was fired (-1 none), where to, at which building, with what impact and
## colour.
var _aim := PackedFloat32Array()
var _bank := PackedFloat32Array()
var _shots := PackedInt32Array()
var _fired_at := PackedFloat32Array()
var _state := PackedColorArray()
var _drawn_as: Array[Transform3D] = []
var _held_at := PackedFloat32Array()
## Per unit: whether the last step brought it a blow (UNIT_HIT), not yet matched by a shot.
var _blow := PackedByteArray()
var _held_to := PackedVector3Array()
var _held_building := PackedInt32Array()
var _held_impact := PackedFloat32Array()
var _held_color := PackedColorArray()


## Call once, before adding to the tree: a MultiMesh pair for each type of `army` (unit: count),
## in the tier of its level in `levels`, for the battle `sim` on a field of `grid`; `centres` are
## the buildings' centres. `area` bounds every instance.
func setup(sim: BattleSim, catalog: Catalog, army: Dictionary, levels: Dictionary, grid: Vector2i,
		centres: Dictionary[int, Vector2], area: AABB) -> void:
	_sim = sim
	_grid = grid
	_centres = centres
	var names := PackedStringArray()
	for unit: String in army:
		if catalog.has_unit(unit) and int(army[unit]) > 0:
			names.append(unit)
	names.sort()
	var capacity := 0
	for unit: String in names:
		capacity += int(army[unit])
	_resize(capacity)
	for unit: String in names:
		var level := clampi(int(levels.get(unit, 1)), 1, catalog.unit_max_level(unit))
		var tier := UnitModels.tier_of(catalog, unit, level)
		var meshes := UnitModels.meshes(unit, tier)
		_near.append(meshes)
		_far.append(UnitModels.meshes(unit, tier, true))
		var count := int(army[unit])
		_type_of_name[unit] = _types.size()
		_types.append(unit)
		_bodies.append(_multimesh(meshes.body, count, area, true))
		_outlines.append(_multimesh(meshes.outline, count, area, false))
		_buffers.append(BattleEffects.Instances.new(count))
		_drawn.append(0)
		var box := meshes.body.get_aabb()
		var hovers := _has_flag(meshes.body, Surf.BOB)
		_aims.append(1 if _aiming(meshes.body) else 0)
		_hovers.append(1 if hovers else 0)
		_fire_seconds.append(maxf(0.05, int(catalog.unit_level_stats(unit, level).get("fire_ms", 1000)) / 1000.0))
		_sockets.append(meshes.sockets)
		var muzzle: LowPolyMesh.Socket = meshes.sockets.get("muzzle")
		_muzzles.append(muzzle)
		_aim_yaw.append(_muzzle_yaw(muzzle))
		var ground := catalog.unit_class(unit) == "ground"
		_bank_max.append(BANK_MAX_GROUND if ground else BANK_MAX)
		_hop.append(0.0 if hovers or not ground else float(WHEELED.get(unit, 1.0)))
		_top.append(box.end.y)
		_middle.append(box.get_center().y)
		_stride.append(float(WHEEL_STRIDE.get(unit, STRIDE * box.size.y)))


## The world point a unit's enemies' shots are aimed at: its middle.
func aim_point(id: int) -> Vector3:
	var u := id - 1
	if u < 0 or u >= _count:
		return Vector3.ZERO
	var at := _cur[u]
	return Vector3(at.x, _middle[_type[u]], at.y)


## Unit `id`'s socket `name` in the world as last drawn (Rig.posed, as the shaders pose the part it
## is on), or its middle where its model has no such socket.
func socket_point(id: int, name: String) -> Vector3:
	var u := id - 1
	if u < 0 or u >= _count:
		return Vector3.ZERO
	var socket: LowPolyMesh.Socket = _sockets[_type[u]].get(name)
	var drawn := _drawn_as[u]
	if socket == null:
		return Vector3(drawn.origin.x, _middle[_type[u]], drawn.origin.z)
	return drawn * Rig.posed(socket.position, socket.rig, socket.rig2, _state[u])


## Unit `id` fired at `to` (a hit on `building`) at `now`: a bolt of `color` from its muzzle, making
## an impact of `impact` radius on arrival, with a muzzle flash where it has a muzzle socket; a
## rigged unit holds it until its aim's share reaches AIM_READY. Fired on the next draw.
func shoot(id: int, to: Vector3, building: int, impact: float, color: Color, now: float) -> void:
	var u := id - 1
	if u < 0 or u >= _count:
		return
	_held_at[u] = now
	_held_to[u] = to
	_held_building[u] = building
	_held_impact[u] = impact
	_held_color[u] = color


## Reads the units after a sim step: those deployed in it start where they stand, the rest move
## their last tick's place to the one before; each unit that struck a blow in it is marked.
func after_step() -> void:
	var events := _sim.events
	for i: int in events.count:
		if events.kind[i] == BattleEvents.UNIT_HIT and events.source[i] >= 1 and events.source[i] <= _count:
			_blow[events.source[i] - 1] = 1
	var total := _sim.unit_count()
	for u: int in _count:
		_prev[u] = _cur[u]
		_cur[u] = _world(_sim.unit_position(u + 1))
	while _count < total:
		var u := _count
		_count += 1
		var at := _world(_sim.unit_position(u + 1))
		_type[u] = _type_of_name.get(_sim.unit_type(u + 1), 0)
		_prev[u] = at
		_cur[u] = at
		_shown[u] = at
		_yaw[u] = DEPLOY_YAW
		_phase[u] = 0.0
		_gait[u] = 0.0
		_flash_at[u] = -1.0
		_death_at[u] = -1.0
		_throw_at[u] = -1.0
		_bar[u] = 1.0
		_aim[u] = 0.0
		_bank[u] = 0.0
		_shots[u] = 0
		_fired_at[u] = -1.0
		_state[u] = Color(0, 0, 0, 0)
		_drawn_as[u] = Transform3D(Basis.IDENTITY, Vector3(at.x, 0.0, at.y))
		_held_at[u] = -1.0
		_blow[u] = 0


## Unit `id` was hit: it flashes from `now`.
func hit(id: int, now: float) -> void:
	if id >= 1 and id <= _count:
		_flash_at[id - 1] = now


## Unit `id` died: it shrinks and fades from `now`.
func die(id: int, now: float) -> void:
	if id >= 1 and id <= _count and _death_at[id - 1] < 0.0:
		_death_at[id - 1] = now


## Unit `id` was thrown from the field point `from`: it flies from there to its new place from `now`.
func throw_unit(id: int, from: Vector2i, now: float) -> void:
	if id >= 1 and id <= _count:
		_throw_at[id - 1] = now
		_throw_from[id - 1] = _world(from)


## Draws every unit at `alpha` of the way from the last tick but one to the last, at `now`, the
## battle's clock, `delta` seconds of it after the last frame, in the far versions when `far`;
## damaged ones get a bar in `effects`.
func draw(alpha: float, now: float, delta: float, effects: BattleEffects, far: bool) -> void:
	if far != _far_shown:
		_far_shown = far
		for t: int in _types.size():
			var meshes := _far[t] if far else _near[t]
			_bodies[t].mesh = meshes.body
			_outlines[t].mesh = meshes.outline
	_drawn.fill(0)
	var turn := 1.0 - exp(-TURN_RATE * delta)
	var ease_gait := minf(1.0, GAIT_EASE * delta)
	var ease_bar := minf(1.0, BAR_EASE * delta)
	var ease_aim := minf(1.0, AIM_EASE * delta)
	var ease_bank := 1.0 - exp(-BANK_EASE * delta)
	for u: int in _count:
		var dying := _death_at[u] >= 0.0
		var fade := clampf((now - _death_at[u]) / DEATH_SECONDS, 0.0, 1.0) if dying else 0.0
		if fade >= 1.0:
			continue
		var t := _type[u]
		var id := u + 1
		var at := _prev[u].lerp(_cur[u], alpha)
		var lift := 0.0
		if _throw_at[u] >= 0.0:
			var k := (now - _throw_at[u]) / THROW_SECONDS
			if k >= 1.0:
				_throw_at[u] = -1.0
			else:
				at = _throw_from[u].lerp(_cur[u], k)
				lift = THROW_HEIGHT * 4.0 * k * (1.0 - k)
		var moved := at.distance_to(_shown[u])
		_shown[u] = at
		var state := _sim.unit_state(id)
		var aiming := _aims[t] == 1 and state == BattleArmy.ATTACKING and not dying
		var walking := moved > WALKING and lift == 0.0 and not dying and not aiming
		_gait[u] = move_toward(_gait[u], 1.0 if walking and _aim[u] == 0.0 else 0.0, ease_gait)
		if _aims[t] == 1:
			_aim[u] = move_toward(_aim[u], 1.0 if aiming and _gait[u] == 0.0 and _bank[u] == 0.0 else 0.0, ease_aim)
		_phase[u] = fmod(_phase[u] + moved / _stride[t], 2.0)
		var facing := Vector2.ZERO
		var target := _sim.unit_target(id)
		if state == BattleArmy.ATTACKING and _centres.has(target):
			facing = _centres[target] - at
		else:
			var heading := _sim.unit_heading(id)
			facing = Vector2(heading.x, heading.y)
		var was := _yaw[u]
		if facing.length_squared() > 0.0001 and not dying:
			_yaw[u] = lerp_angle(_yaw[u], atan2(facing.x, facing.y), turn)
		if _hovers[t] == 1 and delta > 0.0:
			if aiming or _aim[u] > 0.0 or dying:
				_bank[u] = move_toward(_bank[u], 0.0, _bank_max[t] * ease_aim)
			else:
				var turned := -angle_difference(was, _yaw[u]) / delta
				var banking := clampf(turned * BANK_GAIN, -_bank_max[t], _bank_max[t])
				_bank[u] = lerpf(_bank[u], banking, ease_bank)
		var flash := 0.0
		if _flash_at[u] >= 0.0:
			var since := now - _flash_at[u]
			flash = 1.0 - since / HIT_SECONDS if since >= 0.0 and since < HIT_SECONDS else 0.0
		var size := 1.0 - fade * fade
		var basis := Basis(Vector3.UP, _yaw[u] + _aim_yaw[t] * _aim[u]).scaled(Vector3.ONE * maxf(size, 0.01))
		var origin := Vector3(at.x, lift - DEATH_SINK * fade, at.y)
		var custom := Color(Rig.BANK_BASE + _bank[u] if _hovers[t] == 1 else _phase[u], _gait[u] * _hop[t], flash, fade)
		if _aim[u] > 0.0:
			var fire := clampf((now - _fired_at[u]) / _fire_seconds[t], 0.0, 1.0) if _fired_at[u] >= 0.0 else 1.0
			custom = Color(fire + 2.0 * ((_shots[u] + 1) % 2), -_aim[u], flash, fade)
		_state[u] = custom
		_drawn_as[u] = Transform3D(basis, origin)
		_buffers[t].put(_drawn[t], basis, origin, Color.WHITE, custom)
		if _blow[u] == 1:
			_blow[u] = 0
			if _held_at[u] < 0.0:
				_fired_at[u] = now
				_shots[u] += 1
		if _held_at[u] >= 0.0 and (_aims[t] == 0 or _aim[u] >= AIM_READY or not aiming):
			_held_at[u] = -1.0
			_fired_at[u] = now
			_shots[u] += 1
			var from := _muzzle_at(u, basis, origin)
			effects.bolt(from, _held_to[u], _held_color[u], now, 0.0, _held_impact[u], _held_building[u], 0)
			if _muzzles[t] != null:
				effects.flash(from, MUZZLE_FLASH, _held_color[u], now)
		_drawn[t] += 1
		if not dying:
			var whole := float(_sim.unit_max_hp(id))
			var left := float(_sim.unit_hp(id)) / whole if whole > 0.0 else 1.0
			_bar[u] = lerpf(_bar[u], left, ease_bar)
			if left < 1.0:
				effects.bar(Vector3(at.x, _top[t] + BAR_OVER + lift, at.y), _bar[u], MaterialKit.ENERGY)
	for t: int in _types.size():
		_bodies[t].buffer = _buffers[t].data
		_bodies[t].visible_instance_count = _drawn[t]
		_outlines[t].buffer = _buffers[t].data
		_outlines[t].visible_instance_count = _drawn[t]


## How many units are drawn this frame, every type.
func drawn() -> int:
	var total := 0
	for n: int in _drawn:
		total += n
	return total


## Unit `u`'s muzzle in the world, drawn with `basis` at `origin`: its type's `muzzle` socket, or
## on an odd shot its `muzzle_2` where it has one, posed by the state it was last drawn in, or its
## middle.
func _muzzle_at(u: int, basis: Basis, origin: Vector3) -> Vector3:
	var socket := _muzzles[_type[u]]
	if _shots[u] % 2 == 0 and _sockets[_type[u]].has("muzzle_2"):
		socket = _sockets[_type[u]]["muzzle_2"]
	if socket == null:
		return Vector3(origin.x, _middle[_type[u]], origin.z)
	return origin + basis * Rig.posed(socket.position, socket.rig, socket.rig2, _state[u])


## The ground point (world x and z) of a field point.
func _world(at: Vector2i) -> Vector2:
	return Vector2(at.x / 1000.0 - _grid.x * 0.5, at.y / 1000.0 - _grid.y * 0.5)


func _resize(capacity: int) -> void:
	_type.resize(capacity)
	_prev.resize(capacity)
	_cur.resize(capacity)
	_shown.resize(capacity)
	_yaw.resize(capacity)
	_phase.resize(capacity)
	_gait.resize(capacity)
	_flash_at.resize(capacity)
	_death_at.resize(capacity)
	_throw_at.resize(capacity)
	_throw_from.resize(capacity)
	_bar.resize(capacity)
	_aim.resize(capacity)
	_bank.resize(capacity)
	_shots.resize(capacity)
	_drawn_as.resize(capacity)
	_fired_at.resize(capacity)
	_state.resize(capacity)
	_held_at.resize(capacity)
	_blow.resize(capacity)
	_held_to.resize(capacity)
	_held_building.resize(capacity)
	_held_impact.resize(capacity)
	_held_color.resize(capacity)


## Whether any part of a mesh has the surface flag `flag`: Surf.BOB for a hovering or flying
## unit's.
static func _has_flag(mesh: Mesh, flag: int) -> bool:
	var arrays := mesh.surface_get_arrays(0)
	var uv2s: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	for uv2: Vector2 in uv2s:
		if (roundi(uv2.y) & flag) != 0:
			return true
	return false


## The yaw a type turns by at full aim so that its aimed `muzzle` (on Rig.AIM, posed aimed) points
## ahead: minus its level direction's angle off +Z, or 0 for none, or within AIM_YAW_VERTICAL of
## vertical.
static func _muzzle_yaw(muzzle: LowPolyMesh.Socket) -> float:
	if muzzle == null or (roundi(muzzle.rig.w) != Rig.AIM and roundi(muzzle.rig2.w) != Rig.AIM):
		return 0.0
	var ahead := Rig.posed_direction(muzzle.direction, muzzle.rig, muzzle.rig2, Color(1, -1, 0, 0)).normalized()
	if absf(ahead.y) > cos(AIM_YAW_VERTICAL):
		return 0.0
	return -atan2(ahead.x, ahead.z)


## Whether any part of a mesh is rigged on `channel`, as its own joint or its parent's.
static func _has_channel(mesh: Mesh, channel: int) -> bool:
	var arrays := mesh.surface_get_arrays(0)
	for slot: int in [Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2]:
		if arrays[slot] == null:
			return false
		var joints: PackedFloat32Array = arrays[slot]
		for i: int in range(3, joints.size(), 4):
			if roundi(joints[i]) == channel:
				return true
	return false


## Whether any part of a mesh is rigged on a channel that reads the aim (Rig.AIMING), as its own
## joint or its parent's.
static func _aiming(mesh: Mesh) -> bool:
	for channel: int in Rig.AIMING:
		if _has_channel(mesh, channel):
			return true
	return false


func _multimesh(mesh: Mesh, count: int, area: AABB, shadow: bool) -> MultiMesh:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = count
	multimesh.visible_instance_count = 0
	multimesh.custom_aabb = area
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return multimesh
