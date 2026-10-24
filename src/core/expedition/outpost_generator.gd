class_name OutpostGenerator
extends RefCounted
## Lays out a rival outpost on an expedition field (docs/reference/expeditions.md). Pure logic,
## like all of src/core: no clock, integers only, and one SeededRng per field, seeded from the
## sector's seed, the epoch and the field's index (Sector.field_seed_of), so the same inputs give
## the same layout, byte for byte, on every device and on the server.
##
## The field's band (rules.expedition.bands, by index) sets the outpost's Command Center (the
## player's plus cc_offset, clamped), its counts (density_pct of each type's max_count at that
## level, rounded half up) and levels (the highest that level allows, plus level_offset, never
## below 1). The layout, as nested squares round a jittered centre, every footprint at least
## `margin` cells from the edge so a deploy zone exists on every side:
##   the inner compound: the Command Center, the storages and the other buildings (army, lab),
##     packed tight; members the walls cannot ring move out to the middle band;
##   ring 1: walls round the compound, with the band's gaps;
##   the middle band: the moved members, then the defences on two tracks, the shorter-ranged
##     half by the walls, the longer-ranged half further out;
##   ring 2: walls round the middle band, when the walls left cover it;
##   the outer zone: the collectors and the deposits (storages taken out of the compound), each
##     deposit with its hazards (defences taken out of the middle band);
##   traps: one on each gap, the rest on drawn free cells inside the outermost ring.
## A building with no room in its zone is searched for over the whole field with no spacing, and
## dropped (counted in `dropped`) only when none is left; every search visits each cell once, so
## generation always ends.
##
## The outpost's resources are sized so that the battle's loot (loot_pct of what is stored) is the
## band's target: loot_pct of the player's capacity at the scan, for each resource some building
## of the outpost holds.

const ROLE_HQ := 0
const ROLE_STORAGE := 1
const ROLE_COLLECTOR := 2
const ROLE_OTHER := 3
const ROLE_DEFENSE := 4
const ROLE_TRAP := 5
const ROLE_WALL := 6
const ROLE_COUNT := 7

const NO_CELL := Vector2i(-1, -1)

var _catalog: Catalog
var _rng: SeededRng
var _grid: BaseGrid
## The cells every footprint must stay in: the field less the margin.
var _box: Rect2i
## By building id: 1 for a wall or a trap, which spacing ignores.
var _soft: PackedByteArray = PackedByteArray([0])
## The smallest footprint size a search has failed for, by zone ([area, hole, spacing]): the field
## only fills, so a zone with no room for a size never has room for it or a larger one again.
var _full: Dictionary = {}
## By cell (y * width + x): 1 for a wall gap, which only a trap may take.
var _reserved: PackedByteArray = PackedByteArray()
var _buildings: Array[Dictionary] = []
var _next_id: int = 1
var _dropped: int = 0
var _spacing: int = 0
var _gap_cells: int = 1
## The spiral's rotation (0-3) and mirror (0-1), drawn once per field.
var _turn: int = 0
var _mirror: int = 0


## The field `index` of the state's sector; {} for an index that is not a field.
static func generate(catalog: Catalog, state: BaseState, index: int) -> Dictionary:
	var sector := state.sector
	return generate_field(catalog, sector.sector_seed, sector.epoch, index, sector.cc, sector.capacity)


## One field from its inputs:
##   {"seed", "index", "band", "cc",
##    "defender": {"buildings": [{"id", "type", "level", "cell": [x, y]}...], "resources": {res: n}},
##    "loot": {res: n}, "deposits": [id...], "hazards": [id...],
##    "rings": [{"rect": [x, y, width, height], "gaps": [[x, y]...]}...], "dropped": n}
## `defender` is BattleSim's setup shape; `seed` is the battle's seed. {} for an index that is not
## a field.
static func generate_field(catalog: Catalog, sector_seed: int, epoch: int, index: int,
		player_cc: int, capacity: Dictionary[String, int]) -> Dictionary:
	if index < 0 or index >= catalog.expedition_field_count():
		return {}
	var generator := OutpostGenerator.new()
	return generator._generate(catalog, Sector.field_seed_of(sector_seed, epoch, index), index,
		player_cc, capacity)


