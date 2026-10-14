extends HarnessScenario
## The HUD on a fresh base: the build menu's tabs and entries, touches on the menu, the
## place bar following the ghost, the Command Center's info panel, the top bar, and a
## notch-like safe-area inset; then the top bar at its widest, on a Command Center 4 base. Touches are
## real input events (Input.parse_input_event), so they take the same path as a finger:
## through the HUD first, and on to WorldInput only when the HUD lets them through.

## Top and bottom of a phone's safe area, in the HUD's coordinates at 1280x720.
const NOTCH_TOP := 44
const NOTCH_BOTTOM := 34

var _world_touches: int = 0


func run(main: MainScript) -> void:
	var state: BaseState = main.state
	var catalog: Catalog = state.catalog
	var hud: Hud = main.hud
	main.world_input.tapped.connect(func(_at: Vector2) -> void: _world_touches += 1)
	main.world_input.drag_started.connect(func(_at: Vector2) -> void: _world_touches += 1)
	await frames(2)

	# The top bar shows what the base can store, and hides antimatter until it can.
	for res: String in catalog.resources:
		var shown := hud.resource_panel(res).visible
		check(shown == (state.capacity(res) > 0), "%s is %s (capacity %d)" % [
			res, "shown" if shown else "hidden", state.capacity(res)])
	check(not hud.resource_panel("antimatter").visible, "a fresh base hides antimatter")

	# Every menu type sits in exactly one tab, in menu_order order.
	var tabs_of: Dictionary[String, int] = {}
	for category: String in catalog.categories:
		hud.tab_button(category).pressed.emit()
		await frames(2)
		var last_x := -INF
		var in_order := true
		var shown_types := PackedStringArray()
		for type: String in catalog.menu_order:
			var entry := hud.entry_button(type)
			if not entry.visible:
				continue
			shown_types.append(type)
			tabs_of[type] = tabs_of.get(type, 0) + 1
			check(catalog.category_of(type) == category, "%s is under %s" % [type, category])
			in_order = in_order and entry.global_position.x > last_x
			last_x = entry.global_position.x
		check(in_order, "%s lists its %d types in menu order" % [category, shown_types.size()])
		say("tab %s: %s" % [category, ", ".join(shown_types)])
		await screenshot("tab-" + category)
	for type: String in catalog.menu_order:
		check(tabs_of.get(type, 0) == 1, "%s appears in exactly one tab" % type)

	# An available entry shows built/max; a locked one says which Command Center it needs.
	await _open_tab(hud, catalog.category_of("metal_extractor"))
	var max_extractors := catalog.max_count("metal_extractor", state.cc_level())
	check(hud.entry_status("metal_extractor") == "%d/%d" % [state.count_of("metal_extractor"), max_extractors],
		"Metal Extractor reads %s" % hud.entry_status("metal_extractor"))
	check(not hud.entry_button("metal_extractor").disabled, "Metal Extractor is enabled")
	var locked := ""
	for type: String in catalog.menu_order:
		if int(catalog.level_stats(type, 1).get("requires_cc", 1)) > state.cc_level():
			locked = type
			break
	var needed := int(catalog.level_stats(locked, 1).get("requires_cc", 1))
	await _open_tab(hud, catalog.category_of(locked))
	check(hud.entry_button(locked).disabled, "%s is disabled at Command Center %d" % [locked, state.cc_level()])
	check(hud.entry_status(locked) == "Needs Command Center %d" % needed,
		"%s reads %s" % [locked, hud.entry_status(locked)])

	# A tap on a tab switches it, and the world never hears of it.
	await _open_tab(hud, catalog.categories[0])
	var defence := catalog.category_of("laser_turret")
	await _tap(main, hud.tab_button(defence).get_global_rect().get_center())
	check(hud.entry_button("laser_turret").visible and not hud.entry_button("metal_extractor").visible,
		"a tap on the %s tab opened it" % defence)

	# A one-finger drag across the strip scrolls it and presses nothing.
	var first := hud.entry_button("laser_turret")
	var x_before := first.global_position.x
	var from := first.get_global_rect().get_center()
	await _drag(main, from, from - Vector2(400, 0))
	check(first.global_position.x < x_before - 100, "a drag scrolled the strip (%d -> %d)" % [
		x_before, first.global_position.x])
	check(not main.placement.is_placing(), "the drag pressed no entry")

	# A tap on an entry still presses it, and swaps the build bar for the place bar.
	await _open_tab(hud, catalog.category_of("metal_extractor"))
	await _tap(main, hud.entry_button("metal_extractor").get_global_rect().get_center())
	check(main.placement.placing_type == "metal_extractor", "a tap on Metal Extractor began placing it")
	check(_world_touches == 0, "no touch on the menu reached the world (%d did)" % _world_touches)
	check(hud.place_button().is_visible_in_tree() and not hud.entry_button("metal_extractor").is_visible_in_tree(),
		"the place bar replaced the build bar")

	# Moving the ghost updates Place: onto the Command Center it is disabled, off it enabled.
	var cc_id := 0
	for id: int in state.buildings:
		if state.buildings[id].type == Catalog.HQ_TYPE:
			cc_id = id
	var cc: BuildingState = state.buildings[cc_id]
	tap_cell(main, cc.cell + Vector2i.ONE)
	await frames(2)
	check(not main.placement.ghost_is_valid() and hud.place_button().disabled,
		"Place is disabled with the ghost on the Command Center")
	# A tap centres the 3x3 footprint on the tapped cell.
	var free_cell := cc.cell - Vector2i(3, 0)
	check(state.grid.is_free(free_cell - Vector2i.ONE, 3), "the footprint around %s is free" % free_cell)
	tap_cell(main, free_cell)
	await frames(2)
	check(main.placement.ghost_is_valid() and not hud.place_button().disabled,
		"Place is enabled with the ghost on a free cell")
	main.placement.cancel_place()
	await frames(2)
	check(hud.entry_button("metal_extractor").is_visible_in_tree() and not hud.place_button().is_visible_in_tree(),
		"cancelling brings the build bar back")

	# The Command Center's info panel.
	main.placement.select(cc_id)
	await frames(2)
	await screenshot("info-command-center")

	# A notch-like inset moves every part inside it.
	var full := main.get_viewport().get_visible_rect()
	var inset := Rect2(0, NOTCH_TOP, full.size.x, full.size.y - NOTCH_TOP - NOTCH_BOTTOM)
	hud.apply_safe_area(inset)
	await frames(2)
	await screenshot("notch-info")
	main.placement.select(0)
	await frames(2)
	check(hud.resource_panel("metal").get_global_rect().position.y >= NOTCH_TOP + Hud.MARGIN,
		"the top bar sits below the inset's top")
	check(hud.entry_button("metal_extractor").get_global_rect().end.y <= inset.end.y - Hud.MARGIN,
		"the build bar sits above the inset's bottom")
	await screenshot("notch-build-bar")

	# A Command Center 4 base with every collector it allows, storage full, stretches the top
	# bar to its widest: antimatter shows, and the debug button, on its own row, stays clear
	# of the Drones panel. Resources have no command, so the scenario sets them directly.
	_fund(state)
	for level: int in range(2, 5):
		main.placement.select(cc_id)
		main.placement.upgrade_selected()
		check(cc.target_level == level, "the Command Center is upgrading to %d" % level)
		advance(state.seconds_left(cc_id) + 1)
		_fund(state)
	for type: String in ["metal_extractor", "crystal_harvester", "antimatter_siphon"]:
		while state.count_of(type) < catalog.max_count(type, state.cc_level()):
			var count := state.count_of(type)
			main.placement.begin_place(type)
			main.placement.confirm_place()
			if state.count_of(type) == count:
				check(false, "placing a %s failed" % type)
				break
			advance(state.seconds_left(state.last_added_id) + 1)
			_fund(state)
	for res: String in catalog.resources:
		state.resources[res] = state.capacity(res)
	main.placement.select(0)
	await frames(2)
	check(hud.resource_panel("antimatter").visible, "antimatter shows at Command Center %d" % state.cc_level())
	var drones := hud.drones_panel().get_global_rect()
	var reset := hud.reset_button().get_global_rect()
	say("the top bar ends at x=%d; Reset base spans %s" % [drones.end.x, reset])
	check(not drones.intersects(reset), "the debug button clears the Drones panel")
	await screenshot("top-bar-command-center-4")


