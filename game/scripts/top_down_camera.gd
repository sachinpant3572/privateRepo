extends Camera3D
## Top-down follow camera: north up, tilted so the fronts of buildings and
## people show (a 3/4 view). By default it sees in true perspective, the way
## GTA Chinatown Wars does, so towers lean out as you pass and the city has
## depth; phone > Settings > View switches to the classic flat view, like
## Stardew Valley, Crashlands and the Java-era Gangstar games
## (HANDOFF-perspective-camera.md).
## Leads ahead of a moving car, zooms out with speed, and points the city's
## cutaway at the player each frame.

const MeshBuilder = preload("res://scripts/mesh_builder.gd")
const L = preload("res://scripts/layers.gd")
const Terrain = preload("res://scripts/terrain.gd")

## Classic view: far enough back (about 190 m up) that the tallest downtown
## towers, 150 m or so, stay in front of the camera instead of clipping open.
## The view is orthographic, so distance doesn't change the framing.
const DISTANCE := 220.0
const FOOT_SIZE := 26.0
const DRIVE_SIZE := 48.0
## Degrees below the horizon. 90 would be straight down with no fronts at all.
const PITCH := 60.0
## The perspective view looks down more steeply: the top of the screen still
## sees fronts at the classic angle or flatter, while towers nearer the
## bottom lean away from the player instead of over the street beyond them.
## Downtown, perspective hid about 18% of the street on screen at 60
## degrees, 15% at 65 and 11-12% at 70; the classic view hides 11-13%
## (tests/occlusion_probe.tscn). 70 foreshortens people, so 65.
var perspective_pitch := 65.0
const PERSPECTIVE_FOV := 35.0
## Size of the see-through hole when a building blocks the view of the player.
const CUT_RADIUS := 6.0
## Perspective: buildings within this share of the camera's usual distance
## from the focus dissolve, so a roof the camera skims past doesn't pop.
const NEAR_FADE := 0.15
## Perspective: air the camera keeps along its line above a roof it backed
## out of. On wide framings the near fade reaches past it, so the roof just
## under the camera thins out, which is wanted.
const ROOF_AIR := 9.0
## The ground kept clear of tall buildings (MeshBuilder's cutaway): a band
## this wide round the player on foot and in a car, out ahead of them for
## AHEAD_SECONDS of travel up to AHEAD_MAX metres. Settings > Zoom scales it.
const VIEW_RADIUS_FOOT := 12.0
const VIEW_RADIUS_DRIVE := 16.0
const AHEAD_SECONDS := 2.5
const AHEAD_MAX := 90.0
## Phone > Settings > Zoom: scales the on-foot and driving zooms.
const ZOOMS := [0.8, 0.9, 1.0, 1.15, 1.3]
var zoom := 1.0

var target: Node3D
## Inside a place: the room's centre (a Vector3) and the zoom that frames
## it; null and 0 on the street.
var fixed_focus = null
var room_size := 0.0
## True perspective, framing the same `size` metres at the focus as the
## classic view; false for the classic flat view.
var perspective := true
## Above 0, the zoom to hold whatever the player is doing (aircraft).
var zoom_override := 0.0
var _focus := Vector3.ZERO
## Perspective: how far back the camera sits, eased so a step past a tower
## doesn't jump.
var _back := 0.0
## How far the camera is from the ground it frames (Atmosphere fits the
## shadows to it).
var view_depth := 0.0
var _clear_memo := {}
## Where the focus is heading (the lead ahead of a moving car), so the
## camera starts backing off a tower before it reaches it.
var _ahead := Vector3.ZERO
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
	var want_size := FOOT_SIZE * zoom
	var lead := Vector3.ZERO
	if node != target:
		var v: Vector3 = node.velocity
		# Look ahead 0.8 s of travel (0.55 before the perspective view), so
		# at top speed the car sits well back from the way it is going.
		lead = v * 0.8
		want_size = lerpf(FOOT_SIZE, DRIVE_SIZE, clampf(v.length() / 20.0, 0.0, 1.0)) * zoom
	var look := pos
	if zoom_override > 0.0:
		want_size = zoom_override
	if fixed_focus != null:
		look = fixed_focus
		want_size = room_size
	_focus = _focus.lerp(look + lead, 1.0 - exp(-6.0 * delta))
	_ahead = look + lead * 2.0
	size = lerpf(size, want_size, 1.0 - exp(-2.0 * delta))
	_frame(delta)
	_update_cutaway(pos, delta)
	_update_view_band(node)
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
	_ahead = _focus
	if fixed_focus != null:
		size = room_size
	_frame(0.0)


