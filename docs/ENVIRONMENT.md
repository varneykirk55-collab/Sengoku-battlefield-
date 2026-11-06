# Environment overhaul (Bot 3 — `bot3/environment-overhaul`)

Cinematic expansion + visual polish of the existing Sengoku conquest battlefield.
Layout (A farmstead / B hill shrine / C river outpost / N–S camps) is preserved.

## How to launch

- Editor: open `project.godot` in Godot **4.7.2**, F5 → Main Menu → **Enter the Battle**.
- Headless smoke: `tools/test.sh battlefield`
- Env screenshots: `SHOT_OUT_DIR=/tmp/env SHOT_TAG=after_v2 tools/env_screenshot.sh`
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

**v2 did not expand the map further** — only materials, lighting, and presentation.

## v2 revision (palette + lighting fix)

Kirk rejected v1: amber sun `Color(1.0, 0.78, 0.52)` + warm fog/horizon turned greens brown
(a global filter, not a material upgrade).

### Root cause fixed

| | v1 (rejected) | v2 |
|---|---|---|
| Sun color | amber `(1.0, 0.78, 0.52)` | warm-white `(1.0, 0.96, 0.88)` |
| Sun angle | −28° (low golden) | −42° (clearer shadows) |
| Ambient | sky-driven warm | **COLOR** cool `(0.62, 0.7, 0.78)` @ 0.42 |
| Fog | amber `(0.92, 0.78, 0.58)` | cool haze `(0.78, 0.84, 0.9)`, lower density |
| Sky horizon | orange amber | soft blue-white |
| Glow | strong | minimal |
| Terrain albedo | olive + yellow height tint | saturated greens; dirt only on roads/trampled |
| Foliage | dark olive | multi-shade greens + rim + light emission tips |
| Textures | mostly flat / GPU NoiseTexture | **CPU ImageTexture** albedo + normals (headless-safe) |

### Material notes (per-surface, not a filter)

- **Grass vertex colors:** true greens (high G) with moss/meadow patches; no yellow height wash.
- **Roads / camps / objectives:** dirt only where intended; strong green↔path contrast.
- **Terrain material:** CPU noise albedo (green-tinted), normal map, roughness map.
- **Wood:** oak albedo + triplanar CPU bark noise; dark beams for contrast.
- **Stone:** cool greys + faint moss in ramp + normals.
- **Foliage / bamboo / grass quads:** varied greens, rim lighting, slight emission on lit tips.
- **Faction banners:** boosted saturation so red/blue stay vivid under neutral light.

Training Range still uses original cooler `make_environment` / `make_sun`.

## Evidence

- `docs/env_before/` — original washed prototype (pre-Bot3).
- `docs/env_after_v1/` — rejected brown/amber look (kept for history).
- `docs/env_after_v2/` + `docs/env_after/` — current v2 (same six cameras).
- `docs/env_demo/compare_orig_v2_*.png` — original | v2.
- `docs/env_demo/compare_v1_v2_*.png` — rejected v1 | v2.
- Capture: `tools/capture/env_capture.gd` + `tools/env_screenshot.sh`.

## Performance

- Multimesh veg; grass/distant pines cast no shadows; single directional light.
- Navmesh unchanged in v2 (no collider layout change; no rebake).
- `SIM_SECONDS=15 SIM_SOLDIERS=16 tools/sim.sh` → **~2.1 ms CPU/frame** (in line with PERFORMANCE.md).

## Preserved

- Objectives, camps, spawns, CapturePoint, battle rules, soldier/weapon/combat scripts.
- StaticBody layer 1; `wood` group on wooden props.

## Remaining issues

- Software (xvfb/OpenGL) still understates normals/rim vs a real GPU.
- Low-poly primitive art direction remains; further leaps need authored meshes or custom shaders (not Hunyuan).
- Grass quads help at mid distance; ground still benefits from a real grass shader later.
- Merge to `main` needs Kirk’s approval.
