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
   - Patches: Gilt (big blocks, turned +6°), Lantern Quarter (tight,
     follows the river, slight curve), Floodline Wards (long shotgun
     blocks, turned -20°), Ironwharf (yards on wharves), Morrow Point (new,
     far bank).
   - Seams: Crescent Blvd (Gilt|Quarter), Rampart Ave (west|east),
     Wharf St (Wards|docks).
   - Long roads: Lantern Blvd (Union Station to the river, then the
     bridge), Liberty Avenue (the diagonal from Aurum Tower through the
     Crescent/Rampart junction to Ironwharf), and the river road, curved
     along the bank.
3. Morrow Bridge carries Lantern Blvd's line over the river to Morrow
   Point. Morrow Point is a new far-bank district: wards style, a levee
   road, and a ferry landing. demo_window grows to 25 x 28 blocks.
4. Blocks are faces of the graph, found by half-edge traversal.
   - inner = the face minus a strip for each road (Clipper).
   - lot = inner offset in by the sidewalk.
   - Building layouts still run in a rectangle: the largest one aligned
     with the front street that fits the lot. The leftover corners get
     trees and filler.
   - Slivers (too small for a rect) become small plazas or greens.
5. Minor streets are removed per patch to make T-junctions and long
   blocks. Each removal is kept only if the graph stays connected and no
   dead ends appear.
6. Traffic moves node to node (from, to) instead of along a Vector2i
   heading. pick_turn prefers going straight on, by angle.
7. Streaming: a cell is a land face, or an edge cell for an edge with no
   land face beside it (the bridge). Cells are found through a spatial
   hash of their centres.
8. Docks keep wharves on the water: their bank edges have class "quay" (a
   wall, not a road). Everywhere else the river road runs along the bank.
9. Bounds are the window rectangle, with barricades where roads cross it.
   A block is playable (full build with collisions) when it touches the
   window.

10. Liberty Green is a designed park: a 120 x 80 m quad on the north side
    of Liberty Avenue (nearest point to PARK_AT), with a street round its
    other three sides; district streets are clipped out of it. Rejected:
    carving streets out after thinning (left a 12 x 21 m face beside the
    avenue and jagged edges).
11. Landmark blocks: faces too small for a landmark's lot are joined with
    the neighbour that best improves the fit of the lot rect in the front
    frame (LANDMARK_LOTS, default 22 x 22). Rejected: joining by
    compactness (made a 34 x 399 m strip).
12. Thinning caps the joined block per patch (max extent along U and V and
    an area cap), with union-find over faces. `_hugs` drops patch lines that
    run alongside a region edge (they made slivers by the seams).
13. Magnolia Avenue: a curved avenue through Gilt west, so Gilt isn't one
    tilted grid. A frame street round bounds.grow(-4) closes outer blocks.
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
16. Connectivity check counts stranded junctions, not reachable nodes:
    the old count fell whenever a curved street went (its bend points went
    with it), so curved streets could never be thinned or merged.
17. _drop_overlaps after _simplify: a patch line almost in line with the
    frame street, straightened, overlapped it and a block went missing.
18. Parked cars face the way traffic runs in the near lane (curb_yaw was
    reversed). Homecoming's getaway parks at -34 so it pulls away from the
    other parked cars.
19. Landmark rect on its street: _landmark_rect tries each street side of
    a landmark block and keeps the rect whose middle lies on that side
    (largest_rect `reach`) with its top on the sidewalk; that side becomes
    the block's front. Before, a fanned block's rect could sit 40-80 m
    along from its front side, so the door, landmark_front and the curb
    spot landed mid-block (Drowned Streetcar shot in backyards).

## Port of the game (city, cells, traffic, maps)
- Cells: one per land/sliver face, plus an edge cell for each edge with no
  face either side (Morrow Bridge). Each edge is owned by the face on its
  first side, else its second, else its edge cell. Cell ids are ints into
  city.cells; a spatial hash (50 m) of cell centres finds cells near.
- Block layouts keep their rectangle frame: plan.lot_rect(f) in the front
  frame gives ctx.frame/hx/hz. Leftover lot (lot minus rect) gets trees,
  planters or barrels by style. Rect sides on water or quay are closed.
- Streets: one per edge, markings start at plan.clearance(). A side with
  no face (water) gets the road's outer half, a railing and a wall.
- Bridge: deck strip, parapets with colliders, piers, lamps.
- Bounds: walls along the window rect; barricades where a drivable edge
  crosses it. Playable block = face bbox touches the window.
- Traffic: (prev, next) node ids; lane_point(from, to); pick_turn by angle.
- Rail lines: {nodes, rusty}. Lantern Line follows the "lantern" edges from
  Union Station to the River Road; the drowned line is the A* path from the
  drowned streetcar to the depot (rusty).
- mesh_builder.flat triangulates (concave blocks); map_image fills
  polygons with an even-odd scanline.

## API mapping (old -> new)
- block Vector2i -> int face id; node Vector2i -> int node id.
- plan.corners(b) -> plan.face_poly(f).
- plan.side_class(b,k) -> plan.inner_sides(f)[k] {cls, edge}.
- edge_class(n,d) -> edge_class(e).
- in_grid(n) -> drive_node(n).
- lane_point(n,dir) -> lane_point(from,to).
- pick_turn(n,dir,rng) -> pick_turn(prev,cur,rng) -> next node.
- rail_lines -> [{nodes: PackedInt32Array, rusty}].

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
- Build time: about 0.8 s on desktop (thin and blocks are the big steps).
  Watch this on phones.
