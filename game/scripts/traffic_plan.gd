extends RefCounted
## Traffic control read from the road graph alone (US practice, MUTCD and
## ITE): which junctions get signals, all-way or two-way stops or yields,
## where each approach's stop line is, the speed limit of every road and
## where the signal poles and stop signs stand. Pure static functions of the
## city's plan and country data: the cell builder's worker thread calls
## them to build the poles, and Traffic calls them to run the signals, so
## the two always agree.

const StreetPlan = preload("res://scripts/street_plan.gd")

## Same as City.COUNTRY_BASE (country junction ids are offset by it).
const COUNTRY_BASE := 1_000_000

## What a car arriving on a leg must do.
enum { GO, SIGNAL, STOP, YIELD }
## Junction kinds.
enum { FREE, SIGNALS, ALL_STOP, TWO_STOP, ROUNDABOUT, COUNTRY }
const KIND_NAMES := ["free", "signal", "all_stop", "two_stop", "roundabout", "country"]

## Same as CityCells.ZEBRA_STYLES (crosswalks put the stop bar 3.6 m back;
## a test keeps the two equal).
const ZEBRA_STYLES := ["downtown", "quarter", "station", "tower", "police", "hospital", "park", "club"]
## Classes whose approaches get a painted stop bar (CityCells._street).
const BARRED := ["boulevard", "avenue", "river", "street", "quay"]
## Busy districts: collector meets collector under signals, not stop signs.
const BUSY := ["downtown", "midtown", "docks", "quarter"]
## Districts whose signals run a fixed cycle (the rest rest in main green
## until a car calls the cross phase).
const PRETIMED := ["downtown", "midtown", "quarter"]

## Speed limits, m/s (US posted limits: 25, 30, 35, 40 mph in town; 45,
## 55, 65 mph out of it).
const LIMITS := {"quarter": 11.2, "quay": 11.2, "lane": 11.2, "street": 13.4, "avenue": 15.6,
	"river": 15.6, "boulevard": 17.9, "bridge": 17.9}
const COUNTRY_LIMITS := {"freeway": 29.0, "highway": 24.6, "road": 20.1, "avenue": 15.6,
	"street": 13.4, "lane": 11.2, "track": 8.9, "trail": 6.7}
const LINK_LIMIT := 13.4
const WORKS_LIMIT := 11.2
## Country classes ranked like StreetPlan ranks (arterial 4 and up).
const COUNTRY_RANK := {"freeway": 7, "highway": 6, "road": 4, "avenue": 4, "street": 2, "lane": 1, "track": 0, "trail": 0}

## Signal pole: how far behind the curb it stands, the head height and
## the lens spacing in a head (red top, yellow, green bottom).
const POLE_BACK := 0.6
const HEAD_Y := 5.15
const LENS_STEP := 0.33
const LENS_OUT := 0.2
const PED_Y := 2.8
## The sidewalk top the poles stand on (CityCells.KERB).
const KERB := 0.15
## Stop and yield signs stand this far behind the curb.
const SIGN_BACK := 0.5


static func ring_roads() -> Array:
	var out: Array = ["founders"]
	for rb in StreetPlan.ROUNDABOUTS:
		out.append(rb[0])
	return out


## The drivable legs of junction n: [{to, edge (plan edge or -1), cls,
## rank, dir (unit, n to `to`, on the ground), w, link, ring}].
static func legs(city, n: int) -> Array:
	var out: Array = []
	var p := _p2(city, n)
	var rings := ring_roads()
	for m in city.next_nodes(n):
		var leg := {"to": m, "edge": -1, "cls": "link", "rank": 2, "w": 7.2, "link": false, "ring": false}
		if n < COUNTRY_BASE and m < COUNTRY_BASE:
			var e: int = city.plan.edge_between(n, m)
			var cls: String = city.plan.edge_class(e)
			leg.edge = e
			leg.cls = cls
			leg.rank = int(StreetPlan.CLASSES[cls].rank)
			leg.w = float(StreetPlan.CLASSES[cls].width)
			leg.ring = rings.has(city.plan.edge_road[e])
		elif n >= COUNTRY_BASE and m >= COUNTRY_BASE:
			var ce: int = city.country.edge_between(n - COUNTRY_BASE, m - COUNTRY_BASE)
			if ce >= 0:
				var g: Dictionary = city.country.classes[city.country.edge_cls[ce]]
				leg.cls = str(g.id)
				leg.rank = int(COUNTRY_RANK.get(leg.cls, 1))
				leg.w = float(g.w)
		else:
			leg.link = true
		var d: Vector2 = _p2(city, m) - p
		leg.dir = d.normalized() if d.length() > 0.01 else Vector2.RIGHT
		leg.length = d.length()
		out.append(leg)
	return out


