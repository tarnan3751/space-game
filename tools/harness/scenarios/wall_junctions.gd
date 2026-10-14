extends HarnessScenario
## Walls that connect. A fresh base is grown to Command Center 5, then walls are painted in a
## straight run, a corner, a T, a cross and a ramp (a run whose walls end at levels 1 to 5),
## and upgraded together to level 3, then 5. At each level the pattern is screenshotted at the
## closest zoom and the merged wall mesh is checked: the mask of a named cell in each shape,
## every wall's mask against the rule (four-connected, any levels), and its triangles against
## the sum of its pieces'. A wall's own model, which the brush and the gallery show, is the
## lone post, and every piece of every level is within PIECE_TRIANGLES. Last, the cross's
## centre is selected, which leaves it merged with no gold outline, then lifted: it leaves the
## mesh and its neighbours' masks, shows its own post, and rejoins when dropped back.

const WALL := "barrier_wall"
const WallModels := preload("res://src/game/models/walls.gd")
## The pattern's top-left cell, clear of a fresh base's Command Center (18-21 x 18-21) and
## drone bay (24-25 x 19-20). Shapes are in cells from it.
const ORIGIN := Vector2i(6, 6)
const CENTRE := Vector2i(4, 4)
const CROSS_CENTRE := Vector2i(5, 5)
## Where the lifted wall is carried: a free cell, clear of the info panel at this zoom.
const LIFT_TO := Vector2i(3, 6)
const RAMP_ROW := 8
const CLOSE_UP_SIZE := 10.0
## The art style's budget for one wall piece's body.
const PIECE_TRIANGLES := 250


func run(main: MainScript) -> void:
	var state: BaseState = main.state
	var placement: PlacementController = main.placement
	var cc_id := 0
	for id: int in state.buildings:
		if state.buildings[id].type == Catalog.HQ_TYPE:
			cc_id = id
	_fund(state)
	for level: int in range(2, 6):
		placement.select(cc_id)
		placement.upgrade_selected()
		advance(state.seconds_left(cc_id) + 1)
		_fund(state)
	check(state.cc_level() == 5, "the Command Center is at level %d" % state.cc_level())
	placement.select(0)
	_frame(main, ORIGIN + CENTRE)

	for level: int in range(1, WallModels.LEVELS + 1):
		var model := BuildingModels.create(WALL, level, 1)
		var own: PackedVector3Array = _first_mesh(model).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var post: PackedVector3Array = WallModels.piece(level, 0).body[Mesh.ARRAY_VERTEX]
		check(own == post, "a level %d wall's own model is the lone post" % level)
		model.free()
		var most := 0
		for mask: int in 16:
			most = maxi(most, _piece_triangles(level, mask))
		check(most <= PIECE_TRIANGLES, "level %d pieces have at most %d triangles (limit %d)" % [
			level, most, PIECE_TRIANGLES])

	placement.begin_place(WALL)
	var cells: Array[Vector2i] = []
	for shape: Array in _shapes():
		cells.append_array(shape[1])
	for cell: Vector2i in cells:
		tap_cell(main, ORIGIN + cell)
	placement.confirm_place()
	check(state.count_of(WALL) == cells.size(), "painted %d walls (%d)" % [cells.size(), state.count_of(WALL)])

	for stage: int in [1, 3, 5]:
		_upgrade(main, stage)
		await frames(2)
		_check_walls(main, "level %d" % stage)
		for shape: Array in _shapes():
			var named: Vector2i = shape[2]
			var expected: int = shape[3]
			var mask: int = main.base_view.walls.mask_at(ORIGIN + named)
			check(mask == expected, "level %d: the %s's mask at %s is %d (%d)" % [
				stage, shape[0], ORIGIN + named, expected, mask])
		if stage == 1:
			# The brush starts on the free cell at the screen centre, beside the cross.
			placement.begin_place(WALL)
			await screenshot("level1-brush")
			placement.cancel_place()
		await screenshot("level%d" % stage)

	await _lift(main)


## [name, cells, the named cell, its mask]. The shapes do not touch one another.
func _shapes() -> Array[Array]:
	var ramp: Array[Vector2i] = []
	for x: int in 5:
		ramp.append(Vector2i(x, RAMP_ROW))
	return [
		["straight run", _cells([[0, 0], [1, 0], [2, 0], [3, 0], [4, 0]]), Vector2i(2, 0),
			WallModels.PLUS_X | WallModels.MINUS_X],
		["corner", _cells([[6, 0], [6, 1], [6, 2], [7, 2], [8, 2]]), Vector2i(6, 2),
			WallModels.PLUS_X | WallModels.MINUS_Z],
		["T", _cells([[0, 2], [1, 2], [2, 2], [1, 3], [1, 4]]), Vector2i(1, 2),
			WallModels.PLUS_X | WallModels.MINUS_X | WallModels.PLUS_Z],
		["cross", _cells([[5, 4], [4, 5], [5, 5], [6, 5], [5, 6]]), CROSS_CENTRE, 15],
		["ramp", ramp, Vector2i(2, RAMP_ROW), WallModels.PLUS_X | WallModels.MINUS_X],
	]


func _cells(pairs: Array) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for pair: Array in pairs:
		cells.append(Vector2i(pair[0], pair[1]))
	return cells


## Upgrades every wall to `stage`, but the ramp's: its walls stop at levels 1, 2, 3, ...
func _upgrade(main: MainScript, stage: int) -> void:
	var state: BaseState = main.state
	for id: int in state.buildings:
		var building: BuildingState = state.buildings[id]
		if building.type != WALL:
			continue
		var target := stage
		if building.cell.y == ORIGIN.y + RAMP_ROW:
			target = mini(building.cell.x - ORIGIN.x + 1, stage)
		while building.level < target:
			var level := building.level
			main.placement.select(id)
			main.placement.upgrade_selected()
			if building.is_busy():
				advance(state.seconds_left(id) + 1)
			if building.level == level:
				check(false, "upgrading the wall at %s failed" % building.cell)
				break
	main.placement.select(0)


