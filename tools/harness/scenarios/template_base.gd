extends HarnessScenario
## The debug build's Template base (TemplateBase, main._template_base), pressed through the HUD's
## button. Checks every type at its count for the top Command Center level, all at the top level
## and finished; no two footprints overlapping and all inside the grid; every wall
## (PlacementController.PAINT_TYPE) joined to another (each is part of a fence); every resource
## at its cap; every drone free, on the ring too; every moving part moving (a node's pose changing,
## a part folded into its body unheld, BuildingModels.hold, and carrying a motion that moves), but
## for the aiming parts whose idle is still by design (_idles); the save written to
## the run's own file, user://base.json untouched. Screenshots: the whole base at the widest zoom
## in a WIDE window, then each band, framed on its buildings but the walls, with the fence under
## it (the Command Center's with the first category's), in even parts
## PART_CELLS wide at most, each centred and at BAND_ZOOM or as far out as it takes for the part
## and its models, as tall as the band's tallest, to fill no more than FILL of the screen, so none
## runs under the HUD or off the
## screen; each again a second later where a part turns. The first shot waits until the
## "Template base" toast, which covers the Command Center's antenna, has faded. Before the shots,
## rendered only, the whole base is measured in a MEASURE window at the widest zoom and at the
## start zoom (_measure): the draw calls and primitives in a frame, the render thread's CPU time a
## frame, the slowest frame's process time and the frame rate, the first three checked against the
## ceilings below.

const WIDE := Vector2i(1560, 720)
const BAND_ZOOM := 16.0
const PART_CELLS := 16
## The share of the screen a band part may fill (its models framed at the band's tallest).
const FILL := 0.7
## How long the moving parts are sampled, and how many frames apart.
const MOVE_SAMPLE_SECONDS := 1.5
const MOVE_SAMPLE_FRAMES := 4
## Seconds from the press until the HUD's toast has faded (Hud.show_message: 1.8 s shown, then
## 0.6 s fading out).
const TOAST_SECONDS := 2.5
## The window the whole base is measured in, how long each zoom is held before the monitors are
## read (Performance.TIME_FPS counts the last whole second, as in model_gallery), and how long
## they are sampled.
const MEASURE := Vector2i(1600, 900)
const SETTLE_SECONDS := 2.1
const SAMPLE_SECONDS := 3.0
## Ceilings for the whole base on the development Mac, set generously over its measured figures
## (docs/reference/art-style.md, **Cost**), so a regression shows: draw calls and primitives in a
## frame, and the render thread's CPU time a frame on average, in milliseconds.
const DRAW_CALL_CEILING := 1600
const PRIMITIVE_CEILING := 2100000
const RENDER_CPU_CEILING := 6.0


