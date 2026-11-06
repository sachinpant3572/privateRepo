extends Node
## Roadworks screenshots for review (the realism pass): each of the first
## few roadworks from above, wide and close, with traffic running past.
##   xvfb-run godot --rendering-driver opengl3 res://tests/world_shots.tscn -- <out_dir>
## COUNT=n sets how many roadworks (default 4).

const MainScene = preload("res://main.tscn")
const Terrain = preload("res://scripts/terrain.gd")

var out_dir := "user://"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0]
	_run.call_deferred()


func _run() -> void:
	var game = MainScene.instantiate()
	game.settings["camera_turn"] = "north"
	game.missions_enabled = false
	add_child(game)
	game.atmosphere.hour = 12.5
	game.atmosphere.minutes_per_second = 0.0
	game.atmosphere.weather_changes = false
	await _frames(180)
	var city = game.city
	var plan = city.plan
	var edges: Array = city.roadworks.keys()
	edges.sort()
	var count := int(OS.get_environment("COUNT")) if OS.get_environment("COUNT") != "" else 4
	var n := 0
	for e: int in edges:
		if n >= count:
			break
		var wk: Dictionary = city.roadworks[e]
		var pa: Vector3 = city.node_pos(plan.edge_a[e])
		var pb: Vector3 = city.node_pos(plan.edge_b[e])
		var dir := (pb - pa).normalized()
		var at: Vector3 = pa + dir * (float(wk.x0) + float(wk.x1)) * 0.5
		at.y = Terrain.height(at.x, at.z)
		var right := Vector3(-dir.z, 0, dir.x)
		city.stream_now(at)
		game.player.global_position = at - right * float(wk.side) * 14.0 + Vector3(0, 0.5, 0)
		game.player.reset_physics_interpolation()
		print("works %d: edge %d %s side %d %.0f-%.0f m at %s" % [n, e, plan.edge_class(e), int(wk.side), wk.x0, wk.x1, at])
		for view: Array in [["wide", 50.0], ["close", 24.0]]:
			game.camera.fixed_focus = at
			game.camera.room_size = view[1]
			game.camera.snap()
			await _frames(240)
			await _shot("works_%d_%s.png" % [n, view[0]])
		n += 1
	game.camera.fixed_focus = null
	game.camera.room_size = 0.0
	get_tree().quit()


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(file))
	print("saved ", file)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
