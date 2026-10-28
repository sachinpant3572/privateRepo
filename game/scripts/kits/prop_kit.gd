extends RefCounted
## Street props and dock gear. Positions are local to the current
## MeshBuilder.xform; small solid props add [center, size] collision boxes.

const MeshBuilder = preload("res://scripts/mesh_builder.gd")

const IRON := Color(0.13, 0.15, 0.14)
const STEEL := Color(0.55, 0.57, 0.6)
const LAMP_GLOW := Color(1.0, 0.86, 0.45)
const LEAF := Color(0.27, 0.38, 0.2)
const LEAF_LIGHT := Color(0.36, 0.45, 0.23)
const MOSS := Color(0.6, 0.65, 0.55)
const BARK := Color(0.38, 0.27, 0.19)
const CONTAINERS := [Color(0.78, 0.28, 0.2), Color(0.2, 0.45, 0.72), Color(0.28, 0.58, 0.35), Color(0.88, 0.62, 0.2), Color(0.55, 0.55, 0.6)]


const POOL_WARM := Color(0.55, 0.38, 0.16)
const POOL_COOL := Color(0.4, 0.42, 0.38)
const LED := Color(0.92, 0.96, 1.0)
const AD_COLORS := [Color(0.95, 0.5, 0.3), Color(0.4, 0.75, 0.95), Color(0.9, 0.85, 0.4), Color(0.85, 0.45, 0.75)]
const SCOOTERS := [Color(0.2, 0.75, 0.4), Color(0.95, 0.4, 0.2), Color(0.15, 0.15, 0.15)]


## Where a breakable prop's mesh starts (see _breaks).
static func _start(mb, glow) -> Array:
	return [mb.verts.size(), glow.verts.size() if glow != null else 0]


## Marks the prop built since `from` (_start) as one a car knocks down: its
## colliders (the last `cols` in `out`) carry what Breakables needs, the
## kind and the prop's vertex ranges in `mb` and `glow`.
static func _breaks(mb, out: Array, from: Array, kind: String, glow, cols := 1) -> void:
	var info := {"kind": kind, "v": Vector2i(from[0], mb.verts.size()), "g": Vector2i(from[1], glow.verts.size() if glow != null else from[1])}
	for i in range(out.size() - cols, out.size()):
		var col: Array = out[i]
		if col.size() < 3:
			col.append(0.0)
		col.append(info)


## Black cast-iron gas lamp with a warm lantern (Lantern Quarter). With a
## `glow` builder, also the pool of light it throws at night.
static func gas_lamp(mb, out: Array, p: Vector3, glow = null) -> void:
	var from := _start(mb, glow)
	var iron := MeshBuilder.glow(IRON, MeshBuilder.GLOSS)
	mb.box(p + Vector3(0, 0.4, 0), Vector3(0.3, 0.5, 0.3), iron)
	mb.cylinder(p + Vector3(0, 0.15, 0), 0.09, 3.1, iron, 4)
	mb.box(p + Vector3(0, 3.0, 0), Vector3(0.6, 0.06, 0.06), iron)
	mb.box(p + Vector3(0, 3.45, 0), Vector3(0.42, 0.55, 0.42), MeshBuilder.glow(LAMP_GLOW, MeshBuilder.GLOW_LAMP))
	_pool(mb, glow, p + Vector3(0, 0.2, 0), 5.0, POOL_WARM)
	mb.box(p + Vector3(0, 3.8, 0), Vector3(0.55, 0.12, 0.55), iron)
	mb.box(p + Vector3(0, 3.95, 0), Vector3(0.12, 0.2, 0.12), iron)
	out.append([p + Vector3(0, 1.5, 0), Vector3(0.3, 3.0, 0.3)])
	_breaks(mb, out, from, "gas_lamp", glow)


## LED street light: a slim steel pole with a tapered arm toward `dir`
## (over the road) and a flat cobra head.
## With a `banner` colour, two district banners hang off the pole on short
## arms across the curb line.
static func street_light(mb, out: Array, p: Vector3, dir: Vector3, glow = null, banner = null) -> void:
	var from := _start(mb, glow)
	var steel := MeshBuilder.glow(STEEL, MeshBuilder.METAL)
	mb.box(p + Vector3(0, 0.35, 0), Vector3(0.3, 0.4, 0.3), steel)
	mb.cylinder(p + Vector3(0, 0.15, 0), 0.09, 6.2, steel, 5)
	mb.box(p + dir * 1.1 + Vector3(0, 6.15, 0), Vector3(absf(dir.x) * 2.2 + 0.08, 0.08, absf(dir.z) * 2.2 + 0.08), steel)
	mb.box(p + dir * 2.4 + Vector3(0, 6.08, 0), Vector3(absf(dir.x) * 0.5 + 0.32, 0.12, absf(dir.z) * 0.5 + 0.32), MeshBuilder.glow(Color(0.35, 0.37, 0.4), MeshBuilder.METAL))
	mb.box(p + dir * 2.4 + Vector3(0, 6.0, 0), Vector3(absf(dir.x) * 0.4 + 0.24, 0.06, absf(dir.z) * 0.4 + 0.24), MeshBuilder.glow(LED, MeshBuilder.GLOW_LAMP))
	_pool(mb, glow, p + dir * 2.4 + Vector3(0, 0.05, 0), 7.0, POOL_COOL)
	if banner != null:
		var along := Vector3(absf(dir.z), 0, absf(dir.x))
		var flag: Color = banner
		for side in [-1.0, 1.0]:
			mb.box(p + along * side * 0.35 + Vector3(0, 4.7, 0), along * 0.6 + Vector3(0, 0.04, 0.04), steel)
			mb.box(p + along * side * 0.38 + Vector3(0, 4.0, 0), along * 0.5 + Vector3(0, 1.3, 0) + dir.abs() * 0.03, flag if side < 0.0 else flag.lightened(0.15))
	out.append([p + Vector3(0, 2.0, 0), Vector3(0.3, 4.0, 0.3)])
	_breaks(mb, out, from, "street_light", glow)


