extends Node3D
## Runs the city's traffic control and decides how much traffic there is
## and what it is made of (0.23, HANDOFF-0.23-traffic.md).
##
## Signals: one controller per signalled junction (TrafficPlan.junction),
## main road and cross street phases with US yellow and all-red timing,
## pretimed downtown, semi-actuated elsewhere (rests in main green until a
## car calls the cross street), flashing late at night, all-way flashing red
## when a pole is knocked down. The lit lenses of every signal near the
## player are one MultiMesh of camera-facing glow quads (one draw call, no
## lights).
##
## Traffic asks it, per junction and approach, what the rule is (go, signal,
## stop, yield), which light shows, where the stop line is, whose turn it is
## at an all-way stop, and whether a gap is clear; and per position how busy
## the roads are (district x hour x road, capped by graphics quality, raised
## by surges) and which kinds of vehicle drive there.

const TrafficPlan = preload("res://scripts/traffic_plan.gd")
const VehicleKit = preload("res://scripts/kits/vehicle_kit.gd")

## Lights an approach can show.
enum { GREEN, YELLOW, RED, FLASH_YELLOW, FLASH_RED }
## Signal phases: main road go, its yellow, all red, cross street go, its
## yellow, all red.
enum { MAIN_GO, MAIN_AMBER, MAIN_CLEAR, CROSS_GO, CROSS_AMBER, CROSS_CLEAR }
## Pedestrian heads.
enum { PED_DARK, PED_WALK, PED_FLASH, PED_HAND }

## Green times (s). The cycle is about 45 s, shorter than a real 90 s one
## so a player is not stuck, in the same proportions.
const MAIN_GREEN := 22.0
const CROSS_GREEN := 14.0
## Semi-actuated minimums: main green before it may end for a call, and
## the cross green it always gets once called.
const MAIN_MIN := 12.0
const CROSS_MIN := 7.0
## All-red clearance (s).
const ALL_RED := 1.5
## A car this close (m) on a cross approach calls the cross phase; one this
## close keeps it green (passage time EXTEND s), up to CROSS_GREEN.
const CALL_RANGE := 45.0
const GAP_RANGE := 30.0
const EXTEND := 3.0
## Flashing don't-walk before the green ends (s), and the walk shown at the
## start of an actuated cross phase.
const PED_CLEAR := 7.0
const CROSS_WALK := 4.0
## Late-night flash: from midnight to this hour.
const FLASH_UNTIL := 5.0
## Lit lenses within this range (m) of the player, at most MAX_LENSES.
const LENS_RANGE := 130.0
const MAX_LENSES := 1024
## Half-size (m) of a signal lens quad and of a pedestrian head's.
const LENS_SIZE := 0.3
const PED_SIZE := 0.24
const LENS_COLORS := [Color(1.0, 0.12, 0.08), Color(1.0, 0.7, 0.05), Color(0.15, 1.0, 0.55)]
const WALK_COLOR := Color(0.95, 0.95, 1.0)
const HAND_COLOR := Color(1.0, 0.45, 0.1)

## Most traffic around the player by graphics quality.
const QUALITY_CAP := {"low": 8, "medium": 11, "high": 14, "ultra": 18}
## Least traffic whatever the hour.
const MIN_BUDGET := 2

## Weekday traffic by hour, share of the day's volume (FHWA Traffic
## Monitoring Guide urban profile: AM peak 7-9, PM peak 16-18).
const HOUR_SHARE := [1.0, 0.6, 0.5, 0.5, 0.8, 2.0, 4.5, 7.0, 7.0, 5.5, 5.0, 5.3, 5.6, 5.6, 5.9, 6.7, 7.6, 7.9, 6.3, 4.6, 3.6, 3.1, 2.4, 1.6]
## Other day shapes, peak 1: nightlife, the port's day shift, the beach,
## a truck stop's round the clock freight.
const PROFILES := {
	"night": [0.8, 0.6, 0.45, 0.3, 0.2, 0.2, 0.3, 0.45, 0.55, 0.55, 0.6, 0.65, 0.7, 0.7, 0.7, 0.75, 0.8, 0.85, 0.9, 1.0, 1.0, 1.0, 0.95, 0.9],
	"port": [0.15, 0.12, 0.12, 0.15, 0.3, 0.6, 0.9, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.95, 0.8, 0.55, 0.4, 0.3, 0.25, 0.2, 0.18],
	"leisure": [0.2, 0.12, 0.1, 0.1, 0.1, 0.15, 0.25, 0.4, 0.55, 0.7, 0.85, 0.95, 1.0, 1.0, 1.0, 1.0, 0.95, 0.9, 0.85, 0.75, 0.6, 0.45, 0.35, 0.25],
	"freight": [0.6, 0.55, 0.55, 0.55, 0.6, 0.7, 0.85, 0.95, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.95, 0.9, 0.85, 0.8, 0.75, 0.7, 0.65],
}
const PROFILE_OF := {"quarter": "night", "strip": "night", "docks": "port", "industrial": "port", "market": "port",
	"beach": "leisure", "park": "leisure", "truck_stop": "freight"}
