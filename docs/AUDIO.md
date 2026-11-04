# Audio

Audio is a foundation system, not polish: every gameplay feature ships with its sound.

## Buses

`default_bus_layout.tres`, all routed to Master (hard limiter on Master):

| Bus | Used for |
|---|---|
| Music | menu / battle music, victory & defeat cues |
| Ambience | wind, field, distant battle and crowd beds, birds |
| SFX | katana, matchlock, impacts, footsteps, pain, death |
| UI | menus, hit/kill markers, objective cues, ticket warnings, respawn |
| Voice | soldiers' battle cries (reserved for future commands) |

Every bus has a volume slider in **Settings** (saved to `user://settings.cfg`).

## Playing sounds

```gdscript
AudioManager.play(&"matchlock_fire", muzzle.global_position)  # positional
AudioManager.play(&"objective_captured")                      # 2D cue
var bed := AudioManager.start_loop(&"battle_distant_loop")    # looping bed
AudioManager.stop_loop(bed)
Music.play(&"battle"); Music.play_stinger(&"victory", &"menu")
```

Gameplay code only names events. Each event's rules live in one table,
`scripts/audio/sound_catalog.gd`: bus, volume, priority, audible range, voice cap, cooldown,
and an optional distant variant (a matchlock beyond 70 m plays `matchlock_fire_far`).

## Large-battle limits

- 40 positional voices + 16 UI voices.
- Sounds beyond their audible range are skipped.
- Per-event caps (e.g. 10 footsteps, 8 gunshots) — at the cap, a nearer copy replaces a farther one.
- When all voices are busy, the least important voice (priority ÷ distance) is stolen; a new sound
  less important than everything playing is dropped.
- Counters in `AudioManager.stats` (played, culled, capped, stolen, dropped) feed profiling.

## Replacing placeholders

All current files are generated placeholders named `TEMP_*`.

- **Sound effect:** put `.wav`/`.ogg`/`.mp3` files in `audio/sfx/<event>/`, delete the `TEMP_`
  files. Every file in the folder becomes a random variation.
- **Music:** add `audio/music/<track>.ogg` (`menu`, `battle`, `victory`, `defeat`). A real file
  overrides `TEMP_<track>.wav` automatically.
- **New event:** add a folder and a line in `sound_catalog.gd`.

Regenerate placeholders with `python3 tools/audio/build_audio.py` (needs numpy + scipy).
The in-game **Sound Test** screen plays every event, loop and track.

## Known placeholder weaknesses

Synthesized voices (battle cries, crowd, pain) are the least convincing and are the first sounds to
replace with recordings. Music is a simple synthesized taiko / koto / shakuhachi sketch.
