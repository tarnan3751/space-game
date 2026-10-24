extends TestCase
## Making abilities in the Foundry and keeping them in the stock.

const Fixtures := preload("res://test/support/fixtures.gd")

const CC_ID := 1
const ACADEMY_ID := 4
const FOUNDRY_ID := 5


func test_make_pays_and_queues() -> void:
	var state := Fixtures.foundry_base()
	assert_eq(state.foundry_capacity(), 2)
	assert_eq(state.apply(_make("swarm", 2), 30), "")
	assert_eq(state.resources["crystal"], 480)
	assert_eq(state.making_queue_of(FOUNDRY_ID), PackedStringArray(["swarm", "swarm"]))
	assert_eq(state.making_status(FOUNDRY_ID), BaseState.TRAINING_RUNNING)
	assert_eq(state.making_seconds_left(FOUNDRY_ID), 10)
	assert_eq(state.making_queued(), 2)
	assert_eq(state.stock_total(), 0, "abilities being made are not in the stock")


func test_abilities_are_made_one_after_another() -> void:
	var state := Fixtures.foundry_base()
	state.apply(_make("swarm"), 30)
	state.apply(_make("burst"), 30)
	var signals: Array[int] = [0]
	state.changed.connect(func() -> void: signals[0] += 1)
	state.advance_to(39)
	assert_eq(state.stock("swarm"), 0)
	state.advance_to(40)
	assert_eq(state.stock("swarm"), 1)
	assert_eq(signals[0], 1, "a finished ability emits changed")
	assert_eq(state.making_seconds_left(FOUNDRY_ID), 20, "the next starts at once")
	state.advance_to(59)
	assert_eq(state.stock("burst"), 0)
	state.advance_to(60)
	assert_eq(state.stock("burst"), 1)
	assert_eq(state.stock_total(), 2)
	assert_eq(state.making_status(FOUNDRY_ID), BaseState.TRAINING_IDLE)
	assert_eq(state.making_queued(), 0)
	assert_eq(state.stock("ghost"), 0)


func test_the_queue_limit_counts_the_stock_and_every_queue() -> void:
	var state := Fixtures.foundry_base()
	assert_eq(state.apply(_make("swarm"), 30), "")
	state.advance_to(40)
	assert_eq(state.apply(_make("burst"), 40), "")
	assert_eq(state.check_make(FOUNDRY_ID, "swarm"), BaseState.ERR_STOCK_ROOM, "one stocked, one queued")
	assert_eq(state.apply(_make("swarm"), 40), BaseState.ERR_STOCK_ROOM)
	assert_eq(state.resources["crystal"], 470, "a failed command must not charge")


func test_a_huge_count_is_refused_before_it_is_multiplied() -> void:
	var state := Fixtures.foundry_base()
	var huge := 1 << 61
	assert_eq(state.check_make(FOUNDRY_ID, "swarm", huge), BaseState.ERR_STOCK_ROOM)
	assert_eq(state.apply(_make("swarm", huge), 30), BaseState.ERR_STOCK_ROOM)
	assert_eq(state.resources["crystal"], 500)


func test_make_refusals_match_their_checks() -> void:
	var state := Fixtures.foundry_base()
	var cases := [
		[FOUNDRY_ID, "ghost", 1, BaseState.ERR_UNKNOWN_ABILITY],
		[99, "swarm", 1, BaseState.ERR_UNKNOWN_BUILDING],
		[ACADEMY_ID, "swarm", 1, BaseState.ERR_NOT_FOUNDRY],
		[FOUNDRY_ID, "swarm", 0, BaseState.ERR_BAD_COUNT],
		[FOUNDRY_ID, "strike", 1, BaseState.ERR_FOUNDRY_LEVEL],
		[FOUNDRY_ID, "swarm", 3, BaseState.ERR_STOCK_ROOM],
	]
	for entry: Array in cases:
		var id: int = entry[0]
		var ability: String = entry[1]
		var count: int = entry[2]
		var expected: String = entry[3]
		assert_eq(state.check_make(id, ability, count), expected, "check %s" % expected)
		assert_eq(state.apply({"op": "make", "id": id, "ability": ability, "count": count}, 30), expected,
			"apply %s" % expected)
	state.resources["crystal"] = 15
	assert_eq(state.check_make(FOUNDRY_ID, "swarm", 2), BaseState.ERR_FUNDS)
	assert_eq(state.apply(_make("swarm", 2), 30), BaseState.ERR_FUNDS)
	assert_eq(state.resources["crystal"], 15, "all or nothing")
	assert_eq(state.apply(_make("swarm"), 30), "")
	assert_eq(state.resources["crystal"], 5)


