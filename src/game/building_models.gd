class_name BuildingModels
extends RefCounted
## Models built in code from LowPolyMesh parts painted from the material kit (Parts.surf),
## one per building type and level, so the game needs no art assets. The
## contract any model keeps (and an imported one must keep): origin at the footprint centre
## on the ground, +Y up, fitting inside size x size cells.
##
## A model is a Node3D holding the static body's MeshInstance3D and its ink outline's, and at
## most one spinning part: a Node3D at the pivot carrying the SPIN_META meta (its speed in
## radians per second), which turns around Y while the building is finished and idle, with the
## spinning mesh and its outline under it. So a model has at most four MeshInstance3D, two of
## them outlines (OUTLINE_META), which cast no shadow. The meshes are built once per type and
## level and shared; the nodes are per view. A level above a type's models shows its top model.
##
## Each category shares a look: every building but a wall stands on the concrete foundation pad
## (Parts.foundation) in its category's accent colour (docs/reference/art-style.md), and walls
## are posts that join their neighbours (models/walls.gd). Level 1 is plain, each level adds a
## part or an accent, the top level carries gold.
##
## This file dispatches: each type's builder is a static build_<type>(p: Parts, level) in its
## category's file under src/game/models/ (core, resources, army, defense, traps, walls), and
## the helpers they share are on Parts (models/parts.gd).

const SPIN_META := "spin_speed"
## Set on the outline instances, so a view can tell them from the bodies.
const OUTLINE_META := "outline"

const CoreModels := preload("res://src/game/models/core.gd")
const ResourceModels := preload("res://src/game/models/resources.gd")
const ArmyModels := preload("res://src/game/models/army.gd")
const DefenseModels := preload("res://src/game/models/defense.gd")
const TrapModels := preload("res://src/game/models/traps.gd")
const WallModels := preload("res://src/game/models/walls.gd")

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

static var _cache: Dictionary[String, Meshes] = {}
static var _warned: Dictionary[String, bool] = {}


## A built model's meshes, shared by every view that shows it.
class Meshes:
	var body: ArrayMesh
	## Null when no part is outlined.
	var outline: ArrayMesh
	## Null when nothing spins.
	var spin: ArrayMesh
	var spin_outline: ArrayMesh
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
			CoreModels.build_generic(p, size)
		meshes = _store(key, p)
	_add_instances(root, meshes.body, meshes.outline)
	if meshes.spin != null:
		var spinner := Node3D.new()
		spinner.position = meshes.pivot
		spinner.set_meta(SPIN_META, meshes.speed)
		root.add_child(spinner)
		_add_instances(spinner, meshes.spin, meshes.spin_outline)
	return root


## Shown while a building is first being constructed.
static func create_scaffold(size: int) -> Node3D:
	var key := "scaffold/%d" % size
	var meshes: Meshes = _cache.get(key)
	if meshes == null:
		var p := Parts.new()
		CoreModels.build_scaffold(p, size)
		meshes = _store(key, p)
	var root := Node3D.new()
	_add_instances(root, meshes.body, meshes.outline)
	return root


static func _store(key: String, p: Parts) -> Meshes:
	var meshes := Meshes.new()
	meshes.body = p.body.to_mesh()
	meshes.outline = p.body.to_outline_mesh()
	if p.spin.triangle_count() > 0:
		meshes.spin = p.spin.to_mesh()
		meshes.spin_outline = p.spin.to_outline_mesh()
		meshes.pivot = p.pivot
		meshes.speed = p.speed
	_cache[key] = meshes
	return meshes


## A body's MeshInstance3D under `parent`, and its outline's beside it (casting no shadow).
static func _add_instances(parent: Node3D, body: ArrayMesh, outline: ArrayMesh) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = body
	parent.add_child(instance)
	if outline != null:
		var ink := MeshInstance3D.new()
		ink.mesh = outline
		ink.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ink.set_meta(OUTLINE_META, true)
		parent.add_child(ink)


static func _build(p: Parts, type: String, level: int) -> void:
	match type:
		"command_center":
			CoreModels.build_command_center(p, level)
		"drone_bay":
			ResourceModels.build_drone_bay(p, level)
		"metal_extractor":
			ResourceModels.build_metal_extractor(p, level)
		"crystal_harvester":
			ResourceModels.build_crystal_harvester(p, level)
		"antimatter_siphon":
			ResourceModels.build_antimatter_siphon(p, level)
		"metal_silo":
			ResourceModels.build_metal_silo(p, level)
		"crystal_silo":
			ResourceModels.build_crystal_silo(p, level)
		"antimatter_vault":
			ResourceModels.build_antimatter_vault(p, level)
		"hangar":
			ArmyModels.build_hangar(p, level)
		"fabricator":
			ArmyModels.build_fabricator(p, level)
		"heavy_fabricator":
			ArmyModels.build_heavy_fabricator(p, level)
		"research_lab":
			ArmyModels.build_research_lab(p, level)
		"nanite_foundry":
			ArmyModels.build_nanite_foundry(p, level)
		"drydock":
			ArmyModels.build_drydock(p, level)
		"alliance_beacon":
			ArmyModels.build_alliance_beacon(p, level)
		"laser_turret":
			DefenseModels.build_laser_turret(p, level)
		"missile_battery":
			DefenseModels.build_missile_battery(p, level)
		"plasma_mortar":
			DefenseModels.build_plasma_mortar(p, level)
		"shield_generator":
			DefenseModels.build_shield_generator(p, level)
		"flak_cannon":
			DefenseModels.build_flak_cannon(p, level)
		"arc_tower":
			DefenseModels.build_arc_tower(p, level)
		"cloaked_sentry":
			DefenseModels.build_cloaked_sentry(p, level)
		"gravity_well":
			DefenseModels.build_gravity_well(p, level)
		"emp_tower":
			DefenseModels.build_emp_tower(p, level)
		"railgun":
			DefenseModels.build_railgun(p, level)
		"ion_beam":
			DefenseModels.build_ion_beam(p, level)
		"orbital_cannon":
			DefenseModels.build_orbital_cannon(p, level)
		"proximity_mine":
			TrapModels.build_proximity_mine(p, level)
		"grav_trap":
			TrapModels.build_grav_trap(p, level)
		"flak_mine":
			TrapModels.build_flak_mine(p, level)
		"mega_mine":
			TrapModels.build_mega_mine(p, level)
		"barrier_wall":
			WallModels.build_barrier_wall(p, level)
