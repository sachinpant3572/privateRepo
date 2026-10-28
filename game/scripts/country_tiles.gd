extends RefCounted
## Builds one square tile of the country (country.gd) from its data in
## res://data/country.json: ground by zone, roads with markings, sidewalks
## and lights, bridges, banks and the play area's fence, storm barricades,
## lots (kits/country_kit.gd), rail lines, fields, vineyards, ponds and trees.
##
## Static and free of the scene tree, so it runs on a worker thread. A road
## edge, lot, wall or barricade belongs to the tile its middle falls in.
## Returns {mesh, glow, colliders (world walls), props, buildings}; colliders
## are [center, size, yaw] boxes in local metres.

const MeshBuilder = preload("res://scripts/mesh_builder.gd")
const Props = preload("res://scripts/kits/prop_kit.gd")
const Kit = preload("res://scripts/kits/country_kit.gd")
const Grounds = preload("res://scripts/kits/grounds_kit.gd")
const Terrain = preload("res://scripts/terrain.gd")

## Zones whose home cars are live parked cars (Kit.live_cars) rather than
## static models: Bellerive's suburbs (HANDOFF-bellerive-expand.md BX-2).
const LIVE_CAR_ZONES := ["heights", "eastside", "fringe", "shore", "beach_town", "bayou_town"]
const GROUND_Y := -0.04
## On the hills the ground sits this much lower still, so a road (straight
## between its nodes) never dips under a crest of the ground it lies on.
const HILL_GROUND_DROP := 0.26
## Longest edge of a ground triangle on the hills (the height grid is 8 m).
const HILL_TRI := 9.0
## Longest edge of a road, junction or path triangle, and longest piece
## of a lane marking, on the hills, so they follow the ground the cars
## ride on (Terrain.height) instead of cutting a chord through it.
const HILL_PIECE := 4.0
## How far markings sit above the road on the hills, over what is left of
## the chord between their ends.
const HILL_MARK_LIFT := 0.05
## The hills' baked light (from the north-west, fairly low) and the colours
## their faces take (see _hill_shade).
const HILL_LIGHT := Vector3(-0.45, 0.75, -0.48)
const HILL_SCRUB := Color(0.36, 0.4, 0.22)
const HILL_GOLD := Color(0.78, 0.64, 0.34)
const HILL_ROCK := Color(0.58, 0.54, 0.48)
const ROAD_Y := 0.0
const KERB := 0.15
const SIDEWALK := 2.5
## Water lies at -0.55 (city.gd); banks reach below it.
const BANK_BOTTOM := -1.2
const WALL_HEIGHT := 6.0

const ASPHALT := Color(0.27, 0.27, 0.29)
const OLD_ASPHALT := Color(0.33, 0.33, 0.33)
const DIRT := Color(0.52, 0.42, 0.31)
const GRAVEL := Color(0.6, 0.57, 0.51)
const PAVEMENT := Color(0.58, 0.56, 0.52)
const CURB := Color(0.66, 0.65, 0.63)
const MARKING := Color(0.92, 0.8, 0.3)
const WHITE_LINE := Color(0.9, 0.9, 0.88)
const CONCRETE := Color(0.62, 0.61, 0.58)
const BANK := Color(0.36, 0.31, 0.24)
const STONE := Color(0.5, 0.48, 0.44)
const SEAWALL := Color(0.72, 0.7, 0.64)
const CHAIN := Color(0.6, 0.62, 0.64)
const ORANGE := Color(0.95, 0.45, 0.1)
const BALLAST := Color(0.45, 0.42, 0.38)
const SLEEPER := Color(0.36, 0.28, 0.21)
const STEEL := Color(0.62, 0.63, 0.65)
const BARK := Color(0.38, 0.27, 0.19)
const POND := Color(0.17, 0.25, 0.21)

## Ground colour per zone (the flag marks green ground).
const ZONE_GROUND := {
	"land": [Color(0.44, 0.55, 0.3), true], "farmland": [Color(0.6, 0.56, 0.34), false],
	"bayou": [Color(0.3, 0.4, 0.24), true], "hills": [Color(0.38, 0.54, 0.28), true],
	"heights": [Color(0.36, 0.55, 0.3), true], "bayou_town": [Color(0.34, 0.47, 0.28), true],
	"fringe": [Color(0.5, 0.52, 0.4), false], "eastside": [Color(0.44, 0.52, 0.36), true],
	"beach_town": [Color(0.5, 0.56, 0.38), true], "shore": [Color(0.48, 0.55, 0.36), true],
	"town": [Color(0.46, 0.53, 0.34), true], "sand": [Color(0.86, 0.79, 0.6), false],
	"far_desert": [Color(0.74, 0.64, 0.46), false], "far_mountains": [Color(0.5, 0.48, 0.42), false],
	"far_forest": [Color(0.26, 0.38, 0.22), true], "far_lakeside": [Color(0.38, 0.52, 0.3), true],
	"far_parkland": [Color(0.4, 0.56, 0.3), true], "far_military": [Color(0.55, 0.54, 0.44), false],
	"far_land": [Color(0.48, 0.54, 0.34), true],
	# The Bellerive Hills: dry golden grass under the chaparral.
	"mountain": [Color(0.6, 0.55, 0.36), false],
	# Golden Flats fields (tools/farmland.py): pivot circles with wheel
	# tracks, strip fields in rows, canals in concrete.
	"pivot_track": [Color(0.42, 0.34, 0.24), false], "pivot_green": [Color(0.3, 0.42, 0.2), false],
	"pivot_gold": [Color(0.78, 0.66, 0.33), false], "pivot_bare": [Color(0.52, 0.4, 0.28), false],
	"field_green_row": [Color(0.27, 0.37, 0.17), false], "field_green": [Color(0.38, 0.48, 0.26), false],
	"field_gold": [Color(0.82, 0.71, 0.38), false], "field_bare_row": [Color(0.44, 0.33, 0.22), false],
	"field_bare": [Color(0.56, 0.44, 0.3), false], "canal": [Color(0.2, 0.33, 0.35), false],
	"canal_bank": [Color(0.66, 0.64, 0.58), false],
}
## Tree spacing (metres between trees) and kind per zone.
const TREES := {
	"land": [36.0, "round"], "farmland": [90.0, "round"], "bayou": [15.0, "cypress"],
	"hills": [26.0, "cypress"], "heights": [15.0, "round"], "bayou_town": [16.0, "cypress"],
	"fringe": [28.0, "round"], "eastside": [18.0, "palm"], "beach_town": [16.0, "palm"],
	"shore": [18.0, "palm"], "town": [22.0, "round"], "sand": [70.0, "palm"],
	"far_desert": [40.0, "shrub"], "far_mountains": [22.0, "pine"], "far_forest": [12.0, "pine"],
	"far_lakeside": [22.0, "round"], "far_parkland": [24.0, "round"], "far_military": [90.0, "shrub"],
	"far_land": [30.0, "round"],
	"mountain": [10.0, "chaparral"],
}
const TREE_GRID := 10.0
const MAX_TREES := 120
const POND_GRID := 25.0
const LIGHT_CLASSES := ["street", "avenue"]
const POLE_CLASSES := ["road", "lane", "track"]


