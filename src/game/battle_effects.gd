class_name BattleEffects
extends Node3D
## The battle's effects (docs/reference/battle-view.md), each kind batched into one MultiMesh so a
## battle's worth of them costs a fixed handful of draws: the bolts in flight (defences' red,
## units' cyan, shells on an arc), the impacts (expanding hologram discs that fade), the arc
## tower's lightning (the LIGHTNING surface on a kinked strip), the scorch marks mines leave, the
## strips fallen walls leave, and the health bars. A shield generator's pool draws as a faint
## hologram dome of its own while it is up, flickering when it absorbs.
##
## BattleView feeds it from the sim's events and its own clock (seconds of battle shown, which a
## faster speed runs faster); nothing here reads the sim. Each list is a fixed-size set of packed
## arrays with a live count, an ended entry swapped with the last, so a frame allocates nothing.
## A bolt that arrives calls `arrived` with the building and the unit it was aimed at (0 for
## none), for BattleView's hit flashes.

## Floats per instance in a buffer: a 3D transform (three rows of four), a colour and custom data.
const FLOATS := 20
## How many of each can be on screen at once; more are dropped (the oldest stays).
const MAX_BOLTS := 384
const MAX_IMPACTS := 256
const MAX_ARCS := 48
const MAX_SCORCH := 64
const MAX_BARS := 768
## A bolt's speed in world units a second, its shortest flight, its look (length and thickness)
## and a shell's arc: its peak over the straight line, as a share of the distance.
const BOLT_SPEED := 22.0
const BOLT_MIN_SECONDS := 0.06
const BOLT_LENGTH := 0.55
const BOLT_WIDTH := 0.13
const SHELL_ARC := 0.35
const SHELL_SIZE := 2.2
## An impact's life and how far it grows from its start.
const IMPACT_SECONDS := 0.32
const IMPACT_START := 0.25
## A lightning arc's life.
const ARC_SECONDS := 0.28
## A health bar's size in world units (the fill inside the ink back) and its ink border.
const BAR_SIZE := Vector2(0.7, 0.09)
const BAR_BORDER := 0.03
## A shield's dome is this tall for its radius, and flickers for this long, this often, when its
## pool absorbs.
const SHIELD_HEIGHT := 0.55
const SHIELD_FLICKER_SECONDS := 0.3
const SHIELD_FLICKER_RATE := 20.0

## Called with (building id, unit id) when a bolt aimed at either arrives.
var arrived: Callable


## A MultiMesh's buffer (TRANSFORM_3D, colours, custom data: FLOATS a instance), written in place,
## for BattleEffects and BattleUnits.
class Instances:
	var data := PackedFloat32Array()

	func _init(count: int) -> void:
		data.resize(count * FLOATS)

	## Instance `i`: its basis and origin, its colour and its custom data.
	func put(i: int, basis: Basis, origin: Vector3, color: Color, custom: Color) -> void:
		var k := i * FLOATS
		data[k] = basis.x.x
		data[k + 1] = basis.y.x
		data[k + 2] = basis.z.x
		data[k + 3] = origin.x
		data[k + 4] = basis.x.y
		data[k + 5] = basis.y.y
		data[k + 6] = basis.z.y
		data[k + 7] = origin.y
		data[k + 8] = basis.x.z
		data[k + 9] = basis.y.z
		data[k + 10] = basis.z.z
		data[k + 11] = origin.z
		data[k + 12] = color.r
		data[k + 13] = color.g
		data[k + 14] = color.b
		data[k + 15] = color.a
		data[k + 16] = custom.r
		data[k + 17] = custom.g
		data[k + 18] = custom.b
		data[k + 19] = custom.a

static var BOLT := Surf.make(MaterialKit.Layer.GLOW, Color.WHITE, 1.0, Surf.UNLIT, true, false)
static var IMPACT := Surf.make(MaterialKit.Layer.GLOW, Color.WHITE, 1.0, Surf.HOLO, true)
static var ARC := Surf.make(MaterialKit.Layer.GLOW, Color("cfe9ff"), 1.0, Surf.UNLIT | Surf.JITTER | Surf.LIGHTNING)
static var SCORCH := Surf.make(MaterialKit.Layer.ROCK, Color("2c2838"), 1.0, Surf.LIT, false, false)
static var SHIELD := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ENERGY, 1.0, Surf.HOLO, true)

