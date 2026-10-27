extends RefCounted
## Builds one city cell: a block of the street plan with the streets it
## owns, or a street with no block beside it (Morrow Bridge). Pure data in;
## mesh and collision boxes out, so city.gd can run it on a worker thread.
##
## Blocks are the faces of the street plan (street_plan.gd), any shape:
## - An asphalt base fills the block out to its streets' centrelines, so
##   junctions and street edges are always covered; the sidewalk slab
##   follows the block's inner polygon.
## - Each street is detailed in its own frame: neutral grounds with oaks and
##   the streetcar on boulevards, pavers on Quarter streets, bollards and
##   lights on pedestrian lanes, markings, crosswalks. A street with water
##   on one side gets its outer half, a railing and a wall.
## - Block contents are laid out in rectangles ("parcels") turned to face
##   the block's front street. The largest rectangle that fits the lot is
##   split into parcels no bigger than the district's usual block, so big
##   merged blocks hold several buildings; a landmark takes a parcel of its
##   own in the middle of the front. Each parcel gets one layout:
##   - Lantern Quarter: Creole townhouse rings, shops and gardens;
##   - Floodline Wards and Morrow Point: shotgun rows, chapels, pocket parks;
##   - Gilt District: towers, plazas and parking;
##   - Ironwharf: warehouses and container yards, cranes on the quay;
##   - landmarks.
##   The rest of the lot (corners of odd-shaped blocks) gets trees,
##   planters or barrels.

const MeshBuilder = preload("res://scripts/mesh_builder.gd")
const Buildings = preload("res://scripts/kits/building_kit.gd")
const Props = preload("res://scripts/kits/prop_kit.gd")
const StreetPlan = preload("res://scripts/street_plan.gd")

## Road and block slabs reach down into the water so quays have walls.
const SLAB := 1.2
const KERB := 0.15

const ASPHALT := Color(0.27, 0.27, 0.29)
const PAVEMENT := Color(0.58, 0.56, 0.52)
## Granite kerb faces.
const CURB := Color(0.66, 0.65, 0.63)
const PAVERS := Color(0.5, 0.38, 0.32)
const MARKING := Color(0.92, 0.8, 0.3)
const WHITE_LINE := Color(0.9, 0.9, 0.88)
const BIKE_GREEN := Color(0.17, 0.38, 0.26)
const GRASS := Color(0.34, 0.56, 0.28)
const PLAZA := Color(0.72, 0.69, 0.63)
const YARD := Color(0.46, 0.46, 0.45)
const MUD := Color(0.36, 0.33, 0.25)
const POND := Color(0.2, 0.3, 0.26)
const FENCE_WOOD := Color(0.62, 0.52, 0.4)
const CHAIN := Color(0.6, 0.62, 0.64)
const RAIL_WHITE := Color(0.88, 0.88, 0.86)
const MOREAU := Color(0.55, 0.2, 0.24)
const CONCRETE := Color(0.62, 0.61, 0.58)
const STEEL := Color(0.3, 0.36, 0.4)
const ZEBRA_STYLES := ["downtown", "quarter", "station", "tower", "police", "hospital", "park", "club"]
## Biggest parcel (along the front, deep) per district style; bigger lots
## are split.
const PARCEL_MAX := {
	"downtown": Vector2(58, 50), "quarter": Vector2(46, 42), "wards": Vector2(110, 32),
	"docks": Vector2(84, 64),
}
const PARCEL_DEFAULT := Vector2(50, 44)
## Room a landmark's parcel takes beyond its lot need (along, deep).
const LANDMARK_ROOM := Vector2(8, 6)
## The Wards landmarks are a house or apartment in a row of shotguns.
const LANDMARK_PARCEL := {"moreau_house": Vector2(40, 30), "teo_apartment": Vector2(40, 30)}
## Ground colour of a block's lot by district style.
const LOT_GROUND := {
	"quarter": Color(0.55, 0.53, 0.49), "wards": Color(0.32, 0.53, 0.27), "downtown": PLAZA,
	"docks": YARD, "green": Color(0.36, 0.58, 0.3),
}


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
	var cell := 0
	## The block (-1 for a street cell).
	var face := -1
	## The block's front frame (x along the front street, y out through it)
	## and the largest lot rectangle in it.
	var ff := Transform2D.IDENTITY
	var rect := Rect2()
	## Parcel frame: origin at the parcel's centre, +Z out towards its
	## street, +X along it (left to right seen from the street).
	var frame := Transform3D.IDENTITY
	## Half size of the parcel.
	var hx := 17.0
	var hz := 17.0
	var lot := PackedVector2Array()
	## Which parcel sides ("+x", "-x", "+z", "-z") face a street; buildings
	## don't front onto the others (water, the next parcel).
	var open := {"+x": true, "-x": true, "+z": true, "-z": true}
	## Parcels used so far, as world polygons (the filler keeps out).
	var used: Array = []


static func build(city, cell: int) -> Dictionary:
	var ctx := Ctx.new()
	ctx.city = city
	ctx.plan = city.plan
	ctx.mb = MeshBuilder.new()
	ctx.glow = MeshBuilder.new()
	ctx.cell = cell
	ctx.rng.seed = hash([city.seed_value, cell])
	ctx.deco.seed = hash([city.seed_value, cell, "deco"])
	var info: Dictionary = city.cells[cell]
	_streets(ctx, info.edges)
	if info.kind == "face":
		ctx.face = info.id
		_base(ctx)
		if ctx.plan.is_land(ctx.face):
			ctx.lot = ctx.plan.lot(ctx.face)
			ctx.ff = ctx.plan.front_frame2d(ctx.face)
			ctx.rect = ctx.plan.lot_rect(ctx.face)
			if ctx.lot.size() >= 3 and ctx.rect.size.x > 2.0 and ctx.rect.size.y > 2.0:
				var style: String = city.block_style(ctx.face)
				if city.in_window(ctx.face):
					_land_block(ctx, style)
				else:
					_outer_block(ctx)
	return {"mesh": ctx.mb, "glow": ctx.glow, "colliders": ctx.out, "props": ctx.props, "buildings": ctx.buildings}