## The BattleSim setup for a field and an army, with no commands yet.
static func battle_setup(field: Dictionary, army: Dictionary, unit_levels: Dictionary) -> Dictionary:
	var defender: Dictionary = field["defender"]
	return {
		"seed": field["seed"],
		"attacker": {"army": army.duplicate(), "unit_levels": unit_levels.duplicate(), "abilities": {}},
		"defender": defender.duplicate(true),
		"commands": [],
	}


## What the sector map shows of a field without laying it out:
## {"index", "band", "cc", "loot": {res: n}, "seed"}; {} for an index that is not a field.
static func summary(catalog: Catalog, sector: Sector, index: int) -> Dictionary:
	if index < 0 or index >= catalog.expedition_field_count():
		return {}
	var band := catalog.expedition_band(index)
	var cc := outpost_cc(catalog, band, sector.cc)
	var counts := plan(catalog, band, cc)
	var held := PackedStringArray()
	for type: String in counts:
		if counts[type] > 0:
			held.append_array(_held(catalog, type, outpost_level(catalog, band, type, cc)))
	return {"index": index, "band": str(band["id"]), "cc": cc,
		"loot": loot_targets(catalog, band, sector.capacity, held), "seed": sector.field_seed(index)}


static func outpost_cc(catalog: Catalog, band: Dictionary, player_cc: int) -> int:
	return clampi(player_cc + int(band["cc_offset"]), 1, maxi(1, catalog.max_cc_level()))


## Each type's count at the outpost's Command Center level, in catalog order: one Command Center,
## and density_pct of every other type's max_count, rounded half up.
static func plan(catalog: Catalog, band: Dictionary, cc: int) -> Dictionary[String, int]:
	var counts: Dictionary[String, int] = {}
	var density: int = band["density_pct"]
	for type: String in catalog.types():
		var allowed := catalog.max_count(type, cc)
		if type == Catalog.HQ_TYPE:
			counts[type] = mini(1, allowed)
		else:
			counts[type] = mini(allowed, (allowed * density + 50) / 100)
	return counts


## The highest level the outpost's Command Center allows the type, plus the band's level_offset,
## never below 1.
static func outpost_level(catalog: Catalog, band: Dictionary, type: String, cc: int) -> int:
	var best := 1
	for level: int in range(1, catalog.max_level(type) + 1):
		if int(catalog.level_stats(type, level).get("requires_cc", 1)) <= cc:
			best = level
	return maxi(1, best + int(band["level_offset"]))


## The loot target of each resource: the band's loot_pct of the player's capacity, for a resource
## the outpost holds (`held`) and a raid can take; 0 otherwise.
static func loot_targets(catalog: Catalog, band: Dictionary, capacity: Dictionary[String, int],
		held: PackedStringArray) -> Dictionary[String, int]:
	var targets: Dictionary[String, int] = {}
	var share: int = band["loot_pct"]
	for res: String in catalog.resources:
		var target := 0
		if held.has(res) and catalog.loot_pct(res) > 0:
			target = int(capacity.get(res, 0)) * share / 100
		targets[res] = target
	return targets


# --- Internals -----------------------------------------------------------------

