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
	"hangar": [5, 5],
	"fabricator": [3, 5],
	"heavy_fabricator": [3, 3],
	"research_lab": [3, 5],
	"nanite_foundry": [3, 4],
	"drydock": [4, 2],
	"alliance_beacon": [3, 3],
	"laser_turret": [3, 5],
	"missile_battery": [3, 5],
	"plasma_mortar": [3, 4],
	"shield_generator": [3, 4],
	"flak_cannon": [3, 4],
	"arc_tower": [3, 4],
	"cloaked_sentry": [2, 3],
	"gravity_well": [2, 3],
	"emp_tower": [3, 3],
	"railgun": [3, 3],
	"ion_beam": [2, 2],
	"orbital_cannon": [4, 2],
	"proximity_mine": [1, 3],
	"grav_trap": [1, 2],
	"flak_mine": [1, 3],
	"mega_mine": [2, 2],
	"barrier_wall": [1, 5],
}
## The glow strip of a wall, by level.
const WALL_GLOWS := ["glow_cyan", "glow_green", "glow_magenta", "glow_red", "glow_gold"]
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
		"hangar":
			_hangar(p, level)
		"fabricator":
			_fabricator(p, level)
		"heavy_fabricator":
			_heavy_fabricator(p, level)
		"research_lab":
			_research_lab(p, level)
		"nanite_foundry":
			_nanite_foundry(p, level)
		"drydock":
			_drydock(p, level)
		"alliance_beacon":
			_alliance_beacon(p, level)
		"laser_turret":
			_laser_turret(p, level)
		"missile_battery":
			_missile_battery(p, level)
		"plasma_mortar":
			_plasma_mortar(p, level)
		"shield_generator":
			_shield_generator(p, level)
		"flak_cannon":
			_flak_cannon(p, level)
		"arc_tower":
			_arc_tower(p, level)
		"cloaked_sentry":
			_cloaked_sentry(p, level)
		"gravity_well":
			_gravity_well(p, level)
		"emp_tower":
			_emp_tower(p, level)
		"railgun":
			_railgun(p, level)
		"ion_beam":
			_ion_beam(p, level)
		"orbital_cannon":
			_orbital_cannon(p, level)
		"proximity_mine":
			_proximity_mine(p, level)
		"grav_trap":
			_grav_trap(p, level)
		"flak_mine":
			_flak_mine(p, level)
		"mega_mine":
			_mega_mine(p, level)
		"barrier_wall":
			_barrier_wall(p, level)


# --- Shared parts --------------------------------------------------------------

## Gold on the top level, `normal` below it.
static func _accent(level: int, top: int, normal: String) -> String:
	return "gold" if level >= top else normal


## The square slab resource and army buildings stand on.
static func _slab(m: LowPolyMesh, size: float, height: float) -> void:
	m.box(Vector3(0.88 * size, height, 0.88 * size), Vector3.ZERO, "hull_dark")


## The octagonal plinth defences stand on.
static func _plinth(m: LowPolyMesh, size: float, height: float) -> void:
	m.prism(0.47 * size, 0.44 * size, height, 8, Vector3.ZERO, "hull_dark", OCTAGON)


## A point on a circle of `radius` around the Y axis, at `degrees` from +X towards +Z.
static func _around(radius: float, degrees: float, y: float) -> Vector3:
	var angle := deg_to_rad(degrees)
	return Vector3(radius * cos(angle), y, radius * sin(angle))


## A flat rectangle facing up, turned `yaw` degrees: stripes and markings, two triangles.
static func _plate(m: LowPolyMesh, size: Vector2, pos: Vector3, color: String, yaw: float) -> void:
	var turn := Vector3(0, yaw, 0)
	var h := size * 0.5
	m.polygon(PackedVector3Array([
		pos + LowPolyMesh.turn(Vector3(-h.x, 0, -h.y), turn),
		pos + LowPolyMesh.turn(Vector3(-h.x, 0, h.y), turn),
		pos + LowPolyMesh.turn(Vector3(h.x, 0, h.y), turn),
		pos + LowPolyMesh.turn(Vector3(h.x, 0, -h.y), turn),
	]), color)


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


