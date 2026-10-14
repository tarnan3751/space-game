class_name Catalog
extends RefCounted
## Read-only game data from data/*.json: resources, grid size, starting base and
## building definitions. Pure logic (see CLAUDE.md): no Nodes, no engine state.
##
## JSON numbers parse as floats in Godot, so every whole number is converted to
## int on load. Everything handed out by this class is int, never float.

const RULES_PATH := "res://data/rules.json"
const BUILDINGS_PATH := "res://data/buildings.json"
const HQ_TYPE := "command_center"

## Empty when the data loaded and validated cleanly, otherwise a readable list of problems.
var load_error: String = ""
var resources: PackedStringArray = PackedStringArray()
var grid_size: Vector2i = Vector2i.ZERO
var menu_order: PackedStringArray = PackedStringArray()
## {"resources": {name: int}, "buildings": [{"type", "cell": [x, y], "level"}]}
var start: Dictionary = {}

var _buildings: Dictionary = {}


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


func has_type(type: String) -> bool:
	return _buildings.has(type)


func types() -> PackedStringArray:
	return PackedStringArray(_buildings.keys())


func display_name(type: String) -> String:
	return str(_def(type).get("name", type))


func size_of(type: String) -> int:
	return int(_def(type).get("size", 1))


func max_level(type: String) -> int:
	var levels: Array = _def(type).get("levels", [])
	return levels.size()


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


func _def(type: String) -> Dictionary:
	return _buildings.get(type, {})


func _read(rules: Dictionary, buildings: Dictionary) -> void:
	var problems := PackedStringArray()

	for resource_name: Variant in rules.get("resources", []):
		resources.append(str(resource_name))
	if resources.is_empty():
		problems.append("rules.resources is empty")

	var grid: Dictionary = rules.get("grid", {})
	grid_size = Vector2i(int(grid.get("width", 0)), int(grid.get("height", 0)))
	if grid_size.x <= 0 or grid_size.y <= 0:
		problems.append("rules.grid needs a positive width and height")

	start = rules.get("start", {})

	for type: Variant in buildings:
		var def: Dictionary = buildings[type]
		_buildings[str(type)] = def
		problems.append_array(_validate_building(str(type), def))

	if not _buildings.has(HQ_TYPE):
		problems.append("buildings needs a '%s'" % HQ_TYPE)

	for type: Variant in rules.get("menu_order", []):
		if _buildings.has(str(type)):
			menu_order.append(str(type))
		else:
			problems.append("menu_order lists unknown type '%s'" % type)

	for entry: Variant in start.get("buildings", []):
		var entry_dict: Dictionary = entry
		var entry_type := str(entry_dict.get("type", ""))
		if not _buildings.has(entry_type):
			problems.append("start lists unknown type '%s'" % entry_type)

	load_error = "; ".join(problems)


func _validate_building(type: String, def: Dictionary) -> PackedStringArray:
	var problems := PackedStringArray()
	var size := int(def.get("size", 0))
	if size < 1 or size > 8:
		problems.append("%s.size must be 1-8" % type)
	var counts: Array = def.get("max_count", [])
	if counts.is_empty():
		problems.append("%s.max_count is empty" % type)
	var levels: Array = def.get("levels", [])
	if levels.is_empty():
		problems.append("%s has no levels" % type)
	for i: int in levels.size():
		var stats: Dictionary = levels[i]
		var where := "%s level %d" % [type, i + 1]
		if typeof(stats.get("build_seconds")) != TYPE_INT or int(stats["build_seconds"]) < 0:
			problems.append("%s needs a whole, non-negative build_seconds" % where)
		for field: String in ["cost", "produces", "storage"]:
			var amounts: Dictionary = stats.get(field, {})
			for res: Variant in amounts:
				if not resources.has(str(res)):
					problems.append("%s.%s uses unknown resource '%s'" % [where, field, res])
				elif typeof(amounts[res]) != TYPE_INT:
					problems.append("%s.%s.%s must be a whole number" % [where, field, res])
	return problems


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
