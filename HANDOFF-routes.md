# Handoff: a route from the road to every house

Sachin, 2026-10-28: "Ensure there are routes leading to all houses from the street or road, can be
single lane but there should be routes, match the route textures to the building and surroundings".

## Starting state (measured, scratchpad routes/reach.py)

Each home lot's front, measured straight ahead to the nearest road surface (`road_area`):
- street lots (house 812, garden_apartments 39, mansion 14, rowhouse_row): 1.0 m of bare ground
  between the lot's drive and the road;
- cape_house in its parcel: 9 m of lawn; farm homes in farmyards: 6 to 11.7 m, with the farmyard's
  front fence across it (its only gate is the farm drive);
- clusters (shacks, stilt houses, village houses, trailers): homes scattered 20 to 30 m back over a
  yard, with one track from the gate part way in; nothing joins a home to it;
- estates: the estate drive already runs from the road to the mansion.

## Decisions

- R-1 The generator exports per lot `reach` = [left, middle, right]: metres from the lot's front edge
  (x = -w/2, 0, +w/2) straight out to the road surface plus 0.6 m tucked under the road. It is 0 for
  lots with no road within 14 m ahead, or with another lot or plot in the way (own plot excepted).
  Lot array element 9.
- R-2 The kit owns the route's x and surface: `Kit.reach` (static, set by country_tiles before each
  build) is interpolated across the front, and `_lot_fence` draws a route out of every front gate;
  kits without a front fence call `_route_out` at their drive and walk. The surface matches the
  house: concrete for suburban homes, gravel for farmhouses, packed caliche for adobe, terracotta
  pavers for the hacienda, a dirt two-track for the cabin, asphalt for apartments.
  Routes sit 8 mm under the road top, so their tucked-in ends hide under the road.
- R-3 Farmyards: the front fence stops at each home lot's sides and jogs back to the home's own fence,
  so the home's gates open on the strip that leads to the road.
- R-4 Clusters: each home gets an apron along its front and a spur to the cluster track (new part
  kind `footpath`; variant 0 dirt, 1 gravel, 2 planks): planks for stilt houses in wet camps,
  gravel for trailers, dirt for the rest. Spurs are laid before the yard's extras so trees, boats
  and woodpiles keep off them.
- R-5 Checks: the generator counts home lots with no route (reach, cluster spur or estate drive) and
  must print 0; a test checks the same in the game data, and the kit test checks every drive meets a
  gate gap.

## Review fixes folded in (fences/tiers review, f4064ca)

- Flats farmyard homes capped to 26 m wide so the windbreak row (x0 + 3) stays outside their fence.
- Test: each farm-home kind builds a different plan at small, usual and big (the sets of solid
  heights differ; collider counts coincided for farmhouse_small and adobe, so counts were dropped).
- Shortcut surfaces alternate per shortcut, not per surviving piece.
- Note: SHORTCUT_ODDS reshuffles the rng for later zones (Saltgrass shacks, Verdant Hills mansions
  moved); HOME_SCALES alone does not.

## Routes review fixes (review of 5ec5ca4)

- Trailer parks: trailers faced away from the track, so every spur fell back to a straight strip
  under the trailer and through its fence. Trailers now face the track; `cluster_path` returns None
  when every way crosses a home and that home is left out (no rng drawn). The generator prints
  "cluster footpaths under a home" (must be 0), and the test checks the same per path.
  The changed yard spots move the rng for later zones (estates 21 to 19, farmyards 42 to 47).
- Hills: route pieces past a hill lot's front are cut into 1 m steps (`Kit.route_step`) and bent
  from the pad's height to the ground's at the road edge (`country_tiles._bend_routes`); the rigid
  lift skips them (`ctx.fixed`). The test finds the hill house whose road edge is furthest off its
  pad and checks route tops there sit on the ground.
- `Kit.routes_drawn` records only while `Kit.record_routes` is on (tests); the test lets the tile
  worker finish first (`country._finish_task`).
- A side ray that is blocked (lot, plot, water, rails) exports -1 (1 house today, by a rail bed).
  Kits that roll a drive side steer away from it (`_clear_side`: house, ranch, adobe). Otherwise
  `_route_out` leaves by the gate, runs 0.9 m deep along the front outside the fence to the clear
  middle third, and goes out there. The test builds every home kit with the left third blocked.
  (Second review: using max() of the two span ends still drew over the rails.)
- Composite farms (`_sub`) build their buildings with reach 0, so the farmhouse inside Hollis Farm
  draws no drive of its own through the farm's fence; the test asserts one route out.
- `_bend_routes` skips lots not lifted as a pad (pad height <= 0): the drape bends those already.
- The test builds a real tile and checks a street house's drive runs out (catches the tile no longer
  passing `Kit.reach`; mutation-checked, as is the hill bend).
- Adobe side-courtyard gate: its route runs on to the gate piers.

## Open questions / traps

- Parcel and block lawns sit at y 0.005, above a route drawn at -0.016: a route under its own plot's
  lawn vanishes. `_route_out` draws at 0.04 (drive height) and drops to -0.016 only for the last
  0.65 m tucked under the road.
- Town blocks facing the city (`_h_block` "frame" faces, inset 5): the city's frame street is 18 m
  wide on a line 4 m inside the plan bounds, so its outer 5 m lies inside the block. The block lawn
  used to cover that strip (3 to 5 m of grass between the rows' walks and the asphalt). The lawn and
  alley necks now stop at the street edge, and `lot_reach` counts the frame street as a road surface
  (CITY_STREET_W), so those 14 rows get reach 0.6.
- Farmyard front fence gaps and jog fences come before the mirror and use no rng, so farm layouts
  elsewhere did not move.
- Cluster spurs try 0/3/6/9 m out before turning to the track, so they clear neighbouring homes;
  they go into `taken` before the extras.
