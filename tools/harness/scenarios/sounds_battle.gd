extends HarnessScenario
## The battle's sounds (docs/reference/audio.md, **Battle**). First the coverage, from the tables
## alone: every type in Weapons has a shot and a landing key (or an explicit &""), every
## Weapons.Kind, Impact and Death and every trap kind has an entry in Sounds' maps, every kind of
## BattleEvents an entry in Sounds.EVENTS, and every key any of them names is in the table.
##
## Then a practice battle against the template base trimmed to one of each defence and trap, the
## Command Center and the walls beside them (the whole template keeps its defences deep inside, where
## a short battle never reaches them), attacked by every unit type with every ability: the army is
## deployed in groups beside each defence and each trap, the abilities cast on them, the speed
## toggled, End asked and kept, a deploy refused; then the battle runs to its end (surrendered when
## every sound has been heard first). Checked through Audio's counts and the view's loops: each
## defence's shot and landing, each unit's shot (or its landing when its shot is silent), a wall's
## crumble, a collapse and its rubble, a death of each kind and its blast, each trap's click and its
## own sound, the mega mine's blast TRAP_POP after it springs (real time at the battle's speed), the
## shield's rise, hits and fall, the EMP's burst and wakes, the swarm, the strike's marker, bolt and
## landing, the deploys of both classes, a chime for each star won, the HUD's clicks and the sting;
## the loops (the bed, the engines, the shield's hum, the well's, the EMP's crackle, the swarm's,
## the marker, the grav trap's whoosh) started; at the end only the bed held, and after Return no
## voice sounding but the base's own bed (main.ambience) and nothing scheduled. Last, a second
## battle: a strike cast, its whine scheduled, then a surrender: nothing waits on the result panel,
## and the whine is never heard there or after Return. Audio's cost a frame over the battle comes
## from Profile. Headless or rendered; the rendered run's shots show the battle under way
## (SHOT_TICK) and its result.
## Unchecked: timer_warning, which needs a battle's last ten seconds and this one ends long before.

const DEFENCES: Array[String] = ["laser_turret", "missile_battery", "plasma_mortar", "flak_cannon", "arc_tower",
	"cloaked_sentry", "gravity_well", "emp_tower", "railgun", "ion_beam", "orbital_cannon", "shield_generator"]
const TRAPS: Array[String] = ["proximity_mine", "flak_mine", "mega_mine", "grav_trap"]
const ARMY := {"ranger": 40, "breacher": 10, "jet_trooper": 16, "brawler": 16, "dune_runner": 8, "skimmer": 8,
	"siege_walker": 6, "hover_tank": 6, "titan": 3, "gunship": 6, "bomber": 4}
const ABILITIES := {"repair_swarm": 2, "emp_burst": 2, "orbital_strike": 2}
## Each trap moved beside the defence its army group attacks, so the group springs it: the ground
## ones by the railgun, the flak mine by the missile battery, which the aircraft attack.
const TRAP_HOSTS := {"proximity_mine": "railgun", "grav_trap": "railgun", "mega_mine": "railgun",
	"flak_mine": "missile_battery"}
## No group is deployed beside these: a group there fells the missile battery before its first
## salvo; the army reaches it from its neighbours, the aircraft over the flak mine on the way.
const UNGUARDED: Array[String] = ["missile_battery"]
## Walls kept: those within this many cells of a kept building's footprint.
const WALL_REACH := 2
## How long the battle may take to sound everything (seconds of real time, at 2x).
const BATTLE_WAIT := 150.0
## How long after Return every voice must have fallen quiet (seconds).
const QUIET_WAIT := 3.0
## The trap blast's lag behind its spring, seen the frame its mine is gone (TRAP_POP at the battle's
## speed), give or take a frame or two of the scenario's and the drain's (ms).
const POP_SLACK_MS := 40
## How long on the result panel the dropped strike's whine must stay unheard: past its time (the
## strike's 1.5 s at 1x, less STRIKE_WHINE).
const DROP_WAIT := 2.0
## The tick the battle is shot at, under way.
const SHOT_TICK := 200


## The mega mine's id; when it was seen gone and the frame before (ms, -1 until then), so it sprang
## between the two; its blasts so far; and the first blast's lag behind each of the two (ms).
var _mega := 0
var _sprang_at := -1
var _sprang_after := -1
var _watched_at := -1
var _megas := 0
var _pops := PackedInt64Array()


