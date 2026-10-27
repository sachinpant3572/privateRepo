extends Node
## Headless prototype tests. Run with tests/run.sh.
## Each test builds a fresh game, drives it through Controls and checks state.

const MainScene = preload("res://main.tscn")
const Vehicle = preload("res://scripts/vehicle.gd")
const Npc = preload("res://scripts/npc.gd")
const VehicleKit = preload("res://scripts/kits/vehicle_kit.gd")
const Population = preload("res://scripts/population.gd")

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
		"test_people_wear_modern_clothes",
		"test_vehicle_roster_and_parking",
		"test_vehicle_speed_ranks",
		"test_player_driving_assists",
		"test_heavy_vehicle_pushes_harder",
		"test_vehicle_handling_differs",
		"test_traffic_drives_every_kind",
		"test_people_walk_past_sidewalk_props",
		"test_places_line_the_streets",
		"test_shop_visit_restores_the_street",
		"test_doors_lock_and_close",
		"test_diner_meal_and_people_inside",
		"test_bag_and_save_v2",
	]
	# ONLY=name1,name2 runs just those (handy while working on one test).
	var only := OS.get_environment("ONLY")
	if only != "":
		tests = tests.filter(func(t): return t in only.split(","))
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
	await _frames(120)
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
	# Nothing may appear or vanish on screen (the driving camera sees ~60 m
	# out on a wide phone screen).
	var window_size := get_window().size
	get_window().size = Vector2i(2340, 1080)
	var pop = game.population
	var seen := {}
	for p in pop.peds + pop.cars + pop._parked.values():
		seen[p] = pop._in_view(p.global_position, 0.0)
	# spawned, spawned in view, vanished in view, frames, people alive,
	# people on screen, traffic on screen
	var counts := [0, 0, 0, 0, 0, 0, 0]
	for i in 12:
		Controls.override_vector = Vector2.from_angle(i * 1.3)
		await _watch_spawns(60, seen, counts)
	Controls.override_vector = null
	# Then flat out along the straightest run of streets, where the camera
	# is zoomed out and leads furthest.
	var city = game.city
	var at: int = city.nearest_node(car.global_position)
	var heading: Vector3 = -car.global_basis.z
	var path := PackedVector3Array()
	for i in 14:
		var best := -1
		var best_dot := -2.0
		for n in city.next_nodes(at):
			var d: Vector3 = (city.node_pos(n) - city.node_pos(at)).normalized()
			if d.dot(heading) > best_dot:
				best_dot = d.dot(heading)
				best = n
		if best < 0:
			break
		path.append(city.lane_point(at, best))
		heading = (city.node_pos(best) - city.node_pos(at)).normalized()
		at = best
	car.drive_path(path, 1.0)
	var fastest := [0.0]
	await _watch_spawns(480, seen, counts, car, fastest)
	var spawned: int = counts[0]
	var popped: int = counts[1]
	var frames: float = counts[3]
	print("  fast run: %.1f people alive, %.1f on screen, %.1f traffic on screen" % [counts[4] / frames, counts[5] / frames, counts[6] / frames])
	get_window().size = window_size
	await _frames(120) # let the bubble refill around wherever the drive ended
	_check(game.population.peds.size() >= 10, "pedestrians spawned, got %d" % game.population.peds.size())
	_check(game.population.cars.size() >= 5, "traffic spawned, got %d" % game.population.cars.size())
	_check(fastest[0] > 15.0, "the run gets up to speed (%.1f m/s)" % fastest[0])
	_check(spawned > 10 and popped == 0, "%d spawned while driving, %d of them in view" % [spawned, popped])
	_check(counts[2] == 0, "%d people or cars vanished in view" % counts[2])
	_check(counts[4] / frames > 12.0, "the fast run keeps people around (%.1f alive on average)" % (counts[4] / frames))
	_check(is_instance_valid(car), "player car still exists")


## Over `frames`, counts into `counts` (see the caller) the people and cars
## that appear or vanish on screen; `seen` maps each to whether it was on
## screen last frame. Tracks the fastest speed of `car`.
func _watch_spawns(frames: int, seen: Dictionary, counts: Array, car = null, fastest := [0.0]) -> void:
	var pop = game.population
	for f in frames:
		await _frames(1)
		if car != null:
			fastest[0] = maxf(fastest[0], absf(car.speed))
		for p in seen.keys():
			if not is_instance_valid(p):
				if seen[p]:
					counts[2] += 1
				seen.erase(p)
		for p in pop.peds + pop.cars + pop._parked.values():
			if not is_instance_valid(p):
				continue
			var shown: bool = pop._in_view(p.global_position, 0.0)
			if not seen.has(p):
				counts[0] += 1
				if shown:
					counts[1] += 1
			seen[p] = shown
		if car != null:
			counts[3] += 1
			counts[4] += pop.peds.size()
			counts[5] += pop.peds.filter(func(p): return is_instance_valid(p) and pop._in_view(p.global_position, 0.0)).size()
			counts[6] += pop.cars.filter(func(c): return is_instance_valid(c) and c != car and pop._in_view(c.global_position, 0.0)).size()


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


# --- People's clothes ----------------------------------------------------------

