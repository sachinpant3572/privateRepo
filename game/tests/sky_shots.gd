extends Node
## Screenshots of the sky (sky.gd) and the birds (birds.gd): night skies
## looked up at from the city centre, the suburbs, the hills, a remote beach
## and the desert (stars by light pollution, the Milky Way, the moon, the
## city's glow), sunrise and sunset, birds by day, and the normal top-down
## view with the sky in water and wet roads. Needs a real renderer:
##   xvfb-run godot --rendering-driver opengl3 res://tests/sky_shots.tscn -- <out_dir>
## ONLY=s01_city_night,s03_hills_night picks views.

const MainScene = preload("res://main.tscn")
const SkyDome = preload("res://scripts/sky.gd")
const Terrain = preload("res://scripts/terrain.gd")

## Places: downtown (300, 250), the suburbs (-350, 100), the hills (1200,
## -1300), a sand beach (-2033, 1791) and the play area's edge by the far
## desert (-2667, -1959).
## [file, local x, local z, hour, view, yaw (0 north, 90 east; "moon" or
## "sun" to face it), pitch up from the horizon (look-up views) or the view
## size in metres (top-down), weather].
## view: "up" (eye height, Look up), "top" (the game's top-down camera),
## "top_wet" (top-down, streets wet after rain), "up_birds" / "top_birds"
## (a flock set in front of the camera).
const VIEWS := [
	["s01_city_night", 300.0, 250.0, 22.5, "up", 180.0, 18.0, "clear"],
	["s02_suburb_night", -350.0, 100.0, 22.5, "up", 160.0, 22.0, "clear"],
	["s03_hills_night", 1200.0, -1300.0, 22.5, "up", 180.0, 18.0, "clear"],
	["s04_beach_night", -2033.0, 1791.0, 22.5, "up", 180.0, 18.0, "clear"],
	["s05_desert_night", -2667.0, -1959.0, 22.5, "up", 300.0, 24.0, "clear"],
	["s06_hills_zenith", 1200.0, -1300.0, 1.5, "up", 0.0, 62.0, "clear"],
	["s07_hills_moon", 1200.0, -1300.0, 22.5, "up", "moon", 35.0, "clear"],
	["s08_hills_cloudy_night", 1200.0, -1300.0, 22.5, "up", 180.0, 18.0, "cloudy"],
	["s09_sunrise", 1200.0, -1300.0, 6.3, "up", "sun", 8.0, "clear"],
	["s10_sunset_beach", -2033.0, 1791.0, 17.7, "up", "sun", 8.0, "clear"],
	["s11_city_noon_birds", 300.0, 250.0, 12.0, "up_birds", 200.0, 20.0, "clear"],
	["s12_top_birds", 300.0, 250.0, 9.5, "top_birds", 0.0, 60.0, "clear"],
	["s13_top_river_day", "river", 0.0, 12.0, "top", 0.0, 80.0, "clear"],
	["s14_top_river_night", "river", 0.0, 22.5, "top", 0.0, 80.0, "clear"],
	["s15_top_sea_dusk", 300.0, 1930.0, 18.4, "top", 0.0, 80.0, "clear"],
	["s16_top_wet_night", 300.0, 250.0, 22.5, "top_wet", 0.0, 60.0, "clear"],
]

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
	game.save_enabled = false
	add_child(game)
	var atm = game.atmosphere
	atm.minutes_per_second = 0.0
	atm.weather_changes = false
	await _frames(30)
	var look := Camera3D.new()
	add_child(look)
	var only := OS.get_environment("ONLY")
	for v in VIEWS:
		if only != "" and not (v[0] as String) in only.split(","):
			continue
		var at := _river_bank(game.city) if v[1] is String else Vector3(v[1], 0.0, v[2])
		at.y = Terrain.height(at.x, at.z)
		atm.hour = v[3]
		atm.set_weather(v[7], true)
		game.player.global_position = at + Vector3(0, 0.5, 0)
		game.city.stream_now(at)
		var view: String = v[4]
		if view == "top_wet":
			atm.wetness = 1.0
		if view.begins_with("up"):
			game.camera.set_process(false)
			game.camera.set_physics_process(false)
			look.current = true
			atm._apply(0.0)
			var yaw = v[5]
			var pitch: float = v[6]
			if yaw is String:
				var d: Vector3 = atm.sky.moon_dir if yaw == "moon" else atm.sky.sun_dir
				if yaw == "moon":
					pitch = clampf(rad_to_deg(asin(d.y)) - 8.0, 5.0, 70.0)
				yaw = rad_to_deg(atan2(d.x, -d.z))
			SkyDome.look_up(look, atm.env, at, yaw, pitch)
			# Let the birds refill for the new hour and place first.
			await _frames(3)
			if view == "up_birds":
				var fwd := -look.global_transform.basis.z
				var spot := look.global_position + Vector3(fwd.x, 0.0, fwd.z).normalized() * 30.0
				atm.birds.spawn("pigeon", spot)
				atm.birds.spawn("gull", spot + Vector3(fwd.x, 0.0, fwd.z).normalized() * 25.0)
		else:
			SkyDome.horizon_haze(atm.env, false)
			look.current = false
			game.camera.set_process(true)
			game.camera.set_physics_process(true)
			game.camera.current = true
			game.camera.fixed_focus = at
			game.camera.room_size = v[6]
			game.camera.size = v[6]
			game.camera.snap()
			await _frames(3)
			if view == "top_birds":
				atm.birds.spawn("pigeon", at + Vector3(6, 0, -4), true)
				atm.birds.spawn("pigeon", at + Vector3(-12, 0, 10))
				atm.birds.spawn("crow", at + Vector3(10, 0, 14))
		await _frames(40)
		atm.sky.refresh()
		await _frames(4)
		await _shot(v[0] + ".png")
		# SKY_DEBUG=1 lists the flocks near the view and where they are on screen.
		if OS.get_environment("SKY_DEBUG") != "":
			var cam := get_viewport().get_camera_3d()
			for f in atm.birds.flocks:
				var fp: Vector3 = f.pos
				var rel := fp - at
				if Vector2(rel.x, rel.z).length() < 90.0:
					print("    flock %s %s n=%d rel=(%.0f, %.1f, %.0f) screen=%s" % [f.kind, f.state, f.n, rel.x, rel.y, rel.z, cam.unproject_position(fp)])
		print("  sky %s: pollution %.2f stars %.2f milky %.2f glow %.2f birds %d flocks %d" % [v[0], atm.sky.pollution, atm.sky.stars, atm.sky.milky, atm.sky.glow_amount, atm.birds.bird_count(), atm.birds.flocks.size()])
	get_tree().quit()


## A point on the city's river bank: the river's nearest point to the
## centre, moved back toward the centre by most of the river's half width.
func _river_bank(city) -> Vector3:
	var line: PackedVector2Array = city.plan._river
	var c := Vector2(300, 250)
	var best := Vector2.ZERO
	var best_d := INF
	for k in line.size() - 1:
		var q := Geometry2D.get_closest_point_to_segment(c, line[k], line[k + 1])
		if q.distance_to(c) < best_d:
			best_d = q.distance_to(c)
			best = q
	var p: Vector2 = best + (c - best).normalized() * float(city.plan._river_half) * 0.85
	return Vector3(p.x, 0.0, p.y)


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))
	print("saved ", file)


## Rendered frames, not physics ticks: a slow render runs several ticks per
## frame, so ticks alone can end before the birds' _process sees a new hour.
func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
