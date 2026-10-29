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
const GameLog = preload("res://scripts/game_log.gd")
const VehicleClasses = preload("res://scripts/kits/vehicle_classes.gd")
const CarDebris = preload("res://scripts/car_debris.gd")
const CarFire = preload("res://scripts/car_fire.gd")
const Emissions = preload("res://scripts/kits/vehicle_emissions.gd")
const Convertible = preload("res://scripts/convertible.gd")

signal officer_deployed(car)
## A SCRIPT driver reached the end of its path.
signal path_done(car)

## SCRIPT drives a mission path; CHASER hunts the player like police do.
enum Driver { NONE, PLAYER, TRAFFIC, POLICE, SCRIPT, CHASER }

const COAST := 4.0
## How fast (m/s) a car or person settles onto ground drawn under
## Terrain.height (_ground_drop).
const DROP_RATE := 1.5
## How much of gravity's pull along a slope reaches the speed (the rest the
## engine and brakes take).
const SLOPE_PULL := 0.6
## Corner assist: a turn the stick asks for that is too tight at this speed
## slows the car to the speed at which it can turn on this radius (m).
const CORNER_RADIUS := 5.0
## Wheel steering (arrows, tilt): full lock aims this far (radians) off
## the nose, which _drive turns into full steer; seconds to reach it.
const WHEEL_ANGLE := 0.5
const STEER_IN := 0.16
## Tyre scrub for the wheel schemes (arrows, tilt, on-screen wheel, and the
## stick when the view turns behind the car, which steers like one; 0.25.1,
## Sachin: "the vehicle turns are still stiff"): with gas held through a
## turn the car used to keep accelerating, and its circle grows with the
## square of speed, so every held turn ran wide. Now a turn at full lock
## holds the speed at which the tyres keep the car on a TURN_RADIUS circle
## (wider at part lock), and above it the tyres scrub off up to SCRUB m/s²,
## on or off the gas. The stick pointing where to go (fixed view) has the
## corner assist instead.
const TURN_RADIUS := 9.0
const SCRUB := 6.0
## The tightest circle (m) any vehicle turns on, however slow.
const MIN_RADIUS := 3.2
## Seconds the player's car takes to build up (or shed) a turn, as a real
## body takes a moment to start rotating: no snap into the bend.
const YAW_IN := 0.09
## Game grip: each model's corner_g (its real tyres) times this. Real road
## grip on these short city blocks felt stiff (0.21, Sachin: "the handling
## is very stiff now, especially on corners"); the models keep their order.
## 18-wheelers keep their own grip: a quicker yaw swings the trailer's tail
## into walls (_grip).
const CORNER_GRIP := 1.5
## The player's car grips harder still (0.23, Sachin: "The handling is still
## stiff around the corners"); traffic keeps CORNER_GRIP, so its junction
## speeds do not change.
const PLAYER_GRIP := 1.9
## Brake-and-steer drift (0.23, "allow drifting with direction and brake
## like other games offer"): brake while turning at least DRIFT_STEER of
## full lock above DRIFT_MIN (m/s) and the tail steps out; the car keeps
## sliding while the wheel stays turned, losing DRIFT_BLEED (m/s²), and
## DRIFT_BRAKE of the car's brake more at full brake. It ends below
## DRIFT_END or when the wheel straightens. Not on bicycles, motorbikes or
## trucks. Braking into a corner starts one, so the scrub must stay close
## to the brake: a flat 6 m/s² made every car brake alike in corners (0.24,
## "all cars take the same amount of time to brake").
const DRIFT_MIN := 9.0
const DRIFT_STEER := 0.35
const DRIFT_END := 5.0
const DRIFT_BLEED := 2.5
const DRIFT_BRAKE := 0.65
## Seconds the tail takes to step out or grip again.
const DRIFT_IN := 0.25
## How deep (m) another car must sink in before it is moved out
## (_handle_collisions), and the most it moves out each frame.
const OVERLAP := 0.08
const OVERLAP_STEP := 0.25
## Time constant (s) of the smoothed real motion (`motion`).
const MOTION_EASE := 0.12
## Traffic's speed (m/s) where no Traffic manager gives a street's limit.
const TRAFFIC_CRUISE := 13.0
## Traffic picks its turn within twice this (m) of a junction, or further
## at speed.
const TRAFFIC_SLOW_ZONE := 16.0
## Traffic steers for the point this far (m) ahead along its lane.
const TRAFFIC_LOOKAHEAD := 9.0
## Traffic driving (0.23): junction controls, limits and demand live in
## Traffic (a child of Population); the plan of a junction in TrafficPlan.
const TrafficPlan = preload("res://scripts/traffic_plan.gd")
const TrafficManager = preload("res://scripts/traffic.gd")
## Intelligent Driver Model (Treiber 2000): minimum gap (m), time headway
## (s, +0.4 in rain), comfortable braking (m/s²), and the range the kind's
## accel is scaled into (accel x 0.3, m/s²).
const IDM_S0 := 2.0
const IDM_T := 1.4
const IDM_B := 3.0
const IDM_ACCEL := Vector2(1.5, 3.5)
## Traffic looks again for the vehicle it follows every this many frames.
const IDM_SCAN := 3
## Junction speeds (m/s): a turn, and a U-turn.
const TURN_SPEED := 6.5
const TIGHT_TURN_SPEED := 4.5
## A full stop at a sign: seconds standing at the line.
const STOP_HOLD := 1.0
## Seconds held at a sign (or a dark signal) before a driver gives up
## waiting its turn and goes, and at a red before it decides the signal is
## stuck: no junction locks up for good.
const GRIDLOCK := 25.0
const RED_GIVE_UP := 90.0
## The slowest traffic eases to while a siren comes by (m/s).
const SIREN_CRAWL := 2.5
## Seconds stood behind something that never moves off before going round
## it: a wreck or a parked car, another driver (the player), traffic that
## isn't queued at a junction.
const BLOCK_WAIT := Vector3(3.0, 6.0, 10.0)
## Seconds a scripted driver (taxi, getaway) waits behind something that
## does not move off before it goes round.
const SCRIPT_WAIT := 3.0
## Below this share of max health a car burns, then explodes.
const FIRE_AT := 0.15
## Exhaust and tyres: how long a cold engine steams after starting (s), the
## gears it shifts through (petrol cars; trucks' diesels), the sideways
## slide (m/s) at which tyres start to mark, the length of each strip of
## mark (m), and how poor each district is (older cars gather there).
const COLD_START := 40.0
const GEARS := 5.0
const GEARS_DIESEL := 8.0
const SLIDE_MARK := 2.5
const MARK_STEP := 0.45
const POOR := {"wards": 0.8, "bayou": 0.6, "docks": 0.5, "brownstone": 0.35, "quarter": 0.3, "havana": 0.35, "chinatown": 0.3, "painted": 0.1, "beach": 0.05, "midtown": 0.15, "downtown": 0.1, "heights": 0.0}
## Impacts this hard throw a body panel off.
const PANEL_IMPACT := 12.0
## Dents reach this far (m) from the contact point.
const DENT_RADIUS := 1.2
const POLICE_XRAY := Color(0.3, 0.55, 1.0, 0.6)
const PLAYER_XRAY := Color(1.0, 0.85, 0.25, 0.6)

var driver := Driver.NONE
var is_police := false
## Body style from VehicleKit.KINDS; sets the model and the handling.
var kind := "sedan"
## Police cars keep this (their model has its own livery).
const DEFAULT_PAINT := Color(0.8, 0.15, 0.15)
var body_color := DEFAULT_PAINT
var city
var occupant = null
var health := 100.0
## Silhouette colour shown through buildings (the player's car, police);
## transparent means none. xray_shown: whether it is drawn now.
var xray_color := Color(0, 0, 0, 0)
var xray_shown := false
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
## In a brake-and-steer drift; `_slide` (0..1) is how far the tail is out.
var drifting := false
var _slide := 0.0
var _drift_brake := 0.0

