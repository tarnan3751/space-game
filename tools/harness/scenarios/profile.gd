extends HarnessScenario
## A performance profile on the development Mac, to re-run after every change made for cost: the
## template base (Template base, pressed through the HUD: Command Center 10, every building at its
## top level) idle at camera sizes BASE_SIZES, the sector map open over it, the training panel
## open, and the practice raid on it with a full army (ARMY, 280 housing, every unit type at its
## top level) deployed in three groups spread over the deploy cells round POINTS from tick 1, as
## the battle_view scenario deploys, sampled live at camera sizes BATTLE_SIZES round each of
## BATTLE_TICKS (early, units walking and defences firing; late, rubble standing and the effects
## the fight leaves).
## The base at the widest zoom and the battle at its last tick and widest zoom are sampled again with
## the sun's shadow off.
##
## Each sample, in a MEASURE window with vsync off (so a frame's interval is its cost, not the
## display's), held SETTLE_SECONDS after the view is set (SHADOW_SETTLE_SECONDS after the shadow
## is turned off), then every frame for SAMPLE_SECONDS,
## averaged with the worst frame: the frame's interval (real time, the one clock this scenario reads,
## since it measures the machine) and its parts: the main thread from the scene's process to the
## drawing (RenderingServer.frame_pre_draw), the drawing (to frame_post_draw: the render thread's
## work, on this single-threaded renderer the main thread's), and the wait after it until the next
## process (the buffer swap, which waits for the GPU, input and physics); the Performance monitors (process and physics process time, which
## the engine reports as the worst frame of the last second, updated once a second; draw calls,
## primitives and objects in a frame, video memory, nodes, static memory and objects over the
## window), the shadow pass's draw calls and primitives (RenderingServer.viewport_get_render_info:
## the Compatibility renderer counts its primitives but not its draw calls, which the samples with
## the shadow off give), the render thread's CPU and GPU time a frame
## (viewport_set_measure_render_time; the GPU's reads 0 on the Compatibility renderer here), and
## the per-system CPU time a frame Profile sums while it is enabled (src/game/profile.gd:
## BuildingView._process over every view, BattleView._process and its sections, the sim's step,
## BattleUnits' buffer uploads, BattleEffects.draw by list group). The HUD's refresh, BaseView.sync
## and the whole `changed` chain (state.changed emitted, as a command does; then a second of
## production paid through it, advance(1)) are timed here, REPEATS calls each, as are the save's JSON, each of the sector map's outposts laid out
## by OutpostGenerator.generate called directly (the map itself lays them out on worker threads)
## and MultiMesh buffer uploads of the effect lists' sizes (UPLOAD_SIZES instances).
##
## Also logged: the triangles a frame draws by source (_split: the buildings' bodies, outlines and
## moving parts', the walls, the terrain, rocks, outcrops, perimeter and ground; in the battle the
## units' bodies and outlines, each effect list, the rubble), the shadow casters' share, from each
## visible mesh's triangle count times its instances, with the draws (a surface each); and at each battle tick, the transparent
## fill (_fill: each effect list's live instances and the projected area of their triangles, and the
## buildings' hologram surfaces', as screens' worth of alpha-blended pixels). The run ends with the
## table: one row a sample, one column a monitor or a system, and a note on which systems' keys hold
## which (NESTED). Each rendered sample checks that the window drew at least DRAWN_PERCENT of its
## frames, so a window that stopped drawing fails the run rather than logging its last frame's
## numbers. Whatever the run changed (Profile's flag, the window, vsync, the camera) is put back on
## every way out of it.
##
## Headless renders nothing: the samples and the uploads are skipped (logged), and the run checks the
## wiring only (the template laid out, the battle opened and drawn, Profile's keys collected, the
## splits counted). The effect lists are read by their member names in BattleEffects (LISTS and
## BARE, through get()), which only a profile should do.

