extends RefCounted
## Bellerive's street plan, v2 (see reference/MAP_BUILDING.md, section 6).
##
## The streets are a general planar graph, not a grid:
## - Each district (faubourg) has its own street grid, with its own angle
##   and spacing. Near the river the grid curves to follow the bank.
## - The grids meet along seam roads (Crescent Boulevard, Lantern Boulevard,
##   Rampart Avenue, Liberty Avenue in Gilt, Wharf Street, Point Avenue).
##   Streets jog and end in T-junctions where districts meet, as they do
##   in New Orleans.
## - Long roads cut across the city:
##   - Liberty Avenue, the diagonal;
##   - the River Road, which bends with the bank;
##   - Morrow Bridge, to Morrow Point on the far bank.
## - Ironwharf keeps its wharves on the water.
## - Some minor streets are dropped (longer blocks, more T-junctions) or
##   made pedestrian lanes. Neither ever cuts the network apart.
##
## Blocks are the faces of the graph:
## - inner: the face minus its streets' half widths;
## - lot: the inner polygon minus the sidewalk.
## Positions are local metres: the window corner is the origin, and z is
## map y. Polygons are clockwise on screen (positive shoelace area with y
## pointing down).

const SIDEWALK := 3.0
## Junctions closer than this become one.
const MERGE := 8.0
## Curved roads are sampled this often before simplifying.
const STEP := 26.0
## The River Road and Levee Road run this far out from the water's edge.
const RIVER_ROAD := 9.0
## Lot rectangle (along the front, deep) each landmark needs; blocks too
## small for theirs are joined with a neighbour.
const LANDMARK_LOTS := {
	"union_station": Vector2(40, 34), "aurum_tower": Vector2(30, 30), "bpd_lantern": Vector2(30, 24),
	"floodline_clinic": Vector2(28, 24), "lantern_square": Vector2(34, 30), "wharfside_courts": Vector2(34, 30),
	"blue_lantern": Vector2(28, 22), "warehouse_9": Vector2(32, 26), "the_pit": Vector2(28, 30),
	"streetcar_depot": Vector2(32, 26), "drowned_streetcar": Vector2(24, 20),
}
const DEFAULT_LOT := Vector2(22, 22)

const CLASSES := {
	"boulevard": {"width": 24.0, "drive": true, "rank": 5},
	"bridge": {"width": 16.0, "drive": true, "rank": 5},
	"avenue": {"width": 15.0, "drive": true, "rank": 4},
	"river": {"width": 14.0, "drive": true, "rank": 4},
	"street": {"width": 11.0, "drive": true, "rank": 2},
	"quarter": {"width": 9.0, "drive": true, "rank": 1},
	"lane": {"width": 7.0, "drive": false, "rank": 0},
	"quay": {"width": 3.0, "drive": false, "rank": 0},
}
const ROAD_NAMES := {
	"lantern": "Lantern Boulevard", "crescent": "Crescent Boulevard", "rampart": "Rampart Avenue",
	"liberty": "Liberty Avenue", "magnolia": "Magnolia Avenue", "wharf": "Wharf Street", "river_road": "River Road",
	"levee": "Levee Road", "bridge": "Morrow Bridge", "point_ave": "Point Avenue",
}

## District grids. `seed` is a point inside the patch's region (regions are
## the land cut apart by the seam roads). Lines of constant u run along V
## and sit `su` apart; lines of constant v run along U and sit `sv` apart.
## `bend` curves the v-lines (v grows by bend * u^2), so the streets follow
## the crescent. `cut` is the chance of dropping a u- or v-street between
## two junctions, `lane` the chance of making it a pedestrian lane. `max`
## caps the blocks that dropping streets makes: length along U, along V,
## and area.
const PATCHES := [
	{"id": "gilt_w", "bank": "north", "seed": Vector2(150, 200), "origin": Vector2(246, 170), "angle": -9.0, "bend": 0.0003, "fan": 0.00035, "bend_u": 0.0002,
		"su": [64.0, 80.0], "sv": [54.0, 66.0], "fam": "uv", "cls": "street", "cut": [0.1, 0.1], "lane": 0.04, "max": [160.0, 140.0, 9000.0]},
	{"id": "gilt_e", "bank": "north", "seed": Vector2(500, 150), "origin": Vector2(397, 200), "angle": 6.0, "bend": -0.0004, "fan": -0.0007, "bend_u": 0.00025,
		"su": [66.0, 78.0], "sv": [54.0, 64.0], "fam": "uv", "cls": "street", "cut": [0.1, 0.1], "lane": 0.04, "max": [160.0, 140.0, 9000.0]},
	{"id": "gilt_s", "bank": "north", "seed": Vector2(400, 470), "origin": Vector2(500, 400), "angle": 29.0, "bend": 0.0,
		"su": [62.0, 76.0], "sv": [60.0, 60.0], "fam": "u", "cls": "street", "cut": [0.0, 0.0], "lane": 0.0, "max": [0.0, 0.0, 0.0]},
	{"id": "quarter_w", "bank": "north", "seed": Vector2(150, 800), "origin": Vector2(200, 760), "angle": -12.0, "bend": 0.0005, "fan": 0.0005,
		"su": [44.0, 52.0], "sv": [40.0, 48.0], "fam": "uv", "cls": "quarter", "cut": [0.1, 0.08], "lane": 0.1, "max": [105.0, 100.0, 4500.0]},
	{"id": "quarter_e", "bank": "north", "seed": Vector2(520, 750), "origin": Vector2(480, 830), "angle": -6.0, "bend": 0.0006, "fan": -0.0008, "bend_u": 0.0003,
		"su": [46.0, 54.0], "sv": [42.0, 50.0], "fam": "uv", "cls": "quarter", "cut": [0.1, 0.08], "lane": 0.1, "max": [105.0, 100.0, 4500.0]},
	{"id": "wards", "bank": "north", "seed": Vector2(1000, 400), "origin": Vector2(940, 225), "angle": -25.0, "bend": 0.0003, "fan": -0.00025,
		"su": [84.0, 104.0], "sv": [38.0, 46.0], "fam": "uv", "cls": "street", "cut": [0.3, 0.04], "lane": 0.0, "max": [215.0, 60.0, 9000.0]},
	{"id": "docks", "bank": "north", "seed": Vector2(1000, 960), "origin": Vector2(1050, 960), "angle": 9.0, "bend": 0.0,
		"su": [100.0, 125.0], "sv": [80.0, 95.0], "fam": "uv", "cls": "street", "cut": [0.25, 0.25], "lane": 0.0, "max": [260.0, 200.0, 40000.0]},
	{"id": "point_w", "bank": "south", "seed": Vector2(150, 1420), "origin": Vector2(200, 1420), "angle": -10.0, "bend": 0.0004, "fan": 0.0004,
		"su": [56.0, 70.0], "sv": [44.0, 52.0], "fam": "uv", "cls": "street", "cut": [0.18, 0.1], "lane": 0.0, "max": [140.0, 110.0, 7000.0]},
	{"id": "point_e", "bank": "south", "seed": Vector2(800, 1400), "origin": Vector2(700, 1330), "angle": -4.0, "bend": 0.00035, "fan": -0.0003, "bend_u": 0.00015,
		"su": [58.0, 72.0], "sv": [44.0, 52.0], "fam": "uv", "cls": "street", "cut": [0.18, 0.1], "lane": 0.0, "max": [140.0, 110.0, 7000.0]},
]

var window := Rect2()
## The window plus the margin ring of scenery.
var bounds := Rect2()
var seed_value := 0

var node_pos := PackedVector2Array()
var edge_a := PackedInt32Array()
var edge_b := PackedInt32Array()
var edge_cls: Array[String] = []
## Named road the edge belongs to ("" for district streets).
var edge_road: Array[String] = []
var edge_patch := PackedInt32Array()
## Faces either side: [0] seen going a -> b one way round, [1] the other;
## -1 is outside every block (the river, the edge of the map).
var edge_face: Array[Vector2i] = []
## Blocks: {nodes, edges, poly, kind ("land", "water", "sliver"), center,
## area, bbox, inner, sides (edge per inner side, -1 for none), lot, front}.
var faces: Array[Dictionary] = []
## Liberty Green, the park block (-1 if it couldn't be made).
var park_face := -1

