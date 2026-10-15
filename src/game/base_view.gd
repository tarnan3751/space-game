class_name BaseView
extends Node3D
## Draws the base: the buildable ground with its cell grid, the curb round it, the terrain and
## rocks around that, and one BuildingView per building, the finished walls drawn together by one
## WallMesh. Also
## owns the cell <-> world mapping: 1 cell = 1 world unit, grid centred on the origin, cell
## (x, y) maps to world (x, z).
##
## The terrain, the rocks and the crystal outcrops are generated from SCENERY_SEED, so every
## player's base sits in the same landscape: a ring of dunes, craters, mesas and a dry channel
## rising from low, rough ground beside the curb along an edge that wanders, smooth shaded, tinted
## by slope and drawn over by the terrain shader (the field's marks, wind ripples, rock strata),
## with chamfered rocks, small ones strewn beside the curb as rubble, and glowing crystal clusters
## on it. Each is one mesh with its ink
## outline.

const GROUND_SHADER := preload("res://src/game/ground.gdshader")
## The field texture the ground is drawn from, imported as an Image (tools/gen_textures.gd).
const FIELD_TEXTURE := "res://assets/textures/field.png"
const SCENERY_SEED := 7
## Strength of the ground's cell lines, normally and while placing.
const GRID_LINES := 0.1
const GRID_LINES_PLACING := 0.45
## The terrain reaches TERRAIN_EXTENT from the centre in x and z, on a lattice of 1 unit within
## TERRAIN_FINE_REACH of the centre and of TERRAIN_COARSE beyond, cut to half a unit within
## TERRAIN_MESA_REACH of a mesa's outline, so its steep wall meets the level ground over several
## points.
const TERRAIN_EXTENT := 100.0
const TERRAIN_FINE_REACH := 50.0
const TERRAIN_COARSE := 2
const TERRAIN_MESA_REACH := 3.0
## Outside the field the ground stays flat out to TERRAIN_FLAT, about a unit past the kerb's outer
## face (CURB_GAP + CURB_WIDTH), so the kerb and the corner footings stand on flat ground, and
## reaches its full relief between TERRAIN_BLEND_NEAR and TERRAIN_BLEND_FAR out, wandering along
## the edge (blend_end), so no ramp runs straight along a side. Rubble, RUBBLE high either way,
## roughens the ground from TERRAIN_FLAT out whatever the relief.
const TERRAIN_FLAT := 2.4
const TERRAIN_BLEND_NEAR := 4.0
const TERRAIN_BLEND_FAR := 11.0
const RUBBLE := 0.12
## Spacing of the value-noise lattice behind the dunes.
const NOISE_CELL := 7.0
const NOISE_SIZE := 24
## The dunes' height next to the field and from 20 units out (they grow from where the relief is
## full), the scale of their ridges' noise (NOISE_CELL / DUNE_SCALE units across), and how much the
## land rises per unit out.
const DUNES_NEAR := 0.3
const DUNES_FAR := 5.0
const DUNE_SCALE := 0.64
const RISE := 0.04
## A crater's depth and rim height, in radii.
const CRATER_DEPTH := 0.18
const CRATER_RIM := 0.15
## A mesa's wall: how far in from its outline its rim lies, and how far out its foot; how far
## apart round the outline it is sampled, in degrees; how far its foot sinks below the ground, so
## no gap shows under it; and how far inside the foot a lattice cell must lie to be left out.
const MESA_WALL := 1.4
const MESA_FOOT := 0.4
const MESA_STEP := 3.0
const MESA_SINK := 0.05
const MESA_FOOT_MARGIN := 0.25
## The dry channel's half width, depth, and how far it wanders either side of its course (radians).
const CHANNEL_WIDTH := 2.2
const CHANNEL_DEPTH := 1.2
const CHANNEL_MEANDER := 0.22
## The terrain's tint: the rock tint where its normal's y is below ROCK_SLOPE_Y (slopes over 35
## degrees); the shadow side of slopes over 18 degrees (SHADOW_SLOPE_Y) dark and the lit side of
## slopes over 25 degrees (LIT_SLOPE_Y) light; crater floors (within CRATER_FLOOR radii of the
## centre) dark. Each blends in smoothly across its threshold, so the patches between points are
## rounded. The terrain shader draws the surface over it (MaterialKit.terrain).
const ROCK_SLOPE_Y := 0.819
const SHADOW_SLOPE_Y := 0.95
const LIT_SLOPE_Y := 0.906
const CRATER_FLOOR := 0.75
## Towards the key light across the ground (main.gd's sun), in world x and z: the terrain's
## tint, and the ground and terrain shaders' light on their marks.
const SUN_ACROSS := Vector2(-0.5, 0.866)
## The rocks: how many, their radii (world units, most of them small), and how many in a hundred
## of those over 0.8 in radius carry a smaller rock on top.
const ROCK_COUNT := 80
const ROCK_SMALLEST := 0.4
const ROCK_LARGEST := 2.5
const ROCK_STACKED := 25
## The rubble beside the curb: how many small rocks, their radii, and how far outside the field
## they lie, spread evenly round its four sides.
const RUBBLE_ROCKS := 36
const RUBBLE_ROCK_RADIUS := Vector2(0.15, 0.4)
const RUBBLE_ROCK_OUT := Vector2(2.4, 7.4)
## The crystal outcrops: how many clusters, shards in each, the shards' lengths, and how close any
## part of one may come to the field.
const OUTCROP_COUNT := Vector2i(6, 10)
const OUTCROP_SHARDS := Vector2i(3, 7)
const SHARD_LENGTH := Vector2(0.6, 2.0)
const OUTCROP_GAP := 4.0
## The perimeter round the field. The kerb: its height and width, its gap from the field's edge,
## how far each corner is cut back along each side, and the chamfer on its top edges. A pylon
## stands on its middle line every PLATE_CELLS cells (the field texture's tiles are as wide) and on
## each corner cut: PYLON_WIDTH square, PYLON_HEIGHT tall, CORNER_PYLON_HEIGHT on the corners. The
## fence between them: a rail RAIL_RADIUS thick RAIL_HEIGHT up, over an energy panel from the
## kerb's top to the rail, folded half way up: its lower half leaning in by FENCE_LEAN degrees and
## its upper half out by as much.
const CURB_HEIGHT := 0.25
const CURB_WIDTH := 0.35
## The kerb stands far enough out that no pylon covers a field cell from the camera, which looks
## down 35 degrees (IsoCamera.PITCH_DEG) along the view's diagonal: a point h up hides the ground
## h / tan 35 = 1.43 h beyond it along the diagonal, which is 1.01 h across a side. A side pylon's
## cap is 0.98 up and 0.23 wide from its middle, so it reaches 0.23 + 1.01 x 0.98 = 1.22 inwards,
## plus 0.03 for its ink line at the closest zoom: 1.25, which the pylon's middle line,
## CURB_GAP + CURB_WIDTH / 2 out, must reach. At the corner nearest the camera the reach is along
## the diagonal, the whole 1.43 h: the beacon, 1.44 up and 0.12 wide, reaches 0.12 + 1.43 x 1.44 +
## 0.03 = 2.21 (the cap 2.09), but the middle of the kerb's corner cut lies only
## sqrt 2 x (CURB_GAP + CURB_WIDTH / 2 - the cut's half run, 0.35) = 1.31 from the field's corner,
## so each corner pylon stands CORNER_PYLON_OUT further out along the diagonal, on a concrete
## footing that runs out to it from the cut.
const CURB_GAP := 1.1
const CORNER_PYLON_OUT := 0.9
const CURB_CORNER := 0.6
const CURB_BEVEL := 0.05
const PLATE_CELLS := 4
const PYLON_WIDTH := 0.4
const PYLON_HEIGHT := 0.9
const CORNER_PYLON_HEIGHT := 1.2
const RAIL_HEIGHT := 0.75
const RAIL_RADIUS := 0.03
const FENCE_LEAN := 20.0
## The pylons' plated posts; their lamps, energy cyan, pulsing (each phased by its place round the
## loop, so the pulse travels round it); and the corner pylons' beacons, hazard yellow, blinking.
static var PYLON := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.HULL_MID)
static var PYLON_CAP := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.GUNMETAL)
static var PYLON_LAMP := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ENERGY, 1.0, Surf.UNLIT | Surf.PULSE, true)
static var PYLON_BEACON := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.HAZARD, 1.0, Surf.UNLIT | Surf.BLINK, true)
## The fence's panels: a low hologram in energy cyan, phased per side.
static var FENCE_FIELD := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ENERGY, 1.0, Surf.HOLO)
## The rocks' sides and their chamfers and tops, flat shaded and outlined.
static var ROCK_SIDE := Surf.make(MaterialKit.Layer.ROCK, MaterialKit.ROCK)
static var ROCK_TOP := Surf.make(MaterialKit.Layer.ROCK, MaterialKit.ROCK_LIT)
## The outcrops' shards: glowing faceted crystal in the three resource colours, outlined.
static var SHARDS: Array[Surf] = [
	Surf.make(MaterialKit.Layer.CRYSTAL, MaterialKit.CRYSTAL, 0.7, Surf.UNLIT),
	Surf.make(MaterialKit.Layer.CRYSTAL, MaterialKit.METAL, 0.7, Surf.UNLIT),
	Surf.make(MaterialKit.Layer.CRYSTAL, MaterialKit.ANTIMATTER, 0.7, Surf.UNLIT),
]

