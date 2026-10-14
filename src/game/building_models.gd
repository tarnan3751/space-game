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
	"drone_bay": [2, 1],
	"metal_extractor": [3, 5],
	"crystal_harvester": [3, 5],
	"antimatter_siphon": [3, 3],
	"metal_silo": [3, 5],
	"crystal_silo": [3, 5],
	"antimatter_vault": [3, 3],
}
## Octagons are turned so their flat sides face along X and Z.
const OCTAGON := Vector3(0, 22.5, 0)
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
		"drone_bay":
			_drone_bay(p)
		"metal_extractor":
			_metal_extractor(p, level)
		"crystal_harvester":
			_crystal_harvester(p, level)
		"antimatter_siphon":
			_antimatter_siphon(p, level)
		"metal_silo":
			_silo(p, level, "metal", "orange", "")
		"crystal_silo":
			_silo(p, level, "hull", "hull_light", "glow_magenta")
		"antimatter_vault":
			_antimatter_vault(p, level)


# --- Shared parts --------------------------------------------------------------

## Gold on the top level, `normal` below it.
static func _accent(level: int, top: int, normal: String) -> String:
	return "gold" if level >= top else normal


## The square slab resource and army buildings stand on.
static func _slab(m: LowPolyMesh, size: float, height: float) -> void:
	m.box(Vector3(0.88 * size, height, 0.88 * size), Vector3.ZERO, "hull_dark")


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


# --- Resources -----------------------------------------------------------------

static func _drone_bay(p: Parts) -> void:
	var m := p.body
	m.prism(0.92, 0.88, 0.15, 8, Vector3.ZERO, "hull_dark", OCTAGON)
	m.ring(0.55, 0.68, 0.04, 12, Vector3(0, 0.15, 0), "hazard")
	for i: int in 4:
		m.box(Vector3(0.1, 0.06, 0.1), _around(0.75, 45 + 90 * i, 0.15), "glow_cyan")
	p.pivot = Vector3(0, 0.95, 0)
	p.speed = 1.6
	var drone := p.spin
	drone.box(Vector3(0.36, 0.12, 0.36), Vector3(0, -0.06, 0), "metal")
	drone.orb(0.08, 6, 3, Vector3(0, -0.1, 0), "glow_cyan")
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		drone.box(Vector3(0.18, 0.03, 0.18), Vector3(corner.x * 0.28, 0.0, corner.y * 0.28), "hull_light")


static func _metal_extractor(p: Parts, level: int) -> void:
	var m := p.body
	var paint := _accent(level, 5, "orange")
	_slab(m, 3, 0.3)
	var height := 1.5 + 0.2 * level
	var tower := Vector3(-0.75, 0.3, -0.75)
	m.box(Vector3(0.5, height, 0.5), tower, paint)
	m.box(Vector3(0.85, 0.35, 0.85), tower + Vector3(0, height, 0), "hull_light")
	var beam_y := 0.3 + height + 0.1
	if level >= 3:
		var left := Vector3(-0.75, 0.3, 1.0)
		var right := Vector3(1.0, 0.3, -0.75)
		m.box(Vector3(0.22, height, 0.22), left, paint)
		m.box(Vector3(0.22, height, 0.22), right, paint)
		m.strut(Vector3(left.x, beam_y - 0.1, left.z), Vector3(right.x, beam_y - 0.1, right.z), 0.24, "hull_light")
	else:
		m.strut(Vector3(-0.6, beam_y, -0.6), Vector3(0.2, beam_y, 0.2), 0.22, "hull_light")
	if level >= 2:
		m.dome(0.38, 0.3, 6, 2, Vector3(0.85, 0.3, 0.85), "metal_dark")
	if level >= 4:
		m.box(Vector3(0.5, 0.45, 0.6), Vector3(-1.0, 0.3, 0.55), "hull")
		m.box(Vector3(0.14, 0.14, 0.14), tower + Vector3(0.3, height + 0.1, 0.3), "glow_orange")
	p.pivot = Vector3(0.12, 0.3, 0.12)
	p.speed = 3.0
	p.spin.prism(0.05, 0.3 + 0.03 * level, 0.75, 5, Vector3.ZERO, "metal")
	p.spin.box(Vector3(0.35, 0.15, 0.35), Vector3(0, 0.75, 0), "metal_dark")
	p.spin.prism(0.07, 0.07, beam_y - 0.3 - 0.9, 4, Vector3(0, 0.9, 0), "metal_dark")


## [x, z, height, radius, tilt x, tilt z] of each crystal shard, in the order levels add them.
const SHARDS := [
	[-0.55, 0.45, 1.5, 0.3, 12, -10],
	[0.6, -0.4, 1.3, 0.26, -12, 12],
	[0.55, 0.7, 1.1, 0.24, 14, 14],
	[-0.75, -0.5, 1.2, 0.25, -10, -14],
	[1.0, 0.15, 0.9, 0.2, 0, 18],
	[-0.1, 1.0, 0.95, 0.2, 18, 0],
	[0.15, -1.0, 0.85, 0.2, -16, 0],
]


