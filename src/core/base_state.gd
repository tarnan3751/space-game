class_name BaseState
extends RefCounted
## The authoritative model of one player's base.
##
## Rules (see CLAUDE.md): pure logic, no Nodes. Time is always passed in as unix
## seconds (int); this class never reads a clock. All amounts are ints. Every change
## goes through apply(), whose command dictionaries are what the client will later
## send to the server, which runs the same validation.
##
## The army: `army` counts the units housed, per type; each producer building trains from a
## queue of its own (`training`, TrainingQueue), only while it is idle, and a finished unit
## waits for room in the Hangars (`housing_capacity`).

## Emitted after anything visible changes: resources, buildings, levels, timers, the army.
signal changed

const SECONDS_PER_HOUR := 3600
## The save's shape (to_dict). Version 2 records the field it was laid out on; every version 1
## save was laid out on V1_FIELD, and from_dict centres it on a field that has grown since.
const SAVE_VERSION := 2
const V1_FIELD := Vector2i(40, 40)

const ERR_UNKNOWN_OP := "unknown_op"
const ERR_UNKNOWN_TYPE := "unknown_type"
const ERR_UNKNOWN_BUILDING := "unknown_building"
const ERR_BLOCKED := "blocked"
const ERR_LIMIT := "limit_reached"
const ERR_CC_LEVEL := "needs_command_center_level"
const ERR_NO_BUILDER := "no_free_builder"
const ERR_FUNDS := "insufficient_resources"
const ERR_BUSY := "busy"
const ERR_MAX_LEVEL := "max_level"
const ERR_UNKNOWN_UNIT := "unknown_unit"
const ERR_NOT_PRODUCER := "not_a_producer"
const ERR_BAD_COUNT := "bad_count"
const ERR_PRODUCER_LEVEL := "needs_producer_level"
const ERR_HOUSING := "not_enough_housing"
const ERR_NOT_QUEUED := "not_queued"

## training_status(): nothing queued; the head training; the head stopped with time left while
## the producer is busy (constructing or upgrading); the head finished and waiting for room in
## the Hangars, busy producer or not.
const TRAINING_IDLE := "idle"
const TRAINING_RUNNING := "running"
const TRAINING_PAUSED := "paused"
const TRAINING_WAITING := "waiting"

## A shared, read-only default for lookups, so the checks build no {} per call.
const _EMPTY := {}

var catalog: Catalog
var grid: BaseGrid
## Unix time (seconds) the state has been advanced to.
var now: int = 0
var resources: Dictionary[String, int] = {}
var buildings: Dictionary[int, BuildingState] = {}
## Id of the most recently placed building (not saved; handy for selecting it).
var last_added_id: int = 0
## Units housed, per unit type; every catalog unit has an entry, 0 by default.
var army: Dictionary[String, int] = {}
## Each unit type's level, for the whole type; every catalog unit has an entry, 1 by default.
var unit_levels: Dictionary[String, int] = {}
## Training queues by producer building id. A queue stays when it empties.
var training: Dictionary[int, TrainingQueue] = {}

## Production not yet paid out, per resource, in "resource-seconds" (amount * 3600).
## Keeping the remainder means ticking every second or once a day gives the same total.
var _remainders: Dictionary[String, int] = {}
var _next_id: int = 1


func _init(base_catalog: Catalog) -> void:
	catalog = base_catalog
	grid = BaseGrid.new(catalog.grid_size.x, catalog.grid_size.y)
	for res: String in catalog.resources:
		resources[res] = 0
		_remainders[res] = 0
	for unit: String in catalog.unit_types():
		army[unit] = 0
		unit_levels[unit] = 1


