# HANDOFF 0.24: floating car, brakes and handling by class, human models

Sachin, 2026-10-29: "See the car, it seems to be in air even when brakes are
applied. Also, even after building the cars categories, all cars take the
same amount of time to brake and handle on curves. The first car ... the red
sports car ... takes a lot of time to brake and again has stiff handling on
corners. Please fix these issues. Also, the human models are very outdated
and primitive, we need to fix them." Log: breakables.gd:54 get_meta('glow').

## Decisions

- Floating: the hill ground mesh is drawn HILL_GROUND_DROP (0.26 m) below
  Terrain.height off the paving (so it never pokes through roads), but cars
  and people stood at Terrain.height. Fixed on the mover side:
  Country.ground_drop(p) (0 on roads + sidewalks, drives, trails, far roads,
  lot and plot pads; eased over DROP_EASE 1 m off the paving), exposed as
  Terrain.drop(x, z); Vehicle re-looks it up per metre moved and eases it
  (DROP_RATE 1.5 m/s), Humanoid per 0.5 m. Rejected: lowering the drop
  (chord analysis: 99th percentile 9 m chord rises 0.32 m above terrain, so
  roads would poke through), a contact shadow (an extra draw call a car).
- Brakes: the first guess (the coast flag) was wrong; review showed the old
  code already reset `_coast` every frame. Real cause: brake + steer (lock
  >= 0.35, > 9 m/s) starts a drift and the drift scrubbed a flat ~6 m/s², so
  every car braked alike into corners (sports 113 frames from 25 m/s). Now
  DRIFT_BRAKE 0.65 x the car's brake: sports 44 frames, sedan 59
  (test_classes_brake_and_corner_apart; fails at 113 with 0.2).
- Class handling: VehicleClasses rows gain brakes, cornering, turning, wheel
  multipliers, applied to the player's car only (`_feel`), so traffic tuning
  and its tests do not move. Performance 1.15/1.3/1.15/0.8 (sports: 43.7
  m/s² brakes, 33 m/s² corner grip vs a sedan's 20.9).
- Human models (cost options, Sachin can switch):
  - A, chosen: upgrade the code-built kit in place. Smooth-shaded ellipsoids
    and limbs (shared vertices, surface normals) instead of flat facets,
    more segments, shaped hands with fingers and thumb, rounded shoes, a
    face with eye whites, brows, nose, lips. Same rig, one draw call a
    person, every outfit and animation keeps working. About 2-3 h, about
    0.4M tokens. Triangle budget raised (see below).
  - B: replace with modelled CC0 rigged characters (glTF) retargeted to the
    humanoid bones; the outfit variety system would need redoing. 1-2 days,
    download hosts may be blocked.
  - C: AI-generated GLBs (HiggsField image to 3D): unrigged, no clothing
    variety, credits per model. Not viable for a crowd.

- People, as built: smooth_ball / smooth_limb / rounded_slab / loft in
  MeshBuilder. Torso is one loft (12 rings, waist to shoulders) on the
  `_profile` curve (chest and waist ellipsoids joined by a smooth max), its
  rings above y 1.2 bound to Chest so it stretches instead of cracking;
  `_surf` follows the same curve so panels sit on it. Quilted outfits keep
  `_quilt`. Head is one loft too (`_head_rings`: skull and jaw
  ellipsoids joined by a smooth max); two crossing balls left a jagged
  seam over the cheeks that read as stubble (review). Soft chin ball. Hair caps and shoulders went to 12x6 / 10x5.
- Triangles a person (char tris script): 790 avg / 1016 max before; 2439
  avg / 2706 max after (categories 2426 / 2730, hero 3070, plain 2496).
  Budgets: 3300 a look, 2500 average (2600 a category; workers 2507),
  hero 3400. About 20 people on screen
  is about +32k of the 180-200k an Adreno 830 draws at 60 fps. If phones
  drop frames, next step is a people LOD by quality preset (not built).

## Traps

- `ONLY=` names need the `test_` prefix, and new tests must be added to the
  list at the top of test_runner.gd or they never run.
- A GDScript parse error in test_runner hangs the runner until timeout.
- `round` and `pass` are GDScript names; a variable called either fails
  to parse.
- char_shots pages are separate args (`faces hero`), not comma-joined.