# --- Frames and placement ------------------------------------------------------

static func _v3(p: Vector2, y := 0.0) -> Vector3:
	return Vector3(p.x, y, p.y)


## Points ctx.frame/hx/hz at parcel `r` (front frame coordinates). A
## flipped parcel faces the back of the block.
static func _use_parcel(ctx: Ctx, r: Rect2, flipped := false, ff = null) -> void:
	var fr: Transform2D = ctx.ff if ff == null else ff
	var c := fr * r.get_center()
	var x := Vector3(fr.x.x, 0, fr.x.y)
	var z := Vector3(fr.y.x, 0, fr.y.y)
	if flipped:
		x = -x
		z = -z
	ctx.frame = Transform3D(Basis(x, Vector3.UP, z), _v3(c))
	ctx.hx = maxf(r.size.x * 0.5 - 0.2, 2.0)
	ctx.hz = maxf(r.size.y * 0.5 - 0.2, 2.0)
	var poly := PackedVector2Array()
	for q in [Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y), Vector2(r.position.x, r.end.y)]:
		poly.append(fr * q)
	ctx.used.append(poly)
	# A side is open when a street runs along it, just past the sidewalk.
	var inner: PackedVector2Array = ctx.plan.inner(ctx.face)
	var inv := ctx.frame.affine_inverse()
	for key in ["+x", "-x", "+z", "-z"]:
		var local: Vector3 = Vector3(ctx.hx + 0.2, 0, 0) if key == "+x" else Vector3(-ctx.hx - 0.2, 0, 0) if key == "-x" else Vector3(0, 0, ctx.hz + 0.2) if key == "+z" else Vector3(0, 0, -ctx.hz - 0.2)
		var w := ctx.frame * local
		var p := Vector2(w.x, w.z)
		var best := INF
		var best_k := -1
		for k in inner.size():
			var d := Geometry2D.get_closest_point_to_segment(p, inner[k], inner[(k + 1) % inner.size()]).distance_to(p)
			if d < best:
				best = d
				best_k = k
		var cls: String = ctx.plan.side_class(ctx.face, best_k) if best_k >= 0 else ""
		ctx.open[key] = best < StreetPlan.SIDEWALK + 3.5 and cls != "" and cls != "quay"
	ctx.open["+z"] = ctx.open["+z"] or (not flipped and r.end.y > ctx.rect.end.y - 0.5 and ff == null)


## World point for a point in the parcel frame.
static func _w(ctx: Ctx, local: Vector3) -> Vector3:
	return ctx.frame * local


## Points the kits at `local` in the parcel frame, turned by `yaw` (0: front
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
	ctx.mb.box(Vector3(0, KERB + 0.02, 0), Vector3(size.x, 0.04, size.y), _paved(color))
	_done(ctx, local, false)


## The whole parcel in one colour (paved, grassed or tarmacked to match).
static func _ground(ctx: Ctx, color: Color) -> void:
	var poly := PackedVector2Array()
	for q in [Vector2(-ctx.hx - 0.2, -ctx.hz - 0.2), Vector2(ctx.hx + 0.2, -ctx.hz - 0.2), Vector2(ctx.hx + 0.2, ctx.hz + 0.2), Vector2(-ctx.hx - 0.2, ctx.hz + 0.2)]:
		poly.append(q)
	ctx.mb.xform = ctx.frame
	ctx.mb.flat(poly, KERB + 0.02, _paved(color))
	ctx.mb.xform = Transform3D.IDENTITY


## Ground colour with the surface it reads as: lawn, tarmac, plaza pavers,
## concrete, or bare (mud).
static func _paved(color: Color) -> Color:
	var code := MeshBuilder.CONCRETE
	if color.g > color.r * 1.25 and color.g > color.b * 1.2:
		code = MeshBuilder.GRASS
	elif color.v < 0.34:
		code = MeshBuilder.ASPHALT
	elif color.b < color.r * 0.8 and color.v < 0.5:
		code = 1.0
	elif color.v > 0.6:
		code = MeshBuilder.PAVING
	return MeshBuilder.glow(color, code)


## `poly` (world) drawn flat at y in the block's front frame, so its
## pattern lines up with the front street.
static func _flat_in_front(ctx: Ctx, ff: Transform2D, poly: PackedVector2Array, y: float, color: Color, y0 := INF, side := Color(0, 0, 0, 0)) -> void:
	ctx.mb.xform = Transform3D(Basis(Vector3(ff.x.x, 0, ff.x.y), Vector3.UP, Vector3(ff.y.x, 0, ff.y.y)), Vector3(ff.origin.x, 0, ff.origin.y))
	var local := ff.affine_inverse() * poly
	if y0 == INF:
		ctx.mb.flat(local, y, color)
	else:
		ctx.mb.prism(local, y0, y, color, side)
	ctx.mb.xform = Transform3D.IDENTITY


# --- Streets -------------------------------------------------------------------

## Asphalt under the whole block (to the centre of its streets) and the
## sidewalk slab inside them.
static func _base(ctx: Ctx) -> void:
	ctx.mb.prism(ctx.plan.face_poly(ctx.face), -SLAB, 0.0, MeshBuilder.glow(ASPHALT, MeshBuilder.ASPHALT), ASPHALT.darkened(0.15))
	var inner: PackedVector2Array = ctx.plan.inner(ctx.face)
	if inner.size() >= 3:
		var slab := MeshBuilder.glow(PAVEMENT, MeshBuilder.CONCRETE)
		if ctx.plan.is_land(ctx.face):
			_flat_in_front(ctx, ctx.plan.front_frame2d(ctx.face), inner, KERB, slab, -0.3, CURB)
		else:
			ctx.mb.prism(inner, -0.3, KERB, slab, CURB)


## The streets this cell owns: markings and furniture, their outer half
## where water is on one side, the bridge, barricades at the window's edge.
static func _streets(ctx: Ctx, edges: PackedInt32Array) -> void:
	for e in edges:
		var cls: String = ctx.plan.edge_class(e)
		if cls == "bridge":
			_bridge(ctx, e)
		else:
			if cls != "quay":
				_street(ctx, e, cls)
			_open_sides(ctx, e, cls)
		if ctx.plan.drivable(e):
			_barricade(ctx, e)