func run(main: MainScript) -> void:
	await frames(2)
	_check_coverage()
	await _check_battle(main, main.audio)
	await _check_dropped(main, main.audio)


func _check_coverage() -> void:
	var bad := PackedStringArray()
	for type: String in Weapons.TABLE:
		for key: StringName in [Sounds.fire_key(type), Sounds.land_key(type)]:
			if key != &"" and not Sounds.TABLE.has(String(key)):
				bad.append("%s: %s" % [type, key])
	check(bad.is_empty(), "every Weapons type's shot and landing is a key in the table or &\"\" (bad: %s)"
		% ", ".join(bad))
	var missing := PackedStringArray()
	for kind: int in Weapons.Kind.values():
		if not Sounds.FIRE_KIND.has(kind):
			missing.append("Kind %s" % Weapons.Kind.keys()[kind])
	for impact: int in Weapons.Impact.values():
		if not Sounds.LAND_IMPACT.has(impact):
			missing.append("Impact %s" % Weapons.Impact.keys()[impact])
	for death: int in Weapons.Death.values():
		if not Sounds.DEATH.has(death) or not Sounds.DEATH_END.has(death):
			missing.append("Death %s" % Weapons.Death.keys()[death])
	for trap: String in TRAPS:
		if not Sounds.TRAP.has(Weapons.of(trap).kind):
			missing.append("trap %s" % trap)
	var kinds := 0
	var constants := (load("res://src/core/battle/battle_events.gd") as Script).get_script_constant_map()
	for name: String in constants:
		var value: Variant = constants[name]
		if name == "START_CAPACITY" or typeof(value) != TYPE_INT:
			continue
		kinds += 1
		if not Sounds.EVENTS.has(value):
			missing.append("event %s" % name)
	check(missing.is_empty(), "every Kind, Impact, Death, trap and the %d event kinds are mapped (missing: %s)"
		% [kinds, ", ".join(missing)])
	var unknown := PackedStringArray()
	var named: Array[StringName] = [Sounds.TRAP_SPRING]
	for map: Dictionary in [Sounds.FIRE_KIND, Sounds.FIRE, Sounds.LAND_IMPACT, Sounds.LAND, Sounds.DEATH, Sounds.DEATH_END,
			Sounds.TRAP]:
		for key: Variant in map.values():
			named.append(key)
	for keys: Variant in Sounds.EVENTS.values():
		for key: Variant in keys:
			named.append(key)
	for key: StringName in named:
		if key != &"" and not Sounds.TABLE.has(String(key)):
			unknown.append(key)
	check(unknown.is_empty(), "every key the maps name is in the table (unknown: %s)" % ", ".join(unknown))


