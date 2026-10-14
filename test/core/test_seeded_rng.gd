extends TestCase
## The generator must produce the same numbers everywhere, forever: saved seeds
## and server-side verification depend on it. Never change these expected values.


func test_known_sequence() -> void:
	var rng := SeededRng.new(1)
	var expected := [270369, 67634689, 2647435461, 307599695, 2398689233]
	for value: int in expected:
		assert_eq(rng.next_u32(), value)


func test_same_seed_same_sequence() -> void:
	var a := SeededRng.new(12345)
	var b := SeededRng.new(12345)
	assert_eq(a.next_u32(), 3336926330)
	assert_eq(b.next_u32(), 3336926330)
	assert_eq(a.next_u32(), b.next_u32())


func test_range_int_stays_in_bounds() -> void:
	var rng := SeededRng.new(99)
	for i: int in 1000:
		var value := rng.range_int(-3, 4)
		assert_true(value >= -3 and value <= 4, "value %d out of range" % value)


func test_zero_seed_still_works() -> void:
	var rng := SeededRng.new(0)
	assert_true(rng.next_u32() != 0)
