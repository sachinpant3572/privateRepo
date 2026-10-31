extends RefCounted
## Races and cycling (scripts/races.gd, scripts/race_course.gd): the hill
## loop built from the real roads, the start prompt, checkpoints and prizes,
## the rivals, the illegal night run and its police star, the bike stand and
## the Calder trial, the save. Run from tests/test_runner.gd (TEST_MODULES);
## `t` is the runner.

const TESTS := ["test_race_course_follows_the_hill_roads", "test_race_start_prompt_and_countdown",
	"test_race_checkpoints_finish_and_prize", "test_race_skipped_checkpoint_does_not_count",
	"test_race_places_pay_by_place", "test_race_rivals_drive_the_course", "test_race_rivals_finish_the_course",
	"test_race_stuck_rival_recovers", "test_night_race_hours_wager_and_pot", "test_night_race_police_star",
	"test_bike_rental_and_trial", "test_bike_medals_and_best_time", "test_bike_rides_the_trail",
	"test_race_save_and_load", "test_races_wired_into_the_game",
	"test_race_start_needs_a_stopped_ride_and_a_free_player", "test_race_jacked_rival_leaves_the_field",
	"test_race_ride_swap_in_the_grace_window", "test_bike_hire_bike_is_not_at_the_line"]
const Races = preload("res://scripts/races.gd")
const RaceCourse = preload("res://scripts/race_course.gd")
const Vehicle = preload("res://scripts/vehicle.gd")
const Terrain = preload("res://scripts/terrain.gd")
const VehicleKit = preload("res://scripts/kits/vehicle_kit.gd")


## A fresh game at `hour` with the races module (the game's own once main.gd
## makes one). Returns the races node.
func _races(t, hour := 12.0):
	await t._new_game(false)
	var game = t.game
	game.atmosphere.minutes_per_second = 0.0
	game.atmosphere.weather_changes = false
	game.atmosphere.hour = hour
	var races = game.get("races")
	if races == null:
		races = Races.new()
		races.game = game
		game.add_child(races)
	await t._frames(3)
	return races


## The player in a car of `kind` on the lead-in `arc` metres from the start.
func _driver(t, races, kind := "sports", arc := 6.0):
	var game = t.game
	var car = Vehicle.new()
	car.kind = kind
	car.city = game.city
	game.add_child(car)
	game.player.enter_vehicle(car)
	var at: Dictionary = RaceCourse.at_arc(races.hill_course(), arc)
	races.put_car(car, at.pos, RaceCourse.yaw_of(at.dir))
	await t._frames(3)
	return car


## The player's ride back on the lead-in `arc` metres from the start.
func _to_start(t, races, arc := 6.0) -> void:
	var at: Dictionary = RaceCourse.at_arc(races.hill_course(), arc)
	races.put_car(t.game.player.vehicle, at.pos, RaceCourse.yaw_of(at.dir))
	await t._frames(2)


## Starts the day race from the start prompt and runs the countdown out.
func _start_day(t, races) -> bool:
	var ok: bool = races.try_interact()
	for i in 260:
		if races.state == Races.State.RACING:
			break
		await t._frames(1)
	return ok and races.state == Races.State.RACING


## Teleports the player's ride onto gate `i` and lets the race see it.
func _to_gate(t, races, i: int) -> void:
	var g: Dictionary = races.course.gates[i]
	races.put_car(t.game.player.vehicle, g.pos, RaceCourse.yaw_of(g.dir))
	await t._frames(2)


func _min_dist_to_roads(country, p: Vector2) -> float:
	var best := INF
	for r in country.roads:
		if not (r.name in RaceCourse.RACE_ROADS):
			continue
		var nodes: PackedInt32Array = r.nodes
		for i in nodes.size() - 1:
			var a: Vector2 = country.pos(nodes[i])
			var b: Vector2 = country.pos(nodes[i + 1])
			var c := Geometry2D.get_closest_point_to_segment(p, a, b)
			best = minf(best, p.distance_to(c))
	return best


func test_race_course_follows_the_hill_roads(t) -> void:
	await t._new_game(false)
	var country = t.game.city.country
	var c: Dictionary = RaceCourse.hill(country, 2)
	t.check(c.get("ok", false), "the hill course builds from the country's roads")
	t.check(RaceCourse.hill(null, 2).is_empty(), "no country, no course")
	var route: PackedVector3Array = c.route
	var gates: Array = c.gates
	var north := INF
	var off_road := 0.0
	for i in range(0, route.size(), 2):
		north = minf(north, route[i].z)
		off_road = maxf(off_road, _min_dist_to_roads(country, Vector2(route[i].x, route[i].z)))
	t.check(north > RaceCourse.RACE_NORTH, "the whole course is south of RACE_NORTH, northmost z %.0f" % north)
	t.check(off_road < 4.5, "the line stays on the named roads, worst %.1f m off" % off_road)
	var worst_gate := 0.0
	var gate_north := INF
	for g in gates:
		worst_gate = maxf(worst_gate, _min_dist_to_roads(country, Vector2(g.pos.x, g.pos.z)))
		gate_north = minf(gate_north, g.pos.z)
	t.check(worst_gate < 4.0 and gate_north > RaceCourse.RACE_NORTH, "every checkpoint stands on the road south of RACE_NORTH, worst %.1f m" % worst_gate)
	# The start: the lead-in begins beside the design map's start spot.
	t.check(Vector2(route[0].x, route[0].z).distance_to(RaceCourse.START) < 40.0, "the course starts by the design map's start spot")
	# A closed loop run twice: the lead-in ends on the lap line, the first lap
	# ends on it, and so does the second (the finish), all on one spot.
	var lines: Array = gates.filter(func(g): return g.lap_line)
	t.check(lines.size() == 3 and gates[gates.size() - 1].lap_line, "three lap lines (start, lap 2, finish), the last is the finish")
	var gap: float = maxf(lines[0].pos.distance_to(lines[1].pos), lines[1].pos.distance_to(lines[2].pos))
	t.check(gap < 8.0, "the lap lines are on the same spot of the loop, %.1f m apart" % gap)
	t.check(float(c.loop_len) > 1500.0 and float(c.loop_len) < 2600.0 and float(c.length) > float(c.lead_len) + 1.9 * float(c.loop_len),
			"the loop is about 1.9 km, got %.0f m (course %.0f)" % [c.loop_len, c.length])
	var spacing_ok := true
	var prev := 0.0
	for g in gates:
		var d: float = float(g.arc) - prev
		if d < 40.0 or d > 230.0:
			spacing_ok = false
		prev = g.arc
	t.check(spacing_ok and gates.size() >= 20, "checkpoints every 40 to 230 m, %d in all" % gates.size())
	# Every metre of the line runs somewhere a car can go: no jump between samples.
	var jump := 0.0
	for i in range(1, route.size()):
		jump = maxf(jump, Vector2(route[i].x - route[i - 1].x, route[i].z - route[i - 1].z).length())
	t.check(jump < RaceCourse.STEP + 0.5, "the line has no gaps, widest step %.1f m" % jump)
	# The AI's corner speeds: never faster than a car can hold, slower at the bends.
	var vlim: PackedFloat32Array = c.vlim
	var vmin := INF
	var vmax := 0.0
	for v in vlim:
		vmin = minf(vmin, v)
		vmax = maxf(vmax, v)
	t.check(vmin >= 2.0 and vmax <= 36.1 and vmax - vmin > 8.0, "corner speeds run %.1f to %.1f m/s" % [vmin, vmax])


