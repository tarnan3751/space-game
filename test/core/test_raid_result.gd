extends TestCase
## Applying a battle's result to the attacker's base: units spent, loot home, the battle kept.

const Fixtures := preload("res://test/support/fixtures.gd")


func test_a_battle_result_applies() -> void:
	var state := _base()
	var setup := Fixtures.battle_setup([["command_center", 10, 10], ["silo", 15, 15]], {"melee": 6}, [
		Fixtures.deploy(0, "melee", 0, 0), Fixtures.deploy(0, "melee", 0, 0), Fixtures.deploy(0, "melee", 19, 19),
		Fixtures.deploy(0, "melee", 19, 19)], {"metal": 2000, "crystal": 400, "antimatter": 0})
	var result := BattleSim.run(state.catalog, setup)
	assert_eq(result["deployed"], {"melee": 4})
	assert_true(int(result["loot"]["metal"]) > 0, "the battle took something: %s" % result["loot"])
	var command := _command_from(setup, result)
	assert_eq(state.check_raid_result(command), "")
	var metal_before: int = state.resources["metal"]
	assert_eq(state.apply(command, 40), "")
	assert_eq(state.army_count("melee"), 2, "the four deployed are spent")
	assert_eq(state.army_count("grunt"), 2, "the rest come home")
	assert_eq(state.resources["metal"], mini(state.capacity("metal"), metal_before + int(result["loot"]["metal"])))
	assert_eq(state.raids.size(), 1)
	assert_eq(state.raids[0]["at"], 40)
	assert_eq(state.raids[0]["battle"]["commands"], result["commands"])
	assert_eq(state.raids[0]["result"]["hash"], result["hash"])


func test_loot_is_capped_by_storage() -> void:
	var state := _base()
	state.resources["metal"] = 900
	assert_eq(state.apply(_raid({}, {"metal": 500, "crystal": 0}), 40), "")
	assert_eq(state.resources["metal"], 1000, "the Command Center stores 1000")
	state.resources["crystal"] = 1500
	assert_eq(state.apply(_raid({}, {"crystal": 10}), 40), "")
	assert_eq(state.resources["crystal"], 1500, "never removing what is there")


func test_refusals_match_their_checks_and_change_nothing() -> void:
	var cases := {
		"no battle": [{"op": "raid_result", "result": _raid({}, {})["result"]}, BaseState.ERR_BAD_RAID],
		"no result": [{"op": "raid_result", "battle": _raid({}, {})["battle"]}, BaseState.ERR_BAD_RAID],
		"destruction": [_raid({}, {}, [], {"destruction": 101}), BaseState.ERR_BAD_RAID],
		"stars": [_raid({}, {}, [], {"stars": 4}), BaseState.ERR_BAD_RAID],
		"ticks": [_raid({}, {}, [], {"ticks": -1}), BaseState.ERR_BAD_RAID],
		"loot resource": [_raid({}, {"gold": 5}), BaseState.ERR_BAD_RAID],
		"loot amount": [_raid({}, {"metal": 2.5}), BaseState.ERR_BAD_RAID],
		"deployed without commands": [_raid({"melee": 1}, {}, []), BaseState.ERR_BAD_RAID],
		"commands without deployed": [_raid({}, {}, [Fixtures.deploy(0, "melee", 0, 0)]), BaseState.ERR_BAD_RAID],
		"unknown unit": [_raid({"ghost": 1}, {}, [Fixtures.deploy(0, "ghost", 0, 0)]), BaseState.ERR_UNKNOWN_UNIT],
		"too many": [_raid({"grunt": 3}, {}, [Fixtures.deploy(0, "grunt", 0, 0), Fixtures.deploy(0, "grunt", 0, 0),
			Fixtures.deploy(0, "grunt", 0, 0)]), BaseState.ERR_NOT_ENOUGH_UNITS],
		"an ability": [_raid({}, {}, [], {"abilities_used": {"orbital_strike": 1}}), BaseState.ERR_UNKNOWN_ABILITY],
		"an ability at zero": [_raid({}, {}, [], {"abilities_used": {"orbital_strike": 0}}), BaseState.ERR_UNKNOWN_ABILITY],
	}
	for name: String in cases:
		var state := _base()
		var before := JSON.stringify(state.to_dict())
		var command: Dictionary = cases[name][0]
		var expected: String = cases[name][1]
		assert_eq(state.check_raid_result(command), expected, "check: %s" % name)
		assert_eq(state.apply(command, 30), expected, "apply: %s" % name)
		assert_eq(JSON.stringify(state.to_dict()), before, "%s changes nothing" % name)


