class_name IsoCamera
extends Camera3D
## Fixed-angle orthographic camera. It only pans and zooms, never rotates, which keeps
## the base readable on a phone and keeps every building's silhouette consistent.

const PITCH_DEG := -35.0
const YAW_DEG := 45.0
## Orthographic, so distance only needs to keep everything between near and far.
const DISTANCE := 60.0
const MIN_ZOOM_SIZE := 10.0
const MAX_ZOOM_SIZE := 44.0
const START_ZOOM_SIZE := 24.0

## Ground point the camera looks at.
var focus: Vector3 = Vector3.ZERO
## World x/z rectangle the focus is kept inside.
var bounds: Rect2 = Rect2(-20, -20, 40, 40)

var _ground := Plane(Vector3.UP, 0.0)


func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	size = START_ZOOM_SIZE
	near = 0.1
	far = 200.0
	_apply()


func setup(area: Rect2) -> void:
	bounds = area
	var centre := area.get_center()
	focus = Vector3(centre.x, 0.0, centre.y)
	_apply()


## Where a screen point hits the ground plane, or null.
func ground_point(screen_pos: Vector2) -> Variant:
	return _ground.intersects_ray(project_ray_origin(screen_pos), project_ray_normal(screen_pos))


## Moves the view so the ground under the finger follows the finger.
func pan(screen_pos: Vector2, screen_delta: Vector2) -> void:
	var before: Variant = ground_point(screen_pos - screen_delta)
	var after: Variant = ground_point(screen_pos)
	if typeof(before) != TYPE_VECTOR3 or typeof(after) != TYPE_VECTOR3:
		return
	var grabbed: Vector3 = before
	var under_finger: Vector3 = after
	focus += grabbed - under_finger
	_apply()


## Moves the focus by a world offset, kept inside the bounds. The edge scroll's move.
func nudge(world_delta: Vector3) -> void:
	focus += world_delta
	_apply()


## factor > 1 zooms in. The ground point under `screen_pos` stays put.
func zoom_at(factor: float, screen_pos: Vector2) -> void:
	if factor <= 0.0:
		return
	var before: Variant = ground_point(screen_pos)
	size = clampf(size / factor, MIN_ZOOM_SIZE, MAX_ZOOM_SIZE)
	_apply()
	var after: Variant = ground_point(screen_pos)
	if typeof(before) == TYPE_VECTOR3 and typeof(after) == TYPE_VECTOR3:
		var anchor: Vector3 = before
		var drifted: Vector3 = after
		focus += anchor - drifted
		_apply()


func _apply() -> void:
	focus.x = clampf(focus.x, bounds.position.x, bounds.end.x)
	focus.z = clampf(focus.z, bounds.position.y, bounds.end.y)
	focus.y = 0.0
	var view_basis := Basis.from_euler(Vector3(deg_to_rad(PITCH_DEG), deg_to_rad(YAW_DEG), 0.0))
	global_transform = Transform3D(view_basis, focus + view_basis.z * DISTANCE)
