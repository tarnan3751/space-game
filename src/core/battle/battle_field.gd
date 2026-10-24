class_name BattleField
extends RefCounted
## The battle's cells (docs/reference/battle.md): what stands on each, for the ground units'
## pathing, and the deploy zone. Pure logic.
##
## `kind` says whether a cell is free, a wall or another building; traps stand on free cells,
## since units walk over them. `building` is the index + 1 of what stands on a cell (0 for none).
## `cover` counts, per cell, the footprints grown by one cell that cover it, walls included and
## traps left out (they are hidden); a cell is a deploy cell while nothing covers it, so the zone
## opens as buildings fall and a cell under two footprints stays shut until both have.

const FREE := 0
const WALL := 1
const BUILDING := 2

var width: int = 0
var height: int = 0
var kind: PackedByteArray = PackedByteArray()
var building: PackedInt32Array = PackedInt32Array()
var cover: PackedInt32Array = PackedInt32Array()


func _init(grid: Vector2i) -> void:
	width = grid.x
	height = grid.y
	kind.resize(width * height)
	kind.fill(FREE)
	building.resize(width * height)
	building.fill(0)
	cover.resize(width * height)
	cover.fill(0)


## Puts every standing building of the layout on the field.
func place_all(layout: BattleLayout) -> void:
	for b: int in layout.count:
		if layout.classes[b] == BattleLayout.TRAP:
			continue
		var value := WALL if layout.classes[b] == BattleLayout.WALL else BUILDING
		for y: int in range(layout.cell_y[b], layout.cell_y[b] + layout.sizes[b]):
			for x: int in range(layout.cell_x[b], layout.cell_x[b] + layout.sizes[b]):
				kind[y * width + x] = value
				building[y * width + x] = b + 1
		_cover(layout, b, 1)


## A building has fallen: its cells are free and the deploy zone it made is lifted, cell by cell,
## where no other footprint still covers it. A trap was never on the field.
func remove(layout: BattleLayout, b: int) -> void:
	if layout.classes[b] == BattleLayout.TRAP:
		return
	for y: int in range(layout.cell_y[b], layout.cell_y[b] + layout.sizes[b]):
		for x: int in range(layout.cell_x[b], layout.cell_x[b] + layout.sizes[b]):
			kind[y * width + x] = FREE
			building[y * width + x] = 0
	_cover(layout, b, -1)


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


## In the field and outside every standing footprint grown by one cell.
func is_deploy_cell(cell: Vector2i) -> bool:
	return in_bounds(cell) and cover[cell.y * width + cell.x] == 0


func kind_at(cell: Vector2i) -> int:
	if not in_bounds(cell):
		return BUILDING
	return kind[cell.y * width + cell.x]


func _cover(layout: BattleLayout, b: int, delta: int) -> void:
	var left := maxi(0, layout.cell_x[b] - 1)
	var top := maxi(0, layout.cell_y[b] - 1)
	var right := mini(width - 1, layout.cell_x[b] + layout.sizes[b])
	var bottom := mini(height - 1, layout.cell_y[b] + layout.sizes[b])
	for y: int in range(top, bottom + 1):
		for x: int in range(left, right + 1):
			cover[y * width + x] += delta
