extends RefCounted
## Civic kit (Bellerive v3, HANDOFF-bellerive-v3.md B-5): government
## buildings, civic set pieces, city homes and a pleasure pier, borrowed
## from DC, New York and California. Pure data in, mesh out: static
## functions only, no scene tree, so a tile builds on a worker thread.
##
## Frame and colliders as in country_kit.gd: the lot spans x in [-w/2, w/2]
## (along the street) and z in [-d/2, d/2], the main entrance faces the
## street at -Z, ground at y = 0. Everything stays on the lot, except
## flagpoles, lamps and steps, which may reach 1 m past the front edge.
## Collision boxes go to `out` as [center, size] or [center, size, yaw];
## low steps, terraces and decks (under 0.7 m) get none. No text, logos or
## real flags anywhere: flags are plain colour fields, screens abstract.
## pier_rides stands over water: its deck is 1.5 m up with no deck collider
## (the player walks at y = 0), and its piles reach 0.65 m below y = 0, to
## the city's water plane at y = -0.5.

const MeshBuilder = preload("res://scripts/mesh_builder.gd")
const Kit = preload("res://scripts/kits/country_kit.gd")
const Buildings = preload("res://scripts/kits/building_kit.gd")
const Props = preload("res://scripts/kits/prop_kit.gd")

## City government landmarks (the Civic Center on the mall axis).
const LANDMARKS := [
	"city_hall", "county_courthouse", "federal_building", "public_library",
	"police_headquarters", "main_post_office", "fire_headquarters", "founders_obelisk",
	"reflecting_pool", "ferry_building", "led_tower",
]
## Suburban government buildings (the outskirts).
const SUBURBAN := ["fire_station", "post_office", "dmv_office", "sheriff_station", "public_school"]
## Homes: rows and houses.
const HOMES := ["brownstone_row", "painted_lady_row", "rowhouse_row", "cape_house"]
## Attractions.
const ATTRACTIONS := ["pier_rides"]

## Default lot of each kind: x along the front, y deep, metres.
const SIZES := {
	"city_hall": Vector2(70, 56), "county_courthouse": Vector2(50, 40),
	"federal_building": Vector2(60, 44), "public_library": Vector2(50, 36),
	"police_headquarters": Vector2(46, 36), "main_post_office": Vector2(64, 30),
	"fire_headquarters": Vector2(36, 30), "founders_obelisk": Vector2(40, 40),
	"reflecting_pool": Vector2(30, 120), "ferry_building": Vector2(90, 24),
	"led_tower": Vector2(30, 24),
	"fire_station": Vector2(26, 22), "post_office": Vector2(30, 24),
	"dmv_office": Vector2(40, 30), "sheriff_station": Vector2(30, 24),
	"public_school": Vector2(60, 40),
	"brownstone_row": Vector2(36, 14), "painted_lady_row": Vector2(36, 14),
	"rowhouse_row": Vector2(36, 12), "cape_house": Vector2(11, 9),
	"pier_rides": Vector2(60, 140),
}

const LIMESTONE := Color(0.87, 0.84, 0.77)
const MARBLE := Color(0.94, 0.93, 0.89)
const GRANITE := Color(0.62, 0.61, 0.59)
const SANDSTONE := Color(0.85, 0.79, 0.67)
const PAVER := Color(0.8, 0.77, 0.71)
const LAWN := Color(0.4, 0.58, 0.29)
const LEAD := Color(0.56, 0.6, 0.62)
const DOME := Color(0.82, 0.84, 0.84)
const GOLD := Color(0.9, 0.72, 0.25)
const TILE_RED := Color(0.68, 0.3, 0.2)
const ENGINE_RED := Color(0.78, 0.1, 0.08)
const POLICE_BLUE := Color(0.15, 0.25, 0.55)
const CITY_TEAL := Color(0.1, 0.45, 0.5)
const WATER := Color(0.22, 0.38, 0.46)
const DARK := Color(0.1, 0.11, 0.13)
const RECESS := Color(0.16, 0.15, 0.14)
const IRON := Color(0.12, 0.13, 0.13)
const STEEL := Color(0.7, 0.72, 0.75)
const WARM_LIT := Color(0.36, 0.3, 0.22)
const TRIM := Color(0.97, 0.96, 0.92)
const ROOF_GREY := Color(0.62, 0.63, 0.64)
const ASPHALT := Color(0.24, 0.24, 0.26)
const CONCRETE := Color(0.72, 0.71, 0.68)
const YELLOW := Color(0.95, 0.8, 0.2)
## Flags as [field, hoist band]: city teal with gold, county maroon with
## gold, federal navy with white. Plain fields, no emblems.
const CITY_FLAG := [Color(0.1, 0.45, 0.5), Color(0.9, 0.72, 0.25)]
const COUNTY_FLAG := [Color(0.5, 0.15, 0.18), Color(0.9, 0.72, 0.25)]
const FEDERAL_FLAG := [Color(0.14, 0.2, 0.42), Color(0.94, 0.93, 0.89)]
const NEONS := [Color(1.0, 0.3, 0.55), Color(0.3, 0.85, 1.0), Color(1.0, 0.75, 0.2), Color(0.55, 1.0, 0.45), Color(0.8, 0.4, 1.0), Color(1.0, 0.45, 0.2), Color(0.25, 0.5, 1.0)]
## [colour, surface code] of the brownstone fronts: brown sandstone and a
## few red brick.
const BROWNSTONES := [
	[Color(0.45, 0.31, 0.25), 0.1875], [Color(0.53, 0.36, 0.27), 0.1875], [Color(0.4, 0.28, 0.23), 0.1875],
	[Color(0.6, 0.31, 0.24), 0.8125], [Color(0.49, 0.33, 0.29), 0.1875], [Color(0.56, 0.27, 0.21), 0.8125],
]
## Bright Victorian pastels (Alamo Square).
const VICTORIAN := [
	Color(0.96, 0.62, 0.72), Color(0.55, 0.8, 0.93), Color(0.99, 0.86, 0.45), Color(0.62, 0.86, 0.62),
	Color(0.8, 0.66, 0.92), Color(0.99, 0.7, 0.5), Color(0.5, 0.78, 0.76), Color(0.95, 0.5, 0.45),
]
## Capitol Hill rowhouse fronts: red bricks and a few painted.
const ROW_FRONTS := [
	[Color(0.62, 0.3, 0.24), 0.8125], [Color(0.54, 0.27, 0.22), 0.8125], [Color(0.86, 0.82, 0.7), 0.8125],
	[Color(0.68, 0.38, 0.3), 0.8125], [Color(0.55, 0.62, 0.7), 0.8125], [Color(0.5, 0.31, 0.27), 0.8125],
	[Color(0.84, 0.7, 0.52), 0.8125],
]
const CAPE_SIDINGS := [Color(0.94, 0.93, 0.88), Color(0.78, 0.82, 0.84), Color(0.95, 0.88, 0.66), Color(0.7, 0.8, 0.72), Color(0.86, 0.74, 0.66), Color(0.62, 0.7, 0.8)]
const SHUTTERS := [Color(0.12, 0.22, 0.36), Color(0.16, 0.34, 0.24), Color(0.5, 0.16, 0.14), Color(0.15, 0.15, 0.16), Color(0.3, 0.45, 0.5)]


## Every kind this kit builds.
static func kinds() -> Array:
	return LANDMARKS + SUBURBAN + HOMES + ATTRACTIONS


## The default lot of `kind` (x along the front, y deep, metres).
static func default_size(kind: String) -> Vector2:
	return SIZES.get(kind, Vector2(20, 20))


## Triangle budget of `kind` at its default size.
static func budget(kind: String) -> int:
	if kind in SUBURBAN:
		return 3500
	if kind in HOMES:
		return 3000
	return 9000


## Builds `kind` on a lot of `size` (x along the front, y deep). See the
## header for the frame and the collision format.
static func build(kind: String, mb, out: Array, size: Vector2, rng: RandomNumberGenerator) -> void:
	var w := maxf(size.x, 4.0)
	var d := maxf(size.y, 4.0)
	match kind:
		"city_hall": city_hall(mb, out, w, d, rng)
		"county_courthouse": county_courthouse(mb, out, w, d, rng)
		"federal_building": federal_building(mb, out, w, d, rng)
		"public_library": public_library(mb, out, w, d, rng)
		"police_headquarters": police_headquarters(mb, out, w, d, rng)
		"main_post_office": main_post_office(mb, out, w, d, rng)
		"fire_headquarters": fire_headquarters(mb, out, w, d, rng)
		"founders_obelisk": founders_obelisk(mb, out, w, d, rng)
		"reflecting_pool": reflecting_pool(mb, out, w, d, rng)
		"ferry_building": ferry_building(mb, out, w, d, rng)
		"led_tower": led_tower(mb, out, w, d, rng)
		"fire_station": fire_station(mb, out, w, d, rng)
		"post_office": post_office(mb, out, w, d, rng)
		"dmv_office": dmv_office(mb, out, w, d, rng)
		"sheriff_station": sheriff_station(mb, out, w, d, rng)
		"public_school": public_school(mb, out, w, d, rng)
		"brownstone_row": brownstone_row(mb, out, w, d, rng)
		"painted_lady_row": painted_lady_row(mb, out, w, d, rng)
		"rowhouse_row": rowhouse_row(mb, out, w, d, rng)
		"cape_house": cape_house(mb, out, w, d, rng)
		"pier_rides": pier_rides(mb, out, w, d, rng)
		_:
			# Unknown kind: a plain magenta block, so a typo shows instead of a hole.
			Kit._solid(mb, out, Vector3(0, 2.0, 0), Vector3(w * 0.6, 4.0, d * 0.6), Color(1.0, 0.0, 1.0))


# --- Helpers ------------------------------------------------------------------

static func _stone(c: Color) -> Color:
	return MeshBuilder.glow(c, MeshBuilder.CONCRETE)


static func _paving(c := PAVER) -> Color:
	return MeshBuilder.glow(c, MeshBuilder.PAVING)


static func _grass(c := LAWN) -> Color:
	return MeshBuilder.glow(c, MeshBuilder.GRASS)


static func _lit(c := WARM_LIT) -> Color:
	return MeshBuilder.glow(c, MeshBuilder.GLOW_WINDOW)


## A box turned by `yaw` about its centre.
static func _rbox(mb, c: Vector3, size: Vector3, yaw: float, color: Color) -> void:
	var saved: Transform3D = mb.xform
	mb.xform = saved * Transform3D(Basis(Vector3.UP, yaw), c)
	mb.box(Vector3.ZERO, size, color)
	mb.xform = saved


## A flat rectangle centred on c, `size.x` along u and `size.y` up,
## facing n (a sign face, a screen, a clock dial).
static func _panel(mb, c: Vector3, u: Vector3, n: Vector3, size: Vector2, color: Color) -> void:
	var a := u * size.x * 0.5
	var b := Vector3.UP * size.y * 0.5
	mb.quad(c - a - b, c + a - b, c + a + b, c - a + b, n, color)


## A flat disc facing up.
static func _disc(mb, c: Vector3, r: float, color: Color, segs := 24) -> void:
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		mb.tri(c, c + Vector3(cos(a0), 0, sin(a0)) * r, c + Vector3(cos(a1), 0, sin(a1)) * r, Vector3.UP, color)


## A flat ring (or part of one, from angle a0 to a1) facing up.
static func _ring(mb, c: Vector3, r0: float, r1: float, color: Color, segs := 24, a0 := 0.0, a1 := TAU) -> void:
	for i in segs:
		var t0 := lerpf(a0, a1, float(i) / segs)
		var t1 := lerpf(a0, a1, float(i + 1) / segs)
		var d0 := Vector3(cos(t0), 0, sin(t0))
		var d1 := Vector3(cos(t1), 0, sin(t1))
		mb.quad(c + d0 * r0, c + d0 * r1, c + d1 * r1, c + d1 * r0, Vector3.UP, color)


## A disc standing on a wall that faces n (clock dials, round windows).
static func _wall_disc(mb, c: Vector3, n: Vector3, r: float, color: Color, segs := 12) -> void:
	var u := Vector3(-n.z, 0, n.x)
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		mb.tri(c, c + (u * cos(a0) + Vector3.UP * sin(a0)) * r, c + (u * cos(a1) + Vector3.UP * sin(a1)) * r, n, color)


## An arched opening on a wall facing n: c is the middle of its sill on the
## wall face, u runs along the wall; wd wide, ht tall to the crown.
static func _arch_open(mb, c: Vector3, u: Vector3, n: Vector3, wd: float, ht: float, color: Color, segs := 5) -> void:
	var half := wd * 0.5
	var spring := maxf(ht - half, 0.1)
	var o := c + n * 0.05
	mb.quad(o - u * half, o + u * half, o + u * half + Vector3.UP * spring, o - u * half + Vector3.UP * spring, n, color)
	var top := o + Vector3.UP * spring
	for i in segs:
		var a0 := PI * i / segs
		var a1 := PI * (i + 1) / segs
		mb.tri(top, top + (u * cos(a0) + Vector3.UP * sin(a0)) * half, top + (u * cos(a1) + Vector3.UP * sin(a1)) * half, n, color)


## A classical column standing at p: plinth, shaft and capital (with a
## taller flared capital when `corinthian`).
static func _column(mb, p: Vector3, h: float, r: float, color: Color, sides := 8, corinthian := false) -> void:
	mb.box(Vector3(p.x, p.y + r * 0.45, p.z), Vector3(r * 2.6, r * 0.9, r * 2.6), color.darkened(0.06))
	mb.cylinder(Vector3(p.x, p.y + r * 0.9, p.z), r, h - r * 1.8, color, sides)
	if corinthian:
		mb.box(Vector3(p.x, p.y + h - r * 0.75, p.z), Vector3(r * 2.3, r * 0.7, r * 2.3), color.lightened(0.04))
		mb.box(Vector3(p.x, p.y + h - r * 0.2, p.z), Vector3(r * 2.9, r * 0.4, r * 2.9), color)
	else:
		mb.box(Vector3(p.x, p.y + h - r * 0.45, p.z), Vector3(r * 2.8, r * 0.9, r * 2.8), color)


## `n` columns evenly from x0 to x1 at depth z, standing on y0.
static func _colonnade(mb, x0: float, x1: float, z: float, y0: float, h: float, n: int, r: float, color: Color, corinthian := false) -> void:
	for i in n:
		var x := (x0 + x1) * 0.5 if n < 2 else lerpf(x0, x1, float(i) / (n - 1))
		_column(mb, Vector3(x, y0, z), h, r, color, 8, corinthian)


## A broad flight of `n` steps across x0..x1, climbing from z0 (the street
## side, at the ground) back to z1, where it reaches height h.
static func _stair(mb, x0: float, x1: float, z0: float, z1: float, h: float, n: int, color: Color) -> void:
	var run := (z1 - z0) / n
	for i in n:
		var top := h * (i + 1) / n
		var zs := z0 + run * i
		mb.box(Vector3((x0 + x1) * 0.5, top * 0.5, (zs + z1) * 0.5), Vector3(x1 - x0, top, z1 - zs), color)


## A flat roof with a parapet (a balustrade on the classical buildings) on
## a w x d box centred on (cx, cz) whose top is at `top`.
static func _parapet_roof(mb, cx: float, cz: float, w: float, d: float, top: float, edge: Color, ph := 0.9, membrane := ROOF_GREY) -> void:
	mb.box(Vector3(cx, top + 0.02, cz), Vector3(w - 0.4, 0.04, d - 0.4), MeshBuilder.glow(membrane, MeshBuilder.ROOF))
	const T := 0.35
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(cx + s * (w * 0.5 - T * 0.5), top + ph * 0.5, cz), Vector3(T, ph, d), edge)
		mb.box(Vector3(cx, top + ph * 0.5, cz + s * (d * 0.5 - T * 0.5)), Vector3(w - T * 2.0, ph, T), edge)


## A projecting cornice band round the top of a w x d box (centre cx, cz)
## whose top is at `top`.
static func _cornice(mb, cx: float, cz: float, w: float, d: float, top: float, color: Color, out_by := 0.4, h := 0.7) -> void:
	mb.box(Vector3(cx, top - h * 0.5 - 0.05, cz), Vector3(w + out_by * 2.0, h, d + out_by * 2.0), color)


## Rows of windows on one wall: from a to b (points on the wall at y = 0),
## `rows` floors from y0, `fh` apart, about one per `step` metres.
static func _face_windows(mb, a: Vector3, b: Vector3, y0: float, rows: int, fh: float, step: float, size: Vector2, rng: RandomNumberGenerator, facing: Vector3, lit := 0.45) -> void:
	var n := maxi(1, int(a.distance_to(b) / step))
	for f in rows:
		var y := y0 + f * fh
		Kit._windows(mb, Vector3(a.x, y, a.z), Vector3(b.x, y, b.z), n, size, rng, facing, lit)


## Arched openings along a wall from a to b (sill points), one per `step`.
static func _arcade(mb, a: Vector3, b: Vector3, step: float, wd: float, ht: float, n_face: Vector3, color: Color, skip_half := 0.0) -> void:
	var n := maxi(1, int(a.distance_to(b) / step))
	var u := (b - a).normalized()
	for i in n:
		var p := a.lerp(b, (i + 0.5) / n)
		if skip_half > 0.0 and absf(p.x) < skip_half and absf(n_face.z) > 0.5:
			continue
		_arch_open(mb, p, u, n_face, wd, ht, color)


## A dome on a circle of radius r at c (its springing line), rising h, with
## raised ribs; a ribbed lead or stone dome for the top-down read.
static func _dome(mb, c: Vector3, r: float, h: float, color: Color, rib: Color, sides := 16, rings := 5, ribs := 16) -> void:
	for k in rings:
		var t0 := PI * 0.5 * k / rings
		var t1 := PI * 0.5 * (k + 1) / rings
		var tm := (t0 + t1) * 0.5
		for i in sides:
			var a0 := TAU * i / sides
			var a1 := TAU * (i + 1) / sides
			var am := (a0 + a1) * 0.5
			var n := Vector3(cos(am) * cos(tm) / r, sin(tm) / h, sin(am) * cos(tm) / r).normalized()
			var p00 := _dome_pt(c, r, h, a0, t0)
			var p01 := _dome_pt(c, r, h, a1, t0)
			var p10 := _dome_pt(c, r, h, a0, t1)
			var p11 := _dome_pt(c, r, h, a1, t1)
			if k == rings - 1:
				mb.tri(p00, p01, p11, n, color)
			else:
				mb.quad(p00, p01, p11, p10, n, color)
	for j in ribs:
		var a := TAU * j / ribs
		for k in rings - 1:
			var t0 := PI * 0.5 * k / rings
			var t1 := PI * 0.5 * (k + 1) / rings
			Kit._beam(mb, _dome_pt(c, r + 0.12, h + 0.12, a, t0), _dome_pt(c, r + 0.12, h + 0.12, a, t1), 0.32, rib)


static func _dome_pt(c: Vector3, r: float, h: float, a: float, t: float) -> Vector3:
	return c + Vector3(cos(a) * cos(t) * r, sin(t) * h, sin(a) * cos(t) * r)


## A square shaft tapering from half-width b at y0 to t at y1 (obelisks,
## towers); sides and top.
static func _frustum(mb, cx: float, cz: float, b: float, t: float, y0: float, y1: float, color: Color) -> void:
	var hgt := y1 - y0
	for o: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		var u := Vector3(-o.z, 0, o.x)
		var n := (o * hgt + Vector3.UP * (b - t)).normalized()
		var c0 := Vector3(cx, y0, cz) + o * b
		var c1 := Vector3(cx, y1, cz) + o * t
		mb.quad(c0 - u * b, c0 + u * b, c1 + u * t, c1 - u * t, n, color)
	mb.box(Vector3(cx, y1, cz), Vector3(t * 2.0, 0.02, t * 2.0), color)


## A flagpole at p, h tall, its flag a stack of plain colour bands flying
## toward +X (side 1) or -X (side -1); reaches 1.9 m to that side.
static func _flag(mb, out: Array, p: Vector3, h: float, colors: Array, side := 1.0) -> void:
	mb.cylinder(p, 0.09, h, Color(0.86, 0.87, 0.89), 5)
	mb.ball(p + Vector3(0, h + 0.12, 0), Vector3(0.15, 0.15, 0.15), GOLD, 5, 2)
	# A field in the first colour with a hoist band in the second: no
	# horizontal stripes, which too easily match a real national flag.
	mb.box(p + Vector3(side * 1.225, h - 0.85, 0), Vector3(1.35, 1.1, 0.04), colors[0])
	mb.box(p + Vector3(side * 0.325, h - 0.85, 0), Vector3(0.45, 1.1, 0.04), colors[1])
	out.append([p + Vector3(0, 1.0, 0), Vector3(0.3, 2.0, 0.3)])


## A modern pole lamp: steel pole and a flat LED head lit at night.
static func _pole_lamp(mb, out: Array, p: Vector3, h := 5.0) -> void:
	var steel := MeshBuilder.glow(STEEL, MeshBuilder.METAL)
	mb.cylinder(p, 0.1, h, steel, 5)
	mb.box(p + Vector3(0, h + 0.12, 0), Vector3(0.75, 0.16, 0.75), MeshBuilder.glow(Color(0.3, 0.32, 0.35), MeshBuilder.METAL))
	mb.box(p + Vector3(0, h - 0.04, 0), Vector3(0.55, 0.16, 0.55), MeshBuilder.glow(Props.LED, MeshBuilder.GLOW_LAMP))
	out.append([p + Vector3(0, 1.5, 0), Vector3(0.3, 3.0, 0.3)])


