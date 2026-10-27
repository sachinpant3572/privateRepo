extends Node3D
## Bellerive demo map, built from the world map (res://data/world_map.json)
## and laid out by the street plan (street_plan.gd, see
## reference/MAP_BUILDING.md):
## - Streets follow the river's crescent: rows are arcs, columns are spokes.
## - Blocks vary in size by district.
## - Streets come in classes, from boulevards with a neutral ground down to
##   pedestrian lanes, and some are closed off.
##
## Junctions ("nodes") keep grid indices (i, j). Local (0, 0) is the window
## origin in world-map metres (map y = game z). A cell (i, j) owns its block,
## node (i, j) and the streets running east and south from it. Cells are
## built on a worker thread as the focus moves and freed when far away;
## each one is a single mesh plus static bodies. A ring of MARGIN cells
## outside the window is built without collisions so the city doesn't end at
## the edge of the screen. Traffic drives on the right.

const MeshBuilder = preload("res://scripts/mesh_builder.gd")
const Cells = preload("res://scripts/city_cells.gd")
const StreetPlan = preload("res://scripts/street_plan.gd")
const L = preload("res://scripts/layers.gd")

const MAP_PATH := "res://data/world_map.json"
const CITY_ID := "bellerive"
## Nominal junction spacing (the plan varies it per row and column).
const PITCH := 52.0
## A typical street's width, for code that needs a rough figure.
const ROAD := 11.0
const SIDEWALK := 3.0
## Pedestrians walk this far in from the curb.
const WALK_INSET := 1.2
## Liberty Green, the park superblock, goes round the junction nearest
## here (local metres): where the Quarter meets the Wards.
const PARK_AT := Vector2(830, 560)
## Parked cars sit this far out from the curb (their centre).
const PARK_FROM_CURB := 1.0
const MARGIN := 2
const LOAD_RADIUS := 115.0
const UNLOAD_RADIUS := 165.0

## Window size in blocks, from the map.
var blocks := Vector2i(25, 22)
var seed_value := 0
var rng := RandomNumberGenerator.new()
var plan
## Buildings in the cells that are currently loaded.
var building_count := 0
## One closed walking loop per land block, round the inside of its sidewalk.
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
## Streetcar lines: [from node, to node, rusty], along one row or column.
var rail_lines: Array = []
## Node the streaming follows; the spawn point when unset.
var focus_node: Node3D
## Night light pools are drawn only after dark (see set_glow_visible).
var glow_visible := false

var _landmarks := {} # block -> {id, type, name}
var _map_landmarks: Array = [] # [{id, type, name, local}]
var _river: PackedVector2Array
var _river_half := 80.0
var _loop_of_block := {}
var _cells := {} # cell -> Node3D
var _task := -1
var _task_cell := Vector2i.ZERO
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
		spots.append(lm.local)
	plan.build(blocks, seed_v, func(p: Vector2): return district_at(Vector3(p.x, 0, p.y)).get("style", "quarter"),
		func(p: Vector2): return _river_distance(p + map_origin), _river_half, spots, PARK_AT)
	for lm in _map_landmarks:
		var b: Vector2i = plan.block_of(Vector3(lm.local.x, 0, lm.local.y))
		if in_window(b) and block_land(b) and not _landmarks.has(b):
			_landmarks[b] = {"id": lm.id, "type": lm.type, "name": lm.name}
	rail_lines = [
		[Vector2i(plan.boulevard_col, 3), Vector2i(plan.boulevard_col, 20), false], # Lantern Line, Union Station to the river
		[Vector2i(18, 15), Vector2i(25, 15), true], # the drowned line to the old depot
	]
	for i in blocks.x:
		for j in blocks.y:
			var b := Vector2i(i, j)
			if block_land(b):
				_loop_of_block[b] = sidewalk_loops.size()
				sidewalk_loops.append(_make_loop(b))
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
	var wanted := _cells_near(focus, LOAD_RADIUS)
	for cell in _cells.keys():
		if _cell_center(cell).distance_to(Vector2(focus.x, focus.z)) > UNLOAD_RADIUS:
			_unload(cell)
	if _task < 0:
		for cell in wanted:
			if not _cells.has(cell):
				_start_task(cell)
				break


