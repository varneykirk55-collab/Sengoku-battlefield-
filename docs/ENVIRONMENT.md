# Environment overhaul (Bot 3 — `bot3/environment-overhaul`)

Polished stylized-realistic Sengoku battlefield (Ghost of Tsushima–aim richness and
atmosphere — not photoreal, not Hunyuan). Layout (A farmstead / B hill shrine /
C river outpost / N–S camps) is preserved.

## How to launch

- Editor: open `project.godot` in Godot **4.7.2**, F5 → Main Menu → **Enter the Battle**.
- Headless smoke: `tools/test.sh battlefield`
- Env screenshots: `SHOT_OUT_DIR=/tmp/env SHOT_TAG=after_v4 tools/env_screenshot.sh`
- Re-bake nav after layout edits: `tools/bake_navmesh.sh`
- Windows zip: `tools/export_windows.sh env-overhaul` → `dist/SengokuBattlefield-env-overhaul-Windows.zip`

## Map size

| | Original main | Current branch |
|---|---|---|
| `HALF_X` | 120 | **145** (~+21%) |
| `HALF_Z` | 150 | **180** (~+20%) |
| Playable footprint | 240 × 300 m | **290 × 360 m** |
| Objectives A/B/C | unchanged | unchanged |
| Camps (z=±128) | unchanged | unchanged |

Map footprint is frozen; v2–v4 only raise materials, lighting, and mesh density.

## Art direction (current)

**Target:** polished stylized-realistic — dense leaf-card canopies, rich trunks/branches,
detailed architecture, thick ground cover. Soft/GL headless captures understate GPU quality.

## Revision history

### v2 — palette + lighting fix

Kirk rejected v1: amber sun `Color(1.0, 0.78, 0.52)` + warm fog turned greens brown
(a global filter, not a material upgrade).

| | v1 (rejected) | v2 |
|---|---|---|
| Sun color | amber `(1.0, 0.78, 0.52)` | warm-white `(1.0, 0.96, 0.88)` |
| Sun angle | −28° (low golden) | −42° (clearer shadows) |
| Ambient | sky-driven warm | **COLOR** cool `(0.62, 0.7, 0.78)` @ 0.42 |
| Fog | amber `(0.92, 0.78, 0.58)` | cool haze `(0.78, 0.84, 0.9)`, lower density |
| Terrain | olive + yellow height tint | saturated greens; dirt only on roads/trampled |

Training Range still uses original cooler `make_environment` / `make_sun`.

### v3 — terrain shader + authored GLBs

- `assets/env/terrain_blend.gdshader` — vertex R/G/B = dirt/grass/rock blend.
- Blender-authored pine / hut / torii / shrub / rock GLBs under `assets/env/meshes/`.
- CPU `ImageTexture` albedo/normals (headless-safe; NoiseTexture2D hung headless).

### v4 — GoT-aim mesh density (current)

Drop any “intentionally low-poly” framing. Amplify:

- **Pines:** solid canopy plates + dense alpha-clip leaf cards (~1180 cards / ~8k verts hero;
  LOD ~300 cards). Richer bark segments + twigs.
- **Placement:** ≤110 hero pines, denser LOD forest on berms, denser shrubs/stream banks,
  ~3.8k grass-clump attempts + wind subset, more distant berm silhouettes.
- **Architecture:** denser hut / palisade kit modules / torii; camp wing palisades.
- **Foliage:** `foliage_wind.gdshader` on grass-wind pass; `grass_blade` / `pine_card` /
  `leaf_card` textures.
- Nav rebaked after collider-bearing prop changes.

## Evidence

- `docs/env_before/` — original washed prototype (pre-Bot3).
- `docs/env_after_v1/` — rejected brown/amber look (history).
- `docs/env_after_v2/` / `docs/env_after/` — v2 lighting fix.
- `docs/env_after_v3/` / `docs/env_before_v4/` — v3 baseline.
- `docs/env_after_v4/` — current dense pass (six fixed cameras).
- `docs/env_demo/compare_v3_v4_*.png` — v3 | v4 side-by-side.
- `docs/env_demo/env_after_v4_tour.mp4`, `docs/env_demo/gameplay_frames/aerial_v4.png`.
- Capture: `tools/capture/env_capture.gd` + `tools/env_screenshot.sh`.

## Performance

- Multimesh veg; grass/distant pines cast no shadows; single directional light.
- Hero pine count capped; LOD carries silhouette mass.
- Re-bake nav after prop collider changes: `tools/bake_navmesh.sh`.
- Aim: stay near PERFORMANCE.md budget under `tools/sim.sh`.

## Preserved

- Objectives, camps, spawns, CapturePoint, battle rules, soldier/weapon/combat scripts.
- StaticBody layer 1; `wood` group on wooden props.
- No merge to `main` from this branch without explicit Kirk approval.

## Remaining issues

- Software (xvfb/OpenGL) still understates alpha cards / normals vs a real GPU.
- Torii enrichment pass may still be thinner than hut/palisade density — further mesh
  detail welcome without changing footprint or combat.
