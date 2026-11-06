extends Node
## Small-town and back-country events on the calendar (calendar.gd): the
## Saturday fair and the monthly rodeo night at the Hollin fairground, the
## Sunday farmers' market in Brackett, Friday and Saturday night raves in the
## two mountain clearings, a Friday-evening speed trap on Route 9 and a cult
## gathering at the stone ring on full-moon nights.
##
## What is permanent stays in the hill kit (hill_kit.gd draws the stage, the
## speakers, the booths, the ring stones in each lot). An event adds only the
## temporary rest: stalls, bunting, balloons, pulsing light shafts and floor
## tiles, floodlight pools, a fire, a few real lights, a parked patrol car,
## and the people.
##
## Streaming: nothing is built while the player is further than BUILD_R from
## an active event; what is built is freed beyond FREE_R. The dressing is
## baked once per kind on a worker thread (MeshBuilder.surface() is safe
## there) and cached; the people go through PeopleBuilder (two orders in
## flight, one body added every SPAWN_GAP seconds), so no frame builds more
## than one body. The "Events" list for the phone is today_list(); a one-line
## banner (HUD show_banner) tells the player when an event is on within
## NOTICE_R.
##
## Real lights: the Compatibility renderer draws everything a light reaches
## once more, so an event holds at most light_cap() of them (graphics.gd:
## lamps / 2, so 0 on Low, 1 on Medium, 2 on High and Ultra); the rest of the
## glow comes from additive meshes (PULSE_SHADER) that cost no light.
##
## Fiction only: the cult's robes, fire and circle carry no real symbol,
## text or doctrine.

const Calendar = preload("res://scripts/calendar.gd")
const MeshBuilder = preload("res://scripts/mesh_builder.gd")
const CharacterKit = preload("res://scripts/kits/character_kit.gd")
const PeopleBuilder = preload("res://scripts/people_builder.gd")
const Terrain = preload("res://scripts/terrain.gd")
const FireFx = preload("res://scripts/fire_fx.gd")
const Vehicle = preload("res://scripts/vehicle.gd")

## An event is built when the player is nearer than this (m), freed beyond
## FREE_R (the gap stops it flickering at the edge), and announced inside
## NOTICE_R.
const BUILD_R := 150.0
const FREE_R := 190.0
const NOTICE_R := 320.0
## Seconds between checks of the calendar and the player's distance.
const POLL := 0.25
## Bodies ordered ahead per event, and seconds between two being added.
const MAX_IN_FLIGHT := 2
const SPAWN_GAP := 0.3
## A body that has lain this long (s) is removed.
const DEAD_KEEP := 20.0

const S_UP := 0
const S_LEAVING := 1

## The schedule. days: weekdays it runs on (0 Monday); monthly: only the last
## week of each 28-day season (the rodeo); moon: only on a full-moon night
## (Calendar.full_moon_night). start and end are hours; an end before the
## start runs past midnight. place is a country.json lot id; at is a world
## x, z for events that belong to no lot. people is the crowd size.
const SPECS := [
	{"id": "hollin_fair", "name": "Saturday fair", "kind": "fair", "place": "hollin_fairground",
		"where": "Hollin fairground", "days": [5], "start": 10.0, "end": 18.0, "people": 13,
		"notice": "The Saturday fair is on at Hollin"},
	{"id": "hollin_rodeo", "name": "County rodeo night", "kind": "rodeo", "place": "hollin_fairground",
		"where": "Hollin fairground", "days": [5], "monthly": true, "start": 19.0, "end": 23.5, "people": 14,
		"notice": "Rodeo night at the Hollin fairground"},
	{"id": "brackett_market", "name": "Farmers' market", "kind": "market", "at": Vector2(2410.0, -2162.0),
		"where": "Brackett", "days": [6], "start": 8.0, "end": 13.0, "people": 12,
		"notice": "The farmers' market is on in Brackett"},
	{"id": "rave_copperback", "name": "Copperback rave", "kind": "rave", "place": "rave_copperback",
		"where": "Copperback clearing", "days": [4], "start": 22.0, "end": 4.0, "people": 15,
		"notice": "A rave tonight at Copperback"},
	{"id": "rave_east", "name": "East ridge rave", "kind": "rave", "place": "rave_east",
		"where": "East ridge clearing", "days": [5], "start": 22.0, "end": 4.0, "people": 15,
		"notice": "A rave tonight on the east ridge"},
	{"id": "speed_trap", "name": "Speed trap", "kind": "trap", "at": Vector2(1452.0, -4253.0),
		"where": "Route 9 by Hollin", "days": [4], "start": 17.0, "end": 22.0, "people": 1,
		"notice": "Patrol car on Route 9 by Hollin"},
	{"id": "cult_gathering", "name": "Moon gathering", "kind": "cult", "place": "stone_ring",
		"where": "the stone ring", "moon": true, "start": 21.0, "end": 2.0, "people": 11,
		"notice": "Lights at the stone ring tonight"},
]

const NEONS := [Color(1.0, 0.3, 0.55), Color(0.3, 0.85, 1.0), Color(1.0, 0.75, 0.2), Color(0.55, 1.0, 0.45), Color(0.8, 0.4, 1.0)]
const AWNINGS := [Color(0.82, 0.22, 0.18), Color(0.95, 0.93, 0.88), Color(0.2, 0.45, 0.75), Color(0.95, 0.75, 0.2), Color(0.25, 0.6, 0.35), Color(0.9, 0.45, 0.15)]
const FLAGS := [Color(0.85, 0.2, 0.18), Color(0.2, 0.45, 0.8), Color(0.95, 0.8, 0.2), Color(0.3, 0.65, 0.35), Color(0.95, 0.93, 0.88), Color(0.92, 0.5, 0.15)]
const ROBES := [Color(0.45, 0.1, 0.12), Color(0.18, 0.16, 0.42), Color(0.35, 0.24, 0.14), Color(0.2, 0.34, 0.2), Color(0.38, 0.14, 0.36)]
const TIMBER := Color(0.46, 0.32, 0.2)
const TIMBER_DK := Color(0.3, 0.2, 0.13)
const TIMBER_LT := Color(0.66, 0.5, 0.32)
const STRING := Color(0.1, 0.1, 0.12)
const VISITORS := ["general", "general", "general", "tourist", "elderly", "worker"]

## Additive light that pulses: vertex colour is the light, UV.x a phase
## (radians / 2 pi) so shafts and tiles run out of step, UV.y how much faster
## it flickers (a torch). Dark by day (the global `night`).
const PULSE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

global uniform float night;

uniform float rate = 2.2;
uniform float depth = 0.55;

