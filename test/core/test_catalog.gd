extends TestCase
## Game data loading and validation, including the real data/ files.

const Fixtures := preload("res://test/support/fixtures.gd")


func test_shipped_data_is_valid() -> void:
	var catalog := Catalog.load_default()
	assert_eq(catalog.load_error, "")
	assert_true(catalog.has_type(Catalog.HQ_TYPE))
	assert_false(catalog.menu_order.is_empty())


func test_shipped_start_layout_fits() -> void:
	var catalog := Catalog.load_default()
	var state := BaseState.create_new(catalog, 0)
	var start_buildings: Array = catalog.start.get("buildings", [])
	assert_eq(state.buildings.size(), start_buildings.size(), "every start building placed")
	assert_true(state.builders_total() >= 1, "starts with a builder")


func test_shipped_costs_fit_reachable_storage() -> void:
	# Every price must fit in the storage a base can have when the level unlocks: the
	# Command Center's at that level plus every allowed storage building at its best
	# allowed level. Otherwise the level could never be bought.
	var catalog := Catalog.load_default()
	assert_eq(catalog.load_error, "")
	for type: String in catalog.types():
		for level: int in range(1, catalog.max_level(type) + 1):
			var stats := catalog.level_stats(type, level)
			var cc := int(stats.get("requires_cc", 1))
			var cost: Dictionary = stats.get("cost", {})
			for res: Variant in cost:
				var reachable := _reachable_storage(catalog, str(res), cc)
				assert_true(int(cost[res]) <= reachable, "%s level %d costs %d %s; storage at CC %d is %d" % [
					type, level, int(cost[res]), res, cc, reachable])


func test_shipped_curves_never_go_down() -> void:
	var catalog := Catalog.load_default()
	assert_eq(catalog.load_error, "")
	for type: String in catalog.types():
		for level: int in range(2, catalog.max_level(type) + 1):
			var before := catalog.level_stats(type, level - 1)
			var after := catalog.level_stats(type, level)
			for field: String in ["cost", "produces", "storage"]:
				for res: String in catalog.resources:
					assert_true(_amount(after, field, res) >= _amount(before, field, res),
						"%s level %d %s.%s goes down" % [type, level, field, res])
			for field: String in ["build_seconds", "hp", "capacity"]:
				assert_true(int(after.get(field, 0)) >= int(before.get(field, 0)),
					"%s level %d %s goes down" % [type, level, field])


func test_shipped_final_levels_require_the_top_command_center() -> void:
	# Every maxed building belongs to the top tier. The Command Center's own levels each
	# require the one below, so it is left out.
	var catalog := Catalog.load_default()
	assert_eq(catalog.load_error, "")
	var top := catalog.max_level(Catalog.HQ_TYPE)
	for type: String in catalog.types():
		if type == Catalog.HQ_TYPE:
			continue
		var stats := catalog.level_stats(type, catalog.max_level(type))
		assert_eq(int(stats.get("requires_cc", 1)), top, "%s's final level" % type)


func test_shipped_counts_never_go_down() -> void:
	var catalog := Catalog.load_default()
	assert_eq(catalog.load_error, "")
	for type: String in catalog.types():
		for cc: int in range(2, catalog.max_cc_level() + 1):
			assert_true(catalog.max_count(type, cc) >= catalog.max_count(type, cc - 1),
				"%s max_count goes down at Command Center %d" % [type, cc])


func test_shipped_build_times_stay_within_three_days() -> void:
	# No timer a builder waits on is longer than three days, the Command Center's included
	# (docs/plans/retune.md).
	var catalog := Catalog.load_default()
	assert_eq(catalog.load_error, "")
	for type: String in catalog.types():
		for level: int in range(1, catalog.max_level(type) + 1):
			var seconds := int(catalog.level_stats(type, level)["build_seconds"])
			assert_true(seconds <= 3 * 86400, "%s level %d takes %d s" % [type, level, seconds])


func test_shipped_units_fit_what_a_base_can_reach() -> void:
	# A unit's training and research prices fit the storage a base can have when they unlock,
	# and one unit fits the housing it can have then. The Command Center level of a unit is
	# the one its producer level needs; of a research level, the one its lab level needs.
	var catalog := Catalog.load_default()
	assert_eq(catalog.load_error, "")
	assert_false(catalog.unit_types().is_empty())
	for type: String in catalog.unit_types():
		var producer_cc := _requires_cc(catalog, catalog.unit_producer(type), catalog.unit_producer_level(type))
		assert_true(catalog.unit_housing(type) <= _reachable_housing(catalog, producer_cc),
			"%s's housing fits the Hangars at CC %d" % [type, producer_cc])
		for level: int in range(1, catalog.unit_max_level(type) + 1):
			var stats := catalog.unit_level_stats(type, level)
			var cc := producer_cc
			if level > 1:
				cc = maxi(cc, _requires_cc(catalog, catalog.research_type, int(stats["requires_lab"])))
			for field: String in ["train_cost", "research_cost"]:
				var cost: Dictionary = stats.get(field, {})
				for res: Variant in cost:
					var reachable := _reachable_storage(catalog, str(res), cc)
					assert_true(int(cost[res]) <= reachable, "%s level %d %s is %d %s; storage at CC %d is %d" % [
						type, level, field, int(cost[res]), res, cc, reachable])


func test_shipped_unit_curves_never_go_down() -> void:
	var catalog := Catalog.load_default()
	assert_eq(catalog.load_error, "")
	for type: String in catalog.unit_types():
		for level: int in range(2, catalog.unit_max_level(type) + 1):
			var before := catalog.unit_level_stats(type, level - 1)
			var after := catalog.unit_level_stats(type, level)
			for field: String in ["train_cost", "research_cost"]:
				for res: String in catalog.resources:
					assert_true(_amount(after, field, res) >= _amount(before, field, res),
						"%s level %d %s.%s goes down" % [type, level, field, res])
			for field: String in ["research_seconds", "requires_lab", "hp", "damage"]:
				assert_true(int(after.get(field, 0)) >= int(before.get(field, 0)),
					"%s level %d %s goes down" % [type, level, field])


func test_shipped_unit_final_levels_require_the_top_lab() -> void:
	var catalog := Catalog.load_default()
	assert_eq(catalog.load_error, "")
	var top := catalog.max_level(catalog.research_type)
	for type: String in catalog.unit_types():
		var stats := catalog.unit_level_stats(type, catalog.unit_max_level(type))
		assert_eq(int(stats.get("requires_lab", 0)), top, "%s's final level" % type)


