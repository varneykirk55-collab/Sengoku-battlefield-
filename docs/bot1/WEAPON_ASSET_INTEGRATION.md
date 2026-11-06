# Weapon asset integration (recovered Desktop assets)

Source: `C:\Users\aresg\OneDrive\Desktop\Recovered_Weapon_Assets\` (originals untouched).

- **Katana.glb**: SHA256 matches `res://assets/weapons/Katana.glb`. Already integrated (`DETAILED_KATANA`, player only). Mounts unchanged; the optional `KATANA_IN_HAND` −0.02 was skipped.
- **Flintlock.glb**: newly added as `res://assets/weapons/Flintlock.glb` (textures embedded; Godot extracted PNGs alongside). Player matchlock only, via `make_matchlock(w.soldier.is_player)`. AI soldiers keep the procedural one-draw-call mesh.

## Transforms (bone space of `gun_mount`, barrel +Y, gun top +Z, lock +X)
- `DETAILED_MATCHLOCK_XFORM = Transform3D(Basis(X->(0,1,0), Y->(0,0,1), Z->(1,0,0)), (0, -0.24, -0.10))`
  - model +X (muzzle) → +Y; model +Y (top) → +Z; model +Z (lock side) → +X
  - −0.24 Y puts the lock (model x≈0.40) at y≈0.16, the same as the procedural lock; −0.10 Z puts the bore axis (model height ≈0.10) on the bone axis.
- `Muzzle` Marker3D at `(0, 1.20, 0)` (procedural is `(0, 1.14, 0)`). `matchlock_weapon.gd` finds it by name.

## Known limitations
- It looks like a European flintlock, not a Tanegashima matchlock. It has a full shoulder stock, which reaches back to y≈−0.24, and no match cord, so the detailed version has no glow.
- The GLB's cock/frizzen/trigger animations are imported but not played.
- Offsets come from the mesh bounds and haven't been checked in rendered footage yet. Hand/cheek contact may need a small tweak.
- About 66k tris. Only the player has one.