func _generate(catalog: Catalog, field_seed: int, index: int, player_cc: int,
		capacity: Dictionary[String, int]) -> Dictionary:
	_catalog = catalog
	_rng = SeededRng.new(field_seed)
	_grid = BaseGrid.new(catalog.grid_size.x, catalog.grid_size.y)
	_reserved.resize(catalog.grid_size.x * catalog.grid_size.y)
	_reserved.fill(0)
	var rules := catalog.expedition
	var margin: int = rules["margin"]
	_box = Rect2i(margin, margin, catalog.grid_size.x - 2 * margin, catalog.grid_size.y - 2 * margin)
	_spacing = rules["spacing"]
	_gap_cells = rules["wall_gap_cells"]
	var slack: int = rules["slack_pct"]
	var jitter: int = rules["jitter"]
	var band := catalog.expedition_band(index)
	var gaps: int = band["wall_gaps"]
	var cc := outpost_cc(catalog, band, player_cc)

	# The roster by role, each a list of [type, level] in catalog order.
	var counts := plan(catalog, band, cc)
	var roles: Array[Array] = []
	for r: int in ROLE_COUNT:
		roles.append([])
	var walls := 0
	var wall_type := ""
	var wall_level := 1
	for type: String in counts:
		var level := outpost_level(catalog, band, type, cc)
		var role := _role(type, level)
		if role == ROLE_WALL:
			walls += counts[type]
			wall_type = type
			wall_level = level
			continue
		for n: int in counts[type]:
			roles[role].append([type, level])

	# Deposits come out of the storages: the type with the most copies left each time, its last.
	var deposits: Array = []
	for n: int in int(band["deposits"]):
		var pick := _most_copies(roles[ROLE_STORAGE])
		if pick < 0:
			break
		deposits.append(roles[ROLE_STORAGE][pick])
		roles[ROLE_STORAGE].remove_at(pick)

	# The draws, in this order: the shuffles, the jitter, the spiral's turn.
	_shuffle(roles[ROLE_STORAGE])
	_shuffle(roles[ROLE_OTHER])
	_shuffle(roles[ROLE_DEFENSE])
	_shuffle(roles[ROLE_COLLECTOR])
	var centre := catalog.grid_size / 2 + Vector2i(_rng.range_int(-jitter, jitter), _rng.range_int(-jitter, jitter))
	_turn = _rng.range_int(0, 3)
	_mirror = _rng.range_int(0, 1)

	# Hazards come out of the defences, after their shuffle.
	var hazards: Array = []
	for n: int in mini(int(band["hazards"]) * deposits.size(), roles[ROLE_DEFENSE].size()):
		hazards.append(roles[ROLE_DEFENSE].pop_front())

	# The compound: as many members as ring 1 can close round, lowest priority moved out first.
	var hq_size := 0
	if not roles[ROLE_HQ].is_empty():
		hq_size = catalog.size_of(str(roles[ROLE_HQ][0][0]))
	var members: Array = roles[ROLE_STORAGE] + roles[ROLE_OTHER]
	var moved: Array = []
	var side := _compound_side(members, hq_size, slack)
	while not members.is_empty() and _ring_walls(side, gaps) > walls:
		moved.push_front(members.pop_back())
		side = _compound_side(members, hq_size, slack)

	# The middle band's depth: room for the moved members and the defences.
	var middle_need := 0
	for entry: Array in moved + roles[ROLE_DEFENSE]:
		var size := catalog.size_of(str(entry[0])) + _spacing
		middle_need += size * size
	middle_need = middle_need * slack / 100
	var inner := side + 2
	var depth := _depth(inner, middle_need)
	# The outer zone's depth round ring 2: room for the collectors, the deposits and the hazards.
	var outer_need := 0
	for entry: Array in roles[ROLE_COLLECTOR] + deposits + hazards:
		var size := catalog.size_of(str(entry[0])) + _spacing
		outer_need += size * size
	var outer_depth := _depth(inner + 2 * depth + 2, outer_need * slack / 100) if outer_need > 0 else 0
	# Everything nested inside the box: the middle band gives way to the outer zone, then shrinks
	# with the compound, until ring 2 fits.
	var room := mini(_box.size.x, _box.size.y)
	depth = mini(depth, maxi(1, (room - inner - 2 - 2 * outer_depth) / 2))
	depth = mini(depth, maxi(0, (room - inner - 2) / 2))
	side = mini(side, room - 2 - 2 * depth - 2)
	var total := side + 4 + 2 * depth
	var corner := centre - Vector2i(total / 2, total / 2)
	corner = corner.clamp(_box.position, _box.end - Vector2i(total, total))
	var outer := Rect2i(corner, Vector2i(total, total))
	var middle := outer.grow(-1)
	var ring1 := middle.grow(-depth)
	var compound := ring1.grow(-1)

	# The compound, packed tight from its centre, the largest first so the small fill the corners.
	members = _largest_first(members)
	var compound_centre := compound.position + compound.size / 2
	for entry: Array in roles[ROLE_HQ]:
		var size := catalog.size_of(str(entry[0]))
		var cell := compound.position + (compound.size - Vector2i(size, size)) / 2
		if _fits(cell, size, compound, Rect2i(), 0):
			_add(entry, cell)
		else:
			_place_anywhere(entry, compound_centre)
	for entry: Array in members:
		var cell := _spiral(compound_centre, catalog.size_of(str(entry[0])), compound, Rect2i(), 0)
		if cell == NO_CELL:
			moved.append(entry)
		else:
			_add(entry, cell)

	var rings: Array = []
	# Both rings go down before anything outside the compound, their gaps reserved, so no later
	# placement or fallback can sit on a ring or close a gap. Ring 2 only when the walls left
	# cover it.
	var walls_left := _ring(ring1, gaps, walls, wall_type, wall_level, rings)
	var built_outer := _ring_walls(middle.size.x, gaps) <= walls_left
	if built_outer:
		walls_left = _ring(outer, gaps, walls_left, wall_type, wall_level, rings)
	var held_rect := outer if built_outer else middle

	# The middle band: the moved members nearest the compound, then the defences on their tracks.
	for entry: Array in _largest_first(moved):
		var cell := _spiral(compound_centre, catalog.size_of(str(entry[0])), middle, ring1, _spacing)
		if cell == NO_CELL:
			_place_anywhere(entry, compound_centre)
		else:
			_add(entry, cell)
	# By range, then by the shuffled order: one int key each (range * count + index), so the sort
	# is the same everywhere.
	var keys := PackedInt64Array()
	var count: int = roles[ROLE_DEFENSE].size()
	for i: int in count:
		keys.append(_range_of(roles[ROLE_DEFENSE][i]) * count + i)
	keys.sort()
	var defences: Array = []
	for key: int in keys:
		defences.append(roles[ROLE_DEFENSE][key % count])
	var near_count := (defences.size() + 1) / 2
	_spread(defences.slice(0, near_count), ring1.grow(2), middle, ring1)
	_spread(defences.slice(near_count), ring1.grow(2 + depth / 2), middle, ring1)

	# The outer zone: the collectors, the deposits in drawn places among them, their hazards.
	var outside: Array = roles[ROLE_COLLECTOR].duplicate()
	var is_deposit: Array[bool] = []
	for entry: Variant in outside:
		is_deposit.append(false)
	for entry: Array in deposits:
		var at := _rng.range_int(0, outside.size())
		outside.insert(at, entry)
		is_deposit.insert(at, true)
	# The deposits and their hazards take their slots first, so a hazard finds room by its deposit.
	var slots := _slots(outer.grow(2), outside.size())
	var deposit_ids: Array = []
	var hazard_ids: Array = []
	var next_hazard := 0
	for i: int in outside.size():
		if not is_deposit[i]:
			continue
		var id := _place_at(outside[i], slots[i], _box, held_rect)
		if id == 0:
			continue
		deposit_ids.append(id)
		var at := _centre_of(id)
		for n: int in int(band["hazards"]):
			if next_hazard >= hazards.size():
				break
			var hazard: Array = hazards[next_hazard]
			next_hazard += 1
			var cell := _spiral(at, catalog.size_of(str(hazard[0])), _box, held_rect, _spacing)
			var hazard_id: int = _add(hazard, cell) if cell != NO_CELL else _place_anywhere(hazard, at)
			if hazard_id != 0:
				hazard_ids.append(hazard_id)
	for n: int in range(next_hazard, hazards.size()):
		var hazard_id := _place_anywhere(hazards[n], outer.position)
		if hazard_id != 0:
			hazard_ids.append(hazard_id)
	for i: int in outside.size():
		if not is_deposit[i]:
			_place_at(outside[i], slots[i], _box, held_rect)

	var last: Array = (rings[rings.size() - 1] as Dictionary)["rect"] if not rings.is_empty() else []
	var walled := Rect2i(int(last[0]), int(last[1]), int(last[2]), int(last[3])) if not last.is_empty() else held_rect
	_traps(roles[ROLE_TRAP], rings, walled, held_rect)

	# The loot, from what the outpost holds.
	var held := PackedStringArray()
	for building: Dictionary in _buildings:
		for res: String in _held(catalog, str(building["type"]), int(building["level"])):
			if not held.has(res):
				held.append(res)
	var loot := loot_targets(catalog, band, capacity, held)
	var stored := {}
	for res: String in catalog.resources:
		var pct := catalog.loot_pct(res)
		stored[res] = (loot[res] * 100 + pct - 1) / pct if loot[res] > 0 else 0
	var loot_data := {}
	for res: String in loot:
		loot_data[res] = loot[res]
	return {
		"seed": field_seed,
		"index": index,
		"band": str(band["id"]),
		"cc": cc,
		"defender": {"buildings": _buildings, "resources": stored},
		"loot": loot_data,
		"deposits": deposit_ids,
		"hazards": hazard_ids,
		"rings": rings,
		"dropped": _dropped,
	}


