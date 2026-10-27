extends Node
## Keeps a bubble of pedestrians, traffic and parked cars around the player,
## spawning outside the camera view and removing what drifts too far away.

const Pedestrian = preload("res://scripts/pedestrian.gd")
const Vehicle = preload("res://scripts/vehicle.gd")
const VehicleKit = preload("res://scripts/kits/vehicle_kit.gd")

const PED_COUNT := 18
const TRAFFIC_COUNT := 8
const PED_SPAWN := Vector2(30.0, 50.0)
const CAR_SPAWN := Vector2(40.0, 70.0)
const PED_DESPAWN := 70.0
const CAR_DESPAWN := 95.0
const PARK_SPAWN := Vector2(55.0, 90.0)
const PARK_DESPAWN := 120.0

var game
var enabled := true
var peds: Array = []
var cars: Array = []
var rng := RandomNumberGenerator.new()
var _tick := 0.0
var _parked := {} # parked spot index -> car spawned there
var _first_pass := true


func _physics_process(delta: float) -> void:
	_tick -= delta
	if not enabled or _tick > 0.0:
		return
	_tick = 0.25
	var center: Vector3 = game.player.global_position
	peds = peds.filter(func(p): return is_instance_valid(p))
	cars = cars.filter(func(c): return is_instance_valid(c))
	for ped in peds:
		if ped.global_position.distance_to(center) > PED_DESPAWN or ped.dead_time > 20.0:
			ped.queue_free()
	for car in cars:
		if car != game.player.vehicle and car.global_position.distance_to(center) > CAR_DESPAWN:
			car.queue_free()
	if peds.size() < PED_COUNT:
		var spot: Array = game.city.random_sidewalk_between(center, PED_SPAWN.x, PED_SPAWN.y, rng)
		if not spot.is_empty():
			_add_ped(spot[0], spot[1])
	if cars.size() < TRAFFIC_COUNT:
		_spawn_traffic(center)
	_update_parked(center)


func spawn_ped_at(pos: Vector3):
	var spot: Array = game.city.nearest_sidewalk(pos)
	var ped = _add_ped(spot[0], spot[1])
	ped.position = Vector3(pos.x, 0.0, pos.z)
	return ped


func _add_ped(loop: int, point: int):
	var ped = Pedestrian.new()
	ped.setup(game.city, rng, loop, point)
	ped.position = game.city.sidewalk_loops[loop][point]
	game.add_child(ped)
	peds.append(ped)
	return ped


func _spawn_traffic(center: Vector3) -> void:
	var n: Vector2i = game.city.random_node_between(center, CAR_SPAWN.x, CAR_SPAWN.y, rng)
	if n.x < 0:
		return
	var dirs: Array[Vector2i] = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if game.city.in_grid(n + d) and game.city.plan.drivable(n, d):
			dirs.append(d)
	if dirs.is_empty():
		return
	var heading: Vector2i = dirs[rng.randi() % dirs.size()]
	var car = _new_car()
	car.position = game.city.lane_point(n, heading)
	car.rotation.y = atan2(-float(heading.x), -float(heading.y))
	car.rng.seed = rng.randi()
	car.start_traffic(game.city, n, heading)
	game.add_child(car)
	cars.append(car)


## Parked cars live with the map's curb spots: spawned out of view as the
## player approaches, removed when far away (unless the player has one).
func _update_parked(center: Vector3) -> void:
	for idx in _parked.keys():
		var car = _parked[idx]
		if not is_instance_valid(car):
			_parked.erase(idx)
		elif car != game.player.vehicle and car.global_position.distance_to(center) > PARK_DESPAWN:
			car.queue_free()
			_parked.erase(idx)
	var spots: Array = game.city.parked_spots
	for idx in range(1, spots.size()):
		if _parked.has(idx):
			continue
		var d: float = spots[idx][0].distance_to(center)
		if d < PARK_SPAWN.y and (_first_pass or d > PARK_SPAWN.x):
			var car = _new_car()
			car.city = game.city
			car.position = spots[idx][0]
			car.rotation.y = spots[idx][1]
			game.add_child(car)
			_parked[idx] = car
	_first_pass = false


func _new_car():
	var car = Vehicle.new()
	car.kind = VehicleKit.CIVILIAN[rng.randi() % VehicleKit.CIVILIAN.size()]
	car.body_color = VehicleKit.PAINTS[rng.randi() % VehicleKit.PAINTS.size()]
	return car