## Builds every missing cell around `pos` right away (spawn, respawn, tests).
func stream_now(pos: Vector3) -> void:
	_finish_task()
	for cell in _cells_near(pos, LOAD_RADIUS):
		if not _cells.has(cell):
			_add_cell(cell, Cells.build(self, cell))


func set_glow_visible(on: bool) -> void:
	glow_visible = on
	for cell in _cells:
		var g: Node3D = _cells[cell].get_node_or_null("Glow")
		if g:
			g.visible = on


func loaded_cells() -> Array:
	return _cells.keys()


func cell_node(cell: Vector2i) -> Node3D:
	return _cells.get(cell)


# --- Map queries ---------------------------------------------------------------

## The map district containing a local position, or the nearest one.
func district_at(pos: Vector3) -> Dictionary:
	var p := map_origin + Vector2(pos.x, pos.z)
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


func landmark_at(b: Vector2i) -> Dictionary:
	return _landmarks.get(b, {})


## Block holding the map landmark `id`, or (-1, -1).
func landmark_block(id: String) -> Vector2i:
	for b in _landmarks:
		if _landmarks[b].id == id:
			return b
	return Vector2i(-1, -1)


## In-window landmarks for the maps: [{id, type, name, pos}].
func landmarks() -> Array:
	var list: Array = []
	for b in _landmarks:
		var lm: Dictionary = _landmarks[b].duplicate()
		lm["pos"] = block_center(b)
		list.append(lm)
	if plan.park_node.x >= 0:
		list.append({"id": "liberty_green", "type": "park", "name": "Liberty Green", "pos": node_pos(plan.park_node)})
	return list


## A frame on block b's street front: origin on the middle of the front
## sidewalk, basis.x along the street (left to right as seen from the
## street), basis.z pointing out across the street. Landmarks face it.
func front_frame(b: Vector2i) -> Transform3D:
	var k: int = plan.front_side(b)
	var poly: PackedVector2Array = plan.inner(b)
	var a := poly[k]
	var e := poly[(k + 1) % 4]
	var along := (a - e).normalized() # left to right when looking at the block from the street
	var out := Vector2(-along.y, along.x)
	var mid := (a + e) * 0.5 - out * WALK_INSET
	var x := Vector3(along.x, 0, along.y)
	var z := Vector3(out.x, 0, out.y)
	return Transform3D(Basis(x, Vector3.UP, z), Vector3(mid.x, 0, mid.y))


## Same, for a landmark (Transform3D.IDENTITY if it isn't in the window).
func landmark_frame(id: String) -> Transform3D:
	var b := landmark_block(id)
	return front_frame(b) if b.x >= 0 else Transform3D.IDENTITY


## On the sidewalk in front of a landmark (where people meet), or
## Vector3.INF if the landmark isn't in the window.
func landmark_front(id: String) -> Vector3:
	var b := landmark_block(id)
	if b.x < 0:
		return Vector3.INF
	return front_frame(b).origin


## In the street in front of a landmark, `along` metres to the right, in
## the near lane (where cars stop or park).
func landmark_curb(id: String, along := 0.0) -> Vector3:
	var b := landmark_block(id)
	if b.x < 0:
		return Vector3.INF
	return curb_point(b, along)


func curb_point(b: Vector2i, along := 0.0) -> Vector3:
	var f := front_frame(b)
	return f.origin + f.basis.x * along + f.basis.z * (WALK_INSET + PARK_FROM_CURB)


## The street on side k of block b (0 north, 1 east, 2 south, 3 west) as
## [node, direction].
static func side_edge(b: Vector2i, k: int) -> Array:
	match k:
		0:
			return [b, Vector2i(1, 0)]
		1:
			return [b + Vector2i(1, 0), Vector2i(0, 1)]
		2:
			return [b + Vector2i(0, 1), Vector2i(1, 0)]
		_:
			return [b, Vector2i(0, 1)]


