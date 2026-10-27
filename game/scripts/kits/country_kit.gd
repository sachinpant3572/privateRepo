extends RefCounted
## Country, suburb, beach and landmark buildings for the streamed country
## layer (phase 2). Pure data in, mesh out: static functions only, no scene
## tree and no autoloads, so a tile builds on a worker thread.
##
## Every builder works in the lot frame: the lot spans x in [-w/2, w/2]
## (along the street) and z in [-d/2, d/2] (deep), the street at -Z, ground
## at y = 0. The caller sets mb.xform to place the lot. Collision boxes go to
## `out` as [center, size] or [center, size, yaw] like building_kit.gd; low
## decks and porches (under 0.7 m) and anything you walk under get none,
## only their posts. Everything is drawn from `rng` alone.

const MeshBuilder = preload("res://scripts/mesh_builder.gd")
const Buildings = preload("res://scripts/kits/building_kit.gd")
const Props = preload("res://scripts/kits/prop_kit.gd")

const KINDS := [
	# Rural.
	"farmhouse", "barn", "silos", "machine_shed", "trailer_home", "shack", "stilt_house",
	"water_tower", "windpump",
	# Roadside and town.
	"gas_station", "diner", "motel", "general_store", "truck_stop", "garage", "town_hall",
	"bar", "shopfront", "house", "mansion", "garden_apartments", "strip_mall",
	"police_station", "county_hospital", "airboat_dock", "airstrip_hangar",
	# Beach.
	"deco_hotel", "condo_tower", "beach_bar", "lifeguard_tower",
	# Landmarks (one each).
	"grain_elevators", "hollis_farm", "larkspur_vineyard", "gator_farm", "moonshine_still",
	"bellerive_general", "bus_terminal", "seaplane_base", "cruise_terminal", "torque_tone",
	"aurum_hangar",
]

## The usual lot of each kind: x along the street, y deep, metres.
const FOOTPRINTS := {
	"farmhouse": Vector2(24, 26), "barn": Vector2(20, 26), "silos": Vector2(16, 14),
	"machine_shed": Vector2(24, 18), "trailer_home": Vector2(12, 24), "shack": Vector2(10, 12),
	"stilt_house": Vector2(14, 16), "water_tower": Vector2(12, 12), "windpump": Vector2(8, 8),
	"gas_station": Vector2(36, 32), "diner": Vector2(24, 26), "motel": Vector2(42, 36),
	"general_store": Vector2(16, 20), "truck_stop": Vector2(72, 60), "garage": Vector2(22, 22),
	"town_hall": Vector2(30, 30), "bar": Vector2(22, 26), "shopfront": Vector2(9, 16),
	"house": Vector2(16, 24), "mansion": Vector2(52, 56), "garden_apartments": Vector2(42, 32),
	"strip_mall": Vector2(60, 44), "police_station": Vector2(30, 28),
	"county_hospital": Vector2(44, 40), "airboat_dock": Vector2(24, 30),
	"airstrip_hangar": Vector2(30, 30),
	"deco_hotel": Vector2(24, 24), "condo_tower": Vector2(32, 32), "beach_bar": Vector2(14, 12),
	"lifeguard_tower": Vector2(6, 6),
	"grain_elevators": Vector2(50, 40), "hollis_farm": Vector2(90, 80),
	"larkspur_vineyard": Vector2(80, 72), "gator_farm": Vector2(50, 44),
	"moonshine_still": Vector2(22, 22), "bellerive_general": Vector2(90, 70),
	"bus_terminal": Vector2(80, 56), "seaplane_base": Vector2(60, 56),
	"cruise_terminal": Vector2(120, 52), "torque_tone": Vector2(40, 36),
	"aurum_hangar": Vector2(72, 64),
}

const FLOOR := 3.2
const WHITE := Color(0.94, 0.93, 0.89)
const TRIM := Color(0.97, 0.96, 0.92)
const DARK := Color(0.1, 0.11, 0.13)
const PANE := Color(0.16, 0.2, 0.24)
const WOOD := Color(0.45, 0.31, 0.2)
const OLD_WOOD := Color(0.48, 0.44, 0.38)
const BARN_RED := Color(0.62, 0.17, 0.13)
const TIN := Color(0.64, 0.66, 0.68)
const RUST := Color(0.56, 0.33, 0.21)
const STEEL := Color(0.7, 0.72, 0.75)
const CONCRETE := Color(0.7, 0.69, 0.66)
const ASPHALT := Color(0.24, 0.24, 0.26)
const GRAVEL := Color(0.62, 0.59, 0.53)
const LAWN := Color(0.4, 0.58, 0.29)
const DIRT := Color(0.55, 0.45, 0.33)
const LINE := Color(0.92, 0.92, 0.88)
const YELLOW := Color(0.95, 0.8, 0.2)
const STRAW := Color(0.86, 0.74, 0.42)
const COPPER := Color(0.78, 0.45, 0.26)
const GOLD := Color(0.9, 0.72, 0.25)
const POOL := Color(0.3, 0.72, 0.85)
const SWAMP := Color(0.24, 0.3, 0.2)
const LEAF := Color(0.3, 0.44, 0.22)
const TERRACOTTA := Color(0.76, 0.42, 0.28)
const SHOP_GLASS := Color(0.55, 0.68, 0.72)
const PASTELS := [
	Color(0.96, 0.72, 0.74), Color(0.66, 0.88, 0.78), Color(0.8, 0.74, 0.92), Color(0.98, 0.8, 0.62),
	Color(0.68, 0.83, 0.95), Color(0.98, 0.92, 0.64), Color(0.58, 0.86, 0.85), Color(0.97, 0.93, 0.84),
]
const ACCENTS := [Color(0.1, 0.55, 0.6), Color(0.92, 0.42, 0.38), Color(0.2, 0.7, 0.75), Color(0.95, 0.45, 0.62), Color(0.3, 0.45, 0.75)]
const NEONS := [Color(1.0, 0.3, 0.55), Color(0.3, 0.85, 1.0), Color(1.0, 0.75, 0.2), Color(0.55, 1.0, 0.45), Color(0.8, 0.4, 1.0)]
const SHINGLES := [Color(0.36, 0.34, 0.33), Color(0.47, 0.4, 0.34), Color(0.52, 0.54, 0.56), Color(0.62, 0.6, 0.55), Color(0.3, 0.36, 0.42)]
const TIN_ROOFS := [Color(0.64, 0.66, 0.68), Color(0.55, 0.28, 0.22), Color(0.3, 0.45, 0.38), Color(0.38, 0.42, 0.5), Color(0.56, 0.33, 0.21)]
const SIDINGS := [Color(0.94, 0.93, 0.88), Color(0.95, 0.88, 0.62), Color(0.68, 0.8, 0.82), Color(0.78, 0.84, 0.7), Color(0.9, 0.78, 0.66)]
const PAINTS := [Color(0.7, 0.12, 0.14), Color(0.15, 0.3, 0.55), Color(0.85, 0.85, 0.82), Color(0.2, 0.2, 0.22), Color(0.25, 0.5, 0.35), Color(0.9, 0.6, 0.15)]
const BRICKS := [Color(0.6, 0.32, 0.25), Color(0.52, 0.28, 0.22), Color(0.68, 0.44, 0.34)]


static func footprint(kind: String) -> Vector2:
	return FOOTPRINTS.get(kind, Vector2(16, 16))


## Builds `kind` on a lot of `size` (x along the street, y deep). See the
## header for the frame and the collision format.
static func build(kind: String, mb, out: Array, size: Vector2, rng: RandomNumberGenerator) -> void:
	var w := maxf(size.x, 3.0)
	var d := maxf(size.y, 3.0)
	match kind:
		"farmhouse": farmhouse(mb, out, w, d, rng)
		"barn": barn(mb, out, w, d, rng)
		"silos": silos(mb, out, w, d, rng)
		"machine_shed": machine_shed(mb, out, w, d, rng)
		"trailer_home": trailer_home(mb, out, w, d, rng)
		"shack": shack(mb, out, w, d, rng)
		"stilt_house": stilt_house(mb, out, w, d, rng)
		"water_tower": water_tower(mb, out, w, d, rng)
		"windpump": windpump(mb, out, w, d, rng)
		"gas_station": gas_station(mb, out, w, d, rng)
		"diner": diner(mb, out, w, d, rng)
		"motel": motel(mb, out, w, d, rng)
		"general_store": general_store(mb, out, w, d, rng)
		"truck_stop": truck_stop(mb, out, w, d, rng)
		"garage": garage(mb, out, w, d, rng)
		"town_hall": town_hall(mb, out, w, d, rng)
		"bar": bar(mb, out, w, d, rng)
		"shopfront": shopfront(mb, out, w, d, rng)
		"house": house(mb, out, w, d, rng)
		"mansion": mansion(mb, out, w, d, rng)
		"garden_apartments": garden_apartments(mb, out, w, d, rng)
		"strip_mall": strip_mall(mb, out, w, d, rng)
		"police_station": police_station(mb, out, w, d, rng)
		"county_hospital": county_hospital(mb, out, w, d, rng)
		"airboat_dock": airboat_dock(mb, out, w, d, rng)
		"airstrip_hangar": airstrip_hangar(mb, out, w, d, rng)
		"deco_hotel": deco_hotel(mb, out, w, d, rng)
		"condo_tower": condo_tower(mb, out, w, d, rng)
		"beach_bar": beach_bar(mb, out, w, d, rng)
		"lifeguard_tower": lifeguard_tower(mb, out, w, d, rng)
		"grain_elevators": grain_elevators(mb, out, w, d, rng)
		"hollis_farm": hollis_farm(mb, out, w, d, rng)
		"larkspur_vineyard": larkspur_vineyard(mb, out, w, d, rng)
		"gator_farm": gator_farm(mb, out, w, d, rng)
		"moonshine_still": moonshine_still(mb, out, w, d, rng)
		"bellerive_general": bellerive_general(mb, out, w, d, rng)
		"bus_terminal": bus_terminal(mb, out, w, d, rng)
		"seaplane_base": seaplane_base(mb, out, w, d, rng)
		"cruise_terminal": cruise_terminal(mb, out, w, d, rng)
		"torque_tone": torque_tone(mb, out, w, d, rng)
		"aurum_hangar": aurum_hangar(mb, out, w, d, rng)
		_:
			# Unknown kind: a plain block, so a typo shows instead of a hole.
			_solid(mb, out, Vector3(0, 2.0, 0), Vector3(w * 0.6, 4.0, d * 0.6), Color(1.0, 0.0, 1.0))


# --- Helpers ------------------------------------------------------------------

static func _solid(mb, out: Array, c: Vector3, s: Vector3, color: Color) -> void:
	mb.box(c, s, color)
	out.append([c, s])


static func _col(out: Array, c: Vector3, s: Vector3, yaw := 0.0) -> void:
	if yaw == 0.0:
		out.append([c, s])
	else:
		out.append([c, s, yaw])


static func _pick(list: Array, rng: RandomNumberGenerator):
	return list[rng.randi() % list.size()]


## A flat ground surface (top face only) from x0..x1 by z0..z1 at height y:
## lawns, forecourts, gravel. Later pads sit a little higher.
static func _pad(mb, x0: float, x1: float, z0: float, z1: float, color: Color, y := 0.02) -> void:
	mb.box(Vector3((x0 + x1) * 0.5, y, (z0 + z1) * 0.5), Vector3(x1 - x0, 0.02, z1 - z0), color)


## A square-section beam from a to b, `t` thick (t2 wide if given): braces,
## legs, rails, ramps and, flat on the ground, painted lines.
static func _beam(mb, a: Vector3, b: Vector3, t: float, color: Color, t2 := -1.0) -> void:
	var dir := b - a
	var length := dir.length()
	if length < 0.001:
		return
	var x := dir / length
	var ref := Vector3.UP if absf(x.y) < 0.9 else Vector3.BACK
	var z := x.cross(ref).normalized()
	var y := z.cross(x)
	var saved: Transform3D = mb.xform
	mb.xform = saved * Transform3D(Basis(x, y, z), (a + b) * 0.5)
	mb.box(Vector3.ZERO, Vector3(length, t, t2 if t2 > 0.0 else t), color, absf(x.y) < 0.3)
	mb.xform = saved


## A painted line on the ground from a to b.
static func _line(mb, a: Vector3, b: Vector3, width: float, color := LINE) -> void:
	_beam(mb, Vector3(a.x, 0.07, a.z), Vector3(b.x, 0.07, b.z), 0.02, color, width)


## Parking stalls: `n` bays side by side along X from x0, each `bay` wide
## and `depth` deep from the kerb line at z (toward +Z if dir > 0).
static func _stalls(mb, x0: float, z: float, n: int, bay: float, depth: float, dir := 1.0) -> void:
	for i in n + 1:
		var x := x0 + i * bay
		_line(mb, Vector3(x, 0, z), Vector3(x, 0, z + depth * dir), 0.12)


## A hip roof over a w x d rectangle centred on c (eaves at c.y), rising h.
static func _hip(mb, c: Vector3, w: float, d: float, h: float, color: Color) -> void:
	var hx := w * 0.5
	var hz := d * 0.5
	var y1 := c.y + h
	var a := Vector3(c.x - hx, c.y, c.z - hz)
	var b := Vector3(c.x + hx, c.y, c.z - hz)
	var e := Vector3(c.x + hx, c.y, c.z + hz)
	var f := Vector3(c.x - hx, c.y, c.z + hz)
	var side := color.darkened(0.08)
	if w >= d:
		var r0 := Vector3(c.x - hx + hz, y1, c.z)
		var r1 := Vector3(c.x + hx - hz, y1, c.z)
		mb.quad(a, b, r1, r0, Vector3(0, hz, -h).normalized(), color)
		mb.quad(f, e, r1, r0, Vector3(0, hz, h).normalized(), side)
		mb.tri(a, f, r0, Vector3(-h, hz, 0).normalized(), side)
		mb.tri(b, e, r1, Vector3(h, hz, 0).normalized(), color)
	else:
		var r0 := Vector3(c.x, y1, c.z - hz + hx)
		var r1 := Vector3(c.x, y1, c.z + hz - hx)
		mb.quad(a, f, r1, r0, Vector3(-h, hx, 0).normalized(), side)
		mb.quad(b, e, r1, r0, Vector3(h, hx, 0).normalized(), color)
		mb.tri(a, b, r0, Vector3(0, hx, -h).normalized(), color)
		mb.tri(f, e, r1, Vector3(0, hx, h).normalized(), side)


## A gable roof over w x d centred on (cx, cz) with eaves at y, rising h;
## the ridge runs along X, or along Z (gable end to the street) with along_z.
static func _gable(mb, cx: float, cz: float, y: float, w: float, d: float, h: float, color: Color, end_color: Color, along_z := false) -> void:
	if not along_z:
		mb.gable(Vector3(cx, y + h * 0.5, cz), Vector3(w, h, d), color, end_color)
		return
	var saved: Transform3D = mb.xform
	mb.xform = saved * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(cx, 0, cz))
	mb.gable(Vector3(0, y + h * 0.5, 0), Vector3(d, h, w), color, end_color)
	mb.xform = saved


## A roof or vault whose cross-section is `profile` (points (across, up),
## eave to eave, relative to c) run `length` along Z, or along X with
## along_x; the ends are closed in end_color unless `ends` is false.
static func _vault(mb, c: Vector3, profile: PackedVector2Array, length: float, along_x: bool, color: Color, end_color: Color, ends := true) -> void:
	var saved: Transform3D = mb.xform
	mb.xform = saved * Transform3D(Basis(Vector3.UP, PI * 0.5) if along_x else Basis(), c)
	var z0 := -length * 0.5
	var z1 := length * 0.5
	var cx := 0.0
	var cy := INF
	for p in profile:
		cx += p.x / profile.size()
		cy = minf(cy, p.y)
	for k in profile.size() - 1:
		var a := profile[k]
		var b := profile[k + 1]
		var m := (a + b) * 0.5
		var n := Vector3(b.y - a.y, -(b.x - a.x), 0).normalized()
		if n.dot(Vector3(m.x - cx, m.y - cy, 0)) < 0.0:
			n = -n
		mb.quad(Vector3(a.x, a.y, z0), Vector3(b.x, b.y, z0), Vector3(b.x, b.y, z1), Vector3(a.x, a.y, z1), n, color)
	if ends:
		var idx := Geometry2D.triangulate_polygon(profile)
		for t in range(0, idx.size(), 3):
			var p0 := profile[idx[t]]
			var p1 := profile[idx[t + 1]]
			var p2 := profile[idx[t + 2]]
			mb.tri(Vector3(p0.x, p0.y, z0), Vector3(p1.x, p1.y, z0), Vector3(p2.x, p2.y, z0), Vector3.FORWARD, end_color)
			mb.tri(Vector3(p0.x, p0.y, z1), Vector3(p1.x, p1.y, z1), Vector3(p2.x, p2.y, z1), Vector3.BACK, end_color)
	mb.xform = saved


## Half an ellipse from (-half, base) over to (half, base), `rise` high.
static func _arch(half: float, rise: float, base: float, segs := 6) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segs + 1:
		var a := PI - PI * i / segs
		pts.append(Vector2(cos(a) * half, base + sin(a) * rise))
	return pts


static func _cone(mb, base: Vector3, r: float, h: float, color: Color, sides := 8) -> void:
	var top := base + Vector3(0, h, 0)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var n := ((d0 + d1).normalized() * h + Vector3(0, r, 0)).normalized()
		mb.tri(base + d0 * r, base + d1 * r, top, n, color)


## `n` windows centred in n equal steps from a to b (points on the wall
## face), on a wall facing `facing`; optional shutters either side.
static func _windows(mb, a: Vector3, b: Vector3, n: int, size: Vector2, rng: RandomNumberGenerator, facing: Vector3, lit := 0.5, shutter := Color(0, 0, 0, 0)) -> void:
	var along_x := absf(facing.z) > 0.5
	var across := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
	for i in n:
		var p := a.lerp(b, (i + 0.5) / n) + facing * 0.04
		mb.box(p, Vector3(size.x, size.y, 0.08) if along_x else Vector3(0.08, size.y, size.x), Buildings._window(rng, lit))
		if shutter.a > 0.0:
			for s: float in [-1.0, 1.0]:
				var q := p + across * s * (size.x * 0.5 + 0.22) + facing * 0.02
				mb.box(q, Vector3(0.4, size.y, 0.06) if along_x else Vector3(0.06, size.y, 0.4), shutter)


## Window rows on all four walls of a box (x0..x1, z0..z1) for `floors`
## floors of height fh from y0; about one window per `step` metres.
static func _all_windows(mb, x0: float, x1: float, z0: float, z1: float, y0: float, floors: int, fh: float, step: float, size: Vector2, rng: RandomNumberGenerator, lit := 0.5, back := true) -> void:
	var nx := maxi(1, int((x1 - x0) / step))
	var nz := maxi(1, int((z1 - z0) / step))
	for f in floors:
		var y := y0 + f * fh + fh * 0.55
		_windows(mb, Vector3(x0, y, z0), Vector3(x1, y, z0), nx, size, rng, Vector3.FORWARD, lit)
		if back:
			_windows(mb, Vector3(x0, y, z1), Vector3(x1, y, z1), nx, size, rng, Vector3.BACK, lit)
		_windows(mb, Vector3(x0, y, z0), Vector3(x0, y, z1), nz, size, rng, Vector3.LEFT, lit)
		_windows(mb, Vector3(x1, y, z0), Vector3(x1, y, z1), nz, size, rng, Vector3.RIGHT, lit)


## building_kit's modern flat roof (parapet, membrane, plant) over a
## w x d box centred on (cx, cz) with its surface at `top`.
static func _flat_roof(mb, cx: float, cz: float, w: float, d: float, top: float, rng: RandomNumberGenerator, edge: Color, plain := false) -> void:
	var saved: Transform3D = mb.xform
	mb.xform = saved * Transform3D(Basis(), Vector3(cx, 0, cz))
	Buildings._flat_roof(mb, w, d, top, rng, edge, plain)
	mb.xform = saved


## Another kind built on a sub-lot of this one: offset, turned by yaw.
static func _sub(kind: String, mb, out: Array, offset: Vector3, yaw: float, size: Vector2, rng: RandomNumberGenerator) -> void:
	var saved: Transform3D = mb.xform
	var rot := Basis(Vector3.UP, yaw)
	mb.xform = saved * Transform3D(rot, offset)
	var sub: Array = []
	build(kind, mb, sub, size, rng)
	mb.xform = saved
	for col in sub:
		out.append([rot * col[0] + offset, col[1], yaw + (col[2] if col.size() > 2 else 0.0)])


## A square post from the ground to h, with a collider.
static func _post(mb, out: Array, p: Vector3, h: float, t: float, color: Color) -> void:
	_solid(mb, out, Vector3(p.x, h * 0.5, p.z), Vector3(t, h, t), color)


## A canopy: a slab (top at `top`, `thick` deep fascia) over x0..x1 by
## z0..z1 on posts at the given points (posts collide, the slab does not).
static func _canopy(mb, out: Array, x0: float, x1: float, z0: float, z1: float, top: float, thick: float, fascia: Color, deck: Color, posts: Array, post_color := STEEL) -> void:
	var c := Vector3((x0 + x1) * 0.5, top - thick * 0.5, (z0 + z1) * 0.5)
	mb.box(c, Vector3(x1 - x0, thick, z1 - z0), fascia)
	mb.box(Vector3(c.x, top + 0.02, c.z), Vector3(x1 - x0 - 0.4, 0.02, z1 - z0 - 0.4), deck)
	for p: Vector3 in posts:
		_post(mb, out, p, top - thick, 0.35, post_color)


## A sign on a pole: a panel `size` (x wide, y tall) at height h with a
## neon face; only the pole collides.
static func _pylon(mb, out: Array, p: Vector3, h: float, size: Vector2, color: Color, neon: Color) -> void:
	_post(mb, out, p, h - size.y * 0.5, 0.35, STEEL.darkened(0.3))
	var c := p + Vector3(0, h, 0)
	mb.box(c, Vector3(size.x, size.y, 0.5), color)
	for s: float in [-1.0, 1.0]:
		mb.box(c + Vector3(0, 0, s * 0.27), Vector3(size.x - 0.4, size.y - 0.4, 0.04), MeshBuilder.glow(neon, MeshBuilder.GLOW_NEON))
		for k in 3:
			mb.box(c + Vector3((k - 1) * size.x * 0.25, 0, s * 0.3), Vector3(size.x * 0.16, size.y * 0.45, 0.03), color.darkened(0.4))
	mb.box(c + Vector3(0, size.y * 0.5 + 0.05, 0), Vector3(size.x + 0.1, 0.12, 0.6), color.darkened(0.3))


static func _flagpole(mb, out: Array, p: Vector3, h: float, colors: Array) -> void:
	mb.cylinder(p, 0.08, h, Color(0.85, 0.86, 0.88), 5)
	mb.ball(p + Vector3(0, h + 0.1, 0), Vector3(0.14, 0.14, 0.14), GOLD, 5, 2)
	for k in colors.size():
		mb.box(p + Vector3(0.85, h - 0.35 - k * 0.36, 0), Vector3(1.6, 0.36, 0.04), colors[k])
	out.append([p + Vector3(0, 1.0, 0), Vector3(0.3, 2.0, 0.3)])


## A clipped hedge from a to b (along X or Z), h tall; collides if asked.
static func _hedge(mb, out: Array, a: Vector3, b: Vector3, h: float, collide := true, t := 0.9) -> void:
	var c := (a + b) * 0.5 + Vector3(0, h * 0.5, 0)
	var s := Vector3(absf(b.x - a.x) + t, h, absf(b.z - a.z) + t)
	mb.box(c, s, MeshBuilder.glow(LEAF.lightened(0.05), MeshBuilder.GRASS))
	if collide:
		out.append([c, s])


## A bush: a lumpy clump of foliage, no collider.
static func _bush(mb, p: Vector3, r: float, rng: RandomNumberGenerator, color := LEAF) -> void:
	mb.clump(p + Vector3(0, r * 0.7, 0), Vector3(r, r * 0.8, r), MeshBuilder.glow(color.lightened(rng.randf() * 0.1), MeshBuilder.GRASS), rng.randi(), 7, 3, 0.25)


## Italian cypress: a slim dark column of foliage.
static func _cypress(mb, out: Array, p: Vector3, h: float, rng: RandomNumberGenerator) -> void:
	var leaf := MeshBuilder.glow(Color(0.2, 0.32, 0.18), MeshBuilder.GRASS)
	mb.limb(p, p + Vector3(0, 1.0, 0), 0.18, 0.15, Props.BARK, 5, false)
	mb.clump(p + Vector3(0, h * 0.45, 0), Vector3(0.9, h * 0.42, 0.9), leaf, rng.randi(), 7, 4, 0.12)
	mb.clump(p + Vector3(0, h * 0.85, 0), Vector3(0.6, h * 0.2, 0.6), leaf.lightened(0.05), rng.randi(), 6, 3, 0.15)
	out.append([p + Vector3(0, 1.0, 0), Vector3(0.6, 2.0, 0.6)])


## Bald cypress (the bayou tree): flared trunk and a flat, ragged crown.
static func _bald_cypress(mb, out: Array, p: Vector3, rng: RandomNumberGenerator) -> void:
	var h := rng.randf_range(7.0, 9.0)
	mb.limb(p, p + Vector3(0, 1.0, 0), 0.75, 0.35, Props.BARK.lightened(0.15), 6, false)
	mb.limb(p + Vector3(0, 1.0, 0), p + Vector3(0, h, 0), 0.35, 0.15, Props.BARK.lightened(0.15), 5, false)
	var leaf := MeshBuilder.glow(Color(0.36, 0.44, 0.24), MeshBuilder.GRASS)
	var seed := rng.randi()
	mb.clump(p + Vector3(0, h - 0.6, 0), Vector3(2.6, 1.0, 2.6), leaf, seed, 8, 3, 0.3)
	mb.clump(p + Vector3(0.6, h - 2.4, -0.3), Vector3(2.0, 0.8, 2.0), leaf.darkened(0.08), seed + 1, 7, 3, 0.3)
	mb.box(p + Vector3(1.0, h - 2.2, 0.2), Vector3(0.16, 1.2, 0.05), Props.MOSS)
	mb.box(p + Vector3(-0.8, h - 1.6, -0.4), Vector3(0.16, 1.0, 0.05), Props.MOSS)
	out.append([p + Vector3(0, 1.0, 0), Vector3(1.0, 2.0, 1.0)])


## A round hay bale lying on its side.
static func _bale(mb, out: Array, p: Vector3, yaw: float) -> void:
	var d := Vector3(cos(yaw), 0, -sin(yaw)) * 0.6
	mb.limb(p + Vector3(0, 0.7, 0) - d, p + Vector3(0, 0.7, 0) + d, 0.7, 0.7, STRAW, 7)
	out.append([p + Vector3(0, 0.7, 0), Vector3(1.4, 1.4, 1.4)])


static func _wheel(mb, p: Vector3, r: float, width: float, color := DARK) -> void:
	mb.limb(p - Vector3(width * 0.5, 0, 0), p + Vector3(width * 0.5, 0, 0), r, r, color, 6)


## A plain modern car (parked dressing), nose toward -Z before yaw.
static func _car(mb, out: Array, p: Vector3, yaw: float, color: Color, collide := true) -> void:
	var saved: Transform3D = mb.xform
	mb.xform = saved * Transform3D(Basis(Vector3.UP, yaw), p)
	var paint := MeshBuilder.glow(color, MeshBuilder.GLOSS)
	mb.box(Vector3(0, 0.62, 0), Vector3(1.8, 0.6, 4.3), paint)
	mb.box(Vector3(0, 1.15, 0.25), Vector3(1.6, 0.5, 2.1), MeshBuilder.glow(Color(0.2, 0.25, 0.3), MeshBuilder.GLASS))
	mb.box(Vector3(0, 1.42, 0.25), Vector3(1.5, 0.05, 1.9), paint)
	for x: float in [-0.82, 0.82]:
		for z: float in [-1.35, 1.35]:
			_wheel(mb, Vector3(x, 0.34, z), 0.34, 0.22)
	mb.xform = saved
	if collide:
		_col(out, p + Vector3(0, 0.75, 0), Vector3(1.8, 1.5, 4.3), yaw)


## A pickup truck, nose toward -Z before yaw.
static func _pickup(mb, out: Array, p: Vector3, yaw: float, color: Color) -> void:
	var saved: Transform3D = mb.xform
	mb.xform = saved * Transform3D(Basis(Vector3.UP, yaw), p)
	var paint := MeshBuilder.glow(color, MeshBuilder.GLOSS)
	mb.box(Vector3(0, 0.8, -0.6), Vector3(1.95, 0.75, 3.4), paint)
	mb.box(Vector3(0, 1.5, -0.4), Vector3(1.8, 0.7, 1.6), MeshBuilder.glow(Color(0.2, 0.25, 0.3), MeshBuilder.GLASS))
	mb.box(Vector3(0, 1.87, -0.4), Vector3(1.8, 0.06, 1.5), paint)
	mb.box(Vector3(0, 0.62, 1.8), Vector3(1.95, 0.08, 2.0), DARK)
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(s * 0.94, 0.95, 1.8), Vector3(0.08, 0.6, 2.0), paint)
	mb.box(Vector3(0, 0.95, 2.78), Vector3(1.95, 0.6, 0.08), paint)
	for x: float in [-0.88, 0.88]:
		for z: float in [-1.6, 1.8]:
			_wheel(mb, Vector3(x, 0.4, z), 0.4, 0.28)
	mb.xform = saved
	_col(out, p + Vector3(0, 0.9, 0.0), Vector3(2.0, 1.8, 5.6), yaw)


## A farm tractor: big rear wheels, cab with a roll frame, nose to -Z.
static func _tractor(mb, out: Array, p: Vector3, yaw: float, color: Color) -> void:
	var saved: Transform3D = mb.xform
	mb.xform = saved * Transform3D(Basis(Vector3.UP, yaw), p)
	var paint := MeshBuilder.glow(color, MeshBuilder.GLOSS)
	mb.box(Vector3(0, 1.1, -0.9), Vector3(0.9, 0.9, 2.0), paint)
	mb.box(Vector3(0, 1.0, 0.6), Vector3(1.1, 0.8, 1.4), paint)
	mb.cylinder(Vector3(0.25, 1.5, -1.3), 0.07, 0.9, DARK, 4)
	mb.box(Vector3(0, 1.7, 0.7), Vector3(0.5, 0.5, 0.5), DARK)
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(s * 0.6, 2.2, 0.7), Vector3(0.08, 1.6, 0.08), DARK)
		_wheel(mb, Vector3(s * 0.95, 0.8, 0.7), 0.8, 0.5)
		_wheel(mb, Vector3(s * 0.7, 0.45, -1.5), 0.45, 0.3)
	mb.box(Vector3(0, 3.0, 0.7), Vector3(1.4, 0.08, 1.2), paint)
	mb.xform = saved
	_col(out, p + Vector3(0, 1.0, -0.3), Vector3(2.4, 2.0, 4.0), yaw)


## A flat-bottomed boat, bow toward -Z before yaw (on trailers and docks).
static func _boat(mb, p: Vector3, yaw: float, length: float, color: Color, deck := WHITE) -> void:
	var saved: Transform3D = mb.xform
	mb.xform = saved * Transform3D(Basis(Vector3.UP, yaw), p)
	var hw := length * 0.2
	var poly := PackedVector2Array([Vector2(0, -length * 0.5), Vector2(hw, -length * 0.22), Vector2(hw, length * 0.5), Vector2(-hw, length * 0.5), Vector2(-hw, -length * 0.22)])
	mb.prism(poly, 0.0, 0.6, MeshBuilder.glow(deck, MeshBuilder.GLOSS), MeshBuilder.glow(color, MeshBuilder.GLOSS))
	mb.box(Vector3(0, 0.62, length * 0.15), Vector3(hw * 1.4, 0.02, length * 0.4), deck.darkened(0.2))
	mb.box(Vector3(0, 0.95, -length * 0.02), Vector3(hw * 1.2, 0.6, 0.08), MeshBuilder.glow(Color(0.3, 0.38, 0.45), MeshBuilder.GLASS))
	mb.box(Vector3(0, 0.6, length * 0.5 + 0.3), Vector3(0.4, 0.8, 0.5), DARK)
	mb.xform = saved


## A semi trailer (box van), front toward -Z before yaw.
static func _trailer(mb, out: Array, p: Vector3, yaw: float, color: Color) -> void:
	var saved: Transform3D = mb.xform
	mb.xform = saved * Transform3D(Basis(Vector3.UP, yaw), p)
	mb.box(Vector3(0, 2.4, 0), Vector3(2.5, 2.8, 13.0), MeshBuilder.glow(color, MeshBuilder.SIDING))
	mb.box(Vector3(0, 3.82, 0), Vector3(2.5, 0.04, 13.0), color.lightened(0.15))
	for z: float in [4.5, 5.6]:
		for s: float in [-1.0, 1.0]:
			_wheel(mb, Vector3(s * 0.95, 0.5, z), 0.5, 0.5)
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(s * 0.9, 0.5, -3.0), Vector3(0.12, 1.0, 0.12), DARK)
	mb.xform = saved
	_col(out, p + Vector3(0, 2.0, 0), Vector3(2.6, 4.0, 13.0), yaw)


## A semi tractor unit (cab), nose toward -Z before yaw.
static func _semi(mb, out: Array, p: Vector3, yaw: float, color: Color) -> void:
	var saved: Transform3D = mb.xform
	mb.xform = saved * Transform3D(Basis(Vector3.UP, yaw), p)
	var paint := MeshBuilder.glow(color, MeshBuilder.GLOSS)
	mb.box(Vector3(0, 1.3, -1.8), Vector3(2.4, 1.2, 2.0), paint)
	mb.box(Vector3(0, 2.3, -0.4), Vector3(2.4, 2.4, 2.2), paint)
	mb.box(Vector3(0, 2.6, -1.52), Vector3(2.2, 0.9, 0.06), MeshBuilder.glow(Color(0.2, 0.25, 0.3), MeshBuilder.GLASS))
	mb.box(Vector3(0, 0.9, 2.0), Vector3(2.2, 0.3, 3.0), DARK)
	for s: float in [-1.0, 1.0]:
		mb.cylinder(Vector3(s * 1.1, 1.0, 0.85), 0.1, 3.2, MeshBuilder.glow(STEEL, MeshBuilder.METAL), 5)
		for z: float in [-1.8, 2.0, 3.2]:
			_wheel(mb, Vector3(s * 0.95, 0.5, z), 0.5, 0.45)
	mb.xform = saved
	_col(out, p + Vector3(0, 1.6, 0.4), Vector3(2.5, 3.2, 7.2), yaw)


## A coach, front toward -Z before yaw.
static func _bus(mb, out: Array, p: Vector3, yaw: float, color: Color) -> void:
	var saved: Transform3D = mb.xform
	mb.xform = saved * Transform3D(Basis(Vector3.UP, yaw), p)
	var paint := MeshBuilder.glow(color, MeshBuilder.GLOSS)
	mb.box(Vector3(0, 1.85, 0), Vector3(2.55, 3.0, 12.0), MeshBuilder.glow(WHITE, MeshBuilder.GLOSS))
	mb.box(Vector3(0, 0.9, 0), Vector3(2.57, 0.5, 12.0), paint)
	var glass := MeshBuilder.glow(Color(0.18, 0.24, 0.3), MeshBuilder.GLASS)
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(s * 1.29, 2.3, 0.4), Vector3(0.06, 1.1, 10.4), glass)
	mb.box(Vector3(0, 2.1, -6.01), Vector3(2.3, 1.6, 0.06), glass)
	mb.box(Vector3(0, 3.4, 2.5), Vector3(1.6, 0.25, 3.0), MeshBuilder.glow(STEEL, MeshBuilder.METAL))
	for z: float in [-4.0, 3.2, 4.4]:
		for s: float in [-1.0, 1.0]:
			_wheel(mb, Vector3(s * 1.05, 0.5, z), 0.5, 0.4)
	mb.xform = saved
	_col(out, p + Vector3(0, 1.7, 0), Vector3(2.6, 3.4, 12.0), yaw)