## Mast-arm traffic signal: the pole stands at p, the arm reaches 5 m over
## the road toward `dir` and carries two signal heads (lenses on both
## faces along the street), a traffic camera and a street-name sign.
static func traffic_light(mb, out: Array, p: Vector3, dir: Vector3) -> void:
	var from := _start(mb, null)
	var paint := MeshBuilder.glow(Color(0.2, 0.22, 0.22), MeshBuilder.GLOSS)
	mb.cylinder(p + Vector3(0, 0.15, 0), 0.13, 6.0, paint, 6)
	var along := Vector3(absf(dir.z), 0, absf(dir.x))
	mb.box(p + dir * 2.6 + Vector3(0, 5.8, 0), Vector3(absf(dir.x) * 5.2 + 0.12, 0.12, absf(dir.z) * 5.2 + 0.12), paint)
	for k in 2:
		var head := p + dir * (2.4 + k * 2.2) + Vector3(0, 5.15, 0)
		mb.box(head, Vector3(0.36, 1.1, 0.36), MeshBuilder.glow(Color(0.16, 0.17, 0.17), MeshBuilder.GLOSS))
		mb.box(head + Vector3(0, 0.6, 0), Vector3(0.44, 0.05, 0.44), MeshBuilder.glow(Color(0.85, 0.75, 0.2), MeshBuilder.GLOSS))
		var lit := k == 0
		for side in [-1.0, 1.0]:
			var face: Vector3 = head + along * side * 0.2
			mb.box(face + Vector3(0, 0.33, 0), along * 0.04 + (Vector3.ONE - along) * 0.24, Color(0.45, 0.1, 0.08))
			mb.box(face, along * 0.04 + (Vector3.ONE - along) * 0.24, Color(0.45, 0.35, 0.08))
			mb.box(face - Vector3(0, 0.33, 0), along * 0.04 + (Vector3.ONE - along) * 0.24, MeshBuilder.glow(Color(0.2, 0.95, 0.5), MeshBuilder.GLOW_NEON) if lit else Color(0.1, 0.35, 0.18))
	mb.box(p + dir * 1.2 + Vector3(0, 6.15, 0), along * 1.6 + Vector3(0, 0.35, 0) + dir.abs() * 0.04, Color(0.12, 0.42, 0.25))
	mb.box(p + dir * 0.6 + Vector3(0, 5.6, 0), Vector3(0.22, 0.2, 0.22) + dir.abs() * 0.2, MeshBuilder.glow(Color(0.85, 0.86, 0.88), MeshBuilder.GLOSS))
	# Pedestrian signal and push button.
	mb.box(p - dir * 0.25 + Vector3(0, 2.8, 0), Vector3(0.36, 0.36, 0.36), Color(0.1, 0.1, 0.1))
	mb.box(p - dir * 0.25 + Vector3(0, 2.8, 0) + along * 0.19, along * 0.04 + (Vector3.ONE - along) * 0.26, MeshBuilder.glow(Color(1.0, 0.95, 0.85), MeshBuilder.GLOW_NEON))
	mb.box(p - dir * 0.15 + Vector3(0, 1.1, 0), Vector3(0.14, 0.2, 0.14), Color(0.9, 0.75, 0.2))
	# Signal controller cabinet behind the pole, toward the buildings.
	var cab := p + along * 1.0 - dir * 1.3
	mb.box(cab + Vector3(0, 0.12, 0), along * 0.95 + dir.abs() * 0.7 + Vector3(0, 0.1, 0), MeshBuilder.glow(Color(0.6, 0.6, 0.58), MeshBuilder.CONCRETE))
	mb.box(cab + Vector3(0, 0.85, 0), along * 0.8 + dir.abs() * 0.5 + Vector3(0, 1.3, 0), MeshBuilder.glow(Color(0.62, 0.66, 0.62), MeshBuilder.GLOSS))
	mb.box(cab + Vector3(0, 1.52, 0), along * 0.86 + dir.abs() * 0.56 + Vector3(0, 0.05, 0), MeshBuilder.glow(Color(0.7, 0.73, 0.7), MeshBuilder.METAL))
	out.append([p + Vector3(0, 2.0, 0), Vector3(0.35, 4.0, 0.35)])
	out.append([cab + Vector3(0, 0.75, 0), along * 0.8 + dir.abs() * 0.5 + Vector3(0, 1.5, 0)])
	_breaks(mb, out, from, "traffic_light", null, 2)


## Bus shelter facing -Z: glass back and ends, a steel roof, a bench and a
## lit advertising panel, with the stop flag on a pole by the curb.
static func bus_shelter(mb, out: Array, p: Vector3, rng: RandomNumberGenerator) -> void:
	var steel := MeshBuilder.glow(Color(0.3, 0.32, 0.35), MeshBuilder.METAL)
	var glass := MeshBuilder.glow(Color(0.5, 0.6, 0.65), MeshBuilder.GLASS)
	mb.box(p + Vector3(0, 2.45, 0.1), Vector3(3.8, 0.12, 1.7), steel)
	mb.box(p + Vector3(0, 1.3, 0.85), Vector3(3.6, 2.1, 0.05), glass)
	for side in [-1.0, 1.0]:
		mb.box(p + Vector3(side * 1.85, 1.3, 0.35), Vector3(0.05, 2.1, 1.0), glass)
		mb.box(p + Vector3(side * 1.88, 1.2, 0.85), Vector3(0.1, 2.4, 0.1), steel)
	var ad: Color = AD_COLORS[rng.randi() % AD_COLORS.size()]
	mb.box(p + Vector3(1.85, 1.3, 0.35), Vector3(0.14, 1.7, 0.95), Color(0.15, 0.15, 0.17))
	mb.box(p + Vector3(1.85, 1.3, 0.35), Vector3(0.18, 1.5, 0.8), MeshBuilder.glow(ad, MeshBuilder.GLOW_NEON))
	mb.box(p + Vector3(-0.3, 0.48, 0.55), Vector3(2.4, 0.08, 0.45), steel)
	mb.box(p + Vector3(-0.8, 2.0, 0.84), Vector3(1.2, 0.5, 0.06), MeshBuilder.glow(Color(0.15, 0.2, 0.35), MeshBuilder.GLOW_NEON))
	# The stop sign stands at the curb, 1.45 m in front of the shelter.
	mb.cylinder(p + Vector3(-2.4, 0.15, -1.45), 0.05, 2.8, STEEL, 4)
	mb.box(p + Vector3(-2.4, 2.75, -1.45), Vector3(0.5, 0.5, 0.05), Color(0.15, 0.35, 0.75))
	out.append([p + Vector3(0, 1.2, 0.6), Vector3(3.8, 2.4, 0.6)])
	out.append([p + Vector3(-2.4, 1.2, -1.45), Vector3(0.2, 2.4, 0.2)])


## Electric-vehicle charging post with a lit status ring and a holstered
## cable.
static func ev_charger(mb, out: Array, p: Vector3) -> void:
	var from := _start(mb, null)
	mb.box(p + Vector3(0, 0.2, 0), Vector3(0.6, 0.1, 0.45), MeshBuilder.glow(Color(0.6, 0.6, 0.6), MeshBuilder.CONCRETE))
	mb.box(p + Vector3(0, 0.95, 0), Vector3(0.42, 1.5, 0.28), MeshBuilder.glow(Color(0.92, 0.93, 0.94), MeshBuilder.GLOSS))
	mb.box(p + Vector3(0, 1.45, -0.15), Vector3(0.3, 0.32, 0.04), MeshBuilder.glow(Color(0.1, 0.12, 0.15), MeshBuilder.GLASS))
	mb.box(p + Vector3(0, 1.72, 0), Vector3(0.44, 0.06, 0.3), MeshBuilder.glow(Color(0.2, 0.75, 1.0), MeshBuilder.GLOW_NEON))
	mb.box(p + Vector3(0.24, 0.95, -0.05), Vector3(0.1, 0.25, 0.12), Color(0.12, 0.12, 0.12))
	out.append([p + Vector3(0, 0.8, 0), Vector3(0.45, 1.6, 0.35)])
	_breaks(mb, out, from, "ev_charger", null)


