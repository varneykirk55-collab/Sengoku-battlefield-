extends TestCase
## M4: AI armies — spawning, squads, objective movement, melee and ranged fighting, attack
## tokens against the player, respawning, battle audio and level of detail.

var battle: Battle
var heard: Array[StringName] = []


func after_each() -> void:
	AudioManager.sound_played.disconnect(_on_sound)
	if is_instance_valid(battle):
		battle.queue_free()
	await frames(2)
	Music.stop(0.0)


func _on_sound(id: StringName, _pos: Variant) -> void:
	heard.append(id)


func start(map: StringName, armies: bool, per_side: int = 16) -> void:
	battle = load("res://scenes/battle.tscn").instantiate()
	battle.map = map
	battle.ai_armies = armies
	battle.config = battle.config.duplicate()
	battle.config.soldiers_per_faction = per_side
	add_child(battle)
	heard.clear()
	AudioManager.sound_played.connect(_on_sound)
	var pc := battle.player.controller as PlayerController
	pc.input_enabled = false
	await physics_frames(5)


func make_player_invulnerable() -> void:
	battle.player.health.max_health = 1e9
	battle.player.health.restore_full()


## One AI soldier on the test ground, controlled by the battle's director.
func add_ai(faction: int, loadout: Array[StringName], pos: Vector3) -> AIController:
	var s := battle.spawn_soldier(faction, false, loadout)
	var ai := AIController.new()
	s.add_child(ai)
	battle.director.register(s)
	s.respawn_at(Transform3D(Basis.IDENTITY, pos))
	return ai


## Moves the (invulnerable) player — and with them the camera / listener — next to the busiest
## objective, so close-range battle sounds are within hearing distance.
func go_to_the_fighting() -> void:
	var best: CapturePoint = null
	var most := -1
	for cp in battle.director.objectives:
		var c := cp.soldiers_inside()
		if c[0] + c[1] > most:
			most = c[0] + c[1]
			best = cp
	var field := battle.field as Battlefield
	battle.player.respawn_at(Transform3D(Basis.IDENTITY, field.ground_point(best.global_position.x + 10, best.global_position.z + 10) + Vector3(0, 0.4, 0)))
	make_player_invulnerable()


func dummy(faction: int, pos: Vector3) -> Soldier:
	var s := battle.spawn_soldier(faction, false, [&"katana"] as Array[StringName])
	battle.director.register(s)
	s.respawn_at(Transform3D(Basis.IDENTITY, pos))
	s.protected_for = 0.0
	return s


func test_armies_spawn_16_v_16_with_squads() -> void:
	await start(&"battlefield", true)
	var counts := [0, 0]
	var ranged := [0, 0]
	for s in battle.soldiers:
		counts[s.faction] += 1
		if s.weapons.has(&"matchlock") and not s.is_player:
			ranged[s.faction] += 1
	check_eq(counts, [16, 16], "16 soldiers per side, player included")
	check(ranged[0] >= 5 and ranged[1] >= 5, "both sides field matchlock ashigaru (%s)" % [ranged])
	for ai in battle.director.ais:
		check(ai.squad != null and ai.squad.objective != null, "%s has a squad with an objective" % ai.soldier.name)
	var targeted := {}
	for sq in battle.director.squads:
		targeted[sq.objective.objective_id] = true
	check_eq(targeted.size(), 3, "squads spread over all three objectives")


func test_ai_leave_camp_and_reach_objectives() -> void:
	await start(&"battlefield", true)
	make_player_invulnerable()
	var start_pos := {}
	for s in battle.soldiers:
		start_pos[s] = s.global_position
	await seconds(40.0)
	var at_objectives := 0
	var never_moved := 0
	for s in battle.soldiers:
		if s.is_player:
			continue
		for cp in battle.director.objectives:
			if s.alive and s.global_position.distance_to(cp.global_position) < cp.radius + 6.0:
				at_objectives += 1
				break
		if s.deaths == 0 and s.global_position.distance_to(start_pos[s]) < 15.0:
			never_moved += 1
	check(at_objectives >= 8, "soldiers fighting over objectives after 40 s (%d)" % at_objectives)
	check_eq(never_moved, 0, "nobody stays stuck in camp")


