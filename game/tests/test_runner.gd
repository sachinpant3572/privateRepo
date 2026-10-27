extends Node
## Headless prototype tests. Run with tests/run.sh.
## Each test builds a fresh game, drives it through Controls and checks state.

const MainScene = preload("res://main.tscn")
const Vehicle = preload("res://scripts/vehicle.gd")
const Npc = preload("res://scripts/npc.gd")

var game
var passed := 0
var failed := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var tests := [
		"test_city_streams_cells",
		"test_city_follows_world_map",
		"test_street_plan_is_not_a_grid",
		"test_wanted_level_decays_out_of_sight",
		"test_player_walks",
		"test_punching_civilian_gives_one_star",
		"test_enter_drive_and_exit_car",
		"test_carjacking_ejects_driver",
		"test_hitting_cop_brings_police_cars",
		"test_busted_when_cop_holds_player",
		"test_wasted_respawns_at_hospital",
		"test_city_runs_with_population",
		"test_camera_is_classic_top_down",
		"test_punch_combo_ends_in_knockdown_kick",
		"test_minimap_routes_to_waypoint",
		"test_night_lights_the_city",
		"test_homecoming_runs_start_to_finish",
		"test_failed_mission_can_be_retried",
		"test_empty_rooms_phone_and_clues",
		"test_lantern_lights_ambush",
	]
	for name in tests:
		var before := failed
		await call(name)
		print("%s %s" % ["PASS" if failed == before else "FAIL", name])
	await _free_game()
	print("\n%d checks passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)


# --- Tests -------------------------------------------------------------------

func test_city_streams_cells() -> void:
	await _new_game(false)
	var city = game.city
	var cells: Array = city.loaded_cells()
	_check(cells.size() >= 10, "cells around the spawn are built, got %d" % cells.size())
	var single := cells.all(func(c): return city.cell_node(c).get_children().filter(func(n): return n is MeshInstance3D and n.name != "Glow").size() <= 1)
	_check(single, "every cell draws as at most one mesh (plus its night glow)")
	_check(city.building_count > 20, "city has buildings, got %d" % city.building_count)
	var land := 0
	for f in city.plan.faces.size():
		land += 1 if city.block_land(f) and city.in_window(f) else 0
	_check(city.sidewalk_loops.size() == land, "one sidewalk loop per playable land block")
	# Teleport across the map: the old cells go, new ones stream in.
	_place_player_at(city.hospital)
	await _frames(240)
	_check(city.cell_node(city.cell_at(city.hospital)) != null, "cells stream in around the player")
	_check(city.cell_node(city.cell_at(city.spawn_point)) == null, "far cells are unloaded")


func test_city_follows_world_map() -> void:
	await _new_game(false)
	var city = game.city
	var plan = city.plan
	var styles := {}
	for f in plan.faces.size():
		if city.in_window(f):
			styles[city.block_style(f)] = true
	for style in ["quarter", "docks", "wards", "downtown"]:
		_check(styles.has(style), "map district style '%s' is used" % style)
	for landmark in ["police", "hospital", "park", "green", "court", "station", "tower", "club", "safehouse"]:
		_check(styles.has(landmark), "map landmark '%s' is placed" % landmark)
	_check(city.landmark_at(city.block_of(city.spawn_point - city.landmark_frame("union_station").basis.z * 6.0)).get("id") == "union_station", "player starts at Union Station")
	_check(city.district_at(city.spawn_point).name == "Gilt District", "Union Station is in the Gilt District")
	_check(city.police_station.distance_to(city.spawn_point) > 100.0, "police station comes from the map, not the fallback")
	_check(city.district_at(city.hospital).name == "Floodline Wards", "clinic is in the Floodline Wards")
	_check(city.district_at(city.node_pos(_road_node(plan, "point_ave"))).name == "Morrow Point", "Point Avenue runs through Morrow Point")
	# Only the bridge crosses the river.
	var wet := []
	for e in plan.edge_count():
		var m: Vector2 = (plan.pos(plan.edge_a[e]) + plan.pos(plan.edge_b[e])) * 0.5
		if plan.is_water_point(m) and plan.drivable(e):
			wet.append(plan.edge_class(e))
	_check(not wet.is_empty() and wet.all(func(c): return c == "bridge"), "only Morrow Bridge crosses the river, got %s" % [wet])


## The map should read as a city that grew, not a grid: districts at their
## own angles, curved and diagonal roads, T-junctions, blocks of many
## shapes and sizes. Each check would fail on a (warped) grid.
func test_street_plan_is_not_a_grid() -> void:
	await _new_game(false)
	var city = game.city
	var plan = city.plan
	var counts := {}
	var bearing := PackedFloat32Array()
	bearing.resize(9) # street length by bearing (mod 90 degrees), 10-degree bins
	var total := 0.0
	var square := 0.0 # length within 10 degrees of the compass
	for e in plan.edge_count():
		var a: Vector2 = plan.pos(plan.edge_a[e])
		var b: Vector2 = plan.pos(plan.edge_b[e])
		if not city.window.has_point((a + b) * 0.5):
			continue
		var cls: String = plan.edge_class(e)
		counts[cls] = counts.get(cls, 0) + 1
		if plan.drivable(e):
			var deg := fposmod(rad_to_deg((b - a).angle()), 90.0)
			bearing[mini(int(deg / 10.0), 8)] += a.distance_to(b)
			total += a.distance_to(b)
			if minf(deg, 90.0 - deg) < 10.0:
				square += a.distance_to(b)
	for cls in ["boulevard", "avenue", "river", "street", "quarter", "lane", "bridge", "quay"]:
		_check(counts.get(cls, 0) > 0, "street class '%s' is used" % cls)
	var top := 0.0
	for v in bearing:
		top = maxf(top, v)
	_check(top < total * 0.35, "streets run at many angles (top 10-degree bin %.0f%% of length)" % (top / total * 100.0))
	_check(square < total * 0.45, "most streets are off the compass (%.0f%% within 10 degrees of it)" % (square / total * 100.0))
	# Junctions: plenty of T-junctions, not all crossroads.
	var tees := 0
	var crosses := 0
	for n in plan.node_count():
		if not city.drive_node(n):
			continue
		var d: int = plan.edges_of(n).size()
		tees += 1 if d == 3 else 0
		crosses += 1 if d == 4 else 0
	_check(tees > crosses * 1.5, "T-junctions outnumber crossroads (%d T, %d crossroads)" % [tees, crosses])
	# Blocks: many are not plain rectangles (not four-cornered, a corner well
	# off square, or bent sides), and sizes vary.
	var odd := 0
	var land := 0
	var areas: Array = []
	for f in plan.faces.size():
		if not (plan.is_land(f) and city.in_window(f)):
			continue
		land += 1
		areas.append(plan.faces[f].area)
		var poly: PackedVector2Array = plan.face_poly(f)
		var corners := 0
		var skew := 0.0
		var bend := 0.0
		for k in poly.size():
			var d0 := (poly[k] - poly[k - 1]).normalized()
			var d1 := (poly[(k + 1) % poly.size()] - poly[k]).normalized()
			var turn := absf(d0.angle_to(d1))
			if turn > deg_to_rad(20.0):
				corners += 1
				skew = maxf(skew, absf(turn - PI / 2))
			else:
				bend += turn
		if corners != 4 or skew > deg_to_rad(12.0) or bend > deg_to_rad(15.0):
			odd += 1
	_check(odd > land * 0.25, "blocks come in many shapes (%d of %d not rectangles)" % [odd, land])
	areas.sort()
	_check(areas[areas.size() * 9 / 10] > areas[areas.size() / 10] * 3.0, "blocks come in different sizes")
	# Long roads: the diagonal avenue and the bridge.
	var liberty := 0.0
	for e in plan.edge_count():
		if plan.edge_road[e] == "liberty":
			liberty += plan.pos(plan.edge_a[e]).distance_to(plan.pos(plan.edge_b[e]))
	_check(liberty > 900.0, "Liberty Avenue cuts across the city (%.0f m)" % liberty)
	var park: Rect2 = plan.lot_rect(plan.park_face) if plan.park_face >= 0 else Rect2()
	_check(park.size.x > 60.0 and park.size.y > 40.0, "Liberty Green is a big park (%s)" % [park.size])
	# Every drivable junction can be reached from the spawn.
	var start: int = city.nearest_node(city.spawn_point)
	var seen := {start: true}
	var todo: Array = [start]
	while not todo.is_empty():
		var n: int = todo.pop_back()
		for m in city.next_nodes(n):
			if not seen.has(m):
				seen[m] = true
				todo.append(m)
	var stranded := 0
	for n in plan.node_count():
		if city.drive_node(n) and not seen.has(n):
			stranded += 1
	_check(stranded == 0, "no stranded junctions, got %d" % stranded)
	# Every street has a block on at least one side, except the bridge (a
	# street with none is a hole in the map, where blocks went missing).
	var orphans := 0
	for e in plan.edge_count():
		var sides: Vector2i = plan.edge_face[e]
		if sides.x < 0 and sides.y < 0 and plan.edge_class(e) != "bridge":
			orphans += 1
	_check(orphans == 0, "no holes in the map (%d streets with no block either side)" % orphans)
	# And all land in the window is in some block (a missing street can
	# leave an open area that isn't next to any street).
	var bare: Array = []
	var y := 4.0
	while y < city.window.end.y:
		var x := 4.0
		while x < city.window.end.x:
			var p := Vector2(x, y)
			if plan.face_of(p) < 0 and plan.river_distance(p) > plan._river_half + 25.0:
				bare.append(p)
			x += 10.0
		y += 10.0
	_check(bare.is_empty(), "all land in the window is in a block (%d bare points, first %s)" % [bare.size(), bare.slice(0, 3)])
	# Tidying a lot's outline drops only spare points, never a corner (a
	# lost corner leaves bare ground between the sidewalk and the lot).
	var cut_lots := 0
	for f in plan.faces.size():
		var lot: PackedVector2Array = plan.faces[f].lot
		if plan.faces[f].kind != "land" or lot.size() < 3 or not city.in_window(f):
			continue
		var full := 0.0
		for piece in Geometry2D.offset_polygon(plan.faces[f].inner, -plan.SIDEWALK, Geometry2D.JOIN_MITER):
			full = maxf(full, absf(plan.area(piece)))
		if absf(plan.area(lot)) < full - 50.0:
			cut_lots += 1
	_check(cut_lots == 0, "lots keep their corners (%d cut short)" % cut_lots)
	# A corner 0.2 m past a point in line with it once went with that point.
	var tidied: PackedVector2Array = plan._tidy(PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10.2, 0), Vector2(10.2, 10), Vector2(0, 10)]))
	_check(absf(plan.area(tidied)) > 100.0, "tidying an outline keeps a corner next to a spare point (area %.1f)" % absf(plan.area(tidied)))
	for id in ["union_station", "aurum_tower", "lantern_square", "blue_lantern", "bpd_lantern", "floodline_clinic", "wharfside_courts", "moreau_house", "teo_apartment", "warehouse_9", "the_pit", "streetcar_depot", "drowned_streetcar"]:
		var f: int = city.landmark_block(id)
		_check(f >= 0, "landmark %s is placed" % id)
		if f >= 0:
			var need: Vector2 = plan.LANDMARK_LOTS.get(id, plan.DEFAULT_LOT)
			var r: Rect2 = plan.lot_rect(f)
			_check(r.size.x >= need.x - 0.5 and r.size.y >= need.y - 0.5, "%s has room (%s, needs %s)" % [id, r.size, need])
			# Its door faces the street: the rect's middle is on the front
			# side and its top on the sidewalk.
			var inner: PackedVector2Array = plan.faces[f].inner
			var k: int = plan.front_side(f)
			var half: float = inner[k].distance_to(inner[(k + 1) % inner.size()]) * 0.5
			_check(absf(r.get_center().x) <= half and r.end.y > -plan.SIDEWALK - 1.6 and r.end.y < 0.0,
				"%s fronts its street (rect middle %.1f, side half %.1f, top %.1f)" % [id, r.get_center().x, half, r.end.y])


