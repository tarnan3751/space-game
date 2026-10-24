class_name BattleMath
extends RefCounted
## Integer geometry for the battle sim (docs/reference/battle.md). Positions are field units,
## 1000 to a cell, so a cell's centre is cell * 1000 + 500. Distances are compared squared (the
## largest on a 48x48 field is 4.6e9, well inside 64 bits), and the one square root the sim
## needs, for moving along a line, is taken in integers, so no float enters a battle.

const CELL := 1000
const HALF := 500


## The centre of a cell along one axis, in field units.
static func centre(cell: int) -> int:
	return cell * CELL + HALF


## The largest integer whose square is at most `n` (0 for n <= 0).
static func isqrt(n: int) -> int:
	if n <= 0:
		return 0
	# Newton's method from above: any start at or over the root converges to it. The start is
	# the power of two with half n's bit length, rounded up, so it is at most twice the root and
	# even an air unit's whole distance to its target (up to about 4.6e9) takes a few steps.
	var x := 1
	var rest := n
	while rest > 0:
		rest >>= 2
		x <<= 1
	var y := (x + n / x) / 2
	while y < x:
		x = y
		y = (x + n / x) / 2
	return x


## A whole, non-negative number as an int (JSON's floats included); -1 for anything else.
static func whole(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		var number: int = value
		return number if number >= 0 else -1
	if typeof(value) == TYPE_FLOAT:
		var real: float = value
		if real == floorf(real) and real >= 0.0:
			return int(real)
	return -1


## A command's [x, y] (or a Vector2i) as a cell; (-1, -1) for anything else.
static func cell_from(value: Variant) -> Vector2i:
	if typeof(value) == TYPE_VECTOR2I:
		return value
	if typeof(value) == TYPE_ARRAY:
		var values: Array = value
		if values.size() == 2 and whole(values[0]) >= 0 and whole(values[1]) >= 0:
			return Vector2i(whole(values[0]), whole(values[1]))
	return Vector2i(-1, -1)


## The squared distance from (px, py) to the nearest point of the rectangle [x0, x1] x [y0, y1];
## 0 inside it.
static func dist2_to_rect(px: int, py: int, x0: int, y0: int, x1: int, y1: int) -> int:
	var dx := 0
	if px < x0:
		dx = x0 - px
	elif px > x1:
		dx = px - x1
	var dy := 0
	if py < y0:
		dy = y0 - py
	elif py > y1:
		dy = py - y1
	return dx * dx + dy * dy