# --- Army ----------------------------------------------------------------------

static func _hangar(p: Parts, level: int) -> void:
	var m := p.body
	_slab(m, 5, 0.15)
	var height := 1.4 + 0.15 * level
	var front := 1.0
	m.box(Vector3(4.0, height, 3.0), Vector3(0, 0.15, -0.5), "hull")
	var stripe := _accent(level, 5, "hazard")
	for x: float in [-1.2, 0.0, 1.2]:
		m.box(Vector3(0.22, 0.04, 2.8), Vector3(x, 0.15 + height, -0.5), stripe)
	for i: int in 3:
		_plate(m, Vector2(0.18, 0.7), Vector3(-1.2 + 1.2 * i, 0.151, 1.6), "hazard", 30)
	var bays := mini(level, 3)
	var bay := 3.8 / bays
	for i: int in bays:
		var x := -1.9 + bay * (i + 0.5)
		m.box(Vector3(bay - 0.3, height - 0.35, 0.1), Vector3(x, 0.15, front), "window")
		m.box(Vector3(bay - 0.3, 0.08, 0.08), Vector3(x, height - 0.1, front + 0.02), "glow_orange")
	for i: int in bays + 1:
		m.box(Vector3(0.2, height, 0.2), Vector3(-1.9 + bay * i, 0.15, front), "hull_light")
	if level >= 4:
		var tower := Vector3(1.5, 0.15, -1.55)
		m.box(Vector3(0.9, height + 1.0, 0.9), tower, "hull_light")
		m.box(Vector3(0.94, 0.2, 0.94), tower + Vector3(0, height + 0.6, 0), "glow_blue")
		m.prism(0.04, 0.03, 0.6, 4, tower + Vector3(0, height + 1.0, 0), "metal")


static func _fabricator(p: Parts, level: int) -> void:
	var m := p.body
	var paint := _accent(level, 5, "orange")
	_slab(m, 3, 0.2)
	var height := 1.0 + 0.1 * level
	var body := Vector3(-0.25, 0.2, -0.3)
	m.box(Vector3(2.0, height, 1.7), body, "hull_light")
	m.box(Vector3(2.04, 0.12, 1.74), body + Vector3(0, height * 0.6, 0), paint)
	m.box(Vector3(0.8, 0.7, 0.08), Vector3(-0.25, 0.2, 0.56), "window")
	var top := 0.2 + height
	var stack := 1.0 + 0.15 * level
	m.prism(0.2, 0.17, stack, 6, Vector3(-0.85, top, -0.8), "metal_dark")
	m.prism(0.19, 0.19, 0.1, 6, Vector3(-0.85, top + stack - 0.12, -0.8), "glow_orange")
	if level >= 2:
		m.prism(0.16, 0.14, stack * 0.7, 6, Vector3(-0.35, top, -0.85), "metal_dark")
		m.prism(0.15, 0.15, 0.08, 6, Vector3(-0.35, top + stack * 0.7 - 0.1, -0.85), "glow_orange")
	m.box(Vector3(0.7, 0.3, 0.45), Vector3(0.95, 0.2, 0.15), "hull_dark")
	m.box(Vector3(0.7, 0.03, 0.08), Vector3(0.95, 0.5, 0.0), paint)
	m.box(Vector3(0.7, 0.03, 0.08), Vector3(0.95, 0.5, 0.3), paint)
	m.box(Vector3(0.25, 0.25, 0.25), Vector3(1.05, 0.5, 0.15), "orange")
	if level >= 3:
		m.wedge(Vector3(1.9, 0.35, 0.7), body + Vector3(0.0, height, 0.4), "hull")
		m.wedge(Vector3(1.9, 0.35, 0.7), body + Vector3(0.0, height, -0.3), "hull")
	if level >= 4:
		m.box(Vector3(0.14, 0.9, 0.14), Vector3(0.55, top, -0.8), "hull_dark")
		m.strut(Vector3(0.55, top + 0.85, -0.8), Vector3(1.1, top + 0.6, 0.15), 0.1, paint)


