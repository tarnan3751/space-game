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
## main owns quitting: a window's close request saves, silences the sounds and waits
## QUIT_SETTLE_SECONDS for the mixer to let go of them before it quits, or the engine reports
## the playing music as leaked at exit. A `--quit-frames=<n>` user argument takes the same quiet
## path after n frames and says so in the log; the gate's boot uses it instead of `--quit-after`.
##
## A debug build (every run from the editor binary) applies the dev cheats
## (Catalog.apply_dev_cheats: every level free and built in one second at most) and the HUD
## shows the resources as infinite. A `--no-cheats` user argument keeps the real numbers; the
## harness passes it.
##
## A battle (BattleView) takes the base's place while it runs: open_battle() takes the base's view
## and input out of the tree, hides the HUD and adds the battle and its attack HUD (BattleHud) in
## their place; when it finishes (the result panel's Return), the base comes back. An expedition
## starts from the sector map (SectorMap, over the base while it is open, the world's input out of
## the tree): the chosen field's outpost (OutpostGenerator) raided by the army in the Hangars,
## drawn as a rival colony; its result is applied through PlacementController.raid_result, and the
## map opens again on the base. The debug build's Practice raid (practice_setup) raids the
## template base instead, and its result is never applied, so the save and the real base are
## untouched by it.
##
## The sounds (Audio, main.audio) are wired in _wire_audio: the base's events through their
## signals, the HUD's buttons through Audio.tap_buttons, and the battle's shots and landings by
## handing the node to the battle view.

const DEFAULT_SAVE_PATH := "user://base.json"
const SAVE_PATH_ARG := "--save-path="
const NO_CHEATS_ARG := "--no-cheats"
const QUIT_FRAMES_ARG := "--quit-frames="
## How long a quit waits after silencing the sounds, frames running: the mixer, on its own thread,
## lets go of a stopped sound after its next mix, and a frame after that frees it, so a count of
## frames is not enough (they can all pass inside one mix headless). As the harness driver waits.
const QUIT_SETTLE_SECONDS := 0.1
const SAVE_EVERY_TICKS := 10
## The HUD's pictures start rendering in idle frames this long after boot.
const PRERENDER_AFTER := 1.0

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
## The expeditions' screen, over the base while it is open.
var sector_map: SectorMap
## The battle running in the base's place and its HUD; null when there is none.
var battle: BattleView
var battle_hud: BattleHud
## Plays the sounds.
var audio: Audio
var _ticks: int = 0
## What a state change or the tick left to redraw, serviced once at the end of the frame's
## _process: the base's view, the ghost and the HUD; and the sector map's cards while it is open.
var _dirty: bool = false
var _sector_dirty: bool = false
## Seconds since boot, counted up to PRERENDER_AFTER; and whether the HUD's pictures are rendering
## in the base's idle frames (Hud.prerender).
var _booted: float = 0.0
var _prerendering: bool = false
## The frames to quit after (--quit-frames, 0 for none), the frames run, and whether a quit is under way.
var _quit_frames: int = 0
var _frames: int = 0
var _quitting: bool = false
## Where the camera looked at the base, and its zoom, when a battle opened: put back after it.
var _base_focus: Vector3 = Vector3.ZERO
var _base_zoom: float = IsoCamera.START_ZOOM_SIZE


func _ready() -> void:
	save_path = _save_path_from_args()
	get_tree().auto_accept_quit = false
	_quit_frames = _quit_frames_from_args()
	catalog = Catalog.load_default()
	if catalog.load_error != "":
		push_error("Game data is invalid: " + catalog.load_error)
		return
	cheats = OS.is_debug_build() and not OS.get_cmdline_user_args().has(NO_CHEATS_ARG)
	if cheats:
		catalog.apply_dev_cheats()

	_build_environment()

	audio = Audio.new()
	# A run with its own save keeps its own settings beside it.
	if save_path != DEFAULT_SAVE_PATH:
		audio.settings_path = save_path.get_base_dir().path_join("settings.cfg")
	add_child(audio)

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
	sector_map = SectorMap.new()
	sector_map.setup(catalog)
	hud.add_screen(sector_map)

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
	hud.expedition_pressed.connect(open_sector_map)
	sector_map.closed.connect(_on_sector_map_closed)
	sector_map.scan_pressed.connect(_on_scan_pressed)
	sector_map.attack_pressed.connect(_on_attack_pressed)
	placement.selection_changed.connect(_refresh_hud)
	placement.placing_changed.connect(_on_placing_changed)
	placement.command_failed.connect(hud.show_error)
	_wire_audio()

	_set_state(_load_or_create())

	var tick := Timer.new()
	tick.wait_time = 1.0
	tick.autostart = true
	tick.timeout.connect(_on_tick)
	add_child(tick)
	audio.music(&"base")


