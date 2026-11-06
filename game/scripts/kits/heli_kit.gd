extends RefCounted
## Code-built helicopters (#82), in the style of vehicle_kit.gd: smooth
## low-poly bodies in vertex colour, glass and paint sheen on the gloss
## builder. Forward is -z, the skids stand on y = 0. The rotors are their
## own meshes (main about +y at ROTOR_AT, tail about +x at TAIL_AT) so
## helicopter.gd can spin them.
##
## Kinds stay out of VehicleKit.KINDS: traffic, parking and the prewarm
## never pick them; vehicle_classes.gd maps both to the "heli" class.

const VehicleKit = preload("res://scripts/kits/vehicle_kit.gd")

const KINDS := {
	"heli": {"name": "Aurel Skylark", "category": "heli", "size": Vector3(2.3, 2.9, 7.4), "mass": 1.5,
		"health": 100.0, "rotor": 5.0, "blades": 2, "max_speed": 52.0, "lift": 1.85, "tilt": 26.0,
		"climb": 9.0, "yaw": 1.5, "rotor_at": Vector3(0.0, 2.66, 0.0), "tail_at": Vector3(0.16, 2.02, 5.4),
		"tail_r": 0.72, "scale": 1.0},
	"police_heli": {"name": "Skylark Patrol", "category": "heli", "size": Vector3(2.6, 3.2, 8.4), "mass": 1.9,
		"health": 140.0, "rotor": 5.6, "blades": 4, "max_speed": 50.0, "lift": 1.7, "tilt": 24.0,
		"climb": 8.0, "yaw": 1.3, "rotor_at": Vector3(0.0, 2.98, 0.0), "tail_at": Vector3(0.18, 2.26, 6.05),
		"tail_r": 0.8, "scale": 1.12},
}
const PAINTS := [Color(0.82, 0.14, 0.12), Color(0.93, 0.93, 0.92), Color(0.1, 0.24, 0.55), Color(0.95, 0.72, 0.1),
	Color(0.12, 0.4, 0.3)]
const BLADE := Color(0.13, 0.13, 0.14)
const TIP := Color(0.95, 0.75, 0.12)
const NAV_RED := Color(1.0, 0.12, 0.1)
const NAV_GREEN := Color(0.15, 1.0, 0.3)
const WHITE := Color(0.95, 0.95, 0.94)


static func is_heli(kind: String) -> bool:
	return KINDS.has(kind)


static func spec(kind: String) -> Dictionary:
	var s: Dictionary = KINDS.get(kind, KINDS.heli).duplicate()
	s["rider"] = false
	s["lean"] = 0.0 # vehicle.gd _jolt reads it (a car body's lean); the heli banks by _body_pose
	return s


