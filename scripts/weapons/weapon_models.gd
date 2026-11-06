class_name WeaponModels
extends RefCounted
## Weapon meshes and where they sit on the samurai rig.
##
## Conventions (bone space): blades and barrels point along +Y.
##   katana in hand  -> `weapon_r` bone      sheathed -> `katana_sheath` bone
##   matchlock       -> `musket_ctrl` bone: the samurai clips move this bone to the shoulder for
##                      aim / fire / reload and onto the back otherwise, so the gun is shouldered
##                      or slung automatically.
## Player katana: detailed Katana.glb. AI katana: mid-detail procedural (one draw call) for mass
## battles — flip USE_DETAILED_AI_KATANA if profiling allows instanced GLBs.
## Matchlock: TEMP improved procedural tanegashima (no licensed GLB in-repo). Replace make_matchlock()
## when a real asset arrives. Do NOT import Iron Crowns Napoleonic muskets without Kirk approval.

const DETAILED_KATANA := preload("res://assets/weapons/Katana.glb")
const USE_DETAILED_AI_KATANA := false
## After Bot 1 socket repair (9845cd1): IDENTITY mounts; optional grip polish −0.02 m Y.
const KATANA_IN_HAND := Transform3D(Basis.IDENTITY, Vector3(0, -0.02, 0))
const KATANA_SHEATHED := Transform3D(Basis.IDENTITY, Vector3(0, 0.02, 0))  # saya along left waist; nudge +X only if armor clips
const MATCHLOCK_MOUNT := Transform3D(Basis.IDENTITY, Vector3(0, 0, 0))

static var _katana_mesh: ArrayMesh
static var _saya_mesh: ArrayMesh
static var _matchlock_mesh: ArrayMesh
static var _material: StandardMaterial3D
static var _match_glow: StandardMaterial3D


## Parts of the detailed Katana.glb that belong to the scabbard (hidden while the blade is drawn).
const SCABBARD_PARTS := ["Saya", "Koiguchi", "Kojiri", "Kurikata", "Sageo"]
const SCABBARD_OFFSET := 0.147


static func put_katana_in_hand(w: Weapon) -> void:
	_ensure_katana(w)
	_reparent(w.model, w.soldier.visual.hand_r, KATANA_IN_HAND)
	_show_scabbard(w.model, false)


static func sheathe_katana(w: Weapon) -> void:
	_ensure_katana(w)
	_reparent(w.model, w.soldier.visual.hip, KATANA_SHEATHED)
	_show_scabbard(w.model, true)


static func _show_scabbard(model: Node3D, on: bool) -> void:
	for n: Node3D in model.get_meta("scabbard", []):
		n.visible = on
	for n: Node3D in model.get_meta("blade", []):
		n.visible = not on  # the blade is inside the scabbard


static func mount_matchlock(w: Weapon) -> void:
	if w.model == null:
		w.model = make_matchlock()
	_reparent(w.model, w.soldier.visual.gun_mount, MATCHLOCK_MOUNT)


static func _ensure_katana(w: Weapon) -> void:
	if w.model == null:
		w.model = make_katana(w.soldier.is_player or USE_DETAILED_AI_KATANA)


static func _reparent(n: Node3D, parent: Node3D, xform: Transform3D) -> void:
	if n.get_parent() != parent:
		if n.get_parent():
			n.get_parent().remove_child(n)
		parent.add_child(n)
	n.transform = xform


