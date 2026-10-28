extends Node
## Renders a few gameplay screenshots for review. Needs a real renderer:
##   xvfb-run godot --rendering-driver opengl3 res://tests/screenshots.tscn -- <out_dir>

const MainScene = preload("res://main.tscn")
const Terrain = preload("res://scripts/terrain.gd")
const Vehicle = preload("res://scripts/vehicle.gd")

var out_dir := "user://"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0]
	_run.call_deferred()


## Sidewalk spots in front of landmarks, for the district tour shots.
const TOUR := [
	["4_lantern_square", "lantern_square", Vector3(0, 0, 0)],
	["5_blue_lantern", "blue_lantern", Vector3(0, 0, 0)],
	["6_aurum_tower", "aurum_tower", Vector3(0, 0, 0)],
	["7_floodline_wards", "moreau_house", Vector3(0, 0, 0)],
	["8_ironwharf", "wharfside_courts", Vector3(30, 0, 7.0)],
	["9_drowned_streetcar", "drowned_streetcar", Vector3(0, 0, 0)],
	["10_streetcar_depot", "streetcar_depot", Vector3(0, 0, 0)],
	["11_lantern_line", "union_station", Vector3(-26, 0, 11.0)],
	# Bellerive v3: the civic centre, Midtown and the waterfront.
	["25_city_hall", "city_hall", Vector3(0, 0, 0)],
	["26_courthouse", "county_courthouse", Vector3(0, 0, 0)],
	["27_library", "public_library", Vector3(0, 0, 0)],
	["28_liberty_square", "liberty_square", Vector3(0, 0, 0)],
	["29_post_office", "main_post_office", Vector3(0, 0, 0)],
	["30_ferry_building", "ferry_building", Vector3(0, 0, 0)],
	["31_fire_hq", "fire_headquarters", Vector3(0, 0, 0)],
]


## [file, landmark, offset, hour, weather] shots of the Lantern Quarter at
## night and in the rain.
const MOODS := [
	["13_quarter_night", "blue_lantern", Vector3(0, 0, 3.0), 21.5, "clear"],
	["14_square_night", "lantern_square", Vector3(0, 0, 2.0), 22.0, "clear"],
	["15_quarter_rain_night", "blue_lantern", Vector3(18, 0, 5.0), 21.0, "storm"],
	["16_quarter_rain_day", "lantern_square", Vector3(-20, 0, 5.0), 13.0, "rain"],
	["17_quarter_dusk", "lantern_square", Vector3(20, 0, 3.0), 19.2, "clear"],
]


