extends Node
## The game log (Settings > Game > Log), so an issue on the phone can be
## shared as a file: a session header (build, device, renderer, settings,
## save), a snapshot line every second (frame times, draw calls, memory,
## what is round the player, where they are and what they are doing) and
## an event line whenever something happens (hitches, cars, rooms, crashes,
## knockdowns, wanted, missions, settings, saves, weather, every engine and
## script error). One line each: `t=<secs> kind=<kind> key=value ...`; see
## game/LOGGING.md.
##
## Cheap by design: per frame it only adds up frame times; the snapshot is
## built once a second, lines are kept in memory and written to
## user://logs/log0.txt every few seconds (and when Android pauses or closes
## the app). log0 is this session, log1 and log2 the ones before; a file
## that passes MAX_BYTES rolls over the same way.
##
## Other scripts log through the static calls (no node lookup):
##   const GameLog = preload("res://scripts/game_log.gd")
##   GameLog.event("enter_car", {"car": car.kind})

const DIR := "user://logs"
const FILES := 3
const MAX_BYTES := 4 * 1024 * 1024
## Lines kept in memory (the last minute or two) for Report issue.
const RING := 1500
const FLUSH_SECONDS := 3
## Android's clipboard takes a few hundred KB at most.
const COPY_CAP := 200 * 1024
const HITCH_MS := 50.0
const REPORT_SECONDS := 60.0
## Error lines a second before the rest are only counted.
const ERRORS_PER_SECOND := 30

## The log of the running game (the static calls write to it).
static var _inst = null

var game
var dir := DIR
var max_bytes := MAX_BYTES
## Settings > Game > Log. Off: nothing is kept or written.
var enabled := true
## The header is written (the first apply_settings, once the save is read).
var started := false
## Report issue blocks written this session.
var reports := 0
## The last export's path or uri, and what happened ("" before one).
var last_export := ""
var last_status := ""
## Snapshot build times (usec) of the last few ticks, for tests and tuning.
var tick_cost: Array[int] = []

var _t0 := 0
var _file: FileAccess
var _file_bytes := 0
var _pending := PackedStringArray()
var _pending_bytes := 0
var _ring: Array[String] = []
var _ring_t := PackedFloat64Array()
var _ring_at := 0
var _header := PackedStringArray()
var _catcher: Catcher
var _settings := {}
var _ticks := 0
# Frame timing for the second so far (usec).
var _last_us := 0
var _next_tick_us := 0
var _frames := 0
var _ft_sum := 0
var _ft_max := 0
var _f33 := 0
var _f50 := 0
var _hitches := 0
var _last_hitch_us := 0
var _prev_avg_us := 16667
# State seen last tick, for change events.
var _prev := {}
## The nearest road, looked up at most once a second after moving 3 m.
var _road: Array = []
var _road_from := Vector3.INF
var _next_road_us := 0
var _err_seen := {}
var _err_lines := 0
# The road look-ups (loaded on start: preloading them here would make every
# script that logs load the city's builders).
var _cells: Script
var _tiles: Script
var _plan: Script


func _init() -> void:
	_ring.resize(RING)
	_ring_t.resize(RING)
	_ring_t.fill(-1.0)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_t0 = Time.get_ticks_usec()
	_last_us = _t0
	_next_tick_us = _t0 + 1_000_000
	if game != null:
		_inst = self
	_catcher = Catcher.new()
	_catcher.t0 = _t0
	OS.add_logger(_catcher)
	if game != null:
		Wanted.level_changed.connect(_on_wanted)


func _exit_tree() -> void:
	if Wanted.level_changed.is_connected(_on_wanted):
		Wanted.level_changed.disconnect(_on_wanted)
	if _catcher != null:
		OS.remove_logger(_catcher)
		_drain_errors()
		_catcher = null
	if started and enabled:
		_write(_line("session_end", {"reason": "exit"}))
	_close()
	if _inst == self:
		_inst = null


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			event("app_paused")
			flush()
		NOTIFICATION_APPLICATION_RESUMED:
			event("app_resumed")
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			event("focus_out")
			flush()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			event("focus_in")
		NOTIFICATION_WM_CLOSE_REQUEST:
			event("close_request")
			flush()
		NOTIFICATION_OS_MEMORY_WARNING:
			event("memory_warning", {"mem_mb": _mb(Performance.get_monitor(Performance.MEMORY_STATIC))})
			flush()
		NOTIFICATION_CRASH:
			_write(_line("engine_crash", {}))
			flush()


