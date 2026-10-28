extends Node3D
## The country round Bellerive (phase 2): the suburbs past the street plan's
## edge, Golden Flats, Saltgrass and Verdant Hills with their towns, loaded
## from res://data/country.json (made by tools/build_country.py) and built in
## square tiles as the focus moves, like the city's cells.
##
## Local metres as in city.gd (map y = game z). The road graph has its own
## junction ids (city.gd offsets them by COUNTRY_BASE); `links` join country
## junctions to the street plan's frame-street junctions, so traffic, the
## GPS and the police drive straight on from the city into the country.
## The world is flat: walls keep cars out of the water (banks, the Gulf) and
## inside the play area, whose roads end at storm barricades.

const Tiles = preload("res://scripts/country_tiles.gd")
const MeshBuilder = preload("res://scripts/mesh_builder.gd")
const L = preload("res://scripts/layers.gd")
const Terrain = preload("res://scripts/terrain.gd")

const DATA_PATH := "res://data/country.json"
## Tiles load when their square comes this close to the focus (or to where
## a fast car will be in LOOKAHEAD seconds) and unload past UNLOAD_RADIUS.
## Static so a far-seeing camera (Settings > Zoom, the camera demo) can
## widen them.
static var LOAD_RADIUS := 130.0
static var UNLOAD_RADIUS := 210.0
const LOOKAHEAD := 1.2
const NODE_GRID := 50.0
## Barricades stand BARRICADE_IN m inside the play area where a road leaves
## it; the road's junctions within BARRICADE_CUT of its end at the edge are
## cut off for traffic, which could never reach them to turn round.
const BARRICADE_IN := 8.0
const BARRICADE_CUT := 14.0

var tile_size := 100.0
## Home car spot key ("lot:k") -> its index in the city's parked_spots.
var _park_slot := {}
## [{id, w, speed}] by class index.
var classes: Array = []
var zones := PackedStringArray()
var kinds := PackedStringArray()
var node_pos := PackedVector2Array()
var edge_a := PackedInt32Array()
var edge_b := PackedInt32Array()
var edge_cls := PackedInt32Array()
var edge_road := PackedInt32Array()
var edge_bridge := PackedByteArray()
## Roads: {cls, name, nodes (PackedInt32Array), e0 (first edge)}.
var roads: Array = []
## Country junction -> plan junction, and back (plan -> [country]).
var links := {}
var plan_links := {}
## [x, y, yaw, w, d, kind index, landmark id, zone, plot (-1: none), reach
## [left, middle, right] (HANDOFF-routes.md), household tier (-1: not a home;
## HANDOFF-wealth.md), land value 0..1].
var lots: Array = []
## Road-square plots that hold grounds and lots (HANDOFF-plots.md):
## [x, y, yaw, w, d, type index, parts]; parts are [kind index, x, z, w, d,
## rot, variant] in the plot frame (kits/grounds_kit.gd draws them).
var plots: Array = []
var plot_types: Array = []
var part_kinds: Array = []
var tree_kinds: Array = []
## [ax, ay, bx, by, kind]: 0 bank, 1 coast, 2 the play area's edge.
var walls: Array = []
## [x, y, dir x, dir y, width].
var barricades: Array = []
var paths: Array = []
var trails: Array = []
var rails: Array = []
var far_roads: Array = []
## Golden Flats' centre-pivot circles for the maps: [x, y, radius, crop zone].
var pivots: Array = []
var towns: Array = []
## The play area outline(s).
var area: Array[PackedVector2Array] = []
## [{zone, poly}] suburb zones (Brisa Beach, the Heights...).
var suburbs: Array = []
## Sidewalk loops round the suburb blocks inside Bellerive's outline, for
## people (HANDOFF-bellerive-expand.md BX-1): closed, anticlockwise, points
## every 6 m at most, in game metres on the ground.
var walks: Array[PackedVector3Array] = []
var plan_bounds := Rect2()
## Every tile's data: Vector2i -> {g, r, l, w, b, p, t, x, f}.
var tiles := {}
## Bridge edges: edge -> true (parapets instead of bank walls).
var bridge_edges := {}
## Node the streaming follows (city.focus_node is used when unset).
var focus_node: Node3D
var glow_visible := false
var seed_value := 1234