## Every outfit and the named cast build as one rigidly skinned mesh within
## the triangle budget; random looks vary; old look keys still work; a phone
## in hand comes up while strolling.
func test_people_wear_modern_clothes() -> void:
	const CharacterKit = preload("res://scripts/kits/character_kit.gd")
	const MeshBuilder = preload("res://scripts/mesh_builder.gd")
	const Rig = preload("res://scripts/rig.gd")
	const Player = preload("res://scripts/player.gd")
	const Cast = preload("res://scripts/missions/cast.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var looks: Array = [Player.JULES, Cast.NIA, Cast.CELESTE, Cast.MARCEL, Cast.REYES, Cast.REMY, Cast.THIEF,
		Cast.CREW[0], Cast.CREW[1], Cast.AURUM, {"outfit": "uniform", "hair": "police"}]
	for row in CharacterKit.OUTFITS:
		looks.append(CharacterKit.random_look(rng, row[0]))
	var bones_ok := true
	for look in looks:
		var mb := MeshBuilder.new()
		CharacterKit.build(mb, look)
		var arrays := mb.commit().surface_get_arrays(0)
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		for v in range(0, bones.size(), 4):
			if bones[v] < 0 or bones[v] >= CharacterKit.BONES.size() or weights[v] != 1.0:
				bones_ok = false
		_check(mb.triangle_count() < 1300, "%s look stays under 1300 triangles, got %d" % [look.get("outfit"), mb.triangle_count()])
	_check(bones_ok, "every vertex is bound rigidly to one real bone")
	var total := 0
	var outfits := {}
	var hats := {}
	var bags := {}
	for i in 400:
		var look := CharacterKit.random_look(rng)
		var mb := MeshBuilder.new()
		CharacterKit.build(mb, look)
		total += mb.triangle_count()
		outfits[look.outfit] = true
		hats[look.get("headwear", "")] = true
		bags[look.get("bag", "")] = true
	# About 690 triangles a person before the modern clothes; budget 1.5x.
	_check(total / 400.0 < 1035.0, "average civilian within the triangle budget, got %.0f" % (total / 400.0))
	_check(outfits.size() >= 14 and hats.size() >= 6 and bags.size() >= 5,
		"street looks vary: %d outfits, %d hats, %d bags" % [outfits.size(), hats.size(), bags.size()])
	var bare := MeshBuilder.new()
	CharacterKit.build(bare, {"hair": "bald"})
	var vest := MeshBuilder.new()
	CharacterKit.build(vest, {"outfit": "vest"})
	var gilet := MeshBuilder.new()
	CharacterKit.build(gilet, {"outfit": "puffer_vest"})
	_check(vest.triangle_count() == gilet.triangle_count(), "old outfit 'vest' builds as a puffer vest")
	for old in [{"hair": "cap"}, {"hair": "beanie"}, {"hair": "police"}]:
		var mb := MeshBuilder.new()
		CharacterKit.build(mb, old)
		_check(mb.triangle_count() > bare.triangle_count(), "old look key %s still builds its part" % str(old))
	var hand_y := []
	for texting in [false, true]:
		var skel := CharacterKit.build_rig({"phone": Color.BLACK})
		var rig = Rig.new(skel)
		var st = Rig.State.new()
		st.speed = 1.4
		st.texting = texting
		for f in 60:
			rig.pose(st, 1.0 / 60.0)
		hand_y.append(skel.get_bone_global_pose(skel.find_bone("RightHand")).origin.y)
		skel.free()
	_check(hand_y[1] > hand_y[0] + 0.15, "texting brings the phone hand up (%.2f -> %.2f)" % hand_y)


# --- Vehicle roster and handling ---------------------------------------------

## Every model is named and categorised, the story's keys exist, and curb
## spots never get a vehicle too long for them (traffic gets no bikes,
## since it has no rider to show).
func test_vehicle_roster_and_parking() -> void:
	await _free_game()
	var cats := {}
	for kind in VehicleKit.KINDS:
		var spec: Dictionary = VehicleKit.spec(kind)
		_check(spec.get("name", "") != "" and spec.has("category"), "%s has a model name and category" % kind)
		cats[spec.category] = true
	_check(cats.size() >= 14, "at least 14 categories, got %d" % cats.size())
	for kind in ["sedan", "taxi", "police", "pickup", "van", "sports", "scooter"]:
		_check(VehicleKit.KINDS.has(kind), "kind '%s' still exists for missions and main.gd" % kind)
	var long := VehicleKit.PARKED.filter(func(k): return VehicleKit.size_of(k).z > VehicleKit.PARKED_MAX_LENGTH)
	_check(long.is_empty(), "parked list holds nothing longer than %.1f m, got %s" % [VehicleKit.PARKED_MAX_LENGTH, long])
	_check(not VehicleKit.PARKED.has("box_truck") and VehicleKit.CIVILIAN.has("box_truck"), "box trucks drive in traffic only")
	_check(VehicleKit.CIVILIAN.all(func(k): return not VehicleKit.spec(k).rider), "no riderless bikes in traffic")
	var pop = Population.new()
	pop.rng.seed = 11
	var parked := {}
	var traffic := {}
	for i in 400:
		for p in [true, false]:
			var car = pop._new_car(p)
			if p:
				parked[car.kind] = true
			else:
				traffic[car.kind] = true
			car.free()
	pop.free()
	var too_long: Array = parked.keys().filter(func(k): return VehicleKit.size_of(k).z > VehicleKit.PARKED_MAX_LENGTH)
	_check(too_long.is_empty() and parked.size() >= 10, "400 parked picks: %d kinds, none too long %s" % [parked.size(), too_long])
	_check(traffic.has("box_truck") and traffic.size() >= 10, "400 traffic picks: %d kinds incl. box trucks" % traffic.size())