static func _heavy_fabricator(p: Parts, level: int) -> void:
	var m := p.body
	var paint := _accent(level, 3, "red")
	_slab(m, 3, 0.2)
	var height := 1.3 + 0.15 * level
	m.box(Vector3(2.4, height, 2.0), Vector3(-0.1, 0.2, -0.2), "hull_dark")
	m.box(Vector3(2.44, 0.14, 2.04), Vector3(-0.1, 0.2 + height * 0.7, -0.2), paint)
	var top := 0.2 + height
	m.box(Vector3(1.4, 0.5, 1.2), Vector3(-0.4, top, -0.5), "hull")
	m.box(Vector3(1.2, 0.95, 0.08), Vector3(0.1, 0.2, 0.81), "window")
	m.box(Vector3(1.2, 0.08, 0.06), Vector3(0.1, 1.2, 0.84), "glow_red")
	var stack := 1.1 + 0.2 * level
	var stacks: Array[float] = [-0.9, 0.55]
	if level >= 2:
		stacks.append(-0.2)
	for x: float in stacks:
		m.prism(0.22, 0.19, stack, 6, Vector3(x, top, -0.95), "metal_dark")
		m.prism(0.21, 0.21, 0.1, 6, Vector3(x, top + stack - 0.12, -0.95), "glow_red")


static func _research_lab(p: Parts, level: int) -> void:
	var m := p.body
	m.prism(1.42, 1.32, 0.3, 8, Vector3.ZERO, "hull_dark", OCTAGON)
	if level >= 5:
		m.prism(1.44, 1.42, 0.06, 8, Vector3(0, 0.3, 0), "gold", OCTAGON)
	m.prism(1.05, 1.0, 0.5, 8, Vector3(0, 0.3, 0), "hull_light", OCTAGON)
	m.prism(1.03, 1.03, 0.14, 8, Vector3(0, 0.48, 0), "glow_blue", OCTAGON)
	var dome := 0.85 + 0.05 * level
	m.dome(0.95, dome, 8, 3, Vector3(0, 0.8, 0), "white")
	var post := Vector3(0.82, 0.3, -0.82)
	var reach := 1.0 + 0.1 * level
	m.prism(0.08, 0.06, reach, 4, post, "metal")
	var dish := 1.3 if level >= 3 else 1.0
	var aim := Vector3(40, 135, 0)
	var centre := post + Vector3(0, reach, 0)
	m.lathe(PackedVector2Array([
		Vector2(0.06, 0), Vector2(0.45 * dish, 0.18 * dish), Vector2(0.4 * dish, 0.21 * dish), Vector2(0, 0.06),
	]), 8, centre, "white", aim)
	m.cone(0.05, 0.35, 4, centre + LowPolyMesh.turn(Vector3(0, 0.05, 0), aim), "glow_blue", aim)
	if level >= 2:
		var annex := Vector3(-0.85, 0.3, 0.85)
		m.prism(0.38, 0.35, 0.35, 6, annex, "hull_light")
		m.dome(0.36, 0.3, 6, 2, annex + Vector3(0, 0.35, 0), "white")
	if level >= 4:
		m.prism(0.22, 0.18, 0.25, 8, Vector3(0, 0.75 + dome, 0), "glow_blue")


