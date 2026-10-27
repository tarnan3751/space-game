class_name BattleArmy
extends RefCounted
## The attacker's units in a battle (docs/reference/battle.md): their stats, positions, targets
## and paths, and the unit phase of each tick. Pure logic.
##
## Units are indexed 0..count-1 in deploy order (a unit's id is its index + 1), so a tie broken
## by the lowest index is broken by the lowest id. The arrays are sized for the whole army at
## setup, so a tick allocates nothing but the paths it searches. Only this class writes them; the
## combat phase goes through damage_unit, stun, hold and throw_unit, and the abilities through
## damage_unit and heal.
##
## Each tick, in two halves (act, then aim_and_act, with the falls of the first passed on
## between them): a unit with a target walks or flies (a held unit does not) towards it and
## attacks it once in reach, every fire_ms; a unit whose target has fallen, or that has none,
## gets one and acts at once. Units go in id order in each half, and a stunned unit does nothing.

const IDLE := 0
const WALKING := 1
const ATTACKING := 2
const DEAD := 3
## unit_state's display states, over IDLE, WALKING and ATTACKING.
const STUNNED := 4
const HELD := 5

const TICK_MS := 50
## Ground searches a tick at most; units waiting for one are served in id order.
const PATHS_PER_TICK := 4
## No unit's reach is shorter than this, so a cell orthogonally next to a footprint is in reach.
const MIN_REACH := 500
## Unit buckets for the defences' nearest-unit search: cells per side.
const BUCKET_CELLS := 4

## Per unit type (index into type_names): stats at the attacker's level.
var type_names: PackedStringArray = PackedStringArray()
var _t_class: PackedInt32Array = PackedInt32Array()
var _t_speed: PackedInt32Array = PackedInt32Array()
var _t_hp: PackedInt32Array = PackedInt32Array()
var _t_damage: PackedInt32Array = PackedInt32Array()
var _t_fire_ms: PackedInt32Array = PackedInt32Array()
var _t_reach: PackedInt32Array = PackedInt32Array()
var _t_splash: PackedInt32Array = PackedInt32Array()
var _t_self_destruct: PackedByteArray = PackedByteArray()
var _t_set: PackedInt32Array = PackedInt32Array()
## Damage percent against each building class, BattleLayout.CLASS_COUNT per type.
var _t_pct: PackedInt32Array = PackedInt32Array()
## Units still to deploy, per type index.
var left: PackedInt32Array = PackedInt32Array()
var deployed: PackedInt32Array = PackedInt32Array()

var count: int = 0
var alive: int = 0
var unit_type: PackedInt32Array = PackedInt32Array()
## BattleLayout.GROUND or AIR.
var cls: PackedInt32Array = PackedInt32Array()
var x: PackedInt32Array = PackedInt32Array()
var y: PackedInt32Array = PackedInt32Array()
## The last move, not normalised; (0, 0) before the first.
var heading_x: PackedInt32Array = PackedInt32Array()
var heading_y: PackedInt32Array = PackedInt32Array()
var hp: PackedInt32Array = PackedInt32Array()
var state: PackedInt32Array = PackedInt32Array()
## Building index, -1 for none.
var target: PackedInt32Array = PackedInt32Array()
var cooldown: PackedInt32Array = PackedInt32Array()
## The unit is stunned (held) while the tick is below this.
var stun_until: PackedInt32Array = PackedInt32Array()
var hold_until: PackedInt32Array = PackedInt32Array()
## Movement in thousandths of a field unit, carried from tick to tick.
var _carry: PackedInt32Array = PackedInt32Array()
## 1 while the unit wants a target; 1 in _stuck when its last search found nothing.
var _wants: PackedByteArray = PackedByteArray()
var _stuck: PackedByteArray = PackedByteArray()
var _paths: Array[PackedInt32Array] = []
var _path_pos: PackedInt32Array = PackedInt32Array()

