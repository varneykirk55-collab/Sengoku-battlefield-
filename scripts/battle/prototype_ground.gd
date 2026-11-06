class_name PrototypeGround
extends Node3D
## M1 test ground: flat field, a few crates, walls and a ramp to test movement and cameras.
## Replaced by the full battlefield in M3. Also provides the shared sky/light setup.
## Training Range keeps the brighter/simpler look via make_environment/make_sun.
## The conquest battlefield uses make_battlefield_environment/make_battlefield_sun (golden hour).

const SIZE := 160.0


func _ready() -> void:
	add_child(make_environment())
	add_child(make_sun())
	var ground := _box(Vector3(SIZE, 1.0, SIZE), Vector3(0, -0.5, 0), ground_material())
	ground.name = "Ground"
	var crate := _material(Color(0.45, 0.32, 0.2))
	var stone := _material(Color(0.5, 0.5, 0.48))
	for i in 8:
		var a := i * TAU / 8.0
		_box(Vector3(1.4, 1.2, 1.4), Vector3(cos(a) * 14, 0.6, sin(a) * 14), crate)
	_box(Vector3(10, 2.2, 0.8), Vector3(-6, 1.1, -22), stone)
	_box(Vector3(0.8, 2.2, 10), Vector3(20, 1.1, 4), stone)
	var ramp := _box(Vector3(4, 0.4, 10), Vector3(0, 1.5, 26), stone)
	ramp.rotation.x = deg_to_rad(-17)
	_box(Vector3(6, 3.0, 6), Vector3(0, 1.5, 34), stone)
	_spawn_point(0, Vector3(0, 0, -6), 0.0)
	_spawn_point(1, Vector3(0, 0, 45), PI)


## Brighter, cooler look for the Training Range / prototype ground.
static func make_environment() -> WorldEnvironment:
	var we := WorldEnvironment.new()
	we.name = "Environment"
	var env := Environment.new()
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.36, 0.5, 0.68)
	mat.sky_horizon_color = Color(0.78, 0.74, 0.66)
	mat.ground_horizon_color = Color(0.6, 0.56, 0.48)
	mat.ground_bottom_color = Color(0.25, 0.22, 0.18)
	mat.sun_angle_max = 20.0
	sky.sky_material = mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.7, 0.64)
	env.fog_density = 0.004
	env.fog_aerial_perspective = 0.4
	we.environment = env
	return we


static func make_sun() -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_color = Color(1.0, 0.94, 0.84)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	return sun


## Bot3 v5 — neutral bright daytime (late morning, high sun). Natural greens come from
## materials, not grading; lighting supplies contrast/grounding (crisp sun shadows, sky
## ambient, SSAO/SSIL on Forward+). No warm/brown filter, restrained bloom.
static func make_battlefield_environment() -> WorldEnvironment:
	var we := WorldEnvironment.new()
	we.name = "Environment"
	var env := Environment.new()
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.3, 0.5, 0.8)
	mat.sky_horizon_color = Color(0.74, 0.8, 0.88)
	mat.sky_curve = 0.12
	mat.ground_horizon_color = Color(0.5, 0.53, 0.5)
	mat.ground_bottom_color = Color(0.2, 0.21, 0.19)
	mat.ground_curve = 0.1
	mat.sun_angle_max = 18.0
	mat.sun_curve = 0.12
	sky.sky_material = mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# Sky-driven ambient (blue-ish fill in shadow, keeps shadows from going muddy/black).
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.66, 0.74)
	env.ambient_light_sky_contribution = 0.3
	env.ambient_light_energy = 0.45
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 4.5
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.8, 0.9)
	env.fog_density = 0.0011
	env.fog_aerial_perspective = 0.35
	env.fog_sky_affect = 0.2
	env.glow_enabled = true
	env.glow_intensity = 0.06
	env.glow_strength = 0.5
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.4
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 1.6
	env.ssao_power = 1.6
	env.ssao_detail = 0.6
	env.ssao_light_affect = 0.15
	env.ssil_enabled = true
	env.ssil_radius = 4.0
	env.ssil_intensity = 0.6
	# Final grade: tiny contrast lift, saturation held at neutral (no filter tint).
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.07
	env.adjustment_saturation = 0.97
	we.environment = env
	return we


static func make_battlefield_sun() -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	# High late-morning sun, neutral white (bright daytime — not golden hour).
	sun.rotation_degrees = Vector3(-52, -42, 0)
	sun.light_color = Color(1.0, 0.98, 0.95)
	sun.light_energy = 1.4
	sun.light_indirect_energy = 1.0
	sun.light_specular = 0.5
	sun.light_angular_distance = 0.5
	sun.shadow_enabled = true
	sun.shadow_blur = 0.6
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 180.0
	sun.directional_shadow_split_1 = 0.06
	sun.directional_shadow_split_2 = 0.18
	sun.directional_shadow_split_3 = 0.45
	sun.directional_shadow_blend_splits = true
	return sun


static func ground_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var noise := FastNoiseLite.new()
	noise.frequency = 0.02
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.seamless = true
	tex.width = 256
	tex.height = 256
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.27, 0.32, 0.16))
	ramp.set_color(1, Color(0.42, 0.42, 0.24))
	tex.color_ramp = ramp
	m.albedo_texture = tex
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.08, 0.08, 0.08)
	m.roughness = 0.95
	return m


func _material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


func _box(size: Vector3, pos: Vector3, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Soldier.LAYER_WORLD
	body.collision_mask = 0
	add_child(body)
	body.position = pos
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	return body


func _spawn_point(faction: int, pos: Vector3, yaw: float) -> void:
	var m := Marker3D.new()
	m.name = "Spawn_%d" % faction
	m.add_to_group("spawn_%d" % faction)
	add_child(m)
	m.position = pos
	m.rotation.y = yaw
