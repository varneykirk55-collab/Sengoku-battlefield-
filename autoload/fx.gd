extends Node3D
## Lightweight pooled combat effects: tracers, muzzle flash + smoke, blood, dust, sparks, hit-stop.
## Placeholder visuals built from primitives; every effect is pooled so big battles don't allocate.

const POOL := 24

var _tracers: Array[MeshInstance3D] = []
var _flashes: Array[OmniLight3D] = []
var _bursts: Dictionary = {}  # kind -> Array[CPUParticles3D]
var _next := {}
var _hitstop_token := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var tracer_mat := StandardMaterial3D.new()
	tracer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tracer_mat.albedo_color = Color(1.0, 0.85, 0.55, 0.55)
	tracer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in 12:
		var t := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(0.012, 0.012, 1.0)
		t.mesh = m
		t.material_override = tracer_mat.duplicate()
		t.visible = false
		t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(t)
		_tracers.append(t)
	for i in 6:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.7, 0.35)
		l.omni_range = 6.0
		l.light_energy = 0.0
		l.visible = false
		add_child(l)
		_flashes.append(l)
	_make_pool(&"smoke", 12, Color(0.75, 0.73, 0.7, 0.55), 40, 1.6, 0.45, 1.2, Vector3(0, 0.5, 0))
	_make_pool(&"blood", 12, Color(0.45, 0.02, 0.02, 0.9), 14, 0.45, 0.06, 3.0, Vector3(0, -9.8, 0))
	_make_pool(&"dust", 12, Color(0.55, 0.48, 0.38, 0.75), 14, 0.7, 0.1, 2.5, Vector3(0, -6, 0))
	_make_pool(&"sparks", 8, Color(1.0, 0.8, 0.35, 1.0), 26, 0.3, 0.025, 6.0, Vector3(0, -9.8, 0), true)


func tracer(from: Vector3, to: Vector3) -> void:
	var t := _tracers[_cycle(&"tracer", _tracers.size())]
	var len := from.distance_to(to)
	if len < 0.5:
		return
	t.visible = true
	t.global_transform = Transform3D(Basis.looking_at(to - from, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT), from.lerp(to, 0.5))
	t.scale = Vector3(1, 1, len)
	var mat := t.material_override as StandardMaterial3D
	mat.albedo_color.a = 0.55
	var tw := t.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.12)
	tw.tween_callback(func() -> void: t.visible = false)


func muzzle(pos: Vector3, dir: Vector3) -> void:
	var l := _flashes[_cycle(&"flash", _flashes.size())]
	l.global_position = pos + dir * 0.2
	l.visible = true
	l.light_energy = 6.0
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.09)
	tw.tween_callback(func() -> void: l.visible = false)
	_burst(&"smoke", pos + dir * 0.3, dir)


func blood(pos: Vector3, dir: Vector3) -> void:
	_burst(&"blood", pos, dir)


func dust(pos: Vector3, normal: Vector3) -> void:
	_burst(&"dust", pos, normal)


func sparks(pos: Vector3, dir: Vector3) -> void:
	_burst(&"sparks", pos, dir)


## Freezes time briefly for weight on hits (the player's hits only).
func hitstop(seconds: float) -> void:
	if seconds <= 0.0 or get_tree().paused:
		return
	Engine.time_scale = 0.05
	_hitstop_token += 1
	var token := _hitstop_token
	await get_tree().create_timer(seconds, true, false, true).timeout
	if token == _hitstop_token:  # a newer hit-stop extends the freeze
		Engine.time_scale = 1.0


func _cycle(kind: StringName, size: int) -> int:
	var i: int = _next.get(kind, 0)
	_next[kind] = (i + 1) % size
	return i


func _burst(kind: StringName, pos: Vector3, dir: Vector3) -> void:
	var pool: Array = _bursts[kind]
	var p: CPUParticles3D = pool[_cycle(kind, pool.size())]
	p.global_position = pos
	p.direction = dir.normalized() if dir.length() > 0.01 else Vector3.UP
	p.restart()


func _make_pool(kind: StringName, count: int, color: Color, amount: int, lifetime: float, size: float,
		speed: float, gravity: Vector3, unshaded: bool = false) -> void:
	var arr: Array[CPUParticles3D] = []
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = mat
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	for i in count:
		var p := CPUParticles3D.new()
		p.emitting = false
		p.one_shot = true
		p.explosiveness = 0.9
		p.amount = amount
		p.lifetime = lifetime
		p.mesh = quad
		p.spread = 35.0 if kind != &"smoke" else 25.0
		p.initial_velocity_min = speed * 0.4
		p.initial_velocity_max = speed
		p.gravity = gravity
		p.color_ramp = fade
		if kind == &"smoke":
			p.scale_amount_min = 1.0
			p.scale_amount_max = 2.6
			p.damping_min = 1.5
			p.damping_max = 3.0
		p.local_coords = false
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)
		arr.append(p)
	_bursts[kind] = arr
