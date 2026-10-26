extends Node3D
## Grey-box city built from the world map (res://data/world_map.json): a grid
## of blocks whose building style, faction and landmarks come from the map's
## districts. Builds the city's "prototype_window" for now.
##
## Intersections ("nodes") sit at (i * PITCH, j * PITCH) for i, j in 0..BLOCKS.
## Local (0, 0) is the window origin in world-map metres (map y = game z).
## Traffic drives on the right, LANE_OFFSET from the road centre line.

const MeshBuilder = preload("res://scripts/mesh_builder.gd")
const L = preload("res://scripts/layers.gd")

const MAP_PATH := "res://data/world_map.json"
const CITY_ID := "bellerive"
const BLOCKS := 6
const BLOCK := 40.0
const ROAD := 12.0
const PITCH := BLOCK + ROAD
const SIZE := BLOCKS * PITCH
const LANE_OFFSET := 3.0
const SIDEWALK := 3.0
const CURB_PARKING := 4.6

const ASPHALT := Color(0.2, 0.2, 0.23)
const PAVEMENT := Color(0.55, 0.53, 0.5)
const MARKING := Color(0.92, 0.8, 0.3)
const GRASS := Color(0.32, 0.55, 0.28)
const PASTELS := [
	Color(0.9, 0.58, 0.45), Color(0.95, 0.78, 0.38), Color(0.45, 0.72, 0.68),
	Color(0.65, 0.55, 0.82), Color(0.9, 0.48, 0.58), Color(0.52, 0.7, 0.45),
	Color(0.88, 0.84, 0.72),
]
const IRON := Color(0.12, 0.16, 0.14)

var rng := RandomNumberGenerator.new()
var building_count := 0
## One closed walking loop per block, ordered around its perimeter.
var sidewalk_loops: Array[PackedVector3Array] = []
## [position, yaw] pairs for cars parked along the curbs.
var parked_spots: Array = []
var spawn_point := Vector3.ZERO
var hospital := Vector3.ZERO
var police_station := Vector3.ZERO
## World-map position of local (0, 0).
var map_origin := Vector2.ZERO
var districts: Array = []
var _landmark_blocks := {}

var _mesh := MeshBuilder.new()
var _body: StaticBody3D


func build(seed_value: int) -> void:
	rng.seed = seed_value
	_load_map()
	_body = StaticBody3D.new()
	_body.collision_layer = L.WORLD
	_body.collision_mask = 0
	add_child(_body)

	_mesh.box(Vector3(SIZE * 0.5, -0.05, SIZE * 0.5), Vector3(SIZE + 60.0, 0.1, SIZE + 60.0), ASPHALT)
	_build_river()
	_build_markings()
	for i in BLOCKS:
		for j in BLOCKS:
			_build_block(Vector2i(i, j))
	_build_bounds()
	_pick_parking()

	var inst := _mesh.make_instance()
	inst.material_override = MeshBuilder.cutaway_material()
	add_child(inst)
	spawn_point = node_pos(Vector2i(2, 3)) + Vector3(7.5, 0.0, 7.5)
	if police_station == Vector3.ZERO:
		police_station = spawn_point
	if hospital == Vector3.ZERO:
		hospital = spawn_point


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


func _load_map() -> void:
	var world: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MAP_PATH))
	var city: Dictionary = {}
	for c in world.cities:
		if c.id == CITY_ID:
			city = c
	var window: Dictionary = city.prototype_window
	assert(int(window.blocks) == BLOCKS and is_equal_approx(window.pitch, PITCH), "prototype_window must match BLOCKS and PITCH")
	map_origin = Vector2(window.origin[0], window.origin[1])
	for d in city.districts:
		districts.append({
			"id": d.id, "name": d.name, "style": d.style, "faction": d.faction,
			"rect": Rect2(d.rect[0], d.rect[1], d.rect[2], d.rect[3]),
		})
	for lm in world.landmarks:
		var local := Vector2(lm.pos[0], lm.pos[1]) - map_origin
		var b := Vector2i(floori(local.x / PITCH), floori(local.y / PITCH))
		if b.x >= 0 and b.y >= 0 and b.x < BLOCKS and b.y < BLOCKS:
			_landmark_blocks[b] = lm.type


# --- Road graph helpers used by traffic, police and spawning ---------------

func node_pos(n: Vector2i) -> Vector3:
	return Vector3(n.x * PITCH, 0.0, n.y * PITCH)


func in_grid(n: Vector2i) -> bool:
	return n.x >= 0 and n.y >= 0 and n.x <= BLOCKS and n.y <= BLOCKS


