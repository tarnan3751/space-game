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
## A search can be run in slices: begin() starts it and advance() settles at most a given number
## of cells, so BattleArmy can spread one over several ticks under rules.battle.search_cells. One
## search is in flight at a time, since the buffers are shared. A search in flight sees the field
## and the maps as they are when it settles each cell: a fall between two slices opens cells
## (which only the cells not yet settled reach) and takes counts off the maps, so the path is
## still walkable and the search goes on. abandon() drops it, for a set left with nothing standing.
##
## "In reach" comes from a reach map: per cell, how many standing candidates of a set (SET_*)
## lie within a reach of that cell's centre. One map per (set, reach) pair is built the first
## time it is asked for (BattleArmy asks for every one its ground units can need at setup, so no
## tick builds one), and kept up to date as buildings fall or are revealed, about a hundred cells
## each. The maps live side by side in one array of this object's own, so updating
## one never copies it.
##
## The search and the maps run on the field grown by a border of closed cells, so a step needs
## no bounds check; a cell keeps its order there, so ties break as they do on the field.
##
## nearest() is the air units' pick: the nearest standing candidate of a set by straight distance,
## read from a list of each set's members built here, so it never looks at the walls or traps of
## a set without them.

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

## Searches begun, and cells settled by every search, for the tests and the tools.
var searches: int = 0
var settled: int = 0
## The building the last finished search picked, -1 when it found none, and its path. While a
## search is in flight, `found` is its pick so far.
var found: int = -1
var path: PackedInt32Array = PackedInt32Array()
## A search in flight: begun and not finished; its start cell (on the field) and map.
var searching: bool = false
var search_cell: int = -1
var search_map: int = -1

var _field: BattleField
var _layout: BattleLayout
var _wall_cost: int
var _cells: int
## The search runs on the field grown by a border of closed cells, `_pw` wide, so a step needs no
## bounds check: a cell (x, y) is (y + 1) * _pw + x + 1 there, in the same order as on the field,
## so the heap breaks ties the same way. `_kind` is the field's kind in that grid, the border
## BUILDING, kept up to date as buildings fall. The reach maps use the grid too.
var _pw: int
var _pcells: int
var _kind: PackedByteArray = PackedByteArray()
## The neighbour offsets in that grid, in DX/DY's order, and a diagonal's two side cells.
var _step_to: PackedInt32Array = PackedInt32Array()
var _side_x: PackedInt32Array = PackedInt32Array()
var _side_y: PackedInt32Array = PackedInt32Array()
## The reach maps, map m at [m * _pcells, (m + 1) * _pcells); their set and reach.
var _reach: PackedInt32Array = PackedInt32Array()
var _map_set: PackedInt32Array = PackedInt32Array()
var _map_reach: PackedInt32Array = PackedInt32Array()
## Each map's members, the buildings that are or may become its candidates (the unrevealed
## ones too, for the sets a reveal joins), in index order: map m's at [_member_start[m],
## _member_start[m + 1]) of _members.
var _members: PackedInt32Array = PackedInt32Array()
var _member_start: PackedInt32Array = PackedInt32Array([0])
## Each set's members, as _members is each map's: set s's at [_set_start[s], _set_start[s + 1])
## of _set_members, in index order.
var _set_members: PackedInt32Array = PackedInt32Array()
var _set_start: PackedInt32Array = PackedInt32Array([0])
## Search buffers, reused: a cell's cost and parent are valid when its stamp is the search's.
var _cost: PackedInt32Array = PackedInt32Array()
var _parent: PackedInt32Array = PackedInt32Array()
var _seen: PackedInt32Array = PackedInt32Array()
var _done: PackedInt32Array = PackedInt32Array()
var _heap: PackedInt64Array = PackedInt64Array()
var _heap_size: int = 0
## The search in flight's stamp (the cells it has seen and settled carry it), the cells it has
## settled, and its goal so far: the cell, -1 for none yet, and its cost.
var _search_stamp: int = 0
var _search_settled: int = 0
var _goal: int = -1
var _goal_cost: int = -1


func _init(field: BattleField, layout: BattleLayout, wall_cost: int) -> void:
	_field = field
	_layout = layout
	_wall_cost = wall_cost
	_cells = field.width * field.height
	_pw = field.width + 2
	_pcells = _pw * (field.height + 2)
	_kind.resize(_pcells)
	_kind.fill(BattleField.BUILDING)
	for y: int in field.height:
		for x: int in field.width:
			_kind[(y + 1) * _pw + x + 1] = field.kind[y * field.width + x]
	for d: int in 8:
		var dx: int = DX[d]
		var dy: int = DY[d]
		_step_to.append(dy * _pw + dx)
		_side_x.append(dx)
		_side_y.append(dy * _pw)
	_cost.resize(_pcells)
	_parent.resize(_pcells)
	_seen.resize(_pcells)
	_seen.fill(0)
	_done.resize(_pcells)
	_done.fill(0)
	# A cell is pushed at most once per neighbour that improves it.
	_heap.resize(_cells * 8 + 8)
	for set_id: int in SET_ANY_HIDDEN + 1:
		for b: int in layout.count:
			if _may_join(b, set_id):
				_set_members.append(b)
		_set_start.append(_set_members.size())


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
	_reach.resize((m + 1) * _pcells)
	for i: int in range(m * _pcells, (m + 1) * _pcells):
		_reach[i] = 0
	for b: int in _layout.count:
		if _may_join(b, set_id):
			_members.append(b)
		if is_candidate(b, set_id):
			_stamp(m, b, 1)
	_member_start.append(_members.size())
	return m


