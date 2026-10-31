extends RefCounted
## Hill kit (HANDOFF-hill-content.md): the places of the hill country behind
## the city. A secret government research lab and its checkpoint, a sawmill,
## a religious compound, a ranger post, an illegal logging camp, an
## abandoned mine, a stone ring, hot and cold springs, a five-star mountain
## hotel and a log lodge, a rave clearing, a bungee platform, a small-town
## fairground and a hunting store. Pure data in, mesh out: static functions
## only, no scene tree, so a tile builds on a worker thread.
##
## World bible: these are PLACES, never people or groups. No real brands,
## logos or readable text anywhere: signs are colour fields and abstract
## glyph bars. The cult is an invented faith with no real religious symbol:
## its motif is a ring of tall pale poles and a sun disc of concentric
## rings painted on the hall roof.
##
## Frame and colliders as in shady_kit.gd: the lot spans x in [-w/2, w/2]
## (along the front) and z in [-d/2, d/2], the entrance faces the road at
## -Z, ground at y = 0, and everything stays on the lot. Collision boxes go
## to `out` as [center, size] or [center, size, yaw]; flat things (under
## 0.7 m: slabs, rails, rugs, water) get none, and things you walk under
## (roofs, canopies, the bungee deck) collide only through their posts.
##
## Each kind is authored on its default lot and scaled in plan to the lot it
## is given (height unchanged), so any lot size keeps every part on the lot
## and the triangle count does not grow. lab_gate is the exception: its
## 7 m lane is a fixed width, so it lays itself out in metres.
##
## The game camera is a perspective top-down, about 60 degrees down, so
## roofs, yards and the south (-Z) faces carry the detail.

const MeshBuilder = preload("res://scripts/mesh_builder.gd")
const Kit = preload("res://scripts/kits/country_kit.gd")

const KINDS := [
	"research_lab", "lab_gate", "sawmill", "cult_compound", "ranger_post", "logging_camp",
	"mine_entrance", "stone_ring", "hot_spring", "cold_spring", "mountain_hotel", "lodge_hotel",
	"rave_clearing", "bungee_platform", "fairground", "hunting_store",
]

## Default lot of each kind: x along the front, y deep, metres.
const SIZES := {
	"research_lab": Vector2(90, 70), "lab_gate": Vector2(24, 16), "sawmill": Vector2(60, 44),
	"cult_compound": Vector2(80, 70), "ranger_post": Vector2(24, 20), "logging_camp": Vector2(40, 34),
	"mine_entrance": Vector2(30, 24), "stone_ring": Vector2(24, 24), "hot_spring": Vector2(16, 14),
	"cold_spring": Vector2(12, 10), "mountain_hotel": Vector2(60, 44), "lodge_hotel": Vector2(44, 32),
	"rave_clearing": Vector2(36, 30), "bungee_platform": Vector2(12, 10), "fairground": Vector2(70, 50),
	"hunting_store": Vector2(16, 20),
}

const CONCRETE := Color(0.62, 0.63, 0.61)
const CONCRETE_DK := Color(0.45, 0.46, 0.46)
const CONCRETE_LT := Color(0.74, 0.74, 0.71)
const APRON := Color(0.5, 0.52, 0.5)
const ASPHALT := Color(0.21, 0.21, 0.23)
const GRAVEL := Color(0.6, 0.57, 0.5)
const DIRT := Color(0.5, 0.41, 0.3)
const MUD := Color(0.3, 0.24, 0.18)
const GALV := Color(0.68, 0.71, 0.74)
const STEEL := Color(0.58, 0.6, 0.63)
const STEEL_DK := Color(0.28, 0.3, 0.33)
const IRON := Color(0.11, 0.11, 0.12)
const BLACK := Color(0.06, 0.06, 0.07)
const RUST := Color(0.5, 0.29, 0.18)
const RUST_DK := Color(0.36, 0.2, 0.13)
const TIMBER := Color(0.46, 0.32, 0.2)
const TIMBER_DK := Color(0.3, 0.2, 0.13)
const TIMBER_LT := Color(0.66, 0.5, 0.32)
const PINE := Color(0.74, 0.58, 0.36)
const LOG := Color(0.5, 0.35, 0.22)
const LOG_END := Color(0.8, 0.66, 0.44)
const BARK := Color(0.3, 0.22, 0.16)
const SAWDUST := Color(0.76, 0.6, 0.38)
const ROCK := Color(0.52, 0.5, 0.47)
const ROCK_DK := Color(0.36, 0.35, 0.34)
const ROCK_WARM := Color(0.6, 0.53, 0.45)
const MOSS := Color(0.32, 0.45, 0.24)
const LEAF := Color(0.3, 0.44, 0.22)
const GREEN_DK := Color(0.16, 0.3, 0.2)
const WHITE := Color(0.93, 0.93, 0.9)
const CREAM := Color(0.9, 0.85, 0.7)
const YELLOW := Color(0.95, 0.78, 0.15)
const RED := Color(0.72, 0.16, 0.14)
const ORANGE := Color(0.9, 0.45, 0.12)
const GLASS_C := Color(0.2, 0.27, 0.32)
const DOME := Color(0.9, 0.91, 0.92)
const WATER := Color(0.3, 0.72, 0.85)
const MILK := Color(0.52, 0.86, 0.82)
const SHINGLE := Color(0.33, 0.3, 0.29)
const SHINGLE_RED := Color(0.45, 0.22, 0.17)
## Canvas, paints and sign fields (plain colour, no words).
const CANVAS := [Color(0.62, 0.6, 0.42), Color(0.72, 0.66, 0.5), Color(0.4, 0.5, 0.36), Color(0.75, 0.75, 0.7)]
const TENTS := [Color(0.2, 0.45, 0.75), Color(0.85, 0.55, 0.15), Color(0.3, 0.55, 0.35), Color(0.6, 0.2, 0.2), Color(0.55, 0.45, 0.7), Color(0.9, 0.35, 0.55), Color(0.25, 0.7, 0.7)]
const NEONS := [Color(1.0, 0.3, 0.55), Color(0.3, 0.85, 1.0), Color(1.0, 0.75, 0.2), Color(0.55, 1.0, 0.45), Color(0.8, 0.4, 1.0)]
const SIGN_FIELDS := [Color(0.98, 0.85, 0.2), Color(0.95, 0.95, 0.92), Color(0.2, 0.62, 0.38), Color(0.82, 0.22, 0.18), Color(0.25, 0.5, 0.85), Color(1.0, 0.55, 0.15)]
const DARK_CARS := [Color(0.07, 0.07, 0.08), Color(0.12, 0.13, 0.16), Color(0.2, 0.21, 0.23), Color(0.08, 0.1, 0.14)]
const CAR_PAINTS := [Color(0.55, 0.15, 0.15), Color(0.2, 0.3, 0.45), Color(0.7, 0.68, 0.62), Color(0.25, 0.25, 0.27), Color(0.35, 0.45, 0.35), Color(0.6, 0.5, 0.3), Color(0.82, 0.82, 0.8)]


## Every kind this kit builds.
static func kinds() -> Array:
	return KINDS


## The default lot of `kind` (x along the front, y deep, metres).
static func default_size(kind: String) -> Vector2:
	return SIZES.get(kind, Vector2(20, 20))


## Triangle budget of `kind` (the test's rule: big lots 8000, the rest 5000).
static func budget(kind: String) -> int:
	var s := default_size(kind)
	return 8000 if s.x * s.y >= 5000.0 else 5000


## Builds `kind` on a lot of `size` (x along the front, y deep). See the
## header for the frame and the collision format.
static func build(kind: String, mb, out: Array, size: Vector2, rng: RandomNumberGenerator) -> void:
	var w := maxf(size.x, 0.6)
	var d := maxf(size.y, 0.6)
	if kind == "lab_gate":
		lab_gate(mb, out, w, d, rng)
		return
	if not SIZES.has(kind):
		# Unknown kind: a plain magenta block, so a typo shows instead of a hole.
		Kit._solid(mb, out, Vector3(0, 2.0, 0), Vector3(w * 0.6, 4.0, d * 0.6), Color(1.0, 0.0, 1.0))
		return
	var def: Vector2 = SIZES[kind]
	var sc := Vector2(w / def.x, d / def.y)
	var saved: Transform3D = mb.xform
	mb.xform = saved * Transform3D(Basis.from_scale(Vector3(sc.x, 1.0, sc.y)), Vector3.ZERO)
	var local: Array = []
	match kind:
		"research_lab": research_lab(mb, local, def.x, def.y, rng)
		"sawmill": sawmill(mb, local, def.x, def.y, rng)
		"cult_compound": cult_compound(mb, local, def.x, def.y, rng)
		"ranger_post": ranger_post(mb, local, def.x, def.y, rng)
		"logging_camp": logging_camp(mb, local, def.x, def.y, rng)
		"mine_entrance": mine_entrance(mb, local, def.x, def.y, rng)
		"stone_ring": stone_ring(mb, local, def.x, def.y, rng)
		"hot_spring": hot_spring(mb, local, def.x, def.y, rng)
		"cold_spring": cold_spring(mb, local, def.x, def.y, rng)
		"mountain_hotel": mountain_hotel(mb, local, def.x, def.y, rng)
		"lodge_hotel": lodge_hotel(mb, local, def.x, def.y, rng)
		"rave_clearing": rave_clearing(mb, local, def.x, def.y, rng)
		"bungee_platform": bungee_platform(mb, local, def.x, def.y, rng)
		"fairground": fairground(mb, local, def.x, def.y, rng)
		"hunting_store": hunting_store(mb, local, def.x, def.y, rng)
	mb.xform = saved
	_scale_cols(local, sc, out)


## Moves colliders authored on the default lot onto the lot built: centres
## and plan sizes stretch with the lot (a turned box by its own axes).
static func _scale_cols(local: Array, sc: Vector2, out: Array) -> void:
	var mean := (sc.x + sc.y) * 0.5
	for col in local:
		var c: Vector3 = col[0]
		var s: Vector3 = col[1]
		var yaw: float = col[2] if col.size() > 2 else 0.0
		var ns := s
		var half_turn := absf(sin(yaw))
		if half_turn < 0.01:
			ns = Vector3(s.x * sc.x, s.y, s.z * sc.y)
		elif half_turn > 0.99:
			ns = Vector3(s.x * sc.y, s.y, s.z * sc.x)
		else:
			ns = Vector3(s.x * mean, s.y, s.z * mean)
		var nc := Vector3(c.x * sc.x, c.y, c.z * sc.y)
		if col.size() > 2:
			out.append([nc, ns, yaw] + col.slice(3))
		else:
			out.append([nc, ns])


# --- Helpers ------------------------------------------------------------------

static func _g(c: Color, code: float) -> Color:
	return MeshBuilder.glow(c, code)


static func _vary(c: Color, rng: RandomNumberGenerator, amount := 0.06) -> Color:
	var k := 1.0 + rng.randf_range(-amount, amount)
	return Color(clampf(c.r * k, 0.0, 1.0), clampf(c.g * k, 0.0, 1.0), clampf(c.b * k, 0.0, 1.0), c.a)


static func _pick(list: Array, rng: RandomNumberGenerator) -> Color:
	return list[rng.randi() % list.size()]


## Moves the builder to p, turned by yaw; returns the transform to restore.
static func _push(mb, p: Vector3, yaw: float) -> Transform3D:
	var saved: Transform3D = mb.xform
	mb.xform = saved * Transform3D(Basis(Vector3.UP, yaw), p)
	return saved


## A box by its bounds.
static func _bx(mb, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, color: Color) -> void:
	mb.box(Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5), Vector3(x1 - x0, y1 - y0, z1 - z0), color)


## A box by its bounds, with a collider.
static func _sx(mb, out: Array, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, color: Color) -> void:
	var c := Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5)
	var s := Vector3(x1 - x0, y1 - y0, z1 - z0)
	mb.box(c, s, color)
	out.append([c, s])


## A box turned by `yaw` about its centre.
static func _rbox(mb, c: Vector3, size: Vector3, yaw: float, color: Color) -> void:
	var saved := _push(mb, c, yaw)
	mb.box(Vector3.ZERO, size, color)
	mb.xform = saved


## A box turned by `yaw` about its centre, with a collider.
static func _rsx(mb, out: Array, c: Vector3, size: Vector3, yaw: float, color: Color) -> void:
	_rbox(mb, c, size, yaw, color)
	Kit._col(out, c, size, yaw)


## A box turned by any basis about its centre (leaning and tipped things).
static func _tbox(mb, c: Vector3, size: Vector3, basis: Basis, color: Color) -> void:
	var saved: Transform3D = mb.xform
	mb.xform = saved * Transform3D(basis, c)
	mb.box(Vector3.ZERO, size, color, false)
	mb.xform = saved


## A flat panel on the plane z (facing -Z, or +Z with sign > 0).
static func _fz(mb, x0: float, x1: float, y0: float, y1: float, z: float, color: Color, sign := -1.0) -> void:
	mb.quad(Vector3(x0, y0, z), Vector3(x1, y0, z), Vector3(x1, y1, z), Vector3(x0, y1, z), Vector3(0, 0, sign), color)


## A flat panel on the plane x (facing -X, or +X with sign > 0).
static func _fx(mb, z0: float, z1: float, y0: float, y1: float, x: float, color: Color, sign := 1.0) -> void:
	mb.quad(Vector3(x, y0, z0), Vector3(x, y0, z1), Vector3(x, y1, z1), Vector3(x, y1, z0), Vector3(sign, 0, 0), color)


## A flat panel lying on the ground (or a roof) from x0..x1 by z0..z1 at y.
static func _fy(mb, x0: float, x1: float, z0: float, z1: float, y: float, color: Color) -> void:
	mb.quad(Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1), Vector3.UP, color)


## A flat ribbon from a to b, w wide, facing n and -n (wire, brace, strap).
static func _strap(mb, a: Vector3, b: Vector3, w: float, n: Vector3, color: Color) -> void:
	var dv := b - a
	if dv.length() < 0.01:
		return
	var side := dv.cross(n).normalized() * w * 0.5
	mb.quad(a - side, b - side, b + side, a + side, n, color)
	mb.quad(a - side, b - side, b + side, a + side, -n, color)


## A flat disc facing up.
static func _disc(mb, c: Vector3, r: float, color: Color, segs := 12) -> void:
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		mb.tri(c, c + Vector3(cos(a0), 0, sin(a0)) * r, c + Vector3(cos(a1), 0, sin(a1)) * r, Vector3.UP, color)


## A flat ring facing up between radii r0 and r1 (stretched by rz/rx).
static func _ring(mb, c: Vector3, r0: float, r1: float, color: Color, segs := 16, squash := 1.0) -> void:
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var d0 := Vector3(cos(a0), 0, sin(a0) * squash)
		var d1 := Vector3(cos(a1), 0, sin(a1) * squash)
		mb.quad(c + d0 * r0, c + d1 * r0, c + d1 * r1, c + d0 * r1, Vector3.UP, color)


## A pole: a cylinder from the ground, collides.
static func _pole(mb, out: Array, p: Vector3, h: float, r: float, color: Color, sides := 5, collide := true) -> void:
	mb.cylinder(p, r, h, color, sides)
	if collide:
		out.append([p + Vector3(0, h * 0.5, 0), Vector3(r * 2.0, h, r * 2.0)])


## The normal of triangle a, b, c turned to agree with `hint`.
static func _face_n(a: Vector3, b: Vector3, c: Vector3, hint: Vector3) -> Vector3:
	var n := (b - a).cross(c - a).normalized()
	return -n if n.dot(hint) < 0.0 else n


## A rough rock: a faceted lump on the ground at p (base centre), radii
## r = (x, height, z), `lean` shifts the top. Colour `top` caps it.
static func _rock(mb, p: Vector3, r: Vector3, color: Color, rng: RandomNumberGenerator, sides := 5, lean := Vector2.ZERO, top := Color(0, 0, 0, 0), yaw := 0.0) -> void:
	var bot: Array[Vector3] = []
	var cap: Array[Vector3] = []
	var a0 := rng.randf() * TAU
	for i in sides:
		var a := a0 + TAU * i / sides + rng.randf_range(-0.22, 0.22)
		var k := rng.randf_range(0.82, 1.15)
		var kt := rng.randf_range(0.5, 0.78)
		var dir := Vector3(cos(a), 0, sin(a))
		bot.append(p + Basis(Vector3.UP, yaw) * (dir * Vector3(r.x, 0, r.z) * k))
		cap.append(p + Basis(Vector3.UP, yaw) * (dir * Vector3(r.x, 0, r.z) * kt + Vector3(lean.x, 0, lean.y)) + Vector3(0, r.y * rng.randf_range(0.86, 1.0), 0))
	var mid := Vector3.ZERO
	for v in cap:
		mid += v / sides
	var base_mid := Vector3(mid.x - lean.x, 0, mid.z - lean.y)
	var tc := top if top.a > 0.0 else color.lightened(0.08)
	for i in sides:
		var j := (i + 1) % sides
		var shade := color.darkened(0.12) if (i % 2) == 1 else color
		var out_n := ((bot[i] + bot[j]) * 0.5 - base_mid)
		out_n.y = r.y * 0.25
		mb.quad(bot[i], bot[j], cap[j], cap[i], out_n.normalized(), shade)
		mb.tri(mid, cap[i], cap[j], Vector3.UP, tc)


## A rock with a collider (a box over its footprint).
static func _boulder(mb, out: Array, p: Vector3, r: Vector3, color: Color, rng: RandomNumberGenerator, sides := 5) -> void:
	_rock(mb, p, r, color, rng, sides)
	if r.y >= 0.7:
		out.append([p + Vector3(0, r.y * 0.5, 0), Vector3(r.x * 1.5, r.y, r.z * 1.5)])


## A half dome of radius r (x, height, z) with its base ring at c.y.
static func _dome(mb, c: Vector3, r: Vector3, color: Color, sides := 10, rings := 3) -> void:
	for k in rings:
		var t0 := (PI * 0.5) * k / rings
		var t1 := (PI * 0.5) * (k + 1) / rings
		for i in sides:
			var a0 := TAU * i / sides
			var a1 := TAU * (i + 1) / sides
			var p00 := c + Vector3(cos(a0) * sin(t0), cos(t0), sin(a0) * sin(t0)) * r
			var p01 := c + Vector3(cos(a1) * sin(t0), cos(t0), sin(a1) * sin(t0)) * r
			var p10 := c + Vector3(cos(a0) * sin(t1), cos(t1), sin(a0) * sin(t1)) * r
			var p11 := c + Vector3(cos(a1) * sin(t1), cos(t1), sin(a1) * sin(t1)) * r
			var am := (a0 + a1) * 0.5
			var tm := (t0 + t1) * 0.5
			var n := Vector3(cos(am) * sin(tm) / r.x, cos(tm) / r.y, sin(am) * sin(tm) / r.z).normalized()
			if k == 0:
				mb.tri(p00, p10, p11, n, color)
			else:
				mb.quad(p00, p10, p11, p01, n, color)


## A frustum (cone with a flat top) of `sides`, base radius r0, top radius r1.
static func _frustum(mb, base: Vector3, r0: float, r1: float, h: float, color: Color, sides := 8, cap := true) -> void:
	var top := base + Vector3(0, h, 0)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var n := (((d0 + d1) * 0.5).normalized() * h + Vector3(0, r0 - r1, 0)).normalized()
		mb.quad(base + d0 * r0, base + d1 * r0, top + d1 * r1, top + d0 * r1, n, color)
		if cap and r1 > 0.01:
			mb.tri(top, top + d0 * r1, top + d1 * r1, Vector3.UP, color)


## A log lying from a to b (radius r), its b end cut pale.
static func _log(mb, a: Vector3, b: Vector3, r: float, color: Color, end_color := LOG_END, sides := 6) -> void:
	mb.limb(a, b, r, r, color, sides, false)
	var axis := (b - a).normalized()
	var side := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var up := side.cross(axis)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		mb.tri(b + axis * 0.01, b + (side * cos(a0) + up * sin(a0)) * r + axis * 0.01, b + (side * cos(a1) + up * sin(a1)) * r + axis * 0.01, axis, end_color)


## A stack of logs: rows of logs lying along `dir` (a unit vector in plan),
## `rows` high starting with `base` logs, centred on p. One collider.
static func _log_stack(mb, out: Array, p: Vector3, yaw: float, length: float, base: int, r: float, rng: RandomNumberGenerator, rows := -1, collide := true) -> void:
	var n := base if rows < 0 else mini(rows, base)
	var saved := _push(mb, p, yaw)
	var top := 0.0
	for row in n:
		var count := base - row
		for k in count:
			var x := (k - (count - 1) * 0.5) * r * 2.05
			var y := r + row * r * 1.8
			var jitter := rng.randf_range(-0.25, 0.25)
			_log(mb, Vector3(x, y, -length * 0.5 + jitter), Vector3(x, y, length * 0.5 + jitter), r, _vary(LOG, rng, 0.1), LOG_END, 5)
			top = y + r
	mb.xform = saved
	if collide:
		Kit._col(out, p + Vector3(0, top * 0.5, 0), Vector3(base * r * 2.05, top, length), yaw)


## A wire fence from a to b, h tall: posts about every `bay` m, a top rail,
## a criss-cross of mesh wires, and with `barbed` outriggers leaning to
## `outward` with two strands. Collides as one box.
static func _chain(mb, out: Array, a: Vector3, b: Vector3, h: float, outward: Vector3, bay := 5.5, barbed := true, collide := true) -> void:
	var dir := b - a
	var length := dir.length()
	if length < 0.5:
		return
	var u := dir / length
	var n := Vector3(-u.z, 0, u.x)
	if n.dot(outward) < 0.0:
		n = -n
	var count := maxi(1, roundi(length / bay))
	var step := length / count
	var galv := _g(GALV, MeshBuilder.METAL)
	var wire := _g(GALV.darkened(0.12), MeshBuilder.METAL)
	for i in count + 1:
		var p := a + u * (step * i)
		mb.box(p + Vector3(0, h * 0.5, 0), Vector3(0.16, h, 0.16), galv)
		if barbed:
			var tip := p + Vector3(0, h + 0.5, 0) + n * 0.6
			mb.tri(p + Vector3(0, h - 0.1, 0), p + Vector3(0, h + 0.05, 0) , tip, u, galv)
			mb.tri(p + Vector3(0, h - 0.1, 0), p + Vector3(0, h + 0.05, 0) , tip, -u, galv)
	for i in count:
		var p0 := a + u * (step * i)
		var p1 := a + u * (step * (i + 1))
		mb.box((p0 + p1) * 0.5 + Vector3(0, h - 0.05, 0), Vector3(absf(u.x) * step + 0.06, 0.1, absf(u.z) * step + 0.06), galv)
		_strap(mb, p0 + Vector3(0, 0.15, 0) + u * 0.1, p1 + Vector3(0, h - 0.2, 0) - u * 0.1, 0.1, n, wire)
		_strap(mb, p0 + Vector3(0, h - 0.2, 0) + u * 0.1, p1 + Vector3(0, 0.15, 0) - u * 0.1, 0.1, n, wire)
		if barbed:
			for k in 2:
				var off := n * (0.2 + 0.4 * k) + Vector3(0, h + 0.15 + 0.35 * k, 0)
				_strap(mb, p0 + off, p1 + off, 0.06, Vector3.UP, IRON)
	if collide:
		var mid := (a + b) * 0.5 + Vector3(0, h * 0.5, 0)
		var yaw := atan2(-dir.z, dir.x)
		Kit._col(out, mid, Vector3(length, h, 0.2), yaw)


## A plank fence from a to b, h tall: a solid board wall on posts every
## `bay` m with a cap rail. Collides as one box.
static func _boards(mb, out: Array, a: Vector3, b: Vector3, h: float, color: Color, bay := 4.0, post := TIMBER_DK, collide := true) -> void:
	var dir := b - a
	var length := dir.length()
	if length < 0.5:
		return
	var u := dir / length
	var yaw := atan2(-dir.z, dir.x)
	var mid := (a + b) * 0.5
	_rbox(mb, mid + Vector3(0, h * 0.5, 0), Vector3(length, h, 0.16), yaw, _g(color, MeshBuilder.SIDING))
	_rbox(mb, mid + Vector3(0, h + 0.05, 0), Vector3(length, 0.1, 0.3), yaw, post)
	var count := maxi(1, roundi(length / bay))
	for i in count + 1:
		var p := a + u * (length * i / count)
		mb.box(p + Vector3(0, h * 0.5 + 0.1, 0), Vector3(0.28, h + 0.2, 0.28), post)
	if collide:
		Kit._col(out, mid + Vector3(0, h * 0.5, 0), Vector3(length, h, 0.3), yaw)


## A railing from a to b, h tall: posts every `bay` m and a top and mid rail.
static func _railing(mb, out: Array, a: Vector3, b: Vector3, h: float, color: Color, bay := 2.0, collide := false, glass := false) -> void:
	var dir := b - a
	var length := dir.length()
	if length < 0.3:
		return
	var u := dir / length
	var count := maxi(1, roundi(length / bay))
	for i in count + 1:
		var p := a + u * (length * i / count)
		mb.box(p + Vector3(0, h * 0.5, 0), Vector3(0.12, h, 0.12), color)
	var yaw := atan2(-dir.z, dir.x)
	var mid := (a + b) * 0.5
	if glass:
		_rbox(mb, mid + Vector3(0, h * 0.5 - 0.05, 0), Vector3(length, h - 0.1, 0.05), yaw, _g(Color(0.55, 0.72, 0.78), MeshBuilder.GLASS))
	else:
		_rbox(mb, mid + Vector3(0, h * 0.5, 0), Vector3(length, 0.06, 0.06), yaw, color)
	_rbox(mb, mid + Vector3(0, h, 0), Vector3(length, 0.12, 0.14), yaw, color.lightened(0.1))
	if collide:
		Kit._col(out, mid + Vector3(0, h * 0.5, 0), Vector3(length, h, 0.2), yaw)


## A tall light pole with a lamp head leaning toward `toward` (a unit plan
## vector); the head glows by night.
static func _floodlight(mb, out: Array, p: Vector3, h: float, toward: Vector3) -> void:
	mb.cylinder(p, 0.14, h, _g(GALV.darkened(0.2), MeshBuilder.METAL), 4)
	out.append([p + Vector3(0, h * 0.5, 0), Vector3(0.3, h, 0.3)])
	var head := p + Vector3(0, h, 0) + toward * 0.5
	Kit._beam(mb, p + Vector3(0, h - 0.1, 0), head, 0.12, STEEL_DK)
	mb.box(head, Vector3(0.9, 0.18, 0.5), STEEL_DK)
	mb.box(head + Vector3(0, -0.1, 0), Vector3(0.8, 0.05, 0.4), _g(Color(1.0, 0.95, 0.75), MeshBuilder.GLOW_LAMP))


