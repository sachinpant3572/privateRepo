extends RefCounted
## Builds one city cell: its block, the junction at its north-west corner
## and the streets running east and south from that junction. Pure data in;
## mesh and collision boxes out, so city.gd can run it on a worker thread.
##
## Blocks are the polygons of the street plan (street_plan.gd):
## - Each cell lays an asphalt base under its whole block, so junctions
##   and street edges are always covered.
## - The sidewalk slab follows the block's real shape.
## - Each street is detailed in its own frame: neutral grounds with oaks and
##   the streetcar on boulevards, pavers on Quarter streets, bollards and
##   lights on pedestrian lanes, markings, crosswalks.
## - Block contents are laid out in a frame turned to face the block's front
##   street, sized to the largest rectangle that fits its lot:
##   - Lantern Quarter: Creole townhouse rings, shops and gardens;
##   - Floodline Wards: shotgun rows, a chapel, pocket parks;
##   - Gilt District: towers, plazas and parking;
##   - Ironwharf: warehouses and container yards;
##   - landmarks.

const MeshBuilder = preload("res://scripts/mesh_builder.gd")
const Buildings = preload("res://scripts/kits/building_kit.gd")
const Props = preload("res://scripts/kits/prop_kit.gd")
const StreetPlan = preload("res://scripts/street_plan.gd")

## Road and block slabs reach down into the water so quays have walls.
const SLAB := 1.2
const KERB := 0.15

const ASPHALT := Color(0.2, 0.2, 0.23)
const PAVEMENT := Color(0.58, 0.56, 0.52)
const PAVERS := Color(0.5, 0.38, 0.32)
const MARKING := Color(0.92, 0.8, 0.3)
const WHITE_LINE := Color(0.9, 0.9, 0.88)
const GRASS := Color(0.34, 0.56, 0.28)
const PLAZA := Color(0.72, 0.69, 0.63)
const YARD := Color(0.46, 0.46, 0.45)
const MUD := Color(0.36, 0.33, 0.25)
const POND := Color(0.2, 0.3, 0.26)
const FENCE_WOOD := Color(0.62, 0.52, 0.4)
const CHAIN := Color(0.6, 0.62, 0.64)
const RAIL_WHITE := Color(0.88, 0.88, 0.86)
const MOREAU := Color(0.55, 0.2, 0.24)
const ZEBRA_STYLES := ["downtown", "quarter", "station", "tower", "police", "hospital", "park", "club"]


class Ctx:
	var city
	var plan
	var mb
	## Light pools for the additive night glow mesh.
	var glow
	var out: Array = []
	## Street furniture colliders: block movement but not the camera's view.
	var props: Array = []
	var rng := RandomNumberGenerator.new()
	## Separate stream for decoration, so adding details never reshuffles
	## the buildings.
	var deco := RandomNumberGenerator.new()
	var buildings := 0
	var cell := Vector2i.ZERO
	## Block frame: origin at the lot's centre, +Z out through the front
	## street, +X along it (left to right seen from the street).
	var frame := Transform3D.IDENTITY
	## Half size of the largest frame-aligned rectangle inside the lot.
	var hx := 17.0
	var hz := 17.0
	var lot := PackedVector2Array()
	## Which frame sides ("+x", "-x", "+z", "-z") face a street; buildings
	## don't front onto closed ones.
	var open := {"+x": true, "-x": true, "+z": true, "-z": true}


static func build(city, cell: Vector2i) -> Dictionary:
	var ctx := Ctx.new()
	ctx.city = city
	ctx.plan = city.plan
	ctx.mb = MeshBuilder.new()
	ctx.glow = MeshBuilder.new()
	ctx.cell = cell
	ctx.rng.seed = hash([city.seed_value, cell.x, cell.y])
	ctx.deco.seed = hash([city.seed_value, cell.x, cell.y, "deco"])
	var style: String = city.block_style(cell)
	_streets(ctx)
	if style == "water":
		_water_block(ctx)
	else:
		_setup_frame(ctx)
		_base(ctx)
		if city.in_window(cell):
			_land_block(ctx, style)
		else:
			_outer_block(ctx)
	return {"mesh": ctx.mb, "glow": ctx.glow, "colliders": ctx.out, "props": ctx.props, "buildings": ctx.buildings}


# --- Frames and placement ------------------------------------------------------

static func _v3(p: Vector2, y := 0.0) -> Vector3:
	return Vector3(p.x, y, p.y)


static func _setup_frame(ctx: Ctx) -> void:
	var b := ctx.cell
	ctx.lot = ctx.plan.lot(b)
	var front: Transform3D = ctx.city.front_frame(b)
	var c := Vector2.ZERO
	for p in ctx.lot:
		c += p
	c /= ctx.lot.size()
	ctx.frame = Transform3D(front.basis, _v3(c))
	var inv := ctx.frame.affine_inverse()
	var hx := INF
	var hz := INF
	for p in ctx.lot:
		var l := inv * _v3(p)
		hx = minf(hx, absf(l.x))
		hz = minf(hz, absf(l.z))
	ctx.hx = maxf(hx - 0.3, 6.0)
	ctx.hz = maxf(hz - 0.3, 6.0)
	var corners: PackedVector2Array = ctx.plan.corners(b)
	for k in 4:
		var mid := inv * _v3((corners[k] + corners[(k + 1) % 4]) * 0.5)
		var key := ("+x" if mid.x > 0 else "-x") if absf(mid.x) > absf(mid.z) else ("+z" if mid.z > 0 else "-z")
		if ctx.plan.side_class(b, k) == "closed":
			ctx.open[key] = false


## World point for a point in the block frame.
static func _w(ctx: Ctx, local: Vector3) -> Vector3:
	return ctx.frame * local


## Points the kits at `local` in the block frame, turned by `yaw` (0: front
## faces away from the street, PI: towards it, -PI/2 and PI/2: sideways).
## Returns the list the kit fills with colliders.
static func _at(ctx: Ctx, local: Vector3, yaw: float) -> Array:
	ctx.mb.xform = ctx.frame * Transform3D(Basis(Vector3.UP, yaw), local)
	return []


## Moves a kit's local colliders into the cell and resets the placement.
## `into` defaults to the building colliders.
static func _done(ctx: Ctx, local: Array, building := true, into = null) -> void:
	var x: Transform3D = ctx.mb.xform
	var yaw := atan2(-x.basis.x.z, x.basis.x.x)
	var target: Array = ctx.out if into == null else into
	for col in local:
		target.append([x * col[0], col[1], yaw + (col[2] if col.size() > 2 else 0.0)])
	ctx.mb.xform = Transform3D.IDENTITY
	if building:
		ctx.buildings += 1


