extends Control
## Title screen: enter the battle, settings, sound test, quit. Menu music and ambience play here.

const BATTLE_SCENE := "res://scenes/battle.tscn"

var _menu: Control
var _panel_holder: CenterContainer
var _ambience: Node
var _play_button: Button


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--selfcheck"):
		_selfcheck()
		return
	theme = UIStyle.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.055, 0.055)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var sun := ColorRect.new()  # simple rising-sun band behind the title
	sun.color = Color(UIStyle.VERMILION, 0.18)
	sun.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sun.offset_top = 132
	sun.offset_bottom = 196
	add_child(sun)

	_menu = VBoxContainer.new()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_menu.position = Vector2(120, 110)
	_menu.add_theme_constant_override("separation", 14)
	add_child(_menu)
	_menu.add_child(UIStyle.label("SENGOKU", 64, UIStyle.PAPER))
	_menu.add_child(UIStyle.label("BATTLEFIELD", 34, UIStyle.VERMILION))
	_menu.add_child(UIStyle.label("Prototype %s" % ProjectSettings.get_setting("application/config/version"), 15, UIStyle.MUTED))
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 40
	_menu.add_child(spacer)
	_play_button = UIStyle.button("Enter the Battle", _on_play, &"ui_confirm")
	_play_button.name = "PlayButton"
	if not ResourceLoader.exists(BATTLE_SCENE):
		_play_button.disabled = true
		_play_button.tooltip_text = "The battlefield arrives in a later milestone."
	_menu.add_child(_play_button)
	_menu.add_child(UIStyle.button("Training Range", _on_training, &"ui_confirm"))
	_menu.add_child(UIStyle.button("Settings", _open.bind(SettingsPanel)))
	_menu.add_child(UIStyle.button("Sound Test", _open.bind(SoundTestPanel)))
	_menu.add_child(UIStyle.button("Quit", func(): AudioManager.quit_game(), &"ui_back"))

	_panel_holder = CenterContainer.new()
	_panel_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel_holder.visible = false
	add_child(_panel_holder)

	Music.play(&"menu", 2.0)
	_ambience = AudioManager.start_loop(&"amb_wind_loop", null, -8.0, 3.0)
	_focus_first_button()


## Run an exported build with `-- --selfcheck` to confirm it was packaged correctly: all audio
## is found, and a short scripted fight (katana cut, weapon switch, matchlock shot) works.
func _selfcheck() -> void:
	var ok := true
	var with_audio := 0
	for id: StringName in AudioManager.events:
		if AudioManager.has_event(id):
			with_audio += 1
	ok = ok and with_audio == AudioManager.events.size() and Music.tracks.size() >= 4
	print("[selfcheck] sound events with audio: %d/%d" % [with_audio, AudioManager.events.size()])
	print("[selfcheck] music tracks: %s" % ", ".join(Music.tracks.keys().map(func(k): return String(k))))
	var battle: Battle = load(BATTLE_SCENE).instantiate()
	battle.ai_armies = false
	battle.training_targets = true
	get_tree().root.add_child.call_deferred(battle)
	await get_tree().process_frame
	for i in 30:
		await get_tree().physics_frame
	var p := battle.player
	var target: Soldier = null
	for s in battle.soldiers:
		if s.faction != p.faction and (target == null or s.global_position.distance_to(p.global_position) < target.global_position.distance_to(p.global_position)):
			target = s
	target.protected_for = 0.0
	# Katana: step up to the nearest enemy and cut.
	p.respawn_at(Transform3D(Basis.IDENTITY, target.global_position + Vector3(0, 0.1, 1.8)))
	for i in 5:
		await get_tree().physics_frame
	p.weapons.primary(true)
	for i in 40:
		await get_tree().physics_frame
	var cut := target.health.current < 100.0
	print("[selfcheck] katana cut landed: %s (enemy health %d)" % [cut, int(target.health.current)])
	# Matchlock: switch, aim at the enemy's chest, fire.
	p.weapons.select_kind(&"matchlock")
	for i in 40:
		await get_tree().physics_frame
	var before := target.health.current
	p.weapons.aim_provider = func() -> Array:
		var eye := p.head_position() - Vector3(0, 0.1, 0)
		return [eye, (target.chest_position() - eye).normalized()]
	p.weapons.primary(true)
	for i in 30:
		await get_tree().physics_frame
	var shot := target.health.current < before or not target.alive
	print("[selfcheck] matchlock shot landed: %s; audio stats: %s" % [shot, AudioManager.stats])
	ok = ok and cut and shot and AudioManager.stats.played > 10
	battle.queue_free()
	await get_tree().process_frame
	# Phase 2: a short 16 v 16 battle between the AI armies.
	var war: Battle = load(BATTLE_SCENE).instantiate()
	get_tree().root.add_child.call_deferred(war)
	await get_tree().process_frame
	(war.player.controller as PlayerController).input_enabled = false
	war.player.health.max_health = 1e9
	war.player.health.restore_full()
	var kills := [0]
	Events.soldier_killed.connect(func(_v: Node, k: Node) -> void:
		if k is Soldier:
			kills[0] += 1)
	for i in 30 * 60:
		await get_tree().physics_frame
	print("[selfcheck] AI battle: %d soldiers, %d kills in 30 s" % [war.soldiers.size(), kills[0]])
	ok = ok and war.soldiers.size() == 32 and kills[0] > 0
	print("[selfcheck] %s" % ("PASS" if ok else "FAIL"))
	AudioManager.quit_game(0 if ok else 1)


func _focus_first_button() -> void:
	for c in _menu.get_children():
		if c is Button and not c.disabled:
			c.call_deferred("grab_focus")
			return


func _exit_tree() -> void:
	AudioManager.stop_loop(_ambience, 0.0)


func _on_play() -> void:
	Music.stop(1.0)
	Battle.next_setup = {}
	get_tree().change_scene_to_file(BATTLE_SCENE)


## Weapons practice: flat test field, idle enemies at several ranges, no armies.
func _on_training() -> void:
	Music.stop(1.0)
	Battle.next_setup = {"map": &"test_ground", "ai_armies": false, "training_targets": true}
	get_tree().change_scene_to_file(BATTLE_SCENE)


func _open(panel_class: Variant) -> void:
	var panel: Control = panel_class.new()
	_panel_holder.add_child(panel)
	_panel_holder.visible = true
	_menu.visible = false
	panel.closed.connect(func() -> void:
		panel.queue_free()
		_panel_holder.visible = false
		_menu.visible = true
		_focus_first_button())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _panel_holder.visible:
		for c in _panel_holder.get_children():
			if c.has_signal("closed"):
				AudioManager.play(&"ui_back")
				c.closed.emit()
		get_viewport().set_input_as_handled()