## Bike-share dock along local X: a kiosk with a screen, a docking rail and
## a few bikes in the scheme's colour.
static func bike_dock(mb, out: Array, p: Vector3, length: float, rng: RandomNumberGenerator) -> void:
	var brand := Color(0.15, 0.55, 0.85)
	var steel := MeshBuilder.glow(Color(0.4, 0.42, 0.45), MeshBuilder.METAL)
	mb.box(p + Vector3(-length * 0.5 - 0.4, 0.9, 0), Vector3(0.5, 1.8, 0.4), MeshBuilder.glow(brand, MeshBuilder.GLOSS))
	mb.box(p + Vector3(-length * 0.5 - 0.4, 1.3, -0.21), Vector3(0.36, 0.5, 0.04), MeshBuilder.glow(Color(0.5, 0.75, 0.95), MeshBuilder.GLOW_NEON))
	mb.box(p + Vector3(0, 0.3, 0.3), Vector3(length, 0.1, 0.12), steel)
	var slots := int(length / 0.8)
	for i in slots:
		var x := -length * 0.5 + (i + 0.5) * length / slots
		mb.box(Vector3(x, 0.5, 0.3) + p, Vector3(0.1, 0.4, 0.14), steel)
		if rng.randf() < 0.7:
			bike(mb, p + Vector3(x, 0, -0.35), brand)
	out.append([p + Vector3(0, 0.5, 0), Vector3(length + 1.0, 1.0, 1.6)])


## A city bike standing across local X (wheels front and back along Z).
static func bike(mb, p: Vector3, color: Color) -> void:
	for z in [-0.5, 0.5]:
		mb.box(p + Vector3(0, 0.33, z), Vector3(0.05, 0.6, 0.6), Color(0.08, 0.08, 0.08))
	mb.box(p + Vector3(0, 0.55, 0), Vector3(0.07, 0.07, 0.95), MeshBuilder.glow(color, MeshBuilder.GLOSS))
	mb.box(p + Vector3(0, 0.82, -0.4), Vector3(0.5, 0.05, 0.05), Color(0.15, 0.15, 0.15))
	mb.box(p + Vector3(0, 0.82, 0.32), Vector3(0.14, 0.06, 0.24), Color(0.1, 0.1, 0.1))
	mb.box(p + Vector3(0, 0.62, -0.52), Vector3(0.28, 0.2, 0.2), MeshBuilder.glow(color, MeshBuilder.GLOSS))


## Dockless e-scooter left standing on its kickstand, along local X.
static func scooter(mb, p: Vector3, yaw: float, color: Color) -> void:
	var saved: Transform3D = mb.xform
	mb.xform = saved * Transform3D(Basis(Vector3.UP, yaw), p)
	mb.box(Vector3(0, 0.12, 0), Vector3(0.9, 0.06, 0.18), Color(0.12, 0.12, 0.13))
	mb.box(Vector3(0.42, 0.62, 0), Vector3(0.05, 1.0, 0.05), MeshBuilder.glow(color, MeshBuilder.GLOSS))
	mb.box(Vector3(0.42, 1.12, 0), Vector3(0.05, 0.05, 0.5), Color(0.12, 0.12, 0.13))
	for x in [-0.42, 0.42]:
		mb.box(Vector3(x, 0.1, 0), Vector3(0.2, 0.2, 0.06), Color(0.08, 0.08, 0.08))
	mb.xform = saved


## Three-stream bins side by side: a solar compacting bin for landfill
## (the panel on top is what the camera sees), recycling (blue lid) and
## compost (green lid).
static func bins(mb, out: Array, p: Vector3) -> void:
	var from := _start(mb, null)
	var body := MeshBuilder.glow(Color(0.42, 0.44, 0.46), MeshBuilder.METAL)
	mb.box(p + Vector3(-0.7, 0.62, 0), Vector3(0.66, 1.05, 0.62), body)
	mb.box(p + Vector3(-0.7, 1.17, 0), Vector3(0.66, 0.05, 0.62), MeshBuilder.glow(Color(0.85, 0.86, 0.88), MeshBuilder.METAL))
	mb.box(p + Vector3(-0.7, 1.2, 0.02), Vector3(0.56, 0.02, 0.5), MeshBuilder.glow(Color(0.1, 0.13, 0.22), MeshBuilder.SOLAR))
	mb.box(p + Vector3(-0.7, 0.85, -0.32), Vector3(0.44, 0.22, 0.03), Color(0.15, 0.15, 0.16))
	for k in 2:
		var lid := Color(0.15, 0.4, 0.78) if k == 0 else Color(0.25, 0.6, 0.3)
		var q := p + Vector3(k * 0.62, 0, 0)
		mb.box(q + Vector3(0, 0.55, 0), Vector3(0.56, 0.9, 0.56), body)
		mb.box(q + Vector3(0, 1.03, 0), Vector3(0.6, 0.06, 0.6), MeshBuilder.glow(lid, MeshBuilder.GLOSS))
		mb.box(q + Vector3(0, 0.75, -0.29), Vector3(0.3, 0.3, 0.02), MeshBuilder.glow(lid.lightened(0.2), MeshBuilder.GLOSS))
	out.append([p + Vector3(-0.05, 0.6, 0), Vector3(1.95, 1.2, 0.65)])
	_breaks(mb, out, from, "bins", null)


## Wayfinding totem: a slim slab with a lit city map on its face (-Z).
static func wayfinding(mb, out: Array, p: Vector3) -> void:
	var from := _start(mb, null)
	mb.box(p + Vector3(0, 1.3, 0), Vector3(0.9, 2.3, 0.2), MeshBuilder.glow(Color(0.18, 0.2, 0.24), MeshBuilder.GLOSS))
	mb.box(p + Vector3(0, 1.4, -0.11), Vector3(0.7, 1.4, 0.04), MeshBuilder.glow(Color(0.85, 0.88, 0.8), MeshBuilder.GLOW_NEON))
	mb.box(p + Vector3(0, 2.3, -0.12), Vector3(0.7, 0.2, 0.04), Color(0.95, 0.75, 0.2))
	out.append([p + Vector3(0, 1.2, 0), Vector3(0.9, 2.4, 0.25)])
	_breaks(mb, out, from, "wayfinding", null)


