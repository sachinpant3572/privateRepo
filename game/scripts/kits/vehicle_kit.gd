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
		"max_speed": 27.0, "corner_g": 10.5, "accel": 10.0, "turn": 2.7, "mass": 1.15, "grip": 8.5, "power_fade": 0.55,
		"steer_fade": 0.15, "steer_low": 4.0, "reverse": 7.0, "health": 80.0, "roll": 0.0016},
	"sedan": {"name": "Calder Seren", "category": "sedan", "size": Vector3(1.9, 1.4, 4.2),
		"max_speed": 31.0, "accel": 10.5, "turn": 2.4},
	"ev": {"name": "Ionis Lumen", "category": "electric", "size": Vector3(1.95, 1.4, 4.7),
		"max_speed": 34.0, "corner_g": 11.5, "accel": 14.8, "turn": 2.4, "mass": 2.0, "grip": 8.5, "brake": 34.0,
		"power_fade": 0.08, "reverse": 9.0, "health": 105.0, "roll": 0.0011},
	"luxury": {"name": "Aurelle Empyre", "category": "luxury", "size": Vector3(2.0, 1.5, 5.3),
		"max_speed": 33.0, "corner_g": 10.5, "accel": 10.0, "turn": 2.2, "mass": 2.2, "grip": 7.5, "drift": 1.4,
		"power_fade": 0.45, "steer_fade": 0.3, "health": 130.0, "roll": 0.0016},
	"taxi": {"name": "Calder Seren Taxi", "category": "taxi", "size": Vector3(1.9, 1.4, 4.2),
		"max_speed": 30.0, "accel": 10.5, "turn": 2.4, "mass": 1.55, "health": 110.0},
	"police": {"name": "Calder Interceptor", "category": "police", "size": Vector3(1.95, 1.4, 4.4),
		"max_speed": 36.0, "corner_g": 12.0, "accel": 12.0, "turn": 2.5, "mass": 2.2, "grip": 8.5, "drift": 1.6, "brake": 36.0,
		"power_fade": 0.4, "steer_fade": 0.25, "reverse": 9.0, "health": 160.0, "roll": 0.0016},
	"crossover": {"name": "Kaito Rove", "category": "crossover", "size": Vector3(1.9, 1.65, 4.5),
		"max_speed": 30.0, "corner_g": 10.0, "accel": 10.0, "turn": 2.4, "mass": 1.7, "grip": 7.5, "brake": 30.0,
		"steer_fade": 0.25, "health": 110.0, "roll": 0.0018, "pitch": 0.0016},
	"suv": {"name": "Bastion Summit", "category": "suv", "size": Vector3(2.05, 1.9, 5.1),
		"max_speed": 29.0, "corner_g": 9.0, "accel": 9.0, "turn": 2.1, "mass": 2.5, "grip": 6.5, "drift": 1.4, "brake": 28.0,
		"steer_fade": 0.4, "steer_low": 5.5, "health": 150.0, "roll": 0.0024, "pitch": 0.0018},
	"pickup": {"name": "Bastion Haulmark", "category": "pickup", "size": Vector3(2.0, 1.6, 4.9),
		"max_speed": 29.0, "corner_g": 9.0, "accel": 9.0, "turn": 2.1, "mass": 2.4, "grip": 6.5, "drift": 1.3, "brake": 28.0,
		"power_fade": 0.55, "steer_fade": 0.35, "health": 150.0, "roll": 0.0022, "pitch": 0.0016},
	"van": {"name": "Kargo Courier", "category": "van", "size": Vector3(2.0, 2.2, 4.8),
		"max_speed": 26.0, "corner_g": 8.5, "accel": 8.0, "turn": 2.0, "mass": 2.3, "grip": 6.5, "drift": 1.4, "brake": 26.0,
		"power_fade": 0.6, "steer_fade": 0.4, "steer_low": 5.5, "reverse": 7.0, "health": 140.0,
		"roll": 0.0026, "pitch": 0.002},
	"box_truck": {"name": "Drayman 26 Box", "category": "truck", "size": Vector3(2.5, 3.3, 7.5),
		"max_speed": 23.0, "corner_g": 7.5, "accel": 5.0, "turn": 1.7, "mass": 6.5, "grip": 5.5, "drift": 1.2, "brake": 20.0,
		"power_fade": 0.65, "steer_fade": 0.55, "steer_low": 6.5, "reverse": 5.0, "health": 240.0,
		"roll": 0.003, "pitch": 0.0024},
	"sports": {"name": "Vesper GT", "category": "sports", "size": Vector3(1.95, 1.1, 4.1),
		"max_speed": 42.0, "corner_g": 13.5, "accel": 14.0, "turn": 2.8, "mass": 1.45, "grip": 10.0, "drift": 1.7, "slide": 0.2,
		"brake": 38.0, "power_fade": 0.35, "steer_fade": 0.12, "steer_low": 4.5, "health": 95.0,
		"roll": 0.0008, "pitch": 0.0008},
	"muscle": {"name": "Brennan Ironside", "category": "muscle", "size": Vector3(2.0, 1.3, 4.9),
		"max_speed": 40.0, "corner_g": 11.5, "accel": 13.5, "turn": 2.4, "mass": 1.75, "grip": 6.0, "drift": 0.9, "slide": 0.5,
		"brake": 30.0, "power_fade": 0.4, "health": 120.0, "roll": 0.0014, "pitch": 0.0014},
	"super": {"name": "Zentari Vex", "category": "supercar", "size": Vector3(2.05, 1.05, 4.6),
		"max_speed": 48.0, "corner_g": 15.0, "accel": 17.5, "turn": 3.0, "mass": 1.4, "grip": 12.0, "drift": 2.4, "brake": 42.0,
		"power_fade": 0.3, "steer_fade": 0.08, "steer_low": 4.5, "reverse": 7.0, "health": 85.0,
		"roll": 0.0005, "pitch": 0.0006},
	"motorbike": {"name": "Raijin Kaze 900", "category": "motorbike", "size": Vector3(0.8, 1.2, 2.1),
		"max_speed": 44.0, "corner_g": 12.0, "accel": 16.5, "turn": 3.4, "mass": 0.28, "grip": 9.5, "drift": 2.0, "brake": 34.0,
		"power_fade": 0.35, "steer_fade": 0.15, "steer_low": 2.0, "reverse": 3.0, "health": 55.0,
		"lean": 0.55, "rider": true},
	"scooter": {"name": "Vela e-Moped", "category": "scooter", "size": Vector3(0.8, 1.2, 1.9),
		"max_speed": 20.0, "corner_g": 9.0, "accel": 10.5, "turn": 3.4, "mass": 0.15, "grip": 8.5, "drift": 2.0, "brake": 24.0,
		"power_fade": 0.15, "steer_fade": 0.1, "steer_low": 2.0, "reverse": 3.0, "health": 45.0,
		"lean": 0.5, "rider": true},
	# Three-wheelers and the big trucks (added in the realism pass). The
	# tipper and the semi drive in traffic only: too long for a curb spot.
	"tuk_tuk": {"name": "Pavan Autorick", "category": "autorickshaw", "size": Vector3(1.4, 1.75, 2.7),
		"max_speed": 13.5, "accel": 7.0, "turn": 2.9, "mass": 0.45, "grip": 7.0, "drift": 1.6, "brake": 24.0,
		"power_fade": 0.45, "steer_fade": 0.2, "steer_low": 3.0, "reverse": 4.0, "health": 60.0,
		"roll": 0.0042, "pitch": 0.0024},
	"cargo_trike": {"name": "Pavan Loadmate", "category": "cargo trike", "size": Vector3(1.5, 1.85, 3.4),
		"max_speed": 12.5, "accel": 5.5, "turn": 2.6, "mass": 0.8, "grip": 6.5, "drift": 1.4, "brake": 22.0,
		"power_fade": 0.5, "steer_fade": 0.3, "steer_low": 3.5, "reverse": 4.0, "health": 75.0,
		"roll": 0.0048, "pitch": 0.0028},
	"tipper": {"name": "Gorran Quarry 10", "category": "dump truck", "size": Vector3(2.5, 3.2, 8.6),
		"max_speed": 13.5, "accel": 4.2, "turn": 1.55, "mass": 11.0, "grip": 5.0, "drift": 1.1, "brake": 18.0,
		"power_fade": 0.6, "steer_fade": 0.55, "steer_low": 6.5, "reverse": 4.5, "health": 320.0,
		"roll": 0.0032, "pitch": 0.0026},
	"semi": {"name": "Gorran Longhaul 18", "category": "semi truck", "size": Vector3(2.55, 4.0, 15.0),
		"max_speed": 14.0, "accel": 3.4, "turn": 1.45, "mass": 16.0, "grip": 4.5, "drift": 1.0, "brake": 16.0,
		"power_fade": 0.55, "steer_fade": 0.6, "steer_low": 6.0, "reverse": 3.5, "health": 420.0,
		"roll": 0.0034, "pitch": 0.0028},
}
## Kinds longer than this only set off on streets with two or more lanes
## each way (population.gd), so the semi starts on arterials and highways.
const LONG_HAUL := 10.0
## Handling defaults (the mid-size sedan); KINDS entries override them.
## mass: tonnes; scales the push given and taken in collisions, and so the
##   speed lost and damage taken.
## grip, drift: how fast the velocity swings round to the heading (per
##   second), normally and on the handbrake; lower slides more.
## slide: share of grip lost at full throttle with the wheel turned hard
##   (rear-drive power oversteer).
## brake: braking (m/s²). power_fade: share of accel left at top speed is
##   1 - power_fade (0 = flat electric torque, high = runs out of breath).
## corner_g: the most sideways acceleration (m/s²) the tyres hold, so the
##   fastest the heading can swing at speed v is corner_g / v: a car at
##   speed turns on a wide arc, as on a real road.
## steer_fade: share of the turn rate lost at top speed (understeer);
##   steer_low: speed (m/s) below which steering fades out (bikes: low).
## reverse: top reverse speed (m/s). health: damage before it is wrecked.
## roll, pitch: body tilt (rad) per m/s² of sideways and forward
##   acceleration; lean: two-wheelers lean into turns by this share of the
##   balanced lean angle (the rider leans with them).
const HANDLING := {"mass": 1.5, "grip": 8.0, "corner_g": 11.0, "drift": 1.5, "slide": 0.0, "brake": 32.0, "power_fade": 0.5,
	"steer_fade": 0.2, "steer_low": 5.0, "reverse": 8.0, "health": 100.0, "roll": 0.0012, "pitch": 0.0012,
	"lean": 0.0, "rider": false}