static func _nanite_foundry(p: Parts, level: int) -> void:
	var m := p.body
	_slab(m, 3, 0.2)
	var vat := Vector3(-0.3, 0.2, -0.3)
	m.lathe(PackedVector2Array([
		Vector2(0.75, 0), Vector2(0.72, 1.1), Vector2(0.6, 1.1), Vector2(0.6, 0.95),
	]), 8, vat, "metal_dark", OCTAGON)
	m.disc(0.6, 8, vat + Vector3(0, 0.95, 0), "glow_green", OCTAGON)
	m.ring(0.73, 0.82, 0.12, 8, vat + Vector3(0, 0.5, 0), "glow_green", OCTAGON)
	if level >= 4:
		m.ring(0.6, 0.76, 0.06, 8, vat + Vector3(0, 1.1, 0), "gold", OCTAGON)
	var pump := Vector3(0.85, 0.2, 0.75)
	m.box(Vector3(0.6, 0.55, 0.6), pump, "hull_light")
	m.strut(vat + Vector3(0.5, 0.75, 0.5), pump + Vector3(-0.1, 0.4, -0.1), 0.14, "metal")
	m.prism(0.08, 0.08, 0.5, 4, pump + Vector3(0.15, 0.55, 0.15), "metal")
	if level >= 2:
		var small := Vector3(0.85, 0.2, -0.85)
		m.prism(0.35, 0.33, 0.7, 8, small, "metal_dark", OCTAGON)
		m.disc(0.3, 8, small + Vector3(0, 0.701, 0), "glow_green", OCTAGON)
		m.strut(small + Vector3(-0.2, 0.45, 0.1), vat + Vector3(0.6, 0.45, -0.3), 0.12, "metal")
	if level >= 3:
		m.prism(0.15, 0.12, 1.5, 6, Vector3(-1.0, 0.2, 0.9), "hull")
		m.strut(Vector3(-0.95, 0.9, 0.85), vat + Vector3(-0.3, 0.9, 0.5), 0.1, "metal")


static func _drydock(p: Parts, level: int) -> void:
	var m := p.body
	_slab(m, 4, 0.15)
	for z: float in [-0.85, 0.85]:
		m.box(Vector3(3.2, 0.2, 0.18), Vector3(0, 0.15, z), "metal_dark")
	for x: float in [-0.9, 0.0, 0.8]:
		m.box(Vector3(0.3, 0.4, 0.9), Vector3(x, 0.15, 0), "hull_dark")
	m.box(Vector3(2.3, 0.55, 0.9), Vector3(-0.25, 0.55, 0), "hull_light")
	m.wedge(Vector3(0.9, 0.55, 0.7), Vector3(1.25, 0.55, 0), "hull_light", Vector3(0, 90, 0))
	m.box(Vector3(0.6, 0.35, 0.5), Vector3(-0.7, 1.1, 0), "hull")
	m.box(Vector3(0.62, 0.08, 0.52), Vector3(-0.7, 1.32, 0), "glow_blue")
	for z: float in [-0.22, 0.22]:
		m.box(Vector3(0.08, 0.22, 0.25), Vector3(-1.42, 0.7, z), "glow_cyan")
	var frame := _accent(level, 2, "hazard")
	var frames: Array[float] = [-1.0, 0.25]
	if level >= 2:
		frames.append(1.25)
	for x: float in frames:
		for z: float in [-1.15, 1.15]:
			m.box(Vector3(0.15, 1.7, 0.15), Vector3(x, 0.15, z), frame)
		m.box(Vector3(0.15, 0.15, 2.45), Vector3(x, 1.85, 0), frame)


static func _alliance_beacon(p: Parts, level: int) -> void:
	var m := p.body
	m.prism(1.3, 1.2, 0.3, 6, Vector3.ZERO, "hull_dark")
	m.box(Vector3(0.9, 0.3, 0.9), Vector3(0, 0.3, 0), "hull", Vector3(0, 45, 0))
	var height := 2.0 + 0.3 * level
	m.prism(0.38, 0.12, height, 4, Vector3(0, 0.6, 0), _accent(level, 3, "hull_light"), Vector3(0, 45, 0))
	m.box(Vector3(0.6, 0.06, 0.6), Vector3(0, 0.6 + height * 0.4, 0), "hazard", Vector3(0, 45, 0))
	if level >= 2:
		for degrees: float in [-45.0, 135.0]:
			var arm := _around(0.55, degrees, 0.6 + height * 0.6)
			m.strut(Vector3(0, arm.y, 0), arm, 0.06, "metal")
			m.disc(0.2, 6, arm, "white", Vector3(0, -degrees, -60))
	var beacon := "glow_gold" if level >= 3 else "glow_cyan"
	m.orb(0.22 + 0.03 * level, 8, 3, Vector3(0, 0.75 + height + 0.1, 0), beacon)


# --- Defence -------------------------------------------------------------------

