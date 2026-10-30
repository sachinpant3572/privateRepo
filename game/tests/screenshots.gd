extends Node
## Renders a few gameplay screenshots for review. Needs a real renderer:
##   xvfb-run godot --rendering-driver opengl3 res://tests/screenshots.tscn -- <out_dir>

const MainScene = preload("res://main.tscn")
const Terrain = preload("res://scripts/terrain.gd")
const Vehicle = preload("res://scripts/vehicle.gd")
const PedScript = preload("res://scripts/pedestrian.gd")
const Npc = preload("res://scripts/npc.gd")
const CharacterKit = preload("res://scripts/kits/character_kit.gd")

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
	game.settings["camera_turn"] = "north"
	game.missions_enabled = OS.get_environment("SHOTS") == "intro"
	game.save_enabled = false
	if OS.get_environment("SHOTS") in ["blood", "exhaust"]:
		game.population_enabled = false # a quiet street: only the people the shots put there
	add_child(game)
	if game.missions_enabled:
		# Mission 1's opening, as a new game starts it.
		await _intro(game)
		get_tree().quit()
		return
	game.atmosphere.hour = 12.5
	game.atmosphere.minutes_per_second = 0.0
	game.atmosphere.weather_changes = false
	await _frames(180)
	if OS.get_environment("SHOTS") == "hills":
		# Just the roundabouts and the hills (quick look while working on them).
		await _hills(game)
		get_tree().quit()
		return
	if OS.get_environment("SHOTS") == "mountain":
		await _mountain(game)
		get_tree().quit()
		return
	if OS.get_environment("SHOTS") == "lights":
		# Just headlights at night, flat and up and down the hills.
		await _lights(game)
		get_tree().quit()
		return
	if OS.get_environment("SHOTS") == "nightfx":
		# Real lights and effects at night at each graphics quality.
		await _nightfx(game)
		get_tree().quit()
		return
	if OS.get_environment("SHOTS") == "xray":
		# The player on foot and in a car on open road: no see-through tint.
		await _xray(game)
		get_tree().quit()
		return
	if OS.get_environment("SHOTS") == "lookup":
		# Look up through the game's own camera (the HUD's SKY button).
		await _lookup(game)
		get_tree().quit()
		return
	if OS.get_environment("SHOTS") == "props":
		await _props(game)
		get_tree().quit()
		return
	if OS.get_environment("SHOTS") == "crash":
		await _crash(game)
		get_tree().quit()
		return
	if OS.get_environment("SHOTS") == "fire":
		# Car fire early and late, the explosion at 0.1 s, 0.4 s, 2 s and the
		# scorched wreck, by day and night at High and Low (fx_*.png).
		await _fire(game)
		get_tree().quit()
		return
	if OS.get_environment("SHOTS") == "farm":
		# Just Golden Flats' farmland (quick look while working on it).
		await _farm(game)
		get_tree().quit()
		return
	if OS.get_environment("SHOTS") == "routes":
		# Just the ways in from the road to each kind of home.
		await _routes(game)
		get_tree().quit()
		return
	if OS.get_environment("SHOTS") == "wealth":
		# Just one home of each kind at each household tier it takes.
		await _wealth(game)
		get_tree().quit()
		return
	if OS.get_environment("SHOTS") == "view":
		# The same spots in the classic view and in perspective
		# (HANDOFF-perspective-camera.md).
		await _views(game)
		get_tree().quit()
		return
	if OS.get_environment("SHOTS") == "lv":
		# The Las Venturas-size growth (HANDOFF-bellerive-lv.md): Cable Hill,
		# Jade Gate, Calle Luna, Brisa Beach and Ocean Drive, Morrow Point south.
		await _lv(game)
		get_tree().quit()
		return
	if OS.get_environment("SHOTS") == "open":
		# The open land in the city (HANDOFF-world-followups.md stage A):
		# parks with lakes, the cemetery, the stadium, the dock yards.
		await _open(game)
		get_tree().quit()
		return
	if OS.get_environment("SHOTS") == "roads":
		# Just the wide roads (quick look while working on them).
		await _roads(game)
		get_tree().quit()
		return
	if OS.get_environment("SHOTS") == "blood":
		# A street fight's spatter, car hits' smears and pools (0.23).
		await _blood(game)
		get_tree().quit()
		return
	if OS.get_environment("SHOTS") == "flora":
		# The hills' plants and green/dry ground (0.23).
		await _flora(game)
		get_tree().quit()
		return
	if OS.get_environment("SHOTS") == "exhaust":
		# Exhaust by kind and norms, tyre smoke and tyre marks (0.23).
		await _exhaust(game)
		get_tree().quit()
		return
	if OS.get_environment("SHOTS") == "convertibles":
		# Just the 0.23 kinds: the open cars, the bicycle and the MUV.
		await _convertibles(game)
		get_tree().quit()
		return
	if OS.get_environment("SHOTS") == "traffic":
		# Signals by day and night, a queue at a red, rush hour and a quiet
		# night (HANDOFF-0.23-traffic.md).
		await _traffic(game)
		get_tree().quit()
		return
	if OS.get_environment("SHOTS") == "heli":
		# Helicopters (#82): the heliport by day and at dusk, a take-off,
		# downtown from low and high, Mount Calder from the air, the map
		# (HANDOFF-helicopters.md).
		await _heli(game)
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


## Mount Calder (world phase 2): where the range meets the city, the main
## road's switchbacks, the forest half way up, the summit's pads, the
## freight line's shelf at a tunnel portal and on a viaduct's approach, the
## view down from the top with Look up, and the range on the full map
## (mountain_1 to mountain_8).
func _mountain(game) -> void:
	var c = game.city.country
	var m: Dictionary = c.mountain
	# The city's north edge above the cable car's bottom station: the first
	# point out of the city, 60 m on, where the foothills begin.
	var edge := Vector2(0, -430)
	while game.city.plan.in_city(edge) and edge.y > -1500.0:
		edge.y -= 10.0
	var stops := [["mountain_1_city_edge", edge + Vector2(0, -60), 260.0]]
	# The switchbacks: Mount Calder Road's node nearest 500 m up.
	var best := Vector2.ZERO
	var off := INF
	for rd in c.roads:
		if rd.name == "Mount Calder Road":
			for n in rd.nodes:
				var p: Vector2 = c.node_pos[n]
				var d := absf(Terrain.height(p.x, p.y) - 500.0)
				if d < off:
					off = d
					best = p
	stops.append(["mountain_2_switchbacks", best, 300.0])
	stops.append(["mountain_3_forest", best + Vector2(-60, 40), 70.0])
	var s: Dictionary = m.sites
	stops.append(["mountain_4_summit", Vector2(float(s.car_park.x), float(s.car_park.y)), 200.0])
	# The longest tunnel and the longest viaduct, each from a little before
	# its start.
	var rp: Dictionary = c.rail_pass
	var longest := {}
	for sp in rp.get("spans", []):
		var t: String = sp[2]
		if not longest.has(t) or float(sp[1]) - float(sp[0]) > float(longest[t][1]) - float(longest[t][0]):
			longest[t] = sp
	for t in ["t", "b"]:
		if not longest.has(t):
			continue
		var name: String = "mountain_5_rail_tunnel" if t == "t" else "mountain_6_rail_viaduct"
		var k := clampi(int(float(longest[t][0]) / 16.0) - 2, 0, rp.pts.size() - 1)
		stops.append([name, Vector2(rp.pts[k][0], rp.pts[k][1]), 160.0])
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
	# From the viewing deck, Look up toward the city.
	var deck := Vector3(float(s.deck.x), float(s.deck.z), float(s.deck.y))
	game.city.stream_now(deck)
	game.player.global_position = deck
	game.player.reset_physics_interpolation()
	await _frames(30)
	game.camera.set_look_up(true)
	await _frames(60)
	await _shot("mountain_7_view_from_top.png")
	game.camera.set_look_up(false)
	game.hud.full_map.open()
	for i in 4:
		await get_tree().process_frame
	await _shot("mountain_8_map.png")
	game.hud.full_map.close()


