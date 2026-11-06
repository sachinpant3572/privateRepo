## What comes out of a vehicle's tailpipe and off its tyres (Sachin, 0.23:
## exhaust and tyre smoke "based on the type of vehicle, its size and
## category, current pollution norms in US, speed etc.").
##
## US norms set the baseline. A healthy modern petrol car (EPA Tier 3, a
## catalyst) shows nothing but water vapour, and only when the air is cool
## or damp or the engine is cold. Diesel trucks built since 2010 have a
## particulate filter, so they run clean too; California's Truck and Bus
## rule keeps nearly all older trucks off the road, apart from farm
## exemptions and out-of-state rigs. So visible smoke comes from:
## - "old" diesels (pre-filter): a black puff under load and on each
##   upshift;
## - worn engines ("smokers"): blue-grey oil smoke as they pull away. They
##   are rare, and commoner in poorer districts and the country;
## - damage (the engine smoke in vehicle.gd).
## EVs, the e-moped and bicycles emit nothing. Muscle and super cars pop on
## the overrun.
##
## Tyres: every light vehicle since MY2012 has ABS and stability control
## (FMVSS 126), so hard braking leaves faint, broken "shadow" marks and no
## smoke. Locked wheels (handbrake, or an old car without ABS), drifts and
## burnouts leave dark marks and smoke in proportion to the slip speed and
## the load on the tyre. Wet roads leave no marks and no smoke.
##
## fuel: "petrol", "diesel", "electric", "none".
## pipes: tailpipe outlets in the model's frame (-z is the nose), with the
##   outlet direction under "dir".
## tyre: tread width (m); dual: twin rear tyres (trucks); wheels: tracks
##   that mark (2 for cars, 1 for two-wheelers).
## smoker: base chance of a worn engine; old: chance of a pre-filter
##   diesel; pops: overrun pops; abs: false where the US does not require
##   it (motorcycles, three-wheelers, bicycles), so a hard stop locks the
##   wheels and marks dark.

const KINDS := {
	"compact": {"fuel": "petrol", "pipes": [[0.45, 0.3, 1]], "tyre": 0.19, "smoker": 0.03},
	"sedan": {"fuel": "petrol", "pipes": [[0.5, 0.3, 1]], "tyre": 0.22, "smoker": 0.02},
	"taxi": {"fuel": "petrol", "pipes": [[0.5, 0.3, 1]], "tyre": 0.22, "smoker": 0.04},
	"police": {"fuel": "petrol", "pipes": [[-0.55, 0.3, 1], [0.55, 0.3, 1]], "tyre": 0.25, "smoker": 0.0},
	"ev": {"fuel": "electric", "tyre": 0.24},
	"luxury": {"fuel": "petrol", "pipes": [[-0.6, 0.3, 1], [0.6, 0.3, 1]], "tyre": 0.26, "smoker": 0.0},
	"crossover": {"fuel": "petrol", "pipes": [[0.5, 0.35, 1]], "tyre": 0.23, "smoker": 0.02},
	"suv": {"fuel": "petrol", "pipes": [[-0.6, 0.38, 1], [0.6, 0.38, 1]], "tyre": 0.27, "smoker": 0.02},
	"pickup": {"fuel": "petrol", "diesel": 0.3, "pipes": [[0.65, 0.4, 0.92]], "tyre": 0.27, "smoker": 0.03, "old": 0.12},
	"van": {"fuel": "petrol", "diesel": 0.35, "pipes": [[0.55, 0.3, 0.95]], "tyre": 0.23, "smoker": 0.04, "old": 0.1},
	"muv": {"fuel": "petrol", "pipes": [[0.5, 0.3, 1]], "tyre": 0.23, "smoker": 0.02},
	"sports": {"fuel": "petrol", "pipes": [[-0.35, 0.28, 1], [0.35, 0.28, 1]], "tyre": 0.29, "pops": true},
	"muscle": {"fuel": "petrol", "pipes": [[-0.6, 0.3, 1], [-0.45, 0.3, 1], [0.45, 0.3, 1], [0.6, 0.3, 1]], "tyre": 0.3, "pops": true, "smoker": 0.02},
	"super": {"fuel": "petrol", "pipes": [[-0.2, 0.5, 1], [0.2, 0.5, 1]], "tyre": 0.33, "pops": true},
	"roadster": {"fuel": "petrol", "pipes": [[-0.35, 0.28, 1], [0.35, 0.28, 1]], "tyre": 0.27, "pops": true},
	"cabriolet": {"fuel": "petrol", "pipes": [[-0.55, 0.3, 1], [0.55, 0.3, 1]], "tyre": 0.26},
	# Trucks: the box truck exhausts under its right side, ahead of the rear
	# axle; the tipper and the semi through upright stacks behind the cab
	# (positions in metres from the model's centre, as vehicle_kit builds them).
	"box_truck": {"fuel": "diesel", "at": [[1.15, 0.45, 1.2]], "dir": Vector3(1, -0.4, 0), "tyre": 0.28, "dual": true, "old": 0.06},
	"tipper": {"fuel": "diesel", "at": [[1.08, 2.95, -2.42]], "dir": Vector3.UP, "tyre": 0.3, "dual": true, "old": 0.1},
	"semi": {"fuel": "diesel", "at": [[-1.17, 4.02, -3.93], [1.17, 4.02, -3.93]], "dir": Vector3.UP, "tyre": 0.3, "dual": true, "old": 0.07},
	# Single-cylinder three-wheelers: small, often tired engines.
	"tuk_tuk": {"abs": false, "fuel": "petrol", "pipes": [[-0.45, 0.25, 1]], "tyre": 0.13, "smoker": 0.1},
	"cargo_trike": {"abs": false, "fuel": "petrol", "pipes": [[-0.5, 0.3, 1]], "tyre": 0.14, "smoker": 0.1},
	"motorbike": {"abs": false, "fuel": "petrol", "pipes": [[0.18, 0.45, 0.95]], "tyre": 0.18, "wheels": 1, "smoker": 0.02},
	"scooter": {"fuel": "electric", "tyre": 0.11, "wheels": 1},
	"bicycle": {"abs": false, "fuel": "none", "tyre": 0.04, "wheels": 1},
}

