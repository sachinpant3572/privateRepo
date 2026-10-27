extends RefCounted
## Shady kit (Bellerive CA, HANDOFF-bellerive-ca.md): the city's run-down
## places, after Los Angeles, San Francisco and Oakland. Motels on the
## arterials, a liquor store, a pawn shop and a check casher, a brick SRO
## hotel, a chop shop, a scrapyard and an abandoned warehouse; barred
## bungalows, a housing project, a sidewalk encampment, a burned lot and a
## freeway underpass; and small props to scatter. Pure data in, mesh out:
## static functions only, no scene tree, so a tile builds on a worker
## thread.
##
## World bible: these are PLACES, never people or groups. No real brands,
## logos, gangs or readable text anywhere: signs are colour fields, neon
## figures and abstract glyph bars; graffiti is abstract colour shapes
## (bubbles, shards, scribbles), never letters. No religious buildings or
## symbols.
##
## Frame and colliders as in civic_kit.gd: the lot spans x in [-w/2, w/2]
## (along the street) and z in [-d/2, d/2], the entrance faces the street
## at -Z, ground at y = 0, and everything stays on the lot. Collision boxes
## go to `out` as [center, size] or [center, size, yaw]; flat things (under
## 0.7 m: mattresses, cardboard, litter, slabs) get none. Props build at
## the origin with the lot as their size. The underpass deck stands about
## 6 m up with no deck collider (the player walks at y = 0).
##
## The game camera is orthographic, 60 degrees down, so roofs, yards and
## the south (-Z) faces are what reads: the shabby detail sits there (roof
## patches and tarps, cracked asphalt, cars, clutter, tents, pole signs).

const MeshBuilder = preload("res://scripts/mesh_builder.gd")
const Kit = preload("res://scripts/kits/country_kit.gd")
const Buildings = preload("res://scripts/kits/building_kit.gd")
const Props = preload("res://scripts/kits/prop_kit.gd")

## Shady commercial places (arterials and the poor districts).
const COMMERCIAL := [
	"motel", "liquor_store", "pawn_shop", "check_cashing", "sro_hotel",
	"chop_shop", "scrapyard", "abandoned_warehouse",
]
## Poor housing and the places between.
const HOUSING := ["bungalow_barred", "housing_project", "tent_row", "burned_lot", "underpass"]
## Small props for scattering (built at the origin, lot = their size).
const PROPS := ["graffiti_wall", "chainlink_fence", "burnt_car", "shopping_cart", "mattress", "trash_pile", "dead_palm"]

## Default lot of each kind: x along the front, y deep, metres.
const SIZES := {
	"motel": Vector2(40, 32), "liquor_store": Vector2(22, 20), "pawn_shop": Vector2(14, 18),
	"check_cashing": Vector2(16, 16), "sro_hotel": Vector2(18, 22), "chop_shop": Vector2(30, 28),
	"scrapyard": Vector2(50, 40), "abandoned_warehouse": Vector2(40, 30),
	"bungalow_barred": Vector2(12, 22), "housing_project": Vector2(50, 40), "tent_row": Vector2(30, 6),
	"burned_lot": Vector2(20, 20), "underpass": Vector2(24, 14),
	"graffiti_wall": Vector2(8, 1.2), "chainlink_fence": Vector2(12, 1.0), "burnt_car": Vector2(3.0, 5.4),
	"shopping_cart": Vector2(1.4, 1.6), "mattress": Vector2(2.2, 2.6), "trash_pile": Vector2(3, 3),
	"dead_palm": Vector2(2.6, 2.6),
}

const ASPHALT := Color(0.27, 0.27, 0.28)
const CRACK := Color(0.11, 0.11, 0.12)
const PATCH := Color(0.2, 0.2, 0.21)
const OIL := Color(0.19, 0.185, 0.18)
const CONCRETE := Color(0.66, 0.65, 0.61)
const SIDEWALK := Color(0.64, 0.63, 0.59)
const CINDER := Color(0.6, 0.59, 0.56)
const DIRT := Color(0.5, 0.43, 0.33)
const ASH := Color(0.2, 0.19, 0.18)
const SOOT := Color(0.08, 0.08, 0.08)
const DRY := Color(0.6, 0.56, 0.36)
const WEED := Color(0.36, 0.43, 0.22)
const RUST := Color(0.5, 0.29, 0.18)
const IRON := Color(0.09, 0.09, 0.1)
const STEEL := Color(0.58, 0.6, 0.62)
const PLYWOOD := Color(0.72, 0.6, 0.42)
const CARDBOARD := Color(0.62, 0.48, 0.3)
const DARK := Color(0.08, 0.08, 0.09)
const RECESS := Color(0.12, 0.11, 0.11)
const TAR := Color(0.19, 0.19, 0.2)
const MEMBRANE := Color(0.56, 0.56, 0.55)
const TYRE := Color(0.09, 0.09, 0.1)
const PRIMER := Color(0.5, 0.5, 0.48)
const SHOP_GLASS := Color(0.55, 0.62, 0.6)
## Dingy stucco.
const STUCCOS := [
	Color(0.82, 0.78, 0.68), Color(0.74, 0.7, 0.62), Color(0.79, 0.68, 0.58), Color(0.66, 0.7, 0.66),
	Color(0.8, 0.74, 0.56), Color(0.72, 0.64, 0.62), Color(0.62, 0.66, 0.7),
]
## Faded bungalow paint.
const FADED := [
	Color(0.7, 0.8, 0.72), Color(0.86, 0.7, 0.62), Color(0.88, 0.82, 0.6), Color(0.66, 0.76, 0.84),
	Color(0.8, 0.76, 0.68), Color(0.76, 0.7, 0.8), Color(0.84, 0.84, 0.8), Color(0.62, 0.72, 0.62),
]
## Worn composition shingle.
const SHINGLES := [Color(0.38, 0.36, 0.34), Color(0.46, 0.4, 0.34), Color(0.5, 0.5, 0.5), Color(0.34, 0.36, 0.4), Color(0.48, 0.34, 0.28)]
const BRICKS := [Color(0.55, 0.3, 0.24), Color(0.48, 0.27, 0.22), Color(0.6, 0.38, 0.3), Color(0.5, 0.36, 0.3), Color(0.68, 0.56, 0.42)]
const DOORS := [Color(0.15, 0.42, 0.45), Color(0.5, 0.16, 0.16), Color(0.82, 0.5, 0.2), Color(0.2, 0.3, 0.5), Color(0.3, 0.45, 0.3), Color(0.55, 0.35, 0.5)]
const RAILS := [Color(0.85, 0.85, 0.8), Color(0.2, 0.45, 0.48), Color(0.15, 0.15, 0.16), Color(0.6, 0.2, 0.18)]
## Sheets and curtains hung in windows.
const SHEETS := [Color(0.85, 0.82, 0.7), Color(0.6, 0.3, 0.3), Color(0.35, 0.45, 0.6), Color(0.75, 0.6, 0.35), Color(0.5, 0.5, 0.45)]
const BAGS := [Color(0.08, 0.08, 0.09), Color(0.12, 0.14, 0.12), Color(0.85, 0.85, 0.82), Color(0.2, 0.3, 0.55), Color(0.25, 0.25, 0.27)]
## Corrugated sheet metal.
const METALS := [Color(0.62, 0.64, 0.66), Color(0.42, 0.5, 0.58), Color(0.55, 0.33, 0.22), Color(0.78, 0.75, 0.65), Color(0.45, 0.47, 0.44), Color(0.6, 0.42, 0.3)]
const TARPS := [Color(0.2, 0.42, 0.78), Color(0.24, 0.5, 0.32), Color(0.55, 0.5, 0.4), Color(0.85, 0.5, 0.2), Color(0.3, 0.33, 0.4)]
const TENTS := [Color(0.2, 0.45, 0.75), Color(0.85, 0.55, 0.15), Color(0.3, 0.55, 0.35), Color(0.6, 0.2, 0.2), Color(0.4, 0.4, 0.45), Color(0.55, 0.45, 0.7), Color(0.75, 0.75, 0.7)]
const CLOTHES := [Color(0.9, 0.9, 0.88), Color(0.8, 0.25, 0.25), Color(0.25, 0.4, 0.7), Color(0.95, 0.8, 0.3), Color(0.3, 0.6, 0.4), Color(0.6, 0.4, 0.6), Color(0.2, 0.2, 0.22)]
## Tired car paint.
const CAR_PAINTS := [Color(0.55, 0.15, 0.15), Color(0.2, 0.3, 0.45), Color(0.7, 0.68, 0.62), Color(0.25, 0.25, 0.27), Color(0.35, 0.45, 0.35), Color(0.6, 0.5, 0.3), Color(0.45, 0.42, 0.5), Color(0.62, 0.6, 0.55)]
const DUMPSTERS := [Color(0.2, 0.35, 0.25), Color(0.25, 0.3, 0.45), Color(0.45, 0.4, 0.3), Color(0.3, 0.3, 0.32)]
## Spray-paint inks.
const INKS := [Color(0.95, 0.3, 0.55), Color(0.3, 0.8, 0.95), Color(0.98, 0.85, 0.2), Color(0.5, 0.95, 0.4), Color(0.95, 0.5, 0.15), Color(0.65, 0.4, 0.95), Color(0.95, 0.95, 0.95), Color(0.9, 0.2, 0.2)]
## Sign fields: plain colour, no words.
const SIGN_FIELDS := [Color(0.98, 0.85, 0.2), Color(0.95, 0.95, 0.92), Color(0.2, 0.75, 0.4), Color(0.9, 0.25, 0.2), Color(0.25, 0.55, 0.95), Color(1.0, 0.55, 0.15)]
const NEONS := [Color(1.0, 0.3, 0.55), Color(0.3, 0.85, 1.0), Color(1.0, 0.75, 0.2), Color(0.55, 1.0, 0.45), Color(0.8, 0.4, 1.0), Color(1.0, 0.25, 0.2)]


## Every kind this kit builds.
static func kinds() -> Array:
	return COMMERCIAL + HOUSING + PROPS


## The default lot of `kind` (x along the front, y deep, metres).
static func default_size(kind: String) -> Vector2:
	return SIZES.get(kind, Vector2(20, 20))


## Triangle budget of `kind` at its default size.
static func budget(kind: String) -> int:
	if kind in PROPS:
		return 600
	if kind in ["housing_project", "scrapyard"]:
		return 7000
	return 4000


## Builds `kind` on a lot of `size` (x along the front, y deep). See the
## header for the frame and the collision format.
static func build(kind: String, mb, out: Array, size: Vector2, rng: RandomNumberGenerator) -> void:
	var w := maxf(size.x, 0.6)
	var d := maxf(size.y, 0.6)
	match kind:
		"motel": motel(mb, out, w, d, rng)
		"liquor_store": liquor_store(mb, out, w, d, rng)
		"pawn_shop": pawn_shop(mb, out, w, d, rng)
		"check_cashing": check_cashing(mb, out, w, d, rng)
		"sro_hotel": sro_hotel(mb, out, w, d, rng)
		"chop_shop": chop_shop(mb, out, w, d, rng)
		"scrapyard": scrapyard(mb, out, w, d, rng)
		"abandoned_warehouse": abandoned_warehouse(mb, out, w, d, rng)
		"bungalow_barred": bungalow_barred(mb, out, w, d, rng)
		"housing_project": housing_project(mb, out, w, d, rng)
		"tent_row": tent_row(mb, out, w, d, rng)
		"burned_lot": burned_lot(mb, out, w, d, rng)
		"underpass": underpass(mb, out, w, d, rng)
		"graffiti_wall": graffiti_wall(mb, out, w, d, rng)
		"chainlink_fence": chainlink_fence(mb, out, w, d, rng)
		"burnt_car": burnt_car(mb, out, w, d, rng)
		"shopping_cart": shopping_cart(mb, out, w, d, rng)
		"mattress": mattress(mb, out, w, d, rng)
		"trash_pile": trash_pile(mb, out, w, d, rng)
		"dead_palm": dead_palm(mb, out, w, d, rng)
		_:
			# Unknown kind: a plain magenta block, so a typo shows instead of a hole.
			Kit._solid(mb, out, Vector3(0, 2.0, 0), Vector3(w * 0.6, 4.0, d * 0.6), Color(1.0, 0.0, 1.0))


# --- Helpers ------------------------------------------------------------------

static func _g(c: Color, code: float) -> Color:
	return MeshBuilder.glow(c, code)


## Moves the builder to p, turned by yaw; returns the transform to restore.
static func _push(mb, p: Vector3, yaw: float) -> Transform3D:
	var saved: Transform3D = mb.xform
	mb.xform = saved * Transform3D(Basis(Vector3.UP, yaw), p)
	return saved


## A box turned by `yaw` about its centre.
static func _rbox(mb, c: Vector3, size: Vector3, yaw: float, color: Color) -> void:
	var saved := _push(mb, c, yaw)
	mb.box(Vector3.ZERO, size, color)
	mb.xform = saved


## The normal of triangle a, b, c turned to agree with `hint`.
static func _face_n(a: Vector3, b: Vector3, c: Vector3, hint: Vector3) -> Vector3:
	var n := (b - a).cross(c - a).normalized()
	return -n if n.dot(hint) < 0.0 else n


## A flat disc facing up.
static func _disc(mb, c: Vector3, r: float, color: Color, segs := 8) -> void:
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		mb.tri(c, c + Vector3(cos(a0), 0, sin(a0)) * r, c + Vector3(cos(a1), 0, sin(a1)) * r, Vector3.UP, color)


## A point on the plane through o spanned by u (along) and v (up).
static func _wp(o: Vector3, u: Vector3, a: Vector2, v := Vector3.UP) -> Vector3:
	return o + u * a.x + v * a.y


## A flat rectangle centred on o in the plane (u, v), facing n.
static func _panel(mb, o: Vector3, u: Vector3, n: Vector3, size: Vector2, color: Color, v := Vector3.UP) -> void:
	var a := u * size.x * 0.5
	var b := v * size.y * 0.5
	mb.quad(o - a - b, o + a - b, o + a + b, o - a + b, n, color)


## A flat stroke from a to b (plane coordinates about o), t wide, facing n.
static func _stroke(mb, o: Vector3, u: Vector3, n: Vector3, a: Vector2, b: Vector2, t: float, color: Color, v := Vector3.UP) -> void:
	var dv := b - a
	if dv.length() < 0.001:
		return
	var p := Vector2(-dv.y, dv.x).normalized() * t * 0.5
	mb.quad(_wp(o, u, a - p, v), _wp(o, u, b - p, v), _wp(o, u, b + p, v), _wp(o, u, a + p, v), n, color)


## A flat ellipse centred on o in the plane (u, v), facing n.
static func _ellipse(mb, o: Vector3, u: Vector3, n: Vector3, rx: float, ry: float, color: Color, segs := 8, v := Vector3.UP) -> void:
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		mb.tri(o, _wp(o, u, Vector2(cos(a0) * rx, sin(a0) * ry), v), _wp(o, u, Vector2(cos(a1) * rx, sin(a1) * ry), v), n, color)


## A strip lying on the ground from a to b (x, z), wd wide, at height y.
static func _strip(mb, a: Vector2, b: Vector2, wd: float, y: float, color: Color) -> void:
	var dv := b - a
	if dv.length() < 0.01:
		return
	var p := Vector2(-dv.y, dv.x).normalized() * wd * 0.5
	mb.quad(Vector3(a.x - p.x, y, a.y - p.y), Vector3(b.x - p.x, y, b.y - p.y), Vector3(b.x + p.x, y, b.y + p.y), Vector3(a.x + p.x, y, a.y + p.y), Vector3.UP, color)


## A blob lying flat on the ground (stains, ash, dirt, puddles).
static func _blot(mb, x: float, z: float, rx: float, rz: float, y: float, color: Color, segs := 9) -> void:
	_ellipse(mb, Vector3(x, y, z), Vector3.RIGHT, Vector3.UP, rx, rz, color, segs, Vector3.BACK)


static func _pick_state(weights: Array, rng: RandomNumberGenerator) -> int:
	var r := rng.randf()
	for i in weights.size():
		r -= float(weights[i])
		if r <= 0.0:
			return i
	return 0


# --- Ground wear ---------------------------------------------------------------

## `n` wandering cracks over x0..x1 by z0..z1, drawn at height y.
static func _cracks(mb, x0: float, x1: float, z0: float, z1: float, n: int, rng: RandomNumberGenerator, y := 0.05) -> void:
	var crack := _g(CRACK, MeshBuilder.ASPHALT)
	for i in n:
		var p := Vector2(rng.randf_range(x0 + 0.4, x1 - 0.4), rng.randf_range(z0 + 0.4, z1 - 0.4))
		var a := rng.randf() * TAU
		for k in 3:
			a += rng.randf_range(-0.7, 0.7)
			var q := p + Vector2(cos(a), sin(a)) * rng.randf_range(0.8, 2.2)
			q.x = clampf(q.x, x0 + 0.1, x1 - 0.1)
			q.y = clampf(q.y, z0 + 0.1, z1 - 0.1)
			_strip(mb, p, q, 0.07, y, crack)
			p = q


## Oil stains and patched rectangles over x0..x1 by z0..z1.
static func _stains(mb, x0: float, x1: float, z0: float, z1: float, n: int, rng: RandomNumberGenerator, y := 0.045) -> void:
	for i in n:
		var rx := rng.randf_range(0.4, 1.1)
		var rz := rng.randf_range(0.4, 1.1)
		var x := rng.randf_range(x0 + rx, x1 - rx)
		var z := rng.randf_range(z0 + rz, z1 - rz)
		if i % 3 == 2:
			mb.box(Vector3(x, y, z), Vector3(rx * 2.0, 0.02, rz * 2.0), _g(PATCH, MeshBuilder.ASPHALT))
		else:
			_blot(mb, x, z, rx, rz, y + 0.004, _g(OIL, MeshBuilder.ASPHALT))


## A tuft of weeds.
static func _weed(mb, p: Vector3, r: float, rng: RandomNumberGenerator) -> void:
	var c: Color = WEED.lerp(DRY, rng.randf() * 0.7)
	mb.clump(p + Vector3(0, r * 0.45, 0), Vector3(r, r * 0.6, r), _g(c, MeshBuilder.GRASS), rng.randi(), 5, 3, 0.35)


## `n` weed tufts scattered over x0..x1 by z0..z1.
static func _weeds(mb, x0: float, x1: float, z0: float, z1: float, n: int, rng: RandomNumberGenerator, rmin := 0.25, rmax := 0.55) -> void:
	for i in n:
		var r := minf(rng.randf_range(rmin, rmax), minf(x1 - x0, z1 - z0) / 2.8)
		var m := r * 1.4  # the clump's lumps reach about 1.35 r
		_weed(mb, Vector3(rng.randf_range(x0 + m, x1 - m), 0.0, rng.randf_range(z0 + m, z1 - m)), r, rng)


## Faded parking stall lines: `n` bays along X from x0, `depth` from the
## kerb line z toward dir; a few lines worn away.
static func _stalls(mb, x0: float, z: float, n: int, bay: float, depth: float, dir: float, rng: RandomNumberGenerator) -> void:
	var paint := Color(0.78, 0.77, 0.7)
	for i in n + 1:
		if rng.randf() < 0.2:
			continue
		var x := x0 + i * bay
		_strip(mb, Vector2(x, z), Vector2(x, z + depth * dir * rng.randf_range(0.6, 1.0)), 0.11, 0.06, paint)


# --- Wall dressing --------------------------------------------------------------

## Abstract glyph bars (sign "lettering" that never reads): o is the
## middle of the run on the face, w by h.
static func _glyphs(mb, o: Vector3, u: Vector3, n: Vector3, w: float, h: float, color: Color, rng: RandomNumberGenerator) -> void:
	var k := maxi(2, int(w / (h * 0.75)))
	var sw := w / k
	var t := minf(h * 0.2, sw * 0.22)
	for i in k:
		var x0 := -w * 0.5 + i * sw + sw * 0.15
		var x1 := x0 + sw * 0.62
		var yb := -h * 0.5
		var yt := h * 0.5
		_stroke(mb, o, u, n, Vector2(x0, yb), Vector2(x0, yt), t, color)
		match rng.randi() % 4:
			0: _stroke(mb, o, u, n, Vector2(x0, yt - t * 0.5), Vector2(x1, yt - t * 0.5), t, color)
			1: _stroke(mb, o, u, n, Vector2(x0, 0.0), Vector2(x1, 0.0), t, color)
			2: _stroke(mb, o, u, n, Vector2(x0, yb + t * 0.5), Vector2(x1, yb + t * 0.5), t, color)
			_: _stroke(mb, o, u, n, Vector2(x1, yb), Vector2(x1, yt), t, color)


## An abstract spray-paint tag on a wall: o its centre on the face, u along
## the wall, n out (v up the wall). Bubble blobs, angular shards or a
## scribble, with drips; never letters. Reaches about 0.35 h + 0.45 m below
## its centre.
static func _tag(mb, o: Vector3, u: Vector3, n: Vector3, w: float, h: float, rng: RandomNumberGenerator, v := Vector3.UP) -> void:
	var ink: Color = Kit._pick(INKS, rng)
	var ink2: Color = Kit._pick(INKS, rng)
	var line := Color(0.06, 0.06, 0.07)
	var o1 := o + n * 0.02
	var o2 := o + n * 0.035
	var o3 := o + n * 0.05
	match rng.randi() % 3:
		0: # bubble blobs with an outline and a swoosh
			var k := clampi(int(w / maxf(h * 0.8, 0.3)), 2, 4)
			for i in k:
				var c := Vector2(-w * 0.5 + (i + 0.5) * w / k, rng.randf_range(-0.08, 0.08) * h)
				var rx := w / k * 0.62
				var ry := h * rng.randf_range(0.36, 0.46)
				_ellipse(mb, _wp(o1, u, c, v), u, n, rx + 0.07, ry + 0.07, line, 8, v)
				_ellipse(mb, _wp(o2, u, c, v), u, n, rx, ry, ink if i % 2 == 0 else ink.lightened(0.2), 8, v)
			_stroke(mb, o3, u, n, Vector2(-w * 0.42, -h * 0.12), Vector2(w * 0.42, h * 0.18), h * 0.08, ink2, v)
		1: # angular shards and an arrow
			var k := clampi(int(w / maxf(h * 0.6, 0.3)), 2, 5)
			for i in k:
				var s := -w * 0.5 + (i + 0.5) * w / k
				var hw := w / k * 0.55
				var pa := Vector2(s - hw, -h * 0.42)
				var pb := Vector2(s + hw * 0.3, -h * 0.46)
				var pc := Vector2(s + hw * rng.randf_range(0.6, 1.0), h * rng.randf_range(0.3, 0.46))
				var m := (pa + pb + pc) / 3.0
				mb.tri(_wp(o1, u, m + (pa - m) * 1.18, v), _wp(o1, u, m + (pb - m) * 1.18, v), _wp(o1, u, m + (pc - m) * 1.18, v), n, line)
				mb.tri(_wp(o2, u, pa, v), _wp(o2, u, pb, v), _wp(o2, u, pc, v), n, ink if i % 2 == 0 else ink2)
			var tip := Vector2(w * 0.45, h * 0.3)
			_stroke(mb, o3, u, n, Vector2(w * 0.1, -h * 0.1), tip, h * 0.07, ink2, v)
			_stroke(mb, o3, u, n, tip, tip + Vector2(-h * 0.22, 0.0), h * 0.07, ink2, v)
			_stroke(mb, o3, u, n, tip, tip + Vector2(-h * 0.04, -h * 0.22), h * 0.07, ink2, v)
		_: # a quick scribble with an underline
			var pts := maxi(4, int(w / 0.35))
			var prev := Vector2(-w * 0.5, rng.randf_range(-0.3, 0.3) * h)
			for i in range(1, pts + 1):
				var q := Vector2(-w * 0.5 + w * i / pts, rng.randf_range(-0.42, 0.42) * h)
				_stroke(mb, o2, u, n, prev, q, h * 0.09, ink, v)
				prev = q
			_stroke(mb, o3, u, n, Vector2(-w * 0.45, -h * 0.47), Vector2(w * 0.45, -h * 0.42), h * 0.05, ink2, v)
	for i in rng.randi_range(1, 3):
		var s := rng.randf_range(-w * 0.4, w * 0.4)
		_stroke(mb, o2, u, n, Vector2(s, -h * 0.3), Vector2(s, -h * 0.3 - rng.randf_range(0.12, 0.45)), 0.04, ink, v)


## An abstract neon figure on a sign face (o its centre, about s across):
## 0 a bent arrow, 1 a ring, 2 an eight-ray burst, 3 a zigzag bolt.
static func _neon_shape(mb, o: Vector3, u: Vector3, n: Vector3, s: float, shape: int, color: Color) -> void:
	var t := s * 0.07
	match shape:
		0:
			var pts: Array[Vector2] = [Vector2(-0.45, 0.32), Vector2(0.15, 0.32), Vector2(0.3, 0.15), Vector2(0.3, -0.36)]
			for k in 3:
				_stroke(mb, o, u, n, pts[k] * s, pts[k + 1] * s, t, color)
			_stroke(mb, o, u, n, Vector2(0.3, -0.45) * s, Vector2(0.12, -0.24) * s, t, color)
			_stroke(mb, o, u, n, Vector2(0.3, -0.45) * s, Vector2(0.48, -0.24) * s, t, color)
		1:
			for i in 10:
				var a0 := TAU * i / 10.0
				var a1 := TAU * (i + 1) / 10.0
				_stroke(mb, o, u, n, Vector2(cos(a0), sin(a0)) * s * 0.38, Vector2(cos(a1), sin(a1)) * s * 0.38, t, color)
			_ellipse(mb, o, u, n, s * 0.08, s * 0.08, color, 6)
		2:
			for i in 4:
				var a := PI * i / 4.0
				_stroke(mb, o, u, n, Vector2(cos(a), sin(a)) * -s * 0.42, Vector2(cos(a), sin(a)) * s * 0.42, t, color)
		_:
			var pts: Array[Vector2] = [Vector2(-0.42, -0.22), Vector2(-0.14, 0.24), Vector2(0.14, -0.24), Vector2(0.42, 0.22)]
			for k in 3:
				_stroke(mb, o, u, n, pts[k] * s, pts[k + 1] * s, t, color)


