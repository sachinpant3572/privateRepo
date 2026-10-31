extends RefCounted
## Wildlife tests (scripts/wildlife.gd, scripts/kits/animal_kit.gd), run by
## test_runner.gd as a TEST_MODULES module: `t` is the runner.

const Wildlife = preload("res://scripts/wildlife.gd")
const AnimalKit = preload("res://scripts/kits/animal_kit.gd")
const Terrain = preload("res://scripts/terrain.gd")
const Vehicle = preload("res://scripts/vehicle.gd")
const Graphics = preload("res://scripts/graphics.gd")

const TESTS := [
	"test_wildlife_kit_builds_five_light_models",
	"test_wildlife_lives_on_hill_ground_never_in_the_city",
	"test_wildlife_keeps_to_its_hours",
	"test_wildlife_herds_flee_a_walking_player",
	"test_wildlife_car_kills_a_deer",
	"test_wildlife_fx_bangs_scare_animals",
	"test_wildlife_kill_leaves_a_carcass_to_take",
	"test_wildlife_night_lion_hurts_a_player_who_stays",
	"test_wildlife_stays_out_of_lakes",
	"test_wildlife_despawns_past_range_and_halves_on_low",
]

## The hill spot the tests share (found once; ground does not change between
## games).
var _spot := Vector2.INF


## A fresh game on the hills' clock: clear, still, `hour`. Returns the
## Wildlife node (the atmosphere's, or one attached here until the game wires
## it in).
func _begin(t, hour: float):
	await t._new_game(false)
	var atm = t.game.atmosphere
	atm.minutes_per_second = 0.0
	atm.weather_changes = false
	atm.set_weather("clear", true)
	atm.hour = hour
	var w = atm.get("wildlife")
	if w == null:
		w = Wildlife.attach(atm)
	return w


## Open hill ground: inside the habitat, off roads, lots, streams and lakes,
## and the same all round for `room` metres.
func _find_spot(w, room: float) -> Vector2:
	if _spot != Vector2.INF:
		return _spot
	for z in range(-1360, -780, 20):
		for x in range(520, 1400, 20):
			var p := Vector2(x, z)
			if not Terrain.bounds.grow(-200.0).has_point(p) or Terrain.height(p.x, p.y) < 14.0 or Terrain.normal(p.x, p.y).y < 0.96 or not w.habitat_at(p) or not w._clear(p, 14.0):
				continue
			var ok := true
			for i in 16:
				for r: float in [room, room * 0.5]:
					var q := p + Vector2.from_angle(i * TAU / 16.0) * r
					if not w.habitat_at(q) or not w._clear(q, 6.0) or Terrain.normal(q.x, q.y).y < 0.9:
						ok = false
				if not ok:
					break
			if ok:
				_spot = p
				return p
	return Vector2.INF


## Puts the player on foot at ground level at `p` and streams the tiles in.
func _stand(t, p: Vector2) -> Vector3:
	var at := Vector3(p.x, Terrain.height(p.x, p.y) - Terrain.drop(p.x, p.y), p.y)
	t.game.city.stream_now(at)
	t._place_player_at(at + Vector3(0.0, 0.1, 0.0))
	await t._frames(2)
	return at


## A real Vehicle at `at`, facing north (-z), its own physics off.
func _rig(t, at: Vector3):
	var car = Vehicle.new()
	car.kind = "sedan"
	car.city = t.game.city
	t.game.add_child(car)
	car.set_physics_process(false)
	car.global_position = at
	car.rotation.y = 0.0
	return car


## One physics frame of `car` moving straight ahead at `speed` over the ground.
func _roll(car, speed: float) -> void:
	car.speed = speed
	car.velocity = -car.global_basis.z * speed
	var p: Vector3 = car.global_position + car.velocity / 60.0
	p.y = Terrain.height(p.x, p.z) - Terrain.drop(p.x, p.z)
	car.global_position = p


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _lakes_hit(w, animals: Array) -> int:
	var country = w._cache_for
	var n := 0
	for a in animals:
		if not country.lake_at(Vector2(a.position.x, a.position.z)).is_empty():
			n += 1
	return n


