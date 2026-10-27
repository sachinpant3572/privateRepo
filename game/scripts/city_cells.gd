extends RefCounted
## Builds one city cell: its block, the node at its north-west corner and the
## road segments running east and south from that node. Pure data in, mesh
## and collision boxes out, so city.gd can run it on a worker thread.
##
## Each district has its own block layout: Creole townhouse rings with
## courtyards (Lantern Quarter), rows of shotgun houses with backyards and
## power lines (Floodline Wards), towers on plazas (Gilt District) and
## warehouses, containers and cranes (Ironwharf). Map landmarks get their own
## blocks. Fronts face the street; most landmarks face south, toward the
## camera.

const MeshBuilder = preload("res://scripts/mesh_builder.gd")
const Buildings = preload("res://scripts/kits/building_kit.gd")
const Props = preload("res://scripts/kits/prop_kit.gd")

const BLOCK := 40.0
const ROAD := 12.0
const PITCH := BLOCK + ROAD
## Road and block slabs reach down into the water so quays have walls.
const SLAB := 1.2
## Half size of the lot inside the sidewalk.
const INNER := 17.0
## Street furniture stands this far from the block centre (0.45 m in from the
## curb), clear of the pedestrians' walking loop.
const CURB := 19.55

const ASPHALT := Color(0.2, 0.2, 0.23)
const PAVEMENT := Color(0.58, 0.56, 0.52)
const MARKING := Color(0.92, 0.8, 0.3)
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
	var c := Vector3.ZERO


static func build(city, cell: Vector2i) -> Dictionary:
	var ctx := Ctx.new()
	ctx.city = city
	ctx.mb = MeshBuilder.new()
	ctx.glow = MeshBuilder.new()
	ctx.cell = cell
	ctx.c = city.block_center(cell)
	ctx.rng.seed = hash([city.seed_value, cell.x, cell.y])
	ctx.deco.seed = hash([city.seed_value, cell.x, cell.y, "deco"])
	var style: String = city.block_style(cell)
	_roads(ctx, style)
	if style == "water":
		_water_block(ctx)
	elif city.in_window(cell):
		_land_block(ctx, style)
	else:
		_outer_block(ctx)
	return {"mesh": ctx.mb, "glow": ctx.glow, "colliders": ctx.out, "props": ctx.props, "buildings": ctx.buildings}


# --- Placement -------------------------------------------------------------------

## Points the kits at `pos`, turned by `yaw` (0: front faces north, PI: south,
## -PI/2: east, PI/2: west). Returns the list the kit fills with colliders.
static func _at(ctx: Ctx, pos: Vector3, yaw: float) -> Array:
	ctx.mb.xform = Transform3D(Basis(Vector3.UP, yaw), pos)
	return []


## Moves a kit's local colliders into the cell and resets the placement.
static func _done(ctx: Ctx, local: Array, building := true) -> void:
	var x: Transform3D = ctx.mb.xform
	var swap := absf(x.basis.x.z) > 0.5
	for col in local:
		var s: Vector3 = col[1]
		ctx.out.append([x * col[0], Vector3(s.z, s.y, s.x) if swap else s])
	ctx.mb.xform = Transform3D.IDENTITY
	if building:
		ctx.buildings += 1