func test_shipped_abilities_fit_what_a_base_can_reach() -> void:
	# An ability's making and research prices fit the storage a base can have when they unlock:
	# the Command Center level its Foundry level needs, and for a research level the one its lab
	# level needs. The Foundry's capacity holds at least one from its first level.
	var catalog := Catalog.load_default()
	assert_eq(catalog.load_error, "")
	assert_eq(catalog.ability_types(), PackedStringArray(["repair_swarm", "emp_burst", "orbital_strike"]))
	assert_true(int(catalog.level_stats(catalog.foundry_type, 1).get("capacity", 0)) >= 1)
	for id: String in catalog.ability_types():
		var foundry_cc := _requires_cc(catalog, catalog.foundry_type, catalog.ability_requires_foundry(id))
		for level: int in range(1, catalog.ability_max_level(id) + 1):
			var stats := catalog.ability_level_stats(id, level)
			var cc := foundry_cc
			if level > 1:
				cc = maxi(cc, _requires_cc(catalog, catalog.research_type, int(stats["requires_lab"])))
			for field: String in ["make_cost", "research_cost"]:
				var cost: Dictionary = stats.get(field, {})
				for res: Variant in cost:
					var reachable := _reachable_storage(catalog, str(res), cc)
					assert_true(int(cost[res]) <= reachable, "%s level %d %s is %d %s; storage at CC %d is %d" % [
						id, level, field, int(cost[res]), res, cc, reachable])


func test_shipped_ability_curves_never_go_down() -> void:
	var catalog := Catalog.load_default()
	assert_eq(catalog.load_error, "")
	for id: String in catalog.ability_types():
		for level: int in range(2, catalog.ability_max_level(id) + 1):
			var before := catalog.ability_level_stats(id, level - 1)
			var after := catalog.ability_level_stats(id, level)
			for field: String in ["make_cost", "research_cost"]:
				for res: String in catalog.resources:
					assert_true(_amount(after, field, res) >= _amount(before, field, res),
						"%s level %d %s.%s goes down" % [id, level, field, res])
			var fields: Array = Catalog.EFFECT_FIELDS[catalog.ability_effect(id)]
			for field: String in ["research_seconds", "requires_lab"] + fields:
				assert_true(int(after.get(field, 0)) >= int(before.get(field, 0)),
					"%s level %d %s goes down" % [id, level, field])


func test_shipped_ability_final_levels_require_the_top_lab() -> void:
	var catalog := Catalog.load_default()
	assert_eq(catalog.load_error, "")
	var top := catalog.max_level(catalog.research_type)
	for id: String in catalog.ability_types():
		assert_eq(catalog.ability_max_level(id), 5, id)
		var stats := catalog.ability_level_stats(id, catalog.ability_max_level(id))
		assert_eq(int(stats.get("requires_lab", 0)), top, "%s's final level" % id)


func test_json_numbers_become_ints() -> void:
	var catalog := Fixtures.catalog()
	assert_eq(catalog.level_stats("extractor", 1)["build_seconds"], 60)
	assert_eq(catalog.size_of("extractor"), 2)
	assert_eq(catalog.grid_size, Vector2i(10, 10))


func test_level_and_count_lookups() -> void:
	var catalog := Fixtures.catalog()
	assert_eq(catalog.max_level("extractor"), 2)
	assert_eq(catalog.level_stats("extractor", 3), {})
	assert_eq(catalog.max_count("extractor", 1), 2)
	assert_eq(catalog.max_count("extractor", 99), 4, "clamps to the highest level listed")


func test_fixtures_are_valid() -> void:
	assert_eq(Fixtures.catalog().load_error, "")
	assert_eq(_error_after(func(_rules: Dictionary, _buildings: Dictionary) -> void: pass), "",
		"the fixtures survive the JSON round trip the validation tests use")


func test_resource_and_category_lookups() -> void:
	var catalog := Fixtures.catalog()
	assert_eq(catalog.resources, PackedStringArray(["metal", "crystal", "antimatter"]))
	assert_eq(catalog.resource_name("antimatter"), "Antimatter")
	assert_eq(catalog.resource_color("antimatter"), "b48cff")
	assert_eq(catalog.resource_name("gold"), "gold", "falls back to the id")
	assert_eq(catalog.resource_color("gold"), "")
	assert_eq(catalog.categories, PackedStringArray(["resources", "army", "traps", "walls"]))
	assert_eq(catalog.category_name("traps"), "Traps")
	assert_eq(catalog.category_of("extractor"), "resources")
	assert_eq(catalog.category_of(Catalog.HQ_TYPE), Catalog.CORE_CATEGORY)
	assert_eq(catalog.max_cc_level(), 2)


func test_display_fields() -> void:
	var catalog := Fixtures.catalog()
	assert_true(catalog.is_hidden("mine"))
	assert_false(catalog.is_hidden("extractor"))
	assert_eq(catalog.targets_of("mine"), "ground")
	assert_eq(catalog.targets_of("extractor"), "")
	assert_eq(catalog.level_stats("hangar", 2)["capacity"], 30)


func test_dev_cheats_make_every_level_free_and_one_second_at_most() -> void:
	var catalog := Fixtures.catalog()
	var before := Fixtures.catalog()
	catalog.apply_dev_cheats()
	for type: String in catalog.types():
		for cc: int in range(1, catalog.max_cc_level() + 1):
			assert_eq(catalog.max_count(type, cc), before.max_count(type, cc), "%s max_count at CC %d" % [type, cc])
		for level: int in range(1, catalog.max_level(type) + 1):
			var stats := catalog.level_stats(type, level)
			var original := before.level_stats(type, level)
			var where := "%s level %d" % [type, level]
			for res: String in catalog.resources:
				assert_eq(_amount(stats, "cost", res), 0, "%s costs %s" % [where, res])
			# A level that takes time takes one second; an instant one stays instant.
			assert_eq(stats["build_seconds"], mini(int(original["build_seconds"]), 1), where)
			# Every other field (requires_cc, storage, produces, builders...) is untouched.
			var rest := stats.duplicate()
			var original_rest := original.duplicate()
			for field: String in ["cost", "build_seconds"]:
				rest.erase(field)
				original_rest.erase(field)
			assert_eq(rest, original_rest, "%s apart from cost and build_seconds" % where)


