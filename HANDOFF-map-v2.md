# Map v2: Bellerive street network that doesn't read as a grid

Task: Sachin, Oct 27: "It does look like a grid for sure, please fix this.
Check how GTA team has their maps built up, see Watch Dogs maps too." Also:
FPS is 120 (keep it there); add both the bridge to the far bank and the
diagonal avenue. Research goes into reference/MAP_BUILDING.md section 6.

## Why 0.3 still reads as a grid
- Every block has four sides and every junction is a four-way crossing:
  the plan kept grid topology (Vector2i nodes) and only bent it.
- Streets within a district are parallel, so the full map is a fanned grid.

## Decisions
1. Replace the warped grid with a general planar street graph
   (street_plan.gd rewritten). Nodes and blocks get int ids. Cost: about
   2-3k lines touched across ~15 files, one long session. Rejected: keeping
   Vector2i and only adding diagonals; that leaves every block a quad and
   the grid look stays (same failure as 0.3).
2. How the graph is made: district patches plus seam roads, cut out and
   overlaid. This is how New Orleans grew (faubourgs, each with its own
   grid, meeting along seams like Canal and Esplanade), and how Ubisoft
   reshaped Chicago (curves, broken sightlines).
   - Patches: Gilt (big blocks, west half -9°, east +6°), Lantern Quarter (tight,
     follows the river, slight curve), Floodline Wards (long shotgun
     blocks, turned -25°), Ironwharf (yards on wharves), Morrow Point (new,
     far bank).
   - Seams: Crescent Blvd (Gilt|Quarter), Rampart Ave (west|east),
     Wharf St (Wards|docks).
   - Long roads: Lantern Blvd (Union Station to the river, then the
     bridge), Liberty Avenue (the diagonal from Aurum Tower through the
     Crescent/Rampart junction to Ironwharf), and the river road, curved
     along the bank.
3-9. Bridge, faces and lots, thinning, traffic, streaming, quays,
   bounds: see the archive.

10. Liberty Green is a designed park: a 120 x 80 m quad on the north side
    of Liberty Avenue (nearest point to PARK_AT), with a street round its
    other three sides; district streets are clipped out of it. Rejected:
    carving streets out after thinning (left a 12 x 21 m face beside the
    avenue and jagged edges).
11. Landmark blocks: faces too small for a landmark's lot are joined with
    the neighbour that best improves the fit of the lot rect in the front
    frame (LANDMARK_LOTS, default 22 x 22). Rejected: joining by
    compactness (made a 34 x 399 m strip).
12-13. Thinning caps, _hugs, Magnolia, frame street: see the archive.
14. Fan and cross-bend per patch (after a re-check against Watch Dogs'
    "too straight, too many right angles"): u-lines splay from the patch
    middle (`fan`) and curve (`bend_u`); `bend` is 2-3x stronger. Gilt
    West turned to -9 deg. Street length within 10 deg of the compass:
    51% -> 39%. Rejected: random per-line tilt (adjacent lines can cross).
15. largest_rect(poly, need): prefers a rect that holds `need`, then area.
    The grow step and the landmark blocks' final rect use it (an L-shaped
    block's largest rect is a strip). Grow tries options best-first, then
    pairs of neighbours (fanned blocks lean, so an L only fits once the
    fourth block fills it).
16. Connectivity: dropping a link is refused when its two ends are no
    longer joined by drivable streets (_joined, breadth first, stops in a
    few blocks). A count of reachable nodes fell whenever a curved street
    went (its bend points went too); a whole-map count per candidate was
    the slowest part of the build.
17-18. _drop_overlaps, parked cars: see the archive.
19. Landmark rect on its street: _landmark_rect tries each street side of
    a landmark block and keeps the rect whose middle lies on that side
    (largest_rect `reach`) with its top on the sidewalk; that side becomes
    the block's front. Before, a fanned block's rect could sit 40-80 m
    along from its front side, so the door, landmark_front and the curb
    spot landed mid-block (Drowned Streetcar shot in backyards).
20. Jogged cross streets (`jog` per patch, review 1 said Wards and Morrow
    Point still read as turned grids): a v-street piece between two
    u-streets steps 28-42% of the spacing sideways, so crossroads become
    offset T-junctions (T:X was 240:355 before jogs, 497:233 after all of
    map v2). A step only goes between two u-streets that made it into the
    plan (the hug filter drops some), with both its ends inside the
    district. The first try jogged towards dropped u-streets: those
    pieces dead-ended, were pruned, and left 280 m strip blocks. A 9 m
    step let thinning join two blocks by a neck, hence 28% minimum.
