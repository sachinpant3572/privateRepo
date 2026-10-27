extends Node
## Taxis (WORLD_V3_PLAN.md §6: "hail or phone; ride along, or pay extra to
## skip. Prices follow the city").
##
## Hail: on foot and not wanted, with a cab that has a driver within
## HAIL_RANGE, the TAXI button (or T) makes it pull over beside you.
## Phone: the Cab app sends one from out of view along the streets, shown on
## the maps. Get in with ENTER (as a passenger: hailed cabs are not
## carjacked), pick where to go (the map waypoint, else the GPS mission
## marker, else a list of destinations), see the fare, then ride along or
## pay extra to skip there. Pay on arrival; get out early and pay the fare so
## far. Wanted cabbies won't stop and throw you out; a wrecked or stuck cab
## drops you off for free; a mission start or death ends the ride.

const Vehicle = preload("res://scripts/vehicle.gd")
const VehicleKit = preload("res://scripts/kits/vehicle_kit.gd")

## Fares by city: flag fall, then per km of the route, never less than the
## minimum (whole dollars). Bellerive is cheap: a cross-town ride of about
## 2 km is $10, less than a diner breakfast plus a coffee.
const PRICES := {
	"bellerive": {"base": 4, "per_km": 3.0, "min": 6},
}
const CITY := "bellerive"
## Skipping the ride costs this much more than riding along.
const SKIP_MARKUP := 1.5
## A cab with a driver this close (m) can be hailed.
const HAIL_RANGE := 15.0
## A cab waits this long (s) at the curb, and gives up when you walk this far
## (m) from it.
const WAIT_TIME := 40.0
const WALK_AWAY := 60.0
## Seconds without moving before a cab counts as stuck.
const STUCK_TIME := 10.0
## After a drop-off the cab waits until you are this far away (m), or this
## long (s), before it drives off (so it doesn't clip you pulling out).
const CLEAR_DISTANCE := 5.0
const CLEAR_TIME := 6.0
## A called cab gives up if it hasn't arrived by then (s).
const CALL_TIMEOUT := 120.0
## Called cabs set off this far away (m), out of view.
const CALL_SPAWN := Vector2(60.0, 120.0)
## Driving: cruise (m/s, like traffic), corner speed and the final approach.
const CRUISE := 13.0
const TURN_SPEED := 6.0
const TURN_ZONE := 18.0
const STOP_ZONE := 22.0
## The curb lane: this much further out than the lane line.
const CURB_SHIFT := 1.25
## Destinations closer than this (m) are left out of the list.
const NEAR_DEST := 120.0
const FADE_TIME := 0.35
const DRIVER := "Cabbie"
const MARK_COLOR := Color(1.0, 0.9, 0.15)
const DROP_COLOR := Color(0.35, 0.85, 1.0)

enum State { IDLE, PICKUP, WAITING, CHOOSING, RIDING, STOPPING, SKIPPING }

var game
var state := State.IDLE
var cab = null
## The cab came by phone (else it was hailed in the street).
var called := false
## The trip: {name, pos, stop, yaw, points, length, fare} once chosen.
var trip := {}
## Distance the cab has driven with the player since the meter started (m).
var driven := 0.0
var rng := RandomNumberGenerator.new()

var _timer := 0.0
var _stuck := 0.0
var _last_pos := Vector3.ZERO
var _skip_phase := 0
var _skip_frames := 0
var _fade_alpha := 0.0
## The mission running when the job began (a new one cancels the job).
var _mission = null
## Cabs done with a job, waiting for the player to step clear before they
## drive off: [cab, seconds waited].
var _leaving: Array = []
## UI (built by the HUD through build_ui).
var _hail_button: Button
var _panel: PanelContainer
var _panel_title: Label
var _panel_body: VBoxContainer
var _bar: PanelContainer
var _bar_text: Label
var _bar_skip: Button
var _fade: ColorRect
var _panel_mode := ""


func _ready() -> void:
	rng.randomize()


# --- Pricing ---------------------------------------------------------------------

## The fare for a route of `metres`, in whole dollars.
static func fare_for(metres: float) -> int:
	var p: Dictionary = PRICES[CITY]
	return maxi(p.min, int(round(p.base + p.per_km * metres / 1000.0)))


static func skip_fare(fare: int) -> int:
	return int(ceil(fare * SKIP_MARKUP))


