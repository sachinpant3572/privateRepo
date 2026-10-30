extends Node3D
## Heliports (#82): concrete aprons with H pads, edge lights and parked
## helicopters, placed from res://data/heliports.json (local metres, as in
## city.gd) on open ground. `problems` says why a placement is not clear
## (a block, road, lot, water...): the test checks every pad with it, so a
## change to the city or the country that covers a pad shows up there.

const Helicopter = preload("res://scripts/helicopter.gd")
const HeliKit = preload("res://scripts/kits/heli_kit.gd")
const MeshBuilder = preload("res://scripts/mesh_builder.gd")
const Terrain = preload("res://scripts/terrain.gd")
const Tiles = preload("res://scripts/country_tiles.gd")

const DATA_PATH := "res://data/heliports.json"
## Metres of open ground kept round an apron (and checked).
const MARGIN := 3.0
## Highest and most uneven ground an apron may sit on (metres).
const MAX_HEIGHT := 0.6
const MAX_SPREAD := 0.5
## A drivable road must come this close to the apron's edge (metres).
const REACH := 45.0
const APRON := Color(0.5, 0.5, 0.49)
const PAD := Color(0.36, 0.37, 0.38)
const MARK := Color(0.95, 0.95, 0.92)
const RING := Color(0.98, 0.78, 0.1)
const LIGHT := Color(0.3, 1.0, 0.45)

var city
## [{id, name, pos (Vector3), yaw, size (Vector2), pads: [Vector3 world]}]
var ports: Array = []
## The helicopters parked here at the start (they stay in the world once flown).
var helis: Array = []


## The rows of the data file: {id, name, pos [x, z], yaw, size [w, d],
## pads [[x, z, kind]...]} (pads in the apron's frame, x across).
static func rows() -> Array:
	var d = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return d.heliports if d is Dictionary and d.get("heliports") is Array else []


## Pad markings: the touchdown circle, its yellow ring and the H.
const PAD_R := 7.0
const RING_R := 6.2
const ORANGE := Color(0.95, 0.45, 0.1)
## Edge lights: one every LIGHT_STEP metres round the apron.
const LIGHT_STEP := 5.8

var _glow: Array = []


## The aprons (and MARGIN round them) for country_tiles.gd to keep bare:
## [centre, yaw, half size] each.
static func clearings() -> Array:
	var out: Array = []
	for row in rows():
		out.append([Vector2(row.pos[0], row.pos[1]), float(row.yaw), Vector2(row.size[0], row.size[1]) * 0.5 + Vector2.ONE * MARGIN])
	return out


## Builds every heliport of the data file, with its parked helicopters
## unless `parked` is false.
func build(c, parked := true) -> void:
	city = c
	Helicopter.decks = []
	for row in rows():
		_build_port(row, parked)


func set_glow_visible(on: bool) -> void:
	for g in _glow:
		g.visible = on