const MEASURE := Vector2i(1600, 900)
const SETTLE_SECONDS := 1.0
const SAMPLE_SECONDS := 3.0
## The settle after the shadow is turned off: the shaders' variants without it compile first.
const SHADOW_SETTLE_SECONDS := 3.0
## The share of a sample's frames, in percent, whose drawing must have finished (frame_post_draw
## between one process and the next): a window that stops drawing fails the run.
const DRAWN_PERCENT := 99
const BASE_SIZES: Array[float] = [44.0, 24.0, 10.0]
const BATTLE_SIZES: Array[float] = [44.0, 24.0]
const BATTLE_TICKS: Array[int] = [200, 1000]
## How many ticks before a battle sample's tick the battle is slowed to 1x; at the tick itself the
## triangles and the fill are counted and the first window starts.
const BATTLE_LEAD := 20
## Seconds from the Template base press until its toast has faded (template_base's TOAST_SECONDS).
const TOAST_SECONDS := 2.5
const ARMY := {"ranger": 100, "brawler": 40, "jet_trooper": 20, "hover_tank": 5, "gunship": 2}
const SEED := 1793856615
const POINTS: Array[Vector2i] = [Vector2i(42, 9), Vector2i(40, 19), Vector2i(24, 47)]
const SPREAD := 2
## The battle's speed between samples, to reach the late tick sooner; samples run at 1.
const FAST := 3
const PRODUCER := "cadet_academy"
const REPEATS := 20
## Seconds of production paid, one at a time, for its timing (each logs a line).
const SECONDS_PAID := 3
const UPLOAD_SIZES: Array[int] = [64, 256, 384, 768]
## Floats per effect instance (BattleEffects.FLOATS).
const FLOATS := 20
## The effect lists by their member names in BattleEffects: those holding a `multimesh`, then the
## bare MultiMeshes. Debris and the walls' rubble are opaque; the rest blend.
const LISTS: Array[String] = ["_bolts", "_missiles", "_bombs", "_pulses", "_beams", "_vortices", "_debris",
	"_domes", "_markers", "_hover_markers", "_sky_bolts", "_fireballs", "_flashes", "_smoke", "_rings",
	"_sparks", "_puffs", "_glows", "_stuns", "_scorches"]
const BARE: Array[String] = ["_vortex_rings", "_impacts", "_arcs", "_wall_rubble", "_wall_rubble_outline", "_bars",
	"_shield_domes"]
const OPAQUE: Array[String] = ["_debris", "_wall_rubble", "_wall_rubble_outline"]
## The systems' columns in the table, Profile's keys.
const SYSTEMS: Array[StringName] = [&"building_views", &"battle_view", &"battle_steps", &"sim_step", &"units_draw",
	&"units_upload", &"deaths", &"aim_defences", &"draw_buildings", &"bars_upload", &"effects_draw", &"fx_flights",
	&"fx_beams_vortices", &"fx_debris", &"fx_impacts_arcs", &"fx_timed", &"walls_mask"]

## Which systems' columns hold which: never sum them.
const NESTED := "Nested keys: battle_view holds battle_steps (which holds sim_step), units_draw (which holds units_upload), deaths, aim_defences, draw_buildings, bars_upload, effects_draw (which holds every fx_*) and walls_mask; building_views is apart from battle_view."

var _rows: Array[Dictionary] = []
## Every Profile key collected, over the samples and after them.
var _seen: Dictionary[StringName, bool] = {}
## Triangles per mesh, counted once a split; and per mesh for the fill, all surfaces and the
## hologram surfaces alone, once a fill. Each is let go after its split or fill (_forget_meshes):
## a mesh held here would outlive its replacement (the merged walls', rebuilt as walls fall) and
## count in the video memory.
var _tris: Dictionary[Mesh, int] = {}
var _effect_faces: Dictionary[Mesh, PackedVector3Array] = {}
var _holo_faces: Dictionary[Mesh, PackedVector3Array] = {}


## The profile, then what it changed put back (Profile's flag, the window, vsync, the camera) on
## every way out of it, and the table.
func run(main: MainScript) -> void:
	var window := main.get_window().size
	var vsync := DisplayServer.window_get_vsync_mode()
	var zoom := main.camera.size
	var focus := main.camera.focus
	Profile.enabled = true
	Profile.take()
	if not harness.headless:
		main.get_window().size = MEASURE
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await _profile(main)
	Profile.enabled = false
	if not harness.headless:
		main.get_window().size = window
		DisplayServer.window_set_vsync_mode(vsync)
	frame_world(main, zoom, focus)
	_table()


