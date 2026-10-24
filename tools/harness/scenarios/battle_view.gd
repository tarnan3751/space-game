extends HarnessScenario
## The battle view (docs/reference/battle-view.md) on the debug build's Practice raid: the template
## base (Template base, pressed through the HUD) raided by a scripted army, drawn by BattleView in
## the base's place and run to its end.
##
## First the Practice raid button with the Hangars empty: refused with a toast, no battle. Then the
## practice setup (main.practice_setup) given the battle scenario's army (ARMY at LEVEL, the
## Hangars' 280 housing) and SEED, opened through main.open_battle: the base's view and input out of
## the tree, the HUD hidden. The army is deployed as the battle scenario deploys it, in three groups
## a second apart, each spread over the deploy cells within SPREAD of its point, sent live through
## BattleView.script_commands at their ticks, but one Ranger, deployed by a tap on the field (the
## view's own WorldInput). Screenshots at ticks 0 and 200 framed on the first group, at 1,000 and at
## the end at the widest zoom; rendered only, once the whole army is down, the battle is paused
## (speed 0) and measured at the widest zoom in a MEASURE window (_measure): the draw calls,
## primitives and render CPU time a frame against the Cost ceilings, the slowest frame's process
## time, the frame rate and the units drawn. The sim's step time is checked against STEP_CEILING.
## The battle runs at 1x to tick 200, then at 2x (BattleView.speed) to its end.
##
## At the end: the sim's result equals a headless BattleSim.run of the same setup with the
## commands the view sent (so the view altered nothing), the tap's deploy among them; the units
## were drawn and something fell; `finished` brought the base back (its view and input in the tree,
## the HUD shown, the toast "Practice: nothing applied"), and the base's save is as it was but for
## its clock.