## What the meter shows after `metres` with you in the cab, up to the fare.
func fare_so_far() -> int:
	var p: Dictionary = PRICES[CITY]
	var due := int(round(p.base + p.per_km * driven / 1000.0))
	return mini(due, trip.get("fare", due))


# --- Hail and call ---------------------------------------------------------------

## The nearest cab you could hail right now, or null.
func hailable_cab():
	if not _free_on_foot() or Wanted.level > 0 or state != State.IDLE:
		return null
	var p: Vector3 = game.player.global_position
	var best = null
	var best_d := HAIL_RANGE
	for car in get_tree().get_nodes_in_group("vehicles"):
		if car.kind != "taxi" or car.wrecked or car.driver != Vehicle.Driver.TRAFFIC:
			continue
		var d: float = p.distance_to(car.global_position)
		if d < best_d:
			best = car
			best_d = d
	return best


## Hails the nearest cab: it pulls over beside the player. False (with a
## reason shown) when none will stop.
func hail() -> bool:
	if state != State.IDLE or not _free_on_foot():
		return false
	if Wanted.level > 0:
		_say("Cabs won't stop for you with the cops on your tail.")
		return false
	var car = hailable_cab()
	if car == null:
		return false
	var stop := _hail_stop(car)
	if stop.is_empty():
		return false
	_take(car, false)
	cab.drive_path(stop.points, CRUISE / cab.max_speed)
	trip = {}
	state = State.PICKUP
	return true


## Why a cab can't be called now ("" when it can).
func call_reason() -> String:
	if Wanted.level > 0:
		return "No cab will come while the police are after you."
	if state == State.PICKUP or state == State.WAITING:
		return "Your cab is already on its way."
	if state != State.IDLE:
		return "You're already in a cab."
	if game.player.vehicle != null:
		return "Get out of the car first."
	if game.interiors != null and game.interiors.state != game.interiors.State.OUTSIDE:
		return "Step outside first."
	return ""


## Calls a cab by phone: it sets off out of view and drives to the curb
## nearest the player. Returns "" or why it can't come.
func call_cab() -> String:
	var why := call_reason()
	if why != "":
		return why
	var city = game.city
	var p: Vector3 = game.player.global_position
	var curb := _curb_near(p)
	if curb.is_empty():
		return "No cab can reach you here."
	var accept := Callable()
	if game.population != null:
		accept = game.population.out_of_view
	var start := -1
	for attempt in 3:
		start = city.random_node_between(p, CALL_SPAWN.x, CALL_SPAWN.y * (1.0 + attempt), rng, accept)
		if start >= 0 and not city.next_nodes(start).is_empty():
			break
		start = -1
	if start < 0:
		return "No cabs nearby. Try again in a minute."
	var plan := _approach(start, curb, p)
	if plan.is_empty():
		return "No cab can reach you here."
	var car = Vehicle.new()
	car.kind = "taxi"
	car.body_color = VehicleKit.pick_paint("taxi", rng)
	car.city = city
	car.position = city.lane_start(start, plan.first)
	var heading: Vector3 = city.node_pos(plan.first) - city.node_pos(start)
	car.rotation.y = atan2(-heading.x, -heading.z)
	car.rng.seed = rng.randi()
	game.add_child(car)
	_take(car, true)
	cab.drive_path(plan.points, CRUISE / cab.max_speed)
	trip = {}
	state = State.PICKUP
	_say("A cab's on its way.")
	return ""


## Sends a called or hailed cab away before you get in.
func cancel_cab() -> void:
	if state == State.PICKUP or state == State.WAITING:
		_release()


## ENTER near the waiting cab gets you in as a passenger (player.gd asks
## before carjacking). True when it did.
func board(car) -> bool:
	if car == null or car != cab or state != State.WAITING:
		return false
	if Wanted.level > 0:
		return false
	game.player.enter_as_passenger(cab)
	driven = 0.0
	state = State.CHOOSING
	var dests := destinations()
	if not dests.is_empty() and dests[0].get("auto", false):
		choose(dests[0])
	else:
		_show_choices()
	_say("Where to?")
	return true


# --- Destinations and the ride ---------------------------------------------------

