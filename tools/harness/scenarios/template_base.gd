extends HarnessScenario
## The debug build's Template base (TemplateBase, main._template_base), pressed through the HUD's
## button. Checks every type but the walls exactly once, the walls the enclosure's pieces, all at
## the top level and finished; no two footprints overlapping and all inside the grid; every
## resource at its cap; every drone free, on the ring too; every moving part moving; the save
## written to the run's own file, user://base.json untouched. Screenshots: the whole base at the
## widest zoom in a WIDE window, then each band at BAND_ZOOM centred on it (the Command Center's
## with the first category's), in even parts PART_CELLS wide at most so none runs under the HUD
## or off the screen, each again a second later where a part turns.

const WIDE := Vector2i(1560, 720)
const BAND_ZOOM := 16.0
const PART_CELLS := 16
## How long the moving parts are sampled, and how many frames apart.
const MOVE_SAMPLE_SECONDS := 1.5
const MOVE_SAMPLE_FRAMES := 4


func run(main: MainScript) -> void:
	var real := MainScript.DEFAULT_SAVE_PATH
	var real_saved := func() -> int: return FileAccess.get_modified_time(real) if FileAccess.file_exists(real) else 0
	var real_saved_before: int = real_saved.call()
	main.hud.template_button().pressed.emit()
	var state: BaseState = main.state
	var catalog: Catalog = state.catalog
	var pieces := 2 * mini(TemplateBase.WALL_SIZE.x, catalog.grid_size.x) + 3 * (TemplateBase.WALL_SIZE.y - 2)
	for type: String in catalog.types():
		var expected := pieces if catalog.category_of(type) == PlacementController.PAINT_CATEGORY else 1
		check(state.count_of(type) == expected, "%d %s" % [state.count_of(type), type])
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

	# Each band's footprints, and every turning part with its pose.
	var bands := {}
	var turning := []
	for view: BuildingView in main.base_view.views.values():
		var building: BuildingState = state.buildings[view.building_id]
		var band := catalog.category_of(building.type)
		band = catalog.categories[0] if band == Catalog.CORE_CATEGORY else band
		var foot := Rect2i(building.cell, Vector2i.ONE * view.footprint_size)
		bands[band] = (bands.get(band, foot) as Rect2i).merge(foot)
		turning.append_array(view.find_children("*", "Node3D", true, false).filter(
			func(node: Node) -> bool: return node.has_meta(BuildingModels.MOVE_META)))
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
	check(moved.size() > 0 and moved.size() == turning.size(), "%d of %d moving parts moved within %.1f s"
		% [moved.size(), turning.size(), MOVE_SAMPLE_SECONDS])

	main.get_window().size = WIDE
	await _shot(main, "whole", Vector3.ZERO, IsoCamera.MAX_ZOOM_SIZE)
	for band: String in catalog.categories:
		var box: Rect2i = bands[band]
		var parts := ceili(box.size.x / float(PART_CELLS))
		for i: int in parts:
			var part := Rect2i(box.position.x + box.size.x * i / parts, box.position.y, 0, box.size.y)
			part.end.x = box.position.x + box.size.x * (i + 1) / parts
			var name := "band-%s-%d" % [band, i + 1] if parts > 1 else "band-" + band
			var at := main.base_view.cell_to_world(part.position, 0) + Vector3(part.size.x, 0, part.size.y) * 0.5
			await _shot(main, name, at, BAND_ZOOM)
			if turning.any(func(mover: Node3D) -> bool:
					return part.has_point(main.base_view.world_to_cell(mover.global_position))):
				await main.get_tree().create_timer(1.0).timeout
				await screenshot(name + "-later")


## Centres the view on `at` at camera size `size`, then screenshots it once the window caught up.
func _shot(main: MainScript, name: String, at: Vector3, size: float) -> void:
	var centre := main.get_viewport().get_visible_rect().size * 0.5
	main.camera.zoom_at(main.camera.size / size, centre)
	main.camera.pan(centre, centre - main.camera.unproject_position(at))
	await frames(6)
	await screenshot(name)
