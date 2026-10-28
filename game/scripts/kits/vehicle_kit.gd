extends RefCounted
## Modern (2020s) vehicles, low poly but detailed. Local space: forward is
## -Z, ground at y = 0. Car bodies are lofted through cross-sections (low
## hood, raked windscreen, tapered glass cabin, short deck), so each kind
## reads from the 3/4 top-down camera by its roof, glass and light bars,
## plus handling numbers used by vehicle.gd. Fictional makes only.
##
## Paint shells and glass go into `gloss`, a second MeshBuilder that
## vehicle.gd draws with MeshBuilder.gloss_material(); tyres, black trim,
## lights and markings stay on the matte `mb`. Without `gloss` everything
## goes into `mb` (the asset gallery).

## Every model: display name, category, collision size (width, height,
## length), top speed (m/s), acceleration (m/s²), turn rate (rad/s), plus
## any HANDLING values it changes. Keys are stable: missions and main.gd
## ask for "scooter" and "sports" by name.
const KINDS := {
	"compact": {"name": "Nimbi Pip", "category": "compact", "size": Vector3(1.75, 1.5, 3.7),
		"max_speed": 18.0, "accel": 10.0, "turn": 2.7, "mass": 1.15, "grip": 8.5, "power_fade": 0.55,
		"steer_fade": 0.15, "steer_low": 4.0, "reverse": 7.0, "health": 80.0, "roll": 0.0016},
	"sedan": {"name": "Calder Seren", "category": "sedan", "size": Vector3(1.9, 1.4, 4.2),
		"max_speed": 20.5, "accel": 10.5, "turn": 2.4},
	"ev": {"name": "Ionis Lumen", "category": "electric", "size": Vector3(1.95, 1.4, 4.7),
		"max_speed": 22.0, "accel": 13.5, "turn": 2.4, "mass": 2.0, "grip": 8.5, "brake": 34.0,
		"power_fade": 0.08, "reverse": 9.0, "health": 105.0, "roll": 0.0011},
	"luxury": {"name": "Aurelle Empyre", "category": "luxury", "size": Vector3(2.0, 1.5, 5.3),
		"max_speed": 21.0, "accel": 10.0, "turn": 2.2, "mass": 2.2, "grip": 7.5, "drift": 1.4,
		"power_fade": 0.45, "steer_fade": 0.3, "health": 130.0, "roll": 0.0016},
	"taxi": {"name": "Calder Seren Taxi", "category": "taxi", "size": Vector3(1.9, 1.4, 4.2),
		"max_speed": 20.5, "accel": 10.5, "turn": 2.4, "mass": 1.55, "health": 110.0},
	"police": {"name": "Calder Interceptor", "category": "police", "size": Vector3(1.95, 1.4, 4.4),
		"max_speed": 23.0, "accel": 12.0, "turn": 2.5, "mass": 2.2, "grip": 8.5, "drift": 1.6, "brake": 36.0,
		"power_fade": 0.4, "steer_fade": 0.25, "reverse": 9.0, "health": 160.0, "roll": 0.0016},
	"crossover": {"name": "Kaito Rove", "category": "crossover", "size": Vector3(1.9, 1.65, 4.5),
		"max_speed": 19.5, "accel": 10.0, "turn": 2.4, "mass": 1.7, "grip": 7.5, "brake": 30.0,
		"steer_fade": 0.25, "health": 110.0, "roll": 0.0018, "pitch": 0.0016},
	"suv": {"name": "Bastion Summit", "category": "suv", "size": Vector3(2.05, 1.9, 5.1),
		"max_speed": 18.5, "accel": 9.0, "turn": 2.1, "mass": 2.5, "grip": 6.5, "drift": 1.4, "brake": 28.0,
		"steer_fade": 0.4, "steer_low": 5.5, "health": 150.0, "roll": 0.0024, "pitch": 0.0018},
	"pickup": {"name": "Bastion Haulmark", "category": "pickup", "size": Vector3(2.0, 1.6, 4.9),
		"max_speed": 18.5, "accel": 9.0, "turn": 2.1, "mass": 2.4, "grip": 6.5, "drift": 1.3, "brake": 28.0,
		"power_fade": 0.55, "steer_fade": 0.35, "health": 150.0, "roll": 0.0022, "pitch": 0.0016},
	"van": {"name": "Kargo Courier", "category": "van", "size": Vector3(2.0, 2.2, 4.8),
		"max_speed": 17.0, "accel": 8.0, "turn": 2.0, "mass": 2.3, "grip": 6.5, "drift": 1.4, "brake": 26.0,
		"power_fade": 0.6, "steer_fade": 0.4, "steer_low": 5.5, "reverse": 7.0, "health": 140.0,
		"roll": 0.0026, "pitch": 0.002},
	"box_truck": {"name": "Drayman 26 Box", "category": "truck", "size": Vector3(2.5, 3.3, 7.5),
		"max_speed": 14.5, "accel": 5.0, "turn": 1.7, "mass": 6.5, "grip": 5.5, "drift": 1.2, "brake": 20.0,
		"power_fade": 0.65, "steer_fade": 0.55, "steer_low": 6.5, "reverse": 5.0, "health": 240.0,
		"roll": 0.003, "pitch": 0.0024},
	"sports": {"name": "Vesper GT", "category": "sports", "size": Vector3(1.95, 1.1, 4.1),
		"max_speed": 26.5, "accel": 14.0, "turn": 2.8, "mass": 1.45, "grip": 10.0, "drift": 1.7, "slide": 0.2,
		"brake": 38.0, "power_fade": 0.35, "steer_fade": 0.12, "steer_low": 4.5, "health": 95.0,
		"roll": 0.0008, "pitch": 0.0008},
	"muscle": {"name": "Brennan Ironside", "category": "muscle", "size": Vector3(2.0, 1.3, 4.9),
		"max_speed": 25.5, "accel": 13.5, "turn": 2.4, "mass": 1.75, "grip": 6.0, "drift": 0.9, "slide": 0.5,
		"brake": 30.0, "power_fade": 0.4, "health": 120.0, "roll": 0.0014, "pitch": 0.0014},
	"super": {"name": "Zentari Vex", "category": "supercar", "size": Vector3(2.05, 1.05, 4.6),
		"max_speed": 30.5, "accel": 16.5, "turn": 3.0, "mass": 1.4, "grip": 12.0, "drift": 2.4, "brake": 42.0,
		"power_fade": 0.3, "steer_fade": 0.08, "steer_low": 4.5, "reverse": 7.0, "health": 85.0,
		"roll": 0.0005, "pitch": 0.0006},
	"motorbike": {"name": "Raijin Kaze 900", "category": "motorbike", "size": Vector3(0.8, 1.2, 2.1),
		"max_speed": 28.0, "accel": 16.0, "turn": 3.4, "mass": 0.28, "grip": 9.5, "drift": 2.0, "brake": 34.0,
		"power_fade": 0.35, "steer_fade": 0.15, "steer_low": 2.0, "reverse": 3.0, "health": 55.0,
		"lean": 0.55, "rider": true},
	"scooter": {"name": "Vela e-Moped", "category": "scooter", "size": Vector3(0.8, 1.2, 1.9),
		"max_speed": 15.5, "accel": 10.5, "turn": 3.4, "mass": 0.15, "grip": 8.5, "drift": 2.0, "brake": 24.0,
		"power_fade": 0.15, "steer_fade": 0.1, "steer_low": 2.0, "reverse": 3.0, "health": 45.0,
		"lean": 0.5, "rider": true},
}
## Handling defaults (the mid-size sedan); KINDS entries override them.
## mass: tonnes; scales the push given and taken in collisions, and so the
##   speed lost and damage taken.
## grip, drift: how fast the velocity swings round to the heading (per
##   second), normally and on the handbrake; lower slides more.
## slide: share of grip lost at full throttle with the wheel turned hard
##   (rear-drive power oversteer).
## brake: braking (m/s²). power_fade: share of accel left at top speed is
##   1 - power_fade (0 = flat electric torque, high = runs out of breath).
## steer_fade: share of the turn rate lost at top speed (understeer);
##   steer_low: speed (m/s) below which steering fades out (bikes: low).
## reverse: top reverse speed (m/s). health: damage before it is wrecked.
## roll, pitch: body tilt (rad) per m/s² of sideways and forward
##   acceleration; lean: two-wheelers lean into turns by this share of the
##   balanced lean angle (the rider leans with them).
const HANDLING := {"mass": 1.5, "grip": 8.0, "drift": 1.5, "slide": 0.0, "brake": 32.0, "power_fade": 0.5,
	"steer_fade": 0.2, "steer_low": 5.0, "reverse": 8.0, "health": 100.0, "roll": 0.0012, "pitch": 0.0012,
	"lean": 0.0, "rider": false}
