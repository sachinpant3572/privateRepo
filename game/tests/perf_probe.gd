extends Node
## Render-cost probe for Sachin's 0.25.1 log (Ultra, night, driving fast in
## Floodline Wards). Parks a crossover there at 23:42, then frames it as
## parked and as at full speed (TopDownCamera.preview_drive) and prints what
## each pass draws: the main view and the shadow maps. Needs a real renderer:
##   xvfb-run godot --rendering-driver opengl3 --resolution 1560x720 res://tests/perf_probe.tscn

const MainScene = preload("res://main.tscn")
const Vehicle = preload("res://scripts/vehicle.gd")
const Graphics = preload("res://scripts/graphics.gd")

var game


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	game = MainScene.instantiate()
	Graphics.pick(game.settings, "ultra")
	game.settings.merge({"view": "perspective", "zoom": 0.6, "angle": 50.0, "auto_tilt": true, "camera_turn": "car", "drive_zoom": 0.25}, true)
	game.save_enabled = false
	game.missions_enabled = false
	add_child(game)
	await _frames(10)
	game.atmosphere.hour = 23.7
	var at := Vector3(1126.9, 0.0, 134.6)
	game.player.global_position = at
	await _frames(240)
	var car = Vehicle.new()
	car.kind = "crossover"
	car.city = game.city
	car.position = at + Vector3(0, 1, 0)
	car.rotation.y = deg_to_rad(200.0)
	game.add_child(car)
	game.player.enter_vehicle(car)
	await _frames(240)
	await _sample("parked")
	game.camera.preview_drive = true
	await _frames(300)
	await _sample("fast")
	await _sample("fast again")
	var sun: DirectionalLight3D = game.atmosphere.sun
	game.atmosphere._perspective = false # hold the reach set here
	for fit in [1.4, 1.0]:
		sun.directional_shadow_max_distance = game.camera.view_depth * fit
		for mode in [DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS]:
			sun.directional_shadow_mode = mode
			sun.directional_shadow_split_1 = 0.3 if mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS else 0.4
			await _frames(30)
			await _sample("fit %.1f %d splits" % [fit, 4 if mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS else 2])
	game.camera.preview_drive = false
	await _frames(300)
	sun.directional_shadow_max_distance = game.camera.view_depth * 1.4
	await _frames(30)
	await _sample("parked fit 1.4 2 splits")
	game.atmosphere._perspective = true
	# Closing Settings (0.25.1 log: a 61 ms frame): each frame's time after.
	for i in 2:
		game.hud.phone.open_settings()
		await _ui_frames(120)
		var line := "PROBE close settings ms="
		var t := Time.get_ticks_usec()
		game.hud.phone.close()
		for f in 8:
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			line += " %.0f" % ((now - t) / 1000.0)
			t = now
		print(line)
		await _frames(60)
	get_tree().quit()


func _sample(label: String) -> void:
	var vp := get_viewport()
	var n := 60
	var sums := {}
	var t0 := Time.get_ticks_usec()
	for i in n:
		await get_tree().process_frame
		for type in [Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_TYPE_SHADOW]:
			for what in [Viewport.RENDER_INFO_OBJECTS_IN_FRAME, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME]:
				var key := "%s%s" % [["vis", "shd"][type], ["_objs", "_prims", "_draws"][what]]
				sums[key] = sums.get(key, 0) + vp.get_render_info(type, what)
		sums["tot_prims"] = sums.get("tot_prims", 0) + RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0 / n
	var line := "PROBE %-20s ms=%.1f" % [label, ms]
	for k in sums:
		line += " %s=%d" % [k, sums[k] / n]
	line += " cpu=%.1f phys=%.1f" % [Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0]
	var cam = game.camera
	line += " back=%.1f pitch=%.1f depth=%.1f shadow_max=%.0f lamps=%d cars=%d" % [cam._back, cam.perspective_pitch, cam.view_depth, game.atmosphere.sun.directional_shadow_max_distance, game.graphics.lit_lamps().size(), game.graphics.lit_cars.size()]
	print(line)


func _ui_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
