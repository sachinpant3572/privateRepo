extends Node
## Headless prototype tests. Run with tests/run.sh.
## Each test builds a fresh game, drives it through Controls and checks state.

const MainScene = preload("res://main.tscn")
const Vehicle = preload("res://scripts/vehicle.gd")
const Npc = preload("res://scripts/npc.gd")
const VehicleKit = preload("res://scripts/kits/vehicle_kit.gd")
const Terrain = preload("res://scripts/terrain.gd")
const Population = preload("res://scripts/population.gd")
const StreetPlan = preload("res://scripts/street_plan.gd")

var game
var passed := 0
var failed := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var tests := [
		"test_city_streams_cells",
		"test_city_follows_world_map",
		"test_street_plan_is_a_california_grid",
		"test_bellerive_borrows_dc_ny_and_california",
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
		"test_perspective_camera",
		"test_camera_turns_with_car",
		"test_punch_combo_ends_in_knockdown_kick",
		"test_minimap_routes_to_waypoint", "test_state_map_shows_the_whole_state",
		"test_night_lights_the_city",
		"test_homecoming_runs_start_to_finish",
		"test_failed_mission_can_be_retried",
		"test_empty_rooms_phone_and_clues",
		"test_lantern_lights_ambush",
		"test_people_wear_modern_clothes",
		"test_vehicle_roster_and_parking",
		"test_vehicle_speed_ranks",
		"test_player_driving_assists",
		"test_driving_layouts",
		"test_touch_driving_layouts",
		"test_scripted_car_gets_unstuck", "test_heavy_vehicle_pushes_harder",
		"test_vehicle_handling_differs",
		"test_traffic_drives_every_kind",
		"test_roads_have_two_lanes_each_way", "test_cars_knock_down_roadside_props",
		"test_people_walk_past_sidewalk_props",
		"test_places_line_the_streets",
		"test_shop_visit_restores_the_street",
		"test_doors_lock_and_close",
		"test_diner_meal_and_people_inside",
		"test_bag_and_save_v2",
		"test_shop_menu_leaves_touch_buttons_alone",
		"test_thrown_out_of_a_room",
		"test_hit_diner_leaves_the_booth",
		"test_taxi_hail_ride_and_pay",
		"test_taxi_phone_call_and_skip",
		"test_taxi_refuses_wanted_and_broke",
		"test_taxi_ride_ends_cleanly",
		"test_country_joins_the_city",
		"test_country_tiles_stream",
		"test_country_walls_stop_cars",
		"test_traffic_drives_into_the_country", "test_traffic_turns_round_at_barricades",
		"test_country_kit_builds_every_kind",
		"test_country_plots_square_to_their_roads", "test_estates_and_clusters", "test_grounds_kit_builds_every_part",
		"test_bellerive_hills", "test_golden_flats_farmland", "test_every_home_has_a_way_in", "test_homes_by_wealth",
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


## Bellerive v3 (HANDOFF-bellerive-v3.md): the civic centre (City Hall on
## its grounds, the Esplanade, Founders Circle), Midtown's long blocks with
## Liberty Avenue cutting across, Moreau Square and its painted rows, and
## the government buildings facing the mall.
func test_bellerive_borrows_dc_ny_and_california() -> void:
	await _new_game(false)
	var city = game.city
	var plan = city.plan
	for id in ["founders_circle", "city_hall_grounds", "esplanade", "moreau_square"]:
		_check(plan.set_piece_face(id) >= 0, "set piece %s is a block" % id)
	_check(city.landmark_block("city_hall") == plan.set_piece_face("city_hall_grounds"), "City Hall stands on its grounds")
	for id in ["esplanade", "founders_circle", "moreau_square"]:
		var f: int = plan.set_piece_face(id)
		_check(f < 0 or city.landmark_at(f).is_empty(), "%s has no landmark lot in it" % id)
	# Founders Circle: a ring with at least four roads meeting it, and none
	# crossing its lawn.
	var ring := {}
	for e in plan.edge_count():
		if plan.edge_road[e] == "founders":
			ring[plan.edge_a[e]] = true
			ring[plan.edge_b[e]] = true
	var spokes := 0
	var inside := 0
	for e in plan.edge_count():
		if plan.edge_road[e] == "founders":
			continue
		for n in [plan.edge_a[e], plan.edge_b[e]]:
			if ring.has(n):
				spokes += 1
		var mid: Vector2 = (plan.pos(plan.edge_a[e]) + plan.pos(plan.edge_b[e])) * 0.5
		if mid.distance_to(plan.circle_at) < plan.CIRCLE_R - 4.0:
			inside += 1
	_check(spokes >= 4, "roads meet Founders Circle (%d)" % spokes)
	_check(inside == 0, "no street crosses the circle's lawn (%d)" % inside)
	# Magnolia Avenue stops at the City Hall grounds, like DC's diagonals.
	var grounds: int = plan.set_piece_face("city_hall_grounds")
	var through := 0
	for e in plan.edge_count():
		if plan.edge_road[e] == "magnolia" and grounds >= 0:
			var mid: Vector2 = (plan.pos(plan.edge_a[e]) + plan.pos(plan.edge_b[e])) * 0.5
			if Geometry2D.is_point_in_polygon(mid, plan.faces[grounds].inner):
				through += 1
	_check(through == 0, "Magnolia Avenue goes round the grounds, not through them")
	# The buildings on the Esplanade face it, City Hall faces down it and
	# the Federal Building faces the grounds from the north.
	for pair in [["county_courthouse", Vector3(0, 0, -1)], ["federal_building", Vector3(0, 0, 1)], ["public_library", Vector3(0, 0, -1)],
			["police_headquarters", Vector3(0, 0, 1)], ["city_hall", Vector3(1, 0, 0)]]:
		var out: Vector3 = city.landmark_frame(pair[0]).basis.z
		_check(out.dot(pair[1]) > 0.7, "%s faces the civic centre (front %s)" % [pair[0], out])
	# Midtown: avenues (district streets of avenue class) with long thin
	# blocks between them, and Liberty Avenue crossing at least one.
	var avenues := 0
	var crossings := 0
	for e in plan.edge_count():
		if plan.edge_patch[e] >= 0 and plan.PATCHES[plan.edge_patch[e]].id == "midtown" and plan.edge_cls[e] == "avenue":
			avenues += 1
			for n in [plan.edge_a[e], plan.edge_b[e]]:
				for e2 in plan.edges_of(n):
					if plan.edge_road[e2] == "liberty":
						crossings += 1
	_check(avenues >= 10, "Midtown has avenues (%d pieces)" % avenues)
	_check(crossings >= 2, "Liberty Avenue cuts across Midtown's avenues (%d)" % crossings)
	var long_blocks := 0
	var mid_blocks := 0
	for f in plan.faces.size():
		if plan.face_patch(f) == "midtown" and plan.is_land(f) and city.in_window(f) and city.landmark_at(f).is_empty():
			mid_blocks += 1
			var r: Rect2 = plan.lot_rect(f)
			if maxf(r.size.x, r.size.y) > minf(r.size.x, r.size.y) * 1.6:
				long_blocks += 1
	_check(mid_blocks > 0 and long_blocks * 2 > mid_blocks, "Midtown's blocks are long and thin (%d of %d)" % [long_blocks, mid_blocks])
	# New district looks are in use.
	var styles := {}
	for f in plan.faces.size():
		if plan.is_land(f) and city.in_window(f):
			styles[city.district_style(f)] = true
			if city.faces_square(f):
				styles["painted"] = true
			styles[city.block_style(f)] = true
	for style in ["midtown", "brownstone", "painted", "esplanade", "circle", "square"]:
		_check(styles.has(style), "style '%s' is used" % style)


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
	_check(city.district_at(city.spawn_point).name == "Midtown", "Union Station is in Midtown")
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


## The map should read as a California city (Sachin, 2026-10-27: "few of
## them [diagonal] but rest all have bigger parallel roads"): one straight
## north-south/east-west grid, boulevards running right through it on a
## regular pitch, few diagonals, mostly rectangular blocks. The old warped
## plan failed every one of these (17% of streets on the compass).
func test_street_plan_is_a_california_grid() -> void:
	await _new_game(false)
	var city = game.city
	var plan = city.plan
	var counts := {}
	var bearing := PackedFloat32Array()
	bearing.resize(9) # street length by bearing (mod 90 degrees), 10-degree bins
	var total := 0.0
	var square := 0.0 # length within 5 degrees of the compass
	var gridded := 0.0 # ... or of the old town's grid, turned 30 degrees
	for e in plan.edge_count():
		var a: Vector2 = plan.pos(plan.edge_a[e])
		var b: Vector2 = plan.pos(plan.edge_b[e])
		if not city.window.has_point((a + b) * 0.5):
			continue
		var cls: String = plan.edge_class(e)
		counts[cls] = counts.get(cls, 0) + 1
		if plan.drivable(e):
			var deg := fposmod(rad_to_deg((b - a).angle()), 90.0)
			var off := minf(deg, 90.0 - deg)
			total += a.distance_to(b)
			square += a.distance_to(b) if off < 5.0 else 0.0
			var old := absf(fposmod(deg - 30.0 + 45.0, 90.0) - 45.0)
			gridded += a.distance_to(b) if off < 5.0 or old < 5.0 else 0.0
	for cls in ["boulevard", "avenue", "river", "street", "quarter", "lane", "bridge", "quay"]:
		_check(counts.get(cls, 0) > 0, "street class '%s' is used" % cls)
	_check(square > total * 0.8, "streets run north-south and east-west (%.0f%% within 5 degrees)" % (square / total * 100.0))
	_check(gridded > total * 0.9, "two grids at most, the city's and the old town's (%.0f%% on them; the rest is Liberty Avenue, Magnolia and the river)" % (gridded / total * 100.0))
	# District streets run right through their district, from boulevard to
	# boulevard (Sachin: "most of them do cover the district end to end, and
	# are joined to major highways at the end"). One may stop short (a
	# junction of three streets of its district alone) only where something
	# stops it: a landmark's lot, a park or set piece, the river, or a road
	# crossing the grid at an angle (Liberty Avenue, the old town's edge),
	# as Broadway does in Manhattan. The docks drop some on purpose, for
	# yards.
	var junctions := 0
	var stops := 0
	var abrupt: Array = []
	for n in plan.node_count():
		var es: Array = plan.edges_of(n)
		if es.size() < 3 or not city.window.has_point(plan.pos(n)):
			continue
		var k: int = plan.edge_patch[es[0]]
		if k < 0 or plan.PATCHES[k].id == "docks" or not es.all(func(e): return plan.edge_road[e] == "" and plan.edge_patch[e] == k):
			continue
		junctions += 1
		if es.size() == 3:
			stops += 1
			if not es.any(func(e): return _stops_streets(city, plan, e, k)):
				abrupt.append(plan.pos(n).round())
	_check(junctions > 100 and stops < junctions * 0.12 and abrupt.size() <= junctions * 0.02,
		"district streets run through (%d of %d junctions are streets stopping short, %d with nothing stopping them: %s)" % [stops, junctions, abrupt.size(), abrupt])
	# The boulevards run straight through, district to district.
	for road in ["lantern", "crescent", "aurum", "rampart", "cypress"]:
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for e in plan.edge_count():
			if plan.edge_road[e] == road:
				for q in [plan.pos(plan.edge_a[e]), plan.pos(plan.edge_b[e])]:
					lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
					hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
		var span := maxf(hi.x - lo.x, hi.y - lo.y)
		var drift := minf(hi.x - lo.x, hi.y - lo.y)
		_check(span > 900.0 and drift < 3.0, "%s runs straight through (%.0f m long, %.1f m off line)" % [road, span, drift])
	# Junctions: a grid, so crossroads more than T-junctions.
	var tees := 0
	var crosses := 0
	for n in plan.node_count():
		if not city.drive_node(n):
			continue
		var d: int = plan.edges_of(n).size()
		tees += 1 if d == 3 else 0
		crosses += 1 if d == 4 else 0
	_check(crosses > tees, "crossroads outnumber T-junctions (%d crossroads, %d T)" % [crosses, tees])
	# Blocks: mostly rectangles (the odd ones lie along Liberty Avenue and
	# the river), in different sizes from district to district.
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
	_check(odd < land * 0.35, "blocks are mostly rectangles (%d of %d not)" % [odd, land])
	areas.sort()
	var spread: float = areas[areas.size() * 9 / 10] / areas[areas.size() / 10]
	_check(spread > 2.0, "blocks differ in size from district to district (90th/10th percentile %.1f)" % spread)
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
	for id in ["union_station", "aurum_tower", "lantern_square", "blue_lantern", "bpd_lantern", "floodline_clinic", "wharfside_courts", "moreau_house", "teo_apartment", "warehouse_9", "the_pit", "streetcar_depot", "drowned_streetcar",
			"city_hall", "county_courthouse", "federal_building", "public_library", "police_headquarters", "main_post_office", "fire_headquarters", "ferry_building", "liberty_square"]:
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


## True when a block beside street e (of patch k) stops streets: it is
## water, a park, a set piece or a landmark's lot, or a side of it runs off
## the patch grid's axes (a diagonal road, the river bank).
func _stops_streets(city, plan, e: int, k: int) -> bool:
	var grid_angle: float = plan.PATCHES[k].angle
	for f in [plan.edge_face[e].x, plan.edge_face[e].y]:
		if f < 0 or not plan.is_land(f) or plan.is_park(f) or plan.set_piece(f) != "" or city._landmarks.has(f):
			return true
		var poly: PackedVector2Array = plan.face_poly(f)
		for i in poly.size():
			var d: Vector2 = poly[(i + 1) % poly.size()] - poly[i]
			if d.length() > 4.0 and absf(fposmod(rad_to_deg(d.angle()) - grid_angle + 45.0, 90.0) - 45.0) > 5.0:
				return true
	return false


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
	var start := Vector3.INF
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
		if start == Vector3.INF:
			start = city.lane_start(at, best)
		path.append(city.lane_point(at, best))
		heading = (city.node_pos(best) - city.node_pos(at)).normalized()
		at = best
	# The weave can leave the car on a kerb; set off from the lane, so the
	# run isn't cut short by a lamp post.
	var first: Vector3 = path[0] - start
	car.global_position = start
	car.rotation.y = atan2(-first.x, -first.z)
	car.velocity = Vector3.ZERO
	car.speed = 0.0
	car.reset_physics_interpolation()
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


## The perspective view (HANDOFF-perspective-camera.md): on by default,
## framing the same ground as the classic view, never inside a building
## downtown, opening the cutaway when a building hides the player, and
## switching to the classic view from Settings.
## A stand-in for a car the camera follows (tests of the driving view).
class FakeDrive extends Node3D:
	var body: CharacterBody3D
	func focus_node() -> Node3D:
		return body


func test_perspective_camera() -> void:
	var L = preload("res://scripts/layers.gd")
	var MB = preload("res://scripts/mesh_builder.gd")
	await _new_game(false)
	var cam = game.camera
	_place_player(_home(), Vector3.ZERO)
	await _frames(5)
	_check(cam.perspective and cam.projection == Camera3D.PROJECTION_PERSPECTIVE, "the camera sees in perspective by default")
	var framed: float = 2.0 * cam.global_position.distance_to(cam._focus) * tan(deg_to_rad(cam.fov) * 0.5)
	_check(absf(framed - cam.size) < cam.size * 0.01, "perspective frames %.1f m at the player, the zoom asks %.1f" % [framed, cam.size])
	# Downtown spots where the usual camera spot would be inside a tower.
	var city = game.city
	var space: PhysicsDirectSpaceState3D = cam.get_world_3d().direct_space_state
	var query := PhysicsPointQueryParameters3D.new()
	query.collision_mask = L.WORLD
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var win: Rect2 = city.window
	var base: float = cam.FOOT_SIZE * 0.5 / tan(deg_to_rad(cam.PERSPECTIVE_FOV) * 0.5)
	var inside_spots := 0
	var outside := 0
	var framing_kept := 0
	var blocked_spot = null
	var shadows_fit := 0
	var pitch_sum := 0.0
	var pitch_true := 0
	for i in 900:
		if inside_spots >= 6 and blocked_spot != null:
			break
		var at := Vector3(rng.randf_range(win.position.x, win.end.x), 0, rng.randf_range(win.position.y, win.end.y))
		if not str(city.district_at(at).get("id", "")) in ["gilt_district", "midtown"]:
			continue
		city.stream_now(at)
		await get_tree().physics_frame
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3(0, 200, 0), at + Vector3(0, 0.3, 0), L.WORLD)).is_empty():
			continue
		query.position = at + cam.global_basis.z * base
		var inside := not space.intersect_point(query, 1).is_empty()
		if not inside and (blocked_spot != null or inside_spots >= 6):
			continue
		_place_player_at(at)
		await _frames(3)
		if blocked_spot == null and cam._view_blocked(game.player.global_position):
			blocked_spot = at
		if not inside:
			continue
		inside_spots += 1
		query.position = cam.global_position
		if space.intersect_point(query, 1).is_empty():
			outside += 1
		framed = 2.0 * cam.global_position.distance_to(cam._focus) * tan(deg_to_rad(cam.fov) * 0.5)
		if absf(framed - cam.size) < cam.size * 0.02:
			framing_kept += 1
		if game.atmosphere.sun.directional_shadow_max_distance >= cam.view_depth * 1.25:
			shadows_fit += 1
		# The pitch is picked every 0.25 s and eases over about a second.
		await _frames(90)
		pitch_sum += cam.perspective_pitch
		if cam.perspective_pitch >= cam.PITCH_TALL - 0.5 or not cam._view_blocked(game.player.global_position):
			pitch_true += 1
	_check(inside_spots >= 3, "found downtown spots where the usual camera spot is inside a tower: %d" % inside_spots)
	_check(outside == inside_spots and framing_kept == inside_spots, "the camera backs out of the tower at all of them (%d of %d) and frames the same ground (%d)" % [outside, inside_spots, framing_kept])
	_check(pitch_true == inside_spots and pitch_sum / maxf(inside_spots, 1) > 72.0, "among towers the camera tips steeper (%.0f degrees on average) and sees the player, or is at its steepest, at %d of %d spots" % [pitch_sum / maxf(inside_spots, 1), pitch_true, inside_spots])
	_check(shadows_fit == inside_spots, "the shadows reach past the ground the backed-out camera frames (%d of %d)" % [shadows_fit, inside_spots])
	_check(blocked_spot != null, "found a downtown spot where a building hides the player")
	if blocked_spot != null:
		_place_player_at(blocked_spot)
		await _frames(90)
		var mat: ShaderMaterial = MB.cutaway_material()
		var still: bool = cam._view_blocked(game.player.global_position)
		var opened: bool = float(mat.get_shader_parameter("cut_radius")) > cam.CUT_RADIUS * 0.9 and float(mat.get_shader_parameter("cone")) == 1.0
		_check(opened == still, "where a building hides the player even at the picked pitch (%.0f degrees: %s), the cutaway opens round them, narrowing toward the camera (%s)" % [cam.perspective_pitch, "hidden" if still else "in sight", "open" if opened else "shut"])
	# The view band runs out ahead of a moving player, widens over a tower,
	# and is off inside a place.
	var band: ShaderMaterial = MB.cutaway_material()
	_place_player(_home(), Vector3.ZERO)
	await _frames(30)
	game.player.velocity = Vector3(4.0, 0.0, 0.0)
	cam._update_view_band(game.player)
	var ahead: Vector3 = band.get_shader_parameter("ahead")
	_check(ahead.distance_to(Vector3(4.0 * cam.AHEAD_SECONDS, 0, 0)) < 0.01 and float(band.get_shader_parameter("view_radius")) >= cam.VIEW_RADIUS_FOOT, "the view band runs %.0f m ahead of a player walking east, %.0f m wide" % [ahead.length(), float(band.get_shader_parameter("view_radius"))])
	var back_was: float = cam._back
	cam._back = base * 2.0
	cam._update_view_band(game.player)
	_check(is_equal_approx(float(band.get_shader_parameter("view_radius")), cam.VIEW_RADIUS_FOOT * 2.0), "and widens to %.0f m when the camera has backed out over a tower" % float(band.get_shader_parameter("view_radius")))
	cam._back = back_was
	cam.fixed_focus = game.player.global_position
	cam._update_view_band(game.player)
	_check(float(band.get_shader_parameter("view_radius")) == 0.0, "inside a place the view band is off")
	cam.fixed_focus = null
	game.player.velocity = Vector3.ZERO
	# Ground (terrain and roads) is marked so the band never cuts a hill.
	var mb = MB.new()
	mb.box(Vector3.ZERO, Vector3.ONE, Color.WHITE)
	mb.mark_ground(0)
	var start: int = mb.verts.size()
	mb.box(Vector3(0, 5, 0), Vector3.ONE, Color.WHITE)
	var arrays: Array = mb.commit().surface_get_arrays(0)
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	_check(uv2[0].x == 1.0 and uv2[start - 1].x == 1.0 and uv2[start].x == 0.0, "ground vertices carry the ground mark, the rest do not")
	game.settings["view"] = "classic"
	game.apply_settings()
	await _frames(2)
	_check(cam.projection == Camera3D.PROJECTION_ORTHOGONAL and is_equal_approx(cam.rotation_degrees.x, -cam.PITCH), "Settings > View switches to the classic flat view")
	game.settings["view"] = "perspective"
	game.apply_settings()
	await _frames(2)
	_check(cam.projection == Camera3D.PROJECTION_PERSPECTIVE, "and back to perspective")
	# Settings > Zoom scales the view, and the city loads further out to match.
	_place_player(_home(), Vector3.ZERO)
	game.settings["zoom"] = 1.3
	game.apply_settings()
	await _frames(240)
	_check(absf(cam.size - cam.FOOT_SIZE * 1.3) < 0.5 and game.city.LOAD_RADIUS > 130.0, "Zoom 130%% frames %.1f m on foot and loads cells to %.0f m" % [cam.size, game.city.LOAD_RADIUS])
	game.settings["zoom"] = 1.0
	game.apply_settings()
	# Settings > Angle and Tilt near towers, driven from the phone, and Reset
	# camera putting angle, tilt, distance and drive zoom-out back.
	var phone = game.hud.phone
	phone.open()
	phone._settings()
	var angle_s = phone.steppers.get("Angle")
	var zoom_s = phone.steppers.get("Distance")
	var drive_s = phone.steppers.get("Drive zoom-out")
	var tilt_b = _find_button(phone._body, "Tilt near towers: ")
	var reset_b = _find_button(phone._body, "Reset camera")
	_check(angle_s != null and zoom_s != null and drive_s != null and tilt_b != null and reset_b != null and angle_s.get_meta("value").text == "65°" and zoom_s.get_meta("value").text == "100%" and drive_s.get_meta("value").text == "100%", "Settings has Distance (100%), Drive zoom-out (100%), Angle (65°), Tilt near towers and Reset camera")
	if angle_s != null and zoom_s != null and drive_s != null and tilt_b != null and reset_b != null:
		for n in 4:
			angle_s.get_meta("less").pressed.emit()
		tilt_b.pressed.emit()
		zoom_s.get_meta("more").pressed.emit()
		drive_s.get_meta("less").pressed.emit()
		phone.close()  # the open phone pauses the game
		await _frames(240)
		_check(angle_s.get_meta("value").text == "45°" and tilt_b.text.ends_with("OFF") and cam.pitches() == [45.0] and absf(cam.perspective_pitch - 45.0) < 0.5 and game.settings["angle"] == 45.0, "Angle - four times: 45° with tilt off holds the camera at %.1f degrees" % cam.perspective_pitch)
		_check(cam.zoom == 1.15 and game.settings["zoom"] == 1.15 and cam.drive_zoom == 0.75 and drive_s.get_meta("value").text == "75%", "Distance + gives 115%, Drive zoom-out - gives 75%")
		_check(game.city.LOAD_RADIUS > 105.0 * 1.15 * 1.25, "at 45° and Distance 115%% the city loads to %.0f m" % game.city.LOAD_RADIUS)
		tilt_b.pressed.emit()
		_check(cam.pitches() == [45.0, 50.0, 55.0, 60.0, 65.0, 70.0, 75.0, 80.0, 85.0], "with tilt on it picks from 45° up to 85°")
		phone.close()  # the open phone pauses the game
		await _frames(240)
		_check(cam.perspective_pitch < 52.0, "and among low buildings it stays near 45° (%.1f)" % cam.perspective_pitch)
		for n in cam.ANGLES.size() + 2:
			angle_s.get_meta("more").pressed.emit()
		phone.close()  # the open phone pauses the game
		await _frames(240)
		var below: Vector3 = cam.project_ray_normal(cam.get_viewport().get_visible_rect().get_center())
		_check(absf(cam.perspective_pitch - 90.0) < 0.5 and below.y < -0.99 and angle_s.get_meta("more").disabled and not angle_s.get_meta("less").disabled, "Angle 90° looks straight down, and + stops there rather than wrapping")
		for n in cam.DRIVE_ZOOMS.size() + 1:
			drive_s.get_meta("less").pressed.emit()
		_check(cam.drive_zoom == 0.0 and drive_s.get_meta("value").text == "Off" and drive_s.get_meta("less").disabled, "Drive zoom-out goes down to Off")
		reset_b.pressed.emit()
		phone.close()  # the open phone pauses the game
		await _frames(240)
		_check(angle_s.get_meta("value").text == "65°" and tilt_b.text.ends_with("ON") and zoom_s.get_meta("value").text == "100%" and drive_s.get_meta("value").text == "100%" and cam.base_pitch == cam.PITCH_LOW and cam.auto_tilt and cam.zoom == 1.0 and cam.drive_zoom == 1.0 and absf(cam.perspective_pitch - 65.0) < 0.5, "Reset camera puts back 65°, tilt on, 100%% distance and drive zoom-out (pitch %.1f)" % cam.perspective_pitch)
	phone.close()
	game.settings["angle"] = 42
	game.settings["auto_tilt"] = "yes"
	game.settings["drive_zoom"] = 0.3
	game.apply_settings()
	_check(cam.base_pitch == cam.PITCH_LOW and cam.auto_tilt and cam.drive_zoom == 1.0 and game.city.LOAD_RADIUS == 105.0, "a bad saved angle, tilt or drive zoom-out falls back to 65°, tilt on and 100%")
	game.settings["angle"] = 65.0
	game.settings["auto_tilt"] = true
	game.settings["drive_zoom"] = 1.0
	# Driving flat out, the view zooms out and leads the car, keeping it on
	# screen, and the city loads round the middle of the screen.
	_place_player(_home(), Vector3.ZERO)
	await _frames(30)
	_check(absf(cam.perspective_pitch - cam.PITCH_LOW) < 0.5, "among low buildings the camera stays at %.0f degrees" % cam.perspective_pitch)
	var car := CharacterBody3D.new()
	game.add_child(car)
	car.global_position = game.player.global_position
	var drive := FakeDrive.new()
	drive.body = car
	game.add_child(drive)
	cam.target = drive
	var rect: Rect2 = cam.get_viewport().get_visible_rect()
	var report := []
	var all_on := true
	var all_far := true
	var all_loaded := true
	for dir in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		car.velocity = dir * 30.0
		await _frames(300)
		var at: Vector2 = cam.unproject_position(car.global_position)
		if not rect.grow(-rect.size.y * 0.04).has_point(at):
			all_on = false
		# The ground at the screen's edge straight ahead of the car.
		var edge := Vector2(rect.end.x - 1.0 if dir.x > 0.0 else 1.0 if dir.x < 0.0 else at.x, 1.0 if dir.z < 0.0 else rect.end.y - 1.0 if dir.z > 0.0 else at.y)
		var o: Vector3 = cam.project_ray_origin(edge)
		var n: Vector3 = cam.project_ray_normal(edge)
		var g: Vector3 = o + n * ((car.global_position.y - o.y) / n.y)
		var ahead_m: float = (g - car.global_position).dot(dir)
		var e: Array = cam.ground_extents(cam.size)
		# What a 20:9 phone shows east-west (the test window is 16:9).
		var wide: float = cam.size * 0.5 * 20.0 / 9.0
		var want: float = (wide + minf(33.0, wide * 0.6)) if dir.x != 0.0 else (e[2] + minf(33.0, e[1] * 0.75) if dir.z < 0.0 else e[1] + minf(33.0, e[2] * 0.75))
		if dir.x != 0.0:
			ahead_m += wide - e[0] + minf(33.0, wide * 0.6) - minf(33.0, e[0] * 0.6)
		if ahead_m < want - 3.0 or (dir.x != 0.0 and ahead_m < 95.0) or (dir.x == 0.0 and ahead_m < 55.0):
			all_far = false
		for c in [Vector2(0, 0), Vector2(rect.end.x, 0), Vector2(0, rect.end.y), rect.end]:
			var co: Vector3 = cam.project_ray_origin(c)
			var cn: Vector3 = cam.project_ray_normal(c)
			var cg: Vector3 = co + cn * ((car.global_position.y - co.y) / cn.y)
			var sp: Vector3 = cam.stream_point()
			if Vector2(cg.x - sp.x, cg.z - sp.z).length() > game.city.LOAD_RADIUS:
				all_loaded = false
		report.append("%s %.0f m at %.0f degrees" % [["east", "west", "north", "south"][[Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK].find(dir)], ahead_m, cam.perspective_pitch])
	_check(absf(cam.size - cam.DRIVE_SIZE) < 1.0, "flat out the view frames %.0f m" % cam.size)
	_check(all_on, "the car stays on screen driving each way flat out")
	_check(all_far, "the road shows far ahead on a 20:9 phone: %s" % ", ".join(report))
	_check(all_loaded, "the screen's corners lie inside the cells loaded round the middle of the screen")
	# Settings > Drive zoom-out: half widens half as far, Off keeps the
	# on-foot framing, and the car stays on screen either way.
	var dz_sizes := []
	var still_on := true
	for dz in [0.5, 0.0]:
		game.settings["drive_zoom"] = dz
		game.apply_settings()
		await _frames(300)
		dz_sizes.append(cam.size)
		if not rect.grow(-rect.size.y * 0.04).has_point(cam.unproject_position(car.global_position)):
			still_on = false
	game.settings["drive_zoom"] = 1.0
	game.apply_settings()
	_check(absf(dz_sizes[0] - lerpf(cam.FOOT_SIZE, cam.DRIVE_SIZE, 0.5)) < 1.0 and absf(dz_sizes[1] - cam.FOOT_SIZE) < 1.0 and still_on, "Drive zoom-out 50%% frames %.0f m flat out and Off %.0f m (on foot %.0f), the car on screen" % [dz_sizes[0], dz_sizes[1], cam.FOOT_SIZE])
	# Real drives along city routes, the player riding along. Downtown at
	# 30 m/s the tilt settles instead of hunting (the first picker turned back
	# 19.5 times a minute on this drive); in the low-rise districts it stays
	# low (the first hold kept it above 67 degrees 21% of the time here). Each
	# corner of a 20:9 screen is over a cell the city loads.
	var down: Dictionary = await _route_drive(cam, car, 5, ["gilt_district", "midtown"], [], 40.0)
	var low: Dictionary = await _route_drive(cam, car, 3, LOW_RISE, LOW_RISE, 40.0)
	# Zoom 130%, where the screen's corners reach past the cells round the player.
	game.settings["zoom"] = 1.3
	game.apply_settings()
	var wide: Dictionary = await _route_drive(cam, car, 7, LOW_RISE + ["gilt_district", "midtown"], [], 20.0)
	game.settings["zoom"] = 1.0
	game.apply_settings()
	var per_min: float = down.turns / maxf(down.t, 1.0) * 60.0
	_check(down.t > 30.0 and down.changes > 0 and per_min <= 12.0, "driving downtown the tilt changes %d times and turns back %.1f times a minute (%.0f s driven)" % [down.changes, per_min, down.t])
	var steep: float = low.steep / maxf(low.frames, 1.0)
	_check(low.frames > 1200 and steep <= 0.15, "driving through low-rise districts the camera is above 67 degrees %.0f%% of the time" % (steep * 100.0))
	_check(wide.corners > 100 and down.corners + low.corners > 200 and down.outside + low.outside + wide.outside == 0, "driving, every 20:9 screen corner is over a cell the city streams in (%d missing; at 130%%: %d of %d corners, %d were still in the build queue)" % [down.outside + low.outside, wide.outside, wide.corners, down.queued + low.queued + wide.queued])
	cam.target = game.player
	drive.queue_free()
	car.queue_free()
	await _frames(2)