func test_dev_cheats_let_a_base_build_what_it_cannot_afford() -> void:
	var catalog := Fixtures.catalog()
	var state := BaseState.create_new(catalog, 0)
	state.resources["crystal"] = 50
	assert_eq(state.check_place("extractor", Vector2i(5, 5)), BaseState.ERR_FUNDS)
	catalog.apply_dev_cheats()
	assert_eq(state.apply({"op": "place", "type": "extractor", "cell": [5, 5]}, 0), "")
	assert_eq(state.resources["crystal"], 50, "nothing was paid")
	var extractor: BuildingState = state.buildings[state.last_added_id]
	assert_true(extractor.is_busy(), "under construction")
	assert_eq(state.seconds_left(extractor.id), 1)
	state.advance_to(1)
	assert_false(extractor.is_busy(), "finished one second later")
	assert_eq(extractor.level, 1)


func test_unit_lookups() -> void:
	var catalog := Fixtures.catalog()
	assert_eq(catalog.unit_types(), PackedStringArray(["grunt", "flyer", "walker"]), "units.json order")
	assert_eq(catalog.housing_type, "hangar")
	assert_eq(catalog.research_type, "lab")
	assert_true(catalog.has_unit("grunt"))
	assert_false(catalog.has_unit("extractor"))
	assert_eq(catalog.unit_name("walker"), "Walker")
	assert_eq(catalog.unit_name("ghost"), "ghost", "falls back to the id")
	assert_eq(catalog.unit_producer("grunt"), "academy")
	assert_eq(catalog.unit_producer_level("walker"), 2)
	assert_eq(catalog.unit_class("flyer"), "air")
	assert_eq(catalog.unit_crew("walker"), "piloted")
	assert_eq(catalog.unit_housing("walker"), 5)
	assert_eq(catalog.unit_train_seconds("grunt"), 10)
	assert_eq(catalog.unit_max_level("grunt"), 2)
	assert_eq(catalog.unit_max_level("ghost"), 0)
	assert_eq(catalog.unit_level_stats("grunt", 2)["requires_lab"], 1)
	assert_eq(catalog.unit_level_stats("grunt", 2)["research_seconds"], 60)
	assert_eq(catalog.unit_level_stats("grunt", 3), {})
	assert_eq(catalog.units_of_producer("academy"), PackedStringArray(["grunt", "flyer", "walker"]))
	assert_eq(catalog.units_of_producer("hangar"), PackedStringArray())


func test_missing_units_file_reports_an_error() -> void:
	var catalog := Catalog.from_json(FileAccess.get_file_as_string(Fixtures.RULES),
		FileAccess.get_file_as_string(Fixtures.BUILDINGS), "")
	assert_true(catalog.load_error.contains("units JSON is missing"), catalog.load_error)


func test_validation_reports_bad_army_rules() -> void:
	var cases := {
		"rules.army must be an object": func(rules: Dictionary, _units: Dictionary) -> void:
			rules["army"] = "hangar",
		"rules.army.housing names unknown type 'barn'": func(rules: Dictionary, _units: Dictionary) -> void:
			rules["army"]["housing"] = "barn",
		"rules.army needs a research type": func(rules: Dictionary, _units: Dictionary) -> void:
			rules["army"].erase("research"),
	}
	for message: String in cases:
		var error := _unit_error_after(cases[message])
		assert_true(error.contains(message), "%s: %s" % [message, error])


func test_validation_reports_bad_units() -> void:
	var cases := {
		"unit grunt must be an object": func(_rules: Dictionary, units: Dictionary) -> void:
			units["grunt"] = "small",
		"unit grunt.producer must be a building type": func(_rules: Dictionary, units: Dictionary) -> void:
			units["grunt"]["producer"] = "barracks",
		"unit walker.producer_level must be 1-2": func(_rules: Dictionary, units: Dictionary) -> void:
			units["walker"]["producer_level"] = 3,
		"unit grunt.class must be ground or air": func(_rules: Dictionary, units: Dictionary) -> void:
			units["grunt"]["class"] = "space",
		"unit grunt.crew must be human, piloted or autonomous": func(_rules: Dictionary, units: Dictionary) -> void:
			units["grunt"].erase("crew"),
		"unit grunt.housing must be a whole number of at least 1": func(_rules: Dictionary, units: Dictionary) -> void:
			units["grunt"]["housing"] = 0,
		"unit grunt.train_seconds must be a whole number of at least 1": func(_rules: Dictionary, units: Dictionary) -> void:
			units["grunt"]["train_seconds"] = 0,
		"unit grunt.speed must be whole and non-negative": func(_rules: Dictionary, units: Dictionary) -> void:
			units["grunt"]["speed"] = 1.5,
		"unit grunt.prefers must be one of any, defense, resource, wall, hq": func(_rules: Dictionary, units: Dictionary) -> void:
			units["grunt"]["prefers"] = "gold",
		"unit walker.self_destruct must be true or false": func(_rules: Dictionary, units: Dictionary) -> void:
			units["walker"]["self_destruct"] = 1,
		"unit walker.damage_pct must be an object": func(_rules: Dictionary, units: Dictionary) -> void:
			units["walker"]["damage_pct"] = 200,
		"unit walker.damage_pct.tree must be a target class and a whole percent": func(_rules: Dictionary, units: Dictionary) -> void:
			units["walker"]["damage_pct"]["tree"] = 100,
		"unit walker.levels must be a list": func(_rules: Dictionary, units: Dictionary) -> void:
			units["walker"]["levels"] = {},
		"unit walker has no levels": func(_rules: Dictionary, units: Dictionary) -> void:
			units["walker"]["levels"] = [],
		"unit walker level 1 must be an object": func(_rules: Dictionary, units: Dictionary) -> void:
			units["walker"]["levels"][0] = 5,
		"unit walker level 1.train_cost uses unknown resource 'gold'": func(_rules: Dictionary, units: Dictionary) -> void:
			units["walker"]["levels"][0]["train_cost"] = {"gold": 5},
		"unit walker level 1.train_cost.crystal must be a whole number": func(_rules: Dictionary, units: Dictionary) -> void:
			units["walker"]["levels"][0]["train_cost"] = {"crystal": 5.5},
		"unit walker level 1.hp must be whole and non-negative": func(_rules: Dictionary, units: Dictionary) -> void:
			units["walker"]["levels"][0]["hp"] = -1,
		"unit walker level 1 must not have requires_lab: level 1 needs no research": func(_rules: Dictionary, units: Dictionary) -> void:
			units["walker"]["levels"][0]["requires_lab"] = 1,
		"unit grunt level 2.research_cost must be an object": func(_rules: Dictionary, units: Dictionary) -> void:
			units["grunt"]["levels"][1]["research_cost"] = 100,
		"unit grunt level 2.research_seconds must be a whole number of at least 1": func(_rules: Dictionary, units: Dictionary) -> void:
			units["grunt"]["levels"][1].erase("research_seconds"),
		"unit grunt level 2.requires_lab must be 1-2": func(_rules: Dictionary, units: Dictionary) -> void:
			units["grunt"]["levels"][1]["requires_lab"] = 3,
	}
	for message: String in cases:
		var error := _unit_error_after(cases[message])
		assert_true(error.contains(message), "%s: %s" % [message, error])
	for field: String in Catalog.UNIT_LEVEL_WHOLE_FIELDS:
		var field_error := _unit_error_after(func(_rules: Dictionary, units: Dictionary) -> void:
			units["grunt"]["levels"][0][field] = -1)
		assert_true(field_error.contains("unit grunt level 1.%s must be whole and non-negative" % field),
			field_error)


