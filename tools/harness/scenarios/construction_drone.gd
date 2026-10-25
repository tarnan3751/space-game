extends HarnessScenario
## The construction drone on the real build times: a Metal Silo placed on a fresh base gets a
## drone over its scaffold, which descends, moves, and fires its laser at a point on the site;
## when the silo is finished the view has no drone and processes only for its moving parts while
## the old drone climbs away and frees itself. The timer label sits above the drone's flight, over
## the scaffold and over the model. Then, the Command Center taken to level 2 (the metal and the
## crystal topped up by the scenario: the start's amounts and caps do not cover both upgrades),
## an upgrade of the silo gets a drone again, firing at the finished model. Last, a Metal
## Extractor finishes while the player drags it: the dragged view is kept, now showing the
## finished model, and its drone leaves clear of that model's top (site_height()). Last, a
## finished model with no moving part (the first such type at level 1) does not process.

const CLOSE_UP_SIZE := 10.0
## How long to wait for the drone's first shot: arriving, an orbit and the swoop take about 5 s.
const FIRE_WAIT_SECONDS := 10.0


func run(main: MainScript) -> void:
	var state: BaseState = main.state
	var placement: PlacementController = main.placement
	placement.begin_place("metal_silo")
	check(placement.ghost_is_valid(), "the silo's ghost found a free spot")
	placement.confirm_place()
	var id := state.last_added_id
	check(state.buildings.has(id) and state.buildings[id].is_busy(), "the silo is under construction")
	placement.select(0)
	await frames(1)
	var view: BuildingView = main.base_view.views[id]
	var drone := view.drone()
	check(drone != null, "the site has a construction drone")
	if drone == null:
		return
	check(_instances(drone) == 4, "the drone is four instances (%d)" % _instances(drone))
	var body := drone.get_child(0).get_child(0) as MeshInstance3D
	check(body.mesh.get_surface_count() == 2 and body.mesh.surface_get_material(1) == MaterialKit.holo(),
		"the drone's body has its hologram rotors on a second surface")
	check(view.is_processing(), "the view processes while the drone works")
	var centre := main.get_viewport().get_visible_rect().size * 0.5
	main.camera.zoom_at(main.camera.size / CLOSE_UP_SIZE, centre)
	main.camera.pan(centre, centre - main.camera.unproject_position(view.position + Vector3(0, 1, 0)))

	var positions: Array[Vector3] = [drone.drone_position()]
	await _wait(main, 0.5)
	positions.append(drone.drone_position())
	check(positions[1].y < positions[0].y - 1.0, "it descends on arrival (%.2f to %.2f high)" % [positions[0].y, positions[1].y])
	await screenshot("arriving")
	await _wait(main, 1.5)
	positions.append(drone.drone_position())
	say("drone at %s, %s, %s" % positions)
	check(positions[2].distance_to(positions[1]) > 0.3, "it moves on round the site")
	check(await _until_firing(main, drone), "it fires within %d s" % FIRE_WAIT_SECONDS)
	_check_beam(drone, view.footprint_size)
	_check_label(view, drone)
	await frames(2)
	await screenshot("firing")
	# A fifth of a second on, to compare: the sparks flicker, the rotors turn, the beam flows.
	await _wait(main, 0.2)
	await screenshot("firing-later")

	# Finished: the new level's view has no drone and processes only for its moving parts (the
	# silo's plunger pump); the old drone leaves.
	advance(state.seconds_left(id))
	main.base_view.sync(state)
	await frames(1)
	var built: BuildingView = main.base_view.views[id]
	check(state.buildings[id].level == 1 and built != view, "the silo is finished at level 1, in a new view")
	check(built.drone() == null, "the finished silo has no drone")
	check(built.is_processing() == _moves(built), "the finished silo's view processes only for its moving parts")
	check(drone.is_leaving() and drone.get_parent() == main.base_view, "the drone leaves under the base view")
	_check_clear(drone, built.site_height(), "the leaving drone starts clear of the finished model")
	var leaving_from := drone.drone_position().y
	await _wait(main, 0.35)
	check(is_instance_valid(drone) and drone.drone_position().y > leaving_from + 0.3, "it climbs as it leaves")
	await screenshot("leaving")
	await _wait(main, 0.6)
	check(not is_instance_valid(drone), "it frees itself once it has left")

	# An upgrade gets a drone again, over the finished model.
	var cc_id := 0
	for building_id: int in state.buildings:
		if state.buildings[building_id].type == "command_center":
			cc_id = building_id
	state.resources["metal"] = int(state.catalog.level_stats("command_center", 2)["cost"]["metal"])
	placement.select(cc_id)
	placement.upgrade_selected()
	check(state.buildings[cc_id].is_busy(), "the Command Center upgrades")
	advance(state.seconds_left(cc_id))
	main.base_view.sync(state)
	state.resources["crystal"] = int(state.catalog.level_stats("metal_silo", 2)["cost"]["crystal"])
	placement.select(id)
	placement.upgrade_selected()
	check(state.buildings[id].is_busy() and state.buildings[id].target_level == 2, "the silo upgrades to level 2")
	placement.select(0)
	await frames(1)
	var upgrading: BuildingView = main.base_view.views[id]
	drone = upgrading.drone()
	check(drone != null, "the upgrade has a construction drone")
	if drone == null:
		return
	check(_instances(drone) == 4, "the drone is four instances (%d)" % _instances(drone))
	await _wait(main, 1.0)
	_check_clear(drone, upgrading.site_height(), "on its orbit the drone clears the model")
	check(await _until_firing(main, drone), "it fires within %d s" % FIRE_WAIT_SECONDS)
	_check_beam(drone, upgrading.footprint_size)
	_check_label(upgrading, drone)
	await frames(2)
	await screenshot("upgrading")

	# Finished while dragged: the view is kept (BaseView leaves a dragged view alone until it is
	# dropped), so its scaffold gives way to the finished model under the drone, which must leave
	# clear of that model.
	advance(state.seconds_left(id))
	main.base_view.sync(state)
	var cost: Dictionary = state.catalog.level_stats("metal_extractor", 1)["cost"]
	for res: String in cost:
		state.resources[res] = maxi(state.resources[res], int(cost[res]))
	placement.begin_place("metal_extractor")
	check(placement.ghost_is_valid(), "the extractor's ghost found a free spot")
	placement.confirm_place()
	var dragged_id := state.last_added_id
	check(state.buildings.has(dragged_id) and state.buildings[dragged_id].level == 0
		and state.buildings[dragged_id].is_busy(), "the extractor is under construction")
	placement.select(dragged_id)
	await frames(1)
	var dragged: BuildingView = main.base_view.views[dragged_id]
	main.camera.pan(centre, centre - main.camera.unproject_position(dragged.position + Vector3(0, 1, 0)))
	await _wait(main, 1.5)
	# From the centre of the footprint's first cell to the next cell's: a move one cell along x.
	var start: Vector2i = state.buildings[dragged_id].cell
	var drop := start + Vector2i(1, 0)
	var press := main.camera.unproject_position(main.base_view.cell_to_world(start, 1))
	var finger := main.camera.unproject_position(main.base_view.cell_to_world(drop, 1))
	main.world_input.drag_started.emit(press)
	main.world_input.dragged.emit(finger, finger - press)
	await frames(1)
	check(main.base_view.dragging_id == dragged_id and state.check_move(dragged_id, drop) == "",
		"the extractor is being dragged to a free spot")
	drone = dragged.drone()
	check(drone != null and not drone.is_leaving(), "its drone works while it is dragged")
	if drone == null:
		return
	advance(state.seconds_left(dragged_id))
	main.base_view.sync(state)
	await frames(1)
	check(state.buildings[dragged_id].level == 1 and main.base_view.views[dragged_id] == dragged
		and dragged.is_model_visible(), "finished while dragged, the kept view shows the finished model")
	check(dragged.drone() == drone and drone.is_leaving(), "the drone leaves the dragged view")
	_check_clear(drone, dragged.site_height(), "the leaving drone starts clear of the finished model")
	# site_height() includes the lift: the dragged model stands LIFT_HEIGHT higher.
	say("lifted, the finished model's top is %.2f" % dragged.site_height())
	await screenshot("finished-while-dragged")
	main.world_input.drag_ended.emit(finger)
	await _wait(main, 1.0)
	check(main.base_view.dragging_id == 0 and main.base_view.views[dragged_id].drone() == null,
		"dropped, the extractor's view has no drone")
	var moved: BuildingView = main.base_view.views[dragged_id]
	check(state.buildings[dragged_id].cell == drop
		and moved.position.is_equal_approx(main.base_view.cell_to_world(drop, moved.footprint_size)),
		"the move landed: the extractor and its view at %s" % drop)
	_check_grid(state)
	await _check_still(main)