var rng := RandomNumberGenerator.new()
## Bikes and scooters show their rider (see player.gd).
var shows_rider := false
## NPC sitting on a scooter (visible) and NPCs riding inside (hidden).
var rider = null
var passengers: Array = []
## Open cars (VehicleKit "convertible"): whether the soft top is up, and the
## node that holds it and seats the people seen inside (convertible.gd).
var roof_up := false
var convertible = null
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
var _bar_on := true
var _size := Vector3.ONE
var _smoke_time := 0.0
## Exhaust and tyres (kits/vehicle_emissions.gd): this car's engine as rolled
## when it first ran, its tailpipes, the tracks its tyres leave, and the
## state the puffs and marks run on.
var _emit := {}
var _outlets := []
var _tracks := {}
var _engine_on := false
var _cold := 0.0
var _prev_pace := 0.0
## Engine load 0..1, from how hard the car is speeding up.
var _load := 0.0
var _gear := 0
var _puff_time := 0.0
var _pops := 0
var _throttle_was := 0.0
var _pop_time := 0.0
var _tyre_time := 0.0
var _abs_dist := 0.0
## Per marking wheel: where its last strip ended, and whether it is marking.
var _mark_at := PackedVector3Array()
var _marking := PackedByteArray()
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
## How the car really moves (m/s), smoothed over MOTION_EASE: what the
## camera leads by and the speedometer reads. `velocity` is what the car
## asks for, which pinned against something flips every frame.
var motion := Vector3.ZERO
## This kind's class (VehicleClasses.of): ride, crumple, damage, rider throw.
var _cls: Dictionary
## How fast the body rolls and pitches on its springs (rad/s, as _tilt).
var _tilt_v := Vector2.ZERO
## The body's rise on its springs (m, up positive) and how fast it moves.
var _heave := 0.0
## The ground's drop under the car (_ground_drop): eased, wanted, where looked up.
var _drop := 0.0
var _drop_want := 0.0
var _drop_at := Vector2.INF
var _heave_v := 0.0
## The ground's vertical speed under the car last frame (m/s): a change is
## a bump or a crest the springs take.
var _ground_vy := 0.0
var _last_y := INF
## Yaw spin from an off-centre hit (rad/s), dying away.
var _spin := 0.0
## Dented copies of the cached meshes ([body, gloss] arrays and the
## untouched vertices), made on the first real hit.
var _dent_arrays: Array = []
var _dent_orig: Array = []
var _dent_at := -1.0
## Burning (CarFire child) below FIRE_AT of max health.
var _fire: Node3D
## Traffic driving: this driver's cruising speed as a share of the limit
## (Population sets it); the junction controller (Traffic, looked for
## every second until there is one); the street the state below is for,
## its speed limit and lane layout.
var drive_factor := 1.0
var _traffic = null
var _traffic_retry := 0
var _seg := Vector2i(-2, -2)
var _limit := TRAFFIC_CRUISE
var _lane_w := 3.6
var _lane_park := 0.0
## The vehicle followed (IDM): the gap to it (m, bumper to bumper) and its
## speed along the lane; whether the street after the junction has room.
var _lead = null
var _lead_gap := INF
var _lead_speed := 0.0
var _exit_room := true
var _scan_tick := 0
## The junction ahead: its rule for this approach (TrafficPlan GO, SIGNAL,
## STOP, YIELD), the stop line's distance from its centre and from the
## front bumper, the turn planned there (0 on, 1 right, -1 left, 2 U-turn)
## and the speed to take it at.
var _rule := 0
var _stop_back := 0.0
var _line_d := INF
var _turn := 0
var _corner_v := INF
## Held at the line; cleared into the junction; seconds stood at the line
## and whether a full stop was made; the all-way stop queued at; the
## yellow's decision (1 go, -1 stop).
var _held := false
var _released := false
var _stopped := 0.0
var _full_stop := false
var _queued := -1
var _amber := 0
## Waiting at a junction, or queued behind traffic that is.
var _waiting := false
## A siren coming; seconds stood behind something that does not move
## off; going round it (not following it) for this long.
var _siren := false
var _block_time := 0.0
var _bypass_time := 0.0
var _ignore = null


func _ready() -> void:
	add_to_group("vehicles")
	motion_mode = MOTION_MODE_FLOATING
	collision_layer = L.VEHICLES
	collision_mask = L.WORLD | L.PROPS | L.VEHICLES | L.CHARACTERS
	if is_police:
		kind = "police"
	_spec = VehicleKit.spec(kind)
	_cls = VehicleClasses.of(kind)
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
	if driver == Driver.NONE and speed == 0.0 and velocity == Vector3.ZERO and _lights.is_empty() and _settled():
		motion = Vector3.ZERO
		return # parked: nothing to simulate until something drives or hits it
	desired_dir = Vector3.ZERO
	throttle = 0.0
	handbrake = false
	braking = false
	_wheel = false
	_coast = false
	_drift_brake = 0.0
	if driver != Driver.PLAYER:
		drifting = false
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
	set_xray(PLAYER_XRAY)


func release_player() -> void:
	if occupant != null and is_instance_valid(occupant):
		occupant.rotation.z = 0.0
	occupant = null
	driver = Driver.NONE
	update_beams()
	set_xray(POLICE_XRAY if is_police else Color(0, 0, 0, 0))


## Drives as traffic, setting off from junction `from` towards `to` in
## lane `in_lane`.
func start_traffic(c, from: int, to: int, in_lane := 0) -> void:
	city = c
	_leave_junction()
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
	_leave_junction()
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


## Whether a vehicle `size` long and wide at `pos`, facing `yaw`, would sit
## clear of every vehicle by `margin` (their footprints on the ground, so an
## 18-wheeler's trailer counts all the way to its tail, not just near its
## middle). Spawners check this so nothing appears inside another vehicle.
static func room_for(tree: SceneTree, pos: Vector3, yaw: float, size: Vector3, margin := 0.5, skip = null) -> bool:
	for v in tree.get_nodes_in_group("vehicles"):
		if v != skip and v.is_inside_tree() and footprints_meet(pos, yaw, size, v.global_position, v.rotation.y, v._size, margin):
			return false
	return true


## Whether two vehicle footprints (rectangles on the ground) come within
## `margin` of each other.
static func footprints_meet(a: Vector3, a_yaw: float, a_size: Vector3, b: Vector3, b_yaw: float, b_size: Vector3, margin := 0.0) -> bool:
	var axes := [Vector2(cos(a_yaw), -sin(a_yaw)), Vector2(sin(a_yaw), cos(a_yaw)),
		Vector2(cos(b_yaw), -sin(b_yaw)), Vector2(sin(b_yaw), cos(b_yaw))]
	var gap := Vector2(b.x - a.x, b.z - a.z)
	for n: Vector2 in axes:
		var ra: float = (a_size.x * absf(axes[0].dot(n)) + a_size.z * absf(axes[1].dot(n))) * 0.5
		var rb: float = (b_size.x * absf(axes[2].dot(n)) + b_size.z * absf(axes[3].dot(n))) * 0.5
		if absf(gap.dot(n)) > ra + rb + margin:
			return false
	return true


## Moves the car by `offset` at once, stopping at walls (another car
## sunk into it moves it out).
func shove(offset: Vector3) -> void:
	move_and_collide(offset)
	# A parked car skips its physics step: put it back on the ground here.
	global_position.y = Terrain.height(global_position.x, global_position.z) - _drop


## Hit by another vehicle: `push` is already scaled by the two masses (see
## _handle_collisions); a hard shove costs up to 40% of our speed. `at`, the
## contact point, dents the body there, bounces it on its springs and spins
## the car when the blow is off-centre; a hard one throws a rider off.
func bump(push: Vector3, at = null) -> void:
	velocity += push
	speed *= lerpf(1.0, 0.6, clampf(push.length() / 6.0, 0.0, 1.0))
	_damage(push.length())
	if at != null:
		_jolt(at, push)
		# The push is 0.6 of the striker's speed for equal masses: the dent
		# matches what the striker takes from the same crash.
		_crumple(at, push.normalized(), push.length() / 0.6)
	var throw: float = _cls.throw
	if throw > 0.0 and push.length() >= throw * 0.6:
		_throw_rider(push)


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
			s = clampf(Controls.stick_steer() + Input.get_axis("steer_left", "steer_right"), -1.0, 1.0)
		# Turning in takes STEER_IN seconds (scaled by the class's wheel);
		# letting go or turning back is twice as quick.
		var rate := 1.0 / (STEER_IN * _feel("wheel"))
		if signf(s) != signf(_steer_in) or absf(s) < absf(_steer_in):
			rate *= 2.0
		_steer_in = move_toward(_steer_in, s, rate * get_physics_process_delta_time())
		desired_dir = fwd.rotated(Vector3.UP, -_steer_in * WHEEL_ANGLE)
		throttle = gas
		if _drift_input(-_steer_in, brake):
			return
		if brake > 0.05:
			_pedal_brake(brake, _steer_in)
		else:
			_coast = gas < 0.05
		return
	# Stick: the car heads where the stick points; GAS floors it that way
	# (straight on with the stick at rest), BRAKE stops and reverses.
	_coast = false
	var dir := Controls.world_move()
	throttle = dir.length()
	if throttle > 0.05:
		desired_dir = dir / throttle
	if gas > 0.05:
		throttle = maxf(throttle, gas)
		if desired_dir == Vector3.ZERO:
			desired_dir = fwd
	var turn := 0.0
	if desired_dir != Vector3.ZERO:
		turn = clampf(fwd.signed_angle_to(desired_dir, Vector3.UP) * 2.0, -1.0, 1.0)
	if _drift_input(turn, brake):
		return
	if brake > 0.05:
		_pedal_brake(brake, 0.0)


