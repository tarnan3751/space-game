class_name Catalog
extends RefCounted
## Read-only game data from data/*.json: resources, build-menu categories, grid size,
## starting base, building definitions and unit types. Pure logic (see CLAUDE.md): no Nodes, no
## engine state.
##
## JSON numbers parse as floats in Godot, so every whole number is converted to
## int on load. Everything handed out by this class is int, never float.
##
## The one exception to read-only is apply_dev_cheats(), which a debug build of the game
## calls once after loading (main.gd): every level becomes free and builds in one second at
## most, and so does every unit's training and research. BaseState never knows, so a save made under the cheats is an ordinary save.

const RULES_PATH := "res://data/rules.json"
const BUILDINGS_PATH := "res://data/buildings.json"
const UNITS_PATH := "res://data/units.json"
const HQ_TYPE := "command_center"
## The Command Center's category. It is never a build-menu category.
const CORE_CATEGORY := "core"
const TARGETS := ["ground", "air", "both"]
## Per-level fields that must be whole and non-negative when present. The last eight are the
## battle sim's specials (docs/reference/battle.md).
const WHOLE_FIELDS := ["builders", "capacity", "hp", "damage", "range_cells", "fire_ms",
	"splash_units", "shell_ms", "shield_hp", "shield_regen", "shield_delay_ms", "hold_ms", "stun_ms",
	"throw_cells"]
## A unit's class: walls stop ground units, not air ones.
const UNIT_CLASSES := ["ground", "air"]
## Who is in a unit: a colonist on foot, a machine with a pilot, or none. Display and models only.
const UNIT_CREWS := ["human", "piloted", "autonomous"]
## The building classes a unit prefers as targets and scales its damage against (battle sim).
const TARGET_CLASSES := ["any", "defense", "resource", "wall", "hq"]
## A building's class in battle (battle_class): what a unit's `prefers` picks among. A trap is
## never a target and never counts for destruction.
const CLASS_HQ := "hq"
const CLASS_WALL := "wall"
const CLASS_TRAP := "trap"
const CLASS_DEFENSE := "defense"
const CLASS_RESOURCE := "resource"
const CLASS_OTHER := "other"
## Per-type unit fields that must be whole and non-negative when present.
const UNIT_WHOLE_FIELDS := ["speed", "splash_units"]
## Per-level unit fields that must be whole and non-negative when present.
const UNIT_LEVEL_WHOLE_FIELDS := ["hp", "damage", "fire_ms", "range_units"]
## The fields only a researched level (2 and up) carries.
const RESEARCH_FIELDS := ["research_cost", "research_seconds", "requires_lab"]
## Shared, read-only defaults for lookups, so a lookup builds no new {} or [] per call
## (BaseState's checks run every frame while a ghost is dragged).
const _NONE := {}
const _NO_LIST := []

## Empty when the data loaded and validated cleanly, otherwise a readable list of problems.
var load_error: String = ""
## Resource ids, in rules.resources order.
var resources: PackedStringArray = PackedStringArray()
## Build-menu category ids, in rules.categories order (the tab order).
var categories: PackedStringArray = PackedStringArray()
var grid_size: Vector2i = Vector2i.ZERO
var menu_order: PackedStringArray = PackedStringArray()
## {"resources": {name: int}, "buildings": [{"type", "cell": [x, y], "level"}]}
var start: Dictionary = {}
## rules.army: the building type whose capacity houses the army, and the one that researches.
var housing_type: String = ""
var research_type: String = ""
## Unit type ids in units.json order, the training menu's order.
var unit_order: PackedStringArray = PackedStringArray()
## rules.battle (all 0 or "" when the rules have none): the battle's length in seconds, the wall
## type, the build-menu category whose types are traps, and the extra path cost of entering a
## wall cell, in field units.
var battle_seconds: int = 0
var wall_type: String = ""
var trap_category: String = ""
var wall_cost_units: int = 0