const ARMY := {"ranger": 100, "brawler": 40, "jet_trooper": 20, "hover_tank": 5, "gunship": 2}
const LEVEL := 8
## The battle's seed: not BaseView.SCENERY_SEED, so the field stands in a landscape of its own.
const SEED := 1793856615
## The deploy points (the battle scenario's): open pockets right of the resources and army bands,
## and below the base.
const POINTS: Array[Vector2i] = [Vector2i(42, 9), Vector2i(40, 19), Vector2i(24, 47)]
## How far round its point a group spreads, in cells.
const SPREAD := 2
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
const ALL_DOWN := 41

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
	setup["attacker"] = {"army": ARMY, "unit_levels": levels, "abilities": {}}
	var zoom := main.camera.size
	var focus_before := main.camera.focus
	var error := main.open_battle(setup, true)
	check(error == "", "the battle opens: '%s'" % error)
	if error != "":
		return
	var view: BattleView = main.battle
	view.finished.connect(func(_setup: Dictionary, result: Dictionary) -> void:
		_result = result
		_finished = true)
	check(view.field.scenery_seed == SEED and SEED != BaseView.SCENERY_SEED and view.field.mesas != main.base_view.mesas,
		"the field stands in the landscape of the battle's seed, not the base's (mesas %s)" % [view.field.mesas])
	check(view.is_inside_tree() and not main.base_view.is_inside_tree() and not main.world_input.is_inside_tree()
		and not main.hud.visible, "the battle took the base's place: its view and input out, the HUD hidden")

	# Each group spread over the deploy cells within SPREAD of its point, so the units do not stand
	# on one another.
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
		for k: int in int(ARMY[unit]) - (1 if unit == "ranger" else 0):
			var group: Array = spots[n % 3]
			var cell: Vector2i = group[(n / 3) % group.size()]
			commands.append({"op": "deploy", "tick": (n % 3) * 20, "unit": unit, "cell": [cell.x, cell.y]})
			n += 1
	view.script_commands(commands)
	view.deploy_unit = "ranger"
	var focus := main.base_view.cell_to_world(Vector2i(38, 14), 1)
	_frame(main, CLOSE_ZOOM, focus)
	# The tapped Ranger lands on the first deploy cell beside the first group's.
	var tap_cell := POINTS[0]
	for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 1)]:
		if view.sim.is_deploy_cell(POINTS[0] + step):
			tap_cell = POINTS[0] + step
			break
	view.input.tapped.emit(main.camera.unproject_position(view.field.cell_to_world(tap_cell, 1)))
	check(view.sim.unit_count() == 1 and view.sim.unit_type(1) == "ranger"
		and view.sim.unit_position(1) == Vector2i(tap_cell.x * 1000 + 500, tap_cell.y * 1000 + 500),
		"a tap deployed a Ranger on %s (%d units)" % [tap_cell, view.sim.unit_count()])
	await frames(2)
	await screenshot("tick-%d" % CLOSE_TICKS[0])

	await _until_tick(view, ALL_DOWN)
	check(view.sim.unit_count() == n + 1 and view.units.drawn() > 0,
		"all %d units deployed (%d), %d drawn" % [n + 1, view.sim.unit_count(), view.units.drawn()])
	if harness.headless:
		say("the battle's draw calls and frame time skipped (headless)")
	else:
		var window := main.get_window().size
		main.get_window().size = MEASURE
		view.speed = 0
		await _measure(main, view)
		view.speed = 1
		main.get_window().size = window
	_frame(main, CLOSE_ZOOM, focus)
	await _until_tick(view, CLOSE_TICKS[1])
	await screenshot("tick-%d" % CLOSE_TICKS[1])

	view.speed = 2
	_frame(main, IsoCamera.MAX_ZOOM_SIZE, Vector3.ZERO)
	await _until_tick(view, LATE_TICK)
	if not view.sim.is_over():
		await screenshot("tick-%d" % LATE_TICK)
	while not view.sim.is_over():
		await frames(1)
	await frames(2)
	await screenshot("end")
	var step := view.step_ms()
	say("the battle: %d ticks, destruction %d%%, %d stars, loot %s; the sim's step %.3f ms on average, %.3f ms at the longest (tick %d)"
		% [view.sim.tick, view.sim.destruction_pct(), view.sim.stars(), view.sim.loot(), step.x, step.y,
		view.slowest_tick()])
	check(step.x <= STEP_CEILING, "the sim's step averages under %.0f ms (%.3f)" % [STEP_CEILING, step.x])
	check(view.sim.destruction_pct() > 0, "something fell (%d%%)" % view.sim.destruction_pct())
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
	check(deployed == n + 1, "%d units deployed in the result" % deployed)
	await frames(2)
	check(main.battle == null and main.base_view.is_inside_tree() and main.world_input.is_inside_tree()
		and main.hud.visible and main.hud.toast_text() == "Practice: nothing applied",
		"the base came back: '%s'" % main.hud.toast_text())
	check(is_equal_approx(main.camera.size, zoom) and main.camera.focus.is_equal_approx(focus_before),
		"the camera is back where it was over the base: size %.1f (%.1f)" % [main.camera.size, zoom])
	check(_kept(main.state) == before, "the base's buildings, resources, army and raids are as they were")
	await frames(4)
	await screenshot("back")


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


## Sets the camera to `size` with `target` at the screen's centre.
func _frame(main: MainScript, size: float, target: Vector3) -> void:
	var centre := main.get_viewport().get_visible_rect().size * 0.5
	main.camera.zoom_at(main.camera.size / size, centre)
	main.camera.pan(centre, centre - main.camera.unproject_position(target))


## The battle at the widest zoom over the field: held SETTLE_SECONDS, then sampled every frame for
## SAMPLE_SECONDS, as template_base measures the base; says the most draw calls and primitives in a
## frame, the render thread's CPU time a frame on average, the slowest frame's process time, the
## frame rate and the units drawn, and checks the first three against the ceilings.
func _measure(main: MainScript, view: BattleView) -> void:
	_frame(main, IsoCamera.MAX_ZOOM_SIZE, Vector3.ZERO)
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