## A box sign on a wall: c is the middle of its back on the wall face, u
## along the wall, n out. Lit: a glowing colour field with dark glyph bars;
## otherwise a dark face with glowing glyph bars (channel letters).
static func _sign_band(mb, c: Vector3, u: Vector3, n: Vector3, w: float, h: float, field: Color, rng: RandomNumberGenerator, lit := true) -> void:
	mb.box(c + n * 0.15, u.abs() * w + Vector3(0, h, 0) + n.abs() * 0.3, Color(0.16, 0.16, 0.17))
	var face := c + n * 0.31
	var glow_c := _g(field, MeshBuilder.GLOW_NEON)
	if lit:
		_panel(mb, face, u, n, Vector2(w - 0.2, h - 0.16), glow_c)
		_glyphs(mb, face + n * 0.02, u, n, w * 0.78, h * 0.5, field.darkened(0.8), rng)
	else:
		_panel(mb, face, u, n, Vector2(w - 0.2, h - 0.16), Color(0.1, 0.1, 0.11))
		_glyphs(mb, face + n * 0.02, u, n, w * 0.78, h * 0.5, glow_c, rng)


## A faded painted wall advert (a ghost sign): colour field, glyph bars
## and a disc, all washed out.
static func _ghost_sign(mb, c: Vector3, u: Vector3, n: Vector3, w: float, h: float, rng: RandomNumberGenerator) -> void:
	var base: Color = (Kit._pick(SIGN_FIELDS, rng) as Color).lerp(Color(0.7, 0.66, 0.6), 0.55)
	_panel(mb, c + n * 0.02, u, n, Vector2(w, h), base)
	_glyphs(mb, c + n * 0.035 + u * w * 0.1, u, n, w * 0.65, h * 0.45, base.darkened(0.35), rng)
	_ellipse(mb, c + n * 0.035 - u * w * 0.36, u, n, h * 0.32, h * 0.32, base.lerp(Color(0.8, 0.3, 0.25), 0.3), 10)


## Security bars over an opening w x h centred on c (on the wall face).
static func _bars(mb, c: Vector3, u: Vector3, n: Vector3, w: float, h: float) -> void:
	var o := c + n * 0.09
	var iron := _g(IRON, MeshBuilder.GLOSS)
	var k := maxi(3, int(w / 0.17))
	for i in k + 1:
		var s := -w * 0.5 + w * i / k
		_stroke(mb, o, u, n, Vector2(s, -h * 0.5), Vector2(s, h * 0.5), 0.045, iron)
	for y: float in [-h * 0.5 + 0.03, 0.0, h * 0.5 - 0.03]:
		_stroke(mb, o + n * 0.005, u, n, Vector2(-w * 0.5, y), Vector2(w * 0.5, y), 0.06, iron)


## One window (c its centre on the wall face, u along, n out) in a state:
## 0 glass, 1 barred glass, 2 boarded, 3 broken (dark, a shard or two
## left), 4 hung with a sheet.
static func _win(mb, c: Vector3, u: Vector3, n: Vector3, size: Vector2, state: int, rng: RandomNumberGenerator, lit := 0.3) -> void:
	var o := c + n * 0.03
	match state:
		2:
			_panel(mb, o, u, n, size + Vector2(0.2, 0.2), _g(PLYWOOD.darkened(rng.randf() * 0.25), MeshBuilder.SIDING))
			_stroke(mb, o + n * 0.02, u, n, Vector2(-size.x * 0.5, -size.y * 0.3), Vector2(size.x * 0.5, size.y * 0.3), 0.12, PLYWOOD.darkened(0.4))
		3:
			_panel(mb, o, u, n, size, RECESS)
			var g := _g(Color(0.5, 0.58, 0.62), MeshBuilder.GLOSS)
			var q := o + n * 0.01
			mb.tri(_wp(q, u, Vector2(-size.x * 0.5, size.y * 0.5)), _wp(q, u, Vector2(-size.x * 0.1, size.y * 0.5)), _wp(q, u, Vector2(-size.x * 0.5, size.y * 0.05)), n, g)
			mb.tri(_wp(q, u, Vector2(size.x * 0.5, -size.y * 0.5)), _wp(q, u, Vector2(size.x * 0.15, -size.y * 0.5)), _wp(q, u, Vector2(size.x * 0.5, -size.y * 0.1)), n, g)
		4:
			_panel(mb, o, u, n, size, Kit._pick(SHEETS, rng))
		_:
			_panel(mb, o, u, n, size, Buildings._window(rng, lit))
			if state == 1:
				_bars(mb, c, u, n, size.x + 0.1, size.y + 0.1)


## Window rows on one wall face from a to b (x, z on the face) for `floors`
## floors of fh, one window per `step` metres, sills from y0. The ground
## floor is barred by `bars`; upper floors follow `weights` (glass, barred,
## boarded, broken, sheet); some glass gets a wall AC unit.
static func _face_windows(mb, a: Vector2, b: Vector2, n: Vector3, floors: int, fh: float, step: float, size: Vector2, rng: RandomNumberGenerator, y0 := 1.55, bars := 0.6, weights := [0.76, 0.05, 0.06, 0.05, 0.08], ac := 0.12) -> void:
	var count := maxi(1, int(a.distance_to(b) / step))
	var u := Vector3(b.x - a.x, 0, b.y - a.y).normalized()
	for f in floors:
		var y := y0 + f * fh
		for i in count:
			var p := a.lerp(b, (i + 0.5) / count)
			var c := Vector3(p.x, y, p.y)
			var st := 0
			if f == 0:
				st = 1 if rng.randf() < bars else _pick_state([0.8, 0.0, 0.12, 0.08, 0.0], rng)
			else:
				st = _pick_state(weights, rng)
			_win(mb, c, u, n, size, st, rng, 0.35)
			if st == 0 and rng.randf() < ac:
				mb.box(c + n * 0.2 - Vector3(0, size.y * 0.5 - 0.2, 0), u.abs() * 0.65 + Vector3(0, 0.42, 0) + n.abs() * 0.4, _g(Color(0.8, 0.8, 0.76), MeshBuilder.METAL))


## `count` windows evenly spaced from a to b (centres, on the wall face, n
## out), each in a state drawn from `weights`.
static func _win_row(mb, a: Vector3, b: Vector3, n: Vector3, count: int, size: Vector2, rng: RandomNumberGenerator, weights: Array) -> void:
	var u := (b - a).normalized()
	for i in count:
		_win(mb, a.lerp(b, (i + 0.5) / count), u, n, size, _pick_state(weights, rng), rng, 0.2)


## A steel factory window, w x h centred on c: a dark frame with a grid of
## panes, `broken` of them gone.
static func _factory_window(mb, c: Vector3, u: Vector3, n: Vector3, w: float, h: float, rng: RandomNumberGenerator, broken: float) -> void:
	_panel(mb, c + n * 0.03, u, n, Vector2(w, h), Color(0.05, 0.05, 0.06))
	# Matte grimy panes: GLASS lights some panes at night and GLOSS glints
	# like a lit window under the moon; these sheds stand dark.
	var glass := Color(0.36, 0.42, 0.4)
	const COLS := 4
	const ROWS := 3
	var pw := w / COLS
	var ph := h / ROWS
	for i in COLS:
		for j in ROWS:
			if rng.randf() < broken:
				continue
			_panel(mb, c + n * 0.045 + u * (-w * 0.5 + (i + 0.5) * pw) + Vector3(0, -h * 0.5 + (j + 0.5) * ph, 0), u, n, Vector2(pw - 0.08, ph - 0.08), glass.darkened(rng.randf() * 0.25))


## A roll-down steel shutter over an opening w x h (c the middle of its sill
## on the wall face), `open` of it rolled up (the gap shows dark), with its
## drum box on top and often a tag.
static func _shutter(mb, c: Vector3, u: Vector3, n: Vector3, w: float, h: float, open: float, rng: RandomNumberGenerator) -> void:
	var closed := h * (1.0 - open)
	if open > 0.02:
		_panel(mb, c + n * 0.02 + Vector3(0, h * 0.5, 0), u, n, Vector2(w, h), RECESS)
	if closed > 0.05:
		var metal := _g(Color(0.62, 0.63, 0.62).darkened(rng.randf() * 0.25), MeshBuilder.SIDING)
		var mc := c + n * 0.06 + Vector3(0, h - closed * 0.5, 0)
		_panel(mb, mc, u, n, Vector2(w, closed), metal)
		if closed > 1.6 and rng.randf() < 0.7:
			_tag(mb, mc, u, n, w * 0.7, minf(closed * 0.5, 1.3), rng)
	mb.box(c + n * 0.18 + Vector3(0, h + 0.22, 0), u.abs() * (w + 0.2) + Vector3(0, 0.44, 0) + n.abs() * 0.36, _g(Color(0.42, 0.43, 0.44), MeshBuilder.METAL))


## A worn flat roof over x0..x1 by z0..z1 at height `top`: a stained
## membrane in a parapet, tar patches, often a blue tarp held down by old
## tyres, an AC unit and vent stacks.
static func _shabby_roof(mb, x0: float, x1: float, z0: float, z1: float, top: float, edge: Color, rng: RandomNumberGenerator, ph := 0.6) -> void:
	var w := x1 - x0
	var d := z1 - z0
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	mb.box(Vector3(cx, top + 0.02, cz), Vector3(w - 0.3, 0.04, d - 0.3), _g(MEMBRANE.darkened(rng.randf() * 0.18), MeshBuilder.ROOF))
	const T := 0.3
	var e := _g(edge, MeshBuilder.CONCRETE)
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(cx + s * (w * 0.5 - T * 0.5), top + ph * 0.5, cz), Vector3(T, ph, d), e)
		mb.box(Vector3(cx, top + ph * 0.5, cz + s * (d * 0.5 - T * 0.5)), Vector3(w - T * 2.0, ph, T), e)
	for i in rng.randi_range(2, 4) + mini(4, int(w * d / 120.0)):
		var pw := rng.randf_range(0.8, minf(3.5, w * 0.4))
		var pd := rng.randf_range(0.6, minf(2.5, d * 0.4))
		var px := rng.randf_range(x0 + 0.5 + pw * 0.5, x1 - 0.5 - pw * 0.5)
		var pz := rng.randf_range(z0 + 0.5 + pd * 0.5, z1 - 0.5 - pd * 0.5)
		mb.box(Vector3(px, top + 0.05, pz), Vector3(pw, 0.02, pd), TAR if rng.randf() < 0.65 else MEMBRANE.lightened(0.18))
	if rng.randf() < 0.45 and w > 4.5 and d > 4.5:
		var tw := minf(rng.randf_range(2.5, 4.5), w - 1.6)
		var td := minf(rng.randf_range(2.0, 3.5), d - 1.6)
		var yaw := rng.randf_range(-0.3, 0.3)
		var ex := (tw * cos(yaw) + td * absf(sin(yaw))) * 0.5
		var ez := (td * cos(yaw) + tw * absf(sin(yaw))) * 0.5
		var tx := rng.randf_range(x0 + 0.4 + ex, x1 - 0.4 - ex)
		var tz := rng.randf_range(z0 + 0.4 + ez, z1 - 0.4 - ez)
		_rbox(mb, Vector3(tx, top + 0.08, tz), Vector3(tw, 0.02, td), yaw, Kit._pick(TARPS, rng))
		for k in rng.randi_range(2, 4):
			mb.cylinder(Vector3(tx + rng.randf_range(-0.35, 0.35) * tw, top + 0.09, tz + rng.randf_range(-0.35, 0.35) * td), 0.3, 0.16, TYRE, 6)
	if w > 4.5 and d > 3.5:
		var hx := minf(1.8, w * 0.3)
		Buildings._hvac(mb, Vector3(cx + rng.randf_range(-0.25, 0.25) * (w - hx - 1.0), top, cz + d * 0.18), Vector3(hx, 0.8, minf(1.1, d * 0.25)))
	for i in rng.randi_range(1, 3):
		mb.cylinder(Vector3(rng.randf_range(x0 + 0.6, x1 - 0.6), top, rng.randf_range(z0 + 0.6, z1 - 0.6)), 0.1, 0.6, _g(Color(0.5, 0.5, 0.5), MeshBuilder.METAL), 4)


## A panel lying on one slope of a gable whose ridge runs along Z (built
## by Kit._gable with along_z) over centre x cx, eaves at `eave`, half span
## hs, rising `rise`: side s (+1 / -1), z0..z1, from f0 to f1 of the way
## from the ridge down to the eave.
static func _gable_patch(mb, cx: float, eave: float, hs: float, rise: float, s: float, z0: float, z1: float, f0: float, f1: float, color: Color) -> void:
	var n := Vector3(s * rise, hs, 0).normalized()
	var xa := cx + s * hs * f0
	var xb := cx + s * hs * f1
	var ya := eave + rise * (1.0 - f0) + 0.05
	var yb := eave + rise * (1.0 - f1) + 0.05
	mb.quad(Vector3(xa, ya, z0), Vector3(xb, yb, z0), Vector3(xb, yb, z1), Vector3(xa, ya, z1), n, color)


# --- Fences ---------------------------------------------------------------------

## One wire of a chain-link mesh in the fence's local XY plane, both faces.
static func _wire(mb, a: Vector3, b: Vector3, color: Color, t := 0.05) -> void:
	var dv := b - a
	var p := Vector3(-dv.y, dv.x, 0).normalized() * t * 0.5
	mb.quad(a - p, b - p, b + p, a + p, Vector3.FORWARD, color)
	mb.quad(a - p, b - p, b + p, a + p, Vector3.BACK, color)


## The chain-link mesh in the fence's plane (z = 0): wires at 45 degrees
## both ways, `pitch` apart along x, clipped to x0..x1 by y0..y1, so it
## reads as a diamond lattice.
static func _diamonds(mb, x0: float, x1: float, y0: float, y1: float, pitch: float, color: Color) -> void:
	var hh := y1 - y0
	var c := x0 - hh + fmod(x1 - x0, pitch) * 0.5
	while c < x1:
		# Rising: x = c + (y - y0). Falling: x = c + hh - (y - y0).
		var ya := maxf(y0, y0 + x0 - c)
		var yb := minf(y1, y0 + x1 - c)
		if yb - ya > 0.05:
			_wire(mb, Vector3(c + ya - y0, ya, 0), Vector3(c + yb - y0, yb, 0), color, 0.03)
		var e := c + hh
		ya = maxf(y0, y0 + e - x1)
		yb = minf(y1, y0 + e - x0)
		if yb - ya > 0.05:
			_wire(mb, Vector3(e - (ya - y0), ya, 0), Vector3(e - (yb - y0), yb, 0), color, 0.03)
		c += pitch


## A chain-link fence on the ground from a to b, h tall: galvanised posts
## about every 2.5 m, a top rail and a criss-cross mesh of `mesh` wires each
## way per bay, both faces; barbed wire on top if asked; with `gap` one bay
## is torn out. Collides (in two pieces round a gap).
static func _chainlink(mb, out: Array, a: Vector3, b: Vector3, h: float, rng: RandomNumberGenerator, barbed := false, gap := false, mesh := 3, collide := true) -> void:
	var dir := b - a
	var length := dir.length()
	if length < 0.3:
		return
	var yaw := atan2(-dir.z, dir.x)
	var rot := Basis(Vector3.UP, yaw)
	var mid := (a + b) * 0.5
	var saved := _push(mb, mid, yaw)
	var galv := _g(Color(0.68, 0.7, 0.72), MeshBuilder.METAL)
	var wire := _g(Color(0.6, 0.62, 0.64), MeshBuilder.METAL)
	var bays := maxi(1, int(round(length / 2.5)))
	var bl := length / bays
	var hole := rng.randi() % bays if gap and bays > 1 else -1
	for i in bays + 1:
		var x := clampf(-length * 0.5 + i * bl, -length * 0.5 + 0.06, length * 0.5 - 0.06)
		mb.box(Vector3(x, h * 0.5, 0), Vector3(0.12, h, 0.12), galv)
	for i in bays:
		var x0 := -length * 0.5 + i * bl
		if i == hole:
			# The mesh hangs off one post, curled out at the bottom.
			_wire(mb, Vector3(x0 + 0.1, h - 0.1, 0), Vector3(x0 + bl * 0.3, 0.3, -0.5), wire)
			_wire(mb, Vector3(x0 + bl * 0.3, h - 0.1, 0), Vector3(x0 + 0.1, 0.4, -0.4), wire)
			continue
		mb.box(Vector3(x0 + bl * 0.5, h - 0.03, 0), Vector3(bl, 0.05, 0.05), galv)
		_diamonds(mb, x0 + 0.06, x0 + bl - 0.06, 0.05, h - 0.06, 1.8 / mesh, wire)
		if barbed:
			for k in 2:
				mb.box(Vector3(x0 + bl * 0.5, h + 0.18 + k * 0.17, -0.1 - k * 0.1), Vector3(bl, 0.03, 0.03), Color(0.4, 0.4, 0.42))
	mb.xform = saved
	if not collide:
		return
	if hole < 0:
		Kit._col(out, mid + Vector3(0, h * 0.5, 0), Vector3(length, h, 0.15), yaw)
		return
	var l0 := hole * bl
	var l1 := length - (hole + 1) * bl
	if l0 > 0.1:
		Kit._col(out, mid + rot * Vector3(-length * 0.5 + l0 * 0.5, h * 0.5, 0), Vector3(l0, h, 0.15), yaw)
	if l1 > 0.1:
		Kit._col(out, mid + rot * Vector3(length * 0.5 - l1 * 0.5, h * 0.5, 0), Vector3(l1, h, 0.15), yaw)


## Chain-link runs along one line z from x0 to x1, leaving `gaps` ([a, b]
## pairs along x) open.
static func _chainlink_x(mb, out: Array, x0: float, x1: float, z: float, h: float, gaps: Array, rng: RandomNumberGenerator, barbed := false, mesh := 2) -> void:
	var x := x0
	gaps.sort_custom(func(p, q): return p[0] < q[0])
	for g in gaps:
		if g[0] - x > 0.5:
			_chainlink(mb, out, Vector3(x, 0, z), Vector3(g[0], 0, z), h, rng, barbed, false, mesh)
		x = maxf(x, g[1])
	if x1 - x > 0.5:
		_chainlink(mb, out, Vector3(x, 0, z), Vector3(x1, 0, z), h, rng, barbed, false, mesh)


## A corrugated sheet-metal fence from a to b, h tall: panels about 1.2 m
## wide in mismatched rust, grey and faded paint, posts every 5 m. Collides.
static func _sheet_fence(mb, out: Array, a: Vector3, b: Vector3, h: float, rng: RandomNumberGenerator) -> void:
	var dir := b - a
	var length := dir.length()
	if length < 0.5:
		return
	var yaw := atan2(-dir.z, dir.x)
	var mid := (a + b) * 0.5
	var saved := _push(mb, mid, yaw)
	var n := maxi(1, int(length / 1.2))
	var pw := length / n
	for i in n:
		var c: Color = (Kit._pick(METALS, rng) as Color).darkened(rng.randf() * 0.15)
		var ph := h - rng.randf_range(0.0, 0.3)
		mb.box(Vector3(-length * 0.5 + (i + 0.5) * pw, ph * 0.5, rng.randf_range(-0.02, 0.02)), Vector3(pw + 0.03, ph, 0.05), _g(c, MeshBuilder.SEAM_ROOF))
	var posts := maxi(1, int(length / 5.0))
	for i in posts + 1:
		var x := clampf(-length * 0.5 + length * i / posts, -length * 0.5 + 0.07, length * 0.5 - 0.07)
		mb.box(Vector3(x, h * 0.5 + 0.05, 0.1), Vector3(0.14, h + 0.1, 0.12), Color(0.3, 0.3, 0.31))
	mb.xform = saved
	Kit._col(out, mid + Vector3(0, h * 0.5, 0), Vector3(length, h, 0.2), yaw)


# --- Signs -----------------------------------------------------------------------

## A tall pole sign: a steel pole at p, a cabinet `size` (x wide, y tall)
## at height h facing both ways along Z, each face with a neon figure and a
## lit colour field with glyph bars, and a lit strip below. Only the pole
## collides. `dead` leaves it unlit and faded.
static func _pole_sign(mb, out: Array, p: Vector3, h: float, size: Vector2, field: Color, neon: Color, shape: int, rng: RandomNumberGenerator, dead := false) -> void:
	var ph := h - size.y * 0.5
	mb.box(p + Vector3(0, ph * 0.5, 0), Vector3(0.35, ph, 0.35), _g(Color(0.35, 0.36, 0.37), MeshBuilder.METAL))
	out.append([p + Vector3(0, 1.5, 0), Vector3(0.4, 3.0, 0.4)])
	var c := p + Vector3(0, h, 0)
	var frame := Color(0.18, 0.18, 0.19)
	mb.box(c, Vector3(size.x, size.y, 0.5), frame)
	mb.box(c + Vector3(0, size.y * 0.5 + 0.08, 0), Vector3(size.x, 0.16, 0.56), field.darkened(0.4))
	var ng := neon.darkened(0.5) if dead else _g(neon, MeshBuilder.GLOW_NEON)
	var fg := field.darkened(0.45) if dead else _g(field, MeshBuilder.GLOW_NEON)
	var sc := c - Vector3(0, size.y * 0.5 + 0.45, 0)
	mb.box(sc, Vector3(size.x * 0.62, 0.5, 0.3), frame)
	var strip_lit := not dead and rng.randf() < 0.75
	for n: Vector3 in [Vector3.FORWARD, Vector3.BACK]:
		var u := Vector3(-n.z, 0, n.x)
		var f := c + n * 0.26
		_panel(mb, f, u, n, Vector2(size.x - 0.2, size.y - 0.2), Color(0.1, 0.1, 0.12))
		_neon_shape(mb, f + n * 0.02 - u * size.x * 0.26, u, n, minf(size.y * 0.8, size.x * 0.4), shape, ng)
		_panel(mb, f + n * 0.02 + u * size.x * 0.2, u, n, Vector2(size.x * 0.48, size.y * 0.55), fg)
		_glyphs(mb, f + n * 0.04 + u * size.x * 0.2, u, n, size.x * 0.38, size.y * 0.3, field.darkened(0.8), rng)
		_panel(mb, sc + n * 0.16, u, n, Vector2(size.x * 0.56, 0.34), ng if strip_lit else Color(0.22, 0.22, 0.22))


## A tall blade sign standing out from a wall facing n: o is its root on
## the wall face, y0..y1 its height, `out_by` how far it stands out. Neon
## cells run down both faces; dead, the tubes are dark and faded and one
## cell may still flicker.
static func _blade_sign(mb, o: Vector3, n: Vector3, y0: float, y1: float, out_by: float, field: Color, neon: Color, rng: RandomNumberGenerator, dead := true) -> void:
	var side := Vector3(-n.z, 0, n.x)
	var hgt := y1 - y0
	var c := o + n * (out_by * 0.5 + 0.25) + Vector3(0, (y0 + y1) * 0.5, 0)
	var iron := _g(IRON, MeshBuilder.GLOSS)
	mb.box(c, n.abs() * out_by + Vector3(0, hgt, 0) + side.abs() * 0.35, Color(0.2, 0.19, 0.19))
	for y: float in [y0 + 0.4, y1 - 0.4]:
		Kit._beam(mb, o + Vector3(0, y, 0), o + n * 0.3 + Vector3(0, y, 0), 0.12, iron)
	Kit._beam(mb, o + Vector3(0, y1 + 0.5, 0), c + n * out_by * 0.4 + Vector3(0, hgt * 0.5, 0), 0.06, iron)
	var cells := maxi(2, int(hgt / 1.1))
	var lit := rng.randi() % cells if (rng.randf() < 0.45 or not dead) else -1
	var cell_h := hgt / cells
	var s := minf(out_by * 0.6, cell_h * 0.7)
	var faded := field.darkened(0.55)
	for f: Vector3 in [side, -side]:
		var face := c + f * 0.18
		_panel(mb, face, n, f, Vector2(out_by - 0.15, hgt - 0.15), faded)
		for k in cells:
			var o2 := face + f * 0.02 + Vector3(0, hgt * 0.5 - (k + 0.5) * cell_h, 0)
			var tube := _g(neon, MeshBuilder.GLOW_NEON) if (k == lit or not dead) else Color(0.34, 0.32, 0.32)
			_stroke(mb, o2, n, f, Vector2(-s * 0.4, -s * 0.45), Vector2(-s * 0.4, s * 0.45), 0.08, tube)
			match (k * 7 + cells) % 3:
				0: _stroke(mb, o2, n, f, Vector2(-s * 0.4, s * 0.42), Vector2(s * 0.4, s * 0.42), 0.08, tube)
				1: _stroke(mb, o2, n, f, Vector2(s * 0.4, -s * 0.45), Vector2(s * 0.4, s * 0.45), 0.08, tube)
				_: _stroke(mb, o2, n, f, Vector2(-s * 0.4, 0.0), Vector2(s * 0.4, 0.0), 0.08, tube)


# --- Clutter ---------------------------------------------------------------------

## Trash bags heaped round p (within about 0.6 m plus their size).
static func _bags(mb, p: Vector3, n: int, rng: RandomNumberGenerator, spread := 0.6) -> void:
	for i in n:
		var r := rng.randf_range(0.26, 0.4)
		var q := p + Vector3(rng.randf_range(-spread, spread), 0, rng.randf_range(-spread, spread))
		mb.ball(q + Vector3(0, r * 0.78, 0), Vector3(r, r * 0.75, r * rng.randf_range(0.85, 1.15)), Kit._pick(BAGS, rng), 5, 3)


