class_name TemplateBase
extends RefCounted
## The debug build's showcase base (the HUD's Template base, main._template_base): every type in
## the catalog, hidden ones included, at its top level and finished, grouped by category (one of
## each, the walls an enclosure), with every resource at its cap. build() returns a save
## dictionary in to_dict()'s shape (docs/reference/data-format.md, **The save file**) for main.gd
## to load through BaseState.from_dict; it never touches the save itself.
##
## Everything comes from the catalog, so a roster change still lays out. The bands are "core"
## (the Command Center), then catalog.categories in tab order, from the top of the field (cell
## y 0) down. In a band, the types in menu order run left to right from x 0, GAP cells apart;
## one that would pass the field's right edge starts a new row GAP below the tallest footprint
## of the row before, and the next band starts the same way below the last row. The walls band
## (PlacementController.PAINT_CATEGORY) is an enclosure of its first type instead: a WALL_SIZE
## outline split by a run from the middle of its top side to the middle of its bottom, so it
## shows corners, T junctions and straight runs; it narrows to a field narrower than it. A
## building that does not fit is left out, with an error naming the first, rather than overlap.

const GAP := 1
const WALL_SIZE := Vector2i(12, 6)

var _catalog: Catalog
## What is laid out so far, so nothing overlaps or leaves the field.
var _grid: BaseGrid
var _buildings: Array[Dictionary] = []
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
	var bands := PackedStringArray([Catalog.CORE_CATEGORY])
	bands.append_array(catalog.categories)
	var y := 0
	for category: String in bands:
		var types := PackedStringArray()
		for type: String in order:
			if catalog.category_of(type) == category:
				types.append(type)
		if types.is_empty():
			continue
		if category == PlacementController.PAINT_CATEGORY:
			y = template._enclosure(types[0], y)
		else:
			y = template._band(types, y)
	if template._left_out != "":
		push_error("The template base does not fit the field: %s and any later building that did not fit are left out"
			% template._left_out)

	var amounts := {}
	var remainders := {}
	for res: String in catalog.resources:
		amounts[res] = 0
		remainders[res] = 0
	var data := {
		"version": 1,
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


## Lays `types` out in rows from (0, y); returns the first row of the next band.
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
	return y + depth + GAP


## The wall enclosure from (0, y): its outline and the run down its middle.
func _enclosure(type: String, y: int) -> int:
	var width := mini(WALL_SIZE.x, _grid.width)
	for dy: int in WALL_SIZE.y:
		for dx: int in width:
			if dy == 0 or dy == WALL_SIZE.y - 1 or dx == 0 or dx == width - 1 or dx == width / 2:
				_add(type, Vector2i(dx, y + dy))
	return y + WALL_SIZE.y + GAP


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
