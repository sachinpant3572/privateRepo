# HANDOFF: realism pass, SKY package (sun, moon, stars, city glow, birds)

Part of HANDOFF-realism-pass.md. Sachin, 2026-10-28: "introduce birds, and sun, and stars in sky
that are more clearer when seen through remote mountain or beach areas where pollution is very
less, or from desert, at night." and "Test verify everything thoroughly."

## What is where

- `game/scripts/sky.gd` (SkyDome, RefCounted, owned by Atmosphere as `atm.sky`): a `sky`
  shader set on the Environment (BG_SKY; ambient stays a colour, reflections now come from the
  sky's 32 px radiance map, updated incrementally; tonemap, glow and exposure untouched). Gradient by hour and weather, sun disc and halo on the scene light's
  bearing (`disc_direction`), moon with phase (LUNAR_DAYS 8, PHASE0 0.08), stars and the Milky
  Way by light pollution (`pollution_at`, `star_visibility`), the city glow (`glow_at`: all round
  in town, a dome per lit place farther off), clouds. Globals: `stars`, `sky_zenith`, `sun_dir`.
- Look up: `SkyDome.look_up(cam, env, at, yaw, pitch)` / `look_up_transform` /
  `horizon_haze(env, on)` / `looks_at_sky(cam)`. The main session wires it into the camera.
- `game/scripts/birds.gd` (Birds, Node3D under Atmosphere, `atm.birds`): one MultiMesh of 320
  (20 flocks x 16), wing flap and blob shadows in the vertex shader. `Birds.startle(pos, radius)`
  from anywhere; fx.gd calls it on hits, crashes and knocked props.
- Water and wet roads mirror `sky_zenith` (and stars in water): small edits in mesh_builder.gd.
- Shots: `game/tests/sky_shots.tscn` (README). Tests: the four `test_sky_*`, `test_stars_*`,
  `test_birds_*` in test_runner.gd.

## Decisions

- A sky shader, not a dome mesh: it also feeds the reflection cubemap, costs no geometry, and
  is redrawn only 4 times a second while the top-down view frames no sky (IDLE_HZ).
- New globals rather than changing `sky_tint`, which WORLD and others read.
- Sun disc on the light's bearing; it sinks to the horizon in the first and last 14% of the
  arc while the light itself stays 25 degrees up (readable shadows).
- Light pollution from data/world_map.json (districts by style, city areas, towns), falling off
  over 230 m: downtown 0.08 of the stars, suburbs about 0.2, hills, beach and desert 0.8-0.9.
- City glow as domes: from the hills the glow sits over town (13 degrees off its bearing), not
  as a ring; downtown it is all round. Replaced a single bearing plus "focus" that lit the whole
  horizon from the hills.
- Moon starts as a waxing crescent so the first night out of town shows the Milky Way.
- Birds: one draw call, blob shadows in the same mesh (no shadow pass); CPU flock states fly,
  land, perch, flee, leave; none at night or in storms, bats 18:54-20:36, fewer in rain.
- The ground has no collider: a landing ray that hits nothing is open ground; city lots sit
  LOT_TOP (0.19 m) above Terrain.height on the kerb, so birds and their shadows sit on that.
- A missing country tile is open sea (gulls), not land.

## Traps

- `_frames` in shot scripts must wait on process frames: a slow render runs several physics
  ticks per frame, so the birds' jump refresh dropped the flocks spawned for a shot.
- Birds draw kinds at random (rng.randomize): a test must not need a share of a kind. The
  beach point's circle takes in canals and bayou, so egrets there are right; the test checks
  each flock against the habitat at its `home` (where it was started) instead.
- Perched birds seen from straight above are small (realistic); look for them with SKY_DEBUG=1.
- The orange or white sea glare at dusk and noon, and water glint dots by day, predate this work.
- `ONLY=s..` and `SKY_DEBUG=1` work for sky_shots; logs to /tmp with a `sky_` prefix.

## Not done

- No guns exist yet: gunshot code should call `Birds.startle(pos, 40.0)` when it lands.
- Stars in puddles (WORLD owns the road shaders; puddles mirror `sky_zenith` only).
