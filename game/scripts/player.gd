extends "res://scripts/humanoid.gd"
## The player: on foot, punching, and getting in and out of cars.

const VehicleKit = preload("res://scripts/kits/vehicle_kit.gd")
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
	# Finer mesh and white racing stripes over the shoulders and across the
	# back, so the hero reads at a glance from the street camera.
	"hero": true, "stripes": Color(0.96, 0.96, 0.94),
}

var vehicle = null
## Riding in the back of a cab (taxi.gd), not driving it.
var passenger := false
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
		if riding and anim != null: # pedalling a bicycle
			anim.pedal = VehicleKit.pedal_angle(vehicle.kind, anim.pedal, vehicle.speed, delta)
		if controllable and Controls.just_pressed("interact"):
			var game = get_tree().get_first_node_in_group("game") if passenger else null
			if game != null and game.taxi != null:
				game.taxi.request_exit() # the cab pulls up and you pay
			else:
				exit_vehicle()
		return
	super(delta)


func _think(delta: float) -> void:
	if not controllable:
		velocity = Vector3.ZERO
		style = ""
		return
	var dir := Controls.world_move()
	var sprinting := Input.is_action_pressed("sprint")
	var speed := SPRINT_SPEED if sprinting else JOG_SPEED
	walk(dir, speed, delta)
	# Badly hurt, Jules runs holding his side; sprinting pumps the arms.
	var moving := dir.length_squared() > 0.01
	style = "limp" if health < max_health * 0.3 else ("sprint" if sprinting and moving else "")
	if Controls.just_pressed("attack"):
		punch()
	if Controls.just_pressed("interact"):
		var game = get_tree().get_first_node_in_group("game")
		if game == null or game.interiors == null or not game.interiors.try_interact():
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
	var game = get_tree().get_first_node_in_group("game")
	# The cab waiting for us wins over any car that happens to be nearer.
	if game != null and game.taxi != null and is_instance_valid(game.taxi.cab) \
			and global_position.distance_to(game.taxi.cab.global_position) < ENTER_RANGE \
			and game.taxi.board(game.taxi.cab):
		return
	var car = nearest_vehicle()
	if car == null:
		return
	if game != null and game.taxi != null and game.taxi.board(car):
		return # the cab that pulled over for us: in the back, not a carjacking
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
	GameLog.event("enter_car", {"car": car.kind, "model": car.model_name(), "stolen": car.has_ai_driver(), "at": car.global_position})
	car.take_player(self)
	riding = car.shows_rider
	visible = riding
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0


## In the back of a cab: hidden and carried, the cab keeps its driver.
func enter_as_passenger(car) -> void:
	vehicle = car
	GameLog.event("enter_car", {"car": car.kind, "passenger": true, "at": car.global_position})
	passenger = true
	riding = false
	visible = false
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0


func exit_vehicle(thrown := false) -> void:
	var car = vehicle
	if car == null:
		return
	GameLog.event("exit_car", {"car": car.kind, "thrown": thrown, "speed": absf(car.speed) * 3.6, "car_hp": car.health, "at": car.global_position})
	vehicle = null
	riding = false
	sitting = false # in an open car's seat (convertible.gd)
	if anim != null:
		anim.car = 0
		anim.pedal = -1.0
	var was_passenger := passenger
	passenger = false
	if not was_passenger:
		car.release_player()
	# Passengers step out on the curb side.
	global_position = _free_spot_beside(car, was_passenger)
	reset_physics_interpolation()
	visible = true
	_set_standing_layers()
	if dead:
		knock_down(0.0) # lie where they fell, out of the way
	if thrown:
		take_hit(null, 25.0, Vector3.ZERO)


func respawn(at: Vector3) -> void:
	if vehicle != null:
		exit_vehicle()
	revive(at)
	controllable = true


func _free_spot_beside(car, curb_first := false) -> Vector3:
	var b: Basis = car.global_basis
	var origin: Vector3 = car.global_position
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.45
	query.shape = sphere
	query.collision_mask = L.WORLD | L.PROPS | L.VEHICLES
	query.exclude = [car.get_rid()]
	var space := get_world_3d().direct_space_state
	var sides := [b.x * 1.8, -b.x * 1.8] if curb_first else [-b.x * 1.8, b.x * 1.8]
	for offset in sides + [b.z * 3.0, -b.z * 3.0]:
		var spot: Vector3 = origin + offset
		spot.y = 0.0
		query.transform = Transform3D(Basis(), spot + Vector3(0, 0.9, 0))
		if space.intersect_shape(query, 1).is_empty():
			return spot
	return Vector3(origin.x, 0.0, origin.z) + (b.x if curb_first else -b.x) * 1.8
