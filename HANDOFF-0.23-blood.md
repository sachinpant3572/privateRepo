# 0.23 blood package: decisions

Sachin, 2026-10-29: "Build bloodwork when beating, or killing someone,
either through melees, guns, or vehicles."

## Approach

- `scripts/blood.gd` (a child of the Fx autoload, `Fx.bloodwork`) owns all
  of it: a pool of 4 particle emitters for spurts, and ONE MultiMesh of 200
  ground marks (drops, pools, smears) used as a ring buffer, oldest
  overwritten. One draw call for every mark; no node or material per hit.
- Marks fade in the shader: each instance's custom data holds its start
  time, life, grow time and kind plus a shape seed. Nothing is written per
  frame except one shader parameter (`now`).
- Fx wrappers: `Fx.blood(pos, dir, amount)`, `Fx.blood_pool(pos, size,
  grow)`, `Fx.blood_smear(pos, dir, size)`, `Fx.set_blood(on)`.
- `Humanoid.bleed(pos, dir, amount)` is the public hook (guns use it, then
  `take_hit(shooter, damage, push, false)` so the hit adds no second spurt).
- Melee: `take_hit` spurts from the chest, scaled by damage. Vehicle: no
  blood under 4 m/s (14 km/h); above, a spurt and a smear trail while the
  body slides. Any death, and a hard knock-down, leaves a pool once the
  body settles; a body freed before that lays its pool on the way out.
- Settings > Game "Blood" (on by default, `settings["blood"]`); off clears
  every mark and stops new ones. main.gd passes it in `apply_settings`.

## Decisions

- Unshaded `blend_mix`, darkened by the `night` and `sun_dir` globals the
  way birds are. Rejected `blend_mul`: the compatibility renderer tonemaps
  in the scene shader when it draws straight to the screen (no glow), so a
  "white" multiplier would print dark squares.
- Compat packs MultiMesh custom data as half floats, so start times are
  kept relative to an epoch that moves every 60 s (all live marks are
  rewritten then, about 200 writes a minute).
- Marks sit on raised paving where it is, LIFT 0.035 m above its top:
  BLOCK_TOP 0.17 inside a city block's kerb line (`plan.inner`: sidewalk
  0.15, lot paving 0.16-0.17), PAVEMENT_TOP 0.15 within 2.7 m of a country
  road edge, else on the terrain. People stand at Terrain.height (sunk
  0.15 m on sidewalks, existing behaviour), so a body on a sidewalk lies
  over its pool only by its top few centimetres; the shots show it reads.
- Colour (calibrated in SHOTS=blood): the ACES tonemap (exposure 0.85)
  crushes dark reds, so 0.16 came out sRGB (19, 0, 0), black. fresh_color
  0.45 gives about (125, 0, 0) for drops and (85, 0, 0) for a pool's middle
  by day; dry_color 0.28 about (65, 0, 0). Day/night factor
  (0.7 + 0.3 sun) * (1 - 0.45 night): dark brown-red at night.
- Pools: 1.7 for a melee death, 1.6 + 0.3 * amount for a car kill, 0.8 for
  a hard hit (7 m/s+) the victim survives (shader edge ~0.84 of the quad,
  so a 1.7 pool is ~1.4 m across, wider than a body).
- Car smear: budget = slide speed in metres (1.5-20), a smear every
  clamp(speed * 0.12, 0.55, 2.5) m (patches while the body skids fast,
  unbroken as it slows), uneven lengths and a little slip so a trail is
  not a dashed line; ends when the body slows under 0.8 m/s.
- Blood still works when `Fx.enabled` is false (headless) so tests can see
  it; `Fx.enabled` only gates time effects (hit-stop, shake), and blood adds
  none.
- No victim tint (would need a material per person).
- The logger is untouched: deaths, knock-downs and car hits are already
  logged; melee hits are not, and the brief says not to add them.

## Traps

- Fx persists across tests: tests clear `Fx.bloodwork` first and turn
  blood back on at the end.
- Headless MultiMesh keeps no instance data (reads back identity/zero), so
  blood.gd mirrors transforms and custom data on the CPU for tests.
- Pedestrians have 40 health and punch for 7: test and shot damage values
  say which (the player's punch 12, kick 24).

## Shots

`SHOTS=blood` (README): street at (500, 230), blood_1 to blood_9 in the
output folder. Judged: spray visible as the kick lands; spatter small and
irregular on the sidewalk; smear patches along the slide; pools wider than
the bodies; dark brown-red at night; barely visible at the driving zoom.