## Weighted pick list for civilian traffic. No two-wheelers: traffic has no
## visible rider to put on them.
const CIVILIAN := ["sedan", "sedan", "sedan", "compact", "compact", "compact", "crossover", "crossover",
	"crossover", "suv", "suv", "ev", "ev", "pickup", "pickup", "van", "van", "taxi", "taxi", "luxury",
	"sports", "muscle", "super", "box_truck", "box_truck", "tuk_tuk", "cargo_trike", "tipper", "semi"]
## Weighted pick list for curb spots: nothing longer than about 5.5 m (the
## spots are single gaps along the curb), so no box trucks.
const PARKED := ["sedan", "sedan", "sedan", "compact", "compact", "compact", "crossover", "crossover", "suv",
	"suv", "ev", "ev", "pickup", "pickup", "van", "luxury", "sports", "muscle", "super", "motorbike",
	"motorbike", "scooter", "tuk_tuk", "cargo_trike"]
const PARKED_MAX_LENGTH := 5.5
## Weighted pick lists for a country home's own car by household tier
## (T0 to T5): old small cars, bikes and three-wheelers, then family cars,
## then luxury.
const PARKED_BY_TIER := [
	["compact", "compact", "sedan", "pickup", "van", "scooter", "motorbike", "tuk_tuk", "cargo_trike"],
	["compact", "compact", "sedan", "sedan", "pickup", "van", "motorbike", "tuk_tuk"],
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
	"tuk_tuk": [Color(0.12, 0.48, 0.24), Color(0.98, 0.8, 0.15), Color(0.1, 0.1, 0.11), Color(0.15, 0.4, 0.75),
		Color(0.12, 0.48, 0.24)],
	"cargo_trike": [Color(0.15, 0.4, 0.75), Color(0.12, 0.48, 0.24), Color(0.95, 0.95, 0.95), Color(0.8, 0.15, 0.15),
		Color(0.98, 0.8, 0.15)],
	"tipper": [Color(0.98, 0.72, 0.1), Color(0.95, 0.45, 0.1), Color(0.8, 0.15, 0.15), Color(0.2, 0.45, 0.25),
		Color(0.92, 0.92, 0.9)],
	"semi": [Color(0.8, 0.12, 0.12), Color(0.12, 0.25, 0.6), Color(0.95, 0.95, 0.95), Color(0.1, 0.1, 0.11),
		Color(0.2, 0.45, 0.28), Color(0.95, 0.55, 0.15)],
}
## Glass: a dark blue-grey, light enough that black paint still shows its
## window line; the interior is painted on it (dash, wheel, headrests).
const GLASS := Color(0.15, 0.19, 0.25)
## Dashboard, seats and the shade under a canopy, seen through the glass.
const INTERIOR := Color(0.05, 0.055, 0.065)
## Seat backs and headrests: a warm grey lighter than the glass, so the
## cabin reads from the game camera above.
const SEAT := Color(0.3, 0.27, 0.24)
## Fake sky reflection streaked across glass, so it reads as glass in any light.
const SHEEN := Color(0.42, 0.5, 0.58)
## The dark well behind a wheel, inside the arch.
const WELL := Color(0.025, 0.025, 0.03)
const REVERSE := Color(0.93, 0.94, 0.96)
## Painted steel truck rims, and the loads in a tipper.
const STEEL := Color(0.6, 0.62, 0.64)
const GRAVEL := Color(0.55, 0.5, 0.43)
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
		"tuk_tuk":
			_tuk_tuk(mb, g, paint)
		"cargo_trike":
			_cargo_trike(mb, g, paint)
		"tipper":
			_tipper(mb, g, paint)
		"semi":
			_semi(mb, g, paint)
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
	_interior(g, c, 0, 4)
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
	_lamps(mb, st, true, true, 0.34)
	_seams(mb, st, paint, -1.86, 1.54, [-0.74, 0.36, 1.32], [-0.62, 0.62], -0.83)
	_mirrors(mb, st, -0.6, 0.02, Vector3(0.18, 0.11, 0.12), g, paint)
	g.box(Vector3(0, 1.39, 0.82), Vector3(0.07, 0.05, 0.16), POLICE_BLACK) # roof fin aerial
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
	_interior(g, c, 0, 6)
	_glass_sheen(g, c, 0)
	_glass_sheen(g, c, 6)
	_wheels(mb, st, [-1.42, 1.42], 0.37, 0.28, Color(0.3, 0.31, 0.33))
	_lamps(mb, st, true, true, 0.36)
	# Unit number on the roof for the helicopter, a spotlight by the screen.
	for x in [-0.2, 0.0, 0.2]:
		mb.box(Vector3(x, 1.405, 1.05), Vector3(0.12, 0.012, 0.3), POLICE_BLACK)
	mb.box(Vector3(-0.78, 1.12, -0.95), Vector3(0.1, 0.1, 0.16), RIM)
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
	_interior(g, c, 0, 4)
	_glass_sheen(g, c, 0)
	_wheels(mb, st, [-1.6], 0.4, 0.3)
	for s in [-1.0, 1.0]:
		_wheel(mb, s * 1.012, 1.62, 0.4, 0.3, RIM, true)
	_lamps(mb, st, true, false)
	_end_decal(mb, -2.45, -1.0, -0.5, 0.5, 0.56, 0.84, TRIM, 0.008) # grille
	for y in [0.63, 0.7, 0.77]:
		_end_decal(mb, -2.45, -1.0, -0.48, 0.48, y, y + 0.018, Color(0.3, 0.31, 0.33), 0.011)
	_seams(mb, st, paint, -2.3, -INF, [-0.95, -0.02, 0.58], [-0.72, 0.72], -1.03)
	_mirrors(mb, st, -0.82, 0.04, Vector3(0.2, 0.15, 0.14), g, paint)
	for s in [-1.0, 1.0]:
		mb.box(Vector3(s * 1.0, 0.46, -0.2), Vector3(0.12, 0.05, 1.5), TRIM) # side steps
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
	_interior(g, [zs, secs], 0, -1, 2)
	_glass_sheen(g, [zs, secs], 0, 2)
	_wheels(mb, st, [-1.55, 1.55], 0.38, 0.28)
	_lamps(mb, st, true, false, 0.36)
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
	_interior(g, c, 0, 2)
	_glass_sheen(g, c, 0)
	_glass_sheen(g, c, 2)
	_wheels(mb, st, [-1.3, 1.3], 0.34, 0.28)
	_lamps(mb, st)
	_seams(mb, st, paint, -1.76, 1.58, [-0.58, 0.6], [-0.55, 0.55], -0.63)
	_mirrors(mb, st, -0.4, 0.03, Vector3(0.16, 0.1, 0.12), g, paint)
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
			_wheel(mb, s * 0.065, z, 0.24, 0.065, Color(0.55, 0.56, 0.58), false, 5)
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
	# Fork legs, mirror stalks, the grab rail round the seat back, the red
	# rear shock and the plate.
	for s in [-1.0, 1.0]:
		mb.limb(Vector3(s * 0.075, 0.24, -0.68), Vector3(s * 0.07, 0.62, -0.76), 0.022, 0.022, TRIM, 4)
		mb.limb(Vector3(s * 0.2, 1.3, -0.56), Vector3(s * 0.24, 1.41, -0.54), 0.01, 0.01, TRIM, 3)
		mb.limb(Vector3(s * 0.16, 0.8, 0.52), Vector3(s * 0.13, 0.82, 0.84), 0.015, 0.015, Color(0.3, 0.3, 0.32), 4)
	mb.limb(Vector3(-0.13, 0.82, 0.84), Vector3(0.13, 0.82, 0.84), 0.015, 0.015, Color(0.3, 0.3, 0.32), 4)
	mb.limb(Vector3(0.12, 0.26, 0.66), Vector3(0.16, 0.55, 0.42), 0.025, 0.025, Color(0.8, 0.12, 0.1), 4)
	mb.box(Vector3(0, 0.5, 0.97), Vector3(0.14, 0.09, 0.015), PLATE)


## City hatchback: stubby nose, tall upright cabin running almost to the
## tail, near-vertical hatch under a roof spoiler, contrast roof.
static func _compact(mb, g, paint: Color) -> void:
	var st := [[-1.85, 0.8, 0.26, 0.66], [-1.66, 0.86, 0.22, 0.8], [-0.95, 0.875, 0.22, 0.9], [1.72, 0.875, 0.22, 0.94],
		[1.85, 0.86, 0.26, 0.86]]
	var cab := [[-0.95, 0, 0], [-0.3, 0.62, 1.44], [0.2, 0.62, 1.46], [0.32, 0.62, 1.46], [1.5, 0.6, 1.43], [1.72, 0, 0]]
	var roof := Color(0.95, 0.95, 0.95) if paint.get_luminance() < 0.55 else POLICE_BLACK
	_hull(mb, g, st, paint, Vector2(-0.95, 1.72))
	var c := _cabin(g, st, cab, [[GLASS, GLASS], [roof, GLASS], [roof, TRIM], [roof, GLASS], [GLASS, paint]])
	_interior(g, c, 0, 4)
	_glass_sheen(g, c, 0)
	_wheels(mb, st, [-1.2, 1.2], 0.31, 0.22)
	_lamps(mb, st, true, true, 0.3)
	_seams(mb, st, paint, -1.62, -INF, [-0.9, 0.28, 1.4])
	_mirrors(mb, st, -0.78, 0.02, Vector3(0.18, 0.11, 0.12), g, roof)
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
	_interior(g, c, 0, 2)
	# Seats seen down through the glass roof.
	for x in [0.3, 0.7]:
		_glass_decal(g, c, 1, x - 0.11, x + 0.11, 0.05, 0.3, SEAT)
		_glass_decal(g, c, 1, x - 0.12, x + 0.12, 0.78, 1.0, SEAT)
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
	_seams(mb, st, paint, -2.05, 1.76, [-0.9, 0.36, 1.5], [], 0.0, false)
	for z in [-0.42, 0.76]:
		_side_decal(mb, st, z, z + 0.18, 0.76, 0.79, RIM, 0.01) # flush handles
	_mirrors(mb, st, -0.75, 0.03, Vector3(0.14, 0.08, 0.1), g, paint)


