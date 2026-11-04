# Testing

## How

- `tools/test.sh [filter]` — imports the project and runs `tests/unit/test_*.gd` headless.
- CI (`.github/workflows/ci.yml`) runs the same on every push, on a free Linux runner.
  A manual run with *export_windows* also builds the Windows zip as an artifact.
- `tools/verify_export.sh` — exports a Linux build with the same content as the Windows build and runs
  its self-check (all sound events and music found inside the packaged build).
- `tools/screenshot.sh` — renders a scene to PNG under a virtual display (software OpenGL).

## What the cloud can and cannot verify

| Verified in the cloud | Needs the owner on Windows |
|---|---|
| Scripts compile, scenes load | That the `.exe` launches |
| Game rules via automated tests | How controls and combat *feel* |
| Audio routing, limits, loops, music logic | How the audio actually *sounds* and is balanced |
| Packaged build contains and finds its audio | GPU frame rate |
| Layout via software-rendered screenshots | Gamepad on real hardware |

## Results log

### M0 — 2026-11-04

- 17/17 automated tests pass (`tools/test.sh`): buses and routing, every catalog event has audio,
  required feature sounds present, 3D vs 2D playback, distance culling, distant-gunshot variant,
  per-event caps, nearer-replaces-farther, cooldowns, priority voice stealing, loops, music
  crossfade, volume settings persist and drive buses, every action has PC + gamepad bindings,
  scenes load, menu boots with music and ambience, settings and sound test panels build.
- Windows export succeeds (`SengokuBattlefield.exe`, single file); Linux twin self-check:
  46/46 sound events and 4/4 music tracks found in the packaged build.
- Main menu screenshot checked (software rendering).
- Not verified: audio heard by a person, the Windows `.exe` launching.
- Known headless-only noise: Godot reports a few audio playbacks "still in use at exit" when run
  headless (the dummy audio driver never runs the mixer that releases them). Tests are unaffected.
