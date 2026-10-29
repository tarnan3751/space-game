extends HarnessScenario
## The sounds (docs/reference/audio.md): every key in Sounds.TABLE loaded as a 16-bit 44.1 kHz mono
## stream of the length its bounds allow, looping as its recipe says; the buses and the limiter;
## every key played once and recorded; one key played 100 times in a frame sounding once; a flood
## of plays never past the pool's voices, a sting still getting one; a loop held and stopped, and a
## loop's fade ended by silence(); three scheduled plays sounding in order, and a due play retired
## behind one still waiting; a missing track refused; a volume kept in the run's own settings file;
## no work a frame idle. Before all that, the boot: its sting once and the base's ambience looping,
## ducked under the build panel and back. Then the hooks: Build and Close tapped (ui_tap, ui_open,
## ui_tap_soft, ui_close), the toasts by kind, a refusal's buzz once however many ask for it in a
## frame, the settings panel round-tripped through its sliders and its mute, a building tapped
## (its category's select sound) and tapped again (nothing), a building placed (place_ok), its
## drone's laser, the base's metal meter filling (meter_full), an upgrade started (build_start) and
## a construction finished (build_done), another finishing during a practice battle (nothing,
## the ambience off) and the ambience back after it, and the battle
## against the template base's mapped defences (laser_fire and impact_small, the shells and missiles
## when they come, and a sting at the end), with Audio's cost a frame from Profile. The music: the
## base's track playing from boot, crossfaded to the combat track as the battle opens and back to
## the base's as it is left. Plays are recorded whatever the device, so the checks hold on run.sh's
## Dummy audio driver; a rendered run with --audible plays them aloud. In the battle, too: the
## training panel open as it opens closes unheard, and the base's metal meter filling behind it
## plays nothing. Not exercised here or in any scenario: housing_full (a trained head left waiting
## for room in the Hangars), offline_boot (the boot after a catch-up that finished something; a
## harness run boots a new base, so it plays boot_sting), and the settings' volumes and mute
## restored on a second boot (a run boots once).

const ARMY := {"ranger": 40, "hover_tank": 5}
## The defences whose shots and landings have sounds (Sounds.FIRE).
const MAPPED: Array[String] = ["laser_turret", "plasma_mortar", "missile_battery"]
## How long the battle may take to fire every mapped sound (seconds of real time, at 2x).
const BATTLE_WAIT := 40.0
## How many one-shots _play_every_key plays at once, well under the pool's voices.
const PLAY_BATCH := 8
const SCHEDULE: Array[StringName] = [&"select_building_core", &"ui_tap", &"impact_small"]
## How long a fade of the base's ambience takes to settle (main.BED_FADE and a margin), and the
## construction drone's first firing at the latest (seconds of real time).
const BED_SETTLE := 0.8
const LASER_WAIT := 8.0


func run(main: MainScript) -> void:
	var audio: Audio = main.audio
	await frames(2)
	check(audio.current_music() == &"base" and audio.music_playing(), "the base's music plays from boot")
	await _check_boot(main, audio)
	# The rest counts voices: the ambience's loop holds one, so it goes (main takes it as still on).
	audio.silence()
	_check_table(audio)
	_check_buses()
	await _play_every_key(audio)
	await _check_cooldown_and_cap(audio)
	await _check_loop(audio)
	await _check_schedule(main, audio)
	_check_music_and_settings(main, audio)
	await _measure_idle(main)
	await _check_hud(main, audio)
	await _check_toasts(main, audio)
	await _check_settings(main, audio)
	await _check_building(main, audio)
	await _check_battle(main, audio)


func _check_table(audio: Audio) -> void:
	var bad := PackedStringArray()
	for name: String in Sounds.TABLE:
		var key := StringName(name)
		var stream := audio.stream(key)
		var loops := bool(Sounds.TABLE[name].get("loop", false))
		if stream == null or stream.format != AudioStreamWAV.FORMAT_16_BITS or stream.mix_rate != 44100 or stream.stereo \
				or stream.get_length() < float(Sounds.field(key, "min")) or stream.get_length() > float(Sounds.field(key, "max")) \
				or (stream.loop_mode == AudioStreamWAV.LOOP_FORWARD) != loops:
			bad.append(name)
	check(bad.is_empty() and audio.keys().size() == Sounds.TABLE.size(),
		"every one of the %d keys loads as 16-bit 44.1 kHz mono within its bounds (bad: %s)"
		% [Sounds.TABLE.size(), ", ".join(bad)])


