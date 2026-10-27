extends RefCounted
## Modern (2020s) vehicles, low poly but detailed. Local space: forward is
## -Z, ground at y = 0. Car bodies are lofted through cross-sections (low
## hood, raked windscreen, tapered glass cabin, short deck), so each kind
## reads from the 3/4 top-down camera by its roof, glass and light bars,
## plus handling numbers used by vehicle.gd.
##
## Paint shells and glass go into `gloss`, a second MeshBuilder that
## vehicle.gd draws with MeshBuilder.gloss_material(); tyres, black trim,
## lights and markings stay on the matte `mb`. Without `gloss` everything
## goes into `mb` (the asset gallery).

const KINDS := {
	"sedan": {"size": Vector3(1.9, 1.4, 4.2), "max_speed": 24.0, "accel": 14.0, "turn": 2.4},
	"taxi": {"size": Vector3(1.9, 1.4, 4.2), "max_speed": 24.0, "accel": 14.0, "turn": 2.4},
	"police": {"size": Vector3(1.95, 1.4, 4.4), "max_speed": 27.0, "accel": 16.0, "turn": 2.5},
	"pickup": {"size": Vector3(2.0, 1.6, 4.9), "max_speed": 22.0, "accel": 12.0, "turn": 2.1},
	"van": {"size": Vector3(2.0, 2.2, 4.8), "max_speed": 20.0, "accel": 11.0, "turn": 2.0},
	"sports": {"size": Vector3(1.95, 1.1, 4.1), "max_speed": 31.0, "accel": 19.0, "turn": 2.8},
	"scooter": {"size": Vector3(0.8, 1.2, 1.9), "max_speed": 18.0, "accel": 14.0, "turn": 3.4, "rider": true},
}
## Weighted pick list for civilian traffic and parked cars.
const CIVILIAN := ["sedan", "sedan", "sedan", "pickup", "van", "sports", "taxi", "taxi"]
const PAINTS := [
	Color(0.82, 0.16, 0.16), Color(0.15, 0.35, 0.75), Color(0.95, 0.95, 0.95), Color(0.15, 0.15, 0.17),
	Color(0.2, 0.55, 0.32), Color(0.6, 0.3, 0.62), Color(0.95, 0.55, 0.18), Color(0.55, 0.58, 0.62),
]
const GLASS := Color(0.09, 0.12, 0.16)
## Fake sky reflection streaked across glass, so it reads as glass in any light.
const SHEEN := Color(0.4, 0.48, 0.56)
## Black plastic and gloss-black pillars: bumpers, sills, intakes, mirrors.
const TRIM := Color(0.07, 0.07, 0.08)
const TYRE := Color(0.05, 0.05, 0.05)
const RIM := Color(0.74, 0.76, 0.79)
const SPOKE_GAP := Color(0.12, 0.12, 0.13)
const HEAD := Color(1.0, 0.98, 0.9)
const TAIL := Color(0.9, 0.05, 0.07)
const PLATE := Color(0.88, 0.88, 0.82)
const AMBER := Color(1.0, 0.6, 0.1)
const TAXI_YELLOW := Color(0.98, 0.78, 0.12)
const POLICE_BLACK := Color(0.06, 0.07, 0.09)
const VAN_WHITE := Color(0.92, 0.93, 0.94)


static func size_of(kind: String) -> Vector3:
	return KINDS.get(kind, KINDS.sedan).size


static func build(mb, kind: String, paint: Color, gloss = null) -> void:
	var g = gloss if gloss != null else mb
	match kind:
		"taxi":
			_taxi(mb, g)
		"police":
			_police(mb, g)
		"pickup":
			_pickup(mb, g, paint)
		"van":
			_van(mb, g, paint)
		"sports":
			_sports(mb, g, paint)
		"scooter":
			_scooter(mb, g, paint)
		_:
			_sedan(mb, g, paint)


# --- Kinds -------------------------------------------------------------------

