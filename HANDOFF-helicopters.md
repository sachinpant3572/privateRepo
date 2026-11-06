# Helicopters (#82)

Sachin approved "Helicopters (#82)" with "Yes to all these please". Walk up to a
helicopter, get in, take off, fly over Bellerive and the country, land, get
out: GTA SA/V feel, adapted to a top-down phone game. Helicopters only (no
boats, planes or airships). Branch `worktree-agent-a17c1ea9d7ee1ab59`.

## Where it lives

- `game/scripts/helicopter.gd`: the helicopter, `extends "vehicle.gd"`.
- `game/scripts/kits/heli_kit.gd`: the code-built meshes (civilian, police).
- `game/scripts/kits/vehicle_classes.gd`: the "heli" class row.
- `game/scripts/heliports.gd` and `game/data/heliports.json`: the aprons,
  pads, H, lights, parked helicopters, map markers, `problems()` for the test.
- `controls.gd` (collective, Q/PgUp and Z/PgDn), `touch_controls.gd` (flying
  layout), `hud.gd` (ALT and km/h, EXIT/BAIL), `player.gd` (board, exit,
  bail), `minimap.gd` and `full_map.gd` (H markers), `main.gd` (builds the
  heliports), `country_tiles.gd` (keeps the aprons bare of plants).
- `top_down_camera.gd`: the air framing and `stream_point()`/`stream_radius()`.
- `city.gd`, `country.gd`: stream round the camera's air point and radius.
- Tests: the `# --- Helicopters (#82)` block at the end of
  `game/tests/test_runner.gd` (8 tests). Shots: `SHOTS=heli` in
  `game/tests/screenshots.gd` (README lists it).

## Decisions (and why)

- **Reuse vehicle.gd** (extends it): health, damage, fire and explosion
  (car_fire.gd), debris, entering and the HUD's vehicle paths all come for
  free. Helicopter overrides `_physics_process` with its own flight model; a
  separate class would have duplicated the damage, fire and seat code.
- **Flight model** (arcade, weight-aware): the collective sets a wanted climb
  rate (climb 9 m/s, sink 12 m/s) chased at HOLD 6/s within the rotor's lift
  (lift grows with rpm^2, +15% ground effect within one rotor diameter, less
  when hurt). The tilt chases the stick's wanted velocity (max 52 m/s,
  ACCEL 8 m/s^2, tilt rate 18 m/s^3, quadratic drag), so it has inertia.
  Spool-up 4 s from boarding (lift-off after about 2-3 s), run-down 8 s.
- **Soft landing**: with DOWN held, near the ground the sink is limited to
  what braking at CUSHION 4 m/s^2 stops at TOUCH_SPEED 1.5 m/s, with the brake
  fed forward so the descent keeps to it. Touchdowns under LAND_SPEED 3 m/s are
  free; above it 9 health per m/s (x1.3 class) and a crumple; over 8 m/s
  throws debris; a heavy one wrecks it (fire, debris, wreck falls).
- **Walls**: `move_and_slide` against the city's colliders. Floating
  `move_and_slide` leaves the speed into a wall in `velocity`, so held into a
  tower it built up frame on frame and struck again until wrecked (first test
  run). Now each contact removes the speed into the wall; a blow at NUDGE
  5 m/s or more also bounces it back a little and costs 1.5 health per m/s.
- **`landed`** needs the skids to have taken it (|vy| <= 0.05), not just
  altitude < 0.05: a centimetre up at 22 m/s it is still falling.
- **Mount Calder and hills** (Terrain has no collider): a probe 3 m ahead; a
  rise of more than STEP 0.8 m over the skids stops the closing speed along
  the slope's normal and strikes it; it never goes under `_ground`.
- **Ceiling** 250 m over the land under it (wanted climb tapers to 0).
- **Out of the "vehicles" group above LOW 3 m**, so traffic, police cars and
  the car-only systems ignore a flying helicopter.