var _buildings: Dictionary = {}
var _units: Dictionary = {}
## rules.battle.loot_pct: resource -> the percent of the defender's stored amount a raid can take.
var _loot_pct: Dictionary = {}
## id -> its rules entry ({"id", "name", "color"}), in rules order.
var _resource_defs: Dictionary = {}
var _category_defs: Dictionary = {}


static func load_default() -> Catalog:
	return from_json(
		FileAccess.get_file_as_string(RULES_PATH),
		FileAccess.get_file_as_string(BUILDINGS_PATH),
		FileAccess.get_file_as_string(UNITS_PATH)
	)


## `units_text` defaults to no unit types; an empty string (a missing file) is an error.
static func from_json(rules_text: String, buildings_text: String, units_text: String = "{}") -> Catalog:
	var catalog := Catalog.new()
	var rules: Variant = _parse(rules_text)
	var buildings: Variant = _parse(buildings_text)
	var units: Variant = _parse(units_text)
	if typeof(rules) != TYPE_DICTIONARY or typeof(buildings) != TYPE_DICTIONARY \
			or typeof(units) != TYPE_DICTIONARY:
		catalog.load_error = "rules, buildings or units JSON is missing or not an object"
		return catalog
	catalog._read(rules, buildings, units)
	return catalog


## A resource's display name; its id when it has none.
func resource_name(id: String) -> String:
	var def: Dictionary = _resource_defs.get(id, {})
	return str(def.get("name", id))


## A resource's colour as a hex string ("c8d3e0"); "" when it has none.
func resource_color(id: String) -> String:
	var def: Dictionary = _resource_defs.get(id, {})
	return str(def.get("color", ""))


## A category's display name; its id when it has none.
func category_name(id: String) -> String:
	var def: Dictionary = _category_defs.get(id, {})
	return str(def.get("name", id))


func has_type(type: String) -> bool:
	return _buildings.has(type)


func types() -> PackedStringArray:
	return PackedStringArray(_buildings.keys())


func display_name(type: String) -> String:
	return str(_def(type).get("name", type))


func size_of(type: String) -> int:
	return int(_def(type).get("size", 1))


## One of `categories`, or CORE_CATEGORY for the Command Center.
func category_of(type: String) -> String:
	return str(_def(type).get("category", ""))


## Hidden from an attacker until it triggers (traps, the Cloaked Sentry).
func is_hidden(type: String) -> bool:
	return _def(type).get("hidden", false) == true


## "ground", "air" or "both" for defences and traps; "" when the type has none.
func targets_of(type: String) -> String:
	return str(_def(type).get("targets", ""))


## The type's class in battle, one of the CLASS_* constants, in this order: the Command Center
## is hq; rules.battle.wall is wall; a type in rules.battle.trap_category is trap; a type with
## `targets`, or whose level 1 has `range_cells`, is defense (the Shield Generator has no
## targets); a type with `produces` or `storage` at some level is resource; the rest are other.
func battle_class(type: String) -> String:
	if type == HQ_TYPE:
		return CLASS_HQ
	if type == wall_type:
		return CLASS_WALL
	if trap_category != "" and category_of(type) == trap_category:
		return CLASS_TRAP
	if targets_of(type) != "" or level_stats(type, 1).has("range_cells"):
		return CLASS_DEFENSE
	for level: int in range(1, max_level(type) + 1):
		var stats := level_stats(type, level)
		if stats.has("produces") or stats.has("storage"):
			return CLASS_RESOURCE
	return CLASS_OTHER


## The percent of the defender's stored `res` a raid can take (rules.battle.loot_pct); 0 when unset.
func loot_pct(res: String) -> int:
	return int(_loot_pct.get(res, 0))


## The number of levels; 0 when `levels` is missing or not a list (validation reports it).
func max_level(type: String) -> int:
	var levels: Variant = _def(type).get("levels", _NO_LIST)
	if typeof(levels) != TYPE_ARRAY:
		return 0
	var level_list: Array = levels
	return level_list.size()


