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
##   - Floodline Wards and Morrow Point: shotgun rows, chapels, pocket parks,
##     barred bungalows, a housing project, burned lots, and run-down
##     strips (motels, liquor, pawn, check cashing, SROs; kits/shady_kit.gd)
##     on their avenues and boulevards;
##   - Gilt District: towers, plazas (a fountain or a statue on a plinth)
##     and parking, a third of it skyscrapers (kits/skyline_kit.gd); Midtown
##     taller, with LED towers and more skyscrapers;
##   - Morrow Point: brownstone rows round green block cores (Brooklyn);
##   - round Moreau Square: painted Victorian rows (SF's Alamo Square);
##   - Ironwharf: warehouses and container yards, cranes on the quay;
##     inland, chop shops, scrapyards, and abandoned warehouses with a tent
##     row along the sidewalk (skid row);
##   - landmarks, the government buildings among them (kits/civic_kit.gd);
##   - the civic centre's set pieces: City Hall's grounds, the Esplanade
##     with its reflecting pool and the memorial arch at its west end,
##     Founders Circle with the obelisk.
##   The rest of the lot (corners of odd-shaped blocks) gets trees,
##   planters or barrels.

const MeshBuilder = preload("res://scripts/mesh_builder.gd")
const Buildings = preload("res://scripts/kits/building_kit.gd")
const Props = preload("res://scripts/kits/prop_kit.gd")
const Civic = preload("res://scripts/kits/civic_kit.gd")
const Skyline = preload("res://scripts/kits/skyline_kit.gd")
const Shady = preload("res://scripts/kits/shady_kit.gd")
const Kit = preload("res://scripts/kits/country_kit.gd")
const StreetPlan = preload("res://scripts/street_plan.gd")
const TrafficPlan = preload("res://scripts/traffic_plan.gd")

## Road and block slabs reach down into the water so quays have walls.
const SLAB := 1.2
## Half width of the walk kept clear in front of a place's door.
const DOOR_CLEAR := 1.5
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
## District banners on downtown street lights.
const BANNERS := [Color(0.85, 0.62, 0.18), Color(0.12, 0.5, 0.58), Color(0.7, 0.16, 0.22)]
const ZEBRA_STYLES := ["downtown", "quarter", "station", "tower", "police", "hospital", "park", "club"]
## Road surfaces (Sachin: "some roads are newly paved ... some roads are old
## worn out but still solid, some are too washed out but still good, some
## are built from tiles, of white or brown colors"): [colour, pattern code,
## pattern scale, how far the paint has faded toward the road, share of
## the dashes worn away (1: no lines at all)]. The tarmac's shade sets how
## cracked and patched the shader draws it (MeshBuilder's asphalt).
const ROAD_LOOKS := {
	"fresh": [Color(0.165, 0.165, 0.18), MeshBuilder.ASPHALT, Vector2.ONE, 0.0, 0.0],
	"worn": [Color(0.31, 0.31, 0.315), MeshBuilder.ASPHALT, Vector2.ONE, 0.2, 0.05],
	"washed": [Color(0.43, 0.42, 0.4), MeshBuilder.ASPHALT, Vector2.ONE, 0.55, 0.35],
	# Slabs about 4.5 m by 3.6 m.
	"concrete": [Color(0.53, 0.53, 0.5), MeshBuilder.CONCRETE, Vector2(0.333, 0.417), 0.1, 0.0],
	# Pale tiles 1 m by 0.5 m.
	"tile_white": [Color(0.8, 0.78, 0.74), MeshBuilder.PAVING, Vector2(0.6, 0.6), 0.3, 1.0],
	# Terracotta brick pavers in light mortar.
	"tile_brown": [Color(0.6, 0.37, 0.27), MeshBuilder.BRICK, Vector2(0.5, 0.5), 0.3, 1.0],
	"pavers": [PAVERS, MeshBuilder.PAVING, Vector2.ONE, 0.25, 1.0],
	# Grey granite setts.
	"setts": [Color(0.47, 0.46, 0.45), MeshBuilder.PAVING, Vector2(1.8, 1.8), 0.25, 1.0],
}
const ROAD_KINDS := ["fresh", "worn", "washed", "concrete", "tile_white", "tile_brown"]
## Shares of ROAD_KINDS by district style: new tarmac and concrete in the
## centre, worn and washed-out in the wards and on the docks, brick and
## tile in the old quarters (tiles only on the two-lane streets).
const ROAD_MIX := {
	"downtown": [45, 25, 0, 20, 10, 0], "financial": [45, 25, 0, 20, 10, 0], "civic": [45, 25, 0, 20, 10, 0],
	"midtown": [30, 40, 10, 20, 0, 0], "market": [30, 40, 10, 20, 0, 0], "strip": [30, 40, 10, 20, 0, 0],
	"quarter": [10, 30, 20, 0, 15, 25], "oldtown": [10, 30, 20, 0, 15, 25], "revival": [10, 30, 20, 0, 15, 25],
	"brownstone": [30, 35, 5, 10, 5, 15], "rowhouse": [30, 35, 5, 10, 5, 15], "heights": [30, 35, 5, 10, 5, 15], "enclave": [30, 35, 5, 10, 5, 15],
	"wards": [5, 40, 50, 5, 0, 0], "bayou": [5, 40, 50, 5, 0, 0],
	"docks": [10, 35, 25, 30, 0, 0], "industrial": [10, 35, 25, 30, 0, 0], "waterfront": [10, 35, 25, 30, 0, 0],
	"default": [25, 40, 15, 15, 0, 5],
}
## The paved quarter streets and walking lanes.
const PAVER_KINDS := ["pavers", "pavers", "tile_brown", "tile_white", "setts"]
## The order the quarter's pavings stack in where two meet (see _street).
const PAVER_LAYERS := ["pavers", "tile_brown", "tile_white", "setts"]
## Road paint (the fade above applies to these colours only).
const PAINTS := [MARKING, WHITE_LINE, BIKE_GREEN, Color(0.93, 0.93, 0.9)]
## Dug-up ground at roadworks.
const WORKS_DIRT := Color(0.45, 0.36, 0.26)
## Biggest parcel (along the front, deep) per district style; bigger lots
## are split.
const PARCEL_MAX := {
	"downtown": Vector2(58, 50), "midtown": Vector2(52, 50), "quarter": Vector2(46, 42), "wards": Vector2(110, 32),
	"docks": Vector2(84, 64), "brownstone": Vector2(40, 34), "painted": Vector2(44, 32),
	"chinatown": Vector2(36, 30), "havana": Vector2(40, 34), "beach": Vector2(44, 40),
}
const PARCEL_DEFAULT := Vector2(50, 44)
## Towers reach full height this far in from the city's edge; nearer it
## they are lower and fewer (HANDOFF-city-outline.md). Downtown sits near
## the north-west edge, so a longer falloff would flatten a third of it.
const EDGE_LOW := 150.0
## Parcels this near the edge may be a parking lot or a green.
const EDGE_OPEN := 90.0
## Room a landmark's parcel takes beyond its lot need (along, deep).
const LANDMARK_ROOM := Vector2(8, 6)
## The Wards landmarks are a house or apartment in a row of shotguns.
const LANDMARK_PARCEL := {"moreau_house": Vector2(40, 30), "teo_apartment": Vector2(40, 30)}
## Ground colour of a block's lot by district style.
const LOT_GROUND := {
	"quarter": Color(0.55, 0.53, 0.49), "wards": Color(0.32, 0.53, 0.27), "downtown": PLAZA, "midtown": PLAZA,
	"docks": YARD, "green": Color(0.36, 0.58, 0.3), "brownstone": Color(0.32, 0.53, 0.27), "painted": Color(0.32, 0.53, 0.27),
	"chinatown": PAVEMENT, "havana": Color(0.84, 0.79, 0.68), "beach": Color(0.86, 0.81, 0.68),
}
## Map landmarks built by the civic kit: landmark id -> kit kind.
const CIVIC_LANDMARKS := {
	"city_hall": "city_hall", "county_courthouse": "county_courthouse", "federal_building": "federal_building",
	"public_library": "public_library", "police_headquarters": "police_headquarters",
	"main_post_office": "main_post_office", "fire_headquarters": "fire_headquarters",
	"ferry_building": "ferry_building", "liberty_square": "led_tower",
}
## The set pieces whose blocks are lawn rather than lots.
const LAWNS := ["green", "esplanade", "circle", "square"]
## Skyscrapers (skyline_kit.gd) per district, repeats weighting the draw:
## Gilt is the older financial core (helipad roofs, granite slabs, an
## art-deco crown), Midtown the newer glass towers.
const GILT_TOWERS := ["skyscraper_glass", "skyscraper_helipad", "skyscraper_helipad", "skyscraper_crown", "skyscraper_slab", "highrise_mid", "highrise_mid"]
const MIDTOWN_TOWERS := ["skyscraper_glass", "skyscraper_glass", "skyscraper_crown", "skyscraper_twin", "skyscraper_helipad", "highrise_mid"]
## Shady storefronts (shady_kit.gd) along the Wards' avenues and boulevards,
## like LA's Figueroa or Western: motels, liquor, pawn, check cashing, SROs.
const STRIP_SHOPS := ["liquor_store", "pawn_shop", "check_cashing", "motel", "sro_hotel", "liquor_store", "pawn_shop"]
## The run-down yards of inland Ironwharf.
const DOCKS_SHADY := ["chop_shop", "scrapyard", "abandoned_warehouse"]


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
	## Class of the street along the parcel's front (+z), or "".
	var front_cls := ""
	## The block's distance to the city's edge (StreetPlan.edge_distance):
	## towers give way to lower buildings, lots and greens toward it.
	var edge := INF


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
		if key == "+z":
			ctx.front_cls = cls if ctx.open[key] else ""
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
		target.append([x * col[0], col[1], yaw + (col[2] if col.size() > 2 else 0.0)] + col.slice(3))
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
## where water is on one side, the bridge.
static func _streets(ctx: Ctx, edges: PackedInt32Array) -> void:
	for e in edges:
		var cls: String = ctx.plan.edge_class(e)
		if cls == "bridge":
			_bridge(ctx, e)
		else:
			_street(ctx, e, cls)
			_open_sides(ctx, e, cls)


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
	# Its surface (road_surface): a skin over the block's tarmac between
	# the junctions; quarter streets and lanes are paved in it instead.
	var look: Array = ROAD_LOOKS[road_surface(city.seed_value, e, cls, style)]
	var drop: float = look[4]
	var paint_from: int = mb.verts.size()
	if cls != "quarter" and cls != "lane":
		var skin: int = mb.uvs.size()
		mb.box(Vector3(mid, 0.004, 0), Vector3(run, 0.008, w - 0.04), MeshBuilder.glow(look[0], look[1]))
		mb.scale_uvs(skin, look[2])
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
			_lane_lines(mb, s0, run, cls, drop)
			if line >= 0:
				Props.rails(mb, Vector3(s0, 0.26, 0), Vector3(s0 + run, 0.26, 0), rusty)
				if not rusty:
					_tram_wires(ctx, s0, run, ctx.deco.randf() < 0.2)
			var t := s0 + 4.0
			var local: Array = []
			while t < s0 + run - 4.0:
				var off := 2.2 if line >= 0 else 0.0
				for side in ([-1.0, 1.0] if line >= 0 else [0.0]):
					# Palms (LA's Wilshire and Sunset) except where the
					# streetcar runs the Quarter's oak-shaded neutral ground.
					if style in ["downtown", "midtown"] or line < 0:
						Props.palm(mb, local, Vector3(t, 0.25, side * off), ctx.deco)
					else:
						Props.oak(mb, local, Vector3(t, 0.25, side * off), ctx.deco)
				t += 12.0 if style != "quarter" or line < 0 else 14.0
			if ng >= 1.0:
				local.append([Vector3(ng_mid, 0.4, 0), Vector3(ng, 0.8, 6.0)])
			_done(ctx, local, false, ctx.props)
			mb.xform = frame
		"avenue", "river", "street":
			# Four lanes: a double yellow line down the middle, dashes
			# between the lanes, a solid line along the parking strip.
			if drop < 1.0:
				for z in [-0.12, 0.12]:
					mb.box(Vector3(mid, 0.01, z), Vector3(run, 0.02, 0.12), MARKING)
			_lane_lines(mb, s0, run, cls, drop)
		"quay":
			_dashes(mb, s0, run, 0.0, MARKING, drop)
		"quarter":
			# Old pavers, setts or tiles between the curbs, no markings.
			# It runs into the junction, over the next street's paving: each
			# kind 1.5 mm apart so two never fight in one plane (under the
			# zebra at 0.025; HANDOFF-shimmer.md).
			var skin: int = mb.uvs.size()
			var lift := 0.0015 * PAVER_LAYERS.find(road_surface(city.seed_value, e, cls, style))
			mb.box(Vector3(mid, 0.005 + lift, 0), Vector3(run + 1.0, 0.02, w - 0.4), MeshBuilder.glow(look[0], look[1]))
			mb.scale_uvs(skin, look[2])
		"lane":
			# Pedestrian lane: paved over, bollards at each end, lights strung
			# across.
			var skin: int = mb.uvs.size()
			mb.box(Vector3(length * 0.5, 0.08, 0), Vector3(length, 0.16, w), MeshBuilder.glow(look[0].lightened(0.1), look[1]))
			mb.scale_uvs(skin, look[2])
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
	if cls != "lane" and drop < 1.0:
		# Tar patches and skid marks (not on pavers and tiles).
		for k in ctx.deco.randi_range(0, 2):
			Props.road_mark(mb, Vector3(ctx.deco.randf_range(s0 + 2.0, s0 + run - 2.0), 0.0, ctx.deco.randf_range(-w * 0.3, w * 0.3)), Vector3.RIGHT, ctx.deco)
	var zebra: bool = style in ZEBRA_STYLES and cls != "lane"
	if zebra:
		if s0 > 0.0:
			Props.crosswalk(mb, Vector3(s0 + 1.6, 0.0, 0), Vector3.RIGHT, w - 1.5)
		if s1 > 0.0:
			Props.crosswalk(mb, Vector3(s0 + run - 1.6, 0.0, 0), Vector3.RIGHT, w - 1.5)
	if cls in ["boulevard", "avenue", "river", "street", "quay"] and run > 10.0 and drop < 1.0:
		# Traffic keeps right: towards b on the +z side, towards a on -z.
		var gap := 3.6 if zebra else 1.0
		if s1 > 0.0:
			_approach(mb, s0 + run - gap, 1.0, cls, style == "downtown" or style == "quarter", run > 32.0)
		if s0 > 0.0:
			_approach(mb, s0 + gap, -1.0, cls, style == "downtown" or style == "quarter", run > 32.0)
	# Paint as old as the road under it.
	mb.fade_colors(paint_from, PAINTS, look[0], look[3])
	var wk: Dictionary = city.roadworks.get(e, {})
	if not wk.is_empty():
		_works(ctx, wk, cls, w, frame)
	_controls(ctx, e, frame, [na, nb], [s0, s1])
	mb.xform = Transform3D.IDENTITY


