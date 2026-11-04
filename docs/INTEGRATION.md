# Asset integration guide (Phase 2 preparation)

Where each kind of production asset plugs in. Originals (Kengeki, ASHIGARU) are never modified —
copy assets into this repository.

## Characters (Kengeki samurai, Hunyuan 3D, Tripo, AccuRig)

Code: `scripts/soldier/soldier_visual.gd`.

- `MODEL` — the character scene (GLB) used for every soldier.
- `CLIP` — maps game actions to clip names: idle, walk, run, slash (katana), aim / fire / reload
  (matchlock), hit, death. A new model needs clips for these (they can be retargeted).
- Bones the game uses by name: `spine_01` (upper-body layer starts here), `spine_03` (banner),
  `head`, `weapon_r` (katana in hand), `katana_sheath` (sheathed katana), `musket_ctrl`
  (matchlock — the clips move this bone between shoulder and back).
- `HEAD_MESHES` — meshes hidden in first person.
- The model must face +Z in the GLB (it is turned 180° to face Godot's -Z), use metres, and stand
  with feet at y = 0. Clips must be in-place (no root motion).

**AccuRig skeletons** use different bone names. Two options: (1) retarget the clips onto the Rōnin
rig in Blender before export, or (2) set up a Godot `BoneMap` with the humanoid profile at import and
add a name map in `SoldierVisual` for the six bones above. Option 1 is simplest for a first pass.
Kengeki's `kengeki_character_animated.glb` (AccuRig samurai) is not in git; copy it in when ready.

Faction colour is applied at runtime (kimono tint + sashimono), so one model serves both armies.

## Weapons

Code: `scripts/weapons/weapon_models.gd`.

- Player katana: `DETAILED_KATANA` (`assets/weapons/Katana.glb`). Blade along +X in the GLB;
  scabbard parts are recognised by name (`SCABBARD_PARTS`).
- AI katana and every matchlock are procedural (`_katana()`, `_matchlock()`); replace them by
  loading a GLB in `make_katana()` / `make_matchlock()`. Convention: blade / barrel along +Y of
  the mount, grip or cheek point at the origin, a `Muzzle` marker at the barrel end.
- Keep AI weapon models light (they appear 30+ times).

## Animations

Upper-body actions are stretched to gameplay timings (`play_action(action, duration)`), so clips
of any length work. Gameplay timing lives in `data/weapons/*.tres`, not in the clips.

## Environment (Sengoku structures, terrain)

Code: `scripts/battle/battlefield.gd` builds everything from primitives in helper functions
(`_hut`, `_torii`, `_palisade`, `_stone_wall`, `_rock`, `_build_camp`, trees). Replace a helper's
body with a GLB instance at the same transform. Add collision (`StaticBody3D`, layer 1; group
`wood` for wooden impact sounds). **After any layout change run `tools/bake_navmesh.sh`** — a test
fails if the saved navmesh is stale.

## Sound effects and music

See [AUDIO.md](AUDIO.md): drop files into `audio/sfx/<event>/` (remove the `TEMP_` files) or add
`audio/music/<track>.ogg`. No code changes. The Sound Test screen plays everything.
