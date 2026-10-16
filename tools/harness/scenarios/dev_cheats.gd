extends HarnessScenario
## The debug build's dev cheats. run.sh passes --no-cheats, so the scenario applies them
## itself (Catalog.apply_dev_cheats) on a base emptied of resources: the first type that
## takes time to build is placed through PlacementController without spending anything and
## finishes one second later, and while it builds, with the only drone busy, a 12-cell paint
## stroke places 12 walls, which stay instant.

const WALL := "barrier_wall"
const LINE_START := Vector2i(10, 18)
const LINE_LENGTH := 12


func run(main: MainScript) -> void:
	var state: BaseState = main.state
	var placement: PlacementController = main.placement
	check(not main.cheats, "--no-cheats kept the real numbers")
	for res: String in state.catalog.resources:
		state.resources[res] = 0
	var type := ""
	for menu_type: String in state.catalog.menu_order:
		if int(state.catalog.level_stats(menu_type, 1).get("build_seconds", 0)) > 0:
			type = menu_type
			break
	check(state.check_can_build(type) == BaseState.ERR_FUNDS, "with no resources a %s is unaffordable" % type)
	main.catalog.apply_dev_cheats()

	placement.begin_place(type)
	placement.confirm_place()
	var id := state.last_added_id
	check(state.buildings.has(id) and state.buildings[id].type == type, "the %s is placed (id %d)" % [type, id])
	var building: BuildingState = state.buildings[id]
	check(building.is_busy() and state.seconds_left(id) == 1 and state.builders_free() == 0,
		"it builds for one second on the only drone")

	placement.begin_place(WALL)
	var at := _screen_of(main, LINE_START)
	main.world_input.drag_started.emit(at)
	for i: int in range(1, LINE_LENGTH):
		var next := _screen_of(main, LINE_START + Vector2i(i, 0))
		main.world_input.dragged.emit(next, next - at)
		at = next
		await frames(1)
	main.world_input.drag_ended.emit(at)
	check(state.count_of(WALL) == LINE_LENGTH, "a %d-cell stroke placed %d walls" % [LINE_LENGTH, state.count_of(WALL)])
	placement.confirm_place()

	for res: String in state.catalog.resources:
		check(state.resources[res] == 0, "no %s was spent" % res)
	advance(1)
	check(not building.is_busy() and building.level == 1, "finished at level 1 one second later")


func _screen_of(main: MainScript, cell: Vector2i) -> Vector2:
	return main.camera.unproject_position(main.base_view.cell_to_world(cell, 1))
