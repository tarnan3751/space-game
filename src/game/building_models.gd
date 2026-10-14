class_name BuildingModels
extends RefCounted
## Flat-shaded low-poly models built in code from LowPolyMesh parts and painted from the
## Palette texture, one per building type and level, so the game needs no art assets. The
## contract any model keeps (and an imported one must keep): origin at the footprint centre
## on the ground, +Y up, fitting inside size x size cells.
##
## A model is a Node3D holding one static MeshInstance3D and at most one spinning one, which
## carries the SPIN_META meta (its speed in radians per second) and turns around Y while the
## building is finished and idle. The meshes are built once per type and level and shared;
## the nodes are per view. A level above a type's models shows its top model.
##
## Each category shares a look: resources stand on square slabs (tanks, drills), the army on
## slabs as halls and domes with big doors, defences on octagonal plinths, traps lie flat and
## walls are blocks. Level 1 is plain, each level adds a part or an accent, the top level
## carries gold.

const SPIN_META := "spin_speed"

## [the footprint size a model is built for, the levels it has models for] per type.
const MODELS := {
	"command_center": [4, 5],
}
## Where the Command Center's antennae stand, in the order levels add them (degrees).
const ANTENNAE := [200.0, 340.0, 100.0, 20.0]

static var _cache: Dictionary[String, Meshes] = {}
static var _warned: Dictionary[String, bool] = {}


## A model while it is built: the static body, and the part that spins around `pivot`.
class Parts:
	var body := LowPolyMesh.new()
	var spin := LowPolyMesh.new()
	var pivot := Vector3.ZERO
	var speed := 0.0


## A built model's meshes, shared by every view that shows it.
class Meshes:
	var body: ArrayMesh
	## Null when nothing spins.
	var spin: ArrayMesh
	var pivot := Vector3.ZERO
	var speed := 0.0


static func create(type: String, level: int, size: int) -> Node3D:
	var root := Node3D.new()
	var shown := 0
	var key := "?/%d" % size
	if MODELS.has(type):
		var spec: Array = MODELS[type]
		var built_for: int = spec[0]
		var top: int = spec[1]
		shown = clampi(level, 1, top)
		key = "%s/%d" % [type, shown]
		if built_for != size:
			root.scale = Vector3.ONE * (float(size) / built_for)
	elif not _warned.has(type):
		_warned[type] = true
		push_warning("No model for building type '%s'; showing a generic block" % type)
	var meshes: Meshes = _cache.get(key)
	if meshes == null:
		var p := Parts.new()
		if shown > 0:
			_build(p, type, shown)
		else:
			_generic(p, size)
		meshes = _store(key, p)
	var body := MeshInstance3D.new()
	body.mesh = meshes.body
	root.add_child(body)
	if meshes.spin != null:
		var spinner := MeshInstance3D.new()
		spinner.mesh = meshes.spin
		spinner.position = meshes.pivot
		spinner.set_meta(SPIN_META, meshes.speed)
		root.add_child(spinner)
	return root


## Shown while a building is first being constructed.
static func create_scaffold(size: int) -> Node3D:
	var key := "scaffold/%d" % size
	var meshes: Meshes = _cache.get(key)
	if meshes == null:
		var p := Parts.new()
		_scaffold(p, size)
		meshes = _store(key, p)
	var root := Node3D.new()
	var frame := MeshInstance3D.new()
	frame.mesh = meshes.body
	root.add_child(frame)
	return root


static func _store(key: String, p: Parts) -> Meshes:
	var meshes := Meshes.new()
	meshes.body = p.body.to_mesh()
	if p.spin.triangle_count() > 0:
		meshes.spin = p.spin.to_mesh()
		meshes.pivot = p.pivot
		meshes.speed = p.speed
	_cache[key] = meshes
	return meshes


static func _build(p: Parts, type: String, level: int) -> void:
	match type:
		"command_center":
			_command_center(p, level)


# --- Shared parts --------------------------------------------------------------

## Gold on the top level, `normal` below it.
static func _accent(level: int, top: int, normal: String) -> String:
	return "gold" if level >= top else normal


