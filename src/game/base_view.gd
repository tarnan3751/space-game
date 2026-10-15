class_name BaseView
extends Node3D
## Draws the base: the buildable ground with its cell grid, the terrain and rocks around it,
## and one BuildingView per building, the finished walls drawn together by one WallMesh. Also
## owns the cell <-> world mapping: 1 cell = 1 world unit, grid centred on the origin, cell
## (x, y) maps to world (x, z).
##
## The terrain and the rocks are generated from SCENERY_SEED, so every player's base sits in
## the same landscape. Each is one mesh painted from the material kit (the terrain mostly its
## regolith, the rocks its rock layer); the rocks also have their ink outline.

const GROUND_SHADER := preload("res://src/game/ground.gdshader")
## The field texture the ground is drawn from, imported as an Image (tools/gen_textures.gd).
const FIELD_TEXTURE := "res://assets/textures/field.png"
const SCENERY_SEED := 7
## Strength of the ground's cell lines, normally and while placing.
const GRID_LINES := 0.1
const GRID_LINES_PLACING := 0.45
## The terrain reaches this far from the centre in X and Z, on a lattice of TERRAIN_STEP.
const TERRAIN_EXTENT := 90.0
const TERRAIN_STEP := 2.0
## Spacing of the value-noise lattice behind the terrain's hills.
const NOISE_CELL := 7.0
const NOISE_SIZE := 24
const ROCK_COUNT := 40
## Texture repeats per world unit on the terrain: the dust large (a craterlet about every two
## cells), the rock grain finer.
const TERRAIN_DUST_UV := 0.3
const TERRAIN_ROCK_UV := 0.5

## The terrain's faces by height band, from the crater floors up: flat and not outlined (its
## relief shows in the bands). The ring reads as quiet dust on the regolith layer, with the rock
## layer's grain and cracks only on the two highest bands and in the craters.
static var TERRAIN_CRATER := Surf.make(MaterialKit.Layer.ROCK, MaterialKit.TERRAIN_DARK, TERRAIN_ROCK_UV,
	Surf.LIT, false, false)
static var TERRAIN_LOW := Surf.make(MaterialKit.Layer.REGOLITH, MaterialKit.TERRAIN, TERRAIN_DUST_UV, Surf.LIT,
	false, false)
static var TERRAIN_MID := Surf.make(MaterialKit.Layer.REGOLITH, MaterialKit.TERRAIN.lerp(MaterialKit.ROCK, 0.5),
	TERRAIN_DUST_UV, Surf.LIT, false, false)
static var TERRAIN_HIGH := Surf.make(MaterialKit.Layer.ROCK, MaterialKit.ROCK, TERRAIN_ROCK_UV, Surf.LIT,
	false, false)
static var TERRAIN_PEAK := Surf.make(MaterialKit.Layer.ROCK, MaterialKit.ROCK.darkened(0.15), TERRAIN_ROCK_UV,
	Surf.LIT, false, false)
## The rocks' sides and tops, outlined.
static var ROCK_SIDE := Surf.make(MaterialKit.Layer.ROCK, MaterialKit.ROCK)
static var ROCK_TOP := Surf.make(MaterialKit.Layer.ROCK, MaterialKit.ROCK_LIT)

var grid_size: Vector2i = Vector2i.ZERO
var views: Dictionary[int, BuildingView] = {}
## Building drawn with a selection tile.
var selected_id: int = 0
## Building currently being dragged; sync() leaves its position alone.
var dragging_id: int = 0
## Every finished wall but the dragged one, in one mesh.
var walls: WallMesh

var _ground_material: ShaderMaterial
## The walls `walls` draws, as (x << 32 | y << 16 | level) in id order: unchanged, no rebuild.
var _wall_signature: PackedInt64Array = PackedInt64Array()
## The state the pending wall rebuild reads; null when none is pending.
var _walls_state: BaseState = null
## NOISE_SIZE x NOISE_SIZE heights in [0, 1], wrapping.
var _noise: PackedFloat32Array = PackedFloat32Array()
## Each crater as (x, z, radius, depth).
var _craters: Array[Vector4] = []