## A plane: fuselage along Z (nose at -Z), `high_wing` puts the wing on
## top (seaplane, crop duster), `floats` hangs pontoons, `biplane` adds a
## lower wing. No collider (the caller adds one sized for its use).
static func _plane(mb, p: Vector3, yaw: float, length: float, color: Color, stripe: Color, high_wing := true, floats := false, biplane := false) -> void:
	var saved: Transform3D = mb.xform
	mb.xform = saved * Transform3D(Basis(Vector3.UP, yaw), p)
	var paint := MeshBuilder.glow(color, MeshBuilder.GLOSS)
	var r := length * 0.075
	var y := r + (1.4 if floats else 1.0)
	mb.limb(Vector3(0, y, -length * 0.5), Vector3(0, y, -length * 0.2), r * 0.7, r, paint, 6)
	mb.limb(Vector3(0, y, -length * 0.2), Vector3(0, y + r * 0.3, length * 0.5), r, r * 0.25, paint, 6)
	mb.box(Vector3(0, y + r * 0.6, -length * 0.22), Vector3(r * 1.5, r * 0.8, length * 0.14), MeshBuilder.glow(Color(0.2, 0.26, 0.32), MeshBuilder.GLASS))
	var span := length * 1.25
	var wy := y + r * 1.05 if high_wing else y - r * 0.6
	mb.box(Vector3(0, wy, -length * 0.15), Vector3(span, 0.12, length * 0.16), paint)
	mb.box(Vector3(0, wy + 0.07, -length * 0.15), Vector3(span * 0.25, 0.02, length * 0.16), stripe)
	if biplane:
		mb.box(Vector3(0, y - r * 0.7, -length * 0.15), Vector3(span * 0.9, 0.1, length * 0.15), paint)
		for s: float in [-1.0, 1.0]:
			mb.box(Vector3(s * span * 0.32, y + r * 0.2, -length * 0.15), Vector3(0.08, r * 1.8, 0.08), DARK)
	elif high_wing:
		for s: float in [-1.0, 1.0]:
			_beam(mb, Vector3(s * r, y - r * 0.5, -length * 0.15), Vector3(s * span * 0.3, wy, -length * 0.15), 0.08, DARK)
	mb.box(Vector3(0, y + r * 0.35, length * 0.45), Vector3(length * 0.42, 0.08, length * 0.1), paint)
	mb.box(Vector3(0, y + r * 1.2, length * 0.46), Vector3(0.08, r * 2.0, length * 0.12), stripe)
	mb.box(Vector3(0, y, -length * 0.5 - 0.06), Vector3(length * 0.28, 0.12, 0.04), DARK)
	mb.box(Vector3(0, y, -length * 0.5 - 0.06), Vector3(0.12, length * 0.28, 0.04), DARK)
	mb.box(Vector3(0, y - r * 0.2, -length * 0.4), Vector3(r * 2.1, r * 0.25, 0.1), stripe)
	if floats:
		for s: float in [-1.0, 1.0]:
			mb.limb(Vector3(s * span * 0.16, 0.4, -length * 0.4), Vector3(s * span * 0.16, 0.4, length * 0.25), 0.25, 0.32, MeshBuilder.glow(WHITE, MeshBuilder.GLOSS), 6)
			_beam(mb, Vector3(s * span * 0.16, 0.6, -length * 0.15), Vector3(s * r * 0.6, y - r * 0.6, -length * 0.15), 0.08, DARK)
	else:
		for s: float in [-1.0, 1.0]:
			_beam(mb, Vector3(s * r * 0.6, y - r * 0.6, -length * 0.22), Vector3(s * r * 1.6, 0.35, -length * 0.22), 0.08, DARK)
			_wheel(mb, Vector3(s * r * 1.6, 0.35, -length * 0.22), 0.35, 0.15)
	mb.xform = saved


# --- Rural ---------------------------------------------------------------------

## A rural mailbox on a post at the kerb.
static func _rural_mailbox(mb, p: Vector3, color := Color(0.85, 0.86, 0.88)) -> void:
	mb.box(p + Vector3(0, 0.55, 0), Vector3(0.1, 1.1, 0.1), WOOD)
	mb.limb(p + Vector3(0, 1.22, -0.25), p + Vector3(0, 1.22, 0.25), 0.15, 0.15, MeshBuilder.glow(color, MeshBuilder.GLOSS), 6)
	mb.box(p + Vector3(0.17, 1.35, 0.1), Vector3(0.04, 0.25, 0.05), Color(0.85, 0.15, 0.12))


## Two-storey clapboard farmhouse with a full front porch, a tin gable roof,
## a brick chimney and a one-storey kitchen wing; gravel drive and pickup.
static func farmhouse(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var bw := clampf(w * 0.5, 7.0, 14.0)
	var bd := clampf(d * 0.3, 6.0, 10.0)
	var cx := -w * 0.5 + 2.0 + bw * 0.5
	var zf := -d * 0.5 + clampf(d * 0.3, 4.0, 9.0)
	var cz := zf + bd * 0.5
	var siding: Color = _pick(SIDINGS, rng)
	var body := MeshBuilder.glow(siding, MeshBuilder.SIDING)
	var shutter := Color(0.16, 0.3, 0.22) if rng.randf() < 0.5 else Color(0.2, 0.22, 0.3)
	var h := 2.0 * FLOOR + 0.6
	_pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, MeshBuilder.glow(LAWN, MeshBuilder.GRASS))
	mb.box(Vector3(cx, 0.3, cz), Vector3(bw + 0.1, 0.6, bd + 0.1), MeshBuilder.glow(CONCRETE, MeshBuilder.CONCRETE))
	mb.box(Vector3(cx, h * 0.5 + 0.3, cz), Vector3(bw, h - 0.6, bd), body)
	_col(out, Vector3(cx, h * 0.5, cz), Vector3(bw, h, bd))
	var roof: Color = _pick(TIN_ROOFS, rng)
	_gable(mb, cx, cz, h, bw + 0.8, bd + 0.8, 2.6, MeshBuilder.glow(roof, MeshBuilder.SEAM_ROOF), body)
	mb.box(Vector3(cx - bw * 0.5 + 1.0, h + 1.4, cz + bd * 0.2), Vector3(0.9, 3.6, 0.9), MeshBuilder.glow(BRICKS[0], MeshBuilder.BRICK))
	for x: float in [cx - bw * 0.5 + 0.06, cx + bw * 0.5 - 0.06]:
		mb.box(Vector3(x, h * 0.5 + 0.3, zf - 0.06), Vector3(0.2, h - 0.6, 0.06), TRIM)
	# Windows: two floors at the front (a door in the middle below), sides, back.
	var n := maxi(2, int(bw / 2.4))
	var y1 := 0.6 + FLOOR + 1.6
	_windows(mb, Vector3(cx - bw * 0.5, y1, zf), Vector3(cx + bw * 0.5, y1, zf), n, Vector2(1.0, 1.5), rng, Vector3.FORWARD, 0.4, shutter)
	var half := maxi(1, int((bw * 0.5 - 0.9) / 2.4))
	_windows(mb, Vector3(cx - bw * 0.5, 2.0, zf), Vector3(cx - 0.9, 2.0, zf), half, Vector2(1.0, 1.5), rng, Vector3.FORWARD, 0.4, shutter)
	_windows(mb, Vector3(cx + 0.9, 2.0, zf), Vector3(cx + bw * 0.5, 2.0, zf), half, Vector2(1.0, 1.5), rng, Vector3.FORWARD, 0.4, shutter)
	mb.box(Vector3(cx, 1.7, zf - 0.05), Vector3(1.0, 2.2, 0.1), WOOD.darkened(0.2))
	_all_windows(mb, cx - bw * 0.5, cx + bw * 0.5, zf, zf + bd, 0.6, 2, FLOOR, 3.0, Vector2(0.9, 1.4), rng, 0.4)
	# Porch across the front: floor, posts, rail, steps and a shed roof.
	var pd := 2.4
	mb.box(Vector3(cx, 0.55, zf - pd * 0.5), Vector3(bw, 0.12, pd), MeshBuilder.glow(WOOD.lightened(0.25), MeshBuilder.SIDING))
	var posts := maxi(2, int(bw / 2.6) + 1)
	for i in posts:
		var x := cx - bw * 0.5 + 0.12 + (bw - 0.24) * i / (posts - 1)
		_solid(mb, out, Vector3(x, 1.95, zf - pd + 0.12), Vector3(0.16, 2.8, 0.16), TRIM)
	for s: float in [-1.0, 1.0]:
		var xa := cx + s * 1.0
		var xb := cx + s * (bw * 0.5 - 0.1)
		mb.box(Vector3((xa + xb) * 0.5, 1.5, zf - pd + 0.12), Vector3(absf(xb - xa), 0.08, 0.08), TRIM)
		mb.box(Vector3((xa + xb) * 0.5, 0.9, zf - pd + 0.12), Vector3(absf(xb - xa), 0.06, 0.06), TRIM)
	mb.box(Vector3(cx, 0.3, zf - pd - 0.45), Vector3(1.8, 0.6, 0.9), MeshBuilder.glow(WOOD.lightened(0.15), MeshBuilder.SIDING))
	var pr := MeshBuilder.glow(roof, MeshBuilder.SEAM_ROOF)
	var r0 := Vector3(cx - bw * 0.5 - 0.2, 3.75, zf)
	var r1 := Vector3(cx + bw * 0.5 + 0.2, 3.75, zf)
	mb.quad(r0, r1, r1 + Vector3(0, -0.5, -pd - 0.3), r0 + Vector3(0, -0.5, -pd - 0.3), Vector3(0, pd, -0.5).normalized(), pr)
	mb.box(Vector3(cx, 3.15, zf - pd - 0.25), Vector3(bw + 0.4, 0.2, 0.08), TRIM)
	# Kitchen wing at the back.
	var ww := bw * 0.45
	var wd := clampf(d * 0.18, 3.0, 5.0)
	var wx := cx + bw * 0.2
	var wz := zf + bd + wd * 0.5
	_solid(mb, out, Vector3(wx, 1.8, wz), Vector3(ww, 3.6, wd), body)
	_gable(mb, wx, wz, 3.6, ww + 0.6, wd + 0.6, 1.6, MeshBuilder.glow(roof, MeshBuilder.SEAM_ROOF), body, true)
	_windows(mb, Vector3(wx - ww * 0.5, 2.0, wz), Vector3(wx - ww * 0.5, 2.0, wz + wd * 0.5), 1, Vector2(0.9, 1.2), rng, Vector3.LEFT, 0.4)
	# Gravel drive down the side, a pickup, mailbox, an oak out back.
	var dx := cx + bw * 0.5 + 3.0
	_pad(mb, dx - 1.6, dx + 1.6, -d * 0.5, zf + bd, MeshBuilder.glow(GRAVEL, MeshBuilder.CONCRETE), 0.04)
	_pickup(mb, out, Vector3(dx, 0, zf + bd * 0.4), 0.0, _pick(PAINTS, rng))
	_rural_mailbox(mb, Vector3(dx - 2.2, 0, -d * 0.5 + 0.5))
	if w >= 18.0:
		Props.oak(mb, out, Vector3(w * 0.5 - 4.6, 0, d * 0.5 - 4.6), rng)


