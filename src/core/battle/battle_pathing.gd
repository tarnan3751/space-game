class_name BattlePathing
extends RefCounted
## Ground pathing for the battle sim (docs/reference/battle.md, **Pathing**). Pure logic.
##
## One search finds a ground unit's target and its path together: Dijkstra over the cells from
## the unit's cell, an orthogonal step costing 1000 and a diagonal one 1414, a wall cell
## `wall_cost` more to enter, every other building's cells closed, and no diagonal step past a
## wall or a building at either side (no corner cutting). It stops at the first cell it settles
## from which a candidate building is in reach. Ties are settled by the heap's order, cost then
## cell index, so the result is the same everywhere.
##
## "In reach" comes from a reach map: per cell, how many standing candidates of a set (SET_*)
## lie within a reach of that cell's centre. One map per (set, reach) pair is built the first
## time a unit asks for it, and kept up to date as buildings fall or are revealed, about a
## hundred cells each. The maps live side by side in one array of this object's own, so updating
## one never copies it.

const SET_ANY := 0
const SET_DEFENSE := 1
const SET_RESOURCE := 2
const SET_HQ := 3
const SET_WALL := 4
## Every building but walls and traps, the unrevealed ones too: the last resort of a unit that
## finds nothing else standing.
const SET_ANY_HIDDEN := 5

const STEP := 1000
const DIAGONAL := 1414
## Neighbour offsets, in a fixed order: the four orthogonal ones, then the diagonals.
const DX := [1, -1, 0, 0, 1, 1, -1, -1]
const DY := [0, 0, 1, -1, 1, -1, 1, -1]

## Searches run, for the budget and the tests.
var searches: int = 0
## The building the last find() picked, -1 when it found none.
var found: int = -1

var _field: BattleField
var _layout: BattleLayout
var _wall_cost: int
var _cells: int
## The reach maps, map m at [m * _cells, (m + 1) * _cells); their set and reach.
var _reach: PackedInt32Array = PackedInt32Array()
var _map_set: PackedInt32Array = PackedInt32Array()
var _map_reach: PackedInt32Array = PackedInt32Array()
## Search buffers, reused: a cell's cost and parent are valid when its stamp is the search's.
var _cost: PackedInt32Array = PackedInt32Array()
var _parent: PackedInt32Array = PackedInt32Array()
var _seen: PackedInt32Array = PackedInt32Array()
var _done: PackedInt32Array = PackedInt32Array()
var _heap: PackedInt64Array = PackedInt64Array()
var _heap_size: int = 0


func _init(field: BattleField, layout: BattleLayout, wall_cost: int) -> void:
	_field = field
	_layout = layout
	_wall_cost = wall_cost
	_cells = field.width * field.height
	_cost.resize(_cells)
	_parent.resize(_cells)
	_seen.resize(_cells)
	_seen.fill(0)
	_done.resize(_cells)
	_done.fill(0)
	# A cell is pushed at most once per neighbour that improves it.
	_heap.resize(_cells * 8 + 8)


## Whether building `b` belongs to a set, standing or not.
func is_member(b: int, set_id: int) -> bool:
	var cls := _layout.classes[b]
	if cls == BattleLayout.TRAP:
		return false
	match set_id:
		SET_ANY:
			return cls != BattleLayout.WALL and _layout.revealed[b] != 0
		SET_DEFENSE:
			return cls == BattleLayout.DEFENSE and _layout.revealed[b] != 0
		SET_RESOURCE:
			return cls == BattleLayout.RESOURCE and _layout.revealed[b] != 0
		SET_HQ:
			return cls == BattleLayout.HQ
		SET_WALL:
			return cls == BattleLayout.WALL
		SET_ANY_HIDDEN:
			return cls != BattleLayout.WALL
	return false


## A standing candidate of the set.
func is_candidate(b: int, set_id: int) -> bool:
	return _layout.destroyed[b] == 0 and is_member(b, set_id)


## The reach map of (set, reach), built on first use.
func map_for(set_id: int, reach: int) -> int:
	for m: int in _map_set.size():
		if _map_set[m] == set_id and _map_reach[m] == reach:
			return m
	var m := _map_set.size()
	_map_set.append(set_id)
	_map_reach.append(reach)
	_reach.resize((m + 1) * _cells)
	for i: int in range(m * _cells, (m + 1) * _cells):
		_reach[i] = 0
	for b: int in _layout.count:
		if is_candidate(b, set_id):
			_stamp(m, b, 1)
	return m


func map_set(m: int) -> int:
	return _map_set[m]


func map_count() -> int:
	return _map_set.size()


## How many candidates of map `m` are in reach of `cell`.
func reach_count(m: int, cell: int) -> int:
	return _reach[m * _cells + cell]


## Building `b` has fallen: it leaves every map it was in.
func building_fell(b: int) -> void:
	for m: int in _map_set.size():
		if is_member(b, _map_set[m]):
			_stamp(m, b, -1)


## Building `b` has been revealed: it joins the maps of the sets that wanted it seen.
func building_revealed(b: int) -> void:
	if _layout.destroyed[b] != 0:
		return
	for m: int in _map_set.size():
		var set_id := _map_set[m]
		if (set_id == SET_ANY or set_id == SET_DEFENSE) and is_member(b, set_id):
			_stamp(m, b, 1)


