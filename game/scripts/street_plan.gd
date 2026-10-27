extends RefCounted
## Bellerive's street plan (see reference/MAP_BUILDING.md). The streets keep
## a grid's topology (junction (i, j) links to its four neighbours), which
## traffic, streaming, the GPS and missions rely on, but nothing else about
## it is a grid:
## - Rows are arcs following the river's crescent and columns are spokes
##   fanning out from it, like New Orleans.
## - Row and column spacing changes by district, and every junction is
##   nudged a little.
## - Each street has a class (boulevard with a neutral ground, avenue, river
##   road, street, narrow Quarter street, pedestrian lane, or closed), and
##   so a width.
## - Junctions next to the river are pulled onto a curve along the bank.
## - Each block is the polygon between its four junctions, pulled in by its
##   streets' half widths and the sidewalk.
## Positions are local metres (map origin at the window's corner, z = map y).

const BASE := 52.0
const SIDEWALK := 3.0
## The crescent's centre lies this far south of the window.
const CRESCENT_RADIUS := 2000.0
const JITTER := 2.2
## Minimum junction spacing round a landmark's block.
const LANDMARK_SPACING := 60.0

## Street classes: width (m), drivable, and the look cells give them.
const CLASSES := {
	"boulevard": {"width": 24.0, "drive": true},
	"avenue": {"width": 15.0, "drive": true},
	"river": {"width": 14.0, "drive": true},
	"street": {"width": 11.0, "drive": true},
	"quarter": {"width": 9.0, "drive": true},
	"lane": {"width": 7.0, "drive": false},
	"closed": {"width": 0.0, "drive": false},
}
## Street names for the boulevards and avenue (shown on the full map).
const NAMES := {"spoke_boulevard": "Lantern Boulevard", "arc_boulevard": "Crescent Boulevard", "avenue": "Rampart Avenue"}

var blocks := Vector2i(25, 22)
var margin := 2
var seed_value := 0
## Index of the Lantern Line spoke column and the boulevard row.
var boulevard_col := 6
var boulevard_row := 10
var avenue_col := 13

var col_w := PackedFloat32Array() # spacing after column i (index i + margin)
var row_h := PackedFloat32Array()
var center := Vector2.ZERO # crescent centre
var ref_radius := 0.0
var _cum_u := PackedFloat32Array()
var _cum_z := PackedFloat32Array()
var _pos := {} # Vector2i -> Vector2
var _water := {} # Vector2i -> true
var _bank := {} # Vector2i -> true (pulled onto the river road)
var _class := {} # [n, d] key -> class name
## Junction removed to make the Liberty Green park (its four blocks join
## into one); (-99, -99) when there is none.
var park_node := Vector2i(-99, -99)
var _lots := {} # block -> PackedVector2Array
var _inner := {} # block -> PackedVector2Array (inside the roads)

var _district_style: Callable # (local pos Vector2) -> style string
var _river_distance: Callable # (local pos Vector2) -> metres to the centreline
var _river_half := 80.0


## Builds the plan. `style_at` gives the district style at a local point,
## `river_distance` the distance to the river centreline; `landmarks` are
## local points whose blocks must be big enough for a landmark.
func build(size: Vector2i, seed_v: int, style_at: Callable, river_distance: Callable, river_half: float, landmarks: Array, park_at := Vector2(-1, -1)) -> void:
	blocks = size
	seed_value = seed_v
	_district_style = style_at
	_river_distance = river_distance
	_river_half = river_half
	_spacing()
	# Landmark blocks get room: widen their row and column and redo the
	# layout, until no landmark lands in a narrow block (widening moves
	# landmarks into the next block over now and then).
	for pass_ in 6:
		_place_nodes()
		var grew := false
		for p in landmarks:
			var b := block_of(Vector3(p.x, 0, p.y))
			var ck := b.x + margin
			var rk := b.y + margin
			if ck >= 0 and ck < col_w.size() and col_w[ck] < LANDMARK_SPACING:
				col_w[ck] = LANDMARK_SPACING
				grew = true
			if rk >= 0 and rk < row_h.size() and row_h[rk] < LANDMARK_SPACING:
				row_h[rk] = LANDMARK_SPACING
				grew = true
		if not grew:
			break
	_place_nodes()
	_mark_water()
	_snap_bank()
	_classify()
	if park_at.x >= 0.0:
		_make_park(park_at, landmarks)
	_make_blocks()


# --- Queries -------------------------------------------------------------------