## How busy each district's roads are at their peak hour (share of the cap).
const LEVELS := {
	"downtown": 0.9, "midtown": 0.85, "financial": 0.85, "civic": 0.75, "quarter": 0.7, "strip": 0.7,
	"docks": 0.6, "market": 0.6, "waterfront": 0.55, "oldtown": 0.55, "industrial": 0.55, "wards": 0.55,
	"brownstone": 0.55, "rowhouse": 0.5, "revival": 0.5, "heights": 0.5, "beach": 0.5, "suburb": 0.45,
	"enclave": 0.4, "hills": 0.4, "park": 0.35, "prairie": 0.35, "bayou": 0.3,
	# Towns.
	"truck_stop": 0.5, "town": 0.45, "village": 0.3, "ghost": 0.1,
}
const DEFAULT_LEVEL := 0.4
## Country regions (not towns): rural roads, the base quieter still.
const REGION_LEVEL := 0.2
const MILITARY_LEVEL := 0.15
## Near a freeway or highway the roads are busy whatever the region.
const ROAD_LEVEL := {"freeway": 0.7, "highway": 0.5}

## Where traffic sets off, by road: arterials far more than side streets.
const SPAWN_WEIGHT := {"boulevard": 1.0, "bridge": 0.9, "avenue": 0.9, "river": 0.8, "street": 0.6, "link": 0.5,
	"quay": 0.4, "quarter": 0.35, "lane": 0.15}
const COUNTRY_SPAWN_WEIGHT := {"freeway": 1.0, "highway": 0.8, "avenue": 0.6, "street": 0.5, "road": 0.4,
	"lane": 0.15, "track": 0.15, "trail": 0.1}

## The vehicle mix by district: multipliers on VehicleKit.CIVILIAN's weights
## (none under 0.5 for the trucks and three-wheelers: every kind still turns
## up everywhere, just rarely).
const MIXES := {
	"freight": {"box_truck": 4.0, "tipper": 3.0, "semi": 4.0, "pickup": 2.0, "van": 2.5, "luxury": 0.3, "super": 0.1, "sports": 0.3},
	"cbd": {"taxi": 3.0, "luxury": 2.5, "ev": 2.0, "super": 1.5, "sports": 1.3, "pickup": 0.5, "tipper": 0.5, "semi": 0.5,
		"tuk_tuk": 0.5, "cargo_trike": 0.5},
	"town_centre": {"taxi": 2.0, "luxury": 1.6, "ev": 1.6, "super": 1.2, "pickup": 0.6, "tipper": 0.5, "semi": 0.5,
		"tuk_tuk": 0.5, "cargo_trike": 0.5},
	"wealthy": {"luxury": 3.0, "ev": 2.5, "suv": 2.0, "crossover": 1.5, "van": 0.6, "box_truck": 0.5, "tipper": 0.5,
		"semi": 0.5, "tuk_tuk": 0.5, "cargo_trike": 0.5},
	"working": {"compact": 2.0, "pickup": 1.6, "van": 1.8, "tuk_tuk": 3.0, "cargo_trike": 3.0, "luxury": 0.3, "super": 0.1,
		"ev": 0.4, "sports": 0.5},
	"nightlife": {"taxi": 2.0, "sports": 1.3},
	"market": {"van": 2.5, "box_truck": 2.0, "cargo_trike": 2.0, "tuk_tuk": 2.0, "pickup": 1.5, "luxury": 0.5},
	"rural": {"pickup": 3.5, "tipper": 2.5, "cargo_trike": 2.0, "semi": 1.5, "taxi": 0.2, "luxury": 0.4, "super": 0.2,
		"sports": 0.5},
	"truck_stop": {"semi": 5.0, "box_truck": 3.0, "pickup": 2.0, "taxi": 0.2},
	"suburb": {"suv": 2.0, "crossover": 2.0, "ev": 1.5, "pickup": 1.2, "tipper": 0.5, "semi": 0.5},
	"mixed": {},
}
const MIX_OF := {
	"docks": "freight", "industrial": "freight", "downtown": "cbd", "financial": "cbd", "midtown": "town_centre",
	"civic": "town_centre", "heights": "wealthy", "enclave": "wealthy", "hills": "wealthy", "wards": "working",
	"rowhouse": "working", "bayou": "working", "quarter": "nightlife", "strip": "nightlife", "market": "market",
	"prairie": "rural", "village": "rural", "town": "rural", "ghost": "rural", "truck_stop": "truck_stop",
	"suburb": "suburb",
}