## The sounds of the base and its HUD (docs/reference/audio.md, **Hooks**): a building tapped and
## a construction started (PlacementController), finished (BaseView), every HUD button's tap, and
## the build panel opening and closing.
func _wire_audio() -> void:
	placement.sound = _base_sound
	base_view.building_finished.connect(func(_id: int) -> void: _base_sound(&"build_done", 0.0))
	audio.tap_buttons(hud)
	# The HUD's own handler ran first, so the panel is already open or closed.
	hud.build_button().pressed.connect(func() -> void: audio.play(&"ui_open" if hud.is_menu_open() else &"ui_close"))
	hud.close_button().pressed.connect(func() -> void: audio.play(&"ui_close"))


## Plays the base's sound `key` (its pitch varied up to `pitch_jitter`), unless a battle runs in the
## base's place (its view keeps syncing out of the tree, and a construction finishing then is not
## heard).
func _base_sound(key: StringName, pitch_jitter: float = 0.06) -> void:
	if battle == null:
		audio.play(key, pitch_jitter)


## The one animation clock, set before any view animates (main is their ancestor, so it
## processes first): Motion.clock() for the moving parts, anim_time for the shaders. Then what the
## frame's state changes and the tick marked is redrawn, once however many there were: a command
## applied from input (which runs before _process) is drawn in the same frame.
func _process(delta: float) -> void:
	if _quit_frames > 0:
		_frames += 1
		if _frames == _quit_frames:
			print("main: quitting after %d frames" % _frames)
			_quit()
	RenderingServer.global_shader_parameter_set(&"anim_time", Motion.tick())
	if _booted < PRERENDER_AFTER:
		_booted += delta
	var idle := _booted >= PRERENDER_AFTER and state != null and battle == null and not sector_map.visible \
		and not placement.is_placing() and not placement.is_dragging()
	if idle != _prerendering:
		_prerendering = idle
		hud.prerender(idle)
	if _dirty:
		_dirty = false
		base_view.sync(state)
		placement.refresh()
		_refresh_hud()
	if _sector_dirty:
		_sector_dirty = false
		if sector_map.visible:
			sector_map.refresh(state)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit()


## Quits quietly: the sounds shut down and QUIT_SETTLE_SECONDS waited, so nothing playing is
## left to the engine's exit. Phones never ask to close; the system ends the app.
func _quit() -> void:
	if _quitting:
		return
	_quitting = true
	if audio != null:
		audio.shut_down()
	await get_tree().create_timer(QUIT_SETTLE_SECONDS).timeout
	get_tree().quit()


## The local clock. Easy to cheat by changing the device time; the server will own time.
func _now() -> int:
	return int(Time.get_unix_time_from_system())


func _on_tick() -> void:
	state.advance_to(_now())
	# Timer labels change every second even when nothing else did.
	_dirty = true
	hud.fit_safe_area()
	if sector_map.visible:
		sector_map.tick(state)
	_ticks += 1
	if _ticks % SAVE_EVERY_TICKS == 0:
		_save()


## Marks the redraw _process does; production fires this every second on a producing base, and
## a command once per apply.
func _on_state_changed() -> void:
	_dirty = true
	_sector_dirty = true


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
		hud.show_message(Hud.research_error_text(error), Hud.ToastKind.REFUSAL)


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
		hud.show_message(Hud.research_error_text(error), Hud.ToastKind.REFUSAL)


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
		hud.show_message("Train some units first", Hud.ToastKind.REFUSAL)
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


## Opens the sector map over the base, its world input out of the tree so no tap reaches the base;
## nothing while a battle runs or the map is open.
func open_sector_map() -> void:
	if battle != null or sector_map.visible:
		return
	placement.cancel_place()
	placement.select(0)
	remove_child(world_input)
	sector_map.open(state)


func _on_sector_map_closed() -> void:
	if not world_input.is_inside_tree():
		add_child(world_input)