func test_race_start_prompt_and_countdown(t) -> void:
	var races = await _races(t, 12.0)
	var game = t.game
	t.check(races.prompt().is_empty() and races.hud_text() == "", "far from the start there is no prompt and no panel")
	var car = await _driver(t, races, "sports", 6.0)
	var pr: Array = races.prompt()
	t.check(pr.size() == 2 and pr[0] == "Hill race: E / RACE" and pr[1] == "RACE", "driving into the start line offers the race, got %s" % [pr])
	game.player.exit_vehicle()
	races.put_car(car, car.global_position + Vector3(0, 0, 400), 0.0)
	t.check(races.prompt().is_empty(), "on foot by the start there is nothing to do (no bike stand here)")
	game.player.enter_vehicle(car)
	var at: Dictionary = RaceCourse.at_arc(races.hill_course(), 6.0)
	races.put_car(car, at.pos, RaceCourse.yaw_of(at.dir))
	# A helicopter or a bicycle cannot run it.
	for kind in ["bicycle", "heli"]:
		var saved: String = car.kind
		car.kind = kind
		t.check(races.prompt().is_empty(), "a %s is not offered the road race" % kind)
		car.kind = saved
	game.cash = 700
	t.check(races.try_interact(), "E at the line is taken")
	t.check(races.state == Races.State.COUNTDOWN and races.mode == "day" and races.rivals.size() == 3, "the countdown starts with three rivals")
	t.check(game.cash == 700, "the day race is free to enter")
	t.check(races.hud_text().begins_with("HILL RACE\n3"), "the panel counts down from 3, got %s" % [races.hud_text()])
	var rival_slots_clear := true
	for r in races.rivals:
		if r.car.global_position.distance_to(car.global_position) < 2.5:
			rival_slots_clear = false
	t.check(rival_slots_clear, "the rivals line up beside the player, not on top")
	var held: Vector3 = car.global_position
	await t._frames(60)
	t.check(races.state == Races.State.COUNTDOWN and car.global_position.distance_to(held) < 1.0, "the player's car is held on the grid during the count")
	await t._frames(150)
	t.check(races.state == Races.State.RACING, "the race goes at zero")
	t.check(races.prompt().is_empty(), "no prompt mid-race")
	var txt: String = races.hud_text()
	t.check(txt.contains("lap 1/2") and txt.contains("checkpoint 1/%d" % races.course.gates.size()) and txt.contains(" of 4"),
			"the panel shows lap, checkpoint and place, got %s" % [txt])
	# A second press mid-race does not start another.
	t.check(not races.start_race("day"), "no second start while racing")
	races.cancel()
	t.check(races.state == Races.State.IDLE and races.rivals.is_empty() and races.hud_text() == "", "cancel clears the field and the panel")
	# Not with the police after you.
	Wanted.report_crime(1)
	t.check(not races.start_race("day") and races.state == Races.State.IDLE, "no race while wanted")
	Wanted.clear()


func test_race_checkpoints_finish_and_prize(t) -> void:
	var races = await _races(t, 12.0)
	var game = t.game
	await _driver(t, races)
	game.cash = 100
	t.check(await _start_day(t, races), "the race starts")
	var gates: Array = races.course.gates
	var in_order := true
	for i in gates.size():
		in_order = in_order and races.next_gate == i
		await _to_gate(t, races, i)
		if races.state != Races.State.RACING:
			break
	t.check(in_order, "each checkpoint counted as the next one in turn")
	t.check(races.state == Races.State.DONE, "passing every checkpoint in order finishes the race")
	t.check(races.result.get("place", 0) == 1 and races.result.prize == 400, "first place pays $400, got %s" % [races.result])
	t.check(game.cash == 500, "the prize is paid, cash %d" % game.cash)
	t.check(races.result.time > 0.0 and races.best.get("day", 0.0) == races.result.time and races.result.new_best,
			"the time is the new best")
	t.check(races.hud_text().contains("1st place"), "the panel shows the result, got %s" % [races.hud_text()])
	# The best time only improves: a slower run keeps it.
	var first: float = races.best["day"]
	await t._frames(8 * 60 + 30)
	t.check(races.state == Races.State.IDLE and races.rivals.is_empty(), "the result shows a few seconds, then the track is clear")
	await _to_start(t, races)
	await _start_day(t, races)
	await t._frames(120)
	for i in gates.size():
		await _to_gate(t, races, i)
		if races.state != Races.State.RACING:
			break
	t.check(races.state == Races.State.DONE and races.best["day"] == first and not races.result.new_best and races.result.time > first,
			"a slower run keeps the best time %.2f (ran %.2f)" % [first, races.result.time])