## Starts, holds or ends a brake-and-steer drift (DRIFT_MIN); `turn` is
## the wheel, -1..1. True while drifting: the brake then scrubs speed in
## the slide (_drive) instead of stopping the car.
func _drift_input(turn: float, brake: float) -> bool:
	var cls: String = _cls["class"]
	if cls == "cycle" or cls == "two_wheeler" or cls == "truck":
		drifting = false
		return false
	if not drifting and brake > 0.05 and speed > DRIFT_MIN and absf(turn) >= DRIFT_STEER:
		drifting = true
		GameLog.event("drift", {"car": kind, "speed": speed})
	elif drifting and (speed < DRIFT_END or absf(turn) < 0.12):
		drifting = false
	if drifting:
		_drift_brake = brake
	return drifting


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


## An 18-wheeler: routed along streets with room for its trailer.
func _long_haul() -> bool:
	return _size.z > VehicleKit.LONG_HAUL


## The game's grip multiplier on corner_g (CORNER_GRIP; none for 18-wheelers).
func _grip() -> float:
	if _long_haul():
		return 1.0
	return PLAYER_GRIP * _feel("cornering") if driver == Driver.PLAYER else CORNER_GRIP


## The class's handling multiplier `key` (VehicleClasses: brakes,
## cornering, turning, wheel) for the player's car; traffic drives on its
## kind's spec alone, so its junction speeds and stops do not change.
func _feel(key: String) -> float:
	return _cls.get(key, 1.0) if driver == Driver.PLAYER else 1.0


## Braking (m/s²): the kind's, scaled by its class for the player.
func _brake_rate() -> float:
	return _spec.brake * _feel("brakes")


## Heading turn rate (rad/s) at full lock, scaled by the class for the player.
func _turn_rate() -> float:
	return turn_rate * _feel("turning")


## Traffic: follows its lane junction to junction at the street's limit
## (its driver's share of it), keeps its distance to the vehicle ahead
## (IDM), obeys the junction's light or sign, yields to sirens and goes
## round what blocks its lane for good.
func _traffic_ai() -> void:
	if _next_node < 0:
		throttle = 0.0
		return
	var dt := get_physics_process_delta_time()
	_find_traffic()
	if Vector2i(_prev_node, _next_node) != _seg:
		_enter_street()
	var p := global_position
	var target: Vector3 = city.lane_point(_prev_node, _next_node, lane)
	var near := Vector2(target.x - p.x, target.z - p.z).length()
	# The turn is picked in time to slow for it (and to get in lane).
	if near < maxf(TRAFFIC_SLOW_ZONE * 2.0, speed * speed / 6.0 + 15.0) and _after_node < 0:
		_after_node = city.pick_turn(_prev_node, _next_node, rng, _long_haul())
		_plan_turn()
		target = city.lane_point(_prev_node, _next_node, lane)
	var turn_in := false
	if _after_node >= 0:
		var ls: Vector3 = city.lane_start(_next_node, _after_node, lane)
		turn_in = Vector2(ls.x - p.x, ls.z - p.z).length() < 4.0
	# Held at the line, the car stays on this street however close it is.
	if (near < 5.0 or turn_in) and not _held:
		_advance()
		_enter_street()
		target = city.lane_point(_prev_node, _next_node, lane)
	var to := target - p
	to.y = 0.0
	near = to.length()
	# Follow the lane line a few metres ahead rather than aiming straight at
	# the far junction, so a car that turned wide finds its own side of a
	# boulevard median again instead of cutting across it.
	var a: Vector3 = city.lane_start(_prev_node, _next_node, lane) if _prev_node >= 0 else p
	var ab := target - a
	ab.y = 0.0
	var u := Vector2(ab.x, ab.z) / ab.length() if ab.length() > 0.5 else Vector2(-global_basis.z.x, -global_basis.z.z).normalized()
	var d_node := Vector2(to.x, to.z).dot(u)
	_line_d = d_node - _stop_back - _size.z * 0.5
	_obey(dt)
	if _queued >= 0 and _line_d < -1.5:
		_traffic.depart(_queued, self)
		_queued = -1
	var aim := target
	if ab.length() > TRAFFIC_LOOKAHEAD:
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		# Far off the lane (a left turn across a boulevard), look nearer, so
		# the car swings out to its lane before running down it rather than
		# cutting the corner into the median's nose.
		var lane_at := a + ab * t
		var off := Vector2(p.x - lane_at.x, p.z - lane_at.z).length()
		var ahead := clampf(TRAFFIC_LOOKAHEAD - off, 2.0, TRAFFIC_LOOKAHEAD)
		aim = a + ab * minf(1.0, t + ahead / ab.length())
	# Over to the right for a siren; out to the left round a blockage.
	var side := 0.0
	if _bypass_time > 0.0:
		var w: float = _ignore._size.x if _ignore != null and is_instance_valid(_ignore) else 2.0
		side = -((_size.x + w) * 0.5 + 0.6)
	elif _siren:
		side = 1.2 if lane > 0 else clampf((_lane_w - _size.x) * 0.5 - 0.1 + _lane_park, 0.0, 1.2)
	if side != 0.0:
		aim += Vector3(-u.y, 0.0, u.x) * side
	aim.y = p.y
	desired_dir = (aim - p).normalized() if aim.distance_to(p) > 0.5 else to.normalized()
	if _reverse_time > 0.0:
		# Ran into a wall or kerb prop (a wide model missing a corner): back
		# off, swinging the nose toward the lane, then carry on.
		_reverse_time -= dt
		_since_reverse = 0.0
		var swing := signf((-global_basis.z).signed_angle_to(desired_dir, Vector3.UP))
		desired_dir = global_basis.z.rotated(Vector3.UP, 0.6 * swing)
		throttle = 0.7
		return
	_since_reverse += dt
	_yield_time = maxf(_yield_time - dt, -2.0)
	var v := maxf(speed, 0.0)
	var cruise := minf(_limit * drive_factor, max_speed * 0.8)
	var rain: bool = _traffic != null and _traffic.raining
	if rain:
		cruise *= 0.9
	_scan_tick -= 1
	if _scan_tick <= 0:
		_scan_tick = IDM_SCAN
		_scan_leader(Vector2(a.x, a.z), u, d_node)
		_siren = _traffic != null and _traffic.siren_near(self)
	elif _lead_gap < INF:
		_lead_gap -= (v - _lead_speed) * dt
	var gap := _lead_gap
	var lead_v := _lead_speed
	# The short ray still sees what the lane scan does not: a car cutting
	# across, a person, a vehicle that is not traffic's.
	var people := false
	if _ahead.is_colliding():
		var hit = _ahead.get_collider()
		if hit != null and hit.is_in_group("vehicles"):
			if hit != _ignore:
				var g := _ahead.global_position.distance_to(_ahead.get_collision_point())
				if g < gap:
					gap = g
					lead_v = maxf(hit.velocity.dot(-global_basis.z), 0.0)
		elif hit != null:
			people = true
	# A line to stop at is a leader standing still.
	if _held and _line_d + IDM_S0 - 0.4 < gap:
		gap = _line_d + IDM_S0 - 0.4
		lead_v = 0.0
	var acc := _idm(v, cruise, gap, v - lead_v, rain)
	if _held and v < 0.3 and _line_d < 1.0:
		acc = minf(acc, 0.0) # at the line: foot on the brake, no creeping over
	var v_cmd := clampf(v + acc * dt, 0.0, maxf(cruise, v))
	if _corner_v < INF:
		# Down to the turn's speed by 8 m short of the junction's middle.
		v_cmd = minf(v_cmd, sqrt(_corner_v * _corner_v + 2.0 * IDM_B * maxf(near - 8.0, 0.0)))
	if ab.length() > 0.5 and (-global_basis.z).angle_to(ab) > 0.4:
		# Still coming round from the last junction: hold turn speed until
		# lined up with the new street, or a fast model runs wide mid-turn.
		v_cmd = minf(v_cmd, TURN_SPEED)
	if _siren:
		v_cmd = minf(v_cmd, maxf(v - 4.0 * dt, SIREN_CRAWL))
	if _bypass_time > 0.0:
		_bypass_time -= dt
		v_cmd = minf(v_cmd, 3.0)
		if _bypass_time <= 0.0:
			_ignore = null
	_check_blocked(dt, v)
	# _drive eases the pedal off by the angle still to steer; undo that, or
	# a car coming round a bend or a U-turn slows to a stop mid-turn.
	var off := absf((-global_basis.z).signed_angle_to(desired_dir, Vector3.UP))
	throttle = minf(v_cmd / (max_speed * lerpf(1.0, 0.45, off / PI)), 1.0)
	# The brake pedal: an emergency, or holding the car still once stopped.
	braking = people or _yield_time > 0.0 or acc < -8.5 or (gap < IDM_S0 * 0.5 and v > lead_v + 0.5) \
			or (acc <= 0.0 and v < 0.3)