## Units by bucket, rebuilt each tick: the first unit of a bucket and the next in its bucket.
var bucket_head: PackedInt32Array = PackedInt32Array()
var bucket_next: PackedInt32Array = PackedInt32Array()
var buckets_wide: int = 0
var buckets_high: int = 0

## Standing candidates per BattlePathing set, for a unit's fallback.
var _standing: PackedInt32Array = PackedInt32Array()
## 1 per fallen building: the layout's flags, set by BattleCombat the moment a building falls
## (note_fallen), since reading this object's array is cheaper in the per-unit loop than reading
## another's.
var _down: PackedByteArray = PackedByteArray()

var _layout: BattleLayout
var _field: BattleField
var _width: int = 0
var _pathing: BattlePathing
## This tick's shared searches: the cell and map asked, and what they gave.
var _share_count: int = 0
var _share_cell: PackedInt32Array = PackedInt32Array()
var _share_map: PackedInt32Array = PackedInt32Array()
var _share_target: PackedInt32Array = PackedInt32Array()
var _share_path: Array[PackedInt32Array] = []


func _init(layout: BattleLayout, field: BattleField, pathing: BattlePathing) -> void:
	_layout = layout
	_field = field
	_width = field.width
	_pathing = pathing
	_down.resize(layout.count)
	_down.fill(0)
	_standing.resize(BattlePathing.SET_ANY_HIDDEN + 1)
	_standing.fill(0)
	for b: int in layout.count:
		for set_id: int in _standing.size():
			if pathing.is_member(b, set_id):
				_standing[set_id] += 1
	buckets_wide = (field.width + BUCKET_CELLS - 1) / BUCKET_CELLS
	buckets_high = (field.height + BUCKET_CELLS - 1) / BUCKET_CELLS
	bucket_head.resize(buckets_wide * buckets_high)
	bucket_head.fill(-1)


## Reads the attacker: {unit: count} and {unit: level} (a level is clamped into the unit's
## levels; 1 when left out). Returns "" or why it is refused, a total above BattleSim.MAX_UNITS
## included, checked before anything is sized by it. The unit types are taken in sorted
## order, whatever order the dictionary holds them in (a JSON round trip sorts it), so the type
## indices, and with them the whole battle and its hash, do not depend on it.
func setup(catalog: Catalog, army: Dictionary, unit_levels: Dictionary) -> String:
	var names: Array[String] = []
	for unit: Variant in army:
		names.append(str(unit))
	names.sort()
	var total := 0
	for name: String in names:
		if not catalog.has_unit(name):
			return "the attacker's army has unknown unit '%s'" % name
		var number := BattleMath.whole(army[name])
		if number < 0:
			return "the attacker's army has a bad count of %s" % name
		if number > BattleSim.MAX_UNITS - total:
			return "the attacker's army has more than %d units" % BattleSim.MAX_UNITS
		var level := clampi(BattleMath.whole(unit_levels.get(name, 1)), 1, catalog.unit_max_level(name))
		_add_type(catalog, name, level, number)
		total += number
	unit_type.resize(total)
	cls.resize(total)
	x.resize(total)
	y.resize(total)
	heading_x.resize(total)
	heading_y.resize(total)
	hp.resize(total)
	state.resize(total)
	target.resize(total)
	cooldown.resize(total)
	stun_until.resize(total)
	hold_until.resize(total)
	_carry.resize(total)
	_wants.resize(total)
	_stuck.resize(total)
	_path_pos.resize(total)
	_paths.resize(total)
	bucket_next.resize(total)
	# Every reach map a ground unit can ask for (_set_for: its set, then the two fallbacks, at
	# its reach), built now so that no tick pays for one.
	for t: int in type_names.size():
		if _t_class[t] == BattleLayout.GROUND and left[t] > 0:
			for set_id: int in [_t_set[t], BattlePathing.SET_ANY, BattlePathing.SET_ANY_HIDDEN]:
				_pathing.map_for(set_id, _t_reach[t])
	return ""


func type_index(unit: String) -> int:
	return type_names.find(unit)


