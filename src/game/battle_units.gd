class_name BattleUnits
extends Node3D
## The attacker's units in battle (docs/reference/battle-view.md): every unit of a type drawn from
## one MultiMesh of its body and one of its outline (UnitModels.meshes, in the tier of the
## attacker's level), so an army costs a few draws a type however many there are.
##
## Each instance's transform carries where the unit is and which way it faces, its custom data
## (INSTANCE_CUSTOM, effects.gdshaderinc) what the shaders animate: x the gait's phase in steps
## walked, y how much of the gait shows, z the hit flash, w the death's fade. Positions are
## interpolated here only, between the sim's last two ticks (after_step keeps both); the sim is
## read, never changed. A walking ground unit hops (the gait) at a step per STRIDE of its height
## walked; a wheeled one only jolts (WHEELED); a hovering or flying one bobs by its own surface
## flags. A unit turns smoothly towards where it last moved, or towards the building it attacks.
## A hit flashes it for HIT_SECONDS; a death shrinks, sinks and fades it over DEATH_SECONDS, after
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
## A thrown unit's flight.
const THROW_SECONDS := 0.45
const THROW_HEIGHT := 1.6
## How fast a health bar's fill follows the hull, and how high over a unit's top it floats.
const BAR_EASE := 10.0
const BAR_OVER := 0.25
## The camera size from which the far versions are drawn.
const FAR_ZOOM := 20.0

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
		var hovers := _bobs(meshes.body)
		var ground := catalog.unit_class(unit) == "ground"
		_hop.append(0.0 if hovers or not ground else float(WHEELED.get(unit, 1.0)))
		_top.append(box.end.y)
		_middle.append(box.get_center().y)
		_stride.append(STRIDE * box.size.y)


## The world point a unit's shots leave from and are aimed at: its middle.
func aim_point(id: int) -> Vector3:
	var u := id - 1
	if u < 0 or u >= _count:
		return Vector3.ZERO
	var at := _cur[u]
	return Vector3(at.x, _middle[_type[u]], at.y)


## Reads the units after a sim step: those deployed in it start where they stand, the rest move
## their last tick's place to the one before.
func after_step() -> void:
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
		var heading := _sim.unit_heading(u + 1)
		_yaw[u] = atan2(heading.x, heading.y) if heading != Vector2i.ZERO else PI * 0.25
		_phase[u] = 0.0
		_gait[u] = 0.0
		_flash_at[u] = -1.0
		_death_at[u] = -1.0
		_throw_at[u] = -1.0
		_bar[u] = 1.0


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
		var walking := moved > WALKING and lift == 0.0 and not dying
		_gait[u] = move_toward(_gait[u], 1.0 if walking else 0.0, ease_gait)
		_phase[u] = fmod(_phase[u] + moved / _stride[t], 2.0)
		var facing := Vector2.ZERO
		var target := _sim.unit_target(id)
		if state == BattleArmy.ATTACKING and _centres.has(target):
			facing = _centres[target] - at
		else:
			var heading := _sim.unit_heading(id)
			facing = Vector2(heading.x, heading.y)
		if facing.length_squared() > 0.0001 and not dying:
			_yaw[u] = lerp_angle(_yaw[u], atan2(facing.x, facing.y), turn)
		var flash := 0.0
		if _flash_at[u] >= 0.0:
			var since := now - _flash_at[u]
			flash = 1.0 - since / HIT_SECONDS if since >= 0.0 and since < HIT_SECONDS else 0.0
		var size := 1.0 - fade * fade
		var basis := Basis(Vector3.UP, _yaw[u]).scaled(Vector3.ONE * maxf(size, 0.01))
		var origin := Vector3(at.x, lift - DEATH_SINK * fade, at.y)
		var custom := Color(_phase[u], _gait[u] * _hop[t], flash, fade)
		_buffers[t].put(_drawn[t], basis, origin, Color.WHITE, custom)
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


## Whether a mesh's parts bob (Surf.BOB): a hovering or flying unit's.
static func _bobs(mesh: Mesh) -> bool:
	var arrays := mesh.surface_get_arrays(0)
	var uv2s: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	for uv2: Vector2 in uv2s:
		if (roundi(uv2.y) & Surf.BOB) != 0:
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
