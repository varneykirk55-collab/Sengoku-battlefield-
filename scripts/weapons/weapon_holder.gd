class_name WeaponHolder
extends Node
## A soldier's loadout. Controllers call primary/secondary/reload/switch; the holder routes
## them to the current weapon and handles the short switch delay.

signal weapon_changed(weapon: Weapon)

const SWITCH_TIME := 0.45

var soldier: Soldier
var weapons: Array[Weapon] = []
var index := 0
## Returns [origin: Vector3, direction: Vector3] for shots. Set by the controller
## (player: the camera's crosshair ray; AI: eye toward its target).
var aim_provider: Callable

var _switch_left := 0.0


func setup(s: Soldier, loadout: Array[StringName]) -> void:
	soldier = s
	for k in loadout:
		var w: Weapon
		match k:
			&"katana":
				w = KatanaWeapon.new()
			&"matchlock":
				w = MatchlockWeapon.new()
		if w:
			w.name = String(k).capitalize()
			add_child(w)
			w.setup(s, self)
			weapons.append(w)
	# Every katana starts sheathed; the first weapon is drawn.
	for w in weapons:
		if w is KatanaWeapon:
			WeaponModels.sheathe_katana(w)
	if not weapons.is_empty():
		weapons[0].equip()


func current() -> Weapon:
	return weapons[index] if index < weapons.size() else null


func has(kind: StringName) -> bool:
	return weapons.any(func(w: Weapon) -> bool: return w.kind == kind)


func get_weapon(kind: StringName) -> Weapon:
	for w in weapons:
		if w.kind == kind:
			return w
	return null


func switching() -> bool:
	return _switch_left > 0.0


func is_aiming() -> bool:
	var w := current()
	return w != null and w.is_aiming()


func primary(pressed: bool) -> void:
	if current() and soldier.alive:
		current().primary(pressed)


func secondary(pressed: bool) -> void:
	if current() and soldier.alive:
		current().secondary(pressed)


func reload() -> void:
	if current() and soldier.alive:
		current().reload()


func switch_next() -> void:
	if weapons.size() > 1:
		select((index + 1) % weapons.size())


func select_kind(kind: StringName) -> void:
	for i in weapons.size():
		if weapons[i].kind == kind:
			select(i)
			return


func select(i: int) -> void:
	if i == index or i < 0 or i >= weapons.size() or not soldier.alive:
		return
	if current() and current().busy():
		return
	if current():
		current().unequip()
	index = i
	current().equip()
	_switch_left = SWITCH_TIME
	weapon_changed.emit(current())


func aim_ray() -> Array:
	if aim_provider.is_valid():
		return aim_provider.call()
	return [soldier.head_position(), soldier.look_direction()]


func on_death() -> void:
	for w in weapons:
		if w is KatanaWeapon:
			(w as KatanaWeapon).cancel()
		if w is MatchlockWeapon:
			(w as MatchlockWeapon).aiming = false


func on_respawn() -> void:
	if current():
		current().unequip()
	for w in weapons:
		w.reset()
	index = 0
	_switch_left = 0.0
	if current():
		current().equip()
	weapon_changed.emit(current())


func _physics_process(delta: float) -> void:
	_switch_left = maxf(0.0, _switch_left - delta)
	for w in weapons:
		w.tick(delta)