func left_total() -> int:
	var total := 0
	for i: int in left.size():
		total += left[i]
	return total


## Places a unit of type index `t` at a cell's centre; returns its index.
func deploy(t: int, cell: Vector2i) -> int:
	var u := count
	count += 1
	alive += 1
	left[t] -= 1
	deployed[t] += 1
	unit_type[u] = t
	cls[u] = _t_class[t]
	x[u] = BattleMath.centre(cell.x)
	y[u] = BattleMath.centre(cell.y)
	heading_x[u] = 0
	heading_y[u] = 0
	hp[u] = _t_hp[t]
	state[u] = IDLE
	target[u] = -1
	cooldown[u] = 0
	stun_until[u] = 0
	hold_until[u] = 0
	_carry[u] = 0
	_wants[u] = 1
	_stuck[u] = 0
	_path_pos[u] = 0
	_paths[u] = PackedInt32Array()
	return u


func max_hp(u: int) -> int:
	return _t_hp[unit_type[u]]


## The unit phase's first half: every unit that has a target, in id order and unless stunned,
## walks, flies or attacks; one whose target has fallen drops it and wants another. BattleSim
## then passes the falls on, so the second half's searches see them.
func act(tick: int, combat: BattleCombat, events: BattleEvents) -> void:
	for u: int in count:
		var now_state := state[u]
		if now_state == DEAD or stun_until[u] > tick:
			continue
		var aim := target[u]
		# Most ticks of an attacking unit only count its cooldown down.
		if now_state == ATTACKING and cooldown[u] > TICK_MS and _down[aim] == 0:
			cooldown[u] -= TICK_MS
			continue
		if aim >= 0 and _down[aim] != 0:
			target[u] = -1
			state[u] = IDLE
			_wants[u] = 1
		if _wants[u] == 0:
			_act(u, tick, combat, events)


## The unit phase's second half: every unit that wants a target, in id order and unless
## stunned, gets one (a ground unit through BattlePathing, at most PATHS_PER_TICK searches, units
## of one type on one cell sharing a search; an air unit by straight distance) and acts on it at
## once. A target that falls in this half is noticed next tick.
func aim_and_act(tick: int, combat: BattleCombat, events: BattleEvents) -> void:
	_share_count = 0
	var budget := PATHS_PER_TICK
	for u: int in count:
		if _wants[u] == 0 or state[u] == DEAD or stun_until[u] > tick:
			continue
		if cls[u] == BattleLayout.AIR:
			_aim_air(u)
		else:
			budget = _aim_ground(u, budget)
		if _wants[u] == 0 and target[u] >= 0 and _down[target[u]] == 0:
			_act(u, tick, combat, events)


## One unit's move or attack this tick.
func _act(u: int, tick: int, combat: BattleCombat, events: BattleEvents) -> void:
	if target[u] < 0:
		return
	if state[u] == WALKING:
		if cls[u] == BattleLayout.AIR:
			if hold_until[u] <= tick:
				_fly(u)
			elif _in_air_reach(u):
				state[u] = ATTACKING
		else:
			_walk(u)
	if state[u] == ATTACKING:
		_attack(u, tick, combat, events)


## A building has fallen: the units whose last search found nothing look again. A unit after
## the fallen building notices in its next update; a path never runs through a wall (it stops
## at the first and attacks it), so no other path changes.
func building_fell(b: int) -> void:
	for u: int in count:
		if _stuck[u] != 0 and state[u] != DEAD:
			_stuck[u] = 0
			_wants[u] = 1


## The moment a building falls (BattleCombat calls it), so the units and their fallback see it
## at once.
func note_fallen(b: int) -> void:
	_down[b] = 1
	for set_id: int in _standing.size():
		if _pathing.is_member(b, set_id):
			_standing[set_id] -= 1


func building_revealed(b: int) -> void:
	for set_id: int in [BattlePathing.SET_ANY, BattlePathing.SET_DEFENSE]:
		if _pathing.is_member(b, set_id):
			_standing[set_id] += 1


