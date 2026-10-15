class_name BuildingView
extends Node3D
## Visual for one building: its model (or a scaffold while first being built), a
## footprint tile for selection/placement feedback, and a floating timer label.
## Holds no game state; BaseView and PlacementController push state into it.
##
## The meshes are shared, so a state shows by overriding an instance's material with another
## shared one from MaterialKit, never a new material: a selected or lifted building's outlines
## turn core gold (ink_selected) until both end, when the override is cleared (null); a
## placement ghost keeps plain ink outlines, lifted as it is, and its bodies take the valid or
## invalid ghost tint (set_ghost) for as long as it lives.

enum Footprint { NONE, SELECTED, VALID, INVALID }

const FOOTPRINT_COLORS := {
	Footprint.SELECTED: Color(0.31, 0.84, 0.9, 0.4),
	Footprint.VALID: Color(0.3, 0.9, 0.45, 0.6),
	Footprint.INVALID: Color(0.95, 0.3, 0.3, 0.65),
}
const LIFT_HEIGHT := 0.35
## The timer label's text, in font pixels, and its outline (the stroke reaches a quarter of
## outline_size out): about 2 px of ink round the text at the starting zoom.
const LABEL_FONT_SIZE := 48
const LABEL_OUTLINE_SIZE := 20

var building_id: int = 0
var building_type: String = ""
## The finished level the model shows; 0 while the building is first being constructed.
var building_level: int = 0
var footprint_size: int = 1

var _model: Node3D
var _scaffold: Node3D
var _footprint: MeshInstance3D
var _footprint_material: StandardMaterial3D
var _label: Label3D
## The models' and the scaffold's mesh instances: bodies and ink outlines.
var _bodies: Array[MeshInstance3D] = []
var _outlines: Array[MeshInstance3D] = []
var _selected: bool = false
var _lifted: bool = false
## A placement ghost's body tint (set_ghost), null for any other view. A ghost's outlines stay
## plain ink though it is lifted.
var _ghost_tint: Material = null
## Whether the outlines carry the selected ink now.
var _inked: bool = false
## The model's moving parts, each with its Motion and its rest position, and the seconds the
## view has spent animating them (it stands still while the building is busy).
var _movers: Array[Node3D] = []
var _motions: Array[Motion] = []
var _rests: PackedVector3Array = PackedVector3Array()
var _time: float = 0.0
var _animate: bool = true
## BaseView's merged wall mesh draws this building, so its own model is hidden (set_merged).
var _merged: bool = false


## Call once, before adding to the tree. `level` picks the model (level 1's while it is 0).
func setup(id: int, type: String, level: int, size: int) -> void:
	building_id = id
	building_type = type
	building_level = level
	footprint_size = size

	_model = BuildingModels.create(type, maxi(level, 1), size)
	add_child(_model)
	_collect_movers(_model)
	_scaffold = BuildingModels.create_scaffold(size)
	add_child(_scaffold)
	_collect_meshes(_model)
	_collect_meshes(_scaffold)

	var plane := PlaneMesh.new()
	# Full footprint plus a small rim, so it shows around the model's base slab.
	plane.size = Vector2(size, size) + Vector2(0.3, 0.3)
	_footprint_material = StandardMaterial3D.new()
	_footprint_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_footprint_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_footprint = MeshInstance3D.new()
	_footprint.mesh = plane
	_footprint.material_override = _footprint_material
	_footprint.position = Vector3(0, 0.03, 0)
	add_child(_footprint)

	# In the HUD's font and colours, its own Lilita One, ink-outlined.
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font = Hud.BODY_FONT
	_label.font_size = LABEL_FONT_SIZE
	_label.outline_size = LABEL_OUTLINE_SIZE
	_label.pixel_size = 0.016
	_label.modulate = Hud.TEXT
	_label.outline_modulate = Hud.INK
	_label.position = Vector3(0, 1.4 + size * 0.4, 0)
	add_child(_label)

	set_footprint(Footprint.NONE)
	show_status(1, false, 1, 0)


func _ready() -> void:
	# Nothing to animate (walls, traps) costs nothing per frame. Not in setup(): entering the
	# tree turns processing on for any script with _process.
	set_process(not _movers.is_empty())


## level 0 = first construction (scaffold). busy = constructing or upgrading.
func show_status(level: int, busy: bool, target_level: int, seconds_left: int) -> void:
	_model.visible = level >= 1 and not _merged
	_scaffold.visible = level < 1
	_animate = level >= 1 and not busy
	_label.visible = busy
	if busy:
		var what := "Building" if level < 1 else "Lv %d" % target_level
		_label.text = "%s  %s" % [what, Format.duration(seconds_left)]


## The footprint tile; SELECTED also inks the outlines in gold.
func set_footprint(mode: Footprint) -> void:
	_footprint.visible = mode != Footprint.NONE
	if mode != Footprint.NONE:
		_footprint_material.albedo_color = FOOTPRINT_COLORS[mode]
	_selected = mode == Footprint.SELECTED
	_update_outlines()


## A wall that BaseView's merged wall mesh draws hides its model; the footprint tile, the
## label and the lift stay the view's. The scaffold, shown while the level is 0, is untouched.
## Its outlines go with the model, so a merged wall shows no gold when it is selected.
func set_merged(on: bool) -> void:
	_merged = on
	_model.visible = not on and not _scaffold.visible


## Whether the view draws its own model: finished, and not drawn by the merged wall mesh.
func is_model_visible() -> bool:
	return _model.visible


## Raised slightly while being dragged, so it reads as "picked up", with gold outlines (a
## ghost's stay plain).
func set_lifted(lifted: bool) -> void:
	var height := LIFT_HEIGHT if lifted else 0.0
	_model.position = Vector3(0, height, 0)
	_scaffold.position = Vector3(0, height, 0)
	_lifted = lifted
	_update_outlines()


## Marks the view as a placement ghost and tints its bodies for a spot it can (valid) or cannot
## take; its outlines stay plain ink.
func set_ghost(valid: bool) -> void:
	var material := MaterialKit.ghost_valid() if valid else MaterialKit.ghost_invalid()
	if material == _ghost_tint:
		return
	_ghost_tint = material
	_update_outlines()
	for body: MeshInstance3D in _bodies:
		if body.mesh.surface_get_material(0) == MaterialKit.toon():
			body.set_surface_override_material(0, material)


func _process(delta: float) -> void:
	if not _animate:
		return
	_time += delta
	for i: int in _movers.size():
		_movers[i].transform = _motions[i].transform_at(_time, _rests[i])


func _update_outlines() -> void:
	var inked := (_selected or _lifted) and _ghost_tint == null
	if inked == _inked:
		return
	_inked = inked
	var material: Material = MaterialKit.ink_selected() if inked else null
	for outline: MeshInstance3D in _outlines:
		outline.set_surface_override_material(0, material)


func _collect_meshes(node: Node) -> void:
	for child: Node in node.get_children():
		if child is MeshInstance3D:
			if child.has_meta(BuildingModels.OUTLINE_META):
				_outlines.append(child as MeshInstance3D)
			else:
				_bodies.append(child as MeshInstance3D)
		_collect_meshes(child)


func _collect_movers(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Node3D and child.has_meta(BuildingModels.MOVE_META):
			var mover := child as Node3D
			_movers.append(mover)
			_motions.append(mover.get_meta(BuildingModels.MOVE_META) as Motion)
			_rests.append(mover.position)
		_collect_movers(child)
