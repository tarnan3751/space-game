extends SceneTree
## Batch battles for balance (docs/reference/battle.md, **Tools**): runs a scripted attack for N
## seeds against a layout on the shipped data, headless, and writes one CSV row per seed. Run it
## after an import (tools/gates.sh does one), from the project root:
##
##   $GODOT --headless --path . -s res://tools/sim_battles.gd -- [--seeds=10] \
##       [--army=ranger:100,brawler:40] [--level=3] [--cc=5] [--outpost=2] \
##       [--strategy=random] [--abilities=repair_swarm:2,emp_burst:1] \
##       [--layout=<save.json>] [--out=<file.csv>]
##
## The layout is the debug build's template base (TemplateBase: every type at its Command Center
## 10 count, at its top level, every resource at its cap) unless --layout names a save file,
## which is only read, or --outpost names an expedition field index: then each seed lays out that
## field of sector seed `seed`, epoch 0, with OutpostGenerator against a player of Command Center
## --cc (5 by default) holding the capacity of every storage at its count and top allowed level,
## as tools/gen_outposts.gd does. --cc also sets every unit's and ability's level to the highest
## a base of that level can have researched (its best Research Lab's), unless --level gives one
## level for all (3 by default without --cc; clamped to each).
##
## Each seed's attack is drawn with the tool's own SeededRng; the sim itself draws nothing.
## --strategy picks how:
##   random     one to four deploy points among the layout's deploy cells (the default);
##   edge       three points on one drawn side of the field;
##   two_edges  two points on each of two drawn sides, the army alternating between them;
##   waves      three points on one drawn side, the tanks (a unit whose hull at its level is 150
##              or more) first, the rest five seconds later.
## A point on a side is the deploy cell nearest the base along a line in from the field's edge.
## Each unit is deployed at a tick in the first three seconds of its wave; then, for each ability
## brought (none by default), a tick from 3 to 8 seconds and a cell: a swarm on one of the deploy
## points, a burst or a strike on a defence's cell. Without --out the CSV goes to stdout; a
## summary line (the stars and the mean destruction) goes to stderr. The ms column is wall time,
## read here, in the tool, never in the sim: it is how the performance budget is measured.

const DEFAULT_ARMY := "ranger:100,brawler:40,jet_trooper:20,hover_tank:5,gunship:2"
const STRATEGIES := ["random", "edge", "two_edges", "waves"]
## A unit with this much hull at its level or more is a tank, in the first wave.
const TANK_HP := 150
## Ticks between the two waves' starts (five seconds).
const WAVE_GAP_TICKS := 100


func _init() -> void:
	var options := _options()
	var catalog := Catalog.load_default()
	if catalog.load_error != "":
		printerr("sim_battles: the data does not load: ", catalog.load_error)
		quit(1)
		return
	var strategy := str(options.get("strategy", "random"))
	if not STRATEGIES.has(strategy):
		printerr("sim_battles: --strategy is one of ", ", ".join(STRATEGIES))
		quit(1)
		return
	var outpost := int(options.get("outpost", "-1"))
	var cc := clampi(int(options.get("cc", "5")), 1, catalog.max_cc_level())
	if outpost >= catalog.expedition_field_count():
		printerr("sim_battles: %d is not a field" % outpost)
		quit(1)
		return
	var capacity := _capacity(catalog, cc)
	var defender := {}
	if outpost < 0:
		defender = _defender(catalog, str(options.get("layout", "")))
		if defender.is_empty():
			quit(1)
			return
	var army := _army(str(options.get("army", DEFAULT_ARMY)))
	var abilities := _army(str(options.get("abilities", "")))
	var lab := _best_level(catalog, catalog.research_type, cc)
	var levels := {}
	for unit: String in army:
		levels[unit] = _researched(catalog, unit, false, lab) if _by_cc(options) else int(options.get("level", "3"))
	var ability_levels := {}
	for ability: String in abilities:
		ability_levels[ability] = _researched(catalog, ability, true, lab) if _by_cc(options) \
			else int(options.get("level", "3"))
	var seeds := int(options.get("seeds", "10"))
	var lines := PackedStringArray()
	var header := PackedStringArray(["seed", "ticks", "destruction", "stars"])
	for res: String in catalog.resources:
		header.append("loot_" + res)
	header.append_array(PackedStringArray(["deployed", "abilities", "ms"]))
	lines.append(",".join(header))
	var star_counts := [0, 0, 0, 0]
	var destruction_sum := 0
	for seed_value: int in range(1, seeds + 1):
		if outpost >= 0:
			var field := OutpostGenerator.generate_field(catalog, seed_value, 0, outpost, cc, capacity)
			defender = field["defender"]
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
		var commands := _commands(seed_value, strategy, army, levels, probe, cells, catalog, abilities,
			defences)
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
		var stars: int = result["stars"]
		star_counts[stars] += 1
		destruction_sum += int(result["destruction"])
		var row := PackedStringArray([str(seed_value), str(result["ticks"]), str(result["destruction"]),
			str(stars)])
		var loot: Dictionary = result["loot"]
		for res: String in catalog.resources:
			row.append(str(loot[res]))
		row.append_array(PackedStringArray([str(deployed), str(used), str(ms)]))
		lines.append(",".join(row))
	printerr("sim_battles: %s, %d seeds: stars 0/1/2/3 %d/%d/%d/%d, mean destruction %d%%" % [
		strategy, seeds, star_counts[0], star_counts[1], star_counts[2], star_counts[3],
		destruction_sum / maxi(seeds, 1)])
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