## The merged mesh against the rule: every drawn wall's mask, its triangles, and the views.
func _check_walls(main: MainScript, label: String) -> void:
	var state: BaseState = main.state
	var walls: WallMesh = main.base_view.walls
	var levels: Dictionary[Vector2i, int] = {}
	var shown := PackedStringArray()
	for id: int in state.buildings:
		var building: BuildingState = state.buildings[id]
		if building.type == WALL and building.level >= 1 and id != main.base_view.dragging_id:
			levels[building.cell] = building.level
			if main.base_view.views[id].is_model_visible():
				shown.append(str(building.cell))
	check(shown.is_empty(), "%s: the views of the %d walls drawn hide their models (%s)" % [
		label, levels.size(), ", ".join(shown)])
	var wrong := PackedStringArray()
	var expected := 0
	for cell: Vector2i in levels:
		var mask := _rule(levels, cell)
		if walls.mask_at(cell) != mask:
			wrong.append("%s: %d, not %d" % [cell, walls.mask_at(cell), mask])
		expected += _piece_triangles(levels[cell], mask)
	check(wrong.is_empty(), "%s: every wall's mask follows the rule (%s)" % [label, ", ".join(wrong)])
	var drawn := _triangles(walls.body.mesh)
	check(drawn == expected, "%s: the merged mesh has its %d pieces' triangles (%d, expected %d)" % [
		label, levels.size(), drawn, expected])
	check(walls.outline.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		"%s: the outline casts no shadow" % label)


## The cross's centre, selected and dragged away: the mesh drops it and its joints while it is
## in the air, its own post shows, and carried back and dropped it rejoins.
func _lift(main: MainScript) -> void:
	var state: BaseState = main.state
	var walls: WallMesh = main.base_view.walls
	var centre := ORIGIN + CROSS_CENTRE
	var above := centre + Vector2i(0, -1)
	var id := state.building_at(centre).id
	var view: BuildingView = main.base_view.views[id]
	main.placement.select(id)
	await frames(2)
	# Selected, it stays merged: its gold outlines belong to its hidden model.
	check(not view.is_model_visible() and walls.mask_at(centre) == 15,
		"the selected wall stays in the merged mesh, its own gold-outlined model hidden")
	await screenshot("selected")
	var from := _screen_of(main, centre)
	var to := _screen_of(main, ORIGIN + LIFT_TO)
	main.world_input.drag_started.emit(from)
	main.world_input.dragged.emit(to, to - from)
	await frames(2)
	check(walls.mask_at(centre) == -1, "the lifted wall left the merged mesh")
	check(walls.mask_at(above) == 0, "the wall above it lost its joint (%d)" % walls.mask_at(above))
	check(view.is_model_visible(), "the lifted wall shows its own post")
	_check_walls(main, "lifted")
	await screenshot("lifted")
	main.world_input.dragged.emit(from, from - to)
	main.world_input.drag_ended.emit(from)
	await frames(2)
	check(state.buildings[id].cell == centre, "dropped on its own cell, it did not move")
	var rejoined := walls.mask_at(centre) == 15 and walls.mask_at(above) == WallModels.PLUS_Z
	check(rejoined and not view.is_model_visible(),
		"dropped, it rejoins the cross (%d, %d)" % [walls.mask_at(centre), walls.mask_at(above)])
	main.placement.select(0)


## Four-connected neighbours that are walls, as WallModels' bits.
static func _rule(levels: Dictionary[Vector2i, int], cell: Vector2i) -> int:
	var mask := 0
	if levels.has(cell + Vector2i(1, 0)):
		mask |= WallModels.PLUS_X
	if levels.has(cell + Vector2i(-1, 0)):
		mask |= WallModels.MINUS_X
	if levels.has(cell + Vector2i(0, 1)):
		mask |= WallModels.PLUS_Z
	if levels.has(cell + Vector2i(0, -1)):
		mask |= WallModels.MINUS_Z
	return mask


static func _triangles(mesh: Mesh) -> int:
	var array_mesh := mesh as ArrayMesh
	if array_mesh == null:
		return 0
	var count := 0
	for surface: int in array_mesh.get_surface_count():
		var indices := array_mesh.surface_get_array_index_len(surface)
		count += (indices if indices > 0 else array_mesh.surface_get_array_len(surface)) / 3
	return count


static func _piece_triangles(level: int, mask: int) -> int:
	var vertices: PackedVector3Array = WallModels.piece(level, mask).body[Mesh.ARRAY_VERTEX]
	return vertices.size() / 3


static func _first_mesh(model: Node3D) -> Mesh:
	for child: Node in model.get_children():
		if child is MeshInstance3D:
			return (child as MeshInstance3D).mesh
	return null


func _fund(state: BaseState) -> void:
	for res: String in state.catalog.resources:
		state.resources[res] = 1_000_000


func _screen_of(main: MainScript, cell: Vector2i) -> Vector2:
	return main.camera.unproject_position(main.base_view.cell_to_world(cell, 1))


## The closest zoom, centred on `cell`, through the calls a pinch and a drag make.
func _frame(main: MainScript, cell: Vector2i) -> void:
	var centre := main.get_viewport().get_visible_rect().size * 0.5
	main.camera.zoom_at(main.camera.size / CLOSE_UP_SIZE, centre)
	main.camera.pan(centre, centre - _screen_of(main, cell))
