extends Node3D
## Bellerive demo map, built from the world map (res://data/world_map.json)
## and laid out by the street plan (street_plan.gd, see
## reference/MAP_BUILDING.md): a planar street graph made of district
## patches at their own angles, seam roads, Liberty Avenue, the River Road
## and Morrow Bridge to Morrow Point.
##
## Junctions ("nodes"), streets ("edges") and blocks ("faces") have the
## plan's int ids. Local (0, 0) is the window origin in world-map metres
## (map y = game z). The city streams in cells: one per block, plus one for
## each street with no block beside it (the bridge). Each street belongs to
## one cell. Cells are built on a worker thread as the focus moves and
## freed when far away; each one is a single mesh plus static bodies.
## Blocks touching the playable window get full detail and collisions;
## the rest of the plan (up to MARGIN metres out) is built as silhouettes so
## the city doesn't end at the edge of the screen. Traffic drives on the
## right.

const MeshBuilder = preload("res://scripts/mesh_builder.gd")
const Cells = preload("res://scripts/city_cells.gd")
const StreetPlan = preload("res://scripts/street_plan.gd")
const L = preload("res://scripts/layers.gd")

const MAP_PATH := "res://data/world_map.json"
const CITY_ID := "bellerive"
## The window is measured in blocks of this many metres (world_map.json).
const PITCH := 52.0
## A typical street's width, for code that needs a rough figure.
const ROAD := 11.0
const SIDEWALK := 3.0
## Pedestrians walk this far in from the curb.
const WALK_INSET := 1.2
## Liberty Green, the park, sits on Liberty Avenue nearest here (local
## metres): where the Quarter meets the Wards.
const PARK_AT := Vector2(830, 560)
## Parked cars sit this far out from the curb (their centre).
const PARK_FROM_CURB := 1.0
## Scenery round the window, in metres.
const MARGIN := 110.0
## Cells load when their bounding box comes this close, and unload past
## UNLOAD_RADIUS.
const LOAD_RADIUS := 105.0
const UNLOAD_RADIUS := 150.0
const CELL_GRID := 50.0
## Map districts by street plan patch (patch ids start with these).
const PATCH_DISTRICTS := {
	"gilt": "gilt_district", "quarter": "lantern_quarter", "wards": "floodline_wards",
	"docks": "ironwharf", "point": "morrow_point",
}

## Window size in blocks, from the map.
var blocks := Vector2i(25, 28)
## The playable area in local metres.
var window := Rect2()
var seed_value := 0
var rng := RandomNumberGenerator.new()
var plan
## Buildings in the cells that are currently loaded.
var building_count := 0
## One closed walking loop per playable land block, round the inside of its
## sidewalk.
var sidewalk_loops: Array[PackedVector3Array] = []
## [position, yaw] pairs for cars parked along the curbs. The first one is
## next to the spawn point.
var parked_spots: Array = []
var spawn_point := Vector3.ZERO
var hospital := Vector3.ZERO
var police_station := Vector3.ZERO
## World-map position of local (0, 0).
var map_origin := Vector2.ZERO
var districts: Array = []
## Streetcar lines: [{nodes: PackedInt32Array, rusty: bool}].
var rail_lines: Array = []
## Cells: {kind ("face" or "edge"), id (face or edge), box (Rect2, local
## metres), edges (PackedInt32Array, the streets it builds)}.
var cells: Array = []
## Node the streaming follows; the spawn point when unset.
var focus_node: Node3D
## Night light pools are drawn only after dark (see set_glow_visible).
var glow_visible := false

var _landmarks := {} # face -> {id, type, name}
var _map_landmarks: Array = [] # [{id, type, name, local}]
var _district_by_id := {}
var _river: PackedVector2Array
var _river_half := 80.0
var _loop_of_block := {}
var _cell_of_face := PackedInt32Array()
var _cell_grid := {} # Vector2i -> [cell]
var _rail_of_edge := {} # edge -> rail line index
var _loaded := {} # cell -> Node3D
var _task := -1
var _task_cell := 0
var _task_result: Dictionary
var _stream_tick := 0.0
var _astar: AStar2D