## District regions: [polygon, patch index].
var _regions: Array = []
var _river := PackedVector2Array()
var _park_at := Vector2.ZERO
## Liberty Green's outline, roads included (empty when there's no park).
var _park_poly := PackedVector2Array()
var _river_half := 80.0
var _adj: Array = [] # node -> Array of edge ids, sorted by direction
var _dead := PackedByteArray()
var _node_grid := {}
var _face_grid := {}
const GRID := 50.0


## Builds the plan inside `win` plus `margin`. `river_line` is the river
## centreline in local metres, `landmarks` [id, local point] pairs whose
## blocks need room for the landmark, `park_at` where Liberty Green goes.
func build(win: Rect2, margin: float, seed_v: int, river_line: PackedVector2Array, river_half: float, landmarks: Array, park_at: Vector2) -> void:
	window = win
	bounds = win.grow(margin)
	seed_value = seed_v
	_park_at = park_at
	_river = river_line
	_river_half = river_half
	var src: Array = []
	var t := Time.get_ticks_usec()
	_layout(src)
	t = _lap("layout", t)
	_arrange(src)
	t = _lap("arrange", t)
	_merge_close()
	_prune()
	_simplify()
	_compact()
	_find_faces()
	t = _lap("graph", t)
	_thin()
	_simplify()
	_compact()
	_find_faces()
	t = _lap("thin", t)
	var wants: Array = []
	for lm in landmarks:
		wants.append([lm[1], LANDMARK_LOTS.get(lm[0], DEFAULT_LOT)])
	for pass_ in 6:
		if not _grow_blocks(wants):
			break
		_simplify()
		_compact()
		_find_faces()
	t = _lap("grow", t)
	_make_blocks()
	_index()
	# Landmark blocks keep the rectangle that best holds the landmark, on
	# the street side it fronts.
	for w in wants:
		var f := face_of(w[0])
		if f >= 0 and faces[f].kind == "land" and faces[f].lot.size() >= 3:
			var pick := _landmark_rect(f, w[1])
			faces[f].front = pick[0]
			faces[f].rect = pick[1]
	t = _lap("blocks", t)
	if not _park_poly.is_empty():
		park_face = face_of(interior_point(_park_poly))


## Build time per step, in ms (for the tests and tuning).
var timings := {}


func _lap(step: String, since: int) -> int:
	var now := Time.get_ticks_usec()
	timings[step] = (now - since) / 1000.0
	return now


# --- Queries -------------------------------------------------------------------

func pos(n: int) -> Vector2:
	return node_pos[n]


func node_count() -> int:
	return node_pos.size()


func edge_count() -> int:
	return edge_a.size()


## Edges at node n, sorted by direction.
func edges_of(n: int) -> Array:
	return _adj[n]


## The node at the other end of edge e from n.
func other(e: int, n: int) -> int:
	return edge_b[e] if edge_a[e] == n else edge_a[e]


func edge_between(a: int, b: int) -> int:
	for e in _adj[a]:
		if other(e, a) == b:
			return e
	return -1


func edge_class(e: int) -> String:
	return edge_cls[e]


func edge_width(e: int) -> float:
	return CLASSES[edge_cls[e]].width


func drivable(e: int) -> bool:
	return CLASSES[edge_cls[e]].drive


## Drivable streets at node n.
func degree(n: int) -> int:
	var k := 0
	for e in _adj[n]:
		if drivable(e):
			k += 1
	return k


## How far along edge e from node n its own markings must stop to clear
## the other streets crossing there (0 where the street just bends).
func clearance(n: int, e: int) -> float:
	var w := edge_width(e) * 0.5
	var d := (pos(other(e, n)) - pos(n)).normalized()
	var best := 0.0
	for e2 in _adj[n]:
		if e2 == e:
			continue
		var d2 := (pos(other(e2, n)) - pos(n)).normalized()
		var c := d.dot(d2)
		if c < -0.94: # straight on
			continue
		var s := maxf(sqrt(maxf(1.0 - c * c, 0.0)), 0.3)
		best = maxf(best, minf(edge_width(e2) * 0.5 / s + w * absf(c) / s, 30.0))
	return best


## Block containing local point p, or -1 (river, edge of the map).
func face_of(p: Vector2) -> int:
	var key := Vector2i(floori(p.x / GRID), floori(p.y / GRID))
	for f in _face_grid.get(key, []):
		var face: Dictionary = faces[f]
		if face.bbox.has_point(p) and Geometry2D.is_point_in_polygon(p, face.poly):
			return f
	return -1


## Faces whose bounding boxes touch the grid cells within r of p.
func faces_near(p: Vector2, r: float) -> Array:
	var seen := {}
	for gx in range(floori((p.x - r) / GRID), floori((p.x + r) / GRID) + 1):
		for gy in range(floori((p.y - r) / GRID), floori((p.y + r) / GRID) + 1):
			for f in _face_grid.get(Vector2i(gx, gy), []):
				seen[f] = true
	return seen.keys()


## Nodes within r of p (from the grid; caller checks the distance).
func nodes_near(p: Vector2, r: float) -> Array:
	var out: Array = []
	for gx in range(floori((p.x - r) / GRID), floori((p.x + r) / GRID) + 1):
		for gy in range(floori((p.y - r) / GRID), floori((p.y + r) / GRID) + 1):
			out.append_array(_node_grid.get(Vector2i(gx, gy), []))
	return out


func is_land(f: int) -> bool:
	return f >= 0 and faces[f].kind == "land"


func face_poly(f: int) -> PackedVector2Array:
	return faces[f].poly


## The block inside its streets (the sidewalk's outer edge).
func inner(f: int) -> PackedVector2Array:
	return faces[f].inner


## The lot inside the sidewalk, where buildings stand.
func lot(f: int) -> PackedVector2Array:
	return faces[f].lot


## Class of the street along inner side k of block f ("" for none).
func side_class(f: int, k: int) -> String:
	var e: int = faces[f].sides[k]
	return edge_cls[e] if e >= 0 else ""


func front_side(f: int) -> int:
	return faces[f].front


func is_park(f: int) -> bool:
	return f >= 0 and f == park_face


func is_water_point(p: Vector2) -> bool:
	return river_distance(p) < _river_half


func river_distance(p: Vector2) -> float:
	var best := INF
	for k in _river.size() - 1:
		best = minf(best, Geometry2D.get_closest_point_to_segment(p, _river[k], _river[k + 1]).distance_to(p))
	return best


# --- Layout ----------------------------------------------------------------------

