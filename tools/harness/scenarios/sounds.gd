extends HarnessScenario
## The sounds (docs/reference/audio.md): every key in Sounds.TABLE loaded as a 16-bit 44.1 kHz mono
## stream of the length its bounds allow, looping as its recipe says; the buses and the limiter;
## every key played once and recorded; one key played 100 times in a frame sounding once; a flood
## of plays never past the pool's voices, a sting still getting one; a loop held and stopped, and a
## loop's fade ended by silence(); three scheduled plays sounding in order, and a due play retired
## behind one still waiting; a missing track refused; a volume kept in the run's own settings file;
## no work a frame idle. Then the hooks: Build and Close tapped (ui_tap, ui_open, ui_close), a
## building tapped (select_building) and tapped again (nothing), a building placed and finished
## (build_start, build_done), another finishing during a practice battle (nothing), and the battle
## against the template base's mapped defences (laser_fire and impact_small, the shells and missiles
## when they come, and a sting at the end), with Audio's cost a frame from Profile. Plays are
## recorded whatever the device, so the checks hold on run.sh's Dummy audio driver; a rendered run
## with --audible plays them aloud.

const ARMY := {"ranger": 40, "hover_tank": 5}
## The defences whose shots and landings have sounds (Sounds.FIRE).
const MAPPED: Array[String] = ["laser_turret", "plasma_mortar", "missile_battery"]
## How long the battle may take to fire every mapped sound (seconds of real time, at 2x).
const BATTLE_WAIT := 40.0
const SCHEDULE: Array[StringName] = [&"select_building", &"ui_tap", &"impact_small"]


func run(main: MainScript) -> void:
	var audio: Audio = main.audio
	await frames(2)
	_check_table(audio)
	_check_buses()
	await _play_every_key(audio)
	await _check_cooldown_and_cap(audio)
	await _check_loop(audio)
	await _check_schedule(main, audio)
	_check_music_and_settings(main, audio)
	await _measure_idle(main)
	await _check_hud(main, audio)
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


func _play_every_key(audio: Audio) -> void:
	var refused := PackedStringArray()
	var keys := audio.keys()
	for key: StringName in keys:
		if _loops(key):
			continue
		if not audio.play(key, 0.06, -6.0) or audio.play_count(key) != 1:
			refused.append(key)
		await frames(1)
	check(refused.is_empty(), "every one-shot played once (refused: %s)" % ", ".join(refused))
	var recent := audio.recent_plays()
	say("recent plays: %s" % ", ".join(PackedStringArray(recent)))
	check(recent.size() == keys.size() - 1, "each is in recent_plays (%d)" % recent.size())
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
	audio.schedule(&"select_building", 0.05)
	await main.get_tree().create_timer(0.2).timeout
	check(audio.scheduled_count() == 1 and audio.recent_plays()[-1] == &"select_building",
		"a due play behind a later one is played and retired (%d waiting)" % audio.scheduled_count())
	await main.get_tree().create_timer(0.4).timeout
	check(audio.scheduled_count() == 0 and not audio.is_processing(), "the later one plays in its turn")


func _check_music_and_settings(main: MainScript, audio: Audio) -> void:
	check(not audio.music(&"no_such_track") and audio.current_music() == &"", "a missing track is refused")
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


func _check_hud(main: MainScript, audio: Audio) -> void:
	var taps := audio.play_count(&"ui_tap")
	var opens := audio.play_count(&"ui_open")
	var closes := audio.play_count(&"ui_close")
	await tap_screen(main, main.hud.build_button().get_global_rect().get_center())
	await main.get_tree().create_timer(Hud.MENU_OPEN_SECONDS + 0.05).timeout
	check(main.hud.is_menu_open() and audio.play_count(&"ui_tap") == taps + 1 and audio.play_count(&"ui_open") == opens + 1,
		"Build tapped: ui_tap and ui_open")
	await screenshot("menu-open")
	await audio.get_tree().create_timer(0.1).timeout
	await tap_screen(main, main.hud.close_button().get_global_rect().get_center())
	await main.get_tree().create_timer(Hud.MENU_OPEN_SECONDS + 0.05).timeout
	check(not main.hud.is_menu_open() and audio.play_count(&"ui_tap") == taps + 2
		and audio.play_count(&"ui_close") == closes + 1, "Close tapped: ui_tap and ui_close")


func _check_building(main: MainScript, audio: Audio) -> void:
	var state: BaseState = main.state
	var cc: BuildingState = null
	for id: int in state.buildings:
		cc = state.buildings[id]
		break
	var selects := audio.play_count(&"select_building")
	tap_cell(main, cc.cell)
	await frames(2)
	check(main.placement.selected_id == cc.id and audio.play_count(&"select_building") == selects + 1,
		"a building tapped: select_building")
	await audio.get_tree().create_timer(0.1).timeout
	tap_cell(main, cc.cell)
	await frames(2)
	check(main.placement.selected_id == cc.id and audio.play_count(&"select_building") == selects + 1,
		"the selected building tapped again: no sound")
	main.placement.select(0)
	main.catalog.apply_dev_cheats()
	var type := ""
	for menu_type: String in state.catalog.menu_order:
		if int(state.catalog.level_stats(menu_type, 1).get("build_seconds", 0)) > 0 \
				and state.check_can_build(menu_type) == "":
			type = menu_type
			break
	var starts := audio.play_count(&"build_start")
	main.placement.begin_place(type)
	main.placement.confirm_place()
	check(audio.play_count(&"build_start") == starts + 1, "a %s placed: build_start" % type)
	await frames(2)
	var dones := audio.play_count(&"build_done")
	advance(1)
	await frames(3)
	check(audio.play_count(&"build_done") == dones + 1, "its construction finished: build_done")
	main.placement.select(0)


func _check_battle(main: MainScript, audio: Audio) -> void:
	# A construction under way (the dev cheats still on: one second) finishes while the battle runs.
	var state: BaseState = main.state
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
	var setup := main.practice_setup()
	# Only the mapped defences and the Command Center stand, where the template has them: in the
	# whole template the laser turrets sit deep inside and seldom fire.
	var kept: Array[Dictionary] = []
	for building: Dictionary in setup["defender"]["buildings"]:
		if MAPPED.has(building["type"]) or building["type"] == "command_center":
			kept.append(building)
	setup["defender"]["buildings"] = kept
	setup["attacker"] = {"army": ARMY, "unit_levels": {}, "abilities": {}, "ability_levels": {}}
	var error := main.open_battle(setup, true)
	check(error == "", "the practice battle opens: '%s'" % error)
	if error != "":
		return
	var view: BattleView = main.battle
	view.speed = 2
	var dones := audio.play_count(&"build_done")
	advance(1)
	await frames(3)
	check(audio.play_count(&"build_done") == dones and main.state.buildings[main.state.last_added_id].level == 1,
		"a construction finishing while the battle runs plays nothing")
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


## Waits until no voice sounds (every key here is shorter than two seconds).
func _quiet(audio: Audio) -> void:
	var until := Time.get_ticks_msec() + 3000
	while audio.playing_count() > 0 and Time.get_ticks_msec() < until:
		await frames(1)
	check(audio.playing_count() == 0, "the pool falls quiet")


static func _loops(key: StringName) -> bool:
	return bool(Sounds.TABLE[String(key)].get("loop", false))