func _build_port(row: Dictionary, parked: bool) -> void:
	var centre := Vector2(row.pos[0], row.pos[1])
	var yaw := float(row.yaw)
	var half := Vector2(float(row.size[0]), float(row.size[1])) * 0.5
	# The slab's top sits just over the highest ground under it (no
	# collider: people walk on the ground, a few centimetres under it).
	var top := -INF
	var low := INF
	var x := -half.x
	while x <= half.x + 0.01:
		var z := -half.y
		while z <= half.y + 0.01:
			var p := to_world(row, Vector2(x, z))
			var g := Terrain.height(p.x, p.y) - Terrain.drop(p.x, p.y)
			top = maxf(top, g)
			low = minf(low, g)
			z += 2.0
		x += 2.0
	top += 0.05
	# Helicopters set down on the pads' paint (helicopter.gd _ground).
	Helicopter.decks.append([centre, yaw, half, top + 0.02])
	var root := Node3D.new()
	root.name = "Heliport_%s" % row.id
	root.position = Vector3(centre.x, top, centre.y)
	root.rotation.y = yaw
	add_child(root)
	var mb := MeshBuilder.new()
	var glow := MeshBuilder.new()
	var rect := PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)])
	mb.prism(rect, low - top - 0.3, 0.0, MeshBuilder.glow(APRON, MeshBuilder.CONCRETE), APRON.darkened(0.25))
	# A white line round the edge, inset.
	var e := half - Vector2.ONE * 0.9
	var inset := [Vector2(-e.x, -e.y), Vector2(e.x, -e.y), Vector2(e.x, e.y), Vector2(-e.x, e.y)]
	for i in 4:
		_strip(mb, inset[i], inset[(i + 1) % 4], 0.25, 0.02, MARK)
	var pads: Array = []
	for pad in row.pads:
		var at := Vector2(float(pad[0]), float(pad[1]))
		pads.append(at)
		_pad(mb, at)
	# Green edge lights round the apron, glowing after dark.
	var lamp := MeshBuilder.glow(LIGHT, MeshBuilder.GLOW_LAMP)
	var corners := [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]
	for i in 4:
		var a: Vector2 = corners[i] * 0.985
		var b: Vector2 = corners[(i + 1) % 4] * 0.985
		var n := maxi(1, roundi(a.distance_to(b) / LIGHT_STEP))
		for k in n:
			var q := a.lerp(b, float(k) / n)
			mb.box(Vector3(q.x, 0.08, q.y), Vector3(0.22, 0.16, 0.22), APRON.darkened(0.4))
			mb.box(Vector3(q.x, 0.24, q.y), Vector3(0.16, 0.16, 0.16), lamp)
			glow.light_pool(Vector3(q.x, 0.03, q.y), Vector2(1.6, 1.6), LIGHT.darkened(0.45), 8)
	# Yellow-white lights round each touchdown circle.
	var ring_lamp := MeshBuilder.glow(Color(1.0, 0.9, 0.55), MeshBuilder.GLOW_LAMP)
	for at in pads:
		for k in 8:
			var q: Vector2 = at + Vector2.from_angle(TAU * k / 8.0 + PI / 8.0) * (PAD_R + 0.4)
			mb.box(Vector3(q.x, 0.1, q.y), Vector3(0.18, 0.2, 0.18), ring_lamp)
			glow.light_pool(Vector3(q.x, 0.03, q.y), Vector2(1.2, 1.2), Color(0.55, 0.5, 0.3), 8)
	# The windsock on its mast in a corner.
	var w := Vector2(-half.x + 1.6, half.y - 1.6)
	mb.cylinder(Vector3(w.x, 0.0, w.y), 0.07, 4.6, Color(0.85, 0.85, 0.82), 6)
	mb.limb(Vector3(w.x, 4.4, w.y), Vector3(w.x + 2.4, 4.1, w.y - 0.6), 0.36, 0.16, ORANGE, 8)
	mb.limb(Vector3(w.x + 0.8, 4.3, w.y - 0.2), Vector3(w.x + 1.6, 4.2, w.y - 0.4), 0.33, 0.25, MARK, 8)
	var inst := mb.make_instance()
	inst.name = "Apron"
	inst.material_override = MeshBuilder.cutaway_material()
	root.add_child(inst)
	var lights := glow.make_instance()
	lights.name = "Glow"
	lights.material_override = MeshBuilder.glow_material()
	lights.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lights.visible = city != null and city.get("glow_visible") == true
	root.add_child(lights)
	_glow.append(lights)
	var world_pads: Array = []
	for at in pads:
		var wp := to_world(row, at)
		world_pads.append(Vector3(wp.x, top, wp.y))
	ports.append({"id": row.id, "name": row.name, "pos": Vector3(centre.x, top, centre.y), "yaw": yaw, "size": half * 2.0, "pads": world_pads})
	if not parked:
		return
	var civil := 0
	for i in row.pads.size():
		var kind := String(row.pads[i][2]) if row.pads[i].size() > 2 else "heli"
		var h = Helicopter.new()
		h.kind = kind
		if kind != "police_heli":
			h.body_color = HeliKit.PAINTS[(civil + absi(hash(row.id))) % HeliKit.PAINTS.size()]
			civil += 1
		h.position = world_pads[i]
		# Nose to the apron's far side, parked in a row.
		h.rotation.y = yaw
		add_child(h)
		helis.append(h)


## A touchdown pad at `at` (apron frame): the darker circle, the yellow
## ring and the H.
func _pad(mb, at: Vector2) -> void:
	var circle := PackedVector2Array()
	for k in 32:
		circle.append(at + Vector2.from_angle(-TAU * k / 32.0) * PAD_R)
	mb.flat(circle, 0.02, MeshBuilder.glow(PAD, MeshBuilder.CONCRETE))
	var y := 0.04
	for k in 32:
		var a0 := Vector2.from_angle(TAU * k / 32.0)
		var a1 := Vector2.from_angle(TAU * (k + 1) / 32.0)
		var r1 := RING_R - 0.45
		mb.quad(Vector3(at.x + a0.x * RING_R, y, at.y + a0.y * RING_R), Vector3(at.x + a0.x * r1, y, at.y + a0.y * r1),
			Vector3(at.x + a1.x * r1, y, at.y + a1.y * r1), Vector3(at.x + a1.x * RING_R, y, at.y + a1.y * RING_R), Vector3.UP, RING)
	# The H, its bars along the apron's depth.
	for sx in [-1.0, 1.0]:
		mb.box(Vector3(at.x + sx * 1.3, 0.05, at.y), Vector3(0.6, 0.02, 4.2), MARK)
	mb.box(Vector3(at.x, 0.05, at.y), Vector3(2.0, 0.02, 0.6), MARK)


## A painted line from a to b (apron frame), `w` wide, `y` up.
static func _strip(mb, a: Vector2, b: Vector2, w: float, y: float, color: Color) -> void:
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x) * w * 0.5
	mb.quad(Vector3(a.x + n.x, y, a.y + n.y), Vector3(b.x + n.x, y, b.y + n.y), Vector3(b.x - n.x, y, b.y - n.y), Vector3(a.x - n.x, y, a.y - n.y), Vector3.UP, color)


## The world point of a pad (or any point in the apron's frame).
static func to_world(row: Dictionary, local: Vector2) -> Vector2:
	return Vector2(row.pos[0], row.pos[1]) + local.rotated(-float(row.yaw))