## Red barn with a gambrel roof, its gable end to the lane: white-trimmed
## doors with X braces, a hayloft door, a cupola, a lean-to and hay bales.
static func barn(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var bw := clampf(w * 0.62, 8.0, 15.0)
	var bl := clampf(d * 0.68, 11.0, 22.0)
	var cz := -d * 0.5 + 2.5 + bl * 0.5
	var paint := BARN_RED if rng.randf() < 0.8 else Color(0.55, 0.53, 0.5)
	var red := MeshBuilder.glow(paint, MeshBuilder.SIDING)
	const H := 5.0
	_pad(mb, -bw * 0.5 - 1.0, bw * 0.5 + 1.0, -d * 0.5, cz + bl * 0.5 + 0.5, MeshBuilder.glow(DIRT, MeshBuilder.CONCRETE))
	_solid(mb, out, Vector3(0, H * 0.5, cz), Vector3(bw, H, bl), red)
	var hw := bw * 0.5 + 0.35
	var r1 := bw * 0.3
	var r2 := bw * 0.13
	var profile := PackedVector2Array([Vector2(-hw, H - 0.1), Vector2(-hw * 0.64, H + r1), Vector2(0, H + r1 + r2), Vector2(hw * 0.64, H + r1), Vector2(hw, H - 0.1)])
	var roof: Color = [Color(0.46, 0.48, 0.5), Color(0.3, 0.32, 0.34), Color(0.35, 0.42, 0.36), Color(0.62, 0.64, 0.66)][rng.randi() % 4]
	_vault(mb, Vector3(0, 0, cz), profile, bl + 0.6, false, MeshBuilder.glow(roof, MeshBuilder.SEAM_ROOF), red)
	var fz := cz - bl * 0.5 - 0.05
	# Corner boards, doors with white frames and X braces, hayloft door.
	for x: float in [-bw * 0.5 + 0.12, bw * 0.5 - 0.12]:
		for z: float in [fz - 0.02, cz + bl * 0.5 + 0.07]:
			mb.box(Vector3(x, H * 0.5, z), Vector3(0.25, H, 0.06), TRIM)
	var dw := minf(bw * 0.3, 3.2)
	for s: float in [-1.0, 1.0]:
		var c := Vector3(s * dw * 0.5, 2.0, fz - 0.03)
		mb.box(c, Vector3(dw, 4.0, 0.08), paint.darkened(0.12))
		for v: float in [-1.0, 1.0]:
			mb.box(c + Vector3(v * (dw * 0.5 - 0.08), 0, -0.04), Vector3(0.16, 4.0, 0.06), TRIM)
			mb.box(c + Vector3(0, v * 1.92, -0.04), Vector3(dw, 0.16, 0.06), TRIM)
			_beam(mb, c + Vector3(-dw * 0.45, v * 1.85, -0.06), c + Vector3(dw * 0.45, -v * 1.85, -0.06), 0.14, TRIM, 0.05)
	var ez := cz - bl * 0.5 - 0.3
	mb.box(Vector3(0, H + 1.3, ez - 0.05), Vector3(1.8, 1.9, 0.08), TRIM)
	mb.box(Vector3(0, H + 1.3, ez - 0.09), Vector3(1.5, 1.6, 0.06), paint.darkened(0.25))
	mb.box(Vector3(0, H + r1 + r2 - 0.4, ez - 0.6), Vector3(0.3, 0.3, 1.3), WOOD)
	_windows(mb, Vector3(-bw * 0.5, 3.0, cz - bl * 0.5), Vector3(-bw * 0.5, 3.0, cz + bl * 0.5), maxi(2, int(bl / 4.5)), Vector2(0.9, 0.9), rng, Vector3.LEFT, 0.1)
	_windows(mb, Vector3(bw * 0.5, 3.0, cz - bl * 0.5), Vector3(bw * 0.5, 3.0, cz + bl * 0.5), maxi(2, int(bl / 4.5)), Vector2(0.9, 0.9), rng, Vector3.RIGHT, 0.1)
	# Cupola and weathervane on the ridge.
	var top := H + r1 + r2
	mb.box(Vector3(0, top + 0.5, cz), Vector3(1.4, 1.2, 1.4), TRIM)
	mb.box(Vector3(0, top + 0.6, cz - 0.71), Vector3(0.9, 0.6, 0.04), DARK)
	_hip(mb, Vector3(0, top + 1.1, cz), 1.9, 1.9, 0.9, MeshBuilder.glow(roof, MeshBuilder.SEAM_ROOF))
	mb.cylinder(Vector3(0, top + 1.9, cz), 0.03, 1.0, DARK, 4)
	mb.box(Vector3(0, top + 2.7, cz), Vector3(0.9, 0.25, 0.04), DARK)
	# Lean-to shed down one side.
	var lw := minf(3.4, (w - bw) * 0.5 - 0.5)
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	if lw > 1.8:
		var ll := bl * 0.6
		var lx := side * (bw * 0.5 + lw * 0.5)
		var lz := cz + bl * 0.15
		_solid(mb, out, Vector3(lx, 1.5, lz), Vector3(lw, 3.0, ll), red)
		var e0 := Vector3(side * bw * 0.5, H - 0.6, lz - ll * 0.5 - 0.2)
		var e1 := Vector3(side * (bw * 0.5 + lw + 0.3), 2.9, lz - ll * 0.5 - 0.2)
		var len_z := Vector3(0, 0, ll + 0.4)
		mb.quad(e0, e1, e1 + len_z, e0 + len_z, Vector3(side * (H - 3.5), lw, 0).normalized(), MeshBuilder.glow(roof, MeshBuilder.SEAM_ROOF))
		mb.quad(e0, e1, Vector3(e1.x, 2.9 - 0.1, e1.z), Vector3(e1.x, 3.0, e0.z), Vector3.FORWARD, red)
		mb.tri(Vector3(side * bw * 0.5, 3.0, e0.z + 0.2), e0 + Vector3(0, 0, 0.2), Vector3(e1.x - side * 0.3, 3.0, e0.z + 0.2), Vector3.FORWARD, red)
	# Round bales stacked by the barn.
	var bz := cz + bl * 0.5 + 1.4
	var bx := -side * (bw * 0.5 - 1.0)
	if bz + 1.0 < d * 0.5:
		_bale(mb, out, Vector3(bx, 0, bz), 0.0)
		_bale(mb, out, Vector3(bx - side * 1.6, 0, bz), 0.0)
	elif (w - bw) * 0.5 > 2.0:
		_bale(mb, out, Vector3(-side * (bw * 0.5 + 1.0), 0, cz), PI * 0.5)


## Two or three corrugated grain bins with conical roofs on a pad, with an
## auger reaching up to the tallest.
static func silos(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var n := 3 if w >= d * 1.05 and (w - 3.6) / 6.0 >= 1.5 else 2
	var r := clampf(minf((w - 2.0 - (n - 1) * 0.8) / (2.0 * n), d * 0.28), 1.5, 4.2)
	var cz := d * 0.5 - 0.8 - r
	var galv := MeshBuilder.glow(Color(0.76, 0.78, 0.79), MeshBuilder.METAL)
	var ring := MeshBuilder.glow(Color(0.6, 0.62, 0.64), MeshBuilder.METAL)
	var cap := MeshBuilder.glow(Color(0.84, 0.85, 0.86), MeshBuilder.METAL)
	var span := n * 2.0 * r + (n - 1) * 0.8
	_pad(mb, -span * 0.5 - 0.6, span * 0.5 + 0.6, cz - r - 0.6, cz + r + 0.6, MeshBuilder.glow(CONCRETE, MeshBuilder.CONCRETE))
	var tallest := 0
	var heights: Array[float] = []
	for i in n:
		heights.append(r * rng.randf_range(2.3, 3.1))
		if heights[i] > heights[tallest]:
			tallest = i
	for i in n:
		var x := -span * 0.5 + r + i * (2.0 * r + 0.8)
		var h := heights[i]
		var base := Vector3(x, 0, cz)
		mb.cylinder(base, r, h, galv, 12)
		for k in 2:
			mb.cylinder(base + Vector3(0, h * (k + 1) / 3.0, 0), r + 0.05, 0.12, ring, 12)
		_cone(mb, base + Vector3(0, h, 0), r + 0.15, r * 0.55, cap, 12)
		mb.cylinder(base + Vector3(0, h + r * 0.5, 0), r * 0.18, 0.4, galv, 6)
		mb.box(Vector3(x, h * 0.5, cz - r - 0.05), Vector3(0.5, h, 0.06), DARK)
		mb.box(Vector3(x, 0.8, cz - r - 0.06), Vector3(1.0, 1.2, 0.05), ring)
		_col(out, Vector3(x, h * 0.5, cz), Vector3(r * 1.75, h, r * 1.75))
	# Auger from a hopper near the lane up to the tallest bin.
	var tx := -span * 0.5 + r + tallest * (2.0 * r + 0.8)
	var foot := Vector3(clampf(tx + r + 1.5, -w * 0.5 + 1.0, w * 0.5 - 1.0), 0.9, maxf(-d * 0.5 + 1.2, cz - r - 4.0))
	var top := Vector3(tx, heights[tallest] + r * 0.5, cz)
	mb.limb(foot, top, 0.2, 0.2, MeshBuilder.glow(Color(0.85, 0.75, 0.25), MeshBuilder.GLOSS), 6)
	mb.box(foot + Vector3(0, -0.3, 0), Vector3(1.0, 0.8, 1.0), MeshBuilder.glow(Color(0.85, 0.75, 0.25), MeshBuilder.GLOSS))
	_wheel(mb, foot.lerp(top, 0.25) * Vector3(1, 0, 1) + Vector3(0, 0.4, 0), 0.4, 1.2)
	_beam(mb, foot.lerp(top, 0.25) * Vector3(1, 0, 1) + Vector3(0, 0.4, 0), foot.lerp(top, 0.25), 0.1, DARK)
	_col(out, foot, Vector3(1.0, 1.8, 1.0))


## Open-fronted steel machine shed with a tractor, hay and a fuel tank.
static func machine_shed(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var bw := w - 2.0
	var bd := clampf(d * 0.72, 7.0, 16.0)
	var cz := d * 0.5 - 1.0 - bd * 0.5
	var z0 := cz - bd * 0.5
	var z1 := cz + bd * 0.5
	const H := 5.2
	var paint: Color = [Color(0.62, 0.64, 0.66), Color(0.76, 0.7, 0.56), Color(0.42, 0.52, 0.42), BARN_RED][rng.randi() % 4]
	var siding := MeshBuilder.glow(paint, MeshBuilder.SEAM_ROOF)
	_pad(mb, -bw * 0.5, bw * 0.5, -d * 0.5, z0, MeshBuilder.glow(GRAVEL, MeshBuilder.CONCRETE))
	_pad(mb, -bw * 0.5, bw * 0.5, z0, z1, MeshBuilder.glow(CONCRETE.darkened(0.25), MeshBuilder.CONCRETE))
	_solid(mb, out, Vector3(0, H * 0.5, z1 - 0.1), Vector3(bw, H, 0.2), siding)
	for s: float in [-1.0, 1.0]:
		_solid(mb, out, Vector3(s * (bw * 0.5 - 0.1), H * 0.5, cz), Vector3(0.2, H, bd), siding)
	mb.box(Vector3(0, H - 0.4, z0 + 0.1), Vector3(bw, 0.8, 0.2), siding)
	var bays := maxi(2, int(bw / 6.0))
	for i in range(1, bays):
		_post(mb, out, Vector3(-bw * 0.5 + bw * i / bays, 0, z0 + 0.15), H - 0.8, 0.3, paint.darkened(0.2))
	_gable(mb, 0, cz, H, bw + 0.6, bd + 0.6, 1.4, MeshBuilder.glow(Color(0.7, 0.72, 0.74), MeshBuilder.SEAM_ROOF), siding)
	var bay_w := bw / bays
	_tractor(mb, out, Vector3(-bw * 0.5 + bay_w * 0.5, 0, cz - 0.5), 0.0, [Color(0.2, 0.5, 0.25), Color(0.8, 0.2, 0.15), Color(0.9, 0.6, 0.1)][rng.randi() % 3])
	if bays >= 3:
		_pickup(mb, out, Vector3(-bw * 0.5 + bay_w * 1.5, 0, cz), 0.0, _pick(PAINTS, rng))
	var hx := bw * 0.5 - bay_w * 0.5
	_solid(mb, out, Vector3(hx, 1.2, cz + bd * 0.15), Vector3(bay_w * 0.7, 2.4, bd * 0.6), STRAW)
	mb.box(Vector3(hx, 2.42, cz + bd * 0.15), Vector3(bay_w * 0.7, 0.04, 0.06), STRAW.darkened(0.2))
	if z0 - (-d * 0.5) > 4.0:
		var tank := Vector3(bw * 0.5 - 1.8, 1.6, z0 - 2.0)
		mb.limb(tank - Vector3(1.1, 0, 0), tank + Vector3(1.1, 0, 0), 0.6, 0.6, MeshBuilder.glow(Color(0.85, 0.2, 0.15), MeshBuilder.GLOSS), 8)
		for s: float in [-1.0, 1.0]:
			_beam(mb, tank + Vector3(s * 0.8, -0.5, 0), Vector3(tank.x + s * 0.9, 0, tank.z), 0.1, DARK)
		_col(out, tank, Vector3(2.4, 1.4, 1.3))


## Single-wide trailer on a skirted pad: a two-tone stripe, a deck at the
## door, propane tank, dish, a shed out back and a car on the gravel.
static func trailer_home(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var tw := clampf(w * 0.36, 3.6, 4.6)
	var tl := clampf(d * 0.68, 10.0, 20.0)
	var tx := -w * 0.5 + 1.0 + tw * 0.5
	var tz := d * 0.5 - 1.5 - tl * 0.5
	var body: Color = [WHITE, Color(0.95, 0.9, 0.7), Color(0.75, 0.85, 0.9), Color(0.85, 0.9, 0.8), Color(0.9, 0.82, 0.78)][rng.randi() % 5]
	var stripe: Color = _pick(ACCENTS, rng)
	_pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, MeshBuilder.glow(LAWN.lerp(DIRT, 0.35), MeshBuilder.GRASS))
	mb.box(Vector3(tx, 0.35, tz), Vector3(tw - 0.1, 0.7, tl - 0.1), Color(0.6, 0.55, 0.45))
	mb.box(Vector3(tx, 2.05, tz), Vector3(tw, 2.7, tl), MeshBuilder.glow(body, MeshBuilder.SIDING))
	_col(out, Vector3(tx, 1.7, tz), Vector3(tw, 3.4, tl))
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(tx + s * (tw * 0.5 + 0.02), 1.3, tz), Vector3(0.04, 0.35, tl), stripe)
	mb.box(Vector3(tx, 1.3, tz - tl * 0.5 - 0.02), Vector3(tw, 0.35, 0.04), stripe)
	_gable(mb, tx, tz, 3.4, tw + 0.2, tl + 0.1, 0.35, MeshBuilder.glow(TIN.lightened(0.15), MeshBuilder.SEAM_ROOF), MeshBuilder.glow(body, MeshBuilder.SIDING), true)
	var dz := tz - tl * 0.18
	var xr := tx + tw * 0.5
	mb.box(Vector3(xr + 0.04, 1.75, dz), Vector3(0.08, 2.0, 0.9), body.darkened(0.3))
	_windows(mb, Vector3(xr, 2.4, tz - tl * 0.5), Vector3(xr, 2.4, dz - 0.7), maxi(1, int((dz - 0.7 - tz + tl * 0.5) / 3.0)), Vector2(1.2, 0.9), rng, Vector3.RIGHT, 0.4)
	_windows(mb, Vector3(xr, 2.4, dz + 0.7), Vector3(xr, 2.4, tz + tl * 0.5), maxi(1, int((tz + tl * 0.5 - dz - 0.7) / 3.0)), Vector2(1.2, 0.9), rng, Vector3.RIGHT, 0.4)
	_windows(mb, Vector3(tx - tw * 0.5, 2.4, tz - tl * 0.5), Vector3(tx - tw * 0.5, 2.4, tz + tl * 0.5), maxi(1, int(tl / 5.0)), Vector2(1.0, 0.8), rng, Vector3.LEFT, 0.4)
	_windows(mb, Vector3(tx - 0.5, 2.3, tz - tl * 0.5), Vector3(tx + 0.5, 2.3, tz - tl * 0.5), 1, Vector2(2.0, 1.0), rng, Vector3.FORWARD, 0.4)
	mb.box(Vector3(tx - tw * 0.5 - 0.25, 2.0, tz + tl * 0.25), Vector3(0.5, 0.45, 0.7), MeshBuilder.glow(Props.STEEL, MeshBuilder.METAL))
	# Deck and steps at the door, a grill on it.
	var deck := MeshBuilder.glow(WOOD.lightened(0.2), MeshBuilder.SIDING)
	mb.box(Vector3(xr + 1.3, 0.62, dz), Vector3(2.6, 0.12, 3.0), deck)
	mb.box(Vector3(xr + 2.9, 0.3, dz), Vector3(0.6, 0.6, 1.2), deck)
	for z: float in [dz - 1.45, dz + 1.45]:
		mb.box(Vector3(xr + 1.3, 1.15, z), Vector3(2.6, 0.06, 0.06), WOOD)
		mb.box(Vector3(xr + 2.55, 0.9, z), Vector3(0.08, 0.6, 0.08), WOOD)
	mb.cylinder(Vector3(xr + 1.8, 0.68, dz + 0.9), 0.3, 0.8, DARK, 6)
	# Propane tank, dish, clothesline, shed, mailbox.
	var pz := tz + tl * 0.32
	mb.limb(Vector3(xr + 0.9, 0.55, pz - 0.7), Vector3(xr + 0.9, 0.55, pz + 0.7), 0.45, 0.45, MeshBuilder.glow(WHITE, MeshBuilder.GLOSS), 8)
	_col(out, Vector3(xr + 0.9, 0.5, pz), Vector3(1.0, 1.0, 1.6))
	Buildings._dish(mb, Vector3(tx, 3.5, tz + tl * 0.35))
	var lx := minf(xr + 3.6, w * 0.5 - 0.6)
	for z: float in [tz - 1.0, tz + 3.0]:
		mb.box(Vector3(lx, 1.0, z), Vector3(0.08, 2.0, 0.08), STEEL)
		mb.box(Vector3(lx, 1.95, z), Vector3(0.9, 0.06, 0.06), STEEL)
	mb.box(Vector3(lx, 1.9, tz + 1.0), Vector3(0.02, 0.02, 4.0), DARK)
	for k in 3:
		mb.box(Vector3(lx, 1.6, tz - 0.2 + k * 1.1), Vector3(0.04, 0.6, 0.7), _pick(PASTELS, rng))
	var sx := w * 0.5 - 1.5
	var sz := d * 0.5 - 1.5
	if sx - 1.2 > xr + 0.5:
		var shed := Color(0.75, 0.72, 0.62)
		_solid(mb, out, Vector3(sx, 1.1, sz), Vector3(2.4, 2.2, 2.4), MeshBuilder.glow(shed, MeshBuilder.SIDING))
		_gable(mb, sx, sz, 2.2, 2.7, 2.7, 0.8, MeshBuilder.glow(SHINGLES[0], MeshBuilder.ROOF), MeshBuilder.glow(shed, MeshBuilder.SIDING))
	_pad(mb, tx - 1.6, tx + 1.6, -d * 0.5, tz - tl * 0.5, MeshBuilder.glow(GRAVEL, MeshBuilder.CONCRETE), 0.04)
	if tz - tl * 0.5 + d * 0.5 > 5.5:
		_car(mb, out, Vector3(tx, 0, tz - tl * 0.5 - 3.0), 0.0, _pick(PAINTS, rng))
	_rural_mailbox(mb, Vector3(tx + 2.2, 0, -d * 0.5 + 0.5))


## Bayou fishing shack: a weathered plank hut on a deck on piles, a rusty
## tin roof, crab traps, a cooler, a stovepipe and a jon boat.
static func shack(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	const PH := 0.9
	var x0 := -w * 0.5 + 0.6
	var x1 := w * 0.5 - 0.6
	var z0 := -d * 0.5 + 1.0
	var z1 := d * 0.5 - 0.4
	var pile := Color(0.3, 0.25, 0.2)
	for i in 3:
		for k in 3:
			mb.cylinder(Vector3(lerpf(x0 + 0.2, x1 - 0.2, i * 0.5), 0, lerpf(z0 + 0.2, z1 - 0.2, k * 0.5)), 0.16, PH, pile, 5)
	mb.box(Vector3((x0 + x1) * 0.5, PH, (z0 + z1) * 0.5), Vector3(x1 - x0, 0.14, z1 - z0), MeshBuilder.glow(OLD_WOOD, MeshBuilder.SIDING))
	mb.box(Vector3(x0 + 1.0, PH * 0.5, z0 - 0.5), Vector3(1.2, PH, 1.0), MeshBuilder.glow(OLD_WOOD.darkened(0.1), MeshBuilder.SIDING))
	var sw := (x1 - x0) * 0.72
	var sd := (z1 - z0) * 0.55
	var sx := x0 + 0.3 + sw * 0.5
	var sz := z1 - 0.3 - sd * 0.5
	var paint: Color = [OLD_WOOD.lightened(0.1), Color(0.45, 0.55, 0.55), Color(0.5, 0.58, 0.45), Color(0.62, 0.55, 0.45)][rng.randi() % 4]
	var body := MeshBuilder.glow(paint, MeshBuilder.SIDING)
	mb.box(Vector3(sx, PH + 1.3, sz), Vector3(sw, 2.6, sd), body)
	_col(out, Vector3(sx, (PH + 2.6) * 0.5, sz), Vector3(sw, PH + 2.6, sd))
	_col(out, Vector3((x0 + x1) * 0.5, PH * 0.5, (z0 + z1) * 0.5), Vector3(x1 - x0, PH, z1 - z0))
	var roof := TIN.lerp(RUST, rng.randf_range(0.4, 0.9))
	_gable(mb, sx, sz, PH + 2.6, sw + 0.8, sd + 0.8, 1.2, MeshBuilder.glow(roof, MeshBuilder.SEAM_ROOF), body)
	mb.box(Vector3(sx + sw * 0.15, PH + 3.4, sz + sd * 0.1), Vector3(sw * 0.3, 0.04, sd * 0.3), MeshBuilder.glow(RUST.darkened(0.15), MeshBuilder.SEAM_ROOF))
	var fz := sz - sd * 0.5 - 0.04
	mb.box(Vector3(sx - sw * 0.2, PH + 1.0, fz), Vector3(0.9, 2.0, 0.08), WOOD.darkened(0.3))
	mb.box(Vector3(sx + sw * 0.22, PH + 1.5, fz), Vector3(0.9, 0.8, 0.08), Buildings._window(rng, 0.6))
	_beam(mb, Vector3(sx + sw * 0.22 - 0.5, PH + 1.95, fz - 0.05), Vector3(sx + sw * 0.22 + 0.5, PH + 2.0, fz - 0.7), 0.06, OLD_WOOD, 1.0)
	mb.cylinder(Vector3(sx + sw * 0.3, PH + 2.8, sz + sd * 0.2), 0.12, 1.6, DARK, 5)
	# Deck clutter: crab traps, a cooler, a chair, buoys on the wall.
	var trap := Color(0.5, 0.58, 0.52)
	for k in 3:
		mb.box(Vector3(x1 - 0.5, PH + 0.3 + (0.55 if k == 2 else 0.0), z1 - 0.6 - (k % 2) * 0.75), Vector3(0.6, 0.5, 0.6), trap)
	mb.box(Vector3(x0 + 0.5, PH + 0.3, sz - sd * 0.5 - 0.5), Vector3(0.7, 0.45, 0.45), MeshBuilder.glow(WHITE, MeshBuilder.GLOSS))
	mb.box(Vector3(x0 + 1.4, PH + 0.3, sz - sd * 0.5 - 0.6), Vector3(0.55, 0.06, 0.55), WOOD)
	mb.box(Vector3(x0 + 1.4, PH + 0.6, sz - sd * 0.5 - 0.35), Vector3(0.55, 0.6, 0.06), WOOD)
	for k in 3:
		mb.ball(Vector3(sx - sw * 0.5 + 0.5 + k * 0.4, PH + 2.0 - k * 0.2, fz - 0.15), Vector3(0.15, 0.2, 0.15), [Color(0.95, 0.4, 0.15), WHITE, Color(0.95, 0.85, 0.2)][k], 5, 2)
	var room := sz - sd * 0.5 - z0 - 0.6
	if room > 2.6:
		_boat(mb, Vector3(x1 - 1.0, PH + 0.08, z0 + 0.3 + minf(room, 4.0) * 0.5), 0.0, minf(room, 4.0), Color(0.28, 0.42, 0.3), Color(0.55, 0.58, 0.52))


## Bayou house up on piles: a wraparound deck under the hip roof, rails,
## a stair down to the yard, and a skiff parked underneath.
static func stilt_house(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	const PH := 2.8
	var hw := clampf(w * 0.62, 6.0, 11.0)
	var hd := clampf(d * 0.5, 5.5, 10.0)
	var hz := d * 0.5 - 1.0 - hd * 0.5
	var dx0 := -hw * 0.5 - 1.5
	var dx1 := hw * 0.5 + 1.5
	var dz0 := hz - hd * 0.5 - 1.8
	var dz1 := hz + hd * 0.5 + 0.2
	var pile := Color(0.32, 0.27, 0.22)
	for i in 3:
		for k in 3:
			var p := Vector3(lerpf(dx0 + 0.25, dx1 - 0.25, i * 0.5), 0, lerpf(dz0 + 0.25, dz1 - 0.25, k * 0.5))
			mb.cylinder(p, 0.2, PH, pile, 6)
			_col(out, p + Vector3(0, PH * 0.5, 0), Vector3(0.45, PH, 0.45))
	for i in 2:
		var xa := lerpf(dx0 + 0.25, dx1 - 0.25, i * 0.5)
		var xb := lerpf(dx0 + 0.25, dx1 - 0.25, (i + 1) * 0.5)
		_beam(mb, Vector3(xa, 0.3, dz0 + 0.25), Vector3(xb, PH - 0.2, dz0 + 0.25), 0.12, pile)
		_beam(mb, Vector3(xa, PH - 0.2, dz0 + 0.25), Vector3(xb, 0.3, dz0 + 0.25), 0.12, pile)
	var deck := MeshBuilder.glow(OLD_WOOD.lightened(0.1), MeshBuilder.SIDING)
	mb.box(Vector3(0, PH, (dz0 + dz1) * 0.5), Vector3(dx1 - dx0, 0.18, dz1 - dz0), deck)
	var paint: Color = [Color(0.55, 0.75, 0.72), Color(0.95, 0.85, 0.55), WHITE, Color(0.62, 0.72, 0.88), Color(0.85, 0.62, 0.55)][rng.randi() % 5]
	var body := MeshBuilder.glow(paint, MeshBuilder.SIDING)
	mb.box(Vector3(0, PH + 1.5, hz), Vector3(hw, 3.0, hd), body)
	var roof: Color = _pick(TIN_ROOFS, rng)
	_hip(mb, Vector3(0, PH + 3.0, (dz0 + dz1) * 0.5), dx1 - dx0 + 0.4, dz1 - dz0 + 0.4, 1.8, MeshBuilder.glow(roof, MeshBuilder.SEAM_ROOF))
	for x: float in [dx0 + 0.1, 0.0, dx1 - 0.1]:
		mb.box(Vector3(x, PH + 1.5, dz0 + 0.1), Vector3(0.14, 3.0, 0.14), TRIM)
	var fz := hz - hd * 0.5
	mb.box(Vector3(hw * 0.15, PH + 1.1, fz - 0.04), Vector3(0.9, 2.1, 0.08), WOOD)
	_windows(mb, Vector3(-hw * 0.5, PH + 1.6, fz), Vector3(hw * 0.05, PH + 1.6, fz), maxi(1, int(hw * 0.55 / 2.2)), Vector2(1.0, 1.3), rng, Vector3.FORWARD, 0.5, TRIM)
	_all_windows(mb, -hw * 0.5, hw * 0.5, fz, hz + hd * 0.5, PH, 1, 3.0, 3.0, Vector2(0.9, 1.2), rng, 0.5)
	# Rails round the deck, open at the stair head.
	var rail := TRIM.darkened(0.1)
	mb.box(Vector3((dx0 + 3.6 + dx1) * 0.5, PH + 1.0, dz0 + 0.05), Vector3(dx1 - dx0 - 3.6, 0.07, 0.07), rail)
	for x: float in [dx0 + 0.05, dx1 - 0.05]:
		mb.box(Vector3(x, PH + 1.0, (dz0 + dz1) * 0.5), Vector3(0.07, 0.07, dz1 - dz0), rail)
	# Stair along the front from the yard up to the deck.
	var sz := dz0 - 0.6
	var foot := Vector3(dx0 + 3.6, 0, sz)
	for k in 8:
		mb.box(Vector3(foot.x - (k + 0.5) * 0.45, (k + 1) * PH / 8.0, sz), Vector3(0.45, 0.06, 1.0), deck)
	for s: float in [-0.5, 0.5]:
		_beam(mb, Vector3(foot.x, 0.1, sz + s), Vector3(dx0, PH, sz + s), 0.1, pile, 0.06)
	_col(out, Vector3(dx0 + 1.8, 0.7, sz), Vector3(3.6, 1.4, 1.1))
	# Skiff and a water tank under the house.
	_boat(mb, Vector3(dx1 - 1.6, 0.05, hz), 0.0, minf(4.0, hd * 0.8), Color(0.2, 0.35, 0.5))
	mb.cylinder(Vector3(dx0 + 1.0, 0, hz + hd * 0.25), 0.6, 1.4, Color(0.25, 0.3, 0.28), 8)


## Steel water tower: four braced legs, a riser, a banded tank, cone roof.
static func water_tower(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var s := minf(w, d)
	var th := clampf(s * 1.25, 10.0, 18.0)
	var r := s * 0.28 + 0.5
	var paint: Color = [Color(0.82, 0.88, 0.92), WHITE, Color(0.72, 0.8, 0.86)][rng.randi() % 3]
	var leg := Color(0.55, 0.6, 0.64)
	var feet: Array[Vector3] = []
	var tops: Array[Vector3] = []
	for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		feet.append(Vector3(c.x * s * 0.36, 0, c.y * s * 0.36))
		tops.append(Vector3(c.x * r * 0.7, th, c.y * r * 0.7))
	for i in 4:
		_beam(mb, feet[i], tops[i], 0.35, leg)
		_col(out, feet[i] + Vector3(0, 1.5, 0), Vector3(0.8, 3.0, 0.8))
	for level: float in [0.33, 0.66]:
		for i in 4:
			var j := (i + 1) % 4
			var a := feet[i].lerp(tops[i], level)
			var b := feet[j].lerp(tops[j], level)
			_beam(mb, a, b, 0.14, leg)
			_beam(mb, feet[i].lerp(tops[i], level - 0.33), b, 0.08, leg)
			_beam(mb, feet[j].lerp(tops[j], level - 0.33), a, 0.08, leg)
	mb.cylinder(Vector3.ZERO, 0.45, th, leg, 6)
	_col(out, Vector3(0, 1.5, 0), Vector3(1.0, 3.0, 1.0))
	var tank_h := r * 1.1
	mb.cylinder(Vector3(0, th - 0.2, 0), r + 0.5, 0.15, DARK, 12)
	mb.cylinder(Vector3(0, th, 0), r, tank_h, MeshBuilder.glow(paint, MeshBuilder.GLOSS), 12)
	mb.cylinder(Vector3(0, th + tank_h * 0.45, 0), r + 0.03, 0.9, _pick(ACCENTS, rng), 12)
	_cone(mb, Vector3(0, th + tank_h, 0), r + 0.1, r * 0.45, MeshBuilder.glow(paint.darkened(0.12), MeshBuilder.GLOSS), 12)
	mb.ball(Vector3(0, th + tank_h + r * 0.45 + 0.1, 0), Vector3(0.2, 0.2, 0.2), leg, 5, 2)
	mb.box(Vector3(0, th * 0.5, -0.47), Vector3(0.4, th, 0.05), DARK)


## Farm windpump: lattice tower, a many-bladed wheel facing the lane, a tail
## vane, and a round stock tank.
static func windpump(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var s := minf(w, d)
	var h := clampf(s * 1.15, 6.0, 10.0)
	var foot := s * 0.18
	var galv := MeshBuilder.glow(Color(0.72, 0.74, 0.76), MeshBuilder.METAL)
	var feet: Array[Vector3] = []
	var tops: Array[Vector3] = []
	for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		feet.append(Vector3(c.x * foot, 0, c.y * foot))
		tops.append(Vector3(c.x * 0.3, h, c.y * 0.3))
	for i in 4:
		_beam(mb, feet[i], tops[i], 0.12, galv)
		_col(out, feet[i] + Vector3(0, 1.0, 0), Vector3(0.3, 2.0, 0.3))
		for level: float in [0.3, 0.6]:
			_beam(mb, feet[i].lerp(tops[i], level), feet[(i + 1) % 4].lerp(tops[(i + 1) % 4], level), 0.06, galv)
	mb.box(Vector3(0, h, 0), Vector3(0.9, 0.08, 0.9), WOOD)
	mb.box(Vector3(0, h + 0.3, 0), Vector3(0.4, 0.4, 0.8), MeshBuilder.glow(Color(0.5, 0.52, 0.55), MeshBuilder.METAL))
	mb.cylinder(Vector3(0, 0, 0), 0.05, h, DARK, 4)
	var hub := Vector3(0, h + 0.4, -0.5)
	var radius := clampf(s * 0.22, 1.1, 2.0)
	var saved: Transform3D = mb.xform
	for i in 16:
		var a := TAU * i / 16.0
		mb.xform = saved * Transform3D(Basis(Vector3.BACK, a), hub)
		mb.box(Vector3(radius * 0.58, 0, 0), Vector3(radius * 0.78, radius * 0.18, 0.03), galv)
	mb.xform = saved
	for i in 16:
		var a0 := TAU * i / 16.0
		var a1 := TAU * (i + 1) / 16.0
		_beam(mb, hub + Vector3(cos(a0), sin(a0), 0) * radius, hub + Vector3(cos(a1), sin(a1), 0) * radius, 0.05, DARK)
	mb.box(hub + Vector3(0, 0, -0.1), Vector3(0.3, 0.3, 0.3), DARK)
	var tail := Vector3(0, h + 0.4, radius * 1.1)
	_beam(mb, Vector3(0, h + 0.4, 0.2), tail, 0.07, galv)
	mb.box(tail + Vector3(0, 0.1, 0.3), Vector3(0.03, radius * 0.55, radius * 0.8), MeshBuilder.glow(Color(0.85, 0.85, 0.8), MeshBuilder.GLOSS))
	var tr := s * 0.15
	var tank := Vector3(0, 0, s * 0.3)
	mb.cylinder(tank, tr, 0.7, galv, 10)
	mb.cylinder(tank + Vector3(0, 0.7, 0), tr - 0.1, 0.01, Color(0.32, 0.45, 0.5), 10)
	_beam(mb, Vector3(0.1, 0.6, 0.1), tank + Vector3(0, 0.75, -tr * 0.8), 0.08, galv)
	_col(out, tank + Vector3(0, 0.35, 0), Vector3(tr * 1.7, 0.7, tr * 1.7))


# --- Roadside and town ---------------------------------------------------------

## A fuel pump facing the lanes either side (along X).
static func _pump(mb, p: Vector3, accent: Color, tall := 1.75) -> void:
	mb.box(p + Vector3(0, tall * 0.5, 0), Vector3(0.6, tall, 0.9), MeshBuilder.glow(WHITE, MeshBuilder.GLOSS))
	mb.box(p + Vector3(0, tall - 0.15, 0), Vector3(0.64, 0.3, 0.94), accent)
	for s: float in [-1.0, 1.0]:
		mb.box(p + Vector3(s * 0.31, tall * 0.62, 0), Vector3(0.04, 0.4, 0.5), MeshBuilder.glow(Color(0.3, 0.6, 0.7), MeshBuilder.GLOW_WINDOW))
		mb.box(p + Vector3(s * 0.33, tall * 0.4, 0.25), Vector3(0.06, 0.5, 0.1), DARK)


static func _ambulance(mb, out: Array, p: Vector3, yaw: float) -> void:
	var saved: Transform3D = mb.xform
	mb.xform = saved * Transform3D(Basis(Vector3.UP, yaw), p)
	var white := MeshBuilder.glow(WHITE, MeshBuilder.GLOSS)
	mb.box(Vector3(0, 1.0, -2.3), Vector3(2.0, 1.2, 1.4), white)
	mb.box(Vector3(0, 1.75, -2.1), Vector3(1.9, 0.6, 1.0), MeshBuilder.glow(Color(0.2, 0.25, 0.3), MeshBuilder.GLASS))
	mb.box(Vector3(0, 1.6, 0.6), Vector3(2.2, 2.6, 4.4), white)
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(s * 1.11, 1.3, 0.2), Vector3(0.04, 0.35, 5.6), Color(0.9, 0.2, 0.15))
		mb.box(Vector3(s * 0.7, 2.98, -1.3), Vector3(0.5, 0.18, 0.3), MeshBuilder.glow(Color(1.0, 0.2, 0.15), MeshBuilder.GLOW_NEON))
	for x: float in [-0.9, 0.9]:
		for z: float in [-2.0, 1.9]:
			_wheel(mb, Vector3(x, 0.4, z), 0.4, 0.28)
	mb.xform = saved
	_col(out, p + Vector3(0, 1.5, 0), Vector3(2.2, 3.0, 6.2), yaw)


## A white cruiser with a dark band and a light bar (police post).
static func _cruiser(mb, out: Array, p: Vector3, yaw: float) -> void:
	_car(mb, out, p, yaw, WHITE)
	var saved: Transform3D = mb.xform
	mb.xform = saved * Transform3D(Basis(Vector3.UP, yaw), p)
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(s * 0.91, 0.65, 0.2), Vector3(0.03, 0.25, 3.0), Color(0.12, 0.16, 0.3))
	mb.box(Vector3(-0.35, 1.5, 0.0), Vector3(0.6, 0.12, 0.3), MeshBuilder.glow(Color(1.0, 0.2, 0.15), MeshBuilder.GLOW_NEON))
	mb.box(Vector3(0.35, 1.5, 0.0), Vector3(0.6, 0.12, 0.3), MeshBuilder.glow(Color(0.2, 0.4, 1.0), MeshBuilder.GLOW_NEON))
	mb.xform = saved


## A blue hospital sign: a white H on a blue panel, on a low plinth.
static func _h_sign(mb, out: Array, p: Vector3, size: float) -> void:
	mb.box(p + Vector3(0, 0.3, 0), Vector3(size * 1.2, 0.6, 0.8), MeshBuilder.glow(CONCRETE, MeshBuilder.CONCRETE))
	var c := p + Vector3(0, 0.6 + size * 0.5, 0)
	mb.box(c, Vector3(size, size, 0.4), Color(0.12, 0.3, 0.7))
	for s: float in [-1.0, 1.0]:
		mb.box(c + Vector3(-size * 0.22, 0, s * 0.21), Vector3(size * 0.14, size * 0.65, 0.03), MeshBuilder.glow(WHITE, MeshBuilder.GLOW_NEON))
		mb.box(c + Vector3(size * 0.22, 0, s * 0.21), Vector3(size * 0.14, size * 0.65, 0.03), MeshBuilder.glow(WHITE, MeshBuilder.GLOW_NEON))
		mb.box(c + Vector3(0, 0, s * 0.21), Vector3(size * 0.4, size * 0.13, 0.03), MeshBuilder.glow(WHITE, MeshBuilder.GLOW_NEON))
	_col(out, p + Vector3(0, (size + 0.6) * 0.5, 0), Vector3(size * 1.2, size + 0.6, 0.8))


## Gas station: a canopy over pump islands up front (the forecourt stays
## open to the street), a kiosk at the back and a price sign at the corner.
static func gas_station(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var accent: Color = [Color(0.1, 0.5, 0.45), Color(0.85, 0.35, 0.12), Color(0.2, 0.35, 0.7), Color(0.75, 0.15, 0.2)][rng.randi() % 4]
	var accent2: Color = YELLOW if accent.r < 0.5 else Color(0.15, 0.2, 0.3)
	_pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, MeshBuilder.glow(CONCRETE, MeshBuilder.CONCRETE))
	# Kiosk.
	var kw := clampf(w * 0.45, 8.0, 18.0)
	var kd := clampf(d * 0.25, 5.5, 9.0)
	var kz := d * 0.5 - 1.0 - kd * 0.5
	var kf := kz - kd * 0.5 - 0.04
	const KH := 4.2
	_solid(mb, out, Vector3(0, KH * 0.5, kz), Vector3(kw, KH, kd), WHITE.darkened(0.05))
	mb.box(Vector3(-kw * 0.1, 1.5, kf), Vector3(kw * 0.6, 2.4, 0.08), MeshBuilder.glow(SHOP_GLASS, MeshBuilder.GLOW_WINDOW))
	mb.box(Vector3(kw * 0.3, 1.25, kf), Vector3(1.6, 2.5, 0.08), MeshBuilder.glow(PANE, MeshBuilder.GLASS))
	mb.box(Vector3(0, KH - 0.5, kf - 0.04), Vector3(kw, 0.8, 0.1), accent)
	mb.box(Vector3(0, KH - 0.5, kf - 0.1), Vector3(kw * 0.5, 0.4, 0.04), MeshBuilder.glow(accent2.lightened(0.3), MeshBuilder.GLOW_NEON))
	_flat_roof(mb, 0, kz, kw, kd, KH, rng, accent.darkened(0.2), true)
	mb.box(Vector3(-kw * 0.5 + 0.6, 0.55, kf - 0.5), Vector3(1.2, 1.1, 0.7), MeshBuilder.glow(WHITE, MeshBuilder.GLOSS))
	mb.box(Vector3(-kw * 0.5 + 0.6, 0.85, kf - 0.86), Vector3(1.0, 0.3, 0.02), Color(0.2, 0.5, 0.85))
	_col(out, Vector3(-kw * 0.5 + 0.6, 0.55, kf - 0.5), Vector3(1.2, 1.1, 0.7))
	# Canopy over the islands.
	var cw := clampf(w * 0.62, 11.0, 26.0)
	var cd := clampf(d * 0.32, 6.5, 12.0)
	var cz := kz - kd * 0.5 - 3.0 - cd * 0.5
	var ni := 2 if cw < 18.0 else 3
	var posts: Array = []
	for i in ni:
		var x := -cw * 0.5 + cw * (i + 0.5) / ni
		mb.box(Vector3(x, 0.1, cz), Vector3(1.2, 0.2, cd * 0.72), MeshBuilder.glow(CONCRETE.lightened(0.1), MeshBuilder.CONCRETE))
		for s: float in [-1.0, 1.0]:
			_pump(mb, Vector3(x, 0.2, cz + s * cd * 0.2), accent)
			mb.cylinder(Vector3(x, 0.2, cz + s * cd * 0.34), 0.12, 0.9, MeshBuilder.glow(YELLOW, MeshBuilder.GLOSS), 6)
		mb.box(Vector3(x, 2.6, cz), Vector3(0.35, 5.2, 0.35), STEEL)
		_col(out, Vector3(x, 0.9, cz), Vector3(1.3, 1.8, cd * 0.72))
	var top := 5.4
	mb.box(Vector3(0, top - 0.45, cz), Vector3(cw, 0.9, cd), MeshBuilder.glow(WHITE, MeshBuilder.GLOSS))
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(0, top - 0.55, cz + s * (cd * 0.5 + 0.03)), Vector3(cw, 0.35, 0.06), accent)
		mb.box(Vector3(s * (cw * 0.5 + 0.03), top - 0.55, cz), Vector3(0.06, 0.35, cd), accent)
	mb.box(Vector3(0, top + 0.02, cz), Vector3(cw - 0.4, 0.02, cd - 0.4), MeshBuilder.glow(Color(0.86, 0.87, 0.88), MeshBuilder.ROOF))
	mb.box(Vector3(cw * 0.3, top - 0.45, cz - cd * 0.5 - 0.06), Vector3(2.4, 0.6, 0.06), MeshBuilder.glow(accent2, MeshBuilder.GLOW_NEON))
	for x: float in [-cw * 0.25, cw * 0.25]:
		mb.box(Vector3(x, top - 0.95, cz), Vector3(cw * 0.3, 0.04, cd * 0.6), MeshBuilder.glow(Color(1.0, 0.98, 0.92), MeshBuilder.GLOW_LAMP))
	_pylon(mb, out, Vector3(w * 0.5 - 1.6, 0, -d * 0.5 + 1.6), 6.0, Vector2(2.4, 3.0), accent, Color(1.0, 0.55, 0.2))
	# Air pump, dumpster, a car at a pump now and then.
	_post(mb, out, Vector3(-w * 0.5 + 1.2, 0, kz), 1.4, 0.4, Color(0.85, 0.2, 0.15))
	_solid(mb, out, Vector3(w * 0.5 - 1.6, 0.75, d * 0.5 - 1.4), Vector3(2.0, 1.5, 1.2), Color(0.2, 0.4, 0.3))
	if rng.randf() < 0.6:
		_car(mb, out, Vector3(-cw * 0.5 + cw / ni - 1.9, 0, cz), 0.0, _pick(PAINTS, rng))


## Roadside diner: a streamlined stainless dining car with rounded ends,
## an enamel band, ribbon windows, a barrel roof and a neon arrow sign.
static func diner(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var enamel: Color = [Color(0.75, 0.12, 0.15), Color(0.1, 0.55, 0.6), Color(0.2, 0.35, 0.7), Color(0.95, 0.6, 0.65)][rng.randi() % 4]
	var steel := MeshBuilder.glow(STEEL.lightened(0.1), MeshBuilder.METAL)
	var paint := MeshBuilder.glow(enamel, MeshBuilder.GLOSS)
	var bw := clampf(w * 0.7, 10.0, 20.0)
	var bd := clampf(d * 0.26, 5.0, 8.0)
	var kd := 3.0
	var cz := d * 0.5 - 1.0 - kd - bd * 0.5
	var fz := cz - bd * 0.5
	var r := bd * 0.5
	var mid := bw - bd
	const H := 3.8
	_pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, MeshBuilder.glow(ASPHALT, MeshBuilder.ASPHALT))
	mb.box(Vector3(0, 0.25, cz), Vector3(mid, 0.5, bd + 0.02), DARK.lightened(0.15))
	mb.box(Vector3(0, 1.05, cz), Vector3(mid, 1.1, bd + 0.04), paint)
	mb.box(Vector3(0, 2.7, cz), Vector3(mid, 2.2, bd), steel)
	for s: float in [-1.0, 1.0]:
		var c := Vector3(s * mid * 0.5, 0, cz)
		mb.cylinder(c, r + 0.02, 1.6, paint, 12)
		mb.cylinder(c + Vector3(0, 1.6, 0), r, H - 1.6, steel, 12)
		mb.ball(c + Vector3(0, H, 0), Vector3(r + 0.15, 0.9, r + 0.15), MeshBuilder.glow(WHITE, MeshBuilder.GLOSS), 12, 4)
	_col(out, Vector3(0, H * 0.5, cz), Vector3(bw, H, bd))
	_vault(mb, Vector3(0, 0, cz), _arch(r + 0.15, 0.9, H, 6), mid, true, MeshBuilder.glow(WHITE, MeshBuilder.GLOSS), WHITE, false)
	for z: float in [fz - 0.04, cz + bd * 0.5 + 0.04]:
		mb.box(Vector3(0, 2.4, z), Vector3(mid, 1.1, 0.08), MeshBuilder.glow(SHOP_GLASS, MeshBuilder.GLOW_WINDOW))
		mb.box(Vector3(0, 1.62, z), Vector3(mid, 0.1, 0.1), steel)
		mb.box(Vector3(0, H - 0.15, z), Vector3(mid, 0.18, 0.1), MeshBuilder.glow(enamel.lightened(0.3), MeshBuilder.GLOW_NEON))
		for k in int(mid / 1.4):
			mb.box(Vector3(-mid * 0.5 + 1.4 * (k + 1), 2.4, z), Vector3(0.08, 1.1, 0.12), steel)
	# Vestibule and steps.
	_solid(mb, out, Vector3(0, 1.6, fz - 0.8), Vector3(2.6, 3.2, 1.6), paint)
	mb.box(Vector3(0, 3.25, fz - 0.8), Vector3(2.9, 0.12, 1.9), steel)
	mb.box(Vector3(0, 1.35, fz - 1.62), Vector3(1.2, 2.3, 0.06), MeshBuilder.glow(SHOP_GLASS, MeshBuilder.GLOW_WINDOW))
	mb.box(Vector3(0, 0.15, fz - 2.0), Vector3(2.0, 0.3, 0.8), MeshBuilder.glow(CONCRETE, MeshBuilder.CONCRETE))
	# Kitchen annex behind.
	var kz := cz + bd * 0.5 + kd * 0.5
	_solid(mb, out, Vector3(0, 1.7, kz), Vector3(bw * 0.6, 3.4, kd), WHITE.darkened(0.08))
	mb.box(Vector3(0, 3.45, kz), Vector3(bw * 0.6, 0.1, kd), MeshBuilder.glow(Buildings.MEMBRANES[1], MeshBuilder.ROOF))
	Buildings._hvac(mb, Vector3(-bw * 0.12, 3.4, kz), Vector3(1.8, 0.8, 1.2))
	mb.box(Vector3(bw * 0.15, 3.9, kz), Vector3(0.6, 1.0, 0.6), steel)
	_solid(mb, out, Vector3(bw * 0.3 + 1.4, 0.75, kz), Vector3(1.8, 1.5, 1.2), Color(0.2, 0.4, 0.3))
	# Parking in front and the arrow sign.
	var n := int(mid / 2.7)
	_stalls(mb, -n * 1.35, fz - 2.6, n, 2.7, 5.0, -1.0)
	var sp := Vector3(-w * 0.5 + 2.0, 0, -d * 0.5 + 1.4)
	_pylon(mb, out, sp, 6.5, Vector2(3.4, 1.6), enamel, Color(1.0, 0.85, 0.5))
	var neon := MeshBuilder.glow(Color(1.0, 0.35, 0.3), MeshBuilder.GLOW_NEON)
	_beam(mb, sp + Vector3(0.4, 4.6, 0), sp + Vector3(2.8, 4.6, 0), 0.25, neon, 0.25)
	_beam(mb, sp + Vector3(2.9, 4.6, 0), sp + Vector3(2.3, 5.2, 0), 0.22, neon, 0.25)
	_beam(mb, sp + Vector3(2.9, 4.6, 0), sp + Vector3(2.3, 4.0, 0), 0.22, neon, 0.25)


## Two-storey (or one) L-shaped motel: rooms along the back and down one
## side, a walkway with a rail, an office at the street end, parking in the
## L, a fenced pool, and a tall neon sign.
static func motel(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var floors := 2 if rng.randf() < 0.6 else 1
	const FH := 3.0
	var H := floors * FH
	var body: Color = _pick(PASTELS, rng)
	var accent: Color = _pick(ACCENTS, rng)
	var roof: Color = [TERRACOTTA, Color(0.25, 0.5, 0.55), Color(0.3, 0.35, 0.5), SHINGLES[2]][rng.randi() % 4]
	var wd := clampf(d * 0.22, 6.5, 9.0)
	var x0 := -w * 0.5 + 1.0
	var x1 := w * 0.5 - 1.0
	var zb0 := d * 0.5 - 1.0 - wd
	var zl0 := -d * 0.5 + 6.0
	_pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, MeshBuilder.glow(ASPHALT, MeshBuilder.ASPHALT))
	# Wings.
	_solid(mb, out, Vector3(0, H * 0.5, zb0 + wd * 0.5), Vector3(x1 - x0, H, wd), body)
	_solid(mb, out, Vector3(x0 + wd * 0.5, H * 0.5, (zl0 + zb0) * 0.5), Vector3(wd, H, zb0 - zl0), body)
	_hip(mb, Vector3(0.4, H, zb0 + wd * 0.5 - 0.8), x1 - x0 + 0.6, wd + 2.2, 2.0, MeshBuilder.glow(roof, MeshBuilder.SEAM_ROOF))
	_hip(mb, Vector3(x0 + wd * 0.5 + 0.8, H, (zl0 + zb0) * 0.5 - 0.6), wd + 2.2, zb0 - zl0 + 1.2, 2.0, MeshBuilder.glow(roof, MeshBuilder.SEAM_ROOF))
	# Rooms: a door, a window and a wall AC unit each, on every floor.
	var unit := MeshBuilder.glow(Color(0.8, 0.82, 0.84), MeshBuilder.METAL)
	var nb := int((x1 - x0 - wd - 1.6) / 4.0)
	var nl := int((zb0 - zl0 - 1.6) / 4.0)
	for f in floors:
		var y := f * FH
		for i in nb:
			var x := x0 + wd + 1.6 + 4.0 * i + 1.0
			mb.box(Vector3(x, y + 1.05, zb0 - 0.04), Vector3(0.9, 2.1, 0.08), accent)
			mb.box(Vector3(x + 1.6, y + 1.6, zb0 - 0.04), Vector3(1.4, 1.1, 0.08), Buildings._window(rng, 0.5))
			mb.box(Vector3(x + 1.6, y + 0.7, zb0 - 0.2), Vector3(0.7, 0.45, 0.35), unit)
		for i in nl:
			var z := zl0 + 4.0 * i + 1.0
			var xf := x0 + wd + 0.04
			mb.box(Vector3(xf, y + 1.05, z), Vector3(0.08, 2.1, 0.9), accent)
			mb.box(Vector3(xf, y + 1.6, z + 1.6), Vector3(0.08, 1.1, 1.4), Buildings._window(rng, 0.5))
			mb.box(Vector3(xf + 0.16, y + 0.7, z + 1.6), Vector3(0.35, 0.45, 0.7), unit)
	# Walkway and rail along both wings, with posts and a stair.
	var rail := MeshBuilder.glow(WHITE, MeshBuilder.GLOSS)
	var post_n := maxi(2, int((x1 - x0 - wd) / 4.0))
	for i in post_n + 1:
		var x := x0 + wd + 1.6 + (x1 - x0 - wd - 1.8) * i / post_n
		_post(mb, out, Vector3(x, 0, zb0 - 1.5), H, 0.2, rail)
	for i in maxi(2, int((zb0 - zl0) / 4.0)) + 1:
		var z := zl0 + 0.2 + (zb0 - 1.6 - zl0) * i / maxi(2, int((zb0 - zl0) / 4.0))
		_post(mb, out, Vector3(x0 + wd + 1.5, 0, z), H, 0.2, rail)
	if floors > 1:
		var deck := MeshBuilder.glow(CONCRETE, MeshBuilder.CONCRETE)
		mb.box(Vector3((x0 + wd + x1) * 0.5, FH, zb0 - 0.8), Vector3(x1 - x0 - wd, 0.2, 1.6), deck)
		mb.box(Vector3(x0 + wd + 0.8, FH, (zl0 + zb0) * 0.5), Vector3(1.6, 0.2, zb0 - zl0), deck)
		mb.box(Vector3((x0 + wd + x1) * 0.5 + 0.8, FH + 1.0, zb0 - 1.55), Vector3(x1 - x0 - wd - 1.6, 0.08, 0.08), rail)
		mb.box(Vector3(x0 + wd + 1.55, FH + 1.0, (zl0 + zb0) * 0.5 - 0.8), Vector3(0.08, 0.08, zb0 - zl0 - 1.6), rail)
		var st := Vector3(x1 - 0.6, 0, zb0 - 2.4)
		for k in 8:
			mb.box(Vector3(st.x - (k + 0.5) * 0.4, (k + 1) * FH / 8.0, st.z), Vector3(0.4, 0.06, 1.1), deck)
		_beam(mb, Vector3(st.x, 0.1, st.z - 0.55), Vector3(st.x - 3.2, FH, st.z - 0.55), 0.12, rail)
		_col(out, Vector3(st.x - 1.6, 0.7, st.z), Vector3(3.2, 1.4, 1.2))
	# Office at the street end of the side wing.
	var oz0 := -d * 0.5 + 1.5
	_solid(mb, out, Vector3(x0 + wd * 0.5, 1.8, (oz0 + zl0) * 0.5), Vector3(wd, 3.6, zl0 - oz0), body.darkened(0.06))
	mb.box(Vector3(x0 + wd * 0.5, 1.5, oz0 - 0.04), Vector3(wd * 0.7, 2.2, 0.08), MeshBuilder.glow(SHOP_GLASS, MeshBuilder.GLOW_WINDOW))
	mb.box(Vector3(x0 + wd * 0.5, 3.6, (oz0 + zl0) * 0.5), Vector3(wd + 0.6, 0.3, zl0 - oz0 + 0.6), accent)
	mb.box(Vector3(x0 + wd * 0.5, 3.77, (oz0 + zl0) * 0.5), Vector3(wd, 0.04, zl0 - oz0), MeshBuilder.glow(Buildings.MEMBRANES[0], MeshBuilder.ROOF))
	mb.box(Vector3(x0 + wd + 0.6, 0.9, oz0 + 1.0), Vector3(0.8, 1.8, 0.8), MeshBuilder.glow(Color(0.85, 0.2, 0.2), MeshBuilder.GLOSS))
	_pylon(mb, out, Vector3(x0 + wd + 2.0, 0, -d * 0.5 + 0.8), 7.0, Vector2(3.6, 2.2), accent, _pick(NEONS, rng))
	mb.box(Vector3(x0 + wd + 2.0, 5.2, -d * 0.5 + 0.8), Vector3(2.4, 0.6, 0.4), MeshBuilder.glow(Color(1.0, 0.3, 0.3), MeshBuilder.GLOW_NEON))
	# Parking stalls facing the rooms.
	_stalls(mb, x0 + wd + 1.6, zb0 - 1.8, nb, 4.0, 5.5, -1.0)
	for i in nl + 1:
		var z := zl0 + 4.0 * i
		_line(mb, Vector3(x0 + wd + 1.8, 0, z), Vector3(x0 + wd + 7.3, 0, z), 0.12)
	# Pool in the front corner, fenced.
	if w >= 30.0 and zb0 - 7.5 > -d * 0.5 + 11.0:
		var px0 := x1 - 9.0
		var px1 := x1 - 0.5
		var pz0 := -d * 0.5 + 3.0
		var pz1 := -d * 0.5 + 10.0
		_pad(mb, px0, px1, pz0, pz1, MeshBuilder.glow(Color(0.86, 0.84, 0.78), MeshBuilder.PAVING), 0.05)
		mb.box(Vector3((px0 + px1) * 0.5, 0.06, (pz0 + pz1) * 0.5), Vector3(px1 - px0 - 3.0, 0.04, pz1 - pz0 - 3.0), POOL)
		var fence := Color(0.9, 0.9, 0.88)
		Props.fence(mb, out, Vector3(px0, 0, pz0), Vector3(px1, 0, pz0), fence)
		Props.fence(mb, out, Vector3(px0, 0, pz1), Vector3(px1, 0, pz1), fence)
		Props.fence(mb, out, Vector3(px0, 0, pz0), Vector3(px0, 0, pz1), fence)
		Props.fence(mb, out, Vector3(px1, 0, pz0), Vector3(px1, 0, pz1), fence)
		for k in 2:
			mb.box(Vector3(px0 + 1.0 + k * 1.0, 0.3, pz1 - 0.7), Vector3(0.6, 0.15, 1.6), WHITE)
		mb.cylinder(Vector3(px1 - 1.0, 0, pz1 - 1.0), 0.04, 2.1, WHITE, 4)
		mb.ball(Vector3(px1 - 1.0, 2.15, pz1 - 1.0), Vector3(1.1, 0.28, 1.1), accent, 8, 2)


## Country general store: a false front with a sign board over a porch,
## a gable roof behind it, display windows, barrels and an old pump.
static func general_store(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var paint: Color = [BARN_RED, Color(0.85, 0.68, 0.3), WHITE, Color(0.45, 0.55, 0.6), OLD_WOOD][rng.randi() % 5]
	var body := MeshBuilder.glow(paint, MeshBuilder.SIDING)
	var bw := w - 2.0
	var bd := clampf(d * 0.6, 7.0, 14.0)
	var fz := -d * 0.5 + 3.2
	var cz := fz + bd * 0.5
	const H := 4.2
	_pad(mb, -w * 0.5, w * 0.5, -d * 0.5, fz - 2.4, MeshBuilder.glow(GRAVEL, MeshBuilder.CONCRETE))
	_solid(mb, out, Vector3(0, H * 0.5, cz), Vector3(bw, H, bd), body)
	_gable(mb, 0, cz, H, bw + 0.6, bd + 0.4, 2.0, MeshBuilder.glow(_pick(TIN_ROOFS, rng), MeshBuilder.SEAM_ROOF), body, true)
	var facade := paint.lightened(0.08) if paint.v < 0.7 else paint.darkened(0.1)
	mb.box(Vector3(0, 3.6, fz - 0.1), Vector3(bw + 0.4, 7.2, 0.2), MeshBuilder.glow(facade, MeshBuilder.SIDING))
	mb.box(Vector3(0, 7.25, fz - 0.15), Vector3(bw + 0.7, 0.25, 0.45), TRIM)
	mb.box(Vector3(0, 5.6, fz - 0.24), Vector3(bw * 0.75, 1.3, 0.08), Color(0.95, 0.9, 0.78))
	for k in 5:
		mb.box(Vector3((k - 2) * bw * 0.13, 5.6, fz - 0.29), Vector3(bw * 0.09, 0.7, 0.03), Color(0.3, 0.15, 0.1))
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(s * bw * 0.28, 1.9, fz - 0.24), Vector3(bw * 0.3, 1.8, 0.08), MeshBuilder.glow(SHOP_GLASS, MeshBuilder.GLOW_WINDOW))
	mb.box(Vector3(0, 1.3, fz - 0.24), Vector3(1.2, 2.4, 0.08), WOOD.darkened(0.2))
	_windows(mb, Vector3(-bw * 0.5, 2.2, fz), Vector3(-bw * 0.5, 2.2, fz + bd), maxi(1, int(bd / 4.0)), Vector2(1.0, 1.3), rng, Vector3.LEFT, 0.3)
	_windows(mb, Vector3(bw * 0.5, 2.2, fz), Vector3(bw * 0.5, 2.2, fz + bd), maxi(1, int(bd / 4.0)), Vector2(1.0, 1.3), rng, Vector3.RIGHT, 0.3)
	# Porch with a shed roof.
	mb.box(Vector3(0, 0.45, fz - 1.3), Vector3(bw + 0.4, 0.12, 2.4), MeshBuilder.glow(WOOD.lightened(0.2), MeshBuilder.SIDING))
	mb.box(Vector3(0, 0.2, fz - 2.8), Vector3(2.0, 0.4, 0.8), MeshBuilder.glow(WOOD, MeshBuilder.SIDING))
	for i in 4:
		var x := -bw * 0.5 + 0.1 + (bw - 0.2) * i / 3.0
		_solid(mb, out, Vector3(x, 1.95, fz - 2.35), Vector3(0.16, 3.0, 0.16), WOOD)
	var r0 := Vector3(-bw * 0.5 - 0.2, 3.7, fz - 0.2)
	var r1 := Vector3(bw * 0.5 + 0.2, 3.7, fz - 0.2)
	mb.quad(r0, r1, r1 + Vector3(0, -0.4, -2.4), r0 + Vector3(0, -0.4, -2.4), Vector3(0, 2.4, -0.4).normalized(), MeshBuilder.glow(TIN, MeshBuilder.SEAM_ROOF))
	mb.box(Vector3(-bw * 0.3, 0.75, fz - 0.6), Vector3(1.6, 0.08, 0.45), WOOD)
	mb.box(Vector3(-bw * 0.3, 1.0, fz - 0.36), Vector3(1.6, 0.5, 0.06), WOOD)
	for k in 2:
		mb.cylinder(Vector3(bw * 0.3 + k * 0.7, 0.5, fz - 0.7), 0.3, 0.8, WOOD.darkened(0.15), 7)
	mb.box(Vector3(bw * 0.18, 0.95, fz - 0.6), Vector3(1.0, 0.9, 0.6), MeshBuilder.glow(WHITE, MeshBuilder.GLOSS))
	# A vintage pump out front.
	var pp := Vector3(bw * 0.5 - 0.8, 0, -d * 0.5 + 1.0)
	mb.box(pp + Vector3(0, 0.95, 0), Vector3(0.6, 1.9, 0.5), MeshBuilder.glow(Color(0.8, 0.15, 0.12), MeshBuilder.GLOSS))
	mb.ball(pp + Vector3(0, 2.15, 0), Vector3(0.3, 0.3, 0.3), MeshBuilder.glow(WHITE, MeshBuilder.GLOW_NEON), 6, 3)
	_col(out, pp + Vector3(0, 1.0, 0), Vector3(0.6, 2.0, 0.5))


## Truck stop: a tall diesel canopy over long islands, a travel centre with
## a diner end, truck stalls with parked rigs and a tall pylon sign.
static func truck_stop(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var accent: Color = [Color(0.8, 0.15, 0.15), Color(0.15, 0.35, 0.65), Color(0.1, 0.5, 0.35)][rng.randi() % 3]
	_pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, MeshBuilder.glow(ASPHALT, MeshBuilder.ASPHALT))
	# Diesel canopy.
	var lanes := 3 if w >= 60.0 else 2
	var cw := lanes * 6.5 + (lanes + 1) * 1.4
	var cl := clampf(d * 0.38, 14.0, 26.0)
	var cx := -w * 0.5 + 3.0 + cw * 0.5
	var cz := -d * 0.5 + 6.0 + cl * 0.5
	_pad(mb, cx - cw * 0.5 - 1.0, cx + cw * 0.5 + 1.0, cz - cl * 0.5 - 2.0, cz + cl * 0.5 + 2.0, MeshBuilder.glow(CONCRETE, MeshBuilder.CONCRETE), 0.04)
	for i in lanes + 1:
		var x := cx - cw * 0.5 + 0.7 + i * 7.9
		mb.box(Vector3(x, 0.12, cz), Vector3(1.4, 0.24, cl * 0.75), MeshBuilder.glow(CONCRETE.lightened(0.1), MeshBuilder.CONCRETE))
		for s: float in [-1.0, 1.0]:
			_pump(mb, Vector3(x, 0.24, cz + s * cl * 0.18), accent, 2.0)
			mb.box(Vector3(x, 3.2, cz + s * cl * 0.3), Vector3(0.4, 6.4, 0.4), STEEL)
		_col(out, Vector3(x, 1.0, cz), Vector3(1.5, 2.0, cl * 0.75))
	const TOP := 7.0
	mb.box(Vector3(cx, TOP - 0.55, cz), Vector3(cw + 1.0, 1.1, cl), MeshBuilder.glow(WHITE, MeshBuilder.GLOSS))
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(cx, TOP - 0.6, cz + s * (cl * 0.5 + 0.03)), Vector3(cw + 1.0, 0.45, 0.06), accent)
		mb.box(Vector3(cx + s * (cw * 0.5 + 0.53), TOP - 0.6, cz), Vector3(0.06, 0.45, cl), accent)
	mb.box(Vector3(cx, TOP + 0.02, cz), Vector3(cw + 0.6, 0.02, cl - 0.4), MeshBuilder.glow(Color(0.86, 0.87, 0.88), MeshBuilder.ROOF))
	mb.box(Vector3(cx, TOP - 0.55, cz - cl * 0.5 - 0.07), Vector3(5.0, 0.7, 0.06), MeshBuilder.glow(YELLOW, MeshBuilder.GLOW_NEON))
	# Travel centre: shop and a diner end.
	var bw := clampf(w * 0.42, 18.0, 34.0)
	var bd := clampf(d * 0.28, 11.0, 18.0)
	var bx := w * 0.5 - 2.0 - bw * 0.5
	var bz := d * 0.5 - 2.0 - bd * 0.5
	var bf := bz - bd * 0.5 - 0.04
	const BH := 5.5
	var shop_w := bw * 0.6
	var din_w := bw - shop_w
	_solid(mb, out, Vector3(bx - bw * 0.5 + shop_w * 0.5, BH * 0.5, bz), Vector3(shop_w, BH, bd), Color(0.86, 0.8, 0.68))
	_solid(mb, out, Vector3(bx + bw * 0.5 - din_w * 0.5, BH * 0.5, bz), Vector3(din_w, BH, bd), Color(0.93, 0.91, 0.84))
	mb.box(Vector3(bx - bw * 0.5 + shop_w * 0.5, 1.6, bf), Vector3(shop_w * 0.7, 2.6, 0.08), MeshBuilder.glow(SHOP_GLASS, MeshBuilder.GLOW_WINDOW))
	mb.box(Vector3(bx - bw * 0.5 + shop_w * 0.5, BH - 0.8, bf - 0.05), Vector3(shop_w - 1.0, 1.0, 0.1), accent)
	mb.box(Vector3(bx - bw * 0.5 + shop_w * 0.5, BH - 0.8, bf - 0.11), Vector3(shop_w * 0.6, 0.5, 0.04), MeshBuilder.glow(WHITE, MeshBuilder.GLOW_NEON))
	var dx := bx + bw * 0.5 - din_w * 0.5
	mb.box(Vector3(dx, 0.7, bf), Vector3(din_w, 1.4, 0.1), MeshBuilder.glow(Color(0.75, 0.12, 0.15), MeshBuilder.GLOSS))
	mb.box(Vector3(dx, 2.3, bf), Vector3(din_w - 1.0, 1.4, 0.08), MeshBuilder.glow(SHOP_GLASS, MeshBuilder.GLOW_WINDOW))
	mb.box(Vector3(dx, 3.2, bf - 0.04), Vector3(din_w, 0.12, 0.12), MeshBuilder.glow(STEEL, MeshBuilder.METAL))
	_flat_roof(mb, bx, bz, bw, bd, BH, rng, accent.darkened(0.3), true)
	mb.box(Vector3(dx, BH + 1.4, bf + 1.2), Vector3(din_w * 0.7, 1.6, 0.25), Color(0.75, 0.12, 0.15))
	mb.box(Vector3(dx, BH + 1.4, bf + 1.05), Vector3(din_w * 0.7 - 0.3, 1.3, 0.04), MeshBuilder.glow(Color(1.0, 0.85, 0.5), MeshBuilder.GLOW_NEON))
	_stalls(mb, bx - bw * 0.5, bf - 0.6, int(bw / 2.7), 2.7, 5.5, -1.0)
	# Truck stalls behind the canopy, with rigs parked.
	var tz0 := cz + cl * 0.5 + 3.0
	var tz1 := d * 0.5 - 1.0
	var tx1 := bx - bw * 0.5 - 3.0
	var length := minf(tz1 - tz0, 21.0)
	if length > 13.5:
		var n := int((tx1 - (-w * 0.5 + 2.0)) / 4.4)
		for i in n + 1:
			var x := -w * 0.5 + 2.0 + i * 4.4
			_line(mb, Vector3(x, 0, tz1), Vector3(x, 0, tz1 - length), 0.15, YELLOW)
		var colors := [WHITE, Color(0.2, 0.3, 0.55), Color(0.75, 0.75, 0.72)]
		for k in mini(2, n):
			var x := -w * 0.5 + 2.0 + 2.2 + (k * 2 + 1) * 4.4
			if x > tx1:
				break
			var tz := tz1 - 7.0
			_trailer(mb, out, Vector3(x, 0, tz), 0.0, colors[k % 3])
			if length > 20.5:
				_semi(mb, out, Vector3(x, 0, tz - 9.8), 0.0, [accent, Color(0.15, 0.15, 0.18)][k % 2])
	_pylon(mb, out, Vector3(w * 0.5 - 2.5, 0, -d * 0.5 + 2.5), 14.0, Vector2(5.0, 3.4), accent, Color(1.0, 0.75, 0.3))
	_solid(mb, out, Vector3(bx + bw * 0.5 - 1.0, 0.75, bz + bd * 0.5 + 1.0 if bz + bd * 0.5 + 1.8 < d * 0.5 else bz), Vector3(1.2, 1.5, 1.8), Color(0.2, 0.4, 0.3))


## Auto shop: block building with roll-up bays (one open), an office, a
## painted sign band, tyre stacks and a car waiting outside.
static func garage(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var bw := w - 3.0
	var bd := clampf(d * 0.5, 7.0, 14.0)
	var cz := d * 0.5 - 1.0 - bd * 0.5
	var fz := cz - bd * 0.5 - 0.04
	const H := 5.0
	var wall: Color = [Color(0.85, 0.83, 0.76), Color(0.72, 0.74, 0.76), Color(0.75, 0.82, 0.8), Color(0.9, 0.82, 0.62)][rng.randi() % 4]
	var accent: Color = _pick(PAINTS, rng)
	_pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, MeshBuilder.glow(CONCRETE.darkened(0.08), MeshBuilder.CONCRETE))
	_solid(mb, out, Vector3(0, H * 0.5, cz), Vector3(bw, H, bd), MeshBuilder.glow(wall, MeshBuilder.CONCRETE))
	var bays := clampi(int(bw * 0.65 / 4.2), 1, 3)
	var open_bay := rng.randi() % bays
	for i in bays:
		var x := -bw * 0.5 + 0.6 + 2.0 + i * 4.2
		if i == open_bay:
			mb.box(Vector3(x, 1.8, fz + 0.01), Vector3(3.4, 3.6, 0.06), Color(0.08, 0.08, 0.09))
			mb.box(Vector3(x, 3.4, fz - 0.02), Vector3(3.4, 0.4, 0.06), MeshBuilder.glow(Color(0.6, 0.62, 0.64), MeshBuilder.SIDING))
			for s: float in [-1.0, 1.0]:
				mb.box(Vector3(x + s * 1.3, 1.2, fz + 0.04), Vector3(0.2, 2.4, 0.04), MeshBuilder.glow(YELLOW, MeshBuilder.GLOSS))
		else:
			mb.box(Vector3(x, 1.8, fz - 0.02), Vector3(3.4, 3.6, 0.06), MeshBuilder.glow(Color(0.7, 0.72, 0.74), MeshBuilder.SIDING))
		mb.box(Vector3(x, 3.7, fz - 0.04), Vector3(3.7, 0.14, 0.1), accent.darkened(0.2))
	var ox := (-bw * 0.5 + 0.6 + bays * 4.2 + bw * 0.5) * 0.5
	mb.box(Vector3(ox - 0.6, 1.6, fz - 0.02), Vector3(1.8, 1.4, 0.08), MeshBuilder.glow(SHOP_GLASS, MeshBuilder.GLOW_WINDOW))
	mb.box(Vector3(ox + 1.2, 1.2, fz - 0.02), Vector3(1.0, 2.3, 0.08), MeshBuilder.glow(PANE, MeshBuilder.GLASS))
	mb.box(Vector3(0, H - 0.5, fz - 0.06), Vector3(bw, 0.8, 0.1), accent)
	for k in int(bw / 1.2) - 2:
		mb.box(Vector3(-bw * 0.5 + 1.5 + k * 1.2, H - 0.5, fz - 0.12), Vector3(0.7, 0.45, 0.03), WHITE)
	_flat_roof(mb, 0, cz, bw, bd, H, rng, wall.darkened(0.2), true)
	# Tyre stacks, drums, a car at the open bay and a wreck at the side.
	var tyre := Color(0.12, 0.12, 0.13)
	for k in 3:
		var p := Vector3(bw * 0.5 - 0.6 - k * 0.85, 0, fz - 0.8)
		mb.cylinder(p, 0.38, 0.25 * (3 + k % 2), tyre, 8)
		mb.cylinder(p + Vector3(0, 0.25 * (3 + k % 2), 0), 0.2, 0.01, Color(0.05, 0.05, 0.05), 8)
		_col(out, p + Vector3(0, 0.5, 0), Vector3(0.8, 1.0, 0.8))
	Props.barrel(mb, out, Vector3(-w * 0.5 + 0.8, 0, fz + 1.0), Color(0.2, 0.35, 0.6))
	Props.barrel(mb, out, Vector3(-w * 0.5 + 0.8, 0, fz + 2.0), Color(0.6, 0.2, 0.15))
	var room := fz + d * 0.5
	if room > 5.0:
		_car(mb, out, Vector3(-bw * 0.5 + 0.6 + 2.0 + open_bay * 4.2, 0, fz - 3.0), PI, _pick(PAINTS, rng))


## Small-town hall: two brick storeys under a hip roof, a white portico
## with a pediment, a cupola with clock faces, flagpole, lawn and oaks.
static func town_hall(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var bw := clampf(w * 0.7, 12.0, 26.0)
	var bd := clampf(d * 0.42, 8.0, 16.0)
	var fz := -d * 0.5 + clampf(d * 0.32, 6.0, 12.0)
	var cz := fz + bd * 0.5
	const H := 7.8
	var brick := MeshBuilder.glow(_pick(BRICKS, rng), MeshBuilder.BRICK)
	var slate := Color(0.3, 0.32, 0.36)
	_pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, MeshBuilder.glow(LAWN, MeshBuilder.GRASS))
	_pad(mb, -1.2, 1.2, -d * 0.5, fz, MeshBuilder.glow(CONCRETE, MeshBuilder.CONCRETE), 0.04)
	_solid(mb, out, Vector3(0, H * 0.5, cz), Vector3(bw, H, bd), brick)
	mb.box(Vector3(0, 0.4, cz), Vector3(bw + 0.1, 0.8, bd + 0.1), MeshBuilder.glow(CONCRETE.lightened(0.1), MeshBuilder.CONCRETE))
	mb.box(Vector3(0, H + 0.15, cz), Vector3(bw + 0.5, 0.3, bd + 0.5), TRIM)
	var rise := clampf(bd * 0.25, 2.0, 3.6)
	_hip(mb, Vector3(0, H + 0.3, cz), bw + 0.6, bd + 0.6, rise, slate)
	for f in 2:
		var y := 0.8 + f * 3.6 + 1.6
		_windows(mb, Vector3(-bw * 0.5, y, fz), Vector3(bw * 0.5, y, fz), maxi(3, int(bw / 2.2)), Vector2(1.1, 2.0), rng, Vector3.FORWARD, 0.4)
	_all_windows(mb, -bw * 0.5, bw * 0.5, fz, fz + bd, 0.8, 2, 3.6, 2.6, Vector2(1.0, 1.8), rng, 0.4)
	# Portico.
	var pw := clampf(bw * 0.42, 6.0, 10.0)
	var pd := 3.0
	var pz := fz - pd * 0.5
	mb.box(Vector3(0, 0.3, pz - 0.3), Vector3(pw + 0.8, 0.6, pd + 0.6), MeshBuilder.glow(CONCRETE.lightened(0.15), MeshBuilder.CONCRETE))
	mb.box(Vector3(0, 0.15, pz - pd * 0.5 - 0.6), Vector3(pw * 0.6, 0.3, 0.6), MeshBuilder.glow(CONCRETE.lightened(0.15), MeshBuilder.CONCRETE))
	for i in 4:
		var x := -pw * 0.5 + 0.5 + i * (pw - 1.0) / 3.0
		mb.cylinder(Vector3(x, 0.6, fz - pd + 0.5), 0.35, H - 1.4, TRIM, 8)
		_col(out, Vector3(x, (H - 0.8) * 0.5, fz - pd + 0.5), Vector3(0.7, H - 0.8, 0.7))
	mb.box(Vector3(0, H - 0.4, pz), Vector3(pw + 0.4, 0.8, pd + 0.2), TRIM)
	_gable(mb, 0, pz, H, pw + 0.5, pd + 0.5, 1.8, slate, TRIM, true)
	mb.box(Vector3(0, 1.8, fz - 0.05), Vector3(1.6, 3.0, 0.1), WOOD.darkened(0.25))
	mb.box(Vector3(0, 3.6, fz - 0.05), Vector3(1.6, 0.6, 0.1), MeshBuilder.glow(PANE, MeshBuilder.GLASS))
	# Cupola.
	var top := H + 0.3 + rise
	mb.box(Vector3(0, top + 0.4, cz), Vector3(2.4, 1.6, 2.4), TRIM)
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(0, top + 0.5, cz + s * 1.22), Vector3(1.0, 1.0, 0.04), WHITE.lightened(0.5))
		mb.box(Vector3(0, top + 0.6, cz + s * 1.25), Vector3(0.08, 0.4, 0.03), DARK)
		mb.box(Vector3(s * 1.22, top + 0.5, cz), Vector3(0.04, 1.0, 1.0), WHITE.lightened(0.5))
	mb.cylinder(Vector3(0, top + 1.2, cz), 0.85, 1.4, TRIM, 8)
	_cone(mb, Vector3(0, top + 2.6, cz), 1.05, 1.3, MeshBuilder.glow(Color(0.42, 0.62, 0.52), MeshBuilder.SEAM_ROOF), 8)
	mb.cylinder(Vector3(0, top + 3.9, cz), 0.04, 1.0, GOLD, 4)
	# Grounds: flagpole, lamps, oaks.
	_flagpole(mb, out, Vector3(-pw * 0.5 - 2.5, 0, -d * 0.5 + 2.0), 8.0, [Color(0.1, 0.45, 0.5), GOLD, WHITE])
	for s: float in [-1.0, 1.0]:
		Props.gas_lamp(mb, out, Vector3(s * 1.8, 0, -d * 0.5 + 1.5))
	if w >= 24.0 and fz + d * 0.5 > 8.0:
		for s: float in [-1.0, 1.0]:
			Props.oak(mb, out, Vector3(s * (w * 0.5 - 4.6), 0, -d * 0.5 + 4.6), rng)


## Roadhouse bar: a long low wood building with a tin roof and porch,
## neon window signs, a big neon roof sign, motorcycles and a pickup.
static func bar(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var paint: Color = [Color(0.4, 0.28, 0.2), Color(0.3, 0.38, 0.3), Color(0.5, 0.2, 0.16), Color(0.3, 0.3, 0.34)][rng.randi() % 4]
	var body := MeshBuilder.glow(paint, MeshBuilder.SIDING)
	var bw := clampf(w * 0.7, 10.0, 18.0)
	var bd := clampf(d * 0.42, 7.0, 13.0)
	var cz := d * 0.5 - 1.5 - bd * 0.5
	var fz := cz - bd * 0.5
	const H := 4.2
	_pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, MeshBuilder.glow(GRAVEL, MeshBuilder.CONCRETE))
	_solid(mb, out, Vector3(0, H * 0.5, cz), Vector3(bw, H, bd), body)
	var roof := MeshBuilder.glow(TIN.lerp(RUST, rng.randf() * 0.5), MeshBuilder.SEAM_ROOF)
	_gable(mb, 0, cz, H, bw + 0.8, bd + 0.8, 1.8, roof, body)
	# Porch.
	mb.box(Vector3(0, 0.35, fz - 1.2), Vector3(bw, 0.12, 2.4), MeshBuilder.glow(WOOD, MeshBuilder.SIDING))
	for i in 4:
		_solid(mb, out, Vector3(-bw * 0.5 + 0.1 + (bw - 0.2) * i / 3.0, 1.6, fz - 2.3), Vector3(0.16, 3.2, 0.16), WOOD.darkened(0.2))
	var r0 := Vector3(-bw * 0.5 - 0.2, 3.5, fz)
	var r1 := Vector3(bw * 0.5 + 0.2, 3.5, fz)
	mb.quad(r0, r1, r1 + Vector3(0, -0.4, -2.5), r0 + Vector3(0, -0.4, -2.5), Vector3(0, 2.5, -0.4).normalized(), roof)
	mb.box(Vector3(-bw * 0.15, 1.2, fz - 0.05), Vector3(1.2, 2.4, 0.1), WOOD.darkened(0.4))
	for k in 3:
		var x := -bw * 0.5 + 1.5 + k * 2.0 if k < 2 else bw * 0.3
		mb.box(Vector3(x, 1.8, fz - 0.05), Vector3(1.2, 1.0, 0.08), Color(0.12, 0.1, 0.1))
		mb.box(Vector3(x, 1.8, fz - 0.1), Vector3(0.7, 0.45, 0.03), MeshBuilder.glow(NEONS[(k + rng.randi()) % NEONS.size()], MeshBuilder.GLOW_NEON))
	# Roof sign: a board edged in neon with a star.
	var sc := Vector3(bw * 0.12, H + 1.9, fz + 0.9)
	mb.box(sc, Vector3(bw * 0.5, 1.8, 0.2), Color(0.12, 0.12, 0.14))
	var neon := MeshBuilder.glow(_pick(NEONS, rng), MeshBuilder.GLOW_NEON)
	for s: float in [-1.0, 1.0]:
		mb.box(sc + Vector3(0, s * 0.8, -0.12), Vector3(bw * 0.5, 0.1, 0.04), neon)
		mb.box(sc + Vector3(s * bw * 0.25, 0, -0.12), Vector3(0.1, 1.7, 0.04), neon)
	# A four-point star at the left of the board.
	var star := sc + Vector3(-bw * 0.13, 0, -0.14)
	for k in 4:
		var a := PI * 0.25 * k
		var r := 0.55 if k % 2 == 0 else 0.3
		var dir := Vector3(cos(a), sin(a), 0) * r
		_beam(mb, star - dir, star + dir, 0.12, MeshBuilder.glow(YELLOW, MeshBuilder.GLOW_NEON), 0.03)
	for k in 4:
		mb.box(sc + Vector3(0.2 + k * 0.5, 0, -0.13), Vector3(0.35, 0.8, 0.03), MeshBuilder.glow(Color(1.0, 0.95, 0.85), MeshBuilder.GLOW_NEON))
	for s: float in [-1.0, 1.0]:
		mb.box(sc + Vector3(s * bw * 0.2, -1.2, 0.2), Vector3(0.1, 1.0, 0.1), DARK)
	# Bikes by the porch, a pickup, picnic tables.
	for k in 3:
		_motorbike(mb, out, Vector3(-bw * 0.5 + 1.0 + k * 1.1, 0, fz - 3.6), 0.25, _pick(PAINTS, rng))
	if fz + d * 0.5 > 9.0:
		_pickup(mb, out, Vector3(bw * 0.3, 0, fz - 6.0), 0.1, _pick(PAINTS, rng))
	var tx := bw * 0.5 + (w * 0.5 - bw * 0.5) * 0.5
	if w * 0.5 - bw * 0.5 > 2.4:
		for k in 2:
			var p := Vector3(tx, 0, cz - bd * 0.25 + k * 2.6)
			mb.box(p + Vector3(0, 0.75, 0), Vector3(0.8, 0.08, 1.8), WOOD)
			for s: float in [-1.0, 1.0]:
				mb.box(p + Vector3(s * 0.65, 0.45, 0), Vector3(0.3, 0.06, 1.8), WOOD)
			_col(out, p + Vector3(0, 0.4, 0), Vector3(1.6, 0.8, 1.8))


static func _motorbike(mb, out: Array, p: Vector3, yaw: float, color: Color) -> void:
	var saved: Transform3D = mb.xform
	mb.xform = saved * Transform3D(Basis(Vector3.UP, yaw), p)
	for z: float in [-0.7, 0.7]:
		_wheel(mb, Vector3(0, 0.33, z), 0.33, 0.12)
	mb.box(Vector3(0, 0.75, 0), Vector3(0.3, 0.35, 1.0), MeshBuilder.glow(color, MeshBuilder.GLOSS))
	mb.box(Vector3(0, 0.85, 0.4), Vector3(0.28, 0.12, 0.6), DARK)
	mb.box(Vector3(0, 1.1, -0.6), Vector3(0.8, 0.05, 0.05), MeshBuilder.glow(STEEL, MeshBuilder.METAL))
	mb.xform = saved
	_col(out, p + Vector3(0, 0.55, 0), Vector3(0.6, 1.1, 1.8), yaw)


## Main-street shop: two floors on the property line, a display front with
## a striped awning over the sidewalk strip, a sign band and a cornice.
static func shopfront(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var fz := -d * 0.5 + 1.6
	var bd := d - 2.2
	var cz := fz + bd * 0.5
	var bw := w - 0.2
	const H := 7.6
	var paint: Color = _pick(PASTELS, rng)
	var body := MeshBuilder.glow(paint, MeshBuilder.SIDING) if rng.randf() < 0.3 else paint
	if rng.randf() < 0.5:
		body = MeshBuilder.glow(_pick(BRICKS, rng), MeshBuilder.BRICK)
	var trim := TRIM.darkened(0.08)
	_solid(mb, out, Vector3(0, H * 0.5, cz), Vector3(bw, H, bd), body)
	mb.box(Vector3(0, H - 0.2, fz + 0.1), Vector3(bw + 0.1, 0.5, 0.5), trim)
	for k in maxi(2, int(bw / 1.5)):
		mb.box(Vector3(-bw * 0.5 + 0.4 + k * (bw - 0.8) / maxf(1.0, int(bw / 1.5) - 1), H - 0.6, fz - 0.08), Vector3(0.18, 0.35, 0.2), trim)
	var front := fz - 0.04
	var frame := MeshBuilder.glow(DARK.lightened(0.1), MeshBuilder.GLOSS)
	mb.box(Vector3(0, 1.6, front + 0.02), Vector3(bw - 0.4, 3.2, 0.06), frame)
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(s * (bw * 0.25 + 0.35), 1.55, front - 0.02), Vector3(bw * 0.5 - 1.6, 1.9, 0.06), MeshBuilder.glow(SHOP_GLASS, MeshBuilder.GLOW_WINDOW))
	mb.box(Vector3(0, 1.25, front - 0.02), Vector3(1.1, 2.4, 0.06), MeshBuilder.glow(PANE, MeshBuilder.GLASS))
	var sign: Color = _pick(ACCENTS, rng)
	mb.box(Vector3(0, 3.0, front - 0.08), Vector3(bw - 0.6, 0.5, 0.12), sign.darkened(0.3))
	for k in int((bw - 1.6) / 0.7):
		mb.box(Vector3(-bw * 0.5 + 1.1 + k * 0.7, 3.0, front - 0.15), Vector3(0.45, 0.3, 0.04), MeshBuilder.glow(Color(0.98, 0.95, 0.85), MeshBuilder.GLOW_NEON))
	var awning: Color = _pick(Buildings.AWNINGS, rng)
	var stripes := maxi(4, int(bw / 0.6))
	for i in stripes:
		var x := -bw * 0.5 + (i + 0.5) * bw / stripes
		var a := Vector3(x, 2.75, front)
		_beam(mb, a, Vector3(x, 2.35, -d * 0.5 + 0.3), 0.05, awning if i % 2 == 0 else Color(0.95, 0.93, 0.88), bw / stripes)
	var bays := maxi(2, int(bw / 2.6))
	for b in bays:
		var x := -bw * 0.5 + bw / bays * (b + 0.5)
		mb.box(Vector3(x, 5.3, front), Vector3(minf(1.1, bw / bays * 0.55), 1.8, 0.08), Buildings._window(rng))
		mb.box(Vector3(x, 6.35, front - 0.06), Vector3(minf(1.4, bw / bays * 0.7), 0.25, 0.14), trim)
		mb.box(Vector3(x, 4.35, front - 0.08), Vector3(minf(1.3, bw / bays * 0.65), 0.08, 0.2), trim)
	_flat_roof(mb, 0, cz, bw, bd, H, rng, (paint.darkened(0.2) if body.a == 1.0 else trim))


## Gulf ranch house: one pastel storey under a broad hip roof, a garage at
## one side with its driveway, shuttered windows, foundation shrubs, a palm
## or crepe myrtle, and out back a screened pool cage or a patio.
static func house(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var bw := clampf(w * 0.55, 5.8, 13.0)
	var gw := clampf(w * 0.24, 3.0, 4.2)
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	var total := bw + gw
	var fz := -d * 0.5 + clampf(d * 0.3, 4.5, 8.0)
	var bd := clampf(d * 0.4, 6.5, 11.0)
	var cz := fz + bd * 0.5
	var mx := -side * gw * 0.5
	var gx := side * (total * 0.5 - gw * 0.5)
	const H := 3.0
	var paint: Color = _pick(PASTELS, rng)
	var trim := WHITE
	var shutter := Color(0, 0, 0, 0)
	if rng.randf() < 0.55:
		shutter = (_pick(ACCENTS, rng) as Color).darkened(0.1)
	var body: Color = paint if rng.randf() < 0.7 else MeshBuilder.glow(paint, MeshBuilder.SIDING)
	_pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, MeshBuilder.glow(LAWN, MeshBuilder.GRASS))
	mb.box(Vector3(0, 0.1, cz), Vector3(total + 0.1, 0.2, bd + 0.1), MeshBuilder.glow(CONCRETE, MeshBuilder.CONCRETE))
	mb.box(Vector3(mx, H * 0.5 + 0.1, cz), Vector3(bw, H - 0.2, bd), body)
	mb.box(Vector3(gx, H * 0.5 + 0.1, cz), Vector3(gw, H - 0.2, bd), body)
	_col(out, Vector3(0, H * 0.5, cz), Vector3(total, H, bd))
	var roof_roll := rng.randf()
	var roof: Color
	if roof_roll < 0.35:
		roof = MeshBuilder.glow(TERRACOTTA.lerp(Color(0.8, 0.55, 0.4), rng.randf() * 0.5), MeshBuilder.SEAM_ROOF)
	elif roof_roll < 0.55:
		roof = MeshBuilder.glow(Color(0.88, 0.88, 0.86), MeshBuilder.SEAM_ROOF)
	else:
		roof = _pick(SHINGLES, rng)
	var rise := clampf(minf(total, bd) * 0.22, 1.3, 2.4)
	_hip(mb, Vector3(0, H, cz), total + 1.0, bd + 1.0, rise, roof)
	mb.box(Vector3(0, H - 0.05, cz), Vector3(total + 1.0, 0.15, bd + 1.0), trim)
	# Garage door, front door, windows.
	var front := fz - 0.04
	mb.box(Vector3(gx, 1.25, front), Vector3(gw - 0.7, 2.3, 0.08), MeshBuilder.glow(WHITE, MeshBuilder.SIDING))
	var dx := mx + side * bw * 0.22
	mb.box(Vector3(dx, 1.2, front), Vector3(1.0, 2.1, 0.08), _pick(ACCENTS, rng))
	mb.box(Vector3(dx, 2.4, front - 0.06), Vector3(1.4, 0.12, 0.3), trim)
	var wx0 := mx - bw * 0.5
	var wx1 := dx - side * 0.8
	_windows(mb, Vector3(minf(wx0, wx1), 1.6, fz), Vector3(maxf(wx0, wx1), 1.6, fz), maxi(1, int(absf(wx1 - wx0) / 2.4)), Vector2(1.2, 1.3), rng, Vector3.FORWARD, 0.5, shutter)
	_all_windows(mb, mx - bw * 0.5, mx + bw * 0.5, fz, fz + bd, 0.2, 1, H, 3.2, Vector2(1.1, 1.2), rng, 0.5)
	mb.box(Vector3(-side * (total * 0.5 + 0.35), 0.35, cz + bd * 0.2), Vector3(0.6, 0.6, 0.8), MeshBuilder.glow(Color(0.8, 0.82, 0.84), MeshBuilder.METAL))
	# Driveway and path.
	var drive := MeshBuilder.glow(CONCRETE.lightened(0.05), MeshBuilder.CONCRETE)
	_pad(mb, gx - gw * 0.5 + 0.2, gx + gw * 0.5 - 0.2, -d * 0.5, fz, drive, 0.04)
	_pad(mb, dx - 0.6, dx + 0.6, fz - 2.0, fz, drive, 0.04)
	_pad(mb, minf(dx, gx), maxf(dx, gx), fz - 2.0, fz - 0.8, drive, 0.04)
	for k in 3:
		var x := lerpf(mx - bw * 0.5 + 0.6, dx - side * 1.0, k / 2.0)
		_bush(mb, Vector3(x, 0, fz - 0.6), 0.55, rng)
	_rural_mailbox(mb, Vector3(gx - side * (gw * 0.5 + 0.4), 0, -d * 0.5 + 0.5))
	if rng.randf() < 0.5:
		Props.palm(mb, out, Vector3(-side * (w * 0.5 - 3.0), 0, -d * 0.5 + 2.6), rng)
	else:
		Props.crepe_myrtle(mb, out, Vector3(-side * (w * 0.5 - 2.0), 0, -d * 0.5 + 2.2), rng)
	if rng.randf() < 0.6:
		_car(mb, out, Vector3(gx, 0, fz - 3.2), 0.0, _pick(PAINTS, rng))
	# Back: a screened pool cage or a patio.
	var back := fz + bd
	var room := d * 0.5 - back
	if room >= 6.0 and rng.randf() < 0.45:
		var px0 := mx - minf(bw, 9.0) * 0.5
		var px1 := mx + minf(bw, 9.0) * 0.5
		var pz0 := back
		var pz1 := back + minf(7.0, room - 1.0)
		_pad(mb, px0, px1, pz0, pz1, MeshBuilder.glow(Color(0.88, 0.84, 0.76), MeshBuilder.PAVING), 0.05)
		mb.box(Vector3((px0 + px1) * 0.5, 0.07, (pz0 + pz1) * 0.5 + 0.4), Vector3(px1 - px0 - 2.6, 0.04, pz1 - pz0 - 2.4), POOL)
		var frame := MeshBuilder.glow(Color(0.3, 0.26, 0.22), MeshBuilder.GLOSS)
		const CH := 3.4
		var nx := maxi(2, int((px1 - px0) / 2.0))
		for i in nx + 1:
			var x := lerpf(px0 + 0.05, px1 - 0.05, float(i) / nx)
			mb.box(Vector3(x, CH * 0.5, pz1 - 0.05), Vector3(0.08, CH, 0.08), frame)
			_beam(mb, Vector3(x, CH, pz0), Vector3(x, CH + 0.8, (pz0 + pz1) * 0.5), 0.07, frame)
			_beam(mb, Vector3(x, CH + 0.8, (pz0 + pz1) * 0.5), Vector3(x, CH, pz1), 0.07, frame)
		var nz := maxi(2, int((pz1 - pz0) / 2.0))
		for k in nz + 1:
			var z := lerpf(pz0 + 0.05, pz1 - 0.05, float(k) / nz)
			for x: float in [px0 + 0.05, px1 - 0.05]:
				mb.box(Vector3(x, CH * 0.5, z), Vector3(0.08, CH, 0.08), frame)
		for z: float in [pz0 + 0.05, pz1 - 0.05]:
			mb.box(Vector3((px0 + px1) * 0.5, CH, z), Vector3(px1 - px0, 0.08, 0.08), frame)
		for x: float in [px0 + 0.05, px1 - 0.05]:
			mb.box(Vector3(x, CH, (pz0 + pz1) * 0.5), Vector3(0.08, 0.08, pz1 - pz0), frame)
		mb.box(Vector3((px0 + px1) * 0.5, CH + 0.8, (pz0 + pz1) * 0.5), Vector3(px1 - px0, 0.08, 0.08), frame)
		_col(out, Vector3((px0 + px1) * 0.5, CH * 0.5, (pz0 + pz1) * 0.5), Vector3(px1 - px0, CH, pz1 - pz0))
	elif room >= 3.5:
		_pad(mb, mx - 2.5, mx + 2.5, back, back + 3.0, MeshBuilder.glow(Color(0.82, 0.78, 0.7), MeshBuilder.PAVING), 0.05)
		Props.cafe_table(mb, out, Vector3(mx, 0, back + 1.6), _pick(Buildings.PARASOLS, rng))


## Magnolia Heights mansion: a white Greek Revival house with a two-storey
## columned portico and pediment, wings, chimneys, a gravel loop round a
## fountain, gate piers in a street hedge, oaks, a pool and a carriage house.
static func mansion(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var bw := clampf(w * 0.46, 16.0, 32.0)
	var bd := clampf(d * 0.26, 10.0, 18.0)
	var fz := -d * 0.5 + clampf(d * 0.42, 13.0, 26.0)
	var cz := fz + bd * 0.5
	const H := 8.4
	var paint: Color = [WHITE, Color(0.97, 0.94, 0.85), Color(0.96, 0.92, 0.78), Color(0.92, 0.88, 0.84)][rng.randi() % 4]
	var slate: Color = [Color(0.28, 0.3, 0.34), Color(0.35, 0.33, 0.32), Color(0.3, 0.38, 0.36)][rng.randi() % 3]
	var shutter := Color(0.12, 0.25, 0.18)
	_pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, MeshBuilder.glow(LAWN.lightened(0.05), MeshBuilder.GRASS))
	_solid(mb, out, Vector3(0, H * 0.5, cz), Vector3(bw, H, bd), paint)
	mb.box(Vector3(0, H + 0.18, cz), Vector3(bw + 0.6, 0.36, bd + 0.6), TRIM)
	var rise := clampf(bd * 0.3, 3.0, 5.0)
	_hip(mb, Vector3(0, H + 0.36, cz), bw + 1.0, bd + 1.0, rise, slate)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-0.25, 0.25]:
			mb.box(Vector3(sx * (bw * 0.5 - 1.6), H + rise * 0.6, cz + sz * bd), Vector3(1.0, rise * 1.2 + 1.0, 0.7), MeshBuilder.glow(BRICKS[1], MeshBuilder.BRICK))
	var ww := bw * 0.3
	var wd := bd * 0.72
	for s: float in [-1.0, 1.0]:
		var wx := s * (bw * 0.5 + ww * 0.5)
		var wz := cz + bd * 0.12
		_solid(mb, out, Vector3(wx, 2.6, wz), Vector3(ww, 5.2, wd), paint.darkened(0.03))
		mb.box(Vector3(wx, 5.3, wz), Vector3(ww + 0.4, 0.25, wd + 0.4), TRIM)
		_hip(mb, Vector3(wx, 5.4, wz), ww + 0.6, wd + 0.6, 1.8, slate)
		_windows(mb, Vector3(wx - ww * 0.5, 2.4, wz - wd * 0.5), Vector3(wx + ww * 0.5, 2.4, wz - wd * 0.5), maxi(1, int(ww / 2.4)), Vector2(1.1, 2.2), rng, Vector3.FORWARD, 0.5, shutter)
	for f in 2:
		var y := 0.6 + f * 4.0 + 1.6
		_windows(mb, Vector3(-bw * 0.5, y, fz), Vector3(bw * 0.5, y, fz), maxi(4, int(bw / 2.6)), Vector2(1.1, 2.3), rng, Vector3.FORWARD, 0.5, shutter)
	_all_windows(mb, -bw * 0.5, bw * 0.5, fz, fz + bd, 0.6, 2, 4.0, 3.0, Vector2(1.1, 2.2), rng, 0.5)
	# Portico.
	var pw := bw * 0.55
	var pd := 3.6
	var pz := fz - pd * 0.5
	mb.box(Vector3(0, 0.4, pz - 0.2), Vector3(pw + 1.0, 0.8, pd + 0.6), MeshBuilder.glow(WHITE, MeshBuilder.CONCRETE))
	mb.box(Vector3(0, 0.2, pz - pd * 0.5 - 0.7), Vector3(pw * 0.5, 0.4, 0.8), MeshBuilder.glow(WHITE, MeshBuilder.CONCRETE))
	for i in 6:
		var x := -pw * 0.5 + 0.5 + i * (pw - 1.0) / 5.0
		mb.cylinder(Vector3(x, 0.8, fz - pd + 0.6), 0.45, H - 1.6, TRIM, 8)
		_col(out, Vector3(x, H * 0.5, fz - pd + 0.6), Vector3(0.9, H, 0.9))
	mb.box(Vector3(0, H - 0.3, pz), Vector3(pw + 0.6, 1.0, pd + 0.2), TRIM)
	_gable(mb, 0, pz, H + 0.2, pw + 0.8, pd + 0.6, 2.4, slate, TRIM, true)
	mb.box(Vector3(0, 4.3, fz - 0.8), Vector3(pw - 1.2, 0.2, 1.6), TRIM)
	mb.box(Vector3(0, 5.3, fz - 1.55), Vector3(pw - 1.2, 0.08, 0.08), Buildings.IRON)
	mb.box(Vector3(0, 1.9, fz - 0.05), Vector3(1.8, 3.0, 0.1), Color(0.15, 0.2, 0.18))
	mb.box(Vector3(0, 3.7, fz - 0.05), Vector3(2.2, 0.6, 0.1), MeshBuilder.glow(PANE, MeshBuilder.GLASS))
	# Gravel loop round a fountain, a drive to the street, gate piers.
	var gravel := MeshBuilder.glow(GRAVEL.lightened(0.1), MeshBuilder.CONCRETE)
	var r := clampf(minf(w * 0.14, (fz - pd + d * 0.5 - 6.0) * 0.5), 3.5, 8.0)
	var rc := Vector3(0, 0.04, fz - pd - 1.2 - r)
	for i in 16:
		var a0 := TAU * i / 16.0
		var a1 := TAU * (i + 1) / 16.0
		var i0 := rc + Vector3(cos(a0), 0, sin(a0)) * (r - 1.6)
		var o0 := rc + Vector3(cos(a0), 0, sin(a0)) * (r + 1.6)
		var i1 := rc + Vector3(cos(a1), 0, sin(a1)) * (r - 1.6)
		var o1 := rc + Vector3(cos(a1), 0, sin(a1)) * (r + 1.6)
		mb.quad(i0, o0, o1, i1, Vector3.UP, gravel)
	_pad(mb, -1.6, 1.6, -d * 0.5, rc.z - r, gravel, 0.04)
	var fr := minf(2.2, r - 2.0)
	mb.cylinder(rc, fr, 0.6, MeshBuilder.glow(CONCRETE.lightened(0.15), MeshBuilder.CONCRETE), 10)
	mb.cylinder(rc + Vector3(0, 0.6, 0), fr - 0.25, 0.01, POOL, 10)
	mb.cylinder(rc, 0.3, 1.8, MeshBuilder.glow(CONCRETE.lightened(0.15), MeshBuilder.CONCRETE), 6)
	mb.cylinder(rc + Vector3(0, 1.8, 0), 0.8, 0.15, MeshBuilder.glow(CONCRETE.lightened(0.15), MeshBuilder.CONCRETE), 8)
	_col(out, rc + Vector3(0, 0.5, 0), Vector3(fr * 1.6, 1.0, fr * 1.6))
	for s: float in [-1.0, 1.0]:
		_solid(mb, out, Vector3(s * 2.3, 1.1, -d * 0.5 + 0.7), Vector3(0.9, 2.2, 0.9), MeshBuilder.glow(BRICKS[0], MeshBuilder.BRICK))
		mb.ball(Vector3(s * 2.3, 2.5, -d * 0.5 + 0.7), Vector3(0.3, 0.3, 0.3), MeshBuilder.glow(Color(1.0, 0.9, 0.6), MeshBuilder.GLOW_LAMP), 6, 3)
		_hedge(mb, out, Vector3(s * 3.2, 0, -d * 0.5 + 0.7), Vector3(s * (w * 0.5 - 0.6), 0, -d * 0.5 + 0.7), 1.3)
	# Oaks on the lawn.
	for s: float in [-1.0, 1.0]:
		var ox := s * (w * 0.5 - 5.0)
		if absf(ox) > r + 5.0:
			Props.oak(mb, out, Vector3(ox, 0, rc.z), rng)
	# Pool and terrace out back; a carriage house in a back corner.
	var back := fz + bd
	var room := d * 0.5 - back
	if room > 7.0:
		var pz0 := back + 2.0
		var pz1 := minf(back + 9.0, d * 0.5 - 1.0)
		_pad(mb, -6.0, 6.0, back, pz1, MeshBuilder.glow(Color(0.86, 0.82, 0.74), MeshBuilder.PAVING), 0.05)
		mb.box(Vector3(0, 0.07, (pz0 + pz1) * 0.5), Vector3(8.0, 0.04, pz1 - pz0 - 1.2), POOL)
		for k in 3:
			mb.box(Vector3(-5.2, 0.3, pz0 + 0.8 + k * 1.4), Vector3(1.6, 0.15, 0.6), WHITE)
	if room > 8.0 and w * 0.5 - (bw * 0.5 + ww) > -2.0:
		var cx := w * 0.5 - 5.5
		var ccz := d * 0.5 - 4.0
		_solid(mb, out, Vector3(cx, 2.0, ccz), Vector3(8.0, 4.0, 6.0), paint)
		_hip(mb, Vector3(cx, 4.0, ccz), 8.6, 6.6, 1.8, slate)
		for k in 2:
			mb.box(Vector3(cx - 1.9 + k * 3.8, 1.3, ccz - 3.04), Vector3(2.8, 2.5, 0.08), MeshBuilder.glow(Color(0.2, 0.3, 0.25), MeshBuilder.SIDING))


