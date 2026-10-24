class_name BattleAbilities
extends RefCounted
## The attacker's abilities in a battle (docs/reference/battle.md, **Abilities**): how many of
## each are left, the repair swarms at work and the orbital strikes on their way. Pure logic.
##
## An ability is used at a cell's centre, at the start of its tick (use), and acts by its effect:
## a swarm heals every living unit within its radius each tick for its duration; an EMP burst
## disables every standing defence whose centre is within its radius at once (BattleCombat.disable);
## a strike lands after its delay on every standing building and wall whose footprint is within its
## radius, and on every living unit there too. The ability phase (tick) runs after the commands:
## the strikes due land, in the order they were called, then the swarms heal, in the order they
## were cast. Swarms and strikes are held in lists sized at setup for every ability brought, so a
## tick allocates nothing.

const TICK_MS := 50
const SWARM := 0
const EMP := 1
const STRIKE := 2
const _EFFECTS := [Catalog.EFFECT_SWARM, Catalog.EFFECT_EMP, Catalog.EFFECT_STRIKE]

## Per ability brought, in sorted id order: its id, effect, radius, and its numbers at the
## attacker's level (heal a second, or damage; duration, stun or delay in ms).
var type_names: PackedStringArray = PackedStringArray()
var _t_effect: PackedInt32Array = PackedInt32Array()
var _t_radius: PackedInt32Array = PackedInt32Array()
var _t_amount: PackedInt32Array = PackedInt32Array()
var _t_ms: PackedInt32Array = PackedInt32Array()
## The ability's place in catalog.ability_types() plus one, the events' source.
var _t_source: PackedInt32Array = PackedInt32Array()
## Left to use and used, per ability.
var left: PackedInt32Array = PackedInt32Array()
var used: PackedInt32Array = PackedInt32Array()

## Swarms at work, in cast order: the point, the tick they stop, the heal a second, the radius and
## the heal carried, in thousandths.
var swarm_count: int = 0
var _swarm_x: PackedInt32Array = PackedInt32Array()
var _swarm_y: PackedInt32Array = PackedInt32Array()
var _swarm_end: PackedInt32Array = PackedInt32Array()
var _swarm_heal: PackedInt32Array = PackedInt32Array()
var _swarm_radius: PackedInt32Array = PackedInt32Array()
var _swarm_carry: PackedInt32Array = PackedInt32Array()
## Strikes on their way, in call order: the point, the tick they land, the damage, the radius and
## the event source.
var strike_count: int = 0
var _strike_x: PackedInt32Array = PackedInt32Array()
var _strike_y: PackedInt32Array = PackedInt32Array()
var _strike_land: PackedInt32Array = PackedInt32Array()
var _strike_damage: PackedInt32Array = PackedInt32Array()
var _strike_radius: PackedInt32Array = PackedInt32Array()
var _strike_source: PackedInt32Array = PackedInt32Array()

var _layout: BattleLayout
var _army: BattleArmy
var _combat: BattleCombat


func _init(layout: BattleLayout, army: BattleArmy, combat: BattleCombat) -> void:
	_layout = layout
	_army = army
	_combat = combat


## Reads the attacker's {ability: count} and {ability: level} (a level is clamped into the
## ability's levels; 1 when left out). Returns "" or why it is refused, a total above
## BattleSim.MAX_ABILITIES included, checked before anything is sized by it. The ids are taken in
## sorted order, whatever order the dictionary holds them in, as the army's are.
func setup(catalog: Catalog, abilities: Dictionary, levels: Dictionary) -> String:
	var names: Array[String] = []
	for ability: Variant in abilities:
		names.append(str(ability))
	names.sort()
	var total := 0
	for name: String in names:
		if not catalog.has_ability(name):
			return "the attacker's abilities have unknown ability '%s'" % name
		var number := BattleMath.whole(abilities[name])
		if number < 0:
			return "the attacker's abilities have a bad count of %s" % name
		if number > BattleSim.MAX_ABILITIES - total:
			return "the attacker's abilities have more than %d in all" % BattleSim.MAX_ABILITIES
		var level := clampi(BattleMath.whole(levels.get(name, 1)), 1, catalog.ability_max_level(name))
		var stats := catalog.ability_level_stats(name, level)
		var effect := _EFFECTS.find(catalog.ability_effect(name))
		type_names.append(name)
		_t_effect.append(effect)
		_t_radius.append(catalog.ability_radius(name))
		match effect:
			SWARM:
				_t_amount.append(int(stats.get("heal_per_second", 0)))
				_t_ms.append(int(stats.get("duration_ms", 0)))
			EMP:
				_t_amount.append(0)
				_t_ms.append(int(stats.get("stun_ms", 0)))
			_:
				_t_amount.append(int(stats.get("damage", 0)))
				_t_ms.append(int(stats.get("delay_ms", 0)))
		_t_source.append(catalog.ability_types().find(name) + 1)
		left.append(number)
		used.append(0)
		total += number
	# Packed arrays are values, so each is resized by name.
	_swarm_x.resize(total)
	_swarm_y.resize(total)
	_swarm_end.resize(total)
	_swarm_heal.resize(total)
	_swarm_radius.resize(total)
	_swarm_carry.resize(total)
	_strike_x.resize(total)
	_strike_y.resize(total)
	_strike_land.resize(total)
	_strike_damage.resize(total)
	_strike_radius.resize(total)
	_strike_source.resize(total)
	return ""


func type_index(ability: String) -> int:
	return type_names.find(ability)


