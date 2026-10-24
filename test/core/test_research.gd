extends TestCase
## Researching unit and ability levels in the research building.

const Fixtures := preload("res://test/support/fixtures.gd")

const CC_ID := 1
const ACADEMY_ID := 4
const LAB_ID := 5
const FOUNDRY_ID := 6


func test_research_needs_a_lab() -> void:
	var state := Fixtures.army_base()
	assert_eq(state.lab_level(), 0)
	assert_eq(state.check_research("grunt"), BaseState.ERR_LAB_LEVEL)
	assert_eq(state.apply(_research("grunt"), 30), BaseState.ERR_LAB_LEVEL)


func test_research_pays_and_raises_the_level() -> void:
	var state := _lab_base()
	var crystal: int = state.resources["crystal"]
	assert_eq(state.apply(_research("grunt"), 160), "")
	assert_eq(state.resources["crystal"], crystal - 100)
	assert_eq(state.research_unit, "grunt")
	assert_eq(state.research_seconds_left(), 60)
	state.advance_to(219)
	assert_eq(state.unit_level("grunt"), 1)
	state.advance_to(220)
	assert_eq(state.unit_level("grunt"), 2)
	assert_eq(state.research_unit, "")
	assert_eq(state.research_seconds_left(), 0)
	state.apply({"op": "train", "id": ACADEMY_ID, "unit": "grunt"}, 220)
	assert_eq(state.resources["crystal"], crystal - 100 - 20, "trains at the new level's price")
	assert_eq(state.check_research("grunt"), BaseState.ERR_MAX_LEVEL)


func test_a_unit_with_one_level_is_at_its_max() -> void:
	var state := _lab_base()
	assert_eq(state.check_research("walker"), BaseState.ERR_MAX_LEVEL)
	assert_eq(state.check_research("ghost"), BaseState.ERR_UNKNOWN_UNIT)
	assert_eq(state.apply(_research("ghost"), 160), BaseState.ERR_UNKNOWN_UNIT)


func test_a_level_needs_its_lab_level() -> void:
	var state := _lab_base()
	assert_eq(state.check_research("flyer"), BaseState.ERR_LAB_LEVEL)
	assert_eq(state.apply({"op": "upgrade", "id": LAB_ID}, 160), "")
	assert_eq(state.check_research("flyer"), BaseState.ERR_LAB_LEVEL, "the level under way does not count")
	state.advance_to(220)
	assert_eq(state.lab_level(), 2)
	assert_eq(state.check_research("flyer"), "")


func test_research_goes_on_while_the_lab_upgrades() -> void:
	var state := _lab_base()
	state.apply(_research("grunt"), 160)
	assert_eq(state.apply({"op": "upgrade", "id": LAB_ID}, 161), "")
	state.advance_to(220)
	assert_eq(state.unit_level("grunt"), 2)
	assert_eq(state.lab_level(), 1, "the lab finishes at 221")


func test_one_research_at_a_time() -> void:
	var state := _lab_base()
	state.apply(_research("grunt"), 160)
	assert_eq(state.check_research("grunt"), BaseState.ERR_BUSY)
	assert_eq(state.apply(_research("grunt"), 170), BaseState.ERR_BUSY)


func test_research_needs_the_unit_unlocked() -> void:
	# A lab but no academy: nothing trains the grunt yet.
	var state := Fixtures.new_base(0)
	state.resources["metal"] = 1000
	state.apply({"op": "upgrade", "id": CC_ID}, 0)
	state.advance_to(100)
	state.apply({"op": "place", "type": "lab", "cell": [5, 5]}, 100)
	state.advance_to(130)
	assert_false(state.is_unit_unlocked("grunt"))
	assert_eq(state.check_research("grunt"), BaseState.ERR_PRODUCER_LEVEL)
	state.apply({"op": "place", "type": "academy", "cell": [9, 9]}, 130)
	assert_true(state.is_unit_unlocked("grunt"))
	assert_eq(state.check_research("grunt"), "")


func test_research_needs_its_price() -> void:
	var state := _lab_base()
	state.resources["crystal"] = 99
	assert_eq(state.check_research("grunt"), BaseState.ERR_FUNDS)
	assert_eq(state.apply(_research("grunt"), 160), BaseState.ERR_FUNDS)
	assert_eq(state.resources["crystal"], 99, "a failed command must not charge")


func test_dev_cheats_research_free_in_one_second() -> void:
	var state := _lab_base()
	state.catalog.apply_dev_cheats()
	state.resources["crystal"] = 0
	assert_eq(state.apply(_research("grunt"), 160), "")
	assert_eq(state.research_seconds_left(), 1)
	state.advance_to(161)
	assert_eq(state.unit_level("grunt"), 2)


func test_research_raises_an_ability_level() -> void:
	var state := _foundry_lab_base()
	var crystal: int = state.resources["crystal"]
	assert_eq(state.check_research_ability("swarm"), "")
	assert_eq(state.apply(_research_ability("swarm"), 160), "")
	assert_eq(state.resources["crystal"], crystal - 100)
	assert_eq(state.research_ability, "swarm")
	assert_eq(state.research_unit, "")
	assert_eq(state.research_seconds_left(), 60)
	state.apply(_make("swarm"), 215)
	state.advance_to(219)
	assert_eq(state.ability_level("swarm"), 1)
	state.advance_to(220)
	assert_eq(state.ability_level("swarm"), 2)
	assert_eq(state.research_ability, "")
	assert_eq(state.research_seconds_left(), 0)
	state.apply(_make("swarm"), 220)
	assert_eq(state.resources["crystal"], crystal - 100 - 10 - 20, "makes at the new level's price")
	state.apply({"op": "cancel_making", "id": FOUNDRY_ID, "ability": "swarm"}, 220)
	assert_eq(state.resources["crystal"], crystal - 100 - 10, "the newest refunds its level 2 price")
	state.apply({"op": "cancel_making", "id": FOUNDRY_ID, "ability": "swarm"}, 220)
	assert_eq(state.resources["crystal"], crystal - 100, "the one queued before refunds level 1's")
	assert_eq(state.check_research_ability("swarm"), BaseState.ERR_MAX_LEVEL)


