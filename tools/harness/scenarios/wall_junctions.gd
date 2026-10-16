extends HarnessScenario
## Walls that connect. A fresh base is grown to Command Center 5, then walls are painted in a
## straight run, a corner, a T, a cross, a ramp (a run whose walls end at levels 1 to 5) and a
## two-level L and T (arms that stop at level 1, 2 or 3, STEP_CAPS), and upgraded together to
## level 3, then 5. At each level the pattern is screenshotted at the closest zoom and the
## merged wall mesh is checked: the mask of a named cell in each shape, every wall's mask
## against the rule (four-connected, any levels), its triangles against the sum of its pieces',
## and its outline's triangles against the sum of its pieces' outlines, each piece outlining
## its steps down to neighbours whose solid segment is lower (WallModels.solid_top: by height,
## so an L5's low slab is lower than an L1 segment). STEPS names the walls that must, or must
## not, show a step's extra ink triangles at levels 3 and 5, an L5 beside an L3 among them. A
## wall's own model, which the brush and the gallery show, is the lone post, every piece of
## every level is within PIECE_TRIANGLES for its level's tier, and every piece's body is the
## same whatever its lower mask.
## Last, the cross's centre is selected, which leaves it merged with no gold outline, then
## lifted: it leaves the mesh and its neighbours' masks, shows its own post, and rejoins when
## dropped back.

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
## The two-level shapes' arms that stop below the rest, by cell: their level at most.
const STEP_CAPS: Dictionary[Vector2i, int] = {
	Vector2i(7, 4): 1, Vector2i(8, 5): 3, Vector2i(6, 7): 1, Vector2i(8, 7): 2,
}
## The two-level L's corner and T's centre.
const STEP_CORNERS: Array[Vector2i] = [Vector2i(8, 4), Vector2i(7, 7)]
## [stage, cell, whether its piece inks a step]. At level 3 the L's corner and the T's centre
## (L3) stand over their L1 and L2 arms. At level 5 the L's corner is an L5, whose solid slab is
## lower than both its arms: its L3 and L1 arms step down to it, and it inks nothing.
const STEPS: Array[Array] = [
	[3, Vector2i(8, 4), true], [3, Vector2i(7, 7), true],
	[5, Vector2i(8, 5), true], [5, Vector2i(7, 4), true], [5, Vector2i(8, 4), false],
]
const CLOSE_UP_SIZE := 10.0

var _catalog: Catalog
## The art style's budget for one wall piece's body, by Parts.Tier (Base, Gold, Chrome,
## Obsidian, Crown).
const PIECE_TRIANGLES := [250, 250, 300, 350, 400]


func run(main: MainScript) -> void:
	var state: BaseState = main.state
	var placement: PlacementController = main.placement
	_catalog = state.catalog
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
		var model := BuildingModels.create(WALL, level, 1, _tier(level))
		var own: PackedVector3Array = _first_mesh(model).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var post: PackedVector3Array = _piece(level, 0).body[Mesh.ARRAY_VERTEX]
		check(own == post, "a level %d wall's own model is the lone post" % level)
		model.free()
		var most := 0
		var differs := PackedStringArray()
		for mask: int in 16:
			most = maxi(most, _piece_triangles(level, mask))
			var plain: Array = _piece(level, mask).body
			for lower: int in range(1, 16):
				if lower & mask == lower and _piece(level, mask, lower).body != plain:
					differs.append("%d/%d" % [mask, lower])
		check(differs.is_empty(), "level %d pieces' bodies are the same whatever the lower mask (%s)" % [
			level, ", ".join(differs)])
		var limit: int = PIECE_TRIANGLES[_tier(level)]
		check(most <= limit, "level %d pieces have at most %d triangles (limit %d)" % [level, most, limit])

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
		_check_steps(main, stage)
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
		["two-level L", _cells([[7, 4], [8, 4], [8, 5]]), STEP_CORNERS[0], WallModels.MINUS_X | WallModels.PLUS_Z],
		["two-level T", _cells([[6, 7], [7, 7], [8, 7], [7, 8]]), STEP_CORNERS[1],
			WallModels.PLUS_X | WallModels.MINUS_X | WallModels.PLUS_Z],
	]