var game
## Every vehicle, refreshed four times a second (traffic reads it to find
## the car ahead and gaps), and the police cars among them with sirens on.
var vehicles: Array = []
var sirens: Array = []
## Rain slows traffic and lengthens its headway.
var raining := false
## Seconds since start (signal clocks, surges).
var clock := 0.0

var _entries := {} # junction id -> controller entry (see _entry)
var _live: Array = [] # signal entries being run
var _limits := {} # Vector2i(a, b) -> speed limit
var _surges: Array = [] # [pos, radius, factor, until]
var _budget := 8
var _density := 0.5
var _pole_shapes := {} # pole key -> its CollisionShape3D in a loaded cell
var _scanned := {} # cell root instance id -> true
var _mix_cache := {} # mix + night flag -> [kinds, cumulative weights]
var _vehicle_tick := 0.0
var _near_tick := 0.0
var _pole_tick := 0.0
var _budget_tick := 0.0
var _dirty := true
var _mm: MultiMesh
var _view: MultiMeshInstance3D


func _ready() -> void:
	add_to_group("traffic")
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_mm.mesh = quad
	_mm.instance_count = MAX_LENSES
	_mm.visible_instance_count = 0
	_view = MultiMeshInstance3D.new()
	_view.name = "SignalLenses"
	_view.multimesh = _mm
	var mat := ShaderMaterial.new()
	mat.shader = _lens_shader()
	_view.material_override = mat
	_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_view.custom_aabb = AABB(Vector3(-1e5, -1e3, -1e5), Vector3(2e5, 4e3, 2e5))
	add_child(_view)


func _physics_process(delta: float) -> void:
	if game == null or game.city == null:
		return
	clock += delta
	_vehicle_tick -= delta
	if _vehicle_tick <= 0.0:
		_vehicle_tick = 0.25
		_refresh_vehicles()
	_near_tick -= delta
	if _near_tick <= 0.0:
		_near_tick = 1.0
		_refresh_near()
	_pole_tick -= delta
	if _pole_tick <= 0.0:
		_pole_tick = 0.5
		_refresh_poles()
	_budget_tick -= delta
	if _budget_tick <= 0.0:
		_budget_tick = 2.0
		_refresh_budget()
	var hour := _hour()
	for i in range(_live.size() - 1, -1, -1):
		var e: Dictionary = _live[i]
		if clock - float(e.seen) > 2.0 and not e.near:
			e.live = false
			_live.remove_at(i)
			_dirty = true
			continue
		_run_signal(e, delta, hour)
	if _dirty:
		_dirty = false
		_rebuild_lenses()


# --- Junction controllers ----------------------------------------------------

## The controller entry of junction n (made on first use): its plan
## (TrafficPlan.junction), each approach's stop line, the signal state and
## the all-way stop queue.
func _entry(n: int) -> Dictionary:
	var e = _entries.get(n)
	if e == null:
		e = _make_entry(n)
		_entries[n] = e
	e.seen = clock
	if e.kind == TrafficPlan.SIGNALS and not e.live:
		e.live = true
		_live.append(e)
		_dirty = true
	return e


func _make_entry(n: int) -> Dictionary:
	var city = game.city
	var j: Dictionary = TrafficPlan.junction(city, n)
	var legs: Array = j.legs
	var to_leg := {}
	var stops := PackedFloat32Array()
	var max_stop := 0.0
	var yellow := [3.0, 3.0]
	for i in legs.size():
		to_leg[legs[i].to] = i
		var s := TrafficPlan.stop_back(city, n, legs[i], legs) if legs.size() >= 3 else 0.0
		stops.append(s)
		max_stop = maxf(max_stop, s)
		# Yellow change interval (ITE): 1 s reaction plus v / (2 x 3.05
		# m/s²), from the approach's limit, at least 3 s.
		var v := TrafficPlan.limit(city, legs[i].to, n)
		var g: int = legs[i].group
		yellow[g] = maxf(yellow[g], 1.0 + v / 6.1)
	var e := {"n": n, "kind": j.kind, "legs": legs, "to_leg": to_leg, "stops": stops, "max_stop": max_stop,
		"pos": city.node_pos(n), "style": j.style, "pretimed": j.pretimed, "arterial": j.arterial,
		"yellow": yellow, "phase": MAIN_GO, "t": 0.0, "go_end": INF, "walk_end": INF, "call": false,
		"flash": false, "dead": false, "poles": [], "queue": [], "seen": clock, "live": false, "near": false}
	if j.kind == TrafficPlan.SIGNALS:
		for pole in TrafficPlan.poles(city, n, j):
			e.poles.append({"key": pole.key, "group": pole.group, "lens": TrafficPlan.lens_points(city, pole),
				"loaded": false, "down": false})
		if j.pretimed:
			# Neighbouring signals start at different points of the cycle.
			var cycle: float = MAIN_GREEN + CROSS_GREEN + yellow[0] + yellow[1] + ALL_RED * 2.0
			_set_phase(e, MAIN_GO)
			_skip(e, fposmod(float(hash(n) % 997), cycle))
		else:
			_set_phase(e, MAIN_GO)
			e.t = MAIN_MIN
	return e