## Cardboard: a flattened sheet and a box or two round p (about 1 m each way).
static func _cardboard(mb, p: Vector3, rng: RandomNumberGenerator) -> void:
	var c := CARDBOARD.darkened(rng.randf() * 0.2)
	_rbox(mb, p + Vector3(0, 0.03, 0), Vector3(rng.randf_range(0.9, 1.2), 0.03, rng.randf_range(1.3, 1.7)), rng.randf_range(-0.3, 0.3), c.lightened(0.08))
	for i in rng.randi_range(1, 2):
		var s := rng.randf_range(0.4, 0.65)
		_rbox(mb, p + Vector3(rng.randf_range(-0.35, 0.35), s * 0.4, rng.randf_range(-0.35, 0.35)), Vector3(s, s * 0.8, s * 1.1), rng.randf_range(-0.6, 0.6), c)


## An old mattress lying flat (1.4 x 1.95), stained.
static func _mattress(mb, p: Vector3, yaw: float, rng: RandomNumberGenerator) -> void:
	var saved := _push(mb, p, yaw)
	var cloth := Color(0.86, 0.84, 0.76).lerp(Color(0.72, 0.78, 0.84), rng.randf() * 0.5).darkened(rng.randf() * 0.2)
	mb.box(Vector3(0, 0.11, 0), Vector3(1.4, 0.22, 1.95), cloth)
	mb.box(Vector3(0, 0.1, 0), Vector3(1.43, 0.12, 1.98), cloth.darkened(0.22))
	for i in rng.randi_range(1, 3):
		mb.box(Vector3(rng.randf_range(-0.4, 0.4), 0.225, rng.randf_range(-0.6, 0.6)), Vector3(rng.randf_range(0.25, 0.5), 0.01, rng.randf_range(0.25, 0.6)), Color(0.62, 0.52, 0.32))
	mb.xform = saved


## A wheelie bin.
static func _bin(mb, p: Vector3, yaw: float, color: Color) -> void:
	var saved := _push(mb, p, yaw)
	mb.box(Vector3(0, 0.5, 0), Vector3(0.62, 1.0, 0.72), _g(color, MeshBuilder.GLOSS))
	mb.box(Vector3(0, 1.03, 0.02), Vector3(0.66, 0.06, 0.78), _g(color.darkened(0.3), MeshBuilder.GLOSS))
	mb.xform = saved


## A dumpster (1.9 x 1.2) with one lid thrown back on a heap of bags.
static func _dumpster(mb, out: Array, p: Vector3, yaw: float, rng: RandomNumberGenerator) -> void:
	var saved := _push(mb, p, yaw)
	var paint := _g(Kit._pick(DUMPSTERS, rng), MeshBuilder.GLOSS)
	var lid := Color(0.15, 0.15, 0.16)
	mb.box(Vector3(0, 0.62, 0), Vector3(1.9, 1.15, 1.2), paint)
	mb.box(Vector3(0, 0.55, -0.61), Vector3(1.5, 0.5, 0.02), _g(RUST, MeshBuilder.METAL))
	mb.box(Vector3(-0.47, 1.22, 0), Vector3(0.92, 0.04, 1.16), lid)
	mb.box(Vector3(0.47, 1.21, 0), Vector3(0.86, 0.02, 1.1), DARK)
	mb.box(Vector3(0.47, 1.5, 0.6), Vector3(0.92, 0.6, 0.04), lid)
	_bags(mb, Vector3(0.47, 0.95, -0.05), 2, rng, 0.15)
	mb.xform = saved
	Kit._col(out, p + Vector3(0, 0.62, 0), Vector3(1.9, 1.25, 1.25), yaw)


## A stack of `n` old tyres at p.
static func _tyres(mb, out: Array, p: Vector3, n: int, collide := true) -> void:
	for k in n:
		mb.cylinder(p + Vector3(0, k * 0.24, 0), 0.37 if k % 2 == 0 else 0.355, 0.24, TYRE if k % 2 == 0 else TYRE.lightened(0.07), 7)
	_disc(mb, p + Vector3(0, n * 0.24 + 0.005, 0), 0.18, Color(0.03, 0.03, 0.03), 6)
	if collide:
		out.append([p + Vector3(0, n * 0.12, 0), Vector3(0.74, n * 0.24, 0.74)])


## A crate or milk crate.
static func _crate(mb, p: Vector3, s: float, yaw: float, color: Color) -> void:
	_rbox(mb, p + Vector3(0, s * 0.5, 0), Vector3(s, s, s), yaw, color)


## An old couch facing -Z (before yaw), 2 m wide.
static func _couch(mb, p: Vector3, yaw: float, color: Color) -> void:
	var saved := _push(mb, p, yaw)
	mb.box(Vector3(0, 0.25, 0), Vector3(2.0, 0.5, 0.9), color)
	mb.box(Vector3(0, 0.68, 0.33), Vector3(2.0, 0.5, 0.25), color.darkened(0.12))
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(s * 0.9, 0.62, -0.02), Vector3(0.22, 0.26, 0.86), color.darkened(0.05))
	mb.box(Vector3(-0.42, 0.53, -0.08), Vector3(0.8, 0.06, 0.66), color.lightened(0.1))
	mb.xform = saved


## A shopping cart (basket 0.56 x 0.9, handle toward +Z before yaw),
## loaded with bags and bundles if `load`.
static func _cart(mb, out: Array, p: Vector3, yaw: float, rng: RandomNumberGenerator, load := true, collide := true) -> void:
	var saved := _push(mb, p, yaw)
	var wire := _g(Color(0.74, 0.76, 0.78), MeshBuilder.METAL)
	const BW := 0.56
	const BL := 0.9
	const Y0 := 0.42
	const Y1 := 0.98
	mb.box(Vector3(0, Y0, 0.05), Vector3(BW, 0.02, BL), wire.darkened(0.3))
	for y: float in [Y0 + 0.2, Y1]:
		mb.box(Vector3(0, y, -BL * 0.5 + 0.05), Vector3(BW, 0.03, 0.03), wire)
		mb.box(Vector3(0, y, BL * 0.5 + 0.05), Vector3(BW, 0.03, 0.03), wire)
		mb.box(Vector3(-BW * 0.5, y, 0.05), Vector3(0.03, 0.03, BL), wire)
		mb.box(Vector3(BW * 0.5, y, 0.05), Vector3(0.03, 0.03, BL), wire)
	for x: float in [-BW * 0.5, BW * 0.5]:
		for z: float in [-BL * 0.5 + 0.05, BL * 0.5 + 0.05]:
			mb.box(Vector3(x, (Y0 + Y1) * 0.5, z), Vector3(0.04, Y1 - Y0, 0.04), wire)
		Kit._beam(mb, Vector3(x * 0.8, 0.1, -BL * 0.5 + 0.05), Vector3(x * 0.8, 0.1, BL * 0.5 + 0.05), 0.04, wire)
		Kit._beam(mb, Vector3(x * 0.8, 0.1, BL * 0.5 + 0.05), Vector3(x, Y0, BL * 0.5 + 0.05), 0.04, wire)
		Kit._beam(mb, Vector3(x, Y1, BL * 0.5 + 0.05), Vector3(x, Y1 + 0.1, BL * 0.5 + 0.22), 0.04, wire)
		for z: float in [-BL * 0.5 + 0.08, BL * 0.5 + 0.02]:
			mb.box(Vector3(x * 0.8, 0.07, z), Vector3(0.05, 0.14, 0.14), DARK)
	mb.box(Vector3(0, Y1 + 0.1, BL * 0.5 + 0.22), Vector3(BW + 0.04, 0.05, 0.05), _g(Color(0.75, 0.2, 0.18), MeshBuilder.GLOSS))
	if load:
		for k in rng.randi_range(1, 3):
			var r := rng.randf_range(0.2, 0.28)
			mb.ball(Vector3(rng.randf_range(-0.1, 0.1), Y1 - 0.05 + k * 0.08, -0.25 + k * 0.28), Vector3(r, r * 0.8, r), Kit._pick(BAGS + TARPS, rng), 5, 3)
	mb.xform = saved
	if collide:
		Kit._col(out, p + Basis(Vector3.UP, yaw) * Vector3(0, 0.55, 0.1), Vector3(0.6, 1.1, 1.2), yaw)


## A dome tent (rx by rz, h high) with its door toward -Z before yaw: eight
## panels round a mid ring, a fly over the crown in a second colour.
static func _tent(mb, out: Array, p: Vector3, yaw: float, rx: float, rz: float, h: float, color: Color, fly: Color) -> void:
	var saved := _push(mb, p, yaw)
	const S := 8
	var apex := Vector3(0, h, 0)
	for i in S:
		var a0 := TAU * i / S + PI / S
		var a1 := TAU * (i + 1) / S + PI / S
		var am := (a0 + a1) * 0.5
		var hint := Vector3(cos(am) / rx, 0.3, sin(am) / rz).normalized()
		var b0 := Vector3(cos(a0) * rx, 0.02, sin(a0) * rz)
		var b1 := Vector3(cos(a1) * rx, 0.02, sin(a1) * rz)
		var m0 := Vector3(b0.x * 0.78, h * 0.62, b0.z * 0.78)
		var m1 := Vector3(b1.x * 0.78, h * 0.62, b1.z * 0.78)
		mb.quad(b0, b1, m1, m0, _face_n(b0, b1, m1, hint), color if i % 2 == 0 else color.darkened(0.1))
		mb.tri(m0, m1, apex, _face_n(m0, m1, apex, hint), fly)
	# The door on the front panel.
	var fz := -rz * 0.924 - 0.03
	var tz := -rz * 0.743 - 0.03
	mb.tri(Vector3(-rx * 0.26, 0.05, fz), Vector3(rx * 0.26, 0.05, fz), Vector3(0, h * 0.55, tz), Vector3(0, 0.3, -1).normalized(), color.darkened(0.5))
	mb.xform = saved
	Kit._col(out, p + Vector3(0, h * 0.5, 0), Vector3(rx * 1.6, h, rz * 1.6), yaw)


## A tarp lean-to: a sheet from y_hi at its back edge (+Z before yaw)
## sagging down to y_lo at the front, on two poles; w along X, l deep.
static func _tarp(mb, p: Vector3, yaw: float, w: float, l: float, y_hi: float, y_lo: float, color: Color) -> void:
	var saved := _push(mb, p, yaw)
	var hw := w * 0.5
	var hl := l * 0.5
	var n := Vector3(0, l, -(y_hi - y_lo)).normalized()
	var a := Vector3(-hw, y_lo, -hl)
	var b := Vector3(hw, y_lo, -hl)
	var c := Vector3(hw, y_hi, hl)
	var e := Vector3(-hw, y_hi, hl)
	var ma := Vector3(0, y_lo - 0.1, -hl)
	var mc := Vector3(0, y_hi - 0.2, hl)
	mb.quad(a, ma, mc, e, n, color)
	mb.quad(ma, b, c, mc, n, color.darkened(0.08))
	var pole := Color(0.45, 0.45, 0.47)
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(s * (hw - 0.06), y_lo * 0.5, -hl + 0.06), Vector3(0.11, y_lo, 0.11), pole)
	mb.xform = saved


## A stripped car shell up on blocks (nose toward -Z before yaw): no hood,
## no doors, no glass, rust and primer, maybe one wheel left on.
static func _shell(mb, out: Array, p: Vector3, yaw: float, rng: RandomNumberGenerator, collide := true) -> void:
	var saved := _push(mb, p, yaw)
	var paint: Color = (Kit._pick(CAR_PAINTS, rng) as Color).lerp(RUST, rng.randf_range(0.0, 0.45))
	var body := _g(paint, MeshBuilder.GLOSS)
	const Y := 0.3
	mb.box(Vector3(0, Y + 0.3, 0), Vector3(1.8, 0.6, 4.3), body)
	mb.box(Vector3(0, Y + 0.61, -1.5), Vector3(1.5, 0.02, 1.15), RECESS)
	mb.box(Vector3(-0.2, Y + 0.64, -1.5), Vector3(0.6, 0.06, 0.5), Color(0.25, 0.25, 0.26))
	mb.box(Vector3(0, Y + 0.61, 0.3), Vector3(1.5, 0.02, 1.9), RECESS)
	for s: float in [-1.0, 1.0]:
		for z: float in [-0.7, 1.2]:
			mb.box(Vector3(s * 0.7, Y + 0.86, z), Vector3(0.11, 0.5, 0.11), body)
		mb.box(Vector3(s * 0.905, Y + 0.32, 0.15), Vector3(0.02, 0.42, 1.7), RECESS)
	mb.box(Vector3(0, Y + 1.13, 0.25), Vector3(1.55, 0.06, 1.95), body)
	mb.box(Vector3(rng.randf_range(-0.3, 0.3), Y + 1.17, 0.25), Vector3(0.7, 0.01, 0.8), _g(PRIMER if rng.randf() < 0.5 else RUST, MeshBuilder.METAL))
	mb.box(Vector3(rng.randf_range(-0.4, 0.4), Y + 0.61, 1.75), Vector3(0.8, 0.01, 0.5), _g(RUST, MeshBuilder.METAL))
	for x: float in [-0.7, 0.7]:
		for z: float in [-1.35, 1.35]:
			if rng.randf() < 0.2:
				Kit._wheel(mb, Vector3(x * 1.17, 0.34, z), 0.34, 0.22)
			else:
				mb.box(Vector3(x, Y * 0.5, z), Vector3(0.38, Y, 0.38), _g(CINDER, MeshBuilder.CONCRETE))
	mb.xform = saved
	if collide:
		Kit._col(out, p + Vector3(0, 0.75, 0), Vector3(1.8, 1.5, 4.3), yaw)


## A burnt-out car on its rims (nose toward -Z before yaw): charred shell,
## pillars, a sagging roof, no glass, ash on the ground under it.
static func _burnt_car(mb, out: Array, p: Vector3, yaw: float, rng: RandomNumberGenerator, ash := Vector2(1.25, 2.45)) -> void:
	var saved := _push(mb, p, yaw)
	var shell := _g(SOOT.lerp(RUST, rng.randf_range(0.2, 0.6)), MeshBuilder.METAL)
	_blot(mb, 0, 0, ash.x, ash.y, 0.05, ASH, 9)
	mb.box(Vector3(0, 0.52, 0), Vector3(1.8, 0.56, 4.3), shell)
	mb.box(Vector3(0, 0.81, -1.5), Vector3(1.6, 0.02, 1.15), _g(RUST.darkened(0.25), MeshBuilder.METAL))
	mb.box(Vector3(0, 0.81, 0.3), Vector3(1.6, 0.02, 1.9), DARK)
	mb.box(Vector3(rng.randf_range(-0.4, 0.4), 0.82, rng.randf_range(1.5, 1.8)), Vector3(0.6, 0.01, 0.5), Color(0.62, 0.6, 0.56))
	mb.box(Vector3(rng.randf_range(-0.4, 0.4), 0.82, -1.6), Vector3(0.5, 0.01, 0.6), Color(0.55, 0.53, 0.5))
	for s: float in [-1.0, 1.0]:
		for z: float in [-0.7, 1.25]:
			mb.box(Vector3(s * 0.7, 1.0, z), Vector3(0.11, 0.4, 0.11), shell)
	var sag := Vector3(0, 1.08, 0.3)
	for s: float in [-1.0, 1.0]:
		mb.quad(Vector3(s * 0.72, 1.2, -0.7), Vector3(0, sag.y, -0.7), Vector3(0, sag.y, 1.25), Vector3(s * 0.72, 1.2, 1.25), Vector3(-s * 0.1, 1, 0).normalized(), _g(SOOT.lerp(RUST, 0.4), MeshBuilder.METAL))
	for x: float in [-0.82, 0.82]:
		for z: float in [-1.35, 1.35]:
			mb.box(Vector3(x, 0.22, z), Vector3(0.12, 0.42, 0.42), _g(Color(0.35, 0.3, 0.27), MeshBuilder.METAL))
	mb.xform = saved
	Kit._col(out, p + Vector3(0, 0.65, 0), Vector3(1.8, 1.3, 4.3), yaw)


## A beat-up parked car: country_kit's car in tired paint, often with a
## primer hood.
static func _beater(mb, out: Array, p: Vector3, yaw: float, rng: RandomNumberGenerator) -> void:
	var paint: Color = (Kit._pick(CAR_PAINTS, rng) as Color).lerp(Color(0.5, 0.5, 0.48), 0.2)
	Kit._car(mb, out, p, yaw, paint)
	if rng.randf() < 0.5:
		var saved := _push(mb, p, yaw)
		mb.box(Vector3(0, 0.93, -1.5), Vector3(1.7, 0.01, 1.1), _g(PRIMER, MeshBuilder.METAL))
		mb.xform = saved


## A bare dead tree with a few branches.
static func _dead_tree(mb, out: Array, p: Vector3, h: float, rng: RandomNumberGenerator, color := Color(0.3, 0.26, 0.22)) -> void:
	var top := p + Vector3(0, h * 0.55, 0)
	mb.limb(p, top, 0.22, 0.15, color, 5, false)
	for i in 4:
		var a := TAU * i / 4.0 + rng.randf_range(-0.5, 0.5)
		var e := top + Vector3(cos(a) * h * 0.22, h * rng.randf_range(0.18, 0.4), sin(a) * h * 0.22)
		mb.limb(top, e, 0.12, 0.05, color, 4, false)
		mb.limb(e, e + Vector3(cos(a + 0.7) * h * 0.1, h * 0.1, sin(a + 0.7) * h * 0.1), 0.05, 0.02, color, 3, false)
	out.append([p + Vector3(0, 1.0, 0), Vector3(0.5, 2.0, 0.5)])


## A bare palm trunk, maybe a skirt of dead brown fronds or a snapped top;
## stays within `reach` of p.
static func _dead_palm(mb, out: Array, p: Vector3, reach: float, rng: RandomNumberGenerator) -> void:
	var h := rng.randf_range(8.0, 12.0)
	var lean_r := reach * rng.randf_range(0.0, 0.2)
	var a0 := rng.randf() * TAU
	var lean := Vector3(cos(a0), 0, sin(a0)) * lean_r
	var trunk := _g(Color(0.5, 0.45, 0.38), MeshBuilder.SIDING)
	var snapped := rng.randf() < 0.35
	var top_h := h * (rng.randf_range(0.55, 0.75) if snapped else 1.0)
	var prev := p
	for i in 3:
		var t := (i + 1) / 3.0
		var q := p + Vector3(0, top_h * t, 0) + lean * t * t
		mb.limb(prev, q, lerpf(0.26, 0.17, i / 3.0), lerpf(0.26, 0.17, t), trunk, 6, false)
		prev = q
	if snapped:
		mb.cylinder(prev, 0.17, 0.05, Color(0.62, 0.52, 0.38), 6)
		for k in 3:
			var sa := TAU * k / 3.0 + rng.randf_range(-0.4, 0.4)
			var tip := prev + Vector3(cos(sa) * 0.12, rng.randf_range(0.5, 1.0), sin(sa) * 0.12)
			mb.limb(prev + Vector3(cos(sa) * 0.1, 0, sin(sa) * 0.1), tip, 0.07, 0.015, trunk, 4, false)
		for k in 2:
			Props._frond(mb, prev - Vector3(0, 0.25 + k * 0.3, 0), rng.randf() * TAU, 0.9, -rng.randf_range(0.8, 1.1), Color(0.42, 0.33, 0.22))
	else:
		var brown := Color(0.48, 0.38, 0.26)
		mb.clump(prev + Vector3(0, 0.05, 0), Vector3(0.3, 0.3, 0.3), Color(0.4, 0.34, 0.26), rng.randi(), 5, 3)
		var length := clampf((reach - lean_r - 0.45) / 0.45, 0.6, 1.8)
		for i in 7:
			var a := TAU * i / 7.0 + rng.randf_range(-0.2, 0.2)
			Props._frond(mb, prev - Vector3(0, 0.1, 0), a, length, -rng.randf_range(0.9, 1.3), brown.darkened(rng.randf() * 0.2))
	out.append([p + Vector3(0, 1.5, 0), Vector3(0.5, 3.0, 0.5)])


## A scrap handler: a pedestal mast with an operator cab on top and a boom
## reaching `reach` toward -Z (before yaw) to a grapple claw that holds a
## crushed car. p is the mast foot.
static func _claw_crane(mb, out: Array, p: Vector3, yaw: float, h: float, reach: float, rng: RandomNumberGenerator) -> void:
	var saved := _push(mb, p, yaw)
	var paint := _g(Color(0.85, 0.62, 0.15).lerp(RUST, rng.randf_range(0.15, 0.4)), MeshBuilder.GLOSS)
	var dark := Color(0.15, 0.15, 0.16)
	mb.box(Vector3(0, 0.4, 0), Vector3(3.0, 0.8, 3.0), _g(CONCRETE, MeshBuilder.CONCRETE))
	mb.box(Vector3(0, 0.8 + (h - 0.8) * 0.5, 0), Vector3(1.1, h - 0.8, 1.1), paint)
	mb.box(Vector3(0, h + 1.0, 0.3), Vector3(2.2, 2.0, 2.6), paint)
	mb.box(Vector3(0, h + 1.25, -1.02), Vector3(1.9, 1.1, 0.06), _g(Color(0.2, 0.25, 0.3), MeshBuilder.GLASS))
	mb.box(Vector3(0, h + 0.75, 2.1), Vector3(2.2, 1.3, 1.2), dark)
	var b0 := Vector3(0.75, h + 0.6, -0.8)
	var b1 := Vector3(0.75, h + reach * 0.35, -reach * 0.62)
	var b2 := Vector3(0.75, h * 0.62, -reach)
	Kit._beam(mb, b0, b1, 0.55, paint)
	Kit._beam(mb, b1, b2, 0.4, paint)
	var hub := b2 - Vector3(0, 0.45, 0)
	mb.box(hub, Vector3(0.6, 0.5, 0.6), dark)
	for i in 4:
		var a := TAU * i / 4.0 + PI * 0.25
		var dv := Vector3(cos(a), 0, sin(a))
		Kit._beam(mb, hub, hub + dv * 0.8 - Vector3(0, 0.5, 0), 0.14, dark)
		Kit._beam(mb, hub + dv * 0.8 - Vector3(0, 0.5, 0), hub + dv * 0.45 - Vector3(0, 1.3, 0), 0.12, dark)
	mb.box(hub - Vector3(0, 1.45, 0), Vector3(1.9, 0.55, 3.6), _g(Kit._pick(CAR_PAINTS, rng), MeshBuilder.METAL))
	mb.xform = saved
	out.append([p + Vector3(0, 1.5, 0), Vector3(3.0, 3.0, 3.0)])


## A stack of `n` crushed cars at p (each 1.9 x 0.55 x 3.6, long along Z),
## a little askew. Returns the stack height.
static func _cube_stack(mb, p: Vector3, n: int, rng: RandomNumberGenerator) -> float:
	for k in n:
		var c: Color = (Kit._pick(CAR_PAINTS, rng) as Color).lerp(RUST, rng.randf_range(0.1, 0.5))
		var off := Vector3(rng.randf_range(-0.1, 0.1), k * 0.56 + 0.28, rng.randf_range(-0.15, 0.15))
		var yaw := rng.randf_range(-0.06, 0.06)
		_rbox(mb, p + off, Vector3(1.9, 0.55, 3.6), yaw, _g(c, MeshBuilder.METAL))
		if k == n - 1 or rng.randf() < 0.5:
			_rbox(mb, p + off + Vector3(0, 0.285, rng.randf_range(-0.6, 0.6)), Vector3(1.5, 0.01, 0.7), yaw, Color(0.12, 0.13, 0.14))
	return n * 0.56


# --- Shady commercial ---------------------------------------------------------------