## Where to: the waypoint, then the mission's GPS marker (each marked
## "auto"), then the city's destinations, nearest first.
func destinations() -> Array:
	var list: Array = []
	if game.waypoint != null:
		list.append({"name": "Waypoint", "pos": game.waypoint, "auto": true})
	if game.missions != null:
		for m in game.missions.markers:
			if m.get("gps", false):
				list.append({"name": m.get("label", "Mission"), "pos": m.pos, "auto": list.is_empty()})
				break
	var from: Vector3 = game.player.focus_node().global_position
	var places: Array = []
	if game.city.has_method("taxi_destinations"):
		places = game.city.taxi_destinations()
	else:
		places = game.city.landmarks()
	places = places.filter(func(d): return from.distance_to(d.pos) > NEAR_DEST)
	places.sort_custom(func(a, b): return from.distance_to(a.pos) < from.distance_to(b.pos))
	for d in places:
		list.append({"name": d.name, "pos": d.pos})
	return list


## Plans the ride to `dest` ({name, pos}) and shows the fare. Returns the
## trip ({} when no road gets there).
func choose(dest: Dictionary) -> Dictionary:
	if state != State.CHOOSING:
		return {}
	var plan := plan_ride(dest.pos)
	if plan.is_empty():
		_say("Can't get there from here.")
		return {}
	plan["name"] = dest.name
	trip = plan
	_show_confirm()
	return trip


## Plans a drive from the cab's spot to the curb nearest `pos`:
## {pos, stop, yaw, points, length, fare}, or {} if there is no road.
func plan_ride(pos: Vector3) -> Dictionary:
	if cab == null:
		return {}
	var curb := _curb_near(pos)
	if curb.is_empty():
		return {}
	var city = game.city
	var fwd: Vector3 = -cab.global_basis.z
	var ahead: int = city.nearest_node(cab.global_position + fwd * 20.0)
	if ahead < 0:
		return {}
	var plan := _approach(ahead, curb, pos)
	if plan.is_empty():
		return {}
	var points := PackedVector3Array([city.node_pos(ahead)])
	points.append_array(plan.points)
	var length := 0.0
	var at: Vector3 = cab.global_position
	for q in points:
		length += Vector2(q.x - at.x, q.z - at.z).length()
		at = q
	return {"pos": pos, "stop": plan.stop, "yaw": plan.yaw, "points": points,
		"length": length, "fare": fare_for(length)}


## Starts the meter and drives the chosen trip. False when you can't pay.
func ride() -> bool:
	if state != State.CHOOSING or trip.is_empty():
		return false
	if game.cash < trip.fare:
		_say("That's $%d and you've got $%d. Walk, friend." % [trip.fare, game.cash])
		return false
	cab.drive_path(trip.points, CRUISE / cab.max_speed)
	driven = 0.0
	_stuck = 0.0
	_last_pos = cab.global_position
	state = State.RIDING
	_show_bar()
	_say("Sit back. %s it is." % trip.name)
	return true


## Pays extra to be there at once: a fade, and the cab at the curb with
## you beside it. False when you can't pay.
func skip() -> bool:
	if trip.is_empty() or not (state == State.CHOOSING or state == State.RIDING):
		return false
	var cost := skip_fare(trip.fare)
	if game.cash < cost:
		_say("Skipping the drive is $%d. You've got $%d." % [cost, game.cash])
		return false
	state = State.SKIPPING
	_skip_phase = 0
	game.player.controllable = false
	_hide_ui()
	return true


## GET OUT (or ENTER inside the cab): out at once before the meter runs;
## during the ride the cab pulls up first and you pay the fare so far.
func request_exit() -> void:
	match state:
		State.CHOOSING:
			game.player.exit_vehicle()
			_say("Suit yourself.")
			_release()
		State.RIDING:
			cab.path = PackedVector3Array()
			cab.path_index = 0
			state = State.STOPPING
		State.STOPPING, State.SKIPPING:
			pass
		_:
			if game.player.vehicle != null and game.player.passenger:
				game.player.exit_vehicle()