## A plain boxy vehicle (parked dressing): length along Z before yaw, nose to -Z.
static func _vehicle(mb, out: Array, p: Vector3, yaw: float, color: Color, length := 4.8, width := 2.0, height := 1.55, tall_cab := 0.8) -> void:
	var saved := _push(mb, p, yaw)
	var paint := _g(color, MeshBuilder.GLOSS)
	mb.box(Vector3(0, 0.62, 0), Vector3(width, 0.7, length), paint)
	mb.box(Vector3(0, 0.62 + 0.35 + tall_cab * 0.5, length * 0.08), Vector3(width * 0.9, tall_cab, length * 0.55), paint)
	mb.box(Vector3(0, 0.62 + 0.35 + tall_cab * 0.5 + 0.02, length * 0.08), Vector3(width * 0.92, tall_cab * 0.55, length * 0.5), _g(Color(0.1, 0.12, 0.15), MeshBuilder.GLASS))
	mb.box(Vector3(0, 0.2, 0), Vector3(width * 0.94, 0.4, length * 0.9), BLACK)
	mb.xform = saved
	Kit._col(out, p + Vector3(0, height * 0.5, 0), Vector3(width + 0.1, height, length), yaw)


## A rotating-free sign: a colour-field board on two posts. Facing -Z.
static func _board(mb, out: Array, p: Vector3, size: Vector2, y0: float, field: Color, rng: RandomNumberGenerator, collide := true) -> void:
	var frame := TIMBER_DK
	for s: float in [-1.0, 1.0]:
		mb.box(p + Vector3(s * (size.x * 0.5 - 0.1), (y0 + size.y) * 0.5, 0.0), Vector3(0.14, y0 + size.y, 0.14), frame)
	mb.box(p + Vector3(0, y0 + size.y * 0.5, 0), Vector3(size.x, size.y, 0.12), frame)
	_fz(mb, p.x - size.x * 0.5 + 0.12, p.x + size.x * 0.5 - 0.12, p.y + y0 + 0.12, p.y + y0 + size.y - 0.12, p.z - 0.08, field)
	_glyph_bars(mb, p.x, p.y + y0 + size.y * 0.5, p.z - 0.09, size.x * 0.7, size.y * 0.35, field.darkened(0.5), rng)
	if collide:
		out.append([p + Vector3(0, (y0 + size.y) * 0.5, 0), Vector3(size.x, y0 + size.y, 0.3)])


## Abstract glyph bars (never letters): a row of bars of mixed height.
static func _glyph_bars(mb, cx: float, cy: float, z: float, w: float, h: float, color: Color, rng: RandomNumberGenerator) -> void:
	var n := 5
	for i in n:
		var bh := h * rng.randf_range(0.45, 1.0)
		var bw := w / (n * 1.6)
		var x := cx - w * 0.5 + (i + 0.5) * w / n
		_fz(mb, x - bw * 0.5, x + bw * 0.5, cy - h * 0.5, cy - h * 0.5 + bh, z, color)


## A pitched tent (canvas) on the ground: ridge along X before yaw, door at -Z end.
static func _tent(mb, out: Array, p: Vector3, yaw: float, w: float, l: float, h: float, color: Color, door := true) -> void:
	var saved := _push(mb, p, yaw)
	mb.gable(Vector3(0, h * 0.5, 0), Vector3(w, h, l), color, color.darkened(0.15))
	if door:
		var hw := w * 0.5
		mb.tri(Vector3(-hw * 0.0 - 0.5, 0.0, -l * 0.5 - 0.01), Vector3(0.5, 0.0, -l * 0.5 - 0.01), Vector3(0, h * 0.0 + 1.0, -l * 0.5 - 0.01), Vector3(0, 0, -1), color.darkened(0.6))
	mb.xform = saved
	Kit._col(out, p + Vector3(0, h * 0.5, 0), Vector3(w, h, l), yaw)


# --- Research lab ---------------------------------------------------------------