## The major roads and the district grids, as polylines:
## {pts, cls, road, patch, fam}.
func _layout(src: Array) -> void:
	var box := _rect_poly(bounds)
	var band80 := _band(_river_half)
	var band89 := _band(_river_half + RIVER_ROAD)
	var road_line := _extend(_chain(band89, box, true), 3.0)
	var levee := _extend(_chain(band89, box, false), 3.0)
	var bank := _extend(_chain(band80, box, true), 3.0)
	var lantern := _spline([Vector2(300, -140), Vector2(318, 150), Vector2(326, 300), Vector2(333, 505), Vector2(345, 1000), Vector2(350, 1110)])
	var rampart := _spline([Vector2(640, -140), Vector2(668, 250), Vector2(690, 500), Vector2(712, 800), Vector2(728, 1000), Vector2(735, 1080)])
	var crescent := _spline([Vector2(-140, 595), Vector2(120, 540), Vector2(333, 505), Vector2(520, 495), Vector2(690, 500), Vector2(700, 501)])
	var liberty := _spline([Vector2(318, 296), Vector2(690, 500), Vector2(1290, 877)])
	var magnolia := _spline([Vector2(-140, 90), Vector2(30, 230), Vector2(140, 400), Vector2(185, 560)])
	var p4 := _cross(rampart, road_line)
	var b0 := _cross(lantern, road_line)
	# River Road: along the bank up to Rampart. Past it the wharves have the
	# water.
	var river_road := PackedVector2Array()
	for p in road_line:
		if p.x < p4.x - 6.0:
			river_road.append(p)
	river_road.append(p4)
	var quay := PackedVector2Array([p4])
	for p in bank:
		if p.x > p4.x + 40.0:
			quay.append(p)
	var wharf := _spline([p4 + Vector2(-12, 18), p4, p4 + Vector2(45, -75), Vector2(860, 885), Vector2(1000, 862), Vector2(1150, 855), Vector2(1300, 862), Vector2(1440, 882)])
	# Morrow Bridge: straight over the river from the foot of Lantern
	# Boulevard, square to the bank; Point Avenue carries on beyond.
	var t := _tangent(road_line, b0)
	var across := Vector2(-t.y, t.x)
	if across.y < 0.0:
		across = -across
	var b1 := _cross(PackedVector2Array([b0, b0 + across * 600.0]), levee)
	var point_ave := PackedVector2Array([b1, b1 + across * 450.0])
	# Liberty Green: a park on Liberty Avenue, the size of a few blocks,
	# with a street round its other three sides. District streets stop at
	# its edge.
	var park_ring := _park_shape(liberty, _park_at, 120.0, 80.0)
	if not park_ring.is_empty():
		src.append({"pts": _resample(_extend(park_ring, 2.0), STEP), "cls": "street", "road": "park", "patch": -1, "fam": -1})
	for r in [[lantern, "boulevard", "lantern"], [crescent, "boulevard", "crescent"], [rampart, "avenue", "rampart"],
			[liberty, "avenue", "liberty"], [magnolia, "avenue", "magnolia"], [wharf, "avenue", "wharf"], [river_road, "river", "river_road"],
			[levee, "river", "levee"], [quay, "quay", "quay"], [PackedVector2Array([b0, b1]), "bridge", "bridge"],
			[point_ave, "avenue", "point_ave"]]:
		src.append({"pts": _resample(r[0], STEP), "cls": r[1], "road": r[2], "patch": -1, "fam": -1})
	# Districts: the land cut apart along the seams.
	var north := _piece(Geometry2D.clip_polygons(box, band80), Vector2(300, 300))
	var south := _piece(Geometry2D.clip_polygons(box, band89), Vector2(300, bounds.end.y - 20.0))
	var road_cut := river_road.duplicate()
	road_cut.insert(0, river_road[0] + (river_road[0] - river_road[1]).normalized() * 60.0)
	road_cut.append(p4 + (p4 - river_road[river_road.size() - 2]).normalized() * 4.0)
	var liberty_gilt := PackedVector2Array()
	for p in liberty:
		if p.x <= 700.0:
			liberty_gilt.append(p)
	var north_parts: Array = [north]
	for seam in [lantern, crescent, rampart, road_cut, liberty_gilt, wharf]:
		north_parts = _cut(north_parts, seam)
	var south_parts := _cut([south], PackedVector2Array([b1 - across * 5.0, b1 + across * 450.0]))
	# A street round the edge of the scenery closes off the outermost blocks.
	var frame := _rect_poly(bounds.grow(-4.0))
	for k in 4:
		var a := frame[k]
		var b := frame[(k + 1) % 4]
		for land in [north, south]:
			for piece in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([a, b]), land):
				if _length(piece) > 20.0:
					src.append({"pts": _resample(_extend(piece, 2.0), STEP), "cls": "street", "road": "frame", "patch": -1, "fam": -1})
	_regions = []
	for k in PATCHES.size():
		var p: Dictionary = PATCHES[k]
		var region := _piece(north_parts if p.bank == "north" else south_parts, p.seed)
		if region.is_empty():
			push_warning("street plan: no region for %s" % p.id)
			continue
		_regions.append([region, k])
		_patch_lines(src, k, region)


func _patch_lines(src: Array, k: int, region: PackedVector2Array) -> void:
	var p: Dictionary = PATCHES[k]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, p.id])
	var th := deg_to_rad(p.angle)
	var u_dir := Vector2(cos(th), sin(th))
	var v_dir := Vector2(-sin(th), cos(th))
	var o: Vector2 = p.origin
	var bend: float = p.bend
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for q in region:
		var d := q - o
		var u := d.dot(u_dir)
		var v := d.dot(v_dir) - bend * u * u
		lo = Vector2(minf(lo.x, u), minf(lo.y, v))
		hi = Vector2(maxf(hi.x, u), maxf(hi.y, v))
	lo -= Vector2(30, 30)
	hi += Vector2(30, 30)
	# The u-lines fan out from the middle of the patch (like spokes round
	# the crescent) and curve; the outer ones are spared so the fan still
	# covers the region.
	var fan: float = p.get("fan", 0.0)
	var bend_u: float = p.get("bend_u", 0.0)
	var mid := (lo + hi) * 0.5
	var spare := absf(fan) * (hi.x - lo.x) * (hi.y - lo.y) * 0.25 + absf(bend_u) * pow((hi.y - lo.y) * 0.5, 2)
	var lines: Array = [] # [polyline, family]
	if "u" in p.fam:
		for u in _positions(rng, lo.x - spare, hi.x + spare, p.su):
			var tilt: float = rng.randf_range(-0.012, 0.012) + fan * (u - mid.x)
			var pts := PackedVector2Array()
			var v := lo.y
			while true:
				var uu: float = u + tilt * (v - mid.y) + bend_u * pow(v - mid.y, 2)
				pts.append(o + u_dir * uu + v_dir * (v + bend * uu * uu))
				if v >= hi.y:
					break
				v = minf(v + STEP, hi.y)
			lines.append([pts, 0])
	if "v" in p.fam:
		for v in _positions(rng, lo.y, hi.y, p.sv):
			var tilt := rng.randf_range(-0.012, 0.012)
			var pts := PackedVector2Array()
			var u := lo.x - spare
			while true:
				var vv: float = v + tilt * u
				pts.append(o + u_dir * u + v_dir * (vv + bend * u * u))
				if u >= hi.x + spare:
					break
				u = minf(u + STEP, hi.x + spare)
			lines.append([pts, 1])
	var gap: float = minf(p.su[0], p.sv[0]) * 0.55
	for l in lines:
		var pieces := Geometry2D.intersect_polyline_with_polygon(l[0], region)
		if not _park_poly.is_empty():
			var outside: Array[PackedVector2Array] = []
			for piece in pieces:
				outside.append_array(Geometry2D.clip_polyline_with_polygon(piece, _park_poly))
			pieces = outside
		for piece in pieces:
			if piece.size() < 2 or _length(piece) < 12.0:
				continue
			# A street running alongside the district's edge, too close to
			# it, would leave a sliver of a block: leave it out.
			if _hugs(piece, region, gap) or (not _park_poly.is_empty() and _hugs(piece, _park_poly, gap)):
				continue
			# Reach over the seam so the crossing is found.
			var n := piece.size()
			piece[0] += (piece[0] - piece[1]).normalized() * 1.5
			piece[n - 1] += (piece[n - 1] - piece[n - 2]).normalized() * 1.5
			src.append({"pts": piece, "cls": p.cls, "road": "", "patch": k, "fam": l[1]})


## True when the middle and both quarter points of a line lie within
## `gap` of the polygon's edge.
static func _hugs(line: PackedVector2Array, poly: PackedVector2Array, gap: float) -> bool:
	var total := _length(line)
	for f in [0.25, 0.5, 0.75]:
		var q := _point_at(line, total * f)
		var near := false
		for k in poly.size():
			if Geometry2D.get_closest_point_to_segment(q, poly[k], poly[(k + 1) % poly.size()]).distance_to(q) < gap:
				near = true
				break
		if not near:
			return false
	return true


static func _point_at(line: PackedVector2Array, at: float) -> Vector2:
	var t := 0.0
	for k in line.size() - 1:
		var l := line[k].distance_to(line[k + 1])
		if t + l >= at:
			return line[k].lerp(line[k + 1], (at - t) / maxf(l, 0.001))
		t += l
	return line[line.size() - 1]