## A tall iron lamp standard with three globes (plazas).
static func _globe_lamp(mb, out: Array, p: Vector3) -> void:
	var iron := MeshBuilder.glow(IRON, MeshBuilder.GLOSS)
	var globe := MeshBuilder.glow(Props.LAMP_GLOW, MeshBuilder.GLOW_LAMP)
	mb.box(p + Vector3(0, 0.45, 0), Vector3(0.5, 0.9, 0.5), iron)
	mb.cylinder(p, 0.12, 4.6, iron, 5)
	mb.box(p + Vector3(0, 4.3, 0), Vector3(1.6, 0.1, 0.1), iron)
	for x: float in [-0.75, 0.0, 0.75]:
		mb.ball(p + Vector3(x, 4.75 + (0.35 if x == 0.0 else 0.0), 0), Vector3(0.3, 0.3, 0.3), globe, 6, 3)
	out.append([p + Vector3(0, 1.5, 0), Vector3(0.5, 3.0, 0.5)])


## A stone urn on a pedestal (library terrace, balustrades).
static func _urn(mb, p: Vector3, color: Color) -> void:
	mb.box(p + Vector3(0, 0.45, 0), Vector3(0.8, 0.9, 0.8), color.darkened(0.05))
	mb.cylinder(p + Vector3(0, 0.9, 0), 0.22, 0.3, color, 6)
	mb.ball(p + Vector3(0, 1.5, 0), Vector3(0.5, 0.42, 0.5), color, 7, 3)
	mb.cylinder(p + Vector3(0, 1.8, 0), 0.4, 0.15, color.lightened(0.05), 7)


## A thin board or iron fence panel from a to b (along X or Z), h tall;
## no collider (callers add one where it counts).
static func _fence_panel(mb, a: Vector3, b: Vector3, h: float, color: Color) -> void:
	var c := (a + b) * 0.5 + Vector3(0, h * 0.5, 0)
	mb.box(c, Vector3(maxf(absf(b.x - a.x), 0.06), h, maxf(absf(b.z - a.z), 0.06)), color)


## A fire engine (nose toward -Z before yaw), `length` metres.
## A compact palm: a straight ringed trunk and a tight crown of short
## fronds (about 2.8 m reach, against the street palm's 4 m), for plazas
## near a facade or a lot edge.
static func _palm(mb, out: Array, p: Vector3, rng: RandomNumberGenerator) -> void:
	var h := rng.randf_range(5.5, 7.5)
	mb.limb(p, p + Vector3(0, h, 0), 0.24, 0.16, MeshBuilder.glow(Color(0.58, 0.5, 0.4), MeshBuilder.SIDING), 6, false)
	var crown := p + Vector3(0, h + 0.1, 0)
	mb.clump(crown, Vector3(0.42, 0.4, 0.42), Color(0.45, 0.42, 0.25), rng.randi(), 6, 3)
	var green := Props._leaf(Color(0.33, 0.46, 0.22).lerp(Color(0.42, 0.52, 0.25), rng.randf()))
	var turn := rng.randf() * TAU
	for i in 8:
		var a := turn + TAU * i / 8.0
		Props._frond(mb, crown, a, rng.randf_range(2.0, 2.4), rng.randf_range(0.5, 0.8), green if i % 2 == 0 else green.lightened(0.06))
	out.append([p + Vector3(0, 1.5, 0), Vector3(0.45, 3.0, 0.45)])


static func _fire_engine(mb, out: Array, p: Vector3, yaw: float, length := 9.0) -> void:
	var saved: Transform3D = mb.xform
	mb.xform = saved * Transform3D(Basis(Vector3.UP, yaw), p)
	var red := MeshBuilder.glow(ENGINE_RED, MeshBuilder.GLOSS)
	var chrome := MeshBuilder.glow(STEEL, MeshBuilder.METAL)
	var hl := length * 0.5
	mb.box(Vector3(0, 1.55, -hl + 1.25), Vector3(2.5, 2.3, 2.5), red)
	mb.box(Vector3(0, 2.1, -hl - 0.02), Vector3(2.2, 0.9, 0.06), MeshBuilder.glow(Color(0.2, 0.25, 0.3), MeshBuilder.GLASS))
	mb.box(Vector3(0, 1.45, 1.25), Vector3(2.5, 2.1, length - 2.5), red)
	mb.box(Vector3(0, 2.62, 1.25), Vector3(2.3, 0.1, length - 2.6), MeshBuilder.glow(Color(0.9, 0.9, 0.88), MeshBuilder.GLOSS))
	mb.box(Vector3(0, 2.95, 0.6), Vector3(0.9, 0.3, length - 1.2), chrome)
	mb.box(Vector3(0, 2.8, -hl + 0.6), Vector3(1.8, 0.16, 0.4), MeshBuilder.glow(Color(1.0, 0.2, 0.15), MeshBuilder.GLOW_NEON))
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(s * 1.26, 1.0, 1.25), Vector3(0.04, 0.2, length - 2.6), MeshBuilder.glow(Color(0.95, 0.85, 0.3), MeshBuilder.GLOSS))
		for z: float in [-hl + 1.3, hl - 1.6]:
			Kit._wheel(mb, Vector3(s * 1.0, 0.5, z), 0.5, 0.35)
	mb.xform = saved
	Kit._col(out, p + Vector3(0, 1.5, 0), Vector3(2.5, 3.0, length), yaw)


## A plain white mail truck (nose toward -Z before yaw), no markings.
static func _mail_truck(mb, out: Array, p: Vector3, yaw: float) -> void:
	var saved: Transform3D = mb.xform
	mb.xform = saved * Transform3D(Basis(Vector3.UP, yaw), p)
	var white := MeshBuilder.glow(Color(0.94, 0.94, 0.93), MeshBuilder.GLOSS)
	mb.box(Vector3(0, 1.3, 0.4), Vector3(1.9, 2.0, 3.4), white)
	mb.box(Vector3(0, 0.9, -1.75), Vector3(1.8, 1.0, 1.0), white)
	mb.box(Vector3(0, 1.75, -1.32), Vector3(1.7, 0.7, 0.06), MeshBuilder.glow(Color(0.2, 0.25, 0.3), MeshBuilder.GLASS))
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(s * 0.96, 1.0, 0.4), Vector3(0.04, 0.16, 3.2), Color(0.2, 0.32, 0.6))
		for z: float in [-1.5, 1.4]:
			Kit._wheel(mb, Vector3(s * 0.85, 0.36, z), 0.36, 0.24)
	mb.xform = saved
	Kit._col(out, p + Vector3(0, 1.15, 0), Vector3(1.9, 2.3, 4.5), yaw)


## A yellow school bus (nose toward -Z before yaw), no lettering.
static func _school_bus(mb, out: Array, p: Vector3, yaw: float) -> void:
	var saved: Transform3D = mb.xform
	mb.xform = saved * Transform3D(Basis(Vector3.UP, yaw), p)
	var yellow := MeshBuilder.glow(Color(0.98, 0.72, 0.1), MeshBuilder.GLOSS)
	mb.box(Vector3(0, 1.75, 0.6), Vector3(2.4, 2.5, 9.6), yellow)
	mb.box(Vector3(0, 1.1, -4.9), Vector3(2.3, 1.2, 1.4), yellow)
	mb.box(Vector3(0, 3.02, 0.6), Vector3(2.2, 0.06, 9.4), MeshBuilder.glow(Color(0.94, 0.93, 0.9), MeshBuilder.GLOSS))
	var glass := MeshBuilder.glow(Color(0.18, 0.24, 0.3), MeshBuilder.GLASS)
	mb.box(Vector3(0, 2.3, -4.22), Vector3(2.2, 0.9, 0.06), glass)
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(s * 1.21, 2.3, 0.8), Vector3(0.06, 0.8, 8.6), glass)
		mb.box(Vector3(s * 1.22, 1.15, 0.6), Vector3(0.04, 0.12, 9.6), DARK)
		for z: float in [-3.9, 3.4]:
			Kit._wheel(mb, Vector3(s * 1.0, 0.5, z), 0.5, 0.35)
	mb.xform = saved
	Kit._col(out, p + Vector3(0, 1.5, 0), Vector3(2.4, 3.0, 11.0), yaw)


## A flat-topped car park or wing roof seen from above: membrane only.
static func _membrane(mb, cx: float, cz: float, w: float, d: float, top: float, color := ROOF_GREY) -> void:
	mb.box(Vector3(cx, top + 0.02, cz), Vector3(w, 0.04, d), MeshBuilder.glow(color, MeshBuilder.ROOF))


# --- City government landmarks -------------------------------------------------

## City Hall: a white Beaux-Arts hall after the US Capitol and SF City Hall.
## A central block under a drum ringed with columns and a tall ribbed dome
## with a lantern; two long wings with pedimented pavilions; a pedimented
## portico of eight columns up a broad stair; a paved forecourt with lawn
## panels, lamps and flagpoles.
static func city_hall(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var stone := _stone(LIMESTONE)
	var base_c := _stone(LIMESTONE.darkened(0.14))
	var white := _stone(MARBLE)
	var lead := MeshBuilder.glow(LEAD, MeshBuilder.SEAM_ROOF)
	const PH := 2.4
	const CH := 20.0
	const WH := 16.0
	var back := d * 0.5 - 2.0
	var fz := -d * 0.5 + d * 0.36
	var cw := clampf(w * 0.36, 14.0, 34.0)
	var bd := back - fz
	var ccz := (fz + back) * 0.5
	var pw := cw * 0.72
	var pd := clampf(d * 0.11, 4.0, 7.0)
	var sd := clampf(d * 0.11, 4.0, 7.0)
	var pz0 := fz - pd
	var sz0 := pz0 - sd
	# Ground: paved forecourt, lawn panels with low hedges, lawn behind.
	Kit._pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, _paving())
	for s: float in [-1.0, 1.0]:
		var xa := s * (pw * 0.5 + 4.5)
		var xb := s * (w * 0.5 - 1.0)
		var lx0 := minf(xa, xb)
		var lx1 := maxf(xa, xb)
		Kit._pad(mb, lx0, lx1, -d * 0.5 + 1.5, fz + 2.5, _grass(), 0.04)
		Kit._hedge(mb, out, Vector3(lx0 + 0.3, 0, -d * 0.5 + 1.8), Vector3(lx1 - 0.3, 0, -d * 0.5 + 1.8), 0.6, false, 0.6)
		var path_x := (lx0 + lx1) * 0.5
		Kit._pad(mb, path_x - 1.0, path_x + 1.0, -d * 0.5 + 1.5, fz + 2.5, _paving(PAVER.lightened(0.08)), 0.06)
	Kit._pad(mb, -w * 0.5 + 1.0, w * 0.5 - 1.0, back, d * 0.5 - 0.5, _grass(), 0.04)
	# Wings, each with a pedimented centre pavilion and an end pavilion.
	var wz0 := fz + 4.0
	var wz1 := back - 2.0
	var wcz := (wz0 + wz1) * 0.5
	var wd := wz1 - wz0
	var wx0 := cw * 0.5
	var wx1 := w * 0.5 - 1.0
	var ww := wx1 - wx0
	for s: float in [-1.0, 1.0]:
		var wx := s * (wx0 + wx1) * 0.5
		mb.box(Vector3(wx, WH * 0.5, wcz), Vector3(ww, WH, wd), stone)
		Kit._col(out, Vector3(wx, WH * 0.5, wcz - 0.6), Vector3(ww, WH, wd + 1.2))
		mb.box(Vector3(wx, PH * 0.5, wcz), Vector3(ww + 0.3, PH, wd + 0.3), base_c)
		_cornice(mb, wx, wcz, ww, wd, WH, white, 0.35, 0.8)
		_parapet_roof(mb, wx, wcz, ww, wd, WH, white, 1.0)
		var nwin := maxi(3, int(ww / 2.8))
		for f in 3:
			var y := PH + 1.9 + f * 4.2
			Kit._windows(mb, Vector3(wx - ww * 0.5 + 0.6, y, wz0), Vector3(wx + ww * 0.5 - 0.6, y, wz0), nwin, Vector2(1.2, 2.3), rng, Vector3.FORWARD, 0.45)
			Kit._windows(mb, Vector3(wx - ww * 0.5 + 0.6, y, wz1), Vector3(wx + ww * 0.5 - 0.6, y, wz1), nwin, Vector2(1.2, 2.3), rng, Vector3.BACK, 0.45)
			Kit._windows(mb, Vector3(s * wx1, y, wz0 + 0.6), Vector3(s * wx1, y, wz1 - 0.6), maxi(2, int(wd / 3.0)), Vector2(1.2, 2.3), rng, Vector3(s, 0, 0), 0.45)
		for k in nwin + 1:
			var px := wx - ww * 0.5 + 0.6 + (ww - 1.2) * k / nwin
			mb.box(Vector3(px, (PH + WH - 0.8) * 0.5, wz0 - 0.12), Vector3(0.5, WH - 0.8 - PH, 0.24), white)
		# Centre pavilion: four columns, an entablature and a pediment.
		var pvw := clampf(ww * 0.36, 6.0, 10.0)
		mb.box(Vector3(wx, WH * 0.5, wz0 - 0.6), Vector3(pvw, WH, 1.2), stone)
		_colonnade(mb, wx - pvw * 0.5 + 0.7, wx + pvw * 0.5 - 0.7, wz0 - 1.7, PH, WH - PH - 1.2, 4, 0.42, white)
		mb.box(Vector3(wx, WH - 0.6, wz0 - 1.2), Vector3(pvw + 0.3, 1.2, 1.4), white)
		Kit._gable(mb, wx, wz0 - 0.7, WH, pvw + 0.5, 2.6, 2.2, lead, white, true)
		# End pavilion, a little taller and forward.
		var ex := s * (wx1 - 3.0)
		mb.box(Vector3(ex, (WH + 1.2) * 0.5, wcz - 0.5), Vector3(6.0, WH + 1.2, wd + 1.0), stone)
		_parapet_roof(mb, ex, wcz - 0.5, 6.0, wd + 1.0, WH + 1.2, white, 0.8)
	# Central block.
	Kit._solid(mb, out, Vector3(0, CH * 0.5, ccz), Vector3(cw, CH, bd), stone)
	mb.box(Vector3(0, PH * 0.5, ccz), Vector3(cw + 0.3, PH, bd + 0.3), base_c)
	_cornice(mb, 0, ccz, cw, bd, CH, white, 0.4, 0.9)
	_parapet_roof(mb, 0, ccz, cw, bd, CH, white, 1.0)
	for s: float in [-1.0, 1.0]:
		_face_windows(mb, Vector3(s * (pw * 0.5 + 0.6), 0, fz), Vector3(s * (cw * 0.5 - 0.5), 0, fz), PH + 1.9, 4, 4.0, 2.4, Vector2(1.1, 2.2), rng, Vector3.FORWARD)
	_face_windows(mb, Vector3(-cw * 0.5 + 0.8, 0, back), Vector3(cw * 0.5 - 0.8, 0, back), PH + 1.9, 4, 4.0, 2.6, Vector2(1.1, 2.2), rng, Vector3.BACK)
	# Portico: podium, eight columns, entablature, pediment, doors.
	mb.box(Vector3(0, PH * 0.5, fz - pd * 0.5), Vector3(pw + 1.0, PH, pd), base_c)
	const COLH := 12.0
	_colonnade(mb, -pw * 0.5 + 0.8, pw * 0.5 - 0.8, pz0 + 0.8, PH, COLH, 8, 0.55, white, true)
	_colonnade(mb, -pw * 0.5 + 0.8, pw * 0.5 - 0.8, pz0 + pd * 0.62, PH, COLH, 2, 0.55, white, true)
	mb.box(Vector3(0, PH + COLH + 0.7, fz - pd * 0.5 + 0.1), Vector3(pw + 0.4, 1.4, pd + 0.2), white)
	Kit._gable(mb, 0, fz - pd * 0.5 + 0.3, PH + COLH + 1.4, pw + 0.8, pd + 1.0, 3.4, lead, white, true)
	mb.box(Vector3(0, PH + 3.0, fz - 0.05), Vector3(3.0, 6.0, 0.1), _lit())
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(s * pw * 0.25, PH + 2.6, fz - 0.05), Vector3(1.8, 4.6, 0.1), _lit(WARM_LIT.darkened(0.2)))
	Kit._col(out, Vector3(0, (PH + COLH) * 0.5, fz - pd * 0.5), Vector3(pw + 1.0, PH + COLH, pd))
	# Broad stair with cheek blocks; the lower steps stay walkable.
	_stair(mb, -pw * 0.5 - 1.0, pw * 0.5 + 1.0, sz0, pz0, PH, 8, white)
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(s * (pw * 0.5 + 1.6), PH * 0.5 + 0.2, (sz0 + pz0) * 0.5), Vector3(1.2, PH + 0.4, sd), base_c)
	Kit._col(out, Vector3(0, PH * 0.5, pz0 - sd * 0.35), Vector3(pw + 3.2, PH, sd * 0.7))
	# Drum ringed with sixteen columns, a ribbed dome and a lantern.
	var r := minf(cw, bd) * 0.36
	var dc := Vector3(0, CH, ccz)
	const COL := 8.0
	mb.cylinder(dc, r + 1.9, 1.0, base_c, 16)
	mb.cylinder(dc + Vector3(0, 1.0, 0), r, COL + 2.8, stone, 16)
	for i in 16:
		var a := TAU * (i + 0.5) / 16.0
		_column(mb, dc + Vector3(cos(a) * (r + 1.1), 1.0, sin(a) * (r + 1.1)), COL, 0.38, white, 6)
		var aw := TAU * i / 16.0
		_rbox(mb, dc + Vector3(cos(aw) * (r + 0.04), 1.0 + COL * 0.5, sin(aw) * (r + 0.04)), Vector3(1.1, 3.6, 0.08), PI * 0.5 - aw, Buildings._window(rng, 0.6))
	mb.cylinder(dc + Vector3(0, 1.0 + COL, 0), r + 1.7, 0.9, white, 16)
	var dome_y := CH + 1.0 + COL + 2.8
	var dr := r * 0.96
	var dh := r * 0.82 + 1.0
	_dome(mb, Vector3(0, dome_y, ccz), dr, dh, MeshBuilder.glow(DOME, MeshBuilder.GLOSS), MeshBuilder.glow(GOLD, MeshBuilder.METAL))
	var top := dome_y + dh
	mb.cylinder(Vector3(0, top - 0.6, ccz), 1.4, 2.8, _lit(Color(0.5, 0.45, 0.35)), 8)
	for i in 8:
		var a := TAU * (i + 0.5) / 8.0
		mb.box(Vector3(cos(a) * 1.45, top + 0.8, ccz + sin(a) * 1.45), Vector3(0.3, 2.8, 0.3), white)
	Kit._cone(mb, Vector3(0, top + 2.2, ccz), 1.8, 1.3, MeshBuilder.glow(GOLD, MeshBuilder.METAL), 8)
	mb.ball(Vector3(0, top + 3.6, ccz), Vector3(0.3, 0.3, 0.3), MeshBuilder.glow(GOLD, MeshBuilder.METAL), 6, 3)
	mb.cylinder(Vector3(0, top + 3.6, ccz), 0.06, 0.9, MeshBuilder.glow(GOLD, MeshBuilder.METAL), 4)
	# Lamps at the stair foot and the forecourt, flagpoles, oaks.
	for s: float in [-1.0, 1.0]:
		Props.gas_lamp(mb, out, Vector3(s * (pw * 0.5 + 1.6), 0, sz0 - 0.8))
		Props.gas_lamp(mb, out, Vector3(s * (pw * 0.5 + 3.4), 0, -d * 0.5 + 0.6))
		_flag(mb, out, Vector3(s * (pw * 0.5 + 6.0), 0, -d * 0.5 + 0.6), 12.0, CITY_FLAG, s)
		var oak_x := s * (w * 0.5 - 5.5)
		if absf(oak_x) > pw * 0.5 + 9.0 and fz + 2.5 > -d * 0.5 + 9.0:
			Props.oak(mb, out, Vector3(oak_x, 0, -d * 0.5 + 6.5), rng)


