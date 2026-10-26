extends Node3D
## Prototype entry point: builds the grey-box district and wires the player,
## camera, police, population and HUD together. Handles BUSTED and WASTED.

const City = preload("res://scripts/city.gd")
const Player = preload("res://scripts/player.gd")
const Vehicle = preload("res://scripts/vehicle.gd")
const TopDownCamera = preload("res://scripts/top_down_camera.gd")
const PoliceManager = preload("res://scripts/police_manager.gd")
const Population = preload("res://scripts/population.gd")
const Hud = preload("res://scripts/hud.gd")

const RESPAWN_DELAY := 2.5

var population_enabled := true
var city
var player
var camera
var police
var population
var hud
var respawning := false


func _ready() -> void:
	add_to_group("game")
	_setup_environment()

	city = City.new()
	add_child(city)
	city.build(1234)

	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for spot in city.parked_spots:
		var car = Vehicle.new()
		car.body_color = Vehicle.COLORS[rng.randi() % Vehicle.COLORS.size()]
		car.city = city
		car.position = spot[0]
		car.rotation.y = spot[1]
		add_child(car)

	player = Player.new()
	player.position = city.spawn_point
	player.rotation.y = PI * 0.75
	add_child(player)
	player.died.connect(func(_who): _respawn("WASTED", city.hospital))

	camera = TopDownCamera.new()
	camera.target = player
	add_child(camera)
	camera.snap()
	Controls.camera = camera

	police = PoliceManager.new()
	police.game = self
	add_child(police)

	population = Population.new()
	population.game = self
	population.enabled = population_enabled
	add_child(population)

	hud = Hud.new()
	hud.game = self
	add_child(hud)


func on_busted() -> void:
	_respawn("BUSTED", city.police_station)


func _respawn(text: String, point: Vector3) -> void:
	if respawning:
		return
	respawning = true
	player.controllable = false
	hud.show_message(text)
	await get_tree().create_timer(RESPAWN_DELAY, true, true).timeout
	Wanted.clear()
	police.clear_all()
	player.respawn(point)
	camera.snap()
	respawning = false


func _setup_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	sun.light_energy = 0.7
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 110.0
	add_child(sun)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.7, 0.85)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.8, 0.88)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