func build(seed_v: int) -> void:
	seed_value = seed_v
	rng.seed = seed_v
	_load_map()
	plan = StreetPlan.new()
	var spots: Array = []
	for lm in _map_landmarks:
		spots.append([lm.id, lm.local])
	var river := PackedVector2Array()
	for p in _river:
		river.append(p - map_origin)
	plan.build(window, MARGIN, seed_v, river, _river_half, spots, PARK_AT)
	for lm in _map_landmarks:
		var f: int = plan.face_of(lm.local)
		if plan.is_land(f) and not _landmarks.has(f) and not plan.is_park(f):
			_landmarks[f] = {"id": lm.id, "type": lm.type, "name": lm.name, "local": lm.local}
	_make_cells()
	_make_rails()
	for f in plan.faces.size():
		if plan.is_land(f) and in_window(f):
			_loop_of_block[f] = sidewalk_loops.size()
			sidewalk_loops.append(_make_loop(f))
	_place_points()
	_pick_parking()
	_build_water()
	_build_bounds()
	stream_now(spawn_point)


func _process(delta: float) -> void:
	_poll_task()
	_stream_tick -= delta
	if _stream_tick > 0.0:
		return
	_stream_tick = 0.2
	var focus := focus_node.global_position if is_instance_valid(focus_node) else spawn_point
	var p := Vector2(focus.x, focus.z)
	for cell in _loaded.keys():
		if _box_distance(cells[cell].box, p) > UNLOAD_RADIUS:
			_unload(cell)
	if _task < 0:
		for cell in _cells_near(focus, LOAD_RADIUS):
			if not _loaded.has(cell):
				_start_task(cell)
				break


## Builds every missing cell around `pos` right away (spawn, respawn, tests).
func stream_now(pos: Vector3) -> void:
	_finish_task()
	for cell in _cells_near(pos, LOAD_RADIUS):
		if not _loaded.has(cell):
			_add_cell(cell, Cells.build(self, cell))


func set_glow_visible(on: bool) -> void:
	glow_visible = on
	for cell in _loaded:
		var g: Node3D = _loaded[cell].get_node_or_null("Glow")
		if g:
			g.visible = on


func loaded_cells() -> Array:
	return _loaded.keys()


func cell_node(cell: int) -> Node3D:
	return _loaded.get(cell)


## The cell holding a local position (its block's cell), or -1.
func cell_at(pos: Vector3) -> int:
	var f := block_of(pos)
	return _cell_of_face[f] if f >= 0 else -1


## Cell that builds block f.
func cell_of_face(f: int) -> int:
	return _cell_of_face[f]


# --- Map queries ---------------------------------------------------------------

## The map district at a local position: the district of the street plan
## patch there, else the map's district rectangles (nearest one outside
## them all).
func district_at(pos: Vector3) -> Dictionary:
	var local := Vector2(pos.x, pos.z)
	var f: int = plan.face_of(local)
	var patch: String = plan.face_patch(f) if f >= 0 else plan.patch_at(local)
	if patch != "":
		var id: String = PATCH_DISTRICTS.get(patch.get_slice("_", 0), "")
		if _district_by_id.has(id):
			return _district_by_id[id]
	var p := map_origin + local
	var best := {}
	var best_d := INF
	for d in districts:
		var r: Rect2 = d.rect
		if r.has_point(p):
			return d
		var dist := r.get_center().distance_to(p)
		if dist < best_d:
			best_d = dist
			best = d
	return best


func landmark_at(f: int) -> Dictionary:
	return _landmarks.get(f, {})


## Block holding the map landmark `id`, or -1.
func landmark_block(id: String) -> int:
	for f in _landmarks:
		if _landmarks[f].id == id:
			return f
	return -1


## In-window landmarks for the maps: [{id, type, name, pos}].
func landmarks() -> Array:
	var list: Array = []
	for f in _landmarks:
		if not in_window(f):
			continue
		var lm: Dictionary = _landmarks[f].duplicate()
		lm["pos"] = block_center(f)
		list.append(lm)
	if plan.park_face >= 0:
		list.append({"id": "liberty_green", "type": "park", "name": "Liberty Green", "pos": block_center(plan.park_face)})
	return list