## County Courthouse after NY's Foley Square: a wide stair up to a deep
## colonnade of ten columns under a pediment, a six-storey granite block
## behind it.
static func county_courthouse(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var stone := _stone(GRANITE.lightened(0.28))
	var base_c := _stone(GRANITE.lightened(0.1))
	var white := _stone(MARBLE)
	var lead := MeshBuilder.glow(LEAD.darkened(0.1), MeshBuilder.SEAM_ROOF)
	const PH := 2.8
	const FH := 3.5
	const FLOORS := 6
	var sd := clampf(d * 0.2, 5.0, 9.0)
	var pd := clampf(d * 0.16, 4.5, 7.0)
	var sz0 := -d * 0.5 + 1.0
	var pz0 := sz0 + sd
	var fz := pz0 + pd
	var back := d * 0.5 - 1.0
	var bw := w - 2.0
	var bd := back - fz
	var bcz := (fz + back) * 0.5
	var H := PH + FLOORS * FH
	Kit._pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, _paving(PAVER.darkened(0.04)))
	Kit._solid(mb, out, Vector3(0, H * 0.5, bcz), Vector3(bw, H, bd), stone)
	mb.box(Vector3(0, PH * 0.5, bcz), Vector3(bw + 0.3, PH, bd + 0.3), base_c)
	_cornice(mb, 0, bcz, bw, bd, H, white, 0.4, 0.9)
	_parapet_roof(mb, 0, bcz, bw, bd, H, white, 1.0)
	Buildings._hvac(mb, Vector3(-bw * 0.2, H, bcz + bd * 0.2), Vector3(3.0, 1.2, 1.6))
	# A light well in the roof (the block is a hollow square in plan).
	mb.box(Vector3(0, H + 0.05, bcz + bd * 0.05), Vector3(bw * 0.3, 0.04, bd * 0.32), MeshBuilder.glow(Color(0.3, 0.32, 0.34), MeshBuilder.CONCRETE))
	var pw := minf(w * 0.82, bw - 2.0)
	for s: float in [-1.0, 1.0]:
		_face_windows(mb, Vector3(s * (pw * 0.5 + 0.4), 0, fz), Vector3(s * (bw * 0.5 - 0.3), 0, fz), PH + 1.6, FLOORS, FH, 2.4, Vector2(1.0, 1.9), rng, Vector3.FORWARD)
		_face_windows(mb, Vector3(s * bw * 0.5, 0, fz + 0.5), Vector3(s * bw * 0.5, 0, back - 0.5), PH + 1.6, FLOORS, FH, 2.8, Vector2(1.0, 1.9), rng, Vector3(s, 0, 0))
	_face_windows(mb, Vector3(-bw * 0.5 + 0.5, 0, back), Vector3(bw * 0.5 - 0.5, 0, back), PH + 1.6, FLOORS, FH, 2.8, Vector2(1.0, 1.9), rng, Vector3.BACK)
	_face_windows(mb, Vector3(-pw * 0.5 + 1.0, 0, fz), Vector3(pw * 0.5 - 1.0, 0, fz), PH + 1.6 + 4.0 * FH, 2, FH, 2.6, Vector2(1.0, 1.9), rng, Vector3.FORWARD)
	# Deep colonnade: ten columns in front, eight behind, under a pediment.
	const COLH := 12.5
	var ncol := clampi(int(pw / 4.0) + 1, 8, 10)
	mb.box(Vector3(0, PH * 0.5, pz0 + pd * 0.5), Vector3(pw + 1.0, PH, pd), base_c)
	_colonnade(mb, -pw * 0.5 + 0.9, pw * 0.5 - 0.9, pz0 + 0.9, PH, COLH, ncol, 0.6, white, true)
	_colonnade(mb, -pw * 0.5 + 0.9 + pw / ncol, pw * 0.5 - 0.9 - pw / ncol, pz0 + pd * 0.6, PH, COLH, ncol - 2, 0.55, white, true)
	mb.box(Vector3(0, PH + COLH + 0.75, pz0 + pd * 0.5 + 0.2), Vector3(pw + 0.4, 1.5, pd + 0.6), white)
	Kit._gable(mb, 0, pz0 + pd * 0.5 + 0.3, PH + COLH + 1.5, pw + 0.6, pd + 1.2, 3.8, lead, white, true)
	for k in 3:
		mb.box(Vector3((k - 1) * pw * 0.22, PH + 2.8, fz - 0.05), Vector3(2.4, 5.6, 0.1), _lit())
	Kit._col(out, Vector3(0, (PH + COLH) * 0.5, pz0 + pd * 0.5), Vector3(pw + 1.0, PH + COLH, pd))
	# The wide stair, lamps on its cheeks, flags at the corners.
	_stair(mb, -pw * 0.5 - 0.5, pw * 0.5 + 0.5, sz0, pz0, PH, 9, white)
	Kit._col(out, Vector3(0, PH * 0.5, pz0 - sd * 0.38), Vector3(pw + 1.0, PH, sd * 0.76))
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(s * (pw * 0.5 + 1.1), (PH + 0.5) * 0.5, (sz0 + pz0) * 0.5 + 0.2), Vector3(1.2, PH + 0.5, sd - 0.4), base_c)
		Props.gas_lamp(mb, out, Vector3(s * (pw * 0.5 + 1.1), PH + 0.5, sz0 + sd * 0.25))
		_flag(mb, out, Vector3(s * (w * 0.5 - 2.4), 0, -d * 0.5 + 0.8), 11.0, COUNTY_FLAG, s)


## Federal Building in the Federal Triangle manner: a seven-storey
## limestone block round an open courtyard, red tile hipped roofs, an
## arched ground-floor arcade and a colonnade over the entrance.
static func federal_building(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var stone := _stone(LIMESTONE)
	var base_c := _stone(LIMESTONE.darkened(0.1))
	var white := _stone(MARBLE)
	var tile := MeshBuilder.glow(TILE_RED, MeshBuilder.SEAM_ROOF)
	const H := 25.0
	const AH := 5.5
	var x0 := -w * 0.5 + 1.0
	var x1 := w * 0.5 - 1.0
	var z0 := -d * 0.5 + 3.0
	var z1 := d * 0.5 - 1.0
	var rd := clampf(minf(w, d) * 0.26, 8.0, 15.0)
	var bw := x1 - x0
	var cz := (z0 + z1) * 0.5
	var cd := z1 - z0 - rd * 2.0
	Kit._pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, _paving())
	# Four ranges.
	var ranges := [
		[Vector3(0, H * 0.5, z0 + rd * 0.5), Vector3(bw, H, rd)],
		[Vector3(0, H * 0.5, z1 - rd * 0.5), Vector3(bw, H, rd)],
		[Vector3(x0 + rd * 0.5, H * 0.5, cz), Vector3(rd, H, cd)],
		[Vector3(x1 - rd * 0.5, H * 0.5, cz), Vector3(rd, H, cd)],
	]
	for rg in ranges:
		Kit._solid(mb, out, rg[0], rg[1], stone)
	mb.box(Vector3(0, AH * 0.5, z0 + rd * 0.5), Vector3(bw + 0.3, AH, rd + 0.3), base_c)
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(s * (bw * 0.5 + 0.075), AH * 0.5, cz), Vector3(0.15, AH, z1 - z0), base_c)
	# A cornice band round the outside only (a full box would lid the courtyard).
	var cd_all := z1 - z0
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(0, H - 0.45, cz + s * (cd_all * 0.5 - 0.2)), Vector3(bw + 0.8, 0.8, 1.2), white)
		mb.box(Vector3(s * (bw * 0.5 - 0.2), H - 0.45, cz), Vector3(1.2, 0.8, cd_all - 1.6), white)
	# Red tile hips over each range (they cross at the corners).
	var rise := rd * 0.3
	Kit._hip(mb, Vector3(0, H, z0 + rd * 0.5), bw + 0.8, rd + 0.8, rise, tile)
	Kit._hip(mb, Vector3(0, H, z1 - rd * 0.5), bw + 0.8, rd + 0.8, rise, tile)
	for s: float in [-1.0, 1.0]:
		Kit._hip(mb, Vector3(s * (bw * 0.5 - rd * 0.5), H, cz), rd + 0.8, z1 - z0 + 0.8, rise, tile)
	# Courtyard: paving, a lawn, a fountain, clipped trees.
	var ix := bw * 0.5 - rd
	var iz0 := z0 + rd
	var iz1 := z1 - rd
	Kit._pad(mb, -ix, ix, iz0, iz1, _paving(PAVER.lightened(0.05)), 0.04)
	Kit._pad(mb, -ix * 0.7, ix * 0.7, iz0 + cd * 0.15, iz1 - cd * 0.15, _grass(), 0.06)
	var fc := Vector3(0, 0, cz)
	mb.cylinder(fc, minf(cd, ix) * 0.22, 0.6, white, 12)
	mb.cylinder(fc + Vector3(0, 0.6, 0), minf(cd, ix) * 0.22 - 0.3, 0.01, MeshBuilder.glow(WATER.lightened(0.2), MeshBuilder.GLASS), 12)
	mb.cylinder(fc, 0.35, 1.8, white, 6)
	Kit._col(out, fc + Vector3(0, 0.4, 0), Vector3(minf(cd, ix) * 0.4, 0.8, minf(cd, ix) * 0.4))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			Kit._bush(mb, Vector3(sx * ix * 0.55, 0, cz + sz * cd * 0.28), 1.3, rng)
	# Arcade on the street face and the ends; a big arch at the entrance.
	var arch := MeshBuilder.glow(Color(0.2, 0.18, 0.15), MeshBuilder.GLOW_WINDOW)
	_arcade(mb, Vector3(x0 + 1.0, 0, z0 - 0.15), Vector3(x1 - 1.0, 0, z0 - 0.15), 4.2, 2.8, 4.6, Vector3.FORWARD, arch, 4.5)
	_arch_open(mb, Vector3(0, 0, z0 - 0.15), Vector3.RIGHT, Vector3.FORWARD, 4.6, 7.0, _lit())
	for s: float in [-1.0, 1.0]:
		_arcade(mb, Vector3(s * (bw * 0.5 + 0.15), 0, z0 + 1.0), Vector3(s * (bw * 0.5 + 0.15), 0, z1 - 1.0), 4.2, 2.8, 4.6, Vector3(s, 0, 0), arch)
		_face_windows(mb, Vector3(s * bw * 0.5, 0, z0 + 0.6), Vector3(s * bw * 0.5, 0, z1 - 0.6), AH + 1.6, 6, 3.1, 3.0, Vector2(1.1, 1.8), rng, Vector3(s, 0, 0))
		# Courtyard faces of the side ranges.
		_face_windows(mb, Vector3(s * ix, 0, iz0 + 0.5), Vector3(s * ix, 0, iz1 - 0.5), 1.8, 7, 3.3, 3.0, Vector2(1.0, 1.7), rng, Vector3(-s, 0, 0))
	_face_windows(mb, Vector3(x0 + 0.6, 0, z0), Vector3(x1 - 0.6, 0, z0), AH + 1.6, 6, 3.1, 3.0, Vector2(1.1, 1.8), rng, Vector3.FORWARD)
	_face_windows(mb, Vector3(x0 + 0.6, 0, z1), Vector3(x1 - 0.6, 0, z1), 1.8, 7, 3.3, 3.0, Vector2(1.1, 1.8), rng, Vector3.BACK)
	_face_windows(mb, Vector3(-ix + 0.5, 0, iz1), Vector3(ix - 0.5, 0, iz1), 1.8, 7, 3.3, 3.0, Vector2(1.0, 1.7), rng, Vector3.FORWARD)
	# Colonnade over the entrance (second to fifth floors).
	var cw := clampf(bw * 0.3, 10.0, 22.0)
	_colonnade(mb, -cw * 0.5, cw * 0.5, z0 - 0.75, AH, 13.5, 6, 0.5, white, true)
	mb.box(Vector3(0, AH + 14.0, z0 - 0.5), Vector3(cw + 1.6, 1.0, 1.2), white)
	mb.box(Vector3(0, AH + 0.25, z0 - 0.5), Vector3(cw + 1.6, 0.5, 1.2), white)
	# Flags and lamps at the street.
	for s: float in [-1.0, 1.0]:
		_flag(mb, out, Vector3(s * (cw * 0.5 + 3.0), 0, -d * 0.5 + 1.0), 10.0, FEDERAL_FLAG, s)
		Props.gas_lamp(mb, out, Vector3(s * (w * 0.5 - 2.0), 0, -d * 0.5 + 1.2))


## Public Library, Beaux-Arts like NY's on Fifth Avenue: a raised terrace
## with urns, a three-arch portico with paired columns, end pavilions, and
## a long reading room lit by a glass skylight roof.
static func public_library(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var stone := _stone(Color(0.9, 0.87, 0.8))
	var base_c := _stone(Color(0.8, 0.77, 0.7))
	var white := _stone(MARBLE)
	const H := 15.0
	const TH := 0.5
	var fz := -d * 0.5 + clampf(d * 0.3, 7.0, 13.0)
	var back := d * 0.5 - 1.0
	var bw := w - 2.0
	var bd := back - fz
	var bcz := (fz + back) * 0.5
	var pw := clampf(w * 0.36, 12.0, 22.0)
	var pdp := 3.6
	var pvw := clampf(w * 0.14, 5.0, 8.0)
	var tz0 := -d * 0.5 + 2.2
	Kit._pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, _paving(PAVER.darkened(0.03)))
	# Terrace with lawn panels, a low balustrade with urns and front steps.
	mb.box(Vector3(0, TH * 0.5, (tz0 + fz) * 0.5), Vector3(bw, TH, fz - tz0), base_c)
	for s: float in [-1.0, 1.0]:
		var xa := s * (pw * 0.5 + 2.5)
		var xb := s * (bw * 0.5 - 1.0)
		Kit._pad(mb, minf(xa, xb), maxf(xa, xb), tz0 + 1.2, fz - pdp - 1.4, _grass(), TH + 0.02)
		var bx0 := s * (pw * 0.5 + 2.0)
		var bx1 := s * (bw * 0.5)
		mb.box(Vector3((bx0 + bx1) * 0.5, TH + 0.45, tz0 + 0.25), Vector3(absf(bx1 - bx0), 0.9, 0.5), white)
		Kit._col(out, Vector3((bx0 + bx1) * 0.5, (TH + 0.9) * 0.5, tz0 + 0.25), Vector3(absf(bx1 - bx0), TH + 0.9, 0.5))
		for k in 2:
			_urn(mb, Vector3(lerpf(bx0, bx1, 0.15 + k * 0.6), TH + 0.9, tz0 + 0.25), white)
	_stair(mb, -pw * 0.5 - 1.6, pw * 0.5 + 1.6, -d * 0.5 + 0.6, tz0, TH, 3, white)
	# Main block.
	Kit._solid(mb, out, Vector3(0, H * 0.5, bcz), Vector3(bw, H, bd), stone)
	mb.box(Vector3(0, 2.2, bcz), Vector3(bw + 0.3, 4.4, bd + 0.3), base_c)
	_cornice(mb, 0, bcz, bw, bd, H, white, 0.4, 0.8)
	_parapet_roof(mb, 0, bcz, bw, bd, H, white, 1.0)
	var span0 := pw * 0.5 + 0.6
	var span1 := bw * 0.5 - pvw - 0.4
	for s: float in [-1.0, 1.0]:
		if span1 - span0 > 2.0:
			var n := maxi(1, int((span1 - span0) / 3.2))
			for k in n:
				var x := s * lerpf(span0, span1, (k + 0.5) / n)
				_arch_open(mb, Vector3(x, 5.2, fz), Vector3.RIGHT, Vector3.FORWARD, 1.9, 5.6, Buildings._window(rng, 0.55))
				Kit._windows(mb, Vector3(x, 2.4, fz), Vector3(x, 2.4, fz), 1, Vector2(1.0, 1.4), rng, Vector3.FORWARD, 0.3)
		_face_windows(mb, Vector3(s * bw * 0.5, 0, fz + 1.0), Vector3(s * bw * 0.5, 0, back - 1.0), 2.4, 2, 5.6, 3.2, Vector2(1.2, 2.4), rng, Vector3(s, 0, 0))
	_face_windows(mb, Vector3(-bw * 0.5 + 1.0, 0, back), Vector3(bw * 0.5 - 1.0, 0, back), 2.4, 2, 5.6, 3.2, Vector2(1.2, 2.4), rng, Vector3.BACK)
	# End pavilions.
	for s: float in [-1.0, 1.0]:
		var px := s * (bw * 0.5 - pvw * 0.5)
		Kit._solid(mb, out, Vector3(px, (H + 1.2) * 0.5, fz - 0.6 + 2.0), Vector3(pvw, H + 1.2, 4.0), stone)
		_parapet_roof(mb, px, fz + 1.4, pvw, 4.0, H + 1.2, white, 0.8)
		_arch_open(mb, Vector3(px, 4.6, fz - 0.6), Vector3.RIGHT, Vector3.FORWARD, pvw * 0.42, 7.5, Buildings._window(rng, 0.6))
		for k: float in [-1.0, 1.0]:
			mb.box(Vector3(px + k * pvw * 0.36, (H + 0.4) * 0.5, fz - 0.75), Vector3(0.6, H - 0.4, 0.3), white)
	# Three-arch portico with paired columns and urns on the attic.
	var pz := fz - pdp * 0.5
	Kit._solid(mb, out, Vector3(0, (H + 1.6) * 0.5, pz), Vector3(pw, H + 1.6, pdp), white)
	_parapet_roof(mb, 0, pz, pw, pdp, H + 1.6, white, 0.6)
	for k in 3:
		_arch_open(mb, Vector3((k - 1) * pw * 0.29, TH, fz - pdp), Vector3.RIGHT, Vector3.FORWARD, pw * 0.2, 9.5, _lit())
	for k in 4:
		var px := (-1.5 + k) * pw * 0.29
		for o: float in [-0.55, 0.55]:
			_column(mb, Vector3(px + o, TH, fz - pdp - 0.7), 11.0, 0.42, white, 8, true)
		_urn(mb, Vector3(px, H + 1.6, pz), white)
	mb.box(Vector3(0, TH + 11.6, fz - pdp - 0.45), Vector3(pw, 1.2, 1.3), white)
	# Reading room: a clerestory under a long glass skylight.
	var rw := bw * 0.72
	var rdp := clampf(bd * 0.42, 6.0, 12.0)
	var rz := back - rdp * 0.5 - 1.6
	mb.box(Vector3(0, H + 1.6, rz), Vector3(rw, 3.2, rdp), stone)
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(0, H + 1.7, rz + s * (rdp * 0.5 + 0.05)), Vector3(rw - 1.0, 1.6, 0.08), _lit(Color(0.42, 0.4, 0.34)))
	var sky := MeshBuilder.glow(Color(0.55, 0.66, 0.72), MeshBuilder.GLOW_WINDOW)
	var srise := rdp * 0.28
	Kit._gable(mb, 0, rz, H + 3.2, rw + 0.4, rdp + 0.4, srise, sky, stone)
	var ribs := int(rw / 2.4)
	var rib := MeshBuilder.glow(Color(0.25, 0.27, 0.3), MeshBuilder.METAL)
	for k in ribs + 1:
		var x := -rw * 0.5 + rw * k / ribs
		for s: float in [-1.0, 1.0]:
			Kit._beam(mb, Vector3(x, H + 3.25, rz + s * (rdp * 0.5 + 0.2)), Vector3(x, H + 3.25 + srise, rz), 0.14, rib)
	mb.box(Vector3(0, H + 3.25 + srise, rz), Vector3(rw + 0.4, 0.18, 0.3), rib)
	# Lamps and flagpoles at the steps.
	for s: float in [-1.0, 1.0]:
		Props.gas_lamp(mb, out, Vector3(s * (pw * 0.5 + 2.4), 0, -d * 0.5 + 1.0))
		_flag(mb, out, Vector3(s * (w * 0.5 - 2.4), 0, -d * 0.5 + 0.8), 10.0, CITY_FLAG, s)