## Parking pay station.
static func pay_station(mb, out: Array, p: Vector3) -> void:
	var from := _start(mb, null)
	mb.box(p + Vector3(0, 0.8, 0), Vector3(0.35, 1.3, 0.3), MeshBuilder.glow(Color(0.2, 0.3, 0.5), MeshBuilder.GLOSS))
	mb.box(p + Vector3(0, 1.2, -0.16), Vector3(0.24, 0.2, 0.03), MeshBuilder.glow(Color(0.6, 0.85, 0.7), MeshBuilder.GLOW_NEON))
	mb.box(p + Vector3(0, 1.62, 0.04), Vector3(0.5, 0.04, 0.42), MeshBuilder.glow(Color(0.1, 0.13, 0.22), MeshBuilder.SOLAR))
	mb.box(p + Vector3(0, 1.52, 0.04), Vector3(0.06, 0.16, 0.06), MeshBuilder.glow(STEEL, MeshBuilder.METAL))
	out.append([p + Vector3(0, 0.7, 0), Vector3(0.35, 1.4, 0.3)])
	_breaks(mb, out, from, "pay_station", null)


## Fire hydrant: flanged base, barrel, side nozzles with caps and a
## domed bonnet (gloss red, a yellow-capped top nut).
static func hydrant(mb, out: Array, p: Vector3) -> void:
	var from := _start(mb, null)
	var red := MeshBuilder.glow(Color(0.82, 0.15, 0.12), MeshBuilder.GLOSS)
	mb.box(p + Vector3(0, 0.19, 0), Vector3(0.44, 0.08, 0.44), red)
	mb.cylinder(p + Vector3(0, 0.15, 0), 0.17, 0.62, red, 6)
	mb.box(p + Vector3(0, 0.55, 0), Vector3(0.52, 0.13, 0.13), red)
	for side in [-1.0, 1.0]:
		mb.box(p + Vector3(side * 0.28, 0.55, 0), Vector3(0.05, 0.16, 0.16), MeshBuilder.glow(STEEL, MeshBuilder.METAL))
	mb.box(p + Vector3(0, 0.5, -0.2), Vector3(0.18, 0.18, 0.12), red)
	mb.ball(p + Vector3(0, 0.78, 0), Vector3(0.2, 0.12, 0.2), red, 6, 2)
	mb.box(p + Vector3(0, 0.92, 0), Vector3(0.1, 0.08, 0.1), Color(0.95, 0.85, 0.3))
	out.append([p + Vector3(0, 0.5, 0), Vector3(0.45, 1.0, 0.45)])
	_breaks(mb, out, from, "hydrant", null)


## Park bench facing -Z after turning by `yaw`: wooden slats (the siding
## code draws them) on a steel frame with armrests.
static func bench(mb, out: Array, p: Vector3, yaw: float) -> void:
	var from := _start(mb, null)
	var saved: Transform3D = mb.xform
	mb.xform = saved * Transform3D(Basis(Vector3.UP, yaw), p)
	var wood := MeshBuilder.glow(Color(0.66, 0.46, 0.28), MeshBuilder.SIDING)
	var frame := MeshBuilder.glow(Color(0.32, 0.34, 0.36), MeshBuilder.METAL)
	mb.box(Vector3(0, 0.47, 0), Vector3(1.8, 0.06, 0.48), wood)
	mb.box(Vector3(0, 0.82, 0.24), Vector3(1.8, 0.42, 0.05), wood)
	for side in [-0.82, 0.0, 0.82]:
		mb.box(Vector3(side, 0.24, 0.02), Vector3(0.06, 0.42, 0.5), frame)
	for side in [-0.88, 0.88]:
		mb.box(Vector3(side, 0.64, 0.0), Vector3(0.06, 0.05, 0.42), frame)
	mb.xform = saved
	out.append([p + Vector3(0, 0.5, 0), Vector3(1.8, 1.0, 0.6), yaw])
	_breaks(mb, out, from, "bench", null)


## Litter bin: perforated steel (dark green) under a domed steel lid.
static func trash_can(mb, out: Array, p: Vector3) -> void:
	var from := _start(mb, null)
	var green := MeshBuilder.glow(Color(0.2, 0.32, 0.26), MeshBuilder.GLOSS)
	mb.cylinder(p + Vector3(0, 0.15, 0), 0.3, 0.85, green, 8)
	for y in [0.35, 0.6, 0.85]:
		mb.cylinder(p + Vector3(0, y, 0), 0.31, 0.04, MeshBuilder.glow(Color(0.12, 0.18, 0.15), MeshBuilder.GLOSS), 8)
	mb.ball(p + Vector3(0, 1.0, 0), Vector3(0.33, 0.14, 0.33), MeshBuilder.glow(Color(0.55, 0.58, 0.6), MeshBuilder.METAL), 8, 2)
	out.append([p + Vector3(0, 0.5, 0), Vector3(0.6, 1.0, 0.6)])
	_breaks(mb, out, from, "trash_can", null)


## Postal drop box: navy with a domed top and a white panel.
static func mailbox(mb, out: Array, p: Vector3) -> void:
	var from := _start(mb, null)
	var navy := MeshBuilder.glow(Color(0.16, 0.3, 0.62), MeshBuilder.GLOSS)
	mb.box(p + Vector3(0, 0.6, 0), Vector3(0.5, 0.9, 0.45), navy)
	mb.limb(p + Vector3(-0.25, 1.05, 0), p + Vector3(0.25, 1.05, 0), 0.22, 0.22, navy, 8)
	mb.box(p + Vector3(0, 0.75, -0.23), Vector3(0.3, 0.16, 0.02), Color(0.92, 0.92, 0.9))
	mb.box(p + Vector3(0, 0.12, 0), Vector3(0.56, 0.08, 0.5), Color(0.15, 0.15, 0.16))
	out.append([p + Vector3(0, 0.6, 0), Vector3(0.5, 1.2, 0.45)])
	_breaks(mb, out, from, "mailbox", null)


## A row of inverted-U steel bike racks along local X, with a bike or two
## locked to them.
static func bike_rack(mb, out: Array, p: Vector3, rng: RandomNumberGenerator) -> void:
	var from := _start(mb, null)
	var steel := MeshBuilder.glow(Color(0.6, 0.62, 0.65), MeshBuilder.METAL)
	for i in 3:
		var x := (i - 1) * 0.9
		for z in [-0.3, 0.3]:
			mb.box(p + Vector3(x, 0.45, z), Vector3(0.05, 0.8, 0.05), steel)
		mb.box(p + Vector3(x, 0.86, 0), Vector3(0.05, 0.05, 0.65), steel)
		if rng.randf() < 0.5:
			bike(mb, p + Vector3(x + 0.18, 0, 0), [Color(0.15, 0.15, 0.17), Color(0.75, 0.2, 0.18), Color(0.85, 0.85, 0.82), Color(0.2, 0.45, 0.4)][rng.randi() % 4])
	out.append([p + Vector3(0, 0.45, 0), Vector3(2.4, 0.9, 0.8)])
	_breaks(mb, out, from, "bike_rack", null)