## A frame on block f's street front: origin on the front sidewalk in front
## of the middle of the lot, basis.x along the street (left to right as seen
## from the street), basis.z pointing out across the street. Landmarks face
## it.
func front_frame(f: int) -> Transform3D:
	var ff: Transform2D = plan.front_frame2d(f)
	var r: Rect2 = plan.lot_rect(f)
	var mid := ff * Vector2(r.get_center().x, -WALK_INSET)
	var x := Vector3(ff.x.x, 0, ff.x.y)
	var z := Vector3(ff.y.x, 0, ff.y.y)
	return Transform3D(Basis(x, Vector3.UP, z), Vector3(mid.x, 0, mid.y))


## Same, for a landmark (Transform3D.IDENTITY if it isn't placed).
func landmark_frame(id: String) -> Transform3D:
	var f := landmark_block(id)
	return front_frame(f) if f >= 0 else Transform3D.IDENTITY


## On the sidewalk in front of a landmark (where people meet), or
## Vector3.INF if the landmark isn't placed.
func landmark_front(id: String) -> Vector3:
	var f := landmark_block(id)
	if f < 0:
		return Vector3.INF
	return front_frame(f).origin


## In the street in front of a landmark, `along` metres to the right, in
## the near lane (where cars stop or park).
func landmark_curb(id: String, along := 0.0) -> Vector3:
	var f := landmark_block(id)
	if f < 0:
		return Vector3.INF
	return curb_point(f, along)


func curb_point(f: int, along := 0.0) -> Vector3:
	var fr := front_frame(f)
	return fr.origin + fr.basis.x * along + fr.basis.z * (WALK_INSET + PARK_FROM_CURB)


## Yaw for a car parked in front of block f, facing the way traffic runs in
## the near lane (curb on its right; front frame -x).
func curb_yaw(f: int) -> float:
	var x := front_frame(f).basis.x
	return atan2(x.x, x.z)


## A block is playable (full detail, collisions, people) when it touches
## the window.
func in_window(f: int) -> bool:
	return f >= 0 and (plan.faces[f].bbox as Rect2).intersects(window)


## A block with a sidewalk and a lot (not a traffic island).
func block_land(f: int) -> bool:
	return plan.is_land(f)


## "sliver" for traffic islands, "green" for the park, the landmark type if
## the map puts one in this block, else the district style.
func block_style(f: int) -> String:
	if not plan.is_land(f):
		return "sliver"
	if plan.is_park(f):
		return "green"
	if _landmarks.has(f):
		return _landmarks[f].type
	return district_style(f)


## The style of the district block f is in ("quarter", "wards", ...).
func district_style(f: int) -> String:
	return district_at(_v3(plan.faces[f].center)).get("style", "quarter")


## Middle of block f's lot rectangle (its centre for traffic islands).
func block_center(f: int) -> Vector3:
	var r: Rect2 = plan.lot_rect(f)
	if r.size.x <= 0.0:
		return _v3(plan.faces[f].center)
	return _v3(plan.front_frame2d(f) * r.get_center())


func block_of(pos: Vector3) -> int:
	return plan.face_of(Vector2(pos.x, pos.z))


## Index into rail_lines of the line running along street e, or -1.
func rail_on(e: int) -> int:
	return _rail_of_edge.get(e, -1)


static func _v3(p: Vector2) -> Vector3:
	return Vector3(p.x, 0.0, p.y)


# --- Road graph helpers used by traffic, police and spawning -------------------

func node_pos(n: int) -> Vector3:
	return _v3(plan.pos(n))


## A junction cars can use: on a drivable street, inside the window.
func drive_node(n: int) -> bool:
	return n >= 0 and plan.degree(n) > 0 and window.grow(2.0).has_point(plan.pos(n))


func nearest_node(pos: Vector3) -> int:
	var p := Vector2(pos.x, pos.z)
	for r in [40.0, 100.0, 250.0, 700.0]:
		var best := -1
		var best_d := INF
		for n in plan.nodes_near(p, r):
			if not drive_node(n):
				continue
			var d: float = plan.pos(n).distance_squared_to(p)
			if d < best_d:
				best_d = d
				best = n
		if best >= 0:
			return best
	return -1


## Where a car driving from junction `from` to `to` should aim: the
## right-hand lane of that street, at `to`. `from` may be -1 (just the
## junction).
func lane_point(from: int, to: int) -> Vector3:
	if from < 0 or from == to:
		return node_pos(to)
	var seg := (node_pos(to) - node_pos(from)).normalized()
	var right := Vector3(-seg.z, 0.0, seg.x)
	var e: int = plan.edge_between(from, to)
	var w: float = plan.edge_width(e) if e >= 0 else ROAD
	return node_pos(to) + right * lane_offset(w)