## Each kind floors it from rest down a long empty straight (no city, so
## nothing in the way). Top speeds and 0-20 m/s times, measured from the
## distance covered each frame, must rank as designed.
func test_vehicle_speed_ranks() -> void:
	await _free_game()
	var kinds: Array = VehicleKit.KINDS.keys()
	var cars := []
	for i in kinds.size():
		var car = _track_car(kinds[i], Vector3(i * 14.0, 0, 0), 0.0)
		var path := PackedVector3Array([Vector3(i * 14.0, 0, -4000.0)])
		car.drive_path(path, 1.0)
		cars.append(car)
	var last := []
	var top := {}
	var t15 := {}
	for car in cars:
		last.append(car.global_position)
	for f in 600:
		await _frames(1)
		for i in cars.size():
			var v: float = cars[i].global_position.distance_to(last[i]) * 60.0
			last[i] = cars[i].global_position
			top[kinds[i]] = maxf(top.get(kinds[i], 0.0), v)
			if v >= 15.0 and not t15.has(kinds[i]):
				t15[kinds[i]] = (f + 1) / 60.0
	for car in cars:
		car.queue_free()
	for kind in kinds:
		var want: float = VehicleKit.KINDS[kind].max_speed
		_check(absf(top[kind] - want) < want * 0.03, "%s reaches its top speed %.1f m/s, got %.1f" % [kind, want, top[kind]])
	var by_top := ["super", "motorbike", "sports", "muscle", "police", "ev", "luxury", "sedan", "crossover", "suv",
		"compact", "van", "scooter", "box_truck"]
	for i in by_top.size() - 1:
		_check(top[by_top[i]] > top[by_top[i + 1]], "top speed: %s %.1f > %s %.1f" % [by_top[i], top[by_top[i]], by_top[i + 1], top[by_top[i + 1]]])
	var by_launch := ["super", "motorbike", "ev", "sports", "muscle", "police", "sedan", "luxury", "crossover", "compact",
		"suv", "pickup"]
	for i in by_launch.size() - 1:
		var a: String = by_launch[i]
		var b: String = by_launch[i + 1]
		_check(t15.get(a, 99.0) < t15.get(b, 99.0), "0-15 m/s: %s %.2f s < %s %.2f s" % [a, t15.get(a, 99.0), b, t15.get(b, 99.0)])
	_check(t15.ev < t15.sedan * 0.7, "electric torque: EV 0-15 %.2f s well under the sedan's %.2f s" % [t15.ev, t15.sedan])
	_check(not t15.has("box_truck"), "the box truck never reaches 15 m/s")


