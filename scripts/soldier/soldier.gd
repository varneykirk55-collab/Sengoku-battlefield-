class_name Soldier
extends CharacterBody3D
## One fighter on the battlefield, used by both the player and the AI.
## A controller (PlayerController or AIController) writes the intent fields each frame
## (move_dir, wants_sprint, wants_jump, look_yaw / look_pitch); Soldier turns them into
## movement, owns health, death and body sounds, and exposes weapons (M2).

signal died(soldier: Soldier, killer: Node)
signal respawned(soldier: Soldier)
signal damaged(soldier: Soldier, amount: float, source: Node)

const LAYER_WORLD := 1
const LAYER_SOLDIERS := 2

@export var faction := 0
@export var display_name := "Ashigaru"

@export_group("Movement")
@export var run_speed := 4.6
@export var sprint_speed := 6.8
## Speed while aiming the matchlock or recovering from a heavy action.
@export var slow_speed := 2.2
@export var acceleration := 26.0
@export var air_control := 0.3
@export var jump_velocity := 5.0
@export var turn_speed := 12.0
## Below this height the soldier is considered out of the world and dies.
@export var kill_height := -30.0

# ---- intent, written by the controller every frame ----
## World-space desired direction on the ground plane, length 0..1.
var move_dir := Vector3.ZERO
var wants_sprint := false
var wants_jump := false
## Where the soldier is looking (radians). Yaw 0 = facing -Z.
var look_yaw := 0.0
var look_pitch := 0.0
## While true the body faces look_yaw (aiming / attacking); otherwise it faces its movement.
var face_look := false
## Multiplier applied by weapons (aiming, reloading, swinging).
var speed_scale := 1.0
## Yaw forced by an attack in progress (NAN = none).
var facing_override := NAN

## Physics level of detail, set by the BattleDirector: far-away soldiers who aren't fighting
## move every other physics frame (at double step), halving their character-controller cost.
var half_rate_physics := false
var controller: Node = null
var health: HealthComponent
var visual: SoldierVisual
var weapons: WeaponHolder
var alive := true
var is_player := false
var kills := 0
var deaths := 0
## Seconds of protection after (re)spawning; attacking ends it early.
const SPAWN_PROTECTION := 2.0
var protected_for := 0.0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _stride := 0.0
var _was_on_floor := true
var _air_time := 0.0
var _body_yaw := 0.0
var _impulse := Vector3.ZERO
var _move_vel := Vector3.ZERO
var _half_frame := false


func _ready() -> void:
	collision_layer = LAYER_SOLDIERS
	collision_mask = LAYER_WORLD | LAYER_SOLDIERS
	floor_snap_length = 0.35
	max_slides = 4
	floor_max_angle = deg_to_rad(50.0)
	health = $Health as HealthComponent
	health.died.connect(_on_health_died)
	health.damaged.connect(func(amount: float, source: Node) -> void: _on_damaged(amount, source))
	visual = SoldierVisual.new()
	visual.name = "Visual"
	add_child(visual)
	visual.setup(faction)
	_body_yaw = look_yaw
	visual.rotation.y = _body_yaw
	weapons = WeaponHolder.new()
	weapons.name = "Weapons"
	add_child(weapons)


## Gives the soldier its weapons. The first one is drawn. e.g. [&"katana", &"matchlock"].
func equip_loadout(loadout: Array[StringName]) -> void:
	weapons.setup(self, loadout)


## Short shove (lunges, knockback). Decays quickly.
func push(v: Vector3) -> void:
	v.y = 0.0
	_impulse += v


static var prof_move_us := 0
static var prof_slide_us := 0


func _physics_process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	_physics_body(delta)
	prof_move_us += Time.get_ticks_usec() - t0


func _physics_body(delta: float) -> void:
	if not alive:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
		velocity.y -= _gravity * delta
		move_and_slide()
		return
	protected_for = maxf(0.0, protected_for - delta)
	_move(delta)
	_turn(delta)
	_body_sounds(delta)
	visual.set_locomotion(Vector2(velocity.x, velocity.z).length(), is_on_floor())
	if global_position.y < kill_height:
		die(null)


func _move(delta: float) -> void:
	var dir := move_dir
	dir.y = 0.0
	if dir.length() > 1.0:
		dir = dir.normalized()
	var sprinting := wants_sprint and dir.length() > 0.3 and speed_scale >= 1.0
	var top := (sprint_speed if sprinting else run_speed) * speed_scale
	var target := dir * top
	var accel := acceleration if is_on_floor() else acceleration * air_control
	# Controlled movement and short pushes (lunges, knockback) are kept apart so pushes decay
	# on their own instead of feeding back into the acceleration.
	_move_vel = _move_vel.move_toward(target, accel * delta)
	velocity.x = _move_vel.x + _impulse.x
	velocity.z = _move_vel.z + _impulse.z
	_impulse = _impulse.move_toward(Vector3.ZERO, 22.0 * delta)
	if is_on_floor():
		if wants_jump:
			velocity.y = jump_velocity
			AudioManager.play(&"land", global_position, -6.0, 1.25)
	else:
		velocity.y -= _gravity * delta
	wants_jump = false
	var t0 := Time.get_ticks_usec()
	if half_rate_physics:
		_half_frame = not _half_frame
		if _half_frame:
			velocity *= 2.0  # cover two frames' distance in one step
			move_and_slide()
			velocity *= 0.5
	else:
		move_and_slide()
	prof_slide_us += Time.get_ticks_usec() - t0


