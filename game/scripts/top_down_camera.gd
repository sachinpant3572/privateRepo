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
## The driving zoom at top speed (DRIVE_SPEED and up): with the lead, about
## 100 m of road shows ahead east-west and 60 m or more north-south.
const DRIVE_SIZE := 62.0
const DRIVE_SPEED := 28.0
## Look ahead this many seconds of travel, capped so the car stays on screen
## (HANDOFF-perspective-camera.md E-2).
const LEAD_SECONDS := 1.1
## Degrees below the horizon. 90 would be straight down with no fronts at all.
const PITCH := 60.0
## The perspective view looks down more steeply: the top of the screen still
## sees fronts at the classic angle or flatter, while towers nearer the
## bottom lean away from the player instead of over the street beyond them.
## Downtown, perspective hid about 18% of the street on screen at 60
## degrees, 15% at 65 and 11-12% at 70; the classic view hides 11-13%
## (tests/occlusion_probe.tscn). 70 foreshortens people, so 65 where the
## buildings are low; among towers the camera tips toward 85 (5% hidden;
## E-1 in the handoff).
const PITCH_LOW := 65.0
const PITCH_TALL := 85.0
## The pitches the camera picks from, every PITCH_EVERY seconds: the lowest
## that keeps the player and the ground round the view in sight. They run
## from `base_pitch` (Settings > Angle, PITCH_LOW by default) up to
## PITCH_TALL in 5 degree steps, or are `base_pitch` alone with Settings >
## Tilt near towers off.
const PITCHES := [65.0, 70.0, 75.0, 80.0, 85.0]
const ANGLES := [40.0, 45.0, 50.0, 55.0, 60.0, 65.0, 70.0, 75.0, 80.0, 85.0, 90.0]
var base_pitch := PITCH_LOW
var auto_tilt := true
const PITCH_EVERY := 0.25
## Tipping up is at once while the player is hidden; for the ground round the
## view alone it waits for PITCH_VOTES checks in a row that agree. Either way
## it rises at most PITCH_STEP a check. Tipping down waits PITCH_HOLD seconds
## after the last tip up and PITCH_VOTES agreeing checks, then drops to the
## highest of them. So the camera neither hunts at driving speed nor stays
## steep long after a passing tower (E-1).
const PITCH_HOLD := 1.5
const PITCH_VOTES := 3
const PITCH_STEP := 10.0
var perspective_pitch := PITCH_LOW
var _pitch_want := PITCH_LOW
var _pitch_t := 0.0
var _pitch_hold := 0.0
var _pitch_votes := 0
var _pitch_recent: Array[float] = []
var _player_hidden := false
var _player := Vector3.ZERO
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
		var speed := Vector2(v.x, v.z).length()
		want_size = lerpf(FOOT_SIZE, DRIVE_SIZE, clampf(speed / DRIVE_SPEED, 0.0, 1.0)) * zoom
		# The smaller framing while the zoom eases, and the camera as backed out
		# now, so the car stays on screen on the way there too.
		lead = _cap_lead(Vector3(v.x, 0.0, v.z) * LEAD_SECONDS, minf(size, want_size), _back)
	var look := pos
	_player = pos
	if zoom_override > 0.0:
		want_size = zoom_override
	if fixed_focus != null:
		look = fixed_focus
		want_size = room_size
	_focus = _focus.lerp(look + lead, 1.0 - exp(-6.0 * delta))
	_ahead = look + lead * 2.0
	size = lerpf(size, want_size, 1.0 - exp(-2.0 * delta))
	_update_pitch(delta)
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
	_player = target.focus_node().global_position
	_pitch_t = 0.0
	_pitch_hold = 0.0
	_pitch_votes = 0
	_pitch_recent.clear()
	_update_pitch(0.0)
	_frame(0.0)


## Where the streaming should centre: the ground in the middle of the screen.
func stream_point() -> Vector3:
	return _focus


## The ground the screen shows from the focus: [east-west half width, to the
## bottom edge (south), to the top edge (north)], for a framing `frame`, with
## the camera backed out to at least `back_out` (which narrows the lens).
func ground_extents(frame: float, back_out := 0.0) -> Array[float]:
	var screen := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(20.0, 9.0)
	var half_w := frame * 0.5 * screen.x / maxf(screen.y, 1.0)
	if not perspective:
		var d := frame * 0.5 / sin(deg_to_rad(PITCH))
		return [half_w, d, d]
	var p := deg_to_rad(perspective_pitch)
	var back := maxf(frame * 0.5 / tan(deg_to_rad(PERSPECTIVE_FOV) * 0.5), back_out)
	var hf := atan(frame * 0.5 / back)
	var height := back * sin(p)
	var behind := back * cos(p)
	var south := behind - height / tan(p + hf) if p + hf < PI * 0.5 else behind + height * tan(p + hf - PI * 0.5)
	var north := height / tan(p - hf) - behind
	return [half_w, south, north]