# --- Tests ------------------------------------------------------------------------

func test_wildlife_kit_builds_five_light_models(t) -> void:
	var worst := 0
	var seen := {}
	for model in AnimalKit.MODELS:
		var tris := AnimalKit.triangle_count(model)
		worst = maxi(worst, tris)
		var spec: Dictionary = AnimalKit.spec(model)
		var mesh: ArrayMesh = AnimalKit.mesh(model)
		var box := mesh.get_aabb()
		seen[model] = box.size
		# A model is about its spec's size, standing on y 0, its feet below its body.
		t.check(tris > 150 and tris < 900, "%s is a light model (%d triangles)" % [model, tris])
		var scale: float = spec.scale
		t.check(box.position.y > -0.05 and box.size.y < float(spec.height) * 2.2 and box.size.z * scale > 0.35 and box.size.z * scale < 2.8, "%s stands on the ground and is %.2f m long, %.2f m tall drawn" % [model, box.size.z * scale, box.size.y * scale])
		t.check(AnimalKit.material(model) is ShaderMaterial, "%s has its gait shader" % model)
	t.check(seen.buck.y > seen.doe.y + 0.1, "the buck is taller than the doe (antlers)")
	t.check(seen.lion.z > seen.coyote.z and seen.coyote.z > seen.rabbit.z, "a lion is longer than a coyote, a coyote than a rabbit")
	t.check(worst * Wildlife.MAX_ALIVE < 14000, "16 animals stay inside the budget (worst model %d triangles, %d for all)" % [worst, worst * Wildlife.MAX_ALIVE])


func test_wildlife_lives_on_hill_ground_never_in_the_city(t) -> void:
	var w = await _begin(t, 10.0)
	var spot := _find_spot(w, 45.0)
	t.check(spot != Vector2.INF, "there is open hill ground to test on (%s)" % [spot])
	t.check(not w.habitat_at(Vector2(300, 250)) and not w.habitat_at(Vector2(-900, -1100)), "the city and the farmland are not habitat")
	if spot == Vector2.INF:
		return
	var at = await _stand(t, spot)
	var seen := 0
	var strays := []
	var low := 99.0
	var far := 0.0
	var in_city := 0
	var city = t.game.city
	for round in 4:
		w.refresh()
		await t._frames(3)
		for a in w.animals:
			seen += 1
			var p := Vector2(a.position.x, a.position.z)
			if not w.habitat_at(p):
				strays.append("%s at %s" % [a.kind, p.round()])
			low = minf(low, Terrain.height(p.x, p.y))
			far = maxf(far, _flat(a.position, at))
			if city.plan.in_city(p):
				in_city += 1
			var ground := Terrain.height(p.x, p.y) - Terrain.drop(p.x, p.y)
			if absf(a.position.y - ground) > 0.6:
				strays.append("%s floats %.1f m off the ground" % [a.kind, a.position.y - ground])
	t.check(seen >= 4, "the hills fill with animals around the player (%d seen over 4 fills)" % seen)
	t.check(strays.is_empty() and in_city == 0, "every animal starts in the hill habitat, on the ground, none in the city %s" % [strays.slice(0, 3)])
	t.check(low >= Wildlife.MIN_HEIGHT - 0.01 and far <= Wildlife.RADIUS + 15.0, "all on hill ground (lowest %.1f m) within %.0f m of the player" % [low, far])
	t.check(w.alive_count() <= w.max_alive(), "no more than %d alive (%d)" % [w.max_alive(), w.alive_count()])
	# In the city nothing is placed at all.
	var town := Vector2(300.0, 250.0)
	await _stand(t, town)
	w.refresh()
	await t._frames(3)
	t.check(w.animals.is_empty(), "no animals are placed in the city (%d)" % w.animals.size())