# --- Static calls (other scripts) -----------------------------------------------

## Logs an event on the running game's log (a no-op without one).
static func event(kind: String, data := {}) -> void:
	if _inst != null and _inst.enabled:
		_inst.log_event(kind, data)


## Who a node is, for event lines: player, or its script and kind.
static func name_of(n) -> String:
	if n == null or not is_instance_valid(n):
		return "-"
	return _inst._who(n) if _inst != null else str(n.name)


## A person knocked down (by a car, a combo) or killed.
static func person(kind: String, who: Node3D, extra := {}) -> void:
	if _inst == null or not _inst.enabled:
		return
	var data := {"who": _inst._who(who)}
	var p = _inst.game.player if _inst.game != null else null
	if p != null and who != p and is_instance_valid(p):
		data["d"] = who.global_position.distance_to(p.global_position)
	data["at"] = who.global_position
	data.merge(extra)
	_inst.log_event(kind, data)


func _on_wanted(level: int) -> void:
	log_event("wanted", {"level": level})


# --- Writing --------------------------------------------------------------------

func log_event(kind: String, data := {}) -> void:
	_write(_line(kind, data))


## Called by main.apply_settings: the first call starts the log (the save
## is read by then); later ones log what changed. Log off stops it.
func settings_applied(settings: Dictionary) -> void:
	var want: bool = settings.get("log", true)
	if not started:
		_settings = settings.duplicate()
		enabled = want
		if enabled:
			_start()
		else:
			_pending.clear()
			_pending_bytes = 0
		return
	var changed := {}
	for k in settings:
		if not _settings.has(k) or _settings[k] != settings[k]:
			changed[k] = settings[k]
	for k in _settings:
		if not settings.has(k):
			changed[k] = "(removed)"
	_settings = settings.duplicate()
	if changed.is_empty():
		return
	if want and not enabled:
		enabled = true
		_open()
		_write(_line("log_on", {}))
		for h in _header:
			_write(h)
	if enabled:
		if game != null and game.graphics != null:
			changed["gfx_quality"] = game.graphics.get("quality")
		log_event("settings", changed)
	if not want and enabled:
		_write(_line("log_off", {}))
		flush()
		_close()
		enabled = false


func _start() -> void:
	started = true
	_cells = load("res://scripts/city_cells.gd")
	_tiles = load("res://scripts/country_tiles.gd")
	_plan = load("res://scripts/street_plan.gd")
	_open(true)
	var boot_ms := (Time.get_ticks_usec() - _t0) / 1000.0
	var head := PackedStringArray()
	for kind in ["session", "device", "display", "render", "memory", "settings", "camera", "save"]:
		head.append(_line(kind, _header_fields(kind)))
	head[0] += " boot_ms=%d" % int(boot_ms)
	_header = head
	# The header goes first; anything logged while the game was building
	# (errors, mostly) after it.
	var early := _pending
	_pending = PackedStringArray()
	_pending_bytes = 0
	for h in head:
		_write(h)
	for l in early:
		_queue(l)
	_drain_errors()
	_frames = 0
	_ft_sum = 0
	_ft_max = 0
	_f33 = 0
	_f50 = 0
	_last_us = Time.get_ticks_usec()
	flush()


func _write(line: String) -> void:
	if not enabled:
		return
	_ring[_ring_at] = line
	_ring_t[_ring_at] = _now()
	_ring_at = (_ring_at + 1) % RING
	_queue(line)


func _queue(line: String) -> void:
	_pending.append(line)
	_pending_bytes += line.length() + 1
	if started and _pending_bytes > 64 * 1024:
		flush()


## Writes the buffered lines to the file now.
func flush() -> void:
	if not started or not enabled or _pending.is_empty():
		return
	if _file == null:
		_open()
	if _file == null:
		return
	flush_pending_only()
	# Past the cap: on to a fresh log0 (the old one becomes log1), which
	# starts with the session header again.
	if _file_bytes > max_bytes:
		_open(true)
		if _file != null:
			var again := _header.duplicate()
			if not again.is_empty():
				again[0] += " continued=1"
			var text := "\n".join(again) + "\n"
			_file.store_string(text)
			_file.flush()
			_file_bytes += text.length()


