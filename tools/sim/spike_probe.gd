extends Node
## Finds what coincides with slow frames in a big battle.
func _ready() -> void:
	var b: Battle = load("res://scenes/battle.tscn").instantiate()
	b.config = b.config.duplicate()
	b.config.soldiers_per_faction = int(OS.get_environment("SIM_SOLDIERS")) if OS.get_environment("SIM_SOLDIERS") != "" else 32
	add_child(b)
	await get_tree().physics_frame
	(b.player.controller as PlayerController).input_enabled = false
	b.player.health.max_health = 1e9
	b.player.health.restore_full()
	if OS.get_environment("NO_SOLDIER_COLLISION") == "1":
		for s in b.soldiers:
			if not s.is_player:
				s.collision_mask = Soldier.LAYER_WORLD
	if OS.get_environment("NO_AI") == "1":
		b.director.process_mode = Node.PROCESS_MODE_DISABLED
	var deaths := [0]
	var spawns := [0]
	Events.soldier_killed.connect(func(_v, _k): deaths[0] += 1)
	Events.soldier_spawned.connect(func(_s): spawns[0] += 1)
	for i in 30:
		await get_tree().physics_frame
	AIController.prof_think_us = 0
	AIController.prof_steer_us = 0
	Soldier.prof_move_us = 0
	SoldierVisual.prof_anim_us = 0
	Soldier.prof_slide_us = 0
	var last := Time.get_ticks_usec()
	var spikes := {"reassign": 0, "death": 0, "spawn": 0, "other": 0, "total": 0}
	var hist := [0, 0, 0, 0, 0]
	var avg_sum := 0.0
	var avg_n := 0  # <4, 4-8, 8-12, 12-16, >16 ms
	var r0: int = b.director.stats.reassignments
	for i in 60 * 40:
		var d0: int = deaths[0]
		var s0: int = spawns[0]
		var ra: int = b.director.stats.reassignments
		await get_tree().physics_frame
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000.0
		last = now
		if i < 30:
			continue
		hist[mini(int(ms / 4.0), 4)] += 1
		avg_sum += ms
		avg_n += 1
		if ms > 8.0:
			spikes.total += 1
			if b.director.stats.reassignments != ra:
				spikes.reassign += 1
			elif deaths[0] != d0:
				spikes.death += 1
			elif spawns[0] != s0:
				spikes.spawn += 1
			else:
				spikes.other += 1
	print("[probe] avg %.2f ms" % [avg_sum / max(avg_n, 1)])
	var n := float(max(avg_n, 1)) * 1000.0
	print("[probe] per frame: AI think %.2f ms, AI steering %.2f ms, soldier movement %.2f ms (move_and_slide %.2f ms), animation %.2f ms" % [
		AIController.prof_think_us / n, AIController.prof_steer_us / n, Soldier.prof_move_us / n, Soldier.prof_slide_us / n, SoldierVisual.prof_anim_us / n])
	print("[probe] frame-time histogram <4/4-8/8-12/12-16/>16 ms: %s" % [hist])
	print("[probe] slow frames (>8 ms) coinciding with: %s" % spikes)
	AudioManager.quit_game()