var grid_size: Vector2i = Vector2i.ZERO
var views: Dictionary[int, BuildingView] = {}
## Building drawn with a selection tile.
var selected_id: int = 0
## Building currently being dragged; sync() leaves its position alone.
var dragging_id: int = 0
## Every finished wall but the dragged one, in one mesh.
var walls: WallMesh
## The scenery, each a body and its ink outline, which casts no shadow.
var boundary: MeshInstance3D
var boundary_outline: MeshInstance3D
var terrain: MeshInstance3D
var terrain_outline: MeshInstance3D
var rocks: MeshInstance3D
var rocks_outline: MeshInstance3D
var outcrops: MeshInstance3D
var outcrops_outline: MeshInstance3D
## The centre of each crystal outcrop, on the ground.
var outcrop_spots: PackedVector3Array = PackedVector3Array()
## The terrain's craters, each as (x, z, radius), and its mesas, each as (x, z, radius, the
## height of its top).
var craters: Array[Vector3] = []
var mesas: Array[Vector4] = []

var _ground_material: ShaderMaterial
## The field texture, which the ground and the terrain draw their marks from.
var _field_texture: ImageTexture
## The walls `walls` draws, as (x << 32 | y << 16 | level) in id order: unchanged, no rebuild.
var _wall_signature: PackedInt64Array = PackedInt64Array()
## The state the pending wall rebuild reads; null when none is pending.
var _walls_state: BaseState = null
## NOISE_SIZE x NOISE_SIZE heights in [0, 1], wrapping.
var _noise: PackedFloat32Array = PackedFloat32Array()
## Each mesa's outline: the phases of the two waves that make it irregular.
var _mesa_phases: Array[Vector2] = []
## The dry channel: the angle of its course from the centre, the phase of its meander, and the
## distance from the centre it starts at; and its course as a direction.
var _channel: Vector3 = Vector3.ZERO
var _channel_course: Vector2 = Vector2.ZERO


func setup(size: Vector2i) -> void:
	grid_size = size
	_build_ground()
	_build_boundary()
	var rng := SeededRng.new(SCENERY_SEED)
	_build_terrain(rng)
	var stones := LowPolyMesh.new()
	var stone_spots := _build_rocks(stones, rng)
	_build_outcrops(rng)
	# The rubble draws from the seed last, so the rocks and the outcrops keep their places.
	_scatter_rubble(stones, stone_spots, rng)
	rocks = _add_mesh(stones.to_mesh(), true)
	rocks_outline = _add_mesh(stones.to_outline_mesh(), false)
	walls = WallMesh.new()
	walls.setup(self)
	add_child(walls)


## World-space centre of a footprint whose top-left cell is `cell`.
func cell_to_world(cell: Vector2i, size: int) -> Vector3:
	return Vector3(
		cell.x + size * 0.5 - grid_size.x * 0.5,
		0.0,
		cell.y + size * 0.5 - grid_size.y * 0.5
	)


func world_to_cell(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x + grid_size.x * 0.5), floori(point.z + grid_size.y * 0.5))


## Top-left cell of a `size` footprint centred as closely as possible on `point`.
func footprint_cell_at(point: Vector3, size: int) -> Vector2i:
	return Vector2i(
		roundi(point.x + grid_size.x * 0.5 - size * 0.5),
		roundi(point.z + grid_size.y * 0.5 - size * 0.5)
	)


## The buildable area in world x/z.
func area() -> Rect2:
	return Rect2(-grid_size.x * 0.5, -grid_size.y * 0.5, grid_size.x, grid_size.y)


## Brightens the cell grid while a building is being placed.
func set_grid_highlight(on: bool) -> void:
	_ground_material.set_shader_parameter("line_strength", GRID_LINES_PLACING if on else GRID_LINES)


## Creates, updates and removes building views to match the state.
func sync(state: BaseState) -> void:
	# A freed view's construction drone, by building id: it leaves over the new view's site.
	var leaving: Dictionary[int, ConstructionDrone] = {}
	for id: int in views.keys():
		var stale: bool = not state.buildings.has(id)
		if not stale:
			var building: BuildingState = state.buildings[id]
			# A new finished level gets its model; a dragged view keeps its own until dropped.
			stale = views[id].building_type != building.type \
				or (views[id].building_level != building.level and id != dragging_id)
		if stale:
			var drone := views[id].release_drone(self)
			if drone != null:
				leaving[id] = drone
			views[id].queue_free()
			views.erase(id)

	for id: int in state.buildings:
		var building: BuildingState = state.buildings[id]
		var view: BuildingView = views.get(id)
		if view == null:
			view = BuildingView.new()
			view.setup(id, building.type, building.level, state.catalog.size_of(building.type))
			add_child(view)
			views[id] = view
		view.show_status(building.level, building.is_busy(), building.target_level, state.seconds_left(id))
		if id == dragging_id:
			continue
		view.position = cell_to_world(building.cell, view.footprint_size)
		view.set_lifted(false)
		var mode := BuildingView.Footprint.SELECTED if id == selected_id else BuildingView.Footprint.NONE
		view.set_footprint(mode)
	for id: int in leaving:
		leaving[id].leave(views[id].site_height() if views.has(id) else 0.0)
	_sync_walls(state)


## The merged mesh draws every finished wall but the dragged one, whose view shows its own post
## so it can follow the finger. The mesh is rebuilt only when the walls it draws, by cell and
## level, changed, and at the end of the frame, once however many changed in it (a fast paint
## stroke places several walls in one drag event).
func _sync_walls(state: BaseState) -> void:
	var signature := PackedInt64Array()
	for id: int in state.buildings:
		var building: BuildingState = state.buildings[id]
		var merged := id != dragging_id and WallMesh.draws(state.catalog, building)
		views[id].set_merged(merged)
		if merged:
			signature.append(building.cell.x << 32 | building.cell.y << 16 | building.level)
	if signature != _wall_signature:
		_wall_signature = signature
		if _walls_state == null:
			_rebuild_walls.call_deferred()
		_walls_state = state


func _rebuild_walls() -> void:
	walls.rebuild(_walls_state, dragging_id)
	_walls_state = null


func clear() -> void:
	for view: BuildingView in views.values():
		view.queue_free()
	views.clear()
	selected_id = 0
	dragging_id = 0


func _build_ground() -> void:
	var field: Image = load(FIELD_TEXTURE)
	# Mipmapped here: the image importer keeps the PNG as it is.
	field.generate_mipmaps()
	_ground_material = ShaderMaterial.new()
	_ground_material.shader = GROUND_SHADER
	_ground_material.set_shader_parameter("grid_size", Vector2(grid_size))
	_field_texture = ImageTexture.create_from_image(field)
	_ground_material.set_shader_parameter("field", _field_texture)
	_ground_material.set_shader_parameter("field_color", MaterialKit.FIELD)
	_ground_material.set_shader_parameter("field_light", MaterialKit.FIELD_LIGHT)
	_ground_material.set_shader_parameter("field_dark", MaterialKit.FIELD_DARK)
	_ground_material.set_shader_parameter("plate_color", MaterialKit.FIELD_PLATE)
	_ground_material.set_shader_parameter("ink_color", MaterialKit.INK)
	_ground_material.set_shader_parameter("sun_across", SUN_ACROSS)
	_ground_material.set_shader_parameter("line_strength", GRID_LINES)
	var plane := PlaneMesh.new()
	plane.size = Vector2(grid_size)
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	ground.material_override = _ground_material
	add_child(ground)


