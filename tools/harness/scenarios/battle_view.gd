extends HarnessScenario
## The battle view and its attack HUD (docs/reference/battle-view.md, docs/reference/hud.md,
## **Battle HUD**) on the debug build's Practice raid: the template base (Template base, pressed
## through the HUD) raided by a scripted army, drawn by BattleView in the base's place and run
## until the HUD's End.
##
## First the Practice raid button with the Hangars empty: refused with a toast, no battle. Then the
## practice setup (main.practice_setup) given the battle scenario's army (ARMY at LEVEL, the
## Hangars' 280 housing) and SEED, not the base's scenery seed, opened through main.open_battle
## once the base's idle frames are making the cards' pictures (Hud.prerender):
## the field in a landscape of its own, the base's view and input out of the tree, its HUD hidden,
## the BattleHud shown with a card per type, the first selected and the red zone up, and in a
## rendered run every card's picture made. Through the
## HUD: the Ranger's card selects it; a tap deploys one and a tap in the zone is refused with a
## toast; a drag over SMEAR cells deploys one a cell, one a tick; a drag back and forth over two cells
## deploys two. One Ranger is kept back. The rest of the army is deployed
## as the battle scenario deploys it, in three groups a second apart from SCRIPT_TICK, each spread
## over the deploy cells within SPREAD of its point, sent live through
## BattleView.script_commands. Rendered only, once the whole army is down, the battle is paused
## (speed 0) and measured at the widest zoom in a MEASURE window (_measure): the draw calls,
## primitives and render CPU time a frame against the Cost ceilings, the slowest frame's process
## time, the frame rate and the units drawn. At tick 200, through the abilities bar (two of each
## ability brought, ABILITIES_EACH): the orbital strike on the nearest defence, its marker, its bolt
## from the sky, its blast and its smoke a few ticks after shot and the defence's hull down; an EMP burst on the standing defence farthest from the army, disabled in the sim
## and dimmed; a repair swarm on a living unit, its dome shot; the Ranger's card selected again.
## The top bar is checked against the sim; the speed
## button takes the battle to 2x; at tick 1,000 End asks (a real touch beside it, the kept Ranger
## selected, deploys nothing), Keep fighting goes back, End battle
## surrenders, and the result panel replaces the deploy bar; the battle stays until Return.
## Screenshots: tick 0 (the red zone and the toast), the smear, tick 200, the strike's marker,
## bolt, blast and after, the EMP, the swarm, tick 1,000, the confirmation, the result panel (its abilities used),
## the base after it. The sim's step time is checked against
## STEP_CEILING.
##
## At the end: the sim's result equals a headless BattleSim.run of the same setup with the
## commands the view sent (so the view altered nothing), the HUD's deploys among them; every unit
## was deployed and something fell; `finished` brought the base back (its view and input in the
## tree, its HUD shown, the toast "Practice: nothing applied", the camera where it was), and the
## base's save is as it was but for its clock. Last, a practice battle bringing one of every unit
## type and every ability: both bars end left of the Build column (the deploy bar scrolls), then
## End and Return.