func _profile(main: MainScript) -> void:
	main.hud.template_button().pressed.emit()
	var toast := main.get_tree().create_timer(TOAST_SECONDS)
	var state: BaseState = main.state
	var catalog: Catalog = main.catalog
	check(state.buildings.size() > 300, "the template base is laid out: %d buildings" % state.buildings.size())
	await toast.timeout
	var sun: DirectionalLight3D = null
	for child: Node in main.get_children():
		if child is DirectionalLight3D:
			sun = child as DirectionalLight3D
	check(sun != null and sun.shadow_enabled, "the sun casts its shadow")

	# The base.
	for size: float in BASE_SIZES:
		frame_world(main, size, Vector3.ZERO)
		if size == BASE_SIZES[0]:
			await frames(2)
			_split_base(main)
		await _sample(main, "base %d" % int(size))
	frame_world(main, BASE_SIZES[0], Vector3.ZERO)
	sun.shadow_enabled = false
	await _sample(main, "base %d, no shadow" % int(BASE_SIZES[0]), null, SHADOW_SETTLE_SECONDS)
	sun.shadow_enabled = true
	_holo_fill(main, main.base_view, "the base")
	_time_refreshes(main, "the base")
	_time_save(main)
	_time_uploads()

	# The sector map over the base, then the training panel.
	frame_world(main, IsoCamera.START_ZOOM_SIZE, Vector3.ZERO)
	main.hud.expedition_button().pressed.emit()
	await frames(3)
	check(main.sector_map.is_open(), "the Expedition button opened the sector map")
	_time_outposts(main)
	await _sample(main, "sector map")
	main.sector_map.close()
	await frames(3)
	var producer := _first(state, PRODUCER)
	main.placement.select(producer.id)
	await frames(2)
	main.hud.action_button().pressed.emit()
	await main.get_tree().create_timer(Hud.MENU_OPEN_SECONDS + 0.05).timeout
	check(main.hud.is_training_open(), "Train opened the %s's training panel" % PRODUCER)
	await _sample(main, "training panel")
	_time_refreshes(main, "the training panel open")
	main.hud.army_close_button().pressed.emit()
	main.placement.select(0)
	await frames(3)

	# The practice raid.
	var setup := main.practice_setup()
	var levels := {}
	for unit: String in ARMY:
		levels[unit] = catalog.unit_max_level(unit)
	setup["seed"] = SEED
	setup["attacker"] = {"army": ARMY, "unit_levels": levels, "abilities": {}, "ability_levels": {}}
	var error := main.open_battle(setup, true)
	check(error == "", "the battle opens: '%s'" % error)
	if error != "":
		return
	var view: BattleView = main.battle
	view.script_commands(_deploys(view))
	view.select_unit("")
	var last := BATTLE_TICKS[BATTLE_TICKS.size() - 1]
	for tick: int in BATTLE_TICKS:
		if harness.headless:
			break
		view.speed = FAST
		await _until_tick(view, tick - BATTLE_LEAD)
		view.speed = 1
		for size: float in BATTLE_SIZES:
			frame_world(main, size, Vector3.ZERO)
			if size == BATTLE_SIZES[0]:
				await _until_tick(view, tick)
				await frames(2)
				_split_battle(main, view, "the battle at tick %d, size %d" % [view.sim.tick, int(size)])
				_fill(main, view)
			await _sample(main, "battle t%d %d" % [tick, int(size)], view)
		if tick == last:
			frame_world(main, BATTLE_SIZES[0], Vector3.ZERO)
			sun.shadow_enabled = false
			await _sample(main, "battle t%d %d, no shadow" % [tick, int(BATTLE_SIZES[0])], view, SHADOW_SETTLE_SECONDS)
			sun.shadow_enabled = true
	if harness.headless:
		await _until_tick(view, BATTLE_LEAD)
		frame_world(main, BATTLE_SIZES[0], Vector3.ZERO)
		await frames(2)
		_split_battle(main, view, "the battle at tick %d, size %d" % [view.sim.tick, int(BATTLE_SIZES[0])])
		_fill(main, view)
		say("the samples, the shadow pass and the uploads skipped (headless)")
	check(view.units.drawn() > 0 or view.sim.is_over(), "the army is drawn: %d units" % view.units.drawn())
	for key: StringName in Profile.take():
		_seen[key] = true
	check(_seen.has(&"battle_view") and _seen.has(&"units_draw") and _seen.has(&"effects_draw") and _seen.has(&"sim_step")
		and _seen.has(&"building_views"), "Profile collected the systems: %s" % ", ".join(PackedStringArray(_seen.keys())))
	var step := view.step_ms()
	say("the sim's step over %d ticks: %.3f ms on average, %.3f ms at the longest (tick %d); %d%% destruction"
		% [view.sim.tick, step.x, step.y, view.slowest_tick(), view.sim.destruction_pct()])
	var finished := [false]
	view.finished.connect(func(_setup: Dictionary, _result: Dictionary) -> void: finished[0] = true)
	check(view.surrender() == "", "the battle surrenders")
	while not view.sim.is_over():
		await frames(1)
	view.leave()
	while not finished[0]:
		await frames(1)
	await frames(2)
	check(main.battle == null, "the battle ended and the base came back")