## Long-wheelbase luxury saloon: long hood with an upright chrome grille and
## creases, stretched rear doors, chrome window line, upright boot.
static func _luxury(mb, g, paint: Color) -> void:
	var st := [[-2.65, 0.92, 0.26, 0.76], [-2.47, 0.99, 0.22, 0.92], [-0.8, 1.0, 0.22, 0.99], [1.78, 1.0, 0.22, 1.01],
		[2.42, 0.99, 0.24, 1.01], [2.65, 0.93, 0.3, 0.88]]
	var cab := [[-0.8, 0, 0], [0.0, 0.68, 1.48], [0.5, 0.68, 1.5], [0.62, 0.68, 1.5], [1.25, 0.67, 1.49], [1.78, 0, 0]]
	_hull(mb, g, st, paint, Vector2(-0.8, 1.78))
	var c := _cabin(g, st, cab, [[GLASS, GLASS], [paint, GLASS], [paint, TRIM], [paint, GLASS], [GLASS, paint]])
	_interior(g, c, 0, 4)
	_glass_sheen(g, c, 0)
	_glass_sheen(g, c, 4)
	_wheels(mb, st, [-1.76, 1.74], 0.37, 0.27)
	_lamps(mb, st)
	_seams(mb, st, paint, -2.42, 1.86, [-0.75, 0.56, 1.66], [-0.5, 0.5], -0.83)
	_side_decal(mb, st, -0.78, 1.74, 0.9, 0.925, RIM, 0.01) # chrome belt line
	_side_decal(mb, st, -1.28, 1.28, 0.39, 0.42, RIM, 0.01) # chrome sill
	_mirrors(mb, st, -0.62, 0.02, Vector3(0.18, 0.11, 0.12), g, paint)
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
	_interior(g, c, 0, 4)
	_glass_sheen(g, c, 0)
	_wheels(mb, st, [-1.4, 1.42], 0.38, 0.27)
	_lamps(mb, st, true, true, 0.36)
	_seams(mb, st, paint, -2.02, -INF, [-1.0, 0.3, 1.45])
	_side_decal(mb, st, -2.0, 2.1, 0.4, 0.56, TRIM) # cladding
	for x in [-0.56, 0.56]:
		mb.box(Vector3(x, 1.65, 0.6), Vector3(0.05, 0.05, 1.6), RIM) # roof rails
	_end_decal(mb, -2.25, -1.0, -0.5, 0.5, 0.42, 0.5, RIM, 0.012) # skid plates
	_end_decal(mb, 2.25, 1.0, -0.5, 0.5, 0.42, 0.5, RIM, 0.012)
	_mirrors(mb, st, -0.85, 0.03, Vector3(0.18, 0.13, 0.13), g, paint)


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
	_interior(g, c, 0, 6)
	_glass_sheen(g, c, 0)
	_wheels(mb, st, [-1.55, 1.6], 0.42, 0.3)
	_lamps(mb, st)
	_end_decal(mb, -2.55, -1.0, -0.6, 0.6, 0.52, 0.77, TRIM, 0.008) # grille
	_end_decal(mb, -2.55, -1.0, -0.6, 0.6, 0.63, 0.66, RIM, 0.012)
	_seams(mb, st, paint, -2.33, -INF, [-1.1, 0.25, 1.15])
	_mirrors(mb, st, -0.95, 0.06, Vector3(0.2, 0.16, 0.14), g, paint)
	# Spare wheel on the tailgate.
	_end_decal(mb, 2.55, 1.0, -0.36, 0.36, 0.62, 1.04, TYRE, 0.02)
	_end_decal(mb, 2.55, 1.0, -0.2, 0.2, 0.7, 0.96, paint.darkened(0.3), 0.024)
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
	_interior(g, c, 0, 2)
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
	_mirrors(mb, st, -0.25, 0.02, Vector3(0.18, 0.11, 0.12), g, paint)
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
	_interior(g, c, 0, -1)
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
	_mirrors(mb, st, -0.7, 0.03, Vector3(0.15, 0.08, 0.1), g, paint)
	var carbon := Color(0.12, 0.12, 0.13)
	mb.box(Vector3(0, 0.12, -2.24), Vector3(1.7, 0.04, 0.22), carbon) # splitter
	for x in [-0.45, 0.45]:
		mb.box(Vector3(x, 0.94, 2.08), Vector3(0.05, 0.2, 0.12), carbon)
	mb.box(Vector3(0, 1.05, 2.1), Vector3(1.9, 0.04, 0.34), carbon) # wing
	for x in [-0.3, -0.1, 0.1, 0.3]:
		mb.box(Vector3(x, 0.26, 2.32), Vector3(0.03, 0.14, 0.1), Color(0.2, 0.2, 0.22)) # diffuser


## Six-wheel box truck: short-nosed cab in the paint colour with a barred
## grille and a steel bumper, on a black chassis; tall ribbed white box
## with a livery band, roll-up rear door, roof ribs, marker lights, side
## guards and twin-tyred rear wheels.
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
	_interior(g, [zs, secs], 0, -1, 2)
	_glass_sheen(g, [zs, secs], 0, 2)
	for x in [-0.4, 0.0, 0.4]:
		mb.box(Vector3(x, 2.52, -2.2), Vector3(0.12, 0.04, 0.06), AMBER)
	_lamps(mb, st, true, false)
	# Barred grille, steel bumper with the plate, door seams, mirrors.
	_end_decal(mb, -3.75, -1.0, -0.6, 0.6, 0.6, 0.95, TRIM, 0.008)
	for y in [0.68, 0.76, 0.84]:
		_end_decal(mb, -3.75, -1.0, -0.58, 0.58, y, y + 0.03, RIM, 0.011)
	mb.box(Vector3(0, 0.52, -3.78), Vector3(2.2, 0.26, 0.14), Color(0.36, 0.37, 0.39))
	_end_decal(mb, -3.85, -1.0, -0.22, 0.22, 0.45, 0.56, PLATE)
	_seams(mb, st, paint, -3.55, -INF, [-2.68, -1.66])
	_mirrors(mb, st, -2.62, 0.55, Vector3(0.12, 0.42, 0.14))
	# Box: ribbed sides under the livery band, bottom rail, side markers,
	# tail lamps, side guards and mud flaps.
	g.box(Vector3(0, 2.05, 1.08), Vector3(2.5, 2.5, 5.34), VAN_WHITE)
	for s in [-1.0, 1.0]:
		for k in 12:
			var z := -1.45 + k * 0.45
			_quad_x(mb, s * 1.254, z - 0.02, z + 0.02, 0.92, 3.25, VAN_WHITE.darkened(0.14))
		_quad_x(mb, s * 1.258, -1.3, 3.5, 1.45, 2.3, paint)
		_quad_x(mb, s * 1.258, -1.3, 3.5, 2.4, 2.47, paint.darkened(0.3))
		_quad_x(mb, s * 1.256, -1.59, 3.75, 0.8, 0.92, Color(0.55, 0.56, 0.58))
		for z in [-1.4, 1.0, 3.5]:
			_quad_x(mb, s * 1.26, z - 0.05, z + 0.05, 0.98, 1.06, AMBER)
		_quad_x(mb, s * 1.12, -0.3, 1.7, 0.42, 0.72, Color(0.32, 0.33, 0.35))
		mb.box(Vector3(s * 1.2, 1.3, 3.76), Vector3(0.1, 0.5, 0.02), TAIL)
		_end_decal(mb, 3.05, 1.0, s * 0.7, s * 1.2, 0.2, 0.8, TRIM, 0.0)
	mb.limb(Vector3(-0.9, 0.64, -1.4), Vector3(-0.9, 0.64, -0.5), 0.22, 0.22, RIM, 8) # fuel tank
	mb.box(Vector3(0, 0.62, 1.1), Vector3(1.7, 0.32, 5.2), TRIM)
	# Roll-up rear door with slats and a red and white strip, bumper, plate.
	_end_decal(mb, 3.75, 1.0, -1.12, 1.12, 0.9, 3.12, Color(0.83, 0.84, 0.86))
	for k in 6:
		var y := 1.2 + k * 0.32
		_end_decal(mb, 3.75, 1.0, -1.12, 1.12, y, y + 0.025, Color(0.62, 0.63, 0.66), 0.01)
	_end_decal(mb, 3.75, 1.0, -1.2, 1.2, 0.82, 0.88, Color.WHITE, 0.012)
	for k in 6:
		var x := -1.2 + k * 0.4
		_end_decal(mb, 3.75, 1.0, x, x + 0.2, 0.82, 0.88, TAIL, 0.014)
	mb.box(Vector3(0, 0.5, 3.8), Vector3(2.2, 0.14, 0.12), TRIM)
	_end_decal(mb, 3.86, 1.0, -0.22, 0.22, 0.45, 0.56, PLATE)
	for z in [-0.9, 0.2, 1.3, 2.4, 3.5]:
		g.box(Vector3(0, 3.305, z), Vector3(2.3, 0.02, 0.06), VAN_WHITE.darkened(0.12))
	for x in [-1.12, 1.12]:
		mb.box(Vector3(x, 3.27, -1.55), Vector3(0.1, 0.05, 0.03), AMBER)
	# Single tyres under the cab, twin tyres under the box: six wheels.
	for s in [-1.0, 1.0]:
		_truck_wheel(mb, s * (_at(st, -2.95, 1) + 0.012), -2.95, 0.5, 0.3, false, true)
		_truck_wheel(mb, s * 1.2, 2.45, 0.5, 0.58, true)


