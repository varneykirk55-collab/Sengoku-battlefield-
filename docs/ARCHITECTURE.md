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

## Battlefield (M3)

- `Battlefield` builds the map deterministically from code: 240 x 300 m heightmap (central hill
  under B, ridge, stream valley, edge berms), objectives A/B/C (`CapturePoint`), faction camps
  with spawn markers, and primitive cover (rocks, palisades, stone walls, huts, torii, pines).
- Navigation: `tools/bake_navmesh.sh` bakes `data/maps/battlefield_nav.res` offline; a test fails
  if the layout changes without a re-bake.
- `AmbienceDirector`: wind and field beds, birds from the treeline, gusts.
- `Battle.map` selects `battlefield` (default) or `test_ground` (flat field used by some tests).

## AI armies (M4)

- `BattleConfig` (`data/battle/default_battle.tres`): army size, ranged share, squad size, think
  rate, player attack tokens, AI skill, respawn delays, conquest rules.
- `BattleDirector`: spatial grid (12 m cells) rebuilt every 3 frames; staggered thinking
  (`ai_think_hz` per AI, spread across frames); squads of 4 reassigned every 4 s by objective value
  (unowned / threatened / enemy-held) with diminishing returns per extra squad; line-of-sight
  rays only for the best 3 candidates; max 2 AI on the player in melee; animation and shadow LOD
  by camera distance.
- `AIController`: ADVANCE (NavigationAgent3D path, straight-line fallback while navigation is
  still syncing), HOLD (slot around the objective), MELEE (close in, 1-3 cut combos, heavy cuts,
  pauses, side-steps), RANGED (aim time by skill and distance, distance-based aim error, reload,
  katana when rushed). Separation from nearby allies, stuck detection with sidesteps.
- `AmbienceDirector` battle beds: combat noise near the listener raises the crowd bed, far away
  the distant-battle bed.
- AI soldiers respawn at their camp after `ai_respawn_delay` (tickets arrive in M5).

## Conquest (M5)

- `ConquestMode` updates every 0.1 s: per-point progress -1..1 (faction 1 .. faction 0), capture
  speed scales with headcount (+25% per extra soldier, max 2.5x), neutralising runs at double
  speed, any enemy presence contests. Deaths cost one ticket; the side holding fewer points
  bleeds `bleed_per_point` per point of difference per second. Zero tickets ends the match.
- Reinforcements: AI respawn at a safely held point half the time, otherwise at camp; the player
  prefers a held point.
- `ConquestHUD`: tickets, A/B/C strip, capture bar, Tab scoreboard, victory / defeat screen with
  Fight again / Return to menu. The match ends with a short slow-motion beat and a music stinger.
