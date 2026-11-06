# 0.22 fixes (Sachin's 0.21 feedback, 2026-10-29)

Five items from testing 0.21 on a Galaxy S25 Ultra (12 GB), on Ultra.

## 1. Critical bug: 18-wheeler stuck, whole view shaking (video)

The video shows the Gorran Longhaul 18 at night with 1 star. The HUD reads
22–23 km/h, the truck sits still in the world, and the camera shakes.

- Verified:
  - Spawns checked other cars by **centre distance** only, so a 2.2 x 5.4 m
    curb spot could sit under a 15 m trailer whose centre was far off.
  - A car sunk into the semi makes `get_real_velocity()` read about 72 m/s
    (vertical depenetration) while the semi's position moves smoothly.
  - The semi's own first `move_and_slide` lifts it out of a shallow overlap
    with a one-off 1.1 m step.
- Inferred, not reproduced headless: the stuck-with-shaking state itself.
  Probes of a straight pin, a tail sweep past a parked car and a semi
  pushing a parked sedan all drove on smoothly.
- Fixes:
  - `Vehicle.room_for` / `footprints_meet`: a 2D SAT footprint check, used by
    traffic, parked and police spawns (`PARK_FOOTPRINT` for curb spots).
  - Police cars: when the junction picked is taken (often the only one in
    range, so before this two police cars spawned inside each other), the
    spawn tries a spot 9 m up each road leaving it.
  - The camera's lead and turn, and the HUD speed, now read `Vehicle.motion`
    (real flat velocity eased over 0.12 s), not the commanded `velocity`.
  - Safety net in `_handle_collisions`: a parked or lighter car sunk more
    than `OVERLAP` (0.08 m) into this one is moved out (`shove`,
    `move_and_collide`, at most 0.25 m a frame).
- Tests: `test_spawns_need_room`, `test_overlap_resolves`,
  `test_heavy_pushes_parked`, `test_pinned_car_holds_still`.
- Open: if it happens again, the new logger (item 5) records position,
  speed, nearby vehicles and FPS. Ask Sachin for the log.

## 2. Handling stiff, especially on corners

- `CORNER_GRIP` 1.5 multiplies every kind's `corner_g`, for both the yaw
  cap and the AI's corner speed.
- `STEER_IN` 0.3 → 0.22 s, `YAW_IN` 0.18 → 0.12 s, `MIN_RADIUS` 3.5 → 3.2 m.
- Rejected: raising `corner_g` per kind in `vehicle_kit.gd`. One multiplier
  keeps the kinds' relative feel and is one number to tune back.

## 3. See-through tint while walking on open road

- Cause: `STENCIL_MODE_XRAY` was always on for the player, their car,
  police and hostile people. The stencil draws wherever the body fails the
  depth test, including one limb behind another, so the player looked
  tinted on an empty road.
- Fix:
  - `set_xray(color)` only records the colour and joins group `xray`.
  - `show_xray(on)` swaps the material.
  - `TopDownCamera._update_xray` runs every 0.12 s within 80 m and casts rays
    (mask WORLD | VEHICLES, skipping self and one's own ride) from the legs
    and chest (a car's nose and tail) to the camera. The silhouette shows
    only when all of those rays are blocked.
- Test: `test_xray_only_when_hidden`. Shots: `SHOTS=xray`.

## 4. Stutter, 20s fps on Ultra with more than two vehicles

- Measured: building one vehicle mesh costs 1.4–4.5 ms (14.5 ms for the
  pickup on first build), and every traffic spawn built its own.
  - Fix: `Vehicle._meshes` caches the meshes by kind and paint.
- Inferred: "more than two vehicles" is exactly when Ultra's third real car
  light came on (cars: 3), and Ultra also had the headlight shadow. The
  Compatibility renderer draws everything a light reaches once more per
  light.
  - Fix: Ultra now keeps High's 2 car lights and no headlight shadow (its
    4x MSAA was already on in 0.21).
- Cheaper or bigger options not taken: MSAA 2x; a per-light range cut.
  Revisit with the logger's FPS rows.

## 5. Logger

Built by a background agent in a worktree: `game/scripts/game_log.gd`,
`game/LOGGING.md`, a Log section in Settings > Game (on/off, BUG button,
Report issue, Export, Copy) and a BUG button on the HUD. See LOGGING.md.
Merge fixes: the settings-tab test counts the Log rows (heading and status
carry meta `section`); the changed-settings diff compares types first.

- Agent notes carried over:
  - Its follow-up commit bf2f73f (same two fixes, done differently) was
    not merged; main's own fixes cover it.
  - The log names the build from `config/version` (now `0.22-fixes`).
  - The HUD FPS label is rebuilt every frame (small cost, pre-existing).
  - Android's Save dialog for Export is untested on a device; Copy log
    is the fallback.

## 6. Called cab never arrived (found by the suite)

- Cause: the curb stop sat on a parked car, or on the player standing in
  the parking strip; the cab braked for them 5 m short and never reached
  its last point.
- Fixes:
  - `_curb_stop` tries spots 6 and 11 m along the street (short of the
    spot first) when a car (`room_for`, skipping the cab) or the player on
    foot is on it.
  - A called cab stopped on its last leg has arrived when its look-ahead
    ray is braking it for the player on foot, or when it is within
    `PULL_UP_STOP` (6 m) of its stop and `PULL_UP` (9 m) of the player.
    The stop can lie past the player when the near spot is taken, so a
    stop-distance rule alone missed it; a distance-along-the-street rule
    fired for cabs held by traffic in the lane (second review).
- Test: `test_cab_stop_skips_parked_car`.
- Also seeded the suburbs test's spawn probe (20 draws, 80% on suburb
  loops); one unseeded draw failed now and then.

## Review fixes (first review)

- `shove()` re-grounds the car on the terrain after `move_and_collide`.
- 18-wheelers keep their old corner grip (`_grip()`): a quicker yaw
  swung the trailer into walls.
- Wrecked cars leave the `xray` group.
- X-ray: inside the cutaway hole only vehicles count as cover (walls are
  already cut away there); the silhouette materials are pre-warmed at load.
- Logger: hitches need 1.5x the running average and 0.5 s apart; snapshots
  list the 3 nearest vehicles (`near`) and the car's real speed
  (`moving_kmh`); the export event names the file.
- Not done: pre-warming the vehicle mesh cache at load (the first car of
  each model and paint still builds its mesh once, 2-15 ms).

## Second review (nothing serious)

- Fixed: the cab arrival rule (above).
- Open, minor: in the classic orthographic view `covered()` aims rays at
  the camera position, not along the view (`_view_blocked` does it right);
  only far police/hostile silhouettes are affected. CORNER_GRIP also lets
  AI take corners about 22% faster (suite green). 18-wheelers keep the
  old, stiffer grip on purpose. Whether the light count caused the Ultra
  drop is unverified: the logger's fps rows from the S25 are the check.

## Traps

- A GDScript parse error in `test_runner.gd` makes the runner hang with no
  output until the 450 s timeout. If a subset run prints nothing, look for
  `Parse Error` first.
- `get_real_velocity()` includes depenetration and can read 70+ m/s while
  the body barely moves; use its flat part, eased (`motion`).
