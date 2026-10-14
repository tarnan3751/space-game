class_name Catalog
extends RefCounted
## Read-only game data from data/*.json: resources, build-menu categories, grid size,
## starting base and building definitions. Pure logic (see CLAUDE.md): no Nodes, no
## engine state.
##
## JSON numbers parse as floats in Godot, so every whole number is converted to
## int on load. Everything handed out by this class is int, never float.

const RULES_PATH := "res://data/rules.json"
const BUILDINGS_PATH := "res://data/buildings.json"
const HQ_TYPE := "command_center"
## The Command Center's category. It is never a build-menu category.
const CORE_CATEGORY := "core"
const TARGETS := ["ground", "air", "both"]
## Per-level fields that must be whole and non-negative when present.
const WHOLE_FIELDS := ["builders", "capacity", "hp", "damage", "range_cells", "fire_ms"]

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

var _buildings: Dictionary = {}
## id -> its rules entry ({"id", "name", "color"}), in rules order.
var _resource_defs: Dictionary = {}
var _category_defs: Dictionary = {}


static func load_default() -> Catalog:
	return from_json(
		FileAccess.get_file_as_string(RULES_PATH),
		FileAccess.get_file_as_string(BUILDINGS_PATH)
	)


static func from_json(rules_text: String, buildings_text: String) -> Catalog:
	var catalog := Catalog.new()
	var rules: Variant = _parse(rules_text)
	var buildings: Variant = _parse(buildings_text)
	if typeof(rules) != TYPE_DICTIONARY or typeof(buildings) != TYPE_DICTIONARY:
		catalog.load_error = "rules or buildings JSON is missing or not an object"
		return catalog
	catalog._read(rules, buildings)
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


## Hidden from an attacker until it triggers (traps, the Cloaked Sentry). Display only for now.
func is_hidden(type: String) -> bool:
	return _def(type).get("hidden", false) == true


## "ground", "air" or "both" for defences and traps; "" when the type has none.
func targets_of(type: String) -> String:
	return str(_def(type).get("targets", ""))


## The number of levels; 0 when `levels` is missing or not a list (validation reports it).
func max_level(type: String) -> int:
	var levels: Variant = _def(type).get("levels", [])
	if typeof(levels) != TYPE_ARRAY:
		return 0
	var level_list: Array = levels
	return level_list.size()


## Stats for one level (1-based): cost, build_seconds, hp, produces, storage, builders...
## Returns an empty Dictionary when the type or level doesn't exist.
func level_stats(type: String, level: int) -> Dictionary:
	var levels: Array = _def(type).get("levels", [])
	if level < 1 or level > levels.size():
		return {}
	return levels[level - 1]


## How many of `type` a base may own at the given Command Center level.
func max_count(type: String, cc_level: int) -> int:
	var counts: Array = _def(type).get("max_count", [])
	if counts.is_empty():
		return 0
	return int(counts[clampi(cc_level, 1, counts.size()) - 1])


## The Command Center's level count: the length of every max_count list.
func max_cc_level() -> int:
	return max_level(HQ_TYPE)


func _def(type: String) -> Dictionary:
	return _buildings.get(type, {})


func _read(rules: Dictionary, buildings: Dictionary) -> void:
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
	load_error = "; ".join(problems)


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