func setup(size: Vector2i) -> void:
	grid_size = size
	_build_ground()
	var rng := SeededRng.new(SCENERY_SEED)
	_build_terrain(rng)
	_build_rocks(rng)
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
	_ground_material.set_shader_parameter("fleck_color", MaterialKit.CRYSTAL)
	_ground_material.set_shader_parameter("ink_color", MaterialKit.INK)
	_ground_material.set_shader_parameter("line_strength", GRID_LINES)
	var plane := PlaneMesh.new()
	plane.size = Vector2(grid_size)
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	ground.material_override = _ground_material
	add_child(ground)


## The land around the grid: a flat-shaded annulus from the grid's edge, where it is pinned to
## y = 0 so it meets the ground without a seam, out to TERRAIN_EXTENT, coloured by height.
func _build_terrain(rng: SeededRng) -> void:
	_noise.resize(NOISE_SIZE * NOISE_SIZE)
	for i: int in _noise.size():
		_noise[i] = rng.range_int(0, 1000) / 1000.0
	var half := Vector2(grid_size) * 0.5
	for i: int in rng.range_int(3, 5):
		var angle := TAU * rng.range_int(0, 3599) / 3600.0
		var radius := rng.range_int(40, 80) / 10.0
		var distance := maxf(half.x, half.y) + radius * 1.6 + rng.range_int(40, 250) / 10.0
		_craters.append(Vector4(cos(angle) * distance, sin(angle) * distance, radius,
			rng.range_int(14, 22) / 10.0))

	var xs := _lattice(-half.x, half.x)
	var zs := _lattice(-half.y, half.y)
	var heights := PackedFloat32Array()
	for z: float in zs:
		for x: float in xs:
			heights.append(_terrain_height(x, z))
	var mesh := LowPolyMesh.new()
	for j: int in zs.size() - 1:
		for i: int in xs.size() - 1:
			if xs[i] >= -half.x and xs[i + 1] <= half.x and zs[j] >= -half.y and zs[j + 1] <= half.y:
				continue
			var row := j * xs.size()
			var a := Vector3(xs[i], heights[row + i], zs[j])
			var b := Vector3(xs[i + 1], heights[row + i + 1], zs[j])
			var c := Vector3(xs[i + 1], heights[row + xs.size() + i + 1], zs[j + 1])
			var d := Vector3(xs[i], heights[row + xs.size() + i], zs[j + 1])
			# Alternate the diagonals, so the facets do not all lean one way.
			if (i + j) % 2 == 0:
				_terrain_face(mesh, a, d, c)
				_terrain_face(mesh, a, c, b)
			else:
				_terrain_face(mesh, a, d, b)
				_terrain_face(mesh, b, d, c)
	var terrain := MeshInstance3D.new()
	terrain.mesh = mesh.to_mesh()
	# Its relief shows in the flat shading; its shadows would cost a pass for little.
	terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(terrain)


## Low-poly rocks scattered on the terrain around the grid, all in one mesh.
func _build_rocks(rng: SeededRng) -> void:
	var half := Vector2(grid_size) * 0.5
	var mesh := LowPolyMesh.new()
	var placed := 0
	while placed < ROCK_COUNT:
		var angle := TAU * rng.range_int(0, 3599) / 3600.0
		var distance := maxf(half.x, half.y) + 2.0 + rng.range_int(0, 2600) / 100.0
		var radius := 0.4 + rng.range_int(0, 140) / 100.0
		var x := cos(angle) * distance
		var z := sin(angle) * distance
		# The grid is square, so a ring around it still overlaps the corners.
		if absf(x) < half.x + radius and absf(z) < half.y + radius:
			continue
		placed += 1
		_rock(mesh, Vector3(x, _terrain_height(x, z) - 0.2 * radius, z), radius, rng)
	var rocks := MeshInstance3D.new()
	rocks.mesh = mesh.to_mesh()
	add_child(rocks)
	var outline := MeshInstance3D.new()
	outline.mesh = mesh.to_outline_mesh()
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(outline)


