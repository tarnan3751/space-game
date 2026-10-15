extends HarnessScenario
## The HUD on a fresh base: the meters and drone ring, the Build button and the panel it slides
## up (tabs, cards, close button), a card picked into the place bar, a purchase, a wide window.
## Touches are real input events (Input.parse_input_event), so they take a finger's path.

var _world_taps: int = 0


func run(main: MainScript) -> void:
	var state: BaseState = main.state
	var catalog: Catalog = state.catalog
	var hud: Hud = main.hud
	main.world_input.tapped.connect(func(_at: Vector2) -> void: _world_taps += 1)
	await frames(2)
	check(not hud.resource_panel("antimatter").visible, "a fresh base hides antimatter")
	_check_top_bar(hud, state)
	check(not hud.is_menu_open() and hud.build_button().is_visible_in_tree(), "the panel starts closed, Build showing")
	await screenshot("closed")
	await _tap(main, main.get_viewport().get_visible_rect().size * Vector2(0.4, 1.0) - Vector2(0, 100))
	check(_world_taps == 1, "a tap where the closed panel opens reached the world")
	main.placement.select(0)

	# Build opens the panel on the first tab; a tap on each tab shows its cards.
	await open_build_menu(main)
	check(hud.tab_button(catalog.categories[0]).button_pressed, "the first tab is selected")
	for category: String in catalog.categories:
		await _tap(main, hud.tab_button(category).get_global_rect().get_center())
		var shown := PackedStringArray()
		var expected := PackedStringArray()
		for type: String in catalog.menu_order:
			if catalog.category_of(type) == category:
				expected.append(type)
			if hud.entry_button(type).is_visible_in_tree():
				shown.append(type)
		check(shown == expected, "the %s tab shows %s" % [category, ", ".join(shown)])
		await screenshot("open-" + category)

	# A locked card is disabled and says what it needs. Taps on the panel's empty top row, on a
	# meter and on the drone ring stop there; the close button closes the panel.
	var locked: String = Array(catalog.menu_order).filter(func(type: String) -> bool:
		return int(catalog.level_stats(type, 1).get("requires_cc", 1)) > state.cc_level())[0]
	await _tap(main, hud.tab_button(catalog.category_of(locked)).get_global_rect().get_center())
	check(hud.entry_button(locked).disabled and hud.entry_status(locked).begins_with("Needs Command Center"),
		"%s is disabled: %s" % [locked, hud.entry_status(locked)])
	for at: Vector2 in [hud.close_button().get_global_rect().get_center() - Vector2(120, 0),
			hud.resource_panel("metal").get_global_rect().get_center(), hud.drones_panel().get_global_rect().get_center()]:
		await _tap(main, at)
	await _tap(main, hud.close_button().get_global_rect().get_center())
	await _wait(main, Hud.MENU_CLOSE_SECONDS)
	check(not hud.is_menu_open() and not hud.close_button().is_visible_in_tree(), "the close button closed the panel")
	check(_world_taps == 1, "no touch on the panel, a meter or the ring reached the world (%d did)" % (_world_taps - 1))

	# Picking a card closes the panel and begins placing; the place bar takes Build's place.
	await open_build_menu(main)
	await _tap(main, hud.tab_button(catalog.category_of("metal_extractor")).get_global_rect().get_center())
	check(hud.entry_status("metal_extractor") == "0 / %d" % catalog.max_count("metal_extractor", state.cc_level()),
		"Metal Extractor reads %s" % hud.entry_status("metal_extractor"))
	var card_at := hud.entry_button("metal_extractor").get_global_rect().get_center()
	_touch(main, card_at, true)
	await frames(2)
	await screenshot("card-pressed")
	_touch(main, card_at, false)
	await _wait(main, Hud.MENU_CLOSE_SECONDS)
	check(main.placement.placing_type == "metal_extractor" and not hud.is_menu_open(), "the card closed the panel, placing")
	check(hud.place_button().is_visible_in_tree() and not hud.build_button().is_visible_in_tree(), "the place bar hid Build")
	await screenshot("place-bar")
	main.placement.cancel_place()
	await frames(2)
	check(hud.build_button().is_visible_in_tree(), "Build is back after cancelling")

	# A purchase lowers the metal meter and busies the ring's drone.
	var metal_before := hud.resource_fill("metal").size.x
	await open_build_menu(main)
	hud.entry_button("crystal_harvester").pressed.emit()
	main.placement.confirm_place()
	await _wait(main, Hud.MENU_CLOSE_SECONDS)
	_check_top_bar(hud, state)
	check(hud.resource_fill("metal").size.x < metal_before, "the metal fill fell from %d px" % metal_before)
	await screenshot("purchase")
	# Build over the new building's info panel deselects it; the panel fits a wide window.
	await open_build_menu(main)
	check(main.placement.selected_id == 0, "opening the build panel cleared the selection")
	main.get_window().size = Vector2i(1560, 720)
	await frames(4)
	check(hud.close_button().get_global_rect().end.x <= 1560 - Hud.MARGIN, "the close button fits a 1560x720 window")
	await screenshot("wide-open")


## Each meter's fill spans its track by amount over capacity, to a pixel; the ring counts drones.
func _check_top_bar(hud: Hud, state: BaseState) -> void:
	for res: String in state.catalog.resources:
		var fill := hud.resource_fill(res)
		var track: Control = fill.get_parent()
		var capacity := state.capacity(res)
		var want := track.size.x * state.resources[res] / capacity if capacity > 0 else 0.0
		check(absf(fill.size.x - want) <= 1.0, "the %s fill is %.0f px for %d / %d" % [res, fill.size.x, state.resources[res], capacity])
	var ring := hud.drones_panel()
	check(ring.free_count() == state.builders_free() and ring.total_count() == state.builders_total(),
		"the drone ring shows %d of %d free" % [ring.free_count(), ring.total_count()])


func _wait(main: MainScript, seconds: float) -> void:
	await main.get_tree().create_timer(seconds + 0.05).timeout
	await frames(2)


func _tap(main: MainScript, point: Vector2) -> void:
	for pressed: bool in [true, false]:
		_touch(main, point, pressed)
		await frames(2)


## A finger down or up at `point`, in the HUD's coordinates: input events arrive in window
## pixels, which the viewport maps back through its final transform (the canvas_items stretch).
func _touch(main: MainScript, point: Vector2, pressed: bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.position = main.get_viewport().get_final_transform() * point
	touch.pressed = pressed
	Input.parse_input_event(touch)
