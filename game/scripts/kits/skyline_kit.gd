extends RefCounted
## Skyline kit (Bellerive v3): downtown skyscrapers and the city's big
## monuments, all fictional, borrowed by type from Los Angeles, San
## Francisco and DC: setback glass towers, an art-deco crown, the flat-roof
## helipad towers of LA's old fire rule, twin towers with a sky bridge, a
## 1970s finned slab and mid-rise fillers with podium parking; hillside
## letters, a domed observatory, an oval coliseum with a peristyle, a
## memorial arch, an abstract statue on a plinth, a suspension-bridge tower
## and a lattice radio mast. Pure data in, mesh out: static functions only,
## no scene tree, so a tile builds on a worker thread.
##
## Frame and colliders as in civic_kit.gd: the lot spans x in [-w/2, w/2]
## (along the street) and z in [-d/2, d/2], the main entrance faces the
## street at -Z, ground at y = 0. Everything stays on the lot (no
## overhangs), except hillside_letters, whose scaffold legs reach 2 m below
## y = 0 into the sloped hillside. Collision boxes go to `out` as
## [center, size] or [center, size, yaw]; every kind has one standing on
## the ground. No text, logos, real flags, people or religious symbols:
## sculptures are abstract, screens are colour blocks, the hillside letters
## are consonant-like glyphs that never spell a word.
##
## The game camera is orthographic and pitched 60 degrees down, so the
## detail goes on roofs (helipads, plant, crowns, setback gardens, beacons)
## and the street-level plaza; tall shafts are cheap: one glass block with
## spandrel bands and fins drawn as quads and slim boxes.
##
## Tower heights are drawn from `rng` within HEIGHTS (the main roof; masts,
## spires and crowns rise up to about 12 m more, see the header of each
## builder). Footprints scale with the lot; heights do not.

const MeshBuilder = preload("res://scripts/mesh_builder.gd")
const Kit = preload("res://scripts/kits/country_kit.gd")
const Buildings = preload("res://scripts/kits/building_kit.gd")
const Props = preload("res://scripts/kits/prop_kit.gd")
const Civic = preload("res://scripts/kits/civic_kit.gd")

## Downtown towers.
const SKYSCRAPERS := [
	"skyscraper_glass", "skyscraper_crown", "skyscraper_helipad",
	"skyscraper_twin", "skyscraper_slab", "highrise_mid",
]
## Monuments and landmarks.
const MONUMENTS := [
	"hillside_letters", "observatory", "coliseum", "memorial_arch",
	"statue_plinth", "suspension_tower", "radio_mast",
]

## Default lot of each kind: x along the front, y deep, metres.
const SIZES := {
	"skyscraper_glass": Vector2(44, 44), "skyscraper_crown": Vector2(44, 44),
	"skyscraper_helipad": Vector2(42, 42), "skyscraper_twin": Vector2(50, 44),
	"skyscraper_slab": Vector2(50, 36), "highrise_mid": Vector2(36, 36),
	"hillside_letters": Vector2(120, 30), "observatory": Vector2(70, 50),
	"coliseum": Vector2(180, 150), "memorial_arch": Vector2(40, 30),
	"statue_plinth": Vector2(20, 20), "suspension_tower": Vector2(30, 12),
	"radio_mast": Vector2(20, 20),
}
## Height range of the main roof (or the tip, for the crown tower), metres.
const HEIGHTS := {
	"skyscraper_glass": Vector2(90, 140), "skyscraper_crown": Vector2(100, 150),
	"skyscraper_helipad": Vector2(80, 130), "skyscraper_twin": Vector2(90, 120),
	"skyscraper_slab": Vector2(60, 90), "highrise_mid": Vector2(30, 55),
	"suspension_tower": Vector2(36, 36), "radio_mast": Vector2(56, 62),
}

const GLASSES := [
	Color(0.3, 0.45, 0.55), Color(0.24, 0.36, 0.46), Color(0.36, 0.5, 0.52), Color(0.44, 0.38, 0.28),
	Color(0.5, 0.55, 0.6), Color(0.22, 0.4, 0.42), Color(0.3, 0.33, 0.38),
]
const SPANDRELS := [Color(0.5, 0.54, 0.58), Color(0.26, 0.28, 0.31), Color(0.62, 0.6, 0.56), Color(0.4, 0.46, 0.5)]
const FRAMES := [Color(0.74, 0.76, 0.79), Color(0.3, 0.32, 0.35), Color(0.58, 0.52, 0.42), Color(0.86, 0.86, 0.84)]
## Granite and stone claddings of the 1980s towers.
const CLADDING := [Color(0.62, 0.5, 0.46), Color(0.56, 0.56, 0.57), Color(0.78, 0.74, 0.66), Color(0.44, 0.42, 0.42), Color(0.7, 0.62, 0.52)]
## Art-deco limestone and terracotta.
const DECO_STONE := [Color(0.86, 0.8, 0.68), Color(0.8, 0.68, 0.52), Color(0.76, 0.75, 0.71), Color(0.68, 0.56, 0.46)]
const CROWN_LIGHTS := [Color(1.0, 0.78, 0.38), Color(0.9, 0.92, 1.0), Color(0.45, 0.8, 1.0), Color(1.0, 0.55, 0.3)]
const ACCENT_LIGHTS := [Color(0.4, 0.85, 1.0), Color(1.0, 0.4, 0.6), Color(0.9, 0.92, 1.0), Color(0.6, 1.0, 0.6), Color(1.0, 0.75, 0.3)]
const PRECAST := [Color(0.76, 0.73, 0.66), Color(0.68, 0.67, 0.64), Color(0.8, 0.76, 0.68)]
const STUCCO := [Color(0.92, 0.88, 0.8), Color(0.86, 0.8, 0.72), Color(0.8, 0.84, 0.86), Color(0.9, 0.84, 0.74)]
const SEATS := [Color(0.55, 0.16, 0.16), Color(0.72, 0.62, 0.42), Color(0.2, 0.3, 0.48), Color(0.62, 0.62, 0.6)]
const BRIDGE_PAINTS := [Color(0.66, 0.25, 0.16), Color(0.5, 0.56, 0.6), Color(0.3, 0.42, 0.37), Color(0.76, 0.73, 0.66)]
const CAR_PAINTS := [Color(0.85, 0.85, 0.86), Color(0.12, 0.13, 0.15), Color(0.5, 0.52, 0.55), Color(0.6, 0.12, 0.1), Color(0.18, 0.28, 0.5), Color(0.75, 0.72, 0.62)]

const PAVER := Color(0.78, 0.76, 0.72)
const GRANITE := Color(0.5, 0.49, 0.48)
const LIMESTONE := Color(0.87, 0.84, 0.77)
const LAWN := Color(0.4, 0.58, 0.29)
const ROOF_GREY := Color(0.62, 0.63, 0.64)
const ROOF_TAN := Color(0.7, 0.66, 0.58)
const UNIT := Color(0.8, 0.82, 0.84)
const DARK := Color(0.1, 0.11, 0.13)
const STEEL := Color(0.7, 0.72, 0.75)
const GOLD := Color(0.9, 0.72, 0.25)
const BRONZE := Color(0.5, 0.36, 0.2)
const VERDIGRIS := Color(0.42, 0.62, 0.55)
const WHITE := Color(0.95, 0.95, 0.93)
const YELLOW := Color(0.95, 0.8, 0.2)
const RED_LIGHT := Color(1.0, 0.15, 0.1)
const LOBBY := Color(0.34, 0.4, 0.44)
const WATER := Color(0.25, 0.45, 0.55)
const POOL := Color(0.25, 0.62, 0.75)
const TRACK := Color(0.66, 0.32, 0.24)
const AVIATION := Color(0.88, 0.3, 0.14)


## Every kind this kit builds.
static func kinds() -> Array:
	return SKYSCRAPERS + MONUMENTS


## The default lot of `kind` (x along the front, y deep, metres).
static func default_size(kind: String) -> Vector2:
	return SIZES.get(kind, Vector2(30, 30))


## The height range of `kind` (main roof), or zero for low monuments.
static func height_range(kind: String) -> Vector2:
	return HEIGHTS.get(kind, Vector2.ZERO)


## Triangle budget of `kind` at its default lot.
static func budget(kind: String) -> int:
	if kind == "highrise_mid":
		return 3000
	if kind in SKYSCRAPERS:
		return 6000
	if kind == "coliseum":
		return 12000
	return 8000


## Builds `kind` on a lot of `size` (x along the front, y deep). See the
## header for the frame and the collision format.
static func build(kind: String, mb, out: Array, size: Vector2, rng: RandomNumberGenerator) -> void:
	var w := maxf(size.x, 6.0)
	var d := maxf(size.y, 6.0)
	match kind:
		"skyscraper_glass": skyscraper_glass(mb, out, w, d, rng)
		"skyscraper_crown": skyscraper_crown(mb, out, w, d, rng)
		"skyscraper_helipad": skyscraper_helipad(mb, out, w, d, rng)
		"skyscraper_twin": skyscraper_twin(mb, out, w, d, rng)
		"skyscraper_slab": skyscraper_slab(mb, out, w, d, rng)
		"highrise_mid": highrise_mid(mb, out, w, d, rng)
		"hillside_letters": hillside_letters(mb, out, w, d, rng)
		"observatory": observatory(mb, out, w, d, rng)
		"coliseum": coliseum(mb, out, w, d, rng)
		"memorial_arch": memorial_arch(mb, out, w, d, rng)
		"statue_plinth": statue_plinth(mb, out, w, d, rng)
		"suspension_tower": suspension_tower(mb, out, w, d, rng)
		"radio_mast": radio_mast(mb, out, w, d, rng)
		_:
			# Unknown kind: a plain magenta block, so a typo shows instead of a hole.
			Kit._solid(mb, out, Vector3(0, 2.0, 0), Vector3(w * 0.6, 4.0, d * 0.6), Color(1.0, 0.0, 1.0))


# --- Helpers ------------------------------------------------------------------

static func _gl(c: Color) -> Color:
	return MeshBuilder.glow(c, MeshBuilder.GLASS)


static func _mt(c: Color) -> Color:
	return MeshBuilder.glow(c, MeshBuilder.METAL)


static func _gloss(c: Color) -> Color:
	return MeshBuilder.glow(c, MeshBuilder.GLOSS)


static func _neon(c: Color) -> Color:
	return MeshBuilder.glow(c, MeshBuilder.GLOW_NEON)


static func _lamp(c := Color(1.0, 0.95, 0.85)) -> Color:
	return MeshBuilder.glow(c, MeshBuilder.GLOW_LAMP)


static func _pick(list: Array, rng: RandomNumberGenerator):
	return list[rng.randi() % list.size()]


static func _height(kind: String, rng: RandomNumberGenerator) -> float:
	var r := height_range(kind)
	return rng.randf_range(r.x, r.y)


## A solid box that also collides.
static func _solid(mb, out: Array, c: Vector3, s: Vector3, color: Color) -> void:
	mb.box(c, s, color)
	out.append([c, s])


## A band of four outward quads round a sw x sd block centred on (cx, cz),
## from y up h, `off` proud of the faces. `faces` is a mask: 1 front (-Z),
## 2 back, 4 left (-X), 8 right.
static func _band(mb, cx: float, cz: float, sw: float, sd: float, y: float, h: float, off: float, color: Color, faces := 15) -> void:
	var hx := sw * 0.5 + off
	var hz := sd * 0.5 + off
	var y1 := y + h
	if faces & 1:
		mb.quad(Vector3(cx - hx, y, cz - hz), Vector3(cx + hx, y, cz - hz), Vector3(cx + hx, y1, cz - hz), Vector3(cx - hx, y1, cz - hz), Vector3.FORWARD, color)
	if faces & 2:
		mb.quad(Vector3(cx - hx, y, cz + hz), Vector3(cx + hx, y, cz + hz), Vector3(cx + hx, y1, cz + hz), Vector3(cx - hx, y1, cz + hz), Vector3.BACK, color)
	if faces & 4:
		mb.quad(Vector3(cx - hx, y, cz - hz), Vector3(cx - hx, y, cz + hz), Vector3(cx - hx, y1, cz + hz), Vector3(cx - hx, y1, cz - hz), Vector3.LEFT, color)
	if faces & 8:
		mb.quad(Vector3(cx + hx, y, cz - hz), Vector3(cx + hx, y, cz + hz), Vector3(cx + hx, y1, cz + hz), Vector3(cx + hx, y1, cz - hz), Vector3.RIGHT, color)


## Vertical fins (mullions, piers) proud of the faces of a sw x sd block
## from y0 to y1, about one every `step` metres, `t` wide and `depth` deep;
## `corners` adds a square fin on each corner. `faces` as in _band.
static func _fins(mb, cx: float, cz: float, sw: float, sd: float, y0: float, y1: float, step: float, t: float, depth: float, color: Color, faces := 15, corners := false) -> void:
	var h := y1 - y0
	var ym := (y0 + y1) * 0.5
	var nx := maxi(2, roundi(sw / step))
	var nz := maxi(2, roundi(sd / step))
	for i in range(1, nx):
		var x := cx - sw * 0.5 + sw * i / nx
		if faces & 1:
			mb.box(Vector3(x, ym, cz - sd * 0.5 - depth * 0.5), Vector3(t, h, depth), color)
		if faces & 2:
			mb.box(Vector3(x, ym, cz + sd * 0.5 + depth * 0.5), Vector3(t, h, depth), color)
	for i in range(1, nz):
		var z := cz - sd * 0.5 + sd * i / nz
		if faces & 4:
			mb.box(Vector3(cx - sw * 0.5 - depth * 0.5, ym, z), Vector3(depth, h, t), color)
		if faces & 8:
			mb.box(Vector3(cx + sw * 0.5 + depth * 0.5, ym, z), Vector3(depth, h, t), color)
	if corners:
		var c := depth * 2.0 + t
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				mb.box(Vector3(cx + sx * sw * 0.5, ym, cz + sz * sd * 0.5), Vector3(c, h, c), color)


