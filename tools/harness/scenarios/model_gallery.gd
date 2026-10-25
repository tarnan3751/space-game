extends HarnessScenario
## The model gallery: one BuildingView per building type and level in the catalog, laid out on
## the grid in category rows, with an overview screenshot of each page of rows (saying the draw
## calls and the frame rate there), a close-up of each row (in even parts ROW_PART_CELLS wide at
## most, so none runs under the HUD), and a detail shot of each row's first building at the
## closest zoom, where outlines, bands and textures can be read. Each close-up and detail shot
## checks that its models' footprints and tops are on the screen and clear of the Build button.
## The overview's line also says the render thread's CPU time for the frame, measured on the
## root viewport.
##
## Checks every model, built for its level's tier (BuildingModels.tier_of): one body
## MeshInstance3D and up to Parts.max_moving(tier) more (the moving parts), each with an outline
## instance beside it on the ink material casting no shadow unless all its parts are ones never
## outlined (Surf.NO_OUTLINE); every vertex's kit layer (UV2.x) within the kit; the body
## triangles, both surfaces, within the art style's budget for its footprint and tier
## (docs/reference/art-style.md, **Budgets**); its reach in x and z (the body's bounds, each
## moving part's over its whole motion) within its footprint plus EXTENT_SLACK; and its top (the
## body's bounds, each moving part's over its whole motion) within its height cap,
## CC_HEIGHT_CAP for the Command Center and HEIGHT_CAP for every other type. For the Command
## Center, also that its dome with its gold ring, and the L8 ring hovering over it, reach no further
## out than the storey they ride (CoreModels.dome_fit).
##
## Rows follow the catalog's categories: "core" (the Command Center), then catalog.categories
## in tab order. The views hang under a Node3D of the scenario's own under main, not under
## base_view, whose sync() frees views that are not in the state; the base's own views are
## hidden meanwhile. The whole roster does not fit on the grid at once, so rows that do not fit
## start a new page.

## Body triangles a model may have, by footprint size, then by Parts.Tier (Base, Gold, Chrome,
## Obsidian, Crown); a wall piece has WALL_BUDGETS by tier.
const BUDGETS := {
	1: [600, 600, 840, 1080, 1320],
	2: [2000, 2000, 2800, 3600, 4400],
	3: [3000, 3000, 4200, 5400, 6600],
	4: [5000, 5000, 7000, 9000, 11000],
	5: [5000, 5000, 7000, 9000, 11000],
}
const WALL_TYPE := "barrier_wall"
const WALL_BUDGETS := [250, 250, 300, 350, 400]
## How tall a model may stand (world units, at its scale): the Command Center, every other type.
const CC_HEIGHT_CAP := 7.0
const HEIGHT_CAP := 5.0
## How far past its footprint's edge (world units) a model may reach in x or z.
const EXTENT_SLACK := 0.15
## Degrees between the angles a swinging part's reach is sampled at.
const SWING_STEP := 5.0
## Cells between models and between rows.
const GAP := 1
const OVERVIEW_SIZE := 44.0
const CLOSE_UP_SIZE := 20.0
const DETAIL_SIZE := 10.0
## The widest stretch of a row (cells) one close-up shows: a row is shot in even parts no wider.
const ROW_PART_CELLS := 20
## Seconds the overview is held before the frame rate is read. Performance.TIME_FPS counts the
## last whole second, so only after two does it cover a second with the page already settled.
const SETTLE_SECONDS := 2.1


