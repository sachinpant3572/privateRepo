extends Node3D
## Races and cycling (package R of HANDOFF-hill-content.md, phase 3).
##
## By day a checkpoint race on the hill loop (race_course.gd builds it from the
## real roads): drive a car into the start marker, press E, and you line up
## with three rivals, count down, and run the lead-in and two laps. Prize by
## place. After dark (21:00 to 04:00) the same marker offers the illegal night
## run instead: a buy-in, faster rivals, the winner takes the pot, and a
## police unit that sees you racing gives a wanted star. Up on the Calder Trail
## a rental stand hires out a bicycle for $10, and the downhill time trial
## from it earns medals.
##
## The rest of the game reaches it through a few calls (HANDOFF-races.md has
## the patches): prompt(), try_interact(), hud_text(), map_markers(),
## to_save(), load_save().

const Vehicle = preload("res://scripts/vehicle.gd")
const VehicleKit = preload("res://scripts/kits/vehicle_kit.gd")
const MeshBuilder = preload("res://scripts/mesh_builder.gd")
const Terrain = preload("res://scripts/terrain.gd")
const RaceCourse = preload("res://scripts/race_course.gd")

enum State { IDLE, COUNTDOWN, RACING, DONE }

## Laps of the ring in the hill race.
const LAPS := 2
## The night run is open from NIGHT_FROM to NIGHT_TO (hours, past midnight).
const NIGHT_FROM := 21.0
const NIGHT_TO := 4.0
## How close (m) to the start line, the rental stand and the trail's top the
## prompts appear.
const START_RANGE := 22.0
const STAND_RANGE := 5.5
const TRIAL_RANGE := 30.0
## A checkpoint counts when the car comes within this many metres of it.
const GATE_RADIUS := 15.0
const BIKE_GATE_RADIUS := 11.0
const COUNT_TIME := 3.0
const RESULT_TIME := 8.0
## Day prizes by place.
const PRIZE := [400, 200, 80]
## Night buy-in limits; the winner takes everyone's stake.
const WAGER_MIN := 100
const WAGER_MAX := 500
const RENT_PRICE := 10
## Rides that cannot run the road races.
const NO_RACE := ["heli", "police_heli", "bicycle", "scooter", "tipper", "semi", "box_truck"]
const MEDAL_NAMES := ["no medal", "bronze", "silver", "gold"]
## Cash for reaching each medal (paid once, as the medal improves).
const MEDAL_PRIZE := [0, 60, 150, 300]
## The average speed (m/s) over the whole run that earns bronze, silver, gold.
const MEDAL_SPEED := [4.6, 5.6, 6.6]
## A race ends for the player after this long without a checkpoint, or this
## long out of the saddle.
const LOST_TIME := 90.0
const OFF_VEHICLE_TIME := 8.0
## A rival that has not moved for STUCK_TIME, or is OFF_ROUTE metres from its
## line for 3 s, is put back on the course.
const STUCK_TIME := 5.0
const OFF_ROUTE := 30.0
## Rubber band: a rival speeds up or slows by at most this share to stay in
## touch with the player.
const BAND := 0.04

const DAY_RIVALS := [
	{"name": "Kessa Vane", "kind": "sedan", "paint": Color(0.78, 0.12, 0.1), "skill": 0.86, "off": 1.4},
	{"name": "Darrow Pike", "kind": "crossover", "paint": Color(0.95, 0.75, 0.1), "skill": 0.9, "off": -1.4},
	{"name": "Ines Holloway", "kind": "compact", "paint": Color(0.15, 0.55, 0.3), "skill": 0.95, "off": 0.0},
]
const NIGHT_RIVALS := [
	{"name": "Rix", "kind": "sports", "paint": Color(0.1, 0.1, 0.12), "skill": 0.95, "off": 1.4},
	{"name": "Moth", "kind": "muscle", "paint": Color(0.5, 0.08, 0.6), "skill": 1.0, "off": -1.4},
	{"name": "Solenne", "kind": "roadster", "paint": Color(0.9, 0.9, 0.92), "skill": 1.05, "off": 0.0},
]

const BEAM_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.55, 0.1, 0.6);

