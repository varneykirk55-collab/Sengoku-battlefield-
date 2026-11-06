class_name EnvMeshes
extends RefCounted
## Procedural stylized Sengoku environment meshes (original, copyright-safe).
## Japanese pine / sugi silhouettes: layered foliage plates + tapered trunk — not European oaks,
## not single cones. Used via MultiMesh on the battlefield.

static func japanese_pine() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Trunk: tapered cylinder, slight lean encoded in ring offsets.
	_add_trunk(st, 7.2, 0.32, 0.12, 10, 8, Color(0.28, 0.18, 0.1))
	# Layered foliage plates (flattened cones / discs) — sugi/pine silhouette.
	var layers := [
		{"y": 3.2, "r": 2.6, "h": 1.6, "c": Color(0.08, 0.32, 0.1)},
		{"y": 4.4, "r": 2.2, "h": 1.5, "c": Color(0.1, 0.4, 0.12)},
		{"y": 5.5, "r": 1.75, "h": 1.4, "c": Color(0.12, 0.48, 0.14)},
		{"y": 6.5, "r": 1.25, "h": 1.25, "c": Color(0.16, 0.55, 0.16)},
		{"y": 7.35, "r": 0.75, "h": 1.1, "c": Color(0.22, 0.62, 0.18)},
	]
	for L in layers:
		_add_foliage_plate(st, L.y, L.r, L.h, 9, L.c)
	# Small branch stubs under mid layers.
	for i in 5:
		var a := float(i) * TAU / 5.0 + 0.4
		var y := 3.6 + float(i) * 0.55
		_add_branch(st, Vector3(cos(a) * 0.25, y, sin(a) * 0.25), a, 0.9 + 0.15 * float(i % 2))
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


static func japanese_pine_lod() -> ArrayMesh:
	## Cheaper distant silhouette: trunk + 3 plates.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_trunk(st, 7.0, 0.3, 0.12, 7, 6, Color(0.28, 0.18, 0.1))
	_add_foliage_plate(st, 3.6, 2.4, 1.8, 7, Color(0.09, 0.36, 0.11))
	_add_foliage_plate(st, 5.4, 1.6, 1.5, 7, Color(0.14, 0.5, 0.15))
	_add_foliage_plate(st, 6.9, 0.85, 1.2, 6, Color(0.2, 0.58, 0.17))
	st.generate_normals()
	return st.commit()


static func shrub() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_ellipsoid(st, Vector3(0, 0.45, 0), Vector3(0.85, 0.55, 0.7), 8, 6, Color(0.14, 0.42, 0.12))
	_add_ellipsoid(st, Vector3(0.35, 0.55, 0.1), Vector3(0.55, 0.4, 0.5), 7, 5, Color(0.18, 0.5, 0.14))
	_add_ellipsoid(st, Vector3(-0.3, 0.5, -0.15), Vector3(0.5, 0.38, 0.48), 7, 5, Color(0.1, 0.38, 0.1))
	st.generate_normals()
	return st.commit()


static func grass_tuft() -> ArrayMesh:
	## Crossed quads for dense ground cover.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := 0.7
	var w := 0.55
	var cols := [Color(0.2, 0.55, 0.14), Color(0.28, 0.62, 0.16), Color(0.16, 0.48, 0.12)]
	for i in 3:
		var yaw := float(i) * PI / 3.0
		var c: Color = cols[i]
		_add_quad(st, Vector3(0, h * 0.5, 0), Vector2(w * (0.85 + 0.1 * float(i)), h), yaw, c)
	st.generate_normals()
	return st.commit()


static func rock_chunk() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Irregular faceted rock from subdivided / displaced icosphere-like points.
	var pts: Array[Vector3] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 14:
		var p := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.5, 1.0), rng.randf_range(-1, 1)).normalized()
		p *= Vector3(rng.randf_range(0.7, 1.2), rng.randf_range(0.45, 0.9), rng.randf_range(0.7, 1.15))
		pts.append(p)
	# Convex-ish fan from center bottom
	var center := Vector3(0, -0.2, 0)
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		_tri(st, center, a, b, Color(0.5, 0.52, 0.54))
		_tri(st, a, Vector3(0, 0.55, 0), b, Color(0.48, 0.5, 0.52))
	st.generate_normals()
	return st.commit()


# ----------------------------------------------------------------------------- primitives
static func _add_trunk(st: SurfaceTool, height: float, r_bot: float, r_top: float, rings: int, segs: int, color: Color) -> void:
	for yi in rings:
		var t0 := float(yi) / float(rings)
		var t1 := float(yi + 1) / float(rings)
		var y0 := t0 * height
		var y1 := t1 * height
		var r0 := lerpf(r_bot, r_top, t0)
		var r1 := lerpf(r_bot, r_top, t1)
		var lean0 := Vector3(0.08 * t0, 0, 0.04 * t0)
		var lean1 := Vector3(0.08 * t1, 0, 0.04 * t1)
		for si in segs:
			var a0 := float(si) / float(segs) * TAU
			var a1 := float(si + 1) / float(segs) * TAU
			var p00 := Vector3(cos(a0) * r0, y0, sin(a0) * r0) + lean0
			var p10 := Vector3(cos(a1) * r0, y0, sin(a1) * r0) + lean0
			var p01 := Vector3(cos(a0) * r1, y1, sin(a0) * r1) + lean1
			var p11 := Vector3(cos(a1) * r1, y1, sin(a1) * r1) + lean1
			var shade := color.darkened(0.08 * (0.5 + 0.5 * cos(a0)))
			_tri(st, p00, p01, p11, shade)
			_tri(st, p00, p11, p10, shade)