func run(main: MainScript) -> void:
	var roster := _roster(main)
	var categories := _categories(main)
	check(not roster.is_empty(), "the catalog has building types")
	check(main.state.catalog.has_type(WALL_TYPE), "the catalog has the %s type" % WALL_TYPE)
	for entry: Dictionary in roster:
		_check_budget(main.state.catalog, entry)

	for view: BuildingView in main.base_view.views.values():
		view.visible = false
	var grid: Vector2i = main.state.catalog.grid_size
	var rows := _rows(roster, categories, grid.x)
	var laid_out := 0
	var models := 0
	for row: Dictionary in rows:
		laid_out += (row["models"] as Array).size()
	for entry: Dictionary in roster:
		models += int(entry["levels"])
	check(laid_out == models, "every type and level is laid out (%d of %d)" % [laid_out, models])
	var pages := _paginate(rows, grid.y)
	var viewport_rid := main.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport_rid, true)
	for page_index: int in pages.size():
		var gallery := Node3D.new()
		main.add_child(gallery)
		var page: Array = pages[page_index]
		for row: Dictionary in page:
			var names := PackedStringArray()
			var views: Array[BuildingView] = []
			for model: Array in row["models"]:
				var type: String = model[0]
				var level: int = model[1]
				var size: int = model[2]
				var cell := Vector2i(model[3], row["y"] + (row["depth"] - size) / 2)
				var view := BuildingView.new()
				view.setup(0, type, level, size, BuildingModels.tier_of(main.state.catalog, type, level))
				view.position = main.base_view.cell_to_world(cell, size)
				gallery.add_child(view)
				views.append(view)
				names.append("%s %d" % [type, level])
			row["views"] = views
			say("page %d, %s row at y %d: %s" % [page_index + 1, row["category"], row["y"], ", ".join(names)])
		_frame(main, main.base_view.cell_to_world(Vector2i(grid.x / 2, grid.y / 2), 0), OVERVIEW_SIZE)
		await main.get_tree().create_timer(SETTLE_SECONDS).timeout
		say("page %d overview: %d draw calls, %d fps, %.2f ms render CPU" % [page_index + 1,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.TIME_FPS),
			RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid)])
		await screenshot("page%d-overview" % (page_index + 1))
		for row_index: int in page.size():
			var row: Dictionary = page[row_index]
			var row_models: Array = row["models"]
			var width: int = row["width"]
			var parts := ceili(width / float(ROW_PART_CELLS))
			for part: int in parts:
				# The models whose centres fall in this part's even share of the row's width.
				var shown: Array[BuildingView] = []
				var low := width
				var high := 0
				for i: int in row_models.size():
					var x: int = row_models[i][3]
					var size: int = row_models[i][2]
					if mini((2 * x + size) * parts / (2 * width), parts - 1) == part:
						shown.append(row["views"][i])
						low = mini(low, x)
						high = maxi(high, x + size)
				var name := "page%d-row%d-%s" % [page_index + 1, row_index + 1, row["category"]]
				name += "-%d" % (part + 1) if parts > 1 else ""
				var at := main.base_view.cell_to_world(Vector2i(low, row["y"]), 0) \
					+ Vector3((high - low) * 0.5, 0, int(row["depth"]) * 0.5)
				_frame(main, at, CLOSE_UP_SIZE)
				_check_clear_of_hud(main, shown, name)
				await frames(2)
				await screenshot(name)
		for row_index: int in page.size():
			var row: Dictionary = page[row_index]
			var first: Array = (row["models"] as Array)[0]
			var size: int = first[2]
			var cell := Vector2i(first[3], int(row["y"]) + (int(row["depth"]) - size) / 2)
			var name := "page%d-row%d-%s-detail" % [page_index + 1, row_index + 1, row["category"]]
			_frame(main, main.base_view.cell_to_world(cell, size), DETAIL_SIZE)
			var row_views: Array[BuildingView] = row["views"]
			_check_clear_of_hud(main, row_views.slice(0, 1), name)
			await frames(2)
			await screenshot(name)
		gallery.queue_free()
		await frames(1)


## Every type in the catalog: {"type", "category", "levels", "size"}.
func _roster(main: MainScript) -> Array[Dictionary]:
	var catalog: Catalog = main.state.catalog
	var roster: Array[Dictionary] = []
	for type: String in catalog.types():
		roster.append({
			"type": type,
			"category": catalog.category_of(type),
			"levels": catalog.max_level(type),
			"size": catalog.size_of(type),
		})
	return roster


## Row order: the Command Center's "core", then the catalog's categories in tab order.
func _categories(main: MainScript) -> PackedStringArray:
	var categories := PackedStringArray(["core"])
	categories.append_array(main.state.catalog.categories)
	return categories


func _check_budget(catalog: Catalog, entry: Dictionary) -> void:
	var type: String = entry["type"]
	var size: int = entry["size"]
	var cap := CC_HEIGHT_CAP if type == Catalog.HQ_TYPE else HEIGHT_CAP
	for level: int in range(1, int(entry["levels"]) + 1):
		var tier := BuildingModels.tier_of(catalog, type, level)
		var limits: Array = WALL_BUDGETS if type == WALL_TYPE else BUDGETS[mini(size, 5)]
		var limit: int = limits[tier]
		var model := BuildingModels.create(type, level, size, tier)
		var bodies := _bodies(model)
		var reach := _reach(model, bodies)
		var top := _top(model, bodies)
		var bound := size * 0.5 + EXTENT_SLACK
		var triangles := 0
		var outlined := 0
		var need_outline := 0
		var top_layer := 0
		for body: MeshInstance3D in bodies:
			var outlinable := false
			for surface: int in body.mesh.get_surface_count():
				var arrays := body.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				triangles += vertices.size() / 3
				var layers: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
				for layer: Vector2 in layers:
					top_layer = maxi(top_layer, roundi(layer.x))
					outlinable = outlinable or (roundi(layer.y) & Surf.NO_OUTLINE) == 0
			if outlinable:
				need_outline += 1
				if _has_outline(body):
					outlined += 1
		model.free()
		var over := "" if reach <= bound else ", over by %.2f" % (reach - bound)
		check(bodies.size() >= 1 and bodies.size() <= 1 + Parts.max_moving(tier) and outlined == need_outline
			and top_layer < MaterialKit.LAYERS.size() and triangles <= limit and reach <= bound and top <= cap,
			"%s %d: %d body instance(s), %d of %d outlined, top kit layer %d, %d triangles (limit %d), reach %.2f (limit %.2f%s), %s tier, top %.2f (cap %.1f)"
			% [type, level, bodies.size(), outlined, need_outline, top_layer, triangles, limit, reach, bound, over,
			str(Parts.Tier.keys()[tier]).to_lower(), top, cap])
		if type == Catalog.HQ_TYPE:
			# The dome caps the tower: with its gold ring, and the ring hovering over it, it reaches no
			# further out than the lip of what it rides (CoreModels.dome_fit).
			var fit := BuildingModels.CoreModels.dome_fit(level)
			check(fit.x <= fit.z + 0.001 and fit.y <= fit.z + 0.001,
				"%s %d: dome %.2f out with its gold ring, hovering ring %.2f, the storey under them %.2f" % [type, level, fit.x,
				fit.y, fit.z])


