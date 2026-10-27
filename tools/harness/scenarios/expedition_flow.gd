extends HarnessScenario
## The expedition flow in the game (docs/reference/hud.md, **Sector map**; battle-view.md,
## **Expeditions**) on the debug build's Template base (Command Center 10), pressed through its
## button. The Expedition button opens the sector map over the base (the world's input out of the
## tree), its badge counting six open fields; the first scan is free and starts epoch 1, the next
## is refused with "The scanner is still cooling down" and, the cooldown passed (advance), Scan is
## ready again; each card shows its field's band and outpost. The easy
## field's detail lays the field out (the minimap draws every building but the walls and traps,
## and every wall apart); Attack with the Hangars empty is refused with "Train some units first".
## Then, given the battle scenario's army at its top levels, one of the first ability in stock and
## half of every storage, Attack opens the battle as a rival colony, bringing the army and the stock: the field's seed the landscape's, every defender building and the
## merged walls on MaterialKit.rival, nothing else (units, outlines, rubble, scenery) tinted. The
## army is deployed from the middles of the four edges in four waves, sent through
## BattleView.script_commands, and run at 2x to its end; the result panel's Return leaves it. Back
## on the base: the raid applied with the
## field's inputs logged, the field cleared exactly when a star was taken, the units deployed spent,
## the loot banked up to storage, the toast, and the map open again with the stamp; a cleared
## field's detail does not open and its result applied again is refused ("That field has
## changed"). A finger held on the world while Expedition is pressed, and lifted while the map is
## open, does not stop the first tap on the world after Close. Then the green faction at Command
## Center 10: the even field's battle opened and shot at its start, framed on its buildings' middle,
## then an EMP burst (one in stock) cast on a defence: the disabled defences grey on disabled_rival
## and every body still rival, and again once they wake; then left by End; the practice raid on the template base (Crown) shot the same way, untinted
## everywhere; rendered, the share of the shots' middles in the green band (GREEN_HUES, saturated)
## must be at least GREEN_RATIO times the practice's and GREEN_MARGIN above it, both logged.
## Screenshots: the map (its thumbnails all in), the detail, the battle at tick 300 framed on the
## outpost, the map after it, the even field tinted and the practice beside it.
##
## The army, the stock, the storages and the sector's seed are set on main.state directly, as the expedition scenario sets its
## copy's: the dev cheats are off in the harness, and training 167 units would take its real time.

const ARMY := {"ranger": 100, "brawler": 40, "jet_trooper": 20, "hover_tank": 5, "gunship": 2}
const LEVEL := 8
## The easy band's first field.
const FIELD := 0
## The ability cast over the Command Center 10 outpost, to disable and wake its defences.
const EMP := "emp_burst"
## The sector's seed, set so the run repeats (the template base's own comes from the clock).
const SECTOR_SEED := 20261024
## How far round each edge's middle a wave spreads, in cells, and the ticks between waves.
const SPREAD := 2
const WAVE_TICKS := 20
const BATTLE_TICK := 300
const BATTLE_ZOOM := 26.0
## The even band's first field: Command Center 10 against the template base's 10.
const TOP_FIELD := 2
## The green band (hue, sRGB) and the saturation and value a pixel needs to count; the middle of
## the screen measured, clear of the HUD; and the pass marks: the tinted share at least GREEN_RATIO
## times the practice's and GREEN_MARGIN above it.
const GREEN_HUES := Vector2(0.17, 0.47)
const GREEN_SATURATION := 0.35
const GREEN_VALUE := 0.25
const MEASURED := Rect2(240, 120, 800, 400)
const GREEN_RATIO := 2.0
const GREEN_MARGIN := 0.03

var _setup: Dictionary = {}
var _result: Dictionary = {}
var _finished: bool = false


