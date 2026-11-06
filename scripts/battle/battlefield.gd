class_name Battlefield
extends Node3D
## The prototype battlefield, generated deterministically from code (primitives only):
## rolling terrain with a central hill and a stream valley, three capture points (A, B, C),
## two faction camps, and cover (rocks, palisades, stone walls, huts, a torii, pines,
## bamboo, grass, dirt roads). Bot 3 v3 — cinematic: terrain shader, Blender pine/hut/torii GLBs.
##
## Layout (top view, -Z is north):
##                 north camp (faction 1, blue)        z = -128
##                                   C  (55, -45)
##                        B (0, 0) on the hill
##            A (-55, 45)
##                 south camp (faction 0, red)          z = +128
##
## The navigation mesh is baked offline (tools/bake_navmesh.sh) into NAV_PATH and loaded here.

const HALF_X := 145.0  # was 120; ~21% wider
const HALF_Z := 180.0  # was 150; ~20% deeper
const SEED := 1575  # year of Nagashino
const NAV_PATH := "res://data/maps/battlefield_nav.res"
const OBJECTIVES := [
	{"id": &"A", "pos": Vector2(-55, 45)},
	{"id": &"B", "pos": Vector2(0, 0)},
	{"id": &"C", "pos": Vector2(55, -45)},
]
const CAMPS := [Vector2(0, 128), Vector2(0, -128)]  # faction 0, faction 1

## Road segments linking camps ↔ A/B/C (dirt vertex-color paths).
const ROADS := [
	[Vector2(0, 128), Vector2(-55, 45)],
	[Vector2(0, 128), Vector2(0, 0)],
	[Vector2(-55, 45), Vector2(0, 0)],
	[Vector2(0, 0), Vector2(55, -45)],
	[Vector2(0, -128), Vector2(55, -45)],
	[Vector2(0, -128), Vector2(0, 0)],
	[Vector2(0, 128), Vector2(55, -45)],
	[Vector2(0, -128), Vector2(-55, 45)],
]

## Set false by the navmesh baker (it builds the source geometry only).
var load_navigation := true
var objectives: Array[CapturePoint] = []
var nav_region: NavigationRegion3D

var _noise := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var _wood: StandardMaterial3D
var _stone: StandardMaterial3D
var _dark_wood: StandardMaterial3D
var _thatch: StandardMaterial3D
var _bamboo: StandardMaterial3D
var _foliage_dark: StandardMaterial3D
var _foliage_mid: StandardMaterial3D
var _foliage_lit: StandardMaterial3D
var _grass_mat: StandardMaterial3D
var _pine_mesh: Mesh
var _pine_lod_mesh: Mesh
var _shrub_mesh: Mesh
var _rock_mesh: Mesh
var _hut_scene: PackedScene
var _torii_scene: PackedScene


func _ready() -> void:
	_noise.seed = SEED
	_noise.frequency = 0.012
	_noise.fractal_octaves = 3
	_rng.seed = SEED
	# Distinct per-material palette — saturated greens, oak wood, cool stone (no olive-brown wash).
	_wood = _wood_mat(Color(0.58, 0.4, 0.22))
	_dark_wood = _wood_mat(Color(0.22, 0.14, 0.08))
	_stone = _stone_mat(Color(0.52, 0.54, 0.56))
	_thatch = _mat(Color(0.74, 0.6, 0.34), 0.9)
	_bamboo = _foliage_mat(Color(0.4, 0.7, 0.28), 0.55, 0.08)
	_foliage_dark = _foliage_mat(Color(0.04, 0.28, 0.08), 0.8, 0.0)
	_foliage_mid = _foliage_mat(Color(0.1, 0.52, 0.14), 0.68, 0.06)
	_foliage_lit = _foliage_mat(Color(0.3, 0.72, 0.18), 0.52, 0.18)
	_grass_mat = _foliage_mat(Color(0.28, 0.68, 0.16), 0.72, 0.08)
	_load_env_assets()
	add_child(PrototypeGround.make_battlefield_environment())
	var sun := PrototypeGround.make_battlefield_sun()
	add_child(sun)
	_build_terrain()
	_build_bounds()
	_build_stream_water()
	for i in OBJECTIVES.size():
		_build_objective(OBJECTIVES[i].id, OBJECTIVES[i].pos)
	for f in CAMPS.size():
		_build_camp(f, CAMPS[f])
	_scatter_cover()
	_build_trees()
	_build_shrubs()
	_build_bamboo()
	_build_grass()
	_build_distant_scenery()
	if load_navigation:
		_load_navigation()


