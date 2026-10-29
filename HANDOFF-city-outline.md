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