## Weighted pick list for civilian traffic. No two-wheelers: traffic has no
## visible rider to put on them.
const CIVILIAN := ["sedan", "sedan", "sedan", "compact", "compact", "compact", "crossover", "crossover",
	"crossover", "suv", "suv", "ev", "ev", "pickup", "pickup", "van", "van", "taxi", "taxi", "luxury",
	"sports", "muscle", "super", "box_truck", "box_truck"]
## Weighted pick list for curb spots: nothing longer than about 5.5 m (the
## spots are single gaps along the curb), so no box trucks.
const PARKED := ["sedan", "sedan", "sedan", "compact", "compact", "compact", "crossover", "crossover", "suv",
	"suv", "ev", "ev", "pickup", "pickup", "van", "luxury", "sports", "muscle", "super", "motorbike",
	"motorbike", "scooter"]
const PARKED_MAX_LENGTH := 5.5
## Weighted pick lists for a country home's own car by household tier
## (T0 to T5): old small cars and bikes, then family cars, then luxury.
const PARKED_BY_TIER := [
	["compact", "compact", "sedan", "pickup", "van", "scooter", "motorbike"],
	["compact", "compact", "sedan", "sedan", "pickup", "van", "motorbike"],
	["sedan", "sedan", "compact", "crossover", "crossover", "suv", "ev", "pickup", "van"],
	["sedan", "crossover", "crossover", "suv", "suv", "ev", "ev", "pickup", "muscle"],
	["luxury", "luxury", "suv", "ev", "sports"],
	["luxury", "sports", "super", "luxury", "ev"],
]
const PAINTS := [
	Color(0.82, 0.16, 0.16), Color(0.15, 0.35, 0.75), Color(0.95, 0.95, 0.95), Color(0.15, 0.15, 0.17),
	Color(0.2, 0.55, 0.32), Color(0.6, 0.3, 0.62), Color(0.95, 0.55, 0.18), Color(0.55, 0.58, 0.62),
]
## Category palettes (others use PAINTS). Box trucks and vans keep a white
## body and wear the paint as cab and livery.
const PALETTES := {
	"compact": [Color(0.55, 0.8, 0.72), Color(0.98, 0.8, 0.3), Color(0.92, 0.45, 0.4), Color(0.45, 0.65, 0.88),
		Color(0.95, 0.95, 0.95), Color(0.2, 0.22, 0.25)],
	"ev": [Color(0.93, 0.93, 0.94), Color(0.55, 0.58, 0.62), Color(0.1, 0.1, 0.11), Color(0.12, 0.25, 0.55),
		Color(0.72, 0.1, 0.12), Color(0.78, 0.8, 0.82)],
	"luxury": [Color(0.05, 0.05, 0.06), Color(0.62, 0.64, 0.66), Color(0.08, 0.12, 0.25), Color(0.38, 0.07, 0.1),
		Color(0.9, 0.89, 0.85), Color(0.25, 0.26, 0.27)],
	"super": [Color(0.55, 0.85, 0.1), Color(1.0, 0.45, 0.05), Color(0.98, 0.8, 0.05), Color(0.85, 0.08, 0.1),
		Color(0.1, 0.55, 0.95), Color(0.95, 0.95, 0.95)],
	"muscle": [Color(0.8, 0.1, 0.1), Color(0.08, 0.08, 0.09), Color(0.95, 0.45, 0.1), Color(0.15, 0.3, 0.7),
		Color(0.15, 0.4, 0.25), Color(0.85, 0.72, 0.2)],
	"box_truck": [Color(0.8, 0.15, 0.15), Color(0.15, 0.35, 0.75), Color(0.2, 0.55, 0.32), Color(0.95, 0.55, 0.18),
		Color(0.45, 0.2, 0.55)],
	"motorbike": [Color(0.85, 0.1, 0.1), Color(0.1, 0.1, 0.11), Color(0.15, 0.35, 0.8), Color(0.55, 0.85, 0.1),
		Color(0.95, 0.95, 0.95), Color(1.0, 0.45, 0.05)],
}
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