## Each ability brought, two of each.
const ABILITIES_EACH := 2
const ARMY := {"ranger": 100, "brawler": 40, "jet_trooper": 20, "hover_tank": 5, "gunship": 2}
const LEVEL := 8
## The battle's seed: not BaseView.SCENERY_SEED, so the field stands in a landscape of its own.
const SEED := 1793856615
## The deploy points (the battle scenario's): open pockets right of the resources and army bands,
## and below the base.
const POINTS: Array[Vector2i] = [Vector2i(42, 9), Vector2i(40, 19), Vector2i(24, 47)]
## How far round its point a group spreads, in cells; the tick the scripted groups start at,
## after the HUD's own deploys; the Rangers a drag deploys.
const SPREAD := 2
const SCRIPT_TICK := 60
const SMEAR := 4
## The Rangers a back-and-forth drag over two cells deploys (one a cell, never more), and the
## one kept back, selected, for the touch beside the End confirmation.
const BACK_AND_FORTH := 2
const KEPT := 1
## The Rangers the HUD deploys: a tap, the smear and the back-and-forth.
const BY_HUD := 1 + SMEAR + BACK_AND_FORTH
## The ticks shot while the battle runs, and the camera size the first two are taken at.
const CLOSE_TICKS: Array[int] = [0, 200]
const LATE_TICK := 1000
const CLOSE_ZOOM := 18.0
## The measuring window, how long the view is held before the monitors are read and how long they
## are sampled (as template_base), and the ceilings: the Cost ceilings of the maxed base
## (docs/reference/art-style.md) and the sim's step a tick.
const MEASURE := Vector2i(1600, 900)
const SETTLE_SECONDS := 2.1
const SAMPLE_SECONDS := 3.0
const DRAW_CALL_CEILING := 1600
const PRIMITIVE_CEILING := 2100000
const RENDER_CPU_CEILING := 6.0
const STEP_CEILING := 5.0
## The tick from which every scripted unit is down.
const ALL_DOWN := SCRIPT_TICK + 41

var _result: Dictionary = {}
var _finished: bool = false