static func _positions(rng: RandomNumberGenerator, lo: float, hi: float, spacing: Array) -> Array:
	var out: Array = [0.0]
	var t := 0.0
	while t < hi:
		t += rng.randf_range(spacing[0], spacing[1])
		out.append(t)
	t = 0.0
	while t > lo:
		t -= rng.randf_range(spacing[0], spacing[1])
		out.append(t)
	return out


## The river widened to `half` either side of its centreline.
func _band(half: float) -> PackedVector2Array:
	var polys := Geometry2D.offset_polyline(_river, half, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)
	return _largest(polys)


## The north or south edge of a river band inside `box`, west to east.
func _chain(band: PackedVector2Array, box: PackedVector2Array, north: bool) -> PackedVector2Array:
	var n := band.size()
	var inside := PackedByteArray()
	inside.resize(n)
	var r := bounds.grow(-1.0)
	for k in n:
		inside[k] = 1 if r.has_point(band[k]) else 0
	var start := 0
	for k in n:
		if inside[k] == 0:
			start = k
			break
	var chains: Array = []
	var cur := PackedVector2Array()
	for i in n + 1:
		var k := (start + i) % n
		if inside[k] == 1:
			cur.append(band[k])
		elif cur.size() > 0:
			chains.append(cur)
			cur = PackedVector2Array()
	if cur.size() > 0:
		chains.append(cur)
	var best := PackedVector2Array()
	var best_y := INF if north else -INF
	for c in chains:
		if _length(c) < 300.0:
			continue
		var y := 0.0
		for p in c:
			y += p.y
		y /= c.size()
		if (north and y < best_y) or (not north and y > best_y):
			best_y = y
			best = c
	if best.size() > 1 and best[0].x > best[best.size() - 1].x:
		best.reverse()
	return best


