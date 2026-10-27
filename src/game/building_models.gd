class_name BuildingModels
extends RefCounted
## Models built in code from LowPolyMesh parts painted from the material kit (Parts.surf),
## one per building type and level, so the game needs no art assets. The
## contract any model keeps (and an imported one must keep): origin at the footprint centre
## on the ground, +Y up, fitting inside size x size cells.
##
## A model is a Node3D holding the static body's MeshInstance3D and its ink outline's, and up
## to Parts.max_moving(tier) moving parts (three, four at Crown, the fourth its escort).
##
## A moving part that moves on the clock alone, its idle, is folded into the body and its outline
## (_folds): its own body and outline arrays, built in its own space as any moving part's are,
## are moved by its pivot into the model's space, stamped with its Motion (LowPolyMesh.stamp_motion,
## Surf.MOVE) and appended to the body's surfaces and the outline, the outline's averaged normals
## kept as the part had them; the shaders move it, at no draw of its own. The meshes' custom_aabb
## covers its whole sweep, so it is never culled as it moves, and the root carries FOLDS_META, the
## static body's top (top_of), which the folded parts leave out. hold() holds the folded parts'
## pose, for a view that freezes them (BuildingView, while busy or disabled). The fold, like every
## array of the meshes, is worked out in thread-safe array work (mesh_data), and the meshes are made
## from the arrays on the main thread (meshes_from); ModelPreview runs the first on a worker thread.
##
## Every other moving part is a Node3D at its pivot carrying the MOVE_META meta (its Motion),
## which BuildingView moves while the building is finished and idle, with the part's mesh and its
## outline under it: a part with a socket (a turret's head with its muzzle), one another rides or
## one that rides another, and one with a marching figure. So a model has at most eight
## MeshInstance3D (ten at Crown), half of them at most outlines (OUTLINE_META), which cast no
## shadow; a part with nothing to outline (only hologram, flicker or jitter parts) has none. The
## meshes are built once per type, level and tier and shared; the nodes are per view. A level above
## a type's models shows its top model. The root and each moving part's node carry their sockets
## (LowPolyMesh.socket) as SOCKETS_META when they have any: a muzzle on a turret's head is on the
## head's node, so it turns with it. A moving part that rides another (Parts.riding: a ring round
## a barrel that aims) carries RIDES_META, the index of the one it rides among the moving parts'
## nodes; its node stands beside the others under the root, at its own pivot, and BuildingView
## carries it with the part it rides. A moving part with a figure marching on the clock
## (Surf.MARCH) carries MARCH_META, so a busy view hides it rather than let it step in place.
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
## Set on a model's root and on a moving part's node when the body or the part has sockets
## (LowPolyMesh.socket): its sockets by name, in that node's space.
const SOCKETS_META := "sockets"
## Set on a moving part's node that rides another (Parts.riding): the index of the one it rides,
## among the model's moving parts in their order as nodes.
const RIDES_META := "rides"
## Set on a moving part's node when any of its parts carries Surf.MARCH.
const MARCH_META := "march"
## Set on a model's root when moving parts are folded into its body: the static body's top, in
## the model's space (top_of).
const FOLDS_META := "folds"
## The shaders' instance uniform that holds the folded parts' pose (hold()).
const HOLD_PARAMETER := &"move_hold"
## The least clock a hold takes, since 0 is the shaders' "not held".
const HOLD_LEAST := 0.0001

const CoreModels := preload("res://src/game/models/core.gd")
const ResourceModels := preload("res://src/game/models/resources.gd")
const ArmyModels := preload("res://src/game/models/army.gd")
const DefenseModels := preload("res://src/game/models/defense.gd")
const TrapModels := preload("res://src/game/models/traps.gd")
const WallModels := preload("res://src/game/models/walls.gd")
const DroneModels := preload("res://src/game/models/drone.gd")
const RubbleModels := preload("res://src/game/models/rubble.gd")

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
	"fabricator": [3, 10],
	"heavy_fabricator": [3, 8],
	"research_lab": [3, 10],
	"nanite_foundry": [3, 8],
	"drydock": [4, 7],
	"alliance_beacon": [3, 7],
	"laser_turret": [3, 10],
	"missile_battery": [3, 10],
	"plasma_mortar": [3, 8],
	"shield_generator": [3, 8],
	"flak_cannon": [3, 8],
	"arc_tower": [3, 8],
	"cloaked_sentry": [2, 7],
	"gravity_well": [2, 6],
	"emp_tower": [3, 6],
	"railgun": [3, 7],
	"ion_beam": [2, 6],
	"orbital_cannon": [4, 5],
	"proximity_mine": [1, 6],
	"grav_trap": [1, 5],
	"flak_mine": [1, 5],
	"mega_mine": [2, 5],
	"barrier_wall": [1, 10],
}

