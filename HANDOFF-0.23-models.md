# 0.23 models package: convertibles, bicycle, MUV

Plan and decisions for the models package of 0.23 (HANDOFF-0.23-vehicles.md
has the release plan). Branch `worktree-agent-a2a87c52f007c834a`.

## Kinds (scripts/kits/vehicle_kit.gd)

| key | name | size w x h x l (m) | mass | max_speed | accel | corner_g | seats |
|---|---|---|---|---|---|---|---|
| `roadster` | Vesper Lido | 1.86 x 1.2 x 4.0 | 1.3 | 40 m/s | 13 | 13 | 2 |
| `cabriolet` | Aurelle Riviera | 1.96 x 1.4 x 4.8 | 1.95 | 35 m/s | 11 | 11 | 4 |
| `muv` | Kaito Septa | 1.9 x 1.75 x 4.6 | 1.9 | 28 m/s | 9 | 9.5 | 7 |
| `bicycle` | Ardeno Corso | 0.6 x 1.1 x 1.8 | 0.09 | 8.6 m/s (31 km/h) | 2.5 | 7 | 1 |

- Roadster and cabriolet: category "convertible", flag `"convertible": true`.
  Bicycle: `rider: true`, leans like the motorbike. MUV sits between the
  sedan and the van in size, mass and speed.
- Only mass, max_speed, accel, corner_g and the existing handling keys are
  set. The class table (suspension, damage) is the main session's.
- Pools: CIVILIAN + roadster, cabriolet, muv x2. PARKED + roadster,
  cabriolet, muv x2, bicycle x2. PARKED_BY_TIER: T0 + bicycle x2;
  T1 + muv, bicycle; T2 + muv x2, bicycle; T3 + muv, roadster;
  T4 + roadster, cabriolet; T5 + cabriolet, roadster, cabriolet.
  Bicycles are never in CIVILIAN (traffic).

## Convertible design

- Decision: the body mesh is always built open (tub, seats, headrests,
  dash, wheel, windscreen frame on the hull rim), so `Vehicle._meshes`
  keeps its `kind|paint` key. The soft top is a separate mesh, cached in
  `scripts/convertible.gd` (`static var _tops`) by `kind|up` and
  `kind|down`, and swapped on the helper node. Fabric goes on the matte
  material, the rear window on gloss.
  - Why: the main session's dents copy the cached body mesh on the
    first hit. If the roof state were in the body key, a roof toggle
    would swap the body mesh under a dented copy. A separate top
    keeps the two apart.
- `scripts/convertible.gd` (new) is a Node3D under `Vehicle._model`, so
  it rolls with the body. It holds:
  - the raised and folded tops, with a 0.7 s fold (FOLD_TIME) on the
    physics tick;
  - the seated AI driver and passenger figures (a CharacterKit rig,
    posed once; passenger 40% of the time), shown only while an AI
    drives (`has_ai_driver`: TRAFFIC, POLICE, SCRIPT, CHASER) with the
    roof down;
  - seat placement for the player and NPC passengers
    (`VehicleKit.seat(kind, i) + (0, 0.92*(1-h), 0)`). It runs at
    physics priority 50, after the car and the player move: physics
    interpolation is on, so idle-time moves would jitter.
- vehicle.gd edits, kept small (11 lines):
  - `const Convertible`, `var roof_up := false`, `var convertible = null`;
  - building the helper in `_build_model` when the spec has `convertible`;
  - one call in `_skin`, so the top follows x-ray and wreck materials.
- Roof at spawn: population `_roof(car)` after the kind is picked (also in
  the long-haul re-pick). `VehicleKit.roof_up_at_spawn(rng, night, wet)`:
  up with 40% odds by day in the dry, 85% at night or in rain > 0.05.
- HUD `roof_button` at `Rect2(-300, -392, 130, 56)` from the bottom-right
  (left of EXIT, above DRIFT), shown only while the player drives an open
  car, greyed above 1.5 m/s (ROOF_SPEED); R does the same.
- Occupants: with the roof down the player and NPC passengers stay visible
  and sit; with it up they hide, as in any car. Seated figures drop
  their "bag" accessory (it hung through the seat).

## Rig (scripts/rig.gd)

- State gains `car` (0 none, 1 passenger, 2 driver) and `pedal` (crank
  angle, < 0 for none).
- `_car_seat`: legs out into the footwell, the back against the seat,
  hands at ten to two when driving, on the lap as a passenger.
- Bicycle: `_ride` places the legs by two-bone IK on the crank
  (`Rig.PEDAL_HIP_Y 0.95`, `PEDAL_CRANK (0.15, 0.29)`, `PEDAL_ARM 0.17`),
  with the ankle 0.08 h above the pedal. Spine -0.3, head 0.25, hands on
  the bars. `VehicleKit.pedal_angle` turns the crank at speed x
  PEDAL_RATE (1.13); -1 for kinds without pedals. player.gd and npc.gd
  set it each frame and reset sitting, car and pedal on exit.

## Gates

- Tests (test_runner.gd, at the end): `test_new_kinds_build_and_drive`,
  `test_convertible_roof_meshes`,
  `test_convertible_occupants_show_with_roof_down`,
  `test_roof_button_only_when_nearly_stopped`,
  `test_bicycle_rider_and_pedals`, `test_new_kinds_in_pools` (79 checks).
  A mutation run (ROOF_SPEED 20, dry odds 0.6) failed 7 checks, so the
  button and spawn-odds checks can fail.
- Shots: `SHOTS=convertibles` (95 open cars down, 96 up, 97 bicycle,
  98 MUV between sedan and van); gallery rows for the new kinds.

## Rejected

- Roof state in the body mesh key: see the dents reason above.
- Placing seated people in `_process`: physics interpolation is on.
- Posing rigs in a SceneTree `_initialize`: the pose only applies in
  `_process` once the tree runs.

## Traps

- Rig arm z sign: a more negative right-arm z moves the hand inward.
- A red stick through a seated figure was its bag accessory, not an arm.
- The worktree guard refuses heredoc-plus-run and computed sed args: use
  Write/Edit and plain single commands.

## Open

- The bicycle's crank mesh is static (built level); only the rider's legs
  turn with the pedals.
- Independent review: not run inside the package (the package agent had
  no tool to start a reviewer); a self-review of the diff found nothing.
  The main session's release review should cover this package.
- AI crew figures in open cars keep the plain body material, so they do
  not take the car's x-ray tint.
