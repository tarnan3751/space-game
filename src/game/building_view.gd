class_name BuildingView
extends Node3D
## Visual for one building: its model (or a scaffold while first being built), a
## footprint tile for selection/placement feedback, and a floating timer label.
## Holds no game state; BaseView and PlacementController push state into it.

enum Footprint { NONE, SELECTED, VALID, INVALID }

const FOOTPRINT_COLORS := {
	Footprint.SELECTED: Color(0.31, 0.84, 0.9, 0.4),
	Footprint.VALID: Color(0.3, 0.9, 0.45, 0.6),
	Footprint.INVALID: Color(0.95, 0.3, 0.3, 0.65),
}
const LIFT_HEIGHT := 0.35

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
var _spinners: Array[Node3D] = []
var _spin_speeds: PackedFloat32Array = PackedFloat32Array()
var _animate: bool = true


## Call once, before adding to the tree. `level` picks the model (level 1's while it is 0).
func setup(id: int, type: String, level: int, size: int) -> void:
	building_id = id
	building_type = type
	building_level = level
	footprint_size = size

	_model = BuildingModels.create(type, maxi(level, 1), size)
	add_child(_model)
	_collect_spinners(_model)
	_scaffold = BuildingModels.create_scaffold(size)
	add_child(_scaffold)

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

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 48
	_label.outline_size = 14
	_label.pixel_size = 0.016
	_label.modulate = Color("e9f6ff")
	_label.outline_modulate = Color(0, 0, 0, 0.85)
	_label.position = Vector3(0, 1.4 + size * 0.4, 0)
	add_child(_label)

	set_footprint(Footprint.NONE)
	show_status(1, false, 1, 0)


func _ready() -> void:
	# Nothing to animate (walls, traps) costs nothing per frame. Not in setup(): entering the
	# tree turns processing on for any script with _process.
	set_process(not _spinners.is_empty())


## level 0 = first construction (scaffold). busy = constructing or upgrading.
func show_status(level: int, busy: bool, target_level: int, seconds_left: int) -> void:
	_model.visible = level >= 1
	_scaffold.visible = level < 1
	_animate = level >= 1 and not busy
	_label.visible = busy
	if busy:
		var what := "Building" if level < 1 else "Lv %d" % target_level
		_label.text = "%s  %s" % [what, Format.duration(seconds_left)]


func set_footprint(mode: Footprint) -> void:
	_footprint.visible = mode != Footprint.NONE
	if mode != Footprint.NONE:
		_footprint_material.albedo_color = FOOTPRINT_COLORS[mode]


## Raised slightly while being dragged, so it reads as "picked up".
func set_lifted(lifted: bool) -> void:
	var height := LIFT_HEIGHT if lifted else 0.0
	_model.position = Vector3(0, height, 0)
	_scaffold.position = Vector3(0, height, 0)


func _process(delta: float) -> void:
	if not _animate:
		return
	for i: int in _spinners.size():
		_spinners[i].rotate_y(_spin_speeds[i] * delta)


func _collect_spinners(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Node3D and child.has_meta(BuildingModels.SPIN_META):
			_spinners.append(child as Node3D)
			_spin_speeds.append(float(child.get_meta(BuildingModels.SPIN_META)))
		_collect_spinners(child)
