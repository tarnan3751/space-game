class_name PlacementController
extends Node
## Interprets gestures on the base: camera pan/zoom, selecting buildings, placing new
## ones (ghost + confirm, like Clash), and dragging the selected building to move it.
## Walls are painted instead: until Done, a tap places one, and a drag one on every free
## cell the finger crosses. The ground's cell grid shows only during these (_show_grid).
## This is the only game-layer code that calls BaseState.apply().
##
## While the ghost, a building or the wall brush is dragged with the finger near the
## screen's edge, the camera scrolls toward that edge and the dragged thing keeps following
## the finger. Drag positions arrive only as events, so the scroll runs in _process, on
## only for such drags.

signal selection_changed
## Placement started, ended, or the ghost moved.
signal placing_changed
signal command_failed(error: String)

enum Drag { NONE, CAMERA, GHOST, BUILDING, PAINT }

## The type painted rather than placed one at a time, with the ghost and Place: the wall,
## one cell by data.
const PAINT_TYPE := "barrier_wall"

## The edge margin, as a fraction of the viewport's shorter side.
const EDGE_MARGIN := 0.08
## The scroll speed at the very edge, in viewport widths per second; it falls off linearly
## to nothing at the margin's inner side. One viewport width is the visible world width.
const EDGE_SCROLL_SPEED := 0.6

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
var _painting: bool = false
## The last cell a paint stroke reached; the next one is walked to from here.
var _paint_cell: Vector2i = Vector2i.ZERO
## A failure other than a taken cell has been shown during this stroke.
var _paint_failed: bool = false
## The finger of a ghost, building or paint drag, and the cell under it when the drag was
## last followed; the edge scroll follows the drag again only when that cell changes.
var _finger: Vector2 = Vector2.ZERO
var _finger_cell: Vector2i = Vector2i.ZERO


func _ready() -> void:
	set_process(false)


func connect_input(input: WorldInput) -> void:
	input.tapped.connect(_on_tapped)
	input.drag_started.connect(_on_drag_started)
	input.dragged.connect(_on_dragged)
	input.drag_ended.connect(_on_drag_ended)
	input.pinched.connect(_on_pinched)
	input.panned.connect(_on_panned)


func is_placing() -> bool:
	return placing_type != ""


## Whether the ghost's footprint shows VALID. While painting, whether another wall can be
## built at all: the cell under the brush is usually the wall it just placed.
func ghost_is_valid() -> bool:
	if not is_placing():
		return false
	if _painting:
		return state.check_can_build(placing_type) == ""
	return state.check_place(placing_type, _ghost_cell) == ""


## Placing walls: the ghost is a brush and there is nothing to confirm.
func is_painting() -> bool:
	return _painting


## The ghost's top-left cell (the brush's while painting); meaningful only while placing.
func ghost_cell() -> Vector2i:
	return _ghost_cell


# --- Placing ---------------------------------------------------------------------

func begin_place(type: String) -> void:
	cancel_place()
	select(0)
	placing_type = type
	var size := state.catalog.size_of(type)
	_painting = type == PAINT_TYPE
	_ghost = BuildingView.new()
	_ghost.setup(0, type, 1, size, BuildingModels.tier_of(state.catalog, type, 1))
	_ghost.set_lifted(true)
	base_view.add_child(_ghost)
	_show_grid()
	var start := Vector2i(state.grid.width / 2, state.grid.height / 2)
	var centre: Variant = camera.ground_point(camera.get_viewport().get_visible_rect().size * 0.5)
	if typeof(centre) == TYPE_VECTOR3:
		start = base_view.footprint_cell_at(centre, size)
	_set_ghost_cell(_find_free_cell(start, size))


## Places the ghost's building and selects it; while painting, only ends the mode (Done).
func confirm_place() -> void:
	if not is_placing():
		return
	if _painting:
		cancel_place()
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
	# A ghost or paint drag in progress ends with it: a second finger can press Cancel.
	if _drag == Drag.GHOST or _drag == Drag.PAINT:
		_set_drag(Drag.NONE)
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	if placing_type != "":
		placing_type = ""
		_painting = false
		_show_grid()
		placing_changed.emit()


## Re-checks the ghost after the state changed (resources, builders).
func refresh() -> void:
	if is_placing():
		_set_ghost_cell(_ghost_cell)


# --- Painting --------------------------------------------------------------------

## A tap, or the start of a paint drag: a wall on `cell`, and the brush moves there.
func _begin_stroke(cell: Vector2i) -> void:
	_paint_failed = false
	_paint_cell = cell
	_paint(cell)
	_set_ghost_cell(cell)


## Paints every cell from the last one the stroke reached to `cell`, one orthogonal step at
## a time along the straight line between them, so a fast stroke leaves no gap and a
## diagonal one becomes a staircase of walls that touch.
func _paint_to(cell: Vector2i) -> void:
	if cell == _paint_cell:
		return
	var span := (cell - _paint_cell).abs()
	var step := (cell - _paint_cell).sign()
	var taken := Vector2i.ZERO
	while _paint_cell != cell:
		# Step along whichever axis the line crosses a cell edge on first.
		if (1 + 2 * taken.x) * span.y < (1 + 2 * taken.y) * span.x:
			_paint_cell.x += step.x
			taken.x += 1
		else:
			_paint_cell.y += step.y
			taken.y += 1
		_paint(_paint_cell)
	_set_ghost_cell(cell)


