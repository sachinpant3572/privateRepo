# 0.23: traffic lights and realistic traffic

Sachin, 2026-10-28: "Also build realistic traffic lights, and simulate
realistic traffic too, based upon the type of district, congestion, events
happening, what the region is meant for etc. factors."

## Where it starts (survey, file:line at commit 58f901d)

- Traffic: a fixed bubble of `TRAFFIC_COUNT 8` cars (population.gd:10),
  spawned at junctions 40-70 m out (`_spawn_traffic` :88). The kind comes
  from the flat `VehicleKit.CIVILIAN` list. Nothing varies by place or time;
  `world_map.json` `npc_density` is text that no code reads.
- Driving: `Vehicle._traffic_ai` (vehicle.gd:629-694) follows lanes on one
  road graph (city + country, `city.next_nodes`, `lane_point`,
  `pick_turn`). It cruises at `TRAFFIC_CRUISE 13` m/s everywhere and at
  6.5 m/s near junctions. A fixed 8 m ray (`_ahead`) brakes it. There are
  no speed limits (country `edge_speed` exists, unused), no give-way rules
  and no junction occupancy.
- Lights: `Props.traffic_light` (prop_kit.gd:91) is a static mesh with a
  permanently lit green lens, put 60% per downtown block side
  (city_cells.gd:1968), not per junction approach. Nothing reacts to it.
- Stop bars already sit at `_setback + gap` (city_cells.gd:365, 508).
- Districts: `city.district_at(pos)` gives `style` (quarter, docks,
  downtown, midtown, heights, wards, bayou, brownstone) or town or region
  kinds. Country: `zone_at`; lots carry tier and land value.
- Clock: `atmosphere.hour`. Events: wanted level, police cars, missions,
  roadworks.

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
