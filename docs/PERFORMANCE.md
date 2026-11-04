# Performance findings

All numbers are **CPU only**, measured headless (no rendering) on the 2-core cloud VM used for
development, with `tools/sim.sh` and `tools/sim/spike_probe.tscn`. A desktop CPU should be
faster per core. **GPU cost has not been measured** — that needs the owner's PC.

## Frame cost (after M6 optimisations)

| Armies | Avg CPU / frame | AI think | AI steering | Movement (of which move_and_slide) | Animation |
|---|---|---|---|---|---|
| 16 v 16 | ~2.2 ms | — | — | — | — |
| 32 v 32 | 3.8 ms | 0.23 ms | 0.22 ms | 1.73 ms (1.35) | 0.35 ms |
| 64 v 64 | 7.3 ms | 0.58 ms | 0.44 ms | 3.40 ms (2.69) | 0.72 ms |

At 60 fps the frame budget is 16.7 ms, so the simulation leaves room for rendering at all three
sizes on this VM. Slow frames at 32 v 32: 2 of 2,370 frames above 8 ms, none above 12 ms — not
tied to game events (likely VM noise).

## What costs what

- **Godot's character controller (`move_and_slide`) is the biggest CPU cost** — about 20 µs per
  soldier per frame after optimisation (was 31 µs).
- AI decisions are cheap: staggered at 5 Hz per soldier, spatial grid, line-of-sight rays only for
  the best three candidates (~1 ms at 64 v 64 including steering).
- Animation is cheap **because of the LOD**: when it was disabled (every soldier animating every
  frame) a 64 v 64 frame rose from ~8.6 ms to ~13 ms.
- Soldier-to-soldier collision: no measurable cost.

## Optimisations in place

| Where | What |
|---|---|
| AI | Decisions staggered across frames; spatial grid (12 m cells) rebuilt every 3 frames; LOS rays capped at 3 per decision |
| Animation | AnimationTree advanced manually: every frame < 25 m, 30 Hz < 60 m, 15 Hz < 120 m, 8 Hz beyond |
| Physics | Beyond 70 m and not fighting: character controller every other frame at double step; max 4 slides |
| Rendering | Shadows off beyond 70 m; soldiers culled beyond 260 m (fog hides them); auto mesh LODs + shadow meshes on the Rōnin import; one shared animation library; two shared kimono materials; AI weapons are one-draw-call procedural meshes |
| Audio | 40 3D + 16 UI voices; range culling, per-event caps, priority stealing; footsteps skipped beyond 30 m before any audio lookup; listener position cached per frame |
| Pooling | Soldiers are never freed during a match — the dead are reused as reinforcements; effects are pooled |

## Risks for larger armies

1. **GPU**: each Rōnin is ~94k triangles in 14 meshes. 32 on screen is ~3 million triangles before
   LOD. If the owner's PC struggles, the first fixes are a lower-poly soldier model (the biggest
   win), a closer draw distance, or impostors for far soldiers.
2. **CPU beyond 64 v 64**: `move_and_slide` grows linearly. The next step would be cheaper movement
   for distant soldiers (navmesh-following without a physics body), then Godot servers / Mass-style
   batching — only if needed.

Reproduce: `SIM_SECONDS=60 SIM_SOLDIERS=32 tools/sim.sh`, or the per-system breakdown with
`SIM_SOLDIERS=64 tools/godot.sh --headless --path . --fixed-fps 60 res://tools/sim/spike_probe.tscn`.