static func _laser_turret(p: Parts, level: int) -> void:
	var m := p.body
	_plinth(m, 3, 0.45)
	m.prism(1.0, 0.95, 0.12, 8, Vector3(0, 0.45, 0), "hull", OCTAGON)
	p.pivot = Vector3(0, 0.57, 0)
	p.speed = 0.4
	var head := p.spin
	var radius := 0.6 + 0.03 * level
	head.prism(radius, radius - 0.05, 0.35, 8, Vector3.ZERO, "hull_light")
	head.dome(radius - 0.05, 0.3, 8, 2, Vector3(0, 0.35, 0), "hull_light")
	if level >= 5:
		head.prism(radius + 0.03, radius + 0.03, 0.08, 8, Vector3(0, 0.15, 0), "gold")
	if level >= 2:
		head.box(Vector3(0.5, 0.28, 0.3), Vector3(0, 0.22, radius - 0.1), "hull")
	if level >= 4:
		for x: float in [-1.0, 1.0]:
			head.box(Vector3(0.12, 0.3, 0.5), Vector3(x * (radius + 0.02), 0.05, -0.1), "hull_dark")
	var length := 0.85 + 0.05 * level
	var barrels: Array[float] = [0.0]
	if level >= 3:
		barrels = [-0.16, 0.16]
	for x: float in barrels:
		head.prism(0.09, 0.08, length, 6, Vector3(x, 0.36, 0.25), "metal", Vector3(90, 0, 0))
		head.orb(0.1, 6, 3, Vector3(x, 0.36, 0.3 + length), "glow_cyan")


static func _missile_battery(p: Parts, level: int) -> void:
	var m := p.body
	_plinth(m, 3, 0.4)
	m.box(Vector3(0.9, 0.45, 0.9), Vector3(0, 0.4, 0), "hull", Vector3(0, 45, 0))
	var columns := 2 if level < 3 else (3 if level < 5 else 4)
	var width := columns * 0.38 + 0.2
	var aim := Vector3(-30, 45, 0)
	var base := Vector3(0, 0.85, 0)
	m.box(Vector3(width, 0.85, 1.0), base, "hull_light", aim)
	m.box(Vector3(width + 0.04, 0.1, 1.04), base + LowPolyMesh.turn(Vector3(0, 0.4, 0), aim),
		_accent(level, 5, "red"), aim)
	var tube_aim := aim + Vector3(90, 0, 0)
	for column: int in columns:
		for row: int in 2:
			var face := Vector3(-0.19 * (columns - 1) + 0.38 * column, 0.22 + 0.4 * row, 0.5)
			var mouth := base + LowPolyMesh.turn(face, aim)
			m.prism(0.14, 0.14, 0.06, 6, mouth, "window", tube_aim)
			m.cone(0.08, 0.14, 4, mouth, "glow_red", tube_aim)


static func _plasma_mortar(p: Parts, level: int) -> void:
	var m := p.body
	_plinth(m, 3, 0.35)
	m.prism(0.6, 0.55, 0.3, 8, Vector3(0, 0.35, 0), "hull", OCTAGON)
	var rim := 1.0 + 0.05 * level
	var bowl := Vector3(0, 0.65, 0)
	m.lathe(PackedVector2Array([
		Vector2(0.6, 0), Vector2(rim, 0.75), Vector2(rim - 0.15, 0.8), Vector2(0.45, 0.25),
	]), 10, bowl, "metal_dark")
	m.disc(0.46, 10, bowl + Vector3(0, 0.25, 0), "glow_orange")
	m.orb(0.32, 6, 3, bowl + Vector3(0, 0.45, 0), "glow_orange")
	if level >= 2:
		for degrees: float in [0.0, 90.0, 180.0, 270.0]:
			m.strut(_around(1.05, degrees + 45, 0.35), _around(0.85, degrees + 45, 1.15), 0.12, "hull_light")
	if level >= 3:
		m.ring(rim - 0.15, rim + 0.03, 0.06, 10, bowl + Vector3(0, 0.8, 0), _accent(level, 4, "hazard"))