## The perimeter round the field (CURB_*, PYLON_*, RAIL_*), in one mesh with its outline: the
## kerb, an octagonal band of concrete with chamfered top edges; a pylon on its middle line every
## PLATE_CELLS cells along each side and a taller one on each corner cut, each a plated post with a
## hazard band, a gunmetal cap and a lamp (a beacon on the corners); and between the pylons a fence,
## a gunmetal rail, with a ball joint where it bends, over a hologram panel folded half way up. The body casts a shadow (the pylons are real masses); the
## outline none.
func _build_boundary() -> void:
	var mesh := LowPolyMesh.new()
	var top := CURB_HEIGHT - CURB_BEVEL
	var inner := _curb_loop(0.0, 0.0)
	var inner_shoulder := _curb_loop(0.0, top)
	var inner_top := _curb_loop(CURB_BEVEL, CURB_HEIGHT)
	var outer_top := _curb_loop(CURB_WIDTH - CURB_BEVEL, CURB_HEIGHT)
	var outer_shoulder := _curb_loop(CURB_WIDTH, top)
	var outer := _curb_loop(CURB_WIDTH, 0.0)
	_curb_band(mesh, inner, inner_shoulder, -1.0)
	_curb_band(mesh, inner_shoulder, inner_top, -1.0)
	_curb_band(mesh, inner_top, outer_top, 1.0)
	_curb_band(mesh, outer_top, outer_shoulder, 1.0)
	_curb_band(mesh, outer_shoulder, outer, 1.0)

	# The fence's course round the kerb's middle line: for each corner k, its pylon (on the middle
	# of the cut, between corners 2k and 2k + 1 of the loop), the bend into side k, that side's
	# pylons in order, and the bend out of it. Each point's kind: 0 a bend, 1 a pylon, 2 a corner.
	var middle := _curb_loop(CURB_WIDTH * 0.5, 0.0)
	var course := PackedVector3Array()
	var kinds := PackedInt32Array()
	var sides := PackedInt32Array()
	var pylons := 0
	for k: int in 4:
		var from := middle[2 * k + 1]
		var to := middle[(2 * k + 2) % middle.size()]
		var cut := (middle[2 * k] + from) * 0.5
		var diagonal := Vector3(cut.x, 0.0, cut.z).normalized()
		course.append(cut + diagonal * CORNER_PYLON_OUT)
		kinds.append(2)
		# The corner pylon's footing, from inside the kerb to just past the pylon, along the
		# diagonal: turned 45 degrees, the box's z runs along the (1, 1) diagonal and its x along
		# (1, -1).
		var run := CORNER_PYLON_OUT + 2.0 * PYLON_WIDTH
		var size := Vector3(PYLON_WIDTH + 0.2, CURB_HEIGHT, run) if cut.x * cut.z > 0.0 \
			else Vector3(run, CURB_HEIGHT, PYLON_WIDTH + 0.2)
		mesh.box_chamfered(size, CURB_BEVEL, cut + diagonal * CORNER_PYLON_OUT * 0.5, Parts.CONCRETE_PAD,
			Vector3(0, 45.0, 0))
		course.append(from)
		kinds.append(0)
		for t: float in _pylon_spots(from, to):
			course.append(from.lerp(to, t))
			kinds.append(1)
		course.append(to)
		kinds.append(0)
		while sides.size() < course.size():
			sides.append(k)
	for kind: int in kinds:
		pylons += 1 if kind != 0 else 0
	# The panel's fold, half way up: FENCE_LEAN in from the course, along each point's mitre (the
	# sum of the inward normals of the stretches either side, scaled so each stretch's fold lies
	# parallel to it).
	var fold := (RAIL_HEIGHT - CURB_HEIGHT) * 0.5 * tan(deg_to_rad(FENCE_LEAN))
	var folds := PackedVector3Array()
	for i: int in course.size():
		var before := _inward(course[i - 1], course[i])
		var after := _inward(course[i], course[(i + 1) % course.size()])
		folds.append(course[i] + (before + after) / (1.0 + before.dot(after)) * fold
			+ Vector3(0, (RAIL_HEIGHT + CURB_HEIGHT) * 0.5, 0))

	var index := 0
	for i: int in course.size():
		if kinds[i] != 0:
			_pylon(mesh, course[i], kinds[i] == 2, float(index) / pylons)
			index += 1
		var next := course[(i + 1) % course.size()]
		var rail := Vector3(0, RAIL_HEIGHT, 0)
		Parts.pipe(mesh, course[i] + rail, next + rail, RAIL_RADIUS, Parts.ROD, 8, false)
		if kinds[i] == 0:
			# A ball joint where the rail bends round a corner cut, as Parts.pipe_run makes.
			mesh.orb(RAIL_RADIUS, 8, 4, course[i] + rail, Parts.ROD)
		# The panel, folded: its lower half leaning in to the fold and its upper half out from it,
		# so one half faces the camera on every side. It is see-through and drawn with back faces
		# culled: one face each way.
		var j := (i + 1) % course.size()
		var field := FENCE_FIELD.phased(sides[i] * 0.25)
		for panel: PackedVector3Array in [
				PackedVector3Array([course[i] + Vector3(0, CURB_HEIGHT, 0), next + Vector3(0, CURB_HEIGHT, 0), folds[j], folds[i]]),
				PackedVector3Array([folds[i], folds[j], next + rail, course[i] + rail])]:
			mesh.polygon(panel, field)
			panel.reverse()
			mesh.polygon(panel, field)

	boundary = _add_mesh(mesh.to_mesh(), true)
	boundary_outline = _add_mesh(mesh.to_outline_mesh(), false)


## The horizontal unit normal of the perimeter's stretch from `from` to `to` that points in, towards
## the field.
static func _inward(from: Vector3, to: Vector3) -> Vector3:
	var normal := Vector3(to.z - from.z, 0.0, from.x - to.x).normalized()
	return normal if normal.dot(-(from + to)) > 0.0 else -normal


## Where the pylons stand along one side of the perimeter, from `from` to `to`: at every
## PLATE_CELLS-th line of the grid across it, as fractions of the way along, in order.
func _pylon_spots(from: Vector3, to: Vector3) -> PackedFloat32Array:
	var along_x := absf(to.x - from.x) > absf(to.z - from.z)
	var cells := grid_size.x if along_x else grid_size.y
	var start := from.x if along_x else from.z
	var end := to.x if along_x else to.z
	var spots := PackedFloat32Array()
	for line: int in range(PLATE_CELLS, cells, PLATE_CELLS):
		var t := (line - cells * 0.5 - start) / (end - start)
		if t > 0.0 and t < 1.0:
			spots.append(t)
	spots.sort()
	return spots


## A pylon standing on `foot`: a plated post with a hazard band near its top, a gunmetal cap, and
## on it a lamp pulsing at `phase`, or on a corner, turned to face across the cut and taller, a
## beacon blinking in its place.
static func _pylon(mesh: LowPolyMesh, foot: Vector3, corner: bool, phase: float) -> void:
	var height := CORNER_PYLON_HEIGHT if corner else PYLON_HEIGHT
	var turn := Vector3(0, 45.0 if corner else 0.0, 0)
	mesh.box_chamfered(Vector3(PYLON_WIDTH, height, PYLON_WIDTH), 0.06, foot, PYLON, turn)
	mesh.box_chamfered(Vector3(PYLON_WIDTH + 0.03, 0.12, PYLON_WIDTH + 0.03), 0.03,
		foot + Vector3(0, height - 0.28, 0), Parts.HAZARD, turn)
	var cap := foot + Vector3(0, height, 0)
	mesh.box_chamfered(Vector3(PYLON_WIDTH + 0.06, 0.08, PYLON_WIDTH + 0.06), 0.03, cap, PYLON_CAP, turn)
	if corner:
		mesh.dome(0.12, 0.16, 10, 3, cap + Vector3(0, 0.08, 0), PYLON_BEACON.phased(phase))
	else:
		mesh.dome(0.1, 0.09, 8, 3, cap + Vector3(0, 0.08, 0), PYLON_LAMP.phased(phase))