## The junction controls standing on street e (TrafficPlan): the signal
## mast arms of the junctions at its ends and the stop and yield signs of
## its approaches.
static func _controls(ctx: Ctx, e: int, frame: Transform3D, ends: Array, setbacks: Array) -> void:
	var local: Array = []
	ctx.mb.xform = frame
	for i in 2:
		if setbacks[i] <= 0.0:
			continue
		var n: int = ends[i]
		var j: Dictionary = TrafficPlan.junction(ctx.city, n)
		if j.kind == TrafficPlan.SIGNALS:
			for pole in TrafficPlan.poles(ctx.city, n, j):
				if pole.edge == e:
					Props.traffic_light(ctx.mb, local, Vector3(pole.x, KERB, pole.z), pole.arm, pole.heads, pole.face, pole.cabinet, pole.key)
		for sign in TrafficPlan.signs(ctx.city, n, j):
			if sign.edge == e:
				Props.stop_sign(ctx.mb, local, Vector3(sign.x, KERB, sign.z), sign.face, sign.kind)
	if local.is_empty():
		ctx.mb.xform = Transform3D.IDENTITY
		return
	_done(ctx, local, false, ctx.props)


## Dashes between the lanes each way, and a solid line along the parking
## strip, from the class's lanes (StreetPlan.CLASSES); `drop` of the dashes
## worn away (all of them, and the strip line, on tiles).
static func _lane_lines(mb, s0: float, run: float, cls: String, drop := 0.0) -> void:
	var lanes: Dictionary = StreetPlan.CLASSES[cls]
	for side in [-1.0, 1.0]:
		for k in range(1, lanes.lanes):
			_dashes(mb, s0, run, side * (lanes.middle + lanes.lane_w * k), WHITE_LINE, drop)
		if lanes.park > 0.0 and drop < 1.0:
			mb.box(Vector3(s0 + run * 0.5, 0.01, side * (lanes.middle + lanes.lane_w * lanes.lanes)), Vector3(run, 0.02, 0.12), WHITE_LINE)


## Markings where traffic heading `heading` (+1 along the street frame's x,
## -1 against it) reaches a junction whose markings end at x: a stop bar
## across its half of the street, on cycling streets a green bike box ahead
## of the bar, and (if `arrows`) lane arrows behind it.
static func _approach(mb, x: float, heading: float, cls: String, bikes: bool, arrows: bool) -> void:
	var side := heading # right-hand traffic: +x heading drives on +z
	var geo: Dictionary = StreetPlan.CLASSES[cls]
	var inner: float = geo.middle + 0.1
	var outer: float = geo.middle + geo.lanes * geo.lane_w
	if bikes and cls != "street":
		mb.box(Vector3(x - heading * 1.4, 0.011, side * (inner + outer) * 0.5), Vector3(2.6, 0.02, outer - inner), BIKE_GREEN)
		x -= heading * 2.9
	mb.box(Vector3(x, 0.012, side * (inner + outer) * 0.5), Vector3(0.5, 0.02, outer - inner), WHITE_LINE)
	if not arrows:
		return
	# An arrow in each lane, the inner one a left turn.
	var lanes: Array = []
	for k in geo.lanes:
		lanes.append(geo.middle + geo.lane_w * (k + 0.5))
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