## The right-hand lane at junction `at`, setting off towards `toward`.
func lane_start(at: int, toward: int) -> Vector3:
	var seg := (node_pos(toward) - node_pos(at)).normalized()
	var right := Vector3(-seg.z, 0.0, seg.x)
	var e: int = plan.edge_between(at, toward)
	var w: float = plan.edge_width(e) if e >= 0 else ROAD
	return node_pos(at) + right * lane_offset(w)


## Distance from the centreline to the middle of the right-hand lane.
static func lane_offset(width: float) -> float:
	return maxf(2.4, width * 0.22)


## Drivable neighbours of junction n inside the window.
func next_nodes(n: int) -> Array:
	var out: Array = []
	for e in plan.edges_of(n):
		if plan.drivable(e):
			var m: int = plan.other(e, n)
			if drive_node(m):
				out.append(m)
	return out


## Picks where to go after arriving at `cur` from `prev`: mostly straight
## on, never back unless it is a dead end.
func pick_turn(prev: int, cur: int, rand: RandomNumberGenerator) -> int:
	var din := Vector2.ZERO
	if prev >= 0 and prev != cur:
		din = (plan.pos(cur) - plan.pos(prev)).normalized()
	var options: Array = []
	var sharp: Array = []
	for m in next_nodes(cur):
		if m == prev:
			continue
		var c := din.dot((plan.pos(m) - plan.pos(cur)).normalized())
		if c < -0.6:
			sharp.append(m)
			continue
		options.append(m)
		if c > 0.85:
			options.append(m) # straight on is twice as likely
	if options.is_empty():
		options = sharp
	if options.is_empty():
		return prev if prev >= 0 else cur
	return options[rand.randi() % options.size()]


func random_node_between(center: Vector3, min_d: float, max_d: float, rand: RandomNumberGenerator) -> int:
	var c := Vector2(center.x, center.z)
	var found: Array = []
	for n in plan.nodes_near(c, max_d):
		var d: float = plan.pos(n).distance_to(c)
		if d >= min_d and d <= max_d and drive_node(n):
			found.append(n)
	if found.is_empty():
		return -1
	return found[rand.randi() % found.size()]


## Returns [loop index, point index] of a sidewalk point in the distance band,
## or an empty array if none was found.
func random_sidewalk_between(center: Vector3, min_d: float, max_d: float, rand: RandomNumberGenerator) -> Array:
	var near: Array = []
	for f in plan.faces_near(Vector2(center.x, center.z), max_d):
		if _loop_of_block.has(f):
			near.append(_loop_of_block[f])
	if near.is_empty():
		return []
	for attempt in 24:
		var li: int = near[rand.randi() % near.size()]
		var loop := sidewalk_loops[li]
		var pi := rand.randi() % loop.size()
		var d := loop[pi].distance_to(center)
		if d >= min_d and d <= max_d:
			return [li, pi]
	return []


func nearest_sidewalk(pos: Vector3) -> Array:
	var best := [0, 0]
	var best_d := INF
	for r in [30.0, 90.0, 300.0, 1500.0]:
		for f in plan.faces_near(Vector2(pos.x, pos.z), r):
			var li: int = _loop_of_block.get(f, -1)
			if li < 0:
				continue
			var loop := sidewalk_loops[li]
			for pi in loop.size():
				var d := loop[pi].distance_squared_to(pos)
				if d < best_d:
					best_d = d
					best = [li, pi]
		if best_d < INF:
			break
	return best


## Shortest drive along the streets, as points from `from` to `to` (for the
## GPS line on the maps).
func route(from: Vector3, to: Vector3) -> PackedVector3Array:
	var pts := PackedVector3Array([from])
	for n in route_nodes(from, to):
		pts.append(node_pos(n))
	pts.append(to)
	return pts


## The junctions of the shortest drive from near `from` to near `to`.
func route_nodes(from: Vector3, to: Vector3) -> PackedInt64Array:
	if _astar == null:
		_build_astar()
	var a := nearest_node(from)
	var b := nearest_node(to)
	if a < 0 or b < 0:
		return PackedInt64Array()
	return _astar.get_id_path(a, b)