## The curb's plan at `offset` out from its inner edge and at height `y`: the field's edge
## CURB_GAP + offset out, with each corner cut, as eight corners going round.
func _curb_loop(offset: float, y: float) -> PackedVector3Array:
	var reach := Vector2(grid_size) * 0.5 + Vector2.ONE * (CURB_GAP + offset)
	# Offsetting a 45 degree cut by `offset` lengthens it along each side by (2 - sqrt 2) offset.
	var cut := CURB_CORNER + offset * (2.0 - sqrt(2.0))
	return PackedVector3Array([
		Vector3(reach.x - cut, y, reach.y), Vector3(reach.x, y, reach.y - cut),
		Vector3(reach.x, y, -reach.y + cut), Vector3(reach.x - cut, y, -reach.y),
		Vector3(-reach.x + cut, y, -reach.y), Vector3(-reach.x, y, -reach.y + cut),
		Vector3(-reach.x, y, reach.y - cut), Vector3(-reach.x + cut, y, reach.y),
	])


## The faces between two curb loops, facing out from the field when `outwards` is 1, in when -1,
## and up when they are level.
static func _curb_band(mesh: LowPolyMesh, from: PackedVector3Array, to: PackedVector3Array, outwards: float) -> void:
	for i: int in from.size():
		var j := (i + 1) % from.size()
		var quad := PackedVector3Array([from[i], from[j], to[j], to[i]])
		var middle := (from[i] + from[j] + to[i] + to[j]) * 0.25
		var facing := Vector3(middle.x * outwards, 1.0, middle.z * outwards)
		if (quad[1] - quad[0]).cross(quad[2] - quad[0]).dot(facing) < 0.0:
			quad.reverse()
		mesh.polygon(quad, Parts.CONCRETE_PAD)


## Adds an instance of `mesh`, casting a shadow or not.
func _add_mesh(mesh: Mesh, casts_shadow: bool) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	if not casts_shadow:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


## The land around the field: a smooth-shaded ring out to TERRAIN_EXTENT whose inner edge lies on
## the field's at y = 0, built as one indexed mesh from a lattice of points (TERRAIN_FINE_REACH,
## TERRAIN_COARSE, TERRAIN_MESA_REACH). Where larger cells meet smaller ones, a larger cell fans
## out from the point in the middle of its edge, so no point lies on another cell's edge. Each
## point's normal comes from its lattice neighbours' heights, once, and the ink outline (one more
## mesh, on the same points and normals) inks the ridges and crater rims the camera sees over. The
## lattice lies on the ground without the mesas and leaves out the cells under them; each mesa is
## a flat top and a wall of its own that follow its outline (_mesa_rings), with hard creases at the
## rim and the foot, which the outline inks with fins (_fin).
## Each point is tinted by slope and place (ROCK_SLOPE_Y, SHADOW_SLOPE_Y, CRATER_FLOOR), a tint the
## faces between points blend and the terrain shader draws over (MaterialKit.terrain). The
## terrain receives shadows and casts none.
func _build_terrain(rng: SeededRng) -> void:
	_noise.resize(NOISE_SIZE * NOISE_SIZE)
	for i: int in _noise.size():
		_noise[i] = rng.range_int(0, 1000) / 1000.0
	_place_features(rng)

	# The lattice is in half units: point (i, j) is world (i / 2 - half.x, j / 2 - half.y), so the
	# field spans [0, 2 grid_size]. Fine cells, 1 unit square, fill [fine_low, fine_high] but the
	# field's inside, and coarse ones, TERRAIN_COARSE square, fill the rest out to [low, high]; both
	# ranges are multiples of the coarse cell, so the lattices meet. Fine cells within the mesas'
	# reach (_refined) are cut into four.
	var half := Vector2(grid_size) * 0.5
	var coarse := 2 * TERRAIN_COARSE
	var fine_low := -2 * Vector2i(ceili(TERRAIN_FINE_REACH - half.x), ceili(TERRAIN_FINE_REACH - half.y))
	var fine_high := 2 * (grid_size + Vector2i(grid_size.x % 2, grid_size.y % 2)) - fine_low
	var reach := coarse * ceili((TERRAIN_EXTENT - TERRAIN_FINE_REACH) / TERRAIN_COARSE)
	var low := fine_low - Vector2i(reach, reach)
	var high := fine_high + Vector2i(reach, reach)
	var columns := high.x - low.x + 1
	var rows := high.y - low.y + 1

	# The cells, each as its first corner and its size in half units (1 a refined one); the points,
	# each one's size, the smallest of the cells it is a corner of (0 off the lattice); and their
	# places on the lattice, in order.
	var cells: Array[Vector3i] = []
	var spans := PackedInt32Array()
	spans.resize(columns * rows)
	var places := PackedInt32Array()
	for j: int in range(low.y, high.y, coarse):
		for i: int in range(low.x, high.x, coarse):
			if i < fine_low.x or i >= fine_high.x or j < fine_low.y or j >= fine_high.y:
				cells.append(Vector3i(i, j, coarse))
	for j: int in range(fine_low.y, fine_high.y, 2):
		for i: int in range(fine_low.x, fine_high.x, 2):
			if (i < 0 or i >= 2 * grid_size.x or j < 0 or j >= 2 * grid_size.y) \
					and not _under_mesa(i * 0.5 - half.x, j * 0.5 - half.y, 1.0):
				# A refined cell keeps a fine cell's width from the coarse ones, so a coarse cell's
				# edge holds at most one point between its corners.
				var inside := i > fine_low.x and i < fine_high.x - 2 and j > fine_low.y and j < fine_high.y - 2
				var refined := inside and _refined((i + 1) * 0.5 - half.x, (j + 1) * 0.5 - half.y)
				cells.append(Vector3i(i, j, 1 if refined else 2))
	for cell: Vector3i in cells:
		var first := (cell.y - low.y) * columns + cell.x - low.x
		var span := 2 if cell.z == 1 else cell.z
		var corners := PackedInt32Array([first, first + span, first + span * columns, first + span * columns + span])
		if cell.z == 1:
			corners.append_array(PackedInt32Array([first + 1, first + columns, first + columns + 1,
				first + columns + 2, first + 2 * columns + 1]))
		for place: int in corners:
			if spans[place] == 0:
				places.append(place)
				spans[place] = cell.z
			elif cell.z < spans[place]:
				spans[place] = cell.z
	places.sort()

	# The points, each with its vertex in `ids` (-1 off the lattice) and its height in `heights`.
	var ids := PackedInt32Array()
	ids.resize(columns * rows)
	ids.fill(-1)
	var heights := PackedFloat32Array()
	heights.resize(columns * rows)
	var vertices := PackedVector3Array()
	for place: int in places:
		var x := (place % columns + low.x) * 0.5 - half.x
		var z := (place / columns + low.y) * 0.5 - half.y
		var y := _height(x, z, false)
		ids[place] = vertices.size()
		heights[place] = y
		vertices.append(Vector3(x, y, z))

	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for v: int in vertices.size():
		var place := places[v]
		var column := place % columns
		var row := place / columns
		var step := spans[place]
		# The rise across the point along x and z: between its neighbours `step` either side, or
		# 2 `step` where the lattice coarsens, or the point itself at an edge.
		var east := place
		var west := place
		var north := place
		var south := place
		if column + step < columns and ids[place + step] >= 0:
			east = place + step
		elif column + 2 * step < columns and ids[place + 2 * step] >= 0:
			east = place + 2 * step
		if column >= step and ids[place - step] >= 0:
			west = place - step
		elif column >= 2 * step and ids[place - 2 * step] >= 0:
			west = place - 2 * step
		if row + step < rows and ids[place + step * columns] >= 0:
			south = place + step * columns
		elif row + 2 * step < rows and ids[place + 2 * step * columns] >= 0:
			south = place + 2 * step * columns
		if row >= step and ids[place - step * columns] >= 0:
			north = place - step * columns
		elif row >= 2 * step and ids[place - 2 * step * columns] >= 0:
			north = place - 2 * step * columns
		var along_x := 0.0
		var along_z := 0.0
		if east != west:
			along_x = (heights[east] - heights[west]) / ((east - west) * 0.5)
		if south != north:
			along_z = (heights[south] - heights[north]) / ((south - north) / columns * 0.5)
		var normal := Vector3(-along_x, 1.0, -along_z).normalized()
		normals.append(normal)
		var at := vertices[v]
		# The craters all lie inside the fine lattice.
		colors.append(_tint(normal, _crater_floor(at.x, at.z) if step < coarse else 0.0))

	# Each cell's triangles, going round as (i, j), (i + span, j), (i + span, j + span),
	# (i, j + span), which faces up; a refined cell's four quarters each the same. A cell with no
	# point in the middle of an edge is two triangles whose diagonals alternate, so the faces do not
	# all lean one way; one beside smaller cells fans out from the first such point, so no point
	# lies on another cell's edge.
	var indices := PackedInt32Array()
	for cell: Vector3i in cells:
		var span := cell.z
		var place := (cell.y - low.y) * columns + cell.x - low.x
		if span == 1:
			for quarter: int in 4:
				var at := place + quarter % 2 + quarter / 2 * columns
				indices.append_array(_cell_quad(ids[at], ids[at + 1], ids[at + columns + 1], ids[at + columns],
					(cell.x + quarter % 2 - low.x + cell.y + quarter / 2 - low.y) % 2 == 0))
			continue
		var middle := span / 2
		# Going round: each corner, then the point in the middle of the edge after it, or -1.
		var loop := PackedInt32Array([ids[place], ids[place + middle], ids[place + span],
			ids[place + middle * columns + span], ids[place + span * columns + span],
			ids[place + span * columns + middle], ids[place + span * columns], ids[place + middle * columns]])
		var fan := -1
		for k: int in [1, 3, 5, 7]:
			if loop[k] >= 0:
				fan = k
				break
		if fan < 0:
			indices.append_array(_cell_quad(loop[0], loop[2], loop[4], loop[6],
				((cell.x - low.x) / span + (cell.y - low.y) / span) % 2 == 0))
			continue
		var around := PackedInt32Array()
		for k: int in range(1, 8):
			if loop[(fan + k) % 8] >= 0:
				around.append(loop[(fan + k) % 8])
		for k: int in around.size() - 1:
			indices.append_array(PackedInt32Array([loop[fan], around[k], around[k + 1]]))

	# Each mesa: its flat top, a fan from its middle out to its rim, and its wall, a skirt from the
	# rim down to its foot below the ground, each with its own points and normals, so the rim and
	# the foot are hard creases. The ink outline has fins along both creases: at each, a strip
	# between the two faces' points, which the outline's push opens into a line (_fin). The foot's
	# fins have points of their own, at the foot on the ground, after the body's in the outline.
	var ink_vertices := PackedVector3Array()
	var ink_normals := PackedVector3Array()
	var ink_indices := PackedInt32Array()
	var mesa_walls: Array[Array] = []
	for k: int in mesas.size():
		var rings := _mesa_rings(k)
		mesa_walls.append(rings)
		var rim := rings[0]
		var foot := rings[1]
		var rim_normals := rings[2]
		var foot_normals := rings[3]
		var count := rim.size()
		var middle := vertices.size()
		var top := middle + 1
		var wall := top + count
		vertices.append(Vector3(mesas[k].x, mesas[k].w, mesas[k].y))
		vertices.append_array(rim)
		vertices.append_array(rim)
		for i: int in count:
			vertices.append(foot[i] - Vector3(0.0, MESA_SINK, 0.0))
		for i: int in 1 + count:
			normals.append(Vector3.UP)
			colors.append(_tint(Vector3.UP, 0.0))
		normals.append_array(rim_normals + foot_normals)
		for normal: Vector3 in rim_normals + foot_normals:
			colors.append(_tint(normal, 0.0))
		for i: int in count:
			var j := (i + 1) % count
			var out := Vector3(rim[i].x - mesas[k].x, 0.0, rim[i].z - mesas[k].y)
			indices.append_array(_facing(vertices, middle, top + i, top + j, Vector3.UP))
			indices.append_array(_facing(vertices, wall + i, wall + j, wall + count + j, out))
			indices.append_array(_facing(vertices, wall + i, wall + count + j, wall + count + i, out))
			ink_indices.append_array(_fin(rim[i], rim[j], Vector3.UP, rim_normals[i], rim_normals[j],
				top + i, top + j, wall + j, wall + i))
	for rings: Array in mesa_walls:
		var foot: PackedVector3Array = rings[1]
		var foot_normals: PackedVector3Array = rings[3]
		var ground_normals: PackedVector3Array = rings[4]
		var count := foot.size()
		var ground := vertices.size() + ink_vertices.size()
		var footing := ground + count
		ink_vertices.append_array(foot + foot)
		ink_normals.append_array(ground_normals + foot_normals)
		for i: int in count:
			var j := (i + 1) % count
			ink_indices.append_array(_fin(foot[i], foot[j], ground_normals[i], foot_normals[i], foot_normals[j],
				ground + i, ground + j, footing + j, footing + i))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices + ink_vertices
	arrays[Mesh.ARRAY_NORMAL] = normals + ink_normals
	arrays[Mesh.ARRAY_INDEX] = indices + ink_indices
	var hull := ArrayMesh.new()
	hull.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	hull.surface_set_material(0, MaterialKit.ink())
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	arrays[Mesh.ARRAY_COLOR] = colors
	var body := ArrayMesh.new()
	body.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := MaterialKit.terrain()
	material.set_shader_parameter("field", _field_texture)
	material.set_shader_parameter("grid_size", Vector2(grid_size))
	material.set_shader_parameter("sun_across", SUN_ACROSS)
	body.surface_set_material(0, material)
	terrain = _add_mesh(body, false)
	terrain_outline = _add_mesh(hull, false)


