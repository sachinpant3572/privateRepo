extends Node
## Headless prototype tests. Run with tests/run.sh.
## Each test builds a fresh game, drives it through Controls and checks state.

const MainScene = preload("res://main.tscn")
const Vehicle = preload("res://scripts/vehicle.gd")
const Npc = preload("res://scripts/npc.gd")
const VehicleKit = preload("res://scripts/kits/vehicle_kit.gd")
const Terrain = preload("res://scripts/terrain.gd")
const SkyDome = preload("res://scripts/sky.gd")
const MeshBuilder = preload("res://scripts/mesh_builder.gd")
const Population = preload("res://scripts/population.gd")
const StreetPlan = preload("res://scripts/street_plan.gd")
const PeopleSenses = preload("res://scripts/senses.gd")
const PedScript = preload("res://scripts/pedestrian.gd")
const CharKit = preload("res://scripts/kits/character_kit.gd")
const RigScript = preload("res://scripts/rig.gd")
const GameLog = preload("res://scripts/game_log.gd")

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
		"test_camera_turns_with_car", "test_new_car_swing_calms_when_driving",
		"test_camera_ninety_turns", "test_settings_page_tabs_and_preview",
		"test_punch_combo_ends_in_knockdown_kick",
		"test_minimap_routes_to_waypoint", "test_state_map_shows_the_whole_state",
		"test_night_lights_the_city", "test_headlights_follow_the_ground",
		"test_graphics_quality_presets", "test_real_lights_at_night", "test_police_bar_light_budget", "test_look_up_at_the_sky",
		"test_sky_follows_the_sun_and_moon", "test_stars_by_light_pollution", "test_birds_by_day_not_at_night", "test_birds_startle_and_budget",
		"test_homecoming_runs_start_to_finish",
		"test_failed_mission_can_be_retried",
		"test_empty_rooms_phone_and_clues",
		"test_lantern_lights_ambush",
		"test_people_wear_modern_clothes",
		"test_people_dress_for_their_kind", "test_reactions_by_kind_of_person", "test_reaction_starts_on_time",
		"test_people_notice_by_sight_and_sound", "test_poses_stay_in_joint_limits", "test_crowd_reacts_to_a_punch",
		"test_people_dodge_cars_and_get_up", "test_cops_investigate_off_duty", "test_people_sit_on_benches",
		"test_vehicle_roster_and_parking",
		"test_vehicle_speed_ranks",
		"test_player_driving_assists",
		"test_driving_layouts",
		"test_brake_and_steer_drifts",
		"test_touch_driving_layouts",
		"test_scripted_car_gets_unstuck", "test_heavy_vehicle_pushes_harder", "test_spawns_need_room", "test_overlap_resolves", "test_heavy_pushes_parked", "test_pinned_car_holds_still", "test_xray_only_when_hidden", "test_cars_prewarmed", "test_hero_seen_under_roofs", "test_cab_stop_skips_parked_car",
		"test_vehicle_classes_cover_every_kind", "test_suspension_bounces_and_settles", "test_side_hit_spins_and_dents", "test_hard_crash_throws_panel", "test_crash_throws_rider", "test_car_fire_then_explodes",
		"test_vehicle_handling_differs",
		"test_traffic_drives_every_kind",
		"test_vehicle_models_in_budget_and_grounded", "test_three_wheelers_and_big_trucks",
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
		"test_new_home_kinds_and_live_cars", "test_people_walk_the_suburbs", "test_suburb_home_cars_are_live",
		"test_road_surfaces_and_roadworks", "test_traffic_flows_past_roadworks", "test_boundaries_vary_by_household",
		"test_game_log_file_and_rotation", "test_game_log_snapshot_and_events", "test_game_log_report_copy_and_off",
		"test_screen_shake_setting", "test_settings_sliders_snap_and_apply",
		"test_blood_melee_spurts_and_spatters", "test_blood_car_hits_smear_and_pool", "test_blood_bleed_toggle_cap_and_fade",
		"test_exhaust_by_kind_and_norms", "test_tyre_marks_and_smoke",
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
	_check(city.sidewalk_loops.size() == land + city.country.walks.size(),
		"one sidewalk loop per playable land block, then the suburbs' (%d)" % city.country.walks.size())
	_check(city.country.walks.size() >= 100, "the suburbs have sidewalk loops, got %d" % city.country.walks.size())
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
	# Settings > Angle and Look down near towers, driven from the phone, and
	# Reset camera putting angle, tilt, distance and drive zoom-out back.
	var phone = game.hud.phone
	phone.open()
	phone._settings()
	var page = phone.settings_page
	page.show_tab("Camera")
	var angle_s = page.sliders.get("Angle")
	var zoom_s = page.sliders.get("Distance")
	var drive_s = page.sliders.get("Drive zoom-out")
	var tilt_b = _find_button(page, "Look down near towers: ")
	var reset_b = _find_button(page, "Reset camera")
	_check(angle_s != null and zoom_s != null and drive_s != null and tilt_b != null and reset_b != null and angle_s.get_meta("value").text == "65°" and zoom_s.get_meta("value").text == "100%" and drive_s.get_meta("value").text == "100%", "Settings > Camera has Distance (100%), Drive zoom-out (100%), Angle (65°), Look down near towers and Reset camera")
	if angle_s != null and zoom_s != null and drive_s != null and tilt_b != null and reset_b != null:
		for n in 4:
			_slide(angle_s, -1)
		tilt_b.pressed.emit()
		_slide(zoom_s, 1)
		_slide(drive_s, -1)
		phone.close()  # the open phone pauses the game
		await _frames(240)
		_check(angle_s.get_meta("value").text == "45°" and tilt_b.text.ends_with("OFF") and cam.pitches() == [45.0] and absf(cam.perspective_pitch - 45.0) < 0.5 and game.settings["angle"] == 45.0, "Angle four steps down: 45° with tilt off holds the camera at %.1f degrees" % cam.perspective_pitch)
		_check(cam.zoom == 1.15 and game.settings["zoom"] == 1.15 and cam.drive_zoom == 0.75 and drive_s.get_meta("value").text == "75%", "Distance a step up gives 115%, Drive zoom-out a step down gives 75%")
		_check(game.city.LOAD_RADIUS > 105.0 * 1.15 * 1.25, "at 45° and Distance 115%% the city loads to %.0f m" % game.city.LOAD_RADIUS)
		tilt_b.pressed.emit()
		_check(cam.pitches() == [45.0, 50.0, 55.0, 60.0, 65.0, 70.0, 75.0, 80.0, 85.0], "with tilt on it picks from 45° up to 85°")
		phone.close()  # the open phone pauses the game
		await _frames(240)
		_check(cam.perspective_pitch < 52.0, "and among low buildings it stays near 45° (%.1f)" % cam.perspective_pitch)
		for n in cam.ANGLES.size() + 2:
			_slide(angle_s, 1)
		phone.close()  # the open phone pauses the game
		await _frames(240)
		var below: Vector3 = cam.project_ray_normal(cam.get_viewport().get_visible_rect().get_center())
		_check(absf(cam.perspective_pitch - 90.0) < 0.5 and below.y < -0.99 and angle_s.get_meta("slider").value == angle_s.get_meta("slider").max_value and game.settings["angle"] == 90.0, "Angle 90° looks straight down, and the slider stops there rather than wrapping")
		for n in cam.DRIVE_ZOOMS.size() + 1:
			_slide(drive_s, -1)
		_check(cam.drive_zoom == 0.0 and drive_s.get_meta("value").text == "Off" and drive_s.get_meta("slider").value == 0, "Drive zoom-out goes down to Off")
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
	# faster than 45 degrees a second (0.21: faster made Sachin dizzy).
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
	_check(turned < -deg_to_rad(20.0), "leaning the stick right turns the car right (%.0f degrees)" % rad_to_deg(-turned))
	Controls.override_vector = Vector2(0, -1)
	for f in 180:
		await _frames(1)
		max_rate = maxf(max_rate, rad_to_deg(absf(wrapf(cam.yaw - last, -PI, PI))) * 60.0)
		last = cam.yaw
	var face: float = TopDownCamera._heading(-car.global_basis.z)
	var lag: float = absf(wrapf(cam.yaw - face, -PI, PI))
	_check(lag < deg_to_rad(4.0), "out of the turn the view settles behind the car within 3 s (%.1f degrees off)" % rad_to_deg(lag))
	_check(max_rate <= 45.5, "the view turns at most 45 degrees a second (%.0f)" % max_rate)
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
	# found too little of it): 70 m or more, 2.2 s or more at a sedan's top
	# speed (31 m/s since 0.21; at 0.20's 20.5 m/s it was 3.3 s).
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
		var want: float = 70.0 if kind == "super" else maxf(70.0, fast.speed * 2.2)
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


## Settings > Camera turn "90° turns" (H-17): the view holds through
## steering and dodges, and turns a whole quarter only once the car or the
## walk has been a corner off it for STEP_HOLD. Also Follow's Drive zoom-out
## (H-15), the stick's frame through a slow thumb drift and a brush of the
## dead zone, and letting go mid-turn (H-18), and the HUD gear.
## Getting into a car swings the view behind it at the quick caps; driving
## off before that swing lands hands the turn back to the calm 45 degrees a
## second (review 2026-10-28: the quick caps stayed on through later turns).
func test_new_car_swing_calms_when_driving() -> void:
	await _free_game()
	var TopDownCamera = preload("res://scripts/top_down_camera.gd")
	var cam = TopDownCamera.new()
	add_child(cam)
	var p = preload("res://scripts/player.gd").new()
	p.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(p)
	cam.target = p
	Controls.camera = cam
	cam.snap()
	await _frames(5)
	# The car faces 135 degrees off the view, and the stick turns it at once.
	var car = _player_car("sedan", Vector3(0, 0, 400.0), 0.0, PI * 0.75)
	p.vehicle = car
	Controls.override_vector = Vector2(0.6, -0.8)
	var max_rate := 0.0
	var late := 0
	var last: float = cam.yaw
	for f in 300:
		await _frames(1)
		if car.speed > TopDownCamera.YAW_MIN_SPEED:
			late += 1
		# A second after driving off the swing's spare speed is braked away.
		if late > 60:
			max_rate = maxf(max_rate, rad_to_deg(absf(wrapf(cam.yaw - last, -PI, PI))) * 60.0)
		last = cam.yaw
	Controls.override_vector = null
	_check(late > 120 and max_rate <= 45.5, "driving off mid-swing in a new car, the view turns at most 45 degrees a second (%.0f, %d frames moving)" % [max_rate, late])
	cam.queue_free()
	p.queue_free()
	car.queue_free()


func test_camera_ninety_turns() -> void:
	await _free_game()
	var TopDownCamera = preload("res://scripts/top_down_camera.gd")
	var cam = TopDownCamera.new()
	add_child(cam)
	var p = preload("res://scripts/player.gd").new()
	p.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(p)
	cam.target = p
	Controls.camera = cam
	# Follow, flat out: Drive zoom-out sets how far the view widens and how
	# far it flattens.
	var car = _player_car("sedan", Vector3(0, 0, 400.0), 0.0)
	p.vehicle = car
	cam.snap()
	Controls.override_vector = Vector2(0, -1)
	await _frames(240)
	var fits := true
	var report := []
	for dz in [1.0, 0.5, 0.0]:
		cam.drive_zoom = dz
		await _frames(240)
		var want: float = lerpf(cam.FOOT_SIZE, cam.TURN_DRIVE_SIZE, minf(car.speed / cam.TURN_FULL_SPEED, 1.0) * dz)
		var flat: float = snappedf(cam.TURN_FLATTEN * clampf((car.speed - 8.0) / (cam.TURN_FULL_SPEED - 8.0), 0.0, 1.0), 5.0) * dz
		if car.speed < 15.0 or absf(cam.size - want) > 1.5 or absf(cam._flatten - flat) > 0.01 or (dz > 0.0 and flat == 0.0):
			fits = false
		report.append("%d%% %.0f m, %.1f degrees flatter" % [roundi(dz * 100.0), cam.size, cam._flatten])
	cam.drive_zoom = 1.0
	_check(fits, "in Follow, flat out (%.0f m/s), Drive zoom-out sets the framing and the flatten: %s" % [car.speed, ", ".join(report)])
	# 90° turns: a lane change moves the car, not the view.
	cam.turn_steps = true
	cam.recenter()
	await _frames(60)
	_check(absf(cam.yaw) < 0.01, "90° turns: driving straight north the view stays north (%.1f degrees)" % rad_to_deg(cam.yaw))
	var max_yaw := 0.0
	var h0: float = TopDownCamera._heading(-car.global_basis.z)
	Controls.override_vector = Vector2(0.35, -0.94)
	for f in 30:
		await _frames(1)
		max_yaw = maxf(max_yaw, absf(cam.yaw))
	var steered: float = absf(wrapf(TopDownCamera._heading(-car.global_basis.z) - h0, -PI, PI))
	Controls.override_vector = Vector2(0, -1)
	for f in 90:
		await _frames(1)
		max_yaw = maxf(max_yaw, absf(cam.yaw))
	_check(steered > deg_to_rad(5.0) and max_yaw < 0.01, "a %.0f-degree steer leaves the view where it is (moved %.2f degrees)" % [rad_to_deg(steered), rad_to_deg(max_yaw)])
	# A corner: the view waits STEP_HOLD past 80 degrees, then turns to east.
	Controls.override_vector = Vector2(0.7, -0.7)
	var off_at := -1
	var moved_at := -1
	for f in 480:
		await _frames(1)
		var h: float = TopDownCamera._heading(-car.global_basis.z)
		if h < -deg_to_rad(85.0):
			Controls.override_vector = Vector2(0, -1)
		if off_at < 0 and h < -cam.STEP_TURN:
			off_at = f
		if moved_at < 0 and absf(cam.yaw) > 0.01:
			moved_at = f
	_check(off_at >= 0 and moved_at - off_at >= int(cam.STEP_HOLD * 60.0) - 1, "turning a corner the view holds until the car is %.0f degrees round for %.1f s (waited %.2f s)" % [rad_to_deg(cam.STEP_TURN), cam.STEP_HOLD, (moved_at - off_at) / 60.0])
	_check(absf(cam.yaw + PI * 0.5) < 0.02, "then it turns a whole quarter, square to the streets (%.1f degrees; the car heads %.0f)" % [rad_to_deg(cam.yaw), rad_to_deg(TopDownCamera._heading(-car.global_basis.z))])
	# On foot: a quick sidestep does not turn the view, a held one does.
	Controls.override_vector = null
	p.vehicle = null
	car.queue_free()
	cam.yaw = 0.0
	cam._yaw_goal = 0.0
	cam._yaw_rate = 0.0
	cam._yaw_chasing = false
	cam._yaw_forced = false
	await _frames(30)
	# Two of them, a second apart: short swings never add up to a turn.
	max_yaw = 0.0
	for i in 2:
		Controls.override_vector = Vector2(1, 0)
		p.velocity = Vector3(4.2, 0, 0)
		for f in 15:
			await _frames(1)
			max_yaw = maxf(max_yaw, absf(cam.yaw))
		Controls.override_vector = null
		p.velocity = Vector3.ZERO
		for f in 60:
			await _frames(1)
			max_yaw = maxf(max_yaw, absf(cam.yaw))
	_check(max_yaw < 0.01, "on foot two quarter-second sidesteps a second apart leave the view where it is (moved %.2f degrees)" % rad_to_deg(max_yaw))
	Controls.override_vector = Vector2(1, 0)
	p.velocity = Vector3(4.2, 0, 0)
	await _frames(2)
	var frame: Vector3 = cam.input_axes()[0]
	await _frames(300)
	_check(absf(cam.yaw + PI * 0.5) < 0.02 and cam.input_axes()[0].dot(frame) > 0.9999, "walking sideways on, the view turns a quarter (%.1f degrees) and the walk runs straight" % rad_to_deg(cam.yaw))
	Controls.override_vector = null
	p.velocity = Vector3.ZERO
	await _frames(120)
	_check(absf(cam.yaw + PI * 0.5) < 0.02, "standing still, it stays on the quarter")
	# Follow: a slow thumb drift mid-turn bends the walk only by the drift
	# (the frame holds, so the walk never jumps or spirals).
	cam.turn_steps = false
	cam.yaw = 0.0
	cam._yaw_goal = 0.0
	cam._yaw_rate = 0.0
	cam._yaw_chasing = false
	cam._yaw_forced = false
	await _frames(90)
	Controls.override_vector = Vector2(1, 0)
	p.velocity = Vector3(4.2, 0, 0)
	await _frames(2)
	frame = cam.input_axes()[0]
	await _frames(60)
	var turned_by: float = cam.yaw
	var w0: float = TopDownCamera._heading(Controls.world_move())
	for f in 30:
		var a := deg_to_rad(f + 1.0)
		Controls.override_vector = Vector2(cos(a), -sin(a))
		await _frames(1)
	var bent: float = wrapf(TopDownCamera._heading(Controls.world_move()) - w0, -PI, PI)
	_check(turned_by < -deg_to_rad(20.0) and absf(bent - deg_to_rad(30.0)) < deg_to_rad(2.0) and cam.input_axes()[0].dot(frame) > 0.9999, "mid-turn (view at %.0f degrees), drifting the thumb 30 degrees up bends the walk %.1f degrees left and keeps the frame" % [rad_to_deg(turned_by), rad_to_deg(bent)])
	# Brushing the dead zone for a moment keeps the frame too.
	var held_stick = Controls.override_vector
	Controls.override_vector = Vector2.ZERO
	await _frames(4)
	Controls.override_vector = held_stick
	await _frames(2)
	_check(cam.input_axes()[0].dot(frame) > 0.9999 and absf(wrapf(TopDownCamera._heading(Controls.world_move()) - w0 - bent, -PI, PI)) < 0.01, "a thumb brushing the dead zone keeps the frame, so the walk carries straight on")
	# Letting go mid-turn: the view eases to a stop, never faster.
	Controls.override_vector = null
	p.velocity = Vector3.ZERO
	cam.yaw = 0.0
	cam._yaw_goal = 0.0
	cam._yaw_rate = 0.0
	cam._yaw_chasing = false
	cam._yaw_forced = false
	await _frames(30)
	Controls.override_vector = Vector2(1, 0)
	p.velocity = Vector3(4.2, 0, 0)
	await _frames(40)
	var last: float = cam.yaw
	await _frames(1)
	var moving: float = rad_to_deg(absf(wrapf(cam.yaw - last, -PI, PI))) * 60.0
	var rate := 0.0
	last = cam.yaw
	var let_go: float = cam.yaw
	Controls.override_vector = null
	p.velocity = Vector3.ZERO
	for f in 60:
		await _frames(1)
		rate = maxf(rate, rad_to_deg(absf(wrapf(cam.yaw - last, -PI, PI))) * 60.0)
		last = cam.yaw
	var coast: float = absf(wrapf(cam.yaw - let_go, -PI, PI))
	_check(moving > 30.0 and rate <= moving + 0.5 and coast < deg_to_rad(12.0), "letting go mid-turn (view at %.0f degrees, turning %.0f degrees a second), it eases to a stop %.1f degrees on, never faster" % [rad_to_deg(let_go), moving, rad_to_deg(coast)])
	await _frames(150)
	_check(absf(wrapf(cam.yaw - snappedf(last, PI * 0.5), -PI, PI)) < 0.02, "then squares up with the streets once (%.1f degrees)" % rad_to_deg(cam.yaw))
	p.queue_free()
	cam.queue_free()
	Controls.camera = null
	# In the game: the setting cycles through the gear's Settings.
	await _new_game(false)
	cam = game.camera
	var phone = game.hud.phone
	var opened: int = phone.open_count
	game.hud.settings_button.pressed.emit()
	await _frames(1)
	_check(phone.visible and phone.settings_page.visible and phone.open_count == opened, "the HUD gear opens Settings (and does not count as checking the phone)")
	phone.settings_page.show_tab("Camera")
	var turn_s = phone.settings_page.sliders["Camera turn"]
	var seen := []
	for i in 3:
		turn_s.get_meta("slider").value = i
		seen.append("%s/%s" % [turn_s.get_meta("value").text, str(game.settings.get("camera_turn"))])
	_check(seen == ["Follow/car", "90° turns/steps", "North up/north"] and not cam.turn_view, "Settings > Camera turn slides: %s" % ", ".join(seen))
	game.settings["camera_turn"] = "steps"
	game.apply_settings()
	_check(cam.turn_view and cam.turn_steps, "a saved 90° turns loads as 90° turns")
	game.settings["camera_turn"] = "north"
	game.apply_settings()
	phone.close()
	await _frames(1)

func test_settings_page_tabs_and_preview() -> void:
	await _new_game(false)
	var cam = game.camera
	var phone = game.hud.phone
	var page = phone.settings_page
	game.hud.settings_button.pressed.emit()
	await _idle(2)
	_check(page.visible and not phone._frame.visible and get_tree().paused and page._back.text == "CLOSE", "the gear opens the full-screen Settings page with the game paused")
	_check(cam.process_mode == Node.PROCESS_MODE_ALWAYS and page.preview.render_target_update_mode == SubViewport.UPDATE_ALWAYS and page.get_viewport().disable_3d, "while it is open the camera runs, the preview draws and the hidden game view does not")
	# Every tab, each setting with a line under it saying what it does.
	var want := {"Camera": ["View: ", "Look down near towers: ", "Camera turn", "Screen shake", "Reset camera", "Distance", "Drive zoom-out", "Angle"],
		"Graphics": ["Quality", "Bloom: ", "Smooth edges: ", "Vivid colour: ", "Real lights: ", "Detail: ", "Shadows: ", "FPS limit", "Show FPS: "],
		"Controls": ["Driving"],
		"Game": ["Weather", "Skip 3 hours", "Blood: ", "New game", "Log: ", "BUG button: ", "Report issue", "Export log", "Copy log"]}
	for t in page.TABS:
		page.show_tab(t)
		await _idle(1)
		var missing := []
		for w in want[t]:
			if _find_button(page._list, w) == null and not page.sliders.has(w):
				missing.append(w)
		var hinted := true
		# The Log section's heading and status line sit outside the rows.
		var kids: Array = page._list.get_children().filter(func(k): return not k.has_meta("section"))
		for i in range(0, kids.size(), 3):
			hinted = hinted and kids[i + 1] is Label and kids[i + 1].text.length() > 20
		_check(missing.is_empty() and hinted and kids.size() == want[t].size() * 3 and page._tabs[t].button_pressed, "tab %s has its settings, each with a hint (missing %s)" % [t, missing])
	# The preview follows a change while the game stays paused.
	page.show_tab("Camera")
	var spot: Vector3 = game.player.global_position
	var before: float = cam.size
	_slide(page.sliders["Distance"], 1)
	_slide(page.sliders["Distance"], 1)
	await _idle(150)
	_check(cam.zoom == 1.3 and cam.size > before * 1.2 and absf(page.preview_cam.size - cam.size) < 0.01 and page.preview_cam.global_transform.origin.distance_to(cam.global_transform.origin) < 0.01 and get_tree().paused and game.player.global_position.distance_to(spot) < 0.01, "Distance 130%% eases the paused view out from %.1f to %.1f m, and the preview matches it" % [before, cam.size])
	var foot: float = cam.size
	_slide(page.sliders["Drive zoom-out"], -1)
	await _idle(150)
	_check(cam.preview_drive and page._drive_b.text.ends_with("Driving fast") and cam.size > foot * 1.5, "touching Drive zoom-out previews driving fast (%.1f m at 75%%)" % cam.size)
	page._drive_b.pressed.emit()
	await _idle(150)
	_check(not cam.preview_drive and absf(cam.size - foot) < 1.0, "Preview: As now goes back to the walking view (%.1f m)" % cam.size)
	# FPS limit.
	page.show_tab("Graphics")
	var fps = page.sliders.get("FPS limit")
	_check(fps != null and fps.get_meta("value").text == "120" and fps.get_meta("slider").value == fps.get_meta("slider").max_value, "FPS limit starts at 120, the top of the list")
	_slide(fps, -1)
	_slide(fps, -1)
	_check(game.settings["fps_limit"] == 75 and game.fps_limit() == 75 and fps.get_meta("value").text == "75" and Engine.max_fps == 0, "FPS limit two steps down gives 75 (headless runs stay uncapped)")
	for n in 5:
		_slide(fps, -1)
	_check(game.fps_limit() == 30 and fps.get_meta("slider").value == 0, "and stops at 30")
	var odd := []
	for v in [45, "60", null, 90.0]:
		game.settings["fps_limit"] = v
		odd.append(game.fps_limit())
	_check(odd == [120, 120, 120, 90], "a saved limit not on the list loads as 120: %s" % [odd])
	game.settings["fps_limit"] = 120
	# Scrolling: buttons let drags through to the list, and a drag that
	# becomes a scroll cancels the button it began on.
	var stops := 0
	for b in page._list.find_children("*", "BaseButton", true, false) + page._list.find_children("*", "Slider", true, false) + phone._body.find_children("*", "BaseButton", true, false):
		if b.mouse_filter != Control.MOUSE_FILTER_PASS:
			stops += 1
	_check(stops == 0 and page._scroll.get_v_scroll_bar().custom_minimum_size.x >= 36 and page._scroll.scroll_deadzone > 0, "list buttons and sliders pass drags to their scroll, which has a wide bar")
	await _idle(2)
	var db = _find_button(page._list, "Detail: ")
	# Window pixels (the headless window is tiny and stretched).
	var at: Vector2 = get_viewport().get_final_transform() * db.get_global_rect().get_center()
	await _tap(at, false)
	_check(game.settings["detail"] == "low" and db.text == "Detail: LOW" and db.size.x > 400, "a tap on Detail switches it (the button spans the list, %.0f px)" % db.size.x)
	await _tap(at, true)
	_check(game.settings["detail"] == "low", "a drag that scrolls the list does not")
	await _tap(at, false)
	# The game stays paused, so the page keeps the preview's world current:
	# the light and headlights after a clock skip, the weather at once and
	# the streets a wider view takes in.
	var atm = game.atmosphere
	atm.hour = 12.0
	await _idle(20)
	var day_sun: float = atm.sun.light_energy
	var car = Vehicle.new()
	car.kind = "sedan"
	game.add_child(car)
	car.global_position = game.player.global_position + Vector3(8, 0, 0)
	car.driver = Vehicle.Driver.PLAYER
	await _idle(2)
	var lit: bool = car.headlights_on()
	page.show_tab("Game")
	for i in 4:
		_find_button(page._list, "Skip 3 hours").pressed.emit()
	await _idle(20)
	_check(get_tree().paused and atm.hour == 0.0 and not is_equal_approx(atm.sun.light_energy, day_sun) and not lit and car.headlights_on() and car._lamp_glow.visible, "skipping to midnight while paused relights the preview and turns the headlights on")
	car.queue_free()
	var weather_was = game.settings.get("weather", "auto")
	var wb = page.sliders["Weather"]
	wb.get_meta("slider").value = wb.get_meta("values").find("rain")
	_check(wb.get_meta("value").text == "Rain" and is_equal_approx(atm.rain, 0.6) and is_equal_approx(atm.clouds, 0.85) and atm._rain.can_process(), "Weather rain shows at once in the paused preview, drops falling (rain %.2f)" % atm.rain)
	game.settings["weather"] = weather_was
	atm.set_weather("clear", true)
	page.show_tab("Camera")
	game.settings["zoom"] = 1.3
	game.apply_settings()
	page._preview_driving(true)
	var missing := -1
	for i in 60:
		await _idle(10)
		missing = 0
		for c in game.city._cells_near(cam.stream_point(), game.city.get_script().LOAD_RADIUS):
			if not game.city._loaded.has(c):
				missing += 1
		if missing == 0:
			break
	_check(missing == 0, "zoomed out and driving fast, the paused preview builds the streets it frames (%d missing)" % missing)
	page._preview_driving(false)
	game.settings["zoom"] = 1.0
	game.apply_settings()
	atm.hour = 12.0
	# BACK, from the phone's own Settings app, returns to the apps.
	phone.close()
	phone.open()
	phone._settings()
	_check(page.visible and page._back.text == "BACK", "the phone's Settings app opens the page with BACK")
	phone._on_back()
	_check(phone.visible and not page.visible and phone._frame.visible and get_tree().paused and not page.get_viewport().disable_3d, "BACK returns to the phone's apps and draws the game again")
	phone.close()
	_check(not get_tree().paused and cam.process_mode == Node.PROCESS_MODE_INHERIT and atm._rain.process_mode == Node.PROCESS_MODE_INHERIT and page.preview.render_target_update_mode == SubViewport.UPDATE_DISABLED and not cam.preview_drive, "closing puts the camera back to pausing with the game and stops the preview")
	game.settings["zoom"] = 1.0
	game.settings["drive_zoom"] = 1.0
	game.apply_settings()