func run(main: MainScript) -> void:
	var hud: Hud = main.hud
	var map: SectorMap = main.sector_map
	var catalog: Catalog = main.catalog
	hud.template_button().pressed.emit()
	await frames(2)
	var state: BaseState = main.state
	state.sector.sector_seed = SECTOR_SEED
	var taps := [0]
	main.world_input.tapped.connect(func(_at: Vector2) -> void: taps[0] += 1)
	# A second finger held on the world as Expedition is pressed, lifted while the map is open.
	var world_point := main.get_viewport().get_visible_rect().size * Vector2(0.5, 0.45)
	_touch(main, 1, world_point, true)
	await frames(2)
	var count := catalog.expedition_field_count()
	check(hud.expedition_button().is_visible_in_tree() and hud.expedition_badge() == str(count),
		"the Expedition button shows with %d open fields on its badge ('%s')" % [count, hud.expedition_badge()])
	hud.expedition_button().pressed.emit()
	await frames(3)
	_touch(main, 1, world_point, false)
	await frames(2)
	check(map.is_open() and not map.is_detail_open() and not main.world_input.is_inside_tree()
		and map.mouse_filter == Control.MOUSE_FILTER_STOP,
		"the map opened over the base on its fields, the world's input out of the tree")
	check(map.hint_shown() == (state.sector.cc < state.cc_level()),
		"the scan hint shows exactly while the snapshot (CC %d) is below the base (CC %d)" % [state.sector.cc, state.cc_level()])

	while not map.layouts_done():
		await frames(1)
	var thumbs := true
	for i: int in count:
		thumbs = thumbs and map.card_thumbnail(i).drawn() > 0
	check(thumbs, "every card shows its outpost's thumbnail")
	await screenshot("map")
	var epoch := state.sector.epoch
	check(not map.scan_button().disabled and map.scan_button().text == "SCAN", "the first scan is free")
	map.scan_button().pressed.emit()
	await frames(2)
	check(state.sector.epoch == epoch + 1, "Scan started epoch %d" % state.sector.epoch)
	check(map.scan_button().disabled and map.scan_button().text == "SCAN  %s" % Format.duration(state.scan_seconds_left()),
		"Scan counts down: '%s'" % map.scan_button().text)
	map.scan_pressed.emit()
	check(state.sector.epoch == epoch + 1 and hud.toast_text() == "The scanner is still cooling down",
		"a scan while it recharges is refused: '%s'" % hud.toast_text())
	advance(state.scan_seconds_left())
	await main.get_tree().create_timer(1.2).timeout
	check(not map.scan_button().disabled and map.scan_button().text == "SCAN",
		"once the cooldown has passed, Scan is ready again: '%s'" % map.scan_button().text)
	var fields := state.sector_fields()
	for i: int in count:
		var lines := map.card_lines(i)
		say("expedition_flow: card %d: %s" % [i, " | ".join(lines)])
		check(lines[0] == str(fields[i]["band"]).to_upper() and lines[1] == "Rival colony · CC %d" % int(fields[i]["cc"])
			and not map.card_cleared(i) and not map.card(i).disabled,
			"card %d shows its %s field, open" % [i, fields[i]["band"]])

	map.card(FIELD).pressed.emit()
	await frames(3)
	var field := map.detail_field()
	check(map.is_detail_open() and map.detail_index() == FIELD and not map.scan_button().visible,
		"the easy card opened its detail")
	check(JSON.stringify(field) == JSON.stringify(OutpostGenerator.generate(catalog, state, FIELD)),
		"the detail's field is the field's layout")
	var shown := 0
	var walls := 0
	for entry: Variant in (field["defender"] as Dictionary)["buildings"]:
		var building: Dictionary = entry
		match catalog.battle_class(str(building["type"])):
			Catalog.CLASS_WALL:
				walls += 1
			Catalog.CLASS_TRAP:
				pass
			_:
				shown += 1
	check(map.minimap().drawn() == shown and map.minimap().walls_drawn() == walls,
		"the minimap draws %d buildings (%d) and %d walls (%d), no trap" % [shown, map.minimap().drawn(), walls,
		map.minimap().walls_drawn()])
	# The toast of the refused scan fades first, so the shot shows the detail's header.
	while hud.toast_text() != "":
		await frames(1)
	await screenshot("detail")
	map.attack_button().pressed.emit()
	await frames(1)
	check(main.battle == null and map.is_detail_open() and hud.toast_text() == "Train some units first",
		"Attack with the Hangars empty is refused: '%s'" % hud.toast_text())

	for unit: String in ARMY:
		state.army[unit] = int(ARMY[unit])
		state.unit_levels[unit] = mini(LEVEL, catalog.unit_max_level(unit))
	var ability := catalog.ability_types()[0]
	state.ability_stock[ability] = 1
	for res: String in catalog.resources:
		state.resources[res] = state.capacity(res) / 2
	var before := state.resources.duplicate()
	var raids := state.raids.size()
	map.attack_button().pressed.emit()
	await frames(2)
	var view: BattleView = main.battle
	check(view != null, "Attack opened the battle")
	if view == null:
		return
	view.finished.connect(func(setup: Dictionary, result: Dictionary) -> void:
		_setup = setup
		_result = result
		_finished = true)
	check(not map.is_open() and not hud.visible and view.rival and view.field.scenery_seed == int(field["seed"]),
		"the battle took the base's place, the map closed, as a rival colony in the field's landscape (seed %d)"
		% view.field.scenery_seed)
	_check_tint(view, true)
	var attacker: Dictionary = view.battle_setup["attacker"]
	check(attacker["army"] == ARMY and attacker["abilities"] == {ability: 1}
		and int((attacker["ability_levels"] as Dictionary).get(ability, 0)) == state.ability_level(ability),
		"the battle brings the Hangars' army and the stock: %s" % [attacker["abilities"]])

	var last := catalog.grid_size - Vector2i.ONE
	var points: Array[Vector2i] = [Vector2i(last.x / 2, 0), Vector2i(last.x, last.y / 2), Vector2i(last.x / 2, last.y),
		Vector2i(0, last.y / 2)]
	var spots: Array[Array] = []
	for point: Vector2i in points:
		var cells: Array[Vector2i] = []
		for y: int in range(point.y - SPREAD, point.y + SPREAD + 1):
			for x: int in range(point.x - SPREAD, point.x + SPREAD + 1):
				if view.sim.is_deploy_cell(Vector2i(x, y)):
					cells.append(Vector2i(x, y))
		spots.append(cells)
	var commands: Array[Dictionary] = []
	var n := 0
	for unit: String in ARMY:
		for k: int in int(ARMY[unit]):
			var wave: Array = spots[n % 4]
			var cell: Vector2i = wave[(n / 4) % wave.size()]
			commands.append({"op": "deploy", "tick": (n % 4) * WAVE_TICKS, "unit": unit, "cell": [cell.x, cell.y]})
			n += 1
	view.script_commands(commands)
	view.speed = 2
	var hq := Vector2i.ZERO
	for entry: Variant in (field["defender"] as Dictionary)["buildings"]:
		var building: Dictionary = entry
		if str(building["type"]) == Catalog.HQ_TYPE:
			hq = Vector2i(int(building["cell"][0]), int(building["cell"][1])) + Vector2i.ONE * (catalog.size_of(Catalog.HQ_TYPE) / 2)
	frame_world(main, BATTLE_ZOOM, view.field.cell_to_world(hq, 1))
	while view.sim.tick < BATTLE_TICK and not view.sim.is_over():
		await frames(1)
	await screenshot("battle")
	_check_tint(view, true)
	await _return(main)
	await frames(3)

	var stars := int(_result["stars"])
	var starred := stars >= 1
	say("expedition_flow: the battle: %d ticks, destruction %d%%, %d stars, loot %s" % [int(_result["ticks"]),
		int(_result["destruction"]), stars, _result["loot"]])
	check(state.raids.size() == mini(raids + 1, BaseState.RAID_LOG_SIZE), "the raid was applied and logged")
	var logged: Dictionary = state.raids[state.raids.size() - 1]
	var key: Dictionary = logged.get("expedition", {})
	check(int(key.get("index", -1)) == FIELD and int(key.get("epoch", -1)) == epoch + 1
		and not (logged["battle"] as Dictionary).has("defender"),
		"the raid log keeps the field's inputs, not its layout: %s" % [key])
	check(state.sector.is_cleared(FIELD) == starred, "the field is cleared exactly when a star was taken (%d)" % stars)
	var deployed: Dictionary = _result["deployed"]
	var spent := true
	for unit: String in ARMY:
		spent = spent and state.army[unit] == int(ARMY[unit]) - int(deployed.get(unit, 0))
	check(spent, "the units deployed are spent")
	var loot: Dictionary = _result["loot"]
	var gains := PackedStringArray()
	var banked := true
	for res: String in catalog.resources:
		var expected := maxi(int(before[res]), mini(int(before[res]) + int(loot.get(res, 0)), state.capacity(res)))
		banked = banked and state.resources[res] == expected
		if expected > int(before[res]):
			gains.append("+%s %s" % [Format.amount(expected - int(before[res])), catalog.resource_name(res).to_lower()])
	check(banked, "the loot is banked up to storage: %s" % [state.resources])
	var toast := "Field cleared: %d %s" % [stars, "star" if stars == 1 else "stars"] if starred else "Field still open"
	if not gains.is_empty():
		toast += "\n" + ", ".join(gains)
	check(hud.toast_text() == toast, "the toast: '%s'" % hud.toast_text().replace("\n", " / "))
	check(main.battle == null and hud.visible and map.is_open() and not map.is_detail_open()
		and not main.world_input.is_inside_tree(), "the map opened again over the base")
	check(map.card_cleared(FIELD) == starred and map.card(FIELD).disabled == starred,
		"the easy card is stamped and dimmed exactly when cleared")
	await screenshot("back")

	if starred:
		check(not map.show_field(FIELD) and not map.is_detail_open(), "a cleared field's detail does not open")
		var again := main.placement.raid_result(_setup, _result, {"epoch": state.sector.epoch, "index": FIELD})
		check(again == BaseState.ERR_BAD_EXPEDITION and Hud.error_text(again) == "That expedition does not add up",
			"the cleared field's result again is refused: '%s'" % Hud.error_text(again))
	else:
		say("expedition_flow: no star, so the field stays open and its second attack is not tried")
	map.close_button().pressed.emit()
	await frames(2)
	check(not map.is_open() and main.world_input.is_inside_tree(), "Close gave the world its input back")
	taps[0] = 0
	_touch(main, 0, world_point, true)
	await frames(2)
	_touch(main, 0, world_point, false)
	await frames(2)
	check(taps[0] == 1, "the first tap on the world after Close is a tap, the finger held at Expedition forgotten (%d)" % taps[0])
	var open := count - state.sector.cleared.size()
	check(hud.expedition_badge() == (str(open) if open > 0 else ""), "the badge counts %d open fields" % open)

	# The green faction at Command Center 10, against the template base's own Crown.
	for unit: String in ARMY:
		state.army[unit] = int(ARMY[unit])
	state.ability_stock[EMP] = 1
	hud.expedition_button().pressed.emit()
	await frames(2)
	map.card(TOP_FIELD).pressed.emit()
	await frames(2)
	map.attack_button().pressed.emit()
	await frames(2)
	var top: BattleView = main.battle
	check(top != null and top.rival, "the even field's battle opened tinted")
	var tinted := -1.0
	if top != null:
		_check_tint(top, true)
		await _shoot_outpost(main, top, "top-tinted")
		tinted = _green_share(main)
		# An EMP on a defence: the disabled defences grey and still rival, and again once awake.
		var aim := Vector2i.ZERO
		for entry: Variant in (top.battle_setup["defender"] as Dictionary)["buildings"]:
			var building: Dictionary = entry
			if main.catalog.battle_class(str(building["type"])) == Catalog.CLASS_DEFENSE:
				aim = Vector2i(int(building["cell"][0]), int(building["cell"][1]))
				break
		var cast := top.cast(EMP, aim)
		check(cast == "", "an EMP burst is cast over the outpost: '%s'" % cast)
		var greyed := 0
		for i: int in 120:
			await frames(1)
			greyed = _disabled_shown(top)
			if greyed > 0:
				break
		check(greyed > 0, "the EMP disabled %d defences, shown grey" % greyed)
		_check_tint(top, true)
		top.speed = 2
		for i: int in 600:
			await frames(1)
			if _disabled_shown(top) == 0:
				break
		check(_disabled_shown(top) == 0, "the defences woke")
		_check_tint(top, true)
		_finished = false
		top.finished.connect(func(_s: Dictionary, _r: Dictionary) -> void: _finished = true)
		top.surrender()
		await _return(main)
		await frames(2)
		map.close_button().pressed.emit()
		await frames(2)

	# A practice draws no tint.
	var error := main.open_battle(main.practice_setup(), true)
	check(error == "" and main.battle != null and not main.battle.rival, "a practice raid opens untinted")
	if main.battle != null:
		var practice: BattleView = main.battle
		_check_tint(practice, false)
		await _shoot_outpost(main, practice, "practice")
		var plain := _green_share(main)
		if harness.headless:
			say("expedition_flow: the green share skipped (headless)")
		else:
			say("expedition_flow: green share of the middle: tinted CC 10 field %.3f, practice %.3f" % [tinted, plain])
			check(tinted >= plain * GREEN_RATIO and tinted >= plain + GREEN_MARGIN,
				"the rival colony reads green at Command Center 10: %.3f against %.3f" % [tinted, plain])
		_finished = false
		practice.finished.connect(func(_s: Dictionary, _r: Dictionary) -> void: _finished = true)
		practice.surrender()
		await _return(main)
		await frames(2)