class Ctx:
	var country
	var key: Vector2i
	var rect: Rect2
	var mb
	var glow
	var out: Array = []
	var props: Array = []
	var buildings := 0
	## Live parking spots of the suburbs' home cars: [key "lot:k", position, yaw].
	var parks: Array = []
	var rng := RandomNumberGenerator.new()
	## Ground triangles of this tile: [a, b, c (Vector2), zone name].
	var tris: Array = []
	## Whether the tile lies on the hills, and its ground's vertices in mb.
	var hill := false
	var ground_end := 0
	## Lots and plots on the hills' flat pads, lifted as one piece:
	## [first vertex, end vertex, first collider, end collider, height].
	var rigid: Array = []
	## Route pieces past a hill lot's front, already set to their height:
	## [first vertex, end vertex] (the rigid lift skips them).
	var fixed: Array = []
	## Lots and plots (index) and wall/rail segments ([a, b]) near the
	## tile, for keeping scenery off them.
	var lots_near: Array = []
	var plots_near: Array = []
	var segs_near: Array = []


static func build(country, key: Vector2i) -> Dictionary:
	var ctx := Ctx.new()
	ctx.country = country
	ctx.key = key
	ctx.rect = Rect2(Vector2(key) * country.tile_size, Vector2.ONE * country.tile_size)
	ctx.mb = MeshBuilder.new()
	ctx.glow = MeshBuilder.new()
	ctx.rng.seed = hash([country.seed_value, "tile", key.x, key.y])
	var t: Dictionary = country.tiles.get(key, {})
	ctx.hill = Terrain.touches(ctx.rect.grow(1.0))
	if not t.is_empty():
		_ground(ctx, t.g)
		ctx.ground_end = ctx.mb.verts.size()
		_gather(ctx)
		for e in t.r:
			_road(ctx, int(e))
		_junctions(ctx)
		ctx.mb.mark_ground(0)
		for i in t.get("q", []):
			_plot(ctx, int(i))
		for i in t.l:
			_lot(ctx, int(i))
		for i in t.p:
			_driveway(ctx, country.paths[int(i)])
		for i in t.w:
			_wall(ctx, country.walls[int(i)])
		for i in t.b:
			_barricade(ctx, country.barricades[int(i)])
		for pair in t.x:
			_rail(ctx, int(pair[0]), int(pair[1]))
		var roads_from: int = ctx.mb.verts.size()
		for pair in t.f:
			_far_road(ctx, int(pair[0]), int(pair[1]))
		for pair in t.t:
			_trail(ctx, int(pair[0]), int(pair[1]))
		ctx.mb.mark_ground(roads_from)
		_ponds(ctx)
		_trees(ctx)
		if ctx.hill:
			_drape(ctx)
	return {"mesh": ctx.mb, "glow": ctx.glow, "colliders": ctx.out, "props": ctx.props, "buildings": ctx.buildings,
			"parks": ctx.parks}


# --- Helpers ------------------------------------------------------------------------

static func _v3(p: Vector2, y := 0.0) -> Vector3:
	return Vector3(p.x, y, p.y)


## Frame along a -> b: local x runs from a to b, local +z is the left
## normal (-d.y, d.x).
static func _frame(a: Vector2, b: Vector2, y := 0.0) -> Transform3D:
	var d := (b - a).normalized()
	return Transform3D(Basis(Vector3.UP, atan2(-d.y, d.x)), _v3(a, y))


## Moves colliders built in mb's current frame into `into` and resets the frame.
static func _done(ctx: Ctx, local: Array, into: Array) -> void:
	var x: Transform3D = ctx.mb.xform
	var yaw := atan2(-x.basis.x.z, x.basis.x.x)
	for col in local:
		into.append([x * col[0], col[1], yaw + (col[2] if col.size() > 2 else 0.0)] + col.slice(3))
	ctx.mb.xform = Transform3D.IDENTITY


## Collider box along a segment.
static func _seg_box(a: Vector2, b: Vector2, y: float, height: float, thick: float) -> Array:
	var d := b - a
	return [_v3((a + b) * 0.5, y + height * 0.5), Vector3(d.length() + thick * 0.5, height, thick), atan2(-d.y, d.x)]


## The polygon in the winding prism() expects (clockwise on screen).
static func _cw(poly: PackedVector2Array) -> PackedVector2Array:
	var s := 0.0
	for k in poly.size():
		var a := poly[k]
		var b := poly[(k + 1) % poly.size()]
		s += a.x * b.y - b.x * a.y
	if s < 0.0:
		poly.reverse()
	return poly


static func _circle(c: Vector2, r: float, sides: int) -> PackedVector2Array:
	var poly := PackedVector2Array()
	for i in sides:
		var a := TAU * i / sides
		poly.append(c + Vector2(cos(a), sin(a)) * r)
	return _cw(poly)


static func _is_junction(c, n: int) -> bool:
	return c.degree(n) != 2 or c.links.has(n)


## How far the markings and sidewalks of edge e stop short of junction n.
static func _setback(c, n: int, e: int) -> float:
	if not _is_junction(c, n) or c.degree(n) < 2:
		return 0.0
	var w := 0.0
	for e2 in c.edges_of(n):
		if e2 != e:
			w = maxf(w, c.edge_width(e2))
	return w * 0.5 + 1.0