## Sidewalk works fenced off along local X: water-filled barriers in orange
## and white, cones, a plate over the trench and a sign. A car knocks it
## over (the barriers burst). It spans local Z
## -0.5..0.75; place it at the back of the sidewalk (z about 1.7) so the
## people's walking line (z about 0.75) stays clear.
static func roadworks(mb, out: Array, p: Vector3) -> void:
	var from := _start(mb, null)
	var orange := MeshBuilder.glow(Color(0.95, 0.45, 0.1), MeshBuilder.GLOSS)
	var white := MeshBuilder.glow(Color(0.93, 0.93, 0.9), MeshBuilder.GLOSS)
	mb.box(p + Vector3(0, 0.02, 0.15), Vector3(2.4, 0.03, 0.9), MeshBuilder.glow(Color(0.35, 0.36, 0.38), MeshBuilder.METAL))
	for k in 3:
		mb.box(p + Vector3(-1.4 + k * 1.4, 0.45, -0.3), Vector3(1.3, 0.8, 0.4), orange if k % 2 == 0 else white)
	for x in [-1.6, 1.6]:
		mb.cylinder(p + Vector3(x, 0, 0.55), 0.14, 0.7, orange, 6)
		mb.box(p + Vector3(x, 0.45, 0.55), Vector3(0.24, 0.1, 0.24), white)
	mb.box(p + Vector3(0.9, 1.3, 0.55), Vector3(0.6, 0.6, 0.04), MeshBuilder.glow(Color(0.98, 0.6, 0.12), MeshBuilder.GLOSS))
	mb.box(p + Vector3(0.9, 0.6, 0.57), Vector3(0.05, 1.0, 0.05), MeshBuilder.glow(STEEL, MeshBuilder.METAL))
	out.append([p + Vector3(0, 0.5, 0.125), Vector3(4.0, 1.0, 1.25)])
	_breaks(mb, out, from, "roadworks", null)


## Live oak: a short, thick trunk forking into four low limbs, a clump at
## each tip and two over the fork making a broad, lumpy crown, with grey
## Spanish moss hanging off the limbs.
static func oak(mb, out: Array, p: Vector3, rng: RandomNumberGenerator) -> void:
	var s := rng.randf_range(0.85, 1.2)
	var seed := rng.randi()
	var leaf := _leaf(LEAF.lerp(LEAF_LIGHT, rng.randf()))
	var fork := p + Vector3(0, 2.0 * s, 0)
	mb.limb(p, fork, 0.4 * s, 0.28 * s, BARK, 6, false)
	var turn := rng.randf() * TAU
	for i in 4:
		var a := turn + TAU * i / 4.0 + rng.randf_range(-0.3, 0.3)
		var d := Vector3(cos(a), 0, sin(a))
		var tip := fork + d * rng.randf_range(1.7, 2.3) * s + Vector3(0, rng.randf_range(0.9, 1.5) * s, 0)
		mb.limb(fork, tip, 0.2 * s, 0.09 * s, BARK, 5, false)
		var tint := leaf.lightened(0.08) if i % 2 == 0 else leaf.darkened(0.06)
		mb.clump(tip + Vector3(0, 0.5 * s, 0), Vector3(1.5, 1.0, 1.5) * s * rng.randf_range(0.9, 1.1), tint, seed + i, 9, 4, 0.28)
		if i % 2 == 0:
			# Moss hangs off the limb's outer half (thin along Z so it faces
			# the camera).
			for m in 2:
				var at := fork.lerp(tip, 0.6 + m * 0.25) + Vector3(0, -0.45 * s, 0)
				mb.box(at, Vector3(0.16, 0.9, 0.05) * s, MOSS)
	mb.clump(fork + Vector3(0.4, 2.3, 0.3) * s, Vector3(1.6, 1.0, 1.6) * s, leaf.lightened(0.07), seed + 9, 9, 4, 0.28)
	mb.clump(fork + Vector3(-0.5, 2.0, -0.4) * s, Vector3(1.5, 0.9, 1.5) * s, leaf.lightened(0.02), seed + 10, 9, 4, 0.28)
	out.append([p + Vector3(0, 1.5, 0), Vector3(0.8, 3.0, 0.8)])


## Street tree in a sidewalk pit (downtown): a cast-iron grate flush with
## the paving, a slim trunk and an upright crown of clumps.
static func street_tree(mb, out: Array, p: Vector3, rng: RandomNumberGenerator) -> void:
	var from := _start(mb, null)
	var s := rng.randf_range(0.9, 1.1)
	var seed := rng.randi()
	var leaf := _leaf(Color(0.3, 0.42, 0.2).lerp(Color(0.38, 0.48, 0.23), rng.randf()))
	mb.box(p + Vector3(0, 0.01, 0), Vector3(1.6, 0.02, 1.6), MeshBuilder.glow(Color(0.55, 0.54, 0.5), MeshBuilder.CONCRETE))
	mb.box(p + Vector3(0, 0.016, 0), Vector3(1.36, 0.02, 1.36), MeshBuilder.glow(Color(0.33, 0.31, 0.29), MeshBuilder.GLOSS))
	mb.box(p + Vector3(0, 0.022, 0), Vector3(0.46, 0.02, 0.46), Color(0.22, 0.17, 0.12))
	mb.limb(p, p + Vector3(0, 2.8, 0) * s, 0.13, 0.09, BARK.lightened(0.12), 5, false)
	mb.clump(p + Vector3(0, 3.7, 0) * s, Vector3(1.5, 1.5, 1.5) * s, leaf, seed, 9, 4, 0.28)
	mb.clump(p + Vector3(0.45, 4.8, 0.2) * s, Vector3(1.1, 1.0, 1.1) * s, leaf.lightened(0.08), seed + 1, 6)
	mb.clump(p + Vector3(-0.5, 4.5, -0.3) * s, Vector3(1.0, 0.9, 1.0) * s, leaf.darkened(0.06), seed + 2, 6)
	out.append([p + Vector3(0, 1.0, 0), Vector3(0.3, 2.0, 0.3)])
	_breaks(mb, out, from, "street_tree", null)


