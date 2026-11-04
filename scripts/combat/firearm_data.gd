class_name FirearmData
extends Resource
## Tuning for a matchlock (tanegashima). Hitscan with distance falloff and a long, staged reload.

@export var id: StringName = &"tanegashima"
@export var display_name := "Tanegashima"

@export_group("Damage")
@export var damage: float = 85.0
@export var headshot_multiplier: float = 2.5
## Full damage up to falloff_start; scales linearly down to falloff_min at falloff_end.
@export var falloff_start: float = 50.0
@export var falloff_end: float = 150.0
@export var falloff_min: float = 0.5
@export var max_range: float = 250.0

@export_group("Accuracy (degrees)")
@export var spread_aimed: float = 0.35
@export var spread_hip: float = 3.0
@export var spread_moving: float = 2.0
@export var spread_airborne: float = 4.0

@export_group("Handling")
## The lit match drops into the pan, then the charge goes off.
@export var ignition_delay: float = 0.08
@export var reload_time: float = 9.0
@export var reserve_ammo: int = 12
## Movement multipliers.
@export var aim_move_scale: float = 0.5
@export var reload_move_scale: float = 0.55
@export var recoil_shake: float = 0.45

## Reload steps: [time in seconds, sound event]. Times are scaled to reload_time.
const RELOAD_STEPS := [
	[0.06, &"reload_powder"],
	[0.27, &"reload_ball"],
	[0.45, &"reload_ram"],
	[0.55, &"reload_ram"],
	[0.72, &"reload_prime"],
	[0.9, &"reload_match"],
]


func damage_at(distance: float) -> float:
	if distance <= falloff_start:
		return damage
	var t := clampf((distance - falloff_start) / maxf(falloff_end - falloff_start, 0.01), 0.0, 1.0)
	return damage * lerpf(1.0, falloff_min, t)