## Every defender building's toon bodies and the merged walls carry MaterialKit.rival (or, for the
## moment a building is hit, hit_flash_rival, and while an EMP has it disabled, disabled_rival; or,
## while a building holds its folded parts, its held copy of one, _rival_worn) exactly when `rival`;
## no other mesh in the battle (units, outlines, rubble, scenery) carries either.
func _check_tint(view: BattleView, rival: bool) -> void:
	var tinted := 0
	var plain := 0
	var stray := 0
	for node: Node in view.find_children("*", "GeometryInstance3D", true, false):
		var building := _building_of(node, view)
		if node is MeshInstance3D:
			var mesh := node as MeshInstance3D
			if mesh.mesh == null:
				continue
			for surface: int in mesh.mesh.get_surface_count():
				var override := mesh.get_surface_override_material(surface)
				var on := _rival_worn(override) or mesh.material_override == MaterialKit.rival()
				var body := building and surface == 0 and mesh.mesh.surface_get_material(0) == MaterialKit.toon()
				if mesh == view.field.walls.body:
					body = true
				if body:
					if mesh.is_visible_in_tree():
						if on:
							tinted += 1
						else:
							plain += 1
				elif on:
					stray += 1
		elif (node as GeometryInstance3D).material_override == MaterialKit.rival():
			stray += 1
	if rival:
		check(tinted > 0 and plain == 0 and stray == 0,
			"the defender's %d bodies are tinted, %d left plain, %d other meshes tinted" % [tinted, plain, stray])
	else:
		check(tinted == 0 and stray == 0, "nothing is tinted (%d bodies, %d other meshes)" % [tinted, stray])


