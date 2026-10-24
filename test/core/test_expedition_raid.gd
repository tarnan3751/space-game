extends TestCase
## An expedition's raid (docs/reference/expeditions.md): a field of the sector fought with the
## battle sim and applied through raid_result with its `expedition` key, on the expedition fixture.

const Fixtures := preload("res://test/support/fixtures.gd")

## Easy at Command Center 1: the Command Center, a few buildings, a short ring.
const EASY := 0


func test_a_raid_with_a_star_clears_its_field() -> void:
	var state := _base()
	var command := _fight(state, EASY, _swarm())
	var result: Dictionary = command["result"]
	assert_true(int(result["stars"]) >= 1, "the swarm takes a star: %s" % result)
	assert_eq(state.check_raid_result(command), "")
	assert_eq(state.apply(command, 1000), "")
	assert_true(state.sector.is_cleared(EASY))
	assert_true(state.sector_fields()[EASY]["cleared"])
	assert_eq(state.army_count("melee"), 40 - int(result["deployed"]["melee"]), "the deployed are spent")
	assert_eq(state.check_raid_result(_fight(state, EASY, _swarm())), BaseState.ERR_BAD_EXPEDITION,
		"a cleared field is not fought again this epoch")
	assert_eq(state.apply({"op": "scan"}, 1000), "")
	assert_false(state.sector.is_cleared(EASY), "a scan opens it again")


func test_a_raid_without_a_star_leaves_its_field_open() -> void:
	var state := _base()
	var command := _fight(state, EASY, [{"op": "surrender", "tick": 0}])
	assert_eq(command["result"]["stars"], 0)
	assert_eq(state.apply(command, 1000), "")
	assert_false(state.sector.is_cleared(EASY))
	assert_eq(state.raids.size(), 1, "the raid is kept all the same")


func test_bad_expeditions_are_refused_and_change_nothing() -> void:
	var state := _base()
	state.sector.clear_field(1)
	var good := _fight(state, EASY, [{"op": "surrender", "tick": 0}])
	var moved: Dictionary = good.duplicate(true)
	var first: Dictionary = moved["battle"]["defender"]["buildings"][1]
	first["cell"] = [int(first["cell"][0]) + 1, int(first["cell"][1])]
	var richer: Dictionary = good.duplicate(true)
	richer["battle"]["defender"]["resources"]["metal"] = 1000000
	var reseeded: Dictionary = good.duplicate(true)
	reseeded["battle"]["seed"] = int(good["battle"]["seed"]) + 1
	var cases := {
		"another epoch": _with(good, {"epoch": 1, "index": EASY}),
		"past the last field": _with(good, {"epoch": 0, "index": 6}),
		"a negative index": _with(good, {"epoch": 0, "index": -1}),
		"no index": _with(good, {"epoch": 0}),
		"a cleared field": _with(_fight(state, 1, [{"op": "surrender", "tick": 0}]), {"epoch": 0, "index": 1}),
		"not an object": _with(good, 3),
		"a moved building": moved,
		"more stored": richer,
		"another seed": reseeded,
	}
	for name: String in cases:
		var command: Dictionary = cases[name]
		var before := JSON.stringify(state.to_dict())
		assert_eq(state.check_raid_result(command), BaseState.ERR_BAD_EXPEDITION, name)
		assert_eq(state.apply(command, 1000), BaseState.ERR_BAD_EXPEDITION, name)
		assert_eq(JSON.stringify(state.to_dict()), before, "%s changes nothing" % name)
	assert_eq(state.check_raid_result(good), "", "the good one still applies")


func test_a_command_parsed_from_json_still_matches_its_field() -> void:
	# What a server receives: every number a float.
	var state := _base()
	var command := _fight(state, 2, [{"op": "surrender", "tick": 0}])
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(command))
	assert_eq(state.check_raid_result(parsed), "")


func test_the_log_keeps_the_fields_inputs_not_its_layout() -> void:
	var state := _base()
	var command := _fight(state, 4, [{"op": "surrender", "tick": 0}])
	assert_eq(state.apply(command, 1000), "")
	var raid: Dictionary = state.raids[0]
	var battle: Dictionary = raid["battle"]
	assert_false(battle.has("defender"), "the layout is not kept")
	assert_eq(battle["seed"], command["battle"]["seed"])
	var inputs: Dictionary = raid["expedition"]
	assert_eq(inputs, {"seed": state.sector.sector_seed, "epoch": 0, "index": 4, "cc": 1,
		"capacity": {"metal": 1000, "crystal": 1000, "antimatter": 0}})
	var capacity: Dictionary[String, int] = {}
	for res: Variant in inputs["capacity"]:
		capacity[str(res)] = int(inputs["capacity"][res])
	var again := OutpostGenerator.generate_field(state.catalog, int(inputs["seed"]), int(inputs["epoch"]),
		int(inputs["index"]), int(inputs["cc"]), capacity)
	assert_eq(JSON.stringify(again["defender"]), JSON.stringify(command["battle"]["defender"]),
		"the inputs lay the field out again")
	var json := JSON.stringify(state.to_dict())
	assert_eq(JSON.stringify(BaseState.from_dict(state.catalog, JSON.parse_string(json)).to_dict()), json)


func test_a_raid_without_the_key_keeps_its_defender() -> void:
	var state := _base()
	var command := _fight(state, EASY, [{"op": "surrender", "tick": 0}])
	command.erase("expedition")
	assert_eq(state.apply(command, 1000), "")
	assert_true((state.raids[0]["battle"] as Dictionary).has("defender"))
	assert_false(state.raids[0].has("expedition"))
	assert_eq(state.sector.cleared, PackedInt32Array())


# --- Helpers -------------------------------------------------------------------

## A new expedition-fixture base at time 1000 with an army of 40 melee housed.
func _base() -> BaseState:
	var state := BaseState.create_new(Fixtures.expedition_catalog(), 1000)
	state.army["melee"] = 40
	return state


## Forty melee from the four corners at once.
func _swarm() -> Array:
	var commands := []
	for n: int in 40:
		var corner := n % 4
		commands.append(Fixtures.deploy(0, "melee", 0 if corner % 2 == 0 else 39, 0 if corner < 2 else 39))
	return commands


## Field `index` of the state's sector fought with `commands`, as the raid_result command the game
## layer applies.
func _fight(state: BaseState, index: int, commands: Array) -> Dictionary:
	var field := OutpostGenerator.generate(state.catalog, state, index)
	var setup := OutpostGenerator.battle_setup(field, {"melee": 40}, state.unit_levels)
	setup["commands"] = commands
	var result := BattleSim.run(state.catalog, setup)
	var battle := setup.duplicate(true)
	battle["commands"] = result["commands"]
	var carried := result.duplicate(true)
	carried.erase("commands")
	return {"op": "raid_result", "battle": battle, "result": carried,
		"expedition": {"epoch": state.sector.epoch, "index": index}}


func _with(command: Dictionary, expedition: Variant) -> Dictionary:
	var changed: Dictionary = command.duplicate(true)
	changed["expedition"] = expedition
	return changed