## Where a street's markings stop short of junction n (to clear the streets
## crossing there).
static func _setback(ctx: Ctx, n: int, e: int) -> float:
	var c: float = ctx.plan.clearance(n, e)
	return c + 0.5 if c > 0.0 else 0.0


static func _street(ctx: Ctx, e: int, cls: String) -> void:
	var city = ctx.city
	var plan = ctx.plan
	var mb = ctx.mb
	var na: int = plan.edge_a[e]
	var nb: int = plan.edge_b[e]
	var a: Vector3 = city.node_pos(na)
	var b: Vector3 = city.node_pos(nb)
	var length := a.distance_to(b)
	var w: float = StreetPlan.CLASSES[cls].width
	var s0 := _setback(ctx, na, e)
	var s1 := _setback(ctx, nb, e)
	var run := length - s0 - s1
	if run < 2.0:
		return
	var dir := (b - a) / length
	# Street frame: x along the street from a, z across it.
	var frame := Transform3D(Basis(Vector3.UP, atan2(-dir.z, dir.x)), a)
	mb.xform = frame
	var mid := s0 + run * 0.5
	var style: String = city.district_at((a + b) * 0.5).get("style", "quarter")
	var line: int = city.rail_on(e)
	var rusty: bool = line >= 0 and city.rail_lines[line].rusty
	match cls:
		"boulevard":
			# Neutral ground: a raised lawn with oaks (or palms downtown) and,
			# on the Lantern Line, the streetcar.
			var t0 := 1.5 if s0 > 0.0 else 0.0
			var t1 := 1.5 if s1 > 0.0 else 0.0
			var ng := run - t0 - t1
			var ng_mid := s0 + t0 + ng * 0.5
			if ng >= 1.0:
				mb.box(Vector3(ng_mid, 0.12, 0), Vector3(ng, 0.24, 6.4), PAVEMENT.darkened(0.1))
				mb.box(Vector3(ng_mid, 0.25, 0), Vector3(maxf(ng - 0.4, 0.5), 0.02, 5.6), GRASS)
			for side in [-1.0, 1.0]:
				_dashes(mb, s0, run, side * (3.2 + (w * 0.5 - 3.2) * 0.5), WHITE_LINE)
			if line >= 0:
				Props.rails(mb, Vector3(s0, 0.26, 0), Vector3(s0 + run, 0.26, 0), rusty)
				if not rusty:
					_tram_wires(ctx, s0, run, ctx.deco.randf() < 0.2)
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
			if ng >= 1.0:
				local.append([Vector3(ng_mid, 0.4, 0), Vector3(ng, 0.8, 6.0)])
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
			mb.box(Vector3(mid, 0.005, 0), Vector3(run + 1.0, 0.02, w - 0.4), MeshBuilder.glow(PAVERS, MeshBuilder.PAVING))
		"lane":
			# Pedestrian lane: paved over, bollards at each end, lights strung
			# across.
			mb.box(Vector3(length * 0.5, 0.08, 0), Vector3(length, 0.16, w), MeshBuilder.glow(PAVERS.lightened(0.1), MeshBuilder.PAVING))
			var local: Array = []
			for x in [s0 + 0.5, length - s1 - 0.5]:
				for z in [-2.0, 0.0, 2.0]:
					Props.bollard(mb, local, Vector3(x, 0.1, z))
			_done(ctx, local, false, ctx.props)
			mb.xform = frame
			var k := 0.0
			while k < run - 4.0:
				Props.festoon(mb, Vector3(s0 + 2.0 + k, 4.4, -w * 0.5 - 1.2), Vector3(s0 + 2.0 + k, 4.4, w * 0.5 + 1.2), ctx.deco)
				k += 15.0
	if line >= 0 and cls != "boulevard":
		# The drowned line: rusty rails down the middle of the street.
		Props.rails(mb, Vector3(s0, 0.02, 0), Vector3(s0 + run, 0.02, 0), rusty)
	if cls != "lane":
		for k in ctx.deco.randi_range(0, 2):
			Props.road_mark(mb, Vector3(ctx.deco.randf_range(s0 + 2.0, s0 + run - 2.0), 0.0, ctx.deco.randf_range(-w * 0.3, w * 0.3)), Vector3.RIGHT, ctx.deco)
	var zebra: bool = style in ZEBRA_STYLES and cls != "lane"
	if zebra:
		if s0 > 0.0:
			Props.crosswalk(mb, Vector3(s0 + 1.6, 0.0, 0), Vector3.RIGHT, w - 1.5)
		if s1 > 0.0:
			Props.crosswalk(mb, Vector3(s0 + run - 1.6, 0.0, 0), Vector3.RIGHT, w - 1.5)
	if cls in ["boulevard", "avenue", "river", "street"] and run > 10.0:
		# Traffic keeps right: towards b on the +z side, towards a on -z.
		var gap := 3.6 if zebra else 1.0
		if s1 > 0.0:
			_approach(mb, s0 + run - gap, 1.0, cls, w, style == "downtown" or style == "quarter", run > 32.0)
		if s0 > 0.0:
			_approach(mb, s0 + gap, -1.0, cls, w, style == "downtown" or style == "quarter", run > 32.0)
	mb.xform = Transform3D.IDENTITY


## Markings where traffic heading `heading` (+1 along the street frame's x,
## -1 against it) reaches a junction whose markings end at x: a stop bar
## across its half of the street, on cycling streets a green bike box ahead
## of the bar, and (if `arrows`) lane arrows behind it.
static func _approach(mb, x: float, heading: float, cls: String, w: float, bikes: bool, arrows: bool) -> void:
	var side := heading # right-hand traffic: +x heading drives on +z
	var inner := 3.2 if cls == "boulevard" else 0.3
	var outer := w * 0.5 - 0.4
	if bikes and cls != "street":
		mb.box(Vector3(x - heading * 1.4, 0.011, side * (inner + outer) * 0.5), Vector3(2.6, 0.02, outer - inner), BIKE_GREEN)
		x -= heading * 2.9
	mb.box(Vector3(x, 0.012, side * (inner + outer) * 0.5), Vector3(0.5, 0.02, outer - inner), WHITE_LINE)
	if not arrows:
		return
	var lanes: Array
	# Lane centres, the outer one kept clear of cars parked 1 m off the curb.
	match cls:
		"boulevard":
			lanes = [5.4, 9.2]
		"street":
			lanes = [w * 0.22]
		_:
			lanes = [w * 0.125, w * 0.375 - 0.6]
	for k in lanes.size():
		var turn := -1 if k == 0 and lanes.size() > 1 else 0
		_arrow(mb, Vector3(x - heading * 6.0, 0.012, side * lanes[k]), heading, turn)