# --- Helpers -----------------------------------------------------------------

## Settings > Camera turn "Follow" (HANDOFF-heading-camera.md): the view
## swings round behind the car the way Chinatown Wars' does, within comfort
## limits, and the stick steers the car rather than pointing it; on foot it
## follows the walk.
func test_camera_turns_with_car() -> void:
	await _free_game()
	var TopDownCamera = preload("res://scripts/top_down_camera.gd")
	var cam = TopDownCamera.new()
	add_child(cam)
	var p = preload("res://scripts/player.gd").new()
	p.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(p)
	cam.target = p
	Controls.camera = cam
	var car = _player_car("sedan", Vector3(0, 0, 400.0), 0.0)
	p.vehicle = car
	cam.snap()
	_check(cam.turns() and Controls.stick_steers() and absf(cam.yaw) < 0.01, "Follow is the default: the view starts behind the car and the stick steers")
	# Up is gas.
	Controls.override_vector = Vector2(0, -1)
	await _frames(120)
	_check(car.speed > 12.0 and absf(cam.yaw) < 0.05, "stick up drives on (%.1f m/s) and the view stays put going straight" % car.speed)
	# Leaning the stick right turns the car right; the view follows, never
	# faster than 90 degrees a second.
	var max_rate := 0.0
	var last: float = cam.yaw
	Controls.override_vector = Vector2(0.7, -0.7)
	var turned := 0.0
	var was: float = TopDownCamera._heading(-car.global_basis.z)
	for f in 60:
		await _frames(1)
		var now: float = TopDownCamera._heading(-car.global_basis.z)
		turned += wrapf(now - was, -PI, PI)
		was = now
		max_rate = maxf(max_rate, rad_to_deg(absf(wrapf(cam.yaw - last, -PI, PI))) * 60.0)
		last = cam.yaw
	_check(turned < -deg_to_rad(60.0), "leaning the stick right turns the car right (%.0f degrees)" % rad_to_deg(-turned))
	Controls.override_vector = Vector2(0, -1)
	for f in 150:
		await _frames(1)
		max_rate = maxf(max_rate, rad_to_deg(absf(wrapf(cam.yaw - last, -PI, PI))) * 60.0)
		last = cam.yaw
	var face: float = TopDownCamera._heading(-car.global_basis.z)
	var lag: float = absf(wrapf(cam.yaw - face, -PI, PI))
	_check(lag < deg_to_rad(4.0), "out of the turn the view settles behind the car (%.1f degrees off)" % rad_to_deg(lag))
	_check(max_rate <= 90.5, "the view turns at most 90 degrees a second (%.0f)" % max_rate)
	# Up the screen is now the car's way ahead, in the stick's frame too.
	var up: Vector3 = cam.ground_axes()[1]
	_check(up.dot(-car.global_basis.z) > 0.99 and cam.input_axes()[1].dot(up) > 0.99, "screen up is the car's heading, for the view and the stick")
	# Stick down brakes, then backs up; the view does not flip round.
	var held: float = cam.yaw
	var moved_back := 0.0
	Controls.override_vector = Vector2(0, 1)
	var from: Vector3 = car.global_position
	var drift := 0.0
	for f in 420:
		await _frames(1)
		drift = maxf(drift, absf(wrapf(cam.yaw - held, -PI, PI)))
	moved_back = (car.global_position - from).dot(-car.global_basis.z)
	_check(car.velocity.dot(-car.global_basis.z) < -1.0, "stick down brakes and then backs up (%.1f m/s)" % car.velocity.dot(-car.global_basis.z))
	_check(drift < deg_to_rad(5.0), "backing up, the view holds (%.1f degrees)" % rad_to_deg(drift))
	# Stopped, turning the car in place does not turn the view.
	Controls.override_vector = null
	car.speed = 0.0
	car.velocity = Vector3.ZERO
	await _frames(10)
	held = cam.yaw
	car.rotation.y += PI * 0.5
	await _frames(60)
	_check(absf(wrapf(cam.yaw - held, -PI, PI)) < 0.02, "below 3 m/s the view holds")
	# The compass (the minimap's N) swings it behind the car.
	face = TopDownCamera._heading(-car.global_basis.z)
	cam.recenter()
	await _frames(150)
	_check(absf(wrapf(cam.yaw - face, -PI, PI)) < 0.02, "the compass swings the view behind the car (%.1f to %.1f degrees)" % [rad_to_deg(cam.yaw), rad_to_deg(face)])
	# North up: the view eases back and the stick points the car again.
	cam.turn_view = false
	await _frames(180)
	_check(absf(cam.yaw) < 0.02 and not Controls.stick_steers(), "North up turns the view back and the stick points the way to go (%.1f degrees)" % rad_to_deg(cam.yaw))
	cam.turn_view = true
	# Inside a place the view is north up at once.
	cam.fixed_focus = car.global_position
	await _frames(2)
	_check(cam.yaw == 0.0, "inside places the view is north up")
	cam.fixed_focus = null
	car.queue_free()
	# Flat out the screen shows the road well ahead (Chinatown Wars players
	# found too little of it): 3.3 s of it or more, 70 m or more in the fastest
	# cars (a sedan saw 60 m, 2.9 s, before the wider, flatter framing).
	for kind in ["sedan", "super"]:
		var fast = _player_car(kind, Vector3(-200.0 if kind == "sedan" else 200.0, 0, 600.0), 0.0)
		p.vehicle = fast
		cam.snap()
		Controls.override_vector = Vector2(0, -1)
		await _frames(420)
		var rect: Rect2 = cam.get_viewport().get_visible_rect()
		var co: Vector3 = cam.project_ray_origin(Vector2(rect.size.x * 0.5, 0.0))
		var cn: Vector3 = cam.project_ray_normal(Vector2(rect.size.x * 0.5, 0.0))
		var top: Vector3 = co + cn * ((fast.global_position.y - co.y) / cn.y)
		var ahead: float = (top - fast.global_position).dot(-fast.global_basis.z)
		var want: float = 70.0 if kind == "super" else fast.speed * 3.3
		_check(ahead > want, "%s flat out at %.1f m/s: the screen shows %.0f m ahead, %.1f s (%.0f m framed, %.0f degrees)" % [kind, fast.speed, ahead, ahead / fast.speed, cam.size, cam.perspective_pitch])
		Controls.override_vector = null
		fast.queue_free()
	# On foot (H-13, H-14): the view follows the walk, calmer than in a car,
	# while the stick's frame holds so a sideways push walks straight instead
	# of circling. The test player doesn't run its physics, so its velocity
	# is set by hand; the camera reads the walk's direction off the stick.
	p.vehicle = null
	p.global_position = Vector3(0, 0, 300.0)
	cam.yaw = deg_to_rad(37.0)
	cam._yaw_goal = cam.yaw
	cam._yaw_rate = 0.0
	cam._yaw_chasing = false
	cam._yaw_forced = false
	Controls.override_vector = Vector2(1, 0)
	p.velocity = Vector3(4.2, 0, 0)
	await _frames(2)
	var frame: Vector3 = cam.input_axes()[0]
	var walk_rate := 0.0
	last = cam.yaw
	for f in 300:
		await _frames(1)
		walk_rate = maxf(walk_rate, rad_to_deg(absf(wrapf(cam.yaw - last, -PI, PI))) * 60.0)
		last = cam.yaw
	_check(absf(wrapf(cam.yaw - deg_to_rad(-53.0), -PI, PI)) < 0.02 and cam.input_axes()[0].dot(frame) > 0.9999, "on foot the view follows the walk (37 -> %.1f degrees) while the stick's frame holds, so the walk runs straight" % rad_to_deg(cam.yaw))
	_check(walk_rate <= 60.5, "on foot the view turns at most 60 degrees a second (%.0f)" % walk_rate)
	# A thumb wobble (15 degrees) keeps the frame, and the view ignores it.
	held = cam.yaw
	Controls.override_vector = Vector2(cos(deg_to_rad(15.0)), sin(deg_to_rad(15.0)))
	await _frames(90)
	_check(absf(wrapf(cam.yaw - held, -PI, PI)) < 0.01 and cam.input_axes()[0].dot(frame) > 0.9999, "a 15-degree wobble of the thumb neither turns the view nor the stick's frame")
	# Swinging the thumb up takes the frame from the view again: up walks up
	# the screen as it now is, and the view stays.
	Controls.override_vector = Vector2(0, -1)
	await _frames(90)
	_check(cam.input_axes()[1].dot(cam.ground_axes()[1]) > 0.9999 and absf(wrapf(cam.yaw - held, -PI, PI)) < 0.01, "swinging the thumb up re-reads the stick in the view: up walks up the screen")
	# Standing still squares the view up with the streets.
	Controls.override_vector = null
	p.velocity = Vector3.ZERO
	await _frames(80)
	frame = cam.input_axes()[0]
	Controls.override_vector = Vector2(1, 0)
	var turning: float = cam.yaw
	await _frames(20)
	_check(absf(cam.yaw - turning) > 0.05 and cam.input_axes()[0].dot(frame) > 0.9999, "squaring up while the stick is held, the stick's frame holds (view %.0f -> %.0f degrees)" % [rad_to_deg(turning), rad_to_deg(cam.yaw)])
	Controls.override_vector = null
	await _frames(150)
	_check(absf(wrapf(cam.yaw + PI * 0.5, -PI, PI)) < 0.02, "standing still, the view squares up with the streets (%.1f degrees)" % rad_to_deg(cam.yaw))
	# Getting into a car facing the other way: the view swings behind it
	# before it moves, so stick up drives up the screen from the start.
	var south = _player_car("sedan", Vector3(0, 0, 500.0), 0.0, PI)
	p.vehicle = south
	await _frames(240)
	_check(absf(wrapf(cam.yaw - PI, -PI, PI)) < 0.02 and south.velocity.length() < 0.5, "getting into a parked car facing south, the view swings behind it (%.1f degrees)" % rad_to_deg(cam.yaw))
	p.vehicle = null
	south.queue_free()
	p.queue_free()
	cam.queue_free()
	Controls.camera = null
	# In the game: the setting, the bad-value fallback and the minimap.
	await _new_game(false)
	cam = game.camera
	_check(not cam.turn_view, "the test games start north up")
	game.settings["camera_turn"] = 42
	game.apply_settings()
	_check(cam.turn_view, "a bad saved Camera turn falls back to With car")
	var car2 = _spawn_car(_home(), Vector3(0, 0, -3), -PI * 0.5)
	_place_player(_home(), Vector3.ZERO)
	await _frames(2)
	await _press("interact")
	cam.snap()
	await _frames(2)
	var mm = game.hud.minimap
	var north: Vector2 = mm.turn(Vector2(0, -1))
	var arrow: Vector2 = mm.turn(Vector2(1, 0))
	_check(game.player.vehicle == car2 and absf(cam.yaw + PI * 0.5) < 0.02 and north.dot(Vector2(-1, 0)) > 0.99 and arrow.dot(Vector2(0, -1)) > 0.99, "driving east, the minimap turns with the view: the car points up, N sits on the left")
	cam.yaw = 0.3
	cam._yaw_rate = 0.0
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	tap.position = mm.north_mark()
	mm._gui_input(tap)
	await _frames(150)
	_check(absf(cam.yaw + PI * 0.5) < 0.02 and not game.hud.full_map.visible, "tapping the N swings the view behind the car (and does not open the map; %.1f degrees)" % rad_to_deg(cam.yaw))
	# City routes with the view turning (the car swings at each corner): the
	# wider, flatter view still only shows cells the city streams in.
	var drive: Dictionary = await _route_drive(cam, car2, 7, LOW_RISE + ["gilt_district", "midtown"], [], 30.0)
	_check(drive.corners > 100 and drive.outside == 0, "driving city routes with the view turning, every 20:9 screen corner is over a cell the city streams in (%d of %d missing, %d still in the build queue)" % [drive.outside, drive.corners, drive.queued])
	game.settings["camera_turn"] = "north"
	game.apply_settings()
	await _frames(180)
	_check(absf(cam.yaw) < 0.02, "Settings > Camera turn North up turns the view back (%.1f degrees)" % rad_to_deg(cam.yaw))


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


