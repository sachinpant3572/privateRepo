extends Node
## Records a short demo of the camera options (HANDOFF-camera-demo.md):
## walking, driving and flying, each seen by the classic top-down camera,
## the same camera in perspective, and a third-person 3D camera.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 \
##     --resolution 1280x720 --write-movie /tmp/demo/demo.avi --fixed-fps 30 \
##     res://tests/camera_demo.tscn
## It prints "clip <name> <frame>" at each clip's first frame, for cutting.

const MainScene = preload("res://main.tscn")
const Terrain = preload("res://scripts/terrain.gd")
const Vehicle = preload("res://scripts/vehicle.gd")
const ChaseCamera = preload("res://scripts/chase_camera.gd")
const MeshBuilder = preload("res://scripts/mesh_builder.gd")
const City = preload("res://scripts/city.gd")
const Country = preload("res://scripts/country.gd")

const FPS := 30
## DEMO_SECONDS shortens the clips for a trial run.
var SECONDS := float(OS.get_environment("DEMO_SECONDS")) if OS.get_environment("DEMO_SECONDS") != "" else 8.0
const VIEWS := [
	["classic", "Now: top-down"],
	["perspective", "Option 1: perspective top-down"],
	["chase", "Option 2: full 3D"],
]
## The plane's loop round downtown: radius, height above ground, speed.
const ORBIT_R := 320.0
const ORBIT_UP := 150.0
const ORBIT_SPEED := 42.0


## A stand-in the classic camera follows (it asks its target for the node
## to frame).
class Follow extends Node3D:
	var subject: Node3D
	func focus_node() -> Node3D:
		return subject


class Aircraft extends Node3D:
	var velocity := Vector3.ZERO


var game
var chase
var follow: Follow
var card: ColorRect
var card_text: Label
var caption: Label
var frame := 0


func _ready() -> void:
	_run.call_deferred()


func _process(_delta: float) -> void:
	frame += 1


func _run() -> void:
	game = MainScene.instantiate()
	game.missions_enabled = false
	add_child(game)
	game.atmosphere.hour = 12.5
	game.atmosphere.minutes_per_second = 0.0
	game.atmosphere.weather_changes = false
	chase = ChaseCamera.new()
	add_child(chase)
	follow = Follow.new()
	add_child(follow)
	_make_overlay()
	await _wait(1.0)
	for activity: String in ["walking", "driving", "flying"]:
		for view: Array in VIEWS:
			await _clip(activity, view[0], "%s  ·  %s" % [view[1], activity])
	print("demo done")
	get_tree().quit()


func _clip(activity: String, view: String, label: String) -> void:
	card.visible = true
	card_text.text = label.replace("  ·  ", "\n")
	caption.text = label
	var far_view := view == "chase"
	var radius := 105.0
	if activity == "flying":
		radius = ORBIT_R + (420.0 if far_view else 220.0)
	elif far_view:
		radius = 330.0
	elif view == "perspective":
		radius = 170.0
	City.LOAD_RADIUS = radius
	City.UNLOAD_RADIUS = radius + 60.0
	Country.LOAD_RADIUS = radius + 25.0
	Country.UNLOAD_RADIUS = radius + 100.0
	var cam = game.camera
	cam.perspective = view == "perspective"
	cam.zoom_override = 110.0 if activity == "flying" else 0.0
	cam.far = 1400.0 if activity == "flying" else 340.0
	_fog(far_view, activity == "flying")
	var p = game.player
	var subject: Node3D
	var mover: Callable
	match activity:
		"walking":
			var f: Transform3D = game.city.landmark_frame("lantern_square")
			var a: Vector3 = f * Vector3(-16, 0, 0)
			var b: Vector3 = f * Vector3(20, 0, 0)
			p.process_mode = Node.PROCESS_MODE_INHERIT
			p.visible = true
			p.global_position = a + Vector3(0, Terrain.height(a.x, a.z), 0)
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			game.city.focus_node = p
			subject = p
			mover = func() -> void:
				var to: Vector3 = b - p.global_position
				to.y = 0.0
				Controls.override_vector = Controls.screen_from_world(to.normalized()) if to.length() > 1.0 else Vector2.ZERO
		"driving":
			subject = _spawn_car()
			_park_player()
			game.city.focus_node = subject
			mover = func() -> void: pass
		"flying":
			var plane := _make_plane()
			var centre: Vector3 = game.city.landmark_front("aurum_tower")
			var anchor := Node3D.new()
			add_child(anchor)
			anchor.global_position = centre
			game.city.focus_node = anchor
			_park_player()
			subject = plane
			var t0 := [0.0]
			mover = func() -> void:
				t0[0] += 1.0 / FPS
				_fly(plane, centre, t0[0])
			_fly(plane, centre, 0.0)
	follow.subject = subject
	game.camera.target = p if activity == "walking" else follow
	if far_view:
		chase.follow(subject, [6.5, 9.5, 22.0][["walking", "driving", "flying"].find(activity)], [2.6, 3.6, 7.0][["walking", "driving", "flying"].find(activity)], [1.4, 1.2, 1.5][["walking", "driving", "flying"].find(activity)])
		chase.current = true
		cam.set_process(false)
		MeshBuilder.cutaway_material().set_shader_parameter("cut_radius", 0.001)
	else:
		cam.set_process(true)
		cam.current = true
	game.city.stream_now(subject.global_position)
	cam.snap()
	# Settle behind the title card, then roll.
	var settle := 0
	while settle < FPS * 2:
		# The walker and the car hold still while the card is up; the plane
		# is already flying.
		if activity == "flying":
			mover.call()
		elif activity == "walking":
			Controls.override_vector = Vector2.ZERO
		await get_tree().process_frame
		settle += 1
	card.visible = false
	print("clip %s_%s %d" % [activity, view, frame])
	if activity == "driving":
		_drive(subject)
	for i in int(SECONDS * FPS):
		mover.call()
		await get_tree().process_frame
	Controls.override_vector = null
	if activity != "walking":
		subject.queue_free()
	_fog(false, false)