## A brand-new base laid out from the catalog's "start" section. Start buildings are finished.
static func create_new(base_catalog: Catalog, start_time: int) -> BaseState:
	var state := BaseState.new(base_catalog)
	state.now = start_time
	for entry: Variant in base_catalog.start.get("buildings", []):
		var entry_dict: Dictionary = entry
		var type := str(entry_dict.get("type", ""))
		var cell_data: Array = entry_dict.get("cell", [-1, -1])
		var cell := Vector2i(int(cell_data[0]), int(cell_data[1]))
		if not base_catalog.has_type(type) or not state.grid.is_free(cell, base_catalog.size_of(type)):
			continue
		var building := state._add_building(type, cell)
		building.level = int(entry_dict.get("level", 1))
		building.target_level = building.level
	var start_resources: Dictionary = base_catalog.start.get("resources", {})
	for res: String in base_catalog.resources:
		state.resources[res] = mini(int(start_resources.get(res, 0)), state.capacity(res))
	return state


# --- Commands ------------------------------------------------------------------

## Applies one command and returns "" on success or an ERR_* code. Advances to `at_time` first.
##   {"op": "place",   "type": String, "cell": [x, y]}
##   {"op": "move",    "id": int,      "cell": [x, y]}
##   {"op": "upgrade", "id": int}
##   {"op": "train",   "id": int,      "unit": String, "count": int}   (count optional, 1)
##   {"op": "cancel_training", "id": int, "unit": String}
func apply(command: Dictionary, at_time: int) -> String:
	advance_to(at_time)
	var result := ""
	match str(command.get("op", "")):
		"place":
			result = _place(str(command.get("type", "")), _cell_from(command.get("cell")))
		"move":
			result = _move(int(command.get("id", 0)), _cell_from(command.get("cell")))
		"upgrade":
			result = _upgrade(int(command.get("id", 0)))
		"train":
			result = _train(int(command.get("id", 0)), str(command.get("unit", "")),
				int(command.get("count", 1)))
		"cancel_training":
			result = _cancel_training(int(command.get("id", 0)), str(command.get("unit", "")))
		_:
			result = ERR_UNKNOWN_OP
	if result == "":
		# An upgrade stops its building's training; a train starts it.
		_resume_training()
		changed.emit()
	return result


## Everything about building a new `type` except where it goes. The build menu uses this.
## The Command Center level is checked before the limit, so a type it has not unlocked yet
## (max_count 0 at this level) reads as locked rather than maxed.
func check_can_build(type: String) -> String:
	if not catalog.has_type(type):
		return ERR_UNKNOWN_TYPE
	var stats := catalog.level_stats(type, 1)
	if int(stats.get("requires_cc", 1)) > cc_level():
		return ERR_CC_LEVEL
	if count_of(type) >= catalog.max_count(type, cc_level()):
		return ERR_LIMIT
	return _check_level_requirements(stats)


func check_place(type: String, cell: Vector2i) -> String:
	var error := check_can_build(type)
	if error != "":
		return error
	if not grid.is_free(cell, catalog.size_of(type)):
		return ERR_BLOCKED
	return ""


func check_move(id: int, cell: Vector2i) -> String:
	if not buildings.has(id):
		return ERR_UNKNOWN_BUILDING
	var building: BuildingState = buildings[id]
	if not grid.is_free(cell, catalog.size_of(building.type), id):
		return ERR_BLOCKED
	return ""


func check_upgrade(id: int) -> String:
	if not buildings.has(id):
		return ERR_UNKNOWN_BUILDING
	var building: BuildingState = buildings[id]
	if building.is_busy():
		return ERR_BUSY
	if building.level >= catalog.max_level(building.type):
		return ERR_MAX_LEVEL
	return _check_level_requirements(catalog.level_stats(building.type, building.level + 1))


## Everything about queueing `count` of `unit` at producer `id`. The queue limit is the
## housing: the army plus every queue, this one included, fits the Hangars. A count above the
## whole housing is refused before anything is multiplied by it, so no product can overflow.
func check_train(id: int, unit: String, count: int = 1) -> String:
	if not catalog.has_unit(unit):
		return ERR_UNKNOWN_UNIT
	if not buildings.has(id):
		return ERR_UNKNOWN_BUILDING
	var building: BuildingState = buildings[id]
	if building.type != catalog.unit_producer(unit):
		return ERR_NOT_PRODUCER
	if count < 1:
		return ERR_BAD_COUNT
	if building.level < catalog.unit_producer_level(unit):
		return ERR_PRODUCER_LEVEL
	var room := housing_capacity()
	if count > room or housing_used() + housing_queued() + count * catalog.unit_housing(unit) > room:
		return ERR_HOUSING
	if not can_afford(_train_cost(unit, unit_levels[unit]), count):
		return ERR_FUNDS
	return ""