func test_race_skipped_checkpoint_does_not_count(t) -> void:
	var races = await _races(t, 12.0)
	var game = t.game
	await _driver(t, races)
	game.cash = 100
	await _start_day(t, races)
	var n: int = races.course.gates.size()
	await _to_gate(t, races, 3)
	t.check(races.next_gate == 0, "driving through checkpoint 4 first counts for nothing")
	# The ring's entry (checkpoint 1) and the lap lines and the finish are the
	# same spot: the finish line counts only as the entry now, and does not end it.
	await _to_gate(t, races, n - 1)
	t.check(races.state == Races.State.RACING and races.next_gate == 1, "the finish line does not end the race early (counts as checkpoint 1 only), at %d" % races.next_gate)
	await _to_gate(t, races, 2)
	t.check(races.next_gate == 1, "skipping checkpoint 2 does not count")
	await _to_gate(t, races, 1)
	await _to_gate(t, races, 2)
	t.check(races.next_gate == 3, "then 2 and 3 do, in order")
	# Going back over an earlier one changes nothing.
	await _to_gate(t, races, 0)
	t.check(races.next_gate == 3, "an old checkpoint is not counted twice")
	t.check(game.cash == 100, "nothing is paid for a skipped course")
	# Wandering off the course: the race is lost after a long time without one.
	races._since_gate = races.LOST_TIME + 1.0
	await t._frames(3)
	t.check(races.state == Races.State.IDLE, "a race with no checkpoint for %d s is abandoned" % int(races.LOST_TIME))


func test_race_places_pay_by_place(t) -> void:
	var races = await _races(t, 12.0)
	var game = t.game
	for want in [2, 3, 4]:
		await _driver(t, races)
		game.cash = 0
		await _start_day(t, races)
		var gates: Array = races.course.gates
		# `want - 1` rivals cross the line ahead of the player.
		for k in want - 1:
			races.rivals[k].passed = gates.size()
			races.rivals[k].finish = 0.01 * float(k + 1) # before the teleporting player's ~1 s
		for i in gates.size():
			await _to_gate(t, races, i)
			if races.state != Races.State.RACING:
				break
		var prize: int = [0, 400, 200, 80, 0][want]
		t.check(races.state == Races.State.DONE and races.result.place == want and races.result.prize == prize and game.cash == prize,
				"%s place pays $%d, got %s with cash %d" % [Races.ordinal(want), prize, races.result, game.cash])
		races.cancel()
		await t._frames(2)
	t.check(Races.ordinal(1) == "1st" and Races.ordinal(2) == "2nd" and Races.ordinal(3) == "3rd" and Races.ordinal(4) == "4th",
			"ordinals read right")
	t.check(Races.fmt_time(75.34) == "1:15.3" and Races.fmt_time(9.04) == "0:09.0" and Races.fmt_time(INF) == "--:--.-", "times read m:ss.s")


## Runs the field with the player parked, until `done` says stop or `limit`
## seconds pass; keeps the player's race from timing out.
func _run_field(t, races, limit: float, done: Callable) -> void:
	var frames := int(limit * 60.0)
	for i in frames:
		races._since_gate = 0.0
		await t._frames(1)
		if races.state != Races.State.RACING or done.call():
			return


func test_race_rivals_drive_the_course(t) -> void:
	var races = await _races(t, 12.0)
	await _driver(t, races)
	await _start_day(t, races)
	var start := []
	for r in races.rivals:
		start.append(r.car.global_position)
	await _run_field(t, races, 15.0, func(): return false)
	t.check(races.state == Races.State.RACING, "the race is still on")
	var gates: Array = races.course.gates
	for i in races.rivals.size():
		var r: Dictionary = races.rivals[i]
		var moved: float = r.car.global_position.distance_to(start[i])
		t.check(moved > 120.0, "%s drove %.0f m in 15 s" % [r.name, moved])
		t.check(r.car.speed > 8.0, "%s is up to speed, %.1f m/s" % [r.name, r.car.speed])
		t.check(r.passed >= 1, "%s has passed checkpoints, %d" % [r.name, r.passed])
		# On the road: near the rival's own line.
		var line: PackedVector3Array = r.full
		var best := INF
		for p in line:
			best = minf(best, Vector2(p.x, p.z).distance_to(Vector2(r.car.global_position.x, r.car.global_position.z)))
		t.check(best < 5.0, "%s stays on the line, %.1f m off" % [r.name, best])
	t.check(races.recoveries == 0, "no rival needed a rescue, %d" % races.recoveries)
	var order: Array = races.standings()
	t.check(order.size() == 4 and order[0].passed >= order[3].passed, "standings list the field by checkpoints passed")
	races.cancel()


func test_race_rivals_finish_the_course(t) -> void:
	var races = await _races(t, 12.0)
	await _driver(t, races)
	await _start_day(t, races)
	await _run_field(t, races, 330.0, func(): return races.rivals.all(func(r): return r.finish < INF))
	var finishes := []
	for r in races.rivals:
		finishes.append(snappedf(r.finish, 0.1))
		t.check(r.finish < INF, "%s finished the %d checkpoints (passed %d, %.0f s)" % [r.name, races.course.gates.size(), r.passed, races.time])
	t.check(races.recoveries <= 3, "at most 3 rescues over the whole race, %d" % races.recoveries)
	if not finishes.is_empty() and not (INF in finishes):
		var fastest: float = finishes.min()
		var slowest: float = finishes.max()
		var length: float = races.course.length
		# A good player in a quick car runs 24 to 30 m/s on average: the field
		# is beatable (the best rival is slower than that) but not asleep.
		t.check(length / fastest < 30.0 and length / slowest > 14.0,
				"rivals average %.1f to %.1f m/s over %.0f m (%s)" % [length / slowest, length / fastest, length, finishes])
	races.cancel()