## The army deployed in three groups 20 ticks apart from tick 1, each spread over the deploy cells
## within SPREAD of its point (the battle_view scenario's deploys).
func _deploys(view: BattleView) -> Array[Dictionary]:
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
		for k: int in int(ARMY[unit]):
			var group: Array = spots[n % 3]
			var cell: Vector2i = group[(n / 3) % group.size()]
			commands.append({"op": "deploy", "tick": 1 + (n % 3) * 20, "unit": unit, "cell": [cell.x, cell.y]})
			n += 1
	return commands


## One sample: held SETTLE_SECONDS, then every frame for SAMPLE_SECONDS; logged and kept for the
## table. Headless, skipped.
func _sample(main: MainScript, label: String, view: BattleView = null, settle: float = SETTLE_SECONDS) -> void:
	if harness.headless:
		say("%s: skipped (headless)" % label)
		return
	var rid := main.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	await main.get_tree().create_timer(settle).timeout
	Profile.take()
	var tick_from := view.sim.tick if view != null else 0
	var memory := Performance.get_monitor(Performance.MEMORY_STATIC)
	var objects := Performance.get_monitor(Performance.OBJECT_COUNT)
	var sums := {}
	var worst := {}
	var names: Array[String] = ["frame", "main", "draw", "wait", "process", "physics", "cpu", "gpu", "draws",
		"prims", "objects", "shadow_draws", "shadow_prims"]
	for name: String in names:
		sums[name] = 0.0
		worst[name] = 0.0
	# When the frame's drawing starts and ends, against when the scene's process starts (this
	# coroutine resumes on process_frame, before the nodes' _process).
	# marks[2] counts the frames drawn, so a window that stopped drawing (covered, minimised) fails
	# the sample instead of repeating its last frame's numbers.
	var marks := PackedInt64Array([0, 0, 0])
	var pre := func() -> void: marks[0] = Time.get_ticks_usec()
	var post := func() -> void:
		marks[1] = Time.get_ticks_usec()
		marks[2] += 1
	RenderingServer.frame_pre_draw.connect(pre)
	RenderingServer.frame_post_draw.connect(post)
	var count := 0
	var drawn := 0
	await frames(1)
	var before := Time.get_ticks_usec()
	var draws_before := marks[2]
	var sampling := main.get_tree().create_timer(SAMPLE_SECONDS)
	while sampling.time_left > 0.0:
		await frames(1)
		var at := Time.get_ticks_usec()
		var values := {
			"frame": (at - before) / 1000.0,
			"main": (marks[0] - before) / 1000.0,
			"draw": (marks[1] - marks[0]) / 1000.0,
			"wait": (at - marks[1]) / 1000.0,
			"process": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			"physics": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			"cpu": RenderingServer.viewport_get_measured_render_time_cpu(rid),
			"gpu": RenderingServer.viewport_get_measured_render_time_gpu(rid),
			"draws": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"prims": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			"objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			"shadow_draws": float(RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW,
				RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)),
			"shadow_prims": float(RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW,
				RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)),
		}
		before = at
		if marks[2] > draws_before:
			drawn += 1
		draws_before = marks[2]
		for name: String in names:
			var value: float = values[name]
			sums[name] = float(sums[name]) + value
			worst[name] = maxf(float(worst[name]), value)
		count += 1
	RenderingServer.frame_pre_draw.disconnect(pre)
	RenderingServer.frame_post_draw.disconnect(post)
	check(count > 0 and drawn * 100 >= count * DRAWN_PERCENT,
		"%s: the window drew %d of %d frames (at least %d%% needed)" % [label, drawn, count, DRAWN_PERCENT])
	var systems := Profile.take()
	for key: StringName in systems:
		_seen[key] = true
	var row := {"label": label, "frames": count}
	for name: String in names:
		row[name] = float(sums[name]) / maxi(count, 1)
		row[name + "_max"] = worst[name]
	row["vmem"] = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	row["nodes"] = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	row["static"] = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	row["static_delta"] = (Performance.get_monitor(Performance.MEMORY_STATIC) - memory) / 1024.0
	row["objects_delta"] = int(Performance.get_monitor(Performance.OBJECT_COUNT) - objects)
	row["ticks"] = "%d-%d" % [tick_from, view.sim.tick] if view != null else ""
	var parts := PackedStringArray()
	for key: StringName in SYSTEMS:
		if systems.has(key):
			var spent: Vector2i = systems[key]
			row[key] = spent.x / 1000.0 / maxi(count, 1)
			parts.append("%s %.3f ms (%.1f calls)" % [key, float(row[key]), float(spent.y) / maxi(count, 1)])
	_rows.append(row)
	say("%s%s: %d frames, frame %.2f ms (worst %.2f): main thread %.2f, drawing %.2f, waiting %.2f; process at the worst in a second %.2f (worst %.2f), physics %.2f, render CPU %.2f (worst %.2f), GPU %.2f (worst %.2f); %.0f draw calls (worst %.0f, shadow %.0f), %.0f primitives (worst %.0f, shadow %.0f), %.0f objects; video %.1f MB, %d nodes, static %.1f MB (%+.1f KB, %+d objects over the window)"
		% [label, " (ticks %s)" % row["ticks"] if view != null else "", count, row["frame"], row["frame_max"],
		row["main"], row["draw"], row["wait"], row["process"], row["process_max"], row["physics"], row["cpu"], row["cpu_max"], row["gpu"], row["gpu_max"],
		row["draws"], row["draws_max"], row["shadow_draws"], row["prims"], row["prims_max"], row["shadow_prims"],
		row["objects"], row["vmem"], row["nodes"], row["static"], row["static_delta"], row["objects_delta"]])
	if not parts.is_empty():
		say("%s: per frame %s" % [label, ", ".join(parts)])


