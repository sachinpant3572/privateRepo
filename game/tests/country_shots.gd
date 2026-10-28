extends Node
## Screenshots of the country round Bellerive (phase 2): suburbs past the
## plan's edge, Brisa Beach, the towns, farms, bayou, bridges, the storm
## barricades and the play area's fence, by day and at night. Needs a real
## renderer:
##   xvfb-run godot --rendering-driver opengl3 res://tests/country_shots.tscn -- <out_dir>

const MainScene = preload("res://main.tscn")

## [file, local x (or a country landmark id), local z, view size (metres
## tall), hour].
const VIEWS := [
	["c01_west_edge", -150.0, 116.0, 60.0, 12.5],
	["c02_heights", -380.0, 300.0, 70.0, 12.5],
	["c03_brisa_deco_row", 1634.0, 1660.0, 70.0, 12.5],
	["c04_cruise_terminal", "cruise_terminal", 0.0, 110.0, 12.5],
	["c05_bellerive_general", "bellerive_general", 0.0, 90.0, 12.5],
	["c06_wheaton", -1550.0, -1750.0, 90.0, 12.5],
	["c07_hollis_farm", "hollis_farm", 0.0, 110.0, 12.5],
	["c08_larkspur_vineyard", "larkspur_vineyard", 0.0, 110.0, 12.5],
	["c09_gator_farm", "gator_farm", 0.0, 90.0, 12.5],
	["c10_route1_bridge", -3480.0, 820.0, 80.0, 12.5],
	["c11_storm_barricade", 2795.0, -1811.0, 50.0, 12.5],
	["c12_fence", -434.0, -2210.0, 60.0, 12.5],
	["c13_grain_elevators", "grain_elevators", 0.0, 90.0, 12.5],
	["c14_bank", -3630.0, 707.0, 60.0, 12.5],
	["c15_brisa_night", 1634.0, 1660.0, 70.0, 21.5],
	["c16_wheaton_night", -1550.0, -1750.0, 90.0, 21.5],
	# Plots (HANDOFF-plots.md): estates, clusters, farmyards, fields.
	["c17_hale_estate", "hale_estate", 0.0, 120.0, 12.5],
	["c18_heights_estate", -160.0, -1.0, 110.0, 12.5],
	["c19_villa_turned", 2221.0, -497.0, 110.0, 12.5],
	["c20_bayou_town", -200.0, 600.0, 110.0, 12.5],
	["c21_larkspur", 2350.0, -900.0, 130.0, 12.5],
	["c22_cypress_bend", -2620.0, 980.0, 120.0, 12.5],
	["c23_farmyard", -1870.0, -1300.0, 130.0, 12.5],
	["c24_fields", -1250.0, -2000.0, 170.0, 12.5],
	# The expanded suburbs (BX-5): the east side's cheap blocks, liquor
	# store and burned lot, the Heights' exec houses and an estate
	# gatehouse, Brisa's residential towers and the shore's midrise condos.
	["c25_eastside_blocks", 1870.0, -200.0, 90.0, 12.5],
	["c26_exec_houses", -185.0, 256.0, 90.0, 12.5],
	["c27_gatehouse", -450.0, 455.0, 70.0, 12.5],
	["c28_res_towers", 1650.0, 1718.0, 110.0, 12.5],
	["c29_midrise_condos", -131.0, 1930.0, 90.0, 12.5],
]

var out_dir := "user://"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0]
	_run.call_deferred()


func _run() -> void:
	var game = MainScene.instantiate()
	game.settings["camera_turn"] = "north"
	game.missions_enabled = false
	game.save_enabled = false
	add_child(game)
	game.atmosphere.minutes_per_second = 0.0
	game.atmosphere.weather_changes = false
	await _frames(30)
	var only := OS.get_environment("ONLY")
	for v in VIEWS:
		if only != "" and not (v[0] as String) in only.split(","):
			continue
		# A view on a country landmark follows its lot.
		var at: Vector3 = game.city.country.landmark(v[1]).pos if v[1] is String else Vector3(v[1], 0.0, v[2])
		game.atmosphere.hour = v[4]
		game.player.global_position = at + Vector3(0, 0.5, 0)
		game.city.stream_now(at)
		game.camera.fixed_focus = at
		game.camera.room_size = v[3]
		game.camera.size = v[3]
		game.camera.snap()
		await _frames(40)
		await _shot(v[0] + ".png")
	get_tree().quit()


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))
	print("saved ", file)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