## Intelligent Driver Model: the acceleration (m/s²) at speed `v` toward
## `v0`, `s` m behind a leader closing at `dv` m/s (INF: open road).
func _idm(v: float, v0: float, s: float, dv: float, rain := false) -> float:
	var a_max := clampf(accel * 0.3, IDM_ACCEL.x, IDM_ACCEL.y)
	var free := 1.0 - pow(v / maxf(v0, 0.1), 4.0)
	if s == INF:
		return maxf(a_max * free, -9.0)
	var t := IDM_T + (0.4 if rain else 0.0)
	var want := IDM_S0 + maxf(0.0, v * t + v * dv / (2.0 * sqrt(a_max * IDM_B)))
	return maxf(a_max * (free - pow(want / maxf(s, 0.1), 2.0)), -9.0)


## Waiting at a junction's line, or queued behind traffic that is.
func is_waiting() -> bool:
	return _held or _waiting


## Finds the junction controller (Traffic), looking again once a second
## while there is none (a scene without Population drives with no controls).
func _find_traffic() -> void:
	if _traffic != null and is_instance_valid(_traffic):
		return
	_traffic = null
	_traffic_retry -= 1
	if _traffic_retry > 0:
		return
	_traffic_retry = 60
	_traffic = get_tree().get_first_node_in_group("traffic")
	if _traffic != null:
		_seg = Vector2i(-2, -2)


## Forgets an earlier stint in traffic (a taxi or police car rejoining,
## maybe on the same street): gives up its all-way stop place, and the next
## frame reads the street afresh, so an old release does not run a red.
func _leave_junction() -> void:
	if _queued >= 0 and _traffic != null:
		_traffic.depart(_queued, self)
	_queued = -1
	_seg = Vector2i(-2, -2)


## On a new street: its limit, lane layout and the junction ahead's rule.
func _enter_street() -> void:
	if _queued >= 0 and _traffic != null:
		_traffic.depart(_queued, self)
	_queued = -1
	_seg = Vector2i(_prev_node, _next_node)
	_released = false
	_held = false
	_stopped = 0.0
	_full_stop = false
	_amber = 0
	_scan_tick = 0
	_block_time = 0.0
	_rule = TrafficPlan.GO
	_stop_back = 0.0
	_limit = TRAFFIC_CRUISE
	_lane_w = 3.6
	_lane_park = 0.0
	if _prev_node >= 0 and _next_node >= 0:
		var ls: Dictionary = city.lanes_of(_prev_node, _next_node)
		_lane_w = float(ls.get("lane_w", 3.6))
		_lane_park = float(ls.get("park", 0.0))
		if _traffic != null:
			_rule = _traffic.rule(_next_node, _prev_node)
			_stop_back = _traffic.stop_back(_next_node, _prev_node)
			_limit = _traffic.limit(_prev_node, _next_node)
	_plan_turn()


## The turn at the junction ahead (on, right, left, U-turn), the speed to
## take it at, and the lane for it: the curb lane to turn right, the inside
## lane to turn left, where it is free.
func _plan_turn() -> void:
	_turn = 0
	_corner_v = INF
	if _prev_node < 0 or _after_node < 0:
		return
	var c: Vector3 = city.node_pos(_next_node)
	var pa: Vector3 = city.node_pos(_prev_node)
	var pb: Vector3 = city.node_pos(_after_node)
	var din := Vector2(c.x - pa.x, c.z - pa.z).normalized()
	var dout := Vector2(pb.x - c.x, pb.z - c.z).normalized()
	var ang := absf(din.angle_to(dout))
	if _after_node == _prev_node or ang > 2.4:
		_turn = 2
		_corner_v = TIGHT_TURN_SPEED
	else:
		var cr := din.cross(dout)
		if cr > 0.45:
			_turn = 1
		elif cr < -0.45:
			_turn = -1
		# A bend in the road: about 1 g sideways round a corner of the
		# junction's size.
		if ang > 1.0:
			_corner_v = TURN_SPEED
		elif ang > 0.1:
			_corner_v = maxf(sqrt(100.0 / ang), TURN_SPEED)
	var lanes: int = city.lane_count(_prev_node, _next_node)
	if lanes >= 2 and (_turn == 1 or _turn == -1) and not _long_haul():
		var want := 0 if _turn == 1 else lanes - 1
		if want != lane and _lane_free(want):
			lane = want


## On to the next street, in the same lane where it has it; now and then
## another, when it is free.
func _advance() -> void:
	var nxt: int = _after_node if _after_node >= 0 else city.pick_turn(_prev_node, _next_node, rng, _long_haul())
	_prev_node = _next_node
	_next_node = nxt
	_after_node = -1
	var lanes: int = city.lane_count(_prev_node, _next_node)
	lane = mini(lane, lanes - 1)
	if lanes > 1 and rng.randf() < 0.3:
		var k := rng.randi() % lanes
		if k != lane and _lane_free(k):
			lane = k


## Whether lane k of this street has room beside the car to move into.
func _lane_free(k: int) -> bool:
	if _traffic == null or _prev_node < 0:
		return true
	var s: Vector3 = city.lane_start(_prev_node, _next_node, k)
	var e: Vector3 = city.lane_point(_prev_node, _next_node, k)
	var d := Vector2(e.x - s.x, e.z - s.z)
	if d.length() < 0.5:
		return true
	var u := d.normalized()
	var me := Vector2(global_position.x - s.x, global_position.z - s.z).dot(u)
	for v in _traffic.vehicles:
		if v == self or not is_instance_valid(v):
			continue
		var rel := Vector2(v.global_position.x - s.x, v.global_position.z - s.z)
		var along: float = rel.dot(u) - me
		if along > -12.0 and along < 14.0 and absf(rel.cross(u)) < 1.9:
			return false
	return true


## The vehicle to follow: the nearest in this lane ahead (to just past the
## junction), else in the lane taken on the street after it; and whether
## that street has room to drive into.
func _scan_leader(a2: Vector2, u: Vector2, d_node: float) -> void:
	_lead = null
	_lead_gap = INF
	_lead_speed = 0.0
	_exit_room = true
	if _traffic == null:
		return
	var p2 := Vector2(global_position.x, global_position.z)
	var me := (p2 - a2).dot(u)
	var half := _size.z * 0.5
	var v_me := maxf(speed, 0.0)
	var reach := 25.0 + 4.0 * v_me
	var thr := minf(_lane_w * 0.6, (_size.x + 1.9) * 0.5 + 0.3)
	var u3 := Vector2.ZERO
	var a3 := Vector2.ZERO
	if _after_node >= 0:
		var nl := mini(lane, city.lane_count(_next_node, _after_node) - 1)
		var s3: Vector3 = city.lane_start(_next_node, _after_node, nl)
		var e3: Vector3 = city.lane_point(_next_node, _after_node, nl)
		a3 = Vector2(s3.x, s3.z)
		u3 = Vector2(e3.x - s3.x, e3.z - s3.z).normalized()
	for v in _traffic.vehicles:
		if v == self or v == _ignore or not is_instance_valid(v) or not v.is_inside_tree():
			continue
		var q := Vector2(v.global_position.x, v.global_position.z)
		var fwd := Vector2(-v.global_basis.z.x, -v.global_basis.z.z)
		var vel := Vector2(v.velocity.x, v.velocity.z)
		var rel := q - a2
		var along := rel.dot(u) - me
		if along > 0.0 and along < reach and along < d_node + 6.0 and absf(rel.cross(u)) < thr:
			var ext: float = 0.5 * (absf(fwd.dot(u)) * v._size.z + absf(fwd.orthogonal().dot(u)) * v._size.x)
			var g := along - half - ext
			if g < _lead_gap:
				_lead = v
				_lead_gap = maxf(g, 0.0)
				_lead_speed = maxf(vel.dot(u), 0.0)
			continue
		if u3 == Vector2.ZERO:
			continue
		var rel3 := q - a3
		var al3 := rel3.dot(u3)
		if al3 > -2.0 and al3 < 40.0 and absf(rel3.cross(u3)) < thr:
			var ext3: float = 0.5 * (absf(fwd.dot(u3)) * v._size.z + absf(fwd.orthogonal().dot(u3)) * v._size.x)
			var g3 := maxf(d_node, 0.0) + al3 - half - ext3
			var v3 := maxf(vel.dot(u3), 0.0)
			if al3 - ext3 < _size.z + 4.0 and v3 < 1.0:
				_exit_room = false
			if g3 < _lead_gap:
				_lead = v
				_lead_gap = maxf(g3, 0.0)
				_lead_speed = v3
	_waiting = _held or (_lead != null and _lead_gap < 15.0 and _lead.driver == Driver.TRAFFIC and _lead._waiting)