## The HUD's refresh, BaseView.sync, the whole `changed` chain and a second of production paid
## through it (as the game's tick pays it, with the HUD's meters moving), REPEATS calls each, timed.
func _time_refreshes(main: MainScript, when: String) -> void:
	var state: BaseState = main.state
	var started := Time.get_ticks_usec()
	for k: int in REPEATS:
		main.hud.refresh(state, main.placement.selected_id, false, false, false)
	var hud := (Time.get_ticks_usec() - started) / 1000.0 / REPEATS
	started = Time.get_ticks_usec()
	for k: int in REPEATS:
		main.base_view.sync(state)
	var sync := (Time.get_ticks_usec() - started) / 1000.0 / REPEATS
	started = Time.get_ticks_usec()
	for k: int in REPEATS:
		state.changed.emit()
	var changed := (Time.get_ticks_usec() - started) / 1000.0 / REPEATS
	started = Time.get_ticks_usec()
	for k: int in SECONDS_PAID:
		advance(1)
	var second := (Time.get_ticks_usec() - started) / 1000.0 / SECONDS_PAID
	say("with %s: Hud.refresh %.3f ms, BaseView.sync %.3f ms, the whole changed chain %.3f ms (%d calls each), a second's production paid through it (advance(1)) %.3f ms (%d calls)"
		% [when, hud, sync, changed, REPEATS, second, SECONDS_PAID])


## The save main.gd writes every SAVE_EVERY_TICKS seconds: the state to a dictionary and to JSON
## (the file's write is not timed), REPEATS times.
func _time_save(main: MainScript) -> void:
	var started := Time.get_ticks_usec()
	var size := 0
	for k: int in REPEATS:
		size = JSON.stringify(main.state.to_dict(), "\t").length()
	say("the save: to_dict and JSON.stringify %.3f ms a call (%d KB of text)"
		% [(Time.get_ticks_usec() - started) / 1000.0 / REPEATS, size / 1024])


## Each field of the sector laid out by OutpostGenerator.generate, called directly on the main thread:
## the generator's own cost, which the sector map pays on worker threads (SectorMap.LayoutJob).
func _time_outposts(main: MainScript) -> void:
	var parts := PackedStringArray()
	for index: int in main.catalog.expedition_field_count():
		var started := Time.get_ticks_usec()
		OutpostGenerator.generate(main.catalog, main.state, index)
		parts.append("%.1f" % ((Time.get_ticks_usec() - started) / 1000.0))
	say("OutpostGenerator.generate called directly, one field each: %s ms" % ", ".join(parts))