func test_ai_melee_kills_an_enemy() -> void:
	await start(&"test_ground", false)
	battle.player.respawn_at(Transform3D(Basis.IDENTITY, Vector3(-30, 0.3, -52)))  # listener within earshot, but farther than the dummy
	make_player_invulnerable()
	var ai := add_ai(1, [&"katana"] as Array[StringName], Vector3(-30, 0.3, -20))
	var victim := dummy(0, Vector3(-30, 0.3, -32))
	await seconds(15.0)
	check(not victim.alive or victim.deaths > 0, "AI swordsman closes in and cuts the enemy down")
	check(ai.soldier.alive, "AI survives an unarmed-in-practice dummy")
	check(heard.has(&"katana_swing_light") or heard.has(&"katana_swing_heavy"), "swing sounds")


func test_ai_marksman_shoots_then_draws_katana_up_close() -> void:
	await start(&"test_ground", false)
	var ai := add_ai(1, [&"matchlock", &"katana"] as Array[StringName], Vector3(-40, 0.3, 30))
	var victim := dummy(0, Vector3(-40, 0.3, -10))  # 40 m away
	victim.health.max_health = 1e9
	victim.health.restore_full()
	await seconds(8.0)
	var gun := ai.soldier.weapons.get_weapon(&"matchlock") as MatchlockWeapon
	check(gun.shots_fired >= 1, "marksman fired at a target 40 m away (%d shots)" % gun.shots_fired)
	check(heard.has(&"matchlock_fire"), "gunshot heard")
	# Rush him: the enemy appears right next to the reloading marksman.
	victim.respawn_at(Transform3D(Basis.IDENTITY, ai.soldier.global_position + Vector3(0, 0.3, -4)))
	await seconds(2.0)
	check(ai.soldier.weapons.current() is KatanaWeapon, "marksman switches to the katana when rushed")


func test_at_most_two_ai_fight_the_player_at_once() -> void:
	await start(&"test_ground", false)
	make_player_invulnerable()
	battle.player.respawn_at(Transform3D(Basis.IDENTITY, Vector3(-40, 0.3, 0)))
	for i in 5:
		add_ai(1, [&"katana"] as Array[StringName], Vector3(-46 + i * 3.0, 0.3, -12))
	var worst := 0
	for i in 600:
		await physics_frames(1)
		worst = maxi(worst, battle.director.player_attacker_count())
	check(worst >= 1, "the player was attacked")
	check(worst <= battle.config.max_player_attackers, "never more than %d attackers on the player (saw %d)" % [battle.config.max_player_attackers, worst])


func test_full_battle_kills_respawns_and_sound() -> void:
	await start(&"battlefield", true)
	make_player_invulnerable()
	var kills := [0]
	Events.soldier_killed.connect(func(_v, k): if k is Soldier: kills[0] += 1)
	await seconds(25.0)
	check(heard.has(&"matchlock_fire_far"), "distant volleys heard from the camp")
	go_to_the_fighting()
	await seconds(20.0)
	check(kills[0] >= 5, "soldiers fall in battle (%d kills)" % kills[0])
	var respawned := 0
	for s in battle.soldiers:
		if s.deaths > 0 and s.alive:
			respawned += 1
	check(respawned >= 1, "fallen soldiers come back as reinforcements (%d)" % respawned)
	for id in [&"matchlock_fire", &"katana_hit", &"death_cry"]:
		check(heard.has(id), "battle sound %s" % id)
	var amb := battle.get_node("Ambience") as AmbienceDirector
	check(amb.far_intensity + amb.near_intensity > 0.5, "battle intensity drives the battle beds")
	check(is_instance_valid(amb.distant_bed) and amb.distant_bed.volume_db > AmbienceDirector.DISTANT_DB.x + 1.0, "distant battle bed rises above its floor (%.1f dB)" % amb.distant_bed.volume_db)


func test_battle_cries() -> void:
	await start(&"battlefield", true)
	make_player_invulnerable()
	await seconds(20.0)
	go_to_the_fighting()
	await seconds(25.0)
	check(heard.has(&"battle_cry"), "soldiers shout as they charge")


func test_distant_soldiers_use_cheaper_animation() -> void:
	await start(&"battlefield", true)
	await seconds(1.0)
	var far_cheap := true
	var near_full := true
	for s in battle.soldiers:
		var d := AudioManager.listener_position().distance_to(s.global_position)
		if s.is_player:
			continue
		if d > 130.0 and s.visual.update_interval < 0.1:
			far_cheap = false
		if d < 20.0 and s.visual.update_interval > 0.0:
			near_full = false
	check(far_cheap, "soldiers far away animate at a reduced rate")
	check(near_full, "nearby soldiers animate every frame")
