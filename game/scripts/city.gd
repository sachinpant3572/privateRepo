extends Node3D
## Bellerive demo map, built from the world map (res://data/world_map.json):
## the city's "demo_window" is a grid of blocks whose style, faction and
## landmarks come from the map's districts, cut by the Morrow River.
##
## Intersections ("nodes") sit at (i * PITCH, j * PITCH). Local (0, 0) is the
## window origin in world-map metres (map y = game z). A cell (i, j) owns its
## block, node (i, j) and the road segments running east and south from it.
## Cells are built on a worker thread as the focus moves and freed when far
## away; each one is a single mesh plus one static body. A ring of MARGIN
## cells outside the window is built without collisions so the city doesn't
## end at the edge of the screen. Traffic drives on the right.

const MeshBuilder = preload("res://scripts/mesh_builder.gd")
const Cells = preload("res://scripts/city_cells.gd")
const L = preload("res://scripts/layers.gd")

const MAP_PATH := "res://data/world_map.json"
const CITY_ID := "bellerive"
const BLOCK := 40.0
const ROAD := 12.0
const PITCH := BLOCK + ROAD
const LANE_OFFSET := 3.0
const SIDEWALK := 3.0
const WALK_INSET := 1.2
const CURB_PARKING := 4.6
const MARGIN := 2
const LOAD_RADIUS := 115.0
const UNLOAD_RADIUS := 165.0

## Window size in blocks, from the map.
var blocks := Vector2i(25, 22)
var seed_value := 0
var rng := RandomNumberGenerator.new()
## Buildings in the cells that are currently loaded.
var building_count := 0
## One closed walking loop per land block, ordered around its perimeter.
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
## Streetcar lines: [from node, to node, rusty], straight along one axis.
var rail_lines: Array = []
## Node the streaming follows; the spawn point when unset.
var focus_node: Node3D

var _landmarks := {} # block -> {id, type, name}
var _water := {} # node -> true where the river covers it
var _river: PackedVector2Array
var _river_half := 80.0
var _loop_of_block := {}
var _cells := {} # cell -> Node3D
var _task := -1
var _task_cell := Vector2i.ZERO
var _task_result: Dictionary
var _stream_tick := 0.0


func build(seed_v: int) -> void:
	seed_value = seed_v
	rng.seed = seed_v
	_load_map()
	for i in range(-MARGIN, blocks.x + MARGIN + 1):
		for j in range(-MARGIN, blocks.y + MARGIN + 1):
			if _river_distance(_map_pos(Vector2i(i, j))) < _river_half:
				_water[Vector2i(i, j)] = true
	rail_lines = [
		[Vector2i(6, 3), Vector2i(6, 20), false], # Lantern Line, Union Station to the river
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


func in_window(b: Vector2i) -> bool:
	return b.x >= 0 and b.y >= 0 and b.x < blocks.x and b.y < blocks.y


func node_ok(n: Vector2i) -> bool:
	return not _water.has(n)


## A block is land when all four corners are; land blocks always have a road
## on every side.
func block_land(b: Vector2i) -> bool:
	return node_ok(b) and node_ok(b + Vector2i(1, 0)) and node_ok(b + Vector2i(0, 1)) and node_ok(b + Vector2i(1, 1))


## "water", the landmark type if the map puts one in this block, else the
## district style.
func block_style(b: Vector2i) -> String:
	if not block_land(b):
		return "water"
	if _landmarks.has(b):
		return _landmarks[b].type
	return district_at(block_center(b)).get("style", "quarter")


func block_center(b: Vector2i) -> Vector3:
	return Vector3((b.x + 0.5) * PITCH, 0.0, (b.y + 0.5) * PITCH)


func block_of(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / PITCH), floori(pos.z / PITCH))


## Index into rail_lines of the line running along segment a-b, or -1.
func rail_on(a: Vector2i, b: Vector2i) -> int:
	for k in rail_lines.size():
		var from: Vector2i = rail_lines[k][0]
		var to: Vector2i = rail_lines[k][1]
		if _between(a, from, to) and _between(b, from, to):
			return k
	return -1


# --- Road graph helpers used by traffic, police and spawning -------------------

func node_pos(n: Vector2i) -> Vector3:
	return Vector3(n.x * PITCH, 0.0, n.y * PITCH)