func run(main: MainScript) -> void:
	main.hud.template_button().pressed.emit()
	await frames(2)
	main.hud.practice_button().pressed.emit()
	check(main.battle == null and main.hud.toast_text() == "Train some units first",
		"Practice raid with no units is refused: '%s'" % main.hud.toast_text())
	var before := _kept(main.state)

	var catalog: Catalog = main.catalog
	var setup := main.practice_setup()
	var template := TemplateBase.build(catalog, catalog.grid_size, now())
	check((setup["defender"]["buildings"] as Array).size() == (template["buildings"] as Array).size(),
		"the practice setup defends with the template base's %d buildings" % (template["buildings"] as Array).size())
	var levels := {}
	for unit: String in ARMY:
		levels[unit] = LEVEL
	setup["seed"] = SEED
	var stock := {}
	for ability: String in catalog.ability_types():
		stock[ability] = ABILITIES_EACH
	setup["attacker"] = {"army": ARMY, "unit_levels": levels, "abilities": stock, "ability_levels": {}}
	var zoom := main.camera.size
	var focus_before := main.camera.focus
	# Opened while the base's idle frames are making the cards' pictures, so the battle's HUD
	# must keep the preview running for its deploy cards.
	await main.get_tree().create_timer(MainScript.PRERENDER_AFTER + 0.2).timeout
	check(main.hud.preview().is_processing() or main.hud.preview().is_done(),
		"the base's idle frames are making the pictures as the battle opens")
	var error := main.open_battle(setup, true)
	check(error == "", "the battle opens: '%s'" % error)
	if error != "":
		return
	var view: BattleView = main.battle
	var hud: BattleHud = main.battle_hud
	view.finished.connect(func(_setup: Dictionary, result: Dictionary) -> void:
		_result = result
		_finished = true)
	check(view.field.scenery_seed == SEED and SEED != BaseView.SCENERY_SEED and view.field.mesas != main.base_view.mesas,
		"the field stands in the landscape of the battle's seed, not the base's (mesas %s)" % [view.field.mesas])
	check(view.is_inside_tree() and hud.is_inside_tree() and not main.base_view.is_inside_tree()
		and not main.world_input.is_inside_tree() and not main.hud.visible,
		"the battle and its HUD took the base's place: its view and input out, its HUD hidden")
	var brought := view.units_brought()
	check(view.deploy_unit == brought[0] and view.field.deploy_strength() > 0.0,
		"the first card (%s) starts selected, the red zone showing" % view.deploy_unit)
	for unit: String in brought:
		check(hud.card(unit).is_visible_in_tree() and hud.card_count(unit) == "x%d" % int(ARMY[unit]),
			"%s's card shows x%d (%s)" % [unit, int(ARMY[unit]), hud.card_count(unit)])
	if harness.headless:
		say("the deploy cards' pictures skipped (headless: nothing is drawn)")
	else:
		var waited := 0
		while waited < 240 and _unpictured(hud, brought) > 0:
			await frames(1)
			waited += 1
		check(_unpictured(hud, brought) == 0,
			"every deploy card has its picture (%d frames after the battle opened)" % waited)

	# The scripted groups, each spread over the deploy cells within SPREAD of its point, from tick
	# SCRIPT_TICK, so the HUD's own deploys come first.
	var spots: Array[Array] = []
	for point: Vector2i in POINTS:
		var cells: Array[Vector2i] = []
		for y: int in range(point.y - SPREAD, point.y + SPREAD + 1):
			for x: int in range(point.x - SPREAD, point.x + SPREAD + 1):
				if view.sim.is_deploy_cell(Vector2i(x, y)):
					cells.append(Vector2i(x, y))
		spots.append(cells)
	var commands: Array[Dictionary] = []
	var n := 0
	for unit: String in ARMY:
		for k: int in int(ARMY[unit]) - (BY_HUD + KEPT if unit == "ranger" else 0):
			var group: Array = spots[n % 3]
			var cell: Vector2i = group[(n / 3) % group.size()]
			commands.append({"op": "deploy", "tick": SCRIPT_TICK + (n % 3) * 20, "unit": unit, "cell": [cell.x, cell.y]})
			n += 1
	view.script_commands(commands)
	var focus := main.base_view.cell_to_world(Vector2i(38, 14), 1)
	zoom_to(main, CLOSE_ZOOM, focus)

	# The Ranger's card selects it; a tap deploys one; a tap in the zone is refused with a toast.
	hud.card("ranger").pressed.emit()
	check(view.deploy_unit == "ranger" and hud.card("ranger").theme_type_variation == &"BattleCardSelected",
		"the Ranger's card selected the Ranger")
	var tap_cell: Vector2i = spots[0][0]
	view.input.tapped.emit(_screen(main, view, tap_cell))
	check(view.sim.unit_count() == 1 and view.sim.unit_type(1) == "ranger"
		and view.sim.unit_position(1) == Vector2i(tap_cell.x * 1000 + 500, tap_cell.y * 1000 + 500),
		"a tap deployed a Ranger on %s (%d units)" % [tap_cell, view.sim.unit_count()])
	var blocked := Vector2i(2, 2)
	check(view.is_masked(blocked), "%s is red in the deploy mask" % blocked)
	view.input.tapped.emit(_screen(main, view, blocked))
	check(view.sim.unit_count() == 1 and hud.toast_text() == "Can't deploy there",
		"a tap in the zone deploys nothing: '%s'" % hud.toast_text())
	# The cards count on the sim's step, which a fixed number of frames may not reach.
	await view.stepped
	check(hud.card_count("ranger") == "x%d" % (int(ARMY["ranger"]) - 1), "the Ranger's card counts down: %s"
		% hud.card_count("ranger"))
	await screenshot("tick-%d" % CLOSE_TICKS[0])

	# A drag over SMEAR cells in a row deploys one a cell, one a tick at most.
	var row: Array[Vector2i] = []
	for cell: Variant in spots[1]:
		var at: Vector2i = cell
		if at.y == (spots[1][0] as Vector2i).y and row.size() < SMEAR:
			row.append(at)
	var start := view.sim.unit_count()
	var tick := view.sim.tick
	view.input.drag_started.emit(_screen(main, view, row[0]))
	for k: int in range(1, row.size()):
		view.input.dragged.emit(_screen(main, view, row[k]), _screen(main, view, row[k]) - _screen(main, view, row[k - 1]))
	view.input.drag_ended.emit(_screen(main, view, row[row.size() - 1]))
	while view.sim.unit_count() < start + row.size() and view.sim.tick < tick + 4 * SMEAR:
		await frames(1)
	check(row.size() == SMEAR and view.sim.unit_count() == start + SMEAR and view.sim.tick - tick >= SMEAR,
		"a drag over %d cells deployed %d Rangers over %d ticks" % [row.size(), view.sim.unit_count() - start,
		view.sim.tick - tick])
	await screenshot("smear")

	# Back and forth over two cells side by side: each cell takes one unit, however often crossed.
	var pair: Array[Vector2i] = []
	for cell: Variant in spots[2]:
		var at: Vector2i = cell
		if pair.is_empty() and view.sim.is_deploy_cell(at + Vector2i.RIGHT):
			pair = [at, at + Vector2i.RIGHT]
	start = view.sim.unit_count()
	tick = view.sim.tick
	var a := _screen(main, view, pair[0])
	var b := _screen(main, view, pair[1])
	view.input.drag_started.emit(a)
	for k: int in 4:
		view.input.dragged.emit(b if k % 2 == 0 else a, (b - a) * (1.0 if k % 2 == 0 else -1.0))
	view.input.drag_ended.emit(a)
	while view.sim.tick < tick + 4 * SMEAR:
		await frames(1)
	check(pair.size() == 2 and view.sim.unit_count() == start + BACK_AND_FORTH,
		"a drag back and forth over %s deployed %d (expected %d)" % [pair, view.sim.unit_count() - start, BACK_AND_FORTH])

	await _until_tick(view, ALL_DOWN)
	check(view.sim.unit_count() == n + BY_HUD and view.units.drawn() > 0,
		"all %d units but the one kept back deployed (%d), %d drawn" % [n + BY_HUD, view.sim.unit_count(),
		view.units.drawn()])
	if harness.headless:
		say("the battle's draw calls and frame time skipped (headless)")
	else:
		var window := main.get_window().size
		main.get_window().size = MEASURE
		view.speed = 0
		await _measure(main, view)
		view.speed = 1
		main.get_window().size = window
	zoom_to(main, CLOSE_ZOOM, focus)
	await _until_tick(view, CLOSE_TICKS[1])
	await screenshot("tick-%d" % CLOSE_TICKS[1])
	await _cast_abilities(main, view, hud)
	check(hud.timer_text() == "%d:%02d" % [view.sim.seconds_left() / 60, view.sim.seconds_left() % 60]
		and hud.destruction_text() == "%d%%" % view.sim.destruction_pct()
		and hud.stars_lit() == view.sim.stars(),
		"the top bar: %s, %s, %d stars" % [hud.timer_text(), hud.destruction_text(), hud.stars_lit()])

	hud.speed_button().pressed.emit()
	check(view.speed == 2 and hud.speed_button().text == "2x", "the speed button runs the battle at 2x")
	zoom_to(main, IsoCamera.MAX_ZOOM_SIZE, Vector3.ZERO)
	await _until_tick(view, LATE_TICK)
	if not view.sim.is_over():
		await screenshot("tick-%d" % LATE_TICK)
		hud.end_button().pressed.emit()
		await frames(2)
		check(hud.is_confirm_open() and not view.sim.is_over(), "End asks before it ends the battle")
		# A real touch beside the open confirmation, on a deploy cell with the kept Ranger selected,
		# reaches nothing.
		var units_now := view.sim.unit_count()
		var beside: Vector2i = spots[0][0]
		await tap_screen(main, _screen(main, view, beside))
		check(view.deploy_unit == "ranger" and view.sim.left_to_deploy("ranger") == KEPT
			and view.sim.unit_count() == units_now and hud.is_confirm_open(),
			"a touch beside the open confirmation deploys nothing (%d units)" % view.sim.unit_count())
		await screenshot("confirm")
		hud.keep_button().pressed.emit()
		check(not hud.is_confirm_open() and not view.sim.is_over(), "Keep fighting goes back to the battle")
		hud.end_button().pressed.emit()
		hud.confirm_end_button().pressed.emit()
		check(view.sim.is_over(), "End battle surrenders")
	while not view.sim.is_over():
		await frames(1)
	await frames(4)
	var lines := hud.result_lines()
	check(lines.has("Abilities used") and lines.has("Orbital Strike x1") and lines.has("EMP Burst x1")
		and lines.has("Repair Swarm x1"), "the result panel lists the abilities used")
	check(hud.is_result_open() and not hud.deploy_bar().visible, "the result panel replaces the deploy bar: %s"
		% ", ".join(hud.result_lines()))
	await screenshot("end")
	var step := view.step_ms()
	say("the battle: %d ticks, destruction %d%%, %d stars, loot %s; the sim's step %.3f ms on average, %.3f ms at the longest (tick %d)"
		% [view.sim.tick, view.sim.destruction_pct(), view.sim.stars(), view.sim.loot(), step.x, step.y,
		view.slowest_tick()])
	check(step.x <= STEP_CEILING, "the sim's step averages under %.0f ms (%.3f)" % [STEP_CEILING, step.x])
	check(view.sim.destruction_pct() > 0, "something fell (%d%%)" % view.sim.destruction_pct())
	await frames(30)
	check(not _finished, "the battle stays until Return")
	hud.return_button().pressed.emit()
	while not _finished:
		await frames(1)

	var replay := setup.duplicate(true)
	replay["commands"] = _result.get("commands", [])
	var headless := BattleSim.run(catalog, replay)
	check(JSON.stringify(headless) == JSON.stringify(_result),
		"the view's result equals a headless run of its setup and commands (hash %d)" % int(_result.get("hash", 0)))
	var deployed := 0
	var by_unit: Dictionary = _result.get("deployed", {})
	for unit: String in by_unit:
		deployed += int(by_unit[unit])
	check(deployed == n + BY_HUD, "%d units deployed in the result" % deployed)
	await frames(2)
	check(main.battle == null and main.battle_hud == null and main.base_view.is_inside_tree()
		and main.world_input.is_inside_tree() and main.hud.visible and main.hud.toast_text() == "Practice: nothing applied",
		"the base came back: '%s'" % main.hud.toast_text())
	check(is_equal_approx(main.camera.size, zoom) and main.camera.focus.is_equal_approx(focus_before),
		"the camera is back where it was over the base: size %.1f (%.1f)" % [main.camera.size, zoom])
	check(_kept(main.state) == before, "the base's buildings, resources, army and raids are as they were")
	await frames(4)
	await screenshot("back")

	# Every unit type and every ability brought, one each: both bars stay left of the Build column,
	# the deploy bar scrolling in what the abilities bar leaves.
	var every := {}
	for unit: String in catalog.unit_types():
		every[unit] = 1
	var wide := main.practice_setup()
	var three := {}
	for ability: String in catalog.ability_types():
		three[ability] = 1
	wide["attacker"] = {"army": every, "unit_levels": {}, "abilities": three}
	_finished = false
	check(main.open_battle(wide, true) == "", "a battle with one of every type opens")
	await frames(4)
	var bar := main.battle_hud.deploy_bar().get_global_rect()
	var safe := Hud.safe_area(main.get_viewport())
	var column := safe.end.x - Hud.MARGIN - Hud.BUILD_SIZE.x
	var abilities := main.battle_hud.ability_bar().get_global_rect()
	check(bar.end.x <= column and abilities.end.x <= column and abilities.position.x > bar.end.x,
		"with %d types and %d abilities the deploy bar ends at x %.0f and the abilities bar runs from %.0f to %.0f, left of the Build column at %.0f"
		% [every.size(), three.size(), bar.end.x, abilities.position.x, abilities.end.x, column])
	await screenshot("every-type")
	main.battle.finished.connect(func(_setup: Dictionary, _result: Dictionary) -> void: _finished = true)
	main.battle_hud.end_button().pressed.emit()
	main.battle_hud.confirm_end_button().pressed.emit()
	await frames(2)
	main.battle_hud.return_button().pressed.emit()
	while not _finished:
		await frames(1)
	await frames(2)
	check(main.battle == null, "it ends and the base comes back")


