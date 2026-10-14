class_name BuildingModels
extends RefCounted
## Placeholder low-poly models built from primitive meshes, so the game runs with no
## art assets. Replace per type with imported models later; keep the same contract:
## origin at the footprint centre on the ground, +Y up, fits inside size x size cells.
##
## Any node with the SPIN_META meta rotates around Y while the building is active.

const SPIN_META := "spin_speed"

const HULL := Color("3b3f58")
const HULL_LIGHT := Color("6a7090")
const METAL := Color("c8d3e0")
const ACCENT := Color("4fd6e6")
const ORANGE := Color("f29a4a")
const CRYSTAL := Color("d27cff")
const HAZARD := Color("f2c94c")

static var _materials: Dictionary = {}


## The placeholders do not vary with the level yet.
static func create(type: String, _level: int, size: int) -> Node3D:
	var root := Node3D.new()
	var s := float(size)
	match type:
		"command_center":
			_command_center(root, s)
		"metal_extractor":
			_extractor(root, s)
		"crystal_harvester":
			_harvester(root, s)
		"metal_silo":
			_silo(root, s, METAL, 0.0)
		"crystal_silo":
			_silo(root, s, CRYSTAL, 0.8)
		"drone_bay":
			_drone_bay(root, s)
		"laser_turret":
			_turret(root, s)
		_:
			_box(root, Vector3(0.8 * s, 0.8, 0.8 * s), Vector3(0, 0.4, 0), HULL_LIGHT)
	return root


## Shown while a building is first being constructed.
static func create_scaffold(size: int) -> Node3D:
	var root := Node3D.new()
	var s := float(size)
	var half := 0.4 * s
	_box(root, Vector3(0.9 * s, 0.12, 0.9 * s), Vector3(0, 0.06, 0), HULL)
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		_box(root, Vector3(0.12, 1.0, 0.12), Vector3(corner.x * half, 0.6, corner.y * half), HAZARD)
	for side: float in [-1.0, 1.0]:
		_box(root, Vector3(0.9 * s, 0.1, 0.1), Vector3(0, 1.1, side * half), HAZARD)
	return root


static func material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var key := "%s/%.2f" % [color.to_html(), glow]
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.75
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	_materials[key] = mat
	return mat


# --- Models --------------------------------------------------------------------

static func _command_center(root: Node3D, s: float) -> void:
	_cylinder(root, 0.48 * s, 0.48 * s, 0.5, 6, Vector3(0, 0.25, 0), HULL)
	_cylinder(root, 0.3 * s, 0.34 * s, 0.9, 6, Vector3(0, 0.95, 0), HULL_LIGHT)
	_sphere(root, 0.22 * s, Vector3(0, 1.4, 0), METAL)
	_cylinder(root, 0.04, 0.04, 1.2, 4, Vector3(0, 2.3, 0), METAL)
	_sphere(root, 0.12, Vector3(0, 2.95, 0), ACCENT, 2.0)
	var radar := _spinner(root, Vector3(0, 2.05, 0), 0.8)
	_box(radar, Vector3(0.9, 0.06, 0.25), Vector3(0.3, 0, 0), ACCENT, 0.6)
	for i: int in 6:
		var angle := TAU * i / 6.0
		_box(root, Vector3(0.18, 0.1, 0.18),
			Vector3(cos(angle) * 0.44 * s, 0.55, sin(angle) * 0.44 * s), ACCENT, 1.5)


static func _extractor(root: Node3D, s: float) -> void:
	_box(root, Vector3(0.85 * s, 0.3, 0.85 * s), Vector3(0, 0.15, 0), HULL)
	_box(root, Vector3(0.45, 1.8, 0.45), Vector3(-0.3, 1.2, -0.3), ORANGE)
	_box(root, Vector3(0.9, 0.35, 0.9), Vector3(-0.3, 2.2, -0.3), HULL_LIGHT)
	var drill := _spinner(root, Vector3(0.55, 0.3, 0.55), 3.0)
	_cylinder(drill, 0.38, 0.02, 0.9, 5, Vector3(0, 0.45, 0), METAL)
	_sphere(root, 0.32, Vector3(-0.75, 0.35, 0.6), Color("8d95a8"))