static func _yaw_facing(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


static func _ground(ctx: Ctx, size: float, color: Color) -> void:
	ctx.mb.box(ctx.c + Vector3(0, 0.17, 0), Vector3(size, 0.04, size), color)


# --- Roads -----------------------------------------------------------------------

static func _roads(ctx: Ctx, style: String) -> void:
	var city = ctx.city
	var mb = ctx.mb
	var n := ctx.cell
	var p0: Vector3 = city.node_pos(n)
	if city.node_ok(n):
		mb.box(p0 + Vector3(0, -SLAB * 0.5, 0), Vector3(ROAD, SLAB, ROAD), ASPHALT)
		if ctx.rng.randf() < 0.3:
			Props.manhole(mb, p0 + Vector3(1.6, 0.0, -1.4))
	else:
		_water_wall(ctx, p0, Vector3(ROAD, 0, ROAD))
	for d in [Vector2i(1, 0), Vector2i(0, 1)]:
		var m: Vector2i = n + d
		var p1: Vector3 = city.node_pos(m)
		var along := Vector3(d.x, 0, d.y)
		var across := Vector3(d.y, 0, d.x)
		var mid := (p0 + p1) * 0.5
		if not (city.node_ok(n) and city.node_ok(m)):
			_water_wall(ctx, mid, along * BLOCK + across * ROAD)
			continue
		mb.box(mid + Vector3(0, -SLAB * 0.5, 0), along * BLOCK + across * ROAD + Vector3(0, SLAB, 0), ASPHALT)
		for k in ctx.deco.randi_range(0, 2):
			Props.road_mark(mb, mid + along * ctx.deco.randf_range(-BLOCK * 0.45, BLOCK * 0.45) + across * ctx.deco.randf_range(-4.0, 4.0), along, ctx.deco)
		var line: int = city.rail_on(n, m)
		if line >= 0:
			_tram_segment(ctx, p0, p1, along, across, line)
		else:
			var t := -BLOCK * 0.5 + 5.0
			while t < BLOCK * 0.5 - 5.0:
				mb.box(mid + along * (t + 1.5) + Vector3(0, 0.01, 0), along * 3.0 + across * 0.2 + Vector3(0, 0.02, 0), MARKING)
				t += 6.0
		if style in ZEBRA_STYLES:
			for end in [p0, p1]:
				Props.crosswalk(mb, end + (mid - end).normalized() * (ROAD * 0.5 + 1.8), along, ROAD - 2.0)
		_barricade(ctx, n, m)


static func _tram_segment(ctx: Ctx, p0: Vector3, p1: Vector3, along: Vector3, across: Vector3, line: int) -> void:
	var mb = ctx.mb
	var rusty: bool = ctx.city.rail_lines[line][2]
	Props.rails(mb, p0, p1, rusty)
	if rusty:
		return
	var mid := (p0 + p1) * 0.5
	# Overhead wire with a span wire across the street every segment.
	mb.box(mid + Vector3(0, 5.6, 0), along * PITCH + across * 0.05 + Vector3(0, 0.05, 0), Color(0.08, 0.08, 0.08))
	mb.box(mid + Vector3(0, 5.7, 0), across * (ROAD + 1.0) + along * 0.05 + Vector3(0, 0.05, 0), Color(0.08, 0.08, 0.08))
	var first: Vector2i = ctx.city.rail_lines[line][0]
	if ctx.cell == first or ctx.rng.randf() < 0.12:
		# A streetcar waiting at the stop; traffic passes on either side.
		var local := _at(ctx, mid, 0.0 if along.z != 0.0 else PI / 2)
		Props.streetcar(mb, local, Vector3.ZERO)
		_done(ctx, local, false)


## Striped "road closed" boards where a street leaves the playable window.
static func _barricade(ctx: Ctx, n: Vector2i, m: Vector2i) -> void:
	var a_in := _node_in_window(ctx.city, n)
	if a_in == _node_in_window(ctx.city, m):
		return
	var inside := n if a_in else m
	var outside := m if a_in else n
	var dir := Vector3(outside.x - inside.x, 0, outside.y - inside.y)
	var across := Vector3(absf(dir.z), 0, absf(dir.x))
	var p: Vector3 = ctx.city.node_pos(inside) + dir * (ROAD * 0.5 + 1.6)
	for k in 3:
		var q := p + across * (-4.0 + k * 4.0)
		ctx.mb.box(q + Vector3(0, 1.0, 0), across * 2.8 + dir.abs() * 0.2 + Vector3(0, 0.3, 0), Color(0.95, 0.5, 0.1))
		ctx.mb.box(q + Vector3(0, 0.65, 0), across * 2.8 + dir.abs() * 0.2 + Vector3(0, 0.3, 0), Color(0.95, 0.95, 0.92))
		for s in [-1.2, 1.2]:
			ctx.mb.box(q + across * s + Vector3(0, 0.45, 0), Vector3(0.12, 0.9, 0.12), Color(0.3, 0.3, 0.3))


static func _node_in_window(city, n: Vector2i) -> bool:
	return n.x >= 0 and n.y >= 0 and n.x <= city.blocks.x and n.y <= city.blocks.y


static func _water_wall(ctx: Ctx, center: Vector3, size: Vector3) -> void:
	ctx.out.append([center + Vector3(0, 2.0, 0), size + Vector3(0, 4.0, 0)])


# --- Water -----------------------------------------------------------------------

static func _water_block(ctx: Ctx) -> void:
	var city = ctx.city
	var c := ctx.c
	var b := ctx.cell
	_water_wall(ctx, c, Vector3(BLOCK, 0, BLOCK))
	# A railing wherever a road runs along the water.
	var h := BLOCK * 0.5 - 0.3
	var edges := [
		[b, b + Vector2i(1, 0), Vector3(-h, 0, -h), Vector3(h, 0, -h)],
		[b + Vector2i(0, 1), b + Vector2i(1, 1), Vector3(-h, 0, h), Vector3(h, 0, h)],
		[b, b + Vector2i(0, 1), Vector3(-h, 0, -h), Vector3(-h, 0, h)],
		[b + Vector2i(1, 0), b + Vector2i(1, 1), Vector3(h, 0, -h), Vector3(h, 0, h)],
	]
	for e in edges:
		if city.node_ok(e[0]) and city.node_ok(e[1]):
			Props.fence(ctx.mb, [], c + e[2], c + e[3], RAIL_WHITE, 0.9)
	if ctx.rng.randf() < 0.3:
		_boat(ctx, c + Vector3(ctx.rng.randf_range(-10, 10), 0, ctx.rng.randf_range(-10, 10)), ctx.rng.randf() * TAU)


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
	var c := ctx.c
	ctx.mb.box(c + Vector3(0, (0.15 - SLAB) * 0.5, 0), Vector3(BLOCK, SLAB + 0.15, BLOCK), PAVEMENT)
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
			var local := _at(ctx, c, 0.0)
			Buildings.lantern_square(ctx.mb, local, Props, ctx.rng, ctx.glow)
			_done(ctx, local, false)
		"wharfside_courts":
			var local := _at(ctx, c, 0.0)
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
			match style:
				"downtown":
					_downtown(ctx)
				"wards":
					_wards(ctx, "")
				"docks":
					_docks(ctx, -1)
				_:
					_quarter(ctx)
	_furniture(ctx, ctx.city.district_at(c).get("style", "quarter"))


## Lantern Quarter: a ring of Creole townhouses round a shady courtyard.
static func _quarter(ctx: Ctx) -> void:
	var c := ctx.c
	var rng := ctx.rng
	var depth := 10.0
	ctx.mb.box(c + Vector3(0, 0.17, 0), Vector3(INNER * 2 - 2 * depth, 0.04, INNER * 2 - 2 * depth), GRASS)
	for side in [-1.0, 1.0]:
		var x := -INNER
		while x < INNER - 0.5:
			var w := rng.randf_range(6.0, 9.0)
			if INNER - x - w < 5.0:
				w = INNER - x
			_townhouse(ctx, c + Vector3(x + w * 0.5, 0, side * (INNER - depth * 0.5)), 0.0 if side < 0 else PI, w - 0.2, depth)
			x += w
	var span := INNER * 2 - 2 * depth
	for side in [-1.0, 1.0]:
		for k in 2:
			var z := -INNER + depth + span * 0.25 * (2 * k + 1)
			_townhouse(ctx, c + Vector3(side * (INNER - depth * 0.5), 0, z), PI / 2 if side < 0 else -PI / 2, span * 0.5 - 0.2, depth)
	Props.oak(ctx.mb, ctx.props, c + Vector3(rng.randf_range(-2, 2), 0, rng.randf_range(-2, 2)), rng)
	if rng.randf() < 0.6:
		Props.bench(ctx.mb, ctx.props, c + Vector3(0, 0, 5.0), PI)


static func _townhouse(ctx: Ctx, pos: Vector3, yaw: float, w: float, d: float) -> void:
	var local := _at(ctx, pos, yaw)
	Buildings.townhouse(ctx.mb, local, w, d, ctx.rng.randi_range(2, 3), ctx.rng)
	_done(ctx, local)


## Floodline Wards: shotgun houses on both streets, backyards between them.
## Some houses are storm-damaged, some lots are empty since the flood.
static func _wards(ctx: Ctx, special: String) -> void:
	var c := ctx.c
	var rng := ctx.rng
	var mb = ctx.mb
	_ground(ctx, INNER * 2, GRASS.darkened(0.05))
	var slots := 5
	var slot_w := INNER * 2 / slots
	for side in [-1.0, 1.0]:
		var yaw := 0.0 if side < 0 else PI
		for k in slots:
			var x := -INNER + slot_w * (k + 0.5)
			if side > 0 and special == "teo" and k >= 1 and k <= 3:
				if k == 2:
					var local := _at(ctx, c + Vector3(0, 0, INNER - 6.5), PI)
					Buildings.ward_apartment(mb, local, 15.0, 12.0, rng)
					_done(ctx, local)
				continue
			var d := rng.randf_range(12.0, 14.0)
			var pos := c + Vector3(x, 0, side * (INNER - d * 0.5))
			if side > 0 and special == "moreau" and k == 2:
				var local := _at(ctx, c + Vector3(x, 0, INNER - 7.0), PI)
				Buildings.shotgun(mb, local, 6.2, 14.0, rng, false, MOREAU)
				_done(ctx, local)
				continue
			if rng.randf() < 0.12:
				_empty_lot(ctx, c + Vector3(x, 0, side * (INNER - 6.0)), yaw)
				continue
			var local := _at(ctx, pos, yaw)
			Buildings.shotgun(mb, local, rng.randf_range(4.6, 5.6), d, rng, rng.randf() < 0.18)
			_done(ctx, local)
	for k in range(1, slots):
		var x := -INNER + slot_w * k
		Props.fence(mb, ctx.props, c + Vector3(x, 0, -3.0), c + Vector3(x, 0, 3.0), FENCE_WOOD)
	Props.fence(mb, ctx.props, c + Vector3(-INNER + 0.5, 0, 0), c + Vector3(INNER - 0.5, 0, 0), FENCE_WOOD)
	if rng.randf() < 0.5:
		Props.oak(mb, ctx.props, c + Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-1.5, 1.5)), rng)