## Whether `material` is one of the rival bodies' shared materials, or a held copy of one
## (MaterialKit.moving: the toon_move shader with the copied `rival` 1), as a building whose folded
## parts hold wears it (BuildingView._tint_folded).
func _rival_worn(material: Material) -> bool:
	if material == MaterialKit.rival() or material == MaterialKit.hit_flash_rival() \
			or material == MaterialKit.disabled_rival():
		return true
	var held := material as ShaderMaterial
	return held != null and held.shader == MaterialKit.TOON_MOVE_SHADER \
		and float(held.get_shader_parameter(&"rival")) > 0.5


## Frames the middle of `view`'s buildings (their cells' mean) at BATTLE_ZOOM, the battle paused,
## and shoots it as `name`.
func _shoot_outpost(main: MainScript, view: BattleView, name: String) -> void:
	view.speed = 0
	var sum := Vector2i.ZERO
	var buildings: Array = (view.battle_setup["defender"] as Dictionary)["buildings"]
	for entry: Variant in buildings:
		var building: Dictionary = entry
		sum += Vector2i(int(building["cell"][0]), int(building["cell"][1]))
	frame_world(main, BATTLE_ZOOM, view.field.cell_to_world(sum / maxi(1, buildings.size()), 1))
	await frames(6)
	await screenshot(name)
	view.speed = 1