func _check_buses() -> void:
	var sends := PackedStringArray()
	for bus: StringName in Audio.BUSES:
		var index := AudioServer.get_bus_index(bus)
		if index < 0 or AudioServer.get_bus_send(index) != &"Master":
			sends.append(bus)
	check(sends.is_empty(), "SFX, UI and Music send to Master (wrong: %s)" % ", ".join(sends))
	var limited := false
	for i: int in AudioServer.get_bus_effect_count(0):
		limited = limited or AudioServer.get_bus_effect(0, i) is AudioEffectHardLimiter
	check(limited, "Master has its limiter")


## Every one-shot played once, PLAY_BATCH at a time with the pool gone quiet between batches, so a
## table of any size never fills the voices and no key is refused for room; counted per key, and
## the last of them (RECENT at most) in recent_plays in the order played.
func _play_every_key(audio: Audio) -> void:
	var refused := PackedStringArray()
	var played: Array[StringName] = []
	for key: StringName in audio.keys():
		if _loops(key):
			continue
		if played.size() % PLAY_BATCH == 0:
			await _settle(audio)
		var before := audio.play_count(key)
		if not audio.play(key, 0.06, -6.0) or audio.play_count(key) != before + 1:
			refused.append(key)
		played.append(key)
	check(refused.is_empty(), "every one of the %d one-shots played once (refused: %s)" % [played.size(), ", ".join(refused)])
	var recent := audio.recent_plays()
	say("recent plays: %s" % ", ".join(PackedStringArray(recent)))
	var last := mini(played.size(), Audio.RECENT)
	check(recent.slice(-last) == played.slice(-last), "the last %d of them are in recent_plays, in order" % last)
	await _quiet(audio)


func _check_cooldown_and_cap(audio: Audio) -> void:
	var before := audio.play_count(&"laser_fire")
	var played := 0
	for i: int in 100:
		if audio.play(&"laser_fire", 0.06, -12.0):
			played += 1
	check(played == 1 and audio.play_count(&"laser_fire") == before + 1 and audio.playing_count() == 1,
		"100 plays of one key in a frame sound once (%d played, %d voices)" % [played, audio.playing_count()])
	# Every one-shot but the stings, again and again, a frame apart, softly: the pool fills and
	# never overflows; then a sting, more important than any of them, still gets a voice.
	var most := 0
	for pass_index: int in 40:
		if pass_index > 0:
			await audio.get_tree().create_timer(0.05).timeout
		for key: StringName in audio.keys():
			if not _loops(key) and Sounds.TABLE[String(key)]["category"] != "sting":
				audio.play(key, 0.06, -18.0)
		most = maxi(most, audio.playing_count())
	check(most == Audio.VOICES, "a flood of plays fills the pool's %d voices and no more (%d at most)"
		% [Audio.VOICES, most])
	var full := audio.playing_count()
	check(full == Audio.VOICES and audio.play(&"victory", 0.0, -18.0) and audio.playing_count() == Audio.VOICES,
		"with the pool full (%d) a sting, more important than the rest, takes a voice" % full)
	await _quiet(audio)


func _check_loop(audio: Audio) -> void:
	var id := audio.loop(&"shield_hum")
	await audio.get_tree().create_timer(0.3).timeout
	check(id > 0 and audio.playing_count() == 1, "a loop starts (id %d, %d voices)" % [id, audio.playing_count()])
	await audio.get_tree().create_timer(2.2).timeout
	check(audio.playing_count() == 1, "it is still sounding past its file's length")
	audio.stop(id, 0.1)
	await audio.get_tree().create_timer(0.3).timeout
	check(audio.playing_count() == 0, "stop() fades it out and frees its voice")
	# A loop fading in, silenced: its fade must not go on over the next sound on its voice.
	audio.loop(&"shield_hum", 1.0)
	audio.silence()
	audio.play(&"impact_small", 0.0, -6.0)
	await audio.get_tree().create_timer(0.15).timeout
	var level := 0.0
	for node: Node in audio.get_children():
		var player := node as AudioStreamPlayer
		if player.playing and player.stream == audio.stream(&"impact_small"):
			level = player.volume_db
	check(is_equal_approx(level, -6.0), "silence() ends a loop's fade: the next sound plays at -6 dB (%.1f)" % level)
	await _quiet(audio)