## Dashed line along the street frame's x axis at offset z, `drop` of the
## dashes (picked by a hash of where they are) worn away.
static func _dashes(mb, s0: float, run: float, z: float, color: Color, drop := 0.0) -> void:
	var t := s0 + 2.0
	while t < s0 + run - 3.0:
		if drop <= 0.0 or fposmod(sin(t * 12.9898 + z * 78.233) * 43758.5453, 1.0) >= drop:
			mb.box(Vector3(t + 1.5, 0.01, z), Vector3(3.0, 0.02, 0.18), color)
		t += 6.0


## The surface of street e (ROAD_LOOKS): from a hash of the seed and the
## edge, weighted by its district's style (ROAD_MIX), so a street keeps its
## surface every time its cell is built.
static func road_surface(seed_v: int, e: int, cls: String, style: String) -> String:
	if cls == "quarter" or cls == "lane":
		return PAVER_KINDS[posmod(hash([seed_v, e, "pavers"]), PAVER_KINDS.size())]
	var mix: Array = ROAD_MIX.get(style, ROAD_MIX["default"])
	# Tiles only on the two-lane streets and the quays.
	var kinds := 6 if cls == "street" or cls == "quay" else 4
	var total := 0
	for k in kinds:
		total += int(mix[k])
	var roll := posmod(hash([seed_v, e, "road"]), maxi(total, 1))
	for k in kinds:
		roll -= int(mix[k])
		if roll < 0:
			return ROAD_KINDS[k]
	return "worn"


## Roadworks on a street (City.roadworks), drawn in its street frame: the
## curb lane and parking strip dug up from x0 to x1 on the works side,
## fenced in by water-filled barriers (orange and white; a car bursts them)
## along the open lane and across both ends and by mesh panels along the
## kerb, so nobody walks or drives into the pit. Where traffic meets it, a
## taper of cones and a lit arrow board; 15 m before that, a ROAD WORK
## AHEAD sign. Inside: a trench with a steel plate over part of it, a dirt
## heap, fresh tarmac where the work is done, and a roller or a mini digger
## (solid). Leaves mb.xform at `frame`.
static func _works(ctx: Ctx, wk: Dictionary, cls: String, w: float, frame: Transform3D) -> void:
	var mb = ctx.mb
	var rng: RandomNumberGenerator = ctx.deco
	var g: Dictionary = StreetPlan.CLASSES[cls]
	var sd: float = wk.side
	var x0: float = wk.x0
	var x1: float = wk.x1
	var span := x1 - x0
	# The barrier line along the open lane, the kerb line, the pit between.
	var zi: float = float(g.middle) + float(g.lane_w) * (int(g.lanes) - 1) + 0.35
	var zo := w * 0.5 - 0.25
	var zc := (zi + zo) * 0.5
	var depth := zo - zi
	# Traffic on the works side heads +x (side +1) or -x and meets xa first.
	var xa := x0 if sd > 0.0 else x1
	var xb := x1 if sd > 0.0 else x0
	var local: Array = []
	var from: Array
	mb.xform = frame
	# Over the road paint (lines reach 0.02 m), so no line runs through the pit.
	mb.box(Vector3((x0 + x1) * 0.5, 0.025, sd * zc), Vector3(span, 0.006, depth), MeshBuilder.glow(WORKS_DIRT, 1.0))
	var fresh := span * rng.randf_range(0.25, 0.4)
	mb.box(Vector3(xb - sd * fresh * 0.5, 0.028, sd * zc), Vector3(fresh, 0.006, depth), MeshBuilder.glow(Color(0.12, 0.12, 0.13), MeshBuilder.ASPHALT))
	var dug := span - fresh - 3.0
	var tx := xa + sd * (2.5 + dug * 0.5)
	var tz := sd * (zc + depth * 0.15)
	mb.box(Vector3(tx, 0.029, tz), Vector3(dug, 0.006, 1.1), MeshBuilder.glow(Color(0.15, 0.11, 0.08), 1.0))
	mb.box(Vector3(tx - sd * dug * 0.25, 0.04, tz), Vector3(2.4, 0.03, 1.5), Color(0.27, 0.26, 0.25))
	mb.clump(Vector3(tx + sd * dug * 0.15, 0.2, sd * (zc - depth * 0.22)), Vector3(1.2, 0.55, 0.7), WORKS_DIRT.darkened(0.15), rng.randi(), 7, 3)
	var mx := xb - sd * maxf(fresh * 0.5, 2.2)
	if rng.randf() < 0.5:
		_roller(mb, local, Vector3(mx, 0, sd * zc))
	else:
		_digger(mb, local, Vector3(mx, 0, sd * zc), -sd)
	var orange := MeshBuilder.glow(Color(0.95, 0.45, 0.1), MeshBuilder.GLOSS)
	var white := MeshBuilder.glow(Color(0.93, 0.93, 0.9), MeshBuilder.GLOSS)
	# Along the open lane, 2 m units that burst two at a time.
	var n := maxi(2, roundi(span / 2.0))
	var unit := span / n
	var k := 0
	while k < n:
		from = Props._start(mb, null)
		var m := mini(2, n - k)
		for j in m:
			_barrier(mb, Vector3(x0 + unit * (k + j + 0.5), 0, sd * zi), Vector2(unit - 0.06, 0.45), orange if (k + j) % 2 == 0 else white)
		local.append([Vector3(x0 + unit * (k + m * 0.5), 0.5, sd * zi), Vector3(unit * m, 1.0, 0.5)])
		Props._breaks(mb, local, from, "roadworks", null)
		k += m
	# Across both ends.
	var cnt := maxi(1, roundi(depth / 2.0))
	for xe in [x0, x1]:
		from = Props._start(mb, null)
		for j in cnt:
			_barrier(mb, Vector3(xe, 0, sd * (zi + depth / cnt * (j + 0.5))), Vector2(0.45, depth / cnt - 0.06), white if j % 2 == 0 else orange)
		local.append([Vector3(xe, 0.5, sd * zc), Vector3(0.5, 1.0, depth)])
		Props._breaks(mb, local, from, "roadworks", null)
	# Mesh panels on feet along the kerb.
	from = Props._start(mb, null)
	var mesh := MeshBuilder.glow(Color(0.98, 0.5, 0.12), MeshBuilder.GLOSS)
	mb.box(Vector3((x0 + x1) * 0.5, 0.55, sd * zo), Vector3(span, 0.9, 0.05), mesh)
	mb.box(Vector3((x0 + x1) * 0.5, 1.02, sd * zo), Vector3(span, 0.06, 0.08), mesh)
	var f := 0.0
	while f <= span + 0.01:
		mb.box(Vector3(x0 + f, 0.06, sd * zo), Vector3(0.6, 0.12, 0.3), Color(0.2, 0.2, 0.21))
		f += span / maxf(roundf(span / 2.5), 1.0)
	local.append([Vector3((x0 + x1) * 0.5, 0.6, sd * zo), Vector3(span, 1.2, 0.3)])
	Props._breaks(mb, local, from, "roadworks", null)
	# The taper: cones from the kerb out to the barrier line ahead of it.
	from = Props._start(mb, null)
	var c0 := Vector3(xa - sd * (0.6 + float(ctx.city.WORKS_TAPER)), 0, sd * (zo - 0.2))
	var c1 := Vector3(xa - sd * 0.6, 0, sd * zi)
	for i in 5:
		_cone(mb, c0.lerp(c1, i / 4.0), orange, white)
	var d := c1 - c0
	local.append([(c0 + c1) * 0.5 + Vector3(0, 0.4, 0), Vector3(d.length() + 0.4, 0.8, 0.4), atan2(-d.z, d.x)])
	Props._breaks(mb, local, from, "roadworks", null)
	# A lit arrow board just inside, pointing traffic over to the open lanes.
	from = Props._start(mb, null)
	var ab := Vector3(xa + sd * 1.3, 0, sd * zc)
	var dark := Color(0.14, 0.14, 0.15)
	mb.box(ab + Vector3(0, 0.45, 0), Vector3(1.0, 0.4, 1.3), MeshBuilder.glow(Color(0.95, 0.75, 0.15), MeshBuilder.GLOSS))
	mb.box(ab + Vector3(0, 1.1, 0), Vector3(0.1, 1.0, 0.1), dark)
	mb.box(ab + Vector3(0, 1.9, 0), Vector3(0.1, 0.9, 1.7), dark)
	var face := ab.x - sd * 0.06
	var amber := MeshBuilder.glow(Color(1.0, 0.7, 0.2), MeshBuilder.GLOW_NEON)
	mb.box(Vector3(face, 1.9, sd * (zc + 0.15)), Vector3(0.02, 0.12, 0.7), amber)
	mb.tri(Vector3(face, 1.65, sd * (zc - 0.2)), Vector3(face, 2.15, sd * (zc - 0.2)), Vector3(face, 1.9, sd * (zc - 0.6)), Vector3(-sd, 0, 0), amber)
	local.append([ab + Vector3(0, 0.9, 0), Vector3(1.0, 1.8, 1.3)])
	Props._breaks(mb, local, from, "roadworks", null)
	_works_sign(mb, local, Vector3(xa - sd * 15.0, 0, sd * (w * 0.5 - 0.9)), sd)
	_done(ctx, local, false, ctx.props)
	mb.xform = frame


