extends "res://scripts/humanoid.gd"
## The player: on foot, punching, and getting in and out of cars.

const JOG_SPEED := 4.2
const SPRINT_SPEED := 7.0
const ENTER_RANGE := 3.5

## Jules: red zip jacket over a white tee, turned-up jeans, chunky white
## sneakers with a red stripe, short dark hair.
const JULES := {
	"outfit": "jacket", "jacket": Color(0.82, 0.16, 0.18), "shirt": Color(0.95, 0.95, 0.93),
	"bottoms": "jeans", "pants": Color(0.18, 0.3, 0.55), "shoes": Color(0.95, 0.95, 0.95),
	"shoe_accent": Color(0.82, 0.16, 0.18), "skin": Color(0.6, 0.42, 0.28),
	"hair": "fade", "hair_color": Color(0.08, 0.06, 0.05), "build": 1.05,
}

var vehicle = null
var controllable := true


func _init() -> void:
	look = JULES
	punch_damage = 15.0
	can_kick = true
	xray_color = Color(1.0, 0.85, 0.25, 0.6)


func _ready() -> void:
	super()
	add_to_group("player")


func _physics_process(delta: float) -> void:
	if vehicle != null:
		global_position = vehicle.global_position
		rotation.y = vehicle.rotation.y
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
	if car.rider != null:
		# Knocking a mission rider off their scooter.
		var rider = car.rider
		car.unload_all()
		rider.take_hit(self, 10.0, car.global_basis.x)
		car.driver = car.Driver.NONE
	elif car.has_ai_driver():
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
	riding = car.shows_rider
	visible = riding
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0


func exit_vehicle(thrown := false) -> void:
	var car = vehicle
	if car == null:
		return
	vehicle = null
	riding = false
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
	query.collision_mask = L.WORLD | L.PROPS | L.VEHICLES
	query.exclude = [car.get_rid()]
	var space := get_world_3d().direct_space_state
	for offset in [-b.x * 1.8, b.x * 1.8, b.z * 3.0, -b.z * 3.0]:
		var spot: Vector3 = origin + offset
		spot.y = 0.0
		query.transform = Transform3D(Basis(), spot + Vector3(0, 0.9, 0))
		if space.intersect_shape(query, 1).is_empty():
			return spot
	return Vector3(origin.x, 0.0, origin.z) - b.x * 1.8