## Presses and releases the left button at `at`; `scroll` has the list start
## a drag-scroll in between.
func _tap(at: Vector2, scroll: bool) -> void:
	var page = game.hud.phone.settings_page
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.position = at
	ev.global_position = at
	ev.pressed = true
	get_viewport().push_input(ev)
	await _idle(1)
	if scroll:
		page._scroll.scroll_started.emit()
	var up: InputEventMouseButton = ev.duplicate()
	up.pressed = false
	get_viewport().push_input(up)
	await _idle(1)


## Waits `n` drawn frames (these run while the game is paused).
func _idle(n: int) -> void:
	for i in n:
		await get_tree().process_frame


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


## Settings > Graphics > Quality sets every effect; a toggle changed by hand
## marks the preset with a *; old saves without the new keys get High.
func test_look_up_at_the_sky() -> void:
	await _new_game(false)
	var cam = game.camera
	var env: Environment = game.atmosphere.env
	_check(game.hud.sky_button.visible and cam.can_look_up(), "on foot outdoors the SKY button shows")
	_check(not SkyDome.looks_at_sky(cam), "the usual view looks down, no sky in it")
	game.hud.sky_button.pressed.emit()
	for i in 600:
		if cam.look_up_amount() >= 1.0:
			break
		await _idle(1)
	var fwd: Vector3 = -cam.global_basis.z
	_check(cam.looking_up and cam.look_up_amount() >= 1.0, "SKY rises into Look up")
	_check(fwd.y > 0.45 and SkyDome.looks_at_sky(cam) and env.fog_enabled, "Look up faces the sky 35 degrees up, with the horizon haze on (forward y %.2f)" % fwd.y)
	_check(cam.global_position.distance_to(game.player.global_position + Vector3.UP * 1.7) < 3.0, "the eye sits over the player's shoulder")
	var yaw_before: float = cam.look_yaw
	var drag := InputEventScreenDrag.new()
	drag.relative = Vector2(40, 30)
	cam._unhandled_input(drag)
	_check(not is_equal_approx(cam.look_yaw, yaw_before) and cam.look_pitch > cam.LOOK_UP_PITCH, "dragging looks round and higher")
	# Getting in a car ends it and the view comes back down.
	var car = _track_car("sedan", game.player.global_position + Vector3(3, 0, 0), 0.0)
	await _frames(2)
	game.player.enter_vehicle(car)
	for i in 600:
		if cam.look_up_amount() <= 0.0:
			break
		await _idle(1)
	_check(not cam.looking_up and cam.look_up_amount() == 0.0 and not env.fog_enabled and not game.hud.sky_button.visible, "in a car Look up ends, the haze goes and the button hides")
	_check(not SkyDome.looks_at_sky(cam), "the view is back down on the street")
	game.player.exit_vehicle()
	car.queue_free()


func test_graphics_quality_presets() -> void:
	await _new_game(false)
	var G = game.Graphics
	var s: Dictionary = game.settings
	var env: Environment = game.atmosphere.env
	_check(s.quality == "high" and env.glow_enabled and env.adjustment_enabled and get_viewport().msaa_3d == Viewport.MSAA_DISABLED and game.graphics.cars == 2 and game.graphics.lamps == 4, "a new game starts on High: bloom and vivid colour on, no MSAA, 2 car and 4 lamp lights")
	G.pick(s, "ultra")
	game.apply_settings()
	_check(env.glow_enabled and get_viewport().msaa_3d == Viewport.MSAA_4X and game.graphics.cars == 2 and not game.graphics.car_shadow, "Ultra adds 4x MSAA but keeps two car lights and no headlight shadow (0.22: 20 fps on a phone)")
	G.pick(s, "low")
	game.apply_settings()
	_check(not env.glow_enabled and not env.adjustment_enabled and not game.atmosphere.sun.shadow_enabled and s.detail == "low" and game.graphics.cars == 1 and game.graphics.lamps == 0 and is_equal_approx(get_viewport().scaling_3d_scale, 0.8), "Low: no bloom, shadows or vivid colour, low detail, 80% 3D scale, only the player's headlights are real")
	G.pick(s, "medium")
	s["real_lights"] = false
	game.apply_settings()
	_check(game.graphics.cars == 0 and game.graphics.lamps == 0 and is_equal_approx(get_viewport().scaling_3d_scale, 1.0), "Real lights OFF gives no real lights at all")
	# The page: the slider picks the preset and redraws the toggles.
	var page = game.hud.phone.settings_page
	game.hud.settings_button.pressed.emit()
	await _idle(2)
	page.show_tab("Graphics")
	await _idle(1)
	var row = page.sliders["Quality"]
	_check(row.get_meta("value").text == "Medium *", "the page shows Medium * (changed by hand), got %s" % row.get_meta("value").text)
	_slide(row, 1)
	await _idle(2)
	row = page.sliders["Quality"]
	_check(s.quality == "high" and s.real_lights and s.bloom and row.get_meta("value").text == "High" and row.get_meta("slider").value == 2 and _find_button(page._list, "Bloom: ON") != null, "a step up slides to High, which sets every effect back (got %s)" % row.get_meta("value").text)
	_find_button(page._list, "Bloom: ON").pressed.emit()
	await _idle(1)
	_check(not env.glow_enabled and row.get_meta("value").text == "High *", "turning Bloom off works at once and marks the preset")
	page._back.pressed.emit()
	await _idle(2)
	# A save from before 0.21 has none of the new keys.
	var old := {"shadows": true, "detail": "high"}
	var fresh: Dictionary = game.settings.duplicate()
	fresh.merge(old, true)
	_check(fresh.has("quality") and fresh.has("bloom"), "keys missing from an old save keep their defaults")


## After dark the nearest cars and street lamps get real lights (they light
## the road, kerbs, walls and people round them); further off, the painted
## glow stays. Knocked-down lamps and wrecked cars go dark.
## A police car's light bar lights the road only where the preset's budget
## has room for it (High and Ultra); on Low and Medium the bar still flashes
## but adds no light (review 2026-10-28: Low ran 2 lights for 1 allowed).
func test_police_bar_light_budget() -> void:
	await _free_game()
	var Graphics = preload("res://scripts/graphics.gd")
	_check(not Graphics.PRESETS.low.bars and not Graphics.PRESETS.medium.bars and Graphics.PRESETS.high.bars and Graphics.PRESETS.ultra.bars,
		"the light bar lights the road on High and Ultra only")
	# As PoliceManager.spawn_car_at builds one, on duty with its bar flashing.
	var car = Vehicle.new()
	car.kind = "police"
	car.is_police = true
	car.driver = Vehicle.Driver.POLICE
	car.position = Vector3(0, 0, 400.0)
	add_child(car)
	await _frames(2)
	car.set_real_light(true, 3.0, false, false)
	car._flash_lights(0.1)
	var none: bool = car._bar_light == null
	car.set_real_light(true, 3.0, false, true)
	car._flash_lights(0.1)
	var shown: bool = car._bar_light != null and car._bar_light.visible
	car.set_real_light(true, 3.0, false, false)
	car._flash_lights(0.1)
	_check(none and shown and not car._bar_light.visible, "no bar light within a small budget, a flashing one within a big one, dark again when the budget shrinks")
	car.queue_free()


func test_real_lights_at_night() -> void:
	await _new_game(false)
	game.atmosphere.hour = 22.0
	var car = _spawn_car(_home(), Vector3(0, 0, -3), 0.0)
	_place_player(_home(), Vector3.ZERO)
	await _frames(2)
	await _press("interact")
	var other = _spawn_car(_home(), Vector3(4, 0, -12), 0.0)
	other.driver = Vehicle.Driver.SCRIPT
	var far = _spawn_car(_home(), Vector3(-4, 0, -30), 0.0)
	far.driver = Vehicle.Driver.SCRIPT
	await _frames(5)
	var gfx = game.graphics
	gfx.rescan()
	_check(game.player.vehicle == car and car._real_light != null and car._real_light.visible and car._real_light.light_energy > 2.0, "the player's car gets a real headlight at night")
	_check(not car._beams.visible and car._lamp_glow.visible, "a car with a real light drops the painted beams but keeps its lamp glow")
	_check(gfx.lit_cars.size() == 2 and gfx.lit_cars.has(other) and not gfx.lit_cars.has(far) and far._beams.visible, "High lights the 2 nearest cars; the third keeps painted beams")
	var spot: SpotLight3D = car._real_light
	var ahead: Vector3 = -spot.global_transform.basis.z
	_check(ahead.dot(-car.global_transform.basis.z) > 0.9 and ahead.y < -0.05 and spot.spot_range >= 25.0, "the headlight points ahead and a little down, %.0f m long" % spot.spot_range)
	var lit: Array = gfx.lit_lamps()
	var ok := lit.size() > 0
	var worst := 0.0
	for shape in lit:
		var info: Dictionary = shape.get_meta("brk")
		var light_y: float = shape.global_position.y + info.light.y
		var ground: float = shape.global_position.y - (shape.shape as BoxShape3D).size.y * 0.5
		var want := 5.85 if info.kind == "street_light" else 3.35
		worst = maxf(worst, absf(light_y - ground - want))
	_check(ok and lit.size() <= 4 and worst < 0.1, "the nearest street lamps (%d) light up, at their heads (worst %.2f m off)" % [lit.size(), worst])
	if ok:
		var shape = lit[0]
		shape.get_meta("brk")["down"] = true
		gfx.rescan()
		_check(not gfx.lit_lamps().has(shape), "a knocked-down lamp goes dark")
	other.wrecked = true
	gfx.rescan()
	_check(not gfx.lit_cars.has(other) and not other._real_light.visible, "a wrecked car's lights go out")
	game.atmosphere.hour = 12.0
	await _frames(3)
	gfx.rescan()
	_check(not car._real_light.visible and gfx.lit_lamps().is_empty() and not car._beams.visible, "by day no real lights are on")


## Head and tail lights lie on the ground, so they show on hills too (they
## were flat at the car's height and sank into the road going uphill).
func test_headlights_follow_the_ground() -> void:
	await _new_game(false)
	game.atmosphere.hour = 22.0
	var tex: Texture2D = Terrain.height_texture
	_check(tex != null and tex.get_width() == Terrain.nx and tex.get_height() == Terrain.ny, "the country height grid is handed to the shaders (%dx%d, %.0f m cells)" % [Terrain.nx, Terrain.ny, Terrain.cell])
	# The texture holds the heights the shader reads back, to the decimetre.
	var img := tex.get_image()
	var top := 0
	for k in Terrain.heights.size():
		if Terrain.heights[k] > Terrain.heights[top]:
			top = k
	var worst := 0.0
	for k in [top, top + 1, Terrain.nx * (Terrain.ny / 2) + Terrain.nx / 3, Terrain.heights.size() - 1]:
		var px := img.get_pixel(k % Terrain.nx, k / Terrain.nx)
		var h := (roundf(px.r * 255.0) + roundf(px.g * 255.0) * 256.0) * 0.1
		worst = maxf(worst, absf(h - Terrain.heights[k]))
	_check(Terrain.heights[top] > 50.0 and worst < 0.06, "decoded heights match the grid (top %.1f m, worst error %.2f m)" % [Terrain.heights[top], worst])
	var at := Vector2(760, -1150)
	var pos := Vector3(at.x, Terrain.height(at.x, at.y), at.y)
	game.city.stream_now(pos)
	game.player.global_position = pos + Vector3(6, 0, 0)
	var car = Vehicle.new()
	car.kind = "sedan"
	game.add_child(car)
	car.global_position = pos
	car.driver = Vehicle.Driver.PLAYER
	await _frames(10)
	var beams: MeshInstance3D = car._beams
	car.set_real_light(false)
	_check(beams.visible and beams.material_override == MeshBuilder.ground_glow_material() and car._lamp_glow.visible and car._lamp_glow.material_override == MeshBuilder.glow_material(), "at night, with no real light to spare, the beams and tail pool are drawn on the ground; the lamp glows stay at the lamps")
	car.queue_free()


# --- Sky and birds (sky.gd, birds.gd) ----------------------------------------------

## The sky shader draws the sun's disc on the scene light's bearing at every
## daylight hour (on the light itself from 8 to 16, sinking to the horizon at
## sunrise and sunset), the moon by night with its phase moving on each day,
## and gives way to the plain room colour indoors. Look up points a camera
## at the sky; the game's own top-down camera frames none of it.
func test_sky_follows_the_sun_and_moon() -> void:
	await _new_game(false)
	var SkyDome = load("res://scripts/sky.gd")
	var atm = game.atmosphere
	atm.minutes_per_second = 0.0
	atm.weather_changes = false
	atm.set_weather("clear", true)
	var env: Environment = atm.env
	var mat: ShaderMaterial = atm.sky.material
	_check(env.background_mode == Environment.BG_SKY and env.sky != null and env.sky.sky_material == mat and mat.shader.get_mode() == Shader.MODE_SKY, "the world's background is the sky shader")
	var worst_bearing := 0.0
	var worst_mid := 0.0
	var worst_param := 0.0
	for h in [6.2, 7.0, 8.0, 10.0, 12.0, 14.0, 16.0, 17.0, 17.8]:
		atm.hour = h
		atm._apply(0.0)
		var light: Vector3 = atm.sun.transform.basis.z.normalized()
		var disc: Vector3 = atm.sky.sun_dir
		worst_bearing = maxf(worst_bearing, absf(rad_to_deg(Vector2(light.x, light.z).angle_to(Vector2(disc.x, disc.z)))))
		if h >= 8.0 and h <= 16.0:
			worst_mid = maxf(worst_mid, rad_to_deg(light.angle_to(disc)))
		var shown: Vector3 = mat.get_shader_parameter("sun_dir")
		worst_param = maxf(worst_param, rad_to_deg(shown.angle_to(disc)))
	_check(worst_bearing < 0.5 and worst_mid < 0.5 and worst_param < 0.01, "the sun disc is on the light's bearing all day (worst %.2f deg) and on the light from 8 to 16 (worst %.2f deg); the shader draws it there" % [worst_bearing, worst_mid])
	atm.hour = 6.2
	atm._apply(0.0)
	var low: float = rad_to_deg(asin(atm.sky.sun_dir.y))
	_check(low < 8.0 and atm.sky.sun_amount > 0.9, "at 6:12 the sun is just up in the east (%.1f deg high, bearing %.0f)" % [low, rad_to_deg(atan2(atm.sky.sun_dir.x, -atm.sky.sun_dir.z))])
	atm.hour = 22.0
	atm._apply(0.0)
	var night_light: Vector3 = atm.sun.transform.basis.z.normalized()
	var phase0: float = atm.sky.moon_phase
	_check(atm.sky.sun_amount == 0.0 and atm.sky.sun_dir.y < 0.0 and atm.sky.moon_amount > 0.9 and atm.sky.moon_dir.angle_to(night_light) < 0.01 and atm.sky.moon_dir.y > 0.3, "at night the sun is down and the moon is up where the light comes from")
	for h in [23.5, 3.0, 12.0, 22.0]:
		atm.hour = h
		atm._apply(0.0)
	var moved := fposmod(atm.sky.moon_phase - phase0, 1.0)
	_check(atm.sky.day == 1 and absf(moved - 1.0 / SkyDome.LUNAR_DAYS) < 0.001, "a day later the moon's phase has moved on by 1/%d (%.3f)" % [int(SkyDome.LUNAR_DAYS), moved])
	atm.indoors = true
	atm._apply(0.0)
	await _frames(2)
	_check(env.background_mode == Environment.BG_COLOR and not atm.birds.view.visible, "indoors: a plain dark background and no birds")
	atm.indoors = false
	atm._apply(0.0)
	_check(env.background_mode == Environment.BG_SKY, "back outside, the sky")
	# Look up: a camera at eye height facing a bearing and a pitch.
	var cam := Camera3D.new()
	game.add_child(cam)
	var at := Vector3(1200.0, Terrain.height(1200.0, -1300.0), -1300.0)
	var xf: Transform3D = SkyDome.look_up(cam, env, at, 90.0, 30.0)
	var fwd := -xf.basis.z
	_check(absf(rad_to_deg(asin(fwd.y)) - 30.0) < 0.1 and absf(rad_to_deg(atan2(fwd.x, -fwd.z)) - 90.0) < 0.1 and absf(xf.origin.y - at.y - 1.7) < 0.01 and SkyDome.looks_at_sky(cam) and env.fog_enabled, "Look up: eye high on the hill, 30 degrees up facing east, the sky in frame and the ground hazed into it")
	SkyDome.horizon_haze(env, false)
	cam.queue_free()
	_check(not env.fog_enabled and not SkyDome.looks_at_sky(game.camera), "the top-down view frames no sky (so the sky is redrawn only 4 times a second)")


## Stars by light pollution: few and faint downtown, more in the suburbs, the
## whole sky and the Milky Way from the dark hills, a beach and the edge of
## the desert; none by day or under cloud. An orange glow hangs over the
## city: all round downtown, a dome over the town on its bearing from out of
## town.
func test_stars_by_light_pollution() -> void:
	await _new_game(false)
	var SkyDome = load("res://scripts/sky.gd")
	var atm = game.atmosphere
	atm.minutes_per_second = 0.0
	atm.weather_changes = false
	atm.set_weather("clear", true)
	var places := [["downtown", Vector2(300, 250)], ["suburbs", Vector2(-350, 100)], ["hills", Vector2(1200, -1300)], ["beach", Vector2(-2033, 1791)], ["desert edge", Vector2(-2667, -1959)]]
	var night := {}
	var text := ""
	var by_day := 0.0
	var clouded := 0.0
	var day_glow := 0.0
	for place in places:
		var p: Vector2 = place[1]
		game.player.global_position = Vector3(p.x, Terrain.height(p.x, p.y) + 0.5, p.y)
		atm.hour = 23.0
		atm._apply(0.0)
		night[place[0]] = [atm.sky.stars, atm.sky.milky, atm.sky.glow_amount, atm.sky.material.get_shader_parameter("stars"), SkyDome.glow_at(p), atm.sky.material.get_shader_parameter("glow_lobe")]
		text += " %s %.2f" % [place[0], atm.sky.stars]
		atm.set_weather("cloudy", true)
		clouded = maxf(clouded, atm.sky.stars)
		atm.set_weather("clear", true)
		atm.hour = 12.0
		atm._apply(0.0)
		by_day = maxf(by_day, atm.sky.stars)
		day_glow = maxf(day_glow, atm.sky.glow_amount + float(atm.sky.material.get_shader_parameter("glow_around")))
	var dark := minf(night.hills[0], minf(night.beach[0], night["desert edge"][0]))
	_check(night.downtown[0] <= 0.12 and night.downtown[0] < night.suburbs[0] and night.suburbs[0] < dark and dark >= 0.75, "stars at 23:00 by light pollution:" + text)
	var shader_ok := true
	for k in night:
		shader_ok = shader_ok and absf(float(night[k][3]) - float(night[k][0])) < 0.0001
	_check(shader_ok, "the sky shader shows the stars worked out for the place")
	_check(night.downtown[1] == 0.0 and night.suburbs[1] == 0.0 and minf(night.hills[1], night.beach[1]) > 0.5, "the Milky Way only away from the lights (hills %.2f, beach %.2f)" % [night.hills[1], night.beach[1]])
	_check(by_day == 0.0 and clouded == 0.0, "no stars by day or under cloud")
	var town_glow: Dictionary = night.downtown[4]
	var hill_glow: Dictionary = night.hills[4]
	var dome: Vector4 = hill_glow.lobes[0]
	var shown: Vector4 = night.hills[5][0]
	var off := absf(rad_to_deg(Vector2(dome.x, dome.y).angle_to(Vector2(300, 250) - Vector2(1200, -1300))))
	_check(town_glow.around >= 1.0 and hill_glow.around < 0.1 and off < 25.0 and dome.z > 0.2 and shown.is_equal_approx(dome) and night.downtown[2] > night.hills[2] and day_glow == 0.0, "the city glows orange at night: all round downtown (%.2f), from the hills a dome over town (%.0f deg off its bearing, %.2f); not by day (%.2f)" % [town_glow.around, off, dome.z, day_glow])


## Birds by day, the kinds of the place: pigeons and crows downtown, gulls at
## the beach, egrets and herons in the bayou, hawks over the hills; they
## leave at dusk when bats come out, and none fly at night or in a storm.
func test_birds_by_day_not_at_night() -> void:
	await _new_game(false)
	var atm = game.atmosphere
	atm.minutes_per_second = 0.0
	atm.weather_changes = false
	atm.set_weather("clear", true)
	var birds = atm.birds
	var places := {"city": Vector2(300, 250), "beach": Vector2(-2033, 1791), "bayou": Vector2(-966, 366), "hills": Vector2(1200, -1300), "farm": Vector2(584, -1824)}
	var wrong := []
	for h in places:
		var got: String = birds.habitat_at(places[h])
		if got != h:
			wrong.append("%s reads %s" % [h, got])
	_check(wrong.is_empty() and birds.habitat_at(Vector2(300, 2600)) == "beach", "habitats by place, open sea for gulls %s" % [wrong])
	var Birds = load("res://scripts/birds.gd")
	var kinds := {}
	var misplaced := []
	for h in ["city", "beach", "bayou", "hills"]:
		var p: Vector2 = places[h]
		var at := Vector3(p.x, Terrain.height(p.x, p.y), p.y)
		game.player.global_position = at + Vector3(0, 0.5, 0)
		game.city.stream_now(at)
		atm.hour = 10.0 if h != "city" else 9.0
		await _frames(2)
		var seen := {}
		for f in birds.flocks:
			seen[f.kind] = seen.get(f.kind, 0) + 1
			# Each flock is a kind of the ground it was started over (a beach
			# point's circle also takes in canals and bayou, with their egrets).
			var where: String = birds.habitat_at(f.home)
			var fits := false
			for e in Birds.HABITATS.get(where, Birds.HABITATS.country):
				fits = fits or e[0] == f.kind
			if not fits:
				misplaced.append("%s over %s near %s" % [f.kind, where, h])
		kinds[h] = seen
		if h == "city":
			_check(birds.flocks.size() >= 8 and birds.bird_count() >= 40 and birds.view.visible and birds.mm.visible_instance_count >= birds.bird_count(), "by day %d birds in %d flocks round the player" % [birds.bird_count(), birds.flocks.size()])
			# Indoors hides them; back out on the same spot they show again
			# (review 2026-10-28: they stayed hidden until a flock changed).
			atm.indoors = true
			await _frames(2)
			var hid: bool = not birds.view.visible
			atm.indoors = false
			await _frames(2)
			_check(hid and birds.view.visible, "birds hide indoors and show again back outside")
		atm.hour = 2.0
		await _frames(2)
	_check(misplaced.is_empty() and kinds.city.get("pigeon", 0) + kinds.city.get("crow", 0) > 0 and not kinds.city.has("egret") and kinds.beach.get("gull", 0) > 0 and kinds.bayou.get("egret", 0) + kinds.bayou.get("heron", 0) > 0 and kinds.hills.get("hawk", 0) > 0, "kinds by place: %s, each a kind of its ground %s" % [kinds, misplaced])
	# Back in town: the day ends, the day birds leave and the bats come out.
	var town := Vector3(300, 0, 250)
	game.player.global_position = town + Vector3(0, 0.5, 0)
	atm.hour = 19.0
	await _frames(2)
	var day_flocks: int = birds.flocks.size()
	atm.hour = 19.35
	await _frames(3)
	var leaving := 0
	for f in birds.flocks:
		if f.kind != "bat" and f.state == "leave":
			leaving += 1
	_check(day_flocks >= 8 and leaving == day_flocks, "at 19:21 the day birds head off (%d of %d flocks)" % [leaving, day_flocks])
	atm.hour = 23.0
	await _frames(2)
	_check(birds.bird_count() == 0 and not birds.view.visible, "no birds at night")
	atm.hour = 19.8
	await _frames(2)
	var bats := 0
	for f in birds.flocks:
		bats += 1 if f.kind == "bat" else 100
	_check(bats > 0 and bats <= birds.BAT_FLOCKS, "a few bat flocks at dusk and nothing else (%d)" % [bats])
	atm.hour = 12.0
	atm.set_weather("storm", true)
	await _frames(2)
	_check(birds.bird_count() == 0, "no birds in a storm")
	atm.set_weather("rain", true)
	birds.refresh()
	_check(birds.flocks.size() > 0 and birds.flocks.size() <= birds.RAIN_FLOCKS, "fewer flocks in the rain (%d)" % birds.flocks.size())