## Ground height at a point (metres). Used for building, spawning and tests.
func height_at(x: float, z: float) -> float:
	var h := _noise.get_noise_2d(x, z) * 2.8
	# Central hill under objective B.
	h += 7.5 * exp(-(x * x + z * z) / (2.0 * 26.0 * 26.0))
	# Secondary rolling hills (flanks) — keep combat lanes open.
	h += 4.2 * exp(-((x - 70.0) * (x - 70.0) + (z - 35.0) * (z - 35.0)) / (2.0 * 22.0 * 22.0))
	h += 3.6 * exp(-((x + 75.0) * (x + 75.0) + (z + 40.0) * (z + 40.0)) / (2.0 * 20.0 * 20.0))
	h += 3.0 * exp(-((x - 55.0) * (x - 55.0) + (z + 90.0) * (z + 90.0)) / (2.0 * 18.0 * 18.0))
	h += 2.8 * exp(-((x + 60.0) * (x + 60.0) + (z - 95.0) * (z - 95.0)) / (2.0 * 18.0 * 18.0))
	# Low undulation for variety.
	h += _noise.get_noise_2d(x * 0.45 + 200.0, z * 0.45) * 1.4
	# A low ridge east of A gives cover between A and B.
	var rd := _dist_to_segment(Vector2(x, z), Vector2(-40, 15), Vector2(-15, 55))
	h += 2.4 * exp(-rd * rd / (2.0 * 5.0 * 5.0))
	# Stream valley winding west to east between B and C.
	var stream_z := -70.0 + 14.0 * sin(x / 32.0)
	var sd := absf(z - stream_z)
	h -= 2.2 * exp(-sd * sd / (2.0 * 6.0 * 6.0))
	# Flatten camps and objective centres so fights there are readable.
	for c: Vector2 in CAMPS:
		h = lerpf(h, 0.5, _flat_weight(x, z, c, 22.0))
	for o in OBJECTIVES:
		var p: Vector2 = o.pos
		var center_h := _raw_center_height(p)
		h = lerpf(h, center_h, _flat_weight(x, z, p, 9.0))
	# Slightly flatten dirt roads so they read as paths.
	for road in ROADS:
		var rdist := _dist_to_segment(Vector2(x, z), road[0], road[1])
		if rdist < 3.5:
			var wh := clampf(1.0 - rdist / 3.5, 0.0, 1.0)
			h = lerpf(h, h * 0.92 + 0.15, wh * 0.55)
	# Berms rise toward the map edges (natural boundary), applied last so nothing cuts through them.
	var ex := maxf(0.0, absf(x) - (HALF_X - 22.0)) / 22.0
	var ez := maxf(0.0, absf(z) - (HALF_Z - 14.0)) / 14.0
	h += 14.0 * (ex * ex + ez * ez)
	return h


func ground_point(x: float, z: float) -> Vector3:
	return Vector3(x, height_at(x, z), z)


func spawn_points(faction: int) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for n in get_tree().get_nodes_in_group("spawn_%d" % faction):
		if is_ancestor_of(n):
			out.append(n)
	return out


# ----------------------------------------------------------------------------- terrain
func _raw_center_height(p: Vector2) -> float:
	return _noise.get_noise_2d(p.x, p.y) * 2.8 + 7.5 * exp(-(p.x * p.x + p.y * p.y) / (2.0 * 26.0 * 26.0))


func _flat_weight(x: float, z: float, c: Vector2, radius: float) -> float:
	var d := Vector2(x, z).distance_to(c)
	return clampf(1.0 - (d - radius) / 10.0, 0.0, 1.0)


func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _road_weight(x: float, z: float) -> float:
	var best := 999.0
	for road in ROADS:
		best = minf(best, _dist_to_segment(Vector2(x, z), road[0], road[1]))
	return clampf(1.0 - best / 2.8, 0.0, 1.0)


func _build_terrain() -> void:
	var w := int(HALF_X * 2.0) + 1
	var d := int(HALF_Z * 2.0) + 1
	var heights := PackedFloat32Array()
	heights.resize(w * d)
	for zi in d:
		for xi in w:
			heights[zi * w + xi] = height_at(xi - HALF_X, zi - HALF_Z)
	# Collision: one heightmap, 1 m spacing.
	var body := StaticBody3D.new()
	body.name = "Terrain"
	body.collision_layer = Soldier.LAYER_WORLD
	body.collision_mask = 0
	add_child(body)
	var shape := HeightMapShape3D.new()
	shape.map_width = w
	shape.map_depth = d
	shape.map_data = heights
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	# Render mesh: same grid, coloured by slope, height, roads.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for zi in d:
		for xi in w:
			var x := xi - HALF_X
			var z := zi - HALF_Z
			var h := heights[zi * w + xi]
			var hx := heights[zi * w + mini(xi + 1, w - 1)] - heights[zi * w + maxi(xi - 1, 0)]
			var hz := heights[mini(zi + 1, d - 1) * w + xi] - heights[maxi(zi - 1, 0) * w + xi]
			var n := Vector3(-hx, 2.0, -hz).normalized()
			st.set_normal(n)
			st.set_color(_ground_color(x, z, h, n))
			st.set_uv(Vector2(x, z) * 0.08)
			st.add_vertex(Vector3(x, h, z))
	for zi in d - 1:
		for xi in w - 1:
			var i := zi * w + xi
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + w)
			st.add_index(i + 1)
			st.add_index(i + w + 1)
			st.add_index(i + w)
	var mi := MeshInstance3D.new()
	mi.name = "TerrainMesh"
	mi.mesh = st.commit()
	mi.material_override = _terrain_material()
	body.add_child(mi)


