extends TestCase
## Training units in the producer buildings and housing them in the Hangars.

const Fixtures := preload("res://test/support/fixtures.gd")

const CC_ID := 1
const HANGAR_ID := 3
const ACADEMY_ID := 4


func test_train_pays_and_queues() -> void:
	var state := Fixtures.army_base()
	assert_eq(state.apply(_train("grunt", 3), 30), "")
	assert_eq(state.resources["crystal"], 470)
	assert_eq(state.queue_of(ACADEMY_ID), PackedStringArray(["grunt", "grunt", "grunt"]))
	assert_eq(state.training_status(ACADEMY_ID), BaseState.TRAINING_RUNNING)
	assert_eq(state.training_seconds_left(ACADEMY_ID), 10)
	assert_eq(state.housing_queued(), 3)
	assert_eq(state.housing_used(), 0, "units in training are not housed")


func test_units_complete_one_after_another() -> void:
	var state := Fixtures.army_base()
	state.apply(_train("grunt", 3), 30)
	var signals: Array[int] = [0]
	state.changed.connect(func() -> void: signals[0] += 1)
	state.advance_to(39)
	assert_eq(state.army_count("grunt"), 0)
	state.advance_to(40)
	assert_eq(state.army_count("grunt"), 1)
	assert_eq(signals[0], 1, "a finished unit emits changed")
	assert_eq(state.training_seconds_left(ACADEMY_ID), 10, "the next starts at once")
	state.advance_to(60)
	assert_eq(state.army_count("grunt"), 3)
	assert_eq(state.training_status(ACADEMY_ID), BaseState.TRAINING_IDLE)
	assert_eq(state.housing_used(), 3)
	assert_eq(state.housing_queued(), 0)


func test_queue_trains_in_order() -> void:
	var state := Fixtures.army_base()
	state.apply(_train("flyer"), 30)
	state.apply(_train("grunt"), 30)
	state.advance_to(49)
	assert_eq(state.army_count("flyer"), 0)
	state.advance_to(50)
	assert_eq(state.army_count("flyer"), 1)
	assert_eq(state.army_count("grunt"), 0)
	state.advance_to(60)
	assert_eq(state.army_count("grunt"), 1)
	assert_eq(state.housing_used(), 3)


func test_a_count_is_all_or_nothing() -> void:
	var state := Fixtures.army_base()
	state.resources["crystal"] = 25
	assert_eq(state.apply(_train("grunt", 3), 30), BaseState.ERR_FUNDS)
	assert_eq(state.resources["crystal"], 25, "a failed command must not charge")
	assert_eq(state.queue_of(ACADEMY_ID), PackedStringArray())
	assert_eq(state.apply(_train("grunt", 2), 30), "")
	assert_eq(state.resources["crystal"], 5)


func test_train_refusals_match_their_checks() -> void:
	var state := Fixtures.army_base()
	var cases := [
		[ACADEMY_ID, "ghost", 1, BaseState.ERR_UNKNOWN_UNIT],
		[99, "grunt", 1, BaseState.ERR_UNKNOWN_BUILDING],
		[HANGAR_ID, "grunt", 1, BaseState.ERR_NOT_PRODUCER],
		[ACADEMY_ID, "grunt", 0, BaseState.ERR_BAD_COUNT],
		[ACADEMY_ID, "walker", 1, BaseState.ERR_PRODUCER_LEVEL],
		[ACADEMY_ID, "grunt", 21, BaseState.ERR_HOUSING],
	]
	for entry: Array in cases:
		var id: int = entry[0]
		var unit: String = entry[1]
		var count: int = entry[2]
		var expected: String = entry[3]
		assert_eq(state.check_train(id, unit, count), expected, "check %s" % expected)
		assert_eq(state.apply({"op": "train", "id": id, "unit": unit, "count": count}, 30), expected,
			"apply %s" % expected)
	state.resources["crystal"] = 5
	assert_eq(state.check_train(ACADEMY_ID, "grunt"), BaseState.ERR_FUNDS)
	assert_eq(state.apply(_train("grunt"), 30), BaseState.ERR_FUNDS)
	assert_eq(state.housing_queued(), 0)


func test_a_huge_count_is_refused_before_it_is_multiplied() -> void:
	var state := Fixtures.army_base()
	for count: int in [1 << 62, (1 << 62) + 1]:
		assert_eq(state.check_train(ACADEMY_ID, "flyer", count), BaseState.ERR_HOUSING, "check %d" % count)
		assert_eq(state.apply({"op": "train", "id": ACADEMY_ID, "unit": "flyer", "count": count}, 30),
			BaseState.ERR_HOUSING, "apply %d" % count)
	assert_eq(state.resources["crystal"], 500, "nothing was paid")
	assert_eq(state.queue_of(ACADEMY_ID), PackedStringArray(), "nothing was queued")