## Birds land on roofs and open ground and burst up from people on foot,
## moving cars and loud events (Birds.startle: a crash, a gunshot); all of
## them are one MultiMesh, one draw call, with a fixed budget.
func test_birds_startle_and_budget() -> void:
	await _new_game(false)
	var Birds = load("res://scripts/birds.gd")
	var atm = game.atmosphere
	atm.minutes_per_second = 0.0
	atm.weather_changes = false
	atm.set_weather("clear", true)
	atm.hour = 10.0
	var town := Vector3(300, 0, 250)
	game.city.stream_now(town)
	game.player.global_position = town + Vector3(0, 0.5, 0)
	await _frames(3)
	var birds = atm.birds
	var probe := {"kind": "pigeon"}
	var roofs := 0
	var spots := 0
	var buried := 0
	for i in 12:
		var s = birds._landing_spot(probe, town + Vector3(0, 0, 60), 50.0)
		if s != null:
			spots += 1
			var ground := Terrain.height(s.x, s.z)
			roofs += 1 if s.y > ground + 2.5 else 0
			if Birds._in_lot(game.city, Vector2(s.x, s.z)) and s.y < ground + Birds.LOT_TOP - 0.001:
				buried += 1
	_check(spots >= 8 and roofs >= 1 and buried == 0, "pigeons find places to land in town (%d of 12 tries, %d on roofs), on top of the lots' paving (%d under it)" % [spots, roofs, buried])
	var gull_spot = birds._landing_spot({"kind": "gull"}, Vector3(300, 0, 2600), 40.0)
	_check(gull_spot == null, "gulls do not land on the open sea")
	# A perched flock, and another 150 m off.
	var near := town + Vector3(70, 0, 0)
	var flock: Dictionary = birds.spawn("pigeon", near, true)
	var far: Dictionary = birds.spawn("crow", town + Vector3(-150, 0, 0), true)
	for f in [flock, far]:
		if f.state != "perch":
			birds._set_down(f, Vector3(f.pos.x, Terrain.height(f.pos.x, f.pos.z), f.pos.z))
	var start: Vector3 = flock.pos
	var n: int = Birds.startle(start, 20.0)
	_check(n >= 1 and flock.state == "flee" and far.state == "perch", "a bang scatters the flock near it and not one 220 m off")
	await _frames(60)
	var moved: float = Vector2(flock.pos.x - start.x, flock.pos.z - start.z).length()
	_check(flock.lift > 0.9 and moved > 10.0 and flock.pos.y > start.y + 4.0, "it bursts up and away (%.0f m off, %.1f m up in a second)" % [moved, flock.pos.y - start.y])
	# Someone on foot walks up to a perched flock.
	birds._set_down(flock, Vector3(near.x, Terrain.height(near.x, near.z), near.z))
	await _frames(20)
	_check(flock.state == "perch", "the flock settles again with nobody near")
	game.player.global_position = flock.pos + Vector3(3, 0.5, 0)
	await _frames(20)
	_check(flock.state == "flee", "a person on foot coming close flushes it")
	game.player.global_position = town + Vector3(0, 0.5, 0)
	# A car going past; a parked one does not.
	birds._set_down(flock, Vector3(near.x, Terrain.height(near.x, near.z), near.z))
	var car = Vehicle.new()
	car.kind = "sedan"
	game.add_child(car)
	car.global_position = flock.pos + Vector3(0, 0, 6)
	await _frames(2)
	car.speed = 0.0
	birds._check_threats()
	var parked_ok: bool = flock.state == "perch"
	car.speed = 9.0
	birds._check_threats()
	_check(parked_ok and flock.state == "flee", "a moving car flushes the flock, a parked one does not")
	car.queue_free()
	# A crash nearby (Fx) startles them too.
	birds._set_down(flock, Vector3(near.x, Terrain.height(near.x, near.z), near.z))
	Fx.crash(flock.pos + Vector3(10, 0, 0), 15.0, false)
	_check(flock.state == "flee", "a crash nearby sets them off")
	# Budget: one MultiMesh of 320 birds in one surface, no shadow casting
	# (the blob shadows are part of the mesh); full, it stops at 20 flocks.
	var draws := 0
	for node in birds.find_children("*", "GeometryInstance3D", true, false):
		draws += 1
	var mesh: ArrayMesh = birds.mm.mesh
	var verts: int = mesh.surface_get_array_len(0)
	_check(draws == 1 and birds.view is MultiMeshInstance3D and mesh.get_surface_count() == 1 and birds.mm.instance_count == 320 and birds.view.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and verts * 320 <= 12000, "one draw call: %d birds of %d vertices (shadow quad included), no shadow pass" % [birds.mm.instance_count, verts])
	while not birds.spawn("starling", town + Vector3(randf_range(-80, 80), 0, randf_range(-80, 80))).is_empty():
		pass
	_check(birds.flocks.size() == Birds.MAX_FLOCKS and birds.bird_count() <= 320 and birds.mm.visible_instance_count <= 320, "full up at %d flocks, %d birds" % [birds.flocks.size(), birds.bird_count()])


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


# --- Game log -------------------------------------------------------------------

const LOG_TEST_DIR := "user://test_logs"

## Every key a snapshot line carries in a running game (LOGGING.md).
const SNAP_KEYS := ["clock", "fps", "fps_min", "ft_avg", "ft_max", "f33", "f50", "frames", "cpu", "phys",
	"draws", "prims", "objs", "mem", "vmem", "nodes", "orphans", "bodies", "pairs", "paused",
	"cars", "cars30", "cars60", "moving", "people", "people30", "peds", "traffic", "cops", "copcars",
	"lit_cars", "lit_lamps", "cells", "cell_job", "tiles", "game_time", "hour", "weather", "rain", "wet",
	"clouds", "night", "pos", "head", "mode", "speed", "area", "area_kind", "region", "in_city", "road",
	"road_cls", "surface", "road_d", "indoors", "hp", "cash", "wanted", "act", "mission", "step",
	"outfit", "cam", "zoom", "dzoom", "pitch", "fov", "cam_d", "cam_h", "turn", "look_up", "hitches"]


func _clear_log_dir(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)


## A log on its own (no game) writing to a test folder.
func _test_log(on: bool, max_bytes := GameLog.MAX_BYTES):
	_clear_log_dir(LOG_TEST_DIR)
	var lg = GameLog.new()
	lg.dir = LOG_TEST_DIR
	lg.max_bytes = max_bytes
	add_child(lg)
	lg.settings_applied({"log": on, "quality": "high"})
	return lg


func _log_text(lg) -> String:
	lg.flush()
	return FileAccess.get_file_as_string(lg.path(0))


func test_game_log_file_and_rotation() -> void:
	var lg = _test_log(true, 6000)
	_check(FileAccess.file_exists(lg.path(0)), "log0 is created")
	var text := _log_text(lg)
	_check(text.begins_with("t=") and text.contains("kind=session") and text.contains("kind=device")
		and text.contains("kind=settings"), "log starts with the session header")
	for i in 600:
		lg.log_event("filler", {"i": i, "pad": "x".repeat(60)})
		if i % 20 == 0:
			lg.flush()
	lg.flush()
	_check(FileAccess.file_exists(lg.path(1)) and FileAccess.file_exists(lg.path(2)), "log rotates into log1 and log2")
	_check(not FileAccess.file_exists(LOG_TEST_DIR.path_join("log3.txt")), "only %d files are kept" % GameLog.FILES)
	var big := 0
	for i in GameLog.FILES:
		big = maxi(big, FileAccess.get_file_as_bytes(lg.path(i)).size())
	_check(big < 6000 + 4000, "each file stays near the size cap (%d bytes)" % big)
	_check(FileAccess.get_file_as_string(lg.path(1)).contains("continued=1"), "a rotated file starts with the header again")
	var line := GameLog._kv({"kind": "x", "s": "two words", "v": Vector3(1.04, 2, 3), "b": true, "e": ""})
	_check(line == " x_kind=x s=\"two words\" v=1.0,2.0,3.0 b=1 e=-", "values format as k=v (%s)" % line)
	lg.queue_free()
	await _frames(1)
	_clear_log_dir(LOG_TEST_DIR)


func test_game_log_snapshot_and_events() -> void:
	await _new_game(false)
	var lg = game.game_log
	_check(lg.started and lg.enabled and FileAccess.file_exists(lg.path(0)), "the game starts its log")
	var s: Dictionary = lg.snapshot()
	var missing := []
	for k in SNAP_KEYS:
		if not s.has(k):
			missing.append(k)
	_check(missing.is_empty(), "snapshot has every field (missing %s)" % [missing])
	_check(s.get("mode") == "foot" and s.get("area", "-") != "-" and s.get("road", "-") != "-",
		"snapshot: on foot in %s on %s" % [s.get("area"), s.get("road")])
	# Enter a car.
	var car = _spawn_car(_home(), Vector3(0, 0, -3), 0.0)
	_place_player(_home(), Vector3.ZERO)
	await _frames(2)
	await _press("interact")
	_check(game.player.vehicle == car, "player gets in the car")
	_check(str(lg.snapshot().get("mode")).begins_with("drive:"), "snapshot shows driving")
	# A settings change.
	game.settings["show_fps"] = not game.settings.get("show_fps", true)
	game.apply_settings()
	# Engine and script errors and warnings (a real push_error would fail run.sh).
	push_warning("game log test warning 4471")
	lg._catcher._log_error("test_fn", "res://tests/fake.gd", 12, "game log test error 4472", "why",
		false, Logger.ERROR_TYPE_SCRIPT, [] as Array[ScriptBacktrace])
	lg._drain_errors()
	lg._tick(Time.get_ticks_usec())
	var text := _log_text(lg)
	_check(text.contains("kind=enter_car car="), "entering the car is logged")
	_check(text.contains("kind=settings show_fps="), "a settings change is logged")
	_check(text.contains("kind=warning") and text.contains("4471"), "a pushed warning is logged")
	_check(text.contains("kind=error type=script") and text.contains("4472") and text.contains("fake.gd:12"),
		"a script error is logged")
	_check(text.contains("kind=snap") and text.contains("mode=drive:"), "the 1 s snapshot is written")
	# Cost: one snapshot line (the 1 s tick) and one frame's bookkeeping.
	var costs := []
	for i in 30:
		var t0 := Time.get_ticks_usec()
		lg._write(lg._line("snap", lg.snapshot()))
		costs.append(Time.get_ticks_usec() - t0)
	costs.sort()
	var tick_us: int = costs[costs.size() / 2]
	var road_costs := []
	for i in 30:
		var t0 := Time.get_ticks_usec()
		lg._refresh_road(true)
		road_costs.append(Time.get_ticks_usec() - t0)
	road_costs.sort()
	var road_us: int = road_costs[road_costs.size() / 2]
	lg._next_tick_us = Time.get_ticks_usec() + 60_000_000
	lg._next_road_us = lg._next_tick_us
	var t1 := Time.get_ticks_usec()
	for i in 10000:
		lg._process(0.016)
	var frame_us := (Time.get_ticks_usec() - t1) / 10000.0
	print("  game log cost: snapshot line %d us, road lookup %d us (medians of 30), per frame %.2f us" % [tick_us, road_us, frame_us])
	# Budget 0.2 ms on a desktop release build; the headless debug build in
	# a shared container runs slower, so the gate here is 0.3 ms.
	_check(tick_us < 300, "snapshot under budget (%d us)" % tick_us)
	_check(road_us < 300, "road lookup under budget (%d us)" % road_us)
	_check(frame_us < 20.0, "per-frame cost is tiny (%.2f us)" % frame_us)


func test_game_log_report_copy_and_off() -> void:
	await _new_game(false)
	var lg = game.game_log
	for i in 300:
		lg.log_event("filler", {"i": i, "pad": "y".repeat(80)})
	var n: int = lg.report("test")
	_check(n > 0, "report returns its number")
	var text := _log_text(lg)
	var at := text.find("kind=REPORT n=%d" % n)
	_check(at >= 0 and text.find("kind=report_snap", at) > at and text.find("kind=REPORT_END n=%d" % n, at) > at,
		"report writes a REPORT block with a snapshot")
	_check(text.contains("\n> t="), "report repeats the last minute of the log")
	var copy: String = lg.copy_text(8192)
	_check(copy.to_utf8_buffer().size() <= 8192, "copy keeps to its cap (%d bytes)" % copy.to_utf8_buffer().size())
	_check(copy.begins_with("t=") and copy.contains("kind=session") and copy.contains("older lines cut"),
		"a cut copy keeps the session header")
	var done := []
	lg.export(func(ok, where): done.append([ok, where]))
	_check(done.size() == 1 and done[0][0] and FileAccess.file_exists(done[0][1]), "export writes a file (%s)" % [done])
	if done.size() == 1 and FileAccess.file_exists(done[0][1]):
		DirAccess.remove_absolute(done[0][1])
	# Off: nothing more is written.
	game.settings["log"] = false
	game.apply_settings()
	var size_off := FileAccess.get_file_as_bytes(lg.path(0)).size()
	_check(_log_text(lg).contains("kind=log_off"), "turning the log off is noted")
	lg.log_event("should_not_appear", {})
	lg._tick(Time.get_ticks_usec())
	lg.flush()
	_check(FileAccess.get_file_as_bytes(lg.path(0)).size() == size_off, "log off writes nothing")
	_check(lg.report("off") == 0, "no report while off")
	game.settings["log"] = true
	game.apply_settings()
	_check(_log_text(lg).contains("kind=log_on"), "the log turns back on")
	# Off from the start: no file at all.
	var off = _test_log(false)
	off.log_event("nope", {})
	off.flush()
	_check(not FileAccess.file_exists(off.path(0)), "a log that starts off makes no file")
	off.queue_free()
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
		"compact", "van", "box_truck", "scooter"]
	for i in by_top.size() - 1:
		_check(top[by_top[i]] > top[by_top[i + 1]], "top speed: %s %.1f > %s %.1f" % [by_top[i], top[by_top[i]], by_top[i + 1], top[by_top[i + 1]]])
	var by_launch := ["super", "motorbike", "ev", "sports", "muscle", "police", "sedan", "luxury", "crossover", "compact",
		"suv", "pickup"]
	for i in by_launch.size() - 1:
		var a: String = by_launch[i]
		var b: String = by_launch[i + 1]
		_check(t15.get(a, 99.0) < t15.get(b, 99.0), "0-15 m/s: %s %.2f s < %s %.2f s" % [a, t15.get(a, 99.0), b, t15.get(b, 99.0)])
	_check(t15.ev < t15.sedan * 0.7, "electric torque: EV 0-15 %.2f s well under the sedan's %.2f s" % [t15.ev, t15.sedan])
	_check(t15.get("box_truck", 99.0) > t15.get("van", 99.0) + 1.0, "the box truck is the slowest to 15 m/s (%.2f s, van %.2f s)" % [t15.get("box_truck", 99.0), t15.get("van", 99.0)])


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
	# A 90-degree snap at top speed: the assist brakes hard for the turn, so
	# the car runs on little more than its braking distance (top speeds are
	# road speeds since 0.21, and the tyres hold only corner_g).
	var kinds := ["sedan", "suv", "super"]
	for k in kinds.size():
		var kind: String = kinds[k]
		var spec: Dictionary = VehicleKit.spec(kind)
		car = _player_car(kind, Vector3(-60.0 + k * 20.0, 0, k * 60.0), spec.max_speed)
		Controls.override_vector = Vector2(1, 0)
		var run_on := 0.0
		for f in 150:
			await _frames(1)
			run_on = maxf(run_on, k * 60.0 - car.global_position.z)
		var stopping: float = spec.max_speed * spec.max_speed / (2.0 * spec.brake)
		_check(run_on < stopping + 9.0, "%s at top speed turning 90 degrees runs on %.1f m (braking distance %.1f m)" % [kind, run_on, stopping])
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
		# At 12-16 m/s the tyres hold about 0.75 rad/s (corner_g), less the
		# wheel's STEER_IN and the body's YAW_IN.
		_check(turned < -0.3, "%s layout: steering right with GAS turns right (%.2f rad)" % [scheme, turned])
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
## Brake while turning at speed and the tail steps out: the car slides on
## round the bend instead of stopping, and grips again once the wheel
## straightens (0.23, Sachin: "allow drifting with direction and brake like
## other games offer"). Braking in a straight line still stops; a bicycle
## never drifts.
func test_brake_and_steer_drifts() -> void:
	await _free_game()
	Controls.camera = null
	Controls.scheme = "arrows"
	var car = _player_car("sedan", Vector3(150.0, 0, 150.0), 20.0)
	Input.action_press("gas")
	Input.action_press("steer_left")
	await _frames(12)
	Input.action_release("gas")
	Input.action_press("brake")
	await _frames(12)
	_check(car.drifting, "brake with the wheel at full lock at 72 km/h starts a drift")
	Input.action_release("brake")
	var slip := 0.0
	for f in 40:
		await get_tree().physics_frame
		var flat := Vector3(car.velocity.x, 0.0, car.velocity.z)
		if flat.length() > 2.0:
			slip = maxf(slip, absf((-car.global_basis.z).signed_angle_to(flat, Vector3.UP)))
	_check(slip > 0.3, "the tail steps out in the drift (slip %.2f rad)" % slip)
	_check(car.speed > 6.0, "a drift slides on instead of stopping (%.1f m/s)" % car.speed)
	print("drift: slip %.2f speed %.1f" % [slip, car.speed])
	Input.action_release("steer_left")
	await _frames(45)
	_check(not car.drifting and car._slide < 0.05, "straightening the wheel ends the drift")
	car.queue_free()
	# Straight-line braking stops the car as before.
	car = _player_car("sedan", Vector3(150.0, 0, 150.0), 20.0)
	Input.action_press("brake")
	await _frames(150)
	_check(not car.drifting and car.speed < 1.0, "braking with the wheel straight stops the car (%.1f m/s)" % car.speed)
	Input.action_release("brake")
	car.queue_free()
	car = _player_car("bicycle", Vector3(150.0, 0, 150.0), 10.0)
	Input.action_press("steer_left")
	await _frames(12)
	Input.action_press("brake")
	await _frames(10)
	_check(not car.drifting, "a bicycle does not drift")
	Input.action_release("brake")
	Input.action_release("steer_left")
	car.queue_free()
	Controls.scheme = "stick"


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


## Every traffic kind, the three-wheelers and the box truck, tipper and
## 18-wheeler included, drives junction to junction through the streets
## around the spawn without getting stuck or wrecked.
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
		var options: Array = []
		# The 18-wheeler sets off only on two or more lanes each way, as in
		# Population._new_traffic_car.
		var wide_only: bool = VehicleKit.size_of(kind).z > VehicleKit.LONG_HAUL
		for attempt in 200:
			n = city.random_node_between(center, 15.0, 160.0, rng)
			# Start apart, so cars don't set off into each other.
			var clear: bool = used.keys().all(func(u): return city.node_pos(u).distance_to(city.node_pos(n)) > 25.0) if n >= 0 else false
			options = city.next_nodes(n) if n >= 0 else []
			if wide_only:
				options = options.filter(func(m): return city.lane_count(n, m) >= 2)
			if clear and not options.is_empty():
				break
		used[n] = true
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
	var starts := {}
	for car in cars:
		prev[car] = car._next_node
		passed[car] = 0
		went[car] = 0.0
		starts[car] = car.global_position
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
	# are 120 m between avenues); a slow truck (about 8 m/s in traffic) can
	# pass just one between two long blocks, so 180 m from where it set off
	# counts too.
	for car in cars:
		var net: float = car.global_position.distance_to(starts[car])
		var on: bool = passed[car] >= 3 or (passed[car] >= 2 and went[car] > 200.0) or (passed[car] >= 1 and net > 180.0)
		_check(on and not car.wrecked,
			"traffic %s passed %d junctions, %.0f m (%.0f m from the start) in 30 s (wrecked: %s)" % [car.kind, passed[car], went[car], net, car.wrecked])
	# At junctions offering both, an 18-wheeler's turn is always a street with
	# 2+ lanes each way (review 2026-10-28: it was routed into 9 m quarter
	# streets); other cars still take the narrow ones.
	var mixed := 0
	var narrow_picks := 0
	var wide_narrow := 0
	for cur in city._nodes_near(Vector2(center.x, center.z), 600.0):
		var outs: Array = city.next_nodes(cur)
		if outs.size() < 3:
			continue
		var prev_n: int = outs[0]
		var rest: Array = outs.slice(1)
		if not (rest.any(func(m): return city.lane_count(cur, m) >= 2) and rest.any(func(m): return city.lane_count(cur, m) < 2)):
			continue
		mixed += 1
		for i in 12:
			if city.lane_count(cur, city.pick_turn(prev_n, cur, rng, true)) < 2:
				wide_narrow += 1
			if city.lane_count(cur, city.pick_turn(prev_n, cur, rng)) < 2:
				narrow_picks += 1
	_check(mixed >= 3 and wide_narrow == 0 and narrow_picks > 0,
		"at %d junctions with wide and narrow ways on, the 18-wheeler turned into a narrow one %d times (other cars %d)" % [mixed, wide_narrow, narrow_picks])


## Every vehicle kind builds, in every paint of its palette, within its
## triangle budget (1500 for cars, bikes and three-wheelers, 3000 for the
## trucks), keeps to its footprint (mirrors, roof signs and bumpers may
## stand a little proud) with nothing below the ground, and stands on
## every axle: tyres touching y = 0 on both sides, or on the middle line
## for a single front or rear wheel.
func test_vehicle_models_in_budget_and_grounded() -> void:
	await _free_game()
	var axles := {"box_truck": 2, "tipper": 3, "semi": 5}
	for kind: String in VehicleKit.KINDS:
		var size: Vector3 = VehicleKit.size_of(kind)
		var budget := 3000 if size.z > 6.0 else 1500
		var palette: Array = VehicleKit.PALETTES.get(kind, VehicleKit.PAINTS)
		var most := 0
		var least := 1 << 30
		var lo := Vector3(INF, INF, INF)
		var hi := -lo
		var feet := {} # axle (z in cm) -> sides touching the ground
		for paint: Color in palette:
			var mb := MeshBuilder.new()
			var g := MeshBuilder.new()
			VehicleKit.build(mb, kind, paint, g)
			var tris: int = mb.triangle_count() + g.triangle_count()
			most = maxi(most, tris)
			least = mini(least, tris)
			for m in [mb, g]:
				for i in m.verts.size():
					var v: Vector3 = m.verts[i]
					lo = lo.min(v)
					hi = hi.max(v)
					if v.y < 0.005 and m.colors[i].is_equal_approx(VehicleKit.TYRE):
						var side := "mid" if absf(v.x) < 0.3 else ("left" if v.x < 0.0 else "right")
						var at: Dictionary = feet.get(roundi(v.z * 100.0), {})
						at[side] = true
						feet[roundi(v.z * 100.0)] = at
		_check(least > 200 and most <= budget, "%s builds in %d-%d triangles (budget %d)" % [kind, least, most, budget])
		var proud := Vector3(hi.x - size.x * 0.5, hi.y - size.y, hi.z - size.z * 0.5).max(Vector3(-lo.x - size.x * 0.5, 0, -lo.z - size.z * 0.5))
		_check(lo.y > -0.001 and proud.x < 0.18 and proud.y < 0.25 and proud.z < 0.16,
			"%s fits its %s footprint (lowest y %.3f, proud by %s)" % [kind, size, lo.y, proud])
		var balanced: bool = feet.values().all(func(at): return at.has("mid") != (at.has("left") and at.has("right")))
		_check(feet.size() == axles.get(kind, 2) and balanced,
			"%s stands on %d axles, tyres down on both sides or the middle: %s" % [kind, axles.get(kind, 2), feet])


## The three-wheelers park at the curb and at the poorest homes; the
## tipper and the 18-wheeler only drive. Only the 18-wheeler is longer than
## VehicleKit.LONG_HAUL, and traffic never sets one off down a one-lane
## street, only on two or more lanes each way.
func test_three_wheelers_and_big_trucks() -> void:
	await _new_game(false)
	for kind in ["tuk_tuk", "cargo_trike", "tipper", "semi"]:
		_check(VehicleKit.CIVILIAN.has(kind) and not VehicleKit.spec(kind).rider, "%s drives in traffic" % kind)
	for kind in ["tuk_tuk", "cargo_trike"]:
		_check(VehicleKit.PARKED.has(kind) and VehicleKit.PARKED_BY_TIER[0].has(kind), "%s parks at the curb and at T0 homes" % kind)
	var parks_big := false
	for pool: Array in [VehicleKit.PARKED] + VehicleKit.PARKED_BY_TIER:
		parks_big = parks_big or pool.has("tipper") or pool.has("semi")
	_check(not parks_big, "tippers and 18-wheelers never park at a curb or a home")
	var long: Array = VehicleKit.KINDS.keys().filter(func(k): return VehicleKit.size_of(k).z > VehicleKit.LONG_HAUL)
	_check(long == ["semi"], "only the 18-wheeler is long haul, got %s" % [long])
	# The tuk-tuk's headlamp glow sits on its close-set cowl lamps (x ±0.17;
	# each glow reaches 0.5 m either side, so the box ends near ±0.67, not
	# the ±0.96 it had when it sat a third of the width out).
	var tuk = _track_car("tuk_tuk", Vector3(0, 0, 0), 0.0)
	var glow_box: AABB = tuk._lamp_glow.get_aabb()
	_check(glow_box.end.x < 0.75 and glow_box.position.x > -0.75,
		"the tuk-tuk's lamp glow stays on its cowl lamps: x %.2f..%.2f" % [glow_box.position.x, glow_box.end.x])
	tuk.queue_free()
	var city = game.city
	var plan = city.plan
	var narrow := Vector2i(-1, -1)
	var wide := Vector2i(-1, -1)
	for e in plan.edge_count():
		var a: int = plan.edge_a[e]
		var b: int = plan.edge_b[e]
		if not StreetPlan.CLASSES[plan.edge_class(e)].drive:
			continue
		if city.lane_count(a, b) == 1 and narrow.x < 0:
			narrow = Vector2i(a, b)
		elif city.lane_count(a, b) >= 2 and wide.x < 0:
			wide = Vector2i(a, b)
	_check(narrow.x >= 0 and wide.x >= 0, "the plan has one-lane and wider streets")
	if narrow.x < 0 or wide.x < 0:
		return
	var pop = game.population
	var on_narrow := {}
	var on_wide := {}
	for i in 600:
		for pair in [[narrow, on_narrow], [wide, on_wide]]:
			var car = pop._new_traffic_car(pair[0].x, pair[0].y)
			pair[1][car.kind] = true
			car.free()
	_check(on_wide.has("semi") and on_wide.has("tipper") and on_wide.has("tuk_tuk"),
		"600 picks on a %d-lane street include the 18-wheeler, tipper and tuk-tuk: %s" % [city.lane_count(wide.x, wide.y), on_wide.keys()])
	_check(not on_narrow.has("semi") and on_narrow.has("tipper") and on_narrow.has("cargo_trike"),
		"600 picks on a one-lane street: no 18-wheeler, still tippers and trikes: %s" % [on_narrow.keys()])


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
	var again: Array = Places.build(city)
	again.append_array(Places.build_suburbs(city, again.duplicate()))
	var suburb: Array = city.places.filter(func(p): return p.face < 0)
	_check(suburb.size() >= 6, "the suburbs have enterable places too, got %d" % suburb.size())
	_check(suburb.any(func(p): return p.type == "diner") and suburb.any(func(p): return p.type == "corner_store"), "suburb places include a diner and a store")
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
	# A minute at least, then on until a second shopper is out: one who
	# walks in early and browses three shelves takes up to a minute (each
	# shelf is reached from the middle of the shop), so with only one
	# shopper there at the start a flat minute sometimes saw one leave.
	for i in 9000:
		if i >= 3600 and left[0] >= 2 and paid[0] > 0:
			break
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