## The player's car on the empty track: corner assist and wall hits (Sachin:
## roads felt too small to drive "without hitting anything").
func test_player_driving_assists() -> void:
	await _free_game()
	Controls.camera = null # the stick maps straight onto the ground
	# Easing the thumb off on a straight coasts; it does not brake.
	var car = _player_car("sedan", Vector3(-100.0, 0, 0), 20.0)
	Controls.override_vector = Vector2(0, -0.7)
	await _frames(30)
	_check(car.speed > 15.5, "easing off to 0.7 stick on a straight coasts (20 -> %.1f m/s in 0.5 s)" % car.speed)
	car.queue_free()
	# A swerve (stick 30 degrees off for a moment) costs about 1 m/s.
	car = _player_car("sedan", Vector3(-80.0, 0, 0), 20.0)
	Controls.override_vector = Vector2(0.5, -0.866)
	await _frames(15)
	_check(car.speed > 18.5, "a swerve at 20 m/s keeps %.1f m/s" % car.speed)
	car.queue_free()
	# A 90-degree snap at top speed: the car slows for the turn and runs on
	# much less than the 13.5-19.5 m it did without the assist.
	var kinds := ["sedan", "suv", "super"]
	for k in kinds.size():
		var kind: String = kinds[k]
		car = _player_car(kind, Vector3(-60.0 + k * 20.0, 0, k * 40.0), VehicleKit.KINDS[kind].max_speed)
		Controls.override_vector = Vector2(1, 0)
		var run_on := 0.0
		for f in 120:
			await _frames(1)
			run_on = maxf(run_on, k * 40.0 - car.global_position.z)
		_check(run_on < 11.0, "%s at top speed turning 90 degrees runs on %.1f m" % [kind, run_on])
		car.queue_free()
	# A wall along x = 3 for the scrape and the pin.
	var L = preload("res://scripts/layers.gd")
	var wall := StaticBody3D.new()
	wall.collision_layer = L.WORLD
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(0.5, 4, 400)
	wall.add_child(shape)
	wall.position = Vector3(3.0, 2.0, -150.0)
	add_child(wall)
	# Scraping it at 15 degrees costs little speed and counts as one hit.
	car = _player_car("sedan", Vector3(0, 0, 0), 20.0, -deg_to_rad(15.0))
	Controls.override_vector = Vector2(sin(deg_to_rad(15.0)), -cos(deg_to_rad(15.0)))
	await _frames(40)
	_check(car.speed > 15.0, "a 15-degree wall scrape at 20 m/s keeps %.1f m/s" % car.speed)
	_check(car.max_health - car.health < 10.0, "and costs %.1f health" % (car.max_health - car.health))
	car.queue_free()
	# Sliding sideways into it, as out of a drift, keeps the car's speed.
	car = _player_car("sedan", Vector3(0, 0, -40.0), 18.0)
	car.velocity = Vector3(18.0, 0, 0)
	Controls.override_vector = Vector2(0, -1)
	await _frames(40)
	_check(car.speed > 15.0, "sliding sideways into the wall keeps %.1f m/s" % car.speed)
	car.queue_free()
	# Pinned nose-first against it, the car's speed does not wind up.
	car = _player_car("sedan", Vector3(-1.0, 0, -20.0), 0.0, -PI / 2.0)
	Controls.override_vector = Vector2(1, 0)
	var top := 0.0
	for f in 180:
		await _frames(1)
		if f > 60:
			top = maxf(top, absf(car.speed))
	_check(top < 4.0, "held against a wall for 2 s, speed stays low (%.1f m/s)" % top)
	_check(car.max_health - car.health < 15.0, "and the crash counts once (%.1f health)" % (car.max_health - car.health))
	car.queue_free()
	wall.queue_free()
	# Clipping a post with the front corner by 10 cm glances off it.
	var post := StaticBody3D.new()
	post.collision_layer = L.PROPS
	var post_shape := CollisionShape3D.new()
	post_shape.shape = BoxShape3D.new()
	post_shape.shape.size = Vector3(0.3, 2, 0.3)
	post.add_child(post_shape)
	var hw: float = VehicleKit.size_of("sedan").x * 0.5 + 0.05
	post.position = Vector3(hw + 0.15 - 0.1, 1.0, -15.0)
	add_child(post)
	car = _player_car("sedan", Vector3(0, 0, 0), 15.0)
	Controls.override_vector = Vector2(0, -1)
	await _frames(90)
	_check(car.global_position.z < -20.0 and car.speed > 10.0,
		"clipping a post by 10 cm glances off (%.1f m on, %.1f m/s)" % [-car.global_position.z, car.speed])
	car.queue_free()
	post.queue_free()
	Controls.override_vector = null
	# The game that set it is gone; the next _new_game sets it again.


## A player-driven `kind` at `pos` heading -z turned by `yaw`, at `speed`.
func _player_car(kind: String, pos: Vector3, speed: float, yaw := 0.0):
	var car = _track_car(kind, pos, yaw)
	car.driver = Vehicle.Driver.PLAYER
	car.speed = speed
	car.velocity = -car.global_basis.z * speed
	return car


## A box truck rolling into a parked sedan shoves it much harder than the
## sedan rolling into a parked truck; the lighter car takes the damage.
func test_heavy_vehicle_pushes_harder() -> void:
	await _free_game()
	var runs := []
	for r in 2:
		var hitter_kind := "box_truck" if r == 0 else "sedan"
		var target_kind := "sedan" if r == 0 else "box_truck"
		var x := r * 100.0
		var hitter = _track_car(hitter_kind, Vector3(x, 0, 0), 0.0)
		var gap: float = (VehicleKit.size_of(hitter_kind).z + VehicleKit.size_of(target_kind).z) * 0.5 + 4.0
		var target = _track_car(target_kind, Vector3(x, 0, -gap), 0.0)
		hitter.speed = 12.0
		hitter.velocity = Vector3(0, 0, -12.0)
		runs.append([hitter, target])
	var shove := [0.0, 0.0]
	for f in 90:
		await _frames(1)
		for r in 2:
			var t = runs[r][1]
			shove[r] = maxf(shove[r], Vector2(t.velocity.x, t.velocity.z).length())
	var sedan_hit: float = runs[0][1].max_health - runs[0][1].health # truck hit the sedan
	var truck_hit: float = runs[1][1].max_health - runs[1][1].health # sedan hit the truck
	_check(shove[1] > 0.3, "the sedan does nudge the truck (%.2f m/s)" % shove[1])
	_check(shove[0] > shove[1] * 2.0, "truck shoves the sedan to %.1f m/s, the sedan the truck only to %.1f" % [shove[0], shove[1]])
	_check(sedan_hit > truck_hit * 3.0, "the sedan takes more damage being hit (%.1f) than the truck (%.1f)" % [sedan_hit, truck_hit])
	var sedan_driving: float = runs[1][0].max_health - runs[1][0].health
	var truck_driving: float = runs[0][0].max_health - runs[0][0].health
	_check(sedan_driving > truck_driving * 3.0, "and more when it does the hitting (%.1f vs %.1f)" % [sedan_driving, truck_driving])
	for run in runs:
		for car in run:
			car.queue_free()


