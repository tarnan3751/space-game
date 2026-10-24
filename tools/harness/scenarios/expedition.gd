extends HarnessScenario
## Expeditions on the real data (docs/reference/expeditions.md), headless: a copy of the debug
## build's template base (TemplateBase, Command Center 10, every resource at its cap) with a fixed
## sector seed lays out its six fields, each logged and checked to set up a battle; the battle
## scenario's army (the 280 housing at its top levels) attacks the even field from the four edges;
## the result is applied with the expedition key, and the field must be cleared exactly when the
## attack took a star (the attack's outcome is the development balance's, so it is logged, not
## checked); then a scan opens new fields. main.state is never touched.
##
## It logs each field's and the whole sector's layout time, read here in the tool and never in the
## generator.

const ARMY := {"ranger": 100, "brawler": 40, "jet_trooper": 20, "hover_tank": 5, "gunship": 2}
const LEVEL := 8
const SECTOR_SEED := 20261024
## The even band's first field.
const EVEN := 2


func run(main: MainScript) -> void:
	var catalog: Catalog = main.catalog
	var base := BaseState.from_dict(catalog, TemplateBase.build(catalog, catalog.grid_size, now()))
	base.sector.sector_seed = SECTOR_SEED
	for unit: String in ARMY:
		base.army[unit] = int(ARMY[unit])
		base.unit_levels[unit] = mini(LEVEL, catalog.unit_max_level(unit))
	check(base.sector.cc == catalog.max_cc_level(), "the template base's snapshot is Command Center %d" % base.sector.cc)

	var started := Time.get_ticks_usec()
	var fields: Array[Dictionary] = []
	for index: int in catalog.expedition_field_count():
		var field_started := Time.get_ticks_usec()
		var field := OutpostGenerator.generate(catalog, base, index)
		var ms := (Time.get_ticks_usec() - field_started) / 1000
		fields.append(field)
		var defender: Dictionary = field["defender"]
		var buildings: Array = defender["buildings"]
		say("expedition: field %d %s, outpost CC %d, %d buildings, %d rings, %d deposits, %d hazards, loot %s, %d ms" % [
			index, field["band"], field["cc"], buildings.size(), (field["rings"] as Array).size(),
			(field["deposits"] as Array).size(), (field["hazards"] as Array).size(), field["loot"], ms])
		check(int(field["dropped"]) == 0, "field %d drops nothing" % index)
		var probe := BattleSim.create(catalog, OutpostGenerator.battle_setup(field, ARMY, base.unit_levels))
		check(probe.setup_error == "", "field %d sets up a battle: '%s'" % [index, probe.setup_error])
	var sector_ms := (Time.get_ticks_usec() - started) / 1000
	say("expedition: six fields in %d ms" % sector_ms)
	check(JSON.stringify(OutpostGenerator.generate(catalog, base, EVEN)) == JSON.stringify(fields[EVEN]),
		"the even field lays out the same again")

	# The army from the four edges' middles, a second apart.
	var field: Dictionary = fields[EVEN]
	var setup := OutpostGenerator.battle_setup(field, ARMY, base.unit_levels)
	var last := catalog.grid_size - Vector2i.ONE
	var points: Array[Vector2i] = [Vector2i(last.x / 2, 0), Vector2i(last.x, last.y / 2),
		Vector2i(last.x / 2, last.y), Vector2i(0, last.y / 2)]
	var commands := []
	var n := 0
	for unit: String in ARMY:
		for k: int in int(ARMY[unit]):
			var cell := points[n % 4]
			commands.append({"op": "deploy", "tick": (n % 4) * 20, "unit": unit, "cell": [cell.x, cell.y]})
			n += 1
	commands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["tick"]) < int(b["tick"]))
	setup["commands"] = commands
	var battle_started := Time.get_ticks_usec()
	var result := BattleSim.run(catalog, setup)
	var battle_ms := (Time.get_ticks_usec() - battle_started) / 1000
	check(not result.is_empty(), "the even field's battle runs")
	if result.is_empty():
		return
	say("expedition: even field fought, %d s, destruction %d%%, %d stars, loot %s, %d ms" % [
		int(result["ticks"]) / BattleSim.TICKS_PER_SECOND, result["destruction"], result["stars"],
		result["loot"], battle_ms])

	var battle := setup.duplicate(true)
	battle["commands"] = result["commands"]
	var carried := result.duplicate(true)
	carried.erase("commands")
	var command := {"op": "raid_result", "battle": battle, "result": carried,
		"expedition": {"epoch": base.sector.epoch, "index": EVEN}}
	var error := base.apply(command, now())
	check(error == "", "the result applies with the expedition key: '%s'" % error)
	# The clear rule either way: a star clears the field, none leaves it open. Which one this attack
	# gets is the balance's (the development values), so it is logged, not checked.
	var starred := int(result["stars"]) >= 1
	say("expedition: the attack %s" % ("takes a star: the field is cleared" if starred
		else "takes no star: the field stays open"))
	check(base.sector.is_cleared(EVEN) == starred, "the even field is cleared exactly when a star is taken")
	var logged: Dictionary = base.raids[base.raids.size() - 1]
	check(logged.has("expedition") and not (logged["battle"] as Dictionary).has("defender"),
		"the raid is logged with the field's inputs, not its layout")
	if starred:
		check(base.check_raid_result(command) == BaseState.ERR_BAD_EXPEDITION, "a cleared field is refused")

	var seeds := {}
	for entry: Dictionary in base.sector_fields():
		seeds[entry["seed"]] = true
	check(base.apply({"op": "scan"}, now()) == "", "the first scan is free")
	check(base.sector.epoch == 1 and base.sector.cleared.is_empty(), "a scan starts epoch 1 with nothing cleared")
	var fresh := true
	for entry: Dictionary in base.sector_fields():
		fresh = fresh and not seeds.has(entry["seed"])
	check(fresh, "every field is new after the scan")
	check(base.check_scan() == BaseState.ERR_SCAN_COOLDOWN, "the next scan waits %d s" % base.scan_seconds_left())