static func _shield_generator(p: Parts, level: int) -> void:
	var m := p.body
	_plinth(m, 3, 0.25)
	m.prism(0.5, 0.45, 0.2, 8, Vector3(0, 0.25, 0), "hull", OCTAGON)
	var top := Vector3(0, 1.6, 0)
	for degrees: float in [30.0, 150.0, 270.0]:
		var foot := _around(1.0, degrees, 0.25)
		m.strut(foot, top, 0.14, "hull_light")
		m.box(Vector3(0.3, 0.12, 0.3), foot - Vector3(0, 0.02, 0), _accent(level, 4, "hull"))
	if level >= 2:
		m.prism(0.3, 0.2, 0.25, 6, top - Vector3(0, 0.1, 0), "metal")
	var radius := 0.5 + 0.06 * level
	var centre := top + Vector3(0, radius * 0.8, 0)
	m.orb(radius, 8, 4, centre, "glow_green")
	if level >= 3:
		m.ring(radius + 0.05, radius + 0.2, 0.08, 10, centre - Vector3(0, 0.04, 0), "metal")


static func _flak_cannon(p: Parts, level: int) -> void:
	var m := p.body
	_plinth(m, 3, 0.4)
	m.prism(0.5, 0.38, 1.0, 6, Vector3(0, 0.4, 0), "hull")
	p.pivot = Vector3(0, 1.4, 0)
	p.speed = 0.5
	var head := p.spin
	head.box(Vector3(0.95, 0.6, 0.8), Vector3(0, 0, -0.15), "hull_light")
	if level >= 4:
		head.box(Vector3(0.97, 0.1, 0.82), Vector3(0, 0.4, -0.15), "gold")
	for x: float in [-0.2, 0.2]:
		for z: float in [-0.05, 0.2]:
			var muzzle := Vector3(x, 0.45, z) + LowPolyMesh.turn(Vector3(0, 1.3, 0), Vector3(35, 0, 0))
			head.prism(0.09, 0.07, 1.3, 6, Vector3(x, 0.45, z), "metal", Vector3(35, 0, 0))
			head.box(Vector3(0.12, 0.1, 0.12), muzzle - Vector3(0, 0.05, 0), "glow_orange")
	if level >= 2:
		head.box(Vector3(0.3, 0.2, 0.3), Vector3(0, 0.6, -0.4), "hull_dark")
	if level >= 3:
		for x: float in [-0.6, 0.6]:
			head.prism(0.25, 0.25, 0.24, 8, Vector3(x - 0.12 * signf(x), 0.3, -0.15), "hull_dark",
				Vector3(0, 0, -90 * signf(x)))


static func _arc_tower(p: Parts, level: int) -> void:
	var m := p.body
	_plinth(m, 3, 0.35)
	var height := 1.4 + 0.15 * level
	m.prism(0.4, 0.18, height, 6, Vector3(0, 0.35, 0), "hull")
	var coil := _accent(level, 4, "metal")
	var coils := 1 + level
	for i: int in coils:
		var t := (i + 0.5) / coils
		var radius := lerpf(0.4, 0.18, t)
		m.ring(radius, radius + 0.2, 0.08, 6, Vector3(0, 0.35 + height * t, 0), coil)
	var top := 0.35 + height
	m.prism(0.12, 0.1, 0.2, 6, Vector3(0, top, 0), "metal_dark")
	var orb := 0.32 + 0.04 * level
	m.orb(orb, 8, 4, Vector3(0, top + 0.2 + orb * 0.9, 0), "glow_cyan")


static func _cloaked_sentry(p: Parts, level: int) -> void:
	var m := p.body
	m.prism(0.92, 0.85, 0.25, 8, Vector3.ZERO, "hull_dark", OCTAGON)
	if level >= 3:
		m.prism(0.93, 0.93, 0.05, 8, Vector3(0, 0.18, 0), "gold", OCTAGON)
	m.prism(0.62, 0.6, 0.06, 8, Vector3(0, 0.25, 0), "hull", OCTAGON)
	for yaw: float in [45.0, -45.0]:
		m.box(Vector3(1.1, 0.03, 0.06), Vector3(0, 0.31, 0), "glow_cyan", Vector3(0, yaw, 0))
	if level >= 2:
		m.ring(0.6, 0.67, 0.04, 8, Vector3(0, 0.25, 0), "glow_cyan", OCTAGON)