static func _yaw_facing(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


## A frame-aligned rectangle of ground colour (lawns, yards, plazas).
static func _patch(ctx: Ctx, center: Vector3, size: Vector2, color: Color) -> void:
	if size.x <= 0.5 or size.y <= 0.5:
		return
	var local := _at(ctx, center, 0.0)
	ctx.mb.box(Vector3(0, KERB + 0.02, 0), Vector3(size.x, 0.04, size.y), color)
	_done(ctx, local, false)


## The whole lot in one colour (follows the block's real shape).
static func _ground(ctx: Ctx, color: Color) -> void:
	ctx.mb.flat(ctx.lot, KERB + 0.02, color)


# --- Streets -------------------------------------------------------------------

## Asphalt under the whole block (to the centre of its streets) and the
## sidewalk slab inside them.
static func _base(ctx: Ctx) -> void:
	var b := ctx.cell
	ctx.mb.prism(ctx.plan.corners(b), -SLAB, 0.0, ASPHALT)
	ctx.mb.prism(ctx.plan.inner(b), -0.3, KERB, PAVEMENT, PAVEMENT.darkened(0.25))


## The two streets this cell owns, plus quay walls and barricades.
static func _streets(ctx: Ctx) -> void:
	var city = ctx.city
	var n := ctx.cell
	for d in [Vector2i(1, 0), Vector2i(0, 1)]:
		var m: Vector2i = n + d
		if not ctx.plan.has_node(m):
			continue
		var cls: String = ctx.plan.edge_class(n, d)
		if cls == "closed":
			# A street that runs into the water ends in a railing.
			if city.node_ok(n) != city.node_ok(m):
				var land: Vector2i = n if city.node_ok(n) else m
				var wet: Vector2i = m if land == n else n
				_road_end_wall(ctx, land, wet - land)
			continue
		_street(ctx, n, d, cls)
		_barricade(ctx, n, m)


## Setback of a street's markings from junction n: half the widest street
## crossing there.
static func _setback(ctx: Ctx, n: Vector2i, d: Vector2i) -> float:
	var perp := Vector2i(d.y, d.x)
	return maxf(ctx.plan.edge_width(n, perp), ctx.plan.edge_width(n, -perp)) * 0.5 + 0.5


static func _street(ctx: Ctx, n: Vector2i, d: Vector2i, cls: String) -> void:
	var city = ctx.city
	var mb = ctx.mb
	var a: Vector3 = city.node_pos(n)
	var e: Vector3 = city.node_pos(n + d)
	var length := a.distance_to(e)
	var w: float = StreetPlan.CLASSES[cls].width
	var s0 := _setback(ctx, n, d)
	var s1 := _setback(ctx, n + d, -d)
	var run := length - s0 - s1
	if run < 2.0:
		return
	var dir := (e - a) / length
	# Street frame: x along the street from a, z across it.
	var frame := Transform3D(Basis(Vector3.UP, atan2(-dir.z, dir.x)), a)
	mb.xform = frame
	var mid := s0 + run * 0.5
	var style: String = city.district_at((a + e) * 0.5).get("style", "quarter")
	match cls:
		"boulevard":
			# Neutral ground: a raised lawn with oaks (or palms downtown) and,
			# on the Lantern Line, the streetcar.
			var line: int = city.rail_on(n, n + d)
			mb.box(Vector3(mid, 0.12, 0), Vector3(run - 3.0, 0.24, 6.4), PAVEMENT.darkened(0.1))
			mb.box(Vector3(mid, 0.25, 0), Vector3(run - 3.4, 0.02, 5.6), GRASS)
			for side in [-1.0, 1.0]:
				_dashes(mb, s0, run, side * (3.2 + (w * 0.5 - 3.2) * 0.5), WHITE_LINE)
			if line >= 0:
				Props.rails(mb, Vector3(s0, 0.26, 0), Vector3(s0 + run, 0.26, 0), city.rail_lines[line][2])
				if not city.rail_lines[line][2]:
					_tram_wires(ctx, s0, run, n == city.rail_lines[line][0] or ctx.deco.randf() < 0.15)
			var t := s0 + 4.0
			var local: Array = []
			while t < s0 + run - 4.0:
				var off := 2.2 if line >= 0 else 0.0
				for side in ([-1.0, 1.0] if line >= 0 else [0.0]):
					if style == "downtown":
						Props.palm(mb, local, Vector3(t, 0.25, side * off), ctx.deco)
					else:
						Props.oak(mb, local, Vector3(t, 0.25, side * off), ctx.deco)
				t += 14.0
			local.append([Vector3(mid, 0.4, 0), Vector3(run - 3.0, 0.8, 6.0)])
			_done(ctx, local, false, ctx.props)
			mb.xform = frame
		"avenue", "river":
			for z in [-0.12, 0.12]:
				mb.box(Vector3(mid, 0.01, z), Vector3(run, 0.02, 0.12), MARKING)
			for side in [-1.0, 1.0]:
				_dashes(mb, s0, run, side * w * 0.25, WHITE_LINE)
		"street":
			_dashes(mb, s0, run, 0.0, MARKING)
		"quarter":
			# Old pavers between the curbs, no markings.
			mb.box(Vector3(mid, 0.005, 0), Vector3(run + 1.0, 0.02, w - 0.4), PAVERS)
			for k in int(run / 3.0):
				mb.box(Vector3(s0 + 1.5 + k * 3.0, 0.012, 0), Vector3(0.06, 0.02, w - 0.6), PAVERS.darkened(0.12))
		"lane":
			# Pedestrian lane: paved over, bollards at each end, lights strung
			# across.
			mb.box(Vector3(length * 0.5, 0.08, 0), Vector3(length, 0.16, w), PAVERS.lightened(0.1))
			var local: Array = []
			for x in [s0 - 0.5, length - s1 + 0.5]:
				for z in [-2.0, 0.0, 2.0]:
					Props.bollard(mb, local, Vector3(x, 0.1, z))
			_done(ctx, local, false, ctx.props)
			mb.xform = frame
			var k := 0.0
			while k < run - 4.0:
				Props.festoon(mb, Vector3(s0 + 2.0 + k, 4.4, -w * 0.5 - 1.2), Vector3(s0 + 2.0 + k, 4.4, w * 0.5 + 1.2), ctx.deco)
				k += 15.0
	if cls != "lane":
		for k in ctx.deco.randi_range(0, 2):
			Props.road_mark(mb, Vector3(ctx.deco.randf_range(s0 + 2.0, s0 + run - 2.0), 0.0, ctx.deco.randf_range(-w * 0.3, w * 0.3)), Vector3.RIGHT, ctx.deco)
	if style in ZEBRA_STYLES and cls != "lane":
		for x in [s0 + 1.6, s0 + run - 1.6]:
			Props.crosswalk(mb, Vector3(x, 0.0, 0), Vector3.RIGHT, w - 1.5)
	mb.xform = Transform3D.IDENTITY


## Dashed line along the street frame's x axis at offset z.
static func _dashes(mb, s0: float, run: float, z: float, color: Color) -> void:
	var t := s0 + 2.0
	while t < s0 + run - 3.0:
		mb.box(Vector3(t + 1.5, 0.01, z), Vector3(3.0, 0.02, 0.18), color)
		t += 6.0


## Overhead wires above the streetcar and, now and then, a streetcar at a
## stop (traffic passes either side of the neutral ground).
static func _tram_wires(ctx: Ctx, s0: float, run: float, car: bool) -> void:
	var mb = ctx.mb
	for side in [-1.4, 1.4]:
		mb.box(Vector3(s0 + run * 0.5, 5.6, side), Vector3(run + 2.0, 0.05, 0.05), Color(0.08, 0.08, 0.08))
	var t := s0 + 3.0
	var local: Array = []
	while t < s0 + run:
		mb.cylinder(Vector3(t, 0.25, 2.7), 0.1, 5.6, Color(0.25, 0.27, 0.25), 4)
		mb.box(Vector3(t, 5.7, 0.7), Vector3(0.1, 0.1, 4.2), Color(0.25, 0.27, 0.25))
		local.append([Vector3(t, 2.0, 2.7), Vector3(0.3, 4.0, 0.3)])
		t += 16.0
	if car:
		var saved: Transform3D = mb.xform
		mb.xform = saved * Transform3D(Basis(Vector3.UP, PI / 2), Vector3(s0 + run * 0.5, 0.25, 0))
		var tram: Array = []
		Props.streetcar(mb, tram, Vector3.ZERO)
		var x: Transform3D = mb.xform
		for col in tram:
			local.append([saved.affine_inverse() * (x * col[0]), col[1], PI / 2])
		mb.xform = saved
	var yaw := atan2(-mb.xform.basis.x.z, mb.xform.basis.x.x)
	for col in local:
		ctx.props.append([mb.xform * col[0], col[1], yaw + (col[2] if col.size() > 2 else 0.0)])


## Striped "road closed" boards where a street leaves the playable window.
static func _barricade(ctx: Ctx, n: Vector2i, m: Vector2i) -> void:
	var a_in := _node_in_window(ctx.city, n)
	if a_in == _node_in_window(ctx.city, m):
		return
	var inside := n if a_in else m
	var outside := m if a_in else n
	var p: Vector3 = ctx.city.node_pos(inside)
	var q: Vector3 = ctx.city.node_pos(outside)
	var dir := (q - p).normalized()
	ctx.mb.xform = Transform3D(Basis(Vector3.UP, atan2(-dir.z, dir.x)), p + dir * 8.5)
	for k in 3:
		var z := -4.0 + k * 4.0
		ctx.mb.box(Vector3(0, 1.0, z), Vector3(0.2, 0.3, 2.8), Color(0.95, 0.5, 0.1))
		ctx.mb.box(Vector3(0, 0.65, z), Vector3(0.2, 0.3, 2.8), Color(0.95, 0.95, 0.92))
		for s in [-1.2, 1.2]:
			ctx.mb.box(Vector3(0, 0.45, z + s), Vector3(0.12, 0.9, 0.12), Color(0.3, 0.3, 0.3))
	ctx.mb.xform = Transform3D.IDENTITY


static func _node_in_window(city, n: Vector2i) -> bool:
	return n.x >= 0 and n.y >= 0 and n.x <= city.blocks.x and n.y <= city.blocks.y


## Railing and wall across a street that runs into the river.
static func _road_end_wall(ctx: Ctx, land: Vector2i, d: Vector2i) -> void:
	var p: Vector3 = ctx.city.node_pos(land)
	var q: Vector3 = ctx.city.node_pos(land + d)
	var dir := (q - p).normalized()
	var across := Vector3(-dir.z, 0, dir.x)
	var at := p + dir * 7.5
	Props.fence(ctx.mb, [], at - across * 7.0, at + across * 7.0, RAIL_WHITE, 0.9)
	ctx.out.append([at + Vector3(0, 2.0, 0), Vector3(14.0, 4.0, 1.0), atan2(-across.z, across.x)])


# --- Water -----------------------------------------------------------------------

## Open water: the halves of any streets along it (with railings and quay
## walls), and the odd moored boat.
static func _water_block(ctx: Ctx) -> void:
	var city = ctx.city
	var plan = ctx.plan
	var b := ctx.cell
	var c: PackedVector2Array = plan.corners(b)
	var center := (c[0] + c[1] + c[2] + c[3]) * 0.25
	for k in 4:
		var cls: String = plan.side_class(b, k)
		if cls == "closed":
			continue
		var a := c[k]
		var e := c[(k + 1) % 4]
		var dir := (e - a).normalized()
		var inward := Vector2(-dir.y, dir.x)
		var w: float = StreetPlan.CLASSES[cls].width * 0.5 + 1.2
		var strip := PackedVector2Array([a, e, e + inward * w, a + inward * w])
		ctx.mb.prism(strip, -SLAB, 0.0, ASPHALT, PAVEMENT.darkened(0.3))
		var r0 := _v3(a + inward * (w - 0.3))
		var r1 := _v3(e + inward * (w - 0.3))
		Props.fence(ctx.mb, [], r0, r1, RAIL_WHITE, 0.9)
		var mid := (r0 + r1) * 0.5
		ctx.out.append([mid + Vector3(0, 2.0, 0), Vector3(r0.distance_to(r1) + 1.0, 4.0, 0.8), atan2(-(r1 - r0).z, (r1 - r0).x)])
	if ctx.rng.randf() < 0.3:
		_boat(ctx, _v3(center) + Vector3(ctx.rng.randf_range(-8, 8), 0, ctx.rng.randf_range(-8, 8)), ctx.rng.randf() * TAU)


static func _boat(ctx: Ctx, p: Vector3, yaw: float) -> void:
	var mb = ctx.mb
	mb.xform = Transform3D(Basis(Vector3.UP, yaw), p)
	var hull := Color(0.92, 0.92, 0.9) if ctx.rng.randf() < 0.5 else Color(0.25, 0.4, 0.6)
	mb.box(Vector3(0, -0.2, 0), Vector3(2.6, 0.9, 7.0), hull)
	mb.box(Vector3(0, -0.2, -3.8), Vector3(1.6, 0.9, 1.0), hull)
	mb.box(Vector3(0, 0.3, 0.6), Vector3(2.2, 0.08, 5.4), Color(0.62, 0.45, 0.28))
	mb.box(Vector3(0, 0.95, 1.2), Vector3(1.8, 1.3, 2.2), Color(0.95, 0.95, 0.95))
	mb.box(Vector3(0, 1.2, 0.08), Vector3(1.6, 0.6, 0.06), Color(0.15, 0.22, 0.3))
	mb.xform = Transform3D.IDENTITY


# --- Land blocks -----------------------------------------------------------------

static func _land_block(ctx: Ctx, style: String) -> void:
	if style == "green":
		_liberty_green(ctx)
		_furniture(ctx, "park")
		return
	var lm: Dictionary = ctx.city.landmark_at(ctx.cell)
	match lm.get("id", ""):
		"union_station":
			_union_station(ctx)
		"aurum_tower":
			_aurum(ctx)
		"bpd_lantern":
			_single(ctx, "precinct", YARD)
		"floodline_clinic":
			_single(ctx, "clinic", PLAZA)
		"lantern_square":
			_ground(ctx, PLAZA)
			var local := _at(ctx, Vector3.ZERO, 0.0)
			Buildings.lantern_square(ctx.mb, local, Props, ctx.rng, ctx.glow)
			_done(ctx, local, false)
		"wharfside_courts":
			_ground(ctx, YARD)
			var local := _at(ctx, Vector3.ZERO, 0.0)
			Buildings.courts(ctx.mb, local, Props)
			_done(ctx, local, false)
		"blue_lantern":
			_club(ctx)
		"moreau_house":
			_wards(ctx, "moreau")
		"teo_apartment":
			_wards(ctx, "teo")
		"warehouse_9":
			_docks(ctx, 9)
		"the_pit":
			_pit(ctx)
		"streetcar_depot":
			_depot(ctx)
		"drowned_streetcar":
			_drowned(ctx)
		_:
			var roll := ctx.rng.randf()
			match style:
				"downtown":
					if roll < 0.1:
						_plaza(ctx)
					elif roll < 0.18:
						_parking(ctx)
					else:
						_downtown(ctx)
				"wards":
					if roll < 0.08:
						_pocket_park(ctx)
					elif roll < 0.14:
						_chapel(ctx)
					else:
						_wards(ctx, "")
				"docks":
					if roll < 0.12:
						_parking(ctx)
					else:
						_docks(ctx, -1)
				_:
					if roll < 0.1:
						_garden_square(ctx)
					else:
						_quarter(ctx)
	_furniture(ctx, ctx.city.district_at(ctx.city.block_center(ctx.cell)).get("style", "quarter"))
	_quays(ctx)


## Railings and walls where a block's sidewalk meets the river directly.
static func _quays(ctx: Ctx) -> void:
	var plan = ctx.plan
	var b := ctx.cell
	var dirs := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	var inner: PackedVector2Array = plan.inner(b)
	for k in 4:
		if plan.side_class(b, k) != "closed" or ctx.city.block_land(b + dirs[k]):
			continue
		var a := _v3(inner[k], KERB)
		var e := _v3(inner[(k + 1) % 4], KERB)
		Props.fence(ctx.mb, [], a, e, RAIL_WHITE, 0.9)
		ctx.out.append([(a + e) * 0.5 + Vector3(0, 2.0, 0), Vector3(a.distance_to(e) + 1.0, 4.0, 0.8), atan2(-(e - a).z, (e - a).x)])


## Lantern Quarter: a ring of Creole townhouses round a shady courtyard,
## sized to the block.
static func _quarter(ctx: Ctx) -> void:
	var rng := ctx.rng
	var hx := ctx.hx
	var hz := ctx.hz
	var depth := clampf(minf(hx, hz) * 0.6, 7.0, 10.5)
	_ground(ctx, PAVEMENT.darkened(0.05))
	_patch(ctx, Vector3.ZERO, Vector2(hx * 2 - 2 * depth, hz * 2 - 2 * depth), GRASS)
	for side in [-1.0, 1.0]:
		if not ctx.open["+z" if side > 0 else "-z"]:
			continue
		var x := -hx
		while x < hx - 0.5:
			var w := rng.randf_range(6.0, 9.0)
			if hx - x - w < 5.0:
				w = hx - x
			_townhouse(ctx, Vector3(x + w * 0.5, 0, side * (hz - depth * 0.5)), 0.0 if side < 0 else PI, w - 0.2, depth)
			x += w
	var span := hz * 2 - 2 * depth
	if span > 6.0:
		var count := maxi(1, int(span / 9.0))
		for side in [-1.0, 1.0]:
			if not ctx.open["+x" if side > 0 else "-x"]:
				continue
			for k in count:
				var z := -hz + depth + span / count * (k + 0.5)
				_townhouse(ctx, Vector3(side * (hx - depth * 0.5), 0, z), PI / 2 if side < 0 else -PI / 2, span / count - 0.2, depth)
	var local: Array = []
	ctx.mb.xform = ctx.frame
	Props.oak(ctx.mb, local, Vector3(rng.randf_range(-2, 2), KERB, rng.randf_range(-2, 2)), rng)
	if rng.randf() < 0.6 and hz - depth > 4.0:
		Props.bench(ctx.mb, local, Vector3(0, KERB, hz - depth - 2.0), PI)
	_done(ctx, local, false, ctx.props)


static func _townhouse(ctx: Ctx, pos: Vector3, yaw: float, w: float, d: float) -> void:
	var local := _at(ctx, pos + Vector3(0, KERB, 0), yaw)
	Buildings.townhouse(ctx.mb, local, w, d, ctx.rng.randi_range(2, 3), ctx.rng)
	_done(ctx, local)


## A Quarter garden square: lawn, paths, a fountain, benches and oaks.
static func _garden_square(ctx: Ctx) -> void:
	_ground(ctx, GRASS)
	var mb = ctx.mb
	var local := _at(ctx, Vector3(0, KERB, 0), 0.0)
	mb.box(Vector3(0, 0.03, 0), Vector3(ctx.hx * 2, 0.04, 2.4), PLAZA)
	mb.box(Vector3(0, 0.03, 0), Vector3(2.4, 0.04, ctx.hz * 2), PLAZA)
	mb.cylinder(Vector3(0, 0, 0), 2.4, 0.5, Buildings.STONE, 10)
	mb.cylinder(Vector3(0, 0.05, 0), 2.1, 0.5, Color(0.35, 0.6, 0.75), 10)
	local.append([Vector3(0, 0.4, 0), Vector3(4.8, 0.8, 4.8)])
	for q in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(1, 0, 1)]:
		Props.oak(mb, local, Vector3(q.x * ctx.hx * 0.55, 0, q.z * ctx.hz * 0.55), ctx.rng)
		Props.bench(mb, local, Vector3(q.x * 4.5, 0, q.z * 1.8 + q.z * 1.0), 0.0 if q.z < 0 else PI)
	_done(ctx, local, false, ctx.props)