## The full handling spec of `kind`: HANDLING with its KINDS entry on top.
static func spec(kind: String) -> Dictionary:
	var s: Dictionary = HANDLING.duplicate()
	s.merge(KINDS.get(kind, KINDS.sedan), true)
	return s


## A paint from the kind's category palette.
static func pick_paint(kind: String, rng: RandomNumberGenerator) -> Color:
	var list: Array = PALETTES.get(kind, PAINTS)
	return list[rng.randi() % list.size()]


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
		"compact":
			_compact(mb, g, paint)
		"ev":
			_ev(mb, g, paint)
		"luxury":
			_luxury(mb, g, paint)
		"crossover":
			_crossover(mb, g, paint)
		"suv":
			_suv(mb, g, paint)
		"muscle":
			_muscle(mb, g, paint)
		"super":
			_super(mb, g, paint)
		"box_truck":
			_box_truck(mb, g, paint)
		"motorbike":
			_motorbike(mb, g, paint)
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


## City hatchback: stubby nose, tall upright cabin running almost to the
## tail, near-vertical hatch under a roof spoiler, contrast roof.
static func _compact(mb, g, paint: Color) -> void:
	var st := [[-1.85, 0.8, 0.26, 0.66], [-1.66, 0.86, 0.22, 0.8], [-0.95, 0.875, 0.22, 0.9], [1.72, 0.875, 0.22, 0.94],
		[1.85, 0.86, 0.26, 0.86]]
	var cab := [[-0.95, 0, 0], [-0.3, 0.62, 1.44], [0.2, 0.62, 1.46], [0.32, 0.62, 1.46], [1.5, 0.6, 1.43], [1.72, 0, 0]]
	var roof := Color(0.95, 0.95, 0.95) if paint.get_luminance() < 0.55 else POLICE_BLACK
	_hull(mb, g, st, paint, Vector2(-0.95, 1.72))
	var c := _cabin(g, st, cab, [[GLASS, GLASS], [roof, GLASS], [roof, TRIM], [roof, GLASS], [GLASS, paint]])
	_glass_sheen(g, c, 0)
	_wheels(mb, st, [-1.2, 1.2], 0.31, 0.22)
	_lamps(mb, st)
	_seams(mb, st, paint, -1.62, -INF, [-0.9, 0.28, 1.4])
	_mirrors(mb, st, -0.78)
	g.box(Vector3(0, 1.455, 1.5), Vector3(1.1, 0.05, 0.18), roof) # spoiler over the hatch