static var _cache: Dictionary[String, Meshes] = {}
static var _warned: Dictionary[String, bool] = {}


## A model's surfaces as arrays (mesh_data), before any mesh is made of them: the body's, with the
## folded parts in, their sweep and the body's top without them; and each kept moving part's.
class MeshData:
	var opaque: Array = []
	var holo: Array = []
	var outline: Array = []
	var sockets: Dictionary[String, LowPolyMesh.Socket] = {}
	var folds := false
	var top: float = 0.0
	## The box the folded parts sweep, which the body's and the outline's AABBs take in.
	var sweep := AABB()
	var moving: Array[MovingData] = []


## A kept moving part's arrays, its pivot, Motion, sockets, the index of the part it rides and
## its marching, as Moving carries them.
class MovingData:
	var opaque: Array = []
	var holo: Array = []
	var outline: Array = []
	var pivot := Vector3.ZERO
	var motion: Motion
	var sockets: Dictionary[String, LowPolyMesh.Socket] = {}
	var rides: int = -1
	var marches := false


## A built model's meshes, shared by every view that shows it.
class Meshes:
	var body: ArrayMesh
	## Null when no part is outlined.
	var outline: ArrayMesh
	var moving: Array[Moving] = []
	## The body's sockets (LowPolyMesh.socket), in the model's space.
	var sockets: Dictionary[String, LowPolyMesh.Socket] = {}
	## Whether moving parts are folded into the body, and the static body's top without them.
	var folds := false
	var top: float = 0.0


## A moving part's meshes, where it rests, and how it moves.
class Moving:
	var body: ArrayMesh
	## Null when no part is outlined.
	var outline: ArrayMesh
	var pivot := Vector3.ZERO
	var motion: Motion
	## The part's sockets, in its own space (the pivot at the origin).
	var sockets: Dictionary[String, LowPolyMesh.Socket] = {}
	## The index in Meshes.moving of the part it rides (Parts.riding), -1 for none.
	var rides: int = -1
	## Whether any of its parts marches on the clock (Surf.MARCH).
	var marches := false


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
	var key := "?/%d" % size
	if MODELS.has(type):
		key = "%s/%d/%d" % [type, _shown(type, level), tier]
	elif not _warned.has(type):
		_warned[type] = true
		push_warning("No model for building type '%s'; showing a generic block" % type)
	root.scale = Vector3.ONE * scale_of(type, size)
	var meshes: Meshes = _cache.get(key)
	if meshes == null:
		meshes = _store(key, parts_of(type, level, size, tier))
	_add_parts(root, meshes)
	return root


## The parts of `type`'s model at `level` for `tier`, at its built size (scale_of scales it to
## `size` cells), uncached; a type with no model is the generic block. They read no cache, write
## none and make no resource or node, so they may be built on a worker thread, and mesh_data()
## with them (ModelPreview's pictures).
static func parts_of(type: String, level: int, size: int, tier: int) -> Parts:
	var p := Parts.new()
	p.tier = tier
	if MODELS.has(type):
		_build(p, type, _shown(type, level))
	else:
		CoreModels.build_generic(p, size)
	return p


## The scale a model of `type`, built for its own size, takes at `size` cells: 1 when they match.
static func scale_of(type: String, size: int) -> float:
	if not MODELS.has(type):
		return 1.0
	var built_for: int = (MODELS[type] as Array)[0]
	return 1.0 if built_for == size else float(size) / built_for


## The level of `type`'s models shown for `level`: a level above its models shows its top one.
static func _shown(type: String, level: int) -> int:
	var top: int = (MODELS[type] as Array)[1]
	return clampi(level, 1, top)


## A model's nodes for meshes built from `p`, uncached: for a caller that builds its own parts
## (the effects harness rig).
static func instantiate(p: Parts) -> Node3D:
	var root := Node3D.new()
	_add_parts(root, _meshes(p))
	return root