## Garden apartments: a long two- or three-storey walk-up with an outside
## walkway on every floor, two stair towers, a hip roof and front parking.
static func garden_apartments(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var floors := 2 if rng.randf() < 0.5 else 3
	const FH := 3.0
	var H := floors * FH
	var bl := w - 6.0
	var bd := clampf(d * 0.3, 7.5, 11.0)
	var cz := d * 0.5 - 2.0 - bd * 0.5
	var fz := cz - bd * 0.5
	var paint: Color = _pick(PASTELS, rng)
	var accent: Color = _pick(ACCENTS, rng)
	var roof: Color = _pick(SHINGLES, rng) if rng.randf() < 0.6 else MeshBuilder.glow(TERRACOTTA, MeshBuilder.SEAM_ROOF)
	_pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, MeshBuilder.glow(LAWN, MeshBuilder.GRASS))
	_solid(mb, out, Vector3(0, H * 0.5, cz), Vector3(bl, H, bd), paint)
	_hip(mb, Vector3(0, H, cz - 0.9), bl + 0.8, bd + 2.6, 2.2, roof)
	var units := maxi(2, int(bl / 7.0))
	var uw := bl / units
	var rail := MeshBuilder.glow(WHITE, MeshBuilder.GLOSS)
	var deck := MeshBuilder.glow(CONCRETE, MeshBuilder.CONCRETE)
	for f in floors:
		var y := f * FH
		for u in units:
			var x := -bl * 0.5 + uw * (u + 0.5)
			mb.box(Vector3(x - uw * 0.25, y + 1.05, fz - 0.04), Vector3(0.9, 2.1, 0.08), accent)
			_windows(mb, Vector3(x, y + 1.6, fz), Vector3(x + uw * 0.5, y + 1.6, fz), 1, Vector2(1.4, 1.2), rng, Vector3.FORWARD, 0.5)
			_windows(mb, Vector3(x - uw * 0.5, y + 1.6, fz + bd), Vector3(x + uw * 0.5, y + 1.6, fz + bd), 2, Vector2(1.3, 1.2), rng, Vector3.BACK, 0.5)
		if f > 0:
			mb.box(Vector3(0, y, fz - 0.8), Vector3(bl, 0.2, 1.6), deck)
			mb.box(Vector3(0, y + 1.0, fz - 1.55), Vector3(bl, 0.08, 0.08), rail)
			mb.box(Vector3(0, y + 0.5, fz - 1.55), Vector3(bl, 0.04, 0.04), rail)
	_all_windows(mb, -bl * 0.5, bl * 0.5, fz, fz + bd, 0.0, floors, FH, 3.5, Vector2(1.0, 1.1), rng, 0.5, false)
	for i in units + 1:
		_post(mb, out, Vector3(-bl * 0.5 + 0.1 + (bl - 0.2) * i / units, 0, fz - 1.5), H, 0.2, rail)
	# Stair towers in front of the walkway.
	for s: float in [-1.0, 1.0]:
		var sx := s * bl * 0.3
		var sz := fz - 1.6 - 1.3
		_solid(mb, out, Vector3(sx, H * 0.5, sz), Vector3(2.8, H, 2.4), paint.darkened(0.08))
		mb.box(Vector3(sx, H + 0.1, sz), Vector3(3.0, 0.2, 2.6), accent)
		for f in floors:
			mb.box(Vector3(sx, f * FH + 1.6, sz - 1.22), Vector3(1.6, 1.8, 0.06), MeshBuilder.glow(PANE, MeshBuilder.GLASS))
	# Parking row in front, a dumpster pen, trees at the ends.
	_pad(mb, -w * 0.5 + 1.0, w * 0.5 - 1.0, -d * 0.5, fz - 4.4, MeshBuilder.glow(ASPHALT, MeshBuilder.ASPHALT), 0.04)
	var n := int((w - 4.0) / 2.7)
	_stalls(mb, -n * 1.35, fz - 4.6, n, 2.7, 5.5, -1.0)
	_solid(mb, out, Vector3(w * 0.5 - 2.0, 0.9, d * 0.5 - 1.6), Vector3(3.0, 1.8, 2.0), MeshBuilder.glow(CONCRETE, MeshBuilder.CONCRETE))
	for s: float in [-1.0, 1.0]:
		Props.crepe_myrtle(mb, out, Vector3(s * (w * 0.5 - 1.6), 0, cz), rng)