## Like route(), but through the right-hand lane at each junction, for
## scripted drivers.
func route_lanes(from: Vector3, to: Vector3) -> PackedVector3Array:
	var nodes := route_nodes(from, to)
	var pts := PackedVector3Array()
	for k in nodes.size():
		if k == 0:
			pts.append(lane_start(nodes[0], nodes[1]) if nodes.size() > 1 else node_pos(nodes[0]))
		else:
			pts.append(lane_point(nodes[k - 1], nodes[k]))
	pts.append(to)
	return pts


func _build_astar() -> void:
	_astar = AStar2D.new()
	for n in plan.node_count():
		if drive_node(n):
			_astar.add_point(n, plan.pos(n))
	for e in plan.edge_count():
		var a: int = plan.edge_a[e]
		var b: int = plan.edge_b[e]
		if plan.drivable(e) and drive_node(a) and drive_node(b) and plan.edge_between(a, b) == e:
			_astar.connect_points(a, b)


# --- Setup ---------------------------------------------------------------------

func _load_map() -> void:
	var world: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MAP_PATH))
	var city: Dictionary = {}
	for c in world.cities:
		if c.id == CITY_ID:
			city = c
	var win: Dictionary = city.demo_window
	assert(is_equal_approx(win.pitch, PITCH), "demo_window pitch must match PITCH")
	blocks = Vector2i(int(win.blocks[0]), int(win.blocks[1]))
	window = Rect2(Vector2.ZERO, Vector2(blocks) * PITCH)
	map_origin = Vector2(win.origin[0], win.origin[1])
	for d in city.districts:
		var entry := {
			"id": d.id, "name": d.name, "style": d.style, "faction": d.faction,
			"rect": Rect2(d.rect[0], d.rect[1], d.rect[2], d.rect[3]),
		}
		districts.append(entry)
		_district_by_id[d.id] = entry
	for lm in world.landmarks:
		var local := Vector2(lm.pos[0], lm.pos[1]) - map_origin
		if window.has_point(local):
			_map_landmarks.append({"id": lm.id, "type": lm.type, "name": lm.name, "local": local})
	for w in world.water:
		if w.id == "morrow":
			_river_half = w.width * 0.5
			for p in w.line:
				_river.append(Vector2(p[0], p[1]))


## One cell per block; each street goes to the block on its first side,
## else the one on its second, else a cell of its own.
func _make_cells() -> void:
	var count: int = plan.faces.size()
	_cell_of_face.resize(count)
	var owned: Array = []
	for f in count:
		_cell_of_face[f] = f
		cells.append({"kind": "face", "id": f, "box": plan.faces[f].bbox, "edges": PackedInt32Array()})
	for e in plan.edge_count():
		var slots: Vector2i = plan.edge_face[e]
		var owner := slots.x if slots.x >= 0 else slots.y
		if owner >= 0:
			cells[owner].edges.append(e)
			continue
		var a: Vector2 = plan.pos(plan.edge_a[e])
		var b: Vector2 = plan.pos(plan.edge_b[e])
		var box := Rect2(a, Vector2.ZERO).expand(b).grow(plan.edge_width(e))
		cells.append({"kind": "edge", "id": e, "box": box, "edges": PackedInt32Array([e])})
	for c in cells.size():
		var r: Rect2 = cells[c].box
		for gx in range(floori(r.position.x / CELL_GRID), floori(r.end.x / CELL_GRID) + 1):
			for gy in range(floori(r.position.y / CELL_GRID), floori(r.end.y / CELL_GRID) + 1):
				var key := Vector2i(gx, gy)
				if not _cell_grid.has(key):
					_cell_grid[key] = []
				_cell_grid[key].append(c)


