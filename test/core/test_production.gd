extends TestCase
## Resource production: integer-only, storage caps, and tick-size independence.

const Fixtures := preload("res://test/support/fixtures.gd")


func test_production_starts_when_construction_completes() -> void:
	# Extractor placed at t=1000 finishes at t=1060, then makes 1 metal per second.
	# One big advance must split the interval at the completion time.
	var state := Fixtures.new_base(1000)
	state.apply({"op": "place", "type": "extractor", "cell": [5, 5]}, 1000)
	state.advance_to(1160)
	assert_eq(state.resources["metal"], 600)


func test_fractional_production_carries_over() -> void:
	# Harvester: 1800 crystal/h = 1 every 2 s. Spends 50 metal, crystal starts at 500.
	var state := Fixtures.new_base()
	state.apply({"op": "place", "type": "harvester", "cell": [9, 9]}, 0)
	state.advance_to(1)
	assert_eq(state.resources["crystal"], 500)
	state.advance_to(2)
	assert_eq(state.resources["crystal"], 501)
	state.advance_to(101)
	assert_eq(state.resources["crystal"], 550)


func test_many_small_ticks_equal_one_big_tick() -> void:
	var stepped := Fixtures.new_base()
	var jumped := Fixtures.new_base()
	for state: BaseState in [stepped, jumped]:
		state.apply({"op": "place", "type": "harvester", "cell": [9, 9]}, 0)
		state.apply({"op": "place", "type": "extractor", "cell": [5, 5]}, 7)
	# Stays under the storage caps so the carried remainders are really exercised.
	for t: int in range(8, 501):
		stepped.advance_to(t)
	jumped.advance_to(500)
	assert_eq(stepped.resources["metal"], 883)
	assert_eq(stepped.resources["crystal"], 650)
	assert_eq(JSON.stringify(stepped.to_dict()), JSON.stringify(jumped.to_dict()))


func test_storage_caps_production() -> void:
	var state := Fixtures.new_base()
	state.apply({"op": "place", "type": "harvester", "cell": [9, 9]}, 0)
	state.advance_to(10_000_000)
	assert_eq(state.resources["crystal"], 1000)


func test_silo_raises_cap_after_it_is_built() -> void:
	var state := Fixtures.new_base()
	state.apply({"op": "place", "type": "silo", "cell": [5, 5]}, 0)
	assert_eq(state.capacity("metal"), 1000)
	state.advance_to(30)
	assert_eq(state.capacity("metal"), 2000)


func test_busy_buildings_do_not_produce() -> void:
	var state := Fixtures.new_base()
	state.apply({"op": "place", "type": "extractor", "cell": [5, 5]}, 0)
	assert_eq(state.production_per_hour("metal"), 0)
	state.advance_to(60)
	assert_eq(state.production_per_hour("metal"), 3600)


func test_third_resource_produces_and_caps() -> void:
	# Siphon: instant, 3600 antimatter/h = 1 per second, stores 100. The CC stores none.
	var state := Fixtures.new_base()
	assert_eq(state.resources["antimatter"], 0)
	assert_eq(state.apply({"op": "place", "type": "siphon", "cell": [9, 9]}, 0), "")
	assert_eq(state.capacity("antimatter"), 100)
	state.advance_to(60)
	assert_eq(state.resources["antimatter"], 60)
	state.advance_to(1000)
	assert_eq(state.resources["antimatter"], 100)
	assert_eq(state.resources["metal"], 500, "the other resources are untouched")
	assert_eq(state.resources["crystal"], 450)


func test_capacities_match_capacity_per_resource() -> void:
	var state := Fixtures.new_base()
	assert_eq(state.apply({"op": "place", "type": "siphon", "cell": [9, 9]}, 0), "")
	assert_eq(state.apply({"op": "place", "type": "silo", "cell": [5, 5]}, 0), "")
	var under_way := state.capacities()
	assert_eq(under_way, {"metal": 1000, "crystal": 1000, "antimatter": 100}, "the silo stores nothing while it is built")
	state.advance_to(30)
	var built := state.capacities()
	assert_eq(built, {"metal": 2000, "crystal": 1000, "antimatter": 100})
	assert_eq(PackedStringArray(built.keys()), state.catalog.resources, "every resource, in the catalog's order")
	for res: String in state.catalog.resources:
		assert_eq(built[res], state.capacity(res), res)