## People walk the suburbs' sidewalks (BX-1): out on the east side, the
## crowd spawns on the country's loops, on the ground by the streets.
func test_people_walk_the_suburbs() -> void:
	await _new_game(true)
	var city = game.city
	var c = city.country
	var first: int = city.sidewalk_loops.size() - c.walks.size()
	var at := Vector3.INF
	for w in c.walks:
		if w[0].x > 1700.0 and w[0].z > 200.0 and w[0].z < 900.0:
			at = w[0]
			break
	_check(at != Vector3.INF, "an east side loop to stand on")
	if at == Vector3.INF:
		return
	_place_player_at(at)
	await _frames(600)
	var pop = game.population
	var near := 0
	var on_suburb := 0
	for p in pop.peds:
		if p.global_position.distance_to(at) > 120.0:
			continue
		near += 1
		var hit: Array = city.nearest_sidewalk(p.global_position)
		if int(hit[0]) >= first:
			on_suburb += 1
	_check(near >= 8, "people about on the east side, got %d" % near)
	_check(on_suburb * 10 >= near * 8, "they walk the suburb loops (%d of %d)" % [on_suburb, near])
	# A seeded spread of draws (one unseeded draw failed now and then).
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var drawn := 0
	var out_there := 0
	for k in 20:
		var probe: Array = city.random_sidewalk_between(at, 30.0, 60.0, rng)
		if probe.is_empty():
			continue
		drawn += 1
		if int(probe[0]) >= first:
			out_there += 1
	_check(drawn > 0 and out_there * 10 >= drawn * 8, "spawn points out there are on suburb loops (%d of %d)" % [out_there, drawn])
	var road := INF
	for p in pop.peds:
		if p.global_position.distance_to(at) < 120.0:
			road = minf(road, c.road_distance(Vector2(p.global_position.x, p.global_position.z), 40.0))
	_check(road > 0.5, "no one walks in the road (closest %.1f m from the asphalt's middle-line)" % road)


## The suburbs' home cars are live (BX-2): an east side tile opens its
## homes' car spots in the city's parked_spots, real cars park there, and
## the spots close when the tile unloads.
func test_suburb_home_cars_are_live() -> void:
	await _new_game(true)
	var city = game.city
	var c = city.country
	var first: int = city.parked_spots.size()
	var at := Vector3.INF
	for w in c.walks:
		if w[0].x > 1700.0 and w[0].z > 200.0 and w[0].z < 900.0:
			at = w[0]
			break
	_check(at != Vector3.INF, "an east side loop to stand on")
	if at == Vector3.INF:
		return
	_place_player_at(at)
	game.population.refill()
	await _frames(400)
	var spots: Array = city.parked_spots.slice(first)
	_check(spots.size() >= 10 and spots.all(func(s): return s.size() == 4 and s[3] >= 0 and s[3] <= 5), "east side homes open car spots with their tiers, got %d" % spots.size())
	var parked := 0
	var off_tier: Array = []
	for idx in game.population._parked:
		if idx >= first and is_instance_valid(game.population._parked[idx]):
			var car = game.population._parked[idx]
			if car.global_position.distance_to(city.parked_spots[idx][0]) < 1.5:
				parked += 1
			var tier: int = city.parked_spots[idx][3]
			if not car.kind in preload("res://scripts/kits/vehicle_kit.gd").PARKED_BY_TIER[tier]:
				off_tier.append("%s at T%d" % [car.kind, tier])
	_check(parked >= 3, "live cars park at the homes, got %d" % parked)
	_check(off_tier.is_empty(), "each home's car suits its household (%s)" % [off_tier])
	var keys: Array = c.loaded_tiles()
	_place_player_at(city.spawn_point)
	await _frames(240)
	var open := 0
	var closed := 0
	for idx in range(first, city.parked_spots.size()):
		var p: Vector3 = city.parked_spots[idx][0]
		if keys.has(c.tile_key(p)) and not c.loaded_tiles().has(c.tile_key(p)):
			if city.parked_spots[idx][2]:
				open += 1
			else:
				closed += 1
	_check(closed > 0 and open == 0, "spots close with their tiles (%d closed, %d left open)" % [closed, open])


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
	# The shady kinds (shady_kit) are built through Kit.build too; their
	# yards and blocks are compounds, held to the big-lot budget.
	var shady: Array = preload("res://scripts/kits/shady_kit.gd").kinds()
	for kind: String in Kit.KINDS + shady:
		var f: Vector2 = Kit.footprint(kind)
		var budget := 8000 if f.x * f.y >= 5000.0 or kind in shady else 5000
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
			if tris <= 0 or tris > budget:
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
					if thin <= 0.9 and maxf(e.x, e.y) * 2.0 >= 1.5 and s.y <= 2.6 and at_edge:
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
		# An estate's gatehouse stands at its gate; the homes are the rest.
		var homes: Array = []
		var gates := 0
		for l: Array in c.lots:
			if int(l[8]) == i:
				if c.kinds[int(l[5])] == "gatehouse":
					gates += 1
				else:
					homes.append(l)
		if gates > (1 if ty == "estate" else 0):
			bare += 1
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
		# The boundary wall: long colliders lying along the plot's edges, square
		# to it, as high as the plot's wall look (GroundsKit._wall_look, 1.5-2.4 m).
		var py := float(p[2])
		var on_edge := func(col) -> bool:
			if not (col[1].x > 20.0 and col[1].y > 1.45 and col[1].y < 2.45):
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
							if cs.x > 1.0 and cs.z < 0.9 and cs.y <= 2.6 and cc.z < -size.y * 0.5 + 1.6:
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
		"ranch_house": [2, 3], "adobe_farmhouse": [2, 3], "farmhouse_big": [3, 4], "condo_tower": [3, 4], "mansion": [4, 5],
		"cheap_block": [0, 1], "bungalow_barred": [0, 1], "midrise_condo": [3, 4], "res_tower": [4, 5], "exec_house": [4, 5]}
	const UNITS := {"garden_apartments": 12, "rowhouse_row": 4, "cheap_block": 16, "midrise_condo": 20}
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
		if kind in ["condo_tower", "midrise_condo", "res_tower"]:
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
	var d: float = Kit.footprint("house").y
	# The boundary goes by the household (Sachin, 2026-10-28: "some can have
	# it but others can have their own different types of boundaries"): the
	# T1 house's is a poor one (open, broken, chain-link, ply, wire, block),
	# the T4 house's a rich one (hedge, iron, a tall wall, brick), and a
	# fronted one has a run along the front line beside its gate.
	var poor_b: Dictionary = Kit.boundary(1, "", hash([3, "boundary"]))
	var rich_b: Dictionary = Kit.boundary(4, "", hash([3, "boundary"]))
	var front_runs := func(out: Array) -> int:
		var k := 0
		for col in out:
			k += 1 if col.size() < 3 and col[1].z < 0.9 and col[1].x > 1.0 and col[0].z < -d * 0.5 + 2.0 else 0
		return k
	var poor_runs: int = front_runs.call(poor)
	var rich_runs: int = front_runs.call(rich)
	_check(count.call(poor, LUX) == 0 and poor_b.style in ["", "broken", "chain", "ply", "wire", "block"]
		and (poor_runs >= 1 or poor_b.style == "") and count.call(rich, LUX) == 1
		and rich_b.style in ["hedge", "iron", "wall", "brick"] and rich_runs >= 1,
		"a T1 house has a poor boundary (%s, %d front runs) and no luxury car, a T4 house a rich one (%s, %d runs) and one (%d cars)"
		% [poor_b.style, poor_runs, rich_b.style, rich_runs, count.call(rich, LUX)])
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
		# In the suburbs the car is live: a T4 spot that spawns a luxury pick.
		for pk: Array in tile.parks:
			if int(pk[3]) == 4 and Vector3(pk[1].x, 0.0, pk[1].z).distance_to(at) < 15.0:
				cars += 1
	_check(rich_lot >= 0 and cars >= 1, "a tile build gives a T4 street house its luxury car (lot %d, %d cars)" % [rich_lot, cars])


## The newer home kinds (homes_kit.gd): each builds at every tier inside its
## triangle budget, the tiers read differently, and the live-car hook swaps a
## home's parked car for a park marker without changing anything else.
func test_new_home_kinds_and_live_cars() -> void:
	var Kit = preload("res://scripts/kits/country_kit.gd")
	var Shady = preload("res://scripts/kits/shady_kit.gd")
	var MB = preload("res://scripts/mesh_builder.gd")
	var build := func(kind: String, tier: int, seed_v: int, live := false) -> Array:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_v
		Kit.wealth = tier
		Kit.live_cars = live
		var mb = MB.new()
		var out: Array = []
		Kit.build(kind, mb, out, Kit.footprint(kind), rng)
		Kit.wealth = -1
		Kit.live_cars = false
		return [mb, out]
	var tinted := func(mb, c: Color) -> int:
		var k := 0
		for col: Color in mb.colors:
			if col.is_equal_approx(c):
				k += 1
		return k
	var problems: Array[String] = []
	for kind: String in ["res_tower", "midrise_condo", "cheap_block", "exec_house", "gatehouse"]:
		if kind not in Kit.KINDS:
			problems.append("%s not in KINDS" % kind)
			continue
		for tier in 6:
			var r: Array = build.call(kind, tier, 5 + tier)
			var tris: int = r[0].triangle_count()
			if tris <= 0 or tris > 5000:
				problems.append("%s T%d: %d triangles" % [kind, tier, tris])
	_check(problems.is_empty(), "the new home kinds build at every tier in budget %s" % [problems])
	# cheap_block: T0 boards up more windows than T1; midrise_condo: only T4
	# has the roof pool.
	var boards := [0, 0]
	for seed_v in 6:
		for t in 2:
			boards[t] += tinted.call(build.call("cheap_block", t, seed_v)[0], Shady.PLYWOOD.darkened(0.4))
	_check(boards[0] > boards[1], "a T0 cheap block has more boarded windows than a T1 (%s)" % [boards])
	var pool3: int = tinted.call(build.call("midrise_condo", 3, 4)[0], Kit.POOL)
	var pool4: int = tinted.call(build.call("midrise_condo", 4, 4)[0], Kit.POOL)
	_check(pool3 == 0 and pool4 > 0, "a T4 midrise condo has a roof pool, a T3 none (%d, %d)" % [pool3, pool4])
	# Live cars: a T4 house gives park markers instead of its luxury car, and
	# with the hook off it builds exactly as before.
	const LUX := Vector3(1.9, 1.5, 4.9)
	var off: Array = build.call("house", 4, 3)
	var again: Array = build.call("house", 4, 3)
	var on: Array = build.call("house", 4, 3, true)
	var parks: Array = on[1].filter(func(c): return c is Dictionary)
	var solid_on: Array = on[1].filter(func(c): return c is Array)
	var lux_off: Array = off[1].filter(func(c): return c is Array and (c[1] as Vector3).is_equal_approx(LUX))
	var lux_on: Array = solid_on.filter(func(c): return (c[1] as Vector3).is_equal_approx(LUX))
	_check(off[1] == again[1] and off[0].verts == again[0].verts and lux_off.size() >= 1 and not off[1].any(func(c): return c is Dictionary),
		"with live cars off a T4 house builds the same, with its car (%d)" % lux_off.size())
	var shapes_ok := parks.all(func(p): return p.size() == 3 and p.park is Vector3 and p.park.y == 0.0 and p.yaw is float and p.tier == 4)
	var car_left := 0
	for p: Dictionary in parks:
		for v: Vector3 in on[0].verts:
			if v.y > 0.5 and v.y < 1.6 and Vector2(v.x - p.park.x, v.z - p.park.z).length() < 0.7:
				car_left += 1
	var others_same: bool = solid_on == off[1].filter(func(c): return not (c[1] as Vector3).is_equal_approx(LUX))
	_check(parks.size() >= 1 and parks.size() == lux_off.size() and shapes_ok and lux_on.is_empty() and car_left == 0 and others_same,
		"with live cars on a T4 house gives %d park markers, no car mesh (%d verts) or collider (%d)" % [parks.size(), car_left, lux_on.size()])
	# The marker sits where the static car stood.
	var near := parks.all(func(p): return lux_off.any(func(c): return Vector2(c[0].x - p.park.x, c[0].z - p.park.z).length() < 0.5))
	_check(near, "each park marker stands where the static car was")


# --- People: looks, senses and reactions ---------------------------------------

## A stand-in city for pedestrians: one sidewalk loop running north-south
## through `origin`, so someone told to walk at 0 m/s stands facing north.
func _fake_street(origin: Vector3):
	var fake := GDScript.new()
	fake.source_code = "extends RefCounted\nvar sidewalk_loops: Array = []\n"
	fake.reload()
	var city = fake.new()
	city.sidewalk_loops.append(PackedVector3Array([origin + Vector3(0, 0, -80), origin + Vector3(0, 0, 80)]))
	return city


## A pedestrian of `cat` and `personality` standing still at `pos`.
func _street_ped(city, rng: RandomNumberGenerator, pos: Vector3, yaw: float, cat := "general", personality := "calm"):
	var ped = PedScript.new()
	ped.setup(city, rng, 0, 0)
	ped.point_index = 0
	ped.step = 1
	ped.category = cat
	ped.personality = personality
	ped.brave = personality == "brave"
	ped.walk_speed = 0.0
	ped.position = pos
	ped.rotation.y = yaw
	add_child(ped)
	return ped


## Whether `who` shows reaction `r` in its body now.
func _shows_reaction(who, r: String) -> bool:
	match r:
		"startle", "dodge", "duck":
			return who._action == r
		"cower", "hands_up", "film", "call":
			return who.shown_gesture() == r
		"cheer":
			return who.shown_gesture() in ["cheer", "clap"]
		"shout":
			return who.shown_gesture() in ["shake_fist", "argue"]
		"flee":
			return who.style == "panic"
	return who._look_time > 0.0


func _in_limits(r: Vector3, i: int) -> bool:
	var lo: Vector3 = RigScript.LIMITS[i][0]
	var hi: Vector3 = RigScript.LIMITS[i][1]
	return r.is_finite() and r.x >= lo.x - 1e-4 and r.y >= lo.y - 1e-4 and r.z >= lo.z - 1e-4 \
		and r.x <= hi.x + 1e-4 and r.y <= hi.y + 1e-4 and r.z <= hi.z + 1e-4


## Poses a fresh rig on `skel` for `frames` ticks of `st`, calling
## step(st, f) before each tick when given, and notes in `bad` any joint
## outside Rig.LIMITS and any value that is not finite. Returns the last
## bone rotations and, after them, the body's (lift, tilt, roll).
func _pose_run(skel: Skeleton3D, st, frames: int, label: String, bad: Array, step := Callable()) -> Array:
	var rig = RigScript.new(skel)
	for f in frames:
		if step.is_valid():
			step.call(st, f)
		rig.pose(st, 1.0 / 60.0)
		for i in RigScript.LIMITS.size():
			if not _in_limits(rig.bone_rotation(i), i) and bad.size() < 12:
				bad.append("%s: bone %d at %s, frame %d" % [label, i, rig.bone_rotation(i), f])
		var body := Vector3(skel.position.y, skel.rotation.x, skel.rotation.z)
		if not body.is_finite() and bad.size() < 12:
			bad.append("%s: body %s, frame %d" % [label, body, f])
	var out := []
	for i in RigScript.LIMITS.size():
		out.append(rig.bone_rotation(i))
	out.append(Vector3(skel.position.y, skel.rotation.x, skel.rotation.z))
	return out


## The largest difference between two _pose_run results.
func _pose_gap(a: Array, b: Array) -> float:
	var gap := 0.0
	for i in a.size():
		var d: Vector3 = (a[i] - b[i]).abs()
		gap = maxf(gap, maxf(d.x, maxf(d.y, d.z)))
	return gap


## Height of who's hips bone over the ground under them.
func _hips_height(who) -> float:
	var skel: Skeleton3D = who.model
	return (skel.global_transform * skel.get_bone_global_pose(0).origin).y - who.global_position.y