func test_nothing_is_made_without_a_foundry() -> void:
	var state := Fixtures.army_base()
	assert_eq(state.foundry_capacity(), 0)
	assert_eq(state.check_make(FOUNDRY_ID, "swarm"), BaseState.ERR_UNKNOWN_BUILDING)
	assert_false(state.is_ability_unlocked("swarm"))


func test_making_queue_of_hands_out_a_copy() -> void:
	var state := Fixtures.foundry_base()
	state.apply(_make("swarm"), 30)
	var queue := state.making_queue_of(FOUNDRY_ID)
	queue.append("burst")
	assert_eq(state.making_queue_of(FOUNDRY_ID), PackedStringArray(["swarm"]))
	assert_eq(state.making_queue_of(99), PackedStringArray())


func test_an_upgrading_foundry_pauses_and_resumes() -> void:
	var state := Fixtures.foundry_base()
	state.apply(_make("swarm"), 30)
	assert_eq(state.apply({"op": "upgrade", "id": FOUNDRY_ID}, 35), "")
	assert_eq(state.making_status(FOUNDRY_ID), BaseState.TRAINING_PAUSED)
	assert_eq(state.making_seconds_left(FOUNDRY_ID), 5)
	assert_eq(state.foundry_capacity(), 2, "the old level's capacity while it upgrades")
	state.advance_to(44)
	assert_eq(state.making_seconds_left(FOUNDRY_ID), 5, "the clock is stopped")
	state.advance_to(45)
	assert_eq(state.foundry_capacity(), 3)
	assert_eq(state.making_status(FOUNDRY_ID), BaseState.TRAINING_RUNNING)
	state.advance_to(49)
	assert_eq(state.stock("swarm"), 0)
	state.advance_to(50)
	assert_eq(state.stock("swarm"), 1)
	assert_eq(state.check_make(FOUNDRY_ID, "strike"), "", "the strike needs foundry level 2")


func test_a_made_ability_waits_for_room() -> void:
	# A save holding a full stock and a queue (a data change lowered the capacity): the head is
	# made, waits, and is stocked the moment the Foundry's upgrade raises the capacity.
	var data := Fixtures.foundry_base().to_dict()
	data["abilities"] = {"stock": {"swarm": 2}, "levels": {},
		"making": [{"building": FOUNDRY_ID, "units": ["burst"], "paid_levels": [1], "done_at": 50, "left": 0}]}
	var state := BaseState.from_dict(Fixtures.catalog(), data)
	assert_eq(state.making_status(FOUNDRY_ID), BaseState.TRAINING_RUNNING)
	state.advance_to(50)
	assert_eq(state.stock("burst"), 0)
	assert_eq(state.making_status(FOUNDRY_ID), BaseState.TRAINING_WAITING)
	assert_eq(state.making_seconds_left(FOUNDRY_ID), 0)
	assert_eq(state.apply({"op": "upgrade", "id": FOUNDRY_ID}, 50), "")
	assert_eq(state.making_status(FOUNDRY_ID), BaseState.TRAINING_WAITING, "waits, busy Foundry or not")
	state.advance_to(60)
	assert_eq(state.stock("burst"), 1, "stocked when the upgrade completes")
	assert_eq(state.making_status(FOUNDRY_ID), BaseState.TRAINING_IDLE)


func test_cancel_refunds_the_level_paid() -> void:
	var state := Fixtures.foundry_base()
	state.apply(_make("swarm"), 30)
	state.ability_levels["swarm"] = 2
	state.apply(_make("swarm"), 30)
	assert_eq(state.resources["crystal"], 470)
	assert_eq(state.apply(_cancel("swarm"), 31), "")
	assert_eq(state.resources["crystal"], 490, "the newest, paid at level 2")
	assert_eq(state.making_queue_of(FOUNDRY_ID).size(), 1)
	assert_eq(state.apply(_cancel("swarm"), 32), "")
	assert_eq(state.resources["crystal"], 500)
	assert_eq(state.making_status(FOUNDRY_ID), BaseState.TRAINING_IDLE)
	state.advance_to(100)
	assert_eq(state.stock("swarm"), 0)


