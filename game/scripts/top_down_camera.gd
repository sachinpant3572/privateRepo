extends Camera3D
## Classic top-down follow camera: north up, tilted so the fronts of buildings
## and people show (a 3/4 view), like Stardew Valley, Crashlands and the
## Java-era Gangstar games.
## Leads ahead of a moving car, zooms out with speed, and points the city's
## cutaway at the player each frame.

const MeshBuilder = preload("res://scripts/mesh_builder.gd")
const L = preload("res://scripts/layers.gd")

## Far enough back (about 190 m up) that the tallest downtown towers, 150 m
## or so, stay in front of the camera instead of clipping open. The view is
## orthographic, so distance doesn't change the framing.
const DISTANCE := 220.0
const FOOT_SIZE := 26.0
const DRIVE_SIZE := 48.0
## Degrees below the horizon. 90 would be straight down with no fronts at all.
const PITCH := 60.0
## Size of the see-through hole when a building blocks the view of the player.
const CUT_RADIUS := 6.0

var target: Node3D
## Inside a place: the room's centre (a Vector3) and the zoom that frames
## it; null and 0 on the street.
var fixed_focus = null
var room_size := 0.0
## Prototype (HANDOFF-camera-demo.md): a true perspective view from the same
## angle, framing the same `size` metres at the focus, so tall things and
## aircraft loom toward the camera.
var perspective := false
const PERSPECTIVE_FOV := 35.0
## Above 0, the zoom to hold whatever the player is doing (aircraft).
var zoom_override := 0.0
var _focus := Vector3.ZERO
var _cut := 0.0
var _trauma := 0.0
var _shake_t := 0.0


func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	size = FOOT_SIZE
	near = 1.0
	far = DISTANCE + 120.0
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
		lead = v * 0.55
		want_size = lerpf(FOOT_SIZE, DRIVE_SIZE, clampf(v.length() / 20.0, 0.0, 1.0))
	var look := pos
	if zoom_override > 0.0:
		want_size = zoom_override
	if fixed_focus != null:
		look = fixed_focus
		want_size = room_size
	_focus = _focus.lerp(look + lead, 1.0 - exp(-6.0 * delta))
	size = lerpf(size, want_size, 1.0 - exp(-2.0 * delta))
	_frame()
	_update_cutaway(pos, delta)
	_apply_shake(delta)


## Adds screen shake (0..1); it eases off by itself.
func shake(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


func _apply_shake(delta: float) -> void:
	_trauma = maxf(_trauma - delta * 2.2, 0.0)
	_shake_t += delta * 40.0
	var k := _trauma * _trauma * 0.9
	h_offset = (sin(_shake_t * 1.13) + sin(_shake_t * 2.71) * 0.5) * k
	v_offset = (sin(_shake_t * 1.37 + 1.0) + sin(_shake_t * 3.07) * 0.5) * k


## Ground-plane directions for screen right and screen up (east and north).
func ground_axes() -> Array[Vector3]:
	return [Vector3.RIGHT, Vector3.FORWARD]


func snap() -> void:
	_focus = fixed_focus if fixed_focus != null else target.focus_node().global_position
	if fixed_focus != null:
		size = room_size
	_frame()


## Places the camera back from the focus: DISTANCE for the flat view, or far
## enough that the perspective view frames `size` metres there.
func _frame() -> void:
	var back := DISTANCE
	if perspective:
		projection = PROJECTION_PERSPECTIVE
		fov = PERSPECTIVE_FOV
		back = size * 0.5 / tan(deg_to_rad(PERSPECTIVE_FOV) * 0.5)
		far = back + 900.0
	else:
		projection = PROJECTION_ORTHOGONAL
	global_position = _focus + global_basis.z * back


## Opens the city's see-through hole around the player only while a building
## actually blocks the camera's view of them, fading it in and out.
func _update_cutaway(player_pos: Vector3, delta: float) -> void:
	var want := CUT_RADIUS if _view_blocked(player_pos) else 0.0
	_cut = move_toward(_cut, want, CUT_RADIUS * 4.0 * delta)
	var mat := MeshBuilder.cutaway_material()
	mat.set_shader_parameter("cut_radius", maxf(_cut, 0.001))
	mat.set_shader_parameter("focus", player_pos + Vector3(0, 1.0, 0))
	mat.set_shader_parameter("cam_right", global_basis.x)
	mat.set_shader_parameter("cam_up", global_basis.y)
	mat.set_shader_parameter("cam_back", global_basis.z)


func _view_blocked(player_pos: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	for height in [0.4, 1.6]:
		var from := player_pos + Vector3(0, height, 0)
		var query := PhysicsRayQueryParameters3D.create(from, from + global_basis.z * DISTANCE, L.WORLD)
		if not space.intersect_ray(query).is_empty():
			return true
	return false
