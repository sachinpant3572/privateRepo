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
	["4_lantern_square", "lantern_square", Vector3(0, 0, 18.8)],
	["5_blue_lantern", "blue_lantern", Vector3(0, 0, 18.8)],
	["6_aurum_tower", "aurum_tower", Vector3(0, 0, 18.8)],
	["7_floodline_wards", "moreau_house", Vector3(0, 0, 18.8)],
	["8_ironwharf", "wharfside_courts", Vector3(30, 0, 26.0)],
	["9_drowned_streetcar", "drowned_streetcar", Vector3(0, 0, 18.8)],
	["10_streetcar_depot", "streetcar_depot", Vector3(0, 0, 18.8)],
	["11_lantern_line", "union_station", Vector3(-26, 0, 30.0)],
]


func _run() -> void:
	var game = MainScene.instantiate()
	add_child(game)
	await _frames(180)
	await _shot("1_on_foot.png")
	var home: Vector3 = game.player.global_position
	for stop in TOUR:
		var b: Vector2i = game.city.landmark_block(stop[1])
		var pos: Vector3 = game.city.block_center(b) + stop[2]
		game.city.stream_now(pos)
		game.player.global_position = pos
		game.player.reset_physics_interpolation()
		game.camera.snap()
		await _frames(90)
		await _shot(stop[0] + ".png")
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