func test_wildlife_keeps_to_its_hours(t) -> void:
	var w = await _begin(t, 12.0)
	var spot := _find_spot(w, 45.0)
	if spot == Vector2.INF:
		t.check(false, "there is open hill ground to test on")
		return
	await _stand(t, spot)
	t.check(Wildlife.is_active("deer", 12.0) and not Wildlife.is_active("deer", 1.0) and Wildlife.is_active("coyote", 23.0) and not Wildlife.is_active("coyote", 12.0), "deer are a day animal, coyotes a night one")
	t.check(Wildlife.is_active("lion", 22.0) and not Wildlife.is_active("lion", 12.0) and Wildlife.is_active("rabbit", 12.0) and not Wildlife.is_active("rabbit", 23.0), "lions come out at night, rabbits by day")
	var day := {}
	for round in 6:
		w.refresh()
		for a in w.animals:
			day[a.kind] = day.get(a.kind, 0) + 1
	t.check(day.has("deer") or day.has("rabbit"), "by day the hills hold deer or rabbits %s" % [day])
	t.check(not day.has("coyote") and not day.has("lion"), "by day there are no coyotes or lions %s" % [day])
	t.game.atmosphere.hour = 23.5
	var night := {}
	for round in 6:
		w.refresh()
		for a in w.animals:
			night[a.kind] = night.get(a.kind, 0) + 1
	t.check(night.has("coyote") or night.has("lion"), "at night the hills hold coyotes or a lion %s" % [night])
	t.check(not night.has("deer") and not night.has("rabbit"), "at night the deer and rabbits are bedded down %s" % [night])


func test_wildlife_herds_flee_a_walking_player(t) -> void:
	var w = await _begin(t, 10.0)
	var spot := _find_spot(w, 45.0)
	if spot == Vector2.INF:
		t.check(false, "there is open hill ground to test on")
		return
	var at = await _stand(t, spot)
	w.refresh()
	for a in w.animals.duplicate():
		w._remove(w.animals.find(a))
	var herd: Array = w.spawn("deer", at + Vector3(0.0, 0.0, -40.0), 4)
	var hare: Array = w.spawn("rabbit", at + Vector3(40.0, 0.0, 0.0), 1)
	t.check(herd.size() == 4 and hare.size() == 1, "a herd of four deer and a rabbit are placed (%d, %d)" % [herd.size(), hare.size()])
	# Standing 40 m off, nothing stirs.
	await t._frames(60)
	var calm := 0
	for a in herd + hare:
		if a.state != "flee" and a.state != "alert":
			calm += 1
	t.check(calm == 5, "animals 40 m off do not mind a person (%d of 5 calm)" % calm)
	# The player walks toward the herd until it is inside 12 m.
	var before: Array = []
	for a in herd:
		before.append(a.position)
	var player = t.game.player
	var step := Vector3(0.0, 0.0, -1.0)
	for i in 400:
		var p: Vector3 = player.global_position
		player.global_position = Vector3(p.x, Terrain.height(p.x, p.z - 0.07) - Terrain.drop(p.x, p.z - 0.07), p.z - 0.07)
		player.velocity = step * 4.0
		await t._frames(1)
		var close := false
		for a in herd:
			if _flat(a.position, player.global_position) < 12.0:
				close = true
		if close:
			break
	await t._frames(30)
	var fled := 0
	for a in herd:
		if a.state == "flee" or a.state == "alert":
			fled += 1
	t.check(fled == 4, "the whole herd breaks away when a person walks within range (%d of 4)" % fled)
	await t._frames(120)
	player.velocity = Vector3.ZERO
	var gap := 0.0
	var gone := 0
	for a in herd:
		gap = maxf(gap, _flat(a.position, player.global_position))
		if _flat(a.position, player.global_position) > 30.0:
			gone += 1
	t.check(gone >= 3, "the herd runs well clear (%d of 4 beyond 30 m, the farthest %.0f m off)" % [gone, gap])
	# A rabbit holds still at 15 m and bolts at 6 m.
	var rabbit: Dictionary = hare[0]
	player.velocity = Vector3.ZERO
	var rp: Vector3 = rabbit.position
	t._place_player_at(Vector3(rp.x - 15.0, Terrain.height(rp.x - 15.0, rp.z) - Terrain.drop(rp.x - 15.0, rp.z), rp.z))
	await t._frames(45)
	var calm_at_15: bool = rabbit.state != "flee"
	rp = rabbit.position
	t._place_player_at(Vector3(rp.x - 6.0, Terrain.height(rp.x - 6.0, rp.z) - Terrain.drop(rp.x - 6.0, rp.z), rp.z))
	await t._frames(45)
	t.check(calm_at_15 and rabbit.state == "flee", "a rabbit sits tight at 15 m and bolts at 6 m (calm %s, now %s)" % [calm_at_15, rabbit.state])
	# A gunshot far off startles the herd that has settled.
	var hp: Vector3 = herd[0].position
	var near_bang := Wildlife.startle(hp + Vector3(20.0, 0.0, 0.0), 30.0)
	var far_bang := Wildlife.startle(hp + Vector3(400.0, 0.0, 0.0), 30.0)
	t.check(near_bang >= 1 and far_bang == 0, "Wildlife.startle reaches animals in range and no further (%d, %d)" % [near_bang, far_bang])