func nearest_node(pos: Vector3) -> Vector2i:
	return Vector2i(
		clampi(roundi(pos.x / PITCH), 0, BLOCKS),
		clampi(roundi(pos.z / PITCH), 0, BLOCKS))


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
	for attempt in 24:
		var n := Vector2i(rand.randi_range(0, BLOCKS), rand.randi_range(0, BLOCKS))
		var d := node_pos(n).distance_to(Vector3(center.x, 0.0, center.z))
		if d >= min_d and d <= max_d:
			return n
	return Vector2i(-1, -1)


## Returns [loop index, point index] of a sidewalk point in the distance band,
## or an empty array if none was found.
func random_sidewalk_between(center: Vector3, min_d: float, max_d: float, rand: RandomNumberGenerator) -> Array:
	for attempt in 24:
		var li := rand.randi() % sidewalk_loops.size()
		var loop := sidewalk_loops[li]
		var pi := rand.randi() % loop.size()
		var d := loop[pi].distance_to(center)
		if d >= min_d and d <= max_d:
			return [li, pi]
	return []


func nearest_sidewalk(pos: Vector3) -> Array:
	var best := [0, 0]
	var best_d := INF
	for li in sidewalk_loops.size():
		var loop := sidewalk_loops[li]
		for pi in loop.size():
			var d := loop[pi].distance_squared_to(pos)
			if d < best_d:
				best_d = d
				best = [li, pi]
	return best


# --- Construction ------------------------------------------------------------

func _block_rect(b: Vector2i) -> Rect2:
	var origin := Vector2(b.x * PITCH + ROAD * 0.5, b.y * PITCH + ROAD * 0.5)
	return Rect2(origin, Vector2(BLOCK, BLOCK))


## Landmark type if the map puts one in this block, else the district style.
func _block_style(b: Vector2i) -> String:
	if _landmark_blocks.has(b):
		return _landmark_blocks[b]
	var center := node_pos(b) + Vector3(PITCH * 0.5, 0, PITCH * 0.5)
	return district_at(center).get("style", "quarter")


func _build_block(b: Vector2i) -> void:
	var r := _block_rect(b)
	var center := Vector3(r.get_center().x, 0.0, r.get_center().y)
	_mesh.box(center + Vector3(0, 0.075, 0), Vector3(BLOCK, 0.15, BLOCK), PAVEMENT)
	_add_sidewalk_loop(r)
	var inner := r.grow(-SIDEWALK)
	match _block_style(b):
		"park":
			_build_park(inner)
		"court":
			_build_court(inner)
		"police":
			_solid(Vector3(inner.get_center().x, 0, inner.get_center().y), Vector3(inner.size.x, 9.0, inner.size.y * 0.6), Color(0.45, 0.55, 0.75))
			police_station = Vector3(r.get_center().x, 0, r.end.y - 1.5)
		"hospital":
			_solid(Vector3(inner.get_center().x, 0, inner.get_center().y), Vector3(inner.size.x * 0.8, 14.0, inner.size.y * 0.8), Color(0.95, 0.95, 0.97))
			_mesh.box(Vector3(inner.get_center().x, 14.1, inner.get_center().y), Vector3(8, 0.2, 2.5), Color(0.85, 0.15, 0.15))
			_mesh.box(Vector3(inner.get_center().x, 14.1, inner.get_center().y), Vector3(2.5, 0.2, 8), Color(0.85, 0.15, 0.15))
			hospital = Vector3(r.get_center().x, 0, r.position.y + 1.5)
		"docks":
			_build_docks(inner)
		"downtown":
			_build_lots(inner, 2, 18.0, 42.0, [Color(0.55, 0.6, 0.68), Color(0.7, 0.72, 0.75), Color(0.45, 0.5, 0.58)], false)
		"wards":
			_build_lots(inner, 4, 3.5, 5.5, PASTELS, false)
		"heights":
			_build_heights(inner)
		"bayou":
			_build_bayou(inner)
		_:
			_build_lots(inner, 3, 6.5, 11.0, PASTELS, true)