## Drivable node inside the window.
func in_grid(n: Vector2i) -> bool:
	return n.x >= 0 and n.y >= 0 and n.x <= blocks.x and n.y <= blocks.y and node_ok(n)


func nearest_node(pos: Vector3) -> Vector2i:
	var n := Vector2i(
		clampi(roundi(pos.x / PITCH), 0, blocks.x),
		clampi(roundi(pos.z / PITCH), 0, blocks.y))
	if in_grid(n):
		return n
	var best := n
	var best_d := INF
	for r in range(1, 4):
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				var m := n + Vector2i(dx, dz)
				var d := node_pos(m).distance_squared_to(pos)
				if in_grid(m) and d < best_d:
					best_d = d
					best = m
		if best_d < INF:
			break
	return best


## Where a car heading `dir` should aim when approaching node `n`.
func lane_point(n: Vector2i, dir: Vector2i) -> Vector3:
	var right := Vector3(-dir.y, 0.0, dir.x)
	return node_pos(n) + right * LANE_OFFSET


## Picks the next heading at node `n`: mostly straight on, never a U-turn
## unless it is a dead end.
func pick_turn(n: Vector2i, dir: Vector2i, rand: RandomNumberGenerator) -> Vector2i:
	var options: Array[Vector2i] = []
	for d in [dir, dir, Vector2i(dir.y, -dir.x), Vector2i(-dir.y, dir.x)]:
		if in_grid(n + d):
			options.append(d)
	if options.is_empty():
		return -dir
	return options[rand.randi() % options.size()]


func random_node_between(center: Vector3, min_d: float, max_d: float, rand: RandomNumberGenerator) -> Vector2i:
	var c := nearest_node(center)
	var r := ceili(max_d / PITCH)
	for attempt in 24:
		var n := c + Vector2i(rand.randi_range(-r, r), rand.randi_range(-r, r))
		if not in_grid(n):
			continue
		var d := node_pos(n).distance_to(Vector3(center.x, 0.0, center.z))
		if d >= min_d and d <= max_d:
			return n
	return Vector2i(-1, -1)


## Returns [loop index, point index] of a sidewalk point in the distance band,
## or an empty array if none was found.
func random_sidewalk_between(center: Vector3, min_d: float, max_d: float, rand: RandomNumberGenerator) -> Array:
	var c := block_of(center)
	var r := ceili(max_d / PITCH)
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
	for lm in world.landmarks:
		var local := Vector2(lm.pos[0], lm.pos[1]) - map_origin
		var b := Vector2i(floori(local.x / PITCH), floori(local.y / PITCH))
		if in_window(b):
			_landmarks[b] = {"id": lm.id, "type": lm.type, "name": lm.name}
	for w in world.water:
		if w.id == "morrow":
			_river_half = w.width * 0.5
			for p in w.line:
				_river.append(Vector2(p[0], p[1]))


func _map_pos(n: Vector2i) -> Vector2:
	return map_origin + Vector2(n.x, n.y) * PITCH


func _river_distance(p: Vector2) -> float:
	var best := INF
	for k in _river.size() - 1:
		var q := Geometry2D.get_closest_point_to_segment(p, _river[k], _river[k + 1])
		best = minf(best, q.distance_to(p))
	return best


func _between(n: Vector2i, a: Vector2i, b: Vector2i) -> bool:
	return n.x >= mini(a.x, b.x) and n.x <= maxi(a.x, b.x) and n.y >= mini(a.y, b.y) and n.y <= maxi(a.y, b.y)


## Spawn in front of Union Station, respawns in front of the precinct and the
## clinic: all on the south sidewalk, facing the camera.
func _place_points() -> void:
	for b in _landmarks:
		var front := block_center(b) + Vector3(0, 0, BLOCK * 0.5 - WALK_INSET)
		match _landmarks[b].id:
			"union_station":
				spawn_point = front
			"bpd_lantern":
				police_station = front
			"floodline_clinic":
				hospital = front
	if police_station == Vector3.ZERO:
		police_station = spawn_point
	if hospital == Vector3.ZERO:
		hospital = spawn_point


