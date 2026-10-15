extends HarnessScenario
## The comic style's view states on a fresh base, each checked and screenshotted close up: the
## selected Command Center's gold outlines, the placement ghost tinted (its outline plain) on a
## free spot and on a taken one, and a new building's scaffold; the cell grid shows only with the
## ghost. Also says the fresh base's draw calls and fps.

const CLOSE_UP_SIZE := 12.0


func run(main: MainScript) -> void:
	await main.get_tree().create_timer(2.1).timeout  # TIME_FPS then covers a settled second.
	say("fresh base: %d draw calls, %d fps" % [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.TIME_FPS)])
	var centre := main.get_viewport().get_visible_rect().size * 0.5
	main.camera.zoom_at(main.camera.size / CLOSE_UP_SIZE, centre)
	var cc_id := 0
	for id: int in main.state.buildings:
		if main.state.buildings[id].type == "command_center":
			cc_id = id
	var cc: BuildingState = main.state.buildings[cc_id]
	var cc_view: BuildingView = main.base_view.views[cc_id]
	main.camera.pan(centre, centre - main.camera.unproject_position(cc_view.position))
	main.placement.select(cc_id)
	check(_all_overridden(cc_view, true, MaterialKit.ink_selected()), "the selected building's outlines are gold")
	check(not main.base_view.is_grid_shown(), "the grid is hidden with a building selected")
	await _shot("selected")
	main.placement.select(0)
	check(_all_overridden(cc_view, true, null), "deselecting clears the outline override")
	main.placement.begin_place("metal_extractor")
	var ghost: BuildingView = null
	for child: Node in main.base_view.get_children():
		if child is BuildingView and (child as BuildingView).building_id == 0:
			ghost = child
	tap_cell(main, cc.cell + Vector2i(1, 6))
	check(main.placement.ghost_is_valid() and _all_overridden(ghost, false, MaterialKit.ghost_valid())
		and _all_overridden(ghost, true, null), "the ghost on a free spot takes the valid tint, its outline plain")
	check(main.base_view.is_grid_shown(), "the grid shows while placing")
	await _shot("ghost-valid")
	tap_cell(main, cc.cell + Vector2i(1, 1))
	check(not main.placement.ghost_is_valid() and _all_overridden(ghost, false, MaterialKit.ghost_invalid()),
		"the ghost on the Command Center takes the invalid tint")
	await _shot("ghost-invalid")
	tap_cell(main, cc.cell + Vector2i(1, 6))
	main.placement.confirm_place()
	main.placement.select(0)
	check(main.state.buildings[main.state.last_added_id].level == 0, "the new building is under construction")
	check(not main.base_view.is_grid_shown(), "the grid is hidden once the building is placed")
	await _shot("construction")


## Whether every outline (or body) instance under a view's model and scaffold overrides with
## `material`. A body whose surface 0 is a hologram (a moving part made only of HOLO parts) is
## never overridden, by design, so it passes with no override.
func _all_overridden(view: BuildingView, outlines: bool, material: Material) -> bool:
	for node: Node in view.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.has_meta(BuildingModels.OUTLINE_META) != outlines or mesh.get_parent() == view:
			continue
		var override := mesh.get_surface_override_material(0)
		if mesh.mesh.surface_get_material(0) == MaterialKit.holo():
			if override != null:
				return false
		elif override != material:
			return false
	return true


## A screenshot once the window has caught up: it shows a frame or two behind the scene.
func _shot(name: String) -> void:
	await frames(6)
	await screenshot(name)