func _ground_color(x: float, z: float, h: float, n: Vector3) -> Color:
	## Vertex COLOR as blend weights for terrain shader: R=dirt, G=grass, B=rock.
	var n1 := clampf(_noise.get_noise_2d(x * 3.0, z * 3.0) + 0.5, 0.0, 1.0)
	var slope := 1.0 - n.y
	var grass_w := 1.0
	var dirt_w := 0.0
	var rock_w := 0.0
	# Steep slopes → rock / exposed soil
	dirt_w += clampf(slope * 6.5 - 0.7, 0.0, 0.9)
	rock_w += clampf(slope * 5.0 - 1.3, 0.0, 1.0)
	# Macro meadow variation
	grass_w += n1 * 0.25
	# Roads
	var rw := _road_weight(x, z)
	if rw > 0.0:
		dirt_w += rw * 1.4
		grass_w -= rw * 0.9
	# Trampled camps / objectives
	for o in OBJECTIVES:
		var p: Vector2 = o.pos
		var tw := clampf(1.0 - Vector2(x, z).distance_to(p) / 11.0, 0.0, 0.7)
		dirt_w += tw
		grass_w -= tw * 0.6
	for cp: Vector2 in CAMPS:
		var tw2 := clampf(1.0 - Vector2(x, z).distance_to(cp) / 16.0, 0.0, 0.5)
		dirt_w += tw2
		grass_w -= tw2 * 0.5
	# Stream bed → wet rock/dirt
	var stream_z := -70.0 + 14.0 * sin(x / 32.0)
	if absf(z - stream_z) < 2.8 and h < 0.5:
		rock_w += 0.7
		dirt_w += 0.5
		grass_w -= 0.8
	grass_w = maxf(grass_w, 0.05)
	dirt_w = maxf(dirt_w, 0.0)
	rock_w = maxf(rock_w, 0.0)
	var s := grass_w + dirt_w + rock_w
	return Color(dirt_w / s, grass_w / s, rock_w / s)


func _terrain_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/env/terrain_blend.gdshader")
	m.set_shader_parameter("grass_albedo", load("res://assets/env/textures/grass_albedo.png"))
	m.set_shader_parameter("dirt_albedo", load("res://assets/env/textures/dirt_albedo.png"))
	m.set_shader_parameter("rock_albedo", load("res://assets/env/textures/rock_albedo.png"))
	m.set_shader_parameter("grass_normal", load("res://assets/env/textures/grass_normal.png"))
	m.set_shader_parameter("dirt_normal", load("res://assets/env/textures/dirt_normal.png"))
	m.set_shader_parameter("rock_normal", load("res://assets/env/textures/rock_normal.png"))
	m.set_shader_parameter("grass_rough", load("res://assets/env/textures/grass_rough.png"))
	m.set_shader_parameter("grass_scale", 0.12)
	m.set_shader_parameter("dirt_scale", 0.15)
	m.set_shader_parameter("rock_scale", 0.1)
	m.set_shader_parameter("normal_strength", 0.9)
	return m


func _build_bounds() -> void:
	# Invisible walls just inside the edges; the berms already make them hard to reach.
	for spec in [[Vector3(HALF_X - 3, 20, 0), Vector3(1, 60, HALF_Z * 2)], [Vector3(-HALF_X + 3, 20, 0), Vector3(1, 60, HALF_Z * 2)],
			[Vector3(0, 20, HALF_Z - 3), Vector3(HALF_X * 2, 60, 1)], [Vector3(0, 20, -HALF_Z + 3), Vector3(HALF_X * 2, 60, 1)]]:
		var body := StaticBody3D.new()
		body.name = "Bound"
		body.collision_layer = Soldier.LAYER_WORLD
		add_child(body)
		body.position = spec[0]
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = spec[1]
		cs.shape = shape
		body.add_child(cs)


func _build_stream_water() -> void:
	# Thin translucent ribbon following the stream valley — visual only, no collision.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.5, 0.55, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.15
	mat.metallic = 0.15
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in 49:
		var x := -HALF_X + 8.0 + i * ((HALF_X * 2.0 - 16.0) / 48.0)
		var stream_z := -70.0 + 14.0 * sin(x / 32.0)
		var y := height_at(x, stream_z) + 0.15
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(i / 48.0, 0.0))
		st.add_vertex(Vector3(x, y, stream_z - 1.6))
		st.set_uv(Vector2(i / 48.0, 1.0))
		st.add_vertex(Vector3(x, y, stream_z + 1.6))
	var mi := MeshInstance3D.new()
	mi.name = "StreamWater"
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# ----------------------------------------------------------------------------- objectives & camps
func _build_objective(id: StringName, p: Vector2) -> void:
	var cp := CapturePoint.new()
	cp.name = "Objective_" + String(id)
	cp.objective_id = id
	add_child(cp)
	cp.position = ground_point(p.x, p.y)
	objectives.append(cp)
	match id:
		&"A":  # farmstead: two huts and a fence
			_hut(Vector3(p.x - 9, 0, p.y - 6), 0.2)
			_hut(Vector3(p.x + 8, 0, p.y + 7), -0.4)
			_palisade(Vector2(p.x - 14, p.y + 8), Vector2(p.x - 4, p.y + 15))
			_stone_wall(Vector2(p.x + 6, p.y - 12), Vector2(p.x + 15, p.y - 4))
			_rock(Vector3(p.x - 5, 0, p.y + 12), 1.0)
		&"B":  # hilltop shrine: a torii and low stone walls
			_torii(Vector3(p.x, 0, p.y - 7))
			_stone_wall(Vector2(p.x - 10, p.y + 6), Vector2(p.x - 3, p.y + 10))
			_stone_wall(Vector2(p.x + 4, p.y + 10), Vector2(p.x + 11, p.y + 5))
			_rock(Vector3(p.x + 9, 0, p.y - 4), 1.4)
			_rock(Vector3(p.x - 8, 0, p.y - 2), 0.9)
		&"C":  # river crossing outpost: hut, palisade, rocks
			_hut(Vector3(p.x + 9, 0, p.y + 5), 1.3)
			_palisade(Vector2(p.x - 13, p.y - 10), Vector2(p.x - 3, p.y - 15))
			_palisade(Vector2(p.x - 14, p.y + 4), Vector2(p.x - 9, p.y + 13))
			_rock(Vector3(p.x - 4, 0, p.y + 9), 1.2)
			_rock(Vector3(p.x + 6, 0, p.y - 8), 1.1)