## The hills' ecology (0.23): a wet canyon floor, a dry south face, a
## green north face, the pines up high, a eucalyptus grove, and two wide
## views showing the golden and green patches.
func _flora(game) -> void:
	var Flora = preload("res://scripts/kits/flora_kit.gd")
	var best := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var b: Rect2 = Terrain.bounds
	for i in 6000:
		var x := b.position.x + rng.randf() * b.size.x
		var z := b.position.y + rng.randf() * b.size.y
		var h := Terrain.height(x, z)
		if h < 8.0:
			continue
		var n := Terrain.normal(x, z)
		var m: float = Flora.moisture(x, z, h, n)
		var score := {
			"canyon": m - h / 60.0,
			"south": -m + n.z,
			"north": m - n.z,
			"pines": (h - 60.0) / 40.0 + m if h > 65.0 else -INF,
			"grove": Flora.noise(x, z, 90.0, 3) - h / 80.0,
		}
		for k: String in score:
			if score[k] > best.get(k, [-INF])[0]:
				best[k] = [score[k], Vector2(x, z)]
	var stops := []
	var names := {"canyon": "flora_1_canyon", "south": "flora_2_south_face", "north": "flora_3_north_face",
		"pines": "flora_4_pines", "grove": "flora_5_eucalyptus"}
	for k: String in names:
		if best.has(k):
			stops.append([names[k], best[k][1], 45.0])
	stops.append(["flora_6_wide_observatory", Vector2(1050, -905), 220.0])
	stops.append(["flora_7_wide_canyon", Vector2(760, -1150), 260.0])
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


## Each kind of home close up with its drive or path out to the road (or
## the yard's track): the first lot of each kind, a cluster of each style,
## and a rowhouse row facing the city's edge.
func _routes(game) -> void:
	var c = game.city.country
	var stops := []
	var seen := {}
	for l: Array in c.lots:
		var kind: String = c.kinds[int(l[5])]
		var in_plot := int(l[8]) >= 0
		var key: String = kind + ("@" + c.plot_types[int(c.plots[int(l[8])][5])] if in_plot else "")
		if seen.has(key) or kind not in ["house", "cape_house", "rowhouse_row", "shack", "stilt_house", "mansion", "garden_apartments", "trailer_home", "farmhouse", "farmhouse_big", "farmhouse_small", "ranch_house", "adobe_farmhouse"]:
			continue
		seen[key] = true
		stops.append(["73_%02d_%s" % [stops.size(), key.replace("@", "_in_")], Vector2(l[0], l[1]), 34.0 if kind != "rowhouse_row" else 50.0])
	# The first rowhouse row with the city within 40 m of it.
	for l: Array in c.lots:
		var p := Vector2(l[0], l[1])
		if c.kinds[int(l[5])] != "rowhouse_row" or game.city.plan.in_city(p):
			continue
		var near := false
		for d in [Vector2(40, 0), Vector2(-40, 0), Vector2(0, 40), Vector2(0, -40)]:
			near = near or game.city.plan.in_city(p + d)
		if near:
			stops.append(["73_%02d_rowhouse_city_edge" % stops.size(), p, 60.0])
			break
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


## One home of each kind at each household tier (HANDOFF-wealth.md), the
## street's lot centred: 74_<tier>_<kind>.
func _wealth(game) -> void:
	var c = game.city.country
	var stops := []
	var seen := {}
	for l: Array in c.lots:
		var t := int(l[10]) if l.size() > 10 else -1
		var key := "T%d_%s" % [t, c.kinds[int(l[5])]]
		if t < 0 or seen.has(key):
			continue
		seen[key] = true
		stops.append(["74_%s" % key, Vector2(l[0], l[1]), 50.0 if c.kinds[int(l[5])] in ["rowhouse_row", "mansion", "condo_tower", "garden_apartments"] else 30.0])
	stops.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
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


## 0.23 crash physics: a sedan driven at 72 km/h into the side of a parked
## one (before, the impact with panels flying and the nose dipping, the
## dents once it settles), then the struck car set alight, its blast and
## the wreck.
func _crash(game) -> void:
	var at := Vector2(690, 470)
	var pos := Vector3(at.x, Terrain.height(at.x, at.y), at.y)
	game.city.stream_now(pos)
	game.player.global_position = pos + Vector3(-12, 0, 8)
	game.camera.fixed_focus = pos + Vector3(0, 0, 6)
	game.camera.room_size = 22.0
	game.camera.snap()
	var parked = Vehicle.new()
	parked.kind = "sedan"
	parked.body_color = Color(0.2, 0.35, 0.7)
	game.add_child(parked)
	parked.global_position = pos
	parked.rotation.y = PI / 2.0
	var car = Vehicle.new()
	car.kind = "sedan"
	car.body_color = Color(0.75, 0.12, 0.1)
	game.add_child(car)
	car.global_position = pos + Vector3(0, 0, 14)
	car.driver = Vehicle.Driver.PLAYER
	await _frames(20)
	await _shot("93_crash_before.png")
	game.camera.fixed_focus = pos
	car.speed = 20.0
	car.velocity = Vector3(0, 0, -20)
	Controls.override_vector = Vector2(0, -1)
	var hit := false
	for i in 90:
		await _frames(1)
		if car.global_position.distance_to(parked.global_position) < 4.0 and not hit:
			hit = true
			Controls.override_vector = Vector2.ZERO
			car.driver = Vehicle.Driver.NONE
			await _frames(4)
			await _shot("93_crash_impact.png")
			break
	print("crash hit=%s parked hp %.0f spin %.2f car hp %.0f" % [hit, parked.health, parked.rotation.y - PI / 2.0, car.health])
	await _frames(120)
	game.camera.room_size = 11.0
	game.camera.snap()
	await _frames(10)
	await _shot("93_crash_dents.png")
	car.global_position += Vector3(0, 0, 12) # out of the blast
	parked._damage(parked.health - parked.max_health * parked.FIRE_AT * 0.9, true)
	game.camera.room_size = 16.0
	game.camera.snap()
	await _frames(60)
	await _shot("94_crash_fire.png")
	for i in 900:
		if parked._fire == null or parked._fire.exploded:
			break
		await _frames(1)
	await _frames(6)
	await _shot("94_crash_blast.png")
	await _frames(150)
	await _shot("94_crash_wreck.png")
	game.camera.fixed_focus = null
	game.camera.room_size = 0.0