21. Bank chains run on to where the river band leaves the box. The band's
    vertices are 100 m+ apart; stopping at the last vertex inside left
    land east of Ironwharf and Morrow Point with no closing edge, so no
    block (water showed through).
22. Review 1 fixes: grow claims the faces it joins (stale faces within a
    pass); _landmark_rect falls back when no side fits; a boulevard
    median is skipped when shorter than 1 m (negative box on seed 99);
    _drop_overlaps only replaces a drivable street by a drivable path;
    join_traffic_here takes "came from" as the neighbour of the junction
    ahead that points back past the car.
23. Morrow Point halves turned +16 / -20 deg (were -10 / -4): every patch
    sat within about 25 deg of the compass (review 1). Within 10 deg of the
    compass: 38% -> 30%. No landmark is there. Rejected for now: turning
    the Wards or Quarter (landmarks and seams would move).
24. _drop_links finds all links before killing any (a shared T-junction
    looked like a bend once one link went, so the next ran through it),
    drops a stub the merge leaves, then checks dead ends and _joined
    (kept inside the window when an end is in it: a lane cut once left a
    junction reachable only through the margin).
    Thinning skips links under 24 m (jog steps). _drop_orphans removes
    streets with no block either side (seed 2024: a straightened frame
    street a metre from a district street). Bridge bends are always
    straightened (a merge nudged its end; 16 deg kink).

25. Bayou Road (review 2: the Wards were still one turned grid, 69% of
    their street length in one 30 deg band). A curved avenue east from
    Rampart, between Moreau House and Teo's Apartment (~140 m from each),
    is a seam: the Wards south of it stay at -25 deg (jog 0.45 -> 0.3),
    a new patch `wards_n` north of it runs at +12 deg with a fan and
    cross-bend. Wards share in their best 30 deg band (both street
    families): 97% -> about 51% (50-52% on seeds 1, 7, 42, 99, 2024). Rejected: only lowering the jog (the
    angle is what reads as a grid) and a second diagonal through the
    Wards (Liberty already crosses them).
26. _trim_close: a district street stretch within half a street gap of
    its district edge is cut out, unless it is an end that gets clear in
    under 2.5x that (meets the edge at more than ~24 deg). Bayou Road
    first had two 6-way junctions where curved Wards streets touched it
    at a tangent. _hugs still drops whole lines that run alongside.
    _ease_crowds: a junction of 5+ streets loses district links,
    shortest first, through _drop_links, down to 4 (a 7-way formed at
    Liberty Green's corner). Left: only Crescent/Liberty/Rampart (5).
27. Review 2 fixes: _tidy drops near-duplicates against the last kept
    point, then in-line points against kept neighbours until stable (it
    compared against dropped points and cut lot corners off, leaving bare
    triangles). _drop_links never drops a named road or the bridge as a
    stub, and checks every remaining end of the dropped links is joined
    to the others (a stub's far end went unchecked when the junction
    between them emptied). _joined searches from the end in the window.
28. Homecoming: the chase fails (with retry) if the thief's scooter is
    wrecked; before, the mission waited for it forever. The test skips to
    the chase end along the last street leg (the very last leg is the hop
    to the curb; stepping back along it put the scooter in a building).
    Bigger option not taken: the thief runs on foot to the Square.

## Port of the game and API mapping
Done; notes in `HANDOFF-map-v2-archive.md`.

## Open questions
- (none yet)

## Traps
- Clipper (Geometry2D) output orientation and point order are not
  guaranteed. Normalise to positive shoelace (clockwise on screen, y down).
- mesh_builder.flat used a fan, which is wrong for concave polygons.
  Switched to triangulate_polygon.
- Clipped patch lines end on seams to within float error. Extend them by
  1.5 m before intersecting, then prune stubs.
- The game builds with seed 1234 (main.gd); plan_dump.gd uses rough
  landmark points, so its plan differs a little. Check the game's plan.
- Tests that teleport along "x" assumed east-west streets; place things
  along the route or street instead.
- Build time: 0.65-0.9 (up to 1.1 under load) s on desktop (blocks ~0.2 s is the big step; thin
  was 0.25 s before _joined). Watch this on phones.