## The Fx autoload's crash and explosion send nearby animals running; a
## bang far off leaves them grazing.
func test_wildlife_fx_bangs_scare_animals(t) -> void:
	var w = await _begin(t, 12.0)
	var spot := _find_spot(w, 45.0)
	if spot == Vector2.INF:
		t.check(false, "there is open hill ground to test on")
		return
	var at = await _stand(t, spot)
	for a in w.animals.duplicate():
		w._remove(w.animals.find(a))
	for case in [["crash", 15.0, true], ["explosion", 20.0, true], ["explosion", 300.0, false]]:
		var made: Array = w.spawn("deer", at + Vector3(0.0, 0.0, -40.0), 1)
		if made.is_empty():
			t.check(false, "a deer stands 40 m off")
			return
		var deer: Dictionary = made[0]
		deer.state = "idle"
		deer.timer = 30.0
		var bang: Vector3 = deer.position + Vector3(0.0, 0.0, -float(case[1]))
		if case[0] == "crash":
			Fx.crash(bang, 1.0, false)
		else:
			Fx.explosion(bang, 1.0)
		await t._frames(2)
		var ran: bool = deer.state == "flee"
		t.check(ran == case[2], "a %s %.0f m off: the deer %s (state %s)" % [case[0], case[1], "runs" if case[2] else "stays", deer.state])
		w._remove(w.animals.find(deer))


func test_wildlife_car_kills_a_deer(t) -> void:
	var w = await _begin(t, 10.0)
	var spot := _find_spot(w, 45.0)
	if spot == Vector2.INF:
		t.check(false, "there is open hill ground to test on")
		return
	var at = await _stand(t, spot)
	w.refresh()
	for a in w.animals.duplicate():
		w._remove(w.animals.find(a))
	var herd: Array = w.spawn("deer", at + Vector3(0.0, 0.0, -30.0), 1)
	var deer: Dictionary = herd[0]
	deer.state = "graze"
	deer.timer = 999.0
	var got := []
	w.killed.connect(func(kind, pos, by): got.append([kind, pos, by]))
	# A car 60 m south of it, heading north at 28 m/s (100 km/h; yaw 0 faces
	# -z). The deer bolts ahead of it at 11 m/s and the car gains on it. The
	# car is a real Vehicle with its own physics off (the forest's trees and
	# rocks stop one on the hill), moved straight ahead here at a set speed.
	var car = _rig(t, Vector3(deer.position.x, deer.position.y, deer.position.z + 60.0))
	t.game.player.global_position = at + Vector3(40.0, 0.0, 40.0)
	var frames := 0
	while got.is_empty() and frames < 600:
		_roll(car, 28.0)
		await t._frames(1)
		frames += 1
	t.check(got.size() == 1 and got[0][0] == "deer" and got[0][2] == "car", "a car at speed kills the deer in its way, by car (%s after %d frames)" % [got, frames])
	t.check(not deer.alive and deer.state == "dead", "the deer is down (%s)" % deer.state)
	t.check(w.animals_in(deer.position, 5.0).is_empty() and w.animals_in(deer.position, 5.0, true).has(deer), "a body is not 'alive' but is still there for animals_in(.., true)")
	t.check(car.speed < 27.5, "a deer jolts the car (28.0 to %.1f m/s)" % car.speed)
	car.queue_free()
	# A parked car does not hurt anything standing by it.
	var herd2: Array = w.spawn("deer", at + Vector3(20.0, 0.0, 0.0), 1)
	var car2 = Vehicle.new()
	car2.kind = "sedan"
	car2.city = t.game.city
	t.game.add_child(car2)
	car2.global_position = herd2[0].position + Vector3(1.0, 0.0, 0.0)
	await t._frames(40)
	t.check(herd2[0].alive, "a parked car does not kill")
	car2.queue_free()
	# A slow car is not a killer either: the deer steps aside.
	var herd3: Array = w.spawn("deer", at + Vector3(-20.0, 0.0, -20.0), 1)
	var slow = _rig(t, Vector3(herd3[0].position.x, herd3[0].position.y, herd3[0].position.z + 30.0))
	for f in 300:
		_roll(slow, 2.0)
		await t._frames(1)
	t.check(herd3[0].alive and herd3[0].state != "dead", "a car crawling at 2 m/s does not kill (%s)" % herd3[0].state)
	slow.queue_free()


