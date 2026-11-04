class_name PlayerController
extends Node
## Turns keyboard/mouse and gamepad input into Soldier intent, and owns the player's cameras:
## an over-the-shoulder third-person camera (default) and a first-person camera (toggle).

signal camera_mode_changed(first_person: bool)

const MOUSE_RAD_PER_PIXEL := 0.0024
const GAMEPAD_RAD_PER_SEC := 3.2
const PITCH_LIMIT := deg_to_rad(80.0)
const TP_DISTANCE := 2.7
const TP_SHOULDER := 0.7
const TP_HEIGHT := 1.55
const EYE_HEIGHT := 1.62

var soldier: Soldier
var first_person := false
## Extra zoom requested by weapons (matchlock aim): 0 = none, 1 = full.
var aim_zoom := 0.0
## Disables input (pause, menus, end of match).
var input_enabled := true

var rig: Node3D
var yaw_node: Node3D
var pitch_node: Node3D
var spring: SpringArm3D
var tp_camera: Camera3D
var fp_camera: Camera3D

var _yaw := 0.0
var _pitch := -0.1
var _shake := 0.0
var _zoom := 0.0


func _ready() -> void:
	soldier = get_parent() as Soldier
	soldier.is_player = true
	soldier.controller = self
	soldier.visual.use_first_person_layers()
	_yaw = soldier.look_yaw
	_build_cameras()
	soldier.weapons.aim_provider = crosshair_ray
	soldier.died.connect(func(_s: Soldier, _k: Node) -> void: _apply_camera_mode())
	soldier.respawned.connect(func(_s: Soldier) -> void:
		_yaw = soldier.look_yaw
		_pitch = -0.1
		_apply_camera_mode())
	Settings.changed.connect(func(key: String) -> void:
		if key == "video/fov":
			_apply_fov())
	_apply_camera_mode()
	_apply_fov()


func _build_cameras() -> void:
	rig = Node3D.new()
	rig.name = "CameraRig"
	rig.top_level = true
	soldier.add_child(rig)
	yaw_node = Node3D.new()
	rig.add_child(yaw_node)
	pitch_node = Node3D.new()
	yaw_node.add_child(pitch_node)
	spring = SpringArm3D.new()
	spring.spring_length = TP_DISTANCE
	spring.margin = 0.15
	spring.collision_mask = Soldier.LAYER_WORLD
	spring.position = Vector3(TP_SHOULDER, 0, 0)
	var probe := SphereShape3D.new()
	probe.radius = 0.2
	spring.shape = probe
	pitch_node.add_child(spring)
	tp_camera = Camera3D.new()
	tp_camera.name = "ThirdPersonCamera"
	tp_camera.near = 0.08
	tp_camera.far = 900.0
	spring.add_child(tp_camera)
	fp_camera = Camera3D.new()
	fp_camera.name = "FirstPersonCamera"
	fp_camera.near = 0.05
	fp_camera.far = 900.0
	fp_camera.cull_mask = 0xFFFFF & ~(1 << (SoldierVisual.FIRST_PERSON_HIDDEN_LAYER - 1))
	pitch_node.add_child(fp_camera)


## Shots go where the crosshair points: find what the camera ray hits, then fire from the
## soldier's eye toward that point (so third-person shots can't pass through cover the soldier
## is behind).
func crosshair_ray() -> Array:
	var cam := current_camera()
	var from := cam.global_position
	var dir := -cam.global_basis.z
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 400.0,
		Soldier.LAYER_WORLD | Soldier.LAYER_SOLDIERS, [soldier.get_rid()])
	var hit := soldier.get_world_3d().direct_space_state.intersect_ray(q)
	var target: Vector3 = hit.position if not hit.is_empty() else from + dir * 400.0
	var eye := soldier.head_position() - Vector3(0, 0.1, 0)
	return [eye, (target - eye).normalized()]


func toggle_camera() -> void:
	first_person = not first_person
	_apply_camera_mode()
	camera_mode_changed.emit(first_person)


func current_camera() -> Camera3D:
	return fp_camera if fp_camera.current else tp_camera