## Electric saloon: smooth closed nose with no grille, one light bar across
## the front and the back, a glass roof from windscreen to tail framed by
## painted rails, flush door handles and aero wheel covers.
static func _ev(mb, g, paint: Color) -> void:
	var st := [[-2.35, 0.88, 0.24, 0.6], [-2.1, 0.95, 0.2, 0.77], [-0.95, 0.975, 0.2, 0.87], [1.6, 0.975, 0.2, 0.93],
		[2.08, 0.96, 0.22, 0.95], [2.35, 0.9, 0.28, 0.86]]
	var cab := [[-0.95, 0, 0], [-0.05, 0.66, 1.39], [0.65, 0.66, 1.4], [1.6, 0, 0]]
	_hull(mb, g, st, paint, Vector2(-0.95, 1.6))
	var c := _cabin(g, st, cab, [[GLASS, GLASS], [GLASS, GLASS], [GLASS, paint]])
	for seg in 3:
		_glass_sheen(g, c, seg)
	for x in [-0.63, 0.63]:
		g.box(Vector3(x, 1.4, 0.3), Vector3(0.07, 0.025, 0.72), paint)
	g.box(Vector3(0, 1.4, 0.3), Vector3(1.26, 0.025, 0.06), TRIM) # B-pillar line across the roof
	_wheels(mb, st, [-1.42, 1.42], 0.35, 0.26, Color(0.27, 0.28, 0.3))
	# Light bars: one strip across the nose (no grille, just a low sensor
	# slot) and the full-width tail bar.
	var f: Array = st[0]
	var w: float = f[1]
	_end_decal(mb, f[0], -1.0, -w * 0.88, w * 0.88, f[3] - 0.08, f[3] - 0.03, HEAD, 0.008)
	_top_decal(mb, st, -w * 0.88, w * 0.88, f[0] + 0.01, f[0] + 0.07, HEAD)
	_end_decal(mb, f[0], -1.0, -0.36, 0.36, f[2] + 0.06, f[2] + 0.13, TRIM)
	_lamps(mb, st, false, true)
	_seams(mb, st, paint, -2.05, 1.76, [-0.9, 0.36, 1.5])
	for z in [-0.42, 0.76]:
		_side_decal(mb, st, z, z + 0.18, 0.76, 0.79, RIM, 0.01) # flush handles
	_mirrors(mb, st, -0.75, 0.03, Vector3(0.14, 0.08, 0.1))


## Long-wheelbase luxury saloon: long hood with an upright chrome grille and
## creases, stretched rear doors, chrome window line, upright boot.
static func _luxury(mb, g, paint: Color) -> void:
	var st := [[-2.65, 0.92, 0.26, 0.76], [-2.47, 0.99, 0.22, 0.92], [-0.8, 1.0, 0.22, 0.99], [1.78, 1.0, 0.22, 1.01],
		[2.42, 0.99, 0.24, 1.01], [2.65, 0.93, 0.3, 0.88]]
	var cab := [[-0.8, 0, 0], [0.0, 0.68, 1.48], [0.5, 0.68, 1.5], [0.62, 0.68, 1.5], [1.25, 0.67, 1.49], [1.78, 0, 0]]
	_hull(mb, g, st, paint, Vector2(-0.8, 1.78))
	var c := _cabin(g, st, cab, [[GLASS, GLASS], [paint, GLASS], [paint, TRIM], [paint, GLASS], [GLASS, paint]])
	_glass_sheen(g, c, 0)
	_glass_sheen(g, c, 4)
	_wheels(mb, st, [-1.76, 1.74], 0.37, 0.27)
	_lamps(mb, st)
	_seams(mb, st, paint, -2.42, 1.86, [-0.75, 0.56, 1.66], [-0.5, 0.5], -0.83)
	_side_decal(mb, st, -0.78, 1.74, 0.95, 0.975, RIM, 0.01) # chrome belt line
	_mirrors(mb, st, -0.62)
	# Upright chrome grille with black slats, stand-up emblem.
	_end_decal(mb, -2.65, -1.0, -0.3, 0.3, 0.36, 0.72, RIM, 0.008)
	for k in 6:
		var x := -0.25 + k * 0.1
		_end_decal(mb, -2.65, -1.0, x - 0.02, x + 0.02, 0.4, 0.68, TRIM, 0.012)
	mb.box(Vector3(0, 0.8, -2.58), Vector3(0.05, 0.08, 0.05), RIM)