## The Lantern Line runs down Lantern Boulevard from Union Station to the
## river; the drowned line, rusty and long out of use, from the drowned
## streetcar to the old depot.
func _make_rails() -> void:
	rail_lines = []
	var station := landmark_block("union_station")
	if station >= 0:
		var c := Vector2(block_center(station).x, block_center(station).z)
		var start := -1
		var best := INF
		for n in plan.nodes_near(c, 160.0):
			if _road_edges(n, "lantern").is_empty():
				continue
			var d: float = plan.pos(n).distance_to(c)
			if d < best:
				best = d
				start = n
		if start >= 0:
			var nodes := PackedInt32Array([start])
			var prev := -1
			var cur := start
			for guard in 200:
				var nxt := -1
				for e in _road_edges(cur, "lantern"):
					var m: int = plan.other(e, cur)
					if m != prev and (prev >= 0 or plan.pos(m).y > plan.pos(cur).y):
						nxt = m
				if nxt < 0:
					break
				nodes.append(nxt)
				prev = cur
				cur = nxt
				if not _road_edges(cur, "river_road").is_empty():
					break
			_add_rail(nodes, false)
	var drowned := landmark_block("drowned_streetcar")
	var depot := landmark_block("streetcar_depot")
	if drowned >= 0 and depot >= 0:
		var path := route_nodes(front_frame(drowned).origin, front_frame(depot).origin)
		_add_rail(PackedInt32Array(Array(path)), true)


func _road_edges(n: int, road: String) -> Array:
	var out: Array = []
	for e in plan.edges_of(n):
		if plan.edge_road[e] == road:
			out.append(e)
	return out


func _add_rail(nodes: PackedInt32Array, rusty: bool) -> void:
	if nodes.size() < 2:
		return
	var k := rail_lines.size()
	rail_lines.append({"nodes": nodes, "rusty": rusty})
	for i in nodes.size() - 1:
		var e: int = plan.edge_between(nodes[i], nodes[i + 1])
		if e >= 0 and not _rail_of_edge.has(e):
			_rail_of_edge[e] = k


## Spawn in front of Union Station, respawns in front of the precinct and the
## clinic: all on the landmarks' street-front sidewalks.
func _place_points() -> void:
	spawn_point = landmark_front("union_station")
	police_station = landmark_front("bpd_lantern")
	hospital = landmark_front("floodline_clinic")
	if spawn_point == Vector3.INF:
		spawn_point = node_pos(nearest_node(_v3(window.get_center())))
	if police_station == Vector3.INF:
		police_station = spawn_point
	if hospital == Vector3.INF:
		hospital = spawn_point


## The walking loop round block f: just inside its sidewalk's outer edge.
func _make_loop(f: int) -> PackedVector3Array:
	var inner: PackedVector2Array = plan.inner(f)
	var poly: PackedVector2Array = StreetPlan._largest(Geometry2D.offset_polygon(inner, -WALK_INSET, Geometry2D.JOIN_MITER))
	if poly.size() < 3:
		poly = inner
	if StreetPlan.area(poly) < 0.0:
		poly.reverse()
	var loop := PackedVector3Array()
	for k in poly.size():
		var a := poly[k]
		var e := poly[(k + 1) % poly.size()]
		var steps := maxi(1, int(a.distance_to(e) / 6.0))
		for s in steps:
			loop.append(_v3(a.lerp(e, float(s) / steps)))
	return loop


func _pick_parking() -> void:
	# Always leave one car at the curb in front of the spawn point.
	var home := landmark_block("union_station")
	if home >= 0:
		parked_spots.append([curb_point(home, 9.0), curb_yaw(home)])
	else:
		parked_spots.append([spawn_point + Vector3(9, 0, 4), -PI / 2])
	for e in plan.edge_count():
		var a_n: int = plan.edge_a[e]
		var b_n: int = plan.edge_b[e]
		if not (plan.drivable(e) and drive_node(a_n) and drive_node(b_n)) or rng.randf() > 0.25:
			continue
		var cls: String = plan.edge_class(e)
		if cls == "quarter" or cls == "bridge" or rail_on(e) >= 0:
			continue # too narrow to park and pass, or no curb
		var a := node_pos(a_n)
		var b := node_pos(b_n)
		var s0: float = plan.clearance(a_n, e) + 6.0
		var s1: float = plan.clearance(b_n, e) + 6.0
		var length := a.distance_to(b)
		if length - s0 - s1 < 8.0:
			continue
		var along := (b - a) / length
		var right := Vector3(-along.z, 0, along.x)
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		var w: float = plan.edge_width(e)
		var p := a + along * rng.randf_range(s0, length - s1) + right * side * (w * 0.5 - PARK_FROM_CURB)
		if not plan.is_land(block_of(p + right * side * 4.0)):
			continue # no curb on that side (water)
		var facing := along * side
		parked_spots.append([p, atan2(-facing.x, -facing.z)])