## Sport bike: full fairing with twin LED eyes and a smoked screen, tank,
## stepped seat, slim raised tail, black engine, side exhaust and clip-on
## bars. The rider sits on it as on the scooter (rig.gd's ride pose puts
## the hips about 0.7 m up over the origin and the hands at about 0.9 m,
## 0.55 m ahead), so the seat, tank and bars sit low to meet them.
static func _motorbike(mb, g, paint: Color) -> void:
	for z in [-0.72, 0.7]:
		for s in [-1.0, 1.0]:
			_wheel(mb, s * 0.08, z, 0.29, 0.08, Color(0.3, 0.31, 0.33), false, 5)
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
	# Engine, forks (chrome stanchions in black lowers), the frame spars,
	# swingarm, footpegs, exhaust, fender, brake caliper, bars and mirrors.
	mb.box(Vector3(0, 0.37, -0.07), Vector3(0.26, 0.32, 0.5), Color(0.18, 0.18, 0.2))
	for s in [-1.0, 1.0]:
		mb.limb(Vector3(s * 0.085, 0.29, -0.72), Vector3(s * 0.085, 0.56, -0.66), 0.032, 0.03, TRIM, 4)
		mb.limb(Vector3(s * 0.085, 0.56, -0.66), Vector3(s * 0.08, 0.9, -0.58), 0.022, 0.022, RIM, 4)
		mb.limb(Vector3(s * 0.165, 0.66, -0.52), Vector3(s * 0.15, 0.46, 0.02), 0.03, 0.03, RIM, 4)
		mb.limb(Vector3(s * 0.08, 0.4, 0.1), Vector3(s * 0.08, 0.29, 0.7), 0.03, 0.03, TRIM, 4)
		mb.box(Vector3(s * 0.19, 0.36, 0.14), Vector3(0.1, 0.025, 0.03), TRIM)
		mb.limb(Vector3(s * 0.13, 0.9, -0.62), Vector3(s * 0.2, 0.97, -0.74), 0.01, 0.01, TRIM, 3)
	mb.box(Vector3(0.1, 0.4, -0.64), Vector3(0.03, 0.09, 0.12), Color(0.8, 0.1, 0.1))
	mb.limb(Vector3(0.15, 0.24, 0.08), Vector3(0.17, 0.45, 0.6), 0.055, 0.045, Color(0.32, 0.33, 0.35), 5)
	g.box(Vector3(0, 0.6, -0.74), Vector3(0.13, 0.04, 0.4), paint)
	mb.limb(Vector3(-0.28, 0.92, -0.52), Vector3(0.28, 0.92, -0.52), 0.02, 0.02, Color(0.3, 0.3, 0.32), 4)
	for x in [-0.25, 0.25]:
		mb.box(Vector3(x, 0.92, -0.52), Vector3(0.1, 0.045, 0.045), TRIM)
		mb.box(Vector3(signf(x) * 0.22, 0.98, -0.76), Vector3(0.09, 0.04, 0.05), TRIM)


## Auto-rickshaw: one front wheel under a rounded cowl with twin round
## lamps, an open-sided cab under a canvas canopy in a contrast colour,
## the driver's seat ahead of a rear bench, the engine low at the back.
## No rider key: vehicle.gd hides the driver, so the open sides show the
## shade inside and the seats.
static func _tuk_tuk(mb, g, paint: Color) -> void:
	var canvas := POLICE_BLACK if paint.get_luminance() > 0.5 else TAXI_YELLOW
	var seam := canvas.lightened(0.2) if canvas.get_luminance() < 0.3 else canvas.darkened(0.3)
	var seat := Color(0.24, 0.12, 0.08)
	var rim := Color(0.3, 0.31, 0.33)
	var st := [[-1.35, 0.34, 0.42, 0.95], [-1.22, 0.42, 0.4, 1.0], [-0.95, 0.52, 0.36, 0.9], [-0.62, 0.66, 0.3, 0.76],
		[1.12, 0.68, 0.3, 0.78], [1.35, 0.62, 0.36, 0.76]]
	_hull(mb, g, st, paint, Vector2(-1.22, 1.12))
	_side_decal(mb, st, -0.6, 1.3, 0.5, 0.56, canvas)
	# Windscreen with the dash, the bar and the driver's seat behind it.
	var gq := _gq([Vector3(-0.38, 0.99, -1.21), Vector3(0.38, 0.99, -1.21), Vector3(0.56, 1.45, -1.01),
		Vector3(-0.56, 1.45, -1.01)])
	_face(g, gq[0], gq[1], GLASS)
	_gq_decal(g, gq, 0.04, 0.96, 0.0, 0.16, INTERIOR)
	_gq_decal(g, gq, 0.2, 0.8, 0.24, 0.29, TRIM)
	_gq_decal(g, gq, 0.38, 0.62, 0.52, 0.86, seat)
	_sheen(g, gq)
	_gq_decal(g, gq, 0.3, 0.64, 0.05, 0.075, TRIM, 0.008)
	# Canvas canopy from the windscreen header to the back, with straps.
	var cz := [-1.03, -0.9, 1.14, 1.32]
	var dims := [[0.6, 1.47, 1.66], [0.7, 1.45, 1.75], [0.7, 1.45, 1.75], [0.68, 1.45, 1.68]]
	var secs := []
	for d in dims:
		var w: float = d[0]
		var mid := lerpf(d[1], d[2], 0.6)
		secs.append([Vector2(-w, d[1]), Vector2(-w * 0.97, mid), Vector2(-w * 0.72, d[2]), Vector2(w * 0.72, d[2]),
			Vector2(w * 0.97, mid), Vector2(w, d[1])])
	var skin := func(_s: int, _e: int) -> Array: return [mb, canvas]
	_loft(cz, secs, skin)
	_cap(mb, secs[0], cz[0], -1.0, canvas)
	_cap(mb, secs[-1], cz[-1], 1.0, canvas)
	for z in [-0.35, 0.3, 0.9]:
		_strap(mb, secs[1], z, 0.04, seam)
	# Open sides: the shade inside with the seats, pillars, canvas quarters.
	for s in [-1.0, 1.0]:
		mb.limb(Vector3(s * 0.39, 0.97, -1.22), Vector3(s * 0.58, 1.46, -1.01), 0.022, 0.022, TRIM, 4)
		_face(mb, [Vector3(s * 0.44, 0.95, -1.13), Vector3(s * 0.6, 0.75, -0.62), Vector3(s * 0.6, 1.46, -0.62),
			Vector3(s * 0.52, 1.46, -1.1)], Vector3(s, 0, 0), INTERIOR)
		_quad_x(mb, s * 0.6, -0.62, 0.78, 0.75, 1.46, INTERIOR)
		_quad_x(mb, s * 0.604, -0.56, -0.3, 0.9, 1.12, seat)
		_quad_x(mb, s * 0.604, 0.05, 0.76, 0.76, 0.9, seat)
		_quad_x(mb, s * 0.604, 0.48, 0.76, 0.9, 1.26, seat)
		_quad_x(mb, s * 0.69, 0.78, 1.32, 0.74, 1.46, canvas)
		mb.limb(Vector3(s * 0.67, 0.76, 0.8), Vector3(s * 0.69, 1.46, 0.8), 0.025, 0.025, TRIM, 4)
		# Mirror on a stalk off the windscreen frame.
		mb.limb(Vector3(s * 0.46, 1.1, -1.17), Vector3(s * 0.64, 1.2, -1.2), 0.012, 0.012, TRIM, 3)
		mb.box(Vector3(s * 0.67, 1.21, -1.2), Vector3(0.1, 0.07, 0.03), TRIM)
		_end_decal(mb, -1.185, 1.0, s * 0.63, s * 0.71, 1.185, 1.235, SHEEN, 0.0)
	_end_decal(mb, 1.32, 1.0, -0.69, 0.69, 0.74, 1.46, canvas, 0.0)
	_end_decal(mb, 1.32, 1.0, -0.3, 0.3, 1.12, 1.36, GLASS)
	# Wheels: one in front on a fork, two at the back in arches.
	for s in [-1.0, 1.0]:
		_wheel(mb, s * 0.055, -1.02, 0.2, 0.055, rim, false, 0)
		mb.limb(Vector3(s * 0.075, 0.2, -1.02), Vector3(s * 0.075, 0.46, -1.1), 0.02, 0.02, TRIM, 4)
		_wheel(mb, s * (_at(st, 0.82, 1) + 0.012), 0.82, 0.22, 0.13, rim, true)
	# Cowl: twin round lamps in chrome rings, indicators, a vent, the plate.
	for s in [-1.0, 1.0]:
		_disc(mb, Vector3(s * 0.17, 0.8, -1.357), 0.085, Vector3.FORWARD, RIM)
		_disc(mb, Vector3(s * 0.17, 0.8, -1.362), 0.065, Vector3.FORWARD, HEAD)
		_end_decal(mb, -1.35, -1.0, s * 0.2, s * 0.28, 0.9, 0.93, AMBER, 0.008)
	_end_decal(mb, -1.35, -1.0, -0.07, 0.07, 0.58, 0.7, TRIM, 0.008)
	_end_decal(mb, -1.35, -1.0, -0.14, 0.14, 0.46, 0.54, PLATE, 0.008)
	# Tail: lamps, indicators, plate, bumper bar, engine and exhaust.
	for s in [-1.0, 1.0]:
		_end_decal(mb, 1.35, 1.0, s * 0.36, s * 0.54, 0.58, 0.68, TAIL, 0.008)
		_end_decal(mb, 1.35, 1.0, s * 0.36, s * 0.44, 0.52, 0.57, AMBER, 0.008)
	_end_decal(mb, 1.35, 1.0, -0.15, 0.15, 0.44, 0.54, PLATE, 0.008)
	mb.box(Vector3(0, 0.36, 1.37), Vector3(1.1, 0.06, 0.06), TRIM)
	mb.box(Vector3(0.05, 0.2, 0.9), Vector3(0.62, 0.22, 0.5), Color(0.2, 0.2, 0.22))
	mb.limb(Vector3(-0.3, 0.28, 1.15), Vector3(-0.32, 0.26, 1.4), 0.03, 0.03, RIM, 5)


