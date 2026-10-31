extends Node
## Screenshots of the places (storefronts by day and night, the rooms, the
## shop menu, a diner meal, the phone's Places app) for review. Needs a
## real renderer:
##   xvfb-run godot --rendering-driver opengl3 res://tests/place_shots.tscn -- <out_dir>

const MainScene = preload("res://main.tscn")

var out_dir := "user://"
var game


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0]
	_run.call_deferred()


func _run() -> void:
	game = MainScene.instantiate()
	game.settings["camera_turn"] = "north"
	game.save_enabled = false
	game.missions_enabled = false
	add_child(game)
	await _frames(30)
	var ii = game.interiors
	for type in ["corner_store", "diner"]:
		var p := _nearest(type)
		for hour in [12.0, 22.0]:
			game.atmosphere.hour = hour
			await _at(p.door + Vector3(-sin(p.yaw), 0, -cos(p.yaw)) * -4.0, p.yaw)
			await _frames(90)
			await _shot("%s_front_%02d.png" % [type, int(hour)])
		# At the door: the prompt and the ring.
		game.atmosphere.hour = 12.0
		await _at(p.door, p.yaw)
		await _frames(20)
		await _shot("%s_door.png" % type)
		ii.enter(p)
		while not (ii.is_inside() and game.player.controllable):
			await _frames(1)
		await _frames(240)
		await _shot("%s_inside.png" % type)
		game.cash = 120
		game.player.global_position = ii.ORIGIN + ii.room.counter.pos
		game.player.reset_physics_interpolation()
		await _frames(10)
		ii.try_interact()
		await _ui_frames(6)
		await _shot("%s_menu.png" % type)
		if type == "diner":
			game.player.health = 40.0
			ii.buy("gumbo", "order")
			await _frames(90)
			await _shot("diner_meal.png")
			await _frames(200)
		else:
			ii.menu.close()
		ii.leave()
		while ii.state != ii.State.OUTSIDE:
			await _frames(1)
		await _frames(30)
	game.inventory.bag = ["chips", "soda"]
	game.hud.phone.open()
	await _ui_frames(4)
	game.hud.phone._places()
	await _ui_frames(4)
	await _shot("phone_places.png")
	game.hud.phone.close()
	get_tree().quit()


func _nearest(type: String) -> Dictionary:
	var best := {}
	for p in game.city.places:
		if p.type == type and (best.is_empty() or p.door.distance_to(game.city.spawn_point) < best.door.distance_to(game.city.spawn_point)):
			best = p
	return best


func _at(pos: Vector3, yaw: float) -> void:
	game.city.stream_now(pos)
	game.player.global_position = pos
	game.player.rotation.y = yaw
	game.player.reset_physics_interpolation()
	game.camera.snap()
	await _frames(3)


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