## Mid-size saloon: low hood, raked screen, glass cabin with black B-pillars,
## short deck; some have a panoramic glass roof.
static func _sedan(mb, g, paint: Color, roof = null) -> Array:
	var st := [[-2.1, 0.88, 0.26, 0.64], [-1.9, 0.94, 0.22, 0.8], [-0.8, 0.95, 0.22, 0.9],
		[1.5, 0.95, 0.22, 0.94], [1.86, 0.94, 0.24, 0.96], [2.1, 0.88, 0.3, 0.8]]
	var cab := [[-0.8, 0, 0], [0.0, 0.62, 1.38], [0.3, 0.62, 1.39], [0.42, 0.62, 1.39], [0.95, 0.6, 1.36], [1.5, 0, 0]]
	var top: Color = roof if roof != null else paint
	_hull(mb, g, st, paint, Vector2(-0.8, 1.5))
	var c := _cabin(g, st, cab, [[GLASS, GLASS], [top, GLASS], [top, TRIM], [top, GLASS], [GLASS, paint]])
	_glass_sheen(g, c, 0)
	_glass_sheen(g, c, 4)
	if roof == null and _panoramic(paint):
		# Glass roof panel framed by the painted roof edges.
		var roof_st := []
		for i in range(1, cab.size() - 1):
			roof_st.append([cab[i][0], cab[i][1], 0.0, cab[i][2]])
		_top_decal(g, roof_st, -0.5, 0.5, 0.08, 0.86, GLASS, 0.006)
		_top_decal(g, roof_st, -0.12, 0.02, 0.12, 0.82, SHEEN, 0.01)
	_wheels(mb, st, [-1.33, 1.33], 0.34)
	_lamps(mb, st)
	_seams(mb, st, paint, -1.86, 1.54, [-0.74, 0.36, 1.32], [-0.62, 0.62], -0.83)
	_mirrors(mb, st, -0.6)
	return st


## Hybrid taxi: the saloon in yellow with a slim lit roof sign and a black
## checker band between the wheels.
static func _taxi(mb, g) -> void:
	var st := _sedan(mb, g, TAXI_YELLOW, TAXI_YELLOW)
	mb.box(Vector3(0, 1.405, 0.3), Vector3(0.68, 0.03, 0.26), TRIM)
	mb.box(Vector3(0, 1.48, 0.3), Vector3(0.58, 0.13, 0.17), Color(1.0, 0.96, 0.78))
	_side_decal(mb, st, -0.92, 0.92, 0.52, 0.6, TRIM)
	for i in 7:
		if i % 2 == 0:
			var z := -0.92 + i * (1.84 / 7.0)
			_side_decal(mb, st, z, z + 1.84 / 7.0, 0.53, 0.59, Color.WHITE, 0.012)


## Police interceptor (SUV build): black with white doors and roof, slim
## red/blue LED bar (vehicle.gd flashes it), push bar.
static func _police(mb, g) -> void:
	var st := [[-2.2, 0.9, 0.3, 0.78], [-2.02, 0.96, 0.26, 0.96], [-0.95, 0.975, 0.26, 1.02], [-0.72, 0.975, 0.26, 1.02],
		[1.08, 0.975, 0.26, 1.03], [1.9, 0.975, 0.26, 1.04], [2.12, 0.96, 0.28, 1.02], [2.2, 0.92, 0.32, 0.9]]
	var cab := [[-0.95, 0, 0], [-0.3, 0.68, 1.4], [0.3, 0.68, 1.4], [0.42, 0.68, 1.4], [1.1, 0.67, 1.39],
		[1.22, 0.67, 1.39], [1.76, 0.65, 1.37], [1.9, 0, 0]]
	var white := Color(0.95, 0.95, 0.95)
	var sides := [null, null, null, white, null, null, null]
	_hull(mb, g, st, POLICE_BLACK, Vector2(-0.95, 1.9), sides)
	var c := _cabin(g, st, cab, [[GLASS, GLASS], [white, GLASS], [white, TRIM], [white, GLASS], [white, TRIM],
		[white, GLASS], [GLASS, TRIM]])
	_glass_sheen(g, c, 0)
	_glass_sheen(g, c, 6)
	_wheels(mb, st, [-1.42, 1.42], 0.37, 0.28, Color(0.3, 0.31, 0.33))
	_lamps(mb, st)
	_seams(mb, st, POLICE_BLACK, -1.98, -INF, [-0.7, 0.38, 1.06])
	_side_decal(mb, st, -0.7, 1.06, 0.66, 0.7, Color(0.15, 0.3, 0.75), 0.012)
	_mirrors(mb, st, -0.72)
	# Push bar.
	for x in [-0.36, 0.36]:
		mb.box(Vector3(x, 0.56, -2.26), Vector3(0.11, 0.56, 0.11), TRIM)
	mb.box(Vector3(0, 0.7, -2.28), Vector3(0.95, 0.12, 0.11), TRIM)
	# Low-profile light bar: dim lenses, lit by vehicle.gd's flashers.
	mb.box(Vector3(0, 1.415, 0.35), Vector3(1.3, 0.03, 0.28), TRIM)
	mb.box(Vector3(-0.31, 1.465, 0.35), Vector3(0.5, 0.11, 0.24), Color(0.5, 0.06, 0.08))
	mb.box(Vector3(0.31, 1.465, 0.35), Vector3(0.5, 0.11, 0.24), Color(0.08, 0.18, 0.55))