## Strip mall: a row of shop units under one parapet with a feature tower,
## a covered walk on posts, tenant signs, and a parking lot with a pylon.
static func strip_mall(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var bl := w - 4.0
	var bd := clampf(d * 0.32, 9.0, 18.0)
	var cz := d * 0.5 - 1.0 - bd * 0.5
	var fz := cz - bd * 0.5
	const H := 5.0
	var paint: Color = [Color(0.92, 0.86, 0.74), Color(0.88, 0.88, 0.84), Color(0.95, 0.82, 0.7), Color(0.84, 0.88, 0.82)][rng.randi() % 4]
	var accent: Color = _pick(ACCENTS, rng)
	_pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, MeshBuilder.glow(ASPHALT, MeshBuilder.ASPHALT))
	_pad(mb, -bl * 0.5, bl * 0.5, fz - 3.2, fz, MeshBuilder.glow(CONCRETE, MeshBuilder.CONCRETE), 0.05)
	_solid(mb, out, Vector3(0, H * 0.5, cz), Vector3(bl, H, bd), paint)
	_flat_roof(mb, 0, cz, bl, bd, H, rng, paint.darkened(0.2), true)
	mb.box(Vector3(0, H + 0.6, fz + 0.2), Vector3(bl, 1.6, 0.4), paint.darkened(0.04))
	var n := clampi(int(bl / 9.0), 3, 8)
	var uw := bl / n
	var front := fz - 0.04
	for i in n:
		var x := -bl * 0.5 + uw * (i + 0.5)
		mb.box(Vector3(x, 1.5, front), Vector3(uw * 0.72, 2.6, 0.08), MeshBuilder.glow(SHOP_GLASS, MeshBuilder.GLOW_WINDOW))
		mb.box(Vector3(x, 1.2, front - 0.02), Vector3(0.06, 2.4, 0.06), DARK)
		var sign: Color = NEONS[(i + rng.randi()) % NEONS.size()]
		mb.box(Vector3(x, H + 0.6, fz - 0.04), Vector3(uw * 0.6, 0.9, 0.1), sign.darkened(0.55))
		for k in 4:
			mb.box(Vector3(x - uw * 0.21 + k * uw * 0.14, H + 0.6, fz - 0.1), Vector3(uw * 0.1, 0.5, 0.03), MeshBuilder.glow(sign, MeshBuilder.GLOW_NEON))
	# Feature tower in the middle.
	mb.box(Vector3(0, H + 1.6, fz + 0.6), Vector3(uw * 1.1, 3.2, 1.2), accent)
	_hip(mb, Vector3(0, H + 3.2, fz + 0.6), uw * 1.1 + 0.6, 1.8, 1.0, MeshBuilder.glow(TERRACOTTA, MeshBuilder.SEAM_ROOF))
	# Covered walk.
	var posts: Array = []
	for i in n + 1:
		posts.append(Vector3(-bl * 0.5 + 0.2 + (bl - 0.4) * i / n, 0, fz - 2.9))
	_canopy(mb, out, -bl * 0.5, bl * 0.5, fz - 3.2, fz, 3.8, 0.5, accent.lightened(0.2), MeshBuilder.glow(Buildings.MEMBRANES[0], MeshBuilder.ROOF), posts, WHITE)
	# Parking rows.
	var zc := fz - 3.2
	var stalls := int((w - 6.0) / 2.7)
	var x0 := -stalls * 1.35
	_stalls(mb, x0, zc, stalls, 2.7, 5.5, -1.0)
	var zr := zc - 12.5
	if zr - 11.0 > -d * 0.5 + 6.0:
		_stalls(mb, x0, zr, stalls, 2.7, 5.5, 1.0)
		_stalls(mb, x0, zr, stalls, 2.7, 5.5, -1.0)
		for s: float in [-1.0, 1.0]:
			_pad(mb, s * (stalls * 1.35 + 0.2) - 1.2, s * (stalls * 1.35 + 0.2) + 1.2, zr - 5.5, zr + 5.5, MeshBuilder.glow(LAWN, MeshBuilder.GRASS), 0.06)
			Props.crepe_myrtle(mb, out, Vector3(s * (stalls * 1.35 + 0.2), 0, zr), rng)
	# Pylon with stacked tenant panels.
	var pp := Vector3(w * 0.5 - 2.0, 0, -d * 0.5 + 2.0)
	_post(mb, out, pp, 6.0, 0.5, paint.darkened(0.3))
	for k in 3:
		var c := pp + Vector3(0, 4.0 + k * 1.3, 0)
		mb.box(c, Vector3(3.0, 1.1, 0.5), Color(0.15, 0.15, 0.18))
		mb.box(c + Vector3(0, 0, -0.27), Vector3(2.7, 0.8, 0.04), MeshBuilder.glow(NEONS[(k + 1) % NEONS.size()], MeshBuilder.GLOW_NEON))
	mb.box(pp + Vector3(0, 8.2, 0), Vector3(3.4, 0.9, 0.7), accent)


## State police post: a low brick building with a blue band, a glazed
## entrance under a canopy, a radio mast, a flagpole and cruisers parked out
## front in marked bays.
static func police_station(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var bw := clampf(w * 0.65, 11.0, 22.0)
	var bd := clampf(d * 0.38, 7.0, 13.0)
	var fz := -d * 0.5 + clampf(d * 0.36, 7.5, 12.0)
	var cz := fz + bd * 0.5
	const H := 4.4
	var blue := Color(0.15, 0.25, 0.55)
	_pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, MeshBuilder.glow(LAWN, MeshBuilder.GRASS))
	_pad(mb, -w * 0.5 + 1.0, w * 0.5 - 1.0, -d * 0.5, fz - 1.2, MeshBuilder.glow(ASPHALT, MeshBuilder.ASPHALT), 0.04)
	_pad(mb, -bw * 0.5, bw * 0.5, fz - 1.2, fz, MeshBuilder.glow(CONCRETE, MeshBuilder.CONCRETE), 0.05)
	_solid(mb, out, Vector3(0, H * 0.5, cz), Vector3(bw, H, bd), MeshBuilder.glow(_pick(BRICKS, rng), MeshBuilder.BRICK))
	mb.box(Vector3(0, H - 0.5, fz - 0.05), Vector3(bw, 0.6, 0.1), blue)
	_flat_roof(mb, 0, cz, bw, bd, H, rng, Color(0.75, 0.74, 0.7), true)
	_windows(mb, Vector3(-bw * 0.5, 2.0, fz), Vector3(-1.8, 2.0, fz), maxi(1, int((bw * 0.5 - 1.8) / 2.0)), Vector2(1.2, 1.0), rng, Vector3.FORWARD, 0.5)
	_windows(mb, Vector3(1.8, 2.0, fz), Vector3(bw * 0.5, 2.0, fz), maxi(1, int((bw * 0.5 - 1.8) / 2.0)), Vector2(1.2, 1.0), rng, Vector3.FORWARD, 0.5)
	_all_windows(mb, -bw * 0.5, bw * 0.5, fz, fz + bd, 0.0, 1, 3.6, 3.0, Vector2(1.2, 0.9), rng, 0.4)
	mb.box(Vector3(0, 1.4, fz - 0.06), Vector3(2.4, 2.8, 0.08), MeshBuilder.glow(Color(0.3, 0.4, 0.5), MeshBuilder.GLOW_WINDOW))
	_canopy(mb, out, -2.0, 2.0, fz - 2.4, fz, 3.4, 0.3, blue, blue.lightened(0.2), [Vector3(-1.8, 0, fz - 2.2), Vector3(1.8, 0, fz - 2.2)], WHITE)
	mb.box(Vector3(0, 3.6, fz - 2.42), Vector3(2.4, 0.3, 0.04), MeshBuilder.glow(Color(0.35, 0.55, 1.0), MeshBuilder.GLOW_NEON))
	# Radio mast at the back corner.
	var mast := Vector3(bw * 0.5 - 1.0, H, cz + bd * 0.5 - 1.0)
	for k in 3:
		var a := TAU * k / 3.0
		_beam(mb, mast + Vector3(cos(a) * 0.4, 0, sin(a) * 0.4), mast + Vector3(cos(a) * 0.1, 9.0, sin(a) * 0.1), 0.06, Color(0.85, 0.3, 0.25))
	mb.box(mast + Vector3(0, 9.1, 0), Vector3(0.2, 0.2, 0.2), MeshBuilder.glow(Color(1.0, 0.15, 0.1), MeshBuilder.GLOW_NEON))
	_flagpole(mb, out, Vector3(-bw * 0.5 - 1.5 if w * 0.5 - bw * 0.5 > 2.0 else -bw * 0.5 + 1.0, 0, fz - 0.6), 7.5, [Color(0.15, 0.25, 0.55), GOLD])
	# Marked bays with cruisers.
	var nb := clampi(int((bw - 2.0) / 2.8), 2, 7)
	var x0 := -nb * 1.4
	_stalls(mb, x0, fz - 1.3, nb, 2.8, 5.5, -1.0)
	if fz - 1.3 - 5.5 > -d * 0.5 - 0.5:
		_cruiser(mb, out, Vector3(x0 + 1.4, 0, fz - 1.3 - 2.75), PI)
		if rng.randf() < 0.7:
			_cruiser(mb, out, Vector3(x0 + 1.4 + 2.8 * 2, 0, fz - 1.3 - 2.75), PI)


## County hospital: a white two-storey block with teal bands, a glazed
## entrance, an ambulance canopy at one end and a blue H sign.
static func county_hospital(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var bw := clampf(w * 0.68, 18.0, 34.0)
	var bd := clampf(d * 0.38, 10.0, 18.0)
	var fz := -d * 0.5 + clampf(d * 0.32, 9.0, 14.0)
	var cz := fz + bd * 0.5
	const H := 8.2
	var teal := Color(0.15, 0.55, 0.58)
	_pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, MeshBuilder.glow(LAWN, MeshBuilder.GRASS))
	_pad(mb, -w * 0.5 + 1.0, w * 0.5 - 1.0, -d * 0.5, fz, MeshBuilder.glow(ASPHALT, MeshBuilder.ASPHALT), 0.04)
	_solid(mb, out, Vector3(0, H * 0.5, cz), Vector3(bw, H, bd), MeshBuilder.glow(Color(0.93, 0.93, 0.91), MeshBuilder.CONCRETE))
	var glass := MeshBuilder.glow(Color(0.4, 0.55, 0.62), MeshBuilder.GLASS)
	for f in 2:
		var y := 0.4 + f * 3.9 + 1.7
		for z: float in [fz - 0.04, fz + bd + 0.04]:
			mb.box(Vector3(0, y, z), Vector3(bw - 1.0, 1.5, 0.08), glass)
		for x: float in [-bw * 0.5 - 0.04, bw * 0.5 + 0.04]:
			mb.box(Vector3(x, y, cz), Vector3(0.08, 1.5, bd - 1.0), glass)
	for k in int(bw / 4.0) + 1:
		mb.box(Vector3(-bw * 0.5 + 0.2 + k * (bw - 0.4) / int(bw / 4.0), H * 0.5, fz - 0.1), Vector3(0.3, H, 0.2), teal)
	_flat_roof(mb, 0, cz, bw, bd, H, rng, teal.darkened(0.2))
	# Main entrance.
	mb.box(Vector3(-bw * 0.15, 1.6, fz - 0.6), Vector3(5.0, 3.2, 1.2), MeshBuilder.glow(Color(0.35, 0.45, 0.52), MeshBuilder.GLOW_WINDOW))
	_canopy(mb, out, -bw * 0.15 - 3.5, -bw * 0.15 + 3.5, fz - 4.0, fz - 1.2, 3.8, 0.4, teal, MeshBuilder.glow(Buildings.MEMBRANES[0], MeshBuilder.ROOF), [Vector3(-bw * 0.15 - 3.2, 0, fz - 3.7), Vector3(-bw * 0.15 + 3.2, 0, fz - 3.7)], WHITE)
	# Ambulance canopy at the end, with a red band and an ambulance.
	var ax0 := bw * 0.5 - 8.0
	var ax1 := bw * 0.5
	_canopy(mb, out, ax0, ax1, fz - 7.0, fz, 4.6, 0.6, WHITE, MeshBuilder.glow(Buildings.MEMBRANES[1], MeshBuilder.ROOF), [Vector3(ax0 + 0.3, 0, fz - 6.7), Vector3(ax1 - 0.3, 0, fz - 6.7)], WHITE)
	mb.box(Vector3((ax0 + ax1) * 0.5, 4.3, fz - 7.04), Vector3(6.0, 0.35, 0.04), MeshBuilder.glow(Color(1.0, 0.2, 0.15), MeshBuilder.GLOW_NEON))
	_ambulance(mb, out, Vector3((ax0 + ax1) * 0.5 - 1.6, 0, fz - 3.6), 0.0)
	_h_sign(mb, out, Vector3(-w * 0.5 + 3.0, 0, -d * 0.5 + 1.5), 1.8)
	var n := clampi(int((bw * 0.5 - 4.0) / 2.7), 2, 10)
	var sd := minf(5.5, fz - 6.0 + d * 0.5 - 0.3)
	if sd > 3.5:
		_stalls(mb, -bw * 0.5, fz - 6.0, n, 2.7, sd, -1.0)


## Glades airboat rentals: a ticket hut by the lane, a boardwalk to a
## wooden dock out the back (+Z) with finger piers and moored airboats.
static func airboat_dock(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	_pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, MeshBuilder.glow(GRAVEL, MeshBuilder.CONCRETE))
	var dz0 := -d * 0.5 + d * 0.4
	_pad(mb, -w * 0.5 + 0.5, w * 0.5 - 0.5, dz0, d * 0.5, MeshBuilder.glow(SWAMP, MeshBuilder.GLASS), 0.04)
	# Ticket hut.
	var hx := -w * 0.5 + 3.2
	var hz := -d * 0.5 + 3.0
	var hut := MeshBuilder.glow(Color(0.55, 0.72, 0.6), MeshBuilder.SIDING)
	_solid(mb, out, Vector3(hx, 1.4, hz), Vector3(4.0, 2.8, 3.0), hut)
	_gable(mb, hx, hz, 2.8, 4.6, 3.6, 1.0, MeshBuilder.glow(TIN, MeshBuilder.SEAM_ROOF), hut)
	mb.box(Vector3(hx, 1.6, hz - 1.54), Vector3(1.6, 1.0, 0.08), MeshBuilder.glow(SHOP_GLASS, MeshBuilder.GLOW_WINDOW))
	_beam(mb, Vector3(hx - 1.4, 2.5, hz - 1.5), Vector3(hx - 1.4, 2.2, hz - 2.6), 0.06, MeshBuilder.glow(Color(0.95, 0.85, 0.3), MeshBuilder.GLOSS), 2.8)
	mb.box(Vector3(hx + 3.4, 2.2, hz - 1.0), Vector3(2.6, 1.3, 0.12), Color(0.95, 0.9, 0.75))
	mb.box(Vector3(hx + 3.4, 2.2, hz - 1.07), Vector3(2.0, 0.6, 0.03), Color(0.2, 0.45, 0.3))
	for s: float in [-1.0, 1.0]:
		_post(mb, out, Vector3(hx + 3.4 + s * 1.1, 0, hz - 1.0), 1.6, 0.14, WOOD)
	# Boardwalk and dock.
	var deck := MeshBuilder.glow(OLD_WOOD.lightened(0.15), MeshBuilder.SIDING)
	var pile := Color(0.3, 0.26, 0.22)
	mb.box(Vector3(0, 0.35, (hz + 1.5 + dz0) * 0.5), Vector3(2.0, 0.12, dz0 - hz - 1.5), deck)
	mb.box(Vector3(0, 0.35, dz0 + 1.5), Vector3(w - 2.0, 0.14, 3.0), deck)
	var fingers := 3 if w >= 20.0 else 2
	var fl := d * 0.5 - 0.3 - (dz0 + 3.0)
	for i in fingers:
		var x := -w * 0.5 + 1.8 + (w - 3.6) * i / (fingers - 1)
		mb.box(Vector3(x, 0.35, dz0 + 3.0 + fl * 0.5), Vector3(1.4, 0.12, fl), deck)
		for t: float in [0.0, 0.5, 1.0]:
			mb.cylinder(Vector3(x + 0.6, 0, dz0 + 3.1 + (fl - 0.2) * t), 0.12, 1.1, pile, 5)
	for x: float in [-w * 0.5 + 1.2, w * 0.5 - 1.2]:
		mb.cylinder(Vector3(x, 0, dz0 + 0.1), 0.12, 1.0, pile, 5)
	# Airboats between the fingers.
	var colors := [Color(0.25, 0.45, 0.3), Color(0.7, 0.72, 0.74), Color(0.55, 0.5, 0.35), Color(0.2, 0.3, 0.5)]
	var bay := (w - 3.6) / (fingers - 1)
	var per := clampi(int((bay - 1.4) / 3.2), 1, 2)
	var placed := 0
	for i in fingers - 1:
		var x := -w * 0.5 + 1.8 + bay * (i + 0.5)
		for k in per:
			if placed >= 3:
				break
			placed += 1
			var bx := x + (k - (per - 1) * 0.5) * 3.2
			_airboat(mb, out, Vector3(bx, 0.05, dz0 + 3.0 + fl * 0.5 + k * 0.8), 0.0, colors[(placed + rng.randi()) % colors.size()])
	# Life vests on a rack, a cooler, a gator warning sign.
	mb.box(Vector3(w * 0.5 - 2.0, 1.0, dz0 + 1.2), Vector3(1.8, 1.0, 0.2), MeshBuilder.glow(Color(1.0, 0.5, 0.1), MeshBuilder.GLOSS))
	mb.box(Vector3(w * 0.5 - 3.4, 0.7, dz0 + 1.0), Vector3(0.8, 0.5, 0.5), MeshBuilder.glow(WHITE, MeshBuilder.GLOSS))
	mb.box(Vector3(-w * 0.5 + 2.0, 1.4, dz0 - 0.4), Vector3(1.0, 1.0, 0.08), YELLOW)
	_post(mb, out, Vector3(-w * 0.5 + 2.0, 0, dz0 - 0.35), 1.0, 0.1, WOOD)


## An airboat: a flat aluminium hull, a raised driver's seat and a big
## caged propeller at the stern; bow toward -Z before yaw.
static func _airboat(mb, out: Array, p: Vector3, yaw: float, color: Color) -> void:
	var saved: Transform3D = mb.xform
	mb.xform = saved * Transform3D(Basis(Vector3.UP, yaw), p)
	var hull := PackedVector2Array([Vector2(-1.1, -2.6), Vector2(-0.8, -2.9), Vector2(0.8, -2.9), Vector2(1.1, -2.6), Vector2(1.1, 2.4), Vector2(-1.1, 2.4)])
	mb.prism(hull, 0.0, 0.45, MeshBuilder.glow(STEEL, MeshBuilder.METAL), MeshBuilder.glow(color, MeshBuilder.GLOSS))
	for k in 2:
		mb.box(Vector3(0, 0.75, -1.4 + k * 0.9), Vector3(1.6, 0.25, 0.5), Color(0.25, 0.3, 0.45))
	mb.box(Vector3(0, 1.3, 0.8), Vector3(0.7, 0.2, 0.6), Color(0.25, 0.3, 0.45))
	_beam(mb, Vector3(0, 0.45, 0.6), Vector3(0, 1.2, 0.8), 0.1, DARK)
	mb.box(Vector3(0, 0.9, 1.6), Vector3(0.7, 0.8, 0.8), DARK.lightened(0.2))
	var hub := Vector3(0, 1.6, 2.1)
	var ring := 1.05
	for i in 10:
		var a0 := TAU * i / 10.0
		var a1 := TAU * (i + 1) / 10.0
		_beam(mb, hub + Vector3(cos(a0), sin(a0), 0) * ring, hub + Vector3(cos(a1), sin(a1), 0) * ring, 0.05, MeshBuilder.glow(STEEL, MeshBuilder.METAL))
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		_beam(mb, hub, hub + Vector3(cos(a), sin(a), 0) * ring, 0.04, DARK)
	_beam(mb, hub + Vector3(-0.9, -0.2, -0.05), hub + Vector3(0.9, 0.2, -0.05), 0.1, Color(0.85, 0.85, 0.82), 0.03)
	for s: float in [-0.35, 0.35]:
		mb.box(Vector3(s, 1.4, 2.35), Vector3(0.04, 1.1, 0.5), color.darkened(0.2))
	mb.xform = saved
	_col(out, p + Vector3(0, 0.6, 0), Vector3(2.2, 1.2, 5.4), yaw)


