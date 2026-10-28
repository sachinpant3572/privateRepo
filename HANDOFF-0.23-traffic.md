# 0.23: traffic lights and realistic traffic

Sachin, 2026-10-28: "Also build realistic traffic lights, and simulate
realistic traffic too, based upon the type of district, congestion, events
happening, what the region is meant for etc. factors."

The design as first written, where it started and the cost estimate are
in HANDOFF-0.23-traffic-archive.md. This note is what was built.

## Files

- `traffic_plan.gd` (static, pure; the cell builder calls it off the main
  thread): junction control, stop lines (`stop_back` = the painted bar),
  speed limits, pole and lens geometry, signs.
- `traffic.gd` (child of Population, group "traffic"): signal
  controllers, all-way stop queues, demand budget, vehicle mix, surges,
  sirens, the vehicle cache and the lens MultiMesh. Vehicles find it
  lazily; without one they drive with no controls.
- population.gd: budget from Traffic, kind from the district mix, a
  per-driver speed factor. city_cells.gd: poles and signs per approach
  (no more random green poles). prop_kit.gd `traffic_light`: mast arm,
  heads, ped heads, cabinet. vehicle.gd: `_traffic_ai` and its new
  helpers, consts and vars, the `_ahead` ray. `_police_ai` is unchanged:
  traffic finds police drivers itself (`Traffic.sirens`) and yields.

## Decisions (as built)

Control, by leg rank (StreetPlan: arterial 4+, collector 2-3, local 1):
- Main group = top leg plus its most opposite leg (dot < -0.7). Arterial
  main x collector+ cross: signal. Collector x collector: signal in
  downtown, midtown, docks, quarter, else all-way stop. Local x local:
  all-way stop. Anything x local cross: two-way stop on the cross legs.
  Roundabout ring free, spokes yield. Nodes with a country link: never
  signals. Country: the two best, most opposite legs major, the rest
  yield (no signs drawn: country tiles are not this package's).
- Pretimed in downtown, midtown, quarter (main 22 s, cross 14 s, offset
  by node hash); semi-actuated elsewhere: rests in main green; a car
  within 45 m of a cross approach calls it after main's 12 s minimum;
  cross 7 s minimum, extended 3 s per car within 30 m, 14 s maximum.
- Yellow = max(3, 1 + v / 6.1) s from the approach limit (ITE); all red
  1.5 s. Walk with its own green, then 7 s flashing hand before the
  yellow (an actuated cross street: 4 s walk); a call on a resting main
  green waits out the flashing hand.
- Flash 00:00-05:00 (main flashing yellow, cross flashing red = stop),
  except crossings of two arterials, which keep cycling. A knocked-down
  pole hides its lenses and turns the junction to all-way flashing red
  (the manager polls breakables' info; breakables.gd untouched).
- Poles: far-side mast arm on the departure leg straight ahead (US), at
  the corner (setback + 0.5, 0.6 m behind the curb), heads over each
  lane; else near side. One cabinet per junction.
- Lenses: housings baked and dim; lit lenses are one MultiMesh of
  camera-facing quads (one draw call, no lights, MAX_LENSES 1024 within
  130 m), bigger at night, so they read from the top-down camera.

Driving (vehicle.gd `_traffic_ai`):
- Limits: lane, quarter, quay 25 mph (11.2 m/s); street 30 (13.4); avenue
  35 (15.6); boulevard 40 (17.9); country road 45, highway 55, freeway
  65; roadworks 25. Cruise = min(limit x driver factor, 0.8 x the kind's
  top speed): factor 0.92-1.08 for most, 10% speeders 1.1-1.2, 5% slow
  0.85-0.9. Rain: -10% and T +0.4 s.
- IDM: a_max = clamp(accel x 0.3, 1.5, 3.5), s0 2 m, T 1.4 s, b 3, on the
  nearest leader along this street and the next (cached list, rescanned
  every 3 frames); the 8 m ray stays for people and odd obstacles.
- The stop line is a leader standing still (cars stop 0.4 m short). At
  the line under 0.3 m/s the foot stays on the brake: IDM alone creeps
  the last bit, which read as rolling over a red.
- Yellow: stop if d > v^2/6. Red: stop unless d < v^2/18. Right on red
  after a full stop when the cross traffic gap is clear; permissive lefts
  yield to oncoming. Don't block the box: on green a car waits at the
  line while its exit street has no room.
- Signs: full stop of 1 s, then first come first served, and only with
  the box clear. Box clear counts a car's end nearest the middle, not
  its centre (a car half into the box let the next one go). Gridlock
  give-up 25 s at a sign, 90 s at a red.
- Sirens (any police driver): within 15 m, or within 40 m and closing,
  slow to 2.5 m/s and pull right; resume after. Police don't stop at
  lights.
- Blockages: behind something that never moves, go round after 3, 6 or
  10 s (wreck or parked; a driver; traffic not queued at a junction).
- `_drive` eases the throttle by the angle still to steer; `_traffic_ai`
  undoes that, or a car slowed to a stop mid U-turn.
- Taxis and `_script_ai` don't obey lights (taxi.gd is not this
  package's); hook: they could call `traffic.may_go` like `_traffic_ai`.

Demand and mix (traffic.gd):
- Budget = clamp(round(cap x level x hour x surge), 2, cap), cap by
  quality (low 8, medium 11, high 14, ultra 18), refreshed every 2 s.
- Level by district (downtown 0.9 ... bayou 0.3; country regions 0.2;
  near a freeway 0.7). Hour: FHWA urban weekday profile by default;
  nightlife (quarter, strip), port (docks, industrial, market), leisure
  (beach, park), freight (truck stop) profiles. Floor 12% of peak.
- Where cars set off: arterials far more than side streets
  (SPAWN_WEIGHT).
- Mix: multipliers on VehicleKit.CIVILIAN weights by district (freight,
  cbd, town_centre, wealthy, working, nightlife, market, rural,
  truck_stop, suburb); taxis x2 from 21:00 to 05:00. Nothing under
  0.5 for trucks and three-wheelers, so every kind still turns up.
- Events: `traffic.surge(pos, radius, factor, secs)` (a factor under 1
  thins traffic: a closure); sirens; roadworks; wrecks.

## Tests (test_runner.gd, at the end of the list)

signal phases and yellow timing; stop at red, go on green; all-way stop
first come first served; speed limits by road class; IDM gap behind a
stopped car; density and mix by district and hour; surge raises the
budget; yield to a siren; late-night flash; zebra styles match.
Test design: real junctions found near the spawn point (arterial blocks
there run 100-130 m); lights forced with `_set_phase` and `go_end = 1e9`.

## Gates

- Shots: `SHOTS=traffic` (96-98 in screenshots.gd), with a rough frame-time
  probe at the end of the run.

## Traps

- The worktree's imports generate `.uid` files for puffs.gd and
  kits/vehicle_emissions.gd (the main session's scripts): don't commit
  them from here.
- Raising speeds and adding stops changes taxi, roadworks and traffic test
  timings. Keep their meaning; retune waits, not checks.