static func research_lab(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var hx := w * 0.5
	var hz := d * 0.5
	var fx := hx - 1.5
	var fz := hz - 1.5
	var apron := _g(APRON, MeshBuilder.CONCRETE)
	var asph := _g(ASPHALT, MeshBuilder.ASPHALT)
	Kit._pad(mb, -fx + 0.3, fx - 0.3, -fz + 0.3, fz - 0.3, apron, 0.02)
	# The lab road in from the gate, a forecourt before the main block, parking.
	Kit._pad(mb, -3.5, 3.5, -hz, -14.0, asph, 0.05)
	Kit._pad(mb, -26.0, 12.0, -14.0, -8.5, asph, 0.05)
	Kit._pad(mb, 3.5, 36.0, -31.0, -16.0, asph, 0.05)
	for i in 9:
		var x := 8.0 + i * 3.0
		Kit._line(mb, Vector3(x, 0, -30.0), Vector3(x, 0, -24.5), 0.14, Color(0.85, 0.85, 0.8))
		Kit._line(mb, Vector3(x, 0, -22.5), Vector3(x, 0, -17.0), 0.14, Color(0.85, 0.85, 0.8))
	# Perimeter: tall wire fence with barbed outriggers, a gate gap in front.
	var fh := 3.2
	_chain(mb, out, Vector3(-fx, 0, -fz), Vector3(-4.6, 0, -fz), fh, Vector3(0, 0, -1))
	_chain(mb, out, Vector3(4.6, 0, -fz), Vector3(fx, 0, -fz), fh, Vector3(0, 0, -1))
	_chain(mb, out, Vector3(-fx, 0, fz), Vector3(fx, 0, fz), fh, Vector3(0, 0, 1))
	_chain(mb, out, Vector3(-fx, 0, -fz), Vector3(-fx, 0, fz), fh, Vector3(-1, 0, 0))
	_chain(mb, out, Vector3(fx, 0, -fz), Vector3(fx, 0, fz), fh, Vector3(1, 0, 0))
	# Gate piers, the sliding leaf pulled open along the right fence, an intercom post.
	var pier := _g(CONCRETE_DK, MeshBuilder.CONCRETE)
	for s: float in [-1.0, 1.0]:
		_sx(mb, out, s * 4.6 - 0.45, s * 4.6 + 0.45, 0.0, 3.6, -fz - 0.45, -fz + 0.45, pier)
		_bx(mb, s * 4.6 - 0.55, s * 4.6 + 0.55, 3.6, 3.8, -fz - 0.55, -fz + 0.55, CONCRETE_LT)
	_sx(mb, out, 5.4, 13.0, 0.2, 2.6, -fz + 0.55, -fz + 0.7, _g(GALV, MeshBuilder.METAL))
	_bx(mb, 5.4, 13.0, 0.9, 1.0, -fz + 0.5, -fz + 0.75, STEEL_DK)
	_bx(mb, 5.4, 13.0, 2.4, 2.5, -fz + 0.5, -fz + 0.75, STEEL_DK)
	_bx(mb, -6.0, -5.5, 0.0, 1.3, -fz - 0.9, -fz - 0.4, STEEL)
	_bx(mb, -6.1, -5.4, 1.3, 1.5, -fz - 0.95, -fz - 0.35, _g(Color(0.2, 0.8, 0.4), MeshBuilder.GLOW_LAMP))
	# Main block: two storeys, no windows; louvres, a steel door and a canopy.
	var bx0 := -30.0
	var bx1 := 14.0
	var bz0 := -8.0
	var bz1 := 16.0
	var bh := 7.6
	var conc := _g(CONCRETE, MeshBuilder.CONCRETE)
	_sx(mb, out, bx0, bx1, 0.0, bh, bz0, bz1, conc)
	_bx(mb, bx0 - 0.12, bx1 + 0.12, 3.7, 3.95, bz0 - 0.12, bz1 + 0.12, _g(CONCRETE_DK, MeshBuilder.CONCRETE))
	_bx(mb, bx0 - 0.15, bx1 + 0.15, bh - 0.4, bh, bz0 - 0.15, bz1 + 0.15, _g(CONCRETE_DK, MeshBuilder.CONCRETE))
	for i in 7:
		var x := bx0 + 6.0 + i * 5.2
		_fz(mb, x - 0.08, x + 0.08, 0.0, bh - 0.4, bz0 - 0.02, CONCRETE_DK)
	for x: float in [-23.0, -1.0, 8.0]:
		_fz(mb, x - 1.8, x + 1.8, 1.4, 3.2, bz0 - 0.03, IRON)
		for k in 5:
			_fz(mb, x - 1.8, x + 1.8, 1.5 + k * 0.36, 1.6 + k * 0.36, bz0 - 0.04, STEEL_DK)
	_fz(mb, -10.0, -6.0, 0.0, 2.9, bz0 - 0.03, _g(Color(0.24, 0.28, 0.32), MeshBuilder.GLOSS))
	_fz(mb, -8.07, -7.93, 0.0, 2.9, bz0 - 0.05, IRON)
	_bx(mb, -12.0, -4.0, 3.1, 3.4, bz0 - 3.2, bz0, _g(CONCRETE_DK, MeshBuilder.CONCRETE))
	for s: float in [-1.0, 1.0]:
		Kit._post(mb, out, Vector3(-8.0 + s * 3.7, 0, bz0 - 3.0), 3.1, 0.35, STEEL)
	mb.box(Vector3(-8.0, 3.0, bz0 - 3.0), Vector3(0.6, 0.12, 0.3), _g(Color(1.0, 0.95, 0.75), MeshBuilder.GLOW_LAMP))
	# Roof: parapet, cooling units, vents, a stair bulkhead.
	var rf := _g(Color(0.4, 0.4, 0.42), MeshBuilder.ROOF)
	_bx(mb, bx0 + 0.1, bx1 - 0.1, bh, bh + 0.04, bz0 + 0.1, bz1 - 0.1, rf)
	for u in [Vector2(bx0 + 3, bz0 + 3), Vector2(bx0 + 3, bz1 - 3), Vector2(-14, 0), Vector2(-4, 8), Vector2(6, -2), Vector2(6, 11)]:
		_ac_unit(mb, Vector3(u.x, bh + 0.04, u.y), rng)
	for u in [Vector2(-22, 3), Vector2(-12, 11), Vector2(-26, 11), Vector2(2, 4), Vector2(10, 13)]:
		var vp := Vector3(u.x, bh + 0.04, u.y)
		mb.cylinder(vp, 0.4, 1.3, _g(STEEL, MeshBuilder.METAL), 6)
		Kit._cone(mb, vp + Vector3(0, 1.3, 0), 0.65, 0.4, STEEL_DK, 6)
	_bx(mb, -8.0, -3.0, bh, bh + 2.4, 11.0, 15.0, conc)
	_bx(mb, -7.0, -4.0, bh + 2.4, bh + 2.55, 10.8, 15.2, CONCRETE_DK)
	# Annex: a lower block with a roller door.
	_sx(mb, out, 18.0, 34.0, 0.0, 4.4, -6.0, 8.0, _g(CONCRETE.lightened(0.04), MeshBuilder.CONCRETE))
	_bx(mb, 17.9, 34.1, 4.0, 4.4, -6.1, 8.1, CONCRETE_DK)
	_bx(mb, 17.9, 34.1, 4.4, 4.9, -6.1, 8.1, _g(CONCRETE, MeshBuilder.CONCRETE))
	_bx(mb, 18.4, 33.6, 4.9, 5.0, -5.6, 7.6, rf)
	_fz(mb, 22.0, 28.0, 0.0, 3.4, -6.03, _g(Color(0.34, 0.4, 0.38), MeshBuilder.GLOSS))
	for k in 7:
		_fz(mb, 22.0, 28.0, 0.3 + k * 0.45, 0.36 + k * 0.45, -6.05, STEEL_DK)
	_bx(mb, 20.0, 30.0, 0.0, 0.5, -8.4, -6.0, _g(CONCRETE_LT, MeshBuilder.CONCRETE))
	_ac_unit(mb, Vector3(22.0, 5.0, 2.0), rng)
	_ac_unit(mb, Vector3(29.0, 5.0, 4.0), rng)
	_sx(mb, out, 14.0, 18.0, 0.0, 3.0, 1.0, 4.0, conc)
	# A squat radome.
	var rc := Vector3(-35.0, 0.0, -22.0)
	mb.cylinder(rc, 5.2, 1.4, _g(CONCRETE_DK, MeshBuilder.CONCRETE), 12)
	_dome(mb, rc + Vector3(0, 1.4, 0), Vector3(5.0, 4.0, 5.0), _g(DOME, MeshBuilder.GLOSS), 12, 3)
	out.append([rc + Vector3(0, 2.7, 0), Vector3(9.6, 5.4, 9.6)])
	# Lattice mast and a satellite dish.
	_mast(mb, out, Vector3(-38.0, 0.0, 27.0), 30.0)
	_dish(mb, out, Vector3(-24.0, 0.0, 26.0), 3.4, rng)
	# A concrete bunker entrance in the back wall.
	_bunker(mb, out, 0.0, 33.0)
	# Guard tower in the front right corner.
	_guard_tower(mb, out, Vector3(fx - 3.5, 0.0, -fz + 3.5))
	# Helipad on paving.
	var hc := Vector3(28.0, 0.0, 20.0)
	Kit._pad(mb, hc.x - 9.0, hc.x + 9.0, hc.z - 9.0, hc.z + 9.0, _g(CONCRETE_LT, MeshBuilder.CONCRETE), 0.04)
	_ring(mb, hc + Vector3(0, 0.07, 0), 6.3, 6.8, Color(0.95, 0.8, 0.2), 20)
	_disc(mb, hc + Vector3(0, 0.065, 0), 6.3, Color(0.3, 0.32, 0.34), 20)
	_bx(mb, hc.x - 2.2, hc.x - 1.6, 0.075, 0.085, hc.z - 2.6, hc.z + 2.6, WHITE)
	_bx(mb, hc.x + 1.6, hc.x + 2.2, 0.075, 0.085, hc.z - 2.6, hc.z + 2.6, WHITE)
	_bx(mb, hc.x - 1.6, hc.x + 1.6, 0.075, 0.085, hc.z - 0.3, hc.z + 0.3, WHITE)
	for k in 4:
		var a := PI * 0.25 + k * PI * 0.5
		mb.box(hc + Vector3(cos(a), 0, sin(a)) * 7.8 + Vector3(0, 0.1, 0), Vector3(0.3, 0.2, 0.3), _g(Color(1.0, 0.6, 0.2), MeshBuilder.GLOW_LAMP))
	# Dark vehicles in the parking.
	var spots: Array[Vector3] = [Vector3(10.5, 0, -27.0), Vector3(16.5, 0, -27.0), Vector3(22.5, 0, -27.0), Vector3(13.5, 0, -19.8), Vector3(25.5, 0, -19.8)]
	for sp in spots:
		_vehicle(mb, out, sp, 0.0 if rng.randf() < 0.5 else PI, _pick(DARK_CARS, rng))
	_vehicle(mb, out, Vector3(31.0, 0, -22.0), PI * 0.5, _pick(DARK_CARS, rng), 5.6, 2.2, 2.3, 1.2)
	# Floodlights along the fence and by the gate.
	for p in [Vector2(-fx + 2.5, -24.0), Vector2(fx - 2.5, -10.0), Vector2(-fx + 2.5, 4.0), Vector2(fx - 2.5, 4.0), Vector2(-fx + 2.5, 28.0), Vector2(fx - 2.5, 28.0), Vector2(-9.0, -fz + 2.0), Vector2(9.0, -fz + 2.0)]:
		var toward := Vector3(-signf(p.x) if absf(p.x) > fx - 3.0 else 0.0, 0, 0.0 if absf(p.x) > fx - 3.0 else 1.0)
		_floodlight(mb, out, Vector3(p.x, 0, p.y), 7.0, toward)


## A rooftop cooling unit: a box with a fan grille.
static func _ac_unit(mb, base: Vector3, rng: RandomNumberGenerator) -> void:
	var s := Vector3(rng.randf_range(2.0, 3.0), rng.randf_range(1.1, 1.6), rng.randf_range(1.6, 2.2))
	mb.box(base + Vector3(0, s.y * 0.5, 0), s, _g(Color(0.7, 0.72, 0.74), MeshBuilder.METAL))
	_bx(mb, base.x - s.x * 0.3, base.x + s.x * 0.3, base.y + s.y, base.y + s.y + 0.04, base.z - s.z * 0.3, base.z + s.z * 0.3, IRON)
	mb.box(base + Vector3(0, 0.15, 0), Vector3(s.x + 0.3, 0.3, s.z + 0.3), CONCRETE_DK)


## A lattice radio mast of four legs, braced all round, with a beacon.
static func _mast(mb, out: Array, base: Vector3, h: float) -> void:
	var wb := 2.6
	var wt := 0.9
	var levels := 7
	var galv := _g(GALV.darkened(0.1), MeshBuilder.METAL)
	var corners: Array = [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for c: Vector2 in corners:
		Kit._beam(mb, base + Vector3(c.x * wb * 0.5, 0.15, c.y * wb * 0.5), base + Vector3(c.x * wt * 0.5, h, c.y * wt * 0.5), 0.2, galv)
	for k in levels:
		var t0 := float(k) / levels
		var t1 := float(k + 1) / levels
		var r0 := lerpf(wb, wt, t0) * 0.5
		var r1 := lerpf(wb, wt, t1) * 0.5
		for i in 4:
			var c0: Vector2 = corners[i]
			var c1: Vector2 = corners[(i + 1) % 4]
			var n := Vector3((c0.x + c1.x) * 0.5, 0, (c0.y + c1.y) * 0.5).normalized()
			var a := base + Vector3(c0.x * r0, h * t0 + (0.08 if k == 0 else 0.0), c0.y * r0)
			var b := base + Vector3(c1.x * r1, h * t1, c1.y * r1)
			if k % 2 == 1:
				a = base + Vector3(c1.x * r0, h * t0, c1.y * r0)
				b = base + Vector3(c0.x * r1, h * t1, c0.y * r1)
			_strap(mb, a, b, 0.1, n, galv)
	for k in [0.0, 0.5, 1.0]:
		var r: float = lerpf(wb, wt, k) * 0.5 + 0.1
		_bx(mb, base.x - r, base.x + r, maxf(h * k - 0.05, 0.0), maxf(h * k - 0.05, 0.0) + 0.15, base.z - r, base.z + r, galv.darkened(0.15))
	for s: float in [-1.0, 1.0]:
		Kit._beam(mb, base + Vector3(s * 0.5, h * 0.8, 0), base + Vector3(s * 2.2, h * 0.8, 0), 0.12, STEEL_DK)
		mb.box(base + Vector3(s * 2.2, h * 0.8 + 0.3, 0), Vector3(0.7, 0.6, 0.12), _g(DOME, MeshBuilder.GLOSS))
	mb.cylinder(base + Vector3(0, h, 0), 0.05, 2.5, STEEL_DK, 4)
	mb.box(base + Vector3(0, h + 0.15, 0), Vector3(0.5, 0.3, 0.5), _g(Color(1.0, 0.2, 0.15), MeshBuilder.GLOW_LAMP))
	out.append([base + Vector3(0, 3.0, 0), Vector3(2.2, 6.0, 2.2)])


## A parabolic dish on a pedestal, tilted up toward the front.
static func _dish(mb, out: Array, base: Vector3, r: float, rng: RandomNumberGenerator) -> void:
	var hub := base + Vector3(0, 3.6, 0)
	mb.cylinder(base, 0.55, 2.6, _g(CONCRETE_LT, MeshBuilder.CONCRETE), 5)
	Kit._beam(mb, base + Vector3(0, 2.5, 0), hub, 0.35, STEEL)
	var tilt := deg_to_rad(52.0)
	var a := Vector3(0.0, sin(tilt), -cos(tilt))
	var u := a.cross(Vector3.UP).normalized()
	var v := a.cross(u).normalized()
	var apex := hub - a * (r * 0.3)
	var rim: Array[Vector3] = []
	var segs := 10
	for i in segs:
		var t := TAU * i / segs
		rim.append(hub + (u * cos(t) + v * sin(t)) * r)
	for i in segs:
		var j := (i + 1) % segs
		mb.tri(apex, rim[i], rim[j], _face_n(apex, rim[i], rim[j], a), _g(DOME, MeshBuilder.GLOSS))
		mb.tri(apex - a * 0.1, rim[j], rim[i], -a, DOME.darkened(0.3))
	var feed := hub + a * (r * 0.55)
	Kit._beam(mb, rim[0] if v.y < 0 else rim[segs / 2 + 0], feed, 0.1, STEEL_DK)
	mb.box(feed, Vector3(0.3, 0.3, 0.3), IRON)
	out.append([base + Vector3(0, 1.4, 0), Vector3(1.2, 2.8, 1.2)])


## A concrete bunker entrance at the back wall z: wing walls, blast doors, a berm over it.
static func _bunker(mb, out: Array, cx: float, z: float) -> void:
	var conc := _g(CONCRETE_DK, MeshBuilder.CONCRETE)
	# The earth berm behind and over it.
	var gr := Color(0.4, 0.45, 0.33)
	var b0 := Vector3(cx - 15.0, 0, z - 6.0)
	var b1 := Vector3(cx + 15.0, 0, z - 6.0)
	var b2 := Vector3(cx + 15.0, 0, z + 0.4)
	var b3 := Vector3(cx - 15.0, 0, z + 0.4)
	var t0 := Vector3(cx - 8.0, 6.0, z - 2.0)
	var t1 := Vector3(cx + 8.0, 6.0, z - 2.0)
	var t2 := Vector3(cx + 8.0, 6.0, z + 0.4)
	var t3 := Vector3(cx - 8.0, 6.0, z + 0.4)
	mb.quad(b0, b1, t1, t0, Vector3(0, 0.6, -0.8).normalized(), gr)
	mb.quad(b1, b2, t2, t1, Vector3(0.8, 0.6, 0).normalized(), gr.darkened(0.08))
	mb.quad(b3, b0, t0, t3, Vector3(-0.8, 0.6, 0).normalized(), gr.darkened(0.08))
	mb.quad(t0, t1, t2, t3, Vector3.UP, gr.lightened(0.05))
	out.append([Vector3(cx, 2.2, z - 2.8), Vector3(26.0, 4.4, 6.4)])
	# The concrete face with the recess and the two blast door leaves.
	_bx(mb, cx - 9.0, cx + 9.0, 0.0, 4.6, z - 6.0, z - 4.2, conc)
	_bx(mb, cx - 9.2, cx + 9.2, 4.6, 5.0, z - 6.2, z - 4.0, _g(CONCRETE_LT, MeshBuilder.CONCRETE))
	for s: float in [-1.0, 1.0]:
		_rsx(mb, out, Vector3(cx + s * 11.0, 1.3, z - 8.0), Vector3(5.5, 2.6, 0.7), s * 0.7, conc)
	_fz(mb, cx - 3.6, cx + 3.6, 0.0, 3.5, z - 6.03, IRON)
	for s: float in [-1.0, 1.0]:
		_fz(mb, cx + s * 0.05 - (3.4 if s < 0 else 0.0), cx + s * 0.05 + (3.4 if s > 0 else 0.0), 0.1, 3.4, z - 6.1, _g(Color(0.3, 0.33, 0.36), MeshBuilder.METAL))
		for k in 5:
			var x0 := cx + s * 0.4 + (k * 0.65) * s
			_fz(mb, minf(x0, x0 + s * 0.3), maxf(x0, x0 + s * 0.3), 3.4 - 0.5, 3.4, z - 6.14, YELLOW if k % 2 == 0 else IRON)
	_bx(mb, cx - 4.0, cx + 4.0, 3.5, 3.9, z - 6.3, z - 4.2, _g(CONCRETE_LT, MeshBuilder.CONCRETE))
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(cx + s * 2.0, 4.2, z - 6.4), Vector3(0.7, 0.25, 0.3), _g(Color(1.0, 0.95, 0.75), MeshBuilder.GLOW_LAMP))
	mb.box(Vector3(cx, 4.2, z - 6.3), Vector3(0.4, 0.4, 0.4), STEEL_DK)


## A watch tower on four posts: a deck, a glazed cab and a searchlight.
static func _guard_tower(mb, out: Array, p: Vector3) -> void:
	var wood := TIMBER_DK
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			Kit._post(mb, out, p + Vector3(sx * 1.5, 0, sz * 1.5), 7.0, 0.3, _g(STEEL, MeshBuilder.METAL))
	for k in 2:
		var y := 2.0 + k * 2.6
		for sx: float in [-1.0, 1.0]:
			_strap(mb, p + Vector3(sx * 1.5, y, -1.5), p + Vector3(sx * 1.5, y + 2.6, 1.5), 0.12, Vector3(sx, 0, 0), STEEL_DK)
		for sz: float in [-1.0, 1.0]:
			_strap(mb, p + Vector3(-1.5, y, sz * 1.5), p + Vector3(1.5, y + 2.6, sz * 1.5), 0.12, Vector3(0, 0, sz), STEEL_DK)
	_bx(mb, p.x - 2.2, p.x + 2.2, 7.0, 7.25, p.z - 2.2, p.z + 2.2, wood)
	for s: float in [-1.0, 1.0]:
		_bx(mb, p.x - 2.2, p.x + 2.2, 7.25, 8.1, p.z + s * 2.15 - 0.04, p.z + s * 2.15 + 0.04, _g(wood, MeshBuilder.SIDING))
		_bx(mb, p.x + s * 2.15 - 0.04, p.x + s * 2.15 + 0.04, 7.25, 8.1, p.z - 2.2, p.z + 2.2, _g(wood, MeshBuilder.SIDING))
	_bx(mb, p.x - 1.7, p.x + 1.7, 8.1, 10.2, p.z - 1.7, p.z + 1.7, _g(Color(0.35, 0.4, 0.38), MeshBuilder.GLOSS))
	_bx(mb, p.x - 1.75, p.x + 1.75, 8.6, 9.7, p.z - 1.75, p.z + 1.75, _g(Color(0.1, 0.12, 0.15), MeshBuilder.GLASS))
	Kit._hip(mb, Vector3(p.x, 10.2, p.z), 4.4, 4.4, 0.9, STEEL_DK)
	mb.box(Vector3(p.x - 1.9, 10.5, p.z - 1.0), Vector3(0.7, 0.5, 0.7), STEEL_DK)
	mb.box(Vector3(p.x - 1.9, 10.5, p.z - 1.38), Vector3(0.5, 0.4, 0.05), _g(Color(1.0, 0.97, 0.8), MeshBuilder.GLOW_LAMP))
	for k in 6:
		Kit._beam(mb, p + Vector3(-1.6, 0.3 + k * 1.1, 1.9), p + Vector3(-0.8, 0.3 + k * 1.1, 1.9), 0.1, wood)
	Kit._beam(mb, p + Vector3(-1.6, 0, 1.9), p + Vector3(-1.6, 7.0, 1.9), 0.1, wood)


## The checkpoint where the lab road leaves Route 9. Laid out in metres (the
## road is 7 m wide whatever the lot): the lane x in [-3.5, 3.5] is clear
## of colliders, the striped arm across it is a visual only.
static func lab_gate(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var hx := w * 0.5
	var hz := d * 0.5
	var kz := d / 16.0
	# Asphalt lane through the lot.
	Kit._pad(mb, -3.5, 3.5, -hz, hz, _g(ASPHALT, MeshBuilder.ASPHALT), 0.02)
	# Fence stubs out from the lane edges to the lot sides.
	var fz := 1.4 * kz
	_chain(mb, out, Vector3(-hx + 0.2, 0, fz), Vector3(-4.2, 0, fz), 2.8, Vector3(0, 0, -1), 4.0)
	_chain(mb, out, Vector3(4.2, 0, fz), Vector3(hx - 0.2, 0, fz), 2.8, Vector3(0, 0, -1), 4.0)
	# Guard booth with windows on its lane side and front.
	var bx := 6.4
	var bz := 0.6 * kz
	_gate_booth(mb, out, bx, bz)
	# Striped barrier arm, raised (no gate logic yet, and the lane has no
	# collider, so a lowered arm would read as cars driving through it).
	mb.box(Vector3(3.9, 0.6, bz - 0.8 * kz), Vector3(0.5, 1.2, 0.5), _g(Color(0.85, 0.2, 0.15), MeshBuilder.GLOSS))
	out.append([Vector3(3.9, 0.6, bz - 0.8 * kz), Vector3(0.5, 1.2, 0.5)])
	var segs := 8
	for i in segs:
		var y0 := 1.2 + 6.4 * i / segs
		_bx(mb, 3.84, 3.96, y0, y0 + 6.4 / segs, bz - 0.8 * kz - 0.07, bz - 0.8 * kz + 0.07, RED if i % 2 == 0 else WHITE)
	# Tyre-spike strip before the barrier.
	var sz := -2.6 * kz
	_bx(mb, -3.3, 3.3, 0.02, 0.07, sz - 0.4, sz + 0.4, IRON)
	for i in 14:
		var x := -3.0 + i * 0.46
		for k in 2:
			Kit._cone(mb, Vector3(x, 0.07, sz - 0.2 + k * 0.4), 0.07, 0.2, STEEL, 3)
	# Warning boards (colour fields), a bollard row down each lane edge, a lamp.
	for s: float in [-1.0, 1.0]:
		var bd := Vector3(s * 5.4, 0, -5.4 * kz)
		_board(mb, out, bd, Vector2(1.8, 1.3), 1.0, YELLOW if s < 0 else RED, rng)
		for k in 3:
			var p := Vector3(s * 4.0, 0, (-6.4 + k * 1.7) * kz)
			mb.cylinder(p, 0.16, 0.9, YELLOW, 5)
			mb.box(p + Vector3(0, 0.55, 0), Vector3(0.34, 0.1, 0.34), IRON)
			out.append([p + Vector3(0, 0.45, 0), Vector3(0.32, 0.9, 0.32)])
	_floodlight(mb, out, Vector3(-6.0, 0, 3.4 * kz), 5.5, Vector3(1, 0, 0))


## The guard booth of lab_gate: a small glazed box with a flat roof.
static func _gate_booth(mb, out: Array, x: float, z: float) -> void:
	var body := _g(Color(0.8, 0.8, 0.76), MeshBuilder.CONCRETE)
	_sx(mb, out, x - 1.5, x + 1.5, 0.0, 2.7, z - 1.4, z + 1.4, body)
	_bx(mb, x - 1.85, x + 1.85, 2.7, 2.95, z - 1.75, z + 1.75, STEEL_DK)
	var gl := _g(Color(0.12, 0.17, 0.22), MeshBuilder.GLASS)
	_fx(mb, z - 1.0, z + 1.0, 1.1, 2.4, x - 1.52, gl, -1.0)
	_fz(mb, x - 1.0, x + 1.0, 1.1, 2.4, z - 1.42, gl)
	_fz(mb, x - 1.0, x + 1.0, 1.1, 2.4, z + 1.42, gl, 1.0)
	_bx(mb, x - 1.55, x - 1.45, 1.0, 1.1, z - 1.05, z + 1.05, CONCRETE_DK)
	_bx(mb, x - 1.0, x + 1.0, 2.95, 3.35, z - 0.9, z + 0.9, STEEL)
	mb.box(Vector3(x, 3.5, z), Vector3(0.5, 0.25, 0.5), _g(Color(1.0, 0.3, 0.2), MeshBuilder.GLOW_LAMP))


# STUBS (replaced below as kinds are written)


# --- Shared small builders -------------------------------------------------------

## A small cabin centred on p (ground), turned by yaw: walls, a gable roof
## with its ridge along the front, a door and windows on the -Z face.
static func _cabin(mb, out: Array, p: Vector3, yaw: float, w: float, d: float, wall_h: float, rise: float, wall: Color, roof: Color, rng: RandomNumberGenerator, windows := 2, tin := true, logs := false) -> void:
	var saved := _push(mb, p, yaw)
	mb.box(Vector3(0, wall_h * 0.5, 0), Vector3(w, wall_h, d), _g(wall, MeshBuilder.SIDING))
	var rc := _g(roof, MeshBuilder.SEAM_ROOF) if tin else roof
	Kit._gable(mb, 0.0, 0.0, wall_h, w + 0.8, d + 0.8, rise, rc, wall.darkened(0.15))
	mb.box(Vector3(0, wall_h + rise + 0.03, 0), Vector3(w + 0.9, 0.08, 0.2), roof.darkened(0.25))
	var fz := -d * 0.5 - 0.03
	var dx := -w * 0.5 + 1.0 if windows > 1 else 0.0
	_fz(mb, dx - 0.5, dx + 0.5, 0.0, 2.05, fz, TIMBER_DK)
	_fz(mb, dx - 0.4, dx + 0.4, 0.1, 1.95, fz - 0.02, TIMBER)
	for i in windows:
		var x := lerpf(dx + 1.8, w * 0.5 - 0.9, 0.0 if windows < 3 else float(i) / (windows - 1)) if windows > 0 else 0.0
		if windows == 1:
			x = w * 0.25
		_fz(mb, x - 0.45, x + 0.45, 1.0, 1.8, fz, _g(GLASS_C, MeshBuilder.GLASS))
		_fz(mb, x - 0.55, x + 0.55, 0.92, 1.0, fz - 0.01, wall.darkened(0.35))
	if logs:
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				for k in 3:
					mb.box(Vector3(sx * (w * 0.5), 0.5 + k * 0.8, sz * (d * 0.5)), Vector3(0.42, 0.3, 0.42), LOG_END.darkened(0.15))
	mb.xform = saved
	Kit._col(out, p + Vector3(0, wall_h * 0.5, 0), Vector3(w, wall_h, d), yaw)


## A vertical disc (a saw blade, a wheel) in the plane z, facing both ways.
static func _vdisc(mb, c: Vector3, r: float, color: Color, segs := 12) -> void:
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var p0 := c + Vector3(cos(a0) * r, sin(a0) * r, 0)
		var p1 := c + Vector3(cos(a1) * r, sin(a1) * r, 0)
		mb.tri(c, p0, p1, Vector3(0, 0, -1), color)
		mb.tri(c, p0, p1, Vector3(0, 0, 1), color)


## A sloped panel from low (a, y0) to high (b, y1) edges: lean-to roofs,
## sheets, ramps, awnings. a and b are plan points, `width` along the edge.
static func _slope(mb, a: Vector3, b: Vector3, width: float, along: Vector3, color: Color, thick := 0.0) -> void:
	var half := along.normalized() * width * 0.5
	var n := (b - a).cross(half).normalized()
	if n.y < 0.0:
		n = -n
	mb.quad(a - half, a + half, b + half, b - half, n, color)
	if thick > 0.0:
		mb.quad(a - half - Vector3(0, thick, 0), a + half - Vector3(0, thick, 0), b + half - Vector3(0, thick, 0), b - half - Vector3(0, thick, 0), -n, color.darkened(0.3))


## A rough cliff block x0..x1 by z0..z1 and h tall: a flat front at z0, the
## top corners jittered, the sides leaning in a little.
static func _cliff(mb, x0: float, x1: float, z0: float, z1: float, h: float, rng: RandomNumberGenerator, color: Color) -> void:
	var j := func(): return rng.randf_range(-0.12, 0.12) * h
	var yl: float = h + j.call()
	var yr: float = h + j.call()
	var inset := minf(1.2, (x1 - x0) * 0.12)
	var zi := minf(2.0, (z1 - z0) * 0.3)
	var f0 := Vector3(x0, 0, z0)
	var f1 := Vector3(x1, 0, z0)
	var t0 := Vector3(x0 + inset, yl, z0)
	var t1 := Vector3(x1 - inset, yr, z0)
	var u0 := Vector3(x0 + inset, yl * 0.97, z1 - zi)
	var u1 := Vector3(x1 - inset, yr * 0.97, z1 - zi)
	var b0 := Vector3(x0, 0, z1)
	var b1 := Vector3(x1, 0, z1)
	mb.quad(f0, f1, t1, t0, Vector3(0, 0.3, -1).normalized(), color)
	mb.quad(f0, t0, u0, b0, Vector3(-1, 0.3, 0).normalized(), color.darkened(0.12))
	mb.quad(f1, t1, u1, b1, Vector3(1, 0.3, 0).normalized(), color.darkened(0.06))
	mb.quad(t0, t1, u1, u0, Vector3.UP, color.lightened(0.1))


# --- Sawmill ------------------------------------------------------------------------

static func sawmill(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var hx := w * 0.5
	var hz := d * 0.5
	Kit._pad(mb, -hx + 1.0, hx - 1.0, -hz + 1.0, hz - 1.0, Color(0.55, 0.45, 0.33), 0.02)
	Kit._pad(mb, -3.0, 3.0, -hz + 0.2, -6.0, _g(GRAVEL, MeshBuilder.CONCRETE), 0.035)
	for k in 5:
		var z := -17.0 + k * 3.0
		Kit._pad(mb, -26.0 + rng.randf_range(-1, 1), 8.0 + rng.randf_range(-1, 1), z, z + 0.7, Color(0.44, 0.36, 0.26), 0.036)
	# The mill shed: posts and a tin roof over the saw line.
	var sx0 := -16.0
	var sx1 := 10.0
	var sz0 := -4.0
	var sz1 := 12.0
	var eave := 5.2
	Kit._pad(mb, sx0, sx1, sz0, sz1, _g(CONCRETE_DK, MeshBuilder.CONCRETE), 0.04)
	for i in 7:
		var x := lerpf(sx0, sx1, i / 6.0)
		for z: float in [sz0, sz1]:
			_pole_sq(mb, out, Vector3(x, 0, z), eave, 0.4, TIMBER_DK)
	for z: float in [sz0 + (sz1 - sz0) / 3.0, sz0 + (sz1 - sz0) * 2.0 / 3.0]:
		for x: float in [sx0, sx1]:
			_pole_sq(mb, out, Vector3(x, 0, z), eave, 0.4, TIMBER_DK)
	for z: float in [sz0, sz1]:
		_bx(mb, sx0 - 0.2, sx1 + 0.2, eave - 0.5, eave - 0.2, z - 0.15, z + 0.15, TIMBER)
	var tin: Color = _pick(Kit.TIN_ROOFS, rng)
	Kit._gable(mb, (sx0 + sx1) * 0.5, (sz0 + sz1) * 0.5, eave, sx1 - sx0 + 1.6, sz1 - sz0 + 1.6, 2.6, _g(tin, MeshBuilder.SEAM_ROOF), tin.darkened(0.3))
	for k in 3:
		var px := sx0 + 3.0 + k * 8.0
		_slope(mb, Vector3(px, eave + 0.01, sz0 - 0.2), Vector3(px, eave + 2.62, (sz0 + sz1) * 0.5), 2.2, Vector3.RIGHT, tin.darkened(0.2 + 0.1 * k))
	# Saw line: a long bed, a carriage and blade, roller tables out of the end.
	var zl := 5.0
	_sx(mb, out, sx0 + 2.0, sx1 + 7.0, 0.0, 0.9, zl - 0.8, zl + 0.8, _g(STEEL_DK, MeshBuilder.METAL))
	_bx(mb, sx0 + 2.0, sx1 + 7.0, 0.9, 0.95, zl - 0.45, zl + 0.45, IRON)
	for x: float in [-9.0, -2.0, 5.0]:
		_bx(mb, x - 0.3, x + 0.3, 0.9, 1.4, zl - 1.0, zl + 1.0, ORANGE.darkened(0.2))
	_bx(mb, -5.2, -2.0, 0.95, 2.4, zl - 1.3, zl + 1.3, _g(ORANGE.darkened(0.15), MeshBuilder.GLOSS))
	out.append([Vector3(-3.6, 1.2, zl), Vector3(3.2, 2.4, 2.6)])
	_vdisc(mb, Vector3(-3.6, 1.7, zl - 1.36), 0.95, _g(STEEL, MeshBuilder.METAL), 14)
	for k in 5:
		_bx(mb, sx1 + 0.5 + k * 1.4, sx1 + 0.8 + k * 1.4, 0.95, 1.25, zl - 0.7, zl + 0.7, STEEL_DK)
	var plank := _g(PINE, MeshBuilder.SIDING)
	for k in 3:
		_bx(mb, 4.0 + k * 3.0, 6.6 + k * 3.0, 0.95, 1.1, zl - 0.3 + 0.1 * k, zl + 0.3 + 0.1 * k, plank)
	# The log ramp at the west end and a sawdust chute to the pile.
	_slope(mb, Vector3(-22.0, 0.3, 5.0), Vector3(sx0 + 2.0, 0.95, 5.0), 1.8, Vector3.BACK, _g(TIMBER, MeshBuilder.SIDING), 0.25)
	_rsx(mb, out, Vector3(15.0, 0.45, 6.6), Vector3(7.0, 0.9, 1.0), 0.0, _g(STEEL_DK, MeshBuilder.METAL))
	# Log deck, front left: two stacks and a few loose logs.
	_log_stack(mb, out, Vector3(-24.0, 0, -12.0), 0.08, 11.0, 5, 0.5, rng, 4)
	_log_stack(mb, out, Vector3(-18.5, 0, -13.0), -0.05, 10.0, 4, 0.5, rng, 3)
	for k in 3:
		var a := Vector3(-13.0 + k * 0.6, 0.48, -10.0 + k * 1.1)
		_log(mb, a + Vector3(0, 0, 4.0), a - Vector3(0, 0, 3.0 + k), 0.46, _vary(LOG, rng, 0.1), LOG_END, 5)
	# Lumber stacks, front right: boards on stickers under a tarp.
	for k in 3:
		var cz := -16.0 + k * 3.6
		var cx := 17.0 + (k % 2) * 1.2
		_sx(mb, out, cx - 5.0, cx + 5.0, 0.35, 2.0, cz - 0.9, cz + 0.9, plank.darkened(0.04 * k))
		_bx(mb, cx - 4.8, cx + 4.8, 0.0, 0.35, cz - 0.6, cz + 0.6, TIMBER_DK)
		for i in 5:
			_fy(mb, cx - 4.9 + i * 2.1, cx - 4.8 + i * 2.1 + 0.9, cz - 0.9, cz + 0.9, 2.02, PINE.lightened(0.1 * float(i % 2)))
		_fz(mb, cx - 5.0, cx + 5.0, 0.4, 1.9, cz - 0.91, PINE.darkened(0.15))
	_tarp_over(mb, Vector3(22.0, 0, -4.8), 7.0, 1.9, 1.5, Color(0.2, 0.42, 0.7))
	out.append([Vector3(22.0, 0.8, -4.8), Vector3(7.0, 1.6, 2.2)])
	# Sawdust and bark piles.
	_pile(mb, out, Vector3(16.0, 0, 12.0), 6.0, 5.0, SAWDUST, rng)
	_pile(mb, out, Vector3(23.5, 0, 3.0), 4.2, 3.2, BARK.lightened(0.1), rng)
	# Log loader: a wheeled machine with a grapple boom.
	_loader(mb, out, Vector3(-9.0, 0, -11.0), 0.5)
	# Office shed.
	_cabin(mb, out, Vector3(-22.0, 0, 15.0), 0.0, 8.0, 5.0, 2.6, 1.0, TIMBER_LT.darkened(0.15), _pick(Kit.TIN_ROOFS, rng), rng, 2)
	_bx(mb, -24.5, -22.5, 0.0, 0.3, 11.8, 12.6, CONCRETE_LT)
	mb.cylinder(Vector3(-19.5, 2.6, 16.2), 0.12, 1.4, STEEL_DK, 4)
	_board(mb, out, Vector3(5.5, 0, -hz + 3.0), Vector2(2.6, 1.5), 1.2, Color(0.2, 0.55, 0.3), rng)
	# The tall rusty teepee burner at the back.
	var bc := Vector3(22.0, 0.0, 15.5)
	_frustum(mb, bc, 5.4, 1.6, 15.0, _g(RUST, MeshBuilder.METAL), 12, false)
	_frustum(mb, bc + Vector3(0, 15.0, 0), 1.9, 0.0, 1.2, RUST_DK, 12, false)
	mb.cylinder(bc, 5.5, 0.35, RUST_DK, 12)
	_fz(mb, bc.x - 1.1, bc.x + 1.1, 0.0, 2.1, bc.z - 5.2, IRON)
	for k in 3:
		var by := 3.0 + k * 4.0
		mb.cylinder(bc + Vector3(0, by, 0), 5.4 - 3.8 * by / 15.0 + 0.06, 0.3, RUST_DK, 12)
	out.append([bc + Vector3(0, 7.5, 0), Vector3(9.0, 15.0, 9.0)])
	Kit._beam(mb, Vector3(15.0, 1.0, 12.0), bc + Vector3(-4.0, 2.2, -1.5), 0.5, STEEL_DK)


## A square timber post from the ground to h, with a collider.
static func _pole_sq(mb, out: Array, p: Vector3, h: float, t: float, color: Color) -> void:
	mb.box(p + Vector3(0, h * 0.5, 0), Vector3(t, h, t), color)
	out.append([p + Vector3(0, h * 0.5, 0), Vector3(t, h, t)])


## A pitched tarp over a stack: two sloped sheets down to the stack's sides.
static func _tarp_over(mb, p: Vector3, length: float, half: float, h: float, color: Color) -> void:
	var ridge := h + 0.7
	for s: float in [-1.0, 1.0]:
		var a := Vector3(p.x - length * 0.5, h - 0.4, p.z + s * (half + 0.1))
		var b := Vector3(p.x - length * 0.5, ridge, p.z)
		var c := Vector3(p.x + length * 0.5, ridge, p.z)
		var e := Vector3(p.x + length * 0.5, h - 0.4, p.z + s * (half + 0.1))
		mb.quad(a, b, c, e, Vector3(0, 1, s * 0.8).normalized(), color if s < 0 else color.darkened(0.1))


## A heap of sawdust or bark: a cone of rings with a collider box.
static func _pile(mb, out: Array, p: Vector3, r: float, h: float, color: Color, rng: RandomNumberGenerator) -> void:
	_frustum(mb, p, r, r * 0.45, h * 0.6, color.darkened(0.06), 10, false)
	_frustum(mb, p + Vector3(0, h * 0.6, 0), r * 0.45, 0.0, h * 0.4, color, 10, false)
	out.append([p + Vector3(0, h * 0.3, 0), Vector3(r * 1.3, h * 0.6, r * 1.3)])


## A wheeled log loader: chassis, cab and a boom with a grapple, nose to -Z before yaw.
static func _loader(mb, out: Array, p: Vector3, yaw: float) -> void:
	var saved := _push(mb, p, yaw)
	var paint := _g(Color(0.92, 0.62, 0.1), MeshBuilder.GLOSS)
	mb.box(Vector3(0, 1.1, 0.4), Vector3(2.5, 1.0, 4.4), paint)
	mb.box(Vector3(0, 1.0, -1.6), Vector3(1.8, 0.8, 1.2), STEEL_DK)
	mb.box(Vector3(0.0, 2.1, 0.9), Vector3(1.9, 1.4, 1.8), paint)
	mb.box(Vector3(0.0, 2.2, 0.0), Vector3(1.7, 1.1, 0.06), _g(Color(0.12, 0.17, 0.22), MeshBuilder.GLASS))
	mb.box(Vector3(0.0, 2.85, 0.9), Vector3(2.1, 0.1, 2.0), STEEL_DK)
	for sx: float in [-1.0, 1.0]:
		for z: float in [-1.5, 1.7]:
			mb.box(Vector3(sx * 1.25, 0.65, z), Vector3(0.7, 1.3, 1.3), BLACK)
	Kit._beam(mb, Vector3(0.7, 1.7, -0.2), Vector3(0.7, 3.6, -3.2), 0.35, paint)
	Kit._beam(mb, Vector3(0.7, 3.6, -3.2), Vector3(0.7, 1.4, -5.2), 0.3, paint)
	for sx: float in [-1.0, 1.0]:
		Kit._beam(mb, Vector3(0.7 + sx * 0.35, 1.4, -5.2), Vector3(0.7 + sx * 0.7, 0.5, -5.8), 0.16, STEEL_DK)
	mb.xform = saved
	Kit._col(out, p + Vector3(0, 1.4, 0), Vector3(2.9, 2.8, 4.8), yaw)


# --- Cult compound ---------------------------------------------------------------------

static func cult_compound(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var hx := w * 0.5
	var hz := d * 0.5
	var fx := hx - 2.0
	var fz := hz - 2.0
	var pale := Color(0.88, 0.85, 0.74)
	var gold := Color(0.9, 0.7, 0.22)
	var ochre := Color(0.78, 0.5, 0.2)
	# Wooden perimeter with a gate gap at front centre, pale gate posts.
	var fh := 2.6
	_boards(mb, out, Vector3(-fx, 0, -fz), Vector3(-3.2, 0, -fz), fh, TIMBER_LT.darkened(0.12))
	_boards(mb, out, Vector3(3.2, 0, -fz), Vector3(fx, 0, -fz), fh, TIMBER_LT.darkened(0.12))
	_boards(mb, out, Vector3(-fx, 0, fz), Vector3(fx, 0, fz), fh, TIMBER_LT.darkened(0.12))
	_boards(mb, out, Vector3(-fx, 0, -fz), Vector3(-fx, 0, fz), fh, TIMBER_LT.darkened(0.12))
	_boards(mb, out, Vector3(fx, 0, -fz), Vector3(fx, 0, fz), fh, TIMBER_LT.darkened(0.12))
	for s: float in [-1.0, 1.0]:
		mb.cylinder(Vector3(s * 3.4, 0, -fz), 0.32, 5.2, _g(pale, MeshBuilder.SIDING), 6)
		out.append([Vector3(s * 3.4, 2.6, -fz), Vector3(0.64, 5.2, 0.64)])
		mb.ball(Vector3(s * 3.4, 5.5, -fz), Vector3(0.5, 0.5, 0.5), gold, 6, 3)
		mb.box(Vector3(s * 3.4, 4.6, -fz), Vector3(0.9, 0.2, 0.9), ochre)
	# Path and plaza with a ring of tall pale poles around a fire bowl.
	Kit._pad(mb, -1.8, 1.8, -hz, -28.0, _g(GRAVEL.lightened(0.15), MeshBuilder.CONCRETE), 0.03)
	var pc := Vector3(0.0, 0.0, -17.0)
	_disc(mb, pc + Vector3(0, 0.04, 0), 12.0, _g(Color(0.7, 0.67, 0.58), MeshBuilder.PAVING), 20)
	_ring(mb, pc + Vector3(0, 0.06, 0), 10.2, 10.7, gold, 24)
	_ring(mb, pc + Vector3(0, 0.06, 0), 5.2, 5.5, ochre, 20)
	mb.cylinder(pc, 1.2, 0.7, CONCRETE_DK, 8)
	_disc(mb, pc + Vector3(0, 0.72, 0), 1.0, _g(Color(1.0, 0.5, 0.15), MeshBuilder.GLOW_LAMP), 8)
	out.append([pc + Vector3(0, 0.35, 0), Vector3(2.4, 0.7, 2.4)])
	for k in 14:
		var a := TAU * k / 14.0
		var pp := pc + Vector3(cos(a), 0, sin(a)) * 9.2
		var ph := 6.4 + 0.9 * sin(k * 1.7)
		mb.cylinder(pp, 0.28, ph, _g(pale, MeshBuilder.SIDING), 5)
		out.append([pp + Vector3(0, ph * 0.5, 0), Vector3(0.56, ph, 0.56)])
		mb.cylinder(pp + Vector3(0, ph, 0), 0.36, 0.28, gold, 5)
	# The long meeting hall: a flat roof with a sun disc of concentric rings
	# painted on it, a ring clerestory at its heart, an A-frame porch.
	var hx0 := -20.0
	var hx1 := 20.0
	var hz0 := -2.0
	var hz1 := 14.0
	var top := 5.6
	_sx(mb, out, hx0, hx1, 0.0, top, hz0, hz1, _g(pale.darkened(0.04), MeshBuilder.SIDING))
	for i in 11:
		var x := hx0 + 2.0 + i * 3.6
		_bx(mb, x - 0.18, x + 0.18, 0.0, top, hz0 - 0.1, hz0, TIMBER_DK)
	_bx(mb, hx0 - 0.5, hx1 + 0.5, top, top + 0.35, hz0 - 0.5, hz1 + 0.5, _g(TIMBER, MeshBuilder.SIDING))
	var roof_y := top + 0.35
	_bx(mb, hx0 - 0.5, hx1 + 0.5, roof_y, roof_y + 0.3, hz0 - 0.5, hz0 - 0.3, TIMBER_DK)
	_bx(mb, hx0 - 0.5, hx1 + 0.5, roof_y, roof_y + 0.3, hz1 + 0.3, hz1 + 0.5, TIMBER_DK)
	for s: float in [-1.0, 1.0]:
		var xe := hx0 - 0.5 if s < 0 else hx1 + 0.3
		_bx(mb, xe, xe + 0.2, roof_y, roof_y + 0.3, hz0 - 0.5, hz1 + 0.5, TIMBER_DK)
	var rc := Vector3(0.0, roof_y + 0.02, 6.0)
	_disc(mb, rc, 7.6, Color(0.82, 0.8, 0.7), 24)
	var ring_cols: Array[Color] = [ochre, gold, Color(0.35, 0.22, 0.14), gold, ochre]
	for k in 5:
		_ring(mb, rc + Vector3(0, 0.02 + 0.01 * k, 0), 7.4 - k * 1.05, 6.6 - k * 1.05, ring_cols[k], 24)
	mb.cylinder(rc, 2.7, 1.5, _g(pale, MeshBuilder.SIDING), 12)
	mb.cylinder(rc + Vector3(0, 0.6, 0), 2.76, 0.7, _g(Color(0.15, 0.2, 0.25), MeshBuilder.GLASS), 12)
	_frustum(mb, rc + Vector3(0, 1.5, 0), 3.0, 0.8, 0.8, gold, 12)
	mb.cylinder(rc + Vector3(0, 2.3, 0), 0.07, 1.6, gold, 4)
	mb.ball(rc + Vector3(0, 3.95, 0), Vector3(0.28, 0.28, 0.28), gold, 6, 3)
	# A-frame porch.
	for sx: float in [-1.0, 1.0]:
		Kit._post(mb, out, Vector3(sx * 3.4, 0, hz0 - 3.6), 2.8, 0.4, TIMBER_DK)
	Kit._gable(mb, 0.0, hz0 - 2.1, 2.8, 9.0, 4.4, 4.2, _g(Color(0.5, 0.22, 0.14), MeshBuilder.SEAM_ROOF), pale.darkened(0.1), true)
	_fz(mb, -2.2, 2.2, 0.0, 3.2, hz0 - 0.04, TIMBER_DK)
	_fz(mb, -2.0, 2.0, 0.1, 3.0, hz0 - 0.06, _g(Color(0.55, 0.38, 0.2), MeshBuilder.SIDING))
	for k in 4:
		var cx := lerpf(-16.5, 16.5, k / 3.0) + (-0.0 if k < 2 else 0.0)
		if absf(cx) > 6.0:
			_fz(mb, cx - 0.7, cx + 0.7, 1.3, 2.9, hz0 - 0.03, _g(GLASS_C, MeshBuilder.GLASS))
	# Dorm cabins in an arc behind the hall, doors toward the plaza.
	var centre := Vector2(0.0, 9.0)
	for k in 6:
		var th := deg_to_rad(12.0 + k * 31.0)
		var pp := Vector2(centre.x + cos(th) * 32.0, centre.y + sin(th) * 19.5)
		var dir := (centre - pp).normalized()
		var yaw := atan2(-dir.x, -dir.y)
		_cabin(mb, out, Vector3(pp.x, 0, pp.y), yaw, 6.0, 4.4, 2.6, 1.6, _pick([Color(0.8, 0.76, 0.66), Color(0.72, 0.62, 0.5), Color(0.84, 0.8, 0.7)], rng), Color(0.45, 0.28, 0.2), rng, 1, false)
	# Vegetable garden rows, front left.
	for k in 7:
		var gz := -31.0 + k * 2.0
		_bx(mb, -35.0, -16.0, 0.0, 0.22, gz - 0.6, gz + 0.6, Color(0.32, 0.22, 0.15))
		for i in 6:
			var gx := -34.0 + i * 3.1 + (k % 2) * 1.0
			mb.box(Vector3(gx + 0.8, 0.45, gz), Vector3(1.9, 0.5, 0.8), _vary(_pick([LEAF, LEAF.lightened(0.15), Color(0.4, 0.52, 0.2), Color(0.5, 0.25, 0.4)], rng), rng, 0.05))
	for k in 3:
		Kit._beam(mb, Vector3(-35.0, 0, -31.0 + k * 6.0), Vector3(-35.0, 1.6, -31.0 + k * 6.0), 0.12, TIMBER_DK)
	# Water tank on a stand, front right.
	var tp := Vector3(27.0, 0.0, -20.0)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			Kit._post(mb, out, tp + Vector3(sx * 1.7, 0, sz * 1.7), 5.5, 0.4, TIMBER_DK)
	for sx: float in [-1.0, 1.0]:
		_strap(mb, tp + Vector3(sx * 1.7, 0.4, -1.7), tp + Vector3(sx * 1.7, 5.0, 1.7), 0.18, Vector3(sx, 0, 0), TIMBER)
	mb.cylinder(tp + Vector3(0, 5.5, 0), 2.5, 3.2, _g(Color(0.4, 0.45, 0.5), MeshBuilder.METAL), 10)
	_frustum(mb, tp + Vector3(0, 8.7, 0), 2.6, 0.2, 1.1, Color(0.35, 0.38, 0.42), 10)
	# Lookout platform at the back right.
	var lp := Vector3(33.0, 0.0, 27.0)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			Kit._post(mb, out, lp + Vector3(sx * 1.6, 0, sz * 1.6), 9.0, 0.34, TIMBER_DK)
	for k in 3:
		for sx: float in [-1.0, 1.0]:
			_strap(mb, lp + Vector3(sx * 1.6, 1.0 + k * 2.6, -1.6), lp + Vector3(sx * 1.6, 3.6 + k * 2.6, 1.6), 0.16, Vector3(sx, 0, 0), TIMBER)
	_bx(mb, lp.x - 2.4, lp.x + 2.4, 9.0, 9.2, lp.z - 2.4, lp.z + 2.4, TIMBER)
	_railing(mb, out, lp + Vector3(-2.3, 9.2, -2.3), lp + Vector3(2.3, 9.2, -2.3), 1.0, TIMBER_DK)
	_railing(mb, out, lp + Vector3(-2.3, 9.2, 2.3), lp + Vector3(2.3, 9.2, 2.3), 1.0, TIMBER_DK)
	_railing(mb, out, lp + Vector3(-2.3, 9.2, -2.3), lp + Vector3(-2.3, 9.2, 2.3), 1.0, TIMBER_DK)
	_railing(mb, out, lp + Vector3(2.3, 9.2, -2.3), lp + Vector3(2.3, 9.2, 2.3), 1.0, TIMBER_DK)
	for k in 8:
		Kit._beam(mb, lp + Vector3(-1.2, 0.5 + k * 1.05, -1.75), lp + Vector3(-0.5, 0.5 + k * 1.05, -1.75), 0.1, TIMBER_LT)
	Kit._beam(mb, lp + Vector3(-1.2, 0, -1.75), lp + Vector3(-1.2, 9.2, -1.75), 0.1, TIMBER_LT)


# --- Ranger post --------------------------------------------------------------------------

static func ranger_post(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var hx := w * 0.5
	var hz := d * 0.5
	Kit._pad(mb, -hx + 0.8, hx - 0.8, -hz + 0.8, hz - 0.8, Color(0.58, 0.5, 0.38), 0.02)
	Kit._pad(mb, -2.0, 2.0, -hz, -hz + 5.0, _g(GRAVEL, MeshBuilder.CONCRETE), 0.03)
	# Log cabin with a porch on the front.
	var cp := Vector3(-4.5, 0.0, 3.0)
	_cabin(mb, out, cp, 0.0, 10.0, 6.6, 2.9, 2.4, Color(0.5, 0.34, 0.2), Color(0.18, 0.36, 0.26), rng, 2, true, true)
	for k in 5:
		_fz(mb, cp.x - 5.0, cp.x + 5.0, 0.55 + k * 0.55, 0.6 + k * 0.55, cp.z - 3.32, Color(0.32, 0.21, 0.13))
	_bx(mb, -9.5, -0.5, 0.0, 0.3, -1.4, 0.0, TIMBER_LT)
	for x: float in [-9.4, -5.0, -0.6]:
		Kit._post(mb, out, Vector3(x, 0, -1.3), 2.6, 0.22, TIMBER_DK)
	_bx(mb, -9.9, -0.1, 2.6, 2.75, -1.9, 0.3, TIMBER)
	_slope(mb, Vector3(-5.0, 2.75, -1.9), Vector3(-5.0, 3.5, 0.3), 10.4, Vector3.RIGHT, _g(Color(0.18, 0.36, 0.26), MeshBuilder.SEAM_ROOF), 0.08)
	_railing(mb, out, Vector3(-9.5, 0.3, -1.3), Vector3(-6.8, 0.3, -1.3), 0.9, TIMBER_DK)
	_railing(mb, out, Vector3(-3.2, 0.3, -1.3), Vector3(-0.5, 0.3, -1.3), 0.9, TIMBER_DK)
	for x: float in [-8.0, -2.2]:
		_bx(mb, x - 0.35, x + 0.35, 0.3, 0.55, -0.9, -0.3, TIMBER_LT)
		_bx(mb, x - 0.35, x + 0.35, 0.55, 1.0, -0.35, -0.3, TIMBER_LT)
	Kit._flagpole(mb, out, Vector3(2.8, 0, -6.5), 8.0, [Color(0.16, 0.42, 0.3)])
	# Fire-lookout tower, about 10 m.
	_lookout_tower(mb, out, Vector3(7.5, 0.0, 4.5))
	# Ranger pickup, light bar on the roof.
	Kit._pickup(mb, out, Vector3(6.0, 0, -4.2), 0.35, Color(0.13, 0.38, 0.3))
	var saved := _push(mb, Vector3(6.0, 0, -4.2), 0.35)
	mb.box(Vector3(0, 2.0, -0.4), Vector3(1.2, 0.14, 0.3), _g(Color(0.9, 0.2, 0.2), MeshBuilder.GLOW_NEON))
	mb.xform = saved
	# Notice board, a woodpile, a trail marker.
	_notice_board(mb, out, Vector3(-9.0, 0, -5.8), rng)
	for k in 3:
		var lp := Vector3(-1.8, 0.2 + k * 0.38, 8.2)
		for i in 4 - k:
			_log(mb, lp + Vector3(i * 0.5 - (3 - k) * 0.25, 0, 0.0), lp + Vector3(i * 0.5 - (3 - k) * 0.25, 0, -1.6), 0.2, _vary(LOG, rng, 0.1), LOG_END, 5)
	out.append([Vector3(-1.0, 0.6, 7.6), Vector3(2.2, 1.2, 1.8)])
	_board(mb, out, Vector3(8.5, 0, -8.6), Vector2(1.4, 0.9), 0.7, Color(0.2, 0.55, 0.3), rng)


## A fire-lookout tower: four tapered legs, braces, a stair and a glazed cab.
static func _lookout_tower(mb, out: Array, p: Vector3) -> void:
	var h := 8.0
	var wb := 4.0
	var wt := 2.6
	var wood := TIMBER_DK
	var cs: Array = [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for c: Vector2 in cs:
		Kit._beam(mb, p + Vector3(c.x * wb * 0.5, 0.1, c.y * wb * 0.5), p + Vector3(c.x * wt * 0.5, h, c.y * wt * 0.5), 0.3, wood)
		out.append([p + Vector3(c.x * wb * 0.5, 1.0, c.y * wb * 0.5), Vector3(0.4, 2.0, 0.4)])
	for k in 3:
		var t0 := k / 3.0
		var t1 := (k + 1) / 3.0
		var r0 := lerpf(wb, wt, t0) * 0.5
		var r1 := lerpf(wb, wt, t1) * 0.5
		for i in 4:
			var c0: Vector2 = cs[i]
			var c1: Vector2 = cs[(i + 1) % 4]
			var n := Vector3((c0.x + c1.x) * 0.5, 0, (c0.y + c1.y) * 0.5).normalized()
			_strap(mb, p + Vector3(c0.x * r0, h * t0 + 0.1, c0.y * r0), p + Vector3(c1.x * r1, h * t1, c1.y * r1), 0.16, n, wood.lightened(0.1))
	# Stair up the front, landings.
	for k in 3:
		var y0 := 0.4 + k * 2.4
		Kit._beam(mb, p + Vector3(-1.9 + k * 0.1, y0, -2.1), p + Vector3(-0.3 + k * 0.1, y0 + 2.4, -2.1), 0.14, wood)
		_bx(mb, p.x - 2.2 + k * 0.1, p.x - 1.0 + k * 0.1, y0 + 2.3, y0 + 2.4, p.z - 2.3, p.z - 1.8, TIMBER_LT)
	var deck_y := h
	_bx(mb, p.x - 2.0, p.x + 2.0, deck_y, deck_y + 0.2, p.z - 2.0, p.z + 2.0, TIMBER)
	_bx(mb, p.x - 1.4, p.x + 1.4, deck_y + 0.2, deck_y + 2.4, p.z - 1.4, p.z + 1.4, _g(Color(0.4, 0.3, 0.2), MeshBuilder.SIDING))
	_bx(mb, p.x - 1.45, p.x + 1.45, deck_y + 0.9, deck_y + 2.0, p.z - 1.45, p.z + 1.45, _g(Color(0.12, 0.17, 0.2), MeshBuilder.GLASS))
	Kit._hip(mb, Vector3(p.x, deck_y + 2.4, p.z), 3.4, 3.4, 0.9, Color(0.18, 0.36, 0.26))
	_railing(mb, out, p + Vector3(-1.95, deck_y + 0.2, -1.95), p + Vector3(1.95, deck_y + 0.2, -1.95), 0.9, wood, 2.0)
	_railing(mb, out, p + Vector3(-1.95, deck_y + 0.2, 1.95), p + Vector3(1.95, deck_y + 0.2, 1.95), 0.9, wood, 2.0)
	_railing(mb, out, p + Vector3(-1.95, deck_y + 0.2, -1.95), p + Vector3(-1.95, deck_y + 0.2, 1.95), 0.9, wood, 2.0)
	_railing(mb, out, p + Vector3(1.95, deck_y + 0.2, -1.95), p + Vector3(1.95, deck_y + 0.2, 1.95), 0.9, wood, 2.0)


## A notice board: a roofed frame on two posts with colour panels (no words).
static func _notice_board(mb, out: Array, p: Vector3, rng: RandomNumberGenerator) -> void:
	for s: float in [-1.0, 1.0]:
		Kit._post(mb, out, p + Vector3(s * 1.3, 0, 0), 2.4, 0.18, TIMBER_DK)
	_bx(mb, p.x - 1.4, p.x + 1.4, 0.9, 2.1, p.z - 0.07, p.z + 0.07, TIMBER)
	_slope(mb, p + Vector3(0, 2.1, -0.25), p + Vector3(0, 2.5, 0.25), 3.0, Vector3.RIGHT, _g(Color(0.18, 0.36, 0.26), MeshBuilder.SEAM_ROOF), 0.06)
	for i in 4:
		var x := p.x - 1.0 + i * 0.66
		_fz(mb, x - 0.26, x + 0.26, 1.1 + rng.randf() * 0.2, 1.9 - rng.randf() * 0.2, p.z - 0.09, _pick(SIGN_FIELDS, rng))


# --- Logging camp -------------------------------------------------------------------------

static func logging_camp(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var hx := w * 0.5
	var hz := d * 0.5
	var mud := Color(0.35, 0.28, 0.2)
	_disc_xz(mb, Vector3(0, 0.02, 0), hx - 1.0, hz - 1.0, mud, 24)
	for s: float in [-1.0, 1.0]:
		_strap(mb, Vector3(s * 2.0 + 1.0, 0.03, -hz + 0.4), Vector3(s * 3.0 + 4.0, 0.03, -2.0), 0.9, Vector3.UP, MUD.darkened(0.12))
	var skip: Array[Vector3] = []
	# Two canvas tents and a fire pit between them.
	_tent(mb, out, Vector3(-12.0, 0, 8.0), 0.5, 3.2, 4.4, 2.2, CANVAS[0], true)
	_tent(mb, out, Vector3(-5.5, 0, 11.5), -0.3, 3.2, 4.4, 2.2, CANVAS[2], true)
	skip.append_array([Vector3(-12, 0, 8), Vector3(-5.5, 0, 11.5)])
	var fp := Vector3(-8.0, 0, 5.0)
	_disc(mb, fp + Vector3(0, 0.04, 0), 1.0, Color(0.1, 0.09, 0.08), 8)
	for k in 7:
		var a := TAU * k / 7.0
		_rock(mb, fp + Vector3(cos(a), 0, sin(a)) * 0.95, Vector3(0.28, 0.3, 0.28), ROCK, rng, 5)
	Kit._beam(mb, fp + Vector3(-0.5, 0.15, 0.2), fp + Vector3(0.5, 0.5, -0.2), 0.16, BARK)
	Kit._beam(mb, fp + Vector3(0.5, 0.15, 0.3), fp + Vector3(-0.4, 0.5, -0.1), 0.16, BARK)
	mb.box(fp + Vector3(0, 0.1, 0), Vector3(0.5, 0.2, 0.5), _g(Color(1.0, 0.45, 0.1), MeshBuilder.GLOW_LAMP))
	for k in 3:
		var a := 3.6 + k * 1.1
		_log(mb, fp + Vector3(cos(a), 0.0, sin(a)) * 2.2 + Vector3(-0.7, 0.24, 0), fp + Vector3(cos(a), 0.0, sin(a)) * 2.2 + Vector3(0.7, 0.24, 0), 0.2, LOG, LOG_END, 5)
	# The old work trailer on blocks.
	var tp := Vector3(10.5, 0, 9.5)
	var saved := _push(mb, tp, 0.18)
	mb.box(Vector3(0, 1.5, 0), Vector3(7.2, 2.4, 2.7), _g(Color(0.78, 0.76, 0.68), MeshBuilder.SIDING))
	mb.box(Vector3(0, 2.75, 0), Vector3(7.4, 0.14, 2.9), RUST)
	mb.box(Vector3(-1.0, 2.84, 0.2), Vector3(3.0, 0.04, 1.8), MEMBRANE_C)
	for x: float in [-3.0, 0.0, 3.0]:
		mb.box(Vector3(x, 0.15, 0), Vector3(0.5, 0.3, 2.2), CONCRETE_DK)
	_fz(mb, -2.4, -1.4, 0.4, 2.2, -1.38, TIMBER_DK)
	_fz(mb, 0.0, 1.6, 1.2, 2.0, -1.38, _g(GLASS_C, MeshBuilder.GLASS))
	_fz(mb, 2.0, 3.3, 1.2, 2.0, -1.38, TIMBER.darkened(0.3))
	_bx(mb, -2.6, -1.2, 0.0, 0.4, -2.3, -1.4, TIMBER)
	mb.xform = saved
	out.append([tp + Vector3(0, 1.4, 0), Vector3(7.4, 2.8, 2.9), 0.18])
	# Log piles.
	_log_stack(mb, out, Vector3(-14.0, 0, -6.0), 0.15, 6.0, 4, 0.42, rng, 3)
	_log_stack(mb, out, Vector3(-6.5, 0, -11.0), -0.2, 5.0, 3, 0.42, rng, 3)
	_log_stack(mb, out, Vector3(15.0, 0, -9.0), 0.4, 5.5, 3, 0.42, rng, 2)
	skip.append_array([Vector3(-14, 0, -6), Vector3(-6.5, 0, -11), Vector3(15, 0, -9)])
	# Tracked feller-skidder.
	_skidder(mb, out, Vector3(4.5, 0, -4.0), -0.5)
	skip.append(Vector3(4.5, 0, -4.0))
	# Fuel drums under a tarp.
	var dp := Vector3(14.5, 0, 1.0)
	for k in 6:
		var o := Vector3((k % 3) * 0.75 - 0.75, 0, (k / 3) * 0.8 - 0.4)
		mb.cylinder(dp + o, 0.32, 0.9, _pick([RUST, Color(0.2, 0.4, 0.6), Color(0.7, 0.2, 0.15)], rng), 6)
	_tarp_over(mb, dp, 2.6, 1.0, 1.1, Color(0.22, 0.45, 0.7))
	out.append([dp + Vector3(0, 0.55, 0), Vector3(2.6, 1.1, 1.8)])
	# Stumps all over.
	skip.append_array([fp, tp, dp])
	var placed := 0
	var tries := 0
	while placed < 18 and tries < 200:
		tries += 1
		var sp := Vector3(rng.randf_range(-hx + 2.0, hx - 2.0), 0, rng.randf_range(-hz + 2.0, hz - 2.0))
		var ok := true
		for q in skip:
			if Vector2(sp.x - q.x, sp.z - q.z).length() < 4.5:
				ok = false
				break
		if absf(sp.x) < 3.5 and sp.z < 0:
			ok = false
		if not ok:
			continue
		skip.append(sp)
		placed += 1
		var r := rng.randf_range(0.32, 0.6)
		var sh := rng.randf_range(0.25, 0.75)
		mb.cylinder(sp, r, sh, BARK.lightened(0.05), 5)
		_disc(mb, sp + Vector3(0, sh + 0.01, 0), r * 0.92, LOG_END, 5)
		if sh >= 0.7:
			out.append([sp + Vector3(0, sh * 0.5, 0), Vector3(r * 1.7, sh, r * 1.7)])
	for k in 5:
		var a := Vector3(rng.randf_range(-hx + 4.0, hx - 4.0), 0.26, rng.randf_range(-hz + 4.0, hz - 6.0))
		_log(mb, a, a + Vector3(rng.randf_range(-3.0, 3.0), 0, rng.randf_range(2.0, 4.0)), 0.22, _vary(LOG, rng, 0.1), LOG_END, 5)


const MEMBRANE_C := Color(0.55, 0.55, 0.52)


## A flat ellipse in the ground plane.
static func _disc_xz(mb, c: Vector3, rx: float, rz: float, color: Color, segs := 16) -> void:
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		mb.tri(c, c + Vector3(cos(a0) * rx, 0, sin(a0) * rz), c + Vector3(cos(a1) * rx, 0, sin(a1) * rz), Vector3.UP, color)


## A tracked feller-skidder: boxy, yellow, a boom with a felling head, nose to -Z before yaw.
static func _skidder(mb, out: Array, p: Vector3, yaw: float) -> void:
	var saved := _push(mb, p, yaw)
	var paint := _g(Color(0.95, 0.72, 0.1), MeshBuilder.GLOSS)
	for sx: float in [-1.0, 1.0]:
		mb.box(Vector3(sx * 1.35, 0.6, 0.0), Vector3(0.9, 1.2, 5.0), BLACK)
		for k in 4:
			mb.box(Vector3(sx * 1.35, 1.25, -1.8 + k * 1.2), Vector3(0.7, 0.1, 0.6), STEEL_DK)
	mb.box(Vector3(0, 1.4, 0.2), Vector3(2.2, 1.0, 4.4), paint)
	mb.box(Vector3(0, 2.4, 0.9), Vector3(2.0, 1.4, 2.0), paint)
	mb.box(Vector3(0, 2.5, -0.15), Vector3(1.8, 1.0, 0.06), _g(Color(0.12, 0.17, 0.22), MeshBuilder.GLASS))
	mb.box(Vector3(0, 3.2, 0.9), Vector3(2.2, 0.1, 2.2), STEEL_DK)
	mb.box(Vector3(0, 2.3, 2.4), Vector3(1.8, 1.8, 0.9), STEEL_DK)
	Kit._beam(mb, Vector3(0.5, 2.0, -1.0), Vector3(0.5, 4.3, -3.4), 0.4, paint)
	Kit._beam(mb, Vector3(0.5, 4.3, -3.4), Vector3(0.5, 2.6, -6.2), 0.34, paint)
	mb.box(Vector3(0.5, 2.3, -6.4), Vector3(0.7, 1.4, 0.7), STEEL_DK)
	mb.box(Vector3(0.5, 2.0, -6.8), Vector3(0.14, 0.14, 0.14), _g(Color(0.9, 0.3, 0.2), MeshBuilder.GLOW_LAMP))
	mb.xform = saved
	Kit._col(out, p + Vector3(0, 1.5, 0), Vector3(3.6, 3.0, 5.2), yaw)


# --- Mine entrance -----------------------------------------------------------------

static func mine_entrance(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var hx := w * 0.5
	var hz := d * 0.5
	_disc_xz(mb, Vector3(0, 0.02, -1.0), hx - 1.0, hz - 1.5, DIRT.darkened(0.2), 24)
	# The rock face across the back half: two cliff blocks and a lintel over the portal.
	var rock := Color(0.4, 0.37, 0.34)
	_cliff(mb, -hx + 0.5, -1.9, 1.0, hz - 0.5, 9.0, rng, rock)
	_cliff(mb, 1.9, hx - 0.5, 1.0, hz - 0.5, 7.5, rng, rock.lightened(0.05))
	_bx(mb, -1.95, 1.95, 3.7, 8.0, 1.0, hz - 0.5, rock.darkened(0.05))
	out.append([Vector3(-hx * 0.55 - 0.9, 4.5, (1.0 + hz - 0.5) * 0.5), Vector3(hx - 0.5 - 1.9 - 0.9, 9.0, hz - 1.5)])
	out.append([Vector3(hx * 0.55 + 0.9, 3.75, (1.0 + hz - 0.5) * 0.5), Vector3(hx - 0.5 - 1.9 - 0.9, 7.5, hz - 1.5)])
	out.append([Vector3(0, 2.0, 1.6), Vector3(3.6, 4.0, 0.6)]) # the adit is plugged: nobody walks in
	# Outcrops and scree break up the face.
	for side: float in [-1.0, 1.0]:
		for k in 7:
			var ox := side * (3.1 + k * 1.6 + rng.randf_range(-0.3, 0.3))
			var oh := rng.randf_range(1.0, 3.2) * (1.0 - 0.06 * k)
			_rock(mb, Vector3(ox, 0, 0.9 + rng.randf_range(-0.3, 0.4)), Vector3(rng.randf_range(1.0, 1.7), oh, rng.randf_range(0.9, 1.4)), _vary(_pick([rock, rock.lightened(0.12), rock.darkened(0.15), ROCK_WARM.darkened(0.2)], rng), rng, 0.08), rng, 6, Vector2(0, rng.randf_range(-0.2, 0.3)))
	# Boulders along the crest with mossy tops, so the face reads as rock
	# rather than two grey blocks.
	for side: float in [-1.0, 1.0]:
		var top_h := 9.0 if side < 0.0 else 7.5
		for k in 5:
			var cx := side * (2.6 + k * (hx - 3.5) / 5.0 + rng.randf_range(0.0, 0.6))
			var cz := rng.randf_range(1.6, hz - 1.5)
			_rock(mb, Vector3(cx, top_h - 0.5, cz), Vector3(rng.randf_range(1.2, 2.0), rng.randf_range(0.9, 1.8), rng.randf_range(1.1, 1.8)), _vary(_pick([rock, ROCK_WARM.darkened(0.15)], rng), rng, 0.08), rng, 6, Vector2.ZERO, MOSS)
	# The timber-framed portal, dark inside, boarded over its right half.
	_bx(mb, -1.43, 1.43, 0.0, 3.4, 1.0, 1.25, BLACK)
	for s: float in [-1.0, 1.0]:
		_bx(mb, s * 1.65 - 0.22, s * 1.65 + 0.22, 0.0, 3.6, 0.6, 1.1, TIMBER_DK)
	_bx(mb, -2.0, 2.0, 3.4, 3.9, 0.5, 1.1, TIMBER)
	Kit._beam(mb, Vector3(-1.45, 0.2, 0.45), Vector3(-0.2, 3.3, 0.45), 0.25, TIMBER_DK, 0.06)
	for k in 4:
		var y := 0.45 + k * 0.78
		_bx(mb, -0.15 + rng.randf_range(-0.25, 0.25), 1.45, y, y + 0.26, 0.4, 0.52, _vary(PINE.darkened(0.3), rng, 0.1))
	Kit._beam(mb, Vector3(-0.1, 0.25, 0.3), Vector3(1.5, 3.3, 0.3), 0.26, PINE.darkened(0.35), 0.06)
	# One dead lamp hung from the header, still faintly lit.
	mb.box(Vector3(-1.0, 3.0, 0.3), Vector3(0.22, 0.3, 0.22), _g(Color(0.95, 0.85, 0.5), MeshBuilder.GLOW_LAMP))
	Kit._beam(mb, Vector3(-1.0, 3.4, 0.3), Vector3(-1.0, 3.15, 0.3), 0.04, IRON)
	# Ore-cart rails coming out of the portal, torn up further out.
	for x: float in [-0.55, 0.55]:
		_bx(mb, x - 0.05, x + 0.05, 0.12, 0.2, -4.0, 0.9, STEEL_DK)
	for k in 5:
		_bx(mb, -0.95, 0.95, 0.04, 0.12, -3.9 + k * 1.0, -3.65 + k * 1.0, TIMBER_DK)
	_bx(mb, -0.6, -0.5, 0.12, 0.2, -9.0, -5.5, RUST_DK)
	Kit._beam(mb, Vector3(0.55, 0.15, -9.0), Vector3(1.4, 0.15, -5.6), 0.1, RUST_DK)
	for k in 3:
		_bx(mb, -0.95, 0.95, 0.04, 0.12, -9.0 + k * 1.3, -8.76 + k * 1.3, TIMBER_DK)
	# The tipped ore cart.
	var ang := 1.0
	var cp := Vector3(1.9, 0.65 * sin(ang) + 0.45 * cos(ang) + 0.2, -4.7)
	var saved: Transform3D = mb.xform
	mb.xform = saved * Transform3D(Basis(Vector3.BACK, ang), cp)
	var cart := _g(RUST, MeshBuilder.METAL)
	mb.box(Vector3(0, -0.41, 0), Vector3(1.3, 0.08, 1.9), cart)
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(s * 0.65, 0, 0), Vector3(0.08, 0.9, 1.9), cart)
		mb.box(Vector3(0, 0, s * 0.95), Vector3(1.3, 0.9, 0.08), cart.darkened(0.12))
		for t: float in [-1.0, 1.0]:
			mb.limb(Vector3(s * 0.62 - 0.1, -0.48, t * 0.6), Vector3(s * 0.62 + 0.1, -0.48, t * 0.6), 0.2, 0.2, STEEL_DK, 6, true)
	mb.xform = saved
	out.append([cp, Vector3(1.9, 1.5, 2.2)])
	for k in 8:
		_rock(mb, Vector3(3.0 + rng.randf_range(-0.9, 1.2), 0, -4.6 + rng.randf_range(-1.4, 1.4)), Vector3(0.2, rng.randf_range(0.12, 0.3), 0.2), ROCK_DK.darkened(0.2), rng, 4)
	# The collapsed tin shed: a roof sheet resting on two posts, a fallen one, wall boards.
	_slope(mb, Vector3(-11.8, 0.3, -4.0), Vector3(-8.2, 2.3, -4.0), 5.0, Vector3.BACK, _g(Color(0.42, 0.25, 0.19), MeshBuilder.METAL), 0.06)
	_pole_sq(mb, out, Vector3(-8.2, 0, -6.3), 2.3, 0.28, TIMBER_DK)
	_pole_sq(mb, out, Vector3(-8.2, 0, -1.8), 2.3, 0.28, TIMBER_DK)
	_tbox(mb, Vector3(-7.0, 0.8, -4.0), Vector3(0.28, 1.4, 0.28), Basis(Vector3.BACK, 1.25), TIMBER_DK)
	_rbox(mb, Vector3(-5.6, 0.12, -6.3), Vector3(3.0, 0.05, 1.6), 0.5, _g(Color(0.4, 0.24, 0.18), MeshBuilder.METAL))
	_tbox(mb, Vector3(-6.3, 1.12, -1.6), Vector3(2.6, 0.05, 1.6), Basis(Vector3.BACK, 0.8), _g(Color(0.34, 0.21, 0.16), MeshBuilder.METAL))
	for k in 6:
		_rbox(mb, Vector3(-5.0 + rng.randf_range(-1.6, 1.6), 0.08, -3.4 + rng.randf_range(-1.8, 1.8)), Vector3(1.6, 0.1, 0.22), rng.randf() * PI, _vary(PINE.darkened(0.3), rng, 0.1))
	out.append([Vector3(-9.8, 1.2, -4.0), Vector3(4.4, 2.4, 5.2)])
	# The timber headframe over the shaft, with its sheave and cables.
	var hp := Vector3(8.5, 0, -2.5)
	saved = _push(mb, hp, 0.0)
	var leg_t := 0.4
	var top_y := 11.5
	var corners: Array[Vector2] = [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for c: Vector2 in corners:
		Kit._beam(mb, Vector3(c.x * 2.2, 0.3, c.y * 1.6), Vector3(c.x * 0.7, top_y, c.y * 0.5), leg_t, TIMBER)
	for lvl in 3:
		var y := 0.1 + (top_y - 0.1) * (lvl + 1) / 3.0 * (1.0 if lvl < 2 else 0.97)
		var t := y / top_y
		var hxl := 2.2 - 1.5 * t
		var hzl := 1.6 - 1.1 * t
		var ring: Array[Vector3] = [Vector3(-hxl, y, -hzl), Vector3(hxl, y, -hzl), Vector3(hxl, y, hzl), Vector3(-hxl, y, hzl)]
		for i in 4:
			Kit._beam(mb, ring[i], ring[(i + 1) % 4], 0.26, TIMBER_DK)
		if lvl < 2:
			var y0 := 0.1 + (top_y - 0.1) * lvl / 3.0
			var t0 := y0 / top_y
			var hx0 := 2.2 - 1.5 * t0
			var hz0 := 1.6 - 1.1 * t0
			Kit._beam(mb, Vector3(-hx0, y0, -hz0), Vector3(hxl, y, -hzl), 0.2, TIMBER_DK)
			Kit._beam(mb, Vector3(hx0, y0, -hz0), Vector3(-hxl, y, -hzl), 0.2, TIMBER_DK)
	_vdisc(mb, Vector3(0, top_y + 0.5, -0.1), 1.15, IRON, 12)
	_vdisc(mb, Vector3(0, top_y + 0.5, -0.14), 0.8, STEEL_DK, 12)
	mb.box(Vector3(0, top_y + 0.5, 0.2), Vector3(0.4, 0.4, 1.2), IRON)
	_strap(mb, Vector3(0.0, top_y - 0.5, -0.05), Vector3(0.0, 2.6, -0.05), 0.08, Vector3(0, 0, -1), IRON)
	_strap(mb, Vector3(-1.1, top_y + 0.4, -0.05), Vector3(-7.0, 0.3, -0.05), 0.08, Vector3(0, 0, -1), IRON)
	mb.box(Vector3(0, 2.2, -0.05), Vector3(0.9, 0.7, 0.5), _g(RUST_DK, MeshBuilder.METAL))
	mb.xform = saved
	for c: Vector2 in corners:
		out.append([hp + Vector3(c.x * 2.0, 1.5, c.y * 1.5), Vector3(0.7, 3.0, 0.7)])
	# The shaft collar: planks round a black hole.
	_fy(mb, hp.x - 1.1, hp.x + 1.1, hp.z - 0.9, hp.z + 0.9, 0.04, BLACK)
	for s: float in [-1.0, 1.0]:
		_bx(mb, hp.x + s * 1.2 - 0.15, hp.x + s * 1.2 + 0.15, 0.0, 0.3, hp.z - 1.05, hp.z + 1.05, TIMBER_DK)
		_bx(mb, hp.x - 1.05, hp.x + 1.05, 0.0, 0.3, hp.z + s * 1.0 - 0.15, hp.z + s * 1.0 + 0.15, TIMBER_DK)
	# Mine timbers stacked, a rusty barrier across the rails, warning boards.
	for k in 4:
		Kit._beam(mb, Vector3(4.0, 0.2 + (k / 2) * 0.32, -10.3 + (k % 2) * 0.4), Vector3(7.6, 0.2 + (k / 2) * 0.32, -10.3 + (k % 2) * 0.4), 0.3, TIMBER_DK)
	for k in 4:
		Kit._beam(mb, Vector3(-1.8 + k * 0.9, 1.0, -7.6), Vector3(-0.9 + k * 0.9, 1.0, -7.6), 0.14, RED if k % 2 == 0 else WHITE, 0.08)
	_pole_sq(mb, out, Vector3(-2.0, 0, -7.6), 1.25, 0.16, TIMBER_DK)
	_pole_sq(mb, out, Vector3(1.9, 0, -7.6), 1.25, 0.16, TIMBER_DK)
	_board(mb, out, Vector3(-5.0, 0, -9.8), Vector2(1.7, 1.2), 1.0, YELLOW, rng)
	_board(mb, out, Vector3(5.2, 0, -7.0), Vector2(1.5, 1.1), 1.0, RED, rng)
	# Fence stubs either side, a dead tree, fallen rock before the portal.
	_chain(mb, out, Vector3(-hx + 1.0, 0, -hz + 1.5), Vector3(-6.0, 0, -hz + 1.5), 2.0, Vector3(0, 0, -1), 4.5, false)
	_chain(mb, out, Vector3(6.0, 0, -hz + 1.5), Vector3(hx - 1.0, 0, -hz + 1.5), 2.0, Vector3(0, 0, -1), 4.5, false)
	mb.limb(Vector3(-11.5, 0.05, -8.0), Vector3(-11.7, 4.6, -8.0), 0.32, 0.12, BARK, 5, false)
	mb.limb(Vector3(-11.6, 2.8, -8.0), Vector3(-9.8, 5.4, -7.6), 0.14, 0.05, BARK, 4, false)
	mb.limb(Vector3(-11.6, 3.4, -8.0), Vector3(-13.4, 5.6, -8.4), 0.14, 0.05, BARK, 4, false)
	mb.limb(Vector3(-11.7, 4.4, -8.0), Vector3(-11.4, 6.6, -7.8), 0.1, 0.04, BARK, 4, false)
	out.append([Vector3(-11.6, 1.5, -8.0), Vector3(0.7, 3.0, 0.7)])
	for k in 7:
		var rp := Vector3(rng.randf_range(-6.0, 6.0), 0, rng.randf_range(-3.0, 0.2))
		if absf(rp.x) < 1.4:
			rp.x += 2.6 * signf(rp.x if rp.x != 0.0 else 1.0)
		_rock(mb, rp, Vector3(rng.randf_range(0.3, 0.9), rng.randf_range(0.25, 0.7), rng.randf_range(0.3, 0.9)), _vary(ROCK, rng, 0.12), rng, 5)


# --- Shared by the later kinds -----------------------------------------------------

## A flat oval ring in the ground plane between two ellipses at c.
static func _oval(mb, c: Vector3, rx0: float, rz0: float, rx1: float, rz1: float, color: Color, segs := 24) -> void:
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		mb.quad(c + d0 * Vector3(rx0, 0, rz0), c + d1 * Vector3(rx0, 0, rz0), c + d1 * Vector3(rx1, 0, rz1), c + d0 * Vector3(rx1, 0, rz1), Vector3.UP, color)


## A conifer h tall: trunk and three cones, trunk collider.
static func _pine(mb, out: Array, p: Vector3, h: float, rng: RandomNumberGenerator) -> void:
	mb.cylinder(p, 0.22, h * 0.3, BARK, 5)
	var col := _vary(GREEN_DK, rng, 0.12)
	for k in 3:
		Kit._cone(mb, p + Vector3(0, h * (0.18 + 0.21 * k), 0), h * 0.3 * (1.0 - 0.27 * k), h * 0.4, col.lightened(0.04 * k), 6)
	out.append([p + Vector3(0, 1.0, 0), Vector3(0.6, 2.0, 0.6)])


## A picnic table turned by yaw (long side along X), collides.
static func _picnic(mb, out: Array, p: Vector3, yaw: float, color: Color) -> void:
	var saved := _push(mb, p, yaw)
	mb.box(Vector3(0, 0.78, 0), Vector3(2.0, 0.08, 0.8), color)
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(0, 0.45, s * 0.75), Vector3(2.0, 0.07, 0.28), color.darkened(0.1))
		mb.box(Vector3(s * 0.8, 0.4, 0), Vector3(0.12, 0.8, 1.7), TIMBER_DK)
	mb.xform = saved
	Kit._col(out, p + Vector3(0, 0.45, 0), Vector3(2.0, 0.9, 1.9), yaw)


## Grass tufts scattered in a plan ellipse, none within `gap` of the points in `avoid`.
static func _tufts(mb, centre: Vector3, rx: float, rz: float, n: int, rng: RandomNumberGenerator, avoid: Array = [], gap := 1.5) -> void:
	var placed := 0
	var tries := 0
	while placed < n and tries < n * 12:
		tries += 1
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf())
		var p := centre + Vector3(cos(a) * rx * r, 0, sin(a) * rz * r)
		var ok := true
		for q: Vector3 in avoid:
			if Vector2(p.x - q.x, p.z - q.z).length() < gap:
				ok = false
				break
		if not ok:
			continue
		placed += 1
		var c := _vary(LEAF.lightened(0.05), rng, 0.15)
		for k in 3:
			var da := TAU * k / 3.0 + rng.randf()
			Kit._cone(mb, p + Vector3(cos(da), 0, sin(da)) * 0.12, 0.13, rng.randf_range(0.45, 0.8), c, 4)


# --- Stone ring ---------------------------------------------------------------------

static func stone_ring(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var hx := w * 0.5
	var hz := d * 0.5
	_disc_xz(mb, Vector3(0, 0.02, 0), hx - 0.8, hz - 0.8, MOSS.darkened(0.2).lerp(DIRT, 0.25), 28)
	_oval(mb, Vector3(0, 0.04, 0), 6.0, 6.0, 7.3, 7.3, DIRT.lightened(0.12), 28)
	_strap(mb, Vector3(0, 0.05, -hz + 0.6), Vector3(0, 0.05, -7.0), 2.0, Vector3.UP, DIRT.lightened(0.08))
	var spots: Array[Vector3] = [Vector3.ZERO]
	# Twelve stones on a ring, two of them fallen.
	for i in 12:
		var a := TAU * (i + 0.5) / 12.0 + rng.randf_range(-0.05, 0.05)
		var rad := 8.0 + rng.randf_range(-0.5, 0.5)
		var p := Vector3(cos(a) * rad, 0, sin(a) * rad)
		spots.append(p)
		var col := _vary(_pick([ROCK, ROCK_DK, ROCK_WARM, ROCK.lightened(0.1)], rng), rng, 0.08)
		var moss := MOSS.lerp(col, 0.35) if rng.randf() < 0.5 else col.lightened(0.1)
		if i == 3 or i == 8:
			_rock(mb, p, Vector3(2.2, 0.85, 0.85), col, rng, 6, Vector2.ZERO, moss, -a)
			Kit._col(out, p + Vector3(0, 0.42, 0), Vector3(3.8, 0.85, 1.4), -a)
			continue
		var h := rng.randf_range(2.0, 4.0)
		var lean := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.2, 0.6)
		var yaw := atan2(-cos(a), -sin(a))
		var rx := rng.randf_range(0.7, 1.1)
		var rz := rng.randf_range(0.55, 0.9)
		_rock(mb, p, Vector3(rx, h, rz), col, rng, 6, lean, moss, yaw)
		out.append([p + Vector3(lean.x * 0.4, h * 0.5, lean.y * 0.4), Vector3(rx * 1.5, h, rz * 1.5), yaw])
	# The flat central stone with a few offerings.
	_rock(mb, Vector3.ZERO, Vector3(2.4, 0.6, 1.9), ROCK_DK, rng, 7, Vector2.ZERO, ROCK.lightened(0.15), 0.4)
	for k in 3:
		var cp := Vector3(-0.7 + k * 0.7, 0.42, 0.2 - (k % 2) * 0.5)
		mb.cylinder(cp, 0.06, 0.26, CREAM, 5)
		mb.box(cp + Vector3(0, 0.3, 0), Vector3(0.09, 0.09, 0.09), _g(Color(1.0, 0.8, 0.4), MeshBuilder.GLOW_LAMP))
	# An inner circle of small stones, scatter and grass.
	for i in 14:
		var a := TAU * i / 14.0 + 0.2
		_rock(mb, Vector3(cos(a), 0, sin(a)) * 4.4 + Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2)), Vector3(rng.randf_range(0.22, 0.4), rng.randf_range(0.14, 0.3), rng.randf_range(0.22, 0.4)), _vary(ROCK, rng, 0.1), rng, 4)
	for i in 10:
		var a := rng.randf() * TAU
		var rad := rng.randf_range(10.0, 11.0)
		_rock(mb, Vector3(cos(a) * rad, 0, sin(a) * rad), Vector3(rng.randf_range(0.3, 0.8), rng.randf_range(0.2, 0.55), rng.randf_range(0.3, 0.8)), _vary(ROCK, rng, 0.12), rng, 5)
	_tufts(mb, Vector3.ZERO, hx - 1.5, hz - 1.5, 22, rng, spots, 1.8)


# --- Hot spring ----------------------------------------------------------------------

static func hot_spring(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var hx := w * 0.5
	var hz := d * 0.5
	var pc := Vector3(0, 0, 1.0)
	# The pool outline: a wobbly oval, with a stained shelf ring a little wider.
	var inner := PackedVector2Array()
	var stain := PackedVector2Array()
	var rim: Array[Vector3] = []
	var n := 16
	for i in n:
		var a := TAU * i / n
		var k := rng.randf_range(0.88, 1.1)
		var dir := Vector2(cos(a) * 3.7, sin(a) * 2.7) * k
		inner.append(Vector2(pc.x + dir.x, pc.z + dir.y))
		stain.append(Vector2(pc.x + dir.x * 1.4, pc.z + dir.y * 1.4))
		rim.append(Vector3(pc.x + dir.x * 1.08, 0, pc.z + dir.y * 1.08))
	mb.flat(stain, 0.03, ORANGE.lerp(WHITE, 0.45).darkened(0.05))
	mb.flat(inner, 0.05, _g(MILK, MeshBuilder.GLOSS))
	# A raised rim of mineral-stained rocks round the water.
	var tints := [ROCK_WARM, ORANGE.lerp(ROCK, 0.6), WHITE.lerp(ROCK, 0.35), RUST.lerp(ROCK, 0.5), CREAM.lerp(ROCK, 0.4)]
	for i in n:
		var r := Vector3(rng.randf_range(0.8, 1.2), rng.randf_range(0.3, 0.85), rng.randf_range(0.65, 0.95))
		var col := _vary(tints[rng.randi() % tints.size()], rng, 0.08)
		_boulder(mb, out, rim[i], r, col, rng, 5)
	# Mineral shelves: stacked terraces, orange to white.
	var shelf_cols := [ORANGE.lerp(WHITE, 0.2), ORANGE.lerp(CREAM, 0.55), CREAM.lerp(ORANGE, 0.2), CREAM]
	for t in 2:
		var base := Vector3(-4.7 + t * 9.4, 0, 4.1 + t * 0.6)
		var rr := 2.3 - t * 0.35
		for k in 3:
			_frustum(mb, base + Vector3(0, k * 0.2, 0), rr * (1.0 - 0.2 * k), rr * (1.0 - 0.2 * k) * 0.95, 0.2, shelf_cols[(k + t) % 4], 10, true)
		_disc(mb, base + Vector3(0.1, 0.62, 0.0), rr * 0.42, _g(MILK.lerp(Color(0.5, 0.85, 0.85), 0.5), MeshBuilder.GLOSS), 8)
	# Stepping stones from the road, a bench with a folded towel, a bucket, a sign.
	for k in 5:
		_disc_xz(mb, Vector3(0.3 * sin(k * 1.3), 0.04, -hz + 1.0 + k * 0.85), 0.5, 0.42, ROCK_WARM.lightened(0.1), 7)
	var bp := Vector3(5.4, 0, -3.4)
	var saved := _push(mb, bp, 0.35)
	mb.box(Vector3(0, 0.45, 0), Vector3(1.7, 0.08, 0.5), PINE)
	mb.box(Vector3(0, 0.78, 0.22), Vector3(1.7, 0.4, 0.07), PINE.darkened(0.1))
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(s * 0.7, 0.225, 0), Vector3(0.1, 0.45, 0.4), TIMBER_DK)
	mb.box(Vector3(-0.4, 0.55, 0), Vector3(0.5, 0.12, 0.35), WHITE)
	mb.xform = saved
	Kit._col(out, bp + Vector3(0, 0.45, 0), Vector3(1.8, 0.9, 0.7), 0.35)
	mb.cylinder(Vector3(3.4, 0.0, -2.4), 0.25, 0.4, TIMBER, 6)
	_board(mb, out, Vector3(-5.0, 0, -5.4), Vector2(1.4, 0.9), 0.9, Color(0.25, 0.5, 0.85), rng)
	_tufts(mb, Vector3.ZERO, hx - 1.0, hz - 1.0, 8, rng, [Vector3(0, 0, 1.0)], 5.0)


# --- Cold spring ---------------------------------------------------------------------

static func cold_spring(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var hx := w * 0.5
	var hz := d * 0.5
	var clear := WATER.lightened(0.2)
	_disc_xz(mb, Vector3(0, 0.03, 0.4), 3.7, 2.6, MOSS.darkened(0.2), 20)
	_disc_xz(mb, Vector3(0, 0.05, 0.4), 3.2, 2.2, _g(clear, MeshBuilder.GLOSS), 20)
	# A pile of mossy rocks at the back with the spout in the middle.
	var pile: Array = [
		[Vector3(0, 0, 3.4), Vector3(1.5, 2.5, 1.1)], [Vector3(-1.9, 0, 3.2), Vector3(1.1, 1.7, 1.0)],
		[Vector3(1.9, 0, 3.3), Vector3(1.2, 1.9, 1.0)], [Vector3(-3.4, 0, 3.0), Vector3(1.0, 1.0, 0.9)],
		[Vector3(3.5, 0, 3.1), Vector3(0.9, 0.9, 0.9)], [Vector3(-0.9, 0, 2.6), Vector3(0.8, 1.1, 0.7)],
		[Vector3(1.0, 0, 2.6), Vector3(0.7, 0.8, 0.6)],
	]
	for item: Array in pile:
		var col := ROCK.lerp(MOSS, rng.randf_range(0.15, 0.4))
		_boulder(mb, out, item[0], item[1], _vary(col, rng, 0.08), rng, 6)
	mb.limb(Vector3(0, 1.45, 3.0), Vector3(0, 1.3, 1.45), 0.1, 0.1, STEEL, 6, true)
	_strap(mb, Vector3(0, 1.25, 1.45), Vector3(0, 0.45, 1.45), 0.13, Vector3(0, 0, -1), clear.lightened(0.15))
	# The stone basin under it: eight blocks round clear water.
	for i in 8:
		var a := TAU * i / 8.0
		var bp := Vector3(cos(a) * 1.0, 0.0, 1.45 + sin(a) * 1.0)
		_rbox(mb, bp + Vector3(0, 0.28, 0), Vector3(0.95, 0.56, 0.48), -a + PI * 0.5, _vary(ROCK, rng, 0.08))
	_disc(mb, Vector3(0, 0.4, 1.45), 0.82, _g(clear, MeshBuilder.GLOSS), 10)
	# Pebbles round the pool, planks to the road, ferns, a sign.
	for i in 14:
		var a := TAU * i / 14.0 + rng.randf_range(-0.1, 0.1)
		_rock(mb, Vector3(cos(a) * 3.4, 0, 0.4 + sin(a) * 2.4), Vector3(rng.randf_range(0.14, 0.3), rng.randf_range(0.1, 0.22), rng.randf_range(0.14, 0.3)), _vary(ROCK, rng, 0.1), rng, 4)
	for k in 3:
		_bx(mb, -0.6, 0.6, 0.0, 0.07, -hz + 0.5 + k * 0.5, -hz + 0.5 + k * 0.5 + 0.4, PINE.darkened(0.2))
	_board(mb, out, Vector3(-3.6, 0, -3.2), Vector2(1.2, 0.8), 0.9, Color(0.25, 0.62, 0.45), rng)
	for i in 8:
		var a := TAU * i / 8.0 + 0.3
		var fp := Vector3(cos(a) * 4.6, 0, 0.8 + sin(a) * 3.2)
		if absf(fp.x) < hx - 0.6 and absf(fp.z) < hz - 0.6:
			for k in 4:
				var da := TAU * k / 4.0
				Kit._cone(mb, fp + Vector3(cos(da), 0, sin(da)) * 0.15, 0.14, rng.randf_range(0.5, 0.9), LEAF.lightened(0.1), 4)


# --- Mountain hotel ---------------------------------------------------------------------

## A sun lounger on the terrace deck at p (y is the deck), head toward +Z before yaw.
static func _lounger(mb, p: Vector3, yaw: float, color: Color) -> void:
	var saved := _push(mb, p, yaw)
	mb.box(Vector3(0, 0.3, 0.2), Vector3(0.8, 0.12, 1.4), color)
	mb.box(Vector3(-0.3, 0.14, 0.2), Vector3(0.08, 0.28, 1.3), STEEL_DK)
	mb.box(Vector3(0.3, 0.14, 0.2), Vector3(0.08, 0.28, 1.3), STEEL_DK)
	var tilt := Transform3D(Basis(Vector3.RIGHT, -0.7), Vector3(0, 0.52, 1.05))
	mb.xform = mb.xform * tilt
	mb.box(Vector3.ZERO, Vector3(0.8, 0.1, 0.8), color, false)
	mb.xform = saved


## A parasol over a round table with four chairs, on a deck at p.
static func _parasol_set(mb, p: Vector3, color: Color) -> void:
	mb.cylinder(p, 0.5, 0.72, WHITE, 6)
	mb.cylinder(p + Vector3(0, 0.72, 0), 0.04, 1.8, STEEL, 4)
	Kit._cone(mb, p + Vector3(0, 2.2, 0), 1.8, 0.55, color, 8)
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		mb.box(p + Vector3(cos(a), 0.4, sin(a)) * Vector3(1.0, 1.0, 1.0), Vector3(0.42, 0.08, 0.42), color.darkened(0.2))
		mb.box(p + Vector3(cos(a) * 1.0, 0.18, sin(a) * 1.0), Vector3(0.1, 0.36, 0.1), STEEL_DK)


## A garden lamp post: a slim post with a glowing globe.
static func _lamp(mb, out: Array, p: Vector3, h := 3.2) -> void:
	mb.cylinder(p, 0.08, h, IRON, 4)
	mb.ball(p + Vector3(0, h + 0.2, 0), Vector3(0.22, 0.22, 0.22), _g(Color(1.0, 0.92, 0.7), MeshBuilder.GLOW_LAMP), 6, 2)
	out.append([p + Vector3(0, h * 0.5, 0), Vector3(0.3, h, 0.3)])


static func mountain_hotel(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var hx := w * 0.5
	var hz := d * 0.5
	var stone := _g(Color(0.55, 0.51, 0.46), MeshBuilder.BRICK)
	var glass := _g(Color(0.5, 0.65, 0.74), MeshBuilder.GLASS)
	var lit := _g(Color(1.0, 0.86, 0.55), MeshBuilder.GLOW_WINDOW)
	var deck_c := Color(0.6, 0.46, 0.33)
	# --- The drive loop in front, an island in it, the road apron.
	Kit._pad(mb, -2.5, 2.5, -hz, -hz + 2.0, Color(0.3, 0.3, 0.32), 0.015)
	_oval(mb, Vector3(0, 0.03, -13.0), 9.0, 3.2, 14.0, 7.5, Color(0.3, 0.3, 0.32), 28)
	_disc_xz(mb, Vector3(0, 0.04, -13.0), 8.6, 2.8, _g(LEAF.darkened(0.1), MeshBuilder.GRASS), 20)
	for k in 4:
		_boulder(mb, out, Vector3(-4.5 + k * 3.0, 0, -13.0 + (k % 2) * 0.8 - 0.4), Vector3(rng.randf_range(0.5, 0.9), rng.randf_range(0.7, 1.3), rng.randf_range(0.5, 0.8)), _vary(ROCK, rng, 0.1), rng, 5)
	_pine(mb, out, Vector3(-6.2, 0, -13.0), 5.5, rng)
	_pine(mb, out, Vector3(6.2, 0, -13.0), 5.0, rng)
	# --- Stone base storey with the entrance, windows and planters.
	_sx(mb, out, -22.0, 22.0, 0.0, 4.5, -5.0, 9.0, stone)
	_bx(mb, -22.3, 22.3, 4.5, 4.75, -5.3, 9.3, Color(0.46, 0.46, 0.44))
	_fz(mb, -3.0, 3.0, 0.0, 3.4, -5.03, glass)
	_bx(mb, -3.2, -3.0, 0.0, 3.5, -5.1, -4.95, IRON)
	_bx(mb, 3.0, 3.2, 0.0, 3.5, -5.1, -4.95, IRON)
	_bx(mb, -3.2, 3.2, 3.4, 3.6, -5.1, -4.95, IRON)
	for i in 8:
		var x := (-19.0 + i * 5.4) if i < 4 else (-19.0 + (i + 1) * 5.4 - 2.0)
		if absf(x) < 5.0:
			continue
		var pane := lit if rng.randf() < 0.4 else glass
		_fz(mb, x - 1.3, x + 1.3, 1.1, 3.5, -5.03, pane)
		_bx(mb, x - 1.4, x + 1.4, 0.95, 1.1, -5.12, -5.0, stone.darkened(0.25))
	_bx(mb, -9.0, 9.0, 0.0, 0.18, -8.0, -5.0, Color(0.55, 0.55, 0.53))
	_bx(mb, -9.0, 9.0, 0.0, 0.1, -9.0, -8.0, CONCRETE)
	for s: float in [-1.0, 1.0]:
		_sx(mb, out, s * 7.2 - 0.6, s * 7.2 + 0.6, 0.0, 0.8, -6.0, -5.2, stone)
		mb.ball(Vector3(s * 7.2, 1.15, -5.6), Vector3(0.6, 0.45, 0.4), _g(LEAF, MeshBuilder.GRASS), 6, 2)
	# --- Porte-cochere: a flat canopy on stone piers over the drive.
	mb.box(Vector3(0, 4.45, -8.1), Vector3(14.0, 0.5, 6.2), Color(0.6, 0.6, 0.58))
	mb.box(Vector3(0, 4.72, -8.1), Vector3(13.4, 0.06, 5.6), _g(Color(0.2, 0.22, 0.24), MeshBuilder.ROOF))
	for s: float in [-1.0, 1.0]:
		_sx(mb, out, s * 6.4 - 0.4, s * 6.4 + 0.4, 0.0, 4.2, -11.4, -10.6, stone)
	mb.box(Vector3(0, 3.9, -11.1), Vector3(12.4, 0.12, 0.12), _g(Color(1.0, 0.9, 0.65), MeshBuilder.GLOW_LAMP))
	# --- Two timber-and-glass storeys, a central glass tower and the roof.
	_sx(mb, out, -19.0, 19.0, 4.75, 12.0, -3.0, 9.0, _g(TIMBER, MeshBuilder.SIDING))
	for row in 2:
		for i in 8:
			var x := -17.5 + i * 5.0
			if absf(x) < 7.0 and row == 0:
				continue
			var y0 := 5.2 + row * 3.6
			_fz(mb, x - 2.0, x + 2.0, y0, y0 + 2.9, -3.03, lit if rng.randf() < 0.35 else glass)
			_fz(mb, x - 2.0, x + 2.0, y0, y0 + 2.9, 9.03, lit if rng.randf() < 0.3 else glass, 1.0)
	for i in 10:
		_bx(mb, -20.5 + i * 4.55 - 0.18, -20.5 + i * 4.55 + 0.18, 4.75, 12.0, -3.35, -3.0, TIMBER_DK)
	for s: float in [-1.0, 1.0]:
		for row in 2:
			for k in 2:
				_fx(mb, 1.0 + k * 4.4, 4.4 + k * 4.4, 5.2 + row * 3.6, 8.0 + row * 3.6, s * 19.03, glass, s)
	_sx(mb, out, -7.0, 7.0, 12.0, 15.6, -3.5, 3.5, _g(TIMBER_DK, MeshBuilder.SIDING))
	_fz(mb, -6.4, 6.4, 12.4, 15.2, -3.53, glass)
	for i in 5:
		_bx(mb, -6.0 + i * 3.0 - 0.15, -6.0 + i * 3.0 + 0.15, 12.0, 15.6, -3.65, -3.5, TIMBER)
	mb.box(Vector3(0, 15.85, 0), Vector3(15.0, 0.5, 8.4), CONCRETE_DK)
	for s: float in [-1.0, 1.0]:
		var wing_x := s * 13.0
		Kit._gable(mb, wing_x, 3.0, 12.0, 14.4, 16.4, 2.6, _g(Color(0.24, 0.27, 0.3), MeshBuilder.SEAM_ROOF), TIMBER_DK)
	_bx(mb, -6.0, 6.0, 12.0, 14.2, 3.4, 8.4, _g(Color(0.24, 0.27, 0.3), MeshBuilder.SEAM_ROOF))
	_bx(mb, 11.4, 13.2, 12.0, 15.6, 2.0, 3.8, stone)
	# --- The cantilevered terrace: deck strips round the infinity pool, glass rails, braces.
	var deck := deck_c
	_bx(mb, -20.0, 20.0, 4.05, 4.5, 9.0, 14.0, deck)
	_bx(mb, -20.0, -12.0, 4.05, 4.5, 14.0, 20.5, deck)
	_bx(mb, 12.0, 20.0, 4.05, 4.5, 14.0, 20.5, deck)
	_bx(mb, -12.0, 12.0, 3.7, 4.2, 14.0, 19.5, Color(0.5, 0.82, 0.84))
	_fy(mb, -11.9, 11.9, 14.1, 19.5, 4.42, _g(WATER.lightened(0.1), MeshBuilder.GLOSS))
	_bx(mb, -12.0, 12.0, 3.6, 4.2, 19.5, 20.4, STEEL_DK)
	_fy(mb, -12.0, 12.0, 19.5, 20.4, 4.3, WATER.darkened(0.25))
	# A stone undercroft carries the terrace (hill lots sit on a level pad,
	# so open braces would leave it hanging 4 m over flat ground).
	_sx(mb, out, -20.0, 20.0, 0.0, 4.05, 9.0, 20.4, stone)
	for x: float in [-15.0, -5.0, 5.0, 15.0]:
		_fz(mb, x - 1.6, x + 1.6, 0.0, 2.6, 20.43, TIMBER_DK, 1.0)
	var saved := _push(mb, Vector3(0, 4.5, 0), 0.0)
	_railing(mb, [], Vector3(-20.0, 0, 9.2), Vector3(-20.0, 0, 20.4), 1.1, STEEL, 3.0, false, true)
	_railing(mb, [], Vector3(20.0, 0, 9.2), Vector3(20.0, 0, 20.4), 1.1, STEEL, 3.0, false, true)
	_railing(mb, [], Vector3(-20.0, 0, 20.4), Vector3(-12.0, 0, 20.4), 1.1, STEEL, 3.0, false, true)
	_railing(mb, [], Vector3(12.0, 0, 20.4), Vector3(20.0, 0, 20.4), 1.1, STEEL, 3.0, false, true)
	_railing(mb, [], Vector3(-12.0, 0, 20.5), Vector3(12.0, 0, 20.5), 1.0, STEEL, 4.0, false, true)
	for x: float in [-15.0, -8.0, 8.0, 15.0]:
		_parasol_set(mb, Vector3(x, 0, 11.6), _pick([Color(0.85, 0.82, 0.74), Color(0.62, 0.2, 0.18), Color(0.2, 0.35, 0.3)], rng))
	for k in 3:
		_lounger(mb, Vector3(-17.0 + k * 1.3, 0, 15.5), PI, WHITE)
		_lounger(mb, Vector3(17.0 - k * 1.3, 0, 15.5), PI, WHITE)
	mb.xform = saved
	# --- Parking for a few cars, a connecting lane, lamps and flags.
	Kit._pad(mb, 13.0, 16.0, -15.5, -11.5, Color(0.3, 0.3, 0.32), 0.015)
	Kit._pad(mb, 15.5, 28.5, -20.0, -8.5, Color(0.3, 0.3, 0.32), 0.015)
	for i in 5:
		Kit._line(mb, Vector3(16.5 + i * 3.0, 0, -19.5), Vector3(16.5 + i * 3.0, 0, -14.5), 0.12)
		Kit._line(mb, Vector3(16.5 + i * 3.0, 0, -14.0), Vector3(16.5 + i * 3.0, 0, -9.0), 0.12)
	var cols := [Color(0.1, 0.1, 0.12), Color(0.82, 0.82, 0.8), Color(0.3, 0.32, 0.38), Color(0.45, 0.1, 0.12)]
	for i in 4:
		Kit._car(mb, out, Vector3(18.0 + i * 3.0, 0, -17.0), PI + rng.randf_range(-0.04, 0.04), cols[i], true, Kit.CAR_LUXURY if i == 0 else Kit.CAR_SEDAN)
	for i in 2:
		Kit._car(mb, out, Vector3(21.0 + i * 6.0, 0, -11.2), rng.randf_range(-0.04, 0.04), cols[(i + 2) % 4])
	for k in 6:
		var a := TAU * (k + 0.5) / 6.0
		_lamp(mb, out, Vector3(cos(a) * 14.8, 0, -13.0 + sin(a) * 8.3), 3.2)
	Kit._flagpole(mb, out, Vector3(-11.0, 0, -8.5), 8.5, [Color(0.15, 0.25, 0.4), Color(0.9, 0.85, 0.7)])
	Kit._flagpole(mb, out, Vector3(11.0, 0, -8.5), 8.5, [Color(0.5, 0.15, 0.15), Color(0.9, 0.85, 0.7)])
	_board(mb, out, Vector3(-21.0, 0, -18.5), Vector2(3.6, 1.8), 1.6, Color(0.15, 0.2, 0.3), rng)
	for i in 14:
		var side := 1.0 if i % 2 == 0 else -1.0
		var z := -14.0 + (i / 2) * 5.5
		var x := side * (26.0 + rng.randf_range(-0.5, 0.8))
		if side > 0.0 and z < -7.0:
			continue
		_pine(mb, out, Vector3(clampf(x, -hx + 3.5, hx - 3.5), 0, clampf(z, -hz + 3.5, hz - 3.5)), rng.randf_range(7.0, 11.0), rng)


# --- Lodge hotel ----------------------------------------------------------------------------

## A wooden porch chair at p (y = the deck), facing -Z before yaw.
static func _chair(mb, p: Vector3, yaw: float, color: Color) -> void:
	var saved := _push(mb, p, yaw)
	mb.box(Vector3(0, 0.42, 0), Vector3(0.55, 0.08, 0.52), color)
	mb.box(Vector3(0, 0.78, 0.25), Vector3(0.55, 0.7, 0.07), color)
	mb.box(Vector3(-0.27, 0.6, 0), Vector3(0.07, 0.07, 0.5), color.darkened(0.15))
	mb.box(Vector3(0.27, 0.6, 0), Vector3(0.07, 0.07, 0.5), color.darkened(0.15))
	mb.box(Vector3(0, 0.2, 0.05), Vector3(0.5, 0.4, 0.4), TIMBER_DK)
	mb.xform = saved


## A dormer on a front roof slope: a small box with a window and its own little gable.
static func _dormer(mb, x: float, y: float, z: float, roof: Color, wall: Color) -> void:
	mb.box(Vector3(x, y + 1.1, z), Vector3(2.0, 2.2, 2.4), wall)
	_fz(mb, x - 0.7, x + 0.7, y + 0.5, y + 1.8, z - 1.23, _g(GLASS_C.lightened(0.15), MeshBuilder.GLASS))
	_bx(mb, x - 0.85, x + 0.85, y + 0.4, y + 0.5, z - 1.3, z - 1.2, TIMBER_DK)
	Kit._gable(mb, x, z, y + 2.2, 2.6, 2.8, 1.0, roof, wall.darkened(0.15), true)


static func lodge_hotel(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var hx := w * 0.5
	var hz := d * 0.5
	var log_c := _g(LOG, MeshBuilder.SIDING)
	var shingle := _g(SHINGLE, MeshBuilder.ROOF)
	var stone := _g(Color(0.5, 0.47, 0.43), MeshBuilder.BRICK)
	# --- Gravel yard in front, a path to the porch steps.
	Kit._pad(mb, -20.0, 20.0, -hz + 0.5, -9.2, GRAVEL, 0.015)
	_strap(mb, Vector3(0, 0.03, -9.2), Vector3(0, 0.03, -8.3), 3.2, Vector3.UP, GRAVEL.lightened(0.1))
	# --- The main two-storey log block with its steep shingle roof.
	_sx(mb, out, -15.0, 15.0, 0.0, 5.0, -3.0, 8.0, log_c)
	for k in 9:
		_fz(mb, -15.0, 15.0, 0.45 + k * 0.5, 0.52 + k * 0.5, -3.02, BARK)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-3.0, 8.0]:
			for k in 6:
				mb.box(Vector3(sx * 15.0, 0.4 + k * 0.85, sz), Vector3(0.45, 0.32, 0.45), LOG_END.darkened(0.12 * (k % 2)))
	Kit._gable(mb, 0.0, 2.5, 5.0, 31.6, 13.2, 5.2, shingle, LOG.darkened(0.15))
	mb.box(Vector3(0, 10.25, 2.5), Vector3(31.8, 0.18, 0.3), LOG.darkened(0.3))
	# Dormers along the front slope, windows on both floors.
	for x: float in [-11.5, -7.0, 7.0, 11.5]:
		_dormer(mb, x, 5.9, -2.4, shingle, LOG)
	for i in 8:
		var x := -12.5 + i * 3.6
		if absf(x) < 4.5:
			continue
		_fz(mb, x - 0.6, x + 0.6, 1.2, 2.5, -3.04, _g(Color(1.0, 0.85, 0.55), MeshBuilder.GLOW_WINDOW) if rng.randf() < 0.45 else _g(GLASS_C, MeshBuilder.GLASS))
		_bx(mb, x - 0.8, x + 0.8, 1.05, 1.2, -3.12, -3.0, TIMBER_DK)
		_fz(mb, x - 0.6, x + 0.6, 3.3, 4.5, -3.04, _g(Color(1.0, 0.85, 0.55), MeshBuilder.GLOW_WINDOW) if rng.randf() < 0.35 else _g(GLASS_C, MeshBuilder.GLASS))
	# --- The entry pavilion: a cross gable on two big log columns.
	_fz(mb, -2.2, 2.2, 0.0, 3.2, -3.04, TIMBER_DK)
	_fz(mb, -1.9, 1.9, 0.1, 3.1, -3.06, _g(GLASS_C.lightened(0.1), MeshBuilder.GLASS))
	Kit._gable(mb, 0.0, -2.5, 5.0, 10.6, 10.8, 4.4, shingle, LOG.darkened(0.1), true)
	_fz(mb, -2.6, 2.6, 5.6, 8.4, -7.92, _g(Color(1.0, 0.85, 0.55), MeshBuilder.GLOW_WINDOW))
	for s: float in [-1.0, 1.0]:
		var cp := Vector3(s * 4.8, 0, -7.4)
		mb.cylinder(cp, 0.38, 5.4, LOG, 7)
		out.append([cp + Vector3(0, 2.7, 0), Vector3(0.8, 5.4, 0.8)])
	# --- The long porch: deck, steps, shed roofs, log posts, chairs, rail.
	_bx(mb, -14.8, 14.8, 0.0, 0.35, -7.4, -3.0, PINE.darkened(0.15))
	_bx(mb, -3.0, 3.0, 0.0, 0.17, -8.4, -7.4, PINE.darkened(0.25))
	for s: float in [-1.0, 1.0]:
		var cx := s * 9.8
		_slope(mb, Vector3(cx, 3.4, -7.9), Vector3(cx, 4.6, -3.0), 9.8, Vector3.RIGHT, shingle, 0.15)
		_bx(mb, cx - 4.9, cx + 4.9, 3.15, 3.5, -7.95, -7.75, LOG)
		for k in 3:
			var px := s * (6.8 + k * 3.6)
			mb.cylinder(Vector3(px, 0.35, -7.7), 0.17, 3.1, LOG, 6)
			out.append([Vector3(px, 1.9, -7.7), Vector3(0.4, 3.1, 0.4)])
		_railing(mb, [], Vector3(s * 5.8, 0.35, -7.2), Vector3(s * 14.5, 0.35, -7.2), 1.0, LOG.lightened(0.1), 3.6, false, false)
	for i in 6:
		var x := (-13.0 + i * 2.4) if i < 3 else (7.0 + (i - 3) * 2.4)
		_chair(mb, Vector3(x, 0.35, -5.4 + rng.randf_range(-0.3, 0.3)), rng.randf_range(-0.25, 0.25), _pick([PINE, Color(0.55, 0.16, 0.14), Color(0.2, 0.38, 0.3), TIMBER_LT], rng))
	mb.box(Vector3(-8.0, 0.6, -3.7), Vector3(2.4, 0.08, 0.6), PINE)
	mb.box(Vector3(10.5, 0.55, -3.7), Vector3(0.8, 0.5, 0.8), TIMBER)
	# --- The stone chimney and a woodpile.
	_sx(mb, out, 15.2, 17.6, 0.0, 9.0, 1.0, 3.4, stone)
	_bx(mb, 15.5, 17.3, 9.0, 12.4, 1.3, 3.1, stone.darkened(0.08))
	_bx(mb, 15.3, 17.5, 12.4, 12.7, 1.1, 3.3, stone.darkened(0.3))
	_log_stack(mb, out, Vector3(19.0, 0, 5.0), 0.0, 3.2, 4, 0.22, rng, 3)
	# --- Three guest cabins across the back.
	for x: float in [-14.0, 0.0, 14.0]:
		_cabin(mb, out, Vector3(x, 0, 12.2), 0.0, 6.0, 5.0, 2.8, 1.8, LOG, SHINGLE, rng, 2, false, true)
	Kit._pad(mb, -16.0, 16.0, 9.0, 9.9, GRAVEL.darkened(0.1), 0.015)
	# --- Cars in the yard, lamps, a flag and the sign.
	var paints := [Color(0.2, 0.3, 0.45), Color(0.7, 0.68, 0.62), Color(0.35, 0.45, 0.35), Color(0.55, 0.15, 0.15)]
	for i in 4:
		Kit._car(mb, out, Vector3(-14.0 + i * 5.5, 0, -12.8 + rng.randf_range(-0.6, 0.6)), PI + rng.randf_range(-0.3, 0.3), paints[i])
	Kit._pickup(mb, out, Vector3(15.0, 0, -12.6), PI + 0.15, Color(0.35, 0.3, 0.2))
	for x: float in [-16.5, 16.5, -2.5, 2.5]:
		_lamp(mb, out, Vector3(x, 0, -9.0), 2.8)
	Kit._flagpole(mb, out, Vector3(-17.5, 0, -7.0), 7.5, [Color(0.18, 0.4, 0.28), Color(0.9, 0.82, 0.6)])
	_board(mb, out, Vector3(16.0, 0, -15.0), Vector2(3.2, 1.7), 1.4, Color(0.25, 0.4, 0.28), rng)
	for i in 10:
		var side := 1.0 if i % 2 == 0 else -1.0
		var z := -8.0 + (i / 2) * 6.0
		var ph := rng.randf_range(7.0, 10.0)
		var px := minf(hx - 2.8 + rng.randf_range(-0.4, 0.3), hx - ph * 0.3 - 0.3)
		_pine(mb, out, Vector3(side * px, 0, clampf(z, -hz + 3.0, hz - 3.0)), ph, rng)


# --- Rave clearing ---------------------------------------------------------------

## A horizontal truss along X from x0 to x1, centred at height y on the plane z:
## two chords and a zigzag of straps on the -Z face.
static func _truss_x(mb, x0: float, x1: float, y: float, z: float, h: float, bay: float) -> void:
	var tc := _g(STEEL, MeshBuilder.METAL)
	var n := maxi(2, roundi(absf(x1 - x0) / bay))
	_bx(mb, x0, x1, y - h * 0.5 - 0.06, y - h * 0.5 + 0.06, z - 0.25, z + 0.25, tc)
	_bx(mb, x0, x1, y + h * 0.5 - 0.06, y + h * 0.5 + 0.06, z - 0.25, z + 0.25, tc)
	for i in n:
		var xa := lerpf(x0, x1, float(i) / n)
		var xb := lerpf(x0, x1, float(i + 1) / n)
		var up := i % 2 == 0
		var ya := y - h * 0.5 if up else y + h * 0.5
		var yb := y + h * 0.5 if up else y - h * 0.5
		_strap(mb, Vector3(xa, ya, z - 0.26), Vector3(xb, yb, z - 0.26), 0.07, Vector3(0, 0, -1), tc)


## A vertical truss column: four corner chords, zigzag straps on the -Z face and
## on the X face turned to `out_x`.
static func _truss_col(mb, x: float, z: float, y0: float, y1: float, w := 0.5, out_x := 1.0) -> void:
	var tc := _g(STEEL, MeshBuilder.METAL)
	var hw := w * 0.5
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_bx(mb, x + sx * hw - 0.06, x + sx * hw + 0.06, y0, y1, z + sz * hw - 0.06, z + sz * hw + 0.06, tc)
	var n := maxi(2, roundi((y1 - y0) / 0.9))
	for i in n:
		var ya := lerpf(y0, y1, float(i) / n) + (0.06 if i == 0 else 0.0)
		var yb := lerpf(y0, y1, float(i + 1) / n)
		var flip := i % 2 == 0
		_strap(mb, Vector3(x - hw if flip else x + hw, ya, z - hw - 0.07), Vector3(x + hw if flip else x - hw, yb, z - hw - 0.07), 0.07, Vector3(0, 0, -1), tc)
		var xf := x + out_x * (hw + 0.07)
		_strap(mb, Vector3(xf, ya, z - hw if flip else z + hw), Vector3(xf, yb, z + hw if flip else z - hw), 0.07, Vector3(out_x, 0, 0), tc)


## A stage light head hanging with its lens facing down; the lens glows.
static func _par(mb, p: Vector3, color: Color) -> void:
	mb.box(p, Vector3(0.34, 0.34, 0.34), STEEL_DK)
	mb.box(p + Vector3(0, -0.19, 0), Vector3(0.26, 0.05, 0.26), _g(color, MeshBuilder.GLOW_NEON))


## A string of bunting from a to b, sagging by `sag`, with `n` pennants.
static func _bunting(mb, a: Vector3, b: Vector3, sag: float, n: int, rng: RandomNumberGenerator) -> void:
	var dv := b - a
	var side := Vector3(-dv.z, 0.0, dv.x).normalized()
	var prev := a
	for i in range(1, n + 1):
		var t := float(i) / n
		var p := a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0)
		_strap(mb, prev, p, 0.05, Vector3.UP, BLACK)
		if i < n:
			var along := (p - prev).normalized() * 0.2
			var col: Color = NEONS[rng.randi() % NEONS.size()]
			var tip := p + Vector3(0, -0.45, 0)
			mb.tri(p - along, p + along, tip, side, col)
			mb.tri(p - along, p + along, tip, -side, col)
		prev = p


## A speaker stack of three cabinets facing -Z, one collider.
static func _speaker_stack(mb, out: Array, x: float, z: float, trim: Color) -> void:
	var cab := _g(Color(0.1, 0.1, 0.12), MeshBuilder.GLOSS)
	var tiers := [[1.9, 1.1, 1.5, 0.44], [1.6, 1.0, 1.3, 0.36], [1.4, 0.9, 1.1, 0.3]]
	var y := 0.0
	for t: Array in tiers:
		var tw: float = t[0]
		var th: float = t[1]
		var td: float = t[2]
		mb.box(Vector3(x, y + th * 0.5, z), Vector3(tw, th, td), cab)
		_vdisc(mb, Vector3(x, y + th * 0.5, z - td * 0.5 - 0.02), t[3], BLACK, 10)
		_fz(mb, x - tw * 0.5 + 0.12, x + tw * 0.5 - 0.12, y + th - 0.2, y + th - 0.1, z - td * 0.5 - 0.02, trim)
		y += th
	mb.box(Vector3(x, y + 0.2, z), Vector3(1.2, 0.4, 0.8), STEEL_DK)
	out.append([Vector3(x, y * 0.5, z), Vector3(1.9, y, 1.5)])


## The generator trailer: a bed, a yellow generator housing, wheels and a tongue; nose to -Z.
static func _gen_trailer(mb, out: Array, p: Vector3, yaw: float) -> void:
	var saved := _push(mb, p, yaw)
	mb.box(Vector3(0, 0.85, 0), Vector3(2.0, 0.22, 4.4), STEEL_DK)
	mb.box(Vector3(0, 1.71, 0.5), Vector3(1.85, 1.5, 2.9), _g(YELLOW, MeshBuilder.GLOSS))
	_fz(mb, -0.7, 0.7, 1.2, 2.2, -0.97, Color(0.15, 0.15, 0.17))
	mb.box(Vector3(0.5, 0.98, -1.55), Vector3(0.8, 0.55, 0.9), RUST_DK)
	mb.cylinder(Vector3(-0.6, 2.46, 1.3), 0.09, 0.9, STEEL_DK, 5)
	Kit._beam(mb, Vector3(0, 0.8, -2.2), Vector3(0, 0.62, -3.5), 0.14, STEEL_DK)
	mb.cylinder(Vector3(0, 0.0, -3.35), 0.06, 0.62, STEEL_DK, 4)
	for s: float in [-1.0, 1.0]:
		mb.limb(Vector3(s * 1.0, 0.54, 0.4), Vector3(s * 1.2, 0.54, 0.4), 0.52, 0.52, BLACK, 8, true)
	mb.xform = saved
	Kit._col(out, p + Vector3(0, 1.3, 0.2), Vector3(2.3, 2.6, 4.4), yaw)


## A portable toilet cabin facing -X: its door on the -X face.
static func _portaloo(mb, out: Array, p: Vector3, color: Color) -> void:
	mb.box(p + Vector3(0, 1.15, 0), Vector3(1.3, 2.3, 1.3), _g(color, MeshBuilder.GLOSS))
	mb.box(p + Vector3(0, 2.34, 0), Vector3(1.4, 0.1, 1.4), Color(0.85, 0.86, 0.85))
	_fx(mb, p.z - 0.4, p.z + 0.4, 0.1, 2.0, p.x - 0.67, color.darkened(0.3), -1.0)
	_fx(mb, p.z - 0.3, p.z + 0.3, 1.5, 1.7, p.x - 0.68, Color(0.9, 0.9, 0.9), -1.0)
	out.append([p + Vector3(0, 1.2, 0), Vector3(1.3, 2.4, 1.3)])


static func rave_clearing(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var tc := _g(STEEL, MeshBuilder.METAL)
	var cloth := Color(0.13, 0.13, 0.16)
	# --- Ground: trampled dirt round the dance floor, a track in from the road.
	_disc_xz(mb, Vector3(0, 0.012, 0.5), 11.5, 9.5, _vary(DIRT.darkened(0.12), rng, 0.04), 24)
	Kit._pad(mb, -2.6, 2.6, -15.0, -4.0, DIRT.darkened(0.05), 0.02)
	# --- The stage: a deck on the back line, a truss frame with a slanted roof.
	_sx(mb, out, -6.8, 6.8, 0.0, 1.2, 6.2, 12.8, Color(0.16, 0.16, 0.19))
	_fz(mb, -6.8, 6.8, 1.0, 1.15, 6.17, _g(NEONS[0], MeshBuilder.GLOW_NEON))
	for sx: float in [-1.0, 1.0]:
		_truss_col(mb, sx * 6.4, 6.9, 1.2, 7.2, 0.5, sx)
		_truss_col(mb, sx * 6.4, 12.2, 1.2, 6.4, 0.5, sx)
		Kit._beam(mb, Vector3(sx * 6.4, 7.0, 6.9), Vector3(sx * 6.4, 6.2, 12.2), 0.32, tc, 0.32)
	_truss_x(mb, -6.4, 6.4, 7.0, 6.9, 0.5, 1.0)
	_truss_x(mb, -6.4, 6.4, 6.2, 12.2, 0.5, 1.0)
	var tilt := atan2(0.8, 5.3)
	var saved := _push(mb, Vector3(0, 7.1, 9.55), 0.0)
	var roof_basis := Basis(Vector3.RIGHT, tilt)
	mb.xform = mb.xform * Transform3D(roof_basis, Vector3.ZERO)
	mb.box(Vector3.ZERO, Vector3(14.6, 0.14, 6.9), cloth, false)
	for i in 5:
		mb.box(Vector3(-5.2 + i * 2.6, 0.09, 0), Vector3(0.5, 0.03, 6.2), _g(NEONS[i % NEONS.size()], MeshBuilder.GLOW_NEON))
	mb.xform = saved
	# --- LED backdrop: a dark frame and bars of changing height (never letters).
	_bx(mb, -6.2, 6.2, 1.3, 6.0, 12.4, 12.6, BLACK)
	for i in 12:
		var bx0 := -5.8 + i * 0.97
		var bh := rng.randf_range(1.2, 4.2)
		_fz(mb, bx0, bx0 + 0.8, 1.5, 1.5 + bh, 12.38, _g(NEONS[i % NEONS.size()], MeshBuilder.GLOW_NEON))
	# --- Lights on the front truss, a disco ball and the DJ table.
	for i in 8:
		_par(mb, Vector3(-5.6 + i * 1.6, 6.5, 6.9), NEONS[i % NEONS.size()])
	mb.cylinder(Vector3(0, 5.65, 9.3), 0.025, 1.4, STEEL_DK, 3)
	mb.ball(Vector3(0, 5.35, 9.3), Vector3(0.5, 0.5, 0.5), _g(Color(0.85, 0.87, 0.9), MeshBuilder.METAL), 8, 4)
	mb.box(Vector3(0, 1.65, 8.9), Vector3(3.4, 0.9, 0.9), Color(0.12, 0.12, 0.15))
	_fz(mb, -1.6, 1.6, 1.35, 1.9, 8.43, _g(NEONS[1], MeshBuilder.GLOW_NEON))
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(s * 1.05, 2.13, 8.9), Vector3(0.85, 0.08, 0.7), BLACK)
		_disc(mb, Vector3(s * 1.05, 2.18, 8.9), 0.3, Color(0.7, 0.72, 0.75), 10)
	mb.box(Vector3(0, 2.14, 8.9), Vector3(0.7, 0.1, 0.6), STEEL_DK)
	mb.box(Vector3(1.9, 2.1, 9.2), Vector3(0.6, 0.04, 0.4), Color(0.7, 0.7, 0.72))
	for s: float in [-2.6, 2.6]:
		mb.box(Vector3(s, 1.45, 7.0), Vector3(0.95, 0.5, 0.65), _g(Color(0.1, 0.1, 0.12), MeshBuilder.GLOSS))
		_vdisc(mb, Vector3(s, 1.45, 6.66), 0.2, BLACK, 8)
	# --- Speaker stacks either side of the stage.
	_speaker_stack(mb, out, -8.6, 8.0, NEONS[2])
	_speaker_stack(mb, out, 8.6, 8.0, NEONS[3])
	# --- Lighting towers at the dance floor's edge, joined by an overhead truss.
	for sx: float in [-1.0, 1.0]:
		var tx := sx * 12.0
		_bx(mb, tx - 0.8, tx + 0.8, 0.0, 0.14, -1.8, -0.2, CONCRETE_DK)
		_truss_col(mb, tx, -1.0, 0.14, 6.0, 0.6, sx)
		out.append([Vector3(tx, 3.0, -1.0), Vector3(0.75, 6.0, 0.75)])
		mb.box(Vector3(tx, 6.2, -1.0), Vector3(1.7, 0.4, 0.8), STEEL_DK)
		for i in 3:
			_par(mb, Vector3(tx - 0.55 + i * 0.55, 5.8, -1.0), NEONS[(i + (0 if sx < 0 else 2)) % NEONS.size()])
	_truss_x(mb, -12.0, 12.0, 6.0, -1.0, 0.5, 1.5)
	for i in 9:
		_par(mb, Vector3(-10.0 + i * 2.5, 5.6, -1.0), NEONS[(i * 2) % NEONS.size()])
	# --- The dance floor: checker tiles under the rig.
	Kit._pad(mb, -4.6, 4.6, 0.8, 5.0, BLACK, 0.015)
	for i in 6:
		for j in 3:
			var col: Color = NEONS[(i + j) % NEONS.size()]
			_fy(mb, -4.5 + i * 1.5 + 0.05, -4.5 + (i + 1) * 1.5 - 0.05, 0.9 + j * 1.35, 0.9 + (j + 1) * 1.35 - 0.1, 0.05, _g(col.darkened(0.2), MeshBuilder.GLOW_NEON))
	# --- Front-of-house desk.
	mb.box(Vector3(0, 0.55, -4.0), Vector3(2.4, 1.1, 1.0), Color(0.15, 0.15, 0.18))
	mb.box(Vector3(0, 1.14, -4.0), Vector3(2.0, 0.08, 0.7), BLACK)
	out.append([Vector3(0, 0.55, -4.0), Vector3(2.4, 1.1, 1.0)])
	for s: float in [-1.0, 1.0]:
		_bx(mb, s * 2.0 - 0.45, s * 2.0 + 0.45, 0.0, 0.8, -4.45, -3.55, Color(0.2, 0.2, 0.22))
	# --- Generator trailer, cables and cable ramps.
	_gen_trailer(mb, out, Vector3(14.3, 0, 8.4), 0.12)
	var cable := Color(0.06, 0.06, 0.07)
	var orange := Color(0.85, 0.4, 0.1)
	Kit._beam(mb, Vector3(13.0, 0.05, 6.1), Vector3(13.0, 0.05, 5.4), 0.06, cable, 0.12)
	Kit._beam(mb, Vector3(13.0, 0.05, 5.4), Vector3(-12.0, 0.05, 5.4), 0.06, cable, 0.12)
	Kit._beam(mb, Vector3(12.9, 0.05, 5.5), Vector3(12.9, 0.05, -0.2), 0.06, orange, 0.1)
	Kit._beam(mb, Vector3(-12.0, 0.05, 5.4), Vector3(-12.0, 0.05, -0.3), 0.06, cable, 0.12)
	Kit._beam(mb, Vector3(-11.9, 0.05, 5.5), Vector3(-6.9, 0.05, 6.9), 0.06, orange, 0.1)
	for rp: Vector3 in [Vector3(12.9, 0.07, 2.6), Vector3(-12.0, 0.07, 2.6), Vector3(0.0, 0.07, 5.4), Vector3(8.5, 0.07, 5.4)]:
		mb.box(rp, Vector3(1.4, 0.14, 0.9), YELLOW)
		mb.box(rp + Vector3(0, 0.005, 0.0), Vector3(0.18, 0.15, 0.92), BLACK)
	# --- Tents and a chill-out rug with hay bales.
	var tents := [[-14.0, -4.5, 0.3, 3.2, 3.6, 2.0], [-14.4, 1.2, -0.2, 3.0, 3.4, 1.9], [-13.4, 6.4, 0.5, 4.0, 4.2, 2.4], [14.8, -4.8, -0.4, 3.2, 3.6, 2.0], [14.9, -8.8, 0.25, 3.0, 3.4, 1.9]]
	for tdef: Array in tents:
		var colr: Color = TENTS[rng.randi() % TENTS.size()]
		_tent(mb, out, Vector3(tdef[0], 0, tdef[1]), tdef[2], tdef[3], tdef[4], tdef[5], colr)
	_fy(mb, 1.2, 5.6, -8.4, -5.2, 0.03, _g(Color(0.7, 0.25, 0.4), MeshBuilder.SIDING))
	_fy(mb, 1.6, 5.2, -8.0, -5.6, 0.035, _g(Color(0.9, 0.7, 0.3), MeshBuilder.SIDING))
	for hb: Array in [[2.0, -8.9, 0.1], [4.6, -8.8, -0.2], [0.7, -6.8, 1.4], [6.2, -6.6, 1.5]]:
		_rbox(mb, Vector3(hb[0], 0.3, hb[1]), Vector3(1.3, 0.6, 0.7), hb[2], SAWDUST.darkened(0.1))
	# --- Bonfire ring with a teepee of logs, a flame and log benches.
	var fc := Vector3(-8.5, 0, -6.5)
	_disc_xz(mb, fc + Vector3(0, 0.03, 0), 1.3, 1.3, Color(0.1, 0.09, 0.09), 10)
	for i in 9:
		var a := TAU * i / 9.0
		_rock(mb, fc + Vector3(cos(a), 0, sin(a)) * 1.7, Vector3(0.38, 0.3, 0.38), _vary(ROCK, rng, 0.12), rng, 5)
	for i in 5:
		var a := TAU * i / 5.0 + 0.3
		_log(mb, fc + Vector3(cos(a) * 0.8, 0.15, sin(a) * 0.8), fc + Vector3(0, 1.25, 0), 0.09, BARK, BARK.lightened(0.15), 5)
	Kit._cone(mb, fc + Vector3(0, 0.15, 0), 0.55, 1.2, _g(ORANGE, MeshBuilder.GLOW_LAMP), 6)
	Kit._cone(mb, fc + Vector3(0, 0.15, 0), 0.3, 1.5, _g(Color(1.0, 0.85, 0.3), MeshBuilder.GLOW_LAMP), 5)
	out.append([fc + Vector3(0, 0.45, 0), Vector3(2.6, 0.9, 2.6)])
	for i in 4:
		var a := TAU * i / 4.0 + 0.5
		var cc := fc + Vector3(cos(a), 0, sin(a)) * 3.5 + Vector3(0, 0.28, 0)
		var tang := Vector3(-sin(a), 0, cos(a)) * 1.2
		_log(mb, cc - tang, cc + tang, 0.22, LOG, LOG_END, 6)
	# --- Bar: four posts, a striped roof and a counter.
	var bar := Vector3(-8.5, 0, -12.0)
	for cx: float in [-1.8, 1.8]:
		for cz: float in [-1.3, 1.3]:
			_pole_sq(mb, out, bar + Vector3(cx, 0, cz), 2.6, 0.18, TIMBER_DK)
	for i in 6:
		mb.box(bar + Vector3(-1.9 + 0.6333 * (i + 0.5), 2.7, 0), Vector3(0.6333, 0.08, 3.1), RED if i % 2 == 0 else WHITE)
	mb.box(bar + Vector3(0, 0.55, 1.0), Vector3(3.0, 1.1, 0.7), _g(TIMBER, MeshBuilder.SIDING))
	mb.box(bar + Vector3(0, 1.12, 1.0), Vector3(3.2, 0.06, 0.9), TIMBER_LT)
	out.append([bar + Vector3(0, 0.55, 1.0), Vector3(3.0, 1.1, 0.7)])
	for i in 4:
		mb.box(bar + Vector3(-1.2 + i * 0.8, 1.35, 0.9), Vector3(0.2, 0.4, 0.2), _g(NEONS[i % NEONS.size()], MeshBuilder.GLASS))
	# --- Portable toilets in a row on the east edge.
	for i in 3:
		_portaloo(mb, out, Vector3(16.4, 0, 0.4 + i * 1.5), [Color(0.2, 0.5, 0.75), Color(0.3, 0.6, 0.4), Color(0.2, 0.5, 0.75)][i])
	# --- Entrance arch with a banner of colour bars.
	_truss_col(mb, -3.3, -13.7, 0.0, 4.6, 0.5, -1.0)
	_truss_col(mb, 3.3, -13.7, 0.0, 4.6, 0.5, 1.0)
	_truss_x(mb, -3.3, 3.3, 4.4, -13.7, 0.5, 1.1)
	out.append([Vector3(-3.3, 2.3, -13.7), Vector3(0.7, 4.6, 0.7)])
	out.append([Vector3(3.3, 2.3, -13.7), Vector3(0.7, 4.6, 0.7)])
	_fz(mb, -3.0, 3.0, 2.7, 4.0, -14.05, Color(0.1, 0.1, 0.14))
	for i in 9:
		var bh2 := rng.randf_range(0.5, 1.2)
		_fz(mb, -2.8 + i * 0.64, -2.8 + i * 0.64 + 0.45, 2.8, 2.8 + bh2, -14.07, _g(NEONS[i % NEONS.size()], MeshBuilder.GLOW_NEON))
	# --- Bunting from the towers to the stage.
	_bunting(mb, Vector3(-12.0, 6.3, -1.0), Vector3(-6.4, 7.2, 6.9), 1.0, 12, rng)
	_bunting(mb, Vector3(12.0, 6.3, -1.0), Vector3(6.4, 7.2, 6.9), 1.0, 12, rng)
	# --- Vehicles at the front: a painted van and a few cars, nose out.
	_vehicle(mb, out, Vector3(9.5, 0, -11.8), 0.35, Color(0.85, 0.35, 0.65), 5.0, 2.1, 2.2, 1.0)
	Kit._car(mb, out, Vector3(13.8, 0, -12.4), 3.3 + rng.randf_range(-0.2, 0.2), _pick(CAR_PAINTS, rng))
	Kit._car(mb, out, Vector3(6.0, 0, -12.6), 3.0 + rng.randf_range(-0.2, 0.2), _pick(CAR_PAINTS, rng))
	Kit._pickup(mb, out, Vector3(-14.5, 0, -11.5), 0.2, Color(0.3, 0.3, 0.34))
	# --- Pines round the edge, kept inside the lot.
	for pn: Array in [[-15.5, 12.8, 7.0], [-9.5, 13.3, 6.0], [9.8, 13.3, 6.5], [15.8, 13.0, 6.0], [-16.0, -13.2, 7.0], [-16.3, 9.0, 6.0]]:
		var ph: float = pn[2]
		var pr := ph * 0.3
		_pine(mb, out, Vector3(clampf(pn[0], -17.7 + pr, 17.7 - pr), 0, clampf(pn[1], -14.7 + pr, 14.7 - pr)), ph, rng)


# --- Bungee platform ---------------------------------------------------------------

## A thin cable from a to b (a few sides, no caps).
static func _wire(mb, a: Vector3, b: Vector3, r := 0.025, color := Color(0.1, 0.1, 0.12)) -> void:
	mb.limb(a, b, r, r, color, 3, false)


static func bungee_platform(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var steel := _g(STEEL_DK, MeshBuilder.METAL)
	var steel_lt := _g(STEEL, MeshBuilder.METAL)
	var rail := Color(0.95, 0.78, 0.15)
	# --- Ground: a gravel pad behind the deck and a painted queue line.
	Kit._pad(mb, -5.5, 5.5, -0.6, 4.7, GRAVEL.darkened(0.05), 0.02)
	# --- Footing: two concrete plinths under the deck's back end, three steps up to it.
	for s: float in [-1.0, 1.0]:
		_bx(mb, s * 1.0 - 0.45, s * 1.0 + 0.45, 0.0, 0.46, -0.4, 1.2, CONCRETE_DK)
	_bx(mb, -1.4, 1.4, 0.0, 0.4, 1.2, 1.7, CONCRETE)
	_bx(mb, -1.4, 1.4, 0.0, 0.2, 1.7, 2.2, CONCRETE_LT)
	# --- The cantilever deck: grating slab on two long beams, cross-members and raking braces.
	_bx(mb, -1.4, 1.4, 0.48, 0.6, -4.7, 1.2, steel)
	for i in 12:
		var zs := -4.4 + i * 0.5
		_fy(mb, -1.3, 1.3, zs, zs + 0.2, 0.605, steel_lt)
	for s: float in [-1.0, 1.0]:
		_bx(mb, s * 1.0 - 0.1, s * 1.0 + 0.1, 0.22, 0.48, -4.6, -0.4, steel)
		Kit._beam(mb, Vector3(s * 1.0, 0.1, -0.4), Vector3(s * 1.0, 0.34, -3.4), 0.12, steel)
	for zc: float in [-4.4, -3.0, -1.6]:
		_bx(mb, -1.4, 1.4, 0.26, 0.4, zc - 0.07, zc + 0.07, steel)
	# --- Hazard stripes along the tip edge.
	for i in 7:
		_fy(mb, -1.4 + i * 0.4, -1.4 + (i + 1) * 0.4, -4.7, -4.4, 0.608, YELLOW if i % 2 == 0 else BLACK)
	# --- Yellow railings down both sides.
	for s: float in [-1.0, 1.0]:
		_railing(mb, out, Vector3(s * 1.4, 0.6, 1.0), Vector3(s * 1.4, 0.6, -4.5), 1.1, rail, 1.4, false)
	# --- The gate at the tip: two posts with beacons and a barred leaf.
	for s: float in [-1.0, 1.0]:
		var gp := Vector3(s * 1.4, 0.6, -4.6)
		mb.box(gp + Vector3(0, 0.8, 0), Vector3(0.16, 1.6, 0.16), rail)
		out.append([gp + Vector3(0, 0.8, 0), Vector3(0.2, 1.6, 0.2)])
		mb.box(gp + Vector3(0, 1.68, 0), Vector3(0.2, 0.14, 0.2), _g(Color(1.0, 0.25, 0.2), MeshBuilder.GLOW_LAMP))
	for gy: float in [0.35, 0.75, 1.1]:
		mb.limb(Vector3(-1.3, 0.6 + gy, -4.6), Vector3(1.3, 0.6 + gy, -4.6), 0.04, 0.04, rail, 4, false)
	for i in 7:
		mb.cylinder(Vector3(-1.2 + i * 0.4, 0.6, -4.6), 0.03, 1.1, rail, 4)
	mb.limb(Vector3(-1.3, 0.95, -4.62), Vector3(1.3, 1.7, -4.62), 0.035, 0.035, rail, 4, false)
	# --- Two masts on the footing with a cross-beam, a banner and stay cables to the deck.
	for s: float in [-1.0, 1.0]:
		var mp := Vector3(s * 1.9, 0, 0.9)
		_bx(mb, mp.x - 0.4, mp.x + 0.4, 0.0, 0.3, mp.z - 0.4, mp.z + 0.4, CONCRETE_DK)
		mb.box(mp + Vector3(0, 2.65, 0), Vector3(0.3, 4.7, 0.3), steel)
		out.append([mp + Vector3(0, 2.65, 0), Vector3(0.4, 4.7, 0.4)])
		for zs: float in [-1.2, -2.6, -4.0]:
			_wire(mb, mp + Vector3(0, 4.8, 0), Vector3(s * 1.4, 0.7, zs))
		_wire(mb, mp + Vector3(0, 4.8, 0), Vector3(s * 2.8, 0.08, 3.9))
		mb.box(Vector3(s * 2.8, 0.1, 3.9), Vector3(0.3, 0.2, 0.3), CONCRETE_DK)
	_bx(mb, -2.05, 2.05, 4.75, 5.0, 0.76, 1.04, steel)
	mb.box(Vector3(0, 5.2, 0.9), Vector3(0.24, 0.24, 0.24), _g(Color(1.0, 0.25, 0.2), MeshBuilder.GLOW_LAMP))
	var field: Color = SIGN_FIELDS[rng.randi() % SIGN_FIELDS.size()]
	_fz(mb, -1.5, 1.5, 3.7, 4.7, 0.7, field)
	_glyph_bars(mb, 0.0, 4.2, 0.69, 2.0, 0.5, field.darkened(0.55), rng)
	# --- Winch hut with a drum frame and a cable up to the mast.
	_cabin(mb, out, Vector3(-3.9, 0, 3.3), 0.0, 2.4, 2.0, 2.2, 0.8, Color(0.32, 0.42, 0.38), RUST_DK, rng, 1, true)
	var dp := Vector3(-3.9, 0, 1.3)
	_bx(mb, dp.x - 0.8, dp.x + 0.8, 0.0, 0.14, dp.z - 0.5, dp.z + 0.5, steel)
	for s: float in [-1.0, 1.0]:
		_bx(mb, dp.x + s * 0.7 - 0.07, dp.x + s * 0.7 + 0.07, 0.14, 1.0, dp.z - 0.3, dp.z + 0.3, steel_lt)
	mb.limb(dp + Vector3(-0.65, 0.78, 0), dp + Vector3(0.65, 0.78, 0), 0.34, 0.34, _g(RUST, MeshBuilder.SIDING), 8, true)
	mb.limb(dp + Vector3(0.65, 0.78, 0), dp + Vector3(0.95, 0.78, 0), 0.05, 0.05, BLACK, 4, true)
	mb.limb(dp + Vector3(0.95, 0.78, 0), dp + Vector3(0.95, 0.78, 0.4), 0.04, 0.04, BLACK, 4, true)
	out.append([dp + Vector3(0, 0.55, 0), Vector3(1.8, 1.1, 1.0)])
	_wire(mb, dp + Vector3(0, 1.14, 0), Vector3(-1.9, 4.8, 0.9), 0.03)
	# --- Booking kiosk with a striped awning, a window and a colour-field sign.
	var kp := Vector3(3.9, 0, 2.3)
	mb.box(kp + Vector3(0, 1.15, 0), Vector3(2.0, 2.3, 1.6), _g(Color(0.85, 0.82, 0.72), MeshBuilder.SIDING))
	mb.box(kp + Vector3(0, 2.38, 0), Vector3(2.4, 0.14, 2.0), Color(0.25, 0.27, 0.3))
	out.append([kp + Vector3(0, 1.2, 0), Vector3(2.0, 2.4, 1.6)])
	var kf := kp.z - 0.82
	_fz(mb, kp.x - 0.7, kp.x + 0.7, 1.1, 1.85, kf, _g(GLASS_C, MeshBuilder.GLASS))
	mb.box(Vector3(kp.x, 1.05, kf - 0.25), Vector3(1.7, 0.12, 0.5), TIMBER_LT)
	_fx(mb, kp.z - 0.4, kp.z + 0.4, 0.0, 2.0, kp.x - 1.02, TIMBER_DK, -1.0)
	for i in 6:
		var sx0 := kp.x - 1.1 + 0.2 + i * 0.36
		_slope(mb, Vector3(sx0, 1.95, kf - 0.95), Vector3(sx0, 2.4, kf), 0.36, Vector3.RIGHT, RED if i % 2 == 0 else WHITE, 0.0)
	mb.box(kp + Vector3(0, 2.8, -0.85), Vector3(2.2, 0.7, 0.14), TIMBER_DK)
	var kfield: Color = SIGN_FIELDS[rng.randi() % SIGN_FIELDS.size()]
	_fz(mb, kp.x - 1.0, kp.x + 1.0, 2.5, 3.1, kp.z - 0.94, kfield)
	_glyph_bars(mb, kp.x, 2.8, kp.z - 0.95, 1.4, 0.35, kfield.darkened(0.55), rng)
	# --- Gear: harness crates, a tyre stack, a safety mat, a warning board and lamps.
	mb.box(Vector3(0, 0.07, 3.1), Vector3(2.8, 0.14, 1.4), _g(Color(0.2, 0.4, 0.75), MeshBuilder.SIDING))
	for i in 3:
		var cr := Vector3(-1.6 + i * 0.75, 0.0, 4.3)
		mb.box(cr + Vector3(0, 0.25, 0), Vector3(0.65, 0.5, 0.5), _g(ORANGE, MeshBuilder.SIDING))
	for k in 3:
		mb.cylinder(Vector3(1.9, 0.25 * k, 4.2), 0.4, 0.25, BLACK, 8)
	out.append([Vector3(1.9, 0.38, 4.2), Vector3(0.8, 0.76, 0.8)])
	_board(mb, out, Vector3(2.9, 0, 0.1), Vector2(1.5, 0.9), 1.0, YELLOW, rng)
	for s: float in [-1.0, 1.0]:
		var prev := Vector3.ZERO
		for i in 3:
			var pp := Vector3(s * 4.7, 0.0, -4.4 + i * 2.0)
			_pole(mb, out, pp, 1.0, 0.05, ORANGE if i % 2 == 0 else WHITE, 5)
			if i > 0:
				mb.limb(prev + Vector3(0, 0.9, 0), pp + Vector3(0, 0.9, 0), 0.02, 0.02, ORANGE, 3, false)
			prev = pp
	_lamp(mb, out, Vector3(5.4, 0, -0.4), 3.4)
	_lamp(mb, out, Vector3(-5.1, 0, -0.1), 3.4)


# --- Fairground -------------------------------------------------------------------

## A stall booth centred on p, front toward -Z before yaw: three walls, a counter,
## a flat roof, a striped awning over the front, a colour-field sign and wares.
static func _booth(mb, out: Array, p: Vector3, yaw: float, wall: Color, stripe: Color, field: Color, rng: RandomNumberGenerator) -> void:
	var saved := _push(mb, p, yaw)
	mb.box(Vector3(0, 1.3, 1.2), Vector3(4.0, 2.6, 0.14), _g(wall, MeshBuilder.SIDING))
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(s * 1.93, 1.3, 0.1), Vector3(0.14, 2.6, 2.4), _g(wall.darkened(0.12), MeshBuilder.SIDING))
	mb.box(Vector3(0, 0.55, -0.9), Vector3(3.7, 1.1, 0.5), _g(wall.darkened(0.25), MeshBuilder.SIDING))
	mb.box(Vector3(0, 1.14, -0.95), Vector3(3.9, 0.12, 0.8), TIMBER_LT)
	mb.box(Vector3(0, 2.68, 0), Vector3(4.4, 0.14, 2.8), Color(0.27, 0.26, 0.28))
	for i in 8:
		var sx := -2.2 + 0.55 * (i + 0.5)
		var sc := stripe if i % 2 == 0 else WHITE
		_slope(mb, Vector3(sx, 2.2, -2.5), Vector3(sx, 2.75, -1.4), 0.55, Vector3.RIGHT, sc, 0.0)
		_fz(mb, sx - 0.275, sx + 0.275, 2.05, 2.2, -2.5, sc)
	mb.box(Vector3(0, 3.17, 0.0), Vector3(3.4, 0.8, 0.14), TIMBER_DK)
	_fz(mb, -1.6, 1.6, 2.82, 3.52, -0.09, field)
	_glyph_bars(mb, 0.0, 3.17, -0.1, 2.2, 0.4, field.darkened(0.55), rng)
	for i in 3:
		var wc: Color = TENTS[rng.randi() % TENTS.size()]
		mb.box(Vector3(-1.1 + i * 1.1, 1.38, -0.95), Vector3(0.45, 0.4, 0.4), _g(wc, MeshBuilder.SIDING))
	mb.xform = saved
	Kit._col(out, p + Vector3(0, 1.3, 0), Vector3(4.4, 2.6, 2.8), yaw)


## The Ferris wheel: a ground point c below the hub, the wheel in the XY plane
## with two rims, spokes, twelve gondolas, A-frame legs and a boarding deck.
static func _ferris(mb, out: Array, c: Vector3, rng: RandomNumberGenerator) -> void:
	var rim_c := _g(Color(0.92, 0.92, 0.9), MeshBuilder.GLOSS)
	var red := _g(RED, MeshBuilder.GLOSS)
	var radius := 6.3
	var hub := Vector3(c.x, 8.0, c.z)
	var n := 12
	var ring: Array = []
	for i in n:
		var a := TAU * i / n
		ring.append(Vector3(cos(a) * radius, sin(a) * radius, 0))
	for zs: float in [-0.9, 0.9]:
		for i in n:
			var pa: Vector3 = ring[i]
			var pb: Vector3 = ring[(i + 1) % n]
			mb.limb(hub + pa + Vector3(0, 0, zs), hub + pb + Vector3(0, 0, zs), 0.09, 0.09, rim_c, 4, false)
			mb.limb(hub + Vector3(0, 0, zs), hub + pa + Vector3(0, 0, zs), 0.05, 0.05, rim_c, 3, false)
	mb.limb(hub + Vector3(0, 0, -2.0), hub + Vector3(0, 0, 2.0), 0.42, 0.42, red, 8, true)
	for i in n:
		var pa: Vector3 = ring[i]
		var rp := hub + pa
		mb.limb(rp + Vector3(0, 0, -0.95), rp + Vector3(0, 0, 0.95), 0.05, 0.05, rim_c, 3, false)
		var gc: Color = TENTS[i % TENTS.size()]
		mb.limb(rp, rp + Vector3(0, -0.5, 0), 0.04, 0.04, STEEL_DK, 3, false)
		mb.box(rp + Vector3(0, -0.95, 0), Vector3(1.1, 0.9, 1.5), _g(gc, MeshBuilder.GLOSS))
		mb.box(rp + Vector3(0, -0.43, 0), Vector3(1.25, 0.14, 1.65), gc.darkened(0.35))
	for i in n:
		var mid: Vector3 = (ring[i] as Vector3).lerp(ring[(i + 1) % n], 0.5)
		mb.box(hub + mid + Vector3(0, 0, -1.0), Vector3(0.22, 0.22, 0.22), _g(Color(1.0, 0.9, 0.55), MeshBuilder.GLOW_LAMP))
	for zs: float in [-1.9, 1.9]:
		for sx: float in [-1.0, 1.0]:
			var foot := Vector3(c.x + sx * 4.6, 0.0, c.z + zs * 1.3)
			mb.limb(hub + Vector3(0, 0, zs), foot + Vector3(0, 0.2, 0), 0.2, 0.22, red, 5, false)
			_bx(mb, foot.x - 0.55, foot.x + 0.55, 0.0, 0.3, foot.z - 0.55, foot.z + 0.55, CONCRETE_DK)
			out.append([foot + Vector3(0, 0.6, 0), Vector3(1.1, 1.2, 1.1)])
	for sx: float in [-1.0, 1.0]:
		var f0 := Vector3(c.x + sx * 4.6, 0.3, c.z - 2.47)
		var f1 := Vector3(c.x + sx * 4.6, 0.3, c.z + 2.47)
		mb.limb(f0, f1, 0.1, 0.1, STEEL_DK, 4, false)
	_bx(mb, c.x - 2.2, c.x + 2.2, 0.0, 0.5, c.z - 4.2, c.z - 2.4, TIMBER)
	_fy(mb, c.x - 2.2, c.x + 2.2, c.z - 4.2, c.z - 2.4, 0.505, TIMBER_LT)
	_cabin(mb, out, c + Vector3(-7.2, 0, -3.0), 0.0, 2.4, 2.0, 2.2, 0.7, Color(0.8, 0.78, 0.7), SHINGLE_RED, rng, 1, true)


## A string-light pole: a timber pole with a crossbar.
static func _light_pole(mb, out: Array, p: Vector3) -> void:
	mb.cylinder(p, 0.13, 5.0, TIMBER_DK, 5)
	out.append([p + Vector3(0, 2.5, 0), Vector3(0.3, 5.0, 0.3)])
	mb.box(p + Vector3(0, 4.9, 0), Vector3(0.9, 0.12, 0.12), TIMBER_DK)


## A string of bulbs from a to b, sagging a little, with `n` glowing bulbs.
static func _bulbs(mb, a: Vector3, b: Vector3, n: int, rng: RandomNumberGenerator) -> void:
	var cols := [Color(1.0, 0.85, 0.5), Color(1.0, 0.55, 0.4), Color(0.7, 0.9, 1.0), Color(1.0, 0.95, 0.7)]
	var prev := a
	for i in range(1, n + 2):
		var t := float(i) / (n + 1)
		var p := a.lerp(b, t) - Vector3(0, 0.55 * 4.0 * t * (1.0 - t), 0)
		mb.limb(prev, p, 0.02, 0.02, BLACK, 3, false)
		if i <= n:
			var bc: Color = cols[rng.randi() % cols.size()]
			mb.ball(p + Vector3(0, -0.13, 0), Vector3(0.12, 0.15, 0.12), _g(bc, MeshBuilder.GLOW_LAMP), 4, 2)
		prev = p


static func fairground(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var hx := w * 0.5
	var hz := d * 0.5
	# --- Ground: the midway ring path, the track in from the road, a gravel car park.
	_oval(mb, Vector3(0, 0.02, -8.0), 11.5, 3.2, 15.0, 6.8, GRAVEL.darkened(0.08), 28)
	Kit._pad(mb, -3.0, 3.0, -hz, -13.0, GRAVEL.darkened(0.12), 0.02)
	Kit._pad(mb, -34.0, -9.0, -23.5, -16.5, GRAVEL.darkened(0.15), 0.02)
	# --- The Ferris wheel on the right of the midway.
	_ferris(mb, out, Vector3(25.0, 0, 14.0), rng)
	# --- A ring of stall booths round the midway, their fronts toward the middle, a gap at the front.
	var centre := Vector3(0, 0, -8.0)
	var count := 9
	var span := deg_to_rad(316.0)
	var start := deg_to_rad(-90.0 + 22.0)
	for i in count:
		var th := start + span * i / (count - 1)
		var u := Vector3(cos(th), 0, sin(th))
		var bp := centre + Vector3(u.x * 17.0, 0, u.z * 8.0)
		var yaw := atan2(u.x, u.z)
		var wall: Color = TENTS[(i * 3) % TENTS.size()]
		var stripe: Color = TENTS[(i * 3 + 2) % TENTS.size()]
		var field: Color = SIGN_FIELDS[(i + 1) % SIGN_FIELDS.size()]
		_booth(mb, out, bp, yaw, wall, stripe, field, rng)
	# --- The rodeo arena: an oval fence with two gates, dirt floor, barrels and bucking chutes.
	var ac := Vector3(-17.0, 0, 11.0)
	_disc_xz(mb, ac + Vector3(0, 0.012, 0), 13.7, 8.7, _vary(DIRT.lightened(0.06), rng, 0.03), 28)
	_ring(mb, ac + Vector3(0, 0.016, 0), 9.0, 10.5, DIRT.darkened(0.1), 28, 0.62)
	var seg := 22
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var p0 := ac + Vector3(cos(a0) * 14.0, 0, sin(a0) * 9.0)
		var p1 := ac + Vector3(cos(a1) * 14.0, 0, sin(a1) * 9.0)
		if i != 0 and i != 11:
			mb.limb(p0 + Vector3(0, 0.55, 0), p1 + Vector3(0, 0.55, 0), 0.05, 0.05, TIMBER, 4, false)
			mb.limb(p0 + Vector3(0, 1.1, 0), p1 + Vector3(0, 1.1, 0), 0.06, 0.06, WHITE.darkened(0.08), 4, false)
			var dv := p1 - p0
			Kit._col(out, (p0 + p1) * 0.5 + Vector3(0, 0.6, 0), Vector3(dv.length(), 1.2, 0.2), atan2(-dv.z, dv.x))
		mb.cylinder(p0, 0.1, 1.3, TIMBER_DK, 4)
	for bpos: Vector3 in [Vector3(-23.0, 0, 9.0), Vector3(-11.0, 0, 9.0), Vector3(-17.0, 0, 15.0)]:
		var bc: Color = [RED, Color(0.2, 0.4, 0.75), ORANGE][roundi(absf(bpos.x + bpos.z)) % 3]
		mb.cylinder(bpos, 0.42, 1.0, _g(bc, MeshBuilder.METAL), 8)
		out.append([bpos + Vector3(0, 0.5, 0), Vector3(0.85, 1.0, 0.85)])
	for k in 5:
		_bx(mb, -21.0 + k * 2.7 - 0.07, -21.0 + k * 2.7 + 0.07, 0.0, 1.6, 17.0, 19.1, TIMBER_DK)
	_bx(mb, -21.0, -10.2, 1.5, 1.62, 17.0, 19.1, TIMBER)
	out.append([Vector3(-15.6, 0.8, 18.0), Vector3(10.8, 1.6, 2.1)])
	# --- Bleachers behind the arena: three tiers under a tin roof.
	var tiers := [[0.55, 20.8, 21.9], [1.1, 21.9, 23.1], [1.65, 23.1, 24.4]]
	for t: Array in tiers:
		var th2: float = t[0]
		_bx(mb, -26.0, -8.0, 0.0, th2, t[1], t[2], TIMBER_DK)
		_fy(mb, -26.0, -8.0, t[1], t[2], th2 + 0.005, TIMBER_LT)
	out.append([Vector3(-17.0, 0.83, 22.6), Vector3(18.0, 1.65, 3.6)])
	for i in 6:
		_pole(mb, out, Vector3(-25.5 + i * 3.4, 0, 24.3), 3.84, 0.1, TIMBER_DK, 4)
	mb.box(Vector3(-17.0, 3.9, 22.6), Vector3(19.0, 0.16, 4.6), _g(RUST_DK, MeshBuilder.SEAM_ROOF))
	# --- Picnic tables by the car park path.
	for i in 4:
		_picnic(mb, out, Vector3(12.0 + i * 5.0, 0, -20.5 + rng.randf_range(-0.8, 0.8)), rng.randf_range(-0.3, 0.3), TIMBER if i % 2 == 0 else TIMBER_LT)
	# --- String lights from a middle pole to six poles round the midway.
	var mid_pole := Vector3(0, 0, -8.0)
	_light_pole(mb, out, mid_pole)
	var ends := [Vector3(-12.0, 0, -8.0), Vector3(12.0, 0, -8.0), Vector3(-6.0, 0, -3.0), Vector3(6.0, 0, -3.0), Vector3(-6.0, 0, -13.0), Vector3(6.0, 0, -13.0)]
	for e: Vector3 in ends:
		_light_pole(mb, out, e)
		_bulbs(mb, mid_pole + Vector3(0, 4.9, 0), e + Vector3(0, 4.9, 0), 4, rng)
	# --- Entrance arch with a banner of colour bars, and the flag.
	for s: float in [-1.0, 1.0]:
		_sx(mb, out, s * 3.4 - 0.2, s * 3.4 + 0.2, 0.0, 5.0, -hz + 0.9, -hz + 1.3, TIMBER_DK)
	_bx(mb, -3.8, 3.8, 4.7, 5.1, -hz + 0.9, -hz + 1.3, TIMBER)
	var af: Color = SIGN_FIELDS[rng.randi() % SIGN_FIELDS.size()]
	_fz(mb, -3.0, 3.0, 3.6, 4.75, -hz + 0.88, af)
	_glyph_bars(mb, 0.0, 4.15, -hz + 0.87, 4.2, 0.6, af.darkened(0.55), rng)
	Kit._flagpole(mb, out, Vector3(-6.5, 0, -21.5), 8.0, [Color(0.2, 0.4, 0.75), Color(0.95, 0.9, 0.7)])
	# --- Car park: cars nose to the track, a pickup and a stock trailer.
	for i in 3:
		Kit._car(mb, out, Vector3(-31.0 + i * 3.4, 0, -20.2 + rng.randf_range(-0.6, 0.6)), PI + rng.randf_range(-0.15, 0.15), _pick(CAR_PAINTS, rng))
	Kit._pickup(mb, out, Vector3(-17.5, 0, -20.0), PI + 0.1, Color(0.4, 0.3, 0.22))
	var tp := Vector3(-13.0, 0, -20.5)
	_rbox(mb, tp + Vector3(0, 1.45, 0), Vector3(2.3, 2.1, 5.0), 0.1, _g(Color(0.7, 0.7, 0.72), MeshBuilder.METAL))
	for s: float in [-1.0, 1.0]:
		mb.limb(tp + Vector3(s * 1.2, 0.5, 0.5), tp + Vector3(s * 1.4, 0.5, 0.5), 0.5, 0.5, BLACK, 8, true)
	out.append([tp + Vector3(0, 1.3, 0), Vector3(2.4, 2.3, 5.0), 0.1])
	# --- Pines at the edges, kept inside the lot.
	for pn: Array in [[-33.5, -5.0, 7.0], [-33.5, 3.0, 6.5], [33.5, -12.0, 7.0], [30.0, 22.5, 6.5], [14.0, 22.8, 6.0]]:
		var ph: float = pn[2]
		var pr := ph * 0.3
		_pine(mb, out, Vector3(clampf(pn[0], -hx + 0.3 + pr, hx - 0.3 - pr), 0, clampf(pn[1], -hz + 0.3 + pr, hz - 0.3 - pr)), ph, rng)


# --- Hunting store -----------------------------------------------------------------

## A canoe resting on a rack, hull length 4.8 along X centred on p (ground):
## a V hull with a pale inside, two thwarts, a two-trestle rack and a collider.
static func _canoe(mb, out: Array, p: Vector3, yaw: float, hull: Color) -> void:
	var saved := _push(mb, p, yaw)
	var n := 8
	var base := 1.13
	var prev_l := Vector3.ZERO
	var prev_k := Vector3.ZERO
	var prev_r := Vector3.ZERO
	for i in n + 1:
		var t := -1.0 + 2.0 * i / n
		var hw := 0.46 * pow(maxf(0.0, 1.0 - t * t), 0.7)
		var x := 2.4 * t
		var ytop := base + 0.32 + 0.12 * t * t
		var ybot := base + 0.05 + 0.2 * t * t
		var l := Vector3(x, ytop, -hw)
		var k := Vector3(x, ybot, 0.0)
		var r := Vector3(x, ytop, hw)
		if i > 0:
			mb.quad(prev_l, prev_k, k, l, Vector3(0, -0.3, -1).normalized(), hull)
			mb.quad(prev_r, prev_k, k, r, Vector3(0, -0.3, 1).normalized(), hull)
			mb.quad(prev_l, prev_k, k, l, Vector3(0, 0.6, 1).normalized(), TIMBER_LT)
			mb.quad(prev_r, prev_k, k, r, Vector3(0, 0.6, -1).normalized(), TIMBER_LT)
		prev_l = l
		prev_k = k
		prev_r = r
	for tx: float in [-0.8, 0.8]:
		mb.box(Vector3(tx, base + 0.36, 0), Vector3(0.12, 0.06, 0.8), TIMBER_DK)
	for sx: float in [-1.5, 1.5]:
		for sz: float in [-1.0, 1.0]:
			mb.cylinder(Vector3(sx, 0.0, sz * 0.62), 0.07, 1.2, TIMBER_DK, 4)
		_bx(mb, sx - 0.07, sx + 0.07, 1.14, 1.26, -0.7, 0.7, TIMBER)
	mb.xform = saved
	Kit._col(out, p + Vector3(0, 0.9, 0), Vector3(5.0, 1.8, 1.3), yaw)


## A paddle leaning against something: its foot at p, top toward `lean`.
static func _paddle(mb, p: Vector3, lean: Vector3, color: Color) -> void:
	var top := p + lean + Vector3(0, 1.5, 0)
	mb.limb(p + Vector3(0, 0.05, 0), top, 0.03, 0.03, TIMBER_LT, 4, true)
	mb.limb(p + Vector3(0, 0.05, 0), p + lean * 0.2 + Vector3(0, 0.45, 0), 0.1, 0.1, color, 4, true)


static func hunting_store(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var hz := d * 0.5
	var siding := Color(0.4, 0.29, 0.2)
	var batten := Color(0.26, 0.18, 0.12)
	var roof := Color(0.2, 0.33, 0.27)
	var cx := -2.1
	# --- Ground: gravel parking in front, the porch deck, a step.
	Kit._pad(mb, -7.8, 7.8, -hz, -5.5, GRAVEL.darkened(0.08), 0.02)
	_bx(mb, -7.2, 3.0, 0.0, 0.3, -5.4, -1.5, TIMBER_LT.darkened(0.12))
	_bx(mb, -2.9, -0.9, 0.0, 0.15, -6.0, -5.4, TIMBER_LT.darkened(0.2))
	# --- The store: a board-and-batten box, a gable tin roof and a tall false front.
	mb.box(Vector3(cx, 1.7, 3.0), Vector3(10.2, 3.4, 9.0), _g(siding, MeshBuilder.SIDING))
	out.append([Vector3(cx, 1.7, 3.0), Vector3(10.2, 3.4, 9.0)])
	Kit._gable(mb, cx, 3.45, 3.4, 11.2, 9.7, 1.7, _g(roof, MeshBuilder.SEAM_ROOF), siding.darkened(0.2))
	mb.box(Vector3(cx, 5.12, 3.45), Vector3(11.2, 0.12, 0.22), roof.darkened(0.3))
	mb.cylinder(Vector3(-5.0, 4.4, 4.2), 0.16, 1.4, STEEL_DK, 5)
	mb.cylinder(Vector3(-5.0, 5.8, 4.2), 0.24, 0.12, STEEL_DK, 5)
	mb.box(Vector3(cx, 4.3, -1.6), Vector3(10.6, 1.8, 0.2), _g(siding.darkened(0.1), MeshBuilder.SIDING))
	mb.box(Vector3(cx, 5.28, -1.6), Vector3(10.8, 0.16, 0.34), batten)
	var fz := -1.71
	for i in 22:
		var bxp := -7.0 + i * 0.47
		_fz(mb, bxp - 0.05, bxp + 0.05, 0.3, 3.4, -1.52, batten)
	var field := Color(0.14, 0.3, 0.2)
	_fz(mb, -7.2, 3.0, 3.6, 5.1, fz - 0.01, field)
	var cream := Color(0.92, 0.86, 0.66)
	for tier in 3:
		var yb := 3.75 + tier * 0.38
		var hw := 0.62 - tier * 0.15
		mb.tri(Vector3(cx - hw, yb, fz - 0.03), Vector3(cx + hw, yb, fz - 0.03), Vector3(cx, yb + 0.6, fz - 0.03), Vector3(0, 0, -1), cream)
	_fz(mb, cx - 0.06, cx + 0.06, 3.65, 3.8, fz - 0.03, cream)
	_glyph_bars(mb, -5.2, 4.35, fz - 0.03, 3.4, 0.8, cream, rng)
	_glyph_bars(mb, 1.0, 4.35, fz - 0.03, 3.4, 0.8, ORANGE, rng)
	# --- Front wall: a double door, two shop windows with shutters, a hanging lantern.
	var wz := -1.54
	_fz(mb, cx - 0.9, cx + 0.9, 0.3, 2.45, wz, TIMBER_DK)
	_fz(mb, cx - 0.8, cx - 0.04, 0.4, 2.35, wz - 0.02, TIMBER)
	_fz(mb, cx + 0.04, cx + 0.8, 0.4, 2.35, wz - 0.02, TIMBER)
	_fz(mb, cx - 0.6, cx - 0.24, 1.3, 2.1, wz - 0.04, _g(GLASS_C, MeshBuilder.GLASS))
	_fz(mb, cx + 0.24, cx + 0.6, 1.3, 2.1, wz - 0.04, _g(GLASS_C, MeshBuilder.GLASS))
	for wx: float in [-5.2, 1.0]:
		_fz(mb, wx - 0.95, wx + 0.95, 1.0, 2.5, wz, TIMBER_DK)
		_fz(mb, wx - 0.85, wx + 0.85, 1.1, 2.4, wz - 0.02, _g(GLASS_C, MeshBuilder.GLASS))
		_fz(mb, wx - 0.02, wx + 0.02, 1.1, 2.4, wz - 0.04, TIMBER_DK)
		_fz(mb, wx - 1.5, wx - 0.97, 1.0, 2.5, wz - 0.02, field)
		_fz(mb, wx + 0.97, wx + 1.5, 1.0, 2.5, wz - 0.02, field)
	mb.box(Vector3(cx + 1.4, 2.7, -1.75), Vector3(0.22, 0.3, 0.22), _g(Color(1.0, 0.85, 0.5), MeshBuilder.GLOW_LAMP))
	mb.cylinder(Vector3(cx + 1.4, 2.85, -1.75), 0.02, 0.55, BLACK, 3)
	# --- Porch: a shed roof on log posts, a bench, barrels, crates and hanging jackets.
	_slope(mb, Vector3(cx, 2.6, -5.6), Vector3(cx, 3.4, -1.7), 10.8, Vector3.RIGHT, _g(roof, MeshBuilder.SEAM_ROOF), 0.12)
	_bx(mb, -7.5, 3.3, 2.5, 2.7, -5.7, -5.5, TIMBER_DK)
	for i in 6:
		var px := -7.0 + i * 2.0
		mb.cylinder(Vector3(px, 0.3, -5.4), 0.13, 2.3, _vary(LOG, rng, 0.1), 5)
		out.append([Vector3(px, 1.45, -5.4), Vector3(0.3, 2.3, 0.3)])
	mb.box(Vector3(-5.2, 0.55, -2.0), Vector3(3.0, 0.1, 0.5), TIMBER_LT)
	for bx0: float in [-6.4, -4.0]:
		mb.box(Vector3(bx0, 0.42, -2.0), Vector3(0.12, 0.24, 0.45), TIMBER_DK)
	for bp: Vector3 in [Vector3(-6.7, 0.3, -3.3), Vector3(1.9, 0.3, -2.6)]:
		mb.cylinder(bp, 0.4, 0.95, _g(RUST_DK, MeshBuilder.SIDING), 7)
		out.append([bp + Vector3(0, 0.48, 0), Vector3(0.8, 0.95, 0.8)])
	_rbox(mb, Vector3(0.4, 0.62, -2.5), Vector3(0.9, 0.64, 0.7), 0.2, TIMBER)
	_rbox(mb, Vector3(0.45, 1.2, -2.45), Vector3(0.7, 0.5, 0.6), -0.3, TIMBER_LT)
	for i in 4:
		var jx: float = [-6.0, -4.0, 0.0, 2.0][i]
		var jc: Color = [ORANGE, Color(0.35, 0.4, 0.25), Color(0.5, 0.42, 0.28), ORANGE][i]
		_fz(mb, jx - 0.3, jx + 0.3, 1.5, 2.5, -5.73, jc)
	out.append([Vector3(0.42, 0.88, -2.5), Vector3(0.9, 1.15, 0.8)])
	# --- The pylon sign by the road: a colour field on two tall posts.
	_board(mb, out, Vector3(5.6, 0, -8.6), Vector2(4.4, 2.2), 2.6, ORANGE, rng, false)
	for s: float in [-1.0, 1.0]:
		out.append([Vector3(5.6 + s * 2.1, 2.4, -8.6), Vector3(0.3, 4.8, 0.3)])
	mb.tri(Vector3(5.6 - 0.7, 3.2, -8.77), Vector3(5.6 + 0.7, 3.2, -8.77), Vector3(5.6, 4.5, -8.77), Vector3(0, 0, -1), Color(0.14, 0.3, 0.2))
	# --- The canoe on its rack, paddles leaning on the porch.
	_canoe(mb, out, Vector3(-2.0, 0, -8.2), 0.06, Color(0.75, 0.2, 0.15))
	_paddle(mb, Vector3(-7.0, 0.0, -6.0), Vector3(0, 0, 0.45), Color(0.2, 0.5, 0.3))
	_paddle(mb, Vector3(-5.0, 0.0, -6.0), Vector3(0, 0, 0.45), Color(0.75, 0.2, 0.15))
	# --- The fenced side yard: board fence with a gate gap, firewood, a pelt rack and an archery bale.
	_boards(mb, out, Vector3(7.5, 0, -1.4), Vector3(7.5, 0, 8.7), 1.3, Color(0.5, 0.38, 0.26), 3.4)
	_boards(mb, out, Vector3(7.5, 0, 8.7), Vector3(3.1, 0, 8.7), 1.3, Color(0.5, 0.38, 0.26), 3.4)
	_boards(mb, out, Vector3(3.1, 0, -1.4), Vector3(4.5, 0, -1.4), 1.3, Color(0.5, 0.38, 0.26), 3.4)
	_boards(mb, out, Vector3(6.5, 0, -1.4), Vector3(7.5, 0, -1.4), 1.3, Color(0.5, 0.38, 0.26), 3.4)
	_rbox(mb, Vector3(5.05, 0.6, -2.17), Vector3(1.9, 1.1, 0.12), 0.95, Color(0.5, 0.38, 0.26))
	_log_stack(mb, out, Vector3(6.6, 0, 6.0), 0.0, 2.6, 5, 0.14, rng, 4)
	for hx: float in [4.0, 6.0]:
		mb.cylinder(Vector3(hx, 0.0, 3.2), 0.08, 2.1, TIMBER_DK, 4)
		out.append([Vector3(hx, 1.05, 3.2), Vector3(0.2, 2.1, 0.2)])
	mb.limb(Vector3(3.95, 2.0, 3.2), Vector3(6.05, 2.0, 3.2), 0.05, 0.05, TIMBER, 4, false)
	for i in 3:
		var hc: Color = [Color(0.55, 0.4, 0.26), Color(0.7, 0.58, 0.42), Color(0.42, 0.3, 0.2)][i]
		var hx2 := 4.5 + i * 0.55
		var hy := 1.95 - rng.randf_range(0.9, 1.2)
		mb.quad(Vector3(hx2 - 0.22, hy, 3.12), Vector3(hx2 + 0.22, hy + 0.05, 3.12), Vector3(hx2 + 0.28, 1.95, 3.12), Vector3(hx2 - 0.28, 1.95, 3.12), Vector3(0, 0, -1), hc)
		mb.quad(Vector3(hx2 - 0.22, hy, 3.28), Vector3(hx2 + 0.22, hy + 0.05, 3.28), Vector3(hx2 + 0.28, 1.95, 3.28), Vector3(hx2 - 0.28, 1.95, 3.28), Vector3(0, 0, 1), hc.darkened(0.15))
	for k in 2:
		_rbox(mb, Vector3(5.7 + k * 1.3 - 0.65, 0.3, 8.0), Vector3(1.25, 0.6, 0.6), 0.05 * k, SAWDUST.darkened(0.12))
	mb.box(Vector3(5.7, 0.9, 8.0), Vector3(1.25, 0.6, 0.6), SAWDUST.darkened(0.2))
	out.append([Vector3(5.7, 0.7, 8.0), Vector3(2.6, 1.4, 0.7)])
	for ring in 4:
		var rc: Color = [WHITE, BLACK, Color(0.2, 0.4, 0.75), RED][ring]
		_vdisc(mb, Vector3(5.7, 0.9, 7.68 - ring * 0.008), 0.28 - ring * 0.065, rc, 10)
	# --- A parked pickup, a lamp and a spruce in the front corner.
	Kit._pickup(mb, out, Vector3(5.0, 0, -5.9), -0.4, Color(0.28, 0.34, 0.3))
	_lamp(mb, out, Vector3(-7.55, 0, -3.5), 3.4)
	_pine(mb, out, Vector3(-6.2, 0, -8.3), 5.0, rng)
