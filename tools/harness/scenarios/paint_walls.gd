extends HarnessScenario
## Painting walls, and the edge scroll. Barrier Wall from the menu enters paint mode: a drag
## along a row places a wall on each cell, drawn as one merged mesh of joined pieces, a tap
## places one, a fast drag across a wall fills the cells it jumped and skips the wall, a drag
## with no metal shows one toast, a drag held at the screen's edge keeps painting as the world
## slides, a drag past the count limit shows one toast, and Done ends the mode with the walls
## kept. Then the ghost of a 3x3 type and the selected building are each held near the right
## edge: the camera scrolls right and each keeps following the finger. Last, a building drag
## that a second finger interrupts by pressing Close, or Reset base, ends there and moves
## nothing. Gestures are WorldInput's signals, as tap_cell sends them.

const WALL := "barrier_wall"
const WallModels := preload("res://src/game/models/walls.gd")
## A fresh base's free cells: the Command Center covers 18-21 x 18-21, the drone bay
## 24-25 x 19-20. Every row here is on screen at the starting zoom and clear of the edges.
const LINE_START := Vector2i(6, 14)
const LINE_LENGTH := 12
const CROSSING_COLUMN := 10
const SPARE_ROW := 24
## How far in from the right edge the finger is held: inside the edge margin.
const EDGE_INSET := 24.0
const HOLD_FRAMES := 30
## Brush holds are shorter, so the walls they paint stay under the count limit.
const BRUSH_HOLD_FRAMES := 20
const CLOSE_UP_SIZE := 10.0

## Every command_failed (every toast) since it was last cleared.
var _failures: PackedStringArray = PackedStringArray()