## A burning sedan: a small engine fire, the whole car alight, then the
## explosion at 0.1 s, 0.4 s, 2 s and the wreck with its scorch mark, by day
## and by night at High, and by day and night at Low. Run it with
## `--fixed-fps 60` so each frame is 1/60 s of game time. `FIRE_ONLY=day_high,...`
## runs just those.
func _fire(game) -> void:
	var at := Vector2(690, 470)
	var pos := Vector3(at.x, Terrain.height(at.x, at.y), at.y)
	game.city.stream_now(pos)
	game.player.global_position = pos + Vector3(-30, 0, 20)
	var only := OS.get_environment("FIRE_ONLY")
	for run in [["day_high", 11.0, "high"], ["night_high", 22.5, "high"], ["day_low", 11.0, "low"], ["night_low", 22.5, "low"]]:
		if only != "" and not (run[0] in only.split(",")):
			continue
		game.Graphics.pick(game.settings, run[2])
		game.apply_settings()
		game.atmosphere.hour = run[1]
		var tag: String = run[0]
		game.camera.fixed_focus = pos + Vector3(0, 0, 1.0)
		game.camera.room_size = 9.0
		game.camera.snap()
		var other = Vehicle.new()
		other.kind = "sedan"
		other.body_color = Color(0.2, 0.35, 0.7)
		game.add_child(other)
		other.global_position = pos + Vector3(8.5, 0, 0)
		var car = Vehicle.new()
		car.kind = "sedan"
		car.body_color = Color(0.75, 0.75, 0.72)
		game.add_child(car)
		car.global_position = pos
		car.rotation.y = PI / 2.0
		await _frames(40)
		car._damage(car.health - car.max_health * car.FIRE_AT * 0.97, true)
		await _frames(45)
		await _shot("fx_%s_1_early.png" % tag)
		var fire = car._fire
		for i in 900:
			if fire._k > 0.8:
				break
			await _frames(1)
		await _shot("fx_%s_2_late.png" % tag)
		game.camera.room_size = 20.0
		game.camera.snap()
		for i in 900:
			if fire.exploded:
				break
			await _frames(1)
		await _frames(5)
		await _shot("fx_%s_3_blast_0.1s.png" % tag)
		await _frames(18)
		await _shot("fx_%s_4_blast_0.4s.png" % tag)
		await _frames(30)
		await _shot("fx_%s_5_blast_0.9s.png" % tag)
		await _frames(72)
		await _shot("fx_%s_6_smoke_2s.png" % tag)
		await _frames(300)
		game.camera.room_size = 14.0
		await _shot("fx_%s_7_wreck_7s.png" % tag)
		await _frames(1200)
		await _shot("fx_%s_8_scorch_27s.png" % tag)
		print("fire %s: explosion pieces on %d" % [tag, Fx.boom.pieces_on()])
		car.queue_free()
		other.queue_free()
		await _frames(5)
	game.camera.fixed_focus = null
	game.camera.room_size = 0.0
	game.Graphics.pick(game.settings, "high")
	game.apply_settings()
	game.atmosphere.hour = 11.0


## A car with its lights on at night, on the flat and pointing up and down
## the Bellerive Hills: the beams must lie on the ground ahead, not sink
## under a road that climbs.
func _lights(game) -> void:
	game.atmosphere.hour = 22.0
	game.player.visible = false
	var stops := [
		["86_lights_flat", Vector2(690, 470), 0.0],
		["86_lights_down_crest", Vector2(1560, -1255), -1.0],
		["86_lights_down_canyon", Vector2(760, -1150), -1.0],
		["86_lights_up_crest", Vector2(1560, -1255), 1.0],
		["86_lights_up_canyon", Vector2(760, -1150), 1.0],
	]
	for stop in stops:
		var at: Vector2 = stop[1]
		var n := Terrain.normal(at.x, at.y)
		var dir := Vector3(0, 0, -1)
		if stop[2] != 0.0 and Vector2(n.x, n.z).length() > 0.001:
			dir = -Vector3(n.x, 0, n.z).normalized() * stop[2] # uphill is against the normal's lean
		var pos := Vector3(at.x, Terrain.height(at.x, at.y), at.y)
		game.city.stream_now(pos)
		game.player.global_position = pos - dir * 6.0
		var car = Vehicle.new()
		car.kind = "sedan"
		game.add_child(car)
		car.global_position = pos
		car.rotation.y = atan2(-dir.x, -dir.z)
		car.driver = Vehicle.Driver.PLAYER
		game.camera.fixed_focus = pos + dir * 6.0
		game.camera.room_size = 34.0
		game.camera.snap()
		await _frames(40)
		print("lights %s grade %.1f%%" % [stop[0], 100.0 * (Terrain.height(pos.x + dir.x * 10.0, pos.z + dir.z * 10.0) - pos.y) / 10.0])
		await _shot(stop[0] + ".png")
		car.queue_free()
	game.camera.fixed_focus = null
	game.camera.room_size = 0.0
	game.player.visible = true


## Night at each graphics quality: a car's real headlight on the road with
## a parked car in its beam, the street lamps round it, and a police car's
## light bar (87); then the Lantern Quarter's gas lamps at High (88).
func _lookup(game) -> void:
	var cam = game.camera
	for v in [["89_lookup_city_night", 300.0, 250.0, 22.5, 0.5], ["90_lookup_hills_night", 1200.0, -1300.0, 22.5, 1.0],
			["91_lookup_hills_dusk", 1200.0, -1300.0, 18.2, 1.0], ["92_lookup_city_day", 300.0, 250.0, 11.0, 1.0]]:
		var pos := Vector3(v[1], 0.0, v[2])
		pos.y = Terrain.height(pos.x, pos.z)
		game.atmosphere.hour = v[3]
		game.player.global_position = pos + Vector3(0, 0.5, 0)
		game.city.stream_now(pos)
		cam.set_look_up(false)
		cam._look_t = 0.0
		cam.snap()
		await _frames(10)
		cam.set_look_up(true)
		for i in 600:
			if cam.look_up_amount() >= v[4]:
				break
			await get_tree().process_frame
		await _frames(20)
		print("lookup %s: amount %.2f, forward y %.2f" % [v[0], cam.look_up_amount(), -cam.global_basis.z.y])
		await _shot(v[0] + ".png")
	cam.set_look_up(false)


## Mission 1's opening on a new game: the title card, Jules's first line
## and the snatch (95). The hero must be in plain view throughout.
func _intro(game) -> void:
	await _frames(80)
	await _shot("95_intro_card.png")
	await _frames(100)
	await _shot("95_intro_line.png")
	var p = game.player
	print("intro: player %s cam yaw %.2f pitch %.1f" % [p.global_position, game.camera.yaw, game.camera.global_rotation_degrees.x])
	for i in 3:
		game.hud._advance_dialogue()
		await _frames(90)
		await _shot("95_intro_after_%d.png" % i)


func _xray(game) -> void:
	var at := Vector2(690, 470)
	var pos := Vector3(at.x, Terrain.height(at.x, at.y), at.y)
	game.city.stream_now(pos)
	game.player.global_position = pos
	game.camera.snap()
	for q in ["low", "ultra"]:
		game.Graphics.pick(game.settings, q)
		game.apply_settings()
		await _frames(30)
		await _shot("93_xray_foot_%s.png" % q)
	var car = Vehicle.new()
	car.kind = "sedan"
	game.add_child(car)
	car.global_position = pos + Vector3(0, 0, 3)
	await _frames(2)
	game.player.enter_vehicle(car)
	await _frames(30)
	await _shot("93_xray_car_ultra.png")
	game.player.exit_vehicle()
	car.queue_free()
	game.Graphics.pick(game.settings, "high")
	game.apply_settings()