## One water plane under the whole map; land is built on top of it.
func _build_water() -> void:
	var mb := MeshBuilder.new()
	var r: Rect2 = plan.bounds.grow(300.0)
	mb.box(_v3(r.get_center()) + Vector3(0, -0.55, 0), Vector3(r.size.x, 0.1, r.size.y), Color(0.16, 0.36, 0.42))
	var inst := mb.make_instance()
	inst.name = "Water"
	inst.material_override = MeshBuilder.water_material()
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)


## Invisible walls along the window's edge (the cells put barricades where
## streets cross it).
func _build_bounds() -> void:
	var body := StaticBody3D.new()
	body.name = "Bounds"
	body.collision_layer = L.WORLD
	body.collision_mask = 0
	add_child(body)
	var w := window
	var c := window.get_center()
	for side in [[Vector2(c.x, w.position.y - 0.5), Vector2(w.size.x + 2.0, 1.0)], [Vector2(c.x, w.end.y + 0.5), Vector2(w.size.x + 2.0, 1.0)],
			[Vector2(w.position.x - 0.5, c.y), Vector2(1.0, w.size.y + 2.0)], [Vector2(w.end.x + 0.5, c.y), Vector2(1.0, w.size.y + 2.0)]]:
		var at: Vector2 = side[0]
		var size: Vector2 = side[1]
		_add_shape(body, Vector3(at.x, 3.0, at.y), Vector3(size.x, 6.0, size.y))


# --- Streaming -----------------------------------------------------------------

static func _box_distance(r: Rect2, p: Vector2) -> float:
	var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
	return q.distance_to(p)


## Cells whose bounding box is within `radius` of `pos`, nearest first.
func _cells_near(pos: Vector3, radius: float) -> Array:
	var p := Vector2(pos.x, pos.z)
	var seen := {}
	var found: Array = []
	for gx in range(floori((p.x - radius) / CELL_GRID), floori((p.x + radius) / CELL_GRID) + 1):
		for gy in range(floori((p.y - radius) / CELL_GRID), floori((p.y + radius) / CELL_GRID) + 1):
			for c in _cell_grid.get(Vector2i(gx, gy), []):
				if seen.has(c):
					continue
				seen[c] = true
				if _box_distance(cells[c].box, p) <= radius:
					found.append(c)
	found.sort_custom(func(a, b): return _box_distance(cells[a].box, p) < _box_distance(cells[b].box, p))
	return found


func _start_task(cell: int) -> void:
	_task_cell = cell
	_task = WorkerThreadPool.add_task(_run_task.bind(cell), false, "city cell")


func _run_task(cell: int) -> void:
	_task_result = Cells.build(self, cell)


func _poll_task() -> void:
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		_finish_task()


func _finish_task() -> void:
	if _task < 0:
		return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	if not _loaded.has(_task_cell):
		_add_cell(_task_cell, _task_result)
	_task_result = {}


func _add_cell(cell: int, built: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "Cell_%d" % cell
	if built.mesh.triangle_count() > 0:
		var inst: MeshInstance3D = built.mesh.make_instance()
		inst.material_override = MeshBuilder.cutaway_material()
		root.add_child(inst)
	if built.glow.triangle_count() > 0:
		var glow: MeshInstance3D = built.glow.make_instance()
		glow.name = "Glow"
		glow.material_override = MeshBuilder.glow_material()
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glow.visible = glow_visible
		root.add_child(glow)
	for group in [[built.colliders, L.WORLD], [built.props, L.PROPS]]:
		if group[0].is_empty():
			continue
		var body := StaticBody3D.new()
		body.collision_layer = group[1]
		body.collision_mask = 0
		root.add_child(body)
		for c in group[0]:
			_add_shape(body, c[0], c[1], c[2] if c.size() > 2 else 0.0)
	root.set_meta("buildings", built.buildings)
	building_count += built.buildings
	add_child(root)
	_loaded[cell] = root


func _unload(cell: int) -> void:
	var root: Node3D = _loaded[cell]
	building_count -= int(root.get_meta("buildings"))
	_loaded.erase(cell)
	root.queue_free()


func _add_shape(body: StaticBody3D, center: Vector3, size: Vector3, yaw := 0.0) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = center
	shape.rotation.y = yaw
	body.add_child(shape)


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
