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