## From 14 m/s, every kind is told to turn hard right under full throttle.
## The muscle car slides far more than the supercar, the truck turns more
## slowly than the sedan, the tall SUV rolls out of the turn more than the
## low supercar, and the motorbike leans into it (with its rider).
func test_vehicle_handling_differs() -> void:
	await _free_game()
	var kinds := ["sedan", "muscle", "super", "suv", "box_truck", "motorbike"]
	var cars := {}
	for i in kinds.size():
		var car = _track_car(kinds[i], Vector3(i * 30.0, 0, 0), 0.0)
		car.speed = 14.0
		car.velocity = Vector3(0, 0, -14.0)
		car.drive_path(PackedVector3Array([Vector3(i * 30.0 + 400.0, 0, -20.0)]), 1.0)
		cars[kinds[i]] = car
	var rider := Node3D.new() # stands in for the player on the bike
	add_child(rider)
	cars.motorbike.occupant = rider
	var slip := {}
	var roll := {}
	var yaw20 := {}
	for f in 90:
		await _frames(1)
		for kind in kinds:
			var car = cars[kind]
			var v := Vector3(car.velocity.x, 0, car.velocity.z)
			if v.length() > 3.0:
				slip[kind] = maxf(slip.get(kind, 0.0), absf((-car.global_basis.z).signed_angle_to(v, Vector3.UP)))
			roll[kind] = car._tilt.x if absf(car._tilt.x) > absf(roll.get(kind, 0.0)) else roll.get(kind, 0.0)
			if f == 19:
				yaw20[kind] = -car.rotation.y
		if f == 30:
			_check(absf(rider.rotation.z - cars.motorbike._tilt.x) < 0.001 and rider.rotation.z < -0.05, "the rider leans with the bike (%.2f rad)" % rider.rotation.z)
	_check(slip.muscle > slip.super * 1.8, "muscle car slides (%.2f rad) far more than the supercar (%.2f)" % [slip.muscle, slip.super])
	_check(yaw20.box_truck < yaw20.sedan * 0.75, "box truck understeers: turned %.2f rad in 1/3 s vs the sedan's %.2f" % [yaw20.box_truck, yaw20.sedan])
	_check(roll.suv > roll.super * 2.0 and roll.super >= 0.0, "SUV rolls out of the turn (%.3f rad) more than the supercar (%.3f)" % [roll.suv, roll.super])
	_check(roll.motorbike < -0.15, "motorbike leans into the right turn (%.2f rad)" % roll.motorbike)
	cars.motorbike.release_player()
	_check(absf(rider.rotation.z) < 0.001, "the rider stands up straight after getting off")
	rider.queue_free()
	for kind in kinds:
		cars[kind].queue_free()


## Every traffic kind, the box truck included, drives junction to junction
## through the streets around the spawn without getting stuck or wrecked.
func test_traffic_drives_every_kind() -> void:
	await _new_game(false)
	var city = game.city
	var kinds := []
	for k in VehicleKit.CIVILIAN:
		if not kinds.has(k):
			kinds.append(k)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var used := {}
	var cars := []
	var center: Vector3 = city.spawn_point
	for kind in kinds:
		var n := -1
		for attempt in 100:
			n = city.random_node_between(center, 15.0, 160.0, rng)
			# Start apart, so cars don't set off into each other.
			var clear: bool = used.keys().all(func(u): return city.node_pos(u).distance_to(city.node_pos(n)) > 25.0) if n >= 0 else false
			if clear and not city.next_nodes(n).is_empty():
				break
		used[n] = true
		var options: Array = city.next_nodes(n)
		var to: int = options[rng.randi() % options.size()]
		var car = Vehicle.new()
		car.kind = kind
		car.city = city
		car.position = city.lane_start(n, to)
		var heading: Vector3 = city.node_pos(to) - city.node_pos(n)
		car.rotation.y = atan2(-heading.x, -heading.z)
		car.rng.seed = rng.randi()
		car.start_traffic(city, n, to)
		game.add_child(car)
		cars.append(car)
	var passed := {}
	var prev := {}
	for car in cars:
		prev[car] = car._next_node
		passed[car] = 0
	for f in 1800:
		await _frames(1)
		for car in cars:
			if car._next_node != prev[car]:
				prev[car] = car._next_node
				passed[car] += 1
	for car in cars:
		_check(passed[car] >= 3 and not car.wrecked, "traffic %s passed %d junctions in 30 s (wrecked: %s)" % [car.kind, passed[car], car.wrecked])


## A vehicle on the empty test track (no game loaded).
func _track_car(kind: String, pos: Vector3, yaw: float):
	var car = Vehicle.new()
	car.kind = kind
	car.position = pos
	car.rotation.y = yaw
	add_child(car)
	return car


# --- Sidewalk props -----------------------------------------------------------

