extends Camera3D
## Fixed isometric camera that follows the player, leads ahead of a moving
## car and zooms out with speed.

const DISTANCE := 60.0
const FOOT_SIZE := 26.0
const DRIVE_SIZE := 38.0

var target: Node3D
var _focus := Vector3.ZERO


func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	size = FOOT_SIZE
	near = 1.0
	far = 200.0
	rotation_degrees = Vector3(-35.264, 45.0, 0.0)
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


func snap() -> void:
	_focus = target.focus_node().global_position
	global_position = _focus + global_basis.z * DISTANCE
