class_name AttackData
extends Resource
## One katana technique. Ported from Kengeki's AttackData (block/parry/stamina fields removed:
## battlefield melee is fast and direct). Timing runs startup -> active (hit window) -> recovery.

@export var id: StringName = &"attack"
## Upper-body clip (SoldierVisual.CLIP key) stretched over the whole attack.
@export var animation: StringName = &"slash"

@export_group("Timing")
@export var startup: float = 0.15
@export var active: float = 0.12
@export var recovery: float = 0.30
## Seconds into recovery after which the next attack may be queued.
@export var cancel_point: float = 0.08

@export_group("Damage")
@export var damage: float = 34.0
@export var knockback: float = 2.5

@export_group("Hit Shape")
## The blade sweeps from sweep_from to sweep_to (degrees, 0 = forward, + = attacker's right)
## over the active window. Targets inside the swept arc and within reach are hit once.
@export var reach: float = 2.3
@export var sweep_from: float = 70.0
@export var sweep_to: float = -70.0
@export var height_min: float = -0.6
@export var height_max: float = 1.0
## Max targets damaged by one swing (0 = unlimited).
@export var max_targets: int = 2

@export_group("Movement")
## Forward push at the start of the hit window (m/s).
@export var lunge_speed: float = 4.0
## Movement speed multiplier during the attack.
@export var move_scale: float = 0.6

@export_group("Feedback")
@export var swing_sound: StringName = &"katana_swing_light"
@export var hitstop: float = 0.04
@export var camera_shake: float = 0.15


func total_time() -> float:
	return startup + active + recovery