## Visible puff colours.
const VAPOUR := Color(0.95, 0.96, 0.98, 0.32)
const SOOT := Color(0.08, 0.08, 0.08, 0.6)
const OIL := Color(0.55, 0.6, 0.7, 0.42)
const HAZE := Color(0.7, 0.7, 0.72, 0.18)
const TYRE := Color(0.9, 0.9, 0.9, 0.55)
const DUST := Color(0.62, 0.52, 0.38, 0.5)


static func of(kind: String) -> Dictionary:
	return KINDS.get(kind, KINDS["sedan"])


## Rolls one vehicle's engine: fuel (some pickups and vans are diesel),
## whether it is a pre-filter diesel and whether it burns oil.
## `poor` (0..1) raises both: older cars gather where money is short.
static func roll(kind: String, rng: RandomNumberGenerator, poor: float) -> Dictionary:
	var e := of(kind)
	var fuel: String = e.fuel
	if fuel == "petrol" and rng.randf() < float(e.get("diesel", 0.0)):
		fuel = "diesel"
	var lift := 1.0 + 2.0 * clampf(poor, 0.0, 1.0)
	return {
		"fuel": fuel,
		"old": fuel == "diesel" and rng.randf() < float(e.get("old", 0.04)) * lift,
		"smoker": fuel == "petrol" and rng.randf() < float(e.get("smoker", 0.0)) * lift,
		"pops": e.get("pops", false),
		"abs": e.get("abs", true),
	}


## Outlets in the vehicle's frame: [position, outward direction].
static func outlets(kind: String, size: Vector3) -> Array:
	var e := of(kind)
	var out := []
	if e.has("at"):
		for p in e.at:
			out.append([Vector3(p[0], p[1], p[2]), (e.dir as Vector3).normalized()])
	for p in e.get("pipes", []):
		# [x, height, fraction of the half length back]
		out.append([Vector3(p[0] * minf(size.x / 1.9, 1.1), p[1], size.z * 0.5 * p[2] + 0.05), Vector3(0, 0.1, 1).normalized()])
	return out


## The wheels that mark, in the vehicle's frame: rear pair first (they slide
## in a drift), then the front pair (they mark when the brakes lock).
static func tracks(kind: String, size: Vector3) -> Dictionary:
	var e := of(kind)
	var w: float = e.tyre * (2.0 if e.get("dual", false) else 1.0)
	var rear := []
	var front := []
	if int(e.get("wheels", 2)) == 1:
		rear.append(Vector3(0, 0, size.z * 0.36))
		front.append(Vector3(0, 0, -size.z * 0.36))
	else:
		var x := size.x * 0.5 - w * 0.5 - 0.06
		rear = [Vector3(-x, 0, size.z * 0.32), Vector3(x, 0, size.z * 0.32)]
		front = [Vector3(-x, 0, -size.z * 0.3), Vector3(x, 0, -size.z * 0.3)]
		if kind == "semi" or kind == "tipper":
			# Long rigs: the marks come from the drive axles under the cab's back.
			rear = [Vector3(-x, 0, -size.z * 0.12), Vector3(x, 0, -size.z * 0.12)]
			front = [Vector3(-x, 0, -size.z * 0.42), Vector3(x, 0, -size.z * 0.42)]
	return {"rear": rear, "front": front, "width": w}