## Stats for one level (1-based): cost, build_seconds, hp, produces, storage, builders...
## Returns a shared, read-only empty Dictionary when the type or level doesn't exist.
func level_stats(type: String, level: int) -> Dictionary:
	var levels: Array = _def(type).get("levels", _NO_LIST)
	if level < 1 or level > levels.size():
		return _NONE
	return levels[level - 1]


## How many of `type` a base may own at the given Command Center level.
func max_count(type: String, cc_level: int) -> int:
	var counts: Array = _def(type).get("max_count", _NO_LIST)
	if counts.is_empty():
		return 0
	return int(counts[clampi(cc_level, 1, counts.size()) - 1])


## The Command Center's level count: the length of every max_count list.
func max_cc_level() -> int:
	return max_level(HQ_TYPE)


func has_unit(type: String) -> bool:
	return _units.has(type)


## Unit type ids in units.json order.
func unit_types() -> PackedStringArray:
	return unit_order


## The unit types `building_type` trains, in units.json order. Builds a new array: for the HUD.
func units_of_producer(building_type: String) -> PackedStringArray:
	var found := PackedStringArray()
	for type: String in unit_order:
		if unit_producer(type) == building_type:
			found.append(type)
	return found


func unit_name(type: String) -> String:
	return str(_unit(type).get("name", type))


## The building type that trains the unit.
func unit_producer(type: String) -> String:
	return str(_unit(type).get("producer", ""))


## The level a producer building needs before it can train the unit.
func unit_producer_level(type: String) -> int:
	return int(_unit(type).get("producer_level", 1))


## "ground" or "air".
func unit_class(type: String) -> String:
	return str(_unit(type).get("class", ""))


## "human", "piloted" or "autonomous". Display and models only.
func unit_crew(type: String) -> String:
	return str(_unit(type).get("crew", ""))


## Housing units one of this type takes in the Hangars.
func unit_housing(type: String) -> int:
	return int(_unit(type).get("housing", 0))


func unit_train_seconds(type: String) -> int:
	return int(_unit(type).get("train_seconds", 0))


## Battle: field units a second.
func unit_speed(type: String) -> int:
	return int(_unit(type).get("speed", 0))


## Battle: the building class it picks first; "any" when it has none.
func unit_prefers(type: String) -> String:
	return str(_unit(type).get("prefers", "any"))


## Battle: splash radius in field units, 0 for one target.
func unit_splash(type: String) -> int:
	return int(_unit(type).get("splash_units", 0))


## Battle: the percent of its damage it does to a building class; 100 unless damage_pct says.
func unit_damage_pct(type: String, building_class: String) -> int:
	var percents: Dictionary = _unit(type).get("damage_pct", _NONE)
	return int(percents.get(building_class, 100))


## Battle: whether its first attack spends it.
func unit_self_destructs(type: String) -> bool:
	return _unit(type).get("self_destruct", false) == true


## The number of levels; 0 when `levels` is missing or not a list (validation reports it).
func unit_max_level(type: String) -> int:
	var levels: Variant = _unit(type).get("levels", _NO_LIST)
	if typeof(levels) != TYPE_ARRAY:
		return 0
	var level_list: Array = levels
	return level_list.size()


## Stats for one unit level (1-based): train_cost, hp, damage, fire_ms, range_units, and from
## level 2 research_cost, research_seconds and requires_lab. Shared and read-only, like
## level_stats, and the same empty Dictionary when the type or level doesn't exist.
func unit_level_stats(type: String, level: int) -> Dictionary:
	var levels: Array = _unit(type).get("levels", _NO_LIST)
	if level < 1 or level > levels.size():
		return _NONE
	return levels[level - 1]


