# 0.23: traffic lights and realistic traffic

Sachin, 2026-10-28: "Also build realistic traffic lights, and simulate
realistic traffic too, based upon the type of district, congestion, events
happening, what the region is meant for etc. factors."

## Where it started (commit 58f901d)

- A fixed bubble of 8 traffic cars from one flat kind list; one speed
  (13 m/s, 6.5 at junctions); an 8 m ray to brake; random lit-green poles
  per downtown block side that nothing obeyed. Stop bars already painted
  at `_setback + gap` (city_cells.gd `_street`).

## Design (decided)

Signals (MUTCD and ITE practice, US):
- Junctions with 3+ legs where an arterial (2+ lanes each way) meets a
  street get signals. Minor-minor junctions get all-way stops. A minor leg
  meeting a major road gets a two-way stop on the minor leg. Roundabouts
  yield on entry. Rural country junctions: stop on the minor road;
  signals only in towns.
- One controller per signalled junction. Legs pair by opposite direction
  into phases: main pair (higher rank) and cross pair; T junctions run
  main pair plus stem.
- Timing:
  - yellow = 1.0 + v / (2 × 3.05) s, from the approach speed limit (3-5 s);
  - all-red 1.5 s;
  - main green 22 s, cross 14 s, so the cycle is about 45 s. That is
    shorter than a real 90 s cycle so a player isn't stuck, but in the
    same proportions.
- Semi-actuated: the cross phase is skipped and main green rests when no
  car (the player included) waits on the cross approaches.
- Late night (00:00-05:00): flashing yellow on the main road and flashing
  red on the cross street (treated as a stop sign).
- California rules: right turn on red after a full stop when clear;
  permissive left turns yield to oncoming traffic.
- Heads: the housings stay in the baked cell mesh, one per approach,
  hanging over its lanes and placed per approach at signalled junctions
  instead of the random per-block-side poles. Lit lenses are one global
  MultiMesh of camera-facing glow quads (one draw call), so they read
  from the top-down camera. Pedestrian heads show WALK, flashing hand and
  hand with the phases.

Driving:
- Speed limits by road class (US):
  - lane and quarter: 25 mph (11.2 m/s); street: 30 (13.4);
    avenue: 35 (15.6); boulevard and bridge: 40 (17.9);
  - country: road 45 (20), highway 55 (24.6), freeway 65 (29).
  - Each driver ±10%, with a few speeders.
- Car following: the Intelligent Driver Model, `a = a_max [1 - (v/v0)^4 -
  (s*/s)^2]` with `s* = s0 + vT + v dv / (2 sqrt(a b))`, s0 2 m, T 1.4 s,
  comfortable braking b 3 m/s². The leader comes from a look-ahead that
  scales with speed and follows the lane. The stop line acts as a leader
  standing still.
- Stops: at a red or yellow light the car stops if it can stop
  comfortably (d > v² / (2 × 3)); otherwise it goes on. At stop signs it
  makes a full stop of 1 s, then first come, first served, and only when
  the junction box is clear.
- Emergency vehicles: traffic pulls right and slows for police with
  sirens on.
- Blockages: a stationary car ahead (wreck, parked badly) for 3+ s → the
  car changes lane if it can, otherwise creeps round.

Demand (density and mix):
- The budget comes from district × hour × road, capped by graphics
  quality (Low 8 … Ultra 18):
  - Hour factor: the FHWA weekday profile (AM peak 7-9, PM peak 16-18,
    1-2% per hour at night).
  - District profile: downtown and midtown run high by day with peaks;
    the quarter peaks in the evening and at night; docks peak 6-18 by
    day; wards, brownstone and heights are residential (low, with
    peaks); bayou and country roads are low; freeways are high.
- Mix by district:
  - docks: trucks;
  - downtown: taxis, luxury, EVs;
  - heights: luxury, EVs, SUVs;
  - wards: old compacts, pickups, vans, three-wheelers;
  - farmland: pickups, tippers, cargo trikes.