func _road_node(plan, road: String) -> int:
	for e in plan.edge_count():
		if plan.edge_road[e] == road:
			return plan.edge_b[e]
	return 0


func test_wanted_level_decays_out_of_sight() -> void:
	await _free_game()
	Wanted.report_crime(1)
	_check(Wanted.level == 1, "crime gives one star")
	Wanted.report_crime(2)
	_check(Wanted.level == 2, "crime against police gives two stars")
	Wanted.tick(5.0, true)
	_check(Wanted.level == 2, "stays wanted while seen")
	Wanted.tick(11.0, false)
	_check(Wanted.level == 2, "not lost before the evade time")
	Wanted.tick(1.5, false)
	_check(Wanted.level == 0, "lost after staying out of sight")


func test_player_walks() -> void:
	await _new_game(false)
	var start: Vector3 = game.player.global_position
	Controls.override_vector = Vector2(0, -1)
	await _frames(60)
	Controls.override_vector = null
	var moved: float = game.player.global_position.distance_to(start)
	_check(moved > 3.0, "player walks, moved %.1f m" % moved)


func test_punching_civilian_gives_one_star() -> void:
	await _new_game(false)
	var p = game.player
	_place_player(_home(), Vector3(7.5, 0, 7.5))
	var ped = game.population.spawn_ped_at(p.global_position + p.forward() * 1.0)
	ped.walk_speed = 0.0
	await _frames(2)
	await _press("attack")
	_check(ped.health < ped.max_health, "punch damages pedestrian")
	_check(Wanted.level == 1, "assault gives one star, got %d" % Wanted.level)
	await _frames(240)
	_check(game.police.cops.size() >= 2, "police on foot respond")