## Takes `amount` off a unit's hull; returns true when that kills it.
func damage_unit(u: int, amount: int) -> bool:
	if state[u] == DEAD or amount <= 0:
		return false
	hp[u] -= amount
	if hp[u] > 0:
		return false
	hp[u] = 0
	_kill(u)
	return true


## Gives `amount` back to a living unit's hull, up to its type's.
func heal(u: int, amount: int) -> void:
	if state[u] == DEAD:
		return
	hp[u] = mini(max_hp(u), hp[u] + amount)


func stun(u: int, until: int) -> void:
	stun_until[u] = maxi(stun_until[u], until)


func hold(u: int, until: int) -> void:
	hold_until[u] = maxi(hold_until[u], until)


## Throws a ground unit up to `cells` cells away from (from_x, from_y)'s side: opposite to its
## heading, or away from that point when it has none, in one of the eight directions. It stops
## on the last free cell before a building, a wall or the field's edge, or before a diagonal step
## past one, lands on that cell's centre and looks for a target again.
func throw_unit(u: int, from_x: int, from_y: int, cells: int) -> void:
	var dx := -heading_x[u]
	var dy := -heading_y[u]
	if dx == 0 and dy == 0:
		dx = x[u] - from_x
		dy = y[u] - from_y
	if dx == 0 and dy == 0:
		dy = 1
	var step_x := signi(dx)
	var step_y := signi(dy)
	if absi(dx) > 2 * absi(dy):
		step_y = 0
	elif absi(dy) > 2 * absi(dx):
		step_x = 0
	var cell := Vector2i(x[u] / BattleMath.CELL, y[u] / BattleMath.CELL)
	for k: int in cells:
		var next := cell + Vector2i(step_x, step_y)
		if _field.kind_at(next) != BattleField.FREE:
			break
		# No corner cutting, as for walking: a diagonal step needs both cells beside it free.
		if step_x != 0 and step_y != 0 and (_field.kind_at(Vector2i(next.x, cell.y)) != BattleField.FREE
				or _field.kind_at(Vector2i(cell.x, next.y)) != BattleField.FREE):
			break
		cell = next
	x[u] = BattleMath.centre(cell.x)
	y[u] = BattleMath.centre(cell.y)
	target[u] = -1
	state[u] = IDLE
	_wants[u] = 1
	_stuck[u] = 0


## Rebuilds the unit buckets from the living units.
func rebuild_buckets() -> void:
	bucket_head.fill(-1)
	var span := BUCKET_CELLS * BattleMath.CELL
	for u: int in count:
		if state[u] == DEAD:
			continue
		var bucket := (y[u] / span) * buckets_wide + x[u] / span
		bucket_next[u] = bucket_head[bucket]
		bucket_head[bucket] = u


func _kill(u: int) -> void:
	state[u] = DEAD
	target[u] = -1
	alive -= 1


func _add_type(catalog: Catalog, name: String, level: int, number: int) -> void:
	var stats := catalog.unit_level_stats(name, level)
	var t := type_names.size()
	type_names.append(name)
	_t_class.append(BattleLayout.AIR if catalog.unit_class(name) == "air" else BattleLayout.GROUND)
	_t_speed.append(catalog.unit_speed(name))
	_t_hp.append(maxi(1, int(stats.get("hp", 0))))
	_t_damage.append(int(stats.get("damage", 0)))
	_t_fire_ms.append(maxi(TICK_MS, int(stats.get("fire_ms", 0))))
	_t_reach.append(maxi(MIN_REACH, int(stats.get("range_units", 0))))
	_t_splash.append(catalog.unit_splash(name))
	_t_self_destruct.append(1 if catalog.unit_self_destructs(name) else 0)
	var set_id := BattlePathing.SET_ANY
	match catalog.unit_prefers(name):
		Catalog.CLASS_DEFENSE:
			set_id = BattlePathing.SET_DEFENSE
		Catalog.CLASS_RESOURCE:
			set_id = BattlePathing.SET_RESOURCE
		Catalog.CLASS_HQ:
			set_id = BattlePathing.SET_HQ
		Catalog.CLASS_WALL:
			set_id = BattlePathing.SET_WALL
	_t_set.append(set_id)
	for c: int in BattleLayout.CLASS_COUNT:
		_t_pct.append(catalog.unit_damage_pct(name, BattleLayout.CLASS_NAMES[c]))
	left.append(number)
	deployed.append(0)


