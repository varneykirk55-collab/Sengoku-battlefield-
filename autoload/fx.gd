extends Node3D
## Pooled combat VFX: soft black-powder smoke, muzzle flash, soft tracers, impacts, hit-stop.
## Soft circular textures live in res://assets/vfx/ (procedural PNGs). No solid QuadMesh boxes.

const SMOKE_TEX := preload("res://assets/vfx/soft_smoke.png")
const FLASH_TEX := preload("res://assets/vfx/muzzle_flash.png")
const TRACER_TEX := preload("res://assets/vfx/soft_tracer.png")
const DUST_TEX := preload("res://assets/vfx/soft_dust.png")

var _tracers: Array[MeshInstance3D] = []
var _flashes: Array[OmniLight3D] = []
var _flash_sprites: Array[MeshInstance3D] = []
var _bursts: Dictionary = {}  # kind -> Array[CPUParticles3D]
var _next := {}
var _hitstop_token := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_tracers()
	_build_muzzle_lights()
	_build_flash_sprites()
	_make_pool(&"smoke", 16, Color(0.55, 0.52, 0.48, 0.7), 28, 1.9, 0.55, 0.85, Vector3(0, 0.35, 0), SMOKE_TEX, false, true)
	_make_pool(&"blood", 12, Color(0.5, 0.02, 0.02, 0.85), 12, 0.4, 0.05, 2.8, Vector3(0, -9.8, 0), DUST_TEX)
	_make_pool(&"dust", 12, Color(0.55, 0.48, 0.38, 0.7), 12, 0.65, 0.09, 2.2, Vector3(0, -5.5, 0), DUST_TEX)
	_make_pool(&"sparks", 8, Color(1.0, 0.75, 0.3, 1.0), 18, 0.28, 0.02, 5.5, Vector3(0, -9.8, 0), DUST_TEX, true)
	_make_pool(&"wood", 8, Color(0.45, 0.3, 0.15, 0.85), 10, 0.55, 0.07, 2.4, Vector3(0, -7.0, 0), DUST_TEX)
	_make_pool(&"armor", 8, Color(0.7, 0.7, 0.65, 0.9), 14, 0.35, 0.03, 4.0, Vector3(0, -8.0, 0), DUST_TEX, true)


func tracer(from: Vector3, to: Vector3) -> void:
	var t := _tracers[_cycle(&"tracer", _tracers.size())]
	var len := from.distance_to(to)
	if len < 0.8:
		return
	t.visible = true
	var mid := from.lerp(to, 0.5)
	var dir := to - from
	t.global_transform = Transform3D(
		Basis.looking_at(dir, Vector3.UP if absf(dir.normalized().y) < 0.99 else Vector3.RIGHT),
		mid
	)
	# Soft streak: thin in X/Y, length along -Z (looking_at forward).
	t.scale = Vector3(0.035, 0.035, len)
	var mat := t.material_override as StandardMaterial3D
	mat.albedo_color.a = 0.35
	var tw := t.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.1)
	tw.tween_callback(func() -> void: t.visible = false)


func muzzle(pos: Vector3, dir: Vector3) -> void:
	var d := dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	var at := pos + d * 0.15
	# Bright point light (short).
	var l := _flashes[_cycle(&"flash", _flashes.size())]
	l.global_position = at
	l.visible = true
	l.light_energy = 8.0
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.08)
	tw.tween_callback(func() -> void: l.visible = false)
	# Soft textured flash sprite.
	var spr := _flash_sprites[_cycle(&"flash_spr", _flash_sprites.size())]
	spr.visible = true
	spr.global_position = at
	spr.look_at(at + d, Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT)
	spr.scale = Vector3(0.35, 0.35, 0.35)
	var sm := spr.material_override as StandardMaterial3D
	sm.albedo_color.a = 1.0
	var tw2 := spr.create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(spr, "scale", Vector3(0.9, 0.9, 0.9), 0.07)
	tw2.tween_property(sm, "albedo_color:a", 0.0, 0.09)
	tw2.chain().tween_callback(func() -> void: spr.visible = false)
	# Soft black-powder puff drifting up.
	_burst(&"smoke", pos + d * 0.25, (d + Vector3(0, 0.6, 0)).normalized())