func test_enter_drive_and_exit_car() -> void:
	await _new_game(false)
	var car = _spawn_car(_home(), Vector3(0, 0, -3), 0.0)
	_place_player(_home(), Vector3.ZERO)
	await _frames(2)
	await _press("interact")
	_check(game.player.vehicle == car, "player gets in the car")
	_check(not game.player.visible, "player hidden while driving")
	var start: Vector3 = car.global_position
	# Screen up is north (world -Z): straight down the road.
	Controls.override_vector = Vector2(0, -1)
	await _frames(90)
	Controls.override_vector = null
	var moved: float = car.global_position.distance_to(start)
	_check(moved > 10.0, "car drives, moved %.1f m" % moved)
	_check(car.health > 90.0, "no crash on an empty road")
	await _frames(120)
	await _press("interact")
	_check(game.player.vehicle == null and game.player.visible, "player gets out")
	_check(Wanted.level == 0, "taking a parked car is not a crime")


func test_carjacking_ejects_driver() -> void:
	await _new_game(false)
	var node: int = game.city.next_nodes(_home())[0]
	var car = _spawn_car(node, Vector3(0, 0, -3), 0.0)
	car.start_traffic(game.city, node, _home())
	car.driver = Vehicle.Driver.TRAFFIC
	_place_player(node, Vector3.ZERO)
	var peds_before: int = game.population.peds.size()
	await _press("interact")
	_check(game.player.vehicle == car, "player takes the car")
	_check(game.population.peds.size() == peds_before + 1, "driver is thrown out")
	_check(Wanted.level == 1, "carjacking gives one star")