var _bolts: MultiMesh
var _bolt_buffer: Instances
var _bolt_count := 0
var _bolt_from := PackedVector3Array()
var _bolt_to := PackedVector3Array()
var _bolt_start := PackedFloat32Array()
var _bolt_seconds := PackedFloat32Array()
## The arc's peak height, 0 for a straight bolt; its size; what it was aimed at; its impact's
## radius (0 for none) and colour.
var _bolt_arc := PackedFloat32Array()
var _bolt_size := PackedFloat32Array()
var _bolt_building := PackedInt32Array()
var _bolt_unit := PackedInt32Array()
var _bolt_impact := PackedFloat32Array()
var _bolt_color := PackedColorArray()

var _impacts: MultiMesh
var _impact_buffer: Instances
var _impact_count := 0
var _impact_at := PackedVector3Array()
var _impact_start := PackedFloat32Array()
var _impact_radius := PackedFloat32Array()
var _impact_color := PackedColorArray()

var _arcs: MultiMesh
var _arc_buffer: Instances
var _arc_count := 0
var _arc_from := PackedVector3Array()
var _arc_to := PackedVector3Array()
var _arc_start := PackedFloat32Array()

var _scorch: MultiMesh
var _scorch_buffer: Instances
var _scorch_count := 0

var _wall_rubble: MultiMesh
var _wall_rubble_outline: MultiMesh
var _wall_rubble_buffer: Instances
var _wall_rubble_count := 0

var _bars: MultiMesh
var _bar_buffer: Instances
var _bar_count := 0
## The camera's right and up, which every bar faces along (the camera never turns).
var _across := Vector3.RIGHT
var _up := Vector3.UP

var _shields: Dictionary[int, MeshInstance3D] = {}
var _shield_pool: Dictionary[int, int] = {}
var _shield_flicker: Dictionary[int, float] = {}


