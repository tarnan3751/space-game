class_name HarnessScenario
extends RefCounted
## Base class for harness scenarios (tools/harness/scenarios/*.gd). The driver creates
## one instance, hands it the running Main node and awaits run(). A scenario acts on the
## game the way the player does: through PlacementController, the input signals and
## BaseState. It never reads a clock of its own; time moves only through advance().
##
## Every helper below logs to the run's log.txt. check() records a failure instead of
## stopping, so one run can report several problems, like the tests.

const MainScript := preload("res://src/game/main.gd")

## Set by the driver before run() is called.
var harness: HarnessDriver


## Override. May await (frames, screenshots). `main` is the root node of scenes/main.tscn.
func run(_main: MainScript) -> void:
	push_error("scenario does not override run()")


## Appends a line to log.txt and prints it.
func say(text: String) -> void:
	harness.say(text)


## Records a failure when `condition` is false. The run still continues.
func check(condition: bool, message: String) -> void:
	harness.check(condition, message)


## The harness clock, in unix seconds. Commands applied by PlacementController use it.
func now() -> int:
	return harness.now()


## Moves the harness clock forward and advances the state to it, as the game's tick does.
func advance(seconds: int) -> void:
	harness.advance(seconds)


## Waits for `count` rendered (or, headless, processed) frames.
func frames(count: int) -> void:
	await harness.frames(count)


## Saves a PNG of the window to the output directory. Headless runs log and skip it. A rendered
## run fails when a shot is byte-identical to an earlier one (the window stopped drawing),
## unless the scenario passes `may_repeat` for a shot meant to show that nothing changed.
func screenshot(name: String, may_repeat: bool = false) -> void:
	await harness.screenshot(name, may_repeat)


## Saves a strip of `count` consecutive frames of the window, about `step_ms` of real time apart,
## as one PNG (four frames to a row, each 640x360), numbered with the screenshots. The log line
## gives the gaps measured, the camera's size and how many frames repeat the one before. Headless
## runs log and skip it. A strip is one shot for the guard against repeated frames. `crop` takes
## the centre half of the window each way, for a close subject (frame_span's `crop`).
func strip(name: String, count: int, step_ms: int, crop: bool = false) -> void:
	await harness.strip(name, count, step_ms, crop)


## Sets the camera to `size` with `world_pos` at the screen's centre, so every close-up is framed
## the same way. A size under the camera's own closest zoom (IsoCamera.MIN_ZOOM_SIZE) is set
## directly, as no gesture can.
func frame_world(main: MainScript, size: float, world_pos: Vector3) -> void:
	var centre := main.get_viewport().get_visible_rect().size * 0.5
	main.camera.zoom_at(main.camera.size / maxf(size, IsoCamera.MIN_ZOOM_SIZE), centre)
	main.camera.size = size
	main.camera.pan(centre, centre - main.camera.unproject_position(world_pos))


## Frames `a` and `b` together: the camera centred between them, sized so the tile shows their
## projected span (the larger of its height and its width over the screen's aspect) plus
## `margin`, and at least `minimum`, in world units of the view's height; twice that when the
## strip will crop the centre half of the window (`crop`). Returns the camera size set.
func frame_span(main: MainScript, a: Vector3, b: Vector3, margin: float, minimum: float, crop: bool = false) -> float:
	var middle := (a + b) * 0.5
	frame_world(main, main.camera.size, middle)
	var screen := main.get_viewport().get_visible_rect().size
	var span := (main.camera.unproject_position(a) - main.camera.unproject_position(b)).abs() \
		* main.camera.size / screen.y
	var size := maxf(minimum, maxf(span.y, span.x / (screen.x / screen.y)) + margin) * (2.0 if crop else 1.0)
	frame_world(main, size, middle)
	return size


## Opens the build panel the way the player does: presses the Build button (unless the panel
## is already open), waits for the panel to slide up, and checks that it is open.
func open_build_menu(main: MainScript) -> void:
	var hud: Hud = main.hud
	if not hud.is_menu_open():
		hud.build_button().pressed.emit()
	await main.get_tree().create_timer(Hud.MENU_OPEN_SECONDS + 0.05).timeout
	await frames(2)
	check(hud.is_menu_open(), "the Build button opened the build panel")


## Taps the ground at the centre of `cell`, the way a finger would: through WorldInput's
## tapped signal, so PlacementController handles it exactly as a real tap.
func tap_cell(main: MainScript, cell: Vector2i) -> void:
	var screen_pos: Vector2 = main.camera.unproject_position(main.base_view.cell_to_world(cell, 1))
	main.world_input.tapped.emit(screen_pos)