## Crepe myrtle: three slim, pale, splaying stems carrying bloom clusters
## (mostly pink, some white, lilac or watermelon red).
static func crepe_myrtle(mb, out: Array, p: Vector3, rng: RandomNumberGenerator) -> void:
	var from := _start(mb, null)
	var roll := rng.randf()
	var bloom := Color(0.88, 0.5, 0.68) if roll < 0.55 else (Color(0.86, 0.84, 0.84) if roll < 0.75 else (Color(0.68, 0.55, 0.82) if roll < 0.9 else Color(0.84, 0.28, 0.38)))
	bloom = _leaf(bloom)
	var seed := rng.randi()
	var turn := rng.randf() * TAU
	for i in 3:
		var a := turn + TAU * i / 3.0
		var d := Vector3(cos(a), 0, sin(a))
		var tip := p + d * 0.55 + Vector3(0, 2.3, 0)
		mb.limb(p + d * 0.06, tip, 0.07, 0.045, Color(0.66, 0.55, 0.45), 4, false)
		mb.clump(tip + d * 0.15 + Vector3(0, 0.4, 0), Vector3(0.75, 0.62, 0.75), bloom.darkened(0.04 * i), seed + i, 7, 3, 0.25)
	mb.clump(p + Vector3(0, 3.05, 0), Vector3(0.78, 0.58, 0.78), bloom.lightened(0.06), seed + 5, 7, 3, 0.25)
	out.append([p + Vector3(0, 1.0, 0), Vector3(0.4, 2.0, 0.4)])
	_breaks(mb, out, from, "crepe_myrtle", null)


## Concrete planter with a clipped shrub and a fountain of ornamental grass.
static func planter(mb, out: Array, p: Vector3) -> void:
	var seed := int(p.x * 13.0 + p.z * 7.0)
	mb.box(p + Vector3(0, 0.4, 0), Vector3(1.4, 0.5, 1.4), MeshBuilder.glow(Color(0.68, 0.66, 0.62), MeshBuilder.CONCRETE))
	mb.box(p + Vector3(0, 0.66, 0), Vector3(1.22, 0.02, 1.22), Color(0.22, 0.17, 0.13))
	mb.clump(p + Vector3(-0.22, 0.95, 0.18), Vector3(0.48, 0.4, 0.48), _leaf(LEAF.lightened(0.06)), seed, 6)
	grass(mb, p + Vector3(0.3, 0.66, -0.25), 0.75, seed)
	out.append([p + Vector3(0, 0.5, 0), Vector3(1.4, 1.0, 1.4)])


## A fountain of ornamental grass blades from `p`, about `h` tall.
static func grass(mb, p: Vector3, h: float, seed: int) -> void:
	var straw := Color(0.62, 0.62, 0.36)
	for i in 7:
		var a := TAU * i / 7.0 + MeshBuilder._hash(seed + i) * 0.6
		var d := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-d.z, 0, d.x) * 0.06
		var tip := p + d * h * 0.45 + Vector3(0, h * (0.75 + 0.3 * MeshBuilder._hash(seed * 3 + i)), 0)
		mb.tri(p - side, p + side, tip, (d + Vector3(0, 0.6, 0)).normalized(), straw.lerp(LEAF_LIGHT, 0.4 * (i % 2)))


## Foliage colour: the GRASS code, which the city shader breaks into leaf
## clusters above the ground.
static func _leaf(color: Color) -> Color:
	return MeshBuilder.glow(color, MeshBuilder.GRASS)


## Picket or chain-link style fence between two points (posts plus rails),
## at any angle.
static func fence(mb, out: Array, a: Vector3, b: Vector3, color: Color, height := 1.2) -> void:
	var dir := b - a
	var length := dir.length()
	if length < 0.1:
		return
	var yaw := atan2(-dir.z, dir.x)
	var mid := (a + b) * 0.5
	var saved: Transform3D = mb.xform
	mb.xform = saved * Transform3D(Basis(Vector3.UP, yaw), mid)
	var posts := maxi(2, int(length / 2.5) + 1)
	for i in posts:
		mb.box(Vector3(-length * 0.5 + length * i / (posts - 1), height * 0.5, 0), Vector3(0.1, height, 0.1), color)
	mb.box(Vector3(0, height * 0.85, 0), Vector3(length + 0.06, 0.07, 0.06), color)
	mb.box(Vector3(0, height * 0.35, 0), Vector3(length + 0.06, 0.07, 0.06), color)
	mb.xform = saved
	out.append([mid + Vector3(0, height * 0.5, 0), Vector3(length + 0.15, height, 0.15), yaw])


## Wooden power pole; wires to `next` are drawn as thin sagless lines.
static func power_pole(mb, out: Array, p: Vector3, next = null) -> void:
	mb.cylinder(p + Vector3(0, 0.15, 0), 0.13, 7.5, BARK.lightened(0.1), 4)
	mb.box(p + Vector3(0, 7.2, 0), Vector3(1.6, 0.12, 0.12), BARK)
	if next != null:
		var q: Vector3 = next
		var d := q - p
		var saved: Transform3D = mb.xform
		mb.xform = saved * Transform3D(Basis(Vector3.UP, atan2(-d.z, d.x)), (p + q) * 0.5)
		for off in [-0.7, 0.7]:
			mb.box(Vector3(0, 7.3, off), Vector3(d.length() + 0.08, 0.06, 0.06), Color(0.06, 0.06, 0.06))
		mb.xform = saved
	out.append([p + Vector3(0, 2.0, 0), Vector3(0.3, 4.0, 0.3)])


static func crate(mb, out: Array, p: Vector3, size := 1.1) -> void:
	var from := _start(mb, null)
	mb.box(p + Vector3(0, size * 0.5, 0), Vector3(size, size, size), Color(0.62, 0.45, 0.25))
	mb.box(p + Vector3(0, size * 0.5, 0), Vector3(size + 0.04, size * 0.15, size + 0.04), Color(0.45, 0.32, 0.18))
	out.append([p + Vector3(0, size * 0.5, 0), Vector3(size, size, size)])
	_breaks(mb, out, from, "crate", null)


static func barrel(mb, out: Array, p: Vector3, color := Color(0.25, 0.4, 0.65)) -> void:
	var from := _start(mb, null)
	mb.cylinder(p + Vector3(0, 0.15, 0), 0.38, 1.1, color, 6)
	mb.cylinder(p + Vector3(0, 0.6, 0), 0.4, 0.08, color.darkened(0.3), 6)
	out.append([p + Vector3(0, 0.6, 0), Vector3(0.8, 1.2, 0.8)])
	_breaks(mb, out, from, "barrel", null)


## Shipping container, long side along X (6 m) unless `along_z`.
static func container(mb, out: Array, p: Vector3, color: Color, along_z := false) -> void:
	var size := Vector3(6.0, 2.6, 2.4) if not along_z else Vector3(2.4, 2.6, 6.0)
	mb.box(p + Vector3(0, size.y * 0.5, 0), size, color)
	var ribs := 5
	for i in ribs:
		var t := -0.4 + 0.8 * i / (ribs - 1)
		var off := Vector3(size.x * t, 0, 0) if not along_z else Vector3(0, 0, size.z * t)
		mb.box(p + off + Vector3(0, size.y * 0.5, 0), Vector3(0.12, size.y + 0.02, size.z + 0.06) if not along_z else Vector3(size.x + 0.06, size.y + 0.02, 0.12), color.darkened(0.2))
	out.append([p + Vector3(0, size.y * 0.5, 0), size])