## Whether the levels come from --cc: it is given and --level is not.
func _by_cc(options: Dictionary) -> bool:
	return options.has("cc") and not options.has("level")


func _army(spec: String) -> Dictionary:
	var army := {}
	for part: String in spec.split(",", false):
		var pair := part.split(":")
		army[pair[0]] = int(pair[1]) if pair.size() > 1 else 1
	return army


## The highest level of `type` whose `requires_cc` a Command Center of level `cc` allows; 0 when
## none does.
func _best_level(catalog: Catalog, type: String, cc: int) -> int:
	var best := 0
	for level: int in range(1, catalog.max_level(type) + 1):
		if int(catalog.level_stats(type, level).get("requires_cc", 1)) <= cc:
			best = level
	return best


## The highest level of a unit (or an ability) a Research Lab of level `lab` can have researched.
func _researched(catalog: Catalog, id: String, ability: bool, lab: int) -> int:
	var top := catalog.ability_max_level(id) if ability else catalog.unit_max_level(id)
	var best := 1
	for level: int in range(2, top + 1):
		var stats := catalog.ability_level_stats(id, level) if ability else catalog.unit_level_stats(id, level)
		if int(stats.get("requires_lab", 0)) <= lab:
			best = level
	return best


## A base of that level (its Command Center at it) with every storage at its count and its top
## allowed level.
func _capacity(catalog: Catalog, cc: int) -> Dictionary[String, int]:
	var capacity: Dictionary[String, int] = {}
	for res: String in catalog.resources:
		capacity[res] = 0
	for type: String in catalog.types():
		# The Command Center's level k requires k - 1, so a base of level cc has it at cc.
		var best := cc if type == Catalog.HQ_TYPE else maxi(_best_level(catalog, type, cc), 1)
		var storage: Dictionary = catalog.level_stats(type, best).get("storage", {})
		for res: Variant in storage:
			capacity[str(res)] += int(storage[res]) * catalog.max_count(type, cc)
	return capacity


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


## The scripted attack of a seed (the header's strategies): the units, in army order, spread over
## the strategy's deploy points, each at a tick in the first three seconds of its wave; then each
## ability at a tick from 3 to 8 seconds, a swarm on a deploy point, a burst or a strike on a
## defence; the commands in tick order. The abilities are drawn after the deploys, so an attack
## without them is unchanged, and `random` draws as the tool always has.
func _commands(seed_value: int, strategy: String, army: Dictionary, levels: Dictionary,
		probe: BattleSim, cells: Array[Vector2i], catalog: Catalog, abilities: Dictionary,
		defences: Array[Vector2i]) -> Array:
	var rng := SeededRng.new(seed_value)
	var points: Array[Vector2i] = []
	if strategy == "random":
		for i: int in rng.range_int(1, 4):
			points.append(cells[rng.range_int(0, cells.size() - 1)])
	else:
		var sides := 2 if strategy == "two_edges" else 1
		var first := rng.range_int(0, 3)
		for s: int in sides:
			var side := (first + s * (1 + rng.range_int(0, 2))) % 4 if s > 0 else first
			var along := rng.range_int(10, catalog.grid_size.x - 11)
			for offset: int in ([-4, 4] if sides == 2 else [-6, 0, 6]):
				var point := _side_point(probe, catalog.grid_size, side, along + offset)
				if point.x >= 0:
					points.append(point)
		if points.is_empty():
			points.append(cells[rng.range_int(0, cells.size() - 1)])
	var by_tick: Array[Array] = []
	by_tick.resize(60 + WAVE_GAP_TICKS + 1)
	for i: int in by_tick.size():
		by_tick[i] = []
	var n := 0
	for unit: String in army:
		var start := 0
		if strategy == "waves" and int(catalog.unit_level_stats(unit, clampi(int(levels[unit]), 1,
				catalog.unit_max_level(unit))).get("hp", 0)) < TANK_HP:
			start = WAVE_GAP_TICKS
		for k: int in int(army[unit]):
			var cell := points[n % points.size()]
			by_tick[start + rng.range_int(0, 59)].append({"op": "deploy", "unit": unit, "cell": [cell.x, cell.y]})
			n += 1
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


## The deploy cell nearest the base on the line `along` in from side `side` (0 top, 1 right,
## 2 bottom, 3 left): the last deploy cell walking in from the edge. (-1, -1) when the edge cell
## is not one.
func _side_point(probe: BattleSim, size: Vector2i, side: int, along: int) -> Vector2i:
	var span := size.y if side == 1 or side == 3 else size.x
	along = clampi(along, 0, span - 1)
	var found := Vector2i(-1, -1)
	var depth := size.x if side == 1 or side == 3 else size.y
	for d: int in depth:
		var cell: Vector2i
		match side:
			0: cell = Vector2i(along, d)
			1: cell = Vector2i(size.x - 1 - d, along)
			2: cell = Vector2i(along, size.y - 1 - d)
			_: cell = Vector2i(d, along)
		if not probe.is_deploy_cell(cell):
			break
		found = cell
	return found