func blood(pos: Vector3, dir: Vector3) -> void:
	_burst(&"blood", pos, dir)


func dust(pos: Vector3, normal: Vector3) -> void:
	_burst(&"dust", pos, normal)


func sparks(pos: Vector3, dir: Vector3) -> void:
	_burst(&"sparks", pos, dir)


func wood_chips(pos: Vector3, normal: Vector3) -> void:
	_burst(&"wood", pos, normal)


func armor_sparks(pos: Vector3, dir: Vector3) -> void:
	_burst(&"armor", pos, dir)
	_burst(&"sparks", pos, dir)


## Surface-aware impact: flesh / armor / wood / ground.
func impact(pos: Vector3, normal: Vector3, kind: StringName) -> void:
	match kind:
		&"flesh":
			blood(pos, -normal)
		&"armor":
			armor_sparks(pos, normal)
		&"wood":
			wood_chips(pos, normal)
		_:
			dust(pos, normal)


func hitstop(seconds: float) -> void:
	if seconds <= 0.0 or get_tree().paused:
		return
	Engine.time_scale = 0.05
	_hitstop_token += 1
	var token := _hitstop_token
	await get_tree().create_timer(seconds, true, false, true).timeout
	if token == _hitstop_token:
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


func _build_tracers() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.88, 0.55, 0.35)
	mat.albedo_texture = TRACER_TEX
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in 12:
		var t := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1, 1)
		t.mesh = q
		t.material_override = mat.duplicate()
		t.visible = false
		t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(t)
		_tracers.append(t)


func _build_muzzle_lights() -> void:
	for i in 8:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.72, 0.35)
		l.omni_range = 5.5
		l.light_energy = 0.0
		l.visible = false
		add_child(l)
		_flashes.append(l)


func _build_flash_sprites() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = FLASH_TEX
	mat.albedo_color = Color(1, 1, 1, 1)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	for i in 8:
		var spr := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1, 1)
		spr.mesh = q
		spr.material_override = mat.duplicate()
		spr.visible = false
		spr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(spr)
		_flash_sprites.append(spr)


func _make_pool(kind: StringName, count: int, color: Color, amount: int, lifetime: float, size: float,
		speed: float, gravity: Vector3, tex: Texture2D, unshaded: bool = false, smoke: bool = false) -> void:
	var arr: Array[CPUParticles3D] = []
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.albedo_texture = tex
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if unshaded or smoke:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = mat
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0.95), Color(1, 1, 1, 0.65), Color(1, 1, 1, 0.0)])
	var scale_curve := Curve.new()
	if smoke:
		scale_curve.add_point(Vector2(0.0, 0.45))
		scale_curve.add_point(Vector2(0.25, 1.2))
		scale_curve.add_point(Vector2(1.0, 2.4))
	else:
		scale_curve.add_point(Vector2(0.0, 1.0))
		scale_curve.add_point(Vector2(1.0, 0.4))
	for i in count:
		var p := CPUParticles3D.new()
		p.emitting = false
		p.one_shot = true
		p.explosiveness = 0.85 if smoke else 0.92
		p.amount = amount
		p.lifetime = lifetime
		p.mesh = quad
		p.spread = 28.0 if smoke else 35.0
		p.initial_velocity_min = speed * (0.25 if smoke else 0.4)
		p.initial_velocity_max = speed
		p.gravity = gravity
		p.color_ramp = fade
		p.scale_amount_curve = scale_curve
		if smoke:
			p.scale_amount_min = 0.8
			p.scale_amount_max = 1.6
			p.damping_min = 0.8
			p.damping_max = 1.8
			p.angular_velocity_min = -25.0
			p.angular_velocity_max = 25.0
		p.local_coords = false
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)
		arr.append(p)
	_bursts[kind] = arr