func _turn(delta: float) -> void:
	var target := _body_yaw
	var flat := Vector2(velocity.x, velocity.z)
	if not is_nan(facing_override):
		target = facing_override
	elif face_look:
		target = look_yaw
	elif flat.length() > 0.6:
		target = atan2(-velocity.x, -velocity.z)
	_body_yaw = lerp_angle(_body_yaw, target, 1.0 - exp(-turn_speed * delta))
	visual.rotation.y = _body_yaw


func _body_sounds(delta: float) -> void:
	var on_floor := is_on_floor()
	var audible := AudioManager.listener_position().distance_squared_to(global_position) < 900.0  # 30 m
	if on_floor:
		var speed := Vector2(velocity.x, velocity.z).length()
		_stride += speed * delta
		var stride_len := 1.9 if speed > run_speed + 0.5 else 1.5
		if speed > 0.8 and _stride >= stride_len:
			_stride = 0.0
			if audible:
				AudioManager.play(&"footstep", global_position, 0.0 if speed > 3.0 else -5.0)
		if audible and not _was_on_floor and _air_time > 0.35:
			AudioManager.play(&"land", global_position)
		_air_time = 0.0
	else:
		_air_time += delta
	_was_on_floor = on_floor


## Applies damage from `source` (a Soldier, or null for the world). Returns damage dealt.
func take_damage(amount: float, source: Node = null, weapon_kind: StringName = &"") -> float:
	if not alive or (protected_for > 0.0 and source != null):
		return 0.0
	var dealt := health.take_damage(amount, source)
	if dealt > 0.0 and source:
		Events.damage_dealt.emit(source, self, dealt, weapon_kind)
	return dealt


func die(killer: Node) -> void:
	if not alive:
		return
	if health.current > 0.0:
		health.current = 0.0
		health.changed.emit(0.0, health.max_health)
	alive = false
	deaths += 1
	if killer is Soldier and killer != self:
		(killer as Soldier).kills += 1
	collision_layer = 0  # corpses don't block the living or stop bullets
	move_dir = Vector3.ZERO
	weapons.on_death()
	facing_override = NAN
	speed_scale = 1.0
	face_look = false
	visual.die()
	AudioManager.play(&"death_cry", head_position())
	get_tree().create_timer(0.7, false).timeout.connect(func() -> void:
		if is_instance_valid(self) and not alive:
			AudioManager.play(&"body_fall", global_position))
	died.emit(self, killer)
	Events.soldier_killed.emit(self, killer)


## Brings the soldier back at a spawn transform with full health.
func respawn_at(xform: Transform3D) -> void:
	global_transform = Transform3D(Basis.IDENTITY, xform.origin)
	look_yaw = xform.basis.get_euler().y
	_body_yaw = look_yaw
	look_pitch = 0.0
	velocity = Vector3.ZERO
	move_dir = Vector3.ZERO
	alive = true
	collision_layer = LAYER_SOLDIERS
	health.restore_full()
	protected_for = SPAWN_PROTECTION
	visual.reset()
	visual.rotation.y = _body_yaw
	_impulse = Vector3.ZERO
	_move_vel = Vector3.ZERO
	weapons.on_respawn()
	_was_on_floor = true
	_air_time = 0.0
	respawned.emit(self)
	Events.soldier_spawned.emit(self)


func is_alive() -> bool:
	return alive


func head_position() -> Vector3:
	return global_position + Vector3(0, 1.65, 0)


func chest_position() -> Vector3:
	return global_position + Vector3(0, 1.25, 0)


## Unit vector of where the soldier is looking (yaw + pitch).
func look_direction() -> Vector3:
	return Basis.from_euler(Vector3(look_pitch, look_yaw, 0.0)) * Vector3.FORWARD


## Flat forward of the body.
func body_forward() -> Vector3:
	return Basis(Vector3.UP, _body_yaw) * Vector3.FORWARD


func _on_damaged(amount: float, source: Node) -> void:
	damaged.emit(self, amount, source)
	if health.current > 0.0:
		AudioManager.play(&"hurt", head_position())
		visual.hit_react()


func _on_health_died(killer: Node) -> void:
	die(killer)