## Crew-cab pickup: tall blunt nose with a big grille, four-door cab, bed
## with a dark ribbed liner, roof rails and amber cab lights.
static func _pickup(mb, g, paint: Color) -> void:
	var st := [[-2.45, 0.93, 0.36, 0.9], [-2.32, 0.99, 0.3, 1.1], [-1.0, 1.0, 0.3, 1.16], [0.62, 1.0, 0.3, 1.18]]
	var cab := [[-1.0, 0, 0], [-0.38, 0.74, 1.6], [0.02, 0.74, 1.6], [0.13, 0.74, 1.6], [0.52, 0.74, 1.6], [0.62, 0, 0]]
	_hull(mb, g, st, paint, Vector2(-1.0, 0.62))
	var c := _cabin(g, st, cab, [[GLASS, GLASS], [paint, GLASS], [paint, TRIM], [paint, GLASS], [GLASS, paint]])
	_glass_sheen(g, c, 0)
	_wheels(mb, st, [-1.6], 0.4, 0.3)
	for s in [-1.0, 1.0]:
		_wheel(mb, s * 1.012, 1.62, 0.4, 0.3, RIM, true)
	_lamps(mb, st, true, false)
	_end_decal(mb, -2.45, -1.0, -0.5, 0.5, 0.56, 0.84, TRIM, 0.008) # grille
	_seams(mb, st, paint, -2.3, -INF, [-0.95, -0.02, 0.58], [-0.72, 0.72], -1.03)
	_mirrors(mb, st, -0.82, 0.04, Vector3(0.2, 0.15, 0.14))
	for x in [-0.6, 0.6]:
		mb.box(Vector3(x, 1.62, 0.07), Vector3(0.06, 0.04, 0.9), TRIM)
	for x in [-0.3, 0.0, 0.3]:
		mb.box(Vector3(x, 1.605, -0.35), Vector3(0.1, 0.03, 0.05), AMBER)
	# Bed: sides, tailgate, liner with ribs, rail caps, bumper, tail lamps.
	for s in [-1.0, 1.0]:
		g.box(Vector3(s * 0.93, 0.74, 1.52), Vector3(0.14, 0.88, 1.8), paint)
		mb.box(Vector3(s * 0.93, 1.19, 1.52), Vector3(0.15, 0.02, 1.8), TRIM)
		_quad_x(mb, s * 1.004, 0.66, 2.42, 0.3, 0.46, TRIM)
		mb.box(Vector3(s * 0.92, 0.96, 2.43), Vector3(0.14, 0.34, 0.04), TAIL)
	g.box(Vector3(0, 0.74, 2.38), Vector3(1.72, 0.84, 0.12), paint)
	mb.box(Vector3(0, 0.82, 1.5), Vector3(1.72, 0.02, 1.76), Color(0.17, 0.17, 0.18))
	for x in [-0.5, -0.17, 0.17, 0.5]:
		mb.box(Vector3(x, 0.835, 1.5), Vector3(0.05, 0.02, 1.7), Color(0.24, 0.24, 0.25))
	mb.box(Vector3(0, 0.4, 2.48), Vector3(1.9, 0.16, 0.14), TRIM)
	_end_decal(mb, 2.44, 1.0, -0.22, 0.22, 0.62, 0.72, PLATE)


