extends Camera3D
## Follow camera with two looks over the same 3D world:
## ISOMETRIC (default) shows building fronts at the classic 45° angle;
## CLASSIC looks steeply down with north up, like the old Java-era games.
## Switching eases between the two. Leads ahead of a moving car and zooms
## out with speed. The choice is remembered between sessions.

enum Mode { ISOMETRIC, CLASSIC }

const MeshBuilder = preload("res://scripts/mesh_builder.gd")

const DISTANCE := 60.0
const FOOT_SIZE := 26.0
const DRIVE_SIZE := 38.0
const SETTINGS_PATH := "user://settings.cfg"
## Pitch and yaw in degrees. CLASSIC stops short of straight down so building
## fronts still show a little, as in the old games.
const ANGLES := {
	Mode.ISOMETRIC: Vector3(-35.264, 45.0, 0.0),
	Mode.CLASSIC: Vector3(-72.0, 0.0, 0.0),
}

var target: Node3D
var mode := Mode.ISOMETRIC
var _focus := Vector3.ZERO
var _goal := Quaternion.IDENTITY


func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	size = FOOT_SIZE
	near = 1.0
	far = 200.0
	current = true
	var settings := ConfigFile.new()
	if settings.load(SETTINGS_PATH) == OK:
		mode = settings.get_value("camera", "mode", Mode.ISOMETRIC)
	set_mode(mode, true)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("camera"):
		toggle()
	if target == null:
		return
	quaternion = quaternion.slerp(_goal, 1.0 - exp(-8.0 * delta))
	var node: Node3D = target.focus_node()
	var pos := node.get_global_transform_interpolated().origin
	var want_size := FOOT_SIZE
	var lead := Vector3.ZERO
	if node != target:
		var v: Vector3 = node.velocity
		lead = v * 0.35
		want_size = lerpf(FOOT_SIZE, DRIVE_SIZE, clampf(v.length() / 24.0, 0.0, 1.0))
	_focus = _focus.lerp(pos + lead, 1.0 - exp(-6.0 * delta))
	size = lerpf(size, want_size, 1.0 - exp(-2.0 * delta))
	global_position = _focus + global_basis.z * DISTANCE
	_update_cutaway(pos)


## Points the city's see-through hole at the player for this frame's view.
func _update_cutaway(player_pos: Vector3) -> void:
	var mat := MeshBuilder.cutaway_material()
	mat.set_shader_parameter("focus", player_pos + Vector3(0, 1.0, 0))
	mat.set_shader_parameter("cam_right", global_basis.x)
	mat.set_shader_parameter("cam_up", global_basis.y)
	mat.set_shader_parameter("cam_back", global_basis.z)


func toggle() -> void:
	set_mode(Mode.CLASSIC if mode == Mode.ISOMETRIC else Mode.ISOMETRIC)
	var settings := ConfigFile.new()
	settings.load(SETTINGS_PATH)
	settings.set_value("camera", "mode", mode)
	settings.save(SETTINGS_PATH)


## Movement follows the goal angle, so controls switch instantly while the
## view eases over.
func set_mode(value: Mode, instant := false) -> void:
	mode = value
	var a: Vector3 = ANGLES[mode]
	_goal = Basis.from_euler(Vector3(deg_to_rad(a.x), deg_to_rad(a.y), 0.0)).get_rotation_quaternion()
	if instant:
		quaternion = _goal


func ground_axes() -> Array[Vector3]:
	var b := Basis(_goal)
	var right := b.x
	right.y = 0.0
	var forward := -b.z
	forward.y = 0.0
	return [right.normalized(), forward.normalized()]


func snap() -> void:
	quaternion = _goal
	_focus = target.focus_node().global_position
	global_position = _focus + global_basis.z * DISTANCE