func run(main: MainScript) -> void:
	var real := MainScript.DEFAULT_SAVE_PATH
	var real_saved := func() -> int: return FileAccess.get_modified_time(real) if FileAccess.file_exists(real) else 0
	var real_saved_before: int = real_saved.call()
	main.hud.template_button().pressed.emit()
	var toast := main.get_tree().create_timer(TOAST_SECONDS)
	var state: BaseState = main.state
	var catalog: Catalog = state.catalog
	for type: String in catalog.types():
		var expected := catalog.max_count(type, catalog.max_cc_level())
		check(state.count_of(type) == expected, "%d of %d %s" % [state.count_of(type), expected, type])
	var grid := BaseGrid.new(catalog.grid_size.x, catalog.grid_size.y)
	var fits := true
	var topped := 0
	for building: BuildingState in state.buildings.values():
		var size := catalog.size_of(building.type)
		fits = fits and grid.is_free(building.cell, size)
		grid.occupy(building.id, building.cell, size)
		topped += 1 if building.level == catalog.max_level(building.type) and not building.is_busy() else 0
	check(fits and topped == state.buildings.size(),
		"%d of %d at the top level and finished, none overlapping or off the grid" % [topped, state.buildings.size()])
	var walls := 0
	var joined := 0
	for building: BuildingState in state.buildings.values():
		if building.type != PlacementController.PAINT_TYPE:
			continue
		walls += 1
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: BuildingState = state.buildings.get(grid.occupant_at(building.cell + step))
			if next != null and next.type == PlacementController.PAINT_TYPE:
				joined += 1
				break
	check(walls > 0 and joined == walls, "%d of %d walls joined to another" % [joined, walls])
	for res: String in catalog.resources:
		var cap := state.capacity(res)
		check(state.resources[res] == cap, "%s %d of a cap of %d" % [res, state.resources[res], cap])
	var ring := Vector2i(main.hud.drones_panel().free_count(), main.hud.drones_panel().total_count())
	check(state.builders_total() > 0 and state.builders_free() == state.builders_total() and ring.x == ring.y
		and ring.y == state.builders_total(), "%d of %d drones free, %s on the ring" % [state.builders_free(),
		state.builders_total(), ring])
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(main.save_path))
	check(main.save_path == harness.save_path and (saved["buildings"] as Array).size() == state.buildings.size()
		and real_saved.call() == real_saved_before, "saved to %s, %s untouched" % [main.save_path, real])

	# Each band's footprints, the walls' left out (they are the fences), and every turning part
	# with its pose.
	var bands := {}
	var tallest := {}
	var turning := []
	# The models whose idle parts are folded into their bodies, which the shaders move unless held.
	var folding := []
	for view: BuildingView in main.base_view.views.values():
		var building: BuildingState = state.buildings[view.building_id]
		var band := catalog.category_of(building.type)
		band = catalog.categories[0] if band == Catalog.CORE_CATEGORY else band
		var foot := Rect2i(building.cell, Vector2i.ONE * view.footprint_size)
		if building.type != PlacementController.PAINT_TYPE:
			bands[band] = (bands.get(band, foot) as Rect2i).merge(foot)
			tallest[band] = maxf(float(tallest.get(band, 0.0)), view.site_height())
		turning.append_array(view.find_children("*", "Node3D", true, false).filter(
			func(node: Node) -> bool: return node.has_meta(BuildingModels.MOVE_META)))
		folding.append_array(view.find_children("*", "Node3D", true, false).filter(
			func(node: Node) -> bool: return node.has_meta(BuildingModels.FOLDS_META)))
	# An aiming part whose idle Motion is still (a swing of zero degrees: the railgun's rails, the
	# orbital cannon's mount and the tower riding it) moves only as it aims in battle.
	var still := turning.filter(func(mover: Node3D) -> bool: return not _idles(mover))
	turning = turning.filter(func(mover: Node3D) -> bool: return _idles(mover))
	# A part may hold still for a while (a hammer's hold) or come back to its first pose on a
	# whole period, so each is sampled every few frames over a second and a half and passes once
	# any sample differs from its first pose.
	var poses := turning.map(func(mover: Node3D) -> Transform3D: return mover.transform)
	var moved := {}
	var sampling := main.get_tree().create_timer(MOVE_SAMPLE_SECONDS)
	while sampling.time_left > 0.0:
		await frames(MOVE_SAMPLE_FRAMES)
		for i: int in turning.size():
			if not (turning[i] as Node3D).transform.is_equal_approx(poses[i]):
				moved[i] = true
	check(moved.size() > 0 and moved.size() == turning.size(), "%d of %d moving parts moved within %.1f s (%d aiming parts still at idle by design)"
		% [moved.size(), turning.size(), MOVE_SAMPLE_SECONDS, still.size()])
	var held := folding.filter(func(model: Node3D) -> bool:
		var value: Variant = (model.get_child(0) as MeshInstance3D).get_instance_shader_parameter(BuildingModels.HOLD_PARAMETER)
		return typeof(value) == TYPE_FLOAT and value != 0.0)
	check(folding.size() > 0 and held.is_empty(), "%d of %d models with folded moving parts hold them"
		% [held.size(), folding.size()])
	var folded := 0
	var still_folded := 0
	for model: Node3D in folding:
		for motion: Motion in _folded_motions((model.get_child(0) as MeshInstance3D).mesh):
			folded += 1
			still_folded += 0 if (motion.rate if motion.kind == Motion.Kind.SPIN else motion.amplitude) != 0.0 else 1
	check(folded > 0 and still_folded == 0, "%d of %d folded moving parts carry no motion (Motion.from_channels)"
		% [still_folded, folded])

	if toast.time_left > 0.0:
		await toast.timeout
	if harness.headless:
		say("the whole base's draw calls and frame time skipped (headless)")
	else:
		main.get_window().size = MEASURE
		await _measure(main, "widest", IsoCamera.MAX_ZOOM_SIZE)
		await _measure(main, "start", IsoCamera.START_ZOOM_SIZE)
	main.get_window().size = WIDE
	await shot_at(main, "whole", Vector3.ZERO, IsoCamera.MAX_ZOOM_SIZE)
	for band: String in catalog.categories:
		# The band with the fence under it.
		var box: Rect2i = (bands[band] as Rect2i).grow_side(SIDE_BOTTOM, 1)
		var height: float = tallest[band]
		say("band %s: tallest model %.2f" % [band, height])
		var parts := ceili(box.size.x / float(PART_CELLS))
		for i: int in parts:
			var part := Rect2i(box.position.x + box.size.x * i / parts, box.position.y, 0, box.size.y)
			part.end.x = box.position.x + box.size.x * (i + 1) / parts
			var name := "band-%s-%d" % [band, i + 1] if parts > 1 else "band-" + band
			var at := main.base_view.cell_to_world(part.position, 0) + Vector3(part.size.x, 0, part.size.y) * 0.5
			await shot_at(main, name, at, _fit(main, part, height))
			if (turning + folding).any(func(mover: Node3D) -> bool:
					return part.has_point(main.base_view.world_to_cell(mover.global_position))):
				await main.get_tree().create_timer(1.0).timeout
				await screenshot(name + "-later")


