extends Node
## Screenshots of the taxi: the TAXI button, the cab pulled over, the
## destination list, the fare (and the broke version), a ride in progress
## and the phone's Cab app. Needs a real renderer (a phone-shaped window):
##   xvfb-run -a -s "-screen 0 1600x720x24" godot --rendering-driver opengl3 \
##     --resolution 1600x720 res://tests/taxi_shots.tscn -- <out_dir>

const MainScene = preload("res://main.tscn")
const Vehicle = preload("res://scripts/vehicle.gd")

var out_dir := "user://"
var game


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0]
	_run.call_deferred()


func _run() -> void:
	game = MainScene.instantiate()
	game.save_enabled = false
	game.missions_enabled = false
	game.population_enabled = false
	add_child(game)
	game.atmosphere.hour = 12.5
	game.atmosphere.minutes_per_second = 0.0
	game.atmosphere.weather_changes = false
	game.hud.touch.visible = true
	game.cash = 60
	await _frames(60)
	var taxi = game.taxi
	var cab = _cab_in_traffic()
	await _frames(20)
	await _shot("taxi_1_hail_button.png")
	taxi.hail()
	for i in 600:
		if taxi.state == taxi.State.WAITING:
			break
		await _frames(1)
	game.hud.hide_dialogue()
	var p = game.player
	p.global_position = cab.global_position + cab.global_basis.x * 2.4
	p.reset_physics_interpolation()
	await _frames(20)
	await _shot("taxi_2_waiting.png")
	taxi.board(cab)
	game.hud.hide_dialogue()
	await _frames(10)
	await _shot("taxi_3_destinations.png")
	var dest: Dictionary = taxi.destinations()[0]
	taxi.choose(dest)
	await _frames(5)
	await _shot("taxi_4_fare.png")
	game.cash = 3
	taxi._show_confirm()
	await _frames(5)
	await _shot("taxi_5_fare_broke.png")
	game.cash = 60
	taxi._show_confirm()
	taxi.ride()
	game.hud.hide_dialogue()
	await _frames(420)
	await _shot("taxi_6_ride.png")
	taxi.skip()
	for i in 200:
		if taxi.state == taxi.State.IDLE:
			break
		await _frames(1)
	await _frames(30)
	await _shot("taxi_7_after_skip.png")
	game.hud.hide_dialogue()
	game.hud.phone.open()
	await _ui_frames(3)
	game.hud.phone._cab()
	await _ui_frames(4)
	await _shot("taxi_8_phone_cab.png")
	game.hud.phone.close()
	taxi.call_cab()
	await _frames(90)
	await _shot("taxi_9_called_minimap.png")
	game.hud.full_map.open()
	await _ui_frames(4)
	await _shot("taxi_10_called_full_map.png")
	game.hud.full_map.close()
	get_tree().quit()


## A cab in traffic coming up to the player on the sidewalk.
func _cab_in_traffic():
	var city = game.city
	var home: int = city.nearest_node(city.spawn_point)
	var near: Array = [home]
	for n in city.next_nodes(home):
		near.append(n)
	var ends := []
	for n in near:
		for m in city.next_nodes(n):
			if ends.is_empty() and city.node_pos(n).distance_to(city.node_pos(m)) > 70.0:
				ends = [n, m]
	var pa: Vector3 = city.node_pos(ends[0])
	var dir: Vector3 = (city.node_pos(ends[1]) - pa).normalized()
	var side: Vector3 = (city.lane_point(ends[0], ends[1]) - city.node_pos(ends[1])).normalized()
	var cab = Vehicle.new()
	cab.kind = "taxi"
	cab.city = city
	cab.position = city.lane_start(ends[0], ends[1]) + dir * 14.0
	cab.rotation.y = atan2(-dir.x, -dir.z)
	cab.start_traffic(city, ends[0], ends[1])
	game.add_child(cab)
	var p = game.player
	p.global_position = pa + dir * 26.0 + side * 7.0
	p.reset_physics_interpolation()
	game.camera.snap()
	return cab


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))
	print("saved ", file)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ui_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
