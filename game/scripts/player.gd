extends "res://scripts/humanoid.gd"
## The player: on foot, punching, and getting in and out of cars.

const VehicleKit = preload("res://scripts/kits/vehicle_kit.gd")
const JOG_SPEED := 4.2
const SPRINT_SPEED := 7.0
const ACCEL := 18.0 # m/s²: about a quarter second from standing to a jog
const DECEL := 26.0 # stops and turns back a little quicker than he starts
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

## Bailing out of a helicopter (#82): a drop up to BAIL_SAFE metres is
## shrugged off, each metre more costs BAIL_HURT health (about 17 m kills).
const BAIL_SAFE := 2.5
const BAIL_HURT := 7.0

var vehicle = null
## Riding in the back of a cab (taxi.gd), not driving it.
var passenger := false
var controllable := true
## A bail-out's fall: metres still to drop, speed down, and the height it
## began at.
var _fall := 0.0
var _fall_v := 0.0
var _fall_from := 0.0


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
			elif vehicle.has_method("exit_check") and vehicle.exit_check() == "roof":
				# Nobody stands on a roof here: land on open ground first.
				var g = get_tree().get_first_node_in_group("game")
				if g != null and g.hud != null:
					g.hud.show_banner("Land on open ground to get out")
			else:
				exit_vehicle()
		return
	super(delta)
	if _fall > 0.0:
		# Bailed out of a helicopter: down to the ground, hurt by the drop.
		_fall_v += 9.8 * delta
		_fall -= _fall_v * delta
		if _fall <= 0.0:
			_fall = 0.0
			GameLog.event("bail_landed", {"from": _fall_from})
			take_hit(null, maxf(_fall_from - BAIL_SAFE, 0.0) * BAIL_HURT, Vector3.ZERO)
			Fx.crash(global_position, _fall_v, true)
		else:
			global_position.y += _fall


func _think(delta: float) -> void:
	if not controllable:
		velocity = Vector3.ZERO
		style = ""
		return
	var dir := Controls.world_move()
	var sprinting := Input.is_action_pressed("sprint")
	var speed := SPRINT_SPEED if sprinting else JOG_SPEED
	# Speed builds and drops over a few steps instead of jumping, so starts
	# lean in and stops plant a foot.
	dir.y = 0.0
	var want := dir * speed
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var rate := ACCEL if want.dot(flat) >= 0.0 and want.length_squared() > flat.length_squared() else DECEL
	velocity = flat.move_toward(want, rate * delta)
	if dir.length_squared() > 0.01:
		face(dir, delta)
	# Badly hurt, Jules runs holding his side; sprinting pumps the arms.
	var moving := dir.length_squared() > 0.01
	style = "limp" if health < max_health * 0.3 else ("sprint" if sprinting and moving else "")
	if Controls.just_pressed("attack"):
		punch()
	if Controls.just_pressed("interact"):
		var game = get_tree().get_first_node_in_group("game")
		# The waiting cab comes before a shop door, as the HUD offers them.
		if _board_waiting_cab(game):
			pass
		elif game == null or game.interiors == null or not game.interiors.try_interact():
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


## Boards the cab waiting for us when it is in reach. True when it did.
func _board_waiting_cab(game) -> bool:
	return game != null and game.taxi != null and is_instance_valid(game.taxi.cab) \
			and global_position.distance_to(game.taxi.cab.global_position) < ENTER_RANGE \
			and game.taxi.board(game.taxi.cab)


func try_enter_vehicle() -> void:
	var game = get_tree().get_first_node_in_group("game")
	# The cab waiting for us wins over any car that happens to be nearer.
	if _board_waiting_cab(game):
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
	# Out of a helicopter in the air: a jump, and the fall to the ground.
	# Thrown out high over a roof (a wreck), the fall is to open ground
	# nearby; wrecked while sitting on the roof, they get down unhurt by a fall.
	var check: String = car.exit_check() if car.has_method("exit_check") else ""
	var bail: bool = check == "bail" or (thrown and check == "roof" and car.height_over_floor() > car.LOW)
	var from_y: float = car.global_position.y
	if not was_passenger:
		car.release_player()
	# Passengers step out on the curb side.
	global_position = _free_spot_beside(car, was_passenger)
	if check == "roof":
		global_position = car.open_ground_near(global_position)
	reset_physics_interpolation()
	visible = true
	_set_standing_layers()
	if dead:
		knock_down(0.0) # lie where they fell, out of the way
	if bail:
		var ground := Terrain.height(global_position.x, global_position.z) - Terrain.drop(global_position.x, global_position.z)
		_fall_from = maxf(from_y + 0.5 - ground, 0.0)
		_fall = _fall_from
		_fall_v = 0.0
		global_position.y = ground + _fall
		reset_physics_interpolation()
		knock_down(sqrt(2.0 * _fall / 9.8) + 1.2)
		GameLog.event("bail", {"height": _fall_from})
	if thrown:
		take_hit(null, 25.0, Vector3.ZERO)


func respawn(at: Vector3) -> void:
	if vehicle != null:
		exit_vehicle()
	_fall = 0.0
	_fall_v = 0.0
	revive(at)
	controllable = true


## Put down at `at` on its feet: out of any vehicle, with no fall from a bail
## to finish (a mission replay moves the player mid-flight).
func stand_at(at: Vector3) -> void:
	if vehicle != null:
		exit_vehicle()
	_fall = 0.0
	_fall_v = 0.0
	if not dead and knocked_time > 0.0:
		knocked_time = 0.0
		_set_standing_layers()
	global_position = at
	reset_physics_interpolation()


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
		spot.y = Terrain.height(spot.x, spot.z) - Terrain.drop(spot.x, spot.z)
		query.transform = Transform3D(Basis(), spot + Vector3(0, 0.9, 0))
		if space.intersect_shape(query, 1).is_empty():
			return spot
	var fallback: Vector3 = origin + (b.x if curb_first else -b.x) * 1.8
	fallback.y = Terrain.height(fallback.x, fallback.z) - Terrain.drop(fallback.x, fallback.z)
	return fallback