func _build_camp(faction: int, c: Vector2) -> void:
	var facing := 0.0 if faction == 0 else PI  # camps face the battle
	var color: Color = UIStyle.FACTION_COLORS[faction]
	# Richer banner / curtain colors (more saturated, still readable).
	var curtain := _mat(Color(0.95, 0.95, 0.92), 0.88)
	var band := _mat(color.lightened(0.05).lerp(color, 0.7), 0.7)
	band.albedo_color = Color(clampf(color.r * 1.15, 0.0, 1.0), clampf(color.g * 1.05, 0.0, 1.0), clampf(color.b * 1.05, 0.0, 1.0))
	var away := 1.0 if faction == 0 else -1.0
	# Maku: cloth curtains on poles around the back of the camp.
	for i in 7:
		var x := -21.0 + i * 7.0
		var z := c.y + away * 12.0
		var pos := ground_point(c.x + x, z)
		_panel(pos + Vector3(0, 1.1, 0), Vector3(6.6, 2.2, 0.08), curtain, false)
		_panel(pos + Vector3(0, 1.1, 0), Vector3(6.62, 0.5, 0.1), band, false)
	# Tall nobori banners and spawn markers.
	for i in 5:
		var x := -16.0 + i * 8.0
		_nobori(ground_point(c.x + x, c.y + away * 10.0), color)
		var m := Marker3D.new()
		m.name = "Spawn_%d_%d" % [faction, i]
		m.add_to_group("spawn_%d" % faction)
		add_child(m)
		m.position = ground_point(c.x + x, c.y + away * 4.0) + Vector3(0, 0.2, 0)
		m.rotation.y = facing
	# Command tent-ish box and supply crates for cover (keep clear of spawn ring).
	_box(ground_point(c.x - 12, c.y + away * 6.0) + Vector3(0, 0.6, 0), Vector3(1.4, 1.2, 1.4), _wood, true)
	_box(ground_point(c.x + 13, c.y + away * 5.0) + Vector3(0, 0.6, 0), Vector3(1.4, 1.2, 2.6), _wood, true)
	# Extra camp detail: side palisade wings + a small hut (behind spawns, not blocking).
	_palisade(Vector2(c.x - 24, c.y + away * 2.0), Vector2(c.x - 18, c.y + away * 14.0))
	_palisade(Vector2(c.x + 24, c.y + away * 2.0), Vector2(c.x + 18, c.y + away * 14.0))
	_hut(Vector3(c.x - 18, 0, c.y + away * 8.0), facing + 0.3)
	_box(ground_point(c.x + 10, c.y + away * 9.0) + Vector3(0, 0.45, 0), Vector3(1.0, 0.9, 1.0), _wood, true)
	# Extra flanking nobori for stronger faction color presence.
	_nobori(ground_point(c.x - 22, c.y + away * 6.0), color)
	_nobori(ground_point(c.x + 22, c.y + away * 6.0), color)


# ----------------------------------------------------------------------------- cover
func _scatter_cover() -> void:
	# Rock clusters and palisade lines along the routes between camps and objectives.
	var routes := [
		[CAMPS[0], OBJECTIVES[0].pos], [CAMPS[0], OBJECTIVES[1].pos], [OBJECTIVES[0].pos, OBJECTIVES[1].pos],
		[OBJECTIVES[1].pos, OBJECTIVES[2].pos], [CAMPS[1], OBJECTIVES[2].pos], [CAMPS[1], OBJECTIVES[1].pos],
		[CAMPS[0], OBJECTIVES[2].pos], [CAMPS[1], OBJECTIVES[0].pos],
	]
	for r in routes:
		var a: Vector2 = r[0]
		var b: Vector2 = r[1]
		for k in 4:
			var t := 0.25 + 0.17 * k + _rng.randf_range(-0.05, 0.05)
			var side := Vector2(-(b - a).y, (b - a).x).normalized() * _rng.randf_range(5.0, 12.0) * (1.0 if k % 2 == 0 else -1.0)
			var p := a.lerp(b, t) + side
			if _too_close_to_points(p, 14.0) or _road_weight(p.x, p.y) > 0.4:
				continue
			match k % 3:
				0:
					_rock(Vector3(p.x, 0, p.y), _rng.randf_range(0.9, 1.7))
					_rock(Vector3(p.x + 1.8, 0, p.y + 0.8), _rng.randf_range(0.6, 1.0))
				1:
					var dir := (b - a).normalized().rotated(_rng.randf_range(1.2, 1.9))
					_palisade(p - dir * 4.0, p + dir * 4.0)
				2:
					var dir2 := (b - a).normalized().rotated(PI / 2)
					_stone_wall(p - dir2 * 3.5, p + dir2 * 3.5)
	# Open-field boulders (more on the expanded flanks).
	for i in 38:
		var p := Vector2(_rng.randf_range(-HALF_X + 25, HALF_X - 25), _rng.randf_range(-HALF_Z + 30, HALF_Z - 30))
		if not _too_close_to_points(p, 16.0) and _road_weight(p.x, p.y) < 0.35:
			_rock(Vector3(p.x, 0, p.y), _rng.randf_range(0.7, 2.2))
	# Rocky formations as cover near secondary hills.
	var rock_clusters: Array[Vector2] = [Vector2(68, 32), Vector2(-72, -38), Vector2(52, -88), Vector2(-58, 90)]
	for cluster in rock_clusters:
		for j in 5:
			var offset := Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-6, 6))
			var p: Vector2 = cluster + offset
			if not _too_close_to_points(p, 14.0):
				_rock(Vector3(p.x, 0, p.y), _rng.randf_range(1.0, 2.4))


