extends TestCase
## M2: katana and matchlock combat, weapon switching, reloading, and their sounds.

var battle: Battle
var player: Soldier
var heard: Array[StringName] = []


func before_each() -> void:
	battle = load("res://scenes/battle.tscn").instantiate()
	battle.training_targets = false
	add_child(battle)
	player = battle.player
	AudioManager.sound_played.connect(_on_sound)
	await physics_frames(15)
	player.respawn_at(Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 0)))  # at the origin, facing -Z
	(player.controller as PlayerController)._yaw = 0.0
	(player.controller as PlayerController)._pitch = 0.0
	await physics_frames(5)
	heard.clear()
	Combat.clash_chance = 0.0


func after_each() -> void:
	for a in ["primary", "secondary", "move_forward"]:
		Input.action_release(a)
	AudioManager.sound_played.disconnect(_on_sound)
	Engine.time_scale = 1.0
	Combat.clash_chance = 0.3
	battle.queue_free()
	await frames(2)
	Music.stop(0.0)


func _on_sound(id: StringName, _pos: Variant) -> void:
	heard.append(id)


func enemy(pos: Vector3, loadout: Array[StringName] = [&"katana"], faction: int = 1) -> Soldier:
	var s := battle.spawn_soldier(faction, false, loadout)
	s.respawn_at(Transform3D(Basis(Vector3.UP, PI), pos))
	return s


func tap(action: String) -> void:
	Input.action_press(action)
	await physics_frames(1)
	Input.action_release(action)
	await physics_frames(1)


## Aims the player's shots straight at a point (instead of the camera crosshair).
func aim_player_at(target: Vector3) -> void:
	player.weapons.aim_provider = func() -> Array:
		var eye := player.head_position() - Vector3(0, 0.1, 0)
		return [eye, (target - eye).normalized()]


func test_player_spawns_with_katana_drawn_and_matchlock_slung() -> void:
	check(player.weapons.current() is KatanaWeapon, "katana drawn first")
	check(player.weapons.has(&"matchlock"), "player carries a matchlock")
	var k := player.weapons.get_weapon(&"katana")
	check(k.model.get_parent() == player.visual.hand_r, "katana model in the right hand")
	check((k.model.get_meta("scabbard", []) as Array).all(func(n): return not n.visible), "scabbard hidden while drawn")
	var m := player.weapons.get_weapon(&"matchlock")
	check(m.model.get_parent() == player.visual.gun_mount, "matchlock on its mount (slung)")


func test_light_attack_hits_enemy_in_front() -> void:
	var e := await enemy(Vector3(0, 0.1, -1.8))
	await physics_frames(5)
	await tap("primary")
	await seconds(0.5)
	check_near(e.health.current, 66.0, 0.5, "light cut deals 34")
	for id in [&"katana_swing_light", &"katana_hit", &"hit_marker", &"hurt"]:
		check(heard.has(id), "sound %s" % id)


func test_three_light_cuts_kill() -> void:
	var e := await enemy(Vector3(0, 0.1, -1.8))
	await physics_frames(5)
	for i in 3:
		await tap("primary")
		await seconds(0.6)
	check(not e.alive, "enemy killed by three light cuts")
	check_eq(player.kills, 1, "kill credited to the player")
	check(heard.has(&"kill_marker") and heard.has(&"death_cry"), "kill marker and death cry")


func test_heavy_attack_is_slow_and_strong() -> void:
	var e := await enemy(Vector3(0, 0.1, -2.0))
	await physics_frames(5)
	await tap("secondary")
	await seconds(0.25)
	check_near(e.health.current, 100.0, 0.01, "no damage during the heavy wind-up")
	await seconds(0.6)
	check_near(e.health.current, 25.0, 0.5, "heavy cut deals 75")
	check(heard.has(&"katana_swing_heavy"), "heavy swing sound")


func test_katana_spares_allies_and_misses_behind() -> void:
	var ally := await enemy(Vector3(0, 0.1, -1.6), [&"katana"], 0)
	var behind := await enemy(Vector3(0, 0.1, 1.8))
	await physics_frames(5)
	await tap("primary")
	await seconds(0.6)
	check_near(ally.health.current, 100.0, 0.01, "no friendly fire")
	check_near(behind.health.current, 100.0, 0.01, "enemy behind is not hit")


func test_melee_assist_turns_swing_onto_enemy() -> void:
	var e := await enemy(Vector3(-1.1, 0.1, -2.0))  # ~29 degrees left of the look direction
	await physics_frames(5)
	await tap("primary")
	await seconds(0.5)
	check(e.health.current < 100.0, "assisted cut hits an enemy off to the side")


func test_switch_to_matchlock_moves_models() -> void:
	await tap("weapon_matchlock")
	await seconds(0.5)
	check(player.weapons.current() is MatchlockWeapon, "matchlock selected")
	var k := player.weapons.get_weapon(&"katana")
	check(k.model.get_parent() == player.visual.hip, "katana sheathed at the hip")
	var scabbard: Array = k.model.get_meta("scabbard", [])
	check(not scabbard.is_empty() and scabbard.all(func(n): return n.visible), "scabbard visible when sheathed")
	var blade: Array = k.model.get_meta("blade", [])
	check(blade.all(func(n): return not n.visible), "blade hidden inside the scabbard")
	check_eq(player.visual.stance, &"matchlock", "matchlock stance")
	check(heard.has(&"weapon_raise"), "raise sound")
	await tap("switch_weapon")
	await seconds(0.5)
	check(player.weapons.current() is KatanaWeapon, "switch_weapon cycles back to the katana")
	check(heard.has(&"katana_draw"), "draw sound")


