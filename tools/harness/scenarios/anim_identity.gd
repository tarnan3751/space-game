extends HarnessScenario
## The models' poses at fixed moments (fix_clock), for comparing two trees' animation frame by frame
## (docs/reference/art-style.md, **Animation**): run on each tree rendered and compare the shots of
## the same name (Image.compute_image_metrics), so a change to how parts move, or to where they are
## drawn, shows as a difference at a known clock. The HUD and the base's own views are hidden.
##
## Every type but the wall at level 1, its middle level and its top level (as anim_base takes them),
## each a BuildingView of the scenario's own alone at the field's middle, framed on DEFAULT_SHARE of
## its height at DEFAULT_ZOOM a cell, and the gunship (its rotors) at Base and at Crown, framed on its
## middle at UNIT_ZOOM: a screenshot at each clock of CLOCKS, "<type>-<level>-<k>" or
## "unit-gunship-<tier>-<k>", each allowed to repeat the one before (a model with nothing moving
## looks the same at every clock). Checks: every view showed its model.

## The fixed clocks the shots are taken at, in seconds: one early, the others well into periods.
const CLOCKS: Array[float] = [0.37, 2.9, 7.41]
const DEFAULT_SHARE := 0.55
const DEFAULT_ZOOM := 2.6
const UNIT_ZOOM := 4.0
const UNIT := "gunship"


func run(main: MainScript) -> void:
	main.hud.visible = false
	for view: BuildingView in main.base_view.views.values():
		view.visible = false
	var catalog: Catalog = main.catalog
	var grid: Vector2i = catalog.grid_size
	var middle := main.base_view.cell_to_world(Vector2i(grid.x / 2, grid.y / 2), 1)
	var shown := 0
	var views := 0
	for type: String in catalog.types():
		if catalog.battle_class(type) == Catalog.CLASS_WALL:
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
			views += 1
			shown += 1 if view.site_height() > 0.0 else 0
			frame_world(main, size * DEFAULT_ZOOM, view.position + Vector3(0.0, DEFAULT_SHARE * view.site_height(), 0.0))
			await _shoot("%s-%d" % [type, level])
			view.queue_free()
			await frames(1)
	for tier: int in [Parts.Tier.BASE, Parts.Tier.CROWN]:
		var unit := UnitModels.create(UNIT, tier)
		unit.position = middle
		main.add_child(unit)
		frame_world(main, UNIT_ZOOM, middle + Vector3(0.0, 1.4, 0.0))
		await _shoot("unit-%s-%d" % [UNIT, tier])
		unit.queue_free()
		await frames(1)
	release_clock()
	check(views > 0 and shown == views, "every view showed its model (%d of %d)" % [shown, views])


## A screenshot at each fixed clock of CLOCKS.
func _shoot(name: String) -> void:
	for k: int in CLOCKS.size():
		fix_clock(CLOCKS[k])
		await frames(3)
		await screenshot("%s-%d" % [name, k], true)