func map_set(m: int) -> int:
	return _map_set[m]


func map_count() -> int:
	return _map_set.size()


## How many candidates of map `m` are in reach of `cell`.
func reach_count(m: int, cell: int) -> int:
	return _reach[m * _pcells + _grown(cell)]


## Building `b` has fallen: its cells take the field's kind again, and it leaves every map it
## was in.
func building_fell(b: int) -> void:
	var width := _field.width
	for y: int in range(_layout.cell_y[b], _layout.cell_y[b] + _layout.sizes[b]):
		for x: int in range(_layout.cell_x[b], _layout.cell_x[b] + _layout.sizes[b]):
			_kind[(y + 1) * _pw + x + 1] = _field.kind[y * width + x]
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


## The standing candidate of a set nearest to a point, by the squared distance to its footprint,
## then the lowest index; -1 when none stands. is_candidate and BattleMath.dist2_to_rect, written
## out over the set's members.
func nearest(px: int, py: int, set_id: int) -> int:
	var seen_only := set_id == SET_ANY or set_id == SET_DEFENSE or set_id == SET_RESOURCE
	var destroyed := _layout.destroyed
	var revealed := _layout.revealed
	var x0 := _layout.x0
	var y0 := _layout.y0
	var x1 := _layout.x1
	var y1 := _layout.y1
	var best := -1
	var best_d2 := 0
	for i: int in range(_set_start[set_id], _set_start[set_id + 1]):
		var b := _set_members[i]
		if destroyed[b] != 0 or (seen_only and revealed[b] == 0):
			continue
		var dx := 0
		if px < x0[b]:
			dx = x0[b] - px
		elif px > x1[b]:
			dx = px - x1[b]
		var dy := 0
		if py < y0[b]:
			dy = y0[b] - py
		elif py > y1[b]:
			dy = py - y1[b]
		var d2 := dx * dx + dy * dy
		if best < 0 or d2 < best_d2:
			best = b
			best_d2 = d2
	return best


## The cheapest path from `start` to a cell where map `m` has a candidate in reach, as cell
## indices from `start` to that cell, and in `found` the candidate: the nearest in reach of that
## cell, then the lowest id. When several cells tie for the cheapest, the one whose candidate has
## the lowest id wins. Empty (and found -1) when there is none. Walls on the path are walked
## through at their cost; the caller decides to break them. The whole search at once, begin()
## and advance() with no limit: never while a search is in flight.
func find(start: int, m: int) -> PackedInt32Array:
	begin(start, m)
	advance(_pcells)
	return path


## Starts a search from `start` on map `m`; advance() runs it. Never while one is in flight.
func begin(start: int, m: int) -> void:
	searches += 1
	_search_stamp = searches
	searching = true
	search_cell = start
	search_map = m
	_search_settled = 0
	_goal = -1
	_goal_cost = -1
	found = -1
	path = PackedInt32Array()
	var first := _grown(start)
	_heap_size = 0
	_seen[first] = _search_stamp
	_cost[first] = 0
	_parent[first] = -1
	_push_key(first)


## Drops the search in flight: nothing is in flight after it, and it found nothing.
func abandon() -> void:
	searching = false
	found = -1
	path = PackedInt32Array()


## Runs the search in flight until it is done or has settled `cells` more cells; returns how many
## it settled. When it is done, `searching` is false and `found` and `path` hold its result. A
## search ends the moment nothing is left to settle at or below its goal's cost, so one that has
## settled its last cell is not left in flight for the next slice.
func advance(cells: int) -> int:
	var stamp := _search_stamp
	var kind := _kind
	var reach := _reach
	var step_to := _step_to
	var side_x := _side_x
	var side_y := _side_y
	var pcells := _pcells
	var m := search_map
	var offset := m * pcells
	var goal := _goal
	var goal_cost := _goal_cost
	var used := 0
	var done := false
	while true:
		if _heap_size == 0:
			done = true
			break
		var key := _heap[0]
		var cell := key % pcells
		var cost := key / pcells
		if goal >= 0 and cost > goal_cost:
			done = true
			break
		if _done[cell] == stamp:
			_pop()
			continue
		if used >= cells:
			break
		_pop()
		_done[cell] = stamp
		used += 1
		if reach[offset + cell] > 0:
			# A map is current after every fall passed on; one this tick has not passed on yet
			# leaves a count with nothing standing behind it, and the search goes on.
			var pick := _pick_at(_shrunk(cell), m)
			if pick >= 0:
				if goal < 0 or pick < found:
					goal = cell
					goal_cost = cost
					found = pick
				continue
		if goal >= 0:
			continue
		for d: int in 8:
			var next := cell + step_to[d]
			var next_kind := kind[next]
			if next_kind == BattleField.BUILDING or _done[next] == stamp:
				continue
			var step := STEP
			if d >= 4:
				if kind[cell + side_x[d]] != BattleField.FREE or kind[cell + side_y[d]] != BattleField.FREE:
					continue
				step = DIAGONAL
			if next_kind == BattleField.WALL:
				step += _wall_cost
			var next_cost := cost + step
			if _seen[next] != stamp or next_cost < _cost[next]:
				_seen[next] = stamp
				_cost[next] = next_cost
				_parent[next] = cell
				_push_key(next_cost * pcells + next)
	_goal = goal
	_goal_cost = goal_cost
	_search_settled += used
	settled += used
	if done:
		searching = false
		if goal >= 0:
			var at := goal
			while at >= 0:
				path.append(_shrunk(at))
				at = _parent[at]
			path.reverse()
	return used