func _run() -> void:
	var game = MainScene.instantiate()
	game.missions_enabled = false
	add_child(game)
	game.atmosphere.hour = 12.5
	game.atmosphere.minutes_per_second = 0.0
	game.atmosphere.weather_changes = false
	await _frames(180)
	if OS.get_environment("SHOTS") == "hills":
		# Just the roundabouts and the hills (quick look while working on them).
		await _hills(game)
		get_tree().quit()
		return
	if OS.get_environment("SHOTS") == "props":
		await _props(game)
		get_tree().quit()
		return
	if OS.get_environment("SHOTS") == "farm":
		# Just Golden Flats' farmland (quick look while working on it).
		await _farm(game)
		get_tree().quit()
		return
	if OS.get_environment("SHOTS") == "roads":
		# Just the wide roads (quick look while working on them).
		await _roads(game)
		get_tree().quit()
		return
	await _shot("1_on_foot.png")
	game.waypoint = game.city.node_pos(game.city.nearest_node(game.city.landmark_front("lantern_square")))
	await _frames(30)
	game.hud.full_map.open()
	for i in 4:
		await get_tree().process_frame
	await _shot("12_full_map.png")
	var fm = game.hud.full_map
	fm.zoom = minf(fm.size.x / fm.map.size.x, (fm.size.y - 56.0) / fm.map.size.y)
	fm.pan = fm.map.size * 0.5 - Vector2(0, 28.0) / fm.zoom
	fm.queue_redraw()
	for i in 3:
		await get_tree().process_frame
	await _shot("12b_full_map_all.png")
	game.hud.full_map.close()
	var home: Vector3 = game.player.global_position
	for stop in TOUR:
		var pos: Vector3 = game.city.landmark_frame(stop[1]) * stop[2]
		game.city.stream_now(pos)
		game.player.global_position = pos
		game.player.reset_physics_interpolation()
		game.camera.snap()
		await _frames(90)
		await _shot(stop[0] + ".png")
	var green: Vector3 = game.city.block_center(game.city.plan.park_face) + Vector3(0, 0, 14.0)
	var roads := [
		["19_liberty_green", green],
		["20_morrow_bridge", _road_spot(game, "bridge", Vector2(330, 1100))],
		["21_liberty_avenue", _road_spot(game, "liberty", Vector2(740, 530))],
		["22_river_road", _road_spot(game, "river_road", Vector2(480, 1010))],
		["23_morrow_point", _road_spot(game, "point_ave", Vector2(330, 1300))],
		["24_wharf_street", _road_spot(game, "wharf", Vector2(1000, 860))],
		["32_founders_circle", _road_spot(game, "founders", game.city.plan.circle_at + Vector2(0, 46))],
		["33_esplanade", _road_spot(game, "esplanade", game.city.plan.circle_at + Vector2(-120, 32))],
		["34_moreau_square", _road_spot(game, "moreau", game.city.plan.MOREAU_AT + Vector2(0, 50))],
		["35_morrow_point_rows", _road_spot(game, "", Vector2(600, 1350))],
		["36_midtown", _road_spot(game, "", Vector2(500, 200))],
	]
	for stop in roads:
		var pos: Vector3 = stop[1]
		game.city.stream_now(pos)
		game.player.global_position = pos
		game.player.reset_physics_interpolation()
		game.camera.snap()
		await _frames(90)
		await _shot(stop[0] + ".png")
	# Bellerive CA: the skyline kit's towers and monuments and the shady
	# kit's strips, bungalows and yards, from above and from the street.
	var esplanade := Vector2.ZERO
	for sp in game.city.plan.set_pieces:
		if sp.id == "esplanade":
			esplanade = sp.at
	var aerials := [
		["37_gilt_skyline", Vector3(150, 0, 230), 170.0],
		["38_midtown_skyline", Vector3(500, 0, 180), 170.0],
		["39_wards_from_above", Vector3(1080, 0, 620), 130.0],
		["40_ironwharf_from_above", Vector3(1000, 0, 930), 130.0],
		["41_esplanade_arch", Vector3(esplanade.x - 50.0, 0, esplanade.y), 110.0],
		["44_ironwharf_quay", Vector3(1060, 0, 1060), 90.0],
	]
	for stop in aerials:
		var pos: Vector3 = stop[1]
		game.city.stream_now(pos)
		game.player.global_position = pos
		game.player.reset_physics_interpolation()
		game.camera.fixed_focus = pos
		game.camera.room_size = stop[2]
		game.camera.snap()
		await _frames(90)
		await _shot(stop[0] + ".png")
	await _hills(game)
	for stop in [["42_gilt_street", _road_spot(game, "", Vector2(150, 260))], ["43_wards_strip", _road_spot(game, "cypress", Vector2(1010, 650))]]:
		var pos: Vector3 = stop[1]
		game.city.stream_now(pos)
		game.player.global_position = pos
		game.player.reset_physics_interpolation()
		game.camera.snap()
		await _frames(90)
		await _shot(stop[0] + ".png")
	for mood in MOODS:
		var pos: Vector3 = game.city.landmark_frame(mood[1]) * mood[2]
		game.atmosphere.hour = mood[3]
		game.atmosphere.set_weather(mood[4], true)
		game.city.stream_now(pos)
		game.player.global_position = pos
		game.player.reset_physics_interpolation()
		game.camera.snap()
		await _frames(90)
		await _shot(mood[0] + ".png")
	game.atmosphere.hour = 12.5
	game.atmosphere.set_weather("clear", true)
	game.city.stream_now(home)
	game.player.global_position = home
	game.player.reset_physics_interpolation()
	game.camera.snap()
	await _frames(60)

	var p = game.player
	await _walk_to_car(game)
	Controls.override_vector = Controls.screen_from_world(Vector3.RIGHT)
	await _frames(100)
	await _shot("2_driving.png")
	game.atmosphere.hour = 22.0
	game.atmosphere.set_weather("rain", true)
	Input.action_press("sprint")
	Controls.override_vector = Controls.screen_from_world(Vector3(1, 0, 0.8).normalized())
	await _frames(40)
	Input.action_release("sprint")
	Controls.override_vector = Controls.screen_from_world(Vector3.RIGHT)
	await _frames(20)
	await _shot("18_night_drive.png")
	game.atmosphere.hour = 12.5
	game.atmosphere.set_weather("clear", true)

	Wanted.report_crime(2)
	await _frames(150)
	Controls.override_vector = null
	await _frames(60)
	await _shot("3_police_chase.png")
	print("player at ", p.global_position, " wanted ", Wanted.level)
	get_tree().quit()