func test_ability_research_refusals_match_their_checks() -> void:
	var state := _foundry_lab_base()
	var cases := {
		"ghost": BaseState.ERR_UNKNOWN_ABILITY,
		"burst": BaseState.ERR_MAX_LEVEL,
		"strike": BaseState.ERR_FOUNDRY_LEVEL,
	}
	for ability: String in cases:
		assert_eq(state.check_research_ability(ability), cases[ability], ability)
		assert_eq(state.apply(_research_ability(ability), 160), cases[ability], ability)
	assert_eq(state.apply({"op": "upgrade", "id": FOUNDRY_ID}, 160), "")
	state.advance_to(170)
	assert_true(state.is_ability_unlocked("strike"))
	assert_eq(state.check_research_ability("strike"), BaseState.ERR_LAB_LEVEL, "its level 2 needs lab 2")
	state.resources["crystal"] = 99
	assert_eq(state.check_research_ability("swarm"), BaseState.ERR_FUNDS)
	assert_eq(state.apply(_research_ability("swarm"), 170), BaseState.ERR_FUNDS)
	assert_eq(state.resources["crystal"], 99, "a failed command must not charge")


func test_ability_research_needs_a_foundry() -> void:
	var state := _lab_base()
	assert_false(state.is_ability_unlocked("swarm"))
	assert_eq(state.check_research_ability("swarm"), BaseState.ERR_FOUNDRY_LEVEL)


func test_units_and_abilities_share_one_research() -> void:
	var state := _foundry_lab_base()
	state.apply(_research("grunt"), 160)
	assert_eq(state.check_research_ability("swarm"), BaseState.ERR_BUSY)
	assert_eq(state.apply(_research_ability("swarm"), 160), BaseState.ERR_BUSY)
	state.advance_to(220)
	assert_eq(state.apply(_research_ability("swarm"), 220), "")
	assert_eq(state.check_research("flyer"), BaseState.ERR_LAB_LEVEL)
	assert_eq(state.check_research("grunt"), BaseState.ERR_MAX_LEVEL)
	state.unit_levels["grunt"] = 1
	assert_eq(state.check_research("grunt"), BaseState.ERR_BUSY, "an ability research holds the slot")


func test_dev_cheats_research_an_ability_free_in_one_second() -> void:
	var state := _foundry_lab_base()
	state.catalog.apply_dev_cheats()
	state.resources["crystal"] = 0
	assert_eq(state.apply(_research_ability("swarm"), 160), "")
	assert_eq(state.research_seconds_left(), 1)
	state.advance_to(161)
	assert_eq(state.ability_level("swarm"), 2)


func test_ticks_of_one_second_equal_one_big_tick() -> void:
	assert_eq(_snapshot(_scripted(1)), _snapshot(_scripted(1000)))


## Research, training and a lab upgrade finishing in the same second, with the clock advanced
## every `step` seconds between the commands.
func _scripted(step: int) -> BaseState:
	var state := _lab_base()
	var commands := {
		# The lab upgrade, the research and the sixth grunt all finish at 220.
		160: [_research("grunt"), {"op": "train", "id": ACADEMY_ID, "unit": "grunt", "count": 6},
			{"op": "upgrade", "id": LAB_ID}],
		220: [_research("flyer")],
	}
	for t: int in range(160, 500):
		if commands.has(t):
			var list: Array = commands[t]
			for command: Dictionary in list:
				assert_eq(state.apply(command, t), "", "%s at %d" % [command, t])
		elif (t - 160) % step == 0:
			state.advance_to(t)
	state.advance_to(500)
	assert_eq(state.unit_level("flyer"), 2)
	return state


func _snapshot(state: BaseState) -> String:
	return JSON.stringify({"save": state.to_dict(), "army": state.army, "levels": state.unit_levels,
		"research": [state.research_unit, state.research_done_at]})


## The army base with Command Center 2 and a finished lab (id 5, at (5, 5)), at time 160 with
## 400 metal and 500 crystal.
static func _lab_base() -> BaseState:
	var state := Fixtures.army_base()
	state.resources["metal"] = 900
	state.apply({"op": "upgrade", "id": CC_ID}, 30)
	state.advance_to(130)
	state.apply({"op": "place", "type": "lab", "cell": [5, 5]}, 130)
	state.advance_to(160)
	return state


## The lab base with a foundry (id 6, at (8, 5), level 1).
func _foundry_lab_base() -> BaseState:
	var state := _lab_base()
	state.apply({"op": "place", "type": "foundry", "cell": [8, 5]}, 160)
	assert_eq(state.last_added_id, FOUNDRY_ID)
	return state


static func _research_ability(ability: String) -> Dictionary:
	return {"op": "research", "ability": ability}


static func _make(ability: String) -> Dictionary:
	return {"op": "make", "id": FOUNDRY_ID, "ability": ability}


static func _research(unit: String) -> Dictionary:
	return {"op": "research", "unit": unit}
