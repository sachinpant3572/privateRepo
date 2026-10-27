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

const REVERSE_SPEED := 8.0
const BRAKE := 32.0
const COAST := 4.0
const GRIP := 8.0
const DRIFT_GRIP := 1.5
const TRAFFIC_THROTTLE := 0.5
const POLICE_XRAY := Color(0.3, 0.55, 1.0, 0.6)

var driver := Driver.NONE
var is_police := false
## Body style from VehicleKit.KINDS; sets the model and the handling.
var kind := "sedan"
var body_color := Color(0.8, 0.15, 0.15)
var city
var occupant = null
var health := 100.0
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
var _stuck_time := 0.0
var _reverse_time := 0.0
var _deployed := false
var _light_time := 0.0
var _lights: Array[MeshInstance3D] = []
var _model: MeshInstance3D
var _ahead: RayCast3D
var _beams: MeshInstance3D
var _size := Vector3.ONE
var _skid_dist := 0.0
var _smoke_time := 0.0
var _splash_time := 0.0
var _hard_brake := false
var _game


func _ready() -> void:
	add_to_group("vehicles")
	motion_mode = MOTION_MODE_FLOATING
	collision_layer = L.VEHICLES
	collision_mask = L.WORLD | L.PROPS | L.VEHICLES | L.CHARACTERS
	if is_police:
		kind = "police"
	var spec: Dictionary = VehicleKit.KINDS.get(kind, VehicleKit.KINDS.sedan)
	max_speed = spec.max_speed
	accel = spec.accel
	turn_rate = spec.turn
	shows_rider = spec.get("rider", false)
	var size: Vector3 = spec.size
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


## Keeps a scooter's rider in the saddle and passengers inside.
func _carry() -> void:
	if rider != null and is_instance_valid(rider):
		rider.global_position = global_position
		rider.rotation.y = rotation.y
	for p in passengers:
		if is_instance_valid(p):
			p.global_position = global_position


## Everyone riding gets out (wrecks, mission ends).
func unload_all() -> void:
	if rider != null and is_instance_valid(rider):
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
		_model.material_override = MeshBuilder.xray_material()


func release_player() -> void:
	occupant = null
	driver = Driver.NONE
	if not wrecked:
		_model.material_override = MeshBuilder.material()


## Drives as traffic, setting off from junction `from` towards `to`.
func start_traffic(c, from: int, to: int) -> void:
	city = c
	driver = Driver.TRAFFIC
	_prev_node = from
	_next_node = to


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


func bump(push: Vector3) -> void:
	velocity += push
	speed *= 0.6
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
	if Vector2(target.x - global_position.x, target.z - global_position.z).length() < 5.0:
		var nxt: int = city.pick_turn(_prev_node, _next_node, rng)
		_prev_node = _next_node
		_next_node = nxt
		target = city.lane_point(_prev_node, _next_node)
	var to := target - global_position
	to.y = 0.0
	desired_dir = to.normalized()
	throttle = TRAFFIC_THROTTLE
	braking = _ahead.is_colliding()


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


func _drive(delta: float) -> void:
	var fwd := -global_basis.z
	var target := 0.0
	if desired_dir != Vector3.ZERO:
		var angle := fwd.signed_angle_to(desired_dir, Vector3.UP)
		if absf(angle) > deg_to_rad(120.0) and speed < 3.0:
			target = -REVERSE_SPEED * throttle
			angle = (-fwd).signed_angle_to(desired_dir, Vector3.UP)
		else:
			# Ease off for sharp corners so the car can make the turn.
			target = max_speed * throttle * lerpf(1.0, 0.45, absf(angle) / PI)
		var grip_turn := clampf(absf(speed) / 5.0, 0.0, 1.0)
		var turn := clampf(angle * 2.0, -1.0, 1.0) * turn_rate * grip_turn * delta
		rotate_y(turn * (1.6 if handbrake else 1.0))

	var rate := accel
	_hard_brake = false
	if desired_dir == Vector3.ZERO:
		rate = COAST
	elif signf(target) != signf(speed) and absf(speed) > 0.5:
		rate = BRAKE
		_hard_brake = absf(speed) > 9.0
	elif absf(target) < absf(speed):
		rate = COAST * 2.0
	speed = move_toward(speed, target, rate * delta)
	if braking or handbrake:
		speed = move_toward(speed, 0.0, (BRAKE if braking else 10.0) * delta)

	var want := -global_basis.z * speed
	var grip := DRIFT_GRIP if handbrake else GRIP
	velocity = Vector3(velocity.x, 0.0, velocity.z).lerp(want, clampf(grip * delta, 0.0, 1.0))
	var before := velocity
	move_and_slide()
	global_position.y = 0.0
	_handle_collisions(before)


func _handle_collisions(before: Vector3) -> void:
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var other := col.get_collider()
		if other != null and other.has_method("hit_by_vehicle"):
			if before.length() > 2.5 and not other.dead:
				Fx.hit(other.global_position, true, driver == Driver.PLAYER)
			other.hit_by_vehicle(self, before.length())
			continue
		var impact := absf(before.dot(col.get_normal()))
		if impact < 4.0:
			continue
		var players: bool = driver == Driver.PLAYER or (other != null and other.get("driver") == Driver.PLAYER)
		Fx.crash(col.get_position(), impact, players)
		speed *= 0.5
		_damage(impact * 0.6)
		if other != null and other.has_method("bump"):
			other.bump(before * 0.6)


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
	_model.material_override = mat
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
	if health < 45.0:
		_smoke_time -= delta
		if _smoke_time <= 0.0:
			_smoke_time = 0.35 if not wrecked else 0.2
			Fx.smoke(global_transform * Vector3(0, 1.0, -_size.z * 0.3), 0.9 if not wrecked else 1.4)
	if _beams != null:
		_beams.visible = not wrecked and (driver != Driver.NONE or _deployed) and _game != null and _game.atmosphere.night_amount() > 0.05


func _build_model() -> void:
	var mb := MeshBuilder.new()
	VehicleKit.build(mb, kind, body_color)
	_model = mb.make_instance()
	if is_police:
		_model.material_override = MeshBuilder.xray_material(POLICE_XRAY)
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
			bar.size = Vector3(0.5, 0.15, 0.3)
			light.mesh = bar
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = Color(0.9, 0.1, 0.1) if i == 0 else Color(0.1, 0.3, 1.0)
			light.material_override = mat
			light.position = Vector3(-0.3 if i == 0 else 0.3, 1.49, 0.35)
			add_child(light)
			_lights.append(light)
