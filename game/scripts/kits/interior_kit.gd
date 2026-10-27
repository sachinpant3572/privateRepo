extends RefCounted
## Rooms behind the places' doors (places.gd), built in code like the city:
## one vertex-coloured mesh, collision boxes and the spots people use. Room
## space: floor at y = 0 centred on the origin, width along X, depth along
## Z, the street door in the front wall (+Z, nearest the camera), which is
## drawn low like a doll's house so the camera sees in.
##
## build() returns {mesh (MeshBuilder), colliders ([center, size]), size
## (Vector2), door (the doorway), hub (just inside it: where people come
## in, go out and where the EXIT prompt is), counter ({pos, yaw}: where the
## player buys), staff ([{pos, yaw, gesture}]), spots ([{kind, pos, yaw,
## path}]) and focus (camera centre)}. A spot's path runs from the hub to
## the spot through open floor; kinds are "browse", "till", "order",
## "seat" and "stool".

const MeshBuilder = preload("res://scripts/mesh_builder.gd")

const WALL_H := 3.2
const FRONT_H := 0.6
const WALL_T := 0.2
const DOOR_W := 1.6
## Seat height for people sitting (Rig's sit pose matches it).
const SEAT_Y := 0.45

const PRODUCTS := [
	Color(0.85, 0.2, 0.18), Color(0.95, 0.75, 0.15), Color(0.2, 0.5, 0.85), Color(0.25, 0.65, 0.3),
	Color(0.95, 0.5, 0.15), Color(0.6, 0.3, 0.7), Color(0.95, 0.95, 0.92), Color(0.15, 0.15, 0.18),
	Color(0.9, 0.4, 0.55), Color(0.55, 0.35, 0.2),
]
const STEEL := Color(0.72, 0.74, 0.77)
const WOOD := Color(0.55, 0.38, 0.24)
const DARK := Color(0.14, 0.15, 0.17)


