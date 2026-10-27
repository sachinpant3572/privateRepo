extends RefCounted
## Street props and dock gear. Positions are local to the current
## MeshBuilder.xform; small solid props add [center, size] collision boxes.

const MeshBuilder = preload("res://scripts/mesh_builder.gd")

const IRON := Color(0.1, 0.12, 0.11)
const STEEL := Color(0.55, 0.57, 0.6)
const LAMP_GLOW := Color(1.0, 0.86, 0.45)
const LEAF := Color(0.25, 0.48, 0.24)
const MOSS := Color(0.6, 0.65, 0.55)
const BARK := Color(0.38, 0.27, 0.19)
const CONTAINERS := [Color(0.78, 0.28, 0.2), Color(0.2, 0.45, 0.72), Color(0.28, 0.58, 0.35), Color(0.88, 0.62, 0.2), Color(0.55, 0.55, 0.6)]


const POOL_WARM := Color(0.55, 0.38, 0.16)
const POOL_COOL := Color(0.4, 0.42, 0.38)
const LED := Color(0.92, 0.96, 1.0)
const AD_COLORS := [Color(0.95, 0.5, 0.3), Color(0.4, 0.75, 0.95), Color(0.9, 0.85, 0.4), Color(0.85, 0.45, 0.75)]
const SCOOTERS := [Color(0.2, 0.75, 0.4), Color(0.95, 0.4, 0.2), Color(0.15, 0.15, 0.15)]


## Black cast-iron gas lamp with a warm lantern (Lantern Quarter). With a
## `glow` builder, also the pool of light it throws at night.
static func gas_lamp(mb, out: Array, p: Vector3, glow = null) -> void:
	mb.cylinder(p + Vector3(0, 0.15, 0), 0.09, 3.1, IRON, 4)
	mb.box(p + Vector3(0, 3.45, 0), Vector3(0.42, 0.55, 0.42), MeshBuilder.glow(LAMP_GLOW, MeshBuilder.GLOW_LAMP))
	_pool(mb, glow, p + Vector3(0, 0.2, 0), 5.0, POOL_WARM)
	mb.box(p + Vector3(0, 3.8, 0), Vector3(0.55, 0.12, 0.55), IRON)
	out.append([p + Vector3(0, 1.5, 0), Vector3(0.3, 3.0, 0.3)])


## LED street light: a slim steel pole with a tapered arm toward `dir`
## (over the road) and a flat cobra head.
static func street_light(mb, out: Array, p: Vector3, dir: Vector3, glow = null) -> void:
	var steel := MeshBuilder.glow(STEEL, MeshBuilder.METAL)
	mb.box(p + Vector3(0, 0.35, 0), Vector3(0.3, 0.4, 0.3), steel)
	mb.cylinder(p + Vector3(0, 0.15, 0), 0.09, 6.2, steel, 5)
	mb.box(p + dir * 1.1 + Vector3(0, 6.15, 0), Vector3(absf(dir.x) * 2.2 + 0.08, 0.08, absf(dir.z) * 2.2 + 0.08), steel)
	mb.box(p + dir * 2.4 + Vector3(0, 6.08, 0), Vector3(absf(dir.x) * 0.5 + 0.32, 0.12, absf(dir.z) * 0.5 + 0.32), MeshBuilder.glow(Color(0.35, 0.37, 0.4), MeshBuilder.METAL))
	mb.box(p + dir * 2.4 + Vector3(0, 6.0, 0), Vector3(absf(dir.x) * 0.4 + 0.24, 0.06, absf(dir.z) * 0.4 + 0.24), MeshBuilder.glow(LED, MeshBuilder.GLOW_LAMP))
	_pool(mb, glow, p + dir * 2.4 + Vector3(0, 0.05, 0), 7.0, POOL_COOL)
	out.append([p + Vector3(0, 2.0, 0), Vector3(0.3, 4.0, 0.3)])