## Delivery van: short sloping hood, tall raked windscreen, high-roof cargo
## box with a sliding door, livery stripe in the paint colour, roof ribs.
static func _van(mb, g, paint: Color) -> void:
	var body := VAN_WHITE if paint.get_luminance() < 0.8 else Color(0.62, 0.65, 0.68)
	var st := [[-2.4, 0.92, 0.32, 0.74], [-2.22, 0.98, 0.28, 0.98], [-1.6, 1.0, 0.28, 1.16], [2.4, 1.0, 0.28, 1.2]]
	_hull(mb, g, st, body, Vector2(-1.6, 2.4))
	# Upper body: sections [belt, window top, roof edge] each side.
	var zs := [-1.6, -0.92, -0.35, 2.4]
	var secs := []
	for i in zs.size():
		var z: float = zs[i]
		var wb := _at(st, z, 1) * 0.97
		var yb := _at(st, z, 3) - 0.08
		if i == 0:
			secs.append([Vector2(-wb, yb), Vector2(-wb, yb), Vector2(-wb, yb), Vector2(wb, yb), Vector2(wb, yb), Vector2(wb, yb)])
		else:
			secs.append([Vector2(-wb, yb), Vector2(-wb, 1.82), Vector2(-0.86, 2.2), Vector2(0.86, 2.2), Vector2(wb, 1.82), Vector2(wb, yb)])
	var looks := [[GLASS, TRIM, GLASS], [GLASS, body, body], [body, body, body]]
	var skin := func(s: int, e: int) -> Array: return [g, looks[s][mini(e, 4 - e)]]
	_loft(zs, secs, skin)
	_cap(g, secs[-1], 2.4, 1.0, body)
	_glass_sheen(g, [zs, secs], 0, 2)
	_wheels(mb, st, [-1.55, 1.55], 0.38, 0.28)
	_lamps(mb, st, true, false)
	_seams(mb, st, body, -2.2, -INF, [-1.55, -0.33, 0.92])
	for s in [-1.0, 1.0]:
		# Livery stripe, sliding door track and cab door window frame.
		_quad_x(mb, s * 0.976, -0.3, 2.36, 1.28, 1.44, paint)
		_quad_x(mb, s * 0.978, 0.95, 2.2, 1.14, 1.17, TRIM)
		_quad_x(mb, s * 0.978, -0.35, -0.32, 1.12, 2.0, body.darkened(0.45))
		_quad_x(mb, s * 0.978, 0.9, 0.93, 1.12, 2.0, body.darkened(0.45))
		mb.box(Vector3(s * 0.88, 1.45, 2.41), Vector3(0.16, 0.7, 0.02), TAIL)
	_mirrors(mb, st, -1.45, 0.25, Vector3(0.14, 0.26, 0.14))
	# Rear doors: split line, windows, bumper, plate.
	_end_decal(mb, 2.4, 1.0, -0.015, 0.015, 0.45, 2.1, body.darkened(0.45))
	for x in [-0.45, 0.45]:
		_end_decal(mb, 2.4, 1.0, x - 0.3, x + 0.3, 1.5, 1.95, GLASS)
	_end_decal(mb, 2.4, 1.0, -0.9, 0.9, 0.28, 0.48, TRIM, 0.01)
	_end_decal(mb, 2.4, 1.0, -0.22, 0.22, 0.5, 0.6, PLATE, 0.012)
	for z in [-0.1, 0.4, 0.9, 1.4, 1.9]:
		g.box(Vector3(0, 2.205, z), Vector3(1.6, 0.02, 0.05), body.darkened(0.12))


## Sports coupe: low, coke-bottle waist with wide haunches, long fastback
## glass, ducktail spoiler, hood vents, diffuser with fins.
static func _sports(mb, g, paint: Color) -> void:
	var st := [[-2.05, 0.86, 0.2, 0.5], [-1.8, 0.95, 0.16, 0.6], [-1.25, 0.975, 0.16, 0.66], [-0.6, 0.93, 0.16, 0.72],
		[0.95, 0.975, 0.16, 0.77], [1.55, 0.975, 0.18, 0.8], [1.9, 0.95, 0.2, 0.82], [2.05, 0.88, 0.24, 0.66]]
	var cab := [[-0.6, 0, 0], [0.05, 0.56, 1.08], [0.55, 0.54, 1.07], [1.55, 0, 0]]
	_hull(mb, g, st, paint, Vector2(-0.6, 1.55))
	var c := _cabin(g, st, cab, [[GLASS, GLASS], [paint, GLASS], [GLASS, paint]])
	_glass_sheen(g, c, 0)
	_glass_sheen(g, c, 2)
	_wheels(mb, st, [-1.3, 1.3], 0.34, 0.28)
	_lamps(mb, st)
	_seams(mb, st, paint, -1.76, 1.58, [-0.58, 0.6], [-0.55, 0.55], -0.63)
	_mirrors(mb, st, -0.4, 0.03, Vector3(0.16, 0.1, 0.12))
	for x in [-0.3, 0.3]:
		_top_decal(mb, st, x - 0.12, x + 0.12, -1.3, -1.05, TRIM)
	_side_decal(mb, st, 0.62, 0.9, 0.3, 0.5, TRIM)
	g.box(Vector3(0, 0.84, 1.93), Vector3(1.62, 0.11, 0.12), TRIM)
	_end_decal(mb, 2.05, 1.0, -0.72, 0.72, 0.2, 0.36, TRIM, 0.01)
	for x in [-0.36, -0.12, 0.12, 0.36]:
		mb.box(Vector3(x, 0.28, 2.1), Vector3(0.03, 0.14, 0.12), Color(0.2, 0.2, 0.22))