## A MultiMesh buffer upload (an effect list's each frame) of each of UPLOAD_SIZES instances,
## REPEATS times, timed on the main thread.
func _time_uploads() -> void:
	if harness.headless:
		return
	var parts := PackedStringArray()
	for size: int in UPLOAD_SIZES:
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.use_custom_data = true
		multimesh.mesh = BoxMesh.new()
		multimesh.instance_count = size
		var data := PackedFloat32Array()
		data.resize(size * FLOATS)
		var started := Time.get_ticks_usec()
		for k: int in REPEATS:
			data[0] = float(k)
			multimesh.buffer = data
		parts.append("%d instances (%d KB) %.1f us" % [size, size * FLOATS * 4 / 1024,
			float(Time.get_ticks_usec() - started) / REPEATS])
	say("a MultiMesh buffer upload: %s" % ", ".join(parts))


## Triangles a frame of the base by source, and the shadow casters' share.
func _split_base(main: MainScript) -> void:
	var out: Dictionary[String, Vector4i] = {}
	_split_field(main.base_view, out)
	for view: BuildingView in main.base_view.views.values():
		_split_building(view, view, out)
	_say_split("the base at size %d" % int(main.camera.size), out)
	_forget_meshes()


## Triangles a frame of the battle by source.
func _split_battle(_main: MainScript, view: BattleView, label: String) -> void:
	var out: Dictionary[String, Vector4i] = {}
	_split_field(view.field, out)
	var names := _list_names(view.effects)
	for child: Node in view.get_children():
		if child == view.field:
			continue
		if child == view.effects:
			for node: Node in child.get_children():
				if node is MultiMeshInstance3D:
					var instance := node as MultiMeshInstance3D
					_add(out, "effects " + names.get(instance.multimesh, "?"), instance)
		elif child == view.units:
			for node: Node in child.get_children():
				if node is MultiMeshInstance3D:
					var instance := node as MultiMeshInstance3D
					var outline := instance.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					_add(out, "units outline" if outline else "units body", instance)
		elif child is BuildingView:
			_split_building(child as BuildingView, child, out)
		else:
			_split_tree(child, out)
	_say_split(label, out)
	_forget_meshes()


## The rest of the battle's children: the buildings' root (BuildingViews, the traps hidden until
## they spring) and the rubble.
func _split_tree(node: Node, out: Dictionary[String, Vector4i]) -> void:
	for child: Node in node.get_children():
		if child is BuildingView:
			_split_building(child as BuildingView, child, out)
		elif child is GeometryInstance3D:
			_add(out, "rubble", child as GeometryInstance3D)
			_split_tree(child, out)
		else:
			_split_tree(child, out)


## A field's scenery and walls, by node.
func _split_field(field: BaseView, out: Dictionary[String, Vector4i]) -> void:
	var named := {field.terrain: "terrain", field.terrain_outline: "terrain outline", field.rocks: "rocks",
		field.rocks_outline: "rocks outline", field.outcrops: "outcrops", field.outcrops_outline: "outcrops outline",
		field.boundary: "perimeter", field.boundary_outline: "perimeter outline"}
	for child: Node in field.get_children():
		if child is BuildingView:
			continue
		if child == field.walls:
			_add(out, "walls", field.walls.body)
			_add(out, "walls outline", field.walls.outline)
			continue
		if child is GeometryInstance3D:
			_add(out, named.get(child, "ground and other"), child as GeometryInstance3D)


## A building's meshes: its bodies and outlines, its moving parts' apart.
func _split_building(node: Node, view: BuildingView, out: Dictionary[String, Vector4i], moving: bool = false) -> void:
	for child: Node in node.get_children():
		var mover := moving or child.has_meta(BuildingModels.MOVE_META)
		if child is MeshInstance3D:
			var outline := child.has_meta(BuildingModels.OUTLINE_META)
			_add(out, "%s %s" % ["movers" if mover else "buildings", "outline" if outline else "body"],
				child as MeshInstance3D)
		elif child is GeometryInstance3D:
			_add(out, "buildings other", child as GeometryInstance3D)
		_split_building(child, view, out, mover)


## Adds a visible instance's triangles (times its MultiMesh's instances) and draws (a surface each,
## a MultiMesh's while it shows any) under `key`: (triangles drawn, cast; draws, shadow draws).
func _add(out: Dictionary[String, Vector4i], key: String, node: GeometryInstance3D) -> void:
	if node == null or not node.is_visible_in_tree():
		return
	var triangles := 0
	var draws := 0
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		triangles = _triangles(mesh)
		draws = mesh.get_surface_count() if mesh != null else 0
	elif node is MultiMeshInstance3D:
		var multimesh := (node as MultiMeshInstance3D).multimesh
		if multimesh != null and multimesh.mesh != null:
			var shown := multimesh.instance_count if multimesh.visible_instance_count < 0 else multimesh.visible_instance_count
			triangles = _triangles(multimesh.mesh) * shown
			draws = multimesh.mesh.get_surface_count() if shown > 0 else 0
	var casts := node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var had: Vector4i = out.get(key, Vector4i.ZERO)
	out[key] = had + Vector4i(triangles, triangles if casts else 0, draws, draws if casts else 0)