## The cheapest path from `start` to a cell where map `m` has a candidate in reach, as cell
## indices from `start` to that cell, and in `found` the candidate: the nearest in reach of that
## cell, then the lowest id. When several cells tie for the cheapest, the one whose candidate has
## the lowest id wins. Empty (and found -1) when there is none. Walls on the path are walked
## through at their cost; the caller decides to break them.
func find(start: int, m: int) -> PackedInt32Array:
	searches += 1
	var stamp := searches
	var kind := _field.kind
	var width := _field.width
	var height := _field.height
	var offset := m * _cells
	_heap_size = 0
	_seen[start] = stamp
	_cost[start] = 0
	_parent[start] = -1
	_push_key(start)
	var goal := -1
	var goal_cost := -1
	found = -1
	while _heap_size > 0:
		var key := _pop()
		var cell := key % _cells
		var cost := key / _cells
		if goal >= 0 and cost > goal_cost:
			break
		if _done[cell] == stamp:
			continue
		_done[cell] = stamp
		if _reach[offset + cell] > 0:
			# A map is current after every fall passed on; one this tick has not passed on yet
			# leaves a count with nothing standing behind it, and the search goes on.
			var pick := _pick_at(cell, m)
			if pick >= 0:
				if goal < 0 or pick < found:
					goal = cell
					goal_cost = cost
					found = pick
				continue
		if goal >= 0:
			continue
		var x := cell % width
		var y := cell / width
		for d: int in 8:
			var dx: int = DX[d]
			var dy: int = DY[d]
			var nx := x + dx
			var ny := y + dy
			if nx < 0 or ny < 0 or nx >= width or ny >= height:
				continue
			var next := ny * width + nx
			var next_kind := kind[next]
			if next_kind == BattleField.BUILDING or _done[next] == stamp:
				continue
			var step := STEP
			if d >= 4:
				if kind[y * width + nx] != BattleField.FREE or kind[ny * width + x] != BattleField.FREE:
					continue
				step = DIAGONAL
			if next_kind == BattleField.WALL:
				step += _wall_cost
			var next_cost := cost + step
			if _seen[next] != stamp or next_cost < _cost[next]:
				_seen[next] = stamp
				_cost[next] = next_cost
				_parent[next] = cell
				_push_key(next_cost * _cells + next)
	var path := PackedInt32Array()
	if goal < 0:
		return path
	var at := goal
	while at >= 0:
		path.append(at)
		at = _parent[at]
	path.reverse()
	return path


## The nearest candidate of map `m`'s set in reach of a cell's centre, then the lowest index.
func _pick_at(cell: int, m: int) -> int:
	var set_id := _map_set[m]
	var px := BattleMath.centre(cell % _field.width)
	var py := BattleMath.centre(cell / _field.width)
	var r2 := _map_reach[m] * _map_reach[m]
	var best := -1
	var best_d2 := 0
	for b: int in _layout.count:
		if not is_candidate(b, set_id):
			continue
		var d2 := BattleMath.dist2_to_rect(px, py, _layout.x0[b], _layout.y0[b], _layout.x1[b],
			_layout.y1[b])
		if d2 <= r2 and (best < 0 or d2 < best_d2):
			best = b
			best_d2 = d2
	return best


func _stamp(m: int, b: int, delta: int) -> void:
	var r := _map_reach[m]
	var r2 := r * r
	var width := _field.width
	var left := maxi(0, (_layout.x0[b] - r) / BattleMath.CELL)
	var top := maxi(0, (_layout.y0[b] - r) / BattleMath.CELL)
	var right := mini(width - 1, (_layout.x1[b] + r) / BattleMath.CELL)
	var bottom := mini(_field.height - 1, (_layout.y1[b] + r) / BattleMath.CELL)
	var bx0 := _layout.x0[b]
	var by0 := _layout.y0[b]
	var bx1 := _layout.x1[b]
	var by1 := _layout.y1[b]
	var offset := m * _cells
	for y: int in range(top, bottom + 1):
		var py := BattleMath.centre(y)
		for x: int in range(left, right + 1):
			if BattleMath.dist2_to_rect(BattleMath.centre(x), py, bx0, by0, bx1, by1) <= r2:
				_reach[offset + y * width + x] += delta


## A binary min-heap of cost * cells + cell.
func _push_key(key: int) -> void:
	var i := _heap_size
	_heap_size += 1
	while i > 0:
		var parent := (i - 1) / 2
		if _heap[parent] <= key:
			break
		_heap[i] = _heap[parent]
		i = parent
	_heap[i] = key


func _pop() -> int:
	var top := _heap[0]
	_heap_size -= 1
	var last := _heap[_heap_size]
	var i := 0
	while true:
		var child := i * 2 + 1
		if child >= _heap_size:
			break
		if child + 1 < _heap_size and _heap[child + 1] < _heap[child]:
			child += 1
		if _heap[child] >= last:
			break
		_heap[i] = _heap[child]
		i = child
	_heap[i] = last
	return top
