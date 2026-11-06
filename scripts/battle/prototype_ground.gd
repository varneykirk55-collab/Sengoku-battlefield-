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
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
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


## Cinematic late-afternoon / golden-hour look for the conquest battlefield.
static func make_battlefield_environment() -> WorldEnvironment:
	var we := WorldEnvironment.new()
	we.name = "Environment"
	var env := Environment.new()
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	# Deeper zenith, warm amber horizon, soft ground wash.
	mat.sky_top_color = Color(0.18, 0.28, 0.52)
	mat.sky_horizon_color = Color(0.96, 0.68, 0.42)
	mat.sky_curve = 0.08
	mat.ground_horizon_color = Color(0.72, 0.52, 0.34)
	mat.ground_bottom_color = Color(0.22, 0.16, 0.12)
	mat.ground_curve = 0.12
	mat.sun_angle_max = 28.0
	mat.sun_curve = 0.12
	sky.sky_material = mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.72
	env.ambient_light_sky_contribution = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.92, 0.78, 0.58)
	env.fog_density = 0.0028
	env.fog_aerial_perspective = 0.55
	env.fog_sky_affect = 0.55
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_strength = 0.85
	env.glow_bloom = 0.12
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	# SSAO left off by default — readable on low-end / software GL; enable on owner GPU if desired.
	env.ssao_enabled = false
	we.environment = env
	return we


static func make_battlefield_sun() -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	# Lower, warmer late-afternoon angle from the southwest.
	sun.rotation_degrees = Vector3(-28, -55, 0)
	sun.light_color = Color(1.0, 0.78, 0.52)
	sun.light_energy = 1.65
	sun.light_indirect_energy = 1.1
	sun.shadow_enabled = true
	sun.shadow_blur = 1.4
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 160.0
	sun.directional_shadow_split_1 = 0.08
	sun.directional_shadow_split_2 = 0.22
	sun.directional_shadow_split_3 = 0.5
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