## A lane arrow painted on the street frame's ground, pointing along
## `heading` (+1 or -1 on x); `turn` -1 adds a left-turn head.
static func _arrow(mb, p: Vector3, heading: float, turn: int) -> void:
	var paint := WHITE_LINE
	mb.box(p + Vector3(-heading * 0.5, 0, 0), Vector3(2.2, 0.02, 0.18), paint)
	var tip := p.x + heading * 1.4
	var base := p.x + heading * 0.6
	mb.tri(Vector3(base, p.y + 0.01, p.z - 0.4), Vector3(base, p.y + 0.01, p.z + 0.4), Vector3(tip, p.y + 0.01, p.z), Vector3.UP, paint)
	if turn != 0:
		# Left of the heading is -z for +x traffic.
		var left := -heading
		var y := p.y + 0.01
		mb.box(Vector3(p.x - heading * 0.4, p.y, p.z + left * 0.45), Vector3(0.18, 0.02, 0.9), paint)
		var hz := p.z + left * 0.9
		mb.tri(Vector3(p.x - heading * 0.8, y, hz), Vector3(p.x, y, hz), Vector3(p.x - heading * 0.4, y, hz + left * 0.7), Vector3.UP, paint)


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
	if car and run > 20.0:
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


## How far from junction n a railing along side `side` (unit vector across
## street e) must stop: clear of any street leaving n on that side, or a
## little past n to close the corner when none does.
static func _rail_trim(ctx: Ctx, n: int, e: int, side: Vector2) -> float:
	var plan = ctx.plan
	var d: Vector2 = (plan.pos(plan.other(e, n)) - plan.pos(n)).normalized()
	var best := -1.0
	for e2 in plan.edges_of(n):
		if e2 == e:
			continue
		var d2: Vector2 = (plan.pos(plan.other(e2, n)) - plan.pos(n)).normalized()
		if d2.dot(side) <= 0.2:
			continue
		var s := maxf(absf(d.cross(d2)), 0.3)
		best = maxf(best, minf(plan.edge_width(e2) * 0.5 / s + 1.0, 30.0))
	return best


## A side of street e with no block on it: the street's outer half, and a
## railing and wall where it is water.
static func _open_sides(ctx: Ctx, e: int, cls: String) -> void:
	var plan = ctx.plan
	var na: int = plan.edge_a[e]
	var nb: int = plan.edge_b[e]
	var a: Vector2 = plan.pos(na)
	var b: Vector2 = plan.pos(nb)
	var length := a.distance_to(b)
	if length < 0.5:
		return
	var dir := (b - a) / length
	var w: float = plan.edge_width(e) * 0.5
	var mid := (a + b) * 0.5
	for sgn in [-1.0, 1.0]:
		var side: Vector2 = Vector2(-dir.y, dir.x) * sgn
		if plan.face_of(mid + side * (w + 2.5)) >= 0:
			continue # a block's base covers this half
		var t0 := _rail_trim(ctx, na, e, side)
		var t1 := _rail_trim(ctx, nb, e, side)
		var ext0 := 1.0 if t0 < 0.0 else 0.0
		var ext1 := 1.0 if t1 < 0.0 else 0.0
		var outer := w + 1.2
		var strip := PackedVector2Array([a - dir * ext0, b + dir * ext1, b + dir * ext1 + side * outer, a - dir * ext0 + side * outer])
		ctx.mb.prism(strip, -SLAB, 0.0 if cls != "quay" else KERB, MeshBuilder.glow(ASPHALT, MeshBuilder.ASPHALT) if cls != "quay" else MeshBuilder.glow(CONCRETE, MeshBuilder.CONCRETE), CONCRETE.darkened(0.3))
		if not plan.is_water_point(mid + side * (w + 6.0)):
			continue
		var r0: Vector2 = a + dir * (t0 if t0 >= 0.0 else -ext0) + side * (outer - 0.3)
		var r1: Vector2 = b - dir * (t1 if t1 >= 0.0 else -ext1) + side * (outer - 0.3)
		if (r1 - r0).dot(dir) < 1.0:
			continue
		var y := KERB if cls == "quay" else 0.0
		Props.fence(ctx.mb, [], _v3(r0, y), _v3(r1, y), RAIL_WHITE, 0.9)
		var m: Vector2 = (r0 + r1) * 0.5
		ctx.out.append([_v3(m, 2.0), Vector3(r0.distance_to(r1) + 0.6, 4.0, 0.8), atan2(-(r1 - r0).y, (r1 - r0).x)])
		if cls == "quay":
			# Mooring bollards along the wharf edge.
			var t := 6.0
			while t < r0.distance_to(r1) - 3.0:
				ctx.mb.cylinder(_v3(r0 + dir * t - side * 0.8, KERB), 0.25, 0.6, Color(0.15, 0.15, 0.16), 6)
				t += 14.0