## Debug builds only: every level of every type costs nothing, and one that takes time
## builds in one second. An instant level stays instant, so walls still need no builder and
## paint as fast as the finger moves. Units train and research free in one second. Nothing
## else changes, so the Command Center still gates levels and counts, and the producers and
## the lab still gate units. Call it once, on a catalog that loaded cleanly.
func apply_dev_cheats() -> void:
	for type: String in _buildings:
		var levels: Array = _def(type)["levels"]
		for stats: Dictionary in levels:
			stats["cost"] = {}
			stats["build_seconds"] = mini(int(stats["build_seconds"]), 1)
	for type: String in _units:
		var unit: Dictionary = _units[type]
		unit["train_seconds"] = mini(int(unit["train_seconds"]), 1)
		var unit_levels: Array = unit["levels"]
		for i: int in unit_levels.size():
			var stats: Dictionary = unit_levels[i]
			stats["train_cost"] = {}
			if i > 0:
				stats["research_cost"] = {}
				stats["research_seconds"] = mini(int(stats["research_seconds"]), 1)


func _def(type: String) -> Dictionary:
	return _buildings.get(type, _NONE)


func _unit(type: String) -> Dictionary:
	return _units.get(type, _NONE)


func _read(rules: Dictionary, buildings: Dictionary, units: Dictionary) -> void:
	var problems := PackedStringArray()

	problems.append_array(_read_entries(rules.get("resources", []), "rules.resources", _resource_defs))
	resources = PackedStringArray(_resource_defs.keys())
	if resources.is_empty():
		problems.append("rules.resources is empty")
	for id: String in resources:
		var color := resource_color(id)
		if color != "" and not color.is_valid_html_color():
			problems.append("rules.resources '%s'.color must be a hex colour" % id)

	problems.append_array(_read_entries(rules.get("categories", []), "rules.categories", _category_defs))
	categories = PackedStringArray(_category_defs.keys())
	if categories.has(CORE_CATEGORY):
		problems.append("rules.categories must not list '%s'" % CORE_CATEGORY)

	var grid: Variant = rules.get("grid", {})
	if typeof(grid) == TYPE_DICTIONARY:
		var grid_dict: Dictionary = grid
		if _is_whole(grid_dict.get("width")) and _is_whole(grid_dict.get("height")):
			grid_size = Vector2i(int(grid_dict["width"]), int(grid_dict["height"]))
	if grid_size.x <= 0 or grid_size.y <= 0:
		problems.append("rules.grid needs a positive width and height")

	var start_data: Variant = rules.get("start", {})
	if typeof(start_data) == TYPE_DICTIONARY:
		start = start_data
	else:
		problems.append("rules.start must be an object")

	# Every definition is stored before any is validated: max_count is checked against
	# the Command Center's level count.
	for type: Variant in buildings:
		if typeof(buildings[type]) != TYPE_DICTIONARY:
			problems.append("%s must be an object" % type)
			continue
		var def: Dictionary = buildings[type]
		_buildings[str(type)] = def
	for type: String in _buildings:
		problems.append_array(_validate_building(type, _buildings[type]))

	if not _buildings.has(HQ_TYPE):
		problems.append("buildings needs a '%s'" % HQ_TYPE)

	var menu_data: Variant = rules.get("menu_order", [])
	if typeof(menu_data) != TYPE_ARRAY:
		problems.append("rules.menu_order must be a list")
	else:
		var menu_list: Array = menu_data
		for type: Variant in menu_list:
			var menu_type := str(type)
			if not _buildings.has(menu_type):
				problems.append("menu_order lists unknown type '%s'" % menu_type)
			elif menu_type == HQ_TYPE:
				problems.append("menu_order must not list '%s'" % HQ_TYPE)
			elif menu_order.has(menu_type):
				problems.append("menu_order lists '%s' twice" % menu_type)
			else:
				menu_order.append(menu_type)
		for type: String in _buildings:
			if type != HQ_TYPE and not menu_order.has(type):
				problems.append("menu_order is missing '%s'" % type)

	problems.append_array(_validate_start())
	problems.append_array(_read_army(rules.get("army", {}), units))
	problems.append_array(_read_battle(rules.get("battle", {})))
	load_error = "; ".join(problems)


