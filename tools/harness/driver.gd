class_name HarnessDriver
extends SceneTree
## Scripted driver for behaviour checks. Boots scenes/main.tscn on an isolated save
## file, runs one scenario from tools/harness/scenarios/, and writes a log and
## screenshots to an output directory. Use tools/harness/run.sh rather than calling
## this directly; the README in this folder documents both.
##
##   $GODOT [--headless] --path . -s res://tools/harness/driver.gd -- \
##       --scenario=<name> --out=<dir> --save-path=<file> --no-cheats
##
## --save-path is required and is the same argument main.gd honours, so a run never
## touches user://base.json. --no-cheats is main.gd's too: without it a debug build makes
## every level free and one second at most, so run.sh passes it and scenarios run on the
## real numbers. Headless runs check logic only; a rendered run (no
## --headless) also saves screenshots. The exit code is 0 when every check passed.
##
## Time: the harness clock starts CLOCK_LEAD seconds ahead of the device clock and moves
## only when a scenario calls advance(). PlacementController's clock is replaced with it,
## and the game's own one-second tick, which advances to device time, is ignored by
## BaseState because that time is in the past. Runs are therefore repeatable to the
## second whatever the machine's speed.

const SCENARIO_DIR := "res://tools/harness/scenarios"
const MAIN_SCENE := "res://scenes/main.tscn"
const CLOCK_LEAD := 1_000_000
const MainScript := preload("res://src/game/main.gd")

var scenario_name: String = ""
var out_dir: String = ""
var save_path: String = ""
var headless: bool = false
var failures: PackedStringArray = PackedStringArray()

var _main: MainScript
var _log: FileAccess
var _clock: int = 0
var _screenshots: int = 0


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="):
			scenario_name = arg.trim_prefix("--scenario=")
		elif arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--save-path="):
			save_path = arg.trim_prefix("--save-path=")
	if scenario_name == "" or out_dir == "" or save_path == "":
		printerr("usage: driver.gd -- --scenario=<name> --out=<dir> --save-path=<file>")
		quit(2)
		return
	if save_path.begins_with("user://"):
		printerr("harness: --save-path must not point into user:// (that is the real save)")
		quit(2)
		return
	var scenario_path := SCENARIO_DIR.path_join(scenario_name + ".gd")
	if not ResourceLoader.exists(scenario_path):
		printerr("harness: no scenario at %s" % scenario_path)
		quit(2)
		return

	DirAccess.make_dir_recursive_absolute(out_dir)
	_log = FileAccess.open(out_dir.path_join("log.txt"), FileAccess.WRITE)
	headless = DisplayServer.get_name() == "headless"
	_clock = int(Time.get_unix_time_from_system()) + CLOCK_LEAD
	say("harness: scenario %s, %s, out %s" % [
		scenario_name, "headless" if headless else "rendered", out_dir])
	say("harness: save %s, clock starts at %d" % [save_path, _clock])

	var scene: PackedScene = load(MAIN_SCENE)
	_main = scene.instantiate()
	root.add_child(_main)
	_run(scenario_path)


func _run(scenario_path: String) -> void:
	# Main's _ready runs on the first iteration, not inside _initialize.
	await process_frame
	if _main.state == null:
		check(false, "main.tscn did not create a BaseState (bad game data?)")
		_finish()
		return
	_main.placement.clock = now
	_main.state.advance_to(_clock)
	# A scenario that does not parse loads as null or cannot be instantiated; stop rather than
	# wait for a run that never starts.
	var script := load(scenario_path) as GDScript
	var scenario: HarnessScenario = null
	if script != null and script.can_instantiate():
		scenario = script.new() as HarnessScenario
	if scenario == null:
		say("HARNESS FAIL: %s, script failed to load" % scenario_name)
		_log.close()
		quit(1)
		return
	scenario.harness = self
	say("harness: run %s" % scenario_name)
	await scenario.run(_main)
	_finish()


func _finish() -> void:
	if failures.is_empty():
		say("HARNESS PASS: %s" % scenario_name)
	else:
		say("HARNESS FAIL: %s, %d failed check(s)" % [scenario_name, failures.size()])
		for failure: String in failures:
			say("  failed: " + failure)
	if _log != null:
		_log.close()
	quit(0 if failures.is_empty() else 1)


# --- Services for scenarios -----------------------------------------------------------

func say(text: String) -> void:
	print(text)
	if _log != null:
		_log.store_line(text)


func check(condition: bool, message: String) -> void:
	if condition:
		say("ok   " + message)
	else:
		say("FAIL " + message)
		failures.append(message)


func now() -> int:
	return _clock


func advance(seconds: int) -> void:
	_clock += maxi(seconds, 0)
	_main.state.advance_to(_clock)
	say("advance %d s -> t=%d" % [seconds, _clock])


func frames(count: int) -> void:
	for i: int in maxi(count, 0):
		await process_frame


## `may_repeat` marks a shot that may match an earlier one byte for byte: its log line ends
## in "(may repeat)", which exempts it from run.sh's stale-frame guard.
func screenshot(name: String, may_repeat: bool = false) -> void:
	_screenshots += 1
	var file_name := "%02d-%s.png" % [_screenshots, name]
	var marker := " (may repeat)" if may_repeat else ""
	if headless:
		say("screenshot %s skipped (headless)%s" % [file_name, marker])
		return
	# Two frames so the scene and the HUD reflect the latest state change.
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var path := out_dir.path_join(file_name)
	var error := image.save_png(path)
	if error == OK:
		say("screenshot %s (%dx%d)%s" % [file_name, image.get_width(), image.get_height(), marker])
	else:
		check(false, "could not save %s: %s" % [path, error_string(error)])