func test_hitting_cop_brings_police_cars() -> void:
	await _new_game(false)
	var p = game.player
	_place_player(_home(), Vector3(7.5, 0, 7.5))
	var cop = game.police.spawn_cop_at(p.global_position + p.forward() * 1.0)
	cop.active = false
	await _frames(2)
	await _press("attack")
	_check(Wanted.level == 2, "hitting a cop gives two stars, got %d" % Wanted.level)
	await _frames(60)
	var police_cars: Array = game.police.cars.filter(func(c): return c.driver == Vehicle.Driver.POLICE)
	_check(police_cars.size() == 2, "two police cars respond, got %d" % police_cars.size())


func test_busted_when_cop_holds_player() -> void:
	await _new_game(false)
	var p = game.player
	_place_player(_home(), Vector3(7.5, 0, 7.5))
	Wanted.report_crime(1)
	game.police.spawn_cop_at(p.global_position + Vector3(1.0, 0, 0))
	await _frames(150)
	_check(game.respawning, "cop arrests a player standing still")
	await _frames(200)
	_check(Wanted.level == 0, "wanted level cleared after arrest")
	_check(p.global_position.distance_to(game.city.police_station) < 2.0, "respawn at the police station")


func test_wasted_respawns_at_hospital() -> void:
	await _new_game(false)
	var p = game.player
	p.take_hit(null, 999.0, Vector3.ZERO)
	_check(p.dead, "player dies")
	await _frames(200)
	_check(not p.dead and p.health == p.max_health, "player revived")
	_check(p.global_position.distance_to(game.city.hospital) < 2.0, "respawn at the hospital")