## rules.battle, optional: a catalog without it has no battle rules (battle_seconds 0).
func _read_battle(battle: Variant) -> PackedStringArray:
	var problems := PackedStringArray()
	if typeof(battle) != TYPE_DICTIONARY:
		problems.append("rules.battle must be an object")
		return problems
	var rules: Dictionary = battle
	if rules.is_empty():
		return problems
	if not _is_whole(rules.get("seconds")) or int(rules["seconds"]) < 1:
		problems.append("rules.battle.seconds must be a whole number of at least 1")
	else:
		battle_seconds = int(rules["seconds"])
	if not _is_whole(rules.get("wall_cost_units", 0)):
		problems.append("rules.battle.wall_cost_units must be whole and non-negative")
	else:
		wall_cost_units = int(rules.get("wall_cost_units", 0))
	wall_type = str(rules.get("wall", ""))
	if rules.has("wall") and not _buildings.has(wall_type):
		problems.append("rules.battle.wall names unknown type '%s'" % wall_type)
	trap_category = str(rules.get("trap_category", ""))
	if rules.has("trap_category") and not categories.has(trap_category):
		problems.append("rules.battle.trap_category must be one of rules.categories")
	var loot: Variant = rules.get("loot_pct", {})
	if typeof(loot) != TYPE_DICTIONARY:
		problems.append("rules.battle.loot_pct must be an object")
		return problems
	var loot_dict: Dictionary = loot
	for res: Variant in loot_dict:
		if not resources.has(str(res)):
			problems.append("rules.battle.loot_pct uses unknown resource '%s'" % res)
		elif not _is_whole(loot_dict[res]) or int(loot_dict[res]) > 100:
			problems.append("rules.battle.loot_pct.%s must be a whole percent, 0-100" % res)
		else:
			_loot_pct[str(res)] = int(loot_dict[res])
	return problems


## rules.army and units.json. Every unit is stored, then validated against the buildings.
func _read_army(army: Variant, units: Dictionary) -> PackedStringArray:
	var problems := PackedStringArray()
	if typeof(army) != TYPE_DICTIONARY:
		problems.append("rules.army must be an object")
	else:
		var army_dict: Dictionary = army
		housing_type = str(army_dict.get("housing", ""))
		research_type = str(army_dict.get("research", ""))
		for field: String in ["housing", "research"]:
			if army_dict.has(field) and not _buildings.has(str(army_dict[field])):
				problems.append("rules.army.%s names unknown type '%s'" % [field, army_dict[field]])
			elif not army_dict.has(field) and not units.is_empty():
				problems.append("rules.army needs a %s type" % field)
	for type: Variant in units:
		if typeof(units[type]) != TYPE_DICTIONARY:
			problems.append("unit %s must be an object" % type)
			continue
		var def: Dictionary = units[type]
		_units[str(type)] = def
		unit_order.append(str(type))
	for type: String in unit_order:
		problems.append_array(_validate_unit(type, _units[type]))
	return problems