## What the flood left: a bare foundation, steps to nowhere, weeds and junk.
static func _empty_lot(ctx: Ctx, p: Vector3, yaw: float) -> void:
	var rng := ctx.rng
	var local := _at(ctx, p, yaw)
	var mb = ctx.mb
	mb.box(Vector3(0, 0.3, 0.5), Vector3(4.8, 0.3, 9.0), Color(0.6, 0.58, 0.55))
	mb.box(Vector3(1.2, 0.35, -4.4), Vector3(1.2, 0.7, 0.8), Color(0.62, 0.6, 0.58))
	for i in 6:
		mb.box(Vector3(rng.randf_range(-2.5, 2.5), 0.35, rng.randf_range(-5, 5)), Vector3(0.9, 0.5, 0.9), Color(0.4, 0.55, 0.25).lerp(Color(0.55, 0.55, 0.3), rng.randf()))
	if rng.randf() < 0.6:
		Props.crate(mb, local, Vector3(-1.5, 0.15, 2.5))
	mb.box(Vector3(-1.8, 1.0, -4.2), Vector3(0.1, 2.0, 0.1), Color(0.35, 0.3, 0.25))
	mb.box(Vector3(-1.8, 1.7, -4.25), Vector3(1.4, 0.8, 0.06), Color(0.95, 0.95, 0.9))
	mb.box(Vector3(-1.8, 1.7, -4.29), Vector3(1.2, 0.2, 0.02), Color(0.8, 0.15, 0.15))
	_done(ctx, local, false)


