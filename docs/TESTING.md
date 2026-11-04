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

### M3 — 2026-11-04

- 50/50 tests pass. New (battlefield): objectives A, B, C on the ground and neutral, B on the hill;
  both camps have 5 grounded spawn points at opposite ends; the player spawns in the south camp and
  runs across the terrain; navigation paths exist from both camps to every objective; the saved
  navmesh matches the current layout (re-bake guard); capture points count living soldiers only;
  the map boundary stops the player; wind and field beds play and birds call from the trees.
- Navmesh: 4,404 polygons covering ~63,400 m2 of ~67,700 m2; baked offline in ~0.2 s.
- Finding: Godot 4.7 syncs large navigation regions asynchronously, so AI must tolerate
  "no path yet" for the first moments of a match.
- Screenshots checked: aerial and top-down layout (A farmstead, B hilltop torii, C river outpost,
  stream, treelines, camps), ground views from the spawn and the hill.

### M4 — 2026-11-04

- 60/60 tests pass, three consecutive runs. New (AI): 16 v 16 with matchlock ashigaru on both
  sides and every AI in a squad, squads spread over A, B and C; after 40 s soldiers are fighting
  over the objectives and nobody is stuck in camp; an AI swordsman closes in and kills an enemy;
  an AI marksman fires at a target 40 m away and draws the katana when rushed; never more than two
  AI fight the player in melee at once; in a full battle soldiers fall and reinforcements return,
  distant volleys are heard from camp, close fighting is heard up close (cuts, death cries),
  the battle intensity raises the battle beds, and soldiers shout as they charge; distant soldiers
  animate at a reduced rate. Training Range menu option and setup options.
- Packaged-build self-check (Linux twin): training-range cut and shot land; a 30 s 16 v 16 AI
  battle runs inside the exported game (32 soldiers, 14 kills). PASS.
- Headless CPU cost per frame (2-core cloud VM, no rendering, 40 s battles):

  | Soldiers | Avg | Worst | Kills / 40 s |
  |---|---|---|---|
  | 16 v 16 | 2.2 ms | 5.2 ms | 25 |
  | 32 v 32 | 4.1 ms | 15.6 ms | 42 |
  | 64 v 64 | 8.0 ms | 22.2 ms | 72 |

  CPU scales roughly linearly; the occasional spikes at 32 v 32+ are investigated in M6.
  GPU cost (32 skinned Rōnin at ~94k triangles each) can only be measured on the owner's PC.
- Screenshots checked: armies marching out of camp, fighting at objective C.
- Windows build: `SengokuBattlefield-M4-Windows.zip`. Not launched on Windows.

### M5 — 2026-11-04

- 72/72 tests pass. New (conquest): the player captures a neutral point in ~12 s with capture
  ticks, a "Capturing" bar and the captured cue; three soldiers capture in ~8 s; any enemy
  presence contests (no progress, contested cue, HUD says contested); an enemy point is
  neutralised (double speed) and then captured; losing a point plays the lost cue; deaths cost
  tickets; holding more points bleeds the enemy at 0.25 per point of difference per second; the
  conch warning at low tickets; defeat at zero tickets (end screen DEFEAT, defeat music, input
  off); victory (VICTORY screen and music); the HUD shows tickets and A/B/C and Tab shows the
  scoreboard; respawning at a held point; **complete AI-vs-AI conquest matches reach a winner**.
- Simulated default match (150 tickets at the time): faction 0 won after 248 s, 195 kills,
  7 captures. Starting tickets raised to 250 (~7 minutes); tune in `data/battle/default_battle.tres`.
- Screenshots checked: ticket strip, A/B/C chips, contested capture bar, scoreboard.