## Each kind of person dresses the part within the triangle budget, and the
## hero's finer mesh and white stripes cost a little more than a plain look.
func test_people_dress_for_their_kind() -> void:
	const Player = preload("res://scripts/player.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var total := 0
	var count := 0
	var rigid := true
	for cat in CharKit.CATEGORIES:
		var tris := 0
		var most := 0
		var flair := 0
		var wrong := []
		for n in 40:
			var look := CharKit.category_look(rng, cat)
			var mb := MeshBuilder.new()
			CharKit.build(mb, look)
			var t: int = mb.triangle_count()
			if n < 6:
				var arrays := mb.commit().surface_get_arrays(0)
				var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
				var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
				for v in range(0, bones.size(), 4):
					if bones[v] < 0 or bones[v] >= CharKit.BONES.size() or weights[v] != 1.0:
						rigid = false
			tris += t
			most = maxi(most, t)
			var got: String = look.get("category", "")
			if got != cat and not (cat == "general" and got in ["medic", "worker", "office"]):
				wrong.append("category " + got)
			var outfit: String = look.get("outfit", "")
			var bottoms: String = look.get("bottoms", "")
			var bag: String = look.get("bag", "")
			var hat: String = look.get("headwear", "")
			match cat:
				"office":
					if hat != "" or outfit not in ["suit", "blazer", "polo"] or bottoms in ["joggers", "cargo", "shorts", "leggings"]:
						wrong.append("%s/%s/%s" % [outfit, bottoms, hat])
					if look.has("lanyard") or bag == "briefcase" or outfit == "suit":
						flair += 1
				"worker":
					if outfit != "hivis" and look.get("shoe_style", "") != "boots":
						wrong.append("%s in %s" % [outfit, look.get("shoe_style", "")])
				"gang":
					if bag not in ["", "crossbody"] or look.has("glasses"):
						wrong.append("bag %s glasses %s" % [bag, look.has("glasses")])
					if look.has("chain") or hat == "bandana":
						flair += 1
				"tourist":
					if look.has("camera") or bag in ["shopping", "backpack"] or hat in ["bucket", "cap"] or look.has("sunglasses"):
						flair += 1
				"elderly":
					if look.get("hair_color") not in CharKit.GREYS or look.has("headphones") or look.has("phone"):
						wrong.append("hair %s headphones %s phone %s" % [look.get("hair_color"), look.has("headphones"), look.has("phone")])
					if outfit == "cardigan" or look.has("glasses") or look.has("cane"):
						flair += 1
				"athlete":
					if look.has("bag") or look.has("phone") or bottoms not in ["shorts", "leggings", "joggers"]:
						wrong.append("bag %s phone %s %s" % [bag, look.has("phone"), bottoms])
				"shopkeeper":
					if not look.has("apron"):
						wrong.append("no apron")
				"medic":
					if outfit != "scrubs":
						wrong.append(outfit)
		total += tris
		count += 40
		_check(wrong.is_empty(), "%s people dress the part %s" % [cat, wrong])
		_check(tris / 40.0 < 1035.0 and most < 1300, "%s looks within budget: %.0f average, %d at most" % [cat, tris / 40.0, most])
		if cat in ["office", "gang", "tourist", "elderly"]:
			_check(flair >= 24, "most %s people carry their kind's touches (%d of 40)" % [cat, flair])
	_check(rigid, "every category look is bound rigidly to real bones")
	_check(total / float(count) < 1035.0, "the street as a whole stays within budget, %.0f a person" % (total / float(count)))
	var hero := MeshBuilder.new()
	CharKit.build(hero, Player.JULES)
	var plain_look: Dictionary = Player.JULES.duplicate()
	plain_look.erase("hero")
	plain_look.erase("stripes")
	var plain := MeshBuilder.new()
	CharKit.build(plain, plain_look)
	_check(hero.triangle_count() < 1300 and hero.triangle_count() >= plain.triangle_count() + 60,
		"Jules is built finer than a plain look and stays in budget (%d against %d)" % [hero.triangle_count(), plain.triangle_count()])


## Senses.choose(): every answer is a known reaction, each kind of person
## has a range of them, and the situations people meet get the reaction that
## kind of person would show. Patrons indoors and mission characters narrow
## the same choice to what they can do where they are.
func test_reactions_by_kind_of_person() -> void:
	const Patron = preload("res://scripts/patron.gd")
	var used := {}
	var unknown := []
	for cat in PeopleSenses.CATEGORIES:
		var mine := {}
		for pers in PeopleSenses.PERSONALITIES:
			for kind in PeopleSenses.KINDS:
				for near in [false, true]:
					var r: String = PeopleSenses.choose(cat, pers, kind, near)
					if r != "ignore" and not PeopleSenses.HOLD.has(r):
						unknown.append("%s/%s/%s: %s" % [cat, pers, kind, r])
					used[r] = true
					mine[r] = true
		_check(mine.size() >= (5 if cat == "cop" else 8), "%s people have a range of reactions (%d)" % [cat, mine.size()])
	_check(unknown.is_empty(), "every reaction has a hold time %s" % [unknown])
	var unused := PeopleSenses.HOLD.keys().filter(func(k): return not used.has(k))
	_check(unused.is_empty(), "every reaction is shown by someone %s" % [unused])
	# [category, personality, situation, near, reaction]
	var table := [
		["general", "calm", "gunshot", false, "flee"], ["general", "calm", "gunshot", true, "duck"],
		["general", "timid", "gunshot", true, "cower"], ["elderly", "calm", "gunshot", false, "cower"],
		["gang", "brave", "gunshot", false, "look"], ["general", "calm", "explosion", false, "flee"],
		["general", "calm", "aim", true, "hands_up"], ["gang", "brave", "aim", true, "shout"],
		["elderly", "timid", "car_threat", true, "dodge"],
		["gang", "calm", "fight", false, "cheer"], ["tourist", "calm", "fight", false, "film"],
		["office", "calm", "fight", false, "call"], ["shopkeeper", "calm", "fight", false, "call"],
		["medic", "calm", "fight", false, "look"], ["worker", "brave", "fight", false, "shout"],
		["general", "timid", "fight", false, "flee"], ["elderly", "timid", "fight", false, "call"],
		["general", "curious", "fight", false, "film"],
		["general", "calm", "scream", false, "look"], ["general", "timid", "scream", false, "flee"],
		["medic", "calm", "crash", false, "help"], ["worker", "calm", "crash", false, "approach"],
		["general", "calm", "crash", true, "startle"], ["general", "timid", "crash", true, "flee"],
		["tourist", "calm", "crash", false, "film"],
		["gang", "calm", "car_on_sidewalk", false, "shout"], ["office", "calm", "car_on_sidewalk", false, "flee"],
		["medic", "calm", "body", false, "help"], ["gang", "brave", "body", false, "avoid"],
		["office", "calm", "body", false, "call"], ["general", "timid", "body", false, "flee"],
		["general", "calm", "horn", true, "startle"], ["gang", "calm", "horn", false, "shout"],
		["gang", "calm", "siren", false, "hurry"], ["general", "calm", "siren", false, "look"],
		["office", "calm", "car_close", true, "startle"], ["worker", "calm", "car_close", true, "shout"],
		["tourist", "calm", "wanted", false, "film"], ["elderly", "calm", "wanted", false, "avoid"],
		["shopkeeper", "calm", "wanted", false, "call"], ["elderly", "calm", "sprint_past", true, "startle"],
		["general", "calm", "rain", false, "hurry"], ["athlete", "calm", "rain", false, "ignore"],
		["cop", "brave", "fight", false, "investigate"], ["cop", "brave", "gunshot", false, "investigate"],
		["cop", "brave", "car_threat", true, "dodge"], ["cop", "brave", "rain", false, "ignore"],
	]
	var off := []
	for row in table:
		var r: String = PeopleSenses.choose(row[0], row[1], row[2], row[3])
		if r != row[4]:
			off.append("%s %s %s%s: %s, wanted %s" % [row[1], row[0], row[2], " near" if row[3] else "", r, row[4]])
	_check(off.is_empty(), "%d situations get the reaction their kind of person shows %s" % [table.size(), off])
	_check(PeopleSenses.danger("gunshot") > PeopleSenses.danger("fight") and PeopleSenses.danger("fight") > PeopleSenses.danger("horn")
		and PeopleSenses.danger("horn") > PeopleSenses.danger("sprint_past") and PeopleSenses.danger("nothing") == -1,
		"a shot outranks a fight, a fight a horn, a horn someone running past")
	_check(PeopleSenses.is_near("fight", 4.0) and not PeopleSenses.is_near("fight", 4.1) and PeopleSenses.is_near("gunshot", 12.0),
		"near means 4 m for a fight and 12 m for a shot")
	var staff = Patron.new()
	staff.staff = true
	var timid = Patron.new()
	timid.personality = "timid"
	var brave = Patron.new()
	brave.personality = "brave"
	var npc = Npc.new()
	var inside := [
		[staff, "staff", "fight", false, "call"], [staff, "staff", "gunshot", false, "cower"],
		[staff, "staff", "crash", true, "startle"], [timid, "timid customer", "fight", false, "flee"],
		[brave, "brave customer", "crash", false, "look"], [brave, "brave customer", "body", false, "look"],
		[npc, "mission character", "gunshot", false, "duck"], [npc, "mission character", "fight", false, "look"],
		[npc, "mission character", "car_threat", true, "dodge"], [npc, "mission character", "body", false, "look"],
		[npc, "mission character", "crash", true, "startle"],
	]
	off.clear()
	for row in inside:
		var r: String = row[0]._choose_reaction(row[2], row[3], null, {})
		if r != row[4]:
			off.append("%s %s: %s, wanted %s" % [row[1], row[2], r, row[4]])
	_check(off.is_empty(), "staff hold their post, customers leave rather than run over, mission people react on the spot %s" % [off])
	_check(staff.category == "shopkeeper", "shop staff count as shopkeepers")
	# Which reaction wins when a second event comes: [new, its danger, old, its danger, takes over].
	var takeovers := [
		["look", 3, "cheer", 2, true], ["cheer", 1, "look", 2, false], ["flee", 2, "cheer", 2, true],
		["flee", 2, "cower", 2, false], ["look", 2, "cheer", 2, false], ["cheer", 2, "look", 2, true],
		["call", 2, "look", 2, true], ["look", 2, "look", 2, false], ["film", 2, "flee", 2, false],
	]
	off.clear()
	for row in takeovers:
		if npc._replaces(row[0], row[1], row[2], row[3]) != row[4]:
			off.append("%s (%d) over %s (%d)" % [row[0], row[1], row[2], row[3]])
	_check(off.is_empty(), "worse news always takes over; as bad only to get away or to do more than look %s" % [off])
	for n in [staff, timid, brave, npc]:
		n.free()


## Reaction times stay within 0.15-0.6 s and follow distance, nerve and age;
## a queued reaction starts on the first physics tick at or after its time,
## already showing in the body.
func test_reaction_starts_on_time() -> void:
	await _free_game()
	var low := INF
	var high := -INF
	for kind in PeopleSenses.KINDS:
		for cat in PeopleSenses.CATEGORIES:
			for pers in PeopleSenses.PERSONALITIES:
				for d in [0.0, 2.0, 10.0, 40.0, 80.0]:
					var t: float = PeopleSenses.delay(kind, d, pers, cat)
					low = minf(low, t)
					high = maxf(high, t)
	_check(low >= 0.15 - 1e-6 and high <= 0.6 + 1e-6, "every reaction takes 0.15-0.6 s (%.2f-%.2f)" % [low, high])
	_check(PeopleSenses.delay("gunshot", 60.0) > PeopleSenses.delay("gunshot", 2.0) + 0.15, "a far shot takes longer to reach people")
	_check(PeopleSenses.delay("fight", 5.0, "timid") < PeopleSenses.delay("fight", 5.0, "brave"), "the timid jump quicker than the brave")
	_check(PeopleSenses.delay("fight", 5.0, "calm", "elderly") > PeopleSenses.delay("fight", 5.0, "calm", "general") + 0.1, "the elderly react slower")
	_check(PeopleSenses.delay("car_threat", 4.0) <= 0.16, "a car coming at someone gets the quickest reaction")
	var o := Vector3(0, 0, 900)
	var city = _fake_street(o)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	# [situation, metres away, category, personality, reaction]
	var rows := [
		["fight", 3.0, "general", "calm", "look"], ["crash", 20.0, "elderly", "calm", "look"],
		["car_threat", 4.0, "athlete", "timid", "dodge"], ["body", 6.0, "office", "brave", "help"],
		["scream", 10.0, "tourist", "curious", "look"], ["gunshot", 50.0, "gang", "calm", "flee"],
		["horn", 3.0, "worker", "calm", "startle"],
	]
	var peds := []
	for i in rows.size():
		peds.append(_street_ped(city, rng, o + Vector3(i * 30.0 - 90.0, 0, 0), 0.0, rows[i][2], rows[i][3]))
	await _frames(2)
	var due := []
	for i in rows.size():
		var row: Array = rows[i]
		var ped = peds[i]
		ped.perceive(row[0], ped.global_position + Vector3(row[1], 0, 0), null, row[1], {})
		var want: float = PeopleSenses.delay(row[0], row[1], row[3], row[2])
		_check(ped.pending_reaction() == row[4] and absf(ped.pending_in() - want) < 1e-5,
			"%s %s, %s at %.0f m: '%s' queued in %.3f s (wanted '%s' in %.3f s)" % [row[3], row[2], row[0], row[1], ped.pending_reaction(), ped.pending_in(), row[4], want])
		due.append(ped.clock + ped.pending_in())
	var started := []
	started.resize(rows.size())
	started.fill(false)
	for f in 45:
		await _frames(1)
		for i in rows.size():
			var ped = peds[i]
			if started[i] or ped.reacted_at < 0.0:
				continue
			started[i] = true
			var late: float = ped.reacted_at - due[i]
			_check(late >= -1e-4 and late <= 1.0 / 60.0 + 1e-4 and ped.reaction == rows[i][4] and _shows_reaction(ped, rows[i][4]),
				"%s %s starts to %s on the tick it is due (%.4f s late) and shows it" % [rows[i][3], rows[i][2], ped.reaction, late])
	_check(not started.has(false), "every queued reaction started %s" % [started])
	for ped in peds:
		ped.queue_free()


## Sounds carry all round to their hearing radius; sights need the view cone
## (or to be within 3 m). Whoever caused it and whoever was hit are not told,
## nobody down notices anything, an equal scare only interrupts to get away,
## and a scream passes panic on to people who never heard the shot.
func test_people_notice_by_sight_and_sound() -> void:
	await _free_game()
	var o := Vector3(0, 0, 1200)
	var city = _fake_street(o)
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	var ped = _street_ped(city, rng, o, 0.0)
	await _frames(2)
	# [situation at o, metres away, degrees off the way the person faces, data, noticed]
	var cases := [
		["fight", 8.0, 180.0, {}, true], ["fight", 18.0, 0.0, {}, true], ["fight", 18.0, 180.0, {}, false],
		["fight", 30.0, 0.0, {}, false], ["body", 2.5, 180.0, {}, true], ["body", 8.0, 180.0, {}, false],
		["body", 8.0, 0.0, {}, true], ["body", 8.0, 60.0, {}, true], ["body", 8.0, 70.0, {}, false],
		["gunshot", 50.0, 180.0, {}, true], ["gunshot", 70.0, 180.0, {}, false], ["gunshot", 40.0, 180.0, {"loud": 0.5}, false],
		["crash", 30.0, 0.0, {}, true], ["crash", 33.0, 180.0, {}, true], ["horn", 20.0, 180.0, {}, true],
		["siren", 40.0, 90.0, {}, true], ["wanted", 15.0, 90.0, {}, false],
	]
	var wrong := []
	for c in cases:
		# Facing north (-z), the person stands so that o lies c[2] degrees
		# off straight ahead.
		var a := deg_to_rad(c[2])
		ped.global_position = o + Vector3(sin(a), 0, cos(a)) * c[1]
		ped.rotation.y = 0.0
		ped._drop_reactions()
		PeopleSenses.emit(get_tree(), c[0], o, null, c[3])
		if (ped.pending_in() >= 0.0) != c[4]:
			wrong.append("%s %.0f m at %.0f degrees %s" % [c[0], c[1], c[2], c[3]])
	_check(wrong.is_empty(), "%d sights and sounds are noticed only in range and view %s" % [cases.size(), wrong])
	ped.global_position = o + Vector3(0, 0, 5)
	ped._drop_reactions()
	PeopleSenses.emit(get_tree(), "fight", o, ped, {})
	_check(ped.pending_in() < 0.0, "whoever starts a fight is not told about it")
	PeopleSenses.emit(get_tree(), "fight", o, null, {"victim": ped})
	_check(ped.pending_in() < 0.0, "the one being hit is not told about the fight")
	ped.knocked_time = 1.0
	PeopleSenses.emit(get_tree(), "gunshot", o, null, {})
	_check(ped.pending_in() < 0.0, "nobody notices anything while knocked down")
	ped.knocked_time = 0.0
	PeopleSenses.emit(get_tree(), "fight", o, null, {})
	await _frames(30)
	_check(ped.reaction == "look" and ped.reaction_kind == "fight", "a calm passer-by turns to look at a fight, got '%s'" % ped.reaction)
	ped.perceive("scream", o, null, 5.0)
	_check(ped.pending_in() < 0.0, "a scream as bad as the fight does not swap one look for another")
	ped.personality = "timid"
	ped.perceive("scream", o, null, 5.0)
	_check(ped.pending_reaction() == "flee", "but it does send a timid onlooker running, got '%s'" % ped.pending_reaction())
	ped._drop_reactions()
	ped.queue_free()
	var o2 := o + Vector3(0, 0, 200)
	var near = _street_ped(city, rng, o2 + Vector3(25, 0, 0), 0.0)
	var far = _street_ped(city, rng, o2 + Vector3(35, 0, 0), 0.0, "general", "timid")
	await _frames(2)
	PeopleSenses.emit(get_tree(), "gunshot", o2, null, {"loud": 0.5})
	_check(near.pending_reaction() == "flee" and far.pending_in() < 0.0, "a muffled shot is heard 25 m away, not 35 m")
	await _frames(60)
	_check(far.reaction == "flee" and far.reaction_kind == "scream",
		"the scream of someone running sends a timid person 10 m on running too ('%s' at '%s')" % [far.reaction, far.reaction_kind])
	near.queue_free()
	far.queue_free()


## Every pose the rig makes (standing, every gait, gesture and action,
## falling, lying, getting up, fighting, riding, sitting, looking, turning
## and idling) keeps each joint inside Rig.LIMITS with finite values, and
## each gesture and action visibly moves the body.
func test_poses_stay_in_joint_limits() -> void:
	var skel := CharKit.build_rig({})
	var bad := []
	var st = RigScript.State.new()
	st.idle = false
	var stand := _pose_run(skel, st, 90, "standing", bad)
	var flat := []
	for g in RigScript.GESTURES:
		for seated in [false, true]:
			st = RigScript.State.new()
			st.idle = false
			st.sit = seated
			st.gesture = g
			var got := _pose_run(skel, st, 90, g + (" seated" if seated else ""), bad)
			if not seated and _pose_gap(got, stand) < 0.15:
				flat.append("%s %.2f" % [g, _pose_gap(got, stand)])
	_check(flat.is_empty(), "every gesture visibly moves the body %s" % [flat])
	for style in RigScript.STYLES:
		for speed in [0.0, 1.4, 2.2, 4.5, 7.0]:
			for g in ["", "call"]:
				st = RigScript.State.new()
				st.style = style
				st.speed = speed
				st.gesture = g
				_pose_run(skel, st, 60, "%s gait at %.1f m/s %s" % [style, speed, g], bad)
	var still := []
	for a in RigScript.ACTIONS:
		var n := int(round(float(RigScript.ACTIONS[a]) * 60.0))
		var play := func(s, f): s.action_t = float(f) / n if f <= n else -1.0
		for side in [-1.0, 1.0]:
			st = RigScript.State.new()
			st.idle = false
			st.action = a
			st.action_side = side
			var mid := _pose_run(skel, st, n / 2, "%s %+.0f" % [a, side], bad, play)
			if _pose_gap(mid, stand) < 0.2:
				still.append("%s %.2f" % [a, _pose_gap(mid, stand)])
			st = RigScript.State.new()
			st.action = a
			st.action_side = side
			st.speed = 1.4
			_pose_run(skel, st, n + 20, "%s %+.0f walking" % [a, side], bad, play)
	_check(still.is_empty(), "every action visibly moves the body halfway through %s" % [still])
	for dead in [false, true]:
		for face_down in [false, true]:
			for seed in [0, 3, 7]:
				st = RigScript.State.new()
				st.down = true
				st.dead = dead
				st.face_down = face_down
				st.idle_seed = seed
				_pose_run(skel, st, 150, "down dead %s front %s seed %d" % [dead, face_down, seed], bad)
	var rise := func(s, f): s.getup = -1.0 if f < 60 else (f - 60) / 60.0
	for face_down in [false, true]:
		st = RigScript.State.new()
		st.down = true
		st.face_down = face_down
		_pose_run(skel, st, 121, "getting up front %s" % face_down, bad, rise)
	var punches := func(s, f):
		s.punch = float(f % 17) / 17.0
		s.punch_left = int(f / 17.0) % 2 == 1
		s.guard = true
	st = RigScript.State.new()
	_pose_run(skel, st, 102, "punches", bad, punches)
	var kicks := func(s, f): s.kick = float(f % 27) / 27.0
	st = RigScript.State.new()
	_pose_run(skel, st, 81, "kicks", bad, kicks)
	var hit := func(s, f): s.flinch = maxf(1.0 - f / 30.0, 0.0)
	st = RigScript.State.new()
	st.guard = true
	_pose_run(skel, st, 60, "guard and flinch", bad, hit)
	st = RigScript.State.new()
	st.ride = true
	_pose_run(skel, st, 60, "riding", bad)
	for yaw in [-2.5, 2.5]:
		for pitch in [-1.0, 1.0]:
			for speed in [0.0, 1.4]:
				st = RigScript.State.new()
				st.look_amount = 1.0
				st.look_yaw = yaw
				st.look_pitch = pitch
				st.speed = speed
				_pose_run(skel, st, 60, "looking %.1f %.1f" % [yaw, pitch], bad)
	for turn in [-6.0, 6.0]:
		for accel in [-8.0, 8.0]:
			st = RigScript.State.new()
			st.speed = 4.5
			st.turn = turn
			st.accel = accel
			_pose_run(skel, st, 60, "turning %.0f %.0f" % [turn, accel], bad)
	# Standing about with nothing to do, idle acts come round in turn.
	var rig = RigScript.new(skel)
	st = RigScript.State.new()
	st.idle_seed = 7
	var acts := {}
	for f in 3000:
		rig.pose(st, 1.0 / 60.0)
		for i in RigScript.LIMITS.size():
			if not _in_limits(rig.bone_rotation(i), i) and bad.size() < 12:
				bad.append("idle: bone %d at %s, frame %d" % [i, rig.bone_rotation(i), f])
		if rig.idle_act() != "":
			acts[rig.idle_act()] = true
	_check(acts.size() >= 5, "standing about, a person works through idle acts (%s)" % [acts.keys()])
	_check(bad.is_empty(), "every pose keeps each joint inside its limits %s" % [bad])
	skel.free()


## Punch someone in the street and the people round about react each in
## their own way, on time: the gang cheers, the tourist films, the office
## worker calls it in, the timid one runs, the brave worker shouts and the
## medic watches. A cop who catches the player gets their hands up.
func test_crowd_reacts_to_a_punch() -> void:
	await _new_game(false)
	var p = game.player
	_place_player(_home(), Vector3(7.5, 0, 7.5))
	var victim = game.population.spawn_ped_at(p.global_position + p.forward() * 1.0)
	victim.walk_speed = 0.0
	# [category, personality, where from the player, reaction]
	var crowd := [
		["gang", "calm", Vector3(-5, 0, -2), "cheer"], ["tourist", "calm", Vector3(5, 0, -2), "film"],
		["office", "calm", Vector3(-4, 0, 4), "call"], ["general", "timid", Vector3(4, 0, 4), "flee"],
		["worker", "brave", Vector3(0, 0, -8), "shout"], ["medic", "calm", Vector3(-7, 0, -6), "look"],
	]
	var peds := []
	for row in crowd:
		var ped = game.population.spawn_ped_at(p.global_position + row[2])
		ped.walk_speed = 0.0
		ped.category = row[0]
		ped.personality = row[1]
		ped.brave = row[1] == "brave"
		peds.append(ped)
	await _frames(2)
	var start := []
	for ped in peds:
		start.append(ped.global_position)
	await _press("attack")
	_check(victim.health < victim.max_health, "the punch lands")
	var due := []
	for i in peds.size():
		_check(peds[i].pending_reaction() == crowd[i][3],
			"the %s %s sees the punch and is about to %s, got '%s'" % [crowd[i][1], crowd[i][0], crowd[i][3], peds[i].pending_reaction()])
		due.append(peds[i].clock + peds[i].pending_in())
	_check(victim.pending_in() < 0.0 and victim.reaction == "", "the one punched reacts to the hit, not to the fight")
	var seen := []
	seen.resize(peds.size())
	seen.fill(false)
	for f in 45:
		await _frames(1)
		for i in peds.size():
			var ped = peds[i]
			if seen[i] or ped.reacted_at < 0.0:
				continue
			seen[i] = true
			var late: float = ped.reacted_at - due[i]
			_check(late >= -1e-4 and late <= 1.0 / 60.0 + 1e-4 and ped.reaction == crowd[i][3] and _shows_reaction(ped, crowd[i][3]),
				"the %s starts to %s on time (%.4f s late) and shows it ('%s')" % [crowd[i][0], ped.reaction, late, ped.shown_gesture()])
	_check(not seen.has(false), "everyone in the crowd reacts within 0.75 s %s" % [seen])
	await _frames(60)
	for i in peds.size():
		var moved: float = Vector2(peds[i].global_position.x - start[i].x, peds[i].global_position.z - start[i].z).length()
		if crowd[i][3] == "flee":
			_check(moved > 3.0, "the timid one runs off (%.1f m)" % moved)
		else:
			_check(moved < 0.6, "the %s stays put to %s (moved %.2f m)" % [crowd[i][0], crowd[i][3], moved])
	game.police.spawn_cop_at(p.global_position + Vector3(1, 0, 0))
	await _frames(40)
	_check(p.shown_gesture() == "hands_up", "a cop at arm's length gets the player's hands up, got '%s'" % p.shown_gesture())


## A car coming at someone on foot: they see it, step out of its way in
## time and are not hurt. Knocked down, people fall, lie, get up in the
## last stretch of the knockdown and stand when it ends.
func test_people_dodge_cars_and_get_up() -> void:
	await _free_game()
	var o := Vector3(0, 0, 1500)
	var city = _fake_street(o)
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	var ped = _street_ped(city, rng, o + Vector3(0.3, 0, 0), 0.0)
	Controls.camera = null
	await _frames(2)
	var car = _player_car("sedan", o + Vector3(0, 0, 16), 9.0)
	Controls.override_vector = Vector2(0, -0.6)
	var dodged := false
	for f in 150:
		await _frames(1)
		dodged = dodged or (ped.reaction == "dodge" and ped.reaction_kind == "car_threat")
	Controls.override_vector = null
	_check(dodged, "someone a car is heading for sees it and dodges")
	_check(ped.health == ped.max_health and ped.knocked_time <= 0.0 and car.global_position.z < o.z - 4.0,
		"the car goes by without hitting them (car at z %+.1f, health %.0f)" % [car.global_position.z - o.z, ped.health])
	_check(absf(ped.global_position.x - o.x) > 1.2, "they stepped out of its path (%.2f m off it)" % absf(ped.global_position.x - o.x))
	car.queue_free()
	for knock in [2.0, 1.5]:
		var length := minf(clampf(knock - RigScript.FALL_TIME - 0.3, 0.6, RigScript.GETUP_TIME), knock - RigScript.FALL_TIME)
		ped.knock_down(knock)
		var t := 0.0
		var rise := -1.0
		var stood := -1.0
		var last := -1.0
		var steady := true
		var lying := -INF
		for f in int(knock * 60.0) + 10:
			await _frames(1)
			t += 1.0 / 60.0
			var g: float = ped._getup_progress()
			if g >= 0.0:
				if rise < 0.0:
					rise = t
				steady = steady and g >= last - 1e-6
				last = g
			elif rise < 0.0 and t > RigScript.FALL_TIME + 0.2:
				lying = maxf(lying, _hips_height(ped))
			if stood < 0.0 and ped.knocked_time <= 0.0:
				stood = t
		await _frames(30)
		var up := _hips_height(ped)
		_check(absf(rise - (knock - length)) <= 0.05 and steady,
			"knocked down %.1f s, they start getting up at %.2f s (wanted %.2f) and keep rising" % [knock, rise, knock - length])
		_check(absf(stood - knock) <= 0.05, "and stand when it ends (%.2f s)" % stood)
		_check(lying > -INF and lying < 0.45 and up > 0.75, "hips %.2f m up lying, %.2f m standing after" % [lying, up])
	ped.queue_free()


## On a chase a cop ignores everything else; off duty, a fight draws them
## over: a point toward it, a brisk walk to within SCENE_RANGE, a word on
## the radio, then back to the beat.
func test_cops_investigate_off_duty() -> void:
	const Cop = preload("res://scripts/cop.gd")
	await _free_game()
	var o := Vector3(0, 0, 1800)
	var cop = Cop.new()
	cop.position = o + Vector3(0, 0, 10)
	add_child(cop)
	await _frames(2)
	PeopleSenses.emit(get_tree(), "fight", o, null, {})
	_check(cop.pending_in() < 0.0, "a cop on a chase does not stop for a fight")
	cop.active = false
	PeopleSenses.emit(get_tree(), "fight", o, null, {})
	_check(cop.pending_reaction() == "investigate", "off duty, a fight draws the cop over, got '%s'" % cop.pending_reaction())
	await _frames(30)
	_check(cop.reaction == "investigate" and cop.shown_gesture() == "point", "the cop points toward it, got '%s'" % cop.shown_gesture())
	await _frames(200)
	var d: float = Vector2(cop.global_position.x - o.x, cop.global_position.z - o.z).length()
	_check(d < Cop.SCENE_RANGE + 0.5 and cop.shown_gesture() == "call",
		"walks over to %.1f m and radios it in ('%s')" % [d, cop.shown_gesture()])
	await _frames(240)
	_check(cop.reaction == "" and cop.style == "patrol", "then goes back to the beat ('%s', %s)" % [cop.reaction, cop.style])
	cop.queue_free()


## A walker who stops for a bench walks to the nearest free one, turns and
## sits facing out over the seat; a second finds it taken and waits; a
## knocked-down bench is never chosen; a gunshot gets the sitter up and off
## with collisions back on.
func test_people_sit_on_benches() -> void:
	const L = preload("res://scripts/layers.gd")
	await _free_game()
	var o := Vector3(300, 0, 1900)
	var city = _fake_street(o)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var benches := []
	for b in 2:
		var body := StaticBody3D.new()
		body.collision_layer = L.PROPS
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.8, 1.0, 0.6)
		shape.shape = box
		# Seat faces -x (yaw 90°): the backrest is on the far side from the walker.
		shape.position = o + Vector3(2.0, 0.5, 0.0) if b == 0 else o + Vector3(-1.6, 0.5, 0.0)
		shape.rotation.y = PI / 2.0
		shape.set_meta("brk", {"kind": "bench", "down": b == 1})
		body.add_child(shape)
		add_child(body)
		benches.append(shape)
	var ped = _street_ped(city, rng, o, 0.0)
	ped.walk_speed = 1.4
	await _frames(3)
	ped.pause_for("bench", 15.0)
	_check(ped.pause_kind == "bench" and ped._bench == benches[0],
		"a walker picks the standing bench, not the knocked-down nearer one ('%s')" % ped.pause_kind)
	var sat_at := -1
	for f in 300:
		await _frames(1)
		if ped.sitting:
			sat_at = f
			break
	await _frames(30)
	var seat: Vector3 = benches[0].global_position
	var off := Vector2(ped.global_position.x - seat.x, ped.global_position.z - seat.z).length()
	var faces: float = ped.forward().dot(Vector3.LEFT)
	_check(sat_at > 0 and sat_at < 150 and off < 0.15 and faces > 0.95,
		"walks over and sits on the seat in %d frames, %.2f m off, facing out (%.2f)" % [sat_at, off, faces])
	_check(ped.collision_mask & L.PROPS == 0 and _hips_height(ped) < 0.75,
		"sitting, the body clears the bench collider and the hips are at seat height (%.2f m)" % _hips_height(ped))
	var other = _street_ped(city, rng, o + Vector3(0, 0, 1.5), 0.0)
	await _frames(2)
	other.pause_for("bench", 10.0)
	_check(other.pause_kind == "wait", "a second walker finds the bench taken and waits ('%s')" % other.pause_kind)
	ped.perceive("gunshot", o + Vector3(-30, 0, 0), null, 30.0, {})
	await _frames(45)
	_check(not ped.sitting and ped.reaction == "flee" and ped.collision_mask & L.PROPS != 0
		and ped.global_position.distance_to(seat) > 0.5,
		"a gunshot gets the sitter up and running, colliding again ('%s')" % ped.reaction)
	var third = _street_ped(city, rng, o + Vector3(0, 0, -1.0), 0.0)
	third.walk_speed = 1.4
	await _frames(3)
	third.pause_for("bench", 15.0)
	for f in 300:
		await _frames(1)
		if third.sitting:
			break
	var sat: bool = third.sitting
	third.knock_down(0.4) # no attacker, so no reaction ends the sit
	await _frames(60)
	_check(sat and not third.sitting and third.collision_mask & L.PROPS != 0 and third.pause_kind != "bench",
		"knocked down on the bench, a sitter gets up standing, colliding again (sat %s, sitting %s)" % [sat, third.sitting])
	third.queue_free()
	ped.queue_free()
	other.queue_free()
	for b in benches:
		b.get_parent().queue_free()

# --- Road surfaces, roadworks, boundaries and gates (the realism pass) --------