func _check_schedule(main: MainScript, audio: Audio) -> void:
	var asked := Time.get_ticks_msec()
	for i: int in SCHEDULE.size():
		audio.schedule(SCHEDULE[i], 0.1 * (i + 1))
	check(audio.is_processing(), "a scheduled play turns the drain on")
	await main.get_tree().create_timer(0.5).timeout
	var keys := audio.recent_plays().slice(-SCHEDULE.size())
	var times := audio.recent_times().slice(-SCHEDULE.size())
	var offsets := PackedInt64Array()
	for time: int in times:
		offsets.append(time - asked)
	say("scheduled plays at %s ms" % [offsets])
	var on_time := true
	for i: int in offsets.size():
		on_time = on_time and absi(offsets[i] - 100 * (i + 1)) <= 50
	check(keys == SCHEDULE and on_time, "three scheduled plays sound in order, 0.1 s apart (%s at %s ms)"
		% [", ".join(PackedStringArray(keys)), offsets])
	check(not audio.is_processing(), "the drain turns off once nothing waits")
	# A play due soon behind one due later is retired when it plays, not when the later one does.
	audio.schedule(&"ui_tap", 0.4)
	audio.schedule(&"select_building_core", 0.05)
	await main.get_tree().create_timer(0.2).timeout
	check(audio.scheduled_count() == 1 and audio.recent_plays()[-1] == &"select_building_core",
		"a due play behind a later one is played and retired (%d waiting)" % audio.scheduled_count())
	await main.get_tree().create_timer(0.4).timeout
	check(audio.scheduled_count() == 0 and not audio.is_processing(), "the later one plays in its turn")


func _check_music_and_settings(main: MainScript, audio: Audio) -> void:
	check(not audio.music(&"no_such_track") and audio.current_music() == &"", "a missing track is refused")
	check(audio.music(&"base") and audio.current_music() == &"base" and audio.music_playing(),
		"music(&\"base\") starts the base's track")
	check(audio.settings_path == main.save_path.get_base_dir().path_join("settings.cfg"),
		"the settings sit beside the run's own save: %s" % audio.settings_path)
	audio.set_volume(&"Music", 0.5)
	var config := ConfigFile.new()
	var loaded := config.load(audio.settings_path)
	check(loaded == OK and is_equal_approx(float(config.get_value(Audio.SETTINGS_SECTION, "Music", 0.0)), 0.5)
		and is_equal_approx(audio.volume(&"Music"), 0.5), "a volume is set and kept in the settings file")
	audio.set_volume(&"Music", 1.0)


func _measure_idle(main: MainScript) -> void:
	Profile.enabled = true
	Profile.take()
	var count := 0
	var until := Time.get_ticks_msec() + 1000
	while Time.get_ticks_msec() < until:
		await frames(1)
		count += 1
	var spent: Vector2i = Profile.take().get(&"audio", Vector2i.ZERO)
	Profile.enabled = false
	var ms := spent.x / 1000.0 / maxi(count, 1)
	say("Audio idle: %.4f ms a frame over %d frames (%d plays)" % [ms, count, spent.y])
	check(not main.audio.is_processing() and main.audio.playing_count() == 0,
		"idle, Audio does no work a frame: no _process, no voice sounding")


