extends RefCounted
## Race courses (package R of HANDOFF-hill-content.md, phase 3). Built at run
## time from the country's road graph and the terrain, so they follow the real
## roads: nothing here is drawn by hand.
##
## hill(): the loop on the hill ways of tools/hill_design_map.py RACE_ROADS,
## south of RACE_NORTH only. The roads of those names are cut at RACE_NORTH,
## pruned to their 2-core (spurs and dead ends go) and walked as one ring. A
## lead-in runs from the start marker to the ring, where the lap line is.
## trail(): the Calder Trail's pieces joined bottom to top and reversed, so the
## run goes downhill from the rental stand.
##
## A course is a Dictionary:
##   route   PackedVector3Array  the line every STEP metres (start .. finish)
##   cum     PackedFloat32Array  metres from the start to each route point
##   gates   Array of {i, pos, dir, arc, lap_line}  the checkpoints in order
##   rival   PackedVector3Array  every RIVAL_STRIDE-th point, for the AI cars
##   rival_i PackedInt32Array    the route index of each rival point
##   vlim    PackedFloat32Array  the corner speed (m/s) at each rival point
##   length, lead_len, loop_len, laps
## `ok` is false when the data is not there.

const Terrain = preload("res://scripts/terrain.gd")

## From tools/hill_design_map.py.
const RACE_ROADS := ["East Hills Road", "Whistler Track", "Copperback Cut", "Copperback Track"]
const RACE_NORTH := -3340.0
const START := Vector2(2780.0, -2520.0)
const CALDER := "Calder Trail"
const BIKE_SPOT := Vector2(990.0, -1502.0)
## The route is sampled this often (m); an AI car steers to every third one.
const STEP := 4.0
const RIVAL_STRIDE := 3
## Checkpoints about this far apart (m).
const GATE_GAP := 150.0
## The foot of the Calder Trail is a scramble up from the road: the run starts
## above the first FOOT_RUN metres of it.
const FOOT_RUN := 60.0
## The start line's arch stands this far along the lead-in; the cars line up
## behind it, rows GRID_ROW apart, two abreast (GRID_SIDE either side).
const ARCH_ARC := 34.0
const GRID_ARCS := [26.0, 16.0]
const GRID_SIDE := 1.7
## Corner speed: v = sqrt(A_LAT / curvature), and the braking the AI plans for.
const A_LAT := 5.0
const BRAKE := 5.5
const SMOOTH_PASSES := 6


# --- The road graph ------------------------------------------------------------

## Node -> neighbours, along the roads named in RACE_ROADS, both ends south of
## RACE_NORTH.
static func _graph(country) -> Dictionary:
	var adj := {}
	for r in country.roads:
		if not (r.name in RACE_ROADS):
			continue
		var nodes: PackedInt32Array = r.nodes
		for i in nodes.size() - 1:
			var a: int = nodes[i]
			var b: int = nodes[i + 1]
			if a == b or country.pos(a).y <= RACE_NORTH or country.pos(b).y <= RACE_NORTH:
				continue
			if not adj.has(a):
				adj[a] = []
			if not adj.has(b):
				adj[b] = []
			if not adj[a].has(b):
				adj[a].append(b)
			if not adj[b].has(a):
				adj[b].append(a)
	return adj


## Takes away nodes with fewer than two neighbours until none are left: what
## remains is the rings.
static func _two_core(adj: Dictionary) -> Dictionary:
	var core := adj.duplicate(true)
	var changed := true
	while changed:
		changed = false
		for n in core.keys():
			if core[n].size() < 2:
				for m in core[n]:
					core[m].erase(n)
				core.erase(n)
				changed = true
	return core