func _too_close_to_points(p: Vector2, r: float) -> bool:
	for o in OBJECTIVES:
		if p.distance_to(o.pos) < r:
			return true
	for c: Vector2 in CAMPS:
		if p.distance_to(c) < r + 6.0:
			return true
	return false


func _build_trees() -> void:
	# Stylized Japanese pine GLBs (MultiMesh) — replaces primitive cones.
	var mesh := _pine_mesh if _pine_mesh else EnvMeshes.japanese_pine()
	var lod := _pine_lod_mesh if _pine_lod_mesh else EnvMeshes.japanese_pine_lod()
	var near_spots: Array[Vector3] = []
	var far_spots: Array[Vector3] = []
	for i in 200:
		var side := _rng.randi() % 4
		var x := _rng.randf_range(-HALF_X + 6, HALF_X - 6)
		var z := _rng.randf_range(-HALF_Z + 6, HALF_Z - 6)
		match side:
			0: x = _rng.randf_range(-HALF_X + 6, -HALF_X + 52)
			1: x = _rng.randf_range(HALF_X - 52, HALF_X - 6)
			2: z = _rng.randf_range(-HALF_Z + 6, -HALF_Z + 30)
			3: z = _rng.randf_range(HALF_Z - 30, HALF_Z - 6)
		var p := Vector2(x, z)
		if _too_close_to_points(p, 18.0) or _road_weight(x, z) > 0.45:
			continue
		var gp := ground_point(x, z)
		# Near midfield groves use high detail; berms use LOD.
		if absf(x) < HALF_X - 55.0 and absf(z) < HALF_Z - 40.0:
			near_spots.append(gp)
		else:
			far_spots.append(gp)
	for i in 22:
		var p := Vector2(_rng.randf_range(22, 44), _rng.randf_range(-18, 18))
		if _road_weight(p.x, p.y) < 0.4:
			near_spots.append(ground_point(p.x, p.y))
	for i in 14:
		var p := Vector2(_rng.randf_range(-98, -72), _rng.randf_range(18, 58))
		if not _too_close_to_points(p, 16.0):
			near_spots.append(ground_point(p.x, p.y))
	var pines := _multimesh(mesh, null, near_spots, Vector3.ZERO, 1.0)
	pines.name = "Pines"
	var pines_lod := _multimesh(lod, null, far_spots, Vector3.ZERO, 1.05)
	pines_lod.name = "PinesLOD"
	# Trunk colliders (near + far)
	var body := StaticBody3D.new()
	body.name = "TreeTrunks"
	body.collision_layer = Soldier.LAYER_WORLD
	body.add_to_group("wood")
	add_child(body)
	for s in near_spots + far_spots:
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.35
		cyl.height = 6.5
		cs.shape = cyl
		cs.position = s + Vector3(0, 3.2, 0)
		body.add_child(cs)



