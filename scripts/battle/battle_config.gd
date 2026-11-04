class_name BattleConfig
extends Resource
## Match rules in one place. Edit data/battle/default_battle.tres (or make variants) to tune.

@export_group("Armies")
## Soldiers per faction, including the player on the player's side.
@export_range(1, 128) var soldiers_per_faction := 16
## Fraction of AI soldiers carrying a matchlock (they also carry a katana).
@export_range(0.0, 1.0) var ranged_fraction := 0.4
@export_range(1, 12) var squad_size := 4
## AI decision rate per soldier (staggered across frames).
@export var ai_think_hz := 5.0
## Seconds between squad objective reassignments.
@export var squad_reassign_interval := 4.0
## How many AI may fight the player in melee at the same time.
@export var max_player_attackers := 2
## 0..1: AI accuracy and reaction quality.
@export_range(0.0, 1.0) var ai_skill := 0.55

@export_group("Respawn")
@export var player_respawn_delay := 5.0
@export var ai_respawn_delay := 6.0

@export_group("Conquest")
@export var starting_tickets := 150
## Ticket bleed per second when one faction holds more objectives (per objective of difference).
@export var bleed_per_point := 0.25
## Seconds for one soldier to capture a neutral point; more soldiers capture faster.
@export var capture_time := 12.0
## Extra speed per additional soldier (0.25 = each extra soldier adds 25%), capped.
@export var capture_bonus_per_soldier := 0.25
@export var capture_max_multiplier := 2.5
## Tickets at which the low-tickets warning sounds.
@export var ticket_warning_at := 30