## Offset direction at node n for edge e (unit normal n_e when the road
## does not carry on through n, else the mitred normal scaled so strips keep
## their width round the bend).
static func _miter(c, e: int, node: int, n: Vector2, start: bool) -> Vector2:
	if _is_junction(c, node):
		return n
	var adj: PackedInt32Array = c.edges_of(node)
	var e2: int = adj[0] if adj[0] != e else adj[1]
	var p: Vector2 = c.node_pos[node]
	var o: Vector2 = c.node_pos[c.other(e2, node)]
	var d2 := (p - o).normalized() if start else (o - p).normalized()
	var m := (n + Vector2(-d2.y, d2.x)).normalized()
	var k := m.dot(n)
	if k < 0.5:
		return n
	return m / k


## Strip beside edge e between offsets h0 and h1 (left of a -> b positive),
## pulled back s0 / s1 from the ends.
static func _strip(c, e: int, h0: float, h1: float, s0 := 0.0, s1 := 0.0) -> PackedVector2Array:
	var a: Vector2 = c.node_pos[c.edge_a[e]]
	var b: Vector2 = c.node_pos[c.edge_b[e]]
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	var ma := n if s0 > 0.0 else _miter(c, e, c.edge_a[e], n, true)
	var mb := n if s1 > 0.0 else _miter(c, e, c.edge_b[e], n, false)
	var pa := a + d * s0
	var pb := b - d * s1
	return _cw(PackedVector2Array([pa + ma * h0, pb + mb * h0, pb + mb * h1, pa + ma * h1]))


static func _dashes(mb, s0: float, run: float, z: float, color: Color, lift := 0.0) -> void:
	var t := s0 + 1.5
	while t < s0 + run - 3.0:
		mb.box(Vector3(t + 1.5, 0.01 + lift, z), Vector3(3.0, 0.02, 0.16), color)
		t += 7.0


## A solid line; with `piece` set it is cut into pieces no longer than
## that, so it can follow the hills.
static func _line(mb, s0: float, run: float, z: float, color: Color, piece := 0.0, lift := 0.0) -> void:
	if run <= 0.5:
		return
	var n := 1 if piece <= 0.0 else ceili(run / piece)
	var l := run / n
	for i in n:
		mb.box(Vector3(s0 + l * (i + 0.5), 0.01 + lift, z), Vector3(l, 0.02, 0.14), color)


static func _seg_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))


# --- Ground ------------------------------------------------------------------------

static func _ground(ctx: Ctx, parts: Array) -> void:
	for part in parts:
		var zone: String = ctx.country.zones[int(part[0])]
		var g: Array = ZONE_GROUND.get(zone, [Color(0.45, 0.52, 0.34), true])
		# Plain colour: the grass code's mown stripes read as a lawn, not a field.
		var color: Color = g[0]
		var flat: Array = part[1]
		for k in range(0, flat.size() - 5, 6):
			var a := Vector2(flat[k], flat[k + 1])
			var b := Vector2(flat[k + 2], flat[k + 3])
			var cc := Vector2(flat[k + 4], flat[k + 5])
			if ctx.hill:
				_hill_tri(ctx.mb, a, b, cc, color)
			else:
				ctx.mb.tri(_v3(a, GROUND_Y), _v3(b, GROUND_Y), _v3(cc, GROUND_Y), Vector3.UP, color)
			ctx.tris.append([a, b, cc, zone])


## A ground triangle on the hills, split until no edge is longer than
## HILL_TRI so it can follow the height grid (_drape lifts it).
static func _hill_tri(mb, a: Vector2, b: Vector2, c: Vector2, color: Color, y := GROUND_Y, size := HILL_TRI) -> void:
	var ab := a.distance_squared_to(b)
	var bc := b.distance_squared_to(c)
	var ca := c.distance_squared_to(a)
	var longest := maxf(ab, maxf(bc, ca))
	if longest <= size * size:
		mb.tri(_v3(a, y), _v3(b, y), _v3(c, y), Vector3.UP, color)
	elif longest == ab:
		var m := (a + b) * 0.5
		_hill_tri(mb, a, m, c, color, y, size)
		_hill_tri(mb, m, b, c, color, y, size)
	elif longest == bc:
		var m := (b + c) * 0.5
		_hill_tri(mb, b, m, a, color, y, size)
		_hill_tri(mb, m, c, a, color, y, size)
	else:
		var m := (c + a) * 0.5
		_hill_tri(mb, c, m, b, color, y, size)
		_hill_tri(mb, m, a, b, color, y, size)


## A flat polygon at y; on the hills it is cut into small triangles so
## _drape can lay it on the ground.
static func _flat(ctx: Ctx, poly: PackedVector2Array, y: float, color: Color) -> void:
	if not ctx.hill:
		ctx.mb.flat(poly, y, color)
		return
	var idx := Geometry2D.triangulate_polygon(poly)
	if idx.is_empty():
		for k in range(1, poly.size() - 1):
			idx.append_array([0, k, k + 1])
	for k in range(0, idx.size(), 3):
		_hill_tri(ctx.mb, poly[idx[k]], poly[idx[k + 1]], poly[idx[k + 2]], color, y, HILL_PIECE)


## Lays the tile on the hills: lots and plots rise as one piece to their
## pads, every other vertex, collider and prop by the ground's height under
## it (the city and the flat country stay at 0), and the ground takes the
## hill's own normals and shade.
static func _drape(ctx: Ctx) -> void:
	var mb = ctx.mb
	var lifted := PackedByteArray()
	lifted.resize(mb.verts.size())
	var out_lifted := PackedByteArray()
	out_lifted.resize(ctx.out.size())
	for r: Array in ctx.fixed:
		for i in range(r[0], r[1]):
			lifted[i] = 1
	for r: Array in ctx.rigid:
		var h: float = r[4]
		for i in range(r[0], r[1]):
			if lifted[i] == 0:
				mb.verts[i] += Vector3(0.0, h, 0.0)
			lifted[i] = 1
		for i in range(r[2], r[3]):
			var p: Vector3 = ctx.out[i][0]
			ctx.out[i][0] = p + Vector3(0.0, h, 0.0)
			out_lifted[i] = 1
	for i in mb.verts.size():
		if lifted[i] == 1:
			continue
		var v: Vector3 = mb.verts[i]
		var h := Terrain.height(v.x, v.z)
		if h == 0.0:
			continue
		if i < ctx.ground_end:
			v.y += h - HILL_GROUND_DROP * minf(1.0, h * 0.5)
			var n := Terrain.normal(v.x, v.z)
			mb.normals[i] = n
			mb.colors[i] = _hill_shade(mb.colors[i], n, h)
		else:
			v.y += h
		mb.verts[i] = v
	var glow = ctx.glow
	for i in glow.verts.size():
		var v: Vector3 = glow.verts[i]
		v.y += Terrain.height(v.x, v.z)
		glow.verts[i] = v
	for i in ctx.out.size():
		if out_lifted[i] == 0:
			var p: Vector3 = ctx.out[i][0]
			ctx.out[i][0] = p + Vector3(0.0, Terrain.height(p.x, p.z), 0.0)
	for c in ctx.props:
		var p: Vector3 = c[0]
		c[0] = p + Vector3(0.0, Terrain.height(p.x, p.z), 0.0)