func test_city_runs_with_population() -> void:
	await _new_game(true)
	var car = _spawn_car(_home(), Vector3(0, 0, -3), 0.0)
	_place_player(_home(), Vector3.ZERO)
	await _press("interact")
	# Weave around for a while to exercise traffic, pedestrians and collisions.
	for i in 12:
		Controls.override_vector = Vector2.from_angle(i * 1.3)
		await _frames(60)
	Controls.override_vector = null
	await _frames(120) # let the bubble refill around wherever the drive ended
	_check(game.population.peds.size() >= 10, "pedestrians spawned, got %d" % game.population.peds.size())
	_check(game.population.cars.size() >= 5, "traffic spawned, got %d" % game.population.cars.size())
	_check(is_instance_valid(car), "player car still exists")


func test_camera_is_classic_top_down() -> void:
	await _new_game(false)
	var cam = game.camera
	_place_player(_home(), Vector3.ZERO)
	_check(cam.global_basis.z.y > 0.8 and absf(cam.global_basis.z.x) < 0.01, "camera looks down at a 3/4 angle with north up")
	var start: Vector3 = game.player.global_position
	Controls.override_vector = Vector2(0, -1)
	await _frames(40)
	Controls.override_vector = null
	var moved: Vector3 = game.player.global_position - start
	_check(moved.z < -2.0 and absf(moved.x) < 0.5, "screen-up walks north, moved %s" % moved)


# --- Helpers -----------------------------------------------------------------

func test_punch_combo_ends_in_knockdown_kick() -> void:
	await _new_game(false)
	var p = game.player
	var target = Npc.new()
	target.setup("Dummy", {})
	target.position = p.global_position + p.forward() * 1.0
	target.max_health = 200.0
	game.add_child(target)
	target.health = 200.0
	await _frames(2)
	for i in 3:
		await _press("attack")
		await _frames(int(p.PUNCH_COOLDOWN * 60.0) + 2)
	_check(target.knocked_time > 0.0 or target.dead, "third hit of the combo is a kick that knocks down")
	_check(target.health <= 200.0 - p.punch_damage * 4.0 + 0.1, "the kick hits twice as hard")


func test_minimap_routes_to_waypoint() -> void:
	await _new_game(false)
	var city = game.city
	game.waypoint = city.node_pos(city.nearest_node(city.landmark_front("lantern_square")))
	await _frames(10)
	var route: PackedVector3Array = game.hud.minimap.route()
	_check(route.size() > 5, "GPS route follows the streets, got %d points" % route.size())
	_check(route[route.size() - 1].distance_to(game.waypoint) < 1.0, "route ends at the waypoint")
	game.hud.full_map.open()
	await get_tree().process_frame
	_check(get_tree().paused, "full map pauses the game")
	game.hud.full_map.close()
	_check(not get_tree().paused, "closing the map resumes")


func test_night_lights_the_city() -> void:
	await _new_game(false)
	game.atmosphere.hour = 22.0
	await _frames(5)
	_check(game.atmosphere.is_night(), "22:00 is night")
	var glows := 0
	for c in game.city.loaded_cells():
		var g = game.city.cell_node(c).get_node_or_null("Glow")
		if g and g.visible:
			glows += 1
	_check(glows > 3, "lamp pools glow at night, got %d cells" % glows)
	game.atmosphere.hour = 12.0
	await _frames(5)
	_check(not game.city.glow_visible, "lamp pools are off by day")