## A water-filled barrier on the ground at p, `size` its footprint (x, z):
## a wide base and a narrower top.
static func _barrier(mb, p: Vector3, size: Vector2, color: Color) -> void:
	mb.box(p + Vector3(0, 0.28, 0), Vector3(size.x, 0.56, size.y), color)
	var top := Vector3(size.x, 0.3, size.y * 0.55) if size.x > size.y else Vector3(size.x * 0.55, 0.3, size.y)
	mb.box(p + Vector3(0, 0.71, 0), top, color)


## A traffic cone on its black base.
static func _cone(mb, p: Vector3, orange: Color, white: Color) -> void:
	mb.box(p + Vector3(0, 0.02, 0), Vector3(0.42, 0.04, 0.42), Color(0.12, 0.12, 0.12))
	mb.limb(p + Vector3(0, 0.04, 0), p + Vector3(0, 0.75, 0), 0.17, 0.035, orange, 6, false)
	mb.limb(p + Vector3(0, 0.38, 0), p + Vector3(0, 0.52, 0), 0.112, 0.085, white, 6, false)


## A ROAD WORK AHEAD sign on an A-frame at p: an orange diamond with a
## black border and three lines of black lettering, leaning back so it reads
## from above, facing traffic that heads `heading` (+1 or -1 along x).
static func _works_sign(mb, out: Array, p: Vector3, heading: float) -> void:
	var from := Props._start(mb, null)
	var t := deg_to_rad(58.0)
	var u := Vector3(heading * sin(t), cos(t), 0)
	var n := Vector3(-heading * cos(t), sin(t), 0)
	var a := Vector3(0, 0, 1)
	var c := p + Vector3(0, 1.15, 0)
	var steel := MeshBuilder.glow(Color(0.35, 0.36, 0.38), MeshBuilder.METAL)
	for s in [-1.0, 1.0]:
		mb.limb(p + Vector3(-heading * 0.25, 0, s * 0.4), c - u * 0.2 + a * s * 0.32 - n * 0.03, 0.025, 0.025, steel, 4, false)
		mb.limb(p + Vector3(heading * 0.7, 0, s * 0.4), c + u * 0.4 + a * s * 0.2 - n * 0.03, 0.025, 0.025, steel, 4, false)
	var black := Color(0.06, 0.06, 0.06)
	mb.quad(c + u * 0.88, c + a * 0.88, c - u * 0.88, c - a * 0.88, n, black)
	var q := c + n * 0.01
	mb.quad(q + u * 0.78, q + a * 0.78, q - u * 0.78, q - a * 0.78, n, MeshBuilder.glow(Color(0.98, 0.55, 0.1), MeshBuilder.GLOSS))
	for line in [[0.25, 0.21], [0.0, 0.25], [-0.25, 0.3]]:
		var r: Vector3 = c + n * 0.02 + u * float(line[0])
		var hw: float = line[1]
		mb.quad(r + u * 0.055 - a * hw, r + u * 0.055 + a * hw, r - u * 0.055 + a * hw, r - u * 0.055 - a * hw, n, black)
	out.append([p + Vector3(heading * 0.2, 0.7, 0), Vector3(1.1, 1.4, 1.3)])
	Props._breaks(mb, out, from, "roadworks", null)


## A tandem road roller along x at p, under a canopy (its collider solid).
static func _roller(mb, out: Array, p: Vector3) -> void:
	var yellow := MeshBuilder.glow(Color(0.93, 0.7, 0.12), MeshBuilder.GLOSS)
	var drum := MeshBuilder.glow(Color(0.36, 0.37, 0.38), MeshBuilder.METAL)
	var dark := Color(0.13, 0.13, 0.14)
	for dx in [-1.05, 1.05]:
		mb.limb(p + Vector3(dx, 0.5, -0.62), p + Vector3(dx, 0.5, 0.62), 0.5, 0.5, drum, 8, true)
		mb.box(p + Vector3(dx, 0.98, 0), Vector3(1.1, 0.12, 1.36), yellow)
	mb.box(p + Vector3(0, 0.85, 0), Vector3(1.0, 0.8, 1.2), yellow)
	mb.box(p + Vector3(0, 1.4, 0), Vector3(0.7, 0.3, 0.6), dark)
	for cx in [-0.45, 0.45]:
		for cz in [-0.5, 0.5]:
			mb.box(p + Vector3(cx, 1.85, cz), Vector3(0.07, 0.9, 0.07), dark)
	mb.box(p + Vector3(0, 2.33, 0), Vector3(1.15, 0.07, 1.25), yellow)
	out.append([p + Vector3(0, 1.0, 0), Vector3(3.2, 2.0, 1.4)])


## A mini digger along x at p, its arm reaching `toward` (+1 or -1 on x)
## into the trench (its collider solid).
static func _digger(mb, out: Array, p: Vector3, toward: float) -> void:
	var yellow := MeshBuilder.glow(Color(0.93, 0.7, 0.12), MeshBuilder.GLOSS)
	var dark := Color(0.13, 0.13, 0.14)
	for z in [-0.55, 0.55]:
		mb.box(p + Vector3(0, 0.22, z), Vector3(2.0, 0.44, 0.38), dark)
	mb.box(p + Vector3(0, 0.62, 0), Vector3(1.5, 0.36, 1.35), yellow)
	mb.box(p + Vector3(-toward * 0.3, 1.25, 0.25), Vector3(0.85, 0.9, 0.75), MeshBuilder.glow(Color(0.2, 0.25, 0.3), MeshBuilder.GLASS))
	mb.box(p + Vector3(-toward * 0.3, 1.73, 0.25), Vector3(0.95, 0.07, 0.85), yellow)
	var elbow := p + Vector3(toward * 1.6, 2.0, -0.25)
	mb.limb(p + Vector3(toward * 0.6, 0.9, -0.25), elbow, 0.13, 0.1, yellow, 5, false)
	var tip := p + Vector3(toward * 2.5, 0.45, -0.25)
	mb.limb(elbow, tip, 0.09, 0.07, yellow, 5, false)
	mb.box(tip + Vector3(0, -0.1, 0), Vector3(0.5, 0.35, 0.55), dark)
	out.append([p + Vector3(toward * 0.5, 1.0, 0), Vector3(3.2, 2.0, 1.5)])


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
		ctx.props.append([mb.xform * col[0], col[1], yaw + (col[2] if col.size() > 2 else 0.0)] + col.slice(3))


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
		ctx.mb.prism(strip, -SLAB, 0.0, MeshBuilder.glow(ASPHALT, MeshBuilder.ASPHALT), CONCRETE.darkened(0.3))
		if not plan.is_water_point(mid + side * (w + 6.0)):
			continue
		var r0: Vector2 = a + dir * (t0 if t0 >= 0.0 else -ext0) + side * (outer - 0.3)
		var r1: Vector2 = b - dir * (t1 if t1 >= 0.0 else -ext1) + side * (outer - 0.3)
		if (r1 - r0).dot(dir) < 1.0:
			continue
		Props.fence(ctx.mb, [], _v3(r0, 0.0), _v3(r1, 0.0), RAIL_WHITE, 0.9)
		var m: Vector2 = (r0 + r1) * 0.5
		ctx.out.append([_v3(m, 2.0), Vector3(r0.distance_to(r1) + 0.6, 4.0, 0.8), atan2(-(r1 - r0).y, (r1 - r0).x)])
		if cls == "quay":
			# Mooring bollards along the wharf edge.
			var t := 6.0
			while t < r0.distance_to(r1) - 3.0:
				ctx.mb.cylinder(_v3(r0 + dir * t - side * 0.8, 0.0), 0.25, 0.6, Color(0.15, 0.15, 0.16), 6)
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
	_lane_lines(mb, s0, run, "bridge")
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
static func split(r: Rect2, size: Vector2) -> Array:
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
	if district == "wards" and city.faces_square(ctx.face):
		district = "painted"
	var grounds: bool = ctx.plan.set_piece(ctx.face) == "grounds"
	ctx.edge = ctx.plan.edge_distance(ctx.plan.faces[ctx.face].center, true)
	var lawn: bool = style in LAWNS or grounds
	_flat_in_front(ctx, ctx.ff, ctx.lot, KERB + 0.01, _paved(LOT_GROUND.green if lawn else LOT_GROUND.get(district, PAVEMENT)))
	if style in LAWNS:
		_use_parcel(ctx, ctx.rect)
		match style:
			"green":
				_liberty_green(ctx)
			"esplanade":
				_esplanade(ctx)
			"circle":
				_founders_circle(ctx)
			"square":
				_square_park(ctx)
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
		if grounds:
			# City Hall stands alone on its lawn.
			rest = []
			district = "grounds"
	var docks_ff = docks_frame(ctx.plan, ctx.face) if district == "docks" and lm.is_empty() else null
	if docks_ff != null:
		# Yards turn their backs to the quay, so cranes reach over the water.
		var r: Rect2 = StreetPlan.largest_rect(docks_ff.affine_inverse() * ctx.lot)
		for p in split(r, Vector2(PARCEL_MAX.docks.x, INF)):
			_use_parcel(ctx, p[0], p[1], docks_ff)
			_docks(ctx, -1)
	else:
		var k := -1
		for r in rest:
			if r.size.x < 9.0 or r.size.y < 9.0:
				continue
			for p in split(r, PARCEL_MAX.get(district, PARCEL_DEFAULT)):
				k += 1
				var place: Dictionary = city.place_at(ctx.face, k) if lm.is_empty() else {}
				if not place.is_empty():
					_shop_parcel(ctx, p[0], place, district)
					continue
				_use_parcel(ctx, p[0], p[1])
				if ctx.hx < 4.0 or ctx.hz < 4.0:
					continue
				_district_parcel(ctx, district)
	var look := "downtown" if district == "midtown" else district
	_filler(ctx, look)
	_furniture(ctx, look)


