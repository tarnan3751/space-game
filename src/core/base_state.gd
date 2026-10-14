class_name BaseState
extends RefCounted
## The authoritative model of one player's base.
##
## Rules (see CLAUDE.md): pure logic, no Nodes. Time is always passed in as unix
## seconds (int); this class never reads a clock. All amounts are ints. Every change
## goes through apply(), whose command dictionaries are what the client will later
## send to the server, which runs the same validation.

## Emitted after anything visible changes: resources, buildings, levels, timers.
signal changed

const SECONDS_PER_HOUR := 3600

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

var catalog: Catalog
var grid: BaseGrid
## Unix time (seconds) the state has been advanced to.
var now: int = 0
var resources: Dictionary[String, int] = {}
var buildings: Dictionary[int, BuildingState] = {}
## Id of the most recently placed building (not saved; handy for selecting it).
var last_added_id: int = 0

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
		_:
			result = ERR_UNKNOWN_OP
	if result == "":
		changed.emit()
	return result


## Everything about building a new `type` except where it goes. The build menu uses this.
func check_can_build(type: String) -> String:
	if not catalog.has_type(type):
		return ERR_UNKNOWN_TYPE
	if count_of(type) >= catalog.max_count(type, cc_level()):
		return ERR_LIMIT
	return _check_level_requirements(catalog.level_stats(type, 1))


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


# --- Time ----------------------------------------------------------------------

## Moves the base forward to `time`: finishes construction in time order and pays out
## production for each stretch in between, so a building that completes mid-interval
## only produces after it completes. Earlier times are ignored (clocks can go backwards).
func advance_to(time: int) -> void:
	if time <= now:
		return
	var any_change := false
	var next := _next_completion(time)
	while next != null:
		if _accumulate(next.finish_at - now):
			any_change = true
		now = maxi(now, next.finish_at)
		_complete(next)
		any_change = true
		next = _next_completion(time)
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

func capacity(res: String) -> int:
	var total := 0
	for building: BuildingState in buildings.values():
		if building.level >= 1:
			total += _amount(_stats(building), "storage", res)
	return total


## Busy buildings (constructing or upgrading) don't produce.
func production_per_hour(res: String) -> int:
	var total := 0
	for building: BuildingState in buildings.values():
		if building.level >= 1 and not building.is_busy():
			total += _amount(_stats(building), "produces", res)
	return total


func builders_total() -> int:
	var total := 0
	for building: BuildingState in buildings.values():
		if building.level >= 1:
			total += int(_stats(building).get("builders", 0))
	return total


func builders_busy() -> int:
	var total := 0
	for building: BuildingState in buildings.values():
		if building.is_busy():
			total += 1
	return total


func builders_free() -> int:
	return builders_total() - builders_busy()


func cc_level() -> int:
	for building: BuildingState in buildings.values():
		if building.type == Catalog.HQ_TYPE:
			return maxi(building.level, 1)
	return 1


func count_of(type: String) -> int:
	var total := 0
	for building: BuildingState in buildings.values():
		if building.type == type:
			total += 1
	return total


func building_at(cell: Vector2i) -> BuildingState:
	var id := grid.occupant_at(cell)
	if id == 0 or not buildings.has(id):
		return null
	return buildings[id]


func can_afford(cost: Dictionary) -> bool:
	for res: Variant in cost:
		if resources.get(str(res), 0) < int(cost[res]):
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
		"version": 1,
		"now": now,
		"next_id": _next_id,
		"resources": resource_data,
		"remainders": remainder_data,
		"buildings": building_list,
	}


## Rebuilds a base from to_dict() output (works on JSON-parsed data, floats included).
static func from_dict(base_catalog: Catalog, data: Dictionary) -> BaseState:
	var state := BaseState.new(base_catalog)
	state.now = int(data.get("now", 0))
	state._next_id = int(data.get("next_id", 1))
	var resource_data: Dictionary = data.get("resources", {})
	var remainder_data: Dictionary = data.get("remainders", {})
	for res: String in base_catalog.resources:
		state.resources[res] = int(resource_data.get(res, 0))
		state._remainders[res] = int(remainder_data.get(res, 0))
	for entry: Variant in data.get("buildings", []):
		var building := BuildingState.from_dict(entry)
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
	_pay(catalog.level_stats(type, 1).get("cost", {}))
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
	_pay(catalog.level_stats(building.type, building.level + 1).get("cost", {}))
	_start_work(building, building.level + 1)
	return ""


func _check_level_requirements(stats: Dictionary) -> String:
	if int(stats.get("requires_cc", 1)) > cc_level():
		return ERR_CC_LEVEL
	if int(stats.get("build_seconds", 0)) > 0 and builders_free() <= 0:
		return ERR_NO_BUILDER
	if not can_afford(stats.get("cost", {})):
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
	for building: BuildingState in buildings.values():
		if not building.is_busy() or building.finish_at > limit:
			continue
		if best == null:
			best = building
		elif building.finish_at < best.finish_at:
			best = building
		elif building.finish_at == best.finish_at and building.id < best.id:
			best = building
	return best


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


func _pay(cost: Dictionary) -> void:
	for res: Variant in cost:
		var key := str(res)
		resources[key] = resources.get(key, 0) - int(cost[res])


func _stats(building: BuildingState) -> Dictionary:
	return catalog.level_stats(building.type, building.level)


static func _amount(stats: Dictionary, field: String, res: String) -> int:
	var amounts: Dictionary = stats.get(field, {})
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