## Path of log n (0 this session).
func path(n := 0) -> String:
	return dir.path_join("log%d.txt" % n)


## Opens log0; `rotate` first moves the older logs along (log2 is dropped).
func _open(rotate := false) -> void:
	_close()
	DirAccess.make_dir_recursive_absolute(dir)
	if rotate:
		var d := DirAccess.open(dir)
		if d != null:
			if d.file_exists("log%d.txt" % (FILES - 1)):
				d.remove("log%d.txt" % (FILES - 1))
			for i in range(FILES - 2, -1, -1):
				if d.file_exists("log%d.txt" % i):
					d.rename("log%d.txt" % i, "log%d.txt" % (i + 1))
	if rotate or not FileAccess.file_exists(path(0)):
		_file = FileAccess.open(path(0), FileAccess.WRITE)
		_file_bytes = 0
	else:
		_file = FileAccess.open(path(0), FileAccess.READ_WRITE)
		if _file != null:
			_file.seek_end()
			_file_bytes = _file.get_position()


func _close() -> void:
	if _file != null:
		flush_pending_only()
		_file.close()
		_file = null


func flush_pending_only() -> void:
	if _file != null and not _pending.is_empty() and enabled and started:
		var text := "\n".join(_pending) + "\n"
		_pending.clear()
		_pending_bytes = 0
		_file.store_string(text)
		_file_bytes += text.length()
	if _file != null:
		_file.flush()


# --- Per frame and per second ---------------------------------------------------

func _process(_delta: float) -> void:
	if not enabled:
		return
	var now := Time.get_ticks_usec()
	var dt := now - _last_us
	_last_us = now
	_frames += 1
	_ft_sum += dt
	if dt > _ft_max:
		_ft_max = dt
	if dt > 33333:
		_f33 += 1
		if dt > 50000:
			_f50 += 1
			_hitches += 1
			if started and now - _last_hitch_us > 500_000:
				_last_hitch_us = now
				_hitch(dt)
	if now >= _next_tick_us:
		_next_tick_us = now + 1_000_000
		_next_road_us = now + 500_000
		if started:
			_tick(now)
	elif now >= _next_road_us:
		# The road lookup half a second after the snapshot, so no one frame
		# carries both.
		_next_road_us = _next_tick_us + 500_000
		if started:
			_refresh_road()


func _hitch(dt: int) -> void:
	var data := {"ms": dt / 1000.0}
	data.merge(snapshot())
	log_event("hitch", data)


func _tick(_now_us: int) -> void:
	_drain_errors()
	var t0 := Time.get_ticks_usec()
	var s := snapshot()
	_write(_line("snap", s))
	_check_changes(s)
	var cost := Time.get_ticks_usec() - t0
	tick_cost.append(cost)
	if tick_cost.size() > 20:
		tick_cost.remove_at(0)
	_prev_avg_us = _ft_sum / maxi(_frames, 1)
	_frames = 0
	_ft_sum = 0
	_ft_max = 0
	_f33 = 0
	_f50 = 0
	_ticks += 1
	if _ticks % FLUSH_SECONDS == 0:
		flush()