## Crop-duster strip: an open-fronted arched metal hangar with a yellow
## biplane duster half out of it, a fuel tank and a windsock.
static func airstrip_hangar(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var hw := clampf(w * 0.7, 13.0, 24.0)
	var hd := clampf(d * 0.55, 9.0, 18.0)
	var cz := d * 0.5 - 1.0 - hd * 0.5
	var fz := cz - hd * 0.5
	const H := 4.6
	var galv := MeshBuilder.glow(Color(0.72, 0.74, 0.76), MeshBuilder.SEAM_ROOF)
	_pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, MeshBuilder.glow(LAWN.lerp(STRAW, 0.35), MeshBuilder.GRASS))
	_pad(mb, -hw * 0.5, hw * 0.5, -d * 0.5, cz + hd * 0.5, MeshBuilder.glow(CONCRETE, MeshBuilder.CONCRETE), 0.04)
	_solid(mb, out, Vector3(0, H * 0.5, cz + hd * 0.5 - 0.1), Vector3(hw, H, 0.2), galv)
	for s: float in [-1.0, 1.0]:
		_solid(mb, out, Vector3(s * (hw * 0.5 - 0.1), H * 0.5, cz), Vector3(0.2, H, hd), galv)
	_vault(mb, Vector3(0, 0, cz), _arch(hw * 0.5 + 0.3, clampf(hw * 0.2, 2.4, 4.5), H, 7), hd + 0.4, false, galv, galv)
	mb.box(Vector3(0, H - 0.2, fz - 0.15), Vector3(hw + 0.6, 0.4, 0.3), MeshBuilder.glow(Color(0.85, 0.3, 0.2), MeshBuilder.GLOSS))
	# The duster, half out on the apron.
	var length := clampf(hw * 0.45, 6.5, 8.5)
	_plane(mb, Vector3(0, 0, fz - length * 0.3), 0.0, length, YELLOW, Color(0.8, 0.15, 0.12), true, false, true)
	_col(out, Vector3(0, 1.3, fz - length * 0.3), Vector3(length * 1.1, 2.6, length))
	mb.box(Vector3(hw * 0.3, 1.0, cz + hd * 0.25), Vector3(1.6, 2.0, 1.6), MeshBuilder.glow(Color(0.85, 0.2, 0.15), MeshBuilder.GLOSS))
	_col(out, Vector3(hw * 0.3, 1.0, cz + hd * 0.25), Vector3(1.6, 2.0, 1.6))
	# Fuel tank and windsock.
	var tx := -w * 0.5 + 2.0
	var tz := -d * 0.5 + 3.0
	mb.limb(Vector3(tx, 1.6, tz - 1.2), Vector3(tx, 1.6, tz + 1.2), 0.65, 0.65, MeshBuilder.glow(WHITE, MeshBuilder.GLOSS), 8)
	for s: float in [-1.0, 1.0]:
		_beam(mb, Vector3(tx, 1.0, tz + s * 0.8), Vector3(tx, 0, tz + s * 0.9), 0.12, DARK)
	_col(out, Vector3(tx, 1.2, tz), Vector3(1.4, 2.4, 2.6))
	var wp := Vector3(w * 0.5 - 1.2, 0, -d * 0.5 + 1.2)
	mb.cylinder(wp, 0.06, 6.0, WHITE, 4)
	_col(out, wp + Vector3(0, 1.0, 0), Vector3(0.3, 2.0, 0.3))
	for k in 4:
		var r := 0.45 - k * 0.08
		mb.limb(wp + Vector3(-0.1 - k * 0.5, 5.8 - k * 0.1, 0), wp + Vector3(-0.6 - k * 0.5, 5.75 - k * 0.12, 0), r, r - 0.06, Color(1.0, 0.45, 0.1) if k % 2 == 0 else WHITE, 6, false)


# --- Beach ---------------------------------------------------------------------

## Points round a rectangle x0..x1 by z0..z1 with its front corners (at z0)
## rounded to radius r, clockwise on screen, for mb.prism. `back` replaces
## z1 to cut a front band.
static func _rounded_front(x0: float, x1: float, z0: float, z1: float, r: float, segs := 4) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(Vector2(x0, z1))
	for i in segs + 1:
		var a := PI + PI * 0.5 * i / segs
		pts.append(Vector2(x0 + r + cos(a) * r, z0 + r + sin(a) * r))
	for i in segs + 1:
		var a := PI * 1.5 + PI * 0.5 * i / segs
		pts.append(Vector2(x1 - r + cos(a) * r, z0 + r + sin(a) * r))
	pts.append(Vector2(x1, z1))
	return pts


## Pastel Art Deco hotel: three to six floors with rounded front corners
## wrapped in glass, eyebrow ledges, a neon fin over the entrance, a stepped
## crown, and a terrace with parasols facing the street.
static func deco_hotel(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var floors := rng.randi_range(3, 6)
	const FH := 3.2
	var H := floors * FH + 0.8
	var bw := w - 2.0
	var bd := clampf(d * 0.62, 8.0, 18.0)
	var fz := -d * 0.5 + clampf(d * 0.24, 4.0, 7.0)
	var cz := fz + bd * 0.5
	var x0 := -bw * 0.5
	var x1 := bw * 0.5
	var r := clampf(bw * 0.14, 1.4, 3.2)
	var paint: Color = _pick(PASTELS, rng)
	var accent: Color = _pick(ACCENTS, rng)
	var neon: Color = _pick(NEONS, rng)
	mb.prism(_rounded_front(x0, x1, fz, fz + bd, r), 0.0, H, accent.lightened(0.35), paint)
	mb.box(Vector3(0, H + 0.02, cz + 0.3), Vector3(bw - 1.2, 0.04, bd - 1.2), MeshBuilder.glow(Buildings.MEMBRANES[0], MeshBuilder.ROOF))
	_col(out, Vector3(0, H * 0.5, cz), Vector3(bw, H, bd))
	# Eyebrows over each floor, glass wrapping the rounded corners.
	var band := _rounded_front(x0 - 0.45, x1 + 0.45, fz - 0.45, fz + r + 0.8, r + 0.45)
	var glass := MeshBuilder.glow(Color(0.35, 0.5, 0.58), MeshBuilder.GLASS)
	for f in floors:
		var y := 0.6 + f * FH
		if f > 0:
			mb.prism(band, y - 0.12, y + 0.06, TRIM, TRIM.darkened(0.1))
		for c: Vector2 in [Vector2(x0 + r, PI), Vector2(x1 - r, PI * 1.5)]:
			for i in 4:
				var a0 := c.y + PI * 0.5 * i / 4.0
				var a1 := c.y + PI * 0.5 * (i + 1) / 4.0
				var p0 := Vector3(c.x + cos(a0) * (r + 0.04), 0, fz + r + sin(a0) * (r + 0.04))
				var p1 := Vector3(c.x + cos(a1) * (r + 0.04), 0, fz + r + sin(a1) * (r + 0.04))
				var n := Vector3(cos((a0 + a1) * 0.5), 0, sin((a0 + a1) * 0.5))
				mb.quad(p0 + Vector3(0, y + 0.8, 0), p1 + Vector3(0, y + 0.8, 0), p1 + Vector3(0, y + 2.3, 0), p0 + Vector3(0, y + 2.3, 0), n, glass if f > 0 else MeshBuilder.glow(SHOP_GLASS, MeshBuilder.GLOW_WINDOW))
		if f > 0:
			_windows(mb, Vector3(x0 + r + 0.6, y + 1.55, fz), Vector3(-1.2, y + 1.55, fz), maxi(1, int((bw * 0.5 - r - 1.8) / 1.8)), Vector2(1.2, 1.5), rng, Vector3.FORWARD, 0.5)
			_windows(mb, Vector3(1.2, y + 1.55, fz), Vector3(x1 - r - 0.6, y + 1.55, fz), maxi(1, int((bw * 0.5 - r - 1.8) / 1.8)), Vector2(1.2, 1.5), rng, Vector3.FORWARD, 0.5)
			for x: float in [x0, x1]:
				_windows(mb, Vector3(x, y + 1.55, fz + r + 0.5), Vector3(x, y + 1.55, fz + bd), maxi(1, int((bd - r) / 2.4)), Vector2(1.2, 1.5), rng, Vector3.LEFT if x < 0.0 else Vector3.RIGHT, 0.5)
		else:
			mb.box(Vector3(0, 1.8, fz - 0.04), Vector3(bw - 2.0 * r - 1.0, 2.4, 0.08), MeshBuilder.glow(SHOP_GLASS, MeshBuilder.GLOW_WINDOW))
	_windows(mb, Vector3(x0, H * 0.5, fz + bd), Vector3(x1, H * 0.5, fz + bd), maxi(2, int(bw / 2.4)), Vector2(1.0, H - 3.0), rng, Vector3.BACK, 0.3)
	# Neon fin over the entrance, and a stepped crown.
	var fin_h := H + 3.5
	mb.box(Vector3(0, fin_h * 0.5 + 1.0, fz - 0.75), Vector3(0.6, fin_h - 2.0, 1.5), accent)
	mb.box(Vector3(0, fin_h * 0.5 + 1.2, fz - 1.52), Vector3(0.2, fin_h - 3.0, 0.04), MeshBuilder.glow(neon, MeshBuilder.GLOW_NEON))
	for k in 5:
		mb.box(Vector3(0, H - 1.0 - k * 1.1, fz - 1.54), Vector3(0.45, 0.7, 0.03), MeshBuilder.glow(Color(1.0, 0.97, 0.9), MeshBuilder.GLOW_NEON))
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(s * 0.32, fin_h * 0.5 + 1.2, fz - 0.75), Vector3(0.04, fin_h - 3.0, 1.2), MeshBuilder.glow(neon, MeshBuilder.GLOW_NEON))
	var cw := bw * 0.34
	for k in 3:
		var tw := cw * (1.0 - k * 0.28)
		mb.box(Vector3(0, H + 0.45 + k * 0.9, fz + 0.9), Vector3(tw, 0.9, 1.6 - k * 0.3), accent if k % 2 == 0 else paint.lightened(0.15))
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(s * (cw * 0.5 + 0.8), H + 0.6, fz + 0.4), Vector3(0.35, 1.2, 0.35), accent)
	Buildings._hvac(mb, Vector3(-bw * 0.2, H, fz + bd - 2.0), Vector3(2.4, 1.0, 1.3))
	# Terrace in front: a raised deck with a low wall, marquee and parasols.
	var tz0 := -d * 0.5 + 0.6
	mb.box(Vector3(0, 0.25, (tz0 + fz) * 0.5), Vector3(bw, 0.5, fz - tz0), MeshBuilder.glow(Color(0.9, 0.86, 0.8), MeshBuilder.PAVING))
	for s: float in [-1.0, 1.0]:
		var xa := s * 1.6
		var xb := s * bw * 0.5
		_solid(mb, out, Vector3((xa + xb) * 0.5, 0.55, tz0 + 0.15), Vector3(absf(xb - xa), 1.1, 0.3), paint.darkened(0.08))
		mb.box(Vector3((xa + xb) * 0.5, 1.12, tz0 + 0.15), Vector3(absf(xb - xa) + 0.1, 0.06, 0.4), accent)
	_canopy(mb, out, -2.2, 2.2, fz - 2.6, fz, 3.6, 0.35, accent, paint, [], WHITE)
	mb.box(Vector3(0, 3.42, fz - 2.62), Vector3(4.4, 0.12, 0.04), MeshBuilder.glow(neon, MeshBuilder.GLOW_NEON))
	if fz - tz0 > 3.6:
		for s: float in [-1.0, 1.0]:
			Props.cafe_table(mb, out, Vector3(s * bw * 0.3, 0.5, (tz0 + fz) * 0.5), _pick(Buildings.PARASOLS, rng))


## Beach condo tower: ten to sixteen floors of balconies with glass rails,
## corner fins, a rooftop pool, a porte-cochère and palms.
static func condo_tower(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var floors := rng.randi_range(10, 16)
	const FH := 3.2
	var H := floors * FH + 1.0
	var tw := clampf(w * 0.62, 13.0, 26.0)
	var td := clampf(d * 0.4, 9.0, 16.0)
	var cz := clampf(d * 0.05, -2.0, 2.0)
	var fz := cz - td * 0.5
	var bz := cz + td * 0.5
	var white := Color(0.95, 0.95, 0.93)
	var accent: Color = [Color(0.35, 0.65, 0.8), Color(0.2, 0.6, 0.6), Color(0.85, 0.55, 0.5), Color(0.6, 0.7, 0.85)][rng.randi() % 4]
	var glass := MeshBuilder.glow(Color(0.3, 0.48, 0.6), MeshBuilder.GLASS)
	var rail := MeshBuilder.glow(Color(0.55, 0.72, 0.78), MeshBuilder.GLASS)
	_pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, MeshBuilder.glow(Color(0.86, 0.82, 0.72), MeshBuilder.PAVING))
	_solid(mb, out, Vector3(0, H * 0.5, cz), Vector3(tw, H, td), white)
	for f in floors:
		var y := 1.0 + f * FH
		for s: float in [-1.0, 1.0]:
			var z := cz + s * td * 0.5
			mb.box(Vector3(0, y + 1.4, z + s * 0.04), Vector3(tw - 1.2, 2.2, 0.08), glass)
			if f > 0:
				mb.box(Vector3(0, y, z + s * 0.8), Vector3(tw - 0.8, 0.18, 1.6), white)
				mb.box(Vector3(0, y + 0.55, z + s * 1.58), Vector3(tw - 0.8, 0.9, 0.04), rail)
		for x: float in [-tw * 0.5 - 0.04, tw * 0.5 + 0.04]:
			mb.box(Vector3(x, y + 1.4, cz), Vector3(0.08, 2.0, 1.4), glass)
	mb.box(Vector3(0, 2.2, fz - 0.06), Vector3(tw * 0.6, 3.6, 0.08), MeshBuilder.glow(Color(0.35, 0.45, 0.5), MeshBuilder.GLOW_WINDOW))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			mb.box(Vector3(sx * (tw * 0.5 - 0.2), H * 0.5 + 0.6, cz + sz * (td * 0.5 + 0.9)), Vector3(0.4, H + 1.2, 0.4), accent)
	# Roof: parapet, plant, a pool deck with loungers.
	_flat_roof(mb, 0, cz, tw, td, H, rng, accent.darkened(0.2), true)
	var pw := tw * 0.5
	mb.box(Vector3(-tw * 0.15, H + 0.1, cz - td * 0.15), Vector3(pw + 2.0, 0.12, td * 0.45), MeshBuilder.glow(Buildings.DECK, MeshBuilder.SIDING))
	mb.box(Vector3(-tw * 0.15, H + 0.18, cz - td * 0.15), Vector3(pw, 0.06, td * 0.25), POOL)
	for k in 3:
		mb.box(Vector3(-tw * 0.15 - pw * 0.4 + k * pw * 0.4, H + 0.3, cz - td * 0.15 - td * 0.18), Vector3(0.6, 0.15, 1.4), WHITE)
	# Porte-cochère, drop-off, palms.
	_canopy(mb, out, -4.0, 4.0, fz - 5.5, fz - 0.6, 4.6, 0.45, accent, MeshBuilder.glow(Buildings.MEMBRANES[0], MeshBuilder.ROOF), [Vector3(-3.6, 0, fz - 5.2), Vector3(3.6, 0, fz - 5.2)], WHITE)
	_pad(mb, -6.0, 6.0, -d * 0.5, fz - 0.6, MeshBuilder.glow(ASPHALT, MeshBuilder.ASPHALT), 0.04)
	for s: float in [-1.0, 1.0]:
		Props.palm(mb, out, Vector3(s * (w * 0.5 - 3.2), 0, -d * 0.5 + 3.2), rng)
		if d * 0.5 - bz > 5.0:
			Props.palm(mb, out, Vector3(s * (w * 0.5 - 3.2), 0, d * 0.5 - 3.2), rng)
	if d * 0.5 - bz > 7.0:
		var pz0 := bz + 2.5
		var pz1 := d * 0.5 - 1.0
		mb.box(Vector3(0, 0.07, (pz0 + pz1) * 0.5), Vector3(minf(tw * 0.6, 12.0), 0.04, pz1 - pz0 - 1.0), POOL)


## Beach bar: a timber deck, a thatched hip roof on posts over a square
## bar with stools, a surfboard rack and parasol tables.
static func beach_bar(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var deck := MeshBuilder.glow(Buildings.DECK.lightened(0.1), MeshBuilder.SIDING)
	mb.box(Vector3(0, 0.15, 0), Vector3(w - 0.6, 0.3, d - 0.6), deck)
	var bw := clampf(w * 0.42, 3.5, 7.0)
	var bd := clampf(d * 0.4, 3.0, 6.0)
	var cz := d * 0.12
	var wood := Color(0.55, 0.38, 0.24)
	var counter := MeshBuilder.glow(Color(0.25, 0.55, 0.6), MeshBuilder.GLOSS)
	for s: float in [-1.0, 1.0]:
		_solid(mb, out, Vector3(s * bw * 0.5, 0.85, cz), Vector3(0.6, 1.1, bd), wood)
		_solid(mb, out, Vector3(0, 0.85, cz + s * bd * 0.5), Vector3(bw, 1.1, 0.6), wood)
		mb.box(Vector3(s * bw * 0.5, 1.43, cz), Vector3(0.8, 0.06, bd + 0.2), counter)
		mb.box(Vector3(0, 1.43, cz + s * bd * 0.5), Vector3(bw + 0.2, 0.06, 0.8), counter)
	mb.box(Vector3(0, 1.0, cz), Vector3(bw * 0.5, 1.4, 0.5), wood.darkened(0.2))
	for k in 6:
		mb.box(Vector3(-bw * 0.2 + k * bw * 0.08, 1.85, cz), Vector3(0.1, 0.3, 0.1), MeshBuilder.glow(NEONS[k % NEONS.size()], MeshBuilder.GLASS))
	for k in maxi(2, int(bw / 1.0)):
		var x := -bw * 0.5 + 0.5 + k * (bw - 1.0) / maxf(1.0, int(bw / 1.0) - 1)
		mb.cylinder(Vector3(x, 0.3, cz - bd * 0.5 - 0.8), 0.2, 0.75, MeshBuilder.glow(DARK.lightened(0.2), MeshBuilder.GLOSS), 6)
	var posts := [Vector3(-bw * 0.5 - 0.6, 0, cz - bd * 0.5 - 0.6), Vector3(bw * 0.5 + 0.6, 0, cz - bd * 0.5 - 0.6), Vector3(bw * 0.5 + 0.6, 0, cz + bd * 0.5 + 0.6), Vector3(-bw * 0.5 - 0.6, 0, cz + bd * 0.5 + 0.6)]
	for p: Vector3 in posts:
		mb.cylinder(p + Vector3(0, 0.3, 0), 0.14, 2.9, wood, 6)
		_col(out, p + Vector3(0, 1.5, 0), Vector3(0.3, 3.0, 0.3))
	var thatch := Color(0.78, 0.66, 0.4)
	_hip(mb, Vector3(0, 3.2, cz), bw + 3.0, bd + 3.0, 2.2, thatch)
	mb.box(Vector3(0, 3.15, cz), Vector3(bw + 3.0, 0.15, bd + 3.0), thatch.darkened(0.2))
	for i in 12:
		var t := i / 12.0
		mb.box(Vector3(-bw * 0.5 - 1.5 + (bw + 3.0) * t, 3.0, cz - bd * 0.5 - 1.5), Vector3(0.18, 0.4, 0.06), thatch.darkened(0.15))
	Props.festoon(mb, posts[0] + Vector3(0, 2.9, 0), Vector3(-w * 0.5 + 0.8, 2.4, -d * 0.5 + 0.8), rng)
	# Surfboards in a rack, two parasol tables on the deck.
	var rx := w * 0.5 - 0.9
	for k in 3:
		mb.box(Vector3(rx, 1.3, -d * 0.5 + 1.2 + k * 0.45), Vector3(0.6, 2.2, 0.08), MeshBuilder.glow(_pick(PASTELS, rng), MeshBuilder.GLOSS))
	_col(out, Vector3(rx, 1.1, -d * 0.5 + 1.65), Vector3(0.7, 2.2, 1.4))
	if w >= 11.0:
		Props.cafe_table(mb, out, Vector3(-w * 0.5 + 2.0, 0.3, -d * 0.5 + 2.0), _pick(Buildings.PARASOLS, rng))
		Props.cafe_table(mb, out, Vector3(-w * 0.5 + 2.0, 0.3, d * 0.5 - 1.8), _pick(Buildings.PARASOLS, rng))


## Lifeguard tower: a bright hut on four piles with a ramp, a flag and a
## rescue float; only the piles collide.
static func lifeguard_tower(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var s := minf(w, d)
	var hs := clampf(s * 0.4, 1.8, 3.0)
	const PH := 2.2
	var paint: Color = [Color(0.98, 0.85, 0.3), Color(0.96, 0.6, 0.7), Color(0.35, 0.8, 0.8), Color(0.98, 0.6, 0.3), Color(0.6, 0.75, 0.95)][rng.randi() % 5]
	var stripe: Color = _pick(ACCENTS, rng)
	var wood := Color(0.62, 0.55, 0.45)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var p := Vector3(sx * hs * 0.45, 0, sz * hs * 0.45)
			mb.cylinder(p, 0.12, PH, wood, 5)
			_col(out, p + Vector3(0, PH * 0.5, 0), Vector3(0.3, PH, 0.3))
	_beam(mb, Vector3(-hs * 0.45, 0.2, -hs * 0.45), Vector3(hs * 0.45, PH - 0.2, -hs * 0.45), 0.08, wood)
	_beam(mb, Vector3(hs * 0.45, 0.2, -hs * 0.45), Vector3(-hs * 0.45, PH - 0.2, -hs * 0.45), 0.08, wood)
	mb.box(Vector3(0, PH, -0.2), Vector3(hs + 0.6, 0.14, hs + 1.0), MeshBuilder.glow(wood, MeshBuilder.SIDING))
	mb.box(Vector3(0, PH + 0.6, -hs * 0.5 - 0.65), Vector3(hs + 0.6, 0.05, 0.05), WHITE)
	mb.box(Vector3(0, PH + 1.1, 0.1), Vector3(hs, 2.0, hs * 0.8), MeshBuilder.glow(paint, MeshBuilder.SIDING))
	mb.box(Vector3(0, PH + 0.5, 0.1 - hs * 0.4 - 0.03), Vector3(hs, 0.35, 0.04), stripe)
	mb.box(Vector3(0, PH + 1.4, 0.1 - hs * 0.4 - 0.04), Vector3(hs * 0.7, 0.8, 0.06), MeshBuilder.glow(Color(0.3, 0.45, 0.55), MeshBuilder.GLASS))
	_hip(mb, Vector3(0, PH + 2.1, 0.1), hs + 0.6, hs * 0.8 + 0.6, 0.8, stripe)
	var back := minf(d * 0.5 - 0.2, hs * 0.45 + 2.6)
	_beam(mb, Vector3(0, PH - 0.05, hs * 0.5), Vector3(0, 0.1, back), 0.08, MeshBuilder.glow(wood, MeshBuilder.SIDING), 0.9)
	mb.cylinder(Vector3(hs * 0.5 + 0.1, PH, -hs * 0.5), 0.03, 2.6, WHITE, 4)
	mb.box(Vector3(hs * 0.5 + 0.55, PH + 2.3, -hs * 0.5), Vector3(0.9, 0.3, 0.02), Color(0.85, 0.15, 0.12))
	mb.box(Vector3(hs * 0.5 + 0.55, PH + 2.0, -hs * 0.5), Vector3(0.9, 0.3, 0.02), YELLOW)
	mb.box(Vector3(-hs * 0.5 - 0.04, PH + 1.0, 0.1), Vector3(0.08, 0.25, 0.9), Color(1.0, 0.45, 0.1))


# --- Landmarks -----------------------------------------------------------------

## Golden Flats grain elevators: two rows of tall concrete silos with a
## conveyor gallery along the top, a taller head house with the co-op band,
## a drive-through truck dump, an office and a rail spur at the back.
static func grain_elevators(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var r := clampf(w * 0.065, 2.2, 3.6)
	var cols := clampi(int(w * 0.55 / (2.0 * r)), 3, 7)
	var H := clampf(w * 0.5, 18.0, 30.0)
	var conc := MeshBuilder.glow(Color(0.84, 0.82, 0.76), MeshBuilder.CONCRETE)
	var cx0 := -w * 0.5 + 2.0
	var cwid := cols * 2.0 * r
	var cz := clampf(d * 0.1, -d * 0.5 + 2.0 * r + 8.0, d * 0.5 - 2.0 * r - 3.0)
	_pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, MeshBuilder.glow(GRAVEL, MeshBuilder.CONCRETE))
	for row in 2:
		for c in cols:
			var p := Vector3(cx0 + r + c * 2.0 * r, 0, cz + (row - 0.5) * 2.0 * r)
			mb.cylinder(p, r, H, conc, 12)
			mb.cylinder(p + Vector3(0, H - 0.6, 0), r + 0.05, 0.3, Color(0.6, 0.58, 0.54), 12)
	mb.box(Vector3(cx0 + cwid * 0.5, H * 0.5 - 0.02, cz), Vector3(cwid - 2.0 * r, H - 0.04, 2.0 * r), conc)
	_col(out, Vector3(cx0 + cwid * 0.5, H * 0.5, cz), Vector3(cwid, H, 4.0 * r))
	mb.box(Vector3(cx0 + cwid * 0.5 + 2.0, H + 1.3, cz), Vector3(cwid + 4.0, 2.6, 3.0), MeshBuilder.glow(Color(0.7, 0.7, 0.68), MeshBuilder.SEAM_ROOF))
	mb.box(Vector3(cx0 + cwid * 0.5 + 2.0, H + 1.6, cz - 1.52), Vector3(cwid + 3.0, 0.5, 0.04), MeshBuilder.glow(PANE, MeshBuilder.GLASS))
	# Head house.
	var hx := cx0 + cwid + 4.5
	var hh := H + 12.0
	_solid(mb, out, Vector3(hx, hh * 0.5, cz), Vector3(8.0, hh, 9.0), conc)
	_gable(mb, hx, cz, hh, 8.6, 9.6, 2.4, MeshBuilder.glow(Color(0.55, 0.57, 0.6), MeshBuilder.SEAM_ROOF), conc)
	mb.box(Vector3(hx, hh - 3.5, cz - 4.54), Vector3(7.6, 2.4, 0.08), Color(0.62, 0.14, 0.12))
	for k in 5:
		mb.box(Vector3(hx - 3.0 + k * 1.5, hh - 3.5, cz - 4.6), Vector3(1.0, 1.4, 0.04), WHITE)
	for k in 4:
		mb.box(Vector3(hx, 4.0 + k * (hh - 9.0) / 4.0, cz - 4.54), Vector3(1.0, 1.2, 0.08), Buildings._window(rng, 0.3))
	# Spouts and the drive-through truck dump in front of the head house.
	var sz0 := cz - 4.5 - 9.0
	_beam(mb, Vector3(hx - 2.0, hh - 6.0, cz - 4.5), Vector3(hx - 1.0, 6.5, sz0 + 4.5), 0.35, MeshBuilder.glow(STEEL, MeshBuilder.METAL))
	_beam(mb, Vector3(hx + 1.0, hh - 3.0, cz), Vector3(cx0 + cwid - r, H + 1.0, cz - r), 0.3, MeshBuilder.glow(STEEL, MeshBuilder.METAL))
	_canopy(mb, out, hx - 4.0, hx + 4.0, sz0, cz - 4.5, 6.0, 0.6, MeshBuilder.glow(TIN, MeshBuilder.SEAM_ROOF), MeshBuilder.glow(TIN.lightened(0.1), MeshBuilder.SEAM_ROOF), [Vector3(hx - 3.8, 0, sz0 + 0.2), Vector3(hx + 3.8, 0, sz0 + 0.2)])
	mb.box(Vector3(hx, 0.05, sz0 + 4.5), Vector3(3.6, 0.06, 7.0), MeshBuilder.glow(Color(0.3, 0.3, 0.32), MeshBuilder.METAL))
	# Office, rail spur, a truck waiting.
	var ox := -w * 0.5 + 6.0
	var oz := -d * 0.5 + 4.0
	_solid(mb, out, Vector3(ox, 1.7, oz), Vector3(8.0, 3.4, 5.0), Color(0.88, 0.85, 0.75))
	_gable(mb, ox, oz, 3.4, 8.6, 5.6, 1.2, MeshBuilder.glow(Color(0.55, 0.28, 0.22), MeshBuilder.SEAM_ROOF), Color(0.88, 0.85, 0.75))
	_windows(mb, Vector3(ox - 4.0, 1.8, oz - 2.5), Vector3(ox + 4.0, 1.8, oz - 2.5), 3, Vector2(1.2, 1.1), rng, Vector3.FORWARD, 0.4)
	Props.rails(mb, Vector3(-w * 0.5, 0, d * 0.5 - 1.5), Vector3(w * 0.5, 0, d * 0.5 - 1.5), true)
	_pickup(mb, out, Vector3(hx + 6.5 if hx + 9.5 < w * 0.5 else ox + 6.0, 0, sz0 + 1.0), 0.0, _pick(PAINTS, rng))


static func _cow(mb, out: Array, p: Vector3, yaw: float, rng: RandomNumberGenerator) -> void:
	var saved: Transform3D = mb.xform
	mb.xform = saved * Transform3D(Basis(Vector3.UP, yaw), p)
	var holstein := rng.randf() < 0.5
	var body := WHITE if holstein else Color(0.5, 0.32, 0.2)
	mb.box(Vector3(0, 1.05, 0), Vector3(0.8, 0.8, 1.8), body)
	if holstein:
		mb.box(Vector3(0.05, 1.47, 0.3), Vector3(0.6, 0.04, 0.7), DARK)
		mb.box(Vector3(0.41, 1.1, -0.3), Vector3(0.02, 0.5, 0.6), DARK)
	mb.box(Vector3(0, 1.3, -1.1), Vector3(0.45, 0.5, 0.6), body.darkened(0.1))
	mb.box(Vector3(0, 1.15, -1.42), Vector3(0.4, 0.3, 0.1), Color(0.85, 0.65, 0.6))
	for x: float in [-0.28, 0.28]:
		for z: float in [-0.7, 0.7]:
			mb.box(Vector3(x, 0.33, z), Vector3(0.16, 0.66, 0.16), body.darkened(0.2))
	mb.xform = saved
	_col(out, p + Vector3(0, 0.8, 0), Vector3(0.9, 1.6, 2.6), yaw)


## Hollis Farm: the family farmhouse, the red barn, grain bins and a
## machine shed round a gravel lane under an entrance arch, with a fenced
## pasture (cows, a windpump) and a corn patch.
static func hollis_farm(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	_pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, MeshBuilder.glow(LAWN.lerp(STRAW, 0.25), MeshBuilder.GRASS))
	var lx := -w * 0.1
	var gravel := MeshBuilder.glow(GRAVEL, MeshBuilder.CONCRETE)
	_pad(mb, lx - 2.0, lx + 2.0, -d * 0.5, d * 0.42, gravel, 0.03)
	_pad(mb, lx, w * 0.2, -d * 0.05, -d * 0.01, gravel, 0.03)
	_sub("farmhouse", mb, out, Vector3(-w * 0.3, 0, -d * 0.3), 0.0, Vector2(w * 0.27, d * 0.33), rng)
	_sub("barn", mb, out, Vector3(w * 0.08, 0, d * 0.18), 0.0, Vector2(w * 0.22, d * 0.33), rng)
	_sub("silos", mb, out, Vector3(w * 0.32, 0, d * 0.3), 0.0, Vector2(w * 0.18, d * 0.17), rng)
	_sub("machine_shed", mb, out, Vector3(-w * 0.3, 0, d * 0.32), 0.0, Vector2(w * 0.27, d * 0.22), rng)
	# Pasture: a fence round the front-right with cows and a windpump.
	var px0 := w * 0.12
	var px1 := w * 0.46
	var pz0 := -d * 0.42
	var pz1 := d * 0.02
	_pad(mb, px0, px1, pz0, pz1, MeshBuilder.glow(LAWN.lightened(0.05), MeshBuilder.GRASS), 0.03)
	var rail := Color(0.92, 0.9, 0.85)
	Props.fence(mb, out, Vector3(px0, 0, pz0), Vector3(px1, 0, pz0), rail)
	Props.fence(mb, out, Vector3(px1, 0, pz0), Vector3(px1, 0, pz1), rail)
	Props.fence(mb, out, Vector3(px0, 0, pz1), Vector3(px1, 0, pz1), rail)
	Props.fence(mb, out, Vector3(px0, 0, pz0), Vector3(px0, 0, pz1 - 5.0), rail)
	_sub("windpump", mb, out, Vector3(w * 0.3, 0, -d * 0.18), 0.0, Vector2(8, 8), rng)
	for k in 4:
		_cow(mb, out, Vector3(lerpf(px0 + 4.0, px1 - 4.0, rng.randf()), 0, lerpf(pz0 + 4.0, -d * 0.26, rng.randf())), rng.randf() * TAU, rng)
	# Corn patch between the house and the pasture.
	var corn := MeshBuilder.glow(Color(0.45, 0.58, 0.22), MeshBuilder.GRASS)
	var cx0 := lx + 3.0
	var cx1 := px0 - 2.0
	if cx1 - cx0 > 3.0:
		var z := -d * 0.45
		while z < -d * 0.1:
			mb.box(Vector3((cx0 + cx1) * 0.5, 0.8, z), Vector3(cx1 - cx0, 1.6, 0.5), corn)
			z += 1.2
		_col(out, Vector3((cx0 + cx1) * 0.5, 0.8, -d * 0.275), Vector3(cx1 - cx0, 1.6, d * 0.35))
	_tractor(mb, out, Vector3(lx + 6.0, 0, -d * 0.03), PI * 0.5, Color(0.2, 0.5, 0.25))
	# Entrance arch over the lane.
	var az := -d * 0.5 + 1.0
	for s: float in [-1.0, 1.0]:
		_post(mb, out, Vector3(lx + s * 2.6, 0, az), 5.0, 0.35, WOOD.darkened(0.2))
	mb.box(Vector3(lx, 4.6, az), Vector3(6.0, 0.3, 0.3), WOOD.darkened(0.2))
	mb.box(Vector3(lx, 3.9, az - 0.05), Vector3(4.2, 0.9, 0.1), Color(0.93, 0.88, 0.75))
	for k in 6:
		mb.box(Vector3(lx - 1.6 + k * 0.64, 3.9, az - 0.12), Vector3(0.4, 0.5, 0.03), Color(0.45, 0.15, 0.1))
	_rural_mailbox(mb, Vector3(lx + 3.4, 0, -d * 0.5 + 0.6))


## Larkspur Estate: a U-shaped villa and winery round a paved courtyard
## with a fountain, a belvedere tower, terracotta roofs, a cypress avenue
## from the lane and vine rows on three sides.
static func larkspur_vineyard(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var mw := clampf(w * 0.4, 20.0, 36.0)
	var wl := clampf(d * 0.22, 9.0, 18.0)
	var md := 9.0
	var ww := 8.0
	var fz := -d * 0.5 + clampf(d * 0.2, 8.0, 16.0)
	var hz := fz + wl
	var stucco: Color = [Color(0.93, 0.84, 0.66), Color(0.9, 0.78, 0.6), Color(0.95, 0.9, 0.78)][rng.randi() % 3]
	var tile := MeshBuilder.glow(TERRACOTTA, MeshBuilder.SEAM_ROOF)
	_pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, MeshBuilder.glow(Color(0.5, 0.56, 0.32), MeshBuilder.GRASS))
	# Main hall and wings.
	_solid(mb, out, Vector3(0, 3.7, hz + md * 0.5), Vector3(mw, 7.4, md), stucco)
	_hip(mb, Vector3(0, 7.4, hz + md * 0.5), mw + 1.0, md + 1.0, 2.6, tile)
	for s: float in [-1.0, 1.0]:
		var wx := s * (mw * 0.5 - ww * 0.5)
		_solid(mb, out, Vector3(wx, 2.2, fz + wl * 0.5), Vector3(ww, 4.4, wl), stucco.darkened(0.04))
		_hip(mb, Vector3(wx, 4.4, fz + wl * 0.5 - 0.3), ww + 1.0, wl + 0.4, 2.0, tile)
		for k in maxi(1, int(wl / 3.0)):
			mb.box(Vector3(wx - s * (ww * 0.5 + 0.04), 1.6, fz + 1.5 + k * 3.0), Vector3(0.08, 2.4, 1.4), MeshBuilder.glow(Color(0.3, 0.22, 0.16), MeshBuilder.GLOW_WINDOW))
		_windows(mb, Vector3(wx - ww * 0.5, 2.2, fz), Vector3(wx + ww * 0.5, 2.2, fz), 2, Vector2(1.0, 1.4), rng, Vector3.FORWARD, 0.4, Color(0.3, 0.38, 0.25))
	for f in 2:
		_windows(mb, Vector3(-mw * 0.5 + ww, 1.8 + f * 3.6, hz), Vector3(mw * 0.5 - ww, 1.8 + f * 3.6, hz), maxi(2, int((mw - 2.0 * ww) / 2.6)), Vector2(1.1, 1.8), rng, Vector3.FORWARD, 0.4, Color(0.3, 0.38, 0.25))
	_all_windows(mb, -mw * 0.5, mw * 0.5, hz, hz + md, 0.0, 2, 3.6, 3.0, Vector2(1.0, 1.6), rng, 0.4)
	mb.box(Vector3(0, 1.6, hz - 0.05), Vector3(2.4, 3.2, 0.1), WOOD.darkened(0.2))
	# Belvedere tower at an inner corner.
	var tx := -mw * 0.5 + ww + 2.6
	var tz := hz + 2.6
	_solid(mb, out, Vector3(tx, 6.5, tz), Vector3(5.0, 13.0, 5.0), stucco.lightened(0.04))
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(tx, 11.6, tz + s * 2.52), Vector3(3.4, 1.6, 0.06), Color(0.15, 0.12, 0.1))
		mb.box(Vector3(tx + s * 2.52, 11.6, tz), Vector3(0.06, 1.6, 3.4), Color(0.15, 0.12, 0.1))
	_hip(mb, Vector3(tx, 13.0, tz), 6.0, 6.0, 2.2, tile)
	# Courtyard: paving, fountain, potted trees, barrels by the cellar door.
	var paving := MeshBuilder.glow(Color(0.82, 0.74, 0.6), MeshBuilder.PAVING)
	_pad(mb, -mw * 0.5 + ww, mw * 0.5 - ww, fz, hz, paving, 0.04)
	var fc := Vector3(0, 0, fz + wl * 0.5)
	mb.cylinder(fc, 2.2, 0.6, MeshBuilder.glow(Color(0.78, 0.74, 0.66), MeshBuilder.CONCRETE), 10)
	mb.cylinder(fc + Vector3(0, 0.6, 0), 1.9, 0.01, POOL, 10)
	mb.cylinder(fc, 0.3, 1.8, MeshBuilder.glow(Color(0.78, 0.74, 0.66), MeshBuilder.CONCRETE), 6)
	mb.cylinder(fc + Vector3(0, 1.8, 0), 0.9, 0.15, MeshBuilder.glow(Color(0.78, 0.74, 0.66), MeshBuilder.CONCRETE), 8)
	_col(out, fc + Vector3(0, 0.5, 0), Vector3(3.4, 1.0, 3.4))
	for s: float in [-1.0, 1.0]:
		var pp := Vector3(s * (mw * 0.5 - ww - 1.5), 0, hz - 1.5)
		mb.cylinder(pp, 0.5, 0.7, TERRACOTTA, 7)
		_bush(mb, pp + Vector3(0, 0.6, 0), 0.9, rng, Color(0.4, 0.5, 0.3))
	for k in 4:
		var bp := Vector3(mw * 0.5 - ww - 1.0, 0, fz + 1.5 + k * 1.0)
		Props.barrel(mb, out, bp, Color(0.45, 0.3, 0.18))
	# Low wall and gate between the wings.
	for s: float in [-1.0, 1.0]:
		var xa := s * 2.4
		var xb := s * (mw * 0.5 - ww)
		_solid(mb, out, Vector3((xa + xb) * 0.5, 0.6, fz + 0.2), Vector3(absf(xb - xa), 1.2, 0.4), stucco.darkened(0.08))
		_solid(mb, out, Vector3(xa, 1.2, fz + 0.2), Vector3(0.8, 2.4, 0.8), stucco.darkened(0.12))
	# Cypress avenue and the drive.
	_pad(mb, -2.4, 2.4, -d * 0.5, fz, MeshBuilder.glow(GRAVEL.lightened(0.1), MeshBuilder.CONCRETE), 0.03)
	var z := -d * 0.5 + 2.0
	while z < fz - 1.5:
		for s: float in [-1.0, 1.0]:
			_cypress(mb, out, Vector3(s * 3.6, 0, z), rng.randf_range(8.0, 10.0), rng)
		z += 5.0
	# Vine rows on posts: either side of the avenue, and behind the villa.
	var vine := MeshBuilder.glow(Color(0.33, 0.48, 0.2), MeshBuilder.GRASS)
	var blocks := [[-w * 0.5 + 1.5, -6.0, -d * 0.5 + 1.5, fz - 1.0], [6.0, w * 0.5 - 1.5, -d * 0.5 + 1.5, fz - 1.0],
		[-w * 0.5 + 1.5, -mw * 0.5 - 2.0, fz, d * 0.5 - 1.5], [mw * 0.5 + 2.0, w * 0.5 - 1.5, fz, d * 0.5 - 1.5],
		[-mw * 0.5, mw * 0.5, hz + md + 3.0, d * 0.5 - 1.5]]
	for b in blocks:
		var bx0: float = b[0]
		var bx1: float = b[1]
		if bx1 - bx0 < 4.0:
			continue
		var vz: float = b[2] + 1.0
		while vz < b[3] - 0.5:
			mb.box(Vector3((bx0 + bx1) * 0.5, 0.75, vz), Vector3(bx1 - bx0 - 1.0, 1.1, 0.6), vine)
			for x: float in [bx0 + 0.3, bx1 - 0.3]:
				mb.box(Vector3(x, 0.8, vz), Vector3(0.1, 1.6, 0.1), WOOD)
			_col(out, Vector3((bx0 + bx1) * 0.5, 0.8, vz), Vector3(bx1 - bx0 - 0.4, 1.6, 0.6))
			vz += 2.6


static func _gator(mb, p: Vector3, yaw: float, size: float) -> void:
	var saved: Transform3D = mb.xform
	mb.xform = saved * Transform3D(Basis(Vector3.UP, yaw), p) * Transform3D(Basis().scaled(Vector3.ONE * size), Vector3.ZERO)
	var hide := Color(0.26, 0.33, 0.2)
	mb.box(Vector3(0, 0.16, 0), Vector3(0.6, 0.3, 1.4), hide)
	mb.box(Vector3(0, 0.33, 0), Vector3(0.36, 0.06, 1.2), hide.darkened(0.2))
	mb.box(Vector3(0, 0.15, -0.95), Vector3(0.42, 0.24, 0.6), hide)
	mb.box(Vector3(0, 0.12, -1.45), Vector3(0.28, 0.16, 0.5), hide.lightened(0.05))
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(s * 0.13, 0.3, -1.1), Vector3(0.1, 0.08, 0.1), Color(0.8, 0.75, 0.3))
		for z: float in [-0.45, 0.45]:
			mb.box(Vector3(s * 0.38, 0.08, z), Vector3(0.22, 0.12, 0.16), hide.darkened(0.1))
	_beam(mb, Vector3(0, 0.15, 0.7), Vector3(0.15, 0.12, 1.5), 0.24, hide)
	_beam(mb, Vector3(0.15, 0.12, 1.5), Vector3(0.45, 0.08, 2.2), 0.14, hide)
	mb.xform = saved