## Ground colour on the hills, so the relief reads from above: baked
## shade from a low north-west light, dark chaparral on the north faces,
## golden grass on the south ones, and bare rock showing near the top.
## The alpha (the surface code) is kept.
static func _hill_shade(c: Color, n: Vector3, h: float) -> Color:
	var lit := clampf(1.0 + 2.2 * (n.dot(HILL_LIGHT) - HILL_LIGHT.y), 0.55, 1.3)
	var rgb := Color(c.r, c.g, c.b)
	rgb = rgb.lerp(HILL_SCRUB, clampf(-n.z * 2.5, 0.0, 0.55))
	rgb = rgb.lerp(HILL_GOLD, clampf(n.z * 2.5, 0.0, 0.35))
	rgb = rgb.lerp(HILL_ROCK, clampf((h - 70.0) / 60.0, 0.0, 0.4))
	return Color(rgb.r * lit, rgb.g * lit, rgb.b * lit, c.a)


## Lots and wall/rail segments in this tile and its neighbours.
static func _gather(ctx: Ctx) -> void:
	var c = ctx.country
	for gx in range(ctx.key.x - 1, ctx.key.x + 2):
		for gy in range(ctx.key.y - 1, ctx.key.y + 2):
			var t: Dictionary = c.tiles.get(Vector2i(gx, gy), {})
			if t.is_empty():
				continue
			for i in t.l:
				ctx.lots_near.append(int(i))
			for i in t.get("q", []):
				ctx.plots_near.append(int(i))
			for i in t.w:
				var w: Array = c.walls[int(i)]
				ctx.segs_near.append([Vector2(w[0], w[1]), Vector2(w[2], w[3]), 3.0])
			for pair in t.x:
				var pts: Array = c.rails[int(pair[0])].pts
				var k := int(pair[1])
				ctx.segs_near.append([Vector2(pts[k][0], pts[k][1]), Vector2(pts[k + 1][0], pts[k + 1][1]), 5.0])
			for i in t.p:
				var path: Array = c.paths[int(i)]
				ctx.segs_near.append([Vector2(path[0][0], path[0][1]), Vector2(path[1][0], path[1][1]), 3.0])


## The zone of the ground under p in this tile, "" off the ground.
static func _zone_at(ctx: Ctx, p: Vector2) -> String:
	for tr in ctx.tris:
		if Geometry2D.point_is_inside_triangle(p, tr[0], tr[1], tr[2]):
			return tr[3]
	return ""


## Whether p (with `room` metres round it) is clear of roads, lots, walls,
## rails and driveways.
static func _clear(ctx: Ctx, p: Vector2, room: float) -> bool:
	var c = ctx.country
	if c.road_distance(p, 40.0 + room) < room:
		return false
	for i in ctx.lots_near:
		if _in_rect(p, c.lots[i], room):
			return false
	for i in ctx.plots_near:
		if _in_rect(p, c.plots[i], room):
			return false
	for s in ctx.segs_near:
		if _seg_distance(p, s[0], s[1]) < s[2] + room * 0.5:
			return false
	return true


## Whether p is within `room` of a lot or plot [x, y, yaw, w, d, ...]; a
## lot's rect runs on out to the road its drives reach (element 9).
static func _in_rect(p: Vector2, l: Array, room: float) -> bool:
	var r := p - Vector2(l[0], l[1])
	var cs := cos(float(l[2]))
	var sn := sin(float(l[2]))
	var lx := r.x * cs - r.y * sn
	var lz := r.x * sn + r.y * cs
	var ahead := 0.0
	if l.size() > 9 and l[9] is Array:
		for v in l[9]:
			ahead = maxf(ahead, float(v))
	var hd := float(l[4]) * 0.5
	return absf(lx) < float(l[3]) * 0.5 + room and lz < hd + room and lz > -hd - ahead - room


# --- Roads -------------------------------------------------------------------------

