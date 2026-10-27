extends HarnessScenario
## The UI pass's three skins (docs/reference/hud.md, **Skins**) side by side, for the owner to pick
## from: for each of A, B and C, set through Hud.set_skin, the debug build's Template base with the
## build panel closed (the top bar, its meters full); the build panel open on the Army tab with its
## pictures made; the Cadet Academy's training page with two Rangers queued; then, on a fresh base
## (Reset base), the Hangar's card held down on the Army tab (on the template every card is maxed),
## and the Resources tab with its locked cards. Each shot is named
## after its skin. Checks: the theme each skin builds, the meters' full state on the template, the
## held card's content sunk (A and C) or the card squashed (B) in a rendered run, the locked cards. Rendered, for
## its fifteen shots; headless it checks the wiring.

const PRODUCER := "cadet_academy"
const SKINS: Array[Hud.Look] = [Hud.Look.A, Hud.Look.B, Hud.Look.C]


func run(main: MainScript) -> void:
	var hud: Hud = main.hud
	for look: Hud.Look in SKINS:
		var label: String = Hud.Look.keys()[look]
		hud.set_skin(look)
		await _shoot(main, label.to_lower())
	hud.set_skin(Hud.Look.A)


func _shoot(main: MainScript, label: String) -> void:
	var hud: Hud = main.hud
	var catalog: Catalog = main.state.catalog
	var card_box := hud.ui_theme().get_stylebox("normal", "CardButton")
	check((card_box is StyleBoxTexture) == (Hud.skin == Hud.Look.B),
		"%s: the cards' shape is a %s" % [label, card_box.get_class()])
	main.hud.template_button().pressed.emit()
	await frames(4)
	var state: BaseState = main.state
	for res: String in catalog.resources:
		var shader := (hud.resource_fill(res).get_child(0) as CanvasItem).material as ShaderMaterial
		var full: bool = shader.get_shader_parameter(&"full")
		check(full == (state.resources[res] >= state.capacity(res)),
			"%s: the %s meter's full state is %s at %d / %d" % [label, res, full, state.resources[res], state.capacity(res)])
	await wait_seconds(main, 0.5)
	await screenshot("%s-01-top" % label)

	await open_build_menu(main)
	hud.tab_button("army").pressed.emit()
	await _pictures(main)
	await screenshot("%s-02-build-army" % label)
	hud.close_button().pressed.emit()
	await wait_seconds(main, Hud.MENU_CLOSE_SECONDS)

	var academy := _first(state, PRODUCER)
	main.placement.select(academy.id)
	await frames(2)
	hud.action_button().pressed.emit()
	await wait_seconds(main, Hud.MENU_OPEN_SECONDS)
	check(hud.is_training_open(), "%s: Train opened the training page" % label)
	hud.train_card("ranger").pressed.emit()
	hud.train_card("ranger").pressed.emit()
	await frames(2)
	check(hud.queue_shown().size() == 2, "%s: two Rangers queued" % label)
	await _pictures(main)
	await wait_seconds(main, 0.3)
	await screenshot("%s-04-training" % label)
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
	if DisplayServer.get_name() == "headless":
		pass
	elif Hud.skin == Hud.Look.B:
		check(card.scale != Vector2.ONE and body.position == Vector2.ZERO,
			"%s: the held card squashes (%s)" % [label, card.scale])
	else:
		check(body.position == Vector2.ONE * Hud.PRESSED_SINK,
			"%s: the held card's content sank to %s" % [label, body.position])
	await screenshot("%s-03-pressed" % label)
	# Let go: the card is picked, and its placing cancelled.
	touch_screen(main, at, false)
	await frames(2)
	if main.placement.is_placing():
		main.placement.cancel_place()
	await open_build_menu(main)
	hud.tab_button("resources").pressed.emit()
	await _pictures(main)
	var locked := PackedStringArray()
	for type: String in catalog.menu_order:
		if catalog.category_of(type) == "resources" and hud.entry_status(type).begins_with("Needs Command Center"):
			locked.append(type)
	check(not locked.is_empty() and hud.entry_button(locked[0]).disabled, "%s: locked cards %s" % [label, ", ".join(locked)])
	await screenshot("%s-05-locked" % label)
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