func _make_loop(b: Vector2i) -> PackedVector3Array:
	var c := block_center(b)
	var half := BLOCK * 0.5 - WALK_INSET
	var corners := [
		Vector2(c.x - half, c.z - half), Vector2(c.x + half, c.z - half),
		Vector2(c.x + half, c.z + half), Vector2(c.x - half, c.z + half),
	]
	var loop := PackedVector3Array()
	for k in 4:
		var a: Vector2 = corners[k]
		var e: Vector2 = corners[(k + 1) % 4]
		var steps := int(a.distance_to(e) / 6.0)
		for s in steps:
			var p := a.lerp(e, float(s) / steps)
			loop.append(Vector3(p.x, 0.0, p.y))
	return loop


func _pick_parking() -> void:
	# Always leave one car at the curb in front of the spawn point.
	var front := spawn_point + Vector3(9.0, 0, WALK_INSET + ROAD * 0.5 - CURB_PARKING)
	parked_spots.append([front, -PI / 2])
	for i in blocks.x + 1:
		for j in blocks.y + 1:
			var n := Vector2i(i, j)
			for dir in [Vector2i(1, 0), Vector2i(0, 1)]:
				if not (in_grid(n) and in_grid(n + dir)) or rng.randf() > 0.2:
					continue
				var mid := (node_pos(n) + node_pos(n + dir)) * 0.5
				var along := rng.randf_range(-12.0, 12.0)
				var side := CURB_PARKING if rng.randf() < 0.5 else -CURB_PARKING
				if dir.x != 0:
					parked_spots.append([mid + Vector3(along, 0, side), -PI / 2])
				else:
					parked_spots.append([mid + Vector3(side, 0, along), 0.0])


## One water plane under the whole map; land is built on top of it.
func _build_water() -> void:
	var mb := MeshBuilder.new()
	var lo := -MARGIN * PITCH - 200.0
	var size := Vector2((blocks.x + 2 * MARGIN) * PITCH + 400.0, (blocks.y + 2 * MARGIN) * PITCH + 400.0)
	mb.box(Vector3(lo + size.x * 0.5, -0.55, lo + size.y * 0.5), Vector3(size.x, 0.1, size.y), Color(0.16, 0.36, 0.42))
	var inst := mb.make_instance()
	inst.name = "Water"
	inst.material_override = MeshBuilder.water_material()
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)


## Invisible walls just outside the window's edge roads.
func _build_bounds() -> void:
	var body := StaticBody3D.new()
	body.name = "Bounds"
	body.collision_layer = L.WORLD
	body.collision_mask = 0
	add_child(body)
	var lo := -ROAD * 0.5 - 0.8
	var hi := Vector2(blocks.x * PITCH + ROAD * 0.5 + 0.8, blocks.y * PITCH + ROAD * 0.5 + 0.8)
	var mid := Vector2((lo + hi.x) * 0.5, (lo + hi.y) * 0.5)
	var span := Vector2(hi.x - lo + 2.0, hi.y - lo + 2.0)
	for wall in [
		[Vector3(mid.x, 3, lo), Vector3(span.x, 6, 1)], [Vector3(mid.x, 3, hi.y), Vector3(span.x, 6, 1)],
		[Vector3(lo, 3, mid.y), Vector3(1, 6, span.y)], [Vector3(hi.x, 3, mid.y), Vector3(1, 6, span.y)],
	]:
		_add_shape(body, wall[0], wall[1])


# --- Streaming -----------------------------------------------------------------

func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * PITCH, (cell.y + 0.5) * PITCH)


## Cells whose centre is within `radius` of `pos`, nearest first.
func _cells_near(pos: Vector3, radius: float) -> Array:
	var p := Vector2(pos.x, pos.z)
	var c := block_of(pos)
	var r := ceili(radius / PITCH)
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
	for group in [[built.colliders, L.WORLD], [built.props, L.PROPS]]:
		if group[0].is_empty():
			continue
		var body := StaticBody3D.new()
		body.collision_layer = group[1]
		body.collision_mask = 0
		root.add_child(body)
		for c in group[0]:
			_add_shape(body, c[0], c[1])
	root.set_meta("buildings", built.buildings)
	building_count += built.buildings
	add_child(root)
	_cells[cell] = root


func _unload(cell: Vector2i) -> void:
	var root: Node3D = _cells[cell]
	building_count -= int(root.get_meta("buildings"))
	_cells.erase(cell)
	root.queue_free()


func _add_shape(body: StaticBody3D, center: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = center
	body.add_child(shape)


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