## Through the abilities bar: the strike cast on a standing defence (its marker, then its blast,
## the defence's hull down after it lands), an EMP burst on the farthest (it dims, disabled in the sim),
## and a repair swarm on a living unit (its dome); each card counts down, and selecting an ability
## lets the unit type go and hides the red zone.
func _cast_abilities(main: MainScript, view: BattleView, hud: BattleHud) -> void:
	var brought := view.abilities_brought()
	check(brought.size() == 3, "the abilities bar brings %s" % ", ".join(brought))
	for ability: String in brought:
		check(hud.ability_card(ability).is_visible_in_tree() and hud.ability_count(ability) == "x%d" % ABILITIES_EACH,
			"%s's card shows x%d (%s)" % [ability, ABILITIES_EACH, hud.ability_count(ability)])
	var defences := _standing_defences(main, view)
	check(defences.size() >= 2, "%d defences stand" % defences.size())
	if defences.size() < 2:
		return
	view.speed = 1
	# The strike.
	var target: int = defences[0]
	var hp := view.sim.building_hp(target)
	hud.ability_card("orbital_strike").pressed.emit()
	check(view.cast_ability == "orbital_strike" and view.deploy_unit == "" and view.field.deploy_strength() == 0.0,
		"the strike's card selects it, the unit let go and the red zone hidden")
	var at := _centre(main, view, target)
	zoom_to(main, CLOSE_ZOOM, at)
	var tick := view.sim.tick
	view.input.tapped.emit(main.camera.unproject_position(at))
	check(view.sim.left_to_use("orbital_strike") == ABILITIES_EACH - 1, "a tap cast the strike on the %s (id %d)"
		% [view.building_type(target), target])
	await _until_tick(view, tick + 4)
	await screenshot("strike-marker")
	await _until_tick(view, tick + 26)
	await screenshot("strike-bolt")
	await _until_tick(view, tick + 34)
	await screenshot("strike-blast")
	await _until_tick(view, tick + 41)
	await screenshot("strike-after")
	check(view.sim.is_destroyed(target) or view.sim.building_hp(target) < hp, "the strike landed: hull %d of %d"
		% [view.sim.building_hp(target), hp])
	# The EMP burst, on the standing defence farthest from the army, chosen now: one near it can
	# fall to the units while the strike lands.
	defences = _standing_defences(main, view)
	var turret: int = defences[defences.size() - 1]
	hud.ability_card("emp_burst").pressed.emit()
	at = _centre(main, view, turret)
	zoom_to(main, CLOSE_ZOOM, at)
	view.input.tapped.emit(main.camera.unproject_position(at))
	await _until_tick(view, view.sim.tick + 2)
	check(view.sim.left_to_use("emp_burst") == ABILITIES_EACH - 1 and view.sim.building_disabled(turret)
		and view.is_shown_disabled(turret), "the EMP burst disabled the %s (id %d), dimmed"
		% [view.building_type(turret), turret])
	await screenshot("emp")
	# The repair swarm, on a living unit.
	var unit := 0
	for id: int in range(1, view.sim.unit_count() + 1):
		if view.sim.unit_state(id) != BattleArmy.DEAD:
			unit = id
			break
	hud.ability_card("repair_swarm").pressed.emit()
	if unit != 0:
		at = view.units.aim_point(unit)
		at.y = 0.0
		zoom_to(main, CLOSE_ZOOM, at)
		view.input.tapped.emit(main.camera.unproject_position(at))
		await _until_tick(view, view.sim.tick + 4)
	check(view.sim.left_to_use("repair_swarm") == ABILITIES_EACH - 1, "a tap cast the swarm on unit %d" % unit)
	await screenshot("swarm")
	check(hud.ability_count("orbital_strike") == "x%d" % (ABILITIES_EACH - 1), "the cards count down")
	# Back to the Rangers, as the rest of the scenario has them.
	hud.card("ranger").pressed.emit()
	check(view.deploy_unit == "ranger" and view.cast_ability == "", "the Ranger's card takes the selection back")