## Gilt District: towers on a stone plaza, in one of three layouts. Kept
## mid-rise so roofs don't swallow the street under the 3/4 camera.
static func _downtown(ctx: Ctx) -> void:
	var c := ctx.c
	var rng := ctx.rng
	_ground(ctx, INNER * 2, PLAZA)
	match rng.randi() % 3:
		0:
			_tower(ctx, c, 24.0, 24.0, rng.randf_range(18.0, 30.0))
			for x in [-14.5, 14.5]:
				Props.planter(ctx.mb, ctx.props, c + Vector3(x, 0, 14.5))
		1:
			for x in [-8.5, 8.5]:
				_tower(ctx, c + Vector3(x, 0, -2.0), 15.0, 26.0, rng.randf_range(14.0, 26.0))
				Props.planter(ctx.mb, ctx.props, c + Vector3(x, 0, 15.0))
		_:
			for x in [-8.5, 8.5]:
				for z in [-8.5, 8.5]:
					_tower(ctx, c + Vector3(x, 0, z), 14.0, 14.0, rng.randf_range(11.0, 22.0))


static func _tower(ctx: Ctx, pos: Vector3, w: float, d: float, h: float) -> void:
	var local := _at(ctx, pos, PI)
	Buildings.tower(ctx.mb, local, w, d, h, ctx.rng)
	_done(ctx, local)