func _nightfx(game) -> void:
	game.atmosphere.hour = 22.0
	game.player.visible = false
	var at := Vector2(690, 470)
	var pos := Vector3(at.x, Terrain.height(at.x, at.y), at.y)
	game.city.stream_now(pos)
	game.player.global_position = pos + Vector3(0, 0, 4)
	var cars := []
	for spec in [["sedan", Vector3.ZERO, Vehicle.Driver.PLAYER], ["van", Vector3(1.5, 0, -11), Vehicle.Driver.NONE], ["police", Vector3(-6, 0, 4), Vehicle.Driver.SCRIPT]]:
		var car = Vehicle.new()
		car.kind = spec[0]
		car.is_police = spec[0] == "police"
		game.add_child(car)
		car.global_position = pos + spec[1]
		car.driver = spec[2]
		car._deployed = car.is_police # parked on a job, bar flashing
		cars.append(car)
	Wanted.level = 1 # the bar flashes while someone is wanted
	game.camera.fixed_focus = pos + Vector3(0, 0, -6)
	game.camera.room_size = 40.0
	game.camera.snap()
	for q in ["low", "medium", "high", "ultra"]:
		game.Graphics.pick(game.settings, q)
		game.apply_settings()
		await _frames(30)
		print("nightfx %s: %d car lights, %d lamp lights" % [q, game.graphics.lit_cars.size(), game.graphics.lit_lamps().size()])
		await _shot("87_night_%s.png" % q)
	game.Graphics.pick(game.settings, "high")
	game.apply_settings()
	Wanted.level = 0
	for car in cars:
		car.queue_free()
	var sq: Vector3 = game.city.landmark_front("lantern_square")
	game.city.stream_now(sq)
	game.player.global_position = sq
	game.camera.fixed_focus = sq
	game.camera.room_size = 34.0
	game.camera.snap()
	await _frames(30)
	print("nightfx lantern: %d lamp lights" % game.graphics.lit_lamps().size())
	await _shot("88_night_lantern_high.png")
	game.camera.fixed_focus = null
	game.camera.room_size = 0.0
	game.player.visible = true


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