## Road surfaces and roadworks (Sachin, 2026-10-28: "every road seems to have
## same tecture in the city which is opposite from reality, in reality some
## roads are newly paved, some are being paved so there is a construction
## sign, to avoid it, otherwise the cars can get stuck or detriyed and also
## coukd kill people. Some roads are old worn out but still solid, some are
## too washed out but still good, some are built from tiles, of white or
## brown colros etc."): the city's streets and the country's roads mix their
## surfaces by district and class, the same every build; each district has
## two or three roadworks that close the curb lane one way, the other lanes
## and every junction still open, with no parked car, sidewalk or taxi stop
## in them and barriers a car can burst; and a car in traffic drives past
## one in its open lane without touching it.
func test_road_surfaces_and_roadworks() -> void:
	await _new_game(false)
	var city = game.city
	var plan = city.plan
	var CityCells = preload("res://scripts/city_cells.gd")
	var CountryTiles = preload("res://scripts/country_tiles.gd")
	# The city's streets: every kind somewhere, the same each time, another
	# map seed another mix; new tarmac and concrete in the centre, worn and
	# washed-out in the wards.
	var kinds := {}
	var by_style := {}
	var same := true
	var moved := 0
	var streets := 0
	for e in plan.edge_count():
		if not plan.drivable(e):
			continue
		var cls: String = plan.edge_class(e)
		var mid: Vector3 = (city.node_pos(plan.edge_a[e]) + city.node_pos(plan.edge_b[e])) * 0.5
		var style: String = city.district_at(mid).get("style", "quarter")
		var s: String = CityCells.road_surface(city.seed_value, e, cls, style)
		same = same and s == CityCells.road_surface(city.seed_value, e, cls, style)
		moved += 1 if s != CityCells.road_surface(city.seed_value + 1, e, cls, style) else 0
		streets += 1
		kinds[s] = kinds.get(s, 0) + 1
		if not by_style.has(style):
			by_style[style] = {}
		by_style[style][s] = by_style[style].get(s, 0) + 1
	var share := func(styles: Array, which: Array) -> float:
		var n := 0
		var k := 0
		for st: String in styles:
			var mix: Dictionary = by_style.get(st, {})
			for s: String in mix:
				n += int(mix[s])
				k += int(mix[s]) if s in which else 0
		return float(k) / maxf(n, 1.0)
	var centre_new: float = share.call(["downtown", "financial", "civic"], ["fresh", "concrete"])
	var wards_new: float = share.call(["wards", "bayou"], ["fresh", "concrete"])
	var wards_washed: float = share.call(["wards", "bayou"], ["washed"])
	var centre_washed: float = share.call(["downtown", "financial", "civic"], ["washed"])
	var tiled: int = kinds.get("tile_white", 0) + kinds.get("tile_brown", 0) + kinds.get("pavers", 0) + kinds.get("setts", 0)
	_check(kinds.size() >= 7 and same and moved > streets / 3 and tiled > 0,
		"the city's %d streets mix %d surfaces (%s), the same every build, %d another with another seed" % [streets, kinds.size(), kinds, moved])
	_check(centre_new > wards_new + 0.2 and wards_washed > centre_washed + 0.2,
		"new tarmac and concrete downtown (%.0f%%, wards %.0f%%), washed-out tarmac in the wards (%.0f%%, downtown %.0f%%)"
		% [centre_new * 100.0, wards_new * 100.0, wards_washed * 100.0, centre_washed * 100.0])
	# The country's roads: their surface by class, in stretches along a road.
	var c = city.country
	var ckinds := {}
	var per_road := {}
	for e in c.edge_a.size():
		if c.edge_road[e] < 0:
			continue
		var s: String = CountryTiles.road_surface(c, e)
		ckinds[s] = ckinds.get(s, 0) + 1
		var rd: int = c.edge_road[e]
		if not per_road.has(rd):
			per_road[rd] = {}
		per_road[rd][s] = true
	var mixed_roads := 0
	for rd in per_road:
		mixed_roads += 1 if per_road[rd].size() > 1 else 0
	_check(ckinds.size() >= 4 and mixed_roads >= 3, "the country's roads mix %d surfaces (%s), %d roads change along their way" % [ckinds.size(), ckinds, mixed_roads])
	# The roadworks.
	var per_district := {}
	var wrong: Array[String] = []
	var loop_rects: Array[Rect2] = []
	for loop: PackedVector3Array in city.sidewalk_loops:
		var r := Rect2(Vector2(loop[0].x, loop[0].z), Vector2.ZERO)
		for p: Vector3 in loop:
			r = r.expand(Vector2(p.x, p.z))
		loop_rects.append(r)
	for e: int in city.roadworks:
		var wk: Dictionary = city.roadworks[e]
		var na: int = plan.edge_a[e]
		var nb: int = plan.edge_b[e]
		var pa: Vector3 = city.node_pos(na)
		var pb: Vector3 = city.node_pos(nb)
		var length := pa.distance_to(pb)
		var dir := (pb - pa) / length
		var right := Vector3(-dir.z, 0, dir.x)
		var sd: float = wk.side
		var id: String = city.district_at((pa + pb) * 0.5).get("id", "")
		per_district[id] = per_district.get(id, 0) + 1
		var g: Dictionary = StreetPlan.CLASSES[plan.edge_class(e)]
		var w: float = g.width
		var tag := "works on %s street %d (%s side %+d, %.0f-%.0f m)" % [g.get("name", plan.edge_class(e)), e, id, int(sd), wk.x0, wk.x1]
		# One lane shut that way, the far side of the street as it was.
		var shut: Dictionary = city.lanes_of(na, nb) if sd > 0.0 else city.lanes_of(nb, na)
		var other: Dictionary = city.lanes_of(nb, na) if sd > 0.0 else city.lanes_of(na, nb)
		if int(shut.get("lanes", 0)) != int(g.lanes) - 1 or int(shut.get("lanes", 0)) < 1 or int(shut.get("closed", 0)) != 1:
			wrong.append("%s: %d lanes open that way of %d" % [tag, int(shut.get("lanes", 0)), int(g.lanes)])
		if int(other.get("lanes", 0)) != int(g.lanes) or other.has("closed"):
			wrong.append("%s: the other way lost a lane" % tag)
		# The open lanes keep clear of the barrier line.
		var zi: float = float(g.middle) + float(g.lane_w) * (int(g.lanes) - 1) + 0.35
		var outer: float = city.lane_offset(shut, 0) + float(g.lane_w) * 0.5
		if outer > zi - 0.25 + 0.01:
			wrong.append("%s: the open lane runs to %.2f m, the barriers start at %.2f m" % [tag, outer, zi - 0.25])
		# No car parked in it, its taper or its sign.
		for spot: Array in city.parked_spots:
			var q: Vector3 = spot[0] - pa
			var x := q.dot(dir)
			var z := q.dot(right) * sd
			if x > wk.x0 - 25.0 and x < wk.x1 + 25.0 and z > 0.0 and z < w * 0.5 + 1.0:
				wrong.append("%s: a car parked in it at %.0f m" % [tag, x])
		# A taxi stop there moves out of it.
		var stop: Vector3 = city.clear_of_works(na, nb, pa + dir * (wk.x0 + wk.x1) * 0.5)
		var sx := (stop - pa).dot(dir)
		if sx > wk.x0 - city.WORKS_TAPER - 1.0 and sx < wk.x1 + city.WORKS_TAPER + 1.0:
			wrong.append("%s: a taxi stop left at %.0f m" % [tag, sx])
		# No sidewalk loop through the pit.
		var pit := PackedVector2Array()
		for corner: Vector2 in [Vector2(wk.x0, zi), Vector2(wk.x1, zi), Vector2(wk.x1, w * 0.5 - 0.25), Vector2(wk.x0, w * 0.5 - 0.25)]:
			var p3: Vector3 = pa + dir * corner.x + right * sd * corner.y
			pit.append(Vector2(p3.x, p3.z))
		var pit_rect := Rect2(pit[0], Vector2.ZERO).expand(pit[1]).expand(pit[2]).expand(pit[3]).grow(0.5)
		for i in loop_rects.size():
			if not loop_rects[i].intersects(pit_rect):
				continue
			var loop: PackedVector3Array = city.sidewalk_loops[i]
			for j in loop.size():
				var u := Vector2(loop[j].x, loop[j].z)
				var v := Vector2(loop[(j + 1) % loop.size()].x, loop[(j + 1) % loop.size()].z)
				var hit := Geometry2D.is_point_in_polygon(u, pit)
				for k in 4:
					hit = hit or Geometry2D.segment_intersects_segment(u, v, pit[k], pit[(k + 1) % 4]) != null
				if hit:
					wrong.append("%s: a sidewalk runs through the pit" % tag)
					break
	# Every junction still reached from the start (the works close a lane,
	# never a street).
	var start: int = city.nearest_node(city.spawn_point)
	var seen := {start: true}
	var todo: Array[int] = [start]
	while not todo.is_empty():
		var n: int = todo.pop_back()
		for m: int in city.next_nodes(n):
			if m < city.COUNTRY_BASE and not seen.has(m):
				seen[m] = true
				todo.append(m)
	var stranded := 0
	for n in plan.node_count():
		if city.drive_node(n) and not city.next_nodes(n).is_empty() and not seen.has(n):
			stranded += 1
	for e: int in city.roadworks:
		if not (seen.has(plan.edge_a[e]) and seen.has(plan.edge_b[e])):
			wrong.append("works street %d cut off from the start" % e)
	var most := 0
	for id in per_district:
		most = maxi(most, per_district[id])
	for p in wrong.slice(0, 20):
		print("  " + p)
	_check(city.roadworks.size() >= 6 and per_district.size() >= 3 and most <= 3 and wrong.is_empty() and stranded == 0,
		"%d roadworks in %d districts (at most %d in one) each shut one lane one way, clear of parked cars, taxi stops and sidewalks; %d junctions cut off (%d problems)"
		% [city.roadworks.size(), per_district.size(), most, stranded, wrong.size()])
	# A car in traffic on the works side of the nearest works.
	var best_e := -1
	var best_d := INF
	for e: int in city.roadworks:
		var at: Vector3 = (city.node_pos(plan.edge_a[e]) + city.node_pos(plan.edge_b[e])) * 0.5
		if at.distance_to(city.spawn_point) < best_d:
			best_d = at.distance_to(city.spawn_point)
			best_e = e
	if best_e < 0:
		_check(false, "a street with roadworks to drive past")
		return
	var wk: Dictionary = city.roadworks[best_e]
	var sd: float = wk.side
	var na: int = plan.edge_a[best_e]
	var nb: int = plan.edge_b[best_e]
	var pa: Vector3 = city.node_pos(na)
	var pb: Vector3 = city.node_pos(nb)
	var length := pa.distance_to(pb)
	var dir := (pb - pa) / length
	var right := Vector3(-dir.z, 0, dir.x)
	var g: Dictionary = StreetPlan.CLASSES[plan.edge_class(best_e)]
	var zi: float = float(g.middle) + float(g.lane_w) * (int(g.lanes) - 1) + 0.35
	var from := na if sd > 0.0 else nb
	var to := nb if sd > 0.0 else na
	var xa: float = wk.x0 if sd > 0.0 else wk.x1
	var xb: float = wk.x1 if sd > 0.0 else wk.x0
	var works_at: Vector3 = pa + dir * (wk.x0 + wk.x1) * 0.5
	game.player.global_position = works_at - right * sd * (float(g.width) * 0.5 + 2.5) + Vector3(0, 0.5, 0)
	game.player.reset_physics_interpolation()
	city.stream_now(works_at)
	await _frames(2)
	var barriers: Array[CollisionShape3D] = []
	for cell in city.get_children():
		for body in cell.get_children():
			if not body is StaticBody3D:
				continue
			for s in body.get_children():
				if s is CollisionShape3D and s.has_meta("brk") and s.get_meta("brk").kind == "roadworks" \
						and s.global_position.distance_to(works_at) < (wk.x1 - wk.x0) * 0.5 + 30.0:
					barriers.append(s)
	var x_start: float = clampf(xa - sd * (city.WORKS_TAPER + 30.0), 2.0, length - 2.0)
	var lanes: Dictionary = city.lanes_of(from, to)
	var heading := dir * sd
	var car = Vehicle.new()
	car.kind = "sedan"
	car.city = city
	car.position = pa + dir * x_start + right * sd * city.lane_offset(lanes, 0) + Vector3(0, 0.3, 0)
	car.rotation.y = atan2(-heading.x, -heading.z)
	car.rng.seed = 11
	car.start_traffic(city, from, to)
	game.add_child(car)
	var widest := -INF
	var past := false
	var frames := 0
	for f in 900:
		await _frames(1)
		frames = f
		var q: Vector3 = car.global_position - pa
		var x := q.dot(dir)
		if x > wk.x0 - 1.0 and x < wk.x1 + 1.0:
			widest = maxf(widest, q.dot(right) * sd)
		if (x - xb) * sd > 6.0:
			past = true
			break
	var burst := barriers.filter(func(s): return s.get_meta("brk").get("down", false)).size()
	_check(barriers.size() >= 6 and past and not car.wrecked and widest < zi - 0.25 - 0.6 and burst == 0,
		"a car in traffic drives past the roadworks %.0f m off in its open lane in %.1f s (%s; out to %.2f m, barriers from %.2f m; %d of %d barriers burst)"
		% [best_d, frames / 60.0, "past" if past else "stuck", widest, zi - 0.25, burst, barriers.size()])
	car.queue_free()
	await _frames(1)


## Traffic round the roadworks (brief: "no car stuck at roadworks over a
## simulated run"): at the three works nearest the start, a car in every open
## lane the works way, one the other way and one turning in from a side
## street drive for 25 s. None may wreck, burst a barrier or stand still
## (under 0.5 m/s) for more than 12 s in all; the works-way cars all pass.
func test_traffic_flows_past_roadworks() -> void:
	await _new_game(false)
	var city = game.city
	var plan = city.plan
	var edges: Array = city.roadworks.keys()
	edges.sort_custom(func(a: int, b: int) -> bool:
		var ma: Vector3 = (city.node_pos(plan.edge_a[a]) + city.node_pos(plan.edge_b[a])) * 0.5
		var mb: Vector3 = (city.node_pos(plan.edge_a[b]) + city.node_pos(plan.edge_b[b])) * 0.5
		return ma.distance_to(city.spawn_point) < mb.distance_to(city.spawn_point))
	var problems: Array[String] = []
	var cars_run := 0
	var passed_n := 0
	for e: int in edges.slice(0, 3):
		var wk: Dictionary = city.roadworks[e]
		var sd: float = wk.side
		var na: int = plan.edge_a[e]
		var nb: int = plan.edge_b[e]
		var pa: Vector3 = city.node_pos(na)
		var pb: Vector3 = city.node_pos(nb)
		var dir := (pb - pa).normalized()
		var right := Vector3(-dir.z, 0, dir.x)
		var works_at: Vector3 = pa + dir * (float(wk.x0) + float(wk.x1)) * 0.5
		var from := na if sd > 0.0 else nb
		var to := nb if sd > 0.0 else na
		var xb: float = wk.x1 if sd > 0.0 else wk.x0
		city.stream_now(works_at)
		game.player.global_position = works_at - right * sd * (float(StreetPlan.CLASSES[plan.edge_class(e)].width) * 0.5 + 2.5) + Vector3(0, 0.5, 0)
		game.player.reset_physics_interpolation()
		await _frames(2)
		var barriers: Array = []
		for cell in city.get_children():
			for body in cell.get_children():
				if body is StaticBody3D:
					for sh in body.get_children():
						if sh is CollisionShape3D and sh.has_meta("brk") and sh.get_meta("brk").kind == "roadworks" \
								and sh.global_position.distance_to(works_at) < 60.0:
							barriers.append(sh)
		# [from, to, lane, must pass the works]
		var starts: Array = []
		for k in city.lane_count(from, to):
			starts.append([from, to, k, true])
		starts.append([to, from, 0, false])
		for m: int in city.next_nodes(from):
			if m != to and m < city.COUNTRY_BASE:
				starts.append([m, from, 0, false])
				break
		var cars: Array = []
		var still := {}
		var went := {}
		var rng := RandomNumberGenerator.new()
		rng.seed = e
		for st: Array in starts:
			var car = Vehicle.new()
			car.kind = "sedan"
			car.city = city
			car.position = city.lane_start(st[0], st[1], st[2]) + Vector3(0, 0.3, 0)
			var heading: Vector3 = city.node_pos(st[1]) - city.node_pos(st[0])
			car.rotation.y = atan2(-heading.x, -heading.z)
			car.rng.seed = rng.randi()
			car.start_traffic(city, st[0], st[1], st[2])
			game.add_child(car)
			cars.append(car)
			still[car] = 0
			went[car] = false
		for f in 1500:
			await _frames(1)
			for i in cars.size():
				var car = cars[i]
				if car.velocity.length() < 0.5:
					still[car] += 1
				if starts[i][3] and ((car.global_position - pa).dot(dir) - xb) * sd > 6.0:
					went[car] = true
		for i in cars.size():
			var car = cars[i]
			var tag := "works %d, car %d (%d->%d lane %d)" % [e, i, starts[i][0], starts[i][1], starts[i][2]]
			cars_run += 1
			if car.wrecked:
				problems.append("%s wrecked" % tag)
			if still[car] > 12 * 60:
				problems.append("%s stood still %.1f s" % [tag, still[car] / 60.0])
			if starts[i][3]:
				if went[car]:
					passed_n += 1
				else:
					problems.append("%s never got past the works" % tag)
			car.queue_free()
		var burst := barriers.filter(func(sh): return sh.get_meta("brk").get("down", false)).size()
		if burst > 0 or barriers.is_empty():
			problems.append("works %d: %d of %d barriers burst" % [e, burst, barriers.size()])
		await _frames(1)
	for p in problems:
		print("  " + p)
	_check(problems.is_empty() and cars_run >= 9 and passed_n >= 3,
		"traffic round 3 roadworks: %d cars for 25 s each, %d past the works in the open lanes, none wrecked, stuck or through a barrier (%d problems)"
		% [cars_run, passed_n, problems.size()])


## Boundaries and gates by household (Sachin, 2026-10-28: "every home does
## not need to have same length and height of gate, make it mixed please" and
## "every house should not same kind of fence some can have it but others can
## have their own different types of boundaries, from wood, concrete, ply,
## some high some low etc, depending upon the people, location etc."):
## boundary() gives each tier several fronts, poor ones at T0-T1 and rich
## ones at T4-T5, from knee-high to over 2 m, sides and back always, the same
## for the same household, the zone leaning the pick; farms, adobes, ward
## yards and estate walls vary too; built homes hang gates of mixed width,
## kind and height, none standing in a way out, and every collider is a real
## box.
func test_boundaries_vary_by_household() -> void:
	await _free_game()
	var Kit = preload("res://scripts/kits/country_kit.gd")
	var MB = preload("res://scripts/mesh_builder.gd")
	var Grounds = preload("res://scripts/kits/grounds_kit.gd")
	var CityCells = preload("res://scripts/city_cells.gd")
	const POOR := ["", "broken", "chain", "ply", "wire", "block"]
	const RICH := ["hedge", "iron", "wall", "brick"]
	var fronts: Array[Dictionary] = []
	var heights: Array[Array] = []
	var styles := {}
	var gate_kinds := {}
	var gate_hs := {}
	var extras := {}
	var walks := [0, 0]
	var wrong: Array[String] = []
	for t in 6:
		fronts.append({})
		heights.append([])
		for s in 80:
			var b: Dictionary = Kit.boundary(t, "", hash([s, "boundary"]))
			if b.hash() != Kit.boundary(t, "", hash([s, "boundary"])).hash():
				wrong.append("T%d seed %d: another boundary the second time" % [t, s])
			fronts[t][b.style] = fronts[t].get(b.style, 0) + 1
			styles[b.style] = true
			styles[b.back] = true
			if b.style != "":
				heights[t].append(b.h)
			if b.back == "" or b.back_h < 1.0:
				wrong.append("T%d seed %d: sides and back %s %.2f m" % [t, s, b.back, b.back_h])
			if (t <= 1 and not b.style in POOR) or (t >= 4 and not b.style in RICH):
				wrong.append("T%d seed %d: a %s front" % [t, s, b.style])
			gate_kinds[b.gate] = true
			gate_hs[b.gate_h] = true
			extras[b.drive_extra] = true
			walks[1 if b.walk > 0.0 else 0] += 1
	var mean := func(list: Array) -> float:
		var sum := 0.0
		for h: float in list:
			sum += h
		return sum / maxf(list.size(), 1.0)
	var all_h: Array = []
	for list in heights:
		all_h.append_array(list)
	var fewest := 99
	for t in 6:
		fewest = mini(fewest, fronts[t].size())
	var rich_h: float = mean.call(heights[4] + heights[5])
	var mid_h: float = mean.call(heights[2] + heights[3])
	var materials := ["picket", "board", "slat", "ply", "block", "wall", "chain", "iron", "hedge", "brick", "wire", "stone", "broken", "low"]
	var missing := materials.filter(func(m): return not styles.has(m))
	for p in wrong.slice(0, 20):
		print("  " + p)
	_check(wrong.is_empty() and fewest >= 3 and missing.is_empty() and all_h.min() <= 0.8 and all_h.max() >= 2.3 and rich_h > mid_h + 0.4,
		"boundaries: at least %d fronts a tier (T0 %s, T5 %s), poor at T0-T1 and rich at T4-T5, %.2f-%.2f m (T4-T5 %.2f m, T2-T3 %.2f m), sides and back always, missing %s (%d problems)"
		% [fewest, fronts[0].keys(), fronts[5].keys(), all_h.min(), all_h.max(), rich_h, mid_h, missing, wrong.size()])
	_check(gate_kinds.size() == 4 and gate_hs.size() >= 8 and extras.size() >= 8 and walks[0] > 0 and walks[1] > 0,
		"gates: %s, %d heights, %d drive gate margins, %d with a walk gate and %d without" % [gate_kinds.keys(), gate_hs.size(), extras.size(), walks[1], walks[0]])
	# The zone leans the pick: stone walls in the mountains.
	var stone := [0, 0]
	for s in 120:
		stone[0] += 1 if Kit.boundary(3, "", hash([s, "zone"])).style == "stone" else 0
		stone[1] += 1 if Kit.boundary(3, "mountain", hash([s, "zone"])).style == "stone" else 0
	_check(stone[1] > stone[0] + 10, "T3 stone fronts: %d in the mountains, %d elsewhere" % [stone[1], stone[0]])
	# Farms, adobes, ward back yards and estate walls.
	var farm := {}
	var farm_h := {}
	var adobe := {}
	for s in 60:
		var r := RandomNumberGenerator.new()
		r.seed = s
		var f: Dictionary = Kit._farm_fence(r, "rail", Color.WHITE)
		farm[f.style] = true
		farm_h[f.h] = true
		adobe[Kit._adobe_wall(r, Color.WHITE).style] = true
	var yard_h := {}
	var open_yards := 0
	var yr := RandomNumberGenerator.new()
	yr.seed = 5
	for k in 40:
		var out: Array = []
		CityCells._yard_fence(MB.new(), out, Vector3(0, 0, -3), Vector3(0, 0, 3), yr)
		open_yards += 1 if out.is_empty() else 0
		for col in out:
			yard_h[snappedf(col[1].y, 0.05)] = true
	var wall_h := {}
	var wall_look := {}
	for p in 40:
		var look: Array = Grounds._wall_look(hash([p, "plot"]))
		wall_h[look[0]] = true
		wall_look[look[1]] = true
	_check(farm.size() >= 3 and farm.has("") and farm_h.size() >= 4 and adobe.size() >= 3 and yard_h.size() >= 4 and wall_h.size() >= 5 and wall_look.size() >= 3,
		"farm fences %s (%d heights), adobe walls %s, ward yards at %d heights (%d open), estate walls at %d heights in %d looks"
		% [farm.keys(), farm_h.size(), adobe.keys(), yard_h.size(), open_yards, wall_h.size(), wall_look.size()])
	# Built homes: gates of mixed kind, width and height; no boundary part in
	# a way out from the lot's front edge to 2.5 m in; every collider a real box;
	# the same household the same each build.
	var leaf_counts := {}
	var leaf_hs := {}
	var gate_ws := {}
	var problems: Array[String] = []
	Kit.record_routes = true
	Kit.reach = [4.0, 4.0, 4.0]
	for kind: String in ["house", "trailer_home", "mansion", "exec_house", "cheap_block", "bungalow_barred", "res_tower", "midrise_condo",
			"farmhouse", "farmhouse_small", "farmhouse_big", "ranch_house", "adobe_farmhouse", "shack", "stilt_house", "garden_apartments"]:
		var size: Vector2 = Kit.footprint(kind)
		for tier in 6:
			for seed in (6 if kind == "house" else 1):
				var rng := RandomNumberGenerator.new()
				rng.seed = seed + 17 * tier
				var out: Array = []
				Kit.wealth = tier
				Kit.routes_drawn.clear()
				Kit.build(kind, MB.new(), out, size, rng)
				Kit.wealth = -1
				var tag := "%s T%d seed %d" % [kind, tier, rng.seed]
				var leaves := 0
				for col in out:
					if not col is Array:
						continue
					var cc: Vector3 = col[0]
					var cs: Vector3 = col[1]
					if not (cc.is_finite() and cs.is_finite()) or cs.x <= 0.0 or cs.y <= 0.0 or cs.z <= 0.0:
						problems.append("%s: collider at %s size %s" % [tag, cc, cs])
						continue
					if col.size() > 2:
						continue
					if (is_equal_approx(cs.x, 0.08) or is_equal_approx(cs.z, 0.08)) and cc.z < -size.y * 0.5 + 4.5:
						leaves += 1
						leaf_hs[snappedf(cs.y, 0.05)] = true
					if cs.y > 2.6 or cc.z - cs.z * 0.5 > -size.y * 0.5 + 2.5 or cc.z + cs.z * 0.5 < -size.y * 0.5:
						continue
					# Only the boundary's kind of thing (runs, leaves, posts, piers,
					# hedges: under 1.2 m through): the household's car on its drive
					# and a shack's deck the walk climbs onto are meant to be there.
					if minf(cs.x, cs.z) > 1.2:
						continue
					for r: Vector4 in Kit.routes_drawn:
						if r.z <= 0.0:
							continue
						var m := (r.x + r.y) * 0.5
						var half := maxf(0.2, (r.y - r.x) * 0.5 - 0.4)
						if minf(m + half, cc.x + cs.x * 0.5) - maxf(m - half, cc.x - cs.x * 0.5) > 0.02:
							problems.append("%s: %s by %s in the way out %.1f-%.1f" % [tag, cc, cs, r.x, r.y])
				if kind == "house":
					leaf_counts[leaves] = true
					# Gate widths: the gaps between the front line's runs.
					var runs: Array = []
					for col in out:
						if col is Array and col.size() == 2 and col[1].x > 0.3 and col[1].z < 0.9 and absf(col[0].z - (-size.y * 0.5 + 1.2)) < 0.1:
							runs.append(Vector2(col[0].x - col[1].x * 0.5, col[0].x + col[1].x * 0.5))
					runs.sort_custom(func(a: Vector2, c: Vector2) -> bool: return a.x < c.x)
					for i in range(1, runs.size()):
						if runs[i].x - runs[i - 1].y > 0.5:
							gate_ws[snappedf(runs[i].x - runs[i - 1].y, 0.1)] = true
	# The same household builds the same boundary.
	var twice: Array = []
	for k in 2:
		var rng := RandomNumberGenerator.new()
		rng.seed = 9
		var out: Array = []
		Kit.wealth = 3
		Kit.build("house", MB.new(), out, Kit.footprint("house"), rng)
		Kit.wealth = -1
		twice.append(out)
	Kit.routes_drawn.clear()
	Kit.record_routes = false
	Kit.reach = [0.0, 0.0, 0.0]
	for p in problems.slice(0, 40):
		print("  " + p)
	_check(problems.is_empty() and twice[0] == twice[1] and leaf_counts.size() >= 3 and leaf_hs.size() >= 4 and gate_ws.size() >= 4,
		"built homes: gates with %s leaves at %d heights, ways out %d widths, the same each build (%s), colliders sane and no way out blocked (%d problems)"
		% [leaf_counts.keys(), leaf_hs.size(), gate_ws.size(), twice[0] == twice[1], problems.size()])


## Sachin's 0.21 video: an 18-wheeler stuck while the whole view shook. A
## car parked at the curb could spawn inside the long trailer (spawns
## checked only how near the other cars' centres were), so every spawn now
## needs room for its whole footprint.
func test_spawns_need_room() -> void:
	await _free_game()
	var semi = _track_car("semi", Vector3.ZERO, 0.0)
	await _frames(1)
	var sedan := VehicleKit.size_of("sedan")
	_check(not Vehicle.room_for(get_tree(), Vector3(1.0, 0, 5.5), 0.0, sedan, 0.5), "no room for a sedan under the semi's trailer, 5.5 m from its centre")
	_check(not Vehicle.room_for(get_tree(), Vector3(2.2, 0, -3.0), PI * 0.5, sedan, 0.5), "nor for one across its cab")
	_check(Vehicle.room_for(get_tree(), Vector3(5.0, 0, 0.0), 0.0, sedan, 0.5), "but room for one beside it in the next lane")
	_check(Vehicle.room_for(get_tree(), Vector3(0.0, 0, 12.0), 0.0, sedan, 0.5), "and behind the trailer")
	semi.queue_free()
	await _frames(1)