## Morrow Bridge: a deck over the river with parapets, lamps and a steel
## portal at each end.
static func _bridge(ctx: Ctx, e: int) -> void:
	var plan = ctx.plan
	var mb = ctx.mb
	var na: int = plan.edge_a[e]
	var nb: int = plan.edge_b[e]
	var a: Vector2 = plan.pos(na)
	var b: Vector2 = plan.pos(nb)
	var length := a.distance_to(b)
	var dir := (b - a) / length
	var side := Vector2(-dir.y, dir.x)
	var w: float = plan.edge_width(e) * 0.5
	var deck := w + 1.4
	mb.prism(PackedVector2Array([a - side * deck, b - side * deck, b + side * deck, a + side * deck]), -1.4, 0.0, MeshBuilder.glow(ASPHALT, MeshBuilder.ASPHALT), CONCRETE.darkened(0.15))
	var frame := Transform3D(Basis(Vector3.UP, atan2(-dir.y, dir.x)), _v3(a))
	mb.xform = frame
	var s0 := _setback(ctx, na, e)
	var s1 := _setback(ctx, nb, e)
	var run := length - s0 - s1
	for z in [-0.12, 0.12]:
		mb.box(Vector3(s0 + run * 0.5, 0.01, z), Vector3(run, 0.02, 0.12), MARKING)
	for sgn in [-1.0, 1.0]:
		_dashes(mb, s0, run, sgn * w * 0.5, WHITE_LINE)
	var local: Array = []
	var p0 := s0 - 0.5
	var p1 := length - s1 + 0.5
	for sgn in [-1.0, 1.0]:
		var z: float = sgn * (w + 0.7)
		# Parapet with a walkway beside the traffic.
		mb.box(Vector3((p0 + p1) * 0.5, 0.5, z), Vector3(p1 - p0, 1.0, 0.6), CONCRETE)
		mb.box(Vector3((p0 + p1) * 0.5, 1.05, z), Vector3(p1 - p0, 0.1, 0.7), CONCRETE.lightened(0.1))
		local.append([Vector3((p0 + p1) * 0.5, 1.5, z), Vector3(p1 - p0, 3.0, 0.8)])
		# Lamps every 24 m, staggered.
		var t := p0 + (8.0 if sgn > 0.0 else 20.0)
		while t < p1 - 4.0:
			Props.street_light(mb, [], Vector3(t, 1.1, z), Vector3(0, 0, -sgn), ctx.glow)
			t += 24.0
		# Steel portals at each end.
		for x in [p0 + 1.0, p1 - 1.0]:
			mb.box(Vector3(x, 4.6, z + sgn * 0.3), Vector3(1.2, 9.2, 1.2), STEEL)
	for x in [p0 + 1.0, p1 - 1.0]:
		mb.box(Vector3(x, 8.6, 0), Vector3(1.0, 1.2, (w + 1.3) * 2.0), STEEL)
		mb.box(Vector3(x, 7.6, 0), Vector3(0.12, 0.8, 6.0), Color(0.92, 0.85, 0.6))
	# Piers where the deck meets the water.
	var t := p0 + 26.0
	while t < p1 - 20.0:
		mb.box(Vector3(t, -0.9, 0), Vector3(3.0, 1.0, (deck + 0.6) * 2.0), CONCRETE.darkened(0.25))
		t += 36.0
	_done(ctx, local, false, ctx.out)


## Striped "road closed" boards where street e leaves the playable window.
static func _barricade(ctx: Ctx, e: int) -> void:
	var plan = ctx.plan
	var win: Rect2 = ctx.city.window
	var a: Vector2 = plan.pos(plan.edge_a[e])
	var b: Vector2 = plan.pos(plan.edge_b[e])
	if win.has_point(a) == win.has_point(b):
		return
	var inside := a if win.has_point(a) else b
	var outside := b if inside == a else a
	var corners := [win.position, Vector2(win.end.x, win.position.y), win.end, Vector2(win.position.x, win.end.y)]
	var hit = null
	for k in 4:
		hit = Geometry2D.segment_intersects_segment(inside, outside, corners[k], corners[(k + 1) % 4])
		if hit != null:
			break
	if hit == null:
		return
	var dir := (outside - inside).normalized()
	var p: Vector2 = hit - dir * 1.5
	var w: float = plan.edge_width(e)
	ctx.mb.xform = Transform3D(Basis(Vector3.UP, atan2(-dir.y, dir.x)), _v3(p))
	var count := maxi(2, ceili(w / 4.0))
	for k in count:
		var z := -w * 0.5 + 1.6 + k * (w - 3.2) / maxf(count - 1, 1)
		ctx.mb.box(Vector3(0, 1.0, z), Vector3(0.2, 0.3, 2.8), Color(0.95, 0.5, 0.1))
		ctx.mb.box(Vector3(0, 0.65, z), Vector3(0.2, 0.3, 2.8), Color(0.95, 0.95, 0.92))
		for s in [-1.2, 1.2]:
			ctx.mb.box(Vector3(0, 0.45, z + s), Vector3(0.12, 0.9, 0.12), Color(0.3, 0.3, 0.3))
	ctx.mb.xform = Transform3D.IDENTITY


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

## Splits rect `r` (front frame) into parcels no bigger than `size`: columns
## along the front, and a back row facing the back street when deep.
## Returns [[Rect2, flipped]].
static func _split(r: Rect2, size: Vector2) -> Array:
	var out: Array = []
	if r.size.x < 1.0 or r.size.y < 1.0:
		return out
	var cols := maxi(1, ceili(r.size.x / size.x - 0.15))
	var rows := 2 if r.size.y > size.y * 1.15 else 1
	var cw := r.size.x / cols
	var rh := r.size.y / rows
	for i in cols:
		for j in rows:
			out.append([Rect2(r.position.x + i * cw, r.position.y + (rows - 1 - j) * rh, cw, rh), j == 1])
	return out