## Call once, before adding to the tree. `walls` is how many walls could fall, `area` the field's
## AABB (every instance stays in it).
func setup(walls: int, area: AABB) -> void:
	var bolt := LowPolyMesh.new()
	bolt.orb(0.5, 8, 4, Vector3.ZERO, BOLT)
	_bolts = _multimesh(bolt.to_mesh(), MAX_BOLTS, area, false)
	_bolt_buffer = Instances.new(MAX_BOLTS)
	_bolt_start.resize(MAX_BOLTS)
	_bolt_seconds.resize(MAX_BOLTS)
	_bolt_arc.resize(MAX_BOLTS)
	_bolt_size.resize(MAX_BOLTS)
	_bolt_impact.resize(MAX_BOLTS)
	_bolt_from.resize(MAX_BOLTS)
	_bolt_to.resize(MAX_BOLTS)
	_bolt_building.resize(MAX_BOLTS)
	_bolt_unit.resize(MAX_BOLTS)
	_bolt_color.resize(MAX_BOLTS)

	var disc := LowPolyMesh.new()
	disc.ring(0.32, 0.5, 0.05, 20, Vector3.ZERO, IMPACT)
	disc.disc(0.32, 20, Vector3(0, 0.01, 0), IMPACT)
	_impacts = _multimesh(disc.to_mesh(), MAX_IMPACTS, area, false)
	_impact_buffer = Instances.new(MAX_IMPACTS)
	_impact_at.resize(MAX_IMPACTS)
	_impact_start.resize(MAX_IMPACTS)
	_impact_radius.resize(MAX_IMPACTS)
	_impact_color.resize(MAX_IMPACTS)

	# A kinked strip along +Z from 0 to 1, stretched to each arc's length.
	var arc := LowPolyMesh.new()
	var last := Vector3.ZERO
	for k: int in range(1, 7):
		var point := Vector3(0.0, 0.0, k / 6.0) + (Vector3(0.12 if k % 2 == 1 else -0.12, 0.05, 0) if k < 6 else Vector3.ZERO)
		Parts.pipe(arc, last, point, 0.045, ARC, 3, false)
		last = point
	_arcs = _multimesh(arc.to_mesh(), MAX_ARCS, area, false)
	_arc_buffer = Instances.new(MAX_ARCS)
	_arc_from.resize(MAX_ARCS)
	_arc_to.resize(MAX_ARCS)
	_arc_start.resize(MAX_ARCS)

	var scorch := LowPolyMesh.new()
	scorch.disc(0.5, 12, Vector3.ZERO, SCORCH)
	_scorch = _multimesh(scorch.to_mesh(), MAX_SCORCH, area, false)
	_scorch_buffer = Instances.new(MAX_SCORCH)

	var strip := BuildingModels.wall_rubble()
	_wall_rubble = _multimesh(strip.body, maxi(walls, 1), area, true)
	_wall_rubble_outline = _multimesh(strip.outline, maxi(walls, 1), area, false)
	_wall_rubble_buffer = Instances.new(maxi(walls, 1))

	var quad := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.5, -0.5, 0), Vector3(0.5, 0.5, 0), Vector3(0.5, -0.5, 0),
		Vector3(-0.5, -0.5, 0), Vector3(-0.5, 0.5, 0), Vector3(0.5, 0.5, 0)])
	var white := PackedColorArray()
	white.resize(6)
	white.fill(Color.WHITE)
	arrays[Mesh.ARRAY_COLOR] = white
	quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var bar_material := StandardMaterial3D.new()
	bar_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bar_material.vertex_color_use_as_albedo = true
	bar_material.no_depth_test = true
	bar_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	bar_material.render_priority = 1
	quad.surface_set_material(0, bar_material)
	_bars = _multimesh(quad, MAX_BARS, area, false)
	_bar_buffer = Instances.new(MAX_BARS)
	var view := Basis.from_euler(Vector3(deg_to_rad(IsoCamera.PITCH_DEG), deg_to_rad(IsoCamera.YAW_DEG), 0.0))
	_across = view.x
	_up = view.y


# --- Adding ----------------------------------------------------------------------

## A bolt from `from` to `to`, `color`, starting at `now`: straight at BOLT_SPEED, or on an arc
## landing `seconds` later when `seconds` is over 0 (a shell). On arrival it makes an impact of
## `impact` radius (none at 0) and calls `arrived` with `building` and `unit`.
func bolt(from: Vector3, to: Vector3, color: Color, now: float, seconds: float = 0.0, impact: float = 0.35,
		building: int = 0, unit: int = 0) -> void:
	if _bolt_count == MAX_BOLTS:
		return
	var i := _bolt_count
	_bolt_count += 1
	_bolt_from[i] = from
	_bolt_to[i] = to
	_bolt_start[i] = now
	var shell := seconds > 0.0
	_bolt_seconds[i] = seconds if shell else maxf(BOLT_MIN_SECONDS, from.distance_to(to) / BOLT_SPEED)
	_bolt_arc[i] = from.distance_to(to) * SHELL_ARC if shell else 0.0
	_bolt_size[i] = SHELL_SIZE if shell else 1.0
	_bolt_impact[i] = impact
	_bolt_color[i] = color
	_bolt_building[i] = building
	_bolt_unit[i] = unit


## An impact at `at`, growing to `radius` and fading, in `color`, from `now`.
func impact(at: Vector3, radius: float, color: Color, now: float) -> void:
	if _impact_count == MAX_IMPACTS or radius <= 0.0:
		return
	var i := _impact_count
	_impact_count += 1
	_impact_at[i] = at
	_impact_start[i] = now
	_impact_radius[i] = radius
	_impact_color[i] = color


## A lightning arc from `from` to `to`, from `now`.
func lightning(from: Vector3, to: Vector3, now: float) -> void:
	if _arc_count == MAX_ARCS:
		return
	var i := _arc_count
	_arc_count += 1
	_arc_from[i] = from
	_arc_to[i] = to
	_arc_start[i] = now


