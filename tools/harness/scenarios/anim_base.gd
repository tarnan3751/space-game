extends HarnessScenario
## The base's animation as frame strips (docs/reference/art-style.md, **Animation**,
## **Construction drone**), for the animation audit, the HUD hidden.
##
## First the construction drone on the fresh base: a Metal Silo placed through PlacementController,
## framed at DRONE_ZOOM; "drone-arrive" (STRIP_FRAMES at STRIP_STEP_MS) from the moment it is
## placed, the drone flying in and descending, and "drone-laser" once it fires (within
## FIRE_WAIT_SECONDS), its laser on the scaffold. Then, at its next shot, "drone-beam", framed on
## the beam at the closest a gesture zooms and cropped (BEAM_HALF_ZOOM), and "drone-sparks" at its
## following shot, framed close on the work point (SPARK_ZOOM, cropped).
##
## Then every type but the walls and the traps, at level 1, its middle level (half its top, rounded
## up) and its top level, each a BuildingView of the scenario's own, alone at the field's middle
## (the base's own views hidden, as model_gallery does), for "<type>-<level>" (STRIP_FRAMES at
## STRIP_STEP_MS, cropped to the window's centre half): framed on the point FOCUS gives for the
## type at that level, its moving part, at the camera size it gives; a type FOCUS leaves out is
## framed on its middle (DEFAULT_SHARE of its height) at DEFAULT_ZOOM a cell. Checks: the silo's
## drone exists and fires three times, and every view shot showed its model.

const STRIP_FRAMES := 8
const STRIP_STEP_MS := 150
const DRONE_ZOOM := 6.0
const FIRE_WAIT_SECONDS := 10.0
const SPARK_ZOOM := 4.0
## The beam's strip: framed with frame_span on its two ends, cropped, at the camera's closest
## gesture zoom (IsoCamera.MIN_ZOOM_SIZE, the cropped tile half of it), so its pixels are the
## window's own as the player sees them.
const BEAM_HALF_ZOOM := 5.0
## Where each type's strip is framed, by level band: [from level, focus, camera size], the bands in
## rising order, a level taking the last band it has reached. The focus is x and z in the model's
## own space and y as a share of the site's height, on the moving part the idle reads by at those
## levels; the camera size is cropped (the window's centre half shows half of it).
const FOCUS := {
	"command_center": [[1, Vector3(-0.3, 0.6, -0.6), 10.0], [6, Vector3(-0.3, 0.7, -0.8), 10.0]],
	"drone_bay": [[1, Vector3(-0.1, 0.45, -0.1), 5.0]],
	"metal_extractor": [[1, Vector3(-0.2, 0.7, -0.2), 5.5], [6, Vector3(0.0, 0.55, 0.0), 7.0]],
	"crystal_harvester": [[1, Vector3(0.0, 0.6, 0.0), 6.0]],
	"antimatter_siphon": [[1, Vector3(0.0, 0.55, 0.0), 6.0]],
	"metal_silo": [[1, Vector3(0.8, 0.35, 0.8), 5.0], [6, Vector3(0.3, 0.6, 0.3), 9.0]],
	"crystal_silo": [[1, Vector3(0.0, 0.6, 0.0), 5.5], [6, Vector3(0.0, 0.65, 0.0), 8.0]],
	"antimatter_vault": [[1, Vector3(0.0, 0.45, 0.6), 5.5], [6, Vector3(0.0, 0.6, 0.3), 8.0]],
	"hangar": [[1, Vector3(-0.4, 0.55, -0.1), 10.0]],
	"cadet_academy": [[1, Vector3(-0.55, 0.3, 0.85), 4.5], [4, Vector3(0.2, 0.4, 0.3), 7.0]],
	"fabricator": [[1, Vector3(0.3, 0.55, 0.3), 6.0]],
	"heavy_fabricator": [[1, Vector3(0.7, 0.3, 0.0), 7.0]],
	"research_lab": [[1, Vector3(0.2, 0.65, -0.2), 6.0], [6, Vector3(0.1, 0.72, -0.1), 8.0]],
	"nanite_foundry": [[1, Vector3(-0.4, 0.6, -0.4), 6.0]],
	"drydock": [[1, Vector3(-0.3, 0.45, 0.4), 9.0]],
	"alliance_beacon": [[1, Vector3(0.0, 0.55, 0.0), 7.0], [4, Vector3(0.0, 0.45, 0.0), 9.0]],
}
const DEFAULT_SHARE := 0.55
const DEFAULT_ZOOM := 2.6