## Mast-arm traffic signal: the pole stands at p, the arm reaches 5 m over
## the road toward `dir` and carries two signal heads (lenses on both
## faces along the street), a traffic camera and a street-name sign.
static func traffic_light(mb, out: Array, p: Vector3, dir: Vector3) -> void:
	var paint := MeshBuilder.glow(Color(0.2, 0.22, 0.22), MeshBuilder.GLOSS)
	mb.cylinder(p + Vector3(0, 0.15, 0), 0.13, 6.0, paint, 6)
	var along := Vector3(absf(dir.z), 0, absf(dir.x))
	mb.box(p + dir * 2.6 + Vector3(0, 5.8, 0), Vector3(absf(dir.x) * 5.2 + 0.12, 0.12, absf(dir.z) * 5.2 + 0.12), paint)
	for k in 2:
		var head := p + dir * (2.4 + k * 2.2) + Vector3(0, 5.15, 0)
		mb.box(head, Vector3(0.36, 1.1, 0.36), Color(0.1, 0.1, 0.1))
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
	out.append([p + Vector3(0, 2.0, 0), Vector3(0.35, 4.0, 0.35)])


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
	mb.cylinder(p + Vector3(-2.4, 0.15, -0.3), 0.05, 2.8, STEEL, 4)
	mb.box(p + Vector3(-2.4, 2.75, -0.3), Vector3(0.5, 0.5, 0.05), Color(0.15, 0.35, 0.75))
	out.append([p + Vector3(0, 1.2, 0.6), Vector3(3.8, 2.4, 0.6)])
	out.append([p + Vector3(-2.4, 1.2, -0.3), Vector3(0.2, 2.4, 0.2)])


## Electric-vehicle charging post with a lit status ring and a holstered
## cable.
static func ev_charger(mb, out: Array, p: Vector3) -> void:
	mb.box(p + Vector3(0, 0.2, 0), Vector3(0.6, 0.1, 0.45), MeshBuilder.glow(Color(0.6, 0.6, 0.6), MeshBuilder.CONCRETE))
	mb.box(p + Vector3(0, 0.95, 0), Vector3(0.42, 1.5, 0.28), MeshBuilder.glow(Color(0.92, 0.93, 0.94), MeshBuilder.GLOSS))
	mb.box(p + Vector3(0, 1.45, -0.15), Vector3(0.3, 0.32, 0.04), MeshBuilder.glow(Color(0.1, 0.12, 0.15), MeshBuilder.GLASS))
	mb.box(p + Vector3(0, 1.72, 0), Vector3(0.44, 0.06, 0.3), MeshBuilder.glow(Color(0.2, 0.75, 1.0), MeshBuilder.GLOW_NEON))
	mb.box(p + Vector3(0.24, 0.95, -0.05), Vector3(0.1, 0.25, 0.12), Color(0.12, 0.12, 0.12))
	out.append([p + Vector3(0, 0.8, 0), Vector3(0.45, 1.6, 0.35)])


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


## Recycling and rubbish bins side by side (black and blue lids).
static func bins(mb, out: Array, p: Vector3) -> void:
	for k in 2:
		var c := Color(0.2, 0.22, 0.24) if k == 0 else Color(0.15, 0.35, 0.65)
		var q := p + Vector3(k * 0.7 - 0.35, 0, 0)
		mb.box(q + Vector3(0, 0.55, 0), Vector3(0.6, 0.9, 0.6), MeshBuilder.glow(c, MeshBuilder.GLOSS))
		mb.box(q + Vector3(0, 1.03, 0), Vector3(0.64, 0.06, 0.64), MeshBuilder.glow(c.darkened(0.25), MeshBuilder.GLOSS))
	out.append([p + Vector3(0, 0.55, 0), Vector3(1.3, 1.1, 0.6)])


## Wayfinding totem: a slim slab with a lit city map on its face (-Z).
static func wayfinding(mb, out: Array, p: Vector3) -> void:
	mb.box(p + Vector3(0, 1.3, 0), Vector3(0.9, 2.3, 0.2), MeshBuilder.glow(Color(0.18, 0.2, 0.24), MeshBuilder.GLOSS))
	mb.box(p + Vector3(0, 1.4, -0.11), Vector3(0.7, 1.4, 0.04), MeshBuilder.glow(Color(0.85, 0.88, 0.8), MeshBuilder.GLOW_NEON))
	mb.box(p + Vector3(0, 2.3, -0.12), Vector3(0.7, 0.2, 0.04), Color(0.95, 0.75, 0.2))
	out.append([p + Vector3(0, 1.2, 0), Vector3(0.9, 2.4, 0.25)])


## Parking pay station.
static func pay_station(mb, out: Array, p: Vector3) -> void:
	mb.box(p + Vector3(0, 0.8, 0), Vector3(0.35, 1.3, 0.3), MeshBuilder.glow(Color(0.2, 0.3, 0.5), MeshBuilder.GLOSS))
	mb.box(p + Vector3(0, 1.2, -0.16), Vector3(0.24, 0.2, 0.03), MeshBuilder.glow(Color(0.6, 0.85, 0.7), MeshBuilder.GLOW_NEON))
	out.append([p + Vector3(0, 0.7, 0), Vector3(0.35, 1.4, 0.3)])