## The two triangles of a terrain cell going round `a`, `b`, `c`, `d` (which faces up), split along
## a-c when `even`, else along b-d.
static func _cell_quad(a: int, b: int, c: int, d: int, even: bool) -> PackedInt32Array:
	if even:
		return PackedInt32Array([a, b, c, a, c, d])
	return PackedInt32Array([a, b, d, b, c, d])


## The terrain's tint at a point whose normal is `normal`, `floor_weight` on a crater's floor: by
## slope and place (ROCK_SLOPE_Y, SHADOW_SLOPE_Y, LIT_SLOPE_Y). Each weight steps smoothly from 0
## to 1 across its threshold; a slope is steeper than a threshold where its normal's y is below it.
static func _tint(normal: Vector3, floor_weight: float) -> Color:
	var steep := smoothstep(ROCK_SLOPE_Y + 0.1, ROCK_SLOPE_Y - 0.1, normal.y)
	if steep >= 1.0:
		return MaterialKit.ROCK
	var facing := normal.x * SUN_ACROSS.x + normal.z * SUN_ACROSS.y
	var shadow_side := smoothstep(SHADOW_SLOPE_Y + 0.03, SHADOW_SLOPE_Y - 0.03, normal.y) \
		* smoothstep(-0.05, -0.15, facing)
	var lit_side := smoothstep(LIT_SLOPE_Y + 0.03, LIT_SLOPE_Y - 0.03, normal.y) * smoothstep(0.1, 0.2, facing)
	return MaterialKit.TERRAIN.lerp(MaterialKit.TERRAIN_LIGHT, lit_side) \
		.lerp(MaterialKit.TERRAIN_DARK, maxf(shadow_side, floor_weight)) \
		.lerp(MaterialKit.ROCK, steep)


## The triangle `a`, `b`, `c` of `points`, in the order that faces `front` (the terrain's meshes
## are raw arrays: a triangle faces away from the cross product of its first two edges).
static func _facing(points: PackedVector3Array, a: int, b: int, c: int, front: Vector3) -> PackedInt32Array:
	if (points[b] - points[a]).cross(points[c] - points[a]).dot(front) > 0.0:
		return PackedInt32Array([a, c, b])
	return PackedInt32Array([a, b, c])