## The set a unit of type t picks from now: its preference while one stands, else any building,
## else any building hidden or not.
func _set_for(t: int) -> int:
	var set_id := _t_set[t]
	if _standing[set_id] > 0:
		return set_id
	if _standing[BattlePathing.SET_ANY] > 0:
		return BattlePathing.SET_ANY
	return BattlePathing.SET_ANY_HIDDEN


func _aim_air(u: int) -> void:
	var best := _pathing.nearest(x[u], y[u], _set_for(unit_type[u]))
	_wants[u] = 0
	if best < 0:
		_stuck[u] = 1
		return
	target[u] = best
	state[u] = ATTACKING if _in_air_reach(u) else WALKING
	cooldown[u] = 0


## Gives a ground unit a target and a path, from this tick's shared searches or a new one while
## the budget lasts; returns the budget left. The path stops short of the first wall it would
## walk through, and that wall becomes the target.
func _aim_ground(u: int, budget: int) -> int:
	var t := unit_type[u]
	var m := _pathing.map_for(_set_for(t), _t_reach[t])
	var cell := (y[u] / BattleMath.CELL) * _field.width + x[u] / BattleMath.CELL
	var share := -1
	for i: int in _share_count:
		if _share_cell[i] == cell and _share_map[i] == m:
			share = i
			break
	if share < 0:
		if budget <= 0:
			return budget
		budget -= 1
		share = _search(cell, m)
	_wants[u] = 0
	var aim := _share_target[share]
	if aim < 0:
		_stuck[u] = 1
		return budget
	target[u] = aim
	_paths[u] = _share_path[share]
	_path_pos[u] = 0
	state[u] = WALKING
	cooldown[u] = 0
	return budget


func _search(cell: int, m: int) -> int:
	var path := _pathing.find(cell, m)
	var aim := _pathing.found
	for k: int in range(1, path.size()):
		if _field.kind[path[k]] == BattleField.WALL:
			aim = _field.building[path[k]] - 1
			path = path.slice(0, k)
			break
	var i := _share_count
	_share_count += 1
	if i == _share_cell.size():
		_share_cell.append(cell)
		_share_map.append(m)
		_share_target.append(aim)
		_share_path.append(path)
	else:
		_share_cell[i] = cell
		_share_map[i] = m
		_share_target[i] = aim
		_share_path[i] = path
	return i


## Moves a ground unit along its path; at its end it attacks.
func _walk(u: int) -> void:
	var path := _paths[u]
	var t := unit_type[u]
	var carry := _carry[u] + _t_speed[t] * TICK_MS
	var budget := carry / 1000
	_carry[u] = carry % 1000
	var pos := _path_pos[u]
	var px := x[u]
	var py := y[u]
	while budget > 0 and pos < path.size():
		var tx := BattleMath.centre(path[pos] % _width)
		var ty := BattleMath.centre(path[pos] / _width)
		var dx := tx - px
		var dy := ty - py
		# Along an axis the length needs no root.
		var d := absi(dx) + absi(dy) if dx == 0 or dy == 0 else BattleMath.isqrt(dx * dx + dy * dy)
		if d <= budget:
			px = tx
			py = ty
			budget -= d
			pos += 1
		else:
			px += dx * budget / d
			py += dy * budget / d
			budget = 0
		if dx != 0 or dy != 0:
			heading_x[u] = dx
			heading_y[u] = dy
	x[u] = px
	y[u] = py
	_path_pos[u] = pos
	if pos >= path.size():
		state[u] = ATTACKING
		cooldown[u] = 0


