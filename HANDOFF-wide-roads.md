# HANDOFF: wide roads, breakable props, Golden Flats farmland

Task (Sachin, 2026-10-28):
- "I think we need to increase road size in most of thr parts of belleriv, the flat part, so that two
  cars can comfortably drive along in the same lane, so that 4 cars can drive around in the same road at
  once comfortably, 2 in one lane 2 in opposite lane. I dont see this happening on ghe major roads. Some
  parts can have narrow roads, like inner streets, alleys etc, or road to mountains, but test shoulf be
  either 4 lane or 6 or 8 lane, 6 and 8 lane shoulf be for major highways and expressways."
- "Also, make the side props drstroyable by car and car wont stop after drstroying them, right now thr
  car stops after hitting the water controller, any small tree or lamppost etc, things that should
  easily be drstroyed in real life without affecting the speed that much."
- "we need to show sorawling irrigation fields too somewhere in the map, with major highways or
  espressways going through them, with shirtcuts in between, on paved and unpaved roads leading to
  farmhouses, or other buildings ... It can be near the mountains but flat ... see San Andreas map."

Order: wide roads (city, then country), then breakable props, then the fields. Follows
`HANDOFF-roads-mountain.md`.

## Starting state (measured)

- City classes (`street_plan.gd CLASSES`): boulevard 24 (median 6.4), bridge 16, avenue 15, river 14,
  street 11, quarter 9, lane 7 (walk only), quay 10. Traffic drives one lane per direction at
  `lane_offset(w) = max(2.4, w*0.22)`; avenues are painted as 2+2 but parked cars sit in the outer
  lane, so in play every road is one lane each way.
- Country classes (`build_country.py CLASSES`): highway 16, avenue 14, road 10, street 10, lane 7,
  track 6, trail 3.5. Every class is drawn and driven as one lane each way.

## Decisions

- W-1 **Lane counts by class** (lane 3.3-3.6 m; cars are 1.75-2.05 m wide, the box truck 2.5 m).
  Each class carries its lane geometry: lanes per direction, the middle (median or centre line) and
  the parking strip. City:
  | class | lanes | layout (half, from the middle out) | width |
  |---|---|---|---|
  | boulevard | 6 | median 3.2, 3 x 3.5, gutter 0.3 | 28 |
  | avenue | 4 | 0.2, 2 x 3.6, parking 2.4 | 20 (was 15) |
  | street | 4 | 0.2, 2 x 3.3, parking 2.2 | 18 (was 11) |
  | river | 4 | 0.2, 2 x 3.5, gutter 0.8 | 16 |
  | bridge | 4 | 0.2, 2 x 3.6, gutter 0.6 | 16 |
  | quay, quarter | 2 | narrow: the industrial quay and the old town's inner streets | 10, 9 |
  | lane | 0 | walking lane | 7 |
  Parked cars stay on streets and avenues, in the parking strip; none on boulevards, river, bridge.
  Rejected: 4-lane streets at 15 m with no parking strip (parked cars would block the curb lane, or
  the city would lose its parked cars).
- W-2 **Country**: a new `freeway` class (8 lanes) for the Bellerive Beltway; highway 6 lanes (Route
  1, 9, 40, Canyon Freeway, the Golden Flats expressway); avenue and suburb street 4 lanes; county
  roads, mountain roads, lanes, tracks and trails stay 2 lanes or fewer (Sachin: "road to mountains"
  may be narrow).
- W-3 **Traffic** keeps a lane: each car picks a lane on spawn and at each junction (clamped to the
  street's lane count); `lane_point(from, to, lane)`. Taxis and parking use the curb lane.
- W-4 **One width table**: every copy of the widths (plan_preview.py, build_country.py
  frame_junctions, mountain.py `_HALF`, `_merged_fit`'s -8.5) reads or is checked against the class
  table.

- W-5 **Country streets are all 4 lanes** (no separate 2-lane residential class): the cheaper option;
  a narrow suburb class can come later if the outskirts look over-paved.
- W-6 **Landmark lots shrunk to fit the wider streets**: union_station (40,32), aurum_tower (28,27),
  county_courthouse (50,36), federal_building (47,32), police_headquarters (42,32). Without it the
  courthouse was not placed and Aurum Tower merged a street away.
- W-7 **Breakable props** (`scripts/breakables.gd`): the prop kit tags each breakable prop's colliders
  with its vertex range in the cell's one mesh; a hit over 2.5 m/s turns the colliders off, collapses
  that range (`mesh_surface_update_vertex_region`), lays a plain toppled copy down, and plays
  `Fx.knock` (debris; leaves; sparks; a hydrant gushes for 6 s). The car keeps 82-92% of its speed.
  Props come back when the cell is rebuilt. Breakable: lamps, signals, street trees, crepe myrtles,
  hydrants, benches, bins, mailboxes, bike racks, signs, pay stations, chargers, cafe tables, crates,
  barrels. Solid on purpose: big oaks, palms, bollards, power poles, fences, planters, bus shelters.
- W-8 **Taxi ride start** (`taxi.gd plan_ride`): the ride starts toward the far end of the street the
  cab stands on, not the junction straight ahead of its nose: a cab pulled into the parking strip sits
  at an angle and the old cone search picked a junction on another street (it then drove into a block).

## Measured after the change

- Country: 5106 nodes, 633 roads, lots 2335 -> 2056 (fronting 1511 -> 1333), worst lot turn 2.75 deg,
  the same 74 unreached nodes as before. Mountain grades: freeway 10.7% steepest, Crest 18.8%.
- City plan: river roads shifted (RIVER_ROAD 10); minor streets lost to bigger blocks, accepted:
  x922 y987-1043, x1339 y935-987, quarter streets (229..330, 786) and (342,614)-(330,635); (125,500-578)
  avenue became a lane; (649..690, 789..805) quarter became a lane.
- Tests: two cars abreast on a street 3.3 m apart; parked cars 0 of 117 in a traffic lane; lamp,
  street tree, signal and hydrant knocked down at 16 m/s, car keeps 15.9-20.5 m/s. Suite 635/0.

## Traps

- (from the last task) Any change to the generator's RNG use shifts lots in every zone.
- A GDScript parse error makes a headless test run hang with no output: run
  `godot --headless --check-only --script res://<file>` on changed scripts first.
