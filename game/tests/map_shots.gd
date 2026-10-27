extends Node
## Screenshots of the maps: the full map zoomed out to the whole state, part
## way in on the countryside, and on the city; then the minimap at the edge
## of the playable city, where it runs on into the state bake. Needs a real
## renderer:
##   xvfb-run godot --rendering-driver opengl3 res://tests/map_shots.tscn -- <out_dir>

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
	game.save_enabled = false
	game.missions_enabled = false
	add_child(game)
	await _frames(30)
	game.atmosphere.hour = 12.0
	var fm = game.hud.full_map
	fm.open()
	await _ui_frames(2)
	fm.zoom = fm._min_zoom()
	fm.pan = fm.state.world_size * 0.5 + fm.state.origin - fm.map.origin
	await _shot("map_state.png")
	# World metres: Cinder Ridge and Lake Miravel, then the Golden Flats.
	for view in [["map_ridge.png", Vector2(5200, 1800), 0.25], ["map_flats.png", Vector2(4300, 5200), 0.25],
			["map_keys.png", Vector2(9500, 8200), 0.2]]:
		fm.pan = view[1] - game.city.map_origin - fm.map.origin
		fm.zoom = view[2]
		await _shot(view[0])
	fm._tap(fm.size * 0.5 + Vector2(0, -200))
	await _shot("map_tap_closed.png")
	fm.close()
	# Just past the west edge of the city's bake, on the state's.
	var win: Rect2 = game.city.window
	game.player.global_position = Vector3(fm.map.origin.x - 40.0, 0.5, win.get_center().y)
	await _frames(30)
	await _shot("map_minimap_edge.png")
	get_tree().quit()


func _shot(file: String) -> void:
	game.hud.full_map.queue_redraw()
	await _ui_frames(1)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))
	print("saved ", file)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ui_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