## A car held against a wall at full throttle: its smoothed motion, which
## the camera's lead and the speedometer read, stays near nought, so the
## view holds still (its commanded velocity flips each frame).
func test_pinned_car_holds_still() -> void:
	await _free_game()
	var L = preload("res://scripts/layers.gd")
	var wall := StaticBody3D.new()
	wall.collision_layer = L.WORLD
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(20, 4, 0.5)
	wall.add_child(shape)
	wall.position = Vector3(0.0, 2.0, -9.0)
	add_child(wall)
	var semi = _player_car("semi", Vector3.ZERO, 0.0)
	Controls.override_vector = Vector2(0, -1)
	await _frames(240)
	var most := 0.0
	var start: Vector3 = semi.global_position
	for f in 60:
		await _frames(1)
		most = maxf(most, semi.motion.length())
	_check(most < 1.0, "a semi pinned against a wall at full throttle shows at most %.2f m/s of motion" % most)
	_check(semi.global_position.distance_to(start) < 0.3, "and stays put (moved %.2f m in a second)" % semi.global_position.distance_to(start))
	Controls.override_vector = null
	semi.queue_free()
	wall.queue_free()
	await _frames(1)


## Every traffic, parked, taxi and police model and paint is built while
## the game loads, so a car's first appearance never builds a mesh (0.23).
## Sachin, 2026-10-28: "the Hero is being hidden behind the bus stop, in
## the very beginning scene of the first mission ... ensure Hero is always
## visible in such cases". Roofs people stand under are on L.SIGHT, which
## only the camera's rays test, and the city shader keeps a small hole open
## over the player whatever the colliders say.
func test_hero_seen_under_roofs() -> void:
	var L = preload("res://scripts/layers.gd")
	var Props = preload("res://scripts/kits/prop_kit.gd")
	var out: Array = []
	Props.bus_shelter(MeshBuilder.new(), out, Vector3.ZERO, RandomNumberGenerator.new())
	var roofs := out.filter(func(c): return L.sight_only(c))
	_check(roofs.size() == 1 and roofs[0][0].y > 2.2 and roofs[0][1].x > 3.7, "a bus shelter's roof is a sight-only box over head height (%s)" % [roofs])
	await _new_game(false)
	var cam = game.camera
	var p = game.player
	var probe := Vehicle.new()
	add_child(probe)
	_check(p.collision_mask & L.SIGHT == 0 and probe.collision_mask & L.SIGHT == 0, "nothing walks or drives into the sight layer")
	probe.queue_free()
	var sight: Array = []
	for b in game.city.find_children("*", "StaticBody3D", true, false):
		if b.collision_layer == L.SIGHT:
			sight.append(b)
	_check(not sight.is_empty() and sight.all(func(b): return b.collision_mask == 0 and b.get_children().all(func(c): return not c.has_meta("brk"))), "downtown cells have sight-only roofs, colliding with nothing and never breakable (%d)" % sight.size())
	if sight.is_empty():
		return
	var roof: Vector3 = sight[0].get_child(0).global_position
	var under := Vector3(roof.x, roof.y - 2.45, roof.z)
	_place_player_at(under)
	await _frames(10)
	_check(cam._view_blocked(p.global_position), "standing under a shelter roof opens the see-through hole")
	_check(cam.covered(cam.get_world_3d().direct_space_state, cam.global_position, p), "and the x-ray counts the roof as cover")
	var mat = MeshBuilder.cutaway_material()
	_check(mat.get_shader_parameter("body_radius") == cam.BODY_CUT and cam.BODY_CUT > 0.8, "the small body hole is always open over the player")
	# Opening of mission 1: the camera comes down in front of the hero.
	var far_off: float = cam.global_position.distance_to(p.global_position)
	p.rotation.y = 0.0
	_check(cam.set_close_up(p), "a clear angle onto the hero's face is found")
	await _frames(90)
	var rel: Vector3 = cam.global_position - p.global_position
	var ahead: Vector3 = -p.global_basis.z
	_check(cam.close_up_amount() == 1.0 and rel.length() < 7.0 and rel.dot(ahead) > 2.0 and rel.y > 1.0 and rel.y < 3.0, "the close-up is in front of the hero at face height (%s)" % rel)
	var to_face: Vector3 = (p.global_position + Vector3(0, 1.15, 0) - cam.global_position).normalized()
	_check(-cam.global_basis.z.dot(to_face) > 0.99, "and looks at him")
	cam.set_close_up(null)
	await _frames(90)
	_check(cam.close_up_amount() == 0.0 and cam.global_position.distance_to(p.global_position) > far_off * 0.8, "then eases back to the usual view")
	# Boxed in on every side: no close-up, the usual view stays.
	var box := StaticBody3D.new()
	box.collision_layer = L.WORLD
	for a in 12:
		var sh := CollisionShape3D.new()
		sh.shape = BoxShape3D.new()
		sh.shape.size = Vector3(1.0, 4.0, 1.0)
		sh.position = Vector3(cos(TAU * a / 12.0), 2.0, sin(TAU * a / 12.0)) * 1.4
		box.add_child(sh)
	add_child(box)
	box.global_position = p.global_position
	await _frames(2)
	_check(not cam.set_close_up(p) and cam.close_up == null, "with walls all round there is no close-up")
	box.queue_free()
	await _frames(2)


func test_cars_prewarmed() -> void:
	await _new_game(false)
	var missing := []
	for i in 300:
		var car = game.population._new_car(i % 2 == 0, i % 7 - 1)
		var key := "%s|%s" % [car.kind, car.body_color.to_html()]
		if not Vehicle._meshes.has(key) and not missing.has(key):
			missing.append(key)
		car.free()
	var cop = Vehicle.new()
	cop.is_police = true
	if not Vehicle._meshes.has("police|%s" % cop.body_color.to_html()):
		missing.append("police")
	cop.free()
	_check(missing.is_empty(), "every traffic and parked car's mesh is built at load (missing %s)" % [missing])


## The see-through silhouette shows only while a wall or a car hides the
## player (Sachin, 2026-10-29), never on open road.
func test_xray_only_when_hidden() -> void:
	await _new_game(false)
	var L = preload("res://scripts/layers.gd")
	var cam = game.camera
	var p = game.player
	var at: Vector3 = game.city.node_pos(_home()) + Vector3(0, 0, 0)
	_place_player_at(at)
	await _frames(20)
	cam._update_xray(1.0, p.global_position)
	var open_hidden: bool = cam.covered(cam.get_world_3d().direct_space_state, cam.global_position, p)
	_check(p.is_in_group("xray") and not open_hidden and not p.xray_shown, "on an open junction the player is not covered and has no silhouette")
	# A wall right between the player and the camera.
	var wall := StaticBody3D.new()
	wall.collision_layer = L.WORLD
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(6, 6, 6)
	wall.add_child(shape)
	add_child(wall)
	var mid: Vector3 = p.global_position.lerp(cam.global_position, 0.25)
	wall.global_position = mid
	await _frames(2)
	# The test wall is not a cutaway mesh: keep the see-through hole shut.
	cam._cut = 0.0
	cam._update_xray(1.0, p.global_position)
	_check(p.xray_shown and p.body_mesh.material_override.stencil_mode == BaseMaterial3D.STENCIL_MODE_XRAY, "behind a wall the player shows through it")
	# A building's hole open round the player shows them plainly: no tint.
	cam._cut = cam.CUT_RADIUS
	cam._update_xray(1.0, p.global_position)
	_check(not p.xray_shown, "inside the open see-through hole the player has no silhouette")
	wall.queue_free()
	await _frames(2)
	cam._cut = 0.0
	cam._update_xray(1.0, p.global_position)
	_check(not p.xray_shown and p.body_mesh.material_override.stencil_mode == BaseMaterial3D.STENCIL_MODE_DISABLED, "with the wall gone the silhouette is off again")
	# Classic flat view: the rays run along the view, not to the camera.
	# A wall on the line to an eye off to one side does not hide the
	# player; one straight along the view does.
	var space = cam.get_world_3d().direct_space_state
	var back := Vector3(0.0, 0.8, 0.6).normalized()
	var eye: Vector3 = p.global_position + Vector3(120.0, 160.0, 0.0)
	wall = StaticBody3D.new()
	wall.collision_layer = L.WORLD
	shape = CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(4, 4, 4)
	wall.add_child(shape)
	add_child(wall)
	wall.global_position = p.global_position.lerp(eye, 0.05)
	await _frames(2)
	_check(cam.covered(space, eye, p) and not cam.covered(space, eye, p, L.WORLD | L.VEHICLES, back), "flat view: a wall off the line of sight does not count as hiding the player")
	wall.global_position = p.global_position + back * 8.0
	await _frames(2)
	_check(cam.covered(space, eye, p, L.WORLD | L.VEHICLES, back), "flat view: a wall along the line of sight hides the player")
	wall.queue_free()
	await _frames(2)


## A car sunk into a semi's trailer is moved out within a few frames, so
## the semi drives on smoothly instead of jumping back and forth a metre
## each frame (the shaking view in Sachin's 0.21 video).
func test_overlap_resolves() -> void:
	await _free_game()
	for off in [Vector3(0, 0, 5.0), Vector3(1.0, 0, 5.5), Vector3(-1.2, 0, -3.0)]:
		var semi = _player_car("semi", Vector3.ZERO, 0.0)
		var parked = _track_car("sedan", off, 0.0)
		Controls.override_vector = Vector2(0, -1)
		# The first frame's move_and_slide lifts the semi itself out of a
		# shallow overlap (a one-off step); what must not happen is that
		# going on frame after frame.
		await _frames(5)
		var most := 0.0
		var last: Vector3 = semi.global_position
		for f in 75:
			await _frames(1)
			most = maxf(most, semi.global_position.distance_to(last))
			last = semi.global_position
		_check(most < 0.3, "a semi with a sedan sunk in at %s drives on smoothly (largest step %.2f m a frame)" % [off, most])
		Controls.override_vector = null
		semi.queue_free()
		parked.queue_free()
		await _frames(2)


## Driving a semi into a parked sedan pushes the sedan along, and the
## speedometer reads the pace the semi really makes.
func test_heavy_pushes_parked() -> void:
	await _free_game()
	var semi = _player_car("semi", Vector3.ZERO, 0.0)
	var parked = _track_car("sedan", Vector3(0.6, 0, -10.2), 0.3)
	await _frames(2)
	var start: Vector3 = parked.global_position
	Controls.override_vector = Vector2(0, -1)
	await _frames(150)
	Controls.override_vector = null
	_check(semi.global_position.z < -4.0, "the semi drives on into the sedan (went %.1f m)" % -semi.global_position.z)
	_check(parked.global_position.distance_to(start) > 3.0, "pushing it %.1f m" % parked.global_position.distance_to(start))
	_check(absf(semi.speed - semi.motion.length()) < 2.0, "the speedometer reads the semi's real pace (%.1f vs %.1f m/s)" % [semi.speed, semi.motion.length()])
	semi.queue_free()
	parked.queue_free()
	await _frames(2)


## A cab sent to a curb spot with a car parked on it waited behind that
## car for ever (0.22): the stop moves to the nearest clear spot.
func test_cab_stop_skips_parked_car() -> void:
	await _new_game(false)
	var taxi = game.taxi
	_place_player_at(game.city.spawn_point)
	await _frames(2)
	var curb: Dictionary = taxi._curb_near(game.player.global_position)
	_check(not curb.is_empty(), "a street by the player")
	if curb.is_empty():
		return
	var first: Array = taxi._curb_stop(curb.a, curb.b, curb.at)
	var parked = Vehicle.new()
	parked.city = game.city
	parked.position = first[0]
	parked.rotation.y = first[1]
	game.add_child(parked)
	await _frames(1)
	var second: Array = taxi._curb_stop(curb.a, curb.b, curb.at)
	_check(second[0].distance_to(first[0]) > 4.0, "the stop moves off the parked car, %.1f m" % second[0].distance_to(first[0]))
	_check(Vehicle.room_for(get_tree(), second[0], second[1], VehicleKit.size_of("taxi"), 0.2), "and is clear of every car")


# --- 0.23 vehicle classes: suspension, crash damage, fire --------------------

## Every kind has a class, every class row has every field, and the water
## and air classes are reserved for later.
func test_vehicle_classes_cover_every_kind() -> void:
	var Classes = preload("res://scripts/kits/vehicle_classes.gd")
	var missing := []
	for kind in VehicleKit.KINDS:
		if not Classes.OF_KIND.has(kind):
			missing.append(kind)
	_check(missing.is_empty(), "every vehicle kind has a class (missing: %s)" % [missing])
	var fields := ["hz", "zeta", "roll_max", "pitch_max", "crumple", "dent_cap", "damage", "throw", "kick"]
	var short := []
	for c in Classes.CLASSES:
		for f in fields:
			if not Classes.CLASSES[c].has(f):
				short.append("%s.%s" % [c, f])
	_check(short.is_empty(), "every class row has all %d fields (missing: %s)" % [fields.size(), short])
	_check(["boat", "ship", "plane", "heli", "airship"].all(func(c): return Classes.CLASSES.has(c)), "boats, ships, planes, helis and airships have reserved rows")
	_check(Classes.class_of("compact") == "hatchback" and Classes.class_of("semi") == "truck" and Classes.class_of("luxury") == "performance" and Classes.class_of("scooter") == "two_wheeler" and Classes.class_of("van") == "muv",
		"kinds map to Sachin's groups (compact hatchback, semi truck, luxury performance, scooter two-wheeler, van MUV)")


## A blow to the front dips the nose on the springs; it swings back past
## level and settles, and the parked car then stops simulating. A light
## hatchback bounces further than a stiff box truck.
func test_suspension_bounces_and_settles() -> void:
	await _free_game()
	var cars := {}
	for kind in ["compact", "box_truck"]:
		var car = _track_car(kind, Vector3(60.0 if kind == "box_truck" else 0.0, 0, 0), 0.0)
		cars[kind] = car
	await _frames(2)
	var low := {}
	var high := {}
	for kind in cars:
		var car = cars[kind]
		car._jolt(car.global_position + Vector3(0, 0.6, -car._size.z * 0.5), Vector3(0, 0, 6.0)) # shoved back
		low[kind] = 0.0
		high[kind] = 0.0
	var settled_at := -1
	for f in 240:
		await _frames(1)
		for kind in cars:
			low[kind] = minf(low[kind], cars[kind]._tilt.y)
			if low[kind] < -0.01:
				high[kind] = maxf(high[kind], cars[kind]._tilt.y)
		if settled_at < 0 and cars.compact._settled():
			settled_at = f
	_check(low.compact < -0.03, "the hatchback's nose dips on the blow (%.3f rad)" % low.compact)
	_check(high.compact > 0.002, "and swings back past level on its springs (%.3f rad)" % high.compact)
	_check(absf(low.box_truck) < absf(low.compact) * 0.6, "the box truck dips less (%.3f vs %.3f)" % [low.box_truck, low.compact])
	_check(settled_at > 0 and settled_at < 240, "the body settles within 4 s (%.1f s)" % (settled_at / 60.0))
	var at: Vector3 = cars.compact.global_position
	await _frames(10)
	_check(cars.compact._settled() and cars.compact.global_position == at, "settled and parked, it stays put")
	for kind in cars:
		cars[kind].queue_free()


## A car hit side-on near its tail spins and both are dented where they met,
## no deeper than the class allows; a car rear-ended in line hardly turns.
func test_side_hit_spins_and_dents() -> void:
	await _free_game()
	var target = _track_car("sedan", Vector3(0, 0, 0), 0.0)
	var hitter = _track_car("sedan", Vector3(8.0, 0, 1.4), PI / 2.0)
	hitter.speed = 12.0
	hitter.velocity = Vector3(-12.0, 0, 0)
	var line = _track_car("sedan", Vector3(80.0, 0, 0), 0.0)
	var rammer = _track_car("sedan", Vector3(80.0, 0, 9.0), 0.0)
	rammer.speed = 12.0
	rammer.velocity = Vector3(0, 0, -12.0)
	var cached: Mesh = target._model.mesh
	for f in 120:
		await _frames(1)
	_check(absf(target.rotation.y) > 0.3, "the side-hit car spins (%.2f rad)" % target.rotation.y)
	_check(absf(line.rotation.y) < 0.05, "the rear-ended car hardly turns (%.3f rad)" % line.rotation.y)
	_check(target._model.mesh != cached and not target._dent_arrays.is_empty(), "the hit car has its own dented mesh")
	for car in [target, hitter]:
		var verts: PackedVector3Array = car._dent_arrays[0][Mesh.ARRAY_VERTEX] if not car._dent_arrays.is_empty() else PackedVector3Array()
		var deepest := 0.0
		var deepest_at := Vector3.ZERO
		for i in verts.size():
			var d: float = verts[i].distance_to(car._dent_orig[0][i])
			if d > deepest:
				deepest = d
				deepest_at = car._dent_orig[0][i]
		var side := "right rear" if car == target else "front"
		var where_ok: bool = (deepest_at.x > 0.3 and deepest_at.z > 0.3) if car == target else deepest_at.z < -1.0
		_check(deepest > 0.08 and deepest <= car._cls.dent_cap + 0.001 and where_ok, "the %s of the %s car is dented %.2f m (cap %.2f) at %s" % [side, "hit" if car == target else "hitting", deepest, car._cls.dent_cap, deepest_at])
	var other = _track_car("sedan", Vector3(160.0, 0, 0), 0.0)
	await _frames(1)
	_check(other._model.mesh == cached, "an undamaged car of the same paint still shares the cached mesh")
	var t0 := Time.get_ticks_usec()
	target._dent_at = -1.0
	target._crumple(target.global_position + Vector3(-1.0, 0.6, -1.5), Vector3(1, 0, 0), 10.0)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	_check(ms < 40.0, "one dent costs %.1f ms (%d body vertices)" % [ms, target._dent_orig[0].size()])
	for car in [target, hitter, line, rammer, other]:
		car.queue_free()


## A hard crash tears a body panel off; it lands and lies on the road.
func test_hard_crash_throws_panel() -> void:
	await _free_game()
	var wall = _track_car("semi", Vector3(0, 0, -12.0), PI / 2.0)
	var car = _track_car("compact", Vector3(0, 0, 0), 0.0)
	car.speed = 20.0
	car.velocity = Vector3(0, 0, -20.0)
	var CarDebris = preload("res://scripts/car_debris.gd")
	var pieces := []
	for f in 150:
		await _frames(1)
		for n in get_children():
			if n.get_script() == CarDebris and not pieces.has(n):
				pieces.append(n)
	_check(pieces.size() >= 1, "a 72 km/h crash throws %d panel(s) off" % pieces.size())
	# The oldest may be gone: at most CarDebris.MAX lie about, counting
	# earlier tests' panels.
	pieces = pieces.filter(func(n): return is_instance_valid(n))
	if not pieces.is_empty():
		var p = pieces[-1]
		_check(p._resting and absf(p.global_position.y - Terrain.height(p.global_position.x, p.global_position.z)) < 0.1, "the panel comes to rest on the ground")
	for n in pieces:
		n.queue_free()
	car.queue_free()
	wall.queue_free()


## Riding a motorbike into a truck throws the player off; a gentle bump does not.
func test_crash_throws_rider() -> void:
	await _new_game(false)
	var node := _home()
	var truck = Vehicle.new()
	truck.kind = "box_truck"
	truck.city = game.city
	truck.position = game.city.node_pos(node) + Vector3(0, 0, -10.0)
	truck.rotation.y = PI / 2.0
	game.add_child(truck)
	var bike = Vehicle.new()
	bike.kind = "motorbike"
	bike.city = game.city
	bike.position = game.city.node_pos(node) + Vector3(0, 0, 2.0)
	game.add_child(bike)
	await _frames(1)
	var p = game.player
	p.enter_vehicle(bike)
	bike.bump(Vector3(0, 0, 2.0), bike.global_position + Vector3(0, 0.6, 1.0))
	await _frames(2)
	_check(p.vehicle == bike, "a gentle bump leaves the rider on")
	bike.speed = 14.0
	bike.velocity = Vector3(0, 0, -14.0)
	for f in 90:
		await _frames(1)
		if p.vehicle == null:
			break
	_check(p.vehicle == null and p.health < p.max_health, "a 50 km/h crash into a truck throws the rider off, hurt (health %.0f)" % p.health)
	bike.queue_free()
	truck.queue_free()


## Below 15% health a car burns, the fire eats the rest and it explodes:
## people near it are knocked down and hurt, a car beside it is shoved.
func test_car_fire_then_explodes() -> void:
	await _new_game(false)
	var node := _home()
	var car = _spawn_car(node, Vector3(0, 0, 0), 0.0)
	var near = _spawn_car(node, Vector3(4.0, 0, 0), 0.0)
	await _frames(1)
	car._damage(car.max_health * 0.8, true)
	_check(car._fire == null, "a car at 20% does not burn yet")
	car._damage(car.max_health * 0.1, true)
	_check(car._fire != null and not car.wrecked, "below 15% it catches fire")
	_place_player_at(car.global_position + Vector3(-3.0, 0, 0))
	var p = game.player
	var hp: float = p.health
	var near_at: Vector3 = near.global_position
	var burned := 0
	for f in 600:
		await _frames(1)
		if car.wrecked:
			break
		burned += 1
	await _frames(2)
	_check(car.wrecked and car._fire.exploded, "the fire wrecks it and it explodes (%.1f s)" % (burned / 60.0))
	_check(burned > 60 * 2 and burned < 60 * 8, "burning takes a few seconds, under BURN_TIME (%.1f s)" % (burned / 60.0))
	_check(p.health < hp and (p.knocked_time > 0.0 or p.dead), "the player 3 m away is knocked down and hurt (%.0f -> %.0f)" % [hp, p.health])
	_check(near.health < near.max_health and near.global_position.distance_to(near_at) > 0.05, "the car beside it is shoved %.2f m and damaged" % near.global_position.distance_to(near_at))
	car.queue_free()
	near.queue_free()


## Settings > Camera > Screen shake (0.23, Sachin: "screen shake is too
## much, give me a slider"): the strength scales the view's shake offset,
## 0 holds it still, 100% is the shake before 0.23, 50% is the default, and
## it saves, loads and falls back to 50% for saves without it.
func test_screen_shake_setting() -> void:
	await _new_game(false)
	var cam = game.camera
	_check(game.settings.get("shake") == 50 and game.shake_percent() == 50 and is_equal_approx(cam.shake_strength, 0.5), "a new game shakes at 50%% (got %s)" % [game.settings.get("shake")])
	# The offset at one moment of a full shake, at 100%, 50% and 0%.
	var full := []
	for pct in [100, 50, 0]:
		game.settings["shake"] = pct
		game.apply_settings()
		cam._trauma = 1.0
		cam._shake_t = 0.37
		cam._apply_shake(0.0)
		full.append(Vector2(cam.h_offset, cam.v_offset))
	var want := Vector2(sin(0.37 * 1.13) + sin(0.37 * 2.71) * 0.5, sin(0.37 * 1.37 + 1.0) + sin(0.37 * 3.07) * 0.5) * 0.9
	_check(full[0].distance_to(want) < 0.0001 and full[0].length() > 0.5, "at 100%% the offset is the full shake before 0.23 (%s, want %s)" % [full[0], want])
	_check(full[1].distance_to(want * 0.5) < 0.0001, "at 50%% it is half (%s)" % full[1])
	_check(full[2] == Vector2.ZERO, "at Off there is no offset (%s)" % full[2])
	# In play, through shake(): Off never moves the view; 100% does.
	var most := [0.0, 0.0]
	for i in 2:
		game.settings["shake"] = [0, 100][i]
		game.apply_settings()
		cam.shake(1.0)
		for f in 20:
			await _frames(1)
			most[i] = maxf(most[i], Vector2(cam.h_offset, cam.v_offset).length())
		cam._trauma = 0.0
	_check(most[0] == 0.0 and most[1] > 0.3, "a shake at Off moves the view 0 m, at 100%% up to %.2f m" % most[1])
	# Bad saved values fall back to 50%.
	var odd := []
	for v in [45, "loud", null, 100.0, -10, 30.0, 20.5]:
		game.settings["shake"] = v
		odd.append(game.shake_percent())
	_check(odd == [50, 50, 50, 100, 50, 30, 50], "a saved shake not on the list loads as 50%%: %s" % [odd])
	# Save and load, through a throwaway file.
	var mm = game.missions
	mm.save_enabled = true
	mm.save_path = "user://test_save_shake.json"
	game.settings["shake"] = 30
	game.apply_settings()
	mm.save_game()
	# (apply_settings saves too, so the change after the save is not applied.)
	game.settings["shake"] = 80
	cam.shake_strength = 0.8
	mm.load_game()
	game.apply_settings()
	_check(game.settings["shake"] == 30 and is_equal_approx(cam.shake_strength, 0.3), "Screen shake 30%% survives save and load (%s)" % [game.settings["shake"]])
	# A save from before 0.23 has no "shake": a fresh game loading it keeps 50%.
	game.settings["shake"] = 50
	var f := FileAccess.open(mm.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 2, "done": [], "cash": 10, "phone": false, "settings": {"zoom": 1.15, "fps_limit": 60}, "inventory": {}}))
	f.close()
	mm.load_game()
	game.apply_settings()
	_check(game.settings["shake"] == 50 and is_equal_approx(cam.shake_strength, 0.5) and cam.zoom == 1.15, "an old save without it loads at 50% and keeps its other settings")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(mm.save_path))
	mm.save_enabled = false
	game.settings["zoom"] = 1.0
	game.settings["fps_limit"] = 120
	game.apply_settings()