func test_dev_cheats_make_units_free_and_one_second_at_most() -> void:
	var catalog := Fixtures.catalog()
	var before := Fixtures.catalog()
	catalog.apply_dev_cheats()
	for type: String in catalog.unit_types():
		assert_eq(catalog.unit_train_seconds(type), mini(before.unit_train_seconds(type), 1), type)
		assert_eq(catalog.unit_producer_level(type), before.unit_producer_level(type), type)
		assert_eq(catalog.unit_housing(type), before.unit_housing(type), type)
		for level: int in range(1, catalog.unit_max_level(type) + 1):
			var stats := catalog.unit_level_stats(type, level)
			var original := before.unit_level_stats(type, level)
			var where := "%s level %d" % [type, level]
			assert_eq(stats["train_cost"], {}, where)
			var changed := ["train_cost"]
			if level > 1:
				assert_eq(stats["research_cost"], {}, where)
				assert_eq(stats["research_seconds"], mini(int(original["research_seconds"]), 1), where)
				changed.append_array(["research_cost", "research_seconds"])
			# Every other field (requires_lab, hp, damage...) is untouched.
			var rest := stats.duplicate()
			var original_rest := original.duplicate()
			for field: String in changed:
				rest.erase(field)
				original_rest.erase(field)
			assert_eq(rest, original_rest, "%s apart from its costs and times" % where)


func test_dev_cheats_make_abilities_free_and_one_second_at_most() -> void:
	var catalog := Fixtures.catalog()
	var before := Fixtures.catalog()
	catalog.apply_dev_cheats()
	for id: String in catalog.ability_types():
		assert_eq(catalog.ability_make_seconds(id), mini(before.ability_make_seconds(id), 1), id)
		assert_eq(catalog.ability_requires_foundry(id), before.ability_requires_foundry(id), id)
		for level: int in range(1, catalog.ability_max_level(id) + 1):
			var stats := catalog.ability_level_stats(id, level)
			var original := before.ability_level_stats(id, level)
			var where := "%s level %d" % [id, level]
			assert_eq(stats["make_cost"], {}, where)
			var changed := ["make_cost"]
			if level > 1:
				assert_eq(stats["research_cost"], {}, where)
				assert_eq(stats["research_seconds"], mini(int(original["research_seconds"]), 1), where)
				changed.append_array(["research_cost", "research_seconds"])
			var rest := stats.duplicate()
			var original_rest := original.duplicate()
			for field: String in changed:
				rest.erase(field)
				original_rest.erase(field)
			assert_eq(rest, original_rest, "%s apart from its costs and times" % where)


func test_ability_lookups() -> void:
	var catalog := Fixtures.catalog()
	assert_eq(catalog.ability_types(), PackedStringArray(["swarm", "burst", "strike"]), "abilities.json order")
	assert_eq(catalog.foundry_type, "foundry")
	assert_true(catalog.has_ability("strike"))
	assert_false(catalog.has_ability("grunt"))
	assert_eq(catalog.ability_name("burst"), "Burst")
	assert_eq(catalog.ability_name("ghost"), "ghost", "falls back to the id")
	assert_eq(catalog.ability_effect("swarm"), Catalog.EFFECT_SWARM)
	assert_eq(catalog.ability_effect("burst"), Catalog.EFFECT_EMP)
	assert_eq(catalog.ability_effect("strike"), Catalog.EFFECT_STRIKE)
	assert_eq(catalog.ability_make_seconds("strike"), 30)
	assert_eq(catalog.ability_requires_foundry("strike"), 2)
	assert_eq(catalog.ability_radius("swarm"), 2000)
	assert_eq(catalog.ability_max_level("swarm"), 2)
	assert_eq(catalog.ability_max_level("burst"), 1)
	assert_eq(catalog.ability_max_level("ghost"), 0)
	assert_eq(catalog.ability_level_stats("swarm", 2)["heal_per_second"], 80)
	assert_eq(catalog.ability_level_stats("strike", 1)["make_cost"], {"crystal": 30})
	assert_eq(catalog.ability_level_stats("strike", 3), {})


func test_no_abilities_file_is_no_abilities() -> void:
	var catalog := Catalog.from_json(FileAccess.get_file_as_string(Fixtures.RULES),
		FileAccess.get_file_as_string(Fixtures.BUILDINGS), FileAccess.get_file_as_string(Fixtures.UNITS))
	assert_eq(catalog.load_error, "")
	assert_true(catalog.ability_types().is_empty())
	var missing := Catalog.from_json(FileAccess.get_file_as_string(Fixtures.RULES),
		FileAccess.get_file_as_string(Fixtures.BUILDINGS), FileAccess.get_file_as_string(Fixtures.UNITS), "")
	assert_true(missing.load_error.contains("abilities JSON is missing"), missing.load_error)