## Everything about this moment, as key -> value (the snapshot line).
func snapshot() -> Dictionary:
	var s := {}
	var frames := maxi(_frames, 1)
	var avg := float(_ft_sum) / frames
	s["clock"] = Time.get_time_string_from_system()
	s["fps"] = 1_000_000.0 / avg if _ft_sum > 0 else 0.0
	s["fps_min"] = 1_000_000.0 / _ft_max if _ft_max > 0 else 0.0
	s["ft_avg"] = avg / 1000.0
	s["ft_max"] = _ft_max / 1000.0
	s["f33"] = _f33
	s["f50"] = _f50
	s["frames"] = _frames
	s["cpu"] = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	s["phys"] = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	s["draws"] = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	s["prims"] = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	s["objs"] = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
	s["mem"] = _mb(Performance.get_monitor(Performance.MEMORY_STATIC))
	s["vmem"] = _mb(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
	s["nodes"] = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	s["orphans"] = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	s["bodies"] = int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS))
	s["pairs"] = int(Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS))
	if game == null or not is_instance_valid(game.player):
		return s
	var tree := get_tree()
	s["paused"] = tree.paused
	var player = game.player
	var at: Vector3 = player.global_position
	var car = player.vehicle
	# Round the player.
	var cars := 0
	var near30 := 0
	var near60 := 0
	var moving := 0
	for v in tree.get_nodes_in_group("vehicles"):
		cars += 1
		var d2: float = v.global_position.distance_squared_to(at)
		if d2 < 3600.0:
			near60 += 1
			if d2 < 900.0:
				near30 += 1
		if absf(v.speed) > 0.5:
			moving += 1
	s["cars"] = cars
	s["cars30"] = near30
	s["cars60"] = near60
	s["moving"] = moving
	var people := 0
	var near_people := 0
	for h in tree.get_nodes_in_group("humanoids"):
		if h == player:
			continue
		people += 1
		if h.global_position.distance_squared_to(at) < 900.0 and h.is_visible_in_tree():
			near_people += 1
	s["people"] = people
	s["people30"] = near_people
	if game.population != null:
		s["peds"] = game.population.peds.size()
		s["traffic"] = game.population.cars.size()
	if game.police != null:
		s["cops"] = game.police.cops.size()
		s["copcars"] = game.police.cars.size()
	var gfx = game.graphics
	if gfx != null:
		var lit = gfx.get("lit_cars")
		s["lit_cars"] = lit.size() if lit is Array else -1
		s["lit_lamps"] = gfx.lit_lamps().size() if gfx.has_method("lit_lamps") else -1
	var city = game.city
	if city != null:
		var loaded = city.get("_loaded")
		s["cells"] = loaded.size() if loaded is Dictionary else -1
		s["cell_job"] = int(city.get("_task")) >= 0 if city.get("_task") != null else false
		if city.country != null:
			var tiles = city.country.get("_loaded")
			if tiles is Dictionary:
				s["tiles"] = tiles.size()
	# Weather and time.
	var atm = game.atmosphere
	if atm != null:
		s["game_time"] = atm.clock_text()
		s["hour"] = atm.hour
		s["weather"] = atm.weather
		s["rain"] = atm.rain
		s["wet"] = atm.wetness
		s["clouds"] = atm.clouds
		s["night"] = atm.night_amount()
	# Where.
	s["pos"] = at
	var body: Node3D = car if car != null else player
	var fwd: Vector3 = -body.global_basis.z
	s["head"] = fposmod(rad_to_deg(atan2(fwd.x, -fwd.z)), 360.0)
	if car != null:
		s["mode"] = ("passenger:" if player.passenger else "drive:") + str(car.kind)
		s["speed"] = absf(car.speed) * 3.6
		s["car_hp"] = car.health
	else:
		s["mode"] = "foot"
		s["speed"] = Vector2(player.velocity.x, player.velocity.z).length() * 3.6
	if city != null:
		_where(at, s)
	var inside: bool = game.interiors != null and game.interiors.state != game.interiors.State.OUTSIDE
	s["indoors"] = inside
	if inside:
		s["place"] = str(game.interiors.place.get("name", game.interiors.place.get("type", "?")))
	# Doing what.
	s["hp"] = player.health
	s["cash"] = game.cash
	s["wanted"] = Wanted.level
	if Wanted.unseen_time > 0.0:
		s["unseen"] = Wanted.unseen_time
	s["act"] = _doing(player)
	if game.missions != null:
		var m = game.missions.active
		s["mission"] = m.id if m != null else ""
		s["step"] = game.missions.objective_text.left(60)
	if game.taxi != null and game.taxi.state != 0:
		s["taxi"] = game.taxi.State.keys()[game.taxi.state].to_lower()
	s["outfit"] = _outfit(player.look)
	# The camera.
	var cam = game.camera
	if cam != null:
		s["cam"] = "persp" if cam.perspective else "classic"
		s["zoom"] = cam.zoom
		s["dzoom"] = cam.drive_zoom
		s["pitch"] = rad_to_deg(asin(clampf(cam.global_basis.z.y, -1.0, 1.0)))
		s["fov"] = cam.fov
		s["cam_d"] = cam.global_position.distance_to(at)
		s["cam_h"] = cam.global_position.y - at.y
		s["turn"] = ("steps" if cam.turn_steps else "follow") if cam.turn_view else "north"
		s["look_up"] = cam.looking_up
	s["hitches"] = _hitches
	return s