func test_wildlife_kill_leaves_a_carcass_to_take(t) -> void:
	var w = await _begin(t, 10.0)
	var spot := _find_spot(w, 45.0)
	if spot == Vector2.INF:
		t.check(false, "there is open hill ground to test on")
		return
	var at = await _stand(t, spot)
	w.refresh()
	for a in w.animals.duplicate():
		w._remove(w.animals.find(a))
	var herd: Array = w.spawn("deer", at + Vector3(0.0, 0.0, -50.0), 3)
	var rabbits: Array = w.spawn("rabbit", at + Vector3(0.0, 0.0, 50.0), 1)
	await t._frames(5)
	var got := []
	w.killed.connect(func(kind, pos, by): got.append([kind, by]))
	var first: Dictionary = herd[0]
	var where: Vector3 = first.position
	w.kill(first, Vector3(2.0, 0.0, 0.0), "player")
	t.check(got == [["deer", "player"]], "kill() sends killed(kind, pos, by) once %s" % [got])
	t.check(not first.alive and w.alive_count("deer") == 2, "the deer is dead and the herd is one fewer (%d alive)" % w.alive_count("deer"))
	w.kill(first, Vector3.ZERO, "player")
	t.check(got.size() == 1, "killing a body twice reports once")
	await t._frames(30)
	var fled := 0
	for a in herd:
		if a.alive and a.state == "flee":
			fled += 1
	t.check(fled == 2, "the rest of the herd bolts at the shot (%d of 2)" % fled)
	var c: Dictionary = w.carcass_near(first.position, 4.0)
	t.check(not c.is_empty() and c.kind == "deer", "carcass_near finds the body")
	t.check(w.carcass_near(first.position + Vector3(60.0, 0.0, 0.0), 4.0).is_empty(), "and finds nothing 60 m off")
	t.check(w.carcass_near(rabbits[0].position, 4.0).is_empty(), "a live rabbit is not a carcass")
	var took: String = w.take_carcass(c)
	t.check(took == "deer" and w.carcass_near(first.position, 4.0).is_empty() and not w.animals.has(first), "take_carcass hands over the kind (%s) and the body is gone" % took)
	t.check(w.take_carcass(c) == "", "a body can be taken once")
	# A body left alone is gone in about a minute.
	var rabbit: Dictionary = rabbits[0]
	w.kill(rabbit, Vector3.ZERO, "other")
	t.check(w.carcass_near(rabbit.position, 3.0).kind == "rabbit", "a killed rabbit lies there")
	var waited := 0
	while w.animals.has(rabbit) and waited < 4800:
		await t._frames(300)
		waited += 300
	t.check(not w.animals.has(rabbit), "an unclaimed body is gone after about %.0f s (%.0f s)" % [Wildlife.CARCASS_TIME, waited / 60.0])
	t.check(where.distance_to(first.position) < 8.0, "the body stayed near where it fell (%.1f m)" % where.distance_to(first.position))


