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


## Loads the fixture data with one change made to its parsed JSON; returns the load error.
func _error_after(change: Callable) -> String:
	var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Fixtures.RULES))
	var buildings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Fixtures.BUILDINGS))
	change.call(rules, buildings)
	return Catalog.from_json(JSON.stringify(rules), JSON.stringify(buildings)).load_error
