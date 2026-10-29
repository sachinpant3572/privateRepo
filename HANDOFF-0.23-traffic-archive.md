# 0.23 traffic: archive (the design as first written, 2026-10-28)

Moved from HANDOFF-0.23-traffic.md once the build was in. What was built
(and where it differs) is in that note.

## Where it started (commit 58f901d)

- A fixed bubble of 8 traffic cars from one flat kind list; one speed
  (13 m/s, 6.5 at junctions); an 8 m ray to brake; random lit-green poles
  per downtown block side that nothing obeyed. Stop bars already painted
  at `_setback + gap` (city_cells.gd `_street`).

## Design (decided before the build)

Signals (MUTCD and ITE practice, US):
- Junctions with 3+ legs where an arterial meets a street get signals;
  minor-minor junctions all-way stops; a minor leg meeting a major road a
  two-way stop on the minor leg; roundabouts yield on entry; rural
  country junctions stop on the minor road, signals only in towns.
- One controller per signalled junction; legs pair by opposite direction
  into a main pair (higher rank) and a cross pair; T junctions run the
  main pair plus the stem.
- Timing: yellow = 1.0 + v / (2 x 3.05) s from the approach limit (3-5
  s); all red 1.5 s; main green 22 s, cross 14 s (a cycle of about 45 s,
  shorter than a real 90 s so a player isn't stuck, same proportions).
- Semi-actuated: the cross phase is skipped and main green rests when no
  car (the player included) waits on the cross approaches.
- Late night (00:00-05:00): flashing yellow on the main road, flashing red
  on the cross street (a stop sign).
- California rules: right on red after a full stop when clear; permissive
  lefts yield to oncoming traffic.
- Heads: housings in the baked cell mesh, one per approach over its lanes;
  lit lenses one global MultiMesh of camera-facing quads (one draw call).
  Pedestrian heads: WALK, flashing hand, hand.

Driving:
- Limits (US): lane and quarter 25 mph (11.2 m/s), street 30 (13.4),
  avenue 35 (15.6), boulevard and bridge 40 (17.9); country road 45 (20),
  highway 55 (24.6), freeway 65 (29). Each driver +-10%, a few speeders.
- IDM: `a = a_max [1 - (v/v0)^4 - (s*/s)^2]`, `s* = s0 + vT + v dv /
  (2 sqrt(a b))`, s0 2 m, T 1.4 s, b 3 m/s^2; the stop line is a leader
  standing still.
- Stops: at a red or yellow stop if d > v^2 / (2 x 3), else go on. Stop
  signs: a full stop of 1 s, first come first served, box clear.
- Sirens: pull right and slow. Blockages: a car standing ahead 3+ s,
  change lane if possible, else creep round.

Demand:
- Budget = district x hour x road, capped by quality (Low 8 ... Ultra 18).
  FHWA weekday hour profile; district profiles (downtown high by day, the
  quarter at night, docks 6-18, residential low with peaks, bayou and
  country low, freeways high).
- Mix: docks trucks; downtown taxis, luxury, EVs; heights luxury, EVs,
  SUVs; wards compacts, pickups, vans, three-wheelers; farmland pickups,
  tippers, cargo trikes.
- Events: wanted level, roadworks, wrecks, `traffic.surge(pos, radius,
  factor, secs)` for missions.

## Cost (as planned)

- Full package: an agent run of about 2-3 hours, roughly 400-600k tokens.
- Cheaper option: signals with phases and speed limits only, about 1 hour.
- Chosen: the full package, because Sachin asked for district, congestion
  and event factors by name.
