extends RefCounted
## Cartoon vehicles. Local space: forward is -Z, ground at y = 0. Each kind
## has a distinct silhouette and roof marking, so it reads from the top-down
## camera, plus handling numbers used by vehicle.gd.

const KINDS := {
	"sedan": {"size": Vector3(1.9, 1.4, 4.2), "max_speed": 24.0, "accel": 14.0, "turn": 2.4},
	"taxi": {"size": Vector3(1.9, 1.4, 4.2), "max_speed": 24.0, "accel": 14.0, "turn": 2.4},
	"police": {"size": Vector3(1.95, 1.4, 4.4), "max_speed": 27.0, "accel": 16.0, "turn": 2.5},
	"pickup": {"size": Vector3(2.0, 1.6, 4.9), "max_speed": 22.0, "accel": 12.0, "turn": 2.1},
	"van": {"size": Vector3(2.0, 2.2, 4.8), "max_speed": 20.0, "accel": 11.0, "turn": 2.0},
	"sports": {"size": Vector3(1.95, 1.1, 4.1), "max_speed": 31.0, "accel": 19.0, "turn": 2.8},
}
## Weighted pick list for civilian traffic and parked cars.
const CIVILIAN := ["sedan", "sedan", "sedan", "pickup", "van", "sports", "taxi", "taxi"]
const PAINTS := [
	Color(0.82, 0.16, 0.16), Color(0.15, 0.35, 0.75), Color(0.95, 0.95, 0.95), Color(0.15, 0.15, 0.17),
	Color(0.2, 0.55, 0.32), Color(0.6, 0.3, 0.62), Color(0.95, 0.55, 0.18), Color(0.55, 0.58, 0.62),
]
const GLASS := Color(0.12, 0.17, 0.22)
const TYRE := Color(0.07, 0.07, 0.07)
const HEAD := Color(1.0, 0.95, 0.7)
const TAIL := Color(0.8, 0.1, 0.1)
const TAXI_YELLOW := Color(0.98, 0.78, 0.12)


static func size_of(kind: String) -> Vector3:
	return KINDS.get(kind, KINDS.sedan).size