static func _p2(city, n: int) -> Vector2:
	var v: Vector3 = city.node_pos(n)
	return Vector2(v.x, v.z)


## How junction n is controlled: {node, kind, legs (each with `rule` and
## `group`: 0 the main road, 1 the cross street), style, pretimed, main
## (leg indices), arterial (both groups arterial: no late-night flash)}.
static func junction(city, n: int) -> Dictionary:
	var ls := legs(city, n)
	var j := {"node": n, "kind": FREE, "legs": ls, "style": "", "pretimed": false, "main": [], "arterial": false}
	for leg in ls:
		leg.rule = GO
		leg.group = 0
	if ls.size() < 3:
		return j
	j.style = str(city.district_at(city.node_pos(n)).get("style", ""))
	if n < COUNTRY_BASE and ls.any(func(l): return l.ring):
		j.kind = ROUNDABOUT
		for leg in ls:
			leg.rule = GO if leg.ring else YIELD
			leg.group = 0 if leg.ring else 1
		return j
	# Main road: the opposite pair (or single leg) that ranks highest, by
	# its best leg first, then by both.
	var best_key := -1
	var main: Array = []
	for i in ls.size():
		var single: int = ls[i].rank * 10 + ls[i].rank
		if single > best_key:
			best_key = single
			main = [i]
		for k in range(i + 1, ls.size()):
			if (ls[i].dir as Vector2).dot(ls[k].dir) < -0.7:
				var key: int = maxi(ls[i].rank, ls[k].rank) * 10 + ls[i].rank + ls[k].rank
				if key > best_key:
					best_key = key
					main = [i, k]
	j.main = main
	var main_rank := 0
	var cross_rank := 0
	for i in ls.size():
		if main.has(i):
			main_rank = maxi(main_rank, ls[i].rank)
		else:
			cross_rank = maxi(cross_rank, ls[i].rank)
			ls[i].group = 1
	if n >= COUNTRY_BASE:
		j.kind = COUNTRY
		for i in ls.size():
			ls[i].rule = GO if main.has(i) else YIELD
		return j
	var kind := ALL_STOP
	if main_rank >= 4 and cross_rank >= 2:
		kind = SIGNALS
	elif main_rank >= 2 and cross_rank >= 2:
		kind = SIGNALS if j.style in BUSY else ALL_STOP
	elif main_rank >= 2:
		kind = TWO_STOP
	if kind == SIGNALS and ls.any(func(l): return l.link):
		# Where the city meets the country: signs only.
		kind = TWO_STOP if main_rank > cross_rank else ALL_STOP
	j.kind = kind
	j.pretimed = j.style in PRETIMED
	j.arterial = main_rank >= 4 and cross_rank >= 4
	for i in ls.size():
		match kind:
			SIGNALS:
				ls[i].rule = SIGNAL
			ALL_STOP:
				ls[i].rule = STOP
			TWO_STOP:
				ls[i].rule = GO if main.has(i) else STOP
	if kind == SIGNALS and poles(city, n, j).is_empty():
		# Nowhere to stand a pole (bridges, water, stubs): stop signs.
		j.kind = ALL_STOP
		for leg in ls:
			leg.rule = STOP
	return j


## Index of the leg of junction j that leads to node `to`, or -1.
static func leg_to(j: Dictionary, to: int) -> int:
	for i in j.legs.size():
		if j.legs[i].to == to:
			return i
	return -1


