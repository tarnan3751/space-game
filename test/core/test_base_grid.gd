extends TestCase


func test_bounds() -> void:
	var grid := BaseGrid.new(10, 8)
	assert_true(grid.in_bounds(Vector2i(0, 0), 3))
	assert_true(grid.in_bounds(Vector2i(7, 5), 3))
	assert_false(grid.in_bounds(Vector2i(8, 5), 3))
	assert_false(grid.in_bounds(Vector2i(-1, 0), 1))


func test_occupy_and_vacate() -> void:
	var grid := BaseGrid.new(10, 10)
	grid.occupy(7, Vector2i(2, 2), 2)
	assert_eq(grid.occupant_at(Vector2i(3, 3)), 7)
	assert_false(grid.is_free(Vector2i(3, 3), 2))
	assert_true(grid.is_free(Vector2i(3, 3), 2, 7), "own cells count as free")
	grid.vacate(Vector2i(2, 2), 2)
	assert_true(grid.is_free(Vector2i(2, 2), 2))
	assert_eq(grid.occupant_at(Vector2i(-5, 3)), 0)