static func build(type: String, seed_v: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	match type:
		"diner":
			return _diner(rng)
		_:
			return _corner_store(rng)


# --- Rooms -----------------------------------------------------------------------

## About 11 x 13 m: two gondola aisles, shelving down the left wall, drinks
## fridges along the back and the counter by the door on the right.
static func _corner_store(rng: RandomNumberGenerator) -> Dictionary:
	var mb := MeshBuilder.new()
	var out: Array = []
	var w := 11.0
	var d := 13.0
	var hx := w * 0.5
	var hz := d * 0.5
	var wall: Color = [Color(0.93, 0.92, 0.88), Color(0.86, 0.92, 0.9), Color(0.95, 0.9, 0.82)][rng.randi() % 3]
	var stripe: Color = [Color(0.1, 0.55, 0.5), Color(0.75, 0.2, 0.2), Color(0.2, 0.35, 0.65)][rng.randi() % 3]
	_checker(mb, w, d, 1.0, Color(0.86, 0.86, 0.83), Color(0.7, 0.72, 0.73))
	_walls(mb, out, w, d, wall, stripe)
	# Gondolas: double-sided shelves running front to back.
	for gx in [-2.6, -0.2]:
		_gondola(mb, out, Vector3(gx, 0, -0.75), 5.5, rng)
	# Wall shelving down the left side, fridges along the back.
	_wall_shelf(mb, out, Vector3(-hx + WALL_T + 0.25, 0, -1.2), 7.5, rng)
	for k in 4:
		_fridge(mb, out, Vector3(-3.9 + k * 1.9, 0, -hz + WALL_T + 0.35), rng)
	# Counter, till, rack of cigarettes and lotto behind the clerk.
	var cx := hx - 2.2
	_solid(mb, out, Vector3(cx, 0.5, hz - 3.3), Vector3(0.7, 1.0, 3.6), WOOD.darkened(0.2))
	mb.box(Vector3(cx, 1.03, hz - 3.3), Vector3(0.8, 0.06, 3.7), DARK)
	mb.box(Vector3(cx, 1.2, hz - 2.6), Vector3(0.35, 0.3, 0.4), DARK)
	mb.box(Vector3(cx + 0.05, 1.42, hz - 2.6), Vector3(0.05, 0.3, 0.4), MeshBuilder.glow(Color(0.4, 0.75, 0.95), MeshBuilder.GLOSS))
	for k in 6:
		mb.box(Vector3(cx, 1.1, hz - 4.6 + k * 0.18), Vector3(0.3, 0.14, 0.12), PRODUCTS[rng.randi() % PRODUCTS.size()])
	var rack_x := hx - WALL_T - 0.2
	_solid(mb, out, Vector3(rack_x, 1.2, hz - 3.3), Vector3(0.35, 2.4, 3.0), DARK)
	for row in 5:
		for k in 12:
			mb.box(Vector3(rack_x - 0.19, 0.5 + row * 0.38, hz - 4.6 + k * 0.22), Vector3(0.04, 0.26, 0.16), PRODUCTS[rng.randi() % PRODUCTS.size()])
	# Ice chest and a newspaper stand by the door.
	_solid(mb, out, Vector3(-hx + 1.4, 0.45, hz - 1.0), Vector3(1.6, 0.9, 0.8), Color(0.92, 0.95, 0.97))
	mb.box(Vector3(-hx + 1.4, 0.92, hz - 1.0), Vector3(1.4, 0.04, 0.6), MeshBuilder.glow(Color(0.3, 0.55, 0.85), MeshBuilder.GLOSS))
	_solid(mb, out, Vector3(-hx + 3.0, 0.5, hz - 0.8), Vector3(0.6, 1.0, 0.5), Color(0.2, 0.35, 0.6))
	var hub := Vector3(0, 0, hz - 1.4)
	var spots: Array = []
	# Browsing: both sides of each gondola, the wall shelf and the fridges.
	for aisle in [[-4.0, -1.0], [-1.4, -1.0], [-1.4, 1.0], [0.95, -1.0]]:
		var ax: float = aisle[0]
		for z in [-2.6, 0.4]:
			spots.append(_spot("browse", Vector3(ax, 0, z), Vector3(aisle[1], 0, 0), [Vector3(ax, 0, 3.0)]))
	for k in 4:
		var fx := -3.9 + k * 1.9
		spots.append(_spot("browse", Vector3(fx, 0, -hz + 1.35), Vector3.FORWARD, [Vector3(1.0, 0, 3.0), Vector3(1.0, 0, -4.6), Vector3(fx, 0, -4.6)]))
	var till := Vector3(cx - 1.1, 0, hz - 3.0)
	spots.append(_spot("till", till, Vector3.RIGHT, [Vector3(till.x, 0, hub.z)]))
	return {
		"mesh": mb, "colliders": out, "size": Vector2(w, d), "door": Vector3(0, 0, hz), "hub": hub,
		"counter": {"pos": till, "yaw": _yaw(Vector3.RIGHT)},
		"staff": [{"pos": Vector3(cx + 0.8, 0, hz - 3.0), "yaw": _yaw(Vector3.LEFT), "gesture": "work"}],
		"spots": spots, "focus": Vector3(0, 0, 0.6),
	}


## About 15 x 11 m: a counter with stools in front of the kitchen line,
## booths on both side walls, two-tops in the middle and the register by
## the door.
static func _diner(rng: RandomNumberGenerator) -> Dictionary:
	var mb := MeshBuilder.new()
	var out: Array = []
	var w := 15.0
	var d := 11.0
	var hx := w * 0.5
	var hz := d * 0.5
	var red: Color = [Color(0.75, 0.13, 0.15), Color(0.15, 0.5, 0.55), Color(0.9, 0.55, 0.15)][rng.randi() % 3]
	var vinyl: Color = red.lightened(0.05)
	var chrome := MeshBuilder.glow(STEEL, MeshBuilder.METAL)
	var top := MeshBuilder.glow(Color(0.92, 0.9, 0.86), MeshBuilder.GLOSS)
	_checker(mb, w, d, 0.8, Color(0.94, 0.93, 0.9), Color(0.12, 0.12, 0.13))
	_walls(mb, out, w, d, Color(0.96, 0.93, 0.85), red)
	# Kitchen line along the back wall: grill, fryers, coffee and a pie case.
	var kz := -hz + WALL_T + 0.45
	_solid(mb, out, Vector3(-1.0, 0.45, kz), Vector3(9.0, 0.9, 0.9), chrome)
	mb.box(Vector3(-2.6, 0.93, kz), Vector3(2.2, 0.06, 0.7), DARK)
	for k in 3:
		mb.box(Vector3(-0.5 + k * 0.7, 0.98, kz), Vector3(0.5, 0.12, 0.6), Color(0.2, 0.2, 0.22))
	mb.box(Vector3(2.2, 1.3, kz), Vector3(0.8, 0.8, 0.6), DARK)
	mb.box(Vector3(2.2, 1.35, kz + 0.31), Vector3(0.5, 0.3, 0.02), MeshBuilder.glow(Color(0.9, 0.3, 0.2), MeshBuilder.GLOW_NEON))
	mb.box(Vector3(-1.0, 2.4, -hz + WALL_T + 0.2), Vector3(9.0, 0.6, 0.4), chrome)
	# The counter, its stools and the pie case on it.
	var cz := -hz + 3.0
	_solid(mb, out, Vector3(-0.75, 0.52, cz), Vector3(8.5, 1.05, 0.7), red.darkened(0.15))
	mb.box(Vector3(-0.75, 1.07, cz), Vector3(8.7, 0.06, 0.85), top)
	mb.box(Vector3(-0.75, 0.12, cz + 0.36), Vector3(8.5, 0.12, 0.04), chrome)
	mb.box(Vector3(2.6, 1.35, cz), Vector3(1.0, 0.5, 0.5), MeshBuilder.glow(Color(0.8, 0.85, 0.9), MeshBuilder.GLASS))
	for k in 3:
		mb.cylinder(Vector3(2.3 + k * 0.3, 1.12, cz), 0.13, 0.12, [Color(0.85, 0.6, 0.3), Color(0.55, 0.2, 0.25), Color(0.95, 0.85, 0.5)][k], 8)
	var stools: Array = []
	for k in 7:
		var sx := -4.4 + k * 1.1
		mb.cylinder(Vector3(sx, 0, cz + 0.85), 0.05, SEAT_Y - 0.06, chrome, 5)
		mb.cylinder(Vector3(sx, SEAT_Y - 0.08, cz + 0.85), 0.22, 0.08, vinyl, 8)
		stools.append(Vector3(sx, 0, cz + 0.85))
	# Booths on the side walls and two-tops in the middle.
	var seats: Array = [] # [pos, facing, path]
	for side in [-1.0, 1.0]:
		var zs: Array = [0.0, 2.6] if side < 0.0 else [-0.3]
		for zc in zs:
			var tx: float = side * (hx - WALL_T - 0.75)
			_booth(mb, out, Vector3(tx, 0, zc), vinyl, top, chrome)
			for bz in [-0.8, 0.8]:
				for along in [0.3, 0.95]:
					var p := Vector3(side * (hx - WALL_T - along), 0, zc + bz)
					# Down the lane beside the booths; the last step slides in.
					var lane: float = side * 5.4
					var path: Array = [Vector3(0, 0, 0.3), Vector3(lane, 0, 0.3), Vector3(lane, 0, p.z)]
					if side < 0.0:
						path = [Vector3(lane, 0, 4.0), Vector3(lane, 0, p.z)]
					seats.append([p, Vector3(0, 0, -signf(bz)), path])
	for tx in [-3.2, 2.8]:
		_two_top(mb, out, Vector3(tx, 0, 2.2), vinyl, top, chrome)
		seats.append([Vector3(tx, 0, 1.55), Vector3.BACK, [Vector3(0, 0, 0.3), Vector3(tx, 0, 0.9)]])
		seats.append([Vector3(tx, 0, 2.85), Vector3.FORWARD, [Vector3(tx, 0, 4.0), Vector3(tx, 0, 3.5)]])
	# Register by the door.
	var reg := Vector3(hx - 1.9, 0, 2.5)
	_solid(mb, out, reg + Vector3(0, 1.0, 0), Vector3(0.8, 2.0, 1.7), Color(0, 0, 0, 0), false)
	mb.box(Vector3(reg.x, 0.5, reg.z), Vector3(0.7, 1.0, 1.6), red.darkened(0.15))
	mb.box(Vector3(reg.x, 1.03, reg.z), Vector3(0.8, 0.06, 1.7), top)
	mb.box(Vector3(reg.x, 1.2, reg.z + 0.3), Vector3(0.4, 0.3, 0.4), DARK)
	# Jukebox and a gumball machine.
	_solid(mb, out, Vector3(-hx + 0.6, 0.75, hz - 1.6), Vector3(0.8, 1.5, 0.7), Color(0.55, 0.25, 0.15))
	mb.box(Vector3(-hx + 0.97, 1.0, hz - 1.6), Vector3(0.05, 0.9, 0.5), MeshBuilder.glow(Color(1.0, 0.7, 0.3), MeshBuilder.GLOW_NEON))
	mb.ball(Vector3(hx - 0.8, 1.2, hz - 1.0), Vector3(0.25, 0.25, 0.25), MeshBuilder.glow(Color(0.85, 0.85, 0.9), MeshBuilder.GLASS), 8, 4)
	mb.cylinder(Vector3(hx - 0.8, 0, hz - 1.0), 0.08, 0.95, red, 6)
	var hub := Vector3(0, 0, hz - 1.4)
	var spots: Array = []
	for p in seats:
		spots.append(_spot("seat", p[0], p[1], p[2]))
	for s in stools:
		spots.append(_spot("stool", s, Vector3.FORWARD, [Vector3(0, 0, 0.3), Vector3(s.x, 0, 0.3)]))
	var order := Vector3(reg.x - 1.0, 0, reg.z)
	spots.append(_spot("order", order, Vector3.RIGHT, [Vector3(order.x, 0, hub.z)]))
	return {
		"mesh": mb, "colliders": out, "size": Vector2(w, d), "door": Vector3(0, 0, hz), "hub": hub,
		"counter": {"pos": order, "yaw": _yaw(Vector3.RIGHT)},
		"staff": [
			{"pos": Vector3(reg.x + 0.85, 0, reg.z), "yaw": _yaw(Vector3.LEFT), "gesture": "work"},
			{"pos": Vector3(-2.4, 0, kz + 0.9), "yaw": _yaw(Vector3.FORWARD), "gesture": "work"},
			{"pos": Vector3(0.8, 0, cz - 0.75), "yaw": _yaw(Vector3.BACK), "gesture": "talk"},
		],
		"spots": spots, "focus": Vector3(0, 0, 0.4),
	}


# --- Pieces ----------------------------------------------------------------------

static func _spot(kind: String, pos: Vector3, facing: Vector3, path: Array) -> Dictionary:
	var full: Array = path.duplicate()
	full.append(pos)
	return {"kind": kind, "pos": pos, "yaw": _yaw(facing), "path": full}


## The yaw that turns a humanoid to face `dir`.
static func _yaw(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


static func _solid(mb, out: Array, center: Vector3, size: Vector3, color: Color, draw := true) -> void:
	if draw:
		mb.box(center, size, color)
	out.append([center, size])


## Floor tiles in two colours.
static func _checker(mb, w: float, d: float, tile: float, a: Color, b: Color) -> void:
	var nx := int(ceil(w / tile))
	var nz := int(ceil(d / tile))
	for i in nx:
		for j in nz:
			var x0 := -w * 0.5 + i * tile
			var z0 := -d * 0.5 + j * tile
			var x1 := minf(x0 + tile, w * 0.5)
			var z1 := minf(z0 + tile, d * 0.5)
			mb.box(Vector3((x0 + x1) * 0.5, -0.01, (z0 + z1) * 0.5), Vector3(x1 - x0, 0.02, z1 - z0), a if (i + j) % 2 == 0 else b)


## Back and side walls full height with a colour band and a skirting; the
## front wall low with the doorway, a light spill outside it and a stop so
## nobody walks out into nothing.
static func _walls(mb, out: Array, w: float, d: float, color: Color, band: Color) -> void:
	var hx := w * 0.5
	var hz := d * 0.5
	var t := WALL_T
	_solid(mb, out, Vector3(0, WALL_H * 0.5, -hz - t * 0.5), Vector3(w + t * 2.0, WALL_H, t), color)
	for side in [-1.0, 1.0]:
		_solid(mb, out, Vector3(side * (hx + t * 0.5), WALL_H * 0.5, 0), Vector3(t, WALL_H, d), color)
		mb.box(Vector3(side * (hx - 0.01), 1.1, 0), Vector3(0.02, 0.18, d), band)
		mb.box(Vector3(side * (hx - 0.01), 0.06, 0), Vector3(0.03, 0.12, d), color.darkened(0.35))
		var seg := hx - DOOR_W * 0.5
		var sx: float = side * (DOOR_W * 0.5 + seg * 0.5)
		mb.box(Vector3(sx, FRONT_H * 0.5, hz + t * 0.5), Vector3(seg, FRONT_H, t), color.darkened(0.08))
		mb.box(Vector3(sx, FRONT_H + 0.02, hz + t * 0.5), Vector3(seg + 0.02, 0.04, t + 0.04), band)
		out.append([Vector3(sx, WALL_H * 0.5, hz + t * 0.5), Vector3(seg, WALL_H, t)])
		mb.box(Vector3(side * (DOOR_W * 0.5 + 0.05), FRONT_H * 0.5 + 0.1, hz + t * 0.5), Vector3(0.1, FRONT_H + 0.2, t + 0.06), DARK)
	mb.box(Vector3(0, 1.1, -hz + 0.01), Vector3(w, 0.18, 0.02), band)
	mb.box(Vector3(0, 0.06, -hz + 0.01), Vector3(w, 0.12, 0.03), color.darkened(0.35))
	# Doormat and the daylight beyond the door.
	mb.box(Vector3(0, 0.005, hz - 0.5), Vector3(DOOR_W - 0.2, 0.01, 0.8), Color(0.25, 0.2, 0.18))
	mb.box(Vector3(0, -0.01, hz + 1.0), Vector3(DOOR_W + 0.6, 0.02, 1.8), Color(0.78, 0.77, 0.72))
	out.append([Vector3(0, 1.0, hz + 1.2), Vector3(DOOR_W + 0.4, 2.0, 0.4)])


## A double-sided shelf unit `length` long (along Z) with products.
static func _gondola(mb, out: Array, c: Vector3, length: float, rng: RandomNumberGenerator) -> void:
	var h := 1.6
	_solid(mb, out, c + Vector3(0, h * 0.5, 0), Vector3(0.9, h, length), STEEL.darkened(0.15))
	mb.box(c + Vector3(0, h + 0.15, -length * 0.5 + 0.05), Vector3(0.9, 0.3, 0.06), MeshBuilder.glow(Color(0.95, 0.75, 0.2), MeshBuilder.GLOSS))
	for side in [-1.0, 1.0]:
		for level in 4:
			var y := 0.2 + level * 0.38
			mb.box(c + Vector3(side * 0.47, y - 0.02, 0), Vector3(0.06, 0.04, length), STEEL)
			_products(mb, c + Vector3(side * 0.47, y, 0), length, side, rng)
	# Top shelf boxes.
	var z := -length * 0.5 + 0.3
	while z < length * 0.5 - 0.3:
		var s := rng.randf_range(0.3, 0.5)
		mb.box(c + Vector3(0, h + s * 0.5, z), Vector3(0.6, s, s), PRODUCTS[rng.randi() % PRODUCTS.size()].darkened(0.1))
		z += s + 0.15


## A row of packets along a shelf face (side -1 faces -X, 1 faces +X).
static func _products(mb, at: Vector3, length: float, side: float, rng: RandomNumberGenerator) -> void:
	var z := -length * 0.5 + 0.1
	while z < length * 0.5 - 0.15:
		var pw := rng.randf_range(0.14, 0.32)
		var ph := rng.randf_range(0.16, 0.3)
		var color: Color = PRODUCTS[rng.randi() % PRODUCTS.size()]
		var run := rng.randi_range(1, 4)
		for k in run:
			if z + pw > length * 0.5 - 0.1:
				break
			mb.box(at + Vector3(side * 0.03, ph * 0.5, z + pw * 0.5), Vector3(0.12, ph, pw - 0.03), color)
			z += pw
		z += 0.04


## Single-sided wall shelving facing +X.
static func _wall_shelf(mb, out: Array, c: Vector3, length: float, rng: RandomNumberGenerator) -> void:
	var h := 2.0
	_solid(mb, out, c + Vector3(0, h * 0.5, 0), Vector3(0.5, h, length), STEEL.darkened(0.2))
	for level in 5:
		var y := 0.2 + level * 0.36
		mb.box(c + Vector3(0.27, y - 0.02, 0), Vector3(0.06, 0.04, length), STEEL)
		_products(mb, c + Vector3(0.27, y, 0), length, 1.0, rng)


## A glass-door drinks fridge against the back wall, facing +Z.
static func _fridge(mb, out: Array, c: Vector3, rng: RandomNumberGenerator) -> void:
	_solid(mb, out, c + Vector3(0, 1.05, 0), Vector3(1.8, 2.1, 0.7), DARK)
	mb.box(c + Vector3(0, 1.0, 0.33), Vector3(1.6, 1.8, 0.04), Color(0.82, 0.92, 0.98))
	for level in 4:
		var y := 0.35 + level * 0.42
		var x := -0.7
		while x < 0.7:
			mb.box(c + Vector3(x + 0.07, y + 0.12, 0.37), Vector3(0.1, 0.24, 0.04), PRODUCTS[rng.randi() % PRODUCTS.size()])
			x += 0.14
	for k in 3:
		mb.box(c + Vector3(-0.9 + k * 0.9, 1.0, 0.37), Vector3(0.05, 1.9, 0.04), STEEL)
	mb.box(c + Vector3(0, 2.0, 0.37), Vector3(1.8, 0.14, 0.04), MeshBuilder.glow(Color(0.85, 0.95, 1.0), MeshBuilder.GLOW_NEON))


## A booth against a side wall: table out from the wall, benches either side
## (along Z), high padded backs.
static func _booth(mb, out: Array, c: Vector3, vinyl: Color, top: Color, chrome: Color) -> void:
	_table(mb, out, c, Vector3(1.3, 0, 0.8), top, chrome)
	for side in [-1.0, 1.0]:
		var b := c + Vector3(0, 0, side * 0.8)
		_solid(mb, out, b + Vector3(0, SEAT_Y * 0.5, side * 0.05), Vector3(1.5, SEAT_Y, 0.5), vinyl.darkened(0.2))
		mb.box(b + Vector3(0, SEAT_Y + 0.04, side * 0.05), Vector3(1.5, 0.08, 0.5), vinyl)
		_solid(mb, out, b + Vector3(0, 0.6, side * 0.38), Vector3(1.5, 1.2, 0.18), vinyl)


## A small square table with two chairs (along Z).
static func _two_top(mb, out: Array, c: Vector3, vinyl: Color, top: Color, chrome: Color) -> void:
	_table(mb, out, c, Vector3(0.8, 0, 0.8), top, chrome)
	for side in [-1.0, 1.0]:
		var s := c + Vector3(0, 0, side * 0.65)
		mb.box(s + Vector3(0, SEAT_Y - 0.03, 0), Vector3(0.45, 0.06, 0.45), vinyl)
		mb.box(s + Vector3(0, 0.75, side * 0.21), Vector3(0.45, 0.6, 0.05), vinyl.darkened(0.15))
		mb.cylinder(s, 0.04, SEAT_Y - 0.06, chrome, 5)


static func _table(mb, out: Array, c: Vector3, size: Vector3, top: Color, chrome: Color) -> void:
	mb.box(c + Vector3(0, 0.76, 0), Vector3(size.x, 0.05, size.z), top)
	mb.box(c + Vector3(0, 0.73, 0), Vector3(size.x + 0.04, 0.03, size.z + 0.04), chrome)
	mb.cylinder(c, 0.06, 0.72, chrome, 6)
	# Napkins, ketchup and a sugar pot.
	mb.box(c + Vector3(-size.x * 0.3, 0.83, 0), Vector3(0.12, 0.1, 0.08), STEEL)
	mb.cylinder(c + Vector3(-size.x * 0.3 + 0.12, 0.79, 0.06), 0.03, 0.15, Color(0.8, 0.1, 0.1), 5)
	out.append([c + Vector3(0, 0.4, 0), Vector3(size.x, 0.8, size.z)])