## A point on a circle of `radius` around the Y axis, at `degrees` from +X towards +Z.
static func _around(radius: float, degrees: float, y: float) -> Vector3:
	var angle := deg_to_rad(degrees)
	return Vector3(radius * cos(angle), y, radius * sin(angle))


static func _scaffold(p: Parts, size: int) -> void:
	var m := p.body
	var n := float(size)
	var half := 0.4 * n
	m.box(Vector3(0.9 * n, 0.12, 0.9 * n), Vector3.ZERO, "hull_dark")
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		m.box(Vector3(0.12, 1.0, 0.12), Vector3(corner.x * half, 0.12, corner.y * half), "hazard")
	for side: float in [-1.0, 1.0]:
		m.box(Vector3(0.9 * n, 0.1, 0.1), Vector3(0, 1.05, side * half), "hazard")
		m.box(Vector3(0.1, 0.1, 0.9 * n), Vector3(side * half, 0.95, 0), "hazard")
	m.strut(Vector3(-half, 0.12, half), Vector3(half, 1.05, half), 0.08, "hazard")


## Unknown types: a hull block with a hazard stripe.
static func _generic(p: Parts, size: int) -> void:
	var n := float(size)
	p.body.box(Vector3(0.8 * n, 0.8, 0.8 * n), Vector3.ZERO, "hull_light")
	p.body.box(Vector3(0.82 * n, 0.14, 0.82 * n), Vector3(0, 0.45, 0), "hazard")


# --- Core ----------------------------------------------------------------------

static func _command_center(p: Parts, level: int) -> void:
	var m := p.body
	var trim := _accent(level, 5, "hull_light")
	var beacon := "glow_gold" if level >= 5 else "glow_cyan"
	m.prism(1.8, 1.72, 0.35, 6, Vector3.ZERO, "hull_dark")
	m.prism(1.72, 1.68, 0.08, 6, Vector3(0, 0.35, 0), trim)
	for i: int in 6:
		m.box(Vector3(0.16, 0.1, 0.16), _around(1.42, 30 + 60 * i, 0.43), "glow_cyan")
	var body_height := 0.9 + 0.18 * level
	m.prism(1.15, 1.0, body_height, 6, Vector3(0, 0.43, 0), "hull")
	var top := 0.43 + body_height
	if level >= 2:
		m.prism(1.1, 1.08, 0.14, 6, Vector3(0, 0.43 + body_height * 0.45, 0), "glow_cyan")
	m.dome(0.85, 0.7, 8, 3, Vector3(0, top, 0), "metal")
	var mast := 0.8 + 0.15 * level
	m.prism(0.06, 0.04, mast, 4, Vector3(0, top + 0.6, 0), "metal")
	m.orb(0.13, 6, 3, Vector3(0, top + 0.72 + mast, 0), beacon)
	for i: int in level - 1:
		var degrees: float = ANTENNAE[i]
		var foot := _around(0.93, degrees, top)
		var height := 0.5 + 0.12 * i
		m.prism(0.04, 0.03, height, 4, foot, "metal")
		m.pyramid(0.1, 0.12, foot + Vector3(0, height, 0), "gold" if level >= 5 else "glow_red")
	if level >= 3:
		var annex := _around(1.2, -45, 0.43)
		m.prism(0.45, 0.4, 0.45, 6, annex, "hull")
		m.dome(0.4, 0.35, 6, 2, annex + Vector3(0, 0.45, 0), "white")
	if level >= 4:
		var annex := _around(1.2, 135, 0.43)
		m.box(Vector3(0.6, 0.55, 0.6), annex, "hull_light", Vector3(0, 45, 0))
		m.box(Vector3(0.64, 0.12, 0.64), annex + Vector3(0, 0.3, 0), "glow_cyan", Vector3(0, 45, 0))
	p.pivot = Vector3(0, top + 0.6 + mast * 0.45, 0)
	p.speed = 0.8
	p.spin.box(Vector3(0.9, 0.05, 0.22), Vector3(0.3, 0, 0), "hull_light")
	p.spin.box(Vector3(0.12, 0.12, 0.28), Vector3(0.75, -0.03, 0), "glow_cyan")