## Whether a moving part's node moves at idle: its Motion moves (a spin at a rate, a swing or a slide
## of some amplitude), or it rides a part that does (BuildingModels.RIDES_META, an index among its
## model's moving nodes).
func _idles(mover: Node3D) -> bool:
	var motion: Motion = mover.get_meta(BuildingModels.MOVE_META)
	if (motion.rate if motion.kind == Motion.Kind.SPIN else motion.amplitude) != 0.0:
		return true
	if not mover.has_meta(BuildingModels.RIDES_META):
		return false
	var movers := mover.get_parent().get_children().filter(
		func(node: Node) -> bool: return node.has_meta(BuildingModels.MOVE_META))
	return _idles(movers[int(mover.get_meta(BuildingModels.RIDES_META))] as Node3D)


## The camera size at which `part`, `height` tall, fills FILL of the screen; BAND_ZOOM at the
## least.
func _fit(main: MainScript, part: Rect2i, height: float) -> float:
	var screen := main.get_viewport().get_visible_rect().size
	var corner := main.base_view.cell_to_world(part.position, 0)
	var box := Rect2(main.camera.unproject_position(corner), Vector2.ZERO)
	for x: int in [0, part.size.x]:
		for z: int in [0, part.size.y]:
			for y: float in [0.0, height]:
				box = box.expand(main.camera.unproject_position(corner + Vector3(x, y, z)))
	return maxf(BAND_ZOOM, main.camera.size * maxf(box.size.x / screen.x, box.size.y / screen.y) / FILL)


## Centres the view on the field at camera size `size`, holds it SETTLE_SECONDS, then samples
## every frame for SAMPLE_SECONDS: the most draw calls and primitives in a frame, the render
## thread's CPU time a frame on average, the slowest frame's process time (Performance.TIME_PROCESS
## holds the slowest of the last second) and the frame rate at the end; says them and checks the
## first three against the ceilings.
func _measure(main: MainScript, zoom: String, size: float) -> void:
	zoom_to(main, size, Vector3.ZERO)
	var viewport_rid := main.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport_rid, true)
	await main.get_tree().create_timer(SETTLE_SECONDS).timeout
	var draws := 0
	var primitives := 0
	var process := 0.0
	var render := 0.0
	var count := 0
	var sampling := main.get_tree().create_timer(SAMPLE_SECONDS)
	while sampling.time_left > 0.0:
		await frames(1)
		draws = maxi(draws, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		primitives = maxi(primitives, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
		process = maxf(process, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		render += RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid)
		count += 1
	var fps := Performance.get_monitor(Performance.TIME_FPS)
	check(draws > 0 and draws <= DRAW_CALL_CEILING and primitives <= PRIMITIVE_CEILING
		and render / count <= RENDER_CPU_CEILING,
		"the whole base at the %s zoom (size %.0f) in %dx%d: %d draw calls (ceiling %d), %d primitives (ceiling %d), %.2f ms render CPU (ceiling %.1f), %.2f ms process at the slowest, %d fps over %d frames"
		% [zoom, size, MEASURE.x, MEASURE.y, draws, DRAW_CALL_CEILING, primitives, PRIMITIVE_CEILING,
		render / count, RENDER_CPU_CEILING, process, fps, count])


## The distinct Motions the folded parts of a body carry (Surf.MOVE vertices, decoded from CUSTOM0
## and CUSTOM3 with Motion.from_channels), every surface.
func _folded_motions(mesh: Mesh) -> Array[Motion]:
	var motions: Array[Motion] = []
	var seen := {}
	for surface: int in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var uv2s: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		var first: Variant = arrays[Mesh.ARRAY_CUSTOM0]
		var second: Variant = arrays[Mesh.ARRAY_CUSTOM3]
		if typeof(first) != TYPE_PACKED_FLOAT32_ARRAY or typeof(second) != TYPE_PACKED_FLOAT32_ARRAY:
			continue
		for i: int in uv2s.size():
			if (roundi(uv2s[i].y) & Surf.MOVE) == 0:
				continue
			var c0 := Vector4(first[i * 4], first[i * 4 + 1], first[i * 4 + 2], first[i * 4 + 3])
			var c3 := Vector4(second[i * 4], second[i * 4 + 1], second[i * 4 + 2], second[i * 4 + 3])
			if not seen.has([c0, c3]):
				seen[[c0, c3]] = true
				motions.append(Motion.from_channels(c0, c3))
	return motions