## Yaw for a car parked in front of block b, facing along the street to the
## right.
func curb_yaw(b: Vector2i) -> float:
	var x := front_frame(b).basis.x
	return atan2(-x.x, -x.z)


func in_window(b: Vector2i) -> bool:
	return b.x >= 0 and b.y >= 0 and b.x < blocks.x and b.y < blocks.y


func node_ok(n: Vector2i) -> bool:
	return plan.has_node(n) and not plan.is_water(n)


## A block is land when all four corners are.
func block_land(b: Vector2i) -> bool:
	return node_ok(b) and node_ok(b + Vector2i(1, 0)) and node_ok(b + Vector2i(0, 1)) and node_ok(b + Vector2i(1, 1))


## "water", the landmark type if the map puts one in this block, else the
## district style.
func block_style(b: Vector2i) -> String:
	if not block_land(b):
		return "water"
	if plan.is_park(b):
		return "green"
	if _landmarks.has(b):
		return _landmarks[b].type
	return district_at(block_center(b)).get("style", "quarter")


func block_center(b: Vector2i) -> Vector3:
	var c: PackedVector2Array = plan.corners(b)
	var m := (c[0] + c[1] + c[2] + c[3]) * 0.25
	return Vector3(m.x, 0.0, m.y)


func block_of(pos: Vector3) -> Vector2i:
	return plan.block_of(pos)


## Index into rail_lines of the line running along segment a-b, or -1.
func rail_on(a: Vector2i, b: Vector2i) -> int:
	for k in rail_lines.size():
		var from: Vector2i = rail_lines[k][0]
		var to: Vector2i = rail_lines[k][1]
		if _between(a, from, to) and _between(b, from, to):
			return k
	return -1


func edge_width(n: Vector2i, d: Vector2i) -> float:
	return plan.edge_width(n, d)


# --- Road graph helpers used by traffic, police and spawning -------------------

func node_pos(n: Vector2i) -> Vector3:
	var p: Vector2 = plan.pos(n)
	return Vector3(p.x, 0.0, p.y)


## Drivable node inside the window.
func in_grid(n: Vector2i) -> bool:
	return n.x >= 0 and n.y >= 0 and n.x <= blocks.x and n.y <= blocks.y and node_ok(n)


func nearest_node(pos: Vector3) -> Vector2i:
	var b := block_of(pos)
	var best := Vector2i(clampi(b.x, 0, blocks.x), clampi(b.y, 0, blocks.y))
	var best_d := INF
	for r in [1, 3, 6]:
		for dx in range(-r, r + 2):
			for dz in range(-r, r + 2):
				var m := b + Vector2i(dx, dz)
				if not in_grid(m) or _degree(m) == 0:
					continue
				var d := node_pos(m).distance_squared_to(pos)
				if d < best_d:
					best_d = d
					best = m
		if best_d < INF:
			break
	return best


## Where a car heading `dir` should aim when approaching node `n`: the
## right-hand lane of the street it arrives on.
func lane_point(n: Vector2i, dir: Vector2i) -> Vector3:
	var from := n - dir
	var seg := node_pos(n) - node_pos(from) if plan.has_node(from) else node_pos(n + dir) - node_pos(n)
	seg = seg.normalized()
	var right := Vector3(-seg.z, 0.0, seg.x)
	var w: float = plan.edge_width(from, dir) if plan.has_node(from) else plan.edge_width(n, dir)
	return node_pos(n) + right * lane_offset(w)


## Distance from the centreline to the middle of the right-hand lane.
static func lane_offset(width: float) -> float:
	return maxf(2.4, width * 0.22)


## Picks the next heading at node `n`: mostly straight on, never a U-turn
## unless it is a dead end.
func pick_turn(n: Vector2i, dir: Vector2i, rand: RandomNumberGenerator) -> Vector2i:
	var options: Array[Vector2i] = []
	for d in [dir, dir, Vector2i(dir.y, -dir.x), Vector2i(-dir.y, dir.x)]:
		if in_grid(n + d) and plan.drivable(n, d):
			options.append(d)
	if options.is_empty():
		return -dir
	return options[rand.randi() % options.size()]


