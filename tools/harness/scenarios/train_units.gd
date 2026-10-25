extends HarnessScenario
## The training and research HUD on the debug build's Template base (every producer and the
## Research Lab at their top level, the Hangars built): a Cadet Academy selected by a tap, its
## info panel reading the army's housing and its Train opening the army panel, whose header reads
## it too; two Rangers and a Breacher queued from the cards (the first by a real touch), paid for
## and shown in the queue strip; the newest Ranger cancelled from the strip and refunded; the head
## counted down by the game's tick; the first Ranger trained and housed, on the header's housing
## line.
## Then the Research Lab selected, which closes the training panel, its Research opening the
## research page; the Ranger's next level researched from its card, paid for and shown on the
## progress line, a second research refused while it runs, and the level reached. Last, a tap on
## the panel that reaches nothing behind it, a real tap on another building above the panel that
## selects it and closes the panel, and a Hangar's info panel with the army housed. Then, on a
## fresh base (Reset base) with a Cadet Academy placed and finished at level 1 and no Hangar: the
## header reading "No Hangar", with no bar; the Breacher's card locked
## ("Needs Cadet Academy 2", disabled; a real touch on it queues nothing and reaches nothing
## behind it), a Ranger refused for want of room; the panel's close button back to the info panel
## with the academy still selected; and Build over the open panel closing it and opening the build
## panel. Checks go through BaseState; the screenshots show the look.
## Touches are real input events (Input.parse_input_event), so they take a finger's path.

const PRODUCER := "cadet_academy"
## The camera size the academy is shown at, and where on the screen (as a share of it) it is put,
## above the panel.
const ZOOM := 16.0
const FOCUS := Vector2(0.5, 0.3)

var _world_taps: int = 0


