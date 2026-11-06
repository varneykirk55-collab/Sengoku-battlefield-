# SENGOKU Bot 1 — REPAIR Phases 2–3 Report
Date: 2026-11-06 (EST) · Branch: `character-development` (no merge to main)

## Phase 2 — Musket_Aim bounce: FIXED
Cause: Musket_Aim was a 1.5 s raise-to-shoulder clip played with LOOP_LINEAR, so every loop it snapped from shouldered back to low.
Fix (Blender, `04_animations/sengoku_samurai_anims.blend`): every Musket_Aim f-curve was replaced by the shouldered pose from the final frame (f36), held with CONSTANT keys at f0 and f36. The clip name, 1.5 s length and LOOPING contract are unchanged, and `soldier_visual.gd` was not touched.

| Metric | Before | After |
|---|---:|---:|
| musket_ctrl height range in Blender over the clip (loc[2]) | 0.302 m | **0.000 m** |
| Godot imported track, musket_ctrl local Y over 3 loops (271 samples @60 Hz): range | 0.0534 m | **0.0 m** |
| same: variance | 3.9e-4 m² | **0.0** |
| Musket_Fire start/end vs Aim hold (max channel diff) | — | 0.00025 (seamless) |

Musket_Fire still has a 4.9 cm recoil kick, which is intended, and it returns to the hold.
Known gap: Musket_Reload starts and ends in the lowered pose (max diff 0.53 vs the hold). It is a one-shot, so it can't cause a repeating bounce, but the return to aim is a blend rather than a match. It will be polished in Phase 5.

## Phase 3 — Katana sockets: FIXED (rest axes)
Causes: (1) The `katana_sheath` and `weapon_r`/`weapon_l` rest +Y pointed horizontally forward. (2) Every clip had a constant non-identity rotation key on those socket bones, which was a retarget artefact.
Fix: The rest bones were re-oriented and the socket rotation keys were zeroed in all 9 clips, so the rest axis now controls the socket. Parents are unchanged (pelvis / hand_r / hand_l), and no bones were renamed.

| Socket | +Y before (Godot, model rotated PI) | +Y after |
|---|---|---|
| katana_sheath (rest, Godot model space) | (0,0,1) horizontal | (0.12,−0.35,−0.93) |
| katana_sheath in game (Idle, rotated PI) | (0,0,−1) horizontal out of the hip | **(−0.12,−0.65,0.75)**: back and down about 41° along the left waist, hilt forward |
| weapon_r (rest) | (0,0,1) | (−0.25,0.46,0.85) out of the thumb side of the fist |
| weapon_r at guard (Katana_Slash f0, Blender world) | — | (−0.09,−0.66,0.75): blade forward and up about 48°, hand at 1.08 m centreline (chudan-like) |
| weapon_l | mirror of weapon_r | mirror of weapon_r |

The drawn sword follows weapon_r (hand), and the sheathed sword sits on katana_sheath at the waist. Verification was numeric (socket world axes in Blender and Godot). No helper meshes or weapon meshes were added.

## Export / validation
- 67 bones, the same 9 clip names, 49,998 tris unchanged, and the same materials/UVs, so red/blue textures stay compatible.
- Headless Godot 4.7.2 import passed. This is an import plus track sampling only, **not a gameplay playtest**.

## Files
- `04_animations/sengoku_samurai_anims.blend` (updated); backup `sengoku_samurai_anims.pre_repair.blend`
- `exports/sengoku_samurai_anims.glb` and `.fbx` (updated); backup `exports/sengoku_samurai_anims.pre_repair.glb`
- Scripts: `04_animations/work/repair_p2_3.py`, `repair_p3b.py`; stats in `04_animations/repair_p2_3_stats_pass1.json`, `repair_p3b_socket_world.json`
- Game: `assets/characters/samurai/sengoku_samurai_anims.glb` (only game file changed)
- Not touched: soldier_visual.gd, weapon_models.gd, matchlock/katana gameplay, run/sprint speeds.
