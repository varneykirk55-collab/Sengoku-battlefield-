class_name KatanaWeapon
extends Weapon
## Katana: alternating light cuts (primary) and a slow heavy cut (secondary).
## Ported from Kengeki's AttackRunner + arc-sweep hit detection; one buffered follow-up attack.

enum Phase { NONE, STARTUP, ACTIVE, RECOVERY }

const LIGHT := [preload("res://data/weapons/katana_light_a.tres"), preload("res://data/weapons/katana_light_b.tres")]
const HEAVY := preload("res://data/weapons/katana_heavy.tres")
## Melee assist: swings snap toward an enemy inside this cone and range.
const ASSIST_ANGLE := deg_to_rad(40.0)
const ASSIST_EXTRA_RANGE := 1.2

var attack: AttackData
var phase: int = Phase.NONE
var phase_time := 0.0
var attack_yaw := 0.0
var combo := 0
var queued: AttackData = null
var hits_this_swing: Array[Soldier] = []
var swings := 0

var _candidates: Array[Soldier] = []
var _combo_reset := 0.0


func _init() -> void:
	kind = &"katana"
	display_name = "Katana"


func equip() -> void:
	super.equip()
	WeaponModels.put_katana_in_hand(self)
	soldier.visual.set_stance(&"katana")
	AudioManager.play(&"katana_draw", soldier.chest_position())


func unequip() -> void:
	cancel()
	super.unequip()
	WeaponModels.sheathe_katana(self)


func primary(pressed: bool) -> void:
	if pressed:
		_request(LIGHT[combo % 2])


func secondary(pressed: bool) -> void:
	if pressed:
		_request(HEAVY)


func busy() -> bool:
	return phase == Phase.STARTUP or phase == Phase.ACTIVE


func is_attacking() -> bool:
	return phase != Phase.NONE


## True during wind-up and the cut itself (when blades can clash).
func is_dangerous() -> bool:
	return phase == Phase.STARTUP or phase == Phase.ACTIVE


func reset() -> void:
	cancel()
	combo = 0


func status_text() -> String:
	return "Katana"


## Swing knocked aside by a clashing blade.
func knocked_aside() -> void:
	cancel()
	soldier.visual.hit_react()


func cancel() -> void:
	if phase != Phase.NONE:
		soldier.visual.cancel_action()
	phase = Phase.NONE
	attack = null
	queued = null
	_end_attack_state()


func _request(a: AttackData) -> void:
	if not equipped or not soldier.alive or holder.switching():
		return
	if phase == Phase.NONE:
		_start(a)
	elif phase == Phase.RECOVERY and phase_time >= attack.cancel_point:
		_start(a)
	else:
		queued = a  # one buffered follow-up


func _start(a: AttackData) -> void:
	attack = a
	queued = null
	phase = Phase.STARTUP
	phase_time = 0.0
	hits_this_swing.clear()
	swings += 1
	if a in LIGHT:
		combo += 1
	_combo_reset = 0.9
	attack_yaw = _assisted_yaw()
	soldier.protected_for = 0.0
	soldier.facing_override = attack_yaw
	soldier.speed_scale = a.move_scale
	soldier.visual.play_action(a.animation, a.total_time())
	AudioManager.play(a.swing_sound, soldier.chest_position())
	Events.combat_noise.emit(soldier.global_position, 0.3)


func tick(delta: float) -> void:
	if phase == Phase.NONE:
		_combo_reset -= delta
		if _combo_reset <= 0.0:
			combo = 0
		return
	var prev := phase_time
	phase_time += delta
	match phase:
		Phase.STARTUP:
			if phase_time >= attack.startup:
				phase = Phase.ACTIVE
				phase_time = 0.0
				_open_hit_window()
		Phase.ACTIVE:
			var len := maxf(attack.active, 0.001)
			_sweep(clampf(phase_time / len, 0.0, 1.0))
			if phase == Phase.ACTIVE and phase_time >= attack.active:
				phase = Phase.RECOVERY
				phase_time = 0.0
		Phase.RECOVERY:
			if queued and phase_time >= attack.cancel_point:
				_start(queued)
			elif phase_time >= attack.recovery:
				phase = Phase.NONE
				attack = null
				_end_attack_state()


func _open_hit_window() -> void:
	var fwd := Basis(Vector3.UP, attack_yaw) * Vector3.FORWARD
	soldier.push(fwd * attack.lunge_speed)
	_candidates = Combat.soldiers_near(soldier, soldier.global_position + fwd * attack.reach * 0.5 + Vector3.UP, attack.reach + 0.6)
	_candidates.erase(soldier)


## Hits every enemy inside the arc swept so far (from sweep_from toward sweep_to).
func _sweep(progress: float) -> void:
	var current := lerpf(attack.sweep_from, attack.sweep_to, progress)
	var lo := minf(attack.sweep_from, current)
	var hi := maxf(attack.sweep_from, current)
	var fwd := Basis(Vector3.UP, attack_yaw) * Vector3.FORWARD
	var right := fwd.cross(Vector3.UP)
	for c in _candidates:
		if hits_this_swing.has(c) or not c.alive or not Combat.are_enemies(soldier, c):
			continue
		if attack.max_targets > 0 and hits_this_swing.size() >= attack.max_targets:
			return
		var to := c.global_position - soldier.global_position
		var dy := to.y
		to.y = 0.0
		var dist := to.length()
		if dist > attack.reach + 0.35 or dy < attack.height_min - 1.0 or dy > attack.height_max:
			continue
		var angle := rad_to_deg(atan2(to.dot(right), to.dot(fwd))) if dist > 0.05 else 0.0
		if angle < lo - 12.0 or angle > hi + 12.0:
			continue
		hits_this_swing.append(c)
		var result := Combat.melee_strike(soldier, c, attack, to.normalized() if dist > 0.05 else fwd)
		if result == &"clash":
			return
		if soldier.is_player and soldier.controller is PlayerController:
			(soldier.controller as PlayerController).add_shake(attack.camera_shake)


## Yaw for the swing: the look direction, nudged onto a nearby enemy (melee assist).
func _assisted_yaw() -> float:
	var look_fwd := Basis(Vector3.UP, soldier.look_yaw) * Vector3.FORWARD
	var reach: float = HEAVY.reach + ASSIST_EXTRA_RANGE
	var best: Soldier = null
	var best_score := INF
	for c in Combat.soldiers_near(soldier, soldier.global_position + Vector3.UP, reach):
		if c == soldier or not Combat.are_enemies(soldier, c):
			continue
		var to := c.global_position - soldier.global_position
		to.y = 0.0
		var ang := look_fwd.angle_to(to.normalized()) if to.length() > 0.05 else 0.0
		if ang > ASSIST_ANGLE:
			continue
		var score := to.length() + ang * 2.0
		if score < best_score:
			best_score = score
			best = c
	if best:
		var d := best.global_position - soldier.global_position
		return atan2(-d.x, -d.z)
	return soldier.look_yaw


func _end_attack_state() -> void:
	if soldier:
		soldier.facing_override = NAN
		soldier.speed_scale = 1.0