func test_queue_of_hands_out_a_copy() -> void:
	var state := Fixtures.army_base()
	state.apply(_train("grunt"), 30)
	var copy := state.queue_of(ACADEMY_ID)
	copy.append("walker")
	assert_eq(state.queue_of(ACADEMY_ID), PackedStringArray(["grunt"]))
	assert_eq(state.training[ACADEMY_ID].paid_levels.size(), 1)


func test_nothing_trains_without_a_hangar() -> void:
	var state := Fixtures.new_base()
	state.apply({"op": "place", "type": "academy", "cell": [9, 9]}, 0)
	assert_eq(state.housing_capacity(), 0)
	assert_eq(state.check_train(3, "grunt"), BaseState.ERR_HOUSING)


func test_a_producer_under_construction_trains_nothing() -> void:
	var state := Fixtures.army_base()
	state.apply({"op": "upgrade", "id": ACADEMY_ID}, 30)
	assert_eq(state.check_train(ACADEMY_ID, "walker"), BaseState.ERR_PRODUCER_LEVEL,
		"the level under construction does not count yet")
	state.advance_to(40)
	assert_eq(state.check_train(ACADEMY_ID, "walker"), "")


func test_the_queue_limit_counts_the_army_and_every_queue() -> void:
	var state := Fixtures.army_base()
	assert_eq(state.apply(_train("grunt", 15), 30), "")
	state.advance_to(130)
	assert_eq(state.army_count("grunt"), 10)
	assert_eq(state.housing_queued(), 5)
	assert_eq(state.check_train(ACADEMY_ID, "grunt", 6), BaseState.ERR_HOUSING)
	assert_eq(state.check_train(ACADEMY_ID, "grunt", 5), "")
	assert_eq(state.check_train(ACADEMY_ID, "walker"), BaseState.ERR_PRODUCER_LEVEL)


func test_two_producers_train_side_by_side() -> void:
	var state := Fixtures.army_base()
	state.apply({"op": "place", "type": "academy", "cell": [8, 9]}, 30)
	var second := state.last_added_id
	state.apply(_train("grunt", 2), 30)
	state.apply({"op": "train", "id": second, "unit": "grunt", "count": 2}, 30)
	state.advance_to(40)
	assert_eq(state.army_count("grunt"), 2)
	state.advance_to(50)
	assert_eq(state.army_count("grunt"), 4)


func test_an_upgrading_producer_pauses_and_resumes() -> void:
	var state := Fixtures.army_base()
	state.apply(_train("grunt", 2), 30)
	assert_eq(state.apply({"op": "upgrade", "id": ACADEMY_ID}, 34), "")
	assert_eq(state.training_status(ACADEMY_ID), BaseState.TRAINING_PAUSED)
	assert_eq(state.training_seconds_left(ACADEMY_ID), 6)
	state.advance_to(43)
	assert_eq(state.training_seconds_left(ACADEMY_ID), 6, "no time passes while paused")
	assert_eq(state.apply(_train("grunt"), 43), "", "a busy producer still queues")
	state.advance_to(44)
	assert_eq(state.training_status(ACADEMY_ID), BaseState.TRAINING_RUNNING)
	state.advance_to(49)
	assert_eq(state.army_count("grunt"), 0)
	state.advance_to(50)
	assert_eq(state.army_count("grunt"), 1)
	state.advance_to(70)
	assert_eq(state.army_count("grunt"), 3)


func test_a_full_army_waits_until_a_hangar_finishes() -> void:
	# More army than housing (a save after a data change) is kept; the next unit waits.
	var state := Fixtures.army_base()
	state.resources["metal"] = 1000
	state.apply(_train("grunt", 2), 30)
	state.army["grunt"] = 19
	state.advance_to(50)
	assert_eq(state.army_count("grunt"), 20)
	assert_eq(state.training_status(ACADEMY_ID), BaseState.TRAINING_WAITING)
	assert_eq(state.training_seconds_left(ACADEMY_ID), 0)
	assert_eq(state.check_train(ACADEMY_ID, "grunt"), BaseState.ERR_HOUSING)
	state.apply({"op": "upgrade", "id": CC_ID}, 50)
	state.advance_to(150)
	assert_eq(state.apply({"op": "upgrade", "id": HANGAR_ID}, 150), "")
	assert_eq(state.housing_capacity(), 20, "a hangar being upgraded keeps its housing")
	state.advance_to(209)
	assert_eq(state.army_count("grunt"), 20)
	state.advance_to(210)
	assert_eq(state.housing_capacity(), 30)
	assert_eq(state.army_count("grunt"), 21, "housed the moment the hangar finishes")
	assert_eq(state.training_status(ACADEMY_ID), BaseState.TRAINING_IDLE)