func check_cancel_training(id: int, unit: String) -> String:
	if not buildings.has(id):
		return ERR_UNKNOWN_BUILDING
	if not training.has(id) or not training[id].units.has(unit):
		return ERR_NOT_QUEUED
	return ""


# --- Time ----------------------------------------------------------------------

## Moves the base forward to `time`: finishes construction and training in time order and
## pays out production for each stretch in between, so a building that completes mid-interval
## only produces after it completes. At one second, buildings complete before units, so a
## Hangar finishing then already houses them. Earlier times are ignored (clocks can go
## backwards).
func advance_to(time: int) -> void:
	if time <= now:
		return
	var any_change := false
	while true:
		var building := _next_completion(time)
		var queue := _next_training(time)
		if building == null and queue == null:
			break
		any_change = true
		if building != null and (queue == null or building.finish_at <= queue.done_at):
			if _accumulate(building.finish_at - now):
				any_change = true
			now = maxi(now, building.finish_at)
			_complete(building)
		else:
			if _accumulate(queue.done_at - now):
				any_change = true
			now = maxi(now, queue.done_at)
			_finish_head(queue)
		# A finished producer resumes, a finished Hangar or unit changes the room.
		_resume_training()
	if _accumulate(time - now):
		any_change = true
	now = time
	if any_change:
		changed.emit()


func seconds_left(id: int) -> int:
	if not buildings.has(id):
		return 0
	var building: BuildingState = buildings[id]
	if not building.is_busy():
		return 0
	return maxi(0, building.finish_at - now)


# --- Queries -------------------------------------------------------------------

# The queries iterate the ids rather than buildings.values(), which builds an Array per
# call: the HUD runs the placement checks every frame while a ghost is dragged, and the
# server will run the checks and the tick per command.

func capacity(res: String) -> int:
	var total := 0
	for id: int in buildings:
		var building: BuildingState = buildings[id]
		if building.level >= 1:
			total += _amount(_stats(building), "storage", res)
	return total


## Busy buildings (constructing or upgrading) don't produce.
func production_per_hour(res: String) -> int:
	var total := 0
	for id: int in buildings:
		var building: BuildingState = buildings[id]
		if building.level >= 1 and not building.is_busy():
			total += _amount(_stats(building), "produces", res)
	return total


func builders_total() -> int:
	var total := 0
	for id: int in buildings:
		var building: BuildingState = buildings[id]
		if building.level >= 1:
			total += int(_stats(building).get("builders", 0))
	return total


func builders_busy() -> int:
	var total := 0
	for id: int in buildings:
		var building: BuildingState = buildings[id]
		if building.is_busy():
			total += 1
	return total


## The army housing: the `capacity` of every finished housing building (rules.army.housing) at
## its current level, busy or not, like storage.
func housing_capacity() -> int:
	var total := 0
	for id: int in buildings:
		var building: BuildingState = buildings[id]
		if building.type == catalog.housing_type and building.level >= 1:
			total += int(_stats(building).get("capacity", 0))
	return total


## Housing the army takes. Units still in training are not housed yet.
func housing_used() -> int:
	var total := 0
	for unit: String in army:
		total += army[unit] * catalog.unit_housing(unit)
	return total


## Housing every queued unit will take, the one in training included.
func housing_queued() -> int:
	var total := 0
	for id: int in training:
		var queue: TrainingQueue = training[id]
		for unit: String in queue.units:
			total += catalog.unit_housing(unit)
	return total


func army_count(unit: String) -> int:
	var count: int = army.get(unit, 0)
	return count


## A unit type's level; 0 for a type the catalog does not have.
func unit_level(unit: String) -> int:
	var level: int = unit_levels.get(unit, 0)
	return level