## The traffic circles and the Bellerive Hills from above: the camera's
## focus sits on the ground, which is up the hill out there.
func _hills(game) -> void:
	var stops := [
		["45_liberty_circle", Vector2(690, 500), 100.0],
		["46_cypress_circle", Vector2(1010, 500), 90.0],
		["48_lumen_observatory", Vector2(1050, -905), 110.0],
		["49_hillside_letters", Vector2(1330, -1085), 190.0],
		["50_calder_masts", Vector2(1118, -1240), 120.0],
		["51_canyon_freeway", Vector2(760, -1150), 170.0],
		["52_crest_drive", Vector2(1560, -1255), 110.0],
	]
	for stop in stops:
		var at: Vector2 = stop[1]
		var pos := Vector3(at.x, Terrain.height(at.x, at.y), at.y)
		game.city.stream_now(pos)
		game.player.global_position = pos
		game.player.reset_physics_interpolation()
		game.camera.fixed_focus = pos
		game.camera.room_size = stop[2]
		game.camera.snap()
		await _frames(90)
		await _shot(stop[0] + ".png")
	game.camera.fixed_focus = null
	game.camera.room_size = 0.0
	# The hills on the full map, round the player standing on Crest Drive.
	game.hud.full_map.open()
	for i in 4:
		await get_tree().process_frame
	await _shot("47_bellerive_hills_map.png")
	game.hud.full_map.close()


## Golden Flats: a pivot circle wide and its pivot tower close, strip
## fields, the expressway, a farmstead, a pump house at a canal, the
## farmland meeting the hills, and the flats on the full map.
func _farm(game) -> void:
	var c = game.city.country
	var stops := []
	var pivots: Array = c.pivots.duplicate()
	pivots.sort_custom(func(a, b): return a[2] > b[2])
	var big: Array = pivots[0]
	stops.append(["65_pivot_circle", Vector2(big[0], big[1]), 200.0])
	# The span nearest the circle's middle: the pivot tower and the arm.
	var span := Vector2(big[0], big[1])
	var near := INF
	for q: Array in c.plots:
		if c.plot_types[int(q[5])] == "pivot" and Vector2(q[0], q[1]).distance_to(Vector2(big[0], big[1])) < near:
			near = Vector2(q[0], q[1]).distance_to(Vector2(big[0], big[1]))
			span = Vector2(q[0], q[1])
	stops.append(["66_pivot_tower", span, 40.0])
	for road in c.roads:
		if road.name == "Golden Flats Expressway" and road.nodes.size() > 6:
			stops.append(["67_flats_expressway", c.pos(road.nodes[road.nodes.size() / 2]), 160.0])
			break
	for l: Array in c.lots:
		if c.kinds[int(l[5])] == "pump_house":
			stops.append(["68_pump_house_canal", Vector2(l[0], l[1]), 90.0])
			break
	for q: Array in c.plots:
		if c.plot_types[int(q[5])] == "farmyard" and float(q[0]) < -700.0 and float(q[1]) < -600.0:
			stops.append(["69_flats_farmstead", Vector2(q[0], q[1]), 140.0])
			break
	# Each kind of farm home, close up: the first of each on the flats.
	var homes := {}
	for l: Array in c.lots:
		var kind: String = c.kinds[int(l[5])]
		if kind in ["farmhouse", "farmhouse_big", "farmhouse_small", "ranch_house", "adobe_farmhouse"] and str(l[7]) == "golden_flats" and not homes.has(kind):
			homes[kind] = true
			stops.append(["69%s_%s" % ["abcde"[homes.size() - 1], kind], Vector2(l[0], l[1]), 45.0])
	stops.append(["70_strip_fields", Vector2(pivots[pivots.size() - 1][0], pivots[pivots.size() - 1][1]), 200.0])
	stops.append(["71_flats_meet_hills", Vector2(60, -1500), 200.0])
	for stop in stops:
		var at: Vector2 = stop[1]
		var pos := Vector3(at.x, Terrain.height(at.x, at.y), at.y)
		game.city.stream_now(pos)
		game.player.global_position = pos
		game.player.reset_physics_interpolation()
		game.camera.fixed_focus = pos
		game.camera.room_size = stop[2]
		game.camera.snap()
		await _frames(90)
		await _shot(stop[0] + ".png")
	game.camera.fixed_focus = null
	game.camera.room_size = 0.0
	var at := Vector2(big[0], big[1])
	game.player.global_position = Vector3(at.x, 0, at.y)
	game.hud.full_map.open()
	for i in 4:
		await get_tree().process_frame
	await _shot("72_golden_flats_map.png")
	game.hud.full_map.close()


