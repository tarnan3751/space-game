class_name BattleCombat
extends RefCounted
## The defender's side of a battle (docs/reference/battle.md, **Defences**): the defences'
## guns, shells in flight, shields, the gravity well, the EMP, the cloaked sentry and the traps.
## Pure logic.
##
## Every building's damage goes through damage_building, which drains the shields covering it
## before its hull. The defence phase of a tick lands the shells due, then each defence in id
## order (a hidden one first checking whether a unit has come within its range), then each trap,
## then recharges the shields. What fell or was revealed is queued for BattleSim to pass on.

const TICK_MS := 50

## Per building: the attack cooldown in ms and the unit kept as target (-1 for none).
var cooldown: PackedInt32Array = PackedInt32Array()
var aim: PackedInt32Array = PackedInt32Array()
## Per shield generator: the pool, the ms since it last absorbed damage, and recharge carried.
var pool: PackedInt32Array = PackedInt32Array()
var _quiet: PackedInt32Array = PackedInt32Array()
var _regen_carry: PackedInt32Array = PackedInt32Array()
## Per building, the generators covering it, lowest index first.
var _covers: Array[PackedInt32Array] = []
## Shells in flight, in the order they were fired.
var shell_count: int = 0
var _shell_source: PackedInt32Array = PackedInt32Array()
var _shell_land: PackedInt32Array = PackedInt32Array()
var _shell_x: PackedInt32Array = PackedInt32Array()
var _shell_y: PackedInt32Array = PackedInt32Array()
## Buildings fallen (traps gone off) and revealed, in order; each happens once per building, so
## the queues are sized for the layout and BattleSim reads them from where it left off.
var fallen: PackedInt32Array = PackedInt32Array()
var fallen_count: int = 0
var revealed: PackedInt32Array = PackedInt32Array()
var revealed_count: int = 0

var _layout: BattleLayout
var _army: BattleArmy
## The defences that act (they have targets), the traps and the shield generators, by index.
var _guns: PackedInt32Array = PackedInt32Array()
var _traps: PackedInt32Array = PackedInt32Array()
var _shields: PackedInt32Array = PackedInt32Array()
## Units found in an area, reused.
var _found: PackedInt32Array = PackedInt32Array()
var _found_count: int = 0


func _init(layout: BattleLayout, army: BattleArmy) -> void:
	_layout = layout
	_army = army
	var n := layout.count
	cooldown.resize(n)
	cooldown.fill(0)
	aim.resize(n)
	aim.fill(-1)
	pool.resize(n)
	_quiet.resize(n)
	_regen_carry.resize(n)
	_regen_carry.fill(0)
	fallen.resize(n)
	revealed.resize(n)
	for b: int in n:
		pool[b] = layout.shield_max[b]
		_quiet[b] = layout.shield_delay_ms[b]
		if layout.classes[b] == BattleLayout.TRAP and layout.targets[b] != 0:
			_traps.append(b)
		elif layout.classes[b] == BattleLayout.DEFENSE and layout.targets[b] != 0:
			_guns.append(b)
		if layout.shield_max[b] > 0:
			_shields.append(b)
	# Each building's shields: the generators whose bubble holds its centre. A generator does
	# not cover itself, and walls and traps are never shielded.
	_covers.resize(n)
	for b: int in n:
		var covering := PackedInt32Array()
		var cls := layout.classes[b]
		if cls != BattleLayout.WALL and cls != BattleLayout.TRAP:
			for g: int in n:
				if g == b or layout.shield_max[g] <= 0:
					continue
				var dx := layout.cx[b] - layout.cx[g]
				var dy := layout.cy[b] - layout.cy[g]
				if dx * dx + dy * dy <= layout.reach[g] * layout.reach[g]:
					covering.append(g)
		_covers[b] = covering
	var shells := 0
	for b: int in n:
		if layout.shell_ms[b] > 0 and layout.fire_ms[b] > 0:
			shells += layout.shell_ms[b] / maxi(TICK_MS, layout.fire_ms[b]) + 1
	_shell_source.resize(shells)
	_shell_land.resize(shells)
	_shell_x.resize(shells)
	_shell_y.resize(shells)
	_found.resize(army.unit_type.size())