## Police Headquarters: a seven-storey glass and concrete tower with a
## rooftop helipad (a painted circle), antennas, a glazed lobby, a garage
## with a sally port on one side and cruisers out front.
static func police_headquarters(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var conc := _stone(Color(0.8, 0.8, 0.78))
	var glass := MeshBuilder.glow(Color(0.3, 0.42, 0.52), MeshBuilder.GLASS)
	const FLOORS := 7
	const FH := 3.6
	var H := 1.0 + FLOORS * FH
	var gw := clampf(w * 0.3, 10.0, 16.0)
	var tx0 := -w * 0.5 + 1.0
	var tx1 := w * 0.5 - 2.0 - gw
	var tw := tx1 - tx0
	var tcx := (tx0 + tx1) * 0.5
	var fz := -d * 0.5 + clampf(d * 0.24, 6.0, 10.0)
	var back := d * 0.5 - 1.0
	var td := back - fz
	var tcz := (fz + back) * 0.5
	Kit._pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, MeshBuilder.glow(ASPHALT, MeshBuilder.ASPHALT))
	Kit._pad(mb, tx0, tx1, -d * 0.5, fz, MeshBuilder.glow(CONCRETE, MeshBuilder.CONCRETE), 0.04)
	# Tower: concrete frame, glass bands, fins on the street face.
	Kit._solid(mb, out, Vector3(tcx, H * 0.5, tcz), Vector3(tw, H, td), conc)
	for f in FLOORS - 1:
		var y := 1.0 + (f + 1) * FH + FH * 0.5
		mb.box(Vector3(tcx, y, fz - 0.05), Vector3(tw - 0.6, FH * 0.66, 0.08), glass)
		mb.box(Vector3(tcx, y, back + 0.05), Vector3(tw - 0.6, FH * 0.66, 0.08), glass)
		mb.box(Vector3(tx0 - 0.05, y, tcz), Vector3(0.08, FH * 0.66, td - 0.6), glass)
		mb.box(Vector3(tx1 + 0.05, y, tcz), Vector3(0.08, FH * 0.66, td - 0.6), glass)
	var nf := int(tw / 3.0)
	for k in nf + 1:
		var x := tx0 + 0.3 + (tw - 0.6) * k / nf
		if absf(x - tcx) > 5.4:
			mb.box(Vector3(x, (H + 1.0) * 0.5, fz - 0.35), Vector3(0.35, H - 1.0, 0.7), conc)
	mb.box(Vector3(tcx, H - 0.7, fz - 0.12), Vector3(tw, 0.9, 0.24), POLICE_BLUE)
	# Lobby: double-height glazing, a cantilevered canopy, bollards.
	mb.box(Vector3(tcx, 3.8, fz - 0.06), Vector3(10.0, 7.2, 0.1), _lit(Color(0.32, 0.4, 0.48)))
	Kit._canopy(mb, out, tcx - 6.0, tcx + 6.0, fz - 3.6, fz, 7.6, 0.5, POLICE_BLUE, MeshBuilder.glow(Color(0.8, 0.81, 0.82), MeshBuilder.ROOF), [Vector3(tcx - 5.6, 0, fz - 3.2), Vector3(tcx + 5.6, 0, fz - 3.2)], Color(0.85, 0.86, 0.88))
	mb.box(Vector3(tcx, 6.9, fz - 3.62), Vector3(8.0, 0.25, 0.04), MeshBuilder.glow(Color(0.35, 0.55, 1.0), MeshBuilder.GLOW_NEON))
	for k in 5:
		mb.cylinder(Vector3(tcx - 5.0 + k * 2.5, 0, -d * 0.5 + 1.0), 0.25, 0.9, conc, 6)
	# Roof: parapet, helipad on posts, antennas.
	_parapet_roof(mb, tcx, tcz, tw, td, H, conc.darkened(0.08), 1.1)
	var hp := minf(tw, td) * 0.72
	var deck := H + 1.4
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			mb.box(Vector3(tcx + sx * hp * 0.4, H + 0.7, tcz + sz * hp * 0.4), Vector3(0.6, 1.4, 0.6), conc)
	mb.box(Vector3(tcx, deck - 0.15, tcz), Vector3(hp, 0.3, hp), MeshBuilder.glow(Color(0.33, 0.35, 0.37), MeshBuilder.CONCRETE))
	var paint := Color(0.96, 0.84, 0.2)
	_ring(mb, Vector3(tcx, deck + 0.02, tcz), hp * 0.27, hp * 0.33, paint, 28)
	_disc(mb, Vector3(tcx, deck + 0.01, tcz), hp * 0.27, Color(0.28, 0.3, 0.32), 20)
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(tcx, deck + 0.02, tcz + s * (hp * 0.5 - 0.3)), Vector3(hp - 0.6, 0.02, 0.2), TRIM)
		mb.box(Vector3(tcx + s * (hp * 0.5 - 0.3), deck + 0.02, tcz), Vector3(0.2, 0.02, hp - 0.6), TRIM)
	for k in 8:
		var a := TAU * k / 8.0
		var e := Vector3(cos(a), 0, sin(a))
		e = e / maxf(absf(e.x), absf(e.z)) * (hp * 0.5 - 0.15)
		mb.box(Vector3(tcx, deck + 0.1, tcz) + e, Vector3(0.3, 0.2, 0.3), MeshBuilder.glow(Color(0.4, 1.0, 0.5), MeshBuilder.GLOW_LAMP))
	mb.cylinder(Vector3(tcx + hp * 0.5 - 0.4, deck, tcz - hp * 0.5 + 0.4), 0.05, 2.2, STEEL, 4)
	mb.box(Vector3(tcx + hp * 0.5 - 0.4 + 0.5, deck + 2.0, tcz - hp * 0.5 + 0.4), Vector3(1.0, 0.3, 0.3), Color(1.0, 0.45, 0.1))
	for k in 3:
		var ax := tx0 + 1.2 + k * 1.6
		var az := back - 1.2
		var ah := 7.0 + k * 1.5
		mb.cylinder(Vector3(ax, H, az), 0.09, ah, STEEL, 4)
		mb.box(Vector3(ax, H + ah, az), Vector3(0.22, 0.22, 0.22), MeshBuilder.glow(Color(1.0, 0.15, 0.1), MeshBuilder.GLOW_NEON))
	Buildings._dish(mb, Vector3(tx1 - 1.2, H, back - 1.2))
	# Garage with the sally port.
	var gx0 := tx1 + 1.0
	var gx1 := w * 0.5 - 1.0
	var gcx := (gx0 + gx1) * 0.5
	var gz0 := fz + 2.0
	const GH := 7.4
	Kit._solid(mb, out, Vector3(gcx, GH * 0.5, (gz0 + back) * 0.5), Vector3(gx1 - gx0, GH, back - gz0), conc.darkened(0.04))
	_membrane(mb, gcx, (gz0 + back) * 0.5, gx1 - gx0 - 0.3, back - gz0 - 0.3, GH, Color(0.46, 0.47, 0.48))
	for y: float in [2.6, 6.0]:
		mb.box(Vector3(gx1 + 0.05, y, (gz0 + back) * 0.5), Vector3(0.08, 1.2, back - gz0 - 1.2), Color(0.12, 0.12, 0.13))
		mb.box(Vector3(gcx, y + 0.1, gz0 - 0.05), Vector3(gx1 - gx0 - 1.0, 1.0, 0.08), Color(0.12, 0.12, 0.13))
	var door_w := minf(gx1 - gx0 - 2.4, 6.0)
	mb.box(Vector3(gcx, 2.32, gz0 - 0.08), Vector3(door_w + 0.6, 4.6, 0.1), YELLOW)
	mb.box(Vector3(gcx, 2.1, gz0 - 0.12), Vector3(door_w, 4.2, 0.08), MeshBuilder.glow(Color(0.3, 0.32, 0.35), MeshBuilder.METAL))
	mb.box(Vector3(gcx - 0.4, 1.0, gz0 - 2.4), Vector3(door_w - 0.8, 0.12, 0.12), MeshBuilder.glow(Color(0.95, 0.3, 0.2), MeshBuilder.GLOSS))
	mb.box(Vector3(gx1 - 0.5, 1.1, gz0 - 2.4), Vector3(0.7, 2.2, 0.9), conc)
	Kit._col(out, Vector3(gx1 - 0.5, 1.1, gz0 - 2.4), Vector3(0.7, 2.2, 0.9))
	for k in 2:
		Kit._car(mb, out, Vector3(gcx - 2.0 + k * 4.0, GH, (gz0 + back) * 0.5 + 2.0), 0.0, Kit.PAINTS[k + 1], false)
	# Cruisers in marked bays out front, flags on the plaza.
	var nb := clampi(int((tw - 2.0) / 2.8), 2, 9)
	var bx0 := tx0 + 0.5
	Kit._stalls(mb, bx0, -d * 0.5 + 0.4, nb, 2.8, 5.0, 1.0)
	for k in nb:
		if k % 3 != 1 and absf(bx0 + 1.4 + k * 2.8 - tcx) > 6.5:
			Kit._cruiser(mb, out, Vector3(bx0 + 1.4 + k * 2.8, 0, -d * 0.5 + 2.9), PI)
	for k in 3:
		_flag(mb, out, Vector3(tcx - 3.0 + k * 3.0, 0, fz - 4.4), 9.0, FEDERAL_FLAG if k == 1 else CITY_FLAG)
	_pole_lamp(mb, out, Vector3(gx1 - 0.8, 0, -d * 0.5 + 0.6))


## Main Post Office after NY's Farley building: one long Corinthian
## colonnade across the whole front between end pavilions, a broad stair, a
## four-storey block with a skylit sorting hall in the roof.
static func main_post_office(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var stone := _stone(Color(0.88, 0.85, 0.77))
	var base_c := _stone(Color(0.78, 0.75, 0.68))
	var white := _stone(MARBLE)
	const PH := 2.0
	const H := 18.0
	var sz0 := -d * 0.5 + 0.6
	var sd := clampf(d * 0.15, 3.5, 6.0)
	var pz0 := sz0 + sd
	var pd := clampf(d * 0.14, 3.5, 5.5)
	var fz := pz0 + pd
	var back := d * 0.5 - 1.0
	var bw := w - 2.0
	var bd := back - fz
	var bcz := (fz + back) * 0.5
	var pvw := clampf(w * 0.09, 4.5, 7.0)
	var span := bw - pvw * 2.0
	Kit._pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, _paving())
	Kit._solid(mb, out, Vector3(0, H * 0.5, bcz), Vector3(bw, H, bd), stone)
	mb.box(Vector3(0, PH * 0.5, bcz), Vector3(bw + 0.3, PH, bd + 0.3), base_c)
	_cornice(mb, 0, bcz, bw, bd, H, white, 0.4, 0.9)
	_parapet_roof(mb, 0, bcz, bw, bd, H, white, 1.2)
	# Skylit hall in the roof.
	var skw := bw * 0.5
	var skd := bd * 0.42
	mb.box(Vector3(0, H + 0.35, bcz + bd * 0.08), Vector3(skw, 0.7, skd), MeshBuilder.glow(Color(0.5, 0.6, 0.66), MeshBuilder.GLOW_WINDOW))
	for k in int(skw / 3.0) + 1:
		mb.box(Vector3(-skw * 0.5 + k * skw / int(skw / 3.0), H + 0.74, bcz + bd * 0.08), Vector3(0.2, 0.06, skd), MeshBuilder.glow(Color(0.25, 0.27, 0.3), MeshBuilder.METAL))
	Buildings._hvac(mb, Vector3(-bw * 0.36, H, back - 2.2), Vector3(3.6, 1.2, 1.6))
	Buildings._hvac(mb, Vector3(bw * 0.36, H, back - 2.2), Vector3(3.6, 1.2, 1.6))
	_face_windows(mb, Vector3(-bw * 0.5 + 0.8, 0, back), Vector3(bw * 0.5 - 0.8, 0, back), PH + 1.6, 4, 3.8, 3.0, Vector2(1.2, 2.0), rng, Vector3.BACK)
	for s: float in [-1.0, 1.0]:
		_face_windows(mb, Vector3(s * bw * 0.5, 0, fz + 0.6), Vector3(s * bw * 0.5, 0, back - 0.6), PH + 1.6, 4, 3.8, 3.0, Vector2(1.2, 2.0), rng, Vector3(s, 0, 0))
	# End pavilions flush with the colonnade.
	for s: float in [-1.0, 1.0]:
		var px := s * (bw * 0.5 - pvw * 0.5)
		Kit._solid(mb, out, Vector3(px, (H + 0.6) * 0.5, (pz0 + fz + 2.0) * 0.5), Vector3(pvw, H + 0.6, fz + 2.0 - pz0), stone)
		_parapet_roof(mb, px, (pz0 + fz + 2.0) * 0.5, pvw, fz + 2.0 - pz0, H + 0.6, white, 1.2)
		mb.box(Vector3(px, PH * 0.5, (pz0 + fz) * 0.5), Vector3(pvw + 0.3, PH, pd + 0.3), base_c)
		_arch_open(mb, Vector3(px, PH + 1.0, pz0), Vector3.RIGHT, Vector3.FORWARD, pvw * 0.42, 6.5, Buildings._window(rng, 0.6))
		Kit._windows(mb, Vector3(px, PH + 10.5, pz0), Vector3(px, PH + 10.5, pz0), 1, Vector2(pvw * 0.36, 2.2), rng, Vector3.FORWARD, 0.5)
		for k: float in [-1.0, 1.0]:
			mb.box(Vector3(px + k * pvw * 0.38, (PH + H) * 0.5, pz0 - 0.15), Vector3(0.6, H - PH, 0.3), white)
	# The colonnade: podium, columns, entablature, doors and windows behind.
	mb.box(Vector3(0, PH * 0.5, (pz0 + fz) * 0.5), Vector3(span, PH, pd), base_c)
	const COLH := 13.0
	var ncol := maxi(4, int((span - 2.4) / 3.4) + 1)
	_colonnade(mb, -span * 0.5 + 1.2, span * 0.5 - 1.2, pz0 + 0.8, PH, COLH, ncol, 0.6, white, true)
	mb.box(Vector3(0, PH + COLH + 0.8, (pz0 + fz) * 0.5), Vector3(span, 1.6, pd + 0.2), white)
	_membrane(mb, 0, (pz0 + fz) * 0.5, span - 0.2, pd - 0.2, PH + COLH + 1.6, Color(0.7, 0.7, 0.68))
	var nd := maxi(3, int(span / 9.0))
	for k in nd:
		var x := -span * 0.5 + span * (k + 0.5) / nd
		mb.box(Vector3(x, PH + 2.2, fz - 0.05), Vector3(2.2, 4.4, 0.1), _lit())
		Kit._windows(mb, Vector3(x, PH + 8.0, fz), Vector3(x, PH + 8.0, fz), 1, Vector2(2.0, 3.6), rng, Vector3.FORWARD, 0.5)
	Kit._col(out, Vector3(0, (PH + COLH) * 0.5, (pz0 + fz) * 0.5), Vector3(span, PH + COLH, pd))
	# The broad stair across the whole colonnade; lamps; flags.
	_stair(mb, -span * 0.5, span * 0.5, sz0, pz0, PH, 6, white)
	Kit._col(out, Vector3(0, PH * 0.5, pz0 - sd * 0.32), Vector3(span, PH, sd * 0.64))
	for s: float in [-1.0, 1.0]:
		for k: float in [0.18, 0.42]:
			Props.gas_lamp(mb, out, Vector3(s * span * k, 0, -d * 0.5 + 0.2))
		_flag(mb, out, Vector3(s * (bw * 0.5 - pvw * 0.5), 0, -d * 0.5 + 0.6), 10.0, FEDERAL_FLAG, -s)


## Fire Headquarters: a three-storey brick house with three engine bays
## behind red doors, a hose-drying tower, a flagpole and an engine out on
## the apron.
static func fire_headquarters(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var brick := MeshBuilder.glow(Color(0.62, 0.28, 0.22), MeshBuilder.BRICK)
	var trim := _stone(Color(0.9, 0.87, 0.8))
	var red := MeshBuilder.glow(ENGINE_RED, MeshBuilder.GLOSS)
	const H := 12.6
	const GH := 5.0
	var fz := -d * 0.5 + clampf(d * 0.32, 7.0, 12.0)
	var back := d * 0.5 - 1.0
	var bw := w - 2.0
	var bd := back - fz
	var bcz := (fz + back) * 0.5
	Kit._pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, MeshBuilder.glow(CONCRETE, MeshBuilder.CONCRETE))
	Kit._solid(mb, out, Vector3(0, H * 0.5, bcz), Vector3(bw, H, bd), brick)
	_cornice(mb, 0, bcz, bw, bd, H, trim, 0.45, 0.8)
	_parapet_roof(mb, 0, bcz, bw, bd, H, trim.darkened(0.1), 0.8, Color(0.56, 0.56, 0.55))
	mb.box(Vector3(0, GH + 0.2, fz - 0.1), Vector3(bw + 0.2, 0.4, 0.2), trim)
	# Three bays: red sectional doors in stone surrounds, lines on the apron.
	var bayw := clampf((bw - 6.0) / 3.0 - 1.4, 3.4, 4.8)
	for k in 3:
		var x := (k - 1) * bw * 0.3
		mb.box(Vector3(x, 2.15, fz - 0.06), Vector3(bayw, 4.3, 0.1), red)
		mb.box(Vector3(x, 2.9, fz - 0.12), Vector3(bayw - 0.4, 0.55, 0.06), _lit(Color(0.35, 0.38, 0.42)))
		for j in 4:
			mb.box(Vector3(x, 0.6 + j * 0.9, fz - 0.12), Vector3(bayw, 0.05, 0.04), ENGINE_RED.darkened(0.35))
		mb.box(Vector3(x, 4.6, fz - 0.16), Vector3(bayw + 0.9, 0.6, 0.32), trim)
		for s: float in [-1.0, 1.0]:
			mb.box(Vector3(x + s * (bayw * 0.5 + 0.25), 2.15, fz - 0.13), Vector3(0.5, 4.3, 0.26), trim)
		for s: float in [-1.0, 1.0]:
			Kit._line(mb, Vector3(x + s * (bayw * 0.5), 0, -d * 0.5 + 0.5), Vector3(x + s * (bayw * 0.5), 0, fz - 0.2), 0.15, Color(0.8, 0.15, 0.12))
	_face_windows(mb, Vector3(-bw * 0.5 + 0.6, 0, fz), Vector3(bw * 0.5 - 0.6, 0, fz), GH + 1.8, 2, 3.6, 3.2, Vector2(1.1, 2.0), rng, Vector3.FORWARD, 0.5)
	for s: float in [-1.0, 1.0]:
		_face_windows(mb, Vector3(s * bw * 0.5, 0, fz + 0.6), Vector3(s * bw * 0.5, 0, back - 0.6), 2.4, 3, 3.6, 3.0, Vector2(1.1, 1.8), rng, Vector3(s, 0, 0), 0.5)
	# Hose-drying tower in the back corner.
	var ts := clampf(w * 0.15, 4.0, 6.0)
	var tx := bw * 0.5 - ts * 0.5
	var tz := back - ts * 0.5
	const TH := 21.0
	Kit._solid(mb, out, Vector3(tx, TH * 0.5, tz), Vector3(ts, TH, ts), brick)
	mb.box(Vector3(tx, TH - 0.3, tz), Vector3(ts + 0.5, 0.6, ts + 0.5), trim)
	for y: float in [14.0, 17.5]:
		mb.box(Vector3(tx, y, tz - ts * 0.5 - 0.04), Vector3(0.6, 2.2, 0.08), DARK)
		mb.box(Vector3(tx - ts * 0.5 - 0.04, y, tz), Vector3(0.08, 2.2, 0.6), DARK)
	mb.box(Vector3(tx, TH - 1.6, tz - ts * 0.5 - 0.04), Vector3(ts - 1.0, 1.4, 0.08), MeshBuilder.glow(Color(0.25, 0.22, 0.2), MeshBuilder.SIDING))
	Kit._hip(mb, Vector3(tx, TH, tz), ts + 0.6, ts + 0.6, 2.4, MeshBuilder.glow(Color(0.3, 0.32, 0.36), MeshBuilder.SEAM_ROOF))
	# Engine on the apron, flagpole, hydrant.
	var apron := fz + d * 0.5
	var el := minf(9.0, apron - 0.8)
	_fire_engine(mb, out, Vector3(0, 0, fz - el * 0.5 - 0.3), 0.0, el)
	_flag(mb, out, Vector3(-w * 0.5 + 1.2, 0, -d * 0.5 + 0.8), 9.0, CITY_FLAG)
	Props.hydrant(mb, out, Vector3(w * 0.5 - 1.2, 0, -d * 0.5 + 0.8))


## Founders Obelisk: a round paved plaza in a traffic circle, a lawn ring
## cut by four paths, a stepped base and a 50 m stone obelisk; four globe
## lamps and benches. Symmetric: it has no front.
static func founders_obelisk(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var r := minf(w, d) * 0.5 - 0.3
	var marble := _stone(MARBLE.darkened(0.03))
	var granite := _stone(GRANITE)
	Kit._pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, _grass(), 0.02)
	mb.cylinder(Vector3.ZERO, r, 0.18, granite, 32)
	_disc(mb, Vector3(0, 0.2, 0), r - 0.6, _paving(PAVER.lightened(0.04)), 32)
	var gap := 1.8
	for q in 4:
		var r0 := r * 0.42
		var r1 := r * 0.78
		var g0 := gap / r0
		_ring(mb, Vector3(0, 0.23, 0), r0, r1, _grass(), 6, q * PI * 0.5 + g0, (q + 1) * PI * 0.5 - g0)
		var a := (q + 0.5) * PI * 0.5
		Kit._bush(mb, Vector3(cos(a) * r * 0.6, 0.2, sin(a) * r * 0.6), 1.2, rng, Color(0.45, 0.3, 0.42))
	_ring(mb, Vector3(0, 0.24, 0), r * 0.78, r * 0.8, _stone(GRANITE.lightened(0.15)), 32)
	# Stepped base, pedestal, shaft and pyramidion.
	var s0 := clampf(r * 0.62, 8.0, 14.0)
	for k in 3:
		mb.box(Vector3(0, 0.2 + 0.45 + k * 0.9, 0), Vector3(s0 - k * 2.4, 0.9, s0 - k * 2.4), granite.lightened(0.04 * k))
	var py := 0.2 + 2.7
	mb.box(Vector3(0, py + 1.1, 0), Vector3(s0 - 6.2, 2.2, s0 - 6.2), marble)
	mb.box(Vector3(0, py + 2.15, 0), Vector3(s0 - 5.8, 0.3, s0 - 5.8), marble.lightened(0.05))
	var by := py + 2.3
	const TOP := 46.0
	_frustum(mb, 0, 0, 2.2, 1.45, by, TOP, marble)
	Kit._hip(mb, Vector3(0, TOP, 0), 2.9, 2.9, 4.0, marble)
	for o: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		mb.box(Vector3(0, TOP - 2.0, 0) + o * 1.52, Vector3(0.2, 0.2, 0.2), MeshBuilder.glow(Color(1.0, 0.15, 0.1), MeshBuilder.GLOW_NEON))
	Kit._col(out, Vector3(0, 1.55, 0), Vector3(s0, 2.9, s0))
	Kit._col(out, Vector3(0, TOP * 0.5, 0), Vector3(4.4, TOP, 4.4))
	# Lamps on the diagonals, benches facing out on the inner circle.
	for q in 4:
		var a := (q + 0.5) * PI * 0.5
		_globe_lamp(mb, out, Vector3(cos(a) * r * 0.89, 0.2, sin(a) * r * 0.89))
		var b := q * PI * 0.5 + PI * 0.25
		var p := Vector3(cos(b) * r * 0.36, 0.2, sin(b) * r * 0.36)
		if r * 0.36 > s0 * 0.75:
			Props.bench(mb, out, p, atan2(-cos(b), -sin(b)))


## Reflecting Pool: a long shallow pool with a granite coping on the mall
## axis, lawns, low hedges, elm walks with lamps, and paved ends. Long
## along local Z; it has no front.
static func reflecting_pool(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var granite := _stone(GRANITE.lightened(0.15))
	var pw := clampf(w * 0.5, 8.0, 22.0)
	var ez := clampf(d * 0.07, 5.0, 10.0)
	var pl := d - ez * 2.0 - 2.0
	var hx := pw * 0.5 + 0.9 + clampf((w * 0.5 - pw * 0.5 - 0.9) * 0.4, 1.0, 4.0)
	Kit._pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, _grass())
	for s: float in [-1.0, 1.0]:
		Kit._pad(mb, -w * 0.5 + 0.5, w * 0.5 - 0.5, s * (d * 0.5 - ez * 0.5) - ez * 0.5 + 0.5, s * (d * 0.5 - ez * 0.5) + ez * 0.5 - 0.5, _paving(), 0.04)
		var px0 := s * (hx + 0.6)
		var px1 := s * (w * 0.5 - 0.3)
		Kit._pad(mb, minf(px0, px1), maxf(px0, px1), -pl * 0.5, pl * 0.5, MeshBuilder.glow(Color(0.76, 0.72, 0.62), MeshBuilder.CONCRETE), 0.05)
	# The pool and its coping.
	mb.box(Vector3(0, 0.28, 0), Vector3(pw, 0.04, pl), MeshBuilder.glow(WATER, MeshBuilder.GLOSS))
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(s * (pw * 0.5 + 0.45), 0.22, 0), Vector3(0.9, 0.44, pl + 1.8), granite)
		mb.box(Vector3(0, 0.22, s * (pl * 0.5 + 0.45)), Vector3(pw, 0.44, 0.9), granite)
	Kit._col(out, Vector3(0, 0.5, 0), Vector3(pw + 1.8, 1.0, pl + 1.8))
	# Low hedges along the lawns, broken at the middle crossing.
	for s: float in [-1.0, 1.0]:
		for e: float in [-1.0, 1.0]:
			Kit._hedge(mb, out, Vector3(s * hx, 0, e * 4.0), Vector3(s * hx, 0, e * (pl * 0.5 - 0.5)), 0.8, true, 0.7)
	# Lamps and elms alternating along the walks.
	var n := clampi(int(pl / 16.0) + 1, 4, 8)
	for s: float in [-1.0, 1.0]:
		for k in n:
			var z := lerpf(-pl * 0.5 + 4.0, pl * 0.5 - 4.0, float(k) / (n - 1))
			Props.gas_lamp(mb, out, Vector3(s * (hx + 1.1), 0.05, z))
		for k in 5:
			var z := lerpf(-pl * 0.5 + 10.0, pl * 0.5 - 10.0, (k + 0.5) / 5.0)
			Props.street_tree(mb, out, Vector3(s * (w * 0.5 - 2.7), 0.05, z), rng)
		# Benches at the ends facing the water.
		for e: float in [-1.0, 1.0]:
			Props.bench(mb, out, Vector3(s * pw * 0.25, 0.05, e * (pl * 0.5 + 2.6)), 0.0 if e < 0.0 else PI)