func random_node_between(center: Vector3, min_d: float, max_d: float, rand: RandomNumberGenerator) -> Vector2i:
	var c := nearest_node(center)
	var r := ceili(max_d / 40.0)
	for attempt in 24:
		var n := c + Vector2i(rand.randi_range(-r, r), rand.randi_range(-r, r))
		if not in_grid(n) or _degree(n) == 0:
			continue
		var d := node_pos(n).distance_to(Vector3(center.x, 0.0, center.z))
		if d >= min_d and d <= max_d:
			return n
	return Vector2i(-1, -1)


## Returns [loop index, point index] of a sidewalk point in the distance band,
## or an empty array if none was found.
func random_sidewalk_between(center: Vector3, min_d: float, max_d: float, rand: RandomNumberGenerator) -> Array:
	var c := block_of(center)
	var r := ceili(max_d / 40.0)
	for attempt in 24:
		var b := c + Vector2i(rand.randi_range(-r, r), rand.randi_range(-r, r))
		if not _loop_of_block.has(b):
			continue
		var li: int = _loop_of_block[b]
		var loop := sidewalk_loops[li]
		var pi := rand.randi() % loop.size()
		var d := loop[pi].distance_to(center)
		if d >= min_d and d <= max_d:
			return [li, pi]
	return []


func nearest_sidewalk(pos: Vector3) -> Array:
	var best := [0, 0]
	var best_d := INF
	var c := block_of(pos)
	for r in [1, 3, 8]:
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				var li: int = _loop_of_block.get(c + Vector2i(dx, dz), -1)
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
	if _astar == null:
		_build_astar()
	var pts := PackedVector3Array([from])
	var a := nearest_node(from)
	var b := nearest_node(to)
	if in_grid(a) and in_grid(b):
		for id in _astar.get_id_path(_node_id(a), _node_id(b)):
			pts.append(node_pos(Vector2i(id % (blocks.x + 1), id / (blocks.x + 1))))
	pts.append(to)
	return pts


## Like route(), but through the right-hand lane at each junction, for
## scripted drivers.
func route_lanes(from: Vector3, to: Vector3) -> PackedVector3Array:
	var nodes := route(from, to)
	var pts := PackedVector3Array()
	for k in range(1, nodes.size() - 1):
		var here := nearest_node(nodes[k])
		var prev := nearest_node(nodes[k - 1]) if k > 1 else here
		var d := here - prev
		if d == Vector2i.ZERO and k + 1 < nodes.size() - 1:
			d = nearest_node(nodes[k + 1]) - here
		d = d.clamp(Vector2i(-1, -1), Vector2i(1, 1))
		pts.append(lane_point(here, d) if d != Vector2i.ZERO else nodes[k])
	pts.append(to)
	return pts


func _node_id(n: Vector2i) -> int:
	return n.x + n.y * (blocks.x + 1)


func _degree(n: Vector2i) -> int:
	var k := 0
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if plan.drivable(n, d) and in_grid(n + d):
			k += 1
	return k


func _build_astar() -> void:
	_astar = AStar2D.new()
	for i in blocks.x + 1:
		for j in blocks.y + 1:
			var n := Vector2i(i, j)
			if in_grid(n):
				var p := node_pos(n)
				_astar.add_point(_node_id(n), Vector2(p.x, p.z))
	for i in blocks.x + 1:
		for j in blocks.y + 1:
			var n := Vector2i(i, j)
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				if in_grid(n) and in_grid(n + d) and plan.drivable(n, d):
					_astar.connect_points(_node_id(n), _node_id(n + d))


# --- Setup ---------------------------------------------------------------------