func test_state_map_shows_the_whole_state() -> void:
	await _new_game(false)
	var city = game.city
	var t0 := Time.get_ticks_msec()
	var state: Dictionary = preload("res://scripts/state_map.gd").bake(city.map_origin)
	print("  state map bake: %d ms" % (Time.get_ticks_msec() - t0))
	_check(state.size == Vector2(2000, 1500), "the state bakes at 6 m a pixel, got %s" % state.size)
	var playable: Array = state.labels.cities.filter(func(c): return c.playable)
	_check(state.labels.cities.size() == 4 and playable.size() == 1 and playable[0].name == "Bellerive",
		"four cities, Bellerive the playable one")
	_check(state.labels.peaks.size() >= 5 and state.labels.towns.size() >= 16, "peaks and towns are labelled")
	# World (2965, 5398) is 35 m down Bottle Flats Road, inside its first dash;
	# 95 m down is in the gap after it, back on the desert.
	var img: Image = state.texture.get_image()
	var dash := img.get_pixel(int(2965 / 6.0), int(5398 / 6.0))
	var gap := img.get_pixel(int(2905 / 6.0), int(5394 / 6.0))
	_check(_same_color(dash, preload("res://scripts/state_map.gd").TRACK), "a dirt track is drawn, got %s" % dash)
	_check(not _same_color(gap, preload("res://scripts/state_map.gd").TRACK), "and dashed, got %s" % gap)
	var fm = game.hud.full_map
	fm.open()
	await get_tree().process_frame
	fm.zoom = fm._min_zoom()
	var span: Vector2 = state.world_size * fm.zoom
	_check(fm.zoom < fm.STATE_ZOOM and span.x <= fm.size.x and span.y <= fm.size.y - 56.0,
		"zoomed out, the whole state fits the screen (%s in %s)" % [span, fm.size])
	game.waypoint = null
	var concordia: Dictionary = state.labels.cities.filter(func(c): return c.name == "Concordia")[0]
	fm.pan = (Vector2(concordia.pos.x, concordia.pos.z) - fm.map.origin) / preload("res://scripts/map_image.gd").PX_M
	fm._tap(fm.size * 0.5)
	_check(game.waypoint == null and fm._note == "Concordia: not open yet", "a tap on Concordia says it is not open, got '%s'" % fm._note)
	fm.pan = (city.window.get_center() - fm.map.origin) / preload("res://scripts/map_image.gd").PX_M
	fm._tap(fm.size * 0.5)
	_check(game.waypoint != null, "a tap inside Bellerive still sets a waypoint")
	fm.close()
	var mat: ShaderMaterial = game.hud.minimap._mat
	_check(mat.get_shader_parameter("state_tex") == fm.state.texture, "the minimap shows the state past the city's edge")
	var uv_rect: Vector4 = mat.get_shader_parameter("city_uv_rect")
	var lo: Vector2 = (city.window.position - fm.map.origin) / fm.map.size
	var hi: Vector2 = (city.window.end - fm.map.origin) / fm.map.size
	_check(uv_rect.is_equal_approx(Vector4(lo.x, lo.y, hi.x, hi.y)) and lo.x > 0.0 and hi.x < 1.0,
		"the minimap shows the city's bake only inside the playable window, got %s" % uv_rect)
	game.waypoint = null


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
	game.settings["camera_turn"] = "north"
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
	game.settings["camera_turn"] = "north"
	game.population_enabled = with_population
	game.missions_enabled = false
	add_child(game)
	await _frames(2)


func _free_game() -> void:
	Controls.override_vector = null
	Controls.scheme = "stick"
	Controls.tilt_override = null
	for action in ["attack", "interact", "sprint", "gas", "brake", "steer_left", "steer_right"]:
		Input.action_release(action)
	if game != null:
		game.queue_free()
		game = null
		await get_tree().process_frame
	Wanted.clear()


## The road node next to the spawn point (in front of Union Station).
const LOW_RISE := ["lantern_quarter", "floodline_wards", "morrow_point", "ironwharf"]


## Drives `car` (with the player riding along) at 30 m/s along routes from
## random points in the districts `from` (to points in `to`, if any) for
## `seconds`, counting tilt changes and turn-backs, frames above 67 degrees
## outside downtown, and 20:9 screen corners the city's streaming leaves
## unloaded once its build queue has run.
func _route_drive(cam, car: CharacterBody3D, seed: int, from: Array, to: Array, seconds: float) -> Dictionary:
	var city = game.city
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var win: Rect2 = city.window
	var rect: Rect2 = cam.get_viewport().get_visible_rect()
	var wide_x: float = (rect.size.y * 20.0 / 9.0 - rect.size.x) * 0.5
	var out := {"t": 0.0, "changes": 0, "turns": 0, "steep": 0, "frames": 0, "corners": 0, "outside": 0, "queued": 0}
	var tries := 0
	while out.t < seconds and tries < 400:
		tries += 1
		var a := Vector3(rng.randf_range(win.position.x, win.end.x), 0.0, rng.randf_range(win.position.y, win.end.y))
		if not str(city.district_at(a).get("id", "")) in from:
			continue
		var b := a + Vector3(rng.randf_range(-600.0, 600.0), 0.0, rng.randf_range(-600.0, 600.0))
		if not to.is_empty() and not str(city.district_at(b).get("id", "")) in to:
			continue
		var pts: PackedVector3Array = city.route(city.node_pos(city.nearest_node(a)), city.node_pos(city.nearest_node(b)))
		if pts.size() < 4:
			continue
		car.global_position = pts[0]
		car.velocity = Vector3.ZERO
		game.player.global_position = pts[0]
		game.player.reset_physics_interpolation()
		city.stream_now(pts[0])
		cam.snap()
		var last_want: float = cam._pitch_want
		var last_dir := 0.0
		for k in range(1, pts.size()):
			var start: Vector3 = pts[k - 1]
			var leg: Vector3 = pts[k] - start
			leg.y = 0.0
			var s := 0.0
			while s < leg.length() and out.t < seconds:
				await game.get_tree().physics_frame
				s += 30.0 / 60.0
				out.t += 1.0 / 60.0
				car.velocity = leg.normalized() * 30.0
				car.rotation.y = atan2(-leg.x, -leg.z)
				car.global_position = Vector3(start.x, 0.0, start.z) + leg.normalized() * minf(s, leg.length())
				game.player.global_position = car.global_position
				var w: float = cam._pitch_want
				if absf(w - last_want) > 0.1:
					out.changes += 1
					if last_dir != 0.0 and signf(w - last_want) != last_dir:
						out.turns += 1
					last_dir = signf(w - last_want)
					last_want = w
				if not str(city.district_at(car.global_position).get("id", "")) in ["gilt_district", "midtown"]:
					out.frames += 1
					if cam.perspective_pitch > 67.0:
						out.steep += 1
				if Engine.get_process_frames() % 15 == 0:
					var cells: Array = []
					for c in [Vector2(-wide_x, 0.0), Vector2(rect.end.x + wide_x, 0.0), Vector2(-wide_x, rect.end.y), Vector2(rect.end.x + wide_x, rect.end.y)]:
						var co: Vector3 = cam.project_ray_origin(c)
						var cn: Vector3 = cam.project_ray_normal(c)
						var cell: int = city.cell_at(co + cn * (-co.y / cn.y))
						if cell >= 0:
							cells.append(cell)
							if city.cell_node(cell) == null:
								out.queued += 1
					# Builds run on a worker thread in wall-clock time, so let the
					# city's own streaming finish its queue before judging it.
					for n in 60:
						city._finish_task()
						city._stream_tick = 0.0
						city._process(0.0)
						if city._task < 0:
							break
					for cell in cells:
						out.corners += 1
						if city.cell_node(cell) == null:
							out.outside += 1
	return out


func _home() -> int:
	return game.city.nearest_node(game.city.spawn_point)


func _place_player(node: int, offset: Vector3) -> void:
	_place_player_at(game.city.node_pos(node) + offset)


## Height of the highest country tile surface over p (x, z), leaving out
## anything more than 1.5 m over the ground (lamps, wires, roofs). A road
## is drawn by one tile but may reach into the next, so the tiles round
## p's are searched too.
func _surface_top(country, p: Vector2) -> float:
	var top := -INF
	var cap := Terrain.height(p.x, p.y) + 1.5
	var key: Vector2i = country.tile_key(Vector3(p.x, 0.0, p.y))
	var meshes: Array = []
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var tile: Node3D = country.tile_node(key + Vector2i(dx, dy))
			if tile != null:
				meshes.append_array(tile.get_children())
	for n in meshes:
		if not n is MeshInstance3D or n.mesh == null:
			continue
		var xf: Transform3D = n.global_transform
		for si in n.mesh.get_surface_count():
			var arr: Array = n.mesh.surface_get_arrays(si)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx = arr[Mesh.ARRAY_INDEX]
			var count: int = idx.size() if idx != null else vs.size()
			for k in range(0, count, 3):
				var a: Vector3 = xf * vs[idx[k] if idx != null else k]
				var b: Vector3 = xf * vs[idx[k + 1] if idx != null else k + 1]
				var cc: Vector3 = xf * vs[idx[k + 2] if idx != null else k + 2]
				if p.x < minf(a.x, minf(b.x, cc.x)) or p.x > maxf(a.x, maxf(b.x, cc.x)) or p.y < minf(a.z, minf(b.z, cc.z)) or p.y > maxf(a.z, maxf(b.z, cc.z)):
					continue
				var bc := Geometry3D.get_triangle_barycentric_coords(Vector3(p.x, 0, p.y), Vector3(a.x, 0, a.z), Vector3(b.x, 0, b.z), Vector3(cc.x, 0, cc.z))
				if bc.x < 0.0 or bc.y < 0.0 or bc.z < 0.0:
					continue
				var y := a.y * bc.x + b.y * bc.y + cc.y * bc.z
				if y <= cap:
					top = maxf(top, y)
	return top


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


## Equal to within 8-bit image rounding.
func _same_color(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01


func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		if OS.get_environment("VERBOSE") != "": print("  ok: " + message)
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


## The driving layouts: GAS and BRAKE work with the stick; the arrows and
## tilt turn the wheel, off the pedals the car rolls on, and the brake
## held at a stop reverses with the tail swinging the way the wheel turns.
func test_driving_layouts() -> void:
	await _free_game()
	Controls.camera = null
	# Stick: GAS alone drives straight on, BRAKE stops then backs up.
	var car = _player_car("sedan", Vector3(-100.0, 0, 0), 0.0)
	Input.action_press("gas")
	await _frames(60)
	_check(car.speed > 8.0 and absf(car.global_position.x + 100.0) < 0.5, "stick layout: GAS alone drives straight on (%.1f m/s)" % car.speed)
	Input.action_release("gas")
	Input.action_press("brake")
	await _frames(40)
	var stopped_in: float = car.speed
	await _frames(60)
	_check(stopped_in < 2.0 and car.speed < -1.0, "BRAKE stops the car (%.1f m/s), held it reverses (%.1f m/s)" % [stopped_in, car.speed])
	Input.action_release("brake")
	car.queue_free()
	for scheme in ["arrows", "tilt"]:
		Controls.scheme = scheme
		car = _player_car("sedan", Vector3(-60.0 if scheme == "arrows" else -20.0, 0, 0), 12.0)
		var heading: Vector3 = -car.global_basis.z
		Input.action_press("gas")
		if scheme == "arrows":
			Input.action_press("steer_right")
		else:
			Controls.tilt_override = Vector3(4.0, -8.9, 0.0) # right side down
		await _frames(45)
		var turned := heading.signed_angle_to(-car.global_basis.z, Vector3.UP)
		_check(turned < -0.6, "%s layout: steering right with GAS turns right (%.2f rad)" % [scheme, turned])
		_check(car.speed > 9.0, "%s layout: no corner assist braking (%.1f m/s)" % [scheme, car.speed])
		# Off the gas, still steering: it rolls on.
		Input.action_release("gas")
		await _frames(30)
		_check(car.speed > 6.0, "%s layout: off the pedals the car coasts (%.1f m/s)" % [scheme, car.speed])
		Input.action_release("steer_right")
		Controls.tilt_override = null
		car.queue_free()
	# Wheel left while reversing: the nose swings right, the tail left.
	Controls.scheme = "arrows"
	car = _player_car("sedan", Vector3(20.0, 0, 0), 0.0)
	var nose: Vector3 = -car.global_basis.z
	Input.action_press("brake")
	Input.action_press("steer_left")
	await _frames(90)
	var swung := nose.signed_angle_to(-car.global_basis.z, Vector3.UP)
	_check(car.speed < -1.0 and swung < -0.2, "reversing with the wheel left swings the nose right (%.1f m/s, %.2f rad)" % [car.speed, swung])
	Input.action_release("brake")
	Input.action_release("steer_left")
	car.queue_free()
	# Tilt: dead zone near level, full lock by 25 degrees.
	Controls.scheme = "tilt"
	Controls.tilt_override = Vector3(sin(deg_to_rad(2.0)), -cos(deg_to_rad(2.0)), 0.0) * 9.8
	_check(Controls.steer() == 0.0, "a 2-degree tilt is in the dead zone")
	Controls.tilt_override = Vector3(-sin(deg_to_rad(30.0)), -cos(deg_to_rad(30.0)), 0.0) * 9.8
	_check(is_equal_approx(Controls.steer(), -1.0), "a 30-degree left tilt is full left lock")
	Controls.tilt_override = null
	Controls.scheme = "stick"


## Each driving layout puts its buttons on screen in a car, the on-foot
## buttons come back after, and a pedal held while getting out lets go.
func test_touch_driving_layouts() -> void:
	await _new_game(false)
	var touch = game.hud.touch
	touch.visible = true
	var window_size := get_window().size
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	var car = _spawn_car(_home(), Vector3(0, 0, 8), 0.0)
	game.player.enter_vehicle(car)
	for scheme in Controls.SCHEMES:
		game.settings["controls"] = scheme
		game.apply_settings()
		await get_tree().process_frame
		_check(touch.driving and touch.scheme == scheme and touch.stick_on() == (scheme == "stick"), "%s layout is up in the car" % scheme)
		var actions: Array = touch.buttons().map(func(b): return b.action)
		_check(actions.has("gas") and actions.has("brake") and actions.has("interact"), "%s layout has GAS, BRAKE and EXIT" % scheme)
		_check(actions.has("steer_left") == (scheme == "arrows"), "%s layout: arrow buttons only in the arrows layout" % scheme)
		var screen := Rect2(Vector2.ZERO, touch.size)
		for b in touch.buttons():
			var ev := InputEventScreenTouch.new()
			ev.index = 2
			ev.position = touch._center(b)
			ev.pressed = true
			touch._input(ev)
			var held := Input.is_action_pressed(b.action)
			ev.pressed = false
			touch._input(ev)
			_check(held and not Input.is_action_pressed(b.action) and screen.has_point(ev.position), "%s layout: %s presses and lets go" % [scheme, b.action])
	# A thumb sliding from one arrow to the other swaps them.
	game.settings["controls"] = "arrows"
	game.apply_settings()
	await get_tree().process_frame
	var left: Dictionary = touch.ARROWS[0]
	var right: Dictionary = touch.ARROWS[1]
	var tap := InputEventScreenTouch.new()
	tap.index = 4
	tap.position = touch._center(left)
	tap.pressed = true
	touch._input(tap)
	var drag := InputEventScreenDrag.new()
	drag.index = 4
	drag.position = touch._center(right)
	touch._input(drag)
	_check(Input.is_action_pressed("steer_right") and not Input.is_action_pressed("steer_left"), "sliding onto the right arrow swaps the wheel")
	tap.position = drag.position
	tap.pressed = false
	touch._input(tap)
	# GAS held while getting out lets go.
	tap.index = 5
	tap.position = touch._center(touch.DRIVE_BUTTONS[0])
	tap.pressed = true
	touch._input(tap)
	_check(Input.is_action_pressed("gas"), "GAS is held")
	game.player.exit_vehicle()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not touch.driving and not Input.is_action_pressed("gas") and touch.stick_on(), "out of the car: GAS let go, on-foot buttons and stick back")
	tap.pressed = false
	touch._input(tap)
	get_window().size = window_size
	await get_tree().process_frame