## How far back from junction n (along the leg toward `from`) a car stops:
## the painted stop bar of CityCells._street (the setback that clears the
## crossing streets, plus the crosswalk and the bike box), or just clear of
## the crossing road out in the country.
static func stop_back(city, n: int, leg: Dictionary, others: Array) -> float:
	var e: int = leg.edge
	if e < 0 or n >= COUNTRY_BASE:
		var widest := 0.0
		for o in others:
			if o != leg:
				widest = maxf(widest, float(o.w) * 0.5)
		return maxf(widest + 1.5, 4.0)
	var plan = city.plan
	var c: float = plan.clearance(n, e)
	var setback := c + 0.5 if c > 0.0 else 0.0
	var a: Vector3 = city.node_pos(plan.edge_a[e])
	var b: Vector3 = city.node_pos(plan.edge_b[e])
	var style: String = city.district_at((a + b) * 0.5).get("style", "quarter")
	var cls: String = leg.cls
	var zebra: bool = style in ZEBRA_STYLES and cls != "lane"
	var back := setback + (3.6 if zebra else 1.0)
	if cls in BARRED and (style == "downtown" or style == "quarter") and cls != "street":
		back += 2.9
	return maxf(back, 2.5)


## Where the street's markings stop short of junction n (CityCells._setback).
static func setback(city, n: int, e: int) -> float:
	var c: float = city.plan.clearance(n, e)
	return c + 0.5 if c > 0.0 else 0.0


## The speed limit from junction a to b, m/s (work zones 25 mph).
static func limit(city, a: int, b: int) -> float:
	if a >= COUNTRY_BASE and b >= COUNTRY_BASE:
		var ce: int = city.country.edge_between(a - COUNTRY_BASE, b - COUNTRY_BASE)
		if ce >= 0:
			return float(COUNTRY_LIMITS.get(city.country.edge_class(ce), 13.4))
		return LINK_LIMIT
	if a < 0 or b < 0 or a >= COUNTRY_BASE or b >= COUNTRY_BASE:
		return LINK_LIMIT
	var e: int = city.plan.edge_between(a, b)
	if e < 0:
		return LINK_LIMIT
	var v: float = LIMITS.get(city.plan.edge_class(e), 13.4)
	if not city.roadworks.is_empty() and city.roadworks.has(e):
		v = minf(v, WORKS_LIMIT)
	return v


## A street's frame as CityCells._street builds it: x along the street from
## edge_a, z across it (+z the right of travel from a to b).
static func street_frame(city, e: int) -> Transform3D:
	var a: Vector3 = city.node_pos(city.plan.edge_a[e])
	var b: Vector3 = city.node_pos(city.plan.edge_b[e])
	var dir := (b - a).normalized()
	return Transform3D(Basis(Vector3.UP, atan2(-dir.z, dir.x)), a)


## Whether CityCells._street builds a street long enough to carry a pole
## or sign standing `at` from junction n (the run between the setbacks).
static func _hosts(city, e: int, at: float) -> bool:
	if e < 0 or city.plan.edge_class(e) in ["bridge", "lane"]:
		return false
	var plan = city.plan
	var length: float = plan.pos(plan.edge_a[e]).distance_to(plan.pos(plan.edge_b[e]))
	var run: float = length - setback(city, plan.edge_a[e], e) - setback(city, plan.edge_b[e], e)
	return run >= 6.0 and at < length * 0.5 - 1.0


## Whether a local point of street e's frame stands on land.
static func _on_land(city, e: int, local: Vector3) -> bool:
	var w: Vector3 = street_frame(city, e) * local
	var f: int = city.plan.face_of(Vector2(w.x, w.z))
	return f >= 0 and city.plan.is_land(f)


## The signal poles of junction n (its junction() dict `j`, worked out if
## not given): one per signalled approach. US practice: a far-side mast arm
## on the street straight ahead, at its corner on the right, the heads
## hanging over its lanes and facing the approach; else (a T's stem, a
## bridge ahead) a near-side pole on the approach's own corner. Each:
## {key, edge (host street), x, z (its frame), sx (+1 when the junction is
## the street's edge_a), arm (unit, frame), face (unit, frame: where the
## lenses look), heads (distances along the arm), group, leg, cabinet}.
static func poles(city, n: int, j := {}) -> Array:
	if n >= COUNTRY_BASE:
		return []
	if j.is_empty():
		j = junction(city, n)
		if j.kind != SIGNALS:
			return []
	var out: Array = []
	var ls: Array = j.legs
	for i in ls.size():
		var leg: Dictionary = ls[i]
		if leg.link:
			continue
		var travel: Vector2 = -leg.dir
		var ahead := -1
		var best := 0.7
		for k in ls.size():
			if k != i and travel.dot(ls[k].dir) > best:
				best = travel.dot(ls[k].dir)
				ahead = k
		var pole := {}
		if ahead >= 0:
			pole = _pole(city, n, ls[ahead].edge, true)
		if pole.is_empty():
			pole = _pole(city, n, leg.edge, false)
		if pole.is_empty():
			continue
		pole.group = leg.group
		pole.leg = i
		pole.cabinet = out.is_empty()
		pole.key = "%d:%d" % [n, out.size()]
		out.append(pole)
	return out


