extends HarnessScenario
## The top bar's drone meter (docs/reference/hud.md, **Drone meter**), rendered. On a fresh base
## the real meter is set to each of COUNTS in turn, free then all, and shot beside the resource
## meters (01-0of1 .. 07-5of5), each checked for its counts, its text and its place at the end of
## the top bar's row; then every count again at 2x on the panel colour, in two columns (08-2x).
## The game's tick is held while the meter shows counts the base does not have, so the HUD's
## refresh does not put the real ones back; the animation clock is fixed so the resource meters'
## glint stands still.

const COUNTS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 3), Vector2i(3, 3), Vector2i(2, 5),
	Vector2i(0, 5), Vector2i(5, 5)]
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

	main.process_mode = Node.PROCESS_MODE_INHERIT
	release_clock()


## The meter's text: its one Label's.
func _text(meter: DroneRing) -> String:
	return (meter.find_children("*", "Label", true, false)[0] as Label).text