## Floodline Wards: shotgun houses on the front and back streets, backyards
## between them. Some houses are storm-damaged, some lots empty since the
## flood. `special` places Moreau House or Teo's apartment on the front.
static func _wards(ctx: Ctx, special: String) -> void:
	var rng := ctx.rng
	var mb = ctx.mb
	var hx := ctx.hx
	var hz := ctx.hz
	_ground(ctx, GRASS.darkened(0.05))
	var slots := maxi(3, int(hx * 2 / 6.8))
	var slot_w := hx * 2 / slots
	var depth := clampf(hz - 2.5, 8.0, 14.0)
	for side in [-1.0, 1.0]:
		var yaw := 0.0 if side < 0 else PI
		if not ctx.open["+z" if side > 0 else "-z"]:
			continue
		for k in slots:
			var x := -hx + slot_w * (k + 0.5)
			var front: bool = side > 0
			if front and special == "teo" and absi(k - slots / 2) <= 1:
				if k == slots / 2:
					var local := _at(ctx, Vector3(0, KERB, hz - 6.5), PI)
					Buildings.ward_apartment(mb, local, minf(15.0, hx * 2 - 4.0), 12.0, rng)
					_done(ctx, local)
				continue
			var d := minf(rng.randf_range(12.0, 14.0), depth)
			if front and special == "moreau" and k == slots / 2:
				var local := _at(ctx, Vector3(x, KERB, hz - 7.0), PI)
				Buildings.shotgun(mb, local, minf(6.2, slot_w - 0.4), minf(14.0, depth), rng, false, MOREAU)
				_done(ctx, local)
				continue
			if rng.randf() < 0.12:
				_empty_lot(ctx, Vector3(x, 0, side * (hz - 6.0)), yaw)
				continue
			var local := _at(ctx, Vector3(x, KERB, side * (hz - d * 0.5)), yaw)
			Buildings.shotgun(mb, local, minf(rng.randf_range(4.6, 5.6), slot_w - 0.6), d, rng, rng.randf() < 0.18)
			_done(ctx, local)
	ctx.mb.xform = ctx.frame
	var props: Array = []
	for k in range(1, slots):
		var x := -hx + slot_w * k
		Props.fence(mb, props, Vector3(x, KERB, -3.0), Vector3(x, KERB, 3.0), FENCE_WOOD)
	Props.fence(mb, props, Vector3(-hx + 0.5, KERB, 0), Vector3(hx - 0.5, KERB, 0), FENCE_WOOD)
	if rng.randf() < 0.5:
		Props.oak(mb, props, Vector3(rng.randf_range(-hx * 0.7, hx * 0.7), KERB, rng.randf_range(-1.5, 1.5)), rng)
	_done(ctx, props, false, ctx.props)


