# SENGOKU audio licenses

All audio under `audio/` is cleared for use in this project. Sources:

## Original procedural (this repo)
- Regenerated combat voices (`death_cry`, `hurt`, `battle_cry`, `body_fall`) and renamed
  former `TEMP_*` SFX/music: synthesized with `tools/audio/ashigaru_synth.py` /
  `tools/audio/build_audio.py` (numpy/scipy DSP). Original work, offered under **CC0 1.0**.
- Blade clash/block files carrying `kengeki` in the name: procedural placeholders originally
  produced for the owner’s Kengeki project; same synthesis pipeline / CC0 intent.

## Iron Crowns black-powder gunshots (same owner)
- `audio/sfx/matchlock_fire/matchlock_fire_ic_*.ogg`
- `audio/sfx/matchlock_fire_far/matchlock_fire_far_ic_*.ogg`

Copied from Iron Crowns (`ic_env/game/audio/sfx/musket_shot_*.ogg`,
`musket_volley_far_*.ogg`). Those files are **original procedural DSP** owned by the Iron
Crowns project (see IC `AUDIO_LICENSES.md`): no third-party samples, no AI audio services.
Reused here with the same owner’s approval for SENGOKU black-powder fire. Not Napoleonic
musket *meshes* — audio only.

## VFX textures
- `assets/vfx/soft_smoke.png`, `muzzle_flash.png`, `soft_tracer.png`, `soft_dust.png`:
  generated procedurally for this overhaul (CC0).

## Replacement policy
Drop new `.wav` / `.ogg` / `.mp3` into `audio/sfx/<event_id>/`. Every file in the folder is a
random variation. Prefer CC0 or owner-original assets; record additions in this file.