## A player-driven `kind` at `pos` heading -z turned by `yaw`, at `speed`.
func _player_car(kind: String, pos: Vector3, speed: float, yaw := 0.0):
	var car = _track_car(kind, pos, yaw)
	car.driver = Vehicle.Driver.PLAYER
	car.speed = speed
	car.velocity = -car.global_basis.z * speed
	return car


## A scripted driver (taxis, mission getaways) pinned on a wall backs off and
## finds its way on, and one that ran wide comes back to the line it follows.
func test_scripted_car_gets_unstuck() -> void:
	await _free_game()
	# A post (a kerb prop) right on its line.
	var L = preload("res://scripts/layers.gd")
	var post := StaticBody3D.new()
	post.collision_layer = L.WORLD
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(2, 4, 2)
	post.add_child(shape)
	post.position = Vector3(0.3, 2.0, -8.0)
	add_child(post)
	var car = _track_car("sedan", Vector3.ZERO, 0.0)
	car.drive_path(PackedVector3Array([Vector3(0, 0, -40)]), 0.6)
	var done := [false]
	car.path_done.connect(func(_c): done[0] = true)
	var backed := false
	for f in 600:
		await _frames(1)
		backed = backed or car.speed < -1.0
		if done[0]:
			break
	_check(backed, "the scripted car pinned on a post backs off")
	_check(done[0], "and gets round it to its point (ended at %s)" % car.global_position)
	car.queue_free()
	post.queue_free()
	# Running wide 7 m off a 60 m leg, it closes on the line well before the
	# leg's end (aiming straight at the end, it would meet it only there).
	car = _track_car("sedan", Vector3(0, 0, -47.0), -PI / 2.0)
	car.drive_path(PackedVector3Array([Vector3(-20, 0, -40), Vector3(0, 0, -40), Vector3(60, 0, -40)]), 0.6)
	car.path_index = 2
	var back_at := INF
	for f in 300:
		await _frames(1)
		if absf(car.global_position.z + 40.0) < 1.0:
			back_at = car.global_position.x
			break
	_check(back_at < 40.0, "a car run wide is back on its line by x %.0f" % back_at)
	car.queue_free()
	# A stalled car in its lane: it waits a moment, then passes it.
	var stalled = _track_car("sedan", Vector3(0, 0, -100.0), 0.0)
	car = _track_car("sedan", Vector3(0, 0, -80.0), 0.0)
	car.drive_path(PackedVector3Array([Vector3(0, 0, -90), Vector3(0, 0, -160)]), 0.6)
	done[0] = false
	car.path_done.connect(func(_c): done[0] = true)
	var waited := 0
	for f in 900:
		await _frames(1)
		if car.braking and car.global_position.z > -100.0:
			waited += 1
		if done[0]:
			break
	_check(waited > 60, "it waits behind a stalled car (%.1f s)" % (waited / 60.0))
	_check(done[0] and stalled.global_position.distance_to(Vector3(0, 0, -100.0)) < 1.5, "then goes round it, not through it (ended at %s, the stalled car moved %.1f m)" % [car.global_position, stalled.global_position.distance_to(Vector3(0, 0, -100.0))])
	car.queue_free()
	stalled.queue_free()


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


## Props a car hits (lamps, street trees, hydrants, signals) fall and the
## car keeps most of its speed.
func test_cars_knock_down_roadside_props() -> void:
	# Sachin: "make the side props [destroyable] by car and car wont stop
	# after [destroying] them, right now [the] car stops after hitting the
	# water [hydrant], any small tree or lamppost etc".
	await _new_game(false)
	var city = game.city
	city.stream_now(city.spawn_point)
	Controls.camera = null
	var found := {}
	for cell in city.get_children():
		for body in cell.get_children():
			if not body is StaticBody3D:
				continue
			for c in body.get_children():
				if c is CollisionShape3D and c.has_meta("brk"):
					var kind: String = c.get_meta("brk").kind
					if kind in ["street_light", "hydrant", "street_tree", "traffic_light"] and not found.has(kind):
						found[kind] = c
	_check(found.size() >= 3, "street lights, hydrants and trees near the start can be knocked down (%s)" % [found.keys()])
	for kind in found:
		var shape: CollisionShape3D = found[kind]
		var at: Vector3 = shape.global_position
		at.y = 0.0
		# Head for it from the middle of the nearest street.
		var p := Vector2(at.x, at.z)
		var best := INF
		var road := Vector2.ZERO
		for e in city.plan.edge_count():
			if not city.plan.drivable(e):
				continue
			var q := Geometry2D.get_closest_point_to_segment(p, city.plan.pos(city.plan.edge_a[e]), city.plan.pos(city.plan.edge_b[e]))
			if q.distance_to(p) < best:
				best = q.distance_to(p)
				road = q
		var dir := Vector3(p.x - road.x, 0, p.y - road.y).normalized()
		var start := at - dir * 12.0
		var car = _player_car("sedan", start, 16.0, atan2(-dir.x, -dir.z))
		car.global_position = start
		Controls.override_vector = Vector2(dir.x, dir.z)
		var kept := -1.0
		for f in 90:
			await _frames(1)
			if kept < 0.0 and (car.global_position - at).dot(dir) > 2.5:
				kept = car.speed
				break
		var info: Dictionary = shape.get_meta("brk")
		_check(info.get("down", false) and kept > 11.0,
			"a car at 16 m/s knocks down a %s and drives on at %.1f m/s" % [kind, kept])
		car.queue_free()
		await _frames(2)
	Controls.override_vector = Vector2.ZERO


func test_roads_have_two_lanes_each_way() -> void:
	# Sachin: "4 cars can drive around in the same road at once comfortably,
	# 2 in one lane 2 in opposite lane ... Some parts can have narrow roads,
	# like inner streets, alleys etc, or road to mountains, but [the rest]
	# should be either 4 lane or 6 or 8 lane, 6 and 8 lane [for] major
	# highways and expressways."
	await _new_game(false)
	var city = game.city
	var narrow := ["quarter", "quay", "lane"]
	var bad: Array = []
	for cls in StreetPlan.CLASSES:
		var g: Dictionary = StreetPlan.CLASSES[cls]
		var room: float = g.middle + g.lanes * g.lane_w + g.park
		if room > g.width * 0.5 + 0.01 or (g.lanes > 0 and g.lane_w < 3.2):
			bad.append([cls, "lanes do not fit", room, g.width])
		if not narrow.has(cls) and not g.lanes in [2, 3, 4]:
			bad.append([cls, g.lanes])
	_check(bad.is_empty(), "city streets, avenues and boulevards are 4 or 6 lanes, 3.2 m a lane or more (old town, quay and walks narrow) %s" % [bad])
	var c = city.country
	var want := {"freeway": 4, "highway": 3, "avenue": 2, "street": 2, "road": 1, "lane": 1, "track": 1}
	bad = []
	for g in c.classes:
		if want.has(g.id) and int(g.lanes) != want[g.id]:
			bad.append([g.id, g.lanes])
		if float(g.middle) + float(g.lanes) * float(g.lane_w) + float(g.park) > float(g.w) * 0.5 + 0.01:
			bad.append([g.id, "lanes do not fit"])
	_check(bad.is_empty(), "country: the freeway 8 lanes, highways 6, avenues and streets 4, county roads and tracks 2 %s" % [bad])
	var cls_of := {}
	for r in c.roads:
		cls_of[r.name] = c.classes[r.cls].id
	_check(cls_of.get("Bellerive Beltway") == "freeway" and cls_of.get("Canyon Freeway") == "highway" and cls_of.get("Crest Drive") == "road",
		"the Beltway is the 8-lane freeway, the Canyon Freeway 6 lanes, Crest Drive 2 (%s, %s, %s)" % [cls_of.get("Bellerive Beltway"), cls_of.get("Canyon Freeway"), cls_of.get("Crest Drive")])
	# Parked cars sit in the parking strip, clear of the curb lane.
	var in_lane := 0
	for spot in city.parked_spots.slice(1):
		var p := Vector2(spot[0].x, spot[0].z)
		var best := INF
		var clear := 0.0
		for e in city.plan.edge_count():
			var a: Vector2 = city.plan.pos(city.plan.edge_a[e])
			var b: Vector2 = city.plan.pos(city.plan.edge_b[e])
			var d := Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p)
			if d < best:
				best = d
				var g: Dictionary = StreetPlan.CLASSES[city.plan.edge_class(e)]
				clear = g.middle + g.lanes * g.lane_w
		if best < clear + 0.9:
			in_lane += 1
	_check(city.parked_spots.size() > 50 and in_lane == 0, "parked cars keep out of the lanes (%d of %d in a lane)" % [in_lane, city.parked_spots.size() - 1])
	# Two cars side by side on a 4-lane street both drive on, neither held
	# up by the other.
	var edge := -1
	var best_d := INF
	for e in city.plan.edge_count():
		if city.plan.edge_class(e) in ["street", "avenue"] and city.plan.drivable(e):
			var a: Vector3 = city.node_pos(city.plan.edge_a[e])
			var b: Vector3 = city.node_pos(city.plan.edge_b[e])
			var d := a.distance_to(city.spawn_point)
			if a.distance_to(b) > 90.0 and d < best_d and city.drive_node(city.plan.edge_a[e]) and city.drive_node(city.plan.edge_b[e]):
				best_d = d
				edge = e
	var na: int = city.plan.edge_a[edge]
	var nb: int = city.plan.edge_b[edge]
	var dir: Vector3 = (city.node_pos(nb) - city.node_pos(na)).normalized()
	var right := Vector3(-dir.z, 0, dir.x)
	var pair := []
	for lane in 2:
		var car = Vehicle.new()
		car.kind = "sedan" if lane == 0 else "suv"
		car.city = city
		car.position = city.lane_start(na, nb, lane) + dir * 20.0
		car.rotation.y = atan2(-dir.x, -dir.z)
		car.start_traffic(city, na, nb, lane)
		game.add_child(car)
		pair.append(car)
	var starts := [pair[0].global_position, pair[1].global_position]
	var gap_min := INF
	for f in 150:
		await _frames(1)
		gap_min = minf(gap_min, absf((pair[1].global_position - pair[0].global_position).dot(right)))
	var went := [(pair[0].global_position - starts[0]).dot(dir), (pair[1].global_position - starts[1]).dot(dir)]
	_check(went[0] > 15.0 and went[1] > 15.0 and gap_min > 2.6,
		"two cars abreast on %s drive on (%.0f m and %.0f m in 2.5 s), %.1f m apart at the closest" % [city.plan.edge_class(edge), went[0], went[1], gap_min])


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
	var went := {}
	for car in cars:
		prev[car] = car._next_node
		passed[car] = 0
		went[car] = 0.0
	for f in 1800:
		var was := {}
		for car in cars:
			was[car] = car.global_position
		await _frames(1)
		for car in cars:
			went[car] += car.global_position.distance_to(was[car])
			if car._next_node != prev[car]:
				prev[car] = car._next_node
				passed[car] += 1
	# Three junctions, or a fair distance where the blocks are long (Midtown's
	# are 120 m between avenues).
	for car in cars:
		_check((passed[car] >= 3 or (passed[car] >= 2 and went[car] > 200.0)) and not car.wrecked,
			"traffic %s passed %d junctions, %.0f m in 30 s (wrecked: %s)" % [car.kind, passed[car], went[car], car.wrecked])


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



## The shop menu's panel covers the right-hand buttons' corner: closed, it
## must not swallow their taps (review finding).
func test_shop_menu_leaves_touch_buttons_alone() -> void:
	await _new_game(false)
	var touch = game.hud.touch
	touch.visible = true
	# A phone-shaped screen (the test window is square, where the panel
	# misses the buttons).
	var window_size := get_window().size
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	# Open and shut it once (as at a counter), so its panel has a layout.
	game.interiors.menu.open({"type": "corner_store", "name": "Test Mart"})
	for i in 4:
		await get_tree().process_frame
	game.interiors.menu.close()
	await get_tree().process_frame
	var frame: Rect2 = game.interiors.menu.frame.get_global_rect()
	_check(touch.BUTTONS.any(func(b): return frame.has_point(touch._center(b))), "the panel's area covers a button (else this test proves nothing)")
	for b in touch.BUTTONS:
		var ev := InputEventScreenTouch.new()
		ev.index = 3
		ev.position = touch._center(b)
		ev.pressed = true
		touch._input(ev)
		var held := Input.is_action_pressed(b.action)
		ev.pressed = false
		touch._input(ev)
		_check(held, "%s works with the shop menu shut" % b.label)
	get_window().size = window_size
	await get_tree().process_frame


## A respawn, a new game or a mission start while inside (or while the
## door is fading) puts the street, camera and light back (review finding).
func test_thrown_out_of_a_room() -> void:
	await _new_game(false)
	var ii = game.interiors
	game.atmosphere.hour = 12.0
	var store := _nearest_place("corner_store")
	await _enter(store)
	_check(ii.is_inside(), "inside the store")
	game.restart_story()
	await _frames(2)
	_check(ii.state == ii.State.OUTSIDE and game.city.visible and game.population.process_mode != Node.PROCESS_MODE_DISABLED, "a new game from inside gives the street back")
	_check(game.camera.fixed_focus == null and not game.atmosphere.indoors and get_tree().get_nodes_in_group("patrons").is_empty(), "camera, light and room are reset")
	_check(game.player.global_position.distance_to(ii.ORIGIN) > 500.0 and game.player.controllable, "the player is back in the city and can move")
	# Knocked down on the doorstep while the door fades.
	await _at_door(store)
	while ii._cooldown > 0.0:
		await _frames(1)
	await _press("interact")
	_check(ii.state == ii.State.ENTERING, "going in")
	game.player.take_hit(null, 1000.0, Vector3.ZERO)
	for i in 600:
		if not game.respawning and game.player.controllable and not game.player.dead:
			break
		await _frames(1)
	await _frames(30)
	_check(ii.state == ii.State.OUTSIDE and game.city.visible, "dying at the door leaves you outside, got state %d" % ii.state)
	_check(game.camera.fixed_focus == null and game.player.global_position.distance_to(ii.ORIGIN) > 500.0, "the respawn is on the street")


## Hitting someone eating in a booth: they slide out and leave, and the
## seat is free again (review finding).
func test_hit_diner_leaves_the_booth() -> void:
	await _new_game(false)
	var ii = game.interiors
	game.atmosphere.hour = 12.0
	await _enter(_nearest_place("diner"))
	var victim = null
	for n in get_tree().get_nodes_in_group("patrons"):
		if not n.staff and n.sitting:
			victim = n
			break
	_check(victim != null, "someone is eating")
	if victim == null:
		return
	var seat := -1
	for k in ii._taken:
		if ii._taken[k] == victim:
			seat = k
	var gone := [false]
	victim.left.connect(func(_w): gone[0] = true)
	victim.take_hit(game.player, 1.0, Vector3.ZERO)
	var worst := 0.0
	for i in 1200:
		if gone[0]:
			break
		worst = maxf(worst, victim.stuck_time)
		await _frames(1)
	_check(gone[0], "the diner runs out of the door (stuck %.1f s)" % worst)
	_check(seat >= 0 and not ii._taken.has(seat), "the seat is free again")
	Wanted.clear()
	game.police.clear_all()
	# A knocked-out customer frees their seat and stops counting.
	var other = null
	for n in get_tree().get_nodes_in_group("patrons"):
		if not n.staff and n.sitting:
			other = n
			break
	if other != null:
		other.take_hit(game.player, 1000.0, Vector3.ZERO)
		await _frames(2)
		# Checked on the diner itself: a new customer may walk in meanwhile,
		# so the head count alone races (it failed once in a full run).
		_check(not other.is_in_group("patrons") and other.is_in_group("patrons_out") and not ii._taken.values().has(other), "a knocked-out diner frees the seat")
	Wanted.clear()
	await _leave()


# --- Taxis ----------------------------------------------------------------------