## What the flood left: a bare foundation, steps to nowhere, weeds and junk.
static func _empty_lot(ctx: Ctx, p: Vector3, yaw: float) -> void:
	var rng := ctx.rng
	var local := _at(ctx, p + Vector3(0, KERB, 0), yaw)
	var mb = ctx.mb
	mb.box(Vector3(0, 0.15, 0.5), Vector3(4.8, 0.3, 9.0), Color(0.6, 0.58, 0.55))
	mb.box(Vector3(1.2, 0.2, -4.4), Vector3(1.2, 0.7, 0.8), Color(0.62, 0.6, 0.58))
	for i in 6:
		mb.box(Vector3(rng.randf_range(-2.5, 2.5), 0.2, rng.randf_range(-5, 5)), Vector3(0.9, 0.5, 0.9), Color(0.4, 0.55, 0.25).lerp(Color(0.55, 0.55, 0.3), rng.randf()))
	if rng.randf() < 0.6:
		Props.crate(mb, local, Vector3(-1.5, 0.0, 2.5))
	mb.box(Vector3(-1.8, 0.85, -4.2), Vector3(0.1, 2.0, 0.1), Color(0.35, 0.3, 0.25))
	mb.box(Vector3(-1.8, 1.55, -4.25), Vector3(1.4, 0.8, 0.06), Color(0.95, 0.95, 0.9))
	mb.box(Vector3(-1.8, 1.55, -4.29), Vector3(1.2, 0.2, 0.02), Color(0.8, 0.15, 0.15))
	_done(ctx, local, false)


