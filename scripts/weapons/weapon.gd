class_name Weapon
extends Node
## Base class for a soldier's weapons. WeaponHolder routes controller input here.

var soldier: Soldier
var holder: WeaponHolder
var kind: StringName = &"weapon"
var display_name := "Weapon"
var equipped := false
## The weapon's visible model (attached to a bone by the weapon).
var model: Node3D


func setup(s: Soldier, h: WeaponHolder) -> void:
	soldier = s
	holder = h


func equip() -> void:
	equipped = true


func unequip() -> void:
	equipped = false


func primary(_pressed: bool) -> void:
	pass


func secondary(_pressed: bool) -> void:
	pass


func reload() -> void:
	pass


func tick(_delta: float) -> void:
	pass


## True while the weapon must not be put away (mid-swing, match falling into the pan).
func busy() -> bool:
	return false


func is_aiming() -> bool:
	return false


## Restores ammo / state on respawn.
func reset() -> void:
	pass


## One line for the HUD.
func status_text() -> String:
	return ""


## 0..1 progress for the HUD bar, or -1 for none.
func progress() -> float:
	return -1.0