## A scorch mark on the ground at `at`, `radius` across, for the rest of the battle.
func scorch(at: Vector3, radius: float) -> void:
	if _scorch_count == MAX_SCORCH:
		return
	_scorch_buffer.put(_scorch_count, Basis.from_scale(Vector3(radius, 1.0, radius) * 2.0),
		Vector3(at.x, 0.012, at.z), Color.WHITE, Color(0, 0, 0, 0))
	_scorch_count += 1
	_scorch.buffer = _scorch_buffer.data
	_scorch.visible_instance_count = _scorch_count


## The strip a fallen wall leaves, on the cell centred at `at`, for the rest of the battle.
func wall_rubble(at: Vector3) -> void:
	if _wall_rubble_count == _wall_rubble.instance_count:
		return
	_wall_rubble_buffer.put(_wall_rubble_count, Basis(), at, Color.WHITE, Color(0, 0, 0, 0))
	_wall_rubble_count += 1
	for multimesh: MultiMesh in [_wall_rubble, _wall_rubble_outline]:
		multimesh.buffer = _wall_rubble_buffer.data
		multimesh.visible_instance_count = _wall_rubble_count


## A shield generator `id`'s dome, centred on `at`, `radius` across the ground.
func add_shield(id: int, at: Vector3, radius: float) -> void:
	var dome := LowPolyMesh.new()
	dome.dome(1.0, SHIELD_HEIGHT, 24, 6, Vector3.ZERO, SHIELD)
	var instance := MeshInstance3D.new()
	instance.mesh = dome.to_mesh()
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.position = at
	instance.scale = Vector3.ONE * radius
	add_child(instance)
	_shields[id] = instance
	_shield_pool[id] = 0
	_shield_flicker[id] = -1.0


## Shows generator `id`'s dome while its `pool` is up, flickering from `now` when it fell.
func set_shield(id: int, pool: int, now: float) -> void:
	if not _shields.has(id):
		return
	if pool < _shield_pool[id]:
		_shield_flicker[id] = now
	_shield_pool[id] = pool


# --- Drawing ---------------------------------------------------------------------

## Draws everything at `now`, the battle's clock, and drops what has ended.
func draw(now: float) -> void:
	_draw_bolts(now)
	_draw_impacts(now)
	_draw_arcs(now)
	for id: int in _shields:
		var since := now - _shield_flicker[id]
		var flickering := _shield_flicker[id] >= 0.0 and since < SHIELD_FLICKER_SECONDS
		_shields[id].visible = _shield_pool[id] > 0 and (not flickering or int(since * SHIELD_FLICKER_RATE) % 2 == 0)


## Starts a frame's health bars.
func begin_bars() -> void:
	_bar_count = 0


## A health bar `fraction` full in `color` over `at`.
func bar(at: Vector3, fraction: float, color: Color) -> void:
	if _bar_count + 2 > MAX_BARS:
		return
	var back := Basis(_across * (BAR_SIZE.x + 2.0 * BAR_BORDER), _up * (BAR_SIZE.y + 2.0 * BAR_BORDER), Vector3.BACK)
	_bar_buffer.put(_bar_count, back, at, MaterialKit.INK, Color(0, 0, 0, 0))
	var fill := clampf(fraction, 0.0, 1.0)
	var front := Basis(_across * (BAR_SIZE.x * fill), _up * BAR_SIZE.y, Vector3.BACK)
	_bar_buffer.put(_bar_count + 1, front, at - _across * (BAR_SIZE.x * (1.0 - fill) * 0.5), color, Color(0, 0, 0, 0))
	_bar_count += 2


## Ends a frame's health bars and draws them.
func end_bars() -> void:
	_bars.buffer = _bar_buffer.data
	_bars.visible_instance_count = _bar_count


