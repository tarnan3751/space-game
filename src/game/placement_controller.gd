class_name PlacementController
extends Node
## Interprets gestures on the base: camera pan/zoom, selecting buildings, placing new
## ones (ghost + confirm, like Clash), and dragging the selected building to move it.
## This is the only game-layer code that calls BaseState.apply().

signal selection_changed
## Placement started, ended, or the ghost moved.
signal placing_changed
signal command_failed(error: String)

enum Drag { NONE, CAMERA, GHOST, BUILDING }

var state: BaseState
var base_view: BaseView
var camera: IsoCamera
## Returns the current unix time in seconds. Injected so a server clock can replace it.
var clock: Callable

var selected_id: int = 0
var placing_type: String = ""

var _ghost: BuildingView
var _ghost_cell: Vector2i = Vector2i.ZERO
var _drag: Drag = Drag.NONE
var _drag_id: int = 0
var _drag_cell: Vector2i = Vector2i.ZERO
var _grab_offset: Vector2i = Vector2i.ZERO


func connect_input(input: WorldInput) -> void:
	input.tapped.connect(_on_tapped)
	input.drag_started.connect(_on_drag_started)
	input.dragged.connect(_on_dragged)
	input.drag_ended.connect(_on_drag_ended)
	input.pinched.connect(_on_pinched)
	input.panned.connect(_on_panned)


func is_placing() -> bool:
	return placing_type != ""


func ghost_is_valid() -> bool:
	return is_placing() and state.check_place(placing_type, _ghost_cell) == ""


# --- Placing ---------------------------------------------------------------------

func begin_place(type: String) -> void:
	cancel_place()
	select(0)
	placing_type = type
	var size := state.catalog.size_of(type)
	_ghost = BuildingView.new()
	_ghost.setup(0, type, 1, size)
	_ghost.set_lifted(true)
	base_view.add_child(_ghost)
	base_view.set_grid_highlight(true)
	var start := Vector2i(state.grid.width / 2, state.grid.height / 2)
	var centre: Variant = camera.ground_point(camera.get_viewport().get_visible_rect().size * 0.5)
	if typeof(centre) == TYPE_VECTOR3:
		start = base_view.footprint_cell_at(centre, size)
	_set_ghost_cell(_find_free_cell(start, size))


func confirm_place() -> void:
	if not is_placing():
		return
	var command := {"op": "place", "type": placing_type, "cell": [_ghost_cell.x, _ghost_cell.y]}
	var error := state.apply(command, clock.call())
	if error != "":
		command_failed.emit(error)
		return
	var new_id := state.last_added_id
	cancel_place()
	select(new_id)


func cancel_place() -> void:
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	if placing_type != "":
		placing_type = ""
		base_view.set_grid_highlight(false)
		placing_changed.emit()


## Re-checks the ghost after the state changed (resources, builders).
func refresh() -> void:
	if is_placing():
		_set_ghost_cell(_ghost_cell)


# --- Selection and upgrades ------------------------------------------------------

func select(id: int) -> void:
	if id == selected_id:
		return
	selected_id = id
	base_view.selected_id = id
	base_view.sync(state)
	selection_changed.emit()


func upgrade_selected() -> void:
	if selected_id == 0:
		return
	var error := state.apply({"op": "upgrade", "id": selected_id}, clock.call())
	if error != "":
		command_failed.emit(error)


# --- Gestures --------------------------------------------------------------------

func _on_tapped(screen_pos: Vector2) -> void:
	var hit: Variant = _cell_at(screen_pos)
	if typeof(hit) != TYPE_VECTOR2I:
		return
	var cell: Vector2i = hit
	if is_placing():
		var half := _ghost.footprint_size / 2
		_set_ghost_cell(cell - Vector2i(half, half))
		return
	var building := state.building_at(cell)
	select(building.id if building != null else 0)