## Why the apron of `row` is not on clear, open, flat land reachable by road:
## a list of reasons ("" -free when clear). Samples the apron and MARGIN round
## it every 2 m against the street plan (blocks, streets, the river), the
## country (play area, roads, lots, plots, driveways, walls, rails, trails,
## far roads, canals) and the ground's height.
static func problems(c, row: Dictionary) -> Array:
	var out: Array = []
	var plan = c.plan
	var country = c.country
	var half := Vector2(float(row.size[0]), float(row.size[1])) * 0.5 + Vector2.ONE * MARGIN
	var lo := INF
	var hi := -INF
	var reach := INF
	var x := -half.x
	while x <= half.x + 0.01:
		var z := -half.y
		while z <= half.y + 0.01:
			var p := to_world(row, Vector2(x, z))
			var why := _point_problem(c, p)
			if why != "" and not out.has(why):
				out.append(why)
			var h := Terrain.height(p.x, p.y)
			lo = minf(lo, h)
			hi = maxf(hi, h)
			z += 2.0
		x += 2.0
	if hi > MAX_HEIGHT:
		out.append("on a hill (%.1f m)" % hi)
	if hi - lo > MAX_SPREAD:
		out.append("uneven ground (%.1f m)" % (hi - lo))
	# Reachable: a country road (or a street) near the apron's edge.
	var centre := to_world(row, Vector2.ZERO)
	reach = country.road_distance(centre, 120.0) if country else INF
	for n in plan.nodes_near(centre, 120.0):
		for e in plan.edges_of(n):
			if plan.drivable(e):
				reach = minf(reach, _seg(centre, plan.pos(n), plan.pos(plan.other(e, n))) - plan.edge_width(e) * 0.5)
	if reach > half.length() + REACH:
		out.append("no road within reach (%.0f m)" % reach)
	return out


static func _point_problem(c, p: Vector2) -> String:
	var plan = c.plan
	var country = c.country
	if plan.is_water_point(p):
		return "in the river"
	if plan.face_of(p) >= 0:
		return "in a city block or street"
	for n in plan.nodes_near(p, 60.0):
		for e in plan.edges_of(n):
			if _seg(p, plan.pos(n), plan.pos(plan.other(e, n))) < plan.edge_width(e) * 0.5 + 1.0:
				return "on a city street"
	if country == null:
		return "outside the play area"
	if not country.in_play_area(p):
		return "outside the play area"
	if country.road_distance(p, 60.0) < 1.0:
		return "on a country road"
	var t: Dictionary = country.tiles.get(Vector2i(floori(p.x / country.tile_size), floori(p.y / country.tile_size)), {})
	if t.is_empty():
		return "off the country's ground"
	var zone := ""
	for part in t.get("g", []):
		var flat: Array = part[1]
		for k in range(0, flat.size() - 5, 6):
			if Geometry2D.point_is_inside_triangle(p, Vector2(flat[k], flat[k + 1]), Vector2(flat[k + 2], flat[k + 3]), Vector2(flat[k + 4], flat[k + 5])):
				zone = country.zones[int(part[0])]
				break
		if zone != "":
			break
	if zone == "":
		return "off the country's ground"
	if zone in ["canal", "canal_bank", "sand", "bayou", "mountain", "hillside"]:
		return "on %s ground" % zone
	for i in t.get("l", []):
		if Tiles._in_rect(p, country.lots[int(i)], 0.0):
			return "on a lot"
	for i in t.get("q", []):
		if Tiles._in_rect(p, country.plots[int(i)], 0.0):
			return "on a plot"
	for i in t.get("w", []):
		var w: Array = country.walls[int(i)]
		if _seg(p, Vector2(w[0], w[1]), Vector2(w[2], w[3])) < 3.0:
			return "by a wall (water's edge)"
	for i in t.get("p", []):
		var path: Array = country.paths[int(i)]
		if _seg(p, Vector2(path[0][0], path[0][1]), Vector2(path[1][0], path[1][1])) < 3.0:
			return "on a driveway"
	for pair in t.get("x", []):
		var pts: Array = country.rails[int(pair[0])].pts
		var k := int(pair[1])
		if _seg(p, Vector2(pts[k][0], pts[k][1]), Vector2(pts[k + 1][0], pts[k + 1][1])) < 5.0:
			return "on a railway"
	for pair in t.get("t", []):
		var pts: Array = country.trails[int(pair[0])].pts
		var k := int(pair[1])
		if _seg(p, Vector2(pts[k][0], pts[k][1]), Vector2(pts[k + 1][0], pts[k + 1][1])) < 2.5:
			return "on a trail"
	for pair in t.get("f", []):
		var f: Dictionary = country.far_roads[int(pair[0])]
		var k := int(pair[1])
		if _seg(p, Vector2(f.pts[k][0], f.pts[k][1]), Vector2(f.pts[k + 1][0], f.pts[k + 1][1])) < float(country.classes[int(f.cls)].w) * 0.5 + 1.0:
			return "on a far road"
	return ""


static func _seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))