## The meshes built from `p`, uncached: for a caller that keeps its own cache (UnitModels).
static func meshes_of(p: Parts) -> Meshes:
	return _meshes(p)


## A model's nodes for `meshes`, as create() assembles them: for a caller that keeps its own
## cache (UnitModels).
static func assemble(meshes: Meshes) -> Node3D:
	var root := Node3D.new()
	_add_parts(root, meshes)
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


## The heap a building of `size` cells leaves when it falls in battle (models/rubble.gd), built once
## per size and cached like a model.
static func create_rubble(size: int) -> Node3D:
	var key := "rubble/%d" % size
	var meshes: Meshes = _cache.get(key)
	if meshes == null:
		var p := Parts.new()
		RubbleModels.build_rubble(p, size)
		meshes = _store(key, p)
	var root := Node3D.new()
	_add_parts(root, meshes)
	return root


## The strip a wall leaves when it falls in battle: its body and outline meshes, cached, for a
## caller that draws every fallen wall from one MultiMesh (BattleView).
static func wall_rubble() -> Meshes:
	var meshes: Meshes = _cache.get("rubble/wall")
	if meshes == null:
		var p := Parts.new()
		RubbleModels.build_wall_rubble(p)
		meshes = _store("rubble/wall", p)
	return meshes


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
	return meshes_from(mesh_data(p))


