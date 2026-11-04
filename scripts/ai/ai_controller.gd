class_name AIController
extends Node
## Brain of one AI soldier. Decides (think(), ~5 Hz, called by the BattleDirector) and steers
## every physics frame. States:
##   ADVANCE  move to the squad's objective (navmesh path), sprinting when no enemy is close
##   HOLD     stay on the objective, shuffling around a slot
##   MELEE    close in and cut: short combos, pauses between them, occasional heavy cuts
##   RANGED   matchlock: stop, aim, fire, then reload (switching to the katana if rushed)

enum State { ADVANCE, HOLD, MELEE, RANGED }

const MELEE_RANGE := 2.0
const MELEE_SEEK_RADIUS := 28.0
const RANGED_SEEK_RADIUS := 95.0
const RANGED_MIN := 7.0

var soldier: Soldier
var director: BattleDirector
var squad: Squad
var state: State = State.ADVANCE
var target: Soldier = null
var role: StringName = &"melee"
var skill := 0.55
var agent: NavigationAgent3D
var destination := Vector3.ZERO

var _cooldown := 0.0
var _combo_left := 0
var _aim_needed := 1.0
var _aim_time := 0.0
var _aim_error := Vector3.ZERO
var _strafe := 1.0
var _strafe_timer := 0.0
var _separation := Vector3.ZERO
var _stuck_time := 0.0
var _last_pos := Vector3.ZERO
var _detour := Vector3.ZERO
var _detour_time := 0.0
var _no_enemy_time := 0.0


func _ready() -> void:
	soldier = get_parent() as Soldier
	soldier.controller = self
	role = &"ranged" if soldier.weapons.has(&"matchlock") else &"melee"
	agent = NavigationAgent3D.new()
	agent.name = "Nav"
	agent.path_desired_distance = 1.2
	agent.target_desired_distance = 1.5
	agent.avoidance_enabled = false
	agent.path_max_distance = 6.0
	soldier.add_child(agent)
	soldier.weapons.aim_provider = _aim_ray
	soldier.died.connect(func(_s: Soldier, _k: Node) -> void: _on_died())
	_strafe = 1.0 if randf() < 0.5 else -1.0


## Decision step (called by the director at ~ai_think_hz).
func think() -> void:
	var t0 := Time.get_ticks_usec()
	_think_body()
	prof_think_us += Time.get_ticks_usec() - t0


func _think_body() -> void:
	var objective_pos := squad.objective.global_position if squad and squad.objective else soldier.global_position
	var seek := RANGED_SEEK_RADIUS if _gun_ready() else MELEE_SEEK_RADIUS
	var prev_target := target
	if target == null or not target.alive or target.global_position.distance_to(soldier.global_position) > seek * 1.2 or randf() < 0.15:
		target = director.find_target(soldier, seek, objective_pos)
	if target != prev_target and prev_target and prev_target.is_player:
		director.release_player_attack(self)
	_separation = _compute_separation()
	var prev_state := state
	if target:
		_no_enemy_time = 0.0
		var d := target.global_position.distance_to(soldier.global_position)
		if role == &"ranged" and _gun_ready() and d > RANGED_MIN and d < RANGED_SEEK_RADIUS:
			_equip(&"matchlock")
			state = State.RANGED
		else:
			if role == &"ranged" and d < 12.0:
				_equip(&"katana")
			state = State.MELEE if soldier.weapons.current() is KatanaWeapon else State.ADVANCE
	else:
		_no_enemy_time += 0.2
		if role == &"ranged" and _no_enemy_time > 2.0:
			_equip(&"matchlock")  # resume reloading / ready the gun once the area is clear
		destination = squad.slot_for(soldier) if squad else soldier.global_position
		var at_obj := squad != null and squad.objective != null and soldier.global_position.distance_to(squad.objective.global_position) < squad.objective.radius - 1.0
		state = State.HOLD if at_obj else State.ADVANCE
	if state == State.MELEE and prev_state != State.MELEE and target and target.global_position.distance_to(soldier.global_position) > 6.0 and randf() < 0.35:
		AudioManager.play(&"battle_cry", soldier.head_position())
	if state != State.RANGED:
		soldier.weapons.secondary(false)
		_aim_time = 0.0
	if state == State.ADVANCE or state == State.HOLD:
		if agent.target_position.distance_to(destination) > 2.0:
			agent.target_position = destination