func test_validation_reports_bad_abilities() -> void:
	var cases := {
		"rules.army.foundry names unknown type 'forge'": func(rules: Dictionary, _abilities: Dictionary) -> void:
			rules["army"]["foundry"] = "forge",
		"rules.army needs a foundry type when there are abilities": func(rules: Dictionary, _abilities: Dictionary) -> void:
			rules["army"].erase("foundry"),
		"ability swarm must be an object": func(_rules: Dictionary, abilities: Dictionary) -> void:
			abilities["swarm"] = 3,
		"ability grunt shares its id with a unit": func(_rules: Dictionary, abilities: Dictionary) -> void:
			abilities["grunt"] = abilities["burst"].duplicate(true),
		"ability swarm.effect must be swarm, emp or strike": func(_rules: Dictionary, abilities: Dictionary) -> void:
			abilities["swarm"]["effect"] = "heal",
		"ability swarm.make_seconds must be a whole number of at least 1": func(_rules: Dictionary, abilities: Dictionary) -> void:
			abilities["swarm"]["make_seconds"] = 0,
		"ability strike.requires_foundry must be 1-2": func(_rules: Dictionary, abilities: Dictionary) -> void:
			abilities["strike"]["requires_foundry"] = 3,
		"ability burst.radius_units must be whole and non-negative": func(_rules: Dictionary, abilities: Dictionary) -> void:
			abilities["burst"]["radius_units"] = -5,
		"ability burst.levels must be a list": func(_rules: Dictionary, abilities: Dictionary) -> void:
			abilities["burst"]["levels"] = {},
		"ability burst has no levels": func(_rules: Dictionary, abilities: Dictionary) -> void:
			abilities["burst"]["levels"] = [],
		"ability burst level 1 must be an object": func(_rules: Dictionary, abilities: Dictionary) -> void:
			abilities["burst"]["levels"][0] = 1,
		"ability burst level 1.make_cost uses unknown resource 'gold'": func(_rules: Dictionary, abilities: Dictionary) -> void:
			abilities["burst"]["levels"][0]["make_cost"] = {"gold": 5},
		"ability burst level 1.stun_ms must be whole and non-negative": func(_rules: Dictionary, abilities: Dictionary) -> void:
			abilities["burst"]["levels"][0].erase("stun_ms"),
		"ability swarm level 1.duration_ms must be whole and non-negative": func(_rules: Dictionary, abilities: Dictionary) -> void:
			abilities["swarm"]["levels"][0]["duration_ms"] = 1.5,
		"ability strike level 1.delay_ms must be whole and non-negative": func(_rules: Dictionary, abilities: Dictionary) -> void:
			abilities["strike"]["levels"][0]["delay_ms"] = -1,
		"ability burst level 1 must not have research_cost: level 1 needs no research": func(_rules: Dictionary, abilities: Dictionary) -> void:
			abilities["burst"]["levels"][0]["research_cost"] = {},
		"ability swarm level 2.research_seconds must be a whole number of at least 1": func(_rules: Dictionary, abilities: Dictionary) -> void:
			abilities["swarm"]["levels"][1].erase("research_seconds"),
		"ability strike level 2.requires_lab must be 1-2": func(_rules: Dictionary, abilities: Dictionary) -> void:
			abilities["strike"]["levels"][1]["requires_lab"] = 3,
	}
	for message: String in cases:
		var error := _ability_error_after(cases[message])
		assert_true(error.contains(message), "%s: %s" % [message, error])
	assert_eq(_ability_error_after(func(_rules: Dictionary, _abilities: Dictionary) -> void: pass), "")


func test_validation_reports_unknown_resources() -> void:
	var rules := FileAccess.get_file_as_string(Fixtures.RULES)
	var buildings := '{"command_center": {"size": 2, "max_count": [1], "levels": [' \
		+ '{"cost": {"gold": 5}, "build_seconds": 0}]}}'
	var catalog := Catalog.from_json(rules, buildings)
	assert_true(catalog.load_error.contains("unknown resource 'gold'"), catalog.load_error)


func test_missing_files_report_an_error() -> void:
	var catalog := Catalog.from_json("", "")
	assert_false(catalog.load_error.is_empty())


func test_validation_reports_resource_entries() -> void:
	var error := _error_after(func(rules: Dictionary, _buildings: Dictionary) -> void:
		rules["resources"].append({"name": "Gold"}))
	assert_true(error.contains("rules.resources[3] needs an id"), error)
	error = _error_after(func(rules: Dictionary, _buildings: Dictionary) -> void:
		rules["resources"].append({"id": "metal"}))
	assert_true(error.contains("rules.resources lists 'metal' twice"), error)
	error = _error_after(func(rules: Dictionary, _buildings: Dictionary) -> void:
		rules["resources"][0]["color"] = "silver")
	assert_true(error.contains("rules.resources 'metal'.color must be a hex colour"), error)


func test_validation_reports_category_entries() -> void:
	var error := _error_after(func(rules: Dictionary, _buildings: Dictionary) -> void:
		rules["categories"].append({"name": "Misc"}))
	assert_true(error.contains("rules.categories[4] needs an id"), error)
	error = _error_after(func(rules: Dictionary, _buildings: Dictionary) -> void:
		rules["categories"].append({"id": "army"}))
	assert_true(error.contains("rules.categories lists 'army' twice"), error)
	error = _error_after(func(rules: Dictionary, _buildings: Dictionary) -> void:
		rules["categories"].append({"id": Catalog.CORE_CATEGORY}))
	assert_true(error.contains("rules.categories must not list 'core'"), error)


func test_validation_reports_bad_categories() -> void:
	var error := _error_after(func(_rules: Dictionary, buildings: Dictionary) -> void:
		buildings["extractor"].erase("category"))
	assert_true(error.contains("extractor.category must be one of rules.categories"), error)
	error = _error_after(func(_rules: Dictionary, buildings: Dictionary) -> void:
		buildings["extractor"]["category"] = "farming")
	assert_true(error.contains("extractor.category must be one of rules.categories"), error)
	error = _error_after(func(_rules: Dictionary, buildings: Dictionary) -> void:
		buildings["extractor"]["category"] = Catalog.CORE_CATEGORY)
	assert_true(error.contains("extractor.category must be one of rules.categories"), error)
	error = _error_after(func(_rules: Dictionary, buildings: Dictionary) -> void:
		buildings[Catalog.HQ_TYPE]["category"] = "resources")
	assert_true(error.contains("command_center.category must be 'core'"), error)


func test_validation_reports_bad_display_fields() -> void:
	var error := _error_after(func(_rules: Dictionary, buildings: Dictionary) -> void:
		buildings["mine"]["targets"] = "space")
	assert_true(error.contains("mine.targets must be ground, air or both"), error)
	error = _error_after(func(_rules: Dictionary, buildings: Dictionary) -> void:
		buildings["mine"]["hidden"] = "yes")
	assert_true(error.contains("mine.hidden must be true or false"), error)


func test_validation_reports_level_numbers_that_are_not_whole() -> void:
	for field: String in Catalog.WHOLE_FIELDS:
		var field_error := _error_after(func(_rules: Dictionary, buildings: Dictionary) -> void:
			buildings["hangar"]["levels"][0][field] = -1)
		assert_true(field_error.contains("hangar level 1.%s must be whole and non-negative" % field),
			field_error)
	var error := _error_after(func(_rules: Dictionary, buildings: Dictionary) -> void:
		buildings["hangar"]["levels"][0]["hp"] = 1.5)
	assert_true(error.contains("hangar level 1.hp must be whole and non-negative"), error)