func test_homecoming_runs_start_to_finish() -> void:
	await _new_story_game()
	var mm = game.missions
	_check(mm.active != null and mm.active.id == "m01_homecoming", "a new game starts with Homecoming")
	await _talk_until(func(): return mm.objective_text == "Catch the thief!", 900)
	_check(mm.objective_text == "Catch the thief!", "the bag gets snatched")
	var m = mm.active
	await _talk_until(func(): return mm.objective_text == "Get on the scooter", 900)
	_check(m.kid.vehicle == m.getaway, "the thief rides off on his scooter")
	_place_player_at(m.spare.global_position + Vector3(0, 0, -1.5))
	await _press("interact")
	_check(game.player.vehicle == m.spare and game.player.riding, "Jules rides the spare scooter")
	await _talk_until(func(): return mm.objective_text == "Follow the thief", 120)
	await _frames(60)
	_check(m.getaway.speed > 3.0, "the thief drives his route")
	# Skip to the end of the chase: both scooters near the Square, back
	# along the route's last street leg so both stay in the street (the
	# very last leg is the hop from the lane to the curb).
	var stops: int = m.getaway.path.size()
	var end: Vector3 = m.getaway.path[stops - 2]
	var leg: Vector3 = (end - m.getaway.path[stops - 3]).normalized()
	m.getaway.global_position = end - leg * 12.0
	m.getaway.rotation.y = atan2(-leg.x, -leg.z)
	m.getaway.path_index = stops - 2
	m.spare.global_position = end - leg * 20.0
	m.spare.rotation.y = atan2(-leg.x, -leg.z)
	game.city.stream_now(end)
	await _talk_until(func(): return mm.objective_text == "Beat the crew", 600)
	_check(m.crew.size() == 3, "the kid and two of his crew fight")
	for n in m.crew:
		n.take_hit(game.player, 999.0, Vector3.ZERO)
	await _talk_until(func(): return mm.objective_text == "Take the crew's car", 300)
	_check(mm.objective_text == "Take the crew's car", "beating the crew moves on")
	game.player.exit_vehicle()
	game.player.enter_vehicle(m.crew_car)
	await _talk_until(func(): return mm.objective_text == "Drive home to Moreau House", 60)
	var home_curb: Vector3 = m.curb("moreau_house")
	game.city.stream_now(home_curb)
	m.crew_car.global_position = home_curb
	await _talk_until(func(): return mm.objective_text == "Go to the front door", 60)
	game.player.exit_vehicle()
	_place_player_at(m.front("moreau_house"))
	await _talk_until(func(): return mm.active == null, 900)
	_check(mm.done.has("m01_homecoming"), "Homecoming passed")
	_check(game.cash == 500, "reward paid, got $%d" % game.cash)
	_check(mm.next_mission().get("id") == "m02_empty_rooms", "Empty Rooms is next")


func test_failed_mission_can_be_retried() -> void:
	await _new_story_game()
	var mm = game.missions
	await _talk_until(func(): return mm.objective_text == "Catch the thief!", 900)
	game.player.take_hit(null, 999.0, Vector3.ZERO)
	await _talk_until(func(): return game.hud.retry_visible(), 600)
	_check(mm.active == null, "dying fails the mission")
	_check(game.hud.retry_visible(), "the retry prompt shows")
	mm.retry()
	await _frames(5)
	_check(mm.active != null and mm.active.id == "m01_homecoming", "retry restarts the mission")
	_check(game.player.global_position.distance_to(game.city.spawn_point) < 2.0, "retry puts Jules back at Union Station")


