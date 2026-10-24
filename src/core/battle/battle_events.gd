class_name BattleEvents
extends RefCounted
## What happened in the battle's last tick, for the view to draw (docs/reference/battle.md):
## shots, shells, detonations, falls, deaths and abilities. Pure logic. The arrays are reused from tick to
## tick, so only the first `count` entries are this tick's; they grow only when a tick has more
## events than any before it.
##
## `source` and `target` are a building id, a unit id or an ability's place, as the kind says;
## (from_x, from_y) and (to_x, to_y) are field units; `land_tick` is the tick a shell lands or an
## ability's effect ends or lands, else the tick itself.

## A unit hits a building: source unit, target building.
const UNIT_HIT := 0
## A defence hits a unit: source building, target unit.
const SHOT := 1
## A shell is fired: source building, target unit (aimed at), landing at to and land_tick.
const SHELL := 2
## A shell lands at to: source building.
const SHELL_LAND := 3
## A gravity well holds the air units in range: source building.
const HOLD := 4
## A trap goes off: source building (the trap).
const DETONATE := 5
## A unit is thrown from from to to: source building (the trap), target unit.
const THROW := 6
## A hidden building is revealed: source building.
const REVEAL := 7
## A building falls: source building.
const FALL := 8
## A unit dies: target unit.
const DEATH := 9
## An ability is used at to: source the ability's place in catalog.ability_types() plus one;
## land_tick the tick its effect ends (a swarm), the defences wake (an EMP burst) or it lands (a
## strike).
const ABILITY := 10
## An orbital strike lands at to: source as for ABILITY.
const STRIKE_LAND := 11

const START_CAPACITY := 256

var count: int = 0
var kind: PackedInt32Array = PackedInt32Array()
var source: PackedInt32Array = PackedInt32Array()
var target: PackedInt32Array = PackedInt32Array()
var from_x: PackedInt32Array = PackedInt32Array()
var from_y: PackedInt32Array = PackedInt32Array()
var to_x: PackedInt32Array = PackedInt32Array()
var to_y: PackedInt32Array = PackedInt32Array()
var land_tick: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	_grow(START_CAPACITY)


func clear() -> void:
	count = 0


func add(event_kind: int, source_id: int, target_id: int, fx: int, fy: int, tx: int, ty: int,
		lands: int) -> void:
	if count == kind.size():
		_grow(count * 2)
	kind[count] = event_kind
	source[count] = source_id
	target[count] = target_id
	from_x[count] = fx
	from_y[count] = fy
	to_x[count] = tx
	to_y[count] = ty
	land_tick[count] = lands
	count += 1


func _grow(size: int) -> void:
	kind.resize(size)
	source.resize(size)
	target.resize(size)
	from_x.resize(size)
	from_y.resize(size)
	to_x.resize(size)
	to_y.resize(size)
	land_tick.resize(size)
