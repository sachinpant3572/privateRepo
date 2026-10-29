# City outline: Bellerive is not a rectangle

Sachin, 2026-10-29: "Belleriv looks like a perfectly squared/rectangle city.
This is now how ideal cities looks, even if they are fully architected."
(Meaning: real cities, even fully planned ones, are not perfect rectangles.)

## Where the rectangle comes from (Explore report, 2026-10-29)

- Street graph: `street_plan.gd` clips all land to `bounds` (the window
  1300x1456 m grown 110 m) and runs a straight "frame" street 4 m inside it
  on all four sides (`:583-591`). Seams, Liberty Avenue and the river bank
  chains stop at that box.
- Country: `build_country.py` cuts the same box `P` out of the land
  (`:554`), bends highways onto frame junctions per side w/n/e/s (`:629-697`),
  builds the heights and fringe suburbs as axis-aligned boxes off `P.bounds`
  (`:711-719`, `:1023`, `:1101`), and the Beltway is a filleted rectangle.
- Edge look: outside the window, blocks are plain boxes on paved ground
  (`city_cells.gd:2131-2184`), with no sidewalks; heights are random per
  district, with no falloff toward the edge.
- Maps: the full map draws a white rectangle round the window
  (`full_map.gd:175-189`); the minimap clips to the window; the state map
  fills the city and district rects as boxes (`state_map.gd:91-96`).
- Already a stated rule, not met: MAP_BUILDING.md:121 "The playable edge
  follows the street pattern, not a square."
- Constraint: the city keeps its planned size, 4.7 km² (Sachin, 2026-10-28,
  HANDOFF-wealth.md:13). The outline may change shape, not grow.

## Options (cost)

- A, edge dressing only, about 3-4 h: density falloff, vacant lots, greens
  and parking along the edge, map outline removed. The straight frame
  street and the boxed suburbs stay, so the map still shows a rectangle.
  It does not answer the request.
- B, organic outline (chosen), about 10-14 h over this session:
  1. Outline polygon (`world_map.json` "outline"): about the same area,
     following the river and coast, pulled in by the hills, pushed out in
     fingers along the highways and the rail line, notched by parks and
     the docks. The window stays the street plan's working box.
  2. `street_plan.gd`: clip land to the polygon, not `bounds`; replace the
     frame street with an edge road that follows the outline (curved and
     broken, with streets running on out to the country); the outer blocks
     cut by the polygon become irregular.
  3. `build_country.py`: cut the polygon out instead of `P`; join highways
     where they meet the edge road (no square-on bends); suburbs grow out
     from the edge along roads and terrain, not as boxes; the Beltway
     follows the outline at a distance.
  4. Density: building height and kind fall off from the centres
     (downtown, Midtown) toward the edge; edge blocks get lower homes,
     yards, lots, sheds and greens.
  5. Maps, minimap and state map: draw the real outline, no rectangle.
  6. Tests that assume the rectangle (frame street carries on, window
     sampling, minimap uv) move to the polygon; new tests: the outline is
     not convex-box-like (area / bbox area under 0.8), no straight edge
     street longer than about 400 m, heights fall off with distance.
- C, a bigger city (option B of HANDOFF-bellerive-expand.md): not now, the
  size stays (Sachin, 2026-10-28).

## Order

- After 0.25.2 ships (APK, PR). Then this, then #98 wardrobe, then #97.

## Approach as built (2026-10-29)

- `world_map.json` bellerive `"core"`: the core polygon (world coords;
  local = world - (6150, 6650)). Bbox local (-300,-330)..(1660,1800),
  2.72 km² including the river; the old P box was 2.55 km².
- `street_plan.gd build(..., edge)`: the plan is laid out over
  bbox(core).grow(margin), then `_trim_to_outline(pins)` keeps each land
  face whose centre is in the core (plus the faces holding a landmark or
  the park), smooths 3 passes (a block with one kept or water side is a
  spur and goes; a land block with 3 kept sides is a notch and stays),
  and kills edges with no kept face. So the city ends block by block on
  real grid streets, never a sliver, and the frame street is gone.
- Results: `exits` (node where a dropped street went on, outward dir,
  class, road) for the country's roads to join; `edge_loops` (the outer
  face loops: north bank and south bank) as the footprint.
- Trap: the notch rule refills a one-row indentation and the spur rule
  drops a one-block bump, so polygon wiggles must be 2+ blocks wide or
  tall to show. Big east-side blocks (200 m) absorb small wiggles.
- Checks (`/tmp/co/edge.py` on a plan dump): plan4 land 2.42 km², bbox
  fill 0.61, longest straight edge run 380 m (+ a 407 m curved bank), 114
  exits.

## Built since (2026-10-29, second pass)

- `StreetPlan.in_city(p)` (inside an edge loop) and `edge_distance(p)`
  (to the core outline) replace window tests: district_at, playable,
  roadworks; `in_window` is true for every face once an outline exists.
- Density falloff (`city_cells.gd`): EDGE_OPEN 90, EDGE_LOW 150 (was 260).
  Downtown sits near the north-west edge, so a longer falloff flattened a
  third of it. Measured: downtown/midtown buildings within 110 m of the
  edge average 14 m against 22 m beyond 200 m.
- Maps: the bake is clear past the city (state map shows through); the
  minimap uses uv 0-1 of the whole bake; the full map draws the whole bake
  with no window ring; the state map fills the urban area from the plan.
- Bridge faces are kept in the trim. Rail routes that cross the country
  (stale country.json links) are split into one line per city run.
- Tests moved off the rectangle: grid bare-land check (edge loops),
  state map (alpha outside / at the station), roadside props (box probe),
  perspective camera (aimed at downtown towers). New
  `test_city_outline_is_organic`: 2.62 km², fill 0.66, longest straight
  380 m, 110 of 112 exits lead out, edge falloff 14 m vs 22 m.
- Country package: a background agent regenerates `build_country.py`,
  `country.json`, `country.gd`, `"urban"` in world_map.json and the
  country tests against the new edge (exits, polygon cut, suburbs, Beltway).
- Open until it lands: test_places_line_the_streets (Sunset Diner and
  Crescent Grocery doorsteps sit under old country tiles); the frame/links
  test and the traffic `plan.bounds` test belong to that package.