func pos(n: Vector2i) -> Vector2:
	return _pos.get(n, Vector2.ZERO)


func has_node(n: Vector2i) -> bool:
	return _pos.has(n)


func is_water(n: Vector2i) -> bool:
	return _water.has(n)


func is_bank(n: Vector2i) -> bool:
	return _bank.has(n)


## Class of the street from `n` towards neighbour `n + d` (any of the four
## directions).
func edge_class(n: Vector2i, d: Vector2i) -> String:
	if d.x < 0 or d.y < 0:
		return _class.get(_key(n + d, -d), "closed")
	return _class.get(_key(n, d), "closed")


func edge_width(n: Vector2i, d: Vector2i) -> float:
	return CLASSES[edge_class(n, d)].width


func drivable(n: Vector2i, d: Vector2i) -> bool:
	return CLASSES[edge_class(n, d)].drive


## The four corners of block b, clockwise on screen: NW, NE, SE, SW.
func corners(b: Vector2i) -> PackedVector2Array:
	return PackedVector2Array([pos(b), pos(b + Vector2i(1, 0)), pos(b + Vector2i(1, 1)), pos(b + Vector2i(0, 1))])


## The block inside its roads (the sidewalk's outer edge).
func inner(b: Vector2i) -> PackedVector2Array:
	return _inner.get(b, PackedVector2Array())


## The lot inside the sidewalk, where buildings stand.
func lot(b: Vector2i) -> PackedVector2Array:
	return _lots.get(b, PackedVector2Array())


## Street class on side k of block b (0 north, 1 east, 2 south, 3 west).
func side_class(b: Vector2i, k: int) -> String:
	match k:
		0:
			return edge_class(b, Vector2i(1, 0))
		1:
			return edge_class(b + Vector2i(1, 0), Vector2i(0, 1))
		2:
			return edge_class(b + Vector2i(0, 1), Vector2i(1, 0))
		_:
			return edge_class(b, Vector2i(0, 1))


## The side of block b that faces the camera most (its street front),
## among sides with a street.
func front_side(b: Vector2i) -> int:
	var poly := corners(b)
	var c := (poly[0] + poly[1] + poly[2] + poly[3]) * 0.25
	var best := 2
	var best_z := -INF
	for k in 4:
		if side_class(b, k) == "closed":
			continue
		var mid := (poly[k] + poly[(k + 1) % 4]) * 0.5
		var out := (mid - c).normalized()
		if out.y > best_z:
			best_z = out.y
			best = k
	return best


## Block containing a local point (searches round the crescent estimate).
func block_of(p: Vector3) -> Vector2i:
	var guess := _guess(Vector2(p.x, p.z))
	var q := Vector2(p.x, p.z)
	for r in 3:
		for di in range(-r, r + 1):
			for dj in range(-r, r + 1):
				if maxi(absi(di), absi(dj)) != r:
					continue
				var b := guess + Vector2i(di, dj)
				if _pos.has(b) and _pos.has(b + Vector2i(1, 1)) and Geometry2D.is_point_in_polygon(q, corners(b)):
					return b
	return guess


# --- Construction --------------------------------------------------------------

func _spacing() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "spacing"])
	col_w.resize(blocks.x + 2 * margin)
	row_h.resize(blocks.y + 2 * margin)
	for k in col_w.size():
		col_w[k] = BASE * rng.randf_range(0.82, 1.2)
	for k in row_h.size():
		var j := k - margin
		# Gilt District rows (north) run long; the Quarter and Wards are
		# tighter.
		row_h[k] = (64.0 if j < boulevard_row else 44.0) * rng.randf_range(0.9, 1.1)
	# Keep the overall extent close to the old square window.
	_normalise(col_w, BASE * (blocks.x + 2 * margin))
	_normalise(row_h, BASE * (blocks.y + 2 * margin))


static func _normalise(arr: PackedFloat32Array, total: float) -> void:
	var s := 0.0
	for v in arr:
		s += v
	for k in arr.size():
		arr[k] *= total / s