## How high a model stands, in world units, times the model's scale: the static body's bounds,
## and each moving part's over its whole motion (_moving_top).
func _top(model: Node3D, bodies: Array[MeshInstance3D]) -> float:
	var top := 0.0
	for body: MeshInstance3D in bodies:
		if body.get_parent() == model:
			top = maxf(top, body.mesh.get_aabb().end.y)
		else:
			var node := body.get_parent() as Node3D
			top = maxf(top, _moving_top(body.mesh, node.get_meta(BuildingModels.MOVE_META) as Motion, node.position))
	return top * model.scale.y


## A moving part's highest point over its whole motion: its bounds' corners turned about the
## axis every SWING_STEP degrees (a whole turn for a SPIN, -amplitude to +amplitude for a SWING),
## or at both ends of a SLIDE.
func _moving_top(mesh: Mesh, motion: Motion, pivot: Vector3) -> float:
	var box := mesh.get_aabb()
	var poses: Array[Transform3D] = []
	match motion.kind:
		Motion.Kind.SPIN, Motion.Kind.SWING:
			var sweep := TAU if motion.kind == Motion.Kind.SPIN else 2.0 * deg_to_rad(absf(motion.amplitude))
			var steps := maxi(1, ceili(rad_to_deg(sweep) / SWING_STEP))
			var start := 0.0 if motion.kind == Motion.Kind.SPIN else -deg_to_rad(absf(motion.amplitude))
			for k: int in steps + 1:
				poses.append(Transform3D(Basis(motion.axis, start + sweep * k / steps), pivot))
		_:
			var shift := motion.axis * motion.amplitude
			poses.append(Transform3D(Basis.IDENTITY, pivot + shift))
			poses.append(Transform3D(Basis.IDENTITY, pivot - shift))
	var top := -INF
	for at: Transform3D in poses:
		for corner: int in 8:
			top = maxf(top, (at * box.get_endpoint(corner)).y)
	return top


## How far a model reaches from its centre in x or z, in world units, times the model's scale:
## the static body's bounds, and each moving part's reach over its whole motion (_moving_reach).
func _reach(model: Node3D, bodies: Array[MeshInstance3D]) -> float:
	var reach := 0.0
	for body: MeshInstance3D in bodies:
		if body.get_parent() == model:
			reach = maxf(reach, _box_reach(body.mesh.get_aabb(), Transform3D.IDENTITY))
		else:
			var node := body.get_parent() as Node3D
			reach = maxf(reach, _moving_reach(body.mesh, node.get_meta(BuildingModels.MOVE_META) as Motion,
				node.position))
	return reach * model.scale.x


