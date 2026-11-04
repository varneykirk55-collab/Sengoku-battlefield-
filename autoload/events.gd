extends Node
## Global signal bus. Systems announce what happened here; HUD, audio and the battle
## director listen, so gameplay code never needs a direct reference to them.

## A soldier (player or AI) was killed. `killer` may be null (fall, out of bounds).
signal soldier_killed(victim: Node, killer: Node)
## A soldier spawned or respawned.
signal soldier_spawned(soldier: Node)
## Damage was dealt. Used for hit markers and battle-intensity tracking.
signal damage_dealt(attacker: Node, victim: Node, amount: float, weapon_kind: StringName)
## Combat happened at a point (swing, shot, clash). Feeds the distant-battle ambience.
signal combat_noise(position: Vector3, loudness: float)
## Objective ownership/capture state changed.
signal objective_changed(objective: Node)
## A faction captured an objective.
signal objective_captured(objective: Node, faction: int)
## A faction's tickets changed.
signal tickets_changed(faction: int, tickets: int)
## The match ended. `winner` is a faction id, or -1 for a draw.
signal match_ended(winner: int)