func _fund(state: BaseState) -> void:
	for res: String in state.catalog.resources:
		state.resources[res] = 1_000_000


func _open_tab(hud: Hud, category: String) -> void:
	hud.tab_button(category).pressed.emit()
	await frames(2)


## A finger down and up at `point`, in the HUD's coordinates.
func _tap(main: MainScript, point: Vector2) -> void:
	var at := _to_window(main, point)
	_touch(at, true)
	await frames(2)
	_touch(at, false)
	await frames(2)


## A finger pressed at `from`, moved to `to` in ten steps and lifted.
func _drag(main: MainScript, from: Vector2, to: Vector2) -> void:
	var start := _to_window(main, from)
	var end := _to_window(main, to)
	_touch(start, true)
	await frames(2)
	for i: int in 10:
		var drag := InputEventScreenDrag.new()
		drag.position = start.lerp(end, (i + 1) / 10.0)
		drag.relative = (end - start) / 10.0
		Input.parse_input_event(drag)
		await frames(1)
	_touch(end, false)
	await frames(2)


func _touch(at: Vector2, pressed: bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.position = at
	touch.pressed = pressed
	Input.parse_input_event(touch)


## Input events arrive in window pixels; the viewport maps them back through its final
## transform (the canvas_items stretch).
func _to_window(main: MainScript, point: Vector2) -> Vector2:
	return main.get_viewport().get_final_transform() * point