## Damage to a building: the standing generators covering it absorb it first, lowest id first,
## each restarting its recharge delay; the rest comes off the hull.
func damage_building(b: int, amount: int) -> void:
	if _layout.destroyed[b] != 0 or amount <= 0:
		return
	var covering := _covers[b]
	for i: int in covering.size():
		var g := covering[i]
		if _layout.destroyed[g] != 0 or pool[g] <= 0:
			continue
		var absorbed := mini(pool[g], amount)
		pool[g] -= absorbed
		_quiet[g] = 0
		amount -= absorbed
		if amount <= 0:
			return
	if _layout.take(b, amount):
		_army.note_fallen(b)
		fallen[fallen_count] = b
		fallen_count += 1


## Shield left on a generator; 0 once it has fallen.
func shield_of(g: int) -> int:
	if _layout.destroyed[g] != 0:
		return 0
	return pool[g]


## The defence phase of one tick.
func tick(now: int, events: BattleEvents) -> void:
	_land_shells(now, events)
	for i: int in _guns.size():
		var d := _guns[i]
		if _layout.destroyed[d] == 0:
			_defend(d, now, events)
	for i: int in _traps.size():
		var t := _traps[i]
		if _layout.destroyed[t] == 0:
			_trap(t, now, events)
	_recharge()


func _defend(d: int, now: int, events: BattleEvents) -> void:
	var mask := _layout.targets[d]
	var cx := _layout.cx[d]
	var cy := _layout.cy[d]
	var reach := _layout.reach[d]
	if _layout.revealed[d] == 0:
		if _nearest(cx, cy, reach, mask) < 0:
			return
		_layout.reveal(d)
		revealed[revealed_count] = d
		revealed_count += 1
		events.add(BattleEvents.REVEAL, _layout.ids[d], 0, cx, cy, cx, cy, now)
	if cooldown[d] > 0:
		cooldown[d] -= TICK_MS
		if cooldown[d] > 0:
			return
	var u := aim[d]
	if u < 0 or not _fits(u, cx, cy, reach, mask):
		u = _nearest(cx, cy, reach, mask)
		aim[d] = u
	if u < 0:
		cooldown[d] = 0
		return
	cooldown[d] += maxi(TICK_MS, _layout.fire_ms[d])
	var id := _layout.ids[d]
	if _layout.shell_ms[d] > 0:
		var lands := now + _layout.shell_ms[d] / TICK_MS
		var i := shell_count
		shell_count += 1
		_shell_source[i] = d
		_shell_land[i] = lands
		_shell_x[i] = _army.x[u]
		_shell_y[i] = _army.y[u]
		events.add(BattleEvents.SHELL, id, u + 1, cx, cy, _army.x[u], _army.y[u], lands)
	elif _layout.hold_ms[d] > 0:
		var until := now + 1 + _layout.hold_ms[d] / TICK_MS
		_collect(cx, cy, reach, mask)
		for i: int in _found_count:
			_army.hold(_found[i], until)
		events.add(BattleEvents.HOLD, id, 0, cx, cy, cx, cy, now)
	else:
		events.add(BattleEvents.SHOT, id, u + 1, cx, cy, _army.x[u], _army.y[u], now)
		if _layout.stun_ms[d] > 0:
			_army.stun(u, now + 1 + _layout.stun_ms[d] / TICK_MS)
		_hit(u, _layout.damage[d], now, events)


func _land_shells(now: int, events: BattleEvents) -> void:
	var kept := 0
	for i: int in shell_count:
		if _shell_land[i] > now:
			_shell_source[kept] = _shell_source[i]
			_shell_land[kept] = _shell_land[i]
			_shell_x[kept] = _shell_x[i]
			_shell_y[kept] = _shell_y[i]
			kept += 1
			continue
		var d := _shell_source[i]
		events.add(BattleEvents.SHELL_LAND, _layout.ids[d], 0, _shell_x[i], _shell_y[i], _shell_x[i],
			_shell_y[i], now)
		_collect(_shell_x[i], _shell_y[i], _layout.splash[d], _layout.targets[d])
		for k: int in _found_count:
			_hit(_found[k], _layout.damage[d], now, events)
	shell_count = kept


