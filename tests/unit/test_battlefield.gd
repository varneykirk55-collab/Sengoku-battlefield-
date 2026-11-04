extends TestCase
## M3: battlefield layout, spawns, objectives, navigation and environmental audio.

var battle: Battle
var field: Battlefield
var heard: Array[StringName] = []


func before_each() -> void:
	battle = load("res://scenes/battle.tscn").instantiate()
	battle.training_targets = false
	add_child(battle)
	field = battle.field as Battlefield
	AudioManager.sound_played.connect(_on_sound)
	await physics_frames(10)
	heard.clear()


func after_each() -> void:
	Input.action_release("move_forward")
	AudioManager.sound_played.disconnect(_on_sound)
	battle.queue_free()
	await frames(2)
	Music.stop(0.0)


func _on_sound(id: StringName, _pos: Variant) -> void:
	heard.append(id)


func test_three_objectives_on_the_ground() -> void:
	var ids: Array[StringName] = []
	for cp in field.objectives:
		ids.append(cp.objective_id)
		check_near(cp.global_position.y, field.height_at(cp.global_position.x, cp.global_position.z), 0.05, "%s sits on the ground" % cp.objective_id)
		check_eq(cp.owner_faction, CapturePoint.NEUTRAL, "%s starts neutral" % cp.objective_id)
	check_eq(ids, [&"A", &"B", &"C"], "objectives A, B, C")
	var b := field.objectives[1]
	check(b.global_position.y > field.objectives[0].global_position.y + 3.0, "B is on the hill")


func test_each_faction_has_a_camp_with_spawns() -> void:
	for f in 2:
		var pts := field.spawn_points(f)
		check(pts.size() >= 5, "faction %d has spawn points (%d)" % [f, pts.size()])
		for p in pts:
			check(absf(p.global_position.y - field.height_at(p.global_position.x, p.global_position.z)) < 0.5, "spawn %s on the ground" % p.name)
	var south := field.spawn_points(0)[0].global_position
	var north := field.spawn_points(1)[0].global_position
	check(south.z > 100.0 and north.z < -100.0, "camps at opposite ends")


func test_player_spawns_in_south_camp_and_can_run() -> void:
	var p := battle.player
	await seconds(0.6)  # spawned slightly above the ground
	check(p.global_position.z > 100.0, "player spawned in the south camp (z=%.0f)" % p.global_position.z)
	check(p.is_on_floor(), "standing on the terrain")
	var start := p.global_position
	Input.action_press("move_forward")
	await seconds(2.0)
	check(p.global_position.distance_to(start) > 6.0, "ran across the terrain")
	check(p.is_on_floor(), "still grounded")


func test_navigation_reaches_every_objective_from_both_camps() -> void:
	check(field.nav_region != null and field.nav_region.navigation_mesh.get_polygon_count() > 1000, "baked navmesh loaded")
	var map_rid := field.get_world_3d().navigation_map
	# Large regions sync asynchronously; wait until the map answers queries.
	var probe := field.spawn_points(0)[2].global_position
	for i in 240:
		if NavigationServer3D.map_get_iteration_id(map_rid) > 0 and NavigationServer3D.map_get_closest_point(map_rid, probe).distance_to(probe) < 3.0:
			break
		await physics_frames(1)
	for f in 2:
		var from := NavigationServer3D.map_get_closest_point(map_rid, field.spawn_points(f)[2].global_position)
		for cp in field.objectives:
			var to := NavigationServer3D.map_get_closest_point(map_rid, cp.global_position)
			var path := NavigationServer3D.map_get_path(map_rid, from, to, true)
			check(path.size() >= 2, "path from camp %d to %s" % [f, cp.objective_id])
			if path.size() >= 2:
				check(path[path.size() - 1].distance_to(cp.global_position) < 2.5, "camp %d path reaches %s" % [f, cp.objective_id])


func test_baked_navmesh_matches_current_layout() -> void:
	# Guards against changing the map without re-running tools/bake_navmesh.sh.
	var fresh := Battlefield.make_navigation_mesh()
	var src := NavigationMeshSourceGeometryData3D.new()
	var probe := Battlefield.new()
	probe.load_navigation = false
	add_child(probe)
	await physics_frames(1)
	NavigationServer3D.parse_source_geometry_data(fresh, src, probe)
	NavigationServer3D.bake_from_source_geometry_data(fresh, src)
	var saved: NavigationMesh = load(Battlefield.NAV_PATH)
	check_eq(fresh.get_polygon_count(), saved.get_polygon_count(), "saved navmesh is up to date (re-run tools/bake_navmesh.sh)")
	probe.queue_free()


func test_capture_point_counts_soldiers_inside() -> void:
	var b := field.objectives[1]
	var s := battle.spawn_soldier(1, false, [&"katana"] as Array[StringName])
	s.respawn_at(Transform3D(Basis.IDENTITY, b.global_position + Vector3(2, 0.3, 0)))
	await physics_frames(5)
	check_eq(b.soldiers_inside(), [0, 1] as Array[int], "one faction-1 soldier counted in B")
	s.die(null)
	await physics_frames(3)
	check_eq(b.soldiers_inside(), [0, 0] as Array[int], "the dead don't hold objectives")


func test_cannot_leave_the_map() -> void:
	var p := battle.player
	p.respawn_at(Transform3D(Basis(Vector3.UP, -PI / 2), field.ground_point(Battlefield.HALF_X - 12, 0) + Vector3(0, 1, 0)))
	(p.controller as PlayerController)._yaw = -PI / 2  # face +X, the east edge
	Input.action_press("move_forward")
	await seconds(4.0)
	check(p.global_position.x < Battlefield.HALF_X - 2.0, "stopped at the boundary (x=%.1f)" % p.global_position.x)
	check(p.alive, "still alive")


func test_environment_ambience_plays() -> void:
	check(battle.ambience.size() >= 2 and battle.ambience.all(func(a): return is_instance_valid(a) and a.playing), "wind and field beds playing")
	await seconds(10.0)
	check(heard.has(&"amb_bird"), "birds call from the trees")