## Nodes from the one nearest `from` to the first node of `core`, over any road
## south of RACE_NORTH. Empty if there is none.
static func _lead_in(country, from: Vector2, core: Dictionary) -> Array:
	var near: PackedInt32Array = country.nodes_near(from, 300.0)
	if near.is_empty():
		return []
	var start := -1
	var best := INF
	for n in near:
		var d: float = country.pos(n).distance_to(from)
		if d < best:
			best = d
			start = n
	var dist := {start: 0.0}
	var prev := {start: -1}
	var open: Array = [start]
	var done := {}
	var steps := 0
	while not open.is_empty() and steps < 6000:
		steps += 1
		var cur: int = open[0]
		for n in open:
			if dist[n] < dist[cur]:
				cur = n
		open.erase(cur)
		if done.has(cur):
			continue
		done[cur] = true
		if core.has(cur):
			var out: Array = []
			var n := cur
			while n != -1:
				out.push_front(n)
				n = prev[n]
			return out
		for m in country.neighbours(cur):
			if country.pos(m).y <= RACE_NORTH or done.has(m):
				continue
			var nd: float = dist[cur] + country.pos(cur).distance_to(country.pos(m))
			if not dist.has(m) or nd < dist[m]:
				dist[m] = nd
				prev[m] = cur
				open.append(m)
	return []


## The ring through `j1` as nodes, from j1 round to j1 again, leaving by the
## neighbour that bends least from `heading` (the way the lead-in arrives).
## Empty if the walk does not close.
static func _ring(country, core: Dictionary, j1: int, heading: Vector2) -> Array:
	var first := -1
	var best := -2.0
	for m in core[j1]:
		var d: Vector2 = (country.pos(m) - country.pos(j1)).normalized()
		var c := d.dot(heading)
		if c > best:
			best = c
			first = m
	var path: Array = [j1, first]
	var prev := j1
	var cur: int = first
	var guard := 0
	while cur != j1 and guard < 5000:
		guard += 1
		var h: Vector2 = (country.pos(cur) - country.pos(prev)).normalized()
		var nxt := -1
		var nb := -2.0
		for m in core[cur]:
			if m == prev:
				continue
			var c: float = (country.pos(m) - country.pos(cur)).normalized().dot(h)
			if c > nb:
				nb = c
				nxt = m
		if nxt == -1 or (nxt != j1 and path.has(nxt)):
			return []
		path.append(nxt)
		prev = cur
		cur = nxt
	return path if cur == j1 else []


# --- Sampling ------------------------------------------------------------------

static func _length(pts: Array) -> float:
	var s := 0.0
	for i in range(1, pts.size()):
		s += (pts[i] as Vector2).distance_to(pts[i - 1])
	return s


