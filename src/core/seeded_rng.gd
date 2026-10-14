class_name SeededRng
extends RefCounted
## Deterministic 32-bit xorshift generator.
## Use this (never randi()/randf()) for anything the server must reproduce exactly:
## procedural expedition fields, battle rolls. Same seed => same sequence on every device.

const MASK_32 := 0xFFFFFFFF

var state: int


func _init(seed_value: int) -> void:
	state = seed_value & MASK_32
	if state == 0:
		state = 0x9E3779B9


## Next value in [0, 2^32).
func next_u32() -> int:
	var x := state
	x ^= (x << 13) & MASK_32
	x ^= x >> 17
	x ^= (x << 5) & MASK_32
	state = x
	return x


## Integer in [low, high], both inclusive. Slight modulo bias is fine for gameplay.
func range_int(low: int, high: int) -> int:
	if high <= low:
		return low
	return low + next_u32() % (high - low + 1)


## True with probability numerator/denominator, using integers only.
func chance(numerator: int, denominator: int) -> bool:
	return range_int(0, denominator - 1) < numerator
