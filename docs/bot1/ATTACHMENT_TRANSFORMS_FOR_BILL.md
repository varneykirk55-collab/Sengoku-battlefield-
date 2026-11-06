# Attachment transforms for Bill (Bot 2) — after Bot 1 socket fix
Bill owns `weapon_models.gd`. Bot 1 has not changed it.

Socket bone +Y is now the blade axis, so **IDENTITY mounts should work as they are** with the "blade along +Y, guard at origin" convention:

| Const | Recommended | Note |
|---|---|---|
| KATANA_SHEATHED | `Transform3D(Basis.IDENTITY, Vector3(0, 0.02, 0))` (keep the current value) | Saya now runs back and down along the left waist. If the saya mesh clips the kusazuri, try origin `Vector3(0.03, 0.02, 0)` (bone +X = outward). |
| KATANA_IN_HAND | `Transform3D(Basis.IDENTITY, Vector3(0, -0.02, 0))` | Blade leaves the thumb side of the fist. For a two-hand tsuka, move the mesh so about 0.12 m of handle sits at −Y. Keep the detailed GLB's `Basis(Vector3.BACK, PI/2)` model-X→Y fix. |
| Edge orientation | If the edge faces down, add `Basis(Vector3.UP, PI)` | Socket +Z is roughly world up at rest. |
| MATCHLOCK (gun_mount) | unchanged | `musket_ctrl` now holds still while aiming. `_place_gun` damping is not needed. |

Branch: `character-development` (see commit in report). Please confirm visually in a playtest.
