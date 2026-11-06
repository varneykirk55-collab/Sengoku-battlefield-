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

## v5 — KENGEKI courtyard integration + de-plastic materials/lighting (Bot 3)

Layout, terrain heights, spawns (`spawn_0`/`spawn_1`), objectives A/B/C, roads and gameplay are unchanged.
Source pack preserved; a **copied subset** lives in `assets/environment/courtyard/` (same `Courtyard/` / `Decorations/` structure, 27 GLBs, ~70 MB). No KENGEKI scripts/scenes imported.

### Import check (Godot 4.7.2, `tools/capture/glb_aabb.gd`)
All GLBs load; node scale = 1, base at y=0, real metres (no unapplied-scale bug):
yaguramon 15.3×10.4×8.3 · wall_segment_4m 4.0×4.7×1.6 · corner_turret 7.5×10.7×7.5 · barracks_nagaya 24×6×6 ·
storehouse_kura 8×7×6 · stone_lantern_toro 0.8×2.0×0.9 · rock_medium 1.5×1.0×1.2 · rock_formation_large 2.8×2.0×2.7 ·
tree_pine_kuromatsu 6.3×7×3.6 · tree_sakura 5.8×6×5.2 · tree_maple_momiji 4×5×4 · shrub_azalea 1.5×1.1×1.5.

### What replaced what
| Where | Before | v5 |
|---|---|---|
| Each camp | thatch hut | `storehouse_kura` (box collider) |
| Each camp (rear, 24 m behind spawns) | — | honjin enclosure: `main_gate_yaguramon_wide` + 6× `wall_segment_4m` + 2× `corner_turret` + 2 toro lanterns |
| Each camp outer flank | — | `barracks_nagaya` (long axis N–S, clear of roads) |
| Objective A farmstead | 2 huts | `storehouse_kura` + 1 hut, toro lantern, momiji + sakura heroes |
| Objective B shrine | torii, walls | + paired toro lanterns on the approach, azaleas, sakura/momiji outside ring |
| Objective C outpost | hut | `corner_turret` watch-yagura, kuromatsu hero, lantern |
| All cover/field rocks | 80-tri Blender rock | KENGEKI PBR rocks (`rock_medium`, `rock_formation_large`/`_b`), same collider |
Structures with LOD siblings switch to `_lod2` past 70 m (visibility ranges); others cull at 140–320 m. Scatter (pines/shrubs/grass/rocks) avoids new footprints via `_keepouts`.
Not used: `castle_keep_tenshu`, `main_hall_goten`, bridges (no stream crossing without route risk), pond stones.

### Plastic look fix
- Grass/foliage textures regraded (hue toward natural sap/olive, saturation ~0.6×, value ~0.75×; grass avg sRGB 43,174,42 → 92,125,68). Pine/leaf/grass cards same.
- Foliage materials: emission removed, rim 0.4→0.12, roughness ≥0.88, low specular, soft backlight on cards (`_tame_foliage`).
- Wood/stone/thatch base colours toned to KENGEKI `gb_*` guidance.
- `terrain_blend.gdshader` rewritten: removed grass saturation boost; height-aware layer transitions; macro lush/dry variation; per-layer normals (grass/dirt/rock) + roughness map; slope cavity AO; dirt desaturated toward umber.
Faction red/blue banners/curtains untouched.

### Lighting / grade (bright daytime kept)
Higher neutral-white sun (-52°, 1.4), 4-split shadows to 180 m with blend, crisper blur; colour ambient 0.45 + sky contribution; SSAO stronger (Forward+), SSIL on; glow reduced (0.06, no bloom); filmic white 4.5; adjustment contrast 1.07 / saturation 0.97 (no tint).

### Verification
- `tools/test.sh`: 73/73 pass (incl. full AI conquest match). Nav rebaked (`tools/bake_navmesh.sh`: 8028 polys).
- `tools/sim.sh`: 2.30 ms avg CPU/frame (v4 2.19; measured while a capture ran), 0/31 soldiers stuck in camp, all objectives contested.
- Captures now **Forward+ (Vulkan/llvmpipe)** — the game's real renderer. Earlier opengl3 captures mis-decoded sRGB and over-brightened textures. `docs/env_before_v5/` (tip e6695e1) vs `docs/env_after_v5/`, side-by-sides `docs/env_demo/compare_v5_*.png` (11 angles incl. architecture, grass close-up, gameplay eye height).

### Known issues
- No gameplay video this pass (software Vulkan ~10 s/frame).
- SSAO/SSIL only visible on Forward+ GPU; check on Windows.
- Pine LOD canopies still read a bit faceted at mid distance; C turret is visually heavy at the ring edge (collider outside the 12 m capture radius core).
- Near grass tufts are sparse; terrain texture carries most of the close-up.