func _triangles(mesh: Mesh) -> int:
	if mesh == null:
		return 0
	if _tris.has(mesh):
		return _tris[mesh]
	var count := 0
	for surface: int in mesh.get_surface_count():
		if mesh is ArrayMesh:
			var array_mesh := mesh as ArrayMesh
			var indices := array_mesh.surface_get_array_index_len(surface)
			count += (indices if indices > 0 else array_mesh.surface_get_array_len(surface)) / 3
		else:
			var arrays := mesh.surface_get_arrays(surface)
			var index: Variant = arrays[Mesh.ARRAY_INDEX]
			if index != null and (index as PackedInt32Array).size() > 0:
				count += (index as PackedInt32Array).size() / 3
			else:
				count += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	_tris[mesh] = count
	return count


func _say_split(label: String, out: Dictionary[String, Vector4i]) -> void:
	var keys: Array[String] = []
	keys.assign(out.keys())
	keys.sort_custom(func(a: String, b: String) -> bool: return out[a].x > out[b].x)
	var total := Vector4i.ZERO
	var parts := PackedStringArray()
	for key: String in keys:
		total += out[key]
		if out[key].x > 0:
			parts.append("%s %d (%d cast; %d draws, %d shadow)" % [key, out[key].x, out[key].y, out[key].z, out[key].w])
	say("triangles of %s: %d drawn, %d casting the shadow; %d draws, %d into the shadow (a surface each, opaque and transparent passes as one); %s"
		% [label, total.x, total.y, total.z, total.w, ", ".join(parts)])
	check(total.x > 0, "the split of %s counted triangles" % label)


## Each effect list's MultiMesh by its member name; checks every name still resolves, so a renamed
## member fails the run instead of dropping out of the counts (or an opaque list counting as fill).
func _list_names(effects: BattleEffects) -> Dictionary:
	var names := {}
	var missing := PackedStringArray()
	for name: String in LISTS:
		var list: Object = effects.get(name)
		var multimesh: Variant = list.get("multimesh") if list != null else null
		if multimesh is MultiMesh:
			names[multimesh] = name.trim_prefix("_")
		else:
			missing.append(name)
	for name: String in BARE:
		var multimesh: Variant = effects.get(name)
		if multimesh is MultiMesh:
			names[multimesh] = name.trim_prefix("_")
		else:
			missing.append(name)
	check(missing.is_empty(), "every effect list named in LISTS and BARE has its MultiMesh (missing: %s)"
		% ", ".join(missing))
	return names


## The transparent fill at this frame: each blending effect list's live instances and the screen
## area their triangles cover, and the buildings' hologram surfaces', in screens' worth (_area).
func _fill(main: MainScript, view: BattleView) -> void:
	var screen := main.get_viewport().get_visible_rect().size
	var names := _list_names(view.effects)
	var parts := PackedStringArray()
	var total := 0.0
	for node: Node in view.effects.get_children():
		if not node is MultiMeshInstance3D:
			continue
		var instance := node as MultiMeshInstance3D
		var multimesh := instance.multimesh
		var name: String = names.get(multimesh, "?")
		var shown := multimesh.visible_instance_count
		if shown <= 0 or OPAQUE.has("_" + name):
			continue
		var faces := _faces(multimesh.mesh, false)
		var area := 0.0
		for i: int in shown:
			area += _area(main, instance.global_transform * multimesh.get_instance_transform(i), faces, screen)
		total += area
		parts.append("%s %d (%.2f)" % [name, shown, area])
	say("the transparent effects at tick %d, size %d: %.2f screens of alpha-blended fill; %s"
		% [view.sim.tick, int(main.camera.size), total, ", ".join(parts)])
	_holo_fill(main, view, "the battle at tick %d" % view.sim.tick)


## The hologram surfaces (MaterialKit.holo) under `root` and their screen area, in screens' worth.
func _holo_fill(main: MainScript, root: Node, label: String) -> void:
	var screen := main.get_viewport().get_visible_rect().size
	var found := [0, 0.0]
	_holo_walk(main, root, screen, found)
	say("the hologram surfaces of %s at size %d: %d meshes, %.2f screens of alpha-blended fill"
		% [label, int(main.camera.size), int(found[0]), float(found[1])])
	_forget_meshes()