func run(main: MainScript) -> void:
	main.hud.template_button().pressed.emit()
	main.world_input.tapped.connect(func(_at: Vector2) -> void: _world_taps += 1)
	var hud: Hud = main.hud
	var state: BaseState = main.state
	var catalog: Catalog = state.catalog
	await frames(2)
	var capacity := state.housing_capacity()

	var academy := _first(state, PRODUCER)
	_focus(main, academy)
	await frames(4)
	tap_cell(main, academy.cell + Vector2i.ONE)
	await frames(2)
	check(main.placement.selected_id == academy.id, "a tap selected the Cadet Academy (id %d)" % academy.id)
	_world_taps = 0
	check(hud.action_button().is_visible_in_tree() and hud.action_button().text == "Train",
		"its info panel offers Train")
	var housing_line := "Housing %s / %s" % [Format.amount(state.housing_used()), Format.amount(capacity)]
	check(housing_line in hud.info_detail().split("\n"), "its info panel reads %s" % housing_line)
	await screenshot("info-train")
	hud.action_button().pressed.emit()
	await _wait(main, Hud.MENU_OPEN_SECONDS)
	check(hud.is_training_open(), "Train opened the training panel")
	check(hud.army_title() == "%s   Lv %d" % [catalog.display_name(PRODUCER), academy.level],
		"the panel's title: %s" % hud.army_title())
	var panel := hud.army_panel().get_global_rect()
	var screen := main.get_viewport().get_visible_rect()
	check(is_equal_approx(panel.end.y, screen.end.y), "the panel sits on the screen's bottom edge (%s)" % panel)
	var shown := PackedStringArray()
	for unit: String in catalog.unit_types():
		if hud.train_card(unit).is_visible_in_tree():
			shown.append(unit)
	check(shown == catalog.units_of_producer(PRODUCER), "the panel shows the academy's units: %s" % ", ".join(shown))
	_check_housing(hud, state)
	check(hud.queue_shown().is_empty(), "the queue starts empty")

	# Two Rangers and a Breacher; the first Ranger by a real touch on its card.
	var crystal_before: int = state.resources["crystal"]
	await _tap(main, hud.train_card("ranger").get_global_rect().get_center())
	hud.train_card("ranger").pressed.emit()
	hud.train_card("breacher").pressed.emit()
	await frames(2)
	var queued := PackedStringArray(["ranger", "ranger", "breacher"])
	check(state.queue_of(academy.id) == queued, "queued %s" % ", ".join(state.queue_of(academy.id)))
	check(hud.queue_shown() == queued, "the queue strip shows %s" % ", ".join(hud.queue_shown()))
	var cost := 2 * _train_cost(state, "ranger") + _train_cost(state, "breacher")
	check(crystal_before - state.resources["crystal"] == cost, "paid %d crystal for them (expected %d)"
		% [crystal_before - state.resources["crystal"], cost])
	var head_left := Format.duration(state.training_seconds_left(academy.id)) + " left"
	check(hud.queue_head_status() == head_left, "the head reads %s (expected %s)" % [hud.queue_head_status(), head_left])
	check(_world_taps == 0, "no tap on the panel reached the world")
	await screenshot("training")

	# The second entry, a Ranger: the newest Ranger goes, refunded.
	var crystal_queued: int = state.resources["crystal"]
	hud.queue_entry(1).pressed.emit()
	await frames(2)
	queued = PackedStringArray(["ranger", "breacher"])
	check(state.queue_of(academy.id) == queued and hud.queue_shown() == queued,
		"cancelling a Ranger leaves %s" % ", ".join(state.queue_of(academy.id)))
	check(state.resources["crystal"] - crystal_queued == _train_cost(state, "ranger"),
		"the Ranger was refunded %d crystal" % (state.resources["crystal"] - crystal_queued))
	check(hud.toast_text() == "Refunded", "the toast reads %s" % hud.toast_text())
	# Two seconds on (crystal tops up to its cap, so after the refund's check), the game's one-second tick counts the head down (the HUD's tick path).
	advance(2)
	await _wait(main, 1.0)
	head_left = Format.duration(state.training_seconds_left(academy.id)) + " left"
	check(hud.queue_head_status() == head_left, "the tick counted the head down to %s (expected %s)"
		% [hud.queue_head_status(), head_left])

	# The head trains and is housed.
	advance(state.training_seconds_left(academy.id))
	await frames(2)
	check(state.army_count("ranger") == 1 and state.queue_of(academy.id) == PackedStringArray(["breacher"]),
		"the first Ranger is housed, the Breacher next")
	check(hud.train_card_info("ranger") == "Housing %d   Housed 1" % catalog.unit_housing("ranger"),
		"the Ranger card counts it: %s" % hud.train_card_info("ranger"))
	_check_housing(hud, state)
	await screenshot("trained")

	# The Research Lab: selecting it closes the training panel; its Research opens the research.
	var lab := _first(state, catalog.research_type)
	_focus(main, lab)
	await frames(4)
	tap_cell(main, lab.cell + Vector2i.ONE)
	_world_taps = 0
	await _wait(main, Hud.MENU_CLOSE_SECONDS)
	check(main.placement.selected_id == lab.id and not hud.is_training_open() and not hud.army_panel().visible,
		"selecting the Research Lab closed the training panel")
	check(hud.action_button().is_visible_in_tree() and hud.action_button().text == "Research",
		"its info panel offers Research")
	hud.action_button().pressed.emit()
	await _wait(main, Hud.MENU_OPEN_SECONDS)
	check(hud.is_research_open() and hud.research_line() == "No research running",
		"Research opened the research panel: %s" % hud.research_line())
	shown.clear()
	var unlocked := PackedStringArray()
	for unit: String in catalog.unit_types():
		if hud.research_card(unit).is_visible_in_tree():
			shown.append(unit)
		if state.is_unit_unlocked(unit):
			unlocked.append(unit)
	check(not shown.is_empty() and shown == unlocked, "the panel shows the unlocked units: %s" % ", ".join(shown))
	check(hud.research_card_lines("ranger") == PackedStringArray(["Level 1", "Needs Lab %d"
		% int(catalog.unit_level_stats("ranger", 2)["requires_lab"])]), "the Ranger card: %s"
		% " / ".join(hud.research_card_lines("ranger")))
	var crystal_research: int = state.resources["crystal"]
	hud.research_card("ranger").pressed.emit()
	await frames(2)
	var research_cost: Dictionary = catalog.unit_level_stats("ranger", 2)["research_cost"]
	check(state.research_unit == "ranger" and crystal_research - state.resources["crystal"] == int(research_cost["crystal"]),
		"the Ranger's level 2 is being researched, paid %d crystal" % (crystal_research - state.resources["crystal"]))
	var line := "Researching Ranger to Lv 2: %s left" % Format.duration(state.research_seconds_left())
	check(hud.research_line() == line, "the progress line: %s (expected %s)" % [hud.research_line(), line])
	check(hud.research_card_lines("ranger")[1] == "Researching", "the Ranger card says it is researching")
	crystal_research = state.resources["crystal"]
	hud.research_card("breacher").pressed.emit()
	await frames(2)
	check(state.research_unit == "ranger" and state.resources["crystal"] == crystal_research
		and hud.toast_text() == "Research already running",
		"a second research is refused while one runs: %s" % hud.toast_text())
	await screenshot("research")
	advance(state.research_seconds_left())
	await frames(2)
	check(state.unit_level("ranger") == 2 and hud.research_line() == "No research running"
		and hud.research_card_lines("ranger")[0] == "Level 2", "the Ranger reached level 2: %s"
		% " / ".join(hud.research_card_lines("ranger")))

	# A tap on the panel's header reaches nothing behind it; one on a building above the panel
	# selects that building and closes the panel.
	await _tap(main, Vector2(screen.size.x * 0.5, hud.army_panel().get_global_rect().position.y + 30))
	check(_world_taps == 0 and hud.is_research_open() and main.placement.selected_id == lab.id,
		"a tap on the panel's header reached nothing behind it")
	var other := _building_above(main, hud.army_panel().get_global_rect().position.y, lab.id)
	check(other != null, "a building shows above the panel")
	if other != null:
		await _tap(main, main.camera.unproject_position(main.base_view.cell_to_world(other.cell,
			catalog.size_of(other.type))))
		check(_world_taps == 1 and main.placement.selected_id == other.id,
			"a tap above the panel selected the %s (id %d)" % [other.type, other.id])
		await _wait(main, Hud.MENU_CLOSE_SECONDS)
		check(not hud.is_research_open() and not hud.army_panel().visible, "and closed the research panel")
		await screenshot("selected-outside")

	await _hangar_info(main)
	await _fresh_academy(main)


