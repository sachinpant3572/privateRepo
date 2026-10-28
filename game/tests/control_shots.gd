extends Node
## Screenshots of the touch controls: on foot, each driving layout (with a
## pedal or arrow held) and the phone's Settings page. Needs a real renderer:
##   xvfb-run godot --rendering-driver opengl3 res://tests/control_shots.tscn -- <out_dir>

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
	game.settings["camera_turn"] = "north"
	game.save_enabled = false
	game.missions_enabled = false
	add_child(game)
	await _frames(30)
	var touch = game.hud.touch
	touch.visible = true
	game.atmosphere.hour = 12.0
	await _frames(30)
	await _shot("controls_foot.png")
	var car = Vehicle.new()
	car.city = game.city
	car.position = game.city.node_pos(game.city.nearest_node(game.city.spawn_point))
	game.add_child(car)
	game.player.enter_vehicle(car)
	for scheme in Controls.SCHEMES:
		game.settings["controls"] = scheme
		game.apply_settings()
		var held := "gas"
		if scheme == "arrows":
			held = "steer_right"
		elif scheme == "tilt":
			Controls.tilt_override = Vector3(3.0, -9.3, 0.0)
		await _ui_frames(2) # the HUD switches the layout
		var tap := InputEventScreenTouch.new()
		tap.index = 1
		tap.pressed = true
		for b in touch.buttons():
			if b.action == held:
				tap.position = touch._center(b)
		touch._input(tap)
		await _frames(40)
		await _shot("controls_%s.png" % scheme)
		tap.pressed = false
		touch._input(tap)
		Controls.tilt_override = null
	# The HUD's gear opens Settings straight away.
	game.hud.settings_button.pressed.emit()
	await _ui_frames(90)
	await _shot("controls_settings.png")
	# Each tab, and the preview driving fast after a Drive zoom-out change.
	var page = game.hud.phone.settings_page
	page.steppers["Drive zoom-out"].get_meta("less").pressed.emit()
	await _ui_frames(120)
	await _shot("settings_driving.png")
	for t in ["Graphics", "Controls", "Game"]:
		page.show_tab(t)
		await _ui_frames(4)
		await _shot("settings_%s.png" % t.to_lower())
	# The Game tab's Log section, at the bottom.
	page._scroll.scroll_vertical = 100000
	await _ui_frames(4)
	await _shot("settings_game_log.png")
	get_tree().quit()


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