static func _road(ctx: Ctx, e: int) -> void:
	var c = ctx.country
	var na: int = c.edge_a[e]
	var nb: int = c.edge_b[e]
	var a: Vector2 = c.node_pos[na]
	var b: Vector2 = c.node_pos[nb]
	var length := a.distance_to(b)
	if length < 0.3:
		return
	var cls: String = c.edge_class(e)
	var w: float = c.edge_width(e)
	var h := w * 0.5
	var mb = ctx.mb
	var bridge: bool = c.bridge_edges.has(e)
	var surface := DIRT if cls == "track" else (OLD_ASPHALT if cls == "lane" else ASPHALT)
	var road_color := MeshBuilder.glow(surface, MeshBuilder.ASPHALT) if cls != "track" else surface
	if bridge:
		_bridge(ctx, e, a, b, w)
	else:
		_flat(ctx, _strip(c, e, -h, h), ROAD_Y, road_color)
	var s0 := _setback(c, na, e)
	var s1 := _setback(c, nb, e)
	var run := length - s0 - s1
	var k: int = e - int(c.roads[c.edge_road[e]].e0)
	var frame := _frame(a, b, ROAD_Y)
	if run > 1.0:
		mb.xform = frame
		var piece := HILL_PIECE if ctx.hill else 0.0
		var lift := HILL_MARK_LIFT if ctx.hill else 0.0
		var geo: Dictionary = c.classes[c.edge_cls[e]]
		var lanes := int(geo.get("lanes", 0))
		var lane_w := float(geo.get("lane_w", 0.0))
		var middle := float(geo.get("middle", 0.0))
		match cls:
			"freeway", "highway":
				# A painted median between two yellow lines, dashes between
				# the lanes, a solid edge line before the shoulder.
				for side in [-1.0, 1.0]:
					_line(mb, s0, run, side * (middle - 0.15), MARKING, piece, lift)
					_line(mb, s0, run, side * (middle + lanes * lane_w + 0.15), WHITE_LINE, piece, lift)
					for j in range(1, lanes):
						_dashes(mb, s0, run, side * (middle + lane_w * j), WHITE_LINE, lift)
			"avenue", "street":
				for z in [-0.12, 0.12]:
					_line(mb, s0, run, z, MARKING, piece, lift)
				for side in [-1.0, 1.0]:
					for j in range(1, lanes):
						_dashes(mb, s0, run, side * (middle + lane_w * j), WHITE_LINE, lift)
			"road":
				_dashes(mb, s0, run, 0.0, MARKING, lift)
				for side in [-1.0, 1.0]:
					_line(mb, s0, run, side * (h - 0.5), WHITE_LINE, piece, lift)
		mb.xform = Transform3D.IDENTITY
	if bridge:
		return
	if cls in LIGHT_CLASSES:
		# Sidewalks both sides, a street light on every other edge.
		var t0 := s0 - 1.0 if s0 > 0.0 else 0.0
		var t1 := s1 - 1.0 if s1 > 0.0 else 0.0
		# On the hills in pieces, so the kerb follows the ground.
		var pieces := maxi(1, ceili((length - t0 - t1) / HILL_PIECE)) if ctx.hill else 1
		var step := (length - t0 - t1) / pieces
		for side in [-1.0, 1.0]:
			for i in pieces:
				var poly := _strip(c, e, side * h, side * (h + SIDEWALK), t0 + step * i, t1 + step * (pieces - 1 - i))
				mb.prism(poly, GROUND_Y, KERB, MeshBuilder.glow(PAVEMENT, MeshBuilder.CONCRETE), CURB)
		if k % 2 == 0 and run > 8.0:
			var side := 1.0 if k % 4 == 0 else -1.0
			var local: Array = []
			mb.xform = frame
			Props.street_light(mb, local, Vector3(s0 + run * 0.5, KERB, side * (h + 0.6)), Vector3(0, 0, -side), ctx.glow)
			_done(ctx, local, ctx.props)
	elif cls in POLE_CLASSES and k % 2 == 0:
		# Power poles on the left, wired to the next one along the road.
		var road: Dictionary = c.roads[c.edge_road[e]]
		var p := _pole_at(c, e, h)
		if p != Vector2.INF and c.road_distance(p, 40.0) > 1.0:
			var next = null
			var e2: int = int(road.e0) + k + 2
			if k + 2 < road.nodes.size() - 1:
				var q := _pole_at(c, e2, c.edge_width(e2) * 0.5)
				if q != Vector2.INF and q.distance_to(p) < 60.0:
					next = _v3(q)
			Props.power_pole(mb, ctx.props, _v3(p), next)


static func _pole_at(c, e: int, h: float) -> Vector2:
	var a: Vector2 = c.node_pos[c.edge_a[e]]
	var b: Vector2 = c.node_pos[c.edge_b[e]]
	if a.distance_to(b) < 4.0:
		return Vector2.INF
	var d := (b - a).normalized()
	return (a + b) * 0.5 + Vector2(-d.y, d.x) * (h + 3.0)


## Deck, parapets (walls) and a pier under the middle.
static func _bridge(ctx: Ctx, e: int, a: Vector2, b: Vector2, w: float) -> void:
	var c = ctx.country
	var mb = ctx.mb
	var h := w * 0.5 + 1.2
	mb.prism(_strip(c, e, -h, h), -1.4, ROAD_Y, MeshBuilder.glow(ASPHALT, MeshBuilder.ASPHALT), CONCRETE.darkened(0.15))
	var length := a.distance_to(b)
	var frame := _frame(a, b, ROAD_Y)
	mb.xform = frame
	for side in [-1.0, 1.0]:
		mb.box(Vector3(length * 0.5, 0.45, side * (h - 0.25)), Vector3(length + 0.2, 0.9, 0.5), MeshBuilder.glow(CONCRETE, MeshBuilder.CONCRETE))
	mb.cylinder(Vector3(length * 0.5, -4.0, 0), 1.1, 2.6, CONCRETE.darkened(0.2), 8)
	var k: int = e - int(c.roads[c.edge_road[e]].e0)
	var local: Array = []
	if k % 2 == 0:
		Props.street_light(mb, local, Vector3(length * 0.5, 0.9, h - 0.25), Vector3(0, 0, -1), ctx.glow)
	_done(ctx, local, ctx.props)
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	for side in [-1.0, 1.0]:
		ctx.out.append(_seg_box(a + n * side * (h - 0.25), b + n * side * (h - 0.25), ROAD_Y, 4.0, 0.8))


## Asphalt discs where roads meet or end, for the junction nodes in this tile.
static func _junctions(ctx: Ctx) -> void:
	var c = ctx.country
	for n in c.nodes_near(ctx.rect.get_center(), ctx.rect.size.x * 0.75):
		var p: Vector2 = c.node_pos[n]
		if not ctx.rect.has_point(p) or not _is_junction(c, n) or c.links.has(n):
			continue
		var w := 0.0
		var dirt := true
		var bridge := false
		for e in c.edges_of(n):
			w = maxf(w, c.edge_width(e))
			dirt = dirt and c.edge_class(e) == "track"
			bridge = bridge or c.bridge_edges.has(e)
		if bridge:
			continue
		var color := DIRT if dirt else MeshBuilder.glow(ASPHALT, MeshBuilder.ASPHALT)
		_flat(ctx, _circle(p, w * 0.5 + 0.6, 14), ROAD_Y + 0.003, color)


static func _driveway(ctx: Ctx, path: Array) -> void:
	var a := Vector2(path[0][0], path[0][1])
	var b := Vector2(path[1][0], path[1][1])
	if a.distance_to(b) < 0.2:
		return
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x) * 1.75
	_flat(ctx, _cw(PackedVector2Array([a - d + n, b + d + n, b + d - n, a - d - n])), ROAD_Y + 0.002, MeshBuilder.glow(GRAVEL, MeshBuilder.CONCRETE))