## Stood behind something that does not move off: after a while, into
## another lane if one is free, else round it (BLOCK_WAIT). Queues at a
## junction are waited out.
func _check_blocked(dt: float, v: float) -> void:
	if _lead == null or not is_instance_valid(_lead) or _lead_gap > 8.0 or _lead_speed > 0.5 or v > 0.5 \
			or _held or _bypass_time > 0.0:
		_block_time = 0.0
		return
	var patience := BLOCK_WAIT.z
	if _lead.wrecked or _lead.driver == Driver.NONE:
		patience = BLOCK_WAIT.x
	elif _lead.driver != Driver.TRAFFIC:
		patience = BLOCK_WAIT.y
	elif _lead._waiting:
		_block_time = 0.0
		return
	_block_time += dt
	if _block_time < patience:
		return
	_block_time = 0.0
	if _prev_node >= 0:
		var lanes: int = city.lane_count(_prev_node, _next_node)
		for k in lanes:
			if k != lane and _lane_free(k):
				lane = k
				return
	_ignore = _lead
	_bypass_time = (_lead._size.z + _size.z + 6.0) / 3.0


## The junction ahead's light or sign: sets `_held` while the car must
## stop at the line, `_released` once it may go (or has gone) in.
func _obey(dt: float) -> void:
	_held = false
	if _released or _traffic == null or _prev_node < 0 or _rule == TrafficPlan.GO:
		return
	if _line_d < -0.5:
		_released = true
		return
	var v := maxf(speed, 0.0)
	if _line_d > maxf(40.0, v * v / 4.0 + 10.0):
		return
	if _line_d < 3.0 and v < 0.3:
		_stopped += dt
		if _stopped >= STOP_HOLD:
			_full_stop = true
	var n := _next_node
	var give_up := GRIDLOCK
	if _rule == TrafficPlan.SIGNAL:
		var lt: int = _traffic.light(n, _prev_node)
		if not _traffic.is_dead(n) and lt != TrafficManager.FLASH_RED:
			give_up = RED_GIVE_UP
		_held = _signal_hold(n, v, lt)
	elif _rule == TrafficPlan.STOP:
		_held = _sign_hold(n, _traffic.kind(n) == TrafficPlan.ALL_STOP)
	elif _rule == TrafficPlan.YIELD:
		if _line_d < maxf(12.0, v * v / 6.0 + 4.0):
			if _traffic.gap_clear(n, self, _prev_node, _after_node, "cross") and _traffic.box_clear(n, self):
				_released = true
			else:
				_held = true
	# Stood at the line this long, a driver decides the junction is stuck
	# and goes.
	if _held and _stopped > give_up:
		_held = false
		_released = true


## At a signal: whether to hold at the line for light `lt`.
func _signal_hold(n: int, v: float, lt: int) -> bool:
	if _traffic.is_dead(n):
		return _sign_hold(n, true)
	if lt == TrafficManager.GREEN or lt == TrafficManager.FLASH_YELLOW:
		_amber = 0
		# A permissive left (or U-turn) waits for a gap in the oncoming
		# traffic; nobody drives into a junction they can't leave.
		if (_turn == -1 or _turn == 2) and _line_d < 8.0 \
				and not _traffic.gap_clear(n, self, _prev_node, _after_node, "left"):
			return true
		return _line_d < 6.0 and not _exit_room
	if lt == TrafficManager.YELLOW:
		# Stop if it can comfortably (3 m/s²), else carry on through.
		if _amber == 0:
			_amber = -1 if v < 1.0 or _line_d > v * v / 6.0 else 1
		return _amber < 0
	if lt == TrafficManager.FLASH_RED:
		return _sign_hold(n, false)
	# Red: through if it went on the yellow or can't stop even hard.
	if (_amber > 0 and v > 2.0) or (v >= 2.0 and _line_d < v * v / 18.0):
		return false
	# Right on red after a full stop, when clear.
	if _turn == 1 and _full_stop and _exit_room and _traffic.gap_clear(n, self, _prev_node, _after_node, "right") \
			and _traffic.box_clear(n, self):
		_released = true
		return false
	return true


## At a stop sign (or a dark signal, or a flashing red): a full stop, then
## first come first served at an all-way stop, or a gap in the cross
## traffic at a two-way one.
func _sign_hold(n: int, all_way: bool) -> bool:
	if not _full_stop:
		return true
	if all_way:
		if _queued != n:
			_traffic.arrive(n, self)
			_queued = n
		if _exit_room and _traffic.may_go(n, self):
			_released = true
			return false
		return true
	if _exit_room and _traffic.gap_clear(n, self, _prev_node, _after_node, "cross") and _traffic.box_clear(n, self):
		_released = true
		return false
	return true


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
	var scrub := 0.0 # how hard the tyres scrub in a wheel-steered turn, 0..1
	var slide_to := 0.0
	if drifting:
		slide_to = 1.0 if _drift_brake > 0.05 else 0.75
	_slide = move_toward(_slide, slide_to, delta / DRIFT_IN)
	# How loose the rear is: the handbrake, or a drift.
	var loose := maxf(_slide, 1.0 if handbrake else 0.0)
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
			if driver == Driver.PLAYER and not handbrake and not _wheel and not drifting:
				var mix := smoothstep(0.3, 0.9, absf(angle))
				var assisted := lerpf(target, _corner_speed(), mix)
				if assisted < target and assisted < pace:
					corner = mix
				target = minf(target, assisted)
			if driver == Driver.PLAYER and _wheel and not handbrake and not drifting:
				var lock := clampf(absf(angle) * 2.0, 0.0, 1.0)
				if lock > 0.05:
					var hold := sqrt(_spec.corner_g * _grip() * TURN_RADIUS / lock)
					if hold < target or (_coast and hold < pace):
						scrub = lock
					target = minf(target, hold)
		var grip_turn: float = clampf(pace / _spec.steer_low, 0.0, 1.0) * (1.0 - _spec.steer_fade * clampf(pace / max_speed, 0.0, 1.0))
		steer = clampf(angle * 2.0, -1.0, 1.0)
		var rate_want: float = steer * _turn_rate() * grip_turn * lerpf(1.0, 1.6, loose)
		# The tyres hold only so much sideways pull (corner_g = v * yaw rate)
		# and the wheels turn only so far: at speed the arc widens. The
		# handbrake lets the tail come round past grip (a drift).
		var cap: float = minf(_spec.corner_g * _grip() / maxf(pace, 0.1), pace / MIN_RADIUS + 0.3)
		cap *= lerpf(1.0, 1.8, loose)
		rate_want = clampf(rate_want, -cap, cap)
		if driver == Driver.PLAYER:
			_yaw_rate = lerpf(_yaw_rate, rate_want, 1.0 - exp(-delta / YAW_IN))
		else:
			_yaw_rate = rate_want
		yaw = _yaw_rate * delta
		rotate_y(yaw)
	else:
		_yaw_rate = 0.0
	if _spin != 0.0:
		rotate_y(_spin * delta)
		_spin *= exp(-2.5 * delta)
		if absf(_spin) < 0.02:
			_spin = 0.0

	var rate: float = accel * (1.0 - _spec.power_fade * clampf(pace / max_speed, 0.0, 1.0))
	_hard_brake = false
	if desired_dir == Vector3.ZERO or _coast:
		rate = maxf(COAST, SCRUB * scrub)
	elif signf(target) != signf(speed) and pace > 0.5:
		rate = _brake_rate()
		_hard_brake = pace > 9.0
	elif corner > 0.0:
		rate = _brake_rate()
	elif absf(target) < pace:
		rate = SCRUB * scrub if scrub > 0.0 else COAST * 2.0
	if drifting:
		# Sliding: the throttle holds the drift, the brake scrubs it off,
		# and the sideways tyres bleed speed either way.
		rate = accel * 0.5 if target > speed else _brake_rate() * DRIFT_BRAKE * _drift_brake
		_hard_brake = false
	speed = move_toward(speed, target, rate * delta)
	if _slide > 0.0:
		speed = maxf(speed - DRIFT_BLEED * _slide * delta, 0.0)
	if braking or handbrake:
		speed = move_toward(speed, 0.0, (_brake_rate() if braking else 10.0) * delta)
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
	var grip: float = lerpf(_spec.grip, _spec.drift, loose)
	# Power slides need power: none while the corner assist brakes.
	if corner == 0.0:
		grip *= 1.0 - _spec.slide * throttle * absf(steer) * clampf(pace / 10.0, 0.0, 1.0)
	velocity = Vector3(velocity.x, 0.0, velocity.z).lerp(want, clampf(grip * delta, 0.0, 1.0))
	var before := velocity
	move_and_slide()
	global_position.y = Terrain.height(global_position.x, global_position.z) - _ground_drop(delta)
	_ground_bumps(delta)
	_ground_slope(delta)
	# Tilt follows how the body really moves, so a car pinned against a
	# wall with the throttle down stays level.
	var real := get_real_velocity()
	motion = motion.lerp(Vector3(real.x, 0.0, real.z), 1.0 - exp(-delta / MOTION_EASE))
	var moved := real.dot(-global_basis.z)
	_body_tilt(delta, moved * yaw / delta, (moved - _moved) / delta)
	_moved = moved
	_handle_collisions(before)