static func hydrant(mb, out: Array, p: Vector3) -> void:
	mb.cylinder(p + Vector3(0, 0.15, 0), 0.2, 0.7, Color(0.85, 0.18, 0.15), 6)
	mb.box(p + Vector3(0, 0.6, 0), Vector3(0.55, 0.14, 0.14), Color(0.85, 0.18, 0.15))
	mb.box(p + Vector3(0, 0.92, 0), Vector3(0.26, 0.12, 0.26), Color(0.95, 0.85, 0.3))
	out.append([p + Vector3(0, 0.5, 0), Vector3(0.45, 1.0, 0.45)])


## Park bench facing -Z after turning by `yaw`.
static func bench(mb, out: Array, p: Vector3, yaw: float) -> void:
	var saved: Transform3D = mb.xform
	mb.xform = saved * Transform3D(Basis(Vector3.UP, yaw), p)
	mb.box(Vector3(0, 0.5, 0), Vector3(1.8, 0.1, 0.5), Color(0.45, 0.3, 0.18))
	mb.box(Vector3(0, 0.85, 0.22), Vector3(1.8, 0.5, 0.08), Color(0.45, 0.3, 0.18))
	for side in [-0.8, 0.8]:
		mb.box(Vector3(side, 0.32, 0), Vector3(0.08, 0.35, 0.5), IRON)
	mb.xform = saved
	out.append([p + Vector3(0, 0.5, 0), Vector3(1.8, 1.0, 0.6), yaw])


static func trash_can(mb, out: Array, p: Vector3) -> void:
	mb.cylinder(p + Vector3(0, 0.15, 0), 0.3, 0.95, Color(0.22, 0.32, 0.26), 6)
	mb.cylinder(p + Vector3(0, 1.1, 0), 0.33, 0.08, Color(0.15, 0.2, 0.17), 6)
	out.append([p + Vector3(0, 0.5, 0), Vector3(0.6, 1.0, 0.6)])


static func mailbox(mb, out: Array, p: Vector3) -> void:
	mb.box(p + Vector3(0, 0.65, 0), Vector3(0.5, 1.0, 0.45), Color(0.15, 0.3, 0.65))
	mb.box(p + Vector3(0, 1.2, 0), Vector3(0.52, 0.12, 0.47), Color(0.12, 0.24, 0.55))
	out.append([p + Vector3(0, 0.6, 0), Vector3(0.5, 1.2, 0.45)])


## Live oak: a broad, layered crown with grey Spanish moss hanging off it.
static func oak(mb, out: Array, p: Vector3, rng: RandomNumberGenerator) -> void:
	var s := rng.randf_range(0.85, 1.2)
	mb.cylinder(p + Vector3(0, 0.15, 0), 0.32 * s, 3.0 * s, BARK, 5)
	var leaf := LEAF.lerp(Color(0.32, 0.55, 0.25), rng.randf())
	mb.ball(p + Vector3(0, 3.6 * s, 0), Vector3(2.8, 1.5, 2.6) * s, leaf, 7, 3)
	mb.ball(p + Vector3(1.3, 4.4, 0.6) * s, Vector3(1.8, 1.2, 1.7) * s, leaf.lightened(0.1), 6, 3)
	mb.ball(p + Vector3(-1.2, 4.2, -0.8) * s, Vector3(1.6, 1.1, 1.5) * s, leaf.darkened(0.1), 6, 3)
	for i in 3:
		var a := TAU * i / 3.0 + rng.randf()
		mb.box(p + Vector3(cos(a) * 2.2, 2.6, sin(a) * 2.2) * s, Vector3(0.25, 0.9, 0.12) * s, MOSS)
	out.append([p + Vector3(0, 1.5, 0), Vector3(0.7, 3.0, 0.7)])


## Small flowering crepe myrtle (pink or white).
static func crepe_myrtle(mb, out: Array, p: Vector3, rng: RandomNumberGenerator) -> void:
	var bloom := Color(0.95, 0.55, 0.75) if rng.randf() < 0.7 else Color(0.97, 0.95, 0.95)
	mb.cylinder(p + Vector3(0, 0.15, 0), 0.15, 1.8, BARK.lightened(0.15), 4)
	mb.ball(p + Vector3(0, 2.5, 0), Vector3(1.2, 1.0, 1.2), bloom, 6, 3)
	out.append([p + Vector3(0, 1.0, 0), Vector3(0.4, 2.0, 0.4)])