static func _crystal_harvester(p: Parts, level: int) -> void:
	var m := p.body
	_slab(m, 3, 0.25)
	for i: int in 2 + level:
		var shard: Array = SHARDS[i]
		var foot := Vector3(shard[0], 0.25, shard[1])
		var height: float = shard[2]
		var radius: float = shard[3]
		m.cone(radius, height, 4, foot, "glow_magenta", Vector3(shard[4], 0, shard[5]))
	m.prism(0.16, 0.11, 1.5, 6, Vector3(0, 0.25, 0), _accent(level, 5, "metal_dark"))
	p.pivot = Vector3(0, 1.75, 0)
	p.speed = 1.2
	p.spin.box(Vector3(1.8, 0.08, 0.14), Vector3.ZERO, "hull_light")
	p.spin.box(Vector3(0.16, 0.16, 0.22), Vector3(0.85, -0.04, 0), "glow_gold" if level >= 5 else "glow_cyan")


static func _antimatter_siphon(p: Parts, level: int) -> void:
	var m := p.body
	m.prism(1.35, 1.2, 0.35, 6, Vector3.ZERO, "hull_dark")
	m.prism(0.8, 0.7, 0.25, 6, Vector3(0, 0.35, 0), "hull")
	var spire := 2.0 + 0.3 * level
	m.prism(0.3, 0.07, spire, 6, Vector3(0, 0.6, 0), "metal")
	m.orb(0.14, 6, 3, Vector3(0, 0.65 + spire, 0), "glow_violet")
	for degrees: float in [30.0, 150.0, 270.0]:
		m.strut(_around(1.0, degrees, 0.35), _around(0.2, degrees, 1.5), 0.12, _accent(level, 3, "hull_light"))
	p.pivot = Vector3(0, 1.5, 0)
	p.speed = 1.4
	p.spin.ring(0.42, 0.62, 0.14, 8, Vector3.ZERO, "glow_violet")
	if level >= 2:
		p.spin.ring(0.3, 0.44, 0.1, 8, Vector3(0, 0.55, 0), "glow_violet")


## Metal and crystal silos: tanks on a slab, more and taller with each level.
static func _silo(p: Parts, level: int, body: String, band: String, window: String) -> void:
	var m := p.body
	_slab(m, 3, 0.25)
	var tanks: Array[Vector2] = [Vector2(-0.55, 0.55), Vector2(0.55, -0.55)]
	if level >= 3:
		tanks.push_front(Vector2(-0.6, -0.6))
	if level >= 4:
		tanks = [Vector2(-0.6, -0.6), Vector2(0.6, -0.6), Vector2(-0.6, 0.6), Vector2(0.6, 0.6)]
	var radius := 0.45 if tanks.size() == 2 else 0.42
	var height := 1.0 + 0.15 * level
	var trim := _accent(level, 5, band)
	for spot: Vector2 in tanks:
		var base := Vector3(spot.x, 0.25, spot.y)
		m.prism(radius, radius, height, 8, base, body)
		m.dome(radius, 0.3, 8, 2, base + Vector3(0, height, 0), "metal")
		m.prism(radius + 0.04, radius + 0.04, 0.12, 8, base + Vector3(0, height * 0.6, 0), trim)
		if window != "":
			m.box(Vector3(0.1, height - 0.45, 0.22), base + _around(radius, 45, 0.2), window, Vector3(0, -45, 0))
	if level >= 2:
		m.strut(Vector3(-0.55, 0.05 + height, 0.55), Vector3(0.55, 0.05 + height, -0.55), 0.16, trim)


static func _antimatter_vault(p: Parts, level: int) -> void:
	var m := p.body
	_slab(m, 3, 0.2)
	var height := 0.9 + 0.2 * level
	m.box(Vector3(1.6, height, 1.6), Vector3(0, 0.2, 0), "hull")
	m.box(Vector3(1.64, 0.07, 1.64), Vector3(0, 0.2 + height * 0.5, 0), "glow_violet")
	m.box(Vector3(0.08, height, 0.08), Vector3(0.8, 0.2, 0), "glow_violet")
	m.box(Vector3(0.08, height, 0.08), Vector3(0, 0.2, 0.8), "glow_violet")
	var top := 0.2 + height
	m.box(Vector3(1.2, 0.15, 1.2), Vector3(0, top, 0), "hull_light")
	if level >= 2:
		m.disc(0.4, 6, Vector3(0, top + 0.151, 0), "glow_violet")
	var pylon := 1.1 + 0.25 * level
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var foot := Vector3(corner.x * 1.08, 0.2, corner.y * 1.08)
		m.prism(0.12, 0.09, pylon, 4, foot, _accent(level, 3, "hull_light"), Vector3(0, 45, 0))
		m.orb(0.12, 6, 2, foot + Vector3(0, pylon + 0.1, 0), "glow_violet")
	if level >= 3:
		m.orb(0.25, 8, 3, Vector3(0, top + 0.6, 0), "glow_violet")
