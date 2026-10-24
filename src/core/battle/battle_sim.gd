class_name BattleSim
extends RefCounted
## A deterministic battle: the attacker's army against a defended layout (docs/reference/
## battle.md). Pure logic, like all of src/core: no clock (time is the tick count, 20 a second),
## integers only, ties broken by id, and no randomness: the setup's seed is kept in a SeededRng
## for rules to come, and no rule draws from it yet. The same setup gives the same result on every
## device and on the server.
##
## A battle is made from a setup, which is exactly its replay:
##   {"seed": int,
##    "attacker": {"army": {unit: count}, "unit_levels": {unit: level}, "abilities": {}},
##    "defender": {"buildings": [{"id", "type", "level", "cell": [x, y]}, ...],
##                 "resources": {resource: int}},
##    "commands": [command, ...]}
## Commands, in tick order, are applied at the start of their tick; the view sends them live
## through command() instead:
##   {"op": "deploy", "tick": int, "unit": String, "cell": [x, y]}
##   {"op": "ability", "tick": int, "ability": String, "cell": [x, y]}   (step 4b; refused now)
##   {"op": "surrender", "tick": int}
##
## A tick: the commands due; the unit phase (BattleArmy): the units with a target act, their
## falls are passed on, then the units wanting a target get one and act, and their falls are
## passed on; the unit buckets; the defence phase (BattleCombat); the falls and reveals of that;
## then the clock, and the end:
## the timer, 100% destruction, no unit standing and none left to deploy, or a surrender.

const TICKS_PER_SECOND := 20
const TICK_MS := 50

const ERR_BAD_TICK := "bad_tick"
const ERR_UNKNOWN_OP := "unknown_op"
const ERR_UNKNOWN_UNIT := "unknown_unit"
const ERR_NONE_LEFT := "none_left"
const ERR_BLOCKED := "blocked"
const ERR_UNKNOWN_ABILITY := "unknown_ability"
const ERR_OVER := "battle_over"

## "" when the setup was accepted, else why it was not; a refused battle never runs.
var setup_error: String = ""
## Ticks run so far.
var tick: int = 0
var catalog: Catalog
var layout: BattleLayout
var field: BattleField
var pathing: BattlePathing
var army: BattleArmy
var combat: BattleCombat
var events: BattleEvents = BattleEvents.new()
## Seeded from the setup and unused by today's rules.
var rng: SeededRng

var _seed: int = 0
var _total_ticks: int = 0
var _commands: Array = []
var _next_command: int = 0
var _log: Array[Dictionary] = []
var _over: bool = false
## Falls and reveals passed on so far.
var _falls_done: int = 0
var _reveals_done: int = 0


## A battle from a setup; check setup_error before running it.
static func create(battle_catalog: Catalog, setup: Dictionary) -> BattleSim:
	var sim := BattleSim.new()
	sim.catalog = battle_catalog
	sim.setup_error = sim._setup(setup)
	return sim


## Runs a setup to its end and returns the result; {} for a refused setup.
static func run(battle_catalog: Catalog, setup: Dictionary) -> Dictionary:
	var sim := create(battle_catalog, setup)
	if sim.setup_error != "":
		return {}
	sim.run_to_end()
	return sim.result()


func ticks_total() -> int:
	return _total_ticks


func seconds_left() -> int:
	return (_total_ticks - tick + TICKS_PER_SECOND - 1) / TICKS_PER_SECOND


func is_over() -> bool:
	return _over


## One tick.
func step() -> void:
	if _over:
		return
	events.clear()
	while _next_command < _commands.size():
		var next: Dictionary = _commands[_next_command]
		if int(next.get("tick", 0)) > tick:
			break
		_next_command += 1
		command(next)
	if _over:
		return
	army.act(tick, combat, events)
	_pass_on()
	army.aim_and_act(tick, combat, events)
	_pass_on()
	army.rebuild_buckets()
	combat.tick(tick, events)
	_pass_on()
	tick += 1
	if tick >= _total_ticks or (layout.counted > 0 and layout.counted_fallen == layout.counted) \
			or (army.alive == 0 and army.left_total() == 0):
		_over = true


