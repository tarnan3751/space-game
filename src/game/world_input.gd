class_name WorldInput
extends Node
## Turns touch, mouse-wheel and trackpad events that the HUD didn't consume into
## gestures. Uses _unhandled_input, so HUD controls (which stop touches) win.
## Mouse clicks arrive as touches via the emulate_touch_from_mouse project setting,
## so desktop and phone share one code path.

signal tapped(screen_pos: Vector2)
signal drag_started(screen_pos: Vector2)
signal dragged(screen_pos: Vector2, screen_delta: Vector2)
signal drag_ended(screen_pos: Vector2)
## factor > 1 means zoom in.
signal pinched(factor: float, screen_pos: Vector2)
## Two-finger or trackpad pan.
signal panned(screen_pos: Vector2, screen_delta: Vector2)

## Movement below this is still a tap.
const TAP_SLOP_PX := 12.0
const WHEEL_ZOOM_STEP := 1.12
const TRACKPAD_PAN_SCALE := 8.0

var _touches: Dictionary[int, Vector2] = {}
var _press_pos: Vector2 = Vector2.ZERO
var _dragging: bool = false
## Set once a second finger lands; the rest of that gesture can't become a tap or drag.
var _multi_touch: bool = false


## Out of the tree (main.gd takes it out for the sector map and for a battle) it hears no event,
## so a finger down when it left would never be released: it forgets every finger on leaving and
## on coming back, and the first touch after is a gesture of its own.
func _enter_tree() -> void:
	_reset()


func _exit_tree() -> void:
	_reset()


func _reset() -> void:
	_touches.clear()
	_dragging = false
	_multi_touch = false


## A drag that began on the world stays with the world even when the finger passes
## over a HUD panel (otherwise the panel would swallow the rest of the drag).
func _input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _touches.has(drag.index):
			_on_drag(drag)
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_on_drag(event as InputEventScreenDrag)
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if not button.pressed:
			return
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			pinched.emit(WHEEL_ZOOM_STEP, button.position)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			pinched.emit(1.0 / WHEEL_ZOOM_STEP, button.position)
		else:
			return
	elif event is InputEventMagnifyGesture:
		var magnify := event as InputEventMagnifyGesture
		pinched.emit(magnify.factor, magnify.position)
	elif event is InputEventPanGesture:
		var pan_gesture := event as InputEventPanGesture
		panned.emit(pan_gesture.position, -pan_gesture.delta * TRACKPAD_PAN_SCALE)
	else:
		return
	get_viewport().set_input_as_handled()


func _on_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touches[event.index] = event.position
		if _touches.size() == 1:
			_press_pos = event.position
			_dragging = false
			_multi_touch = false
		else:
			if _dragging:
				_dragging = false
				drag_ended.emit(event.position)
			_multi_touch = true
		return

	if not _touches.has(event.index):
		return
	var was_last_finger := _touches.size() == 1
	_touches.erase(event.index)
	if not was_last_finger:
		return
	if _dragging:
		_dragging = false
		drag_ended.emit(event.position)
	elif not _multi_touch and not event.canceled:
		tapped.emit(event.position)


func _on_drag(event: InputEventScreenDrag) -> void:
	if not _touches.has(event.index):
		return
	var previous: Vector2 = _touches[event.index]
	_touches[event.index] = event.position

	if _touches.size() == 1:
		if _multi_touch:
			return
		if not _dragging:
			if event.position.distance_to(_press_pos) < TAP_SLOP_PX:
				return
			_dragging = true
			drag_started.emit(_press_pos)
			dragged.emit(event.position, event.position - _press_pos)
			return
		dragged.emit(event.position, event.position - previous)
		return

	if _touches.size() == 2:
		var other := Vector2.ZERO
		for index: int in _touches:
			if index != event.index:
				other = _touches[index]
		var old_distance := previous.distance_to(other)
		var new_distance := event.position.distance_to(other)
		var old_mid := (previous + other) * 0.5
		var new_mid := (event.position + other) * 0.5
		if old_distance > 1.0:
			pinched.emit(new_distance / old_distance, new_mid)
		panned.emit(new_mid, new_mid - old_mid)