static func planter(mb, out: Array, p: Vector3) -> void:
	mb.box(p + Vector3(0, 0.45, 0), Vector3(1.4, 0.6, 1.4), Color(0.6, 0.58, 0.55))
	mb.ball(p + Vector3(0, 1.0, 0), Vector3(0.65, 0.45, 0.65), LEAF.lightened(0.1), 5, 2)
	out.append([p + Vector3(0, 0.5, 0), Vector3(1.4, 1.0, 1.4)])


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
	mb.box(p + Vector3(0, size * 0.5, 0), Vector3(size, size, size), Color(0.62, 0.45, 0.25))
	mb.box(p + Vector3(0, size * 0.5, 0), Vector3(size + 0.04, size * 0.15, size + 0.04), Color(0.45, 0.32, 0.18))
	out.append([p + Vector3(0, size * 0.5, 0), Vector3(size, size, size)])


static func barrel(mb, out: Array, p: Vector3, color := Color(0.25, 0.4, 0.65)) -> void:
	mb.cylinder(p + Vector3(0, 0.15, 0), 0.38, 1.1, color, 6)
	mb.cylinder(p + Vector3(0, 0.6, 0), 0.4, 0.08, color.darkened(0.3), 6)
	out.append([p + Vector3(0, 0.6, 0), Vector3(0.8, 1.2, 0.8)])


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


## Dockside gantry crane: four legs, a boom along X reaching over the water.
static func crane(mb, out: Array, p: Vector3) -> void:
	var yellow := Color(0.95, 0.72, 0.15)
	for x in [-4.0, 4.0]:
		for z in [-3.0, 3.0]:
			mb.box(p + Vector3(x, 7.0, z), Vector3(0.6, 14.0, 0.6), yellow)
			out.append([p + Vector3(x, 2.0, z), Vector3(0.8, 4.0, 0.8)])
	mb.box(p + Vector3(0, 14.4, 0), Vector3(9.0, 0.8, 7.0), yellow.darkened(0.15))
	mb.box(p + Vector3(0, 15.4, 8.0), Vector3(1.4, 1.0, 26.0), yellow)
	mb.box(p + Vector3(0, 16.4, -2.0), Vector3(3.0, 2.0, 3.0), Color(0.3, 0.32, 0.35))
	mb.box(p + Vector3(0, 11.0, 14.0), Vector3(0.08, 8.0, 0.08), Color(0.1, 0.1, 0.1))
	mb.box(p + Vector3(0, 7.0, 14.0), Vector3(2.4, 0.4, 1.2), Color(0.2, 0.2, 0.22))


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
	# Chairs sit either side along local X.
	mb.cylinder(p + Vector3(0, 0.15, 0), 0.05, 0.6, IRON, 4)
	mb.cylinder(p + Vector3(0, 0.75, 0), 0.4, 0.05, Color(0.92, 0.9, 0.85), 8)
	for side in [-0.7, 0.7]:
		mb.box(p + Vector3(side, 0.45, 0), Vector3(0.38, 0.06, 0.38), IRON)
		mb.box(p + Vector3(side * 1.25, 0.7, 0), Vector3(0.06, 0.5, 0.38), IRON)
	mb.cylinder(p + Vector3(0, 0.8, 0), 0.03, 1.4, Color(0.9, 0.9, 0.88), 4)
	mb.ball(p + Vector3(0, 2.3, 0), Vector3(1.2, 0.3, 1.2), parasol, 8, 2)
	out.append([p + Vector3(0, 0.5, 0), Vector3(1.6, 1.0, 0.8)])


## A bollard (pedestrian lanes, plazas).
static func bollard(mb, out: Array, p: Vector3) -> void:
	mb.cylinder(p + Vector3(0, 0.15, 0), 0.14, 0.8, IRON, 5)
	mb.box(p + Vector3(0, 0.75, 0), Vector3(0.3, 0.06, 0.3), Color(0.85, 0.7, 0.3))
	out.append([p + Vector3(0, 0.45, 0), Vector3(0.3, 0.9, 0.3)])


## A palm (Gilt District plazas and the boulevard).
static func palm(mb, out: Array, p: Vector3, rng: RandomNumberGenerator) -> void:
	var h := rng.randf_range(5.0, 7.0)
	mb.cylinder(p + Vector3(0, 0.15, 0), 0.18, h, BARK.lightened(0.25), 5)
	for i in 6:
		var a := TAU * i / 6.0 + rng.randf()
		var d := Vector3(cos(a), 0, sin(a))
		mb.box(p + Vector3(0, h + 0.1, 0) + d * 1.1, Vector3(absf(d.x) * 2.0 + 0.5, 0.12, absf(d.z) * 2.0 + 0.5), LEAF.lightened(0.15))
	mb.ball(p + Vector3(0, h + 0.2, 0), Vector3(0.5, 0.4, 0.5), LEAF, 5, 2)
	out.append([p + Vector3(0, 1.5, 0), Vector3(0.4, 3.0, 0.4)])


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