## The surfaces of the model built as `p`, as arrays: the body's, with the idle moving parts folded
## in (stamped with their motion, _folds), and each kept moving part's. Works out every array of
## the meshes without making a resource or a node and without touching a cache, so it may run on a
## worker thread (ModelPreview's pictures); meshes_from() makes the meshes on the main thread.
static func mesh_data(p: Parts) -> MeshData:
	var data := MeshData.new()
	data.sockets = p.body.sockets
	data.opaque = p.body.to_arrays()
	data.holo = p.body.holo_arrays()
	data.outline = p.body.to_outline_arrays()
	# Each kept part's index in data.moving, by its index in p.movers (an empty part is dropped).
	var kept: Dictionary[int, int] = {}
	for i: int in p.movers.size():
		if p.movers[i].triangle_count() == 0:
			continue
		if _folds(p, i):
			if not data.folds:
				data.folds = true
				data.top = _top(data.opaque, data.holo)
			var part := p.movers[i]
			var arrays: Array[Array] = [part.to_arrays(), part.holo_arrays(), part.to_outline_arrays()]
			var reach := _sweep(arrays, p.pivots[i], p.motions[i])
			data.sweep = reach if data.sweep.size == Vector3.ZERO else data.sweep.merge(reach)
			for k: int in arrays.size():
				if arrays[k].is_empty() or (arrays[k][Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty():
					continue
				LowPolyMesh.stamp_motion(arrays[k], p.pivots[i], p.motions[i])
			data.opaque = LowPolyMesh.append_arrays(data.opaque, _filled(arrays[0]))
			data.holo = LowPolyMesh.append_arrays(data.holo, _filled(arrays[1]))
			data.outline = LowPolyMesh.append_arrays(data.outline, _filled(arrays[2]))
			continue
		kept[i] = data.moving.size()
		var moving := MovingData.new()
		moving.opaque = p.movers[i].to_arrays()
		moving.holo = p.movers[i].holo_arrays()
		moving.outline = p.movers[i].to_outline_arrays()
		moving.pivot = p.pivots[i]
		moving.motion = p.motions[i]
		moving.sockets = p.movers[i].sockets
		moving.rides = kept.get(p.rides[i], -1)
		moving.marches = p.movers[i].has_flag(Surf.MARCH)
		data.moving.append(moving)
	return data


## The meshes of `data` (mesh_data), each surface on the kit's material: on the main thread.
static func meshes_from(data: MeshData) -> Meshes:
	var meshes := Meshes.new()
	meshes.sockets = data.sockets
	meshes.folds = data.folds
	meshes.top = data.top
	for part: MovingData in data.moving:
		var moving := Moving.new()
		moving.body = LowPolyMesh.body_mesh(part.opaque, part.holo)
		moving.outline = LowPolyMesh.outline_mesh(part.outline)
		moving.pivot = part.pivot
		moving.motion = part.motion
		moving.sockets = part.sockets
		moving.rides = part.rides
		moving.marches = part.marches
		meshes.moving.append(moving)
	meshes.body = LowPolyMesh.body_mesh(data.opaque, data.holo)
	meshes.outline = LowPolyMesh.outline_mesh(data.outline)
	if meshes.folds:
		meshes.body.custom_aabb = meshes.body.get_aabb().merge(data.sweep)
		if meshes.outline != null:
			meshes.outline.custom_aabb = meshes.outline.get_aabb().merge(data.sweep)
	return meshes


## Whether moving part `i` of `p` folds into the body: it moves on the clock alone, with no socket
## (an aiming head's muzzle or trunnion), riding no part and ridden by none, and nothing rigged
## (Surf.RIG: its joints are in the part's own space, and the shaders move a part before they rig
## it), a marching figure (MARCH_META, hidden while busy) among them.
static func _folds(p: Parts, i: int) -> bool:
	return p.movers[i].sockets.is_empty() and p.rides[i] < 0 and not p.rides.has(i) \
		and not p.movers[i].has_flag(Surf.RIG) and not p.movers[i].has_flag(Surf.MARCH)


## Surface arrays with a vertex, else empty ones, for append_arrays.
static func _filled(arrays: Array) -> Array:
	if arrays.is_empty() or (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty():
		return []
	return arrays


## The highest vertex of a body's surfaces, 0 for none.
static func _top(opaque: Array, holo: Array) -> float:
	var top := 0.0
	for arrays: Array in [opaque, holo]:
		if arrays.is_empty():
			continue
		for vertex: Vector3 in (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			top = maxf(top, vertex.y)
	return top


## The box a part built in its own space (its `arrays`, unstamped) sweeps moving as `motion` says
## about `pivot`, in the model's space: a turning part's ball about the pivot, a sliding part's box
## at both ends of its slide.
static func _sweep(arrays: Array[Array], pivot: Vector3, motion: Motion) -> AABB:
	var box := AABB()
	var radius := 0.0
	var first := true
	for surface: Array in arrays:
		if surface.is_empty():
			continue
		for vertex: Vector3 in (surface[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			radius = maxf(radius, vertex.length())
			box = AABB(vertex, Vector3.ZERO) if first else box.expand(vertex)
			first = false
	if motion.kind == Motion.Kind.SLIDE:
		var reach := motion.axis * motion.amplitude
		return AABB(box.position + pivot - reach, box.size).merge(AABB(box.position + pivot + reach, box.size))
	return AABB(pivot - Vector3.ONE * radius, Vector3.ONE * radius * 2.0)


## Holds the folded moving parts of the model `root` (FOLDS_META) at the clock `time`, seconds
## (at least HOLD_LEAST), or lets them run on the clock again for a negative `time`: the shaders'
## move_hold on its body and outline (effects.gdshaderinc). Nothing for a model with none folded.
static func hold(root: Node3D, time: float) -> void:
	if not root.has_meta(FOLDS_META):
		return
	var value := maxf(time, HOLD_LEAST) if time >= 0.0 else 0.0
	for child: Node in root.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).set_instance_shader_parameter(HOLD_PARAMETER, value)


## The top of the model `site`'s static body, in its parent's space: FOLDS_META's when moving parts
## are folded into it, else its body mesh's (ConstructionDrone.top_of).
static func top_of(site: Node3D) -> float:
	if site.has_meta(FOLDS_META):
		return float(site.get_meta(FOLDS_META)) * site.scale.y
	return (site.get_child(0) as MeshInstance3D).mesh.get_aabb().end.y * site.scale.y


## The body's instances under `root`, then a node at each moving part's pivot with its instances.
static func _add_parts(root: Node3D, meshes: Meshes) -> void:
	_add_instances(root, meshes.body, meshes.outline)
	if not meshes.sockets.is_empty():
		root.set_meta(SOCKETS_META, meshes.sockets)
	if meshes.folds:
		root.set_meta(FOLDS_META, meshes.top)
	for moving: Moving in meshes.moving:
		var node := Node3D.new()
		node.position = moving.pivot
		node.set_meta(MOVE_META, moving.motion)
		if not moving.sockets.is_empty():
			node.set_meta(SOCKETS_META, moving.sockets)
		if moving.rides >= 0:
			node.set_meta(RIDES_META, moving.rides)
		if moving.marches:
			node.set_meta(MARCH_META, true)
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