## A Hangar selected by a tap: its info panel keeps the army housed.
func _hangar_info(main: MainScript) -> void:
	var state: BaseState = main.state
	var hangar := _first(state, state.catalog.housing_type)
	_focus(main, hangar)
	await frames(4)
	tap_cell(main, hangar.cell + Vector2i.ONE)
	await frames(2)
	check(main.placement.selected_id == hangar.id, "a tap selected a Hangar (id %d)" % hangar.id)
	var line := "Army housed %s / %s" % [Format.amount(state.housing_used()), Format.amount(state.housing_capacity())]
	check(line in main.hud.info_detail().split("\n"), "its info panel reads %s" % line)
	await screenshot("info-hangar")


## The second part: a level 1 Cadet Academy on a fresh base, with no Hangar.
func _fresh_academy(main: MainScript) -> void:
	var hud: Hud = main.hud
	hud.reset_button().pressed.emit()
	await frames(2)
	var state: BaseState = main.state
	var catalog: Catalog = state.catalog
	check(state.housing_capacity() == 0, "a fresh base has no Hangar")
	main.placement.begin_place(PRODUCER)
	main.placement.confirm_place()
	var academy: BuildingState = state.buildings.get(main.placement.selected_id)
	check(academy != null and academy.type == PRODUCER, "a Cadet Academy is placed and selected")
	if academy == null:
		return
	advance(state.seconds_left(academy.id))
	await frames(2)
	check(academy.level == 1 and not academy.is_busy(), "it is finished at level 1")
	check(hud.action_button().is_visible_in_tree(), "its info panel offers Train")
	check(Hud.NO_HANGAR in hud.info_detail().split("\n"), "with no Hangar its info panel reads: %s" % Hud.NO_HANGAR)
	hud.action_button().pressed.emit()
	await _wait(main, Hud.MENU_OPEN_SECONDS)
	check(hud.is_training_open(), "Train opened the training panel")
	check(hud.housing_text() == "No Hangar: build one to house units" and not hud.housing_bar().is_visible_in_tree(),
		"with no Hangar the header reads: %s" % hud.housing_text())
	var needs := "Needs %s %d" % [catalog.display_name(PRODUCER), catalog.unit_producer_level("breacher")]
	check(hud.train_card("breacher").disabled and hud.train_card_info("breacher") == needs,
		"the Breacher card is locked: %s" % hud.train_card_info("breacher"))
	check(not hud.train_card("ranger").disabled, "the Ranger card is not")
	_world_taps = 0
	await _tap(main, hud.train_card("breacher").get_global_rect().get_center())
	check(_world_taps == 0 and state.queue_of(academy.id).is_empty(),
		"a touch on the locked card queued nothing and reached nothing behind it")
	hud.train_card("ranger").pressed.emit()
	await frames(2)
	check(state.queue_of(academy.id).is_empty() and hud.toast_text() == "Not enough room in the Hangars",
		"a Ranger with no Hangar is refused: %s" % hud.toast_text())
	await screenshot("locked")

	# The close button goes back to the info panel, the academy still selected.
	hud.army_close_button().pressed.emit()
	await _wait(main, Hud.MENU_CLOSE_SECONDS)
	check(not hud.is_training_open() and not hud.army_panel().visible and hud.action_button().is_visible_in_tree()
		and main.placement.selected_id == academy.id, "the close button showed the info panel, the academy still selected")

	# Build over the open panel closes it and opens the build panel.
	hud.action_button().pressed.emit()
	await _wait(main, Hud.MENU_OPEN_SECONDS)
	check(hud.is_training_open(), "Train opened the training panel again")
	hud.build_button().pressed.emit()
	await _wait(main, Hud.MENU_OPEN_SECONDS)
	check(hud.is_menu_open() and not hud.is_training_open() and not hud.army_panel().visible
		and main.placement.selected_id == 0, "Build closed the training panel, cleared the selection and opened the build panel")