func _draw_bolts(now: float) -> void:
	var i := 0
	while i < _bolt_count:
		var t := (now - _bolt_start[i]) / _bolt_seconds[i]
		if t >= 1.0:
			var to := _bolt_to[i]
			impact(to, _bolt_impact[i], _bolt_color[i], now)
			if arrived.is_valid() and (_bolt_building[i] != 0 or _bolt_unit[i] != 0):
				arrived.call(_bolt_building[i], _bolt_unit[i])
			_remove_bolt(i)
			continue
		t = maxf(t, 0.0)
		var from := _bolt_from[i]
		var to := _bolt_to[i]
		var arc := _bolt_arc[i]
		var at := from.lerp(to, t) + Vector3.UP * (arc * 4.0 * t * (1.0 - t))
		var heading := (to - from) + Vector3.UP * (arc * 4.0 * (1.0 - 2.0 * t))
		var forward := heading.normalized() if heading.length_squared() > 0.000001 else Vector3.FORWARD
		var side := forward.cross(Vector3.UP)
		if side.length_squared() < 0.0001:
			side = Vector3.RIGHT
		side = side.normalized()
		var up := side.cross(forward)
		var size := _bolt_size[i]
		var basis := Basis(side * BOLT_WIDTH * size, up * BOLT_WIDTH * size, forward * BOLT_LENGTH * size)
		_bolt_buffer.put(i, basis, at, _bolt_color[i], Color(0, 0, 0, 0))
		i += 1
	_bolts.buffer = _bolt_buffer.data
	_bolts.visible_instance_count = _bolt_count


func _remove_bolt(i: int) -> void:
	_bolt_count -= 1
	var last := _bolt_count
	_bolt_from[i] = _bolt_from[last]
	_bolt_to[i] = _bolt_to[last]
	_bolt_start[i] = _bolt_start[last]
	_bolt_seconds[i] = _bolt_seconds[last]
	_bolt_arc[i] = _bolt_arc[last]
	_bolt_size[i] = _bolt_size[last]
	_bolt_impact[i] = _bolt_impact[last]
	_bolt_color[i] = _bolt_color[last]
	_bolt_building[i] = _bolt_building[last]
	_bolt_unit[i] = _bolt_unit[last]


func _draw_impacts(now: float) -> void:
	var i := 0
	while i < _impact_count:
		var t := (now - _impact_start[i]) / IMPACT_SECONDS
		if t >= 1.0:
			_impact_count -= 1
			var last := _impact_count
			_impact_at[i] = _impact_at[last]
			_impact_start[i] = _impact_start[last]
			_impact_radius[i] = _impact_radius[last]
			_impact_color[i] = _impact_color[last]
			continue
		t = maxf(t, 0.0)
		var grow := lerpf(IMPACT_START, 1.0, 1.0 - (1.0 - t) * (1.0 - t)) * _impact_radius[i] * 2.0
		var at := _impact_at[i]
		_impact_buffer.put(i, Basis.from_scale(Vector3(grow, grow, grow)), Vector3(at.x, at.y + 0.05, at.z),
			_impact_color[i], Color(0, 0, 0, t * t))
		i += 1
	_impacts.buffer = _impact_buffer.data
	_impacts.visible_instance_count = _impact_count


func _draw_arcs(now: float) -> void:
	var i := 0
	while i < _arc_count:
		if now - _arc_start[i] >= ARC_SECONDS:
			_arc_count -= 1
			var last := _arc_count
			_arc_from[i] = _arc_from[last]
			_arc_to[i] = _arc_to[last]
			_arc_start[i] = _arc_start[last]
			continue
		var from := _arc_from[i]
		var along := _arc_to[i] - from
		var forward := along.normalized()
		var side := forward.cross(Vector3.UP)
		if side.length_squared() < 0.0001:
			side = Vector3.RIGHT
		side = side.normalized()
		_arc_buffer.put(i, Basis(side, side.cross(forward), along), from, Color.WHITE, Color(0, 0, 0, 0))
		i += 1
	_arcs.buffer = _arc_buffer.data
	_arcs.visible_instance_count = _arc_count


## A MultiMesh of `mesh` for up to `count` instances with colours and custom data, none shown, its
## bounds the field's `area`, in an instance under this node casting a shadow when `shadow`.
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
