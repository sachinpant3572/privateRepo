extends CharacterBody3D
## Arcade car shared by the player, traffic and police.
## Steering is direction-based: the car turns toward a requested world
## direction (reversing when it points well behind), which suits a touch
## joystick under a top-down camera.

const MeshBuilder = preload("res://scripts/mesh_builder.gd")
const VehicleKit = preload("res://scripts/kits/vehicle_kit.gd")
const L = preload("res://scripts/layers.gd")
const Terrain = preload("res://scripts/terrain.gd")
const Breakables = preload("res://scripts/breakables.gd")

signal officer_deployed(car)
## A SCRIPT driver reached the end of its path.
signal path_done(car)

## SCRIPT drives a mission path; CHASER hunts the player like police do.
enum Driver { NONE, PLAYER, TRAFFIC, POLICE, SCRIPT, CHASER }

const COAST := 4.0
## How much of gravity's pull along a slope reaches the speed (the rest the
## engine and brakes take).
const SLOPE_PULL := 0.6
## Corner assist: a turn the stick asks for that is too tight at this speed
## slows the car to the speed at which it can turn on this radius (m).
const CORNER_RADIUS := 5.0
## Wheel steering (arrows, tilt): full lock aims this far (radians) off
## the nose, which _drive turns into full steer; seconds to reach it.
const WHEEL_ANGLE := 0.5
const STEER_IN := 0.3
## The tightest circle (m) any vehicle turns on, however slow.
const MIN_RADIUS := 3.5
## Seconds the player's car takes to build up (or shed) a turn, as a real
## body takes a moment to start rotating: no snap into the bend.
const YAW_IN := 0.18
const TRAFFIC_THROTTLE := 0.6
## Traffic never cruises faster than this (m/s), whatever the model.
const TRAFFIC_CRUISE := 13.0
## Traffic slows to this (m/s) within TRAFFIC_SLOW_ZONE (m) of a junction.
const TRAFFIC_TURN_SPEED := 6.5
const TRAFFIC_SLOW_ZONE := 16.0
## Traffic steers for the point this far (m) ahead along its lane.
const TRAFFIC_LOOKAHEAD := 9.0
## Seconds a scripted driver (taxi, getaway) waits behind something that
## does not move off before it goes round.
const SCRIPT_WAIT := 3.0
const POLICE_XRAY := Color(0.3, 0.55, 1.0, 0.6)

var driver := Driver.NONE
var is_police := false
## Body style from VehicleKit.KINDS; sets the model and the handling.
var kind := "sedan"
var body_color := Color(0.8, 0.15, 0.15)
var city
var occupant = null
var health := 100.0
var max_health := 100.0
## Tonnes (VehicleKit.HANDLING); collisions share speed and damage by it.
var mass := 1.5
var wrecked := false
var speed := 0.0 # signed, along the car's forward axis

# Per-frame intent, written by whoever drives.
var desired_dir := Vector3.ZERO
var throttle := 0.0
var handbrake := false
var braking := false
## The player steers by the wheel (Controls.wheel_steering): no corner
## assist, and off the pedals the car rolls on rather than braking.
var _wheel := false
var _coast := false
## The wheel eased toward the arrows' full lock, as a thumb turns it.
var _steer_in := 0.0
## The heading's turn rate (rad/s) of the player's car, eased by YAW_IN.
var _yaw_rate := 0.0

var rng := RandomNumberGenerator.new()
## Bikes and scooters show their rider (see player.gd).
var shows_rider := false
## NPC sitting on a scooter (visible) and NPCs riding inside (hidden).
var rider = null
var passengers: Array = []
## SCRIPT driving: points to follow and the throttle to use.
var path := PackedVector3Array()
var path_index := 0
var script_throttle := 0.6
var max_speed := 24.0
var accel := 14.0
var turn_rate := 2.4
## Traffic drives from junction _prev_node to _next_node (plan node ids).
var _prev_node := -1
var _next_node := -1
## The street after _next_node, chosen on the approach, so a right turn onto
## a wide street can start at that street's lane, short of the junction.
var _after_node := -1
## The lane traffic drives in (0 the curb lane; see City.lane_point).
var lane := 0
var _stuck_time := 0.0
var _reverse_time := 0.0
## Traffic that touched another vehicle waits this long (random, so one of
## two cars nosing at each other goes first); below -1 it may yield again.
var _yield_time := -1.0
## Traffic backing off a wall: how long the last back-off was and the time
## since it ended. Hitting a wall again soon backs off further, so a car
## wedged against a median end gets the room to turn past it.
var _last_reverse := 0.0
var _since_reverse := 10.0
## The last wall or prop the car pressed against (its normal, flat): a
## scripted driver that backed off it drives along it for a moment.
var _wall_normal := Vector3.ZERO
var _wall_frame := -100
var _deployed := false
var _light_time := 0.0
var _lights: Array[MeshInstance3D] = []
var _model: MeshInstance3D
## Glass and paint shell, a child of _model drawn with the glossy material.
var _gloss: MeshInstance3D
var _ahead: RayCast3D
var _beams: MeshInstance3D
## The lamps' own glow on the car, lit with the headlights.
var _lamp_glow: MeshInstance3D
## A real spot light in front, live only while Graphics gives this car one of
## the few real lights its quality allows (set_real_light).
var _real_light: SpotLight3D
## A police car's light bar throws red and blue round it, with the real light.
var _bar_light: OmniLight3D
var _size := Vector3.ONE
var _skid_dist := 0.0
var _smoke_time := 0.0
var _splash_time := 0.0
var _hard_brake := false
var _game
## Handling of this kind: VehicleKit.spec(kind).
var _spec: Dictionary
## Body roll (x) and pitch (y) shown on the model, smoothed.
var _tilt := Vector2.ZERO
## The ground's slope under the car: (roll, pitch) in radians, eased.
var _slope := Vector2.ZERO
## Real forward speed last frame (m/s), for the pitch.
var _moved := 0.0
## Riders leaned with a two-wheeler last frame (straightened when they leave).
var _leaning: Array = []


