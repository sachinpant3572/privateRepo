extends Node
## Keeps a bubble of pedestrians, traffic and parked cars around the player,
## spawning outside the camera view and removing what drifts too far away.

const Pedestrian = preload("res://scripts/pedestrian.gd")
const Vehicle = preload("res://scripts/vehicle.gd")
const VehicleKit = preload("res://scripts/kits/vehicle_kit.gd")
const Traffic = preload("res://scripts/traffic.gd")

const PED_COUNT := 18
## The old fixed traffic count; Traffic.budget() sets it now (district, hour,
## events and graphics quality).
const TRAFFIC_COUNT := 8
const PED_SPAWN := Vector2(30.0, 50.0)
const CAR_SPAWN := Vector2(40.0, 70.0)
const PED_DESPAWN := 70.0
const CAR_DESPAWN := 95.0
const PARK_SPAWN := 90.0 # parked cars appear out of view within this range
const PARK_DESPAWN := 120.0

var game
var enabled := true
var peds: Array = []
var cars: Array = []
var rng := RandomNumberGenerator.new()
var _tick := 0.0
var _parked := {} # parked spot index -> car spawned there
var _first_pass := true
## Junction controls, speed limits, demand and the district mix (Traffic).
var traffic


func _ready() -> void:
	traffic = Traffic.new()
	traffic.name = "Traffic"
	traffic.game = game
	add_child(traffic)


func _physics_process(delta: float) -> void:
	_tick -= delta
	if not enabled or _tick > 0.0:
		return
	_tick = 0.25
	var center: Vector3 = game.player.global_position
	var r := reach()
	peds = peds.filter(func(p): return is_instance_valid(p))
	cars = cars.filter(func(c): return is_instance_valid(c))
	for ped in peds:
		if _gone(ped, center, PED_DESPAWN * r) or ped.dead_time > 20.0:
			ped.queue_free()
	for car in cars:
		if car != game.player.vehicle and _gone(car, center, CAR_DESPAWN * r):
			car.queue_free()
	if peds.size() < PED_COUNT:
		var spot: Array = game.city.random_sidewalk_between(center, PED_SPAWN.x, PED_SPAWN.y * r, rng, out_of_view)
		if not spot.is_empty():
			_add_ped(spot[0], spot[1])
	if cars.size() < traffic.budget():
		_spawn_traffic(center, r)
	_update_parked(center)


## How much further out than on foot people and cars come and go: the
## driving camera zooms out to see about 1.8x as far, and Settings > Zoom
## up to 1.3x more.
func reach() -> float:
	var cam = game.camera
	if cam == null:
		return 1.0
	return clampf(cam.size / 30.0, 1.0, 2.1)


## Far enough to remove: beyond `dist` and off screen, or far beyond it.
func _gone(node: Node3D, center: Vector3, dist: float) -> bool:
	var d := node.global_position.distance_to(center)
	return d > dist * 1.5 or (d > dist and out_of_view(node.global_position))


func out_of_view(pos: Vector3) -> bool:
	return not _in_view(pos)


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


## Sets a car off out of view, more often on the arterials than the side
## streets (Traffic.spawn_weight): two tries a tick.
func _spawn_traffic(center: Vector3, r: float) -> void:
	var n := -1
	var to := -1
	for attempt in 2:
		n = game.city.random_node_between(center, CAR_SPAWN.x, CAR_SPAWN.y * r, rng, out_of_view)
		if n < 0:
			return
		var options: Array = game.city.next_nodes(n)
		if options.is_empty():
			continue
		to = options[rng.randi() % options.size()]
		if rng.randf() < traffic.spawn_weight(n, to):
			break
		to = -1
	if to < 0:
		return
	var car = _new_traffic_car(n, to)
	var lane: int = rng.randi() % game.city.lane_count(n, to)
	car.position = game.city.lane_start(n, to, lane)
	var heading: Vector3 = game.city.node_pos(to) - game.city.node_pos(n)
	car.rotation.y = atan2(-heading.x, -heading.z)
	# Never on top of another vehicle (a long truck's trailer included).
	if not Vehicle.room_for(get_tree(), car.position, car.rotation.y, VehicleKit.size_of(car.kind), 1.0):
		car.free()
		return
	car.rng.seed = rng.randi()
	car.start_traffic(game.city, n, to, lane)
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
		# A country home's spot is closed while its tile is not loaded.
		if _parked.has(idx) or (spots[idx].size() > 2 and not spots[idx][2]):
			continue
		var d: float = spots[idx][0].distance_to(center)
		# A home's stalls and garage bays stand about 2.6 m apart: a car in
		# the next one does not block this one.
		if d < PARK_SPAWN and (_first_pass or not _in_view(spots[idx][0])) and not _occupied(spots[idx][0], 2.0 if spots[idx].size() > 3 else 4.0) \
				and Vehicle.room_for(get_tree(), spots[idx][0], spots[idx][1], PARK_FOOTPRINT, 0.0):
			var car = _new_car(true, spots[idx][3] if spots[idx].size() > 3 else -1)
			car.city = game.city
			car.position = spots[idx][0]
			car.rotation.y = spots[idx][1]
			game.add_child(car)
			_parked[idx] = car
	_first_pass = false