## Ferry Building after SF's: a long two-storey arcaded hall under a lead
## roof with a skylit nave, end pavilions and a central clock tower (about
## 45 m, plain dials). Palms and lamps on the street plaza (-Z), a quay
## edge with bollards on the water side (+Z).
static func ferry_building(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var stone := _stone(SANDSTONE)
	var trim := _stone(SANDSTONE.lightened(0.25))
	var lead := MeshBuilder.glow(LEAD, MeshBuilder.SEAM_ROOF)
	const H := 12.0
	var fz := -d * 0.5 + clampf(d * 0.24, 4.5, 8.0)
	var qz := d * 0.5 - clampf(d * 0.12, 2.0, 4.0)
	var bw := w - 2.0
	var bd := qz - fz
	var bcz := (fz + qz) * 0.5
	var pvw := clampf(w * 0.08, 5.0, 8.0)
	Kit._pad(mb, -w * 0.5, w * 0.5, -d * 0.5, fz, _paving())
	Kit._pad(mb, -w * 0.5, w * 0.5, qz, d * 0.5, MeshBuilder.glow(CONCRETE, MeshBuilder.CONCRETE))
	Kit._solid(mb, out, Vector3(0, H * 0.5, bcz), Vector3(bw, H, bd), stone)
	mb.box(Vector3(0, 6.2, bcz), Vector3(bw + 0.2, 0.4, bd + 0.2), trim)
	_cornice(mb, 0, bcz, bw, bd, H, trim, 0.35, 0.7)
	var span := bw - pvw * 2.0
	var rise := clampf(bd * 0.2, 2.0, 3.6)
	Kit._gable(mb, 0, bcz, H, span + 0.4, bd + 0.6, rise, lead, stone)
	# Skylit nave along the ridge.
	var sky := MeshBuilder.glow(Color(0.5, 0.62, 0.68), MeshBuilder.GLOW_WINDOW)
	mb.box(Vector3(0, H + rise + 0.2, bcz), Vector3(span * 0.86, 1.0, 3.0), sky)
	Kit._gable(mb, 0, bcz, H + rise + 0.7, span * 0.86 + 0.3, 3.4, 0.9, sky, stone)
	# End pavilions.
	for s: float in [-1.0, 1.0]:
		var px := s * (bw * 0.5 - pvw * 0.5)
		Kit._solid(mb, out, Vector3(px, (H + 1.6) * 0.5, bcz), Vector3(pvw, H + 1.6, bd + 0.6), stone)
		Kit._hip(mb, Vector3(px, H + 1.6, bcz), pvw + 0.5, bd + 1.1, 1.8, lead)
		_arch_open(mb, Vector3(px, 0, fz - 0.3), Vector3.RIGHT, Vector3.FORWARD, pvw * 0.5, 5.4, _lit())
		_arch_open(mb, Vector3(px, 7.0, fz - 0.3), Vector3.RIGHT, Vector3.FORWARD, pvw * 0.36, 4.0, Buildings._window(rng, 0.5))
	# Arcades, front and back; arched windows above.
	var ts := clampf(minf(d * 0.36, w * 0.12), 5.0, 9.0)
	var arch_lit := _lit(Color(0.3, 0.25, 0.18))
	_arcade(mb, Vector3(-span * 0.5, 0, fz), Vector3(span * 0.5, 0, fz), 4.2, 3.0, 5.0, Vector3.FORWARD, arch_lit, ts * 0.5 + 1.0)
	_arcade(mb, Vector3(-span * 0.5, 7.0, fz), Vector3(span * 0.5, 7.0, fz), 4.2, 1.7, 3.4, Vector3.FORWARD, Buildings._window(rng, 0.5), ts * 0.5 + 1.0)
	_arcade(mb, Vector3(-span * 0.5, 0, qz), Vector3(span * 0.5, 0, qz), 4.2, 3.0, 5.0, Vector3.BACK, arch_lit)
	_arcade(mb, Vector3(-span * 0.5, 7.0, qz), Vector3(span * 0.5, 7.0, qz), 4.2, 1.7, 3.4, Vector3.BACK, Buildings._window(rng, 0.5))
	# Clock tower.
	var tz := fz - 1.0 + ts * 0.5
	Kit._solid(mb, out, Vector3(0, 15.0, tz), Vector3(ts, 30.0, ts), stone)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			mb.box(Vector3(sx * (ts * 0.5 - 0.2), 15.0, tz + sz * (ts * 0.5 - 0.2)), Vector3(0.9, 30.0, 0.9), trim)
	for y: float in [15.0, 19.5, 24.0]:
		_arch_open(mb, Vector3(0, y, fz - 1.0), Vector3.RIGHT, Vector3.FORWARD, 1.4, 3.0, Buildings._window(rng, 0.4))
	mb.box(Vector3(0, 30.4, tz), Vector3(ts + 0.8, 0.8, ts + 0.8), trim)
	var cs := ts - 0.6
	mb.box(Vector3(0, 33.9, tz), Vector3(cs, 6.2, cs), stone)
	var dial := MeshBuilder.glow(Color(0.98, 0.96, 0.88), MeshBuilder.GLOW_LAMP)
	for o: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		var c := Vector3(0, 34.0, tz) + o * (cs * 0.5)
		_wall_disc(mb, c + o * 0.04, o, cs * 0.36, DARK, 12)
		_wall_disc(mb, c + o * 0.08, o, cs * 0.31, dial, 12)
		var u := Vector3(-o.z, 0, o.x)
		Kit._beam(mb, c + o * 0.12, c + o * 0.12 + Vector3.UP * cs * 0.24, 0.16, DARK)
		Kit._beam(mb, c + o * 0.12, c + o * 0.12 + u * cs * 0.17 - Vector3.UP * cs * 0.06, 0.16, DARK)
	mb.box(Vector3(0, 37.2, tz), Vector3(cs + 0.6, 0.5, cs + 0.6), trim)
	var bs := ts - 1.8
	mb.box(Vector3(0, 39.3, tz), Vector3(bs, 3.8, bs), trim)
	for o: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		var u := Vector3(-o.z, 0, o.x)
		for k: float in [-0.22, 0.22]:
			_arch_open(mb, Vector3(0, 37.8, tz) + o * (bs * 0.5) + u * k * bs, u, o, bs * 0.3, 2.8, RECESS)
	Kit._hip(mb, Vector3(0, 41.2, tz), bs + 0.4, bs + 0.4, 3.4, lead)
	mb.cylinder(Vector3(0, 44.4, tz), 0.08, 1.8, GOLD, 4)
	mb.ball(Vector3(0, 46.2, tz), Vector3(0.2, 0.2, 0.2), GOLD, 5, 2)
	# Plaza palms and lamps; quay bollards and a rail on the water side.
	var np := maxi(2, int(bw / 12.0))
	for k in np:
		var x := lerpf(-bw * 0.5 + 4.0, bw * 0.5 - 4.0, float(k) / (np - 1))
		if absf(x) > ts * 0.5 + 3.0:
			_palm(mb, out, Vector3(x, 0, -d * 0.5 + 1.9), rng)
	for s: float in [-1.0, 1.0]:
		Props.gas_lamp(mb, out, Vector3(s * (ts * 0.5 + 1.5), 0, -d * 0.5 + 0.8))
	var nbol := int(w / 8.0)
	for k in nbol:
		mb.cylinder(Vector3(-w * 0.5 + 4.0 + k * 8.0, 0, d * 0.5 - 0.9), 0.25, 0.6, DARK, 6)
	_fence_panel(mb, Vector3(-w * 0.5 + 0.4, 0, d * 0.5 - 0.3), Vector3(w * 0.5 - 0.4, 0, d * 0.5 - 0.3), 1.1, MeshBuilder.glow(Color(0.2, 0.3, 0.32), MeshBuilder.GLOSS))
	Kit._col(out, Vector3(0, 0.55, d * 0.5 - 0.3), Vector3(w - 0.8, 1.1, 0.2))


## LED tower for a Times Square-like plaza: a dark glass mid-rise whose
## street faces carry big bright screen panels (abstract colour fields, no
## text), a lit ribbon over the shopfronts and a rooftop billboard.
static func led_tower(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var floors := rng.randi_range(10, 14)
	const FH := 3.5
	var H := floors * FH + 1.0
	var bw := w - 2.0
	var bd := d - 2.0
	var shell := MeshBuilder.glow(Color(0.2, 0.24, 0.3), MeshBuilder.GLASS)
	var frame := Color(0.16, 0.17, 0.19)
	Kit._pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, _paving(Color(0.6, 0.6, 0.62)))
	Kit._solid(mb, out, Vector3(0, H * 0.5, 0), Vector3(bw, H, bd), shell)
	for f in floors:
		var y := 1.0 + f * FH
		mb.box(Vector3(0, y, bd * 0.5 + 0.05), Vector3(bw, 0.35, 0.1), frame)
	# Shopfronts and the lit ribbon.
	var shop := _lit(Color(0.55, 0.62, 0.66))
	mb.box(Vector3(0, 2.6, -bd * 0.5 - 0.06), Vector3(bw - 1.0, 4.4, 0.1), shop)
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(s * (bw * 0.5 + 0.06), 2.6, 0), Vector3(0.1, 4.4, bd - 1.0), shop)
	mb.box(Vector3(0, 5.3, -bd * 0.5 - 1.0), Vector3(bw * 0.6, 0.3, 2.0), frame)
	var ribbon: Color = NEONS[rng.randi() % NEONS.size()]
	mb.box(Vector3(0, 6.6, -bd * 0.5 - 0.16), Vector3(bw, 0.9, 0.12), MeshBuilder.glow(ribbon, MeshBuilder.GLOW_NEON))
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(s * (bw * 0.5 + 0.16), 6.6, 0), Vector3(0.12, 0.9, bd), MeshBuilder.glow(ribbon, MeshBuilder.GLOW_NEON))
	# Screens: the front stacked high, the sides two each.
	var top := H - 3.0
	var y := 8.0
	var tier := 0
	while y < top - 4.0 and tier < 4:
		var h := minf(rng.randf_range(6.0, 10.0), top - y)
		var sw := bw * rng.randf_range(0.6, 0.95)
		var sx := rng.randf_range(-(bw - sw) * 0.5, (bw - sw) * 0.5)
		_screen(mb, Vector3(sx, y + h * 0.5, -bd * 0.5), Vector3.RIGHT, Vector3.FORWARD, Vector2(sw, h), rng)
		y += h + 1.2
		tier += 1
	for s: float in [-1.0, 1.0]:
		var n := Vector3(s, 0, 0)
		var y0 := 8.0
		for k in 2:
			var h := rng.randf_range(7.0, 11.0)
			if y0 + h > top:
				break
			var sw := bd * rng.randf_range(0.55, 0.9)
			var sz := -bd * 0.5 + sw * 0.5 + rng.randf_range(0.0, bd - sw)
			_screen(mb, Vector3(s * bw * 0.5, y0 + h * 0.5, sz), Vector3(0, 0, -s), n, Vector2(sw, h), rng)
			y0 += h + 1.5
	# Roof: parapet with a neon edge, a billboard on a steel frame.
	_parapet_roof(mb, 0, 0, bw, bd, H, frame, 1.0, Color(0.4, 0.41, 0.42))
	mb.box(Vector3(0, H + 1.05, -bd * 0.5 + 0.18), Vector3(bw, 0.1, 0.06), MeshBuilder.glow(NEONS[(rng.randi()) % NEONS.size()], MeshBuilder.GLOW_NEON))
	var bbw := bw * 0.8
	var bbz := -bd * 0.5 + 2.0
	for k in 4:
		var x := -bbw * 0.5 + bbw * k / 3.0
		mb.box(Vector3(x, H + 3.0, bbz + 0.6), Vector3(0.3, 6.0, 0.3), MeshBuilder.glow(STEEL, MeshBuilder.METAL))
		Kit._beam(mb, Vector3(x, H, bbz + 3.0), Vector3(x, H + 5.0, bbz + 0.7), 0.2, MeshBuilder.glow(STEEL, MeshBuilder.METAL))
	mb.box(Vector3(0, H + 4.6, bbz + 0.35), Vector3(bbw + 0.6, 5.4, 0.3), frame)
	_screen(mb, Vector3(0, H + 4.6, bbz + 0.2), Vector3.RIGHT, Vector3.FORWARD, Vector2(bbw, 4.8), rng)
	Buildings._hvac(mb, Vector3(-bw * 0.2, H, bd * 0.25), Vector3(3.0, 1.2, 1.8))


## A screen: a dark frame, a bright base field and a few abstract blocks
## and a disc in other colours (no text), facing n.
static func _screen(mb, c: Vector3, u: Vector3, n: Vector3, size: Vector2, rng: RandomNumberGenerator) -> void:
	_panel(mb, c + n * 0.08, u, n, size + Vector2(0.6, 0.6), DARK)
	var k0 := rng.randi() % NEONS.size()
	var base: Color = NEONS[k0]
	# Screen colours run darker than sign neon: the shader doubles neon at
	# night, and full-bright fields wash out to pastel under the tonemap.
	_panel(mb, c + n * 0.14, u, n, size, MeshBuilder.glow(base.darkened(0.5), MeshBuilder.GLOW_NEON))
	var blocks := rng.randi_range(2, 4)
	for k in blocks:
		var col: Color = NEONS[(k0 + 1 + k * 2) % NEONS.size()]
		var bw := size.x * rng.randf_range(0.18, 0.5)
		var bh := size.y * rng.randf_range(0.2, 0.6)
		var off := Vector2(rng.randf_range(-(size.x - bw) * 0.5, (size.x - bw) * 0.5), rng.randf_range(-(size.y - bh) * 0.5, (size.y - bh) * 0.5))
		_panel(mb, c + n * (0.18 + k * 0.03) + u * off.x + Vector3.UP * off.y, u, n, Vector2(bw, bh), MeshBuilder.glow(col.darkened(0.35), MeshBuilder.GLOW_NEON))
	if rng.randf() < 0.6:
		var r := minf(size.x, size.y) * rng.randf_range(0.15, 0.3)
		var off := rng.randf_range(-(size.x * 0.5 - r), size.x * 0.5 - r)
		_wall_disc(mb, c + n * 0.32 + u * off, n, r, MeshBuilder.glow(Color(0.6, 0.58, 0.54), MeshBuilder.GLOW_NEON), 10)


# --- Suburban government --------------------------------------------------------

## Suburban fire station: a brick apparatus hall with red doors under a
## metal gable (end to the street), crew quarters beside it, a small hose
## tower, an engine on the apron and a flagpole.
static func fire_station(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var brick := MeshBuilder.glow(Kit._pick(Kit.BRICKS, rng), MeshBuilder.BRICK)
	var red := MeshBuilder.glow(ENGINE_RED, MeshBuilder.GLOSS)
	var trim := _stone(Color(0.88, 0.86, 0.8))
	var tin := MeshBuilder.glow(Kit._pick([Color(0.55, 0.28, 0.22), Color(0.3, 0.32, 0.36), Color(0.64, 0.66, 0.68)], rng), MeshBuilder.SEAM_ROOF)
	var fz := -d * 0.5 + clampf(d * 0.38, 6.0, 10.0)
	var back := d * 0.5 - 1.0
	var bd := back - fz
	var bcz := (fz + back) * 0.5
	var hw := clampf(w * 0.55, 10.0, 20.0)
	var ax0 := -w * 0.5 + 1.0
	var acx := ax0 + hw * 0.5
	var bays := 2 if w < 30.0 else 3
	const AH := 7.0
	Kit._pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, _grass())
	Kit._pad(mb, ax0, ax0 + hw, -d * 0.5, fz, MeshBuilder.glow(CONCRETE, MeshBuilder.CONCRETE), 0.04)
	Kit._solid(mb, out, Vector3(acx, AH * 0.5, bcz), Vector3(hw, AH, bd), brick)
	Kit._gable(mb, acx, bcz, AH, hw + 0.6, bd + 0.6, clampf(hw * 0.2, 2.0, 3.6), tin, brick, true)
	var bayw := minf(4.0, hw / bays - 1.2)
	for k in bays:
		var x := ax0 + hw * (k + 0.5) / bays
		mb.box(Vector3(x, 2.1, fz - 0.06), Vector3(bayw, 4.2, 0.1), red)
		mb.box(Vector3(x, 3.0, fz - 0.12), Vector3(bayw - 0.4, 0.5, 0.06), _lit(Color(0.35, 0.38, 0.42)))
		mb.box(Vector3(x, 4.5, fz - 0.12), Vector3(bayw + 0.6, 0.4, 0.2), trim)
	# Crew quarters with a hip roof.
	var qx0 := ax0 + hw + 0.2
	var qx1 := w * 0.5 - 1.0
	var qw := qx1 - qx0
	if qw > 3.0:
		var qcx := (qx0 + qx1) * 0.5
		var qz0 := fz + 1.5
		Kit._solid(mb, out, Vector3(qcx, 2.0, (qz0 + back) * 0.5), Vector3(qw, 4.0, back - qz0), brick)
		Kit._hip(mb, Vector3(qcx, 4.0, (qz0 + back) * 0.5), qw + 0.8, back - qz0 + 0.8, 1.6, MeshBuilder.glow(Kit._pick(Kit.SHINGLES, rng), MeshBuilder.SIDING))
		Kit._windows(mb, Vector3(qx0, 1.8, qz0), Vector3(qx1, 1.8, qz0), maxi(1, int(qw / 2.5)), Vector2(1.1, 1.2), rng, Vector3.FORWARD, 0.5)
		mb.box(Vector3(qx0 + 1.0, 1.1, qz0 - 0.06), Vector3(1.0, 2.2, 0.1), MeshBuilder.glow(ENGINE_RED.darkened(0.2), MeshBuilder.GLOSS))
		Kit._stalls(mb, qx0 + 0.3, -d * 0.5 + 0.6, maxi(1, int((qw - 0.6) / 2.7)), 2.7, 5.0, 1.0)
		# Hose tower behind the quarters.
		var tx := qx1 - 1.6
		var tz := back - 1.6
		Kit._solid(mb, out, Vector3(tx, 5.5, tz), Vector3(3.0, 11.0, 3.0), brick)
		mb.box(Vector3(tx, 9.5, tz - 1.54), Vector3(1.6, 1.0, 0.08), MeshBuilder.glow(Color(0.25, 0.22, 0.2), MeshBuilder.SIDING))
		Kit._hip(mb, Vector3(tx, 11.0, tz), 3.6, 3.6, 1.6, tin)
		_flag(mb, out, Vector3(qx1 - 1.9, 0, -d * 0.5 + 0.6), 8.0, CITY_FLAG, -1.0)
	else:
		_flag(mb, out, Vector3(w * 0.5 - 2.0, 0, -d * 0.5 + 0.6), 8.0, CITY_FLAG, -1.0)
	Kit._windows(mb, Vector3(ax0 + hw, 2.2, fz + 1.0), Vector3(ax0 + hw, 2.2, back - 1.0), maxi(1, int(bd / 3.0)), Vector2(1.0, 1.1), rng, Vector3.RIGHT, 0.4)
	var apron := fz + d * 0.5
	var el := minf(8.5, apron - 0.6)
	if el > 5.0:
		_fire_engine(mb, out, Vector3(ax0 + hw * 0.5 / bays, 0, fz - el * 0.5 - 0.2), 0.0, el)


