extends Node
## Quick look-development shots: a few spots, for tuning materials and
## detail without the full screenshot tour.
##   xvfb-run godot --rendering-driver opengl3 --resolution 1280x720 \
##     res://tests/lookdev.tscn -- <out_dir> [spot names...]

const MainScene = preload("res://main.tscn")

## [name, landmark, offset in its street frame, hour, weather]
const SPOTS := [
	["downtown", "aurum_tower", Vector3(-14, 0, 4.0), 12.5, "clear"],
	["wards", "moreau_house", Vector3(0, 0, 2.0), 15.0, "clear"],
	["quarter", "lantern_square", Vector3(-20, 0, 4.0), 11.0, "clear"],
	["station", "union_station", Vector3(-26, 0, 11.0), 9.0, "clear"],
	["docks", "wharfside_courts", Vector3(30, 0, 7.0), 16.5, "cloudy"],
	["downtown_night", "aurum_tower", Vector3(-14, 0, 4.0), 22.0, "clear"],
	["quarter_rain", "blue_lantern", Vector3(18, 0, 5.0), 13.0, "rain"],
]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if not args.is_empty() else "user://"
	var only := args.slice(1)
	var game = MainScene.instantiate()
	game.missions_enabled = false
	add_child(game)
	game.atmosphere.minutes_per_second = 0.0
	game.atmosphere.weather_changes = false
	await _frames(120)
	for spot in SPOTS:
		if not only.is_empty() and not only.has(spot[0]):
			continue
		var pos: Vector3 = game.city.landmark_frame(spot[1]) * spot[2]
		game.atmosphere.hour = spot[3]
		game.atmosphere.set_weather(spot[4], true)
		game.city.stream_now(pos)
		game.player.global_position = pos
		game.player.reset_physics_interpolation()
		game.camera.snap()
		await _frames(60)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join(spot[0] + ".png"))
		print("saved ", spot[0])
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
