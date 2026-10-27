extends HarnessScenario
## The top bar's drone meter (docs/reference/hud.md, **Drone meter**), rendered. On a fresh base
## the real meter is set to each of COUNTS in turn, free then all, and shot beside the resource
## meters (01-0of1 .. 07-5of5), each checked for its counts, its text and its place at the end of
## the top bar's row; then every count again at 2x on the panel colour, in two columns (08-2x); then
## the top bar at 2 / 5 in each skin (Hud.set_skin), A, B and C (09-skin-a .. 11-skin-c), a busy
## slot's pixels checked, rendered, to read as the skin's trough (its stripes shift it a little).
## The game's tick is held while the meter shows counts the base does not have, so the HUD's
## refresh does not put the real ones back; the animation clock is fixed so the resource meters'
## glint stands still.

const COUNTS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 3), Vector2i(3, 3), Vector2i(2, 5),
	Vector2i(0, 5), Vector2i(5, 5)]
const SHOWN := Vector2i(2, 5)
const SKINS: Array[Hud.Look] = [Hud.Look.A, Hud.Look.B, Hud.Look.C]
## How far in luminance a busy slot's average on screen may lie from the skin's trough fill.
const BUSY_TOLERANCE := 0.08
const ZOOMED_ROWS := 4
const ZOOMED_GAP := Vector2(40, 20)


func run(main: MainScript) -> void:
	var hud: Hud = main.hud
	await frames(4)
	fix_clock(1.0)
	var meter := hud.drones_panel()
	var real := Vector2i(meter.free_count(), meter.total_count())
	var row := hud.resource_panel("metal").get_parent()
	main.process_mode = Node.PROCESS_MODE_DISABLED
	for count: Vector2i in COUNTS:
		meter.set_counts(count.x, count.y)
		await frames(3)
		var text := _text(meter)
		check(meter.free_count() == count.x and meter.total_count() == count.y and text == "%d / %d" % [count.x, count.y],
			"the meter shows %d of %d free, reading \"%s\"" % [meter.free_count(), meter.total_count(), text])
		check(meter.get_parent() == row and meter.get_index() == row.get_child_count() - 1,
			"the meter ends the top bar's row")
		await screenshot("%dof%d" % [count.x, count.y])
	meter.set_counts(real.x, real.y)

	var backdrop := ColorRect.new()
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.color = Color(Hud.PANEL, 1.0)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_screen(backdrop)
	var zoomed := Control.new()
	zoomed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zoomed.position = Vector2(40, 40)
	zoomed.scale = Vector2(2, 2)
	backdrop.add_child(zoomed)
	for i: int in COUNTS.size():
		var copy := DroneRing.new()
		copy.set_counts(COUNTS[i].x, COUNTS[i].y)
		copy.position = Vector2(i / ZOOMED_ROWS, i % ZOOMED_ROWS) * (DroneRing.SIZE + ZOOMED_GAP)
		zoomed.add_child(copy)
	await frames(3)
	await screenshot("2x")
	backdrop.queue_free()

	meter.set_counts(SHOWN.x, SHOWN.y)
	for look: Hud.Look in SKINS:
		hud.set_skin(look)
		await frames(3)
		if DisplayServer.get_name() != "headless":
			var trough := (hud.ui_theme().get_stylebox(&"panel", &"MeterTrough") as StyleBoxFlat).bg_color
			var busy := _busy_slot_colour(main, meter)
			check(absf(busy.get_luminance() - trough.get_luminance()) < BUSY_TOLERANCE,
				"skin %s: a busy slot reads %s on screen, the skin's trough %s" % [_name(look), busy.to_html(false),
				trough.to_html(false)])
		# Skin A at 2 / 5 is 05-2of5 again, which the guard against repeated frames would refuse.
		await screenshot("skin-" + _name(look), look == Hud.Look.A)
	hud.set_skin(Hud.Look.A)
	meter.set_counts(real.x, real.y)
	main.process_mode = Node.PROCESS_MODE_INHERIT
	release_clock()


## The average colour on screen of the last slot (busy at 2 / 5), inside its ink lines.
func _busy_slot_colour(main: MainScript, meter: DroneRing) -> Color:
	var right := DroneRing.SIZE.x - Hud.METER_TEXT_RIGHT - DroneRing.TEXT_WIDTH
	var width := (right - DroneRing.SLOTS_LEFT) / SHOWN.y
	var inside := Rect2(right - width + 3.0, 10.0, width - 6.0, DroneRing.SIZE.y - 20.0)
	var to_window := main.get_viewport().get_final_transform() * meter.get_global_transform_with_canvas()
	var area := Rect2i((to_window * inside).abs())
	var image := main.get_viewport().get_texture().get_image()
	var sum := Color(0, 0, 0, 0)
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			sum += image.get_pixel(x, y)
	return sum / float(area.get_area())


func _name(look: Hud.Look) -> String:
	return (Hud.Look.keys()[look] as String).to_lower()


## The meter's text: its one Label's.
func _text(meter: DroneRing) -> String:
	return (meter.find_children("*", "Label", true, false)[0] as Label).text