## The share of MEASURED's pixels (every fourth each way) in the green band; -1 headless.
func _green_share(main: MainScript) -> float:
	if harness.headless:
		return -1.0
	var image := main.get_viewport().get_texture().get_image()
	var scale := Vector2(image.get_size()) / main.get_viewport().get_visible_rect().size
	var green := 0
	var counted := 0
	for y: int in range(int(MEASURED.position.y), int(MEASURED.end.y), 4):
		for x: int in range(int(MEASURED.position.x), int(MEASURED.end.x), 4):
			var pixel := image.get_pixel(int(x * scale.x), int(y * scale.y))
			counted += 1
			if pixel.h >= GREEN_HUES.x and pixel.h <= GREEN_HUES.y and pixel.s >= GREEN_SATURATION \
					and pixel.v >= GREEN_VALUE:
				green += 1
	return float(green) / maxf(1.0, float(counted))


## A real touch of finger `index` at `point` (the HUD's coordinates), pressed or lifted.
func _touch(main: MainScript, index: int, point: Vector2, pressed: bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = index
	touch.position = main.get_viewport().get_final_transform() * point
	touch.pressed = pressed
	Input.parse_input_event(touch)


## The defences `view` shows disabled now.
func _disabled_shown(view: BattleView) -> int:
	var shown := 0
	for id: int in view.sim.building_ids():
		if view.is_shown_disabled(id):
			shown += 1
	return shown


## Waits for the battle's end and its result panel (BattleHud), then presses Return, which leaves
## the battle (`finished`).
func _return(main: MainScript) -> void:
	while main.battle_hud == null or not main.battle_hud.is_result_open():
		await frames(1)
	main.battle_hud.return_button().pressed.emit()
	while not _finished:
		await frames(1)


## Whether `node` is part of a defender building's view.
func _building_of(node: Node, view: BattleView) -> bool:
	var at := node.get_parent()
	while at != null and at != view:
		if at is BuildingView:
			return true
		at = at.get_parent()
	return false