## People walk their sidewalk loops straight from corner to corner, at
## furniture-frame z 0.75 (city.gd WALK_INSET less the frame's 0.45 inset),
## and before this pass about 140 spots in the city had a prop square
## across that line. A pedestrian walks past each downtown sidewalk prop,
## built at its place in city_cells.gd `_modern_street`, and must get by.
func test_people_walk_past_sidewalk_props() -> void:
	await _free_game()
	var Props = preload("res://scripts/kits/prop_kit.gd")
	var Pedestrian = preload("res://scripts/pedestrian.gd")
	var L = preload("res://scripts/layers.gd")
	var mb = preload("res://scripts/mesh_builder.gd").new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var fake_city := GDScript.new()
	fake_city.source_code = "extends RefCounted\nvar sidewalk_loops: Array = []\n"
	fake_city.reload()
	var city = fake_city.new()
	var names := ["roadworks", "bike rack", "bus shelter", "bike dock", "wayfinding"]
	var nodes := []
	var peds := []
	for i in names.size():
		var origin := Vector3(i * 40.0, 0, 500.0)
		var out := []
		match i:
			0: Props.roadworks(mb, out, Vector3(0.3, 0, 1.7))
			1: Props.bike_rack(mb, out, Vector3(0.2, 0, 1.3), rng)
			2: Props.bus_shelter(mb, out, Vector3(0.2, 0, 1.55), rng)
			3: Props.bike_dock(mb, out, Vector3(0.4, 0, 1.6), 4.0, rng)
			4: Props.wayfinding(mb, out, Vector3(1.0, 0, 0.7))
		for box in out:
			var body := StaticBody3D.new()
			body.collision_layer = L.PROPS
			var shape := CollisionShape3D.new()
			shape.shape = BoxShape3D.new()
			shape.shape.size = box[1]
			body.add_child(shape)
			body.position = origin + box[0]
			add_child(body)
			nodes.append(body)
		# The building front at the lot line.
		var front := StaticBody3D.new()
		front.collision_layer = L.WORLD
		var wall := CollisionShape3D.new()
		wall.shape = BoxShape3D.new()
		wall.shape.size = Vector3(40, 4, 0.5)
		front.add_child(wall)
		front.position = origin + Vector3(12, 2, 2.8)
		add_child(front)
		nodes.append(front)
		city.sidewalk_loops.append(PackedVector3Array([origin + Vector3(-6, 0, 0.75), origin + Vector3(30, 0, 0.75), origin + Vector3(30, 0, -20)]))
		for n in 2:
			var ped = Pedestrian.new()
			ped.setup(city, rng, i, 1)
			ped.step = 1
			ped.position = city.sidewalk_loops[i][0] - Vector3(n * 1.5, 0, 0)
			add_child(ped)
			nodes.append(ped)
			peds.append(ped)
	# The curb is at frame z -0.45; nobody steps off it to get round.
	var lowest := []
	lowest.resize(peds.size())
	lowest.fill(INF)
	for f in 900:
		await _frames(1)
		for k in peds.size():
			lowest[k] = minf(lowest[k], peds[k].position.z - 500.0)
	for i in names.size():
		for k in [i * 2, i * 2 + 1]:
			var x: float = peds[k].position.x - i * 40.0
			_check(x > 4.0 and lowest[k] > -0.45, "pedestrian %d gets past the %s on the sidewalk (x %.1f, nearest the street z %.2f)" % [k % 2 + 1, names[i], x, lowest[k]])
	for n in nodes:
		n.queue_free()


# --- Places and interiors -------------------------------------------------------

func _nearest_place(type: String) -> Dictionary:
	var best := {}
	for p in game.city.places:
		if p.type == type and (best.is_empty() or p.door.distance_to(game.city.spawn_point) < best.door.distance_to(game.city.spawn_point)):
			best = p
	return best


## Streams the street round a place's door and stands the player on it.
func _at_door(p: Dictionary) -> void:
	game.city.stream_now(p.door)
	_place_player_at(p.door)
	game.player.rotation.y = p.yaw
	await _frames(3)


func _enter(p: Dictionary) -> void:
	await _at_door(p)
	while game.interiors._cooldown > 0.0:
		await _frames(1)
	await _press("interact")
	for i in 120:
		if game.interiors.is_inside() and game.player.controllable:
			break
		await _frames(1)


func _leave() -> void:
	var ii = game.interiors
	_place_player_at(ii.ORIGIN + ii.room.hub)
	await _frames(2)
	# The menu's short cooldown (no reopening it with the same press).
	while ii._cooldown > 0.0:
		await _frames(1)
	await _press("interact")
	for i in 120:
		if ii.state == ii.State.OUTSIDE and game.player.controllable:
			break
		await _frames(1)