func test_a_finished_unit_is_housed_while_its_producer_upgrades() -> void:
	# Busy only stops the clock: a head that has trained is housed when a hangar makes room,
	# and the one behind it waits for the upgrade with its full time.
	var state := Fixtures.army_base()
	state.resources["metal"] = 1000
	state.apply({"op": "place", "type": "drone_bay", "cell": [9, 0]}, 30)
	state.apply({"op": "upgrade", "id": CC_ID}, 30)
	state.advance_to(130)
	state.apply({"op": "upgrade", "id": HANGAR_ID}, 130)
	state.apply(_train("grunt", 3), 130)
	state.army["grunt"] = 19
	state.advance_to(150)
	assert_eq(state.army_count("grunt"), 20)
	assert_eq(state.training_status(ACADEMY_ID), BaseState.TRAINING_WAITING)
	assert_eq(state.apply({"op": "upgrade", "id": ACADEMY_ID}, 185), "")
	assert_eq(state.training_status(ACADEMY_ID), BaseState.TRAINING_WAITING,
		"a finished head waits for room, not for the producer")
	state.advance_to(190)
	assert_eq(state.army_count("grunt"), 21, "housed when the hangar finishes")
	assert_eq(state.training_status(ACADEMY_ID), BaseState.TRAINING_PAUSED)
	assert_eq(state.training_seconds_left(ACADEMY_ID), 10)
	state.advance_to(204)
	assert_eq(state.army_count("grunt"), 21)
	state.advance_to(205)
	assert_eq(state.army_count("grunt"), 22, "the next trains once the upgrade is done at 195")


func test_the_lowest_id_that_fits_is_housed_first() -> void:
	# One housing free: the flyer (2) at the lower id does not fit, the grunt (1) does.
	var state := Fixtures.army_base()
	state.apply({"op": "place", "type": "academy", "cell": [8, 9]}, 30)
	var second := state.last_added_id
	state.apply(_train("flyer"), 30)
	state.apply({"op": "train", "id": second, "unit": "grunt"}, 30)
	state.army["grunt"] = 20
	state.advance_to(50)
	assert_eq(state.training_status(ACADEMY_ID), BaseState.TRAINING_WAITING)
	assert_eq(state.training_status(second), BaseState.TRAINING_WAITING)
	state.army["grunt"] = 19
	assert_eq(state.apply({"op": "place", "type": "wall", "cell": [9, 5]}, 50), "", "any command")
	assert_eq(state.army_count("grunt"), 20)
	assert_eq(state.training_status(second), BaseState.TRAINING_IDLE)
	assert_eq(state.training_status(ACADEMY_ID), BaseState.TRAINING_WAITING)
	assert_eq(state.army_count("flyer"), 0)


func test_a_unit_finishing_with_a_hangar_is_housed() -> void:
	# The hangar and the unit finish in the same second: buildings complete first.
	var state := Fixtures.army_base()
	state.resources["metal"] = 1000
	state.apply({"op": "upgrade", "id": CC_ID}, 30)
	state.advance_to(130)
	state.apply({"op": "upgrade", "id": HANGAR_ID}, 130)
	state.apply(_train("grunt"), 180)
	state.army["grunt"] = 20
	state.advance_to(190)
	assert_eq(state.army_count("grunt"), 21)
	assert_eq(state.training_status(ACADEMY_ID), BaseState.TRAINING_IDLE)


func test_cancel_refunds_the_level_paid() -> void:
	var state := Fixtures.army_base()
	state.apply(_train("grunt"), 30)
	state.unit_levels["grunt"] = 2
	state.apply(_train("grunt"), 30)
	assert_eq(state.resources["crystal"], 470)
	assert_eq(state.apply({"op": "cancel_training", "id": ACADEMY_ID, "unit": "grunt"}, 31), "")
	assert_eq(state.resources["crystal"], 490, "the newest, paid at level 2")
	assert_eq(state.queue_of(ACADEMY_ID).size(), 1)
	assert_eq(state.apply({"op": "cancel_training", "id": ACADEMY_ID, "unit": "grunt"}, 32), "")
	assert_eq(state.resources["crystal"], 500)
	assert_eq(state.training_status(ACADEMY_ID), BaseState.TRAINING_IDLE)
	state.advance_to(100)
	assert_eq(state.army_count("grunt"), 0)


