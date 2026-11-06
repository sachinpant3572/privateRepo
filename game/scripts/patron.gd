extends "res://scripts/humanoid.gd"
## Someone inside a place (interiors.gd). Staff stay at their post doing
## their gesture. Customers work through their stops: walk a spot's path
## from the hub, do something there (browse a shelf, pay at the till, sit
## and eat), walk back to the hub, and after the last stop go out of the
## door and are freed. Hit them and they run out (and the shopkeeper calls
## the police: one star).
##
## Everyone inside listens (Senses): a fight or a crash makes customers stop
## and look, film or phone it in, or (the timid) hurry out of the door;
## staff hold their post and look, call it in, duck or cower.
##
## Positions are world space; the room kit's spots are room space, so the
## interior manager hands them over with `origin` added.

signal left(who)

const WALK := 1.5
const ARRIVE := 0.3
## Seats sit inside benches and chairs: the last step is a slide.
const SLIDE_TIME := 0.45

enum Step { WALK, ACT, OUT }

## Staff never move; `gesture` is what they do.
var staff := false:
	set(v):
		staff = v
		category = "shopkeeper" if v else "general"
var origin := Vector3.ZERO
var hub := Vector3.ZERO
var door := Vector3.ZERO
## [{spot, time}]: spot is an InteriorKit spot (room space).
var stops: Array = []
## Seconds spent walking without getting anywhere (tests read it).
var stuck_time := 0.0

var _step := Step.WALK
var _path: Array = []
var _stop: Dictionary = {}
var _act_left := 0.0
var _slide := -1.0
var _slide_from := Vector3.ZERO
var _slide_to := Vector3.ZERO
var _slide_yaw := 0.0
## The slide is out of a seat (true) or into one.
var _slide_out := false
var _last_pos := Vector3.ZERO
var _fleeing := false
## The player hit this one and the crime has been reported.
var _reported := false

## Reactions that stop a customer where they stand.
const HALT := ["look", "film", "call", "cheer", "shout", "duck", "cower", "hands_up", "startle"]


func _ready() -> void:
	super()
	add_to_group("patrons")
	walk_speed = WALK
	var h := hash(get_instance_id()) % 10
	personality = "calm" if h < 5 else ("curious" if h < 7 else ("timid" if h < 9 else "brave"))
	listen()


## Seats are inside benches and chairs: no collisions at all, or the body
## would be pushed back out.
func _set_seated_layers() -> void:
	collision_layer = 0
	collision_mask = 0


## People inside walk through each other; the player still bumps them.
func _set_standing_layers() -> void:
	collision_layer = L.CHARACTERS
	collision_mask = L.WORLD


## Starts the next stop, or heads for the door after the last one.
func next_stop() -> void:
	sitting = false
	gesture = ""
	if stops.is_empty() or _fleeing:
		_step = Step.OUT
		_path = [hub, door]
		return
	_stop = stops.pop_front()
	_step = Step.WALK
	_path = []
	for p in _stop.spot.path:
		_path.append(origin + p)


## Already sitting at `spot` (people there when the player walks in).
func seat_now(spot: Dictionary, seconds: float) -> void:
	_stop = {"spot": spot, "time": seconds}
	global_position = origin + spot.pos
	rotation.y = spot.yaw
	_begin_act()


func is_seated() -> bool:
	return sitting


func _think(delta: float) -> void:
	if staff:
		velocity = Vector3.ZERO
		return
	if reaction in HALT and _slide < 0.0 and not sitting and _step != Step.ACT:
		# Stops dead to watch.
		walk(Vector3.ZERO, 0.0, delta)
		face(reaction_pos - global_position, delta)
		return
	if _slide >= 0.0:
		_slide += delta / SLIDE_TIME
		var k := minf(_slide, 1.0)
		global_position = _slide_from.lerp(_slide_to, smoothstep(0.0, 1.0, k))
		rotation.y = lerp_angle(rotation.y, _slide_yaw, minf(1.0, 10.0 * delta))
		velocity = Vector3.ZERO
		if _slide >= 1.0:
			_slide = -1.0
			if _slide_out:
				_set_standing_layers()
			else:
				_begin_act()
		return
	match _step:
		Step.ACT:
			velocity = Vector3.ZERO
			rotation.y = lerp_angle(rotation.y, _stop.spot.yaw, minf(1.0, 8.0 * delta))
			_act_left -= delta
			if _act_left <= 0.0:
				_stand_up()
		Step.WALK, Step.OUT:
			_follow(delta)