## A curtain-wall shaft: a glass block from y0 to y1 on a sw x sd footprint
## centred on (cx, cz), spandrel bands every `floor` metres and mullion fins
## about every `step` metres, with corner mullions. Collides when `collide`.
static func _curtain(mb, out: Array, cx: float, cz: float, sw: float, sd: float, y0: float, y1: float, glass: Color, band: Color, fin: Color, floor := 3.8, step := 3.0, collide := true) -> void:
	mb.box(Vector3(cx, (y0 + y1) * 0.5, cz), Vector3(sw, y1 - y0, sd), glass)
	var y := y0 + floor - 0.55
	while y < y1 - 1.0:
		_band(mb, cx, cz, sw, sd, y, 0.55, 0.03, band)
		y += floor
	_fins(mb, cx, cz, sw, sd, y0, y1, step, 0.2, 0.28, fin, 15, true)
	if collide:
		out.append([Vector3(cx, (y0 + y1) * 0.5, cz), Vector3(sw, y1 - y0, sd)])


## A flat roof with a parapet on a sw x sd block whose top is at `top`.
static func _cap(mb, cx: float, cz: float, sw: float, sd: float, top: float, edge: Color, membrane := ROOF_GREY, ph := 1.0) -> void:
	Civic._parapet_roof(mb, cx, cz, sw, sd, top, edge, ph, membrane)


## Red aircraft-warning light standing at p.
static func _beacon(mb, p: Vector3, s := 0.4) -> void:
	mb.box(p + Vector3(0, s * 0.5, 0), Vector3(s, s, s), _neon(RED_LIGHT))


## Red lights on the four corners of a sw x sd roof at `top`.
static func _corner_beacons(mb, cx: float, cz: float, sw: float, sd: float, top: float) -> void:
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_beacon(mb, Vector3(cx + sx * (sw * 0.5 - 0.3), top, cz + sz * (sd * 0.5 - 0.3)), 0.35)


## A tapering spire or mast from `base`, h tall, with a beacon on the tip.
static func _spire(mb, base: Vector3, h: float, r: float, color: Color) -> void:
	mb.limb(base, base + Vector3(0, h, 0), r, r * 0.2, color, 6, false)
	_beacon(mb, base + Vector3(0, h, 0), 0.35)


## Planted terrace on a setback: a lawn strip along the front of the lower
## tier's roof (between its parapet and the upper tier) and shrubs along
## the parapet, plus a strip of decking on the sides when there is room.
static func _setback_garden(mb, cx: float, ow: float, oz0: float, iz0: float, y: float, rng: RandomNumberGenerator) -> void:
	var z0 := oz0 + 0.5
	var z1 := iz0 - 0.3
	if z1 - z0 < 1.2:
		return
	var zm := (z0 + z1) * 0.5
	mb.box(Vector3(cx, y + 0.08, zm), Vector3(ow - 1.2, 0.06, z1 - z0), Civic._grass(LAWN))
	var n := maxi(2, int((ow - 2.0) / 6.0))
	for i in n:
		var x := cx - ow * 0.5 + 1.4 + (ow - 2.8) * (i + 0.5) / n
		Kit._bush(mb, Vector3(x, y + 0.1, z0 + 0.5), 0.7, rng, Kit.LEAF.lightened(0.08 * (i % 2)))


## A mechanical penthouse: louvred walls (the seam code draws the slats),
## a membrane roof and cooling plant on top.
static func _penthouse(mb, cx: float, cz: float, pw: float, pd: float, y: float, h: float, wall: Color) -> void:
	mb.box(Vector3(cx, y + h * 0.5, cz), Vector3(pw, h, pd), wall)
	_band(mb, cx, cz, pw, pd, y + h * 0.25, h * 0.55, 0.03, MeshBuilder.glow(Color(0.42, 0.44, 0.46), MeshBuilder.SEAM_ROOF))
	mb.box(Vector3(cx, y + h + 0.02, cz), Vector3(pw - 0.3, 0.04, pd - 0.3), MeshBuilder.glow(ROOF_GREY, MeshBuilder.ROOF))
	if pw > 5.0 and pd > 3.0:
		Buildings._hvac(mb, Vector3(cx - pw * 0.18, y + h, cz), Vector3(minf(pw * 0.45, 6.0), 1.1, minf(pd * 0.5, 2.4)))


## Window-cleaning gantry (building maintenance unit) on a chrome track
## running along a roof edge from x0 to x1 at depth z.
static func _bmu(mb, x0: float, x1: float, z: float, top: float) -> void:
	mb.box(Vector3((x0 + x1) * 0.5, top + 0.12, z), Vector3(x1 - x0, 0.08, 0.12), _mt(STEEL))
	var x := lerpf(x0, x1, 0.3)
	mb.box(Vector3(x, top + 0.75, z), Vector3(1.4, 1.2, 1.6), _mt(UNIT))
	mb.box(Vector3(x, top + 1.45, z - 1.6), Vector3(0.3, 0.3, 3.2), _gloss(YELLOW))


## The roof of a tower: membrane and parapet, a louvred penthouse toward
## the back, a gondola on its track, corner beacons, and a mast or spire.
static func _tower_roof(mb, cx: float, cz: float, sw: float, sd: float, top: float, edge: Color, rng: RandomNumberGenerator, spire := 0.0) -> void:
	_cap(mb, cx, cz, sw, sd, top, edge, _pick([ROOF_GREY, ROOF_TAN, Color(0.72, 0.73, 0.74)], rng), 1.2)
	var pw := sw * 0.52
	var pd := sd * 0.42
	var pz := cz + sd * 0.5 - pd * 0.5 - 1.6
	_penthouse(mb, cx, pz, pw, pd, top, 4.5, Civic._stone(Color(0.66, 0.66, 0.65)))
	_bmu(mb, cx - sw * 0.5 + 1.2, cx + sw * 0.5 - 1.2, cz - sd * 0.5 + 1.4, top)
	Buildings._stair_hut(mb, Vector3(cx + sw * 0.5 - 2.4, top, pz - pd * 0.5 - 2.0), edge)
	_corner_beacons(mb, cx, cz, sw, sd, top + 1.2)
	if spire > 0.0:
		_spire(mb, Vector3(cx, top + 4.5, pz), spire, 0.6, _mt(STEEL))
	else:
		# A telecom mast with dishes on the penthouse.
		var m := Vector3(cx + pw * 0.3, top + 4.5, pz)
		mb.cylinder(m, 0.14, 7.0, Color(0.6, 0.6, 0.62), 4)
		for k in 3:
			var ang := TAU * k / 3.0
			mb.box(m + Vector3(cos(ang) * 0.35, 5.6, sin(ang) * 0.35), Vector3(0.22, 1.3, 0.22), WHITE)
		_beacon(mb, m + Vector3(0, 7.0, 0), 0.3)


## A glazed lobby across x0..x1 on the face at z (facing -Z), h tall, lit
## at night, with mullions, a dark door bay and a steel canopy reaching
## `reach` toward -Z with a lit fascia.
static func _lobby(mb, x0: float, x1: float, z: float, h: float, reach: float, frame: Color) -> void:
	var cx := (x0 + x1) * 0.5
	var lw := x1 - x0
	mb.box(Vector3(cx, h * 0.5 + 0.05, z - 0.05), Vector3(lw, h, 0.08), Civic._lit(LOBBY))
	var n := maxi(2, int(lw / 2.6))
	for i in range(1, n):
		mb.box(Vector3(x0 + lw * i / n, h * 0.5 + 0.05, z - 0.12), Vector3(0.14, h, 0.14), frame)
	mb.box(Vector3(cx, h + 0.15, z - 0.12), Vector3(lw, 0.3, 0.14), frame)
	mb.box(Vector3(cx, 1.35, z - 0.14), Vector3(minf(4.2, lw * 0.3), 2.7, 0.06), MeshBuilder.glow(Color(0.12, 0.14, 0.16), MeshBuilder.GLASS))
	if reach > 0.8:
		var cw := minf(lw * 0.5, 14.0)
		mb.box(Vector3(cx, h * 0.8 + 0.2, z - reach * 0.5), Vector3(cw, 0.3, reach), _mt(Color(0.3, 0.32, 0.35)))
		mb.box(Vector3(cx, h * 0.8 + 0.2, z - reach + 0.04), Vector3(cw, 0.2, 0.08), _lamp())


## A bronze or steel abstract sculpture standing at p, about h tall, no
## figure: 0 a twisted stack of slabs ending in a canted polished spike, 1 two
## leaning blades with a hoop between them, 2 four split column quarters
## round a sphere.
static func _sculpture(mb, p: Vector3, h: float, variant: int, color: Color) -> void:
	var polished := _mt(Color(0.85, 0.8, 0.66))
	match variant % 3:
		0:
			const N := 7
			for i in N:
				var t := float(i) / N
				var s := lerpf(1.0, 0.5, t) * h * 0.3
				Civic._rbox(mb, p + Vector3(0, h * (i + 0.5) / N * 0.9, 0), Vector3(s, h / N * 0.86, s * 0.42), i * 0.45, color)
			mb.limb(p + Vector3(0, h * 0.86, 0), p + Vector3(0.15 * h, h * 1.05, 0), h * 0.07, h * 0.01, polished, 6, false)
		1:
			for s: float in [-1.0, 1.0]:
				var saved: Transform3D = mb.xform
				mb.xform = saved * Transform3D(Basis(Vector3.BACK, s * 0.2), p + Vector3(s * h * 0.16, 0, 0))
				mb.box(Vector3(0, h * 0.5, 0), Vector3(h * 0.11, h, h * 0.05), color)
				mb.xform = saved
			_hoop(mb, p + Vector3(0, h * 0.45, 0), h * 0.2, h * 0.025, polished)
		_:
			for q in 4:
				var a := TAU * (q + 0.5) / 4.0
				var o := Vector3(cos(a), 0, sin(a)) * h * 0.1
				var saved: Transform3D = mb.xform
				var lean := Basis(Vector3(-o.z, 0, o.x).normalized(), -0.08)
				mb.xform = saved * Transform3D(lean, p + o)
				mb.box(Vector3(0, h * 0.45, 0), Vector3(h * 0.1, h * 0.9, h * 0.1), color)
				mb.xform = saved
			mb.ball(p + Vector3(0, h * 0.55, 0), Vector3(h * 0.13, h * 0.13, h * 0.13), polished, 8, 4)


## A hoop in the x-y plane round c, radius r, bar t thick.
static func _hoop(mb, c: Vector3, r: float, t: float, color: Color, segs := 12) -> void:
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		Kit._beam(mb, c + Vector3(cos(a0), sin(a0), 0) * r, c + Vector3(cos(a1), sin(a1), 0) * r, t, color)


## A square fountain basin at c, s across: granite rim, water and jets.
static func _fountain(mb, out: Array, c: Vector3, s: Vector3) -> void:
	var rim := Civic._stone(GRANITE.lightened(0.2))
	for sx: float in [-1.0, 1.0]:
		mb.box(c + Vector3(sx * (s.x * 0.5 - 0.25), 0.3, 0), Vector3(0.5, 0.6, s.z), rim)
		mb.box(c + Vector3(0, 0.3, sx * (s.z * 0.5 - 0.25)), Vector3(s.x - 1.0, 0.6, 0.5), rim)
	mb.box(c + Vector3(0, 0.42, 0), Vector3(s.x - 1.0, 0.04, s.z - 1.0), _gl(WATER))
	var spray := Color(0.88, 0.94, 1.0)
	var nx := maxi(1, int(s.x / 3.0))
	for i in nx:
		var x := c.x - s.x * 0.5 + s.x * (i + 0.5) / nx
		mb.limb(Vector3(x, 0.44, c.z), Vector3(x, 1.6, c.z), 0.12, 0.03, spray, 4, false)
	out.append([c + Vector3(0, 0.4, 0), Vector3(s.x, 0.8, s.z)])


## The forecourt between the street (z0 = -d/2) and the building face at
## z1, across the lot: pavers, bollards along the kerb, trees or palms at
## the sides, a fountain or an abstract steel sculpture in the middle,
## benches and two pole lamps.
static func _plaza(mb, out: Array, w: float, z0: float, z1: float, rng: RandomNumberGenerator, feature := -1) -> void:
	var depth := z1 - z0
	if depth < 1.5:
		return
	Kit._pad(mb, -w * 0.5, w * 0.5, z0, z1, Civic._paving(PAVER), 0.03)
	var bollard := _mt(Color(0.36, 0.37, 0.39))
	var nb := maxi(2, int((w - 6.0) / 3.2))
	for i in nb:
		var x := -w * 0.5 + 3.0 + (w - 6.0) * (i + 0.5) / nb
		if absf(x) < 3.0:
			continue
		mb.box(Vector3(x, 0.45, z0 + 0.7), Vector3(0.3, 0.9, 0.3), bollard)
	if depth < 6.0:
		return
	var zm := (z0 + z1) * 0.5
	var palms := rng.randf() < 0.5
	for sx: float in [-1.0, 1.0]:
		var xs: Array = [sx * (w * 0.5 - 3.2)]
		if w > 40.0:
			xs.append(sx * (w * 0.5 - 10.0))
		for x: float in xs:
			if palms:
				Civic._palm(mb, out, Vector3(x, 0.03, zm), rng)
			else:
				Props.street_tree(mb, out, Vector3(x, 0.03, zm), rng)
		Civic._pole_lamp(mb, out, Vector3(sx * (w * 0.5 - 1.2), 0.03, z0 + 1.6))
	if depth < 8.0:
		return
	var f := feature if feature >= 0 else rng.randi() % 2
	var fs := minf(depth - 4.0, 7.0)
	if f == 0:
		_fountain(mb, out, Vector3(0, 0.03, zm), Vector3(fs * 1.6, 0, fs))
	else:
		mb.box(Vector3(0, 0.25, zm), Vector3(2.4, 0.5, 2.4), Civic._stone(GRANITE))
		_sculpture(mb, Vector3(0, 0.5, zm), clampf(depth * 0.5, 4.0, 7.0), rng.randi(), _gloss(_pick([Color(0.8, 0.22, 0.12), Color(0.9, 0.55, 0.12), Color(0.2, 0.3, 0.6)], rng)))
		out.append([Vector3(0, 1.5, zm), Vector3(2.4, 3.0, 2.4)])
	for sx: float in [-1.0, 1.0]:
		Props.bench(mb, out, Vector3(sx * (fs + 1.5), 0.03, zm), sx * PI * 0.5)


## A parked car (nose toward -Z before yaw) standing on y.
static func _car(mb, p: Vector3, yaw: float, color: Color) -> void:
	var saved: Transform3D = mb.xform
	mb.xform = saved * Transform3D(Basis(Vector3.UP, yaw), p)
	mb.box(Vector3(0, 0.55, 0), Vector3(1.8, 0.75, 4.3), _gloss(color))
	mb.box(Vector3(0, 1.15, 0.2), Vector3(1.6, 0.5, 2.2), _gl(Color(0.16, 0.2, 0.24)))
	mb.xform = saved