## A car through a street light, a tree and a hydrant: before, just after,
## and the hydrant's gusher.
func _props(game) -> void:
	var city = game.city
	city.stream_now(city.spawn_point)
	await _frames(30)
	var found := {}
	for cell in city.get_children():
		for body in cell.get_children():
			if body is StaticBody3D:
				for c in body.get_children():
					if c is CollisionShape3D and c.has_meta("brk") and c.get_meta("brk").kind in ["street_light", "hydrant", "street_tree"]:
						if not found.has(c.get_meta("brk").kind):
							found[c.get_meta("brk").kind] = c
	Controls.camera = null
	var n := 59
	for kind in found:
		var at: Vector3 = found[kind].global_position
		at.y = 0.0
		var p := Vector2(at.x, at.z)
		var best := INF
		var road := Vector2.ZERO
		for e in city.plan.edge_count():
			if city.plan.drivable(e):
				var q := Geometry2D.get_closest_point_to_segment(p, city.plan.pos(city.plan.edge_a[e]), city.plan.pos(city.plan.edge_b[e]))
				if q.distance_to(p) < best:
					best = q.distance_to(p)
					road = q
		var dir := Vector3(p.x - road.x, 0, p.y - road.y).normalized()
		game.player.global_position = at - dir * 30.0
		game.camera.fixed_focus = at
		game.camera.room_size = 26.0
		game.camera.snap()
		await _frames(30)
		await _shot("%d_%s_before.png" % [n, kind])
		var car = Vehicle.new()
		car.kind = "sedan"
		game.add_child(car)
		car.global_position = at - dir * 14.0
		car.rotation.y = atan2(-dir.x, -dir.z)
		car.driver = Vehicle.Driver.PLAYER
		car.speed = 16.0
		car.velocity = dir * 16.0
		Controls.override_vector = Vector2(dir.x, dir.z)
		await _frames(60)
		Controls.override_vector = Vector2.ZERO
		car.driver = Vehicle.Driver.NONE
		await _frames(10)
		await _shot("%d_%s_after.png" % [n + 1, kind])
		car.queue_free()
		n += 2
	game.camera.fixed_focus = null
	game.camera.room_size = 0.0


## The 4- and 6-lane streets, avenues and boulevards, and the roads out
## of town, with traffic on them.
func _roads(game) -> void:
	var stops := [
		["53_aurum_boulevard", Vector2(600, 140), 60.0],
		["54_gilt_streets", Vector2(180, 230), 90.0],
		["55_midtown_avenue", Vector2(500, 230), 55.0],
		["56_wards_streets", Vector2(1100, 640), 70.0],
		["57_harbor_circle", Vector2(690, 1400), 90.0],
		["58_quarter_streets", Vector2(560, 800), 60.0],
	]
	for stop in stops:
		var at: Vector2 = stop[1]
		var pos := Vector3(at.x, Terrain.height(at.x, at.y), at.y)
		game.city.stream_now(pos)
		game.player.global_position = pos
		game.player.reset_physics_interpolation()
		game.camera.fixed_focus = pos
		game.camera.room_size = stop[2]
		game.camera.snap()
		await _frames(240)
		await _shot(stop[0] + ".png")
	game.camera.fixed_focus = null
	game.camera.room_size = 0.0


## Middle of the street of road `road` nearest `near` (local metres), on
## its right-hand sidewalk side.
func _road_spot(game, road: String, near: Vector2) -> Vector3:
	var plan = game.city.plan
	var best := Vector3.ZERO
	var best_d := INF
	for e in plan.edge_count():
		if plan.edge_road[e] != road:
			continue
		var m: Vector2 = (plan.pos(plan.edge_a[e]) + plan.pos(plan.edge_b[e])) * 0.5
		if m.distance_to(near) < best_d:
			best_d = m.distance_to(near)
			best = Vector3(m.x, 0, m.y)
	return best


func _walk_to_car(game) -> void:
	var p = game.player
	var car = p.nearest_vehicle()
	while car == null:
		var target: Vector3 = game.city.parked_spots[0][0]
		Controls.override_vector = Controls.screen_from_world((target - p.global_position).normalized())
		await _frames(1)
		car = p.nearest_vehicle()
	Controls.override_vector = null
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	await _frames(2)


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(file))
	print("saved ", file)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