## Compact crossover: raised on bigger wheels with black arch and sill
## cladding, short hood, silver roof rails, raked hatch, skid plates.
static func _crossover(mb, g, paint: Color) -> void:
	var st := [[-2.25, 0.88, 0.4, 0.82], [-2.08, 0.94, 0.36, 0.97], [-1.05, 0.95, 0.36, 1.02], [1.86, 0.95, 0.36, 1.04],
		[2.25, 0.92, 0.4, 0.98]]
	var cab := [[-1.05, 0, 0], [-0.35, 0.66, 1.6], [0.2, 0.66, 1.62], [0.32, 0.66, 1.62], [1.5, 0.64, 1.58], [1.86, 0, 0]]
	_hull(mb, g, st, paint, Vector2(-1.05, 1.86))
	var c := _cabin(g, st, cab, [[GLASS, GLASS], [paint, GLASS], [paint, TRIM], [paint, GLASS], [GLASS, paint]])
	_glass_sheen(g, c, 0)
	_wheels(mb, st, [-1.4, 1.42], 0.38, 0.27)
	_lamps(mb, st)
	_seams(mb, st, paint, -2.02, -INF, [-1.0, 0.3, 1.45])
	_side_decal(mb, st, -2.0, 2.1, 0.4, 0.56, TRIM) # cladding
	for x in [-0.56, 0.56]:
		mb.box(Vector3(x, 1.65, 0.6), Vector3(0.05, 0.05, 1.6), RIM) # roof rails
	_end_decal(mb, -2.25, -1.0, -0.5, 0.5, 0.42, 0.5, RIM, 0.012) # skid plates
	_end_decal(mb, 2.25, 1.0, -0.5, 0.5, 0.42, 0.5, RIM, 0.012)
	_mirrors(mb, st, -0.85, 0.03, Vector3(0.18, 0.13, 0.13))


## Full-size SUV: boxy, tall and flat-roofed with three side windows, a big
## grille, roof rack with crossbars, side steps, upright tailgate.
static func _suv(mb, g, paint: Color) -> void:
	var st := [[-2.55, 0.98, 0.44, 0.92], [-2.38, 1.01, 0.4, 1.1], [-1.15, 1.02, 0.4, 1.15], [2.38, 1.02, 0.4, 1.17],
		[2.55, 1.0, 0.42, 1.14]]
	var cab := [[-1.15, 0, 0], [-0.5, 0.8, 1.88], [0.15, 0.8, 1.9], [0.27, 0.8, 1.9], [1.05, 0.8, 1.9], [1.17, 0.8, 1.9],
		[2.3, 0.8, 1.88], [2.38, 0, 0]]
	_hull(mb, g, st, paint, Vector2(-1.15, 2.38))
	var c := _cabin(g, st, cab, [[GLASS, GLASS], [paint, GLASS], [paint, TRIM], [paint, GLASS], [paint, TRIM],
		[paint, GLASS], [GLASS, paint]])
	_glass_sheen(g, c, 0)
	_wheels(mb, st, [-1.55, 1.6], 0.42, 0.3)
	_lamps(mb, st)
	_end_decal(mb, -2.55, -1.0, -0.6, 0.6, 0.52, 0.77, TRIM, 0.008) # grille
	_end_decal(mb, -2.55, -1.0, -0.6, 0.6, 0.63, 0.66, RIM, 0.012)
	_seams(mb, st, paint, -2.33, -INF, [-1.1, 0.25, 1.15])
	_mirrors(mb, st, -0.95, 0.06, Vector3(0.2, 0.16, 0.14))
	# Roof rack and side steps.
	for x in [-0.7, 0.7]:
		mb.box(Vector3(x, 1.95, 0.9), Vector3(0.06, 0.06, 2.4), TRIM)
	for z in [0.0, 1.0, 1.9]:
		mb.box(Vector3(0, 1.97, z), Vector3(1.4, 0.03, 0.06), TRIM)
	for s in [-1.0, 1.0]:
		mb.box(Vector3(s * 1.05, 0.44, 0.03), Vector3(0.14, 0.05, 2.2), TRIM)