## An ink fin along a crease of a mesa, from `from` to `to`: two triangles between the points
## `a`, `b` (on one face, both of normal `face`) and `c`, `d` (on the other, at `to` and `from`, of
## normals `to_normal` and `from_normal`). They lie on one line until the ink shader pushes each
## point out along its normal, which opens the fin into a strip about the outline's width across
## the crease. It faces into the crease, so the ink shader, which draws back faces, draws it.
static func _fin(from: Vector3, to: Vector3, face: Vector3, from_normal: Vector3, to_normal: Vector3,
		a: int, b: int, c: int, d: int) -> PackedInt32Array:
	var pushed := PackedVector3Array([from + face * 0.1, to + face * 0.1, to + to_normal * 0.1, from + from_normal * 0.1])
	var into := -(face + from_normal)
	var fin := _facing(pushed, 0, 1, 2, into) + _facing(pushed, 0, 2, 3, into)
	var corners := PackedInt32Array([a, b, c, d])
	for k: int in fin.size():
		fin[k] = corners[fin[k]]
	return fin


## Mesa `k`'s wall, sampled every MESA_STEP degrees round its outline (_mesa_edge): its rim,
## MESA_WALL in from the outline at the height of its top, and its foot, MESA_FOOT out from it on
## the ground under it; each ring's normals (the wall's, smooth round it); and the ground's normals
## at the foot. As [rim, foot, rim normals, foot normals, ground normals].
func _mesa_rings(k: int) -> Array[PackedVector3Array]:
	var mesa := mesas[k]
	var count := roundi(360.0 / MESA_STEP)
	var rim := PackedVector3Array()
	var foot := PackedVector3Array()
	for i: int in count:
		var turn := TAU * i / count
		var out := Vector2(cos(turn), sin(turn))
		var edge := _mesa_edge(k, out.x, out.y)
		var at := Vector2(mesa.x, mesa.y) + out * (edge - MESA_WALL)
		rim.append(Vector3(at.x, mesa.w, at.y))
		at = Vector2(mesa.x, mesa.y) + out * (edge + MESA_FOOT)
		foot.append(Vector3(at.x, _height(at.x, at.y, false), at.y))
	var rim_normals := PackedVector3Array()
	var foot_normals := PackedVector3Array()
	var ground_normals := PackedVector3Array()
	for i: int in count:
		var before := (i + count - 1) % count
		var after := (i + 1) % count
		var out := Vector3(foot[i].x - mesa.x, 0.0, foot[i].z - mesa.y)
		var down := foot[i] - rim[i]
		var normal := (rim[after] - rim[before]).cross(down).normalized()
		rim_normals.append(normal if normal.dot(out) > 0.0 else -normal)
		normal = (foot[after] - foot[before]).cross(down).normalized()
		foot_normals.append(normal if normal.dot(out) > 0.0 else -normal)
		var e := 0.25
		var x := foot[i].x
		var z := foot[i].z
		ground_normals.append(Vector3((_height(x - e, z, false) - _height(x + e, z, false)) / (2.0 * e), 1.0,
			(_height(x, z - e, false) - _height(x, z + e, false)) / (2.0 * e)).normalized())
	return [rim, foot, rim_normals, foot_normals, ground_normals]


## Whether the lattice cell `size` square whose first corner is (`x`, `z`) lies under a mesa: each
## corner MESA_FOOT_MARGIN or more inside its foot, so its wall covers the cell.
func _under_mesa(x: float, z: float, size: float) -> bool:
	for k: int in mesas.size():
		var under := true
		for corner: Vector2 in [Vector2(x, z), Vector2(x + size, z), Vector2(x, z + size), Vector2(x + size, z + size)]:
			var dx := corner.x - mesas[k].x
			var dz := corner.y - mesas[k].y
			# The outline reaches at most 1.18 radii from the middle.
			if dx * dx + dz * dz > (mesas[k].z * 1.18 + MESA_FOOT) * (mesas[k].z * 1.18 + MESA_FOOT) \
					or sqrt(dx * dx + dz * dz) > _mesa_edge(k, dx, dz) + MESA_FOOT - MESA_FOOT_MARGIN:
				under = false
				break
		if under:
			return true
	return false


## Places the terrain's features from `rng`, inside the fine lattice: two mesas towards the far
## edge of the view (up the screen, -x and -z), off its diagonal so that they show at the widest
## zoom, their flat tops 4 to 6 above the dunes' crests; three to five craters well clear of the
## field and of each other; and the channel's course, away from the mesas.
func _place_features(rng: SeededRng) -> void:
	var half := Vector2(grid_size) * 0.5
	for attempt: int in 80:
		if mesas.size() == 2:
			break
		var angle := deg_to_rad(225.0 + rng.range_int(15, 45) * (1 if rng.range_int(0, 1) == 0 else -1))
		var radius := rng.range_int(50, 75) / 10.0
		var at := Vector2(cos(angle), sin(angle)) * rng.range_int(300, 420) / 10.0
		var height := rng.range_int(40, 60) / 10.0
		var phases := Vector2(rng.range_int(0, 359), rng.range_int(0, 359)) * TAU / 360.0
		var out := _out_of_field(at.x, at.y)
		if maxf(absf(at.x), absf(at.y)) + radius + 2.0 <= TERRAIN_FINE_REACH and out >= radius + 6.0 \
				and _clear(at, radius + 3.0):
			mesas.append(Vector4(at.x, at.y, radius, 0.8 * _dune_height(out, blend_end(at.x, at.y)) + out * RISE + height))
			_mesa_phases.append(phases)
	var count := rng.range_int(3, 5)
	for attempt: int in 80:
		if craters.size() == count:
			break
		var angle := TAU * rng.range_int(0, 3599) / 3600.0
		var radius := rng.range_int(60, 120) / 10.0
		var distance := maxf(half.x, half.y) + radius * 1.4 + rng.range_int(40, 180) / 10.0
		var at := Vector2(cos(angle), sin(angle)) * distance
		if _out_of_field(at.x, at.y) >= radius * 1.4 + 4.0 and _clear(at, radius * 1.5) \
				and maxf(absf(at.x), absf(at.y)) + radius * 1.5 <= TERRAIN_FINE_REACH:
			craters.append(Vector3(at.x, at.y, radius))
	var course := 0.0
	for attempt: int in 40:
		course = TAU * rng.range_int(0, 3599) / 3600.0
		var apart := true
		for mesa: Vector4 in mesas:
			apart = apart and absf(angle_difference(course, atan2(mesa.y, mesa.x))) > 0.9
		if apart:
			break
	var edge := minf(half.x / maxf(absf(cos(course)), 0.001), half.y / maxf(absf(sin(course)), 0.001))
	_channel = Vector3(course, TAU * rng.range_int(0, 359) / 360.0, edge + 6.0)
	_channel_course = Vector2(cos(course), sin(course))


## Whether a feature reaching `extent` from `at` stays clear of every crater and mesa so far.
func _clear(at: Vector2, extent: float) -> bool:
	for crater: Vector3 in craters:
		if at.distance_to(Vector2(crater.x, crater.y)) < extent + crater.z * 1.5:
			return false
	for mesa: Vector4 in mesas:
		if at.distance_to(Vector2(mesa.x, mesa.y)) < extent + mesa.z + 3.0:
			return false
	return true


## Chamfered rocks scattered on the terrain clear of the curb, about a quarter of those over 0.8
## in radius with a smaller rock on top, into `mesh`. Each sits on the lowest ground under it, so
## it does not float on a slope. Returns each rock's (x, z, reach).
func _build_rocks(mesh: LowPolyMesh, rng: SeededRng) -> Array[Vector3]:
	var half := Vector2(grid_size) * 0.5
	var spots: Array[Vector3] = []
	var placed := 0
	while placed < ROCK_COUNT:
		var angle := TAU * rng.range_int(0, 3599) / 3600.0
		var distance := maxf(half.x, half.y) + 2.0 + rng.range_int(0, 4000) / 100.0
		var size := rng.range_int(0, 1000) / 1000.0
		var radius := lerpf(ROCK_SMALLEST, ROCK_LARGEST, size * size)
		var x := cos(angle) * distance
		var z := sin(angle) * distance
		if _out_of_field(x, z) < radius + 1.5:
			continue
		placed += 1
		spots.append(Vector3(x, z, radius * 1.05))
		var top := _rock(mesh, Vector3(x, _lowest_ground(x, z, radius) - 0.1 * radius, z), radius, rng)
		if radius > 0.8 and rng.range_int(0, 99) < ROCK_STACKED:
			var lean := Vector2(rng.range_int(-25, 25), rng.range_int(-25, 25)) * radius / 100.0
			var smaller := radius * rng.range_int(40, 55) / 100.0
			_rock(mesh, Vector3(x + lean.x, top - 0.1 * radius, z + lean.y), smaller, rng)
	return spots