## Every district gets the place types the mix gives it, on any seed; each
## door is on open sidewalk with its storefront right behind it.
func test_places_line_the_streets() -> void:
	const City = preload("res://scripts/city.gd")
	const Places = preload("res://scripts/places.gd")
	for seed_v in [1, 2, 3, 7, 42, 99, 1234]:
		var city = City.new()
		add_child(city)
		city.build(seed_v)
		var have := {}
		for p in city.places:
			have[p.district + ":" + p.type] = true
		var missing: Array = []
		for d in Places.MIX:
			for t in Places.MIX[d]:
				if not have.has(d + ":" + t):
					missing.append(d + ":" + t)
		_check(missing.is_empty(), "seed %d: every district has its place types, missing %s" % [seed_v, missing])
		city.queue_free()
		await get_tree().process_frame
	await _new_game(false)
	var city = game.city
	_check(city.places.size() >= 14, "places are listed, got %d" % city.places.size())
	var again = preload("res://scripts/places.gd").build(city)
	_check(again.size() == city.places.size() and again.all(func(p): return p.door == city.places[again.find(p)].door), "places are the same on every build")
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var blocked: Array = []
	var no_front: Array = []
	for p in city.places:
		_place_player_at(p.door + Vector3(0, 0, 0.01))
		city.stream_now(p.door)
		await _frames(1)
		var query := PhysicsShapeQueryParameters3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.4
		query.shape = sphere
		query.collision_mask = 1 | 16
		query.transform = Transform3D(Basis(), p.door + Vector3(0, 0.9, 0))
		if not space.intersect_shape(query, 1).is_empty():
			blocked.append(p.name)
		var inward := Vector3(-sin(p.yaw), 0, -cos(p.yaw))
		var ray := PhysicsRayQueryParameters3D.create(p.door + Vector3(0, 1.0, 0), p.door + Vector3(0, 1.0, 0) + inward * 3.0, 1)
		if space.intersect_ray(ray).is_empty():
			no_front.append(p.name)
	_check(blocked.is_empty(), "every doorstep is clear, blocked: %s" % [blocked])
	_check(no_front.is_empty(), "a storefront stands behind every door, missing: %s" % [no_front])


## Going into a shop freezes the street exactly as it was and gives it
## back on the way out; buying takes cash and fills the bag.
func test_shop_visit_restores_the_street() -> void:
	await _new_game(true)
	var ii = game.interiors
	var store := _nearest_place("corner_store")
	game.atmosphere.hour = 12.0
	await _at_door(store)
	await _frames(60)
	var car = _spawn_car(game.city.nearest_node(store.door), Vector3(0, 0, 0), 0.0)
	await _frames(10)
	_check(ii.prompt().size() == 2 and ii.prompt()[1] == "ENTER", "the door offers ENTER, got %s" % [ii.prompt()])
	var peds: Array = game.population.peds.duplicate()
	var ped_at: Array = peds.map(func(p): return p.global_position)
	var car_at: Vector3 = car.global_position
	var hour: float = game.atmosphere.hour
	await _enter(store)
	_check(ii.is_inside(), "pressing ENTER at the door goes in")
	_check(game.player.global_position.distance_to(ii.ORIGIN) < 12.0, "the player is in the room")
	_check(not game.city.visible and game.population.process_mode == Node.PROCESS_MODE_DISABLED, "the street is hidden and frozen")
	_check(game.atmosphere.indoors and game.camera.fixed_focus != null, "indoor light and room camera")
	_check(get_tree().get_nodes_in_group("patrons").size() >= 2, "a shopkeeper and customers are inside")
	await _frames(120)
	_check(car.global_position == car_at, "parked traffic waits where it was")
	_check(game.atmosphere.hour > hour, "the clock keeps running inside")
	# Buy at the counter.
	game.cash = 100
	game.player.health = 50.0
	_place_player_at(ii.ORIGIN + ii.room.counter.pos)
	await _frames(2)
	_check(ii.prompt()[1] == "BUY", "the counter offers BUY, got %s" % [ii.prompt()])
	await _press("interact")
	_check(ii.menu.visible and not game.player.controllable, "the counter opens the shop menu")
	_check(ii.buy("chips", "take") and game.cash == 96 and game.inventory.bag == ["chips"], "buying chips to take: $4 and into the bag")
	_check(ii.buy("sandwich", "eat") and game.cash == 87 and is_equal_approx(game.player.health, 80.0), "eating a sandwich now heals 30")
	_check(not ii.buy("burger", "order"), "diner meals aren't sold here")
	game.cash = 1
	_check(not ii.buy("energy", "eat") and game.cash == 1, "can't buy without the cash")
	ii.menu.close()
	_check(game.player.controllable, "closing the menu gives control back")
	await _leave()
	_check(ii.state == ii.State.OUTSIDE, "EXIT at the door goes back out")
	_check(game.player.global_position.distance_to(store.door) < 0.5, "back on the doorstep")
	_check(game.city.visible and game.population.process_mode != Node.PROCESS_MODE_DISABLED, "the street is back and running")
	_check(car.global_position.distance_to(car_at) < 0.05 and car.visible, "the car is where it was")
	var moved: Array = []
	for i in peds.size():
		if not is_instance_valid(peds[i]) or peds[i].global_position.distance_to(ped_at[i]) > 3.0:
			moved.append(i)
	_check(peds.size() > 0 and moved.is_empty(), "the same people are about where they were (%d of %d moved off)" % [moved.size(), peds.size()])
	_check(not game.atmosphere.indoors and game.camera.fixed_focus == null, "street light and camera are back")
	_check(get_tree().get_nodes_in_group("patrons").is_empty(), "the room and its people are gone")