## Muscle car: long hood with a raised scoop, short deck, wide stance with
## fat rear tyres, twin racing stripes nose to tail, ducktail, quad pipes.
static func _muscle(mb, g, paint: Color) -> void:
	var st := [[-2.45, 0.92, 0.22, 0.72], [-2.3, 0.98, 0.2, 0.84], [-0.4, 1.0, 0.2, 0.9], [1.5, 1.0, 0.2, 0.93],
		[2.2, 1.0, 0.22, 0.95], [2.45, 0.96, 0.26, 0.88]]
	var cab := [[-0.4, 0, 0], [0.3, 0.62, 1.29], [0.85, 0.6, 1.28], [1.5, 0, 0]]
	var stripe := Color(0.95, 0.95, 0.95) if paint.get_luminance() < 0.55 else POLICE_BLACK
	_hull(mb, g, st, paint, Vector2(-0.4, 1.5))
	var c := _cabin(g, st, cab, [[GLASS, GLASS], [paint, GLASS], [GLASS, paint]])
	_glass_sheen(g, c, 0)
	_glass_sheen(g, c, 2)
	# Stripes over hood, roof and deck (the glass keeps its own colour).
	var roof_st := []
	for i in range(1, cab.size() - 1):
		roof_st.append([cab[i][0], cab[i][1], 0.0, cab[i][2]])
	for x in [-0.23, 0.23]:
		_top_decal(mb, st, x - 0.08, x + 0.08, -2.44, -0.42, stripe)
		_top_decal(mb, st, x - 0.08, x + 0.08, 1.52, 2.44, stripe)
		_top_decal(mb, roof_st, x - 0.08, x + 0.08, 0.3, 0.85, stripe)
	g.box(Vector3(0, 0.93, -1.3), Vector3(0.24, 0.1, 0.7), paint) # scoop
	_end_decal(mb, -1.65, -1.0, -0.1, 0.1, 0.9, 0.96, TRIM)
	for s in [-1.0, 1.0]:
		_wheel(mb, s * (_at(st, -1.5, 1) + 0.012), -1.5, 0.34, 0.26, RIM, true)
		_wheel(mb, s * (_at(st, 1.6, 1) + 0.012), 1.6, 0.37, 0.32, RIM, true)
	_lamps(mb, st)
	_end_decal(mb, -2.45, -1.0, -0.72, 0.72, 0.42, 0.6, TRIM, 0.008) # grille
	_seams(mb, st, paint, -2.28, 1.56, [-0.36, 0.95])
	_mirrors(mb, st, -0.25)
	g.box(Vector3(0, 0.97, 2.33), Vector3(1.7, 0.06, 0.16), paint) # ducktail
	for x in [-0.62, -0.47, 0.47, 0.62]:
		mb.box(Vector3(x, 0.3, 2.47), Vector3(0.09, 0.09, 0.1), RIM)


## Mid-engine supercar: very low wedge nose, cab-forward glass canopy,
## louvred black engine cover, big side intakes, splitter, fixed wing.
static func _super(mb, g, paint: Color) -> void:
	var st := [[-2.3, 0.88, 0.14, 0.42], [-2.06, 0.98, 0.12, 0.58], [-1.0, 1.0, 0.12, 0.72], [0.75, 1.0, 0.12, 0.79],
		[1.6, 1.03, 0.14, 0.84], [2.3, 1.0, 0.18, 0.84]]
	var cab := [[-1.0, 0, 0], [-0.3, 0.55, 1.03], [0.3, 0.54, 1.04], [0.95, 0.45, 0.95], [1.6, 0, 0]]
	_hull(mb, g, st, paint, Vector2(-1.0, 1.6))
	var c := _cabin(g, st, cab, [[GLASS, GLASS], [paint, GLASS], [GLASS, paint], [TRIM, paint]])
	_glass_sheen(g, c, 0)
	# Louvres across the engine cover.
	for k in 4:
		var z := 1.06 + k * 0.13
		var t := (z - 0.95) / 0.65
		mb.box(Vector3(0, lerpf(0.95, 0.84, t) + 0.012, z), Vector3(lerpf(0.9, 1.64, t) * 0.9, 0.012, 0.04), Color(0.24, 0.24, 0.26))
	for s in [-1.0, 1.0]:
		_wheel(mb, s * (_at(st, -1.42, 1) + 0.012), -1.42, 0.33, 0.28, RIM, true)
		_wheel(mb, s * (_at(st, 1.45, 1) + 0.012), 1.45, 0.36, 0.32, RIM, true)
	_lamps(mb, st)
	_seams(mb, st, paint, -2.0, -INF, [-0.95, 0.5])
	_side_decal(mb, st, 0.55, 1.12, 0.3, 0.64, TRIM) # side intakes
	_mirrors(mb, st, -0.7, 0.03, Vector3(0.15, 0.08, 0.1))
	var carbon := Color(0.12, 0.12, 0.13)
	mb.box(Vector3(0, 0.12, -2.24), Vector3(1.7, 0.04, 0.22), carbon) # splitter
	for x in [-0.45, 0.45]:
		mb.box(Vector3(x, 0.94, 2.08), Vector3(0.05, 0.2, 0.12), carbon)
	mb.box(Vector3(0, 1.05, 2.1), Vector3(1.9, 0.04, 0.34), carbon) # wing
	for x in [-0.3, -0.1, 0.1, 0.3]:
		mb.box(Vector3(x, 0.26, 2.32), Vector3(0.03, 0.14, 0.1), Color(0.2, 0.2, 0.22)) # diffuser