## Suburban post office: a one-storey brick building with a white stone
## entrance and pediment, a flagpole on a round bed, blue collection boxes
## at the kerb, a side lot with mail trucks at a dock.
static func post_office(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var brick := MeshBuilder.glow(Kit.BRICKS[0], MeshBuilder.BRICK)
	var white := _stone(MARBLE)
	const H := 5.6
	var fz := -d * 0.5 + clampf(d * 0.36, 6.0, 10.0)
	var back := d * 0.5 - 1.0
	var bw := clampf(w * 0.6, 12.0, 24.0)
	var bx := -w * 0.5 + 1.0 + bw * 0.5
	var bd := back - fz
	var bcz := (fz + back) * 0.5
	var lot0 := bx + bw * 0.5 + 0.5
	Kit._pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, _grass())
	Kit._pad(mb, lot0, w * 0.5 - 0.3, -d * 0.5, d * 0.5 - 0.3, MeshBuilder.glow(ASPHALT, MeshBuilder.ASPHALT), 0.04)
	Kit._pad(mb, bx - 1.2, bx + 1.2, -d * 0.5, fz, MeshBuilder.glow(CONCRETE, MeshBuilder.CONCRETE), 0.05)
	Kit._pad(mb, -w * 0.5, lot0, -d * 0.5, -d * 0.5 + 1.6, MeshBuilder.glow(CONCRETE, MeshBuilder.CONCRETE), 0.05)
	Kit._solid(mb, out, Vector3(bx, H * 0.5, bcz), Vector3(bw, H, bd), brick)
	_cornice(mb, bx, bcz, bw, bd, H, white, 0.3, 0.5)
	_parapet_roof(mb, bx, bcz, bw, bd, H, white, 0.6, Color(0.6, 0.6, 0.58))
	Buildings._hvac(mb, Vector3(bx + bw * 0.2, H, bcz + bd * 0.2), Vector3(2.2, 0.9, 1.2))
	# Entrance: stone surround, pediment, steps, doors, wall lamps.
	mb.box(Vector3(bx, 2.6, fz - 0.3), Vector3(4.4, 5.2, 0.6), white)
	Kit._gable(mb, bx, fz - 0.3, H - 0.4, 5.0, 1.0, 1.2, white, white, true)
	mb.box(Vector3(bx, 1.5, fz - 0.62), Vector3(2.2, 2.6, 0.08), _lit())
	mb.box(Vector3(bx, 0.2, fz - 1.2), Vector3(3.6, 0.4, 1.2), white)
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(bx + s * 1.6, 2.4, fz - 0.7), Vector3(0.25, 0.4, 0.25), MeshBuilder.glow(Props.LAMP_GLOW, MeshBuilder.GLOW_LAMP))
		var x0 := bx + s * 2.6
		var x1 := bx + s * (bw * 0.5 - 0.6)
		var n := maxi(1, int(absf(x1 - x0) / 2.6))
		for k in n:
			var x := lerpf(x0, x1, (k + 0.5) / n)
			mb.box(Vector3(x, 2.6, fz - 0.04), Vector3(1.6, 3.0, 0.06), white)
			Kit._windows(mb, Vector3(x, 2.6, fz - 0.02), Vector3(x, 2.6, fz - 0.02), 1, Vector2(1.2, 2.6), rng, Vector3.FORWARD, 0.5)
	_face_windows(mb, Vector3(bx - bw * 0.5, 0, fz + 1.0), Vector3(bx - bw * 0.5, 0, back - 1.0), 2.6, 1, 3.0, 3.0, Vector2(1.1, 2.0), rng, Vector3.LEFT)
	# Dock door on the lot side, mail trucks.
	mb.box(Vector3(bx + bw * 0.5 + 0.06, 1.7, back - 3.0), Vector3(0.1, 3.0, 3.4), MeshBuilder.glow(Color(0.55, 0.57, 0.6), MeshBuilder.METAL))
	var lw := w * 0.5 - 0.3 - lot0
	var nt := 2 if lw > 5.5 and bd > 9.0 else 1
	if lw > 2.6:
		for k in nt:
			_mail_truck(mb, out, Vector3(lot0 + 1.4 + k * 2.8, 0, back - 2.6), 0.0)
		Kit._stalls(mb, lot0 + 0.2, fz - 0.4, maxi(1, int((lw - 0.4) / 2.7)), 2.7, 5.0, -1.0)
	# Flagpole on a round bed, blue collection boxes at the kerb.
	var fp := Vector3(bx - 3.6, 0, (fz - d * 0.5) * 0.5 + 0.6)
	_disc(mb, fp + Vector3(0, 0.06, 0), 1.6, MeshBuilder.glow(Color(0.5, 0.36, 0.3), MeshBuilder.GRASS), 12)
	_flag(mb, out, fp, 9.0, FEDERAL_FLAG, 1.0)
	for k in 2:
		var cp := Vector3(bx + 2.4 + k * 1.0, 0, -d * 0.5 + 0.8)
		mb.box(cp + Vector3(0, 0.75, 0), Vector3(0.6, 1.1, 0.55), MeshBuilder.glow(Color(0.12, 0.25, 0.55), MeshBuilder.GLOSS))
		mb.box(cp + Vector3(0, 1.3, 0), Vector3(0.62, 0.12, 0.57), Color(0.1, 0.18, 0.4))
		mb.box(cp + Vector3(0, 1.0, -0.29), Vector3(0.4, 0.06, 0.02), DARK)
		Kit._col(out, cp + Vector3(0, 0.7, 0), Vector3(0.6, 1.4, 0.55))
	Kit._bush(mb, Vector3(bx + bw * 0.5 - 1.5, 0, fz - 1.4), 1.0, rng)
	Kit._bush(mb, Vector3(bx - bw * 0.5 + 1.5, 0, fz - 1.4), 1.0, rng)


## DMV office in California mid-century style: a long low flat-roofed box
## with an overhanging slab, a deep canopy on slim posts, a glazed front,
## a stone feature wall, a queue rail, a big lot and palms.
static func dmv_office(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var stucco := Color(0.93, 0.91, 0.86)
	var accent := Color(0.16, 0.5, 0.56)
	var stonewall := MeshBuilder.glow(Color(0.64, 0.58, 0.5), MeshBuilder.BRICK)
	const H := 4.6
	var fz := -d * 0.5 + clampf(d * 0.42, 9.0, 16.0)
	var back := d * 0.5 - 1.5
	var bw := clampf(w * 0.78, 16.0, 40.0)
	var bd := back - fz
	var bcz := (fz + back) * 0.5
	var cz0 := fz - clampf(d * 0.18, 4.0, 6.0)
	Kit._pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, MeshBuilder.glow(ASPHALT, MeshBuilder.ASPHALT))
	Kit._pad(mb, -bw * 0.5 - 1.0, bw * 0.5 + 1.0, cz0, back + 1.0, MeshBuilder.glow(CONCRETE, MeshBuilder.CONCRETE), 0.05)
	Kit._solid(mb, out, Vector3(0, H * 0.5, bcz), Vector3(bw, H, bd), stucco)
	# Overhanging roof slab with a white fascia.
	mb.box(Vector3(0, H + 0.25, bcz), Vector3(bw + 2.4, 0.5, bd + 2.4), TRIM)
	_membrane(mb, 0, bcz, bw + 2.0, bd + 2.0, H + 0.5, Color(0.84, 0.84, 0.82))
	Buildings._hvac(mb, Vector3(-bw * 0.2, H + 0.5, bcz + bd * 0.15), Vector3(3.0, 1.1, 1.6))
	Buildings._hvac(mb, Vector3(bw * 0.15, H + 0.5, bcz + bd * 0.15), Vector3(3.0, 1.1, 1.6))
	# Deep canopy on slim steel posts.
	var posts: Array = []
	var npost := maxi(2, int(bw / 6.5) + 1)
	for k in npost:
		posts.append(Vector3(lerpf(-bw * 0.5 + 1.5, bw * 0.5 - 1.5, float(k) / (npost - 1)), 0, cz0 + 0.4))
	Kit._canopy(mb, out, -bw * 0.5 + 1.0, bw * 0.5 - 1.0, cz0, fz, H - 0.2, 0.4, accent, MeshBuilder.glow(Color(0.86, 0.86, 0.84), MeshBuilder.ROOF), posts, STEEL)
	# Glazed front with mullions; a stone feature wall at one end.
	var g0 := -bw * 0.5 + 4.6
	var g1 := bw * 0.5 - 1.0
	mb.box(Vector3((g0 + g1) * 0.5, 1.9, fz - 0.05), Vector3(g1 - g0, 3.4, 0.08), _lit(Color(0.42, 0.52, 0.56)))
	var nm := int((g1 - g0) / 1.6)
	for k in nm + 1:
		mb.box(Vector3(g0 + (g1 - g0) * k / nm, 1.9, fz - 0.1), Vector3(0.08, 3.4, 0.06), DARK)
	Kit._solid(mb, out, Vector3(-bw * 0.5 + 2.0, (H + 0.3) * 0.5, fz - 0.2), Vector3(4.0, H + 0.3, 0.8), stonewall)
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(s * (bw * 0.5 + 0.04), 3.8, bcz), Vector3(0.08, 0.7, bd - 2.0), MeshBuilder.glow(Color(0.42, 0.52, 0.56), MeshBuilder.GLASS))
	# Queue rail: stanchions and a rope along the front.
	var q0 := g0 + 1.0
	var q1 := minf(g0 + 12.0, g1 - 1.0)
	for k in 6:
		var x := lerpf(q0, q1, k / 5.0)
		mb.cylinder(Vector3(x, 0.05, fz - 1.6), 0.05, 0.95, MeshBuilder.glow(STEEL, MeshBuilder.METAL), 4)
	mb.box(Vector3((q0 + q1) * 0.5, 0.92, fz - 1.6), Vector3(q1 - q0, 0.06, 0.06), Color(0.15, 0.25, 0.55))
	# Parking, palms, a low monument sign.
	var lot := cz0 + d * 0.5
	var n := int((w - 4.0) / 2.7)
	if lot > 6.0:
		Kit._stalls(mb, -n * 1.35, cz0 - 0.6, n, 2.7, minf(5.4, lot - 1.2), -1.0)
	for k in 3:
		var x := lerpf(-w * 0.5 + 1.8, w * 0.5 - 1.8, k * 0.5)
		if k != 1 or lot < 6.0:
			_palm(mb, out, Vector3(x * (w * 0.5 - 2.9) / (w * 0.5 - 1.8), 0, -d * 0.5 + 1.9), rng)
	var sp := Vector3(w * 0.25, 0, -d * 0.5 + 0.8)
	mb.box(sp + Vector3(0, 0.45, 0), Vector3(3.6, 0.9, 0.6), MeshBuilder.glow(CONCRETE, MeshBuilder.CONCRETE))
	mb.box(sp + Vector3(0, 1.3, 0), Vector3(3.2, 0.9, 0.4), MeshBuilder.glow(accent, MeshBuilder.GLOSS))
	mb.box(sp + Vector3(0, 1.3, -0.22), Vector3(2.8, 0.3, 0.04), MeshBuilder.glow(Color(0.95, 0.8, 0.3), MeshBuilder.GLOW_NEON))
	Kit._col(out, sp + Vector3(0, 0.9, 0), Vector3(3.6, 1.8, 0.6))


## Sheriff station: tan stucco under terracotta hips with a green trim
## band, a two-storey entry tower, a sally-port garage, a radio mast,
## cruisers in the lot and a flagpole.
static func sheriff_station(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var stucco := Color(0.86, 0.78, 0.62)
	var brown := Color(0.4, 0.31, 0.22)
	var green := Color(0.2, 0.36, 0.25)
	var tile := MeshBuilder.glow(Kit.TERRACOTTA, MeshBuilder.SEAM_ROOF)
	const H := 4.6
	var fz := -d * 0.5 + clampf(d * 0.36, 6.0, 10.0)
	var back := d * 0.5 - 1.0
	var bw := clampf(w * 0.62, 12.0, 26.0)
	var bx := -w * 0.5 + 1.0 + bw * 0.5
	var bd := back - fz
	var bcz := (fz + back) * 0.5
	Kit._pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, MeshBuilder.glow(ASPHALT, MeshBuilder.ASPHALT))
	Kit._pad(mb, -w * 0.5, w * 0.5, back, d * 0.5, _grass(), 0.04)
	Kit._pad(mb, bx - bw * 0.5, bx + bw * 0.5, fz - 1.4, fz, MeshBuilder.glow(CONCRETE, MeshBuilder.CONCRETE), 0.05)
	Kit._solid(mb, out, Vector3(bx, H * 0.5, bcz), Vector3(bw, H, bd), stucco)
	mb.box(Vector3(bx, 0.5, bcz), Vector3(bw + 0.1, 1.0, bd + 0.1), brown)
	mb.box(Vector3(bx, H - 0.3, bcz), Vector3(bw + 0.1, 0.4, bd + 0.1), green)
	Kit._hip(mb, Vector3(bx, H, bcz), bw + 1.2, bd + 1.2, clampf(bd * 0.22, 1.5, 2.6), tile)
	Kit._windows(mb, Vector3(bx - bw * 0.5, 2.3, fz), Vector3(bx - 2.6, 2.3, fz), maxi(1, int((bw * 0.5 - 2.6) / 2.4)), Vector2(1.2, 1.3), rng, Vector3.FORWARD, 0.5)
	Kit._windows(mb, Vector3(bx + 2.6, 2.3, fz), Vector3(bx + bw * 0.5, 2.3, fz), maxi(1, int((bw * 0.5 - 2.6) / 2.4)), Vector2(1.2, 1.3), rng, Vector3.FORWARD, 0.5)
	_face_windows(mb, Vector3(bx - bw * 0.5, 0, fz + 1.0), Vector3(bx - bw * 0.5, 0, back - 1.0), 2.3, 1, 3.0, 2.8, Vector2(1.2, 1.3), rng, Vector3.LEFT)
	# Entry tower.
	var ez := fz - 0.6 + 2.5
	Kit._solid(mb, out, Vector3(bx, 3.9, ez), Vector3(5.0, 7.8, 5.0), stucco.lightened(0.05))
	mb.box(Vector3(bx, 7.5, ez), Vector3(5.1, 0.4, 5.1), green)
	Kit._hip(mb, Vector3(bx, 7.8, ez), 5.8, 5.8, 2.0, tile)
	mb.box(Vector3(bx, 1.5, fz - 0.66), Vector3(2.4, 2.8, 0.08), _lit(Color(0.35, 0.4, 0.42)))
	mb.box(Vector3(bx, 5.6, fz - 0.66), Vector3(2.0, 1.4, 0.08), Buildings._window(rng, 0.6))
	mb.box(Vector3(bx, 3.3, fz - 0.7), Vector3(3.6, 0.35, 0.1), MeshBuilder.glow(GOLD, MeshBuilder.METAL))
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(bx + s * 1.7, 2.6, fz - 0.8), Vector3(0.25, 0.4, 0.25), MeshBuilder.glow(Props.LAMP_GLOW, MeshBuilder.GLOW_LAMP))
	# Sally-port garage beside it.
	var gx0 := bx + bw * 0.5 + 0.6
	var gx1 := w * 0.5 - 1.0
	if gx1 - gx0 > 4.0:
		var gcx := (gx0 + gx1) * 0.5
		var gz0 := fz + 1.5
		Kit._solid(mb, out, Vector3(gcx, 2.6, (gz0 + back) * 0.5), Vector3(gx1 - gx0, 5.2, back - gz0), stucco.darkened(0.05))
		mb.box(Vector3(gcx, 4.9, (gz0 + back) * 0.5), Vector3(gx1 - gx0 + 0.1, 0.4, back - gz0 + 0.1), green)
		_membrane(mb, gcx, (gz0 + back) * 0.5, gx1 - gx0 - 0.2, back - gz0 - 0.2, 5.2, Color(0.55, 0.53, 0.5))
		var dw := minf(gx1 - gx0 - 1.6, 4.4)
		mb.box(Vector3(gcx, 2.12, gz0 - 0.06), Vector3(dw + 0.5, 4.2, 0.1), YELLOW)
		mb.box(Vector3(gcx, 1.9, gz0 - 0.1), Vector3(dw, 3.8, 0.08), MeshBuilder.glow(Color(0.32, 0.33, 0.35), MeshBuilder.METAL))
		# Radio mast behind the garage.
		var mp := Vector3(gx1 - 1.2, 5.2, back - 1.2)
		for k in 3:
			var a := TAU * k / 3.0
			Kit._beam(mb, mp + Vector3(cos(a) * 0.6, 0, sin(a) * 0.6), mp + Vector3(cos(a) * 0.12, 13.0, sin(a) * 0.12), 0.08, Color(0.85, 0.3, 0.25))
		for k in 5:
			var y := 1.5 + k * 2.5
			var rr := lerpf(0.6, 0.12, y / 13.0)
			mb.box(mp + Vector3(0, y, 0), Vector3(rr * 1.7, 0.06, rr * 1.7), Color(0.85, 0.85, 0.86))
		mb.box(mp + Vector3(0, 13.1, 0), Vector3(0.2, 0.2, 0.2), MeshBuilder.glow(Color(1.0, 0.15, 0.1), MeshBuilder.GLOW_NEON))
	# Cruisers in front, flagpole.
	var nb := clampi(int((w - 6.0) / 2.8), 2, 8)
	var x0 := -w * 0.5 + 3.0
	Kit._stalls(mb, x0, fz - 1.5, nb, 2.8, minf(5.4, fz - 1.5 + d * 0.5 - 0.3), -1.0)
	if fz - 1.5 - 5.0 > -d * 0.5:
		for k in nb:
			if k % 2 == 0 and absf(x0 + 1.4 + k * 2.8 - bx) > 2.0:
				Kit._cruiser(mb, out, Vector3(x0 + 1.4 + k * 2.8, 0, fz - 1.5 - 2.6), PI)
	_flag(mb, out, Vector3(-w * 0.5 + 1.0, 0, -d * 0.5 + 0.6), 8.0, COUNTY_FLAG, 1.0)


## Public school: a two-storey brick front range and two one-storey stucco
## wings round a courtyard (a U open to the back) with blacktop games and a
## covered walk; a drop-off lane with a school bus and a flagpole in front.
static func public_school(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var brick := MeshBuilder.glow(Color(0.66, 0.36, 0.28), MeshBuilder.BRICK)
	var stucco := Color(0.92, 0.88, 0.78)
	var accent := Color(0.16, 0.42, 0.62)
	const H2 := 8.0
	const H1 := 4.5
	var fz := -d * 0.5 + clampf(d * 0.22, 6.0, 12.0)
	var back := d * 0.5 - 1.0
	var x0 := -w * 0.5 + 1.0
	var x1 := w * 0.5 - 1.0
	var rd := clampf(d * 0.26, 8.0, 13.0)
	var sw := clampf(w * 0.2, 8.0, 14.0)
	var iz0 := fz + rd
	var wd := back - iz0
	Kit._pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, _grass())
	Kit._pad(mb, -w * 0.5 + 0.5, w * 0.5 - 0.5, -d * 0.5 + 0.3, -d * 0.5 + 4.4, MeshBuilder.glow(ASPHALT, MeshBuilder.ASPHALT), 0.04)
	Kit._line(mb, Vector3(-w * 0.5 + 0.5, 0, -d * 0.5 + 4.4), Vector3(w * 0.5 - 0.5, 0, -d * 0.5 + 4.4), 0.25, YELLOW)
	Kit._pad(mb, -2.0, 2.0, -d * 0.5 + 4.4, fz, MeshBuilder.glow(CONCRETE, MeshBuilder.CONCRETE), 0.05)
	# Front range.
	Kit._solid(mb, out, Vector3(0, H2 * 0.5, fz + rd * 0.5), Vector3(x1 - x0, H2, rd), brick)
	Kit._flat_roof(mb, 0, fz + rd * 0.5, x1 - x0, rd, H2, rng, Color(0.75, 0.74, 0.7), true)
	for f in 2:
		var y := 1.8 + f * 3.6
		Kit._windows(mb, Vector3(x0 + 0.5, y, fz), Vector3(-3.5, y, fz), maxi(2, int((-3.5 - x0) / 3.0)), Vector2(2.2, 1.5), rng, Vector3.FORWARD, 0.4)
		Kit._windows(mb, Vector3(3.5, y, fz), Vector3(x1 - 0.5, y, fz), maxi(2, int((x1 - 3.5) / 3.0)), Vector2(2.2, 1.5), rng, Vector3.FORWARD, 0.4)
		Kit._windows(mb, Vector3(-x1 + sw, y, iz0), Vector3(x1 - sw, y, iz0), maxi(2, int((x1 - sw) * 2.0 / 3.0)), Vector2(2.2, 1.5), rng, Vector3.BACK, 0.4)
	# Entrance block, canopy.
	Kit._solid(mb, out, Vector3(0, (H2 + 1.2) * 0.5, fz - 0.6), Vector3(7.0, H2 + 1.2, 1.4), MeshBuilder.glow(stucco, MeshBuilder.CONCRETE))
	mb.box(Vector3(0, 1.5, fz - 1.34), Vector3(3.6, 2.8, 0.08), _lit(Color(0.4, 0.48, 0.52)))
	mb.box(Vector3(0, 6.2, fz - 1.34), Vector3(4.6, 2.2, 0.08), Buildings._window(rng, 0.5))
	mb.box(Vector3(0, H2 + 0.6, fz - 1.36), Vector3(5.0, 0.5, 0.06), accent)
	Kit._canopy(mb, out, -3.0, 3.0, fz - 4.0, fz - 1.3, 3.4, 0.35, accent, MeshBuilder.glow(Color(0.8, 0.81, 0.82), MeshBuilder.ROOF), [Vector3(-2.7, 0, fz - 3.7), Vector3(2.7, 0, fz - 3.7)], TRIM)
	# Wings.
	for s: float in [-1.0, 1.0]:
		var wx := s * (x1 - sw * 0.5)
		if wd > 3.0:
			Kit._solid(mb, out, Vector3(wx, H1 * 0.5, (iz0 + back) * 0.5), Vector3(sw, H1, wd), stucco)
			Kit._flat_roof(mb, wx, (iz0 + back) * 0.5, sw, wd, H1, rng, Color(0.7, 0.68, 0.62), true)
			mb.box(Vector3(wx, H1 - 0.3, (iz0 + back) * 0.5), Vector3(sw + 0.1, 0.35, wd + 0.1), accent)
			Kit._windows(mb, Vector3(s * x1, 2.0, iz0 + 0.6), Vector3(s * x1, 2.0, back - 0.6), maxi(1, int(wd / 3.0)), Vector2(2.2, 1.4), rng, Vector3(s, 0, 0), 0.4)
			Kit._windows(mb, Vector3(s * (x1 - sw), 2.0, iz0 + 0.6), Vector3(s * (x1 - sw), 2.0, back - 0.6), maxi(1, int(wd / 3.0)), Vector2(2.2, 1.4), rng, Vector3(-s, 0, 0), 0.4)
		Kit._windows(mb, Vector3(s * x1, 1.8, fz + 0.6), Vector3(s * x1, 1.8, iz0 - 0.6), maxi(1, int(rd / 3.0)), Vector2(2.0, 1.4), rng, Vector3(s, 0, 0), 0.4)
	# Courtyard: blacktop with game lines, a covered walk, trees.
	var cx := x1 - sw
	if wd > 3.0:
		Kit._pad(mb, -cx, cx, iz0, back, MeshBuilder.glow(ASPHALT.lightened(0.05), MeshBuilder.ASPHALT), 0.04)
		var gz := iz0 + wd * 0.6
		for k in 2:
			var gx := (k - 0.5) * cx * 0.8
			var q := minf(3.0, wd * 0.25)
			for e in [[Vector3(-q, 0, -q), Vector3(q, 0, -q)], [Vector3(q, 0, -q), Vector3(q, 0, q)], [Vector3(q, 0, q), Vector3(-q, 0, q)], [Vector3(-q, 0, q), Vector3(-q, 0, -q)], [Vector3(0, 0, -q), Vector3(0, 0, q)], [Vector3(-q, 0, 0), Vector3(q, 0, 0)]]:
				Kit._line(mb, Vector3(gx, 0, gz) + e[0], Vector3(gx, 0, gz) + e[1], 0.12, [YELLOW, TRIM][k])
		var posts: Array = []
		for k in 3:
			posts.append(Vector3(lerpf(-cx + 1.0, cx - 1.0, k * 0.5), 0, iz0 + 2.6))
		Kit._canopy(mb, out, -cx, cx, iz0, iz0 + 3.0, 3.2, 0.3, accent, MeshBuilder.glow(Color(0.78, 0.79, 0.8), MeshBuilder.ROOF), posts, TRIM)
		for s: float in [-1.0, 1.0]:
			Props.crepe_myrtle(mb, out, Vector3(s * cx * 0.75, 0, back - 1.6), rng)
	# Drop-off lane with a bus; flagpole on a bed.
	_school_bus(mb, out, Vector3(-w * 0.25, 0, -d * 0.5 + 2.4), PI * 0.5)
	var fp := Vector3(6.0, 0, (fz - d * 0.5 + 4.4) * 0.5)
	_disc(mb, fp + Vector3(0, 0.06, 0), 1.5, MeshBuilder.glow(Color(0.5, 0.36, 0.3), MeshBuilder.GRASS), 12)
	_flag(mb, out, fp, 9.0, CITY_FLAG, 1.0)
	for s: float in [-1.0, 1.0]:
		Kit._bush(mb, Vector3(s * 4.2, 0, fz - 1.6), 0.9, rng)