func _load_map() -> void:
	var world: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MAP_PATH))
	var city: Dictionary = {}
	for c in world.cities:
		if c.id == CITY_ID:
			city = c
	var window: Dictionary = city.demo_window
	assert(is_equal_approx(window.pitch, PITCH), "demo_window pitch must match PITCH")
	blocks = Vector2i(int(window.blocks[0]), int(window.blocks[1]))
	map_origin = Vector2(window.origin[0], window.origin[1])
	for d in city.districts:
		districts.append({
			"id": d.id, "name": d.name, "style": d.style, "faction": d.faction,
			"rect": Rect2(d.rect[0], d.rect[1], d.rect[2], d.rect[3]),
		})
	var window_rect := Rect2(Vector2.ZERO, Vector2(blocks) * PITCH)
	for lm in world.landmarks:
		var local := Vector2(lm.pos[0], lm.pos[1]) - map_origin
		if window_rect.has_point(local):
			_map_landmarks.append({"id": lm.id, "type": lm.type, "name": lm.name, "local": local})
	for w in world.water:
		if w.id == "morrow":
			_river_half = w.width * 0.5
			for p in w.line:
				_river.append(Vector2(p[0], p[1]))


func _river_distance(p: Vector2) -> float:
	var best := INF
	for k in _river.size() - 1:
		var q := Geometry2D.get_closest_point_to_segment(p, _river[k], _river[k + 1])
		best = minf(best, q.distance_to(p))
	return best


func _between(n: Vector2i, a: Vector2i, b: Vector2i) -> bool:
	return n.x >= mini(a.x, b.x) and n.x <= maxi(a.x, b.x) and n.y >= mini(a.y, b.y) and n.y <= maxi(a.y, b.y)


## Spawn in front of Union Station, respawns in front of the precinct and the
## clinic: all on the landmarks' street-front sidewalks.
func _place_points() -> void:
	spawn_point = landmark_front("union_station")
	police_station = landmark_front("bpd_lantern")
	hospital = landmark_front("floodline_clinic")
	if spawn_point == Vector3.INF:
		spawn_point = block_center(Vector2i(blocks.x / 2, 2))
	if police_station == Vector3.INF:
		police_station = spawn_point
	if hospital == Vector3.INF:
		hospital = spawn_point


## The walking loop round block b: just inside its sidewalk's outer edge.
func _make_loop(b: Vector2i) -> PackedVector3Array:
	var inset := PackedFloat32Array([WALK_INSET, WALK_INSET, WALK_INSET, WALK_INSET])
	var poly: PackedVector2Array = StreetPlan.inset(plan.inner(b), inset)
	var loop := PackedVector3Array()
	for k in 4:
		var a := poly[k]
		var e := poly[(k + 1) % 4]
		var steps := maxi(1, int(a.distance_to(e) / 6.0))
		for s in steps:
			var p := a.lerp(e, float(s) / steps)
			loop.append(Vector3(p.x, 0.0, p.y))
	return loop


func _pick_parking() -> void:
	# Always leave one car at the curb in front of the spawn point.
	var home := landmark_block("union_station")
	if home.x >= 0:
		parked_spots.append([curb_point(home, 9.0), curb_yaw(home)])
	else:
		parked_spots.append([spawn_point + Vector3(9, 0, 4), -PI / 2])
	for i in blocks.x + 1:
		for j in blocks.y + 1:
			var n := Vector2i(i, j)
			for dir in [Vector2i(1, 0), Vector2i(0, 1)]:
				if not (in_grid(n) and in_grid(n + dir) and plan.drivable(n, dir)) or rng.randf() > 0.2:
					continue
				if plan.edge_class(n, dir) == "quarter":
					continue # too narrow to park and pass
				var a := node_pos(n)
				var e := node_pos(n + dir)
				var along := (e - a).normalized()
				var length := a.distance_to(e)
				if length < 30.0:
					continue
				var right := Vector3(-along.z, 0, along.x)
				var side := 1.0 if rng.randf() < 0.5 else -1.0
				var w: float = plan.edge_width(n, dir)
				var p := (a + e) * 0.5 + along * rng.randf_range(-length * 0.5 + 12.0, length * 0.5 - 12.0) + right * side * (w * 0.5 - PARK_FROM_CURB)
				var facing := along * side
				parked_spots.append([p, atan2(-facing.x, -facing.z)])