static func _polyline_quad(ctx: Ctx, a: Vector2, b: Vector2, w: float, y: float, color: Color) -> void:
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x) * w * 0.5
	var ext := d * w * 0.5
	_flat(ctx, _cw(PackedVector2Array([a - ext + n, b + ext + n, b + ext - n, a - ext - n])), y, color)


## Roads past the play area's edge: plain surfaces to look at.
static func _far_road(ctx: Ctx, i: int, k: int) -> void:
	var f: Dictionary = ctx.country.far_roads[i]
	var pts: Array = f.pts
	var w: float = ctx.country.classes[int(f.cls)].w
	var cls: String = ctx.country.classes[int(f.cls)].id
	var color := DIRT if cls in ["track", "trail"] else MeshBuilder.glow(ASPHALT, MeshBuilder.ASPHALT)
	_polyline_quad(ctx, Vector2(pts[k][0], pts[k][1]), Vector2(pts[k + 1][0], pts[k + 1][1]), w, ROAD_Y, color)


static func _trail(ctx: Ctx, i: int, k: int) -> void:
	var pts: Array = ctx.country.trails[i].pts
	_polyline_quad(ctx, Vector2(pts[k][0], pts[k][1]), Vector2(pts[k + 1][0], pts[k + 1][1]), 3.5, ROAD_Y, DIRT)


# --- Lots --------------------------------------------------------------------------

static func _lot(ctx: Ctx, i: int) -> void:
	var c = ctx.country
	var l: Array = c.lots[i]
	var kind: String = c.kinds[int(l[5])]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([c.seed_value, "lot", i])
	ctx.mb.xform = Transform3D(Basis(Vector3.UP, float(l[2])), Vector3(l[0], 0.0, l[1]))
	var local: Array = []
	var v0: int = ctx.mb.verts.size()
	var o0 := ctx.out.size()
	Kit.reach = l[9] if l.size() > 9 else [0.0, 0.0, 0.0]
	Kit.wealth = int(l[10]) if l.size() > 10 else -1
	Kit.route_step = 1.0 if ctx.hill else 0.0
	Kit.route_out_verts.clear()
	Kit.live_cars = str(l[7]) in LIVE_CAR_ZONES
	Kit.build(kind, ctx.mb, local, Vector2(l[3], l[4]), rng, l.size() > 8 and int(l[8]) >= 0 and c.plot_types[int(c.plots[int(l[8])][5])] == "estate")
	Kit.live_cars = false
	Kit.route_step = 0.0
	# Home cars to park live (Kit.live_cars), on the lot's pad on the hills.
	var cols: Array = []
	var y := Terrain.height(float(l[0]), float(l[1])) if ctx.hill else 0.0
	var k := 0
	for e in local:
		if e is Dictionary:
			var p: Vector3 = ctx.mb.xform * e.park
			ctx.parks.append(["%d:%d" % [i, k], Vector3(p.x, y, p.z), float(l[2]) + e.yaw])
			k += 1
		else:
			cols.append(e)
	local = cols
	_done(ctx, local, ctx.out)
	ctx.buildings += 1
	# The letters stand on the slope as it is; everything else on its pad.
	if ctx.hill and kind != "hill_letters":
		_rigid(ctx, v0, o0, Vector2(l[0], l[1]))
		_bend_routes(ctx, l)
	Kit.route_out_verts.clear()
	Kit.reach = [0.0, 0.0, 0.0]
	Kit.wealth = -1


## A hill lot's routes past its front: from the pad's height at the front
## to the ground's (the draped road's) at the road edge, the reach there
## less the tuck out (Kit.reach still holds the lot's).
static func _bend_routes(ctx: Ctx, l: Array) -> void:
	if Kit.route_out_verts.is_empty():
		return
	var pad := Terrain.height(float(l[0]), float(l[1]))
	if pad <= 0.0:
		return  # not lifted as a pad (_rigid): the drape bends it already
	var to_local: Transform3D = Transform3D(Basis(Vector3.UP, float(l[2])), Vector3(l[0], 0.0, l[1])).affine_inverse()
	var front := -float(l[4]) * 0.5
	for r: Vector2i in Kit.route_out_verts:
		for i in range(r.x, r.y):
			var v: Vector3 = ctx.mb.verts[i]
			var lv := to_local * v
			var run := maxf(Kit._reach_at(lv.x, float(l[3])) - Kit.ROUTE_TUCK, 0.5)
			var t := clampf((front - lv.z) / run, 0.0, 1.0)
			ctx.mb.verts[i] = v + Vector3(0.0, lerpf(pad, Terrain.height(v.x, v.z), t), 0.0)
		ctx.fixed.append([r.x, r.y])


## The grounds of a plot: estate gardens, a cluster's yard, a farmyard or
## a field (its houses and sheds are lots of their own).
static func _plot(ctx: Ctx, i: int) -> void:
	var c = ctx.country
	var p: Array = c.plots[i]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([c.seed_value, "plot", i])
	var base := Transform3D(Basis(Vector3.UP, float(p[2])), Vector3(p[0], 0.0, p[1]))
	var local: Array = []
	var v0: int = ctx.mb.verts.size()
	var o0 := ctx.out.size()
	for part: Array in p[6]:
		ctx.mb.xform = base
		Grounds.draw(c.part_kinds[int(part[0])], part, c.tree_kinds, ctx.mb, local, rng)
	ctx.mb.xform = base
	_done(ctx, local, ctx.out)
	if ctx.hill:
		_rigid(ctx, v0, o0, Vector2(p[0], p[1]))


## Marks what was just built (from vertex v0 and collider o0) to be lifted
## as one piece to the pad's height at `at`.
static func _rigid(ctx: Ctx, v0: int, o0: int, at: Vector2) -> void:
	var h := Terrain.height(at.x, at.y)
	if h > 0.0:
		ctx.rigid.append([v0, ctx.mb.verts.size(), o0, ctx.out.size(), h])


# --- Walls and barricades --------------------------------------------------------------

