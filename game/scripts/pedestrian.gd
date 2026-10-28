extends "res://scripts/humanoid.gd"
## Civilian who lives on the sidewalks. Each has a category (office worker,
## builder, tourist, gang member, elderly, jogger, shop worker, medic or just
## anyone) and a personality (Senses), which pick the look and gait, the
## things they stop to do (a phone call, a smoke, a chat, leaning on a wall,
## hailing a cab, a stretch, a photo) and how they react to what they see
## and hear. Attacked, they flee or, if brave, fight back.
##
## Besides the events Senses broadcasts (fights, crashes, screams), a
## staggered scan every 0.35-0.5 s notices states: a car coming at them or
## up on their sidewalk, a police car racing past, the wanted player in
## view, someone sprinting past, a body, rain.

enum State { WANDER, FLEE, FIGHT, REACT, PAUSE }

const HOSTILE := Color(1.0, 0.3, 0.25, 0.6)
## The street crowd by category, [name, weight].
const CROWD := [["general", 28], ["office", 16], ["worker", 10], ["tourist", 10], ["gang", 7], ["elderly", 10],
	["athlete", 8], ["shopkeeper", 5], ["medic", 6]]
## Things each category stops to do on the sidewalk (Rig gestures, plus
## "chat" with someone close by).
const PAUSES := {
	"general": ["call", "smoke", "wait", "lean_wall", "eat", "chat", "chat", "bench"],
	"office": ["call", "call", "wait", "hail", "chat", "chat", "bench"],
	"worker": ["smoke", "arms_crossed", "stretch", "eat", "chat", "chat"],
	"tourist": ["film", "point", "hail", "eat", "chat", "bench"],
	"gang": ["smoke", "lean_wall", "arms_crossed", "call", "chat", "chat"],
	"elderly": ["wait", "lean_wall", "call", "chat", "bench", "bench"],
	"athlete": ["stretch", "stretch", "wait"],
	"shopkeeper": ["smoke", "call", "lean_wall", "chat"],
	"medic": ["call", "wait", "smoke", "chat"],
}
## "bench" sits on a free street bench within this many metres (else waits).
const BENCH_REACH := 6.0
## The first stop comes this long after spawning, later ones PAUSE_EVERY
## apart (seconds).
const FIRST_PAUSE := Vector2(18.0, 45.0)
const PAUSE_EVERY := Vector2(25.0, 60.0)

var city
var state := State.WANDER
var state_time := 0.0
var threat = null
var brave := false
var loop_index := 0
var point_index := 0
var step := 1
## What the current pause is ("chat", or a gesture).
var pause_kind := ""
## The gait when nothing else changes it.
var base_style := ""
## Stepping round something on the sidewalk: seconds left, which side
## (+1 into the block, -1 toward the street) and how long they have been
## held up.
var _detour := 0.0
var _detour_side := 1.0
var _stuck := 0.0
var _rng := RandomNumberGenerator.new()
var _scan_clock := 0.0
var _pause_clock := 30.0
var _pause_goal := Vector3.ZERO
var _pause_walk := false
var _pause_face := Vector3.ZERO
var _chat_with = null
var _chat_lead := false
## The bench collider sat on (CollisionShape3D) while pause_kind is "bench".
var _bench = null
var _react_from := Vector3.ZERO
var _dodge_dir := Vector3.ZERO
var _rain_hurry := false
var _scream_at := 0.0
## Per source: when each state-like stimulus may be noticed again.
var _noticed := {}
var _seen_bodies := {}