## Three-wheel cargo trike: a one-seat cab-over with a steep windscreen on
## a single front wheel, a drop-side bed on the rear axle under a roped
## tarp, a headboard rack behind the cab.
static func _cargo_trike(mb, g, paint: Color) -> void:
	var rim := Color(0.3, 0.31, 0.33)
	var st := [[-1.7, 0.5, 0.44, 0.86], [-1.6, 0.62, 0.42, 0.97], [-1.42, 0.68, 0.42, 1.0], [-0.42, 0.7, 0.42, 1.02]]
	_hull(mb, g, st, paint, Vector2(-1.42, -0.42))
	# Cab: windscreen up to the roof, side windows, closed back wall.
	var zs := [-1.42, -1.06, -0.42]
	var secs := []
	for i in zs.size():
		var z: float = zs[i]
		var wb := _at(st, z, 1) * 0.97
		var yb := _at(st, z, 3) - 0.04
		if i == 0:
			secs.append([Vector2(-wb, yb), Vector2(-wb, yb), Vector2(-wb, yb), Vector2(wb, yb), Vector2(wb, yb), Vector2(wb, yb)])
		else:
			secs.append([Vector2(-wb, yb), Vector2(-wb, 1.6), Vector2(-wb * 0.88, 1.84), Vector2(wb * 0.88, 1.84), Vector2(wb, 1.6),
				Vector2(wb, yb)])
	var looks := [[GLASS, TRIM, GLASS], [GLASS, paint, paint]]
	var skin := func(s: int, e: int) -> Array: return [g, looks[s][mini(e, 4 - e)]]
	_loft(zs, secs, skin)
	_cap(g, secs[-1], zs[-1], 1.0, paint)
	_interior(g, [zs, secs], 0, -1, 2)
	_glass_sheen(g, [zs, secs], 0, 2)
	_lamps(mb, st, true, false, 0.3)
	_seams(mb, st, paint, -1.62, -INF, [-1.36, -0.46])
	_mirrors(mb, st, -1.3, 0.2, Vector3(0.07, 0.16, 0.08))
	# Front wheel on its fork, rear wheels under the bed.
	for s in [-1.0, 1.0]:
		_wheel(mb, s * 0.06, -1.12, 0.22, 0.06, rim, false, 0)
		mb.limb(Vector3(s * 0.08, 0.22, -1.12), Vector3(s * 0.08, 0.46, -1.2), 0.02, 0.02, TRIM, 4)
		_wheel(mb, s * 0.72, 1.02, 0.24, 0.14, rim, false)
	# Bed: platform, drop sides with ribs and rails, headboard, tailgate.
	var side := paint.darkened(0.12)
	mb.box(Vector3(0, 0.55, 0.65), Vector3(1.5, 0.12, 2.12), TRIM)
	for s in [-1.0, 1.0]:
		g.box(Vector3(s * 0.725, 0.81, 0.65), Vector3(0.05, 0.4, 2.08), side)
		mb.box(Vector3(s * 0.725, 1.02, 0.65), Vector3(0.07, 0.03, 2.1), TRIM)
		for z in [-0.05, 0.45, 0.95, 1.45]:
			_quad_x(mb, s * 0.753, z - 0.02, z + 0.02, 0.62, 1.0, side.darkened(0.25))
	g.box(Vector3(0, 0.98, -0.37), Vector3(1.48, 0.76, 0.06), side)
	mb.box(Vector3(0, 1.37, -0.37), Vector3(1.5, 0.04, 0.08), TRIM)
	g.box(Vector3(0, 0.81, 1.68), Vector3(1.5, 0.4, 0.05), side)
	mb.box(Vector3(0, 1.02, 1.68), Vector3(1.5, 0.03, 0.07), TRIM)
	# Tarp over the load, roped down.
	var tarp := Color(0.16, 0.34, 0.62) if paint.b < 0.5 else Color(0.45, 0.43, 0.3)
	var lz := [-0.3, -0.16, 1.5, 1.62]
	var dims := [[0.58, 1.24], [0.69, 1.42], [0.69, 1.42], [0.58, 1.26]]
	var tsecs := []
	for d in dims:
		var w: float = d[0]
		var yt: float = d[1]
		var ys := lerpf(0.99, yt, 0.75)
		tsecs.append([Vector2(-w, 0.99), Vector2(-w, ys), Vector2(-w * 0.78, yt), Vector2(w * 0.78, yt), Vector2(w, ys),
			Vector2(w, 0.99)])
	var tskin := func(_s: int, _e: int) -> Array: return [mb, tarp]
	_loft(lz, tsecs, tskin)
	_cap(mb, tsecs[0], lz[0], -1.0, tarp)
	_cap(mb, tsecs[-1], lz[-1], 1.0, tarp)
	for z in [0.1, 0.62, 1.14]:
		_strap(mb, tsecs[1], z, 0.03, Color(0.85, 0.82, 0.7))
	# Tail lamps and the plate on the platform's end.
	for s in [-1.0, 1.0]:
		mb.box(Vector3(s * 0.56, 0.55, 1.72), Vector3(0.2, 0.08, 0.02), TAIL)
	mb.box(Vector3(0, 0.43, 1.72), Vector3(0.28, 0.12, 0.02), PLATE)


## Ten-wheel tipper: a flat-fronted day cab with a chrome-barred grille, a
## steel tub (a gravel load heaped in it) with a guard over the cab, the
## hoist ram, a side fuel tank and an exhaust stack; one steer axle and a
## tandem of twin-tyred drive axles.
static func _tipper(mb, g, paint: Color) -> void:
	var tub := paint if paint.r > 0.9 and paint.b < 0.5 else Color(0.34, 0.35, 0.37)
	var st := [[-4.22, 1.16, 0.7, 1.7], [-4.12, 1.22, 0.66, 1.8], [-2.55, 1.24, 0.66, 1.82]]
	_hull(mb, g, st, paint, Vector2(-4.12, -2.55))
	# Cab: near-upright windscreen, side windows, painted rear corners.
	var zs := [-4.12, -3.98, -3.1, -2.55]
	var secs := []
	for i in zs.size():
		var z: float = zs[i]
		var wb := _at(st, z, 1) * 0.97
		var yb := _at(st, z, 3) - 0.04
		if i == 0:
			secs.append([Vector2(-wb, yb), Vector2(-wb, yb), Vector2(-wb, yb), Vector2(wb, yb), Vector2(wb, yb), Vector2(wb, yb)])
		else:
			secs.append([Vector2(-wb, yb), Vector2(-wb, 2.64), Vector2(-wb * 0.92, 2.96), Vector2(wb * 0.92, 2.96), Vector2(wb, 2.64),
				Vector2(wb, yb)])
	var looks := [[GLASS, TRIM, GLASS], [GLASS, paint, paint], [paint, paint, paint]]
	var skin := func(s: int, e: int) -> Array: return [g, looks[s][mini(e, 4 - e)]]
	_loft(zs, secs, skin)
	_cap(g, secs[-1], zs[-1], 1.0, paint)
	var gq := _glass_quad([zs, secs], 0, 2)
	_dash(g, gq)
	_sheen(g, gq)
	_gq_decal(g, gq, 0.0, 1.0, 0.86, 1.0, paint, 0.008)
	mb.box(Vector3(0, 2.86, -4.1), Vector3(2.3, 0.05, 0.26), TRIM) # sun visor
	for x in [-0.5, 0.0, 0.5]:
		mb.box(Vector3(x, 2.985, -3.85), Vector3(0.14, 0.05, 0.06), AMBER)
	# Nose: barred grille, steel bumper with the lamps and the plate.
	_end_decal(mb, -4.22, -1.0, -0.78, 0.78, 1.0, 1.62, TRIM, 0.008)
	for y in [1.1, 1.24, 1.38, 1.52]:
		_end_decal(mb, -4.22, -1.0, -0.76, 0.76, y, y + 0.04, RIM, 0.012)
	mb.box(Vector3(0, 0.62, -4.22), Vector3(2.46, 0.34, 0.16), Color(0.36, 0.37, 0.39))
	for s in [-1.0, 1.0]:
		_end_decal(mb, -4.3, -1.0, s * 0.7, s * 1.06, 0.66, 0.76, HEAD)
		_end_decal(mb, -4.3, -1.0, s * 0.92, s * 1.08, 0.53, 0.61, AMBER)
	_end_decal(mb, -4.3, -1.0, -0.22, 0.22, 0.5, 0.62, PLATE)
	_side_decal(mb, st, -4.18, -4.05, 1.48, 1.62, AMBER)
	# Doors, mirrors on arms, the grab handle and the step behind the wheel.
	_seams(mb, st, paint, -4.17, -INF, [-4.0, -3.05])
	_mirrors(mb, st, -3.95, 0.5, Vector3(0.1, 0.5, 0.2))
	for s in [-1.0, 1.0]:
		_quad_x(mb, s * (_at(st, -3.05, 1) * 0.97 + 0.006), -3.062, -3.038, 1.8, 2.6, paint.darkened(0.55))
		mb.limb(Vector3(s * 1.2, 2.55, -3.98), Vector3(s * 1.3, 2.55, -3.95), 0.02, 0.02, TRIM, 4)
		_side_decal(mb, st, -2.9, -2.86, 0.85, 1.6, TRIM)
		mb.box(Vector3(s * 1.1, 0.48, -2.72), Vector3(0.24, 0.06, 0.3), STEEL)
	# Chassis: frame, fuel tank, battery box, exhaust stack, hoist ram,
	# side guards.
	mb.box(Vector3(0, 0.92, 0.85), Vector3(1.0, 0.3, 6.7), TRIM)
	mb.limb(Vector3(-0.98, 0.78, -2.2), Vector3(-0.98, 0.78, -1.0), 0.27, 0.27, RIM, 8)
	mb.box(Vector3(0.96, 0.8, -1.6), Vector3(0.4, 0.5, 0.7), TRIM)
	mb.limb(Vector3(1.08, 1.1, -2.42), Vector3(1.08, 2.9, -2.42), 0.07, 0.07, RIM, 6)
	mb.limb(Vector3(0, 1.05, -2.3), Vector3(0, 2.4, -2.15), 0.13, 0.11, STEEL, 6)
	for s in [-1.0, 1.0]:
		for y in [0.62, 0.9]:
			mb.box(Vector3(s * 1.15, y, 0.25), Vector3(0.05, 0.1, 2.3), STEEL)
	# Tub: body, raised side walls with ribs, front wall and cab guard,
	# tailgate, rails, markers, and the heaped load.
	var z0 := -2.05
	var z1 := 4.25
	var zc := (z0 + z1) * 0.5
	g.box(Vector3(0, 1.9, zc), Vector3(2.48, 1.2, z1 - z0), tub)
	for s in [-1.0, 1.0]:
		g.box(Vector3(s * 1.18, 2.67, zc), Vector3(0.12, 0.34, z1 - z0), tub)
		for k in 9:
			var z := z0 + 0.35 + k * 0.7
			_quad_x(mb, s * 1.246, z - 0.04, z + 0.04, 1.3, 2.84, tub.darkened(0.3))
		_quad_x(mb, s * 1.248, z0, z1, 1.3, 1.4, tub.darkened(0.45))
		_quad_x(mb, s * 1.248, z0, z1, 2.76, 2.84, tub.darkened(0.2))
		for z in [-1.5, 1.1, 3.7]:
			_quad_x(mb, s * 1.252, z - 0.05, z + 0.05, 1.5, 1.58, AMBER)
	g.box(Vector3(0, 2.8, z0 + 0.06), Vector3(2.48, 0.6, 0.12), tub)
	g.box(Vector3(0, 3.08, z0 - 0.6), Vector3(2.2, 0.06, 1.2), tub)
	g.box(Vector3(0, 2.67, z1 - 0.06), Vector3(2.36, 0.34, 0.12), tub)
	_end_decal(mb, z1, 1.0, -1.24, 1.24, 2.78, 2.84, tub.darkened(0.4))
	for x in [-0.8, 0.0, 0.8]:
		_end_decal(mb, z1, 1.0, x - 0.04, x + 0.04, 1.3, 2.78, tub.darkened(0.3))
	var lo := [Vector3(-1.12, 2.52, z0 + 0.14), Vector3(1.12, 2.52, z0 + 0.14), Vector3(1.12, 2.52, z1 - 0.14),
		Vector3(-1.12, 2.52, z1 - 0.14)]
	var hi := [Vector3(-0.45, 2.98, z0 + 1.2), Vector3(0.45, 2.98, z0 + 1.2), Vector3(0.45, 2.98, z1 - 1.6),
		Vector3(-0.45, 2.98, z1 - 1.6)]
	_face(mb, hi, Vector3.UP, GRAVEL.lightened(0.08))
	_face(mb, [lo[0], lo[1], hi[1], hi[0]], Vector3(0, 1, -1), GRAVEL)
	_face(mb, [lo[2], lo[3], hi[3], hi[2]], Vector3(0, 1, 1), GRAVEL.darkened(0.06))
	_face(mb, [lo[3], lo[0], hi[0], hi[3]], Vector3(-1, 1, 0), GRAVEL.darkened(0.1))
	_face(mb, [lo[1], lo[2], hi[2], hi[1]], Vector3(1, 1, 0), GRAVEL.darkened(0.1))
	# Rear: light bar with the tail lamps and plate, underride bar, flaps.
	mb.box(Vector3(0, 1.1, 4.15), Vector3(2.3, 0.3, 0.1), TRIM)
	for s in [-1.0, 1.0]:
		_end_decal(mb, 4.2, 1.0, s * 0.8, s * 1.1, 1.0, 1.2, TAIL)
		_end_decal(mb, 4.2, 1.0, s * 0.6, s * 0.76, 1.04, 1.16, AMBER)
		_end_decal(mb, 3.98, 1.0, s * 0.95, s * 1.25, 0.25, 0.9, TRIM, 0.0)
	_end_decal(mb, 4.2, 1.0, -0.25, 0.25, 0.98, 1.2, PLATE)
	mb.box(Vector3(0, 0.56, 4.18), Vector3(2.3, 0.16, 0.12), TRIM)
	# Wheels: single steer tyres in arches, twin tyres on the tandem.
	for s in [-1.0, 1.0]:
		_truck_wheel(mb, s * (_at(st, -3.45, 1) + 0.012), -3.45, 0.52, 0.32, false, true)
		for z in [2.0, 3.35]:
			_truck_wheel(mb, s * 1.24, z, 0.52, 0.62, true)