## Junctions cars may use: joined to the city (Ember Canyon Drive, between
## two barricades, is not) and not on the stretch past a storm barricade,
## which traffic could never reach to turn round.
var usable := PackedByteArray()
var _adj: Array = [] # node -> PackedInt32Array of edges
var _node_grid := {}
var _lot_by_id := {}
var _loaded := {} # Vector2i -> Node3D
var _task := -1
var _task_key := Vector2i.ZERO
var _task_result: Dictionary
var _tick := 0.0


func load_data(seed_v := 1234) -> void:
	seed_value = seed_v
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	tile_size = d.tile
	classes = d.classes
	zones = PackedStringArray(d.zones)
	kinds = PackedStringArray(d.kinds)
	var pb: Array = d.plan_bounds
	plan_bounds = Rect2(pb[0], pb[1], pb[2] - pb[0], pb[3] - pb[1])
	node_pos.resize(d.nodes.size())
	for i in d.nodes.size():
		node_pos[i] = Vector2(d.nodes[i][0], d.nodes[i][1])
	var ne: int = d.edges.size()
	edge_a.resize(ne)
	edge_b.resize(ne)
	edge_cls.resize(ne)
	edge_road.resize(ne)
	edge_bridge.resize(ne)
	_adj.resize(node_pos.size())
	for n in node_pos.size():
		_adj[n] = PackedInt32Array()
	for e in ne:
		var row: Array = d.edges[e]
		edge_a[e] = row[0]
		edge_b[e] = row[1]
		edge_cls[e] = row[2]
		edge_road[e] = row[3]
		edge_bridge[e] = row[4]
		_adj[row[0]].append(e)
		_adj[row[1]].append(e)
	for r in d.roads:
		roads.append({"cls": int(r.cls), "name": r.name, "nodes": PackedInt32Array(r.nodes), "e0": int(r.e0)})
	for b in d.bridges:
		var e0: int = roads[b.road].e0
		for k in range(int(b.from), int(b.to)):
			bridge_edges[e0 + k] = true
	for pair in d.links:
		links[int(pair[0])] = int(pair[1])
		if not plan_links.has(int(pair[1])):
			plan_links[int(pair[1])] = []
		plan_links[int(pair[1])].append(int(pair[0]))
	Terrain.load_data(d.get("terrain"))
	lots = d.lots
	plots = d.get("plots", [])
	plot_types = d.get("plot_types", [])
	part_kinds = d.get("part_kinds", [])
	tree_kinds = d.get("tree_kinds", [])
	for i in lots.size():
		if lots[i][6] != "":
			_lot_by_id[lots[i][6]] = i
	walls = d.walls
	barricades = d.barricades
	paths = d.paths
	trails = d.trails
	rails = d.rails
	far_roads = d.far_roads
	pivots = d.get("pivots", [])
	towns = d.towns
	suburbs = d.suburbs
	for w in d.get("walks", []):
		var loop := PackedVector3Array()
		for i in range(0, w.size(), 2):
			loop.append(Vector3(w[i], 0.0, w[i + 1]))
		walks.append(loop)
	for ring in d.area:
		var poly := PackedVector2Array()
		for p in ring:
			poly.append(Vector2(p[0], p[1]))
		area.append(poly)
	for t in d.tiles:
		tiles[Vector2i(t.k[0], t.k[1])] = t
	for n in node_pos.size():
		var key := Vector2i(floori(node_pos[n].x / NODE_GRID), floori(node_pos[n].y / NODE_GRID))
		if not _node_grid.has(key):
			_node_grid[key] = PackedInt32Array()
		_node_grid[key].append(n)
	_find_usable()


func _find_usable() -> void:
	var blocked := {}
	for b in barricades:
		# The road's end at the edge: the dead end nearest the barricade
		# (the area outline is simplified, so which side is "out" can't be
		# told from it this close).
		var p := Vector2(b[0], b[1])
		var end := -1
		for n in nodes_near(p, BARRICADE_IN * 2.0):
			if degree(n) == 1 and (end < 0 or node_pos[n].distance_to(p) < node_pos[end].distance_to(p)):
				end = n
		if end < 0:
			push_warning("barricade at %s has no road end behind it" % p)
			continue
		for n in nodes_near(node_pos[end], BARRICADE_CUT):
			blocked[n] = true
	usable.resize(node_pos.size())
	usable.fill(0)
	var queue: Array = []
	for c in links:
		if not blocked.has(c):
			usable[c] = 1
			queue.append(c)
	while not queue.is_empty():
		var n: int = queue.pop_back()
		for m in neighbours(n):
			if usable[m] == 0 and not blocked.has(m):
				usable[m] = 1
				queue.append(m)