## Runs pretimed entry e on by `secs` (its start offset).
func _skip(e: Dictionary, secs: float) -> void:
	var guard := 0
	while secs > 0.0 and guard < 12:
		guard += 1
		var left := _phase_length(e) - float(e.t)
		if secs < left:
			e.t += secs
			return
		secs -= left
		_set_phase(e, (int(e.phase) + 1) % 6)


func _phase_length(e: Dictionary) -> float:
	match int(e.phase):
		MAIN_AMBER:
			return e.yellow[0]
		CROSS_AMBER:
			return e.yellow[1]
		MAIN_CLEAR, CROSS_CLEAR:
			return ALL_RED
	return e.go_end


func _set_phase(e: Dictionary, phase: int) -> void:
	e.phase = phase
	e.t = 0.0
	match phase:
		MAIN_GO:
			e.go_end = MAIN_GREEN if e.pretimed else INF
			e.walk_end = e.go_end - PED_CLEAR
		CROSS_GO:
			e.call = false
			e.go_end = CROSS_GREEN if e.pretimed else CROSS_MIN
			e.walk_end = CROSS_GREEN - PED_CLEAR if e.pretimed else CROSS_WALK
	_dirty = true


func _run_signal(e: Dictionary, delta: float, hour: float) -> void:
	var flash: bool = e.dead or (hour < FLASH_UNTIL and not e.arterial)
	if flash != e.flash:
		e.flash = flash
		_dirty = true
		if not flash:
			# Out of flash (MUTCD 4D.31): all red, then the main road's green.
			_set_phase(e, CROSS_CLEAR)
	if flash:
		return
	var walking: bool = float(e.t) < float(e.walk_end)
	e.t += delta
	var phase: int = e.phase
	if phase == MAIN_GO and not e.pretimed and e.call and e.go_end == INF:
		# A call: the main road keeps its minimum green and the walk gets
		# its flashing clearance before the yellow.
		e.go_end = maxf(float(e.t) + PED_CLEAR, MAIN_MIN)
		e.walk_end = float(e.go_end) - PED_CLEAR
		_dirty = true
	if float(e.t) >= _phase_length(e):
		_set_phase(e, (phase + 1) % 6)
	elif walking != (float(e.t) < float(e.walk_end)):
		_dirty = true


## The light group g of entry e shows.
func _group_light(e: Dictionary, g: int) -> int:
	if e.flash:
		return FLASH_RED if e.dead or g == 1 else FLASH_YELLOW
	match int(e.phase):
		MAIN_GO:
			return GREEN if g == 0 else RED
		MAIN_AMBER:
			return YELLOW if g == 0 else RED
		CROSS_GO:
			return GREEN if g == 1 else RED
		CROSS_AMBER:
			return YELLOW if g == 1 else RED
	return RED


## What the pedestrian heads along group g's streets show: walk with
## their green, then the flashing hand (the clearance), else the hand.
func _ped_state(e: Dictionary, g: int) -> int:
	if e.flash:
		return PED_DARK
	var go := MAIN_GO if g == 0 else CROSS_GO
	if int(e.phase) != go:
		return PED_HAND
	return PED_WALK if float(e.t) < float(e.walk_end) else PED_FLASH


# --- What traffic asks -------------------------------------------------------

## What a car arriving at junction n from junction `from` must do
## (TrafficPlan GO, SIGNAL, STOP or YIELD).
func rule(n: int, from: int) -> int:
	var e := _entry(n)
	var i: int = e.to_leg.get(from, -1)
	return TrafficPlan.GO if i < 0 else int(e.legs[i].rule)


## How junction n is controlled (TrafficPlan FREE, SIGNALS, ALL_STOP ...).
func kind(n: int) -> int:
	return int(_entry(n).kind)