func _check_battle(main: MainScript, audio: Audio) -> void:
	var setup := main.practice_setup()
	var kept: Array[Dictionary] = []
	var seen := {}
	for building: Dictionary in setup["defender"]["buildings"]:
		var type: String = building["type"]
		if (DEFENCES.has(type) or TRAPS.has(type) or type == "command_center") and not seen.has(type):
			seen[type] = true
			kept.append(building)
	# The buildings the shield generator's bubble holds, so its pool has something to absorb for.
	var shield := Vector2.ZERO
	for building: Dictionary in kept:
		if building["type"] == "shield_generator":
			shield = _centre(main, building)
	var reach := float(main.catalog.level_stats("shield_generator", 1).get("range_cells", 0))
	for building: Dictionary in setup["defender"]["buildings"]:
		var type := str(building["type"])
		if not kept.has(building) and not TRAPS.has(type) and main.catalog.battle_class(type) != Catalog.CLASS_WALL \
				and _centre(main, building).distance_to(shield) <= reach:
			kept.append(building)
	var walls := 0
	for building: Dictionary in setup["defender"]["buildings"]:
		if main.catalog.battle_class(str(building["type"])) == Catalog.CLASS_WALL and _beside(main, building, kept):
			kept.append(building)
			walls += 1
	var absent := PackedStringArray()
	for type: String in DEFENCES + TRAPS:
		if not seen.has(type):
			absent.append(type)
	check(absent.is_empty(), "the template has one of each defence and trap (absent: %s)" % ", ".join(absent))
	say("kept %d buildings, %d of them walls" % [kept.size(), walls])
	_place_traps(main, kept)
	setup["defender"]["buildings"] = kept
	setup["attacker"] = {"army": ARMY, "unit_levels": {}, "abilities": ABILITIES, "ability_levels": {}}
	var counts := {}
	for key: String in Sounds.TABLE:
		counts[StringName(key)] = audio.play_count(StringName(key))
	var error := main.open_battle(setup, true)
	check(error == "", "the practice battle opens: '%s'" % error)
	if error != "":
		return
	var view: BattleView = main.battle
	var hud: BattleHud = main.battle_hud
	check(audio.play_count(&"battle_start") == int(counts[&"battle_start"]) + 1, "the battle opens with battle_start")
	await frames(2)
	check(view.loops_held().has(&"battle_bed") and view.loop_starts(&"shield_hum") == 1,
		"the bed and the shield's hum hold from the start (%s)" % [view.loops_held()])
	# The speed toggled up to 2x; End asked and kept.
	hud.speed_button().pressed.emit()
	check(view.speed == 2 and audio.play_count(&"speed_toggle") > int(counts[&"speed_toggle"]), "speed 2x: speed_toggle")
	hud.end_button().pressed.emit()
	check(hud.is_confirm_open() and audio.play_count(&"confirm_open") > int(counts[&"confirm_open"]),
		"End asks: confirm_open")
	hud.keep_button().pressed.emit()
	# A tap on a defence's cell with a type selected: refused, with its toast's sound.
	view.select_unit("ranger")
	var blocked := _cell(kept[0])
	view.input.tapped.emit(main.camera.unproject_position(view.field.cell_to_world(blocked, 1)))
	await frames(1)
	check(audio.play_count(&"ui_denied") > int(counts[&"ui_denied"]),
		"a deploy refused on %s: ui_denied ('%s')" % [blocked, hud.toast_text()])
	view.select_unit("")
	# From here on, every frame watches for the mega mine springing and its blast (_watch_mega).
	for building: Dictionary in kept:
		if building["type"] == "mega_mine":
			_mega = BattleMath.whole(building["id"])
	_megas = audio.play_count(&"mega_blast")
	_watch_mega(view, audio)
	# The army in groups beside every defence and trap, round the types.
	var left := ARMY.duplicate()
	var deployed := 0
	var types: Array = ARMY.keys()
	var turn := 0
	for building: Dictionary in kept:
		var type: String = building["type"]
		if not (DEFENCES.has(type) or TRAPS.has(type)) or UNGUARDED.has(type):
			continue
		var spots := _spots(main, building)
		for k: int in 8:
			var unit := ""
			for tries: int in types.size():
				var candidate: String = types[(turn + tries) % types.size()]
				if int(left[candidate]) > 0:
					unit = candidate
					turn = (turn + tries + 1) % types.size()
					break
			if unit == "":
				break
			while not spots.is_empty():
				if view.deploy(unit, spots.pop_front()) == "":
					left[unit] = int(left[unit]) - 1
					deployed += 1
					break
	say("%d units deployed beside %d defences and traps"
		% [deployed, DEFENCES.size() + TRAPS.size() - UNGUARDED.size()])
	# Their sounds come with the step that places them.
	var ticked := view.sim.tick
	while view.sim.tick <= ticked + 1:
		await frames(1)
		_watch_mega(view, audio)
	check(audio.play_count(&"deploy_ground") > int(counts[&"deploy_ground"])
		and audio.play_count(&"deploy_air") > int(counts[&"deploy_air"]),
		"the deploys sound by class: deploy_ground +%d, deploy_air +%d (of %d deployed)"
		% [audio.play_count(&"deploy_ground") - int(counts[&"deploy_ground"]),
		audio.play_count(&"deploy_air") - int(counts[&"deploy_air"]), deployed])
	# The abilities: the strike on the shield generator, the EMP over the laser turret, the swarm
	# on the army beside the first defence.
	var at := {}
	for building: Dictionary in kept:
		at[building["type"]] = _cell(building)
	var casts := PackedStringArray()
	casts.append(view.cast("orbital_strike", at["command_center"]))
	casts.append(view.cast("emp_burst", at["laser_turret"]))
	casts.append(view.cast("repair_swarm", at["laser_turret"]))
	check(casts == PackedStringArray(["", "", ""]), "the strike, the EMP and the swarm cast (%s)" % ", ".join(casts))

	# Every sound heard, or the battle over. The trap's pop: mega_blast's time after the mine sprang.
	var wanted := _wanted(main, kept)
	var loops: Array[StringName] = [&"air_bed", &"shield_hum", &"vortex_hum", &"emp_hold", &"swarm_hum",
		&"strike_marker", &"grav_whoosh"]
	Profile.enabled = true
	Profile.take()
	var frame_count := 0
	var cast_again := false
	var shot := false
	var until := Time.get_ticks_msec() + int(BATTLE_WAIT * 1000.0)
	while Time.get_ticks_msec() < until and not view.sim.is_over():
		await frames(1)
		frame_count += 1
		_watch_mega(view, audio)
		if not shot and view.sim.tick >= SHOT_TICK:
			shot = true
			await screenshot("battle")
		if not cast_again and view.sim.tick > 300:
			# Later in the battle, a second strike and EMP where the army has got to.
			cast_again = true
			view.cast("orbital_strike", at["shield_generator"])
			view.cast("emp_burst", at["orbital_cannon"])
		if frame_count % 30 == 0 and _missing(audio, counts, wanted).is_empty() and _loops_missing(view, loops).is_empty() \
				and view.sim.stars() > 0:
			break
	var spent: Vector2i = Profile.take().get(&"audio", Vector2i.ZERO)
	Profile.enabled = false
	say("Audio in battle: %.4f ms a frame over %d frames (%d plays), %d voices sounding at tick %d"
		% [spent.x / 1000.0 / maxi(frame_count, 1), frame_count, spent.y, audio.playing_count(), view.sim.tick])
	var heard := PackedStringArray()
	for key: StringName in wanted:
		heard.append("%s +%d" % [key, audio.play_count(key) - int(counts[key])])
	say("battle plays: %s" % ", ".join(heard))
	var missing := _missing(audio, counts, wanted)
	check(missing.is_empty(), "every battle sound wanted was heard (%d keys; missing: %s)"
		% [wanted.size(), ", ".join(missing)])
	var loops_missing := _loops_missing(view, loops)
	check(loops_missing.is_empty(), "every loop was held (missing: %s)" % ", ".join(loops_missing))
	var unsprung := PackedStringArray()
	for building: Dictionary in kept:
		if TRAPS.has(str(building["type"])) and not view.sim.is_destroyed(BattleMath.whole(building["id"])):
			unsprung.append(building["type"])
	check(unsprung.is_empty(), "every trap sprang (not: %s): trap_click +%d, its blast or crack, the grav trap's whoosh"
		% [", ".join(unsprung), audio.play_count(Sounds.TRAP_SPRING) - int(counts[Sounds.TRAP_SPRING])])
	var expected := roundi(BattleView.TRAP_POP / view.speed * 1000.0)
	# It sprang between the frame before it was seen gone and that frame: its blast is due
	# TRAP_POP after a moment in that span (a long frame holds a due play to the next drain).
	check(_sprang_after >= 0 and _pops.size() == 2 and _pops[0] >= expected - POP_SLACK_MS
			and _pops[1] <= expected + POP_SLACK_MS,
		"the mega mine's blast lands TRAP_POP after it sprang: %d ms after the frame before it was seen gone, %d after that frame, %d expected"
		% [_pops[0] if _pops.size() == 2 else -1, _pops[1] if _pops.size() == 2 else -1, expected])

	# The end: the sting with the banner, only the bed held; Return: silence.
	if not view.sim.is_over():
		view.surrender()
	while not view.sim.is_over():
		await frames(1)
	await frames(2)
	var stings := audio.play_count(&"victory") + audio.play_count(&"defeat") \
		- int(counts[&"victory"]) - int(counts[&"defeat"])
	check(stings == 1 and hud.is_result_open(), "the result shows with one sting (%d)" % stings)
	# Stars won at once chime STAR_GAP apart: wait past the last before counting one a star.
	await main.get_tree().create_timer(BattleHud.STAR_GAP * 3.0 + 0.1).timeout
	var chimes := audio.play_count(&"star_earned") - int(counts[&"star_earned"])
	check(chimes == view.sim.stars() and chimes > 0, "each star won chimes: star_earned +%d for %d stars"
		% [chimes, view.sim.stars()])
	var held := view.loops_held()
	check(held.size() == 1 and held[0] == &"battle_bed", "at the end only the bed is held (%s)" % [held])
	await screenshot("result")
	var finished := [false]
	view.finished.connect(func(_setup: Dictionary, _result: Dictionary) -> void: finished[0] = true)
	hud.return_button().pressed.emit()
	while not finished[0]:
		await frames(1)
	# The base's ambience comes back with the base: its loop is the one voice allowed.
	var quiet_until := Time.get_ticks_msec() + int(QUIET_WAIT * 1000.0)
	while (_voices_but_bed(main, audio) > 0 or audio.scheduled_count() > 0) and Time.get_ticks_msec() < quiet_until:
		await frames(1)
	check(_voices_but_bed(main, audio) == 0 and audio.scheduled_count() == 0,
		"after Return no voice sounds but the base's bed and nothing waits (%d voices, %d scheduled)"
		% [_voices_but_bed(main, audio), audio.scheduled_count()])