## Every setting with several values is a slider (0.23): one tick per value,
## a drag snaps to the nearest, the name of the value shows above it, and
## the value is applied at once. A tap jumps to a tick; a swipe that starts
## on a slider and turns into a scroll changes nothing.
func test_settings_sliders_snap_and_apply() -> void:
	await _new_game(false)
	var cam = game.camera
	var phone = game.hud.phone
	var page = phone.settings_page
	var s: Dictionary = game.settings
	game.hud.settings_button.pressed.emit()
	await _idle(2)
	# What each setting looks like in the game once applied.
	var state := {
		"zoom": func(): return cam.zoom,
		"drive_zoom": func(): return cam.drive_zoom,
		"angle": func(): return cam.base_pitch,
		"camera_turn": func(): return "north" if not cam.turn_view else "steps" if cam.turn_steps else "car",
		"shake": func(): return roundi(cam.shake_strength * 100.0),
		"quality": func(): return game.graphics.quality,
		"fps_limit": func(): return game.fps_limit(),
		"controls": func(): return Controls.scheme,
		"weather": func(): return "auto" if game.atmosphere.weather_changes else game.atmosphere.weather,
	}
	var want := {"Camera": ["Distance", "Drive zoom-out", "Angle", "Camera turn", "Screen shake"],
		"Graphics": ["Quality", "FPS limit"], "Controls": ["Driving"], "Game": ["Weather"]}
	var keep: Dictionary = s.duplicate(true)
	for t in page.TABS:
		page.show_tab(t)
		await _idle(1)
		var names: Array = page.sliders.keys()
		names.sort()
		var expect: Array = want[t].duplicate()
		expect.sort()
		_check(names == expect, "tab %s has sliders %s (want %s)" % [t, names, expect])
		for n in want[t]:
			# Quality redraws the tab, so the row is looked up afresh.
			var row = page.sliders.get(n)
			if row == null:
				_check(false, "%s is a slider" % n)
				continue
			var bar = row.get_meta("slider")
			var values: Array = row.get_meta("values")
			var key: String = row.get_meta("key")
			var shape: bool = bar is HSlider and bar.min_value == 0 and bar.max_value == values.size() - 1 and bar.step == 1.0 and bar.tick_count == values.size() and bar.ticks_on_borders and bar.mouse_filter == Control.MOUSE_FILTER_PASS and bar.custom_minimum_size.y >= 56 and bar.get_theme_icon("grabber").get_width() >= 40
			var wrong := []
			for i in values.size():
				# A drag lands between ticks; it snaps to the nearest.
				bar.value = i + (0.4 if i < values.size() - 1 else -0.4)
				var got = state[key].call()
				var same: bool = is_equal_approx(float(got), float(values[i])) if values[i] is float or values[i] is int else got == values[i]
				if bar.value != i or s[key] != values[i] or not same or row.get_meta("value").text == "":
					wrong.append("%s->%s/%s/%s" % [values[i], bar.value, s[key], got])
			_check(shape and wrong.is_empty(), "%s: a slider over %d values that snaps and applies each one (wrong: %s)" % [n, values.size(), wrong])
			if t == "Graphics":
				await _idle(1)
		for k in keep:
			s[k] = keep[k]
		game.apply_settings()
	# Named values show their names; Off and percentages show as such.
	page.show_tab("Camera")
	await _idle(1)
	var shake_s = page.sliders["Screen shake"]
	shake_s.get_meta("slider").value = 0
	var off_text: String = shake_s.get_meta("value").text
	cam._trauma = 0.0
	shake_s.get_meta("slider").value = 5
	_check(off_text == "Off" and shake_s.get_meta("value").text == "50%" and cam._trauma > 0.5 and page.sliders["Camera turn"].get_meta("value").text == "North up", "Screen shake shows Off and 50%%, and a change shakes the preview once (trauma %.2f); Camera turn shows North up" % cam._trauma)
	cam._trauma = 0.0
	# A tap on the track jumps to the nearest tick, as a finger would.
	var dist = page.sliders["Distance"]
	var bar: HSlider = dist.get_meta("slider")
	await _idle(2)
	var r: Rect2 = bar.get_global_rect()
	var to_window: Transform2D = get_viewport().get_final_transform()
	var left: Vector2 = to_window * (r.position + Vector2(3.0, r.size.y * 0.5))
	var right: Vector2 = to_window * (r.position + Vector2(r.size.x - 3.0, r.size.y * 0.5))
	await _slider_press(left, true)
	await _slider_press(left, false)
	_check(bar.value == 0 and s["zoom"] == 0.6 and cam.zoom == 0.6 and dist.get_meta("value").text == "60%", "a tap at the left end of Distance picks 60%% (value %s, zoom %s)" % [bar.value, s["zoom"]])
	# The finger goes down at the right end (Distance jumps to 130%), then the
	# drag turns into a scroll: it goes back to 60% and the slider lets go.
	await _slider_press(right, true)
	var jumped: float = cam.zoom
	page._scroll.scroll_started.emit()
	var mm := InputEventMouseMotion.new()
	mm.position = (left + right) * 0.5
	mm.global_position = mm.position
	mm.button_mask = MOUSE_BUTTON_MASK_LEFT
	mm.relative = mm.position - right
	get_viewport().push_input(mm)
	await _idle(1)
	await _slider_press((left + right) * 0.5, false)
	_check(jumped == 1.3 and bar.value == 0 and s["zoom"] == 0.6 and cam.zoom == 0.6 and dist.get_meta("value").text == "60%" and page._held == null, "a swipe that starts on a slider and scrolls puts the setting back (jumped to %s, now %s)" % [jumped, s["zoom"]])
	await _slider_press(right, true)
	await _slider_press(right, false)
	_check(bar.value == 6 and cam.zoom == 1.3, "and the slider still works after (%s)" % bar.value)
	phone.close()
	s["zoom"] = 1.0
	game.apply_settings()


## Presses (or releases) the left button at window pixel `at`.
func _slider_press(at: Vector2, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.position = at
	ev.global_position = at
	ev.pressed = down
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	get_viewport().push_input(ev)
	await _idle(1)


## Moves a settings slider `by` ticks, as a drag would; it stops at the ends.
func _slide(row, by: int) -> void:
	var bar: HSlider = row.get_meta("slider")
	bar.value = bar.value + by


# --- Blood (0.23) --------------------------------------------------------------

## A punch that lands sprays a little blood the way it was thrown and
## spatters the ground just past the victim; a kick more; a blow too soft to
## hurt none; and a killing blow leaves a pool spreading under the body.
func test_blood_melee_spurts_and_spatters() -> void:
	var Terrain = preload("res://scripts/terrain.gd")
	await _free_game()
	var bw = Fx.bloodwork
	Fx.set_blood(true)
	bw.clear()
	var o := Vector3(0, 0, 2300)
	var city = _fake_street(o)
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	Controls.camera = null
	var fighter = _street_ped(city, rng, o, 0.0)
	var victim = _street_ped(city, rng, o + Vector3(0, 0, -1.0), PI)
	await _frames(2)
	var spurts: int = bw.spurts
	fighter.punch()
	var punch_marks: int = bw.used()
	_check(victim.health < victim.max_health and bw.spurts == spurts + 1 and punch_marks >= 2,
		"a punch that lands sprays blood (%d spurt, %d marks)" % [bw.spurts - spurts, punch_marks])
	var near := true
	var ahead := 0.0
	var small := true
	var ground := true
	for i in punch_marks:
		var t: Transform3D = bw.mark_transform(i)
		var off: Vector3 = t.origin - victim.global_position
		near = near and Vector2(off.x, off.z).length() < 2.0
		ahead += -off.z / punch_marks
		small = small and t.basis.x.length() <= 0.9 and t.basis.z.length() <= 1.3
		ground = ground and absf(t.origin.y - (Terrain.height(t.origin.x, t.origin.z) + bw.LIFT)) < 0.01 and bw.kind(i) == bw.DROP
	_check(near and ahead > 0.15 and small and ground,
		"its spatter lies on the ground just past them, the way the blow went (%.2f m on), every mark under a metre" % ahead)
	await _frames(30)
	var shown := 0
	for i in punch_marks:
		shown += 1 if bw.alpha(i) > 0.99 else 0
	_check(shown == punch_marks, "the drops land within half a second, fully dark (%d of %d)" % [shown, punch_marks])
	# A kick (double damage) throws more.
	var before: int = bw.used()
	victim.take_hit(fighter, fighter.punch_damage * 2.0, fighter.forward() * 2.2)
	_check(bw.used() - before > punch_marks, "a kick leaves more than a punch (%d marks to %d)" % [bw.used() - before, punch_marks])
	# A shove that does no harm (a mission's nudge) draws none.
	before = bw.used()
	spurts = bw.spurts
	victim.take_hit(null, 0.0, Vector3.RIGHT * 0.5)
	_check(bw.used() == before and bw.spurts == spurts, "a blow that does no harm draws no blood")
	# A killing blow: once the body lies still a pool spreads under it.
	victim.take_hit(fighter, 999.0, fighter.forward())
	var pool := -1
	for f in 120:
		await _frames(1)
		for i in bw.used():
			if bw.kind(i) == bw.POOL:
				pool = i
		if pool >= 0:
			break
	_check(victim.dead and pool >= 0, "a kill leaves a pool")
	if pool >= 0:
		var t: Transform3D = bw.mark_transform(pool)
		var off: Vector3 = t.origin - victim.global_position
		_check(Vector2(off.x, off.z).length() < 1.2 and t.basis.x.length() > 1.3 and t.basis.x.length() < 2.2 and bw.alpha(pool) > 0.99,
			"under the body (%.2f m from its feet), about one and a half metres across (%.2f m)" % [Vector2(off.x, off.z).length(), t.basis.x.length()])
		_check(bw._data[pool].b >= 4.0, "and it spreads over a few seconds (%.0f s)" % bw._data[pool].b)
	fighter.queue_free()
	victim.queue_free()
	await _frames(1)


## A car hit hard enough to hurt sprays blood the way the body flies, smears
## the road behind it while it slides and pools where it stops (a bigger pool
## for the dead); a nudge at walking pace knocks someone over without a mark;
## a dead body taken away before it settled still leaves its pool.
func test_blood_car_hits_smear_and_pool() -> void:
	await _free_game()
	var bw = Fx.bloodwork
	Fx.set_blood(true)
	bw.clear()
	var o := Vector3(0, 0, 2600)
	var city = _fake_street(o)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	Controls.camera = null
	var nudged = _street_ped(city, rng, o + Vector3(-12, 0, 0), 0.0)
	var hurt = _street_ped(city, rng, o, 0.0)
	var killed = _street_ped(city, rng, o + Vector3(12, 0, 0), 0.0)
	await _frames(2)
	# 3 m/s (11 km/h).
	var spurts: int = bw.spurts
	var car = _track_car("sedan", nudged.global_position + Vector3(0, 0, 3), 0.0)
	car.velocity = Vector3(0, 0, -3)
	nudged.hit_by_vehicle(car, 3.0)
	car.queue_free()
	_check(nudged.knocked_time > 0.0 and bw.spurts == spurts and bw.used() == 0, "a nudge at 11 km/h knocks someone over and draws no blood")
	# 9 m/s (32 km/h): hurt, not killed (people have 40 health).
	car = _track_car("sedan", hurt.global_position + Vector3(0, 0, 3), 0.0)
	car.velocity = Vector3(0, 0, -9)
	var start: Vector3 = hurt.global_position
	hurt.hit_by_vehicle(car, 9.0)
	car.queue_free()
	_check(not hurt.dead and hurt.knocked_time > 0.0 and bw.spurts == spurts + 1 and bw.used() >= 2,
		"hit at 32 km/h they are down and blood sprays (%d marks)" % bw.used())
	await _frames(100)
	var smears := 0
	var along := true
	var on_path := true
	var pools := []
	for i in bw.used():
		var t: Transform3D = bw.mark_transform(i)
		if bw.kind(i) == bw.SMEAR:
			smears += 1
			along = along and absf(t.basis.z.normalized().z) > 0.95
			on_path = on_path and absf(t.origin.x - start.x) < 0.3 and t.origin.z < start.z + 0.3 and t.origin.z > hurt.global_position.z - 0.6
		elif bw.kind(i) == bw.POOL:
			pools.append(i)
	_check(smears >= 3 and along and on_path, "the body smears the road along its slide (%d smears over %.1f m)" % [smears, start.z - hurt.global_position.z])
	_check(pools.size() == 1 and absf(bw.mark_transform(pools[0]).origin.z - hurt.global_position.z) < 1.2,
		"and a small pool where it stopped, hurt but alive (%d)" % pools.size())
	var hurt_pool: float = bw.mark_transform(pools[0]).basis.x.length() if pools.size() == 1 else 9.0
	# 30 m/s (108 km/h): killed.
	car = _track_car("sedan", killed.global_position + Vector3(0, 0, 3), 0.0)
	car.velocity = Vector3(0, 0, -30)
	var used: int = bw.used()
	killed.hit_by_vehicle(car, 30.0)
	car.queue_free()
	await _frames(240)
	var kill_pool := -1
	for i in range(used, bw.used()):
		if bw.kind(i) == bw.POOL:
			kill_pool = i
	_check(killed.dead and kill_pool >= 0 and bw.mark_transform(kill_pool).basis.x.length() > hurt_pool,
		"a kill leaves a bigger pool (%.2f m to %.2f m)" % [bw.mark_transform(kill_pool).basis.x.length() if kill_pool >= 0 else 0.0, hurt_pool])
	# The hurt get up and walk off; their pool stays and fades.
	await _frames(90)
	_check(hurt.knocked_time <= 0.0 and not hurt.dead and hurt._pool_size == 0.0, "the hurt get up and no second pool comes")
	# A body cleared away (population recycling) before it settled.
	var gone = _street_ped(city, rng, o + Vector3(24, 0, 0), 0.0)
	await _frames(2)
	gone.take_hit(null, 999.0, Vector3.ZERO)
	used = bw.used()
	gone.queue_free()
	await _frames(1)
	_check(bw.used() == used + 1 and bw.kind(used) == bw.POOL, "a dead body taken away before it settled leaves its pool")
	bw.clock += bw.POOL_LIFE.y + 1.0
	await _frames(2)
	_check(bw.used() == 0 and bw.mm.visible_instance_count == 0, "which fades in time like the rest")
	for p in [nudged, hurt, killed]:
		p.queue_free()
	await _frames(1)


## Guns (when they come) call bleed(); a gun's hit then adds no second
## spurt. The ring buffer never grows past its cap, marks fade out and stop
## drawing, and Settings > Game > Blood OFF shows none and clears the rest.
func test_blood_bleed_toggle_cap_and_fade() -> void:
	await _free_game()
	var bw = Fx.bloodwork
	Fx.set_blood(true)
	bw.clear()
	var o := Vector3(0, 0, 2900)
	var city = _fake_street(o)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	Controls.camera = null
	var ped = _street_ped(city, rng, o, 0.0)
	await _frames(2)
	var spurts: int = bw.spurts
	var wound: Vector3 = ped.global_position + Vector3(0, 1.3, 0)
	ped.bleed(wound, Vector3.RIGHT, 0.3)
	var east := true
	for i in bw.used() - 1:
		east = east and bw.mark_transform(i).origin.x > ped.global_position.x
	_check(bw.spurts == spurts + 1 and bw.used() >= 2 and east and ped.health == ped.max_health,
		"bleed() sprays a spurt and drops the way the round went, and does no harm itself (%d marks)" % bw.used())
	var used: int = bw.used()
	ped.bleed(wound, Vector3.RIGHT, 0.0)
	ped.take_hit(null, 30.0, Vector3.RIGHT, false)
	_check(bw.spurts == spurts + 1 and bw.used() == used and ped.health == ped.max_health - 30.0, "a gun's hit after it (bloody false) adds no second spurt")
	# Many wounds: the buffer stays at its cap.
	for i in 120:
		ped.bleed(wound, Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)), 2.0)
	_check(bw.laid >= 600 and bw.used() == bw.CAP and bw.mm.instance_count == bw.CAP and bw.mm.visible_instance_count == bw.CAP,
		"after %d marks the ground holds the newest %d, one MultiMesh" % [bw.laid, bw.CAP])
	# Fading: full while fresh, fading late in life, then gone and not drawn.
	await _frames(40)
	var full := 0
	for i in bw.CAP:
		full += 1 if bw.alpha(i) > 0.99 else 0
	bw.clock += 50.0
	await _frames(1)
	var mid := 0.0
	for i in bw.CAP:
		mid += bw.alpha(i) / bw.CAP
	bw.clock += 25.0
	await _frames(1)
	var late := 0.0
	for i in bw.CAP:
		late += bw.alpha(i) / bw.CAP
	_check(full == bw.CAP and mid < 0.97 and mid > late and late > 0.0, "marks stay dark, then fade (%.2f at 50 s, %.2f at 75 s)" % [mid, late])
	_check(bw.clock - bw._epoch < bw.REBASE + 1.0, "the shader's clock starts again every minute (%.0f s on)" % (bw.clock - bw._epoch))
	bw.clock += 20.0
	await _frames(2)
	_check(bw.live() == 0 and bw.used() == 0 and bw.mm.visible_instance_count == 0, "after 95 s they are gone and nothing is drawn")
	# OFF.
	ped.bleed(wound, Vector3.RIGHT, 1.0)
	Fx.set_blood(false)
	_check(bw.used() == 0 and not bw.visible, "turning blood off clears what is there")
	var laid: int = bw.laid
	spurts = bw.spurts
	ped.bleed(wound, Vector3.RIGHT, 1.0)
	ped.take_hit(null, 20.0, Vector3.RIGHT)
	ped.take_hit(null, 999.0, Vector3.RIGHT)
	await _frames(240)
	_check(ped.dead and bw.laid == laid and bw.spurts == spurts, "and with it off, blows, wounds and deaths draw none")
	ped.queue_free()
	Fx.set_blood(true)
	# The setting: on by default, and the Game tab's Blood button.
	await _new_game(false)
	_check(game.settings.get("blood") == true and bw.on, "Blood is on by default")
	var page = game.hud.phone.settings_page
	game.hud.settings_button.pressed.emit()
	await _idle(2)
	page.show_tab("Game")
	await _idle(1)
	game.player.bleed(game.player.global_position + Vector3(0, 1.2, 0), Vector3.RIGHT, 1.0)
	var button: Button = _find_button(page._list, "Blood: ")
	var had: int = bw.used()
	button.pressed.emit()
	await _idle(1)
	_check(had > 0 and button.text == "Blood: OFF" and game.settings["blood"] == false and not bw.on and bw.used() == 0,
		"Settings > Game > Blood OFF turns it off and clears the ground (%d marks before)" % had)
	button.pressed.emit()
	await _idle(1)
	_check(button.text == "Blood: ON" and game.settings["blood"] == true and bw.on, "and ON brings it back")
	page._back.pressed.emit()
	await _idle(2)
	Fx.set_blood(true)


# --- Exhaust, tyre smoke and tyre marks (0.23) ----------------------------------

## What comes out of the tailpipe follows US norms by kind (vehicle_emissions.gd):
## EVs and bicycles nothing, a healthy modern petrol car nothing once warm
## on a dry day, vapour from a cold start, black smoke from an old diesel
## pulling away and on each upshift, pops from a sports car lifting off, and
## old diesels and smokers likelier where money is short.
func test_exhaust_by_kind_and_norms() -> void:
	await _free_game()
	Controls.camera = null
	Controls.scheme = "arrows"
	var E = preload("res://scripts/kits/vehicle_emissions.gd")
	var r := RandomNumberGenerator.new()
	r.seed = 7
	_check(E.roll("ev", r, 1.0).fuel == "electric" and E.roll("bicycle", r, 1.0).fuel == "none" and E.roll("semi", r, 0.0).fuel == "diesel",
			"EVs and bicycles burn nothing, semis burn diesel")
	var old_rich := 0
	var old_poor := 0
	var smoky_rich := 0
	var smoky_poor := 0
	for i in 3000:
		old_rich += int(E.roll("pickup", r, 0.0).old)
		old_poor += int(E.roll("pickup", r, 1.0).old)
		smoky_rich += int(E.roll("tuk_tuk", r, 0.0).smoker)
		smoky_poor += int(E.roll("tuk_tuk", r, 1.0).smoker)
	_check(old_poor > old_rich * 2 and smoky_poor > smoky_rich * 2,
			"old diesels and smokers gather where money is short (diesels %d vs %d, smokers %d vs %d of 3000)" % [old_poor, old_rich, smoky_poor, smoky_rich])
	_check(old_rich < 150, "few pre-filter diesels elsewhere (%d of 3000 pickups)" % old_rich)
	var stacks: Array = E.outlets("semi", VehicleKit.size_of("semi"))
	_check(stacks.size() == 2 and stacks[0][0].y > 3.5 and stacks[0][1] == Vector3.UP, "a semi's twin stacks stand tall behind the cab and blow upward")
	var pipe: Array = E.outlets("sedan", VehicleKit.size_of("sedan"))
	_check(pipe.size() == 1 and pipe[0][0].z > VehicleKit.size_of("sedan").z * 0.45, "a sedan's tailpipe is at its rear")

	# A cold start steams; warm on a dry day, a modern petrol car shows nothing.
	Fx.puffs.clear()
	var car = _player_car("sedan", Vector3(150.0, 0, 150.0), 0.0)
	await _frames(40)
	var steam := 0
	for c in Fx.puffs.colors():
		steam += int(c.r > 0.93)
	_check(steam > 2 and car._cold > 0.0, "a cold start puffs white vapour (%d puffs)" % steam)
	car._emit.smoker = false
	car._cold = 0.0
	Fx.puffs.clear()
	Input.action_press("gas")
	await _frames(90)
	Input.action_release("gas")
	_check(Fx.puffs.count() == 0 and car.speed > 8.0, "a warm modern petrol car pulling away shows nothing (%d puffs)" % Fx.puffs.count())
	car.queue_free()

	# An EV shows nothing even from cold.
	Fx.puffs.clear()
	car = _player_car("ev", Vector3(150.0, 0, 150.0), 0.0)
	Input.action_press("gas")
	await _frames(60)
	Input.action_release("gas")
	_check(Fx.puffs.count() == 0, "an EV shows nothing (%d puffs)" % Fx.puffs.count())
	car.queue_free()

	# An old diesel semi pulling away: soot, a burst on each upshift.
	car = _player_car("semi", Vector3(150.0, 0, 150.0), 0.0)
	await _frames(2)
	car._emit.old = true
	Fx.puffs.clear()
	Input.action_press("gas")
	var shifts := 0
	var gear: int = car._gear
	for f in 150:
		await get_tree().physics_frame
		if car._gear > gear:
			shifts += 1
		gear = car._gear
	Input.action_release("gas")
	var soot := 0
	for c in Fx.puffs.colors():
		soot += int(c.r < 0.2)
	_check(soot > 10 and shifts >= 1, "an old diesel pulling away smokes black (%d puffs, %d upshifts)" % [soot, shifts])
	car.queue_free()

	# A sports car lifting off at speed pops.
	Fx.puffs.clear()
	car = _player_car("sports", Vector3(150.0, 0, 150.0), 22.0)
	Input.action_press("gas")
	await _frames(20)
	Input.action_release("gas")
	await _frames(12)
	var flames := 0
	for c in Fx.puffs.colors():
		flames += int(c.r > 0.99 and c.g < 0.6)
	_check(flames > 0, "a sports car pops on the overrun (%d flashes)" % flames)
	car.queue_free()
	Controls.scheme = "stick"


## Tyre marks: a drift lays dark marks and tyre smoke; an ABS stop only faint
## broken marks and no smoke; a motorbike (no ABS) locks up and marks dark;
## traffic's ordinary stops leave nothing; a wet road takes neither.
func test_tyre_marks_and_smoke() -> void:
	await _free_game()
	Controls.camera = null
	Controls.scheme = "arrows"
	Fx.puffs.clear()
	var before: int = Fx._skid_total
	var car = _player_car("sedan", Vector3(150.0, 0, 150.0), 20.0)
	await _drift(car)
	var marks := _marks_since(before)
	_check(marks.x > 8 and marks.y > 0.3, "a drift lays dark marks (%d strips, alpha %.2f)" % [marks.x, marks.y])
	_check(_tyre_puffs() > 4, "and tyre smoke (%d puffs)" % _tyre_puffs())
	car.queue_free()
	await _frames(2)

	Fx.puffs.clear()
	before = Fx._skid_total
	car = _player_car("sedan", Vector3(150.0, 0, 150.0), 20.0)
	Input.action_press("brake")
	await _frames(60)
	Input.action_release("brake")
	marks = _marks_since(before)
	_check(marks.x > 2 and marks.y <= 0.15, "an ABS stop leaves faint marks (%d strips, alpha %.2f)" % [marks.x, marks.y])
	_check(_tyre_puffs() == 0, "and no smoke (%d puffs)" % _tyre_puffs())
	car.queue_free()
	await _frames(2)

	before = Fx._skid_total
	car = _player_car("motorbike", Vector3(150.0, 0, 150.0), 20.0)
	Input.action_press("brake")
	await _frames(60)
	Input.action_release("brake")
	marks = _marks_since(before)
	_check(marks.x > 2 and marks.y > 0.25, "a motorbike without ABS locks up and marks dark (%d strips, alpha %.2f)" % [marks.x, marks.y])
	car.queue_free()
	await _frames(2)

	before = Fx._skid_total
	car = _track_car("sedan", Vector3(150.0, 0, 150.0), 0.0)
	car.driver = Vehicle.Driver.TRAFFIC
	car.speed = 13.0
	car.velocity = -car.global_basis.z * 13.0
	car.braking = true
	await _frames(60)
	_check(Fx._skid_total == before, "traffic stopping as usual leaves no marks")
	car.queue_free()
	await _frames(2)

	var atm = preload("res://scripts/atmosphere.gd").new()
	atm.hour = 12.0
	atm.wetness = 1.0
	Fx.puffs.clear()
	before = Fx._skid_total
	car = _player_car("sedan", Vector3(150.0, 0, 150.0), 20.0)
	car._game = {"atmosphere": atm}
	await _drift(car)
	_check(Fx._skid_total == before and _tyre_puffs() == 0, "a wet road takes no marks and no tyre smoke (%d strips)" % (Fx._skid_total - before))
	car.queue_free()
	await _frames(2)
	atm.free()
	Controls.scheme = "stick"


## Brake and steer at speed (test_brake_and_steer_drifts), then hold the slide.
func _drift(car) -> void:
	Input.action_press("gas")
	Input.action_press("steer_left")
	await _frames(12)
	Input.action_release("gas")
	Input.action_press("brake")
	await _frames(12)
	Input.action_release("brake")
	await _frames(40)
	Input.action_release("steer_left")


## Tyre-mark strips laid since the count was `before`: (how many, darkest alpha).
func _marks_since(before: int) -> Vector2:
	var n := mini(Fx._skid_total - before, Fx.SKID_COUNT)
	var most := 0.0
	for k in n:
		var i := posmod(Fx._skid_next - 1 - k, Fx.SKID_COUNT)
		most = maxf(most, Fx._skid_alpha[i])
	return Vector2(n, most)


## Tyre-smoke puffs alive now (Emissions.TYRE's grey, not vapour's white).
func _tyre_puffs() -> int:
	var n := 0
	for c in Fx.puffs.colors():
		n += int(c.r > 0.85 and c.r < 0.93)
	return n