## One quarter of Liberty Green, the park superblock: lawn and oaks, paths
## to a round plaza with a bandstand at the middle junction, and a pond.
static func _liberty_green(ctx: Ctx) -> void:
	_ground(ctx, GRASS.lightened(0.04))
	var mb = ctx.mb
	var mid: Vector3 = ctx.city.node_pos(ctx.plan.park_node)
	var inv := ctx.frame.affine_inverse()
	var to_mid := inv * mid # the park's centre in this block's frame
	var local := _at(ctx, Vector3(0, KERB, 0), 0.0)
	# Path from the block's outer corner area to the centre.
	var away := -Vector3(to_mid.x, 0, to_mid.z).normalized()
	var start := away * minf(ctx.hx, ctx.hz) * 0.9
	var seg := Vector3(to_mid.x, 0, to_mid.z) - start
	var saved: Transform3D = mb.xform
	mb.xform = saved * Transform3D(Basis(Vector3.UP, atan2(-seg.z, seg.x)), (start + Vector3(to_mid.x, 0, to_mid.z)) * 0.5)
	mb.box(Vector3(0, 0.03, 0), Vector3(seg.length(), 0.04, 2.6), PLAZA)
	mb.xform = saved
	# Round plaza and bandstand at the centre (each quarter draws its part).
	mb.cylinder(Vector3(to_mid.x, 0.0, to_mid.z), 9.0, 0.06, PLAZA.lightened(0.05), 16)
	if ctx.cell == ctx.plan.park_node - Vector2i(1, 1):
		var c := Vector3(to_mid.x, 0.06, to_mid.z)
		mb.cylinder(c, 4.2, 0.6, Buildings.STONE, 8)
		for k in 8:
			var a := TAU * k / 8.0
			mb.cylinder(c + Vector3(cos(a) * 3.8, 0.6, sin(a) * 3.8), 0.12, 2.6, Color(0.95, 0.95, 0.92), 4)
		mb.cylinder(c + Vector3(0, 3.2, 0), 4.6, 0.3, Color(0.35, 0.45, 0.4), 8)
		mb.cylinder(c + Vector3(0, 3.5, 0), 2.2, 1.0, Color(0.35, 0.45, 0.4), 8)
		local.append([c + Vector3(0, 1.5, 0), Vector3(8.4, 3.0, 8.4)])
	# A pond in one quarter, oaks and benches in all.
	if ctx.cell == ctx.plan.park_node - Vector2i(0, 1):
		mb.cylinder(Vector3(away.x * ctx.hx * 0.35, 0.0, away.z * ctx.hz * 0.35), 6.0, 0.06, POND.lightened(0.15), 12)
		mb.cylinder(Vector3(away.x * ctx.hx * 0.35, 0.0, away.z * ctx.hz * 0.35), 6.5, 0.04, Buildings.STONE, 12)
	for k in 5:
		var p := Vector3(ctx.rng.randf_range(-ctx.hx, ctx.hx) * 0.8, 0, ctx.rng.randf_range(-ctx.hz, ctx.hz) * 0.8)
		if p.distance_to(Vector3(to_mid.x, 0, to_mid.z)) < 12.0 or absf((p - start).cross(seg).y) / maxf(seg.length(), 1.0) < 3.0:
			continue
		Props.oak(mb, local, p, ctx.rng)
	Props.bench(mb, local, start + seg * 0.6 + Vector3(-seg.z, 0, seg.x).normalized() * 2.2, atan2(seg.x, seg.z))
	Props.gas_lamp(mb, local, start + seg * 0.3 + Vector3(seg.z, 0, -seg.x).normalized() * 1.8, ctx.glow)
	_done(ctx, local, false, ctx.props)


## A Wards pocket park: worn grass, a basketball hoop, picnic tables, oaks.
static func _pocket_park(ctx: Ctx) -> void:
	_ground(ctx, GRASS.lightened(0.05))
	var mb = ctx.mb
	var local := _at(ctx, Vector3(0, KERB, 0), 0.0)
	mb.box(Vector3(ctx.hx * 0.3, 0.03, 0), Vector3(12.0, 0.04, 10.0), Color(0.6, 0.35, 0.28))
	mb.box(Vector3(ctx.hx * 0.3 + 5.5, 1.6, 0), Vector3(0.2, 3.2, 0.2), Color(0.3, 0.3, 0.3))
	mb.box(Vector3(ctx.hx * 0.3 + 5.2, 3.2, 0), Vector3(0.1, 1.0, 1.6), Color.WHITE)
	local.append([Vector3(ctx.hx * 0.3 + 5.5, 1.6, 0), Vector3(0.4, 3.2, 0.4)])
	for z in [-ctx.hz * 0.5, ctx.hz * 0.5]:
		Props.oak(mb, local, Vector3(-ctx.hx * 0.5, 0, z), ctx.rng)
		mb.box(Vector3(-ctx.hx * 0.2, 0.45, z * 0.6), Vector3(2.0, 0.1, 1.0), Buildings.WOOD.lightened(0.2))
	Props.fence(mb, local, Vector3(-ctx.hx, 0, -ctx.hz), Vector3(ctx.hx, 0, -ctx.hz), CHAIN, 1.6)
	_done(ctx, local, false, ctx.props)


## A white clapboard chapel with a steeple: a Wards landmark to steer by.
static func _chapel(ctx: Ctx) -> void:
	_ground(ctx, GRASS.darkened(0.05))
	var mb = ctx.mb
	var local := _at(ctx, Vector3(0, KERB, 2.0), PI)
	var white := Color(0.96, 0.95, 0.9)
	mb.box(Vector3(0, 3.0, 0), Vector3(9.0, 6.0, 16.0), white)
	local.append([Vector3(0, 3.0, 0), Vector3(9.0, 6.0, 16.0)])
	var saved: Transform3D = mb.xform
	mb.xform = saved * Transform3D(Basis(Vector3.UP, PI / 2), Vector3.ZERO)
	mb.gable(Vector3(0, 7.2, 0), Vector3(16.4, 2.4, 9.6), Color(0.35, 0.3, 0.32), white)
	mb.xform = saved
	mb.box(Vector3(0, 5.5, -8.5), Vector3(3.2, 11.0, 3.2), white)
	mb.box(Vector3(0, 12.0, -8.5), Vector3(2.0, 2.0, 2.0), white.darkened(0.1))
	mb.cylinder(Vector3(0, 13.0, -8.5), 0.9, 3.5, Color(0.35, 0.3, 0.32), 4)
	mb.box(Vector3(0, 2.0, -8.0 - 2.62), Vector3(1.6, 3.0, 0.1), Buildings.WOOD)
	mb.box(Vector3(0, 9.0, -8.5 - 1.62), Vector3(1.2, 1.2, 0.05), MeshBuilder.glow(Color(1.0, 0.85, 0.5), MeshBuilder.GLOW_WINDOW))
	for z in [-4.0, 0.0, 4.0]:
		for x in [-4.55, 4.55]:
			mb.box(Vector3(x, 3.4, z), Vector3(0.08, 2.4, 1.2), MeshBuilder.glow(Color(0.5, 0.6, 0.85), MeshBuilder.GLOW_WINDOW))
	local.append([Vector3(0, 5.5, -8.5), Vector3(3.2, 11.0, 3.2)])
	_done(ctx, local)
	var props := _at(ctx, Vector3(0, KERB, 0), 0.0)
	Props.oak(mb, props, Vector3(-ctx.hx * 0.6, 0, ctx.hz * 0.6), ctx.rng)
	Props.oak(mb, props, Vector3(ctx.hx * 0.6, 0, -ctx.hz * 0.5), ctx.rng)
	_done(ctx, props, false, ctx.props)


## Gilt District: towers on a stone plaza, sized to the block. Kept mid-rise
## so roofs don't swallow the street under the 3/4 camera.
static func _downtown(ctx: Ctx) -> void:
	var rng := ctx.rng
	var hx := ctx.hx
	var hz := ctx.hz
	_ground(ctx, PLAZA)
	match rng.randi() % 3:
		0:
			_tower(ctx, Vector3.ZERO, hx * 2 - 6.0, hz * 2 - 6.0, rng.randf_range(18.0, 30.0))
			var local := _at(ctx, Vector3(0, KERB, 0), 0.0)
			for x in [-hx + 1.5, hx - 1.5]:
				Props.planter(ctx.mb, local, Vector3(x, 0, hz - 1.5))
			_done(ctx, local, false, ctx.props)
		1:
			for x in [-hx * 0.5, hx * 0.5]:
				_tower(ctx, Vector3(x, 0, -1.5), hx - 2.5, hz * 2 - 7.0, rng.randf_range(14.0, 26.0))
		_:
			for x in [-hx * 0.5, hx * 0.5]:
				for z in [-hz * 0.5, hz * 0.5]:
					_tower(ctx, Vector3(x, 0, z), hx - 3.0, hz - 3.0, rng.randf_range(11.0, 22.0))