# --- Skyscrapers ----------------------------------------------------------------

## Setback glass tower (90-140 m roof; spire up to +12 m): a stone podium
## with a glazed lobby and a roof terrace, three curtain-wall tiers that
## step back with planted setbacks (centred or flush at the back), a
## penthouse, gondola, beacons and a spire or a lit crown band.
static func skyscraper_glass(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var h := _height("skyscraper_glass", rng)
	var glass := _gl(_pick(GLASSES, rng))
	var band := _mt(_pick(SPANDRELS, rng))
	var fin := _mt(_pick(FRAMES, rng))
	var stone := Civic._stone(_pick(CLADDING, rng))
	var zf := -d * 0.5 + clampf(d * 0.2, 6.0, 12.0)
	var zb := d * 0.5 - 1.0
	var pw := w - 2.0
	var pd := zb - zf
	var pc := (zf + zb) * 0.5
	const PH := 10.0
	_solid(mb, out, Vector3(0, PH * 0.5, pc), Vector3(pw, PH, pd), stone)
	_band(mb, 0, pc, pw, pd, 6.2, 2.6, 0.03, glass)
	_lobby(mb, -pw * 0.34, pw * 0.34, zf, 5.2, minf(zf + d * 0.5 - 1.0, 3.0), fin)
	# Tiers: 74 %, then 80 % and 78 % of the one below.
	var flush := rng.randf() < 0.5
	var sw: Array = [pw * 0.74, pw * 0.74 * 0.8, pw * 0.74 * 0.8 * 0.78]
	var sd: Array = [pd * 0.7, pd * 0.7 * 0.8, pd * 0.7 * 0.8 * 0.78]
	var tc := pc + pd * 0.08
	var back: float = tc + sd[0] * 0.5
	var tops: Array = [h * rng.randf_range(0.5, 0.6), h * rng.randf_range(0.74, 0.82), h]
	var y0 := PH
	for k in 3:
		var tz: float = back - sd[k] * 0.5 if flush else tc
		_curtain(mb, out, 0, tz, sw[k], sd[k], y0, tops[k], glass, band, fin)
		if k < 2:
			_cap(mb, 0, tz, sw[k], sd[k], tops[k], fin, ROOF_GREY, 1.1)
			var nz: float = back - sd[k + 1] * 0.5 if flush else tc
			_setback_garden(mb, 0, sw[k], tz - sd[k] * 0.5, nz - sd[k + 1] * 0.5, tops[k], rng)
		y0 = tops[k]
	var tz2: float = back - sd[2] * 0.5 if flush else tc
	if rng.randf() < 0.5:
		_tower_roof(mb, 0, tz2, sw[2], sd[2], h, fin, rng, rng.randf_range(6.0, 8.5))
	else:
		_tower_roof(mb, 0, tz2, sw[2], sd[2], h, fin, rng)
		_band(mb, 0, tz2, sw[2], sd[2], h - 1.4, 0.6, 0.32, _neon(_pick(ACCENT_LIGHTS, rng)))
	# Podium roof: membrane and a terrace in front of the first tier.
	_cap(mb, 0, pc, pw, pd, PH, stone, ROOF_TAN, 1.0)
	var t0z: float = (back - sd[0] * 0.5 if flush else tc) - sd[0] * 0.5
	if t0z - zf > 3.4:
		Buildings._terrace(mb, -pw * 0.5 + 0.8, pw * 0.5 - 0.8, zf + 0.6, t0z - 0.6, PH, rng)
	_plaza(mb, out, w, -d * 0.5, zf, rng)


## An art-deco shaft: dark glass between full-height stone piers, darker
## spandrels each floor, square corner piers and a cornice.
static func _deco_shaft(mb, out: Array, cx: float, cz: float, sw: float, sd: float, y0: float, y1: float, stone: Color, glass: Color, spandrel: Color) -> void:
	mb.box(Vector3(cx, (y0 + y1) * 0.5, cz), Vector3(sw, y1 - y0, sd), glass)
	var y := y0 + 3.6
	while y < y1 - 2.0:
		_band(mb, cx, cz, sw, sd, y - 1.1, 1.1, 0.02, spandrel)
		y += 3.6
	_fins(mb, cx, cz, sw, sd, y0, y1, 3.2, 0.8, 0.35, stone, 15, true)
	_band(mb, cx, cz, sw, sd, y1 - 1.6, 1.6, 0.6, stone)
	out.append([Vector3(cx, (y0 + y1) * 0.5, cz), Vector3(sw, y1 - y0, sd)])


## Art-deco stepped tower (100-150 m to the needle tip): a limestone or
## terracotta shaft of piers and dark glass rising in five setbacks with
## stepped corner pinnacles, then a crown of two lit lanterns framed by
## gold fins, a gilded pyramid and a needle. The crown glows a little by
## day and fully at night.
static func skyscraper_crown(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var h := _height("skyscraper_crown", rng)
	var sc: Color = _pick(DECO_STONE, rng)
	var stone := Civic._stone(sc)
	var spandrel := Civic._stone(sc.darkened(0.3))
	var glass := _gl(Color(0.18, 0.22, 0.26).lerp(Color(0.24, 0.3, 0.3), rng.randf()))
	var gold := _mt(GOLD)
	var lit := _neon(_pick(CROWN_LIGHTS, rng))
	var zf := -d * 0.5 + clampf(d * 0.14, 4.5, 9.0)
	var zb := d * 0.5 - 1.2
	var bw := w - 2.4
	var bd := zb - zf
	var bc := (zf + zb) * 0.5
	var fracs := [0.16, 0.5, 0.64, 0.75, 0.82]
	var scales := [1.0, 0.82, 0.68, 0.56, 0.44]
	var y0 := 0.0
	for k in 5:
		var s: float = scales[k]
		var sw: float = bw * s
		var sd: float = bd * s
		var cz := bc + (bd - sd) * 0.12
		var y1: float = h * fracs[k]
		_deco_shaft(mb, out, 0, cz, sw, sd, y0, y1, stone, glass, spandrel)
		if k < 4:
			_cap(mb, 0, cz, sw, sd, y1, stone, ROOF_TAN, 0.9)
			# Stepped pinnacles on the setback corners, lit from below at night.
			for sx: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					var p := Vector3(sx * (sw * 0.5 - 0.9), y1, cz + sz * (sd * 0.5 - 0.9))
					mb.box(p + Vector3(0, 1.4, 0), Vector3(1.8, 2.8, 1.8), stone)
					mb.box(p + Vector3(0, 3.4, 0), Vector3(1.1, 1.2, 1.1), stone)
					mb.box(p + Vector3(0, 4.3, 0), Vector3(0.5, 0.6, 0.5), gold)
		if k == 0:
			# Lobby: tall bronze-framed entrance bay with a lit transom.
			var bronze := _mt(BRONZE)
			mb.box(Vector3(0, 5.0, zf - 0.05), Vector3(minf(bw * 0.3, 12.0), 10.0, 0.08), Civic._lit(Color(0.4, 0.34, 0.26)))
			_fins(mb, 0, zf + 0.5, minf(bw * 0.3, 12.0), 1.0, 0.0, 10.0, 1.6, 0.25, 0.3, bronze, 1, false)
			mb.box(Vector3(0, 10.4, zf - 0.4), Vector3(minf(bw * 0.3, 12.0) + 1.6, 0.8, 0.8), bronze)
		y0 = y1
	# Crown: two lit lanterns with gold fins, a gilded pyramid and a needle.
	var cz2 := bc + (bd - bd * 0.44) * 0.12
	var l1 := bd * 0.34
	var l2 := bd * 0.24
	var tiers := [[h * 0.82, h * 0.875, l1], [h * 0.875, h * 0.92, l2]]
	for t: Array in tiers:
		var ya: float = t[0]
		var yb: float = t[1]
		var s: float = t[2]
		mb.box(Vector3(0, (ya + yb) * 0.5, cz2), Vector3(s, yb - ya, s), lit)
		_fins(mb, 0, cz2, s, s, ya, yb, 1.5, 0.3, 0.3, gold, 15, true)
		_band(mb, 0, cz2, s, s, yb - 0.6, 0.6, 0.5, gold)
		mb.box(Vector3(0, yb + 0.02, cz2), Vector3(s + 1.0, 0.04, s + 1.0), gold)
	var py := h * 0.92
	Kit._hip(mb, Vector3(0, py, cz2), l2 * 0.9, l2 * 0.9, h * 0.04, gold)
	_spire(mb, Vector3(0, py + h * 0.035, cz2), h * 0.045, 0.45, gold)
	# A thin lit edge on each setback (floodlight wash at night).
	for k in range(1, 4):
		var s: float = scales[k]
		var cz := bc + (bd - bd * s) * 0.12
		_band(mb, 0, cz, bw * s, bd * s, h * fracs[k] - 2.2, 0.5, 0.65, Civic._lit(Color(0.9, 0.8, 0.6)))
	_plaza(mb, out, w, -d * 0.5, zf, rng, 1)


## A rooftop helipad on a steel frame, deck s across with its top at c:
## dark deck with a safety-net shelf, a white edge line and H, a yellow
## touchdown ring, perimeter lights, a windsock and an access stair down
## to the roof at `roof`.
static func _helipad(mb, c: Vector3, s: float, roof: float) -> void:
	var leg := _mt(Color(0.4, 0.42, 0.44))
	var hs := s * 0.5
	for sx: float in [-1.0, 0.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			mb.box(Vector3(c.x + sx * (hs - 0.6), (roof + c.y) * 0.5, c.z + sz * (hs - 0.6)), Vector3(0.45, c.y - roof, 0.45), leg)
	mb.box(Vector3(c.x, c.y - 0.25, c.z), Vector3(s, 0.5, s), MeshBuilder.glow(Color(0.36, 0.4, 0.38), MeshBuilder.CONCRETE))
	var net := Color(0.16, 0.17, 0.18)
	for sx: float in [-1.0, 1.0]:
		mb.box(Vector3(c.x + sx * (hs + 0.55), c.y - 0.4, c.z), Vector3(1.1, 0.04, s + 2.2), net)
		mb.box(Vector3(c.x, c.y - 0.4, c.z + sx * (hs + 0.55)), Vector3(s, 0.04, 1.1), net)
	var white := Color(0.95, 0.95, 0.92)
	for sx: float in [-1.0, 1.0]:
		mb.box(Vector3(c.x + sx * (hs - 0.6), c.y + 0.01, c.z), Vector3(0.35, 0.02, s - 0.9), white)
		mb.box(Vector3(c.x, c.y + 0.01, c.z + sx * (hs - 0.6)), Vector3(s - 0.9, 0.02, 0.35), white)
	Civic._ring(mb, c + Vector3(0, 0.02, 0), s * 0.3, s * 0.3 + 0.5, YELLOW, 24)
	var hh := s * 0.3
	mb.box(c + Vector3(-hh * 0.33, 0.03, 0), Vector3(hh * 0.16, 0.02, hh * 0.95), white)
	mb.box(c + Vector3(hh * 0.33, 0.03, 0), Vector3(hh * 0.16, 0.02, hh * 0.95), white)
	mb.box(c + Vector3(0, 0.03, 0), Vector3(hh * 0.6, 0.02, hh * 0.16), white)
	var light := _lamp(Color(0.5, 1.0, 0.55))
	for f: float in [-0.66, 0.0, 0.66]:
		var a := f * (hs - 0.3)
		for p: Vector3 in [Vector3(a, 0, -hs + 0.25), Vector3(a, 0, hs - 0.25), Vector3(-hs + 0.25, 0, a), Vector3(hs - 0.25, 0, a)]:
			mb.box(c + p + Vector3(0, 0.06, 0), Vector3(0.22, 0.12, 0.22), light)
	# Windsock on the back-right corner, flying toward +X.
	var ws := c + Vector3(hs - 0.4, 0, hs - 0.4)
	mb.cylinder(ws, 0.06, 2.6, white, 4)
	mb.limb(ws + Vector3(0, 2.5, 0), ws + Vector3(-1.4, 2.3, 0), 0.28, 0.12, AVIATION, 6, false)
	# Access stair down the back edge.
	Kit._beam(mb, Vector3(c.x - hs * 0.5, c.y - 0.3, c.z + hs + 0.2), Vector3(c.x - hs * 0.5 - (c.y - roof) * 1.1, roof + 0.2, c.z + hs + 0.2), 0.18, _mt(Color(0.5, 0.52, 0.54)), 1.1)


## Flat-topped granite tower with a rooftop helipad (80-130 m roof, deck
## about 2.5 m above it): ribbon windows, darker corner reveals and a glass
## slot down the front and back, a recessed two-storey lobby behind a row
## of piers, a darker machine-floor band at the top.
static func skyscraper_helipad(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var h := _height("skyscraper_helipad", rng)
	var cc: Color = _pick(CLADDING, rng)
	var clad := Civic._stone(cc)
	var dark := Civic._stone(cc.darkened(0.3))
	var glass := _gl(_pick(GLASSES, rng))
	var zf := -d * 0.5 + clampf(d * 0.2, 5.0, 10.0)
	var zb := d * 0.5 - 1.0
	var sw := (w - 2.0) * 0.82
	var sd := (zb - zf) * 0.9
	var cz := zb - sd * 0.5
	var fz := cz - sd * 0.5
	const LH := 9.0
	# Recessed lobby behind piers.
	_solid(mb, out, Vector3(0, LH * 0.5, cz + 1.0), Vector3(sw - 3.2, LH, sd - 2.0), clad)
	_lobby(mb, -sw * 0.36, sw * 0.36, fz + 2.0, 6.0, 0.0, _mt(Color(0.3, 0.32, 0.35)))
	var np := maxi(3, int(sw / 7.0))
	for i in np + 1:
		var x := -sw * 0.5 + 0.6 + (sw - 1.2) * i / np
		_solid(mb, out, Vector3(x, LH * 0.5, fz + 0.6), Vector3(1.2, LH, 1.2), clad)
	for sx: float in [-1.0, 1.0]:
		mb.box(Vector3(sx * (sw * 0.5 - 0.6), LH * 0.5, cz + 0.6), Vector3(1.2, LH, sd - 1.2), clad)
	# Shaft: cladding with a ribbon window each floor.
	mb.box(Vector3(0, (LH + h) * 0.5, cz), Vector3(sw, h - LH, sd), clad)
	out.append([Vector3(0, (LH + h) * 0.5, cz), Vector3(sw, h - LH, sd)])
	var y := LH + 1.0
	while y < h - 5.0:
		_band(mb, 0, cz, sw, sd, y, 2.1, 0.03, glass)
		y += 3.9
	_band(mb, 0, cz, sw, sd, h - 4.2, 4.2, 0.05, dark)
	_fins(mb, 0, cz, sw, sd, LH, h, 1000.0, 0.1, 0.3, dark, 0, true)
	for f in [1, 2]:
		var zz := cz - sd * 0.5 - 0.06 if f == 1 else cz + sd * 0.5 + 0.06
		var n := Vector3.FORWARD if f == 1 else Vector3.BACK
		Civic._panel(mb, Vector3(0, (LH + h - 4.2) * 0.5, zz), Vector3.RIGHT, n, Vector2(sw * 0.12, h - LH - 4.2), glass)
	# Roof: membrane and parapet, plant at the back, the pad over the front.
	_cap(mb, 0, cz, sw, sd, h, dark, ROOF_GREY, 1.2)
	var s := minf(sw, sd) - 3.4
	var pz := cz - sd * 0.5 + s * 0.5 + 1.7
	_helipad(mb, Vector3(0, h + 2.6, pz), s, h)
	var back := pz + s * 0.5 + 1.2
	if cz + sd * 0.5 - back > 2.6:
		Buildings._hvac(mb, Vector3(sw * 0.2, h, (back + cz + sd * 0.5) * 0.5), Vector3(minf(sw * 0.35, 7.0), 1.4, 2.0))
		Buildings._stair_hut(mb, Vector3(sw * 0.5 - 1.8, h, cz + sd * 0.5 - 1.6), dark)
	_corner_beacons(mb, 0, cz, sw, sd, h + 1.2)
	_plaza(mb, out, w, -d * 0.5, zf, rng)


## A sloped top on a sw x sd block at y0, rising `rise` toward +X (dir 1)
## or -X (dir -1), with slim frame bars down the slope.
static func _wedge(mb, cx: float, cz: float, sw: float, sd: float, y0: float, rise: float, dir: float, color: Color, frame: Color) -> void:
	var lo := cx - sw * 0.5 * dir
	var hi := cx + sw * 0.5 * dir
	var z0 := cz - sd * 0.5
	var z1 := cz + sd * 0.5
	var y1 := y0 + rise
	var n := Vector3(-dir * rise, sw, 0).normalized()
	mb.quad(Vector3(lo, y0, z0), Vector3(hi, y1, z0), Vector3(hi, y1, z1), Vector3(lo, y0, z1), n, color)
	mb.quad(Vector3(hi, y0, z0), Vector3(hi, y0, z1), Vector3(hi, y1, z1), Vector3(hi, y1, z0), Vector3(dir, 0, 0), color)
	mb.tri(Vector3(lo, y0, z0), Vector3(hi, y0, z0), Vector3(hi, y1, z0), Vector3.FORWARD, color)
	mb.tri(Vector3(lo, y0, z1), Vector3(hi, y0, z1), Vector3(hi, y1, z1), Vector3.BACK, color)
	var bars := maxi(2, int(sd / 3.0))
	for i in bars + 1:
		var z := z0 + 0.1 + (sd - 0.2) * i / bars
		Kit._beam(mb, Vector3(lo, y0 + 0.08, z), Vector3(hi, y1 + 0.08, z), 0.18, frame)


## Twin towers (90-120 m, sloped glass tops up to +40 % of the tower width)
## joined by a glazed sky bridge with a steel truss: a stone podium with a
## glass atrium between the towers and a roof garden in front of it.
static func skyscraper_twin(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var h := _height("skyscraper_twin", rng)
	var h2 := h if rng.randf() < 0.6 else h * rng.randf_range(0.9, 0.96)
	var glass := _gl(_pick(GLASSES, rng))
	var band := _mt(_pick(SPANDRELS, rng))
	var fin := _mt(_pick(FRAMES, rng))
	var stone := Civic._stone(_pick(CLADDING, rng))
	var zf := -d * 0.5 + clampf(d * 0.16, 5.0, 10.0)
	var zb := d * 0.5 - 1.0
	var pw := w - 2.0
	var pd := zb - zf
	var pc := (zf + zb) * 0.5
	const PH := 12.0
	var tw := pw * 0.33
	var td := pd * 0.62
	var tz := zb - td * 0.5 - 1.2
	var tx := pw * 0.5 - tw * 0.5 - 0.6
	# Podium: stone wings under the towers and a glass atrium between.
	for sx: float in [-1.0, 1.0]:
		_solid(mb, out, Vector3(sx * (pw * 0.5 - tw * 0.5 - 0.3), PH * 0.5, pc), Vector3(tw + 0.6, PH, pd), stone)
		_cap(mb, sx * (pw * 0.5 - tw * 0.5 - 0.3), pc, tw + 0.6, pd, PH, stone, ROOF_TAN, 0.9)
	var aw := pw - (tw + 0.6) * 2.0
	_solid(mb, out, Vector3(0, PH * 0.4, pc + 1.0), Vector3(aw, PH * 0.8, pd - 2.0), _gl(_pick(GLASSES, rng)))
	_fins(mb, 0, pc + 1.0, aw, pd - 2.0, 0.0, PH * 0.8, 2.4, 0.15, 0.2, fin, 1, false)
	_lobby(mb, -aw * 0.4, aw * 0.4, pc + 1.0 - (pd - 2.0) * 0.5, 5.0, 2.0, fin)
	var rib := maxi(3, int((pd - 2.0) / 3.0))
	for i in rib + 1:
		var z := pc + 1.0 - (pd - 2.0) * 0.5 + (pd - 2.0) * i / rib
		mb.box(Vector3(0, PH * 0.8 + 0.12, z), Vector3(aw, 0.22, 0.22), fin)
	# The towers, sloped tops rising toward the middle or outward.
	var inward := rng.randf() < 0.5
	for k in 2:
		var sx := -1.0 if k == 0 else 1.0
		var ht := h if k == 0 else h2
		_curtain(mb, out, sx * tx, tz, tw, td, PH, ht, glass, band, fin, 3.8, 2.6)
		_band(mb, sx * tx, tz, tw, td, ht - 0.8, 0.8, 0.32, fin)
		var dir := -sx if inward else sx
		_wedge(mb, sx * tx, tz, tw, td, ht, tw * 0.4, dir, glass, fin)
		var peak := Vector3(sx * tx + dir * (tw * 0.5 - 0.5), ht + tw * 0.4, tz)
		_beacon(mb, peak, 0.45)
		mb.cylinder(peak + Vector3(0, 0.4, 0), 0.12, 4.0, _mt(STEEL), 4)
		_beacon(mb, peak + Vector3(0, 4.4, 0), 0.3)
	# Sky bridge between the inner faces.
	var by := minf(h, h2) * rng.randf_range(0.45, 0.6)
	var gx := tx - tw * 0.5
	var bd := minf(td * 0.6, 8.0)
	var steel := _mt(Color(0.62, 0.64, 0.67))
	mb.box(Vector3(0, by + 3.0, tz), Vector3(gx * 2.0, 5.0, bd), _gl(Color(0.42, 0.5, 0.56)))
	for sz: float in [-1.0, 1.0]:
		var fz := tz + sz * (bd * 0.5 + 0.15)
		mb.box(Vector3(0, by + 0.4, fz), Vector3(gx * 2.0, 0.8, 0.3), steel)
		mb.box(Vector3(0, by + 5.6, fz), Vector3(gx * 2.0, 0.8, 0.3), steel)
		var bays := maxi(2, int(gx * 2.0 / 3.2))
		for i in bays:
			var xa := -gx + gx * 2.0 * i / bays
			var xb := -gx + gx * 2.0 * (i + 1) / bays
			var up := i % 2 == 0
			Kit._beam(mb, Vector3(xa, by + (0.8 if up else 5.2), fz), Vector3(xb, by + (5.2 if up else 0.8), fz), 0.25, steel)
	mb.box(Vector3(0, by + 0.02, tz), Vector3(gx * 2.0, 0.04, bd + 0.6), _lamp(Color(0.85, 0.9, 1.0)))
	mb.box(Vector3(0, by + 6.05, tz), Vector3(gx * 2.0, 0.1, bd + 0.6), MeshBuilder.glow(ROOF_GREY, MeshBuilder.ROOF))
	# Garden on the atrium's front roof strip and the forecourt.
	var gz0 := pc - pd * 0.5 + 0.6
	var gz1 := tz - td * 0.5 - 0.6
	if gz1 - gz0 > 2.0:
		for sx: float in [-1.0, 1.0]:
			mb.box(Vector3(sx * tx, PH + 0.08, (gz0 + gz1) * 0.5), Vector3(tw - 1.2, 0.06, gz1 - gz0), Civic._grass(LAWN))
			Kit._bush(mb, Vector3(sx * tx, PH + 0.1, gz0 + 0.8), 0.9, rng)
	_plaza(mb, out, w, -d * 0.5, zf, rng)


## 1970s office slab (60-90 m roof, antennas up to +10 m): a wide, thin
## block of dark glass behind close-set precast fins on the long faces,
## blank end walls, standing on round pilotis over a recessed lobby; a long
## louvred penthouse with antennas; a deep plaza with a big fountain.
static func skyscraper_slab(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var h := _height("skyscraper_slab", rng)
	var pc: Color = _pick(PRECAST, rng)
	var concrete := Civic._stone(pc)
	var glass := _gl(_pick([Color(0.2, 0.22, 0.24), Color(0.36, 0.3, 0.22), Color(0.26, 0.32, 0.36)], rng))
	var sw := w - 4.0
	var sd := clampf(d * 0.42, 11.0, 18.0)
	var zb := d * 0.5 - 1.5
	var cz := zb - sd * 0.5
	const PIL := 7.0
	# Lobby inset under the slab, pilotis front and back.
	_solid(mb, out, Vector3(0, PIL * 0.5, cz), Vector3(sw - 6.0, PIL, sd - 5.0), Civic._lit(Color(0.36, 0.38, 0.38)))
	_fins(mb, 0, cz, sw - 6.0, sd - 5.0, 0.0, PIL, 3.0, 0.14, 0.12, _mt(Color(0.3, 0.3, 0.32)), 3, false)
	var nc := maxi(3, roundi(sw / 6.6))
	for i in nc + 1:
		var x := -sw * 0.5 + 0.8 + (sw - 1.6) * i / nc
		for sz: float in [-1.0, 1.0]:
			var p := Vector3(x, 0, cz + sz * (sd * 0.5 - 0.8))
			mb.cylinder(p, 0.55, PIL, concrete, 8)
			out.append([p + Vector3(0, PIL * 0.5, 0), Vector3(1.1, PIL, 1.1)])
	# Transfer beam, the slab and its fins.
	mb.box(Vector3(0, PIL + 0.8, cz), Vector3(sw, 1.6, sd), concrete)
	mb.box(Vector3(0, (PIL + h) * 0.5 + 0.8, cz), Vector3(sw - 2.4, h - PIL - 1.6, sd), glass)
	out.append([Vector3(0, (PIL + h) * 0.5, cz), Vector3(sw, h - PIL, sd)])
	for sx: float in [-1.0, 1.0]:
		mb.box(Vector3(sx * (sw * 0.5 - 0.6), (PIL + h) * 0.5 + 0.8, cz), Vector3(1.2, h - PIL - 1.6, sd + 0.4), concrete)
	var y := PIL + 1.6 + 2.6
	while y < h - 1.5:
		_band(mb, 0, cz, sw - 2.4, sd, y, 1.0, 0.02, concrete, 3)
		y += 3.6
	_fins(mb, 0, cz, sw - 2.4, sd, PIL + 1.6, h, 1.7, 0.3, 0.9, concrete, 3, false)
	_band(mb, 0, cz, sw, sd, h - 1.4, 1.4, 0.95, concrete, 3)
	# Roof: parapet, long penthouse, antennas.
	_cap(mb, 0, cz, sw, sd, h, concrete, ROOF_GREY, 1.0)
	_penthouse(mb, 0, cz + sd * 0.08, sw * 0.55, sd * 0.5, h, 5.0, concrete)
	for k in rng.randi_range(2, 3):
		var p := Vector3(-sw * 0.2 + sw * 0.2 * k, h + 5.0, cz + sd * 0.08)
		var ah := rng.randf_range(4.0, 8.0)
		mb.cylinder(p, 0.12, ah, Color(0.62, 0.62, 0.64), 4)
		_beacon(mb, p + Vector3(0, ah, 0), 0.3)
	_bmu(mb, -sw * 0.5 + 1.6, sw * 0.5 - 1.6, cz - sd * 0.5 + 1.3, h)
	_corner_beacons(mb, 0, cz, sw, sd, h + 1.0)
	_plaza(mb, out, w, -d * 0.5, cz - sd * 0.5, rng, 0)


## Mid-rise office or hotel tower (30-55 m roof) over three or four decks
## of podium parking: open garage decks with concrete parapets, a lobby and
## a garage entrance at the street; on the podium roof a pool deck with
## loungers and palms (hotel) or rooftop parking (office); a glass tower
## or a stucco tower with balconies and a lit crown band.
static func highrise_mid(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var h := _height("highrise_mid", rng)
	var hotel := rng.randf() < 0.5
	var concrete := Civic._stone(_pick(PRECAST, rng))
	var zf := -d * 0.5 + clampf(d * 0.12, 3.5, 6.0)
	var zb := d * 0.5 - 0.8
	var pw := w - 1.6
	var pd := zb - zf
	var pc := (zf + zb) * 0.5
	var levels := 3 if h < 42.0 else 4
	const LH := 3.1
	var ph := levels * LH
	# Garage: dark decks behind concrete parapet bands and columns.
	mb.box(Vector3(0, ph * 0.5, pc), Vector3(pw - 0.6, ph, pd - 0.6), Color(0.2, 0.2, 0.22))
	out.append([Vector3(0, ph * 0.5, pc), Vector3(pw, ph, pd)])
	for k in levels:
		_band(mb, 0, pc, pw - 0.6, pd - 0.6, LH * (k + 1) - 1.05, 1.05, 0.3, concrete)
	_fins(mb, 0, pc, pw - 0.6, pd - 0.6, 0.0, ph - 1.05, 7.5, 0.6, 0.3, concrete, 13, true)
	# Street level: lobby on the left, garage mouth with a barrier on the right.
	_lobby(mb, -pw * 0.45, -pw * 0.05, zf, 2.0, 0.0, _mt(Color(0.3, 0.32, 0.35)))
	mb.box(Vector3(pw * 0.25, 1.3, zf - 0.32), Vector3(6.0, 2.6, 0.06), DARK)
	mb.box(Vector3(pw * 0.25, 1.0, zf - 0.6), Vector3(5.0, 0.12, 0.12), _gloss(Color(0.95, 0.85, 0.2)))
	# Podium roof.
	mb.box(Vector3(0, ph + 0.02, pc), Vector3(pw, 0.04, pd), Civic._paving(Color(0.68, 0.66, 0.62)) if hotel else MeshBuilder.glow(Color(0.42, 0.42, 0.44), MeshBuilder.ASPHALT))
	for sx: float in [-1.0, 1.0]:
		mb.box(Vector3(sx * (pw * 0.5 - 0.15), ph + 0.5, pc), Vector3(0.3, 1.0, pd), concrete)
		mb.box(Vector3(0, ph + 0.5, pc + sx * (pd * 0.5 - 0.15)), Vector3(pw - 0.6, 1.0, 0.3), concrete)
	var tw := pw * 0.6
	var td := pd * 0.42
	var tz := zb - td * 0.5 - 1.0
	var fz := pc - pd * 0.5 + 1.0
	var front := tz - td * 0.5 - 1.0
	if hotel:
		var pool := Vector3(-pw * 0.12, ph, (fz + front) * 0.5)
		var pl := minf(pw * 0.45, 14.0)
		var pdp := minf(front - fz - 2.0, 6.0)
		if pdp > 2.0:
			mb.box(pool + Vector3(0, 0.12, 0), Vector3(pl + 1.0, 0.2, pdp + 1.0), Civic._stone(Color(0.9, 0.88, 0.82)))
			mb.box(pool + Vector3(0, 0.23, 0), Vector3(pl, 0.04, pdp), _gl(POOL))
			for i in 4:
				var lx := pool.x - pl * 0.5 + pl * (i + 0.5) / 4.0
				mb.box(Vector3(lx, ph + 0.25, pool.z + pdp * 0.5 + 1.4), Vector3(0.7, 0.3, 1.8), WHITE)
			for sx: float in [-1.0, 1.0]:
				var up := Vector3(pool.x + sx * (pl * 0.5 + 2.4), ph, pool.z)
				mb.cylinder(up, 0.04, 2.2, Color(0.85, 0.85, 0.85), 4)
				mb.ball(up + Vector3(0, 2.25, 0), Vector3(1.3, 0.3, 1.3), _pick(Buildings.PARASOLS, rng), 8, 2)
			Civic._palm(mb, out, Vector3(pw * 0.38, ph, (fz + front) * 0.5), rng)
	else:
		# Rooftop parking: two rows of cars on painted stalls.
		var x0 := -pw * 0.5 + 1.5
		var n := int((pw - 3.0) / 2.6)
		for row in 2:
			var z := fz + 0.4 + row * 5.2
			if z + 4.8 > front:
				break
			for i in n:
				var x := x0 + 2.6 * (i + 0.5)
				mb.box(Vector3(x - 1.3, ph + 0.06, z + 2.4), Vector3(0.1, 0.02, 4.8), Kit.LINE)
				if rng.randf() < 0.65:
					_car(mb, Vector3(x, ph, z + 2.4), PI if row == 0 else 0.0, _pick(CAR_PAINTS, rng))
		for sx: float in [-1.0, 1.0]:
			Civic._pole_lamp(mb, out, Vector3(sx * (pw * 0.5 - 1.0), ph, front - 0.6), 4.0)
	# The tower.
	if hotel:
		var stucco := Civic._stone(_pick(STUCCO, rng))
		var glass := _gl(_pick([Color(0.3, 0.42, 0.5), Color(0.26, 0.36, 0.4)], rng))
		mb.box(Vector3(0, (ph + h) * 0.5, tz), Vector3(tw, h - ph, td), stucco)
		out.append([Vector3(0, (ph + h) * 0.5, tz), Vector3(tw, h - ph, td)])
		var y := ph + 1.0
		while y < h - 2.0:
			_band(mb, 0, tz, tw, td, y, 1.7, 0.03, glass)
			mb.box(Vector3(0, y - 0.1, tz - td * 0.5 - 0.7), Vector3(tw - 2.0, 0.2, 1.4), stucco)
			y += 3.1
		_fins(mb, 0, tz - td * 0.5 - 0.7, tw - 2.0, 1.4, ph, h - 1.0, 4.0, 0.12, 0.1, Civic._stone(Color(0.9, 0.9, 0.9)), 1, false)
		_cap(mb, 0, tz, tw, td, h, stucco, ROOF_TAN, 1.0)
		_band(mb, 0, tz, tw, td, h - 0.8, 0.5, 0.06, _neon(_pick(ACCENT_LIGHTS, rng)))
		Buildings._hvac(mb, Vector3(-tw * 0.2, h, tz + td * 0.15), Vector3(minf(tw * 0.35, 6.0), 1.2, 2.0))
		Buildings._stair_hut(mb, Vector3(tw * 0.5 - 1.8, h, tz + td * 0.5 - 1.8), stucco)
		_beacon(mb, Vector3(tw * 0.25, h + 1.0, tz), 0.3)
	else:
		_curtain(mb, out, 0, tz, tw, td, ph, h, _gl(_pick(GLASSES, rng)), _mt(_pick(SPANDRELS, rng)), _mt(_pick(FRAMES, rng)), 3.6, 3.4)
		var edge := _mt(_pick(FRAMES, rng))
		_cap(mb, 0, tz, tw, td, h, edge, ROOF_GREY, 1.0)
		Buildings._hvac(mb, Vector3(-tw * 0.15, h, tz + td * 0.1), Vector3(minf(tw * 0.4, 7.0), 1.4, 2.2))
		Buildings._stair_hut(mb, Vector3(tw * 0.5 - 1.8, h, tz + td * 0.5 - 1.8), edge)
		_corner_beacons(mb, 0, tz, tw, td, h + 1.0)
	# Forecourt: planters and bollards along the kerb, a lamp.
	Kit._pad(mb, -w * 0.5, w * 0.5, -d * 0.5, zf, Civic._paving(PAVER), 0.03)
	if zf + d * 0.5 > 2.6:
		for sx: float in [-1.0, 1.0]:
			Props.planter(mb, out, Vector3(sx * w * 0.32, 0.03, (zf - d * 0.5) * 0.5))
		Civic._pole_lamp(mb, out, Vector3(-w * 0.5 + 1.0, 0.03, -d * 0.5 + 1.0))


# --- Monuments ------------------------------------------------------------------

## Blocky glyphs for the hillside letters, 4 cells wide by 5 tall (top row
## first). Consonant-like shapes only, so nine of them never spell a word.
const GLYPHS := [
	"1000100010001000" + "1111", # L-like
	"1111011001100110" + "0110", # T-like
	"1111100011101000" + "1000", # F-like
	"1001100111111001" + "1001", # H-like
	"1110100111101000" + "1000", # P-like
	"1001110110111001" + "1001", # N-like
	"1111000101101000" + "1111", # Z-like
	"1001101011001010" + "1001", # K-like
	"0111000100011001" + "0110", # J-like
	"1001111111111001" + "1001", # M-like
]


## Hillside letters (lot about 120 x 30): nine giant white sheet-metal
## letter panels, about 13 m tall, leaning back on scaffold frames whose
## legs reach 2 m below y = 0 into the slope; floodlights at their feet, a
## service track and scrub. The glyphs are a shuffle of consonant shapes.
static func hillside_letters(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var order := range(GLYPHS.size())
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t: int = order[i]
		order[i] = order[j]
		order[j] = t
	var cell := (w - 4.0) / 9.0
	var lw := cell * 0.8
	var lh := clampf(lw * 1.32, 6.0, minf(16.0, d * 0.6))
	var lean := 0.17
	var zp := -d * 0.5 + clampf(d * 0.3, 3.0, 10.0)
	var white_base := Color(0.95, 0.95, 0.93)
	var steel := _mt(Color(0.42, 0.42, 0.4))
	var cw := lw / 4.0
	var ch := lh / 5.0
	const BASE := 0.6
	const LEG := -2.0
	for k in 9:
		var g: String = GLYPHS[order[k]]
		var x := -w * 0.5 + 2.0 + cell * (k + 0.5)
		var white := white_base.darkened(rng.randf() * 0.06)
		var saved: Transform3D = mb.xform
		mb.xform = saved * Transform3D(Basis(Vector3.RIGHT, lean), Vector3(x, BASE, zp))
		for r in 5:
			var c := 0
			while c < 4:
				if g[r * 4 + c] != "1":
					c += 1
					continue
				var c0 := c
				while c < 4 and g[r * 4 + c] == "1":
					c += 1
				# Mirrored: the glyphs are read from the front (-Z), where +x
				# is on the viewer's left.
				var x0 := lw * 0.5 - c * cw
				var x1 := lw * 0.5 - c0 * cw
				var y1 := lh - r * ch
				mb.box(Vector3((x0 + x1) * 0.5, y1 - ch * 0.5, 0), Vector3(x1 - x0, ch + 0.02, 0.35), white)
		mb.xform = saved
		# Scaffold: three posts behind the panel, rails, struts to the
		# panel's back and raking braces into the hill.
		var top_z := zp + sin(lean) * lh
		var pz := top_z + 0.8
		var post_h := BASE + cos(lean) * lh * 0.92
		for px: float in [-lw * 0.36, 0.0, lw * 0.36]:
			mb.box(Vector3(x + px, (LEG + post_h) * 0.5, pz), Vector3(0.3, post_h - LEG, 0.3), steel)
			Kit._beam(mb, Vector3(x + px, BASE + lh * 0.45, pz), Vector3(x + px, BASE + cos(lean) * lh * 0.45, zp + sin(lean) * lh * 0.45 + 0.2), 0.16, steel)
			Kit._beam(mb, Vector3(x + px, post_h * 0.6, pz), Vector3(x + px, LEG + 0.15, pz + minf(5.0, d * 0.5 - pz - 0.5)), 0.2, steel)
		for ry: float in [post_h * 0.35, post_h * 0.78]:
			mb.box(Vector3(x, ry, pz), Vector3(lw * 0.72 + 0.3, 0.18, 0.18), steel)
		# Legs under the panel's foot.
		for px: float in [-lw * 0.4, lw * 0.4]:
			mb.box(Vector3(x + px, (LEG + BASE) * 0.5, zp + 0.1), Vector3(0.3, BASE - LEG, 0.3), steel)
		out.append([Vector3(x, 1.5, (zp + pz) * 0.5), Vector3(lw, 3.0, pz - zp + 0.6)])
		# Two floodlights in front of each letter.
		for px: float in [-lw * 0.25, lw * 0.25]:
			var f := Vector3(x + px, 0, zp - 2.4)
			mb.box(f + Vector3(0, 0.3, 0), Vector3(0.5, 0.6, 0.4), _mt(Color(0.3, 0.3, 0.32)))
			mb.box(f + Vector3(0, 0.45, 0.21), Vector3(0.36, 0.3, 0.04), _lamp())
	# Service track behind the letters and scrub on the slope.
	var tz := minf(d * 0.5 - 1.5, zp + sin(lean) * lh + 5.5)
	Kit._pad(mb, -w * 0.5 + 1.0, w * 0.5 - 1.0, tz - 1.2, tz + 1.2, MeshBuilder.glow(Color(0.62, 0.55, 0.44), MeshBuilder.ASPHALT), 0.02)
	var scrub := [Color(0.42, 0.44, 0.26), Color(0.5, 0.48, 0.3), Color(0.36, 0.4, 0.24)]
	for i in 26:
		var p := Vector3(rng.randf_range(-w * 0.5 + 2.0, w * 0.5 - 2.0), 0, rng.randf_range(-d * 0.5 + 1.5, d * 0.5 - 1.5))
		if absf(p.z - tz) < 2.0 or absf(p.z - zp) < 3.0:
			continue
		Kit._bush(mb, p, rng.randf_range(0.6, 1.3), rng, _pick(scrub, rng))


## Hilltop observatory (lot about 70 x 50): a long cream art-deco hall
## with a central copper dome (its shutter slit facing the front) on a
## drum, two end towers with smaller domes, a lawn and a central
## figure-less monument pillar topped by a gilt armillary sphere, a
## terrace wall with coin telescopes, lamps, benches and pines.
static func observatory(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var cream := Civic._stone(Color(0.9, 0.86, 0.76))
	var trim := Civic._stone(Color(0.8, 0.76, 0.66))
	var copper := _mt(VERDIGRIS)
	var dark := Color(0.14, 0.15, 0.17)
	Kit._pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, Civic._paving(Color(0.82, 0.78, 0.7)), 0.02)
	var bw := w * 0.64
	var bd := clampf(d * 0.26, 9.0, 16.0)
	var bz := d * 0.5 - 2.5 - bd * 0.5
	const BH := 9.0
	# Hall with pilasters and tall windows, flat roof.
	_solid(mb, out, Vector3(0, BH * 0.5, bz), Vector3(bw, BH, bd), cream)
	_fins(mb, 0, bz, bw, bd, 0.0, BH - 0.6, 3.2, 0.7, 0.25, trim, 15, false)
	_band(mb, 0, bz, bw, bd, BH - 1.2, 1.2, 0.35, trim)
	_cap(mb, 0, bz, bw, bd, BH, trim, ROOF_TAN, 0.7)
	var nwin := maxi(2, roundi(bw / 3.2))
	for i in nwin:
		var x := -bw * 0.5 + bw * (i + 0.5) / nwin
		if absf(x) < 7.5:
			continue
		Civic._panel(mb, Vector3(x, 4.2, bz - bd * 0.5 - 0.04), Vector3.RIGHT, Vector3.FORWARD, Vector2(1.4, 4.6), Civic._lit(Color(0.32, 0.36, 0.4)))
	# Central pavilion, drum and dome.
	var cw := minf(bw * 0.32, 16.0)
	var dr := cw * 0.46
	_solid(mb, out, Vector3(0, (BH + 3.0) * 0.5, bz), Vector3(cw, BH + 3.0, bd + 1.6), cream)
	_band(mb, 0, bz, cw, bd + 1.6, BH + 1.6, 1.4, 0.35, trim)
	mb.box(Vector3(0, 3.0, bz - bd * 0.5 - 0.85), Vector3(4.0, 6.0, 0.1), Civic._lit(Color(0.42, 0.36, 0.26)))
	_fins(mb, 0, bz - bd * 0.5 - 0.3, 6.4, 1.0, 0.0, 7.0, 1.6, 0.5, 0.3, trim, 1, false)
	mb.cylinder(Vector3(0, BH + 3.0, bz), dr + 0.4, 2.2, trim, 20)
	var dc := Vector3(0, BH + 5.2, bz)
	Civic._dome(mb, dc, dr, dr * 0.95, copper, _mt(VERDIGRIS.lightened(0.15)), 20, 5, 10)
	# Shutter slit down the front of the dome.
	for k in 5:
		var t0 := PI * 0.5 * k / 5.0
		var t1 := PI * 0.5 * (k + 1) / 5.0
		var a0 := -PI * 0.5 - 0.09
		var a1 := -PI * 0.5 + 0.09
		var n := Vector3(0, sin((t0 + t1) * 0.5), -cos((t0 + t1) * 0.5))
		mb.quad(Civic._dome_pt(dc, dr + 0.2, dr * 0.95 + 0.2, a0, t0), Civic._dome_pt(dc, dr + 0.2, dr * 0.95 + 0.2, a1, t0), Civic._dome_pt(dc, dr + 0.2, dr * 0.95 + 0.2, a1, t1), Civic._dome_pt(dc, dr + 0.2, dr * 0.95 + 0.2, a0, t1), n, dark)
	# End towers with small domes.
	for sx: float in [-1.0, 1.0]:
		var tx := sx * (bw * 0.5 - 4.0)
		_solid(mb, out, Vector3(tx, (BH + 2.5) * 0.5, bz), Vector3(8.0, BH + 2.5, 8.0), cream)
		_band(mb, tx, bz, 8.0, 8.0, BH + 1.3, 1.2, 0.3, trim)
		mb.cylinder(Vector3(tx, BH + 2.5, bz), 3.4, 0.8, trim, 16)
		Civic._dome(mb, Vector3(tx, BH + 3.3, bz), 3.1, 3.0, copper, copper, 16, 4, 0)
	# Lawn and the monument pillar on the axis.
	var lz0 := -d * 0.5 + 4.0
	var lz1 := bz - bd * 0.5 - 4.0
	var lw := minf(w * 0.5, 34.0)
	for sx: float in [-1.0, 1.0]:
		mb.box(Vector3(sx * (lw * 0.25 + 1.5), 0.05, (lz0 + lz1) * 0.5), Vector3(lw * 0.5 - 3.0, 0.04, lz1 - lz0), Civic._grass(LAWN))
	var mz := (lz0 + lz1) * 0.5
	var granite := Civic._stone(GRANITE.lightened(0.1))
	for k in 3:
		mb.box(Vector3(0, 0.2 + k * 0.4, mz), Vector3(5.0 - k * 1.2, 0.4, 5.0 - k * 1.2), granite)
	Civic._frustum(mb, 0, mz, 0.9, 0.6, 1.2, 12.0, cream)
	mb.box(Vector3(0, 12.2, mz), Vector3(1.6, 0.4, 1.6), granite)
	var gilt := _mt(GOLD)
	var sp := Vector3(0, 13.6, mz)
	mb.ball(sp, Vector3(0.55, 0.55, 0.55), gilt, 8, 4)
	_hoop(mb, sp, 1.0, 0.08, gilt, 12)
	var saved: Transform3D = mb.xform
	mb.xform = saved * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO)
	_hoop(mb, Vector3(-mz, 13.6, 0), 1.0, 0.08, gilt, 12)
	mb.xform = saved
	out.append([Vector3(0, 6.0, mz), Vector3(2.6, 12.0, 2.6)])
	# Terrace wall round the front and sides, coin telescopes, lamps, benches.
	var wall := Civic._stone(Color(0.78, 0.74, 0.66))
	var hw := w * 0.5 - 0.4
	var hd := d * 0.5 - 0.4
	for sx: float in [-1.0, 1.0]:
		_solid(mb, out, Vector3(sx * (hw + 3.0) * 0.5, 0.5, -hd), Vector3(hw - 3.0, 1.0, 0.6), wall)
		_solid(mb, out, Vector3(sx * hw, 0.5, 0), Vector3(0.6, 1.0, d - 0.8), wall)
	for i in 6:
		var x := lerpf(-hw + 4.0, hw - 4.0, i / 5.0)
		if absf(x) < 4.0:
			continue
		var p := Vector3(x, 0, -hd + 1.0)
		mb.cylinder(p, 0.08, 1.1, _mt(Color(0.4, 0.42, 0.44)), 5)
		Kit._beam(mb, p + Vector3(0, 1.2, 0.2), p + Vector3(0, 1.45, -0.4), 0.28, _gloss(Color(0.2, 0.3, 0.55)))
	for sx: float in [-1.0, 1.0]:
		Civic._globe_lamp(mb, out, Vector3(sx * 4.5, 0.02, -hd + 2.0))
		Civic._globe_lamp(mb, out, Vector3(sx * 4.5, 0.02, lz1 + 1.5))
		Props.bench(mb, out, Vector3(sx * (lw * 0.5 + 2.0), 0.02, mz), sx * PI * 0.5)
		for k in 3:
			var p := Vector3(sx * (w * 0.5 - 4.0), 0.02, lerpf(-hd + 5.0, bz - bd * 0.5 - 2.0, k / 2.0))
			Props.street_tree(mb, out, p, rng)


## Ellipse helpers: a point at angle a on radii (rx, rz) round (0, cz).
static func _ep(cz: float, rx: float, rz: float, a: float, y := 0.0) -> Vector3:
	return Vector3(cos(a) * rx, y, cz + sin(a) * rz)


## A flat elliptical ring (or a filled ellipse when r0 is zero) facing up,
## from angle a0 to a1.
static func _ering(mb, cz: float, rx0: float, rz0: float, rx1: float, rz1: float, y: float, color: Color, segs := 48, a0 := 0.0, a1 := TAU) -> void:
	for i in segs:
		var t0 := lerpf(a0, a1, float(i) / segs)
		var t1 := lerpf(a0, a1, float(i + 1) / segs)
		if rx0 <= 0.0:
			mb.tri(Vector3(0, y, cz), _ep(cz, rx1, rz1, t0, y), _ep(cz, rx1, rz1, t1, y), Vector3.UP, color)
		else:
			mb.quad(_ep(cz, rx0, rz0, t0, y), _ep(cz, rx1, rz1, t0, y), _ep(cz, rx1, rz1, t1, y), _ep(cz, rx0, rz0, t1, y), Vector3.UP, color)


## An arch head through a wall from z0 (front) to z1 (back): the spandrels
## on both faces between the springing line and the crown (spring plus
## half the span x0..x1), and the soffit. `segs` must be even.
static func _arch_head(mb, x0: float, x1: float, z0: float, z1: float, spring: float, color: Color, soffit: Color, segs := 8) -> void:
	var r := (x1 - x0) * 0.5
	var xm := x0 + r
	var top := spring + r
	for i in segs:
		var t0 := PI * i / segs
		var t1 := PI * (i + 1) / segs
		var p0 := Vector2(xm + cos(t0) * r, spring + sin(t0) * r)
		var p1 := Vector2(xm + cos(t1) * r, spring + sin(t1) * r)
		var corner := Vector2(x1, top) if i < segs / 2 else Vector2(x0, top)
		mb.tri(Vector3(p0.x, p0.y, z0), Vector3(p1.x, p1.y, z0), Vector3(corner.x, corner.y, z0), Vector3.FORWARD, color)
		mb.tri(Vector3(p0.x, p0.y, z1), Vector3(p1.x, p1.y, z1), Vector3(corner.x, corner.y, z1), Vector3.BACK, color)
		var tm := (t0 + t1) * 0.5
		mb.quad(Vector3(p0.x, p0.y, z0), Vector3(p1.x, p1.y, z0), Vector3(p1.x, p1.y, z1), Vector3(p0.x, p0.y, z1), Vector3(-cos(tm), -sin(tm), 0), soffit)


## Oval coliseum (lot about 180 x 150): a horseshoe bowl of raked seating
## in alternating row colours behind an arcaded outer wall, open at the
## front where a straight peristyle of arches (the middle one wider) closes
## it, crowned by a stepped pylon carrying a bronze torch with a lit flame;
## a grass field with mown stripes, a running track and lines, four
## floodlight masts, an abstract colour-block scoreboard, and a forecourt
## with palms and lamps.
static func coliseum(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var cz := d * 0.04
	var rx := w * 0.5 - 2.0
	var rz := d * 0.5 - 2.0 - cz
	var sc := clampf(minf(w / 180.0, d / 150.0), 0.7, 1.3)
	var H := 20.0 * sc
	var rxi := rx * 0.56
	var rzi := rz * 0.5
	var rxo := rx - 2.0
	var rzo := rz - 2.0
	const G := 0.62
	var a0 := -PI * 0.5 + G
	var a1 := PI * 1.5 - G
	const N := 44
	const K := 10
	var concrete := Civic._stone(Color(0.84, 0.8, 0.72))
	var shade := Civic._stone(Color(0.7, 0.66, 0.58))
	var arch_dark := Color(0.18, 0.17, 0.16)
	var seat_a: Color = _pick(SEATS, rng)
	var seat_b := seat_a.lightened(0.12)
	Kit._pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, Civic._paving(PAVER), 0.02)
	# Field: track ring, grass with stripes, lines.
	_ering(mb, cz, rxi * 0.88, rzi * 0.84, rxi, rzi, 0.05, MeshBuilder.glow(TRACK, MeshBuilder.ASPHALT), 40)
	_ering(mb, cz, 0.0, 0.0, rxi * 0.88, rzi * 0.84, 0.06, Civic._grass(Color(0.36, 0.56, 0.27)), 40)
	for k in 2:
		var f := 0.91 + k * 0.045
		_ering(mb, cz, rxi * f, rzi * (0.84 + (f - 0.88) * 1.33), rxi * f + 0.15, rzi * (0.84 + (f - 0.88) * 1.33) + 0.15, 0.07, WHITE, 40)
	var fx := rxi * 0.62
	var fz := rzi * 0.5
	for sx: float in [-1.0, 1.0]:
		mb.box(Vector3(sx * fx, 0.08, cz), Vector3(0.3, 0.02, fz * 2.0), WHITE)
		mb.box(Vector3(0, 0.08, cz + sx * fz), Vector3(fx * 2.0, 0.02, 0.3), WHITE)
		mb.box(Vector3(sx * fx * 0.8, 0.08, cz), Vector3(0.3, 0.02, fz * 2.0), WHITE)
	mb.box(Vector3(0, 0.08, cz), Vector3(0.3, 0.02, fz * 2.0), WHITE)
	# Seating bowl: K raked bands round the horseshoe.
	var ry := func(f: float) -> float: return lerpf(1.6, H, f)
	for k in K:
		var f0 := float(k) / K
		var f1 := float(k + 1) / K
		var y0: float = ry.call(f0)
		var y1: float = ry.call(f1)
		for i in N:
			var t0 := lerpf(a0, a1, float(i) / N)
			var t1 := lerpf(a0, a1, float(i + 1) / N)
			var p00 := _ep(cz, lerpf(rxi, rxo, f0), lerpf(rzi, rzo, f0), t0, y0)
			var p01 := _ep(cz, lerpf(rxi, rxo, f0), lerpf(rzi, rzo, f0), t1, y0)
			var p10 := _ep(cz, lerpf(rxi, rxo, f1), lerpf(rzi, rzo, f1), t0, y1)
			var p11 := _ep(cz, lerpf(rxi, rxo, f1), lerpf(rzi, rzo, f1), t1, y1)
			var n := (p01 - p00).cross(p10 - p00).normalized()
			if n.y < 0.0:
				n = -n
			var c := seat_a if k % 2 == 0 else seat_b
			if (i / 4) % 2 == 1:
				c = c.darkened(0.08)
			if k == 4:
				c = shade
			mb.quad(p00, p01, p11, p10, n, c)
	# Field wall, walkway on top, outer arcaded wall with pilasters.
	for i in N:
		var t0 := lerpf(a0, a1, float(i) / N)
		var t1 := lerpf(a0, a1, float(i + 1) / N)
		var tm := (t0 + t1) * 0.5
		var q0 := _ep(cz, rxi, rzi, t0)
		var q1 := _ep(cz, rxi, rzi, t1)
		var inward := -Vector3(cos(tm) / rxi, 0, sin(tm) / rzi).normalized()
		mb.quad(q0, q1, q1 + Vector3(0, 1.6, 0), q0 + Vector3(0, 1.6, 0), inward, shade)
		var o0 := _ep(cz, rx, rz, t0)
		var o1 := _ep(cz, rx, rz, t1)
		var outward := Vector3(cos(tm) / rx, 0, sin(tm) / rz).normalized()
		mb.quad(o0, o1, o1 + Vector3(0, H + 1.2, 0), o0 + Vector3(0, H + 1.2, 0), outward, concrete)
		mb.quad(_ep(cz, rxo, rzo, t0, H), _ep(cz, rx, rz, t0, H), _ep(cz, rx, rz, t1, H), _ep(cz, rxo, rzo, t1, H), Vector3.UP, Civic._paving(Color(0.74, 0.72, 0.66)))
		mb.quad(_ep(cz, rx - 0.5, rz - 0.5, t0, H), _ep(cz, rx - 0.5, rz - 0.5, t1, H), _ep(cz, rx - 0.5, rz - 0.5, t1, H + 1.2), _ep(cz, rx - 0.5, rz - 0.5, t0, H + 1.2), -outward, concrete)
		mb.quad(_ep(cz, rx - 0.5, rz - 0.5, t0, H + 1.2), _ep(cz, rx, rz, t0, H + 1.2), _ep(cz, rx, rz, t1, H + 1.2), _ep(cz, rx - 0.5, rz - 0.5, t1, H + 1.2), Vector3.UP, concrete)
		var u := (o1 - o0).normalized()
		var span := o0.distance_to(o1)
		var mid := (o0 + o1) * 0.5
		Civic._arch_open(mb, mid, u, outward, span * 0.55, H * 0.36, arch_dark, 4)
		Civic._arch_open(mb, mid + Vector3(0, H * 0.48, 0), u, outward, span * 0.5, H * 0.32, arch_dark, 4)
		Civic._rbox(mb, o0 + outward * 0.2 + Vector3(0, (H + 1.2) * 0.5, 0), Vector3(1.0, H + 1.2, 0.4), atan2(u.x, u.z) + PI * 0.5, concrete)
	# Close the bowl's two cut ends.
	for e in 2:
		var ta := a0 if e == 0 else a1
		var tn := Vector3(-sin(ta) * rx, 0, cos(ta) * rz).normalized() * (-1.0 if e == 0 else 1.0)
		for k in K:
			var f0 := float(k) / K
			var f1 := float(k + 1) / K
			var b0 := _ep(cz, lerpf(rxi, rxo, f0), lerpf(rzi, rzo, f0), ta)
			var b1 := _ep(cz, lerpf(rxi, rxo, f1), lerpf(rzi, rzo, f1), ta)
			mb.quad(b0, b1, b1 + Vector3(0, ry.call(f1), 0), b0 + Vector3(0, ry.call(f0), 0), tn, shade)
		var w0 := _ep(cz, rxo, rzo, ta)
		var w1 := _ep(cz, rx, rz, ta)
		mb.quad(w0, w1, w1 + Vector3(0, H + 1.2, 0), w0 + Vector3(0, H + 1.2, 0), tn, concrete)
	# Bowl colliders: 16 sectors from the field wall to the outer wall.
	const SECT := 16
	for j in SECT:
		var s0 := lerpf(a0, a1, float(j) / SECT)
		var s1 := lerpf(a0, a1, float(j + 1) / SECT)
		var sm := (s0 + s1) * 0.5
		var pi_ := _ep(cz, rxi, rzi, sm)
		var po := _ep(cz, rx, rz, sm)
		var dir := (po - pi_).normalized()
		var chord := _ep(cz, rx, rz, s0).distance_to(_ep(cz, rx, rz, s1))
		out.append([(pi_ + po) * 0.5 + Vector3(0, H * 0.5, 0), Vector3(chord, H, pi_.distance_to(po)), atan2(dir.x, dir.z)])
	# Peristyle across the open end.
	var xe := rx * sin(G)
	var zp := cz - rz * cos(G)
	var pdp := 5.0
	var hp := H + 3.0
	var top := hp - 4.0
	const OPEN := 9
	var pier := 2.6
	var unit := (xe * 2.0 - pier * (OPEN + 1)) / (OPEN - 1 + 1.6)
	var x := -xe
	var stone := Civic._stone(Color(0.9, 0.86, 0.78))
	var soffit := Civic._stone(Color(0.66, 0.62, 0.55))
	for i in OPEN + 1:
		_solid(mb, out, Vector3(x + pier * 0.5, top * 0.5, zp), Vector3(pier, top, pdp), stone)
		mb.box(Vector3(x + pier * 0.5, top * 0.5, zp - pdp * 0.5 - 0.2), Vector3(pier * 0.5, top - 1.0, 0.4), stone.lightened(0.05))
		x += pier
		if i == OPEN:
			break
		var ow := unit * (1.6 if i == OPEN / 2 else 1.0)
		_arch_head(mb, x, x + ow, zp - pdp * 0.5, zp + pdp * 0.5, top - ow * 0.5, stone, soffit, 8)
		x += ow
	mb.box(Vector3(0, (top + hp) * 0.5, zp), Vector3(xe * 2.0, hp - top, pdp), stone)
	mb.box(Vector3(0, hp + 0.3, zp), Vector3(xe * 2.0 + 0.8, 0.6, pdp + 0.8), stone.darkened(0.04))
	mb.box(Vector3(0, hp + 0.62, zp), Vector3(xe * 2.0, 0.04, pdp), MeshBuilder.glow(ROOF_TAN, MeshBuilder.ROOF))
	# Pylon and torch over the middle arch.
	var bronze := _mt(BRONZE)
	mb.box(Vector3(0, hp + 1.6, zp), Vector3(16.0 * sc, 2.0, pdp), stone)
	mb.box(Vector3(0, hp + 4.6, zp), Vector3(7.0 * sc, 4.0, pdp * 0.8), stone)
	mb.box(Vector3(0, hp + 9.0, zp), Vector3(4.0 * sc, 4.8, pdp * 0.6), stone.lightened(0.04))
	var tb := Vector3(0, hp + 11.4, zp)
	mb.cylinder(tb, 0.5, 1.2, bronze, 8)
	mb.ball(tb + Vector3(0, 1.6, 0), Vector3(1.6, 0.6, 1.6), bronze, 10, 3)
	var flame := _neon(Color(1.0, 0.55, 0.15))
	mb.limb(tb + Vector3(0, 1.9, 0), tb + Vector3(0.2, 4.4, 0.1), 0.9, 0.05, flame, 6, false)
	mb.limb(tb + Vector3(-0.4, 1.9, 0.2), tb + Vector3(-0.6, 3.4, 0.3), 0.5, 0.04, _neon(Color(1.0, 0.8, 0.3)), 5, false)
	# Floodlight masts on the rim and a scoreboard at the back.
	for a: float in [-PI * 0.25, PI * 0.25, PI * 0.75, PI * 1.25]:
		var p := _ep(cz, rx - 1.2, rz - 1.2, a, H + 1.2)
		mb.box(p + Vector3(0, 8.0, 0), Vector3(0.8, 16.0, 0.8), _mt(Color(0.55, 0.57, 0.6)))
		var yaw := atan2(-p.x, -(p.z - cz))
		Civic._rbox(mb, p + Vector3(0, 16.5, 0), Vector3(6.0, 3.0, 0.5), yaw, _mt(Color(0.3, 0.32, 0.34)))
		var inw := Vector3(-p.x, 0, -(p.z - cz)).normalized()
		Civic._rbox(mb, p + Vector3(0, 16.5, 0) + inw * 0.28, Vector3(5.4, 2.4, 0.06), yaw, _lamp())
	var sb := _ep(cz, rx - 1.5, rz - 1.5, PI * 0.5, H + 1.2)
	mb.box(sb + Vector3(0, 4.5, 0), Vector3(18.0 * sc, 7.0, 1.0), Color(0.12, 0.13, 0.15))
	var blocks := [Color(0.2, 0.5, 1.0), Color(1.0, 0.6, 0.2), Color(0.3, 0.9, 0.5)]
	for k in 3:
		mb.box(sb + Vector3((k - 1) * 5.4 * sc, 4.5, -0.52), Vector3(4.6 * sc, 5.0, 0.04), _neon(blocks[k]))
	for sx: float in [-1.0, 1.0]:
		mb.box(sb + Vector3(sx * 7.0 * sc, 0.5, 0), Vector3(0.6, 1.0, 0.6), _mt(STEEL))
	# Forecourt: palms and lamps before the peristyle.
	var fz0 := -d * 0.5 + 3.0
	for i in 4:
		var px := lerpf(-xe + 6.0, xe - 6.0, i / 3.0)
		Civic._palm(mb, out, Vector3(px, 0.02, fz0 + 2.0), rng)
	for sx: float in [-1.0, 1.0]:
		Civic._globe_lamp(mb, out, Vector3(sx * 9.0, 0.02, zp - pdp * 0.5 - 4.0))


## Memorial arch in a small plaza (lot about 40 x 30): a triumphal-style
## stone arch with one tall passage, engaged columns on pedestals, dark
## niches, a cornice and an attic with plain relief panels, crowned by an
## abstract bronze sculpture; an eternal flame under the arch, paved rings,
## lawn corners, flower beds, globe lamps, benches and floodlights.
static func memorial_arch(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var stone := Civic._stone(LIMESTONE.darkened(rng.randf() * 0.06))
	var soffit := Civic._stone(LIMESTONE.darkened(0.25))
	var granite := Civic._stone(GRANITE.lightened(0.18))
	var bronze := _mt(BRONZE)
	Kit._pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, Civic._paving(PAVER), 0.02)
	var r := minf(w, d) * 0.5 - 1.0
	Civic._ring(mb, Vector3(0, 0.04, 0), r - 0.8, r, granite, 32)
	Civic._ring(mb, Vector3(0, 0.04, 0), r * 0.55, r * 0.55 + 0.6, granite, 32)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var c := Vector3(sx * (w * 0.5 - 3.0), 0.05, sz * (d * 0.5 - 3.0))
			mb.box(c, Vector3(4.6, 0.04, 4.6), Civic._grass(LAWN))
			Kit._bush(mb, c + Vector3(-sx * 1.2, 0, -sz * 1.2), 0.8, rng, Color(0.62, 0.3, 0.42))
	var aw := clampf(w * 0.52, 12.0, 24.0)
	var ad := clampf(d * 0.3, 5.0, 10.0)
	var ah := aw * 1.05
	var half := aw * 0.18
	var spring := ah * 0.4
	var crown := spring + half
	var ent := crown + ah * 0.06
	var z0 := -ad * 0.5
	var z1 := ad * 0.5
	# Piers, the arch head, the wall above it.
	for sx: float in [-1.0, 1.0]:
		var pc := sx * (half + aw * 0.5) * 0.5
		_solid(mb, out, Vector3(pc, ent * 0.5, 0), Vector3(aw * 0.5 - half, ent, ad), stone)
		mb.box(Vector3(pc, 0.5, 0), Vector3(aw * 0.5 - half + 0.4, 1.0, ad + 0.4), granite)
		mb.box(Vector3(sx * (half + 0.3), spring - 0.3, 0), Vector3(0.6, 0.6, ad + 0.2), stone.lightened(0.04))
	_arch_head(mb, -half, half, z0, z1, spring, stone, soffit, 10)
	mb.box(Vector3(0, (crown + ent) * 0.5, 0), Vector3(half * 2.0, ent - crown, ad), stone)
	mb.box(Vector3(0, crown - 0.4, z0 - 0.15), Vector3(1.0, 1.6, 0.3), stone.lightened(0.06))
	# Columns on pedestals, niches between them, on both faces.
	var pier_w := aw * 0.5 - half
	for f: float in [-1.0, 1.0]:
		var zf := f * (ad * 0.5 + 0.55)
		var n := Vector3(0, 0, f)
		for sx: float in [-1.0, 1.0]:
			for xo: float in [0.18, 0.82]:
				var x := sx * (half + pier_w * xo)
				mb.box(Vector3(x, 1.2, zf), Vector3(1.4, 2.4, 1.1), stone)
				Civic._column(mb, Vector3(x, 2.4, zf), ent - 2.4, 0.45, stone, 8, true)
			var nx := sx * (half + pier_w * 0.5)
			Civic._arch_open(mb, Vector3(nx, 3.0, f * ad * 0.5), Vector3.RIGHT, n, pier_w * 0.34, spring * 0.7, Color(0.2, 0.19, 0.17), 4)
	for sx: float in [-1.0, 1.0]:
		Civic._arch_open(mb, Vector3(sx * aw * 0.5, 2.0, 0), Vector3(0, 0, 1), Vector3(sx, 0, 0), ad * 0.45, spring * 0.8, Color(0.2, 0.19, 0.17), 4)
	# Cornice, attic, relief panels and the crowning sculpture.
	mb.box(Vector3(0, ent + 0.7, 0), Vector3(aw + 1.2, 1.4, ad + 1.4), stone.lightened(0.03))
	var attic := ah - ent - 1.4
	mb.box(Vector3(0, ent + 1.4 + attic * 0.5, 0), Vector3(aw * 0.94, attic, ad * 0.94), stone)
	mb.box(Vector3(0, ah + 0.3, 0), Vector3(aw * 0.98, 0.6, ad), stone.lightened(0.03))
	for f: float in [-1.0, 1.0]:
		for k in 3:
			var pw := aw * (0.36 if k == 1 else 0.2)
			var px := (k - 1) * aw * 0.31
			mb.box(Vector3(px, ent + 1.4 + attic * 0.5, f * (ad * 0.47 + 0.2)), Vector3(pw, attic * 0.6, 0.4), stone.lightened(0.14))
			mb.box(Vector3(px, ent + 1.4 + attic * 0.5, f * (ad * 0.47 + 0.42)), Vector3(pw * 0.8, attic * 0.42, 0.06), stone.darkened(0.12))
	mb.box(Vector3(0, ah + 1.2, 0), Vector3(aw * 0.36, 1.2, ad * 0.5), bronze)
	_sculpture(mb, Vector3(0, ah + 1.8, 0), clampf(ah * 0.3, 4.0, 8.0), rng.randi(), bronze)
	# Eternal flame under the arch, floodlights at the feet.
	mb.cylinder(Vector3(0, 0, 0), 1.0, 0.5, granite, 12)
	mb.ball(Vector3(0, 0.8, 0), Vector3(0.9, 0.35, 0.9), bronze, 10, 3)
	mb.limb(Vector3(0, 0.95, 0), Vector3(0.1, 2.2, 0), 0.5, 0.04, _neon(Color(1.0, 0.55, 0.15)), 6, false)
	out.append([Vector3(0, 0.5, 0), Vector3(2.0, 1.0, 2.0)])
	for f: float in [-1.0, 1.0]:
		for sx: float in [-1.0, 1.0]:
			var p := Vector3(sx * aw * 0.35, 0, f * (ad * 0.5 + 2.6))
			mb.box(p + Vector3(0, 0.25, 0), Vector3(0.6, 0.5, 0.5), _mt(Color(0.3, 0.3, 0.32)))
			mb.box(p + Vector3(0, 0.52, 0), Vector3(0.46, 0.04, 0.36), _lamp())
	# Lamps, benches facing the arch, bollards across the front.
	for sx: float in [-1.0, 1.0]:
		Civic._globe_lamp(mb, out, Vector3(sx * (aw * 0.5 + 3.0), 0.02, -d * 0.5 + 2.0))
		Civic._globe_lamp(mb, out, Vector3(sx * (aw * 0.5 + 3.0), 0.02, d * 0.5 - 2.0))
		Props.bench(mb, out, Vector3(sx * (aw * 0.5 + 3.5), 0.02, 0), sx * PI * 0.5)
	for i in 8:
		var x := lerpf(-w * 0.5 + 2.0, w * 0.5 - 2.0, i / 7.0)
		if absf(x) < aw * 0.5:
			continue
		mb.box(Vector3(x, 0.45, -d * 0.5 + 0.6), Vector3(0.3, 0.9, 0.3), granite)


## Statue on a plinth (lot about 20 x 20): a round paved plaza in a lawn,
## three square granite steps, a tall polished plinth with plain bronze
## plaques and a cornice, an abstract bronze sculpture on top (no figure),
## chain bollards, globe lamps on the diagonals and benches facing in.
static func statue_plinth(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var r := minf(w, d) * 0.5 - 0.3
	var granite := Civic._stone(GRANITE)
	var polished := MeshBuilder.glow(Color(0.26, 0.25, 0.27), MeshBuilder.GLOSS)
	var bronze := _mt(BRONZE.lerp(Color(0.35, 0.42, 0.36), rng.randf() * 0.5))
	Kit._pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, Civic._grass(LAWN), 0.02)
	Civic._disc(mb, Vector3(0, 0.04, 0), r, Civic._paving(PAVER), 28)
	Civic._ring(mb, Vector3(0, 0.05, 0), r - 0.5, r, granite, 28)
	var s0 := clampf(r * 0.9, 5.0, 11.0)
	for k in 3:
		mb.box(Vector3(0, 0.2 + k * 0.4, 0), Vector3(s0 - k * 1.1, 0.4, s0 - k * 1.1), granite.lightened(0.04 * k))
	var pw := clampf(s0 * 0.36, 2.0, 4.0)
	var ph := clampf(r * 0.65, 4.0, 7.5)
	mb.box(Vector3(0, 1.45, 0), Vector3(pw + 0.6, 0.5, pw + 0.6), granite)
	mb.box(Vector3(0, 1.7 + ph * 0.5, 0), Vector3(pw, ph, pw), polished)
	mb.box(Vector3(0, 1.7 + ph + 0.25, 0), Vector3(pw + 0.5, 0.5, pw + 0.5), granite)
	for o: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		var u := Vector3(-o.z, 0, o.x)
		Civic._panel(mb, Vector3(0, 1.7 + ph * 0.45, 0) + o * (pw * 0.5 + 0.03), u, o, Vector2(pw * 0.55, ph * 0.3), bronze)
	out.append([Vector3(0, (1.7 + ph) * 0.5, 0), Vector3(s0, 1.7 + ph, s0)])
	_sculpture(mb, Vector3(0, 2.2 + ph, 0), clampf(ph * 0.9, 3.5, 7.0), rng.randi(), bronze)
	# Chain bollards round the steps.
	var br := s0 * 0.5 + 1.0
	var iron := _gloss(Color(0.14, 0.15, 0.15))
	for i in 12:
		var a0 := TAU * i / 12.0 + PI / 12.0
		var a1 := TAU * (i + 1) / 12.0 + PI / 12.0
		var p0 := Vector3(cos(a0) * br, 0, sin(a0) * br)
		var p1 := Vector3(cos(a1) * br, 0, sin(a1) * br)
		mb.box(p0 + Vector3(0, 0.4, 0), Vector3(0.22, 0.8, 0.22), iron)
		if i != 9:
			Kit._beam(mb, p0 + Vector3(0, 0.65, 0), p1 + Vector3(0, 0.65, 0), 0.06, iron)
	for q in 4:
		var a := PI * 0.25 + q * PI * 0.5
		Civic._globe_lamp(mb, out, Vector3(cos(a), 0, sin(a)) * (r * 0.8) + Vector3(0, 0.04, 0))
		var b := q * PI * 0.5
		if q == 3:
			continue # the path in from the front (-Z) stays open
		var p := Vector3(cos(b), 0, sin(b)) * (r * 0.78) + Vector3(0, 0.04, 0)
		Props.bench(mb, out, p, atan2(cos(b), sin(b)))


## One suspension-bridge tower (lot about 30 x 12, 36 m to the saddles):
## two stepped art-deco legs at the lot's long edges (z = +-(d/2 - 1),
## so the clear width between them is d - 3.6 m) on concrete footings,
## joined by three portal beams; saddles on top carry the two main cables
## sweeping down toward +-x to the lot ends, with vertical suspenders down
## to 1 m. The bridge deck is assumed at y = 0 and runs along x through
## the portal. Used in pairs on Morrow Bridge.
static func suspension_tower(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	const H := 36.0
	var paint := _gloss(_pick(BRIDGE_PAINTS, rng))
	var groove := MeshBuilder.glow((paint as Color).darkened(0.35), MeshBuilder.GLOSS)
	var footing := Civic._stone(Color(0.66, 0.65, 0.62))
	var zl := d * 0.5 - 1.0
	var tiers := [[0.0, 13.0, 2.4, 2.0], [13.0, 25.0, 2.1, 1.8], [25.0, 34.6, 1.8, 1.6]]
	for sz: float in [-1.0, 1.0]:
		var z := sz * zl
		mb.box(Vector3(0, 0.6, z), Vector3(3.4, 1.2, 2.0), footing)
		for t: Array in tiers:
			var y0: float = t[0]
			var y1: float = t[1]
			var tw: float = t[2]
			var td: float = t[3]
			mb.box(Vector3(0, (y0 + y1) * 0.5, z), Vector3(tw, y1 - y0, td), paint)
			for sx: float in [-1.0, 1.0]:
				mb.box(Vector3(sx * (tw * 0.5 + 0.02), (y0 + y1) * 0.5, z), Vector3(0.04, y1 - y0 - 1.2, td * 0.3), groove)
		out.append([Vector3(0, H * 0.5, z), Vector3(2.4, H, 2.0)])
		# Saddle and aviation light.
		mb.box(Vector3(0, 35.3, z), Vector3(2.6, 1.4, 1.8), paint)
		_beacon(mb, Vector3(0, 36.0, z), 0.4)
	# Portal beams with grooves.
	var inner := zl - 0.8
	for b: Array in [[33.0, 2.4], [24.0, 1.6], [14.0, 1.4]]:
		var by: float = b[0]
		var bh: float = b[1]
		mb.box(Vector3(0, by, 0), Vector3(1.6, bh, inner * 2.0), paint)
		for sx: float in [-1.0, 1.0]:
			for k in 3:
				mb.box(Vector3(sx * 0.82, by, (k - 1) * inner * 0.6), Vector3(0.04, bh * 0.55, inner * 0.35), groove)
	# Main cables and suspenders toward both ends.
	var cable := _gloss((paint as Color).darkened(0.1))
	var reach := w * 0.5 - 0.3
	for sz: float in [-1.0, 1.0]:
		var z := sz * zl
		for sx: float in [-1.0, 1.0]:
			var prev := Vector3(sx * 1.0, 35.6, z)
			for k in range(1, 4):
				var t := reach * k / 3.0
				var p := Vector3(sx * t, 35.6 - 0.45 * t - 0.006 * t * t, z)
				Kit._beam(mb, prev, p, 0.55, cable)
				prev = p
			var s := 3.0
			while s < reach - 0.2:
				var cy := 35.6 - 0.45 * s - 0.006 * s * s
				mb.box(Vector3(sx * s, (cy + 1.0) * 0.5, z), Vector3(0.08, cy - 1.0, 0.08), cable)
				s += 3.0
	# Floodlights at the footings, aimed up the legs.
	for sz: float in [-1.0, 1.0]:
		for sx: float in [-1.0, 1.0]:
			mb.box(Vector3(sx * 1.4, 1.35, sz * zl), Vector3(0.4, 0.3, 0.4), _lamp())


## Lattice radio mast on a hill (lot about 20 x 20, 56-62 m plus a 4 m
## whip): a triangular steel lattice painted in aviation red and white
## bands with red lights at three levels and a top beacon, panel and drum
## antennas, three sets of guy wires to concrete anchors, a gravel compound
## with a chain-link fence and gate, an equipment hut and two dishes.
static func radio_mast(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var h := _height("radio_mast", rng)
	var hw := w * 0.5 - 0.3
	var hd := d * 0.5 - 0.3
	Kit._pad(mb, -hw, hw, -hd, hd, MeshBuilder.glow(Color(0.6, 0.57, 0.52), MeshBuilder.ASPHALT), 0.02)
	# Mast: three legs, zigzag bracing and rings, in eight paint bands.
	var rr := 1.1
	var legs: Array = []
	for k in 3:
		var a := -PI * 0.5 + TAU * k / 3.0
		legs.append(Vector3(cos(a) * rr, 0, sin(a) * rr))
	var red := _gloss(AVIATION)
	var white := _gloss(WHITE)
	mb.box(Vector3(0, 0.3, 0), Vector3(3.2, 0.6, 3.2), Civic._stone(Color(0.7, 0.69, 0.66)))
	const BANDS := 8
	var bh := h / BANDS
	for b in BANDS:
		var c := red if b % 2 == 0 else white
		var y0 := b * bh
		for p: Vector3 in legs:
			mb.box(Vector3(p.x, y0 + bh * 0.5, p.z), Vector3(0.18, bh, 0.18), c)
	var panel := 3.0
	var np := int(h / panel)
	for i in np:
		var y0 := i * panel
		var y1 := y0 + panel
		var c := red if int(y0 / bh) % 2 == 0 else white
		for k in 3:
			var p: Vector3 = legs[k]
			var q: Vector3 = legs[(k + 1) % 3]
			var up := i % 2 == 0
			Kit._beam(mb, p + Vector3(0, y0 if up else y1, 0), q + Vector3(0, y1 if up else y0, 0), 0.11, c)
			Kit._beam(mb, p + Vector3(0, y1, 0), q + Vector3(0, y1, 0), 0.11, c)
	# Whip and lights.
	mb.cylinder(Vector3(0, h, 0), 0.1, 4.0, white, 4)
	_beacon(mb, Vector3(0, h + 4.0, 0), 0.5)
	for f: float in [0.33, 0.66, 0.97]:
		for p: Vector3 in legs:
			_beacon(mb, Vector3(p.x * 1.15, h * f, p.z * 1.15), 0.3)
	# Panel antennas near the top, drum dishes lower down.
	for k in 3:
		var a := -PI * 0.5 + TAU * (k + 0.5) / 3.0
		var o := Vector3(cos(a), 0, sin(a))
		Civic._rbox(mb, o * 0.95 + Vector3(0, h * 0.86, 0), Vector3(0.6, 2.4, 0.2), atan2(o.x, o.z), Color(0.9, 0.9, 0.88))
	for k in 2:
		var a := -PI * 0.5 + TAU * (k + 0.5) / 3.0
		var o := Vector3(cos(a), 0, sin(a))
		var p := o * 0.9 + Vector3(0, h * (0.55 + k * 0.1), 0)
		mb.limb(p, p + o * 0.6, 0.75, 0.75, Color(0.9, 0.9, 0.88), 8)
	# Guy wires to three anchors.
	var ar := minf(hw, hd) - 0.8
	for k in 3:
		var a := PI * 0.5 + TAU * k / 3.0
		var anchor := Vector3(cos(a) * ar, 0, sin(a) * ar)
		mb.box(anchor + Vector3(0, 0.3, 0), Vector3(1.2, 0.6, 1.2), Civic._stone(Color(0.66, 0.65, 0.62)))
		var dir := Vector3(cos(a), 0, sin(a))
		var leg: Vector3 = legs[0]
		for p: Vector3 in legs:
			if p.dot(dir) > leg.dot(dir):
				leg = p
		for f: float in [0.33, 0.66, 0.95]:
			Kit._beam(mb, anchor + Vector3(0, 0.6, 0), leg + Vector3(0, h * f, 0), 0.08, Color(0.3, 0.3, 0.32))
	out.append([Vector3(0, 3.0, 0), Vector3(3.2, 6.0, 3.2)])
	# Equipment hut, dishes on frames.
	var hut := Vector3(-hw + 3.4, 0, hd - 2.6)
	_solid(mb, out, hut + Vector3(0, 1.5, 0), Vector3(5.0, 3.0, 3.4), Civic._stone(Color(0.76, 0.74, 0.7)))
	mb.box(hut + Vector3(0, 3.05, 0), Vector3(5.2, 0.1, 3.6), MeshBuilder.glow(ROOF_GREY, MeshBuilder.ROOF))
	mb.box(hut + Vector3(1.2, 1.05, -1.72), Vector3(0.9, 2.1, 0.06), _mt(Color(0.4, 0.44, 0.48)))
	Buildings._hvac(mb, hut + Vector3(-1.4, 3.0, 0.4), Vector3(1.4, 0.7, 1.0))
	for k in 2:
		Buildings._dish(mb, Vector3(hw - 2.2 - k * 2.4, 0.02, hd - 2.0))
	# Chain-link fence with a gate in the front.
	var mesh := Color(0.55, 0.57, 0.58)
	var post := _mt(Color(0.5, 0.52, 0.54))
	var fh := 2.2
	for side in 4:
		var a: Vector3
		var b: Vector3
		match side:
			0: a = Vector3(-hw, 0, -hd); b = Vector3(hw, 0, -hd)
			1: a = Vector3(hw, 0, -hd); b = Vector3(hw, 0, hd)
			2: a = Vector3(hw, 0, hd); b = Vector3(-hw, 0, hd)
			_: a = Vector3(-hw, 0, hd); b = Vector3(-hw, 0, -hd)
		var segs: Array = [[a, b]]
		if side == 0:
			segs = [[a, Vector3(-2.0, 0, -hd)], [Vector3(2.0, 0, -hd), b]]
		for sgm: Array in segs:
			var p0: Vector3 = sgm[0]
			var p1: Vector3 = sgm[1]
			Civic._fence_panel(mb, p0, p1, fh, mesh)
			var c := (p0 + p1) * 0.5 + Vector3(0, fh * 0.5, 0)
			out.append([c, Vector3(maxf(absf(p1.x - p0.x), 0.2), fh, maxf(absf(p1.z - p0.z), 0.2))])
			var n := maxi(1, int(p0.distance_to(p1) / 3.0))
			for i in n + 1:
				var p := p0.lerp(p1, float(i) / n)
				mb.box(p + Vector3(0, fh * 0.5 + 0.1, 0), Vector3(0.1, fh + 0.2, 0.1), post)
	mb.box(Vector3(-1.0, fh * 0.5, -hd + 0.1), Vector3(2.0, fh, 0.05), Color(0.62, 0.64, 0.65))
