extends SceneTree
## Dependency-free headless test runner. Use tools/run_tests.sh rather than calling
## this directly: the script imports the project first so class_name scripts resolve.
##
## Finds every res://test/**/test_*.gd, which must extend TestCase, and runs each
## method whose name starts with "test_". An optional filter (first user argument
## after "--") runs only tests whose "file::method" contains that text.

const TEST_ROOT := "res://test"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var filter := "" if args.is_empty() else args[0]
	var files := _collect(TEST_ROOT)
	files.sort()

	var passed := 0
	var failed := PackedStringArray()
	for path: String in files:
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			failed.append("%s (failed to load or has errors)" % path)
			continue
		for method: String in _test_methods(script):
			var full_name := "%s::%s" % [path.get_file().get_basename(), method]
			if filter != "" and not full_name.contains(filter):
				continue
			print("RUN  ", full_name)
			var test: TestCase = script.new()
			test.before_each()
			test.call(method)
			if test.failures.is_empty():
				passed += 1
			else:
				failed.append(full_name)
				for failure: String in test.failures:
					print("     FAIL: ", failure)

	print("")
	print("%d passed, %d failed" % [passed, failed.size()])
	for name: String in failed:
		print("  failed: ", name)
	if passed + failed.size() == 0:
		print("No tests matched.")
		quit(1)
		return
	quit(0 if failed.is_empty() else 1)


func _test_methods(script: GDScript) -> PackedStringArray:
	var names := PackedStringArray()
	for info: Dictionary in script.get_script_method_list():
		var method_name: String = info["name"]
		if method_name.begins_with("test_") and not names.has(method_name):
			names.append(method_name)
	names.sort()
	return names


func _collect(dir_path: String) -> PackedStringArray:
	var found := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	for sub: String in dir.get_directories():
		found.append_array(_collect(dir_path.path_join(sub)))
	for file_name: String in dir.get_files():
		if file_name.begins_with("test_") and file_name.ends_with(".gd"):
			found.append(dir_path.path_join(file_name))
	return found
