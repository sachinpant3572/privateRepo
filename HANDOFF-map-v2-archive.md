# Map v2 handoff: archive

Finished history moved out of `HANDOFF-map-v2.md` to keep it under 150
lines. The port is done; this is for reading old code or old notes.

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
- plan.side_class(b,k) -> plan.side_class(f,k); edge ids in faces[f].sides.
- edge_class(n,d) -> edge_class(e).
- in_grid(n) -> drive_node(n).
- lane_point(n,dir) -> lane_point(from,to).
- pick_turn(n,dir,rng) -> pick_turn(prev,cur,rng) -> next node.
- rail_lines -> [{nodes: PackedInt32Array, rusty}].

## Decisions moved from the handoff
3. Morrow Bridge carries Lantern Blvd's line over the river to Morrow
   Point. Morrow Point is a new far-bank district: wards style and a
   levee road (a ferry landing is not built). demo_window grows to
   25 x 28 blocks.
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
17. _drop_overlaps after _simplify: a patch line almost in line with the
    frame street, straightened, overlapped it and a block went missing.
18. Parked cars face the way traffic runs in the near lane (curb_yaw was
    reversed). Homecoming's getaway parks at -34 so it pulls away from the
    other parked cars.
12. Thinning caps the joined block per patch (max extent along U and V and
    an area cap), with union-find over faces. `_hugs` drops patch lines that
    run alongside a region edge (they made slivers by the seams).
13. Magnolia Avenue: a curved avenue through Gilt west, so Gilt isn't one
    tilted grid. A frame street round bounds.grow(-4) closes outer blocks.