# --- Per frame -------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if Controls.just_pressed("hail"):
		hail()
	_send_off(delta)
	if state == State.IDLE:
		return
	var player = game.player
	if cab == null or not is_instance_valid(cab):
		_end_ride("")
		return
	# Ends that apply in every state.
	if player.dead or game.respawning:
		_end_ride("")
		return
	if game.missions != null and game.missions.active != null and game.missions.active != _mission:
		# A mission started: the job is off.
		_end_ride("")
		return
	if cab.driver == Vehicle.Driver.PLAYER or (cab.driver == Vehicle.Driver.NONE and not cab.wrecked):
		# Hijacked (or knocked about): no longer a cab job.
		_end_ride("")
		return
	if cab.wrecked:
		_end_ride("That's it, my cab's done for. No charge." if _riding_now() else "")
		return
	if Wanted.level > 0 and state != State.SKIPPING:
		_end_ride("Out! I don't want trouble with the cops." if _riding_now() else "")
		return
	if _riding_now() and player.vehicle != cab:
		# Out by some other way (a mission teleport, a new game).
		_end_ride("")
		return
	match state:
		State.PICKUP:
			_drive_shaping()
			_timer += delta
			if _check_stuck(delta) or _timer > CALL_TIMEOUT:
				_say("Your cab got stuck in traffic. Try again.")
				_release()
			elif cab.path_index >= cab.path.size() and _stopped():
				state = State.WAITING
				_timer = 0.0
				if called:
					_say("Your cab is here.")
		State.WAITING:
			_timer += delta
			var far: bool = player.global_position.distance_to(cab.global_position) > WALK_AWAY
			if _timer > WAIT_TIME or far:
				_release()
		State.CHOOSING:
			pass
		State.RIDING:
			_meter()
			_drive_shaping()
			_update_bar()
			if _check_stuck(delta):
				_end_ride("Can't get through, sorry. This one's on me.")
			elif cab.path_index >= cab.path.size() and _stopped():
				_arrive(trip.fare, "That's $%d. Enjoy %s." % [trip.fare, trip.name])
		State.STOPPING:
			_meter()
			if _stopped():
				var due := fare_so_far()
				_arrive(due, "Here's fine? That's $%d." % due)
		State.SKIPPING:
			_run_skip(delta)


func _process(_delta: float) -> void:
	if _hail_button == null:
		return
	var overlay: bool = game.hud != null and (game.hud.phone.visible or game.hud.full_map.visible)
	_hail_button.visible = not overlay and hailable_cab() != null
	_panel.visible = not overlay and state == State.CHOOSING
	_bar.visible = not overlay and (state == State.RIDING or state == State.STOPPING)
	_fade.color.a = _fade_alpha
	_fade.visible = _fade_alpha > 0.0


## At a standstill: no forward speed and no slide either.
func _stopped() -> bool:
	return absf(cab.speed) < 0.5 and cab.get_real_velocity().length() < 0.5


func _riding_now() -> bool:
	return state in [State.CHOOSING, State.RIDING, State.STOPPING, State.SKIPPING]


func _meter() -> void:
	var p: Vector3 = cab.global_position
	driven += Vector2(p.x - _last_pos.x, p.z - _last_pos.z).length()
	_last_pos = p


## Not moving for STUCK_TIME seconds.
func _check_stuck(delta: float) -> bool:
	if cab.path_index >= cab.path.size():
		_stuck = 0.0
		return false
	if cab.get_real_velocity().length() < 0.6:
		_stuck += delta
	else:
		_stuck = 0.0
	return _stuck > STUCK_TIME


## Throttle for the scripted cab: traffic's cruise, slowing for corners
## and easing to a stop at the curb.
func _drive_shaping() -> void:
	var i: int = cab.path_index
	var path: PackedVector3Array = cab.path
	if i >= path.size():
		return
	var cruise: float = CRUISE / cab.max_speed
	var to: Vector3 = path[i] - cab.global_position
	to.y = 0.0
	var thr := cruise
	if i + 1 < path.size():
		var out: Vector3 = path[i + 1] - path[i]
		out.y = 0.0
		if out.length() > 0.5 and to.length() > 0.5 and to.length() < TURN_ZONE:
			var angle := absf(to.signed_angle_to(out, Vector3.UP))
			if angle > 0.5:
				thr = minf(thr, lerpf(TURN_SPEED, 3.5, clampf((angle - 0.5) / 2.0, 0.0, 1.0)) / cab.max_speed)
	else:
		thr = cruise * clampf(to.length() / STOP_ZONE, 0.2, 1.0)
	cab.script_throttle = thr


## Out at the curb and paid.
func _arrive(fare: int, line: String) -> void:
	var player = game.player
	if player.vehicle == cab:
		player.exit_vehicle()
	var paid := mini(fare, game.cash)
	game.cash -= paid
	if game.missions != null:
		game.missions.save_game()
	_say(line)
	_release()


## Ends a ride or a pickup without a fare: the player (if inside) gets out,
## the cab goes back to traffic.
func _end_ride(line: String) -> void:
	var player = game.player
	if cab != null and is_instance_valid(cab) and player.vehicle == cab:
		player.exit_vehicle()
	if state == State.SKIPPING:
		_fade_alpha = 0.0
	if not game.respawning:
		player.controllable = true
	if line != "":
		_say(line)
	_release()


