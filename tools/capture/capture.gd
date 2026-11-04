extends Node
## Screenshot helper for cloud QA (software rendering, so it shows layout, not final GPU looks).
##   SHOT_SCENE=res://scenes/main_menu.tscn SHOT_OUT=/tmp/menu.png SHOT_WAIT=1.5 \
##     tools/screenshot.sh
## Optional SHOT_SETUP: name of a method on the loaded scene's root to call before waiting.

func _ready() -> void:
	var scene_path := OS.get_environment("SHOT_SCENE")
	var out := OS.get_environment("SHOT_OUT")
	var wait := float(OS.get_environment("SHOT_WAIT")) if OS.get_environment("SHOT_WAIT") != "" else 1.0
	var inst: Node = load(scene_path).instantiate()
	get_tree().root.add_child.call_deferred(inst)
	await get_tree().process_frame
	await get_tree().process_frame
	var setup := OS.get_environment("SHOT_SETUP")
	if setup != "":
		for step in setup.split(","):
			await _setup(inst, step.strip_edges())
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out)
	print("[capture] saved ", out, " ", img.get_size())
	AudioManager.quit_game()


## Named setup steps for battle screenshots (comma separated in SHOT_SETUP).
func _setup(inst: Node, step: String) -> void:
	var battle := inst as Battle
	match step:
		"fp":
			(battle.player.controller as PlayerController).toggle_camera()
		"front":  # camera looks back at the player's face
			var pc := battle.player.controller as PlayerController
			pc._yaw += PI
			pc._pitch = -0.05
		"run":
			Input.action_press("move_forward")
		"aim":
			battle.player.visual.set_aim(1.0)
		"slash":
			battle.player.visual.play_action(&"slash", 1.2)
		"dummies":  # a line of soldiers from both factions to look at
			for i in 6:
				var s: Soldier = battle.spawn_soldier(i % 2)
				s.global_position = battle.player.global_position + Vector3(-5 + i * 2.0, 0.2, -6)
				s.look_yaw = PI
		"wait":
			await get_tree().create_timer(0.5).timeout