func _place_nodes() -> void:
	_cum_u.resize(col_w.size() + 1)
	_cum_z.resize(row_h.size() + 1)
	_cum_u[0] = -margin * BASE
	_cum_z[0] = -margin * BASE
	for k in col_w.size():
		_cum_u[k + 1] = _cum_u[k] + col_w[k]
	for k in row_h.size():
		_cum_z[k + 1] = _cum_z[k] + row_h[k]
	var width := blocks.x * BASE
	var height := blocks.y * BASE
	center = Vector2(width * 0.5, height + CRESCENT_RADIUS)
	ref_radius = CRESCENT_RADIUS + height * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "jitter"])
	_pos.clear()
	for i in range(-margin, blocks.x + margin + 1):
		for j in range(-margin, blocks.y + margin + 1):
			var u: float = _cum_u[i + margin]
			var z: float = _cum_z[j + margin]
			var p := _crescent(u, z)
			var special := i == boulevard_col or j == boulevard_row or i == avenue_col
			p += Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * (JITTER * (0.3 if special else 1.0))
			_pos[Vector2i(i, j)] = p


## (u along the arcs, z towards the river) to local position.
func _crescent(u: float, z: float) -> Vector2:
	var r := center.y - z
	var phi := (u - center.x) / ref_radius
	return Vector2(center.x + sin(phi) * r, center.y - cos(phi) * r)


## Rough block index for a point, by undoing the crescent.
func _guess(q: Vector2) -> Vector2i:
	var rel := q - center
	var r := rel.length()
	var phi := atan2(rel.x, -rel.y)
	var u := center.x + phi * ref_radius
	var z := center.y - r
	return Vector2i(_find(_cum_u, u) - margin, _find(_cum_z, z) - margin)


static func _find(cum: PackedFloat32Array, v: float) -> int:
	for k in cum.size() - 1:
		if v < cum[k + 1]:
			return k
	return cum.size() - 2


func _mark_water() -> void:
	_water.clear()
	for n in _pos:
		if _river_distance.call(_pos[n]) < _river_half:
			_water[n] = true


## Land junctions beside the river move onto a curve a fixed distance from
## the water, so the river road bends with the bank.
func _snap_bank() -> void:
	_bank.clear()
	var target := _river_half + 9.0
	var moved := {}
	for n in _pos:
		if _water.has(n):
			continue
		var wet := false
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if _water.has(n + d):
				wet = true
		if not wet:
			continue
		var p: Vector2 = _pos[n]
		var d0: float = _river_distance.call(p)
		# Gradient of the distance, numerically.
		var g := Vector2(_river_distance.call(p + Vector2(1, 0)) - d0, _river_distance.call(p + Vector2(0, 1)) - d0)
		if g.length() < 0.001:
			continue
		var shift := clampf(target - d0, -22.0, 22.0)
		moved[n] = p + g.normalized() * shift
	for n in moved:
		var old: Vector2 = _pos[n]
		_pos[n] = moved[n]
		if not _quads_ok(n):
			_pos[n] = old
		else:
			_bank[n] = true


## The four blocks round junction n are still convex and the right way round.
func _quads_ok(n: Vector2i) -> bool:
	for b in [n, n - Vector2i(1, 0), n - Vector2i(0, 1), n - Vector2i(1, 1)]:
		if not (_pos.has(b) and _pos.has(b + Vector2i(1, 1))):
			continue
		var c := corners(b)
		for k in 4:
			var a := c[k]
			var e := c[(k + 1) % 4]
			var f := c[(k + 2) % 4]
			if (e - a).cross(f - e) <= 0.0:
				return false
	return true


func _key(n: Vector2i, d: Vector2i) -> Vector3i:
	return Vector3i(n.x, n.y, 0 if d.x != 0 else 1)


func _classify() -> void:
	_class.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "streets"])
	var candidates: Array = []
	for n in _pos:
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			var m: Vector2i = n + d
			if not _pos.has(m) or _water.has(n) or _water.has(m):
				continue
			var mid: Vector2 = (_pos[n] + _pos[m]) * 0.5
			var style: String = _district_style.call(mid)
			var cls := "quarter" if style == "quarter" else "street"
			if _bank.has(n) and _bank.has(m):
				cls = "river"
			if d.y != 0 and n.x == avenue_col:
				cls = "avenue"
			if d.y != 0 and n.x == boulevard_col and n.y >= 0 and n.y < blocks.y:
				cls = "boulevard"
			if d.x != 0 and n.y == boulevard_row and n.x >= 0 and n.x < avenue_col:
				cls = "boulevard"
			_class[_key(n, d)] = cls
			var inside: bool = n.x > 0 and n.y > 0 and m.x < blocks.x and m.y < blocks.y
			if inside and cls in ["street", "quarter"]:
				candidates.append([n, d, style])
	# Interruptions:
	# - In the Wards, spokes are closed in a staggered pattern, giving long
	#   blocks along the river and T-junctions (as in New Orleans'
	#   neighbourhoods).
	# - Dock blocks merge into big yards.
	# - Some Quarter and Gilt streets become pedestrian lanes.
	var reach := _reach_count()
	for c in candidates:
		var n: Vector2i = c[0]
		var d: Vector2i = c[1]
		var style: String = c[2]
		var roll := rng.randf()
		var want := ""
		match style:
			"wards":
				if d.y != 0 and n.x % 2 == 1 and posmod(n.y, 2) == posmod(n.x / 2, 2) and roll < 0.8:
					want = "closed"
				elif roll < 0.04:
					want = "closed"
			"docks":
				if roll < 0.22:
					want = "closed"
			"quarter":
				if roll < 0.16:
					want = "lane"
			"downtown":
				if roll < 0.07:
					want = "lane"
		if want == "":
			continue
		var before: String = _class[_key(n, d)]
		_class[_key(n, d)] = want
		if _degree(n) < 3 or _degree(n + d) < 3 or _reach_count() < reach:
			_class[_key(n, d)] = before


