extends HarnessScenario
## The base's animation as frame strips (docs/reference/art-style.md, **Animation**,
## **Construction drone**), for the animation audit, the HUD hidden.
##
## First the construction drone on the fresh base: a Metal Silo placed through PlacementController,
## framed at DRONE_ZOOM; "drone-arrive" (STRIP_FRAMES at STRIP_STEP_MS) from the moment it is
## placed, the drone flying in and descending, and "drone-laser" once it fires (within
## FIRE_WAIT_SECONDS), its laser on the scaffold. Then the debug build's Template base (Command
## Center 10, pressed through the HUD's button): one building of every type it holds but the walls
## and the traps (the lowest id of each, in the catalog's order), each framed alone on its middle at
## a size by its footprint (ZOOM_PER_CELL a cell, plus ZOOM_MARGIN), for "<type>-idle"
## (STRIP_FRAMES at STRIP_STEP_MS): the turning parts, the robots, the surface effects, the
## Cadet Academy's hologram cadet, the defences at rest. Checks: the silo's drone exists and fires,
## and the template base holds every type but the walls and the traps, each shot.

const STRIP_FRAMES := 8
const STRIP_STEP_MS := 150
const DRONE_ZOOM := 6.0
const FIRE_WAIT_SECONDS := 10.0
const ZOOM_PER_CELL := 1.6
const ZOOM_MARGIN := 2.5


func run(main: MainScript) -> void:
	main.hud.visible = false
	await _drone(main)
	main.hud.template_button().pressed.emit()
	await frames(4)
	main.hud.visible = false
	var state: BaseState = main.state
	var catalog: Catalog = main.catalog
	var missing := PackedStringArray()
	for type: String in catalog.types():
		var kind := catalog.battle_class(type)
		if kind == Catalog.CLASS_WALL or kind == Catalog.CLASS_TRAP:
			continue
		var found := 0
		for id: int in state.buildings:
			if state.buildings[id].type == type and (found == 0 or id < found):
				found = id
		if found == 0 or not main.base_view.views.has(found):
			missing.append(type)
			continue
		var view: BuildingView = main.base_view.views[found]
		var size := catalog.size_of(type)
		frame_world(main, size * ZOOM_PER_CELL + ZOOM_MARGIN, view.position + Vector3(0.0, view.site_height() * 0.45, 0.0))
		await frames(3)
		await strip("%s-idle" % type, STRIP_FRAMES, STRIP_STEP_MS)
	check(missing.is_empty(), "every type but the walls and the traps was found and shot idling in the template base (missing: %s)"
		% ", ".join(missing))


## A Metal Silo placed on the fresh base: its drone arriving, then at work.
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
	var waited := main.get_tree().create_timer(FIRE_WAIT_SECONDS)
	while not drone.is_firing() and waited.time_left > 0.0:
		await frames(1)
	check(drone.is_firing(), "the drone fires within %d s" % FIRE_WAIT_SECONDS)
	await strip("drone-laser", STRIP_FRAMES, STRIP_STEP_MS)