func left_total() -> int:
	var total := 0
	for i: int in left.size():
		total += left[i]
	return total


## Uses one of ability `t` at a cell's centre, at the start of tick `now`.
func use(t: int, cell: Vector2i, now: int, events: BattleEvents) -> void:
	left[t] -= 1
	used[t] += 1
	var px := BattleMath.centre(cell.x)
	var py := BattleMath.centre(cell.y)
	var radius := _t_radius[t]
	var ends := now + _t_ms[t] / TICK_MS
	match _t_effect[t]:
		SWARM:
			var i := swarm_count
			swarm_count += 1
			_swarm_x[i] = px
			_swarm_y[i] = py
			_swarm_end[i] = ends
			_swarm_heal[i] = _t_amount[t]
			_swarm_radius[i] = radius
			_swarm_carry[i] = 0
		EMP:
			var r2 := radius * radius
			for b: int in _layout.count:
				if _layout.destroyed[b] != 0 or _layout.classes[b] != BattleLayout.DEFENSE:
					continue
				var dx := _layout.cx[b] - px
				var dy := _layout.cy[b] - py
				if dx * dx + dy * dy <= r2:
					_combat.disable(b, ends)
		_:
			var i := strike_count
			strike_count += 1
			_strike_x[i] = px
			_strike_y[i] = py
			_strike_land[i] = ends
			_strike_damage[i] = _t_amount[t]
			_strike_radius[i] = radius
			_strike_source[i] = _t_source[t]
	events.add(BattleEvents.ABILITY, _t_source[t], 0, px, py, px, py, ends)


## The ability phase of tick `now`: the strikes due land, then the swarms heal.
func tick(now: int, events: BattleEvents) -> void:
	var kept := 0
	for i: int in strike_count:
		if _strike_land[i] > now:
			_strike_x[kept] = _strike_x[i]
			_strike_y[kept] = _strike_y[i]
			_strike_land[kept] = _strike_land[i]
			_strike_damage[kept] = _strike_damage[i]
			_strike_radius[kept] = _strike_radius[i]
			_strike_source[kept] = _strike_source[i]
			kept += 1
			continue
		_land(i, now, events)
	strike_count = kept
	kept = 0
	for i: int in swarm_count:
		if _swarm_end[i] <= now:
			continue
		_swarm_x[kept] = _swarm_x[i]
		_swarm_y[kept] = _swarm_y[i]
		_swarm_end[kept] = _swarm_end[i]
		_swarm_heal[kept] = _swarm_heal[i]
		_swarm_radius[kept] = _swarm_radius[i]
		_swarm_carry[kept] = _swarm_carry[i]
		_heal(kept)
		kept += 1
	swarm_count = kept


## A strike lands: its damage to every standing building and wall whose footprint is within its
## radius (through the shields, as any damage), hidden ones too, traps left out; then to every
## living unit within it.
func _land(i: int, now: int, events: BattleEvents) -> void:
	var px := _strike_x[i]
	var py := _strike_y[i]
	var radius := _strike_radius[i]
	var r2 := radius * radius
	var damage := _strike_damage[i]
	events.add(BattleEvents.STRIKE_LAND, _strike_source[i], 0, px, py, px, py, now)
	for b: int in _layout.count:
		if _layout.destroyed[b] != 0 or _layout.classes[b] == BattleLayout.TRAP:
			continue
		if BattleMath.dist2_to_rect(px, py, _layout.x0[b], _layout.y0[b], _layout.x1[b],
				_layout.y1[b]) <= r2:
			_combat.damage_building(b, damage)
	for u: int in _army.count:
		if _army.state[u] == BattleArmy.DEAD:
			continue
		var dx := _army.x[u] - px
		var dy := _army.y[u] - py
		if dx * dx + dy * dy <= r2 and _army.damage_unit(u, damage):
			events.add(BattleEvents.DEATH, 0, u + 1, _army.x[u], _army.y[u], _army.x[u], _army.y[u], now)


## One tick of swarm i: its heal a second, a tick's share with the rest carried, to every living
## unit within its radius, up to its hull.
func _heal(i: int) -> void:
	var carry := _swarm_carry[i] + _swarm_heal[i] * TICK_MS
	_swarm_carry[i] = carry % 1000
	var amount := carry / 1000
	if amount <= 0:
		return
	var px := _swarm_x[i]
	var py := _swarm_y[i]
	var r2 := _swarm_radius[i] * _swarm_radius[i]
	for u: int in _army.count:
		if _army.state[u] == BattleArmy.DEAD:
			continue
		var dx := _army.x[u] - px
		var dy := _army.y[u] - py
		if dx * dx + dy * dy <= r2:
			_army.heal(u, amount)


## Mixes everything of the abilities that changes in a battle into a state hash
## (BattleSim.state_hash).
func hash_into(h: int) -> int:
	for t: int in left.size():
		h = BattleMath.mix(h, left[t])
		h = BattleMath.mix(h, used[t])
	h = BattleMath.mix(h, swarm_count)
	for i: int in swarm_count:
		for value: int in [_swarm_x[i], _swarm_y[i], _swarm_end[i], _swarm_heal[i], _swarm_radius[i],
				_swarm_carry[i]]:
			h = BattleMath.mix(h, value)
	h = BattleMath.mix(h, strike_count)
	for i: int in strike_count:
		for value: int in [_strike_x[i], _strike_y[i], _strike_land[i], _strike_damage[i],
				_strike_radius[i], _strike_source[i]]:
			h = BattleMath.mix(h, value)
	return h