static func _tower(ctx: Ctx, pos: Vector3, w: float, d: float, h: float) -> void:
	var local := _at(ctx, pos + Vector3(0, KERB, 0), PI)
	Buildings.tower(ctx.mb, local, maxf(w, 8.0), maxf(d, 8.0), h, ctx.rng)
	_done(ctx, local)


## A Gilt plaza: paving, a fountain, palms and benches.
static func _plaza(ctx: Ctx) -> void:
	_ground(ctx, PLAZA.lightened(0.08))
	var mb = ctx.mb
	var local := _at(ctx, Vector3(0, KERB, 0), 0.0)
	for k in 5:
		mb.box(Vector3(0, 0.02, -ctx.hz + (k + 0.5) * ctx.hz * 0.4), Vector3(ctx.hx * 2, 0.02, 0.15), PLAZA.darkened(0.08))
	mb.cylinder(Vector3(0, 0, 0), 3.2, 0.6, Buildings.STONE, 12)
	mb.cylinder(Vector3(0, 0.05, 0), 2.9, 0.6, Color(0.35, 0.6, 0.75), 12)
	mb.cylinder(Vector3(0, 0.6, 0), 0.4, 2.0, Buildings.STONE.lightened(0.1), 6)
	local.append([Vector3(0, 0.5, 0), Vector3(6.4, 1.0, 6.4)])
	for q in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(1, 0, 1)]:
		Props.palm(mb, local, Vector3(q.x * ctx.hx * 0.65, 0, q.z * ctx.hz * 0.65), ctx.rng)
		Props.bench(mb, local, Vector3(q.x * 6.0, 0, q.z * 4.5), 0.0 if q.z < 0 else PI)
	_done(ctx, local, false, ctx.props)


## A surface car park: striped bays, a booth, a few lamps.
static func _parking(ctx: Ctx) -> void:
	_ground(ctx, ASPHALT.lightened(0.05))
	var mb = ctx.mb
	var local := _at(ctx, Vector3(0, KERB, 0), 0.0)
	var x := -ctx.hx + 1.5
	while x < ctx.hx - 1.0:
		for z in [-ctx.hz + 2.5, ctx.hz - 2.5]:
			mb.box(Vector3(x, 0.02, z), Vector3(0.12, 0.02, 5.0), WHITE_LINE)
		x += 2.8
	mb.box(Vector3(ctx.hx - 2.5, 1.2, 0), Vector3(2.0, 2.4, 2.0), Color(0.9, 0.85, 0.3))
	local.append([Vector3(ctx.hx - 2.5, 1.2, 0), Vector3(2.0, 2.4, 2.0)])
	mb.xform = ctx.frame * Transform3D(Basis(), Vector3(0, KERB, 0))
	for k in ctx.rng.randi_range(3, 7):
		var bay := ctx.rng.randi_range(0, int((ctx.hx * 2 - 4.0) / 2.8))
		var z := (-ctx.hz + 2.5) if ctx.rng.randf() < 0.5 else (ctx.hz - 2.5)
		var paint: Color = [Color(0.82, 0.16, 0.16), Color(0.15, 0.35, 0.75), Color(0.95, 0.95, 0.95), Color(0.2, 0.2, 0.22)][ctx.rng.randi() % 4]
		var cx := -ctx.hx + 2.9 + bay * 2.8
		mb.box(Vector3(cx, 0.6, z), Vector3(1.8, 0.7, 4.0), paint)
		mb.box(Vector3(cx, 1.15, z + 0.3), Vector3(1.6, 0.45, 2.0), Color(0.12, 0.17, 0.22))
		local.append([Vector3(cx, 0.7, z), Vector3(1.9, 1.4, 4.1)])
	_done(ctx, local, false, ctx.props)


static func _aurum(ctx: Ctx) -> void:
	_ground(ctx, PLAZA.lightened(0.1))
	var local := _at(ctx, Vector3(0, KERB, -3.0), PI)
	Buildings.aurum_tower(ctx.mb, local, ctx.rng)
	_done(ctx, local)
	# Fountain and planters on the forecourt.
	var mb = ctx.mb
	var props := _at(ctx, Vector3(0, KERB, 0), 0.0)
	var fz := minf(13.0, ctx.hz - 3.0)
	mb.cylinder(Vector3(0, 0, fz), 2.6, 0.6, Buildings.STONE, 10)
	mb.cylinder(Vector3(0, 0.05, fz), 2.3, 0.6, Color(0.35, 0.6, 0.75), 10)
	mb.cylinder(Vector3(0, 0.45, fz), 0.3, 1.6, Buildings.GOLD, 6)
	props.append([Vector3(0, 0.5, fz), Vector3(5.2, 1.0, 5.2)])
	for x in [-9.0, 9.0]:
		Props.planter(mb, props, Vector3(x, 0, fz))
	_done(ctx, props, false)


static func _union_station(ctx: Ctx) -> void:
	_ground(ctx, PLAZA)
	var local := _at(ctx, Vector3(0, KERB, -2.0), PI)
	Buildings.union_station(ctx.mb, local)
	_done(ctx, local)
	var props := _at(ctx, Vector3(0, KERB, 0), 0.0)
	var z := minf(14.0, ctx.hz - 2.0)
	for x in [-12.0, 12.0]:
		Props.planter(ctx.mb, props, Vector3(x, 0, z))
	for x in [-6.0, 6.0]:
		Props.bench(ctx.mb, props, Vector3(x, 0, z + 0.5), PI)
	_done(ctx, props, false, ctx.props)


## Precinct or clinic, facing the street.
static func _single(ctx: Ctx, kind: String, ground: Color) -> void:
	_ground(ctx, ground)
	var local := _at(ctx, Vector3(0, KERB, 0), PI)
	if kind == "precinct":
		Buildings.precinct(ctx.mb, local)
	else:
		Buildings.clinic(ctx.mb, local)
	_done(ctx, local)


## The Blue Lantern with a townhouse either side and a shallow row behind.
static func _club(ctx: Ctx) -> void:
	var rng := ctx.rng
	_ground(ctx, PAVEMENT.darkened(0.05))
	var local := _at(ctx, Vector3(0, KERB, ctx.hz - 10.0), PI)
	Buildings.blue_lantern(ctx.mb, local, rng)
	_done(ctx, local)
	var side_w := ctx.hx - 12.5
	if side_w > 3.0:
		for x in [-ctx.hx + side_w * 0.5, ctx.hx - side_w * 0.5]:
			var lt := _at(ctx, Vector3(x, KERB, ctx.hz - 6.0), PI)
			Buildings.townhouse(ctx.mb, lt, side_w - 0.2, 12.0, 2, rng)
			_done(ctx, lt)
	var back := ctx.hz - 20.0
	if back > 3.0:
		var x := -ctx.hx
		while x < ctx.hx - 0.5:
			var w := minf(rng.randf_range(6.0, 9.0), ctx.hx - x)
			var lb := _at(ctx, Vector3(x + w * 0.5, KERB, -ctx.hz + back * 0.5), 0.0)
			Buildings.townhouse(ctx.mb, lb, w - 0.2, back, 2, rng)
			_done(ctx, lb)
			x += w