## The units queued at a producer, oldest (the one in training) first: a copy, built per call,
## since a packed array handed out shares its buffer with the queue's.
func queue_of(id: int) -> PackedStringArray:
	if not training.has(id):
		return PackedStringArray()
	return training[id].units.duplicate()


## One of the TRAINING_* states of a producer's queue.
func training_status(id: int) -> String:
	if not training.has(id) or training[id].is_empty():
		return TRAINING_IDLE
	var queue: TrainingQueue = training[id]
	if queue.is_running():
		return TRAINING_RUNNING
	if queue.left > 0:
		return TRAINING_PAUSED
	return TRAINING_WAITING


## Seconds until the head of a producer's queue finishes training; 0 when it has (waiting).
func training_seconds_left(id: int) -> int:
	if not training.has(id):
		return 0
	var queue: TrainingQueue = training[id]
	if queue.is_running():
		return maxi(0, queue.done_at - now)
	return queue.left


func builders_free() -> int:
	return builders_total() - builders_busy()


func cc_level() -> int:
	for id: int in buildings:
		var building: BuildingState = buildings[id]
		if building.type == Catalog.HQ_TYPE:
			return maxi(building.level, 1)
	return 1


func count_of(type: String) -> int:
	var total := 0
	for id: int in buildings:
		var building: BuildingState = buildings[id]
		if building.type == type:
			total += 1
	return total


func building_at(cell: Vector2i) -> BuildingState:
	var id := grid.occupant_at(cell)
	if id == 0 or not buildings.has(id):
		return null
	return buildings[id]


## Whether `times` of `cost` can be paid at once.
func can_afford(cost: Dictionary, times: int = 1) -> bool:
	for res: Variant in cost:
		if resources.get(str(res), 0) < int(cost[res]) * times:
			return false
	return true


# --- Save / load ---------------------------------------------------------------

func to_dict() -> Dictionary:
	var building_list := []
	for id: int in _sorted_ids():
		building_list.append(buildings[id].to_dict())
	var resource_data := {}
	var remainder_data := {}
	for res: String in catalog.resources:
		resource_data[res] = resources[res]
		remainder_data[res] = _remainders[res]
	return {
		"version": SAVE_VERSION,
		"grid": {"width": catalog.grid_size.x, "height": catalog.grid_size.y},
		"now": now,
		"next_id": _next_id,
		"resources": resource_data,
		"remainders": remainder_data,
		"buildings": building_list,
	}


## Rebuilds a base from to_dict() output (works on JSON-parsed data, floats included). A version
## 1 save (or one with no version) was laid out on V1_FIELD: its buildings move by half the
## field's growth since, so the base stays centred; a field that did not grow moves nothing.
static func from_dict(base_catalog: Catalog, data: Dictionary) -> BaseState:
	var state := BaseState.new(base_catalog)
	var shift := Vector2i.ZERO
	if int(data.get("version", 1)) < 2:
		shift = ((base_catalog.grid_size - V1_FIELD) / 2).max(Vector2i.ZERO)
	state.now = int(data.get("now", 0))
	state._next_id = int(data.get("next_id", 1))
	var resource_data: Dictionary = data.get("resources", {})
	var remainder_data: Dictionary = data.get("remainders", {})
	for res: String in base_catalog.resources:
		state.resources[res] = int(resource_data.get(res, 0))
		state._remainders[res] = int(remainder_data.get(res, 0))
	for entry: Variant in data.get("buildings", []):
		var building := BuildingState.from_dict(entry)
		building.cell += shift
		if not base_catalog.has_type(building.type):
			continue
		# Data changes (a bigger footprint, a smaller grid) can make an old save overlap
		# or overflow. Drop such buildings rather than corrupt the grid.
		if not state.grid.is_free(building.cell, base_catalog.size_of(building.type)):
			continue
		state.buildings[building.id] = building
		state.grid.occupy(building.id, building.cell, base_catalog.size_of(building.type))
		state._next_id = maxi(state._next_id, building.id + 1)
	return state


# --- Internals -----------------------------------------------------------------

func _place(type: String, cell: Vector2i) -> String:
	var error := check_place(type, cell)
	if error != "":
		return error
	_pay(catalog.level_stats(type, 1).get("cost", _EMPTY))
	var building := _add_building(type, cell)
	_start_work(building, 1)
	return ""