## A bank (0), the coast (1) or the play area's edge (2): banks and the
## coast drop to the water behind a low stone edge, the edge is a tall
## chain-link fence. All three are tall invisible walls for cars and people.
static func _wall(ctx: Ctx, w: Array) -> void:
	var a := Vector2(w[0], w[1])
	var b := Vector2(w[2], w[3])
	if a.distance_to(b) < 0.2:
		return
	var kind := int(w[4])
	var mb = ctx.mb
	if kind == 2:
		Props.fence(mb, [], _v3(a, GROUND_Y), _v3(b, GROUND_Y), CHAIN, 2.2)
	else:
		var face := BANK if kind == 0 else SEAWALL.darkened(0.25)
		var top := ROAD_Y + (0.35 if kind == 0 else 0.5)
		var d := b - a
		var n := Vector3(-d.y, 0, d.x).normalized()
		for s in [1.0, -1.0]:
			mb.quad(_v3(a, BANK_BOTTOM), _v3(b, BANK_BOTTOM), _v3(b, GROUND_Y), _v3(a, GROUND_Y), n * s, face)
		mb.xform = _frame(a, b)
		mb.box(Vector3(d.length() * 0.5, top * 0.5, 0), Vector3(d.length() + 0.3, top - GROUND_Y, 0.6), MeshBuilder.glow(STONE if kind == 0 else SEAWALL, MeshBuilder.CONCRETE))
		mb.xform = Transform3D.IDENTITY
	ctx.out.append(_seg_box(a, b, GROUND_Y, WALL_HEIGHT, 1.0))


## Storm closure where a road leaves the play area: jersey barriers across
## the road, striped boards and amber blinkers.
static func _barricade(ctx: Ctx, bar: Array) -> void:
	var p := Vector2(bar[0], bar[1])
	var d := Vector2(bar[2], bar[3]).normalized()
	var width: float = float(bar[4]) + 4.0
	var across := Vector2(-d.y, d.x)
	var mb = ctx.mb
	mb.xform = Transform3D(Basis(Vector3.UP, atan2(-across.y, across.x)), _v3(p, ROAD_Y))
	var count := ceili(width / 3.2)
	for i in count:
		var x := -width * 0.5 + (i + 0.5) * width / count
		mb.box(Vector3(x, 0.25, 0), Vector3(3.0, 0.5, 0.7), MeshBuilder.glow(CONCRETE, MeshBuilder.CONCRETE))
		mb.box(Vector3(x, 0.7, 0), Vector3(3.0, 0.4, 0.3), MeshBuilder.glow(CONCRETE, MeshBuilder.CONCRETE))
	var boards := maxi(2, int(width / 5.0))
	for i in boards:
		var x := -width * 0.5 + (i + 0.5) * width / boards
		for leg in [-0.9, 0.9]:
			mb.box(Vector3(x + leg, 0.7, -1.3), Vector3(0.1, 1.4, 0.1), Color(0.85, 0.85, 0.82))
		for row in 2:
			for s in 4:
				var col := ORANGE if (s + row) % 2 == 0 else Color(0.95, 0.95, 0.92)
				mb.box(Vector3(x - 0.75 + s * 0.5, 0.85 + row * 0.4, -1.3), Vector3(0.5, 0.25, 0.06), col)
		mb.box(Vector3(x, 1.75, -1.3), Vector3(0.22, 0.14, 0.22), MeshBuilder.glow(Color(1.0, 0.7, 0.2), MeshBuilder.GLOW_LAMP))
		Props._pool(mb, ctx.glow, Vector3(x, 0.05, -1.3), 3.0, Color(0.5, 0.3, 0.05))
	mb.xform = Transform3D.IDENTITY
	ctx.out.append([_v3(p, 1.5), Vector3(width, 3.0, 1.2), atan2(-across.y, across.x)])


# --- Rail ---------------------------------------------------------------------------

static func _rail(ctx: Ctx, i: int, k: int) -> void:
	var c = ctx.country
	var line: Dictionary = c.rails[i]
	var pts: Array = line.pts
	var a := Vector2(pts[k][0], pts[k][1])
	var b := Vector2(pts[k + 1][0], pts[k + 1][1])
	var length := a.distance_to(b)
	if length < 0.3:
		return
	var mb = ctx.mb
	var kind: String = line.kind
	if kind == "metro":
		# Elevated guideway on concrete columns (kept off the roads).
		mb.xform = _frame(a, b)
		mb.box(Vector3(length * 0.5, 7.4, 0), Vector3(length + 0.1, 1.0, 4.2), MeshBuilder.glow(CONCRETE, MeshBuilder.CONCRETE))
		mb.box(Vector3(length * 0.5, 8.1, 0), Vector3(length + 0.1, 0.4, 0.3), CONCRETE.darkened(0.1))
		mb.xform = Transform3D.IDENTITY
		if k % 2 == 0 and c.road_distance(a, 40.0) > 1.5:
			mb.cylinder(_v3(a, GROUND_Y), 0.7, 6.95, CONCRETE.darkened(0.1), 8)
			ctx.out.append([_v3(a, 3.5), Vector3(1.4, 7.0, 1.4), 0.0])
		return
	var on_road: bool = c.road_distance((a + b) * 0.5, 40.0) < 2.0
	var building := String(line.name).contains("being built")
	var top := ROAD_Y + 0.02 if on_road else 0.25
	if not on_road:
		_polyline_quad(ctx, a, b, 4.0 if kind == "rail" else 3.2, top, MeshBuilder.glow(BALLAST, MeshBuilder.CONCRETE))
	if building:
		if k % 5 == 0:
			# Stacked sleepers and rails waiting to be laid.
			mb.xform = _frame(a, b, top)
			for row in 3:
				mb.box(Vector3(length * 0.5, 0.15 + row * 0.25, 0), Vector3(2.6, 0.22, 2.0 - row * 0.3), SLEEPER)
			mb.xform = Transform3D.IDENTITY
		return
	mb.xform = _frame(a, b, top)
	if not on_road and kind == "rail":
		var s := 0.6
		while s < length:
			mb.box(Vector3(s, 0.04, 0), Vector3(0.24, 0.08, 2.6), SLEEPER)
			s += 1.6
	for z in [-0.72, 0.72]:
		mb.box(Vector3(length * 0.5, 0.1, z), Vector3(length + 0.05, 0.12, 0.1), MeshBuilder.glow(STEEL, MeshBuilder.METAL))
	mb.xform = Transform3D.IDENTITY