## Ironwharf. On the waterfront: one warehouse, a container yard and a crane
## reaching over the river. Inland: warehouses back to back, or one and a
## container yard. `number` paints a roof number (Warehouse 9).
static func _docks(ctx: Ctx, number: int) -> void:
	var rng := ctx.rng
	var mb = ctx.mb
	var hx := ctx.hx
	var hz := ctx.hz
	_ground(ctx, YARD)
	var wl := minf(32.0, hx * 2 - 2.0)
	# Waterfront blocks with the river behind them get a crane over it.
	var waterfront := false
	var inv := ctx.frame.affine_inverse()
	var corners: PackedVector2Array = ctx.plan.corners(ctx.cell)
	var dirs := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	for k in 4:
		if ctx.city.block_land(ctx.cell + dirs[k]):
			continue
		var mid := inv * _v3((corners[k] + corners[(k + 1) % 4]) * 0.5)
		if mid.z < -hz * 0.5:
			waterfront = true
	if waterfront:
		_warehouse(ctx, Vector3(0, 0, hz - 7.5), PI, wl, 15.0, number)
		var local := _at(ctx, Vector3(0, KERB, 0), 0.0)
		for z in [-hz + 4.5, -hz + 8.0]:
			for k in int(wl / 7.5):
				var p := Vector3(-wl * 0.5 + 3.5 + k * 7.5, 0, z)
				for s in rng.randi_range(0, 2):
					Props.container(mb, local, p + Vector3(0, 2.6 * s, 0), Props.CONTAINERS[rng.randi() % Props.CONTAINERS.size()])
		_done(ctx, local, false)
		var crane := _at(ctx, Vector3(rng.randf_range(-hx * 0.5, hx * 0.5), KERB, -hz + 3.5), PI)
		Props.crane(mb, crane, Vector3.ZERO)
		_done(ctx, crane, false)
		return
	if number >= 0 or rng.randf() < 0.5:
		var d := minf(12.0, hz - 1.0)
		_warehouse(ctx, Vector3(0, 0, -hz + d * 0.5), 0.0, wl, d, -1)
		_warehouse(ctx, Vector3(0, 0, hz - d * 0.5), PI, wl, d, number)
		var local := _at(ctx, Vector3(0, KERB, 0), 0.0)
		for i in 4:
			Props.barrel(mb, local, Vector3(rng.randf_range(-hx * 0.8, hx * 0.8), 0, rng.randf_range(-0.5, 0.5)), Color(0.75, 0.3, 0.2) if rng.randf() < 0.5 else Color(0.25, 0.4, 0.65))
		_done(ctx, local, false, ctx.props)
	else:
		_warehouse(ctx, Vector3(0, 0, hz - 9.0), PI, wl, minf(12.0, hz), number)
		var local := _at(ctx, Vector3(0, KERB, 0), 0.0)
		for z in [-hz + 5.0, -hz + 11.5]:
			if z > hz - 15.0:
				continue
			for k in int(wl / 7.5):
				if rng.randf() < 0.25:
					continue
				var p := Vector3(-wl * 0.5 + 3.5 + k * 7.5, 0, z)
				for s in rng.randi_range(1, 2):
					Props.container(mb, local, p + Vector3(0, 2.6 * s, 0), Props.CONTAINERS[rng.randi() % Props.CONTAINERS.size()])
		_done(ctx, local, false)
		var fence := _at(ctx, Vector3(0, KERB, 0), 0.0)
		Props.fence(mb, fence, Vector3(-hx, 0, -hz), Vector3(-3.0, 0, -hz), CHAIN, 2.0)
		Props.fence(mb, fence, Vector3(3.0, 0, -hz), Vector3(hx, 0, -hz), CHAIN, 2.0)
		_done(ctx, fence, false, ctx.props)


static func _warehouse(ctx: Ctx, pos: Vector3, yaw: float, w: float, d: float, number: int) -> void:
	var local := _at(ctx, pos + Vector3(0, KERB, 0), yaw)
	Buildings.warehouse(ctx.mb, local, w, d, ctx.rng.randf_range(8.0, 12.0), ctx.rng, number)
	_done(ctx, local)


## The Pit: a boxing gym in an old warehouse, with an outdoor ring.
static func _pit(ctx: Ctx) -> void:
	_ground(ctx, YARD)
	var mb = ctx.mb
	var local := _at(ctx, Vector3(0, KERB, -6.0), PI)
	Buildings.warehouse(mb, local, minf(26.0, ctx.hx * 2 - 2.0), 18.0, 8.0, ctx.rng)
	mb.box(Vector3(0, 9.6, -9.3), Vector3(11.0, 2.4, 0.3), Color(0.8, 0.12, 0.12))
	mb.box(Vector3(0, 9.6, -9.5), Vector3(8.0, 0.5, 0.06), MeshBuilder.glow(Color(0.97, 0.95, 0.9), MeshBuilder.GLOW_NEON))
	_done(ctx, local)
	var ring_local := _at(ctx, Vector3(0, KERB, minf(11.5, ctx.hz - 4.0)), 0.0)
	mb.box(Vector3(0, 0.3, 0), Vector3(7.0, 0.6, 7.0), Color(0.3, 0.38, 0.55))
	mb.box(Vector3(0, 0.61, 0), Vector3(6.6, 0.02, 6.6), Color(0.85, 0.85, 0.82))
	for x in [-3.3, 3.3]:
		for z in [-3.3, 3.3]:
			mb.box(Vector3(x, 1.25, z), Vector3(0.2, 1.4, 0.2), Color(0.85, 0.15, 0.15) if x * z > 0 else Color(0.15, 0.25, 0.75))
	for y in [1.05, 1.55]:
		for s in [-3.3, 3.3]:
			mb.box(Vector3(0, y, s), Vector3(6.6, 0.05, 0.05), Color.WHITE)
			mb.box(Vector3(s, y, 0), Vector3(0.05, 0.05, 6.6), Color.WHITE)
	ring_local.append([Vector3(0, 0.45, 0), Vector3(7.0, 0.9, 7.0)])
	_done(ctx, ring_local, false)


## Old Streetcar Depot: the drowned line's rusty rails run inside to an
## abandoned car.
static func _depot(ctx: Ctx) -> void:
	_ground(ctx, MUD.lightened(0.15))
	var local := _at(ctx, Vector3(0, KERB, 0), PI)
	Buildings.streetcar_depot(ctx.mb, local)
	Props.streetcar(ctx.mb, local, Vector3(0, 0, 2.0), true)
	Props.rails(ctx.mb, Vector3(0, 0.02, 12.0), Vector3(0, 0.02, -ctx.hz - 6.0), true)
	_done(ctx, local)


## The Drowned Streetcar: a flooded lot where a streetcar sank in the storm
## and was never pulled out. Fenced off, reeds all round.
static func _drowned(ctx: Ctx) -> void:
	var rng := ctx.rng
	var mb = ctx.mb
	_ground(ctx, MUD)
	var local := _at(ctx, Vector3(0, KERB, 0), 0.0)
	mb.box(Vector3(0, 0.05, 0), Vector3(ctx.hx * 1.5, 0.04, ctx.hz * 1.3), POND)
	var saved: Transform3D = mb.xform
	mb.xform = saved * Transform3D(Basis(Vector3.UP, 0.5) * Basis(Vector3.BACK, 0.15), Vector3(1.0, -1.25, 0))
	var car_cols: Array = []
	Props.streetcar(mb, car_cols, Vector3.ZERO, true)
	mb.xform = saved
	for i in 28:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.6, 0.8)
		mb.box(Vector3(cos(a) * ctx.hx * r, 0.55, sin(a) * ctx.hz * r), Vector3(0.12, rng.randf_range(0.8, 1.6), 0.12), Color(0.45, 0.55, 0.25))
	_done(ctx, local, false)
	var props := _at(ctx, Vector3(0, KERB, 0), 0.0)
	Props.oak(mb, props, Vector3(-ctx.hx + 3.0, 0, -ctx.hz + 3.0), rng)
	var hx := ctx.hx * 0.98
	var hz := ctx.hz * 0.98
	for e in [[Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz)], [Vector3(-hx, 0, -hz), Vector3(-hx, 0, hz)],
			[Vector3(hx, 0, -hz), Vector3(hx, 0, hz)], [Vector3(-hx, 0, hz), Vector3(-3.0, 0, hz)],
			[Vector3(3.0, 0, hz), Vector3(hx, 0, hz)]]:
		Props.fence(mb, props, e[0], e[1], CHAIN, 2.0)
	_done(ctx, props, false, ctx.props)


