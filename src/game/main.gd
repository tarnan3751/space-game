extends Node3D
## Root of the base screen. Owns the BaseState, builds the scene in code, and wires
## the camera, input, views and HUD together. See CLAUDE.md for the layering rules.
##
## Saving is local for now (user://base.json). When the server exists, the base comes
## from the server instead and commands are sent there; nothing below main.gd changes.
##
## A `--save-path=<file>` user argument (after `--` on the command line) replaces the
## save file, so the harness and the gates never touch the real one.

const DEFAULT_SAVE_PATH := "user://base.json"
const SAVE_PATH_ARG := "--save-path="
const SAVE_EVERY_TICKS := 10

## Where this run loads and saves the base.
var save_path: String = DEFAULT_SAVE_PATH

var catalog: Catalog
var state: BaseState
var base_view: BaseView
var camera: IsoCamera
var world_input: WorldInput
var placement: PlacementController
var hud: Hud
var _ticks: int = 0


func _ready() -> void:
	save_path = _save_path_from_args()
	catalog = Catalog.load_default()
	if catalog.load_error != "":
		push_error("Game data is invalid: " + catalog.load_error)
		return

	_build_environment()

	base_view = BaseView.new()
	add_child(base_view)
	base_view.setup(catalog.grid_size)

	camera = IsoCamera.new()
	add_child(camera)
	camera.setup(base_view.area())
	camera.make_current()

	world_input = WorldInput.new()
	add_child(world_input)

	hud = Hud.new()
	add_child(hud)
	hud.setup(catalog)

	placement = PlacementController.new()
	placement.base_view = base_view
	placement.camera = camera
	placement.clock = _now
	add_child(placement)
	placement.connect_input(world_input)

	hud.build_pressed.connect(placement.begin_place)
	hud.confirm_pressed.connect(placement.confirm_place)
	hud.cancel_pressed.connect(placement.cancel_place)
	hud.upgrade_pressed.connect(placement.upgrade_selected)
	hud.close_pressed.connect(func() -> void: placement.select(0))
	hud.reset_pressed.connect(_reset_base)
	placement.selection_changed.connect(_refresh_hud)
	placement.placing_changed.connect(_refresh_hud)
	placement.command_failed.connect(hud.show_error)

	_set_state(_load_or_create())

	var tick := Timer.new()
	tick.wait_time = 1.0
	tick.autostart = true
	tick.timeout.connect(_on_tick)
	add_child(tick)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save()


## The local clock. Easy to cheat by changing the device time; the server will own time.
func _now() -> int:
	return int(Time.get_unix_time_from_system())


func _on_tick() -> void:
	state.advance_to(_now())
	# Timer labels change every second even when nothing else did.
	base_view.sync(state)
	_refresh_hud()
	_ticks += 1
	if _ticks % SAVE_EVERY_TICKS == 0:
		_save()


func _on_state_changed() -> void:
	base_view.sync(state)
	placement.refresh()
	_refresh_hud()


func _refresh_hud() -> void:
	if state == null:
		return
	hud.refresh(state, placement.selected_id, placement.is_placing(), placement.ghost_is_valid())


func _set_state(new_state: BaseState) -> void:
	if state != null and state.changed.is_connected(_on_state_changed):
		state.changed.disconnect(_on_state_changed)
	state = new_state
	state.changed.connect(_on_state_changed)
	placement.state = state
	placement.cancel_place()
	placement.select(0)
	base_view.clear()
	base_view.sync(state)
	_refresh_hud()


func _reset_base() -> void:
	_set_state(BaseState.create_new(catalog, _now()))
	_save()
	hud.show_message("Base reset")


func _load_or_create() -> BaseState:
	if FileAccess.file_exists(save_path):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
		if typeof(data) == TYPE_DICTIONARY:
			var loaded := BaseState.from_dict(catalog, data)
			# Offline progress: finish timers and pay out production since the last save.
			loaded.advance_to(_now())
			return loaded
		push_warning("Save file unreadable, starting a new base")
	return BaseState.create_new(catalog, _now())


func _save() -> void:
	if state == null:
		return
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save the base: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(state.to_dict(), "\t"))


static func _save_path_from_args() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(SAVE_PATH_ARG):
			return arg.trim_prefix(SAVE_PATH_ARG)
	return DEFAULT_SAVE_PATH


func _build_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("07060f")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8a86b8")
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	sun.light_color = Color("fff1dc")
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)

	# Cool fill from the other side, like light bouncing off a nearby planet.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25.0, 150.0, 0.0)
	fill.light_color = Color("5fa8ff")
	fill.light_energy = 0.35
	add_child(fill)
