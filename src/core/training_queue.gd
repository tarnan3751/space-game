class_name TrainingQueue
extends RefCounted
## The units one producer building has queued, oldest first: units[0] is the head, the one in
## training. paid_levels[i] is the unit level units[i] was paid for, so a cancel refunds what
## was paid.
##
## Running: done_at is the unix time (seconds) the head completes, and left is 0. Stopped:
## done_at is 0 and left is the head's seconds still to go, while the producer is busy, or 0
## when the head has finished and waits for room in the Hangars. Empty: both 0.

var building_id: int = 0
var units: PackedStringArray = PackedStringArray()
var paid_levels: PackedInt32Array = PackedInt32Array()
var done_at: int = 0
var left: int = 0


func is_empty() -> bool:
	return units.is_empty()


func is_running() -> bool:
	return done_at > 0
