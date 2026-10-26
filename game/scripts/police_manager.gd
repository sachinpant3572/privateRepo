extends Node
## Spawns, steers and retires police for the current wanted level, and tells
## the wanted system whether any unit can see the player.

const Cop = preload("res://scripts/cop.gd")
const Vehicle = preload("res://scripts/vehicle.gd")
const L = preload("res://scripts/layers.gd")

const FOOT_COPS := [0, 2, 3]
const POLICE_CARS := [0, 0, 2]
const SIGHT_RANGE := 35.0
const RETIRE_DISTANCE := 60.0

var game
var cops: Array = []
var cars: Array = []
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	Wanted.level_changed.connect(_on_level_changed)


func _physics_process(delta: float) -> void:
	cops = cops.filter(func(c): return is_instance_valid(c))
	cars = cars.filter(func(c): return is_instance_valid(c))
	var player = game.player
	var level: int = Wanted.level
	if level > 0 and not game.respawning:
		if _active_cops() < FOOT_COPS[level]:
			_spawn_cop_nearby(player.global_position)
		if _active_cars() < POLICE_CARS[level]:
			_spawn_car_nearby(player.global_position)
	_retire(player)
	Wanted.tick(delta, level > 0 and _anyone_sees(player))


func spawn_cop_at(pos: Vector3):
	var cop = Cop.new()
	cop.position = Vector3(pos.x, 0.0, pos.z)
	game.add_child(cop)
	cops.append(cop)
	return cop


func spawn_car_at(pos: Vector3, yaw: float):
	var car = Vehicle.new()
	car.is_police = true
	car.city = game.city
	car.position = pos
	car.rotation.y = yaw
	car.driver = Vehicle.Driver.POLICE
	game.add_child(car)
	car.officer_deployed.connect(_on_officer_deployed)
	cars.append(car)
	return car


func clear_all() -> void:
	for unit in cops + cars:
		if unit != game.player.vehicle:
			unit.queue_free()
	cops.clear()
	cars.clear()


func _active_cops() -> int:
	return cops.filter(func(c): return c.active and not c.dead).size()


func _active_cars() -> int:
	return cars.filter(func(c): return c.driver == Vehicle.Driver.POLICE).size()


func _spawn_cop_nearby(center: Vector3) -> void:
	var n: Vector2i = game.city.random_node_between(center, 30.0, 55.0, rng)
	if n.x < 0:
		return
	var corner := Vector3(7.5 if rng.randf() < 0.5 else -7.5, 0, 7.5 if rng.randf() < 0.5 else -7.5)
	spawn_cop_at(game.city.node_pos(n) + corner)


func _spawn_car_nearby(center: Vector3) -> void:
	var n: Vector2i = game.city.random_node_between(center, 35.0, 60.0, rng)
	if n.x < 0:
		return
	var pos: Vector3 = game.city.node_pos(n)
	var to := center - pos
	spawn_car_at(pos, atan2(-to.x, -to.z))


func _on_officer_deployed(car) -> void:
	var cop = spawn_cop_at(car.global_position - car.global_basis.x * 1.8)
	cop.rotation.y = car.rotation.y


func _on_level_changed(level: int) -> void:
	for cop in cops:
		if is_instance_valid(cop):
			cop.active = level > 0
	if level == 0:
		for car in cars:
			if is_instance_valid(car) and car.driver == Vehicle.Driver.POLICE:
				car.join_traffic_here()


func _anyone_sees(player) -> bool:
	var target: Vector3 = player.focus_node().global_position + Vector3(0, 1.0, 0)
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	for unit in cops + cars:
		var watching: bool = unit.active and not unit.dead if unit is Cop else unit.driver == Vehicle.Driver.POLICE or unit._deployed
		if not watching:
			continue
		var eye: Vector3 = unit.global_position + Vector3(0, 1.4, 0)
		if eye.distance_to(target) > SIGHT_RANGE:
			continue
		var query := PhysicsRayQueryParameters3D.create(eye, target, L.WORLD)
		if space.intersect_ray(query).is_empty():
			return true
	return false


func _retire(player) -> void:
	var center: Vector3 = player.global_position
	for cop in cops:
		var gone: bool = (not cop.active and cop.global_position.distance_to(center) > RETIRE_DISTANCE) or cop.dead_time > 15.0
		if gone:
			cop.queue_free()
	for car in cars:
		if car == player.vehicle or car.driver == Vehicle.Driver.POLICE:
			continue
		if Wanted.level == 0 and car.global_position.distance_to(center) > RETIRE_DISTANCE + 20.0:
			car.queue_free()