## Eighteen-wheel semi: a long-nosed tractor with a chrome grille, roof
## fairing, twin stacks and chrome tanks, coupled to a long box trailer
## with a livery band, side skirts and reflective tape. One rigid body
## (vehicle.gd has no hitch), so it turns wide; population.gd sets it off
## only on streets with two or more lanes each way.
static func _semi(mb, g, paint: Color) -> void:
	var st := [[-7.36, 1.0, 0.66, 1.6], [-7.24, 1.12, 0.6, 1.74], [-6.0, 1.2, 0.62, 1.9], [-5.82, 1.25, 1.08, 1.98],
		[-4.0, 1.25, 1.08, 1.98]]
	_hull(mb, g, st, paint, Vector2(-5.82, -4.0))
	# Cab with a raked split windscreen, door windows and the sleeper.
	var zs := [-5.82, -5.42, -4.86, -4.0]
	var secs := []
	for i in zs.size():
		var z: float = zs[i]
		var wb := _at(st, z, 1) * 0.97
		var yb := _at(st, z, 3) - 0.04
		if i == 0:
			secs.append([Vector2(-wb, yb), Vector2(-wb, yb), Vector2(-wb, yb), Vector2(wb, yb), Vector2(wb, yb), Vector2(wb, yb)])
		else:
			secs.append([Vector2(-wb, yb), Vector2(-wb, 2.7), Vector2(-wb * 0.9, 3.0), Vector2(wb * 0.9, 3.0), Vector2(wb, 2.7),
				Vector2(wb, yb)])
	var looks := [[GLASS, TRIM, GLASS], [GLASS, paint, paint], [paint, paint, paint]]
	var skin := func(s: int, e: int) -> Array: return [g, looks[s][mini(e, 4 - e)]]
	_loft(zs, secs, skin)
	_cap(g, secs[-1], zs[-1], 1.0, paint)
	var gq := _glass_quad([zs, secs], 0, 2)
	_dash(g, gq)
	_sheen(g, gq)
	_gq_decal(g, gq, 0.0, 1.0, 0.88, 1.0, paint, 0.008)
	_gq_decal(g, gq, 0.485, 0.515, 0.0, 0.88, TRIM, 0.008)
	mb.box(Vector3(0, 2.97, -5.52), Vector3(2.2, 0.05, 0.24), TRIM) # sun visor
	# Roof fairing up to the trailer's height, marker lamps ahead of it.
	var fz := [-5.3, -4.05]
	var fsecs := [[Vector2(-0.95, 2.99), Vector2(-0.9, 3.0), Vector2(0.9, 3.0), Vector2(0.95, 2.99)],
		[Vector2(-1.1, 2.99), Vector2(-1.06, 3.92), Vector2(1.06, 3.92), Vector2(1.1, 2.99)]]
	var fskin := func(_s: int, _e: int) -> Array: return [g, paint]
	_loft(fz, fsecs, fskin)
	_cap(g, fsecs[1], fz[1], 1.0, paint)
	for x in [-0.6, -0.3, 0.0, 0.3, 0.6]:
		mb.box(Vector3(x, 3.02, -5.36), Vector3(0.1, 0.05, 0.05), AMBER)
	# Nose: chrome grille with slots, lamps in the fenders, chrome bumper.
	_end_decal(mb, -7.36, -1.0, -0.62, 0.62, 0.74, 1.54, RIM, 0.008)
	for k in 5:
		var y := 0.84 + k * 0.14
		_end_decal(mb, -7.36, -1.0, -0.56, 0.56, y, y + 0.06, TRIM, 0.012)
	for s in [-1.0, 1.0]:
		_end_decal(mb, -7.36, -1.0, s * 0.7, s * 0.96, 1.08, 1.26, HEAD, 0.008)
		_end_decal(mb, -7.36, -1.0, s * 0.72, s * 0.94, 0.96, 1.04, AMBER, 0.008)
		_top_decal(mb, st, s * 0.78 - 0.012, s * 0.78 + 0.012, -7.3, -5.95, paint.darkened(0.55))
	mb.box(Vector3(0, 0.6, -7.43), Vector3(2.42, 0.36, 0.14), RIM)
	_end_decal(mb, -7.5, -1.0, -0.22, 0.22, 0.48, 0.6, PLATE)
	# Doors, mirrors on arms, chrome tanks under the doors, the stacks.
	_seams(mb, st, paint, -5.95, -INF, [-5.76, -4.84])
	_mirrors(mb, st, -5.6, 0.55, Vector3(0.1, 0.55, 0.2))
	for s in [-1.0, 1.0]:
		_quad_x(mb, s * (_at(st, -4.84, 1) * 0.97 + 0.006), -4.852, -4.828, 1.96, 2.66, paint.darkened(0.55))
		mb.limb(Vector3(s * 1.22, 2.8, -5.62), Vector3(s * 1.32, 2.8, -5.6), 0.02, 0.02, TRIM, 4)
		mb.limb(Vector3(s * 0.97, 0.8, -5.74), Vector3(s * 0.97, 0.8, -4.5), 0.28, 0.28, RIM, 8)
		mb.limb(Vector3(s * 1.17, 1.2, -3.93), Vector3(s * 1.17, 3.98, -3.93), 0.075, 0.075, RIM, 6)
		_end_decal(mb, -1.55, 1.0, s * 0.95, s * 1.25, 0.2, 0.95, TRIM, 0.0)
	mb.box(Vector3(0, 0.95, -2.7), Vector3(1.0, 0.3, 2.6), TRIM)
	# Trailer: box, roof bows, frame, bogie subframe, livery band, tape,
	# markers, side skirts, landing legs and mud flaps.
	var body := VAN_WHITE if paint.get_luminance() < 0.8 else Color(0.7, 0.72, 0.75)
	g.box(Vector3(0, 2.64, 1.805), Vector3(2.55, 2.68, 11.31), body)
	for k in 9:
		g.box(Vector3(0, 3.985, -3.2 + k * 1.3), Vector3(2.45, 0.012, 0.06), body.darkened(0.1))
	mb.box(Vector3(0, 1.2, 1.8), Vector3(1.1, 0.2, 11.2), TRIM)
	mb.box(Vector3(0, 1.12, 5.9), Vector3(1.9, 0.3, 2.6), TRIM)
	for s in [-1.0, 1.0]:
		_quad_x(mb, s * 1.281, -3.4, 7.0, 2.15, 3.2, paint)
		_quad_x(mb, s * 1.281, -3.4, 7.0, 2.0, 2.08, paint.darkened(0.35))
		_quad_x(mb, s * 1.281, -3.85, 7.46, 1.3, 1.42, TRIM)
		_quad_x(mb, s * 1.283, -3.6, 7.2, 1.44, 1.5, Color.WHITE)
		for k in 11:
			var z := -3.6 + k * (10.8 / 11.0)
			_quad_x(mb, s * 1.286, z, z + 10.8 / 22.0, 1.44, 1.5, TAIL)
		for z in [-3.6, 1.8, 7.2]:
			_quad_x(mb, s * 1.284, z - 0.05, z + 0.05, 1.6, 1.68, AMBER)
		_quad_x(mb, s * 1.284, -3.84, -3.74, 3.8, 3.9, AMBER)
		_quad_x(mb, s * 1.25, -0.7, 4.55, 0.4, 1.3, body.darkened(0.12))
		mb.box(Vector3(s * 0.85, 0.81, -1.3), Vector3(0.12, 0.98, 0.12), STEEL)
		mb.box(Vector3(s * 0.85, 0.33, -1.3), Vector3(0.3, 0.04, 0.3), STEEL)
		_end_decal(mb, 7.08, 1.0, s * 0.66, s * 1.26, 0.2, 0.95, TRIM, 0.0)
	# Rear doors: lock bars, split line, tape, lamps on the sill, markers,
	# underride bar with the plate.
	_end_decal(mb, 7.46, 1.0, -1.2, 1.2, 1.44, 3.9, body.darkened(0.06))
	_end_decal(mb, 7.46, 1.0, -0.015, 0.015, 1.44, 3.9, TRIM, 0.01)
	for x in [-0.85, -0.3, 0.3, 0.85]:
		_end_decal(mb, 7.46, 1.0, x - 0.025, x + 0.025, 1.5, 3.85, RIM, 0.012)
		_end_decal(mb, 7.46, 1.0, x - 0.07, x + 0.07, 2.1, 2.15, TRIM, 0.015)
	for s in [-1.0, 1.0]:
		_end_decal(mb, 7.46, 1.0, s * 1.15, s * 1.27, 3.55, 3.95, TAIL, 0.012)
		_end_decal(mb, 7.46, 1.0, s * 0.8, s * 1.15, 1.31, 1.41, TAIL, 0.014)
		_end_decal(mb, 7.46, 1.0, s * 0.55, s * 0.75, 1.31, 1.41, AMBER, 0.014)
		mb.box(Vector3(s * 0.7, 0.92, 7.3), Vector3(0.1, 0.76, 0.1), TRIM)
	for x in [-0.3, 0.0, 0.3]:
		_end_decal(mb, 7.46, 1.0, x - 0.05, x + 0.05, 3.85, 3.92, TAIL, 0.012)
	mb.box(Vector3(0, 0.52, 7.38), Vector3(2.3, 0.14, 0.12), TRIM)
	_end_decal(mb, 7.44, 1.0, -0.22, 0.22, 0.46, 0.58, PLATE)
	# Wheels: steer tyres in arches, twin tyres on the two drive axles and
	# the trailer's tandem: eighteen in all.
	for s in [-1.0, 1.0]:
		_truck_wheel(mb, s * (_at(st, -6.55, 1) + 0.012), -6.55, 0.52, 0.32, false, true)
		for z in [-3.35, -2.15, 5.3, 6.5]:
			_truck_wheel(mb, s * 1.26, z, 0.52, 0.6, true)


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