## District, region, road and its surface at `at`.
func _where(at: Vector3, s: Dictionary) -> void:
	var city = game.city
	var d: Dictionary = city.district_at(at)
	s["area"] = str(d.get("name", ""))
	s["area_kind"] = "district" if d.has("rect") else ("region" if d.has("poly") else ("town" if d.has("local") else ""))
	var local := Vector2(at.x, at.z)
	var p: Vector2 = city.map_origin + local
	var region := ""
	for r in city.get("_regions"):
		if Geometry2D.is_point_in_polygon(p, r.poly):
			region = r.name
			break
	s["region"] = region
	s["in_city"] = city.plan.bounds.has_point(local)
	# The road lookup costs more than the rest of a snapshot: it runs on its
	# own frame (_refresh_road), and here only the first time.
	if _road.is_empty():
		_refresh_road(true)
	var road := _road
	s["road"] = road[0]
	s["road_cls"] = road[1]
	s["surface"] = road[2]
	s["road_d"] = road[3]


## Looks the nearest road up again once the player has moved 3 m.
func _refresh_road(force := false) -> void:
	if game == null or game.city == null or not is_instance_valid(game.player):
		return
	var at: Vector3 = game.player.global_position
	if force or _road_from.distance_squared_to(at) > 9.0:
		_road = _road_at(at)
		_road_from = at


## [name, class, surface, distance from its centreline] of the nearest road.
func _road_at(at: Vector3) -> Array:
	var city = game.city
	var n: int = city.nearest_node(at)
	if n < 0:
		return ["", "", "", -1.0]
	var p := Vector2(at.x, at.z)
	var base: int = city.COUNTRY_BASE
	var best := -1
	var best_d := INF
	var net = city.country if n >= base else city.plan
	var node: int = n - base if n >= base else n
	if net == null:
		return ["", "", "", -1.0]
	for e in net.edges_of(node):
		var a: Vector2 = net.node_pos[net.edge_a[e]]
		var b: Vector2 = net.node_pos[net.edge_b[e]]
		var dd := p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))
		if dd < best_d:
			best_d = dd
			best = e
	if best < 0:
		return ["", "", "", -1.0]
	if n >= base:
		var c = city.country
		var r: int = c.edge_road[best]
		var name: String = c.road_name(best) if r >= 0 and r < c.roads.size() else ""
		return [name, c.edge_class(best), _tiles.road_surface(c, best), best_d]
	var plan = city.plan
	var id: String = plan.edge_road[best]
	var cls: String = plan.edge_class(best)
	var mid: Vector2 = (plan.node_pos[plan.edge_a[best]] + plan.node_pos[plan.edge_b[best]]) * 0.5
	var style: String = city.district_at(Vector3(mid.x, 0.0, mid.y)).get("style", "quarter")
	return [_plan.ROAD_NAMES.get(id, id), cls, _cells.road_surface(city.seed_value, best, cls, style), best_d]


func _doing(p) -> String:
	if p.dead:
		return "dead"
	if game.respawning:
		return "respawning"
	if p.knocked_time > 0.0:
		return "knocked"
	var out := PackedStringArray()
	if p.sitting:
		out.append("sitting")
	if p.gesture != "":
		out.append(p.gesture)
	if p.activity != "":
		out.append(p.activity)
	if p.combat_time > 0.0:
		out.append("fighting")
	if not p.controllable:
		out.append("no_control")
	if game.hud != null and game.hud.get("_dialogue") != null and game.hud._dialogue.visible:
		out.append("dialogue")
	return ",".join(out) if not out.is_empty() else "-"


static func _outfit(look: Dictionary) -> String:
	var out := PackedStringArray()
	for k in ["outfit", "jacket", "shirt", "bottoms", "pants", "shoes", "hair"]:
		if look.has(k):
			var v = look[k]
			out.append(v.to_html(false) if v is Color else str(v))
	return ",".join(out)


func _who(n: Node) -> String:
	if game != null and n == game.player:
		return "player"
	var sc = n.get_script()
	var out: String = sc.resource_path.get_file().get_basename() if sc != null else n.get_class()
	var c = n.get("category")
	if c != null and str(c) != "general":
		out += "/" + str(c)
	return out