## The fuselage, skids, fins and lights (not the rotors).
static func build(mb, kind: String, paint: Color, gloss = null) -> void:
	var g = gloss if gloss != null else mb
	var police := kind == "police_heli"
	var k: float = spec(kind).scale
	var body: Color = VehicleKit.POLICE_BLACK if police else paint
	var trim: Color = VehicleKit.TRIM
	var cowl: Color = WHITE if police else body.darkened(0.15)
	var v := func(x: float, y: float, z: float) -> Vector3: return Vector3(x, y, z) * k
	# Cabin pod and the canopy over its front.
	mb.smooth_ball(v.call(0, 1.3, -0.45), Vector3(0.84, 0.76, 1.55) * k, body, 12, 8)
	g.smooth_ball(v.call(0, 1.44, -1.12), Vector3(0.76, 0.64, 0.98) * k, VehicleKit.GLASS, 12, 6)
	# Belly and a band along the cabin's side (white on the police one).
	mb.rounded_slab(v.call(0, 0.72, -0.35), Vector3(1.2, 0.22, 2.4) * k, trim if not police else WHITE, 0.9)
	for x in [-1.0, 1.0]:
		mb.box(v.call(x * 0.8, 1.02, 0.25), Vector3(0.05, 0.16, 1.5) * k, WHITE if police else body.lightened(0.35))
		# Door seams.
		mb.box(v.call(x * 0.83, 1.32, -0.15), Vector3(0.02, 0.8, 0.03) * k, trim)
		mb.box(v.call(x * 0.8, 1.32, 0.75), Vector3(0.02, 0.7, 0.03) * k, trim)
	# Engine cowling, exhaust and the mast.
	mb.rounded_slab(v.call(0, 2.1, 0.4), Vector3(0.98, 0.5, 1.8) * k, cowl, 0.85)
	mb.cylinder(v.call(0, 2.0, 1.32), 0.12 * k, 0.2 * k, trim, 6)
	mb.cylinder(v.call(0, 2.3, 0.0), 0.1 * k, 0.4 * k, trim, 6)
	# Tail boom, fins and stabiliser.
	mb.limb(v.call(0, 1.52, 0.9), v.call(0, 1.78, 5.45), 0.36 * k, 0.13 * k, body, 8)
	mb.box(v.call(0, 2.3, 5.38), Vector3(0.07, 1.15, 0.62) * k, body)
	mb.box(v.call(0, 1.3, 5.4), Vector3(0.07, 0.5, 0.36) * k, body)
	mb.box(v.call(0, 1.7, 4.45), Vector3(1.7, 0.05, 0.36) * k, body)
	for x in [-1.0, 1.0]:
		mb.box(v.call(x * 0.86, 1.72, 4.45), Vector3(0.05, 0.3, 0.36) * k, body)
	if police:
		# Stripe down the boom, the unit number on the cowling for the
		# ground, a searchlight under the nose and flasher lenses.
		mb.box(v.call(0, 1.86, 3.0), Vector3(0.05, 0.08, 3.6) * k, WHITE)
		for x in [-0.22, 0.0, 0.22]:
			mb.box(v.call(x, 2.36, 0.4), Vector3(0.13, 0.02, 0.36) * k, VehicleKit.POLICE_BLACK)
		mb.ball(v.call(0, 0.62, -1.7), Vector3(0.2, 0.2, 0.2) * k, VehicleKit.RIM, 8, 4)
		mb.box(v.call(0, 0.78, -1.62), Vector3(0.12, 0.2, 0.12) * k, trim)
		mb.box(v.call(-0.2, 0.58, 0.9), Vector3(0.2, 0.08, 0.2) * k, Color(0.5, 0.06, 0.08))
		mb.box(v.call(0.2, 0.58, 0.9), Vector3(0.2, 0.08, 0.2) * k, Color(0.08, 0.18, 0.55))
	# Skids on their struts.
	for x in [-1.08, 1.08]:
		mb.limb(v.call(x, 0.07, -1.75), v.call(x, 0.07, 1.45), 0.055 * k, 0.055 * k, trim, 6)
		mb.limb(v.call(x, 0.07, -1.75), v.call(x, 0.32, -2.1), 0.055 * k, 0.05 * k, trim, 6)
		for z in [-0.95, 0.75]:
			mb.limb(v.call(x, 0.07, z), v.call(x * 0.52, 0.74, z), 0.05 * k, 0.05 * k, trim, 6)
	# Navigation lights: red to port (left), green to starboard, white tail,
	# and the red beacon on the cowling.
	mb.box(v.call(-0.9, 1.72, 4.45), Vector3(0.08, 0.08, 0.1) * k, NAV_RED)
	mb.box(v.call(0.9, 1.72, 4.45), Vector3(0.08, 0.08, 0.1) * k, NAV_GREEN)
	mb.box(v.call(0, 1.8, 5.72), Vector3(0.08, 0.08, 0.06) * k, WHITE)
	mb.box(v.call(0, 2.4, 1.0), Vector3(0.1, 0.08, 0.12) * k, NAV_RED)
	g.box(v.call(0, 1.95, -0.2), Vector3(0.5, 0.02, 0.6) * k, VehicleKit.SHEEN)


## The main rotor round its hub (origin): blades along x, painted tips.
static func build_rotor(mb, kind: String) -> void:
	var s := spec(kind)
	var r: float = s.rotor
	var n: int = s.blades
	mb.cylinder(Vector3(0, -0.1, 0), 0.17 * s.scale, 0.2 * s.scale, VehicleKit.TRIM, 8)
	for i in n:
		var a := TAU * i / n
		var dir := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-dir.z, 0, dir.x)
		var root := dir * 0.15
		var tip := dir * r
		var w: float = 0.15 * s.scale
		mb.quad(root + side * w, tip + side * w, tip - side * w, root - side * w, Vector3.UP, BLADE)
		mb.quad(root - side * w + Vector3(0, -0.04, 0), tip - side * w + Vector3(0, -0.04, 0), tip + side * w + Vector3(0, -0.04, 0), root + side * w + Vector3(0, -0.04, 0), Vector3.DOWN, BLADE)
		var t0 := dir * (r - 0.35)
		mb.quad(t0 + side * w + Vector3(0, 0.005, 0), tip + side * w + Vector3(0, 0.005, 0), tip - side * w + Vector3(0, 0.005, 0), t0 - side * w + Vector3(0, 0.005, 0), Vector3.UP, TIP)


## The tail rotor round its hub (origin), turning about x: blades along y.
static func build_tail_rotor(mb, kind: String) -> void:
	var s := spec(kind)
	var r: float = s.tail_r
	mb.box(Vector3.ZERO, Vector3(0.1, 0.14, 0.14), VehicleKit.TRIM, false)
	for sign in [-1.0, 1.0]:
		mb.box(Vector3(0.02, sign * r * 0.5, 0), Vector3(0.03, r, 0.13), BLADE)
		mb.box(Vector3(0.025, sign * (r - 0.08), 0), Vector3(0.035, 0.16, 0.135), TIP)


## A flat disc (the blur of the turning blades), drawn see-through.
static func build_disc(mb, radius: float) -> void:
	var poly := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		poly.append(Vector2(cos(a), sin(a)) * radius)
	mb.flat(poly, 0.0, Color(0.1, 0.1, 0.11))