func _validate_unit(type: String, def: Dictionary) -> PackedStringArray:
	var problems := PackedStringArray()
	var where := "unit " + type
	var producer := str(def.get("producer", ""))
	if not _buildings.has(producer):
		problems.append("%s.producer must be a building type" % where)
	else:
		var producer_level: Variant = def.get("producer_level", 1)
		if typeof(producer_level) != TYPE_INT or int(producer_level) < 1 \
				or int(producer_level) > max_level(producer):
			problems.append("%s.producer_level must be 1-%d" % [where, max_level(producer)])
	if not UNIT_CLASSES.has(def.get("class")):
		problems.append("%s.class must be ground or air" % where)
	if not UNIT_CREWS.has(def.get("crew")):
		problems.append("%s.crew must be human, piloted or autonomous" % where)
	if not _is_whole(def.get("housing")) or int(def["housing"]) < 1:
		problems.append("%s.housing must be a whole number of at least 1" % where)
	if not _is_whole(def.get("train_seconds")) or int(def["train_seconds"]) < 1:
		problems.append("%s.train_seconds must be a whole number of at least 1" % where)
	for field: String in UNIT_WHOLE_FIELDS:
		if def.has(field) and not _is_whole(def[field]):
			problems.append("%s.%s must be whole and non-negative" % [where, field])
	if def.has("prefers") and not TARGET_CLASSES.has(def["prefers"]):
		problems.append("%s.prefers must be one of %s" % [where, ", ".join(TARGET_CLASSES)])
	if def.has("self_destruct") and typeof(def["self_destruct"]) != TYPE_BOOL:
		problems.append("%s.self_destruct must be true or false" % where)
	if def.has("damage_pct"):
		if typeof(def["damage_pct"]) != TYPE_DICTIONARY:
			problems.append("%s.damage_pct must be an object" % where)
		else:
			var percents: Dictionary = def["damage_pct"]
			for target: Variant in percents:
				if not TARGET_CLASSES.has(target) or not _is_whole(percents[target]):
					problems.append("%s.damage_pct.%s must be a target class and a whole percent" % [
						where, target])

	var levels_data: Variant = def.get("levels", [])
	if typeof(levels_data) != TYPE_ARRAY:
		problems.append("%s.levels must be a list" % where)
		return problems
	var levels: Array = levels_data
	if levels.is_empty():
		problems.append("%s has no levels" % where)
	var lab_levels := max_level(research_type)
	for i: int in levels.size():
		var level_where := "%s level %d" % [where, i + 1]
		if typeof(levels[i]) != TYPE_DICTIONARY:
			problems.append("%s must be an object" % level_where)
			continue
		var stats: Dictionary = levels[i]
		problems.append_array(_validate_amounts(stats, "train_cost", level_where))
		for field: String in UNIT_LEVEL_WHOLE_FIELDS:
			if stats.has(field) and not _is_whole(stats[field]):
				problems.append("%s.%s must be whole and non-negative" % [level_where, field])
		if i == 0:
			for field: String in RESEARCH_FIELDS:
				if stats.has(field):
					problems.append("%s must not have %s: level 1 needs no research" % [level_where, field])
			continue
		problems.append_array(_validate_amounts(stats, "research_cost", level_where))
		if not _is_whole(stats.get("research_seconds")) or int(stats["research_seconds"]) < 1:
			problems.append("%s.research_seconds must be a whole number of at least 1" % level_where)
		var lab: Variant = stats.get("requires_lab")
		if typeof(lab) != TYPE_INT or int(lab) < 1 or int(lab) > lab_levels:
			problems.append("%s.requires_lab must be 1-%d" % [level_where, lab_levels])
	return problems


## A {resource: int} field of `stats`, when present: an object of known resources and whole numbers.
func _validate_amounts(stats: Dictionary, field: String, where: String) -> PackedStringArray:
	var problems := PackedStringArray()
	if typeof(stats.get(field, {})) != TYPE_DICTIONARY:
		problems.append("%s.%s must be an object" % [where, field])
		return problems
	var amounts: Dictionary = stats.get(field, {})
	for res: Variant in amounts:
		if not resources.has(str(res)):
			problems.append("%s.%s uses unknown resource '%s'" % [where, field, res])
		elif typeof(amounts[res]) != TYPE_INT:
			problems.append("%s.%s.%s must be a whole number" % [where, field, res])
	return problems