## Gator farm: a tin-roofed gift shop, a big cartoon gator sign over the
## lane, walled pens with ponds and basking gators either side of a
## boardwalk, a viewing shelter and a feed shed.
static func gator_farm(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	_pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, MeshBuilder.glow(DIRT.lightened(0.15), MeshBuilder.CONCRETE))
	# Gift shop.
	var sx := -w * 0.5 + 6.0
	var sz := -d * 0.5 + 5.0
	var shop := MeshBuilder.glow(Color(0.55, 0.7, 0.45), MeshBuilder.SIDING)
	_solid(mb, out, Vector3(sx, 1.8, sz), Vector3(10.0, 3.6, 6.0), shop)
	_gable(mb, sx, sz, 3.6, 10.8, 6.8, 1.6, MeshBuilder.glow(TIN.lerp(RUST, 0.4), MeshBuilder.SEAM_ROOF), shop)
	mb.box(Vector3(sx, 0.3, sz - 4.0), Vector3(10.0, 0.12, 2.0), MeshBuilder.glow(WOOD.lightened(0.2), MeshBuilder.SIDING))
	for k in 3:
		_solid(mb, out, Vector3(sx - 4.8 + k * 4.8, 1.5, sz - 4.9), Vector3(0.16, 3.0, 0.16), WOOD)
	mb.box(Vector3(sx, 3.0, sz - 3.9), Vector3(10.4, 0.1, 2.0), MeshBuilder.glow(TIN, MeshBuilder.SEAM_ROOF))
	mb.box(Vector3(sx - 2.0, 1.2, sz - 3.04), Vector3(1.0, 2.2, 0.08), WOOD.darkened(0.3))
	mb.box(Vector3(sx + 2.0, 1.7, sz - 3.04), Vector3(3.0, 1.3, 0.08), MeshBuilder.glow(SHOP_GLASS, MeshBuilder.GLOW_WINDOW))
	# The gator sign: a board on posts with a grinning gator on top.
	var gp := Vector3(w * 0.5 - 7.0, 0, -d * 0.5 + 2.0)
	for s: float in [-1.0, 1.0]:
		_post(mb, out, gp + Vector3(s * 2.6, 0, 0), 3.4, 0.3, WOOD.darkened(0.2))
	mb.box(gp + Vector3(0, 3.0, 0), Vector3(6.4, 1.4, 0.2), YELLOW)
	for k in 6:
		mb.box(gp + Vector3(-2.5 + k * 1.0, 3.0, -0.12), Vector3(0.7, 0.8, 0.03), Color(0.2, 0.35, 0.15))
	var green := Color(0.3, 0.6, 0.25)
	var g := gp + Vector3(0, 4.3, -0.05)
	mb.box(g, Vector3(4.0, 0.8, 0.3), green)
	mb.box(g + Vector3(0.2, -0.3, -0.16), Vector3(3.0, 0.25, 0.04), Color(0.95, 0.85, 0.45))
	mb.box(g + Vector3(-2.6, 0.0, 0), Vector3(1.4, 0.4, 0.3), green)
	_beam(mb, g + Vector3(-2.0, 0.25, 0), g + Vector3(-3.4, 0.9, 0), 0.3, green, 0.3)
	for k in 4:
		mb.box(g + Vector3(-2.2 - k * 0.32, 0.25 + k * 0.15, -0.16), Vector3(0.12, 0.16, 0.04), WHITE)
		mb.box(g + Vector3(-2.2 - k * 0.32, 0.25, -0.16), Vector3(0.12, 0.12, 0.04), WHITE)
	mb.ball(g + Vector3(-1.9, 0.55, -0.1), Vector3(0.2, 0.2, 0.15), WHITE, 6, 3)
	mb.box(g + Vector3(-1.95, 0.57, -0.26), Vector3(0.1, 0.12, 0.03), DARK)
	_beam(mb, g + Vector3(2.0, 0, 0), g + Vector3(3.0, 0.5, 0), 0.5, green, 0.3)
	_beam(mb, g + Vector3(3.0, 0.5, 0), g + Vector3(3.2, 1.1, 0), 0.3, green, 0.3)
	for x: float in [-1.3, 1.3]:
		mb.box(g + Vector3(x, -0.6, 0), Vector3(0.3, 0.5, 0.3), green)
	# Pens either side of a boardwalk.
	var pz0 := -d * 0.5 + 11.0
	var pz1 := d * 0.5 - 1.0
	var cols := 3 if w >= 45.0 else 2
	var wall := MeshBuilder.glow(CONCRETE, MeshBuilder.CONCRETE)
	var water := MeshBuilder.glow(SWAMP.lightened(0.05), MeshBuilder.GLASS)
	var pen_w := (w * 0.5 - 1.0 - 1.4) / cols
	var pen_d := (pz1 - pz0) / 2.0
	for s: float in [-1.0, 1.0]:
		for c in cols:
			for row in 2:
				var x0 := s * (1.4 + c * pen_w)
				var x1 := s * (1.4 + (c + 1) * pen_w)
				var xa := minf(x0, x1)
				var xb := maxf(x0, x1)
				var za := pz0 + row * pen_d
				var zb := za + pen_d
				_pad(mb, xa + 0.3, xb - 0.3, za + 0.3, zb - 0.3, MeshBuilder.glow(Color(0.7, 0.62, 0.45), MeshBuilder.CONCRETE), 0.03)
				_pad(mb, xa + 0.5, xb - 0.5, za + pen_d * 0.4, zb - 0.5, water, 0.04)
				for e in [[Vector3((xa + xb) * 0.5, 0.5, za), Vector3(xb - xa, 1.0, 0.3)], [Vector3((xa + xb) * 0.5, 0.5, zb), Vector3(xb - xa, 1.0, 0.3)], [Vector3(xa, 0.5, (za + zb) * 0.5), Vector3(0.3, 1.0, pen_d)], [Vector3(xb, 0.5, (za + zb) * 0.5), Vector3(0.3, 1.0, pen_d)]]:
					_solid(mb, out, e[0], e[1], wall)
				_gator(mb, Vector3(lerpf(xa + 1.5, xb - 1.5, rng.randf()), 0.03, za + rng.randf_range(1.0, pen_d * 0.35)), rng.randf() * TAU, rng.randf_range(0.8, 1.3))
				if row == 1 or c == 0:
					_gator(mb, Vector3(lerpf(xa + 1.5, xb - 1.5, rng.randf()), -0.08, za + pen_d * 0.7), rng.randf() * TAU, 1.0)
	# Boardwalk down the middle, a viewing shelter and a feed shed.
	var plank := MeshBuilder.glow(OLD_WOOD.lightened(0.15), MeshBuilder.SIDING)
	mb.box(Vector3(0, 0.45, (pz0 - 4.0 + pz1) * 0.5), Vector3(2.4, 0.12, pz1 - pz0 + 4.0), plank)
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(s * 1.15, 1.4, (pz0 + pz1) * 0.5), Vector3(0.06, 0.06, pz1 - pz0), WOOD)
	var vz := (pz0 + pz1) * 0.5
	for s: float in [-1.0, 1.0]:
		for t: float in [-1.0, 1.0]:
			_post(mb, out, Vector3(s * 1.1, 0, vz + t * 2.0), 3.0, 0.15, WOOD)
	_gable(mb, 0, vz, 3.0, 3.2, 5.0, 1.0, MeshBuilder.glow(TIN, MeshBuilder.SEAM_ROOF), WOOD, true)


## The moonshine still: a hidden shack in the trees, a camouflage tarp
## over a copper pot still on a brick firebox, a thumper keg and worm tub,
## barrels, jars and a woodpile.
static func moonshine_still(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	_pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, MeshBuilder.glow(Color(0.36, 0.34, 0.22), MeshBuilder.GRASS))
	_pad(mb, -0.8, 0.8, -d * 0.5, 0.0, MeshBuilder.glow(DIRT, MeshBuilder.CONCRETE), 0.03)
	# Trees and brush round the edge.
	var ring := 10
	for i in ring:
		var a := TAU * i / ring + rng.randf_range(-0.15, 0.15)
		var p := Vector3(cos(a) * (w * 0.5 - 3.0), 0, sin(a) * (d * 0.5 - 3.0))
		if p.z < -d * 0.3 and absf(p.x) < 3.0:
			continue
		if i % 2 == 0:
			_bald_cypress(mb, out, p, rng)
		else:
			_bush(mb, p, rng.randf_range(1.2, 1.8), rng, Color(0.25, 0.36, 0.2))
	# The shack.
	var hx := -w * 0.2
	var hz := d * 0.2
	var plank := MeshBuilder.glow(OLD_WOOD.darkened(0.15), MeshBuilder.SIDING)
	_solid(mb, out, Vector3(hx, 1.3, hz), Vector3(5.0, 2.6, 4.0), plank)
	_gable(mb, hx, hz, 2.6, 5.6, 4.6, 0.9, MeshBuilder.glow(RUST, MeshBuilder.SEAM_ROOF), plank)
	mb.box(Vector3(hx + 1.0, 1.0, hz - 2.04), Vector3(0.9, 2.0, 0.08), WOOD.darkened(0.4))
	# Tarp lean-to over the still.
	var sx := w * 0.12
	var sz := d * 0.05
	for p: Vector3 in [Vector3(sx - 2.4, 0, sz - 2.0), Vector3(sx + 2.4, 0, sz - 2.0), Vector3(sx - 2.4, 0, sz + 2.0), Vector3(sx + 2.4, 0, sz + 2.0)]:
		mb.cylinder(p, 0.07, 2.4 if p.z < sz else 2.9, WOOD, 4)
	var camo := Color(0.33, 0.38, 0.22)
	mb.quad(Vector3(sx - 2.7, 2.35, sz - 2.3), Vector3(sx + 2.7, 2.35, sz - 2.3), Vector3(sx + 2.7, 2.9, sz + 2.3), Vector3(sx - 2.7, 2.9, sz + 2.3), Vector3(0, 4.6, -0.55).normalized(), camo)
	mb.box(Vector3(sx - 1.0, 2.6, sz), Vector3(1.6, 0.04, 2.0), camo.darkened(0.25))
	# The still.
	var copper := MeshBuilder.glow(COPPER, MeshBuilder.GLOSS)
	var fb := Vector3(sx - 1.0, 0, sz)
	mb.box(fb + Vector3(0, 0.4, 0), Vector3(1.4, 0.8, 1.4), MeshBuilder.glow(BRICKS[0], MeshBuilder.BRICK))
	mb.box(fb + Vector3(0, 0.3, -0.71), Vector3(0.6, 0.4, 0.04), MeshBuilder.glow(Color(1.0, 0.5, 0.15), MeshBuilder.GLOW_NEON))
	mb.cylinder(fb + Vector3(0, 0.8, 0), 0.65, 1.0, copper, 10)
	_cone(mb, fb + Vector3(0, 1.8, 0), 0.65, 0.45, copper, 10)
	mb.cylinder(fb + Vector3(0, 2.1, 0), 0.15, 0.25, copper, 6)
	var keg := fb + Vector3(1.5, 0, 0.2)
	mb.cylinder(keg, 0.4, 0.9, WOOD.lightened(0.1), 8)
	mb.limb(fb + Vector3(0, 2.3, 0), keg + Vector3(0, 1.0, 0), 0.06, 0.06, copper, 5)
	var tub := fb + Vector3(2.8, 0, 0.6)
	mb.cylinder(tub, 0.55, 1.1, WOOD.darkened(0.1), 8)
	mb.cylinder(tub + Vector3(0, 1.1, 0), 0.45, 0.01, Color(0.25, 0.3, 0.3), 8)
	mb.limb(keg + Vector3(0, 0.95, 0), tub + Vector3(0, 1.2, 0), 0.05, 0.05, copper, 5)
	for k in 3:
		mb.limb(tub + Vector3(-0.3, 1.15, -0.2 + k * 0.2), tub + Vector3(0.3, 1.15, -0.1 + k * 0.2), 0.04, 0.04, copper, 4)
	_col(out, fb + Vector3(1.3, 1.0, 0.2), Vector3(4.4, 2.0, 1.8))
	# Barrels, a crate of jars, the woodpile.
	for k in 4:
		Props.barrel(mb, out, Vector3(sx + 1.6, 0, sz + 2.8 + (k % 2) * 0.9) + Vector3((k / 2) * 0.9, 0, 0), Color(0.42, 0.28, 0.16))
	var crate := Vector3(sx - 2.0, 0, sz - 2.8)
	mb.box(crate + Vector3(0, 0.25, 0), Vector3(0.9, 0.5, 0.6), WOOD.lightened(0.15))
	for k in 6:
		mb.cylinder(crate + Vector3(-0.3 + (k % 3) * 0.3, 0.5, -0.12 + (k / 3) * 0.24), 0.09, 0.22, MeshBuilder.glow(Color(0.7, 0.8, 0.82), MeshBuilder.GLASS), 6)
	_col(out, crate + Vector3(0, 0.3, 0), Vector3(0.9, 0.6, 0.6))
	var wood := Vector3(hx - 3.6, 0, hz)
	_solid(mb, out, wood + Vector3(0, 0.55, 0), Vector3(0.9, 1.1, 2.6), Color(0.45, 0.32, 0.2))
	for k in 4:
		mb.box(wood + Vector3(-0.46, 0.2 + k * 0.25, -0.9 + (k % 2) * 0.5), Vector3(0.02, 0.22, 0.22), Color(0.75, 0.62, 0.42))


## Bellerive General: a four-storey glass-banded block with a seven-storey
## tower wing carrying a rooftop helipad, a drop-off canopy at the lobby,
## an ambulance bay with a red EMERGENCY band, a blue H sign and parking.
static func bellerive_general(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var bw := clampf(w * 0.6, 26.0, 60.0)
	var bd := clampf(d * 0.4, 12.0, 30.0)
	var fz := -d * 0.5 + clampf(d * 0.38, 14.0, 30.0)
	var x0 := -w * 0.5 + 3.0
	var cx := x0 + bw * 0.5
	var cz := fz + bd * 0.5
	const FH := 3.6
	var h1 := 4 * FH + 0.4
	var h2 := 7 * FH + 0.4
	var tw := clampf(w * 0.22, 11.0, 22.0)
	var tx1 := minf(x0 + bw - 2.0 + tw, w * 0.5 - 3.0)
	var tx0 := tx1 - tw
	var tz0 := fz - 2.0
	var td := clampf(d * 0.44, 12.0, 32.0)
	var tcx := (tx0 + tx1) * 0.5
	var tcz := tz0 + td * 0.5
	var white := MeshBuilder.glow(Color(0.92, 0.93, 0.92), MeshBuilder.CONCRETE)
	var blue := Color(0.16, 0.36, 0.62)
	var glass := MeshBuilder.glow(Color(0.38, 0.55, 0.66), MeshBuilder.GLASS)
	_pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, MeshBuilder.glow(LAWN, MeshBuilder.GRASS))
	_pad(mb, -w * 0.5 + 1.0, w * 0.5 - 1.0, -d * 0.5, minf(fz, tz0), MeshBuilder.glow(ASPHALT, MeshBuilder.ASPHALT), 0.04)
	# Main block with glass bands on every floor.
	_solid(mb, out, Vector3(cx, h1 * 0.5, cz), Vector3(bw, h1, bd), white)
	for f in 4:
		var y := 0.4 + f * FH + 1.8
		for z: float in [fz - 0.04, fz + bd + 0.04]:
			mb.box(Vector3(cx, y, z), Vector3(bw - 1.0, 1.6, 0.08), glass)
		mb.box(Vector3(x0 - 0.04, y, cz), Vector3(0.08, 1.6, bd - 1.0), glass)
	_flat_roof(mb, cx, cz, bw, bd, h1, rng, Color(0.7, 0.72, 0.74))
	# Tower wing.
	_solid(mb, out, Vector3(tcx, h2 * 0.5, tcz), Vector3(tw, h2, td), white)
	for f in 7:
		var y := 0.4 + f * FH + 1.8
		for z: float in [tz0 - 0.04, tz0 + td + 0.04]:
			mb.box(Vector3(tcx, y, z), Vector3(tw - 1.0, 1.6, 0.08), glass)
		for x: float in [tx0 - 0.04, tx1 + 0.04]:
			mb.box(Vector3(x, y, tcz), Vector3(0.08, 1.6, td - 1.0), glass)
	for x: float in [tx0 + 0.3, tx1 - 0.3]:
		mb.box(Vector3(x, h2 * 0.5, tz0 - 0.15), Vector3(0.6, h2, 0.3), blue)
	# Helipad: a raised deck with a yellow ring, a white H and corner lights.
	mb.box(Vector3(tcx, h2 + 0.25, tcz), Vector3(tw, 0.5, td), MeshBuilder.glow(Color(0.6, 0.62, 0.64), MeshBuilder.CONCRETE))
	var pr := minf(tw, td) * 0.5 - 1.0
	var top := h2 + 0.52
	var ring := MeshBuilder.glow(YELLOW, MeshBuilder.GLOSS)
	for i in 12:
		var a0 := TAU * i / 12.0
		var a1 := TAU * (i + 1) / 12.0
		_beam(mb, Vector3(tcx + cos(a0) * pr * 0.85, top, tcz + sin(a0) * pr * 0.85), Vector3(tcx + cos(a1) * pr * 0.85, top, tcz + sin(a1) * pr * 0.85), 0.03, ring, 0.5)
	var hs := pr * 0.45
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(tcx + s * hs * 0.4, top, tcz), Vector3(hs * 0.22, 0.03, hs * 1.3), WHITE)
	mb.box(Vector3(tcx, top, tcz), Vector3(hs * 0.8, 0.03, hs * 0.22), WHITE)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			mb.box(Vector3(tcx + sx * (tw * 0.5 - 0.4), top + 0.1, tcz + sz * (td * 0.5 - 0.4)), Vector3(0.3, 0.2, 0.3), MeshBuilder.glow(Color(0.3, 1.0, 0.4), MeshBuilder.GLOW_NEON))
	# Lobby with a drop-off canopy.
	var lx := cx - bw * 0.15
	mb.box(Vector3(lx, 2.0, fz - 0.5), Vector3(8.0, 4.0, 1.0), MeshBuilder.glow(Color(0.35, 0.45, 0.52), MeshBuilder.GLOW_WINDOW))
	_canopy(mb, out, lx - 6.0, lx + 6.0, fz - 7.0, fz - 1.0, 4.6, 0.5, blue, MeshBuilder.glow(Buildings.MEMBRANES[0], MeshBuilder.ROOF), [Vector3(lx - 5.6, 0, fz - 6.6), Vector3(lx + 5.6, 0, fz - 6.6)], WHITE)
	mb.box(Vector3(lx, 4.35, fz - 7.04), Vector3(8.0, 0.4, 0.04), MeshBuilder.glow(WHITE, MeshBuilder.GLOW_NEON))
	# Ambulance bay in front of the tower.
	var az0 := maxf(tz0 - 9.0, -d * 0.5 + 2.0)
	_canopy(mb, out, tx0 + 0.5, tx1 - 0.5, az0, tz0, 5.0, 0.7, WHITE, MeshBuilder.glow(Buildings.MEMBRANES[1], MeshBuilder.ROOF), [Vector3(tx0 + 0.8, 0, az0 + 0.3), Vector3(tx1 - 0.8, 0, az0 + 0.3)], WHITE)
	mb.box(Vector3(tcx, 4.65, az0 - 0.04), Vector3(tw - 2.0, 0.4, 0.04), MeshBuilder.glow(Color(1.0, 0.18, 0.12), MeshBuilder.GLOW_NEON))
	mb.box(Vector3(tcx, 1.6, tz0 - 0.06), Vector3(tw * 0.5, 3.2, 0.08), MeshBuilder.glow(Color(0.4, 0.5, 0.55), MeshBuilder.GLOW_WINDOW))
	var am := (tz0 + az0) * 0.5
	_ambulance(mb, out, Vector3(tcx - 2.0, 0, am), PI)
	if tw > 13.0:
		_ambulance(mb, out, Vector3(tcx + 2.4, 0, am), PI)
	_h_sign(mb, out, Vector3(x0 + 2.0, 0, -d * 0.5 + 1.8), 2.2)
	# Visitor parking along the front.
	var pz := -d * 0.5 + 1.5
	if fz - 7.0 - pz > 5.0:
		for seg: Vector2 in [Vector2(x0 + 4.0, lx - 7.0), Vector2(lx + 7.0, tx0 - 1.0)]:
			var n := int((seg.y - seg.x) / 2.7)
			if n < 2:
				continue
			_stalls(mb, seg.x, pz, n, 2.7, 5.5, 1.0)
			for i in n:
				if rng.randf() < 0.45:
					_car(mb, out, Vector3(seg.x + 1.35 + i * 2.7, 0, pz + 2.8), 0.0 if rng.randf() < 0.5 else PI, _pick(PAINTS, rng))
	# Trees along the sides and back.
	for k in 3:
		var oz := cz + bd * 0.5 + 4.5 + k * 6.0
		if oz < d * 0.5 - 4.5:
			Props.oak(mb, out, Vector3(-w * 0.5 + 4.5, 0, oz), rng)
	for k in 3:
		var x := lerpf(x0 + 4.0, tx0 - 2.0, (k + 0.5) / 3.0)
		if fz + bd + 3.0 < d * 0.5 - 1.5:
			Props.crepe_myrtle(mb, out, Vector3(x, 0, fz + bd + 3.0), rng)


## Bellerive bus terminal: a barrel-vaulted terminal hall with a glass front
## and a clock tower, a long platform canopy with angled coach bays, a taxi
## rank and parking along the street.
static func bus_terminal(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	_pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, MeshBuilder.glow(ASPHALT, MeshBuilder.ASPHALT))
	var tbw := clampf(w * 0.45, 18.0, 40.0)
	var tbd := clampf(d * 0.4, 12.0, 24.0)
	var tx0 := -w * 0.5 + 2.0
	var tx1 := tx0 + tbw
	var tz1 := d * 0.5 - 2.0
	var tz0 := tz1 - tbd
	var tcx := (tx0 + tx1) * 0.5
	var tcz := (tz0 + tz1) * 0.5
	const H := 6.0
	var wall := MeshBuilder.glow(Color(0.86, 0.84, 0.78), MeshBuilder.CONCRETE)
	var roof := MeshBuilder.glow(Color(0.42, 0.55, 0.6), MeshBuilder.SEAM_ROOF)
	_pad(mb, tx0 - 1.0, tx1 + 1.0, tz0 - 4.0, tz1, MeshBuilder.glow(Color(0.78, 0.74, 0.66), MeshBuilder.PAVING), 0.05)
	_solid(mb, out, Vector3(tcx, H * 0.5, tcz), Vector3(tbw, H, tbd), wall)
	_vault(mb, Vector3(tcx, 0, tcz), _arch(tbd * 0.5 + 0.4, clampf(tbd * 0.22, 2.5, 5.0), H, 7), tbw + 0.6, true, roof, wall)
	mb.box(Vector3(tcx, 2.6, tz0 - 0.05), Vector3(tbw - 2.0, 4.2, 0.08), MeshBuilder.glow(Color(0.42, 0.55, 0.62), MeshBuilder.GLOW_WINDOW))
	for k in int(tbw / 3.0) + 1:
		mb.box(Vector3(tx0 + 1.0 + k * (tbw - 2.0) / int(tbw / 3.0), 2.6, tz0 - 0.1), Vector3(0.18, 4.2, 0.12), DARK)
	mb.box(Vector3(tcx, 5.2, tz0 - 0.12), Vector3(tbw - 4.0, 0.7, 0.1), MeshBuilder.glow(Color(0.35, 0.8, 1.0), MeshBuilder.GLOW_NEON))
	_all_windows(mb, tx0, tx1, tz0, tz1, 0.0, 1, 5.0, 3.0, Vector2(1.6, 1.4), rng, 0.6, true)
	# Clock tower at the front corner.
	var ck := Vector3(tx1 - 1.5, 0, tz0 - 1.5)
	_solid(mb, out, ck + Vector3(0, 5.5, 0), Vector3(2.4, 11.0, 2.4), MeshBuilder.glow(Color(0.8, 0.76, 0.68), MeshBuilder.BRICK))
	mb.box(ck + Vector3(0, 11.2, 0), Vector3(2.8, 0.4, 2.8), DARK)
	for f: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		var c := ck + Vector3(0, 9.4, 0) + f * 1.22
		var flat := Vector3(1.6, 1.6, 0.06) if absf(f.z) > 0.5 else Vector3(0.06, 1.6, 1.6)
		mb.box(c, flat, MeshBuilder.glow(Color(0.98, 0.95, 0.85), MeshBuilder.GLOW_LAMP))
		mb.box(c + f * 0.04 + Vector3(0, 0.3, 0), Vector3(0.08, 0.6, 0.08), DARK)
		var hand := Vector3(0.5, 0.08, 0.08) if absf(f.z) > 0.5 else Vector3(0.08, 0.08, 0.5)
		mb.box(c + f * 0.04 + (Vector3(0.22, 0, 0) if absf(f.z) > 0.5 else Vector3(0, 0, 0.22)), hand, DARK)
	_cone(mb, ck + Vector3(0, 11.4, 0), 1.6, 2.0, MeshBuilder.glow(Color(0.42, 0.55, 0.6), MeshBuilder.SEAM_ROOF), 4)
	# Platform island under a long canopy, with angled coach bays in front.
	var px0 := tx1 + 4.0
	var px1 := w * 0.5 - 2.0
	var pz1 := d * 0.5 - 2.0
	var pz0 := pz1 - clampf(d * 0.12, 5.0, 8.0)
	_solid(mb, out, Vector3((px0 + px1) * 0.5, 0.1, (pz0 + pz1) * 0.5), Vector3(px1 - px0, 0.2, pz1 - pz0), MeshBuilder.glow(CONCRETE, MeshBuilder.CONCRETE))
	mb.box(Vector3((px0 + px1) * 0.5, 0.22, pz0 + 0.2), Vector3(px1 - px0, 0.02, 0.3), YELLOW)
	var posts: Array = []
	var np := maxi(2, int((px1 - px0) / 8.0) + 1)
	for i in np:
		posts.append(Vector3(px0 + 1.0 + (px1 - px0 - 2.0) * i / (np - 1), 0, (pz0 + pz1) * 0.5))
	_canopy(mb, out, px0 - 0.5, px1 + 0.5, pz0 - 2.0, pz1 + 0.3 if pz1 + 0.3 < d * 0.5 else pz1, 4.5, 0.4, Color(0.42, 0.55, 0.6), MeshBuilder.glow(Color(0.85, 0.88, 0.9), MeshBuilder.ROOF), posts, Color(0.25, 0.3, 0.35))
	for i in np - 1:
		var x := lerpf(posts[i].x, posts[i + 1].x, 0.5)
		Props.bench(mb, out, Vector3(x, 0.2, pz1 - 1.2), PI)
	var bays := clampi(int((px1 - px0) / 7.0), 2, 6)
	var colors := [Color(0.15, 0.4, 0.7), Color(0.85, 0.3, 0.2), Color(0.2, 0.55, 0.4)]
	var parked := 0
	for i in bays:
		var bx := px0 + 3.5 + (px1 - px0 - 7.0) * i / maxf(1.0, bays - 1)
		# Bay axis u runs from the platform back along the coach; v across it.
		var u := Vector3(sin(0.5), 0, -cos(0.5))
		var v := Vector3(cos(0.5), 0, sin(0.5))
		var c := Vector3(bx, 0, pz0 - 0.6 - cos(0.5) * 6.0)
		for s: float in [-1.0, 1.0]:
			_line(mb, c - u * 6.0 + v * s * 1.9, c + u * 6.0 + v * s * 1.9, 0.15)
		if parked < 3 and (i % 2 == 0 or rng.randf() < 0.3):
			parked += 1
			_bus(mb, out, c, PI - 0.5, colors[(i + rng.randi()) % colors.size()])
	# Taxi rank by the terminal front, a pylon sign at the street.
	var rz := tz0 - 6.0
	_line(mb, Vector3(tx0 + 2.0, 0, rz - 1.4), Vector3(tx0 + 16.0, 0, rz - 1.4), 0.15, YELLOW)
	for k in 2:
		var tp := Vector3(tx0 + 4.5 + k * 5.5, 0, rz)
		_car(mb, out, tp, PI * 0.5, Color(0.98, 0.78, 0.15))
		mb.box(tp + Vector3(0, 1.55, 0), Vector3(0.3, 0.2, 0.7), MeshBuilder.glow(Color(1.0, 0.95, 0.6), MeshBuilder.GLOW_NEON))
	_pylon(mb, out, Vector3(tx0 + 1.5, 0, rz + 1.0), 3.2, Vector2(1.6, 1.0), Color(0.15, 0.15, 0.15), Color(1.0, 0.85, 0.2))
	_pylon(mb, out, Vector3(-w * 0.5 + 2.0, 0, -d * 0.5 + 2.0), 6.5, Vector2(3.4, 2.0), Color(0.42, 0.55, 0.6), Color(0.35, 0.8, 1.0))
	# Street-side parking row.
	var sx0 := -w * 0.5 + 6.0
	var n := clampi(int((w * 0.5 - 6.0 - sx0) / 2.7), 2, 20)
	var sz := -d * 0.5 + 1.5
	var limit := minf(tz0 - 7.5, pz0 - 12.5)
	var used := sz
	if limit - sz > 5.5:
		_stalls(mb, sx0, sz, n, 2.7, 5.5, 1.0)
		used = sz + 5.5
		for i in n:
			if rng.randf() < 0.35:
				_car(mb, out, Vector3(sx0 + 1.35 + i * 2.7, 0, sz + 2.8), 0.0, _pick(PAINTS, rng))
		# A second row across the aisle, facing the first.
		var sz2 := sz + 12.0
		if limit - sz2 > 1.0:
			_stalls(mb, sx0, sz2, n, 2.7, 5.5, 1.0)
			used = sz2 + 5.5
			for i in n:
				if rng.randf() < 0.3:
					_car(mb, out, Vector3(sx0 + 1.35 + i * 2.7, 0, sz2 + 2.8), PI, _pick(PAINTS, rng))
	# A planted island between the car park and the coach apron.
	if limit - used > 6.0:
		var mz := (used + limit) * 0.5
		_pad(mb, -w * 0.5 + 8.0, w * 0.5 - 8.0, mz - 1.5, mz + 1.5, MeshBuilder.glow(LAWN, MeshBuilder.GRASS), 0.12)
		mb.box(Vector3(0, 0.06, mz), Vector3(w - 16.0, 0.12, 3.2), MeshBuilder.glow(CONCRETE, MeshBuilder.CONCRETE))
		var np2 := clampi(int((w - 16.0) / 16.0), 2, 4)
		for k in np2:
			Props.palm(mb, out, Vector3(lerpf(-w * 0.5 + 10.0, w * 0.5 - 10.0, (k + 0.5) / np2), 0.12, mz), rng)
	for k in 3:
		Props.palm(mb, out, Vector3(lerpf(tx0 + 2.0, tx1 - 3.0, k / 2.0), 0, tz0 - 3.0), rng)