- Events: wanted level (police on the road, traffic yields), roadworks
  (already narrow lanes), wrecks block lanes, and a `traffic.surge(pos,
  radius, factor, secs)` hook for missions.

## Agent build: approach and decisions (2026-10-28)

- `traffic_plan.gd` (static, pure, thread-safe: the cell builder calls it)
  classifies junctions, places the stop line (`stop_back` = the painted
  bar), speed limits and pole geometry. `traffic.gd` (child of
  Population, group "traffic") runs controllers, demand, mix, surges,
  sirens, the vehicle cache, all-way queues and the lens MultiMesh.
  Vehicles find it lazily; without one they drive with no controls.
- Control by leg rank (StreetPlan rank: arterial 4+, collector 2-3,
  local 1): main group = top leg plus its most opposite leg (dot < -0.7).
  Arterial main x collector+ cross: signal. Collector x collector: signal
  in downtown, midtown, docks, quarter; all-way stop elsewhere. Local x
  local: all-way stop. Anything x local cross: two-way stop on the cross
  legs. Roundabout ring legs go free, spokes yield. Plan nodes with a
  country link: never signals. Country junctions: the two best, most
  opposite legs are major, the rest yield (no stop signs drawn: country
  tiles are not this package's).
- Pretimed in downtown, midtown and quarter (always cycle, offset by node
  hash); semi-actuated elsewhere (rests in main green; a car within 45 m
  on a cross approach calls the cross phase: min 7 s, max 14 s).
- Flash 00:00-05:00 (main flashing yellow, cross flashing red = stop),
  except where both groups are arterial. A knocked-down pole (its brk
  info `down`) hides its lenses and turns the junction to all-way
  flashing red. breakables.gd is not edited: the manager polls the info.
- Poles: far-side mast arm on the departure leg straight ahead (US
  practice), at the corner (setback + 0.5 from the node, 0.6 m behind the
  curb, the spot the old random poles used), heads over each lane; else
  near side on the approach. One cabinet per junction. Ped heads face
  along the host street and show WALK with their own group's green.
- Lenses: housings stay baked and dim; lit lenses are one MultiMesh of
  camera-facing quads (one draw call, no lights), bigger at night. They
  show from any side, so they read from the top-down camera.
- Driving: IDM (a_max from the kind's accel, s0 2 m, T 1.4 s, b 3) on the
  nearest leader along this street and the next (manager's cached list,
  rescanned every 3 frames); the 8 m ray stays for people and odd
  obstacles. Stop line = a stationary leader. Yellow: stop if d >
  v^2/6. Red: stop unless d < v^2/18. Per-driver factor 0.85-1.15 of the
  limit, capped at 0.9 x the kind's top speed; rain -10% and T +0.4 s.
- Taxis and scripted cars (`_script_ai`) don't obey lights: not this
  package's code.

## Packages

- Agent (worktree): all of the above. It owns `scripts/traffic*.gd` (new),
  population.gd, city_cells.gd light placement, prop_kit.gd
  `traffic_light`, and vehicle.gd `_traffic_ai`, `_police_ai` yield and the
  `_ahead` ray.
- Main session: exhaust, tyre smoke and tyre marks (vehicle.gd `_effects`,
  fx.gd, puffs.gd, kits/vehicle_emissions.gd). Notes in
  HANDOFF-0.23-exhaust.md.
- Models agent: vehicle.gd `_build_model`, vehicle_kit.gd.

## Cost

- Full package: an agent run of about 2-3 hours, roughly 400-600k tokens.
- Cheaper option: signals with phases and speed limits only (no IDM,
  demand or events), about 1 hour.
- Chosen: the full package, because Sachin asked for district, congestion
  and event factors by name.

## Open questions / traps

- Raising speeds and adding stops changes taxi, roadworks and traffic test
  timings. Keep their meaning; retune waits, not checks.
- Performance on phones: 18 cars is the Ultra cap; probe frame time.