## The light shown to cars arriving at n from `from` (GREEN for no signal).
func light(n: int, from: int) -> int:
	var e := _entry(n)
	var i: int = e.to_leg.get(from, -1)
	if i < 0 or e.kind != TrafficPlan.SIGNALS:
		return GREEN
	return _group_light(e, int(e.legs[i].group))


## Whether signal junction n is dark (a pole down) and runs as an all-way stop.
func is_dead(n: int) -> bool:
	return bool(_entry(n).dead)


## How far from junction n's centre the stop line of the approach from
## `from` is (m).
func stop_back(n: int, from: int) -> float:
	var e := _entry(n)
	var i: int = e.to_leg.get(from, -1)
	return 0.0 if i < 0 else e.stops[i]


## The speed limit from junction a to b (m/s).
func limit(a: int, b: int) -> float:
	var key := Vector2i(a, b)
	var v = _limits.get(key)
	if v == null:
		v = TrafficPlan.limit(game.city, a, b)
		_limits[key] = v
	return v


## All-way stop, first come first served: `car` stopped at its line.
func arrive(n: int, car) -> void:
	var e := _entry(n)
	if not e.queue.has(car):
		e.queue.append(car)


## Whether `car` is first in junction n's queue and the junction is clear.
func may_go(n: int, car) -> bool:
	var e := _entry(n)
	var q: Array = e.queue
	while not q.is_empty():
		var h = q[0]
		if is_instance_valid(h) and h.driver == h.Driver.TRAFFIC and not h.wrecked and h._next_node == n:
			break
		q.pop_front()
	if q.is_empty():
		q.append(car)
	return q[0] == car and box_clear(n, car)


## `car` has gone into junction n (or given up its place).
func depart(n: int, car) -> void:
	var e = _entries.get(n)
	if e != null:
		e.queue.erase(car)


## Whether no vehicle but `me` is inside junction n (past its stop line on
## its own approach). Parked and wrecked cars don't count: traffic goes
## round those.
func box_clear(n: int, me) -> bool:
	var e := _entry(n)
	var c: Vector3 = e.pos
	var reach: float = float(e.max_stop) + 3.0
	for v in vehicles:
		if v == me or not is_instance_valid(v) or v.wrecked:
			continue
		var p: Vector3 = v.global_position
		var rel := Vector2(p.x - c.x, p.z - c.z)
		var d := rel.length()
		if d > reach:
			continue
		if v.driver == v.Driver.NONE and v.velocity.length() < 0.5:
			continue
		if d < 1.0 or d < _line_at(e, rel / d) - 0.5:
			return false
	return true


## The stop line distance on the leg of entry e nearest direction `dir`.
func _line_at(e: Dictionary, dir: Vector2) -> float:
	var best := -2.0
	var line := 0.0
	var legs: Array = e.legs
	for i in legs.size():
		var dot: float = dir.dot(legs[i].dir)
		if dot > best:
			best = dot
			line = e.stops[i]
	return maxf(line, 4.0)


## Whether a leg of entry e lets its traffic through without stopping now
## (no sign, or a green, yellow or flashing yellow light).
func _flowing(e: Dictionary, i: int) -> bool:
	var r: int = e.legs[i].rule
	if r == TrafficPlan.GO:
		return true
	if r == TrafficPlan.SIGNAL:
		var lt := _group_light(e, int(e.legs[i].group))
		return lt == GREEN or lt == YELLOW or lt == FLASH_YELLOW
	return false


## Whether `me`, at junction n from `from` and going on to `to`, has a gap:
## no vehicle coming in on a conflicting approach within `dist` m or `secs`
## s. mode "cross": every approach whose traffic flows (a stop or yield
## sign; turning right, not the street it turns into); "right": the same,
## for a right turn on red; "left": the oncoming approach (a permissive
## left turn on green).
func gap_clear(n: int, me, from: int, to: int, mode: String) -> bool:
	var e := _entry(n)
	var i_from: int = e.to_leg.get(from, -1)
	var i_to: int = e.to_leg.get(to, -1)
	var legs: Array = e.legs
	var dist := 15.0
	var secs := 4.5
	var oncoming := -1
	if mode == "left":
		dist = 12.0
		secs = 4.0
		if i_from >= 0:
			var best := -0.7
			for k in legs.size():
				var dot: float = (legs[k].dir as Vector2).dot(legs[i_from].dir)
				if k != i_from and dot < best:
					best = dot
					oncoming = k
		if oncoming < 0:
			return true
	var c: Vector3 = e.pos
	for k in legs.size():
		if k == i_from:
			continue
		if mode == "left":
			if k != oncoming:
				continue
		elif not _flowing(e, k) or (k == i_to and mode == "right"):
			continue
		var dir: Vector2 = legs[k].dir
		var half: float = float(legs[k].w) * 0.5 + 1.0
		for v in vehicles:
			if v == me or not is_instance_valid(v) or v.wrecked:
				continue
			var p: Vector3 = v.global_position
			var rel := Vector2(p.x - c.x, p.z - c.z)
			var along := rel.dot(dir)
			if along < -2.0 or along > 60.0 or absf(rel.cross(dir)) > half:
				continue
			var closing := -Vector2(v.velocity.x, v.velocity.z).dot(dir)
			if along < 4.0 and v.velocity.length() > 0.5:
				return false
			if closing < 1.0:
				continue
			if along < dist or along / closing < secs:
				return false
	return true


