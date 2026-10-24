extends HarnessScenario
## The battle sim on the real data (docs/reference/battle.md): a scripted attack on the debug
## build's template base (TemplateBase: every type at its Command Center 10 count and top level,
## every resource at its cap), with one Orbital Strike called on a defence two seconds in, run to
## the end headless, with its duration, destruction, stars and loot logged, then run again to
## check the result and its hash repeat. The result is applied to a copy of the game's base given
## the attacking army and the strike, never to main.state, since no player action leads to a raid
## yet: the deployed units and the strike must be spent and the loot capped by the copy's storage.
##
## It also logs the run's wall time, read here in the tool and never in the sim, as the
## performance budget's measure: a full battle in well under 2 s on the development Mac. Each
## tick's step is timed in both runs and the faster of the two kept, so a moment the machine
## spent elsewhere does not count; the slowest tick must be under TICK_BUDGET_MS. Over it while
## the average tick is over LOADED_AVERAGE_MS, the machine is taken to be loaded and the tick is
## logged, not failed.

## Five of the eleven unit types, the Hangars' 280 housing, each at its top level (a level is
## clamped).
const ARMY := {"ranger": 100, "brawler": 40, "jet_trooper": 20, "hover_tank": 5, "gunship": 2}
const LEVEL := 8
## One Orbital Strike at its top level (clamped), called at tick 40 on the first defence.
const ABILITIES := {"orbital_strike": 1}
const ABILITY_LEVEL := 5
const STRIKE_TICK := 40
## The slowest tick's budget, four full path searches (BattleArmy.PATHS_PER_TICK) with room to
## spare, and the average tick above which the machine counts as loaded (about 0.13 ms on the
## development Mac when it is not).
const TICK_BUDGET_MS := 3.5
const LOADED_AVERAGE_MS := 0.4