## Hail a cab in the street: the TAXI button shows, the cab pulls over
## beside the player, ENTER gets in the back (no carjacking), the list of
## destinations comes up, the fare is shown, the cab drives the real streets
## to the curb and the player gets out and pays.
func test_taxi_hail_ride_and_pay() -> void:
	await _new_game(false)
	var taxi = game.taxi
	var p = game.player
	game.cash = 100
	var cab = _taxi_in_traffic()
	await _frames(2)
	_check(taxi.hailable_cab() == cab, "a cab with a driver nearby can be hailed")
	_check(taxi._hail_button.visible, "the TAXI button shows")
	await _press("hail")
	_check(taxi.state == taxi.State.PICKUP and cab.driver == Vehicle.Driver.SCRIPT, "T hails it: the cab pulls over")
	await _until(func(): return taxi.state == taxi.State.WAITING, 900)
	_check(taxi.state == taxi.State.WAITING, "the cab stops at the curb")
	_check(cab.global_position.distance_to(p.global_position) < 16.0, "beside the player, %.1f m" % cab.global_position.distance_to(p.global_position))
	await _taxi_board(cab)
	_check(p.vehicle == cab and p.passenger and not p.visible, "ENTER gets in the back")
	_check(cab.driver == Vehicle.Driver.SCRIPT and Wanted.level == 0, "the cabbie keeps driving: not a carjacking")
	_check(p.focus_node() == cab, "the camera follows the cab")
	await _frames(2)
	_check(game.hud.touch.seated and game.hud.touch.buttons().is_empty(), "no driving controls in the back")
	_check(taxi._panel.visible and taxi._panel_mode == "choose", "the destination list comes up")
	var dests: Array = taxi.destinations()
	await _frames(ceili(dests.size() / float(taxi.CHOICE_ROWS)) + 1)
	_check(taxi._panel_body.get_child_count() >= 3, "and fills in over a few frames (%d rows)" % taxi._panel_body.get_child_count())
	_check(dests.size() >= 3, "destinations to pick from, got %d" % dests.size())
	var dest := {}
	for d in dests:
		var plan: Dictionary = taxi.plan_ride(d.pos)
		if not plan.is_empty() and plan.length > 150.0 and plan.length < 900.0:
			dest = d
			break
	_check(not dest.is_empty(), "a destination a short ride away")
	if dest.is_empty():
		return
	var trip: Dictionary = taxi.choose(dest)
	_check(trip.fare == taxi.fare_for(trip.length) and trip.fare >= taxi.PRICES.bellerive.min, "fare from the route length: $%d for %.0f m" % [trip.fare, trip.length])
	_check(taxi._panel_mode == "confirm" and _label_shows(taxi._panel, "$%d" % trip.fare), "the fare is shown before riding")
	_check(game.cash == 100, "nothing paid yet")
	_check(taxi.ride(), "RIDE starts the trip")
	await _frames(2)
	_check(taxi._bar.visible and not taxi._panel.visible, "the ride bar shows while riding")
	_check(game.map_markers().any(func(m): return m.label == "Drop-off"), "the drop-off is on the maps")
	await _until(func(): return taxi.state == taxi.State.IDLE, 4800)
	_check(taxi.state == taxi.State.IDLE, "the ride ends (driven %.0f of %.0f m)" % [taxi.driven, trip.length])
	_check(p.vehicle == null and not p.passenger and p.visible and p.controllable, "out on foot and in control")
	var off: float = Vector2(p.global_position.x - trip.stop.x, p.global_position.z - trip.stop.z).length()
	_check(off < 12.0, "dropped at the destination's curb, %.1f m off" % off)
	_check(game.cash == 100 - trip.fare, "paid $%d on arrival, cash %d" % [trip.fare, game.cash])
	await _frames(60)
	_check(p.knocked_time <= 0.0 and p.health == p.max_health, "the cab doesn't clip you as you get out")
	_check(cab.driver == Vehicle.Driver.SCRIPT and cab.speed == 0.0, "it waits while you stand beside it")
	var away: Vector3 = p.global_position - cab.global_position
	away.y = 0.0
	_place_player_at(p.global_position + away.normalized() * 6.0)
	await _frames(3)
	_check(cab.driver == Vehicle.Driver.TRAFFIC, "then goes back to traffic")


## The phone's Cab app calls a cab out of view; it drives to the player and
## shows on the maps. With a waypoint set it goes there; SKIP fades to the
## curb there at once and costs more than riding.
func test_taxi_phone_call_and_skip() -> void:
	await _new_game(false)
	var taxi = game.taxi
	var p = game.player
	game.cash = 200
	_place_player_at(game.city.spawn_point)
	await _frames(2)
	var phone = game.hud.phone
	phone.open()
	phone._cab()
	var call_button = _find_button(phone._body, "CALL A CAB")
	_check(call_button != null, "the phone has a Cab app with CALL A CAB")
	if call_button == null:
		return
	call_button.pressed.emit()
	_check(not phone.visible and not get_tree().paused, "calling closes the phone")
	_check(taxi.state == taxi.State.PICKUP and taxi.called, "a cab is on its way")
	var cab = taxi.cab
	_check(game.population.out_of_view(cab.global_position), "it sets off out of view")
	_check(game.map_markers().any(func(m): return m.label == "Your cab"), "the cab is on the maps")
	await _until(func(): return taxi.state == taxi.State.WAITING, 3600)
	_check(taxi.state == taxi.State.WAITING, "the called cab arrives")
	var gap: float = cab.global_position.distance_to(p.global_position)
	_check(gap < 16.0, "at the curb by the player, %.1f m" % gap)
	var far: int = _taxi_far_node(500.0)
	game.waypoint = game.city.node_pos(far)
	# Another car stopped right where the player stands: the waiting cab
	# still wins (no carjacking a passer-by).
	var other = null
	for v in get_tree().get_nodes_in_group("vehicles"):
		if v != cab and not v.wrecked:
			other = v
			break
	if other != null:
		other.global_position = cab.global_position + cab.global_basis.x * 3.6
		other.reset_physics_interpolation()
	await _taxi_board(cab)
	_check(p.vehicle == cab, "boarding takes the waiting cab, not the car beside it")
	_check(taxi.state == taxi.State.CHOOSING and taxi.trip.get("name") == "Waypoint", "with a waypoint set, that is where it goes")
	var fare: int = taxi.trip.fare
	var stop: Vector3 = taxi.trip.stop
	_check(taxi.skip_fare(fare) > fare, "skipping costs more ($%d vs $%d)" % [taxi.skip_fare(fare), fare])
	_check(taxi.skip(), "SKIP")
	await _frames(5)
	_check(taxi._fade.visible and not p.controllable, "the screen fades")
	await _until(func(): return taxi.state == taxi.State.IDLE, 200)
	var off: float = Vector2(p.global_position.x - stop.x, p.global_position.z - stop.z).length()
	_check(p.vehicle == null and off < 6.0, "out at the waypoint's curb, %.1f m off" % off)
	_check(game.cash == 200 - taxi.skip_fare(fare), "paid the skip fare, cash %d" % game.cash)
	_check(p.controllable and taxi._fade_alpha == 0.0 and not taxi._fade.visible, "faded back in and in control")


## Wanted: no cab stops, none comes by phone, and a cab you're in throws
## you out. Not enough cash: the cabbie won't drive.
func test_taxi_refuses_wanted_and_broke() -> void:
	await _new_game(false)
	var taxi = game.taxi
	var p = game.player
	var cab = _taxi_in_traffic()
	Wanted.report_crime(1)
	await _frames(2)
	_check(taxi.hailable_cab() == null and not taxi._hail_button.visible, "no TAXI button while wanted")
	_check(not taxi.hail() and cab.driver == Vehicle.Driver.TRAFFIC, "a hail is ignored while wanted")
	_check(taxi.call_cab() != "" and taxi.state == taxi.State.IDLE, "no cab comes by phone while wanted")
	Wanted.clear()
	game.cash = 2
	_check(taxi.hail(), "hailed once the heat is off")
	await _until(func(): return taxi.state == taxi.State.WAITING, 900)
	await _taxi_board(cab)
	var dest: Dictionary = taxi.destinations()[0]
	var trip: Dictionary = taxi.choose(dest)
	_check(not trip.is_empty() and trip.fare > 2, "a fare the player can't pay")
	_check(not taxi.ride() and not taxi.skip(), "no ride and no skip without the cash")
	_check(taxi.state == taxi.State.CHOOSING and game.cash == 2, "still at the curb, nothing taken")
	var ride_button = _find_button(taxi._panel_body, "RIDE")
	_check(ride_button != null and ride_button.disabled, "RIDE is greyed out")
	_check(_label_shows(taxi._panel, "Walk, friend"), "the cabbie says so")
	game.cash = 100
	_check(taxi.ride(), "rides once there is cash")
	await _frames(90)
	Wanted.report_crime(1)
	await _frames(3)
	_check(p.vehicle == null and not p.passenger and taxi.state == taxi.State.IDLE, "wanted: thrown out of the cab")
	_check(game.cash == 100 and p.controllable, "no fare taken, in control")
	Wanted.clear()


## Getting out early pays the fare so far; a wreck drops you off free; a
## mission starting or the player dying ends the ride and hands back control.
func test_taxi_ride_ends_cleanly() -> void:
	await _new_game(false)
	var taxi = game.taxi
	var p = game.player
	game.cash = 100
	# Out early: the cab pulls up, the meter is paid.
	await _taxi_ride_far()
	await _frames(240)
	var fare: int = taxi.trip.fare
	taxi.request_exit()
	_check(taxi.state == taxi.State.STOPPING, "GET OUT: the cab pulls up")
	await _until(func(): return taxi.state == taxi.State.IDLE, 300)
	var paid: int = 100 - game.cash
	_check(p.vehicle == null and p.controllable, "out early and in control")
	_check(paid >= taxi.PRICES.bellerive.base and paid < fare, "paid the fare so far: $%d of $%d" % [paid, fare])
	await _frames(60)
	_check(p.knocked_time <= 0.0 and p.health == p.max_health, "stepping out of a cab that just pulled up is safe")
	# A wreck: dropped off, no charge.
	game.cash = 100
	await _taxi_ride_far()
	await _frames(60)
	taxi.cab._damage(10000.0)
	await _frames(2)
	_check(p.vehicle == null and taxi.state == taxi.State.IDLE and game.cash == 100, "a wrecked cab drops you off free")
	# A mission starting ends the ride.
	await _taxi_ride_far()
	await _frames(30)
	var job := Node.new()
	game.missions.active = job
	await _frames(2)
	_check(p.vehicle == null and taxi.state == taxi.State.IDLE and p.controllable, "a mission start ends the ride")
	game.missions.active = null
	job.free()
	# Dying in the back: out, and back in control after the respawn.
	await _taxi_ride_far()
	await _frames(30)
	p.take_hit(null, 999.0, Vector3.ZERO)
	await _frames(3)
	_check(p.dead and p.vehicle == null and taxi.state == taxi.State.IDLE, "death ends the ride")
	await _frames(200)
	_check(not p.dead and p.controllable and p.vehicle == null and not p.passenger, "respawned on foot and in control")
	_check(game.cash == 100, "no fare for the dead")


## A taxi in traffic on a long street near Union Station, coming up to the
## player standing on the sidewalk about 12 m ahead of it.
func _taxi_in_traffic():
	var city = game.city
	# Earlier cabs (and wrecks) out of the way.
	for v in get_tree().get_nodes_in_group("vehicles"):
		if v.kind == "taxi":
			v.remove_from_group("vehicles")
			v.queue_free()
	var ends := _taxi_street()
	var a: int = ends[0]
	var b: int = ends[1]
	var pa: Vector3 = city.node_pos(a)
	var dir: Vector3 = (city.node_pos(b) - pa).normalized()
	var side: Vector3 = (city.lane_point(a, b) - city.node_pos(b)).normalized()
	var cab = Vehicle.new()
	cab.kind = "taxi"
	cab.city = city
	cab.position = city.lane_start(a, b) + dir * 12.0
	cab.rotation.y = atan2(-dir.x, -dir.z)
	cab.start_traffic(city, a, b)
	game.add_child(cab)
	_place_player_at(pa + dir * 24.0 + side * 7.0)
	return cab


## A street of 70 m or more near the spawn: [from, to].
func _taxi_street() -> Array:
	var city = game.city
	var near: Array = [_home()]
	for n in city.next_nodes(_home()):
		near.append(n)
	for n in near.duplicate():
		near.append_array(city.next_nodes(n))
	for n in near:
		for m in city.next_nodes(n):
			if city.node_pos(n).distance_to(city.node_pos(m)) > 70.0:
				return [n, m]
	return [_home(), city.next_nodes(_home())[0]]


## A junction about `dist` m (straight line) from the player.
func _taxi_far_node(dist: float) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	return game.city.random_node_between(game.player.global_position, dist, dist + 150.0, rng)


## Steps up to the waiting cab and gets in.
func _taxi_board(cab) -> void:
	var p = game.player
	p.global_position = cab.global_position + cab.global_basis.x * 2.4
	p.reset_physics_interpolation()
	await _frames(2)
	await _press("interact")


## Hails a fresh cab, boards it and sets off for a waypoint about 600 m away.
func _taxi_ride_far() -> void:
	var taxi = game.taxi
	var cab = _taxi_in_traffic()
	await _frames(2)
	taxi.hail()
	await _until(func(): return taxi.state == taxi.State.WAITING, 900)
	game.waypoint = game.city.node_pos(_taxi_far_node(600.0))
	await _taxi_board(cab)
	game.waypoint = null
	_check(taxi.ride() and game.player.vehicle == cab, "set off in a hailed cab")


## Runs frames until `cond` holds (or `limit` frames pass).
func _until(cond: Callable, limit: int) -> void:
	for i in limit:
		if cond.call():
			return
		await _frames(1)


func _find_button(root: Node, prefix: String):
	for c in root.find_children("*", "Button", true, false):
		if c.text.begins_with(prefix):
			return c
	return null


func _label_shows(root: Node, text: String) -> bool:
	for c in root.find_children("*", "Label", true, false):
		if text in c.text:
			return true
	return false


# --- Country (phase 2) -----------------------------------------------------------

## The country's roads join the street plan at its frame junctions and the
## city's road API answers for both: the GPS drives from Union Station out
## to Wheaton, landmarks and towns are on the maps and in the taxi list.
func test_country_joins_the_city() -> void:
	await _new_game(false)
	var city = game.city
	var c = city.country
	_check(c != null and c.node_count() > 1000, "the country has a road graph")
	_check(c.links.size() >= 20, "country roads join the plan at many junctions, got %d" % c.links.size())
	var bad := 0
	for n in c.links:
		var pn: int = c.links[n]
		if not city.drive_node(pn) or c.pos(n).distance_to(city.plan.pos(pn)) > 6.0 or not (city.COUNTRY_BASE + n) in city.next_nodes(pn) or not pn in city.next_nodes(city.COUNTRY_BASE + n):
			bad += 1
	_check(bad == 0, "every link joins a drivable plan junction within 6 m, both ways, %d bad" % bad)
	# Streets run on out of the city to a major road (Sachin: "most of the
	# roads are reaching the city end to end and then joining the highways
	# ... they should not end abruptly"): the city's streets that meet the
	# frame street carry on out, and no road round the city stops dead
	# short of the play area's edge.
	var plan = city.plan
	var on_frame := {}
	var inward := {}
	for e in plan.edge_count():
		for n in [plan.edge_a[e], plan.edge_b[e]]:
			if plan.edge_road[e] == "frame":
				on_frame[n] = on_frame.get(n, 0) + 1
			elif plan.drivable(e):
				inward[n] = true
	var linked_to := {}
	for n in c.links:
		linked_to[c.links[n]] = true
	var meets := 0
	var carried := 0
	for n in on_frame:
		if on_frame[n] == 2 and inward.has(n):
			meets += 1
			carried += 1 if linked_to.has(n) else 0
	_check(meets > 40 and carried == meets, "every city street that meets the frame carries on out past it (%d of %d)" % [carried, meets])
	# The suburbs and the coast road, to the Beltway and past it; farm lanes
	# and tracks may end at a field, and a road at a drive that carries on
	# to its lot (Observatory Road at the observatory's forecourt).
	var near_city: Rect2 = plan.bounds.grow(1100.0)
	var drives: Array = []
	for path in c.paths:
		drives.append(Vector2(path[1][0], path[1][1]))
	var dead: Array = []
	for n in c.node_count():
		var p: Vector2 = c.pos(n)
		if c.degree(n) != 1 or c.links.has(n) or not near_city.has_point(p):
			continue
		if c.edge_class(c.edges_of(n)[0]) in ["lane", "track"]:
			continue
		if drives.any(func(q): return q.distance_to(p) < 1.0):
			continue
		var inside := true
		for d in [Vector2(25, 0), Vector2(-25, 0), Vector2(0, 25), Vector2(0, -25)]:
			inside = inside and c.in_play_area(p + d)
		if inside:
			dead.append(Vector2i(p))
	_check(dead.is_empty(), "no road round the city stops dead (%s)" % [dead])
	var wheaton: Vector3 = city.taxi_destinations().filter(func(d): return d.id == "wheaton")[0].pos
	var path: PackedInt64Array = city.route_nodes(city.spawn_point, wheaton)
	_check(path.size() > 20, "a route runs from Union Station to Wheaton (%d junctions)" % path.size())
	_check(not path.is_empty() and path[0] < city.COUNTRY_BASE and path[path.size() - 1] >= city.COUNTRY_BASE, "it starts in the plan and ends in the country")
	var off_road := 0
	for k in range(1, path.size()):
		off_road += 0 if path[k] in city.next_nodes(path[k - 1]) else 1
	_check(off_road == 0, "every step of the route follows a road, %d do not" % off_road)
	_check(city.district_at(wheaton).name == "Wheaton", "Wheaton is a district on the banner")
	_check(city.playable(Vector2(wheaton.x, wheaton.z)) and not city.playable(Vector2(-20000, 0)), "the play area holds Wheaton, not the far state")
	var ids: Array = city.landmarks().map(func(l): return l.id)
	for id in ["deco_row", "bellerive_general", "hollis_farm", "union_station"]:
		_check(id in ids, "landmark %s is on the maps" % id)
	_check(city.landmark_front("deco_row") != Vector3.INF, "a country landmark has a front for missions and taxis")


## Country tiles stream in round the player, as one mesh plus collisions,
## and go when the player leaves; the city's window walls are gone.
func test_country_tiles_stream() -> void:
	await _new_game(false)
	var city = game.city
	var c = city.country
	_check(city.get_node_or_null("Bounds") == null, "no walls round the window")
	var at: Vector3 = city.landmark_front("deco_row")
	_place_player_at(at)
	await _frames(240)
	var key: Vector2i = c.tile_key(at)
	var tile: Node3D = c.tile_node(key)
	_check(tile != null, "the tile under the player streams in")
	_check(c.loaded_tiles().size() >= 4, "tiles round the player are built, got %d" % c.loaded_tiles().size())
	if tile != null:
		var meshes := tile.get_children().filter(func(n): return n is MeshInstance3D and n.name != "Glow")
		_check(meshes.size() == 1, "a tile draws as one mesh (plus its glow)")
		_check(tile.get_children().any(func(n): return n is StaticBody3D), "a tile has collisions")
	var built := 0
	for k in c.loaded_tiles():
		built += c.tile_node(k).get_meta("buildings", 0)
	_check(built > 0, "Brisa Beach has buildings, got %d" % built)
	_place_player_at(city.spawn_point)
	await _frames(240)
	_check(c.tile_node(key) == null, "far tiles are unloaded")