## The boot's sting, once, and the base's ambience: looping from the first frame, faded in, ducked
## 8 dB under the build panel and back when it closes.
func _check_boot(main: MainScript, audio: Audio) -> void:
	check(audio.play_count(&"boot_sting") + audio.play_count(&"offline_boot") == 1,
		"the boot played its sting once (boot_sting %d, offline_boot %d)"
		% [audio.play_count(&"boot_sting"), audio.play_count(&"offline_boot")])
	var bed := main.ambience()
	await main.get_tree().create_timer(BED_SETTLE).timeout
	check(bed > 0 and is_equal_approx(audio.loop_level(bed), 1.0),
		"the base's ambience loops from boot, faded in (level %.2f)" % audio.loop_level(bed))
	main.hud.build_button().pressed.emit()
	await main.get_tree().create_timer(BED_SETTLE).timeout
	check(main.ambience() == bed and absf(audio.loop_level(bed) - db_to_linear(-8.0)) < 0.01,
		"under the open build panel it is ducked 8 dB (level %.2f)" % audio.loop_level(bed))
	main.hud.close_button().pressed.emit()
	await main.get_tree().create_timer(BED_SETTLE).timeout
	check(is_equal_approx(audio.loop_level(bed), 1.0), "the panel closed, it is back (level %.2f)" % audio.loop_level(bed))


func _check_hud(main: MainScript, audio: Audio) -> void:
	var before := heard_counts(main)
	await tap_screen(main, main.hud.build_button().get_global_rect().get_center())
	await main.get_tree().create_timer(Hud.MENU_OPEN_SECONDS + 0.05).timeout
	check(main.hud.is_menu_open(), "Build tapped: the panel opens")
	check_heard(main, before, &"ui_tap", 1, "Build tapped")
	check_heard(main, before, &"ui_open", 1, "Build tapped")
	await screenshot("menu-open")
	await audio.get_tree().create_timer(0.1).timeout
	before = heard_counts(main)
	await tap_screen(main, main.hud.close_button().get_global_rect().get_center())
	await main.get_tree().create_timer(Hud.MENU_OPEN_SECONDS + 0.05).timeout
	check(not main.hud.is_menu_open(), "Close tapped: the panel closes")
	check_heard(main, before, &"ui_tap_soft", 1, "Close tapped")
	check_heard(main, before, &"ui_close", 1, "Close tapped")


## Each toast kind's sound (a refusal's ui_denied), and the refusal's buzz once in a frame however
## many ask for it: a disabled card's press lifted and a refusal's toast together.
func _check_toasts(main: MainScript, audio: Audio) -> void:
	var hud: Hud = main.hud
	var kinds := {Hud.ToastKind.INFO: &"toast_info", Hud.ToastKind.REFUSAL: &"ui_denied", Hud.ToastKind.REWARD: &"toast_reward"}
	for kind: Hud.ToastKind in kinds:
		var before := heard_counts(main)
		hud.show_message("A toast", kind)
		check_heard(main, before, kinds[kind], 1, "a %s toast" % Hud.ToastKind.keys()[kind])
		await main.get_tree().create_timer(0.1).timeout
	await open_build_menu(main)
	var locked := ""
	for type: String in main.catalog.menu_order:
		if hud.entry_button(type).disabled:
			locked = type
			break
	check(locked != "", "a card is disabled: %s" % locked)
	if locked == "":
		return
	var card := hud.entry_button(locked)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.global_position = card.get_global_rect().get_center()
	press.pressed = true
	var before := heard_counts(main)
	card.gui_input.emit(press)
	var lift := press.duplicate() as InputEventMouseButton
	lift.pressed = false
	card.gui_input.emit(lift)
	hud.show_error(BaseState.ERR_FUNDS)
	check_heard(main, before, &"ui_denied", 1, "a disabled card lifted and a refusal toast in one frame")
	await main.get_tree().create_timer(0.1).timeout
	before = heard_counts(main)
	card.gui_input.emit(press)
	lift.global_position += Vector2(40, 0)
	card.gui_input.emit(lift)
	check_heard(main, before, &"ui_denied", 0, "a drag off a disabled card")
	hud.close_button().pressed.emit()
	await wait_seconds(main, Hud.MENU_CLOSE_SECONDS)