## A type's role at a level, from its battle class and the level's stats.
func _role(type: String, level: int) -> int:
	match _catalog.battle_class(type):
		Catalog.CLASS_HQ:
			return ROLE_HQ
		Catalog.CLASS_WALL:
			return ROLE_WALL
		Catalog.CLASS_TRAP:
			return ROLE_TRAP
		Catalog.CLASS_DEFENSE:
			return ROLE_DEFENSE
		Catalog.CLASS_RESOURCE:
			var storage: Dictionary = _catalog.level_stats(type, level).get("storage", {})
			return ROLE_STORAGE if not storage.is_empty() else ROLE_COLLECTOR
	return ROLE_OTHER


## The resources a type stores or produces at a level, as the battle's loot counts them: none for
## a wall or a trap, which hold no loot share.
static func _held(catalog: Catalog, type: String, level: int) -> PackedStringArray:
	var found := PackedStringArray()
	var battle_class := catalog.battle_class(type)
	if battle_class == Catalog.CLASS_WALL or battle_class == Catalog.CLASS_TRAP:
		return found
	var stats := catalog.level_stats(type, level)
	for field: String in ["storage", "produces"]:
		var amounts: Dictionary = stats.get(field, {})
		for res: Variant in amounts:
			if int(amounts[res]) > 0:
				found.append(str(res))
	return found