static func _gravity_well(p: Parts, level: int) -> void:
	var m := p.body
	m.prism(0.92, 0.85, 0.2, 8, Vector3.ZERO, "hull_dark", OCTAGON)
	for side: float in [-1.0, 1.0]:
		m.box(Vector3(0.14, 1.2, 0.14), Vector3(side * 0.48, 0.2, -side * 0.48), _accent(level, 3, "hull_light"),
			Vector3(0, 45, 0))
		m.box(Vector3(0.2, 0.08, 0.2), Vector3(side * 0.48, 1.4, -side * 0.48), "glow_violet", Vector3(0, 45, 0))
	m.prism(0.25, 0.18, 0.35, 6, Vector3(0, 0.2, 0), "hull")
	m.orb(0.15, 6, 3, Vector3(0, 1.0, 0), "glow_violet")
	p.pivot = Vector3(0, 1.0, 0)
	p.speed = 1.5
	p.spin.ring(0.45, 0.58, 0.1, 10, Vector3(0, 0, -0.05), "glow_violet", Vector3(90, 0, 0))
	if level >= 2:
		p.spin.ring(0.28, 0.38, 0.08, 8, Vector3(0.04, 0, 0), "glow_violet", Vector3(0, 0, 90))


static func _emp_tower(p: Parts, level: int) -> void:
	var m := p.body
	_plinth(m, 3, 0.35)
	var height := 1.9 + 0.3 * level
	m.prism(0.5, 0.28, height, 6, Vector3(0, 0.35, 0), "hull")
	var top := 0.35 + height
	m.ring(0.28, 0.62, 0.16, 8, Vector3(0, top - 0.35, 0), "hazard")
	if level >= 2:
		m.ring(0.38, 0.6, 0.1, 8, Vector3(0, 0.35 + height * 0.45, 0), _accent(level, 3, "hazard"))
	m.dome(0.3, 0.3, 6, 2, Vector3(0, top, 0), "glow_blue")
	if level >= 3:
		for degrees: float in [45.0, 135.0, 225.0, 315.0]:
			m.pyramid(0.12, 0.35, _around(0.5, degrees, top - 0.19), "gold")


static func _railgun(p: Parts, level: int) -> void:
	var m := p.body
	_plinth(m, 3, 0.35)
	m.box(Vector3(1.1, 0.5, 1.1), Vector3(0, 0.35, 0), "hull", Vector3(0, 45, 0))
	if level >= 2:
		for side: float in [-1.0, 1.0]:
			m.box(Vector3(0.3, 0.4, 0.5), Vector3(side * 0.55, 0.35, side * 0.55), "hull_light", Vector3(0, 45, 0))
	var back := Vector3(-0.85, 0.95, 0.85)
	var muzzle := Vector3(0.95 + 0.05 * level, 1.15, -0.95 - 0.05 * level)
	m.box(Vector3(0.6, 0.4, 0.6), back + Vector3(0.2, -0.15, -0.2), "hull_dark", Vector3(0, 45, 0))
	var side_offset := Vector3(0.085, 0, 0.085)
	var rail := _accent(level, 3, "metal")
	m.strut(back + side_offset, muzzle + side_offset, 0.1, rail)
	m.strut(back - side_offset, muzzle - side_offset, 0.1, rail)
	for t: float in [0.35, 0.55, 0.75]:
		m.box(Vector3(0.2, 0.14, 0.2), back.lerp(muzzle, t) - Vector3(0, 0.07, 0), "glow_cyan", Vector3(0, 45, 0))


static func _ion_beam(p: Parts, level: int) -> void:
	var m := p.body
	m.prism(0.9, 0.85, 0.25, 6, Vector3.ZERO, "hull_dark")
	var height := 1.1 + 0.3 * level
	m.prism(0.2, 0.13, height, 6, Vector3(0, 0.25, 0), "hull_light")
	var top := 0.25 + height
	m.ring(0.13, 0.3, 0.12, 8, Vector3(0, top - 0.1, 0), _accent(level, 2, "metal"))
	m.orb(0.22, 8, 3, Vector3(0, top + 0.2, 0), "glow_red")
	if level >= 2:
		m.cone(0.06, 0.3, 4, Vector3(0, top + 0.38, 0), "gold")