## The map's Scan: the next epoch, or why not as a toast.
func _on_scan_pressed() -> void:
	var error := placement.scan()
	if error != "":
		hud.show_error(error)


## The detail's Attack on field `index` (laid out as `field`): the army in the Hangars and the
## abilities in stock, at their levels, against the outpost, its field's seed the landscape's, the
## map closed for the battle. With no units it is refused with a toast.
func _on_attack_pressed(index: int, field: Dictionary) -> void:
	var army := {}
	for unit: String in catalog.unit_types():
		if state.army_count(unit) > 0:
			army[unit] = state.army_count(unit)
	if army.is_empty():
		hud.show_message("Train some units first", Hud.ToastKind.REFUSAL)
		return
	var abilities := {}
	for ability: String in state.ability_stock:
		if state.ability_stock[ability] > 0:
			abilities[ability] = state.ability_stock[ability]
	var setup := OutpostGenerator.battle_setup(field, army, state.unit_levels, abilities, state.ability_levels)
	sector_map.close()
	var error := open_battle(setup, false, {"epoch": state.sector.epoch, "index": index})
	if error != "":
		hud.show_error(error)
		open_sector_map()


## Runs the battle of `setup` in the base's place: "" or why the setup was refused. `practice`:
## its result is not applied. `expedition` ({"epoch", "index"} of its field, empty for none): the
## defender is drawn as a rival colony, and the result is applied with the field's key.
func open_battle(setup: Dictionary, practice: bool, expedition: Dictionary = {}) -> String:
	if battle != null:
		push_error("A battle is already open")
		return "a battle is already open"
	var view := BattleView.new()
	view.rival = not expedition.is_empty()
	view.audio = audio
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
	audio.music(&"combat", 1.5)
	# The base is no longer idle: the prerender stops before the battle's HUD runs the preview for
	# its deploy cards, so the next frame's idle check leaves that run alone.
	if _prerendering:
		_prerendering = false
		hud.prerender(false)
	battle_hud = BattleHud.new()
	battle_hud.setup(catalog, hud.ui_theme(), hud.preview(), battle)
	add_child(battle_hud)
	audio.tap_buttons(battle_hud)
	_base_focus = camera.focus
	_base_zoom = camera.size
	camera.setup(battle.area())
	battle.finished.connect(_on_battle_finished.bind(practice, expedition))
	battle.ended.connect(_on_battle_ended)
	return ""


## The battle is over: a fanfare for a victory (a star or more), a fall for a defeat.
func _on_battle_ended(result: Dictionary) -> void:
	audio.sting(&"victory" if int(result.get("stars", 0)) > 0 else &"defeat")


## The battle ended and was left: the base comes back. A practice applies nothing; an expedition's
## result is applied (_apply_expedition).
func _on_battle_finished(setup: Dictionary, result: Dictionary, practice: bool, expedition: Dictionary) -> void:
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
	audio.music(&"base", 2.0)
	_refresh_hud()
	if practice:
		hud.show_message("Practice: nothing applied")
	elif not expedition.is_empty():
		_apply_expedition(setup, result, expedition)


## An expedition's end applied with its field's key: a toast of the field cleared with its stars,
## or still open, and what came home (the loot up to storage), or the error; then the map again,
## the field stamped once cleared.
func _apply_expedition(setup: Dictionary, result: Dictionary, expedition: Dictionary) -> void:
	var before := state.resources.duplicate()
	var error := placement.raid_result(setup, result, expedition)
	if error != "":
		hud.show_error(error)
	else:
		var stars := int(result.get("stars", 0))
		var text := "Field still open"
		if stars >= 1:
			text = "Field cleared: %d %s" % [stars, "star" if stars == 1 else "stars"]
		var gains := PackedStringArray()
		for res: String in catalog.resources:
			var gained := state.resources[res] - int(before[res])
			if gained > 0:
				gains.append("+%s %s" % [Format.amount(gained), catalog.resource_name(res).to_lower()])
		if not gains.is_empty():
			text += "\n" + ", ".join(gains)
		# A field cleared, or anything brought home, is a reward.
		hud.show_message(text, Hud.ToastKind.REWARD if stars >= 1 or not gains.is_empty() else Hud.ToastKind.INFO)
	open_sector_map()


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


static func _quit_frames_from_args() -> int:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(QUIT_FRAMES_ARG):
			return arg.trim_prefix(QUIT_FRAMES_ARG).to_int()
	return 0


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