## Box truck: conventional cab in the paint colour on a black chassis,
## tall white box with a livery band, roll-up rear door, roof ribs, marker
## lights and dual rear wheels.
static func _box_truck(mb, g, paint: Color) -> void:
	var st := [[-3.75, 1.08, 0.5, 1.1], [-3.6, 1.13, 0.46, 1.28], [-2.75, 1.15, 0.46, 1.36], [-1.6, 1.16, 0.46, 1.38]]
	_hull(mb, g, st, paint, Vector2(-2.75, -1.6))
	# Cab: windscreen up to the roof, side windows, closed back wall.
	var zs := [-2.75, -2.3, -1.6]
	var secs := []
	for i in zs.size():
		var z: float = zs[i]
		var wb := _at(st, z, 1) * 0.97
		var yb := _at(st, z, 3) - 0.06
		if i == 0:
			secs.append([Vector2(-wb, yb), Vector2(-wb, yb), Vector2(-wb, yb), Vector2(wb, yb), Vector2(wb, yb), Vector2(wb, yb)])
		else:
			secs.append([Vector2(-wb, yb), Vector2(-wb, 2.25), Vector2(-wb * 0.92, 2.5), Vector2(wb * 0.92, 2.5), Vector2(wb, 2.25), Vector2(wb, yb)])
	var looks := [[GLASS, TRIM, GLASS], [GLASS, paint, paint]]
	var skin := func(s: int, e: int) -> Array: return [g, looks[s][mini(e, 4 - e)]]
	_loft(zs, secs, skin)
	_cap(g, secs[-1], -1.6, 1.0, paint)
	_glass_sheen(g, [zs, secs], 0, 2)
	for x in [-0.4, 0.0, 0.4]:
		mb.box(Vector3(x, 2.52, -2.2), Vector3(0.12, 0.04, 0.06), AMBER)
	_lamps(mb, st, true, false)
	_end_decal(mb, -3.75, -1.0, -0.6, 0.6, 0.58, 0.95, TRIM, 0.008) # grille
	_mirrors(mb, st, -2.62, 0.55, Vector3(0.12, 0.42, 0.14))
	# Box, livery band, rear door, roof ribs, chassis and side guards.
	g.box(Vector3(0, 2.05, 1.08), Vector3(2.5, 2.5, 5.34), VAN_WHITE)
	for s in [-1.0, 1.0]:
		_quad_x(mb, s * 1.252, -1.3, 3.5, 1.45, 2.3, paint)
		_quad_x(mb, s * 1.252, -1.3, 3.5, 2.4, 2.47, paint.darkened(0.3))
		_quad_x(mb, s * 1.12, -1.6, 1.7, 0.42, 0.72, Color(0.32, 0.33, 0.35))
		mb.box(Vector3(s * 1.2, 1.3, 3.76), Vector3(0.1, 0.5, 0.02), TAIL)
	mb.box(Vector3(-0.85, 0.6, -0.9), Vector3(0.5, 0.4, 0.9), RIM) # fuel tank
	mb.box(Vector3(0, 0.62, 1.1), Vector3(1.7, 0.32, 5.2), TRIM)
	_end_decal(mb, 3.75, 1.0, -1.12, 1.12, 0.9, 3.12, Color(0.83, 0.84, 0.86))
	for k in 6:
		var y := 1.2 + k * 0.32
		_end_decal(mb, 3.75, 1.0, -1.12, 1.12, y, y + 0.025, Color(0.62, 0.63, 0.66), 0.01)
	mb.box(Vector3(0, 0.5, 3.8), Vector3(2.2, 0.14, 0.12), TRIM)
	_end_decal(mb, 3.86, 1.0, -0.22, 0.22, 0.58, 0.68, PLATE)
	for z in [-0.9, 0.2, 1.3, 2.4, 3.5]:
		g.box(Vector3(0, 3.305, z), Vector3(2.3, 0.02, 0.06), VAN_WHITE.darkened(0.12))
	for x in [-1.12, 1.12]:
		mb.box(Vector3(x, 3.27, -1.55), Vector3(0.1, 0.05, 0.03), AMBER)
	# Front wheels under the cab, dual rear wheels under the box.
	for s in [-1.0, 1.0]:
		_wheel(mb, s * (_at(st, -2.95, 1) + 0.012), -2.95, 0.5, 0.3, RIM, true)
		_wheel(mb, s * 1.18, 2.45, 0.5, 0.48, RIM, false)