func run_to_end() -> void:
	while not _over:
		step()


# --- Commands ------------------------------------------------------------------

## Applies a command at the current tick; "" or an ERR_* code. A command naming a tick must
## name this one. Accepted commands are logged with this tick, for the replay.
func command(cmd: Dictionary) -> String:
	if _over:
		return ERR_OVER
	if cmd.has("tick") and BattleMath.whole(cmd["tick"]) != tick:
		return ERR_BAD_TICK
	match str(cmd.get("op", "")):
		"deploy":
			var unit := str(cmd.get("unit", ""))
			var cell := BattleMath.cell_from(cmd.get("cell"))
			var error := check_deploy(unit, cell)
			if error != "":
				return error
			army.deploy(army.type_index(unit), cell)
			_log.append({"cell": [cell.x, cell.y], "op": "deploy", "tick": tick, "unit": unit})
		"ability":
			return ERR_UNKNOWN_ABILITY
		"surrender":
			_log.append({"op": "surrender", "tick": tick})
			_over = true
		_:
			return ERR_UNKNOWN_OP
	return ""


func check_deploy(unit: String, cell: Vector2i) -> String:
	if _over:
		return ERR_OVER
	if not catalog.has_unit(unit):
		return ERR_UNKNOWN_UNIT
	var t := army.type_index(unit)
	if t < 0 or army.left[t] <= 0:
		return ERR_NONE_LEFT
	if not field.is_deploy_cell(cell):
		return ERR_BLOCKED
	return ""


## In the field and outside every standing footprint grown by one cell (traps left out).
func is_deploy_cell(cell: Vector2i) -> bool:
	return field.is_deploy_cell(cell)


func left_to_deploy(unit: String) -> int:
	var t := army.type_index(unit)
	return army.left[t] if t >= 0 else 0


# --- Units (ids 1..unit_count(), in deploy order) -------------------------------

func unit_count() -> int:
	return army.count


func unit_type(id: int) -> String:
	return army.type_names[army.unit_type[id - 1]]


func unit_position(id: int) -> Vector2i:
	return Vector2i(army.x[id - 1], army.y[id - 1])


func unit_heading(id: int) -> Vector2i:
	return Vector2i(army.heading_x[id - 1], army.heading_y[id - 1])


func unit_hp(id: int) -> int:
	return army.hp[id - 1]


func unit_max_hp(id: int) -> int:
	return army.max_hp(id - 1)


## One of BattleArmy's IDLE, WALKING, ATTACKING, DEAD, STUNNED or HELD (stunned and held over
## the others while they last; held only shows on a unit that would move).
func unit_state(id: int) -> int:
	var u := id - 1
	var unit_state_now := army.state[u]
	if unit_state_now == BattleArmy.DEAD:
		return unit_state_now
	if army.stun_until[u] > tick:
		return BattleArmy.STUNNED
	if army.hold_until[u] > tick and unit_state_now == BattleArmy.WALKING:
		return BattleArmy.HELD
	return unit_state_now


## The building id it is after; 0 for none.
func unit_target(id: int) -> int:
	var b := army.target[id - 1]
	return layout.ids[b] if b >= 0 else 0


# --- Buildings -----------------------------------------------------------------

func building_ids() -> PackedInt32Array:
	return layout.ids


func building_hp(id: int) -> int:
	return layout.hp[layout.index_of(id)]


func building_max_hp(id: int) -> int:
	return layout.max_hp[layout.index_of(id)]


func is_destroyed(id: int) -> bool:
	return layout.destroyed[layout.index_of(id)] != 0


func is_revealed(id: int) -> bool:
	return layout.revealed[layout.index_of(id)] != 0


# --- Progress and the result ---------------------------------------------------