func test_cancelling_the_head_starts_the_next_afresh() -> void:
	var state := Fixtures.foundry_base()
	state.apply(_make("swarm"), 30)
	state.apply(_make("burst"), 30)
	state.apply(_cancel("swarm"), 35)
	assert_eq(state.making_queue_of(FOUNDRY_ID), PackedStringArray(["burst"]))
	assert_eq(state.making_seconds_left(FOUNDRY_ID), 20)
	state.advance_to(54)
	assert_eq(state.stock("burst"), 0)
	state.advance_to(55)
	assert_eq(state.stock("burst"), 1)


func test_a_refund_stops_at_storage() -> void:
	var state := Fixtures.foundry_base()
	state.apply(_make("swarm"), 30)
	state.resources["crystal"] = 995
	state.apply(_cancel("swarm"), 30)
	assert_eq(state.resources["crystal"], 1000)


func test_cancel_refusals_match_their_checks() -> void:
	var state := Fixtures.foundry_base()
	assert_eq(state.check_cancel_making(99, "swarm"), BaseState.ERR_UNKNOWN_BUILDING)
	assert_eq(state.apply({"op": "cancel_making", "id": 99, "ability": "swarm"}, 30),
		BaseState.ERR_UNKNOWN_BUILDING)
	assert_eq(state.check_cancel_making(FOUNDRY_ID, "swarm"), BaseState.ERR_NOT_QUEUED)
	state.apply(_make("swarm"), 30)
	assert_eq(state.check_cancel_making(FOUNDRY_ID, "burst"), BaseState.ERR_NOT_QUEUED)
	assert_eq(state.apply(_cancel("burst"), 30), BaseState.ERR_NOT_QUEUED)
	assert_eq(state.resources["crystal"], 490)


func test_dev_cheats_make_free_in_one_second() -> void:
	var state := Fixtures.foundry_base()
	state.catalog.apply_dev_cheats()
	state.resources["crystal"] = 0
	assert_eq(state.apply(_make("burst"), 30), "")
	assert_eq(state.making_seconds_left(FOUNDRY_ID), 1)
	state.advance_to(31)
	assert_eq(state.stock("burst"), 1)


func test_the_same_commands_give_the_same_state() -> void:
	assert_eq(_snapshot(_scripted(1000)), _snapshot(_scripted(1000)))


func test_ticks_of_one_second_equal_one_big_tick() -> void:
	assert_eq(_snapshot(_scripted(1)), _snapshot(_scripted(1000)))


## Making and training side by side, a cancel, and a Foundry upgrade finishing the second a head
## is made, with the clock advanced every `step` seconds between the commands.
func _scripted(step: int) -> BaseState:
	var state := Fixtures.foundry_base()
	state.resources["metal"] = 1000
	var commands := {
		30: [_make("swarm", 2), {"op": "train", "id": ACADEMY_ID, "unit": "grunt", "count": 3}],
		# The swarm left 10 s at 35 resumes at 45 and is made at 50, the second the grunts end.
		35: [{"op": "upgrade", "id": FOUNDRY_ID}],
		52: [_cancel("swarm"), _make("burst")],
		60: [_make("strike")],
	}
	for t: int in range(30, 300):
		if commands.has(t):
			var list: Array = commands[t]
			for command: Dictionary in list:
				assert_eq(state.apply(command, t), "", "%s at %d" % [command, t])
		elif (t - 30) % step == 0:
			state.advance_to(t)
	state.advance_to(300)
	assert_eq(state.stock("strike"), 1)
	return state


func _snapshot(state: BaseState) -> String:
	return JSON.stringify({"save": state.to_dict(), "stock": state.ability_stock,
		"status": [state.making_status(FOUNDRY_ID), state.making_seconds_left(FOUNDRY_ID)]})


static func _make(ability: String, count: int = 1) -> Dictionary:
	return {"op": "make", "id": FOUNDRY_ID, "ability": ability, "count": count}


static func _cancel(ability: String) -> Dictionary:
	return {"op": "cancel_making", "id": FOUNDRY_ID, "ability": ability}
