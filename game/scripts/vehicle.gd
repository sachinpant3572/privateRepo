extends CharacterBody3D
## Arcade car shared by the player, traffic and police.
## Steering is direction-based: the car turns toward a requested world
## direction (reversing when it points well behind), which suits a touch
## joystick under a top-down camera.

const MeshBuilder = preload("res://scripts/mesh_builder.gd")
const VehicleKit = preload("res://scripts/kits/vehicle_kit.gd")
const L = preload("res://scripts/layers.gd")

signal officer_deployed(car)
## A SCRIPT driver reached the end of its path.
signal path_done(car)

## SCRIPT drives a mission path; CHASER hunts the player like police do.
enum Driver { NONE, PLAYER, TRAFFIC, POLICE, SCRIPT, CHASER }

const COAST := 4.0
const TRAFFIC_THROTTLE := 0.5
## Traffic never cruises faster than this (m/s), whatever the model.
const TRAFFIC_CRUISE := 13.0
## Traffic slows to this (m/s) within TRAFFIC_SLOW_ZONE (m) of a junction.
const TRAFFIC_TURN_SPEED := 6.5
const TRAFFIC_SLOW_ZONE := 16.0
## Traffic steers for the point this far (m) ahead along its lane.
const TRAFFIC_LOOKAHEAD := 9.0
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
var _deployed := false
var _light_time := 0.0
var _lights: Array[MeshInstance3D] = []
var _model: MeshInstance3D
## Glass and paint shell, a child of _model drawn with the glossy material.
var _gloss: MeshInstance3D
var _ahead: RayCast3D
var _beams: MeshInstance3D
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
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x + 0.1, 1.2, size.z + 0.1)
	shape.shape = box
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
	# Skip the junction just behind us; drive on to the next one.
	var fwd := -global_basis.z
	while path_index < path.size() - 1:
		var to := path[path_index] - global_position
		if to.dot(fwd) >= 0.0 or to.length() > 30.0:
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
	throttle = script_throttle
	braking = _ahead.is_colliding() and _ahead.get_collider() != null and _ahead.get_collider().get("driver") != Driver.PLAYER


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
	if not wrecked:
		_skin(MeshBuilder.material(), MeshBuilder.gloss_material())


## Drives as traffic, setting off from junction `from` towards `to`.
func start_traffic(c, from: int, to: int) -> void:
	city = c
	driver = Driver.TRAFFIC
	_prev_node = from
	_next_node = to
	_after_node = -1


## Hands a police car (or a stolen car left behind) back to normal traffic.
func join_traffic_here() -> void:
	var fwd := -global_basis.z
	var ahead: int = city.nearest_node(global_position + fwd * 25.0)
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


## Hit by another vehicle: `push` is already scaled by the two masses (see
## _handle_collisions); a hard shove costs up to 40% of our speed.
func bump(push: Vector3) -> void:
	velocity += push
	speed *= lerpf(1.0, 0.6, clampf(push.length() / 6.0, 0.0, 1.0))
	_damage(push.length())


func _player_input() -> void:
	var dir := Controls.world_move()
	throttle = dir.length()
	if throttle > 0.05:
		desired_dir = dir / throttle
	handbrake = Input.is_action_pressed("sprint")