## A place (places.gd) on parcel `r`: its storefront at the front, and
## the district's usual buildings on the strips beside and behind it.
static func _shop_parcel(ctx: Ctx, r: Rect2, place: Dictionary, district: String) -> void:
	var shop: Rect2 = place.rect
	_use_parcel(ctx, shop)
	var local := _at(ctx, Vector3(0, KERB, 0), PI)
	Buildings.storefront(ctx.mb, local, ctx.hx * 2.0, ctx.hz * 2.0, place.type, ctx.rng)
	_done(ctx, local)
	var gap := 0.6
	for rest in [Rect2(r.position.x, r.position.y, shop.position.x - gap - r.position.x, r.size.y),
			Rect2(shop.end.x + gap, r.position.y, r.end.x - shop.end.x - gap, r.size.y),
			Rect2(shop.position.x, r.position.y, shop.size.x, shop.position.y - gap - r.position.y)]:
		if rest.size.x < 9.0 or rest.size.y < 9.0:
			continue
		_use_parcel(ctx, rest)
		if ctx.hx >= 4.0 and ctx.hz >= 4.0:
			_district_parcel(ctx, district)


## A frame for a docks block with the quay behind it (+y away from the
## water), or null when it has no quay.
static func docks_frame(plan, face: int):
	var inner: PackedVector2Array = plan.inner(face)
	var n := inner.size()
	var best := -1
	var best_len := 0.0
	for k in n:
		if plan.side_class(face, k) != "quay":
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
	if CIVIC_LANDMARKS.has(id):
		_civic(ctx, CIVIC_LANDMARKS[id], GRASS if id in ["city_hall", "county_courthouse", "public_library"] else PLAZA)
		return
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
	# Toward the city's edge the towers thin out to low blocks (EDGE_LOW),
	# and on the edge some lots stand empty, parked or green (EDGE_OPEN).
	var low := clampf(ctx.edge / EDGE_LOW, 0.0, 1.0)
	if ctx.edge < EDGE_OPEN:
		var pick := hash([ctx.cell, ctx.hx, ctx.hz, ctx.frame.origin.x]) % 100
		if pick < 9:
			_parking(ctx)
			return
		if pick < 15:
			_pocket_park(ctx)
			return
	match district:
		"midtown":
			if roll < 0.1 and ctx.hx >= 11.0 and ctx.hz >= 9.0 and low >= 1.0:
				_civic(ctx, "led_tower", PLAZA)
			elif roll < 0.16:
				_plaza(ctx)
			elif roll < 0.55 * low and ctx.hx >= 15.0 and ctx.hz >= 15.0:
				_kit(ctx, Skyline, MIDTOWN_TOWERS[ctx.rng.randi() % MIDTOWN_TOWERS.size()], PLAZA)
			else:
				_downtown(ctx, lerpf(0.5, 1.4, low))
		"brownstone":
			if roll < 0.08:
				_pocket_park(ctx)
			else:
				_rows(ctx, "brownstone_row", 14.0)
		"painted":
			_rows(ctx, "painted_lady_row", 14.0)
		"chinatown":
			if roll < 0.06:
				_pocket_park(ctx)
			else:
				_rows(ctx, "chinatown_row", 14.0, PAVEMENT)
		"havana":
			if ctx.front_cls in ["avenue", "boulevard"] or roll < 0.4:
				_rows(ctx, "havana_row", 14.0, Color(0.84, 0.79, 0.68), true)
			elif roll < 0.46:
				_pocket_park(ctx)
			elif roll < 0.72:
				_bungalows(ctx)
			else:
				_downtown(ctx, 0.4)
		"beach":
			# Deco hotels face the sea along Ocean Drive; condo towers and
			# lower apartment blocks stand behind.
			var front := Vector2(ctx.frame.origin.x, ctx.frame.origin.z) + Vector2(ctx.frame.basis.z.x, ctx.frame.basis.z.z) * ctx.hz
			var seaward := Vector2(-StreetPlan.GULF_DIR.y, StreetPlan.GULF_DIR.x)
			if ctx.plan.sea_front(front) and Vector2(ctx.frame.basis.z.x, ctx.frame.basis.z.z).dot(seaward) > 0.5:
				_kit(ctx, Civic, "deco_hotel", PLAZA, 1.0)
			elif roll < 0.08:
				_pocket_park(ctx)
			elif roll < 0.4 * low and ctx.hx >= 15.0 and ctx.hz >= 15.0:
				_kit(ctx, Skyline, "highrise_mid", PLAZA)
			elif roll < 0.7:
				_kit(ctx, Civic, "deco_hotel", PLAZA, 1.0)
			else:
				_downtown(ctx, lerpf(0.4, 0.8, low))
		"downtown":
			if roll < 0.1:
				_plaza(ctx)
			elif roll < 0.18:
				_parking(ctx)
			elif roll < 0.5 * low and ctx.hx >= 15.0 and ctx.hz >= 15.0:
				_kit(ctx, Skyline, GILT_TOWERS[ctx.rng.randi() % GILT_TOWERS.size()], PLAZA)
			else:
				_downtown(ctx, lerpf(0.5, 1.0, low))
		"wards":
			if ctx.front_cls in ["avenue", "boulevard"] and roll < 0.75:
				_strip(ctx)
			elif roll < 0.06:
				_pocket_park(ctx)
			elif roll < 0.11 and ctx.hx < 30.0:
				_chapel(ctx)
			elif roll < 0.2 and ctx.hx >= 20.0 and ctx.hz >= 13.0:
				_kit(ctx, Shady, "housing_project", GRASS.darkened(0.1), 1.0)
			elif roll < 0.32:
				_bungalows(ctx)
			elif roll < 0.36:
				_kit(ctx, Shady, "burned_lot", MUD, 1.5)
			else:
				_wards(ctx, "")
		"docks":
			if roll < 0.1:
				_parking(ctx)
			elif roll < 0.36:
				var kind: String = DOCKS_SHADY[ctx.rng.randi() % DOCKS_SHADY.size()]
				if kind == "abandoned_warehouse" and ctx.hz >= 16.0:
					_skid_row(ctx)
				else:
					_kit(ctx, Shady, kind, YARD)
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
				"beach", "havana":
					if rng.randf() < 0.5:
						Props.palm(ctx.mb, props, at, rng)
				"chinatown":
					if rng.randf() < 0.25:
						Props.planter(ctx.mb, props, at)
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
	# Back-yard boundaries, each household's own (a generator of their own,
	# so the houses keep theirs).
	var yr := RandomNumberGenerator.new()
	yr.seed = hash([rng.seed, "yard fences"])
	for k in range(1, slots):
		var x := -hx + slot_w * k
		_yard_fence(mb, props, Vector3(x, KERB, -3.0), Vector3(x, KERB, 3.0), yr)
	_yard_fence(mb, props, Vector3(-hx + 0.5, KERB, 0), Vector3(hx - 0.5, KERB, 0), yr)
	if rng.randf() < 0.5:
		Props.oak(mb, props, Vector3(rng.randf_range(-hx * 0.7, hx * 0.7), KERB, rng.randf_range(-1.5, 1.5)), rng)
	_done(ctx, props, false, ctx.props)


## One back-yard boundary from a to b (along X or Z) in a look of its own:
## wood rails, a board or slat privacy fence, chain-link, ply sheets,
## pickets (short runs), or none; its height 0.8 to 1.1 of the usual, with
## its collider.
static func _yard_fence(mb, out: Array, a: Vector3, b: Vector3, r: RandomNumberGenerator) -> void:
	var style: String = Kit._roll([["rail", 25], ["board", 20], ["chain", 18], ["slat", 10], ["ply", 12], ["picket", 10], ["", 5]], {}, r)[0]
	if style == "":
		return
	if style == "picket" and a.distance_to(b) > 12.0:
		style = "rail"
	var paints: Array = Kit.FENCE_COLORS[style]
	var paint: Color = FENCE_WOOD if style == "rail" else paints[r.randi() % paints.size()]
	Kit._fence_run(mb, out, a, b, style, paint, snappedf(Kit.FENCES[style][0] * r.randf_range(0.8, 1.1), 0.05))


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


## A kit building (`kit`: Skyline or Shady) on the parcel, front to the
## street, as big as the parcel but no more than `grow` times the kit's own
## lot, set at the front.
static func _kit(ctx: Ctx, kit, kind: String, ground: Color, grow := 1.3) -> void:
	_ground(ctx, ground)
	var size: Vector2 = kit.default_size(kind) * grow
	size = Vector2(minf(size.x, ctx.hx * 2.0), minf(size.y, ctx.hz * 2.0))
	var local := _at(ctx, Vector3(0, KERB, ctx.hz - size.y * 0.5), PI)
	kit.build(kind, ctx.mb, local, size, ctx.rng)
	_done(ctx, local)


