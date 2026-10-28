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

## Golden Flats farmland (plan, 2026-10-28)

- F-1 **Where**: Golden Flats County (`world_map.json` region `golden_flats`), the flat land west of the
  Bellerive Hills between the Cinder Lower and the Morrow, and the strip between the Morrow and the
  hills' foot. Fields run right up to the mountain outline, where the ground is still flat (the heights
  fade in 220 m inside it), so the farmland meets the hills without a seam.
- F-2 **Roads** (`tools/farmland.py`): the Golden Flats Expressway (highway, 6 lanes) leaves the
  Beltway's north-west corner, bridges the Morrow and runs north-west past Wheaton and the grain
  elevators out of the play area; a 600 m section grid lined up with the map's existing county roads
  (x -1550/-950, y -1750/-1050): paved section roads (`road`) on the grid lines, dirt tracks (`track`)
  on some half-section lines, and a few curving dirt shortcuts across sections. Grid roads stop at the
  rivers (only the expressway and the map routes bridge them) and skip stretches that run alongside an
  existing road. Own RNG, so the rest of the country's lots do not shift more than the new roads make them.
- F-3 **Fields as ground zones**, not plots: the tile cutter already clips zones to the 100 m tiles, so
  a 270 m pivot circle never pops in half-drawn (plots stream by their centre's tile, LOAD_RADIUS 130).
  Centre-pivot circles (R 135/100/65: green alfalfa, gold wheat, bare) with wheel-track rings, and
  rectangular fields with crop rows as stripes (green rows, gold wheat, ploughed furrows); the corners
  between circles stay dry farmland, as in San Andreas' flats. The old 44 m square field cells stay in
  the Verdant Hills only.
- F-4 **Sprinkler arms**: one plot per span (<= 48 m, type `pivot`, part `sprinkler`), so each piece
  streams with its own tile: a truss on A-frame wheel towers, the pivot tower at the centre, an
  overhang at the end. Towers have small colliders.
- F-5 **Canals and pump houses**: concrete-lined canals (zones `canal`, `canal_bank`) beside two paved
  section roads from the Morrow west; a pump house (new country kit kind `pump_house`) at each canal's
  river end. Canals have no collision (a car can cross one): accepted, noted.
- F-6 **Farmsteads** come from the existing `farm_lots` along the new roads, with gravel drives,
  at least 520 m apart in the flats (one per road piece crowded out the pivots: 57 farmsteads).
- F-7 **County Road 10 bridges the Cinder Lower**: the land west of it (Ember Canyon Drive) was cut
  off from the road graph before this task (74 unreached nodes); now 0.
- F-8 Grid pieces that cannot reach the network (crossing it, or within join_ends' 90 m without
  crossing water) are dropped.

Measured: 22 pivots (59 spans), 75 paved section-road pieces, 37 dirt-track pieces, 2 pump houses,
16 farmhouses in the flats, 19 farmyards in all; 6737 nodes, 0 unreached; country.json 1.6 -> 3.9 MB
(about 48k field triangles; tiles stay small). Greens toned down after the first shots (they rendered
neon). Shots 65-72 (`SHOTS=farm`).

## Farm homes (Sachin, 2026-10-28: "All homes in the farmstead look the same ... add farmhouses, big and small ones")

- H-1 Four new country kit kinds: `farmhouse_big` (26x20: two storeys, a gabled wing stepping
  forward, wraparound porch, dormers, two chimneys), `farmhouse_small` (14x12 cottage: stoop and
  canopy, clothesline, vegetable patch), `ranch_house` (22x14: low hip roof, carport, split-rail
  fence), `adobe_farmhouse` (18x15: stucco, terracotta, portal with vigas, walled courtyard, agaves).
  The plain `farmhouse` now varies its roof (tin or shingles), porch (whole front or round the door),
  chimney end and kitchen-wing side.
- H-2 Houses are dealt from a shuffled deck per farm type (`FARM_HOUSES`), not rolled: plain odds
  rolls came out lopsided (4 big houses of 15 farms at 45% odds). Flats farms: big 4, plain 2,
  adobe 2, ranch 2 per deck; 45% add a hired hand's cottage. Hills: plain, adobe, small.
- H-3 Homesteads (`farmyard_layout("homestead")`, 44x38 fenced, a windpump or water tower on most)
  fill the flats roads between farms, 260 m or more from any farm or homestead.
- H-4 Suite failure from the farmland push fixed: section roads that ran out onto nothing at the
  flats' edge (`no road round the city stops dead`). `trim_farm_stubs` cuts them back to their last
  crossing (or makes one hung from its far end a dirt track), and `join_ends` no longer adds a join
  that runs back along the road's own line (it hid those ends).
- Measured: flats homes big 5, plain 7, small 16, ranch 10, adobe 8; 15 flats farms, 46 farmyards
  in all; 21 pivots; 6586 nodes, 0 unreached; country.json 3.8 MB. Gallery page `country_8_farmhouses.png`,
  shots 69a-69e.

## Traps

- (from the last task) Any change to the generator's RNG use shifts lots in every zone.
- A GDScript parse error makes a headless test run hang with no output: run
  `godot --headless --check-only --script res://<file>` on changed scripts first.

## Fences and size tiers (Sachin, 2026-10-28)

Asks: "place proper fencing or walls" round yards that differ from the land about them; "As the
farmhouse sizes get bigger, I see only minor changed in layour and structure ... different variations
as size progresses".
- L-1 `country_kit._lot_fence` (styles rail, split, picket, chain, wire, board, wall, low, hedge):
  farm homes, trailer, house (sides/back, suburb front lawns stay open), mansion (hedge, not in
  estate grounds), town hall, garden apartments, police, hospital, hangar, Hollis, Larkspur,
  Bellerive General. Paved and gravel commercial lots, moonshine, gator, condo and beach lots: open.
- T-1 `_tier(kind, w, d)`: lot area / usual area < 0.8 small plan, > 1.25 big plan. Plans:
  farmhouse cottage+dormer / two-storey / cross gable+ell+screened porch+garage+garden;
  big: flush one-storey wing / stepped wing+wrap porch / turret+ell+carriage house+gazebo;
  small: log cabin+outhouse+woodpile / cottage / +lean-to, hen house, shed;
  ranch: gable box+pad / hip+carport / L with forward wing, garage, patio; adobe: pueblo / L / hacienda.
  FOOTPRINTS farmhouse is now the in-game 16x14 (was 24x26) so gallery and tests sweep game sizes.
- T-2 Generator: farm-home lots cycle x0.85 / x1 / x1.3 per kind (`HOME_SCALES`, a Counter, not the
  rng, so no other zone shifts), x centre and front edge fixed, capped to each template's room; the
  flats gravel yard starts at the drive (x -12.5) so the big house fits. Every tier occurs in game
  (test_golden_flats_farmland checks it).
- T-3 Shortcuts: SHORTCUT_ODDS 0.12 -> 0.35 (7 shortcuts, 3 survived the area clip); paved/dirt
  alternate over the surviving pieces. Now 7 dirt + 5 paved curving pieces; 6703 nodes, 0 unreached.
- Test caps: kit test triangle cap 8000 for lots over 5000 m2 (Hollis with its wire fence).