## The new districts of the Las Venturas-size growth, each printed with
## the district the game finds there.
func _lv(game) -> void:
	var stops := [
		["lv_1_cable_hill", Vector2(60, -380), 80.0],
		["lv_2_jade_gate", Vector2(420, -330), 70.0],
		["lv_3_calle_luna", Vector2(1700, 1000), 70.0],
		["lv_4_brisa_beach", Vector2(1720, 1450), 80.0],
		["lv_5_ocean_drive", Vector2(1900, 1510), 70.0],
		["lv_6_morrow_point_south", Vector2(700, 1800), 90.0],
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
		print("district ", stop[0], " ", game.city.district_at(pos).get("name", "?"))
		await _shot(stop[0] + ".png")
	game.camera.fixed_focus = null
	game.camera.room_size = 0.0


func _open(game) -> void:
	var zoom := {"halcyon_park": 150.0, "bellerive_bowl": 130.0, "morrow_cemetery": 90.0,
		"ironwharf_containers": 90.0, "ironwharf_rail_yard": 90.0}
	var n := 0
	for site in preload("res://scripts/street_plan.gd").OPEN_LAND:
		var f: int = game.city.plan.set_piece_face(site.id)
		var at: Vector2 = game.city.plan.faces[f].center if f >= 0 else site.at
		var pos := Vector3(at.x, Terrain.height(at.x, at.y), at.y)
		game.city.stream_now(pos)
		game.player.global_position = pos
		game.player.reset_physics_interpolation()
		game.camera.fixed_focus = pos
		game.camera.room_size = zoom.get(site.id, 75.0)
		game.camera.snap()
		await _frames(240)
		n += 1
		await _shot("open_%d_%s.png" % [n, site.id])
	game.camera.fixed_focus = null
	game.camera.room_size = 0.0


## Blood (0.23) from the game camera: two people hit by cars on the near
## lane (one hurt at 32 km/h, one killed at 80 km/h) smear the road and
## pool; on the sidewalk beside them a fight spatters it, one victim
## punched, one kicked to death. Shot as the killing kick lands, then once
## the pools have spread: by day at the on-foot, closest and driving zooms
## and at low quality, aged 40 s, and at night.
func _blood(game) -> void:
	game.player.visible = false
	game.Graphics.pick(game.settings, "high")
	game.apply_settings()
	var at := Vector3(500, 0, 230)
	game.city.stream_now(at)
	var near: Array = game.city.nearest_sidewalk(at)
	var loop: PackedVector3Array = game.city.sidewalk_loops[near[0]]
	var walk: Vector3 = loop[near[1]]
	var along: Vector3 = loop[(near[1] + 1) % loop.size()] - walk
	along.y = 0.0
	along = along.normalized()
	# The street is the nearer side off the paving; the lane 2 m into it.
	var lane := walk
	var off := INF
	for side in [Vector3(-along.z, 0, along.x), Vector3(along.z, 0, -along.x)]:
		for k in 30:
			var p: Vector3 = walk + side * (0.5 * k)
			if Fx.bloodwork._paving(Vector2(p.x, p.z)) <= 0.0:
				if k < off:
					off = k
					lane = p + side * 2.0
				break
	print("blood: sidewalk %s, lane %s, along %s" % [walk, lane, along])
	game.player.global_position = walk + along * 16.0 # off to one side, in the open
	var focus := (walk + lane) * 0.5
	focus.y = Terrain.height(focus.x, focus.z)
	game.camera.fixed_focus = focus
	game.camera.room_size = 16.0
	game.camera.snap()
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var yaw := atan2(along.x, along.z)
	var fighter = _blood_ped(game, rng, near, walk, yaw)
	var punched = _blood_ped(game, rng, near, walk + along * 1.0, yaw + PI)
	var kicked = _blood_ped(game, rng, near, walk - along * 1.0, yaw)
	var hurt = _blood_ped(game, rng, near, lane - along * 12.0, yaw)
	var killed = _blood_ped(game, rng, near, lane - along * 10.0 + (lane - walk).normalized() * 2.0, yaw)
	await _frames(30)
	for hit in [[hurt, 9.0], [killed, 22.0]]:
		var car = Vehicle.new()
		car.kind = "sedan"
		game.add_child(car)
		car.global_position = hit[0].global_position - along * 3.0
		car.velocity = along * hit[1]
		hit[0].hit_by_vehicle(car, hit[1])
		car.queue_free()
	await _frames(60)
	# The player's punch (12) and kick (24); people have 40 health.
	punched.take_hit(fighter, 12.0, along * 2.0)
	await _frames(20)
	punched.take_hit(fighter, 12.0, along * 2.0)
	kicked.take_hit(fighter, 24.0, -along * 2.2)
	await _frames(25)
	kicked.take_hit(fighter, 24.0, -along * 2.2)
	await _frames(5)
	await _shot("blood_1_kick_close.png")
	await _frames(420)
	print("blood: %d marks, %d spurts; hurt dead=%s, killed dead=%s, kicked dead=%s" % [Fx.bloodwork.live(), Fx.bloodwork.spurts, hurt.dead, killed.dead, kicked.dead])
	await _shot("blood_2_day_close.png")
	for zoom in [["3_day_foot", 26.0], ["4_day_drive", 62.0]]:
		game.camera.room_size = zoom[1]
		game.camera.snap()
		await _frames(10)
		await _shot("blood_%s.png" % zoom[0])
	game.camera.room_size = 26.0
	game.camera.snap()
	game.Graphics.pick(game.settings, "low")
	game.apply_settings()
	await _frames(10)
	await _shot("blood_5_day_foot_low.png")
	game.Graphics.pick(game.settings, "high")
	game.apply_settings()
	Fx.bloodwork.clock += 40.0 # the marks 40 s older: dried darker
	await _frames(10)
	await _shot("blood_6_day_aged.png")
	Fx.bloodwork.clock -= 40.0
	game.atmosphere.hour = 22.0
	await _frames(30)
	await _shot("blood_7_night_foot.png")
	game.camera.room_size = 16.0
	game.camera.snap()
	await _frames(10)
	await _shot("blood_8_night_close.png")
	game.Graphics.pick(game.settings, "low")
	game.apply_settings()
	await _frames(10)
	await _shot("blood_9_night_close_low.png")
	game.camera.fixed_focus = null
	game.camera.room_size = 0.0


## A street with: an old diesel semi pulling away (soot), a sedan's
## cold-start vapour at night, a drift's smoke and dark marks, and an ABS
## sedan's faint marks beside a motorbike's locked-wheel ones.
func _exhaust(game) -> void:
	game.player.visible = false
	game.player.process_mode = Node.PROCESS_MODE_DISABLED
	game.Graphics.pick(game.settings, "high")
	game.apply_settings()
	Controls.scheme = "arrows"
	# A low-rise street in the wards (39_wards_from_above), so the road is
	# in the sun: dark rubber does not show in a downtown tower's shadow.
	var at := Vector3(1080, 0, 620)
	print("exhaust: street near %s" % at)
	# The city streams round the (hidden) player.
	game.player.global_position = at
	game.city.stream_now(at)
	var near: Array = game.city.nearest_sidewalk(at)
	var loop: PackedVector3Array = game.city.sidewalk_loops[near[0]]
	var walk: Vector3 = loop[near[1]]
	var along: Vector3 = loop[(near[1] + 1) % loop.size()] - walk
	along.y = 0.0
	along = along.normalized()
	var lane := walk
	for side in [Vector3(-along.z, 0, along.x), Vector3(along.z, 0, -along.x)]:
		for k in 30:
			var p: Vector3 = walk + side * (0.5 * k)
			if Fx.bloodwork._paving(Vector2(p.x, p.z)) <= 0.0:
				if lane == walk:
					lane = p + side * 3.0
				break
	var across := (lane - walk).normalized()
	var yaw := atan2(-along.x, -along.z) # the nose (-z) along the street
	var cam = game.camera
	cam.room_size = 22.0

	# 1-2: an old (pre-filter) diesel semi pulls away and shifts up.
	var semi = _exhaust_car(game, "semi", lane - along * 30.0, yaw)
	semi._roll_emissions()
	semi._emit.old = true
	semi._emit.smoker = false
	semi._engine_on = true # warm: no cold-start vapour in this one
	# The camera first: puffs further than 70 m from it are not made.
	_exhaust_look(cam, semi.global_position + along * 4.0)
	await _frames(3)
	semi.drive_path(PackedVector3Array([lane + along * 60.0]), 0.95)
	await _frames(70)
	_exhaust_look(cam, semi.global_position)
	await _frames(3)
	await _shot("exhaust_1_diesel_pull.png")
	await _frames(50)
	_exhaust_look(cam, semi.global_position)
	await _frames(3)
	await _shot("exhaust_2_diesel_shift.png")
	print("exhaust: semi speed %.1f, gear %d, %d puffs" % [semi.speed, semi._gear, Fx.puffs.count()])
	semi.queue_free()
	await _frames(240) # the soot clears

	# 3-4: a sedan's cold start, at dawn and at night: white vapour at the
	# tailpipe (a warm modern car shows nothing).
	var shot := 3
	for hour in [6.6, 22.0]:
		game.atmosphere.hour = hour
		var cold = _exhaust_car(game, "sedan", lane - along * 30.0, yaw)
		cold._roll_emissions()
		cold._emit.smoker = false
		_exhaust_look(cam, cold.global_position + along * 2.0)
		cam.room_size = 12.0
		await _frames(3)
		cold.driver = Vehicle.Driver.PLAYER
		await _frames(90)
		await _frames(3)
		await _shot("exhaust_%d_cold_start_%s.png" % [shot, "dawn" if hour < 12.0 else "night"])
		shot += 1
		cold.queue_free()
		await _frames(2)
	cam.room_size = 22.0
	game.atmosphere.hour = 12.5
	Fx.puffs.clear()

	# 5-6: a drift: tyre smoke and dark curving marks.
	var drift = _exhaust_car(game, "sports", lane - along * 25.0 + across * 1.0, yaw)
	var start: Vector3 = drift.global_position
	_exhaust_look(cam, start + along * 8.0)
	await _frames(3)
	drift.driver = Vehicle.Driver.PLAYER
	drift.speed = 20.0
	drift.velocity = along * 20.0
	Input.action_press("gas")
	Input.action_press("steer_left")
	await _frames(12)
	Input.action_release("gas")
	Input.action_press("brake")
	await _frames(12)
	Input.action_release("brake")
	await _frames(30)
	Input.action_release("steer_left")
	# Framed over the lane it left (framed further out, the camera sits in
	# the far side's buildings).
	_exhaust_look(cam, start + along * (drift.global_position - start).dot(along) + across * 2.0)
	await _frames(2)
	await _shot("exhaust_5_drift.png")
	await _frames(60)
	# Back where it slid: the marks (and the smoke clearing).
	_exhaust_look(cam, start + along * 12.0 + across * 1.0)
	await _frames(2)
	await _shot("exhaust_6_drift_marks.png")
	drift.queue_free()
	await _frames(2)

	# 7: hard stops side by side: the sedan's ABS leaves faint broken marks,
	# the motorbike (no ABS) locks up and marks dark.
	# Kept near the near kerb: framed further out, the camera (65 degrees,
	# no cutaway while its focus is fixed) sits inside the far side's towers.
	var sedan = _exhaust_car(game, "sedan", lane - along * 20.0 + across * 0.5, yaw)
	var bike = _exhaust_car(game, "motorbike", lane - along * 20.0 + across * 4.0, yaw)
	_exhaust_look(cam, sedan.global_position + along * 4.0)
	await _frames(3)
	for v in [sedan, bike]:
		v._engine_on = true
		v.driver = Vehicle.Driver.PLAYER
		v.speed = 20.0
		v.velocity = along * 20.0
	Input.action_press("brake")
	await _frames(70)
	Input.action_release("brake")
	_exhaust_look(cam, sedan.global_position - along * 6.0 + across * 1.0)
	await _frames(3)
	await _shot("exhaust_7_abs_vs_locked.png")
	print("exhaust: %d tyre marks, %d puffs" % [Fx._skid_total, Fx.puffs.count()])
	Controls.scheme = "stick"
	cam.fixed_focus = null
	cam.room_size = 0.0


func _exhaust_car(game, kind: String, pos: Vector3, yaw: float):
	var car = Vehicle.new()
	car.kind = kind
	game.add_child(car)
	pos.y = Terrain.height(pos.x, pos.z)
	car.global_position = pos
	car.rotation.y = yaw
	return car


func _exhaust_look(cam, at: Vector3) -> void:
	at.y = Terrain.height(at.x, at.z)
	cam.fixed_focus = at
	cam.snap()


## A pedestrian standing still at `pos` facing `yaw`, on sidewalk loop
## `near` ([loop, point]).
func _blood_ped(game, rng: RandomNumberGenerator, near: Array, pos: Vector3, yaw: float):
	var ped = PedScript.new()
	ped.setup(game.city, rng, near[0], near[1])
	ped.point_index = near[1]
	ped.personality = "calm"
	ped.walk_speed = 0.0
	ped.position = Vector3(pos.x, Terrain.height(pos.x, pos.z), pos.z)
	ped.rotation.y = yaw
	game.add_child(ped)
	return ped


## Traffic (0.23), all through the gameplay camera on foot unless noted: a
## downtown signal by day and at night (96), the same up close (96 close,
## a fixed camera), a queue held at a red (97), downtown at the 8:00 rush
## and a residential street at 2:30 (98).
func _traffic(game) -> void:
	var TP = preload("res://scripts/traffic_plan.gd")
	var TM = preload("res://scripts/traffic.gd")
	var city = game.city
	var traffic = game.population.traffic
	var s: Vector3 = city.spawn_point
	# The downtown signal nearest the spawn point with its longest approach.
	var best := -1
	var best_d := INF
	var from := -1
	for n in city.plan.node_count():
		if not city.drive_node(n) or city.node_pos(n).distance_to(s) > best_d:
			continue
		if str(city.district_at(city.node_pos(n)).get("style", "")) != "downtown":
			continue
		var j: Dictionary = TP.junction(city, n)
		if int(j.kind) != TP.SIGNALS:
			continue
		var far := -1
		var far_len := 70.0
		for leg in j.legs:
			if not leg.link and float(leg.length) > far_len and city.next_nodes(leg.to).has(n):
				far = int(leg.to)
				far_len = float(leg.length)
		if far >= 0:
			best = n
			best_d = city.node_pos(n).distance_to(s)
			from = far
	if best < 0:
		print("traffic: no downtown signal with a 70 m approach")
		return
	var c: Vector3 = city.node_pos(best)
	var dir: Vector3 = c - city.node_pos(from)
	dir.y = 0.0
	dir = dir.normalized()
	var side := Vector3(-dir.z, 0.0, dir.x)
	var corner: Vector3 = _sidewalk_near(game, c - dir * 14.0 + side * 10.0)
	print("traffic: signal %d at %s, approach from %d" % [best, c, from])
	game.player.visible = false
	# The game's camera held on the junction: about the on-foot view (40 m),
	# the driving view (62 m) at night, and close up (22 m).
	for v in [["96_traffic_junction_day", 12.5, 40.0], ["96_traffic_junction_night", 22.0, 40.0],
			["96_traffic_junction_night_drive", 22.0, 62.0], ["96_traffic_junction_night_close", 22.0, 22.0]]:
		game.atmosphere.hour = v[1]
		game.camera.fixed_focus = c
		game.camera.room_size = v[2]
		await _stand(game, corner, 300 if v[2] == 40.0 else 30)
		print("traffic %s: %d cars, budget %d, %d lenses" % [v[0], game.population.cars.size(), traffic.budget(), traffic._mm.visible_instance_count])
		await _shot(v[0] + ".png")
	# A queue held at a red: six cars down the longest approach.
	game.atmosphere.hour = 12.5
	var e: Dictionary = traffic._entry(best)
	var g: int = e.legs[e.to_leg[from]].group
	traffic._set_phase(e, TM.CROSS_GO if g == 0 else TM.MAIN_GO)
	e.go_end = 1e9
	var lanes: int = city.lane_count(from, best)
	var queue: Array = []
	for i in 6:
		var lane: int = i % mini(lanes, 2)
		var s0: Vector3 = city.lane_start(from, best, lane)
		var u: Vector3 = city.lane_point(from, best, lane) - s0
		u.y = 0.0
		u = u.normalized()
		var car = Vehicle.new()
		car.kind = ["sedan", "taxi", "van", "suv", "compact", "box_truck"][i]
		car.city = city
		car.position = s0 + u * (12.0 + 11.0 * floorf(i / 2.0))
		car.rotation.y = atan2(-u.x, -u.z)
		car.rng.seed = 70 + i
		car.start_traffic(city, from, best, lane)
		game.add_child(car)
		queue.append(car)
	game.camera.fixed_focus = c - dir * 22.0
	game.camera.room_size = 48.0
	await _stand(game, _sidewalk_near(game, c - dir * 24.0 + side * 9.0), 900)
	var held := queue.filter(func(q): return is_instance_valid(q) and q.is_waiting())
	print("traffic red queue: light %d, %d of 6 waiting" % [traffic.light(best, from), held.size()])
	await _shot("97_traffic_red_queue.png")
	for q in queue:
		if is_instance_valid(q):
			q.queue_free()
	traffic._set_phase(e, TM.MAIN_GO)
	# Rush hour downtown, then a residential street deep in the night, both
	# framed wide (100 m; the driving view is 62 m). Population's reach is
	# the same at both sizes (2.1x vs 2.07x), so the frame doesn't change
	# where cars spawn; the log gives the counts, which the shot alone can't.
	game.atmosphere.hour = 8.0
	game.camera.fixed_focus = c
	game.camera.room_size = 100.0
	await _stand(game, corner, 1200)
	print("traffic rush: %d cars (%d within 50 m), budget %d, density %.2f" % [game.population.cars.size(),
		_cars_within(game, c, 50.0), traffic.budget(), traffic._density])
	await _shot("98_traffic_rush_downtown.png")
	var quiet := Vector3.INF
	var q_style := ""
	for style in ["rowhouse", "brownstone", "suburb", "wards"]:
		var q_d := INF
		for n in city.plan.node_count():
			var p: Vector3 = city.node_pos(n)
			if not city.drive_node(n) or p.distance_to(s) > q_d or str(city.district_at(p).get("style", "")) != style:
				continue
			var spot := _sidewalk_near(game, p + Vector3(9, 0, 9))
			if str(city.district_at(spot).get("style", "")) == style:
				quiet = spot
				q_d = p.distance_to(s)
		if quiet != Vector3.INF:
			q_style = style
			break
	game.atmosphere.hour = 2.5
	game.camera.fixed_focus = quiet
	await _stand(game, quiet, 1200)
	print("traffic quiet (%s): %d cars (%d within 50 m), budget %d, density %.2f" % [q_style,
		game.population.cars.size(), _cars_within(game, quiet, 50.0), traffic.budget(), traffic._density])
	await _shot("98_traffic_quiet_night.png")
	# A rough frame-time probe back at the rush: physics time per frame with
	# the junction controller running and with it paused, in alternating
	# blocks of 150 frames so traffic drifting about weighs on both alike.
	game.atmosphere.hour = 8.0
	game.camera.fixed_focus = null
	game.camera.room_size = 0.0
	game.player.visible = true
	await _stand(game, corner, 900)
	var sums := [0.0, 0.0]
	var worsts := [0.0, 0.0]
	var draws := [0.0, 0.0]
	for block in 6:
		var m := block % 2 # 0 controller on, 1 paused
		traffic.set_physics_process(m == 0)
		for i in 150:
			await get_tree().physics_frame
			var t: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
			sums[m] += t
			worsts[m] = maxf(worsts[m], t)
			draws[m] += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	traffic.set_physics_process(true)
	for m in 2:
		print("traffic probe (controller %s): %d cars, physics %.2f ms a frame (worst %.2f), %.0f draw calls" % [
			"on" if m == 0 else "paused", game.population.cars.size(), sums[m] / 450.0 * 1000.0,
			worsts[m] * 1000.0, draws[m] / 450.0])


## How many population cars are within `r` m of `pos` (flat distance).
func _cars_within(game, pos: Vector3, r: float) -> int:
	var count := 0
	for car in game.population.cars:
		if is_instance_valid(car) and Vector2(car.global_position.x - pos.x, car.global_position.z - pos.z).length() <= r:
			count += 1
	return count


## The sidewalk point nearest `pos`.
func _sidewalk_near(game, pos: Vector3) -> Vector3:
	var sw: Array = game.city.nearest_sidewalk(pos)
	return game.city.sidewalk_loops[sw[0]][sw[1]]


## The player on foot at `pos`, the gameplay camera on them, for `frames`.
func _stand(game, pos: Vector3, frames: int) -> void:
	game.city.stream_now(pos)
	game.player.global_position = pos
	game.player.reset_physics_interpolation()
	game.camera.snap()
	await _frames(frames)


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


## Downtown by the Aurum Tower, Midtown's towers and the low-rise Lantern
## Square, on foot and (downtown) at the driving zoom, in the classic view
## and in perspective.
## A stand-in for a car the camera follows (the driving view shots).
class ViewDrive extends Node3D:
	var body: CharacterBody3D
	func focus_node() -> Node3D:
		return body


func _views(game) -> void:
	var city = game.city
	var midtown := Vector3.ZERO
	for d in city.districts:
		if d.get("id", "") == "midtown":
			var c: Vector2 = (d.rect as Rect2).get_center() - city.map_origin
			midtown = Vector3(c.x, 0, c.y)
	var spots := [
		["aurum", city.landmark_front("aurum_tower"), [26.0, 62.0]],
		["midtown", city.node_pos(city.nearest_node(midtown)), [26.0, 62.0]],
		["lantern", city.landmark_front("lantern_square"), [26.0]],
	]
	var cam = game.camera
	for spot: Array in spots:
		var pos: Vector3 = spot[1]
		city.stream_now(pos)
		game.player.global_position = pos
		game.player.reset_physics_interpolation()
		for sz: float in spot[2]:
			for mode: Array in [["classic", false], ["perspective", true]]:
				cam.perspective = mode[1]
				game.atmosphere.set_view(mode[1])
				cam.zoom_override = sz
				cam.size = sz
				cam.snap()
				await _frames(20)
				await _shot("80_%s_%d_%s.png" % [spot[0], sz, mode[0]])
	# Perspective only: a spot where the camera backs out of a tower, and
	# one where a building hides the player and the cutaway opens.
	cam.perspective = true
	game.atmosphere.set_view(true)
	cam.zoom_override = 26.0
	var space: PhysicsDirectSpaceState3D = cam.get_world_3d().direct_space_state
	var query := PhysicsPointQueryParameters3D.new()
	query.collision_mask = 1
	var base: float = 13.0 / tan(deg_to_rad(cam.PERSPECTIVE_FOV) * 0.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var win: Rect2 = city.window
	var want := {"tower": true, "hidden": true}
	for i in 900:
		if want.is_empty():
			break
		var at := Vector3(rng.randf_range(win.position.x, win.end.x), 0, rng.randf_range(win.position.y, win.end.y))
		if not str(city.district_at(at).get("id", "")) in ["gilt_district", "midtown"]:
			continue
		city.stream_now(at)
		await _frames(1)
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3(0, 200, 0), at + Vector3(0, 0.3, 0), 1)).is_empty():
			continue
		query.position = at + cam.global_basis.z * base
		var inside := not space.intersect_point(query, 1).is_empty()
		game.player.global_position = at
		game.player.reset_physics_interpolation()
		cam.snap()
		await _frames(3)
		var hidden: bool = cam._view_blocked(at)
		var kind := "tower" if inside and want.has("tower") else ("hidden" if hidden and want.has("hidden") else "")
		if kind == "":
			continue
		want.erase(kind)
		await _frames(30)
		await _shot("81_%s_perspective.png" % kind)
	cam.zoom_override = 0.0
	# Driving flat out (30 m/s) east and north through Midtown and past the
	# Aurum Tower: the view zooms out, leads the car and ghosts the towers in
	# the way. The player stands where the car would be.
	var body := CharacterBody3D.new()
	game.add_child(body)
	var drive := ViewDrive.new()
	drive.body = body
	game.add_child(drive)
	cam.target = drive
	for spot: Array in spots.slice(0, 2):
		for dir: Array in [["east", Vector3.RIGHT], ["north", Vector3.FORWARD]]:
			var pos: Vector3 = spot[1]
			city.stream_now(pos + dir[1] * 35.0)
			game.player.global_position = pos
			game.player.reset_physics_interpolation()
			body.global_position = pos
			body.velocity = dir[1] * 30.0
			cam.snap()
			await _frames(240)
			await _shot("82_drive_%s_%s.png" % [spot[0], dir[0]])
	# Settings > Camera turn: Follow. The view turns so the car drives up
	# the screen, sits lower at speed, and the minimap turns with it.
	cam.turn_view = true
	for shot: Array in [[spots[0], "east", Vector3.RIGHT], [spots[1], "south", Vector3.BACK], [spots[1], "west", Vector3.LEFT]]:
		var pos: Vector3 = shot[0][1]
		var dir: Vector3 = shot[2]
		city.stream_now(pos + dir * 35.0)
		game.player.global_position = pos
		game.player.reset_physics_interpolation()
		body.global_position = pos
		body.rotation.y = atan2(-dir.x, -dir.z)
		body.velocity = dir * 30.0
		cam.snap()
		await _frames(240)
		await _shot("84_turn_%s_%s.png" % [shot[0][0], shot[1]])
	# Settings > Drive zoom-out Off: flat out, the on-foot framing (the last
	# shot above at 100%).
	cam.drive_zoom = 0.0
	cam.snap()
	await _frames(240)
	await _shot("85_drive_zoom_off_%s_west.png" % spots[1][0])
	cam.drive_zoom = 1.0
	cam.turn_view = false
	cam.snap()
	cam.target = game.player
	drive.queue_free()
	body.queue_free()
	# Settings > Angle, tilt off, on foot: the same two spots from 45 to 90°.
	for spot: Array in [spots[0], spots[2]]:
		var pos: Vector3 = spot[1]
		city.stream_now(pos)
		game.player.global_position = pos
		game.player.reset_physics_interpolation()
		for angle: float in [45.0, 55.0, 65.0, 75.0, 90.0]:
			cam.set_angle(angle, false)
			cam.snap()
			await _frames(20)
			await _shot("83_angle_%s_%d.png" % [spot[0], angle])
	cam.set_angle(cam.PITCH_LOW, true)