func test_wildlife_night_lion_hurts_a_player_who_stays(t) -> void:
	var w = await _begin(t, 23.0)
	var spot := _find_spot(w, 45.0)
	if spot == Vector2.INF:
		t.check(false, "there is open hill ground to test on")
		return
	var at = await _stand(t, spot)
	w.refresh()
	for a in w.animals.duplicate():
		w._remove(w.animals.find(a))
	var player = t.game.player
	player.health = player.max_health
	var cat: Array = w.spawn("lion", at + Vector3(0.0, 0.0, -24.0), 1)
	var lion: Dictionary = cat[0]
	lion.state = "idle"
	lion.timer = 0.5
	var warnings := []
	w.warned.connect(func(text): warnings.append(text))
	var states := {}
	var hurt_at := -1
	for f in 2400:
		await t._frames(1)
		states[lion.state] = true
		if player.health < player.max_health - 1.0:
			hurt_at = f
			break
	t.check(states.has("stalk"), "the lion stalks a person on foot at night (%s)" % [states.keys()])
	t.check(warnings.size() == 2 and String(warnings[0]).contains("stalking") and String(warnings[1]).contains("charges"),
			"the HUD warns of the stalk and the charge, got %s" % [warnings])
	t.check(hurt_at >= 0 and player.health < player.max_health, "a player who stays near is struck (health %.0f after %.1f s)" % [player.health, hurt_at / 60.0])
	await t._frames(8)
	t.check(lion.state == "retreat" and not player.dead, "after one strike the lion retreats and the player lives (%s)" % lion.state)
	await t._frames(300)
	t.check(_flat(lion.position, player.global_position) > 14.0, "the lion is leaving (%.0f m off)" % _flat(lion.position, player.global_position))
	lion.timer = 0.05
	var again := false
	for f in 120:
		await t._frames(1)
		again = again or lion.state == "stalk" or lion.state == "charge"
	t.check(lion.state == "leave" and not again, "after its strike it walks off for good (%s, stalked again %s)" % [lion.state, again])
	# A blocked retreat can leave it idle (_avoid turns it to alert, _rest to
	# idle): a spent lion still walks off rather than wandering near (L3).
	lion.state = "idle"
	lion.timer = 5.0
	await t._frames(3)
	t.check(lion.state == "leave", "a spent lion left idle walks off again (%s)" % lion.state)
	# A player who backs away is left alone, and a lion by day just wanders.
	player.health = player.max_health
	t.game.atmosphere.hour = 12.0
	w.refresh()
	var day_lion: Array = w.spawn("lion", at + Vector3(0.0, 0.0, -12.0), 1)
	t.check(not day_lion.is_empty(), "a lion stands near by day")
	if day_lion.is_empty():
		return
	var calm: Dictionary = day_lion[0]
	var stalked := false
	for f in 360:
		await t._frames(1)
		stalked = stalked or calm.state == "stalk" or calm.state == "charge"
	t.check(w.animals.has(calm) and not stalked and player.health == player.max_health,
			"a lion does not hunt by day (still here %s, stalked %s, health %.0f)" % [w.animals.has(calm), stalked, player.health])