static func _aurum(ctx: Ctx) -> void:
	var c := ctx.c
	_ground(ctx, INNER * 2, PLAZA.lightened(0.1))
	var local := _at(ctx, c + Vector3(0, 0, -3.0), PI)
	Buildings.aurum_tower(ctx.mb, local, ctx.rng)
	_done(ctx, local)
	# Fountain and benches on the forecourt.
	ctx.mb.cylinder(c + Vector3(0, 0.15, 13.0), 2.6, 0.6, Buildings.STONE, 10)
	ctx.mb.cylinder(c + Vector3(0, 0.2, 13.0), 2.3, 0.6, Color(0.35, 0.6, 0.75), 10)
	ctx.mb.cylinder(c + Vector3(0, 0.6, 13.0), 0.3, 1.6, Buildings.GOLD, 6)
	ctx.out.append([c + Vector3(0, 0.5, 13.0), Vector3(5.2, 1.0, 5.2)])
	for x in [-9.0, 9.0]:
		Props.planter(ctx.mb, ctx.props, c + Vector3(x, 0, 13.0))


static func _union_station(ctx: Ctx) -> void:
	var c := ctx.c
	_ground(ctx, INNER * 2, PLAZA)
	var local := _at(ctx, c + Vector3(0, 0, -2.0), PI)
	Buildings.union_station(ctx.mb, local)
	_done(ctx, local)
	for x in [-12.0, 12.0]:
		Props.planter(ctx.mb, ctx.props, c + Vector3(x, 0, 14.0))
	for x in [-6.0, 6.0]:
		Props.bench(ctx.mb, ctx.props, c + Vector3(x, 0, 14.5), PI)


## Precinct or clinic, facing south.
static func _single(ctx: Ctx, kind: String, ground: Color) -> void:
	_ground(ctx, INNER * 2, ground)
	var local := _at(ctx, ctx.c, PI)
	if kind == "precinct":
		Buildings.precinct(ctx.mb, local)
	else:
		Buildings.clinic(ctx.mb, local)
	_done(ctx, local)


## The Blue Lantern with a townhouse either side and a shallow row behind.
static func _club(ctx: Ctx) -> void:
	var c := ctx.c
	var rng := ctx.rng
	var local := _at(ctx, c + Vector3(0, 0, -1.0), PI)
	Buildings.blue_lantern(ctx.mb, local, rng)
	_done(ctx, local)
	for x in [-14.5, 14.5]:
		var lt := _at(ctx, c + Vector3(x, 0, INNER - 6.0), PI)
		Buildings.townhouse(ctx.mb, lt, 4.8, 12.0, 2, rng)
		_done(ctx, lt)
	var x := -INNER
	while x < INNER - 0.5:
		var w := minf(rng.randf_range(6.0, 9.0), INNER - x)
		var lb := _at(ctx, c + Vector3(x + w * 0.5, 0, -INNER + 2.5), 0.0)
		Buildings.townhouse(ctx.mb, lb, w - 0.2, 5.0, 2, rng)
		_done(ctx, lb)
		x += w


