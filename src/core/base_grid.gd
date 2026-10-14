class_name BaseGrid
extends RefCounted
## Occupancy grid for one base. Each cell holds the id of the building on it (0 = empty).
## A building at `cell` with footprint `size` covers cell.x..cell.x+size-1 (same for y).

var width: int
var height: int
var _cells: PackedInt32Array = PackedInt32Array()


func _init(grid_width: int, grid_height: int) -> void:
	width = grid_width
	height = grid_height
	_cells.resize(width * height)
	_cells.fill(0)


func in_bounds(cell: Vector2i, size: int) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x + size <= width and cell.y + size <= height


## True when the whole footprint is inside the grid and empty (cells owned by
## `ignore_id` count as empty, so a building can move onto its own old spot).
func is_free(cell: Vector2i, size: int, ignore_id: int = 0) -> bool:
	if not in_bounds(cell, size):
		return false
	for y: int in range(cell.y, cell.y + size):
		for x: int in range(cell.x, cell.x + size):
			var occupant: int = _cells[y * width + x]
			if occupant != 0 and occupant != ignore_id:
				return false
	return true


func occupant_at(cell: Vector2i) -> int:
	if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
		return 0
	return _cells[cell.y * width + cell.x]


func occupy(id: int, cell: Vector2i, size: int) -> void:
	_set_area(id, cell, size)


func vacate(cell: Vector2i, size: int) -> void:
	_set_area(0, cell, size)


func _set_area(value: int, cell: Vector2i, size: int) -> void:
	for y: int in range(cell.y, cell.y + size):
		for x: int in range(cell.x, cell.x + size):
			_cells[y * width + x] = value
