extends Node
## Renders a few gameplay screenshots for review. Needs a real renderer:
##   xvfb-run godot --rendering-driver opengl3 res://tests/screenshots.tscn -- <out_dir>

const MainScene = preload("res://main.tscn")

var out_dir := "user://"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0]
	_run.call_deferred()


## Sidewalk spots in front of landmarks, for the district tour shots.
const TOUR := [
	["4_lantern_square", "lantern_square", Vector3(0, 0, 0)],
	["5_blue_lantern", "blue_lantern", Vector3(0, 0, 0)],
	["6_aurum_tower", "aurum_tower", Vector3(0, 0, 0)],
	["7_floodline_wards", "moreau_house", Vector3(0, 0, 0)],
	["8_ironwharf", "wharfside_courts", Vector3(30, 0, 7.0)],
	["9_drowned_streetcar", "drowned_streetcar", Vector3(0, 0, 0)],
	["10_streetcar_depot", "streetcar_depot", Vector3(0, 0, 0)],
	["11_lantern_line", "union_station", Vector3(-26, 0, 11.0)],
]


## [file, landmark, offset, hour, weather] shots of the Lantern Quarter at
## night and in the rain.
const MOODS := [
	["13_quarter_night", "blue_lantern", Vector3(0, 0, 3.0), 21.5, "clear"],
	["14_square_night", "lantern_square", Vector3(0, 0, 2.0), 22.0, "clear"],
	["15_quarter_rain_night", "blue_lantern", Vector3(18, 0, 5.0), 21.0, "storm"],
	["16_quarter_rain_day", "lantern_square", Vector3(-20, 0, 5.0), 13.0, "rain"],
	["17_quarter_dusk", "lantern_square", Vector3(20, 0, 3.0), 19.2, "clear"],
]


func _run() -> void:
	var game = MainScene.instantiate()
	game.missions_enabled = false
	add_child(game)
	game.atmosphere.hour = 12.5
	game.atmosphere.minutes_per_second = 0.0
	game.atmosphere.weather_changes = false
	await _frames(180)
	await _shot("1_on_foot.png")
	game.waypoint = game.city.node_pos(game.city.nearest_node(game.city.landmark_front("lantern_square")))
	await _frames(30)
	game.hud.full_map.open()
	for i in 4:
		await get_tree().process_frame
	await _shot("12_full_map.png")
	var fm = game.hud.full_map
	fm.zoom = minf(fm.size.x / fm.map.size.x, (fm.size.y - 56.0) / fm.map.size.y)
	fm.pan = fm.map.size * 0.5 - Vector2(0, 28.0) / fm.zoom
	fm.queue_redraw()
	for i in 3:
		await get_tree().process_frame
	await _shot("12b_full_map_all.png")
	game.hud.full_map.close()
	var home: Vector3 = game.player.global_position
	for stop in TOUR:
		var pos: Vector3 = game.city.landmark_frame(stop[1]) * stop[2]
		game.city.stream_now(pos)
		game.player.global_position = pos
		game.player.reset_physics_interpolation()
		game.camera.snap()
		await _frames(90)
		await _shot(stop[0] + ".png")
	var green: Vector3 = game.city.node_pos(game.city.plan.park_node) + Vector3(0, 0, 14.0)
	game.city.stream_now(green)
	game.player.global_position = green
	game.player.reset_physics_interpolation()
	game.camera.snap()
	await _frames(90)
	await _shot("19_liberty_green.png")
	for mood in MOODS:
		var pos: Vector3 = game.city.landmark_frame(mood[1]) * mood[2]
		game.atmosphere.hour = mood[3]
		game.atmosphere.set_weather(mood[4], true)
		game.city.stream_now(pos)
		game.player.global_position = pos
		game.player.reset_physics_interpolation()
		game.camera.snap()
		await _frames(90)
		await _shot(mood[0] + ".png")
	game.atmosphere.hour = 12.5
	game.atmosphere.set_weather("clear", true)
	game.city.stream_now(home)
	game.player.global_position = home
	game.player.reset_physics_interpolation()
	game.camera.snap()
	await _frames(60)

	var p = game.player
	await _walk_to_car(game)
	Controls.override_vector = Controls.screen_from_world(Vector3.RIGHT)
	await _frames(100)
	await _shot("2_driving.png")
	game.atmosphere.hour = 22.0
	game.atmosphere.set_weather("rain", true)
	Input.action_press("sprint")
	Controls.override_vector = Controls.screen_from_world(Vector3(1, 0, 0.8).normalized())
	await _frames(40)
	Input.action_release("sprint")
	Controls.override_vector = Controls.screen_from_world(Vector3.RIGHT)
	await _frames(20)
	await _shot("18_night_drive.png")
	game.atmosphere.hour = 12.5
	game.atmosphere.set_weather("clear", true)

	Wanted.report_crime(2)
	await _frames(150)
	Controls.override_vector = null
	await _frames(60)
	await _shot("3_police_chase.png")
	print("player at ", p.global_position, " wanted ", Wanted.level)
	get_tree().quit()


func _walk_to_car(game) -> void:
	var p = game.player
	var car = p.nearest_vehicle()
	while car == null:
		var target: Vector3 = game.city.parked_spots[0][0]
		Controls.override_vector = Controls.screen_from_world((target - p.global_position).normalized())
		await _frames(1)
		car = p.nearest_vehicle()
	Controls.override_vector = null
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	await _frames(2)


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(file))
	print("saved ", file)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