## Whether a police car with its siren on is near `car` and closing (or
## right on it): traffic pulls over to let it by.
func siren_near(car) -> bool:
	var p: Vector3 = car.global_position
	for s in sirens:
		if s == car or not is_instance_valid(s):
			continue
		var rel: Vector3 = p - s.global_position
		rel.y = 0.0
		var d := rel.length()
		if d < 15.0:
			return true
		if d < 40.0:
			var u := rel / d
			if s.velocity.dot(u) - car.velocity.dot(u) > 1.0:
				return true
	return false


# --- Demand ------------------------------------------------------------------

## How much traffic the roads around the player carry now (cars).
func budget() -> int:
	return _budget


## How busy the roads at `pos` are at `hour`, 0..1 of the quality cap:
## the district's level times its hour of the day.
func density_at(pos: Vector3, hour: float) -> float:
	var d: Dictionary = game.city.district_at(pos)
	var style := str(d.get("style", ""))
	var level := _level(d)
	var n: int = game.city.nearest_node(pos)
	if n >= 0 and n >= TrafficPlan.COUNTRY_BASE:
		for leg in _entry(n).legs:
			level = maxf(level, float(ROAD_LEVEL.get(leg.cls, 0.0)))
	return level * hour_factor(style, hour)


func _level(d: Dictionary) -> float:
	var style := str(d.get("style", ""))
	if d.has("poly"):
		return MILITARY_LEVEL if style == "military" else REGION_LEVEL
	return float(LEVELS.get(style, DEFAULT_LEVEL))


## The share of a district's peak traffic at `hour` (0.12..1), from its
## day profile, between whole hours.
static func hour_factor(style: String, hour: float) -> float:
	var h := fposmod(hour, 24.0)
	var h0 := int(h) % 24
	var h1 := (h0 + 1) % 24
	var f := h - floorf(h)
	var a: float
	var b: float
	var name: String = PROFILE_OF.get(style, "")
	if name == "":
		a = HOUR_SHARE[h0] / 7.9
		b = HOUR_SHARE[h1] / 7.9
	else:
		a = PROFILES[name][h0]
		b = PROFILES[name][h1]
	return lerpf(0.12, 1.0, lerpf(a, b, f))


## Raises (or with a factor under 1, lowers) traffic within `radius` of
## `pos` for `secs`: a mission's event, a game letting out, a closure.
func surge(pos: Vector3, radius: float, factor: float, secs: float) -> void:
	_surges.append([pos, radius, factor, clock + secs])
	_refresh_budget()


func _surge_at(pos: Vector3) -> float:
	var f := 1.0
	for i in range(_surges.size() - 1, -1, -1):
		var s: Array = _surges[i]
		if clock > float(s[3]):
			_surges.remove_at(i)
			continue
		if Vector2(pos.x - s[0].x, pos.z - s[0].z).length() < float(s[1]):
			f *= float(s[2])
	return f


func _refresh_budget() -> void:
	if game == null or game.player == null:
		return
	var cap: int = QUALITY_CAP.get(_quality(), 14)
	var pos: Vector3 = game.player.global_position
	_density = density_at(pos, _hour())
	_budget = clampi(roundi(cap * _density * _surge_at(pos)), MIN_BUDGET, cap)
	raining = game.atmosphere != null and float(game.atmosphere.rain) > 0.3


## How likely traffic is to set off on the street from a to b (0..1).
func spawn_weight(a: int, b: int) -> float:
	if a >= TrafficPlan.COUNTRY_BASE and b >= TrafficPlan.COUNTRY_BASE:
		var ce: int = game.city.country.edge_between(a - TrafficPlan.COUNTRY_BASE, b - TrafficPlan.COUNTRY_BASE)
		return float(COUNTRY_SPAWN_WEIGHT.get(game.city.country.edge_class(ce), 0.3)) if ce >= 0 else 0.5
	if a >= TrafficPlan.COUNTRY_BASE or b >= TrafficPlan.COUNTRY_BASE:
		return float(SPAWN_WEIGHT.link)
	var e: int = game.city.plan.edge_between(a, b)
	return float(SPAWN_WEIGHT.get(game.city.plan.edge_class(e), 0.5)) if e >= 0 else 0.5