## A base whose production changes as it goes: a harvester (half a crystal a second, so a remainder
## carries), the siphon (capped at 100 antimatter), an extractor finishing at 60, a silo at 130, the
## Command Center upgraded from 200 to 300 (busy: storage stays its level 1's), and a second
## extractor from 400 to 460; then the storage caps metal and crystal.
func _changing_base() -> BaseState:
	var state := Fixtures.new_base()
	for step: Array in [["harvester", [9, 9], 0], ["siphon", [9, 8], 0], ["extractor", [5, 5], 0],
			["silo", [5, 2], 100]]:
		assert_eq(state.apply({"op": "place", "type": step[0], "cell": step[1]}, step[2]), "")
	assert_eq(state.apply({"op": "upgrade", "id": 1}, 200), "")
	state.advance_to(250)
	assert_eq(state.apply({"op": "place", "type": "extractor", "cell": [5, 7]}, 400), "")
	return state


func test_one_pass_production_pays_what_it_paid_before() -> void:
	# The amounts and remainders the per-resource payout (production_per_hour and capacity called
	# for each resource) gave this base, captured before production was paid in one pass.
	var expected := {
		451: [{"metal": 341, "crystal": 475, "antimatter": 100}, {"metal": 0, "crystal": 1800, "antimatter": 0}],
		473: [{"metal": 376, "crystal": 486, "antimatter": 100}, {"metal": 0, "crystal": 1800, "antimatter": 0}],
		1001: [{"metal": 1432, "crystal": 750, "antimatter": 100}, {"metal": 0, "crystal": 1800, "antimatter": 0}],
		2001: [{"metal": 3000, "crystal": 1250, "antimatter": 100}, {"metal": 0, "crystal": 1800, "antimatter": 0}],
		3001: [{"metal": 3000, "crystal": 1750, "antimatter": 100}, {"metal": 0, "crystal": 1800, "antimatter": 0}],
		200001: [{"metal": 3000, "crystal": 2000, "antimatter": 100}, {"metal": 0, "crystal": 1800, "antimatter": 0}],
	}
	var state := _changing_base()
	for t: int in expected:
		state.advance_to(t)
		assert_eq(state.resources, expected[t][0], "the amounts at %d" % t)
		assert_eq(state._remainders, expected[t][1], "the remainders at %d" % t)


func test_one_pass_production_matches_the_per_resource_payout() -> void:
	# Stepped over a long run, every second at first and further apart later: each step's rates and
	# capacities are the per-resource queries', and a step with nothing completing in it pays what
	# the per-resource formula pays from the amounts and remainders before it.
	var state := _changing_base()
	var t := state.now
	while t < 200_000:
		var step := 1 if t < 3000 else 997
		var rates := state.production_rates()
		var capacities := state.capacities()
		var before := state.resources.duplicate()
		var remainders: Dictionary[String, int] = state._remainders.duplicate()
		var completes := state._next_completion(t + step) != null
		for res: String in state.catalog.resources:
			assert_eq(rates[res], state.production_per_hour(res), "%s's rate at %d" % [res, t])
			assert_eq(capacities[res], state.capacity(res), "%s's capacity at %d" % [res, t])
		t += step
		state.advance_to(t)
		if completes:
			continue
		for res: String in state.catalog.resources:
			var rate := state.production_per_hour(res)
			var paid: int = before[res]
			if rate > 0:
				var gained: int = (remainders[res] + rate * step) / BaseState.SECONDS_PER_HOUR
				if gained > 0:
					paid = maxi(paid, mini(state.capacity(res), paid + gained))
			assert_eq(state.resources[res], paid, "%s paid over %d to %d" % [res, t - step, t])