void fragment() {
	ALBEDO = color.rgb;
	ALPHA = color.a * pow(1.0 - UV.y, 1.2) * (0.85 + 0.15 * sin(TIME * 5.0));
}
"""

var game
var state := State.IDLE
## "day", "night" or "bike": the race on now, or the last one run.
var mode := ""
## Seconds on the race clock (from the start light).
var time := 0.0
## Best times by mode (seconds), and the best medal (0 to 3) on the bike run.
var best := {}
var medal := 0
## The buy-in chosen for the night run (0: a quarter of the cash, in hundreds).
var wager := 0
## What this race cost to enter (night).
var stake := 0
## The last race's result: {mode, place, time, prize, medal, best, new_best}.
var result := {}
## [{car, name, skill, off, passed, base, stall, far, finish, full, path}].
var rivals: Array = []
## The checkpoint the player must pass next (the number passed so far).
var next_gate := 0
var course := {}
## How many times a rival was put back on the course in this race.
var recoveries := 0

var _courses := {}
var _count := 0.0
var _since_gate := 0.0
var _off_vehicle := 0.0
var _done_time := 0.0
var _flagged := false
var _police_clock := 0.0
var _finish_t := INF
var _player_car = null
var _rented = null
var _arch: Node3D
var _arch_label: Label3D
var _arch_back: Label3D
var _arch_at := Vector3.ZERO
var _stand: Node3D
var _stand_at := Vector3.ZERO
var _gates: Array = []
var _clock := 0.0


func _ready() -> void:
	if game == null:
		game = get_parent()
	process_physics_priority = 100
	_build_props()


# --- Courses and places ---------------------------------------------------------

func _country():
	return game.city.country if game != null and game.get("city") != null and game.city != null else null


## The hill race course (cached).
func hill_course() -> Dictionary:
	if not _courses.has("hill"):
		_courses["hill"] = RaceCourse.hill(_country(), LAPS)
	return _courses["hill"]


## The Calder Trail run (cached).
func trail_course() -> Dictionary:
	if not _courses.has("trail"):
		_courses["trail"] = RaceCourse.trail(_country())
	return _courses["trail"]


## The start line's arch.
func arch_pos() -> Vector3:
	return _arch_at


## The bike rental stand.
func stand_pos() -> Vector3:
	return _stand_at


## The top of the downhill run, where the trial starts.
func trail_top() -> Vector3:
	var t := trail_course()
	return t.top if not t.is_empty() else Vector3.ZERO


static func is_night_hour(h: float) -> bool:
	return h >= NIGHT_FROM or h < NIGHT_TO


func _hour() -> float:
	return float(game.atmosphere.hour) if game != null and game.get("atmosphere") != null and game.atmosphere != null else 12.0


## Whether the illegal night run is on offer now (never by day).
func night_race_open() -> bool:
	return is_night_hour(_hour())


## The buy-in for the night run with `cash` in hand: the chosen wager, or a
## quarter of the cash in whole hundreds, within the limits and never more
## than the cash; 0 when there is not even the minimum.
func wager_for(cash: int) -> int:
	if cash < WAGER_MIN:
		return 0
	var w := wager if wager > 0 else int(floor(float(cash) * 0.25 / 100.0)) * 100
	return mini(clampi(w, WAGER_MIN, WAGER_MAX), cash - cash % 100)


## Sets the night buy-in (rounded to hundreds, within the limits).
func set_wager(amount: int) -> void:
	wager = clampi(int(round(float(amount) / 100.0)) * 100, WAGER_MIN, WAGER_MAX)


func is_active() -> bool:
	return state != State.IDLE


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _player_pos() -> Vector3:
	return game.player.focus_node().global_position


func _say(text: String) -> void:
	if game != null and game.get("hud") != null and game.hud != null:
		game.hud.show_message(text)


static func fmt_time(t: float) -> String:
	if t >= INF or t < 0.0:
		return "--:--.-"
	var m := int(t / 60.0)
	return "%d:%04.1f" % [m, t - m * 60.0]


static func ordinal(n: int) -> String:
	return ["1st", "2nd", "3rd", "4th", "5th"][n - 1] if n >= 1 and n <= 5 else "%dth" % n


## The medal (0 to 3) a run of `t` seconds earns on the trail.
func medal_for(t: float) -> int:
	var c := trail_course()
	if c.is_empty() or t <= 0.0:
		return 0
	var speed: float = float(c.length) / t
	var m := 0
	for i in MEDAL_SPEED.size():
		if speed >= float(MEDAL_SPEED[i]):
			m = i + 1
	return m


## The time (s) a medal needs on the trail.
func medal_time(m: int) -> float:
	var c := trail_course()
	return float(c.length) / float(MEDAL_SPEED[m - 1]) if not c.is_empty() and m >= 1 and m <= 3 else 0.0


# --- Prompts --------------------------------------------------------------------

## The HUD's prompt: [text, button] or [].
func prompt() -> Array:
	if state != State.IDLE or game == null or not is_instance_valid(game.player) or game.player.dead:
		return []
	var here := _player_pos()
	var car = game.player.vehicle
	if car == null:
		if _stand_at != Vector3.ZERO and _flat(here, _stand_at) <= STAND_RANGE and not _rented_ready():
			if game.cash < RENT_PRICE:
				return ["Bike hire is $%d: you are short" % RENT_PRICE, "RENT"]
			return ["Rent a bike for $%d: E / RENT" % RENT_PRICE, "RENT"]
		return []
	if game.player.passenger:
		return []
	if car.kind == "bicycle":
		if not trail_course().is_empty() and _flat(here, trail_course().top) <= TRIAL_RANGE:
			return ["Calder downhill trial: E / START", "START"]
		return []
	if car.kind in NO_RACE:
		return []
	if _arch_at != Vector3.ZERO and (_flat(here, _arch_at) <= START_RANGE or _flat(here, Vector3(RaceCourse.START.x, 0, RaceCourse.START.y)) <= START_RANGE):
		if night_race_open():
			var w := wager_for(game.cash)
			if w < WAGER_MIN:
				return ["Night run: you need $%d to buy in" % WAGER_MIN, "RACE"]
			return ["Night run, $%d buy-in: E / RACE" % w, "RACE"]
		return ["Hill race: E / RACE", "RACE"]
	return []


## E: acts on the prompt. True when there was one (so nothing else takes the
## press), whether or not it came off.
func try_interact() -> bool:
	if prompt().is_empty():
		return false
	var car = game.player.vehicle
	if car == null:
		rent_bike()
	elif car.kind == "bicycle":
		start_trial()
	else:
		start_race("night" if night_race_open() else "day")
	return true


# --- Starting and stopping ---------------------------------------------------------

## Lines up the player's car and the rivals on the grid and starts the
## countdown. `race_mode` is "day" (by day only) or "night" (after dark only).
func start_race(race_mode: String) -> bool:
	if state != State.IDLE or game == null or not is_instance_valid(game.player):
		return false
	var c := hill_course()
	var car = game.player.vehicle
	if c.is_empty() or car == null or car.kind in NO_RACE or not (race_mode in ["day", "night"]):
		return false
	if (race_mode == "night") != night_race_open():
		return false
	if Wanted.level > 0:
		_say("Lose the police first")
		return false
	var night: bool = race_mode == "night"
	var buy_in := 0
	if night:
		buy_in = wager_for(game.cash)
		if buy_in < WAGER_MIN:
			_say("A night run takes a $%d buy-in" % WAGER_MIN)
			return false
		game.cash -= buy_in
	stake = buy_in
	mode = race_mode
	course = c
	_begin(car)
	var slot := _slot(0, -1)
	put_car(car, slot.pos, slot.yaw)
	_spawn_rivals(NIGHT_RIVALS if night else DAY_RIVALS)
	_say("%s: %d laps, %d checkpoints" % ["Night run" if night else "Hill race", LAPS, course.gates.size()])
	return true


## The downhill trial: the player's bicycle goes to the top of the trail and
## the countdown starts.
func start_trial() -> bool:
	if state != State.IDLE or game == null or not is_instance_valid(game.player):
		return false
	var c := trail_course()
	var car = game.player.vehicle
	if c.is_empty() or car == null or car.get("kind") != "bicycle":
		return false
	mode = "bike"
	course = c
	stake = 0
	_begin(car)
	var at := RaceCourse.at_arc(c, 1.5)
	put_car(car, at.pos, RaceCourse.yaw_of(at.dir))
	_clear_rivals()
	_say("Calder downhill trial: %d checkpoints" % c.gates.size())
	return true


func _begin(car) -> void:
	state = State.COUNTDOWN
	_count = COUNT_TIME
	time = 0.0
	next_gate = 0
	_since_gate = 0.0
	_off_vehicle = 0.0
	_flagged = false
	_police_clock = 0.0
	_finish_t = INF
	_player_car = car
	recoveries = 0
	result = {}
	_clear_rivals()
	_show_gates()


## A grid slot: row 0 is the front, side -1 the left of the road.
func _slot(row: int, side: int) -> Dictionary:
	var at := RaceCourse.at_arc(course, float(RaceCourse.GRID_ARCS[row]))
	var p: Vector3 = at.pos + RaceCourse.right_of(at.dir) * RaceCourse.GRID_SIDE * float(side)
	return {"pos": p, "yaw": RaceCourse.yaw_of(at.dir)}


## Puts `car` at `pos` (on the ground), facing `yaw`, at rest.
func put_car(car, pos: Vector3, yaw: float) -> void:
	car.global_position = Vector3(pos.x, Terrain.height(pos.x, pos.z) - Terrain.drop(pos.x, pos.z), pos.z)
	car.rotation = Vector3(0.0, yaw, 0.0)
	car.speed = 0.0
	car.velocity = Vector3.ZERO
	car.reset_physics_interpolation()
	if car == game.player.vehicle:
		game.player.global_position = car.global_position
		game.player.rotation.y = yaw
		game.player.reset_physics_interpolation()
		if game.get("camera") != null and game.camera != null:
			game.camera.snap()


func _spawn_rivals(specs: Array) -> void:
	var slots := [[0, 1], [1, -1], [1, 1]]
	for i in mini(specs.size(), slots.size()):
		var s: Dictionary = specs[i]
		var slot := _slot(slots[i][0], slots[i][1])
		var car = _new_rival_car(s)
		game.add_child(car)
		put_car(car, slot.pos, slot.yaw)
		var full := RaceCourse.offset_path(course.rival, float(s.off))
		rivals.append({"car": car, "name": s.name, "skill": float(s.skill), "off": float(s.off), "spec": s, "passed": 0, "base": 0,
			"stall": 0.0, "far": 0.0, "finish": INF, "full": full, "path": full})


func _new_rival_car(s: Dictionary):
	var car = Vehicle.new()
	car.kind = s.kind
	car.body_color = s.paint
	car.city = game.city
	return car


func _go() -> void:
	state = State.RACING
	time = 0.0
	_since_gate = 0.0
	for r in rivals:
		if is_instance_valid(r.car):
			r.car.drive_path(r.path, 0.7)
	_say("GO!")


## Stops the race: the stake (night) is lost, the rivals go.
func cancel(msg := "") -> void:
	if state == State.IDLE:
		return
	_clear_rivals()
	_hide_gates()
	state = State.IDLE
	if msg != "":
		_say(msg)


func _clear_rivals() -> void:
	for r in rivals:
		if is_instance_valid(r.car) and (game == null or not is_instance_valid(game.player) or r.car != game.player.vehicle):
			r.car.queue_free()
	rivals.clear()


# --- The race ---------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if game == null or not is_instance_valid(game.player):
		return
	match state:
		State.COUNTDOWN:
			if _player_ok(delta):
				_hold(_player_car)
				_count -= delta
				if _count <= 0.0:
					_go()
		State.RACING:
			time += delta
			_since_gate += delta
			if _player_ok(delta):
				_check_gate()
				if state == State.RACING:
					_update_rivals(delta)
					if mode == "night":
						_police_tick(delta)
		State.DONE:
			_done_time -= delta
			if _done_time <= 0.0:
				_clear_rivals()
				state = State.IDLE


func _process(delta: float) -> void:
	_clock -= delta
	if _clock > 0.0:
		return
	_clock = 0.5
	if _arch_label != null and game != null and game.get("atmosphere") != null:
		var night := night_race_open()
		var text := "NIGHT RUN" if night else "HILL RACE"
		var tint := Color(1.0, 0.35, 0.7) if night else Color(1.0, 0.7, 0.2)
		for l in [_arch_label, _arch_back]:
			l.text = text
			l.modulate = tint


## Holds a car on the grid through the countdown.
func _hold(car) -> void:
	if car != null and is_instance_valid(car):
		car.speed = 0.0
		car.velocity = Vector3.ZERO


## False (and the race cancelled) when the player is out of it.
func _player_ok(delta: float) -> bool:
	var p = game.player
	if p.dead or game.get("respawning") == true:
		cancel("Race abandoned")
		return false
	var car = p.vehicle
	if car == null:
		_off_vehicle += delta
		if _off_vehicle > OFF_VEHICLE_TIME:
			cancel("You left your ride: race abandoned")
			return false
	else:
		_off_vehicle = 0.0
		_player_car = car
		if car.wrecked:
			cancel("Your ride is wrecked: race abandoned")
			return false
	if _since_gate > LOST_TIME:
		cancel("Lost the course: race abandoned")
		return false
	return true


func _check_gate() -> void:
	var gates: Array = course.gates
	var radius := BIKE_GATE_RADIUS if mode == "bike" else GATE_RADIUS
	if next_gate >= gates.size() or _flat(_player_pos(), gates[next_gate].pos) > radius:
		return
	var g: Dictionary = gates[next_gate]
	next_gate += 1
	_since_gate = 0.0
	if next_gate >= gates.size():
		_finish()
		return
	if g.lap_line and mode != "bike":
		_say("Lap %d/%d" % [lap(), LAPS])
	_show_gates()


## The lap the player is on (1 until the first line is crossed).
func lap() -> int:
	if course.is_empty() or mode == "bike":
		return 1
	var n := 0
	for i in mini(next_gate, course.gates.size()):
		if course.gates[i].lap_line:
			n += 1
	return clampi(n, 1, LAPS)


func _finish() -> void:
	_finish_t = time
	var pl := place()
	var prize := 0
	var got := 0
	var new_best := time < float(best.get(mode, INF))
	if new_best:
		best[mode] = time
	match mode:
		"day":
			prize = int(PRIZE[pl - 1]) if pl <= PRIZE.size() else 0
		"night":
			prize = stake * (rivals.size() + 1) if pl == 1 else 0
		"bike":
			got = medal_for(time)
			if got > medal:
				prize = int(MEDAL_PRIZE[got]) - int(MEDAL_PRIZE[medal])
				medal = got
	game.cash += prize
	state = State.DONE
	_done_time = RESULT_TIME
	result = {"mode": mode, "place": pl, "time": time, "prize": prize, "medal": got, "best": float(best.get(mode, time)),
		"new_best": new_best, "stake": stake}
	_hide_gates()
	var line := ""
	if mode == "bike":
		line = "%s   %s" % [MEDAL_NAMES[got].capitalize(), fmt_time(time)]
	else:
		line = "%s place   %s" % [ordinal(pl), fmt_time(time)]
	if prize > 0:
		line += "   +$%d" % prize
	if new_best:
		line += "   (best)"
	if game.get("hud") != null and game.hud != null:
		game.hud.show_banner(line)
	if game.get("missions") != null and game.missions != null:
		game.missions.save_game()


# --- Rivals -----------------------------------------------------------------------

func _update_rivals(delta: float) -> void:
	var vlim: PackedFloat32Array = course.vlim
	var rival_i: PackedInt32Array = course.rival_i
	var gates: Array = course.gates
	var player_arc := player_arc_now()
	for r in rivals:
		var car = r.car
		if not is_instance_valid(car):
			continue
		if car.wrecked:
			_replace_rival(r)
			continue
		var k: int = clampi(int(r.base) + car.path_index, 0, vlim.size() - 1)
		var rival_arc: float = course.cum[rival_i[k]]
		var band := 1.0 + clampf((player_arc - rival_arc) / 600.0, -BAND, BAND)
		car.script_throttle = clampf(vlim[k] * float(r.skill) * band / car.max_speed, 0.15, 1.0)
		var ri: int = rival_i[k]
		while r.passed < gates.size() and ri + RaceCourse.RIVAL_STRIDE >= gates[r.passed].i:
			r.passed += 1
			if r.passed == gates.size() and r.finish == INF:
				r.finish = time
		if time > 4.0 and r.finish == INF and absf(car.speed) < 1.5:
			r.stall += delta
		else:
			r.stall = 0.0
		var path: PackedVector3Array = r.path
		var want: Vector3 = path[clampi(car.path_index, 0, path.size() - 1)]
		r.far = r.far + delta if _flat(car.global_position, want) > OFF_ROUTE else 0.0
		if r.stall > STUCK_TIME or r.far > 3.0:
			recover_rival(r)


## Puts a stuck or lost rival back on its line, a point behind its target,
## and sends it on.
func recover_rival(r: Dictionary) -> void:
	var car = r.car
	var full: PackedVector3Array = r.full
	var k: int = clampi(int(r.base) + car.path_index - 1, 0, full.size() - 2)
	var a: Vector3 = full[k]
	var b: Vector3 = full[k + 1]
	var d := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
	put_car(car, a, RaceCourse.yaw_of(d))
	r.base = k
	r.path = full.slice(k)
	car.drive_path(r.path, 0.7)
	r.stall = 0.0
	r.far = 0.0
	recoveries += 1


## A rival that burnt out gives way to a fresh car of the same model.
func _replace_rival(r: Dictionary) -> void:
	var old = r.car
	var fresh = _new_rival_car(r.spec)
	game.add_child(fresh)
	r.car = fresh
	r.stall = 0.0
	r.far = 0.0
	put_car(fresh, old.global_position, old.rotation.y)
	old.queue_free()
	recover_rival(r)


## How far along the course the player is (m): the last checkpoint's distance
## plus the stretch covered toward the next.
func player_arc_now() -> float:
	if course.is_empty():
		return 0.0
	var gates: Array = course.gates
	var prev: float = gates[next_gate - 1].arc if next_gate > 0 else 0.0
	if next_gate >= gates.size():
		return float(gates[gates.size() - 1].arc)
	var nxt: Dictionary = gates[next_gate]
	var left := _flat(_player_pos(), nxt.pos)
	return clampf(float(nxt.arc) - left, prev, float(nxt.arc))


## The field in running order: [{name, player, passed, dist, finish}].
func standings() -> Array:
	var list: Array = []
	if state == State.IDLE or course.is_empty():
		return list
	var gates: Array = course.gates
	var pdist := _flat(_player_pos(), gates[next_gate].pos) if next_gate < gates.size() else 0.0
	list.append({"name": "You", "player": true, "passed": next_gate, "dist": pdist, "finish": _finish_t})
	for r in rivals:
		var d := 0.0
		if r.passed < gates.size() and is_instance_valid(r.car):
			d = _flat(r.car.global_position, gates[r.passed].pos)
		list.append({"name": r.name, "player": false, "passed": r.passed, "dist": d, "finish": r.finish})
	list.sort_custom(func(a, b):
		var fa: bool = a.finish < INF
		var fb: bool = b.finish < INF
		if fa != fb:
			return fa
		if fa and a.finish != b.finish:
			return a.finish < b.finish
		if a.passed != b.passed:
			return a.passed > b.passed
		return a.dist < b.dist)
	return list


## The player's place now (1 to the field size); 1 with no rivals.
func place() -> int:
	var list := standings()
	for i in list.size():
		if list[i].player:
			return i + 1
	return 1


# --- Police (night) -----------------------------------------------------------------

func _police_tick(delta: float) -> void:
	_police_clock -= delta
	if _police_clock > 0.0:
		return
	_police_clock = 0.4
	if Wanted.level == 0:
		_flagged = false
	if _flagged:
		return
	if police_sees():
		_flagged = true
		Wanted.report_crime(1)
		_say("Street racing: the police saw you")


## Whether a police car or an officer has a clear line to the player within
## the police's sight range (police_manager.gd's rule, for units that are not
## yet on a chase).
func police_sees() -> bool:
	if game == null or not is_instance_valid(game.player):
		return false
	var target := _player_pos() + Vector3(0.0, 1.0, 0.0)
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var sight := 35.0
	if game.get("police") != null and game.police != null:
		sight = float(game.police.SIGHT_RANGE)
	for car in get_tree().get_nodes_in_group("vehicles"):
		if car == game.player.vehicle or car.get("is_police") != true or car.wrecked:
			continue
		if _clear_line(space, car.global_position + Vector3(0.0, 1.4, 0.0), target, sight):
			return true
	if game.get("police") != null and game.police != null:
		for cop in game.police.cops:
			if is_instance_valid(cop) and not cop.dead:
				if _clear_line(space, cop.global_position + Vector3(0.0, 1.4, 0.0), target, sight):
					return true
	return false


func _clear_line(space: PhysicsDirectSpaceState3D, eye: Vector3, target: Vector3, sight: float) -> bool:
	if eye.distance_to(target) > sight:
		return false
	var query := PhysicsRayQueryParameters3D.create(eye, target, 1) # L.WORLD
	return space.intersect_ray(query).is_empty()


# --- The bike stand ---------------------------------------------------------------

func _rented_ready() -> bool:
	return _rented != null and is_instance_valid(_rented) and not _rented.wrecked \
			and _flat(_rented.global_position, _stand_at) < 60.0


## Hires a bicycle for RENT_PRICE: it appears at the top of the trail and the
## player gets on. True when it did.
func rent_bike() -> bool:
	var c := trail_course()
	if c.is_empty() or game == null or game.player.vehicle != null:
		return false
	if game.cash < RENT_PRICE:
		_say("Bike hire is $%d" % RENT_PRICE)
		return false
	game.cash -= RENT_PRICE
	if _rented != null and is_instance_valid(_rented) and _rented != game.player.vehicle:
		_rented.queue_free()
	var bike = Vehicle.new()
	bike.kind = "bicycle"
	bike.body_color = Color(0.1, 0.62, 0.5)
	bike.city = game.city
	game.add_child(bike)
	var at := RaceCourse.at_arc(c, 2.0)
	put_car(bike, at.pos, RaceCourse.yaw_of(at.dir))
	_rented = bike
	game.player.enter_vehicle(bike)
	_say("Bike hired for $%d. Ride the Calder Trail down" % RENT_PRICE)
	return true


# --- HUD ----------------------------------------------------------------------------

## The race panel's text; "" when idle.
func hud_text() -> String:
	var title := "NIGHT RUN" if mode == "night" else ("CALDER DOWNHILL" if mode == "bike" else "HILL RACE")
	match state:
		State.COUNTDOWN:
			return "%s\n%d" % [title, maxi(ceili(_count), 1)]
		State.RACING:
			var gates: int = course.gates.size()
			var top := ""
			var bottom := ""
			if mode == "bike":
				top = "%s   checkpoint %d/%d" % [title, mini(next_gate + 1, gates), gates]
				bottom = "%s   best %s" % [fmt_time(time), fmt_time(float(best.get("bike", INF)))]
			else:
				top = "%s   lap %d/%d   checkpoint %d/%d" % [title, lap(), LAPS, mini(next_gate + 1, gates), gates]
				bottom = "%s of %d   %s   best %s" % [ordinal(place()), rivals.size() + 1, fmt_time(time),
						fmt_time(float(best.get(mode, INF)))]
			return top + "\n" + bottom
		State.DONE:
			if mode == "bike":
				return "%s\n%s %s" % [title, MEDAL_NAMES[int(result.get("medal", 0))], fmt_time(float(result.get("time", 0.0)))]
			return "%s\n%s place %s" % [title, ordinal(int(result.get("place", 1))), fmt_time(float(result.get("time", 0.0)))]
	return ""


## Map markers: the start line, the bike stand and, in a race, the next gate.
func map_markers() -> Array:
	var out: Array = []
	if _arch_at != Vector3.ZERO:
		var night := night_race_open()
		out.append({"pos": _arch_at, "color": Color(1.0, 0.35, 0.7) if night else Color(1.0, 0.6, 0.15),
				"label": "Night run" if night else "Hill race", "gps": false})
	if _stand_at != Vector3.ZERO:
		out.append({"pos": _stand_at, "color": Color(0.3, 0.85, 0.5), "label": "Bike hire", "gps": false})
	if state in [State.COUNTDOWN, State.RACING] and not course.is_empty() and next_gate < course.gates.size():
		out.append({"pos": course.gates[next_gate].pos, "color": Color(1.0, 0.9, 0.3), "label": "Checkpoint", "gps": false})
	return out


# --- Saving -------------------------------------------------------------------------

func to_save() -> Dictionary:
	return {"best": best.duplicate(), "medal": medal}


func load_save(d: Dictionary) -> void:
	cancel()
	best = {}
	var b = d.get("best", {})
	if typeof(b) == TYPE_DICTIONARY:
		for k in b:
			if k in ["day", "night", "bike"] and typeof(b[k]) in [TYPE_FLOAT, TYPE_INT] and float(b[k]) > 0.0 and float(b[k]) < 36000.0:
				best[k] = float(b[k])
	medal = clampi(int(d.get("medal", 0)), 0, 3)
	result = {}


# --- Props --------------------------------------------------------------------------

func _build_props() -> void:
	var hill := hill_course()
	if not hill.is_empty():
		var at := RaceCourse.at_arc(hill, RaceCourse.ARCH_ARC)
		_arch_at = at.pos
		_arch = _make_arch(RaceCourse.yaw_of(at.dir))
		_arch.position = at.pos
		add_child(_arch)
	var trail := trail_course()
	if not trail.is_empty():
		var at := RaceCourse.at_arc(trail, 0.0)
		var right := RaceCourse.right_of(at.dir)
		var p: Vector3 = trail.top + right * 6.0
		p.y = Terrain.height(p.x, p.z)
		_stand_at = p
		_stand = _make_stand(RaceCourse.yaw_of(at.dir))
		_stand.position = p
		add_child(_stand)
	for i in 3:
		var g := _make_gate(5.4 if i >= 0 else 4.0)
		g.visible = false
		add_child(g)
		_gates.append(g)


func _make_label(text: String, size: float, tint: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.pixel_size = size
	l.font_size = 96
	l.outline_size = 24
	l.modulate = tint
	l.outline_modulate = Color(0.04, 0.04, 0.06)
	l.shaded = false
	return l


## The start line: a gantry across the road with a chequered band and a sign
## each way.
func _make_arch(yaw: float) -> Node3D:
	var root := Node3D.new()
	root.rotation.y = yaw
	var mb := MeshBuilder.new()
	var steel := Color(0.2, 0.21, 0.25)
	var half := 5.6
	for s in [-1.0, 1.0]:
		mb.box(Vector3(s * half, 3.3, 0.0), Vector3(0.6, 6.6, 0.6), steel)
		mb.box(Vector3(s * half, 0.25, 0.0), Vector3(1.2, 0.5, 1.2), Color(0.5, 0.5, 0.52))
	mb.box(Vector3(0.0, 6.9, 0.0), Vector3(half * 2.0 + 0.8, 1.5, 0.4), Color(0.12, 0.12, 0.15))
	var n := 18
	var w := (half * 2.0 - 0.4) / float(n)
	for i in n:
		var c := Color(0.95, 0.95, 0.95) if i % 2 == 0 else Color(0.06, 0.06, 0.07)
		var x := -half + 0.2 + (float(i) + 0.5) * w
		mb.box(Vector3(x, 6.0, 0.0), Vector3(w, 0.4, 0.5), c)
	root.add_child(mb.make_instance())
	_arch_label = _make_label("HILL RACE", 0.011, Color(1.0, 0.7, 0.2))
	_arch_label.position = Vector3(0.0, 6.95, 0.25)
	root.add_child(_arch_label)
	_arch_back = _make_label("HILL RACE", 0.011, Color(1.0, 0.7, 0.2))
	_arch_back.position = Vector3(0.0, 6.95, -0.25)
	_arch_back.rotation.y = PI
	root.add_child(_arch_back)
	# A faint beam over the line, so it reads from far off.
	root.add_child(_beam(Vector3(0.0, 0.0, 0.0), 2.2, 22.0, Color(1.0, 0.6, 0.15, 0.28)))
	return root


## The rental stand: a roofed counter on a footing, a row of bicycles and a
## sign.
func _make_stand(yaw: float) -> Node3D:
	var root := Node3D.new()
	root.rotation.y = yaw
	var mb := MeshBuilder.new()
	var wood := Color(0.45, 0.31, 0.19)
	mb.box(Vector3(0.0, -0.65, 0.0), Vector3(6.2, 1.6, 5.4), Color(0.42, 0.4, 0.37))
	for x in [-2.0, 2.0]:
		for z in [-1.3, 1.3]:
			mb.box(Vector3(x, 1.4, z), Vector3(0.18, 2.8, 0.18), wood)
	mb.box(Vector3(0.0, 2.9, 0.0), Vector3(4.6, 0.22, 3.3), Color(0.14, 0.5, 0.36))
	mb.box(Vector3(0.0, 0.55, -1.1), Vector3(3.6, 1.1, 0.7), wood)
	mb.box(Vector3(0.0, 1.12, -1.1), Vector3(3.8, 0.1, 0.9), Color(0.85, 0.82, 0.74))
	mb.box(Vector3(0.0, 0.1, 1.55), Vector3(3.4, 0.14, 0.5), Color(0.3, 0.3, 0.33))
	root.add_child(mb.make_instance())
	var paints := [Color(0.1, 0.62, 0.5), Color(0.85, 0.2, 0.15), Color(0.95, 0.8, 0.15)]
	for i in 3:
		var bm := MeshBuilder.new()
		var gloss := MeshBuilder.new()
		VehicleKit.build(bm, "bicycle", paints[i], gloss)
		var inst := MeshInstance3D.new()
		inst.mesh = bm.commit()
		inst.material_override = MeshBuilder.material()
		var gi := MeshInstance3D.new()
		gi.mesh = gloss.commit()
		gi.material_override = MeshBuilder.gloss_material()
		inst.add_child(gi)
		inst.position = Vector3(-1.1 + 1.1 * float(i), 0.17, 1.55)
		inst.rotation.y = PI * 0.5
		root.add_child(inst)
	var sign := _make_label("BIKE HIRE  $%d" % RENT_PRICE, 0.009, Color(1.0, 1.0, 1.0))
	sign.position = Vector3(0.0, 3.35, -1.65)
	sign.rotation.y = PI
	root.add_child(sign)
	var sign_b := _make_label("BIKE HIRE  $%d" % RENT_PRICE, 0.009, Color(1.0, 1.0, 1.0))
	sign_b.position = Vector3(0.0, 3.35, 1.65)
	root.add_child(sign_b)
	root.add_child(_beam(Vector3(0.0, 0.0, 0.0), 1.6, 18.0, Color(0.3, 0.9, 0.5, 0.25)))
	return root


## A translucent column of light.
func _beam(base: Vector3, radius: float, height: float, tint: Color) -> MeshInstance3D:
	var col := CylinderMesh.new()
	col.top_radius = radius
	col.bottom_radius = radius
	col.height = height
	col.cap_top = false
	col.cap_bottom = false
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = BEAM_SHADER
	mat.shader = sh
	mat.set_shader_parameter("color", tint)
	var inst := MeshInstance3D.new()
	inst.mesh = col
	inst.material_override = mat
	inst.position = base + Vector3(0.0, height * 0.5, 0.0)
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return inst


## A checkpoint gate: two glowing pillars `half` metres either side of the
## centre of the road and a bar across the top.
func _make_gate(half: float) -> Node3D:
	var root := Node3D.new()
	var beams: Array = []
	for s in [-1.0, 1.0]:
		var b := _beam(Vector3(s * half, 0.0, 0.0), 0.7, 12.0, Color(1.0, 0.55, 0.1, 0.7))
		root.add_child(b)
		beams.append(b)
	var bar := BoxMesh.new()
	bar.size = Vector3(half * 2.0, 0.35, 0.35)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.55, 0.1)
	var inst := MeshInstance3D.new()
	inst.mesh = bar
	inst.material_override = mat
	inst.position = Vector3(0.0, 6.0, 0.0)
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(inst)
	root.set_meta("beams", beams)
	root.set_meta("bar", mat)
	return root


## Lights the next three checkpoints (the one to take bright).
func _show_gates() -> void:
	if course.is_empty():
		_hide_gates()
		return
	var gates: Array = course.gates
	var tint := Color(0.3, 1.0, 0.45) if mode == "bike" else (Color(1.0, 0.3, 0.65) if mode == "night" else Color(1.0, 0.55, 0.1))
	for j in _gates.size():
		var g: Node3D = _gates[j]
		var idx := next_gate + j
		if idx >= gates.size():
			g.visible = false
			continue
		var d: Dictionary = gates[idx]
		var t := tint
		if d.lap_line and mode != "bike":
			t = Color(1.0, 0.95, 0.6)
		var alpha := 0.75 if j == 0 else 0.3
		g.position = d.pos
		g.rotation.y = RaceCourse.yaw_of(d.dir)
		g.visible = true
		for b in g.get_meta("beams"):
			b.material_override.set_shader_parameter("color", Color(t, alpha))
		g.get_meta("bar").albedo_color = Color(t, 1.0)


func _hide_gates() -> void:
	for g in _gates:
		g.visible = false