func run(main: MainScript) -> void:
	var state: BaseState = main.state
	var catalog: Catalog = state.catalog
	var placement: PlacementController = main.placement
	var hud: Hud = main.hud
	placement.command_failed.connect(func(error: String) -> void: _failures.append(error))
	var cost: Dictionary = catalog.level_stats(WALL, 1).get("cost", {})
	var wall_cost := int(cost.get("metal", 0))
	var limit := catalog.max_count(WALL, state.cc_level())
	# Where a fresh base puts the drone bay, for the Reset base check at the end.
	var bay_start := _drone_bay(state).cell

	# The menu entry enters paint mode; the place bar offers Done, enabled whatever the brush is on.
	hud.entry_button(WALL).pressed.emit()
	await frames(2)
	check(placement.is_painting(), "Barrier Wall from the menu enters paint mode")
	check(hud.place_button().text == "Done" and not hud.place_button().disabled,
		"the place bar reads Done (%s, %s)" % [hud.place_button().text,
			"disabled" if hud.place_button().disabled else "enabled"])
	await screenshot("brush")

	# A drag along a row of twelve free cells places a wall on each, at level 1's cost.
	_fill_metal(state)
	var metal_before: int = state.resources["metal"]
	var line := _line(LINE_START, Vector2i(1, 0), LINE_LENGTH)
	_failures.clear()
	await _stroke(main, line)
	check(state.count_of(WALL) == LINE_LENGTH, "the drag placed %d walls" % state.count_of(WALL))
	var on_line := 0
	for cell: Vector2i in line:
		if _is_wall(state, cell):
			on_line += 1
	check(on_line == LINE_LENGTH, "a wall on each of the %d cells (%d)" % [LINE_LENGTH, on_line])
	check(metal_before - state.resources["metal"] == LINE_LENGTH * wall_cost,
		"paid %d metal" % (metal_before - state.resources["metal"]))
	check(_failures.is_empty(), "no toast (%s)" % ", ".join(_failures))
	check(placement.is_painting() and placement.selected_id == 0,
		"still painting, and the new walls are not selected")
	check(placement.ghost_cell() == line[-1], "the brush is at the last cell, %s" % placement.ghost_cell())
	check(placement.ghost_is_valid(), "the brush is VALID on the wall it placed: another can be built")
	_check_merged_line(main)
	await screenshot("painted-line")
	await _close_up(main, line[LINE_LENGTH / 2])

	# A tap places one at once; a tap on a wall places nothing and says nothing.
	var count := state.count_of(WALL)
	tap_cell(main, LINE_START + Vector2i(0, 2))
	check(state.count_of(WALL) == count + 1 and _is_wall(state, LINE_START + Vector2i(0, 2)),
		"a tap placed a wall")
	tap_cell(main, LINE_START)
	check(state.count_of(WALL) == count + 1 and _failures.is_empty(), "a tap on a wall did nothing")

	# A fast drag, one event from two cells above the row to two below: the cells it jumped
	# are filled, and the wall it crossed is skipped.
	count = state.count_of(WALL)
	var crossed := Vector2i(CROSSING_COLUMN, LINE_START.y)
	var crossed_id := state.building_at(crossed).id
	var jump: Array[Vector2i] = [crossed - Vector2i(0, 2), crossed + Vector2i(0, 2)]
	await _stroke(main, jump)
	check(state.count_of(WALL) == count + 4, "the drag across the row placed 4 walls (%d)" % (
		state.count_of(WALL) - count))
	var column_filled := true
	for dy: int in [-2, -1, 1, 2]:
		column_filled = column_filled and _is_wall(state, crossed + Vector2i(0, dy))
	check(column_filled, "the jumped cells were filled")
	check(state.building_at(crossed).id == crossed_id, "the crossed wall was skipped")
	check(_failures.is_empty(), "no toast (%s)" % ", ".join(_failures))

	# With no metal, a drag over several cells places nothing and shows one toast; painting
	# stays on for the next drag. Resources have no command, so they are set directly.
	for res: String in catalog.resources:
		state.resources[res] = 0
	count = state.count_of(WALL)
	_failures.clear()
	await _stroke(main, _line(Vector2i(6, SPARE_ROW), Vector2i(1, 0), 5))
	check(state.count_of(WALL) == count, "no wall placed without metal")
	check(_failures.size() == 1 and _failures[0] == BaseState.ERR_FUNDS,
		"one toast for the drag (%s)" % ", ".join(_failures))
	check(not placement.ghost_is_valid(), "the brush is INVALID with no metal")
	check(placement.is_painting(), "still painting")

	# A drag held at the right edge: the world slides left under the finger, the brush stays
	# under it, and the cells it reaches are painted.
	_fill_metal(state)
	count = state.count_of(WALL)
	_failures.clear()
	var camera: IsoCamera = main.camera
	var screen := main.get_viewport().get_visible_rect().size
	var focus := camera.focus
	_zoom_in(main)
	var margin := minf(screen.x, screen.y) * PlacementController.EDGE_MARGIN
	var press := Vector2(screen.x - margin - 40.0, screen.y * 0.5)
	var finger := Vector2(screen.x - EDGE_INSET, press.y)
	main.world_input.drag_started.emit(press)
	main.world_input.dragged.emit(finger, finger - press)
	var focus_held := camera.focus
	await frames(BRUSH_HOLD_FRAMES)
	_check_scrolled_right(camera, focus_held)
	var under := _cell_under(main, finger)
	check(placement.ghost_cell() == under, "the brush is under the finger (%s, finger on %s)" % [
		placement.ghost_cell(), under])
	check(_is_wall(state, under), "the cell under the finger was painted")
	say("the held drag painted %d walls" % (state.count_of(WALL) - count))
	check(_failures.is_empty(), "no toast (%s)" % ", ".join(_failures))
	main.world_input.drag_ended.emit(finger)
	_reset_camera(main, focus)

	# A fast drag longer than the walls left: it stops at the limit, with one toast.
	var left := limit - state.count_of(WALL)
	_failures.clear()
	var long_line := _line(Vector2i(6, SPARE_ROW), Vector2i(1, 0), left + 3)
	var ends: Array[Vector2i] = [long_line[0], long_line[-1]]
	await _stroke(main, ends)
	check(state.count_of(WALL) == limit, "walls stop at the limit, %d" % state.count_of(WALL))
	var filled := 0
	for i: int in left:
		if _is_wall(state, long_line[i]):
			filled += 1
	check(filled == left, "the first %d cells of the drag hold walls (%d)" % [left, filled])
	check(_failures.size() == 1 and _failures[0] == BaseState.ERR_LIMIT,
		"one toast for the drag (%s)" % ", ".join(_failures))
	await frames(2)
	check(hud.place_button().text == "Done" and not hud.place_button().disabled,
		"Done stays enabled where the brush cannot place")
	await screenshot("done")

	# Done ends the mode and keeps every wall; the place bar goes.
	hud.place_button().pressed.emit()
	await frames(2)
	check(not placement.is_placing() and not placement.is_painting(), "Done ended paint mode")
	check(state.count_of(WALL) == limit, "the walls are kept (%d)" % state.count_of(WALL))
	check(placement.selected_id == 0, "nothing is selected")
	check(not hud.place_button().is_visible_in_tree(), "the place bar is gone")

	# The ghost of a 3x3 type, dragged by its centre and held near the right edge.
	placement.begin_place("metal_extractor")
	await frames(2)
	check(not placement.is_painting() and hud.place_button().text == "Place",
		"a 3x3 type places with a ghost and Place")
	_zoom_in(main)
	# The ghost starts on the free spot nearest the screen centre, so it is still on screen.
	var grab := placement.ghost_cell() + Vector2i.ONE
	press = _screen_of(main, grab)
	finger = Vector2(screen.x - EDGE_INSET, press.y)
	main.world_input.drag_started.emit(press)
	main.world_input.dragged.emit(finger, finger - press)
	focus_held = camera.focus
	await frames(HOLD_FRAMES)
	_check_scrolled_right(camera, focus_held)
	under = _cell_under(main, finger)
	check(placement.ghost_cell() == under - Vector2i.ONE, "the ghost's centre is under the finger (%s, finger on %s)" % [
		placement.ghost_cell() + Vector2i.ONE, under])
	await screenshot("ghost-at-edge")
	main.world_input.drag_ended.emit(finger)
	placement.cancel_place()
	_reset_camera(main, focus)

	# The selected building, dragged and held near the right edge, then dropped.
	var bay_id := 0
	for id: int in state.buildings:
		if state.buildings[id].type == "drone_bay":
			bay_id = id
	var bay: BuildingState = state.buildings[bay_id]
	var bay_size := catalog.size_of("drone_bay")
	placement.select(bay_id)
	_zoom_in(main)
	press = _screen_of(main, bay.cell)
	finger = Vector2(screen.x - EDGE_INSET, press.y)
	main.world_input.drag_started.emit(press)
	main.world_input.dragged.emit(finger, finger - press)
	focus_held = camera.focus
	await frames(HOLD_FRAMES)
	_check_scrolled_right(camera, focus_held)
	under = _cell_under(main, finger)
	var view: BuildingView = main.base_view.views[bay_id]
	check(view.position.is_equal_approx(main.base_view.cell_to_world(under, bay_size)),
		"the drone bay is under the finger (finger on %s)" % under)
	await screenshot("building-at-edge")
	var drop_ok := state.check_move(bay_id, under) == ""
	main.world_input.drag_ended.emit(finger)
	check((bay.cell == under) if drop_ok else (bay.cell != under),
		"the drop %s at %s" % ["moved it" if drop_ok else "was refused", under])

	# A second finger presses Close while the bay is dragged: the drag ends there, with no move
	# when the finger lifts, and the edge scroll stops.
	_reset_camera(main, focus)
	var bay_cell := bay.cell
	var dragging: bool = await _interrupted_drag(main, bay, func() -> void: hud.close_pressed.emit())
	check(not dragging, "Close ended the drag at once")
	check(bay.cell == bay_cell and view.position.is_equal_approx(main.base_view.cell_to_world(bay_cell, bay_size)),
		"the drone bay stayed at %s" % bay.cell)
	# The same through Reset base: the new base's drone bay (with the same id) stays put.
	dragging = await _interrupted_drag(main, bay, func() -> void: hud.reset_pressed.emit())
	check(not dragging, "Reset base ended the drag at once")
	check(_drone_bay(main.state).cell == bay_start,
		"the new base's drone bay stayed at %s" % _drone_bay(main.state).cell)