## The 0.23 kinds from the game camera: both open cars with the top down
## and two aboard (Jules at the wheel of the roadster with a passenger, an
## AI cabriolet with its own driver and passenger), the same with the tops
## raised (nobody shows), Jules pedalling a bicycle beside a parked one,
## and the MUV between a sedan and the van.
func _convertibles(game) -> void:
	var at := Vector2(690, 470)
	var pos := Vector3(at.x, Terrain.height(at.x, at.y), at.y)
	game.city.stream_now(pos)
	game.player.global_position = pos + Vector3(0, 0, 6)
	await _frames(10)
	var made := []
	for spec in [["roadster", Vector3(-2.3, 0, 0), Vehicle.Driver.NONE, Color(0.95, 0.75, 0.1)], ["cabriolet", Vector3(2.3, 0, 0.6), Vehicle.Driver.SCRIPT, Color(0.85, 0.8, 0.7)]]:
		var car = Vehicle.new()
		car.kind = spec[0]
		car.body_color = spec[3]
		game.add_child(car)
		car.global_position = pos + spec[1]
		car.driver = spec[2]
		made.append(car)
	await _frames(2)
	made[1].convertible._company = true
	game.player.enter_vehicle(made[0])
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var friend = Npc.new()
	var look := CharacterKit.random_look(rng)
	look.erase("bag")
	friend.setup("Friend", look)
	friend.position = pos + Vector3(-5, 0, 0)
	game.add_child(friend)
	friend.mount(made[0])
	game.camera.fixed_focus = pos + Vector3(0, 0, 0.3)
	game.camera.room_size = 11.0
	game.camera.snap()
	await _frames(40)
	await _shot("95_open_cars_down.png")
	game.hud.toggle_roof()
	made[1].convertible.set_roof(true)
	await _frames(60)
	await _shot("96_open_cars_up.png")
	game.player.exit_vehicle()
	friend.dismount(pos + Vector3(-5, 0, 0))
	for car in made:
		car.queue_free()
	made.clear()
	var bike = Vehicle.new()
	bike.kind = "bicycle"
	game.add_child(bike)
	bike.global_position = pos + Vector3(0, 0, 2)
	var parked = Vehicle.new()
	parked.kind = "bicycle"
	game.add_child(parked)
	parked.global_position = pos + Vector3(1.6, 0, 1.2)
	parked.rotation.y = 0.3
	made.append_array([bike, parked])
	await _frames(2)
	game.player.enter_vehicle(bike)
	Controls.override_vector = Vector2(0, -1)
	await _frames(50)
	Controls.override_vector = null
	game.camera.fixed_focus = bike.global_position + Vector3(0.6, 0, 0)
	game.camera.room_size = 6.0
	game.camera.snap()
	await _frames(2)
	await _shot("97_bicycle.png")
	game.player.exit_vehicle()
	for car in made:
		car.queue_free()
	made.clear()
	for spec in [["sedan", -2.6, Color(0.2, 0.35, 0.7)], ["muv", 0.0, Color(0.7, 0.72, 0.75)], ["van", 2.7, Color(0.92, 0.92, 0.9)]]:
		var car = Vehicle.new()
		car.kind = spec[0]
		car.body_color = spec[2]
		game.add_child(car)
		car.global_position = pos + Vector3(spec[1], 0, 0)
		made.append(car)
	game.player.global_position = pos + Vector3(4.6, 0, 1.5)
	game.camera.fixed_focus = pos + Vector3(0.6, 0, 0.3)
	game.camera.room_size = 11.0
	game.camera.snap()
	await _frames(30)
	await _shot("98_muv_sedan_van.png")
	for car in made:
		car.queue_free()
	game.camera.fixed_focus = null
	game.camera.room_size = 0.0


