extends RefCounted
## Street props and dock gear. Positions are local to the current
## MeshBuilder.xform; small solid props add [center, size] collision boxes.

const IRON := Color(0.1, 0.12, 0.11)
const STEEL := Color(0.55, 0.57, 0.6)
const LAMP_GLOW := Color(1.0, 0.86, 0.45)
const LEAF := Color(0.25, 0.48, 0.24)
const MOSS := Color(0.6, 0.65, 0.55)
const BARK := Color(0.38, 0.27, 0.19)
const CONTAINERS := [Color(0.78, 0.28, 0.2), Color(0.2, 0.45, 0.72), Color(0.28, 0.58, 0.35), Color(0.88, 0.62, 0.2), Color(0.55, 0.55, 0.6)]


## Black cast-iron gas lamp with a warm lantern (Lantern Quarter).
static func gas_lamp(mb, out: Array, p: Vector3) -> void:
	mb.cylinder(p + Vector3(0, 0.15, 0), 0.09, 3.1, IRON, 4)
	mb.box(p + Vector3(0, 3.45, 0), Vector3(0.42, 0.55, 0.42), LAMP_GLOW)
	mb.box(p + Vector3(0, 3.8, 0), Vector3(0.55, 0.12, 0.55), IRON)
	out.append([p + Vector3(0, 1.5, 0), Vector3(0.3, 3.0, 0.3)])


## Modern street light; the arm reaches toward `dir` (over the road).
static func street_light(mb, out: Array, p: Vector3, dir: Vector3) -> void:
	mb.cylinder(p + Vector3(0, 0.15, 0), 0.1, 6.0, STEEL, 4)
	mb.box(p + dir * 1.2 + Vector3(0, 6.0, 0), Vector3(absf(dir.x) * 2.4 + 0.15, 0.12, absf(dir.z) * 2.4 + 0.15), STEEL)
	mb.box(p + dir * 2.3 + Vector3(0, 5.9, 0), Vector3(0.6, 0.15, 0.6), LAMP_GLOW)
	out.append([p + Vector3(0, 2.0, 0), Vector3(0.3, 4.0, 0.3)])


## Traffic light on a pole, signals facing along `dir`.
static func traffic_light(mb, out: Array, p: Vector3, dir: Vector3) -> void:
	mb.cylinder(p + Vector3(0, 0.15, 0), 0.1, 4.2, Color(0.2, 0.22, 0.2), 4)
	mb.box(p + Vector3(0, 4.2, 0), Vector3(0.45, 1.3, 0.45), Color(0.15, 0.16, 0.15))
	var face := p + dir * 0.24 + Vector3(0, 4.2, 0)
	mb.box(face + Vector3(0, 0.4, 0), Vector3(0.22, 0.22, 0.22), Color(0.9, 0.2, 0.15))
	mb.box(face, Vector3(0.22, 0.22, 0.22), Color(0.95, 0.75, 0.15))
	mb.box(face - Vector3(0, 0.4, 0), Vector3(0.22, 0.22, 0.22), Color(0.2, 0.85, 0.35))
	out.append([p + Vector3(0, 2.0, 0), Vector3(0.3, 4.0, 0.3)])


static func hydrant(mb, out: Array, p: Vector3) -> void:
	mb.cylinder(p + Vector3(0, 0.15, 0), 0.2, 0.7, Color(0.85, 0.18, 0.15), 6)
	mb.box(p + Vector3(0, 0.6, 0), Vector3(0.55, 0.14, 0.14), Color(0.85, 0.18, 0.15))
	mb.box(p + Vector3(0, 0.92, 0), Vector3(0.26, 0.12, 0.26), Color(0.95, 0.85, 0.3))
	out.append([p + Vector3(0, 0.5, 0), Vector3(0.45, 1.0, 0.45)])


static func bench(mb, out: Array, p: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	mb.box(p + b * Vector3(0, 0.5, 0), _rot(yaw, Vector3(1.8, 0.1, 0.5)), Color(0.45, 0.3, 0.18))
	mb.box(p + b * Vector3(0, 0.85, 0.22), _rot(yaw, Vector3(1.8, 0.5, 0.08)), Color(0.45, 0.3, 0.18))
	for side in [-0.8, 0.8]:
		mb.box(p + b * Vector3(side, 0.32, 0), _rot(yaw, Vector3(0.08, 0.35, 0.5)), IRON)
	out.append([p + Vector3(0, 0.5, 0), _rot(yaw, Vector3(1.8, 1.0, 0.6))])


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


## Picket or chain-link style fence between two points (posts plus rails).
static func fence(mb, out: Array, a: Vector3, b: Vector3, color: Color, height := 1.2) -> void:
	var dir := b - a
	var length := dir.length()
	var posts := maxi(2, int(length / 2.5) + 1)
	for i in posts:
		var p := a.lerp(b, float(i) / (posts - 1))
		mb.box(p + Vector3(0, height * 0.5, 0), Vector3(0.1, height, 0.1), color)
	var mid := (a + b) * 0.5
	var size := Vector3(absf(dir.x) + 0.06, 0.07, absf(dir.z) + 0.06)
	mb.box(mid + Vector3(0, height * 0.85, 0), size, color)
	mb.box(mid + Vector3(0, height * 0.35, 0), size, color)
	out.append([mid + Vector3(0, height * 0.5, 0), Vector3(absf(dir.x) + 0.15, height, absf(dir.z) + 0.15)])


## Wooden power pole; wires to `next` are drawn as thin sagless lines.
static func power_pole(mb, out: Array, p: Vector3, next = null) -> void:
	mb.cylinder(p + Vector3(0, 0.15, 0), 0.13, 7.5, BARK.lightened(0.1), 4)
	mb.box(p + Vector3(0, 7.2, 0), Vector3(1.6, 0.12, 0.12), BARK)
	if next != null:
		var q: Vector3 = next
		var mid := (p + q) * 0.5
		var d := q - p
		for off in [-0.7, 0.7]:
			mb.box(mid + Vector3(0, 7.3, 0) + Vector3(off, 0, 0) * absf(d.normalized().z) + Vector3(0, 0, off) * absf(d.normalized().x), Vector3(absf(d.x) + 0.08, 0.06, absf(d.z) + 0.08), Color(0.06, 0.06, 0.06))
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


static func _rot(yaw: float, size: Vector3) -> Vector3:
	return size if absf(sin(yaw)) < 0.5 else Vector3(size.z, size.y, size.x)
