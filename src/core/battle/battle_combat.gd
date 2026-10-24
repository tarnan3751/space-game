class_name BattleCombat
extends RefCounted
## The defender's side of a battle (docs/reference/battle.md, **Defences**): the defences'
## guns and the cloaked sentry. Pure logic.
##
## Every building's damage goes through damage_building. The defence phase of a tick runs each
## defence in id order, a hidden one first checking whether a unit has come within its range.
## What fell or was revealed is queued for BattleSim to pass on.

const TICK_MS := 50

## Per building: the attack cooldown in ms and the unit kept as target (-1 for none).
var cooldown: PackedInt32Array = PackedInt32Array()
var aim: PackedInt32Array = PackedInt32Array()
## Buildings fallen and revealed, in order; each happens once per building, so
## the queues are sized for the layout and BattleSim reads them from where it left off.
var fallen: PackedInt32Array = PackedInt32Array()
var fallen_count: int = 0
var revealed: PackedInt32Array = PackedInt32Array()
var revealed_count: int = 0

var _layout: BattleLayout
var _army: BattleArmy
## The defences that act (they have targets), by index.
var _guns: PackedInt32Array = PackedInt32Array()


func _init(layout: BattleLayout, army: BattleArmy) -> void:
	_layout = layout
	_army = army
	var n := layout.count
	cooldown.resize(n)
	cooldown.fill(0)
	aim.resize(n)
	aim.fill(-1)
	fallen.resize(n)
	revealed.resize(n)
	for b: int in n:
		if layout.classes[b] == BattleLayout.DEFENSE and layout.targets[b] != 0:
			_guns.append(b)


## Damage to a building, off its hull.
func damage_building(b: int, amount: int) -> void:
	if _layout.destroyed[b] != 0 or amount <= 0:
		return
	if _layout.take(b, amount):
		_army.note_fallen(b)
		fallen[fallen_count] = b
		fallen_count += 1


## The defence phase of one tick.
func tick(now: int, events: BattleEvents) -> void:
	for i: int in _guns.size():
		var d := _guns[i]
		if _layout.destroyed[d] == 0:
			_defend(d, now, events)


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
	events.add(BattleEvents.SHOT, id, u + 1, cx, cy, _army.x[u], _army.y[u], now)
	_hit(u, _layout.damage[d], now, events)


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
