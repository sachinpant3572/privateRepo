extends Node
## Screenshots of the calendar's events (scripts/events.gd): a rave at night,
## the Saturday fair by day, the rodeo night, the Sunday market, the cult
## circle at the stone ring and the speed trap. Needs a real renderer:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 \
##     --resolution 1280x720 res://tests/events_gallery.tscn -- <out_dir>
## `ONLY=ev01_rave_night,...` shoots just those views.

const MainScene = preload("res://main.tscn")
const Terrain = preload("res://scripts/terrain.gd")
const Calendar = preload("res://scripts/calendar.gd")
const Events = preload("res://scripts/events.gd")

## [file, event id, day, hour, view size (m tall), look shift (x, z) from the
## event centre, people wanted before the shot]. Day 0 is a Friday, 1 a
## Saturday, 2 a Sunday and 2 also has the full moon; "rodeo" is found.
const VIEWS := [
	["ev01_rave_night", "rave_copperback", 0, 23.5, 70.0, Vector2(0, 0), 10],
	["ev02_rave_close", "rave_copperback", 0, 23.5, 36.0, Vector2(0, 0), 10],
	["ev03_rave_east_night", "rave_east", 1, 23.5, 70.0, Vector2(0, 0), 10],
	["ev04_fair_day", "hollin_fair", 1, 12.5, 80.0, Vector2(0, 0), 10],
	["ev05_fair_close", "hollin_fair", 1, 14.5, 44.0, Vector2(0, 0), 10],
	["ev06_rodeo_night", "hollin_rodeo", "rodeo", 21.5, 80.0, Vector2(0, 0), 10],
	["ev07_market_day", "brackett_market", 2, 10.0, 60.0, Vector2(0, 0), 9],
	["ev08_cult_night", "cult_gathering", 2, 22.5, 44.0, Vector2(0, 0), 9],
	["ev09_cult_close", "cult_gathering", 2, 22.5, 24.0, Vector2(0, 0), 9],
	["ev10_speed_trap", "speed_trap", 0, 18.5, 40.0, Vector2(0, 0), 0],
]

var out_dir := "user://"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	var game = MainScene.instantiate()
	game.settings["camera_turn"] = "north"
	game.missions_enabled = false
	game.save_enabled = false
	add_child(game)
	game.atmosphere.minutes_per_second = 0.0
	game.atmosphere.weather_changes = false
	# The game's own nodes: a second events node would build every event twice.
	var cal = game.calendar
	var ev = game.events
	await _frames(30)
	var only := OS.get_environment("ONLY")
	var rodeo_day := 0
	for d in 120:
		if Events.runs_on(Events.spec_of("hollin_rodeo"), d):
			rodeo_day = d
			break
	for v in VIEWS:
		if only != "" and not (v[0] as String) in only.split(","):
			continue
		var spec: Dictionary = Events.spec_of(v[1])
		var c: Vector3 = ev.center(spec)
		var day: int = rodeo_day if v[2] is String else int(v[2])
		var at := c + Vector3(v[5].x, 0.0, v[5].y)
		at.y = maxf(Terrain.height(at.x, at.z), 0.0)
		game.city.stream_now(at)
		cal.set_day(day)
		game.atmosphere.hour = v[3]
		# The player waits well off the shot but inside the build radius.
		var pp := c + Vector3(0.0, 0.0, 95.0)
		pp.y = maxf(Terrain.height(pp.x, pp.z), 0.0) + 1.0
		game.player.global_position = pp
		game.player.reset_physics_interpolation()
		game.camera.fixed_focus = at
		game.camera.room_size = v[4]
		game.camera.size = v[4]
		game.camera.snap()
		ev.poll()
		# Wait (real time) for the dressing and the people to arrive.
		var end := Time.get_ticks_msec() + 90000
		while Time.get_ticks_msec() < end:
			var ready: bool = ev.is_built(v[1]) and (spec.kind == "trap" or ev.has_dressing(v[1])) \
					and ev.goers(v[1]).size() >= int(v[6])
			if ready:
				break
			await get_tree().physics_frame
		# Let them settle into the dance, the circle, the stalls.
		await _frames(150)
		print("%s: built %s, dressing %s, %d people, %d lights, notice '%s'" % [v[0], ev.is_built(v[1]),
				ev.has_dressing(v[1]), ev.goers(v[1]).size(), ev.light_count(v[1]), ev.last_notice])
		await _shot(v[0] + ".png")
	get_tree().quit()


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))
	print("saved ", file)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