## Events for what changed since last second: the car, the room, the
## district and road, the weather, night.
func _check_changes(s: Dictionary) -> void:
	if not s.has("pos"):
		return
	var now := {"weather": s.get("weather", ""), "night": float(s.get("night", 0.0)) > 0.5,
		"area": s.get("area", ""), "region": s.get("region", "")}
	for k in now:
		if _prev.has(k) and _prev[k] != now[k]:
			match k:
				"night": log_event("night" if now[k] else "day", {"hour": s.get("hour", 0.0)})
				"area", "region": log_event(k, {"from": _prev[k], "to": now[k], "pos": s.pos})
				_: log_event(k, {"from": _prev[k], "to": now[k]})
	_prev = now


# --- Errors -------------------------------------------------------------------

func _drain_errors() -> void:
	if _catcher == null:
		return
	var got: Array = _catcher.take()
	if got.is_empty():
		if not _err_seen.is_empty():
			_flush_repeats()
		return
	for e in got:
		if not enabled:
			break
		var key := "%s:%d:%s" % [e[2], e[3], e[5]]
		if _err_seen.has(key):
			_err_seen[key] += 1
			continue
		_err_seen[key] = 1
		if _err_lines >= ERRORS_PER_SECOND:
			continue
		_err_lines += 1
		var data := {"type": e[1], "at": "%s:%d" % [e[2], e[3]], "fn": e[4], "msg": e[5]}
		if e[6] != "":
			data["why"] = e[6]
		if e[7] != "":
			data["stack"] = e[7]
		_write("t=%.2f kind=%s" % [e[0], "warning" if e[1] == "warning" else "error"] + _kv(data))
	_flush_repeats()


func _flush_repeats() -> void:
	for key in _err_seen:
		if _err_seen[key] > 1:
			log_event("error_repeats", {"key": key, "n": _err_seen[key] - 1})
	_err_seen.clear()
	_err_lines = 0


## Collects engine and script errors and warnings from any thread; the log
## takes them on the main thread once a second.
class Catcher extends Logger:
	var t0 := 0
	var _lock := Mutex.new()
	var _got: Array = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		var type: String = ["error", "warning", "script", "shader"][clampi(error_type, 0, 3)]
		var stack := ""
		for bt in script_backtraces:
			if bt == null or bt.is_empty():
				continue
			var parts := PackedStringArray()
			for i in mini(bt.get_frame_count(), 4):
				parts.append("%s:%d %s" % [bt.get_frame_file(i).get_file(), bt.get_frame_line(i), bt.get_frame_function(i)])
			stack = " < ".join(parts)
			break
		var t := (Time.get_ticks_usec() - t0) / 1_000_000.0
		_lock.lock()
		if _got.size() < 500:
			_got.append([t, type, file, line, function, code, rationale, stack])
		_lock.unlock()

	func _log_message(message: String, error: bool) -> void:
		if not error:
			return
		var t := (Time.get_ticks_usec() - t0) / 1_000_000.0
		_lock.lock()
		if _got.size() < 500:
			_got.append([t, "stderr", "", 0, "", message.strip_edges(), "", ""])
		_lock.unlock()

	func take() -> Array:
		_lock.lock()
		var out := _got
		_got = []
		_lock.unlock()
		return out


# --- Report, export, copy -------------------------------------------------------

## Marks an issue: a REPORT block with a full snapshot and the last minute
## of the log, written to disk at once. Returns its number (0 if off).
func report(note := "") -> int:
	if not enabled or not started:
		return 0
	_drain_errors()
	reports += 1
	var now := _now()
	var since := now - REPORT_SECONDS
	var lines := PackedStringArray()
	for i in RING:
		var k := (_ring_at + i) % RING
		if _ring_t[k] >= since and _ring[k] != "":
			lines.append(_ring[k])
	var begin := {"n": reports, "date": Time.get_datetime_string_from_system(false, true)}
	if note != "":
		begin["note"] = note
	_write(_line("REPORT", begin))
	_refresh_road(true)
	var snap := snapshot()
	_write(_line("report_snap", snap))
	for l in lines:
		_queue("> " + l)
	_write(_line("REPORT_END", {"n": reports, "lines": lines.size()}))
	flush()
	return reports


## Everything on disk (oldest first) as one text.
func all_text() -> String:
	flush()
	var parts := PackedStringArray()
	for i in range(FILES - 1, -1, -1):
		if FileAccess.file_exists(path(i)):
			parts.append("#### %s\n" % path(i).get_file() + FileAccess.get_file_as_string(path(i)))
	return "\n".join(parts)


