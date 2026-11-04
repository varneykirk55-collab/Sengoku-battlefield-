extends Node
## Headless test runner.
##   godot --headless --path . res://tests/test_runner.tscn                 all tests
##   SENGOKU_TEST=audio godot --headless --path . res://tests/test_runner.tscn   files/tests matching "audio"
## Exit code 0 = all passed, 1 = failures.

const TEST_DIR := "res://tests/unit"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var filter := OS.get_environment("SENGOKU_TEST")
	var files: Array[String] = []
	for f in DirAccess.get_files_at(TEST_DIR):
		if f.begins_with("test_") and f.ends_with(".gd"):
			files.append(f)
	files.sort()
	var passed := 0
	var failed: Array[String] = []
	var started := Time.get_ticks_msec()
	print("==== Sengoku Battlefield tests (Godot %s) ====" % Engine.get_version_info().string)
	for f in files:
		var script := load(TEST_DIR.path_join(f)) as Script
		if script == null or not script.can_instantiate():
			failed.append("%s: script failed to load" % f)
			print("FAIL  %s (script failed to load)" % f)
			continue
		var methods: Array[String] = []
		for m in script.get_script_method_list():
			var name: String = m.name
			if name.begins_with("test_") and not methods.has(name):
				if filter == "" or f.contains(filter) or name.contains(filter):
					methods.append(name)
		for method in methods:
			var t: TestCase = script.new()
			t.name = f.get_basename()
			add_child(t)
			t.current_test = "%s.%s" % [f.get_basename(), method]
			await t.before_each()
			await t.call(method)
			await t.after_each()
			if t.failures.is_empty():
				passed += 1
				print("PASS  %s" % t.current_test)
			else:
				for msg in t.failures:
					failed.append(msg)
					print("FAIL  %s" % msg)
			t.queue_free()
			await get_tree().process_frame
	var secs := (Time.get_ticks_msec() - started) / 1000.0
	print("==== %d passed, %d failed (%.1fs) ====" % [passed, failed.size(), secs])
	AudioManager.quit_game(0 if failed.is_empty() else 1)
