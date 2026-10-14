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


## Saves a PNG of the window to the output directory. Headless runs log and skip it.
func screenshot(name: String) -> void:
	await harness.screenshot(name)


## Taps the ground at the centre of `cell`, the way a finger would: through WorldInput's
## tapped signal, so PlacementController handles it exactly as a real tap.
func tap_cell(main: MainScript, cell: Vector2i) -> void:
	var screen_pos: Vector2 = main.camera.unproject_position(main.base_view.cell_to_world(cell, 1))
	main.world_input.tapped.emit(screen_pos)
