# Architecture

Approved plan (Godot 4.7.2, GDScript). This file grows as milestones land.

## Autoloads

| Name | Role |
|---|---|
| `Settings` | Persistent settings; applies bus volumes, fullscreen |
| `GameInput` | Registers all input actions (keyboard/mouse + gamepad) in code |
| `Events` | Global signal bus (kills, damage, objectives, tickets, match end) |
| `AudioManager` | Sound events, voice pools, limits, loops |
| `Music` | Two-deck crossfading music, stingers |

## Planned gameplay structure

- **Soldier** (`CharacterBody3D`) shared by player and AI: Health, Faction and WeaponHolder
  components. A PlayerController or AIController drives it, so combat rules are identical for both.
- **Weapons** are data (`Resource`): katana attacks (from Kengeki's AttackData / AttackRunner),
  matchlock timing (from ASHIGARU's musket, with a longer reload).
- **BattleDirector** (one per battle): squads of soldiers receive objective orders (attack/defend
  A/B/C), target selection through a spatial grid, staggered AI thinking (~5 Hz per soldier spread
  across frames), throttled path requests.
- **Conquest**: capture points (`Area3D`) with headcount-scaled capture and contesting, ticket
  bleed, reinforcement spawning with pooling. All rules in one config resource.
- **Audio**: gameplay emits sound events through `AudioManager`; the director's combat intensity
  drives the distant-battle and crowd beds.
- Renderer: Forward+ for the Windows game; screenshots in the cloud use the OpenGL fallback.

Original Kengeki and ASHIGARU repositories are reference-only; reused code is copied in and adapted.

## Combat (M2)

- `WeaponHolder` (on every Soldier) routes controller input (primary / secondary / reload / switch)
  to `KatanaWeapon` or `MatchlockWeapon`. Shots use `holder.aim_ray()`, supplied by the controller
  (player: crosshair ray; AI: eye toward target).
- `Combat` resolves katana contacts (arc sweep from Kengeki, 30% clash chance when both swing) and
  matchlock hitscan (falloff, headshots, no friendly fire, near-miss whiz).
- Tuning lives in `data/weapons/*.tres` (AttackData, FirearmData).
- Weapon models: player's katana is Katana.glb; AI weapons are procedural one-draw-call meshes.
  The matchlock rides the rig's `musket_ctrl` bone and is turned onto the line of sight when
  shouldered (the Rōnin aim clip holds it ~30 degrees off).
- `FX` autoload: pooled tracers, muzzle flash + smoke, blood, dust, sparks, hit-stop.