## The index of the last copy of the type with the most copies in `entries` (ties to the type
## first in the list); -1 when it is empty.
func _most_copies(entries: Array) -> int:
	var copies: Dictionary[String, int] = {}
	var first: PackedStringArray = PackedStringArray()
	for entry: Array in entries:
		var type: String = entry[0]
		if not copies.has(type):
			copies[type] = 0
			first.append(type)
		copies[type] += 1
	var best := ""
	for type: String in first:
		if best == "" or copies[type] > copies[best]:
			best = type
	for i: int in range(entries.size() - 1, -1, -1):
		if str(entries[i][0]) == best:
			return i
	return -1


## The entries by footprint size, largest first, in their order within a size.
func _largest_first(entries: Array) -> Array:
	var keys := PackedInt64Array()
	var count := entries.size()
	for i: int in count:
		keys.append(-_catalog.size_of(str(entries[i][0])) * count + i)
	keys.sort()
	var sorted: Array = []
	for key: int in keys:
		sorted.append(entries[posmod(key, count)])
	return sorted


## Fisher-Yates with the field's generator, one draw per entry after the first.
func _shuffle(entries: Array) -> void:
	for i: int in range(entries.size() - 1, 0, -1):
		var j := _rng.range_int(0, i)
		var swap: Variant = entries[i]
		entries[i] = entries[j]
		entries[j] = swap


## The side of the square compound that holds the Command Center and `members`, with slack.
func _compound_side(members: Array, hq_size: int, slack: int) -> int:
	var area := hq_size * hq_size
	for entry: Array in members:
		var size := _catalog.size_of(str(entry[0]))
		area += size * size
	var side := BattleMath.isqrt(area * slack / 100)
	if side * side < area * slack / 100:
		side += 1
	return maxi(side, hq_size + 2)


## The smallest depth of a square band round a square of `side` whose area is at least `need`.
static func _depth(side: int, need: int) -> int:
	var depth := 1
	while (side + 2 * depth) * (side + 2 * depth) - side * side < need:
		depth += 1
	return depth


## The walls a ring round a square of `side` takes, less its gaps.
func _ring_walls(side: int, gaps: int) -> int:
	return maxi(0, 4 * side + 4 - gaps * _gap_cells)


func _range_of(entry: Array) -> int:
	return int(_catalog.level_stats(str(entry[0]), int(entry[1])).get("range_cells", 0))