func _process(delta: float) -> void:
	_poll_task()
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.15
	var focus := _focus_point()
	var p := Vector2(focus.x, focus.z)
	for key in _loaded.keys():
		if _tile_distance(key, p) > UNLOAD_RADIUS:
			_unload(key)
	if _task < 0:
		var key = _next_missing(focus)
		if key != null:
			_start_task(key)


func _focus_point() -> Vector3:
	var node: Node3D = focus_node
	if not is_instance_valid(node):
		var city = get_parent()
		node = city.focus_node if city and is_instance_valid(city.focus_node) else null
	if node == null:
		return Vector3.ZERO
	var pos := node.global_position
	# Ride along with whatever the focus drives (the player stands still in
	# a car; the car has the velocity).
	var car = node.get("vehicle")
	var v = car.get("velocity") if is_instance_valid(car) and car is Node3D else node.get("velocity")
	if v is Vector3:
		pos += v * LOOKAHEAD
	return pos


## Builds every missing tile round `pos` right away (spawn, respawn, tests).
func stream_now(pos: Vector3) -> void:
	_finish_task()
	for key in tiles_near(pos, LOAD_RADIUS):
		if not _loaded.has(key):
			_add_tile(key, Tiles.build(self, key))


func set_glow_visible(on: bool) -> void:
	glow_visible = on
	for key in _loaded:
		var g: Node3D = _loaded[key].get_node_or_null("Glow")
		if g:
			g.visible = on


func loaded_tiles() -> Array:
	return _loaded.keys()


func tile_node(key: Vector2i) -> Node3D:
	return _loaded.get(key)


func tile_key(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / tile_size), floori(pos.z / tile_size))


## Tiles with data whose square is within `radius` of `pos`, nearest first.
func tiles_near(pos: Vector3, radius: float) -> Array:
	var p := Vector2(pos.x, pos.z)
	var found: Array = []
	for gx in range(floori((p.x - radius) / tile_size), floori((p.x + radius) / tile_size) + 1):
		for gy in range(floori((p.y - radius) / tile_size), floori((p.y + radius) / tile_size) + 1):
			var key := Vector2i(gx, gy)
			if tiles.has(key) and _tile_distance(key, p) <= radius:
				found.append(key)
	found.sort_custom(func(a, b): return _tile_distance(a, p) < _tile_distance(b, p))
	return found


func _next_missing(focus: Vector3):
	for key in tiles_near(focus, LOAD_RADIUS):
		if not _loaded.has(key):
			return key
	return null


func _tile_distance(key: Vector2i, p: Vector2) -> float:
	var r := Rect2(Vector2(key) * tile_size, Vector2.ONE * tile_size)
	var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
	return q.distance_to(p)


# --- Places ----------------------------------------------------------------------

## Whether a local point is inside the play area (outside it the country is
## scenery behind a fence).
func in_play_area(p: Vector2) -> bool:
	for poly in area:
		if Geometry2D.is_point_in_polygon(p, poly):
			return true
	return false


## The suburb zone (heights, beach_town...), town id or region-free ground
## at a local point, "" outside them.
func zone_at(p: Vector2) -> String:
	for s in suburbs:
		var poly := PackedVector2Array()
		for q in s.poly:
			poly.append(Vector2(q[0], q[1]))
		if Geometry2D.is_point_in_polygon(p, poly):
			return s.zone
	return ""


## The lot of a map landmark built in the country: {pos (Vector3, centre),
## front (Vector3, on the street side), yaw, kind}, or {}.
func landmark(id: String) -> Dictionary:
	if not _lot_by_id.has(id):
		return {}
	return lot_info(_lot_by_id[id])


func lot_info(i: int) -> Dictionary:
	var l: Array = lots[i]
	var yaw: float = l[2]
	var front := Vector3(-sin(yaw), 0, -cos(yaw))
	var c := Vector3(l[0], 0, l[1])
	var reach := float(l[4]) * 0.5 + 2.0
	if l.size() > 8 and int(l[8]) >= 0:
		# Inside a plot the way in is the plot's own front edge, straight out
		# from the lot: the house may be turned or set far back in its grounds.
		var p: Array = plots[int(l[8])]
		front = Vector3(-sin(float(p[2])), 0, -cos(float(p[2])))
		reach = (Vector3(p[0], 0, p[1]) - c).dot(front) + float(p[4]) * 0.5 + 2.0
	return {"pos": c, "front": c + front * reach, "yaw": yaw, "kind": kinds[int(l[5])],
			"id": l[6], "size": Vector2(l[3], l[4])}