static func build(mb, kind: String, paint: Color) -> void:
	match kind:
		"taxi":
			_sedan(mb, TAXI_YELLOW)
			mb.box(Vector3(0, 1.55, 0.3), Vector3(0.9, 0.3, 0.32), Color(0.98, 0.98, 0.95))
			mb.box(Vector3(0, 1.55, 0.3), Vector3(0.94, 0.12, 0.34), Color(0.1, 0.1, 0.1))
			for i in 6:
				var z := -1.25 + i * 0.5
				for side in [-0.96, 0.96]:
					mb.box(Vector3(side, 0.6, z), Vector3(0.04, 0.14, 0.25), Color(0.1, 0.1, 0.1) if i % 2 == 0 else Color.WHITE)
		"police":
			_sedan(mb, Color(0.96, 0.96, 0.96), 4.4)
			mb.box(Vector3(0, 0.45, 0), Vector3(1.94, 0.24, 4.44), Color(0.06, 0.07, 0.12))
			for side in [-0.97, 0.97]:
				mb.box(Vector3(side, 0.75, 0.0), Vector3(0.04, 0.45, 1.6), Color(0.06, 0.07, 0.12))
			mb.box(Vector3(0, 1.43, 0.9), Vector3(1.2, 0.03, 0.6), Color(0.06, 0.07, 0.12))
		"pickup":
			_wheels(mb, 2.0, 1.55)
			mb.box(Vector3(0, 0.6, 0), Vector3(2.0, 0.65, 4.9), paint)
			mb.box(Vector3(0, 1.2, -0.55), Vector3(1.85, 0.6, 1.5), GLASS)
			mb.box(Vector3(0, 1.52, -0.55), Vector3(1.8, 0.06, 1.45), paint)
			mb.box(Vector3(0, 0.95, 1.35), Vector3(1.8, 0.05, 2.0), Color(0.2, 0.2, 0.22))
			for side in [-0.95, 0.95]:
				mb.box(Vector3(side, 1.1, 1.35), Vector3(0.1, 0.35, 2.1), paint.darkened(0.15))
			mb.box(Vector3(0, 1.1, 2.4), Vector3(2.0, 0.35, 0.1), paint.darkened(0.15))
			_lights(mb, 2.0, 4.9, 0.7)
		"van":
			_wheels(mb, 2.0, 1.5)
			mb.box(Vector3(0, 1.25, 0.2), Vector3(2.0, 1.9, 4.4), paint)
			mb.box(Vector3(0, 0.75, -2.15), Vector3(2.0, 0.9, 0.7), paint)
			mb.box(Vector3(0, 1.55, -2.0), Vector3(1.85, 0.7, 0.06), GLASS)
			mb.box(Vector3(0, 2.22, 0.4), Vector3(1.6, 0.06, 3.2), Color(0.3, 0.3, 0.32))
			for z in [-0.6, 0.6, 1.8]:
				mb.box(Vector3(0, 2.3, z), Vector3(1.7, 0.08, 0.08), Color(0.3, 0.3, 0.32))
			_lights(mb, 2.0, 4.8, 0.85)
		"sports":
			_wheels(mb, 1.95, 1.3)
			mb.box(Vector3(0, 0.45, 0), Vector3(1.95, 0.5, 4.1), paint)
			mb.box(Vector3(0, 0.85, 0.35), Vector3(1.55, 0.38, 1.6), GLASS)
			mb.box(Vector3(0, 1.06, 0.35), Vector3(1.45, 0.05, 1.45), paint)
			for x in [-0.3, 0.3]:
				mb.box(Vector3(x, 0.72, -1.2), Vector3(0.22, 0.02, 1.7), Color.WHITE)
				mb.box(Vector3(x, 1.09, 0.35), Vector3(0.22, 0.02, 1.45), Color.WHITE)
			mb.box(Vector3(0, 1.0, 1.95), Vector3(1.8, 0.08, 0.35), paint.darkened(0.3))
			for side in [-0.7, 0.7]:
				mb.box(Vector3(side, 0.85, 1.95), Vector3(0.08, 0.35, 0.1), paint.darkened(0.3))
			_lights(mb, 1.95, 4.1, 0.5)
		_:
			_sedan(mb, paint)


static func _sedan(mb, paint: Color, length := 4.2) -> void:
	_wheels(mb, 1.9, length * 0.32)
	mb.box(Vector3(0, 0.55, 0), Vector3(1.9, 0.6, length), paint)
	mb.box(Vector3(0, 1.1, 0.3), Vector3(1.7, 0.55, length * 0.5), GLASS)
	mb.box(Vector3(0, 1.39, 0.3), Vector3(1.6, 0.05, length * 0.45), paint)
	mb.box(Vector3(0, 0.86, -length * 0.3), Vector3(1.6, 0.02, length * 0.25), paint.lightened(0.1))
	_lights(mb, 1.9, length, 0.62)


static func _wheels(mb, width: float, axle: float) -> void:
	for x in [-width * 0.47, width * 0.47]:
		for z in [-axle, axle]:
			mb.box(Vector3(x, 0.35, z), Vector3(0.32, 0.7, 0.8), TYRE)
			mb.box(Vector3(x * 1.04, 0.35, z), Vector3(0.05, 0.32, 0.32), Color(0.75, 0.75, 0.78))


static func _lights(mb, width: float, length: float, y: float) -> void:
	for x in [-width * 0.33, width * 0.33]:
		mb.box(Vector3(x, y, -length * 0.5 - 0.01), Vector3(0.4, 0.15, 0.04), HEAD)
		mb.box(Vector3(x, y, length * 0.5 + 0.01), Vector3(0.4, 0.15, 0.04), TAIL)
