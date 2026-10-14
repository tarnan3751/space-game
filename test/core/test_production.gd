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
