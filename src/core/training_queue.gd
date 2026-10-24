class_name TrainingQueue
extends RefCounted
## The units one producer building has queued, oldest first: units[0] is the head, the one in
## training. paid_levels[i] is the unit level units[i] was paid for, so a cancel refunds what
## was paid.
##
## Running: done_at is the unix time (seconds) the head completes, and left is 0. Stopped:
## done_at is 0 and left is the head's seconds still to go, while the producer is busy, or 0
## when the head has finished and waits for room in the Hangars. Empty: both 0.
##
## The Foundry's making queue is one too (BaseState.making): its `units` hold ability ids, its
## paid_levels the ability level each was paid for, and a finished head waits for room in the
## ability stock.

var building_id: int = 0
var units: PackedStringArray = PackedStringArray()
var paid_levels: PackedInt32Array = PackedInt32Array()
var done_at: int = 0
var left: int = 0


func is_empty() -> bool:
	return units.is_empty()


func is_running() -> bool:
	return done_at > 0


func to_dict() -> Dictionary:
	return {
		"building": building_id,
		"units": Array(units),
		"paid_levels": Array(paid_levels),
		"done_at": done_at,
		"left": left,
	}


## Rebuilds a queue from to_dict() output (JSON-parsed data, floats included). BaseState checks
## what it holds against the base and the catalog.
static func from_dict(data: Dictionary) -> TrainingQueue:
	var queue := TrainingQueue.new()
	queue.building_id = int(data.get("building", 0))
	var unit_list: Array = data.get("units", [])
	var level_list: Array = data.get("paid_levels", [])
	for i: int in unit_list.size():
		queue.units.append(str(unit_list[i]))
		queue.paid_levels.append(int(level_list[i]) if i < level_list.size() else 1)
	queue.done_at = int(data.get("done_at", 0))
	queue.left = int(data.get("left", 0))
	return queue
