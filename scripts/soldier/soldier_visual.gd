class_name SoldierVisual
extends Node3D
## Samurai body: armored model from Bot 1, driven by an AnimationTree.
##   * Locomotion (idle / walk / run) plays on the whole body.
##   * Actions (katana slash, matchlock fire / reload, hit reactions) and the matchlock aim pose
##     play on the upper body only, so soldiers keep moving while fighting.
##   * Death switches to a full-body clip.
## Each soldier carries a sashimono (back banner) and faction armor materials (red / blue).
## Animation can be updated at a reduced rate for distant soldiers (see update_interval).

const MODEL := preload("res://assets/characters/samurai/sengoku_samurai_anims.glb")
const CLIP := {
	&"idle": "Idle", &"walk": "Walk", &"run": "Run", &"slash": "Katana_Slash", &"aim": "Musket_Aim",
	&"fire": "Musket_Fire", &"reload": "Musket_Reload", &"hit": "Hit_React", &"death": "Death",
}
const LOOPING := ["Idle", "Walk", "Run", "Musket_Aim"]
## Single armor mesh (Samurai_GameMesh) — no separate head parts to hide in first person.
const HEAD_MESHES := []
const FIRST_PERSON_HIDDEN_LAYER := 2
const BANNER_COLORS := [Color(0.78, 0.12, 0.1), Color(0.12, 0.28, 0.75)]
const ARMOR_ALBEDO := [
	"res://assets/characters/samurai/textures/SamuraiArmor_Red_BaseColor.png",
	"res://assets/characters/samurai/textures/SamuraiArmor_Blue_BaseColor.png",
]
const ARMOR_METALLIC := "res://assets/characters/samurai/textures/SamuraiArmor_Shared_Metallic.png"
const ARMOR_ROUGHNESS := "res://assets/characters/samurai/textures/SamuraiArmor_Shared_Roughness.png"
const ARMOR_NORMAL := "res://assets/characters/samurai/textures/SamuraiArmor_Shared_Normal.png"
## Death clip dips armor plates ~10 cm through the floor; lift the visual by this amount while dead.
const DEATH_FLOOR_NUDGE := 0.10

const P_LOCO := &"parameters/loco/blend_position"
const P_LOCO_SPEED := &"parameters/loco_speed/scale"
const P_AIM := &"parameters/aim_blend/blend_amount"
const P_STANCE := &"parameters/stance_mix/blend_amount"
const P_ACTION_SPEED := &"parameters/action_speed/scale"
const P_ONESHOT := &"parameters/oneshot/request"
## Soldiers beyond this distance are not drawn (fog hides them anyway).
const DRAW_DISTANCE := 260.0

static var _library: AnimationLibrary
static var _upper_paths: Array[NodePath] = []
static var _armor_materials: Dictionary = {}
static var _banner_materials: Dictionary = {}

var model: Node3D
var skeleton: Skeleton3D
var anim: AnimationPlayer
var tree: AnimationTree
var hand_r: BoneAttachment3D
var hand_l: BoneAttachment3D
var hip: BoneAttachment3D
var back: BoneAttachment3D
var head: BoneAttachment3D
## Matchlock mount, placed every frame at the `musket_ctrl` bone (the clips move that bone to the
## shoulder for aim/fire/reload and onto the back otherwise). Positioned by code rather than a
## BoneAttachment3D so its orientation can be overridden reliably (see gun_aim_dir).
var gun_mount: Node3D
var _gun_bone := -1
var stance: StringName = &"none"
## When set (non-zero), the shouldered matchlock points along this world direction instead of
## the clip's bone angle (the aim clip holds the gun ~30 degrees off the line of sight).
var gun_aim_dir := Vector3.ZERO
var dead := false
## Seconds between animation updates (0 = every frame). Raised for distant soldiers.
var update_interval := 0.0

var _accum := 0.0
var _last_gait := -1.0
var _last_scale := -1.0
var _action_end := 0.0
var _time := 0.0
var _model_base_y := 0.0