## Banks, the coast and the play area's fence are walls: a car driven at
## one stops on the land side.
func test_country_walls_stop_cars() -> void:
	await _new_game(false)
	var city = game.city
	var c = city.country
	for kind in [0, 2]:
		var w: Array = []
		for cand in c.walls:
			var a := Vector2(cand[0], cand[1])
			var b := Vector2(cand[2], cand[3])
			if int(cand[4]) == kind and a.distance_to(b) > 15.0 and c.road_distance((a + b) * 0.5, 60.0) > 25.0:
				w = cand
				break
		_check(not w.is_empty(), "found a wall of kind %d" % kind)
		if w.is_empty():
			continue
		var a := Vector2(w[0], w[1])
		var b := Vector2(w[2], w[3])
		var m := (a + b) * 0.5
		var n := (b - a).normalized().orthogonal()
		if c.in_play_area(m + n * 3.0):
			n = -n # n points out of the play area
		var start := Vector3(m.x - n.x * 14.0, 0.0, m.y - n.y * 14.0)
		city.stream_now(start)
		var car = Vehicle.new()
		car.city = city
		car.position = start
		car.rotation.y = atan2(-n.x, -n.y)
		game.add_child(car)
		_place_player_at(start + Vector3(n.y, 0, -n.x) * 3.0)
		await _frames(4)
		await _press("interact")
		_check(game.player.vehicle == car, "player gets in the car by wall %d" % kind)
		Controls.override_vector = Vector2(n.x, n.y)
		await _frames(240)
		Controls.override_vector = null
		var p: Vector3 = car.global_position
		var past := (Vector2(p.x, p.z) - m).dot(n)
		_check(past < 0.5, "the car stays on the land side of wall %d (%.1f m past)" % [kind, past])
		_check(Vector2(p.x, p.z).distance_to(m) < 5.0, "and it drove up to the wall (%.1f m away)" % Vector2(p.x, p.z).distance_to(m))
		await _press("interact")
		car.queue_free()
		await _frames(2)


## Traffic drives from a frame junction out on to the country roads and
## keeps to them.
func test_traffic_drives_into_the_country() -> void:
	await _new_game(false)
	var city = game.city
	var c = city.country
	var cn: int = c.links.keys()[0]
	var pn: int = c.links[cn]
	var start_node: int = city.COUNTRY_BASE + cn
	var nxt: int = city.next_nodes(start_node).filter(func(m): return m != pn)[0]
	city.stream_now(city.node_pos(start_node))
	var car = _spawn_car(start_node, Vector3.ZERO, 0.0)
	car.position = city.lane_start(start_node, nxt)
	var d: Vector3 = city.node_pos(nxt) - city.node_pos(start_node)
	car.rotation.y = atan2(-d.x, -d.z)
	car.start_traffic(city, start_node, nxt)
	car.driver = Vehicle.Driver.TRAFFIC
	_place_player_at(car.position + Vector3(0, 0, 20))
	var worst := 0.0
	var moved := 0.0
	var last: Vector3 = car.global_position
	for i in 20:
		await _frames(30)
		var q: Vector3 = car.global_position
		moved += q.distance_to(last)
		last = q
		if not city.plan.bounds.has_point(Vector2(q.x, q.z)):
			worst = maxf(worst, c.road_distance(Vector2(q.x, q.z), 60.0))
	_check(moved > 60.0, "traffic car drives on (%.1f m in 10 s)" % moved)
	_check(worst < 1.0, "it keeps to the country roads (worst %.1f m off the edge)" % worst)


## Traffic heading for a storm barricade turns round short of it (the road's
## last stretch, past the barricade, is out of the drive graph), and every
## junction traffic may use can be routed to from the city.
func test_traffic_turns_round_at_barricades() -> void:
	await _new_game(false)
	var city = game.city
	var c = city.country
	# Every barricade has a cut-off road end just behind it, and no junction
	# traffic uses is within a car's turning room of it.
	var bad: Array = []
	for bi in c.barricades.size():
		var p := Vector2(c.barricades[bi][0], c.barricades[bi][1])
		var stub := false
		for n in c.nodes_near(p, 12.0):
			stub = stub or (c.degree(n) == 1 and c.usable[n] == 0)
		var room := INF
		for n in c.nodes_near(p, 30.0):
			if c.usable[n] == 1:
				room = minf(room, c.pos(n).distance_to(p))
		if not stub or room < 6.0:
			bad.append("#%d (stub %s, nearest usable %.1f m)" % [bi, stub, room])
	_check(bad.is_empty(), "every barricade's road end is cut off with room to turn: %s" % ", ".join(bad))
	var from: Vector3 = city.node_pos(city.COUNTRY_BASE + c.links.keys()[0])
	var unrouted := 0
	var tried := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	while tried < 25:
		var n: int = rng.randi() % c.node_count()
		if c.usable[n] == 0:
			continue
		tried += 1
		if city.route_nodes(from, city.node_pos(city.COUNTRY_BASE + n)).is_empty():
			unrouted += 1
	_check(unrouted == 0, "routes reach usable country junctions (%d of %d did not)" % [unrouted, tried])
	for bi in [0, 4]: # 4 sits under 10 m from the simplified area outline
		var b: Array = c.barricades[bi]
		var bp := Vector2(b[0], b[1])
		# The new dead end nearest the barricade, and the junction before it.
		var a := -1
		for n in c.nodes_near(bp, 120.0):
			if c.usable[n] == 1 and (a < 0 or c.pos(n).distance_to(bp) < c.pos(a).distance_to(bp)):
				a = n
		_check(a >= 0, "barricade %d has a usable junction near it" % bi)
		if a < 0:
			continue
		var back := -1
		for m in c.neighbours(a):
			if c.usable[m] == 1:
				back = m
		var start_node: int = city.COUNTRY_BASE + (back if back >= 0 else a)
		var aim: int = city.COUNTRY_BASE + a
		city.stream_now(city.node_pos(start_node))
		var car = _spawn_car(start_node, Vector3.ZERO, 0.0)
		if back >= 0:
			car.position = city.lane_start(start_node, aim)
			var dd: Vector3 = city.node_pos(aim) - city.node_pos(start_node)
			car.rotation.y = atan2(-dd.x, -dd.z)
			car.start_traffic(city, start_node, aim)
		else:
			car.start_traffic(city, start_node, city.next_nodes(start_node)[0])
		car.driver = Vehicle.Driver.TRAFFIC
		_place_player_at(car.position + Vector3(0, 0, 20))
		var nearest := INF
		for f in 20:
			await _frames(30)
			city.stream_now(car.global_position)
			nearest = minf(nearest, Vector2(car.global_position.x, car.global_position.z).distance_to(bp))
		var end := Vector2(car.global_position.x, car.global_position.z).distance_to(bp)
		_check(nearest > 4.0 and end > nearest + 25.0, "traffic turns round short of barricade %d (closest %.1f m, %.1f m away after 10 s)" % [bi, nearest, end])
		car.queue_free()
		await _frames(2)


## Every countryside kind builds at its footprint and on lots 30% smaller and
## bigger: it draws something within budget, stays on its lot, and its
## colliders sit on the lot (1 m slack) with positive, finite sizes.
func test_country_kit_builds_every_kind() -> void:
	var Kit = preload("res://scripts/kits/country_kit.gd")
	var MB = preload("res://scripts/mesh_builder.gd")
	_check(Kit.KINDS.size() >= 41, "country kit lists its kinds, got %d" % Kit.KINDS.size())
	# Each kind at its footprint, 0.7x and 1.3x, and at every lot size the
	# country data gives it.
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/country.json"))
	var lot_sizes := {}
	for lot: Array in data.lots:
		var sizes: Array = lot_sizes.get_or_add(data.kinds[int(lot[5])], [])
		var ls := Vector2(lot[3], lot[4])
		if not sizes.has(ls):
			sizes.append(ls)
	var problems: Array[String] = []
	for kind: String in Kit.KINDS:
		var f: Vector2 = Kit.footprint(kind)
		if not (f.x > 0.0 and f.y > 0.0):
			problems.append("%s: footprint %s" % [kind, f])
			continue
		for size: Vector2 in [f, f * 0.7, f * 1.3] + lot_sizes.get(kind, []):
			var mb = MB.new()
			var out: Array = []
			var rng := RandomNumberGenerator.new()
			rng.seed = 99
			Kit.build(kind, mb, out, size, rng)
			var tris: int = mb.triangle_count()
			var tag := "%s %.1fx%.1f" % [kind, size.x, size.y]
			if tris <= 0 or tris > (5000 if f.x * f.y < 5000.0 else 8000):
				problems.append("%s: %d triangles" % [tag, tris])
			var hx := size.x * 0.5 + 1.0
			var hz := size.y * 0.5 + 1.0
			for col in out:
				var c: Vector3 = col[0]
				var s: Vector3 = col[1]
				var yaw: float = col[2] if col.size() > 2 else 0.0
				if not (c.is_finite() and s.is_finite() and is_finite(yaw)):
					problems.append("%s: NaN collider %s" % [tag, col])
				elif s.x <= 0.0 or s.y <= 0.0 or s.z <= 0.0:
					problems.append("%s: collider size %s" % [tag, s])
				elif absf(c.x) > hx or absf(c.z) > hz:
					problems.append("%s: collider at %s off the lot" % [tag, c])
			for v: Vector3 in mb.verts:
				if not v.is_finite() or absf(v.x) > hx or absf(v.z) > hz:
					problems.append("%s: vertex %s off the lot" % [tag, v])
					break
	for p in problems.slice(0, 10):
		print("  " + p)
	_check(problems.is_empty(), "every country kind builds on its lot (%d problems)" % problems.size())
	# Lawn and yard lots are fenced: a run along the back edge of each, and
	# no house, tree trunk or car stands in a fence, over sizes and seeds;
	# on the farm homes no two solid parts overlap.
	var fenced := ["farmhouse", "farmhouse_big", "farmhouse_small", "ranch_house", "adobe_farmhouse",
		"trailer_home", "house", "mansion", "town_hall", "garden_apartments", "police_station",
		"county_hospital", "airstrip_hangar", "hollis_farm", "larkspur_vineyard", "bellerive_general"]
	var clashes: Array[String] = []
	for kind: String in fenced:
		var f: Vector2 = Kit.footprint(kind)
		for size: Vector2 in [f, f * 0.7, f * 1.3] + lot_sizes.get(kind, []):
			for seed in 6:
				var out: Array = []
				var rng := RandomNumberGenerator.new()
				rng.seed = seed
				Kit.build(kind, MB.new(), out, size, rng)
				var runs: Array[Rect2] = []
				var solids: Array[Rect2] = []
				var back := false
				for col in out:
					var c: Vector3 = col[0]
					var s: Vector3 = col[1]
					var yaw: float = col[2] if col.size() > 2 else 0.0
					var e := Vector2(absf(cos(yaw)) * s.x + absf(sin(yaw)) * s.z, absf(sin(yaw)) * s.x + absf(cos(yaw)) * s.z) * 0.5
					var r := Rect2(Vector2(c.x, c.z) - e, e * 2.0)
					var thin := minf(e.x, e.y) * 2.0
					var along_x := e.x > e.y
					var at_edge := absf(c.z) > size.y * 0.5 - 1.6 if along_x else absf(c.x) > size.x * 0.5 - 1.0
					if thin <= 0.9 and maxf(e.x, e.y) * 2.0 >= 1.5 and s.y <= 2.0 and at_edge:
						runs.append(r)
						if along_x and c.z > size.y * 0.5 - 1.0 and e.x * 2.0 > size.x * 0.6:
							back = true
					elif thin >= 0.6:
						solids.append(r)
				var tag := "%s %.1fx%.1f seed %d" % [kind, size.x, size.y, seed]
				if not back:
					clashes.append("%s: no fence along the back" % tag)
				for a in runs:
					for b in solids:
						if a.grow(-0.02).intersects(b.grow(-0.02)):
							clashes.append("%s: fence %s through %s" % [tag, a, b])
				# On the farm homes nothing solid stands inside anything else
				# either (a tree trunk in the kitchen, a car in the porch).
				if kind.contains("farmhouse") or kind == "ranch_house":
					for i in solids.size():
						for j in range(i + 1, solids.size()):
							if solids[i].grow(-0.05).intersects(solids[j].grow(-0.05)):
								clashes.append("%s: %s inside %s" % [tag, solids[i], solids[j]])
	for p in clashes.slice(0, 10):
		print("  " + p)
	_check(clashes.is_empty(), "lawn lots are fenced and nothing solid stands in a fence (%d problems)" % clashes.size())
	var rng := RandomNumberGenerator.new()
	var a = MB.new()
	var b = MB.new()
	rng.seed = 5
	Kit.build("hollis_farm", a, [], Kit.footprint("hollis_farm"), rng)
	rng.seed = 5
	Kit.build("hollis_farm", b, [], Kit.footprint("hollis_farm"), rng)
	_check(a.verts == b.verts, "country kinds are deterministic from the rng")


## The nearest country road edge to p: [distance past its kerb line, unit
## direction of the road there], or [] with none within a tile. The
## direction blends into the next edge's across a bend (not a corner), so a
## lot on a curve compares with the curve, not the chord.
func _nearest_road_edge(c, p: Vector2) -> Array:
	var key := Vector2i(floori(p.x / c.tile_size), floori(p.y / c.tile_size))
	var best := INF
	var pick := -1
	for gx in range(key.x - 1, key.x + 2):
		for gy in range(key.y - 1, key.y + 2):
			var t: Dictionary = c.tiles.get(Vector2i(gx, gy), {})
			for e in t.get("r", []):
				var a: Vector2 = c.node_pos[c.edge_a[int(e)]]
				var b: Vector2 = c.node_pos[c.edge_b[int(e)]]
				var dd := p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) - float(c.classes[c.edge_cls[int(e)]].w) * 0.5
				if dd < best and a.distance_to(b) > 0.1:
					best = dd
					pick = int(e)
	if pick < 0:
		return []
	var a: Vector2 = c.node_pos[c.edge_a[pick]]
	var b: Vector2 = c.node_pos[c.edge_b[pick]]
	var u := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
	var dir := _node_tangent(c, c.edge_a[pick], pick).lerp(_node_tangent(c, c.edge_b[pick], pick), u).normalized()
	return [best, dir]


func _node_tangent(c, n: int, e: int) -> Vector2:
	var t: Vector2 = (c.node_pos[c.edge_b[e]] - c.node_pos[c.edge_a[e]]).normalized()
	var around: PackedInt32Array = c.edges_of(n)
	if around.size() != 2:
		return t
	var o: int = around[0] if around[1] == e else around[1]
	var u: Vector2 = (c.node_pos[c.edge_b[o]] - c.node_pos[c.edge_a[o]]).normalized()
	if u.dot(t) < 0.0:
		u = -u
	return t if u.dot(t) < 0.87 else (t + u).normalized()


## How far (degrees) a lot or plot [x, y, yaw, w, d, ...] is turned off the
## road its front edge stands on, or -1 when no road runs along its front.
func _turn_off_road(c, l: Array) -> float:
	var yaw := float(l[2])
	var front := Vector2(l[0], l[1]) + Vector2(-sin(yaw), -cos(yaw)) * float(l[4]) * 0.5
	var near := _nearest_road_edge(c, front)
	if near.is_empty() or near[0] > 8.0:
		return -1.0
	var ax := Vector2(cos(yaw), -sin(yaw))
	return rad_to_deg(asin(minf(1.0, absf(ax.cross(near[1])))))


## Every lot and plot on a road runs square to it (Sachin, 2026-10-27: "all
## plots are sold parallely"); buildings turned off their plot stand only in
## estates and clusters; a plot's lots stay inside it.
func test_country_plots_square_to_their_roads() -> void:
	await _new_game(false)
	var c = game.city.country
	var counts := {}
	for p: Array in c.plots:
		var ty: String = c.plot_types[int(p[5])]
		counts[ty] = counts.get(ty, 0) + 1
	_check(counts.get("estate", 0) >= 10 and counts.get("cluster", 0) >= 40 and counts.get("farmyard", 0) >= 10 and counts.get("field", 0) >= 500,
			"the country has estates, clusters, farmyards and fields, got %s" % counts)
	var worst_lot := 0.0
	var fronting := 0
	for l: Array in c.lots:
		if int(l[8]) >= 0 or l[7] == "sand":
			continue
		var off := _turn_off_road(c, l)
		if off >= 0.0:
			fronting += 1
			worst_lot = maxf(worst_lot, off)
	_check(fronting > 1000 and worst_lot < 4.0, "%d lots on a road are square to it, worst %.1f deg" % [fronting, worst_lot])
	var hollis: Dictionary = c.landmark("hollis_farm")
	_check(not hollis.is_empty() and _turn_off_road(c, c.lots[c._lot_by_id["hollis_farm"]]) < 4.0, "the Hollis farm faces its road square on")
	var worst_plot := 0.0
	for p: Array in c.plots:
		var off := _turn_off_road(c, p)
		worst_plot = maxf(worst_plot, off)
	_check(worst_plot < 5.0, "plots on a road are square to it, worst %.1f deg" % worst_plot)
	var turned_outside := 0
	var outside := 0
	for l: Array in c.lots:
		var k := int(l[8])
		if k < 0:
			continue
		var p: Array = c.plots[k]
		var ty: String = c.plot_types[int(p[5])]
		var turn := absf(wrapf(float(l[2]) - float(p[2]), -PI, PI))
		if turn > 0.02 and not ty in ["estate", "cluster"]:
			turned_outside += 1
		# Every corner of the lot within a metre of the plot's edge.
		var py := float(p[2])
		var ly := float(l[2])
		for sx: float in [-0.5, 0.5]:
			for sz: float in [-0.5, 0.5]:
				var cx := sx * float(l[3])
				var cz := sz * float(l[4])
				var r := Vector2(float(l[0]) - float(p[0]) + cx * cos(ly) + cz * sin(ly), float(l[1]) - float(p[1]) - cx * sin(ly) + cz * cos(ly))
				var lx := r.x * cos(py) - r.y * sin(py)
				var lz := r.x * sin(py) + r.y * cos(py)
				if absf(lx) > float(p[3]) * 0.5 + 1.0 or absf(lz) > float(p[4]) * 0.5 + 1.0:
					outside += 1
	_check(turned_outside == 0, "only estates and clusters hold turned buildings, %d others" % turned_outside)
	_check(outside == 0, "every plot's lots stand inside it, %d do not" % outside)