## The gear opens the settings panel on Audio's volumes; its sliders set the buses as they move
## and keep them when let go, the Sound slider both SFX and UI; the mute takes Master to 0 and
## gives it back; the close keeps them, and the panel opens again on them. The volumes are put back.
func _check_settings(main: MainScript, audio: Audio) -> void:
	var hud: Hud = main.hud
	var before := heard_counts(main)
	await tap_screen(main, hud.gear_button().get_global_rect().get_center())
	check(hud.settings_open(), "the gear opened the settings panel")
	check_heard(main, before, &"ui_tap_soft", 1, "the gear tapped")
	check_heard(main, before, &"ui_open", 1, "the gear tapped")
	check(hud.settings_values() == {"music": 100, "sound": 100, "mute": false},
		"it shows the volumes: %s" % hud.settings_values())
	hud.music_slider().value = 40
	hud.sound_slider().value = 70
	check(is_equal_approx(audio.volume(&"Music"), 0.4) and is_equal_approx(audio.volume(&"SFX"), 0.7)
		and is_equal_approx(audio.volume(&"UI"), 0.7), "the sliders set Music to %.2f, SFX and UI to %.2f and %.2f"
		% [audio.volume(&"Music"), audio.volume(&"SFX"), audio.volume(&"UI")])
	before = heard_counts(main)
	hud.sound_slider().drag_ended.emit(true)
	check_heard(main, before, &"ui_tap", 1, "the Sound slider let go plays a tap at its level")
	var config := ConfigFile.new()
	config.load(audio.settings_path)
	check(is_equal_approx(float(config.get_value(Audio.SETTINGS_SECTION, "SFX", 0.0)), 0.7)
		and is_equal_approx(float(config.get_value(Audio.SETTINGS_SECTION, "Music", 0.0)), 0.4),
		"let go, the volumes are kept in the settings file")
	hud.mute_button().button_pressed = true
	check(audio.is_muted() and audio.volume(&"Master") == 0.0, "Mute takes Master to 0")
	hud.mute_button().button_pressed = false
	check(not audio.is_muted() and is_equal_approx(audio.volume(&"Master"), 1.0), "unmuted, Master is back at %.2f"
		% audio.volume(&"Master"))
	await screenshot("settings")
	await frames(6)
	before = heard_counts(main)
	await tap_screen(main, hud.settings_close_button().get_global_rect().get_center())
	check(not hud.settings_open(), "the close button closed the panel")
	check_heard(main, before, &"ui_close", 1, "the settings closed")
	await main.get_tree().create_timer(0.1).timeout
	hud.gear_button().pressed.emit()
	check(hud.settings_values() == {"music": 40, "sound": 70, "mute": false},
		"opened again, it shows what was set: %s" % hud.settings_values())
	hud.music_slider().value = 100
	hud.sound_slider().value = 100
	hud.settings_close_button().pressed.emit()
	check(not hud.settings_open() and is_equal_approx(audio.volume(&"Music"), 1.0) and is_equal_approx(audio.volume(&"UI"), 1.0),
		"the volumes are put back")


func _check_building(main: MainScript, audio: Audio) -> void:
	var state: BaseState = main.state
	var cc: BuildingState = null
	for id: int in state.buildings:
		cc = state.buildings[id]
		break
	var select := Sounds.select_key(state.catalog.category_of(cc.type))
	var before := heard_counts(main)
	tap_cell(main, cc.cell)
	await frames(2)
	check(main.placement.selected_id == cc.id, "a building tapped is selected")
	check_heard(main, before, select, 1, "the %s tapped" % cc.type)
	await audio.get_tree().create_timer(0.1).timeout
	tap_cell(main, cc.cell)
	await frames(2)
	check(main.placement.selected_id == cc.id, "tapped again, it stays selected")
	check_heard(main, before, select, 1, "the selected building tapped again: no more")
	main.placement.select(0)
	# On the real numbers, a construction long enough for its drone to fire.
	before = heard_counts(main)
	main.placement.begin_place("metal_extractor")
	main.placement.confirm_place()
	check_heard(main, before, &"place_ok", 1, "a metal_extractor placed")
	var extractor := state.last_added_id
	var until := Time.get_ticks_msec() + int(LASER_WAIT * 1000.0)
	while audio.play_count(&"laser_work") == int(before[&"laser_work"]) and Time.get_ticks_msec() < until:
		await frames(1)
	check_heard(main, before, &"laser_work", 1, "its drone fired")
	# Built, the extractor fills the metal meter in time.
	advance(state.seconds_left(extractor))
	await frames(2)
	before = heard_counts(main)
	var hours := 0
	while state.resources["metal"] < state.capacity("metal") and hours < 1000:
		advance(3600)
		hours += 1
	await frames(2)
	check_heard(main, before, &"meter_full", 1, "the metal meter filled after %d h" % hours)
	main.placement.select(0)
	main.catalog.apply_dev_cheats()
	# The Command Center's upgrade (the extractor's next level waits for it).
	before = heard_counts(main)
	var refused := state.check_upgrade(cc.id)
	main.placement.select(cc.id)
	main.placement.upgrade_selected()
	check(state.buildings[cc.id].is_busy(), "the Command Center's upgrade started ('%s')" % refused)
	check_heard(main, before, &"build_start", 1, "an upgrade started")
	# Past the chime's cooldown, which the extractor's finish started.
	await main.get_tree().create_timer(0.2).timeout
	advance(state.seconds_left(cc.id))
	await frames(3)
	check_heard(main, before, &"build_done", 1, "its construction finished")
	main.placement.select(0)