func _move(id: int, cell: Vector2i) -> String:
	var error := check_move(id, cell)
	if error != "":
		return error
	var building: BuildingState = buildings[id]
	var size := catalog.size_of(building.type)
	grid.vacate(building.cell, size)
	building.cell = cell
	grid.occupy(id, cell, size)
	return ""


func _upgrade(id: int) -> String:
	var error := check_upgrade(id)
	if error != "":
		return error
	var building: BuildingState = buildings[id]
	_pay(catalog.level_stats(building.type, building.level + 1).get("cost", _EMPTY))
	_start_work(building, building.level + 1)
	return ""


func _train(id: int, unit: String, count: int) -> String:
	var error := check_train(id, unit, count)
	if error != "":
		return error
	var level: int = unit_levels[unit]
	_pay(_train_cost(unit, level), count)
	if not training.has(id):
		var created := TrainingQueue.new()
		created.building_id = id
		training[id] = created
	var queue: TrainingQueue = training[id]
	var was_empty := queue.is_empty()
	for i: int in count:
		queue.units.append(unit)
		queue.paid_levels.append(level)
	if was_empty:
		_start_head(queue)
	return ""


## Removes the newest queued `unit` and refunds what it was paid, up to storage. Removing the
## head starts the next unit from the beginning.
func _cancel_training(id: int, unit: String) -> String:
	var error := check_cancel_training(id, unit)
	if error != "":
		return error
	var queue: TrainingQueue = training[id]
	var index := queue.units.rfind(unit)
	_refund(_train_cost(unit, queue.paid_levels[index]))
	queue.units.remove_at(index)
	queue.paid_levels.remove_at(index)
	if index == 0:
		_start_head(queue)
	return ""


func _check_level_requirements(stats: Dictionary) -> String:
	if int(stats.get("requires_cc", 1)) > cc_level():
		return ERR_CC_LEVEL
	if int(stats.get("build_seconds", 0)) > 0 and builders_free() <= 0:
		return ERR_NO_BUILDER
	if not can_afford(stats.get("cost", _EMPTY)):
		return ERR_FUNDS
	return ""


func _add_building(type: String, cell: Vector2i) -> BuildingState:
	var building := BuildingState.new()
	building.id = _next_id
	_next_id += 1
	building.type = type
	building.cell = cell
	buildings[building.id] = building
	grid.occupy(building.id, cell, catalog.size_of(type))
	last_added_id = building.id
	return building


func _start_work(building: BuildingState, to_level: int) -> void:
	var seconds := int(catalog.level_stats(building.type, to_level).get("build_seconds", 0))
	building.target_level = to_level
	building.finish_at = now + seconds
	if seconds <= 0:
		_complete(building)


func _complete(building: BuildingState) -> void:
	building.level = building.target_level
	building.finish_at = 0


## Earliest busy building finishing at or before `limit`; ties broken by id so the
## order is identical on every device and on the server.
func _next_completion(limit: int) -> BuildingState:
	var best: BuildingState = null
	for id: int in buildings:
		var building: BuildingState = buildings[id]
		if not building.is_busy() or building.finish_at > limit:
			continue
		if best == null:
			best = building
		elif building.finish_at < best.finish_at:
			best = building
		elif building.finish_at == best.finish_at and building.id < best.id:
			best = building
	return best


## Earliest running training queue finishing at or before `limit`; ties broken by producer id.
func _next_training(limit: int) -> TrainingQueue:
	var best: TrainingQueue = null
	for id: int in training:
		var queue: TrainingQueue = training[id]
		if not queue.is_running() or queue.done_at > limit:
			continue
		if best == null or queue.done_at < best.done_at \
				or (queue.done_at == best.done_at and id < best.building_id):
			best = queue
	return best


## Sets the queue's head (if any) to train from the beginning, stopped: _resume_training
## starts it when its producer is idle.
func _start_head(queue: TrainingQueue) -> void:
	queue.done_at = 0
	queue.left = 0
	if not queue.is_empty():
		queue.left = catalog.unit_train_seconds(queue.units[0])


