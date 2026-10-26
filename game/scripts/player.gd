extends "res://scripts/humanoid.gd"
## The player: on foot, punching, and getting in and out of cars.

const JOG_SPEED := 4.2
const SPRINT_SPEED := 7.0
const ENTER_RANGE := 3.5

var vehicle = null
var controllable := true


func _init() -> void:
	shirt = Color(0.85, 0.18, 0.2)
	pants = Color(0.18, 0.3, 0.55)
	skin = SKIN_TONES[1]
	punch_damage = 15.0
	xray = true


func _ready() -> void:
	super()
	add_to_group("player")


func _physics_process(delta: float) -> void:
	if vehicle != null:
		global_position = vehicle.global_position
		if controllable and Controls.just_pressed("interact"):
			exit_vehicle()
		return
	super(delta)


func _think(delta: float) -> void:
	if not controllable:
		velocity = Vector3.ZERO
		return
	var dir := Controls.world_move()
	var speed := SPRINT_SPEED if Input.is_action_pressed("sprint") else JOG_SPEED
	walk(dir, speed, delta)
	if Controls.just_pressed("attack"):
		punch()
	if Controls.just_pressed("interact"):
		try_enter_vehicle()


## The node the camera and police should track.
func focus_node() -> Node3D:
	return vehicle if vehicle != null else self


func nearest_vehicle():
	var best = null
	var best_d := ENTER_RANGE
	for car in get_tree().get_nodes_in_group("vehicles"):
		if car.wrecked:
			continue
		var d := global_position.distance_to(car.global_position)
		if d < best_d:
			best = car
			best_d = d
	return best


func try_enter_vehicle() -> void:
	var car = nearest_vehicle()
	if car == null:
		return
	var game = get_tree().get_first_node_in_group("game")
	if car.has_ai_driver():
		# Carjacking: the driver is thrown out and the crime is reported.
		var door: Vector3 = car.global_position - car.global_basis.x * 1.8
		if car.is_police:
			var cop = game.police.spawn_cop_at(door)
			cop.aggro_time = 5.0
			Wanted.report_crime(2)
		else:
			var ped = game.population.spawn_ped_at(door)
			ped.flee_from(self)
			Wanted.report_crime(1)
	elif car.is_police:
		Wanted.report_crime(2)
	enter_vehicle(car)


func enter_vehicle(car) -> void:
	vehicle = car
	car.take_player(self)
	visible = false
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0


func exit_vehicle(thrown := false) -> void:
	var car = vehicle
	if car == null:
		return
	vehicle = null
	car.release_player()
	global_position = _free_spot_beside(car)
	reset_physics_interpolation()
	visible = true
	_set_standing_layers()
	if thrown:
		take_hit(null, 25.0, Vector3.ZERO)


func respawn(at: Vector3) -> void:
	if vehicle != null:
		exit_vehicle()
	revive(at)
	controllable = true


func _free_spot_beside(car) -> Vector3:
	var b: Basis = car.global_basis
	var origin: Vector3 = car.global_position
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.45
	query.shape = sphere
	query.collision_mask = L.WORLD | L.VEHICLES
	query.exclude = [car.get_rid()]
	var space := get_world_3d().direct_space_state
	for offset in [-b.x * 1.8, b.x * 1.8, b.z * 3.0, -b.z * 3.0]:
		var spot: Vector3 = origin + offset
		spot.y = 0.0
		query.transform = Transform3D(Basis(), spot + Vector3(0, 0.9, 0))
		if space.intersect_shape(query, 1).is_empty():
			return spot
	return Vector3(origin.x, 0.0, origin.z) - b.x * 1.8
