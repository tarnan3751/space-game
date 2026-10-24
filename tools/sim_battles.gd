extends SceneTree
## Batch battles for balance (docs/reference/battle.md, **Tools**): runs a scripted attack for N
## seeds against a layout on the shipped data, headless, and writes one CSV row per seed. Run it
## after an import (tools/gates.sh does one), from the project root:
##
##   $GODOT --headless --path . -s res://tools/sim_battles.gd -- [--seeds=10] \
##       [--army=ranger:100,brawler:40] [--level=3] [--abilities=repair_swarm:2,emp_burst:1] \
##       [--layout=<save.json>] [--out=<file.csv>]
##
## The layout is the debug build's template base (TemplateBase: every type at its Command Center
## 10 count, at its top level, every resource at its cap) unless --layout names a save file,
## which is only read. Each seed draws, with the tool's own SeededRng, one to four deploy points
## among the layout's deploy cells and a deploy tick for each unit in the first three seconds,
## then, for each ability brought (none by default; at --level, clamped), a tick from 3 to 8
## seconds and a cell: a swarm on one of the deploy points, a burst or a strike on a defence's
## cell. The sim itself draws nothing. Without --out the CSV goes to stdout. The ms column is wall time,
## read here, in the tool, never in the sim: it is how the performance budget is measured.

const DEFAULT_ARMY := "ranger:100,brawler:40,jet_trooper:20,hover_tank:5,gunship:2"


func _init() -> void:
	var options := _options()
	var catalog := Catalog.load_default()
	if catalog.load_error != "":
		printerr("sim_battles: the data does not load: ", catalog.load_error)
		quit(1)
		return
	var defender := _defender(catalog, str(options.get("layout", "")))
	if defender.is_empty():
		quit(1)
		return
	var army := _army(str(options.get("army", DEFAULT_ARMY)))
	var abilities := _army(str(options.get("abilities", "")))
	var level := int(options.get("level", "3"))
	var levels := {}
	for unit: String in army:
		levels[unit] = level
	var ability_levels := {}
	for ability: String in abilities:
		ability_levels[ability] = level
	var seeds := int(options.get("seeds", "10"))
	var lines := PackedStringArray()
	var header := PackedStringArray(["seed", "ticks", "destruction", "stars"])
	for res: String in catalog.resources:
		header.append("loot_" + res)
	header.append_array(PackedStringArray(["deployed", "abilities", "ms"]))
	lines.append(",".join(header))
	var probe := BattleSim.create(catalog, _setup(1, army, levels, abilities, ability_levels, defender, []))
	if probe.setup_error != "":
		printerr("sim_battles: ", probe.setup_error)
		quit(1)
		return
	var cells: Array[Vector2i] = []
	for y: int in catalog.grid_size.y:
		for x: int in catalog.grid_size.x:
			if probe.is_deploy_cell(Vector2i(x, y)):
				cells.append(Vector2i(x, y))
	var defences: Array[Vector2i] = []
	for id: int in probe.building_ids():
		var b := probe.layout.index_of(id)
		if probe.layout.classes[b] == BattleLayout.DEFENSE:
			defences.append(Vector2i(probe.layout.cell_x[b], probe.layout.cell_y[b]))
	for seed_value: int in range(1, seeds + 1):
		var commands := _commands(seed_value, army, cells, catalog, abilities, defences)
		var setup := _setup(seed_value, army, levels, abilities, ability_levels, defender, commands)
		var started := Time.get_ticks_usec()
		var result := BattleSim.run(catalog, setup)
		var ms := (Time.get_ticks_usec() - started) / 1000
		var deployed := 0
		var deployed_dict: Dictionary = result["deployed"]
		for unit: Variant in deployed_dict:
			deployed += int(deployed_dict[unit])
		var used := 0
		var used_dict: Dictionary = result["abilities_used"]
		for ability: Variant in used_dict:
			used += int(used_dict[ability])
		var row := PackedStringArray([str(seed_value), str(result["ticks"]), str(result["destruction"]),
			str(result["stars"])])
		var loot: Dictionary = result["loot"]
		for res: String in catalog.resources:
			row.append(str(loot[res]))
		row.append_array(PackedStringArray([str(deployed), str(used), str(ms)]))
		lines.append(",".join(row))
	var text := "\n".join(lines) + "\n"
	var out := str(options.get("out", ""))
	if out == "":
		print(text)
	else:
		var file := FileAccess.open(out, FileAccess.WRITE)
		if file == null:
			printerr("sim_battles: cannot write ", out)
			quit(1)
			return
		file.store_string(text)
		print("sim_battles: %d battles written to %s" % [seeds, out])
	quit(0)


