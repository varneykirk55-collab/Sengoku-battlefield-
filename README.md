# Sengoku Battlefield

Single-player, Battlefield-style combat set in Japan's Sengoku period. You fight as one soldier
in an AI army against another AI army, with katana and tanegashima matchlock, over three
capturable objectives.

Built with **Godot 4.7.2** (Standard build, GDScript). Everything visual and audible is a
placeholder for now.

## Status

| Milestone | Contents | State |
|---|---|---|
| M0 | Project, input (keyboard/mouse + gamepad), six audio buses, AudioManager, music, settings, tests, CI | **Done**, see [testing](docs/TESTING.md) |
| M1 | Player: cameras, movement, health, death/respawn | **Done** |
| M2 | Katana + matchlock, weapon switching, combat audio, Windows build | **Done** |
| M3 | Prototype battlefield, spawns, A/B/C, navmesh, ambience | **Done** |
| M4 | AI armies 16v16 with squads, battle audio, Windows build | **Done** |
| M5 | Conquest: tickets, HUD, match end | **Done** |
| M6 | Profiling, fixes, Windows release | Next |

## Running

**From source:** install Godot 4.7.2 Standard (not .NET), import `project.godot`, press F5.

**AI battle report / profiling:** `SIM_SECONDS=60 SIM_SOLDIERS=16 tools/sim.sh`

**Tests (headless):** `tools/test.sh` (downloads Godot 4.7.2 to `~/.cache/sengoku` on first run).

**Windows build:** `tools/export_windows.sh <label>` writes `dist/SengokuBattlefield-<label>-Windows.zip`
(a single `.exe` with the game data embedded). Packaged Windows builds are planned at M2, M4 and M6.
`tools/verify_export.sh` exports the same content for Linux and runs it, to prove the packaged build
finds all of its audio. The Windows `.exe` itself cannot be launched in the cloud environment.

## Controls

| Action | Keyboard / mouse | Gamepad |
|---|---|---|
| Move | W A S D | Left stick |
| Look | Mouse | Right stick |
| Jump / Sprint | Space / Shift | A / L3 |
| Primary (katana light attack, matchlock fire) | Left mouse | RT |
| Secondary (katana heavy attack, matchlock aim) | Right mouse | LT |
| Reload | R | X |
| Switch weapon | Q or mouse wheel (1 / 2 direct) | Y (D-pad left/right direct) |
| Third / first person | V | D-pad up |
| Scoreboard / Pause | Tab / Esc | Back / Start |
| Debug: hurt yourself (prototype only) | F2 | — |

## Layout

```
autoload/      Settings, GameInput, Events (signal bus), AudioManager, Music
audio/         sfx/<event>/ and music/ - drop-in replaceable audio (TEMP_ = placeholder)
scenes/        game scenes
scripts/       gameplay code (audio/, ui/, ... grows per milestone)
tests/         headless test runner + unit tests
tools/         setup, test, export, screenshot, audio generator
docs/          architecture, audio, testing notes
```

More: [Architecture](docs/ARCHITECTURE.md) · [Audio](docs/AUDIO.md) · [Testing](docs/TESTING.md) · [Asset provenance](LICENSES.md)