## Ironwharf. On the waterfront: one warehouse, a container yard and a crane
## reaching over the river. Inland: warehouses back to back, or one and a
## container yard. `number` paints a roof number (Warehouse 9).
static func _docks(ctx: Ctx, number: int) -> void:
	var c := ctx.c
	var rng := ctx.rng
	var mb = ctx.mb
	_ground(ctx, INNER * 2, YARD)
	if ctx.city.block_style(ctx.cell + Vector2i(0, 1)) == "water":
		_warehouse(ctx, c + Vector3(0, 0, -INNER + 7.5), PI, 15.0, number)
		for z in [4.5, 8.0]:
			for k in 4:
				var p := c + Vector3(-12.0 + k * 7.5, 0, z)
				for s in rng.randi_range(0, 2):
					Props.container(mb, ctx.out, p + Vector3(0, 2.6 * s, 0), Props.CONTAINERS[rng.randi() % Props.CONTAINERS.size()])
		Props.crane(mb, ctx.out, c + Vector3(rng.randf_range(-10.0, 10.0), 0, 13.5))
		return
	if number >= 0 or rng.randf() < 0.5:
		_warehouse(ctx, c + Vector3(0, 0, -INNER + 9.0), 0.0, 12.0, -1)
		_warehouse(ctx, c + Vector3(0, 0, INNER - 9.0), PI, 12.0, number)
		for i in 4:
			Props.barrel(mb, ctx.props, c + Vector3(rng.randf_range(-14, 14), 0, rng.randf_range(-1.0, 1.0)), Color(0.75, 0.3, 0.2) if rng.randf() < 0.5 else Color(0.25, 0.4, 0.65))
	else:
		_warehouse(ctx, c + Vector3(0, 0, INNER - 9.0), PI, 12.0, number)
		for z in [-12.0, -5.5]:
			for k in 4:
				if rng.randf() < 0.25:
					continue
				var p := c + Vector3(-12.0 + k * 7.5, 0, z)
				for s in rng.randi_range(1, 2):
					Props.container(mb, ctx.out, p + Vector3(0, 2.6 * s, 0), Props.CONTAINERS[rng.randi() % Props.CONTAINERS.size()])
		Props.fence(mb, ctx.props, c + Vector3(-INNER + 0.3, 0, -INNER + 0.3), c + Vector3(-3.0, 0, -INNER + 0.3), CHAIN, 2.0)
		Props.fence(mb, ctx.props, c + Vector3(3.0, 0, -INNER + 0.3), c + Vector3(INNER - 0.3, 0, -INNER + 0.3), CHAIN, 2.0)


static func _warehouse(ctx: Ctx, pos: Vector3, yaw: float, d: float, number: int) -> void:
	var local := _at(ctx, pos, yaw)
	Buildings.warehouse(ctx.mb, local, 32.0, d, ctx.rng.randf_range(8.0, 12.0), ctx.rng, number)
	_done(ctx, local)


## The Pit: a boxing gym in an old warehouse, with an outdoor ring.
static func _pit(ctx: Ctx) -> void:
	var c := ctx.c
	var mb = ctx.mb
	_ground(ctx, INNER * 2, YARD)
	var local := _at(ctx, c + Vector3(0, 0, -6.0), PI)
	Buildings.warehouse(mb, local, 26.0, 18.0, 8.0, ctx.rng)
	_done(ctx, local)
	mb.box(c + Vector3(0, 9.6, 3.3), Vector3(11.0, 2.4, 0.3), Color(0.8, 0.12, 0.12))
	mb.box(c + Vector3(0, 9.6, 3.5), Vector3(8.0, 0.5, 0.06), Color(0.97, 0.95, 0.9))
	var ring := c + Vector3(0, 0, 11.5)
	mb.box(ring + Vector3(0, 0.45, 0), Vector3(7.0, 0.6, 7.0), Color(0.3, 0.38, 0.55))
	mb.box(ring + Vector3(0, 0.76, 0), Vector3(6.6, 0.02, 6.6), Color(0.85, 0.85, 0.82))
	for x in [-3.3, 3.3]:
		for z in [-3.3, 3.3]:
			mb.box(ring + Vector3(x, 1.4, z), Vector3(0.2, 1.4, 0.2), Color(0.85, 0.15, 0.15) if x * z > 0 else Color(0.15, 0.25, 0.75))
	for y in [1.2, 1.7]:
		for s in [-3.3, 3.3]:
			mb.box(ring + Vector3(0, y, s), Vector3(6.6, 0.05, 0.05), Color.WHITE)
			mb.box(ring + Vector3(s, y, 0), Vector3(0.05, 0.05, 6.6), Color.WHITE)
	ctx.out.append([ring + Vector3(0, 0.45, 0), Vector3(7.0, 0.9, 7.0)])