## The lead, capped so the car stays on screen: east-west to 0.6 of the half
## width, north-south to 0.75 of the ground behind the focus on that side.
func _cap_lead(lead: Vector3, frame: float, back_out := 0.0) -> Vector3:
	var e := ground_extents(frame, back_out)
	lead.x = clampf(lead.x, -e[0] * 0.6, e[0] * 0.6)
	# Heading north (-z) the focus moves north and the car toward the bottom.
	lead.z = clampf(lead.z, -e[1] * 0.75, e[2] * 0.75)
	return lead


## Sets Settings > Angle and Tilt near towers, starting the pitch over from
## the new angle (it eases there).
func set_angle(pitch: float, tilt: bool) -> void:
	if is_equal_approx(pitch, base_pitch) and tilt == auto_tilt:
		return
	base_pitch = pitch
	auto_tilt = tilt
	_pitch_want = pitch
	_pitch_hold = 0.0
	_pitch_votes = 0
	_pitch_recent.clear()
	_pitch_t = 0.0


## The pitches the picker tries now, lowest first.
func pitches() -> Array[float]:
	var out: Array[float] = [base_pitch]
	if auto_tilt:
		var p := base_pitch + 5.0
		while p <= PITCH_TALL + 0.1:
			out.append(p)
			p += 5.0
	return out


## Perspective: tips the camera from base_pitch toward PITCH_TALL where
## buildings would hide the player or the ground round them, so towers lean
## out of the way instead of over the street (E-1). `delta` 0 snaps.
func _update_pitch(delta: float) -> void:
	if not perspective:
		return
	_pitch_t -= delta
	_pitch_hold -= delta
	if fixed_focus != null:
		_pitch_want = base_pitch
	elif _pitch_t <= 0.0 and is_inside_tree():
		_pitch_t = PITCH_EVERY
		var pick := best_pitch(_player, _focus, _pitch_want)
		_pitch_recent.append(pick)
		if _pitch_recent.size() > PITCH_VOTES:
			_pitch_recent.pop_front()
		if delta <= 0.0:
			_pitch_want = pick
		elif pick > _pitch_want + 0.1:
			_pitch_votes = 0
			var agreed: bool = _pitch_recent.size() == PITCH_VOTES and _pitch_recent.min() > _pitch_want + 0.1
			if _player_hidden or agreed:
				_pitch_want = minf(pick if _player_hidden else _pitch_recent.min(), _pitch_want + PITCH_STEP)
				_pitch_hold = PITCH_HOLD
		elif pick < _pitch_want - 0.1:
			_pitch_votes += 1
			if _pitch_hold <= 0.0 and _pitch_votes >= PITCH_VOTES:
				_pitch_want = _pitch_recent.max()
				_pitch_votes = 0
		else:
			_pitch_votes = 0
	perspective_pitch = _pitch_want if delta <= 0.0 else lerpf(perspective_pitch, _pitch_want, 1.0 - exp(-2.5 * delta))


## The lowest of PITCHES from which the player at `player` is in sight, and
## all but one of up to seven open-ground points round the view's centre
## `center` (a ring and the look-ahead point). Dropping below `now` needs
## all of them in sight, so the camera doesn't hunt between two pitches.
## Where none does, the one that hides least, the steeper on a tie: right
## beside a tower the camera spot is inside it at every pitch, and steeper
## leaves the least tower in the way (the see-through ghost does the rest).
func best_pitch(player: Vector3, center: Vector3, now := PITCH_LOW) -> float:
	var tries := pitches()
	if tries.size() == 1:
		_player_hidden = false
		return tries[0]
	var space := get_world_3d().direct_space_state
	var base := size * 0.5 / tan(deg_to_rad(PERSPECTIVE_FOV) * 0.5)
	var points: Array[Vector3] = [_ahead]
	for i in 6:
		var a := TAU * i / 6.0
		points.append(center + Vector3(cos(a), 0.0, sin(a)) * size * 0.3)
	var open: Array[Vector3] = []
	for p in points:
		var g := Vector3(p.x, Terrain.height(p.x, p.z) + 1.0, p.z)
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x, 400.0, p.z), g, L.WORLD)).is_empty():
			open.append(g)
	var best: float = tries[-1]
	var best_score := 1 << 20
	for pitch: float in tries:
		var eye := center + Basis.from_euler(Vector3(deg_to_rad(-pitch), 0.0, 0.0)).z * base
		var score := 0
		for h in [0.4, 1.6]:
			if not space.intersect_ray(PhysicsRayQueryParameters3D.create(player + Vector3(0.0, h, 0.0), eye, L.WORLD)).is_empty():
				score += 3
				break
		# Whether the player is hidden at the current pitch (read by _update_pitch).
		if absf(pitch - now) < 0.1:
			_player_hidden = score >= 3
		for g in open:
			if not space.intersect_ray(PhysicsRayQueryParameters3D.create(g, eye, L.WORLD)).is_empty():
				score += 1
		if score <= (0 if pitch < now - 0.1 else 1):
			return pitch
		if score <= best_score:
			best_score = score
			best = pitch
	return best


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
		if absf(m[1] - base) < 0.5 and absf(m[4] - perspective_pitch) < 2.0 and from.distance_squared_to(m[0]) < 2.25 and frame - int(m[3]) < 30:
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
		_clear_memo[slot] = [from, base, back, frame, perspective_pitch]
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