func test_race_stuck_rival_recovers(t) -> void:
	var races = await _races(t, 12.0)
	await _driver(t, races)
	await _start_day(t, races)
	await _run_field(t, races, 6.0, func(): return false)
	var r: Dictionary = races.rivals[1]
	var car = r.car
	# 1. Dead in the road: engine off, wheels still.
	car.driver = Vehicle.Driver.NONE
	car.speed = 0.0
	car.velocity = Vector3.ZERO
	var before: Vector3 = car.global_position
	var rec0: int = races.recoveries
	await _run_field(t, races, 9.0, func(): return races.recoveries > rec0)
	t.check(races.recoveries > rec0, "a rival that stopped is put back on the course (%d rescues)" % races.recoveries)
	await _run_field(t, races, 5.0, func(): return false)
	t.check(car.global_position.distance_to(before) > 25.0 and car.speed > 4.0, "and it drives on, moved %.0f m at %.1f m/s" % [car.global_position.distance_to(before), car.speed])
	# 2. Thrown well off the road.
	var rec1: int = races.recoveries
	var far := Vector3(car.global_position.x + 90.0, 0.0, car.global_position.z)
	races.put_car(car, far, 0.0)
	await _run_field(t, races, 8.0, func(): return races.recoveries > rec1)
	t.check(races.recoveries > rec1, "a rival 90 m off its line is put back (%d rescues)" % races.recoveries)
	await t._frames(60)
	var line: PackedVector3Array = r.full
	var best := INF
	for p in line:
		best = minf(best, Vector2(p.x, p.z).distance_to(Vector2(car.global_position.x, car.global_position.z)))
	t.check(best < 8.0, "back on its line, %.1f m off" % best)
	# 3. A wreck gives way to a fresh car of the same model.
	var old = r.car
	var spot: Vector3 = old.global_position
	old.wrecked = true
	var model: String = r.spec.kind
	await t._frames(3)
	t.check(r.car != old and r.car.kind == model and not r.car.wrecked, "a wrecked rival is swapped for a fresh %s" % model)
	t.check(r.car.global_position.distance_to(spot) < 25.0, "it restarts on the stretch where it burnt out, %.0f m away" % r.car.global_position.distance_to(spot))
	t.check(r.car.max_health > float(VehicleKit.spec(model).health) * 2.5 and r.car.health == r.car.max_health, "and every rival car is tougher than stock (%.0f health)" % r.car.max_health)
	races.cancel()


func test_night_race_hours_wager_and_pot(t) -> void:
	var races = await _races(t, 12.0)
	var game = t.game
	for h in [4.0, 12.0, 20.99]:
		t.check(not Races.is_night_hour(h), "%.2f h is not a night-run hour" % h)
	for h in [21.0, 23.0, 0.0, 3.99]:
		t.check(Races.is_night_hour(h), "%.2f h is a night-run hour" % h)
	await _driver(t, races)
	game.cash = 1000
	t.check(not races.night_race_open() and races.prompt()[0] == "Hill race: E / RACE", "at noon only the day race is offered")
	t.check(not races.start_race("night") and game.cash == 1000, "the night run cannot be started at noon")
	# After dark.
	game.atmosphere.hour = 23.0
	t.check(races.night_race_open(), "open at 23:00")
	var pr: Array = races.prompt()
	t.check(pr.size() == 2 and pr[0] == "Night run, $200 buy-in: E / RACE", "the night run asks a buy-in, got %s" % [pr])
	t.check(not races.start_race("day") and races.state == Races.State.IDLE, "the day race is not run at night")
	t.check(races.wager_for(50) == 0 and races.wager_for(100) == 100 and races.wager_for(1000) == 200 and races.wager_for(9000) == 500
			and races.wager_for(350) == 100, "the buy-in is a quarter of the cash in hundreds, $100 to $500")
	game.cash = 40
	t.check(races.prompt()[0].contains("you need $100"), "too poor for the buy-in, the prompt says so")
	t.check(not races.try_interact() and races.state == Races.State.IDLE and game.cash == 40, "and the press takes nothing, starts nothing and is left to E (get out)")
	game.cash = 1000
	races.set_wager(450)
	t.check(races.wager_for(1000) == 500 or races.wager_for(1000) == 400, "a chosen buy-in is rounded to hundreds, got %d" % races.wager_for(1000))
	races.set_wager(200)
	t.check(races.try_interact() and races.mode == "night" and races.state == Races.State.COUNTDOWN, "E starts the night run")
	t.check(game.cash == 800 and races.stake == 200, "the buy-in is taken, cash %d" % game.cash)
	t.check(races.hud_text().begins_with("NIGHT RUN"), "the panel is titled NIGHT RUN")
	for i in 260:
		if races.state == Races.State.RACING:
			break
		await t._frames(1)
	var gates: Array = races.course.gates
	for i in gates.size():
		await _to_gate(t, races, i)
		if races.state != Races.State.RACING:
			break
	t.check(races.state == Races.State.DONE and races.result.place == 1 and races.result.prize == 800, "the winner takes the pot, got %s" % [races.result])
	t.check(game.cash == 1600, "cash after winning the pot, %d" % game.cash)
	races.cancel()
	# A loss: the buy-in is gone, nothing comes back.
	await t._frames(2)
	game.cash = 1000
	races.set_wager(300)
	races.start_race("night")
	for i in 260:
		if races.state == Races.State.RACING:
			break
		await t._frames(1)
	races.rivals[0].passed = gates.size()
	races.rivals[0].finish = 0.01
	for i in gates.size():
		await _to_gate(t, races, i)
		if races.state != Races.State.RACING:
			break
	t.check(races.result.get("place", 0) == 2 and races.result.prize == 0 and game.cash == 700, "second place loses the $300 buy-in, cash %d" % game.cash)
	# The night rivals are quicker than the day ones.
	var day_skill := 0.0
	for s in Races.DAY_RIVALS:
		day_skill = maxf(day_skill, float(s.skill))
	var night_skill := 0.0
	for s in Races.NIGHT_RIVALS:
		night_skill = minf(night_skill if night_skill > 0.0 else 9.0, float(s.skill))
	t.check(night_skill > day_skill, "the night field's slowest is faster than the day field's fastest")