func _build_shrubs() -> void:
	var mesh := _shrub_mesh if _shrub_mesh else EnvMeshes.shrub()
	var spots: Array[Vector3] = []
	for i in 160:
		var x := _rng.randf_range(-HALF_X + 18, HALF_X - 18)
		var z := _rng.randf_range(-HALF_Z + 22, HALF_Z - 22)
		var p := Vector2(x, z)
		if _too_close_to_points(p, 14.0) or _road_weight(x, z) > 0.4:
			continue
		if _rng.randf() > 0.55:
			continue
		spots.append(ground_point(x, z))
	# Clusters near stream banks and grove edges
	for i in 40:
		var x := _rng.randf_range(-100, 40)
		var stream_z := -70.0 + 14.0 * sin(x / 32.0)
		var z := stream_z + _rng.randf_range(4.0, 10.0) * (1.0 if i % 2 == 0 else -1.0)
		var p := Vector2(x, z)
		if not _too_close_to_points(p, 14.0):
			spots.append(ground_point(x, z))
	if spots.is_empty():
		return
	var shrubs := _multimesh(mesh, null, spots, Vector3.ZERO, 1.0)
	shrubs.name = "Shrubs"
	shrubs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _build_bamboo() -> void:
	# Bamboo grove west of the stream / south-west of C — dense vertical MultiMesh, sparse colliders.
	var stalk := CylinderMesh.new()
	stalk.top_radius = 0.06
	stalk.bottom_radius = 0.08
	stalk.height = 7.0
	stalk.radial_segments = 5
	var leaf := PrismMesh.new()
	leaf.size = Vector3(0.9, 0.15, 1.8)
	var spots: Array[Vector3] = []
	for i in 70:
		var p := Vector2(_rng.randf_range(-110, -55), _rng.randf_range(-95, -55))
		if _too_close_to_points(p, 16.0) or _road_weight(p.x, p.y) > 0.4:
			continue
		spots.append(ground_point(p.x, p.y))
	# Second smaller patch near A west.
	for i in 28:
		var p := Vector2(_rng.randf_range(-100, -78), _rng.randf_range(55, 85))
		if not _too_close_to_points(p, 16.0):
			spots.append(ground_point(p.x, p.y))
	if spots.is_empty():
		return
	var stalks := _multimesh(stalk, _bamboo, spots, Vector3(0, 3.5, 0))
	stalks.name = "BambooStalks"
	var leaves := _multimesh(leaf, _foliage_lit, spots, Vector3(0, 6.2, 0), 0.9)
	leaves.name = "BambooLeaves"
	# Colliders every 3rd stalk so AI can path around without exploding cost.
	var body := StaticBody3D.new()
	body.name = "BambooColliders"
	body.collision_layer = Soldier.LAYER_WORLD
	body.add_to_group("wood")
	add_child(body)
	for i in spots.size():
		if i % 3 != 0:
			continue
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.35
		cyl.height = 5.0
		cs.shape = cyl
		cs.position = spots[i] + Vector3(0, 2.5, 0)
		body.add_child(cs)


func _build_grass() -> void:
	var mesh := EnvMeshes.grass_tuft()
	var mat := _grass_mat.duplicate()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	var spots: Array[Vector3] = []
	for i in 900:
		var x := _rng.randf_range(-HALF_X + 18, HALF_X - 18)
		var z := _rng.randf_range(-HALF_Z + 22, HALF_Z - 22)
		var p := Vector2(x, z)
		if _too_close_to_points(p, 11.0) or _road_weight(x, z) > 0.32:
			continue
		var stream_z := -70.0 + 14.0 * sin(x / 32.0)
		if absf(z - stream_z) < 3.5:
			continue
		# Density variation — denser in meadows, thinner on slopes
		var dens := clampf(_noise.get_noise_2d(x * 0.08, z * 0.08) + 0.55, 0.0, 1.0)
		if dens < 0.35:
			continue
		spots.append(ground_point(x, z) + Vector3(0, 0.05, 0))
	if spots.is_empty():
		return
	var grass := _multimesh(mesh, mat, spots, Vector3.ZERO, 1.0)
	grass.name = "GrassTufts"
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_distant_scenery() -> void:
	# Extra berm silhouettes / distant pine hints outside the playable berm (visual only).
	var mesh := _pine_lod_mesh if _pine_lod_mesh else EnvMeshes.japanese_pine_lod()
	var spots: Array[Vector3] = []
	for i in 48:
		var ang := _rng.randf() * TAU
		var radius := maxf(HALF_X, HALF_Z) + _rng.randf_range(8.0, 28.0)
		var x := cos(ang) * radius * (HALF_X / maxf(HALF_X, HALF_Z))
		var z := sin(ang) * radius * (HALF_Z / maxf(HALF_X, HALF_Z))
		# Clamp just outside berms.
		x = clampf(x, -HALF_X - 30.0, HALF_X + 30.0)
		z = clampf(z, -HALF_Z - 30.0, HALF_Z + 30.0)
		if absf(x) < HALF_X - 5.0 and absf(z) < HALF_Z - 5.0:
			continue
		spots.append(Vector3(x, height_at(clampf(x, -HALF_X + 1, HALF_X - 1), clampf(z, -HALF_Z + 1, HALF_Z - 1)) + 2.0, z))
	if spots.is_empty():
		return
	var distant := _multimesh(mesh, null, spots, Vector3.ZERO, 1.35)
	distant.name = "DistantPines"
	distant.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _multimesh(mesh: Mesh, mat: Material, spots: Array[Vector3], offset: Vector3, scale: float = 1.0) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = spots.size()
	for i in spots.size():
		var s := scale * (0.8 + 0.4 * fposmod(spots[i].x * 0.37 + spots[i].z * 0.11, 1.0))
		var yaw := fposmod(spots[i].x * 1.7 + spots[i].z * 0.9, TAU)
		var basis := Basis(Vector3.UP, yaw).scaled(Vector3(s, s * (0.92 + 0.16 * fposmod(spots[i].z * 0.23, 1.0)), s))
		mm.set_instance_transform(i, Transform3D(basis, spots[i] + offset * s))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	if mat != null:
		mmi.material_override = mat
	add_child(mmi)
	return mmi


