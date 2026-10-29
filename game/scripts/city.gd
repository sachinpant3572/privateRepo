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
const Places = preload("res://scripts/places.gd")
const Country = preload("res://scripts/country.gd")

const MAP_PATH := "res://data/world_map.json"
const CITY_ID := "bellerive"
## The window is measured in blocks of this many metres (world_map.json).
const PITCH := 52.0
## One lane each way, on a link between the plan and the country.
const LINK_LANES := {"lanes": 1, "lane_w": 3.6, "middle": 0.6, "park": 0.0}
const SIDEWALK := 3.0
## Pedestrians walk this far in from the curb.
const WALK_INSET := 1.2
## Liberty Green, the park, sits on Liberty Avenue nearest here (local
## metres): where the Quarter meets the Wards.
const PARK_AT := Vector2(870, 356)
## Parked cars sit this far out from the curb (their centre).
const PARK_FROM_CURB := 1.0
## Scenery round the window, in metres.
const MARGIN := 110.0
## Cells load when their bounding box comes this close, and unload past
## UNLOAD_RADIUS. Static so a far-seeing camera (Settings > Zoom, the camera
## demo) can widen them.
static var LOAD_RADIUS := 105.0
static var UNLOAD_RADIUS := 150.0
const CELL_GRID := 50.0
## Map districts by street plan patch (patch ids start with these).
## Country junction ids are offset by this in the road API below, so one
## graph covers the street plan and the country (country.gd).
const COUNTRY_BASE := 1_000_000
## A town counts as the district round it this far out.
const TOWN_RADIUS := 420.0
const PATCH_DISTRICTS := {
	"gilt": "gilt_district", "midtown": "midtown", "quarter": "lantern_quarter", "wards": "floodline_wards",
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
## Shops and diners the player can walk into (places.gd).
var places: Array = []
## Node the streaming follows; the spawn point when unset.
var focus_node: Node3D
## The camera: cells also load round the middle of the screen
## (stream_point), which runs ahead of a fast car.
var view_source: Node
## Night light pools are drawn only after dark (see set_glow_visible).
var glow_visible := false

var _landmarks := {} # face -> {id, type, name}
var _place_by_parcel := {} # Vector2i(face, parcel) -> place
var _map_landmarks: Array = [] # [{id, type, name, local}]
var _district_by_id := {}
var _river: PackedVector2Array
var _river_half := 80.0
var _loop_of_block := {}
## Suburb sidewalk loops by WALK_CELL grid cell (Vector2i -> loop indices);
## they follow the plan's loops in `sidewalk_loops`.
var _walk_grid := {}
const WALK_CELL := 100.0
var _cell_of_face := PackedInt32Array()
var _cell_grid := {} # Vector2i -> [cell]
var _rail_of_edge := {} # edge -> rail line index
## Roadworks (Sachin: "some are being paved so there is a construction
## sign, to avoid it, otherwise the cars can get stuck"): edge ->
## {"side", "x0", "x1"}, the curb lane and parking strip dug up on the side
## `side` of the street frame (+1 the right of a->b, where a->b traffic
## drives; -1 the other) from x0 to x1 metres along from a. That way's
## traffic keeps to its other lanes along the whole street (lanes_of); the
## cell builder draws the barriers, cones, sign and the pit.
var roadworks := {}
var _works_lanes := {} # Vector2i(from, to) -> the lanes left open that way
const WORKS_CLASSES := ["boulevard", "avenue", "river", "street"]
## No works this near the spawn (the tests' and the first drive's streets).
const WORKS_CLEAR_OF_SPAWN := 260.0
## Works stand this far apart at least, two or three to a district.
const WORKS_SPACING := 180.0
## Cones taper the closed lane in over this many metres ahead of the pit.
const WORKS_TAPER := 8.0
var _loaded := {} # cell -> Node3D
var _task := -1
var _task_cell := 0
var _task_result: Dictionary
var _stream_tick := 0.0
var _astar: AStar2D
## The streamed country past the plan's edge (country.gd).
var country
## Map landmarks outside the window ({id, type, name, local}): built in the
## country when it has a lot for them.
var _outer_landmarks: Array = []
## Phase 2 regions ({id, name, style, faction, poly (map metres)}) and the
## country's towns ({id, name, style, faction, local}).
var _regions: Array = []
var _towns: Array = []
## The built-up city's edge in local metres (world_map.json "core"): the
## street plan keeps the blocks inside it.
var core_outline := PackedVector2Array()


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
	plan.build(window, MARGIN, seed_v, river, _river_half, spots, PARK_AT, core_outline)
	country = Country.new()
	country.name = "Country"
	country.load_data(seed_v)
	add_child(country)
	for t in country.towns:
		_towns.append({"id": t.id, "name": t.name, "style": t.kind, "faction": "", "local": Vector2(t.pos[0], t.pos[1])})
	for lm in _map_landmarks:
		var f: int = plan.face_of(lm.local)
		if plan.is_land(f) and not _landmarks.has(f) and not plan.is_park(f) and plan.set_piece(f) in ["", "grounds"]:
			_landmarks[f] = {"id": lm.id, "type": lm.type, "name": lm.name, "local": lm.local}
	places = Places.build(self)
	for p in places:
		_place_by_parcel[Vector2i(p.face, p.parcel)] = p
	places.append_array(Places.build_suburbs(self, places))
	_make_cells()
	_make_rails()
	for f in plan.faces.size():
		if plan.is_land(f) and in_window(f):
			_loop_of_block[f] = sidewalk_loops.size()
			sidewalk_loops.append(_make_loop(f))
	_add_country_walks()
	_place_points()
	_pick_roadworks()
	_pick_parking()
	_build_water()
	stream_now(spawn_point)


func _process(delta: float) -> void:
	_poll_task()
	_stream_tick -= delta
	if _stream_tick > 0.0:
		return
	_stream_tick = 0.2
	var focus := focus_node.global_position if is_instance_valid(focus_node) else spawn_point
	var view := focus
	if is_instance_valid(view_source) and view_source.has_method("stream_point"):
		var s: Vector3 = view_source.stream_point()
		if Vector2(s.x - focus.x, s.z - focus.z).length() < 150.0:
			view = s
	var p := Vector2(focus.x, focus.z)
	var pv := Vector2(view.x, view.z)
	for cell in _loaded.keys():
		if _box_distance(cells[cell].box, p) > UNLOAD_RADIUS and _box_distance(cells[cell].box, pv) > UNLOAD_RADIUS:
			_unload(cell)
	if _task < 0:
		for cell in _cells_near(view, LOAD_RADIUS) + _cells_near(focus, LOAD_RADIUS * 0.6):
			if not _loaded.has(cell):
				_start_task(cell)
				break


## Builds every missing cell around `pos` right away (spawn, respawn, tests).
func stream_now(pos: Vector3) -> void:
	_finish_task()
	for cell in _cells_near(pos, LOAD_RADIUS):
		if not _loaded.has(cell):
			_add_cell(cell, Cells.build(self, cell))
	if country != null:
		country.stream_now(pos)


func set_glow_visible(on: bool) -> void:
	glow_visible = on
	for cell in _loaded:
		var g: Node3D = _loaded[cell].get_node_or_null("Glow")
		if g:
			g.visible = on
	if country != null:
		country.set_glow_visible(on)


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
	var inside: bool = plan.in_city(local)
	if inside:
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
		if (d.rect as Rect2).has_point(p):
			return d
	if not inside:
		for t in _towns:
			if (t.local as Vector2).distance_to(local) < TOWN_RADIUS:
				return t
		for r in _regions:
			if Geometry2D.is_point_in_polygon(p, r.poly):
				return r
	for d in districts:
		var dist: float = (d.rect as Rect2).get_center().distance_to(p)
		if dist < best_d:
			best_d = dist
			best = d
	return best


## The place on front-row parcel k of block f (see Places.front_parcels),
## or {}. Read by the cell builder's worker thread.
func place_at(f: int, k: int) -> Dictionary:
	return _place_by_parcel.get(Vector2i(f, k), {})


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
	for lm in _outer_landmarks:
		var at := _outer_landmark_pos(lm)
		if at != Vector3.INF:
			list.append({"id": lm.id, "type": lm.type, "name": lm.name, "pos": at})
	return list


## Where an outer landmark is: its lot in the country, else its map spot
## when that is in the play area, else Vector3.INF (not built yet).
func _outer_landmark_pos(lm: Dictionary) -> Vector3:
	var lot: Dictionary = country.landmark(lm.id)
	if not lot.is_empty():
		return lot.pos
	if country.in_play_area(lm.local):
		return _v3(lm.local)
	return Vector3.INF


## Where a taxi can take you: every landmark on the maps (at its front) and
## the country's towns. [{id, name, pos}]
func taxi_destinations() -> Array:
	var list: Array = []
	for lm in landmarks():
		var front := landmark_front(lm.id)
		list.append({"id": lm.id, "name": lm.name, "pos": front if front != Vector3.INF else lm.pos})
	for t in _towns:
		var n := nearest_node(_v3(t.local))
		list.append({"id": t.id, "name": t.name, "pos": node_pos(n) if n >= 0 else _v3(t.local)})
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
		var lot: Dictionary = country.landmark(id) if country != null else {}
		return lot.front if not lot.is_empty() else Vector3.INF
	return front_frame(f).origin


## In the street in front of a landmark, `along` metres to the right, in
## the near lane (where cars stop or park).
func landmark_curb(id: String, along := 0.0) -> Vector3:
	var f := landmark_block(id)
	if f < 0:
		var lot: Dictionary = country.landmark(id) if country != null else {}
		if lot.is_empty():
			return Vector3.INF
		var out: Vector3 = (lot.front - lot.pos).normalized()
		return lot.front + out * 3.0 + Vector3(out.z, 0, -out.x) * along
	return curb_point(f, along)


func curb_point(f: int, along := 0.0) -> Vector3:
	var fr := front_frame(f)
	return fr.origin + fr.basis.x * along + fr.basis.z * (WALK_INSET + PARK_FROM_CURB)


## Yaw for a car parked in front of block f, facing the way traffic runs in
## the near lane (curb on its right; front frame -x).
func curb_yaw(f: int) -> float:
	var x := front_frame(f).basis.x
	return atan2(x.x, x.z)


## A block is playable (full detail, collisions, people): every block of
## a plan trimmed to the core outline, else the blocks touching the window.
func in_window(f: int) -> bool:
	return f >= 0 and (not plan.outline.is_empty() or (plan.faces[f].bbox as Rect2).intersects(window))


## Whether a local point is somewhere you can go: the street plan (its
## margin ring included) or the country's play area.
func playable(local: Vector2) -> bool:
	return plan.in_city(local) or (country != null and country.in_play_area(local))


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
	var piece: String = plan.set_piece(f)
	if piece in ["esplanade", "circle", "square"]:
		return piece
	if _landmarks.has(f):
		return _landmarks[f].type
	return district_style(f)


## True when block f fronts on Moreau Square (its painted rows face it).
func faces_square(f: int) -> bool:
	var sq: int = plan.set_piece_face("moreau_square")
	if sq < 0 or f == sq:
		return false
	for e in plan.faces[f].edges:
		var slots: Vector2i = plan.edge_face[e]
		if slots.x == sq or slots.y == sq:
			return true
	return false


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
	return _v3(_pos2(n))


func _pos2(n: int) -> Vector2:
	return country.pos(n - COUNTRY_BASE) if n >= COUNTRY_BASE else plan.pos(n)


## A junction cars can use: on a drivable street of the plan (the margin
## past the window included) or a country road joined to it (Country.usable).
func drive_node(n: int) -> bool:
	if n >= COUNTRY_BASE:
		return country.usable[n - COUNTRY_BASE] == 1
	return n >= 0 and plan.degree(n) > 0 and plan.bounds.grow(2.0).has_point(plan.pos(n))


## Drivable junctions (plan and country ids) within r of p.
func _nodes_near(p: Vector2, r: float) -> Array:
	var out: Array = []
	for n in plan.nodes_near(p, r):
		if drive_node(n):
			out.append(n)
	if country != null:
		for c in country.nodes_near(p, r):
			if country.usable[c] == 1:
				out.append(COUNTRY_BASE + c)
	return out


## The next junction along a heading: the nearest one in front of pos and
## near the line ahead (the end of the street a car is on), else the one
## nearest a point 20 m ahead. A point ahead alone can be nearer the
## junction just passed.
func node_ahead(pos: Vector3, fwd: Vector3) -> int:
	var p := Vector2(pos.x, pos.z)
	var f := Vector2(fwd.x, fwd.z).normalized()
	for r in [100.0, 250.0, 700.0]:
		var best := -1
		var best_along := INF
		for n in _nodes_near(p, r):
			var d: Vector2 = _pos2(n) - p
			var along := d.dot(f)
			if along > 2.0 and absf(d.cross(f)) < maxf(8.0, along * 0.3) and along < best_along:
				best_along = along
				best = n
		if best >= 0:
			return best
	return nearest_node(pos + fwd * 20.0)


func nearest_node(pos: Vector3) -> int:
	var p := Vector2(pos.x, pos.z)
	for r in [40.0, 100.0, 250.0, 700.0, 2000.0]:
		var best := -1
		var best_d := INF
		for n in _nodes_near(p, r):
			var d: float = _pos2(n).distance_squared_to(p)
			if d < best_d:
				best_d = d
				best = n
		if best >= 0:
			return best
	return -1


## The lanes of the street from junction a to b (a street class's lane
## fields, see StreetPlan.CLASSES); one lane each way on a link between the
## plan and the country.
func lanes_of(a: int, b: int) -> Dictionary:
	if a >= COUNTRY_BASE and b >= COUNTRY_BASE:
		var ce: int = country.edge_between(a - COUNTRY_BASE, b - COUNTRY_BASE)
		if ce >= 0:
			return country.classes[country.edge_cls[ce]]
	elif a < COUNTRY_BASE and b < COUNTRY_BASE:
		var e: int = plan.edge_between(a, b)
		if e >= 0:
			if not _works_lanes.is_empty() and _works_lanes.has(Vector2i(a, b)):
				return _works_lanes[Vector2i(a, b)]
			return StreetPlan.CLASSES[plan.edge_class(e)]
	return LINK_LANES


## Lanes each way on the street from a to b.
func lane_count(a: int, b: int) -> int:
	return maxi(1, int(lanes_of(a, b).get("lanes", 1)))


## Where a car driving from junction `from` to `to` in lane `lane` (0 the
## curb lane, counting in toward the middle) should aim: that lane, at
## `to`. `from` may be -1 (just the junction).
func lane_point(from: int, to: int, lane := 0) -> Vector3:
	if from < 0 or from == to:
		return node_pos(to)
	var seg := (node_pos(to) - node_pos(from)).normalized()
	var right := Vector3(-seg.z, 0.0, seg.x)
	return node_pos(to) + right * lane_offset(lanes_of(from, to), lane)


## Lane `lane` at junction `at`, setting off towards `toward`.
func lane_start(at: int, toward: int, lane := 0) -> Vector3:
	var seg := (node_pos(toward) - node_pos(at)).normalized()
	var right := Vector3(-seg.z, 0.0, seg.x)
	return node_pos(at) + right * lane_offset(lanes_of(at, toward), lane)


## Distance from the centreline to the middle of lane `lane` (0 the curb
## lane; past the last lane, the innermost).
static func lane_offset(lanes: Dictionary, lane := 0) -> float:
	var n := maxi(1, int(lanes.get("lanes", 1)))
	var k := clampi(n - 1 - lane, 0, n - 1)
	return float(lanes.get("middle", 0.6)) + float(lanes.get("lane_w", 3.6)) * (k + 0.5)


## Drivable neighbours of junction n (across the links between the plan's
## frame street and the country too).
func next_nodes(n: int) -> Array:
	var out: Array = []
	if n >= COUNTRY_BASE:
		var c := n - COUNTRY_BASE
		for m in country.neighbours(c):
			if country.usable[m] == 1:
				out.append(COUNTRY_BASE + m)
		if country.links.has(c) and drive_node(country.links[c]):
			out.append(country.links[c])
		return out
	for e in plan.edges_of(n):
		if plan.drivable(e):
			var m: int = plan.other(e, n)
			if drive_node(m):
				out.append(m)
	if country != null:
		for c in country.plan_links.get(n, []):
			if country.usable[c] == 1:
				out.append(COUNTRY_BASE + c)
	return out


## Picks where to go after arriving at `cur` from `prev`: mostly straight
## on, never back unless it is a dead end.
## `wide`: an 18-wheeler, which keeps to streets with 2+ lanes each way
## while the junction offers one (1-lane quarter streets trap its trailer).
func pick_turn(prev: int, cur: int, rand: RandomNumberGenerator, wide := false) -> int:
	var din := Vector2.ZERO
	if prev >= 0 and prev != cur:
		din = (_pos2(cur) - _pos2(prev)).normalized()
	var options: Array = []
	var sharp: Array = []
	for m in next_nodes(cur):
		if m == prev:
			continue
		var c := din.dot((_pos2(m) - _pos2(cur)).normalized())
		if c < -0.6:
			sharp.append(m)
			continue
		options.append(m)
		if c > 0.85:
			options.append(m) # straight on is twice as likely
	if options.is_empty():
		options = sharp
	if wide:
		var roomy := options.filter(func(m): return lane_count(cur, m) >= 2)
		if not roomy.is_empty():
			options = roomy
	if options.is_empty():
		return prev if prev >= 0 else cur
	return options[rand.randi() % options.size()]


func random_node_between(center: Vector3, min_d: float, max_d: float, rand: RandomNumberGenerator,
		accept := Callable()) -> int:
	var c := Vector2(center.x, center.z)
	var found: Array = []
	for n in _nodes_near(c, max_d):
		var d: float = _pos2(n).distance_to(c)
		if d >= min_d and d <= max_d and (accept.is_null() or accept.call(node_pos(n))):
			found.append(n)
	if found.is_empty():
		return -1
	return found[rand.randi() % found.size()]


## Returns [loop index, point index] of a sidewalk point in the distance band
## (and passing `accept`, given the point), or an empty array if none was found.
func random_sidewalk_between(center: Vector3, min_d: float, max_d: float, rand: RandomNumberGenerator,
		accept := Callable()) -> Array:
	var near: Array = []
	for f in plan.faces_near(Vector2(center.x, center.z), max_d):
		if _loop_of_block.has(f):
			near.append(_loop_of_block[f])
	near.append_array(_walks_near(center, max_d))
	if near.is_empty():
		return []
	for attempt in 24:
		var li: int = near[rand.randi() % near.size()]
		var loop := sidewalk_loops[li]
		var pi := rand.randi() % loop.size()
		var d := loop[pi].distance_to(center)
		if d >= min_d and d <= max_d and (accept.is_null() or accept.call(loop[pi])):
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
		for li in _walks_near(pos, r):
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
	if country == null:
		return
	for c in country.node_count():
		_astar.add_point(COUNTRY_BASE + c, country.pos(c))
	for e in country.edge_a.size():
		var a: int = COUNTRY_BASE + country.edge_a[e]
		var b: int = COUNTRY_BASE + country.edge_b[e]
		if a != b and drive_node(a) and drive_node(b) and not _astar.are_points_connected(a, b):
			_astar.connect_points(a, b)
	for c in country.links:
		if country.usable[c] == 1 and _astar.has_point(country.links[c]):
			_astar.connect_points(COUNTRY_BASE + c, country.links[c])


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
	core_outline = PackedVector2Array()
	for q in city.get("core", []):
		core_outline.append(Vector2(q[0], q[1]) - map_origin)
	# Districts and landmarks of a later phase are planned, not built yet.
	for d in city.districts:
		if int(d.get("phase", 1)) > 2:
			continue
		var entry := {
			"id": d.id, "name": d.name, "style": d.style, "faction": d.faction,
			"rect": Rect2(d.rect[0], d.rect[1], d.rect[2], d.rect[3]),
		}
		districts.append(entry)
		_district_by_id[d.id] = entry
	for lm in world.landmarks:
		if int(lm.get("phase", 1)) > 2:
			continue
		var local := Vector2(lm.pos[0], lm.pos[1]) - map_origin
		var entry := {"id": lm.id, "type": lm.type, "name": lm.name, "local": local}
		if window.has_point(local) and int(lm.get("phase", 1)) == 1:
			_map_landmarks.append(entry)
		elif not window.has_point(local) and lm.type != "peak":
			# Peaks are names on the map, not places to go.
			_outer_landmarks.append(entry)
	for r in world.regions:
		var phase := int(r.get("phase", 1))
		if phase > 2:
			continue
		var poly := PackedVector2Array()
		for q in r.polygon:
			poly.append(Vector2(q[0], q[1]))
		var entry := {"id": r.id, "name": r.name, "style": r.type, "faction": "", "poly": poly}
		# Phase 1 regions (the Bellerive Hills) lie inside a phase 2 one's
		# outline and are looked up first.
		if phase == 1:
			_regions.push_front(entry)
		else:
			_regions.append(entry)
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
		# The route may leave the trimmed city through the country; rails stay
		# on city streets, one line per city run.
		var run := PackedInt32Array()
		for n in path:
			if n < COUNTRY_BASE:
				run.append(n)
			else:
				_add_rail(run, true)
				run = PackedInt32Array()
		_add_rail(run, true)


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
## Appends the country's suburb sidewalk loops after the plan's and files
## them by grid cell, so people walk the suburbs like the city's blocks.
func _add_country_walks() -> void:
	for w in country.walks:
		var li := sidewalk_loops.size()
		sidewalk_loops.append(w)
		var seen := {}
		for p in w:
			var k := Vector2i(floori(p.x / WALK_CELL), floori(p.z / WALK_CELL))
			if not seen.has(k):
				seen[k] = true
				if not _walk_grid.has(k):
					_walk_grid[k] = PackedInt32Array()
				_walk_grid[k].append(li)


## The suburb sidewalk loops with a point in a grid cell within `r` of `pos`
## (each once).
func _walks_near(pos: Vector3, r: float) -> Array:
	var out := {}
	var c0 := Vector2i(floori((pos.x - r) / WALK_CELL), floori((pos.z - r) / WALK_CELL))
	var c1 := Vector2i(floori((pos.x + r) / WALK_CELL), floori((pos.z + r) / WALK_CELL))
	for gx in range(c0.x, c1.x + 1):
		for gy in range(c0.y, c1.y + 1):
			for li in _walk_grid.get(Vector2i(gx, gy), PackedInt32Array()):
				out[li] = true
	return out.keys()


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


## Two or three roadworks a district (see roadworks), on four- and six-lane
## streets with a curb on the works side, clear of the spawn, the rails and
## each other, from their own random stream (the rest of the city's draws
## stay as they were).
func _pick_roadworks() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value * 7919 + 101
	var by_district := {}
	for e in plan.edge_count():
		var cls: String = plan.edge_class(e)
		if not cls in WORKS_CLASSES or not plan.drivable(e) or rail_on(e) >= 0:
			continue
		var na: int = plan.edge_a[e]
		var nb: int = plan.edge_b[e]
		if not (drive_node(na) and drive_node(nb)):
			continue
		var a := node_pos(na)
		var b := node_pos(nb)
		var mid := (a + b) * 0.5
		var length := a.distance_to(b)
		var run: float = length - plan.clearance(na, e) - plan.clearance(nb, e) - 1.0
		if run < 50.0 or mid.distance_to(spawn_point) < WORKS_CLEAR_OF_SPAWN or not plan.in_city(Vector2(mid.x, mid.z)):
			continue
		var id: String = district_at(mid).get("id", "")
		if not by_district.has(id):
			by_district[id] = []
		by_district[id].append(e)
	var ids := by_district.keys()
	ids.sort()
	var picked: Array[Vector3] = []
	for id in ids:
		var list: Array = by_district[id]
		for k in list.size():
			var j := r.randi_range(k, list.size() - 1)
			var t: int = list[j]
			list[j] = list[k]
			list[k] = t
		var want := r.randi_range(2, 3)
		for e: int in list:
			if want <= 0:
				break
			var na: int = plan.edge_a[e]
			var nb: int = plan.edge_b[e]
			var a := node_pos(na)
			var b := node_pos(nb)
			var length := a.distance_to(b)
			var dir := (b - a) / length
			var right := Vector3(-dir.z, 0, dir.x)
			var g: Dictionary = StreetPlan.CLASSES[plan.edge_class(e)]
			var w: float = g.width
			var side := 1.0 if r.randf() < 0.5 else -1.0
			if not plan.is_land(block_of((a + b) * 0.5 + right * side * (w * 0.5 + 3.0))):
				side = -side
				if not plan.is_land(block_of((a + b) * 0.5 + right * side * (w * 0.5 + 3.0))):
					continue
			var s0: float = plan.clearance(na, e) + 0.5
			var s1: float = plan.clearance(nb, e) + 0.5
			var span := r.randf_range(14.0, 22.0)
			# Room for the sign and the taper on the side traffic comes from.
			var lo := s0 + (24.0 if side > 0.0 else 6.0)
			var hi := length - s1 - span - (6.0 if side > 0.0 else 24.0)
			if hi < lo:
				continue
			var x0 := r.randf_range(lo, hi)
			var at := a + dir * (x0 + span * 0.5)
			if picked.any(func(q: Vector3) -> bool: return q.distance_to(at) < WORKS_SPACING):
				continue
			picked.append(at)
			roadworks[e] = {"side": side, "x0": x0, "x1": x0 + span}
			var open := g.duplicate()
			open["lanes"] = int(g.lanes) - 1
			open["closed"] = 1
			_works_lanes[Vector2i(na, nb) if side > 0.0 else Vector2i(nb, na)] = open
			want -= 1


## The roadworks on the street from a to b, or {}.
func works_on(a: int, b: int) -> Dictionary:
	if roadworks.is_empty() or a < 0 or b < 0 or a >= COUNTRY_BASE or b >= COUNTRY_BASE:
		return {}
	return roadworks.get(plan.edge_between(a, b), {})


## `at`, a point on the street from a to b, moved along the street out of
## its roadworks and their taper (to the nearer end that leaves the
## junctions clear); else `at` as it is.
func clear_of_works(a: int, b: int, at: Vector3) -> Vector3:
	if works_on(a, b).is_empty():
		return at
	var e: int = plan.edge_between(a, b)
	var wk: Dictionary = roadworks[e]
	var pa := node_pos(plan.edge_a[e])
	var pb := node_pos(plan.edge_b[e])
	var length := pa.distance_to(pb)
	var dir := (pb - pa) / length
	var x := (at - pa).dot(dir)
	var lo: float = wk.x0 - WORKS_TAPER - 4.0
	var hi: float = wk.x1 + WORKS_TAPER + 4.0
	if x <= lo or x >= hi:
		return at
	var to := lo if (x - lo < hi - x and lo > 9.0) or hi > length - 9.0 else hi
	return at + dir * (to - x)


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
		var lanes: Dictionary = StreetPlan.CLASSES[plan.edge_class(e)]
		if lanes.park <= 0.0 or rail_on(e) >= 0:
			continue # no parking strip
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
		# In the middle of the parking strip, outside the curb lane.
		var out: float = lanes.middle + lanes.lanes * lanes.lane_w + lanes.park * 0.5
		var x := rng.randf_range(s0, length - s1)
		var p := a + along * x + right * side * out
		if not plan.is_land(block_of(p + right * side * 4.0)):
			continue # no curb on that side (water)
		var wk: Dictionary = roadworks.get(e, {})
		if not wk.is_empty() and wk.side == side and x > wk.x0 - 30.0 and x < wk.x1 + 30.0:
			continue # dug up, or the sign ahead of it
		var facing := along * side
		parked_spots.append([p, atan2(-facing.x, -facing.z)])


## One water plane under the whole map; land is built on top of it.
func _build_water() -> void:
	var mb := MeshBuilder.new()
	var r: Rect2 = country.bounds() if country != null else plan.bounds.grow(300.0)
	mb.box(_v3(r.get_center()) + Vector3(0, -0.55, 0), Vector3(r.size.x, 0.1, r.size.y), Color(0.16, 0.36, 0.42))
	var inst := mb.make_instance()
	inst.name = "Water"
	inst.material_override = MeshBuilder.water_material()
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)


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
	var inst: MeshInstance3D = null
	var glow: MeshInstance3D = null
	if built.mesh.triangle_count() > 0:
		inst = built.mesh.make_instance()
		inst.material_override = MeshBuilder.cutaway_material()
		root.add_child(inst)
	if built.glow.triangle_count() > 0:
		glow = built.glow.make_instance()
		glow.name = "Glow"
		glow.material_override = MeshBuilder.glow_material()
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glow.visible = glow_visible
		root.add_child(glow)
	var solid := func(c: Array) -> bool: return not L.sight_only(c)
	var roof := func(c: Array) -> bool: return L.sight_only(c)
	var sight: Array = built.colliders.filter(roof) + built.props.filter(roof)
	for group in [[built.colliders.filter(solid), L.WORLD], [built.props.filter(solid), L.PROPS], [sight, L.SIGHT]]:
		if group[0].is_empty():
			continue
		var body := StaticBody3D.new()
		body.collision_layer = group[1]
		body.collision_mask = 0
		# The meshes breakable props are cut from (Breakables).
		body.set_meta("mesh", inst)
		body.set_meta("glow", glow)
		root.add_child(body)
		for c in group[0]:
			var shape := _add_shape(body, c[0], c[1], c[2] if c.size() > 2 else 0.0)
			if c.size() > 3 and group[1] != L.SIGHT:
				shape.set_meta("brk", c[3])
				if c[3].has("light"):
					shape.add_to_group("lamps")
	root.set_meta("buildings", built.buildings)
	building_count += built.buildings
	add_child(root)
	_loaded[cell] = root


func _unload(cell: int) -> void:
	var root: Node3D = _loaded[cell]
	building_count -= int(root.get_meta("buildings"))
	_loaded.erase(cell)
	root.queue_free()


func _add_shape(body: StaticBody3D, center: Vector3, size: Vector3, yaw := 0.0) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = center
	shape.rotation.y = yaw
	body.add_child(shape)
	return shape


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
