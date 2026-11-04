class_name TestCase
extends Node
## Base class for automated tests. Each `test_*` method is run in turn by tests/test_runner.gd;
## the test node is in the scene tree, so tests can add scenes and await frames.

var failures: Array[String] = []
var current_test := ""


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func check(condition: bool, message: String) -> bool:
	if not condition:
		failures.append("%s: %s" % [current_test, message])
	return condition


func check_eq(actual: Variant, expected: Variant, message: String) -> bool:
	return check(actual == expected, "%s (expected %s, got %s)" % [message, expected, actual])


func check_near(actual: float, expected: float, tolerance: float, message: String) -> bool:
	return check(absf(actual - expected) <= tolerance, "%s (expected %.3f +/- %.3f, got %.3f)" % [message, expected, tolerance, actual])


func frames(n: int = 1) -> void:
	for i in n:
		await get_tree().process_frame


func physics_frames(n: int = 1) -> void:
	for i in n:
		await get_tree().physics_frame


## Advances simulated time by roughly `seconds` of physics frames.
func seconds(s: float) -> void:
	await physics_frames(ceili(s * Engine.physics_ticks_per_second))