## The standing, drawn defences, the nearest the first group's point first.
func _standing_defences(main: MainScript, view: BattleView) -> Array[int]:
	var found: Array[int] = []
	var near := main.base_view.cell_to_world(POINTS[0], 1)
	for id: int in view.sim.building_ids():
		if not view.sim.is_destroyed(id) and view.is_revealed_defence(id):
			found.append(id)
	found.sort_custom(func(a: int, b: int) -> bool:
		return _centre(main, view, a).distance_to(near) < _centre(main, view, b).distance_to(near))
	return found


## Building `id`'s centre on the ground.
func _centre(_main: MainScript, view: BattleView, id: int) -> Vector3:
	return view.building_centre(id)


## The screen point of `cell`'s centre on the battle's field.
func _screen(main: MainScript, view: BattleView, cell: Vector2i) -> Vector2:
	return main.camera.unproject_position(view.field.cell_to_world(cell, 1))


## What a battle could have changed in the base: its save without the clock and the production
## carried, which the game's own tick moves on as real time passes (the template base is on the
## device's clock).
func _kept(state: BaseState) -> String:
	var data := state.to_dict()
	data.erase("now")
	data.erase("remainders")
	return JSON.stringify(data)


## Waits until the battle reaches `tick` or ends.
func _until_tick(view: BattleView, tick: int) -> void:
	while view.sim.tick < tick and not view.sim.is_over():
		await frames(1)