## Electric moped: slim tyres, sculpted body under the seat, leg shield,
## round LED headlight in the bar cover, small TFT dash. The rider sits on
## it (vehicle.gd keeps them visible).
static func _scooter(mb, g, paint: Color) -> void:
	for z in [-0.68, 0.68]:
		for s in [-1.0, 1.0]:
			_wheel(mb, s * 0.065, z, 0.24, 0.065, Color(0.55, 0.56, 0.58), false, 0)
	# Rear body under the seat.
	var zs := [-0.16, 0.2, 0.66, 0.94]
	var dims := [[0.15, 0.36, 0.6], [0.2, 0.34, 0.72], [0.19, 0.4, 0.74], [0.11, 0.52, 0.7]]
	var secs := []
	for d in dims:
		var w: float = d[0]
		secs.append([Vector2(-w * 0.8, d[1]), Vector2(-w, d[1] + 0.12), Vector2(-w * 0.6, d[2]), Vector2(w * 0.6, d[2]), Vector2(w, d[1] + 0.12), Vector2(w * 0.8, d[1])])
	var skin := func(_s: int, e: int) -> Array: return [mb, TRIM] if e == 0 or e == 4 else [g, paint]
	_loft(zs, secs, skin)
	_cap(g, secs[0], -0.16, -1.0, paint)
	_cap(g, secs[-1], 0.94, 1.0, paint)
	_end_decal(mb, 0.94, 1.0, -0.08, 0.08, 0.6, 0.66, TAIL)
	mb.box(Vector3(0, 0.81, 0.36), Vector3(0.3, 0.11, 0.66), Color(0.1, 0.09, 0.09))
	mb.box(Vector3(0, 0.36, -0.3), Vector3(0.34, 0.05, 0.62), TRIM)
	# Leg shield and front fender, leaning back.
	var keep_mb: Transform3D = mb.xform
	var keep_g: Transform3D = g.xform
	var lean := Transform3D(Basis(Vector3.RIGHT, 0.21), Vector3(0, 0.35, -0.75))
	g.xform = keep_g * lean
	g.box(Vector3(0, 0.4, 0), Vector3(0.42, 0.8, 0.14), paint)
	g.xform = keep_g
	mb.xform = keep_mb * lean
	mb.box(Vector3(0, 0.38, 0.075), Vector3(0.32, 0.7, 0.02), Color(0.16, 0.16, 0.17))
	mb.xform = keep_mb
	g.box(Vector3(0, 0.52, -0.78), Vector3(0.16, 0.06, 0.36), paint)
	# Steering column, handlebar with grips, cover with the round lamp.
	mb.limb(Vector3(0, 1.0, -0.7), Vector3(0, 1.24, -0.6), 0.04, 0.04, TRIM, 4)
	mb.limb(Vector3(-0.36, 1.3, -0.56), Vector3(0.36, 1.3, -0.56), 0.022, 0.022, Color(0.3, 0.3, 0.32), 4)
	for x in [-0.33, 0.33]:
		mb.box(Vector3(x, 1.3, -0.56), Vector3(0.11, 0.05, 0.05), TRIM)
	g.box(Vector3(0, 1.27, -0.6), Vector3(0.3, 0.13, 0.18), paint)
	mb.box(Vector3(0, 1.34, -0.57), Vector3(0.16, 0.012, 0.08), Color(0.15, 0.35, 0.45))
	var lamp := Vector3(0, 1.27, -0.695)
	for i in 8:
		var a0 := TAU * i / 8.0
		var a1 := TAU * (i + 1) / 8.0
		mb.tri(lamp, lamp + Vector3(cos(a0), sin(a0), 0) * 0.075, lamp + Vector3(cos(a1), sin(a1), 0) * 0.075, Vector3.FORWARD, HEAD)
	for x in [-0.24, 0.24]:
		mb.box(Vector3(x, 1.42, -0.54), Vector3(0.09, 0.012, 0.05), TRIM)


# --- Body building blocks ------------------------------------------------------

## Panoramic glass roof on about half the paints (fixed per colour).
static func _panoramic(paint: Color) -> bool:
	return int(paint.r * 7.0 + paint.g * 13.0 + paint.b * 5.0) % 2 == 0


## Lower-body cross-section: sill, side, shoulder and top, left to right.
## Edges: 0 sill, 1 side, 2 shoulder, 3 top, 4 shoulder, 5 side, 6 sill.
static func _sec(w: float, yb: float, yt: float) -> Array:
	var ys := minf(yb + 0.2, yt - 0.16)
	return [Vector2(-w * 0.94, yb), Vector2(-w, ys), Vector2(-w * 0.97, yt - 0.08), Vector2(-w * 0.8, yt),
		Vector2(w * 0.8, yt), Vector2(w * 0.97, yt - 0.08), Vector2(w, ys), Vector2(w * 0.94, yb)]


## Field `k` of hull stations [z, half width, sill y, top y] at `z`, linearly.
static func _at(st: Array, z: float, k: int) -> float:
	if z <= st[0][0]:
		return st[0][k]
	for i in st.size() - 1:
		var a: Array = st[i]
		var b: Array = st[i + 1]
		if z <= b[0]:
			return lerpf(a[k], b[k], (z - a[0]) / (b[0] - a[0]))
	return st[-1][k]