func test_validation_reports_bad_max_count() -> void:
	var error := _error_after(func(_rules: Dictionary, buildings: Dictionary) -> void:
		buildings["extractor"]["max_count"] = [2, 4, 6])
	assert_true(error.contains("extractor.max_count needs 2 entries, one per Command Center level"), error)
	error = _error_after(func(_rules: Dictionary, buildings: Dictionary) -> void:
		buildings["extractor"]["max_count"] = [2, -1])
	assert_true(error.contains("extractor.max_count entries must be whole and non-negative"), error)


func test_validation_reports_requires_cc_out_of_range() -> void:
	var error := _error_after(func(_rules: Dictionary, buildings: Dictionary) -> void:
		buildings["extractor"]["levels"][1]["requires_cc"] = 3)
	assert_true(error.contains("extractor level 2.requires_cc must be 1-2"), error)
	error = _error_after(func(_rules: Dictionary, buildings: Dictionary) -> void:
		buildings["extractor"]["levels"][1]["requires_cc"] = 0)
	assert_true(error.contains("extractor level 2.requires_cc must be 1-2"), error)


func test_validation_reports_max_count_disagreeing_with_unlock() -> void:
	var error := _error_after(func(_rules: Dictionary, buildings: Dictionary) -> void:
		buildings["lab"]["max_count"] = [1, 1])
	assert_true(error.contains("lab.max_count must be 0 below Command Center 2 and above 0 at it"), error)
	error = _error_after(func(_rules: Dictionary, buildings: Dictionary) -> void:
		buildings["extractor"]["max_count"] = [0, 4])
	assert_true(error.contains("extractor.max_count must be 0 below Command Center 1 and above 0 at it"), error)


func test_battle_rules_and_classes() -> void:
	var catalog := Fixtures.battle_catalog()
	assert_eq(catalog.load_error, "")
	assert_eq(catalog.battle_seconds, 60)
	assert_eq(catalog.wall_type, "wall")
	assert_eq(catalog.wall_cost_units, 8000)
	assert_eq(catalog.loot_pct("metal"), 50)
	assert_eq(catalog.loot_pct("gold"), 0)
	var classes := {
		"command_center": Catalog.CLASS_HQ, "wall": Catalog.CLASS_WALL, "mine": Catalog.CLASS_TRAP,
		"air_mine": Catalog.CLASS_TRAP, "turret": Catalog.CLASS_DEFENSE, "shield": Catalog.CLASS_DEFENSE,
		"sentry": Catalog.CLASS_DEFENSE, "extractor": Catalog.CLASS_RESOURCE,
		"silo": Catalog.CLASS_RESOURCE, "siphon": Catalog.CLASS_RESOURCE,
		"drone_bay": Catalog.CLASS_OTHER, "hangar": Catalog.CLASS_OTHER, "lab": Catalog.CLASS_OTHER,
	}
	for type: String in classes:
		assert_eq(catalog.battle_class(type), classes[type], type)


func test_no_battle_rules_is_no_battle() -> void:
	var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Fixtures.RULES))
	rules.erase("battle")
	var catalog := Catalog.from_json(JSON.stringify(rules), FileAccess.get_file_as_string(Fixtures.BUILDINGS),
		FileAccess.get_file_as_string(Fixtures.UNITS))
	assert_eq(catalog.load_error, "")
	assert_eq(catalog.battle_seconds, 0)
	assert_eq(catalog.battle_class("wall"), Catalog.CLASS_OTHER, "no wall type without battle rules")


func test_validation_reports_bad_battle_rules() -> void:
	var cases := {
		"rules.battle must be an object": func(rules: Dictionary, _buildings: Dictionary) -> void:
			rules["battle"] = 180,
		"rules.battle.seconds must be a whole number of at least 1": func(rules: Dictionary, _buildings: Dictionary) -> void:
			rules["battle"]["seconds"] = 0,
		"rules.battle.wall_cost_units must be whole and non-negative": func(rules: Dictionary, _buildings: Dictionary) -> void:
			rules["battle"]["wall_cost_units"] = -1,
		"rules.battle.wall names unknown type 'fence'": func(rules: Dictionary, _buildings: Dictionary) -> void:
			rules["battle"]["wall"] = "fence",
		"rules.battle.trap_category must be one of rules.categories": func(rules: Dictionary, _buildings: Dictionary) -> void:
			rules["battle"]["trap_category"] = "mines",
		"rules.battle.loot_pct must be an object": func(rules: Dictionary, _buildings: Dictionary) -> void:
			rules["battle"]["loot_pct"] = 20,
		"rules.battle.loot_pct uses unknown resource 'gold'": func(rules: Dictionary, _buildings: Dictionary) -> void:
			rules["battle"]["loot_pct"]["gold"] = 10,
		"rules.battle.loot_pct.metal must be a whole percent, 0-100": func(rules: Dictionary, _buildings: Dictionary) -> void:
			rules["battle"]["loot_pct"]["metal"] = 101,
	}
	for message: String in cases:
		var error := _error_after(cases[message])
		assert_true(error.contains(message), "%s: %s" % [message, error])


func test_validation_reports_a_shell_without_a_fire_rate() -> void:
	var error := _error_after(func(_rules: Dictionary, buildings: Dictionary) -> void:
		buildings["mortar"]["levels"][0]["fire_ms"] = 20)
	assert_true(error.contains("mortar level 1 fires shells, so its fire_ms must be at least 50"), error)
	error = _error_after(func(_rules: Dictionary, buildings: Dictionary) -> void:
		buildings["mortar"]["levels"][0].erase("fire_ms"))
	assert_true(error.contains("mortar level 1 fires shells, so its fire_ms must be at least 50"), error)
	error = _error_after(func(_rules: Dictionary, buildings: Dictionary) -> void:
		buildings["mortar"]["levels"][0]["fire_ms"] = 50)
	assert_eq(error, "")