## Profiling accumulators (microseconds), read by tools/sim.
static var prof_think_us := 0
static var prof_steer_us := 0


func _physics_process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	_physics_body(delta)
	prof_steer_us += Time.get_ticks_usec() - t0


func _physics_body(delta: float) -> void:
	if not soldier.alive:
		soldier.move_dir = Vector3.ZERO
		return
	_cooldown -= delta
	soldier.wants_sprint = false
	match state:
		State.ADVANCE:
			_steer_to(destination, delta, true)
		State.HOLD:
			_hold(delta)
		State.MELEE:
			_melee(delta)
		State.RANGED:
			_ranged(delta)
	_check_stuck(delta)


# ----------------------------------------------------------------------------- behaviours
func _hold(delta: float) -> void:
	var to := destination - soldier.global_position
	to.y = 0.0
	if to.length() > 1.5:
		_steer_to(destination, delta, false)
	else:
		soldier.move_dir = _separation
		if squad and squad.objective:
			_face(squad.objective.global_position + (soldier.global_position - squad.objective.global_position) * 3.0)


func _melee(delta: float) -> void:
	if target == null or not target.alive:
		state = State.ADVANCE
		return
	var to := target.global_position - soldier.global_position
	to.y = 0.0
	var d := to.length()
	var allowed := not target.is_player or director.request_player_attack(self)
	var katana := soldier.weapons.current() as KatanaWeapon
	_face(target.global_position)
	if d > MELEE_RANGE + 0.2 or not allowed:
		# Close in (or circle at a distance if waiting for a turn against the player).
		if not allowed and d < 5.0:
			soldier.move_dir = (to.normalized().cross(Vector3.UP) * _strafe * 0.6 - to.normalized() * 0.2 + _separation).limit_length(1.0)
		elif d < 14.0 and director.has_line_of_sight(soldier.chest_position(), target.chest_position()):
			soldier.move_dir = (to.normalized() + _separation * 0.5).limit_length(1.0)
			soldier.wants_sprint = d > 6.0
		else:
			_steer_to(target.global_position, delta, true)
		return
	# In range: short combos with pauses, side-stepping a little between them.
	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_timer = randf_range(0.8, 1.8)
		_strafe = -_strafe
	soldier.move_dir = (to.normalized().cross(Vector3.UP) * _strafe * 0.35 + _separation).limit_length(1.0)
	if katana == null or katana.is_attacking():
		return
	if _combo_left > 0:
		_combo_left -= 1
		katana.primary(true)
	elif _cooldown <= 0.0:
		if randf() < 0.22:
			katana.secondary(true)
			_combo_left = 0
		else:
			_combo_left = randi_range(1, 3) - 1
			katana.primary(true)
		_cooldown = lerpf(1.6, 0.6, skill) + randf_range(0.0, 0.6)


func _ranged(delta: float) -> void:
	if target == null or not target.alive:
		state = State.ADVANCE
		soldier.weapons.secondary(false)
		return
	var gun := soldier.weapons.current() as MatchlockWeapon
	if gun == null or not gun.loaded or gun.reloading:
		soldier.weapons.secondary(false)
		_steer_to(destination if destination != Vector3.ZERO else soldier.global_position, delta, false)
		return
	_face(target.chest_position())
	soldier.move_dir = _separation
	if not gun.aiming:
		soldier.weapons.secondary(true)
		_aim_time = 0.0
		var d := target.global_position.distance_to(soldier.global_position)
		_aim_needed = lerpf(1.6, 0.7, skill) + randf_range(0.0, 0.5) + d / 120.0
	_aim_time += delta
	if _aim_time >= _aim_needed and gun.busy() == false:
		_roll_aim_error()
		soldier.weapons.primary(true)
		soldier.weapons.secondary(false)
		_aim_time = 0.0