func setup(c, rand: RandomNumberGenerator, loop: int, point: int) -> void:
	city = c
	loop_index = loop
	point_index = point
	step = 1 if rand.randf() < 0.5 else -1
	_rng.seed = rand.randi()
	category = _pick_category(rand)
	personality = _pick_personality(rand, category)
	brave = personality == "brave"
	look = CharacterKit.category_look(rand, category)
	# A "general" look can come out as scrubs, hi-vis or a suit: act the part.
	category = look.get("category", category)
	max_health = 40.0
	walk_speed = rand.randf_range(1.3, 1.9)
	run_speed = 5.2
	punch_damage = 7.0
	match category:
		"elderly":
			walk_speed = rand.randf_range(1.1, 1.35)
			run_speed = 3.2
			base_style = "elderly"
		"athlete":
			# An easy jog: quick enough to pass walkers, slow enough to stay
			# on the sidewalk loop like everyone else.
			walk_speed = rand.randf_range(2.0, 2.2)
			run_speed = 6.0
			base_style = "jog"
		"gang":
			walk_speed = rand.randf_range(1.25, 1.6)
			base_style = "swagger"
			punch_damage = 9.0
		"tourist":
			walk_speed = rand.randf_range(1.15, 1.6)
			base_style = "carry" if look.get("bag") == "shopping" else ""
		"office", "general":
			if look.get("bag", "") in ["", "crossbody"] and not look.has("phone") and rand.randf() < 0.2:
				base_style = "pockets"
	_scan_clock = rand.randf_range(0.0, 0.45)
	_pause_clock = rand.randf_range(FIRST_PAUSE.x, FIRST_PAUSE.y)


static func _pick_category(rand: RandomNumberGenerator) -> String:
	var total := 0
	for row in CROWD:
		total += row[1]
	var r := rand.randi() % total
	for row in CROWD:
		r -= row[1]
		if r < 0:
			return row[0]
	return "general"


## Personality, leaning by category: gangs and joggers run brave, the
## elderly timid, tourists curious.
static func _pick_personality(rand: RandomNumberGenerator, cat: String) -> String:
	var brave_p := 0.2
	var timid_p := 0.25
	var curious_p := 0.2
	match cat:
		"gang":
			brave_p = 0.5
			timid_p = 0.05
		"athlete", "worker":
			brave_p = 0.35
		"elderly":
			brave_p = 0.08
			timid_p = 0.45
		"tourist":
			curious_p = 0.4
	var r := rand.randf()
	if r < brave_p:
		return "brave"
	if r < brave_p + timid_p:
		return "timid"
	if r < brave_p + timid_p + curious_p:
		return "curious"
	return "calm"


func _ready() -> void:
	super()
	listen()


func flee_from(who) -> void:
	threat = who
	_set_state(State.FLEE)
	state_time = 8.0
	_react_from = who.global_position if who is Node3D else global_position
	_scream()


## Peds who fight the player show through buildings in red while they do.
func _set_state(value: State) -> void:
	var was := state
	state = value
	_detour = 0.0
	_detour_side = 1.0
	_stuck = 0.0
	if value != State.PAUSE:
		if sitting and _bench != null:
			_stand_from_bench()
		activity = ""
		pause_kind = ""
		_chat_with = null
		_bench = null
	if (was == State.FIGHT) != (value == State.FIGHT):
		set_xray(HOSTILE if value == State.FIGHT else Color(0, 0, 0, 0))


func can_perceive() -> bool:
	return super() and state != State.FLEE and state != State.FIGHT


func _think(delta: float) -> void:
	state_time -= delta
	_scan_clock -= delta
	if _scan_clock <= 0.0:
		_scan_clock = _rng.randf_range(0.35, 0.5)
		_scan()
	match state:
		State.WANDER:
			_pause_clock -= delta
			if _pause_clock <= 0.0:
				_try_pause()
			if state == State.WANDER:
				_wander(delta, walk_speed * (1.35 if _rain_hurry else 1.0))
		State.FLEE, State.FIGHT:
			if state_time <= 0.0 or not is_instance_valid(threat) or threat.dead:
				_set_state(State.WANDER)
				_rejoin_sidewalk()
				_wander(delta, walk_speed)
			elif state == State.FLEE:
				walk((global_position - threat.global_position).normalized(), run_speed, delta)
			else:
				var to: Vector3 = threat.global_position - global_position
				to.y = 0.0
				if not threat.visible:
					flee_from(threat)
				elif to.length() > 1.2:
					walk(to.normalized(), run_speed, delta)
				else:
					walk(Vector3.ZERO, 0.0, delta)
					face(to, delta)
					punch()
		State.REACT:
			_react(delta)
		State.PAUSE:
			if state_time <= 0.0 or (pause_kind == "chat" and not _chat_ok()):
				_set_state(State.WANDER)
				_wander(delta, walk_speed)
			else:
				_pause(delta)
	style = _gait()


