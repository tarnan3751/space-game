extends HarnessScenario
## The HUD's layout on a fresh base: the top bar's row holds the resource meters and then the
## drone meter, nothing else; under a notch-like safe-area inset the top bar, the Build
## button and the open build panel's content keep inside the inset while the panel reaches the
## screen's edges; a drag across the card strip scrolls it and presses nothing; and a window
## resized while the panel slides open leaves it open on the new bottom edge.

## A phone's safe area at 1280x720: its top, bottom and sides, in the HUD's coordinates.
const NOTCH_TOP := 44
const NOTCH_BOTTOM := 34
const NOTCH_SIDE := 48
const RESIZED := Vector2i(1280, 900)


func run(main: MainScript) -> void:
	var hud: Hud = main.hud
	var catalog: Catalog = main.state.catalog
	await frames(2)
	var row := hud.drones_panel().get_parent()
	var meters := 0
	for res: String in catalog.resources:
		meters += 1 if hud.resource_panel(res).get_parent() == row else 0
	check(meters == catalog.resources.size() and row.get_child_count() == meters + 1
		and hud.drones_panel().get_index() == meters,
		"the top bar's row holds the %d resource meters, then the drone meter (%d parts)" % [meters, row.get_child_count()])
	await open_build_menu(main)
	hud.tab_button(catalog.category_of("laser_turret")).pressed.emit()
	var full := main.get_viewport().get_visible_rect()
	var inset := full.grow_individual(-NOTCH_SIDE, -NOTCH_TOP, -NOTCH_SIDE, -NOTCH_BOTTOM)
	hud.apply_safe_area(inset)
	await frames(2)
	var inner := inset.grow(-Hud.MARGIN + 0.5)
	var turret := hud.entry_button("laser_turret")
	check(inner.encloses(hud.resource_panel("metal").get_global_rect()), "the top bar keeps inside the inset")
	check(inner.encloses(hud.build_button().get_global_rect()), "the Build button keeps inside the inset")
	check(inner.encloses(hud.tab_button(catalog.categories[0]).get_global_rect()) and inner.encloses(turret.get_global_rect()),
		"the tabs and the first card keep inside the inset")
	var panel := hud.build_panel().get_global_rect()
	check(panel.position.x == 0 and panel.end.x == full.end.x and absf(panel.end.y - full.end.y) < 1.0,
		"the panel reaches the screen's sides and bottom (%s)" % panel)
	await screenshot("notch-open")
	hud.apply_safe_area(full)
	await frames(2)
	var x_before := turret.global_position.x
	await _drag(main, turret.get_global_rect().get_center(), Vector2(-400, 0))
	check(turret.global_position.x < x_before - 100 and not main.placement.is_placing(),
		"a drag scrolled the strip (%d -> %d) and pressed nothing" % [x_before, turret.global_position.x])
	hud.close_button().pressed.emit()
	await main.get_tree().create_timer(Hud.MENU_CLOSE_SECONDS + 0.05).timeout

	# Resized two frames into the opening slide, the panel still ends open on the bottom edge.
	hud.build_button().pressed.emit()
	await frames(2)
	main.get_window().size = RESIZED
	await main.get_tree().create_timer(Hud.MENU_OPEN_SECONDS + 0.05).timeout
	await frames(2)
	var bottom := main.get_viewport().get_visible_rect().end.y
	panel = hud.build_panel().get_global_rect()
	say("the window is %s, the screen %s; the panel spans %s" % [RESIZED, main.get_viewport().get_visible_rect(), panel])
	check(absf(panel.end.y - bottom) < 1.0, "resized mid-slide, the panel ends on the bottom edge (%d, %d)" % [panel.end.y, bottom])
	await screenshot("resized-open")


## A finger pressed at `from`, moved by `by` in ten steps and lifted. Input events arrive in
## window pixels, which the viewport maps back through its final transform.
func _drag(main: MainScript, from: Vector2, by: Vector2) -> void:
	var to_window := main.get_viewport().get_final_transform()
	_touch(to_window * from, true)
	await frames(2)
	for i: int in 10:
		var drag := InputEventScreenDrag.new()
		drag.position = to_window * (from + by * (i + 1) / 10.0)
		drag.relative = to_window.basis_xform(by / 10.0)
		Input.parse_input_event(drag)
		await frames(1)
	_touch(to_window * (from + by), false)
	await frames(2)


func _touch(at: Vector2, pressed: bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.position = at
	touch.pressed = pressed
	Input.parse_input_event(touch)