## Rubble beside the curb: RUBBLE_ROCKS small rocks into `mesh`, a quarter along each side of the
## field, each in a stretch of the side of its own and a random RUBBLE_ROCK_OUT out, so they spread
## evenly and form no line. A rock that would come near a crater or a mesa (_clear), the channel, a
## rock in `taken` (each (x, z, reach); it adds its own) or an outcrop tries again in its stretch,
## up to 20 times. Each rests on the lowest ground under it.
func _scatter_rubble(mesh: LowPolyMesh, taken: Array[Vector3], rng: SeededRng) -> void:
	var half := Vector2(grid_size) * 0.5
	var stretches := RUBBLE_ROCKS / 4
	for k: int in RUBBLE_ROCKS:
		# The side's outward direction, +x, +z, -x and -z in turn, and the direction along it.
		var normal: Vector2 = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP][k % 4]
		var along := Vector2(-normal.y, normal.x)
		for attempt: int in 20:
			var radius := lerpf(RUBBLE_ROCK_RADIUS.x, RUBBLE_ROCK_RADIUS.y, rng.range_int(0, 100) / 100.0)
			var out := lerpf(RUBBLE_ROCK_OUT.x, RUBBLE_ROCK_OUT.y, rng.range_int(0, 1000) / 1000.0)
			var t := (k / 4 + rng.range_int(0, 1000) / 1000.0) / stretches * 2.0 - 1.0
			var at := normal * (absf(normal.dot(half)) + out) + along * t * absf(along.dot(half))
			var fits := _clear(at, radius) and _off_channel(at, radius)
			for spot: Vector3 in taken:
				fits = fits and at.distance_to(Vector2(spot.x, spot.y)) > spot.z + radius + 0.2
			# No part of an outcrop reaches 3 from its centre.
			for spot: Vector3 in outcrop_spots:
				fits = fits and at.distance_to(Vector2(spot.x, spot.z)) > radius + 3.0
			if fits:
				taken.append(Vector3(at.x, at.y, radius * 1.05))
				_rock(mesh, Vector3(at.x, _lowest_ground(at.x, at.y, radius) - 0.2 * radius, at.y), radius, rng)
				break


## The lowest ground under a rock of `radius` at (`x`, `z`): at its middle and at four points most
## of the way to its edge.
func _lowest_ground(x: float, z: float, radius: float) -> float:
	var ground := terrain_height(x, z)
	for k: int in 4:
		var side := Vector2(cos(k * PI * 0.5), sin(k * PI * 0.5)) * radius * 0.8
		ground = minf(ground, terrain_height(x + side.x, z + side.y))
	return ground


## One rock, a chamfered chunk: a jittered ring of corners on the ground, a shoulder ring a
## little in and most of the way up, a top ring cut in from it (the chamfer) and a low peak,
## flat shaded. Returns the height of its top.
static func _rock(mesh: LowPolyMesh, pos: Vector3, radius: float, rng: SeededRng) -> float:
	var sides := rng.range_int(5, 7)
	var turn := TAU * rng.range_int(0, 359) / 360.0
	var height := radius * rng.range_int(60, 95) / 100.0
	var lower := PackedVector3Array()
	var shoulder := PackedVector3Array()
	var upper := PackedVector3Array()
	for j: int in sides:
		var angle := turn + TAU * (j + rng.range_int(-15, 15) / 100.0) / sides
		var out := Vector3(cos(angle), 0.0, sin(angle)) * radius * rng.range_int(80, 105) / 100.0
		lower.append(pos + out)
		shoulder.append(pos + out * 0.9 + Vector3(0.0, height * rng.range_int(62, 78) / 100.0, 0.0))
		upper.append(pos + out * 0.62 + Vector3(0.0, height * rng.range_int(90, 100) / 100.0, 0.0))
	var lean := Vector2(rng.range_int(-15, 15), rng.range_int(-15, 15)) * radius / 100.0
	var peak := pos + Vector3(lean.x, height * 1.06, lean.y)
	for j: int in sides:
		var k := (j + 1) % sides
		mesh.triangle(lower[j], shoulder[j], shoulder[k], ROCK_SIDE)
		mesh.triangle(lower[j], shoulder[k], lower[k], ROCK_SIDE)
		mesh.triangle(shoulder[j], upper[j], upper[k], ROCK_TOP)
		mesh.triangle(shoulder[j], upper[k], shoulder[k], ROCK_TOP)
		mesh.triangle(upper[j], peak, upper[k], ROCK_TOP)
	return pos.y + height


## Crystal outcrops on the ring: OUTCROP_COUNT clusters of OUTCROP_SHARDS glowing shards, each a
## six-sided crystal leaning out from its cluster's middle, in the resource colours in turn from a
## seeded start. Every part of a cluster stays OUTCROP_GAP clear of the field, and clusters keep
## off the mesas, out of the craters' bowls and apart. One mesh with its outline.
func _build_outcrops(rng: SeededRng) -> void:
	var half := Vector2(grid_size) * 0.5
	var count := rng.range_int(OUTCROP_COUNT.x, OUTCROP_COUNT.y)
	var first := rng.range_int(0, SHARDS.size() - 1)
	var mesh := LowPolyMesh.new()
	for attempt: int in 200:
		if outcrop_spots.size() == count:
			break
		var angle := TAU * rng.range_int(0, 3599) / 3600.0
		var centre := Vector2(cos(angle), sin(angle)) * (maxf(half.x, half.y) + rng.range_int(60, 260) / 10.0)
		var shards := rng.range_int(OUTCROP_SHARDS.x, OUTCROP_SHARDS.y)
		var spread := 0.3 + 0.15 * shards
		# A shard's tip leans at most SHARD_LENGTH.y * sin(30 degrees) out, plus its radius.
		if _out_of_field(centre.x, centre.y) < OUTCROP_GAP + spread + SHARD_LENGTH.y * 0.75 \
				or not _outcrop_clear(centre, spread + 2.0):
			continue
		var surf := SHARDS[(first + outcrop_spots.size()) % SHARDS.size()]
		var ground := terrain_height(centre.x, centre.y)
		for s: int in shards:
			var offset := Vector2.ZERO
			var length := lerpf(SHARD_LENGTH.x, SHARD_LENGTH.y, rng.range_int(50, 100) / 100.0)
			var tilt := rng.range_int(0, 10)
			var yaw := rng.range_int(0, 359)
			if s > 0:
				var turn := TAU * rng.range_int(0, 359) / 360.0
				offset = Vector2(cos(turn), sin(turn)) * spread * rng.range_int(45, 100) / 100.0
				length = lerpf(SHARD_LENGTH.x, SHARD_LENGTH.y, rng.range_int(0, 55) / 100.0)
				tilt = rng.range_int(12, 30)
				yaw = roundi(rad_to_deg(atan2(offset.x, offset.y)))
			var foot := centre + offset
			var radius := length * rng.range_int(20, 27) / 100.0
			var profile := PackedVector2Array([Vector2(radius, 0.0), Vector2(radius, length * 0.68),
				Vector2(0.0, length)])
			var base := Vector3(foot.x, terrain_height(foot.x, foot.y) - 0.12 * length, foot.y)
			mesh.lathe(profile, 6, base, surf, Vector3(tilt, yaw, 0.0))
		outcrop_spots.append(Vector3(centre.x, ground, centre.y))
	outcrops = _add_mesh(mesh.to_mesh(), true)
	outcrops_outline = _add_mesh(mesh.to_outline_mesh(), false)


## Whether an outcrop reaching `extent` from `at` keeps off the mesas, out of the craters' bowls
## and clear of the outcrops so far.
func _outcrop_clear(at: Vector2, extent: float) -> bool:
	for mesa: Vector4 in mesas:
		if at.distance_to(Vector2(mesa.x, mesa.y)) < extent + mesa.z + 2.0:
			return false
	for crater: Vector3 in craters:
		if at.distance_to(Vector2(crater.x, crater.y)) < extent + crater.z * 0.8:
			return false
	for spot: Vector3 in outcrop_spots:
		if at.distance_to(Vector2(spot.x, spot.z)) < extent + 3.0:
			return false
	return true