## Along the sidewalk loop at `speed`, stepping round street furniture.
func _wander(delta: float, speed: float) -> void:
	var loop: PackedVector3Array = city.sidewalk_loops[loop_index]
	var target := loop[point_index]
	if global_position.distance_to(target) < 0.8:
		point_index = posmod(point_index + step, loop.size())
		_detour_side = 1.0
	var dir := target - global_position
	dir.y = 0.0
	dir = dir.normalized()
	# Walking straight at street furniture they would stand against it
	# for good: when held up, step sideways (and a little back, out of
	# pockets) round it. They try the building side first (loops run
	# anticlockwise, so dir x UP times `step` points into the block),
	# then the street side, but never more than 0.6 m off their line
	# toward the curb, which is 1.2 m away.
	var prev := loop[posmod(point_index - step, loop.size())]
	var line := Vector3(target.x - prev.x, 0.0, target.z - prev.z).normalized()
	var off := (global_position - prev).dot(line.cross(Vector3.UP) * float(step))
	var sideways := dir.cross(Vector3.UP) * _detour_side * float(step)
	var pushing := is_on_wall() and get_real_velocity().length() < speed * 0.3
	if _detour > 0.0:
		_detour -= delta
		if _detour_side < 0.0 and off < -0.6:
			_detour_side = 1.0
		elif _detour < 0.6 and is_on_wall() and get_real_velocity().dot(sideways) < speed * 0.3:
			_detour_side = -_detour_side
			_detour = 0.8
		dir = (dir.cross(Vector3.UP) * _detour_side * float(step) * 1.5 - dir * 0.5).normalized()
	elif pushing:
		_stuck += delta
		if _stuck > 0.3:
			_stuck = 0.0
			_detour = 0.8
	else:
		_stuck = 0.0
	walk(dir, speed, delta)


## Into the block from the current stretch of sidewalk (the street is the
## other way).
func _inward() -> Vector3:
	var loop: PackedVector3Array = city.sidewalk_loops[loop_index]
	var target := loop[point_index]
	var prev := loop[posmod(point_index - step, loop.size())]
	var line := Vector3(target.x - prev.x, 0.0, target.z - prev.z).normalized()
	return line.cross(Vector3.UP) * float(step)


## Turns round on the loop when the way ahead leads toward `pos`.
func _turn_away_from(pos: Vector3) -> void:
	var loop: PackedVector3Array = city.sidewalk_loops[loop_index]
	var ahead := loop[point_index] - global_position
	var danger := pos - global_position
	ahead.y = 0.0
	danger.y = 0.0
	if ahead.dot(danger) > 0.0:
		step = -step
		point_index = posmod(point_index + step, loop.size())


func _rejoin_sidewalk() -> void:
	if city != null and city.has_method("nearest_sidewalk"):
		var near: Array = city.nearest_sidewalk(global_position)
		loop_index = near[0]
		point_index = near[1]


func _gait() -> String:
	if state == State.FLEE or (state == State.REACT and reaction == "flee"):
		return "panic"
	if health < max_health * 0.4:
		return "limp"
	if _rain_hurry and (state == State.WANDER or reaction == "hurry"):
		return "rain"
	return base_style


# --- Reactions ------------------------------------------------------------------

func _on_reaction(p: Dictionary) -> void:
	_react_from = p.data.get("from", p.pos)
	_set_state(State.REACT)
	match reaction:
		"flee":
			_turn_away_from(_react_from)
			if p.kind != "scream":
				_scream()
		"avoid":
			_turn_away_from(_react_from)
		"dodge":
			_dodge_dir = global_basis.x * _action_side


func _on_reaction_end(was: String) -> void:
	if state != State.REACT:
		return
	_set_state(State.WANDER)
	if was in ["approach", "help", "dodge", "investigate"]:
		_rejoin_sidewalk()