static func make_katana(detailed: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "KatanaModel"
	var scabbard: Array[Node3D] = []
	var blade: Array[Node3D] = []
	if detailed:
		var k: Node3D = DETAILED_KATANA.instantiate()
		k.transform = Transform3D(Basis(Vector3.BACK, PI / 2.0), Vector3.ZERO)  # model +X -> bone +Y
		root.add_child(k)
		for mi: MeshInstance3D in k.find_children("*", "MeshInstance3D", true, false):
			var nm := String(mi.name)
			if nm.begins_with("Blade") or nm.begins_with("Hamon"):
				blade.append(mi)
			for part in SCABBARD_PARTS:
				if nm.begins_with(part):
					# The GLB lays the scabbard out beside the blade; move it onto the blade axis.
					mi.position.y += SCABBARD_OFFSET
					scabbard.append(mi)
	else:
		var mi := MeshInstance3D.new()
		mi.mesh = _katana()
		mi.material_override = _mat()
		root.add_child(mi)
		var saya := MeshInstance3D.new()
		saya.name = "Saya"
		saya.mesh = _saya()
		saya.material_override = _mat()
		root.add_child(saya)
		scabbard.append(saya)
	root.set_meta("scabbard", scabbard)
	root.set_meta("blade", blade)
	return root


## TEMP procedural tanegashima — readable stock/barrel/lock/serpentine until a real GLB ships.
static func make_matchlock() -> Node3D:
	var root := Node3D.new()
	root.name = "MatchlockModel_TEMP"
	var mi := MeshInstance3D.new()
	mi.mesh = _matchlock()
	mi.material_override = _mat()
	root.add_child(mi)
	# Smouldering match cord tip in the serpentine jaw.
	var glow := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.007
	s.height = 0.014
	s.radial_segments = 6
	s.rings = 3
	glow.mesh = s
	glow.material_override = _glow()
	glow.position = Vector3(0.032, 0.22, 0.04)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(glow)
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 1.16, 0)  # barrel tip along +Y
	root.add_child(muzzle)
	return root


# ----------------------------------------------------------------------------- procedural meshes
static func _katana() -> ArrayMesh:
	# Mid-detail AI blade (one draw call). Player uses Katana.glb instead.
	if _katana_mesh == null:
		var steel := Color(0.82, 0.84, 0.88)
		var wrap := Color(0.1, 0.08, 0.08)
		var brass := Color(0.58, 0.44, 0.22)
		var iron := Color(0.25, 0.24, 0.24)
		_katana_mesh = _combine([
			[_box(Vector3(0.026, 0.72, 0.006)), Transform3D(Basis.IDENTITY, Vector3(0, 0.39, 0)), steel],
			[_box(Vector3(0.014, 0.055, 0.005)), Transform3D(Basis(Vector3.BACK, 0.45), Vector3(0.004, 0.76, 0)), steel],
			[_cyl(0.04, 0.007, 10), Transform3D(Basis.IDENTITY, Vector3(0, 0.02, 0)), iron],  # tsuba
			[_cyl(0.018, 0.02, 8), Transform3D(Basis.IDENTITY, Vector3(0, 0.035, 0)), brass],  # fuchi
			[_box(Vector3(0.028, 0.26, 0.022)), Transform3D(Basis.IDENTITY, Vector3(0, -0.12, 0)), wrap],
			[_cyl(0.016, 0.022, 8), Transform3D(Basis.IDENTITY, Vector3(0, -0.26, 0)), iron],  # kashira
		])
	return _katana_mesh


static func _saya() -> ArrayMesh:
	if _saya_mesh == null:
		_saya_mesh = _combine([
			[_box(Vector3(0.038, 0.74, 0.026)), Transform3D(Basis.IDENTITY, Vector3(0, 0.40, 0)), Color(0.06, 0.05, 0.05)],
			[_box(Vector3(0.04, 0.03, 0.028)), Transform3D(Basis.IDENTITY, Vector3(0, 0.76, 0)), Color(0.5, 0.4, 0.2)],
		])
	return _saya_mesh