## The voices sounding but the base's ambience's loop.
func _voices_but_bed(main: MainScript, audio: Audio) -> int:
	return audio.playing_count() - (1 if audio.loop_level(main.ambience()) >= 0.0 else 0)


## Notes when the mega mine is first seen gone, and each mega_blast's lag behind that.
func _watch_mega(view: BattleView, audio: Audio) -> void:
	var now := Time.get_ticks_msec()
	if _sprang_at < 0 and view.sim.is_destroyed(_mega):
		_sprang_at = now
		_sprang_after = _watched_at
	_watched_at = now
	if audio.play_count(&"mega_blast") != _megas and _pops.is_empty():
		_megas = audio.play_count(&"mega_blast")
		var blast := audio.recent_times()[audio.recent_plays().rfind(&"mega_blast")]
		_pops.append(blast - _sprang_after)
		_pops.append(blast - _sprang_at)


## A strike cast and, once its whine is scheduled (the step that takes the cast has run), the
## battle surrendered: the surrender drops it, so nothing waits on the result panel, the whine is
## not heard there past its time, nor after Return.
func _check_dropped(main: MainScript, audio: Audio) -> void:
	var setup := main.practice_setup()
	setup["attacker"] = {"army": {"ranger": 5}, "unit_levels": {}, "abilities": {"orbital_strike": 1},
		"ability_levels": {}}
	var error := main.open_battle(setup, true)
	check(error == "", "a second practice battle opens: '%s'" % error)
	if error != "":
		return
	var view: BattleView = main.battle
	var target := Vector2i.ZERO
	for building: Dictionary in setup["defender"]["buildings"]:
		if building["type"] == "command_center":
			target = _cell(building)
	var bolts := audio.play_count(&"strike_bolt")
	var cast_at := view.sim.tick
	var refused := view.cast("orbital_strike", target)
	# The step that takes the cast reads its ABILITY event, which schedules the whine.
	while view.sim.tick <= cast_at + 1:
		await frames(1)
	var scheduled := audio.scheduled_count()
	check(refused == "" and scheduled > 0, "a strike cast: its whine scheduled (%d waiting; cast '%s')"
		% [scheduled, refused])
	view.surrender()
	await frames(2)
	check(view.sim.is_over() and main.battle_hud.is_result_open() and audio.scheduled_count() == 0,
		"surrendered: on the result panel nothing waits (%d)" % audio.scheduled_count())
	await main.get_tree().create_timer(DROP_WAIT).timeout
	check(audio.play_count(&"strike_bolt") == bolts,
		"no strike_bolt on the result panel %.1f s on, past its time (+%d)"
		% [DROP_WAIT, audio.play_count(&"strike_bolt") - bolts])
	var finished := [false]
	view.finished.connect(func(_setup: Dictionary, _result: Dictionary) -> void: finished[0] = true)
	main.battle_hud.return_button().pressed.emit()
	while not finished[0]:
		await frames(1)
	check(audio.scheduled_count() == 0 and audio.play_count(&"strike_bolt") == bolts,
		"after Return nothing waits and no strike_bolt (%d waiting, +%d)"
		% [audio.scheduled_count(), audio.play_count(&"strike_bolt") - bolts])


