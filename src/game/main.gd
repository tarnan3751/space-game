extends Node3D
## Root of the base screen. Owns the BaseState, builds the scene in code, and wires
## the camera, input, views and HUD together. See CLAUDE.md for the layering rules.
##
## Saving is local for now (user://base.json). When the server exists, the base comes
## from the server instead and commands are sent there; nothing below main.gd changes.
##
## A `--save-path=<file>` user argument (after `--` on the command line) replaces the
## save file, so the harness and the gates never touch the real one.
##
## A debug build (every run from the editor binary) applies the dev cheats
## (Catalog.apply_dev_cheats: every level free and built in one second at most) and the HUD
## shows the resources as infinite. A `--no-cheats` user argument keeps the real numbers; the
## harness passes it.
##
## A battle (BattleView) takes the base's place while it runs: open_battle() takes the base's view
## and input out of the tree, hides the HUD and adds the battle and its attack HUD (BattleHud) in
## their place; when it finishes (the result panel's Return), the base comes back. Until the
## sector map exists, the only battle is the debug build's Practice raid (practice_setup): the
## template base raided by the army in the Hangars, whose result is never applied, so the save
## and the real base are untouched by it.

const DEFAULT_SAVE_PATH := "user://base.json"
const SAVE_PATH_ARG := "--save-path="
const NO_CHEATS_ARG := "--no-cheats"
const SAVE_EVERY_TICKS := 10

## Where this run loads and saves the base.
var save_path: String = DEFAULT_SAVE_PATH
## Whether this run's catalog has the dev cheats applied.
var cheats: bool = false

var catalog: Catalog
var state: BaseState
var base_view: BaseView
var camera: IsoCamera
var world_input: WorldInput
var placement: PlacementController
var hud: Hud
## The battle running in the base's place and its HUD; null when there is none.
var battle: BattleView
var battle_hud: BattleHud
var _ticks: int = 0
## Where the camera looked at the base, and its zoom, when a battle opened: put back after it.
var _base_focus: Vector3 = Vector3.ZERO
var _base_zoom: float = IsoCamera.START_ZOOM_SIZE


func _ready() -> void:
	save_path = _save_path_from_args()
	catalog = Catalog.load_default()
	if catalog.load_error != "":
		push_error("Game data is invalid: " + catalog.load_error)
		return
	cheats = OS.is_debug_build() and not OS.get_cmdline_user_args().has(NO_CHEATS_ARG)
	if cheats:
		catalog.apply_dev_cheats()

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
	hud.cheats = cheats
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
	hud.template_pressed.connect(_template_base)
	hud.practice_pressed.connect(_practice_raid)
	hud.train_pressed.connect(_on_train_pressed)
	hud.cancel_training_pressed.connect(_on_cancel_training_pressed)
	hud.research_pressed.connect(_on_research_pressed)
	hud.make_pressed.connect(_on_make_pressed)
	hud.cancel_making_pressed.connect(_on_cancel_making_pressed)
	hud.research_ability_pressed.connect(_on_research_ability_pressed)
	placement.selection_changed.connect(_refresh_hud)
	placement.placing_changed.connect(_on_placing_changed)
	placement.command_failed.connect(hud.show_error)

	_set_state(_load_or_create())

	var tick := Timer.new()
	tick.wait_time = 1.0
	tick.autostart = true
	tick.timeout.connect(_on_tick)
	add_child(tick)


## The one animation clock, set before any view animates (main is their ancestor, so it
## processes first): Motion.clock() for the moving parts, anim_time for the shaders.
func _process(_delta: float) -> void:
	RenderingServer.global_shader_parameter_set(&"anim_time", Motion.tick())


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
	hud.refresh(state, placement.selected_id, placement.is_placing(), placement.ghost_is_valid(),
		placement.is_painting())


## Fires on every move of the placement ghost, so the HUD updates only what a move changes.
func _on_placing_changed() -> void:
	hud.refresh_placing(state, placement.selected_id, placement.is_placing(), placement.ghost_is_valid(),
		placement.is_painting())


## A training card: one unit queued, or the reason it was not as a toast.
func _on_train_pressed(id: int, unit: String) -> void:
	var error := placement.train(id, unit)
	if error != "":
		hud.show_error(error)


## A queue entry: the newest of its unit cancelled and refunded.
func _on_cancel_training_pressed(id: int, unit: String) -> void:
	var error := placement.cancel_training(id, unit)
	if error == "":
		hud.show_message("Refunded")
	else:
		hud.show_error(error)


## A research card: the research started, or the reason it was not as a toast.
func _on_research_pressed(unit: String) -> void:
	var error := placement.research(unit)
	if error != "":
		hud.show_message(Hud.research_error_text(error))


## A making card: one ability queued, or the reason it was not as a toast.
func _on_make_pressed(id: int, ability: String) -> void:
	var error := placement.make(id, ability)
	if error != "":
		hud.show_error(error)


## A making queue entry: the newest of its ability cancelled and refunded.
func _on_cancel_making_pressed(id: int, ability: String) -> void:
	var error := placement.cancel_making(id, ability)
	if error == "":
		hud.show_message("Refunded")
	else:
		hud.show_error(error)