## Old Streetcar Depot: the drowned line's rusty rails run inside to an
## abandoned car.
static func _depot(ctx: Ctx) -> void:
	var c := ctx.c
	_ground(ctx, INNER * 2, MUD.lightened(0.15))
	var local := _at(ctx, c, PI)
	Buildings.streetcar_depot(ctx.mb, local)
	Props.streetcar(ctx.mb, local, Vector3(0, 0, 2.0), true)
	_done(ctx, local)
	Props.rails(ctx.mb, c + Vector3(0, 0.15, -12.0), c + Vector3(0, 0.15, PITCH * 0.5), true)


## The Drowned Streetcar: a flooded lot where a streetcar sank in the storm
## and was never pulled out. Fenced off, reeds all round.
static func _drowned(ctx: Ctx) -> void:
	var c := ctx.c
	var rng := ctx.rng
	var mb = ctx.mb
	_ground(ctx, INNER * 2, MUD)
	mb.box(c + Vector3(0, 0.2, 0), Vector3(26.0, 0.04, 22.0), POND)
	mb.xform = Transform3D(Basis(Vector3.UP, 0.5) * Basis(Vector3.BACK, 0.15), c + Vector3(1.0, -1.1, 0))
	var local: Array = []
	Props.streetcar(mb, local, Vector3.ZERO, true)
	_done(ctx, local, false)
	for i in 28:
		var a := rng.randf() * TAU
		var r := rng.randf_range(10.0, 14.0)
		mb.box(c + Vector3(cos(a) * r, 0.7, sin(a) * r * 0.85), Vector3(0.12, rng.randf_range(0.8, 1.6), 0.12), Color(0.45, 0.55, 0.25))
	Props.oak(mb, ctx.props, c + Vector3(-13.0, 0, -12.0), rng)
	for e in [[Vector3(-INNER, 0, -INNER), Vector3(INNER, 0, -INNER)], [Vector3(-INNER, 0, -INNER), Vector3(-INNER, 0, INNER)],
			[Vector3(INNER, 0, -INNER), Vector3(INNER, 0, INNER)], [Vector3(-INNER, 0, INNER), Vector3(-3.0, 0, INNER)],
			[Vector3(3.0, 0, INNER), Vector3(INNER, 0, INNER)]]:
		Props.fence(mb, ctx.props, c + e[0] * 0.98, c + e[1] * 0.98, CHAIN, 2.0)


# --- Street furniture ------------------------------------------------------------

static func _furniture(ctx: Ctx, kind: String) -> void:
	var c := ctx.c
	var rng := ctx.rng
	var mb = ctx.mb
	var out := ctx.props
	var sides := [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(1, 0, 0)]
	for s in sides.size():
		var dir: Vector3 = sides[s]
		var along := Vector3(absf(dir.z), 0, absf(dir.x))
		var base := c + dir * CURB
		match kind:
			"downtown":
				for t in [-10.0, 10.0]:
					Props.street_light(mb, out, base + along * t, dir, ctx.glow)
				if rng.randf() < 0.5:
					Props.trash_can(mb, out, base + along * 4.0)
				if rng.randf() < 0.35:
					Props.bench(mb, out, base + along * -4.0, _yaw_facing(dir))
			"wards":
				if s == 1:
					var next_wards: bool = ctx.city.district_at(c + Vector3(PITCH, 0, 0)).get("style") == "wards"
					for t in [-13.0, 0.0, 13.0]:
						var next = base + along * (t + 13.0) if t < 13.0 else (base + along * 39.0 if next_wards else null)
						Props.power_pole(mb, out, base + along * t, next)
				if rng.randf() < 0.4:
					Props.crepe_myrtle(mb, out, base + along * rng.randf_range(-15.0, 15.0), rng)
				if rng.randf() < 0.25:
					Props.trash_can(mb, out, base + along * 7.0)
			"docks":
				Props.street_light(mb, out, base, dir, ctx.glow)
				if rng.randf() < 0.5:
					Props.barrel(mb, out, base + along * rng.randf_range(-15.0, 15.0), Color(0.75, 0.3, 0.2))
			_:
				for t in [-12.0, 0.0, 12.0]:
					Props.gas_lamp(mb, out, base + along * t, ctx.glow)
				if rng.randf() < 0.5:
					Props.crepe_myrtle(mb, out, base + along * (6.0 if rng.randf() < 0.5 else -6.0), rng)
				elif kind == "quarter" and ctx.deco.randf() < 0.6:
					# Café tables in front of the shops.
					var parasol: Color = Buildings.AWNINGS[ctx.deco.randi() % Buildings.AWNINGS.size()]
					Props.cafe_table(mb, out, c + dir * (CURB - 1.7) + along * (6.0 if ctx.deco.randf() < 0.5 else -6.0), parasol)
				if rng.randf() < 0.3:
					Props.trash_can(mb, out, base + along * 16.0)
				# Festoon lights across the street to the next block (east and
				# south sides only, so each street gets one string).
				if kind == "quarter" and (s == 1 or s == 3) and ctx.deco.randf() < 0.6:
					var a := base + along * ctx.deco.randf_range(-8.0, 8.0) + Vector3(0, 4.6, 0)
					Props.festoon(mb, a, a + dir * (ROAD + 0.9), ctx.deco)
	if rng.randf() < 0.7:
		Props.hydrant(mb, out, c + Vector3(15.0, 0, CURB))
	if rng.randf() < 0.3:
		Props.mailbox(mb, out, c + Vector3(-CURB, 0, 15.0))
	if kind == "downtown":
		Props.traffic_light(mb, out, c + Vector3(-CURB, 0, -CURB), Vector3(0, 0, -1))
		Props.traffic_light(mb, out, c + Vector3(CURB, 0, CURB), Vector3(0, 0, 1))


