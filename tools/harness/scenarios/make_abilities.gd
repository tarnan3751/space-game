extends HarnessScenario
## The Foundry's HUD (docs/reference/hud.md, **Making panel**, **Research panel**) on the debug
## build's Template base (every building at its top level, the Nanite Foundry and the Research Lab
## included): the Foundry selected by a tap, its info panel's stock line and Make, which opens the
## making page; two abilities queued from their cards, paid for and shown in the queue strip; the
## newest cancelled from the strip and refunded; the first made into the stock, on its card and on
## the stock line. Then the Research Lab: its research page lists the abilities after the units, an
## ability's next level researched from its card, paid for and shown on the progress line, and the
## level reached. Checks go through BaseState; the screenshots show the look. Each step's sound
## is checked as it plays (Audio.play_count): the Foundry's voice, Make's whoosh, a card's press,
## the refund, an ability made, the research's press and finish.

const FIRST := "repair_swarm"
const SECOND := "emp_burst"
## The camera size the buildings are shown at, and where on the screen they are put, above the
## panel.
const ZOOM := 16.0
const FOCUS := Vector2(0.5, 0.3)


func run(main: MainScript) -> void:
	main.hud.template_button().pressed.emit()
	await frames(2)
	var hud: Hud = main.hud
	var state: BaseState = main.state
	var catalog: Catalog = state.catalog
	var foundry := _first(state, catalog.foundry_type)
	check(foundry != null, "the template base has a %s" % catalog.foundry_type)
	if foundry == null:
		return
	_focus(main, foundry)
	await frames(4)
	var heard := heard_counts(main)
	tap_cell(main, foundry.cell + Vector2i.ONE)
	await frames(2)
	check_heard(main, heard, Sounds.select_key(catalog.category_of(foundry.type)), 1, "the Foundry tapped")
	var stock_line := "Stock %d / %d" % [state.stock_total(), state.foundry_capacity()]
	check(main.placement.selected_id == foundry.id and hud.action_button().text == "Make"
		and hud.info_detail().contains(stock_line),
		"a tap selected the Foundry; its info panel offers Make and reads %s" % stock_line)
	await screenshot("info-make")
	heard = heard_counts(main)
	hud.action_button().pressed.emit()
	await wait_seconds(main, Hud.MENU_OPEN_SECONDS)
	check(hud.is_making_open(), "Make opened the making page")
	check_heard(main, heard, &"ui_open", 1, "Make pressed")
	for ability: String in catalog.ability_types():
		check(hud.make_card(ability).is_visible_in_tree() and hud.make_card_info(ability) == "In stock 0",
			"%s's card shows, in stock 0 (%s)" % [ability, hud.make_card_info(ability)])

	var crystal: int = state.resources["crystal"]
	heard = heard_counts(main)
	hud.make_card(FIRST).pressed.emit()
	hud.make_card(SECOND).pressed.emit()
	await frames(2)
	# Two presses in one frame: the second inside the tap's cooldown.
	check_heard(main, heard, &"card_press", 1, "two making cards pressed in a frame")
	var queued := PackedStringArray([FIRST, SECOND])
	check(state.making_queue_of(foundry.id) == queued and hud.queue_shown() == queued,
		"queued %s, shown in the strip" % ", ".join(hud.queue_shown()))
	var cost := _make_cost(state, FIRST) + _make_cost(state, SECOND)
	check(crystal - state.resources["crystal"] == cost, "paid %d crystal (expected %d)"
		% [crystal - state.resources["crystal"], cost])
	var head := Format.duration(state.making_seconds_left(foundry.id)) + " left"
	check(hud.queue_head_status() == head, "the head reads %s (expected %s)" % [hud.queue_head_status(), head])
	await screenshot("making")

	crystal = state.resources["crystal"]
	heard = heard_counts(main)
	hud.queue_entry(1).pressed.emit()
	await frames(2)
	check_heard(main, heard, &"queue_refund", 1, "the newest cancelled")
	check(state.making_queue_of(foundry.id) == PackedStringArray([FIRST]) and hud.toast_text() == "Refunded"
		and state.resources["crystal"] - crystal == _make_cost(state, SECOND),
		"the newest cancelled and refunded %d crystal: %s" % [state.resources["crystal"] - crystal, hud.toast_text()])
	heard = heard_counts(main)
	advance(state.making_seconds_left(foundry.id))
	await frames(2)
	check_heard(main, heard, &"make_done", 1, "the head made")
	check(state.stock(FIRST) == 1 and hud.queue_shown().is_empty() and hud.make_card_info(FIRST) == "In stock 1",
		"the %s is made into the stock: %s" % [FIRST, hud.make_card_info(FIRST)])
	await screenshot("made")
	hud.army_close_button().pressed.emit()
	await wait_seconds(main, Hud.MENU_CLOSE_SECONDS)
	stock_line = "Stock 1 / %d" % state.foundry_capacity()
	check(hud.info_detail().contains(stock_line), "the stock line reads %s" % stock_line)

	# The Research Lab: the abilities after the units, one researched.
	var lab := _first(state, catalog.research_type)
	_focus(main, lab)
	await frames(4)
	tap_cell(main, lab.cell + Vector2i.ONE)
	await wait_seconds(main, Hud.MENU_CLOSE_SECONDS)
	hud.action_button().pressed.emit()
	await wait_seconds(main, Hud.MENU_OPEN_SECONDS)
	check(hud.is_research_open(), "Research opened the research page")
	for ability: String in catalog.ability_types():
		check(hud.research_ability_card(ability).is_visible_in_tree(), "%s's research card shows: %s"
			% [ability, " / ".join(hud.research_ability_card_lines(ability))])
	crystal = state.resources["crystal"]
	heard = heard_counts(main)
	hud.research_ability_card(FIRST).pressed.emit()
	await frames(2)
	check_heard(main, heard, &"card_press", 1, "the %s's research card pressed" % FIRST)
	var research_cost: Dictionary = catalog.ability_level_stats(FIRST, 2)["research_cost"]
	check(state.research_ability == FIRST and crystal - state.resources["crystal"] == int(research_cost["crystal"]),
		"the %s's level 2 is being researched, paid %d crystal" % [FIRST, crystal - state.resources["crystal"]])
	var line := "Researching %s to Lv 2: %s left" % [catalog.ability_name(FIRST),
		Format.duration(state.research_seconds_left())]
	check(hud.research_line() == line and hud.research_ability_card_lines(FIRST)[1] == "Researching",
		"the progress line: %s (expected %s)" % [hud.research_line(), line])
	hud.research_card("ranger").pressed.emit()
	await frames(2)
	check(state.research_unit == "" and hud.toast_text() == "Research already running",
		"a unit's research waits for the ability's: %s" % hud.toast_text())
	# The abilities' cards sit after the units': the strip scrolled to them for the shot.
	var card := hud.research_ability_card(FIRST)
	var strip := card.get_parent().get_parent().get_parent() as ScrollContainer
	strip.ensure_control_visible(hud.research_ability_card(catalog.ability_types()[-1]))
	await frames(4)
	await screenshot("research")
	heard = heard_counts(main)
	advance(state.research_seconds_left())
	await frames(2)
	check_heard(main, heard, &"research_done", 1, "the ability's research finished")
	check(state.ability_level(FIRST) == 2 and hud.research_line() == ""
		and hud.research_ability_card_lines(FIRST)[0] == "Level 2",
		"the %s reached level 2: %s" % [FIRST, " / ".join(hud.research_ability_card_lines(FIRST))])


func _first(state: BaseState, type: String) -> BuildingState:
	var found: BuildingState = null
	for id: int in state.buildings:
		var building: BuildingState = state.buildings[id]
		if building.type == type and (found == null or id < found.id):
			found = building
	return found


func _make_cost(state: BaseState, ability: String) -> int:
	var stats := state.catalog.ability_level_stats(ability, state.ability_level(ability))
	return int((stats["make_cost"] as Dictionary).get("crystal", 0))


## Puts `building` at FOCUS of the screen at camera size ZOOM.
func _focus(main: MainScript, building: BuildingState) -> void:
	var size := main.state.catalog.size_of(building.type)
	var at := main.base_view.cell_to_world(building.cell, size)
	zoom_to(main, ZOOM, at, FOCUS)