# --- Homes -------------------------------------------------------------------------

## Brooklyn brownstone row: attached four-storey houses about 6 m wide
## (raised parlor floor over an English basement), stoops to the doors,
## heavy cornices, browns and reds, small rear yards.
static func brownstone_row(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var n := maxi(1, roundi(w / 6.0))
	var uw := w / n
	var sd := clampf(d * 0.2, 1.8, 3.2)
	var hf := -d * 0.5 + sd
	var hb := minf(hf + clampf(d * 0.62, 6.0, 13.0), d * 0.5 - 1.0)
	var hd := hb - hf
	const PARLOR := 1.7
	Kit._pad(mb, -w * 0.5, w * 0.5, -d * 0.5, hf, MeshBuilder.glow(CONCRETE.darkened(0.05), MeshBuilder.CONCRETE))
	Kit._pad(mb, -w * 0.5, w * 0.5, hb, d * 0.5, _grass(), 0.03)
	var start := rng.randi() % BROWNSTONES.size()
	var hmax := 0.0
	var iron := MeshBuilder.glow(IRON, MeshBuilder.GLOSS)
	for i in n:
		var x0 := -w * 0.5 + i * uw
		var cx := x0 + uw * 0.5
		var tone: Array = BROWNSTONES[(start + i) % BROWNSTONES.size()]
		var col: Color = tone[0]
		var face := Color(col.lightened(rng.randf() * 0.06), tone[1])
		var H := rng.randf_range(12.6, 13.4)
		hmax = maxf(hmax, H)
		mb.box(Vector3(cx, H * 0.5, (hf + hb) * 0.5), Vector3(uw, H, hd), face)
		mb.box(Vector3(cx, H - 0.4, hf - 0.3), Vector3(uw, 0.8, 0.6), Color(0.22, 0.19, 0.17))
		mb.box(Vector3(cx, H + 0.02, (hf + hb) * 0.5), Vector3(uw - 0.1, 0.04, hd - 0.1), MeshBuilder.glow(Color(0.5, 0.5, 0.49).lightened(rng.randf() * 0.2), MeshBuilder.ROOF))
		if rng.randf() < 0.7:
			mb.box(Vector3(cx + rng.randf_range(-1.5, 1.5), H + 0.5, hb - 1.5), Vector3(1.0, 1.0, 1.2), face.darkened(0.15))
		var ds := 1.0 if i % 2 == 0 else -1.0
		var dx := cx + ds * uw * 0.28
		# Door, hood, windows (parlor two tall ones, three per upper floor).
		mb.box(Vector3(dx, PARLOR + 1.3, hf - 0.05), Vector3(1.3, 2.6, 0.1), Color(0.24, 0.15, 0.1))
		mb.box(Vector3(dx, PARLOR + 3.0, hf - 0.25), Vector3(1.9, 0.35, 0.5), face.darkened(0.2))
		for k: float in [0.06, 0.32]:
			Kit._windows(mb, Vector3(cx - ds * uw * k, PARLOR + 1.7, hf), Vector3(cx - ds * uw * k, PARLOR + 1.7, hf), 1, Vector2(1.1, 2.4), rng, Vector3.FORWARD, 0.5)
			Kit._windows(mb, Vector3(cx - ds * uw * k, 0.8, hf), Vector3(cx - ds * uw * k, 0.8, hf), 1, Vector2(0.9, 0.9), rng, Vector3.FORWARD, 0.3)
		for f in 2:
			var y := 6.6 + f * 3.1
			Kit._windows(mb, Vector3(x0 + 0.3, y, hf), Vector3(x0 + uw - 0.3, y, hf), 3, Vector2(1.0, 2.0), rng, Vector3.FORWARD, 0.45)
		for f in 3:
			Kit._windows(mb, Vector3(x0 + 0.3, 3.4 + f * 3.1, hb), Vector3(x0 + uw - 0.3, 3.4 + f * 3.1, hb), 3, Vector2(1.0, 1.8), rng, Vector3.BACK, 0.45)
		# Stoop with iron rails; a low areaway rail.
		var sz0 := -d * 0.5 + 0.15
		_stair(mb, dx - 0.85, dx + 0.85, sz0, hf, PARLOR, 6, face.darkened(0.1))
		for s: float in [-1.0, 1.0]:
			Kit._beam(mb, Vector3(dx + s * 0.9, 0.9, sz0 + 0.1), Vector3(dx + s * 0.9, PARLOR + 0.9, hf - 0.1), 0.07, iron)
		Kit._col(out, Vector3(dx, PARLOR * 0.5, (sz0 + hf) * 0.5), Vector3(1.8, PARLOR, hf - sz0))
		# The areaway rail runs from the stoop to the party wall on the window side.
		var ax0 := x0 + 0.2 if ds > 0.0 else dx + 1.0
		var ax1 := dx - 1.0 if ds > 0.0 else x0 + uw - 0.2
		if ax1 - ax0 > 0.5:
			_fence_panel(mb, Vector3(ax0, 0, -d * 0.5 + 0.3), Vector3(ax1, 0, -d * 0.5 + 0.3), 0.6, iron)
		# Rear yard: a board fence to the neighbour, a shrub.
		if i < n - 1 and d * 0.5 - hb > 0.8:
			_fence_panel(mb, Vector3(x0 + uw, 0, hb), Vector3(x0 + uw, 0, d * 0.5 - 0.15), 1.6, Color(0.5, 0.38, 0.27))
			Kit._col(out, Vector3(x0 + uw, 0.8, (hb + d * 0.5) * 0.5), Vector3(0.1, 1.6, d * 0.5 - hb))
		if rng.randf() < 0.5 and d * 0.5 - hb > 1.6:
			Kit._bush(mb, Vector3(cx + rng.randf_range(-1.5, 1.5), 0, (hb + d * 0.5) * 0.5), minf(1.0, (d * 0.5 - hb) * 0.4), rng)
	Kit._col(out, Vector3(0, hmax * 0.5, (hf + hb) * 0.5), Vector3(w, hmax, hd))
	if d * 0.5 - hb > 0.8:
		_fence_panel(mb, Vector3(-w * 0.5 + 0.1, 0, d * 0.5 - 0.15), Vector3(w * 0.5 - 0.1, 0, d * 0.5 - 0.15), 1.6, Color(0.5, 0.38, 0.27))
		Kit._col(out, Vector3(0, 0.8, d * 0.5 - 0.15), Vector3(w - 0.2, 1.6, 0.12))


## Painted ladies (SF Alamo Square): attached three-storey Victorians about
## 7.5 m wide, each a different bright pastel, steep gables to the street
## with white trim, bay windows and short stoops.
static func painted_lady_row(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var n := maxi(1, roundi(w / 7.5))
	var uw := w / n
	var sd := clampf(d * 0.16, 1.6, 2.8)
	var hf := -d * 0.5 + sd
	var hb := minf(hf + clampf(d * 0.66, 6.0, 13.0), d * 0.5 - 1.0)
	var hd := hb - hf
	const BASE := 1.2
	const FH := 3.2
	var H := BASE + 3.0 * FH
	var trim := MeshBuilder.glow(TRIM, MeshBuilder.GLOSS)
	Kit._pad(mb, -w * 0.5, w * 0.5, -d * 0.5, hf, MeshBuilder.glow(CONCRETE.darkened(0.05), MeshBuilder.CONCRETE))
	Kit._pad(mb, -w * 0.5, w * 0.5, hb, d * 0.5, _grass(), 0.03)
	var start := rng.randi() % VICTORIAN.size()
	for i in n:
		var x0 := -w * 0.5 + i * uw
		var cx := x0 + uw * 0.5
		var paint: Color = VICTORIAN[(start + i * 3) % VICTORIAN.size()]
		var accent: Color = VICTORIAN[(start + i * 3 + 4) % VICTORIAN.size()].darkened(0.35)
		var body := MeshBuilder.glow(paint, MeshBuilder.SIDING)
		mb.box(Vector3(cx, H * 0.5, (hf + hb) * 0.5), Vector3(uw, H, hd), body)
		var rise := clampf(uw * 0.62, 3.0, 6.0)
		var roof: Color = MeshBuilder.glow(Kit._pick(Kit.SHINGLES, rng).lightened(0.08), MeshBuilder.SIDING)
		Kit._gable(mb, cx, (hf + hb) * 0.5 - 0.15, H, uw - 0.04, hd + 0.3, rise, roof, paint, true)
		# White trim: cornice, belt course, raking boards, gable window.
		mb.box(Vector3(cx, H - 0.25, hf - 0.2), Vector3(uw - 0.04, 0.5, 0.4), trim)
		mb.box(Vector3(cx, BASE + FH, hf - 0.06), Vector3(uw - 0.04, 0.25, 0.12), trim)
		for s: float in [-1.0, 1.0]:
			Kit._beam(mb, Vector3(cx + s * (uw * 0.5 - 0.1), H, hf - 0.35), Vector3(cx, H + rise, hf - 0.35), 0.28, trim)
		mb.box(Vector3(cx, H + rise * 0.36, hf - 0.2), Vector3(1.3, 1.3, 0.06), trim)
		mb.box(Vector3(cx, H + rise * 0.36, hf - 0.26), Vector3(0.9, 0.9, 0.06), Buildings._window(rng, 0.5))
		# Bay window on floors one and two.
		var bs := 1.0 if i % 2 == 0 else -1.0
		var bx := cx + bs * uw * 0.2
		var bwid := minf(2.8, uw * 0.45)
		var bh := bwid * 0.5
		var poly := PackedVector2Array([Vector2(bx - bh, hf), Vector2(bx - bh + 0.5, hf - 0.9), Vector2(bx + bh - 0.5, hf - 0.9), Vector2(bx + bh, hf)])
		mb.prism(poly, BASE, BASE + 2.0 * FH, body, body)
		mb.box(Vector3(bx, BASE + 2.0 * FH + 0.15, hf - 0.45), Vector3(bwid + 0.2, 0.3, 1.0), trim)
		for f in 2:
			var y := BASE + f * FH + 1.6
			mb.box(Vector3(bx, y, hf - 0.93), Vector3(bwid - 0.9, 2.1, 0.06), trim)
			Kit._windows(mb, Vector3(bx, y, hf - 0.9), Vector3(bx, y, hf - 0.9), 1, Vector2(bwid - 1.3, 1.8), rng, Vector3.FORWARD, 0.5)
		mb.box(Vector3(bx, BASE + 2.0 * FH + 1.6, hf - 0.03), Vector3(1.5, 2.0, 0.06), trim)
		Kit._windows(mb, Vector3(bx, BASE + 2.0 * FH + 1.6, hf), Vector3(bx, BASE + 2.0 * FH + 1.6, hf), 1, Vector2(1.1, 1.7), rng, Vector3.FORWARD, 0.5)
		# Door side: stoop, door, hood, windows above.
		var dx := cx - bs * uw * 0.28
		mb.box(Vector3(dx, BASE + 1.2, hf - 0.04), Vector3(1.5, 2.6, 0.06), trim)
		mb.box(Vector3(dx, BASE + 1.15, hf - 0.08), Vector3(1.1, 2.3, 0.06), accent)
		mb.box(Vector3(dx, BASE + 2.75, hf - 0.4), Vector3(1.8, 0.25, 0.8), trim)
		for f in 2:
			var y := BASE + (f + 1) * FH + 1.6
			mb.box(Vector3(dx, y, hf - 0.03), Vector3(1.4, 2.0, 0.06), trim)
			Kit._windows(mb, Vector3(dx, y, hf), Vector3(dx, y, hf), 1, Vector2(1.0, 1.7), rng, Vector3.FORWARD, 0.5)
		var sz0 := -d * 0.5 + 0.15
		_stair(mb, dx - 0.7, dx + 0.7, sz0, hf, BASE, 5, trim)
		Kit._col(out, Vector3(dx, BASE * 0.5, (sz0 + hf) * 0.5), Vector3(1.4, BASE, hf - sz0))
		Kit._windows(mb, Vector3(bx, 0.6, hf - 0.9), Vector3(bx, 0.6, hf - 0.9), 1, Vector2(1.0, 0.6), rng, Vector3.FORWARD, 0.3)
		for f in 3:
			Kit._windows(mb, Vector3(x0 + 0.5, BASE + f * FH + 1.6, hb), Vector3(x0 + uw - 0.5, BASE + f * FH + 1.6, hb), 2, Vector2(1.0, 1.6), rng, Vector3.BACK, 0.45)
		if rng.randf() < 0.6 and d * 0.5 - hb > 1.6:
			Kit._bush(mb, Vector3(cx + rng.randf_range(-1.5, 1.5), 0, (hb + d * 0.5) * 0.5), minf(1.0, (d * 0.5 - hb) * 0.4), rng)
	Kit._col(out, Vector3(0, H * 0.5, (hf + hb) * 0.5), Vector3(w, H, hd))
	if d * 0.5 - hb > 0.8:
		_fence_panel(mb, Vector3(-w * 0.5 + 0.1, 0, d * 0.5 - 0.15), Vector3(w * 0.5 - 0.1, 0, d * 0.5 - 0.15), 1.6, Color(0.5, 0.38, 0.27))
		Kit._col(out, Vector3(0, 0.8, d * 0.5 - 0.15), Vector3(w - 0.2, 1.6, 0.12))


## DC Capitol Hill rowhouses: two- and three-storey brick fronts about
## 6 m wide, alternating turret bays and front porches, painted cornices,
## small front yards behind low iron fences.
static func rowhouse_row(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var n := maxi(1, roundi(w / 6.0))
	var uw := w / n
	var fy := clampf(d * 0.25, 1.8, 4.0)
	var hf := -d * 0.5 + fy
	var hb := minf(hf + clampf(d * 0.62, 6.0, 12.0), d * 0.5 - 0.8)
	var hd := hb - hf
	const FH := 3.2
	var iron := MeshBuilder.glow(IRON, MeshBuilder.GLOSS)
	var cornices := [Color(0.18, 0.3, 0.22), Color(0.15, 0.15, 0.16), Color(0.93, 0.92, 0.88), Color(0.45, 0.2, 0.18), Color(0.2, 0.28, 0.42)]
	Kit._pad(mb, -w * 0.5, w * 0.5, -d * 0.5, hf, _grass(), 0.03)
	Kit._pad(mb, -w * 0.5, w * 0.5, hb, d * 0.5, _grass(LAWN.darkened(0.08)), 0.03)
	var start := rng.randi() % ROW_FRONTS.size()
	var hmax := 0.0
	for i in n:
		var x0 := -w * 0.5 + i * uw
		var cx := x0 + uw * 0.5
		var front: Array = ROW_FRONTS[(start + i * 2) % ROW_FRONTS.size()]
		var face := Color(front[0], front[1])
		var floors := 2 if rng.randf() < 0.45 else 3
		var H := 0.6 + floors * FH + 0.5
		hmax = maxf(hmax, H)
		var cor: Color = cornices[(start + i) % cornices.size()]
		mb.box(Vector3(cx, H * 0.5, (hf + hb) * 0.5), Vector3(uw, H, hd), face)
		mb.box(Vector3(cx, H - 0.3, hf - 0.3), Vector3(uw, 0.6, 0.6), cor)
		mb.box(Vector3(cx, H + 0.02, (hf + hb) * 0.5), Vector3(uw - 0.1, 0.04, hd - 0.1), MeshBuilder.glow(Color(0.5, 0.5, 0.49).lightened(rng.randf() * 0.2), MeshBuilder.ROOF))
		var side := 1.0 if (i + start) % 2 == 0 else -1.0
		var dx := cx - side * uw * 0.3
		var fx := cx + side * uw * 0.18
		var bay := rng.randf() < 0.5
		if bay:
			# A turret bay up the full front with a pyramid cap.
			var bwid := uw * 0.44
			Kit._solid(mb, out, Vector3(fx, (H - 0.6) * 0.5, hf - 0.55), Vector3(bwid, H - 0.6, 1.1), face)
			Kit._hip(mb, Vector3(fx, H - 0.6, hf - 0.55), bwid + 0.3, 1.4, 1.2, MeshBuilder.glow(Color(0.3, 0.32, 0.35), MeshBuilder.SEAM_ROOF))
			for f in floors:
				Kit._windows(mb, Vector3(fx, 0.6 + f * FH + 1.6, hf - 1.1), Vector3(fx, 0.6 + f * FH + 1.6, hf - 1.1), 1, Vector2(bwid - 0.8, 1.8), rng, Vector3.FORWARD, 0.5)
		else:
			# A front porch: a low deck, two posts, a roof slab.
			mb.box(Vector3(cx, 0.3, hf - 0.9), Vector3(uw - 0.2, 0.6, 1.8), MeshBuilder.glow(Color(0.6, 0.58, 0.55), MeshBuilder.CONCRETE))
			mb.box(Vector3(cx, 3.5, hf - 0.95), Vector3(uw - 0.1, 0.25, 2.0), MeshBuilder.glow(cor.lerp(Color(0.64, 0.64, 0.62), 0.55), MeshBuilder.SEAM_ROOF))
			for s: float in [-1.0, 1.0]:
				Kit._post(mb, out, Vector3(cx + s * (uw * 0.5 - 0.3), 0.6, hf - 1.7), 2.8, 0.2, TRIM)
			for f in floors:
				Kit._windows(mb, Vector3(fx, 0.6 + f * FH + 1.6, hf), Vector3(fx, 0.6 + f * FH + 1.6, hf), 1, Vector2(1.1, 1.9), rng, Vector3.FORWARD, 0.5)
		mb.box(Vector3(dx, 0.6 + 1.15, hf - 0.05), Vector3(1.1, 2.3, 0.1), cor.darkened(0.1))
		for f in floors - 1:
			Kit._windows(mb, Vector3(dx, 0.6 + (f + 1) * FH + 1.6, hf), Vector3(dx, 0.6 + (f + 1) * FH + 1.6, hf), 1, Vector2(1.0, 1.8), rng, Vector3.FORWARD, 0.5)
		for f in floors:
			Kit._windows(mb, Vector3(x0 + 0.4, 0.6 + f * FH + 1.6, hb), Vector3(x0 + uw - 0.4, 0.6 + f * FH + 1.6, hb), 2, Vector2(1.0, 1.6), rng, Vector3.BACK, 0.45)
		# Front yard: a walk to the door and a low iron fence with a gate gap.
		Kit._pad(mb, dx - 0.6, dx + 0.6, -d * 0.5, hf, MeshBuilder.glow(CONCRETE, MeshBuilder.CONCRETE), 0.05)
		Kit._route_out(mb, dx - 0.6, dx + 0.6, d, MeshBuilder.glow(CONCRETE, MeshBuilder.CONCRETE))
		var fz := -d * 0.5 + 0.25
		if dx - 0.8 - (x0 + 0.1) > 0.4:
			_fence_panel(mb, Vector3(x0 + 0.1, 0, fz), Vector3(dx - 0.8, 0, fz), 0.65, iron)
		if x0 + uw - 0.1 - (dx + 0.8) > 0.4:
			_fence_panel(mb, Vector3(dx + 0.8, 0, fz), Vector3(x0 + uw - 0.1, 0, fz), 0.65, iron)
		if not bay and rng.randf() < 0.5:
			Kit._bush(mb, Vector3(fx, 0, -d * 0.5 + 0.9), 0.55, rng)
		elif bay and fy > 2.5:
			Kit._bush(mb, Vector3(fx, 0, -d * 0.5 + 0.8), 0.5, rng)
	Kit._col(out, Vector3(0, hmax * 0.5, (hf + hb) * 0.5), Vector3(w, hmax, hd))


## Levittown Cape Cod: a storey and a half under a steep gable, two front
## dormers, a central door with shutters either side and a chimney; the
## siding, shutter and roof colours vary.
static func cape_house(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var bw := clampf(w * 0.8, 6.0, 12.0)
	var bd := clampf(d * 0.68, 5.0, 9.0)
	var fz := -d * 0.5 + clampf(d * 0.24, 1.5, 4.0)
	var cz := fz + bd * 0.5
	const WH := 2.8
	var rise := bd * 0.62
	var siding: Color = MeshBuilder.glow(Kit._pick(CAPE_SIDINGS, rng), MeshBuilder.SIDING)
	var shutter: Color = Kit._pick(SHUTTERS, rng)
	var roof: Color = MeshBuilder.glow(Kit._pick(Kit.SHINGLES, rng), MeshBuilder.SIDING)
	var trim := MeshBuilder.glow(TRIM, MeshBuilder.GLOSS)
	Kit._pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, _grass())
	Kit._pad(mb, -0.6, 0.6, -d * 0.5, fz, MeshBuilder.glow(CONCRETE, MeshBuilder.CONCRETE), 0.05)
	Kit._route_out(mb, -0.6, 0.6, d, MeshBuilder.glow(CONCRETE, MeshBuilder.CONCRETE))
	Kit._solid(mb, out, Vector3(0, WH * 0.5, cz), Vector3(bw, WH, bd), siding)
	Kit._gable(mb, 0, cz, WH, bw + 0.4, bd + 0.6, rise, roof, siding)
	# Two dormers on the front slope.
	var slope := rise / (bd * 0.5 + 0.3)
	var dz0 := fz + 0.9
	var dtop := WH - 0.3 * slope + (dz0 - fz + 0.3) * slope + 0.9
	for s: float in [-1.0, 1.0]:
		var dx := s * bw * 0.24
		var dl := cz - dz0
		mb.box(Vector3(dx, (WH + dtop) * 0.5, dz0 + dl * 0.5), Vector3(1.6, dtop - WH, dl), siding)
		Kit._gable(mb, dx, dz0 + dl * 0.5 - 0.15, dtop, 2.0, dl + 0.3, 0.75, roof, siding, true)
		mb.box(Vector3(dx, dtop - 0.75, dz0 - 0.03), Vector3(1.0, 0.95, 0.06), trim)
		Kit._windows(mb, Vector3(dx, dtop - 0.75, dz0), Vector3(dx, dtop - 0.75, dz0), 1, Vector2(0.7, 0.75), rng, Vector3.FORWARD, 0.5)
	# Door, stoop, windows with shutters, chimney.
	mb.box(Vector3(0, 1.12, fz - 0.04), Vector3(1.3, 2.2, 0.06), trim)
	mb.box(Vector3(0, 1.0, fz - 0.08), Vector3(0.95, 2.0, 0.06), shutter.darkened(0.1))
	mb.box(Vector3(0, 0.15, fz - 0.6), Vector3(1.8, 0.3, 1.0), MeshBuilder.glow(CONCRETE, MeshBuilder.CONCRETE))
	mb.box(Vector3(0, 2.3, fz - 0.3), Vector3(0.3, 0.3, 0.2), MeshBuilder.glow(Props.LAMP_GLOW, MeshBuilder.GLOW_LAMP))
	for s: float in [-1.0, 1.0]:
		Kit._windows(mb, Vector3(s * bw * 0.24, 1.5, fz), Vector3(s * bw * 0.24, 1.5, fz), 1, Vector2(1.0, 1.3), rng, Vector3.FORWARD, 0.5, shutter)
		Kit._windows(mb, Vector3(s * bw * 0.5, 1.5, fz + 1.0), Vector3(s * bw * 0.5, 1.5, fz + bd - 1.0), 2, Vector2(0.9, 1.1), rng, Vector3(s, 0, 0), 0.4)
		Kit._bush(mb, Vector3(s * bw * 0.36, 0, fz - 0.7), 0.6, rng)
	Kit._windows(mb, Vector3(-bw * 0.5 + 1.0, 1.5, fz + bd), Vector3(bw * 0.5 - 1.0, 1.5, fz + bd), 3, Vector2(0.9, 1.1), rng, Vector3.BACK, 0.4)
	var ch := 1.0 if rng.randf() < 0.5 else -1.0
	mb.box(Vector3(ch * (bw * 0.5 - 0.5), (WH + rise + 0.8) * 0.5, cz + 0.4), Vector3(0.8, WH + rise + 0.8, 0.9), MeshBuilder.glow(Kit.BRICKS[0], MeshBuilder.BRICK))
	if w - bw > 2.4:
		Props.crepe_myrtle(mb, out, Vector3((w * 0.5 - 1.8) * (-ch), 0, -d * 0.5 + 1.8), rng)


# --- Attractions -------------------------------------------------------------------

## Pleasure pier after Santa Monica: a plank deck on piles 1.5 m up, a
## ramp from the street at -Z, a narrow promenade out to a wide amusement
## deck with a Ferris wheel (about 25 m, lit rim), a small roller coaster
## with a loop, an arcade shed, a carousel under a striped roof, lamps
## along the rails and benches facing the sea.
static func pier_rides(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	const DY := 1.5
	var deck_c := MeshBuilder.glow(Color(0.62, 0.5, 0.38), MeshBuilder.SIDING)
	var pile_c := Color(0.34, 0.28, 0.24)
	var rail_c := MeshBuilder.glow(Color(0.93, 0.93, 0.9), MeshBuilder.GLOSS)
	var steel := MeshBuilder.glow(Color(0.88, 0.89, 0.9), MeshBuilder.METAL)
	var rl := clampf(d * 0.06, 6.0, 10.0)
	var nw := clampf(w * 0.3, 10.0, 20.0)
	var z_land := -d * 0.5
	var zn0 := z_land + rl
	var zw0 := -d * 0.5 + d * 0.32
	var zw1 := d * 0.5 - 0.3
	var ww := w - 0.6
	# Ramp up from the street.
	var rn := Vector3(0, rl, -DY).normalized()
	mb.quad(Vector3(-nw * 0.5, 0.04, z_land), Vector3(nw * 0.5, 0.04, z_land), Vector3(nw * 0.5, DY, zn0), Vector3(-nw * 0.5, DY, zn0), rn, MeshBuilder.glow(CONCRETE, MeshBuilder.CONCRETE))
	for s: float in [-1.0, 1.0]:
		mb.tri(Vector3(s * nw * 0.5, 0, z_land), Vector3(s * nw * 0.5, 0, zn0), Vector3(s * nw * 0.5, DY, zn0), Vector3(s, 0, 0), Color(0.6, 0.58, 0.55))
		mb.box(Vector3(s * (nw * 0.5 - 0.15), DY * 0.5 + 0.55, (z_land + zn0) * 0.5), Vector3(0.3, 0.1, rl), rail_c)
		Kit._col(out, Vector3(s * (nw * 0.5 - 0.15), 0.75, (z_land + zn0) * 0.5), Vector3(0.3, 1.5, rl))
	# Decks.
	mb.box(Vector3(0, DY - 0.25, (zn0 + zw0) * 0.5), Vector3(nw, 0.5, zw0 - zn0), deck_c)
	mb.box(Vector3(0, DY - 0.25, (zw0 + zw1) * 0.5), Vector3(ww, 0.5, zw1 - zw0), deck_c)
	mb.box(Vector3(0, DY + 0.02, (zn0 + zw1) * 0.5), Vector3(3.0, 0.03, zw1 - zn0), MeshBuilder.glow(Color(0.55, 0.43, 0.33), MeshBuilder.SIDING))
	# Piles along the edges.
	var pz := zn0 + 2.0
	while pz < zw0:
		for s: float in [-1.0, 1.0]:
			mb.box(Vector3(s * (nw * 0.5 - 0.4), 0.2, pz), Vector3(0.5, 1.8, 0.5), pile_c)
		pz += 6.0
	pz = zw0 + 3.0
	while pz < zw1:
		for s: float in [-1.0, 1.0]:
			mb.box(Vector3(s * (ww * 0.5 - 0.4), 0.2, pz), Vector3(0.5, 1.8, 0.5), pile_c)
		pz += 6.0
	var px := -ww * 0.5 + 3.0
	while px < ww * 0.5:
		mb.box(Vector3(px, 0.2, zw1 - 0.4), Vector3(0.5, 1.8, 0.5), pile_c)
		px += 6.0
	# Railings (white panels with a cap) and lamps along them.
	var rails := [
		[Vector3(-nw * 0.5 + 0.1, 0, zn0), Vector3(-nw * 0.5 + 0.1, 0, zw0)],
		[Vector3(nw * 0.5 - 0.1, 0, zn0), Vector3(nw * 0.5 - 0.1, 0, zw0)],
		[Vector3(-ww * 0.5 + 0.1, 0, zw0), Vector3(-ww * 0.5 + 0.1, 0, zw1 - 0.1)],
		[Vector3(ww * 0.5 - 0.1, 0, zw0), Vector3(ww * 0.5 - 0.1, 0, zw1 - 0.1)],
		[Vector3(-ww * 0.5 + 0.1, 0, zw1 - 0.1), Vector3(ww * 0.5 - 0.1, 0, zw1 - 0.1)],
		[Vector3(-ww * 0.5 + 0.1, 0, zw0 + 0.1), Vector3(-nw * 0.5, 0, zw0 + 0.1)],
		[Vector3(nw * 0.5, 0, zw0 + 0.1), Vector3(ww * 0.5 - 0.1, 0, zw0 + 0.1)],
	]
	var lamp_glow := MeshBuilder.glow(Props.LAMP_GLOW, MeshBuilder.GLOW_LAMP)
	for rr in rails:
		var a: Vector3 = rr[0] + Vector3(0, DY, 0)
		var b: Vector3 = rr[1] + Vector3(0, DY, 0)
		_fence_panel(mb, a, b, 0.95, rail_c)
		var along_x := absf(b.x - a.x) > absf(b.z - a.z)
		mb.box((a + b) * 0.5 + Vector3(0, 1.0, 0), Vector3(absf(b.x - a.x) + 0.2 if along_x else 0.22, 0.08, 0.22 if along_x else absf(b.z - a.z) + 0.2), rail_c)
		Kit._col(out, (a + b) * 0.5 + Vector3(0, 0.0, 0), Vector3(absf(b.x - a.x) + 0.2 if along_x else 0.25, 3.0, 0.25 if along_x else absf(b.z - a.z) + 0.2))
		var nl := int(a.distance_to(b) / 10.0)
		for k in nl:
			var p := a.lerp(b, (k + 0.5) / nl)
			mb.cylinder(p, 0.08, 4.2, IRON, 4)
			mb.box(p + Vector3(0, 4.25, 0), Vector3(0.4, 0.45, 0.4), lamp_glow)
			mb.box(p + Vector3(0, 4.55, 0), Vector3(0.55, 0.12, 0.55), IRON)
	# Gateway at the top of the ramp: two pylons and a lit crossbar.
	for s: float in [-1.0, 1.0]:
		Kit._solid(mb, out, Vector3(s * (nw * 0.5 - 1.0), DY + 3.0, zn0 + 1.0), Vector3(0.9, 6.0, 0.9), MeshBuilder.glow(Color(0.2, 0.42, 0.55), MeshBuilder.GLOSS))
	mb.box(Vector3(0, DY + 5.6, zn0 + 1.0), Vector3(nw - 1.2, 1.2, 0.5), MeshBuilder.glow(Color(0.2, 0.42, 0.55), MeshBuilder.GLOSS))
	mb.box(Vector3(0, DY + 5.6, zn0 + 0.72), Vector3(nw - 2.4, 0.7, 0.06), MeshBuilder.glow(NEONS[2], MeshBuilder.GLOW_NEON))
	# Ferris wheel (in the x-y plane, so it reads as a circle from above).
	var R := clampf(minf(w * 0.2, d * 0.1), 7.0, 12.0)
	var wc := Vector3(ww * 0.5 - R - 1.6, DY + R + 2.2, zw1 - clampf(d * 0.16, 12.0, 26.0))
	var rim := MeshBuilder.glow(Color(0.95, 0.35, 0.3), MeshBuilder.GLOW_NEON)
	const SEG := 20
	for side: float in [-1.0, 1.0]:
		var o := Vector3(0, 0, side * 1.1)
		for i in SEG:
			var a0 := TAU * i / SEG
			var a1 := TAU * (i + 1) / SEG
			Kit._beam(mb, wc + o + Vector3(cos(a0), sin(a0), 0) * R, wc + o + Vector3(cos(a1), sin(a1), 0) * R, 0.3, rim)
		for i in SEG / 2:
			var a := TAU * i / (SEG / 2)
			Kit._beam(mb, wc + o, wc + o + Vector3(cos(a), sin(a), 0) * R, 0.12, steel)
	mb.limb(wc - Vector3(0, 0, 1.6), wc + Vector3(0, 0, 1.6), 0.6, 0.6, steel, 8)
	for i in SEG:
		var a := TAU * (i + 0.5) / SEG
		var gp := wc + Vector3(cos(a) * R, sin(a) * R - 1.0, 0)
		mb.box(gp, Vector3(1.3, 1.1, 1.6), MeshBuilder.glow(NEONS[i % NEONS.size()].darkened(0.15), MeshBuilder.GLOSS))
		mb.box(gp + Vector3(0, 0.62, 0), Vector3(1.5, 0.12, 1.8), TRIM)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			Kit._beam(mb, Vector3(wc.x + sx * R * 0.42, DY, wc.z + sz * 2.6), wc + Vector3(0, 0, sz * 1.3), 0.4, steel)
	mb.box(Vector3(wc.x, DY + 0.25, wc.z), Vector3(R * 0.9 + 1.0, 0.5, 6.0), MeshBuilder.glow(Color(0.3, 0.32, 0.36), MeshBuilder.METAL))
	Kit._col(out, Vector3(wc.x, DY + 2.0, wc.z), Vector3(R * 0.9 + 1.0, 4.0, 5.6))
	# Roller coaster: an oval circuit with a lift hill, a loop and supports.
	var rx := clampf(w * 0.2, 6.0, 12.0)
	var rz := clampf(d * 0.13, 9.0, 20.0)
	var ccx := -ww * 0.5 + rx + 1.6
	var ccz := wc.z - 2.0
	if ccz + rz > zw1 - 1.2:
		ccz = zw1 - 1.2 - rz
	var track := MeshBuilder.glow(Color(0.15, 0.6, 0.7), MeshBuilder.GLOSS)
	const N := 32
	var pts: Array = []
	for i in N:
		var t := TAU * i / N
		var h := DY + 1.3 + 8.0 * pow(maxf(0.0, sin(t)), 2.0) + 2.2 * pow(maxf(0.0, sin(3.0 * t + 1.0)), 2.0) * (1.0 - maxf(0.0, sin(t)))
		pts.append(Vector3(ccx + rx * cos(t), h, ccz + rz * sin(t)))
	for i in N:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[(i + 1) % N]
		Kit._beam(mb, a, b, 0.25, track, 1.1)
		if i % 2 == 0:
			Kit._beam(mb, Vector3(a.x, DY, a.z), a - Vector3(0, 0.15, 0), 0.2, MeshBuilder.glow(TRIM, MeshBuilder.GLOSS))
	var lc := Vector3(ccx - rx, DY + 1.3 + 3.4, ccz)
	for i in 12:
		var a0 := TAU * i / 12.0 - PI * 0.5
		var a1 := TAU * (i + 1) / 12.0 - PI * 0.5
		Kit._beam(mb, lc + Vector3(0.0, sin(a0), cos(a0)) * 3.4 + Vector3(-0.6 + i * 0.1, 0, 0), lc + Vector3(0.0, sin(a1), cos(a1)) * 3.4 + Vector3(-0.5 + i * 0.1, 0, 0), 0.25, track, 1.0)
	var t0 := -PI * 0.5
	var sp := Vector3(ccx, DY, ccz - rz)
	mb.box(sp + Vector3(0, 1.6, 0), Vector3(6.0, 0.2, 3.4), MeshBuilder.glow(Color(0.95, 0.75, 0.2), MeshBuilder.GLOSS))
	for s: float in [-1.0, 1.0]:
		mb.box(sp + Vector3(s * 2.8, 0.8, 1.5), Vector3(0.2, 1.6, 0.2), TRIM)
	for k in 3:
		var t := t0 + 0.1 + k * 0.12
		var cp := Vector3(ccx + rx * cos(t), DY + 1.75, ccz + rz * sin(t))
		mb.box(cp, Vector3(1.5, 0.7, 1.2), MeshBuilder.glow(NEONS[k * 2], MeshBuilder.GLOSS))
	for e in [[Vector3(-1, 0, -1), Vector3(1, 0, -1)], [Vector3(1, 0, -1), Vector3(1, 0, 1)], [Vector3(1, 0, 1), Vector3(-1, 0, 1)], [Vector3(-1, 0, 1), Vector3(-1, 0, -1)]]:
		var a: Vector3 = Vector3(ccx, DY, ccz) + Vector3(e[0].x * (rx + 1.2), 0, e[0].z * (rz + 1.2))
		var b: Vector3 = Vector3(ccx, DY, ccz) + Vector3(e[1].x * (rx + 1.2), 0, e[1].z * (rz + 1.2))
		_fence_panel(mb, a, b, 0.9, MeshBuilder.glow(Color(0.2, 0.42, 0.55), MeshBuilder.GLOSS))
	Kit._col(out, Vector3(ccx, DY + 1.5, ccz), Vector3(rx * 2.0 + 2.4, 3.0, rz * 2.0 + 2.4))
	# Arcade shed near the start of the wide deck.
	var aw := clampf(w * 0.32, 10.0, 20.0)
	var ad := clampf(d * 0.1, 7.0, 14.0)
	var ax := -ww * 0.5 + 0.8 + aw * 0.5
	var az0 := zw0 + 1.5
	var az := az0 + ad * 0.5
	const AH := 5.5
	Kit._solid(mb, out, Vector3(ax, DY + AH * 0.5, az), Vector3(aw, AH, ad), MeshBuilder.glow(Color(0.95, 0.88, 0.72), MeshBuilder.SIDING))
	_parapet_roof(mb, ax, az, aw, ad, DY + AH, Color(0.85, 0.35, 0.4), 0.7, Color(0.6, 0.62, 0.64))
	mb.box(Vector3(ax, DY + 1.6, az0 - 0.06), Vector3(aw - 2.0, 2.8, 0.08), _lit(Color(0.45, 0.3, 0.5)))
	for k in 7:
		var c: Color = NEONS[k % NEONS.size()]
		mb.box(Vector3(ax - aw * 0.42 + k * aw * 0.14, DY + 4.2, az0 - 0.12), Vector3(aw * 0.1, 1.2, 0.06), MeshBuilder.glow(c, MeshBuilder.GLOW_NEON))
	mb.box(Vector3(ax + aw * 0.5 + 0.06, DY + 2.0, az), Vector3(0.08, 2.6, ad - 2.0), _lit(Color(0.45, 0.3, 0.5)))
	# Carousel house under a striped tent roof.
	var cr := clampf(w * 0.11, 4.5, 7.0)
	var cc := Vector3(ww * 0.5 - 0.8 - cr - 0.8, DY, zw0 + 1.8 + cr)
	mb.cylinder(cc, cr, 3.6, MeshBuilder.glow(Color(0.96, 0.92, 0.82), MeshBuilder.SIDING), 12)
	for i in 6:
		var a := TAU * (i + 0.5) / 6.0
		mb.box(cc + Vector3(cos(a) * (cr + 0.04), 1.6, sin(a) * (cr + 0.04)), Vector3(1.4, 2.4, 1.4), _lit(Color(0.5, 0.35, 0.25)))
	for i in 16:
		var a0 := TAU * i / 16.0
		var a1 := TAU * (i + 1) / 16.0
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var n := ((d0 + d1).normalized() * 3.0 + Vector3(0, cr + 0.6, 0)).normalized()
		mb.tri(cc + Vector3(0, 3.6, 0) + d0 * (cr + 0.6), cc + Vector3(0, 3.6, 0) + d1 * (cr + 0.6), cc + Vector3(0, 6.6, 0), n, Color(0.85, 0.15, 0.15) if i % 2 == 0 else TRIM)
	mb.cylinder(cc + Vector3(0, 6.5, 0), 0.06, 1.4, GOLD, 4)
	mb.box(cc + Vector3(0.45, 7.6, 0), Vector3(0.8, 0.4, 0.04), Color(0.95, 0.8, 0.2))
	Kit._col(out, cc + Vector3(0, 1.8, 0), Vector3(cr * 1.8, 3.6, cr * 1.8))
	# Benches facing the sea along the open middle of the wide deck.
	var bz0 := maxf(az0 + ad, cc.z + cr) + 2.0
	var bz1 := minf(ccz - rz, wc.z - 3.0) - 2.5
	if bz1 > bz0 + 10.0:
		# Food kiosks with neon awnings and umbrella tables in the open middle.
		for k in 2:
			var kp := Vector3((-1.0 if k == 0 else 1.0) * ww * 0.2, DY, lerpf(bz0, bz1, 0.3 + k * 0.4))
			var neon: Color = NEONS[(k * 3 + rng.randi() % 2) % NEONS.size()]
			Kit._solid(mb, out, kp + Vector3(0, 1.3, 0), Vector3(3.2, 2.6, 2.6), MeshBuilder.glow(Color(0.95, 0.92, 0.84), MeshBuilder.SIDING))
			mb.box(kp + Vector3(0, 1.2, -1.32), Vector3(2.4, 1.0, 0.06), _lit(Color(0.5, 0.4, 0.3)))
			mb.box(kp + Vector3(0, 2.75, -0.3), Vector3(3.8, 0.3, 3.6), MeshBuilder.glow(neon.darkened(0.2), MeshBuilder.GLOSS))
			mb.box(kp + Vector3(0, 2.65, -2.12), Vector3(3.8, 0.12, 0.08), MeshBuilder.glow(neon, MeshBuilder.GLOW_NEON))
		for k in 4:
			var up := Vector3((k % 2 * 2 - 1) * ww * 0.08 + (rng.randf() - 0.5), DY, lerpf(bz0, bz1, 0.15 + k * 0.23))
			mb.cylinder(up, 0.45, 0.75, MeshBuilder.glow(TRIM, MeshBuilder.GLOSS), 6)
			mb.cylinder(up, 0.05, 2.3, IRON, 4)
			Kit._cone(mb, up + Vector3(0, 2.0, 0), 1.3, 0.5, NEONS[(k + 2) % NEONS.size()].darkened(0.15), 8)
	if bz1 > bz0:
		for k in 3:
			var z := lerpf(bz0, bz1, (k + 0.5) / 3.0)
			Props.bench(mb, out, Vector3(-ww * 0.5 + 0.9, DY, z), -PI * 0.5)
			Props.bench(mb, out, Vector3(ww * 0.5 - 0.9, DY, z), PI * 0.5)
	for k in 2:
		var z := lerpf(zn0 + 4.0, zw0 - 3.0, (k + 0.5) / 2.0)
		Props.bench(mb, out, Vector3(-nw * 0.5 + 0.9, DY, z), -PI * 0.5)
		Props.bench(mb, out, Vector3(nw * 0.5 - 0.9, DY, z), PI * 0.5)