## The start section: its resources and the buildings a new base is laid out with. The
## shapes checked here are the ones BaseState.create_new reads.
func _validate_start() -> PackedStringArray:
	var problems := PackedStringArray()
	var amounts: Variant = start.get("resources", {})
	if typeof(amounts) != TYPE_DICTIONARY:
		problems.append("rules.start.resources must be an object")
	else:
		var amount_dict: Dictionary = amounts
		for res: Variant in amount_dict:
			if not _is_whole(amount_dict[res]):
				problems.append("rules.start.resources.%s must be whole and non-negative" % res)
	var entries: Variant = start.get("buildings", [])
	if typeof(entries) != TYPE_ARRAY:
		problems.append("rules.start.buildings must be a list")
		return problems
	var entry_list: Array = entries
	for i: int in entry_list.size():
		if typeof(entry_list[i]) != TYPE_DICTIONARY:
			problems.append("rules.start.buildings[%d] must be an object" % i)
			continue
		var entry: Dictionary = entry_list[i]
		var cell: Variant = entry.get("cell", [-1, -1])
		if typeof(cell) != TYPE_ARRAY or cell.size() != 2 \
				or typeof(cell[0]) != TYPE_INT or typeof(cell[1]) != TYPE_INT:
			problems.append("rules.start.buildings[%d].cell must be [x, y]" % i)
		var entry_type := str(entry.get("type", ""))
		if not _buildings.has(entry_type):
			problems.append("start lists unknown type '%s'" % entry_type)
			continue
		var level: Variant = entry.get("level", 1)
		if typeof(level) != TYPE_INT or int(level) < 1 or int(level) > max_level(entry_type):
			problems.append("start lists %s at level %s, outside 1-%d" % [
				entry_type, level, max_level(entry_type)])
	return problems


func _validate_building(type: String, def: Dictionary) -> PackedStringArray:
	var problems := PackedStringArray()
	var cc_levels := max_cc_level()
	var size: Variant = def.get("size", 0)
	if typeof(size) != TYPE_INT or int(size) < 1 or int(size) > 8:
		problems.append("%s.size must be 1-8" % type)
	var category := str(def.get("category", ""))
	if type == HQ_TYPE:
		if category != CORE_CATEGORY:
			problems.append("%s.category must be '%s'" % [type, CORE_CATEGORY])
	elif category == CORE_CATEGORY or not categories.has(category):
		problems.append("%s.category must be one of rules.categories" % type)
	if def.has("hidden") and typeof(def["hidden"]) != TYPE_BOOL:
		problems.append("%s.hidden must be true or false" % type)
	if def.has("targets") and not TARGETS.has(def["targets"]):
		problems.append("%s.targets must be ground, air or both" % type)

	var levels_data: Variant = def.get("levels", [])
	var counts_data: Variant = def.get("max_count", [])
	if typeof(levels_data) != TYPE_ARRAY:
		problems.append("%s.levels must be a list" % type)
	if typeof(counts_data) != TYPE_ARRAY:
		problems.append("%s.max_count must be a list" % type)
	if typeof(levels_data) != TYPE_ARRAY or typeof(counts_data) != TYPE_ARRAY:
		return problems
	var levels: Array = levels_data
	if levels.is_empty():
		problems.append("%s has no levels" % type)
	var counts: Array = counts_data
	var counts_ok := false
	if counts.is_empty():
		problems.append("%s.max_count is empty" % type)
	elif cc_levels > 0 and counts.size() != cc_levels:
		problems.append("%s.max_count needs %d entries, one per Command Center level" % [type, cc_levels])
	else:
		counts_ok = true
		for count: Variant in counts:
			counts_ok = counts_ok and _is_whole(count)
		if not counts_ok:
			problems.append("%s.max_count entries must be whole and non-negative" % type)
	# The first Command Center level that allows one must be the one level 1 requires.
	if type != HQ_TYPE and counts_ok and not levels.is_empty() and typeof(levels[0]) == TYPE_DICTIONARY:
		var first: Dictionary = levels[0]
		var unlock_data: Variant = first.get("requires_cc", 1)
		var unlock := int(unlock_data) if typeof(unlock_data) == TYPE_INT else 0
		if unlock >= 1 and unlock <= counts.size():
			var agrees := int(counts[unlock - 1]) > 0
			for cc: int in range(1, unlock):
				agrees = agrees and int(counts[cc - 1]) == 0
			if not agrees:
				problems.append("%s.max_count must be 0 below Command Center %d and above 0 at it" % [
					type, unlock])

	for i: int in levels.size():
		var where := "%s level %d" % [type, i + 1]
		if typeof(levels[i]) != TYPE_DICTIONARY:
			problems.append("%s must be an object" % where)
			continue
		var stats: Dictionary = levels[i]
		if typeof(stats.get("build_seconds")) != TYPE_INT or int(stats["build_seconds"]) < 0:
			problems.append("%s needs a whole, non-negative build_seconds" % where)
		if stats.has("requires_cc") and cc_levels > 0:
			var required: Variant = stats["requires_cc"]
			if typeof(required) != TYPE_INT or int(required) < 1 or int(required) > cc_levels:
				problems.append("%s.requires_cc must be 1-%d" % [where, cc_levels])
		for field: String in WHOLE_FIELDS:
			if stats.has(field) and not _is_whole(stats[field]):
				problems.append("%s.%s must be whole and non-negative" % [where, field])
		# A shell in flight is held until it lands; the battle sizes that buffer from fire_ms.
		if _is_whole(stats.get("shell_ms", 0)) and int(stats.get("shell_ms", 0)) > 0 \
				and (not _is_whole(stats.get("fire_ms")) or int(stats["fire_ms"]) < 50):
			problems.append("%s fires shells, so its fire_ms must be at least 50" % where)
		for field: String in ["cost", "produces", "storage"]:
			if typeof(stats.get(field, {})) != TYPE_DICTIONARY:
				problems.append("%s.%s must be an object" % [where, field])
				continue
			var amounts: Dictionary = stats.get(field, {})
			for res: Variant in amounts:
				if not resources.has(str(res)):
					problems.append("%s.%s uses unknown resource '%s'" % [where, field, res])
				elif typeof(amounts[res]) != TYPE_INT:
					problems.append("%s.%s.%s must be a whole number" % [where, field, res])
	return problems