func _ready() -> void:
	add_to_group("vehicles")
	motion_mode = MOTION_MODE_FLOATING
	collision_layer = L.VEHICLES
	collision_mask = L.WORLD | L.PROPS | L.VEHICLES | L.CHARACTERS
	if is_police:
		kind = "police"
	_spec = VehicleKit.spec(kind)
	max_speed = _spec.max_speed
	accel = _spec.accel
	turn_rate = _spec.turn
	mass = _spec.mass
	max_health = _spec.health
	health = max_health
	shows_rider = _spec.rider
	var size: Vector3 = _spec.size
	_size = size
	_game = get_tree().get_first_node_in_group("game")
	# A box with its corners cut, so clipping a post or a building corner
	# glances the car aside instead of stopping it as a head-on hit.
	var shape := CollisionShape3D.new()
	var hx := size.x * 0.5 + 0.05
	var hz := size.z * 0.5 + 0.05
	var cut := minf(0.45, hx * 0.5)
	var points := PackedVector3Array()
	for y in [-0.6, 0.6]:
		for c in [Vector2(hx - cut, -hz), Vector2(hx, -hz + cut), Vector2(hx, hz - cut), Vector2(hx - cut, hz),
				Vector2(cut - hx, hz), Vector2(-hx, hz - cut), Vector2(-hx, cut - hz), Vector2(cut - hx, -hz)]:
			points.append(Vector3(c.x, y, c.y))
	var hull := ConvexPolygonShape3D.new()
	hull.points = points
	shape.shape = hull
	shape.position.y = 0.6
	add_child(shape)
	_ahead = RayCast3D.new()
	_ahead.position = Vector3(0, 0.7, -size.z * 0.5 - 0.2)
	_ahead.target_position = Vector3(0, 0, -8.0)
	_ahead.collision_mask = L.VEHICLES | L.CHARACTERS
	add_child(_ahead)
	_ahead.add_exception(self)
	_build_model()


func _physics_process(delta: float) -> void:
	if driver == Driver.NONE and speed == 0.0 and velocity == Vector3.ZERO and _lights.is_empty():
		return # parked: nothing to simulate until something drives or hits it
	desired_dir = Vector3.ZERO
	throttle = 0.0
	handbrake = false
	braking = false
	_wheel = false
	_coast = false
	if not wrecked:
		match driver:
			Driver.PLAYER:
				_player_input()
			Driver.TRAFFIC:
				_traffic_ai()
			Driver.POLICE, Driver.CHASER:
				_police_ai(delta)
			Driver.SCRIPT:
				_script_ai()
	_drive(delta)
	_flash_lights(delta)
	_effects(delta)
	_carry()


func has_ai_driver() -> bool:
	return driver in [Driver.TRAFFIC, Driver.POLICE, Driver.SCRIPT, Driver.CHASER]


## Drives along `points` (see City.route_lanes) at `throttle`, then stops
## and emits path_done.
func drive_path(points: PackedVector3Array, throttle_amount := 0.6) -> void:
	path = points
	path_index = 0
	script_throttle = throttle_amount
	driver = Driver.SCRIPT
	_stuck_time = 0.0
	_reverse_time = 0.0
	_since_reverse = 10.0
	_wall_normal = Vector3.ZERO
	# Skip the junction just behind us; drive on to the next one.
	var fwd := -global_basis.z
	while path_index < path.size() - 1:
		var to := path[path_index] - global_position
		if to.dot(fwd) >= 0.0 or Vector2(to.x, to.z).length() > 30.0:
			break
		path_index += 1