## --key=value user arguments.
func _options() -> Dictionary:
	var options := {}
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--") and argument.contains("="):
			var parts := argument.substr(2).split("=", true, 1)
			options[parts[0]] = parts[1]
	return options


func _army(spec: String) -> Dictionary:
	var army := {}
	for part: String in spec.split(",", false):
		var pair := part.split(":")
		army[pair[0]] = int(pair[1]) if pair.size() > 1 else 1
	return army


## {"buildings", "resources"} of the template base or of a save file.
func _defender(catalog: Catalog, path: String) -> Dictionary:
	var data: Dictionary = {}
	if path == "":
		data = TemplateBase.build(catalog, catalog.grid_size, 0)
	else:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) != TYPE_DICTIONARY:
			printerr("sim_battles: cannot read the layout ", path)
			return {}
		data = parsed
	return {"buildings": data.get("buildings", []), "resources": data.get("resources", {})}


func _setup(seed_value: int, army: Dictionary, levels: Dictionary, abilities: Dictionary,
		ability_levels: Dictionary, defender: Dictionary, commands: Array) -> Dictionary:
	return {
		"seed": seed_value,
		"attacker": {"army": army, "unit_levels": levels, "abilities": abilities,
			"ability_levels": ability_levels},
		"defender": defender,
		"commands": commands,
	}


## The scripted attack of a seed: the units, in army order, spread over one to four deploy
## points, each at a tick in the first three seconds; then each ability at a tick from 3 to 8
## seconds, a swarm on a deploy point, a burst or a strike on a defence; the commands in tick
## order. The abilities are drawn after the deploys, so an attack without them is unchanged.
func _commands(seed_value: int, army: Dictionary, cells: Array[Vector2i], catalog: Catalog,
		abilities: Dictionary, defences: Array[Vector2i]) -> Array:
	var rng := SeededRng.new(seed_value)
	var points: Array[Vector2i] = []
	for i: int in rng.range_int(1, 4):
		points.append(cells[rng.range_int(0, cells.size() - 1)])
	var by_tick: Array[Array] = []
	by_tick.resize(60)
	for i: int in by_tick.size():
		by_tick[i] = []
	var n := 0
	for unit: String in army:
		for k: int in int(army[unit]):
			var cell := points[n % points.size()]
			by_tick[rng.range_int(0, 59)].append({"op": "deploy", "unit": unit, "cell": [cell.x, cell.y]})
			n += 1
	# Ticks 60 to 160 for the abilities.
	by_tick.resize(161)
	for i: int in range(60, by_tick.size()):
		by_tick[i] = []
	for ability: String in abilities:
		for k: int in int(abilities[ability]):
			var tick := rng.range_int(60, 160)
			var cell := points[rng.range_int(0, points.size() - 1)]
			if catalog.ability_effect(ability) != Catalog.EFFECT_SWARM and not defences.is_empty():
				cell = defences[rng.range_int(0, defences.size() - 1)]
			by_tick[tick].append({"op": "ability", "ability": ability, "cell": [cell.x, cell.y]})
	var commands := []
	for tick: int in by_tick.size():
		for command: Dictionary in by_tick[tick]:
			command["tick"] = tick
			commands.append(command)
	return commands