## Waits in steps of a tenth of a second until the drone fires, up to FIRE_WAIT_SECONDS.
func _until_firing(main: MainScript, drone: ConstructionDrone) -> bool:
	for step: int in int(FIRE_WAIT_SECONDS * 10):
		if drone.is_firing():
			return true
		await _wait(main, 0.1)
	return drone.is_firing()


## The beam runs from the drone's emitter down to a point on the site, in the work band and
## within the footprint and the models' slack, and the drone's lowest point clears the site's top.
func _check_beam(drone: ConstructionDrone, size: int) -> void:
	var ends := drone.beam_ends()
	var reach := size * 0.5 + 0.15
	var top := drone.site_height()
	check(absf(ends[1].x) <= reach and absf(ends[1].z) <= reach
		and ends[1].y >= ConstructionDrone.WORK_LOW * top - 0.001 and ends[1].y <= ConstructionDrone.WORK_HIGH * top + 0.001,
		"the beam hits a point on the site (%.2f, %.2f, %.2f; the site is %.2f high)" % [ends[1].x, ends[1].y, ends[1].z, top])
	check(ends[0].y > ends[1].y + 0.5 and ends[0].distance_to(drone.drone_position()) < 0.6,
		"the beam starts at the drone, above the point")
	_check_clear(drone, top, "firing, the drone clears the site")


