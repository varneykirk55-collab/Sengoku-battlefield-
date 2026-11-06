# Terrain repair (black ground + green patches) — Bot3

Reproduced on Kirk's laptop GPU (AMD Radeon RX 560X, Vulkan 1.3.260, Godot 4.7.2 Forward+).
Not reproducible on software Vulkan (llvmpipe) — which is why earlier captures looked fine.

Root cause: project had `msaa_3d=1` (2x MSAA) while v5 enabled SSAO + SSIL. On this AMD
driver, MSAA + screen-space AO/IL writes black (invalid) tiles over the lit buffer, so most
of the ground goes black from frame 1. The "bright-green rectangles" were grass blade cards
showing through the black. Bisected: SSAO+SSIL off -> fixed; MSAA off (SSAO/SSIL kept) -> fixed.
Terrain shader/textures were not the cause (removing NORMAL_MAP did not help).

Fix: `msaa_3d=0`, `screen_space_aa=2` (SMAA). AO/indirect light kept.
Also fixed: CPU-generated stone normal map stored "up" in green instead of blue (Z).

Validated on RX 560X: 0 black samples across all 11 capture angles, no shader/material errors.
Rollback tag: bot3/pre-terrain-repair-20261106.