# ----------------------------------------------------------------------------- prop builders
func _rock(p: Vector3, size: float) -> void:
	var base := ground_point(p.x, p.z)
	if _rock_mesh:
		var body := StaticBody3D.new()
		body.collision_layer = Soldier.LAYER_WORLD
		add_child(body)
		body.position = base
		body.rotation = Vector3(_rng.randf_range(-0.15, 0.15), _rng.randf_range(0, TAU), _rng.randf_range(-0.15, 0.15))
		body.scale = Vector3.ONE * size * _rng.randf_range(0.9, 1.4)
		var mi := MeshInstance3D.new()
		mi.mesh = _rock_mesh
		body.add_child(mi)
		var cs := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 0.85
		cs.shape = shape
		cs.position.y = 0.35
		body.add_child(cs)
		return
	var dims := Vector3(size * _rng.randf_range(1.2, 2.0), size * _rng.randf_range(0.8, 1.4), size * _rng.randf_range(1.0, 1.8))
	var b := _box(base + Vector3(0, dims.y * 0.4, 0), dims, _stone, false)
	b.rotation = Vector3(_rng.randf_range(-0.2, 0.2), _rng.randf_range(0, TAU), _rng.randf_range(-0.2, 0.2))


func _palisade(a: Vector2, b: Vector2) -> void:
	# A row of sharpened stakes (one box per 1.2 m so it follows the ground).
	var n := maxi(2, ceili(a.distance_to(b) / 1.2))
	for i in n:
		var p := a.lerp(b, (i + 0.5) / n)
		var base := ground_point(p.x, p.y)
		var stake := _box(base + Vector3(0, 1.0, 0), Vector3(1.25, 2.0, 0.28), _wood, true)
		stake.rotation.y = -atan2(b.y - a.y, b.x - a.x)


func _stone_wall(a: Vector2, b: Vector2) -> void:
	var n := maxi(2, ceili(a.distance_to(b) / 2.0))
	for i in n:
		var p := a.lerp(b, (i + 0.5) / n)
		var base := ground_point(p.x, p.y)
		var block := _box(base + Vector3(0, 0.55, 0), Vector3(2.1, 1.1, 0.9), _stone, false)
		block.rotation.y = -atan2(b.y - a.y, b.x - a.x)


func _hut(p: Vector3, yaw: float) -> void:
	var base := ground_point(p.x, p.z)
	if _hut_scene:
		var inst: Node3D = _hut_scene.instantiate()
		add_child(inst)
		inst.position = base
		inst.rotation.y = yaw
		# Approximate collision box for the hut footprint
		var body := StaticBody3D.new()
		body.collision_layer = Soldier.LAYER_WORLD
		body.add_to_group("wood")
		inst.add_child(body)
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(6.2, 3.2, 5.0)
		cs.shape = shape
		cs.position.y = 1.6
		body.add_child(cs)
		return
	var root := Node3D.new()
	add_child(root)
	root.position = base
	root.rotation.y = yaw
	var walls := _box(Vector3.ZERO, Vector3(6.0, 2.6, 4.5), _wood, true)
	walls.reparent(root, false)
	walls.position = Vector3(0, 1.3, 0)
	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(5.6, 2.0, 6.8)
	roof.mesh = prism
	roof.material_override = _thatch
	root.add_child(roof)
	roof.position = Vector3(0, 3.6, 0)
	roof.rotation.y = PI / 2


func _torii(p: Vector3) -> void:
	var base := ground_point(p.x, p.z)
	if _torii_scene:
		var inst: Node3D = _torii_scene.instantiate()
		add_child(inst)
		inst.position = base
		var body := StaticBody3D.new()
		body.collision_layer = Soldier.LAYER_WORLD
		body.add_to_group("wood")
		inst.add_child(body)
		for x in [-1.9, 1.9]:
			var cs := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = 0.25
			cyl.height = 4.6
			cs.shape = cyl
			cs.position = Vector3(x, 2.3, 0)
			body.add_child(cs)
		return
	var red := _mat(Color(0.88, 0.1, 0.06), 0.55)
	for x in [-1.9, 1.9]:
		_box(base + Vector3(x, 2.2, 0), Vector3(0.38, 4.4, 0.38), red, true)
	_box(base + Vector3(0, 4.6, 0), Vector3(5.6, 0.4, 0.5), _dark_wood, false)
	_box(base + Vector3(0, 3.8, 0), Vector3(4.6, 0.28, 0.32), red, false)