## A run-down commercial strip on a Wards avenue or boulevard: liquor
## store, pawn shop, check casher, motel and SRO side by side along the
## front, each at its own width, a burned lot in a gap too narrow for a
## shop, and shotguns on the back street.
static func _strip(ctx: Ctx) -> void:
	var rng := ctx.rng
	var hx := ctx.hx
	var hz := ctx.hz
	_ground(ctx, Shady.SIDEWALK)
	var back: bool = ctx.open["-z"] and hz >= 22.0
	var deep := hz if back else hz * 2.0
	var x := -hx
	while x < hx - 6.0:
		var kind: String = STRIP_SHOPS[rng.randi() % STRIP_SHOPS.size()]
		var size: Vector2 = Shady.default_size(kind)
		if size.x > hx - x:
			kind = "burned_lot"
			size = Vector2(hx - x, minf(20.0, deep))
		var w := size.x
		if hx - x - w < 8.0:
			w = hx - x
		var d := minf(size.y, deep)
		var local := _at(ctx, Vector3(x + w * 0.5, KERB, hz - d * 0.5), PI)
		Shady.build(kind, ctx.mb, local, Vector2(w - 0.4, d), rng)
		_done(ctx, local)
		x += w
	if back:
		var slots := maxi(2, int(hx * 2 / 6.8))
		var slot_w := hx * 2 / slots
		for k in slots:
			if rng.randf() < 0.15:
				continue
			var d := minf(12.0, hz - 2.0)
			var local := _at(ctx, Vector3(-hx + slot_w * (k + 0.5), KERB, -hz + d * 0.5), 0.0)
			Buildings.shotgun(ctx.mb, local, minf(5.4, slot_w - 0.6), d, rng, rng.randf() < 0.3)
			_done(ctx, local)


## A row of barred bungalows (LA's flatlands): small stucco houses behind
## chain-link, one per 12 m lot, on each street side of the parcel.
static func _bungalows(ctx: Ctx) -> void:
	var hx := ctx.hx
	var hz := ctx.hz
	_ground(ctx, GRASS.darkened(0.08))
	var both: bool = ctx.open["-z"] and hz >= 14.0
	var slots := maxi(1, int(hx * 2 / 12.0))
	var slot_w := hx * 2 / slots
	for side in [1.0, -1.0]:
		if not ctx.open["+z" if side > 0 else "-z"] or (side < 0 and not both):
			continue
		var d := minf(22.0, hz if both else hz * 2.0)
		for k in slots:
			var local := _at(ctx, Vector3(-hx + slot_w * (k + 0.5), KERB, side * (hz - d * 0.5)), PI if side > 0 else 0.0)
			Shady.build("bungalow_barred", ctx.mb, local, Vector2(slot_w - 0.3, d), ctx.rng)
			_done(ctx, local)


## Skid row: an abandoned warehouse at the back of the lot and a line of
## tents and tarps along the sidewalk in front of it.
static func _skid_row(ctx: Ctx) -> void:
	_ground(ctx, YARD)
	var tents := 6.0
	var d := minf(30.0, ctx.hz * 2.0 - tents - 1.0)
	var w := minf(40.0, ctx.hx * 2.0)
	var local := _at(ctx, Vector3(0, KERB, -ctx.hz + d * 0.5), PI)
	Shady.build("abandoned_warehouse", ctx.mb, local, Vector2(w, d), ctx.rng)
	_done(ctx, local)
	var row := _at(ctx, Vector3(0, KERB, ctx.hz - tents * 0.5), PI)
	Shady.build("tent_row", ctx.mb, row, Vector2(ctx.hx * 2.0 - 1.0, tents), ctx.rng)
	_done(ctx, row, false, ctx.props)


## Gilt District: towers on a stone plaza, sized to the block. Kept mid-rise
## so roofs don't swallow the street under the 3/4 camera.
## `tall` scales the heights (Midtown stands taller).
static func _downtown(ctx: Ctx, tall := 1.0) -> void:
	var rng := ctx.rng
	var hx := ctx.hx
	var hz := ctx.hz
	_ground(ctx, PLAZA)
	match rng.randi() % 3:
		0:
			_tower(ctx, Vector3.ZERO, hx * 2 - 6.0, hz * 2 - 6.0, rng.randf_range(18.0, 30.0) * tall)
			var local := _at(ctx, Vector3(0, KERB, 0), 0.0)
			for x in [-hx + 1.5, hx - 1.5]:
				Props.planter(ctx.mb, local, Vector3(x, 0, hz - 1.5))
			_done(ctx, local, false, ctx.props)
		1:
			for x in [-hx * 0.5, hx * 0.5]:
				_tower(ctx, Vector3(x, 0, -1.5), hx - 2.5, hz * 2 - 7.0, rng.randf_range(14.0, 26.0) * tall)
		_:
			for x in [-hx * 0.5, hx * 0.5]:
				for z in [-hz * 0.5, hz * 0.5]:
					_tower(ctx, Vector3(x, 0, z), hx - 3.0, hz - 3.0, rng.randf_range(11.0, 22.0) * tall)


static func _tower(ctx: Ctx, pos: Vector3, w: float, d: float, h: float) -> void:
	var local := _at(ctx, pos + Vector3(0, KERB, 0), PI)
	Buildings.tower(ctx.mb, local, maxf(w, 8.0), maxf(d, 8.0), h, ctx.rng)
	_done(ctx, local)


## A Gilt plaza: paving, a fountain or a monument (an abstract statue on
## a plinth), palms and benches.
static func _plaza(ctx: Ctx) -> void:
	_ground(ctx, PLAZA.lightened(0.08))
	var mb = ctx.mb
	var statue := ctx.rng.randf() < 0.45 and minf(ctx.hx, ctx.hz) >= 10.0
	if statue:
		var s := minf(20.0, minf(ctx.hx, ctx.hz) * 2.0 - 8.0)
		var monument := _at(ctx, Vector3(0, KERB, 0), PI)
		Skyline.build("statue_plinth", mb, monument, Vector2(s, s), ctx.rng)
		_done(ctx, monument, false)
	var local := _at(ctx, Vector3(0, KERB, 0), 0.0)
	for k in 5:
		var z := -ctx.hz + (k + 0.5) * ctx.hz * 0.4
		if not statue or absf(z) > 10.5:
			mb.box(Vector3(0, 0.02, z), Vector3(ctx.hx * 2, 0.02, 0.15), PLAZA.darkened(0.08))
	if not statue:
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
		# Over the quay road and its sidewalk to the water.
		Props.crane(mb, crane, Vector3.ZERO, 21.0 + StreetPlan.QUAY_SET + StreetPlan.CLASSES.quay.width * 0.5 + StreetPlan.SIDEWALK)
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


# --- Civic centre and set pieces ---------------------------------------------------

## A civic kit building filling the parcel, its front to the street.
static func _civic(ctx: Ctx, kind: String, ground: Color) -> void:
	_ground(ctx, ground)
	var local := _at(ctx, Vector3(0, KERB, 0), PI)
	Civic.build(kind, ctx.mb, local, Vector2(ctx.hx * 2.0, ctx.hz * 2.0), ctx.rng)
	_done(ctx, local)


## Rows of terraced houses (`kind`, a civic kit row) along the parcel's
## street sides, each `depth` deep, with the gardens behind them meeting in
## a green core.
static func _rows(ctx: Ctx, kind: String, depth: float, ground := GRASS, palms := false) -> void:
	var hx := ctx.hx
	var hz := ctx.hz
	_ground(ctx, ground)
	var d := minf(depth, hz - 1.0)
	for side in [1.0, -1.0]:
		if not ctx.open["+z" if side > 0 else "-z"] or (side < 0 and hz < depth + 4.0):
			continue
		var x := -hx
		while x < hx - 6.0:
			var w := minf(36.0, hx - x)
			if hx - x - w < 8.0:
				w = hx - x
			var local := _at(ctx, Vector3(x + w * 0.5, KERB, side * (hz - d * 0.5)), PI if side > 0 else 0.0)
			Civic.build(kind, ctx.mb, local, Vector2(w - 0.4, d), ctx.rng)
			_done(ctx, local)
			x += w
	var props := _at(ctx, Vector3(0, KERB, 0), 0.0)
	for k in int(hx / 9.0):
		if ctx.rng.randf() < 0.6:
			var at := Vector3(-hx + 6.0 + k * 18.0, 0, ctx.rng.randf_range(-1.5, 1.5))
			if palms:
				Props.palm(ctx.mb, props, at, ctx.rng)
			else:
				Props.oak(ctx.mb, props, at, ctx.rng)
	_done(ctx, props, false, ctx.props)