# --- Fields, ponds and trees ------------------------------------------------------------

## Ponds and reeds in the bayou, on a POND_GRID grid where the ground is
## clear. Fields and vines are plots (build_country.py field_plots).
static func _ponds(ctx: Ctx) -> void:
	var n := int(ctx.rect.size.x / POND_GRID)
	for gx in n:
		for gy in n:
			var cpt := ctx.rect.position + Vector2(gx + 0.5, gy + 0.5) * POND_GRID
			var zone := _zone_at(ctx, cpt)
			var roll := ctx.rng.randf()
			if zone == "bayou" or zone == "bayou_town":
				if roll < (0.35 if zone == "bayou" else 0.12):
					_pond(ctx, cpt + Vector2(ctx.rng.randf_range(-5, 5), ctx.rng.randf_range(-5, 5)))


static func _pond(ctx: Ctx, cpt: Vector2) -> void:
	var r := ctx.rng.randf_range(4.0, 8.0)
	if _zone_at(ctx, cpt) == "" or not _clear(ctx, cpt, r + 1.0):
		return
	var poly := PackedVector2Array()
	var sides := 12
	for i in sides:
		var a := TAU * i / sides
		poly.append(cpt + Vector2(cos(a), sin(a)) * r * ctx.rng.randf_range(0.75, 1.1))
	ctx.mb.flat(_cw(poly), GROUND_Y + 0.01, MeshBuilder.glow(POND, MeshBuilder.GLOSS))
	for i in 8:
		var a := TAU * i / 8.0 + ctx.rng.randf() * 0.4
		Props.grass(ctx.mb, _v3(cpt + Vector2(cos(a), sin(a)) * r * 1.05, GROUND_Y), ctx.rng.randf_range(0.8, 1.4), ctx.rng.randi())


static func _trees(ctx: Ctx) -> void:
	var n := int(ctx.rect.size.x / TREE_GRID)
	var count := 0
	for gx in n:
		for gy in n:
			if count >= MAX_TREES:
				return
			var p := ctx.rect.position + Vector2(gx + ctx.rng.randf(), gy + ctx.rng.randf()) * TREE_GRID
			var roll := ctx.rng.randf()
			var zone := _zone_at(ctx, p)
			if zone == "" or not TREES.has(zone):
				continue
			var spacing: float = TREES[zone][0]
			if roll > (TREE_GRID / spacing) * (TREE_GRID / spacing):
				continue
			var kind: String = TREES[zone][1]
			if kind == "palm" and zone == "eastside" and ctx.rng.randf() < 0.5:
				kind = "round"
			elif kind == "chaparral" and ctx.rng.randf() < 0.18:
				kind = "round" # a live oak among the scrub
			if not _clear(ctx, p, 2.5 if kind != "shrub" else 1.0):
				continue
			_tree(ctx, _v3(p, GROUND_Y), kind)
			count += 1


static func _tree(ctx: Ctx, p: Vector3, kind: String) -> void:
	var mb = ctx.mb
	var rng := ctx.rng
	var seed := rng.randi()
	match kind:
		"palm":
			Props.palm(mb, ctx.props, p, rng)
			return
		"shrub":
			mb.clump(p + Vector3(0, 0.5, 0), Vector3(1.0, 0.6, 1.0) * rng.randf_range(0.7, 1.3), Props._leaf(Color(0.42, 0.45, 0.28)), seed, 5, 3)
			return
		"chaparral":
			# Sage and chamise: low, wide, dusty olive clumps.
			var leaf := Props._leaf(Color(0.33, 0.38, 0.22).lerp(Color(0.46, 0.47, 0.32), rng.randf()))
			var r := rng.randf_range(1.6, 3.0)
			mb.clump(p + Vector3(0, 0.7, 0), Vector3(r, 0.9, r * rng.randf_range(0.7, 1.0)), leaf, seed, 6, 3)
			if rng.randf() < 0.5:
				mb.clump(p + Vector3(r * 0.8, 0.5, rng.randf_range(-1.0, 1.0)), Vector3(r * 0.6, 0.6, r * 0.6), leaf.darkened(0.1), seed + 1, 5, 3)
			return
		"cypress":
			var h := rng.randf_range(7.0, 11.0)
			mb.cylinder(p, 0.45, 1.0, BARK, 6)
			mb.cylinder(p + Vector3(0, 1.0, 0), 0.25, h * 0.6, BARK, 5)
			var leaf := Props._leaf(Color(0.3, 0.4, 0.2).lerp(Color(0.38, 0.44, 0.24), rng.randf()))
			mb.clump(p + Vector3(0, h * 0.7, 0), Vector3(1.8, h * 0.32, 1.8), leaf, seed, 6, 4)
			mb.clump(p + Vector3(rng.randf_range(-0.8, 0.8), h * 0.45, rng.randf_range(-0.8, 0.8)), Vector3(1.4, 1.0, 1.4), leaf.darkened(0.08), seed + 1, 5, 3)
		"pine":
			var h := rng.randf_range(8.0, 13.0)
			mb.cylinder(p, 0.25, h * 0.5, BARK, 5)
			var leaf := Props._leaf(Color(0.2, 0.32, 0.2).lerp(Color(0.26, 0.36, 0.22), rng.randf()))
			for i in 3:
				var t := 0.4 + i * 0.2
				mb.clump(p + Vector3(0, h * t, 0), Vector3(2.4 - i * 0.6, 1.3, 2.4 - i * 0.6), leaf.lightened(i * 0.04), seed + i, 6, 3)
		_:
			var h := rng.randf_range(5.0, 8.0)
			var r := rng.randf_range(2.2, 3.4)
			mb.cylinder(p, 0.24, h * 0.55, BARK, 5)
			var leaf := Props._leaf(Color(0.3, 0.44, 0.22).lerp(Color(0.42, 0.5, 0.24), rng.randf()))
			mb.clump(p + Vector3(0, h * 0.7, 0), Vector3(r, r * 0.75, r), leaf, seed, 7, 4)
	ctx.props.append([p + Vector3(0, 1.5, 0), Vector3(0.5, 3.0, 0.5), 0.0])