## Gives the cab back to traffic and clears the job.
func _release() -> void:
	if cab != null and is_instance_valid(cab):
		if not cab.wrecked and cab.driver != Vehicle.Driver.PLAYER:
			cab.path = PackedVector3Array()
			cab.path_index = 0
			if cab.driver != Vehicle.Driver.SCRIPT:
				cab.driver = Vehicle.Driver.SCRIPT # holds the brake while it waits
			_leaving.append([cab, 0.0])
		# Population despawns it again once it is far away.
		if game.population != null and not game.population.cars.has(cab):
			game.population.cars.append(cab)
	cab = null
	called = false
	trip = {}
	state = State.IDLE
	_timer = 0.0
	_stuck = 0.0
	_fade_alpha = 0.0
	_hide_ui()


## Cabs back to traffic once the player is clear of them.
func _send_off(delta: float) -> void:
	for entry in _leaving.duplicate():
		var car = entry[0]
		entry[1] += delta
		if not is_instance_valid(car) or car.wrecked or car.driver != Vehicle.Driver.SCRIPT or car == cab:
			_leaving.erase(entry)
			continue
		var p = game.player
		var gap: float = p.global_position.distance_to(car.global_position)
		if (gap > CLEAR_DISTANCE and p.vehicle != car) or entry[1] > CLEAR_TIME:
			_leaving.erase(entry)
			car.join_traffic_here()


func _take(car, by_phone: bool) -> void:
	cab = car
	called = by_phone
	_mission = game.missions.active if game.missions != null else null
	_timer = 0.0
	_stuck = 0.0
	if not by_phone and game.population != null:
		# Ours until the job ends: population won't despawn it meanwhile.
		game.population.cars.erase(car)


## The skip: fade out, move the cab to the curb at the destination with the
## player beside it, fade in, pay.
func _run_skip(delta: float) -> void:
	match _skip_phase:
		0:
			_fade_alpha = minf(1.0, _fade_alpha + delta / FADE_TIME)
			if _fade_alpha >= 1.0:
				_skip_phase = 1
				var stop: Vector3 = trip.stop
				game.city.stream_now(stop)
				cab.path = PackedVector3Array()
				cab.path_index = 0
				cab.global_position = stop
				cab.rotation = Vector3(0.0, trip.yaw, 0.0)
				cab.velocity = Vector3.ZERO
				cab.speed = 0.0
				cab.reset_physics_interpolation()
				# The trip took time.
				var secs: float = trip.length / CRUISE
				game.atmosphere.hour = fmod(game.atmosphere.hour + secs * game.atmosphere.minutes_per_second / 60.0, 24.0)
				_skip_frames = 0
		1:
			# Let physics see the streamed street before stepping out.
			_skip_frames += 1
			if _skip_frames >= 3:
				var player = game.player
				if player.vehicle == cab:
					player.exit_vehicle()
				player.controllable = true
				game.camera.snap()
				var cost := skip_fare(trip.fare)
				game.cash -= mini(cost, game.cash)
				if game.missions != null:
					game.missions.save_game()
				_say("That's $%d with the shortcut. Enjoy %s." % [cost, trip.name])
				_skip_phase = 2
		2:
			_fade_alpha = maxf(0.0, _fade_alpha - delta / FADE_TIME)
			if _fade_alpha <= 0.0:
				_release()


# --- Road geometry ---------------------------------------------------------------

## The street nearest `pos`: {a, b, at} with `at` the nearest point on the
## street a-b (kept clear of the junctions). {} when there is no road.
func _curb_near(pos: Vector3) -> Dictionary:
	var city = game.city
	var n: int = city.nearest_node(pos)
	if n < 0:
		return {}
	var nodes := [n]
	for m in city.next_nodes(n):
		nodes.append(m)
	var best := {}
	var best_d := INF
	var seen := {}
	for a in nodes:
		for b in city.next_nodes(a):
			var key := Vector2i(mini(a, b), maxi(a, b))
			if seen.has(key):
				continue
			seen[key] = true
			var pa: Vector3 = city.node_pos(a)
			var ab: Vector3 = city.node_pos(b) - pa
			ab.y = 0.0
			var length := ab.length()
			if length < 1.0:
				continue
			var t := clampf((pos - pa).dot(ab) / (length * length), 0.0, 1.0)
			# Away from the junctions (the middle of a short street).
			var margin := minf(9.0, length * 0.5) / length
			t = clampf(t, margin, 1.0 - margin)
			var at := pa + ab * t
			var d := Vector2(pos.x - at.x, pos.z - at.z).length()
			if d < best_d:
				best_d = d
				best = {"a": a, "b": b, "at": at}
	return best