## A flat round disc (lamp lens, chrome ring) at `c` facing `n`.
static func _disc(m, c: Vector3, r: float, n: Vector3, color: Color, sides := 8) -> void:
	var u := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
	var v := n.cross(u)
	for k in sides:
		var a0 := TAU * k / sides
		var a1 := TAU * (k + 1) / sides
		_tri(m, c, c + (u * cos(a0) + v * sin(a0)) * r, c + (u * cos(a1) + v * sin(a1)) * r, n, color)


## A band `width` long from `z` laid over the lofted section `sec`
## (Vector2 x/y points), lifted just off it: tarp straps, ropes.
static func _strap(m, sec: Array, z: float, width: float, color: Color) -> void:
	var mid := Vector2.ZERO
	for p in sec:
		mid += p
	mid /= sec.size()
	for e in sec.size() - 1:
		var a: Vector2 = sec[e]
		var b: Vector2 = sec[e + 1]
		var d := b - a
		if d.length() < 1e-4:
			continue
		var n := Vector3(-d.y, d.x, 0.0).normalized()
		var out := (a + b) * 0.5 - mid
		if n.x * out.x + n.y * out.y < 0.0:
			n = -n
		var lift := n * 0.012
		_face(m, [Vector3(a.x, a.y, z) + lift, Vector3(b.x, b.y, z) + lift,
				Vector3(b.x, b.y, z + width) + lift, Vector3(a.x, a.y, z + width) + lift], n, color)


## Two slanted light streaks across the top glass of loft segment `seg`
## (`top` = index of the section's first top point).
static func _glass_sheen(g, loft: Array, seg: int, top := 1) -> void:
	_sheen(g, _glass_quad(loft, seg, top))


## The two light streaks on glass quad `gq` (see _gq).
static func _sheen(g, gq: Array) -> void:
	for band in [[0.14, 0.3, 0.3, 0.46], [0.36, 0.42, 0.52, 0.58]]:
		var pts := []
		for uv in [Vector2(band[0], 0.08), Vector2(band[1], 0.08), Vector2(band[3], 0.92), Vector2(band[2], 0.92)]:
			pts.append(_glass_at(gq, uv.x, uv.y, 0.006))
		_face(g, pts, gq[1], SHEEN)


## The top glass quad of loft segment `seg` (`top` = index of the section's
## first top point) and its upward normal: [corners, normal]. Corner 0 is
## the left end of the segment's first station (u runs left to right, v
## from that station to the next).
static func _glass_quad(loft: Array, seg: int, top := 1) -> Array:
	var zs: Array = loft[0]
	var secs: Array = loft[1]
	var a: Array = secs[seg]
	var b: Array = secs[seg + 1]
	return _gq([Vector3(a[top].x, a[top].y, zs[seg]), Vector3(a[top + 1].x, a[top + 1].y, zs[seg]),
		Vector3(b[top + 1].x, b[top + 1].y, zs[seg + 1]), Vector3(b[top].x, b[top].y, zs[seg + 1])])


## A glass quad from its corners (0 to 1 along the near edge, 3 to 2 along
## the far one) and its upward normal: [corners, normal].
static func _gq(q: Array) -> Array:
	var n: Vector3 = (q[1] - q[0]).cross(q[3] - q[0])
	if n.length() < 1e-6:
		n = (q[2] - q[3]).cross(q[3] - q[0])
	n = n.normalized()
	if n.y < 0.0:
		n = -n
	return [q, n]


static func _glass_at(gq: Array, u: float, v: float, lift: float) -> Vector3:
	var q: Array = gq[0]
	return q[0].lerp(q[1], u).lerp(q[3].lerp(q[2], u), v) + gq[1] * lift


## A rectangle (in the glass quad's u, v) painted on a glass segment.
static func _glass_decal(g, loft: Array, seg: int, u0: float, u1: float, v0: float, v1: float, color: Color, top := 1) -> void:
	_gq_decal(g, _glass_quad(loft, seg, top), u0, u1, v0, v1, color)


## A rectangle (in u, v) painted on glass quad `gq`.
static func _gq_decal(g, gq: Array, u0: float, u1: float, v0: float, v1: float, color: Color, lift := 0.004) -> void:
	_face(g, [_glass_at(gq, u0, v0, lift), _glass_at(gq, u1, v0, lift), _glass_at(gq, u1, v1, lift),
		_glass_at(gq, u0, v1, lift)], gq[1], color)


## The cabin seen through the glass, painted on it (the shell is opaque):
## the dashboard, the steering wheel on the left (traffic keeps right) and
## the front seat backs behind the windscreen, loft segment `front`; the
## rear headrests and the parcel shelf through the rear window, segment
## `back` (-1 for none).
static func _interior(g, loft: Array, front: int, back: int, top := 1) -> void:
	_dash(g, _glass_quad(loft, front, top))
	if back >= 0:
		var gq := _glass_quad(loft, back, top)
		for u in [0.26, 0.74]:
			_gq_decal(g, gq, u - 0.09, u + 0.09, 0.4, 0.66, SEAT)
		_gq_decal(g, gq, 0.03, 0.97, 0.84, 1.0, INTERIOR)


## The dashboard, the steering wheel on the left and the front seat backs
## seen through windscreen quad `gq` (v = 0 at its base).
static func _dash(g, gq: Array) -> void:
	_gq_decal(g, gq, 0.03, 0.97, 0.0, 0.2, INTERIOR)
	var hub := _glass_at(gq, 0.29, 0.24, 0.004)
	for k in 6:
		var a0 := TAU * k / 6.0
		var a1 := TAU * (k + 1) / 6.0
		_tri(g, hub, _glass_at(gq, 0.29 + cos(a0) * 0.085, 0.24 + sin(a0) * 0.1, 0.004),
			_glass_at(gq, 0.29 + cos(a1) * 0.085, 0.24 + sin(a1) * 0.1, 0.004), gq[1], INTERIOR)
	for u in [0.3, 0.7]:
		_gq_decal(g, gq, u - 0.1, u + 0.1, 0.56, 0.84, SEAT)


## Four wheels (or as many axles as given) flush with the hull sides.
static func _wheels(mb, st: Array, axles: Array, r: float, width := 0.26, rim := RIM) -> void:
	for z in axles:
		for s in [-1.0, 1.0]:
			_wheel(mb, s * (_at(st, z, 1) + 0.012), z, r, width, rim, true)


