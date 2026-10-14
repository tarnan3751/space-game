class_name BuildingState
extends RefCounted
## One building in a base.
## `level` is the finished level: 0 while the building is first being constructed.
## While busy, `target_level` is the level under construction and `finish_at` is the
## unix time (seconds) it completes. When idle, target_level == level and finish_at == 0.

var id: int = 0
var type: String = ""
var cell: Vector2i = Vector2i.ZERO
var level: int = 0
var target_level: int = 0
var finish_at: int = 0


func is_busy() -> bool:
	return target_level > level


func to_dict() -> Dictionary:
	return {
		"id": id,
		"type": type,
		"cell": [cell.x, cell.y],
		"level": level,
		"target_level": target_level,
		"finish_at": finish_at,
	}


static func from_dict(data: Dictionary) -> BuildingState:
	var building := BuildingState.new()
	building.id = int(data.get("id", 0))
	building.type = str(data.get("type", ""))
	var cell_data: Array = data.get("cell", [0, 0])
	building.cell = Vector2i(int(cell_data[0]), int(cell_data[1]))
	building.level = int(data.get("level", 0))
	building.target_level = int(data.get("target_level", building.level))
	building.finish_at = int(data.get("finish_at", 0))
	return building