## An ability's research card: the research started, or the reason it was not as a toast.
func _on_research_ability_pressed(ability: String) -> void:
	var error := placement.research_ability(ability)
	if error != "":
		hud.show_message(Hud.research_error_text(error))


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


## Debug builds only, like the reset: the base becomes the template, every type at its top
## level grouped by category (TemplateBase), and is saved at once.
func _template_base() -> void:
	_set_state(BaseState.from_dict(catalog, TemplateBase.build(catalog, catalog.grid_size, _now())))
	_save()
	hud.show_message("Template base")


## Debug builds only: raids the template base (TemplateBase, as the battle scenario builds it) with
## the army in the Hangars at its researched levels; nothing is applied when it ends.
func _practice_raid() -> void:
	var setup := practice_setup()
	if (setup["attacker"]["army"] as Dictionary).is_empty():
		hud.show_message("Train some units first")
		return
	var error := open_battle(setup, true)
	if error != "":
		push_warning("The practice raid was refused: " + error)


## A practice raid's setup (docs/reference/battle.md): the template base's buildings and
## resources defending, the base's army at its levels attacking with the Foundry's stock at its
## levels, a seed from the clock (so each practice stands in a landscape of its own), no commands.
func practice_setup() -> Dictionary:
	var template := TemplateBase.build(catalog, catalog.grid_size, _now())
	var army := {}
	var levels := {}
	for unit: String in catalog.unit_types():
		if state.army_count(unit) > 0:
			army[unit] = state.army_count(unit)
			levels[unit] = state.unit_level(unit)
	var abilities := {}
	var ability_levels := {}
	for ability: String in catalog.ability_types():
		if state.stock(ability) > 0:
			abilities[ability] = state.stock(ability)
			ability_levels[ability] = state.ability_level(ability)
	return {
		"seed": _now() & SeededRng.MASK_32,
		"attacker": {"army": army, "unit_levels": levels, "abilities": abilities,
			"ability_levels": ability_levels},
		"defender": {"buildings": template["buildings"], "resources": template["resources"]},
		"commands": [],
	}


## Runs the battle of `setup` in the base's place: "" or why the setup was refused. `practice`:
## its result is not applied (the only battle until the sector map).
func open_battle(setup: Dictionary, practice: bool) -> String:
	if battle != null:
		push_error("A battle is already open")
		return "a battle is already open"
	var view := BattleView.new()
	var error := view.setup(catalog, setup, camera)
	if error != "":
		view.free()
		return error
	placement.cancel_place()
	placement.select(0)
	remove_child(base_view)
	remove_child(world_input)
	hud.visible = false
	battle = view
	add_child(battle)
	battle_hud = BattleHud.new()
	battle_hud.setup(catalog, hud.ui_theme(), hud.preview(), battle)
	add_child(battle_hud)
	_base_focus = camera.focus
	_base_zoom = camera.size
	camera.setup(battle.area())
	battle.finished.connect(_on_battle_finished.bind(practice))
	return ""


## The battle ended and was left: the base comes back. A practice applies nothing.
func _on_battle_finished(_setup: Dictionary, _result: Dictionary, practice: bool) -> void:
	battle.queue_free()
	battle = null
	battle_hud.queue_free()
	battle_hud = null
	add_child(base_view)
	add_child(world_input)
	camera.setup(base_view.area())
	camera.size = _base_zoom
	camera.nudge(_base_focus - camera.focus)
	hud.visible = true
	_refresh_hud()
	if practice:
		hud.show_message("Practice: nothing applied")


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


## The comic style's light (docs/reference/art-style.md, **Light and shading**): deep space
## behind, with stars and a nebula haze (sky.gdshader), a cool ambient for the sides the sun misses,
## and one warm key light whose filtered, single-split shadow the toon shader draws into its shadow
## band with a dotted edge. Linear tonemapping, so the accent colours come out as picked.
func _build_environment() -> void:
	var environment := Environment.new()
	# The sky is drawn on the view's plane, so it takes the camera's fixed angle. It lights
	# nothing: the ambient light is a colour and there are no reflections.
	var sky_material := ShaderMaterial.new()
	sky_material.shader = preload("res://src/game/sky.gdshader")
	sky_material.set_shader_parameter("view_basis",
		Basis.from_euler(Vector3(deg_to_rad(IsoCamera.PITCH_DEG), deg_to_rad(IsoCamera.YAW_DEG), 0.0)))
	sky_material.set_shader_parameter("space", MaterialKit.SPACE)
	sky_material.set_shader_parameter("haze", MaterialKit.TERRAIN)
	sky_material.set_shader_parameter("star_tint", MaterialKit.ENERGY)
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = MaterialKit.AMBIENT
	environment.ambient_light_energy = 0.35
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	sun.light_color = MaterialKit.SUN
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 80.0
	sun.shadow_normal_bias = 5.0
	sun.shadow_bias = 0.3
	add_child(sun)