## Speed (m/s) at which this model's heading turns as fast as a car on a
## CORNER_RADIUS circle at full lock: v = R * turn * (1 - steer_fade * v /
## max_speed), solved for v, and no faster than its tyres hold that
## circle (v² / R = corner_g). The path is tighter than R, since the velocity
## lags the heading by the model's grip.
func _corner_speed() -> float:
	var k: float = CORNER_RADIUS * _turn_rate()
	return minf(k / (1.0 + k * _spec.steer_fade / max_speed), sqrt(_spec.corner_g * _grip() * CORNER_RADIUS))


## Tilts the model: cars roll out of turns and pitch back under power and
## forward under braking, tall ones more; two-wheelers lean into turns.
## `lateral` is the sideways acceleration (m/s², positive turning left).
## The body rides on springs (the class's hz and zeta): it lags, overshoots
## and settles, and bumps and crashes (_jolt) set it bouncing.
func _body_tilt(delta: float, lateral: float, forward: float) -> void:
	var roll_max: float = _cls.roll_max
	var pitch_max: float = _cls.pitch_max
	var want := Vector2(clampf(-lateral * _spec.roll, -roll_max, roll_max), clampf(forward * _spec.pitch, -pitch_max, pitch_max * 0.83))
	var w: float = TAU * _cls.hz
	var damp: float = 2.0 * _cls.zeta * w
	var pivot := Vector3(0, 0.45, 0) # about the axles
	if _spec.lean > 0.0:
		# The rider leans the bike; no spring in that.
		_tilt.x = lerpf(_tilt.x, clampf(atan(lateral / 9.8) * _spec.lean, -0.5, 0.5), 1.0 - exp(-7.0 * delta))
		_tilt_v.x = 0.0
		pivot = Vector3.ZERO # about the tyres' contact line
	else:
		_tilt_v.x += (-w * w * (_tilt.x - want.x) - damp * _tilt_v.x) * delta
		_tilt.x = clampf(_tilt.x + _tilt_v.x * delta, -roll_max * 1.8, roll_max * 1.8)
	_tilt_v.y += (-w * w * (_tilt.y - want.y) - damp * _tilt_v.y) * delta
	_tilt.y = clampf(_tilt.y + _tilt_v.y * delta, -pitch_max * 1.8, pitch_max * 1.8)
	_heave_v += (-w * w * _heave - damp * _heave_v) * delta
	_heave = clampf(_heave + _heave_v * delta, -0.12, 0.1)
	var b := Basis.from_euler(Vector3(_tilt.y, 0.0, _tilt.x))
	var lie := Basis.from_euler(Vector3(_slope.y, 0.0, _slope.x))
	_model.transform = Transform3D(lie, Vector3(0.0, _heave, 0.0)) * Transform3D(b, pivot - b * pivot)


## True once the body has stopped bouncing and spinning (a parked car can
## stop simulating).
func _settled() -> bool:
	return _spin == 0.0 and _tilt.length_squared() + _tilt_v.length_squared() + _heave * _heave + _heave_v * _heave_v < 1e-6


## Off the roads on the hills the ground is drawn a little under
## Terrain.height (Terrain.drop): looked up each metre of travel and eased
## (DROP_RATE), so the car settles off the kerb onto the dirt instead of
## floating over it.
func _ground_drop(delta: float) -> float:
	var p := Vector2(global_position.x, global_position.z)
	if p.distance_squared_to(_drop_at) > 1.0:
		_drop_at = p
		_drop_want = Terrain.drop(p.x, p.y)
	_drop = move_toward(_drop, _drop_want, DROP_RATE * delta)
	return _drop


## Bumps and crests: when the ground under the car speeds up or slows its
## climb, the body's weight lags it on the springs.
func _ground_bumps(delta: float) -> void:
	var y := global_position.y
	if is_inf(_last_y) or absf(y - _last_y) > 1.0: # placed or shoved
		_last_y = y
		_ground_vy = 0.0
		return
	var vy := (y - _last_y) / delta
	_last_y = y
	var change := vy - _ground_vy
	_ground_vy = vy
	if absf(change) > 0.2:
		_heave_v -= clampf(change, -4.0, 4.0) * 0.35 * _cls.kick


## A blow at `at` (world) changing the car's velocity by `dv` (m/s): the body
## pitches and rolls on its springs and bounces, and a blow off the line
## through the car's centre spins it (a side hit at the tail spins it most;
## a head-on or rear-end hit hardly at all).
func _jolt(at: Vector3, dv: Vector3) -> void:
	var k: float = _cls.kick
	_tilt_v.y += clampf(dv.dot(-global_basis.z) * 0.08 * k, -1.2, 1.2)
	if _spec.lean == 0.0:
		_tilt_v.x += clampf(dv.dot(global_basis.x) * 0.08 * k, -1.2, 1.2)
	_heave_v += clampf(dv.length() * 0.02 * k, 0.0, 0.5)
	var r := at - global_position
	var across := dv.normalized().dot(-global_basis.z)
	var inertia := (_size.x * _size.x + _size.z * _size.z) / 12.0
	var turn := (r.z * dv.x - r.x * dv.z) / inertia * 0.5 * (1.0 - across * across)
	_spin = clampf(_spin + turn, -3.0, 3.0)
	if absf(_spin) < 0.02:
		_spin = 0.0


## Dents the body at `at` (world), pushing it along `dir` by the class's
## crumple per m/s of `impact`, no deeper than its dent_cap anywhere. The
## first dent copies the shared cached mesh; later ones edit the copy.
func _crumple(at: Vector3, dir: Vector3, impact: float) -> void:
	var crumple: float = _cls.crumple
	if crumple <= 0.0 or impact < 4.0 or _model == null:
		return
	var now := Time.get_ticks_msec() * 0.001
	if now - _dent_at < 0.1:
		return # one dent per blow (a crash reports several contacts)
	_dent_at = now
	if _dent_arrays.is_empty():
		for m in [_model.mesh, _gloss.mesh]:
			var arrays: Array = m.surface_get_arrays(0)
			_dent_arrays.append(arrays)
			_dent_orig.append(arrays[Mesh.ARRAY_VERTEX].duplicate())
	var cap: float = _cls.dent_cap
	var depth := minf(impact * crumple, cap)
	var p := to_local(at)
	var d := global_basis.inverse() * dir
	d.y = 0.0
	if d.length_squared() < 1e-6:
		return
	d = d.normalized()
	var meshes: Array[ArrayMesh] = []
	for k in 2:
		var verts: PackedVector3Array = _dent_arrays[k][Mesh.ARRAY_VERTEX]
		var orig: PackedVector3Array = _dent_orig[k]
		for i in verts.size():
			var v := verts[i]
			var dx := v.x - p.x
			var dz := v.z - p.z
			if absf(dx) > DENT_RADIUS or absf(dz) > DENT_RADIUS:
				continue
			var dist := sqrt(dx * dx + dz * dz + 0.25 * (v.y - p.y) * (v.y - p.y))
			if dist >= DENT_RADIUS or v.y < 0.25: # the wheels keep their shape
				continue
			var fall := 1.0 - dist / DENT_RADIUS
			var moved := v + d * depth * fall * fall - orig[i]
			if moved.length() > cap:
				moved = moved.normalized() * cap
			verts[i] = orig[i] + moved
		_dent_arrays[k][Mesh.ARRAY_VERTEX] = verts
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _dent_arrays[k])
		meshes.append(mesh)
	_model.mesh = meshes[0]
	_gloss.mesh = meshes[1]
	if impact >= PANEL_IMPACT and get_parent() != null:
		# A panel tears off and flies.
		var fly := -dir * rng.randf_range(2.0, 4.0) + Vector3.UP * rng.randf_range(3.0, 5.5) + velocity * 0.5
		CarDebris.throw(get_parent(), at + Vector3.UP * 0.3, fly, body_color, minf(impact / 20.0, 1.0))


## A crash throws the rider off a two-wheeler or cycle: the player gets up
## hurt beside it, an NPC rider tumbles along the way it was going.
func _throw_rider(fling: Vector3) -> void:
	var flat := Vector3(fling.x, 0.0, fling.z)
	if driver == Driver.PLAYER and occupant != null:
		var p = occupant
		p.exit_vehicle(true)
		p.velocity += flat * 0.5
	elif rider != null and is_instance_valid(rider):
		var r = rider
		r.rotation.z = 0.0
		r.dismount(global_position + (flat.normalized() * 1.2 if flat.length() > 0.1 else Vector3.ZERO))
		rider = null
		r.take_hit(null, flat.length() * 2.0, Vector3.ZERO)
		if not r.dead:
			r.knock_down(2.0, flat)
		r.velocity = flat * 0.5
		if has_ai_driver():
			driver = Driver.NONE
	else:
		return
	GameLog.event("rider_thrown", {"car": kind, "kmh": flat.length() * 3.6, "at": global_position})