func test_wildlife_stays_out_of_lakes(t) -> void:
	var w = await _begin(t, 10.0)
	var country = t.game.city.country
	w._ensure_caches()
	var lake: Dictionary = {}
	var shore := Vector2.INF
	var out := Vector2.ZERO
	for l in country.lakes:
		var poly: PackedVector2Array = l.poly
		if poly.size() < 8:
			continue
		var mid := Vector2.ZERO
		for q in poly:
			mid += q
		mid /= float(poly.size())
		for i in poly.size():
			var q: Vector2 = poly[i]
			var dir := (q - mid).normalized()
			var land: Vector2 = q + dir * 8.0
			if country.lake_at(land, 3.0).is_empty() and Terrain.height(land.x, land.y) > 3.0 and Terrain.normal(land.x, land.y).y > 0.85:
				lake = l
				shore = q
				out = dir
				break
		if not lake.is_empty():
			break
	t.check(not lake.is_empty(), "the hills have a lake with a walkable shore")
	if lake.is_empty():
		return
	# The player 12 m behind the herd: well inside a deer's flee radius even
	# standing still (25 m x 0.7), so the herd always runs at the lake.
	var herd_at := shore + out * 8.0
	var player_at := shore + out * 20.0
	var at = await _stand(t, player_at)
	w.refresh()
	for a in w.animals.duplicate():
		w._remove(w.animals.find(a))
	var herd: Array = w.spawn("deer", Vector3(herd_at.x, 0.0, herd_at.y), 3)
	var rabbit: Array = w.spawn("rabbit", Vector3(herd_at.x, 0.0, herd_at.y) + Vector3(out.x, 0.0, out.y) * 2.0, 1)
	var wet := 0
	var ran := 0.0
	for f in 600:
		await t._frames(1)
		if f % 6 == 0:
			wet += _lakes_hit(w, herd + rabbit)
		for a in herd:
			ran = maxf(ran, _flat(a.position, Vector3(herd_at.x, 0.0, herd_at.y)))
	t.check(ran > 6.0 and wet == 0, "deer driven toward a lake run (%.0f m) and never step into it (%d samples in the water)" % [ran, wet])
	# Fresh fills near the lake never put anything in it.
	var shore_stand := shore + out * 30.0
	await _stand(t, shore_stand)
	var placed := 0
	var swimming := 0
	for round in 6:
		w.refresh()
		placed += w.animals.size()
		swimming += _lakes_hit(w, w.animals)
	t.check(swimming == 0, "fresh herds never start in the water (%d placed, %d wet)" % [placed, swimming])


func test_wildlife_despawns_past_range_and_halves_on_low(t) -> void:
	var w = await _begin(t, 10.0)
	var spot := _find_spot(w, 45.0)
	if spot == Vector2.INF:
		t.check(false, "there is open hill ground to test on")
		return
	var at = await _stand(t, spot)
	w.refresh()
	for a in w.animals.duplicate():
		w._remove(w.animals.find(a))
	var far: Array = w.spawn("deer", at + Vector3(0.0, 0.0, -(Wildlife.DESPAWN + 40.0)), 2)
	var near: Array = w.spawn("rabbit", at + Vector3(0.0, 0.0, -60.0), 1)
	await t._frames(200)
	t.check(not w.animals.has(far[0]) and not w.animals.has(far[1]), "animals left past %.0f m are dropped" % Wildlife.DESPAWN)
	t.check(w.animals.has(near[0]), "and one 60 m off stays")
	# The cap: 16 on High, 8 on Low.
	t.check(w.max_alive() == Wildlife.MAX_ALIVE, "at most %d alive on High (%d)" % [Wildlife.MAX_ALIVE, w.max_alive()])
	Graphics.pick(t.game.settings, "low")
	t.game.apply_settings()
	t.check(w.max_alive() == Wildlife.MAX_ALIVE / 2, "Low halves it (%d)" % w.max_alive())
	var most := 0
	for round in 5:
		w.refresh()
		most = maxi(most, w.alive_count())
	t.check(most <= Wildlife.MAX_ALIVE / 2, "and fills no further than that (%d)" % most)
	# Walking away takes the animals out of the picture, indoors hides them.
	Graphics.pick(t.game.settings, "high")
	t.game.apply_settings()
	w.refresh()
	await t._frames(2)
	var shown := false
	for model in w._views:
		shown = shown or (w._views[model].visible and w._mms[model].visible_instance_count > 0)
	t.game.atmosphere.indoors = true
	await t._frames(2)
	var hidden := true
	for model in w._views:
		hidden = hidden and not w._views[model].visible
	t.game.atmosphere.indoors = false
	t.check(shown and hidden, "drawn outdoors (%s), not drawn indoors (%s)" % [shown, hidden])
	# Moving the player a long way takes the hills with him.
	await _stand(t, Vector2(300.0, 250.0))
	await t._frames(3)
	t.check(w.animals.is_empty(), "in the city the hills are left behind (%d animals)" % w.animals.size())