## The Esplanade: a lawn between the drives with a reflecting pool down the
## middle, gravel walks and rows of elms either side, benches facing it.
static func _esplanade(ctx: Ctx) -> void:
	var mb = ctx.mb
	var hx := ctx.hx
	var hz := ctx.hz
	# The Veterans Arch closes the west end of the pool when there is room
	# (the Mall's memorial at the end of its reflecting pool).
	var arch := hx * 2.0 >= 150.0 and hz * 2.0 >= 30.0
	var arch_w := 34.0 if arch else 0.0
	var pool_len := minf(120.0, hx * 2.0 - 24.0 - arch_w)
	var pool := _at(ctx, Vector3(arch_w * 0.5, KERB, 0), PI / 2)
	Civic.build("reflecting_pool", mb, pool, Vector2(minf(24.0, hz * 2.0 - 16.0), pool_len), ctx.rng)
	_done(ctx, pool, false, ctx.props)
	var ax := arch_w * 0.5 - pool_len * 0.5 - 16.0
	if arch:
		var monument := _at(ctx, Vector3(ax, KERB, 0), PI / 2)
		Skyline.build("memorial_arch", mb, monument, Vector2(minf(36.0, hz * 2.0 - 14.0), 28.0), ctx.rng)
		_done(ctx, monument)
	var local := _at(ctx, Vector3(0, KERB, 0), 0.0)
	for z in [-hz + 6.0, hz - 6.0]:
		mb.box(Vector3(0, 0.03, z), Vector3(hx * 2.0 - 4.0, 0.04, 3.0), PLAZA.lightened(0.08))
	var x := -hx + 6.0
	while x <= hx - 6.0:
		for z in [-hz + 2.5, hz - 2.5]:
			Props.oak(mb, local, Vector3(x, 0, z), ctx.rng)
		if absf(x) > 8.0 and int((x + hx) / 12.0) % 2 == 0 and not (arch and absf(x + 6.0 - ax) < 16.0):
			Props.bench(mb, local, Vector3(x + 6.0, 0, hz - 8.2), 0.0)
			Props.bench(mb, local, Vector3(x + 6.0, 0, -hz + 8.2), PI)
		x += 12.0
	_done(ctx, local, false, ctx.props)


## A traffic circle's lawn: walks from the middle out to the crossings,
## palms round it, and the Founders Obelisk at the centre of Founders
## Circle (a statue or a fountain at the others).
static func _founders_circle(ctx: Ctx) -> void:
	var mb = ctx.mb
	var r := minf(ctx.hx, ctx.hz)
	var local := _at(ctx, Vector3(0, KERB, 0), 0.0)
	mb.cylinder(Vector3(0, 0.0, 0), r + 2.0, 0.04, PLAZA, 20)
	mb.cylinder(Vector3(0, 0.0, 0), r - 1.0, 0.06, MeshBuilder.glow(GRASS, MeshBuilder.GRASS), 20)
	var saved: Transform3D = mb.xform
	for k in 4:
		mb.xform = saved * Transform3D(Basis(Vector3.UP, PI / 4 + k * PI / 2), Vector3.ZERO)
		mb.box(Vector3(0, 0.08, -r * 0.5), Vector3(2.4, 0.04, r), PLAZA)
	mb.xform = saved
	for k in 8:
		var a := TAU * (k + 0.5) / 8.0
		Props.palm(mb, local, Vector3(cos(a), 0, sin(a)) * (r - 4.0), ctx.rng)
	_done(ctx, local, false, ctx.props)
	# Founders Circle has the obelisk; the other circles a statue (Liberty
	# Circle) or a fountain.
	var id: String = ctx.plan.set_piece_id(ctx.face)
	var middle := _at(ctx, Vector3(0, KERB, 0), PI)
	var s := minf(28.0, r * 1.4)
	if id == "founders_circle":
		Civic.build("founders_obelisk", mb, middle, Vector2(s, s), ctx.rng)
	elif id == "liberty_circle":
		Skyline.statue_plinth(mb, middle, minf(22.0, s), minf(22.0, s), ctx.rng)
	else:
		Skyline._fountain(mb, middle, Vector3(0, 0.02, 0), Vector3(minf(14.0, r * 0.7), 0, minf(14.0, r * 0.7)))
	_done(ctx, middle)


## Moreau Square: a lawn with walks corner to corner, a fountain where they
## meet and oaks round the edge.
static func _square_park(ctx: Ctx) -> void:
	var mb = ctx.mb
	var hx := ctx.hx
	var hz := ctx.hz
	var local := _at(ctx, Vector3(0, KERB, 0), 0.0)
	var saved: Transform3D = mb.xform
	for s in [-1.0, 1.0]:
		var diag := Vector3(hx * 2.0, 0, hz * 2.0 * s)
		mb.xform = saved * Transform3D(Basis(Vector3.UP, atan2(-diag.z, diag.x)), Vector3.ZERO)
		mb.box(Vector3(0, 0.03, 0), Vector3(diag.length() - 4.0, 0.04, 2.4), PLAZA)
	mb.xform = saved
	mb.cylinder(Vector3(0, 0, 0), 4.0, 0.5, Buildings.STONE, 12)
	mb.cylinder(Vector3(0, 0.05, 0), 3.6, 0.5, Color(0.35, 0.6, 0.75), 12)
	mb.cylinder(Vector3(0, 0.5, 0), 0.5, 2.2, Buildings.STONE.lightened(0.1), 6)
	local.append([Vector3(0, 0.5, 0), Vector3(8.0, 1.0, 8.0)])
	var x := -hx + 3.0
	while x <= hx - 3.0:
		for z in [-hz + 3.0, hz - 3.0]:
			if ctx.rng.randf() < 0.8:
				Props.oak(mb, local, Vector3(x, 0, z), ctx.rng)
		x += 11.0
	var z := -hz + 14.0
	while z <= hz - 14.0:
		for xx in [-hx + 3.0, hx - 3.0]:
			Props.oak(mb, local, Vector3(xx, 0, z), ctx.rng)
		z += 11.0
	for q in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(1, 0, 1)]:
		Props.bench(mb, local, q * 7.0, atan2(q.x, q.z))
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
		if cls == "":
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
		var clear := _door_zones(ctx, half)
		var street := Vector3(0, 0, -1)
		if cls == "lane":
			for t in [-half * 0.5, half * 0.5]:
				_put(ctx, local, clear, func(): Props.planter(ctx.mb, local, Vector3(t, 0, 1.2)))
		else:
			match kind:
				"downtown":
					# Street lights every 18 m (some with district banners)
					# and a street tree in a pit halfway between, clear of
					# the bench, bins, shelter zone, pay station, hydrant
					# and mailbox.
					var banner = BANNERS[ctx.deco.randi() % BANNERS.size()] if ctx.deco.randf() < 0.5 else null
					var t := -half
					while t <= half:
						_put(ctx, local, clear, func(): Props.street_light(ctx.mb, local, Vector3(t, 0, 0), street, ctx.glow, banner))
						var tree := t + 9.0
						if tree < half - 1.0 and absf(tree) > 6.2 and absf(tree + half * 0.7) > 1.4 and absf(tree - half + 3.0) > 1.4 and absf(tree + half - 3.0) > 1.4:
							_put(ctx, local, clear, func(): Props.street_tree(ctx.mb, local, Vector3(tree, 0, 0.3), ctx.deco))
						t += 18.0
					if rng.randf() < 0.5:
						_put(ctx, local, clear, func(): Props.bins(ctx.mb, local, Vector3(minf(4.4, half), 0, 0.2)))
					if rng.randf() < 0.35:
						_put(ctx, local, clear, func(): Props.bench(ctx.mb, local, Vector3(maxf(-4.0, -half), 0, 0.4), 0.0))
					# (Was a lit signal pole on 6 sides in 10; junction signals
					# stand where TrafficPlan puts them now, _controls. The
					# draw stays so the rest of the block is laid out as before.)
					rng.randf()
					_modern_street(ctx, local, clear, half, true)
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
							_put(ctx, local, clear, func(): Props.crepe_myrtle(ctx.mb, local, Vector3(rng.randf_range(-half, half), 0, 0), rng))
					if rng.randf() < 0.25:
						_put(ctx, local, clear, func(): Props.bins(ctx.mb, local, Vector3(minf(7.0, half), 0, 0.3)))
					if ctx.deco.randf() < 0.15:
						var at := Vector3(ctx.deco.randf_range(-half, half), 0, 1.6)
						_put(ctx, local, clear, func(): Props.scooter(ctx.mb, at, ctx.deco.randf() * TAU, Props.SCOOTERS[ctx.deco.randi() % Props.SCOOTERS.size()]), at)
					elif half > 3.0 and ctx.deco.randf() < 0.06:
						_put(ctx, local, clear, func(): Props.roadworks(ctx.mb, local, Vector3(0, 0, 1.7)))
				"docks":
					var t := -half
					while t <= half:
						_put(ctx, local, clear, func(): Props.street_light(ctx.mb, local, Vector3(t, 0, 0), street, ctx.glow))
						t += 30.0
					if rng.randf() < 0.5:
						_put(ctx, local, clear, func(): Props.barrel(ctx.mb, local, Vector3(rng.randf_range(-half, half), 0, 0), Color(0.75, 0.3, 0.2)))
				_:
					var t := -half
					while t <= half:
						_put(ctx, local, clear, func(): Props.gas_lamp(ctx.mb, local, Vector3(t, 0, 0), ctx.glow))
						t += 12.0
					if rng.randf() < 0.5:
						_put(ctx, local, clear, func(): Props.crepe_myrtle(ctx.mb, local, Vector3(minf(6.0, half) if rng.randf() < 0.5 else maxf(-6.0, -half), 0, 0), rng))
					elif kind == "quarter" and ctx.deco.randf() < 0.6:
						var parasol: Color = Buildings.AWNINGS[ctx.deco.randi() % Buildings.AWNINGS.size()]
						_put(ctx, local, clear, func(): Props.cafe_table(ctx.mb, local, Vector3(minf(6.0, half) if ctx.deco.randf() < 0.5 else maxf(-6.0, -half), 0, 1.3), parasol))
					if rng.randf() < 0.3:
						_put(ctx, local, clear, func(): Props.trash_can(ctx.mb, local, Vector3(half - 1.0, 0, 0)))
					if kind == "quarter":
						_modern_street(ctx, local, clear, half, false)
					# Festoon lights across narrow Quarter streets.
					if kind == "quarter" and cls == "quarter" and out.y > -0.3 and ctx.deco.randf() < 0.45:
						var t0 := ctx.deco.randf_range(-half * 0.6, half * 0.6)
						_put(ctx, local, clear, func(): Props.festoon(ctx.mb, Vector3(t0, 4.6, 0), Vector3(t0, 4.6, -(StreetPlan.CLASSES[cls].width + 0.9)), ctx.deco))
		if rng.randf() < 0.35 and half > 4.0:
			_put(ctx, local, clear, func(): Props.hydrant(ctx.mb, local, Vector3(half - 3.0, 0, 0)))
		if rng.randf() < 0.15 and half > 4.0:
			_put(ctx, local, clear, func(): Props.mailbox(ctx.mb, local, Vector3(3.0 - half, 0, 0)))
		_done(ctx, local, false, ctx.props)


