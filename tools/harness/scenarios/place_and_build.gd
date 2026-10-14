extends HarnessScenario
## Example scenario: place a Metal Extractor through PlacementController, advance the
## harness clock until it finishes, and screenshot each stage.


func run(main: MainScript) -> void:
	var state: BaseState = main.state
	var placement: PlacementController = main.placement
	check(state.buildings.size() == 2, "a fresh base has the two start buildings")
	var before: Dictionary[String, int] = state.resources.duplicate()
	await frames(2)
	await screenshot("fresh-base")

	placement.begin_place("metal_extractor")
	check(placement.is_placing(), "placing a metal_extractor")
	check(placement.ghost_is_valid(), "the ghost found a free cell")
	await frames(2)
	await screenshot("ghost")

	placement.confirm_place()
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
	advance(1)
	check(not building.is_busy() and building.level == 1, "finished at level 1")
	check(state.builders_free() == 1, "the drone is free again")
	check(state.production_per_hour("metal") > 0, "it now produces metal")
	await frames(2)
	await screenshot("built")