## This session's header and as much of the newest log as fits in
## `cap` bytes (cut at a line), for the clipboard.
func copy_text(cap := COPY_CAP) -> String:
	flush()
	var head := "\n".join(_header) + "\n"
	var body := PackedByteArray()
	for i in FILES:
		if not FileAccess.file_exists(path(i)):
			continue
		var b := FileAccess.get_file_as_bytes(path(i))
		var marker := ("#### %s\n" % path(i).get_file()).to_utf8_buffer()
		var nb := marker
		nb.append_array(b)
		nb.append_array(body)
		body = nb
		if body.size() >= cap:
			break
	var room := cap - head.to_utf8_buffer().size() - 32
	if body.size() > room:
		var cut := body.size() - room
		# Start at the next line (a newline byte is never inside a UTF-8
		# character).
		while cut < body.size() and body[cut] != 10:
			cut += 1
		body = body.slice(cut + 1)
		return head + "#### ...(older lines cut)\n" + body.get_string_from_utf8()
	return body.get_string_from_utf8()


## Copies the log to the clipboard (Copy log). Returns the bytes copied.
func copy_to_clipboard(cap := COPY_CAP) -> int:
	var text := copy_text(cap)
	DisplayServer.clipboard_set(text)
	var n := text.to_utf8_buffer().size()
	last_status = "Copied %d KB to the clipboard" % (n / 1024)
	log_event("copy", {"bytes": n})
	return n


## Export log: on a phone, Android's own Save dialog (Storage Access
## Framework, no permissions) to put the file anywhere (Downloads, Drive)
## and share it; where there is no native dialog (desktop, tests), a copy
## in user://logs/export/. `done` gets (ok, where).
func export(done := Callable()) -> void:
	var name := "solvera_log_%s.txt" % Time.get_datetime_string_from_system(false, false).replace(":", "-").replace("T", "_")
	var text := all_text()
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		var cb := func(ok: bool, paths: PackedStringArray, _filter: int):
			_saved.call_deferred(ok and not paths.is_empty(), paths[0] if not paths.is_empty() else "", text, done)
		var err := DisplayServer.file_dialog_show("Save the Solvera log", "", name, false,
			DisplayServer.FILE_DIALOG_MODE_SAVE_FILE, PackedStringArray(["*.txt;Text;text/plain"]), cb)
		if err == OK:
			last_status = "Pick where to save the log"
			return
	var to := dir.path_join("export")
	DirAccess.make_dir_recursive_absolute(to)
	_saved(true, to.path_join(name), text, done)


func _saved(ok: bool, where: String, text: String, done: Callable) -> void:
	if ok:
		var f := FileAccess.open(where, FileAccess.WRITE)
		ok = f != null
		if ok:
			f.store_string(text)
			f.close()
	last_export = where
	last_status = ("Saved %d KB: %s" % [text.length() / 1024, where.get_file().uri_decode()]) if ok else "Export cancelled or failed"
	log_event("export", {"ok": ok, "to": where, "bytes": text.length()})
	flush()
	if done.is_valid():
		done.call(ok, where)


# --- Header ---------------------------------------------------------------------