- **Exit**: 3 m or lower is an ordinary exit (EXIT). Higher is a bail-out
  (BAIL): the player drops and loses (h - 2.5) x 7 health. Over a roof exit is
  refused ("land on open ground"): humanoids snap to the terrain, so nobody
  can stand on a roof here.
- **Touch**: in flight the layout is forced to the stick whatever the driving
  layout, with UP (gas), DOWN (brake) and EXIT, no DRIFT. North up the stick
  flies where it points on screen and the nose turns that way; with the view
  turning, up flies ahead and a lean turns it. Hands off it hovers.
- **Camera**: pitch eases toward 75 deg in the air. The ground framing grows
  with height until AIR_FRAME 120 m down the screen; past that the camera
  backs off and narrows the lens so the helicopter keeps its size. The camera
  follows the nose (when the view turns) even in a hover.
- **Streaming**: the camera publishes `stream_point()` (the ground at the
  screen's centre, AIR_LEAD s ahead) and `stream_radius()` (to the corners of a
  20:9 screen). City cells load within max(105, r) and unload past
  max(150, r + 45); country tiles load within max(130, r), unload past r + 80;
  both tick every 0.05 s while flying (0.2 s and 0.15 s otherwise).
- **`_ground_hit`** projects from the camera's own transform, not
  `project_ray_*()`: with physics interpolation on those used the interpolated
  transform and lagged a frame, a whole teleport right after `snap()`.
- **Placement**: one heliport, Jade Gate (721, -77), 46 x 26 m, yaw 90 deg,
  two pads (civilian and police). The apron has no collider: helicopters set
  down on its "deck" (`Helicopter.decks`), people walk on the ground just under
  it. No rooftop heliport (people can't stand on roofs). No minimap rim arrow.
- **Police helicopter: skipped** (the flyable `police_heli` kind stays, parked
  at the heliport). A chasing one is not small: at about 55 m it sits below the
  camera (35-90 m up) and fills the view, or above it and only its shadow
  shows; it would need to path round downtown's towers, plus a searchlight and
  wanted-sight rules. The first follow code was removed rather than left dead.

## Cost measured (render prims, visible + shadow, hovering downtown)

| Setup | 60 m | 150 m | 200 m | 250 m |
|---|---|---|---|---|
| AIR_FRAME 150 | | 208k | 330k | 344k |
| AIR_FRAME 120 (chosen) | 186k | 201k | 201k | 237k |

Driving fast downtown, for reference: 181k (70k visible + 111k shadow).
Sachin's phone ran 45-52 fps at 250-306k (HANDOFF-fps.md). Chosen: AIR_FRAME
120 with CEILING 250, worst +31% over driving. **Cheaper option**: CEILING 200
(201k, +11%). A shadow-distance cap (150 m) was tried and reverted: it did not
cut the 200 m cost and drew a visible shadow edge on screen.

Streaming (desktop, AIR_FRAME 120 at 150 m): radius 191-220 m, 3.8 cells/s
needed, at most 42-43 cells loaded, no holes once running (1 at a teleport).
At 250 m (with AIR_FRAME 150): radius 232-268 m, 8.5 cells/s, 74 cells max.
A cell builds in 17-20 ms on a worker; its main-thread add is 1.3-1.4 ms;
the worst frame 9.3 ms on desktop. Not measured on a phone.

## Traps

- Worktree isolation refuses for-loops, heredoc+sed compounds and sed with a
  computed `$(...)` line: use plain commands, `bash script.sh`, or Edit.
- Tests: `L` (layers.gd) is not a class constant in test_runner.gd (each test
  preloads its own); the helicopter block has `HeliLayers`.
- Pumping streaming in tests: `city._finish_task(); city._stream_tick = 0.0;
  city._process(0.0)` and the same for country with `_tick`, until both
  `_task < 0`.

## Open

- Not tried on a phone: the fps at 250 m and the cell-build rate at full
  speed are desktop numbers. If the phone stutters, CEILING 200 first.
- A police helicopter chase (see above) would be its own task.
