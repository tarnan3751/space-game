class_name TestCase
extends RefCounted
## Base class for headless tests. tools/test_runner.gd creates a fresh instance per
## test method, calls before_each(), then the method. Assertions record failures
## instead of stopping, so one test can report several problems.

var failures: PackedStringArray = PackedStringArray()


## Override for per-test setup.
func before_each() -> void:
	pass


## Strict equality: types must match too, so int 5 and float 5.0 are different.
func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if typeof(actual) != typeof(expected):
		_fail(message, "expected %s (%s) but got %s (%s)" % [
			str(expected), type_string(typeof(expected)), str(actual), type_string(typeof(actual))])
	elif actual != expected:
		_fail(message, "expected %s but got %s" % [str(expected), str(actual)])


func assert_true(condition: bool, message: String = "") -> void:
	if not condition:
		_fail(message, "expected true")


func assert_false(condition: bool, message: String = "") -> void:
	if condition:
		_fail(message, "expected false")


func _fail(message: String, detail: String) -> void:
	failures.append(detail if message.is_empty() else "%s: %s" % [message, detail])