func _cells(pairs: Array) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for pair: Array in pairs:
		cells.append(Vector2i(pair[0], pair[1]))
	return cells


## Upgrades every wall to `stage`, but the ramp's (its walls stop at levels 1, 2, 3, ...) and the
## two-level shapes' arms (STEP_CAPS).
func _upgrade(main: MainScript, stage: int) -> void:
	var state: BaseState = main.state
	for id: int in state.buildings:
		var building: BuildingState = state.buildings[id]
		if building.type != WALL:
			continue
		var target := stage
		if building.cell.y == ORIGIN.y + RAMP_ROW:
			target = mini(building.cell.x - ORIGIN.x + 1, stage)
		var cap: int = STEP_CAPS.get(building.cell - ORIGIN, stage)
		target = mini(target, cap)
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
	var expected_ink := 0
	for cell: Vector2i in levels:
		var mask := _rule(levels, cell)
		if walls.mask_at(cell) != mask:
			wrong.append("%s: %d, not %d" % [cell, walls.mask_at(cell), mask])
		expected += _piece_triangles(levels[cell], mask)
		expected_ink += _outline_triangles(levels[cell], mask, _lower_rule(levels, cell))
	check(wrong.is_empty(), "%s: every wall's mask follows the rule (%s)" % [label, ", ".join(wrong)])
	var drawn := _triangles(walls.body.mesh)
	check(drawn == expected, "%s: the merged mesh has its %d pieces' triangles (%d, expected %d)" % [
		label, levels.size(), drawn, expected])
	var inked := _triangles(walls.outline.mesh)
	check(inked == expected_ink, "%s: the merged outline has its pieces' outlines, steps inked (%d, expected %d)" % [
		label, inked, expected_ink])
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


## The STEPS of `stage`: a wall that steps down to a lower neighbour has its piece's outline
## gain the steps' caps, more triangles than the same piece with none; one that does not, none.
func _check_steps(main: MainScript, stage: int) -> void:
	var levels: Dictionary[Vector2i, int] = {}
	for id: int in main.state.buildings:
		var building: BuildingState = main.state.buildings[id]
		if building.type == WALL and building.level >= 1:
			levels[building.cell] = building.level
	for step: Array in STEPS:
		if step[0] != stage:
			continue
		var cell: Vector2i = ORIGIN + (step[1] as Vector2i)
		var inks: bool = step[2]
		var mask := _rule(levels, cell)
		var lower := _lower_rule(levels, cell)
		var plain := _outline_triangles(levels[cell], mask, 0)
		var stepped := _outline_triangles(levels[cell], mask, lower)
		var shown := (lower != 0 and stepped > plain) if inks else (lower == 0 and stepped == plain)
		check(shown, "level %d: the L%d wall at %s %s (lower mask %d, %d ink triangles, %d without)" % [
			stage, levels[cell], cell, "steps down and inks it" if inks else "inks no step", lower, stepped, plain])


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


## Four-connected neighbours that are walls whose solid segment is lower, as WallModels' bits.
static func _lower_rule(levels: Dictionary[Vector2i, int], cell: Vector2i) -> int:
	var mask := 0
	for bit: int in WallModels.NEIGHBOURS.size():
		var neighbour := cell + WallModels.NEIGHBOURS[bit]
		if levels.has(neighbour) and WallModels.solid_top(levels[neighbour]) < WallModels.solid_top(
				levels[cell]):
			mask |= 1 << bit
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


## A level's Tier, as the game builds its walls for it.
func _tier(level: int) -> int:
	return BuildingModels.tier_of(_catalog, WALL, level)


## The piece of `level`, built for its tier, and the masks.
func _piece(level: int, mask: int, lower_mask: int = 0) -> WallModels.Piece:
	return WallModels.piece(level, _tier(level), mask, lower_mask)


func _piece_triangles(level: int, mask: int) -> int:
	var vertices: PackedVector3Array = _piece(level, mask).body[Mesh.ARRAY_VERTEX]
	return vertices.size() / 3


func _outline_triangles(level: int, mask: int, lower_mask: int) -> int:
	var outline := _piece(level, mask, lower_mask).outline
	if outline.is_empty():
		return 0
	var vertices: PackedVector3Array = outline[Mesh.ARRAY_VERTEX]
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