func run(main: MainScript) -> void:
	main.hud.visible = false
	await _drone(main)
	for view: BuildingView in main.base_view.views.values():
		view.visible = false
	var catalog: Catalog = main.catalog
	var grid: Vector2i = catalog.grid_size
	var shown := 0
	var strips := 0
	for type: String in catalog.types():
		var kind := catalog.battle_class(type)
		if kind == Catalog.CLASS_WALL or kind == Catalog.CLASS_TRAP:
			continue
		var size := catalog.size_of(type)
		var levels: Array[int] = [1]
		for level: int in [(catalog.max_level(type) + 1) / 2, catalog.max_level(type)]:
			if not levels.has(level):
				levels.append(level)
		for level: int in levels:
			var view := BuildingView.new()
			view.setup(0, type, level, size, BuildingModels.tier_of(catalog, type, level))
			view.position = main.base_view.cell_to_world(Vector2i(grid.x / 2, grid.y / 2), size)
			main.add_child(view)
			strips += 1
			shown += 1 if view.site_height() > 0.0 else 0
			var focus := Vector3(0.0, DEFAULT_SHARE, 0.0)
			var zoom := size * DEFAULT_ZOOM
			if FOCUS.has(type):
				for band: Array in FOCUS[type]:
					var from: int = band[0]
					if level >= from:
						focus = band[1]
						zoom = band[2]
			frame_world(main, zoom, view.position + Vector3(focus.x, focus.y * view.site_height(), focus.z))
			await frames(3)
			await strip("%s-%d" % [type, level], STRIP_FRAMES, STRIP_STEP_MS, true)
			view.queue_free()
			await frames(1)
	check(strips > 0 and shown == strips, "every type but the walls and the traps showed its model at each level shot (%d of %d)"
		% [shown, strips])


## A Metal Silo placed on the fresh base: its drone arriving, then at work, then its beam and its
## sparks close.
func _drone(main: MainScript) -> void:
	var state: BaseState = main.state
	var placement: PlacementController = main.placement
	placement.begin_place("metal_silo")
	check(placement.ghost_is_valid(), "the silo's ghost found a free spot")
	placement.confirm_place()
	var id := state.last_added_id
	placement.select(0)
	await frames(1)
	var view: BuildingView = main.base_view.views[id]
	var drone := view.drone()
	check(drone != null, "the site has a construction drone")
	if drone == null:
		return
	frame_world(main, DRONE_ZOOM, view.position + Vector3(0.0, 1.0, 0.0))
	await strip("drone-arrive", STRIP_FRAMES, STRIP_STEP_MS)
	await _next_shot(main, drone, 1)
	await strip("drone-laser", STRIP_FRAMES, STRIP_STEP_MS)
	await _next_shot(main, drone, 2)
	var ends := drone.beam_ends()
	frame_span(main, drone.global_transform * ends[0], drone.global_transform * ends[1], 0.0, BEAM_HALF_ZOOM, true)
	await strip("drone-beam", STRIP_FRAMES, STRIP_STEP_MS, true)
	await _next_shot(main, drone, 3)
	ends = drone.beam_ends()
	frame_world(main, SPARK_ZOOM, drone.global_transform * ends[1])
	await strip("drone-sparks", STRIP_FRAMES, STRIP_STEP_MS, true)


## Waits for the drone's next shot to start, its `count`th, within FIRE_WAIT_SECONDS.
func _next_shot(main: MainScript, drone: ConstructionDrone, count: int) -> void:
	var waited := main.get_tree().create_timer(FIRE_WAIT_SECONDS)
	while drone.is_firing() and waited.time_left > 0.0:
		await frames(1)
	while not drone.is_firing() and waited.time_left > 0.0:
		await frames(1)
	check(drone.is_firing(), "the drone fires its shot %d within %d s" % [count, FIRE_WAIT_SECONDS])