## A two-storey L or U motel round a cracked car park, after the motels on
## LA's and Oakland's arterials: rooms with doors, curtained windows and
## wall AC units under outdoor walkways, an office with a barred night
## window, an ice-machine alcove, faded stalls, beaters, a drained pool
## behind a chain-link fence and a tall pole sign with a neon figure.
static func motel(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var hw := w * 0.5
	var hd := d * 0.5
	const FH := 2.9
	var floors := 2 if d >= 20.0 else 1
	var H := floors * FH + 0.3
	var body: Color = Kit._pick(STUCCOS, rng)
	var wall := _g(body, MeshBuilder.CONCRETE)
	var door_c: Color = Kit._pick(DOORS, rng)
	var band: Color = Kit._pick(DOORS, rng)
	var field: Color = Kit._pick(SIGN_FIELDS, rng)
	var wd := clampf(d * 0.26, 6.5, 9.0)
	const WALK := 1.8
	var u_shape := w >= 34.0 and rng.randf() < 0.45
	var x0 := -hw + 0.6
	var x1 := hw - 0.6
	var zb1 := hd - 0.6
	var zb0 := zb1 - wd
	var zl0 := -hd + clampf(d * 0.22, 5.5, 8.0)
	var lx := x0 + wd
	var rx := x1 - wd if u_shape else x1
	Kit._pad(mb, -hw, hw, -hd, hd, _g(ASPHALT, MeshBuilder.ASPHALT))
	# Wings and their roofs.
	Kit._solid(mb, out, Vector3((x0 + x1) * 0.5, H * 0.5, (zb0 + zb1) * 0.5), Vector3(x1 - x0, H, wd), wall)
	Kit._solid(mb, out, Vector3(x0 + wd * 0.5, H * 0.5, (zl0 + zb0) * 0.5), Vector3(wd, H, zb0 - zl0), wall)
	_shabby_roof(mb, x0, x1, zb0, zb1, H, body.darkened(0.2), rng, 0.5)
	_shabby_roof(mb, x0, lx, zl0, zb0, H, body.darkened(0.2), rng, 0.5)
	mb.box(Vector3((lx + rx) * 0.5, H - 0.35, zb0 - 0.15), Vector3(rx - lx, 0.7, 0.3), band)
	mb.box(Vector3(lx + 0.15, H - 0.35, (zl0 + zb0) * 0.5), Vector3(0.3, 0.7, zb0 - zl0), band)
	if u_shape:
		Kit._solid(mb, out, Vector3(x1 - wd * 0.5, H * 0.5, (zl0 + zb0) * 0.5), Vector3(wd, H, zb0 - zl0), wall)
		_shabby_roof(mb, rx, x1, zl0, zb0, H, body.darkened(0.2), rng, 0.5)
		mb.box(Vector3(rx - 0.15, H - 0.35, (zl0 + zb0) * 0.5), Vector3(0.3, 0.7, zb0 - zl0), band)
	# Rooms on the courtyard faces, an ice-machine alcove in the first one.
	var xs := (rx - WALK - 0.2) if u_shape else (x1 - 0.6)
	var bx0 := lx + WALK + 0.3
	var bx1 := (rx - WALK - 0.3) if u_shape else (x1 - 4.2)
	var nb := maxi(1, int((bx1 - bx0) / 3.8))
	for f in floors:
		for i in nb:
			var x := bx0 + (bx1 - bx0) * (i + 0.5) / nb
			_room(mb, Vector3(x, f * FH, zb0), Vector3.RIGHT, Vector3.FORWARD, door_c, rng, f == 0 and i == nb - 1)
	var sz0 := zl0 + 0.4
	var sz1 := zb0 - WALK - 0.3
	var ns := maxi(1, int((sz1 - sz0) / 3.8))
	for f in floors:
		for i in ns:
			var z := sz0 + (sz1 - sz0) * (i + 0.5) / ns
			_room(mb, Vector3(lx, f * FH, z), Vector3.BACK, Vector3.RIGHT, door_c, rng)
			if u_shape:
				_room(mb, Vector3(rx, f * FH, z), Vector3.FORWARD, Vector3.LEFT, door_c, rng)
	# Walks along the rooms, outdoor walkways above with a stair.
	var deck := _g(CONCRETE, MeshBuilder.CONCRETE)
	var rail := _g(Kit._pick(RAILS, rng), MeshBuilder.GLOSS)
	mb.box(Vector3((lx + rx) * 0.5, 0.08, zb0 - WALK * 0.5), Vector3(rx - lx, 0.16, WALK), deck)
	mb.box(Vector3(lx + WALK * 0.5, 0.08, (zl0 + zb0 - WALK) * 0.5), Vector3(WALK, 0.16, zb0 - WALK - zl0), deck)
	if u_shape:
		mb.box(Vector3(rx - WALK * 0.5, 0.08, (zl0 + zb0 - WALK) * 0.5), Vector3(WALK, 0.16, zb0 - WALK - zl0), deck)
	if floors > 1:
		_walkway(mb, Vector3(lx, 0, zb0 - WALK), Vector3(rx, 0, zb0 - WALK), Vector3.FORWARD, WALK, FH, rail, deck)
		_walkway(mb, Vector3(lx + WALK, 0, zl0), Vector3(lx + WALK, 0, zb0 - WALK), Vector3.RIGHT, WALK, FH, rail, deck)
		if u_shape:
			_walkway(mb, Vector3(rx - WALK, 0, zl0), Vector3(rx - WALK, 0, zb0 - WALK), Vector3.LEFT, WALK, FH, rail, deck)
		var st := Vector3(xs, 0, zb0 - WALK - 0.6)
		for k in 8:
			mb.box(Vector3(st.x - 3.2 + (k + 0.5) * 0.4, (k + 1) * FH / 8.0 - 0.05, st.z), Vector3(0.4, 0.06, 1.1), deck)
		Kit._beam(mb, Vector3(st.x - 3.2, 0.1, st.z - 0.55), Vector3(st.x, FH, st.z - 0.55), 0.12, rail)
		Kit._col(out, Vector3(st.x - 1.6, 0.7, st.z), Vector3(3.2, 1.4, 1.2))
	# The office at the street end of the left wing.
	var od := clampf(zl0 + hd - 1.2, 2.8, 5.0)
	var oz0 := zl0 - od
	const OH := 3.6
	Kit._solid(mb, out, Vector3(x0 + wd * 0.5, OH * 0.5, (oz0 + zl0) * 0.5), Vector3(wd, OH, od), _g(body.darkened(0.08), MeshBuilder.CONCRETE))
	_shabby_roof(mb, x0, lx, oz0, zl0, OH, body.darkened(0.25), rng, 0.4)
	var of := Vector3(x0 + wd * 0.5, 0, oz0)
	_win(mb, of + Vector3(-wd * 0.16, 1.5, 0), Vector3.RIGHT, Vector3.FORWARD, Vector2(wd * 0.42, 1.5), 1, rng, 1.0)
	_panel(mb, of + Vector3(wd * 0.28, 1.05, -0.03), Vector3.RIGHT, Vector3.FORWARD, Vector2(1.0, 2.1), _g(Color(0.35, 0.37, 0.4), MeshBuilder.METAL))
	_sign_band(mb, of + Vector3(0, OH - 0.45, 0), Vector3.RIGHT, Vector3.FORWARD, wd - 1.0, 0.6, field, rng, false)
	_dumpster(mb, out, Vector3(lx + 1.3, 0, oz0 + 1.2), PI * 0.5, rng)
	_bags(mb, Vector3(lx + 1.3, 0, oz0 + 2.6), 2, rng, 0.3)
	# The car park: cracked, stained, faded stalls and a few beaters.
	var pz := zb0 - WALK
	_cracks(mb, -hw, hw, -hd, pz, int(w * d / 70.0), rng)
	_stains(mb, lx + WALK, x1, -hd + 0.5, pz, int(w * d / 110.0), rng)
	var px0 := lx + WALK + 0.5
	var px1 := (xs - 3.8) if floors > 1 else ((rx - WALK - 0.5) if u_shape else (x1 - 0.5))
	var bays := maxi(0, int((px1 - px0) / 3.0))
	_stalls(mb, px0, pz - 0.1, bays, 3.0, 5.2, -1.0, rng)
	for i in bays:
		if rng.randf() < 0.32:
			_beater(mb, out, Vector3(px0 + 1.5 + 3.0 * i, 0, pz - 2.7), PI, rng)
	var sx := lx + WALK + 0.1
	var nsb := maxi(0, int((sz1 - sz0) / 3.0))
	for i in nsb + 1:
		_strip(mb, Vector2(sx, sz0 + 3.0 * i), Vector2(sx + 5.0, sz0 + 3.0 * i), 0.11, 0.06, Color(0.78, 0.77, 0.7))
	if nsb > 0 and rng.randf() < 0.6:
		_beater(mb, out, Vector3(sx + 2.7, 0, sz0 + 1.5 + 3.0 * (rng.randi() % nsb)), PI * 0.5, rng)
	# A drained pool, fenced, in the front corner of an L.
	var pool := false
	if not u_shape and w >= 30.0:
		var qx0 := hw - 12.0
		var qx1 := hw - 1.2
		var qz0 := -hd + 2.6
		var qz1 := qz0 + 7.5
		if qz1 < pz - 6.4 and qx0 > lx + WALK + 6.0:
			pool = true
			Kit._pad(mb, qx0, qx1, qz0, qz1, _g(Color(0.78, 0.76, 0.7), MeshBuilder.PAVING), 0.05)
			mb.box(Vector3((qx0 + qx1) * 0.5, 0.07, (qz0 + qz1) * 0.5), Vector3(qx1 - qx0 - 2.6, 0.02, qz1 - qz0 - 2.6), Color(0.32, 0.42, 0.38))
			_blot(mb, qx1 - 3.0, (qz0 + qz1) * 0.5, 1.4, 1.0, 0.09, Color(0.2, 0.3, 0.2))
			_cracks(mb, qx0 + 1.3, qx1 - 1.3, qz0 + 1.3, qz1 - 1.3, 3, rng, 0.09)
			_bags(mb, Vector3(qx0 + 3.0, 0.08, qz0 + 2.4), 2, rng, 0.3)
			var gaps := [[qx0 + 1.0, qx0 + 2.2]]
			_chainlink_x(mb, out, qx0, qx1, qz0, 1.5, gaps, rng)
			_chainlink_x(mb, out, qx0, qx1, qz1, 1.5, [], rng)
			_chainlink(mb, out, Vector3(qx0, 0, qz0), Vector3(qx0, 0, qz1), 1.5, rng, false, false, 2)
			_chainlink(mb, out, Vector3(qx1, 0, qz0), Vector3(qx1, 0, qz1), 1.5, rng, false, false, 2)
	if not pool:
		_cart(mb, out, Vector3(hw - 3.0, 0, -hd + 3.0), rng.randf_range(0, TAU), rng)
		_mattress(mb, Vector3(hw - 4.5, 0, -hd + 5.5), rng.randf_range(-0.5, 0.5), rng)
	# Weeds along the edges and the tall pole sign by the street.
	_weeds(mb, -hw, hw, -hd, -hd + 0.8, int(w / 4.0), rng)
	_weeds(mb, hw - 0.8, hw, -hd, pz, int(d / 5.0), rng)
	_pole_sign(mb, out, Vector3(hw - 2.6, 0, -hd + 0.9), clampf(w * 0.22, 7.0, 10.0), Vector2(4.4, 2.4), field, Kit._pick(NEONS, rng), rng.randi() % 4, rng)


## One motel room front on a wall facing n: base is the middle of the
## room's floor line on the wall, u along the wall. A door, a curtained
## window, a wall AC unit; some doors boarded, a few windows broken. `ice`
## puts the ice-machine and vending alcove there instead.
static func _room(mb, base: Vector3, u: Vector3, n: Vector3, door_c: Color, rng: RandomNumberGenerator, ice := false) -> void:
	if ice:
		_panel(mb, base + n * 0.02 + Vector3(0, 1.25, 0), u, n, Vector2(2.4, 2.5), RECESS)
		mb.box(base + n * 0.42 - u * 0.55 + Vector3(0, 0.85, 0), u.abs() * 1.0 + Vector3(0, 1.7, 0) + n.abs() * 0.8, _g(Color(0.86, 0.87, 0.86), MeshBuilder.GLOSS))
		mb.box(base + n * 0.42 + u * 0.6 + Vector3(0, 0.95, 0), u.abs() * 0.9 + Vector3(0, 1.9, 0) + n.abs() * 0.8, _g(Color(0.2, 0.35, 0.6), MeshBuilder.GLOSS))
		_panel(mb, base + n * 0.83 + u * 0.6 + Vector3(0, 1.3, 0), u, n, Vector2(0.6, 0.8), _g(Color(0.8, 0.9, 1.0), MeshBuilder.GLOW_NEON))
		return
	var dp := base - u * 0.9
	if rng.randf() < 0.12:
		_win(mb, dp + Vector3(0, 1.08, 0), u, n, Vector2(0.95, 1.95), 2, rng)
	else:
		_panel(mb, dp + n * 0.03 + Vector3(0, 1.05, 0), u, n, Vector2(0.9, 2.1), door_c.darkened(rng.randf() * 0.25))
	var wp := base + u * 0.75 + Vector3(0, 1.55, 0)
	_win(mb, wp, u, n, Vector2(1.4, 1.1), _pick_state([0.68, 0.0, 0.12, 0.08, 0.12], rng), rng, 0.35)
	if rng.randf() < 0.7:
		mb.box(wp + n * 0.18 - Vector3(0, 0.85, 0), u.abs() * 0.7 + Vector3(0, 0.45, 0) + n.abs() * 0.36, _g(Color(0.78, 0.78, 0.74).darkened(rng.randf() * 0.2), MeshBuilder.METAL))


## An outdoor walkway at height y whose outer edge runs from a to b on the
## ground (the wall lies `depth` back, against n): a slab, a top rail,
## balusters facing n and posts down to the ground.
static func _walkway(mb, a: Vector3, b: Vector3, n: Vector3, depth: float, y: float, rail: Color, deck: Color) -> void:
	var length := a.distance_to(b)
	if length < 0.5:
		return
	var u := (b - a) / length
	var mid := (a + b) * 0.5
	mb.box(mid - n * depth * 0.5 + Vector3(0, y, 0), u.abs() * length + Vector3(0, 0.2, 0) + n.abs() * depth, deck)
	mb.box(mid + n * 0.04 + Vector3(0, y + 1.0, 0), u.abs() * length + Vector3(0, 0.07, 0) + n.abs() * 0.07, rail)
	var k := maxi(2, int(length / 0.45))
	for i in k + 1:
		var s := -length * 0.5 + length * i / k
		_stroke(mb, mid + n * 0.05 + Vector3(0, y + 0.1, 0), u, n, Vector2(s, 0.0), Vector2(s, 0.9), 0.04, rail)
	var pk := maxi(1, int(length / 3.8))
	for i in pk + 1:
		var s := -length * 0.5 + 0.1 + (length - 0.2) * i / pk
		mb.box(mid + u * s - n * 0.1 + Vector3(0, y * 0.5, 0), Vector3(0.16, y, 0.16), rail)


## A squat liquor store behind a few parking bays: a lit sign band, barred
## display windows plastered with poster colour, a gated door, an ice
## chest, a mural tag on the side, sometimes a pole sign or a rooftop
## billboard (abstract colour, no words).
static func liquor_store(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var hw := w * 0.5
	var hd := d * 0.5
	const H := 4.4
	var bw := clampf(w - 2.0, 8.0, 22.0)
	var bd := clampf(d * 0.5, 6.5, 12.0)
	var z1 := hd - 0.8
	var fz := z1 - bd
	var body: Color = Kit._pick(STUCCOS, rng)
	var wall := _g(body, MeshBuilder.CONCRETE)
	var field: Color = Kit._pick(SIGN_FIELDS, rng)
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	Kit._pad(mb, -hw, hw, -hd, hd, _g(ASPHALT, MeshBuilder.ASPHALT))
	Kit._pad(mb, -bw * 0.5 - 0.6, bw * 0.5 + 0.6, fz - 1.6, fz, _g(SIDEWALK, MeshBuilder.CONCRETE), 0.08)
	Kit._solid(mb, out, Vector3(0, H * 0.5, fz + bd * 0.5), Vector3(bw, H, bd), wall)
	mb.box(Vector3(0, 0.5, fz - 0.03), Vector3(bw, 1.0, 0.06), _g(Kit._pick(DOORS, rng), MeshBuilder.CONCRETE))
	_shabby_roof(mb, -bw * 0.5, bw * 0.5, fz, z1, H, body.darkened(0.2), rng)
	_sign_band(mb, Vector3(0, H - 0.7, fz), Vector3.RIGHT, Vector3.FORWARD, bw - 1.2, 1.1, field, rng, rng.randf() < 0.65)
	# Gated door and barred display windows with posters.
	var dx := side * bw * 0.2
	_panel(mb, Vector3(dx, 1.2, fz - 0.03), Vector3.RIGHT, Vector3.FORWARD, Vector2(1.8, 2.3), _g(SHOP_GLASS, MeshBuilder.GLOW_WINDOW))
	_bars(mb, Vector3(dx, 1.2, fz), Vector3.RIGHT, Vector3.FORWARD, 1.9, 2.35)
	var spans := [[-bw * 0.5 + 0.6, dx - 1.3], [dx + 1.3, bw * 0.5 - 0.6]]
	for sp in spans:
		var n := maxi(0, int((sp[1] - sp[0]) / 2.8))
		for i in n:
			var wx: float = lerpf(sp[0], sp[1], (i + 0.5) / n)
			var c := Vector3(wx, 1.85, fz)
			_panel(mb, c + Vector3(0, 0, -0.03), Vector3.RIGHT, Vector3.FORWARD, Vector2(2.4, 1.6), _g(Color(0.5, 0.45, 0.35), MeshBuilder.GLOW_WINDOW))
			for k in rng.randi_range(1, 3):
				var pc: Color = (Kit._pick(INKS + SIGN_FIELDS, rng) as Color).lerp(Color(0.9, 0.9, 0.85), 0.3)
				_panel(mb, c + Vector3(rng.randf_range(-0.8, 0.8), rng.randf_range(-0.3, 0.3), -0.05), Vector3.RIGHT, Vector3.FORWARD, Vector2(0.55, 0.75), pc)
			_bars(mb, c, Vector3.RIGHT, Vector3.FORWARD, 2.5, 1.7)
	# Ice chest by the door, a mural tag on the side wall facing the side street.
	var ic := Vector3(dx - side * 1.7, 0, fz - 0.55)
	mb.box(ic + Vector3(0, 0.62, 0), Vector3(1.3, 1.05, 0.7), _g(Color(0.9, 0.92, 0.94), MeshBuilder.GLOSS))
	mb.box(ic + Vector3(0, 0.75, -0.36), Vector3(1.2, 0.25, 0.02), _g(Color(0.2, 0.45, 0.85), MeshBuilder.GLOSS))
	var sxw := side * bw * 0.5
	_tag(mb, Vector3(sxw, 2.3, fz + bd * 0.5), Vector3(0, 0, side), Vector3(side, 0, 0), minf(bd - 2.0, 6.0), 1.7, rng)
	_tag(mb, Vector3(-sxw, 1.9, fz + bd * 0.4), Vector3(0, 0, -side), Vector3(-side, 0, 0), minf(bd - 3.0, 3.5), 1.1, rng)
	# Parking: faded stalls, wheel stops, a beater or two.
	var bays := maxi(1, int((bw - 1.0) / 2.8))
	var sx0 := -bays * 1.4
	var kerb := fz - 1.6
	var bay_d := minf(5.0, kerb + hd - 0.3)
	_stalls(mb, sx0, kerb, bays, 2.8, bay_d, -1.0, rng)
	for i in bays:
		var x := sx0 + 1.4 + 2.8 * i
		mb.box(Vector3(x, 0.09, kerb - 0.7), Vector3(1.5, 0.14, 0.22), _g(CONCRETE, MeshBuilder.CONCRETE))
		if rng.randf() < 0.3 and bay_d >= 4.4:
			_beater(mb, out, Vector3(x, 0, kerb - 2.5), PI, rng)
	_cracks(mb, -hw, hw, -hd, kerb, int(w * (kerb + hd) / 40.0), rng)
	_stains(mb, sx0, -sx0, -hd + 0.4, kerb, bays + 1, rng)
	# Corners: a dumpster and bags on one, a pole sign or a cart on the other.
	var cx := side * (hw - 1.0)
	_dumpster(mb, out, Vector3(cx, 0, kerb - 1.6), PI * 0.5, rng)
	_bags(mb, Vector3(cx, 0, kerb - 3.3), 2, rng, 0.25)
	if rng.randf() < 0.55:
		_pole_sign(mb, out, Vector3(-side * (hw - 2.0), 0, -hd + 0.8), 5.8, Vector2(3.4, 1.8), field, Kit._pick(NEONS, rng), rng.randi() % 4, rng)
	else:
		_cart(mb, out, Vector3(-side * (hw - 1.0), 0, -hd + 1.5), rng.randf_range(0, TAU), rng)
		Props.trash_can(mb, out, Vector3(-side * (hw - 1.0), 0, kerb - 0.8))
	_weeds(mb, -hw, hw, -hd, -hd + 0.6, int(w / 4.0), rng)
	# A rooftop billboard now and then: a blank colour advert, no words.
	if rng.randf() < 0.4 and bw >= 10.0:
		var bbw := minf(bw - 3.0, 7.0)
		var bz := z1 - 1.6
		var steel := _g(Color(0.35, 0.36, 0.37), MeshBuilder.METAL)
		for s: float in [-1.0, 1.0]:
			mb.box(Vector3(s * bbw * 0.3, H + 1.3, bz), Vector3(0.25, 2.6, 0.25), steel)
		var bc := Vector3(0, H + 3.8, bz)
		mb.box(bc, Vector3(bbw, 2.8, 0.3), Color(0.2, 0.2, 0.21))
		var ad: Color = Kit._pick(SIGN_FIELDS, rng)
		_panel(mb, bc + Vector3(0, 0, -0.16), Vector3.RIGHT, Vector3.FORWARD, Vector2(bbw - 0.3, 2.5), ad.lerp(Color(0.8, 0.78, 0.72), 0.3))
		_ellipse(mb, bc + Vector3(-bbw * 0.25, 0, -0.18), Vector3.RIGHT, Vector3.FORWARD, 0.9, 0.9, (Kit._pick(INKS, rng) as Color).darkened(0.1), 10)
		_glyphs(mb, bc + Vector3(bbw * 0.15, 0.1, -0.18), Vector3.RIGHT, Vector3.FORWARD, bbw * 0.45, 0.8, ad.darkened(0.7), rng)
		_tag(mb, bc + Vector3(bbw * 0.1, -0.55, -0.2), Vector3.RIGHT, Vector3.FORWARD, bbw * 0.4, 0.7, rng)


## A narrow two-storey pawn shop on the sidewalk: roll-down shutters over
## barred display windows, a bright sign band, the hanging three-ball
## trade sign, barred and boarded windows upstairs, a dumpster out back.
static func pawn_shop(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var hw := w * 0.5
	var hd := d * 0.5
	const FH := 3.6
	var H := FH * 2.0 + 0.4
	var bw := w - 0.4
	var fz := -hd + 1.4
	var bd := clampf(d * 0.7, 7.0, d - 3.0)
	var z1 := fz + bd
	var brick := rng.randf() < 0.55
	var body: Color = Kit._pick(BRICKS, rng) if brick else Kit._pick(STUCCOS, rng)
	var wall := _g(body, MeshBuilder.BRICK if brick else MeshBuilder.CONCRETE)
	var field: Color = Kit._pick(SIGN_FIELDS, rng)
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	Kit._pad(mb, -hw, hw, -hd, fz, _g(SIDEWALK, MeshBuilder.CONCRETE), 0.06)
	_cracks(mb, -hw, hw, -hd, fz, 3, rng, 0.08)
	Kit._pad(mb, -hw, hw, z1, hd, _g(ASPHALT, MeshBuilder.ASPHALT))
	Kit._solid(mb, out, Vector3(0, H * 0.5, fz + bd * 0.5), Vector3(bw, H, bd), wall)
	# A false-front parapet and a worn roof.
	mb.box(Vector3(0, H + 0.5, fz + 0.2), Vector3(bw, 1.0, 0.4), wall)
	mb.box(Vector3(0, H + 1.06, fz + 0.2), Vector3(bw + 0.1, 0.12, 0.55), body.darkened(0.3))
	_shabby_roof(mb, -bw * 0.5, bw * 0.5, fz + 0.4, z1, H, body.darkened(0.25), rng, 0.5)
	# Ground floor: a gated door at one side, display windows behind roll-down shutters.
	var door_x := side * (bw * 0.5 - 1.2)
	_panel(mb, Vector3(door_x, 1.2, fz - 0.03), Vector3.RIGHT, Vector3.FORWARD, Vector2(1.2, 2.4), _g(SHOP_GLASS, MeshBuilder.GLOW_WINDOW))
	_bars(mb, Vector3(door_x, 1.2, fz), Vector3.RIGHT, Vector3.FORWARD, 1.25, 2.4)
	_shutter(mb, Vector3(door_x, 0, fz), Vector3.RIGHT, Vector3.FORWARD, 1.4, 2.5, 1.0, rng)
	var sp0 := minf(-side * (bw * 0.5 - 0.4), door_x + side * -0.9)
	var sp1 := maxf(-side * (bw * 0.5 - 0.4), door_x + side * -0.9)
	var nwin := maxi(1, int((sp1 - sp0) / 3.2))
	var ww := (sp1 - sp0) / nwin - 0.4
	for i in nwin:
		var x := lerpf(sp0, sp1, (i + 0.5) / nwin)
		var roll := rng.randf()
		var open := 1.0 if roll < 0.5 else (0.0 if roll < 0.8 else rng.randf_range(0.3, 0.6))
		if open > 0.0:
			var c := Vector3(x, 0.4 + 1.2, fz)
			_panel(mb, c + Vector3(0, 0, -0.025), Vector3.RIGHT, Vector3.FORWARD, Vector2(ww, 2.3), _g(Color(0.55, 0.48, 0.32), MeshBuilder.GLOW_WINDOW))
			_bars(mb, c, Vector3.RIGHT, Vector3.FORWARD, ww, 2.35)
		_shutter(mb, Vector3(x, 0.4, fz), Vector3.RIGHT, Vector3.FORWARD, ww, 2.4, open, rng)
	_sign_band(mb, Vector3(0, FH + 0.2, fz), Vector3.RIGHT, Vector3.FORWARD, bw - 0.8, 0.9, field, rng, true)
	# The hanging three-ball trade sign on an iron bracket.
	var iron := _g(IRON, MeshBuilder.GLOSS)
	var gold := _g(Color(0.9, 0.72, 0.25), MeshBuilder.GLOSS)
	var bx := -side * (bw * 0.5 - 0.7)
	var arm := Vector3(bx, FH + 1.6, fz - 1.1)
	Kit._beam(mb, Vector3(bx, FH + 1.6, fz), arm, 0.1, iron)
	Kit._beam(mb, Vector3(bx, FH + 1.0, fz), arm + Vector3(0, 0, 0.5), 0.06, iron)
	var balls: Array[Vector3] = [arm + Vector3(0, -0.55, 0), arm + Vector3(-0.3, -1.0, 0), arm + Vector3(0.3, -1.0, 0)]
	for bp in balls:
		Kit._beam(mb, arm, bp, 0.03, iron)
		mb.ball(bp - Vector3(0, 0.2, 0), Vector3(0.22, 0.22, 0.22), gold, 6, 3)
	# Upstairs: barred, boarded and curtained windows, an AC unit.
	_face_windows(mb, Vector2(-bw * 0.5, fz), Vector2(bw * 0.5, fz), Vector3.FORWARD, 1, FH, 2.8, Vector2(1.3, 1.5), rng, FH + 1.9, 0.5, [0.4, 0.3, 0.15, 0.05, 0.1], 0.3)
	# Tags on the side walls, a dumpster and junk out back.
	for s: float in [-1.0, 1.0]:
		if rng.randf() < 0.75:
			_tag(mb, Vector3(s * bw * 0.5, 1.9, fz + rng.randf_range(2.5, bd - 2.5)), Vector3(0, 0, s), Vector3(s, 0, 0), minf(bd * 0.4, 4.0), 1.2, rng)
	if hd - z1 >= 1.6:
		_dumpster(mb, out, Vector3(-side * (hw - 1.3), 0, (z1 + hd) * 0.5), 0.0, rng)
		_bags(mb, Vector3(side * (hw - 1.4), 0, (z1 + hd) * 0.5), 3, rng, 0.35)
	_weeds(mb, -hw, hw, z1, hd, 3, rng)


## A corner check casher: a single-storey box tight on the corner, a bright
## sign band wrapping round to the side street, barred windows with lit
## posters, a gated glass door, steel bollards, a wall machine with a lit
## screen, a neon figure in the window, two bays behind a barbed fence.
static func check_cashing(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var hw := w * 0.5
	var hd := d * 0.5
	const H := 4.6
	var bw := clampf(w * 0.78, 8.0, w - 1.0)
	var bd := clampf(d * 0.6, 6.5, d - 3.5)
	var x1 := hw - 0.5
	var x0 := x1 - bw
	var fz := -hd + 1.0
	var z1 := fz + bd
	var cx := (x0 + x1) * 0.5
	var body: Color = (Kit._pick(STUCCOS, rng) as Color).lightened(0.05)
	var wall := _g(body, MeshBuilder.CONCRETE)
	var field: Color = Kit._pick([Color(0.98, 0.85, 0.2), Color(0.2, 0.75, 0.4), Color(1.0, 0.55, 0.15), Color(0.95, 0.95, 0.92)], rng)
	var stripe: Color = Kit._pick([Color(0.15, 0.45, 0.25), Color(0.75, 0.15, 0.15), Color(0.15, 0.3, 0.6)], rng)
	Kit._pad(mb, -hw, hw, -hd, hd, _g(ASPHALT, MeshBuilder.ASPHALT))
	Kit._pad(mb, -hw, hw, -hd, fz, _g(SIDEWALK, MeshBuilder.CONCRETE), 0.06)
	Kit._pad(mb, x1, hw, fz, z1, _g(SIDEWALK, MeshBuilder.CONCRETE), 0.06)
	Kit._solid(mb, out, Vector3(cx, H * 0.5, (fz + z1) * 0.5), Vector3(bw, H, bd), wall)
	_shabby_roof(mb, x0, x1, fz, z1, H, body.darkened(0.2), rng, 0.5)
	# The bright band wraps the corner, a painted stripe under it.
	_sign_band(mb, Vector3(cx, H - 0.75, fz), Vector3.RIGHT, Vector3.FORWARD, bw - 0.3, 1.2, field, rng, true)
	_sign_band(mb, Vector3(x1, H - 0.75, (fz + z1) * 0.5), Vector3.BACK, Vector3.RIGHT, bd - 0.3, 1.2, field, rng, true)
	_panel(mb, Vector3(cx, H - 1.55, fz - 0.03), Vector3.RIGHT, Vector3.FORWARD, Vector2(bw, 0.3), stripe)
	_panel(mb, Vector3(x1 + 0.03, H - 1.55, (fz + z1) * 0.5), Vector3.BACK, Vector3.RIGHT, Vector2(bd, 0.3), stripe)
	# The corner door and barred windows with lit posters.
	var dx := x1 - 1.3
	_panel(mb, Vector3(dx, 1.2, fz - 0.03), Vector3.RIGHT, Vector3.FORWARD, Vector2(1.6, 2.4), _g(SHOP_GLASS, MeshBuilder.GLOW_WINDOW))
	_bars(mb, Vector3(dx, 1.2, fz), Vector3.RIGHT, Vector3.FORWARD, 1.65, 2.45)
	var nf := maxi(1, int((dx - 1.2 - x0 - 0.6) / 2.6))
	for i in nf:
		var c := Vector3(lerpf(x0 + 0.6, dx - 1.2, (i + 0.5) / nf), 1.75, fz)
		_panel(mb, c + Vector3(0, 0, -0.03), Vector3.RIGHT, Vector3.FORWARD, Vector2(2.1, 1.7), _g(Color(0.52, 0.5, 0.4), MeshBuilder.GLOW_WINDOW))
		_panel(mb, c + Vector3(rng.randf_range(-0.5, 0.5), 0.1, -0.05), Vector3.RIGHT, Vector3.FORWARD, Vector2(0.7, 0.9), _g(field.lerp(Color.WHITE, 0.3), MeshBuilder.GLOW_NEON))
		_bars(mb, c, Vector3.RIGHT, Vector3.FORWARD, 2.2, 1.8)
	if nf > 0:
		var nc := Vector3(lerpf(x0 + 0.6, dx - 1.2, 0.5 / nf), 2.2, fz - 0.07)
		_neon_shape(mb, nc, Vector3.RIGHT, Vector3.FORWARD, 0.8, 1 + rng.randi() % 2, _g(Kit._pick(NEONS, rng), MeshBuilder.GLOW_NEON))
	var ns := maxi(1, int((bd - 2.5) / 2.8))
	for i in ns:
		var c := Vector3(x1, 1.75, lerpf(fz + 1.0, z1 - 1.5, (i + 0.5) / ns))
		_win(mb, c, Vector3.BACK, Vector3.RIGHT, Vector2(1.8, 1.5), 1, rng, 0.8)
	# A wall machine with a lit screen on the side, bollards before the glass.
	var mz := z1 - 0.9
	mb.box(Vector3(x1 + 0.2, 1.25, mz), Vector3(0.4, 1.5, 0.9), _g(Color(0.5, 0.52, 0.55), MeshBuilder.METAL))
	_panel(mb, Vector3(x1 + 0.41, 1.5, mz), Vector3.BACK, Vector3.RIGHT, Vector2(0.5, 0.4), _g(Color(0.4, 0.8, 1.0), MeshBuilder.GLOW_NEON))
	var bol := _g(Color(0.95, 0.8, 0.2), MeshBuilder.GLOSS)
	for i in 4:
		var bp := Vector3(lerpf(x0 + 0.8, x1 - 0.6, i / 3.0), 0.06, fz - 0.6)
		mb.cylinder(bp, 0.13, 1.0, bol, 6)
	out.append([Vector3(cx, 0.5, fz - 0.6), Vector3(bw - 1.0, 1.0, 0.3)])
	# A security camera on each front corner.
	for x: float in [x0 + 0.3, x1 - 0.3]:
		mb.box(Vector3(x, H - 0.1, fz - 0.35), Vector3(0.22, 0.2, 0.45), Color(0.85, 0.85, 0.82))
	# Behind and beside: a strip with weeds, two bays, a barbed fence.
	var back := hd - z1
	if back >= 2.0:
		_stalls(mb, x0, hd - 0.3, maxi(1, int(bw / 2.8)), 2.8, minf(back - 0.6, 5.0), -1.0, rng)
		if back >= 5.0 and rng.randf() < 0.6:
			_beater(mb, out, Vector3(x0 + 1.4, 0, hd - 2.6), 0.0, rng)
		_chainlink_x(mb, out, -hw + 0.2, hw - 0.2, hd - 0.2, 2.0, [], rng, true)
	if x0 + hw >= 1.5:
		_weeds(mb, -hw, x0, fz, hd, int((x0 + hw) * d / 6.0), rng)
		Props.trash_can(mb, out, Vector3((x0 - hw) * 0.5, 0, fz + 0.6))
	_bags(mb, Vector3(x0 - 0.2 if x0 + hw > 1.4 else x0 + 1.0, 0, z1 + 0.6), 2, rng, 0.2)
	_cracks(mb, -hw, hw, -hd, fz, 3, rng, 0.08)


## A narrow brick SRO hotel, five to seven storeys, after the Tenderloin and
## Skid Row: shuttered shops either side of a gated entry, windows hung
## with sheets, boarded or broken, AC units, a fire escape down the front,
## a dead neon blade sign on a bracket, a ghost sign on the side, a water
## tank on the tar roof.
static func sro_hotel(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var hw := w * 0.5
	var hd := d * 0.5
	var floors := rng.randi_range(5, 7)
	const GF := 4.0
	const FH := 3.1
	var H := GF + (floors - 1) * FH
	var bw := w - 0.6
	var fz := -hd + 1.8
	var bd := clampf(d * 0.74, 9.0, d - 2.4)
	var z1 := fz + bd
	var body: Color = Kit._pick(BRICKS, rng)
	var wall := _g(body, MeshBuilder.BRICK)
	var trim: Color = Kit._pick([Color(0.78, 0.74, 0.64), Color(0.6, 0.58, 0.54), Color(0.7, 0.62, 0.5)], rng)
	var tc := _g(trim, MeshBuilder.CONCRETE)
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	Kit._pad(mb, -hw, hw, -hd, fz, _g(SIDEWALK, MeshBuilder.CONCRETE), 0.06)
	_cracks(mb, -hw, hw, -hd, fz, 4, rng, 0.08)
	_stains(mb, -hw, hw, -hd, fz, 2, rng, 0.085)
	Kit._pad(mb, -hw, hw, z1, hd, _g(ASPHALT, MeshBuilder.ASPHALT))
	Kit._solid(mb, out, Vector3(0, H * 0.5, fz + bd * 0.5), Vector3(bw, H, bd), wall)
	mb.box(Vector3(0, H - 0.35, fz + bd * 0.5), Vector3(bw + 0.4, 0.7, bd + 0.3), tc)
	mb.box(Vector3(0, GF, fz - 0.1), Vector3(bw, 0.3, 0.2), tc)
	_shabby_roof(mb, -bw * 0.5, bw * 0.5, fz, z1, H, trim.darkened(0.15), rng, 0.8)
	# A water tank on legs and a stair bulkhead on the roof.
	var tk := Vector3(-side * bw * 0.22, H, z1 - 2.6)
	var wood := Color(0.42, 0.32, 0.24)
	for lx: float in [-0.9, 0.9]:
		for lz: float in [-0.9, 0.9]:
			mb.box(tk + Vector3(lx, 1.0, lz), Vector3(0.14, 2.0, 0.14), IRON)
	mb.box(tk + Vector3(0, 2.0, 0), Vector3(2.4, 0.15, 2.4), wood.darkened(0.2))
	mb.cylinder(tk + Vector3(0, 2.05, 0), 1.15, 2.6, _g(wood, MeshBuilder.SIDING), 9)
	Kit._cone(mb, tk + Vector3(0, 4.65, 0), 1.25, 0.9, Color(0.25, 0.25, 0.26), 9)
	mb.box(Vector3(side * (bw * 0.5 - 1.6), H + 1.25, z1 - 2.0), Vector3(2.2, 2.5, 2.4), tc)
	# Ground floor: a gated entry under a little marquee, shops either side.
	_panel(mb, Vector3(0, 1.3, fz - 0.03), Vector3.RIGHT, Vector3.FORWARD, Vector2(1.6, 2.6), RECESS)
	_bars(mb, Vector3(0, 1.3, fz), Vector3.RIGHT, Vector3.FORWARD, 1.7, 2.6)
	_panel(mb, Vector3(0, 2.95, fz - 0.03), Vector3.RIGHT, Vector3.FORWARD, Vector2(1.6, 0.4), _g(Color(0.9, 0.8, 0.5), MeshBuilder.GLOW_WINDOW))
	mb.box(Vector3(0, 3.35, fz - 0.6), Vector3(2.6, 0.25, 1.2), Color(0.2, 0.2, 0.21))
	var shop_w := (bw - 2.4) * 0.5 - 0.6
	var bodega := rng.randf() < 0.5
	for s: float in [-1.0, 1.0]:
		var sx := s * ((bw - 2.4) * 0.25 + 1.2)
		if bodega and s == side:
			var c := Vector3(sx, 1.5, fz)
			_panel(mb, c + Vector3(0, 0, -0.03), Vector3.RIGHT, Vector3.FORWARD, Vector2(shop_w, 2.0), _g(Color(0.55, 0.5, 0.36), MeshBuilder.GLOW_WINDOW))
			_bars(mb, c, Vector3.RIGHT, Vector3.FORWARD, shop_w, 2.05)
			_sign_band(mb, Vector3(sx, 3.15, fz), Vector3.RIGHT, Vector3.FORWARD, shop_w, 0.6, Kit._pick(SIGN_FIELDS, rng), rng, true)
		else:
			_shutter(mb, Vector3(sx, 0.2, fz), Vector3.RIGHT, Vector3.FORWARD, shop_w, 2.6, 0.0, rng)
	# Upper floors.
	_face_windows(mb, Vector2(-bw * 0.5, fz), Vector2(bw * 0.5, fz), Vector3.FORWARD, floors - 1, FH, 2.3, Vector2(1.1, 1.6), rng, GF + 1.5, 0.0, [0.48, 0.04, 0.13, 0.13, 0.22], 0.2)
	for s: float in [-1.0, 1.0]:
		var sx := s * bw * 0.5
		var lw := Vector2(sx, z1 - minf(5.0, bd * 0.4))
		_face_windows(mb, lw, Vector2(sx, z1 - 0.6), Vector3(s, 0, 0), floors - 1, FH, 2.4, Vector2(1.0, 1.4), rng, GF + 1.5, 0.0, [0.5, 0.05, 0.15, 0.15, 0.15], 0.0)
	_face_windows(mb, Vector2(bw * 0.5, z1), Vector2(-bw * 0.5, z1), Vector3.BACK, floors - 1, FH, 2.6, Vector2(1.0, 1.4), rng, GF + 1.5, 0.0, [0.5, 0.05, 0.15, 0.15, 0.15], 0.1)
	_ghost_sign(mb, Vector3(-side * bw * 0.5, H - 3.6, fz + bd * 0.32), Vector3(0, 0, -side), Vector3(-side, 0, 0), minf(bd * 0.55, 8.0), 3.4, rng)
	# The fire escape and the dead blade sign.
	_fire_escape(mb, Vector3(0, 0, fz), Vector3.RIGHT, Vector3.FORWARD, -bw * 0.3, bw * 0.3, floors, GF, FH)
	var sy0 := GF + FH * 0.5
	var sy1 := minf(sy0 + FH * 2.8, H - 0.8)
	_blade_sign(mb, Vector3(side * (bw * 0.5 - 0.7), 0, fz), Vector3.FORWARD, sy0, sy1, 1.2, Kit._pick(SIGN_FIELDS, rng), Kit._pick(NEONS, rng), rng, true)
	# Tags at street level, junk in the back alley.
	for s: float in [-1.0, 1.0]:
		_tag(mb, Vector3(s * bw * 0.5, 1.8, fz + rng.randf_range(2.0, bd - 2.0)), Vector3(0, 0, s), Vector3(s, 0, 0), 3.0, 1.2, rng)
	if hd - z1 >= 1.6:
		_dumpster(mb, out, Vector3(side * (hw - 1.3), 0, (z1 + hd) * 0.5), 0.0, rng)
		if hd - z1 >= 2.3:
			_mattress(mb, Vector3(-side * (hw - 2.0), 0, (z1 + hd) * 0.5), PI * 0.5 + rng.randf_range(-0.2, 0.2), rng)
		else:
			_bags(mb, Vector3(-side * (hw - 1.5), 0, (z1 + hd) * 0.5), 2, rng, 0.2)
	_bags(mb, Vector3(side * (bw * 0.25), 0, -hd + 0.9), 2, rng, 0.3)


## A fire escape on a wall: o is the wall's foot on its face, u along the
## wall, n out; landings from s0 to s1 (along u) at each upper floor with
## railings, a flight between landings, a drop ladder over the street.
static func _fire_escape(mb, o: Vector3, u: Vector3, n: Vector3, s0: float, s1: float, floors: int, gf: float, fh: float) -> void:
	var iron := _g(Color(0.12, 0.12, 0.13), MeshBuilder.GLOSS)
	var length := s1 - s0
	var mid := o + u * (s0 + s1) * 0.5
	const DEP := 1.2
	for f in range(1, floors):
		var y := gf + (f - 1) * fh
		mb.box(mid + n * DEP * 0.5 + Vector3(0, y, 0), u.abs() * length + Vector3(0, 0.06, 0) + n.abs() * DEP, iron)
		var ro := mid + n * DEP + Vector3(0, y, 0)
		_stroke(mb, ro, u, n, Vector2(-length * 0.5, 1.0), Vector2(length * 0.5, 1.0), 0.07, iron)
		_stroke(mb, ro, u, n, Vector2(-length * 0.5, 0.5), Vector2(length * 0.5, 0.5), 0.05, iron)
		var k := maxi(2, int(length / 0.5))
		for i in k + 1:
			var s := -length * 0.5 + length * i / k
			_stroke(mb, ro, u, n, Vector2(s, 0.0), Vector2(s, 1.0), 0.04, iron)
		if f > 1:
			var dir := 1.0 if f % 2 == 0 else -1.0
			var a := mid + n * (DEP * 0.5) + u * (-dir * length * 0.42) + Vector3(0, y - fh + 0.05, 0)
			var b := mid + n * (DEP * 0.5) + u * (dir * length * 0.1) + Vector3(0, y, 0)
			var sn := (b - a).cross(n).normalized()
			if sn.y < 0.0:
				sn = -sn
			mb.quad(a - n * 0.32, a + n * 0.32, b + n * 0.32, b - n * 0.32, sn, iron)
	var lo := mid + n * (DEP - 0.15) + u * (length * 0.36)
	for s: float in [-0.25, 0.25]:
		_stroke(mb, lo, u, n, Vector2(s, gf * 0.45), Vector2(s, gf), 0.05, iron)
	for r in 4:
		var y := lerpf(gf * 0.5, gf - 0.3, r / 3.0)
		_stroke(mb, lo, u, n, Vector2(-0.25, y), Vector2(0.25, y), 0.04, iron)


## A chop shop: a corrugated garage with roll-up doors (one open), a yard
## behind a mismatched sheet-metal fence and a chain-link gate, stripped
## shells on blocks, tyre stacks, an engine on a pallet, doors and a hood
## leaning on the fence, an engine hoist and a flood light.
static func chop_shop(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var hw := w * 0.5
	var hd := d * 0.5
	var gw := clampf(w * 0.68, 12.0, w - 2.0)
	var gd := clampf(d * 0.38, 7.0, 13.0)
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	var gx := side * (hw - 0.6 - gw * 0.5)
	var gz1 := hd - 0.6
	var gz0 := gz1 - gd
	const H := 5.0
	var metal: Color = Kit._pick(METALS, rng)
	var wall := _g(metal, MeshBuilder.SEAM_ROOF)
	var fh := 2.4
	Kit._pad(mb, -hw, hw, -hd, hd, _g(Color(0.55, 0.54, 0.5), MeshBuilder.CONCRETE))
	_cracks(mb, -hw, hw, -hd, gz0, int(w * d / 60.0), rng, 0.04)
	_stains(mb, -hw + 1.0, hw - 1.0, -hd + 1.0, gz0, int(w * d / 50.0), rng, 0.04)
	# The garage.
	Kit._solid(mb, out, Vector3(gx, H * 0.5, (gz0 + gz1) * 0.5), Vector3(gw, H, gd), wall)
	var roof_c := _g((Kit._pick(METALS, rng) as Color).lerp(RUST, 0.3), MeshBuilder.SEAM_ROOF)
	var rc := Vector3(gx, H + 0.65, (gz0 + gz1) * 0.5)
	var rs := Vector3(gw + 0.4, 1.3, gd + 0.6)
	mb.gable(rc, rs, roof_c, wall)
	for i in rng.randi_range(2, 4):
		var px := rng.randf_range(gx - gw * 0.45, gx + gw * 0.3)
		Buildings._slope_quad(mb, rc, rs, px, px + rng.randf_range(1.2, 2.6), rng.randf_range(0.0, 0.4), rng.randf_range(0.5, 0.95), _g(RUST if rng.randf() < 0.6 else Color(0.75, 0.77, 0.78), MeshBuilder.SEAM_ROOF))
	var nd := clampi(int(gw / 5.0), 2, 4)
	var open_i := rng.randi() % nd
	for i in nd:
		var dx := gx - gw * 0.5 + gw * (i + 0.5) / nd
		_shutter(mb, Vector3(dx, 0, gz0), Vector3.RIGHT, Vector3.FORWARD, 3.4, 3.8, 1.0 if i == open_i else (0.0 if rng.randf() < 0.7 else 0.35), rng)
		if i == open_i:
			_shell(mb, out, Vector3(dx, 0, gz0 - 2.8), rng.randf_range(-0.1, 0.1), rng)
			# Engine hoist beside the open door.
			var hp := Vector3(dx + 2.2 * (1.0 if i < nd - 1 else -1.0), 0, gz0 - 1.2)
			var red := _g(Color(0.7, 0.18, 0.15), MeshBuilder.GLOSS)
			Kit._beam(mb, hp + Vector3(-0.4, 0.05, 0.6), hp + Vector3(0, 2.2, 0), 0.1, red)
			Kit._beam(mb, hp + Vector3(0.4, 0.05, 0.6), hp + Vector3(0, 2.2, 0), 0.1, red)
			Kit._beam(mb, hp + Vector3(0, 2.2, 0), hp + Vector3(0, 2.0, -1.4), 0.1, red)
			Kit._beam(mb, hp + Vector3(0, 2.0, -1.4), hp + Vector3(0, 1.1, -1.4), 0.03, DARK)
			mb.box(hp + Vector3(0, 0.85, -1.4), Vector3(0.6, 0.5, 0.7), Color(0.3, 0.3, 0.32))
	var board := Vector3(gx, H - 0.55, gz0)
	mb.box(board + Vector3(0, 0, -0.06), Vector3(minf(gw - 2.0, 9.0), 0.8, 0.1), (Kit._pick(SIGN_FIELDS, rng) as Color).darkened(0.25))
	_glyphs(mb, board + Vector3(0, 0, -0.12), Vector3.RIGHT, Vector3.FORWARD, minf(gw - 3.0, 7.0), 0.45, DARK, rng)
	_tag(mb, Vector3(gx + side * (gw * 0.5), 2.0, (gz0 + gz1) * 0.5), Vector3(0, 0, side), Vector3(side, 0, 0), minf(gd - 2.0, 5.0), 1.4, rng)
	# Fences: sheet metal round the yard, a chain-link gate on the street.
	var gate_x := -side * (hw * 0.45)
	var gw2 := 5.0
	_sheet_fence(mb, out, Vector3(-hw + 0.2, 0, -hd + 0.2), Vector3(gate_x - gw2 * 0.5, 0, -hd + 0.2), fh, rng)
	_sheet_fence(mb, out, Vector3(gate_x + gw2 * 0.5, 0, -hd + 0.2), Vector3(hw - 0.2, 0, -hd + 0.2), fh, rng)
	_sheet_fence(mb, out, Vector3(-hw + 0.2, 0, -hd + 0.4), Vector3(-hw + 0.2, 0, hd - 0.2), fh, rng)
	_sheet_fence(mb, out, Vector3(hw - 0.2, 0, -hd + 0.4), Vector3(hw - 0.2, 0, hd - 0.2), fh, rng)
	if rng.randf() < 0.5:
		_chainlink(mb, out, Vector3(gate_x - gw2 * 0.5, 0, -hd + 0.25), Vector3(gate_x + gw2 * 0.5, 0, -hd + 0.25), fh, rng, true, false, 3)
	else:
		_chainlink(mb, out, Vector3(gate_x + gw2 * 0.5, 0, -hd + 0.55), Vector3(gate_x + gw2 * 1.5 - 0.3, 0, -hd + 0.55), fh, rng, true, false, 3)
	for i in 2:
		_tag(mb, Vector3(lerpf(-hw + 2.0, hw - 2.0, rng.randf()), 1.3, -hd + 0.15), Vector3.RIGHT, Vector3.FORWARD, 2.2, 0.9, rng)
	# The yard: stripped shells, tyres, parts.
	var yz0 := -hd + 3.2
	var yz1 := gz0 - 3.4
	var ns := clampi(int(w / 9.0), 1, 4)
	for i in ns:
		var x := lerpf(-hw + 3.0, hw - 3.0, (i + 0.5) / ns)
		if absf(x - gate_x) < 2.0:
			x += 2.8 * signf(x - gate_x + 0.01)
		var z := lerpf(yz0, yz1, rng.randf()) if yz1 > yz0 else yz0
		_shell(mb, out, Vector3(x, 0, z), PI * 0.5 + rng.randf_range(-0.35, 0.35), rng)
	var tz := gz0 - 1.2
	for i in rng.randi_range(3, 5):
		var tx := -side * (hw - 1.2) + side * i * 0.85
		_tyres(mb, out, Vector3(tx, 0, tz - (i % 2) * 0.8), rng.randi_range(2, 5))
	var pallet := Vector3(side * (hw - 2.2), 0, -hd + 1.6)
	mb.box(pallet + Vector3(0, 0.07, 0), Vector3(1.2, 0.14, 1.0), Color(0.6, 0.48, 0.32))
	mb.box(pallet + Vector3(0, 0.45, 0), Vector3(0.8, 0.6, 0.6), _g(Color(0.3, 0.3, 0.31), MeshBuilder.METAL))
	mb.box(pallet + Vector3(0.1, 0.85, 0), Vector3(0.5, 0.2, 0.4), _g(Color(0.5, 0.15, 0.12), MeshBuilder.GLOSS))
	for i in 3:
		var dc: Color = (Kit._pick(CAR_PAINTS, rng) as Color).lerp(RUST, rng.randf() * 0.4)
		var zx := -side * (hw - 0.45)
		_rbox(mb, Vector3(zx, 0.55, -hd + 3.0 + i * 1.3), Vector3(0.1, 1.0, 1.1), 0.0, _g(dc, MeshBuilder.GLOSS))
	_rbox(mb, Vector3(rng.randf_range(-2.0, 2.0), 0.05, (yz0 + gz0) * 0.5), Vector3(1.5, 0.05, 1.2), rng.randf() * TAU, _g(Kit._pick(CAR_PAINTS, rng), MeshBuilder.GLOSS))
	# A flood light on a pole by the gate.
	var lp := Vector3(gate_x + side * 3.4, 0, -hd + 0.9)
	mb.box(lp + Vector3(0, 2.6, 0), Vector3(0.16, 5.2, 0.16), _g(Color(0.4, 0.4, 0.42), MeshBuilder.METAL))
	mb.box(lp + Vector3(0, 5.2, 0.4), Vector3(0.6, 0.35, 0.3), _g(Color(1.0, 0.92, 0.75), MeshBuilder.GLOW_LAMP))
	out.append([lp + Vector3(0, 1.5, 0), Vector3(0.3, 3.0, 0.3)])
	_weeds(mb, -hw + 0.4, hw - 0.4, gz1 - 0.2, hd - 0.2, 3, rng, 0.2, 0.35)


## A scrapyard: a dirt yard behind sheet-metal fences and a barbed
## chain-link front with a gate, a weigh scale and an office cabin, rows
## of crushed-car stacks, scrap heaps, a tyre pile, a baler and a claw
## crane on a mast.
static func scrapyard(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var hw := w * 0.5
	var hd := d * 0.5
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	Kit._pad(mb, -hw, hw, -hd, hd, DIRT.darkened(0.05))
	for i in int(w * d / 90.0):
		_blot(mb, rng.randf_range(-hw + 2, hw - 2), rng.randf_range(-hd + 2, hd - 2), rng.randf_range(0.8, 2.5), rng.randf_range(0.8, 2.0), 0.04, (DIRT.darkened(0.45) if i % 2 == 0 else DIRT.darkened(0.25)), 9)
	# Fences and the gate.
	var gate_x := side * (hw - 7.0)
	var fh := 2.6
	_sheet_fence(mb, out, Vector3(-hw + 0.2, 0, hd - 0.2), Vector3(hw - 0.2, 0, hd - 0.2), fh, rng)
	_sheet_fence(mb, out, Vector3(-hw + 0.2, 0, -hd + 0.6), Vector3(-hw + 0.2, 0, hd - 0.4), fh, rng)
	_sheet_fence(mb, out, Vector3(hw - 0.2, 0, -hd + 0.6), Vector3(hw - 0.2, 0, hd - 0.4), fh, rng)
	_chainlink_x(mb, out, -hw + 0.2, hw - 0.2, -hd + 0.4, fh, [[gate_x - 3.2, gate_x + 3.2]], rng, true, 2)
	# The weigh scale inside the gate, the office cabin beside it.
	var scale_l := minf(8.0, d * 0.25)
	mb.box(Vector3(gate_x, 0.08, -hd + 1.2 + scale_l * 0.5), Vector3(3.2, 0.16, scale_l), _g(Color(0.45, 0.46, 0.47), MeshBuilder.METAL))
	var ox := gate_x - side * 6.5
	var oz := -hd + 2.8
	var cabin := _g(Color(0.85, 0.84, 0.78), MeshBuilder.SIDING)
	Kit._solid(mb, out, Vector3(ox, 1.55, oz), Vector3(6.0, 2.7, 2.6), cabin)
	mb.box(Vector3(ox, 0.1, oz), Vector3(6.2, 0.2, 2.8), CINDER)
	mb.box(Vector3(ox, 2.95, oz), Vector3(6.2, 0.1, 2.8), _g(Color(0.5, 0.5, 0.48), MeshBuilder.ROOF))
	_win(mb, Vector3(ox - 1.4, 1.8, oz - 1.3), Vector3.RIGHT, Vector3.FORWARD, Vector2(1.4, 0.9), 1, rng, 0.8)
	_win(mb, Vector3(ox + 1.6, 1.8, oz - 1.3), Vector3.RIGHT, Vector3.FORWARD, Vector2(1.0, 0.9), 1, rng, 0.8)
	_panel(mb, Vector3(ox + 0.3, 1.3, oz - 1.33), Vector3.RIGHT, Vector3.FORWARD, Vector2(0.9, 2.0), _g(Color(0.4, 0.42, 0.45), MeshBuilder.METAL))
	mb.box(Vector3(ox + 0.3, 0.3, oz - 1.8), Vector3(1.2, 0.2, 0.8), _g(Color(0.4, 0.4, 0.42), MeshBuilder.METAL))
	mb.box(Vector3(ox, 3.3, oz - 1.0), Vector3(3.6, 0.7, 0.12), (Kit._pick(SIGN_FIELDS, rng) as Color).darkened(0.2))
	_glyphs(mb, Vector3(ox, 3.3, oz - 1.07), Vector3.RIGHT, Vector3.FORWARD, 3.0, 0.4, DARK, rng)
	# Rows of crushed-car stacks at the back, one collider per row.
	var rows := clampi(int(d * 0.5 / 6.0), 2, 3)
	for r in rows:
		var zr := hd - 3.0 - r * 6.0
		var xa := -hw + 2.0
		var xb := hw - 2.0
		if r == rows - 1:
			if side > 0.0:
				xb = hw * 0.15
			else:
				xa = -hw * 0.15
		var x := xa + 1.0
		var top := 0.0
		while x < xb - 0.9:
			if rng.randf() < 0.85:
				top = maxf(top, _cube_stack(mb, Vector3(x, 0, zr), rng.randi_range(2, 6), rng))
			x += 2.3
		Kit._col(out, Vector3((xa + xb) * 0.5, top * 0.5, zr), Vector3(xb - xa, maxf(top, 0.6), 4.0))
	# Scrap heaps and the claw crane in the middle.
	var mz := lerpf(-hd + scale_l + 2.0, hd - 3.0 - (rows - 1) * 6.0 - 3.0, 0.5)
	var heaps := 2 if w < 40.0 else 3
	for i in heaps:
		var hx := lerpf(-hw * 0.6, hw * 0.6, (i + 0.5) / heaps) - side * 2.0
		var r := rng.randf_range(2.8, 4.0)
		var hp := Vector3(hx, 0, mz + rng.randf_range(-1.0, 1.0))
		Kit._cone(mb, hp, r, rng.randf_range(1.8, 2.8), _g(RUST.lerp(Color(0.4, 0.38, 0.36), rng.randf()), MeshBuilder.METAL), 8)
		for k in 9:
			var a := rng.randf() * TAU
			var rr := rng.randf_range(0.3, r * 0.8)
			var bp := hp + Vector3(cos(a) * rr, 0.0, sin(a) * rr)
			var by := (1.0 - rr / r) * 2.0 + 0.2
			_rbox(mb, bp + Vector3(0, by, 0), Vector3(rng.randf_range(0.3, 1.4), rng.randf_range(0.1, 0.4), rng.randf_range(0.2, 0.8)), rng.randf() * TAU, _g((Kit._pick(METALS + CAR_PAINTS, rng) as Color).darkened(0.1), MeshBuilder.METAL))
		out.append([hp + Vector3(0, 0.8, 0), Vector3(r * 1.3, 1.6, r * 1.3)])
	var cp := Vector3(side * hw * 0.05, 0, mz + 4.5)
	_claw_crane(mb, out, cp, (0.5 if side > 0.0 else -0.5), 6.5, 7.0, rng)
	# A baler, a tyre pile, wrecks waiting by the scale.
	var bxp := Vector3(-side * (hw - 4.0), 0, mz - 4.0)
	var yel := _g(Color(0.75, 0.6, 0.2).lerp(RUST, 0.35), MeshBuilder.GLOSS)
	Kit._solid(mb, out, bxp + Vector3(0, 1.2, 0), Vector3(3.2, 2.4, 7.0), yel)
	mb.box(bxp + Vector3(0, 2.42, -0.8), Vector3(2.4, 0.02, 4.0), DARK)
	mb.box(bxp + Vector3(0, 3.2, 2.5), Vector3(3.0, 1.6, 1.6), yel)
	for k in 8:
		_tyres(mb, out if k == 0 else [], Vector3(side * (hw - 2.0) - side * (k % 4) * 0.8, 0, mz - 5.0 + (k / 4) * 0.8), rng.randi_range(2, 5), k == 0)
	for i in 2:
		_shell(mb, out, Vector3(gate_x - side * (3.0 + i * 2.6), 0, -hd + scale_l + 3.5), rng.randf_range(-0.2, 0.2), rng)
	_weeds(mb, -hw + 0.5, hw - 0.5, hd - 1.0, hd - 0.4, int(w / 5.0), rng, 0.2, 0.4)
	_weeds(mb, -hw + 0.5, hw - 0.5, -hd + 0.6, -hd + 1.2, int(w / 5.0), rng, 0.2, 0.4)


## An abandoned brick warehouse: a sawtooth roof whose glazing is mostly
## smashed and partly fallen in, steel factory windows with the panes gone,
## boarded loading doors and a rusted roll door stuck half open, a ghost
## sign on the parapet, tags at street level, a cracked apron gone to
## weeds, a rusting container, pallets and a fallen fence.
static func abandoned_warehouse(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var hw := w * 0.5
	var hd := d * 0.5
	var bw := w - 1.6
	var bd := clampf(d * 0.7, 10.0, d - 5.0)
	var z1 := hd - 0.8
	var fz := z1 - bd
	var H := clampf(w * 0.2, 6.5, 9.0)
	var bc: Color = (Kit._pick(BRICKS, rng) as Color).darkened(0.1)
	var wall := _g(bc, MeshBuilder.BRICK)
	var conc := _g(Color(0.6, 0.59, 0.55), MeshBuilder.CONCRETE)
	Kit._pad(mb, -hw, hw, -hd, hd, conc)
	_cracks(mb, -hw, hw, -hd, fz, int(w * (fz + hd) / 18.0), rng, 0.04)
	_stains(mb, -hw, hw, -hd, fz, int(w / 6.0), rng, 0.035)
	Kit._solid(mb, out, Vector3(0, H * 0.5, (fz + z1) * 0.5), Vector3(bw, H, bd), wall)
	# Parapet with a ghost sign.
	mb.box(Vector3(0, H + 0.6, fz + 0.2), Vector3(bw, 1.2, 0.4), wall)
	mb.box(Vector3(0, H + 1.25, fz + 0.2), Vector3(bw + 0.1, 0.1, 0.5), Color(0.5, 0.48, 0.45))
	_ghost_sign(mb, Vector3(0, H - 0.4, fz), Vector3.RIGHT, Vector3.FORWARD, bw * 0.55, 1.6, rng)
	# Sawtooth roof: the glazing faces the street, mostly smashed.
	var teeth := maxi(2, int(bd / 5.0))
	var tl := (bd - 0.8) / teeth
	const RISE := 1.8
	var roof_c := _g(Color(0.36, 0.35, 0.34), MeshBuilder.SEAM_ROOF)
	var glass := Color(0.36, 0.42, 0.4)  # matte grime, dark at night
	var holes := 0
	for t in teeth:
		var za := fz + 0.6 + t * tl
		var zb := za + tl
		_panel(mb, Vector3(0, H + RISE * 0.5, za - 0.01), Vector3.RIGHT, Vector3.FORWARD, Vector2(bw - 0.2, RISE), Color(0.05, 0.05, 0.06))
		var k := maxi(2, int((bw - 0.4) / 1.3))
		for i in k:
			if rng.randf() < 0.45:
				_panel(mb, Vector3(-bw * 0.5 + 0.2 + (i + 0.5) * (bw - 0.4) / k, H + RISE * 0.5, za - 0.03), Vector3.RIGHT, Vector3.FORWARD, Vector2((bw - 0.4) / k - 0.12, RISE - 0.2), glass.darkened(rng.randf() * 0.3))
		var rn := Vector3(0, tl, RISE).normalized()
		mb.quad(Vector3(-bw * 0.5, H + RISE, za), Vector3(bw * 0.5, H + RISE, za), Vector3(bw * 0.5, H, zb), Vector3(-bw * 0.5, H, zb), rn, roof_c)
		for s: float in [-1.0, 1.0]:
			mb.tri(Vector3(s * bw * 0.5, H, za), Vector3(s * bw * 0.5, H + RISE, za), Vector3(s * bw * 0.5, H, zb), Vector3(s, 0, 0), wall)
		if rng.randf() < 0.55 or (t == teeth - 1 and holes == 0):
			holes += 1
			var hwid := rng.randf_range(2.5, minf(6.0, bw * 0.3))
			var hx := rng.randf_range(-bw * 0.5 + 1.0 + hwid * 0.5, bw * 0.5 - 1.0 - hwid * 0.5)
			var f0 := rng.randf_range(0.1, 0.35)
			var f1 := rng.randf_range(0.6, 0.9)
			var lift := rn * 0.03
			var pa := Vector3(0, H + RISE * (1.0 - f0), za + tl * f0) + lift
			var pb := Vector3(0, H + RISE * (1.0 - f1), za + tl * f1) + lift
			mb.quad(pa + Vector3(hx - hwid * 0.5, 0, 0), pa + Vector3(hx + hwid * 0.5, 0, 0), pb + Vector3(hx + hwid * 0.5, 0, 0), pb + Vector3(hx - hwid * 0.5, 0, 0), rn, Color(0.04, 0.04, 0.04))
			for j in 2:
				var bxx := hx + (j - 0.5) * hwid * 0.5
				Kit._beam(mb, pa + Vector3(bxx, 0.05, -0.2), pb + Vector3(bxx, 0.05, 0.2), 0.14, _g(RUST.darkened(0.2), MeshBuilder.METAL))
	# A small tree and weeds growing on the roof.
	Kit._bush(mb, Vector3(rng.randf_range(-bw * 0.35, bw * 0.35), H, z1 - 0.4), 0.7, rng, WEED)
	Kit._bush(mb, Vector3(rng.randf_range(-bw * 0.35, bw * 0.35), H + 0.02, fz + 0.45), 0.45, rng, WEED)
	# The front: loading doors (boarded, one roll door stuck), factory windows, tags.
	var nd := clampi(int(bw / 11.0), 2, 3)
	var stuck := rng.randi() % nd
	var door_xs: Array = []
	for i in nd:
		var dx := lerpf(-bw * 0.5, bw * 0.5, (i + 0.5) / nd)
		door_xs.append(dx)
		if i == stuck:
			_panel(mb, Vector3(dx, 2.1, fz - 0.02), Vector3.RIGHT, Vector3.FORWARD, Vector2(3.6, 4.2), RECESS)
			var rust_door := _g(RUST.lerp(Color(0.5, 0.5, 0.5), 0.3), MeshBuilder.SIDING)
			_panel(mb, Vector3(dx, 2.6, fz - 0.05), Vector3.RIGHT, Vector3.FORWARD, Vector2(3.6, 3.2), rust_door)
			_tag(mb, Vector3(dx, 2.8, fz - 0.05), Vector3.RIGHT, Vector3.FORWARD, 2.6, 1.3, rng)
		else:
			for s: float in [-1.0, 1.0]:
				_panel(mb, Vector3(dx + s * 0.92, 2.1, fz - 0.04), Vector3.RIGHT, Vector3.FORWARD, Vector2(1.76, 4.2), _g(PLYWOOD.darkened(rng.randf() * 0.35), MeshBuilder.SIDING))
			_tag(mb, Vector3(dx + rng.randf_range(-0.6, 0.6), 2.0, fz - 0.05), Vector3.RIGHT, Vector3.FORWARD, rng.randf_range(2.2, 3.2), 1.2, rng)
		mb.box(Vector3(dx, 4.45, fz - 0.12), Vector3(4.0, 0.3, 0.24), Color(0.4, 0.38, 0.36))
	var nw := maxi(2, int(bw / 4.5))
	for i in nw:
		var wx := lerpf(-bw * 0.5 + 1.5, bw * 0.5 - 1.5, (i + 0.5) / nw)
		var clear := true
		for dx in door_xs:
			if absf(wx - dx) < 3.4:
				clear = false
		if clear:
			_factory_window(mb, Vector3(wx, 2.6, fz), Vector3.RIGHT, Vector3.FORWARD, 2.4, 2.4, rng, 0.65)
			if rng.randf() < 0.5:
				_tag(mb, Vector3(wx, 1.2, fz), Vector3.RIGHT, Vector3.FORWARD, 2.2, 0.75, rng)
		_factory_window(mb, Vector3(wx, H - 1.6, fz), Vector3.RIGHT, Vector3.FORWARD, 2.6, 1.8, rng, 0.6)
	for s: float in [-1.0, 1.0]:
		var nsd := maxi(2, int(bd / 4.5))
		for i in nsd:
			var wz := lerpf(fz + 1.5, z1 - 1.5, (i + 0.5) / nsd)
			_factory_window(mb, Vector3(s * bw * 0.5, H - 2.0, wz), Vector3(0, 0, s), Vector3(s, 0, 0), 2.6, 2.2, rng, 0.6)
		_tag(mb, Vector3(s * bw * 0.5, 1.8, lerpf(fz + 2.0, z1 - 2.0, rng.randf())), Vector3(0, 0, s), Vector3(s, 0, 0), 3.2, 1.3, rng)
	# A loading dock before one boarded door, weeds along the wall and cracks.
	var dock_x: float = door_xs[(stuck + 1) % nd]
	Kit._solid(mb, out, Vector3(dock_x, 0.6, fz - 1.2), Vector3(5.0, 1.2, 2.4), conc)
	_weeds(mb, -hw + 0.3, hw - 0.3, fz - 0.9, fz - 0.1, int(bw / 2.0), rng, 0.3, 0.6)
	_weeds(mb, -hw, hw, -hd, fz - 2.6, int(w * (fz + hd) / 30.0), rng, 0.25, 0.55)
	# Yard junk: a rusting container, pallets, tyres, a mattress, trash; a fallen fence.
	var yard := fz + hd
	var cside := -1.0 if rng.randf() < 0.5 else 1.0
	if yard >= 4.4:
		var cz := -hd + 1.0 + 1.25
		Props.container(mb, out, Vector3(cside * (hw - 4.0), 0, cz), _g(RUST.lerp(Color(0.3, 0.42, 0.5), rng.randf() * 0.5), MeshBuilder.SEAM_ROOF))
	for i in 3:
		mb.box(Vector3(-cside * (hw - 2.5), 0.08 + i * 0.15, -hd + 2.2), Vector3(1.2, 0.14, 1.0), Color(0.55, 0.45, 0.32).darkened(i * 0.08))
	_tyres(mb, out, Vector3(-cside * (hw - 4.2), 0, -hd + 1.8), 3)
	_mattress(mb, Vector3(rng.randf_range(-3.0, 3.0), 0, -hd + 2.0), rng.randf_range(-0.6, 0.6), rng)
	_bags(mb, Vector3(-cside * (hw - 5.6), 0, -hd + 2.2), 3, rng, 0.4)
	var gaps := [[-hw * 0.2, hw * 0.25]]
	_chainlink_x(mb, out, -hw + 0.2, hw - 0.2, -hd + 0.3, 2.0, gaps, rng, false, 2)
	var fallen := Vector3(hw * 0.02, 0.06, -hd + 1.4)
	for j in 6:
		var x0 := -hw * 0.2 + 0.2 + j * (hw * 0.45 - 0.4) / 6.0
		_stroke(mb, fallen, Vector3.RIGHT, Vector3.UP, Vector2(x0 - fallen.x, -0.9), Vector2(x0 - fallen.x + 0.8, 0.9), 0.05, Color(0.55, 0.57, 0.58), Vector3.BACK)
		_stroke(mb, fallen, Vector3.RIGHT, Vector3.UP, Vector2(x0 - fallen.x + 0.8, -0.9), Vector2(x0 - fallen.x, 0.9), 0.05, Color(0.55, 0.57, 0.58), Vector3.BACK)


# --- Poor housing ---------------------------------------------------------------------

## A small 1920s bungalow on a narrow lot, after South LA: a low front gable
## with wide eaves, a porch on tapered piers, bars on every window and a
## security screen door, a chain-link front fence, a worn yard and a
## two-strip drive with a car on blocks (or a beater), a couch, bins, a
## tarp on the roof now and then, an old garage or shed out back.
static func bungalow_barred(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var hw := w * 0.5
	var hd := d * 0.5
	var bw := clampf(w * 0.64, 5.5, 9.5)
	var bd := clampf(d * 0.46, 7.0, 11.0)
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	var cx := -side * (hw - 0.6 - bw * 0.5)
	var fz := -hd + clampf(d * 0.26, 4.2, 6.5)
	var cz := fz + bd * 0.5
	const PL := 0.55
	const WH := 2.8
	var eave := PL + WH
	var paint: Color = Kit._pick(FADED, rng)
	var wall := _g(paint, MeshBuilder.SIDING) if rng.randf() < 0.55 else _g(paint, MeshBuilder.CONCRETE)
	var trim := paint.lerp(Color(0.92, 0.9, 0.84), 0.5)
	var roof: Color = Kit._pick(SHINGLES, rng)
	var conc := _g(CONCRETE, MeshBuilder.CONCRETE)
	# Yard: worn grass, bare dirt, a two-strip drive down the side.
	Kit._pad(mb, -hw, hw, -hd, hd, _g(DRY, MeshBuilder.GRASS))
	for i in rng.randi_range(3, 5):
		_blot(mb, rng.randf_range(-hw + 1.2, hw - 1.2), rng.randf_range(-hd + 1.2, fz - 0.6), rng.randf_range(0.6, 1.4), rng.randf_range(0.5, 1.1), 0.04, DIRT, 7)
	var dw := w - bw - 0.6
	var dcx := side * (hw - dw * 0.5)
	if dw >= 2.0:
		for s: float in [-1.0, 1.0]:
			Kit._pad(mb, dcx + s * 0.75 - 0.3, dcx + s * 0.75 + 0.3, -hd, hd - 1.0, conc, 0.05)
		_cracks(mb, dcx - 1.1, dcx + 1.1, -hd, hd - 1.0, 2, rng, 0.07)
	# The house.
	Kit._solid(mb, out, Vector3(cx, eave * 0.5, cz), Vector3(bw, eave, bd), wall)
	mb.box(Vector3(cx, PL * 0.5, cz), Vector3(bw + 0.06, PL, bd + 0.06), _g(CONCRETE.darkened(0.15), MeshBuilder.CONCRETE))
	var rise := clampf(bw * 0.2, 1.2, 1.9)
	var hs := (bw + 1.0) * 0.5
	Kit._gable(mb, cx, cz, eave, bw + 1.0, bd + 1.0, rise, roof, wall, true)
	var rz0 := cz - bd * 0.5 - 0.5
	var rz1 := cz + bd * 0.5 + 0.5
	for i in rng.randi_range(1, 3):
		var pz := rng.randf_range(rz0 + 0.5, rz1 - 2.0)
		_gable_patch(mb, cx, eave, hs, rise, 1.0 if rng.randf() < 0.5 else -1.0, pz, pz + rng.randf_range(0.8, 1.6), rng.randf_range(0.1, 0.4), rng.randf_range(0.6, 0.9), roof.darkened(0.25) if i % 2 == 0 else roof.lightened(0.12))
	if rng.randf() < 0.4:
		var tz := rng.randf_range(rz0 + 0.8, rz1 - 3.5)
		_gable_patch(mb, cx, eave, hs, rise, side, tz, tz + rng.randf_range(2.0, 3.0), 0.05, 0.8, Kit._pick(TARPS, rng))
	if rng.randf() < 0.5:
		Buildings._dish(mb, Vector3(cx + side * hs * 0.5, eave + rise * 0.5, cz + bd * 0.3))
	# Porch on tapered piers under its own little gable.
	var pw := bw * 0.62
	var px := cx
	mb.box(Vector3(px, PL * 0.5, fz - 1.1), Vector3(pw, PL, 2.2), conc)
	mb.box(Vector3(px, PL * 0.33, fz - 2.45), Vector3(1.4, PL * 0.66, 0.5), conc)
	Kit._gable(mb, px, fz - 1.0, eave - 0.25, pw + 0.4, 2.5, 0.9, roof, _g(trim, MeshBuilder.SIDING), true)
	for s: float in [-1.0, 1.0]:
		var pp := Vector3(px + s * (pw * 0.5 - 0.25), PL, fz - 2.0)
		mb.box(pp + Vector3(0, 0.5, 0), Vector3(0.5, 1.0, 0.5), _g(Kit._pick(BRICKS, rng), MeshBuilder.BRICK))
		mb.box(pp + Vector3(0, 1.0 + (WH - 1.25) * 0.5, 0), Vector3(0.24, WH - 1.25, 0.24), trim)
	out.append([Vector3(px, 1.6, fz - 2.0), Vector3(pw, 3.2, 0.5)])
	# Barred door and windows all round.
	_panel(mb, Vector3(px, PL + 1.05, fz - 0.03), Vector3.RIGHT, Vector3.FORWARD, Vector2(1.0, 2.1), (Kit._pick(DOORS, rng) as Color).darkened(0.2))
	_bars(mb, Vector3(px, PL + 1.05, fz), Vector3.RIGHT, Vector3.FORWARD, 1.0, 2.1)
	for s: float in [-1.0, 1.0]:
		_win(mb, Vector3(cx + s * bw * 0.32, PL + 1.5, fz), Vector3.RIGHT, Vector3.FORWARD, Vector2(1.2, 1.4), 1, rng, 0.4)
		_face_windows(mb, Vector2(cx + s * bw * 0.5, fz + 1.0), Vector2(cx + s * bw * 0.5, fz + bd - 1.0), Vector3(s, 0, 0), 1, WH, 3.0, Vector2(1.0, 1.2), rng, PL + 1.5, 0.9, [1.0], 0.15)
	_face_windows(mb, Vector2(cx + bw * 0.5 - 1.0, fz + bd), Vector2(cx - bw * 0.5 + 1.0, fz + bd), Vector3.BACK, 1, WH, 3.0, Vector2(1.0, 1.2), rng, PL + 1.5, 0.9, [1.0], 0.0)
	# Porch couch or yard junk, bins by the drive.
	if rng.randf() < 0.55:
		_couch(mb, Vector3(px - pw * 0.22, PL, fz - 1.0), 0.0, (Kit._pick(SHEETS, rng) as Color).darkened(0.2))
	else:
		_couch(mb, Vector3(-side * (hw - 1.6), 0, -hd + 2.6), PI * 0.5 * side + rng.randf_range(-0.3, 0.3), (Kit._pick(SHEETS, rng) as Color).darkened(0.3))
	var bins := [Color(0.15, 0.4, 0.2), Color(0.2, 0.3, 0.6), Color(0.15, 0.15, 0.16)]
	for i in 3:
		if dw >= 2.0:
			_bin(mb, Vector3(dcx + side * (dw * 0.5 - 0.45), 0, fz + 0.5 + i * 0.8), 0.0, bins[i])
	# The front fence: chain-link with a gate at the path and an open drive.
	var fzf := -hd + 0.25
	var gaps := [[px - 0.6, px + 0.6]]
	if dw >= 2.0:
		gaps.append([dcx - dw * 0.5 + 0.1, dcx + dw * 0.5 + 0.2])
	_chainlink_x(mb, out, -hw + 0.15, hw - 0.15, fzf, 1.2, gaps, rng, false, 2)
	Kit._pad(mb, px - 0.55, px + 0.55, -hd, fz - 2.7, conc, 0.05)
	# A car on blocks or a beater in the drive.
	var roll := rng.randf()
	if dw >= 2.3:
		var car_z := clampf(fz + 1.0, -hd + 3.0, hd - 3.5)
		if roll < 0.45:
			_shell(mb, out, Vector3(dcx, 0, car_z), 0.0, rng)
		elif roll < 0.8:
			_beater(mb, out, Vector3(dcx, 0, car_z), 0.0, rng)
	# Out back: an old garage at the end of the drive, or a shed.
	var back := fz + bd
	if hd - back >= 5.0 and dw >= 2.6:
		var gd := minf(5.4, hd - back - 0.8)
		var gwd := minf(4.2, w - 1.0)
		var gxx := clampf(dcx, -hw + gwd * 0.5 + 0.2, hw - gwd * 0.5 - 0.2)
		var gzz := hd - 0.3 - gd * 0.5
		var gwall := _g(paint.darkened(0.15), MeshBuilder.SIDING)
		Kit._solid(mb, out, Vector3(gxx, 1.3, gzz), Vector3(gwd, 2.6, gd), gwall)
		Kit._gable(mb, gxx, gzz, 2.6, gwd + 0.4, gd + 0.3, 1.0, roof.darkened(0.1), gwall, true)
		_panel(mb, Vector3(gxx, 1.05, gzz - gd * 0.5 - 0.03), Vector3.RIGHT, Vector3.FORWARD, Vector2(gwd - 0.8, 2.1), _g(Color(0.75, 0.73, 0.68), MeshBuilder.SIDING))
		_tag(mb, Vector3(gxx, 1.3, gzz - gd * 0.5 - 0.03), Vector3.RIGHT, Vector3.FORWARD, gwd - 1.4, 0.8, rng)
	elif hd - back >= 3.0:
		var sx := -side * (hw - 1.5)
		Kit._solid(mb, out, Vector3(sx, 1.0, hd - 1.4), Vector3(2.0, 2.0, 1.8), _g(METALS[0], MeshBuilder.SEAM_ROOF))
	if hd - back >= 2.5:
		_tyres(mb, out, Vector3(-side * (hw - 0.8), 0, back + 1.0), rng.randi_range(2, 4))
		_bags(mb, Vector3(cx, 0, back + 1.2), 2, rng, 0.3)
	# A dead palm or a scraggly tree in the yard, weeds along the fence.
	var tp := Vector3(-side * (hw - 1.4), 0, -hd + 1.6)
	if rng.randf() < 0.5:
		_dead_palm(mb, out, tp, 1.2, rng)
	else:
		_dead_tree(mb, out, tp, 4.0, rng, Color(0.36, 0.3, 0.24))
		Kit._bush(mb, tp + Vector3(side * 0.3, 2.3, 0), 0.9, rng, Color(0.38, 0.44, 0.24))
	_weeds(mb, -hw, hw, -hd + 0.4, -hd + 1.0, int(w / 2.5), rng, 0.2, 0.4)


## A three- or four-storey brick housing project round a bare courtyard
## (a U open to the street), after the big LA and Oakland projects:
## punched windows, barred on the ground floor, AC units, open concrete
## stair towers on the courtyard side, flat roofs with tarps and dishes; in
## the courtyard dirt and dry grass, paths, a play frame, laundry lines, a
## basketball hoop, benches and bins; a low chain-link fence on the street.
static func housing_project(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var hw := w * 0.5
	var hd := d * 0.5
	var floors := rng.randi_range(3, 4)
	const FH := 2.9
	var H := floors * FH + 0.3
	var bd := clampf(minf(w, d) * 0.24, 8.0, 11.0)
	var x0 := -hw + 1.0
	var x1 := hw - 1.0
	var zb1 := hd - 1.0
	var zb0 := zb1 - bd
	var zs0 := -hd + clampf(d * 0.12, 3.5, 6.0)
	var bc: Color = Kit._pick([BRICKS[0], BRICKS[2], BRICKS[4], Color(0.74, 0.62, 0.5)], rng)
	var wall := _g(bc, MeshBuilder.BRICK)
	var edge := bc.darkened(0.2)
	# Ground: a dry lawn strip on the street, dirt in the court.
	Kit._pad(mb, -hw, hw, -hd, hd, _g(DRY.darkened(0.05), MeshBuilder.GRASS))
	var cx0 := x0 + bd
	var cx1 := x1 - bd
	Kit._pad(mb, cx0, cx1, zs0, zb0, DIRT, 0.03)
	for i in int((cx1 - cx0) * (zb0 - zs0) / 40.0):
		_blot(mb, rng.randf_range(cx0 + 1.5, cx1 - 1.5), rng.randf_range(zs0 + 1.5, zb0 - 1.5), rng.randf_range(0.8, 2.2), rng.randf_range(0.6, 1.6), 0.045, _g(DRY.lerp(WEED, rng.randf() * 0.4), MeshBuilder.GRASS), 8)
	# The three blocks.
	var blocks := [[x0, x1, zb0, zb1], [x0, cx0, zs0, zb0], [cx1, x1, zs0, zb0]]
	for b in blocks:
		Kit._solid(mb, out, Vector3((b[0] + b[1]) * 0.5, H * 0.5, (b[2] + b[3]) * 0.5), Vector3(b[1] - b[0], H, b[3] - b[2]), wall)
		_shabby_roof(mb, b[0], b[1], b[2], b[3], H, edge, rng, 0.5)
		if rng.randf() < 0.6:
			Buildings._dish(mb, Vector3(lerpf(b[0] + 1.0, b[1] - 1.0, rng.randf()), H, lerpf(b[2] + 1.0, b[3] - 1.0, rng.randf())))
	# A concrete band at each floor line on the street ends.
	for b in [blocks[1], blocks[2]]:
		for f in range(1, floors):
			mb.box(Vector3((b[0] + b[1]) * 0.5, f * FH, zs0 - 0.06), Vector3(b[1] - b[0], 0.22, 0.12), _g(CONCRETE, MeshBuilder.CONCRETE))
	# Windows: every outside face, the courtyard faces, the street ends.
	const STEP := 2.6
	var ws := Vector2(1.2, 1.3)
	_face_windows(mb, Vector2(x1, zb1), Vector2(x0, zb1), Vector3.BACK, floors, FH, STEP, ws, rng)
	_face_windows(mb, Vector2(cx0, zb0), Vector2(cx1, zb0), Vector3.FORWARD, floors, FH, STEP, ws, rng)
	_face_windows(mb, Vector2(x0, zs0), Vector2(x0, zb1), Vector3.LEFT, floors, FH, STEP, ws, rng)
	_face_windows(mb, Vector2(x1, zb1), Vector2(x1, zs0), Vector3.RIGHT, floors, FH, STEP, ws, rng)
	_face_windows(mb, Vector2(cx0, zs0), Vector2(cx0, zb0), Vector3.RIGHT, floors, FH, STEP, ws, rng)
	_face_windows(mb, Vector2(cx1, zb0), Vector2(cx1, zs0), Vector3.LEFT, floors, FH, STEP, ws, rng)
	_face_windows(mb, Vector2(x0, zs0), Vector2(cx0, zs0), Vector3.FORWARD, floors, FH, STEP, ws, rng)
	_face_windows(mb, Vector2(cx1, zs0), Vector2(x1, zs0), Vector3.FORWARD, floors, FH, STEP, ws, rng)
	# Open stair towers on the courtyard side.
	var span := cx1 - cx0
	for t: float in [0.25, 0.75]:
		_stair_core(mb, out, Vector3(lerpf(cx0, cx1, t), 0, zb0), Vector3.FORWARD, floors, FH)
	_stair_core(mb, out, Vector3(cx0, 0, lerpf(zs0, zb0, 0.45)), Vector3.RIGHT, floors, FH)
	_stair_core(mb, out, Vector3(cx1, 0, lerpf(zs0, zb0, 0.55)), Vector3.LEFT, floors, FH)
	# Tags on the street ends and outside walls at ground level.
	for b in [blocks[1], blocks[2]]:
		_tag(mb, Vector3(lerpf(b[0], b[1], rng.randf_range(0.3, 0.7)), 1.25, zs0), Vector3.RIGHT, Vector3.FORWARD, rng.randf_range(2.0, 3.0), 0.9, rng)
	_tag(mb, Vector3(x0, 1.3, lerpf(zs0, zb1, rng.randf())), Vector3.BACK, Vector3.LEFT, 3.0, 1.0, rng)
	_tag(mb, Vector3(x1, 1.3, lerpf(zs0, zb1, rng.randf())), Vector3.FORWARD, Vector3.RIGHT, 3.0, 1.0, rng)
	# Courtyard paths.
	var path := _g(Color(0.68, 0.67, 0.63), MeshBuilder.CONCRETE)
	var mid_x := (cx0 + cx1) * 0.5
	Kit._pad(mb, mid_x - 0.8, mid_x + 0.8, -hd, zb0, path, 0.06)
	Kit._pad(mb, cx0, cx1, lerpf(zs0, zb0, 0.5) - 0.7, lerpf(zs0, zb0, 0.5) + 0.7, path, 0.065)
	_cracks(mb, mid_x - 0.8, mid_x + 0.8, zs0, zb0, 3, rng, 0.075)
	# Play frame, laundry lines, a hoop, benches, bins.
	var court_d := zb0 - zs0
	_play_frame(mb, out, Vector3(lerpf(cx0, cx1, 0.25) - 1.0, 0, lerpf(zs0, zb0, 0.25)), rng)
	var lz := lerpf(zs0, zb0, 0.78) - 1.0
	for k in 2:
		var z := lz + k * 1.4
		_laundry(mb, out, Vector3(mid_x + 1.6, 0, z), Vector3(mid_x + minf(span * 0.38, 8.5), 0, z), rng)
	_hoop(mb, out, Vector3(cx1 - 1.5, 0, lerpf(zs0, zb0, 0.22)), Vector3.LEFT)
	_blot(mb, cx1 - 4.5, lerpf(zs0, zb0, 0.22), 2.4, 2.0, 0.05, _g(Color(0.5, 0.49, 0.47), MeshBuilder.ASPHALT), 10)
	for k in 2:
		var bp := Vector3(mid_x - 2.4 - k * 2.6, 0, lerpf(zs0, zb0, 0.5) + 1.5)
		if k == 0:
			Kit._solid(mb, out, bp + Vector3(0, 0.25, 0), Vector3(1.8, 0.5, 0.5), _g(CONCRETE, MeshBuilder.CONCRETE))
		else:
			mb.box(bp + Vector3(0, 0.25, 0), Vector3(1.8, 0.5, 0.5), _g(CONCRETE, MeshBuilder.CONCRETE))
	for k in 4:
		_bin(mb, Vector3(mid_x + 1.4 + k * 0.75, 0, zs0 + 0.6), 0.0, [Color(0.15, 0.15, 0.16), Color(0.15, 0.4, 0.2), Color(0.2, 0.3, 0.6)][k % 3])
	_dead_tree(mb, out, Vector3(lerpf(cx0, cx1, 0.7), 0, lerpf(zs0, zb0, 0.42)), 5.0, rng)
	_mattress(mb, Vector3(cx0 + 4.0, 0, zb0 - 2.0), rng.randf_range(0, TAU), rng)
	_cart(mb, out, Vector3(cx1 - 4.0, 0, zs0 + 2.0), rng.randf_range(0, TAU), rng)
	_bags(mb, Vector3(mid_x + 2.5, 0, zs0 + 1.4), 3, rng, 0.4)
	_weeds(mb, cx0 + 0.4, cx1 - 0.4, zs0 + 0.4, zb0 - 0.4, int(span * court_d / 25.0), rng)
	# The street side: a low chain-link fence with the gate on the path, a
	# blank estate sign, weeds on the dry lawn.
	_chainlink_x(mb, out, -hw + 0.3, hw - 0.3, -hd + 0.4, 1.4, [[mid_x - 1.0, mid_x + 1.0]], rng, false, 2)
	var sgp := Vector3(mid_x + 3.0, 0, -hd + 1.4)
	for s: float in [-1.0, 1.0]:
		mb.box(sgp + Vector3(s * 1.1, 0.7, 0), Vector3(0.14, 1.4, 0.14), _g(STEEL, MeshBuilder.METAL))
	mb.box(sgp + Vector3(0, 1.55, 0), Vector3(2.6, 1.0, 0.1), Color(0.18, 0.32, 0.5))
	_glyphs(mb, sgp + Vector3(0, 1.55, -0.07), Vector3.RIGHT, Vector3.FORWARD, 2.0, 0.4, Color(0.92, 0.92, 0.88), rng)
	out.append([sgp + Vector3(0, 1.0, 0), Vector3(2.6, 2.0, 0.3)])
	_weeds(mb, -hw, hw, -hd + 0.7, zs0 - 0.2, int(w / 3.0), rng)


## An open concrete stair tower against a wall facing n: base is its foot
## at the middle of the wall face; two fins out 2.6 m, a landing and a
## railing at each floor, flights between, a cap on top. Collides.
static func _stair_core(mb, out: Array, base: Vector3, n: Vector3, floors: int, fh: float) -> void:
	var u := Vector3(-n.z, 0, n.x)
	const W := 3.0
	const D := 2.6
	var top := floors * fh + 0.3
	var conc := _g(Color(0.72, 0.7, 0.66), MeshBuilder.CONCRETE)
	var rail := _g(Color(0.25, 0.3, 0.32), MeshBuilder.GLOSS)
	for s: float in [-1.0, 1.0]:
		mb.box(base + u * s * (W * 0.5 - 0.12) + n * D * 0.5 + Vector3(0, top * 0.5, 0), u.abs() * 0.24 + Vector3(0, top, 0) + n.abs() * D, conc)
	mb.box(base + n * D * 0.5 + Vector3(0, top + 0.1, 0), u.abs() * W + Vector3(0, 0.2, 0) + n.abs() * D, conc)
	for f in range(1, floors):
		var y := f * fh
		mb.box(base + n * 0.6 + Vector3(0, y - 0.1, 0), u.abs() * (W - 0.48) + Vector3(0, 0.2, 0) + n.abs() * 1.2, conc)
		var ro := base + n * D + Vector3(0, y, 0)
		_stroke(mb, ro, u, n, Vector2(-W * 0.5 + 0.24, 1.0), Vector2(W * 0.5 - 0.24, 1.0), 0.07, rail)
		for k in 6:
			var s := lerpf(-W * 0.5 + 0.3, W * 0.5 - 0.3, k / 5.0)
			_stroke(mb, ro, u, n, Vector2(s, 0.0), Vector2(s, 1.0), 0.04, rail)
	for f in floors - 1:
		var dir := 1.0 if f % 2 == 0 else -1.0
		var a := base + n * 1.9 + u * (-dir * (W * 0.5 - 0.4)) + Vector3(0, f * fh + 0.05, 0)
		var b := base + n * 1.9 + u * (dir * (W * 0.5 - 0.4)) + Vector3(0, (f + 1) * fh, 0)
		var sn := (b - a).cross(n).normalized()
		if sn.y < 0.0:
			sn = -sn
		mb.quad(a - n * 0.55, a + n * 0.55, b + n * 0.55, b - n * 0.55, sn, conc.darkened(0.12))
	Kit._col(out, base + n * D * 0.5 + Vector3(0, top * 0.5, 0), u.abs() * W + Vector3(0, top, 0) + n.abs() * D)


## A steel climbing frame with a platform and a slide (to +X), faded paint.
static func _play_frame(mb, out: Array, p: Vector3, rng: RandomNumberGenerator) -> void:
	var paint: Color = (Kit._pick([Color(0.75, 0.25, 0.2), Color(0.2, 0.4, 0.7), Color(0.85, 0.7, 0.2), Color(0.3, 0.55, 0.35)], rng) as Color).lerp(Color(0.55, 0.5, 0.45), 0.35)
	var steel := _g(paint, MeshBuilder.GLOSS)
	const W := 3.0
	const D := 1.8
	const H := 2.2
	for x: float in [-W * 0.5, W * 0.5]:
		for z: float in [-D * 0.5, D * 0.5]:
			mb.cylinder(p + Vector3(x, 0, z), 0.07, H, steel, 5)
	for z: float in [-D * 0.5, D * 0.5]:
		Kit._beam(mb, p + Vector3(-W * 0.5, H, z), p + Vector3(W * 0.5, H, z), 0.08, steel)
	for k in 6:
		var x := lerpf(-W * 0.5 + 0.2, W * 0.5 - 0.2, k / 5.0)
		Kit._beam(mb, p + Vector3(x, H, -D * 0.5), p + Vector3(x, H, D * 0.5), 0.05, steel)
	mb.box(p + Vector3(W * 0.25, 1.1, 0), Vector3(W * 0.5, 0.08, D), Color(0.55, 0.45, 0.32))
	var slide := _g((Kit._pick([Color(0.9, 0.75, 0.2), Color(0.25, 0.55, 0.85), Color(0.85, 0.3, 0.25)], rng) as Color).lerp(Color(0.6, 0.58, 0.55), 0.3), MeshBuilder.GLOSS)
	var s0 := p + Vector3(W * 0.5, 1.1, 0)
	var s1 := p + Vector3(W * 0.5 + 2.0, 0.15, 0)
	var sn := Vector3(1.1 - 0.15, 2.0, 0).normalized()
	mb.quad(s0 + Vector3(0, 0.02, -0.35), s1 + Vector3(0, 0.02, -0.35), s1 + Vector3(0, 0.02, 0.35), s0 + Vector3(0, 0.02, 0.35), sn, slide)
	for z: float in [-0.38, 0.38]:
		Kit._beam(mb, s0 + Vector3(0, 0.15, z), s1 + Vector3(0, 0.15, z), 0.06, slide)
	out.append([p + Vector3(0.9, 1.1, 0), Vector3(W + 1.8, 2.2, D)])


## A laundry line between two T-posts from a to b (along X or Z): two
## wires with clothes pegged on them, plain colour panels.
static func _laundry(mb, out: Array, a: Vector3, b: Vector3, rng: RandomNumberGenerator) -> void:
	var post := _g(Color(0.55, 0.56, 0.58), MeshBuilder.METAL)
	var along := (b - a).normalized()
	var across := Vector3(-along.z, 0, along.x)
	for p: Vector3 in [a, b]:
		mb.box(p + Vector3(0, 1.1, 0), Vector3(0.12, 2.2, 0.12), post)
		Kit._beam(mb, p + Vector3(0, 2.15, 0) - across * 0.6, p + Vector3(0, 2.15, 0) + across * 0.6, 0.08, post)
		out.append([p + Vector3(0, 1.0, 0), Vector3(0.2, 2.0, 0.2)])
	var count := maxi(1, int(a.distance_to(b) / 0.9))
	for s: float in [-0.45, 0.45]:
		Kit._beam(mb, a + across * s + Vector3(0, 2.1, 0), b + across * s + Vector3(0, 2.1, 0), 0.025, Color(0.85, 0.85, 0.85))
		for i in count:
			if rng.randf() < 0.3:
				continue
			var c := a.lerp(b, (i + 0.5) / count) + across * s
			var cw := rng.randf_range(0.4, 0.7)
			var ch := rng.randf_range(0.5, 0.9)
			mb.box(c + Vector3(0, 2.08 - ch * 0.5, 0), along.abs() * cw + Vector3(0, ch, 0) + across.abs() * 0.03, Kit._pick(CLOTHES, rng))


## A basketball hoop: a pole at p, the backboard and rim reaching toward n.
static func _hoop(mb, out: Array, p: Vector3, n: Vector3) -> void:
	var steel := _g(Color(0.45, 0.47, 0.5), MeshBuilder.METAL)
	var u := Vector3(-n.z, 0, n.x)
	mb.box(p + Vector3(0, 1.6, 0), Vector3(0.16, 3.2, 0.16), steel)
	Kit._beam(mb, p + Vector3(0, 3.0, 0), p + n * 0.9 + Vector3(0, 3.0, 0), 0.1, steel)
	var bc := p + n * 0.9 + Vector3(0, 3.35, 0)
	mb.box(bc, u.abs() * 1.6 + Vector3(0, 1.0, 0) + n.abs() * 0.05, Color(0.88, 0.88, 0.86))
	var rim := bc + n * 0.3 + Vector3(0, -0.3, 0)
	var orange := _g(Color(0.9, 0.4, 0.15), MeshBuilder.GLOSS)
	for i in 8:
		var a0 := TAU * i / 8.0
		var a1 := TAU * (i + 1) / 8.0
		_stroke(mb, rim, Vector3.RIGHT, Vector3.UP, Vector2(cos(a0), sin(a0)) * 0.23, Vector2(cos(a1), sin(a1)) * 0.23, 0.04, orange, Vector3.BACK)
	out.append([p + Vector3(0, 1.5, 0), Vector3(0.3, 3.0, 0.3)])


## A sidewalk encampment along the front strip (after Skid Row and the
## Oakland underpasses): a blank warehouse wall at the back with a shut
## roll door, high barred windows and tags; in front of it a row of dome
## tents, tarp lean-tos and cardboard, with shopping carts, crates, bags,
## a mattress or two, buckets, an umbrella. A walkway stays clear at the kerb.
static func tent_row(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var hw := w * 0.5
	var hd := d * 0.5
	var wt := clampf(d * 0.12, 0.45, 0.8)
	var wz := hd - wt * 0.5
	var face := hd - wt
	var wh := rng.randf_range(5.5, 7.0)
	var brick := rng.randf() < 0.5
	var wc: Color = Kit._pick(BRICKS, rng) if brick else Color(0.7, 0.68, 0.62)
	var wall := _g(wc, MeshBuilder.BRICK if brick else MeshBuilder.CONCRETE)
	Kit._pad(mb, -hw, hw, -hd, face, _g(SIDEWALK, MeshBuilder.CONCRETE))
	_cracks(mb, -hw, hw, -hd, face, int(w / 3.0), rng, 0.04)
	_stains(mb, -hw, hw, -hd, face, int(w / 5.0), rng, 0.035)
	# The warehouse wall.
	Kit._solid(mb, out, Vector3(0, wh * 0.5, wz), Vector3(w, wh, wt), wall)
	mb.box(Vector3(0, wh + 0.1, wz), Vector3(w, 0.2, wt), _g(wc.darkened(0.25), MeshBuilder.CONCRETE))
	_win_row(mb, Vector3(-hw + 2.0, wh - 1.4, face), Vector3(hw - 2.0, wh - 1.4, face), Vector3.FORWARD, maxi(1, int(w / 5.0)), Vector2(1.6, 0.9), rng, [0.2, 0.5, 0.1, 0.2, 0.0])
	var door_x := rng.randf_range(-hw * 0.6, hw * 0.6)
	_shutter(mb, Vector3(door_x, 0, face), Vector3.RIGHT, Vector3.FORWARD, 3.6, 3.8, 0.0, rng)
	mb.box(Vector3(-door_x * 0.5 + hw * 0.4, wh * 0.5, face - 0.08), Vector3(0.16, wh, 0.16), _g(Color(0.4, 0.42, 0.44), MeshBuilder.METAL))
	var x := -hw + 2.0
	while x < hw - 2.0:
		if absf(x - door_x) > 2.4:
			_tag(mb, Vector3(x, rng.randf_range(2.3, 2.9), face), Vector3.RIGHT, Vector3.FORWARD, rng.randf_range(2.0, 3.4), 1.1, rng)
		x += rng.randf_range(3.5, 5.0)
	# The camp, in slots along the wall.
	var depth := minf(d - wt - 1.4, 3.2)
	var zc := face - depth * 0.5
	x = -hw + 0.4
	var slot := 0
	while x < hw - 1.4:
		var sw := rng.randf_range(2.2, 3.6)
		if x + sw > hw - 0.3:
			sw = hw - 0.3 - x
			if sw < 1.4:
				break
		var cx := x + sw * 0.5
		if absf(cx - door_x) < 1.6 + sw * 0.5:
			x = door_x + 2.0
			continue
		var kind := rng.randi() % 4 if slot > 0 else 0
		match kind:
			0, 3: # a dome tent, sometimes under a thrown tarp, with things in front
				var rx := minf(sw * 0.4, 1.3)
				var rz := minf(depth * 0.4, 1.1)
				var h := rng.randf_range(1.05, 1.4)
				var yaw := rng.randf_range(-0.2, 0.2)
				_tent(mb, out, Vector3(cx, 0, face - 0.2 - rz), yaw, rx, rz, h, Kit._pick(TENTS, rng), Kit._pick(TENTS, rng))
				if kind == 3:
					_rbox(mb, Vector3(cx, h * 0.8, face - 0.2 - rz), Vector3(rx * 1.5, 0.02, rz * 1.3), yaw + 0.3, Kit._pick(TARPS, rng))
				var front := face - 0.2 - rz * 2.0 - 0.3
				if front > face - depth:
					_bags(mb, Vector3(cx + rng.randf_range(-0.5, 0.5), 0, front), 2, rng, 0.2)
			1: # a tarp lean-to off the wall over a mattress and bags
				var tw := sw - 0.2
				_tarp(mb, Vector3(cx, 0, face - depth * 0.5), 0.0, tw, depth, 2.1, 1.15, Kit._pick(TARPS, rng))
				if tw >= 2.1 and depth >= 1.6:
					_mattress(mb, Vector3(cx, 0, face - depth * 0.5), PI * 0.5 + rng.randf_range(-0.1, 0.1), rng)
				else:
					_cardboard(mb, Vector3(cx, 0, face - depth * 0.5), rng)
				_bags(mb, Vector3(cx + tw * 0.3, 0, face - 0.5), 2, rng, 0.15)
				Kit._col(out, Vector3(cx, 0.75, face - depth * 0.5), Vector3(tw, 1.5, depth))
			_: # cardboard, crates and a loaded cart
				_cardboard(mb, Vector3(cx - sw * 0.15, 0, face - 0.9), rng)
				_crate(mb, Vector3(cx + sw * 0.25, 0, face - 0.5), 0.45, rng.randf_range(-0.3, 0.3), Kit._pick([Color(0.2, 0.35, 0.65), Color(0.75, 0.2, 0.2), Color(0.85, 0.7, 0.2)], rng))
				_crate(mb, Vector3(cx + sw * 0.25, 0.45, face - 0.5), 0.45, rng.randf_range(-0.3, 0.3), Kit._pick([Color(0.2, 0.35, 0.65), Color(0.3, 0.55, 0.3)], rng))
				Kit._col(out, Vector3(cx, 0.45, face - 0.9), Vector3(sw - 0.4, 0.9, 1.6))
		# Carts and odds and ends at the front of the camp.
		if rng.randf() < 0.55 and depth >= 2.4:
			_cart(mb, out, Vector3(cx + rng.randf_range(-0.6, 0.6), 0, face - depth + 0.45), PI * 0.5 + rng.randf_range(-0.4, 0.4), rng)
		elif rng.randf() < 0.4:
			mb.cylinder(Vector3(cx + rng.randf_range(-0.5, 0.5), 0, face - depth + 0.4), 0.17, 0.42, _g(Kit._pick([Color(0.9, 0.5, 0.15), Color(0.9, 0.9, 0.88), Color(0.2, 0.4, 0.75)], rng), MeshBuilder.GLOSS), 6)
		x += sw + rng.randf_range(0.1, 0.5)
		slot += 1
	# An umbrella over one spot, a heap of bags at one end.
	var ux := rng.randf_range(-hw + 3.0, hw - 3.0)
	mb.cylinder(Vector3(ux, 0, face - 0.4), 0.03, 2.0, Color(0.5, 0.5, 0.5), 4)
	mb.ball(Vector3(ux, 2.0, face - 0.4), Vector3(1.0, 0.3, 1.0), Kit._pick(TENTS, rng), 8, 2)
	_bags(mb, Vector3(hw - 1.0, 0, -hd + 1.0 + minf(1.0, d * 0.1)), 3, rng, 0.3)


## A burned lot: the foundation slab of a house that burned, stub walls
## and a standing brick chimney, charred timber and ash; rubble heaps,
## a burnt-out car, tyres and trash, weeds and dry grass, a broken
## chain-link fence with a panel lying in the dirt, a charred tree.
static func burned_lot(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var hw := w * 0.5
	var hd := d * 0.5
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	Kit._pad(mb, -hw, hw, -hd, hd, DIRT)
	for i in rng.randi_range(4, 6):
		var bx := rng.randf_range(-hw + 1.5, hw - 1.5)
		var bz := rng.randf_range(-hd + 1.5, hd - 1.5)
		_blot(mb, bx, bz, minf(rng.randf_range(1.0, 2.2), hw - absf(bx) - 0.05), minf(rng.randf_range(0.8, 1.8), hd - absf(bz) - 0.05), 0.035, _g(DRY, MeshBuilder.GRASS), 8)
	# The slab, ash, stub walls and the chimney.
	var fw := clampf(w * 0.5, 5.5, 11.0)
	var fd := clampf(d * 0.45, 5.5, 10.0)
	var fx := side * clampf(hw - fw * 0.5 - 1.5, 0.0, 2.0)
	var fzc := hd - 1.2 - fd * 0.5
	var conc := _g(Color(0.6, 0.58, 0.54), MeshBuilder.CONCRETE)
	_blot(mb, fx, fzc, fw * 0.62, fd * 0.62, 0.045, ASH, 10)
	mb.box(Vector3(fx, 0.2, fzc), Vector3(fw, 0.4, fd), conc)
	mb.box(Vector3(fx, 0.41, fzc), Vector3(fw - 0.4, 0.02, fd - 0.4), ASH)
	var charred := [SOOT, Color(0.18, 0.15, 0.13), Color(0.3, 0.24, 0.2)]
	var edges := [
		[Vector3(fx - fw * 0.5, 0, fzc - fd * 0.5), Vector3(fx + fw * 0.5, 0, fzc - fd * 0.5)],
		[Vector3(fx - fw * 0.5, 0, fzc + fd * 0.5), Vector3(fx + fw * 0.5, 0, fzc + fd * 0.5)],
		[Vector3(fx - fw * 0.5, 0, fzc - fd * 0.5), Vector3(fx - fw * 0.5, 0, fzc + fd * 0.5)],
		[Vector3(fx + fw * 0.5, 0, fzc - fd * 0.5), Vector3(fx + fw * 0.5, 0, fzc + fd * 0.5)],
	]
	for e in edges:
		var a: Vector3 = e[0]
		var b: Vector3 = e[1]
		var along := (b - a).normalized()
		var length := a.distance_to(b)
		var inward := Vector3(fx, 0, fzc) - (a + b) * 0.5
		inward = Vector3(inward.x, 0, inward.z).normalized() * 0.15
		var pieces := maxi(2, int(length / 1.6))
		var tallest := 0.0
		for i in pieces:
			if rng.randf() < 0.35:
				continue
			var ph := rng.randf_range(0.2, 1.6)
			tallest = maxf(tallest, ph)
			var pc := a.lerp(b, (i + 0.5) / pieces) + inward + Vector3(0, 0.4 + ph * 0.5, 0)
			mb.box(pc, along.abs() * (length / pieces - 0.15) + Vector3(0, ph, 0) + Vector3(absf(along.z), 0, absf(along.x)) * 0.25, Kit._pick(charred, rng))
		if tallest > 0.5:
			Kit._col(out, (a + b) * 0.5 + inward + Vector3(0, 0.4 + tallest * 0.5, 0), along.abs() * length + Vector3(0, tallest, 0) + Vector3(absf(along.z), 0, absf(along.x)) * 0.3)
	var chp := Vector3(fx - side * (fw * 0.5 - 0.8), 0, fzc + fd * 0.5 - 0.7)
	var chh := rng.randf_range(4.5, 6.0)
	Kit._solid(mb, out, chp + Vector3(0, chh * 0.5, 0), Vector3(1.2, chh, 0.9), _g(Kit._pick(BRICKS, rng), MeshBuilder.BRICK))
	mb.box(chp + Vector3(0, chh - 0.6, 0), Vector3(1.22, 1.2, 0.92), SOOT.lerp(Color(0.3, 0.2, 0.15), 0.3))
	mb.box(chp + Vector3(0, 1.3, -0.46), Vector3(0.7, 0.8, 0.02), SOOT)
	for i in rng.randi_range(5, 8):
		var bl := rng.randf_range(1.6, minf(4.0, fw - 1.0))
		var bp := Vector3(fx + rng.randf_range(-fw * 0.3, fw * 0.3), 0.52 + (i % 3) * 0.12, fzc + rng.randf_range(-fd * 0.3, fd * 0.3))
		_rbox(mb, bp, Vector3(bl, 0.2, 0.22), rng.randf() * PI, Kit._pick(charred, rng))
	for i in 3:
		var hp := Vector3(fx + rng.randf_range(-fw * 0.3, fw * 0.3), 0.4, fzc + rng.randf_range(-fd * 0.3, fd * 0.3))
		mb.clump(hp + Vector3(0, 0.15, 0), Vector3(0.9, 0.45, 0.8), Color(0.16, 0.15, 0.14), rng.randi(), 6, 3, 0.35)
	mb.cylinder(Vector3(fx + side * fw * 0.25, 0.4, fzc - fd * 0.2), 0.3, 1.5, _g(Color(0.55, 0.5, 0.45).lerp(RUST, 0.4), MeshBuilder.METAL), 8)
	# Rubble at the front, a burnt car, trash.
	for i in 2:
		var rp := Vector3(rng.randf_range(-hw + 3.0, hw - 3.0), 0, rng.randf_range(-hd + 3.5, fzc - fd * 0.5 - 2.0))
		Kit._cone(mb, rp, rng.randf_range(1.2, 1.8), rng.randf_range(0.6, 1.0), _g(Color(0.5, 0.46, 0.42), MeshBuilder.CONCRETE), 7)
		for k in 5:
			_rbox(mb, rp + Vector3(rng.randf_range(-1.0, 1.0), 0.2, rng.randf_range(-1.0, 1.0)), Vector3(rng.randf_range(0.3, 0.7), 0.3, rng.randf_range(0.3, 0.6)), rng.randf() * TAU, _g(Kit._pick(BRICKS + [CONCRETE], rng), MeshBuilder.CONCRETE))
	if w >= 7.0:
		_burnt_car(mb, out, Vector3(-side * (hw - 2.6), 0, -hd + 3.6), side * rng.randf_range(0.0, 0.25), rng)
	_tyres(mb, out, Vector3(side * (hw - 1.4), 0, -hd + 2.0), 2)
	_tyres(mb, [], Vector3(side * (hw - 2.2), 0, -hd + 1.8), 1, false)
	_mattress(mb, Vector3(rng.randf_range(-1.5, 1.5), 0, -hd + 2.6), rng.randf_range(-0.8, 0.8), rng)
	_bags(mb, Vector3(side * (hw - 2.0), 0, -hd + 4.4), 3, rng, 0.4)
	_cart(mb, out, Vector3(side * (hw - 3.2), 0, fzc - fd * 0.5 - 1.2), rng.randf() * TAU, rng, false)
	# Fence: chain-link on the street with a torn bay and a panel down, one side run.
	var gx := rng.randf_range(-hw * 0.3, hw * 0.3)
	_chainlink_x(mb, out, -hw + 0.2, hw - 0.2, -hd + 0.25, 1.8, [[gx - 1.4, gx + 1.4]], rng, false, 2)
	var fallen := Vector3(gx, 0.06, -hd + 1.25)
	for j in 4:
		var s0 := -1.2 + j * 0.6
		_stroke(mb, fallen, Vector3.RIGHT, Vector3.UP, Vector2(s0, -0.85), Vector2(s0 + 0.6, 0.85), 0.05, Color(0.55, 0.57, 0.58), Vector3.BACK)
		_stroke(mb, fallen, Vector3.RIGHT, Vector3.UP, Vector2(s0 + 0.6, -0.85), Vector2(s0, 0.85), 0.05, Color(0.55, 0.57, 0.58), Vector3.BACK)
	_chainlink(mb, out, Vector3(side * (hw - 0.2), 0, -hd + 0.4), Vector3(side * (hw - 0.2), 0, hd - 0.3), 1.8, rng, false, true, 2)
	# A charred tree and weeds everywhere.
	_dead_tree(mb, out, Vector3(-side * (hw - 1.8), 0, hd - 2.0), 5.0, rng, Color(0.12, 0.11, 0.1))
	_weeds(mb, -hw, hw, -hd, hd, int(w * d / 10.0), rng, 0.2, 0.55)


## A freeway underpass: a concrete deck about 6 m up across the whole lot
## on two bents of round columns, girders under it and a fascia toward the
## street covered in big tags, a sloped abutment at the back with a tag on
## it and a chain-link fence along its foot; under the deck cardboard,
## tents, mattresses and carts, lit by sodium lamps; lanes and barriers on
## top.
static func underpass(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var hw := w * 0.5
	var hd := d * 0.5
	const TOP := 6.4
	const SLAB := 0.7
	const GIRDER := 0.9
	var yb := TOP - SLAB - GIRDER
	var zd0 := -hd + clampf(d * 0.1, 1.0, 2.0)
	var zd1 := hd - 0.1
	var zs0 := hd - clampf(d * 0.32, 3.0, 5.0)
	var conc := _g(Color(0.68, 0.67, 0.63), MeshBuilder.CONCRETE)
	var dark_conc := _g(Color(0.52, 0.51, 0.48), MeshBuilder.CONCRETE)
	Kit._pad(mb, -hw, hw, -hd, hd, _g(Color(0.55, 0.54, 0.5), MeshBuilder.CONCRETE))
	Kit._pad(mb, -hw, hw, zs0 - 1.4, zs0, DIRT, 0.03)
	_cracks(mb, -hw, hw, -hd, zs0 - 1.4, int(w / 3.0), rng, 0.04)
	_stains(mb, -hw, hw, -hd, zs0 - 1.4, int(w / 4.0), rng, 0.035)
	# Deck, girders and the fascia.
	mb.box(Vector3(0, TOP - SLAB * 0.5, (zd0 + zd1) * 0.5), Vector3(w, SLAB, zd1 - zd0), conc)
	mb.box(Vector3(0, yb + GIRDER * 0.5, zd0 + 0.2), Vector3(w, GIRDER, 0.4), conc)
	var ng := maxi(3, int((zd1 - zd0) / 3.0))
	for i in range(1, ng):
		var z := lerpf(zd0 + 0.2, zd1 - 0.5, float(i) / (ng - 1))
		mb.box(Vector3(0, yb + GIRDER * 0.5, z), Vector3(w, GIRDER, 0.5), dark_conc)
	mb.box(Vector3(0, TOP + 0.02, (zd0 + zd1) * 0.5), Vector3(w, 0.04, zd1 - zd0 - 1.2), _g(ASPHALT, MeshBuilder.ASPHALT))
	var lanes := maxi(2, int((zd1 - zd0 - 1.2) / 3.6))
	for k in range(1, lanes):
		var z := lerpf(zd0 + 0.6, zd1 - 0.6, float(k) / lanes)
		var x := -hw + 0.5
		while x < hw - 0.5:
			_strip(mb, Vector2(x, z), Vector2(minf(x + 3.0, hw - 0.1), z), 0.14, TOP + 0.05, Color(0.85, 0.84, 0.78))
			x += 9.0
	for z: float in [zd0 + 0.3, zd1 - 0.3]:
		mb.box(Vector3(0, TOP + 0.4, z), Vector3(w, 0.8, 0.5), conc)
	for i in maxi(1, int(w / 7.0)):
		var tx := lerpf(-hw + 3.0, hw - 3.0, (i + 0.5) / maxi(1, int(w / 7.0)))
		_tag(mb, Vector3(tx + rng.randf_range(-0.8, 0.8), (yb + TOP - SLAB) * 0.5 + 0.35, zd0 - 0.01), Vector3.RIGHT, Vector3.FORWARD, rng.randf_range(3.5, 5.5), 1.0, rng)
	# Sodium lamps under the deck.
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(s * hw * 0.25, yb - 0.12, zd0 + 1.4), Vector3(0.6, 0.2, 0.4), _g(Color(1.0, 0.62, 0.28), MeshBuilder.GLOW_LAMP))
	# Bents: cap beams on round columns, tags on the columns.
	var bx := clampf(hw * 0.55, 3.0, hw - 1.5)
	for s: float in [-1.0, 1.0]:
		var x := s * bx
		mb.box(Vector3(x, yb - 0.45, (zd0 + zd1) * 0.5 + 0.2), Vector3(1.1, 0.9, zd1 - zd0 - 1.4), conc)
		var nc := 2 if (zd1 - zd0) < 11.0 else 3
		for k in nc:
			var z := lerpf(zd0 + 1.6, zd1 - 1.4, float(k) / (nc - 1))
			mb.cylinder(Vector3(x, 0, z), 0.55, yb - 0.9, conc, 10)
			out.append([Vector3(x, 1.5, z), Vector3(1.1, 3.0, 1.1)])
			if z < zs0 and rng.randf() < 0.7:
				_tag(mb, Vector3(x, 1.8, z - 0.56), Vector3.RIGHT, Vector3.FORWARD, 0.95, 0.9, rng)
	# The sloped abutment at the back, with a tag and a fence at its foot.
	var sv := Vector3(0, yb, zd1 - zs0).normalized()
	var slope_n := Vector3(0, zd1 - zs0, -yb).normalized()
	mb.quad(Vector3(-hw, 0.05, zs0), Vector3(hw, 0.05, zs0), Vector3(hw, yb, zd1), Vector3(-hw, yb, zd1), slope_n, conc)
	for s: float in [-1.0, 1.0]:
		mb.tri(Vector3(s * hw, 0, zs0), Vector3(s * hw, yb, zd1), Vector3(s * hw, 0, zd1), Vector3(s, 0, 0), dark_conc)
	Kit._col(out, Vector3(0, 1.0, (zs0 + zd1) * 0.5 + 0.6), Vector3(w, 2.0, maxf(zd1 - zs0 - 1.2, 0.5)))
	var sl := Vector3(0, 0, zs0).lerp(Vector3(0, yb, zd1), 0.45) + slope_n * 0.01
	_tag(mb, sl + Vector3(rng.randf_range(-hw * 0.3, hw * 0.3), 0, 0), Vector3.RIGHT, slope_n, minf(w * 0.3, 5.0), 1.4, rng, sv)
	_chainlink(mb, out, Vector3(-hw + 0.2, 0, zs0 - 0.25), Vector3(hw - 0.2, 0, zs0 - 0.25), 1.8, rng, false, true, 2)
	# The camp under the deck, in the strip before the fence.
	var z0 := zd0 + 0.8
	var z1 := zs0 - 0.7
	var zc := (z0 + z1) * 0.5
	var slots := [[-hw + 0.8, -bx - 0.9], [-bx + 0.9, bx - 0.9], [bx + 0.9, hw - 0.8]]
	for sp in slots:
		var a: float = sp[0]
		var b: float = sp[1]
		if b - a < 1.6:
			continue
		var m := (a + b) * 0.5
		match rng.randi() % 3:
			0:
				var rx := minf((b - a) * 0.35, 1.3)
				var rz := minf((z1 - z0) * 0.4, 1.1)
				_tent(mb, out, Vector3(m, 0, zc), rng.randf_range(-0.3, 0.3), rx, rz, rng.randf_range(1.1, 1.4), Kit._pick(TENTS, rng), Kit._pick(TENTS, rng))
			1:
				if (b - a) >= 2.4 and (z1 - z0) >= 1.6:
					_mattress(mb, Vector3(m, 0, zc), PI * 0.5 + rng.randf_range(-0.2, 0.2), rng)
				else:
					_cardboard(mb, Vector3(m, 0, zc), rng)
				_bags(mb, Vector3(m + (b - a) * 0.3, 0, zc), 2, rng, 0.2)
			_:
				_cardboard(mb, Vector3(m, 0, zc), rng)
				if b - a >= 2.4:
					_cart(mb, out, Vector3(m + (b - a) * 0.28, 0, zc), rng.randf() * TAU, rng)
	_bags(mb, Vector3(rng.randf_range(-hw + 2.0, hw - 2.0), 0, -hd + 0.9), 2, rng, 0.3)
	_weeds(mb, -hw, hw, zs0 - 1.3, zs0 - 0.4, int(w / 3.0), rng)


# --- Props -------------------------------------------------------------------------

## A free-standing block wall (length w, up to 12 m) covered in abstract
## tags on both faces, piers along it, weeds at its foot.
static func graffiti_wall(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var length := clampf(w - 0.2, 1.0, 12.0)
	var t := minf(0.3, d * 0.4)
	var h := rng.randf_range(2.4, 3.0)
	var block := rng.randf() < 0.6
	var wc: Color = Kit._pick([Color(0.66, 0.65, 0.62), Color(0.72, 0.66, 0.56), Color(0.58, 0.6, 0.62)], rng) if block else Kit._pick(BRICKS, rng)
	Kit._solid(mb, out, Vector3(0, h * 0.5, 0), Vector3(length, h, t), _g(wc, MeshBuilder.CONCRETE if block else MeshBuilder.BRICK))
	mb.box(Vector3(0, h + 0.05, 0), Vector3(length + 0.06, 0.1, t + 0.06), wc.darkened(0.2))
	var np := maxi(1, int(length / 2.6))
	for i in np + 1:
		var px := clampf(-length * 0.5 + length * i / np, -length * 0.5 + 0.17, length * 0.5 - 0.17)
		mb.box(Vector3(px, h * 0.5, 0), Vector3(0.34, h, t + 0.1), wc.darkened(0.08))
	var x := -length * 0.5 + 0.3
	while x < length * 0.5 - 1.0:
		var tw := minf(rng.randf_range(1.6, 3.0), length * 0.5 - 0.2 - x)
		var th := rng.randf_range(0.9, minf(1.5, h - 1.3))
		_tag(mb, Vector3(x + tw * 0.5, rng.randf_range(maxf(1.25, th * 0.35 + 0.55), h - th * 0.5 - 0.15), -t * 0.5 - 0.05), Vector3.RIGHT, Vector3.FORWARD, tw, th, rng)
		x += tw * rng.randf_range(0.7, 1.05)
	for i in rng.randi_range(1, 2):
		var tw := minf(rng.randf_range(1.8, 3.0), length - 0.6)
		var tx := rng.randf_range(-length * 0.5 + 0.3 + tw * 0.5, length * 0.5 - 0.3 - tw * 0.5)
		_tag(mb, Vector3(tx, 1.4, t * 0.5 + 0.05), Vector3.LEFT, Vector3.BACK, tw, 1.0, rng)
	_weeds(mb, -length * 0.5, length * 0.5, -t * 0.5 - 0.5, -t * 0.5 - 0.05, int(length / 1.5), rng, 0.15, 0.25)


## A chain-link fence run along X, w long: maybe barbed, maybe torn.
static func chainlink_fence(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var h := rng.randf_range(1.8, 2.4)
	_chainlink(mb, out, Vector3(-w * 0.5 + 0.1, 0, 0), Vector3(w * 0.5 - 0.1, 0, 0), h, rng, rng.randf() < 0.5, rng.randf() < 0.35, 3)
	var reach := minf(d * 0.5 - 0.05, 0.5)
	_weeds(mb, -w * 0.5 + 0.2, w * 0.5 - 0.2, -reach, reach, int(w / 2.0), rng, 0.12, minf(0.3, reach * 0.5))
	if w >= 3.0 and d >= 0.9:
		_bags(mb, Vector3(rng.randf_range(-w * 0.3, w * 0.3), 0, -0.25), 1, rng, 0.0)


## A burnt-out car shell with ash under it.
static func burnt_car(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var ash := Vector2(minf(1.25, w * 0.5 - 0.05), minf(2.45, d * 0.5 - 0.05))
	_burnt_car(mb, out, Vector3.ZERO, rng.randf_range(-0.06, 0.06) * minf(1.0, (d - 4.3) / 0.8), rng, ash)
	if w >= 2.8:
		mb.cylinder(Vector3(-w * 0.5 + 0.45, 0, d * 0.25), 0.37, 0.24, TYRE, 7)


## A shopping cart loaded with bags and bundles.
static func shopping_cart(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	_cart(mb, out, Vector3(0, 0, -0.17), rng.randf_range(-0.22, 0.22), rng)


## An old mattress dumped on the ground, maybe on a box spring.
static func mattress(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var yaw := rng.randf_range(-0.35, 0.35)
	# Turn it less on a small lot so its corners stay on it.
	while absf(yaw) > 0.01 and (0.72 * cos(yaw) + 0.99 * absf(sin(yaw)) > w * 0.5 or 0.99 * cos(yaw) + 0.72 * absf(sin(yaw)) > d * 0.5):
		yaw *= 0.7
	if rng.randf() < 0.4:
		_rbox(mb, Vector3(0, 0.12, 0), Vector3(1.38, 0.24, 1.9), yaw * 0.6, Color(0.55, 0.45, 0.35))
		var saved := _push(mb, Vector3(0, 0.24, 0), yaw)
		_mattress(mb, Vector3.ZERO, 0.0, rng)
		mb.xform = saved
	else:
		_mattress(mb, Vector3.ZERO, yaw, rng)
	mb.ball(Vector3(0.3, 0.3, -0.5), Vector3(0.3, 0.1, 0.2), Color(0.85, 0.85, 0.8), 5, 2)


## A heap of trash: bags, boxes, a broken chair and a tyre.
static func trash_pile(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var r := minf(w, d) * 0.5
	_bags(mb, Vector3.ZERO, rng.randi_range(4, 7), rng, maxf(r - 0.6, 0.1))
	for i in rng.randi_range(1, 2):
		var s := rng.randf_range(0.35, 0.55)
		_crate(mb, Vector3(rng.randf_range(-r, r) * 0.4, 0, rng.randf_range(-r, r) * 0.4), s, rng.randf() * TAU, CARDBOARD.darkened(rng.randf() * 0.2))
	var cp := Vector3(rng.randf_range(-r, r) * 0.3, 0, rng.randf_range(-r, r) * 0.3)
	var chair: Color = Kit._pick([Color(0.9, 0.9, 0.88), Color(0.25, 0.4, 0.3), Color(0.5, 0.35, 0.25)], rng)
	_rbox(mb, cp + Vector3(0, 0.45, 0), Vector3(0.45, 0.06, 0.45), rng.randf() * TAU, chair)
	_rbox(mb, cp + Vector3(0, 0.2, 0), Vector3(0.4, 0.4, 0.4), 0.3, chair.darkened(0.3))
	if r >= 1.0:
		mb.cylinder(Vector3(r - 0.45, 0, -r + 0.45), 0.37, 0.24, TYRE, 7)
	out.append([Vector3(0, 0.4, 0), Vector3(r * 1.3, 0.8, r * 1.3)])


## A dead palm: a bare trunk, a skirt of dead fronds or a snapped top.
static func dead_palm(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	_dead_palm(mb, out, Vector3.ZERO, minf(w, d) * 0.5 - 0.1, rng)
	mb.box(Vector3(0, 0.03, 0), Vector3(minf(w, 1.2), 0.02, minf(d, 1.2)), DIRT)
