extends TestCase
## M5: capturing, contesting, neutralising, tickets, bleed, match end, HUD and cues.

var battle: Battle
var heard: Array[StringName] = []


func start(armies: bool = false, tickets: int = 150) -> void:
	battle = load("res://scenes/battle.tscn").instantiate()
	battle.ai_armies = armies
	battle.config = battle.config.duplicate()
	battle.config.starting_tickets = tickets
	add_child(battle)
	heard.clear()
	AudioManager.sound_played.connect(_on_sound)
	(battle.player.controller as PlayerController).input_enabled = false
	await physics_frames(5)


func after_each() -> void:
	AudioManager.sound_played.disconnect(_on_sound)
	Engine.time_scale = 1.0
	if is_instance_valid(battle):
		battle.queue_free()
	await frames(2)
	Music.stop(0.0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_sound(id: StringName, _pos: Variant) -> void:
	heard.append(id)


func point(id: StringName) -> CapturePoint:
	for cp in battle.conquest.points:
		if cp.objective_id == id:
			return cp
	return null


func stand(s: Soldier, cp: CapturePoint, offset: Vector3 = Vector3.ZERO) -> void:
	s.respawn_at(Transform3D(Basis.IDENTITY, cp.global_position + offset + Vector3(0, 0.4, 0)))


func soldier(faction: int) -> Soldier:
	var s := battle.spawn_soldier(faction, false, [&"katana"] as Array[StringName])
	battle.director.register(s)
	return s


func test_player_captures_a_neutral_point() -> void:
	await start()
	var b := point(&"B")
	stand(battle.player, b, Vector3(2, 0, 0))
	await seconds(5.0)
	check(b.progress > 0.25 and b.owner_faction == CapturePoint.NEUTRAL, "progress climbing, not yet owned (%.2f)" % b.progress)
	check(heard.has(&"capture_tick"), "capture ticks while capturing")
	check(battle.conquest_hud._capture_box.visible, "capture bar shown")
	check(battle.conquest_hud._capture_label.text.begins_with("Capturing"), "HUD says Capturing (%s)" % battle.conquest_hud._capture_label.text)
	await seconds(8.0)
	check_eq(b.owner_faction, 0, "B captured after ~12 s")
	check(heard.has(&"objective_captured"), "captured cue")


func test_more_soldiers_capture_faster() -> void:
	await start()
	var c := point(&"C")
	stand(battle.player, c)
	for i in 2:
		stand(soldier(0), c, Vector3(3 + i * 1.5, 0, 0))
	await seconds(8.5)
	check_eq(c.owner_faction, 0, "three soldiers capture in ~8 s (12 s / 1.5)")


func test_enemy_presence_contests() -> void:
	await start()
	var a := point(&"A")
	stand(battle.player, a)
	stand(soldier(1), a, Vector3(4, 0, 0))
	await seconds(4.0)
	check(a.contested, "point contested")
	check_near(a.progress, 0.0, 0.001, "no progress while contested")
	check(heard.has(&"objective_contested"), "contested cue")
	check(battle.conquest_hud._capture_label.text.contains("CONTESTED"), "HUD says contested")


func test_enemy_point_is_neutralised_then_captured() -> void:
	await start()
	var b := point(&"B")
	b.progress = -1.0
	b.set_owner_faction(1)
	stand(battle.player, b)
	await seconds(6.5)
	check_eq(b.owner_faction, CapturePoint.NEUTRAL, "enemy point neutralised first")
	check(battle.conquest_hud._capture_label.text.begins_with("Capturing"), "then capturing")
	await seconds(12.5)
	check_eq(b.owner_faction, 0, "then captured")


func test_losing_a_point_plays_lost_cue() -> void:
	await start()
	var a := point(&"A")
	a.progress = 1.0
	a.set_owner_faction(0)
	stand(soldier(1), a)
	await seconds(13.0)
	check(a.owner_faction != 0, "enemy took the point from us")
	check(heard.has(&"objective_lost"), "lost cue")


func test_deaths_cost_tickets() -> void:
	await start()
	var e := soldier(1)
	stand(e, point(&"C"))
	e.die(null)
	await physics_frames(2)
	check_eq(battle.conquest.ticket_count(1), 149, "a death costs one ticket")


func test_holding_more_points_bleeds_the_enemy() -> void:
	await start()
	for id in [&"A", &"B"]:
		point(id).progress = 1.0
		point(id).set_owner_faction(0)
	await seconds(10.0)
	var t0 := battle.conquest.ticket_count(0)
	var t1 := battle.conquest.ticket_count(1)
	check_eq(t0, 150, "the side holding more points doesn't bleed")
	check(t1 <= 145 and t1 >= 144, "enemy bleeds 2 x 0.25 per second (%d after 10 s)" % t1)


func test_low_tickets_warning_and_defeat() -> void:
	await start(false, 32)
	var mine := soldier(0)
	for i in 3:
		stand(mine, point(&"A"))
		mine.die(null)
		await physics_frames(2)
	check(heard.has(&"ticket_warning"), "conch warning at 30 tickets or below")
	for i in 29:
		mine.respawn_at(Transform3D(Basis.IDENTITY, point(&"A").global_position + Vector3(0, 0.4, 0)))
		mine.die(null)
	await seconds(2.0)
	check(battle.conquest.over, "match over at zero tickets")
	check_eq(battle.conquest.winner, 1, "the enemy wins")
	check(battle.conquest_hud.is_end_visible(), "end screen shown")
	check_eq(battle.conquest_hud._end_title.text, "DEFEAT", "DEFEAT for the player's side")
	check_eq(Music.current, &"defeat", "defeat music")
	check(not (battle.player.controller as PlayerController).input_enabled, "player input disabled")


func test_victory() -> void:
	await start(false, 3)
	var e := soldier(1)
	for i in 3:
		e.respawn_at(Transform3D(Basis.IDENTITY, point(&"C").global_position + Vector3(0, 0.4, 0)))
		e.die(battle.player)
	await seconds(2.0)
	check_eq(battle.conquest.winner, 0, "player's side wins")
	check_eq(battle.conquest_hud._end_title.text, "VICTORY", "VICTORY screen")
	check_eq(Music.current, &"victory", "victory music")


func test_hud_shows_tickets_and_objectives() -> void:
	await start()
	await frames(2)
	var hud := battle.conquest_hud
	check_eq(hud._tickets[0].text, "150", "our tickets shown")
	check_eq(hud._chips.size(), 3, "three objective chips")
	Input.action_press("scoreboard")
	await frames(2)
	check(hud._scoreboard.visible, "Tab shows the scoreboard")
	check(hud._score_text.text.contains("You"), "player listed on the scoreboard")
	Input.action_release("scoreboard")
	await frames(2)
	check(not hud._scoreboard.visible, "released Tab hides it")


func test_respawn_at_a_held_point() -> void:
	await start()
	var b := point(&"B")
	b.progress = 1.0
	b.set_owner_faction(0)
	battle.respawn_delay = 0.5
	battle.player.die(null)
	await seconds(1.0)
	check(battle.player.alive, "respawned")
	check(battle.player.global_position.distance_to(b.global_position) < b.radius + 1.0, "respawned at the held point B")


func test_full_ai_conquest_match_reaches_a_winner() -> void:
	# The success criterion, AI vs AI: armies capture, fight, bleed and someone wins.
	await start(true, 60)
	battle.player.health.max_health = 1e9
	battle.player.health.restore_full()
	var captured := [0]
	Events.objective_captured.connect(func(_cp, _f): captured[0] += 1)
	for i in 300:  # up to 5 simulated minutes
		await seconds(1.0)
		if battle.conquest.over:
			break
	check(captured[0] >= 3, "objectives changed hands (%d captures)" % captured[0])
	check(battle.conquest.over, "the match ended (tickets %d : %d)" % [battle.conquest.ticket_count(0), battle.conquest.ticket_count(1)])
	check(battle.conquest.winner == 0 or battle.conquest.winner == 1, "there is a winner")