func test_doors_lock_and_close() -> void:
	await _new_game(false)
	var ii = game.interiors
	var diner := _nearest_place("diner")
	game.atmosphere.hour = 3.0
	await _at_door(diner)
	_check(ii.prompt()[1] == "CLOSED", "the diner is shut at 3 am, got %s" % [ii.prompt()])
	await _press("interact")
	_check(ii.state == ii.State.OUTSIDE, "a shut door stays shut")
	game.atmosphere.hour = 12.0
	await _frames(2)
	Wanted.report_crime(1)
	await _frames(2)
	_check(ii.prompt()[1] == "LOCKED" and ii.prompt()[0].contains("cops"), "no hiding in shops from the police, got %s" % [ii.prompt()])
	await _press("interact")
	_check(ii.state == ii.State.OUTSIDE, "locked with stars")
	Wanted.clear()
	game.police.clear_all()
	await _frames(2)
	_check(ii.prompt()[1] == "ENTER", "open at noon with no stars")
	var car = _spawn_car(game.city.nearest_node(diner.door), Vector3.ZERO, 0.0)
	game.player.enter_vehicle(car)
	await _frames(2)
	_check(ii.prompt().is_empty(), "no doors from behind the wheel")
	game.player.exit_vehicle()


func test_diner_meal_and_people_inside() -> void:
	await _new_game(false)
	var ii = game.interiors
	game.atmosphere.hour = 12.0
	await _enter(_nearest_place("diner"))
	_check(ii.is_inside(), "into the diner")
	game.cash = 50
	game.player.health = 30.0
	_place_player_at(ii.ORIGIN + ii.room.counter.pos)
	await _frames(2)
	_check(ii.prompt()[1] == "ORDER", "the register takes orders")
	_check(ii.buy("burger", "order"), "ordering a burger")
	_check(game.cash == 35 and game.player.sitting and not game.player.controllable, "Jules sits down to eat it")
	await _frames(int(ii.MEAL_TIME * 60) + 10)
	_check(is_equal_approx(game.player.health, 90.0) and not game.player.sitting and game.player.controllable, "the meal heals 60 and Jules gets up (health %.1f)" % game.player.health)
	# Let the place run for a minute: customers come, eat and go.
	var left := [0]
	var arrived := {}
	var worst := 0.0
	for i in 3600:
		for n in get_tree().get_nodes_in_group("patrons"):
			if not n.staff:
				if not arrived.has(n):
					arrived[n] = true
					n.left.connect(func(_w): left[0] += 1)
				worst = maxf(worst, n.stuck_time)
		await _frames(1)
	_check(left[0] >= 2, "diners finish and leave, %d left" % left[0])
	_check(arrived.size() >= left[0] + 1, "new customers arrive (%d seen)" % arrived.size())
	_check(worst < 3.0, "nobody gets stuck (worst %.1f s)" % worst)
	await _leave()
	_check(ii.state == ii.State.OUTSIDE, "out of the diner")
	# The corner store: shoppers browse, pay and leave.
	await _enter(_nearest_place("corner_store"))
	_check(ii.is_inside(), "into the corner store")
	left[0] = 0
	arrived.clear()
	worst = 0.0
	var paid := [0]
	for i in 3600:
		for n in get_tree().get_nodes_in_group("patrons"):
			if not n.staff:
				if not arrived.has(n):
					arrived[n] = true
					n.left.connect(func(_w): left[0] += 1)
				worst = maxf(worst, n.stuck_time)
				if n.gesture == "pay":
					paid[0] += 1
		await _frames(1)
	_check(left[0] >= 2 and paid[0] > 0, "shoppers pay and leave, %d left" % left[0])
	_check(worst < 3.0, "nobody gets stuck in the aisles (worst %.1f s)" % worst)
	# Hitting someone inside sends them running and calls the police.
	var victim = null
	for n in get_tree().get_nodes_in_group("patrons"):
		if not n.staff:
			victim = n
	if victim != null:
		victim.take_hit(game.player, 5.0, Vector3.ZERO)
		_check(Wanted.level == 1, "the shopkeeper calls the police")
	await _leave()
	Wanted.clear()


func test_bag_and_save_v2() -> void:
	await _new_game(false)
	var mm = game.missions
	var inv = game.inventory
	_check(inv.add("chips") and inv.add("candy") and inv.add("sandwich") and not inv.add("soda"), "the bag holds three snacks")
	_check(not inv.add("burger"), "diner meals don't go in the bag")
	game.player.health = 40.0
	_check(game.eat_snack() and inv.bag.size() == 2 and is_equal_approx(game.player.health, 70.0), "SNACK eats the best one first (sandwich +30)")
	game.player.health = game.player.max_health
	_check(not game.eat_snack() and inv.bag.size() == 2, "no snacking at full health")
	# Save v2 round trip, through a throwaway file.
	mm.save_enabled = true
	mm.save_path = "user://test_save_v2.json"
	game.cash = 77
	mm.save_game()
	inv.bag.clear()
	game.cash = 0
	mm.load_game()
	_check(game.cash == 77 and inv.bag == ["chips", "candy"], "the bag and cash survive save and load, got %s" % [inv.bag])
	var saved = JSON.parse_string(FileAccess.get_file_as_string(mm.save_path))
	_check(int(saved.get("version", 0)) == 2, "saves are version 2")
	# A version 1 save (before the bag) still loads.
	var f := FileAccess.open(mm.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"done": ["m01_homecoming"], "cash": 500, "phone": false, "settings": {}}))
	f.close()
	mm.load_game()
	_check(game.cash == 500 and mm.done == ["m01_homecoming"] and inv.bag.is_empty(), "a v1 save loads with an empty bag")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(mm.save_path))

