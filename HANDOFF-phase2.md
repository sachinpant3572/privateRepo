# Phase 2 handoff: Bellerive's edges, the first countryside, taxis

Request (Sachin, 2026-10-27): "go ahead with phase 2". Phase 2 per WORLD_V3_PLAN.md §7:
Bellerive's edges (Brisa Beach, Golden Flats, Saltgrass, Verdant Hills), streaming past
the window, the first countryside roads and towns, taxis. Estimated 6-8 sessions.

## Decisions

- **P-1 Country is a second streamed layer, the street plan stays as it is.** Bellerive's
  plan (seed 1234) is not touched, so its blocks, landmarks and missions do not move; the
  plan dump must stay identical. A new layer (`scripts/country.gd`, tiles built by
  `scripts/country_tiles.gd` on a worker thread) covers everything outside `plan.bounds`.
  Rejected: growing the street plan to the whole area (it was tuned for 1.5 km; high risk,
  slow on phones).
- **P-2 The country is generated offline.** `tools/build_country.py` (Python + shapely)
  reads `data/world_map.json` and the plan dump and writes `data/country.json`: the play
  area, road graph with polylines, bridges, water banks, suburb and town lots, trees and
  barricades. The game only reads the JSON (fast start on phones, deterministic, tests can
  check the data). Regenerate after changing world_map.json or the plan.
- **P-3 Play area** = the phase 2 regions (Golden Flats, Saltgrass, Verdant Hills) plus
  the Bellerive rect, minus the Gulf. Its edge is a wall; roads leaving it end at "storm
  closure" barricades (the Great Storm story gate from §7).
- **P-4 Every road inside the play area is built, whatever its phase**: the near stretches
  of Route 40 and Route 9 (phase 3) are what joins Ridley Crossing and Wheaton to
  Bellerive. Rail, metro and the people mover are scenery (no trains yet).
- **P-5 Flat world.** Vehicles sit at y = 0 (vehicle.gd); there is no ground collider.
  Water is kept out by walls along every bank and the coast; bridges have parapet walls.
  Verdant Hills are hills in look only (vineyards, hedges, cypress), not in height.
- **P-6 The window opens.** City window walls and "road closed" boards go; the margin ring
  becomes drivable (`drive_node` uses `plan.bounds`), its silhouette blocks get colliders.
  Full detail (sidewalk people, places) stays inside the window.
- **P-7 Suburbs fill the rest of the Bellerive rect** (Magnolia Heights, Blackwater
  Bayou, the east side, the south shore, Brisa Beach): grid streets that carry on from the
  plan's frame-street junctions, so city streets run straight on into them.
- **P-8 One road graph.** Country junction ids are offset by `COUNTRY_BASE` (1 000 000);
  city.gd's road API (node_pos, next_nodes, nearest_node, route...) answers for both, so
  traffic, police, GPS and missions work unchanged.
- **P-9 Phase 2 landmarks inside the window move out to the edges** (the plan cannot take
  new landmarks without changing): see "Moved landmarks" below.
- **P-10 Parallel packages**: a kit agent writes `scripts/kits/country_kit.gd` (country,
  suburb and landmark buildings); a taxi agent writes the taxi service. The main session
  owns the generator, country layer, city changes, maps and gates.

- **P-11 Country ground is plain colour**, not the grass surface code: its mown stripes
  read as a lawn across whole fields. Suburb tree spacing 15-22 m, fields on a 25 m grid.
- **P-12 Margin silhouettes get plain box colliders** (city_cells `_outer_parcel`); the
  margin ring keeps silhouette detail, no people or places (those stay in the window).
- **P-13 The state map bake draws the margin ring's streets and every country road**
  (`StateMap.bake(origin, city)`, +25 ms at start), so the minimap past the window shows
  the drivable roads. Phase 2 pins now show on the state map (planned = phase above 2).

- **P-14 Country kit look**: no text or brand on any building; the hospital reads by a
  white H on blue, shops by awnings and colour. 41 kinds, one `build(kind, mb, rng)`.

- **P-15 Scripted drivers (taxis, getaways) follow the line between path points** with
  traffic's 9 m look-ahead, and back off and slide along a wall they are pinned on. A
  car running wide out of a corner used to scrape along kerb props forever.

## Moved landmarks

The plan cannot take new landmarks, so phase 2 landmarks that sat inside the window moved
just outside it (map metres, `data/world_map.json`): bellerive_general (7000,6420) north
edge; torque_tone_bellerive (7750,7300) east side; seaplane_base (7750,8300),
deco_row (7777,8345), brisa_promenade (7924,8335) on the Brisa coast; cruise_terminal
(6950,8590) on the south shore, with the Serena ferry and cruise route now starting at
(6950,8660). Brisa Beach's district rect is now [7580,7950,760,700].

## Open questions

- Respawn stays at the city clinic; the County Hospital in Wheaton is a building only.
- No country pedestrians or parked cars yet; traffic does drive out (population spawns on
  country junctions near the player). Traffic cruises at 13 m/s on every class.
- Wheaton's grid is axis-aligned, not turned to the diagonal Route 9.
- The Gulfline Metro is drawn only outside the plan; no airport yet (phase 4).
- No LOD for the country: tiles load inside 130 m (worker thread, ~5 ms each).
- Water-facing kit lots (cruise_terminal quay, seaplane_base pond) expect water at the
  lot's +Z; the generator does not yet turn those lots to face the water, so the quay
  faces the beach and the seaplane pond sits inland. Fix in build_country.py (yaw lots
  toward the nearest coast).

## Traps

- Godot 4.7.2; `game/tests/run.sh` after every game-code change.
- Plan dump: `godot --headless -s res://tests/plan_dump.gd -- out.json`; compare with the
  previous dump ignoring "ms".
- Regenerate the country after changing world_map.json or the plan:
  `python3 tools/build_country.py <plan dump>` (needs `pip install shapely`), preview with
  `tools/country_preview.py`.
- Build the A* graph only after the country loads: city.gd creates the country right
  after the plan, before places and parking (they can ask for routes).
- `prism()` expects clockwise-on-screen polygons; country_tiles `_cw()` fixes winding.