## Places the camera back from the focus: DISTANCE for the flat view, or far
## enough that the perspective view frames `size` metres there. On foot the
## perspective camera is only about 37 m up, inside the downtown towers; there
## it backs off along its line until it is clear of them and narrows its
## field of view to frame the same ground. It eases out ahead of a tower the
## player is heading for, jumps out only if it would otherwise be inside one,
## and eases back in. `delta` 0 snaps. Nothing above the camera can show in
## perspective, so the far plane only has to reach the ground at the top
## corners of the screen.
func _frame(delta: float) -> void:
	var back := DISTANCE
	if perspective:
		rotation_degrees = Vector3(-perspective_pitch, 0.0, 0.0)
		projection = PROJECTION_PERSPECTIVE
		var base := size * 0.5 / tan(deg_to_rad(PERSPECTIVE_FOV) * 0.5)
		var need := _clear_back(_focus, base, 0)
		var want := maxf(need, _clear_back(_ahead, base, 1))
		if delta <= 0.0 or _back <= 0.0:
			_back = want
		else:
			_back = lerpf(_back, want, 1.0 - exp(-(4.0 if want > _back else 1.5) * delta))
		_back = maxf(_back, need)
		back = _back
		fov = rad_to_deg(2.0 * atan(size * 0.5 / back))
		far = back * 4.0
		view_depth = back
	else:
		rotation_degrees = Vector3(-PITCH, 0.0, 0.0)
		projection = PROJECTION_ORTHOGONAL
		# The ground under a focus high above it (an aircraft) is further.
		far = DISTANCE + 120.0 + maxf(_focus.y - Terrain.height(_focus.x, _focus.z), 0.0) * 1.2
		view_depth = DISTANCE
	global_position = _focus + global_basis.z * back


## The first distance from `base` outward along the camera's line from
## `from` that is outside every building, with ROOF_AIR above the roof.
func _clear_back(from: Vector3, base: float, slot := -1) -> float:
	if not is_inside_tree():
		return base
	# Over a tower the search takes 30-odd steps, so each caller's last
	# answer is kept while its point stays put (and refreshed now and then,
	# for buildings streaming in).
	var frame := Engine.get_process_frames()
	if slot >= 0 and _clear_memo.has(slot):
		var m: Array = _clear_memo[slot]
		if m[1] == base and from.distance_squared_to(m[0]) < 2.25 and frame - int(m[3]) < 30:
			return m[2]
	var query := PhysicsPointQueryParameters3D.new()
	query.collision_mask = L.WORLD
	var space := get_world_3d().direct_space_state
	var back := base
	var found := false
	for i in 60:
		query.position = from + global_basis.z * back
		if space.intersect_point(query, 1).is_empty():
			found = true
			break
		back += 4.0
	if found and back != base:
		back += ROOF_AIR
	if slot >= 0:
		_clear_memo[slot] = [from, base, back, frame]
	return back


## Points the cutaway's clear band at the player and the way they are going;
## off inside a place, where the room's own walls cut away.
func _update_view_band(node: Node3D) -> void:
	var mat := MeshBuilder.cutaway_material()
	if fixed_focus != null:
		mat.set_shader_parameter("view_radius", 0.0)
		return
	var v = node.get("velocity")
	var flat := Vector3(v.x, 0.0, v.z) if v is Vector3 else Vector3.ZERO
	var radius := VIEW_RADIUS_DRIVE if node != target else VIEW_RADIUS_FOOT
	# Backed out over a tower, the tower fills the screen round the band, so
	# the band widens with the camera's distance (up to 3 times).
	if perspective:
		var base := size * 0.5 / tan(deg_to_rad(PERSPECTIVE_FOV) * 0.5)
		radius *= clampf(_back / base, 1.0, 3.0)
	mat.set_shader_parameter("view_radius", radius * zoom)
	mat.set_shader_parameter("ahead", flat.normalized() * minf(flat.length() * AHEAD_SECONDS, AHEAD_MAX) if flat.length() > 1.0 else Vector3.ZERO)


## Opens the city's see-through hole around the player only while a building
## actually blocks the camera's view of them, fading it in and out.
## When the perspective camera has backed out over a tower, the tower fills
## much of the screen, so the hole opens up to twice as wide.
func _update_cutaway(player_pos: Vector3, delta: float) -> void:
	var widen := 1.0
	if perspective:
		var base := size * 0.5 / tan(deg_to_rad(PERSPECTIVE_FOV) * 0.5)
		widen = 1.0 + clampf((_back - base) / base, 0.0, 1.0)
	var want := CUT_RADIUS * widen if _view_blocked(player_pos) else 0.0
	_cut = move_toward(_cut, want, CUT_RADIUS * 4.0 * delta)
	var mat := MeshBuilder.cutaway_material()
	mat.set_shader_parameter("cut_radius", maxf(_cut, 0.001))
	mat.set_shader_parameter("focus", player_pos + Vector3(0, 1.0, 0))
	mat.set_shader_parameter("cam_back", global_basis.z)
	mat.set_shader_parameter("eye", global_position)
	mat.set_shader_parameter("cone", 1.0 if perspective else 0.0)
	mat.set_shader_parameter("near_fade", NEAR_FADE * size * 0.5 / tan(deg_to_rad(PERSPECTIVE_FOV) * 0.5) if perspective else 0.0)


func _view_blocked(player_pos: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	for height in [0.4, 1.6]:
		var from := player_pos + Vector3(0, height, 0)
		var to := global_position if perspective else from + global_basis.z * DISTANCE
		var query := PhysicsRayQueryParameters3D.create(from, to, L.WORLD)
		if not space.intersect_ray(query).is_empty():
			return true
	return false