## The head has trained: housed if there is room, else it waits for room.
func _finish_head(queue: TrainingQueue) -> void:
	queue.done_at = 0
	queue.left = 0
	var unit := queue.units[0]
	if housing_used() + catalog.unit_housing(unit) > housing_capacity():
		return
	army[unit] += 1
	queue.units.remove_at(0)
	queue.paid_levels.remove_at(0)
	_start_head(queue)


## Brings every queue in line with its producer and the room in the Hangars at `now`: a busy
## producer's queue stops with the time it has left and an idle one's runs, each queue on its
## own, so the order does not matter; then a head waiting for room is housed when it fits,
## busy producer or not, lowest producer id first.
func _resume_training() -> void:
	for id: int in training:
		var queue: TrainingQueue = training[id]
		if queue.is_empty():
			continue
		var busy := buildings[id].is_busy()
		if queue.is_running() and busy:
			queue.left = queue.done_at - now
			queue.done_at = 0
		elif not queue.is_running() and not busy and queue.left > 0:
			queue.done_at = now + queue.left
			queue.left = 0
	var waiting := _next_waiting()
	while waiting != null:
		_finish_head(waiting)
		if not waiting.is_empty() and not buildings[waiting.building_id].is_busy():
			waiting.done_at = now + waiting.left
			waiting.left = 0
		waiting = _next_waiting()


## The lowest-id queue whose head has trained, waits for room and fits now. A lower id whose
## head does not fit is passed over for one that does.
func _next_waiting() -> TrainingQueue:
	var best: TrainingQueue = null
	var room := housing_capacity() - housing_used()
	for id: int in training:
		var queue: TrainingQueue = training[id]
		if queue.is_empty() or queue.is_running() or queue.left > 0:
			continue
		if catalog.unit_housing(queue.units[0]) > room:
			continue
		if best == null or id < best.building_id:
			best = queue
	return best


func _train_cost(unit: String, level: int) -> Dictionary:
	return catalog.unit_level_stats(unit, level).get("train_cost", _EMPTY)


## Pays out production for `seconds` at current rates, capped by storage. Returns true
## if any resource amount changed.
func _accumulate(seconds: int) -> bool:
	if seconds <= 0:
		return false
	var any_change := false
	for res: String in catalog.resources:
		var rate := production_per_hour(res)
		if rate <= 0:
			continue
		var pending: int = _remainders[res] + rate * seconds
		var gained: int = pending / SECONDS_PER_HOUR
		_remainders[res] = pending % SECONDS_PER_HOUR
		if gained > 0:
			# Full storage stops production but never removes what's already there.
			var before: int = resources[res]
			var after := maxi(before, mini(capacity(res), before + gained))
			if after != before:
				resources[res] = after
				any_change = true
	return any_change


func _pay(cost: Dictionary, times: int = 1) -> void:
	for res: Variant in cost:
		var key := str(res)
		resources[key] = resources.get(key, 0) - int(cost[res]) * times


## Gives `amount` back, up to storage; like production, it never removes what is there.
func _refund(amount: Dictionary) -> void:
	for res: Variant in amount:
		var key := str(res)
		var before: int = resources.get(key, 0)
		resources[key] = maxi(before, mini(capacity(key), before + int(amount[res])))


func _stats(building: BuildingState) -> Dictionary:
	return catalog.level_stats(building.type, building.level)


static func _amount(stats: Dictionary, field: String, res: String) -> int:
	var amounts: Dictionary = stats.get(field, _EMPTY)
	return int(amounts.get(res, 0))


static func _cell_from(value: Variant) -> Vector2i:
	if typeof(value) == TYPE_VECTOR2I:
		return value
	if typeof(value) == TYPE_ARRAY:
		var values: Array = value
		if values.size() == 2:
			return Vector2i(int(values[0]), int(values[1]))
	return Vector2i(-1, -1)


func _sorted_ids() -> Array[int]:
	var ids: Array[int] = []
	for id: int in buildings:
		ids.append(id)
	ids.sort()
	return ids