func _build_lots(area: Rect2, split: int, min_h: float, max_h: float, palette: Array, balconies: bool) -> void:
	var lot := area.size / split
	for x in split:
		for z in split:
			if split == 3 and x == 1 and z == 1:
				continue # courtyard
			var w := lot.x - 1.0
			var d := lot.y - 1.0
			var h := rng.randf_range(min_h, max_h)
			var c := Vector3(area.position.x + lot.x * (x + 0.5), 0.0, area.position.y + lot.y * (z + 0.5))
			var color: Color = palette[rng.randi() % palette.size()]
			_solid(c, Vector3(w, h, d), color)
			_mesh.box(c + Vector3(0, h + 0.15, 0), Vector3(w + 0.4, 0.3, d + 0.4), color.darkened(0.3))
			if balconies:
				_mesh.box(c + Vector3(0, 3.6, 0), Vector3(w + 1.4, 0.15, d + 1.4), IRON)
				_mesh.box(c + Vector3(0, 4.15, 0), Vector3(w + 1.45, 0.08, d + 1.45), IRON)


## Mansions set back in gardens.
func _build_heights(area: Rect2) -> void:
	var c := Vector3(area.get_center().x, 0, area.get_center().y)
	_mesh.box(c + Vector3(0, 0.17, 0), Vector3(area.size.x, 0.05, area.size.y), GRASS)
	var half := area.size.x * 0.25
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			var p := c + Vector3(x * half, 0, z * half)
			_solid(p, Vector3(12.0, 7.5, 9.0), Color(0.95, 0.93, 0.86))
			_mesh.box(p + Vector3(0, 7.65, 0), Vector3(12.6, 0.3, 9.6), Color(0.35, 0.3, 0.32))
	_add_trees(area, 6, c)


## Swamp edge: wet ground, a couple of stilt shacks and trees.
func _build_bayou(area: Rect2) -> void:
	var c := Vector3(area.get_center().x, 0, area.get_center().y)
	_mesh.box(c + Vector3(0, 0.17, 0), Vector3(area.size.x, 0.05, area.size.y), Color(0.28, 0.4, 0.27))
	_mesh.box(c + Vector3(4, 0.2, 4), Vector3(area.size.x * 0.5, 0.02, area.size.y * 0.4), Color(0.25, 0.38, 0.42))
	for p in [c + Vector3(-8, 0, -6), c + Vector3(7, 0, -9)]:
		_solid(p + Vector3(0, 1.2, 0), Vector3(6.0, 3.0, 5.0), Color(0.5, 0.4, 0.3))
	_add_trees(area, 8, c)


func _build_park(area: Rect2) -> void:
	var c := Vector3(area.get_center().x, 0, area.get_center().y)
	_mesh.box(c + Vector3(0, 0.17, 0), Vector3(area.size.x, 0.05, area.size.y), GRASS)
	_mesh.box(c + Vector3(0, 0.2, 0), Vector3(area.size.x, 0.02, 3.0), PAVEMENT)
	_mesh.box(c + Vector3(0, 0.2, 0), Vector3(3.0, 0.02, area.size.y), PAVEMENT)
	_add_trees(area, 10, c)


## Scatters trees in an area, keeping the cross paths through `c` clear.
func _add_trees(area: Rect2, count: int, c: Vector3) -> void:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.25
	trunk.bottom_radius = 0.3
	trunk.height = 2.4
	trunk.radial_segments = 6
	var crown := SphereMesh.new()
	crown.radius = 2.0
	crown.height = 3.4
	crown.radial_segments = 8
	crown.rings = 4
	for i in count:
		var p := Vector3(
			rng.randf_range(area.position.x + 3, area.end.x - 3), 0,
			rng.randf_range(area.position.y + 3, area.end.y - 3))
		if absf(p.x - c.x) < 3.0 or absf(p.z - c.z) < 3.0:
			continue # keep the paths clear
		_mesh.primitive(trunk, Transform3D(Basis(), p + Vector3(0, 1.2, 0)), Color(0.4, 0.28, 0.18))
		_mesh.primitive(crown, Transform3D(Basis(), p + Vector3(0, 3.6, 0)), GRASS.darkened(0.25))
		_collider(p + Vector3(0, 1.2, 0), Vector3(0.6, 2.4, 0.6))


func _build_court(area: Rect2) -> void:
	var c := Vector3(area.get_center().x, 0, area.get_center().y)
	_mesh.box(c + Vector3(0, 0.17, 0), Vector3(area.size.x, 0.05, area.size.y), Color(0.75, 0.45, 0.3))
	_mesh.box(c + Vector3(0, 0.2, 0), Vector3(15.0, 0.02, 28.0), Color(0.2, 0.42, 0.65))
	_mesh.box(c + Vector3(0, 0.21, 0), Vector3(15.0, 0.02, 0.2), Color.WHITE)
	for side in [-1.0, 1.0]:
		var post := c + Vector3(0, 0, side * 13.5)
		_solid(post, Vector3(0.25, 3.0, 0.25), Color(0.3, 0.3, 0.3))
		_mesh.box(post + Vector3(0, 3.1, -side * 0.3), Vector3(1.8, 1.1, 0.1), Color.WHITE)