## Where a cab driving from junction `from` toward `to` stops at `at`: in
## the right-hand lane, nudged toward the curb. [stop, yaw]
func _curb_stop(from: int, to: int, at: Vector3) -> Array:
	var city = game.city
	var off: Vector3 = city.lane_point(from, to) - city.node_pos(to)
	var dir: Vector3 = city.node_pos(to) - city.node_pos(from)
	return [at + off * CURB_SHIFT, atan2(-dir.x, -dir.z)]


## A drive from junction `start` to a stop on the curb street, arriving the
## way that keeps the curb on `side_of`'s side when the route allows (no
## U-turn at the last junction): {points, stop, yaw, first} where `first`
## is the junction after `start`, or {} when no road connects them.
func _approach(start: int, curb: Dictionary, side_of: Vector3) -> Dictionary:
	var city = game.city
	var options := []
	for dir in [[curb.a, curb.b], [curb.b, curb.a]]:
		var s := _curb_stop(dir[0], dir[1], curb.at)
		var near_side: bool = (s[0] - curb.at).dot(side_of - curb.at) > 0.0
		var nodes: PackedInt64Array = city.route_nodes(city.node_pos(start), city.node_pos(dir[0]))
		if nodes.is_empty() and start != dir[0]:
			continue
		if nodes.is_empty():
			nodes = PackedInt64Array([start])
		# Coming in along the curb street itself means turning back on it.
		var turns_back: bool = nodes.size() >= 2 and nodes[nodes.size() - 2] == dir[1]
		var length := 0.0
		for k in range(1, nodes.size()):
			length += city.node_pos(nodes[k - 1]).distance_to(city.node_pos(nodes[k]))
		var score := length + (0.0 if near_side else 60.0) + (400.0 if turns_back else 0.0)
		options.append({"nodes": nodes, "stop": s[0], "yaw": s[1], "to": dir[1], "score": score})
	if options.is_empty():
		return {}
	options.sort_custom(func(x, y): return x.score < y.score)
	var best: Dictionary = options[0]
	var nodes: PackedInt64Array = best.nodes
	var points := PackedVector3Array()
	for k in nodes.size():
		if k == 0:
			if nodes.size() > 1:
				points.append(city.lane_start(nodes[0], nodes[1]))
		else:
			points.append(city.lane_point(nodes[k - 1], nodes[k]))
	var last: int = nodes[nodes.size() - 1]
	points.append(city.lane_start(last, best.to))
	points.append(best.stop)
	var first: int = nodes[1] if nodes.size() > 1 else best.to
	return {"points": points, "stop": best.stop, "yaw": best.yaw, "first": first}


## Where a hailed cab pulls over: on its own street, level with the player
## (or as soon after as it can stop), else round the corner via _approach.
func _hail_stop(car) -> Dictionary:
	var city = game.city
	var p: Vector3 = game.player.global_position
	var a: int = car._prev_node
	var b: int = car._next_node
	if a >= 0 and b >= 0 and a != b:
		var pa: Vector3 = city.node_pos(a)
		var ab: Vector3 = city.node_pos(b) - pa
		ab.y = 0.0
		var length := ab.length()
		if length > 1.0:
			var dir := ab / length
			var along_cab: float = (car.global_position - pa).dot(dir)
			var along_p: float = (p - pa).dot(dir)
			var s := maxf(along_p, along_cab + 9.0)
			if s <= length - 5.0:
				var stop := _curb_stop(a, b, pa + dir * s)
				return {"points": PackedVector3Array([stop[0]])}
	if b < 0:
		return {}
	var curb := _curb_near(p)
	if curb.is_empty():
		return {}
	var plan := _approach(b, curb, p)
	if plan.is_empty():
		return {}
	var points := PackedVector3Array([city.lane_point(a, b) if a >= 0 else city.node_pos(b)])
	points.append_array(plan.points)
	return {"points": points}


# --- Maps ------------------------------------------------------------------------

