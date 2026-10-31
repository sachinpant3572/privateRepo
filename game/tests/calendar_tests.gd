extends RefCounted
## The calendar (scripts/calendar.gd) and the events on it (scripts/events.gd):
## the day count, weekdays and seasons, the save, the schedule, and the
## events building near the player and going away with the clock or with
## distance. Run from tests/test_runner.gd (TEST_MODULES); `t` is the runner.
##
## main.gd does not create the Calendar or Events nodes yet (see the patch in
## the package report), so each test makes its own and hangs them on the game.

const Calendar = preload("res://scripts/calendar.gd")
const Events = preload("res://scripts/events.gd")
const Terrain = preload("res://scripts/terrain.gd")

const TESTS := [
	"test_calendar_clock_and_dates",
	"test_calendar_save_and_open_season",
	"test_calendar_schedule",
	"test_calendar_places_and_pads",
	"test_calendar_rave_comes_and_goes",
	"test_calendar_fair_and_market",
	"test_calendar_cult_and_trap",
	"test_calendar_far_player_builds_nothing",
	"test_calendar_lights_and_phone_list",
]

## Seconds a build may take in real time (the dressing bakes on a worker and
## the people come one every 0.3 s).
const BUILD_WAIT := 90.0


# --- Helpers ---------------------------------------------------------------------------

## A calendar and an events node on the test game, with the clock frozen.
func _rig(t) -> Array:
	var game = t.game
	game.atmosphere.minutes_per_second = 0.0
	game.atmosphere.weather_changes = false
	var cal = Calendar.new()
	cal.game = game
	game.add_child(cal)
	var ev = Events.new()
	ev.game = game
	ev.calendar = cal
	game.add_child(ev)
	return [cal, ev]


## Puts the player 40 m south of `c` (high up: the hills may not have
## collision yet) and sets the day and hour; nothing awaits in between so the
## events node never sees a half-set scene.
func _setup(t, cal, c: Vector3, day: int, hour: float, dist := 40.0) -> void:
	cal.set_day(day)
	t.game.atmosphere.hour = hour
	t._place_player_at(Vector3(c.x, 300.0, c.z + dist))


func _built(ev, id: String, min_goers: int) -> bool:
	return ev.has_dressing(id) and ev.goers(id).size() >= min_goers


func _spread(c: Vector3, r: float) -> float:
	var lo := INF
	var hi := -INF
	for a in 12:
		var ang := TAU * float(a) / 12.0
		for rr in [0.0, r * 0.5, r]:
			var h := maxf(Terrain.height(c.x + cos(ang) * rr, c.z + sin(ang) * rr), 0.0)
			lo = minf(lo, h)
			hi = maxf(hi, h)
	return hi - lo


# --- Tests -----------------------------------------------------------------------------

