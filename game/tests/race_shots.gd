extends Node
## Screenshots of the races and the bike trial (scripts/races.gd): the start
## line with its prompt, the grid at the countdown, a checkpoint gate with the
## rivals closing in, the night run's start and gate, the bike stand and a
## trail checkpoint. Needs a real renderer:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 \
##     --resolution 1280x720 res://tests/race_shots.tscn -- <out_dir>
## 8 shots (race_1 .. race_8); read them through tools/contactsheet.sh.

const MainScene = preload("res://main.tscn")
const Vehicle = preload("res://scripts/vehicle.gd")
const Races = preload("res://scripts/races.gd")
const RaceCourse = preload("res://scripts/race_course.gd")
const Terrain = preload("res://scripts/terrain.gd")

var out_dir := "user://"
var game
var races


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
	game.population_enabled = false
	add_child(game)
	game.atmosphere.hour = 12.5
	game.atmosphere.minutes_per_second = 0.0
	game.atmosphere.weather_changes = false
	game.hud.touch.visible = true
	game.cash = 1000
	await _frames(30)
	races = game.get("races")
	if races == null:
		races = Races.new()
		races.game = game
		game.add_child(races)
	await _frames(5)
	var hill: Dictionary = races.hill_course()
	var car = Vehicle.new()
	car.kind = "sports"
	car.body_color = Color(0.82, 0.16, 0.16)
	car.city = game.city
	game.add_child(car)
	game.player.enter_vehicle(car)

	# 1. The start line by day, with the prompt.
	_on_course(car, hill, 6.0, 0.0)
	await _frames(100)
	await _shot("race_1_start_prompt.png")

	# 2. The grid at the countdown.
	races.try_interact()
	await _frames(100)
	await _shot("race_2_countdown.png")

	# 3. A checkpoint gate with the rivals closing in.
	for i in 200:
		if races.state == races.State.RACING:
			break
		await _frames(1)
	_on_course(car, hill, float(hill.gates[0].arc) - 1.0, 16.0)
	for i in 1500:
		await _frames(1)
		races._since_gate = 0.0
		var near := false
		for r in races.rivals:
			if r.car.global_position.distance_to(car.global_position) < 17.0:
				near = true
		if near:
			break
	await _shot("race_3_gate_rivals.png")
	races.cancel()

	# 4. The night run: the arch relabelled, the prompt with the buy-in.
	game.atmosphere.hour = 23.0
	_on_course(car, hill, 6.0, 0.0)
	await _frames(150)
	await _shot("race_4_night_start.png")

	# 5. A night gate.
	races.try_interact()
	for i in 260:
		await _frames(1)
	_on_course(car, hill, float(hill.gates[0].arc) - 1.0, 16.0)
	await _frames(150) # the GO! message has faded by then
	await _shot("race_5_night_gate.png")
	races.cancel()
	game.atmosphere.hour = 12.5
	await _frames(30)

	# 6. The bike stand, on foot.
	game.player.exit_vehicle()
	var stand: Vector3 = races.stand_pos()
	var p = game.player
	p.global_position = Vector3(stand.x, Terrain.height(stand.x, stand.z), stand.z) + _stand_front() * 3.8
	p.reset_physics_interpolation()
	game.camera.snap()
	game.cash = 50
	await _frames(60)
	await _shot("race_6_bike_stand.png")

	# 7. The trial: the bike at the top, the countdown, a trail checkpoint.
	races.try_interact()
	await _frames(30)
	await _shot("race_7_bike_rented.png")
	# The hired bike stands below the top: pedal up to the line, then start.
	_on_course(game.player.vehicle, races.trail_course(), 3.0, 0.0)
	await _frames(10)
	races.try_interact()
	for i in 220:
		await _frames(1)
	var trail: Dictionary = races.trail_course()
	_on_course(game.player.vehicle, trail, float(trail.gates[0].arc) - 14.0, 0.0)
	await _frames(150) # the GO! message has faded by then
	await _shot("race_8_trail_gate.png")
	get_tree().quit()


## The side of the stand with the bikes on it (its local +Z).
func _stand_front() -> Vector3:
	var at: Dictionary = RaceCourse.at_arc(races.trail_course(), 0.0)
	return Basis(Vector3.UP, RaceCourse.yaw_of(at.dir)) * Vector3(0.0, 0.0, 1.0)


## `ride` on the course at `arc` metres, `off` metres to the right of the line.
func _on_course(ride, course: Dictionary, arc: float, off: float) -> void:
	var at: Dictionary = RaceCourse.at_arc(course, arc)
	var pos: Vector3 = at.pos + RaceCourse.right_of(at.dir) * off
	races.put_car(ride, pos, RaceCourse.yaw_of(at.dir))


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))
	print("saved ", file)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
