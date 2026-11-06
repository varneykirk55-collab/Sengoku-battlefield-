# SENGOKU Bot 1 — REPAIR Phases 7–8 (partial)

**Date:** 2026-11-06 ~08:25 America/New_York  
**Branch:** `character-development`  
**Commits:** `9845cd1` (musket hold + sockets) → `74777b1` (run/reload polish) → **`5fdbc58`** (soldier_visual sync + 0.15s stance xfade)

## soldier_visual.gd (Kirk-approved)

- `AnimationNodeBlendSpace1D.sync = true` on loco (Walk/Run stay in phase while blending).
- Stance/aim blend amounts ease over `STANCE_XFADE = 0.15` s instead of snapping.
- No speed changes; no weapon_models / combat script edits; GLB unchanged in this commit.

## Validation

- Headless Godot import of GLB: previously PASS on 74777b1 assets.
- Automated unit tests: run via `res://tests/test_runner.tscn` after this commit (see parent status).
- **Interactive playtest / before-after gameplay footage: NOT captured on this box** (no human play session). Kirk should F5 on `character-development` @ `5fdbc58` to confirm musket hold, katana sheath, and run feel.

## Remaining

- Foot slide vs move speed still needs IK or playback remapping (documented in Phase 4).
- FP kabuto hide still blocked by single `Samurai_GameMesh`.
- Bill should merge `5fdbc58` soldier_visual carefully into `bot2/combat-audio` and re-pull GLB from `74777b1` if not already.

## Definition of Done status

| Item | Status |
|------|--------|
| Musket no bounce | Fixed in GLB (`9845cd1`); headless track variance 0 |
| Katana not pelvis spike | Socket axes fixed (`9845cd1`) |
| Run more human | Cadence/stride polish (`74777b1`) |
| Stance blends smoother | `5fdbc58` |
| Red/blue compatible | Yes |
| In-game visual proof | **Pending Kirk playtest / capture** |