func _drone_bay(state: BaseState) -> BuildingState:
	for id: int in state.buildings:
		if state.buildings[id].type == "drone_bay":
			return state.buildings[id]
	return null


## Selects `building`, drags it from its cell three cells away, has `interrupt` press a HUD
## button as a second finger would, and lifts the finger. Returns whether the drag was still
## going (the edge scroll still processing) after the press.
func _interrupted_drag(main: MainScript, building: BuildingState, interrupt: Callable) -> bool:
	main.placement.select(building.id)
	var from := _screen_of(main, building.cell)
	var to := _screen_of(main, building.cell + Vector2i(-3, 2))
	main.world_input.drag_started.emit(from)
	main.world_input.dragged.emit(to, to - from)
	await frames(1)
	interrupt.call()
	await frames(1)
	var dragging := main.placement.is_processing()
	main.world_input.drag_ended.emit(to)
	await frames(2)
	return dragging


## The row is one merged mesh: an end piece at each end and the rest joined both ways. The
## outline instance casts no shadow.
func _check_merged_line(main: MainScript) -> void:
	var walls: WallMesh = main.base_view.walls
	var through := WallModels.PLUS_X | WallModels.MINUS_X
	var expected := _piece_triangles(1, WallModels.PLUS_X) + _piece_triangles(1, WallModels.MINUS_X) \
		+ (LINE_LENGTH - 2) * _piece_triangles(1, through)
	var drawn := _triangles(walls.body.mesh)
	check(drawn == expected, "the row is one merged mesh of its %d pieces (%d triangles, expected %d)" % [
		LINE_LENGTH, drawn, expected])
	check(walls.outline.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		"the wall outline casts no shadow")