## One wheel with its outer face at x = x_out: a ten-sided tyre, a rim with
## a darker lip, `spokes` spoke gaps and a centre cap, and, if `arch`, a
## dark wheel well on the body round its top.
static func _wheel(mb, x_out: float, z: float, r: float, width: float, rim: Color, arch: bool, spokes := 5) -> void:
	var s := signf(x_out)
	var out := Vector3(s, 0, 0)
	var xi := x_out - s * width
	var c := Vector3(x_out, r, z)
	var lip := rim.darkened(0.45)
	_tread(mb, x_out, xi, z, r)
	for i in 10:
		var a0 := TAU * i / 10.0 - PI / 10.0
		var a1 := a0 + TAU / 10.0
		var d0 := Vector3(0, sin(a0), cos(a0))
		var d1 := Vector3(0, sin(a1), cos(a1))
		_tri(mb, c, c + d0 * r, c + d1 * r, out, TYRE)
		_tri(mb, c + out * 0.004, c + out * 0.004 + d0 * r * 0.68, c + out * 0.004 + d1 * r * 0.68, out, lip)
		_tri(mb, c + out * 0.007, c + out * 0.007 + d0 * r * 0.6, c + out * 0.007 + d1 * r * 0.6, out, rim)
	var gap := c + out * 0.01
	for k in spokes:
		var a := TAU * k / spokes + PI / 2.0 + PI / spokes
		_tri(mb, gap + Vector3(0, sin(a), cos(a)) * r * 0.2, gap + Vector3(0, sin(a - 0.36), cos(a - 0.36)) * r * 0.53,
			gap + Vector3(0, sin(a + 0.36), cos(a + 0.36)) * r * 0.53, out, SPOKE_GAP)
	var hub := c + out * 0.013
	for k in 6:
		var a0 := TAU * k / 6.0
		var a1 := TAU * (k + 1) / 6.0
		_tri(mb, hub, hub + Vector3(0, sin(a0), cos(a0)) * r * 0.14, hub + Vector3(0, sin(a1), cos(a1)) * r * 0.14, out, lip)
	if arch:
		var ac := Vector3(x_out - s * 0.008, r, z)
		for k in 6:
			var b0 := -0.18 + (PI + 0.36) * k / 6.0
			var b1 := -0.18 + (PI + 0.36) * (k + 1) / 6.0
			var e0 := Vector3(0, sin(b0), cos(b0))
			var e1 := Vector3(0, sin(b1), cos(b1))
			_face(mb, [ac + e0 * r * 1.0, ac + e1 * r * 1.0, ac + e1 * r * 1.13, ac + e0 * r * 1.13], out, WELL)


## A truck wheel at x = x_out over `width`: tyre, painted steel disc with
## hand holes and a raised hub; `dual` splits the width into two tyres with
## a gap between (the inner one's tread shows front and back).
static func _truck_wheel(mb, x_out: float, z: float, r: float, width: float, dual: bool, arch := false) -> void:
	var s := signf(x_out)
	var w1 := width * 0.46 if dual else width
	_wheel(mb, x_out, z, r, w1, STEEL, arch, 0)
	if dual:
		_tread(mb, x_out - s * (width - w1), x_out - s * width, z, r)
	var out := Vector3(s, 0, 0)
	var c := Vector3(x_out, r, z) + out * 0.016
	for k in 6:
		var a := TAU * k / 6.0 + PI / 6.0
		var p := c + Vector3(0, sin(a), cos(a)) * r * 0.4
		_face(mb, [p + Vector3(0, 0.08, 0.08) * r, p + Vector3(0, 0.08, -0.08) * r, p + Vector3(0, -0.08, -0.08) * r,
			p + Vector3(0, -0.08, 0.08) * r], out, SPOKE_GAP)
	mb.box(Vector3(x_out + s * 0.03, r, z), Vector3(0.06, r * 0.34, r * 0.34), STEEL.darkened(0.25))


## The tread of a tyre from x = xa to xb where it shows (front, back and
## low down; the top hides under the body, the bottom on the road).
static func _tread(mb, xa: float, xb: float, z: float, r: float) -> void:
	for i in 10:
		var a0 := TAU * i / 10.0 - PI / 10.0
		var a1 := a0 + TAU / 10.0
		var d0 := Vector3(0, sin(a0), cos(a0))
		var d1 := Vector3(0, sin(a1), cos(a1))
		var mid := (d0 + d1).normalized()
		if mid.y > -0.9 and mid.y < 0.5:
			_face(mb, [Vector3(xb, r, z) + d0 * r, Vector3(xa, r, z) + d0 * r, Vector3(xa, r, z) + d1 * r, Vector3(xb, r, z) + d1 * r], mid, TYRE)


## LED lights. Nose: slim headlamps over amber indicators, wrapping round
## onto the hood and the corners, a thin strip between them (or a black
## grille with a chrome bar when `grille`, its half width as a share of the
## nose, is set), the lower intake and the plate. Tail: lamp clusters with
## amber indicators and reversing lamps, wrapping onto the deck and the
## corners, joined by a thin bar; the bumper and the plate.
static func _lamps(mb, st: Array, front := true, rear := true, grille := 0.0) -> void:
	if front:
		var f: Array = st[0]
		var dz: float = st[1][0] - f[0]
		var w: float = f[1]
		var yt: float = f[3]
		for s in [-1.0, 1.0]:
			_top_decal(mb, st, s * w * 0.36, s * w * 0.76, f[0] + 0.01, f[0] + dz * 0.6, HEAD)
			_end_decal(mb, f[0], -1.0, s * w * 0.42, s * w * 0.8, yt - 0.12, yt - 0.03, HEAD, 0.008)
			_end_decal(mb, f[0], -1.0, s * w * 0.58, s * w * 0.8, yt - 0.16, yt - 0.12, AMBER, 0.008)
		_side_decal(mb, st, f[0] + 0.03, f[0] + 0.15, yt - 0.18, yt - 0.09, HEAD)
		_side_decal(mb, st, f[0] + 0.15, f[0] + 0.22, yt - 0.16, yt - 0.1, AMBER)
		if grille > 0.0:
			_end_decal(mb, f[0], -1.0, -w * grille, w * grille, yt - 0.16, yt - 0.04, TRIM, 0.007)
			_end_decal(mb, f[0], -1.0, -w * grille, w * grille, yt - 0.11, yt - 0.095, RIM, 0.01)
		else:
			_end_decal(mb, f[0], -1.0, -w * 0.8, w * 0.8, yt - 0.08, yt - 0.06, HEAD)
		_end_decal(mb, f[0], -1.0, -w * 0.62, w * 0.62, f[2] + 0.03, f[2] + 0.18, TRIM)
		_end_decal(mb, f[0], -1.0, -0.2, 0.2, f[2] + 0.06, f[2] + 0.15, PLATE, 0.01)
	if rear:
		var r: Array = st[-1]
		var dz: float = r[0] - st[-2][0]
		var w: float = r[1]
		var yt: float = r[3]
		_top_decal(mb, st, -w * 0.76, w * 0.76, r[0] - dz * 0.55, r[0] - 0.01, TAIL)
		_end_decal(mb, r[0], 1.0, -w * 0.84, w * 0.84, yt - 0.07, yt - 0.03, TAIL)
		for s in [-1.0, 1.0]:
			_end_decal(mb, r[0], 1.0, s * w * 0.5, s * w * 0.84, yt - 0.18, yt - 0.03, TAIL, 0.008)
			_end_decal(mb, r[0], 1.0, s * w * 0.7, s * w * 0.82, yt - 0.165, yt - 0.11, AMBER, 0.01)
			_end_decal(mb, r[0], 1.0, s * w * 0.52, s * w * 0.66, yt - 0.165, yt - 0.11, REVERSE, 0.01)
		_side_decal(mb, st, r[0] - 0.2, r[0] - 0.03, yt - 0.18, yt - 0.09, TAIL)
		_end_decal(mb, r[0], 1.0, -w * 0.8, w * 0.8, r[2] + 0.01, r[2] + 0.15, TRIM)
		_end_decal(mb, r[0], 1.0, -0.22, 0.22, r[2] + 0.18, r[2] + 0.29, PLATE)


## Panel gaps: across the hood at `hood_z` and the deck at `deck_z` (-INF
## for none), down the sides at each of `doors`, and along the hood at each x
## of `hood_x` back to `hood_end` (the windscreen). Each door gets a handle
## near its back edge unless `handles` is false.
static func _seams(mb, st: Array, paint: Color, hood_z: float, deck_z: float, doors: Array, hood_x := [], hood_end := 0.0,
		handles := true) -> void:
	var line := paint.darkened(0.55)
	if handles:
		var grip := paint.darkened(0.4) if paint.get_luminance() > 0.3 else paint.lightened(0.3)
		for i in doors.size() - 1:
			var z: float = doors[i + 1] - 0.3
			var yt := _at(st, z, 3)
			_side_decal(mb, st, z, z + 0.17, yt - 0.25, yt - 0.21, grip, 0.01)
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


## Door mirrors just ahead of the front doors: a black foot on the door, the
## housing in `cap` (on the gloss shell `g` when given) and the mirror glass
## facing back.
static func _mirrors(mb, st: Array, z: float, dy := 0.02, size := Vector3(0.18, 0.11, 0.12), g = null, cap := TRIM) -> void:
	var w := _at(st, z, 1)
	var yt := _at(st, z, 3)
	var shell = g if g != null else mb
	for s in [-1.0, 1.0]:
		var c := Vector3(s * (w + 0.06), yt + dy, z)
		mb.box(Vector3(s * (w + 0.01), c.y - size.y * 0.45, z + 0.02), Vector3(0.08, 0.05, size.z * 0.7), TRIM)
		shell.box(c, size, cap)
		var zb := z + size.z * 0.5 + 0.004
		_face(mb, [Vector3(c.x - size.x * 0.4, c.y - size.y * 0.36, zb), Vector3(c.x + size.x * 0.4, c.y - size.y * 0.36, zb),
			Vector3(c.x + size.x * 0.4, c.y + size.y * 0.36, zb), Vector3(c.x - size.x * 0.4, c.y + size.y * 0.36, zb)],
			Vector3.BACK, SHEEN)