## A moving part's reach from the model's centre in x or z over its whole motion. SPIN: each
## vertex sweeps a circle about the axis through the pivot, which reaches no further from the
## pivot than the circle's centre's offset plus its radius (the sweep), so the part reaches the
## pivot's x plus the sweep in x and the pivot's z plus the sweep in z: per axis, as the extent is,
## so a round pushed along a diagonal is not over-counted.
## SWING: the part's bounds turned every SWING_STEP degrees from -amplitude to +amplitude, both
## ends included. SLIDE: its
## bounds at both ends of the slide.
func _moving_reach(mesh: Mesh, motion: Motion, pivot: Vector3) -> float:
	var box := mesh.get_aabb()
	match motion.kind:
		Motion.Kind.SPIN:
			var sweep := 0.0
			for surface: int in mesh.get_surface_count():
				var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				for vertex: Vector3 in vertices:
					var centre := motion.axis * vertex.dot(motion.axis)
					sweep = maxf(sweep, Vector2(centre.x, centre.z).length() + (vertex - centre).length())
			return maxf(absf(pivot.x), absf(pivot.z)) + sweep
		Motion.Kind.SWING:
			var reach := 0.0
			var steps := maxi(1, ceili(2.0 * absf(motion.amplitude) / SWING_STEP))
			for k: int in steps + 1:
				var angle := deg_to_rad(motion.amplitude) * (2.0 * k / steps - 1.0)
				reach = maxf(reach, _box_reach(box, Transform3D(Basis(motion.axis, angle), pivot)))
			return reach
		_:
			var shift := motion.axis * motion.amplitude
			return maxf(_box_reach(box, Transform3D(Basis.IDENTITY, pivot + shift)),
				_box_reach(box, Transform3D(Basis.IDENTITY, pivot - shift)))


## The largest |x| or |z| of a box's corners placed by `at`.
func _box_reach(box: AABB, at: Transform3D) -> float:
	var reach := 0.0
	for corner: int in 8:
		var point := at * box.get_endpoint(corner)
		reach = maxf(reach, maxf(absf(point.x), absf(point.z)))
	return reach


## Whether a body has an outline instance beside it on the ink material, casting no shadow.
func _has_outline(body: MeshInstance3D) -> bool:
	for sibling: Node in body.get_parent().get_children():
		if sibling is MeshInstance3D and sibling.has_meta(BuildingModels.OUTLINE_META):
			var outline := sibling as MeshInstance3D
			return outline.mesh.surface_get_material(0) == MaterialKit.ink() \
				and outline.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return false


## The model's body mesh instances (not the outlines), the moving parts' included.
func _bodies(node: Node) -> Array[MeshInstance3D]:
	var bodies: Array[MeshInstance3D] = []
	for child: Node in node.get_children():
		if child is MeshInstance3D and not child.has_meta(BuildingModels.OUTLINE_META):
			bodies.append(child as MeshInstance3D)
		bodies.append_array(_bodies(child))
	return bodies


## Rows of models, category by category, each row as wide as the grid allows:
## {"category", "models": [[type, level, size, x]], "width", "depth"}.
func _rows(roster: Array[Dictionary], categories: PackedStringArray,
		width: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for category: String in categories:
		var row := {}
		for entry: Dictionary in roster:
			if entry["category"] != category:
				continue
			var size: int = entry["size"]
			for level: int in range(1, int(entry["levels"]) + 1):
				if row.is_empty() or int(row["width"]) + size > width:
					row = {"category": category, "models": [], "width": -GAP, "depth": 0}
					rows.append(row)
				row["width"] = int(row["width"]) + GAP
				row["models"].append([entry["type"], level, size, row["width"]])
				row["width"] = int(row["width"]) + size
				row["depth"] = maxi(row["depth"], size)
	return rows


## Gives each row its "y" and splits the rows into pages that fit the grid's height.
func _paginate(rows: Array[Dictionary], height: int) -> Array[Array]:
	var pages: Array[Array] = [[]]
	var y := 0
	for row: Dictionary in rows:
		if y + int(row["depth"]) > height and not pages.back().is_empty():
			pages.append([])
			y = 0
		row["y"] = y
		pages.back().append(row)
		y += int(row["depth"]) + GAP
	return pages


## Checks that every view's footprint corners and the top of its model project onto the screen
## and outside the Build button, as the camera is framed now.
func _check_clear_of_hud(main: MainScript, views: Array[BuildingView], shot: String) -> void:
	var screen := main.get_viewport().get_visible_rect()
	var button := main.hud.build_button().get_global_rect()
	var hidden := PackedStringArray()
	for view: BuildingView in views:
		var half := view.footprint_size * 0.5
		var points: Array[Vector3] = [view.position + Vector3(0, view.site_height(), 0)]
		for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			points.append(view.position + Vector3(corner.x * half, 0, corner.y * half))
		for point: Vector3 in points:
			var at := main.camera.unproject_position(point)
			if not screen.has_point(at) or button.has_point(at):
				hidden.append("%s %d" % [view.building_type, view.building_level])
				break
	check(hidden.is_empty(), "%s: every model on the screen, clear of the Build button%s" % [shot,
		"" if hidden.is_empty() else " (not: %s)" % ", ".join(hidden)])


## Zooms the camera to an orthographic size and pans it onto a ground point, through the
## same calls a pinch and a drag make.
func _frame(main: MainScript, point: Vector3, size: float) -> void:
	var centre := main.get_viewport().get_visible_rect().size * 0.5
	main.camera.zoom_at(main.camera.size / size, centre)
	main.camera.pan(centre, centre - main.camera.unproject_position(point))