func test_night_race_police_star(t) -> void:
	var races = await _races(t, 23.0)
	var game = t.game
	await _driver(t, races)
	game.cash = 1000
	races.set_wager(100)
	t.check(races.try_interact(), "the night run starts")
	for i in 260:
		if races.state == Races.State.RACING:
			break
		await t._frames(1)
	# Nobody about: no star.
	await t._frames(90)
	t.check(Wanted.level == 0 and not races.police_sees(), "no police in sight, no star")
	# A patrol car well out of sight range.
	var far = Vehicle.new()
	far.is_police = true
	far.city = game.city
	game.add_child(far)
	var me: Vector3 = game.player.vehicle.global_position
	far.global_position = Vector3(me.x + 90.0, Terrain.height(me.x + 90.0, me.z), me.z)
	await t._frames(60)
	t.check(Wanted.level == 0, "a patrol car 90 m off does not see a thing")
	# One close by with a clear line, but empty and parked (the trap car of
	# events.gd): it sees nothing.
	far.global_position = Vector3(me.x + 14.0, Terrain.height(me.x + 14.0, me.z), me.z)
	await t._frames(60)
	t.check(Wanted.level == 0 and not races.police_sees(), "an empty parked patrol car 14 m off sees nothing, got %d" % Wanted.level)
	# With an officer out of it (police_manager.gd's rule) it does.
	far._deployed = true
	await t._frames(45)
	t.check(Wanted.level == 1, "a patrol car with its officer out 14 m off sees the street race: one star, got %d" % Wanted.level)
	t.check(races.state == Races.State.RACING, "the race goes on")
	races.cancel()
	Wanted.clear()
	far.queue_free()
	# By day the same car sees nothing wrong.
	game.atmosphere.hour = 12.0
	await t._frames(3)
	var car = game.player.vehicle
	var at: Dictionary = RaceCourse.at_arc(races.hill_course(), 6.0)
	races.put_car(car, at.pos, RaceCourse.yaw_of(at.dir))
	var cop = Vehicle.new()
	cop.is_police = true
	cop.city = game.city
	game.add_child(cop)
	var q: Vector3 = at.pos + Vector3(10.0, 0.0, 0.0)
	cop.global_position = Vector3(q.x, Terrain.height(q.x, q.z), q.z)
	t.check(races.try_interact() and races.mode == "day", "the day race starts")
	await t._frames(260)
	await t._frames(60)
	t.check(Wanted.level == 0, "a day race with a patrol car beside it is legal")
	races.cancel()
	cop.queue_free()


func test_bike_rental_and_trial(t) -> void:
	var races = await _races(t, 12.0)
	var game = t.game
	var trail: Dictionary = races.trail_course()
	t.check(not trail.is_empty() and trail.gates.size() >= 4, "the Calder Trail run builds with %d checkpoints" % trail.get("gates", []).size())
	var top: Vector3 = trail.top
	t.check(Vector2(top.x, top.z).distance_to(RaceCourse.BIKE_SPOT) < 60.0, "the run starts near the design map's spot")
	var first: Vector3 = trail.route[0]
	var last: Vector3 = trail.route[trail.route.size() - 1]
	t.check(first.y - last.y > 40.0, "it runs downhill: %.0f m of drop" % (first.y - last.y))
	var s: Vector3 = races.stand_pos()
	t.check(Vector2(s.x, s.z).distance_to(Vector2(top.x, top.z)) < 12.0, "the stand is beside the top")
	# On foot at the stand.
	var p = game.player
	p.global_position = s + Vector3(0.0, 0.0, 3.0)
	p.reset_physics_interpolation()
	game.cash = 5
	var pr: Array = races.prompt()
	t.check(pr.size() == 2 and pr[1] == "ENTER" and pr[0].contains("short"), "too poor: the stand says so, got %s" % [pr])
	t.check(not races.try_interact() and p.vehicle == null and game.cash == 5, "no bike without the $10, and E is left to its other jobs")
	game.cash = 50
	pr = races.prompt()
	t.check(pr.size() == 2 and pr[0] == "Rent a bike for $10: E / RENT", "with the cash it offers a bike, got %s" % [pr])
	t.check(races.try_interact(), "E rents it")
	t.check(p.vehicle != null and p.vehicle.kind == "bicycle" and game.cash == 40, "the player is on a bicycle, $10 poorer (cash %d)" % game.cash)
	t.check(p.vehicle.global_position.distance_to(top) < 40.0, "the bike is on the trail below the top")
	var bike = p.vehicle
	var up: Dictionary = RaceCourse.at_arc(trail, 3.0)
	races.put_car(bike, up.pos, RaceCourse.yaw_of(up.dir))
	pr = races.prompt()
	t.check(pr.size() == 2 and pr[0] == "Calder downhill trial: E / START" and pr[1] == "START", "on the bike at the top: the trial is offered, got %s" % [pr])
	# Far from the top the bike is just a bike.
	races.put_car(bike, top + Vector3(0.0, 0.0, 200.0), 0.0)
	t.check(races.prompt().is_empty(), "away from the top no trial is offered")
	var at: Dictionary = RaceCourse.at_arc(trail, 2.0)
	races.put_car(bike, at.pos, RaceCourse.yaw_of(at.dir))
	t.check(races.try_interact() and races.state == Races.State.COUNTDOWN and races.mode == "bike", "E at the top starts the trial")
	t.check(races.rivals.is_empty(), "the trial is against the clock")
	await t._frames(200)
	t.check(races.state == Races.State.RACING, "the trial runs")
	var txt: String = races.hud_text()
	t.check(txt.contains("CALDER DOWNHILL") and txt.contains("checkpoint 1/%d" % trail.gates.size()), "the panel shows the checkpoint, got %s" % [txt])
	# Gates in order finish; skipping one does not count.
	var g: Array = trail.gates
	races.put_car(bike, g[2].pos, RaceCourse.yaw_of(g[2].dir))
	await t._frames(2)
	t.check(races.next_gate == 0, "checkpoint 3 before 1 and 2 does not count")
	for i in g.size():
		races.put_car(bike, g[i].pos, RaceCourse.yaw_of(g[i].dir))
		await t._frames(2)
		if races.state != Races.State.RACING:
			break
	t.check(races.state == Races.State.DONE and races.result.mode == "bike", "the last checkpoint ends the trial")
	t.check(races.result.medal == 3 and races.result.prize == 300 and game.cash == 340, "a very fast run takes gold and its $300, cash %d" % game.cash)
	t.check(races.best.get("bike", 0.0) == races.result.time and races.medal == 3, "the time and the medal are kept")
	# Quitting the saddle abandons the trial.
	await t._frames(8 * 60 + 30)
	races.put_car(bike, at.pos, RaceCourse.yaw_of(at.dir))
	races.try_interact()
	await t._frames(200)
	p.exit_vehicle()
	await t._frames(8 * 60 + 30)
	t.check(races.state == Races.State.IDLE, "walking away from the bike abandons the trial")