func run(main: MainScript) -> void:
	var catalog: Catalog = main.catalog
	var template := TemplateBase.build(catalog, catalog.grid_size, now())
	var levels := {}
	for unit: String in ARMY:
		levels[unit] = LEVEL
	var setup := {
		"seed": 7,
		"attacker": {"army": ARMY, "unit_levels": levels, "abilities": ABILITIES,
			"ability_levels": {"orbital_strike": ABILITY_LEVEL}},
		"defender": {"buildings": template["buildings"], "resources": template["resources"]},
		"commands": [],
	}
	var probe := BattleSim.create(catalog, setup)
	check(probe.setup_error == "", "the template base sets up a battle: '%s'" % probe.setup_error)
	if probe.setup_error != "":
		return
	var cells: Array[Vector2i] = []
	for y: int in catalog.grid_size.y:
		for x: int in catalog.grid_size.x:
			if probe.is_deploy_cell(Vector2i(x, y)):
				cells.append(Vector2i(x, y))
	check(not cells.is_empty(), "%d deploy cells round the template base" % cells.size())
	# The army in three groups a second apart: in the open pockets the template leaves at the
	# right of the resources and army bands, and below the base.
	var points: Array[Vector2i] = [Vector2i(42, 9), Vector2i(40, 19), Vector2i(24, catalog.grid_size.y - 1)]
	for point: Vector2i in points:
		check(probe.is_deploy_cell(point), "%s is a deploy cell" % point)
	var commands := []
	var n := 0
	for unit: String in ARMY:
		for k: int in int(ARMY[unit]):
			var cell := points[n % 3]
			commands.append({"op": "deploy", "tick": (n % 3) * 20, "unit": unit, "cell": [cell.x, cell.y]})
			n += 1
	var aim := {}
	for entry: Dictionary in template["buildings"]:
		if catalog.battle_class(str(entry["type"])) == Catalog.CLASS_DEFENSE:
			aim = entry
			break
	var aim_cell: Array = aim["cell"]
	commands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["tick"]) < int(b["tick"]))
	# Inserted after the sort, which is not stable, so the deploys keep the order they had without it.
	var at := 0
	while at < commands.size() and int(commands[at]["tick"]) <= STRIKE_TICK:
		at += 1
	commands.insert(at, {"op": "ability", "tick": STRIKE_TICK, "ability": "orbital_strike", "cell": aim_cell})
	setup["commands"] = commands
	var landing := STRIKE_TICK + int(catalog.ability_level_stats("orbital_strike", ABILITY_LEVEL)["delay_ms"]) \
		/ BattleSim.TICK_MS
	var watch := BattleSim.create(catalog, setup)
	var aim_id := int(aim["id"])
	while watch.tick <= landing:
		watch.step()
	check(watch.is_destroyed(aim_id) or watch.building_hp(aim_id) < watch.building_max_hp(aim_id),
		"the strike on %s %d at %s landed at tick %d: %d of %d hull left" % [aim["type"], aim_id, aim_cell,
			landing, watch.building_hp(aim_id), watch.building_max_hp(aim_id)])

	var ticks := PackedInt32Array()
	var started := Time.get_ticks_usec()
	var result := _timed_run(catalog, setup, ticks)
	var ms := (Time.get_ticks_usec() - started) / 1000
	var again := _timed_run(catalog, setup, ticks)
	var total := 0
	var slowest := 0
	for t: int in ticks.size():
		total += ticks[t]
		if ticks[t] > ticks[slowest]:
			slowest = t
	var average := total / 1000.0 / ticks.size()
	var worst := ticks[slowest] / 1000.0
	say("battle: %d buildings, %d units, %d s of battle (%d ticks) in %d ms" % [
		probe.layout.count, n, int(result["ticks"]) / BattleSim.TICKS_PER_SECOND, result["ticks"], ms])
	say("battle: destruction %d%%, %d stars, loot %s" % [result["destruction"], result["stars"], result["loot"]])
	check(int(result["ticks"]) > 0 and int(result["ticks"]) <= probe.ticks_total(), "the battle ran and ended")
	var deployed := 0
	var deployed_dict: Dictionary = result["deployed"]
	for unit: String in deployed_dict:
		deployed += int(deployed_dict[unit])
	check(deployed == n, "all %d units deployed (%d)" % [n, deployed])
	check(int(result["destruction"]) > 0, "the attack destroyed something")
	check(ms < 2000, "a battle simulates in under 2 s (%d ms)" % ms)
	var tick_line := "the sim's step %.3f ms on average, %.3f ms at the slowest (tick %d), the faster of two runs" % [
		average, worst, slowest]
	if worst > TICK_BUDGET_MS and average > LOADED_AVERAGE_MS:
		say("battle: %s: over the %.1f ms budget, but the machine is loaded (average over %.1f ms)" % [tick_line,
			TICK_BUDGET_MS, LOADED_AVERAGE_MS])
	else:
		check(worst <= TICK_BUDGET_MS, "battle: %s, budget %.1f ms" % [tick_line, TICK_BUDGET_MS])
	check(JSON.stringify(again) == JSON.stringify(result), "the same setup gives the same result, hash %d" % result["hash"])
	check(result["abilities_used"] == {"orbital_strike": 1}, "the strike is used: %s" % result["abilities_used"])

	var base := BaseState.from_dict(catalog, main.state.to_dict())
	for unit: String in ARMY:
		base.army[unit] = int(ARMY[unit])
	base.ability_stock["orbital_strike"] = 1
	var battle := setup.duplicate(true)
	battle["commands"] = result["commands"]
	var carried := result.duplicate(true)
	carried.erase("commands")
	var before := {}
	for res: String in catalog.resources:
		before[res] = base.resources[res]
	var error := base.apply({"op": "raid_result", "battle": battle, "result": carried}, now())
	check(error == "", "the result applies to a copy of the base: '%s'" % error)
	var spent := true
	for unit: String in ARMY:
		spent = spent and base.army_count(unit) == int(ARMY[unit]) - int(deployed_dict.get(unit, 0))
	check(spent, "the deployed units are spent")
	check(base.stock("orbital_strike") == 0, "the strike is spent")
	var capped := true
	var loot: Dictionary = result["loot"]
	for res: String in catalog.resources:
		var expected := maxi(int(before[res]), mini(base.capacity(res), int(before[res]) + int(loot[res])))
		capped = capped and base.resources[res] == expected
	check(capped, "the loot came home up to storage: %s" % base.resources)
	check(base.raids.size() == 1, "the battle is kept with its result")


## Runs a battle to its end tick by tick, as BattleSim.run does, keeping in `ticks` each tick's
## step time in microseconds, the lower of this run's and what is there; returns the result.
func _timed_run(catalog: Catalog, setup: Dictionary, ticks: PackedInt32Array) -> Dictionary:
	var sim := BattleSim.create(catalog, setup)
	while not sim.is_over():
		var at := Time.get_ticks_usec()
		sim.step()
		var spent := Time.get_ticks_usec() - at
		if sim.tick > ticks.size():
			ticks.append(spent)
		elif spent < ticks[sim.tick - 1]:
			ticks[sim.tick - 1] = spent
	return sim.result()