## The ground's slope along and across the car (it lies on the hill).
func _ground_slope(delta: float) -> void:
	var n := Terrain.normal(global_position.x, global_position.z)
	var want := Vector2.ZERO
	if n.y < 0.9999:
		var fwd := -global_basis.z
		var right := global_basis.x
		want = Vector2(atan(-(n.x * right.x + n.z * right.z) / n.y), atan(-(n.x * fwd.x + n.z * fwd.z) / n.y))
	var before := _slope
	_slope = _slope.lerp(want, 1.0 - exp(-10.0 * delta))
	# Over a crest or into a dip the body's weight lags the change of slope.
	_tilt_v.y -= clampf((_slope.y - before.y) * 0.3, -0.05, 0.05) * _cls.kick
	if _slope.length_squared() < 1e-8:
		_slope = Vector2.ZERO


func _handle_collisions(before: Vector3) -> void:
	# move_and_slide can report one body several times a frame; it is one hit.
	var struck := []
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var other := col.get_collider()
		# Sunk into another car (a long tail swung into a parked car, which
		# turning does not sweep, or a car spawned too close): move_and_slide
		# pushed this one out and back every frame, 1.2 m each way, and the
		# view shook (Sachin's 0.21 video). The parked or lighter car is
		# moved out instead.
		if other != null and other.has_method("shove") and col.get_depth() > OVERLAP:
			if other.driver == Driver.NONE or other.mass < mass:
				var n := Vector3(col.get_normal().x, 0.0, col.get_normal().z).normalized()
				other.shove(-n * minf(col.get_depth() + 0.05, OVERLAP_STEP))
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
		# The share of the crash this car takes (1 against a wall).
		var share := 1.0
		if other != null and other.has_method("bump"):
			# Share by mass (equal masses: half the speed kept, 0.6 of the
			# impact as damage and push, as for walls): the lighter vehicle
			# loses more speed, takes more damage and is shoved further.
			var m: float = other.mass
			var mine := mass / (mass + m)
			share = 2.0 * (1.0 - mine)
			speed *= mine
			_damage(impact * 1.2 * (1.0 - mine))
			other.bump(before * 1.2 * mine, col.get_position())
		else:
			_damage(impact * 0.6)
		var n := col.get_normal()
		_jolt(col.get_position(), n * impact * minf(share, 1.5))
		_crumple(col.get_position(), n, impact * share)
		var throw: float = _cls.throw
		if throw > 0.0 and impact * share >= throw:
			_throw_rider(before)


## Takes `amount` of damage, times the class's damage multiplier unless
## `raw` (fire). Below FIRE_AT the car catches fire (not a bicycle).
func _damage(amount: float, raw := false) -> void:
	if wrecked:
		return
	health -= amount if raw else amount * _cls.damage
	if health > 0.0:
		if health < max_health * FIRE_AT and _fire == null and _cls["class"] != "cycle":
			_fire = CarFire.ignite(self)
		return
	wrecked = true
	unload_all()
	if is_in_group("xray"):
		remove_from_group("xray") # nothing to show through walls any more
	if _cls["class"] != "cycle":
		# Burnt out. A bicycle never burns; it is just bent.
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
		_bar_light.visible = on and _bar_on and _real_light.visible
		_bar_light.light_color = Color(1.0, 0.12, 0.1) if phase else Color(0.15, 0.35, 1.0)


## Exhaust, tyre marks and tyre smoke (_exhaust, _tyres), splashes on wet
## roads, smoke from a damaged engine, and headlights after dark.
func _effects(delta: float) -> void:
	var v := Vector3(velocity.x, 0.0, velocity.z)
	var moving := v.length()
	_exhaust(delta)
	_tyres(delta, v, moving)
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


## What this car's tailpipes show (kits/vehicle_emissions.gd has the US
## norms behind it): water vapour on cool or damp air and from a cold
## engine; black soot under load and on each upshift from an old diesel;
## blue-grey oil smoke from a worn engine; pops on the overrun from a sports
## car. EVs, the e-moped and bicycles show nothing.
func _exhaust(delta: float) -> void:
	if _emit.is_empty():
		_roll_emissions()
	var on := not wrecked and (driver != Driver.NONE or _deployed)
	if on and not _engine_on and absf(speed) < 0.5:
		_cold = COLD_START
	_engine_on = on
	var pace := absf(speed)
	var gain := clampf((pace - _prev_pace) / maxf(delta, 0.001) / maxf(accel, 1.0), 0.0, 1.0)
	_prev_pace = pace
	_load = lerpf(_load, gain, clampf(8.0 * delta, 0.0, 1.0))
	var gear := int(pace / maxf(max_speed / (GEARS_DIESEL if _emit.fuel == "diesel" else GEARS), 1.0))
	var shift := gear > _gear and _load > 0.3
	_gear = gear
	if not on or _outlets.is_empty():
		return
	_cold = maxf(_cold - delta, 0.0)
	var k := clampf(_size.x / 1.9, 0.6, 1.5)
	var fuel: String = _emit.fuel
	var air := 0.0
	if _game != null:
		air = maxf(_game.atmosphere.night_amount(), _game.atmosphere.wetness)
	# Overrun pops: lifting off the gas at speed.
	var lifted := _throttle_was > 0.5 and throttle < 0.1
	_throttle_was = throttle
	if _emit.pops and lifted and pace > 14.0 and _pops == 0:
		_pops = _erng().randi_range(2, 4)
		_pop_time = 0.0
	if _pops > 0:
		_pop_time -= delta
		if _pop_time <= 0.0:
			_pop_time = _erng().randf_range(0.06, 0.16)
			_pops -= 1
			for o in _outlets:
				var at: Vector3 = global_transform * o[0]
				Fx.puff(at, global_basis * o[1] * 2.0, 0.22 * k, 0.6, 0.12, Color(1.0, 0.55, 0.15, 0.9))
				Fx.puff(at, global_basis * o[1] * 1.5, 0.2 * k, 0.9, 0.7, Color(0.5, 0.5, 0.52, 0.3))
	var color := Color(0, 0, 0, 0)
	var size := 0.2
	var every := 0.0
	var burst := 1
	if fuel == "diesel" and _emit.old and (_load > 0.3 or shift):
		color = Emissions.SOOT
		color.a *= clampf(0.4 + _load, 0.0, 1.0)
		size = 0.32
		every = 0.07
		if shift:
			burst = 3
			color.a = 0.75
			size = 0.45
	elif _emit.smoker and (_load > 0.25 or pace < 1.0):
		color = Emissions.OIL
		if pace < 1.0 and _load <= 0.25:
			color.a *= 0.5
			every = 0.45
		else:
			every = 0.1
		size = 0.26
	elif fuel == "diesel" and (shift or (_load > 0.6 and pace < 8.0)):
		color = Emissions.HAZE
		size = 0.3
		every = 0.2
	elif (_cold > 0.0 or air > 0.4) and pace < 10.0:
		color = Emissions.VAPOUR
		color.a *= clampf(maxf(_cold / COLD_START, air), 0.4, 1.0)
		size = 0.26
		every = 0.12 if _load > 0.3 else 0.22
	if color.a <= 0.0:
		return
	_puff_time -= delta
	if _puff_time > 0.0 and not shift:
		return
	_puff_time = every
	var r := _erng()
	for o in _outlets:
		var at: Vector3 = global_transform * o[0]
		var out: Vector3 = global_basis * o[1]
		for i in burst:
			var jitter := Vector3(r.randf_range(-0.3, 0.3), r.randf_range(0.0, 0.3), r.randf_range(-0.3, 0.3))
			Fx.puff(at, velocity * 0.15 + out * (1.2 + 2.0 * _load) + jitter, size * k, 0.9 + 0.6 * _load, 1.5 + 0.4 * _load, color)