static func _orbital_cannon(p: Parts, level: int) -> void:
	var m := p.body
	m.prism(1.85, 1.75, 0.4, 8, Vector3.ZERO, "hull_dark", OCTAGON)
	m.prism(1.25, 1.15, 0.35, 8, Vector3(0, 0.4, 0), "hull", OCTAGON)
	m.prism(0.4, 0.3, 0.5, 6, Vector3(0, 0.75, 0), "hull_light")
	var dish := 1.2 if level < 2 else 1.4
	var aim := Vector3(40, 135, 0)
	var centre := Vector3(0, 1.25, 0)
	m.lathe(PackedVector2Array([
		Vector2(0.15, 0), Vector2(dish, 0.45), Vector2(dish - 0.12, 0.5), Vector2(0, 0.15),
	]), 10, centre, "white", aim)
	m.cone(0.12, 1.2, 6, centre + LowPolyMesh.turn(Vector3(0, 0.15, 0), aim), "glow_blue", aim)
	if level >= 2:
		m.ring(dish - 0.12, dish + 0.02, 0.06, 10, centre + LowPolyMesh.turn(Vector3(0, 0.45, 0), aim), "gold", aim)
		for degrees: float in [45.0, 225.0]:
			var pylon := _around(1.45, degrees, 0.4)
			m.prism(0.14, 0.1, 0.8, 4, pylon, "hull_light")
			m.pyramid(0.16, 0.2, pylon + Vector3(0, 0.8, 0), "glow_blue")


# --- Traps (at most 40 triangles) ------------------------------------------------

static func _proximity_mine(p: Parts, level: int) -> void:
	var m := p.body
	m.prism(0.38, 0.34, 0.1, 6, Vector3.ZERO, "hull_light")
	var dots := level + 1
	for i: int in dots:
		m.pyramid(0.1, 0.06, _around(0.2, 360.0 * i / dots, 0.1), "glow_gold" if level >= 3 else "glow_red")


static func _grav_trap(p: Parts, level: int) -> void:
	var m := p.body
	m.box(Vector3(0.76, 0.06, 0.76), Vector3.ZERO, "hull")
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		m.pyramid(0.14, 0.4, Vector3(corner.x * 0.27, 0.06, corner.y * 0.27), _accent(level, 2, "metal"))
	m.pyramid(0.24, 0.1, Vector3(0, 0.06, 0), "glow_violet")


static func _flak_mine(p: Parts, level: int) -> void:
	var m := p.body
	m.prism(0.14, 0.12, 0.15, 4, Vector3.ZERO, "hull_dark")
	m.orb(0.27, 5, 3, Vector3(0, 0.38, 0), "hull")
	var dot := "glow_gold" if level >= 3 else "glow_orange"
	for i: int in mini(level, 2):
		m.pyramid(0.14, 0.08, _around(0.14 * i, 0, 0.58), dot)


static func _mega_mine(p: Parts, level: int) -> void:
	var m := p.body
	m.prism(0.8, 0.75, 0.12, 6, Vector3.ZERO, "metal_dark")
	for offset: float in [-0.3, 0.0, 0.3]:
		_plate(m, Vector2(0.12, 0.7), Vector3(offset, 0.121, 0), "hazard", 30)
	for i: int in 3:
		m.pyramid(0.1, 0.05, _around(0.55, 90 + 120 * i, 0.12), "glow_gold" if level >= 2 else "glow_red")


# --- Walls (at most 40 triangles) ------------------------------------------------

static func _barrier_wall(p: Parts, level: int) -> void:
	var m := p.body
	var height := 0.5 + 0.06 * level
	m.box(Vector3(0.86, height, 0.86), Vector3.ZERO, "hull")
	m.box(Vector3(0.74, 0.22, 0.74), Vector3(0, height, 0), "hull_light")
	m.box(Vector3(0.76, 0.06, 0.34), Vector3(0, height + 0.2, 0), WALL_GLOWS[level - 1])
