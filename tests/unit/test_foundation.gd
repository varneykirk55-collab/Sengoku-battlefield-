extends TestCase
## Project foundation: input map, scenes load, menu boots with music.


func test_every_action_has_pc_and_gamepad_binding() -> void:
	for action in GameInput.gameplay_actions():
		check(InputMap.has_action(action), "action %s registered" % action)
		var pc := false
		var pad := false
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey or ev is InputEventMouseButton:
				pc = true
			elif ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				pad = true
		# Look actions are mouse-motion on PC (handled directly by the camera).
		if not action.begins_with("look_"):
			check(pc, "action %s has a keyboard/mouse binding" % action)
		check(pad, "action %s has a gamepad binding" % action)


func test_all_scenes_load() -> void:
	for path in _scenes("res://scenes"):
		var s := load(path) as PackedScene
		if check(s != null, "scene loads: %s" % path):
			var inst := s.instantiate()
			check(inst != null, "scene instantiates: %s" % path)
			inst.free()


func test_main_menu_boots_with_music_and_ambience() -> void:
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu)
	await frames(3)
	check_eq(Music.current, &"menu", "menu music starts")
	check(menu._ambience != null and is_instance_valid(menu._ambience), "menu wind ambience starts")
	menu.queue_free()
	await frames(2)
	Music.stop(0.0)


func test_settings_and_sound_test_panels_build() -> void:
	for cls in [SettingsPanel, SoundTestPanel]:
		var p: Control = cls.new()
		add_child(p)
		await frames(1)
		check(p.get_child_count() > 0, "%s builds its controls" % p.get_class())
		p.queue_free()
	await frames(1)


func _scenes(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		var clean := f.trim_suffix(".remap")
		if clean.ends_with(".tscn"):
			out.append(dir.path_join(clean))
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_scenes(dir.path_join(sub)))
	return out


func test_menu_offers_battle_and_training_range() -> void:
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu)
	await frames(2)
	var labels: Array[String] = []
	for c in menu._menu.get_children():
		if c is Button:
			labels.append(c.text)
	check(labels.has("Enter the Battle") and labels.has("Training Range"), "battle and training options (%s)" % [labels])
	menu.queue_free()
	await frames(1)
	Music.stop(0.0)


func test_battle_setup_options_apply() -> void:
	Battle.next_setup = {"map": &"test_ground", "ai_armies": false, "training_targets": true}
	var b: Battle = load("res://scenes/battle.tscn").instantiate()
	add_child(b)
	await physics_frames(3)
	check(b.field is PrototypeGround, "training range uses the test ground")
	check(b.soldiers.size() == 6, "player plus five training targets (%d)" % b.soldiers.size())
	check(Battle.next_setup.is_empty(), "options are consumed")
	b.queue_free()
	await frames(2)
	Music.stop(0.0)