## Rubber on the road. Drifts and sideways slides mark from the rear tyres
## and smoke in proportion to how fast the tyre slides, how wide it is and
## how heavy the car is; locked wheels (the handbrake, or a car without ABS
## braking hard) mark dark and smoke too; an ABS stop leaves only faint,
## broken marks; a powerful car's burnout lays two black stripes. Wet roads
## take neither marks nor smoke.
func _tyres(delta: float, v: Vector3, moving: float) -> void:
	if _tracks.is_empty():
		_roll_emissions()
	var wheels: Array = _tracks.rear + _tracks.front
	var n_rear: int = _tracks.rear.size()
	var wet: bool = _game != null and _game.atmosphere.wetness > 0.4
	var lateral := absf(v.dot(global_basis.x))
	var pace := absf(speed)
	var rear := lateral if lateral > SLIDE_MARK else 0.0
	var front := 0.0
	var faint := false
	if handbrake and moving > 3.0:
		rear = maxf(rear, moving)
	# A hard stop: the player (or a cop, a chaser) on the brakes at speed.
	# Traffic's ordinary stops leave nothing.
	if (_hard_brake or (braking and moving > 12.0 and driver != Driver.TRAFFIC)) and not drifting:
		if _emit.get("abs", true):
			faint = true
		else:
			rear = maxf(rear, moving)
			front = moving
	if _emit.pops and throttle > 0.9 and pace < 7.0 and _load > 0.4 and driver == Driver.PLAYER:
		rear = maxf(rear, 10.0 - pace)
	if wet or wrecked:
		rear = 0.0
		front = 0.0
		faint = false
	var heavy := clampf(0.75 + mass * 0.1, 0.75, 1.2)
	_abs_dist += moving * delta
	# An ABS stop pulses: about 1.5 m of mark, then a gap.
	var pulse := faint and fmod(_abs_dist, 2.4) < 1.5
	var width: float = _tracks.width
	var smoke := false
	if rear > 4.0 or front > 4.0:
		_tyre_time -= delta
		if _tyre_time <= 0.0:
			var amount := maxf(rear, front) * width * 4.0 * heavy
			_tyre_time = clampf(0.3 / maxf(amount, 0.01), 0.035, 0.25)
			smoke = true
	for i in wheels.size():
		var slide := rear if i < n_rear else front
		var mark := slide > 0.0 or pulse
		if not mark:
			_marking[i] = 0
			continue
		var p: Vector3 = global_transform * (wheels[i] as Vector3)
		if _marking[i] == 0:
			_marking[i] = 1
			_mark_at[i] = p
		elif p.distance_to(_mark_at[i]) >= MARK_STEP:
			var alpha := 0.13 if slide <= 0.0 else clampf(0.22 + slide * 0.035, 0.0, 0.62) * heavy
			Fx.tyre_mark(_mark_at[i], p, width, alpha)
			_mark_at[i] = p
		if smoke and slide > 4.0 and _emit.fuel != "none":
			var r := _erng()
			var c := Emissions.TYRE
			c.a *= clampf(slide / 12.0, 0.3, 1.0)
			Fx.puff(p + Vector3(0, 0.25, 0), -v * 0.15 + Vector3(r.randf_range(-0.6, 0.6), 0.4, r.randf_range(-0.6, 0.6)),
					0.35 + width, 1.4 + slide * 0.06, 2.0, c)


## Rolls this car's engine (fuel, an old diesel, a smoker) once, with older
## cars likelier in the poorer districts, and finds its tailpipes and tracks.
func _roll_emissions() -> void:
	var poor := 0.25
	if _game != null and _game.get("city") != null and _game.city.has_method("district_at"):
		poor = POOR.get(str(_game.city.district_at(global_position).get("style", "")), 0.25)
	var r := RandomNumberGenerator.new()
	r.seed = hash(get_instance_id())
	_emit = Emissions.roll(kind, r, poor)
	_outlets = Emissions.outlets(kind, _size)
	_tracks = Emissions.tracks(kind, _size)
	var n: int = _tracks.rear.size() + _tracks.front.size()
	_mark_at.resize(n)
	_marking.resize(n)
	_marking.fill(0)


static var _fx_rng := RandomNumberGenerator.new()


## Jitter for puffs only (keeps `rng`, which traffic draws on, untouched).
static func _erng() -> RandomNumberGenerator:
	return _fx_rng


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
## `bar`: a police car's light bar may light the road too (Graphics.bars).
func set_real_light(on: bool, energy := 0.0, shadow := false, bar := true) -> void:
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
	if _real_light != null:
		_real_light.visible = on
		_real_light.light_energy = energy
		_real_light.shadow_enabled = on and shadow
		# The bar's own light, made the first time a budget allows it.
		if is_police and bar and _bar_light == null:
			_bar_light = OmniLight3D.new()
			_bar_light.omni_range = 9.0
			_bar_light.omni_attenuation = 1.4
			_bar_light.position = Vector3(0, 1.7, 0.35)
			_bar_light.visible = false
			_model.add_child(_bar_light)
		_bar_on = bar
		if _bar_light != null:
			_bar_light.light_energy = energy * 0.3
			if not on or not bar:
				_bar_light.visible = false
	update_beams()


## Built car meshes by kind and paint, shared by every car alike: building
## one takes 2 to 15 ms, so building each new car in traffic afresh made
## the game stutter (0.21 on Ultra, Sachin, 2026-10-29).
static var _meshes := {}


## Builds every traffic, parked, taxi and police model in each of its
## paints into _meshes while the game loads, so no car's first appearance
## stalls a frame (0.23, Sachin: "Building them all during loading ... Lets
## do this"). 134 meshes, about 0.35 s on a desktop. Mission cars with
## their own paint still build when they first appear.
static func prewarm() -> void:
	var kinds := {"taxi": true}
	for k in VehicleKit.CIVILIAN + VehicleKit.PARKED:
		kinds[k] = true
	for row in VehicleKit.PARKED_BY_TIER:
		for k in row:
			kinds[k] = true
	for k in kinds:
		_prewarm_one(k, VehicleKit.PALETTES.get(k, VehicleKit.PAINTS))
		if VehicleKit.KINDS.get(k, {}).get("convertible", false):
			Convertible.top_meshes(k, true)
			Convertible.top_meshes(k, false)
	_prewarm_one("police", [DEFAULT_PAINT])


static func _prewarm_one(k: String, paints: Array) -> void:
	for paint in paints:
		var key := "%s|%s" % [k, paint.to_html()]
		if _meshes.has(key):
			continue
		var mb := MeshBuilder.new()
		var gloss := MeshBuilder.new()
		VehicleKit.build(mb, k, paint, gloss)
		_meshes[key] = [mb.commit(), gloss.commit()]


func _build_model() -> void:
	var key := "%s|%s" % [kind, body_color.to_html()]
	if not _meshes.has(key):
		var mb := MeshBuilder.new()
		var gloss := MeshBuilder.new()
		VehicleKit.build(mb, kind, body_color, gloss)
		_meshes[key] = [mb.commit(), gloss.commit()]
	_model = MeshInstance3D.new()
	_model.mesh = _meshes[key][0]
	_gloss = MeshInstance3D.new()
	_gloss.mesh = _meshes[key][1]
	_model.add_child(_gloss)
	if _spec.get("convertible", false):
		convertible = Convertible.new(self)
		_model.add_child(convertible)
	_skin(MeshBuilder.material(), MeshBuilder.gloss_material())
	if is_police:
		set_xray(POLICE_XRAY)
	add_child(_model)
	# Beams and the red pool behind lie on the ground, over the hills too
	# (ground_glow_material); the lamps' own glow rides on the car.
	var ground := MeshBuilder.new()
	var glow := MeshBuilder.new()
	var head := Color(0.6, 0.55, 0.38)
	# lamp_x: how far out the headlamps sit, where a kind's differ (the
	# tuk-tuk's twin lamps sit close together on its cowl).
	var lamp_x: float = _spec.get("lamp_x", _size.x * 0.33)
	var lamps := [0.0] if shows_rider else [-lamp_x, lamp_x]
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


## Sets the see-through colour (transparent for none). TopDownCamera draws
## it only while something big hides the car (show_xray).
func set_xray(color: Color) -> void:
	xray_color = color
	if color.a > 0.0:
		add_to_group("xray")
	elif is_in_group("xray"):
		remove_from_group("xray")
	show_xray(xray_shown)


## Draws the see-through silhouette (stencil x-ray) or the plain paint.
func show_xray(on: bool) -> void:
	xray_shown = on and xray_color.a > 0.0
	if wrecked:
		return
	if xray_shown:
		_skin(MeshBuilder.xray_material(xray_color), _gloss_xray(xray_color))
	else:
		_skin(MeshBuilder.material(), MeshBuilder.gloss_material())


## Materials for the matte body and its glossy glass/paint shell (both get
## stencil x-ray together, so the whole car shows through buildings).
func _skin(body: Material, shell: Material) -> void:
	_model.material_override = body
	_gloss.material_override = shell
	if convertible != null:
		convertible.skin(body, shell)


static var _gloss_xrays := {}


## The glossy material with the same stencil x-ray as MeshBuilder.xray_material.
static func _gloss_xray(color: Color) -> StandardMaterial3D:
	if not _gloss_xrays.has(color):
		var mat: StandardMaterial3D = MeshBuilder.gloss_material().duplicate()
		mat.stencil_mode = BaseMaterial3D.STENCIL_MODE_XRAY
		mat.stencil_color = color
		_gloss_xrays[color] = mat
	return _gloss_xrays[color]
