class_name TestCase
extends RefCounted
## Minimal base class for the headless test runner (tests/run_tests.gd).
## Methods named test_* are run; they may await tree.physics_frame.

var tree: SceneTree
var failures: PackedStringArray = PackedStringArray()
var assertion_count: int = 0


func check(condition: bool, message: String) -> void:
	assertion_count += 1
	if not condition:
		failures.append(message)


func check_eq(actual: Variant, expected: Variant, message: String) -> void:
	check(actual == expected, "%s (expected %s, got %s)" % [message, str(expected), str(actual)])


func check_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	check(
		absf(actual - expected) <= tolerance,
		"%s (expected %s +/- %s, got %s)" % [message, str(expected), str(tolerance), str(actual)]
	)


func wait_frames(count: int) -> void:
	for _i in count:
		await tree.physics_frame