## Helicopters (#82): the heliport on foot by day and at dusk (pad, H,
## lights, both helicopters), the take-off with the flying HUD, downtown
## from 30 m and 200 m, Mount Calder's slope from 60 m, and the full map's
## H marker (heli_1 to heli_7).
func _heli(game) -> void:
	var port: Dictionary = game.heliports.ports[0]
	var centre: Vector3 = port.pos
	var heli = game.heliports.helis[0]
	var side: Vector3 = centre + Vector3(0.0, 0.0, float(port.size.y) * 0.5 + 5.0).rotated(Vector3.UP, float(port.yaw))
	game.city.stream_now(centre)
	game.player.global_position = Vector3(side.x, Terrain.height(side.x, side.z), side.z)
	game.player.reset_physics_interpolation()
	game.camera.fixed_focus = centre
	game.camera.room_size = 60.0
	game.camera.snap()
	await _frames(90)
	await _shot("heli_1_pad.png")
	game.atmosphere.hour = 20.4
	await _frames(60)
	await _shot("heli_2_pad_dusk.png")
	game.atmosphere.hour = 12.5
	game.camera.fixed_focus = null
	game.camera.room_size = 0.0
	# Board and hold UP: the rotor spools, it lifts and climbs.
	game.player.global_position = heli.global_position + Vector3(4.0, 0.0, 0.0)
	game.player.reset_physics_interpolation()
	await _frames(5)
	game.player.enter_vehicle(heli)
	Input.action_press("gas")
	await _frames(240)
	await _shot("heli_3_takeoff.png")
	Input.action_release("gas")
	# The full map, opened here so it centres on the heliport's H.
	game.hud.full_map.open()
	for i in 4:
		await get_tree().process_frame
	await _shot("heli_7_map.png")
	game.hud.full_map.close()
	# Hovering over downtown, low then high, and over the mountain.
	var peak: Array = game.city.country.mountain.peaks.mount_calder
	var summit := Vector3(float(peak[0]), 0.0, float(peak[1]))
	var spawn: Vector3 = game.city.spawn_point
	var away := Vector3(spawn.x - summit.x, 0.0, spawn.z - summit.z).normalized()
	var slope := summit
	while Terrain.height(slope.x, slope.z) > 600.0 and slope.distance_to(summit) < 4000.0:
		slope += away * 10.0
	for stop: Array in [["heli_4_downtown_30m", spawn, 30.0, 180], ["heli_5_downtown_200m", spawn, 200.0, 240], ["heli_6_mountain_60m", slope, 60.0, 240]]:
		var at: Vector3 = stop[1]
		var ground: float = Terrain.height(at.x, at.z) - Terrain.drop(at.x, at.z)
		game.city.stream_now(Vector3(at.x, ground, at.z))
		heli.global_position = Vector3(at.x, ground + float(stop[2]), at.z)
		heli.rotation.y = atan2(away.x, away.z) # nose toward the summit
		heli.velocity = Vector3.ZERO
		heli.rpm = 1.0
		heli.landed = false
		heli.altitude = stop[2]
		heli.above_land = stop[2]
		heli.reset_physics_interpolation()
		game.player.global_position = heli.global_position
		game.camera.snap()
		await _frames(stop[3])
		await _shot(stop[0] + ".png")


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(file))
	print("saved ", file)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