# --- Outside the window ----------------------------------------------------------

## Cheap blocks past the edge of the playable area: right silhouettes, no
## details or collisions.
static func _outer_block(ctx: Ctx) -> void:
	var c := ctx.c
	var rng := ctx.rng
	var mb = ctx.mb
	mb.box(c + Vector3(0, (0.15 - SLAB) * 0.5, 0), Vector3(BLOCK, SLAB + 0.15, BLOCK), PAVEMENT)
	match ctx.city.district_at(c).get("style", "quarter"):
		"downtown":
			for x in [-8.5, 8.5]:
				var h := rng.randf_range(14.0, 28.0)
				var glass: Color = Buildings.GLASS[rng.randi() % Buildings.GLASS.size()]
				mb.box(c + Vector3(x, h * 0.5, 0), Vector3(15.0, h, 30.0), glass)
				mb.box(c + Vector3(x, h + 0.3, 0), Vector3(14.6, 0.6, 29.6), glass.lightened(0.3))
		"wards":
			_ground(ctx, INNER * 2, GRASS)
			for z in [-11.0, 11.0]:
				for k in 5:
					var col: Color = Buildings.WARDS[rng.randi() % Buildings.WARDS.size()]
					mb.box(c + Vector3(-13.6 + k * 6.8, 2.0, z), Vector3(5.0, 3.4, 12.0), col)
					mb.box(c + Vector3(-13.6 + k * 6.8, 3.85, z), Vector3(5.4, 0.3, 12.4), Color(0.36, 0.33, 0.33))
		"docks":
			_ground(ctx, INNER * 2, YARD)
			mb.box(c + Vector3(0, 5.0, -6.0), Vector3(32.0, 10.0, 16.0), Color(0.55, 0.5, 0.45))
		"heights", "bayou":
			_ground(ctx, INNER * 2, GRASS.darkened(0.1))
			mb.box(c + Vector3(0, 4.0, 0), Vector3(14.0, 8.0, 10.0), Color(0.95, 0.93, 0.86))
			mb.box(c + Vector3(0, 8.2, 0), Vector3(14.6, 0.4, 10.6), Color(0.35, 0.3, 0.32))
		_:
			_ground(ctx, 14.0, GRASS)
			for side in [-1.0, 1.0]:
				var col: Color = Buildings.CREOLE[rng.randi() % Buildings.CREOLE.size()]
				var h := rng.randf_range(7.0, 10.5)
				mb.box(c + Vector3(0, h * 0.5, side * 12.0), Vector3(34.0, h, 10.0), col)
				mb.box(c + Vector3(side * 12.0, h * 0.5, 0), Vector3(10.0, h, 14.0), col.darkened(0.08))
	ctx.buildings += 1