static func _matchlock() -> ArrayMesh:
	# TEMP improved low-poly tanegashima silhouette (octagonal barrel, full stock, lock, serpentine).
	if _matchlock_mesh == null:
		var iron := Color(0.18, 0.17, 0.16)
		var wood := Color(0.42, 0.24, 0.12)
		var dark_wood := Color(0.28, 0.15, 0.08)
		var brass := Color(0.68, 0.52, 0.24)
		_matchlock_mesh = _combine([
			# octagonal barrel along +Y (muzzle at ~1.16)
			[_cyl(0.015, 0.95, 8), Transform3D(Basis.IDENTITY, Vector3(0, 0.66, 0)), iron],
			[_cyl(0.019, 0.05, 8), Transform3D(Basis.IDENTITY, Vector3(0, 1.12, 0)), iron],  # muzzle ring
			[_cyl(0.022, 0.06, 8), Transform3D(Basis.IDENTITY, Vector3(0, 0.22, 0)), iron],  # breech
			# forestock under barrel
			[_box(Vector3(0.038, 0.85, 0.032)), Transform3D(Basis.IDENTITY, Vector3(0, 0.55, -0.028)), wood],
			# cheek / pistol grip (tanegashima has no long shoulder stock)
			[_box(Vector3(0.042, 0.22, 0.065)), Transform3D(Basis(Vector3.RIGHT, -0.35), Vector3(0, -0.02, -0.05)), dark_wood],
			[_box(Vector3(0.04, 0.12, 0.055)), Transform3D(Basis(Vector3.RIGHT, -0.7), Vector3(0, -0.12, -0.09)), dark_wood],
			# brass lock plate (right side)
			[_box(Vector3(0.007, 0.12, 0.036)), Transform3D(Basis.IDENTITY, Vector3(0.026, 0.18, -0.01)), brass],
			# serpentine (S-shaped match holder) — two angled boxes
			[_box(Vector3(0.006, 0.014, 0.055)), Transform3D(Basis(Vector3.RIGHT, 0.75), Vector3(0.032, 0.21, 0.02)), brass],
			[_box(Vector3(0.006, 0.01, 0.035)), Transform3D(Basis(Vector3.RIGHT, -0.4), Vector3(0.032, 0.24, 0.045)), brass],
			# pan / flash pan shelf
			[_box(Vector3(0.02, 0.018, 0.02)), Transform3D(Basis.IDENTITY, Vector3(0.02, 0.2, 0.012)), brass],
			# front sight blade
			[_box(Vector3(0.005, 0.014, 0.01)), Transform3D(Basis.IDENTITY, Vector3(0, 1.1, 0.018)), brass],
			# barrel bands
			[_cyl(0.02, 0.012, 8), Transform3D(Basis.IDENTITY, Vector3(0, 0.85, 0)), brass],
			[_cyl(0.02, 0.012, 8), Transform3D(Basis.IDENTITY, Vector3(0, 0.45, 0)), brass],
		])
	return _matchlock_mesh


static func _box(size: Vector3) -> PrimitiveMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func _cyl(radius: float, height: float, segments: int) -> PrimitiveMesh:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = segments
	c.rings = 1
	return c


## Merges primitive parts into one vertex-coloured mesh (one draw call).
static func _combine(parts: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part in parts:
		var arrays: Array = (part[0] as PrimitiveMesh).get_mesh_arrays()
		var xf: Transform3D = part[1]
		var col: Color = part[2]
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var order: Array = range(verts.size()) if idx.is_empty() else Array(idx)
		for i in order:
			st.set_color(col)
			st.set_normal((xf.basis * normals[i]).normalized())
			st.add_vertex(xf * verts[i])
	return st.commit()


static func _mat() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 0.55
		_material.metallic = 0.25
	return _material


static func _glow() -> StandardMaterial3D:
	if _match_glow == null:
		_match_glow = StandardMaterial3D.new()
		_match_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_match_glow.albedo_color = Color(1.0, 0.45, 0.1)
		_match_glow.emission_enabled = true
		_match_glow.emission = Color(1.0, 0.4, 0.1)
		_match_glow.emission_energy_multiplier = 3.0
	return _match_glow