## A traffic kind for `pos`, from the district's mix (taxis twice as common
## at night).
func pick_kind(pos: Vector3, rng: RandomNumberGenerator) -> String:
	var d: Dictionary = game.city.district_at(pos)
	var style := str(d.get("style", ""))
	var mix: String = MIX_OF.get(style, "rural" if d.has("poly") else "mixed")
	var hour := _hour()
	var night := hour >= 21.0 or hour < 5.0
	return mix_pick(mix, night, rng)


## A kind from mix `mix` (MIXES), by weight.
func mix_pick(mix: String, night: bool, rng: RandomNumberGenerator) -> String:
	var key := mix + ("/n" if night else "")
	var table = _mix_cache.get(key)
	if table == null:
		var kinds: Array = []
		var cum := PackedFloat32Array()
		var total := 0.0
		var mult: Dictionary = MIXES.get(mix, {})
		for k: String in VehicleKit.CIVILIAN:
			if not VehicleKit.KINDS.has(k):
				continue
			var w: float = float(mult.get(k, 1.0)) * (2.0 if night and k == "taxi" else 1.0)
			total += w
			kinds.append(k)
			cum.append(total)
		table = [kinds, cum]
		_mix_cache[key] = table
	var kinds: Array = table[0]
	var cum: PackedFloat32Array = table[1]
	var r := rng.randf() * cum[cum.size() - 1]
	for i in cum.size():
		if r < cum[i]:
			return kinds[i]
	return kinds[kinds.size() - 1]


func _hour() -> float:
	return float(game.atmosphere.hour) if game.atmosphere != null else 12.0


func _quality() -> String:
	return str(game.graphics.quality) if game.graphics != null else "high"


# --- Upkeep ------------------------------------------------------------------

func _refresh_vehicles() -> void:
	vehicles = get_tree().get_nodes_in_group("vehicles")
	sirens.clear()
	for v in vehicles:
		if v.driver == v.Driver.POLICE and not v.wrecked:
			sirens.append(v)
	# Detectors of the actuated signals: calls and green extensions.
	for e in _live:
		if e.pretimed or e.flash:
			continue
		if e.phase == MAIN_GO and not e.call:
			e.call = _waiting_on(e, 1, CALL_RANGE)
		elif e.phase == CROSS_GO and float(e.t) >= CROSS_MIN - EXTEND and _waiting_on(e, 1, GAP_RANGE):
			e.go_end = maxf(float(e.go_end), minf(float(e.t) + EXTEND, CROSS_GREEN))


## Whether a driven vehicle is on an approach of group g of entry e within
## `reach` m, heading in.
func _waiting_on(e: Dictionary, g: int, reach: float) -> bool:
	var c: Vector3 = e.pos
	var legs: Array = e.legs
	for v in vehicles:
		if not is_instance_valid(v) or v.wrecked or v.driver == v.Driver.NONE:
			continue
		var p: Vector3 = v.global_position
		var rel := Vector2(p.x - c.x, p.z - c.z)
		var d := rel.length()
		if d > reach or d < 1.0:
			continue
		var u := rel / d
		var fwd: Vector3 = -v.global_basis.z
		if Vector2(fwd.x, fwd.z).dot(-u) < 0.6:
			continue
		for leg in legs:
			if int(leg.group) == g and u.dot(leg.dir) > 0.85:
				return true
	return false


## Keeps the signals around the player running (and their lenses shown).
func _refresh_near() -> void:
	if game.player == null:
		return
	var p: Vector3 = game.player.global_position
	for e in _live:
		e.near = false
	var made := 0
	for n in game.city._nodes_near(Vector2(p.x, p.z), LENS_RANGE):
		if not _entries.has(n):
			# Spread the work of new junctions over a few seconds.
			made += 1
			if made > 12:
				_near_tick = 0.2
				continue
		var e := _entry(n)
		if e.kind == TrafficPlan.SIGNALS:
			e.near = true


