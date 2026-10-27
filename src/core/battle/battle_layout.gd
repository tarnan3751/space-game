class_name BattleLayout
extends RefCounted
## The defender's buildings in a battle (docs/reference/battle.md): what each one is, where it
## stands and its hull. Pure logic, like all of src/core.
##
## Buildings are indexed 0..count-1 in id order, so a tie broken by the lowest index is broken by
## the lowest id. Everything a building is (type, cell, class, stats at its level) is fixed at
## setup; only `hp`, `destroyed` and `revealed` change, and only through this class's own
## methods: an array of another object written through a chain (`layout.hp[i] = v`) is copied
## first, so the other modules read these arrays and never write them.

## Battle classes as ints, in Catalog.battle_class's order.
const HQ := 0
const WALL := 1
const TRAP := 2
const DEFENSE := 3
const RESOURCE := 4
const OTHER := 5
const CLASS_COUNT := 6
## Catalog class names by the ints above.
const CLASS_NAMES := [Catalog.CLASS_HQ, Catalog.CLASS_WALL, Catalog.CLASS_TRAP,
	Catalog.CLASS_DEFENSE, Catalog.CLASS_RESOURCE, Catalog.CLASS_OTHER]
## A unit class as a bit, and a building's `targets` as a mask of them.
const GROUND := 1
const AIR := 2

var count: int = 0
var ids: PackedInt32Array = PackedInt32Array()
var types: PackedStringArray = PackedStringArray()
var levels: PackedInt32Array = PackedInt32Array()
var cell_x: PackedInt32Array = PackedInt32Array()
var cell_y: PackedInt32Array = PackedInt32Array()
var sizes: PackedInt32Array = PackedInt32Array()
var classes: PackedInt32Array = PackedInt32Array()
## The footprint in field units, [x0, x1] x [y0, y1], and its centre.
var x0: PackedInt32Array = PackedInt32Array()
var y0: PackedInt32Array = PackedInt32Array()
var x1: PackedInt32Array = PackedInt32Array()
var y1: PackedInt32Array = PackedInt32Array()
var cx: PackedInt32Array = PackedInt32Array()
var cy: PackedInt32Array = PackedInt32Array()
## The level's battle stats; 0 where the level has none. `targets` is a mask of GROUND and AIR,
## `reach` is range_cells in field units.
var targets: PackedInt32Array = PackedInt32Array()
var damage: PackedInt32Array = PackedInt32Array()
var reach: PackedInt32Array = PackedInt32Array()
var fire_ms: PackedInt32Array = PackedInt32Array()
var splash: PackedInt32Array = PackedInt32Array()
var shell_ms: PackedInt32Array = PackedInt32Array()
var shield_max: PackedInt32Array = PackedInt32Array()
var shield_regen: PackedInt32Array = PackedInt32Array()
var shield_delay_ms: PackedInt32Array = PackedInt32Array()
var hold_ms: PackedInt32Array = PackedInt32Array()
var stun_ms: PackedInt32Array = PackedInt32Array()
var throw_cells: PackedInt32Array = PackedInt32Array()
var hidden: PackedByteArray = PackedByteArray()
var max_hp: PackedInt32Array = PackedInt32Array()

## The hull left; a trap has none.
var hp: PackedInt32Array = PackedInt32Array()
## 1 once destroyed (a trap: once it has gone off).
var destroyed: PackedByteArray = PackedByteArray()
## 0 while a hidden building is unseen.
var revealed: PackedByteArray = PackedByteArray()
## The buildings that count for destruction (neither walls nor traps), and how many have fallen.
var counted: int = 0
var counted_fallen: int = 0
## Index of the Command Center, -1 when the layout has none.
var hq_index: int = -1

var _index_of: Dictionary[int, int] = {}


