extends Camera3D
## Prototype third-person camera for the camera demo (HANDOFF-camera-demo.md):
## behind and above the subject, swinging round to its heading, pulled in
## when a wall comes between it and the subject.

var subject: Node3D
## Metres behind the subject, the camera's height, and the height it looks at.
var back := 6.0
var height := 2.4
var look_height := 1.4
var _yaw := 0.0
var _pos := Vector3.ZERO
var _fresh := true


func _ready() -> void:
	projection = PROJECTION_PERSPECTIVE
	fov = 62.0
	near = 0.2
	far = 1500.0


func follow(node: Node3D, behind: float, up: float, look_up: float) -> void:
	subject = node
	back = behind
	height = up
	look_height = look_up
	_fresh = true


func _process(delta: float) -> void:
	if subject == null or not is_instance_valid(subject):
		return
	var p := subject.get_global_transform_interpolated().origin
	var ahead := _heading()
	var want_yaw := atan2(-ahead.x, -ahead.z)
	_yaw = want_yaw if _fresh else lerp_angle(_yaw, want_yaw, 1.0 - exp(-3.0 * delta))
	var fwd := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	var look := p + Vector3.UP * look_height
	var want := p - fwd * back + Vector3.UP * height
	var skip: Array[RID] = []
	if subject is CollisionObject3D:
		skip.append((subject as CollisionObject3D).get_rid())
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(look, want, 0xFFFFFFFF, skip))
	if not hit.is_empty():
		want = hit.position + (look - want).normalized() * 0.4
	_pos = want if _fresh else _pos.lerp(want, 1.0 - exp(-12.0 * delta))
	_fresh = false
	global_position = _pos
	look_at(look + fwd * 4.0, Vector3.UP)


## Where the subject is going: its ground velocity, else the way it faces.
func _heading() -> Vector3:
	var v = subject.get("velocity")
	if v is Vector3 and Vector2(v.x, v.z).length() > 1.5:
		return Vector3(v.x, 0.0, v.z).normalized()
	var f := -subject.global_basis.z
	return Vector3(f.x, 0.0, f.z).normalized()