## The drone's lowest point is CLEARANCE above `top` or more.
func _check_clear(drone: ConstructionDrone, top: float, what: String) -> void:
	var lowest := drone.drone_position().y - drone.reach_below()
	check(lowest >= top + ConstructionDrone.CLEARANCE - 0.001,
		"%s: its lowest point %.2f, the top %.2f" % [what, lowest, top])


## The grid's occupancy, cell by cell, is exactly every building's footprint.
func _check_grid(state: BaseState) -> void:
	var grid := BaseGrid.new(state.grid.width, state.grid.height)
	for building: BuildingState in state.buildings.values():
		grid.occupy(building.id, building.cell, state.catalog.size_of(building.type))
	var wrong := 0
	for y: int in grid.height:
		for x: int in grid.width:
			wrong += 1 if state.grid.occupant_at(Vector2i(x, y)) != grid.occupant_at(Vector2i(x, y)) else 0
	check(wrong == 0, "the grid's occupancy matches every footprint (%d cells differ)" % wrong)


## The view's timer label is above the highest point the drone reaches while it works, and
## above the drone now.
func _check_label(view: BuildingView, drone: ConstructionDrone) -> void:
	var label: Label3D = null
	for child: Node in view.get_children():
		if child is Label3D:
			label = child as Label3D
	check(label != null and label.visible and label.position.y >= drone.ceiling() + BuildingView.LABEL_OVER_DRONE - 0.001
		and label.position.y >= drone.drone_position().y + BuildingView.LABEL_OVER_DRONE,
		"the timer label is above the drone's flight (at %.2f; the drone reaches %.2f, is at %.2f)"
		% [label.position.y if label != null else 0.0, drone.ceiling(), drone.drone_position().y])


## A finished model with no moving part does not process: a view of the first type in the catalog
## whose level 1 has none, made beside the base and freed again.
func _check_still(main: MainScript) -> void:
	var catalog: Catalog = main.catalog
	for type: String in catalog.types():
		var view := BuildingView.new()
		view.setup(0, type, 1, catalog.size_of(type), BuildingModels.tier_of(catalog, type, 1))
		if _moves(view):
			view.free()
			continue
		main.add_child(view)
		await frames(1)
		check(not view.is_processing(), "a finished %s at level 1, with no moving part, does not process" % type)
		view.queue_free()
		return
	check(false, "some type has no moving part at level 1")


## Whether a view's model has a moving part (BuildingModels.MOVE_META).
func _moves(view: BuildingView) -> bool:
	for child: Node in view.find_children("*", "Node3D", true, false):
		if child.has_meta(BuildingModels.MOVE_META):
			return true
	return false


func _instances(node: Node) -> int:
	var count := 0
	for child: Node in node.get_children():
		if child is MeshInstance3D:
			count += 1
		count += _instances(child)
	return count


func _wait(main: MainScript, seconds: float) -> void:
	await main.get_tree().create_timer(seconds).timeout
