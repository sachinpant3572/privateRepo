extends Node3D
## Entry point: builds the Bellerive demo map and wires the player, camera,
## police, population, story missions, places and HUD together. Handles
## BUSTED and WASTED, cash, the bag and settings.

const City = preload("res://scripts/city.gd")
const Country = preload("res://scripts/country.gd")
const Player = preload("res://scripts/player.gd")
const Vehicle = preload("res://scripts/vehicle.gd")
const TopDownCamera = preload("res://scripts/top_down_camera.gd")
const PoliceManager = preload("res://scripts/police_manager.gd")
const Population = preload("res://scripts/population.gd")
const Hud = preload("res://scripts/hud.gd")
const Atmosphere = preload("res://scripts/atmosphere.gd")
const MissionManager = preload("res://scripts/missions/mission_manager.gd")
const Interiors = preload("res://scripts/interiors.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Taxi = preload("res://scripts/taxi.gd")
const Graphics = preload("res://scripts/graphics.gd")
const GameLog = preload("res://scripts/game_log.gd")

const RESPAWN_DELAY := 2.5

var population_enabled := true
## Tests turn the story off (or point it at a throwaway save).
var missions_enabled := true
var save_enabled := true
var city
var player
var camera
var police
var population
var hud
var atmosphere
var graphics
var missions
var interiors
var taxi
## The game log (Settings > Game > Log).
var game_log
var inventory = Inventory.new()
var respawning := false
var cash := 0
var settings := {"shadows": true, "show_fps": true, "weather": "auto", "detail": "high", "controls": "stick", "view": "perspective", "zoom": 1.0, "angle": 65.0, "auto_tilt": true, "camera_turn": "car", "drive_zoom": 1.0, "fps_limit": 120, "quality": "high", "bloom": true, "aa": false, "vivid": true, "real_lights": true, "log": true, "log_button": true, "blood": true}
## Settings > Graphics > FPS limit.
const FPS_LIMITS := [30, 60, 75, 90, 120]
## Player-set map waypoint (a road node position) or null.
var waypoint = null


func _ready() -> void:
	add_to_group("game")
	# First, so it hears errors while the world builds.
	game_log = GameLog.new()
	game_log.game = self
	add_child(game_log)
	atmosphere = Atmosphere.new()
	add_child(atmosphere)
	graphics = Graphics.new()
	graphics.game = self
	add_child(graphics)

	city = City.new()
	add_child(city)
	city.build(1234)
	atmosphere.night_changed.connect(city.set_glow_visible)
	city.set_glow_visible(atmosphere.night_amount() > 0.02)

	missions = MissionManager.new()
	missions.game = self
	missions.save_enabled = save_enabled and missions_enabled
	missions.auto_start = missions_enabled
	add_child(missions)
	if not missions_enabled:
		missions.process_mode = Node.PROCESS_MODE_DISABLED
	var start: Vector3 = missions.spawn_point() if missions_enabled else city.spawn_point

	# The car waiting outside Union Station (or home, once the story has
	# begun); population parks the rest.
	var home = Vehicle.new()
	home.kind = "sports"
	home.body_color = Color(0.82, 0.16, 0.16)
	home.city = city
	home.position = city.parked_spots[0][0]
	home.rotation.y = city.parked_spots[0][1]
	if start != city.spawn_point:
		home.position = city.landmark_curb("moreau_house", 8.0)
		home.rotation.y = city.curb_yaw(city.landmark_block("moreau_house"))
	add_child(home)

	player = Player.new()
	player.position = start
	player.rotation.y = PI
	add_child(player)
	city.focus_node = player
	atmosphere.focus = player
	player.died.connect(func(_who): _respawn("WASTED", city.hospital))
	if start != city.spawn_point:
		city.stream_now(start)

	camera = TopDownCamera.new()
	camera.target = player
	add_child(camera)
	camera.snap()
	Controls.camera = camera
	city.view_source = camera
	Fx.camera = camera

	police = PoliceManager.new()
	police.game = self
	add_child(police)

	population = Population.new()
	population.game = self
	population.enabled = population_enabled
	add_child(population)

	interiors = Interiors.new()
	interiors.game = self
	add_child(interiors)

	taxi = Taxi.new()
	taxi.game = self
	add_child(taxi)

	hud = Hud.new()
	hud.game = self
	add_child(hud)
	missions.hud = hud
	apply_settings()
	if missions_enabled and missions.is_new_game():
		missions.start.call_deferred("m01_homecoming")


func apply_settings() -> void:
	atmosphere.sun.shadow_enabled = settings.get("shadows", true)
	# Low detail: flat colours (no grain or puddles) and lighter rain.
	var high: bool = settings.get("detail", "high") == "high"
	RenderingServer.global_shader_parameter_set("detail", 1.0 if high else 0.0)
	atmosphere.low_detail = not high
	var w: String = settings.get("weather", "auto")
	atmosphere.weather_changes = w == "auto"
	if w != "auto":
		# Changed while paused (the settings page), it changes at once so the
		# preview shows it.
		atmosphere.set_weather(w, get_tree().paused and w != atmosphere.weather)
	var persp: bool = str(settings.get("view", "perspective")) != "classic"
	camera.perspective = persp
	atmosphere.set_view(persp)
	# Zoomed out or tipped flatter, the city and country load further round
	# the player.
	var z = settings.get("zoom", 1.0)
	camera.zoom = float(z) if (z is float or z is int) and camera.ZOOMS.has(float(z)) else 1.0
	var dz = settings.get("drive_zoom", 1.0)
	camera.drive_zoom = float(dz) if (dz is float or dz is int) and camera.DRIVE_ZOOMS.has(float(dz)) else 1.0
	var a = settings.get("angle", 65.0)
	var t = settings.get("auto_tilt", true)
	camera.set_angle(float(a) if (a is float or a is int) and camera.ANGLES.has(float(a)) else camera.PITCH_LOW, t if t is bool else true)
	# Camera turn: follow (behind the car, Chinatown Wars; along the walk),
	# 90° turns (only whole corners) or north up. A change eases round.
	var mode := str(settings.get("camera_turn", "car"))
	var turn := mode != "north"
	var steps := mode == "steps"
	if turn != camera.turn_view or steps != camera.turn_steps:
		camera.turn_view = turn
		camera.turn_steps = steps
		camera.recenter()
	var reach := maxf(camera.zoom, 1.0)
	# A camera flatter than 65 degrees sees further up the screen. Turning
	# with the car it widens and flattens at speed, up the short side.
	if persp:
		var pitch: float = camera.base_pitch - (camera.TURN_FLATTEN if turn else 0.0)
		reach *= maxf(1.0, sin(deg_to_rad(camera.PITCH_LOW)) / sin(deg_to_rad(maxf(pitch, camera.ANGLES[0]))))
		if turn:
			reach *= camera.TURN_DRIVE_SIZE / camera.DRIVE_SIZE
	City.LOAD_RADIUS = 105.0 * reach
	City.UNLOAD_RADIUS = 150.0 * reach
	Country.LOAD_RADIUS = 130.0 * reach
	Country.UNLOAD_RADIUS = 210.0 * reach
	graphics.apply(settings)
	Fx.set_blood(settings.get("blood", true) != false)
	var scheme: String = settings.get("controls", "stick")
	Controls.scheme = scheme if Controls.SCHEMES.has(scheme) else "stick"
	# Headless runs (tests, tools) go flat out.
	Engine.max_fps = 0 if DisplayServer.get_name() == "headless" else fps_limit()
	if missions:
		missions.save_game()
	game_log.settings_applied(settings)


## The saved FPS limit, or 120 if it isn't one of FPS_LIMITS.
func fps_limit() -> int:
	var f = settings.get("fps_limit", 120)
	return int(f) if (f is int or f is float) and FPS_LIMITS.has(int(f)) else 120


## After "New game": back to Union Station and the first mission.
func restart_story() -> void:
	interiors.force_out()
	if player.vehicle != null:
		player.exit_vehicle()
	city.stream_now(city.spawn_point)
	player.respawn(city.spawn_point)
	camera.snap()
	population.refill()
	if missions_enabled:
		missions.start("m01_homecoming")


## Everything the minimap and full map should mark: [{pos, color, label,
## gps}]. The first entry with gps gets the GPS route.
func map_markers() -> Array:
	var list: Array = []
	if waypoint != null:
		list.append({"pos": waypoint, "color": Color(0.85, 0.4, 0.95), "label": "Waypoint", "gps": true})
	if missions:
		list.append_array(missions.markers)
	if taxi:
		list.append_array(taxi.map_markers())
	return list


## Eats the best snack in the bag (HUD SNACK button or H). False when the
## bag is empty or health is full.
func eat_snack() -> bool:
	if player.dead or player.health >= player.max_health:
		return false
	var id: String = inventory.take_best()
	if id == "":
		return false
	player.health = minf(player.max_health, player.health + Inventory.ITEMS[id].heal)
	if player.vehicle == null and player.gesture == "":
		player.gesture = "eat"
		get_tree().create_timer(1.5).timeout.connect(func():
			if player.gesture == "eat" and not player.sitting:
				player.gesture = "")
	missions.save_game()
	return true


func on_busted() -> void:
	_respawn("BUSTED", city.police_station)


func _respawn(text: String, point: Vector3) -> void:
	if respawning:
		return
	respawning = true
	GameLog.event("respawn", {"why": text})
	player.controllable = false
	hud.show_message(text)
	missions.on_player_down(text)
	await get_tree().create_timer(RESPAWN_DELAY, true, true).timeout
	interiors.force_out()
	Wanted.clear()
	police.clear_all()
	city.stream_now(point)
	player.respawn(point)
	camera.snap()
	population.refill()
	respawning = false