func add_shake(amount: float) -> void:
	_shake = minf(_shake + amount, 1.0)


func _apply_camera_mode() -> void:
	# The dead always see themselves from outside.
	var fp := first_person and soldier.alive
	fp_camera.current = fp
	tp_camera.current = not fp


func _apply_fov() -> void:
	var fov: float = Settings.get_value("video/fov")
	tp_camera.fov = fov
	fp_camera.fov = fov


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens: float = Settings.get_value("controls/mouse_sensitivity") * (1.0 - 0.45 * _zoom)
		var invert := -1.0 if Settings.get_value("controls/invert_y") else 1.0
		_yaw -= event.relative.x * MOUSE_RAD_PER_PIXEL * sens
		_pitch = clampf(_pitch - event.relative.y * MOUSE_RAD_PER_PIXEL * sens * invert, -PITCH_LIMIT, PITCH_LIMIT)
	elif event.is_action_pressed("toggle_camera"):
		toggle_camera()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F2:
		# Prototype debug key: hurt yourself to test damage, death and respawn.
		soldier.take_damage(34.0, null, &"debug")


func _process(delta: float) -> void:
	if input_enabled and soldier.alive:
		var look := GameInput.look_vector()
		var invert := -1.0 if Settings.get_value("controls/invert_y") else 1.0
		_yaw -= look.x * GAMEPAD_RAD_PER_SEC * delta * (1.0 - 0.45 * _zoom)
		_pitch = clampf(_pitch - look.y * GAMEPAD_RAD_PER_SEC * 0.7 * delta * invert * (1.0 - 0.45 * _zoom), -PITCH_LIMIT, PITCH_LIMIT)
	_zoom = move_toward(_zoom, aim_zoom, delta * 6.0)
	_update_rig(delta)


func _physics_process(_delta: float) -> void:
	soldier.look_yaw = _yaw
	soldier.look_pitch = _pitch
	if not input_enabled or not soldier.alive:
		soldier.move_dir = Vector3.ZERO
		soldier.wants_sprint = false
		return
	var input := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	soldier.move_dir = Basis(Vector3.UP, _yaw) * Vector3(input.x, 0.0, -input.y)
	soldier.wants_sprint = Input.is_action_pressed("sprint") and input.y > 0.3
	if Input.is_action_just_pressed("jump"):
		soldier.wants_jump = true
	_weapon_input()


func _weapon_input() -> void:
	var w := soldier.weapons
	if Input.is_action_just_pressed("primary"):
		w.primary(true)
	elif Input.is_action_just_released("primary"):
		w.primary(false)
	if Input.is_action_just_pressed("secondary"):
		w.secondary(true)
	elif Input.is_action_just_released("secondary"):
		w.secondary(false)
	if Input.is_action_just_pressed("reload"):
		w.reload()
	if Input.is_action_just_pressed("switch_weapon"):
		w.switch_next()
	if Input.is_action_just_pressed("weapon_katana"):
		w.select_kind(&"katana")
	if Input.is_action_just_pressed("weapon_matchlock"):
		w.select_kind(&"matchlock")
	aim_zoom = 1.0 if w.is_aiming() else 0.0


func _update_rig(delta: float) -> void:
	var base := soldier.global_position
	rig.global_position = base + Vector3(0, TP_HEIGHT if not fp_camera.current else EYE_HEIGHT, 0)
	yaw_node.rotation.y = _yaw
	pitch_node.rotation = Vector3(_pitch, 0.0, 0.0)
	spring.spring_length = lerpf(TP_DISTANCE, 1.4, _zoom) if soldier.alive else TP_DISTANCE + 1.5
	spring.position.x = lerpf(TP_SHOULDER, 0.65, _zoom)
	fp_camera.position = Vector3(0, 0, -0.12)
	var fov: float = Settings.get_value("video/fov")
	tp_camera.fov = lerpf(fov, fov * 0.62, _zoom)
	fp_camera.fov = lerpf(fov, fov * 0.55, _zoom)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 2.5)
		var s := _shake * _shake * 0.06
		pitch_node.rotation = Vector3(_pitch + randf_range(-s, s), randf_range(-s, s), 0.0)