## Markers for main.gd's map_markers(): the cab on its way, the drop-off
## during the ride.
func map_markers() -> Array:
	var list: Array = []
	if cab != null and is_instance_valid(cab) and (state == State.PICKUP or state == State.WAITING):
		list.append({"pos": cab.global_position, "color": MARK_COLOR, "label": "Your cab", "gps": false})
	if not trip.is_empty() and (state == State.RIDING or state == State.STOPPING):
		list.append({"pos": trip.stop, "color": DROP_COLOR, "label": "Drop-off", "gps": true})
	return list


# --- HUD -------------------------------------------------------------------------

## [prompt, button label] for the HUD near the waiting cab, or [].
func prompt() -> Array:
	if state != State.WAITING or cab == null or game.player.vehicle != null:
		return []
	if game.player.nearest_vehicle() == cab:
		return ["Get in the cab: E / ENTER", "GET IN"]
	return ["Your cab is waiting", "ENTER"]


## Status for the phone's Cab app.
func phone_status() -> String:
	match state:
		State.PICKUP:
			var d := 0
			if cab != null and is_instance_valid(cab):
				d = int(cab.global_position.distance_to(game.player.global_position))
			return "Your cab is on its way (%d m)." % d
		State.WAITING:
			return "Your cab is waiting at the curb."
		State.IDLE:
			return "Bellerive Cabs, day and night."
	return "You're in a cab."


func price_text() -> String:
	var p: Dictionary = PRICES[CITY]
	return "$%d + $%d a km (at least $%d). Skip the drive for +%d%%." % [p.base, int(p.per_km), p.min, int(round((SKIP_MARKUP - 1.0) * 100.0))]


## Builds the TAXI button, the destination and fare panel, the ride bar
## and the fade under the HUD's root (called by hud.gd), and keeps the
## touch stick off them.
func build_ui(root: Control, touch) -> void:
	_hail_button = _button("TAXI", hail, true)
	_hail_button.add_theme_font_size_override("font_size", 24)
	_anchor(_hail_button, Vector2(1, 1), Rect2(-215, -430, 150, 64))
	root.add_child(_hail_button)

	_panel = _frame()
	_anchor(_panel, Vector2(0.5, 0.5), Rect2(-280, -270, 560, 540))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)
	_panel_title = _text("", 26, Color(1.0, 0.85, 0.3))
	col.add_child(_panel_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_panel_body = VBoxContainer.new()
	_panel_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_body.add_theme_constant_override("separation", 8)
	scroll.add_child(_panel_body)
	col.add_child(_button("GET OUT", request_exit))
	root.add_child(_panel)

	# One slim row under the clock line, so the cab below stays in view.
	_bar = _frame()
	_anchor(_bar, Vector2(0.5, 0), Rect2(-340, 132, 680, 84))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_bar.add_child(row)
	_bar_text = _text("", 19, Color.WHITE)
	_bar_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	_bar_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_bar_text.clip_text = true
	_bar_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_bar_text)
	_bar_skip = _button("SKIP", func(): skip())
	_bar_skip.custom_minimum_size = Vector2(120, 56)
	row.add_child(_bar_skip)
	var out := _button("GET OUT", request_exit)
	out.custom_minimum_size = Vector2(130, 56)
	row.add_child(out)
	root.add_child(_bar)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)
	_hide_ui()
	if touch != null:
		touch.exclusions.append_array([_hail_button, _panel, _bar])


func _hide_ui() -> void:
	_panel_mode = ""
	if _panel == null:
		return
	_panel.visible = false
	_bar.visible = false


## The destination list (GO picks one).
func _show_choices() -> void:
	if _panel == null:
		return
	_panel_mode = "choose"
	_panel_height(540)
	_panel_title.text = "TAXI  ·  Where to?"
	_clear_body()
	for d in destinations():
		var plan := plan_ride(d.pos)
		if plan.is_empty():
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(_text(d.name, 21, Color.WHITE))
		info.add_child(_text("%.1f km  ·  $%d" % [plan.length / 1000.0, plan.fare], 17, Color(0.72, 0.74, 0.8)))
		row.add_child(info)
		var go := _button("GO", func(): choose(d))
		go.custom_minimum_size = Vector2(96, 52)
		row.add_child(go)
		_panel_body.add_child(row)
	if _panel_body.get_child_count() == 0:
		_panel_body.add_child(_text("Nowhere to go from here.", 20, Color.WHITE))