## Walls along the border of `rect`, clockwise from a drawn cell, with `gaps` runs of
## _gap_cells left open, evenly spaced; when the walls run out, the rest is open. Records the ring
## and returns the walls left.
func _ring(rect: Rect2i, gaps: int, walls: int, wall_type: String, wall_level: int, rings: Array) -> int:
	var perimeter := 2 * (rect.size.x + rect.size.y) - 4
	if rect.size.x < 2 or rect.size.y < 2:
		return walls
	var start := _rng.range_int(0, perimeter - 1)
	var open := PackedByteArray()
	open.resize(perimeter)
	open.fill(0)
	var gap_cells: Array = []
	for g: int in gaps:
		var at := (start + g * perimeter / gaps) % perimeter
		gap_cells.append(_cell_list(_border_cell(rect, (at + _gap_cells / 2) % perimeter)))
		for n: int in _gap_cells:
			open[(at + n) % perimeter] = 1
			var gap_cell := _border_cell(rect, (at + n) % perimeter)
			_reserved[gap_cell.y * _grid.width + gap_cell.x] = 1
	for i: int in perimeter:
		var step := (start + i) % perimeter
		if open[step] == 1:
			continue
		if walls <= 0:
			break
		var cell := _border_cell(rect, step)
		if _grid.is_free(cell, 1):
			_add([wall_type, wall_level], cell)
			walls -= 1
	rings.append({"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y], "gaps": gap_cells})
	return walls


## The cell `step` along the border of `rect`, clockwise from its top-left corner.
static func _border_cell(rect: Rect2i, step: int) -> Vector2i:
	var w := rect.size.x
	var h := rect.size.y
	if step < w - 1:
		return rect.position + Vector2i(step, 0)
	step -= w - 1
	if step < h - 1:
		return rect.position + Vector2i(w - 1, step)
	step -= h - 1
	if step < w - 1:
		return rect.position + Vector2i(w - 1 - step, h - 1)
	step -= w - 1
	return rect.position + Vector2i(0, h - 1 - step)


## Places `entries` at slots spread evenly along the border of `track`, each by _place_at.
func _spread(entries: Array, track: Rect2i, area: Rect2i, hole: Rect2i) -> void:
	var slots := _slots(track, entries.size())
	for i: int in entries.size():
		_place_at(entries[i], slots[i], area, hole)


## `count` cells spread evenly along the border of `track`, from a drawn start (no draw for none).
func _slots(track: Rect2i, count: int) -> Array[Vector2i]:
	var slots: Array[Vector2i] = []
	if count == 0:
		return slots
	var perimeter := maxi(1, 2 * (track.size.x + track.size.y) - 4)
	var start := _rng.range_int(0, perimeter - 1)
	for i: int in count:
		slots.append(_border_cell(track, (start + i * perimeter / count) % perimeter))
	return slots


## The entry at the first spiral cell from `slot` inside `area`, outside `hole`, with spacing; else
## anywhere. Its id, 0 when dropped.
func _place_at(entry: Array, slot: Vector2i, area: Rect2i, hole: Rect2i) -> int:
	var cell := _spiral(slot, _catalog.size_of(str(entry[0])), area, hole, _spacing)
	return _add(entry, cell) if cell != NO_CELL else _place_anywhere(entry, slot)


## Traps: one on each gap's middle cell (the 1x1 traps first), the rest on drawn free cells inside
## `inside` (the outermost ring), then inside `beyond` (the middle band, or the outer ring's)
## once those run out.
func _traps(traps: Array, rings: Array, inside: Rect2i, beyond: Rect2i) -> void:
	# By size, then in catalog order: one int key each (size * count + index), so the sort is the
	# same on every engine.
	var keys := PackedInt64Array()
	var count := traps.size()
	for i: int in count:
		keys.append(_catalog.size_of(str(traps[i][0])) * count + i)
	keys.sort()
	var left: Array = []
	for key: int in keys:
		left.append(traps[key % count])
	for ring: Dictionary in rings:
		for gap: Variant in ring["gaps"]:
			if left.is_empty() or _catalog.size_of(str(left[0][0])) != 1:
				break
			var cell := Vector2i(int(gap[0]), int(gap[1]))
			if _grid.is_free(cell, 1):
				_add(left.pop_front(), cell)
	# The free cells by trap size, listed once in cell order; a drawn cell that no longer fits is
	# struck off and another drawn, so each trap draws at most once per candidate.
	var candidates: Dictionary[int, Array] = {}
	for entry: Array in left:
		var size := _catalog.size_of(str(entry[0]))
		var placed := false
		for area: Rect2i in [inside, beyond]:
			var key := size if area == inside else -size
			if not candidates.has(key):
				var cells: Array = []
				for y: int in range(area.position.y, area.end.y - size + 1):
					for x: int in range(area.position.x, area.end.x - size + 1):
						if _fits(Vector2i(x, y), size, area, Rect2i(), 0):
							cells.append(Vector2i(x, y))
				candidates[key] = cells
			var list: Array = candidates[key]
			while not list.is_empty() and not placed:
				var at := _rng.range_int(0, list.size() - 1)
				var cell: Vector2i = list[at]
				list.remove_at(at)
				if _fits(cell, size, area, Rect2i(), 0):
					_add(entry, cell)
					placed = true
			if placed:
				break
		if not placed:
			_place_anywhere(entry, inside.position)


## The first cell, spiralling out from `anchor`, where a footprint of `size` centred there is
## inside `area`, clear of `hole` and free with `spacing`; NO_CELL when none is. Each ring of the
## spiral is walked in the field's drawn turn and mirror; every cell is visited once.
func _spiral(anchor: Vector2i, size: int, area: Rect2i, hole: Rect2i, spacing: int) -> Vector2i:
	var zone := [area, hole, spacing]
	if _full.has(zone) and size >= int(_full[zone]):
		return NO_CELL
	var origin := anchor - Vector2i(size / 2, size / 2)
	var reach := 0
	for corner: Vector2i in [area.position, area.end, Vector2i(area.position.x, area.end.y),
			Vector2i(area.end.x, area.position.y)]:
		reach = maxi(reach, maxi(absi(corner.x - origin.x), absi(corner.y - origin.y)))
	for r: int in reach + 1:
		var steps := maxi(1, 8 * r)
		for step: int in steps:
			var offset := _ring_offset(r, step)
			var cell := origin + _oriented(offset)
			if _fits(cell, size, area, hole, spacing):
				return cell
	_full[zone] = size
	return NO_CELL


## Step `step` of the square ring at distance r, clockwise from its top-left corner.
static func _ring_offset(r: int, step: int) -> Vector2i:
	if r == 0:
		return Vector2i.ZERO
	var side := 2 * r
	if step < side:
		return Vector2i(-r + step, -r)
	step -= side
	if step < side:
		return Vector2i(r, -r + step)
	step -= side
	if step < side:
		return Vector2i(r - step, r)
	step -= side
	return Vector2i(-r, r - step)


func _oriented(offset: Vector2i) -> Vector2i:
	if _mirror == 1:
		offset.x = -offset.x
	for n: int in _turn:
		offset = Vector2i(-offset.y, offset.x)
	return offset


## Whether a footprint at `cell` lies in `area` and the box, clear of `hole`, on free cells, with
## no building but walls and traps within `spacing` of it.
func _fits(cell: Vector2i, size: int, area: Rect2i, hole: Rect2i, spacing: int) -> bool:
	var footprint := Rect2i(cell, Vector2i(size, size))
	if not area.encloses(footprint) or not _box.encloses(footprint):
		return false
	if hole.has_area() and hole.intersects(footprint):
		return false
	if not _grid.is_free(cell, size):
		return false
	for y: int in range(cell.y, cell.y + size):
		for x: int in range(cell.x, cell.x + size):
			if _reserved[y * _grid.width + x] == 1:
				return false
	if spacing <= 0:
		return true
	for y: int in range(cell.y - spacing, cell.y + size + spacing):
		for x: int in range(cell.x - spacing, cell.x + size + spacing):
			var id := _grid.occupant_at(Vector2i(x, y))
			if id != 0 and _soft[id] == 0:
				return false
	return true


## The fallback: the first spiral cell from `anchor` anywhere in the box, with no spacing; the
## entry is dropped when there is none. Returns its id, 0 when dropped.
func _place_anywhere(entry: Array, anchor: Vector2i) -> int:
	var cell := _spiral(anchor, _catalog.size_of(str(entry[0])), _box, Rect2i(), 0)
	if cell == NO_CELL:
		_dropped += 1
		return 0
	return _add(entry, cell)


func _add(entry: Array, cell: Vector2i) -> int:
	var type: String = entry[0]
	var level: int = entry[1]
	var id := _next_id
	_next_id += 1
	_grid.occupy(id, cell, _catalog.size_of(type))
	var role := _role(type, level)
	_soft.append(1 if role == ROLE_WALL or role == ROLE_TRAP else 0)
	_buildings.append({"id": id, "type": type, "level": level, "cell": [cell.x, cell.y]})
	return id


func _centre_of(id: int) -> Vector2i:
	var building: Dictionary = _buildings[id - 1]
	var cell: Array = building["cell"]
	var size := _catalog.size_of(str(building["type"]))
	return Vector2i(int(cell[0]) + size / 2, int(cell[1]) + size / 2)


static func _cell_list(cell: Vector2i) -> Array:
	return [cell.x, cell.y]
