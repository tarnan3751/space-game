extends SceneTree
## Expedition outposts for inspection (docs/reference/expeditions.md): lays out the sector's fields
## with OutpostGenerator on the shipped data, headless, and writes them as JSON. Run it after an
## import (tools/gates.sh does one), from the project root:
##
##   $GODOT --headless --path . -s res://tools/gen_outposts.gd -- [--cc=5] [--seed=1] \
##       [--epoch=0] [--index=2] [--out=<file.json>] [--ascii]
##
## --cc is the player's Command Center level (the scan's), --seed the sector seed; the player's
## capacity is what a base of that level holds with every storage at its count and top allowed
## level. Without --index every field of the sector is laid out. The JSON is {"fields": [...]},
## each field as OutpostGenerator.generate_field returns it; without --out it goes to stdout.
## --ascii also prints each field as a map (H the Command Center, S storage, C collector, O other,
## D defence, T trap, # wall, . free, a space inside the margin). A summary line per field goes to
## stderr with its wall time, read here, in the tool, never in the generator.

const MARKS := {"hq": "H", "storage": "S", "collector": "C", "other": "O", "defense": "D", "trap": "T",
	"wall": "#"}


func _init() -> void:
	var options := _options()
	var catalog := Catalog.load_default()
	if catalog.load_error != "":
		printerr("gen_outposts: the data does not load: ", catalog.load_error)
		quit(1)
		return
	var cc := clampi(int(options.get("cc", "5")), 1, catalog.max_cc_level())
	var sector_seed := int(options.get("seed", "1"))
	var epoch := int(options.get("epoch", "0"))
	var capacity := _capacity(catalog, cc)
	var indices: Array[int] = []
	if options.has("index"):
		indices.append(int(options["index"]))
	else:
		for i: int in catalog.expedition_field_count():
			indices.append(i)
	var fields := []
	var total_ms := 0
	for index: int in indices:
		var started := Time.get_ticks_usec()
		var field := OutpostGenerator.generate_field(catalog, sector_seed, epoch, index, cc, capacity)
		var ms := (Time.get_ticks_usec() - started) / 1000
		total_ms += ms
		if field.is_empty():
			printerr("gen_outposts: %d is not a field" % index)
			quit(1)
			return
		var defender: Dictionary = field["defender"]
		var buildings: Array = defender["buildings"]
		printerr("field %d: %s, outpost CC %d, %d buildings, %d rings, dropped %d, loot %s, %d ms" % [
			index, field["band"], field["cc"], buildings.size(), (field["rings"] as Array).size(),
			field["dropped"], field["loot"], ms])
		if options.has("ascii"):
			print(_ascii(catalog, field))
		fields.append(field)
	printerr("gen_outposts: %d fields in %d ms" % [fields.size(), total_ms])
	var text := JSON.stringify({"fields": fields}, "  ")
	var out := str(options.get("out", ""))
	if out == "":
		if not options.has("ascii"):
			print(text)
	else:
		var file := FileAccess.open(out, FileAccess.WRITE)
		if file == null:
			printerr("gen_outposts: cannot write ", out)
			quit(1)
			return
		file.store_string(text + "\n")
	quit(0)


## A base of that level (its Command Center at it) with every storage at its count and its top
## allowed level.
func _capacity(catalog: Catalog, cc: int) -> Dictionary[String, int]:
	var capacity: Dictionary[String, int] = {}
	for res: String in catalog.resources:
		capacity[res] = 0
	for type: String in catalog.types():
		# The Command Center's level k requires k - 1, so a base of level cc has it at cc.
		var best := cc if type == Catalog.HQ_TYPE else 1
		if type != Catalog.HQ_TYPE:
			for level: int in range(1, catalog.max_level(type) + 1):
				if int(catalog.level_stats(type, level).get("requires_cc", 1)) <= cc:
					best = level
		var storage: Dictionary = catalog.level_stats(type, best).get("storage", {})
		for res: Variant in storage:
			capacity[str(res)] += int(storage[res]) * catalog.max_count(type, cc)
	return capacity


func _ascii(catalog: Catalog, field: Dictionary) -> String:
	var size := catalog.grid_size
	var margin: int = catalog.expedition["margin"]
	var rows: Array[PackedStringArray] = []
	for y: int in size.y:
		var row := PackedStringArray()
		for x: int in size.x:
			var inside := x >= margin and y >= margin and x < size.x - margin and y < size.y - margin
			row.append("." if inside else " ")
		rows.append(row)
	var defender: Dictionary = field["defender"]
	for building: Dictionary in defender["buildings"]:
		var type: String = building["type"]
		var cell: Array = building["cell"]
		var mark: String = MARKS.get(_role_name(catalog, type, int(building["level"])), "?")
		var deposits: Array = field["deposits"]
		var hazards: Array = field["hazards"]
		if deposits.has(building["id"]):
			mark = "$"
		elif hazards.has(building["id"]):
			mark = "!"
		for dy: int in catalog.size_of(type):
			for dx: int in catalog.size_of(type):
				rows[int(cell[1]) + dy][int(cell[0]) + dx] = mark
	var lines := PackedStringArray(["field %d (%s, CC %d)" % [field["index"], field["band"], field["cc"]]])
	for row: PackedStringArray in rows:
		lines.append("".join(row))
	return "\n".join(lines)


func _role_name(catalog: Catalog, type: String, level: int) -> String:
	var cls := catalog.battle_class(type)
	if cls == Catalog.CLASS_RESOURCE:
		var storage: Dictionary = catalog.level_stats(type, level).get("storage", {})
		return "storage" if not storage.is_empty() else "collector"
	return cls


func _options() -> Dictionary:
	var options := {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			var parts := arg.substr(2).split("=", true, 1)
			options[parts[0]] = parts[1] if parts.size() > 1 else ""
	return options