## The lower body through stations [z, half width, sill y, top y], nose to
## tail, closed at both ends. The top is left out where the cabin covers
## it (`cabin` z range); sides[s] recolours segment s (null keeps paint).
static func _hull(mb, g, st: Array, paint: Color, cabin: Vector2, sides := []) -> void:
	var zs := []
	var secs := []
	for row in st:
		zs.append(row[0])
		secs.append(_sec(row[1], row[2], row[3]))
	var skin := func(s: int, e: int) -> Array:
		if e == 0 or e == 6:
			return [mb, TRIM]
		if e == 3 and zs[s] >= cabin.x - 0.001 and zs[s + 1] <= cabin.y + 0.001:
			return []
		if e != 3 and s < sides.size() and sides[s] != null:
			return [g, sides[s]]
		return [g, paint]
	_loft(zs, secs, skin)
	_cap(g, secs[0], zs[0], -1.0, paint)
	_cap(g, secs[-1], zs[-1], 1.0, paint)


## The glass cabin on the hull: stations [z, roof half width, roof y] from
## windscreen base to rear-window base (the first and last sit on the hull
## top, so their roof values are ignored). segs[s] = [top, sides] colours
## per gap. Returns [zs, sections] for _glass_sheen.
static func _cabin(g, st: Array, cab: Array, segs: Array) -> Array:
	var zs := []
	var secs := []
	for i in cab.size():
		var z: float = cab[i][0]
		var wb := _at(st, z, 1) * 0.8
		var yb := _at(st, z, 3)
		var wr: float = cab[i][1]
		var yr: float = cab[i][2]
		if i == 0 or i == cab.size() - 1:
			wr = wb
			yr = yb
		zs.append(z)
		secs.append([Vector2(-wb, yb), Vector2(-wr, yr), Vector2(wr, yr), Vector2(wb, yb)])
	var skin := func(s: int, e: int) -> Array: return [g, segs[s][0] if e == 1 else segs[s][1]]
	_loft(zs, secs, skin)
	return [zs, secs]


## Lofts cross-sections (Vector2 x, y, left to right over the top) set at
## stations `zs` into flat-shaded quads; skin.call(segment, edge) returns
## [builder, colour], or [] to leave that quad out.
static func _loft(zs: Array, secs: Array, skin: Callable) -> void:
	for s in zs.size() - 1:
		var a: Array = secs[s]
		var b: Array = secs[s + 1]
		for e in a.size() - 1:
			var look: Array = skin.call(s, e)
			if look.is_empty():
				continue
			var ea: Vector2 = a[e + 1] - a[e]
			var eb: Vector2 = b[e + 1] - b[e]
			var d := ea if ea.length() > eb.length() else eb
			_face(look[0], [Vector3(a[e].x, a[e].y, zs[s]), Vector3(a[e + 1].x, a[e + 1].y, zs[s]),
				Vector3(b[e + 1].x, b[e + 1].y, zs[s + 1]), Vector3(b[e].x, b[e].y, zs[s + 1])], Vector3(-d.y, d.x, 0.0), look[1])


## Closes a cross-section at z, facing `dir` along Z.
static func _cap(m, sec: Array, z: float, dir: float, color: Color) -> void:
	for k in range(1, sec.size() - 1):
		_tri(m, Vector3(sec[0].x, sec[0].y, z), Vector3(sec[k].x, sec[k].y, z), Vector3(sec[k + 1].x, sec[k + 1].y, z), Vector3(0, 0, dir), color)


## A flat quad (or a triangle where two corners meet) through `pts`, facing
## the side `hint` points to.
static func _face(m, pts: Array, hint: Vector3, color: Color) -> void:
	var n := Vector3.ZERO
	for i in pts.size():
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[(i + 1) % pts.size()]
		n += Vector3((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y))
	if n.length() < 1e-6:
		return
	n = n.normalized()
	if n.dot(hint) < 0.0:
		n = -n
	_tri(m, pts[0], pts[1], pts[2], n, color)
	if pts.size() > 3:
		_tri(m, pts[0], pts[2], pts[3], n, color)


static func _tri(m, a: Vector3, b: Vector3, c: Vector3, n: Vector3, color: Color) -> void:
	if (b - a).cross(c - a).length_squared() > 1e-10:
		m.tri(a, b, c, n, color)