## Moving for the reaction playing (the pose comes from humanoid.gd).
func _react(delta: float) -> void:
	var to := _react_from - global_position
	to.y = 0.0
	var d := to.length()
	match reaction:
		"flee":
			_wander(delta, run_speed)
		"hurry":
			_wander(delta, walk_speed * 1.5)
		"avoid":
			_wander(delta, walk_speed * 1.3)
		"dodge":
			velocity = _dodge_dir * 4.5 if clock - reacted_at < 0.4 else Vector3.ZERO
		"approach", "investigate":
			if d > 4.5:
				walk(to / d, walk_speed * 1.2, delta)
			else:
				velocity = Vector3.ZERO
				face(to, delta)
		"help":
			if d > 1.1:
				walk(to / d, minf(run_speed * 0.6, 3.2), delta)
			else:
				velocity = Vector3.ZERO
				if d > 0.05:
					face(to, delta)
				if shown_gesture() != "kneel":
					act_gesture("kneel", reaction_time)
		_:
			velocity = Vector3.ZERO
			if d > 0.5:
				face(to, delta)


func _scream() -> void:
	if clock < _scream_at:
		return
	_scream_at = clock + 6.0
	Senses.emit(get_tree(), "scream", global_position, self)


# --- Noticing states --------------------------------------------------------------

func _scan() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var me := global_position
	var wanted := Wanted.level > 0
	var player = tree.get_first_node_in_group("player")
	if player != null and player.visible and not player.dead and player.get("vehicle") == null:
		var pp: Vector3 = player.global_position
		var d := Vector2(pp.x - me.x, pp.z - me.z).length()
		if d < 3.5 and Vector2(player.velocity.x, player.velocity.z).length() > 5.5:
			_notice("sprint_past", pp, player, d, 4.0)
		if wanted and d < 18.0 and Senses.sees(self, pp):
			_notice("wanted", pp, player, d, 12.0)
	_scan_vehicles(tree, me, wanted)
	_scan_bodies(tree, me)
	var game = tree.get_first_node_in_group("game")
	var atm = game.get("atmosphere") if game != null else null
	var rain = atm.get("rain") if atm != null else null
	_rain_hurry = rain != null and float(rain) > 0.3 and Senses.choose(category, personality, "rain") == "hurry"


func _scan_vehicles(tree: SceneTree, me: Vector3, wanted: bool) -> void:
	for car in tree.get_nodes_in_group("vehicles"):
		if not car.visible:
			continue
		var p: Vector3 = me - car.global_position
		p.y = 0.0
		if absf(p.x) > 45.0 or absf(p.z) > 45.0:
			continue
		var d := p.length()
		var v: Vector3 = car.velocity
		v.y = 0.0
		var sp := v.length()
		if wanted and sp > 4.0 and car.get("is_police") == true:
			_notice("siren", car.global_position, car, d, 10.0)
		if d > 14.0 or sp < 2.5:
			continue
		# Where the car will pass closest, if it keeps going.
		var t := p.dot(v) / (sp * sp)
		var miss := p - v * t
		if t > 0.0 and t < 1.2 and miss.length() < 1.5:
			var away := miss.normalized() if miss.length() > 0.1 else v.cross(Vector3.UP).normalized()
			var side := 1.0 if away.dot(global_basis.x) >= 0.0 else -1.0
			perceive("car_threat", car.global_position, car, d, {"side": side})
		elif _on_my_sidewalk(car.global_position) and Senses.sees(self, car.global_position):
			_notice("car_on_sidewalk", car.global_position, car, d, 6.0)
		elif d < 2.6 and sp > 4.0:
			_notice("car_close", car.global_position, car, d, 5.0)


