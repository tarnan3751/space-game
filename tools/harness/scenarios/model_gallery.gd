extends HarnessScenario
## The model gallery: one BuildingView per building type and level in the catalog, laid out on
## the grid in category rows, with an overview screenshot of each page of rows and a close-up
## of each row. Checks every model: one or two body MeshInstance3D (the static body, the
## spinning part), each with an outline instance beside it on the ink material casting no
## shadow; every vertex's kit layer (UV2.x) within the kit; and the body triangles within the
## art style's budget for its footprint (docs/reference/art-style.md, **Budgets**).
##
## Rows follow the catalog's categories: "core" (the Command Center), then catalog.categories
## in tab order. The views hang under a Node3D of the scenario's own under main, not under
## base_view, whose sync() frees views that are not in the state; the base's own views are
## hidden meanwhile. The whole roster does not fit on the grid at once, so rows that do not fit
## start a new page.

## Body triangles a model may have, by footprint size; a wall piece has WALL_BUDGET.
const BUDGETS := {1: 600, 2: 2000, 3: 3000, 4: 5000, 5: 5000}
const WALL_CATEGORY := "walls"
const WALL_BUDGET := 250
## Cells between models and between rows.
const GAP := 1
const OVERVIEW_SIZE := 44.0
const CLOSE_UP_SIZE := 20.0


func run(main: MainScript) -> void:
	var roster := _roster(main)
	var categories := _categories(main)
	check(not roster.is_empty(), "the catalog has building types")
	check(categories.has(WALL_CATEGORY), "the catalog has the %s category" % WALL_CATEGORY)
	for entry: Dictionary in roster:
		_check_budget(entry)

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
	for page_index: int in pages.size():
		var gallery := Node3D.new()
		main.add_child(gallery)
		var page: Array = pages[page_index]
		for row: Dictionary in page:
			var names := PackedStringArray()
			for model: Array in row["models"]:
				var type: String = model[0]
				var level: int = model[1]
				var size: int = model[2]
				var cell := Vector2i(model[3], row["y"] + (row["depth"] - size) / 2)
				var view := BuildingView.new()
				view.setup(0, type, level, size)
				view.position = main.base_view.cell_to_world(cell, size)
				gallery.add_child(view)
				names.append("%s %d" % [type, level])
			say("page %d, %s row at y %d: %s" % [page_index + 1, row["category"], row["y"], ", ".join(names)])
		_frame(main, main.base_view.cell_to_world(Vector2i(grid.x / 2, grid.y / 2), 0), OVERVIEW_SIZE)
		await frames(3)
		await screenshot("page%d-overview" % (page_index + 1))
		for row_index: int in page.size():
			var row: Dictionary = page[row_index]
			var middle := Vector2i(int(row["width"]) / 2, int(row["y"]) + int(row["depth"]) / 2)
			_frame(main, main.base_view.cell_to_world(middle, 0), CLOSE_UP_SIZE)
			await frames(2)
			await screenshot("page%d-row%d-%s" % [page_index + 1, row_index + 1, row["category"]])
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


func _check_budget(entry: Dictionary) -> void:
	var type: String = entry["type"]
	var size: int = entry["size"]
	var limit: int = WALL_BUDGET if entry["category"] == WALL_CATEGORY else BUDGETS[mini(size, 5)]
	for level: int in range(1, int(entry["levels"]) + 1):
		var model := BuildingModels.create(type, level, size)
		var bodies := _bodies(model)
		var triangles := 0
		var outlined := 0
		var top_layer := 0
		for body: MeshInstance3D in bodies:
			var arrays := body.mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			triangles += vertices.size() / 3
			var layers: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
			for layer: Vector2 in layers:
				top_layer = maxi(top_layer, roundi(layer.x))
			if _has_outline(body):
				outlined += 1
		model.free()
		check(bodies.size() >= 1 and bodies.size() <= 2 and outlined == bodies.size()
			and top_layer < MaterialKit.LAYERS.size() and triangles <= limit,
			"%s %d: %d body instance(s), %d outlined, top kit layer %d, %d triangles (limit %d)"
			% [type, level, bodies.size(), outlined, top_layer, triangles, limit])


## Whether a body has an outline instance beside it on the ink material, casting no shadow.
func _has_outline(body: MeshInstance3D) -> bool:
	for sibling: Node in body.get_parent().get_children():
		if sibling is MeshInstance3D and sibling.has_meta(BuildingModels.OUTLINE_META):
			var outline := sibling as MeshInstance3D
			return outline.mesh.surface_get_material(0) == MaterialKit.ink() \
				and outline.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return false


## The model's body mesh instances (not the outlines), the spinning one included.
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


## Zooms the camera to an orthographic size and pans it onto a ground point, through the
## same calls a pinch and a drag make.
func _frame(main: MainScript, point: Vector3, size: float) -> void:
	var centre := main.get_viewport().get_visible_rect().size * 0.5
	main.camera.zoom_at(main.camera.size / size, centre)
	main.camera.pan(centre, centre - main.camera.unproject_position(point))