## Catmull-Rom curve through the points, sampled every few metres.
static func _spline(ctrl: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := ctrl.size()
	for i in n - 1:
		var p0: Vector2 = ctrl[maxi(i - 1, 0)]
		var p1: Vector2 = ctrl[i]
		var p2: Vector2 = ctrl[i + 1]
		var p3: Vector2 = ctrl[mini(i + 2, n - 1)]
		var steps := maxi(2, int(p1.distance_to(p2) / 5.0))
		for s in steps:
			var t := float(s) / steps
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(ctrl[n - 1])
	return out


## Even spacing of about `step` along a polyline (ends kept).
static func _resample(line: PackedVector2Array, step: float) -> PackedVector2Array:
	var total := _length(line)
	var count := maxi(1, roundi(total / step))
	var out := PackedVector2Array([line[0]])
	var seg := 0
	var seg_start := 0.0
	for i in range(1, count):
		var want := total * i / count
		while seg < line.size() - 2 and seg_start + line[seg].distance_to(line[seg + 1]) < want:
			seg_start += line[seg].distance_to(line[seg + 1])
			seg += 1
		var l := line[seg].distance_to(line[seg + 1])
		out.append(line[seg].lerp(line[seg + 1], clampf((want - seg_start) / maxf(l, 0.001), 0.0, 1.0)))
	out.append(line[line.size() - 1])
	return out


## The line with both ends pushed out by `by` metres.
static func _extend(line: PackedVector2Array, by: float) -> PackedVector2Array:
	var out := line.duplicate()
	var n := out.size()
	if n >= 2:
		out[0] += (out[0] - out[1]).normalized() * by
		out[n - 1] += (out[n - 1] - out[n - 2]).normalized() * by
	return out


static func _length(line: PackedVector2Array) -> float:
	var s := 0.0
	for k in line.size() - 1:
		s += line[k].distance_to(line[k + 1])
	return s


## First crossing of two polylines (or the nearest approach).
static func _cross(a: PackedVector2Array, b: PackedVector2Array) -> Vector2:
	for i in a.size() - 1:
		for j in b.size() - 1:
			var hit = Geometry2D.segment_intersects_segment(a[i], a[i + 1], b[j], b[j + 1])
			if hit != null:
				return hit
	push_warning("street plan: roads don't cross")
	return a[a.size() - 1]


## Direction of a polyline near point p.
static func _tangent(line: PackedVector2Array, p: Vector2) -> Vector2:
	var best := 0
	var best_d := INF
	for k in line.size() - 1:
		var d := Geometry2D.get_closest_point_to_segment(p, line[k], line[k + 1]).distance_to(p)
		if d < best_d:
			best_d = d
			best = k
	return (line[best + 1] - line[best]).normalized()


static func _rect_poly(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


static func _piece(polys: Array, p: Vector2) -> PackedVector2Array:
	for poly in polys:
		if Geometry2D.is_point_in_polygon(p, poly):
			return poly
	return PackedVector2Array()


## Splits every polygon along a line.
static func _cut(polys: Array, line: PackedVector2Array) -> Array:
	var strips := Geometry2D.offset_polyline(line, 0.4, Geometry2D.JOIN_MITER, Geometry2D.END_BUTT)
	var out := polys
	for strip in strips:
		var next: Array = []
		for poly in out:
			next.append_array(Geometry2D.clip_polygons(poly, strip))
		out = next
	return out


# --- Graph -----------------------------------------------------------------------

## Splits every polyline where it crosses another and joins them into one
## graph.
func _arrange(src: Array) -> void:
	var sa := PackedVector2Array()
	var sb := PackedVector2Array()
	var sk := PackedInt32Array()
	for i in src.size():
		var pts: PackedVector2Array = src[i].pts
		for j in pts.size() - 1:
			if pts[j].distance_squared_to(pts[j + 1]) > 0.01:
				sa.append(pts[j])
				sb.append(pts[j + 1])
				sk.append(i)
	var n := sa.size()
	var cuts: Array = []
	cuts.resize(n)
	for s in n:
		cuts[s] = [0.0, 1.0]
	var grid := {}
	for s in n:
		var lo := Vector2(minf(sa[s].x, sb[s].x), minf(sa[s].y, sb[s].y))
		var hi := Vector2(maxf(sa[s].x, sb[s].x), maxf(sa[s].y, sb[s].y))
		for gx in range(floori(lo.x / 64.0), floori(hi.x / 64.0) + 1):
			for gy in range(floori(lo.y / 64.0), floori(hi.y / 64.0) + 1):
				var key := Vector2i(gx, gy)
				if not grid.has(key):
					grid[key] = []
				grid[key].append(s)
	var done := {}
	for key in grid:
		var list: Array = grid[key]
		for x in list.size():
			var s: int = list[x]
			for y in range(x + 1, list.size()):
				var t: int = list[y]
				if sk[s] == sk[t]:
					continue
				var pair := mini(s, t) * n + maxi(s, t)
				if done.has(pair):
					continue
				done[pair] = true
				var hit = Geometry2D.segment_intersects_segment(sa[s], sb[s], sa[t], sb[t])
				if hit != null:
					cuts[s].append(_param(sa[s], sb[s], hit))
					cuts[t].append(_param(sa[t], sb[t], hit))
	node_pos = PackedVector2Array()
	edge_a = PackedInt32Array()
	edge_b = PackedInt32Array()
	edge_cls = []
	edge_road = []
	edge_patch = PackedInt32Array()
	var fam := PackedInt32Array()
	var snap := {}
	var lookup := {}
	for s in n:
		var ts: Array = cuts[s]
		ts.sort()
		var prev := -1
		var info: Dictionary = src[sk[s]]
		for t in ts:
			var id := _node_at(sa[s].lerp(sb[s], t), snap)
			if prev >= 0 and id != prev:
				var key := Vector2i(mini(prev, id), maxi(prev, id))
				if lookup.has(key):
					var e: int = lookup[key]
					if CLASSES[info.cls].rank > CLASSES[edge_cls[e]].rank:
						edge_cls[e] = info.cls
						edge_road[e] = info.road
						edge_patch[e] = info.patch
				else:
					lookup[key] = edge_a.size()
					edge_a.append(prev)
					edge_b.append(id)
					edge_cls.append(info.cls)
					edge_road.append(info.road)
					edge_patch.append(info.patch)
					fam.append(info.fam)
			prev = id
	_fam = fam
	_rebuild_adj()


var _fam := PackedInt32Array()


static func _param(a: Vector2, b: Vector2, p: Vector2) -> float:
	var d := b - a
	return clampf((p - a).dot(d) / d.length_squared(), 0.0, 1.0)


func _node_at(p: Vector2, snap: Dictionary) -> int:
	var key := Vector2i(floori(p.x / 2.0), floori(p.y / 2.0))
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			for id in snap.get(key + Vector2i(dx, dy), []):
				if node_pos[id].distance_squared_to(p) < 0.5:
					return id
	var id := node_pos.size()
	node_pos.append(p)
	if not snap.has(key):
		snap[key] = []
	snap[key].append(id)
	return id


func _rebuild_adj() -> void:
	_adj = []
	_adj.resize(node_pos.size())
	for k in node_pos.size():
		_adj[k] = []
	_dead = PackedByteArray()
	_dead.resize(edge_a.size())
	for e in edge_a.size():
		_adj[edge_a[e]].append(e)
		_adj[edge_b[e]].append(e)


## Junctions closer than MERGE become one, at the busiest one's position.
func _merge_close() -> void:
	var n := node_pos.size()
	var parent := PackedInt32Array()
	parent.resize(n)
	for k in n:
		parent[k] = k
	var grid := {}
	for k in n:
		var key := Vector2i(floori(node_pos[k].x / MERGE), floori(node_pos[k].y / MERGE))
		if not grid.has(key):
			grid[key] = []
		grid[key].append(k)
	for k in n:
		var key := Vector2i(floori(node_pos[k].x / MERGE), floori(node_pos[k].y / MERGE))
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				for m in grid.get(key + Vector2i(dx, dy), []):
					if m > k and node_pos[k].distance_to(node_pos[m]) < MERGE:
						var rk := _find(parent, k)
						var rm := _find(parent, m)
						if rk != rm:
							# The busier junction keeps its place.
							if _adj[rm].size() > _adj[rk].size():
								parent[rk] = rm
							else:
								parent[rm] = rk
	var lookup := {}
	var keep := PackedByteArray()
	keep.resize(edge_a.size())
	for e in edge_a.size():
		var a := _find(parent, edge_a[e])
		var b := _find(parent, edge_b[e])
		edge_a[e] = a
		edge_b[e] = b
		if a == b:
			continue
		var key := Vector2i(mini(a, b), maxi(a, b))
		if lookup.has(key):
			var o: int = lookup[key]
			if CLASSES[edge_cls[e]].rank > CLASSES[edge_cls[o]].rank:
				keep[o] = 0
				keep[e] = 1
				lookup[key] = e
			continue
		lookup[key] = e
		keep[e] = 1
	_rebuild_adj()
	for e in edge_a.size():
		if keep[e] == 0:
			_kill(e)


static func _find(parent: PackedInt32Array, k: int) -> int:
	while parent[k] != k:
		parent[k] = parent[parent[k]]
		k = parent[k]
	return k


func _kill(e: int) -> void:
	if _dead[e] == 1:
		return
	_dead[e] = 1
	_adj[edge_a[e]].erase(e)
	_adj[edge_b[e]].erase(e)


## Drops dead ends until none are left.
func _prune() -> void:
	var todo: Array = []
	for k in node_pos.size():
		if _adj[k].size() == 1:
			todo.append(k)
	while not todo.is_empty():
		var k: int = todo.pop_back()
		if _adj[k].size() != 1:
			continue
		var e: int = _adj[k][0]
		var m := other(e, k)
		_kill(e)
		if _adj[m].size() == 1:
			todo.append(m)


## Joins the two edges at a node where a street just carries on, when the
## node is within half a metre of the joined edge.
func _simplify() -> void:
	var changed := true
	while changed:
		changed = false
		for v in node_pos.size():
			if _adj[v].size() != 2:
				continue
			var e1: int = _adj[v][0]
			var e2: int = _adj[v][1]
			if edge_cls[e1] != edge_cls[e2] or edge_road[e1] != edge_road[e2] or edge_patch[e1] != edge_patch[e2]:
				continue
			var u := other(e1, v)
			var w := other(e2, v)
			if u == w or edge_between(u, w) >= 0:
				continue
			if Geometry2D.get_closest_point_to_segment(node_pos[v], node_pos[u], node_pos[w]).distance_to(node_pos[v]) > 0.5:
				continue
			# e1 now runs u -> w; e2 goes.
			_adj[v].clear()
			_adj[w].erase(e2)
			_dead[e2] = 1
			edge_a[e1] = u
			edge_b[e1] = w
			_adj[w].append(e1)
			changed = true
	_drop_overlaps()


## Drops a district street that runs on top of another street. A patch line
## nearly in line with the frame or a seam, straightened, leaves two ways
## between the same junctions along the same line, which breaks the block
## walk (the blocks either side go missing).
func _drop_overlaps() -> void:
	for e in edge_a.size():
		if _dead[e] == 1 or edge_road[e] != "":
			continue
		var a := node_pos[edge_a[e]]
		var b := node_pos[edge_b[e]]
		var length := a.distance_to(b)
		if length < 1.0:
			continue
		var dir := (b - a) / length
		# Walk from one end to the other along streets that stay on e.
		var cur := edge_a[e]
		var prev := e
		var steps := 0
		while cur != edge_b[e] and steps < 8:
			var nxt := -1
			for f in _adj[cur]:
				if f == e or f == prev:
					continue
				var q := node_pos[other(f, cur)]
				var t := (q - a).dot(dir)
				if t <= (node_pos[cur] - a).dot(dir) + 0.01 or t > length + 0.5:
					continue
				if Geometry2D.get_closest_point_to_segment(q, a, b).distance_to(q) > 1.0:
					continue
				nxt = f
				break
			if nxt < 0:
				break
			prev = nxt
			cur = other(nxt, cur)
			steps += 1
		if cur == edge_b[e] and steps > 0:
			_kill(e)


## Removes dead edges and lone nodes, renumbering both.
func _compact() -> void:
	var remap := PackedInt32Array()
	remap.resize(node_pos.size())
	remap.fill(-1)
	var pos2 := PackedVector2Array()
	for k in node_pos.size():
		if _adj[k].size() > 0:
			remap[k] = pos2.size()
			pos2.append(node_pos[k])
	var a2 := PackedInt32Array()
	var b2 := PackedInt32Array()
	var c2: Array[String] = []
	var r2: Array[String] = []
	var p2 := PackedInt32Array()
	var f2 := PackedInt32Array()
	for e in edge_a.size():
		if _dead[e] == 1:
			continue
		a2.append(remap[edge_a[e]])
		b2.append(remap[edge_b[e]])
		c2.append(edge_cls[e])
		r2.append(edge_road[e])
		p2.append(edge_patch[e])
		f2.append(_fam[e])
	node_pos = pos2
	edge_a = a2
	edge_b = b2
	edge_cls = c2
	edge_road = r2
	edge_patch = p2
	_fam = f2
	_rebuild_adj()
	_sort_adj()


func _sort_adj() -> void:
	for k in node_pos.size():
		var list: Array = _adj[k]
		var p := node_pos[k]
		list.sort_custom(func(x, y):
			var dx := node_pos[other(x, k)] - p
			var dy := node_pos[other(y, k)] - p
			return atan2(dx.y, dx.x) < atan2(dy.y, dy.x))


## The chain of edges through nodes that only bend, starting along edge e
## from node n: [edges, end node].
func _link(n: int, e: int) -> Array:
	var edges: Array = [e]
	var cur := other(e, n)
	var prev_e := e
	while _adj[cur].size() == 2 and cur != n:
		var nxt: int = _adj[cur][0] if _adj[cur][0] != prev_e else _adj[cur][1]
		edges.append(nxt)
		prev_e = nxt
		cur = other(nxt, cur)
	return [edges, cur]


## The whole run of edge e between real junctions: [edges, end, end].
func _full_link(e: int) -> Array:
	var edges: Array = [e]
	var ends: Array = []
	for start in [edge_a[e], edge_b[e]]:
		var cur: int = start
		var prev_e := e
		while _adj[cur].size() == 2:
			var nxt: int = _adj[cur][0] if _adj[cur][0] != prev_e else _adj[cur][1]
			if nxt == e:
				break
			edges.append(nxt)
			prev_e = nxt
			cur = other(nxt, cur)
		ends.append(cur)
	return [edges, ends[0], ends[1]]


## Drops some district streets and makes others pedestrian lanes, as each
## district's rules say. Dropping a street joins the blocks either side,
## within the district's size limits, and never cuts junctions off.
func _thin() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "thin"])
	var links: Array = []
	var seen := {}
	for n in node_pos.size():
		if _adj[n].size() == 2:
			continue
		for e in _adj[n]:
			if seen.has(e) or edge_patch[e] < 0:
				continue
			var l := _full_link(e)
			for x in l[0]:
				seen[x] = true
			links.append(l)
	# Blocks joined so far: union-find over faces.
	var group := PackedInt32Array()
	var pts: Array = []
	var areas := PackedFloat32Array()
	for f in faces.size():
		group.append(f)
		pts.append(faces[f].poly)
		areas.append(faces[f].area)
	var stranded := _stranded()
	for l in links:
		var e0: int = l[0][0]
		var p: Dictionary = PATCHES[edge_patch[e0]]
		var roll := rng.randf()
		var cut: float = p.cut[_fam[e0]] if _fam[e0] >= 0 else 0.0
		if roll < cut:
			if _adj[l[1]].size() < 3 or _adj[l[2]].size() < 3:
				continue
			var slots := edge_face[e0]
			if slots.x < 0 or slots.y < 0 or faces[slots.x].kind != "land" or faces[slots.y].kind != "land":
				continue
			var gf := _find(group, slots.x)
			var gg := _find(group, slots.y)
			if gf == gg or areas[gf] + areas[gg] > p.max[2]:
				continue
			var joined: PackedVector2Array = pts[gf] + pts[gg]
			var th := deg_to_rad(p.angle)
			if _extent(joined, Vector2(cos(th), sin(th))) > p.max[0] or _extent(joined, Vector2(-sin(th), cos(th))) > p.max[1]:
				continue
			for e in l[0]:
				_kill(e)
			if _stranded() > stranded:
				for e in l[0]:
					_revive(e)
				continue
			group[gg] = gf
			pts[gf] = joined
			areas[gf] += areas[gg]
		elif roll < cut + p.lane:
			for e in l[0]:
				edge_cls[e] = "lane"
			if _stranded() > stranded:
				for e in l[0]:
					edge_cls[e] = p.cls