## One water plane under the whole map; land is built on top of it.
func _build_water() -> void:
	var mb := MeshBuilder.new()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for i in range(-MARGIN, blocks.x + MARGIN + 1):
		for j in range(-MARGIN, blocks.y + MARGIN + 1):
			var p: Vector2 = plan.pos(Vector2i(i, j))
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	lo -= Vector2(300, 300)
	hi += Vector2(300, 300)
	mb.box(Vector3((lo.x + hi.x) * 0.5, -0.55, (lo.y + hi.y) * 0.5), Vector3(hi.x - lo.x, 0.1, hi.y - lo.y), Color(0.16, 0.36, 0.42))
	var inst := mb.make_instance()
	inst.name = "Water"
	inst.material_override = MeshBuilder.water_material()
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)


## Invisible walls just outside the window's edge streets.
func _build_bounds() -> void:
	var body := StaticBody3D.new()
	body.name = "Bounds"
	body.collision_layer = L.WORLD
	body.collision_mask = 0
	add_child(body)
	var ring: Array = []
	for i in blocks.x:
		ring.append([Vector2i(i, 0), Vector2i(1, 0)])
		ring.append([Vector2i(i, blocks.y), Vector2i(1, 0)])
	for j in blocks.y:
		ring.append([Vector2i(0, j), Vector2i(0, 1)])
		ring.append([Vector2i(blocks.x, j), Vector2i(0, 1)])
	var mid_all := block_center(blocks / 2)
	for e in ring:
		var n: Vector2i = e[0]
		var d: Vector2i = e[1]
		var a := node_pos(n)
		var b := node_pos(n + d)
		var mid := (a + b) * 0.5
		var along := (b - a).normalized()
		var out := Vector3(-along.z, 0, along.x)
		if out.dot(mid - mid_all) < 0.0:
			out = -out
		var w := maxf(plan.edge_width(n, d), 11.0)
		var center := mid + out * (w * 0.5 + 1.0) + Vector3(0, 3, 0)
		_add_shape(body, center, Vector3(a.distance_to(b) + w + 4.0, 6.0, 1.0), atan2(-along.z, along.x))


# --- Streaming -----------------------------------------------------------------

func _cell_center(cell: Vector2i) -> Vector2:
	var c := block_center(cell)
	return Vector2(c.x, c.z)


## Cells whose centre is within `radius` of `pos`, nearest first.
func _cells_near(pos: Vector3, radius: float) -> Array:
	var p := Vector2(pos.x, pos.z)
	var c := block_of(pos)
	var r := ceili(radius / 38.0)
	var found: Array = []
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			var cell := c + Vector2i(dx, dz)
			if cell.x < -MARGIN or cell.y < -MARGIN or cell.x >= blocks.x + MARGIN or cell.y >= blocks.y + MARGIN:
				continue
			if _cell_center(cell).distance_to(p) <= radius:
				found.append(cell)
	found.sort_custom(func(a, b): return _cell_center(a).distance_squared_to(p) < _cell_center(b).distance_squared_to(p))
	return found


func _start_task(cell: Vector2i) -> void:
	_task_cell = cell
	_task = WorkerThreadPool.add_task(_run_task.bind(cell), false, "city cell")


func _run_task(cell: Vector2i) -> void:
	_task_result = Cells.build(self, cell)


func _poll_task() -> void:
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		_finish_task()


func _finish_task() -> void:
	if _task < 0:
		return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	if not _cells.has(_task_cell):
		_add_cell(_task_cell, _task_result)
	_task_result = {}


func _add_cell(cell: Vector2i, built: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "Cell_%d_%d" % [cell.x, cell.y]
	if built.mesh.triangle_count() > 0: # open water cells have nothing to draw
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
	_cells[cell] = root


func _unload(cell: Vector2i) -> void:
	var root: Node3D = _cells[cell]
	building_count -= int(root.get_meta("buildings"))
	_cells.erase(cell)
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