## Lets go of every mesh the splits and the fills counted (_tris and the faces).
func _forget_meshes() -> void:
	_tris.clear()
	_effect_faces.clear()
	_holo_faces.clear()


func _holo_walk(main: MainScript, node: Node, screen: Vector2, found: Array) -> void:
	for child: Node in node.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).is_visible_in_tree():
			var instance := child as MeshInstance3D
			var faces := _faces(instance.mesh, true)
			if not faces.is_empty():
				found[0] = int(found[0]) + 1
				found[1] = float(found[1]) + _area(main, instance.global_transform, faces, screen)
		_holo_walk(main, child, screen, found)


## A mesh's triangles, three points each: its hologram surfaces' only when `holo`. Counted once a fill.
func _faces(mesh: Mesh, holo: bool) -> PackedVector3Array:
	var faces := PackedVector3Array()
	if mesh == null:
		return faces
	var cache := _holo_faces if holo else _effect_faces
	if cache.has(mesh):
		return cache[mesh]
	for surface: int in mesh.get_surface_count():
		if holo and mesh.surface_get_material(surface) != MaterialKit.holo():
			continue
		var arrays := mesh.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var index: Variant = arrays[Mesh.ARRAY_INDEX]
		if index != null and (index as PackedInt32Array).size() > 0:
			for i: int in index as PackedInt32Array:
				faces.append(points[i])
		else:
			faces.append_array(points)
	cache[mesh] = faces
	return faces


## The share of the screen `faces` under `xform` cover, every triangle's projected area summed, so
## overlaps count again as the fill does: the larger of the two windings' sums, a closed mesh's
## front faces (the vertex shaders' billboards and swells are not seen here).
func _area(main: MainScript, xform: Transform3D, faces: PackedVector3Array, screen: Vector2) -> float:
	if xform.basis.determinant() == 0.0:
		return 0.0
	var one_way := 0.0
	var other_way := 0.0
	for i: int in range(0, faces.size() - 2, 3):
		var a := main.camera.unproject_position(xform * faces[i])
		var b := main.camera.unproject_position(xform * faces[i + 1])
		var c := main.camera.unproject_position(xform * faces[i + 2])
		var twice := (b - a).cross(c - a)
		if twice > 0.0:
			one_way += twice * 0.5
		else:
			other_way -= twice * 0.5
	return maxf(one_way, other_way) / (screen.x * screen.y)


func _first(state: BaseState, type: String) -> BuildingState:
	for id: int in state.buildings:
		if state.buildings[id].type == type:
			return state.buildings[id]
	return null


func _until_tick(view: BattleView, tick: int) -> void:
	while view.sim.tick < tick and not view.sim.is_over():
		await frames(1)


## The table: one row a sample; the monitors a frame on average (the worst after a slash), then the
## systems' CPU a frame in milliseconds.
func _table() -> void:
	if _rows.is_empty():
		return
	var header := PackedStringArray(["sample", "frames", "frame ms", "main / draw / wait ms", "process ms (worst a second)", "physics ms", "render CPU ms",
		"GPU ms", "draws (shadow)", "kprims (shadow)", "objects", "video MB", "nodes", "static MB (KB over)"])
	for key: StringName in SYSTEMS:
		header.append(String(key))
	say("| " + " | ".join(header) + " |")
	for row: Dictionary in _rows:
		var cells := PackedStringArray([row["label"], str(row["frames"]),
			"%.2f / %.2f" % [row["frame"], row["frame_max"]],
			"%.2f / %.2f / %.2f" % [row["main"], row["draw"], row["wait"]],
			"%.2f / %.2f" % [row["process"], row["process_max"]],
			"%.2f" % row["physics"],
			"%.2f / %.2f" % [row["cpu"], row["cpu_max"]],
			"%.2f / %.2f" % [row["gpu"], row["gpu_max"]],
			"%.0f (%.0f)" % [row["draws"], row["shadow_draws"]],
			"%.0f (%.0f)" % [float(row["prims"]) / 1000.0, float(row["shadow_prims"]) / 1000.0],
			"%.0f" % row["objects"], "%.1f" % row["vmem"], str(row["nodes"]),
			"%.1f (%+.0f)" % [row["static"], row["static_delta"]]])
		for key: StringName in SYSTEMS:
			cells.append("%.3f" % float(row[key]) if row.has(key) else "-")
		say("| " + " | ".join(cells) + " |")
	say(NESTED)