## The training header's housing line and bar against the state's housing.
func _check_housing(hud: Hud, state: BaseState) -> void:
	var used := state.housing_used()
	var capacity := state.housing_capacity()
	var expected := "Housing %s / %s" % [Format.amount(used), Format.amount(capacity)]
	check(hud.housing_text() == expected, "the header reads %s (expected %s)" % [hud.housing_text(), expected])
	var track := (hud.housing_fill().get_parent() as Control).size.x
	var width := roundf(track * used / capacity)
	if used > 0:
		width = maxf(width, Hud.HOUSING_MIN_FILL)
	check(hud.housing_bar().is_visible_in_tree() and hud.housing_fill().size.x == width,
		"the housing bar is filled %d of %d px (expected %d)" % [hud.housing_fill().size.x, track, width])


func _first(state: BaseState, type: String) -> BuildingState:
	for id: int in state.buildings:
		if state.buildings[id].type == type:
			return state.buildings[id]
	return null


func _train_cost(state: BaseState, unit: String) -> int:
	var stats := state.catalog.unit_level_stats(unit, state.unit_level(unit))
	var cost: Dictionary = stats.get("train_cost", {})
	return int(cost.get("crystal", 0))


## Puts `building` at FOCUS of the screen at camera size ZOOM.
func _focus(main: MainScript, building: BuildingState) -> void:
	var size := main.state.catalog.size_of(building.type)
	var at := main.base_view.cell_to_world(building.cell, size)
	var screen := main.get_viewport().get_visible_rect().size
	main.camera.zoom_at(main.camera.size / ZOOM, screen * 0.5)
	var spot := screen * FOCUS
	main.camera.pan(spot, spot - main.camera.unproject_position(at))


## A building other than `skip` whose footprint's centre is on the screen above `top`, clear of
## the top bar.
func _building_above(main: MainScript, top: float, skip: int) -> BuildingState:
	var screen := main.get_viewport().get_visible_rect().size
	for id: int in main.state.buildings:
		var building: BuildingState = main.state.buildings[id]
		if id == skip or building.type == PlacementController.PAINT_TYPE:
			continue
		var at := main.camera.unproject_position(main.base_view.cell_to_world(building.cell,
			main.state.catalog.size_of(building.type)))
		if at.x > 100 and at.x < screen.x - 100 and at.y > 160 and at.y < top - 40:
			return building
	return null


func _wait(main: MainScript, seconds: float) -> void:
	await main.get_tree().create_timer(seconds + 0.05).timeout
	await frames(2)


func _tap(main: MainScript, point: Vector2) -> void:
	for pressed: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.position = main.get_viewport().get_final_transform() * point
		touch.pressed = pressed
		Input.parse_input_event(touch)
		await frames(2)
