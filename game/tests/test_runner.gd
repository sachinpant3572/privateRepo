extends Node
## Headless prototype tests. Run with tests/run.sh.
## Each test builds a fresh game, drives it through Controls and checks state.

const MainScene = preload("res://main.tscn")
const Vehicle = preload("res://scripts/vehicle.gd")

var game
var passed := 0
var failed := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var tests := [
		"test_city_is_one_mesh",
		"test_city_follows_world_map",
		"test_wanted_level_decays_out_of_sight",
		"test_player_walks",
		"test_punching_civilian_gives_one_star",
		"test_enter_drive_and_exit_car",
		"test_carjacking_ejects_driver",
		"test_hitting_cop_brings_police_cars",
		"test_busted_when_cop_holds_player",
		"test_wasted_respawns_at_hospital",
		"test_city_runs_with_population",
		"test_classic_camera_toggle",
	]
	for name in tests:
		var before := failed
		await call(name)
		print("%s %s" % ["PASS" if failed == before else "FAIL", name])
	await _free_game()
	print("\n%d checks passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)


# --- Tests -------------------------------------------------------------------

func test_city_is_one_mesh() -> void:
	await _new_game(false)
	var meshes: Array = game.city.get_children().filter(func(n): return n is MeshInstance3D)
	_check(meshes.size() == 1, "city draws as a single mesh, got %d" % meshes.size())
	_check(game.city.building_count > 40, "city has buildings")
	_check(game.city.sidewalk_loops.size() == 36, "one sidewalk loop per block")


func test_city_follows_world_map() -> void:
	await _new_game(false)
	var city = game.city
	var styles := {}
	for i in city.BLOCKS:
		for j in city.BLOCKS:
			styles[city._block_style(Vector2i(i, j))] = true
	_check(styles.has("quarter") and styles.has("docks") and styles.has("wards"), "blocks use the map's district styles, got %s" % [styles.keys()])
	for landmark in ["police", "hospital", "park", "court"]:
		_check(styles.has(landmark), "map landmark '%s' is placed" % landmark)
	_check(city.district_at(city.spawn_point).name == "Lantern Quarter", "player starts in the Lantern Quarter")
	var station_offset: Vector3 = city.police_station - city.spawn_point
	_check(station_offset.length() > 10.0, "police station comes from the map, not the fallback")


func test_wanted_level_decays_out_of_sight() -> void:
	await _free_game()
	Wanted.report_crime(1)
	_check(Wanted.level == 1, "crime gives one star")
	Wanted.report_crime(2)
	_check(Wanted.level == 2, "crime against police gives two stars")
	Wanted.tick(5.0, true)
	_check(Wanted.level == 2, "stays wanted while seen")
	Wanted.tick(11.0, false)
	_check(Wanted.level == 2, "not lost before the evade time")
	Wanted.tick(1.5, false)
	_check(Wanted.level == 0, "lost after staying out of sight")


func test_player_walks() -> void:
	await _new_game(false)
	var start: Vector3 = game.player.global_position
	Controls.override_vector = Vector2(0, -1)
	await _frames(60)
	Controls.override_vector = null
	var moved: float = game.player.global_position.distance_to(start)
	_check(moved > 3.0, "player walks, moved %.1f m" % moved)


func test_punching_civilian_gives_one_star() -> void:
	await _new_game(false)
	var p = game.player
	_place_player(Vector2i(2, 2), Vector3(7.5, 0, 7.5))
	var ped = game.population.spawn_ped_at(p.global_position + p.forward() * 1.0)
	ped.walk_speed = 0.0
	await _frames(2)
	await _press("attack")
	_check(ped.health < ped.max_health, "punch damages pedestrian")
	_check(Wanted.level == 1, "assault gives one star, got %d" % Wanted.level)
	await _frames(240)
	_check(game.police.cops.size() >= 2, "police on foot respond")


func test_enter_drive_and_exit_car() -> void:
	await _new_game(false)
	var car = _spawn_car(Vector2i(2, 2), Vector3(0, 0, -3), 0.0)
	_place_player(Vector2i(2, 2), Vector3.ZERO)
	await _frames(2)
	await _press("interact")
	_check(game.player.vehicle == car, "player gets in the car")
	_check(not game.player.visible, "player hidden while driving")
	var start: Vector3 = car.global_position
	# Screen up-right is world -Z under the isometric camera: straight down the road.
	Controls.override_vector = Vector2(0.707, -0.707)
	await _frames(90)
	Controls.override_vector = null
	var moved: float = car.global_position.distance_to(start)
	_check(moved > 10.0, "car drives, moved %.1f m" % moved)
	_check(car.health > 90.0, "no crash on an empty road")
	await _frames(120)
	await _press("interact")
	_check(game.player.vehicle == null and game.player.visible, "player gets out")
	_check(Wanted.level == 0, "taking a parked car is not a crime")


func test_carjacking_ejects_driver() -> void:
	await _new_game(false)
	var car = _spawn_car(Vector2i(3, 2), Vector3(0, 0, -3), 0.0)
	car.start_traffic(game.city, Vector2i(3, 2), Vector2i(0, -1))
	car.driver = Vehicle.Driver.TRAFFIC
	_place_player(Vector2i(3, 2), Vector3.ZERO)
	var peds_before: int = game.population.peds.size()
	await _press("interact")
	_check(game.player.vehicle == car, "player takes the car")
	_check(game.population.peds.size() == peds_before + 1, "driver is thrown out")
	_check(Wanted.level == 1, "carjacking gives one star")


func test_hitting_cop_brings_police_cars() -> void:
	await _new_game(false)
	var p = game.player
	_place_player(Vector2i(2, 2), Vector3(7.5, 0, 7.5))
	var cop = game.police.spawn_cop_at(p.global_position + p.forward() * 1.0)
	cop.active = false
	await _frames(2)
	await _press("attack")
	_check(Wanted.level == 2, "hitting a cop gives two stars, got %d" % Wanted.level)
	await _frames(60)
	var police_cars: Array = game.police.cars.filter(func(c): return c.driver == Vehicle.Driver.POLICE)
	_check(police_cars.size() == 2, "two police cars respond, got %d" % police_cars.size())


func test_busted_when_cop_holds_player() -> void:
	await _new_game(false)
	var p = game.player
	_place_player(Vector2i(2, 2), Vector3(7.5, 0, 7.5))
	Wanted.report_crime(1)
	game.police.spawn_cop_at(p.global_position + Vector3(1.0, 0, 0))
	await _frames(150)
	_check(game.respawning, "cop arrests a player standing still")
	await _frames(200)
	_check(Wanted.level == 0, "wanted level cleared after arrest")
	_check(p.global_position.distance_to(game.city.police_station) < 2.0, "respawn at the police station")


func test_wasted_respawns_at_hospital() -> void:
	await _new_game(false)
	var p = game.player
	p.take_hit(null, 999.0, Vector3.ZERO)
	_check(p.dead, "player dies")
	await _frames(200)
	_check(not p.dead and p.health == p.max_health, "player revived")
	_check(p.global_position.distance_to(game.city.hospital) < 2.0, "respawn at the hospital")


func test_city_runs_with_population() -> void:
	await _new_game(true)
	var car = _spawn_car(Vector2i(2, 2), Vector3(0, 0, -3), 0.0)
	_place_player(Vector2i(2, 2), Vector3.ZERO)
	await _press("interact")
	# Weave around for a while to exercise traffic, pedestrians and collisions.
	for i in 12:
		Controls.override_vector = Vector2.from_angle(i * 1.3)
		await _frames(60)
	Controls.override_vector = null
	_check(game.population.peds.size() >= 10, "pedestrians spawned, got %d" % game.population.peds.size())
	_check(game.population.cars.size() >= 5, "traffic spawned, got %d" % game.population.cars.size())
	_check(is_instance_valid(car), "player car still exists")


func test_classic_camera_toggle() -> void:
	await _new_game(false)
	var cam = game.camera
	_place_player(Vector2i(2, 2), Vector3.ZERO)
	await _press("camera")
	_check(cam.mode == cam.Mode.CLASSIC, "camera switches to classic")
	# In classic view, screen-up is north (world -Z).
	var start: Vector3 = game.player.global_position
	Controls.override_vector = Vector2(0, -1)
	await _frames(40)
	Controls.override_vector = null
	var moved: Vector3 = game.player.global_position - start
	_check(moved.z < -2.0 and absf(moved.x) < 0.5, "screen-up walks north in classic view, moved %s" % moved)
	await _frames(30)
	_check(cam.global_basis.z.y > 0.9, "camera looks steeply down")
	await _press("camera")
	_check(cam.mode == cam.Mode.ISOMETRIC, "camera switches back")


# --- Helpers -----------------------------------------------------------------

func _new_game(with_population: bool) -> void:
	await _free_game()
	game = MainScene.instantiate()
	game.population_enabled = with_population
	add_child(game)
	# Tests assume the default view, whatever the saved setting is.
	game.camera.set_mode(game.camera.Mode.ISOMETRIC, true)
	await _frames(2)


func _free_game() -> void:
	Controls.override_vector = null
	for action in ["attack", "interact", "sprint", "camera"]:
		Input.action_release(action)
	if game != null:
		game.queue_free()
		game = null
		await get_tree().process_frame
	Wanted.clear()


func _place_player(node: Vector2i, offset: Vector3) -> void:
	var p = game.player
	p.global_position = game.city.node_pos(node) + offset
	p.rotation.y = 0.0
	p.reset_physics_interpolation()
	game.camera.snap()


func _spawn_car(node: Vector2i, offset: Vector3, yaw: float):
	var car = Vehicle.new()
	car.city = game.city
	car.position = game.city.node_pos(node) + offset
	car.rotation.y = yaw
	game.add_child(car)
	return car


func _press(action: String) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)
	await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		print("  FAILED: " + message)