func test_bike_medals_and_best_time(t) -> void:
	var races = await _races(t, 12.0)
	var game = t.game
	t.check(races.medal_time(1) > races.medal_time(2) and races.medal_time(2) > races.medal_time(3) and races.medal_time(3) > 40.0,
			"gold is the quickest time: %.0f, %.0f, %.0f s" % [races.medal_time(1), races.medal_time(2), races.medal_time(3)])
	t.check(races.medal_for(races.medal_time(1) + 1.0) == 0, "slower than bronze: no medal")
	t.check(races.medal_for(races.medal_time(1) - 0.5) == 1 and races.medal_for(races.medal_time(2) + 0.5) == 1, "bronze")
	t.check(races.medal_for(races.medal_time(2) - 0.5) == 2 and races.medal_for(races.medal_time(3) + 0.5) == 2, "silver")
	t.check(races.medal_for(races.medal_time(3) - 0.5) == 3, "gold")
	t.check(races.medal_for(0.0) == 0, "a zero time earns nothing")
	var trail: Dictionary = races.trail_course()
	var s: Vector3 = races.stand_pos()
	game.cash = 100
	var p = game.player
	p.global_position = s + Vector3(0.0, 0.0, 3.0)
	p.reset_physics_interpolation()
	races.try_interact()
	var bike = p.vehicle
	# A bronze run, paid $60; a silver after it pays the $90 difference; a
	# second bronze pays nothing and keeps the better time.
	var cash_before: int = game.cash
	var paid := []
	var times := [races.medal_time(1) - 2.0, races.medal_time(2) - 2.0, races.medal_time(1) - 1.0]
	for want in times:
		var at: Dictionary = RaceCourse.at_arc(trail, 2.0)
		races.put_car(bike, at.pos, RaceCourse.yaw_of(at.dir))
		races.try_interact()
		for i in 200:
			if races.state == Races.State.RACING:
				break
			await t._frames(1)
		# Hold the clock at the wanted run time.
		races.time = want
		var g: Array = trail.gates
		for i in g.size():
			races.put_car(bike, g[i].pos, RaceCourse.yaw_of(g[i].dir))
			await t._frames(2)
			if races.state != Races.State.RACING:
				break
		paid.append(races.result.prize)
		races.cancel()
		await t._frames(2)
	t.check(paid == [60, 90, 0], "medal cash is paid as the medal improves, got %s" % [paid])
	t.check(races.medal == 2 and game.cash == cash_before + 150, "best medal silver, cash %d" % game.cash)
	t.check(absf(races.best["bike"] - (races.medal_time(2) - 2.0)) < 0.5, "the best time is the quickest run, %.1f" % races.best["bike"])


func test_bike_rides_the_trail(t) -> void:
	# The line is ridable: a bicycle steered along it passes every checkpoint
	# in order and earns a medal; nothing on the way holds it.
	var races = await _races(t, 12.0)
	var game = t.game
	var trail: Dictionary = races.trail_course()
	var s: Vector3 = races.stand_pos()
	game.cash = 100
	game.player.global_position = s + Vector3(0.0, 0.0, 3.0)
	game.player.reset_physics_interpolation()
	races.try_interact()
	var bike = game.player.vehicle
	var at: Dictionary = RaceCourse.at_arc(trail, 2.0)
	races.put_car(bike, at.pos, RaceCourse.yaw_of(at.dir))
	races.try_interact()
	for i in 200:
		if races.state == Races.State.RACING:
			break
		await t._frames(1)
	var pts := PackedVector3Array()
	for i in range(0, trail.route.size(), 3):
		pts.append(trail.route[i])
	pts.append(trail.route[trail.route.size() - 1])
	bike.drive_path(pts, 1.0)
	var frames := 0
	while races.state == Races.State.RACING and frames < 60 * 400:
		await t._frames(1)
		frames += 1
	t.check(races.state == Races.State.DONE, "the bike reaches the last checkpoint in %.0f s (checkpoint %d/%d)" % [races.time, races.next_gate, trail.gates.size()])
	t.check(races.result.get("medal", 0) >= 1, "and the ride is worth a medal: %.0f s over %.0f m, medal %s" % [races.time, trail.length, races.result.get("medal", 0)])
	races.cancel()