## The keys the battle must play at least once: every kept defence's shot and landing, every unit's
## shot (its landing when the shot is silent), the hits, the falls, a death of each kind and its
## blast, the traps', the shield's, the EMP's, the abilities', the deploys and the loot.
func _wanted(main: MainScript, kept: Array[Dictionary]) -> Array[StringName]:
	var wanted: Array[StringName] = []
	for building: Dictionary in kept:
		var type: String = building["type"]
		if DEFENCES.has(type):
			_want(wanted, Sounds.fire_key(type))
			_want(wanted, Sounds.land_key(type))
	for unit: String in ARMY:
		_want(wanted, Sounds.fire_key(unit) if Sounds.fire_key(unit) != &"" else Sounds.land_key(unit))
	for death: int in Weapons.Death.values():
		_want(wanted, Sounds.DEATH[death])
		_want(wanted, Sounds.DEATH_END[death])
	for trap: String in TRAPS:
		_want(wanted, Sounds.land_key(trap))
		var key: StringName = Sounds.TRAP[Weapons.of(trap).kind]
		if not bool(Sounds.TABLE.get(String(key), {}).get("loop", false)):
			_want(wanted, key)
	for key: StringName in [Sounds.TRAP_SPRING, &"building_hit", &"unit_hit_figure", &"unit_hit_machine",
			&"wall_crumble", &"building_collapse", &"rubble_settle", &"reveal_shimmer", &"unit_thrown",
			&"shield_up", &"shield_hit", &"shield_down", &"emp_burst", &"emp_wake", &"swarm_cast", &"strike_bolt",
			&"strike_land", &"loot_tick"]:
		_want(wanted, key)
	return wanted


