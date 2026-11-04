extends TestCase
## M1: player movement, cameras, health, damage, death and respawn, with their sounds.

var battle: Battle
var player: Soldier
var heard: Array[StringName] = []


func before_each() -> void:
	battle = load("res://scenes/battle.tscn").instantiate()
	battle.training_targets = false
	battle.ai_armies = false
	battle.map = &"test_ground"
	add_child(battle)
	player = battle.player
	heard.clear()
	AudioManager.sound_played.connect(_on_sound)
	await physics_frames(10)
	# A clear lane facing -Z, away from the test ground's crates.
	player.respawn_at(Transform3D(Basis.IDENTITY, Vector3(-40, 0.1, 10)))
	(player.controller as PlayerController)._yaw = 0.0
	await physics_frames(10)  # settle onto the ground
	heard.clear()


func after_each() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "sprint", "jump"]:
		Input.action_release(a)
	AudioManager.sound_played.disconnect(_on_sound)
	get_tree().paused = false
	battle.queue_free()
	await frames(2)
	Music.stop(0.0)


func _on_sound(id: StringName, _pos: Variant) -> void:
	heard.append(id)


func test_battle_spawns_player_with_third_person_camera() -> void:
	check(player != null and player.alive, "player spawned alive")
	check(player.is_on_floor(), "player standing on the ground")
	var pc := player.controller as PlayerController
	check(pc != null, "player has a PlayerController")
	check(pc.tp_camera.current, "third-person camera is the default")
	check_eq(Music.current, &"battle", "battle music playing")
	check(battle.ambience.size() == 2 and battle.ambience.all(func(a): return is_instance_valid(a)), "wind and field ambience running")


func test_forward_input_runs_in_camera_direction() -> void:
	var start := player.global_position
	Input.action_press("move_forward")
	await seconds(1.0)
	var moved := player.global_position - start
	check(moved.z < -3.5, "moved forward (-Z) about run speed: %.2f m" % -moved.z)
	check(absf(moved.x) < 0.3, "no sideways drift")
	check(heard.has(&"footstep"), "footsteps heard while running")


func test_sprint_is_faster_than_running() -> void:
	Input.action_press("move_forward")
	await seconds(0.6)
	var a := player.global_position
	await seconds(1.0)
	var run := (player.global_position - a).length()
	Input.action_press("sprint")
	await seconds(0.5)
	var b := player.global_position
	await seconds(1.0)
	var sprint := (player.global_position - b).length()
	check(sprint > run * 1.3, "sprint (%.2f m/s) clearly faster than run (%.2f m/s)" % [sprint, run])


func test_jump_leaves_ground_and_lands() -> void:
	Input.action_press("jump")
	await physics_frames(2)
	Input.action_release("jump")
	var peak := player.global_position.y
	for i in 30:
		await physics_frames(1)
		peak = maxf(peak, player.global_position.y)
	check(peak > 0.8, "jump height %.2f m" % peak)
	await seconds(1.0)
	check(player.is_on_floor(), "landed again")
	check(heard.has(&"land"), "landing sound")


func test_camera_toggle_switches_to_first_person() -> void:
	var pc := player.controller as PlayerController
	pc.toggle_camera()
	await frames(2)
	check(pc.fp_camera.current, "first-person camera active")
	check_near(pc.fp_camera.global_position.y - player.global_position.y, PlayerController.EYE_HEIGHT, 0.15, "first-person camera at eye height")
	check((pc.fp_camera.cull_mask & (1 << 1)) == 0, "first-person camera hides head meshes (layer 2)")
	pc.toggle_camera()
	await frames(1)
	check(pc.tp_camera.current, "back to third person")


func test_damage_reduces_health_with_hurt_sound() -> void:
	var dealt := player.take_damage(30.0)
	check_near(dealt, 30.0, 0.01, "30 damage dealt")
	check_near(player.health.current, 70.0, 0.01, "health 70")
	check(heard.has(&"hurt"), "hurt sound")
	await frames(1)
	check_near(battle.hud.health_bar.value, 70.0, 0.01, "HUD health bar follows")


func test_death_and_respawn() -> void:
	battle.respawn_delay = 1.0
	var pc := player.controller as PlayerController
	pc.toggle_camera()  # first person: death must switch to the outside view
	var died := [false]
	player.died.connect(func(_s, _k): died[0] = true)
	player.take_damage(150.0)
	await frames(1)
	check(died[0] and not player.alive, "player died")
	check(heard.has(&"death_cry"), "death cry")
	check_eq(player.collision_layer, 0, "corpse no longer collides")
	check(pc.tp_camera.current, "dead player seen in third person")
	check(battle.hud.death_panel.visible, "death / respawn panel shown")
	Input.action_press("move_forward")
	var p := player.global_position
	await seconds(0.5)
	check(player.global_position.distance_to(p) < 0.5, "the dead don't move")
	await seconds(0.8)
	check(heard.has(&"body_fall"), "body fall sound")
	check(player.alive, "respawned after the delay")
	check_near(player.health.current, 100.0, 0.01, "full health after respawn")
	check(heard.has(&"respawn"), "respawn cue")
	check(not battle.hud.death_panel.visible, "death panel hidden")
	check(pc.fp_camera.current, "first-person preference restored")
	check_eq(player.deaths, 1, "death counted")


func test_falling_out_of_world_kills() -> void:
	player.global_position = Vector3(0, -40, 0)
	await physics_frames(2)
	check(not player.alive, "out-of-world soldier dies")


func test_upper_body_action_plays_while_moving() -> void:
	Input.action_press("move_forward")
	await seconds(0.3)
	player.visual.play_action(&"slash", 0.6)
	await physics_frames(5)
	check(player.visual.is_action_playing(), "slash action running")
	check(player.velocity.length() > 3.0, "still running during the upper-body action")


func test_pause_menu_pauses_and_resumes() -> void:
	battle.pause_menu.open()
	check(get_tree().paused, "game paused")
	battle.pause_menu.close()
	check(not get_tree().paused, "game resumed")