## A trap goes off on the first tick a unit of its class is within its range: a throw trap
## throws every ground unit there, a mine hits every unit of its class there; then it is gone.
func _trap(t: int, now: int, events: BattleEvents) -> void:
	var cx := _layout.cx[t]
	var cy := _layout.cy[t]
	var reach := _layout.reach[t]
	var mask := _layout.targets[t]
	if _nearest(cx, cy, reach, mask) < 0:
		return
	events.add(BattleEvents.DETONATE, _layout.ids[t], 0, cx, cy, cx, cy, now)
	_collect(cx, cy, reach, mask)
	for i: int in _found_count:
		var u := _found[i]
		if _layout.throw_cells[t] > 0:
			var from_x := _army.x[u]
			var from_y := _army.y[u]
			_army.throw_unit(u, cx, cy, _layout.throw_cells[t])
			events.add(BattleEvents.THROW, _layout.ids[t], u + 1, from_x, from_y, _army.x[u], _army.y[u], now)
		else:
			_hit(u, _layout.damage[t], now, events)
	_layout.spend_trap(t)
	fallen[fallen_count] = t
	fallen_count += 1


func _recharge() -> void:
	for i: int in _shields.size():
		var g := _shields[i]
		var top := _layout.shield_max[g]
		if _layout.destroyed[g] != 0:
			continue
		if _quiet[g] < _layout.shield_delay_ms[g]:
			_quiet[g] += TICK_MS
			continue
		if pool[g] >= top:
			continue
		var carry := _regen_carry[g] + _layout.shield_regen[g] * TICK_MS
		_regen_carry[g] = carry % 1000
		pool[g] = mini(top, pool[g] + carry / 1000)


func _hit(u: int, amount: int, now: int, events: BattleEvents) -> void:
	if _army.damage_unit(u, amount):
		events.add(BattleEvents.DEATH, 0, u + 1, _army.x[u], _army.y[u], _army.x[u], _army.y[u], now)


## Whether unit u is alive, of a class in `mask` and within `reach` of (cx, cy).
func _fits(u: int, cx: int, cy: int, reach: int, mask: int) -> bool:
	if _army.state[u] == BattleArmy.DEAD or (_army.cls[u] & mask) == 0:
		return false
	var dx := _army.x[u] - cx
	var dy := _army.y[u] - cy
	return dx * dx + dy * dy <= reach * reach


## The living unit of a class in `mask` nearest (cx, cy) within `reach`, then the lowest id; -1
## for none. It reads only the buckets the reach touches.
func _nearest(cx: int, cy: int, reach: int, mask: int) -> int:
	var head := _army.bucket_head
	var next := _army.bucket_next
	var ux := _army.x
	var uy := _army.y
	var span := BattleArmy.BUCKET_CELLS * BattleMath.CELL
	var left := maxi(0, (cx - reach) / span)
	var top := maxi(0, (cy - reach) / span)
	var right := mini(_army.buckets_wide - 1, (cx + reach) / span)
	var bottom := mini(_army.buckets_high - 1, (cy + reach) / span)
	var r2 := reach * reach
	var best := -1
	var best_d2 := 0
	for by: int in range(top, bottom + 1):
		for bx: int in range(left, right + 1):
			var u := head[by * _army.buckets_wide + bx]
			while u >= 0:
				if (_army.cls[u] & mask) != 0 and _army.state[u] != BattleArmy.DEAD:
					var dx := ux[u] - cx
					var dy := uy[u] - cy
					var d2 := dx * dx + dy * dy
					if d2 <= r2 and (best < 0 or d2 < best_d2 or (d2 == best_d2 and u < best)):
						best = u
						best_d2 = d2
				u = next[u]
	return best


## Every living unit of a class in `mask` within `reach` of (cx, cy), into _found, in id order.
func _collect(cx: int, cy: int, reach: int, mask: int) -> void:
	_found_count = 0
	var head := _army.bucket_head
	var next := _army.bucket_next
	var span := BattleArmy.BUCKET_CELLS * BattleMath.CELL
	var left := maxi(0, (cx - reach) / span)
	var top := maxi(0, (cy - reach) / span)
	var right := mini(_army.buckets_wide - 1, (cx + reach) / span)
	var bottom := mini(_army.buckets_high - 1, (cy + reach) / span)
	for by: int in range(top, bottom + 1):
		for bx: int in range(left, right + 1):
			var u := head[by * _army.buckets_wide + bx]
			while u >= 0:
				if _fits(u, cx, cy, reach, mask):
					_found[_found_count] = u
					_found_count += 1
				u = next[u]
	# Insertion sort: the areas hold few units, and id order keeps every result the same.
	for i: int in range(1, _found_count):
		var v := _found[i]
		var j := i - 1
		while j >= 0 and _found[j] > v:
			_found[j + 1] = _found[j]
			j -= 1
		_found[j + 1] = v
