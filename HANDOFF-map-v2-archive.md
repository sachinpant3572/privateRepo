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