## Buildings destroyed, walls and traps left out, as a whole percent rounded down.
func destruction_pct() -> int:
	if layout.counted == 0:
		return 0
	return layout.counted_fallen * 100 / layout.counted


## One at 50%, one for the Command Center, one at 100%.
func stars() -> int:
	var pct := destruction_pct()
	var total := 0
	if pct >= 50:
		total += 1
	if layout.hq_index >= 0 and layout.destroyed[layout.hq_index] != 0:
		total += 1
	if pct == 100:
		total += 1
	return total


## The result, every key and sub-key in sorted order, so equal battles give equal text:
##   {"abilities_used": {}, "commands": [accepted commands], "deployed": {unit: n},
##    "destruction": int, "stars": int, "ticks": int}
func result() -> Dictionary:
	var names := army.type_names.duplicate()
	names.sort()
	var deployed := {}
	for name: String in names:
		var n := army.deployed[army.type_index(name)]
		if n > 0:
			deployed[name] = n
	return {
		"abilities_used": {},
		"commands": _log.duplicate(true),
		"deployed": deployed,
		"destruction": destruction_pct(),
		"stars": stars(),
		"ticks": tick,
	}


# --- Internals -----------------------------------------------------------------

func _setup(setup: Dictionary) -> String:
	if catalog.battle_seconds <= 0:
		return "the catalog has no battle rules"
	_seed = BattleMath.whole(setup.get("seed", 0))
	if _seed < 0:
		return "the seed must be a whole number"
	rng = SeededRng.new(_seed)
	_total_ticks = catalog.battle_seconds * TICKS_PER_SECOND
	var attacker: Variant = setup.get("attacker", {})
	var defender: Variant = setup.get("defender", {})
	var commands: Variant = setup.get("commands", [])
	if typeof(attacker) != TYPE_DICTIONARY or typeof(defender) != TYPE_DICTIONARY \
			or typeof(commands) != TYPE_ARRAY:
		return "attacker and defender must be objects and commands a list"
	var attacker_dict: Dictionary = attacker
	var defender_dict: Dictionary = defender
	var army_data: Variant = attacker_dict.get("army", {})
	var level_data: Variant = attacker_dict.get("unit_levels", {})
	var buildings: Variant = defender_dict.get("buildings", [])
	if typeof(army_data) != TYPE_DICTIONARY or typeof(level_data) != TYPE_DICTIONARY \
			or typeof(buildings) != TYPE_ARRAY:
		return "the army and unit_levels must be objects and buildings a list"
	layout = BattleLayout.new()
	var error := layout.build(catalog, buildings, catalog.grid_size)
	if error != "":
		return error
	field = BattleField.new(catalog.grid_size)
	field.place_all(layout)
	pathing = BattlePathing.new(field, layout, catalog.wall_cost_units)
	army = BattleArmy.new(layout, field, pathing)
	error = army.setup(catalog, army_data, level_data)
	if error != "":
		return error
	combat = BattleCombat.new(layout, army)
	var last := 0
	for entry: Variant in commands:
		if typeof(entry) != TYPE_DICTIONARY:
			return "a command is not an object"
		var at := BattleMath.whole((entry as Dictionary).get("tick"))
		if at < last:
			return "the commands' ticks must be whole and in order"
		last = at
	_commands = commands
	return ""


## Passes the falls and reveals of the last phase to the field, the pathing and the army.
func _pass_on() -> void:
	while _falls_done < combat.fallen_count:
		var b := combat.fallen[_falls_done]
		_falls_done += 1
		field.remove(layout, b)
		if layout.classes[b] == BattleLayout.TRAP:
			continue
		pathing.building_fell(b)
		army.building_fell(b)
		events.add(BattleEvents.FALL, layout.ids[b], 0, layout.cx[b], layout.cy[b], layout.cx[b],
			layout.cy[b], tick)
	while _reveals_done < combat.revealed_count:
		var b := combat.revealed[_reveals_done]
		_reveals_done += 1
		pathing.building_revealed(b)
		army.building_revealed(b)