## Seaplane base: a quonset hangar open to the water on a concrete ramp, a
## finger pier with a moored floatplane, an office hut, a fuel point and a
## windsock; land at the street, water out the back (+Z).
static func seaplane_base(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var wz0 := -d * 0.5 + d * 0.45
	_pad(mb, -w * 0.5, w * 0.5, -d * 0.5, wz0, MeshBuilder.glow(CONCRETE, MeshBuilder.CONCRETE))
	_pad(mb, -w * 0.5, w * 0.5, wz0, d * 0.5, MeshBuilder.glow(Color(0.2, 0.42, 0.48), MeshBuilder.GLASS), 0.03)
	mb.box(Vector3(0, 0.15, wz0), Vector3(w, 0.3, 0.6), MeshBuilder.glow(CONCRETE.darkened(0.15), MeshBuilder.CONCRETE))
	_line(mb, Vector3(-w * 0.5 + 0.5, 0, wz0 - 0.5), Vector3(w * 0.5 - 0.5, 0, wz0 - 0.5), 0.2, YELLOW)
	# Quonset hangar, open toward the water.
	var hw := clampf(w * 0.38, 13.0, 24.0)
	var hd := clampf(d * 0.32, 10.0, 18.0)
	var hx := -w * 0.5 + 2.0 + hw * 0.5
	var hz := wz0 - hd * 0.5
	var galv := MeshBuilder.glow(Color(0.72, 0.74, 0.76), MeshBuilder.SEAM_ROOF)
	var prof := _arch(hw * 0.5, hw * 0.45, 0.0, 8)
	_vault(mb, Vector3(hx, 0, hz), prof, hd, false, galv, galv, false)
	var idx := Geometry2D.triangulate_polygon(prof)
	var end := MeshBuilder.glow(Color(0.85, 0.83, 0.78), MeshBuilder.SIDING)
	for t in range(0, idx.size(), 3):
		var a := prof[idx[t]]
		var b := prof[idx[t + 1]]
		var c := prof[idx[t + 2]]
		var z := hz - hd * 0.5
		mb.tri(Vector3(hx + a.x, a.y, z), Vector3(hx + b.x, b.y, z), Vector3(hx + c.x, c.y, z), Vector3.FORWARD, end)
	mb.box(Vector3(hx, 1.2, hz - hd * 0.5 - 0.05), Vector3(2.0, 2.4, 0.06), DARK)
	mb.box(Vector3(hx, hw * 0.3, hz - hd * 0.5 - 0.05), Vector3(hw * 0.4, 0.8, 0.06), MeshBuilder.glow(Color(0.3, 0.8, 1.0), MeshBuilder.GLOW_NEON))
	_col(out, Vector3(hx, 2.0, hz - hd * 0.5 + 0.2), Vector3(hw, 4.0, 0.4))
	for s: float in [-1.0, 1.0]:
		_col(out, Vector3(hx + s * (hw * 0.5 - 0.6), 1.5, hz), Vector3(1.2, 3.0, hd))
	# Ramp into the water and a floatplane on it, nose out.
	var rz1 := minf(wz0 + 8.0, d * 0.5 - 0.5)
	mb.box(Vector3(hx, 0.03, (wz0 + rz1) * 0.5), Vector3(hw * 0.6, 0.04, rz1 - wz0), MeshBuilder.glow(CONCRETE.darkened(0.25), MeshBuilder.CONCRETE))
	var pl := clampf(hw * 0.5, 7.0, 10.0)
	var pz := minf(wz0 + pl * 0.65, d * 0.5 - pl * 0.5 - 0.5)
	_plane(mb, Vector3(hx, 0, pz), PI, pl, Color(0.2, 0.55, 0.62), WHITE, true, true)
	_col(out, Vector3(hx, 1.4, pz), Vector3(pl * 0.5, 2.8, pl))
	# Finger pier with a moored floatplane.
	var fx := clampf(w * 0.18, hx + hw * 0.5 + 6.0, w * 0.5 - 8.0)
	var fl := d * 0.5 - 1.0 - wz0
	var deck := MeshBuilder.glow(OLD_WOOD.lightened(0.15), MeshBuilder.SIDING)
	mb.box(Vector3(fx, 0.45, wz0 + fl * 0.5), Vector3(2.4, 0.14, fl), deck)
	for t: float in [0.15, 0.5, 0.85]:
		for s: float in [-1.0, 1.0]:
			mb.cylinder(Vector3(fx + s * 1.3, 0, wz0 + fl * t), 0.13, 1.2, Color(0.3, 0.26, 0.22), 5)
	var pl2 := clampf(w * 0.15, 8.0, 10.0)
	var px := fx - 2.0 - pl2 * 0.2
	_plane(mb, Vector3(px, 0, wz0 + fl * 0.55), PI, pl2, Color(0.95, 0.75, 0.2), Color(0.6, 0.15, 0.12), true, true)
	_col(out, Vector3(px, 1.4, wz0 + fl * 0.55), Vector3(pl2 * 0.5, 2.8, pl2))
	mb.box(Vector3(fx + 0.8, 0.9, wz0 + 1.2), Vector3(0.6, 0.8, 0.6), MeshBuilder.glow(Color(0.85, 0.2, 0.15), MeshBuilder.GLOSS))
	# Office hut and windsock on the land side.
	var ox := w * 0.5 - 6.0
	var oz := wz0 - 6.0
	var hut := MeshBuilder.glow(Color(0.62, 0.78, 0.82), MeshBuilder.SIDING)
	_solid(mb, out, Vector3(ox, 1.5, oz), Vector3(7.0, 3.0, 5.0), hut)
	_gable(mb, ox, oz, 3.0, 7.6, 5.6, 1.2, MeshBuilder.glow(Color(0.85, 0.3, 0.2), MeshBuilder.SEAM_ROOF), hut)
	_windows(mb, Vector3(ox - 3.5, 1.7, oz - 2.5), Vector3(ox + 3.5, 1.7, oz - 2.5), 3, Vector2(1.2, 1.0), rng, Vector3.FORWARD, 0.6)
	_windows(mb, Vector3(ox - 3.5, 1.7, oz + 2.5), Vector3(ox + 3.5, 1.7, oz + 2.5), 2, Vector2(1.4, 1.0), rng, Vector3.BACK, 0.6)
	var wp := Vector3(w * 0.5 - 1.5, 0, wz0 - 1.5)
	mb.cylinder(wp, 0.06, 6.0, WHITE, 4)
	_col(out, wp + Vector3(0, 1.0, 0), Vector3(0.3, 2.0, 0.3))
	for k in 4:
		var r := 0.45 - k * 0.08
		mb.limb(wp + Vector3(-0.1 - k * 0.5, 5.8 - k * 0.1, 0), wp + Vector3(-0.6 - k * 0.5, 5.75 - k * 0.12, 0), r, r - 0.06, Color(1.0, 0.45, 0.1) if k % 2 == 0 else WHITE, 6, false)
	# Bollards along the shore, a couple of cars at the street.
	for k in int(w / 8.0):
		var x := -w * 0.5 + 4.0 + k * 8.0
		if absf(x - hx) > hw * 0.35 and absf(x - fx) > 2.0:
			mb.cylinder(Vector3(x, 0.3, wz0 - 0.1), 0.22, 0.5, DARK, 6)
	for k in 2:
		_car(mb, out, Vector3(w * 0.5 - 4.0 - k * 3.0, 0, -d * 0.5 + 3.5), 0.0, _pick(PAINTS, rng))


## Bellerive cruise terminal: a long two-storey hall under a white vaulted
## roof with a glass band and fins, an entrance canopy, coaches at the
## street, and gangway towers with boarding arms on the quay (+Z).
static func cruise_terminal(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	_pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, MeshBuilder.glow(CONCRETE, MeshBuilder.CONCRETE))
	var qa := clampf(d * 0.22, 7.0, 12.0)
	var tw := clampf(w * 0.7, 40.0, 96.0)
	var td := clampf(d * 0.38, 12.0, 24.0)
	var tz1 := d * 0.5 - qa
	var tz0 := tz1 - td
	var cz := (tz0 + tz1) * 0.5
	const H := 9.0
	var white := MeshBuilder.glow(Color(0.94, 0.94, 0.92), MeshBuilder.CONCRETE)
	var teal := Color(0.1, 0.5, 0.6)
	_solid(mb, out, Vector3(0, H * 0.5, cz), Vector3(tw, H, td), white)
	var rise := clampf(td * 0.18, 2.0, 4.5)
	_vault(mb, Vector3(0, 0, cz), _arch(td * 0.5 + 0.6, rise, H, 7), tw + 1.0, true, MeshBuilder.glow(Color(0.96, 0.96, 0.95), MeshBuilder.ROOF), white)
	mb.box(Vector3(0, H + rise + 0.04, cz), Vector3(tw + 1.0, 0.1, 1.6), MeshBuilder.glow(teal, MeshBuilder.GLOSS))
	_pad(mb, -w * 0.5 + 0.5, w * 0.5 - 0.5, -d * 0.5 + 0.5, tz0 - 1.0, MeshBuilder.glow(ASPHALT, MeshBuilder.ASPHALT), 0.04)
	var glass := MeshBuilder.glow(Color(0.3, 0.55, 0.65), MeshBuilder.GLASS)
	for z: float in [tz0 - 0.05, tz1 + 0.05]:
		mb.box(Vector3(0, 6.0, z), Vector3(tw - 2.0, 3.6, 0.08), glass)
		mb.box(Vector3(0, 2.0, z), Vector3(tw - 2.0, 2.6, 0.08), MeshBuilder.glow(Color(0.4, 0.52, 0.58), MeshBuilder.GLOW_WINDOW))
	var nf := int(tw / 4.0)
	for k in nf + 1:
		mb.box(Vector3(-tw * 0.5 + 0.3 + k * (tw - 0.6) / nf, H * 0.5, tz0 - 0.35), Vector3(0.3, H, 0.7), MeshBuilder.glow(teal, MeshBuilder.GLOSS))
	mb.box(Vector3(0, H - 0.3, tz0 - 0.75), Vector3(tw * 0.4, 0.5, 0.06), MeshBuilder.glow(Color(0.3, 0.85, 1.0), MeshBuilder.GLOW_NEON))
	# Entrance canopy.
	var ez0 := maxf(tz0 - 8.0, -d * 0.5 + 4.0)
	_canopy(mb, out, -tw * 0.15, tw * 0.15, ez0, tz0 - 0.8, 5.0, 0.6, teal, MeshBuilder.glow(Color(0.9, 0.92, 0.94), MeshBuilder.ROOF), [Vector3(-tw * 0.15 + 0.5, 0, ez0 + 0.5), Vector3(0, 0, ez0 + 0.5), Vector3(tw * 0.15 - 0.5, 0, ez0 + 0.5)], WHITE)
	# Quay apron: edge line, bollards, gangway towers with bridges.
	_line(mb, Vector3(-w * 0.5 + 0.5, 0, d * 0.5 - 0.8), Vector3(w * 0.5 - 0.5, 0, d * 0.5 - 0.8), 0.25, YELLOW)
	for k in int(w / 10.0):
		var x := -w * 0.5 + 5.0 + k * 10.0
		mb.cylinder(Vector3(x, 0, d * 0.5 - 0.5), 0.28, 0.7, DARK, 6)
		_col(out, Vector3(x, 0.35, d * 0.5 - 0.5), Vector3(0.6, 0.7, 0.6))
	var steel := MeshBuilder.glow(Color(0.82, 0.84, 0.86), MeshBuilder.METAL)
	for s: float in [-1.0, 1.0]:
		var gx := s * tw * 0.25
		var gz := d * 0.5 - qa * 0.45
		_solid(mb, out, Vector3(gx, 6.0, gz), Vector3(3.0, 12.0, 3.0), MeshBuilder.glow(teal, MeshBuilder.SIDING))
		mb.box(Vector3(gx, 12.2, gz), Vector3(3.4, 0.4, 3.4), DARK)
		mb.box(Vector3(gx, 8.0, (tz1 + gz - 1.5) * 0.5), Vector3(2.6, 2.6, gz - 1.5 - tz1), steel)
		mb.box(Vector3(gx, 8.0, (tz1 + gz - 1.5) * 0.5), Vector3(2.66, 0.8, gz - 1.5 - tz1), glass)
		mb.box(Vector3(gx + s * 0.0, 8.0, (gz + 1.5 + d * 0.5 - 0.3) * 0.5), Vector3(2.4, 2.4, d * 0.5 - 0.3 - gz - 1.5), steel)
		for k in 2:
			_beam(mb, Vector3(gx - 1.0 + k * 2.0, 0, gz + 1.2), Vector3(gx - 1.0 + k * 2.0, 6.8, gz + 2.2), 0.25, DARK)
	# Baggage carts on the apron.
	for k in 3:
		var bx := -tw * 0.05 + k * 3.0
		mb.box(Vector3(bx, 0.8, tz1 + qa * 0.5), Vector3(2.0, 1.0, 1.2), MeshBuilder.glow(Color(0.25, 0.3, 0.38), MeshBuilder.METAL))
		_col(out, Vector3(bx, 0.6, tz1 + qa * 0.5), Vector3(2.0, 1.2, 1.2))
	# Coaches at the kerb, palms along the street.
	var bz := -d * 0.5 + 3.0
	if ez0 - bz > 3.0:
		var nb := clampi(int(w / 30.0), 1, 4)
		for i in nb:
			var bx := -w * 0.5 + 10.0 + i * 15.0
			if bx + 6.0 < -tw * 0.15 - 1.0:
				_bus(mb, out, Vector3(bx, 0, bz), PI * 0.5, [Color(0.1, 0.45, 0.6), Color(0.85, 0.5, 0.2)][i % 2])
		_stalls(mb, tw * 0.15 + 3.0, -d * 0.5 + 1.0, clampi(int((w * 0.5 - tw * 0.15 - 5.0) / 2.7), 2, 14), 2.7, 5.5, 1.0)
	for k in int(w / 14.0):
		var x := -w * 0.5 + 7.0 + k * 14.0
		if absf(x) > tw * 0.15 + 1.0:
			Props.palm(mb, out, Vector3(x, 0, tz0 - 2.5 if tz0 - 2.5 > ez0 else ez0), rng)


## Torque & Tone: a charcoal custom-car shop with neon stripes, three roll-up
## doors (one open, a car up on the lift), a glass showroom corner, a car on a
## turntable out front, a "T&T" neon logo on the roof and a boat lean-to.
static func torque_tone(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	_pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, MeshBuilder.glow(ASPHALT, MeshBuilder.ASPHALT))
	var bw := clampf(w * 0.7, 18.0, 34.0)
	var bd := clampf(d * 0.45, 11.0, 20.0)
	var fz := -d * 0.5 + clampf(d * 0.35, 8.0, 14.0)
	var x0 := -w * 0.5 + 2.0
	var x1 := x0 + bw
	var cx := (x0 + x1) * 0.5
	var cz := fz + bd * 0.5
	const H := 6.0
	var pink := MeshBuilder.glow(Color(1.0, 0.25, 0.6), MeshBuilder.GLOW_NEON)
	var cyan := MeshBuilder.glow(Color(0.2, 0.9, 1.0), MeshBuilder.GLOW_NEON)
	_solid(mb, out, Vector3(cx, H * 0.5, cz), Vector3(bw, H, bd), MeshBuilder.glow(Color(0.17, 0.17, 0.19), MeshBuilder.SIDING))
	_flat_roof(mb, cx, cz, bw, bd, H, rng, Color(0.12, 0.12, 0.14), true)
	mb.box(Vector3(cx, H + 0.05, cz), Vector3(bw - 0.5, 0.02, bd - 0.5), MeshBuilder.glow(Color(0.2, 0.2, 0.22), MeshBuilder.ROOF))
	for z: float in [fz - 0.06]:
		mb.box(Vector3(cx, H - 0.6, z), Vector3(bw, 0.18, 0.06), pink)
		mb.box(Vector3(cx, H - 0.95, z), Vector3(bw, 0.1, 0.06), cyan)
	for x: float in [x0 - 0.06, x1 + 0.06]:
		mb.box(Vector3(x, H - 0.6, cz), Vector3(0.06, 0.18, bd), pink)
	# Showroom: the right end is glass on the front and side.
	var sw := clampf(bw * 0.28, 5.0, 9.0)
	var glass := MeshBuilder.glow(Color(0.35, 0.5, 0.6), MeshBuilder.GLOW_WINDOW)
	mb.box(Vector3(x1 - sw * 0.5, 2.4, fz - 0.06), Vector3(sw - 0.4, 4.0, 0.08), glass)
	mb.box(Vector3(x1 + 0.06, 2.4, fz + sw * 0.5), Vector3(0.08, 4.0, sw - 0.4), glass)
	# Roll-up doors.
	var dw := 3.6
	var span := bw - sw - 1.0
	for i in 3:
		var dx := x0 + span * (i + 0.5) / 3.0
		if i == 1:
			mb.box(Vector3(dx, 2.0, fz - 0.06), Vector3(dw, 4.0, 0.08), MeshBuilder.glow(Color(0.85, 0.75, 0.55), MeshBuilder.GLOW_WINDOW))
			for s: float in [-1.0, 1.0]:
				mb.box(Vector3(dx + s * 1.3, 1.2, fz + 0.6), Vector3(0.25, 2.4, 0.25), MeshBuilder.glow(Color(0.9, 0.75, 0.1), MeshBuilder.GLOSS))
			_car(mb, out, Vector3(dx, 1.5, fz + 2.6), 0.0, _pick(NEONS, rng), false)
			mb.box(Vector3(dx, 4.2, fz - 0.08), Vector3(dw + 0.3, 0.4, 0.1), DARK)
		else:
			mb.box(Vector3(dx, 2.0, fz - 0.06), Vector3(dw, 4.0, 0.08), MeshBuilder.glow(Color(0.55, 0.57, 0.6), MeshBuilder.SIDING))
	# Roof logo "T&T": two neon T's with a diamond between, readable from above.
	var ly := H + 0.1
	var lz := cz - bd * 0.22
	var ls := clampf(bw * 0.12, 2.2, 3.6)
	for s: float in [-1.0, 1.0]:
		var tx := cx + s * ls * 1.1
		mb.box(Vector3(tx, ly, lz + ls * 0.45), Vector3(ls, 0.08, ls * 0.22), pink)
		mb.box(Vector3(tx, ly, lz - ls * 0.05), Vector3(ls * 0.22, 0.08, ls * 0.8), pink)
	var dsz := ls * 0.3
	var corners := [Vector3(cx, ly, lz - dsz), Vector3(cx + dsz, ly, lz), Vector3(cx, ly, lz + dsz), Vector3(cx - dsz, ly, lz)]
	for k in 4:
		_beam(mb, corners[k], corners[(k + 1) % 4], 0.08, cyan, 0.2)
	# Turntable with a display car out front of the showroom.
	var tt := Vector3(minf(x1 - sw * 0.5, w * 0.5 - 3.4), 0, fz - 3.4)
	mb.cylinder(tt, 2.9, 0.22, MeshBuilder.glow(STEEL, MeshBuilder.METAL), 12)
	mb.cylinder(tt, 3.2, 0.1, cyan, 12)
	_car(mb, out, tt + Vector3(0, 0.22, 0), 0.6 + rng.randf() * 0.4, Color(0.9, 0.72, 0.2))
	# Pylon sign at the street corner.
	_pylon(mb, out, Vector3(-w * 0.5 + 1.8, 0, -d * 0.5 + 1.8), 5.5, Vector2(3.0, 1.6), Color(0.12, 0.12, 0.14), Color(1.0, 0.25, 0.6))
	# Customer parking in front of the doors.
	var n := clampi(int(span / 2.8), 2, 8)
	if fz - 1.0 - 5.5 > -d * 0.5 + 0.5:
		_stalls(mb, x0 + 0.5, fz - 1.0, n, 2.8, 5.0, -1.0)
		for i in n:
			if i != 1 and i != 2 and rng.randf() < 0.5:
				_car(mb, out, Vector3(x0 + 0.5 + 1.4 + i * 2.8, 0, fz - 3.6), PI, _pick(NEONS, rng))
	# Boat-shop lean-to on the right side with a speedboat on a trailer.
	var lx0 := x1 + 0.5
	var lx1 := w * 0.5 - 1.0
	if lx1 - lx0 > 3.5:
		var lz0 := fz + 1.0
		var lz1 := minf(fz + bd, d * 0.5 - 1.0)
		var mid := (lz0 + lz1) * 0.5
		_beam(mb, Vector3(lx0, 4.6, mid), Vector3(lx1, 3.4, mid), 0.15, MeshBuilder.glow(TIN, MeshBuilder.SEAM_ROOF), lz1 - lz0)
		for z: float in [lz0 + 0.3, lz1 - 0.3]:
			_post(mb, out, Vector3(lx1 - 0.3, 0, z), 3.4, 0.25, STEEL)
		var bl := clampf(lz1 - lz0 - 1.0, 5.0, 7.5)
		var bp := Vector3((lx0 + lx1) * 0.5, 0.7, mid)
		mb.box(Vector3(bp.x, 0.45, mid), Vector3(0.6, 0.1, bl), DARK)
		for s: float in [-1.0, 1.0]:
			_wheel(mb, Vector3(bp.x + s * 0.9, 0.35, mid + bl * 0.15), 0.35, 0.2)
		_boat(mb, bp, 0.0, bl, Color(0.85, 0.15, 0.4))
		_col(out, Vector3(bp.x, 0.9, mid), Vector3(minf(bl * 0.4, lx1 - lx0), 1.8, bl))


## A business jet: low swept wings, rear engines, a T-tail; nose toward -Z
## before yaw. No collider (the caller adds one).
static func _jet(mb, p: Vector3, yaw: float, length: float, color: Color, stripe: Color) -> void:
	var saved: Transform3D = mb.xform
	mb.xform = saved * Transform3D(Basis(Vector3.UP, yaw), p)
	var paint := MeshBuilder.glow(color, MeshBuilder.GLOSS)
	var r := length * 0.065
	var y := 1.2 + r
	mb.limb(Vector3(0, y - r * 0.2, -length * 0.5), Vector3(0, y, -length * 0.32), r * 0.25, r, paint, 8)
	mb.limb(Vector3(0, y, -length * 0.32), Vector3(0, y + r * 0.2, length * 0.32), r, r, paint, 8)
	mb.limb(Vector3(0, y + r * 0.2, length * 0.32), Vector3(0, y + r * 0.5, length * 0.5), r, r * 0.3, paint, 8)
	mb.box(Vector3(0, y + r * 0.45, -length * 0.38), Vector3(r * 1.2, r * 0.5, length * 0.06), MeshBuilder.glow(Color(0.15, 0.2, 0.25), MeshBuilder.GLASS))
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(s * r * 0.98, y + r * 0.2, -length * 0.02), Vector3(0.04, r * 0.35, length * 0.4), MeshBuilder.glow(Color(0.15, 0.2, 0.25), MeshBuilder.GLASS))
		mb.box(Vector3(s * r * 0.99, y - r * 0.3, 0), Vector3(0.04, r * 0.15, length * 0.7), stripe)
		# Swept wing, low on the fuselage.
		_beam(mb, Vector3(s * r * 0.5, y - r * 0.6, -length * 0.06), Vector3(s * length * 0.5, y - r * 0.2, length * 0.12), 0.18, paint, length * 0.13)
		mb.box(Vector3(s * length * 0.5, y + 0.1, length * 0.12), Vector3(0.1, 0.5, 0.7), stripe)
		# Engine pod on a pylon at the rear.
		mb.limb(Vector3(s * r * 1.9, y + r * 0.4, length * 0.18), Vector3(s * r * 1.9, y + r * 0.4, length * 0.34), r * 0.45, r * 0.4, MeshBuilder.glow(Color(0.8, 0.8, 0.82), MeshBuilder.METAL), 8)
		mb.box(Vector3(s * r * 1.35, y + r * 0.4, length * 0.26), Vector3(r * 0.8, 0.12, length * 0.06), paint)
		# Horizontal tail on top of the fin.
		_beam(mb, Vector3(0, y + r * 3.2, length * 0.44), Vector3(s * length * 0.16, y + r * 3.3, length * 0.5), 0.12, paint, length * 0.08)
		_wheel(mb, Vector3(s * r * 1.6, 0.35, length * 0.04), 0.35, 0.2)
	_beam(mb, Vector3(0, y + r * 0.6, length * 0.34), Vector3(0, y + r * 3.3, length * 0.46), length * 0.08, paint, 0.14)
	_beam(mb, Vector3(0, y + r * 1.0, length * 0.36), Vector3(0, y + r * 3.0, length * 0.45), length * 0.03, stripe, 0.16)
	mb.box(Vector3(0, 0.6, -length * 0.36), Vector3(0.08, 1.0, 0.08), DARK)
	_wheel(mb, Vector3(0, 0.28, -length * 0.36), 0.28, 0.16)
	mb.xform = saved


## Aurum private aviation: a graphite flat-roofed hangar with a glass door
## wall, gold fins and band and a gold "A" across the roof, a glazed office
## annex, an apron with a yellow taxi line and a business jet, and a gated
## entrance with a gatehouse and barrier arm.
static func aurum_hangar(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	_pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, MeshBuilder.glow(CONCRETE.darkened(0.18), MeshBuilder.CONCRETE))
	var hw := clampf(w * 0.55, 24.0, 44.0)
	var hd := clampf(d * 0.42, 16.0, 30.0)
	var hx0 := -w * 0.5 + 2.0
	var hx1 := hx0 + hw
	var hz1 := d * 0.5 - 2.0
	var hz0 := hz1 - hd
	var hcx := (hx0 + hx1) * 0.5
	var hcz := (hz0 + hz1) * 0.5
	const H := 11.0
	var graphite := MeshBuilder.glow(Color(0.2, 0.21, 0.23), MeshBuilder.SIDING)
	var gold := MeshBuilder.glow(GOLD, MeshBuilder.GLOSS)
	# Hangar: back and side walls collide; the door wall is a glass curtain.
	_solid(mb, out, Vector3(hcx, H * 0.5, hz1 - 0.3), Vector3(hw, H, 0.6), graphite)
	for s: float in [-1.0, 1.0]:
		_solid(mb, out, Vector3(hcx + s * (hw * 0.5 - 0.3), H * 0.5, hcz), Vector3(0.6, H, hd), graphite)
	mb.box(Vector3(hcx, H - 0.8, hz0 + 0.3), Vector3(hw, 1.6, 0.6), graphite)
	mb.box(Vector3(hcx, (H - 1.6) * 0.5, hz0 + 0.3), Vector3(hw - 1.2, H - 1.6, 0.1), MeshBuilder.glow(Color(0.25, 0.32, 0.38), MeshBuilder.GLASS))
	_col(out, Vector3(hcx, (H - 1.6) * 0.5, hz0 + 0.3), Vector3(hw - 1.2, H - 1.6, 0.4))
	mb.box(Vector3(hcx, H, hcz), Vector3(hw, 0.2, hd), MeshBuilder.glow(Color(0.26, 0.27, 0.29), MeshBuilder.ROOF))
	mb.box(Vector3(hcx, H - 0.4, hz0 - 0.04), Vector3(hw + 0.2, 0.5, 0.08), gold)
	var nf := int(hw / 5.0)
	for k in nf + 1:
		mb.box(Vector3(hx0 + 0.3 + k * (hw - 0.6) / nf, (H - 1.6) * 0.5, hz0 + 0.15), Vector3(0.25, H - 1.6, 0.3), gold)
	# The gold "A" lying on the roof, apex toward the back.
	var ay := H + 0.12
	var ah := hd * 0.6
	var ab := hw * 0.24
	var apex := Vector3(hcx, ay, hcz + ah * 0.5)
	var lft := Vector3(hcx - ab, ay, hcz - ah * 0.5)
	var rgt := Vector3(hcx + ab, ay, hcz - ah * 0.5)
	var bar := clampf(hw * 0.035, 0.9, 1.6)
	_beam(mb, lft, apex, 0.06, gold, bar)
	_beam(mb, rgt, apex, 0.06, gold, bar)
	_beam(mb, lft.lerp(apex, 0.42), rgt.lerp(apex, 0.42), 0.06, gold, bar * 0.8)
	# Glazed two-storey office annex beside the hangar.
	var aw := clampf(w * 0.2, 8.0, 14.0)
	var ad := clampf(hd * 0.55, 9.0, 16.0)
	var ax0 := hx1
	var ax1 := minf(ax0 + aw, w * 0.5 - 1.5)
	var az0 := hz0 + 3.0
	var acx := (ax0 + ax1) * 0.5
	var acz := az0 + ad * 0.5
	if ax1 - ax0 > 4.0:
		_solid(mb, out, Vector3(acx, 3.6, acz), Vector3(ax1 - ax0, 7.2, ad), MeshBuilder.glow(Color(0.3, 0.32, 0.35), MeshBuilder.CONCRETE))
		for f in 2:
			mb.box(Vector3(acx, 1.8 + f * 3.5, az0 - 0.05), Vector3(ax1 - ax0 - 0.6, 2.4, 0.08), MeshBuilder.glow(Color(0.55, 0.5, 0.38), MeshBuilder.GLOW_WINDOW))
			mb.box(Vector3(ax1 + 0.05, 1.8 + f * 3.5, acz), Vector3(0.08, 2.4, ad - 0.6), MeshBuilder.glow(Color(0.35, 0.42, 0.48), MeshBuilder.GLASS))
		_flat_roof(mb, acx, acz, ax1 - ax0, ad, 7.2, rng, Color(0.18, 0.18, 0.2), true)
		mb.box(Vector3(acx, 6.9, az0 - 0.1), Vector3(ax1 - ax0, 0.3, 0.1), gold)
	# Apron: taxi line from the door out to the front, and the jet.
	var line := MeshBuilder.glow(YELLOW, MeshBuilder.GLOSS)
	var lz0 := -d * 0.5 + clampf(d * 0.3, 8.0, 16.0)
	_line(mb, Vector3(hcx, 0, hz0 - 0.5), Vector3(hcx, 0, lz0), 0.3, line)
	_line(mb, Vector3(hcx, 0, lz0), Vector3(-w * 0.5 + 1.0, 0, lz0), 0.3, line)
	var jl := clampf(hw * 0.45, 13.0, 18.0)
	var jz := hz0 - jl * 0.6 - 1.0
	if jz - jl * 0.5 < -d * 0.5 + 2.0:
		jz = -d * 0.5 + 2.0 + jl * 0.5
	_jet(mb, Vector3(hcx, 0, jz), 0.0, jl, WHITE, Color(0.75, 0.58, 0.18))
	_col(out, Vector3(hcx, 1.6, jz), Vector3(jl * 0.16, 3.2, jl))
	_col(out, Vector3(hcx, 1.3, jz + jl * 0.05), Vector3(jl * 0.95, 0.6, jl * 0.25))
	# Front fence with a gate, gatehouse and barrier arm.
	var gx := w * 0.5 - clampf(w * 0.15, 6.0, 12.0)
	var fz := -d * 0.5 + 1.0
	Props.fence(mb, out, Vector3(-w * 0.5 + 0.5, 0, fz), Vector3(gx - 4.0, 0, fz), Color(0.3, 0.3, 0.32), 2.0)
	Props.fence(mb, out, Vector3(gx + 4.0, 0, fz), Vector3(w * 0.5 - 0.5, 0, fz), Color(0.3, 0.3, 0.32), 2.0)
	var gh := Vector3(gx + 5.6, 0, fz + 2.6)
	if gh.x + 1.6 > w * 0.5 - 0.5:
		gh.x = w * 0.5 - 2.1
	_solid(mb, out, gh + Vector3(0, 1.4, 0), Vector3(3.0, 2.8, 3.0), MeshBuilder.glow(Color(0.3, 0.32, 0.35), MeshBuilder.CONCRETE))
	mb.box(gh + Vector3(0, 1.7, -1.54), Vector3(2.4, 1.0, 0.08), MeshBuilder.glow(Color(0.55, 0.5, 0.38), MeshBuilder.GLOW_WINDOW))
	mb.box(gh + Vector3(-1.54, 1.7, 0), Vector3(0.08, 1.0, 2.4), MeshBuilder.glow(Color(0.55, 0.5, 0.38), MeshBuilder.GLOW_WINDOW))
	mb.box(gh + Vector3(0, 2.95, 0), Vector3(3.6, 0.3, 3.6), DARK)
	mb.box(gh + Vector3(0, 2.75, -1.81), Vector3(3.6, 0.15, 0.04), gold)
	_post(mb, out, Vector3(gx + 3.8, 0, fz + 0.8), 1.0, 0.35, Color(0.85, 0.85, 0.82))
	for k in 6:
		_beam(mb, Vector3(gx + 3.6 - k * 1.2, 1.0, fz + 0.8), Vector3(gx + 2.4 - k * 1.2, 1.0, fz + 0.8), 0.12, Color(0.9, 0.15, 0.12) if k % 2 == 0 else WHITE)
	# Cars by the annex and a pair of apron floodlights.
	for k in 2:
		var cp := Vector3(minf(ax0 + 3.0 + k * 3.0, w * 0.5 - 2.0), 0, az0 - 4.0)
		_car(mb, out, cp, 0.0, [Color(0.08, 0.08, 0.09), Color(0.75, 0.6, 0.25)][k])
	for s: float in [-1.0, 1.0]:
		var lp := Vector3(hcx + s * (hw * 0.5 + 1.0), 0, hz0 - 1.5)
		if absf(lp.x) < w * 0.5 - 1.0:
			_post(mb, out, lp, 9.0, 0.3, STEEL)
			mb.box(lp + Vector3(0, 9.1, -0.3), Vector3(1.4, 0.4, 0.6), MeshBuilder.glow(Color(1.0, 0.95, 0.8), MeshBuilder.GLOW_LAMP))
