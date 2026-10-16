class_name BuildingModels
extends RefCounted
## Models built in code from LowPolyMesh parts painted from the material kit (Parts.surf),
## one per building type and level, so the game needs no art assets. The
## contract any model keeps (and an imported one must keep): origin at the footprint centre
## on the ground, +Y up, fitting inside size x size cells.
##
## A model is a Node3D holding the static body's MeshInstance3D and its ink outline's, and up
## to Parts.max_moving(tier) moving parts (three, four at Crown, the fourth its escort): each a
## Node3D at its pivot carrying the MOVE_META meta (its Motion), which BuildingView moves while
## the building is finished and idle, with the part's mesh and its outline under it. So a model
## has at most eight MeshInstance3D (ten at Crown), half of them at most outlines (OUTLINE_META),
## which cast no shadow; a part with nothing to outline (only hologram, flicker or jitter parts)
## has none. The meshes are built once per type, level and tier and shared; the nodes are per
## view. A level above a type's models shows its top model.
##
## Each category shares a look: every building but a wall stands on the concrete foundation pad
## (Parts.foundation) in its category's accent colour (docs/reference/art-style.md), and walls
## are posts that join their neighbours (models/walls.gd). Level 1 is plain and each level adds a
## part or an accent. A level's tier (Parts.Tier) is its theme: tier_of() takes it from the
## data, the Command Center level the level requires, so every type's levels of one Command
## Center band share it (gold trim from Command Center 5). The cache is keyed by type, shown
## level and tier, so a level above a type's models, shown as its top model, is painted for its
## own tier and never hands that paint to the top level's views.
##
## This file dispatches: each type's builder is a static build_<type>(p: Parts, level) in its
## category's file under src/game/models/ (core, resources, army, defense, traps), but for the
## wall, a defence type whose builder has a file of its own (walls), and the helpers they share
## are on Parts (models/parts.gd).

## Set on a moving part's node: its Motion.
const MOVE_META := "motion"
## Set on the outline instances, so a view can tell them from the bodies.
const OUTLINE_META := "outline"

const CoreModels := preload("res://src/game/models/core.gd")
const ResourceModels := preload("res://src/game/models/resources.gd")
const ArmyModels := preload("res://src/game/models/army.gd")
const DefenseModels := preload("res://src/game/models/defense.gd")
const TrapModels := preload("res://src/game/models/traps.gd")
const WallModels := preload("res://src/game/models/walls.gd")
const DroneModels := preload("res://src/game/models/drone.gd")

## [the footprint size a model is built for, the levels it has models for] per type.
const MODELS := {
	"command_center": [4, 10],
	"drone_bay": [2, 3],
	"metal_extractor": [3, 10],
	"crystal_harvester": [3, 10],
	"antimatter_siphon": [3, 8],
	"metal_silo": [3, 10],
	"crystal_silo": [3, 10],
	"antimatter_vault": [3, 8],
	"hangar": [5, 10],
	"cadet_academy": [3, 10],
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
	"barrier_wall": [1, 10],
}

static var _cache: Dictionary[String, Meshes] = {}
static var _warned: Dictionary[String, bool] = {}


## A built model's meshes, shared by every view that shows it.
class Meshes:
	var body: ArrayMesh
	## Null when no part is outlined.
	var outline: ArrayMesh
	var moving: Array[Moving] = []


## A moving part's meshes, where it rests, and how it moves.
class Moving:
	var body: ArrayMesh
	## Null when no part is outlined.
	var outline: ArrayMesh
	var pivot := Vector3.ZERO
	var motion: Motion


## The Tier of the levels unlocked at Command Center `cc`: one mapping, used for every type.
static func tier_for_cc(cc: int) -> int:
	if cc >= 10:
		return Parts.Tier.CROWN
	if cc >= 8:
		return Parts.Tier.OBSIDIAN
	if cc >= 6:
		return Parts.Tier.CHROME
	if cc >= 5:
		return Parts.Tier.GOLD
	return Parts.Tier.BASE