# --- Street furniture ------------------------------------------------------------

## Lamps, trees, bins and benches along each street side of the block, in a
## frame running along the curb.
static func _furniture(ctx: Ctx, kind: String) -> void:
	var plan = ctx.plan
	var b := ctx.cell
	var inner: PackedVector2Array = plan.inner(b)
	var rng := ctx.rng
	for k in 4:
		var cls: String = plan.side_class(b, k)
		if cls == "closed":
			continue
		var a := inner[k]
		var e := inner[(k + 1) % 4]
		var length := a.distance_to(e)
		var dir := (e - a) / length
		var out := Vector2(dir.y, -dir.x)
		# Frame: x along the curb, -z out to the street; origin 0.45 m in.
		var origin := (a + e) * 0.5 - out * 0.45
		ctx.mb.xform = Transform3D(Basis(Vector3.UP, atan2(dir.y * -1.0, dir.x)), _v3(origin, KERB))
		var local: Array = []
		var half := length * 0.5 - 2.5
		var street := Vector3(0, 0, -1)
		if cls == "lane":
			for t in [-half * 0.5, half * 0.5]:
				Props.planter(ctx.mb, local, Vector3(t, 0, 1.2))
		else:
			match kind:
				"downtown":
					var t := -half
					while t <= half:
						Props.street_light(ctx.mb, local, Vector3(t, 0, 0), street, ctx.glow)
						t += 18.0
					if rng.randf() < 0.5:
						Props.trash_can(ctx.mb, local, Vector3(4.0, 0, 0))
					if rng.randf() < 0.35:
						Props.bench(ctx.mb, local, Vector3(-4.0, 0, 0.4), 0.0)
				"wards":
					if k == 2:
						var t := -half
						while t <= half + 0.1:
							var nxt = Vector3(t + 13.0, 0, 0) if t + 13.0 <= half + 0.1 else null
							Props.power_pole(ctx.mb, local, Vector3(t, 0, 0), nxt)
							t += 13.0
					if rng.randf() < 0.4:
						Props.crepe_myrtle(ctx.mb, local, Vector3(rng.randf_range(-half, half), 0, 0), rng)
					if rng.randf() < 0.25:
						Props.trash_can(ctx.mb, local, Vector3(7.0, 0, 0))
				"docks":
					Props.street_light(ctx.mb, local, Vector3.ZERO, street, ctx.glow)
					if rng.randf() < 0.5:
						Props.barrel(ctx.mb, local, Vector3(rng.randf_range(-half, half), 0, 0), Color(0.75, 0.3, 0.2))
				_:
					var t := -half
					while t <= half:
						Props.gas_lamp(ctx.mb, local, Vector3(t, 0, 0), ctx.glow)
						t += 12.0
					if rng.randf() < 0.5:
						Props.crepe_myrtle(ctx.mb, local, Vector3(6.0 if rng.randf() < 0.5 else -6.0, 0, 0), rng)
					elif kind == "quarter" and ctx.deco.randf() < 0.6:
						var parasol: Color = Buildings.AWNINGS[ctx.deco.randi() % Buildings.AWNINGS.size()]
						Props.cafe_table(ctx.mb, local, Vector3(6.0 if ctx.deco.randf() < 0.5 else -6.0, 0, 1.3), parasol)
					if rng.randf() < 0.3:
						Props.trash_can(ctx.mb, local, Vector3(half - 1.0, 0, 0))
					# Festoon lights across narrow Quarter streets.
					if kind == "quarter" and cls == "quarter" and (k == 1 or k == 2) and ctx.deco.randf() < 0.6:
						var t0 := ctx.deco.randf_range(-half * 0.6, half * 0.6)
						Props.festoon(ctx.mb, Vector3(t0, 4.6, 0), Vector3(t0, 4.6, -(StreetPlan.CLASSES[cls].width + 0.9)), ctx.deco)
		if k == 2 and rng.randf() < 0.7:
			Props.hydrant(ctx.mb, local, Vector3(half - 3.0, 0, 0))
		if k == 3 and rng.randf() < 0.3:
			Props.mailbox(ctx.mb, local, Vector3(half - 3.0, 0, 0))
		if kind == "downtown" and (k == 0 or k == 2):
			Props.traffic_light(ctx.mb, local, Vector3(-half - 1.5, 0, 0), street)
		_done(ctx, local, false, ctx.props)


# --- Outside the window ----------------------------------------------------------

## Cheap blocks past the edge of the playable area: right silhouettes, no
## details or collisions.
static func _outer_block(ctx: Ctx) -> void:
	var rng := ctx.rng
	var mb = ctx.mb
	var hx := ctx.hx
	var hz := ctx.hz
	var kind: String = ctx.city.district_at(ctx.city.block_center(ctx.cell)).get("style", "quarter")
	mb.xform = ctx.frame * Transform3D(Basis(), Vector3(0, KERB, 0))
	match kind:
		"downtown":
			for x in [-hx * 0.5, hx * 0.5]:
				var h := rng.randf_range(14.0, 28.0)
				var glass: Color = Buildings.GLASS[rng.randi() % Buildings.GLASS.size()]
				mb.box(Vector3(x, h * 0.5, 0), Vector3(hx - 2.0, h, hz * 2 - 4.0), glass)
				mb.box(Vector3(x, h + 0.3, 0), Vector3(hx - 2.4, 0.6, hz * 2 - 4.4), glass.lightened(0.3))
		"wards":
			mb.box(Vector3(0, 0.02, 0), Vector3(hx * 2, 0.04, hz * 2), GRASS)
			for z in [-hz * 0.55, hz * 0.55]:
				var count := int(hx * 2 / 6.8)
				for k in count:
					var col: Color = Buildings.WARDS[rng.randi() % Buildings.WARDS.size()]
					var x := -hx + (k + 0.5) * hx * 2 / count
					mb.box(Vector3(x, 1.85, z), Vector3(5.0, 3.4, minf(12.0, hz * 0.8)), col)
					mb.box(Vector3(x, 3.7, z), Vector3(5.4, 0.3, minf(12.4, hz * 0.8 + 0.4)), Color(0.36, 0.33, 0.33))
		"docks":
			mb.box(Vector3(0, 0.02, 0), Vector3(hx * 2, 0.04, hz * 2), YARD)
			mb.box(Vector3(0, 5.0, -hz * 0.3), Vector3(hx * 1.8, 10.0, hz), Color(0.55, 0.5, 0.45))
		"heights", "bayou":
			mb.box(Vector3(0, 0.02, 0), Vector3(hx * 2, 0.04, hz * 2), GRASS.darkened(0.1))
			mb.box(Vector3(0, 4.0, 0), Vector3(14.0, 8.0, 10.0), Color(0.95, 0.93, 0.86))
			mb.box(Vector3(0, 8.2, 0), Vector3(14.6, 0.4, 10.6), Color(0.35, 0.3, 0.32))
		_:
			mb.box(Vector3(0, 0.02, 0), Vector3(hx * 2 - 18.0, 0.04, hz * 2 - 18.0), GRASS)
			for side in [-1.0, 1.0]:
				var col: Color = Buildings.CREOLE[rng.randi() % Buildings.CREOLE.size()]
				var h := rng.randf_range(7.0, 10.5)
				mb.box(Vector3(0, h * 0.5, side * (hz - 5.0)), Vector3(hx * 2, h, 10.0), col)
				mb.box(Vector3(side * (hx - 5.0), h * 0.5, 0), Vector3(10.0, h, hz * 2 - 20.0), col.darkened(0.08))
	mb.xform = Transform3D.IDENTITY
	ctx.buildings += 1