func setup(faction: int) -> void:
	model = MODEL.instantiate()
	model.rotation.y = PI  # the model faces +Z; Godot's forward is -Z
	_model_base_y = model.position.y
	add_child(model)
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	anim = model.find_children("*", "AnimationPlayer", true, false)[0]
	_share_library()
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_build_tree()
	hand_r = _attach("weapon_r")
	hand_l = _attach("weapon_l")
	hip = _attach("katana_sheath")
	back = _attach("musket_back")
	head = _attach("head")
	gun_mount = Node3D.new()
	gun_mount.name = "GunMount"
	gun_mount.top_level = true
	add_child(gun_mount)
	_gun_bone = skeleton.find_bone("musket_ctrl")
	_apply_faction(faction)
	for mi in skeleton.get_children():
		if mi is MeshInstance3D:
			(mi as MeshInstance3D).visibility_range_end = DRAW_DISTANCE
			(mi as MeshInstance3D).visibility_range_end_margin = 20.0
			(mi as MeshInstance3D).visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


## Ground speed in m/s drives the walk/run blend and leg playback rate.
func set_locomotion(speed: float, grounded: bool) -> void:
	if dead or tree == null:
		return
	var gait := clampf(speed / 2.4, 0.0, 1.0) if speed < 2.4 else 1.0 + clampf((speed - 2.4) / 2.0, 0.0, 1.0)
	if absf(gait - _last_gait) > 0.01:
		_last_gait = gait
		tree.set(P_LOCO, gait)
	var scale := 1.0
	if speed > 0.1:
		scale = clampf(speed / 1.4, 0.7, 1.6) if speed < 2.4 else clampf(speed / 2.6, 1.0, 2.4)
	if not grounded:
		scale = 0.25  # hang in the stride while airborne (no jump clip on this rig)
	if absf(scale - _last_scale) > 0.01:
		_last_scale = scale
		tree.set(P_LOCO_SPEED, scale)


## Upper-body stance held while moving: &"katana" (blade ready), &"matchlock" (gun shouldered)
## or &"none" (arms follow the locomotion clip).
func set_stance(kind: StringName) -> void:
	stance = kind
	if tree == null:
		return
	tree.set(P_AIM, 0.0 if kind == &"none" else 1.0)
	tree.set(P_STANCE, 1.0 if kind == &"matchlock" else 0.0)


## Shoulders the matchlock (kept for tools/tests).
func set_aim(amount: float) -> void:
	set_stance(&"matchlock" if amount > 0.5 else &"none")


