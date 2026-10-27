class_name ModelPreview
extends Node
## The cards' pictures: each building type's level 1 model, and each unit type's model at a tier
## asked for (unit_key), rendered once into a texture and kept for the session
## (docs/reference/hud.md, **Cards**). A picture is named by its key: a building's type, or
## unit_key(type, tier) for a unit's (the training, research and deploy cards).
##
## One SubViewport, with a world of its own, renders the models one a frame while the HUD lets
## it run (while the build panel is open): a model is put in front of the camera one frame,
## drawn at the end of it, and read back into an ImageTexture the next, which emits `rendered`.
## The camera looks from the world's angle (IsoCamera) and the key light from main.gd's
## direction, with no ambient and no shadow; the materials are the world's, the ink's line
## widened to the same pixels on the texture as on the screen. Moving parts stand at time 0.
## Once every type is cached the viewport is freed and the node stops processing; a request()
## for more builds it again.

signal rendered(key: String, texture: Texture2D)

## The texture's side, in pixels.
const SIZE := 160
## Round the model's bounds, as a share of their larger side.
const MARGIN := 0.08
## The key light's rotation, as main.gd's.
const SUN_ROTATION := Vector3(-55.0, -30.0, 0.0)
## The world's ink line, in pixels at a 720 px viewport height (ink.gdshader's ink_px), which
## the preview's ink draws at its own height instead.
const INK_PX := 2.2
const CAMERA_DISTANCE := 50.0
## A unit picture's key starts with this, then the type and the tier (unit_key).
const UNIT_PREFIX := "unit:"

var _catalog: Catalog
var _cache: Dictionary[String, Texture2D] = {}
## The types still to render, next first.
var _queue: PackedStringArray = PackedStringArray()
var _viewport: SubViewport
var _camera: Camera3D
var _ink: ShaderMaterial
## The model drawn this frame, read back next; null between models.
var _model: Node3D
var _model_type: String = ""


func setup(catalog: Catalog, types: PackedStringArray) -> void:
	_catalog = catalog
	_queue = types.duplicate()


func _ready() -> void:
	# A script with _process is set processing when it enters the tree; it waits for run().
	set_process(false)


## The key of `unit`'s picture at `tier` (Parts.Tier).
static func unit_key(unit: String, tier: int) -> String:
	return "%s%s:%d" % [UNIT_PREFIX, unit, tier]


## The picture of `key` (a building type or a unit_key), or null until it is rendered.
func texture_of(key: String) -> Texture2D:
	return _cache.get(key)


## Puts the keys not pictured or queued yet at the front of the queue, in their order; run() renders
## them.
func request(keys: PackedStringArray) -> void:
	var front := PackedStringArray()
	for key: String in keys:
		if not _cache.has(key) and not _queue.has(key) and key != _model_type and not front.has(key):
			front.append(key)
	_queue = front + _queue


## Whether every type has its picture.
func is_done() -> bool:
	return _queue.is_empty() and _model == null


## Renders while `on`, one model a frame.
func run(on: bool) -> void:
	set_process(on and not is_done())


## Moves `types` to the front of the queue, in their order.
func prioritize(types: PackedStringArray) -> void:
	var rest := PackedStringArray()
	for type: String in _queue:
		if not types.has(type):
			rest.append(type)
	var front := PackedStringArray()
	for type: String in types:
		if _queue.has(type):
			front.append(type)
	_queue = front + rest


func _process(_delta: float) -> void:
	if _model != null:
		_read_back()
	if _queue.is_empty():
		_viewport.queue_free()
		_viewport = null
		_camera = null
		_ink = null
		set_process(false)
		return
	if _viewport == null:
		_build_viewport()
	_stage(_queue[0])
	_queue.remove_at(0)


func _build_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(SIZE, SIZE)
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.near = 0.1
	_camera.far = CAMERA_DISTANCE * 2.0
	_camera.environment = environment
	_camera.basis = Basis.from_euler(Vector3(deg_to_rad(IsoCamera.PITCH_DEG), deg_to_rad(IsoCamera.YAW_DEG), 0.0))
	_viewport.add_child(_camera)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = SUN_ROTATION
	sun.light_color = MaterialKit.SUN
	_viewport.add_child(sun)
	# ink.gdshader draws ink_px pixels at a 720 px height, a share of the view's height; this
	# viewport is SIZE high, so the same share would be under a pixel.
	_ink = MaterialKit.ink().duplicate() as ShaderMaterial
	_ink.set_shader_parameter("ink_px", INK_PX * 720.0 / SIZE)


## Puts the model of `key` (a building type or a unit_key) in front of the camera, framed, to be
## drawn this frame.
func _stage(key: String) -> void:
	_model_type = key
	if key.begins_with(UNIT_PREFIX):
		var parts := key.trim_prefix(UNIT_PREFIX).split(":")
		_model = UnitModels.create(parts[0], int(parts[1]))
	else:
		_model = BuildingModels.create(key, 1, _catalog.size_of(key), BuildingModels.tier_of(_catalog, key, 1))
		BuildingModels.hold(_model, 0.0)
	var bounds := AABB()
	var first := true
	for child: Node in _model.find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = child
		if instance.has_meta(BuildingModels.OUTLINE_META):
			instance.material_override = _ink
		var parent := instance.get_parent() as Node3D
		if parent.has_meta(BuildingModels.MOVE_META):
			var motion: Motion = parent.get_meta(BuildingModels.MOVE_META)
			parent.transform = motion.transform_at(0.0, parent.position)
		var box := _model.transform * (parent.transform if parent != _model else Transform3D.IDENTITY) * instance.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	_viewport.add_child(_model)
	# The bounds' corners in the camera's plane: the camera frames their extent. A unit, slender
	# and round where a building is a block, would sit small in its bounds' corners, so it is
	# framed on its body's own vertices instead and fills the picture as a building does.
	var view := _camera.basis
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	var points := PackedVector3Array()
	if key.begins_with(UNIT_PREFIX):
		for child: Node in _model.find_children("*", "MeshInstance3D", true, false):
			var instance: MeshInstance3D = child
			if not instance.has_meta(BuildingModels.OUTLINE_META):
				for surface: int in instance.mesh.get_surface_count():
					var vertices: PackedVector3Array = instance.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
					points.append_array(_model.transform * vertices)
	else:
		for i: int in 8:
			points.append(bounds.get_endpoint(i))
	for point: Vector3 in points:
		var on_view := Vector2(point.dot(view.x), point.dot(view.y))
		low = low.min(on_view)
		high = high.max(on_view)
	var extent := high - low
	_camera.size = maxf(extent.x, extent.y) * (1.0 + 2.0 * MARGIN)
	var centre := (low + high) / 2.0
	_camera.position = view.x * centre.x + view.y * centre.y + view.z * CAMERA_DISTANCE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


## The staged model's frame, drawn at the end of the last one, into the cache.
## A headless run draws nothing, so it has no image to read: the type is done, unpictured.
func _read_back() -> void:
	_model.queue_free()
	_model = null
	var key := _model_type
	_model_type = ""
	if DisplayServer.get_name() == "headless":
		return
	var texture := ImageTexture.create_from_image(_viewport.get_texture().get_image())
	_cache[key] = texture
	rendered.emit(key, texture)