func test_a_waiting_unit_is_housed_in_the_room_a_raid_frees() -> void:
	var state := _base()
	state.army["melee"] = 17
	state.apply({"op": "train", "id": 4, "unit": "grunt"}, 30)
	state.army["melee"] = 18
	state.advance_to(50)
	assert_eq(state.training_status(4), BaseState.TRAINING_WAITING, "20 housed, the grunt waits")
	var commands := []
	for i: int in 3:
		commands.append(Fixtures.deploy(0, "melee", 0, 0))
	assert_eq(state.apply(_raid({"melee": 3}, {}, commands), 50), "")
	assert_eq(state.army_count("melee"), 15)
	assert_eq(state.army_count("grunt"), 3, "housed at once")
	assert_eq(state.training_status(4), BaseState.TRAINING_IDLE)


func test_the_last_five_raids_are_kept() -> void:
	var state := _base()
	for i: int in 7:
		assert_eq(state.apply(_raid({}, {}, [], {"ticks": i}), 30 + i), "")
	assert_eq(state.raids.size(), BaseState.RAID_LOG_SIZE)
	assert_eq(state.raids[0]["result"]["ticks"], 2, "the oldest dropped")
	assert_eq(state.raids[4]["at"], 36, "newest last")


func test_raids_survive_a_save_round_trip() -> void:
	var state := _base()
	state.apply(_raid({"melee": 1}, {"metal": 10}, [Fixtures.deploy(0, "melee", 0, 0)]), 30)
	var json := JSON.stringify(state.to_dict())
	var restored := BaseState.from_dict(state.catalog, JSON.parse_string(json))
	assert_eq(JSON.stringify(restored.to_dict()), json, "canonical: the numbers come back as ints")
	assert_eq(restored.raids.size(), 1)
	assert_eq(restored.raids[0]["result"]["deployed"]["melee"], 1)


func test_a_version_3_save_loads_with_no_raids() -> void:
	var data := _base().to_dict()
	data["version"] = 3
	data.erase("raids")
	var state := BaseState.from_dict(Fixtures.battle_catalog(), data)
	assert_eq(state.raids, [] as Array[Dictionary])
	var saved := state.to_dict()
	assert_eq(saved["version"], 4)
	assert_eq(saved["raids"], [])


## The battle fixture base: the Command Center and drone bay, a finished hangar (id 3, housing 20)
## and an academy (id 4), at time 30, with six melee and two grunts housed.
func _base() -> BaseState:
	var state := BaseState.create_new(Fixtures.battle_catalog(), 0)
	state.apply({"op": "place", "type": "hangar", "cell": [0, 3]}, 0)
	state.advance_to(30)
	state.apply({"op": "place", "type": "academy", "cell": [9, 9]}, 30)
	state.army["melee"] = 6
	state.army["grunt"] = 2
	return state


func _raid(deployed: Dictionary, loot: Dictionary, commands: Array = [], overrides: Dictionary = {}) -> Dictionary:
	var result := {"abilities_used": {}, "deployed": deployed, "destruction": 0, "hash": 7, "loot": loot,
		"stars": 0, "ticks": 100}
	result.merge(overrides, true)
	var battle := Fixtures.battle_setup([["command_center", 10, 10]], {"melee": 6, "grunt": 2}, commands)
	return {"op": "raid_result", "battle": battle, "result": result}


func _command_from(setup: Dictionary, result: Dictionary) -> Dictionary:
	var battle := setup.duplicate(true)
	battle["commands"] = result["commands"]
	var carried := result.duplicate(true)
	carried.erase("commands")
	return {"op": "raid_result", "battle": battle, "result": carried}
