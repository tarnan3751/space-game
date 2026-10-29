class_name HarnessDriver
extends SceneTree
## Scripted driver for behaviour checks. Boots scenes/main.tscn on an isolated save
## file, runs one scenario from tools/harness/scenarios/, and writes a log and
## screenshots to an output directory. Use tools/harness/run.sh rather than calling
## this directly; the README in this folder documents both.
##
##   $GODOT [--headless] --path . -s res://tools/harness/driver.gd -- \
##       --scenario=<name> --out=<dir> --save-path=<file> --no-cheats [--timeout=<s>]
##
## --save-path is required and is the same argument main.gd honours, so a run never
## touches user://base.json. --no-cheats is main.gd's too: without it a debug build makes
## every level free and one second at most, so run.sh passes it and scenarios run on the
## real numbers. Headless runs check logic only; a rendered run (no
## --headless) also saves screenshots. The exit code is 0 when every check passed.
##
## A watchdog ends a run that has not finished --timeout seconds (HARNESS_TIMEOUT_SECONDS by
## default) after the scenario started: one stopped by a runtime error, or awaiting a signal
## that never comes, fails with exit code 1 instead of leaving Godot running.
##
## Time: the harness clock starts CLOCK_LEAD seconds ahead of the device clock and moves
## only when a scenario calls advance(). PlacementController's clock is replaced with it,
## and the game's own one-second tick, which advances to device time, is ignored by
## BaseState because that time is in the past. Runs are therefore repeatable to the
## second whatever the machine's speed.

const SCENARIO_DIR := "res://tools/harness/scenarios"
const MAIN_SCENE := "res://scenes/main.tscn"
const CLOCK_LEAD := 1_000_000
const HARNESS_TIMEOUT_SECONDS := 300
## How long the driver waits after shutting the sounds down before it quits: the mixer releases a
## stopped playback at its next mix step (the Dummy driver mixes in large buffers, about 90 ms) and
## AudioServer.update() collects it on a later frame; 0.1 s leaked in rendered runs.
const SILENCE_SECONDS := 0.3
## A strip's frames: each downscaled to STRIP_FRAME, laid left to right STRIP_COLUMNS to a row.
const STRIP_FRAME := Vector2i(640, 360)
const STRIP_COLUMNS := 4
## How early a strip's frame may be taken, in ms: half a 120 Hz frame, so frame timing's jitter
## does not push a step to the frame after it.
const STRIP_EARLY_MS := 4
const MainScript := preload("res://src/game/main.gd")

var scenario_name: String = ""
var out_dir: String = ""
var save_path: String = ""
var headless: bool = false
var timeout_seconds: int = HARNESS_TIMEOUT_SECONDS
var failures: PackedStringArray = PackedStringArray()

var _main: MainScript
var _log: FileAccess
var _clock: int = 0
var _screenshots: int = 0
## The last check()'s message, for the watchdog's report.
var _last_check: String = ""
var _ended: bool = false


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="):
			scenario_name = arg.trim_prefix("--scenario=")
		elif arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--save-path="):
			save_path = arg.trim_prefix("--save-path=")
		elif arg.begins_with("--timeout="):
			timeout_seconds = arg.trim_prefix("--timeout=").to_int()
	if scenario_name == "" or out_dir == "" or save_path == "" or timeout_seconds <= 0:
		printerr("usage: driver.gd -- --scenario=<name> --out=<dir> --save-path=<file> [--timeout=<s>]")
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
	say("harness: save %s, clock starts at %d, timeout %d s" % [save_path, _clock, timeout_seconds])

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
		_end(1)
		return
	scenario.harness = self
	say("harness: run %s" % scenario_name)
	create_timer(timeout_seconds).timeout.connect(_on_timeout)
	await scenario.run(_main)
	# Quiet before quitting: a sound still playing at exit is reported as a leak (Audio.shut_down).
	_main.audio.shut_down()
	await create_timer(SILENCE_SECONDS).timeout
	_finish()