## Sport bike: full fairing with twin LED eyes and a smoked screen, tank,
## stepped seat, slim raised tail, black engine, side exhaust and clip-on
## bars. The rider sits on it as on the scooter (rig.gd's ride pose puts
## the hips about 0.7 m up over the origin and the hands at about 0.9 m,
## 0.55 m ahead), so the seat, tank and bars sit low to meet them.
static func _motorbike(mb, g, paint: Color) -> void:
	for z in [-0.72, 0.7]:
		for s in [-1.0, 1.0]:
			_wheel(mb, s * 0.08, z, 0.29, 0.08, Color(0.2, 0.2, 0.22), false, 0)
	# Body: stations [z, half width, bottom y, top y].
	var dims := [[-1.0, 0.05, 0.62, 0.78], [-0.84, 0.16, 0.45, 0.95], [-0.56, 0.19, 0.38, 1.0], [-0.5, 0.16, 0.42, 0.86],
		[-0.1, 0.15, 0.45, 0.84], [-0.04, 0.13, 0.5, 0.72], [0.38, 0.12, 0.52, 0.74], [0.56, 0.1, 0.58, 0.86],
		[0.98, 0.05, 0.74, 0.86]]
	var zs := []
	var secs := []
	for d in dims:
		var w: float = d[1]
		zs.append(d[0])
		secs.append([Vector2(-w * 0.8, d[2]), Vector2(-w, d[2] + 0.14), Vector2(-w * 0.55, d[3]), Vector2(w * 0.55, d[3]),
			Vector2(w, d[2] + 0.14), Vector2(w * 0.8, d[2])])
	var seat := Color(0.1, 0.09, 0.09)
	var skin := func(s: int, e: int) -> Array:
		if e == 0 or e == 4:
			return [mb, TRIM]
		if e == 2 and s == 1:
			return [g, GLASS] # screen
		if e == 2 and (s == 5 or s == 6):
			return [mb, seat]
		return [g, paint]
	_loft(zs, secs, skin)
	_cap(g, secs[0], zs[0], -1.0, paint)
	_cap(g, secs[-1], zs[-1], 1.0, paint)
	for x in [-0.07, 0.07]:
		mb.box(Vector3(x, 0.7, -0.97), Vector3(0.07, 0.035, 0.06), HEAD)
	mb.box(Vector3(0, 0.82, 0.98), Vector3(0.1, 0.04, 0.03), TAIL)
	mb.box(Vector3(0, 0.58, 1.0), Vector3(0.16, 0.1, 0.02), PLATE)
	# Engine, forks, swingarm, exhaust, fender, bars and mirrors.
	mb.box(Vector3(0, 0.37, -0.07), Vector3(0.26, 0.32, 0.5), Color(0.18, 0.18, 0.2))
	for x in [-0.08, 0.08]:
		mb.limb(Vector3(x, 0.29, -0.72), Vector3(x, 0.9, -0.58), 0.025, 0.025, RIM, 4)
		mb.limb(Vector3(x, 0.4, 0.1), Vector3(x, 0.29, 0.7), 0.03, 0.03, TRIM, 4)
	mb.limb(Vector3(0.15, 0.24, 0.08), Vector3(0.17, 0.45, 0.6), 0.055, 0.045, Color(0.32, 0.33, 0.35), 5)
	g.box(Vector3(0, 0.6, -0.74), Vector3(0.13, 0.04, 0.4), paint)
	mb.limb(Vector3(-0.28, 0.92, -0.52), Vector3(0.28, 0.92, -0.52), 0.02, 0.02, Color(0.3, 0.3, 0.32), 4)
	for x in [-0.25, 0.25]:
		mb.box(Vector3(x, 0.92, -0.52), Vector3(0.1, 0.045, 0.045), TRIM)
		mb.box(Vector3(signf(x) * 0.22, 0.98, -0.76), Vector3(0.09, 0.04, 0.05), TRIM)


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