static func _piece_triangles(level: int, mask: int) -> int:
	var vertices: PackedVector3Array = WallModels.piece(level, mask).body[Mesh.ARRAY_VERTEX]
	return vertices.size() / 3


static func _triangles(mesh: Mesh) -> int:
	var array_mesh := mesh as ArrayMesh
	if array_mesh == null:
		return 0
	var count := 0
	for surface: int in array_mesh.get_surface_count():
		var indices := array_mesh.surface_get_array_index_len(surface)
		count += (indices if indices > 0 else array_mesh.surface_get_array_len(surface)) / 3
	return count


## A screenshot at the closest zoom centred on `cell`; the camera then goes back where it was.
func _close_up(main: MainScript, cell: Vector2i) -> void:
	var camera: IsoCamera = main.camera
	var focus := camera.focus
	var centre := main.get_viewport().get_visible_rect().size * 0.5
	camera.zoom_at(camera.size / CLOSE_UP_SIZE, centre)
	camera.pan(centre, centre - _screen_of(main, cell))
	await screenshot("painted-line-close")
	_reset_camera(main, focus)


## Sets metal to what the base can store.
func _fill_metal(state: BaseState) -> void:
	state.resources["metal"] = state.capacity("metal")


func _is_wall(state: BaseState, cell: Vector2i) -> bool:
	var building := state.building_at(cell)
	return building != null and building.type == WALL


func _line(start: Vector2i, step: Vector2i, length: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for i: int in length:
		cells.append(start + step * i)
	return cells


## A one-finger drag through the centres of `cells`, one event per cell, a frame apart.
func _stroke(main: MainScript, cells: Array[Vector2i]) -> void:
	var at := _screen_of(main, cells[0])
	main.world_input.drag_started.emit(at)
	for i: int in range(1, cells.size()):
		var next := _screen_of(main, cells[i])
		main.world_input.dragged.emit(next, next - at)
		at = next
		await frames(1)
	main.world_input.drag_ended.emit(at)
	await frames(1)


func _screen_of(main: MainScript, cell: Vector2i) -> Vector2:
	return main.camera.unproject_position(main.base_view.cell_to_world(cell, 1))


func _cell_under(main: MainScript, screen_pos: Vector2) -> Vector2i:
	var ground: Vector3 = main.camera.ground_point(screen_pos)
	return main.base_view.world_to_cell(ground)


## The closest zoom, about the screen centre, so the held finger's ground stays on the grid.
func _zoom_in(main: MainScript) -> void:
	var camera: IsoCamera = main.camera
	camera.zoom_at(camera.size / IsoCamera.MIN_ZOOM_SIZE, main.get_viewport().get_visible_rect().size * 0.5)


## Back to the starting zoom and `focus`, so the next gesture's cells are where they were.
func _reset_camera(main: MainScript, focus: Vector3) -> void:
	var camera: IsoCamera = main.camera
	camera.zoom_at(camera.size / IsoCamera.START_ZOOM_SIZE, main.get_viewport().get_visible_rect().size * 0.5)
	camera.nudge(focus - camera.focus)


func _check_scrolled_right(camera: IsoCamera, before: Vector3) -> void:
	var moved := (camera.focus - before).dot(camera.global_transform.basis.x)
	check(moved > 0.0, "the camera scrolled right by %.2f" % moved)