func landmark_ids() -> Array:
	return _lot_by_id.keys()


# --- Road graph --------------------------------------------------------------------

func node_count() -> int:
	return node_pos.size()


func pos(n: int) -> Vector2:
	return node_pos[n]


func edges_of(n: int) -> PackedInt32Array:
	return _adj[n]


func degree(n: int) -> int:
	return _adj[n].size()


func other(e: int, n: int) -> int:
	return edge_b[e] if edge_a[e] == n else edge_a[e]


func edge_between(a: int, b: int) -> int:
	for e in _adj[a]:
		if other(e, a) == b:
			return e
	return -1


func edge_width(e: int) -> float:
	return classes[edge_cls[e]].w


func edge_speed(e: int) -> float:
	return classes[edge_cls[e]].speed


func edge_class(e: int) -> String:
	return classes[edge_cls[e]].id


func road_name(e: int) -> String:
	return roads[edge_road[e]].name


## Neighbouring junctions along the roads.
func neighbours(n: int) -> Array:
	var out: Array = []
	for e in _adj[n]:
		out.append(other(e, n))
	return out


func nodes_near(p: Vector2, r: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	for gx in range(floori((p.x - r) / NODE_GRID), floori((p.x + r) / NODE_GRID) + 1):
		for gy in range(floori((p.y - r) / NODE_GRID), floori((p.y + r) / NODE_GRID) + 1):
			for n in _node_grid.get(Vector2i(gx, gy), PackedInt32Array()):
				if node_pos[n].distance_to(p) <= r:
					out.append(n)
	return out


## Distance from p to the nearest road centreline (in roads near p), or INF.
func road_distance(p: Vector2, reach := 60.0) -> float:
	var best := INF
	for n in nodes_near(p, reach):
		for e in _adj[n]:
			var a := node_pos[edge_a[e]]
			var b := node_pos[edge_b[e]]
			best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) - edge_width(e) * 0.5)
	return best


## Everything the water plane must cover, in local metres.
func bounds() -> Rect2:
	var r := plan_bounds
	for poly in area:
		for p in poly:
			r = r.expand(p)
	return r.grow(600.0)


# --- Streaming -----------------------------------------------------------------------

func _start_task(key: Vector2i) -> void:
	_task_key = key
	_task = WorkerThreadPool.add_task(_run_task.bind(key), false, "country tile")


func _run_task(key: Vector2i) -> void:
	_task_result = Tiles.build(self, key)


func _poll_task() -> void:
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		_finish_task()


func _finish_task() -> void:
	if _task < 0:
		return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	if not _loaded.has(_task_key):
		_add_tile(_task_key, _task_result)
	_task_result = {}


func _add_tile(key: Vector2i, built: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "Tile_%d_%d" % [key.x, key.y]
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
	for group in [[built.colliders, L.WORLD], [built.props, L.PROPS]]:
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
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = c[1]
			shape.shape = box
			shape.position = c[0]
			shape.rotation.y = c[2] if c.size() > 2 else 0.0
			if c.size() > 3:
				shape.set_meta("brk", c[3])
			body.add_child(shape)
	root.set_meta("buildings", built.buildings)
	root.set_meta("parks", _open_parks(built.get("parks", [])))
	add_child(root)
	_loaded[key] = root


## Opens a tile's home car spots in the city's parked_spots,
## where the traffic layer parks cars that can drive off. Each spot keeps its
## index for good, so a car parked there stays matched to it; a closed spot
## (its tile unloaded) gets no new car. Returns the spots' indices.
func _open_parks(parks: Array) -> Array:
	var city = get_parent()
	if city == null or not "parked_spots" in city:
		return []
	var idx: Array = []
	for pk in parks:
		var at: int = _park_slot.get(pk[0], -1)
		if at < 0:
			at = city.parked_spots.size()
			_park_slot[pk[0]] = at
			city.parked_spots.append([pk[1], pk[2], true])
		else:
			city.parked_spots[at][2] = true
		idx.append(at)
	return idx


func _unload(key: Vector2i) -> void:
	var root: Node3D = _loaded[key]
	_loaded.erase(key)
	var city = get_parent()
	if city != null and "parked_spots" in city:
		for at: int in root.get_meta("parks", []):
			city.parked_spots[at][2] = false
	root.queue_free()


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