static func _land_block(ctx: Ctx, style: String) -> void:
	var city = ctx.city
	var district: String = city.district_style(ctx.face)
	_flat_in_front(ctx, ctx.ff, ctx.lot, KERB + 0.01, _paved(LOT_GROUND.get("green" if style == "green" else district, PAVEMENT)))
	if style == "green":
		_use_parcel(ctx, ctx.rect)
		_liberty_green(ctx)
		_furniture(ctx, "park")
		return
	var lm: Dictionary = city.landmark_at(ctx.face)
	var rest: Array = [ctx.rect]
	if not lm.is_empty():
		var need: Vector2 = LANDMARK_PARCEL.get(lm.id, StreetPlan.LANDMARK_LOTS.get(lm.id, StreetPlan.DEFAULT_LOT) + LANDMARK_ROOM)
		var r := ctx.rect
		var lw := minf(need.x, r.size.x)
		var ld := minf(need.y, r.size.y)
		var cx := r.get_center().x
		var parcel := Rect2(cx - lw * 0.5, r.end.y - ld, lw, ld)
		_use_parcel(ctx, parcel)
		_landmark(ctx, lm.id)
		rest = [Rect2(r.position.x, r.position.y, parcel.position.x - r.position.x, r.size.y),
			Rect2(parcel.end.x, r.position.y, r.end.x - parcel.end.x, r.size.y),
			Rect2(parcel.position.x, r.position.y, lw, parcel.position.y - r.position.y)]
	var docks_ff = _docks_frame(ctx) if district == "docks" and lm.is_empty() else null
	if docks_ff != null:
		# Yards turn their backs to the quay, so cranes reach over the water.
		var r: Rect2 = StreetPlan.largest_rect(docks_ff.affine_inverse() * ctx.lot)
		for p in _split(r, Vector2(PARCEL_MAX.docks.x, INF)):
			_use_parcel(ctx, p[0], p[1], docks_ff)
			_docks(ctx, -1)
	else:
		for r in rest:
			if r.size.x < 9.0 or r.size.y < 9.0:
				continue
			for p in _split(r, PARCEL_MAX.get(district, PARCEL_DEFAULT)):
				_use_parcel(ctx, p[0], p[1])
				if ctx.hx < 4.0 or ctx.hz < 4.0:
					continue
				_district_parcel(ctx, district)
	_filler(ctx, district)
	_furniture(ctx, district)


## A frame for a docks block with the quay behind it (+y away from the
## water), or null when it has no quay.
static func _docks_frame(ctx: Ctx):
	var inner: PackedVector2Array = ctx.plan.inner(ctx.face)
	var n := inner.size()
	var best := -1
	var best_len := 0.0
	for k in n:
		if ctx.plan.side_class(ctx.face, k) != "quay":
			continue
		var l := inner[k].distance_to(inner[(k + 1) % n])
		if l > best_len:
			best_len = l
			best = k
	if best < 0 or best_len < 20.0:
		return null
	var a := inner[best]
	var b := inner[(best + 1) % n]
	var d := (b - a).normalized()
	var to_water := Vector2(d.y, -d.x) # outside a clockwise (on screen) polygon
	var out := -to_water
	var along := Vector2(out.y, -out.x)
	return Transform2D(along, out, (a + b) * 0.5)


static func _landmark(ctx: Ctx, id: String) -> void:
	match id:
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


static func _district_parcel(ctx: Ctx, district: String) -> void:
	var roll := ctx.rng.randf()
	match district:
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
			elif roll < 0.14 and ctx.hx < 30.0:
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


## Trees, planters or barrels in the corners of the lot no parcel covers.
static func _filler(ctx: Ctx, district: String) -> void:
	var inv := ctx.ff.affine_inverse()
	var local_lot := inv * ctx.lot
	var inset := Geometry2D.offset_polygon(local_lot, -2.2, Geometry2D.JOIN_MITER)
	if inset.is_empty():
		return
	var used: Array = []
	for poly in ctx.used:
		used.append(StreetPlan._bbox(inv * (poly as PackedVector2Array)).grow(1.5))
	var box := StreetPlan._bbox(local_lot)
	var rng := ctx.deco
	var props: Array = []
	ctx.mb.xform = Transform3D(Basis(Vector3(ctx.ff.x.x, 0, ctx.ff.x.y), Vector3.UP, Vector3(ctx.ff.y.x, 0, ctx.ff.y.y)), _v3(ctx.ff.origin, KERB))
	var x := box.position.x + 3.5
	while x < box.end.x - 2.0:
		var y := box.position.y + 3.5
		while y < box.end.y - 2.0:
			var p := Vector2(x + rng.randf_range(-1.5, 1.5), y + rng.randf_range(-1.5, 1.5))
			y += 7.0
			if used.any(func(r): return r.has_point(p)):
				continue
			var inside := false
			for poly in inset:
				if Geometry2D.is_point_in_polygon(p, poly):
					inside = true
			if not inside:
				continue
			var at := Vector3(p.x, 0, p.y)
			match district:
				"downtown":
					if rng.randf() < 0.45:
						Props.palm(ctx.mb, props, at, rng)
					elif rng.randf() < 0.3:
						Props.planter(ctx.mb, props, at)
				"docks":
					if rng.randf() < 0.25:
						Props.container(ctx.mb, props, at, Props.CONTAINERS[rng.randi() % Props.CONTAINERS.size()], rng.randf() < 0.5)
					elif rng.randf() < 0.3:
						Props.barrel(ctx.mb, props, at, Color(0.75, 0.3, 0.2) if rng.randf() < 0.5 else Color(0.25, 0.4, 0.65))
				"wards":
					if rng.randf() < 0.5:
						Props.oak(ctx.mb, props, at, rng)
				_:
					if rng.randf() < 0.35:
						Props.crepe_myrtle(ctx.mb, props, at, rng)
					elif rng.randf() < 0.3:
						Props.oak(ctx.mb, props, at, rng)
		x += 7.0
	_done(ctx, props, false, ctx.props)


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
	var inner: PackedVector2Array = ctx.plan.inner(ctx.face)
	for k in inner.size():
		if ctx.plan.side_class(ctx.face, k) != "quay":
			continue
		var mid := inv * _v3((inner[k] + inner[(k + 1) % inner.size()]) * 0.5)
		if mid.z < -hz * 0.5 and absf(mid.x) < hx + 6.0:
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