## Dockside gantry crane: four legs, a boom along +Z reaching over the
## water, `reach` metres from the legs' centre to its tip.
static func crane(mb, out: Array, p: Vector3, reach := 21.0) -> void:
	var yellow := Color(0.95, 0.72, 0.15)
	for x in [-4.0, 4.0]:
		for z in [-3.0, 3.0]:
			mb.box(p + Vector3(x, 7.0, z), Vector3(0.6, 14.0, 0.6), yellow)
			out.append([p + Vector3(x, 2.0, z), Vector3(0.8, 4.0, 0.8)])
	mb.box(p + Vector3(0, 14.4, 0), Vector3(9.0, 0.8, 7.0), yellow.darkened(0.15))
	mb.box(p + Vector3(0, 15.4, (reach - 5.0) * 0.5), Vector3(1.4, 1.0, reach + 5.0), yellow)
	mb.box(p + Vector3(0, 16.4, -2.0), Vector3(3.0, 2.0, 3.0), Color(0.3, 0.32, 0.35))
	mb.box(p + Vector3(0, 11.0, reach - 7.0), Vector3(0.08, 8.0, 0.08), Color(0.1, 0.1, 0.1))
	mb.box(p + Vector3(0, 7.0, reach - 7.0), Vector3(2.4, 0.4, 1.2), Color(0.2, 0.2, 0.22))


## Bellerive streetcar: green body, red trim, window band and trolley pole.
## Long side along local Z.
static func streetcar(mb, out: Array, p: Vector3, rusty := false) -> void:
	var green := Color(0.2, 0.45, 0.3) if not rusty else Color(0.38, 0.4, 0.3)
	var red := Color(0.7, 0.18, 0.15) if not rusty else Color(0.5, 0.3, 0.22)
	mb.box(p + Vector3(0, 1.4, 0), Vector3(2.6, 2.4, 14.0), green)
	mb.box(p + Vector3(0, 2.2, 0), Vector3(2.66, 0.9, 13.2), Color(0.85, 0.82, 0.62) if not rusty else Color(0.3, 0.32, 0.3))
	mb.box(p + Vector3(0, 0.45, 0), Vector3(2.7, 0.5, 14.1), red)
	mb.box(p + Vector3(0, 2.95, 0), Vector3(2.4, 0.35, 13.6), Color(0.3, 0.3, 0.3))
	mb.box(p + Vector3(0, 3.8, 2.0), Vector3(0.08, 0.08, 6.0), IRON)
	out.append([p + Vector3(0, 1.5, 0), Vector3(2.7, 3.0, 14.0)])


## Two steel rails from `a` to `b` (axis-aligned), set into the road.
static func rails(mb, a: Vector3, b: Vector3, rusty := false) -> void:
	var color := STEEL if not rusty else Color(0.5, 0.35, 0.25)
	var mid := (a + b) * 0.5
	var d := b - a
	var across := Vector3(absf(d.normalized().z), 0, absf(d.normalized().x))
	for side in [-0.75, 0.75]:
		mb.box(mid + across * side + Vector3(0, 0.02, 0), Vector3(absf(d.x) + 0.08, 0.04, absf(d.z) + 0.08), color)


## Zebra crosswalk across a road; stripes run along `along`.
static func crosswalk(mb, center: Vector3, along: Vector3, width := 10.0) -> void:
	var across := Vector3(absf(along.z), 0, absf(along.x))
	for i in 7:
		var off := across * (-width * 0.43 + i * width * 0.143)
		mb.box(center + off + Vector3(0, 0.015, 0), along.abs() * 2.6 + across * 0.7 + Vector3(0, 0.02, 0), Color(0.93, 0.93, 0.9))


static func manhole(mb, p: Vector3) -> void:
	mb.cylinder(p, 0.45, 0.02, Color(0.25, 0.25, 0.27), 8)


## Adds a light pool to `glow` (if given) under the same placement as `mb`.
static func _pool(mb, glow, at: Vector3, radius: float, color: Color) -> void:
	if glow == null:
		return
	glow.xform = mb.xform
	glow.light_pool(at, Vector2(radius, radius), color)
	glow.xform = Transform3D.IDENTITY


## A string of festoon bulbs on a wire from `a` to `b` (both at wire height),
## sagging in the middle (Lantern Quarter streets).
static func festoon(mb, a: Vector3, b: Vector3, rng: RandomNumberGenerator) -> void:
	var bulbs := [Color(1.0, 0.8, 0.4), Color(1.0, 0.55, 0.35), Color(0.95, 0.9, 0.6), Color(0.6, 0.85, 1.0)]
	var n := int(a.distance_to(b) / 1.1)
	var prev := a
	for i in range(1, n + 1):
		var t := float(i) / n
		var q := a.lerp(b, t) - Vector3(0, sin(t * PI) * 0.9, 0)
		var mid := (prev + q) * 0.5
		var d := q - prev
		mb.box(mid, Vector3(absf(d.x) + 0.04, absf(d.y) + 0.04, absf(d.z) + 0.04), Color(0.08, 0.08, 0.08))
		if i < n:
			mb.box(q - Vector3(0, 0.12, 0), Vector3(0.16, 0.2, 0.16), MeshBuilder.glow(bulbs[rng.randi() % bulbs.size()], MeshBuilder.GLOW_LAMP))
		prev = q


## Café set on the sidewalk: round table, two chairs and a parasol.
static func cafe_table(mb, out: Array, p: Vector3, parasol: Color) -> void:
	var from := _start(mb, null)
	# Chairs sit either side along local X.
	mb.cylinder(p + Vector3(0, 0.15, 0), 0.05, 0.6, IRON, 4)
	mb.cylinder(p + Vector3(0, 0.75, 0), 0.4, 0.05, Color(0.92, 0.9, 0.85), 8)
	for side in [-0.7, 0.7]:
		mb.box(p + Vector3(side, 0.45, 0), Vector3(0.38, 0.06, 0.38), IRON)
		mb.box(p + Vector3(side * 1.25, 0.7, 0), Vector3(0.06, 0.5, 0.38), IRON)
	mb.cylinder(p + Vector3(0, 0.8, 0), 0.03, 1.4, Color(0.9, 0.9, 0.88), 4)
	mb.ball(p + Vector3(0, 2.3, 0), Vector3(1.2, 0.3, 1.2), parasol, 8, 2)
	out.append([p + Vector3(0, 0.5, 0), Vector3(1.6, 1.0, 0.8)])
	_breaks(mb, out, from, "cafe_table", null)