func test_cannot_switch_mid_swing() -> void:
	await tap("primary")
	await physics_frames(2)
	await tap("weapon_matchlock")
	check(player.weapons.current() is KatanaWeapon, "switch ignored during the swing")


func test_matchlock_shot_damages_and_reloads_slowly() -> void:
	var e := await enemy(Vector3(0, 0.1, -20))
	await tap("weapon_matchlock")
	await seconds(0.5)
	aim_player_at(e.chest_position())
	Input.action_press("secondary")
	await seconds(0.3)
	check(player.weapons.is_aiming(), "aiming")
	await tap("primary")
	await seconds(0.3)
	var gun := player.weapons.current() as MatchlockWeapon
	check_eq(gun.shots_fired, 1, "one shot fired")
	check_near(e.health.current, 15.0, 0.5, "matchlock ball deals 85 at 20 m")
	check(heard.has(&"matchlock_fire") and heard.has(&"bullet_hit_flesh"), "gunshot and impact sounds")
	Input.action_release("secondary")
	await seconds(1.0)
	check(gun.reloading, "reload starts automatically")
	var before := heard.size()
	await tap("primary")
	check(heard.slice(before).has(&"matchlock_dry"), "trying to fire while reloading clicks")
	check(not gun.loaded, "still loading after 1 s")
	await seconds(5.0)
	check(not gun.loaded, "still loading after 6 s (slow, historical reload)")
	await seconds(4.0)
	check(gun.loaded, "loaded again after ~9 s")
	check_eq(gun.reserve, 11, "one shot used from the reserve")
	for id in [&"reload_powder", &"reload_ball", &"reload_ram", &"reload_prime", &"reload_match"]:
		check(heard.has(id), "reload step sound %s" % id)


func test_headshot_kills() -> void:
	var e := await enemy(Vector3(0, 0.1, -15))
	await tap("weapon_matchlock")
	await seconds(0.5)
	aim_player_at(e.global_position + Vector3(0, 1.62, 0))
	Input.action_press("secondary")
	await seconds(0.3)
	await tap("primary")
	await seconds(0.3)
	check(not e.alive, "headshot kills outright")
	check((player.weapons.current() as MatchlockWeapon).last_shot.headshot, "shot recorded as a headshot")


func test_damage_falls_off_with_distance() -> void:
	var d: FirearmData = MatchlockWeapon.DATA
	check_near(d.damage_at(30.0), 85.0, 0.01, "full damage at 30 m")
	check_near(d.damage_at(100.0), 85.0 * 0.75, 0.01, "75% at 100 m")
	check_near(d.damage_at(200.0), 85.0 * 0.5, 0.01, "50% beyond 150 m")


func test_reload_progress_survives_switching() -> void:
	await tap("weapon_matchlock")
	await seconds(0.5)
	var gun := player.weapons.current() as MatchlockWeapon
	aim_player_at(player.global_position + Vector3(0, 0, -30))
	await tap("primary")
	await seconds(3.0)
	var progress := gun.reload_elapsed
	check(progress > 1.5, "reload under way")
	await tap("weapon_katana")
	await seconds(2.0)
	check_near(gun.reload_elapsed, progress, 0.05, "reload paused while the katana is out")
	await tap("weapon_matchlock")
	await seconds(1.0)
	check(gun.reload_elapsed > progress + 0.5, "reload resumes where it left off")


func test_bullets_do_not_hurt_allies() -> void:
	var ally := await enemy(Vector3(0, 0.1, -10), [&"katana"], 0)
	await tap("weapon_matchlock")
	await seconds(0.5)
	aim_player_at(ally.chest_position())
	Input.action_press("secondary")
	await seconds(0.3)
	await tap("primary")
	await seconds(0.3)
	check_near(ally.health.current, 100.0, 0.01, "no friendly fire from the matchlock")


func test_blades_clash() -> void:
	Combat.clash_chance = 1.0
	var e := await enemy(Vector3(0, 0.1, -1.8))
	await physics_frames(5)
	e.weapons.primary(true)  # enemy swings at the player at the same moment
	await tap("primary")
	await seconds(0.6)
	check(heard.has(&"blade_clash"), "clash sound")
	check(player.health.current > 99.0 or e.health.current > 99.0, "the clash stops at least one cut")


func test_near_miss_whiz() -> void:
	(player.controller as PlayerController).toggle_camera()  # ear at the head
	var e := await enemy(Vector3(0, 0.1, -25), [&"matchlock", &"katana"])
	await physics_frames(5)
	var gun := e.weapons.current() as MatchlockWeapon
	e.weapons.aim_provider = func() -> Array:
		var eye := e.head_position()
		return [eye, ((player.head_position() + Vector3(1.0, 0.3, 0)) - eye).normalized()]
	gun.data = gun.data.duplicate()
	gun.data.spread_hip = 0.0
	gun.data.spread_moving = 0.0
	e.weapons.primary(true)
	await seconds(0.3)
	check(heard.has(&"matchlock_fire"), "enemy gunshot heard")
	check(heard.has(&"bullet_whiz"), "ball passing close to the player whizzes")
	check_near(player.health.current, 100.0, 0.01, "near miss does no damage")