func test_race_save_and_load(t) -> void:
	var races = await _races(t, 12.0)
	races.best = {"day": 151.5, "night": 140.25, "bike": 98.0}
	races.medal = 2
	var saved: Dictionary = JSON.parse_string(JSON.stringify(races.to_save()))
	t.check(saved.has("best") and saved["best"].size() == 3, "the save holds the best times, got %s" % [saved])
	races.load_save({})
	t.check(races.best.is_empty() and races.medal == 0, "load_save({}) clears them")
	races.load_save(saved)
	t.check(races.best == {"day": 151.5, "night": 140.25, "bike": 98.0} and races.medal == 2, "best times and medal survive a JSON round trip, got %s" % [races.to_save()])
	races.load_save({"best": {"day": -5, "night": "fast", "bike": 99999999.0, "moon": 12.0, "x": 9.0}, "medal": 99})
	t.check(races.best.is_empty() and races.medal == 3, "a bad save is dropped or clamped, got %s" % [races.to_save()])
	races.load_save({"best": "oops"})
	t.check(races.best.is_empty(), "a save of the wrong shape is ignored")
	# Loading cancels a race in progress.
	await _driver(t, races)
	t.game.cash = 100
	races.start_race("day")
	t.check(races.state == Races.State.COUNTDOWN, "a race is on")
	races.load_save({})
	t.check(races.state == Races.State.IDLE, "loading a save ends it")


## Only once main.gd makes the module (the patch in HANDOFF-races.md): the
## game's own HUD, E press and save reach it.
func test_races_wired_into_the_game(t) -> void:
	await t._new_game(false)
	var game = t.game
	# Fails until the main session applies HANDOFF-races-wiring.patch (intended).
	t.check(game.get("races") != null, "main.gd makes the races module (patch: HANDOFF-races-wiring.patch)")
	var races = game.races
	game.atmosphere.minutes_per_second = 0.0
	game.atmosphere.hour = 12.0
	var car = await _driver(t, races)
	await t._frames(3)
	game.hud._process(0.016)
	t.check(game.hud._prompt.text == "Hill race: E / RACE", "the HUD shows the prompt in the car, got %s" % [game.hud._prompt.text])
	t.check(game.hud.touch == null or game.hud.touch.labels.get("interact", "") == "RACE", "the interact button reads RACE")
	await t._press("interact")
	t.check(game.player.vehicle == car and races.state != Races.State.IDLE, "E at the line starts the race and does not get out")
	game.hud._process(0.016)
	t.check(game.hud._race.text.begins_with("HILL RACE"), "the race panel is on the HUD, got %s" % [game.hud._race.text])
	races.cancel()
	# Wanted, in a car at the line: the race cannot start, so E gets out.
	Wanted.report_crime(1)
	await t._frames(3)
	game.hud._process(0.016)
	t.check(game.hud._prompt.text == "Lose the police first", "the HUD says why there is no race, got %s" % [game.hud._prompt.text])
	await t._press("interact")
	t.check(game.player.vehicle == null and races.state == Races.State.IDLE, "wanted at the line: E gets out of the car, it does not start a race")
	Wanted.clear()
	# The save goes through the mission manager.
	races.best = {"day": 123.5}
	races.medal = 1
	var mm = game.missions
	mm.save_enabled = true
	mm.save_path = "user://test_save_races.json"
	mm.save_game()
	races.load_save({})
	mm.load_game()
	t.check(races.best == {"day": 123.5} and races.medal == 1, "best times ride the game save, got %s" % [races.to_save()])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(mm.save_path))
	mm.reset_progress()
	t.check(races.best.is_empty(), "New game wipes them")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(mm.save_path))
	var markers: Array = game.map_markers().filter(func(m): return m.get("label", "") == "Hill race")
	t.check(markers.size() == 1, "the start line is on the map")


## The start is offered to a nearly stopped ride only, and never during a
## mission or a taxi trip; a refused press is left to E (getting out).
func test_race_start_needs_a_stopped_ride_and_a_free_player(t) -> void:
	var races = await _races(t, 12.0)
	var game = t.game
	var car = await _driver(t, races, "sports", 6.0)
	t.check(not races.prompt().is_empty(), "stopped on the line: the race is offered")
	car.speed = 14.0
	t.check(races.prompt().is_empty() and not races.try_interact() and races.state == Races.State.IDLE, "rolling through at 14 m/s: no offer, E is not taken")
	car.speed = 2.0
	t.check(not races.prompt().is_empty(), "crawling at 2 m/s: offered")
	car.speed = 0.0
	# Wanted: the prompt explains, the press is not taken (E gets out).
	Wanted.report_crime(1)
	var pr: Array = races.prompt()
	t.check(pr.size() == 2 and pr[0] == "Lose the police first" and pr[1] == "EXIT", "wanted: the prompt says so and the button is EXIT, got %s" % [pr])
	t.check(not races.try_interact() and races.state == Races.State.IDLE and game.player.vehicle == car, "wanted: the press starts nothing and is left to E")
	Wanted.clear()
	# A mission or a taxi trip has the player's attention.
	game.missions.active = RefCounted.new()
	t.check(races.prompt().is_empty() and not races.try_interact() and not races.start_race("day"), "no race during a mission")
	game.missions.active = null
	t.check(not races.prompt().is_empty(), "the mission over: offered again")
	var idle: int = game.taxi.state
	game.taxi.state = game.taxi.State.RIDING
	t.check(races.prompt().is_empty() and not races.start_race("day"), "no race during a taxi trip")
	game.taxi.state = idle
	t.check(races.try_interact() and races.state == Races.State.COUNTDOWN, "free again: E starts it")
	races.cancel()


