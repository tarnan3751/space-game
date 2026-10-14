class_name BaseView
extends Node3D
## Draws the base: ground, grid, scenery and one BuildingView per building.
## Also owns the cell <-> world mapping: 1 cell = 1 world unit, grid centred on the origin,
## cell (x, y) maps to world (x, z).

const GROUND_SHADER := preload("res://src/game/ground.gdshader")
const SCENERY_SEED := 7

var grid_size: Vector2i = Vector2i.ZERO
var views: Dictionary[int, BuildingView] = {}
## Building drawn with a selection tile.
var selected_id: int = 0
## Building currently being dragged; sync() leaves its position alone.
var dragging_id: int = 0


func setup(size: Vector2i) -> void:
	grid_size = size
	_build_ground()
	_build_scenery()


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


func clear() -> void:
	for view: BuildingView in views.values():
		view.queue_free()
	views.clear()
	selected_id = 0
	dragging_id = 0


func _build_ground() -> void:
	var material := ShaderMaterial.new()
	material.shader = GROUND_SHADER
	material.set_shader_parameter("grid_size", Vector2(grid_size))
	var plane := PlaneMesh.new()
	plane.size = Vector2(grid_size)
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	ground.material_override = material
	add_child(ground)

	var outer_plane := PlaneMesh.new()
	outer_plane.size = Vector2(grid_size) * 4.0
	var outer := MeshInstance3D.new()
	outer.mesh = outer_plane
	outer.position = Vector3(0, -0.02, 0)
	outer.material_override = BuildingModels.material(Color("1b1828"))
	add_child(outer)


## Rocks around the buildable area. Seeded, so every player's base looks the same.
func _build_scenery() -> void:
	var rng := SeededRng.new(SCENERY_SEED)
	var rock_material := BuildingModels.material(Color("2c283d"))
	var half := maxi(grid_size.x, grid_size.y) * 0.5
	var placed := 0
	while placed < 60:
		var angle := TAU * rng.range_int(0, 3599) / 3600.0
		var distance := half + 2.0 + rng.range_int(0, 1800) / 100.0
		var radius := 0.4 + rng.range_int(0, 160) / 100.0
		var x := cos(angle) * distance
		var z := sin(angle) * distance
		# The grid is square, so a ring around it still overlaps the corners.
		if absf(x) < half + radius and absf(z) < half + radius:
			continue
		placed += 1
		var mesh := SphereMesh.new()
		mesh.radius = radius
		mesh.height = radius * 1.2
		mesh.radial_segments = 6
		mesh.rings = 3
		var rock := MeshInstance3D.new()
		rock.mesh = mesh
		rock.material_override = rock_material
		rock.position = Vector3(x, 0.0, z)
		rock.rotation_degrees = Vector3(0, rng.range_int(0, 359), 0)
		add_child(rock)
