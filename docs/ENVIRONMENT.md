# Environment overhaul (Bot 3 — `bot3/environment-overhaul`)

Cinematic expansion of the existing Sengoku conquest battlefield. The recognizable
A-farmstead / B-hill-shrine / C-river-outpost / N–S camps layout is preserved; only
terrain extent, materials, lighting, and environmental props changed.

## How to launch

- Editor: open `project.godot` in Godot **4.7.2**, F5 → Main Menu → **Enter the Battle**.
- Headless smoke: `tools/test.sh battlefield`
- Env screenshots: `SHOT_OUT_DIR=/tmp/env SHOT_TAG=after tools/env_screenshot.sh`
- Re-bake nav after layout edits: `tools/bake_navmesh.sh`
- Windows zip: `tools/export_windows.sh env-overhaul` → `dist/SengokuBattlefield-env-overhaul-Windows.zip`

## Map size

| | Before | After |
|---|---|---|
| `HALF_X` | 120 | **145** (~+21%) |
| `HALF_Z` | 150 | **180** (~+20%) |
| Playable footprint | 240 × 300 m | **290 × 360 m** |
| Objectives A/B/C | unchanged | unchanged |
| Camps (z=±128) | unchanged | unchanged |
| Seed | 1575 | 1575 |

## What changed

### Terrain (`scripts/battle/battlefield.gd`)
- Stronger rolling hills on the flanks (four secondary Gaussians) plus mild mid-frequency undulation.
- Dirt **roads** (vertex-color paths) linking camps ↔ A/B/C; roads slightly flattened.
- Stream **water ribbon** (translucent, no collision) following the existing valley.
- Edge berms scaled with the new bounds; invisible walls still just inside.

### Materials
- Per-vertex ground palette: deep greens, warm earth, sun-warmed highlights, trampled dirt, stream bed.
- Terrain material: NoiseTexture2D albedo ramp + normal map + light AO (not a global saturation crank).
- Wood / stone helpers use triplanar noise (+ stone normals). Thatch, bamboo, foliage variants added.
- Nobori / maku banners use more saturated faction colors.

### Lighting (`scripts/battle/prototype_ground.gd`)
- **Training Range unchanged**: still uses `make_environment()` / `make_sun()` (cooler, brighter).
- Battlefield uses **`make_battlefield_environment()` / `make_battlefield_sun()`**:
  - Golden-hour directional sun (~−28° elevation, warm Color(1.0, 0.78, 0.52), energy 1.65).
  - Procedural sky: deep zenith, amber horizon, warm fog / aerial perspective.
  - Soft glow + SSAO; 4-split shadows out to 160 m.

### Environmental props (all MultiMesh where repeated)
- More flank pines + lit crown tips; west grove near A; east grove retained.
- Bamboo groves (west of stream / near A) with sparse colliders (every 3rd stalk).
- Grass clump MultiMesh (shadows off).
- Extra camp palisade wings, hut, crates, flanking nobori (spawns untouched).
- Rocky formations on secondary hills; more open-field boulders (roads/objectives cleared).
- Distant silhouette pines outside the berm (no collision / no shadows).

### Navigation
- `data/maps/battlefield_nav.res` rebaked for the new bounds and colliders.
- Objectives, spawns, and combat lanes kept clear of decor.

## Before / after evidence

- `docs/env_before/before_*.png` — baseline at commit parent (main @ 70ff606 visuals).
- `docs/env_after/after_*.png` — same six fixed cameras after the overhaul.
- Optional: `docs/env_demo/` short frame sequence / video if produced.
- Capture tool: `tools/capture/env_capture.gd` + `tools/env_screenshot.sh`.

## Performance notes

- Repeated vegetation is MultiMesh; grass and distant pines cast no shadows.
- Bamboo colliders thinned (1/3); tree trunks still one collider each (as before).
- Single directional light; no extra real-time lights.
- Terrain remains one heightmap collider + one mesh.
- Large AI battles (16v16+) should stay in the same spirit as `docs/PERFORMANCE.md`;
  GPU cost of extra Multimeshes is modest vs. soldier meshes.
- Headless smoke after overhaul: `SIM_SECONDS=15 SIM_SOLDIERS=16 tools/sim.sh` →
  **avg 2.21 ms CPU/frame** (matches prior 16v16 baseline in PERFORMANCE.md).

## Preserved (do not regress)

- Objective positions A(−55,45) B(0,0) C(55,−45).
- Camp positions / spawn groups `spawn_0` / `spawn_1`.
- CapturePoint system, battle rules, soldier / weapon / combat scripts (untouched).
- `PrototypeGround` Training Range look.
- StaticBody layer 1; `wood` group on wooden props.

## Remaining issues / follow-ups

- Software (xvfb/OpenGL) screenshots understate bloom/SSAO vs. a real GPU.
- Grass density is conservative; can raise if owner's GPU allows.
- No Hunyuan / external mesh kits — still fully procedural primitives (copyright-safe).
- Windows export left on the box under `dist/` when built; laptop was offline at delivery.