## Estates have walls or hedges, a gate and gardens, courts or orchards round
## the house, and some houses turn to a view; clusters hold several homes at
## uneven turns; a tile with an estate builds with its walls solid.
func test_estates_and_clusters() -> void:
	await _new_game(false)
	var c = game.city.country
	var Tiles = preload("res://scripts/country_tiles.gd")
	var bare := 0
	var estates := 0
	var turned := 0
	var hale := -1
	var tennis := 0
	for i in c.plots.size():
		var p: Array = c.plots[i]
		var ty: String = c.plot_types[int(p[5])]
		var kinds := {}
		for part: Array in p[6]:
			kinds[c.part_kinds[int(part[0])]] = true
		var homes: Array = []
		for l: Array in c.lots:
			if int(l[8]) == i:
				homes.append(l)
		if ty == "estate":
			estates += 1
			tennis += 1 if kinds.has("tennis") else 0
			var grounds := kinds.has("parterre") or kinds.has("tennis") or kinds.has("court") or kinds.has("orchard")
			if not ((kinds.has("wall") or kinds.has("hedge")) and kinds.has("gate") and kinds.has("drive") and grounds and homes.size() == 1):
				bare += 1
			for l: Array in homes:
				if absf(wrapf(float(l[2]) - float(p[2]), -PI, PI)) > 0.5:
					turned += 1
				if l[6] == "hale_estate":
					hale = i
		elif ty == "cluster":
			if homes.size() < 2 or not kinds.has("yard"):
				bare += 1
	_check(estates >= 10 and bare == 0, "%d estates and every cluster are laid out, %d bare" % [estates, bare])
	_check(turned >= 1, "an estate house turns to its view, got %d" % turned)
	_check(tennis * 3 >= estates, "a third of the estates have a tennis court, %d of %d" % [tennis, estates])
	_check(hale >= 0, "the Hale Estate stands in grounds of its own")
	var spread := 0.0
	for l: Array in c.lots:
		var k := int(l[8])
		if k >= 0 and c.plot_types[int(c.plots[k][5])] == "cluster":
			spread = maxf(spread, absf(wrapf(float(l[2]) - float(c.plots[k][2]), -PI * 0.25, PI * 0.25)))
	_check(spread > deg_to_rad(10.0), "cluster homes stand at uneven turns, widest %.0f deg" % rad_to_deg(spread))
	if hale >= 0:
		var p: Array = c.plots[hale]
		var key := Vector2i(floori(float(p[0]) / c.tile_size), floori(float(p[1]) / c.tile_size))
		var built: Dictionary = preload("res://scripts/country_tiles.gd").build(c, key)
		var cols: Array = built.colliders
		var bad := cols.filter(func(col): return not (col[0].is_finite() and col[1].is_finite() and is_finite(col[2])))
		_check(bad.is_empty() and cols.size() > 20, "the Hale Estate's tile builds with %d sound colliders" % cols.size())
		# The boundary wall: long colliders lying along the plot's edges, square to it.
		var py := float(p[2])
		var on_edge := func(col) -> bool:
			if not (col[1].x > 20.0 and col[1].y > 1.5 and col[1].y < 2.0):
				return false
			var r := Vector2(col[0].x - float(p[0]), col[0].z - float(p[1]))
			var lx := r.x * cos(py) - r.y * sin(py)
			var lz := r.x * sin(py) + r.y * cos(py)
			var edge := minf(absf(absf(lx) - float(p[3]) * 0.5), absf(absf(lz) - float(p[4]) * 0.5))
			var turn := absf(wrapf(float(col[2]) - py, -PI * 0.25, PI * 0.25))
			return edge < 1.5 and turn < 0.02
		var wall := cols.filter(on_edge)
		_check(wall.size() >= 4, "its boundary walls are solid and on its edges, got %d" % wall.size())


## Every grounds part builds with triangles and sound colliders inside its
## own extent.
func test_grounds_kit_builds_every_part() -> void:
	var Grounds = preload("res://scripts/kits/grounds_kit.gd")
	var MB = preload("res://scripts/mesh_builder.gd")
	var trees := ["oak", "palm", "cypress", "fruit", "magnolia", "jacaranda", "crepe_myrtle", "plane"]
	var sizes := {"lawn": [60.0, 70.0], "yard": [40.0, 30.0], "gravel": [30.0, 20.0], "drive": [6.0, 24.0], "track": [3.5, 20.0],
		"wall": [40.0, 0.6], "hedge": [40.0, 0.6], "fence": [30.0, 0.2], "gate": [7.0, 0.6], "trees": [30.0, 9.0],
		"court": [20.0, 20.0], "parterre": [20.0, 14.0], "tennis": [18.3, 36.6], "orchard": [18.3, 36.6], "crop": [42.0, 42.0],
		"vines": [42.0, 42.0], "boat": [2.0, 5.0], "woodpile": [3.0, 1.6], "garden": [6.0, 5.0],
		"parking": [40.0, 36.0], "alley": [9.0, 60.0], "paving": [20.0, 30.0], "pool": [34.0, 22.0],
		"playground": [32.0, 26.0], "field": [67.0, 70.0], "course": [100.0, 36.0]}
	var problems: Array[String] = []
	for kind: String in sizes:
		# Every tree kind for the tree rows, four variants of the rest.
		for v in (trees.size() if kind == "trees" else 4):
			var mb = MB.new()
			var out: Array = []
			var rng := RandomNumberGenerator.new()
			rng.seed = 7 + v
			var size: Array = sizes[kind]
			# Well away from the origin, turned, so a collider left in the
			# part's own frame or at the wrong yaw shows.
			var p := [0, 60.0, -40.0, size[0], size[1], 0.5, v]
			Grounds.draw(kind, p, trees, mb, out, rng)
			var tag := "%s v%d" % [kind, v]
			if mb.triangle_count() <= 0:
				problems.append("%s: no triangles" % tag)
			var reach := Vector2(size[0], size[1]).length() * 0.5 + 6.0
			for col in out:
				var cc: Vector3 = col[0]
				if not (cc.is_finite() and col[1].is_finite() and is_finite(col[2])):
					problems.append("%s: NaN collider" % tag)
				elif Vector2(cc.x - 60.0, cc.z + 40.0).length() > reach:
					problems.append("%s: collider at %s off the part" % [tag, cc])
				elif kind in ["wall", "hedge", "fence"] and absf(wrapf(float(col[2]) - 0.5, -PI * 0.5, PI * 0.5)) > 0.01:
					problems.append("%s: collider turned %.2f, not along the part" % [tag, col[2]])
	_check(problems.is_empty(), "every grounds part builds soundly: %s" % ", ".join(problems.slice(0, 6)))


## Golden Flats (Sachin, 2026-10-28: "sprawling irrigation fields ... with
## major highways or expressways going through them, with shortcuts in
## between, on paved and unpaved roads leading to farmhouses"): the
## expressway off the Beltway over the Morrow, the section grid of paved
## roads and dirt tracks, centre pivots whose arms stream with their tiles,
## strip fields, canals with pump houses, farmsteads with drives.
func test_golden_flats_farmland() -> void:
	await _new_game(false)
	var city = game.city
	var c = city.country
	var flats := PackedVector2Array()
	var world: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world_map.json"))
	for r in world.regions:
		if r.id == "golden_flats":
			for q in r.polygon:
				flats.append(Vector2(q[0], q[1]) - city.map_origin)
	_check(flats.size() > 3, "Golden Flats is on the map")
	var expressway := []
	var six_lanes := true
	var paved := 0
	var dirt := 0
	for road in c.roads:
		var cls: String = c.classes[road.cls].id
		var mid: Vector2 = c.pos(road.nodes[road.nodes.size() / 2])
		if road.name == "Golden Flats Expressway":
			expressway.append(road)
			six_lanes = six_lanes and cls == "highway" and int(c.classes[road.cls].lanes) == 3
		elif Geometry2D.is_point_in_polygon(mid, flats):
			if cls == "road" and (road.name.begins_with("Range Road") or road.name.begins_with("County Road")):
				paved += 1
			elif cls == "track":
				dirt += 1
	_check(not expressway.is_empty() and six_lanes, "the Golden Flats Expressway runs through the farmland, 6 lanes")
	_check(paved >= 10 and dirt >= 10, "a section grid: %d paved section roads, %d dirt tracks" % [paved, dirt])
	# Shortcuts: unnamed roads curving across a section (the grid lines run
	# straight; a crossing cuts a shortcut into pieces, so each piece turns
	# a little), some paved and some dirt.
	var cuts := {}
	for road in c.roads:
		if road.name != "" or not Geometry2D.is_point_in_polygon(c.pos(road.nodes[road.nodes.size() / 2]), flats):
			continue
		var turn := 0.0
		for i in range(1, road.nodes.size() - 1):
			var a: Vector2 = c.pos(road.nodes[i]) - c.pos(road.nodes[i - 1])
			var b: Vector2 = c.pos(road.nodes[i + 1]) - c.pos(road.nodes[i])
			turn += absf(a.angle_to(b))
		if turn > 0.2:
			var cls: String = c.classes[road.cls].id
			cuts[cls] = cuts.get(cls, 0) + 1
	_check(cuts.get("lane", 0) >= 3 and cuts.get("track", 0) >= 3, "curving shortcuts across the sections, paved and dirt: %s" % cuts)
	# It leaves the Beltway: an expressway node is a Beltway node too.
	var belt := {}
	for road in c.roads:
		if road.name == "Bellerive Beltway":
			for n in road.nodes:
				belt[n] = true
	var joined := false
	for road in expressway:
		for n in road.nodes:
			joined = joined or belt.has(n)
	_check(joined, "the expressway joins the Beltway")
	_check(_bridged(c, "Golden Flats Expressway"), "the expressway bridges the Morrow")
	# Pivots, their spans as plots, the field zones in the tiles.
	_check(c.pivots.size() >= 12, "centre-pivot circles, got %d" % c.pivots.size())
	var spans := 0
	for q: Array in c.plots:
		if c.plot_types[int(q[5])] == "pivot":
			spans += 1
	_check(spans >= c.pivots.size() * 2, "each pivot has its sprinkler spans (%d)" % spans)
	var zone_tris := {}
	for key in c.tiles:
		for part in c.tiles[key].g:
			var z: String = c.zones[int(part[0])]
			if z.begins_with("pivot") or z.begins_with("field") or z.begins_with("canal"):
				zone_tris[z] = zone_tris.get(z, 0) + 1
	for z in ["pivot_track", "pivot_green", "field_green_row", "field_gold", "canal", "canal_bank"]:
		_check(zone_tris.get(z, 0) > 0, "%s is on the ground" % z)
	# Sachin: "All homes in the farmstead look the same ... Also add
	# farmhouses, big and small ones": the flats' homes come in several
	# kinds, big and small among them.
	var pumps := 0
	var farms := 0
	var homes := {}
	for l: Array in c.lots:
		var kind: String = c.kinds[int(l[5])]
		if kind == "pump_house":
			pumps += 1
		elif kind == "barn" and Geometry2D.is_point_in_polygon(Vector2(l[0], l[1]), flats):
			farms += 1
		elif kind in ["farmhouse", "farmhouse_big", "farmhouse_small", "ranch_house", "adobe_farmhouse"] and Geometry2D.is_point_in_polygon(Vector2(l[0], l[1]), flats):
			homes[kind] = homes.get(kind, 0) + 1
	_check(pumps >= 1 and farms >= 6, "pump houses at the canals (%d), farmsteads (%d)" % [pumps, farms])
	_check(homes.size() >= 4 and homes.get("farmhouse_big", 0) >= 3 and homes.get("farmhouse_small", 0) >= 3,
			"the flats' homes come in kinds, big and small among them (%s)" % [homes])
	# Sachin: "As the farmhouse sizes get bigger ... different variations as
	# size progresses": each farm-home kind is built on lots of all three
	# size tiers somewhere in the country, so its three plans all show.
	var tiers := {}
	for l: Array in c.lots:
		var kind: String = c.kinds[int(l[5])]
		if kind in ["farmhouse", "farmhouse_big", "farmhouse_small", "ranch_house", "adobe_farmhouse"]:
			if not tiers.has(kind):
				tiers[kind] = [0, 0, 0]
			tiers[kind][preload("res://scripts/kits/country_kit.gd")._tier(kind, float(l[3]), float(l[4]))] += 1
	var all_tiers := tiers.size() == 5
	for k: String in tiers:
		all_tiers = all_tiers and not (0 in tiers[k])
	_check(all_tiers, "every farm-home kind stands on small, usual and big lots: %s" % [tiers])
	# ... and the three plans differ: built at a small, usual and big size,
	# each kind stands up a different set of solid heights (a plan only
	# scaled up keeps its heights).
	var Kit = preload("res://scripts/kits/country_kit.gd")
	var same: Array[String] = []
	for kind: String in tiers:
		var f: Vector2 = Kit.footprint(kind)
		var sets := []
		for s: float in [0.75, 1.0, 1.35]:
			_check(Kit._tier(kind, f.x * s, f.y * s) == sets.size(), "%s at %.2fx is tier %d" % [kind, s, sets.size()])
			var out: Array = []
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			Kit.build(kind, preload("res://scripts/mesh_builder.gd").new(), out, f * s, rng)
			var heights := {}
			for col: Array in out:
				heights[snappedf((col[1] as Vector3).y, 0.1)] = true
			var hs := heights.keys()
			hs.sort()
			sets.append(hs)
		print("  %s solid heights: %s" % [kind, sets])
		if sets[0] == sets[1] or sets[1] == sets[2] or sets[0] == sets[2]:
			same.append(kind)
	_check(same.is_empty(), "each farm home's small, usual and big plans differ (same solid heights: %s)" % [same])
	# A pivot's tile streams in with its tower solid.
	var big: Array = c.pivots[0]
	var at := Vector3(big[0], 0.0, big[1])
	_place_player_at(at + Vector3(0, 1, 0))
	city.stream_now(at)
	await _frames(20)
	var tile: Node3D = c.tile_node(c.tile_key(at))
	_check(tile != null, "the pivot's tile streams in")
	var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(at + Vector3(0, 1.0, -3.0), at + Vector3(0, 1.0, 3.0)))
	var near_tower := false
	for q: Array in c.plots:
		if c.plot_types[int(q[5])] == "pivot" and Vector2(q[0], q[1]).distance_to(Vector2(big[0], big[1])) < 30.0:
			near_tower = true
	_check(near_tower and not hit.is_empty(), "the pivot tower is solid")


## Whether the named road has a bridge edge (over water).
func _bridged(c, name: String) -> bool:
	for road in c.roads:
		if road.name != name:
			continue
		for k in road.nodes.size() - 1:
			var e: int = c.edge_between(road.nodes[k], road.nodes[k + 1])
			if e >= 0 and c.edge_bridge[e] != 0:
				return true
	return false


## The Bellerive Hills: the height grid loads, the observatory stands on its
## pad up the hill, its tile is raised to the ground, someone on foot stands
## on the slope, and a car driven up Crest Drive keeps its wheels on the road.
func test_bellerive_hills() -> void:
	await _new_game(false)
	var city = game.city
	var c = city.country
	_check(Terrain.nx > 0 and Terrain.ny > 0, "the hills' height grid loads (%d x %d)" % [Terrain.nx, Terrain.ny])
	var peak := 0.0
	for h in Terrain.heights:
		peak = maxf(peak, h)
	_check(peak > 100.0 and peak < 150.0, "Calder Peak tops out at %.0f m" % peak)
	_check(Terrain.height(0.0, 0.0) == 0.0 and Terrain.height(1200.0, 900.0) == 0.0, "the city stays flat")
	for id in ["lumen_observatory", "hill_letters", "calder_mast_0", "calder_mast_1"]:
		_check(not c.landmark(id).is_empty(), "%s has its lot" % id)
	var obs: Dictionary = c.landmark("lumen_observatory")
	if obs.is_empty():
		return
	var at: Vector3 = obs.pos
	var pad := Terrain.height(at.x, at.z)
	_check(pad > 40.0, "the observatory stands up the hill (%.1f m)" % pad)
	var front: Vector3 = obs.front
	_place_player_at(Vector3(front.x, pad + 2.0, front.z))
	city.stream_now(at)
	await _frames(30)
	var p: Vector3 = game.player.global_position
	_check(absf(p.y - Terrain.height(p.x, p.z)) < 0.3, "someone on foot stands on the slope (%.2f m off)" % (p.y - Terrain.height(p.x, p.z)))
	var tile: Node3D = c.tile_node(c.tile_key(at))
	_check(tile != null, "the observatory's tile streams in")
	if tile != null:
		var top := -INF
		for n in tile.get_children():
			if n is MeshInstance3D:
				top = maxf(top, (n.get_aabb() as AABB).end.y)
		_check(top > pad + 8.0, "its tile is raised with the ground (top %.1f m)" % top)
	# The road you see is the ground cars ride on (Terrain.height), with the
	# grass under it and the lane lines just on top, along the hill roads.
	var off_road := 0.0
	var line_low := INF
	var line_high := -INF
	var samples := 0
	for name in ["Canyon Freeway", "Crest Drive", "Observatory Road"]:
		for r in c.roads:
			if r.name != name:
				continue
			for k in range(0, r.nodes.size() - 1, 3):
				var e: int = int(r.e0) + k
				var na: Vector2 = c.node_pos[c.edge_a[e]]
				var nb: Vector2 = c.node_pos[c.edge_b[e]]
				# Off the middle, where two pieces of a line meet.
				var mid := na.lerp(nb, 0.43)
				if Terrain.height(mid.x, mid.y) < 15.0 or na.distance_to(nb) < 6.0 or c.bridge_edges.has(e):
					continue
				var d := (nb - na).normalized()
				var side := Vector2(-d.y, d.x)
				var hw: float = c.edge_width(e) * 0.5
				var lane := mid + side * hw * 0.25
				var geo: Dictionary = c.classes[c.edge_cls[e]]
				var edge_line: Vector2 = mid + side * (geo.middle + geo.lanes * geo.lane_w + 0.15 if c.edge_class(e) == "highway" else hw - 0.5)
				c.stream_now(Vector3(lane.x, 0.0, lane.y))
				samples += 1
				off_road = maxf(off_road, absf(_surface_top(c, lane) - Terrain.height(lane.x, lane.y)))
				# Lines stop short of junctions.
				if c.edge_class(e) in ["highway", "road"] and c.degree(c.edge_a[e]) == 2 and c.degree(c.edge_b[e]) == 2:
					var lift := _surface_top(c, edge_line) - Terrain.height(edge_line.x, edge_line.y)
					line_low = minf(line_low, lift)
					line_high = maxf(line_high, lift)
	_check(samples > 20, "hill roads sampled (%d edges)" % samples)
	_check(off_road < 0.05, "the hill roads' surface is the ground cars ride on, with no grass through it (worst %.3f m off)" % off_road)
	_check(line_low > 0.02 and line_high < 0.15, "their edge lines show just above the road (%.3f to %.3f m)" % [line_low, line_high])
	# Up Crest Drive: from a node, toward the higher of its neighbours.
	var road: Dictionary = {}
	for r in c.roads:
		if r.name == "Crest Drive" and r.nodes.size() > 30:
			road = r
			break
	_check(not road.is_empty(), "Crest Drive is a country road")
	if road.is_empty():
		return
	var best := -1
	var rise := 0.0
	for k in range(4, road.nodes.size() - 8):
		var a: Vector2 = c.node_pos[road.nodes[k]]
		var b: Vector2 = c.node_pos[road.nodes[k + 4]]
		var dh := absf(Terrain.height(b.x, b.y) - Terrain.height(a.x, a.y))
		if dh > rise:
			rise = dh
			best = k
	var a: Vector2 = c.node_pos[road.nodes[best]]
	var b: Vector2 = c.node_pos[road.nodes[best + 4]]
	if Terrain.height(b.x, b.y) < Terrain.height(a.x, a.y):
		var t := a
		a = b
		b = t
	var dir := (b - a).normalized()
	var start := Vector3(a.x, Terrain.height(a.x, a.y), a.y)
	city.stream_now(start)
	var car = Vehicle.new()
	car.city = city
	car.position = start
	car.rotation.y = atan2(-dir.x, -dir.y)
	game.add_child(car)
	_place_player_at(start + Vector3(dir.y, 0, -dir.x) * 3.0)
	await _frames(4)
	await _press("interact")
	_check(game.player.vehicle == car, "player gets in a car on Crest Drive")
	var worst := 0.0
	var tilt := 0.0
	for f in 150:
		Controls.override_vector = dir
		await _frames(1)
		var q: Vector3 = car.global_position
		worst = maxf(worst, absf(q.y - Terrain.height(q.x, q.z)))
		tilt = maxf(tilt, absf(car._slope.y))
	Controls.override_vector = null
	var q: Vector3 = car.global_position
	_check(worst < 0.05, "the car rides on the ground (worst %.3f m off)" % worst)
	_check(q.y > start.y + 2.0, "and it climbs the hill (%.1f m to %.1f m)" % [start.y, q.y])
	_check(tilt > 0.03, "the body pitches up the slope (%.3f rad)" % tilt)
	_check(c.road_distance(Vector2(q.x, q.z), 30.0) < 6.0, "and stays on the road")
	await _press("interact")
	# Left on the slope it stays put (as if on its parking brake) and stops
	# simulating, rather than creeping downhill.
	await _until(func(): return car.velocity == Vector3.ZERO, 900)
	var parked: Vector3 = car.global_position
	await _frames(180)
	var crept: float = car.global_position.distance_to(parked)
	_check(crept < 0.02 and car.velocity == Vector3.ZERO, "a car left on the slope stays put (%.3f m in 3 s)" % crept)
	car.queue_free()
	await _frames(2)