func test_cancelling_the_head_starts_the_next_afresh() -> void:
	var state := Fixtures.army_base()
	state.apply(_train("grunt"), 30)
	state.apply(_train("flyer"), 30)
	state.apply({"op": "cancel_training", "id": ACADEMY_ID, "unit": "grunt"}, 35)
	assert_eq(state.queue_of(ACADEMY_ID), PackedStringArray(["flyer"]))
	assert_eq(state.training_seconds_left(ACADEMY_ID), 20)
	state.advance_to(54)
	assert_eq(state.army_count("flyer"), 0)
	state.advance_to(55)
	assert_eq(state.army_count("flyer"), 1)


func test_a_refund_stops_at_storage() -> void:
	var state := Fixtures.army_base()
	state.apply(_train("grunt"), 30)
	state.resources["crystal"] = 995
	state.apply({"op": "cancel_training", "id": ACADEMY_ID, "unit": "grunt"}, 30)
	assert_eq(state.resources["crystal"], 1000)


func test_cancel_refusals_match_their_checks() -> void:
	var state := Fixtures.army_base()
	assert_eq(state.check_cancel_training(99, "grunt"), BaseState.ERR_UNKNOWN_BUILDING)
	assert_eq(state.apply({"op": "cancel_training", "id": 99, "unit": "grunt"}, 30),
		BaseState.ERR_UNKNOWN_BUILDING)
	assert_eq(state.check_cancel_training(ACADEMY_ID, "grunt"), BaseState.ERR_NOT_QUEUED)
	state.apply(_train("grunt"), 30)
	assert_eq(state.check_cancel_training(ACADEMY_ID, "flyer"), BaseState.ERR_NOT_QUEUED)
	assert_eq(state.apply({"op": "cancel_training", "id": ACADEMY_ID, "unit": "flyer"}, 30),
		BaseState.ERR_NOT_QUEUED)
	assert_eq(state.resources["crystal"], 490)


func test_training_leaves_production_alone() -> void:
	var state := Fixtures.army_base()
	state.apply({"op": "place", "type": "harvester", "cell": [9, 0]}, 30)
	state.apply(_train("grunt", 2), 30)
	state.advance_to(130)
	assert_eq(state.resources["crystal"], 500 - 20 + 50, "1800 crystal an hour for 100 s")
	assert_eq(state.army_count("grunt"), 2)


func test_the_same_commands_give_the_same_state() -> void:
	assert_eq(_snapshot(_scripted(1000)), _snapshot(_scripted(1000)))


func test_ticks_of_one_second_equal_one_big_tick() -> void:
	assert_eq(_snapshot(_scripted(1)), _snapshot(_scripted(1000)))


## A run of training, an upgrade, a second producer, a cancel and a hangar upgrade, with the
## clock advanced every `step` seconds between the commands.
func _scripted(step: int) -> BaseState:
	var state := Fixtures.army_base()
	state.resources["metal"] = 1000
	var commands := {
		30: [_train("grunt", 3), _train("flyer", 2)],
		45: [{"op": "upgrade", "id": ACADEMY_ID}],
		47: [{"op": "place", "type": "academy", "cell": [8, 9]},
			{"op": "train", "id": 5, "unit": "grunt", "count": 2}],
		56: [{"op": "upgrade", "id": CC_ID}],
		70: [{"op": "cancel_training", "id": ACADEMY_ID, "unit": "flyer"}],
		157: [{"op": "upgrade", "id": HANGAR_ID}, _train("walker", 2)],
	}
	for t: int in range(30, 400):
		if commands.has(t):
			var list: Array = commands[t]
			for command: Dictionary in list:
				assert_eq(state.apply(command, t), "", "%s at %d" % [command, t])
		elif (t - 30) % step == 0:
			state.advance_to(t)
	state.advance_to(400)
	return state


func _snapshot(state: BaseState) -> String:
	var queues := []
	for id: int in state.buildings:
		queues.append([id, state.queue_of(id), state.training_status(id), state.training_seconds_left(id)])
	return JSON.stringify({"save": state.to_dict(), "army": state.army, "levels": state.unit_levels,
		"queues": queues})


static func _train(unit: String, count: int = 1) -> Dictionary:
	return {"op": "train", "id": ACADEMY_ID, "unit": unit, "count": count}