## Mixes the search in flight into a state hash (BattleSim.state_hash): whether there is one, its
## start, its map and the cells it has settled.
func hash_into(h: int) -> int:
	h = BattleMath.mix(h, 1 if searching else 0)
	if searching:
		h = BattleMath.mix(h, search_cell)
		h = BattleMath.mix(h, search_map)
		h = BattleMath.mix(h, _search_settled)
	return h


## A field cell's index in the grown grid, and back.
func _grown(cell: int) -> int:
	return (cell / _field.width + 1) * _pw + cell % _field.width + 1


func _shrunk(cell: int) -> int:
	return (cell / _pw - 1) * _field.width + cell % _pw - 1


## Whether building `b` is a member of a set or becomes one when revealed: is_member with every
## building taken as seen.
func _may_join(b: int, set_id: int) -> bool:
	var cls := _layout.classes[b]
	if cls == BattleLayout.TRAP:
		return false
	match set_id:
		SET_ANY, SET_ANY_HIDDEN:
			return cls != BattleLayout.WALL
		SET_DEFENSE:
			return cls == BattleLayout.DEFENSE
		SET_RESOURCE:
			return cls == BattleLayout.RESOURCE
		SET_HQ:
			return cls == BattleLayout.HQ
		SET_WALL:
			return cls == BattleLayout.WALL
	return false


## The nearest candidate of map `m`'s set in reach of a cell's centre, then the lowest index:
## is_candidate and the distance to each member's footprint, written out, since a search asks it
## of every cell in reach it settles at its goal's cost.
func _pick_at(cell: int, m: int) -> int:
	var set_id := _map_set[m]
	var seen_only := set_id == SET_ANY or set_id == SET_DEFENSE or set_id == SET_RESOURCE
	var px := BattleMath.centre(cell % _field.width)
	var py := BattleMath.centre(cell / _field.width)
	var r2 := _map_reach[m] * _map_reach[m]
	var destroyed := _layout.destroyed
	var revealed := _layout.revealed
	var x0 := _layout.x0
	var y0 := _layout.y0
	var x1 := _layout.x1
	var y1 := _layout.y1
	var best := -1
	var best_d2 := 0
	for i: int in range(_member_start[m], _member_start[m + 1]):
		var b := _members[i]
		if destroyed[b] != 0 or (seen_only and revealed[b] == 0):
			continue
		var dx := 0
		if px < x0[b]:
			dx = x0[b] - px
		elif px > x1[b]:
			dx = px - x1[b]
		var dy := 0
		if py < y0[b]:
			dy = y0[b] - py
		elif py > y1[b]:
			dy = py - y1[b]
		var d2 := dx * dx + dy * dy
		if d2 <= r2 and (best < 0 or d2 < best_d2):
			best = b
			best_d2 = d2
	return best


## Adds `delta` to map `m` on every cell whose centre is within its reach of building `b`'s
## footprint: per row, the cells whose centres lie within the row's span, the integer square
## root of what the reach leaves after the row's distance, so the test is exact.
func _stamp(m: int, b: int, delta: int) -> void:
	var r := _map_reach[m]
	var r2 := r * r
	var width := _field.width
	var bx0 := _layout.x0[b]
	var by0 := _layout.y0[b]
	var bx1 := _layout.x1[b]
	var by1 := _layout.y1[b]
	var top := maxi(0, (by0 - r) / BattleMath.CELL)
	var bottom := mini(_field.height - 1, (by1 + r) / BattleMath.CELL)
	var offset := m * _pcells + 1
	for y: int in range(top, bottom + 1):
		var py := BattleMath.centre(y)
		var dy := 0
		if py < by0:
			dy = by0 - py
		elif py > by1:
			dy = py - by1
		if dy > r:
			continue
		var span := BattleMath.isqrt(r2 - dy * dy)
		# The cells x with bx0 - span <= centre(x) <= bx1 + span.
		var low := bx0 - span - BattleMath.HALF
		var left := 0 if low <= 0 else (low + BattleMath.CELL - 1) / BattleMath.CELL
		var right := mini(width - 1, (bx1 + span - BattleMath.HALF) / BattleMath.CELL)
		var row := offset + (y + 1) * _pw
		for x: int in range(left, right + 1):
			_reach[row + x] += delta


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