## Finds the signal poles in newly loaded cells, and which are knocked down
## (Breakables marks their info `down`): a junction with a pole down goes
## dark and runs as an all-way stop.
func _refresh_poles() -> void:
	var city = game.city
	var cells: Array = city.loaded_cells()
	if _scanned.size() > cells.size() * 2 + 64:
		_scanned.clear()
	for c in cells:
		var root: Node3D = city.cell_node(c)
		if root == null or _scanned.has(root.get_instance_id()):
			continue
		_scanned[root.get_instance_id()] = true
		for body in root.get_children():
			if not body is StaticBody3D:
				continue
			for sh in body.get_children():
				if sh is CollisionShape3D and sh.has_meta("brk"):
					var info: Dictionary = sh.get_meta("brk")
					if info.has("signal"):
						_pole_shapes[info.signal] = sh
	for e in _live:
		var dead := false
		for pole in e.poles:
			var sh = _pole_shapes.get(pole.key)
			var loaded: bool = sh != null and is_instance_valid(sh) and sh.is_inside_tree()
			var down: bool = loaded and bool(sh.get_meta("brk").get("down", false))
			if loaded != pole.loaded or down != pole.down:
				pole.loaded = loaded
				pole.down = down
				_dirty = true
			dead = dead or down
		if dead != e.dead:
			e.dead = dead
			_dirty = true


# --- Lenses ------------------------------------------------------------------

func _rebuild_lenses() -> void:
	if game.player == null:
		return
	var p: Vector3 = game.player.global_position
	var count := 0
	var r2 := LENS_RANGE * LENS_RANGE
	for e in _live:
		var c: Vector3 = e.pos
		if Vector2(c.x - p.x, c.z - p.z).length_squared() > r2:
			continue
		var phase := float(int(e.n) % 7) * 0.13
		for pole in e.poles:
			if not pole.loaded or pole.down:
				continue
			var g: int = pole.group
			var lt := _group_light(e, g)
			var idx := 2
			var blink := 0.0
			match lt:
				RED:
					idx = 0
				YELLOW:
					idx = 1
				FLASH_YELLOW:
					idx = 1
					blink = 1.0
				FLASH_RED:
					idx = 0
					blink = 1.0
			for head in pole.lens.heads:
				if count >= MAX_LENSES:
					break
				_put(count, head[idx], LENS_COLORS[idx], 0.0, LENS_SIZE, blink, phase)
				count += 1
			var ped := _ped_state(e, g)
			if ped != PED_DARK and count < MAX_LENSES:
				var walk := ped == PED_WALK
				_put(count, pole.lens.ped, WALK_COLOR if walk else HAND_COLOR, 2.0 if walk else 1.0, PED_SIZE,
					1.0 if ped == PED_FLASH else 0.0, phase)
				count += 1
	_mm.visible_instance_count = count


func _put(i: int, at: Vector3, color: Color, shape: float, size: float, blink: float, phase: float) -> void:
	_mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, at))
	_mm.set_instance_color(i, color)
	_mm.set_instance_custom_data(i, Color(shape, size, blink, phase))


## Lit lenses: camera-facing quads pulled a little toward the camera (so
## the housing never hides them and they read from above), a solid disc
## (signal) or rounded square (walk, hand) with a soft halo that widens at
## night. INSTANCE_CUSTOM: shape (0 disc, 1 hand, 2 walk), half-size,
## blink (1 flashes at 1 Hz), blink phase.
static func _lens_shader() -> Shader:
	var s := Shader.new()
	s.code = """
shader_type spatial;
render_mode skip_vertex_transform, unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled, fog_disabled;

global uniform float night;
varying vec4 v_data;
varying vec3 v_color;

void vertex() {
	float grow = mix(1.0, 2.4, night);
	vec4 c = VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0);
	c.z += 0.35;
	c.xy += VERTEX.xy * 2.0 * INSTANCE_CUSTOM.y * grow;
	VERTEX = c.xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
	v_data = vec4(INSTANCE_CUSTOM.x, 1.0 / grow, INSTANCE_CUSTOM.z, INSTANCE_CUSTOM.w);
	v_color = COLOR.rgb;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float k = v_data.y;
	float d = v_data.x < 0.5 ? r : max(abs(p.x), abs(p.y)) * 0.85 + r * 0.15;
	float core = 1.0 - smoothstep(0.62 * k, 0.78 * k, d);
	float halo = pow(max(1.0 - r, 0.0), 2.0) * mix(0.3, 0.85, night);
	float on = 1.0;
	if (v_data.z > 0.5) {
		on = step(0.5, fract(TIME + v_data.w));
	}
	float a = clamp(core + halo, 0.0, 1.0) * on;
	if (a < 0.01) {
		discard;
	}
	ALBEDO = v_color * mix(1.3, 2.6, night) * mix(0.75, 1.0, core);
	ALPHA = a;
}
"""
	return s
