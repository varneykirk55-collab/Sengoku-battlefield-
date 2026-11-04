class_name MatchlockWeapon
extends Weapon
## Tanegashima matchlock: one shot, then a long staged reload (powder, ball, ramrod, priming,
## match). Hold secondary to aim (tighter spread, zoom, slower movement), primary to fire.
## Reload starts automatically after a shot and pauses (keeping its progress) if put away.

const DATA := preload("res://data/weapons/tanegashima.tres")

var data: FirearmData = DATA
var loaded := true
var reserve := 0
var reloading := false
var reload_elapsed := 0.0
var aiming := false
var shots_fired := 0
var last_shot: Dictionary = {}

var _ignition := -1.0
var _auto_reload_in := -1.0
var _next_step := 0
var _dry_cooldown := 0.0


func _init() -> void:
	kind = &"matchlock"
	display_name = "Tanegashima"


func setup(s: Soldier, h: WeaponHolder) -> void:
	super.setup(s, h)
	reserve = data.reserve_ammo
	WeaponModels.mount_matchlock(self)


func equip() -> void:
	super.equip()
	soldier.visual.set_stance(&"matchlock")
	AudioManager.play(&"weapon_raise", soldier.chest_position())
	if reloading:
		_resume_reload_animation()


func unequip() -> void:
	aiming = false
	_ignition = -1.0
	_auto_reload_in = -1.0
	if reloading:
		soldier.visual.cancel_action()
	soldier.visual.gun_aim_dir = Vector3.ZERO  # slung: follow the bone onto the back
	soldier.speed_scale = 1.0
	soldier.face_look = false
	super.unequip()
	AudioManager.play(&"weapon_lower", soldier.chest_position())


func reset() -> void:
	loaded = true
	reserve = data.reserve_ammo
	reloading = false
	reload_elapsed = 0.0
	aiming = false
	_ignition = -1.0
	_auto_reload_in = -1.0


func primary(pressed: bool) -> void:
	if not pressed or not equipped or not soldier.alive or holder.switching():
		return
	if _ignition >= 0.0:
		return
	if not loaded or reloading:
		if _dry_cooldown <= 0.0:
			AudioManager.play(&"matchlock_dry", soldier.chest_position())
			_dry_cooldown = 0.5
		return
	_ignition = data.ignition_delay  # the lit match drops into the pan...


func secondary(pressed: bool) -> void:
	aiming = pressed and equipped


func reload() -> void:
	if equipped and not loaded and not reloading and reserve > 0 and _ignition < 0.0:
		_start_reload()


func busy() -> bool:
	return _ignition >= 0.0


func is_aiming() -> bool:
	return aiming and equipped and not reloading and soldier.alive


func tick(delta: float) -> void:
	_dry_cooldown -= delta
	if not equipped:
		return
	if _ignition >= 0.0:
		_ignition -= delta
		if _ignition < 0.0:
			_fire()
	if _auto_reload_in >= 0.0:
		_auto_reload_in -= delta
		if _auto_reload_in < 0.0:
			reload()
	if reloading:
		reload_elapsed += delta
		var frac := reload_elapsed / data.reload_time
		while _next_step < FirearmData.RELOAD_STEPS.size() and frac >= FirearmData.RELOAD_STEPS[_next_step][0]:
			AudioManager.play(FirearmData.RELOAD_STEPS[_next_step][1], soldier.chest_position())
			_next_step += 1
		if reload_elapsed >= data.reload_time:
			reloading = false
			loaded = true
	soldier.speed_scale = data.reload_move_scale if reloading else (data.aim_move_scale if is_aiming() else 1.0)
	soldier.face_look = is_aiming() or _ignition >= 0.0
	# Shouldered: barrel follows the line of sight. Reloading: follow the clip (gun upright to ram).
	soldier.visual.gun_aim_dir = Vector3.ZERO if reloading else _gun_direction()


func _gun_direction() -> Vector3:
	if is_aiming() or _ignition >= 0.0 or soldier.face_look:
		return soldier.look_direction()
	# Carried at the ready: along the body's facing, slightly raised.
	return (soldier.body_forward() + Vector3(0, 0.15, 0)).normalized()


func status_text() -> String:
	if reloading:
		return "Reloading  %.1fs   +%d" % [data.reload_time - reload_elapsed, reserve]
	if loaded:
		return "Loaded   +%d" % reserve
	return ("Empty — R to reload   +%d" % reserve) if reserve > 0 else "No shot left"


func progress() -> float:
	if reloading:
		return reload_elapsed / data.reload_time
	return 1.0 if loaded else 0.0


## Current spread cone in degrees.
func spread() -> float:
	var s := data.spread_aimed if is_aiming() else data.spread_hip
	if Vector2(soldier.velocity.x, soldier.velocity.z).length() > 1.0:
		s += data.spread_moving * (0.4 if is_aiming() else 1.0)
	if not soldier.is_on_floor():
		s += data.spread_airborne
	return s


func muzzle_position() -> Vector3:
	var m := model.get_node_or_null("Muzzle") as Node3D if model else null
	return m.global_position if m else soldier.head_position()


func _fire() -> void:
	if not soldier.alive:
		return
	loaded = false
	shots_fired += 1
	soldier.protected_for = 0.0
	var aim: Array = holder.aim_ray()  # [origin, direction] chosen by the controller
	var origin: Vector3 = aim[0]
	var dir: Vector3 = _apply_spread(aim[1], spread())
	# Shots leave from the eye line so third-person shooting matches the crosshair.
	last_shot = Combat.hitscan(soldier, origin, dir, data)
	var muzzle := muzzle_position()
	AudioManager.play(&"matchlock_fire", muzzle)
	FX.muzzle(muzzle, dir)
	FX.tracer(muzzle, last_shot.position)
	_whiz_listener(origin, last_shot.position)
	soldier.visual.play_action(&"fire", 0.35)
	Events.combat_noise.emit(soldier.global_position, 1.0)
	if soldier.is_player and soldier.controller is PlayerController:
		(soldier.controller as PlayerController).add_shake(data.recoil_shake)
	if reserve > 0:
		_auto_reload_in = 0.6


func _start_reload() -> void:
	reloading = true
	reload_elapsed = 0.0
	reserve -= 1
	_next_step = 0
	aiming = false
	_resume_reload_animation()


func _resume_reload_animation() -> void:
	soldier.visual.play_action(&"reload", maxf(data.reload_time - reload_elapsed, 0.2))


func _apply_spread(dir: Vector3, degrees: float) -> Vector3:
	if degrees <= 0.0:
		return dir
	var r := deg_to_rad(degrees) * sqrt(randf())
	var a := randf() * TAU
	var side := dir.cross(Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT).normalized()
	var up := side.cross(dir).normalized()
	return (dir + (side * cos(a) + up * sin(a)) * tan(r)).normalized()


## A ball passing close to the listener makes a crack-and-whistle (not for your own shots).
func _whiz_listener(from: Vector3, to: Vector3) -> void:
	if soldier.is_player:
		return
	var ear := AudioManager.listener_position()
	var p := Combat.closest_point_on_segment(from, to, ear)
	if p.distance_to(ear) < 3.0 and p.distance_to(to) > 1.0:
		AudioManager.play(&"bullet_whiz", p)