func _want(wanted: Array[StringName], key: StringName) -> void:
	if key != &"" and not wanted.has(key):
		wanted.append(key)


func _missing(audio: Audio, counts: Dictionary, wanted: Array[StringName]) -> PackedStringArray:
	var missing := PackedStringArray()
	for key: StringName in wanted:
		if audio.play_count(key) <= int(counts[key]):
			missing.append(key)
	return missing


func _loops_missing(view: BattleView, loops: Array[StringName]) -> PackedStringArray:
	var missing := PackedStringArray()
	for key: StringName in loops:
		if view.loop_starts(key) == 0:
			missing.append(key)
	return missing


func _centre(main: MainScript, building: Dictionary) -> Vector2:
	return Vector2(_cell(building)) + Vector2.ONE * main.catalog.size_of(str(building["type"])) * 0.5


func _cell(building: Dictionary) -> Vector2i:
	return Vector2i(int(building["cell"][0]), int(building["cell"][1]))


## Whether wall `wall` stands within WALL_REACH cells of any of `kept`'s footprints.
func _beside(main: MainScript, wall: Dictionary, kept: Array[Dictionary]) -> bool:
	var cell := _cell(wall)
	for building: Dictionary in kept:
		var from := _cell(building)
		var size := main.catalog.size_of(str(building["type"]))
		if cell.x >= from.x - WALL_REACH and cell.x < from.x + size + WALL_REACH \
				and cell.y >= from.y - WALL_REACH and cell.y < from.y + size + WALL_REACH:
			return true
	return false


## Moves each trap in `kept` to the first free cell round its host (TRAP_HOSTS), nearest first.
func _place_traps(main: MainScript, kept: Array[Dictionary]) -> void:
	var taken := {}
	var hosts := {}
	for building: Dictionary in kept:
		hosts[building["type"]] = building
		if not TRAPS.has(str(building["type"])):
			_mark(taken, _cell(building), main.catalog.size_of(str(building["type"])))
	var grid := main.catalog.grid_size
	for building: Dictionary in kept:
		var type := str(building["type"])
		if not TRAPS.has(type):
			continue
		var size := main.catalog.size_of(type)
		for spot: Vector2i in _spots(main, hosts[TRAP_HOSTS[type]]):
			var free := spot.x >= 0 and spot.y >= 0 and spot.x + size <= grid.x and spot.y + size <= grid.y
			for dx: int in size:
				for dy: int in size:
					free = free and not taken.has(spot + Vector2i(dx, dy))
			if free:
				building["cell"] = [spot.x, spot.y]
				_mark(taken, spot, size)
				break
		say("%s moved beside the %s, to %s" % [type, TRAP_HOSTS[type], building["cell"]])


func _mark(taken: Dictionary, cell: Vector2i, size: int) -> void:
	for dx: int in size:
		for dy: int in size:
			taken[cell + Vector2i(dx, dy)] = true


## The cells round `building`, nearest rings first.
func _spots(main: MainScript, building: Dictionary) -> Array[Vector2i]:
	var from := _cell(building)
	var size := main.catalog.size_of(str(building["type"]))
	var centre := from + Vector2i(size / 2, size / 2)
	var spots: Array[Vector2i] = []
	for reach: int in range(1, 10):
		for dx: int in range(-reach, reach + 1):
			for dy: int in [-reach, reach]:
				spots.append(centre + Vector2i(dx, dy))
				spots.append(centre + Vector2i(dy, dx))
	return spots