static func _harvester(root: Node3D, s: float) -> void:
	_box(root, Vector3(0.85 * s, 0.25, 0.85 * s), Vector3(0, 0.125, 0), HULL)
	var crystals := [
		[Vector3(0.0, 0.25, 0.0), 1.7, 0.32, Vector3(0, 0, 0)],
		[Vector3(-0.5, 0.25, 0.35), 1.1, 0.24, Vector3(14, 0, -10)],
		[Vector3(0.45, 0.25, -0.4), 0.9, 0.22, Vector3(-12, 0, 12)],
	]
	for spec: Array in crystals:
		var height: float = spec[1]
		var base: Vector3 = spec[0]
		var shard := _cylinder(root, 0.0, spec[2], height, 4, base + Vector3(0, height * 0.5, 0), CRYSTAL, 1.2)
		shard.rotation_degrees = spec[3]
	var arm := _spinner(root, Vector3(0, 1.3, 0), 1.2)
	_box(arm, Vector3(1.6, 0.08, 0.14), Vector3.ZERO, HULL_LIGHT)
	_sphere(arm, 0.1, Vector3(0.8, 0, 0), ACCENT, 1.5)


static func _silo(root: Node3D, s: float, tank_color: Color, glow: float) -> void:
	_box(root, Vector3(0.85 * s, 0.25, 0.85 * s), Vector3(0, 0.125, 0), HULL)
	for x: float in [-0.55, 0.55]:
		_cylinder(root, 0.5, 0.5, 1.4, 8, Vector3(x, 0.95, 0), tank_color, glow)
		_sphere(root, 0.5, Vector3(x, 1.65, 0), METAL)
	_box(root, Vector3(1.6, 0.18, 0.3), Vector3(0, 1.2, 0), ORANGE)


static func _drone_bay(root: Node3D, s: float) -> void:
	_cylinder(root, 0.46 * s, 0.48 * s, 0.15, 8, Vector3(0, 0.075, 0), HULL)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.3 * s
	ring.outer_radius = 0.36 * s
	ring.rings = 16
	ring.ring_segments = 4
	_add(root, ring, Vector3(0, 0.17, 0), HAZARD, 0.4)
	var drone := _spinner(root, Vector3(0, 0.95, 0), 1.6)
	_box(drone, Vector3(0.36, 0.12, 0.36), Vector3.ZERO, METAL)
	_sphere(drone, 0.08, Vector3(0, -0.08, 0), ACCENT, 2.0)
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		_box(drone, Vector3(0.18, 0.03, 0.18), Vector3(corner.x * 0.28, 0.05, corner.y * 0.28), HULL_LIGHT)


static func _turret(root: Node3D, s: float) -> void:
	_cylinder(root, 0.32 * s, 0.42 * s, 0.6, 8, Vector3(0, 0.3, 0), HULL)
	var head := _spinner(root, Vector3(0, 0.6, 0), 0.4)
	_box(head, Vector3(0.9, 0.55, 0.9), Vector3(0, 0.3, 0), HULL_LIGHT)
	var barrel := _cylinder(head, 0.09, 0.09, 1.3, 6, Vector3(0, 0.35, -0.8), METAL)
	barrel.rotation_degrees = Vector3(90, 0, 0)
	_sphere(head, 0.13, Vector3(0, 0.35, -1.45), ACCENT, 2.0)


# --- Primitive helpers ---------------------------------------------------------

static func _spinner(parent: Node3D, pos: Vector3, speed: float) -> Node3D:
	var node := Node3D.new()
	node.position = pos
	node.set_meta(SPIN_META, speed)
	parent.add_child(node)
	return node


static func _box(parent: Node3D, box_size: Vector3, pos: Vector3, color: Color,
		glow: float = 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	return _add(parent, mesh, pos, color, glow)


static func _cylinder(parent: Node3D, top: float, bottom: float, height: float, segments: int,
		pos: Vector3, color: Color, glow: float = 0.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return _add(parent, mesh, pos, color, glow)


static func _sphere(parent: Node3D, radius: float, pos: Vector3, color: Color,
		glow: float = 0.0) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	return _add(parent, mesh, pos, color, glow)


static func _add(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color,
		glow: float = 0.0) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = material(color, glow)
	parent.add_child(instance)
	return instance