## Reads a rules list of {"id", "name", ...} objects into `by_id` (id -> entry, in list
## order) and returns the problems: not a list, an entry without an id, an id listed twice.
static func _read_entries(entries: Variant, where: String, by_id: Dictionary) -> PackedStringArray:
	if typeof(entries) != TYPE_ARRAY:
		return PackedStringArray(["%s must be a list" % where])
	var problems := PackedStringArray()
	var entry_list: Array = entries
	for i: int in entry_list.size():
		var entry: Variant = entry_list[i]
		var id: Variant = null
		if typeof(entry) == TYPE_DICTIONARY:
			var entry_dict: Dictionary = entry
			id = entry_dict.get("id")
		if typeof(id) != TYPE_STRING or str(id).is_empty():
			problems.append("%s[%d] needs an id" % [where, i])
		elif by_id.has(id):
			problems.append("%s lists '%s' twice" % [where, id])
		else:
			by_id[id] = entry
	return problems


static func _is_whole(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and int(value) >= 0


static func _parse(text: String) -> Variant:
	if text.is_empty():
		return null
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return _ints(json.data)


## Recursively turns whole-number floats into ints.
static func _ints(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			var number: float = value
			if number == floorf(number):
				return int(number)
			return number
		TYPE_DICTIONARY:
			var source: Dictionary = value
			var converted_dict := {}
			for key: Variant in source:
				converted_dict[key] = _ints(source[key])
			return converted_dict
		TYPE_ARRAY:
			var source_array: Array = value
			var converted_array := []
			for item: Variant in source_array:
				converted_array.append(_ints(item))
			return converted_array
	return value