func _on_timeout() -> void:
	if _ended:
		return
	say("HARNESS FAIL: %s, timed out after %d s (last check: %s)" % [scenario_name, timeout_seconds,
		_last_check if _last_check != "" else "none"])
	_end(1)


func _finish() -> void:
	if _ended:
		return
	if failures.is_empty():
		say("HARNESS PASS: %s" % scenario_name)
	else:
		say("HARNESS FAIL: %s, %d failed check(s)" % [scenario_name, failures.size()])
		for failure: String in failures:
			say("  failed: " + failure)
	_end(0 if failures.is_empty() else 1)


## Closes the log and quits with `code`; a later _finish() or timeout does nothing.
func _end(code: int) -> void:
	_ended = true
	if _log != null:
		_log.close()
		_log = null
	quit(code)


# --- Services for scenarios -----------------------------------------------------------

func say(text: String) -> void:
	print(text)
	if _log != null:
		_log.store_line(text)


func check(condition: bool, message: String) -> void:
	_last_check = message
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


## `count` frames of the window about `step_ms` of real time apart, each downscaled to
## STRIP_FRAME and laid out in reading order, STRIP_COLUMNS to a row, saved as one NN-<name>.png
## (numbered with the screenshots). Frames are taken as frames arrive, the first at or after
## step_ms - STRIP_EARLY_MS since the last, so the log line gives the gaps actually measured, the
## camera's size and how many frames were byte-identical to the one before (a still subject, or a
## stalled one). `crop` takes the centre half of the window each way instead of the whole of it,
## twice the pixels on a close subject. The composed PNG is one shot for run.sh's stale-frame
## guard. Headless runs log and skip it.
func strip(name: String, count: int, step_ms: int, crop: bool = false) -> void:
	if count <= 0:
		check(count > 0, "strip %s has at least one frame (%d)" % [name, count])
		return
	_screenshots += 1
	var file_name := "%02d-%s.png" % [_screenshots, name]
	if headless:
		say("strip %s skipped (headless)" % file_name)
		return
	await process_frame
	await process_frame
	var rows := (count + STRIP_COLUMNS - 1) / STRIP_COLUMNS
	var sheet: Image = null
	var previous := PackedByteArray()
	var identical := 0
	var gaps := PackedStringArray()
	var last := 0
	for i: int in count:
		if i > 0:
			await process_frame
			while Time.get_ticks_usec() - last < (step_ms - STRIP_EARLY_MS) * 1000:
				await process_frame
			gaps.append(str((Time.get_ticks_usec() - last) / 1000))
		last = Time.get_ticks_usec()
		var frame := root.get_texture().get_image()
		if crop:
			frame = frame.get_region(Rect2i(frame.get_size() / 4, frame.get_size() / 2))
		frame.resize(STRIP_FRAME.x, STRIP_FRAME.y, Image.INTERPOLATE_BILINEAR)
		if sheet == null:
			sheet = Image.create(STRIP_FRAME.x * mini(count, STRIP_COLUMNS), STRIP_FRAME.y * rows, false,
				frame.get_format())
		var data := frame.get_data()
		if i > 0 and data == previous:
			identical += 1
		previous = data
		sheet.blit_rect(frame, Rect2i(Vector2i.ZERO, STRIP_FRAME),
			Vector2i(i % STRIP_COLUMNS, i / STRIP_COLUMNS) * STRIP_FRAME)
	var path := out_dir.path_join(file_name)
	var error := sheet.save_png(path)
	if error == OK:
		say("strip %s (%d frames, %d ms, %d identical; camera size %.1f%s; gaps %s ms)" % [file_name, count,
			step_ms, identical, _main.camera.size, ", centre half" if crop else "", " ".join(gaps)])
	else:
		check(false, "could not save %s: %s" % [path, error_string(error)])
