extends Node
## Headless battle simulation for AI checks and profiling.
##   SIM_SECONDS=90 SIM_SOLDIERS=16 tools/sim.sh
## The player stands still in camp (input disabled) and is made invulnerable, so the armies fight
## on their own. Prints a report: kills, objective presence, stuck soldiers, CPU cost per frame.

var battle: Battle
var report := {}

func _ready() -> void:
	var secs := float(OS.get_environment("SIM_SECONDS")) if OS.get_environment("SIM_SECONDS") != "" else 60.0
	var per_side := int(OS.get_environment("SIM_SOLDIERS")) if OS.get_environment("SIM_SOLDIERS") != "" else 16
	battle = load("res://scenes/battle.tscn").instantiate()
	battle.config = battle.config.duplicate()
	battle.config.soldiers_per_faction = per_side
	add_child(battle)
	await get_tree().physics_frame
	var p := battle.player
	(p.controller as PlayerController).input_enabled = false
	p.health.max_health = 1e9
	p.health.restore_full()
	var kills := [0, 0]
	Events.soldier_killed.connect(func(v: Node, k: Node) -> void:
		if k is Soldier: kills[(k as Soldier).faction] += 1)
	var start_pos := {}
	for s in battle.soldiers:
		start_pos[s] = s.global_position
	var phys_ms := 0.0
	var proc_ms := 0.0
	var frames := 0
	var worst := 0.0
	var presence := {&"A": [0, 0], &"B": [0, 0], &"C": [0, 0]}
	var t0 := Time.get_ticks_msec()
	var steps := int(secs * 60.0)
	var last := Time.get_ticks_usec()
	for i in steps:
		await get_tree().physics_frame
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000.0  # whole frame on the CPU (headless: no rendering)
		last = now
		phys_ms += ms
		if i > 30:
			worst = maxf(worst, ms)
		frames += 1
		if i % 60 == 0:
			for cp in battle.director.objectives:
				var c := cp.soldiers_inside()
				presence[cp.objective_id][0] += c[0]
				presence[cp.objective_id][1] += c[1]
	var wall := (Time.get_ticks_msec() - t0) / 1000.0
	var never_left := 0
	for s in battle.soldiers:
		if s != p and s.deaths == 0 and s.global_position.distance_to(start_pos[s]) < 15.0:
			never_left += 1
	var orders := {}
	for sq in battle.director.squads:
		orders["%d:%s" % [sq.faction, sq.objective.objective_id if sq.objective else "-"]] = orders.get("%d:%s" % [sq.faction, sq.objective.objective_id if sq.objective else "-"], 0) + 1
	print("[sim] %d v %d for %.0f s simulated in %.1f s wall" % [per_side, per_side, secs, wall])
	print("[sim] kills by faction 0: %d, faction 1: %d" % kills)
	print("[sim] squads -> objectives: %s" % orders)
	print("[sim] avg soldiers present per sample (f0,f1): %s" % presence)
	print("[sim] soldiers that never left camp alive: %d / %d" % [never_left, battle.soldiers.size() - 1])
	print("[sim] CPU per frame (headless, no rendering): avg %.2f ms, worst %.2f ms" % [phys_ms / frames, worst])
	print("[sim] director: %s  audio: %s" % [battle.director.stats, AudioManager.stats])
	print("[sim] battle beds: near %.1f far %.1f" % [(battle.get_node("Ambience") as AmbienceDirector).near_intensity, (battle.get_node("Ambience") as AmbienceDirector).far_intensity])
	AudioManager.quit_game()
