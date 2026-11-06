extends Node
## v5 tour/gameplay frame capture: live AI battle, scripted camera, PNG per frame.
## Run with --fixed-fps so game time advances exactly 1/fps per rendered frame.
## Env: TOUR_OUT (dir), TOUR_FPS (24), TOUR_WARMUP (sim seconds before recording, 3D disabled)

var battle: Battle
var cam: Camera3D

const SHOTS := [  # [seconds, from_pos, from_look, to_pos, to_look]
	[4.0, Vector3(150, 80, 180), Vector3(0, 5, 0), Vector3(60, 40, 70), Vector3(0, 8, 0)],
	[3.5, Vector3(-30, 12, -98), Vector3(0, 4, -128), Vector3(18, 9, -104), Vector3(0, 5, -150)],
	[3.0, Vector3(82, 10, -24), Vector3(55, 4, -45), Vector3(72, 8, -62), Vector3(55, 4, -42)],
	[3.0, Vector3(-30, 9, 68), Vector3(-55, 3, 45), Vector3(-42, 6, 72), Vector3(-58, 3, 40)],
	[3.0, Vector3(-10, 6, -22), Vector3(0, 3, -6), Vector3(10, 5, -22), Vector3(0, 3, -5)],
]

func _ready() -> void:
	var out := OS.get_environment("TOUR_OUT")
	var fps := float(OS.get_environment("TOUR_FPS")) if OS.get_environment("TOUR_FPS") != "" else 24.0
	var warm := float(OS.get_environment("TOUR_WARMUP")) if OS.get_environment("TOUR_WARMUP") != "" else 25.0
	DirAccess.make_dir_recursive_absolute(out)
	battle = load("res://scenes/battle.tscn").instantiate()
	battle.config = battle.config.duplicate()
	battle.config.soldiers_per_faction = 16
	add_child(battle)
	await get_tree().physics_frame
	var p := battle.player
	(p.controller as PlayerController).input_enabled = false
	p.health.max_health = 1e9
	p.health.restore_full()
	get_viewport().disable_3d = true
	for i in int(warm * fps):
		await get_tree().process_frame
	get_viewport().disable_3d = false
	cam = Camera3D.new()
	cam.far = 1200.0
	cam.fov = 55.0
	add_child(cam)
	cam.current = true
	var n := 0
	for s in SHOTS:
		var frames := int(s[0] * fps)
		for f in frames:
			var t := smoothstep(0.0, 1.0, float(f) / frames)
			_place((s[1] as Vector3).lerp(s[3], t), (s[2] as Vector3).lerp(s[4], t))
			n = await _grab(out, n)
	# Combat follow: over-the-shoulder on the soldier nearest objective B, re-picked if it dies.
	var follow_frames := int(7.0 * fps)
	var target: Node3D = null
	for f in follow_frames:
		if target == null or not is_instance_valid(target) or (target is Soldier and (target as Soldier).health.is_dead()):
			target = _nearest_soldier(Vector3.ZERO)
		if target:
			var fwd := -target.global_transform.basis.z
			fwd.y = 0.0
			fwd = fwd.normalized() if fwd.length() > 0.1 else Vector3.FORWARD
			var desired := target.global_position - fwd * 4.5 + Vector3(0, 2.4, 0) + target.global_transform.basis.x * 0.8
			cam.global_position = cam.global_position.lerp(desired, 0.15 if f > 0 else 1.0)
			cam.look_at(target.global_position + fwd * 6.0 + Vector3(0, 1.4, 0), Vector3.UP)
		n = await _grab(out, n)
	print("[tour] frames=", n)
	AudioManager.quit_game(0)


func _place(pos: Vector3, look: Vector3) -> void:
	cam.global_position = pos
	cam.look_at(look, Vector3.UP)


func _grab(out: String, n: int) -> int:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg("%s/f_%05d.jpg" % [out, n], 0.92)
	if n % 48 == 0:
		print("[tour] frame ", n)
	return n + 1


func _nearest_soldier(p: Vector3) -> Node3D:
	var best: Node3D = null
	var bd := INF
	for s in battle.soldiers:
		if not is_instance_valid(s) or s == battle.player:
			continue
		if s.health.is_dead():
			continue
		var d: float = s.global_position.distance_to(p)
		if d < bd:
			bd = d
			best = s
	return best