## Sachin: "Ensure there are routes leading to all houses from the street or
## road, can be single lane but there should be routes, match the route
## textures to the building and surroundings". Every home lot either runs
## its drives out to a road (lot element 9), stands in a cluster whose
## footpaths join its track, or in an estate whose drive reaches the house
## (the city's edge street counts as a road). Each home kit, built with a
## road ahead, draws a route out past its lot's front, none of them through
## a front fence.
func test_every_home_has_a_way_in() -> void:
	await _new_game(false)
	var c = game.city.country
	var homes := ["house", "cape_house", "rowhouse_row", "shack", "stilt_house", "mansion", "garden_apartments",
		"trailer_home", "farmhouse", "farmhouse_big", "farmhouse_small", "ranch_house", "adobe_farmhouse"]
	var ways := {}
	var lost: Array[String] = []
	for l: Array in c.lots:
		var kind: String = c.kinds[int(l[5])]
		if kind not in homes:
			continue
		var how := ""
		var reach: Array = l[9] if l.size() > 9 else []
		if not reach.is_empty() and maxf(maxf(reach[0], reach[1]), reach[2]) > 0.0:
			how = "reach"
		elif int(l[8]) >= 0:
			var plot: Array = c.plots[int(l[8])]
			var t: String = c.plot_types[int(plot[5])]
			if t == "estate":
				how = "estate"
			elif t == "cluster":
				for part: Array in plot[6]:
					if c.part_kinds[int(part[0])] == "footpath":
						how = "cluster"
		if how == "":
			lost.append("%s at (%d, %d)" % [kind, l[0], l[1]])
		ways[how] = ways.get(how, 0) + 1
	print("  ways in: %s" % [ways])
	_check(lost.is_empty() and ways.get("reach", 0) > 1000, "every home has a way in from a road (%d without: %s)" % [lost.size(), lost.slice(0, 5)])
	# Cluster footpaths: each cluster with homes has as many as it has homes.
	var short: Array[String] = []
	for q: Array in c.plots:
		if c.plot_types[int(q[5])] != "cluster":
			continue
		var paths := 0
		for part: Array in q[6]:
			if c.part_kinds[int(part[0])] == "footpath":
				paths += 1
		var dwellers := 0
		for l: Array in c.lots:
			if int(l[8]) >= 0 and c.plots[int(l[8])] == q:
				dwellers += 1
		if paths < dwellers:
			short.append("cluster at (%d, %d): %d homes, %d paths" % [q[0], q[1], dwellers, paths])
	_check(short.is_empty(), "every cluster home has an apron at least (%s)" % [short.slice(0, 3)])
	# ... and no footpath runs under a home (points along each path's middle
	# line, against every home lot of its plot shrunk by 0.3 m).
	var fp := func(o: Vector2, yaw: float, lx: float, lz: float) -> Vector2:
		return o + Vector2(lx * cos(yaw) + lz * sin(yaw), -lx * sin(yaw) + lz * cos(yaw))
	var under: Array[String] = []
	for k in c.plots.size():
		var q: Array = c.plots[k]
		if c.plot_types[int(q[5])] != "cluster":
			continue
		var o := Vector2(q[0], q[1])
		var lots_here: Array = []
		for l: Array in c.lots:
			if int(l[8]) == k:
				lots_here.append(l)
		for part: Array in q[6]:
			if c.part_kinds[int(part[0])] != "footpath":
				continue
			for t in [-0.5, -0.25, 0.0, 0.25, 0.5]:
				var local: Vector2 = fp.call(Vector2(part[1], part[2]), float(part[5]), float(part[3]) * t, 0.0)
				var p: Vector2 = fp.call(o, float(q[2]), local.x, local.y)
				for l: Array in lots_here:
					var dv := p - Vector2(l[0], l[1])
					var yaw := float(l[2])
					var lx := dv.x * cos(yaw) - dv.y * sin(yaw)
					var lz := dv.x * sin(yaw) + dv.y * cos(yaw)
					if absf(lx) < float(l[3]) * 0.5 - 0.3 and absf(lz) < float(l[4]) * 0.5 - 0.3:
						under.append("path at (%d, %d) under a %s" % [p.x, p.y, c.kinds[int(l[5])]])
	_check(under.is_empty(), "no cluster footpath runs under a home (%d: %s)" % [under.size(), under.slice(0, 3)])
	# The kits: with a road 4 m ahead, each home draws a route out past its
	# front edge, and no route crosses a front fence run.
	var Kit = preload("res://scripts/kits/country_kit.gd")
	var MB = preload("res://scripts/mesh_builder.gd")
	# The kit's statics are shared with the tile worker: let it finish first.
	c._finish_task()
	Kit.record_routes = true
	# A tile build hands each lot its reach: a street house's drive runs out.
	var house := -1
	for i in c.lots.size():
		var l: Array = c.lots[i]
		if c.kinds[int(l[5])] == "house" and minf(minf(l[9][0], l[9][1]), l[9][2]) > 3.0:
			house = i
			break
	var tile_key := Vector2i(-99999, -99999)
	for key: Vector2i in c.tiles:
		for i in c.tiles[key].l:
			if int(i) == house:
				tile_key = key
	Kit.routes_drawn.clear()
	preload("res://scripts/country_tiles.gd").build(c, tile_key)
	var longest := 0.0
	for r: Vector4 in Kit.routes_drawn:
		longest = maxf(longest, r.z)
	_check(house >= 0 and longest > 3.0, "a tile build runs a street house's drive out to its road (house %d, longest route out %.1f m)" % [house, longest])
	# On the hills the route bends from the lot's pad down (or up) to the
	# road: on the house whose road edge lies furthest off its pad, route
	# tops (0.05 up) at the road edge sit on the ground there, none on the pad.
	var Terrain = preload("res://scripts/terrain.gd")
	var hill := -1
	var off := 0.0
	for i in c.lots.size():
		var l: Array = c.lots[i]
		if c.kinds[int(l[5])] != "house" or l[9][1] < 2.0 or Terrain.height(l[0], l[1]) <= 0.0:
			continue
		var yaw := float(l[2])
		for k in 3:
			var lx := (k - 1) * (float(l[3]) * 0.5 - 0.3)
			var lz := -float(l[4]) * 0.5 - (float(l[9][k]) - 0.6)
			var e := Vector2(l[0], l[1]) + Vector2(lx * cos(yaw) + lz * sin(yaw), -lx * sin(yaw) + lz * cos(yaw))
			var gap := absf(Terrain.height(e.x, e.y) - Terrain.height(l[0], l[1]))
			if gap > off:
				hill = i
				off = gap
	var on_ground := 0
	var on_pad := 0
	if hill >= 0:
		var l: Array = c.lots[hill]
		for key: Vector2i in c.tiles:
			for i in c.tiles[key].l:
				if int(i) == hill:
					tile_key = key
		var built: Dictionary = preload("res://scripts/country_tiles.gd").build(c, tile_key)
		var pad := Terrain.height(l[0], l[1])
		var to_local := Transform3D(Basis(Vector3.UP, float(l[2])), Vector3(l[0], 0.0, l[1])).affine_inverse()
		Kit.reach = l[9]
		for v: Vector3 in built.mesh.verts:
			var lv := to_local * Vector3(v.x, 0.0, v.z)
			if absf(lv.x) > float(l[3]) * 0.5:
				continue
			var z_edge := -float(l[4]) * 0.5 - (Kit._reach_at(lv.x, float(l[3])) - 0.6)
			if absf(lv.z - z_edge) > 0.05:
				continue
			if absf(v.y - (Terrain.height(v.x, v.z) + 0.05)) < 0.01:
				on_ground += 1
			elif absf(v.y - (pad + 0.05)) < 0.01:
				on_pad += 1
		Kit.reach = [0.0, 0.0, 0.0]
	_check(hill >= 0 and off > 0.15 and on_ground > 0 and on_pad == 0,
		"a hill house's drive meets its road (road edge %.2f m off the pad; route tops there on the ground %d, on the pad %d)" % [off, on_ground, on_pad])
	var problems: Array[String] = []
	# The same with the left third of the front blocked (rails, water): no
	# route leaves through it. A farm's own buildings draw none of their own
	# through its fence. Every household tier too: its fences keep a gate.
	for case: Array in [[4.0, 4.0, 4.0], [-1.0, 4.0, 4.0]]:
		for kind: String in homes + ["hollis_farm"]:
			var f: Vector2 = Kit.footprint(kind)
			for s: float in [0.75, 1.0, 1.35]:
				for tier in range(-1, 6):
					for seed in (4 if tier < 0 else 2):
						var size := f * s
						var mb = MB.new()
						var out: Array = []
						var rng := RandomNumberGenerator.new()
						rng.seed = seed
						Kit.reach = case
						Kit.wealth = tier
						Kit.routes_drawn.clear()
						Kit.build(kind, mb, out, size, rng)
						Kit.reach = [0.0, 0.0, 0.0]
						Kit.wealth = -1
						var tag := "%s %.1fx%.1f seed %d reach %s tier %d" % [kind, size.x, size.y, seed, case, tier]
						var going_out := 0
						for r: Vector4 in Kit.routes_drawn:
							going_out += 1 if r.z > 0.0 else 0
						if kind == "hollis_farm" and going_out != 1:
							problems.append("%s: %d routes out (its farmhouse's own must stay inside)" % [tag, going_out])
						for r: Vector4 in Kit.routes_drawn:
							if r.z > 0.0 and case[0] < 0.0 and r.w < -0.34 * size.x * 0.5:
								problems.append("%s: route %s out through the blocked side" % [tag, r])
						var ahead := 0.0
						for v: Vector3 in mb.verts:
							ahead = maxf(ahead, -size.y * 0.5 - v.z)
						if Kit.routes_drawn.is_empty() or ahead < 3.9:
							problems.append("%s: no route out (%.1f m past the front)" % [tag, ahead])
						for col in out:
							var cc: Vector3 = col[0]
							var cs: Vector3 = col[1]
							# Front fence runs: long, thin, low, near the front edge.
							if cs.x > 1.0 and cs.z < 0.9 and cs.y <= 2.0 and cc.z < -size.y * 0.5 + 1.6:
								for r: Vector4 in Kit.routes_drawn:
									# (routes that go out; a farm building's own are in its frame)
									if r.z > 0.0 and minf(r.y, cc.x + cs.x * 0.5) - maxf(r.x, cc.x - cs.x * 0.5) > 0.05:
										problems.append("%s: route %s through the fence at x %.1f" % [tag, r, cc.x])
	Kit.routes_drawn.clear()
	Kit.record_routes = false
	for p in problems.slice(0, 60):
		print("  " + p)
	_check(problems.is_empty(), "every home kit runs a route out through a gate (%d problems)" % problems.size())


## Homes by wealth (HANDOFF-wealth.md phase 1): every home lot has a
## household tier in its kind's range, all six tiers are present, land value
## rises with tier (estates, T5, beat T3: they trade the dearest ground for
## the most of it) and so does private ground per household; the kits show
## the tier, and a tile build hands it to them.
func test_homes_by_wealth() -> void:
	await _new_game(false)
	var c = game.city.country
	const RANGE := {"shack": [0, 1], "trailer_home": [0, 1], "stilt_house": [0, 2], "garden_apartments": [1, 2],
		"rowhouse_row": [1, 3], "house": [1, 4], "cape_house": [2, 3], "farmhouse_small": [1, 2], "farmhouse": [2, 3],
		"ranch_house": [2, 3], "adobe_farmhouse": [2, 3], "farmhouse_big": [3, 4], "condo_tower": [3, 4], "mansion": [4, 5]}
	const UNITS := {"garden_apartments": 12, "rowhouse_row": 4}
	var n := [0, 0, 0, 0, 0, 0]
	var value := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	var land := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	var land_n := [0, 0, 0, 0, 0, 0]
	var homes_in := {}
	for l: Array in c.lots:
		if int(l[8]) >= 0 and c.kinds[int(l[5])] in RANGE:
			homes_in[int(l[8])] = homes_in.get(int(l[8]), 0) + 1
	var wrong: Array[String] = []
	for l: Array in c.lots:
		var kind: String = c.kinds[int(l[5])]
		var t := int(l[10]) if l.size() > 10 else -9
		if kind not in RANGE:
			if t != -1:
				wrong.append("%s with tier %d" % [kind, t])
			continue
		var plot_type: String = c.plot_types[int(c.plots[int(l[8])][5])] if int(l[8]) >= 0 else ""
		if t < RANGE[kind][0] or t > RANGE[kind][1] or (plot_type == "estate" and t != 5):
			wrong.append("%s at (%d, %d) tier %d" % [kind, l[0], l[1], t])
			continue
		n[t] += 1
		value[t] += float(l[11])
		if kind == "condo_tower":
			continue  # towers count their floors, not their ground
		var q: Array = c.plots[int(l[8])] if int(l[8]) >= 0 else []
		if plot_type == "estate" or plot_type == "parcel":
			land[t] += float(q[3]) * float(q[4]) / homes_in[int(l[8])]
		else:
			land[t] += float(l[3]) * float(l[4]) / UNITS.get(kind, 1)
		land_n[t] += 1
	var rows: Array[String] = []
	for t in 6:
		value[t] /= maxf(1.0, n[t])
		land[t] /= maxf(1.0, land_n[t])
		rows.append("T%d %d homes, value %.2f, %.0f m2" % [t, n[t], value[t], land[t]])
	print("  " + "; ".join(rows))
	_check(wrong.is_empty(), "every home lot has a tier in its kind's range, others none (%d wrong: %s)" % [wrong.size(), wrong.slice(0, 4)])
	_check(n.min() > 0, "all six household tiers live in Bellerive's country (%s)" % [n])
	var rising := true
	for t in range(1, 6):
		rising = rising and value[t] > value[t - 1 if t < 5 else 3] and land[t] > land[t - 1]
	_check(rising, "land value and private ground per household rise with tier")
	# The kits: a T1 house is a worn rental behind chain-link with a beater;
	# a T4 house is behind a hedge with a luxury car; a T5 mansion keeps two
	# luxury cars, a T4 one.
	c._finish_task()
	var Kit = preload("res://scripts/kits/country_kit.gd")
	var MB = preload("res://scripts/mesh_builder.gd")
	var meshes := {}  # "kind tier" -> the built MeshBuilder
	var built_at := func(kind: String, tier: int, size: Vector2) -> Array:
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		Kit.wealth = tier
		var out: Array = []
		var mb = MB.new()
		Kit.build(kind, mb, out, size, rng)
		Kit.wealth = -1
		meshes["%s %d" % [kind, tier]] = mb
		return out
	var built := func(kind: String, tier: int) -> Array:
		return built_at.call(kind, tier, Kit.footprint(kind))
	var count := func(out: Array, size: Vector3) -> int:
		var k := 0
		for col in out:
			if (col[1] as Vector3).is_equal_approx(size):
				k += 1
		return k
	const LUX := Vector3(1.9, 1.5, 4.9)
	var poor: Array = built.call("house", 1)
	var rich: Array = built.call("house", 4)
	var chain := 0
	var hedge := 0
	var d: float = Kit.footprint("house").y
	# Chain-link crosses the front; the board fence of T2-T3 stops at the
	# sides, so only a run along the front line counts.
	var front_runs := func(out: Array) -> int:
		var k := 0
		for col in out:
			k += 1 if is_equal_approx(col[1].y, 1.8) and col[1].z < 0.2 and col[1].x > 1.5 and col[0].z < -d * 0.5 + 2.0 else 0
		return k
	chain = front_runs.call(poor)
	var middle: int = front_runs.call(built.call("house", 2))
	for col in rich:
		hedge += 1 if is_equal_approx(col[1].y, 1.1) and is_equal_approx(minf(col[1].x, col[1].z), 0.8) else 0
	_check(count.call(poor, LUX) == 0 and chain >= 1 and middle == 0 and count.call(rich, LUX) == 1 and hedge >= 4,
		"a T1 house has chain-link across its front (%d runs, T2 %d) and no luxury car, a T4 house a hedge and one (%d runs, %d cars)" % [chain, middle, hedge, count.call(rich, LUX)])
	# On the 14 m hill lots the T4 car pulls into the garage rather than
	# hang over the lot's front edge.
	var hill_front := INF
	for col in built_at.call("house", 4, Vector2(14, 14)):
		if (col[1] as Vector3).is_equal_approx(LUX):
			hill_front = col[0].z - 2.45
	_check(hill_front >= -7.0 + 0.25 and hill_front < INF, "a T4 car on a 14 m hill lot stays inside the lot (front at %.2f, edge -7)" % hill_front)
	# Every kind with markers builds differently at the bottom and the top
	# of its range, from the same seed.
	var same: Array[String] = []
	for kind: String in ["shack", "trailer_home", "stilt_house", "garden_apartments", "rowhouse_row", "house", "cape_house", "farmhouse_small", "condo_tower", "mansion"]:
		built.call(kind, RANGE[kind][0])
		built.call(kind, RANGE[kind][1])
		var lo = meshes["%s %d" % [kind, RANGE[kind][0]]]
		var hi = meshes["%s %d" % [kind, RANGE[kind][1]]]
		if lo.verts.size() == hi.verts.size() and lo.colors == hi.colors:
			same.append(kind)
	_check(same.is_empty(), "each marked home kind looks different at its lowest and highest tier (same: %s)" % [same])
	_check(count.call(built.call("mansion", 5), LUX) == 2 and count.call(built.call("mansion", 4), LUX) == 1,
		"a T5 mansion keeps two luxury cars, a T4 mansion one")
	# A tile build hands each lot its tier: a T4 house there gets its car.
	var rich_lot := -1
	for i in c.lots.size():
		var l: Array = c.lots[i]
		if c.kinds[int(l[5])] == "house" and int(l[10]) == 4:
			rich_lot = i
			break
	var tile_key := Vector2i(-99999, -99999)
	for key: Vector2i in c.tiles:
		for i in c.tiles[key].l:
			if int(i) == rich_lot:
				tile_key = key
	var cars := 0
	if rich_lot >= 0:
		var tile: Dictionary = preload("res://scripts/country_tiles.gd").build(c, tile_key)
		var at := Vector3(c.lots[rich_lot][0], 0.0, c.lots[rich_lot][1])
		for col in tile.colliders:
			if (col[1] as Vector3).is_equal_approx(LUX) and Vector3(col[0].x, 0.0, col[0].z).distance_to(at) < 15.0:
				cars += 1
	_check(rich_lot >= 0 and cars >= 1, "a tile build gives a T4 street house its luxury car (lot %d, %d cars)" % [rich_lot, cars])
