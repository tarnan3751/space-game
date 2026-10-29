extends HarnessScenario
## The HUD's gallery (docs/reference/hud.md): the debug build's Template base with the build panel
## closed (the top bar, its meters full); the build panel open on the Army tab with its pictures
## made; the Cadet Academy's training page with two Rangers queued; then, on a fresh base (Reset
## base), the Hangar's card held down on the Army tab (on the template every card is maxed), and the
## Resources tab with its locked cards. Checks: the meters' full state on the template, the held
## card's content sunk in a rendered run, the locked cards. Rendered, for its five shots; headless it
## checks the wiring. The sounds: Template base's soft tap and its toast, the base swapped with no
## completion heard (its army, research and stock are counted quietly); the held card pressed when
## let go; the locked card's buzz.

const PRODUCER := "cadet_academy"


func run(main: MainScript) -> void:
	var hud: Hud = main.hud
	var catalog: Catalog = main.state.catalog
	var heard := heard_counts(main)
	main.hud.template_button().pressed.emit()
	await frames(4)
	check_heard(main, heard, &"ui_tap_soft", 1, "Template base pressed")
	check_heard(main, heard, &"toast_info", 1, "Template base pressed")
	for key: StringName in [&"train_done", &"research_done", &"make_done", &"build_done", &"housing_full"]:
		check_heard(main, heard, key, 0, "the base swapped for the template")
	var state: BaseState = main.state
	for res: String in catalog.resources:
		var shader := (hud.resource_fill(res).get_child(0) as CanvasItem).material as ShaderMaterial
		var full: bool = shader.get_shader_parameter(&"full")
		check(full == (state.resources[res] >= state.capacity(res)),
			"the %s meter's full state is %s at %d / %d" % [res, full, state.resources[res], state.capacity(res)])
	await wait_seconds(main, 0.5)
	await screenshot("top")

	await open_build_menu(main)
	hud.tab_button("army").pressed.emit()
	await _pictures(main)
	await screenshot("build-army")
	hud.close_button().pressed.emit()
	await wait_seconds(main, Hud.MENU_CLOSE_SECONDS)

	var academy := _first(state, PRODUCER)
	main.placement.select(academy.id)
	await frames(2)
	hud.action_button().pressed.emit()
	await wait_seconds(main, Hud.MENU_OPEN_SECONDS)
	check(hud.is_training_open(), "Train opened the training page")
	hud.train_card("ranger").pressed.emit()
	hud.train_card("ranger").pressed.emit()
	await frames(2)
	check(hud.queue_shown().size() == 2, "two Rangers queued")
	await _pictures(main)
	await wait_seconds(main, 0.3)
	await screenshot("training")
	hud.army_close_button().pressed.emit()
	main.placement.select(0)
	await wait_seconds(main, Hud.MENU_CLOSE_SECONDS)

	# A card held down, on the fresh base, where the Hangar can be built (on the template every
	# card is maxed, so disabled).
	main.hud.reset_button().pressed.emit()
	await frames(4)
	await open_build_menu(main)
	hud.tab_button("army").pressed.emit()
	await _pictures(main)
	var card := hud.entry_button("hangar")
	var at := card.get_global_rect().get_center()
	touch_screen(main, at, true)
	await frames(3)
	# The press shows on the card's next draw, which a headless run never makes.
	var body := card.get_child(0) as Control
	if DisplayServer.get_name() != "headless":
		check(body.position == Vector2.ONE * Hud.PRESSED_SINK,
			"the held card's content sank to %s" % body.position)
	await screenshot("pressed")
	# Let go: the card is picked, and its placing cancelled.
	heard = heard_counts(main)
	touch_screen(main, at, false)
	await frames(2)
	check_heard(main, heard, &"card_press", 1, "the held card let go")
	if main.placement.is_placing():
		main.placement.cancel_place()
	await open_build_menu(main)
	hud.tab_button("resources").pressed.emit()
	await _pictures(main)
	var locked := PackedStringArray()
	for type: String in catalog.menu_order:
		if catalog.category_of(type) == "resources" and hud.entry_status(type).begins_with("Needs Command Center"):
			locked.append(type)
	check(not locked.is_empty() and hud.entry_button(locked[0]).disabled, "locked cards %s" % ", ".join(locked))
	if not locked.is_empty():
		heard = heard_counts(main)
		await tap_screen(main, hud.entry_button(locked[0]).get_global_rect().get_center())
		check_heard(main, heard, &"ui_denied", 1, "the locked %s tapped" % locked[0])
	await screenshot("locked")
	hud.close_button().pressed.emit()
	await wait_seconds(main, Hud.MENU_CLOSE_SECONDS)


## Waits for the open panel's pictures (a headless run draws none).
func _pictures(main: MainScript) -> void:
	var waited := 0
	while not main.hud.previews_done() and waited < 600:
		await frames(1)
		waited += 1
	await wait_seconds(main, 0.3)


func _first(state: BaseState, type: String) -> BuildingState:
	for id: int in state.buildings:
		if state.buildings[id].type == type:
			return state.buildings[id]
	return null