func _follow(delta: float) -> void:
	if _path.is_empty():
		if _step == Step.OUT:
			left.emit(self)
			queue_free()
		return
	var target: Vector3 = _path[0]
	var to := target - global_position
	to.y = 0.0
	var last := _path.size() == 1
	if _step == Step.WALK and last and _stop.spot.kind in ["seat", "stool"] and to.length() < 1.8:
		# Slide into the seat.
		_path.clear()
		_slide = 0.0
		_slide_out = false
		_slide_from = global_position
		_slide_to = target
		_slide_yaw = _stop.spot.yaw
		_set_seated_layers()
		return
	if to.length() < ARRIVE:
		_path.pop_front()
		if _path.is_empty() and _step == Step.WALK:
			_begin_act()
		return
	style = "panic" if _fleeing else ""
	walk(to.normalized(), WALK * (2.4 if _fleeing else 1.0), delta)
	var moved := global_position.distance_to(_last_pos)
	stuck_time = stuck_time + delta if moved < WALK * delta * 0.2 else maxf(stuck_time - delta, 0.0)
	_last_pos = global_position


func _begin_act() -> void:
	_step = Step.ACT
	velocity = Vector3.ZERO
	_act_left = _stop.time
	match _stop.spot.kind:
		"seat", "stool":
			sitting = true
			gesture = "eat"
			_set_seated_layers()
		"browse":
			gesture = "browse"
		"till", "order":
			gesture = "pay"


func _stand_up() -> void:
	var kind: String = _stop.spot.kind
	var path: Array = _stop.spot.path
	var back: Array = []
	if kind in ["seat", "stool"] and path.size() > 1:
		# Slide back out of the seat (still without collisions) to the
		# last point of the path before it.
		sitting = false
		gesture = ""
		_slide = 0.0
		_slide_out = true
		_slide_from = global_position
		_slide_to = origin + path[path.size() - 2]
		_slide_yaw = _yaw_to(_slide_to)
		path = path.slice(0, path.size() - 1)
	elif kind in ["seat", "stool"]:
		sitting = false
		_set_standing_layers()
	# Back to the hub along the way in, then on to the next stop.
	for k in range(path.size() - 2, -1, -1):
		back.append(origin + path[k])
	back.append(hub)
	next_stop()
	if _step == Step.WALK:
		back.append_array(_path)
		_path = back
	else:
		back.append(door)
		_path = back


func _yaw_to(p: Vector3) -> float:
	var d := p - global_position
	return rotation.y if Vector2(d.x, d.z).length() < 0.01 else atan2(-d.x, -d.z)


func _on_hit(attacker) -> void:
	if attacker == null or not attacker.is_in_group("player") or _reported:
		return
	_reported = true
	Wanted.report_crime(1)
	if staff:
		_fleeing = true
		gesture = "cower"
		return
	_leave()


## Indoors nobody runs over to a scene: staff keep to their post, and
## customers who would run or keep away leave by the door instead.
func _choose_reaction(kind: String, near: bool, source, data: Dictionary) -> String:
	if _fleeing:
		return "ignore"
	var r := super(kind, near, source, data)
	match r:
		"approach", "help", "investigate":
			return "look"
		"hurry":
			return "ignore"
		"flee", "avoid":
			if staff:
				return "cower" if Senses.danger(kind) >= 3 else "call"
	return r


func _on_reaction(_p: Dictionary) -> void:
	if not staff and reaction in ["flee", "avoid"]:
		_leave()


## A reaction gesture shows over the staff's work and a diner's meal.
func shown_gesture() -> String:
	return _act_gesture if _act_gesture != "" else super()


## Gives up the remaining stops and heads out of the door in a hurry.
func _leave() -> void:
	if _fleeing or staff:
		return
	_fleeing = true
	stops.clear()
	if sitting or (_slide >= 0.0 and not _slide_out):
		# Out of the seat the way they got in, then out of the door.
		_slide = -1.0
		_stand_up()
		return
	if _slide >= 0.0:
		# Already sliding out: keep the way back to the hub, then the door.
		var i := _path.find(hub)
		_path = (_path.slice(0, i + 1) if i >= 0 else [hub]) + [door]
		_step = Step.OUT
		return
	_set_standing_layers()
	_step = Step.OUT
	_path = [hub, door]
