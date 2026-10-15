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
## rising from low, rough ground beside the curb along an edge that wanders, smooth shaded and
## painted from the material kit's dust and rock by slope, with chamfered rocks, small ones strewn
## beside the curb as rubble, and glowing crystal clusters on it. Each is one mesh with its ink
## outline.

const GROUND_SHADER := preload("res://src/game/ground.gdshader")
## The field texture the ground is drawn from, imported as an Image (tools/gen_textures.gd).
const FIELD_TEXTURE := "res://assets/textures/field.png"
const SCENERY_SEED := 7
## Strength of the ground's cell lines, normally and while placing.
const GRID_LINES := 0.1
const GRID_LINES_PLACING := 0.45
## The terrain reaches TERRAIN_EXTENT from the centre in x and z, on a lattice of 1 unit within
## TERRAIN_FINE_REACH of the centre and of TERRAIN_COARSE beyond.
const TERRAIN_EXTENT := 100.0
const TERRAIN_FINE_REACH := 50.0
const TERRAIN_COARSE := 2
## Outside the field the ground stays flat out to TERRAIN_FLAT (under the curb) and reaches its
## full relief between TERRAIN_BLEND_NEAR and TERRAIN_BLEND_FAR out, wandering along the edge
## (blend_end), so no ramp runs straight along a side. Rubble, RUBBLE high either way, roughens
## the ground from TERRAIN_FLAT out whatever the relief.
const TERRAIN_FLAT := 0.8
const TERRAIN_BLEND_NEAR := 4.0
const TERRAIN_BLEND_FAR := 11.0
const RUBBLE := 0.12
## Spacing of the value-noise lattice behind the dunes and the dust drifts.
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
## A mesa's wall: how far in from its outline the rim's edge lies, and how far out its foot.
const MESA_WALL := 1.4
const MESA_FOOT := 0.4
## The dry channel's half width, depth, and how far it wanders either side of its course (radians).
const CHANNEL_WIDTH := 2.2
const CHANNEL_DEPTH := 1.2
const CHANNEL_MEANDER := 0.22
## Texture repeats per world unit on the terrain: one layer covers between five and six units.
const TERRAIN_UV := 0.18
## The terrain's painting: the rock tint where its normal's y is below ROCK_SLOPE_Y (slopes over
## 35 degrees); the shadow side of slopes over 18 degrees (SHADOW_SLOPE_Y) dark and the lit side
## of slopes over 25 degrees (LIT_SLOPE_Y) light; crater floors (within CRATER_FLOOR radii of the
## centre) dark; dust drifts where the drift noise passes DRIFT. Each blends in smoothly across its
## threshold (the drifts over PAINT_SOFTNESS either side), so the patches between points are
## rounded. The texture is the dust layer everywhere but on the mesas' walls, which take the rock
## layer: the shader cannot blend two layers, so they switch only at the mesas' rims.
const ROCK_SLOPE_Y := 0.819
const SHADOW_SLOPE_Y := 0.95
const LIT_SLOPE_Y := 0.906
const CRATER_FLOOR := 0.75
const DRIFT := 0.76
const PAINT_SOFTNESS := 0.08
## Towards the key light across the ground (main.gd's sun), in world x and z: the terrain's
## painting and the ground shader's light on the field's marks.
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
const RUBBLE_ROCK_OUT := Vector2(1.6, 6.6)
## The crystal outcrops: how many clusters, shards in each, the shards' lengths, and how close any
## part of one may come to the field.
const OUTCROP_COUNT := Vector2i(6, 10)
const OUTCROP_SHARDS := Vector2i(3, 7)
const SHARD_LENGTH := Vector2(0.6, 2.0)
const OUTCROP_GAP := 4.0
## The curb round the field: its height and width, its gap from the field's edge, and how far
## each corner is cut back along each side. A glowing stud stands on it at every plate seam (the
## ground's plates are PLATE_CELLS square) and on each corner.
const CURB_HEIGHT := 0.2
const CURB_WIDTH := 0.3
const CURB_GAP := 0.3
const CURB_CORNER := 0.6
const CURB_BEVEL := 0.04
const PLATE_CELLS := 4
const STUD_RADIUS := 0.1
## The curb's studs: domes of unlit energy cyan, too small for the outline.
static var CURB_STUD := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ENERGY, 1.0, Surf.UNLIT, false, false)
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
	for id: int in views.keys():
		var stale: bool = not state.buildings.has(id)
		if not stale:
			var building: BuildingState = state.buildings[id]
			# A new finished level gets its model; a dragged view keeps its own until dropped.
			stale = views[id].building_type != building.type \
				or (views[id].building_level != building.level and id != dragging_id)
		if stale:
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
	_ground_material.set_shader_parameter("field", ImageTexture.create_from_image(field))
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


