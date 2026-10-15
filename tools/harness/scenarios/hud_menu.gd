extends HarnessScenario
## The HUD on a fresh base: the meters and drone ring, the Build button and the panel it slides
## up (tabs, cards and their pictures, the selected tab pressed again, close button), a card
## picked into the place bar, a purchase and its flash on the metal meter, the crystal meter
## still through the new harvester's trickle and flashing on a catch-up, a wide window; the
## meters' glint crossing the metal fill.
## Touches are real input events (Input.parse_input_event), so they take a finger's path.

## The meters' glint (meter.gdshader): its period and how long it takes to cross a fill.
const GLINT_PERIOD := 3.5
const GLINT_SWEEP := 0.6

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
	await _check_glint(main, hud)
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

	# Every card's picture is rendered within a second of the panel opening. A headless run draws
	# nothing, so it checks only that every type was gone through.
	await _wait(main, 1.0)
	check(hud.previews_done(), "the pictures are done a second after the panel opened")
	if DisplayServer.get_name() != "headless":
		var missing := PackedStringArray()
		for type: String in catalog.menu_order:
			if hud.entry_preview(type) == null:
				missing.append(type)
		check(missing.is_empty(), "every card has its picture (missing: %s)" % ", ".join(missing))
	for category: String in catalog.categories:
		await _tap(main, hud.tab_button(category).get_global_rect().get_center())
		await frames(2)
		say("panel open on %s: %d draw calls" % [category, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
		await screenshot("pictures-" + category)

	# A press on the selected tab scrolls its strip back to the start, animated.
	var first: String = catalog.categories[0]
	await _tap(main, hud.tab_button(first).get_global_rect().get_center())
	var strip := hud.entry_strip()
	strip.scroll_horizontal = 300
	await frames(2)
	var scrolled := strip.scroll_horizontal
	check(scrolled > 0, "the %s strip scrolled to %d" % [first, scrolled])
	_touch(main, hud.tab_button(first).get_global_rect().get_center(), true)
	await frames(1)
	_touch(main, hud.tab_button(first).get_global_rect().get_center(), false)
	await frames(2)
	check(strip.scroll_horizontal > 0 and strip.scroll_horizontal < scrolled,
		"the strip is on its way back (%d of %d)" % [strip.scroll_horizontal, scrolled])
	await _wait(main, Hud.STRIP_RETURN_SECONDS)
	check(strip.scroll_horizontal == 0 and hud.tab_button(first).button_pressed,
		"pressing the selected tab scrolled its strip back to %d, still selected" % strip.scroll_horizontal)

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
	var flash_at: float = _meter_shader(hud, "metal").get_shader_parameter(&"flash_time")
	check(absf(Motion.clock() - flash_at) < 0.05, "the purchase flashed the metal meter at %.2f s (now %.2f s)" % [flash_at, Motion.clock()])
	await screenshot("purchase-flash")
	say("flash shot %.2f s after the purchase" % (Motion.clock() - flash_at))
	await _wait(main, Hud.MENU_CLOSE_SECONDS)
	_check_top_bar(hud, state)
	check(hud.resource_fill("metal").size.x < metal_before, "the metal fill fell from %d px" % metal_before)
	await screenshot("purchase")
	await _check_trickle(main, hud)
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


## Each meter's stripes carry their own glint, a third of a period after the one before; two
## shots 0.3 s apart catch the band crossing the metal fill (phase 0), timed by the one clock, and
## a third catches it on the crystal fill.
## With the panel closed, the draw calls are logged.
func _check_glint(main: MainScript, hud: Hud) -> void:
	var resources := main.state.catalog.resources
	for i: int in resources.size():
		var phase: float = _meter_shader(hud, resources[i]).get_shader_parameter(&"phase")
		check(is_equal_approx(phase, fmod(i / 3.0, 1.0)), "the %s glint's phase is %.2f" % [resources[i], phase])
	var width: float = _meter_shader(hud, "metal").get_shader_parameter(&"fill_width")
	check(width == hud.resource_fill("metal").size.x, "the metal glint crosses the %.0f px fill" % width)
	say("panel closed: %d draw calls" % Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	# A shot is taken two frames after it is asked for, so the second is asked for that much
	# before 0.3 s has passed.
	while fmod(Motion.clock(), GLINT_PERIOD) < 0.1 or fmod(Motion.clock(), GLINT_PERIOD) >= 0.16:
		await frames(1)
	await screenshot("glint-start")
	var start := Motion.clock()
	say("glint shot at %.2f s into the metal sweep" % fmod(start, GLINT_PERIOD))
	while Motion.clock() < start + 0.27:
		await frames(1)
	await screenshot("glint-later")
	var later := fmod(Motion.clock(), GLINT_PERIOD)
	say("glint shot at %.2f s into the metal sweep" % later)
	check(later < GLINT_SWEEP, "the second glint shot is still within the %.1f s sweep" % GLINT_SWEEP)
	# Then the crystal meter's glint, a third of a period later, halfway across its fill.
	var crystal_start := GLINT_PERIOD / 3.0
	while fposmod(Motion.clock() - crystal_start, GLINT_PERIOD) < 0.25 or fposmod(Motion.clock() - crystal_start, GLINT_PERIOD) >= 0.31:
		await frames(1)
	await screenshot("glint-crystal")
	say("glint shot at %.2f s into the crystal sweep" % fposmod(Motion.clock() - crystal_start, GLINT_PERIOD))


## The crystal harvester bought above, once built, adds crystal every tick or two: that trickle
## never flashes the crystal meter, a stalled tick's included, and an hour's catch-up does.
func _check_trickle(main: MainScript, hud: Hud) -> void:
	var state: BaseState = main.state
	var harvester := 0
	for id: int in state.buildings:
		if state.buildings[id].type == "crystal_harvester":
			harvester = id
	advance(state.seconds_left(harvester) + 1)
	_refresh(main)
	check(state.production_per_hour("crystal") > 0, "the harvester produces %d crystal an hour" % state.production_per_hour("crystal"))
	# Null until the meter first flashes.
	var flashed: Variant = _meter_shader(hud, "crystal").get_shader_parameter(&"flash_time")
	var before: int = state.resources["crystal"]
	for tick: int in 6:
		advance(1)
		_refresh(main)
	# A stalled tick: four seconds' trickle at once.
	advance(4)
	_refresh(main)
	var still: Variant = _meter_shader(hud, "crystal").get_shader_parameter(&"flash_time")
	check(still == flashed and state.resources["crystal"] > before,
		"six ticks' and a four-second tick's trickle (%d -> %d crystal) did not flash the meter" % [before, state.resources["crystal"]])
	advance(3600)
	_refresh(main)
	var caught_up: float = _meter_shader(hud, "crystal").get_shader_parameter(&"flash_time")
	check(absf(Motion.clock() - caught_up) < 0.05, "an hour's catch-up to %d crystal flashed the meter" % state.resources["crystal"])


func _refresh(main: MainScript) -> void:
	main.hud.refresh(main.state, main.placement.selected_id, main.placement.is_placing(), main.placement.ghost_is_valid(),
		main.placement.is_painting())


func _meter_shader(hud: Hud, res: String) -> ShaderMaterial:
	return (hud.resource_fill(res).get_child(0) as CanvasItem).material as ShaderMaterial


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