## Outline of a park `span` long on `road`, `depth` deep, on the side of
## the road where `at` is. Sets _park_poly and returns the street round the
## three sides away from the road (empty when `at` isn't near the road).
func _park_shape(road: PackedVector2Array, at: Vector2, span: float, depth: float) -> PackedVector2Array:
	_park_poly = PackedVector2Array()
	var best_s := 0.0
	var best_d := INF
	var best_q := Vector2.ZERO
	var s := 0.0
	for k in road.size() - 1:
		var q := Geometry2D.get_closest_point_to_segment(at, road[k], road[k + 1])
		var d := q.distance_to(at)
		if d < best_d:
			best_d = d
			best_q = q
			best_s = s + road[k].distance_to(q)
		s += road[k].distance_to(road[k + 1])
	if best_d > depth or best_s < span * 0.5 or best_s > s - span * 0.5:
		push_warning("street plan: the park isn't beside its road")
		return PackedVector2Array()
	var t := _tangent(road, best_q)
	var side := Vector2(-t.y, t.x)
	if side.dot(at - best_q) < 0.0:
		side = -side
	var near := PackedVector2Array()
	var far := PackedVector2Array()
	for k in 7:
		var q := _point_at(road, best_s - span * 0.5 + span * k / 6.0)
		var tk := _tangent(road, q)
		var sk := Vector2(-tk.y, tk.x)
		if sk.dot(side) < 0.0:
			sk = -sk
		near.append(q)
		far.append(q + sk * depth)
	var ring := PackedVector2Array([near[0]])
	ring.append_array(far)
	ring.append(near[6])
	var poly := near.duplicate()
	far.reverse()
	poly.append_array(far)
	_park_poly = _tidy(poly)
	return ring


static func _extent(pts: PackedVector2Array, axis: Vector2) -> float:
	var lo := INF
	var hi := -INF
	for q in pts:
		var t := q.dot(axis)
		lo = minf(lo, t)
		hi = maxf(hi, t)
	return hi - lo


func _revive(e: int) -> void:
	_dead[e] = 0
	_adj[edge_a[e]].append(e)
	_adj[edge_b[e]].append(e)


## Junctions with a drivable street that can't be driven to from the first
## one. (A count of the reachable ones would drop whenever a curved street
## goes, taking its bend points with it.)
func _stranded() -> int:
	var start := -1
	for k in node_pos.size():
		if _drives(k):
			start = k
			break
	if start < 0:
		return 0
	var seen := PackedByteArray()
	seen.resize(node_pos.size())
	seen[start] = 1
	var todo := PackedInt32Array([start])
	while not todo.is_empty():
		var k := todo[todo.size() - 1]
		todo.remove_at(todo.size() - 1)
		for e in _adj[k]:
			if not CLASSES[edge_cls[e]].drive:
				continue
			var m := edge_b[e] if edge_a[e] == k else edge_a[e]
			if seen[m] == 0:
				seen[m] = 1
				todo.append(m)
	var count := 0
	for k in node_pos.size():
		if seen[k] == 0 and not _adj[k].is_empty() and _drives(k):
			count += 1
	return count


func _drives(k: int) -> bool:
	for e in _adj[k]:
		if CLASSES[edge_cls[e]].drive:
			return true
	return false


# --- Blocks ------------------------------------------------------------------------

func _find_faces() -> void:
	faces = []
	edge_face = []
	edge_face.resize(edge_a.size())
	for e in edge_a.size():
		edge_face[e] = Vector2i(-1, -1)
	var used := PackedByteArray()
	used.resize(edge_a.size() * 2)
	var loops: Array = []
	for h in edge_a.size() * 2:
		if used[h] == 1:
			continue
		var halves := PackedInt32Array()
		var cur := h
		var guard := 0
		while used[cur] == 0 and guard < 4000:
			used[cur] = 1
			halves.append(cur)
			cur = _next_half(cur)
			guard += 1
		var poly := PackedVector2Array()
		for x in halves:
			poly.append(node_pos[edge_a[x >> 1]] if (x & 1) == 0 else node_pos[edge_b[x >> 1]])
		loops.append([halves, area(poly)])
	var pos_count := 0
	for l in loops:
		if l[1] > 0.0:
			pos_count += 1
	var sign := 1.0 if pos_count * 2 >= loops.size() else -1.0
	for l in loops:
		if l[1] * sign <= 0.0:
			continue # outside every block
		var halves: PackedInt32Array = l[0]
		var f := faces.size()
		var nodes := PackedInt32Array()
		var edges := PackedInt32Array()
		for x in halves:
			var e := x >> 1
			nodes.append(edge_a[e] if (x & 1) == 0 else edge_b[e])
			edges.append(e)
			var slot := edge_face[e]
			if (x & 1) == 0:
				slot.x = f
			else:
				slot.y = f
			edge_face[e] = slot
		if sign < 0.0:
			# Reverse to clockwise on screen: node k -> k + 1 along edge k.
			var n := nodes.size()
			var rn := PackedInt32Array()
			var re := PackedInt32Array()
			for i in n:
				rn.append(nodes[(n - i) % n])
				re.append(edges[(n - 1 - i + n) % n])
			nodes = rn
			edges = re
		var poly := PackedVector2Array()
		for k in nodes:
			poly.append(node_pos[k])
		var c := interior_point(poly)
		faces.append({
			"nodes": nodes, "edges": edges, "poly": poly, "area": absf(area(poly)), "center": c,
			"kind": "water" if is_water_point(c) else "land", "bbox": _bbox(poly),
			"inner": PackedVector2Array(), "sides": PackedInt32Array(), "lot": PackedVector2Array(), "front": 0,
		})


