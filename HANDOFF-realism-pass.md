# HANDOFF: realism pass (0.21): lights, driving, camera, sky, quality, models, animation, roads, boundaries

Sachin, 2026-10-28 (after playing 0.20), in short:
- "the car light does not illuminate the road or the things falling in its vicinity. Please fix this.
  Check if this is happening for other kinds of lights too ... realistic effect with less vfx".
- "the driving on turns is very swift, and all Cars have too much restricted speed ... the camera
  moves so fast during turns ... causes dizziness. Please fix these on priority."
- Gates mixed in length and height; boundaries of many kinds (wood, concrete, ply, high, low) by
  people and place.
- Better hero, NPC and vehicle models (four-wheelers, two-wheelers, three-wheelers, 6-18 wheel trucks).
- Birds, a sun, stars clearer far from the city (mountains, beach, desert) at night.
- Bloom and other effects with on/off in Settings; quality presets Low, Medium, High, Ultra.
- Roads of many surfaces (new, worn, washed out, tiled white or brown) and roadworks with signs
  that traffic avoids.
- Hero and NPC animations; NPCs react to what they see, hear and are in, at the right moments.
- "Test verify everything thoroughly."
- Brands: buildings open from the start, by cash, or after missions; several malls, each with its
  own character; the trademark knockout search runs (merch is planned).

## Split (decided 2026-10-28)

Main session: P1 lights, driving and camera (vehicle.gd, vehicle_kit.gd HANDLING values,
top_down_camera.gd), quality presets and effect toggles (new scripts/graphics.gd plus
settings_screen.gd), the sky "Look up" view in the camera, the brands plan answers, merges,
gates, review, APK.
Four agents, each in its own git worktree, merged by the main session:
- **VEH** vehicle models: vehicle_kit.gd meshes; new kinds (three-wheeler, 6/10/18-wheel trucks)
  with HANDLING entries for the new kinds only.
- **CHAR** hero and NPC models, animation library, NPC perception and reactions: character_kit.gd,
  rig.gd, humanoid.gd, npc.gd, pedestrian.gd, patron.gd, cop.gd, player.gd (animation calls only).
- **WORLD** road surfaces and roadworks (city_cells.gd, country_tiles.gd road parts, traffic
  avoidance) and gate/boundary variety (country_kit.gd _lot_fence/_fence_run, grounds_kit.gd,
  homes_kit.gd, prop_kit.gd fence).
- **SKY** sun, moon, stars by light pollution, birds: atmosphere.gd sky parts and new files.
Rejected: one agent per item (10+ agents; country_kit and country_tiles would be edited by three
of them); everything in the main session (each call re-reads a context that would pass 250k).

## Decisions

- Real lights are budgeted: the Compatibility renderer lights each mesh in extra passes, so only
  a few real lights may be live (count set by the quality preset). The ground glow decals stay
  as the cheap far layer.
- The camera is top-down (Angle 40-90°), so the sky is rarely in frame: the sky shows in a Look
  up view, in water and wet-road reflections (sky_tint), and through the light on the ground.

- Driving: the yaw rate is capped by grip (corner_g / speed, per kind in HANDLING) and a 3.5 m
  tightest circle, for every driver; the player's yaw also eases in over 0.18 s (YAW_IN). AI yaw
  is not eased (it oscillated). Turn values were not lowered; the grip cap does the calming.
- Top speeds raised to real-world-ish values (sedan 31 m/s = 112 km/h, super 48, scooter 20);
  run-on test bound is now physics based (v^2 / 2a + 9 m).
- Camera driving yaw: 45°/s cap, 60°/s² accel, half-life 0.8 s slow / 0.6 s fast. Quick swings
  (getting in a car, compass/north up) use 90°/s and 180°/s². On-foot constants unchanged
  (changing them broke the walk let-go feel).
- Look-ahead not widened at the new top speeds: flat out the sedan sees about 74 m (2.4 s).
  Zooming out more would load about 40% more city. Open for Sachin.
- Graphics (scripts/graphics.gd): presets low/medium/high/ultra set detail, shadows, bloom, aa,
  vivid, real_lights; the toggles then change one by one ("High *"). Real light budget
  (cars/lamps): low 1/0, medium 1/2, high 2/4, ultra 3/4 plus a shadow on the player's
  headlight and 4x MSAA. Kept at 7-8 lights at most because Compatibility caps lights per
  object (8 by default) and each light redraws the big cell meshes. Low renders 3D at 80%.
- Headlight spot: energy 14 x night, 32° cone, 30 m, -9°. At 5 the cone barely showed (grazing
  angle). With a real light the painted beams hide; the lamp glow on the car stays.
- Lamps: prop_kit tags the collider with "light" (offset to the head) and the "lamps" group;
  street_light head 5.85 m, gas_lamp 3.35 m. Knocked-down lamps go dark.
- Police bar: an omni light alternating red/blue, only while that car holds a real light slot.
- Bloom: additive, intensity 0.45 (softlight brightened the whole night scene).
- No explosions exist in the game yet, so no explosion flash. Windows and shop signs stay
  emission only (bloom makes them glow).
- Haze/fog rejected: a uniform wash at top-down distances.

## Open questions

- Look-ahead at top speed (above). Brand option A/B/C and B1/B2 (BRANDS_AND_PLACES_PLAN.md §10).

## Traps

- Tests: `game/tests/run.sh` (5 min cap); `ONLY=test_a,test_b` runs a subset. New tests go into
  `var tests := [` in test_runner.gd.
- Contact sheets: `tools/contactsheet.sh` at the repo root.
- `SHOTS=nightfx` shoots night at each quality (87) and the Lantern Quarter lamps (88).
- Tests that check "headlights on" use `headlights_on()`, not `_beams.visible` (beams hide
  when the car has a real light).
