extends HarnessScenario
## Example scenario: place a Metal Extractor through PlacementController, advance the
## harness clock until it finishes, and screenshot each stage. The sounds of each step: the ghost
## starting quiet and ticking as a tap moves it (lower over a spot it cannot take), the place's
## clunk and, 0.2 s on, the drone's whoosh, the finish's chime, a tap selecting it by its category's voice, and a drag that lifts it,
## ticks and sets it down.


func run(main: MainScript) -> void:
	var state: BaseState = main.state
	var placement: PlacementController = main.placement
	check(state.buildings.size() == 2, "a fresh base has the two start buildings")
	var before: Dictionary[String, int] = state.resources.duplicate()
	await frames(2)
	await screenshot("fresh-base")

	var heard := heard_counts(main)
	placement.begin_place("metal_extractor")
	check(placement.is_placing(), "placing a metal_extractor")
	check(placement.ghost_is_valid(), "the ghost found a free cell")
	check_heard(main, heard, &"ghost_tick", 0, "the ghost appearing")
	var start := placement.ghost_cell()
	# A tap two cells over moves it there (a tap takes the footprint's middle cell).
	tap_cell(main, start + Vector2i(3, 1))
	check(placement.ghost_cell() == start + Vector2i(2, 0), "a tap moved the ghost to %s" % placement.ghost_cell())
	check_heard(main, heard, &"ghost_tick", 1 if placement.ghost_is_valid() else 0, "the ghost moved")
	await frames(2)
	# Onto the Command Center: the lower tick.
	await main.get_tree().create_timer(0.1).timeout
	var cc: BuildingState = state.buildings[1]
	tap_cell(main, cc.cell + Vector2i.ONE)
	check(not placement.ghost_is_valid(), "over the Command Center the ghost cannot be placed")
	check_heard(main, heard, &"ghost_tick_low", 1, "the ghost moved over the Command Center")
	placement.cancel_place()
	placement.begin_place("metal_extractor")
	await frames(2)
	await screenshot("ghost")

	heard = heard_counts(main)
	placement.confirm_place()
	check_heard(main, heard, &"place_ok", 1, "placed")
	check_heard(main, heard, &"build_start", 0, "placed, at once")
	await main.get_tree().create_timer(PlacementController.PLACE_TO_BUILD + 0.1).timeout
	check_heard(main, heard, &"build_start", 1, "placed, %.1f s on" % PlacementController.PLACE_TO_BUILD)
	var id := state.last_added_id
	check(not placement.is_placing(), "placement ended on confirm")
	check(state.buildings.has(id), "the extractor is in the state (id %d)" % id)
	check(placement.selected_id == id, "the new building is selected")
	var building: BuildingState = state.buildings[id]
	check(building.is_busy() and building.level == 0, "it starts under construction")
	check(state.builders_free() == 0, "it takes the only drone")
	var cost: Dictionary = state.catalog.level_stats("metal_extractor", 1).get("cost", {})
	for res: String in state.catalog.resources:
		var paid: int = before[res] - state.resources[res]
		check(paid == int(cost.get(res, 0)), "paid %d %s" % [paid, res])
	var seconds := state.seconds_left(id)
	say("construction takes %d s" % seconds)
	await frames(2)
	await screenshot("constructing")

	advance(seconds - 1)
	check(building.is_busy(), "still busy one second before it finishes")
	heard = heard_counts(main)
	advance(1)
	check(not building.is_busy() and building.level == 1, "finished at level 1")
	await frames(2)
	check_heard(main, heard, &"build_done", 1, "finished")
	check(state.builders_free() == 1, "the drone is free again")
	check(state.production_per_hour("metal") > 0, "it now produces metal")
	await frames(2)
	await screenshot("built")

	# Tapped, it is selected with its category's voice; dragged, it is lifted, ticks a cell on and
	# is set down there.
	placement.select(0)
	heard = heard_counts(main)
	tap_cell(main, building.cell)
	check(placement.selected_id == id, "a tap selected the extractor")
	check_heard(main, heard, Sounds.select_key(state.catalog.category_of("metal_extractor")), 1, "the extractor tapped")
	var cam: Camera3D = main.camera
	var from := cam.unproject_position(main.base_view.cell_to_world(building.cell, 1))
	var to := cam.unproject_position(main.base_view.cell_to_world(building.cell + Vector2i(0, 3), 1))
	var was := building.cell
	main.world_input.drag_started.emit(from)
	main.world_input.dragged.emit(to, to - from)
	main.world_input.drag_ended.emit(to)
	check(building.cell == was + Vector2i(0, 3), "dragged to %s" % building.cell)
	check_heard(main, heard, &"drag_pickup", 1, "the extractor dragged")
	check_heard(main, heard, &"ghost_tick", 1, "the extractor dragged")
	check_heard(main, heard, &"drag_drop", 1, "the extractor dragged")