# ----------------------------------------------------------------------------- movement helpers
func _steer_to(point: Vector3, delta: float, allow_sprint: bool) -> void:
	var pos := soldier.global_position
	if agent.target_position.distance_to(point) > 2.0:
		agent.target_position = point
	var next := agent.get_next_path_position()
	var dir := next - pos
	dir.y = 0.0
	if dir.length() < 0.2:
		# No path yet (navigation still syncing) or already there: head straight for the point.
		dir = point - pos
		dir.y = 0.0
	if _detour_time > 0.0:
		_detour_time -= delta
		dir = dir.normalized() + _detour
	var flat_to := point - pos
	flat_to.y = 0.0
	if flat_to.length() < 0.8:
		soldier.move_dir = _separation
		return
	soldier.move_dir = (dir.normalized() + _separation).limit_length(1.0)
	soldier.wants_sprint = allow_sprint and flat_to.length() > 18.0 and target == null
	if target == null:
		_face(pos + dir)


func _face(point: Vector3) -> void:
	var d := point - soldier.global_position
	soldier.look_yaw = atan2(-d.x, -d.z)
	var flat := Vector2(d.x, d.z).length()
	soldier.look_pitch = atan2(point.y - soldier.head_position().y, maxf(flat, 0.1))


func _compute_separation() -> Vector3:
	var push := Vector3.ZERO
	for o in director.soldiers_near(soldier.global_position, 1.6, soldier.faction):
		if o == soldier:
			continue
		var away := soldier.global_position - o.global_position
		away.y = 0.0
		var dist := away.length()
		if dist > 0.01:
			push += away / dist * (1.6 - dist) / 1.6
	return push.limit_length(0.7)


func _check_stuck(delta: float) -> void:
	var moved := soldier.global_position.distance_to(_last_pos)
	_last_pos = soldier.global_position
	if soldier.move_dir.length() > 0.5 and moved < 0.6 * delta:
		_stuck_time += delta
		if _stuck_time > 1.2:
			# Blocked (rock, crowd): sidestep for a moment, then let the path take over again.
			_stuck_time = 0.0
			_detour = soldier.move_dir.cross(Vector3.UP).normalized() * (1.0 if randf() < 0.5 else -1.0)
			_detour_time = 0.9
	else:
		_stuck_time = maxf(0.0, _stuck_time - delta)


# ----------------------------------------------------------------------------- weapons
func _gun_ready() -> bool:
	var gun := soldier.weapons.get_weapon(&"matchlock") as MatchlockWeapon
	return gun != null and gun.loaded and not gun.reloading


func _equip(kind: StringName) -> void:
	if soldier.weapons.current() and soldier.weapons.current().kind != kind:
		soldier.weapons.select_kind(kind)


func _roll_aim_error() -> void:
	# Aim error grows with distance and shrinks with skill; ~1/3 of mid-range shots hit.
	var d := target.global_position.distance_to(soldier.global_position) if target else 30.0
	var spread := (0.25 + d * 0.022) * lerpf(1.6, 0.6, skill)
	_aim_error = Vector3(randf_range(-1, 1), randf_range(-0.6, 0.8), randf_range(-1, 1)).normalized() * randf() * spread


func _aim_ray() -> Array:
	var eye := soldier.head_position() - Vector3(0, 0.1, 0)
	if target == null:
		return [eye, soldier.look_direction()]
	return [eye, (target.chest_position() + _aim_error - eye).normalized()]


func _on_died() -> void:
	if director:
		director.release_player_attack(self)
	target = null
	state = State.ADVANCE
	_combo_left = 0
	soldier.weapons.secondary(false)
