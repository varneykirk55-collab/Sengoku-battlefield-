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

### M1 — 2026-11-04

- 27/27 tests pass. New (player, driven through real input actions): battle spawns the player on the
  ground with the third-person camera, battle music and ambience; forward input runs in the camera
  direction with footsteps; sprint is clearly faster than running; jump height and landing sound;
  first-person toggle at eye height with head meshes hidden; damage with hurt sound and HUD update;
  death (death cry, body fall, corpse stops colliding, outside view, death panel, no movement) and
  respawn after the delay (full health, respawn cue, first-person preference restored); falling out
  of the world kills; an upper-body slash plays while running; pause menu pauses and resumes.
- Screenshots checked: third person, first person, facing, faction banners, running slash layering.
- Not verified: how movement and cameras feel with a real mouse/gamepad.

### M2 — 2026-11-04

- 42/42 tests pass, three consecutive runs. New (combat): player spawns with katana drawn and matchlock
  slung; light cut hits for 34 with swing / hit / hurt / hit-marker sounds; three light cuts kill
  (kill credited, kill marker, death cry); heavy cut deals nothing during wind-up then 75; no
  friendly fire and no hits behind; melee assist turns a cut onto an enemy ~29 degrees off;
  switching moves the katana to the hip (scabbard shown, blade hidden) with raise / draw sounds;
  switching is blocked mid-swing; aimed matchlock shot deals 85 at 20 m with gunshot and impact
  sounds; reload starts automatically, takes ~9 s, plays all five reload steps, dry-clicks if you
  fire early, and uses one ball from the reserve; headshots kill; damage falloff with distance;
  reload progress pauses while the katana is out and resumes; no friendly fire from bullets;
  blades clash; an enemy ball passing near the player whizzes.
- The test script now also fails on any GDScript runtime error printed during the run.
- Packaged-build self-check (Linux twin of the Windows build): all audio found; a scripted katana
  cut and matchlock shot land inside the exported game, 16 sounds played. PASS.
- Screenshots checked: katana in hand (scabbard hidden), sheathed at the hip, matchlock shouldered
  along the line of sight, slung on the back, AI soldiers' procedural weapons.
- Windows build: `SengokuBattlefield-M2-Windows.zip` exported. Not launched on Windows.
- Not verified: combat feel, hit-stop and camera shake strength, audio balance.