static func _add_foliage_plate(st: SurfaceTool, y: float, radius: float, height: float, segs: int, color: Color) -> void:
	# Flattened cone: wide base, pointed top — classic stylized pine tier.
	var tip := Vector3(0, y + height * 0.55, 0)
	var base_y := y - height * 0.35
	# Slight horizontal jitter of tip for organic asymmetry
	tip.x += sin(y * 3.1) * 0.12
	tip.z += cos(y * 2.7) * 0.1
	for si in segs:
		var a0 := float(si) / float(segs) * TAU
		var a1 := float(si + 1) / float(segs) * TAU
		# Scalloped edge
		var r0 := radius * (0.92 + 0.08 * sin(a0 * 3.0 + y))
		var r1 := radius * (0.92 + 0.08 * sin(a1 * 3.0 + y))
		var p0 := Vector3(cos(a0) * r0, base_y, sin(a0) * r0)
		var p1 := Vector3(cos(a1) * r1, base_y, sin(a1) * r1)
		var c_edge := color.darkened(0.12)
		var c_lit := color.lightened(0.08)
		_tri(st, tip, p0, p1, c_lit if si % 2 == 0 else c_edge)
	# Underside disc (darker)
	var under := color.darkened(0.25)
	var ctr := Vector3(0, base_y, 0)
	for si in segs:
		var a0 := float(si) / float(segs) * TAU
		var a1 := float(si + 1) / float(segs) * TAU
		var p0 := Vector3(cos(a0) * radius * 0.95, base_y, sin(a0) * radius * 0.95)
		var p1 := Vector3(cos(a1) * radius * 0.95, base_y, sin(a1) * radius * 0.95)
		_tri(st, ctr, p1, p0, under)


static func _add_branch(st: SurfaceTool, origin: Vector3, yaw: float, length: float) -> void:
	var tip := origin + Vector3(cos(yaw), 0.25, sin(yaw)) * length
	var side := Vector3(-sin(yaw), 0, cos(yaw)) * 0.06
	var c := Color(0.25, 0.15, 0.08)
	_tri(st, origin + side, tip, origin - side, c)
	_tri(st, origin - side, tip, origin + side, c)


static func _add_ellipsoid(st: SurfaceTool, center: Vector3, radii: Vector3, segs_h: int, segs_v: int, color: Color) -> void:
	for v in segs_v:
		var v0 := float(v) / float(segs_v)
		var v1 := float(v + 1) / float(segs_v)
		var phi0 := v0 * PI
		var phi1 := v1 * PI
		for h in segs_h:
			var u0 := float(h) / float(segs_h)
			var u1 := float(h + 1) / float(segs_h)
			var th0 := u0 * TAU
			var th1 := u1 * TAU
			var p00 := center + Vector3(sin(phi0) * cos(th0), cos(phi0), sin(phi0) * sin(th0)) * radii
			var p10 := center + Vector3(sin(phi0) * cos(th1), cos(phi0), sin(phi0) * sin(th1)) * radii
			var p01 := center + Vector3(sin(phi1) * cos(th0), cos(phi1), sin(phi1) * sin(th0)) * radii
			var p11 := center + Vector3(sin(phi1) * cos(th1), cos(phi1), sin(phi1) * sin(th1)) * radii
			var shade := color.darkened(0.1 * (1.0 - absf(cos(phi0))))
			_tri(st, p00, p01, p11, shade)
			_tri(st, p00, p11, p10, shade)


static func _add_quad(st: SurfaceTool, center: Vector3, size: Vector2, yaw: float, color: Color) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var right := Vector3(cos(yaw), 0, sin(yaw)) * hx
	var up := Vector3(0, hy, 0)
	var p0 := center - right - up
	var p1 := center + right - up
	var p2 := center + right + up
	var p3 := center - right + up
	_tri(st, p0, p1, p2, color)
	_tri(st, p0, p2, p3, color)
	# backface
	var cd := color.darkened(0.05)
	_tri(st, p0, p2, p1, cd)
	_tri(st, p0, p3, p2, cd)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var n := (b - a).cross(c - a).normalized()
	st.set_normal(n)
	st.set_color(color)
	st.set_uv(Vector2(a.x, a.y) * 0.2)
	st.add_vertex(a)
	st.set_normal(n)
	st.set_color(color)
	st.set_uv(Vector2(b.x, b.y) * 0.2)
	st.add_vertex(b)
	st.set_normal(n)
	st.set_color(color)
	st.set_uv(Vector2(c.x, c.y) * 0.2)
	st.add_vertex(c)