func _nobori(p: Vector3, color: Color) -> void:
	_box(p + Vector3(0, 2.4, 0), Vector3(0.1, 4.8, 0.1), _dark_wood, false)
	var vibrant := Color(clampf(color.r * 1.35, 0, 1), clampf(color.g * 1.15, 0, 1), clampf(color.b * 1.3, 0, 1))
	var flag := _panel(p + Vector3(0.4, 3.3, 0), Vector3(0.7, 2.6, 0.03), _mat(vibrant, 0.7), false)
	flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _panel(p: Vector3, size: Vector3, mat: Material, collide: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	add_child(mi)
	mi.position = p
	if collide:
		var body := StaticBody3D.new()
		body.collision_layer = Soldier.LAYER_WORLD
		mi.add_child(body)
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		body.add_child(cs)
	return mi


func _box(pos: Vector3, size: Vector3, mat: Material, wood: bool) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Soldier.LAYER_WORLD
	body.collision_mask = 0
	if wood:
		body.add_to_group("wood")
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



func _load_env_assets() -> void:
	_pine_mesh = _mesh_from_glb("res://assets/env/meshes/pine.glb")
	_pine_lod_mesh = _mesh_from_glb("res://assets/env/meshes/pine_lod.glb")
	_shrub_mesh = _mesh_from_glb("res://assets/env/meshes/shrub.glb")
	_rock_mesh = _mesh_from_glb("res://assets/env/meshes/rock.glb")
	if ResourceLoader.exists("res://assets/env/meshes/hut.glb"):
		_hut_scene = load("res://assets/env/meshes/hut.glb")
	if ResourceLoader.exists("res://assets/env/meshes/torii.glb"):
		_torii_scene = load("res://assets/env/meshes/torii.glb")


func _mesh_from_glb(path: String) -> Mesh:
	if not ResourceLoader.exists(path):
		return null
	var ps: PackedScene = load(path)
	if ps == null:
		return null
	var root := ps.instantiate()
	var found: Mesh = null
	for c in root.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.mesh:
			found = mi.mesh
			break
	root.queue_free()
	return found


func _mat(c: Color, roughness: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = roughness
	return m


func _foliage_mat(c: Color, roughness: float, emit: float = 0.0) -> StandardMaterial3D:
	var m := _mat(c, roughness)
	m.rim_enabled = true
	m.rim = 0.4
	m.rim_tint = 0.35
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c.lightened(0.15)
		m.emission_energy_multiplier = emit
	return m


func _wood_mat(c: Color) -> StandardMaterial3D:
	var m := _mat(c, 0.78)
	if ResourceLoader.exists("res://assets/env/textures/bark_albedo.png"):
		m.albedo_texture = load("res://assets/env/textures/bark_albedo.png")
		m.albedo_color = c  # tint bark
		m.normal_enabled = true
		m.normal_texture = load("res://assets/env/textures/bark_normal.png")
		m.normal_scale = 0.7
	else:
		m.albedo_texture = _cpu_noise_albedo(
			SEED + 11, 0.22, 128,
			[c.darkened(0.18), c, c.lightened(0.12)])
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.45, 0.45, 0.45)
	m.roughness = 0.8
	return m


func _stone_mat(c: Color) -> StandardMaterial3D:
	# Cool grey stone with faint moss undertone in the noise ramp.
	var m := _mat(c, 0.86)
	m.albedo_texture = _cpu_noise_albedo(
		SEED + 17, 0.11, 128,
		[c.darkened(0.12), c, Color(c.r * 0.9, minf(c.g * 1.08, 1.0), c.b * 0.95)])
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.28, 0.28, 0.28)
	m.normal_enabled = true
	m.normal_texture = _cpu_noise_normal(SEED + 19, 0.16, 128, 7.0)
	m.normal_scale = 0.8
	return m


## CPU-baked albedo ImageTexture (works headless; no NoiseTexture2D GPU wait).
func _cpu_noise_albedo(tex_seed: int, freq: float, size: int, colors: Array) -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = tex_seed
	noise.frequency = freq
	noise.fractal_octaves = 3
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var n_cols := colors.size()
	for y in size:
		for x in size:
			var v := clampf(noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5, 0.0, 0.999)
			var idx_f := v * float(n_cols - 1)
			var i0 := int(idx_f)
			var i1 := mini(i0 + 1, n_cols - 1)
			var c: Color = (colors[i0] as Color).lerp(colors[i1] as Color, idx_f - float(i0))
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


## CPU-baked normal map from height noise (Sobel).
func _cpu_noise_normal(tex_seed: int, freq: float, size: int, strength: float) -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = tex_seed
	noise.frequency = freq
	noise.fractal_octaves = 3
	var heights := PackedFloat32Array()
	heights.resize(size * size)
	for y in size:
		for x in size:
			heights[y * size + x] = noise.get_noise_2d(float(x), float(y))
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var xl := heights[y * size + ((x - 1 + size) % size)]
			var xr := heights[y * size + ((x + 1) % size)]
			var yu := heights[((y - 1 + size) % size) * size + x]
			var yd := heights[((y + 1) % size) * size + x]
			var n := Vector3((xl - xr) * strength, 2.0, (yu - yd) * strength).normalized()
			img.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))
	return ImageTexture.create_from_image(img)


# ----------------------------------------------------------------------------- navigation
## Navigation mesh settings shared by the runtime and the offline baker.
static func make_navigation_mesh() -> NavigationMesh:
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = Soldier.LAYER_WORLD
	nm.cell_size = 0.4
	nm.cell_height = 0.2
	nm.agent_radius = 0.45
	nm.agent_height = 1.8
	nm.agent_max_climb = 0.6
	nm.agent_max_slope = 42.0
	nm.region_min_size = 4.0
	nm.edge_max_error = 1.6
	nm.filter_baking_aabb = AABB(Vector3(-HALF_X + 4, -20, -HALF_Z + 4), Vector3(HALF_X * 2 - 8, 80, HALF_Z * 2 - 8))
	return nm


func _load_navigation() -> void:
	nav_region = NavigationRegion3D.new()
	nav_region.name = "Navigation"
	add_child(nav_region)
	if ResourceLoader.exists(NAV_PATH):
		nav_region.navigation_mesh = load(NAV_PATH)
	else:
		push_warning("[Battlefield] %s missing; baking at runtime (slow). Run tools/bake_navmesh.sh." % NAV_PATH)
		nav_region.navigation_mesh = make_navigation_mesh()
		nav_region.bake_navigation_mesh(false)