func test_empty_rooms_phone_and_clues() -> void:
	await _new_story_game()
	var mm = game.missions
	mm.abandon()
	mm.done = ["m01_homecoming"]
	mm.start("m02_empty_rooms", true)
	await _talk_until(func(): return mm.objective_text.begins_with("Check your phone"), 1200)
	_check(mm.phone_unlocked, "Nia unlocks the phone")
	game.hud.phone.open()
	await get_tree().process_frame
	game.hud.phone.close()
	await _talk_until(func(): return mm.objective_text == "Go to Teo's apartment", 900)
	_check(mm.objective_text == "Go to Teo's apartment", "after the messages, go to Teo's")
	var m = mm.active
	_place_player_at(m.curb("teo_apartment"))
	game.city.stream_now(m.curb("teo_apartment"))
	await _talk_until(func(): return mm.objective_text == "Meet Nia at the door", 120)
	_place_player_at(m.front("teo_apartment"))
	await _talk_until(func(): return mm.objective_text.begins_with("Search for clues"), 900)
	for c in m.CLUES:
		_place_player_at(m.near("teo_apartment", c[0]))
		await _frames(2)
		await _press("interact")
		await _frames(int(m.SEARCH_TIME * 60.0) + 10)
	await _talk_until(func(): return mm.objective_text == "Go to the Floodline Clinic", 1200)
	_check(mm.objective_text == "Go to the Floodline Clinic", "three clues found, on to the clinic")


func test_lantern_lights_ambush() -> void:
	await _new_story_game()
	var mm = game.missions
	mm.abandon()
	mm.done = ["m01_homecoming", "m02_empty_rooms"]
	mm.start("m03_lantern_lights", true)
	await _talk_until(func(): return mm.objective_text.begins_with("Meet Celeste"), 300)
	await _talk_until(func(): return mm.objective_text.begins_with("Pick up Marcel"), 900)
	var m = mm.active
	_place_player_at(m.front("bpd_lantern"))
	game.city.stream_now(m.front("bpd_lantern"))
	await _talk_until(func(): return mm.objective_text == "Get in a car with Marcel", 900)
	var ride = _spawn_car(game.city.nearest_node(game.player.global_position), Vector3(0, 0, 0), 0.0)
	ride.global_position = game.player.global_position + Vector3(0, 0, 4.0)
	await _frames(2)
	game.player.enter_vehicle(ride)
	await _talk_until(func(): return m.marcel.vehicle == ride, 300)
	_check(m.marcel.vehicle == ride, "Marcel gets in when the car is close")
	ride.global_position = m.front("bpd_lantern") + Vector3(0, 0, 60.0)
	await _talk_until(func(): return ride.wrecked, 600)
	_check(ride.wrecked, "the ambush wrecks the car")
	_check(Wanted.level == 2, "the police are called")
	_check(m.marcel.vehicle == null and not m.marcel.dead, "Marcel gets out alive")
	await _talk_until(func(): return mm.objective_text.begins_with("Steal a car"), 300)
	_check(mm.objective_text.begins_with("Steal a car"), "next: steal a car")


func _new_story_game() -> void:
	await _free_game()
	game = MainScene.instantiate()
	game.population_enabled = false
	game.save_enabled = false
	add_child(game)
	await _frames(2)


## Runs frames, tapping through dialogue, until `cond` holds (or `limit`).
func _talk_until(cond: Callable, limit: int) -> void:
	for i in limit:
		if cond.call():
			return
		if game.hud._dialogue.visible:
			game.hud._advance_dialogue()
		await _frames(1)


func _new_game(with_population: bool) -> void:
	await _free_game()
	game = MainScene.instantiate()
	game.population_enabled = with_population
	game.missions_enabled = false
	add_child(game)
	await _frames(2)


func _free_game() -> void:
	Controls.override_vector = null
	for action in ["attack", "interact", "sprint"]:
		Input.action_release(action)
	if game != null:
		game.queue_free()
		game = null
		await get_tree().process_frame
	Wanted.clear()


## The road node next to the spawn point (in front of Union Station).
func _home() -> int:
	return game.city.nearest_node(game.city.spawn_point)


func _place_player(node: int, offset: Vector3) -> void:
	_place_player_at(game.city.node_pos(node) + offset)


func _place_player_at(pos: Vector3) -> void:
	var p = game.player
	p.global_position = pos
	p.rotation.y = 0.0
	p.reset_physics_interpolation()
	game.camera.snap()


func _spawn_car(node: int, offset: Vector3, yaw: float):
	var car = Vehicle.new()
	car.city = game.city
	car.position = game.city.node_pos(node) + offset
	car.rotation.y = yaw
	game.add_child(car)
	return car


func _press(action: String) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)
	await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		print("  FAILED: " + message)