## Lays out `entries` ({id, type, level, cell: [x, y]}, a save's building shape; other keys are
## ignored) on `grid`. A level-0 entry (a building under first construction) is left out. Returns
## "" or the reason the layout is refused: an unknown type, a level the type does not have, an id
## that is not a positive whole number or is listed twice, a footprint off the field or over
## another.
func build(catalog: Catalog, entries: Array, grid: Vector2i) -> String:
	var sorted: Array[Dictionary] = []
	var seen: Dictionary[int, bool] = {}
	for entry: Variant in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			return "a defender building is not an object"
		var data: Dictionary = entry
		var id := BattleMath.whole(data.get("id"))
		if id < 1 or seen.has(id):
			return "defender building id %s is not a new positive whole number" % str(data.get("id"))
		seen[id] = true
		var type := str(data.get("type", ""))
		if not catalog.has_type(type):
			return "defender building %d has unknown type '%s'" % [id, type]
		var level := BattleMath.whole(data.get("level"))
		if level < 0 or level > catalog.max_level(type):
			return "defender building %d has no level %s" % [id, str(data.get("level"))]
		var cell: Variant = data.get("cell")
		if typeof(cell) != TYPE_ARRAY or (cell as Array).size() != 2 \
				or BattleMath.whole(cell[0]) < 0 or BattleMath.whole(cell[1]) < 0:
			return "defender building %d needs a cell [x, y]" % id
		if level > 0:
			sorted.append(data)
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["id"]) < int(b["id"]))
	var taken := BaseGrid.new(grid.x, grid.y)
	for data: Dictionary in sorted:
		var id := int(data["id"])
		var type := str(data["type"])
		var cell_data: Array = data["cell"]
		var cell := Vector2i(int(cell_data[0]), int(cell_data[1]))
		var size := catalog.size_of(type)
		if not taken.is_free(cell, size):
			return "defender building %d is off the field or over another" % id
		taken.occupy(id, cell, size)
		_add(catalog, id, type, int(data["level"]), cell, size)
	return ""


func index_of(id: int) -> int:
	return _index_of.get(id, -1)


## Takes `amount` off a building's hull; returns true when that destroys it.
func take(b: int, amount: int) -> bool:
	if destroyed[b] != 0 or amount <= 0:
		return false
	hp[b] -= amount
	if hp[b] > 0:
		return false
	hp[b] = 0
	_fall(b)
	return true


## A trap going off: gone, never counted.
func spend_trap(b: int) -> void:
	_fall(b)


func reveal(b: int) -> void:
	revealed[b] = 1


func _fall(b: int) -> void:
	destroyed[b] = 1
	if classes[b] != WALL and classes[b] != TRAP:
		counted_fallen += 1


func _add(catalog: Catalog, id: int, type: String, level: int, cell: Vector2i, size: int) -> void:
	var b := count
	count += 1
	_index_of[id] = b
	var stats := catalog.level_stats(type, level)
	var cls := CLASS_NAMES.find(catalog.battle_class(type))
	ids.append(id)
	types.append(type)
	levels.append(level)
	cell_x.append(cell.x)
	cell_y.append(cell.y)
	sizes.append(size)
	classes.append(cls)
	x0.append(cell.x * BattleMath.CELL)
	y0.append(cell.y * BattleMath.CELL)
	x1.append((cell.x + size) * BattleMath.CELL)
	y1.append((cell.y + size) * BattleMath.CELL)
	cx.append(cell.x * BattleMath.CELL + size * BattleMath.HALF)
	cy.append(cell.y * BattleMath.CELL + size * BattleMath.HALF)
	var mask := 0
	match catalog.targets_of(type):
		"ground":
			mask = GROUND
		"air":
			mask = AIR
		"both":
			mask = GROUND | AIR
	targets.append(mask)
	damage.append(int(stats.get("damage", 0)))
	reach.append(int(stats.get("range_cells", 0)) * BattleMath.CELL)
	fire_ms.append(int(stats.get("fire_ms", 0)))
	splash.append(int(stats.get("splash_units", 0)))
	shell_ms.append(int(stats.get("shell_ms", 0)))
	shield_max.append(int(stats.get("shield_hp", 0)))
	shield_regen.append(int(stats.get("shield_regen", 0)))
	shield_delay_ms.append(int(stats.get("shield_delay_ms", 0)))
	hold_ms.append(int(stats.get("hold_ms", 0)))
	stun_ms.append(int(stats.get("stun_ms", 0)))
	throw_cells.append(int(stats.get("throw_cells", 0)))
	var is_hidden := catalog.is_hidden(type)
	hidden.append(1 if is_hidden else 0)
	revealed.append(0 if is_hidden else 1)
	# A building with no hull (a data slip) still stands until one hit.
	var hull := 0 if cls == TRAP else maxi(1, int(stats.get("hp", 0)))
	max_hp.append(hull)
	hp.append(hull)
	destroyed.append(0)
	if cls != WALL and cls != TRAP:
		counted += 1
	if cls == HQ and hq_index < 0:
		hq_index = b