## One cell of a stroke. A taken cell is skipped quietly; any other failure (resources,
## the count limit) is shown once a stroke, and the next stroke tries again.
func _paint(cell: Vector2i) -> void:
	var command := {"op": "place", "type": placing_type, "cell": [cell.x, cell.y]}
	var error := state.apply(command, clock.call())
	if error == "" or error == BaseState.ERR_BLOCKED or _paint_failed:
		return
	_paint_failed = true
	command_failed.emit(error)


# --- Selection and upgrades ------------------------------------------------------

func select(id: int) -> void:
	if id == selected_id:
		return
	# A building drag ends with its selection (a second finger can press Close or Reset base),
	# with no move: the finger lifting later must not move whatever building has that id then.
	if _drag == Drag.BUILDING:
		_set_drag(Drag.NONE)
		base_view.dragging_id = 0
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
	if _painting:
		_begin_stroke(cell)
		return
	if is_placing():
		var half := _ghost.footprint_size / 2
		_set_ghost_cell(cell - Vector2i(half, half))
		return
	var building := state.building_at(cell)
	select(building.id if building != null else 0)


func _on_drag_started(screen_pos: Vector2) -> void:
	_set_drag(Drag.CAMERA)
	var hit: Variant = _cell_at(screen_pos)
	if typeof(hit) != TYPE_VECTOR2I:
		return
	var cell: Vector2i = hit
	_finger = screen_pos
	_finger_cell = cell
	# A paint stroke starts on the ground (the grid); one on the terrain around it pans.
	if _painting:
		if state.grid.in_bounds(cell, 1):
			_set_drag(Drag.PAINT)
			_begin_stroke(cell)
		return
	if is_placing():
		if _in_footprint(cell, _ghost_cell, _ghost.footprint_size):
			_set_drag(Drag.GHOST)
			_grab_offset = _ghost_cell - cell
		return
	# Like Clash: only the selected building can be dragged; anything else pans.
	var building := state.building_at(cell)
	if building != null and building.id == selected_id:
		_set_drag(Drag.BUILDING)
		_drag_id = building.id
		_drag_cell = building.cell
		_grab_offset = building.cell - cell
		base_view.dragging_id = building.id
		# A lifted wall leaves the merged wall mesh at once, and its own post shows.
		base_view.sync(state)


func _on_dragged(screen_pos: Vector2, screen_delta: Vector2) -> void:
	if _drag == Drag.CAMERA:
		camera.pan(screen_pos, screen_delta)
		return
	var hit: Variant = _cell_at(screen_pos)
	if typeof(hit) != TYPE_VECTOR2I:
		return
	var cell: Vector2i = hit
	_finger = screen_pos
	_finger_cell = cell
	if _drag == Drag.GHOST:
		_set_ghost_cell(cell + _grab_offset)
	elif _drag == Drag.PAINT:
		_paint_to(cell)
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
	_set_drag(Drag.NONE)


func _on_pinched(factor: float, screen_pos: Vector2) -> void:
	camera.zoom_at(factor, screen_pos)


func _on_panned(screen_pos: Vector2, screen_delta: Vector2) -> void:
	camera.pan(screen_pos, screen_delta)


# --- Edge scroll -----------------------------------------------------------------

## Runs only during a ghost, building or paint drag (_set_drag). With the finger in the
## edge margin, the camera moves toward that edge, faster the deeper the finger is in it;
## once the cell under the finger changes, the drag follows it as a drag event would. A
## frame where that cell stays the same calls nothing in core and allocates nothing.
func _process(delta: float) -> void:
	var screen := get_viewport().get_visible_rect().size
	var margin := minf(screen.x, screen.y) * EDGE_MARGIN
	var push := Vector2(_edge_push(_finger.x, screen.x, margin), _edge_push(_finger.y, screen.y, margin))
	if push == Vector2.ZERO:
		return
	# The scroll is a screen distance; the ground points either end of it give the world
	# offset, so the speed scales with zoom.
	var from: Variant = camera.ground_point(_finger)
	var to: Variant = camera.ground_point(_finger + push * (EDGE_SCROLL_SPEED * screen.x * delta))
	if typeof(from) != TYPE_VECTOR3 or typeof(to) != TYPE_VECTOR3:
		return
	var start: Vector3 = from
	var end: Vector3 = to
	camera.nudge(end - start)
	var hit: Variant = _cell_at(_finger)
	if typeof(hit) == TYPE_VECTOR2I:
		var cell: Vector2i = hit
		if cell != _finger_cell:
			_on_dragged(_finger, Vector2.ZERO)


## How far into the margin at either end of `length` the point `at` is: -1 at the start
## edge, 1 at the end edge, 0 outside the margin.
static func _edge_push(at: float, length: float, margin: float) -> float:
	if at < margin:
		return -minf((margin - at) / margin, 1.0)
	if at > length - margin:
		return minf((at - (length - margin)) / margin, 1.0)
	return 0.0


# --- Helpers ---------------------------------------------------------------------

func _set_drag(drag: Drag) -> void:
	_drag = drag
	set_process(drag == Drag.GHOST or drag == Drag.BUILDING or drag == Drag.PAINT)
	_show_grid()


## The cell grid shows only while building: placing (the ghost or the wall brush) or moving a
## building.
func _show_grid() -> void:
	base_view.set_grid_highlight(is_placing() or _drag == Drag.BUILDING)


func _set_ghost_cell(cell: Vector2i) -> void:
	_ghost_cell = _clamp_cell(cell, _ghost.footprint_size)
	_ghost.position = base_view.cell_to_world(_ghost_cell, _ghost.footprint_size)
	var valid := ghost_is_valid()
	_ghost.set_footprint(BuildingView.Footprint.VALID if valid else BuildingView.Footprint.INVALID)
	_ghost.set_ghost(valid)
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
