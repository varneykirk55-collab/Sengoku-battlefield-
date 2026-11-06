# SENGOKU Bot 1 — REPAIR Phase 4 (locomotion) + Phase 5 light pass
Date: 2026-11-06 (EST) · Branch `character-development` · no merge to main
Clip-only changes. No bone renamed or reparented (weapon_r/l, katana_sheath, musket_back, musket_ctrl untouched, socket keys stay identity). Same 9 clip names, 67 bones, same GLB path, mesh/materials unchanged, so red/blue stay compatible. soldier.gd speeds (run 4.6 / sprint 6.8), soldier_visual.gd, and Bill's weapon/combat files were NOT touched.

## Causes found
1. **Run cadence far too fast.** The Run clip was 16 f (0.667 s). soldier_visual plays it at speed/2.6, so at 4.6 m/s that's about 1.77×, or **~5.3 steps/s** (a human run is about 3). That made legs "patter" and slide.
2. **Loop seam hitch.** Run/Walk's last key ≠ first key, and Godot's loop wrapped from f15 to f0 in a single frame (pelvis 0.815 to 0.807 m), giving a visible hitch on every cycle.
3. **Walk/Run blend phase mismatch.** The Walk cycle was 1.08 s and Run 0.67 s, so blending in the 2.4–4.4 m/s band mixed out-of-phase legs.
4. **Short stride.** The stance foot sweep was 0.45 m, which caused heavy foot slide at gameplay speed.

## Fixes
| Clip | Change |
|---|---|
| Run | Periodic Catmull-Rom retime 16 f to **28 f cycle (1.167 s) + seamless closing key**. Thigh swing ×1.35, calf ×1.15, foot ×1.1, upper arm ×1.1, spine_01 +4° forward lean (armoured weight) plus ×1.15 torso counter-rotation. Per-frame Root height correction keeps the stance foot on the ground (min foot z 0.087 m, no penetration). |
| Walk | Thigh ×1.25, calf ×1.1, +1.5° lean, seamless closing key (cycle 26 f, 1.083 s). This now nearly matches Run's cycle, so the walk↔run blend stays in phase. |
| Musket_Reload | First 18 f ease in from the Musket_Aim hold, last 30 f ease back to it. Max channel diff to the hold went from 0.52 to **0.000** at both ends, so reload now returns to a steady shouldered aim. |
| Katana_Slash | End already equals f0 guard (diff 0.0), so it recovers into the ready_freeze guard cleanly. f0 guard is weapon_r forward-up ~48°, hands at 1.08 m centreline (chudan-like) and was kept, so Bill's ready_freeze pattern is unchanged. |
| Musket_Aim / Fire | Untouched (static hold verified: all keys constant; Fire 4.9 cm recoil kept). |

## Metrics (Blender, world)
| | Run before | Run after | Walk before | Walk after |
|---|---|---|---|---|
| Cycle | 16 f / 0.667 s | 28 f / 1.167 s | 25 f(+hitch) | 26 f seamless |
| foot z range (m) | 0.087–0.346 | 0.087–0.387 | 0.089–0.192 | 0.089–0.208 |
| foot fore/aft sweep (m) | 0.447 | 0.592 | 0.463 | 0.559 |
| pelvis bob (m) | 0.053 | 0.066 | 0.028 | 0.037 |
| cadence @4.6 m/s | ~5.3 steps/s | **~3.0 steps/s** | | |
| cadence @6.8 m/s (scale clamp 2.4) | ~7.2 | **~4.1** | | |

Remaining slide: at 4.6 m/s and 3 steps/s, each step is about 1.5 m, but the stance sweep is 0.59 m, so some slide remains (much less than before because cadence halved). Removing it fully needs either foot IK or a different speed→scale map in soldier_visual. That is a shared-file change, so I didn't make it.

## Recommendations (shared soldier_visual.gd, for Kirk/Bill approval, not applied)
- `loco` BlendSpace1D: set `sync = true` so walk/run phases lock during blending.
- Run scale: `speed/2.6` is fine with the new clip. Optionally clamp the max to 2.2 for sprint.
- Movement while aiming: aim_blend filters the spine_01 subtree + musket_ctrl, so legs come from loco and the upper body from the static Aim hold. The two don't fight. The +4° Run lean is on spine_01 and is overridden while aiming (the hold stays steady). The only additional coupling is the pelvis bob (6.6 cm) carrying the shouldered gun, which is natural for a run. Fade-in for stance changes could use an Xfade (≈0.15 s) instead of an instant `blend_amount` snap.

## Validation
- Godot 4.7.2 headless import OK. 67 bones, 9 clips; Run 1.1667 s, Walk 1.0833 s, Musket_Aim 1.5 s, Reload 11.125 s, Katana_Slash 1.75 s.
- Project test suite: **73 passed, 0 failed**. No gameplay capture was taken (parent handles Phase 7–8 footage).

## Files
- `04_animations/sengoku_samurai_anims.blend` (backup `.pre_p4.blend`), script `04_animations/work/repair_p4.py`, stats `04_animations/repair_p4_stats.json`
- `exports/sengoku_samurai_anims.glb/.fbx` (backup `exports/sengoku_samurai_anims.pre_p4.glb`)
- Game: `assets/characters/samurai/sengoku_samurai_anims.glb`