## The battle at the widest zoom over the field: held SETTLE_SECONDS, then sampled every frame for
## SAMPLE_SECONDS, as template_base measures the base; says the most draw calls and primitives in a
## frame, the render thread's CPU time a frame on average, the slowest frame's process time, the
## frame rate and the units drawn, and checks the first three against the ceilings.
func _measure(main: MainScript, view: BattleView) -> void:
	zoom_to(main, IsoCamera.MAX_ZOOM_SIZE, Vector3.ZERO)
	var viewport_rid := main.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport_rid, true)
	await main.get_tree().create_timer(SETTLE_SECONDS).timeout
	var draws := 0
	var primitives := 0
	var process := 0.0
	var render := 0.0
	var count := 0
	var drawn := 0
	var sampling := main.get_tree().create_timer(SAMPLE_SECONDS)
	while sampling.time_left > 0.0:
		await frames(1)
		draws = maxi(draws, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		primitives = maxi(primitives, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
		process = maxf(process, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		render += RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid)
		count += 1
		drawn = maxi(drawn, view.units.drawn())
	var fps := Performance.get_monitor(Performance.TIME_FPS)
	check(draws > 0 and draws <= DRAW_CALL_CEILING and primitives <= PRIMITIVE_CEILING
		and render / count <= RENDER_CPU_CEILING,
		"the battle at the widest zoom (size %.0f) in %dx%d with %d units drawn, ticks %d: %d draw calls (ceiling %d), %d primitives (ceiling %d), %.2f ms render CPU (ceiling %.1f), %.2f ms process at the slowest, %d fps over %d frames"
		% [IsoCamera.MAX_ZOOM_SIZE, MEASURE.x, MEASURE.y, drawn, view.sim.tick, draws, DRAW_CALL_CEILING, primitives,
		PRIMITIVE_CEILING, render / count, RENDER_CPU_CEILING, process, fps, count])


## The deploy cards of `units` still without a picture.
func _unpictured(hud: BattleHud, units: PackedStringArray) -> int:
	var missing := 0
	for unit: String in units:
		if hud.card_picture(unit) == null:
			missing += 1
	return missing
