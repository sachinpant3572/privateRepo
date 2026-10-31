extends Node3D
## Wildlife gallery: the five animal models drawn by the real Wildlife node
## (MultiMesh and gait shader) for art review. Needs a real renderer:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 \
##     --resolution 1280x720 res://tests/wildlife_gallery.tscn -- <out_dir> [mode] [model filter]
## Modes: "all" (default) = per model a side row of poses (ortho) and a
## row from the game's camera, then the game-camera scenes by day and night;
## "models" = the per-model shots only; "scenes" = the game-camera scenes only.
## A row's poses: standing, grazing, walk, trot, gallop, dead.

const Wildlife = preload("res://scripts/wildlife.gd")
const AnimalKit = preload("res://scripts/kits/animal_kit.gd")
const MeshBuilder = preload("res://scripts/mesh_builder.gd")

const DAY := {
	"sky": Color(0.55, 0.7, 0.85), "ambient": Color(0.78, 0.8, 0.88), "ambient_energy": 0.35,
	"sun": Color(1.0, 0.97, 0.9), "sun_energy": 0.7, "night": 0.0,
}
const NIGHT := {
	"sky": Color(0.06, 0.08, 0.15), "ambient": Color(0.5, 0.52, 0.72), "ambient_energy": 0.62,
	"sun": Color(0.6, 0.68, 1.0), "sun_energy": 0.28, "night": 1.0,
}
const GROUND := Color(0.36, 0.42, 0.27)

## Poses of a row: [label, state, amp, phase, head, tail, dead].
const POSES := [
	["stand", "idle", 0.0, 0.0, -0.15, 0.0, false],
	["graze", "graze", 0.0, 0.0, 1.0, 0.0, false],
	["walk", "idle", 0.3, 0.25, 0.0, 0.0, false],
	["trot", "idle", 0.62, 0.1, 0.0, 0.0, false],
	["gallop", "flee", 1.0, 0.4, 0.0, 1.0, false],
	["dead", "dead", 0.0, 0.0, 0.0, 0.0, true],
]

## Stand-in for the Atmosphere: what Wildlife reads.
class Stub extends Node:
	var hour := 12.0
	var weather := "clear"
	var indoors := false
	var focus: Node3D
	var wildlife: Node

var out_dir := "user://"
var camera := Camera3D.new()
var sun := DirectionalLight3D.new()
var env := Environment.new()
var stub := Stub.new()
var wild: Node
## Each row and scene stands at its own z, so the blood of one row's dead
## animal does not show under the next.
var _o := Vector3.ZERO
var _row := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var mode: String = args[1] if args.size() > 1 else "all"
	var only: String = args[2] if args.size() > 2 else ""
	_setup_world()
	_run.call_deferred(mode, only)


func _run(mode: String, only: String) -> void:
	if mode == "all" or mode == "models":
		for model: String in AnimalKit.MODELS:
			if only != "" and not model.contains(only):
				continue
			await _model_shots(model)
	if mode == "all" or mode == "scenes":
		await _scene(false)
		await _scene(true)
	get_tree().quit()


func _setup_world() -> void:
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 200.0
	add_child(sun)
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.85
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var ground := MeshBuilder.new()
	ground.box(Vector3(0, -0.1, 0), Vector3(800, 0.2, 800), GROUND)
	add_child(ground.make_instance())
	camera.near = 0.2
	camera.far = 600.0
	add_child(camera)
	var focus := Node3D.new()
	add_child(focus)
	stub.focus = focus
	add_child(stub)
	wild = Wildlife.attach(stub)
	wild.set_process(false)
	_light(DAY)


func _light(look: Dictionary) -> void:
	env.background_color = look.sky
	env.ambient_light_color = look.ambient
	env.ambient_light_energy = look.ambient_energy
	sun.light_color = look.sun
	sun.light_energy = look.sun_energy
	RenderingServer.global_shader_parameter_set("night", look.night)
	RenderingServer.global_shader_parameter_set("wet", 0.0)
	RenderingServer.global_shader_parameter_set("sky_tint", (look.sky as Color).lerp(Color(0.6, 0.7, 0.85), 0.4))


func _clear() -> void:
	for i in range(wild.animals.size() - 1, -1, -1):
		wild._remove(i)