## Liberty Green, the park on Liberty Avenue: lawn and oaks, paths from
## each side to a round plaza with a bandstand, a pond, benches and lamps.
static func _liberty_green(ctx: Ctx) -> void:
	var mb = ctx.mb
	var rng := ctx.rng
	var hx := ctx.hx
	var hz := ctx.hz
	var local := _at(ctx, Vector3(0, KERB, 0), 0.0)
	# Paths: one along the park, one across it, and a diagonal from the
	# front corner (the way people cut across from the avenue).
	mb.box(Vector3(0, 0.03, 0), Vector3(hx * 2, 0.04, 3.0), PLAZA)
	mb.box(Vector3(0, 0.03, 0), Vector3(3.0, 0.04, hz * 2), PLAZA)
	var corner := Vector3(-hx * 0.9, 0, hz * 0.9)
	var saved: Transform3D = mb.xform
	mb.xform = saved * Transform3D(Basis(Vector3.UP, atan2(corner.z, -corner.x)), corner * 0.5)
	mb.box(Vector3(0, 0.03, 0), Vector3(corner.length(), 0.04, 2.4), PLAZA)
	mb.xform = saved
	# Round plaza and bandstand in the middle.
	mb.cylinder(Vector3(0, 0.0, 0), 10.0, 0.07, PLAZA.lightened(0.05), 18)
	mb.cylinder(Vector3(0, 0.07, 0), 4.2, 0.6, Buildings.STONE, 8)
	for k in 8:
		var a := TAU * k / 8.0
		mb.cylinder(Vector3(cos(a) * 3.8, 0.67, sin(a) * 3.8), 0.12, 2.6, Color(0.95, 0.95, 0.92), 4)
	mb.cylinder(Vector3(0, 3.27, 0), 4.6, 0.3, Color(0.35, 0.45, 0.4), 8)
	mb.cylinder(Vector3(0, 3.57, 0), 2.2, 1.0, Color(0.35, 0.45, 0.4), 8)
	local.append([Vector3(0, 1.5, 0), Vector3(8.4, 3.0, 8.4)])
	# A pond in the back corner away from the diagonal path.
	var pond := Vector3(hx * 0.55, 0, -hz * 0.5)
	var pr := minf(9.0, minf(hx, hz) * 0.35)
	mb.cylinder(pond, pr + 0.6, 0.05, Buildings.STONE, 14)
	mb.cylinder(pond, pr, 0.07, POND.lightened(0.15), 14)
	# Oaks, clear of the paths, the plaza and the pond.
	for k in int(hx * hz / 55.0):
		var p := Vector3(rng.randf_range(-hx + 2.5, hx - 2.5), 0, rng.randf_range(-hz + 2.5, hz - 2.5))
		if absf(p.x) < 4.0 or absf(p.z) < 4.0 or p.length() < 14.0 or p.distance_to(pond) < pr + 4.0:
			continue
		var t := clampf((p - corner).dot(-corner) / corner.length_squared(), 0.0, 1.0)
		if p.distance_to(corner.lerp(Vector3.ZERO, t)) < 3.5:
			continue
		Props.oak(mb, local, p, rng)
	# Benches and lamps along the paths.
	for s in [-1.0, 1.0]:
		for f in [0.45, 0.8]:
			Props.bench(mb, local, Vector3(s * hx * f, 0, 2.6), PI)
			Props.bench(mb, local, Vector3(2.6, 0, s * hz * f), -PI / 2)
		Props.gas_lamp(mb, local, Vector3(s * hx * 0.62, 0, -2.2), ctx.glow)
		Props.gas_lamp(mb, local, Vector3(-2.2, 0, s * hz * 0.62), ctx.glow)
	_done(ctx, local, false, ctx.props)


# --- Street furniture ------------------------------------------------------------

## Lamps, trees, bins and benches along each street side of the block, in a
## frame running along the curb.
static func _furniture(ctx: Ctx, kind: String) -> void:
	var plan = ctx.plan
	var inner: PackedVector2Array = plan.inner(ctx.face)
	var rng := ctx.rng
	var n := inner.size()
	for k in n:
		var cls: String = plan.side_class(ctx.face, k)
		if cls == "" or cls == "quay":
			continue
		var a := inner[k]
		var e := inner[(k + 1) % n]
		var length := a.distance_to(e)
		if length < 9.0:
			continue
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
						Props.bins(ctx.mb, local, Vector3(minf(4.0, half), 0, 0.2))
					if rng.randf() < 0.35:
						Props.bench(ctx.mb, local, Vector3(maxf(-4.0, -half), 0, 0.4), 0.0)
					if rng.randf() < 0.6:
						Props.traffic_light(ctx.mb, local, Vector3(-half - 1.5, 0, 0), street)
					_modern_street(ctx, local, half, true)
				"wards":
					# Power lines on the south-facing sides.
					if out.y > 0.4:
						var t := -half
						while t <= half + 0.1:
							var nxt = Vector3(t + 13.0, 0, 0) if t + 13.0 <= half + 0.1 else null
							Props.power_pole(ctx.mb, local, Vector3(t, 0, 0), nxt)
							t += 13.0
					for i in int(length / 40.0) + 1:
						if rng.randf() < 0.4:
							Props.crepe_myrtle(ctx.mb, local, Vector3(rng.randf_range(-half, half), 0, 0), rng)
					if rng.randf() < 0.25:
						Props.bins(ctx.mb, local, Vector3(minf(7.0, half), 0, 0.3))
					if ctx.deco.randf() < 0.15:
						Props.scooter(ctx.mb, Vector3(ctx.deco.randf_range(-half, half), 0, 1.6), ctx.deco.randf() * TAU, Props.SCOOTERS[ctx.deco.randi() % Props.SCOOTERS.size()])
				"docks":
					var t := -half
					while t <= half:
						Props.street_light(ctx.mb, local, Vector3(t, 0, 0), street, ctx.glow)
						t += 30.0
					if rng.randf() < 0.5:
						Props.barrel(ctx.mb, local, Vector3(rng.randf_range(-half, half), 0, 0), Color(0.75, 0.3, 0.2))
				_:
					var t := -half
					while t <= half:
						Props.gas_lamp(ctx.mb, local, Vector3(t, 0, 0), ctx.glow)
						t += 12.0
					if rng.randf() < 0.5:
						Props.crepe_myrtle(ctx.mb, local, Vector3(minf(6.0, half) if rng.randf() < 0.5 else maxf(-6.0, -half), 0, 0), rng)
					elif kind == "quarter" and ctx.deco.randf() < 0.6:
						var parasol: Color = Buildings.AWNINGS[ctx.deco.randi() % Buildings.AWNINGS.size()]
						Props.cafe_table(ctx.mb, local, Vector3(minf(6.0, half) if ctx.deco.randf() < 0.5 else maxf(-6.0, -half), 0, 1.3), parasol)
					if rng.randf() < 0.3:
						Props.trash_can(ctx.mb, local, Vector3(half - 1.0, 0, 0))
					if kind == "quarter":
						_modern_street(ctx, local, half, false)
					# Festoon lights across narrow Quarter streets.
					if kind == "quarter" and cls == "quarter" and out.y > -0.3 and ctx.deco.randf() < 0.45:
						var t0 := ctx.deco.randf_range(-half * 0.6, half * 0.6)
						Props.festoon(ctx.mb, Vector3(t0, 4.6, 0), Vector3(t0, 4.6, -(StreetPlan.CLASSES[cls].width + 0.9)), ctx.deco)
		if rng.randf() < 0.35 and half > 4.0:
			Props.hydrant(ctx.mb, local, Vector3(half - 3.0, 0, 0))
		if rng.randf() < 0.15 and half > 4.0:
			Props.mailbox(ctx.mb, local, Vector3(3.0 - half, 0, 0))
		_done(ctx, local, false, ctx.props)


