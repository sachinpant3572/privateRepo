extends CharacterBody3D
## Arcade car shared by the player, traffic and police.
## Steering is direction-based: the car turns toward a requested world
## direction (reversing when it points well behind), which suits a touch
## joystick under a top-down camera.

const MeshBuilder = preload("res://scripts/mesh_builder.gd")
const L = preload("res://scripts/layers.gd")

signal officer_deployed(car)

enum Driver { NONE, PLAYER, TRAFFIC, POLICE }

const MAX_SPEED := 24.0
const REVERSE_SPEED := 8.0
const ACCEL := 14.0
const BRAKE := 32.0
const COAST := 4.0
const TURN_RATE := 2.4
const GRIP := 8.0
const DRIFT_GRIP := 1.5
const TRAFFIC_THROTTLE := 0.5
const POLICE_XRAY := Color(0.3, 0.55, 1.0, 0.6)
const COLORS := [Color(0.8, 0.15, 0.15), Color(0.15, 0.35, 0.75), Color(0.95, 0.8, 0.2), Color(0.2, 0.55, 0.3), Color(0.9, 0.9, 0.9), Color(0.15, 0.15, 0.17), Color(0.6, 0.3, 0.6)]

var driver := Driver.NONE
var is_police := false
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
var _next_node := Vector2i.ZERO
var _heading := Vector2i(1, 0)
var _stuck_time := 0.0
var _reverse_time := 0.0
var _deployed := false
var _light_time := 0.0
var _lights: Array[MeshInstance3D] = []
var _model: MeshInstance3D
var _ahead: RayCast3D


func _ready() -> void:
	add_to_group("vehicles")
	motion_mode = MOTION_MODE_FLOATING
	collision_layer = L.VEHICLES
	collision_mask = L.WORLD | L.VEHICLES | L.CHARACTERS
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 1.2, 4.3)
	shape.shape = box
	shape.position.y = 0.6
	add_child(shape)
	_ahead = RayCast3D.new()
	_ahead.position = Vector3(0, 0.7, -2.3)
	_ahead.target_position = Vector3(0, 0, -8.0)
	_ahead.collision_mask = L.VEHICLES | L.CHARACTERS
	add_child(_ahead)
	_ahead.add_exception(self)
	_build_model()


func _physics_process(delta: float) -> void:
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
			Driver.POLICE:
				_police_ai(delta)
	_drive(delta)
	_flash_lights(delta)


func has_ai_driver() -> bool:
	return driver == Driver.TRAFFIC or driver == Driver.POLICE


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


func start_traffic(c, from: Vector2i, heading: Vector2i) -> void:
	city = c
	driver = Driver.TRAFFIC
	_heading = heading
	_next_node = from + heading


## Hands a police car (or a stolen car left behind) back to normal traffic.
func join_traffic_here() -> void:
	var fwd := -global_basis.z
	var heading := Vector2i(signi(roundi(fwd.x)), 0) if absf(fwd.x) > absf(fwd.z) else Vector2i(0, signi(roundi(fwd.z)))
	if heading == Vector2i.ZERO:
		heading = Vector2i(1, 0)
	var n: Vector2i = city.nearest_node(global_position + fwd * city.PITCH * 0.5)
	driver = Driver.TRAFFIC
	_heading = heading
	_next_node = n if city.in_grid(n) else city.nearest_node(global_position)


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
	var target: Vector3 = city.lane_point(_next_node, _heading)
	if Vector2(target.x - global_position.x, target.z - global_position.z).length() < 5.0:
		_heading = city.pick_turn(_next_node, _heading, rng)
		_next_node += _heading
		target = city.lane_point(_next_node, _heading)
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
		# Close to a player on foot: stop and send an officer out.
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
			target = MAX_SPEED * throttle * lerpf(1.0, 0.45, absf(angle) / PI)
		var grip_turn := clampf(absf(speed) / 5.0, 0.0, 1.0)
		var turn := clampf(angle * 2.0, -1.0, 1.0) * TURN_RATE * grip_turn * delta
		rotate_y(turn * (1.6 if handbrake else 1.0))

	var rate := ACCEL
	if desired_dir == Vector3.ZERO:
		rate = COAST
	elif signf(target) != signf(speed) and absf(speed) > 0.5:
		rate = BRAKE
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
			other.hit_by_vehicle(self, before.length())
			continue
		var impact := absf(before.dot(col.get_normal()))
		if impact < 4.0:
			continue
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


func _build_model() -> void:
	var mb := MeshBuilder.new()
	var paint := Color(0.95, 0.95, 0.95) if is_police else body_color
	mb.box(Vector3(0, 0.55, 0), Vector3(1.9, 0.6, 4.2), paint)
	mb.box(Vector3(0, 1.1, 0.35), Vector3(1.7, 0.55, 2.1), Color(0.12, 0.16, 0.2))
	mb.box(Vector3(0, 1.39, 0.35), Vector3(1.6, 0.04, 1.9), paint)
	for x in [-0.9, 0.9]:
		for z in [-1.35, 1.35]:
			mb.box(Vector3(x, 0.35, z), Vector3(0.3, 0.7, 0.8), Color(0.07, 0.07, 0.07))
		mb.box(Vector3(x * 0.65, 0.62, -2.11), Vector3(0.4, 0.15, 0.04), Color(1.0, 0.95, 0.7))
		mb.box(Vector3(x * 0.65, 0.62, 2.11), Vector3(0.4, 0.15, 0.04), Color(0.8, 0.1, 0.1))
	if is_police:
		mb.box(Vector3(0, 0.45, 0), Vector3(1.94, 0.22, 4.24), Color(0.05, 0.06, 0.1))
	_model = mb.make_instance()
	if is_police:
		_model.material_override = MeshBuilder.xray_material(POLICE_XRAY)
	add_child(_model)
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