static func _pole(city, n: int, e: int, far: bool) -> Dictionary:
	var at := setback(city, n, e) + 0.5
	if not _hosts(city, e, at):
		return {}
	var plan = city.plan
	var cls: String = plan.edge_class(e)
	var g: Dictionary = StreetPlan.CLASSES[cls]
	var length: float = plan.pos(plan.edge_a[e]).distance_to(plan.pos(plan.edge_b[e]))
	var sx := 1.0 if plan.edge_a[e] == n else -1.0
	var x := at if sx > 0.0 else length - at
	# Far side: traffic leaves n on this street (away from n, +sx), and the
	# pole stands on its right. Near side: traffic comes in toward n.
	var side := sx if far else -sx
	var z := side * (float(g.width) * 0.5 + POLE_BACK)
	if not _on_land(city, e, Vector3(x, 0, z)):
		return {}
	var heads: Array = []
	for k in int(g.lanes):
		heads.append(float(g.width) * 0.5 + POLE_BACK - (float(g.middle) + float(g.lane_w) * (k + 0.5)))
	heads.sort()
	if heads.size() < 2:
		heads.append(heads[0] + 2.2 if not heads.is_empty() else 2.4)
	return {"edge": e, "x": x, "z": z, "sx": sx, "far": far, "arm": Vector3(0, 0, -side),
		"face": Vector3(-sx if far else sx, 0, 0), "heads": heads}


## A pole's base in the world.
static func pole_world(city, pole: Dictionary) -> Vector3:
	return street_frame(city, pole.edge) * Vector3(pole.x, 0, pole.z)


## Where a pole's lenses sit in the world: one entry per head, each
## [red, yellow, green] centres; and the pedestrian head's centre.
static func lens_points(city, pole: Dictionary) -> Dictionary:
	var f := street_frame(city, pole.edge)
	var base := Vector3(pole.x, KERB, pole.z)
	var heads: Array = []
	for off in pole.heads:
		var c: Vector3 = base + pole.arm * off + Vector3(0, HEAD_Y, 0) + pole.face * LENS_OUT
		heads.append([f * (c + Vector3(0, LENS_STEP, 0)), f * c, f * (c - Vector3(0, LENS_STEP, 0))])
	var ped: Vector3 = f * (base - pole.arm * 0.25 + Vector3(0, PED_Y, 0) + pole.face * 0.2)
	return {"heads": heads, "ped": ped}


## Stop and yield signs of junction n: [{edge, x, z, face, kind ("stop",
## "all_way" or "yield")}] in their street's frame, near side right of
## each approach that must stop or give way, at its stop line.
static func signs(city, n: int, j := {}) -> Array:
	if n >= COUNTRY_BASE:
		return []
	if j.is_empty():
		j = junction(city, n)
	var out: Array = []
	if not j.kind in [ALL_STOP, TWO_STOP, ROUNDABOUT]:
		return out
	var ls: Array = j.legs
	for leg in ls:
		if not leg.rule in [STOP, YIELD] or leg.link:
			continue
		var e: int = leg.edge
		var back := stop_back(city, n, leg, ls)
		if not _hosts(city, e, back):
			continue
		var plan = city.plan
		var g: Dictionary = StreetPlan.CLASSES[leg.cls]
		var length: float = plan.pos(plan.edge_a[e]).distance_to(plan.pos(plan.edge_b[e]))
		var sx := 1.0 if plan.edge_a[e] == n else -1.0
		var x := back if sx > 0.0 else length - back
		var z := -sx * (float(g.width) * 0.5 + SIGN_BACK)
		if not _on_land(city, e, Vector3(x, 0, z)):
			continue
		var kind := "yield" if leg.rule == YIELD else ("all_way" if j.kind == ALL_STOP else "stop")
		out.append({"edge": e, "x": x, "z": z, "face": Vector3(sx, 0, 0), "kind": kind})
	return out