## True for the four blocks of the Liberty Green park.
func is_park(b: Vector2i) -> bool:
	var d := park_node - b
	return d.x >= 0 and d.x <= 1 and d.y >= 0 and d.y <= 1


## Closes the four streets round the junction nearest `at`, so its four
## blocks become one park (a superblock).
func _make_park(at: Vector2, landmarks: Array) -> void:
	var best := Vector2i(-99, -99)
	var best_d := INF
	for n in _pos:
		if n.x < 2 or n.y < 2 or n.x > blocks.x - 2 or n.y > blocks.y - 2 or _water.has(n):
			continue
		var d: float = _pos[n].distance_to(at)
		if d < best_d:
			best_d = d
			best = n
	if best.x < 0:
		return
	for p in landmarks:
		var b := block_of(Vector3(p.x, 0, p.y))
		if (best - b).x >= 0 and (best - b).x <= 1 and (best - b).y >= 0 and (best - b).y <= 1:
			return # a landmark lives here
	var reach := _reach_count()
	var saved := {}
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var key := _key(best, d) if d.x >= 0 and d.y >= 0 else _key(best + d, -d)
		saved[key] = _class.get(key, "closed")
		_class[key] = "closed"
	var ok := _reach_count() >= reach - 1
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if _degree(best + d) < 2:
			ok = false
	if not ok:
		for key in saved:
			_class[key] = saved[key]
		return
	park_node = best


## Drivable streets at junction n.
func _degree(n: Vector2i) -> int:
	var k := 0
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if drivable(n, d):
			k += 1
	return k


## How many window junctions can be driven to from the top middle.
func _reach_count() -> int:
	var start := Vector2i(blocks.x / 2, 1)
	var seen := {start: true}
	var todo: Array = [start]
	while not todo.is_empty():
		var n: Vector2i = todo.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var m: Vector2i = n + d
			if seen.has(m) or not drivable(n, d) or m.x < 0 or m.y < 0 or m.x > blocks.x or m.y > blocks.y:
				continue
			seen[m] = true
			todo.append(m)
	return seen.size()


func _make_blocks() -> void:
	_lots.clear()
	_inner.clear()
	for i in range(-margin, blocks.x + margin):
		for j in range(-margin, blocks.y + margin):
			var b := Vector2i(i, j)
			var c := corners(b)
			var road := PackedFloat32Array()
			var walk := PackedFloat32Array()
			for k in 4:
				var cls := side_class(b, k)
				var w: float = CLASSES[cls].width
				road.append(w * 0.5)
				# Closed streets leave a paved footpath between the two lots.
				walk.append(w * 0.5 + SIDEWALK)
			_inner[b] = inset(c, road)
			_lots[b] = inset(c, walk)


## Pulls each side of a convex polygon (clockwise on screen) in by its own
## distance and returns the new corners.
static func inset(poly: PackedVector2Array, dist: PackedFloat32Array) -> PackedVector2Array:
	var n := poly.size()
	var lines: Array = []
	for k in n:
		var a := poly[k]
		var b := poly[(k + 1) % n]
		var dir := (b - a).normalized()
		var inward := Vector2(-dir.y, dir.x) # right of the direction, for clockwise-on-screen polygons
		lines.append([a + inward * dist[k], dir])
	var out := PackedVector2Array()
	for k in n:
		var l0: Array = lines[(k - 1 + n) % n]
		var l1: Array = lines[k]
		var hit = Geometry2D.line_intersects_line(l0[0], l0[1], l1[0], l1[1])
		out.append(hit if hit != null else l1[0])
	return out