func _traffic_ai() -> void:
	if _next_node < 0:
		throttle = 0.0
		return
	var target: Vector3 = city.lane_point(_prev_node, _next_node)
	var near := Vector2(target.x - global_position.x, target.z - global_position.z).length()
	if near < TRAFFIC_SLOW_ZONE and _after_node < 0:
		_after_node = city.pick_turn(_prev_node, _next_node, rng)
	var turn_in := false
	if _after_node >= 0:
		var ls: Vector3 = city.lane_start(_next_node, _after_node)
		turn_in = Vector2(ls.x - global_position.x, ls.z - global_position.z).length() < 4.0
	if near < 5.0 or turn_in:
		var nxt: int = _after_node if _after_node >= 0 else city.pick_turn(_prev_node, _next_node, rng)
		_prev_node = _next_node
		_next_node = nxt
		_after_node = -1
		target = city.lane_point(_prev_node, _next_node)
	var to := target - global_position
	to.y = 0.0
	# Follow the lane line a few metres ahead rather than aiming straight at
	# the far junction, so a car that turned wide finds its own side of a
	# boulevard median again instead of cutting across it.
	var a: Vector3 = city.lane_start(_prev_node, _next_node) if _prev_node >= 0 else global_position
	var ab := target - a
	ab.y = 0.0
	var aim := target
	if ab.length() > TRAFFIC_LOOKAHEAD:
		var t := clampf((global_position - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		aim = a + ab * minf(1.0, t + TRAFFIC_LOOKAHEAD / ab.length())
	aim.y = global_position.y
	desired_dir = (aim - global_position).normalized() if aim.distance_to(global_position) > 0.5 else to.normalized()
	throttle = minf(TRAFFIC_THROTTLE, TRAFFIC_CRUISE / max_speed)
	if to.length() < TRAFFIC_SLOW_ZONE:
		# Slow for the junction, so heavy, understeering models still make
		# the turn instead of running wide (onto a boulevard median).
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
	if absf(speed) < 1.0 and d > 6.0:
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
		var grip_turn: float = clampf(pace / _spec.steer_low, 0.0, 1.0) * (1.0 - _spec.steer_fade * clampf(pace / max_speed, 0.0, 1.0))
		steer = clampf(angle * 2.0, -1.0, 1.0)
		yaw = steer * turn_rate * grip_turn * delta * (1.6 if handbrake else 1.0)
		rotate_y(yaw)

	var rate: float = accel * (1.0 - _spec.power_fade * clampf(pace / max_speed, 0.0, 1.0))
	_hard_brake = false
	if desired_dir == Vector3.ZERO:
		rate = COAST
	elif signf(target) != signf(speed) and pace > 0.5:
		rate = _spec.brake
		_hard_brake = pace > 9.0
	elif absf(target) < pace:
		rate = COAST * 2.0
	speed = move_toward(speed, target, rate * delta)
	if braking or handbrake:
		speed = move_toward(speed, 0.0, (_spec.brake if braking else 10.0) * delta)

	var want := -global_basis.z * speed
	var grip: float = _spec.drift if handbrake else _spec.grip
	grip *= 1.0 - _spec.slide * throttle * absf(steer) * clampf(pace / 10.0, 0.0, 1.0)
	velocity = Vector3(velocity.x, 0.0, velocity.z).lerp(want, clampf(grip * delta, 0.0, 1.0))
	var before := velocity
	move_and_slide()
	global_position.y = 0.0
	# Tilt follows how the body really moves, so a car pinned against a
	# wall with the throttle down stays level.
	var moved := velocity.dot(-global_basis.z)
	_body_tilt(delta, moved * yaw / delta, (moved - _moved) / delta)
	_moved = moved
	_handle_collisions(before)


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
	_model.transform = Transform3D(b, pivot - b * pivot)


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
		var impact := absf(before.dot(col.get_normal()))
		if driver == Driver.TRAFFIC:
			if other != null and other.has_method("bump"):
				if _yield_time < -1.0:
					_yield_time = rng.randf_range(0.3, 2.0)
			elif impact > 2.0 and _reverse_time <= 0.0 and before.dot(-global_basis.z) > 0.0:
				_reverse_time = 1.2 if _since_reverse > 3.0 else minf(_last_reverse + 0.8, 3.2)
				_last_reverse = _reverse_time
				# A floating body keeps its velocity into the wall, which would
				# count the same crash again for several frames; for traffic
				# the crash is one hit.
				if velocity.dot(col.get_normal()) < 0.0:
					velocity = velocity.slide(col.get_normal())
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
			speed *= 0.5
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
	if _beams != null:
		_beams.visible = not wrecked and (driver != Driver.NONE or _deployed) and _game != null and _game.atmosphere.night_amount() > 0.05


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
	var glow := MeshBuilder.new()
	var head := Color(0.6, 0.55, 0.38)
	var lamps := [0.0] if shows_rider else [-_size.x * 0.33, _size.x * 0.33]
	for x in lamps:
		glow.light_beam(Vector3(x, 0.05, -_size.z * 0.5), Vector3.FORWARD, 13.0, 3.2, head)
		glow.light_pool(Vector3(x, 0.7, -_size.z * 0.5 - 0.1), Vector2(0.5, 0.35), Color(1.0, 0.95, 0.8))
	glow.light_pool(Vector3(0, 0.08, _size.z * 0.5 + 0.6), Vector2(_size.x * 0.7, 1.2), Color(0.5, 0.05, 0.04))
	_beams = glow.make_instance()
	_beams.material_override = MeshBuilder.glow_material()
	_beams.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beams.visible = false
	add_child(_beams)
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
