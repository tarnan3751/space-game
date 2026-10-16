class_name TemplateBase
extends RefCounted
## The debug build's showcase base (the HUD's Template base, main._template_base): every type in
## the catalog, hidden ones included, as many of each as the top Command Center level allows
## (Catalog.max_count at max_cc_level), all at their top level and finished, grouped by category
## with the walls (PlacementController.PAINT_TYPE) as fences between the groups, and every
## resource at its cap. build() returns a save dictionary in to_dict()'s shape
## (docs/reference/data-format.md, **The save file**) for main.gd to load through
## BaseState.from_dict; it never touches the save itself.
##
## Everything comes from the catalog, so a roster change still lays out. The bands are
## catalog.categories in tab order, from the top of the field (cell y 0) down, with the Command
## Center ("core") leading the first; the walls are left out of their category's band. In a
## band, the types in menu order run left to right from x 0, each type's copies side by side,
## GAP cells between footprints; one that would pass the field's right edge starts a new row GAP
## below the tallest footprint of the row before. The row under each band is a fence: walls, one
## per cell from x 0 rightwards until they run out, and the next band starts on the row after
## it, so buildings touch the fence on both sides. Walls left over once every band has its fence
## carry on in further rows below. With the shipped roster the bands
## are 12, 10, 16 and 2 rows deep (resources, army, defence, traps), and with their fences (the
## 250 walls are four full fences, a fifth row and 10 more) they fill 46 of the 48 rows. A building that does not fit is left out, with an error naming the
## first, rather than overlap.

const GAP := 1

var _catalog: Catalog
## What is laid out so far, so nothing overlaps or leaves the field.
var _grid: BaseGrid
var _buildings: Array[Dictionary] = []
## The wall pieces still to lay in fences, one type per piece.
var _walls := PackedStringArray()
## The first type that did not fit; "" while everything has.
var _left_out: String = ""


func _init(catalog: Catalog, grid: Vector2i) -> void:
	_catalog = catalog
	_grid = BaseGrid.new(grid.x, grid.y)


static func build(catalog: Catalog, grid: Vector2i, now: int) -> Dictionary:
	var template := TemplateBase.new(catalog, grid)
	var order := PackedStringArray(catalog.menu_order)
	for type: String in catalog.types():
		if not order.has(type):
			order.append(type)
	var cc_level := catalog.max_cc_level()
	for i: int in catalog.max_count(PlacementController.PAINT_TYPE, cc_level):
		template._walls.append(PlacementController.PAINT_TYPE)
	var y := 0
	var leading := PackedStringArray([Catalog.CORE_CATEGORY])
	for category: String in catalog.categories:
		leading.append(category)
		var types := PackedStringArray()
		for band_category: String in leading:
			for type: String in order:
				if catalog.category_of(type) == band_category and type != PlacementController.PAINT_TYPE:
					for i: int in catalog.max_count(type, cc_level):
						types.append(type)
		leading.clear()
		if types.is_empty():
			continue
		y = template._fence(template._band(types, y))
	while not template._walls.is_empty():
		y = template._fence(y)
	if template._left_out != "":
		push_error("The template base does not fit the field: %s and any later building that did not fit are left out"
			% template._left_out)

	var amounts := {}
	var remainders := {}
	for res: String in catalog.resources:
		amounts[res] = 0
		remainders[res] = 0
	var data := {
		"version": BaseState.SAVE_VERSION,
		"grid": {"width": grid.x, "height": grid.y},
		"now": now,
		"next_id": template._buildings.size() + 1,
		"resources": amounts,
		"remainders": remainders,
		"buildings": template._buildings,
	}
	# Every resource at the cap of the base as laid out, which BaseState works out.
	var laid_out := BaseState.from_dict(catalog, data)
	for res: String in catalog.resources:
		amounts[res] = laid_out.capacity(res)
	return data


## Lays `types` out in rows from (0, y), a type's copies side by side; returns the row under
## the band.
func _band(types: PackedStringArray, y: int) -> int:
	var x := 0
	var depth := 0
	for type: String in types:
		var size := _catalog.size_of(type)
		if x > 0 and x + size > _grid.width:
			y += depth + GAP
			x = 0
			depth = 0
		_add(type, Vector2i(x, y))
		x += size + GAP
		depth = maxi(depth, size)
	return y + depth


## A fence along row y from x 0, as many of the walls still to lay as the row holds; returns
## the first row of the next band.
func _fence(y: int) -> int:
	var count := mini(_walls.size(), _grid.width)
	for x: int in count:
		_add(_walls[x], Vector2i(x, y))
	_walls = _walls.slice(count)
	return y + GAP


func _add(type: String, cell: Vector2i) -> void:
	var size := _catalog.size_of(type)
	if not _grid.is_free(cell, size):
		if _left_out == "":
			_left_out = type
		return
	var id := _buildings.size() + 1
	_grid.occupy(id, cell, size)
	var level := _catalog.max_level(type)
	_buildings.append({"id": id, "type": type, "cell": [cell.x, cell.y], "level": level,
		"target_level": level, "finish_at": 0})
