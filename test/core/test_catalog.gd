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


func test_validation_reports_unknown_resources() -> void:
	var rules := FileAccess.get_file_as_string(Fixtures.RULES)
	var buildings := '{"command_center": {"size": 2, "max_count": [1], "levels": [' \
		+ '{"cost": {"gold": 5}, "build_seconds": 0}]}}'
	var catalog := Catalog.from_json(rules, buildings)
	assert_true(catalog.load_error.contains("unknown resource 'gold'"), catalog.load_error)


func test_missing_files_report_an_error() -> void:
	var catalog := Catalog.from_json("", "")
	assert_false(catalog.load_error.is_empty())