## A red sports car in the near lane of a downtown avenue, its route ahead.
func _spawn_car():
	var city = game.city
	var a: int = city.nearest_node(Vector3(380, 0, 140))
	var b: int = city.nearest_node(Vector3(820, 0, 140))
	var nodes: PackedInt64Array = city.route_nodes(city.node_pos(a), city.node_pos(b))
	var car = Vehicle.new()
	car.kind = "sports"
	car.body_color = Color(0.82, 0.16, 0.16)
	car.city = city
	car.position = city.lane_start(nodes[0], nodes[1])
	var heading: Vector3 = city.node_pos(nodes[1]) - city.node_pos(nodes[0])
	car.rotation.y = atan2(-heading.x, -heading.z)
	game.add_child(car)
	car.set_meta("route", city.route_lanes(city.node_pos(a), city.node_pos(b)))
	return car


func _drive(car) -> void:
	car.drive_path(car.get_meta("route"), 0.9)


func _park_player() -> void:
	var p = game.player
	Controls.override_vector = Vector2.ZERO
	p.visible = false
	p.process_mode = Node.PROCESS_MODE_DISABLED


## The plane's place on its loop at time t: banked into the turn, nose
## along the loop.
func _fly(plane: Aircraft, centre: Vector3, t: float) -> void:
	var w := ORBIT_SPEED / ORBIT_R
	var a := -0.6 + w * t
	var pos := centre + Vector3(cos(a), 0.0, sin(a)) * ORBIT_R
	pos.y = Terrain.height(pos.x, pos.z) + ORBIT_UP
	var dir := Vector3(-sin(a), 0.0, cos(a))
	plane.velocity = dir * ORBIT_SPEED
	plane.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP).rotated(dir, 0.35), pos)


## A light plane from boxes: white with a red stripe, about
## 16 m across the wings.
func _make_plane() -> Aircraft:
	var mb := MeshBuilder.new()
	var white := Color(0.94, 0.94, 0.92)
	var red := Color(0.8, 0.12, 0.12)
	var glass := Color(0.15, 0.2, 0.28)
	mb.box(Vector3(0, 0, 0), Vector3(1.6, 1.6, 10.0), white)
	mb.box(Vector3(0, 0, -5.4), Vector3(1.1, 1.1, 0.9), white)
	mb.box(Vector3(0, 0.55, -2.4), Vector3(1.4, 0.7, 2.0), glass)
	mb.box(Vector3(0, -0.1, -0.2), Vector3(1.64, 0.3, 9.0), red)
	mb.box(Vector3(0, 0.25, -1.4), Vector3(16.0, 0.22, 2.2), white)
	mb.box(Vector3(-7.4, 0.26, -1.4), Vector3(1.2, 0.24, 2.24), red)
	mb.box(Vector3(7.4, 0.26, -1.4), Vector3(1.2, 0.24, 2.24), red)
	mb.box(Vector3(0, 0.3, 4.6), Vector3(5.2, 0.16, 1.4), white)
	mb.box(Vector3(0, 1.3, 4.7), Vector3(0.18, 2.2, 1.5), red)
	mb.box(Vector3(0, 0, -5.95), Vector3(2.8, 0.18, 0.06), Color(0.15, 0.15, 0.15))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.commit()
	mi.material_override = MeshBuilder.material()
	var plane := Aircraft.new()
	plane.add_child(mi)
	add_child(plane)
	return plane


## Depth fog that hides where streaming stops, for the far-seeing camera.
func _fog(on: bool, flying: bool) -> void:
	var env: Environment = game.atmosphere.env
	env.fog_enabled = on
	if on:
		env.fog_mode = Environment.FOG_MODE_DEPTH
		env.fog_density = 1.0
		env.fog_light_color = env.background_color
		env.fog_depth_begin = 380.0 if flying else 160.0
		env.fog_depth_end = 820.0 if flying else 360.0


func _make_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	card = ColorRect.new()
	card.color = Color(0.05, 0.06, 0.08, 1.0)
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(card)
	card_text = Label.new()
	card_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card_text.add_theme_font_size_override("font_size", 46)
	card.add_child(card_text)
	caption = Label.new()
	caption.set_anchors_preset(Control.PRESET_CENTER_TOP)
	caption.position = Vector2(-400, 64)
	caption.size = Vector2(800, 40)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 26)
	caption.add_theme_constant_override("outline_size", 8)
	caption.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	layer.add_child(caption)


func _wait(seconds: float) -> void:
	for i in int(seconds * FPS):
		await get_tree().process_frame