## Two slanted light streaks across the top glass of loft segment `seg`
## (`top` = index of the section's first top point).
static func _glass_sheen(g, loft: Array, seg: int, top := 1) -> void:
	var zs: Array = loft[0]
	var secs: Array = loft[1]
	var a: Array = secs[seg]
	var b: Array = secs[seg + 1]
	var q := [Vector3(a[top].x, a[top].y, zs[seg]), Vector3(a[top + 1].x, a[top + 1].y, zs[seg]),
		Vector3(b[top + 1].x, b[top + 1].y, zs[seg + 1]), Vector3(b[top].x, b[top].y, zs[seg + 1])]
	var n: Vector3 = (q[1] - q[0]).cross(q[3] - q[0])
	if n.length() < 1e-6:
		n = (q[2] - q[3]).cross(q[3] - q[0])
	n = n.normalized()
	if n.y < 0.0:
		n = -n
	for band in [[0.14, 0.3, 0.3, 0.46], [0.36, 0.42, 0.52, 0.58]]:
		var pts := []
		for uv in [Vector2(band[0], 0.08), Vector2(band[1], 0.08), Vector2(band[3], 0.92), Vector2(band[2], 0.92)]:
			pts.append(q[0].lerp(q[1], uv.x).lerp(q[3].lerp(q[2], uv.x), uv.y) + n * 0.006)
		_face(g, pts, n, SHEEN)


## Four wheels (or as many axles as given) flush with the hull sides.
static func _wheels(mb, st: Array, axles: Array, r: float, width := 0.26, rim := RIM) -> void:
	for z in axles:
		for s in [-1.0, 1.0]:
			_wheel(mb, s * (_at(st, z, 1) + 0.012), z, r, width, rim, true)


## One wheel with its outer face at x = x_out: tyre, alloy disc with
## `spokes` spokes and, if `arch`, a dark arch line on the body above it.
static func _wheel(mb, x_out: float, z: float, r: float, width: float, rim: Color, arch: bool, spokes := 5) -> void:
	var s := signf(x_out)
	var out := Vector3(s, 0, 0)
	var xi := x_out - s * width
	var c := Vector3(x_out, r, z)
	for i in 8:
		var a0 := TAU * i / 8.0 - PI / 8.0
		var a1 := a0 + TAU / 8.0
		var d0 := Vector3(0, sin(a0), cos(a0))
		var d1 := Vector3(0, sin(a1), cos(a1))
		var mid := (d0 + d1).normalized()
		if mid.y > -0.9 and mid.y < 0.5: # the top hides under the body, the bottom on the road
			_face(mb, [Vector3(xi, r, z) + d0 * r, Vector3(x_out, r, z) + d0 * r, Vector3(x_out, r, z) + d1 * r, Vector3(xi, r, z) + d1 * r], mid, TYRE)
		_tri(mb, c, c + d0 * r, c + d1 * r, out, TYRE)
		var hub := c + out * 0.004
		_tri(mb, hub, hub + d0 * r * 0.64, hub + d1 * r * 0.64, out, rim)
	var gap := c + out * 0.008
	for k in spokes:
		var a := TAU * k / spokes + PI / 2.0 + PI / spokes
		_tri(mb, gap + Vector3(0, sin(a), cos(a)) * r * 0.2, gap + Vector3(0, sin(a - 0.36), cos(a - 0.36)) * r * 0.56,
			gap + Vector3(0, sin(a + 0.36), cos(a + 0.36)) * r * 0.56, out, SPOKE_GAP)
	if arch:
		var ac := Vector3(x_out - s * 0.008, r, z)
		for k in 4:
			var b0 := PI * k / 4.0
			var b1 := PI * (k + 1) / 4.0
			var e0 := Vector3(0, sin(b0), cos(b0))
			var e1 := Vector3(0, sin(b1), cos(b1))
			_face(mb, [ac + e0 * r * 1.02, ac + e1 * r * 1.02, ac + e1 * r * 1.16, ac + e0 * r * 1.16], out, TRIM)


## LED lights: slim white headlamps joined by a full-width strip and a black
## intake at the nose; a full-width red bar, black bumper and plate at the tail.
static func _lamps(mb, st: Array, front := true, rear := true) -> void:
	if front:
		var f: Array = st[0]
		var dz: float = st[1][0] - f[0]
		var w: float = f[1]
		for s in [-1.0, 1.0]:
			_top_decal(mb, st, s * w * 0.36, s * w * 0.76, f[0] + 0.01, f[0] + dz * 0.6, HEAD)
			_end_decal(mb, f[0], -1.0, s * w * 0.42, s * w * 0.8, f[3] - 0.12, f[3] - 0.03, HEAD, 0.008)
		_end_decal(mb, f[0], -1.0, -w * 0.8, w * 0.8, f[3] - 0.08, f[3] - 0.06, HEAD)
		_end_decal(mb, f[0], -1.0, -w * 0.62, w * 0.62, f[2] + 0.03, f[2] + 0.18, TRIM)
	if rear:
		var r: Array = st[-1]
		var dz: float = r[0] - st[-2][0]
		var w: float = r[1]
		_top_decal(mb, st, -w * 0.76, w * 0.76, r[0] - dz * 0.55, r[0] - 0.01, TAIL)
		_end_decal(mb, r[0], 1.0, -w * 0.84, w * 0.84, r[3] - 0.1, r[3] - 0.03, TAIL)
		_end_decal(mb, r[0], 1.0, -w * 0.8, w * 0.8, r[2] + 0.01, r[2] + 0.15, TRIM)
		_end_decal(mb, r[0], 1.0, -0.22, 0.22, r[2] + 0.18, r[2] + 0.29, PLATE)