func test_shipped_battle_data() -> void:
	# Every building that can be hit has a hull; every special carries its fields at every level.
	var catalog := Catalog.load_default()
	assert_eq(catalog.load_error, "")
	assert_true(catalog.battle_seconds > 0)
	assert_eq(catalog.battle_class(catalog.wall_type), Catalog.CLASS_WALL)
	for res: String in catalog.resources:
		assert_true(catalog.loot_pct(res) > 0, "loot_pct.%s" % res)
	var specials := {
		"plasma_mortar": ["splash_units", "shell_ms"], "orbital_cannon": ["splash_units", "shell_ms"],
		"shield_generator": ["shield_hp", "shield_regen", "shield_delay_ms"],
		"gravity_well": ["hold_ms", "fire_ms"], "emp_tower": ["stun_ms"], "grav_trap": ["throw_cells"],
	}
	for type: String in catalog.types():
		var trap := catalog.battle_class(type) == Catalog.CLASS_TRAP
		for level: int in range(1, catalog.max_level(type) + 1):
			var stats := catalog.level_stats(type, level)
			if not trap:
				assert_true(int(stats.get("hp", 0)) > 0, "%s level %d has hp" % [type, level])
			for field: String in specials.get(type, []):
				assert_true(int(stats.get(field, 0)) > 0, "%s level %d has %s" % [type, level, field])
			if catalog.targets_of(type) != "" and type != "gravity_well" and type != "grav_trap":
				assert_true(int(stats.get("damage", 0)) > 0, "%s level %d has damage" % [type, level])


func test_expedition_rules_and_bands() -> void:
	var catalog := Fixtures.expedition_catalog()
	assert_eq(catalog.load_error, "")
	assert_eq(catalog.scan_seconds, 60)
	assert_eq(catalog.expedition_field_count(), 6)
	var bands := PackedStringArray()
	for index: int in 6:
		bands.append(str(catalog.expedition_band(index)["id"]))
	assert_eq(bands, PackedStringArray(["easy", "easy", "even", "even", "hard", "hard"]))
	assert_true(catalog.expedition_band(6).is_empty(), "no band past the last field")
	assert_true(catalog.expedition_band(-1).is_empty(), "no band before the first")
	assert_eq(catalog.expedition_band(4)["cc_offset"], 1)


func test_no_expedition_rules_is_no_fields() -> void:
	var catalog := Fixtures.catalog()
	assert_eq(catalog.load_error, "")
	assert_eq(catalog.expedition_field_count(), 0)
	assert_eq(catalog.scan_seconds, 0)
	assert_true(catalog.expedition_band(0).is_empty())


func test_validation_reports_bad_expedition_rules() -> void:
	var cases := {
		"rules.expedition must be an object": func(rules: Dictionary) -> void:
			rules["expedition"] = 6,
		"rules.expedition.scan_seconds must be a whole number of at least 0": func(rules: Dictionary) -> void:
			rules["expedition"]["scan_seconds"] = -1,
		"rules.expedition.margin must be a whole number of at least 1": func(rules: Dictionary) -> void:
			rules["expedition"]["margin"] = 0,
		"rules.expedition.margin leaves no room on the grid": func(rules: Dictionary) -> void:
			rules["expedition"]["margin"] = 20,
		"rules.expedition.wall_gap_cells must be a whole number of at least 1": func(rules: Dictionary) -> void:
			rules["expedition"]["wall_gap_cells"] = 0,
		"rules.expedition.slack_pct must be a whole number of at least 100": func(rules: Dictionary) -> void:
			rules["expedition"]["slack_pct"] = 90,
		"rules.expedition.bands must be a non-empty list": func(rules: Dictionary) -> void:
			rules["expedition"]["bands"] = [],
		"rules.expedition.bands ids must be unique and not empty": func(rules: Dictionary) -> void:
			rules["expedition"]["bands"][1]["id"] = "easy",
		"rules.expedition band 'even'.fields must be at least 1": func(rules: Dictionary) -> void:
			rules["expedition"]["bands"][1]["fields"] = 0,
		"rules.expedition band 'hard'.cc_offset must be a whole number": func(rules: Dictionary) -> void:
			rules["expedition"]["bands"][2]["cc_offset"] = 0.5,
		"rules.expedition band 'easy'.level_offset must be a whole number, 0 or less": func(rules: Dictionary) -> void:
			rules["expedition"]["bands"][0]["level_offset"] = 1,
		"rules.expedition band 'even'.density_pct must be a whole percent, 0-100": func(rules: Dictionary) -> void:
			rules["expedition"]["bands"][1]["density_pct"] = 120,
		"rules.expedition band 'hard'.loot_pct must be a whole percent, 0-100": func(rules: Dictionary) -> void:
			rules["expedition"]["bands"][2]["loot_pct"] = -5,
		"rules.expedition band 'easy'.deposits must be whole and non-negative": func(rules: Dictionary) -> void:
			rules["expedition"]["bands"][0]["deposits"] = -1,
	}
	for message: String in cases:
		var catalog := Fixtures.expedition_catalog(cases[message])
		assert_true(catalog.load_error.contains(message), "%s: %s" % [message, catalog.load_error])
		assert_eq(catalog.expedition_field_count(), 0, "%s: a refused block gives no fields" % message)


func test_shipped_expedition_rules() -> void:
	var catalog := Catalog.load_default()
	assert_eq(catalog.load_error, "")
	assert_eq(catalog.expedition_field_count(), 6)
	assert_true(catalog.scan_seconds > 0)


func test_validation_reports_bad_menu_order() -> void:
	var error := _error_after(func(rules: Dictionary, _buildings: Dictionary) -> void:
		rules["menu_order"].erase("wall"))
	assert_true(error.contains("menu_order is missing 'wall'"), error)
	error = _error_after(func(rules: Dictionary, _buildings: Dictionary) -> void:
		rules["menu_order"].append("silo"))
	assert_true(error.contains("menu_order lists 'silo' twice"), error)
	error = _error_after(func(rules: Dictionary, _buildings: Dictionary) -> void:
		rules["menu_order"].append(Catalog.HQ_TYPE))
	assert_true(error.contains("menu_order must not list 'command_center'"), error)


func test_validation_reports_start_level_out_of_range() -> void:
	var error := _error_after(func(rules: Dictionary, _buildings: Dictionary) -> void:
		rules["start"]["buildings"][1]["level"] = 2)
	assert_true(error.contains("start lists drone_bay at level 2, outside 1-1"), error)


func test_validation_reports_rules_of_the_wrong_shape() -> void:
	var cases := {
		"rules.resources must be a list": func(rules: Dictionary, _buildings: Dictionary) -> void:
			rules["resources"] = "metal",
		"rules.categories must be a list": func(rules: Dictionary, _buildings: Dictionary) -> void:
			rules["categories"] = {"id": "army"},
		"rules.grid needs a positive width and height": func(rules: Dictionary, _buildings: Dictionary) -> void:
			rules["grid"] = [10, 10],
		"rules.menu_order must be a list": func(rules: Dictionary, _buildings: Dictionary) -> void:
			rules["menu_order"] = null,
		"menu_order lists unknown type '[1, 2]'": func(rules: Dictionary, _buildings: Dictionary) -> void:
			rules["menu_order"].append([1, 2]),
		"rules.start must be an object": func(rules: Dictionary, _buildings: Dictionary) -> void:
			rules["start"] = [],
		"rules.start.resources must be an object": func(rules: Dictionary, _buildings: Dictionary) -> void:
			rules["start"]["resources"] = [500],
		"rules.start.buildings must be a list": func(rules: Dictionary, _buildings: Dictionary) -> void:
			rules["start"]["buildings"] = null,
	}
	for message: String in cases:
		var error := _error_after(cases[message])
		assert_true(error.contains(message), "%s: %s" % [message, error])