## An animal of `model` (kind found from the model) standing at `pos`.
func _put(model: String, pos: Vector3, yaw: float, pose: Array) -> Dictionary:
	var kind: String = {"doe": "deer", "buck": "deer", "rabbit": "rabbit", "coyote": "coyote", "lion": "lion"}[model]
	var a: Dictionary = wild._make(kind, model, pos + _o, null)
	a.size = 1.0
	a.yaw = yaw
	a.state = pose[1]
	a.amp = pose[2]
	a.phase = pose[3]
	a.head = pose[4]
	a.tail = pose[5]
	wild.animals.append(a)
	if pose[6]:
		wild.kill(a, Vector3(1.0, 0.0, 0.0), "other")
		a.roll = 1.0
		a.side = 1.0
	return a


func _model_shots(model: String) -> void:
	var spec: Dictionary = AnimalKit.spec(model)
	var step: float = float(spec.length) * float(spec.scale) * 1.55 + 0.3
	var n := POSES.size()
	var width := step * n
	_light(DAY)
	_clear()
	_next_row()
	for i in n:
		# A line nose to tail along x, all facing -x: a profile for every one.
		var x := (i - (n - 1) * 0.5) * step
		_put(model, Vector3(x, 0.0, 0.0), PI * 0.5, POSES[i])
	wild._push()
	var height := maxf(width / 1.78 * 1.06, 2.0)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = height
	camera.rotation_degrees = Vector3(-8.0, 0.0, 0.0)
	# Aimed at the row's middle: the pitch would otherwise shift an orthographic view.
	camera.global_position = _o + Vector3(0.0, 0.45, 0.0) + camera.global_basis.z * 30.0
	await _snap("wild_%s_1_side.png" % model)
	# The same row from above at the game camera's distance.
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 35.0
	camera.rotation_degrees = Vector3(-60.0, 0.0, 0.0)
	camera.global_position = _o + Vector3(0.0, 0.0, 0.0) + camera.global_basis.z * 28.0
	await _snap("wild_%s_2_game.png" % model)
	# Close, three-quarter, from the front.
	camera.fov = 40.0
	camera.rotation_degrees = Vector3(-30.0, -35.0, 0.0)
	var mid := Vector3((1 - (n - 1) * 0.5) * step, 0.4, 0.0)
	camera.global_position = _o + mid + camera.global_basis.z * (step * 3.2 + 2.0)
	await _snap("wild_%s_3_close.png" % model)


## A hill scene under the game's camera, by day or by night.
func _scene(night: bool) -> void:
	_light(NIGHT if night else DAY)
	_clear()
	_next_row()
	var graze: Array = POSES[1]
	var stand: Array = POSES[0]
	var walk: Array = POSES[2]
	var trot: Array = POSES[3]
	var run: Array = POSES[4]
	var down: Array = POSES[5]
	if not night:
		_put("buck", Vector3(-6.0, 0.0, -2.0), 0.6, stand)
		_put("doe", Vector3(-9.0, 0.0, 0.5), 0.2, graze)
		_put("doe", Vector3(-4.0, 0.0, 3.0), 2.4, walk)
		_put("doe", Vector3(-8.0, 0.0, -5.0), -0.8, graze)
		_put("rabbit", Vector3(2.0, 0.0, 1.0), 1.0, graze)
		_put("rabbit", Vector3(4.0, 0.0, -3.0), -2.0, run)
		_put("doe", Vector3(8.0, 0.0, 2.0), -1.3, down)
	else:
		_put("coyote", Vector3(-3.0, 0.0, 0.0), 0.5, trot)
		_put("coyote", Vector3(-6.0, 0.0, 2.5), 0.9, trot)
		_put("coyote", Vector3(-5.0, 0.0, -3.0), 0.2, stand)
		_put("lion", Vector3(5.0, 0.0, 1.0), -1.4, walk)
		_put("lion", Vector3(9.0, 0.0, -3.0), 2.6, stand)
		_put("rabbit", Vector3(1.0, 0.0, 4.0), 1.0, graze)
	wild._push()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 35.0
	camera.rotation_degrees = Vector3(-60.0, 0.0, 0.0)
	camera.global_position = _o + Vector3(0.0, 0.0, 0.0) + camera.global_basis.z * 26.0
	await _snap("wild_scene_%s_game.png" % ("night" if night else "day"))
	camera.fov = 35.0
	camera.rotation_degrees = Vector3(-24.0, 20.0, 0.0)
	camera.global_position = _o + Vector3(0.0, 1.0, 0.0) + camera.global_basis.z * 20.0
	await _snap("wild_scene_%s_low.png" % ("night" if night else "day"))


func _next_row() -> void:
	_row += 1
	_o = Vector3(0.0, 0.0, -40.0 * _row)


func _snap(file: String) -> void:
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))
	print("saved ", file)