func _build_docks(area: Rect2) -> void:
	var c := Vector3(area.get_center().x, 0, area.get_center().y)
	_solid(c + Vector3(0, 0, -area.size.y * 0.2), Vector3(area.size.x - 2, 8.0, area.size.y * 0.5), Color(0.55, 0.52, 0.48))
	var palette := [Color(0.8, 0.3, 0.2), Color(0.2, 0.45, 0.7), Color(0.3, 0.6, 0.35), Color(0.85, 0.6, 0.2)]
	for i in 5:
		var p := Vector3(area.position.x + 4 + i * 6.5, 0, area.end.y - 6)
		var stack := rng.randi_range(1, 2)
		for s in stack:
			_mesh.box(p + Vector3(0, 1.3 + s * 2.6, 0), Vector3(2.4, 2.6, 6.0), palette[rng.randi() % palette.size()])
		_collider(p + Vector3(0, 1.3 * stack, 0), Vector3(2.4, 2.6 * stack, 6.0))


func _build_river() -> void:
	var z0 := SIZE + ROAD * 0.5 + 4.0
	_mesh.box(Vector3(SIZE * 0.5, 0.15, z0 - 2.0), Vector3(SIZE + 60.0, 0.3, 4.0), Color(0.5, 0.47, 0.42))
	_mesh.box(Vector3(SIZE * 0.5, -0.02, z0 + 60.0), Vector3(SIZE + 400.0, 0.1, 120.0), Color(0.2, 0.42, 0.55))


func _build_markings() -> void:
	for line in BLOCKS + 1:
		for seg in BLOCKS:
			var start := seg * PITCH + ROAD * 0.5 + 2.0
			var t := start
			while t < (seg + 1) * PITCH - ROAD * 0.5 - 2.0:
				var a := line * PITCH
				_mesh.box(Vector3(t + 1.5, 0.01, a), Vector3(3.0, 0.02, 0.2), MARKING)
				_mesh.box(Vector3(a, 0.01, t + 1.5), Vector3(0.2, 0.02, 3.0), MARKING)
				t += 6.0


func _build_bounds() -> void:
	var lo := -ROAD * 0.5 - 1.0
	var hi := SIZE + ROAD * 0.5 + 1.0
	var mid := SIZE * 0.5
	var span := SIZE + ROAD + 4.0
	_collider(Vector3(mid, 2, lo), Vector3(span, 4, 1))
	_collider(Vector3(mid, 2, hi), Vector3(span, 4, 1))
	_collider(Vector3(lo, 2, mid), Vector3(1, 4, span))
	_collider(Vector3(hi, 2, mid), Vector3(1, 4, span))


func _add_sidewalk_loop(r: Rect2) -> void:
	var inset := r.grow(-1.5)
	var corners := [
		Vector2(inset.position.x, inset.position.y), Vector2(inset.end.x, inset.position.y),
		Vector2(inset.end.x, inset.end.y), Vector2(inset.position.x, inset.end.y),
	]
	var loop := PackedVector3Array()
	for k in 4:
		var a: Vector2 = corners[k]
		var b: Vector2 = corners[(k + 1) % 4]
		var steps := int(a.distance_to(b) / 6.0)
		for s in steps:
			var p := a.lerp(b, float(s) / steps)
			loop.append(Vector3(p.x, 0.0, p.y))
	sidewalk_loops.append(loop)


func _pick_parking() -> void:
	# Always leave one car next to the player's spawn.
	var home := node_pos(Vector2i(2, 3))
	parked_spots.append([home + Vector3(16.0, 0, CURB_PARKING), -PI / 2])
	for line in BLOCKS + 1:
		for seg in BLOCKS:
			if rng.randf() > 0.18:
				continue
			var along := seg * PITCH + PITCH * 0.5 + rng.randf_range(-12, 12)
			var side := CURB_PARKING if rng.randf() < 0.5 else -CURB_PARKING
			if rng.randf() < 0.5:
				parked_spots.append([Vector3(along, 0, line * PITCH + side), -PI / 2])
			else:
				parked_spots.append([Vector3(line * PITCH + side, 0, along), 0.0])


func _solid(base_center: Vector3, size: Vector3, color: Color) -> void:
	var center := base_center + Vector3(0, size.y * 0.5, 0)
	_mesh.box(center, size, color)
	_collider(center, size)
	building_count += 1


func _collider(center: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = center
	_body.add_child(shape)