## `pts` (a polyline) every `step` metres from its first point to its last.
static func _resample(pts: Array, step: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if pts.is_empty():
		return out
	out.append(pts[0])
	var carried := 0.0
	var a: Vector2 = pts[0]
	for i in range(1, pts.size()):
		var b: Vector2 = pts[i]
		var seg := a.distance_to(b)
		if seg < 0.0001:
			continue
		var at := step - carried
		while at <= seg:
			out.append(a.lerp(b, at / seg))
			at += step
		carried = seg - (at - step)
		a = b
	var last: Vector2 = pts[pts.size() - 1]
	if out[out.size() - 1].distance_to(last) > step * 0.25:
		out.append(last)
	else:
		out[out.size() - 1] = last
	return out


## Rounds the corners: a few passes of a 1-2-1 average, ends held.
static func _smooth(pts: PackedVector2Array, passes: int) -> PackedVector2Array:
	var cur := pts.duplicate()
	for p in passes:
		var nxt := cur.duplicate()
		for i in range(1, cur.size() - 1):
			nxt[i] = cur[i - 1] * 0.25 + cur[i] * 0.5 + cur[i + 1] * 0.25
		cur = nxt
	return cur


static func _lift(p: Vector2) -> Vector3:
	return Vector3(p.x, Terrain.height(p.x, p.y), p.y)


## Corner speed at each rival point (m/s, never above `vmax`): the speed whose
## sideways pull is A_LAT at that bend, then eased back from each bend by the
## braking an AI car manages.
static func speed_profile(pts: PackedVector3Array, vmax: float) -> PackedFloat32Array:
	var n := pts.size()
	var v := PackedFloat32Array()
	v.resize(n)
	for i in n:
		var a: Vector3 = pts[maxi(i - 1, 0)]
		var b: Vector3 = pts[i]
		var c: Vector3 = pts[mini(i + 1, n - 1)]
		var d1 := Vector2(b.x - a.x, b.z - a.z)
		var d2 := Vector2(c.x - b.x, c.z - b.z)
		var l1 := d1.length()
		var l2 := d2.length()
		var k := 0.0
		if l1 > 0.01 and l2 > 0.01:
			var ang := absf(d1.angle_to(d2))
			k = ang / ((l1 + l2) * 0.5)
		v[i] = minf(vmax, sqrt(A_LAT / maxf(k, 0.0001)))
	# A bend is a few points wide: the slowest of three holds for each.
	var sm := v.duplicate()
	for i in n:
		sm[i] = minf(v[i], minf(v[maxi(i - 1, 0)], v[mini(i + 1, n - 1)]))
	v = sm
	for i in range(n - 2, -1, -1):
		var d := Vector2(pts[i + 1].x - pts[i].x, pts[i + 1].z - pts[i].z).length()
		v[i] = minf(v[i], sqrt(v[i + 1] * v[i + 1] + 2.0 * BRAKE * d))
	return v


# --- The hill loop -------------------------------------------------------------

## The hill race course for `laps` laps of the ring; {} when the road data is
## not there.
static func hill(country, laps := 2) -> Dictionary:
	if country == null or country.roads.is_empty():
		return {}
	var core := _two_core(_graph(country))
	if core.is_empty():
		return {}
	var lead_nodes := _lead_in(country, START, core)
	if lead_nodes.is_empty():
		return {}
	var j1: int = lead_nodes[lead_nodes.size() - 1]
	var heading := (country.pos(j1) - START).normalized()
	if lead_nodes.size() > 1:
		heading = (country.pos(j1) - country.pos(lead_nodes[lead_nodes.size() - 2])).normalized()
	var ring := _ring(country, core, j1, heading)
	if ring.size() < 4:
		return {}
	# The raw line: the lead-in nodes (the marker stands beside the road, so the
	# line begins on the road), then the ring `laps` times.
	var raw: Array = []
	for n in lead_nodes:
		raw.append(country.pos(n))
	var lead_len := _length(raw)
	var loop: Array = []
	for n in ring:
		loop.append(country.pos(n))
	var loop_len := _length(loop)
	for lap in laps:
		for k in range(1, loop.size()):
			raw.append(loop[k])
	var marks: Array = [lead_len]
	for lap in laps:
		marks.append(lead_len + loop_len * (lap + 1))
	return _assemble(raw, marks, laps, lead_len, loop_len, 36.0)


## Builds the course from the raw polyline; `marks` are the arc lengths of the
## lap lines (the last is the finish), `vmax` the speed cap for the profile.
static func _assemble(raw: Array, marks: Array, laps: int, lead_len: float, loop_len: float, vmax: float) -> Dictionary:
	var line := _smooth(_resample(raw, STEP), SMOOTH_PASSES)
	var route := PackedVector3Array()
	var cum := PackedFloat32Array()
	var run := 0.0
	for i in line.size():
		route.append(_lift(line[i]))
		if i > 0:
			run += line[i].distance_to(line[i - 1])
		cum.append(run)
	var gates: Array = []
	var from := 0.0
	for m in marks.size():
		var to: float = float(marks[m])
		var count := maxi(1, roundi((to - from) / GATE_GAP))
		for k in count:
			# The samples are STEP apart on the raw line, so the raw arc says
			# which sample a gate stands on.
			var arc: float = from + (to - from) * float(k + 1) / float(count)
			var idx := clampi(roundi(arc / STEP), 1, route.size() - 1)
			if k == count - 1 and m == marks.size() - 1:
				idx = route.size() - 1
			gates.append(_gate(route, cum, idx, k == count - 1))
		from = to
	var rival := PackedVector3Array()
	var rival_i := PackedInt32Array()
	var i := 0
	while i < route.size():
		rival.append(route[i])
		rival_i.append(i)
		i += RIVAL_STRIDE
	if rival_i[rival_i.size() - 1] != route.size() - 1:
		rival.append(route[route.size() - 1])
		rival_i.append(route.size() - 1)
	return {"ok": true, "route": route, "cum": cum, "gates": gates, "rival": rival, "rival_i": rival_i,
		"vlim": speed_profile(rival, vmax), "length": run, "lead_len": lead_len, "loop_len": loop_len,
		"laps": laps}


static func _gate(route: PackedVector3Array, cum: PackedFloat32Array, idx: int, lap_line: bool) -> Dictionary:
	var a: Vector3 = route[maxi(idx - 2, 0)]
	var b: Vector3 = route[mini(idx + 2, route.size() - 1)]
	var d := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
	return {"i": idx, "pos": route[idx], "dir": d, "arc": cum[idx], "lap_line": lap_line}


# --- Using a course --------------------------------------------------------------

## The route sample at or after `arc` metres.
static func index_at(course: Dictionary, arc: float) -> int:
	var cum: PackedFloat32Array = course.cum
	var lo := 0
	var hi := cum.size() - 1
	while lo < hi:
		var mid := (lo + hi) / 2
		if cum[mid] < arc:
			lo = mid + 1
		else:
			hi = mid
	return lo


## The route at `arc` metres: {pos, dir (flat, unit), i}.
static func at_arc(course: Dictionary, arc: float) -> Dictionary:
	var route: PackedVector3Array = course.route
	var i := index_at(course, arc)
	var a: Vector3 = route[maxi(i - 1, 0)]
	var b: Vector3 = route[mini(i + 1, route.size() - 1)]
	var d := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
	return {"pos": route[i], "dir": d, "i": i}


## The yaw (about Y) that points a car's nose along the flat direction `d`.
static func yaw_of(d: Vector3) -> float:
	return atan2(-d.x, -d.z)


## To the right of the flat direction `d`.
static func right_of(d: Vector3) -> Vector3:
	return Vector3(-d.z, 0.0, d.x)


## `pts` moved `off` metres to the right of their line (negative: left).
static func offset_path(pts: PackedVector3Array, off: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in pts.size():
		var a: Vector3 = pts[maxi(i - 1, 0)]
		var b: Vector3 = pts[mini(i + 1, pts.size() - 1)]
		var d := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
		out.append(pts[i] + right_of(d) * off)
	return out



# --- The Calder Trail ----------------------------------------------------------

## The downhill run: the Calder Trail's pieces ordered from the lowest and
## joined, the foot's scramble (FOOT_RUN m) left off, the top at the trail's
## point nearest BIKE_SPOT (the design map's spot for the route, by the road).
## The line starts at the top and runs down. {} if there is no trail.
static func trail(country, gate_gap := 100.0) -> Dictionary:
	if country == null:
		return {}
	var keyed: Array = []
	for t in country.trails:
		if t.name != CALDER or t.pts.size() < 2:
			continue
		var pts: Array = []
		for p in t.pts:
			pts.append(Vector2(p[0], p[1]))
		var h0 := Terrain.height(pts[0].x, pts[0].y)
		var h1 := Terrain.height(pts[pts.size() - 1].x, pts[pts.size() - 1].y)
		if h1 < h0:
			pts.reverse()
			h0 = h1
		keyed.append([h0, pts])
	if keyed.is_empty():
		return {}
	keyed.sort_custom(func(a, b): return a[0] < b[0])
	var up: Array = []
	for k in keyed:
		for p in k[1]:
			up.append(p)
	# Bottom to top, then the part between the foot and the stand.
	var line := _smooth(_resample(up, STEP), 3)
	var lo := 0
	var hi := 0
	var best := INF
	var run := 0.0
	var found_lo := false
	for i in line.size():
		if i > 0:
			run += line[i].distance_to(line[i - 1])
		if not found_lo and run >= FOOT_RUN:
			lo = i
			found_lo = true
		var d: float = line[i].distance_to(BIKE_SPOT)
		if d < best:
			best = d
			hi = i
	if hi - lo < 10:
		return {}
	var down := line.slice(lo, hi + 1)
	down.reverse()
	var route := PackedVector3Array()
	var cum := PackedFloat32Array()
	run = 0.0
	for i in down.size():
		route.append(_lift(down[i]))
		if i > 0:
			run += down[i].distance_to(down[i - 1])
		cum.append(run)
	var count := maxi(2, roundi(run / gate_gap))
	var gates: Array = []
	for k in count:
		var idx := clampi(roundi(run * float(k + 1) / float(count) / STEP), 1, route.size() - 1)
		if k == count - 1:
			idx = route.size() - 1
		gates.append(_gate(route, cum, idx, k == count - 1))
	return {"ok": true, "route": route, "cum": cum, "gates": gates, "length": run, "lead_len": 0.0, "loop_len": run,
		"laps": 1, "top": route[0]}