func _script_ai() -> void:
	if path_index >= path.size():
		braking = true
		return
	var target := path[path_index]
	var to := target - global_position
	to.y = 0.0
	if to.length() < 5.0:
		path_index += 1
		if path_index >= path.size():
			path_done.emit(self)
		return
	desired_dir = to.normalized()
	if path_index > 0:
		# Follow the line from the last point a few metres ahead, as traffic
		# does, so a car that ran wide out of a corner comes back to its lane
		# instead of scraping along the kerb props toward the next point.
		var a := path[path_index - 1]
		var ab := target - a
		ab.y = 0.0
		if ab.length() > TRAFFIC_LOOKAHEAD:
			var t := clampf((global_position - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			var aim := a + ab * minf(1.0, t + TRAFFIC_LOOKAHEAD / ab.length())
			aim.y = global_position.y
			if aim.distance_to(global_position) > 0.5:
				desired_dir = (aim - global_position).normalized()
	throttle = script_throttle
	var dt := get_physics_process_delta_time()
	if _reverse_time > 0.0:
		# Pinned on a kerb prop after cutting a corner: back off as traffic
		# does, nose swinging toward the path (right, if it is dead ahead),
		# then carry on.
		_reverse_time -= dt
		_since_reverse = 0.0
		var side := signf((-global_basis.z).signed_angle_to(desired_dir, Vector3.UP))
		if side == 0.0:
			side = -1.0
		desired_dir = global_basis.z.rotated(Vector3.UP, 0.6 * side)
		throttle = 0.7
		return
	_since_reverse += dt
	var escaping := _since_reverse < 1.0 and _wall_normal != Vector3.ZERO
	if escaping:
		# Just backed off: go round the obstacle, along its face and a little
		# away (to the left of a face that is dead ahead, so a car stopped in
		# the lane is passed on the left).
		var along := desired_dir - _wall_normal * desired_dir.dot(_wall_normal)
		if along.length() < 0.3:
			along = _wall_normal.cross(Vector3.UP)
		desired_dir = (along.normalized() + _wall_normal * 0.5).normalized()
	var blocker: Object = _ahead.get_collider() if _ahead.is_colliding() else null
	braking = not escaping and blocker != null and blocker.get("driver") != Driver.PLAYER
	# Going nowhere under power (wheels turning against a wall) is stuck;
	# so is waiting SCRIPT_WAIT behind something that does not move off (a
	# stalled car, a body in the road). A second time soon after backs off
	# further.
	if get_real_velocity().length() < 1.0:
		_stuck_time += dt * (1.2 / SCRIPT_WAIT if braking else 1.0)
	else:
		_stuck_time = 0.0
	if _stuck_time > 1.2:
		_stuck_time = 0.0
		if braking and blocker is Node3D:
			var away: Vector3 = global_position - blocker.global_position
			_wall_normal = Vector3(away.x, 0.0, away.z).normalized()
		elif Engine.get_physics_frames() - _wall_frame > 5:
			_wall_normal = Vector3.ZERO # pinned on a car, not on that old wall
		_reverse_time = 1.2 if _since_reverse > 3.0 else minf(_last_reverse + 0.8, 3.2)
		_last_reverse = _reverse_time


## Keeps a scooter's rider in the saddle and passengers inside. Riders on
## two-wheelers (the player too) lean with the bike; anyone who got off
## since last frame is stood up straight.
func _carry() -> void:
	if rider != null and is_instance_valid(rider):
		rider.global_position = global_position
		rider.rotation.y = rotation.y
	for p in passengers:
		if is_instance_valid(p):
			p.global_position = global_position
	var leaning := []
	if shows_rider:
		for r in [rider, occupant]:
			if r != null and is_instance_valid(r):
				r.rotation.z = _tilt.x
				leaning.append(r)
	for r in _leaning:
		if is_instance_valid(r) and not leaning.has(r):
			r.rotation.z = 0.0
	_leaning = leaning


## The model's display name, e.g. "Vesper GT".
func model_name() -> String:
	return _spec.get("name", kind.capitalize())


## Everyone riding gets out (wrecks, mission ends).
func unload_all() -> void:
	if rider != null and is_instance_valid(rider):
		rider.rotation.z = 0.0
		rider.dismount(global_position - global_basis.x * 1.4)
	rider = null
	for p in passengers:
		if is_instance_valid(p):
			p.dismount(global_position + global_basis.x * 2.0)
	passengers.clear()


## The person responsible for what this car hits (for crime reporting).
func driver_node():
	return occupant if driver == Driver.PLAYER else null


func take_player(p) -> void:
	occupant = p
	driver = Driver.PLAYER
	if not wrecked:
		_skin(MeshBuilder.xray_material(), _gloss_xray(Color(1.0, 0.85, 0.25, 0.6)))


func release_player() -> void:
	if occupant != null and is_instance_valid(occupant):
		occupant.rotation.z = 0.0
	occupant = null
	driver = Driver.NONE
	update_beams()
	if not wrecked:
		_skin(MeshBuilder.material(), MeshBuilder.gloss_material())


## Drives as traffic, setting off from junction `from` towards `to` in
## lane `in_lane`.
func start_traffic(c, from: int, to: int, in_lane := 0) -> void:
	city = c
	driver = Driver.TRAFFIC
	_prev_node = from
	_next_node = to
	_after_node = -1
	lane = in_lane


## Hands a police car (or a stolen car left behind) back to normal traffic.
func join_traffic_here() -> void:
	var fwd := -global_basis.z
	var ahead: int = city.node_ahead(global_position, fwd)
	# Came from: the street out of `ahead` that points back past the car
	# (the junction nearest behind may not share a street with it).
	var behind := -1
	var best := 0.3
	if ahead >= 0:
		for m in city.next_nodes(ahead):
			var back: Vector3 = (city.node_pos(m) - city.node_pos(ahead)).normalized()
			if back.dot(-fwd) > best:
				best = back.dot(-fwd)
				behind = m
	driver = Driver.TRAFFIC
	_prev_node = behind
	_next_node = ahead
	_after_node = -1
	# The lane nearest the car.
	lane = 0
	if behind >= 0 and ahead >= 0:
		var best_d := INF
		for k in city.lane_count(behind, ahead):
			var d: float = Geometry3D.get_closest_point_to_segment_uncapped(global_position, city.lane_start(behind, ahead, k), city.lane_point(behind, ahead, k)).distance_to(global_position)
			if d < best_d:
				best_d = d
				lane = k


## Hit by another vehicle: `push` is already scaled by the two masses (see
## _handle_collisions); a hard shove costs up to 40% of our speed.
func bump(push: Vector3) -> void:
	velocity += push
	speed *= lerpf(1.0, 0.6, clampf(push.length() / 6.0, 0.0, 1.0))
	_damage(push.length())


func _player_input() -> void:
	handbrake = Input.is_action_pressed("sprint")
	var fwd := -global_basis.z
	var gas := Controls.gas()
	var brake := Controls.brake()
	var by_stick := Controls.stick_steers()
	if Controls.wheel_steering() or by_stick:
		_wheel = true
		var s := Controls.steer()
		if by_stick:
			var w := Controls.stick_wheel()
			s = clampf(w[0] + Input.get_axis("steer_left", "steer_right"), -1.0, 1.0)
			gas = maxf(gas, w[1])
			brake = maxf(brake, w[2])
		# Turning in takes STEER_IN seconds; letting go or turning back
		# is twice as quick.
		var rate := 1.0 / STEER_IN
		if signf(s) != signf(_steer_in) or absf(s) < absf(_steer_in):
			rate *= 2.0
		_steer_in = move_toward(_steer_in, s, rate * get_physics_process_delta_time())
		desired_dir = fwd.rotated(Vector3.UP, -_steer_in * WHEEL_ANGLE)
		throttle = gas
		if brake > 0.05:
			_pedal_brake(brake, _steer_in)
		else:
			_coast = gas < 0.05
		return
	# Stick: the car heads where the stick points; GAS floors it that way
	# (straight on with the stick at rest), BRAKE stops and reverses.
	var dir := Controls.world_move()
	throttle = dir.length()
	if throttle > 0.05:
		desired_dir = dir / throttle
	if gas > 0.05:
		throttle = maxf(throttle, gas)
		if desired_dir == Vector3.ZERO:
			desired_dir = fwd
	if brake > 0.05:
		_pedal_brake(brake, 0.0)


## The brake pedal: stops the car (still steering), then backs it up.
## `steer` turns the wheel while reversing (the tail swings that way).
func _pedal_brake(amount: float, steer: float) -> void:
	var fwd := -global_basis.z
	if speed > 0.5:
		throttle = 0.0
		if desired_dir == Vector3.ZERO:
			desired_dir = fwd
	else:
		throttle = amount
		desired_dir = (-fwd).rotated(Vector3.UP, steer * WHEEL_ANGLE)


func _traffic_ai() -> void:
	if _next_node < 0:
		throttle = 0.0
		return
	var target: Vector3 = city.lane_point(_prev_node, _next_node, lane)
	var near := Vector2(target.x - global_position.x, target.z - global_position.z).length()
	if near < TRAFFIC_SLOW_ZONE and _after_node < 0:
		_after_node = city.pick_turn(_prev_node, _next_node, rng)
	var turn_in := false
	if _after_node >= 0:
		var ls: Vector3 = city.lane_start(_next_node, _after_node, lane)
		turn_in = Vector2(ls.x - global_position.x, ls.z - global_position.z).length() < 4.0
	if near < 5.0 or turn_in:
		var nxt: int = _after_node if _after_node >= 0 else city.pick_turn(_prev_node, _next_node, rng)
		_prev_node = _next_node
		_next_node = nxt
		_after_node = -1
		# Keep to the same lane where the new street has it; now and then
		# take another.
		var lanes: int = city.lane_count(_prev_node, _next_node)
		lane = mini(lane, lanes - 1)
		if lanes > 1 and rng.randf() < 0.3:
			lane = rng.randi() % lanes
		target = city.lane_point(_prev_node, _next_node, lane)
	var to := target - global_position
	to.y = 0.0
	# Follow the lane line a few metres ahead rather than aiming straight at
	# the far junction, so a car that turned wide finds its own side of a
	# boulevard median again instead of cutting across it.
	var a: Vector3 = city.lane_start(_prev_node, _next_node, lane) if _prev_node >= 0 else global_position
	var ab := target - a
	ab.y = 0.0
	var aim := target
	if ab.length() > TRAFFIC_LOOKAHEAD:
		var t := clampf((global_position - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		# Far off the lane (a left turn across a boulevard), look nearer, so
		# the car swings out to its lane before running down it rather than
		# cutting the corner into the median's nose.
		var lane_at := a + ab * t
		var off := Vector2(global_position.x - lane_at.x, global_position.z - lane_at.z).length()
		var ahead := clampf(TRAFFIC_LOOKAHEAD - off, 2.0, TRAFFIC_LOOKAHEAD)
		aim = a + ab * minf(1.0, t + ahead / ab.length())
	aim.y = global_position.y
	desired_dir = (aim - global_position).normalized() if aim.distance_to(global_position) > 0.5 else to.normalized()
	throttle = minf(TRAFFIC_THROTTLE, TRAFFIC_CRUISE / max_speed)
	if to.length() < TRAFFIC_SLOW_ZONE:
		# Slow for the junction, so heavy, understeering models still make
		# the turn instead of running wide (onto a boulevard median).
		throttle = minf(throttle, TRAFFIC_TURN_SPEED / max_speed)
	elif ab.length() > 0.5 and (-global_basis.z).angle_to(ab) > 0.4:
		# Still coming round from the last junction: hold turn speed until
		# lined up with the new street, or a fast model runs wide mid-turn.
		throttle = minf(throttle, TRAFFIC_TURN_SPEED / max_speed)
	var dt := get_physics_process_delta_time()
	if _reverse_time > 0.0:
		# Ran into a wall or kerb prop (a wide model missing a corner): back
		# off, swinging the nose toward the lane, then carry on.
		_reverse_time -= dt
		_since_reverse = 0.0
		var side := signf((-global_basis.z).signed_angle_to(desired_dir, Vector3.UP))
		desired_dir = global_basis.z.rotated(Vector3.UP, 0.6 * side)
		throttle = 0.7
		return
	_since_reverse += dt
	_yield_time = maxf(_yield_time - dt, -2.0)
	braking = _ahead.is_colliding() or _yield_time > 0.0


func _police_ai(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var to: Vector3 = player.global_position - global_position
	to.y = 0.0
	var d := to.length()
	if _reverse_time > 0.0:
		_reverse_time -= delta
		desired_dir = global_basis.z.rotated(Vector3.UP, 0.6)
		throttle = 1.0
		return
	if player.vehicle == null and d < 9.0 and not _deployed:
		# Close to a player on foot: stop and send an officer (or a mission
		# chaser's crew) out.
		_deployed = true
		driver = Driver.NONE
		officer_deployed.emit(self)
		return
	desired_dir = to / maxf(d, 0.01)
	throttle = clampf(d / 15.0, 0.4, 1.0)
	# Stuck is going nowhere (pinned on a wall, speed can stay above 1).
	if get_real_velocity().length() < 1.0 and d > 6.0:
		_stuck_time += delta
	else:
		_stuck_time = 0.0
	if _stuck_time > 1.2:
		_stuck_time = 0.0
		_reverse_time = 1.0


## Handling, all from the kind's spec (VehicleKit.HANDLING): the power
## curve fades acceleration toward top speed, steering needs rolling wheels
## (steer_low) and fades at speed (steer_fade), grip sets how fast the
## velocity follows the heading (lower slides more, and rear-drive cars
## lose some under power), and brake and reverse are per model.
func _drive(delta: float) -> void:
	var fwd := -global_basis.z
	var target := 0.0
	var steer := 0.0
	var yaw := 0.0
	var pace := absf(speed)
	var corner := 0.0 # how much the corner assist brakes, 0..1
	if desired_dir != Vector3.ZERO:
		var angle := fwd.signed_angle_to(desired_dir, Vector3.UP)
		# Traffic backs up only to get off a wall; a sharp turn it takes
		# forward (reversing to it, it would back down the whole street).
		var backs := driver != Driver.TRAFFIC or _reverse_time > 0.0
		if absf(angle) > deg_to_rad(120.0) and speed < 3.0 and backs:
			target = -_spec.reverse * throttle
			angle = (-fwd).signed_angle_to(desired_dir, Vector3.UP)
		else:
			# Ease off for sharp corners so the car can make the turn.
			target = max_speed * throttle * lerpf(1.0, 0.45, absf(angle) / PI)
			# Corner assist for the player only: AI drivers pick their own
			# junction speeds.
			if driver == Driver.PLAYER and not handbrake and not _wheel:
				var mix := smoothstep(0.3, 0.9, absf(angle))
				var assisted := lerpf(target, _corner_speed(), mix)
				if assisted < target and assisted < pace:
					corner = mix
				target = minf(target, assisted)
		var grip_turn: float = clampf(pace / _spec.steer_low, 0.0, 1.0) * (1.0 - _spec.steer_fade * clampf(pace / max_speed, 0.0, 1.0))
		steer = clampf(angle * 2.0, -1.0, 1.0)
		var rate_want: float = steer * turn_rate * grip_turn * (1.6 if handbrake else 1.0)
		# The tyres hold only so much sideways pull (corner_g = v * yaw rate)
		# and the wheels turn only so far: at speed the arc widens. The
		# handbrake lets the tail come round past grip (a drift).
		var cap: float = minf(_spec.corner_g / maxf(pace, 0.1), pace / MIN_RADIUS + 0.3)
		rate_want = clampf(rate_want, -cap * (1.8 if handbrake else 1.0), cap * (1.8 if handbrake else 1.0))
		if driver == Driver.PLAYER:
			_yaw_rate = lerpf(_yaw_rate, rate_want, 1.0 - exp(-delta / YAW_IN))
		else:
			_yaw_rate = rate_want
		yaw = _yaw_rate * delta
		rotate_y(yaw)
	else:
		_yaw_rate = 0.0

	var rate: float = accel * (1.0 - _spec.power_fade * clampf(pace / max_speed, 0.0, 1.0))
	_hard_brake = false
	if desired_dir == Vector3.ZERO or _coast:
		rate = COAST
	elif signf(target) != signf(speed) and pace > 0.5:
		rate = _spec.brake
		_hard_brake = pace > 9.0
	elif corner > 0.0:
		rate = _spec.brake
	elif absf(target) < pace:
		rate = COAST * 2.0
	speed = move_toward(speed, target, rate * delta)
	if braking or handbrake:
		speed = move_toward(speed, 0.0, (_spec.brake if braking else 10.0) * delta)
	# Hills: slower up, faster down (none of it on the flat). A car stopped
	# with nobody on the gas stays put, as if on its parking brake, so a
	# parked car neither creeps downhill nor keeps simulating.
	if _slope.y != 0.0:
		if throttle == 0.0 and target == 0.0 and absf(speed) < 0.5:
			speed = 0.0
			if Vector2(velocity.x, velocity.z).length() < 0.3:
				velocity = Vector3.ZERO
		else:
			speed -= 9.8 * SLOPE_PULL * sin(_slope.y) * delta

	var want := -global_basis.z * speed
	var grip: float = _spec.drift if handbrake else _spec.grip
	# Power slides need power: none while the corner assist brakes.
	if corner == 0.0:
		grip *= 1.0 - _spec.slide * throttle * absf(steer) * clampf(pace / 10.0, 0.0, 1.0)
	velocity = Vector3(velocity.x, 0.0, velocity.z).lerp(want, clampf(grip * delta, 0.0, 1.0))
	var before := velocity
	move_and_slide()
	global_position.y = Terrain.height(global_position.x, global_position.z)
	_ground_slope(delta)
	# Tilt follows how the body really moves, so a car pinned against a
	# wall with the throttle down stays level.
	var moved := get_real_velocity().dot(-global_basis.z)
	_body_tilt(delta, moved * yaw / delta, (moved - _moved) / delta)
	_moved = moved
	_handle_collisions(before)


## Speed (m/s) at which this model's heading turns as fast as a car on a
## CORNER_RADIUS circle at full lock: v = R * turn * (1 - steer_fade * v /
## max_speed), solved for v, and no faster than its tyres hold that
## circle (v² / R = corner_g). The path is tighter than R, since the velocity
## lags the heading by the model's grip.
func _corner_speed() -> float:
	var k: float = CORNER_RADIUS * turn_rate
	return minf(k / (1.0 + k * _spec.steer_fade / max_speed), sqrt(_spec.corner_g * CORNER_RADIUS))


## Tilts the model: cars roll out of turns and pitch back under power and
## forward under braking, tall ones more; two-wheelers lean into turns.
## `lateral` is the sideways acceleration (m/s², positive turning left).
func _body_tilt(delta: float, lateral: float, forward: float) -> void:
	var roll: float = clampf(-lateral * _spec.roll, -0.09, 0.09)
	var pivot := Vector3(0, 0.45, 0) # about the axles
	if _spec.lean > 0.0:
		roll = clampf(atan(lateral / 9.8) * _spec.lean, -0.5, 0.5)
		pivot = Vector3.ZERO # about the tyres' contact line
	var pitch: float = clampf(forward * _spec.pitch, -0.06, 0.05)
	_tilt = _tilt.lerp(Vector2(roll, pitch), 1.0 - exp(-7.0 * delta))
	var b := Basis.from_euler(Vector3(_tilt.y, 0.0, _tilt.x))
	var lie := Basis.from_euler(Vector3(_slope.y, 0.0, _slope.x))
	_model.transform = Transform3D(lie, Vector3.ZERO) * Transform3D(b, pivot - b * pivot)


## The ground's slope along and across the car (it lies on the hill).
func _ground_slope(delta: float) -> void:
	var n := Terrain.normal(global_position.x, global_position.z)
	var want := Vector2.ZERO
	if n.y < 0.9999:
		var fwd := -global_basis.z
		var right := global_basis.x
		want = Vector2(atan(-(n.x * right.x + n.z * right.z) / n.y), atan(-(n.x * fwd.x + n.z * fwd.z) / n.y))
	_slope = _slope.lerp(want, 1.0 - exp(-10.0 * delta))
	if _slope.length_squared() < 1e-8:
		_slope = Vector2.ZERO


func _handle_collisions(before: Vector3) -> void:
	# move_and_slide can report one body several times a frame; it is one hit.
	var struck := []
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var other := col.get_collider()
		if other != null and other.has_method("hit_by_vehicle"):
			if before.length() > 2.5 and not other.dead:
				Fx.hit(other.global_position, true, driver == Driver.PLAYER)
			other.hit_by_vehicle(self, before.length())
			continue
		if before.length() > Breakables.MIN_SPEED and not Breakables.prop_of(col).is_empty():
			# A lamp post, small tree, hydrant or bin: it goes down, the car
			# carries on with most of its speed.
			var keep := Breakables.smash(col, before, driver == Driver.PLAYER)
			velocity = before * keep
			speed *= keep
			_damage(1.0)
			continue
		var impact := absf(before.dot(col.get_normal()))
		if not (other != null and other.has_method("bump")):
			_wall_normal = Vector3(col.get_normal().x, 0.0, col.get_normal().z).normalized()
			_wall_frame = Engine.get_physics_frames()
		if driver == Driver.TRAFFIC:
			if other != null and other.has_method("bump"):
				if _yield_time < -1.0:
					_yield_time = rng.randf_range(0.3, 2.0)
			elif impact > 2.0 and _reverse_time <= 0.0 and before.dot(-global_basis.z) > 0.0:
				_reverse_time = 1.2 if _since_reverse > 3.0 else minf(_last_reverse + 0.8, 3.2)
				_last_reverse = _reverse_time
		# A floating body keeps its velocity into a wall, which would count
		# the same crash again every frame it stays pressed in: it is one hit.
		# The car loses the speed the wall took off along its heading, but
		# keeps no more than is left along it (plus the lag of the velocity
		# behind it under power): a head-on stop is a stop, a scrape or a
		# drift into a wall costs little, and pinned, `speed` stays low.
		if not (other != null and other.has_method("bump")) and velocity.dot(col.get_normal()) < 0.0:
			var along := absf(velocity.dot(-global_basis.z))
			velocity = velocity.slide(col.get_normal())
			var left := absf(velocity.dot(-global_basis.z))
			var kept: float = maxf(left + accel / _spec.grip + 0.5, absf(speed) - (along - left))
			speed = signf(speed) * minf(absf(speed), kept)
		if impact < 4.0 or struck.has(other):
			continue
		struck.append(other)
		var players: bool = driver == Driver.PLAYER or (other != null and other.get("driver") == Driver.PLAYER)
		Fx.crash(col.get_position(), impact, players)
		if other != null and other.has_method("bump"):
			# Share by mass (equal masses: half the speed kept, 0.6 of the
			# impact as damage and push, as for walls): the lighter vehicle
			# loses more speed, takes more damage and is shoved further.
			var m: float = other.mass
			var mine := mass / (mass + m)
			speed *= mine
			_damage(impact * 1.2 * (1.0 - mine))
			other.bump(before * 1.2 * mine)
		else:
			_damage(impact * 0.6)


func _damage(amount: float) -> void:
	if wrecked:
		return
	health -= amount
	if health > 0.0:
		return
	wrecked = true
	unload_all()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.11, 0.1)
	_skin(mat, mat)
	if driver == Driver.PLAYER and occupant != null:
		occupant.exit_vehicle(true)
	driver = Driver.NONE


func _flash_lights(delta: float) -> void:
	if _lights.is_empty():
		return
	var on := not wrecked and (driver == Driver.POLICE or (_deployed and Wanted.level > 0))
	_light_time += delta
	var phase := int(_light_time * 4.0) % 2 == 0
	_lights[0].visible = on and phase
	_lights[1].visible = on and not phase
	if _bar_light != null:
		_bar_light.visible = on and _real_light.visible
		_bar_light.light_color = Color(1.0, 0.12, 0.1) if phase else Color(0.15, 0.35, 1.0)


## Skid marks and tyre smoke when drifting or braking hard, splashes on wet
## roads, smoke from a damaged engine, and headlights after dark.
func _effects(delta: float) -> void:
	var v := Vector3(velocity.x, 0.0, velocity.z)
	var fwd := -global_basis.z
	var moving := v.length()
	var slip := 0.0
	if moving > 6.0:
		slip = absf(fwd.signed_angle_to(v / moving * signf(speed if speed != 0.0 else 1.0), Vector3.UP))
	var skidding := not shows_rider and ((handbrake and moving > 6.0) or (slip > 0.3 and moving > 8.0) or _hard_brake)
	if skidding:
		_skid_dist += moving * delta
		if _skid_dist > 0.6:
			_skid_dist = 0.0
			for x in [-_size.x * 0.42, _size.x * 0.42]:
				Fx.skid(global_transform * Vector3(x, 0, _size.z * 0.32), v)
		_smoke_time -= delta
		if _smoke_time <= 0.0:
			_smoke_time = 0.12
			Fx.smoke(global_transform * Vector3(0, 0.3, _size.z * 0.4), 0.8)
	if _game != null and _game.atmosphere.wetness > 0.4 and moving > 7.0:
		_splash_time -= delta
		if _splash_time <= 0.0:
			_splash_time = 0.16
			Fx.splash(global_transform * Vector3(_size.x * 0.45 * (1.0 if randf() < 0.5 else -1.0), 0.1, _size.z * 0.3))
	if health < max_health * 0.45:
		_smoke_time -= delta
		if _smoke_time <= 0.0:
			_smoke_time = 0.35 if not wrecked else 0.2
			Fx.smoke(global_transform * Vector3(0, 1.0, -_size.z * 0.3), 0.9 if not wrecked else 1.4)
	update_beams()


## Headlights on at night while someone drives (or the car is out on a job);
## also called by the settings preview, which runs with the game paused.
func update_beams() -> void:
	if _beams != null:
		var on := headlights_on()
		_lamp_glow.visible = on
		# A real light draws its own cone on the road; the painted beams are
		# for the cars further off that have none.
		_beams.visible = on and (_real_light == null or not _real_light.visible)


## True while the headlights are on: at night, with someone driving (or the
## car out on a job), and not wrecked.
func headlights_on() -> bool:
	return not wrecked and (driver != Driver.NONE or _deployed) and _game != null and _game.atmosphere.night_amount() > 0.05


## Gives this car a real headlight (lights the road, kerbs, walls and people
## in front of it) or takes it away. `energy` follows how dark it is.
func set_real_light(on: bool, energy := 0.0, shadow := false) -> void:
	if on and _real_light == null:
		_real_light = SpotLight3D.new()
		_real_light.light_color = Color(1.0, 0.93, 0.78)
		_real_light.spot_range = 30.0
		_real_light.spot_angle = 32.0
		_real_light.spot_attenuation = 0.6
		_real_light.spot_angle_attenuation = 1.2
		_real_light.position = Vector3(0, 0.75 if not shows_rider else 0.95, -_size.z * 0.5 - 0.15)
		_real_light.rotation.x = deg_to_rad(-9.0)
		_real_light.light_specular = 0.4
		add_child(_real_light)
		if is_police:
			_bar_light = OmniLight3D.new()
			_bar_light.omni_range = 9.0
			_bar_light.omni_attenuation = 1.4
			_bar_light.position = Vector3(0, 1.7, 0.35)
			_bar_light.visible = false
			_model.add_child(_bar_light)
	if _real_light != null:
		_real_light.visible = on
		_real_light.light_energy = energy
		_real_light.shadow_enabled = on and shadow
		if _bar_light != null:
			_bar_light.light_energy = energy * 0.3
			if not on:
				_bar_light.visible = false
	update_beams()


func _build_model() -> void:
	var mb := MeshBuilder.new()
	var gloss := MeshBuilder.new()
	VehicleKit.build(mb, kind, body_color, gloss)
	_model = mb.make_instance()
	_gloss = gloss.make_instance()
	_model.add_child(_gloss)
	_skin(MeshBuilder.material(), MeshBuilder.gloss_material())
	if is_police:
		_skin(MeshBuilder.xray_material(POLICE_XRAY), _gloss_xray(POLICE_XRAY))
	add_child(_model)
	# Beams and the red pool behind lie on the ground, over the hills too
	# (ground_glow_material); the lamps' own glow rides on the car.
	var ground := MeshBuilder.new()
	var glow := MeshBuilder.new()
	var head := Color(0.6, 0.55, 0.38)
	var lamps := [0.0] if shows_rider else [-_size.x * 0.33, _size.x * 0.33]
	for x in lamps:
		ground.light_beam(Vector3(x, 0.05, -_size.z * 0.5), Vector3.FORWARD, 13.0, 3.2, head, 5)
		glow.light_pool(Vector3(x, 0.7, -_size.z * 0.5 - 0.1), Vector2(0.5, 0.35), Color(1.0, 0.95, 0.8))
	ground.light_pool(Vector3(0, 0.08, _size.z * 0.5 + 0.6), Vector2(_size.x * 0.7, 1.2), Color(0.5, 0.05, 0.04))
	_beams = ground.make_instance()
	_beams.material_override = MeshBuilder.ground_glow_material()
	_beams.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The shader moves the beams up or down to the ground, off their box.
	_beams.extra_cull_margin = 4.0
	_beams.visible = false
	add_child(_beams)
	_lamp_glow = glow.make_instance()
	_lamp_glow.material_override = MeshBuilder.glow_material()
	_lamp_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lamp_glow.visible = false
	add_child(_lamp_glow)
	if is_police:
		for i in 2:
			var light := MeshInstance3D.new()
			var bar := BoxMesh.new()
			bar.size = Vector3(0.52, 0.12, 0.26)
			light.mesh = bar
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = Color(0.9, 0.1, 0.1) if i == 0 else Color(0.1, 0.3, 1.0)
			light.material_override = mat
			light.position = Vector3(-0.31 if i == 0 else 0.31, 1.465, 0.35)
			_model.add_child(light) # rolls with the body
			_lights.append(light)


## Materials for the matte body and its glossy glass/paint shell (both get
## stencil x-ray together, so the whole car shows through buildings).
func _skin(body: Material, shell: Material) -> void:
	_model.material_override = body
	_gloss.material_override = shell


static var _gloss_xrays := {}


## The glossy material with the same stencil x-ray as MeshBuilder.xray_material.
static func _gloss_xray(color: Color) -> StandardMaterial3D:
	if not _gloss_xrays.has(color):
		var mat: StandardMaterial3D = MeshBuilder.gloss_material().duplicate()
		mat.stencil_mode = BaseMaterial3D.STENCIL_MODE_XRAY
		mat.stencil_color = color
		_gloss_xrays[color] = mat
	return _gloss_xrays[color]