## A bollard (pedestrian lanes, plazas).
static func bollard(mb, out: Array, p: Vector3) -> void:
	mb.cylinder(p + Vector3(0, 0.15, 0), 0.13, 0.8, MeshBuilder.glow(Color(0.6, 0.62, 0.64), MeshBuilder.METAL), 8)
	mb.cylinder(p + Vector3(0, 0.75, 0), 0.135, 0.06, Color(0.95, 0.85, 0.35), 8)
	mb.ball(p + Vector3(0, 0.95, 0), Vector3(0.13, 0.06, 0.13), MeshBuilder.glow(Color(0.6, 0.62, 0.64), MeshBuilder.METAL), 8, 2)
	out.append([p + Vector3(0, 0.45, 0), Vector3(0.3, 0.9, 0.3)])


## A palm (Gilt District plazas and the boulevard): a gently leaning
## trunk (the siding code draws its rings), a crown of arching feather
## fronds folded along the rib, and a few dead fronds hanging under it.
static func palm(mb, out: Array, p: Vector3, rng: RandomNumberGenerator) -> void:
	var h := rng.randf_range(5.5, 8.0)
	var a0 := rng.randf() * TAU
	var lean := Vector3(cos(a0), 0, sin(a0)) * rng.randf_range(0.2, 0.8)
	var trunk := MeshBuilder.glow(Color(0.58, 0.5, 0.4), MeshBuilder.SIDING)
	var prev := p
	for i in 3:
		var t := (i + 1) / 3.0
		var q := p + Vector3(0, h * t, 0) + lean * t * t
		mb.limb(prev, q, lerpf(0.24, 0.16, i / 3.0), lerpf(0.24, 0.16, t), trunk, 6, false)
		prev = q
	var crown := prev + Vector3(0, 0.1, 0)
	mb.clump(crown, Vector3(0.42, 0.4, 0.42), Color(0.45, 0.42, 0.25), rng.randi(), 6, 3)
	var green := _leaf(Color(0.33, 0.46, 0.22).lerp(Color(0.42, 0.52, 0.25), rng.randf()))
	var turn := rng.randf() * TAU
	for i in 9:
		var a := turn + TAU * i / 9.0 + rng.randf_range(-0.15, 0.15)
		_frond(mb, crown, a, rng.randf_range(2.4, 3.1), rng.randf_range(0.5, 0.9), green if i % 2 == 0 else green.lightened(0.06))
	for i in 3:
		var a := turn + TAU * (i + 0.5) / 3.0
		_frond(mb, crown - Vector3(0, 0.2, 0), a, 1.6, -0.9, Color(0.55, 0.44, 0.3))
	out.append([p + Vector3(0, 1.5, 0), Vector3(0.45, 3.0, 0.45)])


## One frond from `base` toward yaw `a`: three segments rising by `rise`
## then drooping (a negative rise hangs it straight down), each a V folded
## along the rib, widest a third of the way out.
static func _frond(mb, base: Vector3, a: float, length: float, rise: float, color: Color) -> void:
	var d := Vector3(cos(a), 0, sin(a))
	var side := Vector3(-d.z, 0, d.x)
	var widths := [0.06, 0.42, 0.34, 0.04]
	var pts: Array[Vector3] = []
	for k in 4:
		var t := k / 3.0
		var y := rise * sin(t * PI * 0.75) - 1.1 * t * t if rise > 0.0 else rise * t * 1.6
		pts.append(base + d * length * t * (1.0 if rise > 0.0 else 0.45) + Vector3(0, y, 0))
	for k in 3:
		var tint := color.darkened(0.12) if k == 0 else (color if k == 1 else color.lightened(0.06))
		for sgn in [-1.0, 1.0]:
			var e0: Vector3 = pts[k] + side * sgn * widths[k] - Vector3(0, widths[k] * 0.35, 0)
			var e1: Vector3 = pts[k + 1] + side * sgn * widths[k + 1] - Vector3(0, widths[k + 1] * 0.35, 0)
			var n := (pts[k + 1] - pts[k]).cross(e0 - pts[k]).normalized()
			if n.y < 0.0:
				n = -n
			mb.quad(pts[k], pts[k + 1], e1, e0, n, tint)


## Oil stain, crack or patch on the asphalt (pure decoration).
static func road_mark(mb, p: Vector3, along: Vector3, rng: RandomNumberGenerator) -> void:
	var across := Vector3(absf(along.z), 0, absf(along.x))
	match rng.randi() % 3:
		0:
			mb.box(p + Vector3(0, 0.012, 0), along.abs() * rng.randf_range(0.8, 1.6) + across * rng.randf_range(0.6, 1.2) + Vector3(0, 0.02, 0), MeshBuilder.glow(Color(0.19, 0.19, 0.21), MeshBuilder.ASPHALT))
		1:
			for k in 3:
				var off := along * (k - 1) * 0.6 + across * rng.randf_range(-0.2, 0.2)
				mb.box(p + off + Vector3(0, 0.012, 0), along.abs() * 0.7 + across * 0.06 + Vector3(0, 0.02, 0), MeshBuilder.glow(Color(0.14, 0.14, 0.15), MeshBuilder.ASPHALT))
		_:
			mb.box(p + Vector3(0, 0.011, 0), along.abs() * rng.randf_range(2.0, 4.0) + across * rng.randf_range(1.5, 2.5) + Vector3(0, 0.02, 0), MeshBuilder.glow(Color(0.23, 0.23, 0.25), MeshBuilder.ASPHALT))


## A spray-painted tag on a wall facing -Z (local), centred at `p`.
static func graffiti(mb, p: Vector3, w: float, rng: RandomNumberGenerator) -> void:
	var inks := [Color(0.95, 0.3, 0.55), Color(0.3, 0.8, 0.95), Color(0.98, 0.85, 0.2), Color(0.5, 0.95, 0.4), Color(0.95, 0.5, 0.15), Color(0.65, 0.4, 0.95)]
	var base: Color = inks[rng.randi() % inks.size()]
	var outline: Color = Color(0.08, 0.08, 0.1)
	mb.box(p + Vector3(0, 0, -0.01), Vector3(w + 0.2, 1.1, 0.03), outline)
	var letters := int(w / 0.7)
	for i in letters:
		var x := -w * 0.5 + (i + 0.5) * w / letters
		var h := rng.randf_range(0.6, 1.0)
		mb.box(p + Vector3(x, rng.randf_range(-0.1, 0.1), -0.03), Vector3(w / letters * 0.8, h, 0.03), base if i % 2 == 0 else base.lightened(0.25))
	mb.box(p + Vector3(0, -0.3, -0.04), Vector3(w * 0.9, 0.08, 0.03), inks[rng.randi() % inks.size()])


static func _rot(yaw: float, size: Vector3) -> Vector3:
	return size if absf(sin(yaw)) < 0.5 else Vector3(size.z, size.y, size.x)