## One rock: a jittered ring on the ground, a narrower one above it and an off-centre peak.
static func _rock(mesh: LowPolyMesh, pos: Vector3, radius: float, rng: SeededRng) -> void:
	var sides := rng.range_int(5, 7)
	var turn := TAU * rng.range_int(0, 359) / 360.0
	var height := radius * rng.range_int(80, 120) / 100.0
	var lower := PackedVector3Array()
	var upper := PackedVector3Array()
	for j: int in sides:
		var angle := turn + TAU * j / sides
		var r := radius * rng.range_int(75, 110) / 100.0
		lower.append(pos + Vector3(r * cos(angle), 0.0, r * sin(angle)))
		var r_up := r * rng.range_int(55, 75) / 100.0
		var y := height * rng.range_int(45, 70) / 100.0
		upper.append(pos + Vector3(r_up * cos(angle + 0.3), y, r_up * sin(angle + 0.3)))
	var lean := Vector2(rng.range_int(-20, 20), rng.range_int(-20, 20)) * radius / 100.0
	var peak := pos + Vector3(lean.x, height, lean.y)
	for j: int in sides:
		var k := (j + 1) % sides
		mesh.triangle(lower[j], upper[j], upper[k], ROCK_SIDE)
		mesh.triangle(lower[j], upper[k], lower[k], ROCK_SIDE)
		mesh.triangle(upper[j], peak, upper[k], ROCK_TOP)


## Heights: 0 at the grid's edge, rising gently with distance, with value-noise hills and
## the craters.
func _terrain_height(x: float, z: float) -> float:
	var half := Vector2(grid_size) * 0.5
	var out := Vector2(maxf(absf(x) - half.x, 0.0), maxf(absf(z) - half.y, 0.0)).length()
	var hills := 0.65 * _noise_at(x, z) + 0.35 * _noise_at(x * 2.3 + 37.0, z * 2.3 + 11.0)
	return smoothstep(0.0, 10.0, out) * (hills * 3.2 + out * 0.04 + _crater_dip(x, z))


## How much the craters lower (bowls) or raise (rims) the ground at a point.
func _crater_dip(x: float, z: float) -> float:
	var dip := 0.0
	for crater: Vector4 in _craters:
		var t := Vector2(x - crater.x, z - crater.y).length() / crater.z
		if t < 1.8:
			dip += -crater.w * maxf(1.0 - t * t, 0.0) + crater.w * 0.45 * exp(-pow((t - 1.0) / 0.3, 2.0))
	return dip


## Smoothly interpolated lattice noise in [0, 1].
func _noise_at(x: float, z: float) -> float:
	var gx := x / NOISE_CELL
	var gz := z / NOISE_CELL
	var ix := floori(gx)
	var iz := floori(gz)
	var fx := smoothstep(0.0, 1.0, gx - ix)
	var fz := smoothstep(0.0, 1.0, gz - iz)
	var top := lerpf(_lattice_value(ix, iz), _lattice_value(ix + 1, iz), fx)
	var bottom := lerpf(_lattice_value(ix, iz + 1), _lattice_value(ix + 1, iz + 1), fx)
	return lerpf(top, bottom, fz)


func _lattice_value(ix: int, iz: int) -> float:
	return _noise[posmod(iz, NOISE_SIZE) * NOISE_SIZE + posmod(ix, NOISE_SIZE)]


## One terrain face (corners counter-clockwise from above), painted by its height band.
func _terrain_face(mesh: LowPolyMesh, a: Vector3, b: Vector3, c: Vector3) -> void:
	var centre := (a + b + c) / 3.0
	var surf := TERRAIN_PEAK
	if _crater_dip(centre.x, centre.z) < -0.3:
		surf = TERRAIN_CRATER
	elif centre.y < 0.8:
		surf = TERRAIN_LOW
	elif centre.y < 2.0:
		surf = TERRAIN_MID
	elif centre.y < 3.2:
		surf = TERRAIN_HIGH
	mesh.triangle(a, b, c, surf)


## Lattice coordinates along one axis from -TERRAIN_EXTENT to TERRAIN_EXTENT that include
## both grid edges, `low` and `high`, so the terrain's inner edge lies exactly on them.
static func _lattice(low: float, high: float) -> PackedFloat32Array:
	var axis := PackedFloat32Array()
	for k: int in range(ceili((TERRAIN_EXTENT + low) / TERRAIN_STEP), 0, -1):
		axis.append(low - k * TERRAIN_STEP)
	for k: int in ceili((high - low) / TERRAIN_STEP):
		axis.append(low + k * TERRAIN_STEP)
	for k: int in ceili((TERRAIN_EXTENT - high) / TERRAIN_STEP) + 1:
		axis.append(high + k * TERRAIN_STEP)
	return axis