## The terrain's height at a point: flat out to TERRAIN_FLAT outside the field, then ridged dunes
## that grow away from it (flattened round the craters) and a gentle rise, the craters' bowls and
## rims and the channel, all blended in by a wandering distance out (blend_end), with rubble over
## it all; and the mesas, each a flat top on a straight wall from its rim to its foot, as their own
## geometry draws them (_mesa_rings). The harness marches the view's rays over it.
func terrain_height(x: float, z: float) -> float:
	return _height(x, z, true)


## The terrain's height at a point, with the mesas or, for the ground under them, without.
func _height(x: float, z: float, with_mesas: bool) -> float:
	var out_x := maxf(absf(x) - grid_size.x * 0.5, 0.0)
	var out_z := maxf(absf(z) - grid_size.y * 0.5, 0.0)
	var out := sqrt(out_x * out_x + out_z * out_z)
	if out <= TERRAIN_FLAT:
		return 0.0
	# From 20 out the relief is full and the dunes grown wherever the blend ends: skipped there.
	var full_out := TERRAIN_BLEND_FAR
	if out < 20.0:
		full_out = blend_end(x, z)
	var rubble := RUBBLE * (2.0 * _noise_at(x * 3.0 + 7.0, z * 3.0 + 13.0) - 1.0) \
		* smoothstep(TERRAIN_FLAT, TERRAIN_FLAT + 2.0, out)
	var ridge := 1.0 - absf(2.0 * _noise_at(x * DUNE_SCALE, z * DUNE_SCALE) - 1.0)
	# _dune_height(out, full_out), written out: this runs for every point of the lattice.
	var dunes := lerpf(DUNES_NEAR, DUNES_FAR, smoothstep(full_out, 20.0, out)) \
		* (0.8 * ridge + 0.2 * _noise_at(x * 2.3 + 37.0, z * 2.3 + 11.0))
	var height := out * RISE
	var distance := sqrt(x * x + z * z)
	# The channel wanders at most CHANNEL_MEANDER from its course: a point well off it is skipped.
	if distance > _channel.z and x * _channel_course.x + z * _channel_course.y > distance * cos(CHANNEL_MEANDER + 0.3):
		var across := _channel_across(x, z, distance)
		if absf(across) < CHANNEL_WIDTH:
			var u := 1.0 - (across / CHANNEL_WIDTH) * (across / CHANNEL_WIDTH)
			height -= CHANNEL_DEPTH * u * u * smoothstep(_channel.z, _channel.z + 5.0, distance)
	# The craters and mesas all lie inside the fine lattice.
	if absf(x) > TERRAIN_FINE_REACH or absf(z) > TERRAIN_FINE_REACH:
		return height + dunes + rubble
	for crater: Vector3 in craters:
		var dx := x - crater.x
		var dz := z - crater.y
		if dx * dx + dz * dz < 4.0 * crater.z * crater.z:
			var t := sqrt(dx * dx + dz * dz) / crater.z
			dunes *= smoothstep(0.8, 1.9, t)
			height += crater.z * _crater_profile(t)
	height += dunes
	height = height * smoothstep(TERRAIN_FLAT, full_out, out) + rubble
	if not with_mesas:
		return height
	for k: int in mesas.size():
		var mesa := mesas[k]
		var dx := x - mesa.x
		var dz := z - mesa.y
		if dx * dx + dz * dz < (mesa.z + 3.0) * (mesa.z + 3.0):
			var edge := _mesa_edge(k, dx, dz)
			var top := clampf((edge + MESA_FOOT - sqrt(dx * dx + dz * dz)) / (MESA_FOOT + MESA_WALL), 0.0, 1.0)
			height = lerpf(height, mesa.w, top)
	return height


## Whether a point lies within TERRAIN_MESA_REACH of a mesa's outline (_mesa_edge), where the
## terrain's lattice is cut to half a unit.
func _refined(x: float, z: float) -> bool:
	for k: int in mesas.size():
		var dx := x - mesas[k].x
		var dz := z - mesas[k].y
		if dx * dx + dz * dz < (mesas[k].z * 1.2 + TERRAIN_MESA_REACH) * (mesas[k].z * 1.2 + TERRAIN_MESA_REACH) \
				and sqrt(dx * dx + dz * dz) < _mesa_edge(k, dx, dz) + TERRAIN_MESA_REACH:
			return true
	return false


## How far across the dry channel's meandering course a point `distance` from the centre lies, in
## world units, either way.
func _channel_across(x: float, z: float, distance: float) -> float:
	var course := _channel.x + CHANNEL_MEANDER * sin(distance / 9.0 + _channel.y)
	return angle_difference(course, atan2(z, x)) * distance


## Whether a point reaching `extent` from `at` keeps out of the dry channel's bed.
func _off_channel(at: Vector2, extent: float) -> bool:
	var distance := at.length()
	return distance + extent < _channel.z or absf(_channel_across(at.x, at.y, distance)) > CHANNEL_WIDTH + extent


## How far out from the field the terrain's relief is full at a point: between TERRAIN_BLEND_NEAR
## and TERRAIN_BLEND_FAR, on a noise whose lattice is 4 units across, so it wanders along the edge.
## The harness checks that it does.
func blend_end(x: float, z: float) -> float:
	return lerpf(TERRAIN_BLEND_NEAR, TERRAIN_BLEND_FAR, _noise_at(x * 1.75 + 101.0, z * 1.75 + 59.0))


## The dunes' height `out` units out from the field, where the relief is full `full_out` out: low
## beside it, growing from there to DUNES_FAR 20 out.
static func _dune_height(out: float, full_out: float) -> float:
	return lerpf(DUNES_NEAR, DUNES_FAR, smoothstep(full_out, 20.0, out))


## Mesa `k`'s outline: its distance from the mesa's centre towards (`dx`, `dz`), irregular.
func _mesa_edge(k: int, dx: float, dz: float) -> float:
	var turn := atan2(dz, dx)
	var phases := _mesa_phases[k]
	return mesas[k].z * (1.0 + 0.12 * sin(3.0 * turn + phases.x) + 0.06 * sin(5.0 * turn + phases.y))


## A crater's height `t` radii from its centre, in radii: a flat floor CRATER_DEPTH deep out to
## 0.45, a wall steepening up to a rim CRATER_RIM high at 1, and a gentler slope outside it.
static func _crater_profile(t: float) -> float:
	var height := CRATER_RIM * exp(-pow((t - 1.0) / (0.15 if t < 1.0 else 0.4), 2.0))
	if t < 1.0:
		height -= CRATER_DEPTH * (1.0 - smoothstep(0.45, 1.0, t))
	return height


## How much a point is on a crater's floor: 1 within CRATER_FLOOR radii of a crater's centre,
## fading out over a tenth of its radius beyond.
func _crater_floor(x: float, z: float) -> float:
	for crater: Vector3 in craters:
		var reach := (CRATER_FLOOR + 0.1) * crater.z
		var squared := (x - crater.x) * (x - crater.x) + (z - crater.y) * (z - crater.y)
		if squared < reach * reach:
			return 1.0 - smoothstep(CRATER_FLOOR, CRATER_FLOOR + 0.1, sqrt(squared) / crater.z)
	return 0.0


## How far a point lies outside the field, in world units (0 inside).
func _out_of_field(x: float, z: float) -> float:
	return Vector2(maxf(absf(x) - grid_size.x * 0.5, 0.0), maxf(absf(z) - grid_size.y * 0.5, 0.0)).length()


## Smoothly interpolated lattice noise in [0, 1]. Written out, as the terrain asks for some
## 30,000 values.
func _noise_at(x: float, z: float) -> float:
	var gx := x / NOISE_CELL
	var gz := z / NOISE_CELL
	var ix := floori(gx)
	var iz := floori(gz)
	var fx := gx - ix
	var fz := gz - iz
	fx = fx * fx * (3.0 - 2.0 * fx)
	fz = fz * fz * (3.0 - 2.0 * fz)
	var left := posmod(ix, NOISE_SIZE)
	var right := (left + 1) % NOISE_SIZE
	var near := posmod(iz, NOISE_SIZE) * NOISE_SIZE
	var far := (near + NOISE_SIZE) % (NOISE_SIZE * NOISE_SIZE)
	var top := _noise[near + left] + (_noise[near + right] - _noise[near + left]) * fx
	var bottom := _noise[far + left] + (_noise[far + right] - _noise[far + left]) * fx
	return top + (bottom - top) * fz