## Plays an upper-body action clip stretched to `duration` seconds.
func play_action(action: StringName, duration: float) -> void:
	if dead or tree == null:
		return
	var clip: String = CLIP.get(action, "")
	if clip == "" or not anim.has_animation(clip):
		return
	var node := (tree.tree_root as AnimationNodeBlendTree).get_node(&"action") as AnimationNodeAnimation
	node.animation = clip
	var length := anim.get_animation(clip).length
	tree.set(P_ACTION_SPEED, length / maxf(duration, 0.05))
	tree.set(P_ONESHOT, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	_action_end = _time + duration


func cancel_action() -> void:
	if tree:
		tree.set(P_ONESHOT, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)


func is_action_playing() -> bool:
	return _time < _action_end


func hit_react() -> void:
	if not is_action_playing():
		play_action(&"hit", 0.45)


func die() -> void:
	dead = true
	tree.active = false
	# Nudge visual up so armor plates don't clip through the floor (~10 cm in the Death clip).
	if model:
		model.position.y = _model_base_y + DEATH_FLOOR_NUDGE
	anim.play(CLIP[&"death"], 0.1)
	anim.advance(0.0)


func reset() -> void:
	dead = false
	_action_end = 0.0
	if model:
		model.position.y = _model_base_y
	anim.stop()
	tree.active = true
	set_stance(stance)
	_last_gait = -1.0
	_last_scale = -1.0
	set_locomotion(0.0, true)
	tree.advance(0.0)


## Hides head geometry from cameras that exclude render layer 2 (the first-person camera).
## Samurai is a single mesh; nothing separate to hide — call is a no-op until split meshes exist.
func use_first_person_layers() -> void:
	for name in HEAD_MESHES:
		var mi := skeleton.get_node_or_null(name) as MeshInstance3D
		if mi:
			mi.layers = 1 << (FIRST_PERSON_HIDDEN_LAYER - 1)


func set_cast_shadows(on: bool) -> void:
	for mi in skeleton.get_children():
		if mi is MeshInstance3D:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static var prof_anim_us := 0


func _process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	_process_body(delta)
	prof_anim_us += Time.get_ticks_usec() - t0


func _process_body(delta: float) -> void:
	_time += delta
	_accum += delta
	if _accum < update_interval:
		_place_gun()
		return
	if dead:
		anim.advance(_accum)
	elif tree:
		tree.advance(_accum)
	_accum = 0.0
	_place_gun()


func _place_gun() -> void:
	if gun_mount.get_child_count() == 0:
		return
	var bone := skeleton.global_transform * skeleton.get_bone_global_pose(_gun_bone)
	var basis := bone.basis.orthonormalized()
	if gun_aim_dir != Vector3.ZERO:
		var y := gun_aim_dir.normalized()
		var z := (Vector3.UP - y * Vector3.UP.dot(y))
		z = z.normalized() if z.length() > 0.1 else Vector3.BACK
		basis = Basis(y.cross(z).normalized(), y, z)
	gun_mount.global_transform = Transform3D(basis, bone.origin)


# ----------------------------------------------------------------------------- setup helpers
func _share_library() -> void:
	# One looping-enabled copy of the clips, shared by every soldier (source keyframes untouched).
	if _library == null:
		var original := anim.get_animation_library(&"")
		_library = AnimationLibrary.new()
		for clip in original.get_animation_list():
			var a: Animation = original.get_animation(clip).duplicate()
			a.loop_mode = Animation.LOOP_LINEAR if LOOPING.has(String(clip)) else Animation.LOOP_NONE
			_library.add_animation(clip, a)
	anim.remove_animation_library(&"")
	anim.add_animation_library(&"", _library)


func _upper_body_paths() -> Array[NodePath]:
	if _upper_paths.is_empty():
		var spine := skeleton.find_bone("spine_01")
		var skel_path := String(model.get_path_to(skeleton))
		for b in skeleton.get_bone_count():
			var i := b
			var upper := skeleton.get_bone_name(b) == "musket_ctrl"
			while i >= 0 and not upper:
				if i == spine:
					upper = true
				i = skeleton.get_bone_parent(i)
			if upper:
				_upper_paths.append(NodePath(skel_path + ":" + skeleton.get_bone_name(b)))
	return _upper_paths


func _build_tree() -> void:
	var bt := AnimationNodeBlendTree.new()
	var loco := AnimationNodeBlendSpace1D.new()
	loco.min_space = 0.0
	loco.max_space = 2.0
	for p in [[&"idle", 0.0], [&"walk", 1.0], [&"run", 2.0]]:
		var a := AnimationNodeAnimation.new()
		a.animation = CLIP[p[0]]
		loco.add_blend_point(a, p[1], -1, p[0])
	bt.add_node(&"loco", loco, Vector2(0, 0))
	bt.add_node(&"loco_speed", AnimationNodeTimeScale.new(), Vector2(200, 0))
	var aim := AnimationNodeAnimation.new()
	aim.animation = CLIP[&"aim"]
	bt.add_node(&"aim", aim, Vector2(200, 200))
	# Katana ready stance: the first frame of the slash, frozen (time scale 0).
	var ready := AnimationNodeAnimation.new()
	ready.animation = CLIP[&"slash"]
	bt.add_node(&"ready", ready, Vector2(0, 300))
	bt.add_node(&"ready_freeze", AnimationNodeTimeScale.new(), Vector2(200, 300))
	bt.add_node(&"stance_mix", AnimationNodeBlend2.new(), Vector2(300, 250))
	var aim_blend := AnimationNodeBlend2.new()
	_filter_upper(aim_blend)
	bt.add_node(&"aim_blend", aim_blend, Vector2(400, 0))
	var action := AnimationNodeAnimation.new()
	action.animation = CLIP[&"slash"]
	bt.add_node(&"action", action, Vector2(200, 400))
	bt.add_node(&"action_speed", AnimationNodeTimeScale.new(), Vector2(400, 400))
	var oneshot := AnimationNodeOneShot.new()
	oneshot.fadein_time = 0.08
	oneshot.fadeout_time = 0.18
	_filter_upper(oneshot)
	bt.add_node(&"oneshot", oneshot, Vector2(600, 0))
	bt.connect_node(&"loco_speed", 0, &"loco")
	bt.connect_node(&"aim_blend", 0, &"loco_speed")
	bt.connect_node(&"ready_freeze", 0, &"ready")
	bt.connect_node(&"stance_mix", 0, &"ready_freeze")
	bt.connect_node(&"stance_mix", 1, &"aim")
	bt.connect_node(&"aim_blend", 1, &"stance_mix")
	bt.connect_node(&"action_speed", 0, &"action")
	bt.connect_node(&"oneshot", 0, &"aim_blend")
	bt.connect_node(&"oneshot", 1, &"action_speed")
	bt.connect_node(&"output", 0, &"oneshot")

	tree = AnimationTree.new()
	tree.name = "AnimationTree"
	model.add_child(tree)
	tree.root_node = NodePath("..")
	tree.anim_player = tree.get_path_to(anim)
	tree.tree_root = bt
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	tree.active = true
	tree.set("parameters/loco_speed/scale", 1.0)
	tree.set("parameters/action_speed/scale", 1.0)
	tree.set("parameters/aim_blend/blend_amount", 0.0)
	tree.set("parameters/ready_freeze/scale", 0.0)
	tree.set("parameters/stance_mix/blend_amount", 0.0)


func _filter_upper(node: AnimationNode) -> void:
	node.filter_enabled = true
	for p in _upper_body_paths():
		node.set_filter_path(p, true)


func _attach(bone: String) -> BoneAttachment3D:
	var ba := BoneAttachment3D.new()
	ba.name = "Attach_" + bone
	ba.bone_name = bone
	skeleton.add_child(ba)
	return ba


func _apply_faction(faction: int) -> void:
	faction = clampi(faction, 0, 1)
	var armor := _find_armor_mesh()
	if armor:
		if not _armor_materials.has(faction):
			_armor_materials[faction] = _make_armor_mat(ARMOR_ALBEDO[faction])
		armor.set_surface_override_material(0, _armor_materials[faction])
	if not _banner_materials.has(faction):
		var bm := StandardMaterial3D.new()
		bm.albedo_color = BANNER_COLORS[faction]
		bm.roughness = 0.85
		bm.cull_mode = BaseMaterial3D.CULL_DISABLED
		_banner_materials[faction] = bm
	# Sashimono: a pole on the back with a vertical banner in the faction colour.
	var spine := _attach("spine_03")
	var banner := Node3D.new()
	banner.name = "Sashimono"
	spine.add_child(banner)
	banner.position = Vector3(0.0, 0.05, -0.2)  # model space: -Z is the back
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.012
	pm.bottom_radius = 0.012
	pm.height = 1.25
	pm.radial_segments = 6
	pole.mesh = pm
	pole.material_override = _pole_material()
	pole.position = Vector3(0, 0.55, 0)
	banner.add_child(pole)
	var flag := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.36, 0.72, 0.012)
	flag.mesh = fm
	flag.material_override = _banner_materials[faction]
	flag.position = Vector3(0.19, 0.78, 0)
	banner.add_child(flag)


func _find_armor_mesh() -> MeshInstance3D:
	var named := skeleton.get_node_or_null("Samurai_GameMesh") as MeshInstance3D
	if named:
		return named
	for mi in skeleton.get_children():
		if mi is MeshInstance3D:
			return mi as MeshInstance3D
	# Some GLB imports nest the mesh under an intermediate node.
	var found := model.find_children("*", "MeshInstance3D", true, false)
	return found[0] as MeshInstance3D if not found.is_empty() else null


static func _make_armor_mat(albedo_path: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(albedo_path)
	m.metallic_texture = load(ARMOR_METALLIC)
	m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.metallic = 1.0
	m.roughness_texture = load(ARMOR_ROUGHNESS)
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.normal_enabled = true
	m.normal_texture = load(ARMOR_NORMAL)
	return m


static var _pole_mat: StandardMaterial3D
static func _pole_material() -> StandardMaterial3D:
	if _pole_mat == null:
		_pole_mat = StandardMaterial3D.new()
		_pole_mat.albedo_color = Color(0.22, 0.16, 0.1)
	return _pole_mat