## Next half-edge round the same face. Half-edge 2e runs a -> b, 2e + 1
## runs b -> a.
func _next_half(h: int) -> int:
	var e := h >> 1
	var v := edge_b[e] if (h & 1) == 0 else edge_a[e]
	var list: Array = _adj[v]
	var i := list.find(e)
	var e2: int = list[(i + 1) % list.size()]
	return e2 * 2 if edge_a[e2] == v else e2 * 2 + 1


## Joins blocks too small for their landmark (or the park) with the
## neighbour that helps most, dropping the district street between them.
## `wants` holds [local point, lot size]. True if anything changed.
func _grow_blocks(wants: Array) -> bool:
	_index()
	var claimed := {}
	for w in wants:
		var f := face_of(w[0])
		if f >= 0:
			claimed[f] = true
	var changed := false
	for w in wants:
		var f := face_of(w[0])
		if f < 0 or faces[f].kind != "land":
			continue
		_block_geom(f)
		if faces[f].kind != "land":
			continue
		var need: Vector2 = w[1]
		var to_frame := front_frame2d(f).affine_inverse()
		var fit: float = _landmark_rect(f, need)[2]
		if fit >= 1.0:
			continue
		# Options: [fit, edges to drop], one neighbour at a time; when none
		# helps, pairs (fanned blocks lean, so an L of three blocks may not
		# fit where the fourth block fills it out).
		var options: Array = []
		var singles := _merge_options(f, faces[f].poly, [f], claimed)
		for o in singles:
			var gfit := _merged_fit(o[2], to_frame, need)
			if gfit > fit + 0.02:
				options.append([gfit, [o[1]]])
		if _drop_best(options):
			changed = true
			continue
		options = []
		for o in singles:
			for o2 in _merge_options(f, o[2], [f, o[0]], claimed):
				var gfit := _merged_fit(o2[2], to_frame, need)
				if gfit > fit + 0.02:
					options.append([gfit, [o[1], o2[1]]])
		if _drop_best(options):
			changed = true
	return changed


## Drops the streets of the best option that can go ([fit, edges] each).
func _drop_best(options: Array) -> bool:
	options.sort_custom(func(x, y): return x[0] > y[0])
	for o in options:
		if _drop_links(o[1]):
			return true
	return false


## Neighbours of the blocks in `members` (around `poly`, their union) that a
## landmark block may join: [face, edge between, union polygon].
func _merge_options(f: int, poly: PackedVector2Array, members: Array, claimed: Dictionary) -> Array:
	var out: Array = []
	var seen := {}
	for m in members:
		for e in faces[m].edges:
			if edge_patch[e] < 0 or _dead[e] == 1:
				continue
			var slots := edge_face[e]
			var g := slots.y if slots.x == m else slots.x
			if g < 0 or members.has(g) or seen.has(g) or faces[g].kind != "land" or (claimed.has(g) and g != f):
				continue
			seen[g] = true
			var merged := _largest(Geometry2D.merge_polygons(poly, faces[g].poly))
			if merged.size() >= 3:
				out.append([g, e, merged])
	return out


## How well a joined block would hold `need`: its outline, pulled in by
## about a street half and a sidewalk.
func _merged_fit(merged: PackedVector2Array, to_frame: Transform2D, need: Vector2) -> float:
	var approx := _largest(Geometry2D.offset_polygon(merged, -8.5))
	if approx.size() < 3:
		return 0.0
	return _fit(largest_rect(to_frame * approx, need), need)


## Drops the streets through `edges` (each with the bends either side), or
## none of them if that would strand a junction.
func _drop_links(edges: Array) -> bool:
	var stranded := _stranded()
	var killed: Array = []
	for e in edges:
		if _dead[e] == 1:
			continue
		var l := _full_link(e)
		if _adj[l[1]].size() < 3 or _adj[l[2]].size() < 3:
			for k in killed:
				_revive(k)
			return false
		for k in l[0]:
			_kill(k)
			killed.append(k)
	if _stranded() > stranded:
		for k in killed:
			_revive(k)
		return false
	return not killed.is_empty()


static func _fit(r: Rect2, need: Vector2) -> float:
	return minf(r.size.x / need.x, r.size.y / need.y)


## Where a landmark goes in block f: [side, rect in that side's frame, fit]
## over the block's street sides, the rect centred on its side so the door
## (and the sidewalk spot in front) faces that street. Best fit wins, then
## the camera-facing front, then area.
func _landmark_rect(f: int, need: Vector2) -> Array:
	var face: Dictionary = faces[f]
	var inner: PackedVector2Array = face.inner
	var best: Array = [face.front, Rect2(), -1.0]
	var best_a := 0.0
	for k in inner.size():
		var e: int = face.sides[k]
		if e < 0 or not drivable(e) or edge_cls[e] == "bridge":
			continue
		var half := inner[k].distance_to(inner[(k + 1) % inner.size()]) * 0.5
		if half < 8.0:
			continue
		var r := largest_rect(side_frame2d(f, k).affine_inverse() * face.lot, need, half - 3.0)
		var fit := minf(1.0, _fit(r, need))
		var a := r.get_area()
		var better: bool = fit > best[2] + 0.001
		if not better and fit > best[2] - 0.001:
			better = k == face.front or (best[0] != face.front and a > best_a)
		if better:
			best = [k, r, fit]
			best_a = a
	if best[2] < 0.0:
		best = [face.front, largest_rect(front_frame2d(f).affine_inverse() * face.lot, need), 0.0]
		best[2] = minf(1.0, _fit(best[1], need))
	return best


func _make_blocks() -> void:
	for f in faces.size():
		var face: Dictionary = faces[f]
		face["rect"] = Rect2()
		face["patch"] = _patch_index(face.center)
		if face.kind == "land":
			_block_geom(f)
			if face.kind == "land" and face.lot.size() >= 3:
				face.rect = largest_rect(front_frame2d(f).affine_inverse() * face.lot)


## Inner polygon, lot, street sides and front of block f.
func _block_geom(f: int) -> void:
	var face: Dictionary = faces[f]
	var poly: PackedVector2Array = face.poly
	var n := poly.size()
	var pieces: Array = [poly]
	for k in n:
		var e: int = face.edges[k]
		var w := edge_width(e) * 0.5
		var a := poly[k]
		var b := poly[(k + 1) % n]
		var d := (b - a).normalized()
		var side := Vector2(-d.y, d.x) * w
		var strip := PackedVector2Array([a - d * w + side, b + d * w + side, b + d * w - side, a - d * w - side])
		var next: Array = []
		for piece in pieces:
			next.append_array(Geometry2D.clip_polygons(piece, strip))
		pieces = next
	var inner_poly := _tidy(_largest(pieces))
	if inner_poly.size() < 3 or absf(area(inner_poly)) < 40.0:
		face.kind = "sliver"
		face.inner = PackedVector2Array()
		face.lot = PackedVector2Array()
		return
	face.inner = inner_poly
	var lot_poly := _tidy(_largest(Geometry2D.offset_polygon(inner_poly, -SIDEWALK, Geometry2D.JOIN_MITER)))
	face.lot = lot_poly if lot_poly.size() >= 3 else PackedVector2Array()
	# Which street each inner side runs along.
	var m := inner_poly.size()
	var sides := PackedInt32Array()
	for k in m:
		var a := inner_poly[k]
		var b := inner_poly[(k + 1) % m]
		var mid := (a + b) * 0.5
		var d := (b - a).normalized()
		var best := -1
		var best_err := 1.6
		for j in n:
			var e: int = face.edges[j]
			var pa := poly[j]
			var pb := poly[(j + 1) % n]
			var ed := (pb - pa).normalized()
			if absf(ed.cross(d)) > 0.2:
				continue
			var err := absf(Geometry2D.get_closest_point_to_segment_uncapped(mid, pa, pb).distance_to(mid) - edge_width(e) * 0.5)
			var t := (mid - pa).dot(ed)
			if t < -edge_width(e) or t > pa.distance_to(pb) + edge_width(e):
				continue
			if err < best_err:
				best_err = err
				best = e
		sides.append(best)
	face.sides = sides
	# The front: the street side facing the camera most, preferring real
	# streets and longer sides.
	var front := 0
	var best_score := -INF
	for k in m:
		var e := sides[k]
		var a := inner_poly[k]
		var b := inner_poly[(k + 1) % m]
		var d := (b - a).normalized()
		var out := Vector2(d.y, -d.x)
		var score := out.y
		if e < 0 or not drivable(e) or edge_cls[e] == "bridge":
			score -= 2.0
		else:
			score += CLASSES[edge_cls[e]].rank * 0.03
		if a.distance_to(b) < 16.0:
			score -= 0.8
		if score > best_score:
			best_score = score
			front = k
	face.front = front