## Flies an air unit straight at its target's nearest point, stopping once in reach.
func _fly(u: int) -> void:
	var b := target[u]
	var t := unit_type[u]
	var nx := clampi(x[u], _layout.x0[b], _layout.x1[b])
	var ny := clampi(y[u], _layout.y0[b], _layout.y1[b])
	var dx := nx - x[u]
	var dy := ny - y[u]
	var d := BattleMath.isqrt(dx * dx + dy * dy)
	var carry := _carry[u] + _t_speed[t] * TICK_MS
	var step := carry / 1000
	_carry[u] = carry % 1000
	var reach := _t_reach[t]
	if d - step <= reach:
		step = maxi(0, d - reach)
		state[u] = ATTACKING
		cooldown[u] = 0
	if d > 0 and step > 0:
		x[u] += dx * step / d
		y[u] += dy * step / d
		heading_x[u] = dx
		heading_y[u] = dy


func _in_air_reach(u: int) -> bool:
	var b := target[u]
	var reach := _t_reach[unit_type[u]]
	return BattleMath.dist2_to_rect(x[u], y[u], _layout.x0[b], _layout.y0[b], _layout.x1[b],
		_layout.y1[b]) <= reach * reach


## Counts the attack cooldown down and hits when it is due: its damage against the target's
## class, and with splash every standing building within splash of the target's centre, each
## at its own class's percent. A self-destructing unit dies with its hit.
func _attack(u: int, tick: int, combat: BattleCombat, events: BattleEvents) -> void:
	if cooldown[u] > 0:
		cooldown[u] -= TICK_MS
		if cooldown[u] > 0:
			return
	var t := unit_type[u]
	var aim := target[u]
	cooldown[u] += _t_fire_ms[t]
	events.add(BattleEvents.UNIT_HIT, u + 1, _layout.ids[aim], x[u], y[u], _layout.cx[aim],
		_layout.cy[aim], tick)
	var damage := _t_damage[t]
	var splash := _t_splash[t]
	if splash <= 0:
		combat.damage_building(aim, damage * _t_pct[t * BattleLayout.CLASS_COUNT + _layout.classes[aim]] / 100)
	else:
		var ax := _layout.cx[aim]
		var ay := _layout.cy[aim]
		var s2 := splash * splash
		for b: int in _layout.count:
			if _layout.destroyed[b] != 0 or _layout.classes[b] == BattleLayout.TRAP:
				continue
			if b == aim or BattleMath.dist2_to_rect(ax, ay, _layout.x0[b], _layout.y0[b],
					_layout.x1[b], _layout.y1[b]) <= s2:
				combat.damage_building(b, damage * _t_pct[t * BattleLayout.CLASS_COUNT + _layout.classes[b]] / 100)
	if _t_self_destruct[t] != 0:
		hp[u] = 0
		_kill(u)
		events.add(BattleEvents.DEATH, 0, u + 1, x[u], y[u], x[u], y[u], tick)


## Mixes everything of the army that changes in a battle into a state hash (BattleSim.state_hash).
func hash_into(h: int) -> int:
	h = BattleMath.mix(h, count)
	h = BattleMath.mix(h, alive)
	for t: int in left.size():
		h = BattleMath.mix(h, left[t])
		h = BattleMath.mix(h, deployed[t])
	for b: int in _down.size():
		h = BattleMath.mix(h, _down[b])
	for s: int in _standing.size():
		h = BattleMath.mix(h, _standing[s])
	for u: int in count:
		for value: int in [unit_type[u], x[u], y[u], heading_x[u], heading_y[u], hp[u], state[u],
				target[u], cooldown[u], stun_until[u], hold_until[u], _carry[u], _wants[u], _stuck[u],
				_path_pos[u]]:
			h = BattleMath.mix(h, value)
		var path := _paths[u]
		h = BattleMath.mix(h, path.size())
		for i: int in path.size():
			h = BattleMath.mix(h, path[i])
	return h