## Panel gaps: across the hood at `hood_z` and the deck at `deck_z` (-INF
## for none), down the sides at each of `doors`, and along the hood at each x
## of `hood_x` back to `hood_end` (the windscreen).
static func _seams(mb, st: Array, paint: Color, hood_z: float, deck_z: float, doors: Array, hood_x := [], hood_end := 0.0) -> void:
	var line := paint.darkened(0.55)
	var w0 := _at(st, hood_z, 1) * 0.78
	_top_decal(mb, st, -w0, w0, hood_z, hood_z + 0.025, line)
	if deck_z > -INF:
		var w1 := _at(st, deck_z, 1) * 0.78
		_top_decal(mb, st, -w1, w1, deck_z, deck_z + 0.025, line)
	for x in hood_x:
		_top_decal(mb, st, x - 0.012, x + 0.012, hood_z, hood_end, line)
	for z in doors:
		var ys := minf(_at(st, z, 2) + 0.2, _at(st, z, 3) - 0.16)
		_side_decal(mb, st, z - 0.012, z + 0.012, ys + 0.02, _at(st, z, 3) - 0.1, line)


## A strip lying on the hull top from z0 to z1 between x0 and x1, split at
## stations so it follows the hood and deck slopes.
static func _top_decal(m, st: Array, x0: float, x1: float, z0: float, z1: float, color: Color, lift := 0.008) -> void:
	var cuts := [z0]
	for row in st:
		if row[0] > z0 and row[0] < z1:
			cuts.append(row[0])
	cuts.append(z1)
	for i in cuts.size() - 1:
		var za: float = cuts[i]
		var zb: float = cuts[i + 1]
		var ya := _at(st, za, 3) + lift
		var yb := _at(st, zb, 3) + lift
		_face(m, [Vector3(x0, ya, za), Vector3(x1, ya, za), Vector3(x1, yb, zb), Vector3(x0, yb, zb)], Vector3.UP, color)


## A band on both hull sides from z0 to z1 between heights y0 and y1.
static func _side_decal(m, st: Array, z0: float, z1: float, y0: float, y1: float, color: Color, lift := 0.008) -> void:
	for s in [-1.0, 1.0]:
		var pts := []
		for p in [Vector2(z0, y0), Vector2(z1, y0), Vector2(z1, y1), Vector2(z0, y1)]:
			pts.append(Vector3(s * (_side_x(st, p.x, p.y) + lift), p.y, p.x))
		_face(m, pts, Vector3(s, 0, 0), color)


## The hull side's half width at height y (it leans in towards the shoulder).
static func _side_x(st: Array, z: float, y: float) -> float:
	var w := _at(st, z, 1)
	var yt := _at(st, z, 3)
	var ys := minf(_at(st, z, 2) + 0.2, yt - 0.16)
	return w * (1.0 - 0.03 * clampf((y - ys) / (yt - 0.08 - ys), 0.0, 1.0))


## A flat rectangle on a nose or tail face at z, facing `dir` along Z.
static func _end_decal(m, z: float, dir: float, x0: float, x1: float, y0: float, y1: float, color: Color, lift := 0.006) -> void:
	var zz := z + dir * lift
	_face(m, [Vector3(x0, y0, zz), Vector3(x1, y0, zz), Vector3(x1, y1, zz), Vector3(x0, y1, zz)], Vector3(0, 0, dir), color)


## A flat rectangle on a vertical side at x (outward is the sign of x).
static func _quad_x(m, x: float, z0: float, z1: float, y0: float, y1: float, color: Color) -> void:
	_face(m, [Vector3(x, y0, z0), Vector3(x, y0, z1), Vector3(x, y1, z1), Vector3(x, y1, z0)], Vector3(signf(x), 0, 0), color)


## Black door mirrors just ahead of the front doors.
static func _mirrors(mb, st: Array, z: float, dy := 0.02, size := Vector3(0.18, 0.11, 0.12)) -> void:
	var w := _at(st, z, 1)
	var yt := _at(st, z, 3)
	for s in [-1.0, 1.0]:
		mb.box(Vector3(s * (w + 0.06), yt + dy, z), size, TRIM)