func _header_fields(kind: String) -> Dictionary:
	var h := {}
	match kind:
		"session":
			h["version"] = _version()
			h["engine"] = Engine.get_version_info().string
			h["date"] = Time.get_datetime_string_from_system(false, true)
			h["debug"] = OS.is_debug_build()
			h["locale"] = OS.get_locale()
		"device":
			h["model"] = OS.get_model_name()
			h["os"] = OS.get_name()
			h["os_version"] = OS.get_version()
			h["cpu"] = OS.get_processor_name()
			h["cores"] = OS.get_processor_count()
		"display":
			h["screen"] = DisplayServer.screen_get_size()
			h["scale"] = DisplayServer.screen_get_scale()
			h["dpi"] = DisplayServer.screen_get_dpi()
			h["hz"] = DisplayServer.screen_get_refresh_rate()
			h["window"] = DisplayServer.window_get_size()
			h["viewport"] = get_viewport().get_visible_rect().size if is_inside_tree() else Vector2.ZERO
			h["vsync"] = DisplayServer.window_get_vsync_mode()
			h["max_fps"] = Engine.max_fps
			h["physics_hz"] = Engine.physics_ticks_per_second
		"render":
			h["method"] = RenderingServer.get_current_rendering_method()
			h["driver"] = RenderingServer.get_current_rendering_driver_name()
			h["adapter"] = RenderingServer.get_video_adapter_name()
			h["vendor"] = RenderingServer.get_video_adapter_vendor()
			h["api"] = RenderingServer.get_video_adapter_api_version()
			h["msaa"] = get_viewport().msaa_3d if is_inside_tree() else 0
		"memory":
			var m := OS.get_memory_info()
			for k in m:
				h[k + "_mb"] = _mb(m[k])
			h["static_mb"] = _mb(Performance.get_monitor(Performance.MEMORY_STATIC))
		"settings":
			h = _settings.duplicate()
			if game != null and game.graphics != null:
				for k in ["quality", "cars", "lamps", "car_shadow", "bars"]:
					var v = game.graphics.get(k)
					if v != null:
						h["gfx_" + k] = v
		"camera":
			var cam = game.camera if game != null else null
			if cam != null:
				h["persp"] = cam.perspective
				h["zoom"] = cam.zoom
				h["drive_zoom"] = cam.drive_zoom
				h["base_pitch"] = cam.base_pitch
				h["auto_tilt"] = cam.auto_tilt
				h["turn_view"] = cam.turn_view
				h["turn_steps"] = cam.turn_steps
				h["fov"] = cam.fov
		"save":
			var mm = game.missions if game != null else null
			if mm != null:
				h["path"] = mm.save_path
				h["enabled"] = mm.save_enabled
				h["exists"] = FileAccess.file_exists(mm.save_path)
				if h["exists"]:
					h["bytes"] = FileAccess.get_file_as_bytes(mm.save_path).size()
				h["done"] = ",".join(PackedStringArray(mm.done))
				h["phone"] = mm.phone_unlocked
				h["cash"] = game.cash
				h["bag"] = game.inventory.bag.size()
	return h


## The build: application/config/version, else the export preset's
## version name (in the editor and tests).
func _version() -> String:
	var v := str(ProjectSettings.get_setting("application/config/version", ""))
	if v != "":
		return v
	var cfg := ConfigFile.new()
	if cfg.load("res://export_presets.cfg") == OK:
		return str(cfg.get_value("preset.0.options", "version/name", "?"))
	return "?"


# --- Formatting -----------------------------------------------------------------

func _now() -> float:
	return (Time.get_ticks_usec() - _t0) / 1_000_000.0


func _line(kind: String, data: Dictionary) -> String:
	return "t=%.2f kind=%s" % [_now(), kind] + _kv(data)


static func _kv(data: Dictionary) -> String:
	if data.is_empty():
		return ""
	var parts := PackedStringArray()
	parts.resize(data.size())
	var i := 0
	for k in data:
		var key: String = k
		if key == "t" or key == "kind":
			key = "x_" + key  # never shadow the line's own t= and kind=
		var v = data[k]
		# The common types inline (a call per value is most of the cost).
		var t := typeof(v)
		if t == TYPE_FLOAT:
			parts[i] = key + "=" + String.num(v, 2)
		elif t == TYPE_INT:
			parts[i] = key + "=" + str(v)
		elif t == TYPE_BOOL:
			parts[i] = key + ("=1" if v else "=0")
		else:
			parts[i] = key + "=" + _val(v)
		i += 1
	return " " + " ".join(parts)


## A value as the log writes it: floats to 2 places, vectors to 0.1 m,
## true/false as 1/0, text with spaces in double quotes.
static func _val(v) -> String:
	match typeof(v):
		TYPE_FLOAT:
			return String.num(v, 2)
		TYPE_BOOL:
			return "1" if v else "0"
		TYPE_INT:
			return str(v)
		TYPE_VECTOR3:
			return "%.1f,%.1f,%.1f" % [v.x, v.y, v.z]
		TYPE_VECTOR2:
			return "%.1f,%.1f" % [v.x, v.y]
		TYPE_VECTOR2I:
			return "%d,%d" % [v.x, v.y]
		TYPE_COLOR:
			return v.to_html(false)
		TYPE_NIL:
			return "-"
	var s := str(v)
	if s == "":
		return "-"
	if s.contains(" ") or s.contains("\"") or s.contains("=") or s.contains("\n") or s.contains("\t"):
		return "\"" + s.replace("\"", "'").replace("\n", " / ").replace("\r", "").replace("\t", " ") + "\""
	return s


static func _mb(bytes: float) -> float:
	return snappedf(bytes / 1048576.0, 0.1)