func test_validation_reports_start_entries_of_the_wrong_shape() -> void:
	var cases := {
		"rules.start.buildings[1] must be an object": func(rules: Dictionary, _buildings: Dictionary) -> void:
			rules["start"]["buildings"][1] = "drone_bay",
		"rules.start.buildings[1].cell must be [x, y]": func(rules: Dictionary, _buildings: Dictionary) -> void:
			rules["start"]["buildings"][1]["cell"] = [3],
		"start lists drone_bay at level [1], outside 1-1": func(rules: Dictionary, _buildings: Dictionary) -> void:
			rules["start"]["buildings"][1]["level"] = [1],
		"rules.start.resources.metal must be whole and non-negative": func(rules: Dictionary, _buildings: Dictionary) -> void:
			rules["start"]["resources"]["metal"] = [500],
	}
	for message: String in cases:
		var error := _error_after(cases[message])
		assert_true(error.contains(message), "%s: %s" % [message, error])


func test_validation_reports_types_of_the_wrong_shape() -> void:
	var cases := {
		"silo must be an object": func(_rules: Dictionary, buildings: Dictionary) -> void:
			buildings["silo"] = "big",
		"silo.size must be 1-8": func(_rules: Dictionary, buildings: Dictionary) -> void:
			buildings["silo"]["size"] = [2],
		"silo.levels must be a list": func(_rules: Dictionary, buildings: Dictionary) -> void:
			buildings["silo"]["levels"] = {"cost": {}},
		"silo.max_count must be a list": func(_rules: Dictionary, buildings: Dictionary) -> void:
			buildings["silo"]["max_count"] = 2,
		"command_center.levels must be a list": func(_rules: Dictionary, buildings: Dictionary) -> void:
			buildings[Catalog.HQ_TYPE]["levels"] = "two",
	}
	for message: String in cases:
		var error := _error_after(cases[message])
		assert_true(error.contains(message), "%s: %s" % [message, error])


func test_validation_reports_levels_of_the_wrong_shape() -> void:
	var cases := {
		"extractor level 1 must be an object": func(_rules: Dictionary, buildings: Dictionary) -> void:
			buildings["extractor"]["levels"][0] = 60,
		"extractor level 2 must be an object": func(_rules: Dictionary, buildings: Dictionary) -> void:
			buildings["extractor"]["levels"][1] = [],
		"extractor level 1.requires_cc must be 1-2": func(_rules: Dictionary, buildings: Dictionary) -> void:
			buildings["extractor"]["levels"][0]["requires_cc"] = [1],
		"extractor level 1.cost must be an object": func(_rules: Dictionary, buildings: Dictionary) -> void:
			buildings["extractor"]["levels"][0]["cost"] = 100,
		"extractor level 1.produces must be an object": func(_rules: Dictionary, buildings: Dictionary) -> void:
			buildings["extractor"]["levels"][0]["produces"] = [],
		"extractor level 1.storage must be an object": func(_rules: Dictionary, buildings: Dictionary) -> void:
			buildings["extractor"]["levels"][0]["storage"] = "none",
	}
	for message: String in cases:
		var error := _error_after(cases[message])
		assert_true(error.contains(message), "%s: %s" % [message, error])


## Storage of `res` a base can reach at Command Center level `cc`.
static func _reachable_storage(catalog: Catalog, res: String, cc: int) -> int:
	var total := _amount(catalog.level_stats(Catalog.HQ_TYPE, cc), "storage", res)
	for type: String in catalog.types():
		if type == Catalog.HQ_TYPE:
			continue
		var best := 0
		for level: int in range(1, catalog.max_level(type) + 1):
			var stats := catalog.level_stats(type, level)
			if int(stats.get("requires_cc", 1)) <= cc:
				best = maxi(best, _amount(stats, "storage", res))
		total += catalog.max_count(type, cc) * best
	return total


## The Command Center level a building type's `level` requires.
static func _requires_cc(catalog: Catalog, type: String, level: int) -> int:
	return int(catalog.level_stats(type, level).get("requires_cc", 1))


## The army housing a base can have at a Command Center level: every allowed housing building at
## its best allowed level.
static func _reachable_housing(catalog: Catalog, cc: int) -> int:
	var best := 0
	for level: int in range(1, catalog.max_level(catalog.housing_type) + 1):
		var stats := catalog.level_stats(catalog.housing_type, level)
		if int(stats.get("requires_cc", 1)) <= cc:
			best = maxi(best, int(stats.get("capacity", 0)))
	return catalog.max_count(catalog.housing_type, cc) * best


static func _amount(stats: Dictionary, field: String, res: String) -> int:
	var amounts: Dictionary = stats.get(field, {})
	return int(amounts.get(res, 0))


## Loads the fixture data with one change made to its parsed JSON; returns the load error.
func _error_after(change: Callable) -> String:
	var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Fixtures.RULES))
	var buildings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Fixtures.BUILDINGS))
	change.call(rules, buildings)
	return Catalog.from_json(JSON.stringify(rules), JSON.stringify(buildings),
		FileAccess.get_file_as_string(Fixtures.UNITS)).load_error


## The same with one change made to the fixture rules and units; returns the load error.
func _unit_error_after(change: Callable) -> String:
	var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Fixtures.RULES))
	var units: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Fixtures.UNITS))
	change.call(rules, units)
	return Catalog.from_json(JSON.stringify(rules), FileAccess.get_file_as_string(Fixtures.BUILDINGS),
		JSON.stringify(units)).load_error


## The same with one change made to the fixture rules and abilities; returns the load error.
func _ability_error_after(change: Callable) -> String:
	var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Fixtures.RULES))
	var abilities: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Fixtures.ABILITIES))
	change.call(rules, abilities)
	return Catalog.from_json(JSON.stringify(rules), FileAccess.get_file_as_string(Fixtures.BUILDINGS),
		FileAccess.get_file_as_string(Fixtures.UNITS), JSON.stringify(abilities)).load_error