## The Tier of `type` at `level`, from the Command Center level it requires (`requires_cc`, 1
## when it has none). The Command Center's own level is its band: its level 5 is Gold though
## it requires Command Center 4.
static func tier_of(catalog: Catalog, type: String, level: int) -> int:
	if type == Catalog.HQ_TYPE:
		return tier_for_cc(level)
	return tier_for_cc(int(catalog.level_stats(type, level).get("requires_cc", 1)))


## The model of `type` at `level`, built for its `tier` (tier_of) and scaled to `size` cells.
static func create(type: String, level: int, size: int, tier: int) -> Node3D:
	var root := Node3D.new()
	var shown := 0
	var key := "?/%d" % size
	if MODELS.has(type):
		var spec: Array = MODELS[type]
		var built_for: int = spec[0]
		var top: int = spec[1]
		shown = clampi(level, 1, top)
		key = "%s/%d/%d" % [type, shown, tier]
		if built_for != size:
			root.scale = Vector3.ONE * (float(size) / built_for)
	elif not _warned.has(type):
		_warned[type] = true
		push_warning("No model for building type '%s'; showing a generic block" % type)
	var meshes: Meshes = _cache.get(key)
	if meshes == null:
		var p := Parts.new()
		p.tier = tier
		if shown > 0:
			_build(p, type, shown)
		else:
			CoreModels.build_generic(p, size)
		meshes = _store(key, p)
	_add_parts(root, meshes)
	return root


## A model's nodes for meshes built from `p`, uncached: for a caller that builds its own parts
## (the effects harness rig).
static func instantiate(p: Parts) -> Node3D:
	var root := Node3D.new()
	_add_parts(root, _meshes(p))
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
	_add_parts(root, meshes)
	return root


## The construction drone (ConstructionDrone): its body and its outline, built once and cached
## like a model.
static func create_drone() -> Node3D:
	var meshes := _drone_meshes("drone")
	var root := Node3D.new()
	_add_instances(root, meshes.body, meshes.outline)
	return root


## The drone's laser (`"beam"`, one unit long up +Y) or the flare where it hits (`"flare"`): one
## instance, unlit, with no outline and casting no shadow.
static func create_drone_effect(part: String) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = _drone_meshes(part).body
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


static func _drone_meshes(part: String) -> Meshes:
	var key := "drone/" + part
	var meshes: Meshes = _cache.get(key)
	if meshes == null:
		var p := Parts.new()
		match part:
			"drone":
				DroneModels.build_drone(p)
			"beam":
				DroneModels.build_beam(p)
			"flare":
				DroneModels.build_flare(p)
		meshes = _store(key, p)
	return meshes


static func _store(key: String, p: Parts) -> Meshes:
	var meshes := _meshes(p)
	_cache[key] = meshes
	return meshes


static func _meshes(p: Parts) -> Meshes:
	var meshes := Meshes.new()
	meshes.body = p.body.to_mesh()
	meshes.outline = p.body.to_outline_mesh()
	for i: int in p.movers.size():
		if p.movers[i].triangle_count() == 0:
			continue
		var moving := Moving.new()
		moving.body = p.movers[i].to_mesh()
		moving.outline = p.movers[i].to_outline_mesh()
		moving.pivot = p.pivots[i]
		moving.motion = p.motions[i]
		meshes.moving.append(moving)
	return meshes


## The body's instances under `root`, then a node at each moving part's pivot with its instances.
static func _add_parts(root: Node3D, meshes: Meshes) -> void:
	_add_instances(root, meshes.body, meshes.outline)
	for moving: Moving in meshes.moving:
		var node := Node3D.new()
		node.position = moving.pivot
		node.set_meta(MOVE_META, moving.motion)
		root.add_child(node)
		_add_instances(node, moving.body, moving.outline)


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
		"cadet_academy":
			ArmyModels.build_cadet_academy(p, level)
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
