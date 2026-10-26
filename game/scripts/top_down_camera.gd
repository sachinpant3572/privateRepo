extends Camera3D
## Classic top-down follow camera: north up, looking steeply down so building
## fronts show a little, like the Java-era Gangstar games and Stardew Valley.
## Leads ahead of a moving car, zooms out with speed, and points the city's
## cutaway at the player each frame.

const MeshBuilder = preload("res://scripts/mesh_builder.gd")

const DISTANCE := 60.0
const FOOT_SIZE := 26.0
const DRIVE_SIZE := 38.0
## Degrees below the horizon. 90 would be straight down with no fronts at all.
const PITCH := 72.0

var target: Node3D
var _focus := Vector3.ZERO


func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	size = FOOT_SIZE
	near = 1.0
	far = 200.0
	rotation_degrees = Vector3(-PITCH, 0.0, 0.0)
	current = true


func _process(delta: float) -> void:
	if target == null:
		return
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


## Ground-plane directions for screen right and screen up (east and north).
func ground_axes() -> Array[Vector3]:
	return [Vector3.RIGHT, Vector3.FORWARD]


func snap() -> void:
	_focus = target.focus_node().global_position
	global_position = _focus + global_basis.z * DISTANCE


## Points the city's see-through hole at the player for this frame's view.
func _update_cutaway(player_pos: Vector3) -> void:
	var mat := MeshBuilder.cutaway_material()
	mat.set_shader_parameter("focus", player_pos + Vector3(0, 1.0, 0))
	mat.set_shader_parameter("cam_right", global_basis.x)
	mat.set_shader_parameter("cam_up", global_basis.y)
	mat.set_shader_parameter("cam_back", global_basis.z)