## Doorsteps of places on this side of the block, as keep-clear rects in
## the furniture frame (ctx.mb.xform): the walk from the curb to the door
## stays free of benches, planters and racks.
static func _door_zones(ctx: Ctx, half: float) -> Array:
	var zones: Array = []
	if ctx.city == null:
		return zones
	var inv: Transform3D = ctx.mb.xform.affine_inverse()
	for place in ctx.city.places:
		if place.face < 0 or place.face != ctx.face:
			continue
		var d: Vector3 = inv * place.door
		if absf(d.x) < half + 4.0 and d.z > -0.5 and d.z < 4.0:
			zones.append(Rect2(d.x - DOOR_CLEAR, 0.3, DOOR_CLEAR * 2.0, d.z + 0.9))
	return zones


## Builds one prop (`build` adds its mesh and colliders) and takes it out
## again if it stands on a doorstep. Props without colliders (scooters)
## give their spot as `at` and are skipped there.
static func _put(ctx: Ctx, local: Array, clear: Array, build: Callable, at = null) -> void:
	if at != null and clear.any(func(z): return z.has_point(Vector2(at.x, at.z))):
		return
	var mark: Array = ctx.mb.mark()
	var glow_mark: Array = ctx.glow.mark() if ctx.glow else []
	var n := local.size()
	build.call()
	for i in range(n, local.size()):
		var col: Array = local[i]
		var yaw: float = col[2] if col.size() > 2 else 0.0
		var size: Vector3 = col[1]
		var ext := Vector2(absf(cos(yaw)) * size.x + absf(sin(yaw)) * size.z, absf(sin(yaw)) * size.x + absf(cos(yaw)) * size.z) * 0.5
		var box := Rect2(Vector2(col[0].x, col[0].z) - ext, ext * 2.0)
		for z in clear:
			if box.intersects(z):
				ctx.mb.rollback(mark)
				if ctx.glow:
					ctx.glow.rollback(glow_mark)
				local.resize(n)
				return


## Present-day kit along a curb (furniture frame, -Z to the street). Downtown,
## in the gap between the bench (x -4.9..-3.1) and the bins (3.37..5.3): a
## bus shelter, a bike-share dock, EV chargers, a wayfinding totem, bike
## racks or sidewalk works, and sometimes a pay station past the bench.
## Elsewhere (the Quarter) bike racks sometimes; everywhere dockless
## scooters, kept inside the sidewalk (its back edge is at z 2.55).
static func _modern_street(ctx: Ctx, local: Array, clear: Array, half: float, downtown: bool) -> void:
	var deco := ctx.deco
	if downtown and half > 6.0:
		var roll := deco.randf()
		if roll < 0.25:
			_put(ctx, local, clear, func(): Props.bus_shelter(ctx.mb, local, Vector3(0.2, 0, 1.55), deco))
		elif roll < 0.45:
			_put(ctx, local, clear, func(): Props.bike_dock(ctx.mb, local, Vector3(0.4, 0, 1.6), 4.0, deco))
		elif roll < 0.6:
			for x in [-1.5, 1.5]:
				_put(ctx, local, clear, func(): Props.ev_charger(ctx.mb, local, Vector3(x, 0, 0.15)))
		elif roll < 0.75:
			_put(ctx, local, clear, func(): Props.wayfinding(ctx.mb, local, Vector3(1.0, 0, 0.7)))
		elif roll < 0.9:
			_put(ctx, local, clear, func(): Props.bike_rack(ctx.mb, local, Vector3(0.2, 0, 1.3), deco))
		elif roll < 0.95:
			_put(ctx, local, clear, func(): Props.roadworks(ctx.mb, local, Vector3(0.3, 0, 1.7)))
		if half >= 8.0 and deco.randf() < 0.25:
			_put(ctx, local, clear, func(): Props.pay_station(ctx.mb, local, Vector3(-half * 0.7, 0, 0.3)))
	elif not downtown and half > 4.0 and deco.randf() < 0.2:
		_put(ctx, local, clear, func(): Props.bike_rack(ctx.mb, local, Vector3(0, 0, 1.6), deco))
	if deco.randf() < 0.3:
		for k in deco.randi_range(1, 2):
			var at := Vector3(deco.randf_range(-half, half), 0, 1.7 + k * 0.3)
			_put(ctx, local, clear, func(): Props.scooter(ctx.mb, at, deco.randf() * TAU, Props.SCOOTERS[deco.randi() % Props.SCOOTERS.size()]), at)


# --- Outside the window ----------------------------------------------------------

## Cheap blocks past the window (the plan's margin ring): right silhouettes
## with plain box collisions, no details.
static func _outer_block(ctx: Ctx) -> void:
	var kind: String = ctx.city.district_style(ctx.face)
	_flat_in_front(ctx, ctx.ff, ctx.lot, KERB + 0.01, _paved(LOT_GROUND.get(kind, PAVEMENT)))
	for p in split(ctx.rect, PARCEL_MAX.get(kind, PARCEL_DEFAULT)):
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
	var local: Array = []
	match kind:
		"downtown":
			for x in [-hx * 0.5, hx * 0.5]:
				var h := rng.randf_range(14.0, 28.0)
				var glass: Color = Buildings.GLASS[rng.randi() % Buildings.GLASS.size()]
				mb.box(Vector3(x, h * 0.5, 0), Vector3(hx - 2.0, h, hz * 2 - 4.0), glass)
				local.append([Vector3(x, h * 0.5, 0), Vector3(hx - 2.0, h, hz * 2 - 4.0)])
				mb.box(Vector3(x, h + 0.3, 0), Vector3(hx - 2.4, 0.6, hz * 2 - 4.4), glass.lightened(0.3))
		"wards":
			for z in ([-hz * 0.55, hz * 0.55] if hz > 9.0 else [0.0]):
				var count := maxi(1, int(hx * 2 / 6.8))
				for k in count:
					var col: Color = Buildings.WARDS[rng.randi() % Buildings.WARDS.size()]
					var x := -hx + (k + 0.5) * hx * 2 / count
					mb.box(Vector3(x, 1.85, z), Vector3(5.0, 3.4, minf(12.0, hz * 0.8)), col)
					local.append([Vector3(x, 1.85, z), Vector3(5.0, 3.4, minf(12.0, hz * 0.8))])
					mb.box(Vector3(x, 3.7, z), Vector3(5.4, 0.3, minf(12.4, hz * 0.8 + 0.4)), Color(0.36, 0.33, 0.33))
		"docks":
			mb.box(Vector3(0, 5.0, -hz * 0.3), Vector3(hx * 1.8, 10.0, hz), Color(0.55, 0.5, 0.45))
			local.append([Vector3(0, 5.0, -hz * 0.3), Vector3(hx * 1.8, 10.0, hz)])
		"heights", "bayou":
			mb.box(Vector3(0, 4.0, 0), Vector3(minf(14.0, hx * 1.6), 8.0, minf(10.0, hz * 1.6)), Color(0.95, 0.93, 0.86))
			local.append([Vector3(0, 4.0, 0), Vector3(minf(14.0, hx * 1.6), 8.0, minf(10.0, hz * 1.6))])
			mb.box(Vector3(0, 8.2, 0), Vector3(minf(14.6, hx * 1.6 + 0.6), 0.4, minf(10.6, hz * 1.6 + 0.6)), Color(0.35, 0.3, 0.32))
		_:
			var col: Color = Buildings.CREOLE[rng.randi() % Buildings.CREOLE.size()]
			var h := rng.randf_range(7.0, 10.5)
			var d := minf(10.0, hz)
			mb.box(Vector3(0, h * 0.5, hz - d * 0.5), Vector3(hx * 2, h, d), col)
			local.append([Vector3(0, h * 0.5, hz - d * 0.5), Vector3(hx * 2, h, d)])
			if hz > 12.0:
				mb.box(Vector3(0, h * 0.5, -hz + d * 0.5), Vector3(hx * 2, h, d), col.darkened(0.08))
				local.append([Vector3(0, h * 0.5, -hz + d * 0.5), Vector3(hx * 2, h, d)])
	_done(ctx, local)