## Fills the curb spots in view too on the next pass, as at the start (after
## a respawn, while the message is up).
func refill() -> void:
	_first_pass = true


## A curb car's footprint for the spot check (the biggest curb models; a
## home's stalls stand 2.6 m apart, so neighbours don't count).
const PARK_FOOTPRINT := Vector3(2.2, 0.0, 5.4)


## Whether a vehicle or the player already stands within `radius` of a
## parking spot (by centre: a long truck over the spot is room_for's).
func _occupied(spot: Vector3, radius := 4.0) -> bool:
	if game.player.global_position.distance_to(spot) < radius:
		return true
	for v in get_tree().get_nodes_in_group("vehicles"):
		if v.global_position.distance_to(spot) < radius:
			return true
	return false


## Whether `pos` is on screen or within `margin` (of the screen width) of
## it. The driving camera sees up to about 60 m ahead on a wide phone.
func _in_view(pos: Vector3, margin := 0.1) -> bool:
	var cam = game.camera
	if cam == null or not cam.is_inside_tree():
		return false
	var screen: Rect2 = cam.get_viewport().get_visible_rect()
	# In perspective, points behind the camera project mirrored onto the screen.
	return not cam.is_position_behind(pos) and screen.grow(screen.size.x * margin).has_point(cam.unproject_position(pos))


## A civilian vehicle with a model from the traffic mix, or from the curb
## mix when `parked` (nothing too long for a curb spot, but bikes).
func _new_car(parked := false, tier := -1):
	var car = Vehicle.new()
	var pool: Array = VehicleKit.PARKED if parked else VehicleKit.CIVILIAN
	if parked and tier >= 0:
		pool = VehicleKit.PARKED_BY_TIER[clampi(tier, 0, 5)]
	car.kind = pool[rng.randi() % pool.size()]
	car.body_color = VehicleKit.pick_paint(car.kind, rng)
	return car


## A traffic vehicle setting off on the street from junction a to b, of a
## kind from the district's mix (Traffic.pick_kind), with its driver's
## share of the speed limit. The 18-wheeler (longer than
## VehicleKit.LONG_HAUL) sets off only where there are two or more lanes
## each way (avenues, boulevards, highways), never down a one-lane quarter
## street.
func _new_traffic_car(a: int, b: int):
	var car = Vehicle.new()
	var at: Vector3 = game.city.node_pos(a)
	car.kind = traffic.pick_kind(at, rng)
	var tries := 0
	while VehicleKit.size_of(car.kind).z > VehicleKit.LONG_HAUL and game.city.lane_count(a, b) < 2:
		tries += 1
		car.kind = traffic.pick_kind(at, rng) if tries < 20 else "sedan"
	car.body_color = VehicleKit.pick_paint(car.kind, rng)
	car.drive_factor = driver_factor(rng)
	return car


## A driver's cruising speed as a share of the limit: most drive at it
## give or take, one in ten speeds, one in twenty dawdles.
static func driver_factor(rand: RandomNumberGenerator) -> float:
	var r := rand.randf()
	if r < 0.05:
		return rand.randf_range(0.85, 0.9)
	if r < 0.15:
		return rand.randf_range(1.1, 1.2)
	return rand.randf_range(0.92, 1.08)