## The curb round the field (CURB_*): an octagonal band of concrete with bevelled top edges and
## a glowing stud on it at every plate seam and on each corner, in one mesh with its outline.
## Neither casts a shadow.
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

	# A stud on the middle of the top at every plate seam along the straight sides, and on the
	# middle of each corner cut (between corners 2k and 2k + 1 of the loop).
	var middle := _curb_loop(CURB_WIDTH * 0.5, CURB_HEIGHT)
	var straight := Vector2(middle[0].x, middle[1].z)
	var studs := PackedVector3Array()
	for k: int in 4:
		studs.append((middle[2 * k] + middle[2 * k + 1]) * 0.5)
	for x: int in range(PLATE_CELLS, grid_size.x, PLATE_CELLS):
		var at := x - grid_size.x * 0.5
		if absf(at) < straight.x:
			studs.append(Vector3(at, CURB_HEIGHT, middle[0].z))
			studs.append(Vector3(at, CURB_HEIGHT, -middle[0].z))
	for z: int in range(PLATE_CELLS, grid_size.y, PLATE_CELLS):
		var at := z - grid_size.y * 0.5
		if absf(at) < straight.y:
			studs.append(Vector3(middle[1].x, CURB_HEIGHT, at))
			studs.append(Vector3(-middle[1].x, CURB_HEIGHT, at))
	for stud: Vector3 in studs:
		mesh.dome(STUD_RADIUS, STUD_RADIUS * 0.7, 10, 2, stud, CURB_STUD)

	boundary = _add_mesh(mesh.to_mesh(), false)
	boundary_outline = _add_mesh(mesh.to_outline_mesh(), false)


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
## TERRAIN_COARSE). Where the coarse cells meet the fine ones, a coarse cell fans out from the
## fine point in the middle of its edge, so no point lies on another cell's edge. Each point's
## normal comes from its lattice neighbours' heights, once, and the ink outline (one more mesh,
## on the same points and normals) inks the ridges and crater rims the camera sees over. Each
## point is painted by slope and place (ROCK_SLOPE_Y, SHADOW_SLOPE_Y, CRATER_FLOOR, DRIFT): its
## tint, which the faces between points blend, and its kit layer, the dust but on the mesas' walls
## (rock). The terrain receives shadows and casts none.
func _build_terrain(rng: SeededRng) -> void:
	_noise.resize(NOISE_SIZE * NOISE_SIZE)
	for i: int in _noise.size():
		_noise[i] = rng.range_int(0, 1000) / 1000.0
	_place_features(rng)

	# Lattice point (i, j) is world (i - half.x, j - half.y), so the field spans [0, grid_size].
	# Fine points fill [fine_low, fine_high] but the field's inside, coarse ones every
	# TERRAIN_COARSE out to [low, high]; both ranges are even, so the lattices meet.
	var half := Vector2(grid_size) * 0.5
	var fine_low := -Vector2i(ceili(TERRAIN_FINE_REACH - half.x), ceili(TERRAIN_FINE_REACH - half.y))
	var fine_high := grid_size - fine_low + Vector2i(grid_size.x % 2, grid_size.y % 2)
	var reach := TERRAIN_COARSE * ceili((TERRAIN_EXTENT - TERRAIN_FINE_REACH) / TERRAIN_COARSE)
	var low := fine_low - Vector2i(reach, reach)
	var high := fine_high + Vector2i(reach, reach)
	var columns := high.x - low.x + 1
	var rows := high.y - low.y + 1

	# The points, each with its vertex in `ids` (-1 off the lattice) and its height in `heights`.
	var ids := PackedInt32Array()
	ids.resize(columns * rows)
	ids.fill(-1)
	var heights := PackedFloat32Array()
	heights.resize(columns * rows)
	var vertices := PackedVector3Array()
	var places := PackedInt32Array()
	var coarse_columns := PackedInt32Array(range(low.x, high.x + 1, TERRAIN_COARSE))
	for j: int in range(low.y, high.y + 1):
		var coarse_row := (j - low.y) % TERRAIN_COARSE == 0
		var row := coarse_columns
		if j >= fine_low.y and j <= fine_high.y:
			row = PackedInt32Array()
			if coarse_row:
				row.append_array(PackedInt32Array(range(low.x, fine_low.x, TERRAIN_COARSE)))
			if j > 0 and j < grid_size.y:
				row.append_array(PackedInt32Array(range(fine_low.x, 1)))
				row.append_array(PackedInt32Array(range(grid_size.x, fine_high.x + 1)))
			else:
				row.append_array(PackedInt32Array(range(fine_low.x, fine_high.x + 1)))
			if coarse_row:
				row.append_array(PackedInt32Array(range(fine_high.x + TERRAIN_COARSE, high.x + 1, TERRAIN_COARSE)))
		elif not coarse_row:
			continue
		var z := j - half.y
		for i: int in row:
			var place := (j - low.y) * columns + i - low.x
			var x := i - half.x
			var y := terrain_height(x, z)
			ids[place] = vertices.size()
			heights[place] = y
			places.append(place)
			vertices.append(Vector3(x, y, z))

	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var colors := PackedColorArray()
	# Only points in here can be on a mesa's wall.
	var mesa_area := Rect2()
	for k: int in mesas.size():
		var around := Rect2(mesas[k].x, mesas[k].y, 0.0, 0.0).grow(mesas[k].z + 3.0)
		mesa_area = around if k == 0 else mesa_area.merge(around)
	for v: int in vertices.size():
		var place := places[v]
		var column := place % columns
		var row := place / columns
		var step := 1
		if column < fine_low.x - low.x or column > fine_high.x - low.x \
				or row < fine_low.y - low.y or row > fine_high.y - low.y:
			step = TERRAIN_COARSE
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
			along_x = (heights[east] - heights[west]) / (east - west)
		if south != north:
			along_z = (heights[south] - heights[north]) / ((south - north) / columns)
		var normal := Vector3(-along_x, 1.0, -along_z).normalized()
		normals.append(normal)
		var at := vertices[v]
		uvs.append(Vector2(at.x, at.z) * TERRAIN_UV)
		# Each weight steps smoothly from 0 to 1 across its threshold. A slope is steeper than a
		# threshold where its normal's y is below it.
		var steep := smoothstep(ROCK_SLOPE_Y + 0.1, ROCK_SLOPE_Y - 0.1, normal.y)
		var tint := MaterialKit.ROCK
		if steep < 1.0:
			var facing := normal.x * SUN_ACROSS.x + normal.z * SUN_ACROSS.y
			var shadow_side := smoothstep(SHADOW_SLOPE_Y + 0.03, SHADOW_SLOPE_Y - 0.03, normal.y) \
				* smoothstep(-0.05, -0.15, facing)
			var lit_side := smoothstep(LIT_SLOPE_Y + 0.03, LIT_SLOPE_Y - 0.03, normal.y) * smoothstep(0.1, 0.2, facing)
			# The craters all lie inside the fine lattice.
			var floor_weight := 0.0
			if step == 1:
				floor_weight = _crater_floor(at.x, at.z)
			var drift := smoothstep(DRIFT - PAINT_SOFTNESS, DRIFT + PAINT_SOFTNESS,
				_noise_at(at.x * 1.9 + 71.0, at.z * 1.9 + 23.0))
			tint = MaterialKit.TERRAIN.lerp(MaterialKit.TERRAIN_LIGHT, maxf(lit_side, drift)) \
				.lerp(MaterialKit.TERRAIN_DARK, maxf(shadow_side, floor_weight)) \
				.lerp(MaterialKit.ROCK, steep)
		var layer := MaterialKit.Layer.REGOLITH
		if mesa_area.has_point(Vector2(at.x, at.z)) and _on_mesa_wall(at.x, at.z):
			layer = MaterialKit.Layer.ROCK
		uv2s.append(Vector2(layer, Surf.LIT))
		colors.append(tint)

	# The cells' triangles, going round as (i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1), which
	# faces up; the diagonals alternate, so the faces do not all lean one way.
	var indices := PackedInt32Array()
	for j: int in range(fine_low.y, fine_high.y):
		for i: int in range(fine_low.x, fine_high.x):
			if i >= 0 and i < grid_size.x and j >= 0 and j < grid_size.y:
				continue
			var place := (j - low.y) * columns + i - low.x
			var a := ids[place]
			var b := ids[place + 1]
			var c := ids[place + columns + 1]
			var d := ids[place + columns]
			indices.append(a)
			indices.append(b)
			if (i + j) % 2 == 0:
				indices.append(c)
				indices.append(a)
			else:
				indices.append(d)
				indices.append(b)
			indices.append(c)
			indices.append(d)
	var span := TERRAIN_COARSE
	for j: int in range(low.y, high.y, span):
		for i: int in range(low.x, high.x, span):
			if i >= fine_low.x and i < fine_high.x and j >= fine_low.y and j < fine_high.y:
				continue
			var place := (j - low.y) * columns + i - low.x
			var corners := PackedInt32Array([ids[place], ids[place + span], ids[place + span * columns + span],
				ids[place + span * columns]])
			# The fine point in the middle of an edge the cell shares with the fine lattice, if any.
			var middles := PackedInt32Array([ids[place + 1], ids[place + columns + span],
				ids[place + span * columns + 1], ids[place + columns]])
			var fan := -1
			for k: int in 4:
				if middles[k] >= 0:
					fan = k
			if fan >= 0:
				var m := middles[fan]
				for k: int in range(1, 4):
					indices.append_array(PackedInt32Array([m, corners[(fan + k) % 4], corners[(fan + k + 1) % 4]]))
			elif ((i - low.x) / span + (j - low.y) / span) % 2 == 0:
				indices.append_array(PackedInt32Array([corners[0], corners[1], corners[2],
					corners[0], corners[2], corners[3]]))
			else:
				indices.append_array(PackedInt32Array([corners[0], corners[1], corners[3],
					corners[1], corners[2], corners[3]]))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var hull := ArrayMesh.new()
	hull.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	hull.surface_set_material(0, MaterialKit.ink())
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_COLOR] = colors
	var body := ArrayMesh.new()
	body.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	body.surface_set_material(0, MaterialKit.toon())
	terrain = _add_mesh(body, false)
	terrain_outline = _add_mesh(hull, false)


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
			var clear := _clear(at, radius) and _off_channel(at, radius)
			for spot: Vector3 in taken:
				clear = clear and at.distance_to(Vector2(spot.x, spot.y)) > spot.z + radius + 0.2
			# No part of an outcrop reaches 3 from its centre.
			for spot: Vector3 in outcrop_spots:
				clear = clear and at.distance_to(Vector2(spot.x, spot.z)) > radius + 3.0
			if clear:
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
## rims, the channel, and the mesas' flat tops, all blended in by a wandering distance out
## (blend_end), with rubble over it all. The harness marches the view's rays over it.
func terrain_height(x: float, z: float) -> float:
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
	for k: int in mesas.size():
		var mesa := mesas[k]
		var dx := x - mesa.x
		var dz := z - mesa.y
		if dx * dx + dz * dz < (mesa.z + 3.0) * (mesa.z + 3.0):
			var edge := _mesa_edge(k, dx, dz)
			var top := 1.0 - smoothstep(edge - MESA_WALL, edge + MESA_FOOT, sqrt(dx * dx + dz * dz))
			height = lerpf(height, mesa.w, top)
	return height * smoothstep(TERRAIN_FLAT, full_out, out) + rubble


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


## Whether a point is on a mesa's wall: below its rim's edge and out to a unit past its foot,
## where the rock layer meets the dust on level ground.
func _on_mesa_wall(x: float, z: float) -> bool:
	for k: int in mesas.size():
		var dx := x - mesas[k].x
		var dz := z - mesas[k].y
		if dx * dx + dz * dz < (mesas[k].z + 3.0) * (mesas[k].z + 3.0):
			var edge := _mesa_edge(k, dx, dz)
			var distance := sqrt(dx * dx + dz * dz)
			return distance > edge - MESA_WALL and distance < edge + MESA_FOOT + 1.0
	return false


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
