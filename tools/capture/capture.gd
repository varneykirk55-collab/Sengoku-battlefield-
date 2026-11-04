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
				var lo: Array[StringName] = [&"katana"] if i < 3 else [&"matchlock", &"katana"]
				var s: Soldier = battle.spawn_soldier(i % 2, false, lo)
				s.respawn_at(Transform3D(Basis(Vector3.UP, PI), battle.player.global_position + Vector3(-5 + i * 2.0, 0.2, -6)))
		"gun":
			battle.player.weapons.select_kind(&"matchlock")
		"fire":
			battle.player.weapons.primary(true)
		"close":  # camera close to the player's side
			var pc := battle.player.controller as PlayerController
			pc.spring.spring_length = 1.6
		"side":
			var pc := battle.player.controller as PlayerController
			pc._yaw += PI * 0.5
		"debuggun":
			await get_tree().create_timer(0.5).timeout
			var p := battle.player
			var gun := p.weapons.get_weapon(&"matchlock") as MatchlockWeapon
			var mz := gun.muzzle_position()
			print("[capture] body_fwd=", p.body_forward(), " look=", p.look_direction(), " aim_dir=", p.visual.gun_aim_dir,
				" mount_y=", p.visual.gun_mount.global_basis.y, " muzzle-mount=", (mz - p.visual.gun_mount.global_position).normalized(),
				" model parent=", gun.model.get_parent().name, " model local=", gun.model.transform)
		"nofog":
			for we in battle.find_children("*", "WorldEnvironment", true, false):
				(we as WorldEnvironment).environment.fog_enabled = false
		"aerial":  # high camera over the south camp looking north across the whole field
			var cam := Camera3D.new()
			battle.add_child(cam)
			cam.far = 1000.0
			cam.global_position = Vector3(0, 150, 230)
			cam.look_at(Vector3(0, 0, -20))
			cam.current = true
			battle.hud.visible = false
		"topdown":
			var cam2 := Camera3D.new()
			battle.add_child(cam2)
			cam2.far = 1000.0
			cam2.global_position = Vector3(0, 330, 0.01)
			cam2.look_at(Vector3.ZERO, Vector3.FORWARD)
			cam2.current = true
			battle.hud.visible = false
		"at_b":
			battle.player.respawn_at(Transform3D(Basis(Vector3.UP, PI * 0.8), (battle.field as Battlefield).ground_point(-12, 18) + Vector3(0, 0.3, 0)))
			(battle.player.controller as PlayerController)._yaw = PI * 0.85
		"wait":
			await get_tree().create_timer(0.5).timeout