func _check_battle(main: MainScript, audio: Audio) -> void:
	# A Cadet Academy built (the dev cheats still on: one second), for an army panel to open over.
	var state: BaseState = main.state
	main.placement.begin_place("cadet_academy")
	main.placement.confirm_place()
	var academy := state.last_added_id
	advance(1)
	await frames(2)
	# A construction under way finishes while the battle runs.
	var type := ""
	for menu_type: String in state.catalog.menu_order:
		if int(state.catalog.level_stats(menu_type, 1).get("build_seconds", 0)) > 0 \
				and state.check_can_build(menu_type) == "":
			type = menu_type
			break
	main.placement.begin_place(type)
	main.placement.confirm_place()
	main.placement.select(0)
	await frames(2)
	# The academy's training panel open as the battle opens; the metal meter short of full.
	main.placement.select(academy)
	await frames(2)
	main.hud.action_button().pressed.emit()
	await wait_seconds(main, Hud.MENU_OPEN_SECONDS)
	check(main.hud.is_training_open(), "the academy's training panel is open")
	state.resources["metal"] = state.capacity("metal") - 100
	await frames(2)
	var setup := main.practice_setup()
	# Only the mapped defences and the Command Center stand, where the template has them: in the
	# whole template the laser turrets sit deep inside and seldom fire.
	var kept: Array[Dictionary] = []
	for building: Dictionary in setup["defender"]["buildings"]:
		if MAPPED.has(building["type"]) or building["type"] == "command_center":
			kept.append(building)
	setup["defender"]["buildings"] = kept
	setup["attacker"] = {"army": ARMY, "unit_levels": {}, "abilities": {}, "ability_levels": {}}
	var heard := heard_counts(main)
	var error := main.open_battle(setup, true)
	check(error == "", "the practice battle opens: '%s'" % error)
	check_heard(main, heard, &"ui_close", 0, "the battle opened over the training panel")
	if error != "":
		return
	var view: BattleView = main.battle
	view.speed = 2
	check(audio.current_music() == &"combat" and audio.music_playing(), "the battle opens on the combat track")
	await frames(2)
	check(main.ambience() == 0, "the base's ambience stops for the battle")
	var dones := audio.play_count(&"build_done")
	advance(1)
	await frames(3)
	check(audio.play_count(&"build_done") == dones and main.state.buildings[main.state.last_added_id].level == 1,
		"a construction finishing while the battle runs plays nothing")
	# Its drone, handed to the base's view out of the tree, stays over the site in the view's frame.
	var built: BuildingState = main.state.buildings[main.state.last_added_id]
	var site := main.base_view.cell_to_world(built.cell, main.catalog.size_of(built.type))
	var released: ConstructionDrone = null
	for child: Node in main.base_view.get_children():
		if child is ConstructionDrone:
			released = child
	check(released != null and released.position.distance_to(site) < 0.01,
		"the finished site's drone, released out of the tree, sits over it (%s at %s)"
		% [released.position if released != null else Vector3.INF, site])
	# The base ticks on behind the battle: its metal meter fills there, unheard.
	heard = heard_counts(main)
	advance(3600)
	await frames(3)
	var metal := (main.hud.resource_fill("metal").get_child(0) as CanvasItem).material as ShaderMaterial
	check(bool(metal.get_shader_parameter(&"full")), "the metal meter filled while the battle ran")
	check_heard(main, heard, &"meter_full", 0, "the metal meter filling while the battle runs")
	# The army lands as near the laser turrets as the deploy zone lets it, so they fire soon.
	var near: Array[Vector2i] = []
	for building: Dictionary in setup["defender"]["buildings"]:
		if building["type"] == "laser_turret":
			near.append(Vector2i(int(building["cell"][0]), int(building["cell"][1])))
	var spots: Array[Vector2i] = []
	for reach: int in range(2, 12):
		for turret: Vector2i in near:
			for dx: int in range(-reach, reach + 1):
				for dy: int in [-reach, reach]:
					spots.append(turret + Vector2i(dx, dy))
					spots.append(turret + Vector2i(dy, dx))
	var deployed := 0
	for unit: String in ARMY:
		for i: int in int(ARMY[unit]):
			while not spots.is_empty():
				var spot: Vector2i = spots.pop_front()
				if view.deploy(unit, spot) == "":
					deployed += 1
					break
	say("%d units deployed beside %d laser turrets" % [deployed, near.size()])
	var counts := {}
	for key: StringName in [&"laser_fire", &"impact_small", &"shell_fire", &"missile_fire", &"explosion_medium",
			&"victory", &"defeat"]:
		counts[key] = audio.play_count(key)
	Profile.enabled = true
	Profile.take()
	var frame_count := 0
	var until := Time.get_ticks_msec() + int(BATTLE_WAIT * 1000.0)
	while Time.get_ticks_msec() < until and not view.sim.is_over():
		await frames(1)
		frame_count += 1
		if audio.play_count(&"laser_fire") > int(counts[&"laser_fire"]) + 5 \
				and audio.play_count(&"impact_small") > int(counts[&"impact_small"]) + 5 \
				and audio.play_count(&"explosion_medium") > int(counts[&"explosion_medium"]):
			break
	var spent: Vector2i = Profile.take().get(&"audio", Vector2i.ZERO)
	Profile.enabled = false
	say("Audio in battle: %.4f ms a frame over %d frames (%d plays), %d voices sounding"
		% [spent.x / 1000.0 / maxi(frame_count, 1), frame_count, spent.y, audio.playing_count()])
	await screenshot("battle")
	var gained := PackedStringArray()
	for key: StringName in counts:
		gained.append("%s +%d" % [key, audio.play_count(key) - int(counts[key])])
	say("battle plays: %s" % ", ".join(gained))
	check(audio.play_count(&"laser_fire") > int(counts[&"laser_fire"])
		and audio.play_count(&"impact_small") > int(counts[&"impact_small"]),
		"the laser turrets' shots and their hits sound")
	check(audio.play_count(&"explosion_medium") > int(counts[&"explosion_medium"]),
		"a mortar's or a missile's landing sounds")
	var finished := [false]
	view.finished.connect(func(_setup: Dictionary, _result: Dictionary) -> void: finished[0] = true)
	view.surrender()
	while not view.sim.is_over():
		await frames(1)
	await frames(2)
	var stings := audio.play_count(&"victory") + audio.play_count(&"defeat") \
		- int(counts[&"victory"]) - int(counts[&"defeat"])
	check(stings == 1, "the battle's end plays one sting (%d)" % stings)
	view.leave()
	while not finished[0]:
		await frames(1)
	check(audio.current_music() == &"base" and audio.music_playing(), "back on the base, the base's track again")
	await frames(2)
	check(main.ambience() > 0, "back on the base, its ambience again")


## Waits until no voice of the pool sounds, three seconds at most (every key here is shorter).
func _settle(audio: Audio) -> void:
	var until := Time.get_ticks_msec() + 3000
	while audio.playing_count() > 0 and Time.get_ticks_msec() < until:
		await frames(1)


## Waits until no voice sounds (every key here is shorter than two seconds).
func _quiet(audio: Audio) -> void:
	var until := Time.get_ticks_msec() + 3000
	while audio.playing_count() > 0 and Time.get_ticks_msec() < until:
		await frames(1)
	check(audio.playing_count() == 0, "the pool falls quiet")


static func _loops(key: StringName) -> bool:
	return bool(Sounds.TABLE[String(key)].get("loop", false))