## A rival the player has jacked is out of the race: never driven, recovered,
## replaced or freed by it.
func test_race_jacked_rival_leaves_the_field(t) -> void:
	var races = await _races(t, 12.0)
	var game = t.game
	await _driver(t, races)
	t.check(races.try_interact() and races.rivals.size() == 3, "a race with three rivals")
	# 1. In the grace window of the countdown: out of the car, into a rival's.
	var mine = game.player.vehicle
	var r0: Dictionary = races.rivals[0]
	var stolen = r0.car
	game.player.exit_vehicle()
	game.player.enter_vehicle(stolen)
	await _start_wait(t, races)
	t.check(races.state == Races.State.RACING and races.rivals.size() == 2 and not races.rivals.has(r0), "the jacked rival leaves the field, %d left" % races.rivals.size())
	t.check(is_instance_valid(stolen) and stolen.driver == Vehicle.Driver.PLAYER and game.player.vehicle == stolen, "GO does not drive the stolen car off with the player in it")
	# 2. Mid-race: another rival is taken; it is not teleported back or freed.
	var r1: Dictionary = races.rivals[0]
	var second = r1.car
	game.player.exit_vehicle()
	game.player.enter_vehicle(second)
	var spot: Vector3 = second.global_position
	r1.stall = 99.0
	r1.far = 99.0
	await t._frames(4)
	t.check(not races.rivals.has(r1) and races.recoveries == 0, "a jacked rival is never recovered (%d rescues)" % races.recoveries)
	t.check(second.global_position.distance_to(spot) < 3.0, "and it stays where the player took it, moved %.1f m" % second.global_position.distance_to(spot))
	# 3. The calls themselves refuse a car the player is in.
	var r2: Dictionary = races.rivals[0]
	var third = r2.car
	game.player.exit_vehicle()
	game.player.enter_vehicle(third)
	races._replace_rival(r2)
	t.check(is_instance_valid(third) and not third.is_queued_for_deletion() and not races.rivals.has(r2), "a jacked rival's car is never replaced or freed")
	r2 = {"car": third, "full": PackedVector3Array(), "base": 0}
	races.recover_rival(r2)
	t.check(races.recoveries == 0, "nor recovered by a direct call")
	races.cancel()
	t.check(is_instance_valid(mine) and is_instance_valid(stolen) and not stolen.is_queued_for_deletion(), "cancelling frees none of the cars the player took")


## Runs the countdown out.
func _start_wait(t, races) -> void:
	for i in 260:
		if races.state == Races.State.RACING:
			break
		await t._frames(1)


## Leaving the car in the grace window: a helicopter (or any ride a race bars)
## ends the race, and nothing counts on foot.
func test_race_ride_swap_in_the_grace_window(t) -> void:
	var races = await _races(t, 12.0)
	var game = t.game
	await _driver(t, races)
	t.check(races.try_interact(), "a race starts")
	await _start_wait(t, races)
	t.check(races.state == Races.State.RACING, "racing")
	# On foot at checkpoint 1: it does not count.
	game.player.exit_vehicle()
	var g: Dictionary = races.course.gates[0]
	game.player.global_position = g.pos
	game.player.reset_physics_interpolation()
	await t._frames(3)
	t.check(races.state == Races.State.RACING and races.next_gate == 0, "a checkpoint walked through on foot does not count, next gate %d" % races.next_gate)
	# Into a ride the race bars (a tipper truck, like a helicopter): over.
	var barred = Vehicle.new()
	barred.kind = "tipper"
	barred.city = game.city
	game.add_child(barred)
	game.player.enter_vehicle(barred)
	await t._frames(3)
	t.check(races.state == Races.State.IDLE, "taking a barred ride in the grace window ends the race")
	game.player.exit_vehicle()
	# The trial wants a bicycle: a car does not do.
	var bike = Vehicle.new()
	bike.kind = "bicycle"
	bike.city = game.city
	game.add_child(bike)
	game.player.enter_vehicle(bike)
	var at: Dictionary = RaceCourse.at_arc(races.trail_course(), 3.0)
	races.put_car(bike, at.pos, RaceCourse.yaw_of(at.dir))
	t.check(races.try_interact() and races.mode == "bike", "the trial starts")
	game.player.exit_vehicle()
	var car = Vehicle.new()
	car.kind = "sports"
	car.city = game.city
	game.add_child(car)
	game.player.enter_vehicle(car)
	await t._frames(3)
	t.check(races.state == Races.State.IDLE, "a car is no good for the downhill trial")


## The hired bike stands below the top, outside the trial range and facing it:
## the first E gets off; the bike left far away is taken back.
func test_bike_hire_bike_is_not_at_the_line(t) -> void:
	var races = await _races(t, 12.0)
	var game = t.game
	var top: Vector3 = races.trail_top()
	var p = game.player
	var s: Vector3 = races.stand_pos()
	p.global_position = s + Vector3(0.0, 0.0, 3.0)
	p.reset_physics_interpolation()
	game.cash = 50
	t.check(races.try_interact(), "E hires a bike")
	var bike = p.vehicle
	var d := Vector2(bike.global_position.x - top.x, bike.global_position.z - top.z).length()
	t.check(d > Races.TRIAL_RANGE, "the hired bike is %.0f m from the top, outside the %.0f m trial range" % [d, Races.TRIAL_RANGE])
	t.check(races.prompt().is_empty() and not races.try_interact(), "so on the new bike E is not taken: it gets off")
	# Pedalled up to the line and stopped, it is offered; rolling, it is not.
	var up: Dictionary = RaceCourse.at_arc(races.trail_course(), 3.0)
	races.put_car(bike, up.pos, RaceCourse.yaw_of(up.dir))
	t.check(not races.prompt().is_empty(), "stopped at the top: the trial is offered")
	bike.speed = 6.0
	t.check(races.prompt().is_empty(), "rolling through the top: it is not")
	bike.speed = 0.0
	# Left a long way off, with the player on foot elsewhere, the bike goes.
	p.exit_vehicle()
	races.put_car(bike, top + Vector3(0.0, 0.0, 300.0), 0.0)
	p.global_position = s + Vector3(0.0, 0.0, 3.0)
	p.reset_physics_interpolation()
	await t._frames(80)
	t.check(not is_instance_valid(bike) or bike.is_queued_for_deletion(), "a bike left 300 m away is taken back")
	var pr: Array = races.prompt()
	t.check(pr.size() == 2 and pr[1] == "RENT", "and the stand hires another, got %s" % [pr])