## The chosen trip and its fare: RIDE or SKIP, or pick somewhere else.
func _show_confirm() -> void:
	if _panel == null:
		return
	_panel_mode = "confirm"
	_panel_height(480)
	_panel_title.text = "TAXI  ·  " + trip.name
	_clear_body()
	var mins := maxi(1, int(round(trip.length / CRUISE / 60.0 * 1.3)))
	_panel_body.add_child(_text("%.1f km  ·  about %d min" % [trip.length / 1000.0, mins], 19, Color(0.72, 0.74, 0.8)))
	var fare := _text("Fare  $%d" % trip.fare, 40, Color(0.55, 0.95, 0.5))
	_panel_body.add_child(fare)
	var cost := skip_fare(trip.fare)
	var short: bool = game.cash < trip.fare
	if short:
		_panel_body.add_child(_text("\"That's $%d and you've got $%d. Walk, friend.\"" % [trip.fare, game.cash], 19, Color(1.0, 0.55, 0.45)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var go := _button("RIDE  $%d" % trip.fare, func(): ride(), true)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.custom_minimum_size = Vector2(0, 64)
	go.disabled = short
	row.add_child(go)
	var sk := _button("SKIP  $%d" % cost, func(): skip())
	sk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sk.custom_minimum_size = Vector2(0, 64)
	sk.disabled = game.cash < cost
	row.add_child(sk)
	_panel_body.add_child(row)
	_panel_body.add_child(_text("Skip: pay +%d%% and be there now." % int(round((SKIP_MARKUP - 1.0) * 100.0)), 16, Color(0.72, 0.74, 0.8)))
	_panel_body.add_child(_button("SOMEWHERE ELSE", _show_choices))


func _show_bar() -> void:
	_hide_ui()
	_update_bar()


func _update_bar() -> void:
	if _bar == null or trip.is_empty():
		return
	var left := 0.0
	var path: PackedVector3Array = cab.path
	var at: Vector3 = cab.global_position
	for i in range(cab.path_index, path.size()):
		left += Vector2(path[i].x - at.x, path[i].z - at.z).length()
		at = path[i]
	_bar_text.text = "%s  ·  %.1f km  ·  $%d" % [trip.name, left / 1000.0, fare_so_far()]
	var cost := skip_fare(trip.fare)
	_bar_skip.text = "SKIP  $%d" % cost
	_bar_skip.disabled = game.cash < cost or state != State.RIDING


func _panel_height(h: float) -> void:
	_panel.offset_top = -h * 0.5
	_panel.offset_bottom = h * 0.5


func _clear_body() -> void:
	for c in _panel_body.get_children():
		_panel_body.remove_child(c)
		c.queue_free()


func _say(line: String) -> void:
	if game.hud != null:
		game.hud.show_dialogue(DRIVER, line)


## On foot, alive, in control, outside and not mid-respawn.
func _free_on_foot() -> bool:
	var p = game.player
	if p == null or p.vehicle != null or p.dead or not p.controllable or game.respawning:
		return false
	return game.interiors == null or game.interiors.state == game.interiors.State.OUTSIDE


# --- Widgets ---------------------------------------------------------------------

func _frame() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.09, 0.9)
	style.set_corner_radius_all(16)
	style.set_border_width_all(3)
	style.border_color = Color(1.0, 0.85, 0.3, 0.8)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	return panel


## A solid button that reads on the dark panel and over the street; `main`
## is the taxi-yellow one (TAXI, RIDE).
func _button(text: String, on_press: Callable, main := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 56)
	b.add_theme_font_size_override("font_size", 20)
	var base := Color(1.0, 0.8, 0.15) if main else Color(0.2, 0.23, 0.3)
	var looks := {"normal": base, "hover": base.lightened(0.12), "pressed": base.darkened(0.2),
		"disabled": Color(0.13, 0.14, 0.17)}
	for k in looks:
		var st := StyleBoxFlat.new()
		st.bg_color = looks[k]
		st.set_corner_radius_all(12)
		st.set_border_width_all(2)
		st.border_color = Color(0, 0, 0, 0.5) if main else Color(1, 1, 1, 0.18)
		b.add_theme_stylebox_override(k, st)
	var ink := Color(0.08, 0.07, 0.04) if main else Color.WHITE
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, ink)
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.46, 0.5))
	if on_press.is_valid():
		b.pressed.connect(on_press)
	return b


func _text(t: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _anchor(control: Control, at: Vector2, rect: Rect2) -> void:
	control.anchor_left = at.x
	control.anchor_right = at.x
	control.anchor_top = at.y
	control.anchor_bottom = at.y
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.end.x
	control.offset_bottom = rect.end.y