func _on_drag_started(screen_pos: Vector2) -> void:
	_drag = Drag.CAMERA
	var hit: Variant = _cell_at(screen_pos)
	if typeof(hit) != TYPE_VECTOR2I:
		return
	var cell: Vector2i = hit
	if is_placing():
		if _in_footprint(cell, _ghost_cell, _ghost.footprint_size):
			_drag = Drag.GHOST
			_grab_offset = _ghost_cell - cell
		return
	# Like Clash: only the selected building can be dragged; anything else pans.
	var building := state.building_at(cell)
	if building != null and building.id == selected_id:
		_drag = Drag.BUILDING
		_drag_id = building.id
		_drag_cell = building.cell
		_grab_offset = building.cell - cell
		base_view.dragging_id = building.id


func _on_dragged(screen_pos: Vector2, screen_delta: Vector2) -> void:
	if _drag == Drag.CAMERA:
		camera.pan(screen_pos, screen_delta)
		return
	var hit: Variant = _cell_at(screen_pos)
	if typeof(hit) != TYPE_VECTOR2I:
		return
	var cell: Vector2i = hit
	if _drag == Drag.GHOST:
		_set_ghost_cell(cell + _grab_offset)
	elif _drag == Drag.BUILDING and base_view.views.has(_drag_id):
		var view: BuildingView = base_view.views[_drag_id]
		_drag_cell = _clamp_cell(cell + _grab_offset, view.footprint_size)
		view.position = base_view.cell_to_world(_drag_cell, view.footprint_size)
		view.set_lifted(true)
		var ok := state.check_move(_drag_id, _drag_cell) == ""
		view.set_footprint(BuildingView.Footprint.VALID if ok else BuildingView.Footprint.INVALID)


func _on_drag_ended(_screen_pos: Vector2) -> void:
	if _drag == Drag.BUILDING:
		base_view.dragging_id = 0
		var building: BuildingState = state.buildings.get(_drag_id)
		if building != null and building.cell != _drag_cell:
			var command := {"op": "move", "id": _drag_id, "cell": [_drag_cell.x, _drag_cell.y]}
			var error := state.apply(command, clock.call())
			if error != "":
				command_failed.emit(error)
		base_view.sync(state)
	_drag = Drag.NONE


func _on_pinched(factor: float, screen_pos: Vector2) -> void:
	camera.zoom_at(factor, screen_pos)


func _on_panned(screen_pos: Vector2, screen_delta: Vector2) -> void:
	camera.pan(screen_pos, screen_delta)


# --- Helpers ---------------------------------------------------------------------

func _set_ghost_cell(cell: Vector2i) -> void:
	_ghost_cell = _clamp_cell(cell, _ghost.footprint_size)
	_ghost.position = base_view.cell_to_world(_ghost_cell, _ghost.footprint_size)
	var ok := state.check_place(placing_type, _ghost_cell) == ""
	_ghost.set_footprint(BuildingView.Footprint.VALID if ok else BuildingView.Footprint.INVALID)
	placing_changed.emit()


func _cell_at(screen_pos: Vector2) -> Variant:
	var point: Variant = camera.ground_point(screen_pos)
	if typeof(point) != TYPE_VECTOR3:
		return null
	return base_view.world_to_cell(point)


func _clamp_cell(cell: Vector2i, size: int) -> Vector2i:
	return cell.clamp(Vector2i.ZERO, Vector2i(state.grid.width - size, state.grid.height - size))


static func _in_footprint(cell: Vector2i, origin: Vector2i, size: int) -> bool:
	return cell.x >= origin.x and cell.y >= origin.y \
		and cell.x < origin.x + size and cell.y < origin.y + size


## Nearest free spot to `around`, searching outward in square rings.
func _find_free_cell(around: Vector2i, size: int) -> Vector2i:
	var limit := maxi(state.grid.width, state.grid.height)
	for radius: int in limit:
		for dy: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var cell := around + Vector2i(dx, dy)
				if state.grid.is_free(cell, size):
					return cell
	return around