## Present-day kit along a curb (furniture frame, -Z to the street). Downtown,
## in the gap between the bench (x -4.9..-3.1) and the bins (3.35..4.65): a
## bus shelter, a bike-share dock, EV chargers or a wayfinding totem, and
## sometimes a pay station past the bench. Everywhere: dockless scooters,
## kept inside the sidewalk (its back edge is at z 2.55).
static func _modern_street(ctx: Ctx, local: Array, half: float, downtown: bool) -> void:
	var deco := ctx.deco
	if downtown and half > 6.0:
		var roll := deco.randf()
		if roll < 0.25:
			Props.bus_shelter(ctx.mb, local, Vector3(0.2, 0, 1.2), deco)
		elif roll < 0.45:
			Props.bike_dock(ctx.mb, local, Vector3(0.4, 0, 1.6), 4.0, deco)
		elif roll < 0.6:
			for x in [-1.5, 1.5]:
				Props.ev_charger(ctx.mb, local, Vector3(x, 0, 0.15))
		elif roll < 0.75:
			Props.wayfinding(ctx.mb, local, Vector3(1.0, 0, 0.7))
		if half >= 8.0 and deco.randf() < 0.25:
			Props.pay_station(ctx.mb, local, Vector3(-half * 0.7, 0, 0.3))
	if deco.randf() < 0.3:
		for k in deco.randi_range(1, 2):
			Props.scooter(ctx.mb, Vector3(deco.randf_range(-half, half), 0, 1.7 + k * 0.3), deco.randf() * TAU, Props.SCOOTERS[deco.randi() % Props.SCOOTERS.size()])


# --- Outside the window ----------------------------------------------------------

## Cheap blocks past the edge of the playable area: right silhouettes, no
## details or collisions.
static func _outer_block(ctx: Ctx) -> void:
	var kind: String = ctx.city.district_style(ctx.face)
	_flat_in_front(ctx, ctx.ff, ctx.lot, KERB + 0.01, _paved(LOT_GROUND.get(kind, PAVEMENT)))
	for p in _split(ctx.rect, PARCEL_MAX.get(kind, PARCEL_DEFAULT)):
		_use_parcel(ctx, p[0], p[1])
		if ctx.hx < 4.0 or ctx.hz < 4.0:
			continue
		_outer_parcel(ctx, kind)
	ctx.used = []


static func _outer_parcel(ctx: Ctx, kind: String) -> void:
	var rng := ctx.rng
	var mb = ctx.mb
	var hx := ctx.hx
	var hz := ctx.hz
	mb.xform = ctx.frame * Transform3D(Basis(), Vector3(0, KERB, 0))
	match kind:
		"downtown":
			for x in [-hx * 0.5, hx * 0.5]:
				var h := rng.randf_range(14.0, 28.0)
				var glass: Color = Buildings.GLASS[rng.randi() % Buildings.GLASS.size()]
				mb.box(Vector3(x, h * 0.5, 0), Vector3(hx - 2.0, h, hz * 2 - 4.0), glass)
				mb.box(Vector3(x, h + 0.3, 0), Vector3(hx - 2.4, 0.6, hz * 2 - 4.4), glass.lightened(0.3))
		"wards":
			for z in ([-hz * 0.55, hz * 0.55] if hz > 9.0 else [0.0]):
				var count := maxi(1, int(hx * 2 / 6.8))
				for k in count:
					var col: Color = Buildings.WARDS[rng.randi() % Buildings.WARDS.size()]
					var x := -hx + (k + 0.5) * hx * 2 / count
					mb.box(Vector3(x, 1.85, z), Vector3(5.0, 3.4, minf(12.0, hz * 0.8)), col)
					mb.box(Vector3(x, 3.7, z), Vector3(5.4, 0.3, minf(12.4, hz * 0.8 + 0.4)), Color(0.36, 0.33, 0.33))
		"docks":
			mb.box(Vector3(0, 5.0, -hz * 0.3), Vector3(hx * 1.8, 10.0, hz), Color(0.55, 0.5, 0.45))
		"heights", "bayou":
			mb.box(Vector3(0, 4.0, 0), Vector3(minf(14.0, hx * 1.6), 8.0, minf(10.0, hz * 1.6)), Color(0.95, 0.93, 0.86))
			mb.box(Vector3(0, 8.2, 0), Vector3(minf(14.6, hx * 1.6 + 0.6), 0.4, minf(10.6, hz * 1.6 + 0.6)), Color(0.35, 0.3, 0.32))
		_:
			var col: Color = Buildings.CREOLE[rng.randi() % Buildings.CREOLE.size()]
			var h := rng.randf_range(7.0, 10.5)
			var d := minf(10.0, hz)
			mb.box(Vector3(0, h * 0.5, hz - d * 0.5), Vector3(hx * 2, h, d), col)
			if hz > 12.0:
				mb.box(Vector3(0, h * 0.5, -hz + d * 0.5), Vector3(hx * 2, h, d), col.darkened(0.08))
	mb.xform = Transform3D.IDENTITY
	ctx.buildings += 1