void fragment() {
	float r = rate * mix(1.0, 3.2, UV.y);
	float p = 0.5 + 0.5 * sin(TIME * r + UV.x * 6.2831853);
	ALBEDO = COLOR.rgb * (1.0 - depth + depth * p) * night;
}
"""

var game
## The Calendar node; found through the game or the "calendar" group when
## not set.
var calendar
## Seconds the people walk off for before an ended event is taken down.
var leave_time := 8.0
var enabled := true
## The last banner shown (tests read it).
var last_notice := ""

var _live := {}
var _noticed := {}
var _centers := {}
var _acc := 0.0

## Events now holding a real light.
static var lights_used := 0
static var _dress_cache := {}
static var _dress_jobs := {}
static var _pulse_mat: ShaderMaterial


## One running event.
class Instance:
	var spec: Dictionary
	var frame: Transform3D
	var center := Vector3.ZERO
	var occurrence := 0
	var state := 0
	var timer := 0.0
	var clock := 0.0
	var rng := RandomNumberGenerator.new()
	var dress: Node3D
	var crowd: Node3D
	var orders: Array = []
	var next := 0
	var flight: Array = []
	var gap := 0.0
	var goers: Array = []
	var lights: Array = []
	var extras: Array = []
	var cue := ""


class DressJob:
	var kind := ""
	var parts: Array = []
	var task := -1
	var collected := false


## A glow mesh builder with the pulse shader's inputs in each vertex.
class Pulse:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()

	func _v(p: Vector3, c: Color, phase: float, flicker: float) -> int:
		verts.append(p)
		norms.append(Vector3.UP)
		cols.append(c)
		uvs.append(Vector2(phase, flicker))
		return verts.size() - 1

	## A shaft from a to b, wide at b, dimmer at b.
	func cone(a: Vector3, b: Vector3, r0: float, r1: float, c0: Color, c1: Color, phase: float, flicker := 0.0, sides := 6) -> void:
		var dir := (b - a).normalized()
		var side := dir.cross(Vector3.UP)
		if side.length() < 0.01:
			side = Vector3.RIGHT
		side = side.normalized()
		var up := side.cross(dir).normalized()
		var base := verts.size()
		for k in sides:
			var ang := TAU * float(k) / float(sides)
			var o := side * cos(ang) + up * sin(ang)
			_v(a + o * r0, c0, phase, flicker)
			_v(b + o * r1, c1, phase, flicker)
		for k in sides:
			var i0 := base + k * 2
			var i1 := base + ((k + 1) % sides) * 2
			idx.append_array([i0, i0 + 1, i1, i1, i0 + 1, i1 + 1])

	## A flat soft disc (bright centre, black rim).
	func disc(c: Vector3, rx: float, rz: float, col: Color, phase: float, flicker := 0.0, sides := 14) -> void:
		var base := _v(c, col, phase, flicker)
		for k in sides:
			var ang := TAU * float(k) / float(sides)
			_v(c + Vector3(cos(ang) * rx, 0.0, sin(ang) * rz), Color(0, 0, 0), phase, flicker)
		for k in sides:
			idx.append_array([base, base + 1 + k, base + 1 + ((k + 1) % sides)])

	## A flat soft ring of radius r (bright in the middle of its width).
	func ring(c: Vector3, r: float, half: float, col: Color, phase: float, flicker := 0.0, sides := 32) -> void:
		var base := verts.size()
		for k in sides:
			var ang := TAU * float(k) / float(sides)
			var d := Vector3(cos(ang), 0.0, sin(ang))
			_v(c + d * (r - half), Color(0, 0, 0), phase, flicker)
			_v(c + d * r, col, phase, flicker)
			_v(c + d * (r + half), Color(0, 0, 0), phase, flicker)
		for k in sides:
			var a := base + k * 3
			var b := base + ((k + 1) % sides) * 3
			idx.append_array([a, a + 1, b, b, a + 1, b + 1, a + 1, a + 2, b + 1, b + 1, a + 2, b + 2])

	## A flat tile.
	func tile(c: Vector3, sx: float, sz: float, col: Color, phase: float, flicker := 0.0) -> void:
		var base := verts.size()
		for p in [Vector3(-sx, 0, -sz), Vector3(sx, 0, -sz), Vector3(sx, 0, sz), Vector3(-sx, 0, sz)]:
			_v(c + p, col, phase, flicker)
		idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])

	func surface() -> Array:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = norms
		arrays[Mesh.ARRAY_COLOR] = cols
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = idx
		return [arrays, {}]


## Someone at an event. The mode says what they do: "mill" walks between
## stops and does something at each, "dance" sways on the spot with arms up
## now and then, "cheer" watches and applauds, "circle" holds a ritual cue,
## "keeper" tends a stall, "stand" holds a post, "leave" walks off. They
## react like anyone (Senses); hit by the player they run and report it.
class Goer extends "res://scripts/humanoid.gd":
	const WALK := 1.25
	const DANCE := ["hands_up", "cheer", "clap", "wave", "", "hands_up", ""]
	const CHEER := ["cheer", "clap", "hands_up", "", "cheer", "talk"]

	var mode := "stand"
	var home := Vector3.ZERO
	var face_to := Vector3.ZERO
	## [{pos, face (Vector3 or null), act}] for "mill".
	var stops: Array = []
	var act := ""
	## The ritual gesture all of a circle hold now ("" listens).
	var cue := ""
	var leave_dir := Vector3.RIGHT

	var _rng := RandomNumberGenerator.new()
	var _phase := 0.0
	var _t := 0.0
	var _next_gesture := 0.0
	var _stop := {}
	var _wait := 0.0
	var _walk_time := 0.0
	var _flee_from := Vector3.ZERO
	var _flee_until := -1.0

	func _ready() -> void:
		super()
		add_to_group("goers")
		walk_speed = WALK
		_rng.seed = get_instance_id()
		_phase = _rng.randf() * TAU
		_next_gesture = _rng.randf_range(0.0, 2.0)
		listen()

	func _think(delta: float) -> void:
		if clock < _flee_until:
			gesture = ""
			activity = ""
			var away := global_position - _flee_from
			away.y = 0.0
			if away.length_squared() < 0.01:
				away = Vector3(cos(_phase), 0.0, sin(_phase))
			walk(away.normalized(), run_speed * 0.7, delta)
			return
		if reaction != "":
			gesture = ""
			walk(Vector3.ZERO, 0.0, delta)
			face(reaction_pos - global_position, delta)
			return
		match mode:
			"mill":
				_mill(delta)
			"dance":
				_dance(delta)
			"cheer":
				_cheer(delta)
			"circle":
				_circle(delta)
			"keeper":
				_post(delta, "shopkeeper")
			"leave":
				gesture = ""
				activity = ""
				walk(leave_dir, WALK * 1.1, delta)
			_:
				_post(delta, "")

	func _on_hit(attacker) -> void:
		if attacker == null:
			return
		if attacker.is_in_group("player"):
			Wanted.report_crime(1)
		_flee_from = attacker.global_position
		_flee_until = clock + 8.0

	func _on_reaction(p: Dictionary) -> void:
		if reaction in ["flee", "avoid", "dodge"]:
			_flee_from = p.data.get("from", p.pos)
			_flee_until = clock + minf(reaction_time, 6.0)

	## Walks back to the post when pushed off it; true while doing so.
	func _go_home(delta: float, tol: float) -> bool:
		var to := home - global_position
		to.y = 0.0
		if to.length() <= tol:
			return false
		gesture = ""
		activity = ""
		walk(to.normalized(), WALK, delta)
		return true

	func _post(delta: float, g: String) -> void:
		if _go_home(delta, 0.6):
			return
		gesture = g
		activity = act
		walk(Vector3.ZERO, 0.0, delta)
		face(face_to - global_position, delta)

	func _circle(delta: float) -> void:
		if _go_home(delta, 0.6):
			return
		gesture = cue
		activity = "listen" if cue == "" else ""
		walk(Vector3.ZERO, 0.0, delta)
		face(face_to - global_position, delta)

	func _cheer(delta: float) -> void:
		if _go_home(delta, 0.8):
			return
		if clock >= _next_gesture:
			gesture = CHEER[_rng.randi() % CHEER.size()]
			_next_gesture = clock + _rng.randf_range(2.0, 5.5)
		activity = "talk" if gesture == "" else ""
		walk(Vector3.ZERO, 0.0, delta)
		face(face_to - global_position, delta)

	func _dance(delta: float) -> void:
		if _go_home(delta, 1.8):
			return
		_t += delta
		if clock >= _next_gesture:
			gesture = DANCE[_rng.randi() % DANCE.size()]
			_next_gesture = clock + _rng.randf_range(1.2, 3.2)
		var to := home - global_position
		to.y = 0.0
		var sway := Vector3(cos(_t * 1.6 + _phase), 0.0, sin(_t * 1.1 + _phase * 1.3))
		velocity = (sway * 0.5 + to * 0.7).limit_length(0.6)
		face(face_to - global_position, delta)

	func _mill(delta: float) -> void:
		if _stop.is_empty():
			if stops.is_empty():
				walk(Vector3.ZERO, 0.0, delta)
				return
			_stop = stops[_rng.randi() % stops.size()]
			_wait = -1.0
			_walk_time = 0.0
		var to: Vector3 = _stop.pos - global_position
		to.y = 0.0
		if _wait < 0.0:
			_walk_time += delta
			if to.length() > 0.45 and _walk_time < 25.0:
				gesture = ""
				activity = ""
				walk(to.normalized(), walk_speed, delta)
				return
			_wait = _rng.randf_range(3.0, 8.0)
			activity = _stop.act
		_wait -= delta
		walk(Vector3.ZERO, 0.0, delta)
		if _stop.has("face"):
			face(_stop.face - global_position, delta)
		if _wait <= 0.0:
			activity = ""
			_stop = {}


# --- Schedule (pure: no node needed) ----------------------------------------------------

## Whether `spec` runs on day number `d` (the day its window starts).
static func runs_on(spec: Dictionary, d: int) -> bool:
	if spec.has("days") and not (Calendar.weekday_of(d) in spec.days):
		return false
	if spec.get("monthly", false) and Calendar.day_of_season_of(d) < Calendar.DAYS_PER_SEASON - 7:
		return false
	if spec.get("moon", false) and not Calendar.full_moon_night(d):
		return false
	return true


## Whether `spec` is on at day `d`, hour `hour`. A window that crosses
## midnight belongs to the day it started on.
static func is_active(spec: Dictionary, d: int, hour: float) -> bool:
	var s: float = spec.start
	var e: float = spec.end
	if e > s:
		return runs_on(spec, d) and hour >= s and hour < e
	return (runs_on(spec, d) and hour >= s) or (runs_on(spec, d - 1) and hour < e)


## The day an occurrence running at (d, hour) started on.
static func occurrence_day(spec: Dictionary, d: int, hour: float) -> int:
	if float(spec.end) < float(spec.start) and hour < float(spec.end):
		return d - 1
	return d


## Every spec on at (d, hour).
static func active_specs(d: int, hour: float) -> Array:
	var out: Array = []
	for spec in SPECS:
		if is_active(spec, d, hour):
			out.append(spec)
	return out


static func spec_of(id: String) -> Dictionary:
	for spec in SPECS:
		if spec.id == id:
			return spec
	return {}


## "10am", "6pm", "11:30pm".
static func hour_text(h: float) -> String:
	var hh := int(floor(h)) % 24
	var mm := int(round((h - floor(h)) * 60.0))
	var h12 := hh % 12
	if h12 == 0:
		h12 = 12
	var ap := "am" if hh < 12 else "pm"
	return "%d%s" % [h12, ap] if mm == 0 else "%d:%02d%s" % [h12, mm, ap]


static func time_text(spec: Dictionary) -> String:
	return "%s-%s" % [hour_text(spec.start), hour_text(spec.end)]


## The cult's chant over time (s): standing and listening, arms up, kneeling,
## arms up again.
static func ritual_cue(t: float) -> String:
	var k := fposmod(t, 16.0)
	if k < 5.0:
		return ""
	if k < 8.0:
		return "hands_up"
	if k < 12.0:
		return "kneel"
	if k < 14.0:
		return "hands_up"
	return ""


# --- Public --------------------------------------------------------------------------

## Today's events for the phone: [{id, name, where, pos (Vector3), start,
## end, active, text}], in order of start. An event over for today is left
## out; a night one that began yesterday and still runs is in.
func today_list() -> Array:
	var cal = _cal()
	if cal == null or game == null or game.atmosphere == null:
		return []
	var day: int = cal.day()
	var hour: float = game.atmosphere.hour
	var out: Array = []
	for spec in SPECS:
		var carry: bool = float(spec.end) < float(spec.start) and runs_on(spec, day - 1) and hour < float(spec.end)
		var today := runs_on(spec, day)
		if not carry and not today:
			continue
		if not carry and float(spec.end) > float(spec.start) and hour >= float(spec.end):
			continue
		out.append({"id": spec.id, "name": spec.name, "where": spec.where, "pos": center(spec),
			"start": -1.0 if carry else float(spec.start), "end": float(spec.end),
			"active": is_active(spec, day, hour),
			"text": "%s at %s, %s" % [spec.name, spec.where, time_text(spec)]})
	out.sort_custom(func(a, b): return a.start < b.start)
	return out


## The world position the event gathers round (y 0); Vector3.INF when the
## place is not in the map.
func center(spec: Dictionary) -> Vector3:
	var id: String = spec.id
	if _centers.has(id):
		return _centers[id]
	var c := Vector3.INF
	if spec.has("at"):
		c = Vector3(spec.at.x, 0.0, spec.at.y)
	elif game != null and game.city != null and game.city.country != null:
		var lm: Dictionary = game.city.country.landmark(spec.place)
		if not lm.is_empty():
			c = lm.pos
	if is_finite(c.x):
		_centers[id] = c
	return c


## Whether the event `id` has anything built (people may still be arriving).
func is_built(id: String) -> bool:
	return _live.has(id)


## Whether it is built and running (not packing up).
func is_up(id: String) -> bool:
	return _live.has(id) and _live[id].state == S_UP


## Whether its set dressing is in the world.
func has_dressing(id: String) -> bool:
	return _live.has(id) and _live[id].dress != null


## The people of event `id` now in the world.
func goers(id: String) -> Array:
	if not _live.has(id):
		return []
	var out: Array = []
	for g in _live[id].goers:
		if is_instance_valid(g):
			out.append(g)
	return out


## Extra nodes of event `id` (the speed trap's patrol car).
func extras(id: String) -> Array:
	return _live[id].extras.duplicate() if _live.has(id) else []


## Real lights event `id` holds.
func light_count(id: String) -> int:
	return _live[id].lights.size() if _live.has(id) else 0


## How many real lights an event may take (graphics.gd's lamp budget / 2).
func light_cap() -> int:
	if game == null or game.graphics == null:
		return 0
	if game.settings.get("real_lights", true) == false:
		return 0
	return clampi(floori(float(game.graphics.lamps) * 0.5), 0, 2)


func _cal():
	if calendar != null:
		return calendar
	if game != null and game.get("calendar") != null:
		return game.calendar
	if is_inside_tree():
		return get_tree().get_first_node_in_group("calendar")
	return null


# --- Streaming ------------------------------------------------------------------------

func _process(delta: float) -> void:
	if game == null:
		return
	_acc += delta
	if _acc >= POLL:
		_acc = 0.0
		poll()
	for id in _live.keys():
		var inst = _live.get(id)
		if inst != null:
			_tick(inst, delta)


## Builds events that are on with the player near, takes down those that
## ended, frees those the player has left, and posts the banner. Runs every
## POLL seconds; tests call it directly.
func poll() -> void:
	var cal = _cal()
	if not enabled or game == null or cal == null or game.atmosphere == null or game.player == null:
		return
	var hour: float = game.atmosphere.hour
	cal.tick(hour)
	var day: int = cal.day()
	var pp: Vector3 = game.player.global_position
	for spec in SPECS:
		var c := center(spec)
		if not is_finite(c.x):
			continue
		var id: String = spec.id
		var d := Vector2(pp.x - c.x, pp.z - c.z).length()
		var active := is_active(spec, day, hour)
		if active and d < NOTICE_R:
			_notify(spec, occurrence_day(spec, day, hour))
		var inst = _live.get(id)
		if inst == null:
			if active and d < BUILD_R:
				_begin(spec, day, hour)
		elif d > FREE_R:
			_free(inst)
		elif not active and inst.state == S_UP:
			_leave(inst)
		elif active and inst.state == S_LEAVING:
			# The clock went back: start over.
			_free(inst)


func _notify(spec: Dictionary, occurrence: int) -> void:
	var key := "%s:%d" % [spec.id, occurrence]
	if _noticed.has(key):
		return
	_noticed[key] = true
	last_notice = spec.notice
	if game != null and game.hud != null:
		game.hud.show_banner(spec.notice)


func _begin(spec: Dictionary, day: int, hour: float) -> void:
	var inst := Instance.new()
	inst.spec = spec
	inst.frame = _frame_for(spec)
	inst.center = center(spec)
	inst.occurrence = occurrence_day(spec, day, hour)
	inst.rng.seed = hash(str(spec.id)) ^ (inst.occurrence * 7919 + 17)
	inst.crowd = Node3D.new()
	inst.crowd.name = "Crowd_" + str(spec.id)
	add_child(inst.crowd)
	_live[spec.id] = inst
	if spec.kind != "trap":
		_need_dress(spec.kind)
	inst.orders = _roster(inst)
	if spec.kind == "trap":
		_make_trap(inst)


## The lot's frame (its pad lifted to the ground at its centre) or, for an
## event at a point, a plain translation.
func _frame_for(spec: Dictionary) -> Transform3D:
	var c := center(spec)
	if spec.has("place"):
		var lm: Dictionary = game.city.country.landmark(spec.place)
		return Transform3D(Basis(Vector3.UP, float(lm.yaw)), Vector3(c.x, maxf(Terrain.height(c.x, c.z), 0.0), c.z))
	return Transform3D(Basis.IDENTITY, Vector3(c.x, 0.0, c.z))


func _leave(inst: Instance) -> void:
	inst.state = S_LEAVING
	inst.timer = leave_time
	inst.orders.clear()
	for g in inst.goers:
		if not is_instance_valid(g):
			continue
		var away: Vector3 = g.global_position - inst.center
		away.y = 0.0
		if away.length_squared() < 0.01:
			away = Vector3(inst.rng.randf_range(-1.0, 1.0), 0.0, inst.rng.randf_range(-1.0, 1.0))
		g.leave_dir = away.normalized()
		g.mode = "leave"


func _free(inst: Instance) -> void:
	_live.erase(inst.spec.id)
	lights_used = maxi(lights_used - inst.lights.size(), 0)
	inst.lights.clear()
	for n in [inst.dress, inst.crowd]:
		if is_instance_valid(n):
			n.queue_free()
	var driven = game.player.get("vehicle") if game != null and is_instance_valid(game.player) else null
	for n in inst.extras:
		# The player may have taken the trap's patrol car: it stays theirs.
		if is_instance_valid(n) and n != driven:
			n.queue_free()


func _exit_tree() -> void:
	for inst in _live.values():
		lights_used = maxi(lights_used - inst.lights.size(), 0)
	_live.clear()
	for kind in _dress_jobs.keys():
		_collect(kind, true)
	# Not held to the end of the program (the next node makes its own).
	_pulse_mat = null


func _tick(inst: Instance, delta: float) -> void:
	inst.clock += delta
	if inst.dress == null and inst.spec.kind != "trap":
		_try_dress(inst)
	if inst.state == S_LEAVING:
		inst.timer -= delta
		if inst.timer <= 0.0:
			_free(inst)
		return
	_feed(inst, delta)
	_animate(inst)


# --- Dressing -------------------------------------------------------------------------

## Starts baking `kind`'s dressing unless it is cached or already baking.
func _need_dress(kind: String) -> void:
	var key := _dress_key(kind)
	if _dress_cache.has(key) or _dress_jobs.has(key):
		return
	var job := DressJob.new()
	job.kind = key
	job.task = WorkerThreadPool.add_task(_bake.bind(job), false, "event dressing")
	_dress_jobs[key] = job


static func _dress_key(kind: String) -> String:
	return "fair" if kind == "rodeo" else kind


## Moves a finished bake into the cache (waiting for it when `wait`).
static func _collect(key: String, wait: bool) -> bool:
	if _dress_cache.has(key):
		return true
	var job: DressJob = _dress_jobs.get(key)
	if job == null:
		return false
	if not wait and not WorkerThreadPool.is_task_completed(job.task):
		return false
	WorkerThreadPool.wait_for_task_completion(job.task)
	_dress_cache[key] = job.parts
	_dress_jobs.erase(key)
	return true


func _try_dress(inst: Instance) -> void:
	var key := _dress_key(inst.spec.kind)
	if not _collect(key, false):
		return
	_make_dress(inst, _dress_cache[key])


func _mesh_node(part: Dictionary) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part.name
	mi.mesh = MeshBuilder.mesh_from(part.surf)
	match part.mat:
		"pulse":
			mi.material_override = _pulse_material()
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		"glow":
			mi.material_override = MeshBuilder.glow_material()
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_:
			mi.material_override = MeshBuilder.material()
	return mi


static func _pulse_material() -> ShaderMaterial:
	if _pulse_mat == null:
		var sh := Shader.new()
		sh.code = PULSE_SHADER
		_pulse_mat = ShaderMaterial.new()
		_pulse_mat.shader = sh
	return _pulse_mat


func _make_dress(inst: Instance, parts: Array) -> void:
	var kind: String = inst.spec.kind
	var root := Node3D.new()
	root.name = "Dress_" + str(inst.spec.id)
	add_child(root)
	inst.dress = root
	if kind == "market":
		# Stalls stand on the road shoulder, each at its own ground height.
		var meshes: Array = []
		for part in parts:
			meshes.append(MeshBuilder.mesh_from(part.surf))
		for i in MARKET_STALLS:
			var w := inst.frame * _market_stall_local(i)
			var mi := MeshInstance3D.new()
			mi.name = "Stall%d" % i
			mi.mesh = meshes[i % meshes.size()]
			mi.material_override = MeshBuilder.material()
			mi.position = Vector3(w.x, Terrain.height(w.x, w.z) - Terrain.drop(w.x, w.z), w.z)
			mi.rotation.y = PI
			root.add_child(mi)
		return
	root.transform = inst.frame
	for part in parts:
		root.add_child(_mesh_node(part))
	match kind:
		"rave":
			_add_light(inst, Vector3(-3.2, 4.6, 3.0), NEONS[0], 1.5, 17.0)
			_add_light(inst, Vector3(3.2, 4.6, 3.0), NEONS[1], 1.5, 17.0)
		"rodeo":
			_add_light(inst, Vector3(-17.0, 8.5, 11.0), Color(1.0, 0.92, 0.75), 1.6, 26.0)
		"cult":
			_add_fire(inst, Vector3(0.0, 0.62, 0.0))
			_add_light(inst, Vector3(0.0, 1.8, 0.0), Color(1.0, 0.6, 0.28), 1.5, 14.0)


## One real light if the budget has one left.
func _add_light(inst: Instance, local: Vector3, color: Color, energy: float, reach: float) -> void:
	if lights_used >= light_cap():
		return
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = reach
	l.omni_attenuation = 1.3
	l.light_specular = 0.2
	l.shadow_enabled = false
	l.position = local
	l.visible = false
	inst.dress.add_child(l)
	inst.lights.append(l)
	lights_used += 1


## A camp fire: tongues rising from a point (the particles are world space,
## so it is added to the dressing at the fire's place).
func _add_fire(inst: Instance, local: Vector3) -> void:
	var cfg: Dictionary = FireFx.cfg()
	var n := maxi(int(cfg.get("core", 8)), 4)
	var p := FireFx.emitter(n, 0.9, FireFx.flame_quad(Vector2(0.7, 1.3), 2))
	FireFx.random_frame(p)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.35
	p.spread = 12.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.3
	p.gravity = Vector3(0, 1.4, 0)
	p.randomness = 0.5
	p.scale_amount_curve = FireFx.curve([Vector2(0.0, 0.6), Vector2(0.25, 1.0), Vector2(0.6, 0.8), Vector2(1.0, 0.2)])
	p.color_ramp = FireFx.ramp([0.0, 0.5, 1.0], [Color(1.0, 0.78, 0.3, 0.9), Color(0.95, 0.4, 0.08, 0.8), Color(0.2, 0.03, 0.01, 0.0)])
	p.position = local
	FireFx.fit_cull(p)
	inst.dress.add_child(p)


func _animate(inst: Instance) -> void:
	if inst.dress == null:
		return
	var night: float = game.atmosphere.night_amount() if game.atmosphere != null else 1.0
	var kind: String = inst.spec.kind
	for i in inst.lights.size():
		var l: OmniLight3D = inst.lights[i]
		l.visible = night > 0.05
		if kind == "rave":
			var k: float = inst.clock * 0.6 + float(i) * 2.0
			var a: Color = NEONS[int(floor(k)) % NEONS.size()]
			var b: Color = NEONS[(int(floor(k)) + 1) % NEONS.size()]
			l.light_color = a.lerp(b, k - floor(k))
			l.light_energy = 1.4 + 0.5 * sin(inst.clock * 4.0 + float(i))
		elif kind == "cult":
			l.light_energy = 1.3 + 0.35 * sin(inst.clock * 13.0) + 0.2 * sin(inst.clock * 7.3)
	if kind == "cult":
		var cue := ritual_cue(inst.clock)
		if cue != inst.cue:
			inst.cue = cue
			for g in inst.goers:
				if is_instance_valid(g):
					g.cue = cue


# --- People ---------------------------------------------------------------------------

## Orders bodies ahead and adds the finished ones, one at a time.
func _feed(inst: Instance, delta: float) -> void:
	for g in inst.goers.duplicate():
		if not is_instance_valid(g):
			inst.goers.erase(g)
		elif g.dead and g.dead_time > DEAD_KEEP:
			inst.goers.erase(g)
			g.queue_free()
	while inst.flight.size() < MAX_IN_FLIGHT and inst.next < inst.orders.size():
		var o: Dictionary = inst.orders[inst.next]
		inst.next += 1
		inst.flight.append([PeopleBuilder.request(o.look), o])
	inst.gap -= delta
	if inst.gap <= 0.0 and not inst.flight.is_empty() and PeopleBuilder.ready(inst.flight[0][0]):
		var f: Array = inst.flight.pop_front()
		_spawn_goer(inst, f[1], f[0])
		inst.gap = SPAWN_GAP


func _spawn_goer(inst: Instance, o: Dictionary, ticket) -> void:
	var g := Goer.new()
	g.made = ticket.made
	g.look = ticket.made.look
	g.category = o.category
	var r: float = inst.rng.randf()
	g.personality = "calm" if r < 0.6 else ("curious" if r < 0.8 else ("timid" if r < 0.9 else "brave"))
	g.max_health = 40.0
	g.mode = o.mode
	g.home = o.pos
	g.face_to = o.face
	g.act = o.get("act", "")
	g.stops = o.get("stops", [])
	g.cue = inst.cue
	var p: Vector3 = o.pos
	g.position = Vector3(p.x, Terrain.height(p.x, p.z), p.z)
	var to: Vector3 = o.face - o.pos
	g.rotation.y = atan2(-to.x, -to.z)
	inst.crowd.add_child(g)
	inst.goers.append(g)


# --- Rosters --------------------------------------------------------------------------

func _look_for(role: String, rng: RandomNumberGenerator) -> Dictionary:
	var look: Dictionary
	match role:
		"keeper":
			look = CharacterKit.category_look(rng, "shopkeeper")
		"officer":
			look = CharacterKit.random_look(rng, "uniform")
			look["headwear"] = "police"
		"raver":
			look = CharacterKit.random_look(rng)
			if rng.randf() < 0.6:
				look["shirt"] = NEONS[rng.randi() % NEONS.size()].darkened(0.1)
			if rng.randf() < 0.3:
				look["headphones"] = NEONS[rng.randi() % NEONS.size()]
			if rng.randf() < 0.3:
				look["headband"] = NEONS[rng.randi() % NEONS.size()]
		"robed":
			# A long plain robe: the dress outfit with its hem at the ankle.
			look = CharacterKit.random_look(rng, "dress")
			look["length"] = 0.1
			look["shirt"] = ROBES[rng.randi() % ROBES.size()]
			look["sleeves"] = "long"
			look["shoe_style"] = "slides"
			look["headwear"] = ""
			for k in ["bag", "bag_color", "phone", "glasses", "sunglasses", "headphones", "lanyard", "camera", "chain", "necklace", "cane", "apron"]:
				look.erase(k)
		_:
			look = CharacterKit.category_look(rng, VISITORS[rng.randi() % VISITORS.size()])
	return look


## An order for one person: a look, where to stand (frame-local points become
## world) and what to do.
func _order(inst: Instance, role: String, local: Vector3, face_local: Vector3, mode: String, extra := {}) -> Dictionary:
	var look := _look_for(role, inst.rng)
	var category: String = look.get("category", "general")
	if role == "keeper":
		category = "shopkeeper"
	elif role == "officer":
		category = "cop"
	var o := {"role": role, "look": look, "category": category, "mode": mode,
		"pos": inst.frame * local, "face": inst.frame * face_local}
	o.merge(extra)
	return o


func _roster(inst: Instance) -> Array:
	match inst.spec.kind:
		"fair":
			return _roster_fair(inst, false)
		"rodeo":
			return _roster_fair(inst, true)
		"market":
			return _roster_market(inst)
		"rave":
			return _roster_rave(inst)
		"cult":
			return _roster_cult(inst)
		"trap":
			return [_order(inst, "officer", Vector3(-1.0, 0.0, -2.2), Vector3(-1.0, 0.0, -30.0), "stand", {"act": "arms_crossed"})]
	return []


## Lot-local spots at the fairground.
const FAIR_CENTRE := Vector3(0.0, 0.0, -8.0)
const FAIR_ARENA := Vector3(-17.0, 0.0, 11.0)
## Extra stalls on the track in: position and the way they face (yaw).
const FAIR_STALLS := [[Vector3(5.8, 0.0, -21.0), PI * 0.5], [Vector3(-5.8, 0.0, -21.0), -PI * 0.5], [Vector3(5.8, 0.0, -16.5), PI * 0.5], [Vector3(-5.8, 0.0, -16.5), -PI * 0.5]]


func _roster_fair(inst: Instance, rodeo: bool) -> Array:
	var rng: RandomNumberGenerator = inst.rng
	var out: Array = []
	var total: int = inst.spec.people
	# The places visitors walk to: round the midway, in front of each booth
	# and in front of the extra stalls.
	var stops: Array = []
	for k in 10:
		var a := TAU * (float(k) + 0.5) / 10.0
		var p := FAIR_CENTRE + Vector3(cos(a) * 13.25, 0.0, sin(a) * 5.0)
		stops.append({"pos": inst.frame * p, "act": ["talk", "", "listen", "eat"][k % 4]})
	var start := deg_to_rad(-90.0 + 22.0)
	var span := deg_to_rad(316.0)
	for i in 9:
		var th := start + span * float(i) / 8.0
		var booth := FAIR_CENTRE + Vector3(cos(th) * 17.0, 0.0, sin(th) * 8.0)
		var at := FAIR_CENTRE + Vector3(cos(th) * 14.2, 0.0, sin(th) * 6.5)
		stops.append({"pos": inst.frame * at, "face": inst.frame * booth, "act": ["browse", "pay", "browse", "eat"][i % 4]})
	var keepers := 2
	for s in keepers:
		var st: Array = FAIR_STALLS[s * 2 if not rodeo else s * 2 + 1]
		var sp: Vector3 = st[0]
		var front := Vector3(-sin(float(st[1])), 0.0, -cos(float(st[1])))
		stops.append({"pos": inst.frame * (sp + front * 1.9), "face": inst.frame * sp, "act": "browse"})
		out.append(_order(inst, "keeper", sp - front * 0.45, sp + front * 4.0, "keeper"))
	var visitors := total - keepers
	if rodeo:
		# Along the arena rail, cheering; a few on the midway.
		var watchers := 8
		for k in watchers:
			var ang := deg_to_rad(30.0 + 40.0 * float(k) + (30.0 if k >= 4 else 0.0))
			var rail := FAIR_ARENA + Vector3(cos(ang) * 15.0, 0.0, sin(ang) * 9.8)
			out.append(_order(inst, "visitor", rail, FAIR_ARENA, "cheer"))
		visitors -= watchers
	for k in visitors:
		var s: Dictionary = stops[rng.randi() % stops.size()]
		var local: Vector3 = inst.frame.affine_inverse() * s.pos
		out.append(_order(inst, "visitor", local, FAIR_CENTRE, "mill", {"stops": stops}))
	return out


const MARKET_STALLS := 6


## A stall's frame-local spot: along the south shoulder of the track.
func _market_stall_local(i: int) -> Vector3:
	return Vector3((float(i) - 2.5) * 7.0, 0.0, -2.9)


func _roster_market(inst: Instance) -> Array:
	var rng: RandomNumberGenerator = inst.rng
	var out: Array = []
	var stops: Array = []
	for i in MARKET_STALLS:
		var sp := _market_stall_local(i)
		out.append(_order(inst, "keeper", sp + Vector3(0.0, 0.0, -0.45), sp + Vector3(0.0, 0.0, 6.0), "keeper"))
		stops.append({"pos": inst.frame * (sp + Vector3(rng.randf_range(-0.5, 0.5), 0.0, 2.3)), "face": inst.frame * sp, "act": ["browse", "pay", "browse", "talk"][i % 4]})
	for k in 5:
		var x := -16.0 + 8.0 * float(k)
		stops.append({"pos": inst.frame * Vector3(x, 0.0, rng.randf_range(0.8, 1.6)), "act": ["talk", "", "listen"][k % 3]})
	var shoppers: int = int(inst.spec.people) - MARKET_STALLS
	for k in shoppers:
		var s: Dictionary = stops[rng.randi() % stops.size()]
		out.append(_order(inst, "visitor", inst.frame.affine_inverse() * s.pos, Vector3.ZERO, "mill", {"stops": stops}))
	return out


func _roster_rave(inst: Instance) -> Array:
	var out: Array = []
	var stage := Vector3(0.0, 0.0, 9.0)
	var floor_spots := [Vector3(-3.4, 0, 1.6), Vector3(-1.1, 0, 1.4), Vector3(1.2, 0, 1.6), Vector3(3.5, 0, 1.4),
		Vector3(-4.0, 0, 2.9), Vector3(-2.0, 0, 3.0), Vector3(0.0, 0, 2.7), Vector3(2.1, 0, 3.0), Vector3(4.0, 0, 2.8),
		Vector3(-2.5, 0, 4.3), Vector3(2.4, 0, 4.3)]
	for s in floor_spots:
		out.append(_order(inst, "raver", s, stage, "dance"))
	var fire := Vector3(-8.5, 0.0, -6.5)
	for a in [0.4, 3.6]:
		var p: Vector3 = fire + Vector3(cos(a) * 2.3, 0.0, sin(a) * 2.3)
		out.append(_order(inst, "raver", p, fire, "stand", {"act": "talk"}))
	out.append(_order(inst, "raver", Vector3(-8.5, 0.0, -9.9), Vector3(-8.5, 0.0, -12.0), "stand", {"act": "eat"}))
	out.append(_order(inst, "raver", Vector3(0.0, 0.0, -5.4), Vector3(0.0, 0.0, 5.0), "stand", {"act": "work"}))
	return out


func _roster_cult(inst: Instance) -> Array:
	var out: Array = []
	for k in 10:
		var a := TAU * (float(k) + 0.25) / 10.0
		out.append(_order(inst, "robed", Vector3(cos(a), 0.0, sin(a)) * 5.6, Vector3.ZERO, "circle"))
	# One inside the circle, beside the fire.
	out.append(_order(inst, "robed", Vector3(0.4, 0.0, 2.6), Vector3.ZERO, "circle"))
	return out


## The parked patrol car (no driver: it stands until something happens to it).
func _make_trap(inst: Instance) -> void:
	var a: Vector2 = inst.spec.at
	var car = Vehicle.new()
	car.is_police = true
	car.city = game.city
	car.position = Vector3(a.x, Terrain.height(a.x, a.y) - Terrain.drop(a.x, a.y), a.y)
	car.rotation.y = -PI * 0.5 + 0.12
	add_child(car)
	inst.extras.append(car)


# --- Set dressing (baked on a worker thread) -------------------------------------------

## Worker task: bakes the parts of one dressing kind.
static func _bake(job: DressJob) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + job.kind.hash()
	match job.kind:
		"fair":
			job.parts = _dress_fair(rng)
		"market":
			job.parts = _dress_market(rng)
		"rave":
			job.parts = _dress_rave(rng)
		"cult":
			job.parts = _dress_cult(rng)


static func _part(name: String, surf: Array, mat: String) -> Dictionary:
	return {"name": name, "surf": surf, "mat": mat}


## A market or fair stall at `p` facing local -Z turned by `yaw`: four
## posts, a counter with goods, a striped awning and a sign board (no
## lettering).
static func _stall(mb, p: Vector3, yaw: float, c1: Color, c2: Color, rng: RandomNumberGenerator) -> void:
	var outer: Transform3D = mb.xform
	var here := outer * Transform3D(Basis(Vector3.UP, yaw), p)
	mb.xform = here
	for sx: float in [-1.45, 1.45]:
		mb.cylinder(Vector3(sx, 0.0, -0.85), 0.05, 2.15, TIMBER_DK, 5)
		mb.cylinder(Vector3(sx, 0.0, 0.85), 0.05, 2.45, TIMBER_DK, 5)
	mb.box(Vector3(0.0, 0.45, -0.55), Vector3(2.9, 0.9, 0.7), TIMBER)
	mb.box(Vector3(0.0, 0.93, -0.55), Vector3(3.0, 0.06, 0.8), TIMBER_LT)
	mb.box(Vector3(0.0, 1.25, 0.86), Vector3(2.9, 2.0, 0.05), c2.darkened(0.3))
	for i in 6:
		mb.xform = here * Transform3D(Basis(Vector3.RIGHT, -0.175), Vector3(-1.25 + 0.5 * float(i), 2.3, 0.0))
		mb.box(Vector3.ZERO, Vector3(0.5, 0.05, 2.05), c1 if i % 2 == 0 else c2, false)
	mb.xform = here
	mb.box(Vector3(0.0, 1.95, -1.03), Vector3(1.6, 0.3, 0.04), c1.darkened(0.15))
	for i in 6:
		var gx := -1.2 + 0.48 * float(i) + rng.randf_range(-0.05, 0.05)
		var h := rng.randf_range(0.14, 0.3)
		var col: Color = AWNINGS[rng.randi() % AWNINGS.size()].lightened(0.1)
		mb.box(Vector3(gx, 0.96 + h * 0.5, -0.55 + rng.randf_range(-0.15, 0.15)), Vector3(0.26, h, 0.26), col)
	mb.xform = outer


## Bunting from a to b with a sag: a cord and a flag at every other step.
static func _bunting(mb, a: Vector3, b: Vector3, sag: float, n: int, rng: RandomNumberGenerator) -> void:
	var dv := b - a
	var side := Vector3(-dv.z, 0.0, dv.x).normalized()
	var prev := a
	for i in range(1, n + 1):
		var t := float(i) / float(n)
		var p := a.lerp(b, t) - Vector3(0.0, sag * 4.0 * t * (1.0 - t), 0.0)
		mb.limb(prev, p, 0.014, 0.014, STRING, 3, false)
		if i < n:
			var along := (p - prev).normalized() * 0.2
			var col: Color = FLAGS[rng.randi() % FLAGS.size()]
			var tip := p + Vector3(0.0, -0.45, 0.0)
			mb.tri(p - along, p + along, tip, side, col)
			mb.tri(p - along, p + along, tip, -side, col)
		prev = p


static func _balloons(mb, base: Vector3, rng: RandomNumberGenerator) -> void:
	for i in 5:
		var tip := base + Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(1.3, 2.0), rng.randf_range(-0.5, 0.5))
		mb.limb(base, tip, 0.008, 0.008, STRING, 3, false)
		mb.ball(tip + Vector3(0.0, 0.3, 0.0), Vector3(0.27, 0.32, 0.27), FLAGS[rng.randi() % FLAGS.size()], 6, 4)


static func _dress_fair(rng: RandomNumberGenerator) -> Array:
	var mb := MeshBuilder.new()
	# Bunting from the entrance posts round the midway's string-light poles.
	var h := 4.9
	for s: float in [-1.0, 1.0]:
		var arch := Vector3(s * 3.4, 5.0, -23.9)
		var low := Vector3(s * 6.0, h, -13.0)
		var out := Vector3(s * 12.0, h, -8.0)
		var top := Vector3(s * 6.0, h, -3.0)
		_bunting(mb, arch, low, 0.9, 10, rng)
		_bunting(mb, low, out, 0.8, 8, rng)
		_bunting(mb, out, top, 0.8, 8, rng)
		_balloons(mb, arch + Vector3(s * 0.4, 0.2, 0.0), rng)
	_bunting(mb, Vector3(-6.0, h, -13.0), Vector3(6.0, h, -13.0), 0.9, 10, rng)
	_bunting(mb, Vector3(-6.0, h, -3.0), Vector3(6.0, h, -3.0), 0.9, 10, rng)
	for i in FAIR_STALLS.size():
		var st: Array = FAIR_STALLS[i]
		_stall(mb, st[0], st[1], AWNINGS[(i * 2) % AWNINGS.size()], AWNINGS[(i * 2 + 1) % AWNINGS.size()], rng)
	var parts := [_part("toon", mb.surface(), "toon")]
	# Floodlights on tall poles round the rodeo arena; their pools of light
	# are drawn at night only, so they cost nothing by day.
	var lights := MeshBuilder.new()
	var pulse := Pulse.new()
	var poles := [Vector3(-32.0, 0.0, 3.0), Vector3(-2.0, 0.0, 3.0), Vector3(-32.0, 0.0, 18.5), Vector3(-2.0, 0.0, 18.5)]
	var gear := MeshBuilder.new()
	for p: Vector3 in poles:
		gear.cylinder(p, 0.14, 9.0, TIMBER_DK, 5)
		gear.box(p + Vector3(0.0, 9.2, 0.0), Vector3(0.9, 0.4, 0.5), Color(0.8, 0.8, 0.76))
		var to := FAIR_ARENA + Vector3(0.0, 0.0, 0.0)
		lights.light_pool(to + (p - to) * 0.18 + Vector3(0.0, 0.07, 0.0), Vector2(9.0, 6.0), Color(1.0, 0.88, 0.62) * 0.55, 14)
		pulse.cone(p + Vector3(0.0, 9.0, 0.0), to + (p - to) * 0.25 + Vector3(0.0, 0.1, 0.0), 0.25, 3.2, Color(1.0, 0.9, 0.7) * 0.5, Color(1.0, 0.9, 0.7) * 0.08, 0.0, 0.0, 7)
	parts.append(_part("floodlights", gear.surface(), "toon"))
	parts.append(_part("floodlight_pools", lights.surface(), "glow"))
	parts.append(_part("floodlight_shafts", pulse.surface(), "pulse"))
	return parts


static func _dress_market(rng: RandomNumberGenerator) -> Array:
	var parts: Array = []
	for v in 3:
		var mb := MeshBuilder.new()
		_stall(mb, Vector3.ZERO, 0.0, AWNINGS[(v * 2) % AWNINGS.size()], AWNINGS[(v * 2 + 3) % AWNINGS.size()], rng)
		parts.append(_part("stall%d" % v, mb.surface(), "toon"))
	return parts


static func _dress_rave(rng: RandomNumberGenerator) -> Array:
	var pulse := Pulse.new()
	# Shafts from the eight pars on the stage truss into the crowd.
	for i in 8:
		var par := Vector3(-5.6 + 1.6 * float(i), 6.5, 6.9)
		var target := Vector3((float(i) - 3.5) * 1.5, 0.1, 1.2 + float(i % 4) * 1.15)
		var c: Color = NEONS[i % NEONS.size()]
		pulse.cone(par, target, 0.07, 0.7, c * 0.6, c * 0.07, float(i) * 0.13, 0.0, 6)
	# Crossing shafts from the towers at the floor's edge.
	for s: float in [-1.0, 1.0]:
		for j in 3:
			var tower := Vector3(s * 12.0, 5.8, -1.0)
			var target := Vector3(-s * (0.5 + 1.8 * float(j)), 0.1, 2.0 + float(j) * 1.0)
			var c: Color = NEONS[(j * 2 + (0 if s < 0.0 else 3)) % NEONS.size()]
			pulse.cone(tower, target, 0.07, 0.75, c * 0.5, c * 0.06, 0.5 + float(j) * 0.17 + (0.0 if s < 0.0 else 0.4), 0.0, 6)
	# The floor tiles chase across the dance floor.
	for i in 6:
		for j in 3:
			var c: Color = NEONS[(i + j) % NEONS.size()]
			pulse.tile(Vector3(-3.75 + 1.5 * float(i), 0.1, 1.55 + 1.35 * float(j)), 0.65, 0.58, c * 0.34, float(i + j) * 0.11)
	# Soft pools under the stage and over the crowd.
	pulse.disc(Vector3(0.0, 0.11, 3.0), 7.5, 4.5, Color(0.5, 0.2, 0.7) * 0.5, 0.0)
	var glow := MeshBuilder.new()
	glow.light_pool(Vector3(-8.5, 0.08, -6.5), Vector2(5.0, 5.0), Color(0.9, 0.45, 0.15) * 0.7, 12)
	return [_part("shafts", pulse.surface(), "pulse"), _part("fire_pool", glow.surface(), "glow")]


static func _dress_cult(rng: RandomNumberGenerator) -> Array:
	var mb := MeshBuilder.new()
	var pulse := Pulse.new()
	var glow := MeshBuilder.new()
	# Four torches on poles outside the circle.
	for k in 4:
		var a := PI * 0.25 + PI * 0.5 * float(k)
		var p := Vector3(cos(a), 0.0, sin(a)) * 6.9
		mb.cylinder(p, 0.07, 2.3, TIMBER_DK, 5)
		mb.cylinder(p + Vector3(0.0, 2.2, 0.0), 0.12, 0.18, Color(0.2, 0.18, 0.16), 6)
		pulse.cone(p + Vector3(0.0, 2.35, 0.0), p + Vector3(0.0, 3.05, 0.0), 0.2, 0.02, Color(1.0, 0.55, 0.15), Color(1.0, 0.85, 0.4), float(k) * 0.23, 1.0, 5)
		glow.light_pool(p + Vector3(0.0, 0.08, 0.0), Vector2(2.6, 2.6), Color(0.9, 0.5, 0.2) * 0.45, 10)
	# The fire on the central stone and the ground round it.
	pulse.disc(Vector3(0.0, 0.64, 0.0), 1.3, 1.1, Color(1.0, 0.5, 0.15), 0.0, 1.0, 10)
	glow.light_pool(Vector3(0.0, 0.1, 0.0), Vector2(7.5, 7.5), Color(0.9, 0.42, 0.14) * 0.6, 16)
	# A faint ring of light under the circle that breathes slowly.
	pulse.ring(Vector3(0.0, 0.12, 0.0), 5.6, 0.6, Color(0.55, 0.3, 0.9) * 0.6, 0.0, 0.0, 32)
	return [_part("torches", mb.surface(), "toon"), _part("flames", pulse.surface(), "pulse"), _part("glow", glow.surface(), "glow")]