## The block frame for f: basis.x along the front street (left to right
## seen from it), basis.z out through it, origin at the front's middle on
## the inner polygon.
func front_frame2d(f: int) -> Transform2D:
	return side_frame2d(f, faces[f].front)


## The same frame on inner side k of block f.
func side_frame2d(f: int, k: int) -> Transform2D:
	var poly: PackedVector2Array = faces[f].inner
	var a := poly[k]
	var b := poly[(k + 1) % poly.size()]
	var along := (a - b).normalized()
	var out := Vector2(-along.y, along.x)
	return Transform2D(along, out, (a + b) * 0.5)


## The largest rectangle in f's lot aligned with its front frame, in frame
## coordinates (x along, y out through the front, so the lot is at y < 0).
func lot_rect(f: int) -> Rect2:
	var face: Dictionary = faces[f]
	if face.has("rect"):
		return face.rect
	if face.lot.size() < 3:
		return Rect2()
	return largest_rect(front_frame2d(f).affine_inverse() * face.lot)


## Id of the district patch block f belongs to ("" outside every patch).
func face_patch(f: int) -> String:
	var k: int = faces[f].get("patch", -1)
	return PATCHES[k].id if k >= 0 else ""


## Id of the district patch at local point p ("" outside every patch).
func patch_at(p: Vector2) -> String:
	var k := _patch_index(p)
	return PATCHES[k].id if k >= 0 else ""


func _patch_index(p: Vector2) -> int:
	for r in _regions:
		if Geometry2D.is_point_in_polygon(p, r[0]):
			return r[1]
	return -1


func _index() -> void:
	_node_grid = {}
	for k in node_pos.size():
		var key := Vector2i(floori(node_pos[k].x / GRID), floori(node_pos[k].y / GRID))
		if not _node_grid.has(key):
			_node_grid[key] = []
		_node_grid[key].append(k)
	_face_grid = {}
	for f in faces.size():
		var r: Rect2 = faces[f].bbox
		for gx in range(floori(r.position.x / GRID), floori(r.end.x / GRID) + 1):
			for gy in range(floori(r.position.y / GRID), floori(r.end.y / GRID) + 1):
				var key := Vector2i(gx, gy)
				if not _face_grid.has(key):
					_face_grid[key] = []
				_face_grid[key].append(f)


# --- Polygons ------------------------------------------------------------------------

## Shoelace area: positive for clockwise on screen (y down).
static func area(poly: PackedVector2Array) -> float:
	var s := 0.0
	var n := poly.size()
	for k in n:
		s += poly[k].cross(poly[(k + 1) % n])
	return s * 0.5


static func _bbox(poly: PackedVector2Array) -> Rect2:
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	return r


static func _largest(polys: Array) -> PackedVector2Array:
	var best := PackedVector2Array()
	var best_a := 0.0
	for p in polys:
		var a := absf(area(p))
		if a > best_a:
			best_a = a
			best = p
	return best


## Clockwise on screen, without repeated or straight-through points.
static func _tidy(poly: PackedVector2Array) -> PackedVector2Array:
	if poly.size() < 3:
		return poly
	if area(poly) < 0.0:
		poly.reverse()
	var out := PackedVector2Array()
	var n := poly.size()
	for k in n:
		var a := poly[(k - 1 + n) % n]
		var b := poly[k]
		var c := poly[(k + 1) % n]
		if b.distance_to(a) < 0.3:
			continue
		if absf((b - a).normalized().cross((c - b).normalized())) < 0.01 and (b - a).dot(c - b) > 0.0:
			continue
		out.append(b)
	return out


## A point inside the polygon (its centroid when that is inside).
static func interior_point(poly: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	var a := 0.0
	var n := poly.size()
	for k in n:
		var cr := poly[k].cross(poly[(k + 1) % n])
		a += cr
		c += (poly[k] + poly[(k + 1) % n]) * cr
	if absf(a) > 0.001:
		c /= 3.0 * a
		if Geometry2D.is_point_in_polygon(c, poly):
			return c
	var tris := Geometry2D.triangulate_polygon(poly)
	var best := poly[0]
	var best_a := -1.0
	for t in range(0, tris.size(), 3):
		var p0 := poly[tris[t]]
		var p1 := poly[tris[t + 1]]
		var p2 := poly[tris[t + 2]]
		var ta := absf((p1 - p0).cross(p2 - p0))
		if ta > best_a:
			best_a = ta
			best = (p0 + p1 + p2) / 3.0
	return best


## The largest axis-aligned rectangle inside a polygon (scanlines 1.5 m
## apart, so it can be a little generous between them; trimmed for that).
## With `need`, a rectangle that fits need (or comes closest) wins over a
## bigger one that doesn't: an L-shaped block's largest rectangle can be a
## long thin strip when a squarer one would hold a landmark. With `reach`,
## only rectangles on the front (top within a metre or so of the lot's
## front edge) whose middle is within reach of x = 0 count.
static func largest_rect(poly: PackedVector2Array, need := Vector2.ZERO, reach := -1.0) -> Rect2:
	var r := _bbox(poly)
	var step := maxf(1.5, r.size.x / 40.0)
	var xs := PackedFloat32Array()
	var lows := PackedFloat32Array()
	var highs := PackedFloat32Array()
	var n := poly.size()
	var x := r.position.x + step * 0.5
	while x < r.end.x:
		var zs: Array = []
		for k in n:
			var a := poly[k]
			var b := poly[(k + 1) % n]
			if (a.x <= x) != (b.x <= x):
				zs.append(a.y + (x - a.x) / (b.x - a.x) * (b.y - a.y))
		zs.sort()
		var lo := 0.0
		var hi := 0.0
		for i in range(0, zs.size() - 1, 2):
			if zs[i + 1] - zs[i] > hi - lo:
				lo = zs[i]
				hi = zs[i + 1]
		xs.append(x)
		lows.append(lo + 0.3)
		highs.append(hi - 0.3)
		x += step
	var best := Rect2()
	var best_a := 0.0
	var best_f := 0.0
	for i in xs.size():
		var top := -INF
		var bottom := INF
		for j in range(i, xs.size()):
			top = maxf(top, lows[j])
			bottom = minf(bottom, highs[j])
			if bottom <= top:
				break
			var w := xs[j] - xs[i]
			if reach >= 0.0 and (bottom < -SIDEWALK - 1.5 or absf(xs[i] + w * 0.5) > reach):
				continue
			var a := w * (bottom - top)
			var f := 0.0 if need == Vector2.ZERO else minf(1.0, _fit(Rect2(0, 0, w, bottom - top), need))
			if f > best_f + 0.001 or (f > best_f - 0.001 and a > best_a):
				best_f = f
				best_a = a
				best = Rect2(xs[i], top, w, bottom - top)
	return best