func test_calendar_clock_and_dates(t) -> void:
	# The pure clock: a jump back over midnight is a new day; a small step
	# back (a rewound clock) is not.
	var c = Calendar.new()
	c.tick(22.0)
	c.tick(23.5)
	t.check(c.day() == 0, "no new day before midnight, day %d" % c.day())
	c.tick(0.5)
	t.check(c.day() == 1, "the day goes up when the hour wraps, day %d" % c.day())
	c.tick(1.0)
	c.tick(0.8)
	t.check(c.day() == 1, "a small step back is not a new day")
	var seen := [0]
	c.day_changed.connect(func(d): seen[0] = d)
	c.tick(23.9)
	c.tick(0.1)
	t.check(c.day() == 2 and seen[0] == 2, "day_changed fires with the new day, got %d" % seen[0])
	# The first day is a Friday, day 10 of autumn.
	c.set_day(0)
	t.check(c.weekday() == 4 and c.weekday_name() == "Friday", "the game starts on a Friday, got %s" % c.weekday_name())
	t.check(c.season() == "autumn" and c.day_of_season() == 9 and c.day_of_year() == 65,
			"it starts on day 10 of autumn, got %s" % c.date_text())
	var names := []
	for d in 7:
		names.append(Calendar.WEEKDAYS[Calendar.weekday_of(d)])
	t.check(names == ["Friday", "Saturday", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday"],
			"weekdays run in order, got %s" % [names])
	t.check(Calendar.weekday_of(112) == Calendar.weekday_of(0) and Calendar.weekday_of(-3) == 1,
			"a 112-day year is 16 whole weeks, and days before the start still have a weekday")
	var seasons := []
	for d in [0, 18, 19, 46, 47, 74, 75, 102, 103, 111, 112]:
		seasons.append(Calendar.season_of(d))
	t.check(seasons == ["autumn", "autumn", "winter", "winter", "spring", "spring", "summer", "summer", "autumn", "autumn", "autumn"],
			"seasons follow the 28-day quarters, got %s" % [seasons])
	t.check(Calendar.day_of_season_of(19) == 0 and Calendar.day_of_season_of(18) == 27, "a season is 28 days")
	c.free()

	# Driven by the game's clock (the node ticks from atmosphere.hour).
	await t._new_game(false)
	var rig := _rig(t)
	var cal = rig[0]
	var atm = t.game.atmosphere
	atm.hour = 23.9
	await t._frames(3)
	atm.hour = 0.1
	await t._frames(3)
	t.check(cal.day() == 1, "the node ticks the day over at midnight, day %d" % cal.day())
	atm.hour = 12.0
	await t._frames(3)
	t.check(cal.day() == 1, "noon is the same day")
	t.check(cal.weekday_name() == "Saturday", "the day after the start is a Saturday, got %s" % cal.weekday_name())


func test_calendar_save_and_open_season(t) -> void:
	var c = Calendar.new()
	c.set_day(37)
	var saved: Dictionary = c.to_save()
	t.check(saved == {"day": 37}, "the save is the day count, got %s" % [saved])
	# Through JSON the count comes back as a float.
	var back = JSON.parse_string(JSON.stringify(saved))
	var d = Calendar.new()
	d.load_save(back)
	t.check(d.day() == 37 and d.weekday() == c.weekday() and d.season() == c.season(),
			"save and load round trip, got day %d" % d.day())
	d.load_save({})
	t.check(d.day() == 0, "an empty save is day 0")
	d.load_save({"day": -9})
	t.check(d.day() == 0, "a negative day is clamped")
	d.load_save({"day": "soon"})
	t.check(d.day() == 0, "a damaged day is day 0")
	d.load_save("garbage")
	t.check(d.day() == 0, "a save that is not a dictionary is day 0")
	d.load_save({"day": 12.0})
	d.tick(23.0)
	d.tick(1.0)
	t.check(d.day() == 13, "the clock carries on after a load, day %d" % d.day())
	# Hunting seasons: deer in autumn only, small game all year, lions never.
	c.set_day(0)
	t.check(c.season() == "autumn" and c.is_open_season("deer"), "deer are open in autumn")
	c.set_day(19)
	t.check(c.season() == "winter" and not c.is_open_season("deer"), "deer are closed in winter")
	c.set_day(47)
	t.check(c.season() == "spring" and not c.is_open_season("deer"), "deer are closed in spring")
	for day in [0, 19, 47, 75]:
		c.set_day(day)
		t.check(c.is_open_season("rabbit") and c.is_open_season("coyote"),
				"rabbit and coyote are open all year (day %d)" % day)
		t.check(not c.is_open_season("mountain_lion") and not c.is_open_season("Mountain Lion"),
				"the mountain lion is never open (day %d)" % day)
		t.check(not c.is_open_season("dragon"), "an unknown kind is closed (day %d)" % day)
	c.free()
	d.free()


func test_calendar_schedule(t) -> void:
	var rave: Dictionary = Events.spec_of("rave_copperback")
	var east: Dictionary = Events.spec_of("rave_east")
	var fair: Dictionary = Events.spec_of("hollin_fair")
	var rodeo: Dictionary = Events.spec_of("hollin_rodeo")
	var market: Dictionary = Events.spec_of("brackett_market")
	var cult: Dictionary = Events.spec_of("cult_gathering")
	var trap: Dictionary = Events.spec_of("speed_trap")
	t.check(not rave.is_empty() and not east.is_empty() and not fair.is_empty() and not rodeo.is_empty()
			and not market.is_empty() and not cult.is_empty() and not trap.is_empty(), "every event is in the schedule")
	var ids := {}
	for s in Events.SPECS:
		ids[s.id] = true
	t.check(ids.size() == Events.SPECS.size(), "event ids are unique")
	# Day 0 is a Friday: the Copperback rave runs 22:00 to 04:00 across midnight.
	t.check(Events.is_active(rave, 0, 23.0) and Events.is_active(rave, 0, 22.0), "Friday 23:00 has a rave at Copperback")
	t.check(Events.is_active(rave, 1, 3.5), "it is still on at 03:30 on Saturday morning")
	t.check(not Events.is_active(rave, 1, 4.0) and not Events.is_active(rave, 1, 12.0), "it is over by 04:00 and not on at noon")
	t.check(not Events.is_active(rave, 0, 3.0), "Thursday night has none (the morning of a Friday carries nothing)")
	t.check(not Events.is_active(rave, 1, 23.0) and Events.is_active(east, 1, 23.0),
			"Saturday night's rave is the east ridge one")
	t.check(not Events.is_active(rave, 0, 21.9), "no rave before 22:00")
	# Saturday fair.
	t.check(Events.is_active(fair, 1, 12.0) and not Events.is_active(fair, 1, 9.0) and not Events.is_active(fair, 1, 18.0),
			"the fair runs 10 to 18 on a Saturday")
	t.check(not Events.is_active(fair, 0, 12.0) and not Events.is_active(fair, 2, 12.0), "no fair on Friday or Sunday")
	# Sunday market.
	t.check(Events.is_active(market, 2, 9.0) and not Events.is_active(market, 2, 14.0) and not Events.is_active(market, 1, 9.0),
			"the market runs on Sunday morning only")
	# Speed trap.
	t.check(Events.is_active(trap, 0, 18.0) and not Events.is_active(trap, 0, 12.0) and not Events.is_active(trap, 1, 18.0),
			"the speed trap is a Friday evening")
	# Rodeo: a Saturday, and only in the last week of each 28-day season.
	var rodeo_days := []
	for d in 224:
		if Events.runs_on(rodeo, d):
			rodeo_days.append(d)
	var all_saturdays := true
	var all_late := true
	for d in rodeo_days:
		all_saturdays = all_saturdays and Calendar.weekday_of(d) == 5
		all_late = all_late and Calendar.day_of_season_of(d) >= 21
	t.check(rodeo_days.size() == 8 and all_saturdays and all_late,
			"the rodeo is one Saturday a season (8 in 2 years), got %s" % [rodeo_days])
	t.check(Events.is_active(rodeo, rodeo_days[0], 21.0) and not Events.is_active(rodeo, rodeo_days[0], 12.0)
			and not Events.is_active(rodeo, rodeo_days[0], 23.7), "the rodeo is an evening, 19:00 to 23:30")
	# Cult: full-moon nights only, every eighth day.
	var moon_days := []
	for d in 48:
		if Events.runs_on(cult, d):
			moon_days.append(d)
	t.check(moon_days == [2, 10, 18, 26, 34, 42], "the cult meets every eighth night, got %s" % [moon_days])
	t.check(Events.is_active(cult, 2, 22.0) and Events.is_active(cult, 3, 1.0) and not Events.is_active(cult, 3, 3.0)
			and not Events.is_active(cult, 3, 22.0) and not Events.is_active(cult, 2, 12.0),
			"a gathering runs 21:00 to 02:00 on the full-moon night")
	# What is on at a given moment.
	var now := []
	for s in Events.active_specs(0, 23.0):
		now.append(s.id)
	t.check(now == ["rave_copperback"], "Friday 23:00 has only the Copperback rave, got %s" % [now])
	now.clear()
	for s in Events.active_specs(2, 22.0):
		now.append(s.id)
	t.check(now == ["cult_gathering"], "Sunday 22:00 (a full moon) has only the gathering, got %s" % [now])
	t.check(Events.active_specs(3, 12.0).is_empty(), "Monday noon has nothing on")
	# Text helpers.
	t.check(Events.hour_text(10.0) == "10am" and Events.hour_text(18.0) == "6pm" and Events.hour_text(23.5) == "11:30pm"
			and Events.hour_text(0.0) == "12am" and Events.hour_text(12.0) == "12pm", "hour_text reads 12-hour times")
	t.check(Events.time_text(fair) == "10am-6pm", "time_text, got %s" % Events.time_text(fair))
	t.check(Events.ritual_cue(1.0) == "" and Events.ritual_cue(6.0) == "hands_up" and Events.ritual_cue(9.0) == "kneel"
			and Events.ritual_cue(16.0 + 6.0) == "hands_up", "the chant cycles every 16 s")


func test_calendar_places_and_pads(t) -> void:
	await t._new_game(false)
	var rig := _rig(t)
	var ev = rig[1]
	var game = t.game
	for spec in Events.SPECS:
		var c: Vector3 = ev.center(spec)
		t.check(is_finite(c.x) and is_finite(c.z), "%s has a place on the map" % spec.id)
		if spec.has("place"):
			var lm: Dictionary = game.city.country.landmark(spec.place)
			t.check(not lm.is_empty() and lm.pos.is_equal_approx(c), "%s is on the lot %s" % [spec.id, spec.place])
	# The crowds stand on the lot pads: the ground should be close to flat
	# across the radius they use, so nobody stands in the air or in the hill.
	var worst := 0.0
	for id in ["hollin_fairground", "rave_copperback", "rave_east", "stone_ring"]:
		var lm: Dictionary = game.city.country.landmark(id)
		var s := _spread(lm.pos, 22.0)
		worst = maxf(worst, s)
		print("  pad %s ground spread over 22 m: %.2f m" % [id, s])
	t.check(worst < 6.0, "the event pads are roughly level (worst spread %.2f m)" % worst)


func test_calendar_rave_comes_and_goes(t) -> void:
	await t._new_game(false)
	var rig := _rig(t)
	var cal = rig[0]
	var ev = rig[1]
	var game = t.game
	t.check(Events.lights_used == 0, "no event light is held at the start, got %d" % Events.lights_used)
	var id := "rave_copperback"
	var c: Vector3 = ev.center(Events.spec_of(id))
	_setup(t, cal, c, 0, 23.0)
	ev.leave_time = 0.5
	ev.poll()
	t.check(ev.is_built(id), "the rave starts on Friday 23:00 with the player near")
	t.check(ev.last_notice == "A rave tonight at Copperback", "the banner names it, got '%s'" % ev.last_notice)
	t.check(not ev.is_built("rave_east") and not ev.is_built("hollin_fair") and not ev.is_built("cult_gathering"),
			"nothing else is built")
	await t._within(func(): return _built(ev, id, 8), BUILD_WAIT)
	var people: Array = ev.goers(id)
	t.check(ev.has_dressing(id), "the rave's dressing is in the world")
	t.check(people.size() >= 8 and people.size() <= 16, "8 to 16 people come, got %d" % people.size())
	var dancers := 0
	var far_off := 0.0
	for g in people:
		if g.mode == "dance":
			dancers += 1
		far_off = maxf(far_off, Vector2(g.global_position.x - c.x, g.global_position.z - c.z).length())
	t.check(dancers >= 5, "most of them dance, got %d" % dancers)
	t.check(far_off < 45.0, "they stay at the clearing, furthest %.1f m" % far_off)
	t.check(ev.light_count(id) <= ev.light_cap() and Events.lights_used == ev.light_count(id),
			"real lights respect the cap (%d of %d, counted %d)" % [ev.light_count(id), ev.light_cap(), Events.lights_used])
	# Through midnight it is the same rave: Saturday 00:10 still counts as Friday night.
	game.atmosphere.hour = 23.9
	await t._frames(3)
	game.atmosphere.hour = 0.2
	await t._frames(3)
	ev.poll()
	t.check(cal.day() == 1 and ev.is_up(id), "the rave carries through midnight (day %d)" % cal.day())
	# At noon it is over: the people leave and the dressing comes down.
	game.atmosphere.hour = 12.0
	ev.poll()
	t.check(not ev.is_up(id), "at noon the rave is no longer up")
	await t._within(func(): return not ev.is_built(id), 10.0)
	t.check(not ev.is_built(id), "the rave is taken down once the people have left")
	t.check(Events.lights_used == 0, "its lights are given back, got %d" % Events.lights_used)
	await t._frames(3)
	t.check(game.get_tree().get_nodes_in_group("goers").is_empty(), "no one from it is left in the world")

	# Back on a Friday night, then the player drives off: it is freed at once.
	_setup(t, cal, c, 7, 23.0)
	ev.poll()
	await t._within(func(): return _built(ev, id, 4), BUILD_WAIT)
	t.check(ev.is_built(id), "it is back the next Friday")
	t._place_player_at(Vector3(c.x, 300.0, c.z + 900.0))
	ev.poll()
	t.check(not ev.is_built(id) and Events.lights_used == 0, "with the player far it is freed")
	await t._frames(3)
	t.check(game.get_tree().get_nodes_in_group("goers").is_empty(), "and its people are gone")


func test_calendar_fair_and_market(t) -> void:
	await t._new_game(false)
	var rig := _rig(t)
	var cal = rig[0]
	var ev = rig[1]
	var id := "hollin_fair"
	var c: Vector3 = ev.center(Events.spec_of(id))
	# Saturday (day 1) at noon; it is day 10 of autumn, not the rodeo week.
	_setup(t, cal, c, 1, 12.0)
	ev.poll()
	t.check(ev.is_built(id) and not ev.is_built("hollin_rodeo"), "the fair is on at noon on Saturday, not the rodeo")
	t.check(ev.last_notice == "The Saturday fair is on at Hollin", "the banner names it, got '%s'" % ev.last_notice)
	await t._within(func(): return _built(ev, id, 8), BUILD_WAIT)
	var people: Array = ev.goers(id)
	t.check(ev.has_dressing(id), "the fair is dressed")
	t.check(people.size() >= 8 and people.size() <= 16, "8 to 16 people, got %d" % people.size())
	var list: Array = ev.today_list()
	var found := false
	for e in list:
		if e.id == id and e.active:
			found = true
	t.check(found, "the fair is in today's list")
	# By night the fair is long over.
	game_hour(t, 19.0)
	ev.leave_time = 0.2
	ev.poll()
	t.check(not ev.is_up(id), "at 7pm the fair is no longer up")
	await t._within(func(): return not ev.is_built(id), 10.0)
	t.check(not ev.is_built(id), "the fair is taken down")
	# The rodeo week: day 22 is a Saturday in the last week of winter... find one.
	var rd := 0
	for d in 120:
		if Events.runs_on(Events.spec_of("hollin_rodeo"), d):
			rd = d
			break
	_setup(t, cal, c, rd, 21.0)
	ev.poll()
	t.check(ev.is_built("hollin_rodeo") and not ev.is_built(id), "rodeo night at 9pm in the last week of a season")
	await t._within(func(): return _built(ev, "hollin_rodeo", 8), BUILD_WAIT)
	t.check(ev.goers("hollin_rodeo").size() >= 8, "the rodeo has a crowd, got %d" % ev.goers("hollin_rodeo").size())
	# Sunday market in Brackett.
	var mid := "brackett_market"
	var mc: Vector3 = ev.center(Events.spec_of(mid))
	_setup(t, cal, mc, 2, 10.0)
	ev.poll()
	t.check(ev.is_built(mid) and not ev.is_built("hollin_rodeo"), "the Sunday market is on in Brackett, the rodeo freed")
	await t._within(func(): return _built(ev, mid, 8), BUILD_WAIT)
	t.check(ev.has_dressing(mid) and ev.goers(mid).size() >= 8, "the market has stalls and people, got %d" % ev.goers(mid).size())
	t.check(ev.last_notice == "The farmers' market is on in Brackett", "banner, got '%s'" % ev.last_notice)


func test_calendar_cult_and_trap(t) -> void:
	await t._new_game(false)
	var rig := _rig(t)
	var cal = rig[0]
	var ev = rig[1]
	var id := "cult_gathering"
	var c: Vector3 = ev.center(Events.spec_of(id))
	_setup(t, cal, c, 2, 22.0)
	ev.poll()
	t.check(ev.is_built(id), "the stone ring gathering is on at 10pm on a full-moon night")
	await t._within(func(): return _built(ev, id, 8), BUILD_WAIT)
	var people: Array = ev.goers(id)
	t.check(people.size() >= 8 and people.size() <= 16, "8 to 16 robed figures, got %d" % people.size())
	var ring := 0
	for g in people:
		if g.mode == "circle":
			ring += 1
	t.check(ring >= 8, "most of them stand in the circle, got %d" % ring)
	# A night without a full moon: nothing, even at the stones.
	ev.leave_time = 0.2
	_setup(t, cal, c, 4, 22.0)
	ev.poll()
	t.check(not ev.is_up(id), "no gathering without a full moon")
	await t._within(func(): return not ev.is_built(id), 10.0)
	# The Friday-evening speed trap on Route 9.
	var tid := "speed_trap"
	var tc: Vector3 = ev.center(Events.spec_of(tid))
	_setup(t, cal, tc, 0, 18.5)
	ev.poll()
	t.check(ev.is_built(tid), "the speed trap is out on Friday evening")
	await t._frames(5)
	t.check(ev.extras(tid).size() >= 1, "with a patrol car parked by the road, got %d" % ev.extras(tid).size())
	if ev.extras(tid).size() >= 1:
		var car = ev.extras(tid)[0]
		t.check(is_instance_valid(car) and car.is_inside_tree() and car.is_police, "it is a police car, in the world")
	_setup(t, cal, tc, 0, 23.0)
	ev.leave_time = 0.2
	ev.poll()
	await t._within(func(): return not ev.is_built(tid), 10.0)
	await t._frames(2)
	t.check(not ev.is_built(tid), "the trap is gone by 11pm")


func test_calendar_far_player_builds_nothing(t) -> void:
	await t._new_game(false)
	var rig := _rig(t)
	var cal = rig[0]
	var ev = rig[1]
	var game = t.game
	# Friday 23:00, a Saturday-noon, a Sunday morning and a full-moon night,
	# each with the player in the city: no event is built, no one is added.
	var cases := [[0, 23.0], [1, 12.0], [2, 10.0], [2, 22.0], [0, 18.0]]
	for cs in cases:
		cal.set_day(cs[0])
		game.atmosphere.hour = cs[1]
		t._place_player_at(game.city.spawn_point + Vector3(0, 2, 0))
		ev.poll()
		var built := []
		for spec in Events.SPECS:
			if ev.is_built(spec.id):
				built.append(spec.id)
		t.check(built.is_empty(), "nothing is built with the player in the city (day %d, %.0f:00), got %s" % [cs[0], cs[1], built])
	await t._frames(20)
	t.check(game.get_tree().get_nodes_in_group("goers").is_empty() and Events.lights_used == 0,
			"no one and no light was added")
	# The edge: just outside the build radius nothing is built, just inside it is.
	var id := "rave_copperback"
	var c: Vector3 = ev.center(Events.spec_of(id))
	cal.set_day(0)
	game.atmosphere.hour = 23.0
	t._place_player_at(Vector3(c.x, 300.0, c.z + Events.BUILD_R + 10.0))
	ev.poll()
	t.check(not ev.is_built(id), "just outside %.0f m it is not built" % Events.BUILD_R)
	t.check(ev.last_notice == "A rave tonight at Copperback", "but the player is told about it inside %.0f m" % Events.NOTICE_R)
	t._place_player_at(Vector3(c.x, 300.0, c.z + Events.BUILD_R - 10.0))
	ev.poll()
	t.check(ev.is_built(id), "just inside it is")
	# It stays built across the gap up to the free radius, then goes.
	t._place_player_at(Vector3(c.x, 300.0, c.z + Events.BUILD_R + 20.0))
	ev.poll()
	t.check(ev.is_built(id), "it holds between the build and free radii (no flicker)")
	t._place_player_at(Vector3(c.x, 300.0, c.z + Events.FREE_R + 20.0))
	ev.poll()
	t.check(not ev.is_built(id), "beyond %.0f m it is freed" % Events.FREE_R)
	# Disabled, it builds nothing.
	ev.enabled = false
	t._place_player_at(Vector3(c.x, 300.0, c.z + 30.0))
	ev.poll()
	t.check(not ev.is_built(id), "a disabled events node builds nothing")


func test_calendar_lights_and_phone_list(t) -> void:
	await t._new_game(false)
	var rig := _rig(t)
	var cal = rig[0]
	var ev = rig[1]
	var game = t.game
	game.graphics.lamps = 4
	t.check(ev.light_cap() == 2, "High allows 2 event lights, got %d" % ev.light_cap())
	game.graphics.lamps = 2
	t.check(ev.light_cap() == 1, "Medium allows 1, got %d" % ev.light_cap())
	game.graphics.lamps = 0
	t.check(ev.light_cap() == 0, "Low allows none, got %d" % ev.light_cap())
	game.graphics.lamps = 4
	game.settings["real_lights"] = false
	t.check(ev.light_cap() == 0, "real lights off allows none, got %d" % ev.light_cap())
	game.settings["real_lights"] = true
	# On Low the rave is built with no real light at all.
	game.graphics.lamps = 0
	var id := "rave_copperback"
	var c: Vector3 = ev.center(Events.spec_of(id))
	_setup(t, cal, c, 0, 23.0)
	ev.poll()
	await t._within(func(): return _built(ev, id, 4), BUILD_WAIT)
	t.check(ev.is_built(id) and ev.light_count(id) == 0 and Events.lights_used == 0, "no real lights on Low, got %d" % ev.light_count(id))
	# Today's events for the phone: Friday 20:00, the trap and the rave.
	cal.set_day(0)
	game.atmosphere.hour = 20.0
	var list: Array = ev.today_list()
	var ids := []
	for e in list:
		ids.append(e.id)
	t.check(ids == ["speed_trap", "rave_copperback"], "Friday 8pm lists the trap, then the rave, got %s" % [ids])
	var ok := true
	for e in list:
		ok = ok and e.has("pos") and e.has("text") and e.pos is Vector3 and is_finite(e.pos.x) and str(e.text) != ""
	t.check(ok, "each entry has a position and text")
	t.check(list.size() == 2 and list[0].active and not list[1].active, "the trap is on now, the rave later")
	# Past midnight the Friday rave still shows; the next day's list has the east ridge one.
	cal.set_day(1)
	game.atmosphere.hour = 2.0
	ids.clear()
	for e in ev.today_list():
		ids.append(e.id)
	t.check("rave_copperback" in ids, "at 2am on Saturday the Friday night rave is still listed, got %s" % [ids])
	game.atmosphere.hour = 9.0
	ids.clear()
	for e in ev.today_list():
		ids.append(e.id)
	t.check(ids == ["hollin_fair", "rave_east"], "Saturday 9am lists the fair and the east ridge rave, got %s" % [ids])


## Sets the clock (a helper so a test reads straight).
func game_hour(t, h: float) -> void:
	t.game.atmosphere.hour = h
