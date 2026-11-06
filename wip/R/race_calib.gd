extends Node
## TEMPORARY calibration probe for races (not committed).

const MainScene = preload("res://main.tscn")
const Vehicle = preload("res://scripts/vehicle.gd")
const Races = preload("res://scripts/races.gd")
const RC = preload("res://scripts/race_course.gd")

var game
var races


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	game = MainScene.instantiate()
	game.settings["camera_turn"] = "north"
	game.population_enabled = false
	game.missions_enabled = false
	game.save_enabled = false
	add_child(game)
	game.atmosphere.minutes_per_second = 0.0
	game.atmosphere.weather_changes = false
	await _frames(5)
	races = Races.new()
	races.game = game
	game.add_child(races)
	await _frames(2)
	var hill = races.hill_course()
	print("hill ok ", hill.get("ok", false), " len ", hill.length, " gates ", hill.gates.size(), " vmean ", _mean(hill.vlim))
	var tr = races.trail_course()
	print("trail ok ", not tr.is_empty(), " len ", tr.get("length", 0), " gates ", tr.get("gates", []).size())
	var groups := {
		"day": Races.DAY_RIVALS,
		"night": Races.NIGHT_RIVALS,
		"ghost": [
			{"name": "g100", "kind": "sedan", "paint": Color(1, 1, 1), "skill": 1.0, "off": 1.4},
			{"name": "g115", "kind": "sedan", "paint": Color(1, 1, 1), "skill": 1.15, "off": -1.4},
			{"name": "g130", "kind": "sedan", "paint": Color(1, 1, 1), "skill": 1.3, "off": 0.0},
		],
	}
	var only := OS.get_environment("GROUPS")
	for g in groups:
		if only != "" and not g in only.split(","):
			continue
		await _group(g, groups[g])
	if only == "" or "bike" in only.split(","):
		await _bike()
	get_tree().quit()


func _mean(a) -> float:
	var s := 0.0
	for v in a:
		s += v
	return s / maxf(a.size(), 1)


func _group(label: String, specs: Array) -> void:
	game.atmosphere.hour = 12.0
	races.course = races.hill_course()
	var grid = races._slot(0, -1)
	var car = Vehicle.new()
	car.kind = "sedan"
	car.city = game.city
	game.add_child(car)
	races.put_car(car, grid.pos, grid.yaw)
	game.player.enter_vehicle(car)
	game.cash = 5000
	var ok = races.start_race("day")
	print("[", label, "] start ", ok, " state ", races.state)
	races._clear_rivals()
	races._spawn_rivals(specs)
	var t0 := Time.get_ticks_msec()
	var frames := 0
	var last_pass := []
	var times := []
	for r in races.rivals:
		last_pass.append(0)
		times.append([])
	var next_report := 20.0
	while races.state != Races.State.IDLE and frames < 60 * 420:
		races._since_gate = 0.0
		await get_tree().physics_frame
		frames += 1
		if races.state == Races.State.RACING:
			var done := true
			for i in races.rivals.size():
				var r = races.rivals[i]
				if r.passed != last_pass[i]:
					last_pass[i] = r.passed
					times[i].append(snappedf(races.time, 0.1))
				if r.finish == INF:
					done = false
			if races.time >= next_report:
				next_report += 20.0
				var s := ""
				for r in races.rivals:
					s += " %s:%d/%d v%.1f" % [r.name, r.passed, races.course.gates.size(), r.car.speed]
				print("  t=%.0f%s rec=%d" % [races.time, s, races.recoveries])
			if done:
				break
	print("[", label, "] wall ms ", Time.get_ticks_msec() - t0, " frames ", frames, " race time ", races.time, " recoveries ", races.recoveries)
	for i in races.rivals.size():
		var r = races.rivals[i]
		print("  ", r.name, " finish ", r.finish, " passed ", r.passed, " gate times ", times[i])
	races.cancel()
	game.player.exit_vehicle()
	car.queue_free()
	await _frames(3)


func _bike() -> void:
	var tr = races.trail_course()
	if tr.is_empty():
		return
	var bike = Vehicle.new()
	bike.kind = "bicycle"
	bike.city = game.city
	game.add_child(bike)
	var at = RC.at_arc(tr, 2.0)
	races.put_car(bike, at.pos, RC.yaw_of(at.dir))
	await _frames(3)
	var pts := PackedVector3Array()
	for i in range(0, tr.route.size(), 3):
		pts.append(tr.route[i])
	pts.append(tr.route[tr.route.size() - 1])
	bike.drive_path(pts, 1.0)
	var frames := 0
	var maxv := 0.0
	while bike.path_index < bike.path.size() - 1 and frames < 60 * 400:
		await get_tree().physics_frame
		frames += 1
		maxv = maxf(maxv, bike.speed)
		if frames % 600 == 0:
			print("  bike t=%d idx %d/%d v %.1f" % [frames / 60, bike.path_index, pts.size(), bike.speed])
	print("[bike] AI time ", frames / 60.0, " over ", tr.length, " m  avg ", tr.length / (frames / 60.0), " max v ", maxv, " idx ", bike.path_index, "/", pts.size())