## True when `pos` is within a metre of the stretch of sidewalk this person
## walks (cars in the lane are at least two metres off it).
func _on_my_sidewalk(pos: Vector3) -> bool:
	var loop: PackedVector3Array = city.sidewalk_loops[loop_index]
	var a := loop[posmod(point_index - step, loop.size())]
	var b := loop[point_index]
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var ap := Vector2(pos.x - a.x, pos.z - a.z)
	var t := clampf(ap.dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return (ap - ab * t).length() < 1.0


func _scan_bodies(tree: SceneTree, me: Vector3) -> void:
	for h in tree.get_nodes_in_group("humanoids"):
		if not h.dead or h == self or not h.visible:
			continue
		var id: int = h.get_instance_id()
		if _seen_bodies.has(id):
			continue
		var d := Vector2(h.global_position.x - me.x, h.global_position.z - me.z).length()
		if d < 12.0 and Senses.sees(self, h.global_position):
			_seen_bodies[id] = true
			perceive("body", h.global_position, h.killer, d, {"body": h})


## perceive() for a state that lasts: once per source every `every` seconds.
func _notice(kind: String, pos: Vector3, source, distance: float, every: float) -> void:
	var key := "%s%d" % [kind, source.get_instance_id()]
	if clock < float(_noticed.get(key, -1.0)):
		return
	_noticed[key] = clock + every
	if _noticed.size() > 48:
		_noticed.clear()
	perceive(kind, pos, source, distance)


# --- Stopping on the sidewalk -------------------------------------------------------

func _try_pause() -> void:
	_pause_clock = _rng.randf_range(PAUSE_EVERY.x, PAUSE_EVERY.y)
	if gesture != "" or reaction != "" or not is_inside_tree():
		return
	var options: Array = PAUSES.get(category, PAUSES.general)
	pause_for(options[_rng.randi() % options.size()], _rng.randf_range(4.0, 9.0))


## Stops to do `what` (a PAUSES entry) for about `secs`; what needs a place
## or a partner falls back to waiting when there is none.
func pause_for(what: String, secs: float) -> void:
	_pause_walk = false
	_pause_face = Vector3.ZERO
	var inward := _inward()
	match what:
		"chat":
			var other = _chat_partner()
			if other == null:
				what = "wait"
			else:
				var mid: Vector3 = (global_position + other.global_position) * 0.5
				var across: Vector3 = (other.global_position - global_position)
				across.y = 0.0
				across = across.normalized() if across.length() > 0.05 else forward()
				other.start_chat(self, mid + across * 0.55, secs)
				_begin_pause("chat", secs)
				_chat_with = other
				_chat_lead = true
				_pause_goal = mid - across * 0.55
				_pause_walk = true
				return
		"lean_wall":
			var hit := _wall_toward(inward, 2.6)
			if hit.is_empty():
				what = "wait"
			else:
				_pause_goal = Vector3(hit.position.x, global_position.y, hit.position.z) - inward * 0.3
				_pause_walk = true
				_pause_face = -inward
		"bench":
			var b = _free_bench()
			if b == null:
				what = "wait"
			else:
				_bench = b
				b.set_meta("sitter", get_instance_id())
				_pause_goal = _bench_front(b)
				_pause_walk = true
				secs = _rng.randf_range(10.0, 20.0)
		"hail":
			_pause_face = -inward
		"film", "point":
			_pause_face = inward.rotated(Vector3.UP, _rng.randf_range(-0.6, 0.6))
	_begin_pause(what, secs)


func _begin_pause(what: String, secs: float) -> void:
	_set_state(State.PAUSE)
	pause_kind = what
	state_time = secs


## Another walker joins a chat: walks to `spot` and talks for `secs`.
func start_chat(other, spot: Vector3, secs: float) -> void:
	_begin_pause("chat", secs)
	_chat_with = other
	_chat_lead = false
	_pause_goal = spot
	_pause_walk = true
	_pause_face = Vector3.ZERO


func _chat_partner():
	for other in get_tree().get_nodes_in_group("perceivers"):
		if other == self or other.get("state") != State.WANDER or other.get("pause_kind") == null:
			continue
		if other.reaction != "" or other.gesture != "":
			continue
		if other.global_position.distance_squared_to(global_position) < 9.0:
			return other
	return null


func _chat_ok() -> bool:
	return is_instance_valid(_chat_with) and _chat_with.get("pause_kind") == "chat" and not _chat_with.dead


func _wall_toward(dir: Vector3, reach: float) -> Dictionary:
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space == null:
		return {}
	var from := global_position + Vector3(0, 1.0, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * reach, L.WORLD)
	return space.intersect_ray(q)


func _pause(delta: float) -> void:
	if _pause_walk:
		var to := _pause_goal - global_position
		to.y = 0.0
		if to.length() > 0.15 and not (is_on_wall() and get_real_velocity().length() < 0.2):
			walk(to.normalized(), walk_speed * 0.8, delta)
			return
		_pause_walk = false
	velocity = Vector3.ZERO
	if pause_kind == "bench":
		if not sitting:
			_sit_on_bench()
		elif not is_instance_valid(_bench) or _bench.disabled or collision_mask != L.WORLD \
				or Vector2(_bench.global_position.x - global_position.x, _bench.global_position.z - global_position.z).length() > 0.4:
			# Knocked off it (a knockdown resets the mask on getting up), or the bench is gone.
			_set_state(State.WANDER)
		return
	if pause_kind == "chat":
		var to: Vector3 = _chat_with.global_position - global_position
		to.y = 0.0
		if to.length() > 0.1:
			face(to, delta)
		# Take turns, about 2.6 s each: one talks while the other listens.
		var turn := (Engine.get_physics_frames() / 156) % 2 == 0
		activity = "talk" if turn == _chat_lead else "listen"
		return
	if _pause_face != Vector3.ZERO:
		face(_pause_face, delta)
	activity = pause_kind


## A street bench within BENCH_REACH nobody sits on and no car knocked
## down (its collider, a CollisionShape3D tagged "brk" by the prop kit), or
## null. One shape query, made only when deciding to sit.
func _free_bench():
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space == null:
		return null
	var sphere := SphereShape3D.new()
	sphere.radius = BENCH_REACH
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sphere
	q.transform = Transform3D(Basis.IDENTITY, global_position)
	q.collision_mask = L.PROPS | L.WORLD
	var best = null
	var best_d := INF
	for hit in space.intersect_shape(q, 24):
		var body = hit.collider
		if not body is CollisionObject3D:
			continue
		var owner_id: int = body.shape_find_owner(hit.shape)
		var shape = body.shape_owner_get_owner(owner_id)
		if not shape is CollisionShape3D or shape.disabled or not shape.has_meta("brk"):
			continue
		var info: Dictionary = shape.get_meta("brk")
		if info.get("kind", "") != "bench" or info.get("down", false):
			continue
		var by := instance_from_id(int(shape.get_meta("sitter", 0)))
		if by != null and by != self and by.get("_bench") == shape:
			continue
		var d := global_position.distance_squared_to(shape.global_position)
		if d < best_d:
			best_d = d
			best = shape
	return best


## Where to stand in front of bench `b` before sitting (the seat faces the
## bench's -z, away from the backrest).
func _bench_front(b) -> Vector3:
	var front: Vector3 = -b.global_basis.z
	front.y = 0.0
	var p: Vector3 = b.global_position + front.normalized() * 0.65
	return Vector3(p.x, global_position.y, p.z)


## Turns round and sits: the body moves onto the seat and stops colliding
## with props while there (the bench's collider covers the seat).
func _sit_on_bench() -> void:
	if not is_instance_valid(_bench) or _bench.disabled:
		_set_state(State.WANDER)
		return
	var front: Vector3 = -_bench.global_basis.z
	front.y = 0.0
	front = front.normalized()
	var seat: Vector3 = _bench.global_position - front * 0.05
	global_position = Vector3(seat.x, global_position.y, seat.z)
	rotation.y = atan2(-front.x, -front.z)
	collision_mask = L.WORLD
	sitting = true


func _stand_from_bench() -> void:
	sitting = false
	collision_mask = L.WORLD | L.PROPS | L.CHARACTERS | L.VEHICLES
	if is_instance_valid(_bench) and global_position.distance_to(_bench.global_position) < 1.0:
		global_position = _bench_front(_bench)


func _on_hit(attacker) -> void:
	if attacker == null:
		return
	if attacker.is_in_group("player"):
		Wanted.report_crime(1)
	threat = attacker
	_set_state(State.FIGHT if brave and health > 15.0 else State.FLEE)
	state_time = 8.0
	if state == State.FLEE:
		_react_from = attacker.global_position
		_scream()
