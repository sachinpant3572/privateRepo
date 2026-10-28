extends Camera3D
## Top-down follow camera, tilted so the fronts of buildings and
## people show (a 3/4 view). By default it sees in true perspective, the way
## GTA Chinatown Wars does, so towers lean out as you pass and the city has
## depth; phone > Settings > View switches to the classic flat view, like
## Stardew Valley, Crashlands and the Java-era Gangstar games
## (HANDOFF-perspective-camera.md).
## Leads ahead of a moving car, zooms out with speed, and points the city's
## cutaway at the player each frame. It swings round behind the car the
## way Chinatown Wars' camera does, and follows the player's walk on foot
## (Settings > Camera turn; North up keeps the map's north at the top;
## HANDOFF-heading-camera.md).

const MeshBuilder = preload("res://scripts/mesh_builder.gd")
const L = preload("res://scripts/layers.gd")
const Terrain = preload("res://scripts/terrain.gd")
const SkyDome = preload("res://scripts/sky.gd")

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
## Look down near towers off.
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
## Phone > Settings > Distance: scales the on-foot and driving zooms.
const ZOOMS := [0.6, 0.7, 0.8, 0.9, 1.0, 1.15, 1.3]
var zoom := 1.0
## Phone > Settings > Drive zoom-out: how much of the widening (and, with
## the view turning, the flattening) speed brings in a car; 0 keeps the
## on-foot framing while driving (H-15).
const DRIVE_ZOOMS := [0.0, 0.25, 0.5, 0.75, 1.0]
var drive_zoom := 1.0
## Settings preview: frame the view as if driving at full speed up the
## screen, so Drive zoom-out shows while standing still.
var preview_drive := false

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

## Settings > Camera turn: Follow or 90° turns (true: behind the car, along
## the walk) or North up (false).
var turn_view := true
## Camera turn: 90° turns (H-17). The view holds still until the car, or the
## walk, has been at least STEP_TURN off it for STEP_HOLD, then turns a
## whole quarter, square to the street grid: steering and dodging never
## move it.
var turn_steps := false
const STEP_TURN := deg_to_rad(80.0)
const STEP_HOLD := 0.4
var _step_time := 0.0
## The view's heading in radians: 0 is north up, positive turns the view
## anticlockwise as seen from above (Godot's yaw), so a car heading west
## points up the screen at PI / 2.
var yaw := 0.0
var _yaw_rate := 0.0
var _yaw_goal := 0.0
## Chasing the goal (it starts past YAW_DEAD and stops within YAW_SETTLE).
var _yaw_chasing := false
## Re-centre: chase the goal at once, past the dead zone and holds.
var _yaw_forced := false
## The swing under way was asked for (the compass, a new car): quick caps.
var _yaw_quick := false
var _still := 0.0
## The heading the stick reads its directions in. On foot it is taken from
## the view when the stick is pressed and held while the thumb stays put, so
## a view following the walk never bends it into a circle; swinging the
## thumb more than INPUT_RECAPTURE takes it from the view again (H-14).
## The thumb direction it was read for trails a slow drift at INPUT_TRAIL,
## so only a quick swing re-reads it, and a let-go shorter than INPUT_GRACE
## (a thumb brushing the dead zone) keeps it (H-18).
var _input_yaw := 0.0
var _input_dir := Vector2.ZERO
var _input_idle := 0.0
const INPUT_RECAPTURE := deg_to_rad(25.0)
const INPUT_TRAIL := deg_to_rad(120.0)
const INPUT_GRACE := 0.2
## Whether the view followed a walk last frame (letting go stops it, H-18).
var _walked := false
## What the view followed last frame: a new car turns the view behind it at
## once, before it moves (the stick already steers it car-relative).
var _yaw_node: Node3D = null
## Below this speed the view keeps its heading (parked, turning on the spot).
const YAW_MIN_SPEED := 3.0
## Swings smaller than this (lane changes, wobbles, slight bends) don't
## turn the view (Sachin, 0.20: the view turning on every slight turn made
## him dizzy).
const YAW_DEAD := 0.21
const YAW_SETTLE := 0.01
## How long the view takes to close half the gap: slower standing, a little
## quicker at speed. The car turns on screen first and the view comes round
## after it, out of a 90-degree turn about two seconds after it straightens.
const YAW_HALF_SLOW := 0.8
const YAW_HALF_FAST := 0.6
## Comfort caps, in radians per second and per second squared (45 and 60
## degrees): the view never whips round, and starts and stops gently.
const YAW_RATE_MAX := PI * 0.25
const YAW_ACCEL_MAX := PI / 3.0
## A swing the player asks for (the compass, getting into a car facing
## another way) is quicker: half-life YAW_HALF_QUICK, 90 and 180 degrees.
const YAW_HALF_QUICK := 0.25
const YAW_RATE_QUICK := PI * 0.5
const YAW_ACCEL_QUICK := PI
## On foot the view keeps its 0.20 pace (the calmer driving caps are for
## the car): squaring up closes half the gap in FOOT_HALF, and it eases in
## and out at up to WALK_ACCEL_MAX.
const FOOT_HALF := 0.35
const WALK_ACCEL_MAX := PI
## The last few degrees close at least this fast (8 degrees a second), so
## the swing ends instead of creeping.
const YAW_RATE_MIN := 0.14
## On foot, standing still this long squares the view up with the streets.
const SQUARE_AFTER := 1.2
## On foot the view follows the walk (H-13), calmer than in a car: above
## WALK_MIN_SPEED, turns under WALK_DEAD are ignored (dodges, fights), and
## it closes half the gap in WALK_HALF at up to WALK_RATE_MAX.
const WALK_MIN_SPEED := 1.0
const WALK_DEAD := deg_to_rad(20.0)
const WALK_HALF := 0.6
const WALK_RATE_MAX := PI / 3.0
## In a car with the view turning the road ahead runs up the phone's short
## side, so at speed the car sits lower (8 m or more off the bottom edge),
## the view widens and flattens by up to 10 degrees, all by TURN_FULL_SPEED:
## about 72 m ahead at a sedan's top speed (3.5 s of road) and 74 m in the
## fastest cars, against 60 m (2.9 s) without. The city loads about 1.5 times the area for it.
const TURN_LEAD_CAP := 0.76
const TURN_LEAD_SECONDS := 1.8
const TURN_DRIVE_SIZE := 68.0
const TURN_FLATTEN := 10.0
const TURN_FULL_SPEED := 22.0
var _flatten := 0.0
## Look up (the HUD's SKY button, or L): on foot the view rises from over
## the player's shoulder to the sky (SkyDome.look_up_transform), for the
## sun, the stars out of town and the birds. Drag to look round; walking,
## getting in a car or going indoors brings the usual view back.
const LOOK_UP_TIME := 0.9
const LOOK_UP_FOV := 70.0
const LOOK_UP_PITCH := 35.0
const LOOK_UP_BACK := 2.5
var looking_up := false
## Bearing (0 north, 90 east) and degrees up from the horizon.
var look_yaw := 0.0
var look_pitch := LOOK_UP_PITCH
var _look_t := 0.0


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
	var flatten := 0.0
	var driving := node != target
	var v := Vector3.ZERO
	if driving:
		v = node.velocity
	if preview_drive and fixed_focus == null:
		driving = true
		v = Vector3.FORWARD.rotated(Vector3.UP, yaw) * (TURN_FULL_SPEED if turns() else DRIVE_SPEED)
	if driving:
		var speed := Vector2(v.x, v.z).length()
		var fast := clampf(speed / (TURN_FULL_SPEED if turns() else DRIVE_SPEED), 0.0, 1.0) * drive_zoom
		want_size = lerpf(FOOT_SIZE, TURN_DRIVE_SIZE if turns() else DRIVE_SIZE, fast) * zoom
		# The smaller framing while the zoom eases, and the camera as backed out
		# now, so the car stays on screen on the way there too.
		lead = _cap_lead(Vector3(v.x, 0.0, v.z) * (TURN_LEAD_SECONDS if turns() else LEAD_SECONDS), minf(size, want_size), _back)
		if turns():
			# In 5-degree steps, so the pitch picker isn't chasing it; then
			# scaled, so each Drive zoom-out flattens by its own amount.
			flatten = snappedf(TURN_FLATTEN * clampf((speed - 8.0) / (TURN_FULL_SPEED - 8.0), 0.0, 1.0), 5.0) * drive_zoom
	if flatten != _flatten:
		_flatten = flatten
		_pitch_t = 0.0
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
	_update_yaw(node, delta)
	_update_pitch(delta)
	_frame(delta)
	_update_cutaway(pos, delta)
	_update_view_band(node)
	_apply_shake(delta)
	_update_look_up(pos, delta)


## Starts or ends Look up; it starts facing the way the screen's top faces.
func set_look_up(on: bool) -> void:
	if on == looking_up or (on and not can_look_up()):
		return
	looking_up = on
	if on:
		look_yaw = -rad_to_deg(yaw)
		look_pitch = LOOK_UP_PITCH


## On foot and outdoors (the player's own node in focus, no room framed).
func can_look_up() -> bool:
	return target != null and target.focus_node() == target and fixed_focus == null and not preview_drive


## How far the view is into Look up (0 the usual view, 1 all the way).
func look_up_amount() -> float:
	return _look_t


func _update_look_up(pos: Vector3, delta: float) -> void:
	if looking_up and (not can_look_up() or Vector2(target.velocity.x, target.velocity.z).length() > 0.8):
		looking_up = false
	var was := _look_t
	_look_t = move_toward(_look_t, 1.0 if looking_up else 0.0, delta / LOOK_UP_TIME)
	var env: Environment = get_world_3d().environment if get_world_3d() != null else null
	if _look_t <= 0.0:
		if was > 0.0:
			near = 1.0
			if env != null:
				SkyDome.horizon_haze(env, false)
		return
	if was <= 0.0 and env != null:
		SkyDome.horizon_haze(env, true)
	var bearing := deg_to_rad(look_yaw)
	var behind := Vector3(-sin(bearing), 0.0, cos(bearing)) * LOOK_UP_BACK
	var to := SkyDome.look_up_transform(pos + behind, look_yaw, look_pitch)
	var k := smoothstep(0.0, 1.0, _look_t)
	var from := global_transform
	global_transform = Transform3D(from.basis.slerp(to.basis, k).orthonormalized(), from.origin.lerp(to.origin, k))
	projection = PROJECTION_PERSPECTIVE
	fov = lerpf(fov, LOOK_UP_FOV, k)
	near = lerpf(1.0, 0.3, k)
	far = lerpf(far, 4000.0, k)


func _unhandled_input(event: InputEvent) -> void:
	if not looking_up:
		return
	var rel := Vector2.ZERO
	if event is InputEventScreenDrag:
		rel = event.relative
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		rel = event.relative
	if rel != Vector2.ZERO:
		look_yaw = wrapf(look_yaw - rel.x * 0.25, 0.0, 360.0)
		look_pitch = clampf(look_pitch + rel.y * 0.2, 5.0, 85.0)


## Adds screen shake (0..1); it eases off by itself.
func shake(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


func _apply_shake(delta: float) -> void:
	_trauma = maxf(_trauma - delta * 2.2, 0.0)
	_shake_t += delta * 40.0
	var k := _trauma * _trauma * 0.9
	h_offset = (sin(_shake_t * 1.13) + sin(_shake_t * 2.71) * 0.5) * k
	v_offset = (sin(_shake_t * 1.37 + 1.0) + sin(_shake_t * 3.07) * 0.5) * k


## Ground-plane directions for screen right and screen up (east and north
## with the view north up).
func ground_axes() -> Array[Vector3]:
	return [Vector3.RIGHT.rotated(Vector3.UP, yaw), Vector3.FORWARD.rotated(Vector3.UP, yaw)]


## The directions the stick reads screen right and up as: the view's, but
## held while the stick is held, so a view still turning (just out of a car,
## squaring up) never bends a walk into a circle.
func input_axes() -> Array[Vector3]:
	return [Vector3.RIGHT.rotated(Vector3.UP, _input_yaw), Vector3.FORWARD.rotated(Vector3.UP, _input_yaw)]


## Whether the view swings round with the car now (Settings > Camera turn,
## and not inside a place, whose rooms are framed north up).
func turns() -> bool:
	return turn_view and fixed_focus == null


## The compass (the minimap's N): swings the view behind the car, or north
## up on foot (it then follows the walk again once the player moves off).
func recenter() -> void:
	var node: Node3D = target.focus_node() if target != null else null
	_yaw_goal = _square(_heading(-node.global_basis.z)) if turns() and node != null and node != target else 0.0
	_step_time = 0.0
	_yaw_forced = true
	_yaw_chasing = true


## The view heading that puts the ground direction `dir` up the screen.
static func _heading(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


## In 90° turns, the nearest quarter (getting in, the compass, a snap).
func _square(heading: float) -> float:
	return snappedf(heading, PI * 0.5) if turn_steps else heading


## The goal in 90° turns: the current one, until `heading` has been a
## corner off it for STEP_HOLD; then the quarter nearest `heading`.
func _step_goal(heading: float, delta: float) -> float:
	if absf(wrapf(heading - _yaw_goal, -PI, PI)) < STEP_TURN:
		_step_time = 0.0
		return _yaw_goal
	_step_time += delta
	if _step_time < STEP_HOLD:
		return _yaw_goal
	_step_time = 0.0
	return snappedf(heading, PI * 0.5)


## Turns the view (H-2, H-5 and H-8 in the handoff). In a vehicle the goal is
## the car's facing, leaning toward where it is actually going as it slides;
## past 90 degrees of slip (a spin, or backing up) and below YAW_MIN_SPEED
## it holds. On foot it follows the walk, calmer (H-13), and standing still
## squares up with the street grid. `delta` 0 snaps.
func _update_yaw(node: Node3D, delta: float) -> void:
	# Following a walk: the calmer dead zone, half-life and cap.
	var walking := false
	# Whether 90° turns weighed a heading this frame; if not, its hold
	# starts over, so short swings never add up to a turn.
	var stepped := false
	if not turns():
		_yaw_goal = 0.0
		if absf(wrapf(yaw, -PI, PI)) > YAW_SETTLE:
			# Back to north up is the player's choice: a quick swing.
			if not _yaw_chasing:
				_yaw_quick = true
			_yaw_chasing = true
		if fixed_focus != null:
			yaw = 0.0
			_yaw_rate = 0.0
			return
	elif node != target:
		_still = 0.0
		var v: Vector3 = node.velocity
		var flat := Vector3(v.x, 0.0, v.z)
		var speed := flat.length()
		var fwd := -node.global_basis.z
		if node != _yaw_node:
			_yaw_goal = _square(_heading(fwd))
			_step_time = 0.0
			_yaw_chasing = true
			_yaw_forced = false
			_yaw_quick = true
		elif speed > YAW_MIN_SPEED and not _yaw_forced:
			var face := _heading(fwd)
			var slip := wrapf(_heading(flat) - face, -PI, PI)
			if absf(slip) < PI * 0.5:
				var goal := face + slip * 0.6 * smoothstep(deg_to_rad(15.0), deg_to_rad(60.0), absf(slip))
				stepped = turn_steps
				_yaw_goal = _step_goal(goal, delta) if turn_steps else goal
	else:
		var speed := Vector2(node.velocity.x, node.velocity.z).length()
		var held := Controls.move_vector().length() > 0.2
		_still = 0.0 if held or speed > 0.5 else _still + delta
		# The way the stick sends the player, not the velocity, so a shove or
		# a wall slide doesn't swing the view.
		var walk := Controls.world_move()
		walking = held and speed > WALK_MIN_SPEED and not _yaw_forced
		if _yaw_forced:
			pass
		elif walking and turn_steps:
			stepped = true
			_yaw_goal = _step_goal(_heading(walk), delta)
		elif walking and (node != _yaw_node or _yaw_chasing or absf(wrapf(_heading(walk) - yaw, -PI, PI)) > WALK_DEAD):
			_yaw_goal = _heading(walk)
			_yaw_chasing = true
		elif _walked and not held and not turn_steps:
			# Let go mid-turn: the view eases to a stop where it is (just past,
			# at WALK_ACCEL_MAX), rather than chasing the old walk at car rates.
			_yaw_goal = yaw + _yaw_rate * absf(_yaw_rate) / (2.0 * WALK_ACCEL_MAX)
		elif _still >= SQUARE_AFTER:
			_yaw_goal = snappedf(yaw, PI * 0.5)
			_yaw_chasing = true
	_walked = walking
	if not stepped:
		_step_time = 0.0
	var gap := wrapf(_yaw_goal - yaw, -PI, PI)
	if absf(gap) > (WALK_DEAD if walking else YAW_DEAD):
		_yaw_chasing = true
	if delta <= 0.0:
		yaw = wrapf(_yaw_goal, -PI, PI)
		_yaw_rate = 0.0
		_yaw_chasing = false
		_yaw_forced = false
		return
	var quick := _yaw_forced or _yaw_quick
	var on_foot := node == target
	var accel_max := YAW_ACCEL_QUICK if quick else (WALK_ACCEL_MAX if on_foot else YAW_ACCEL_MAX)
	if not _yaw_chasing:
		_yaw_rate = move_toward(_yaw_rate, 0.0, accel_max * delta)
	else:
		var v = node.get("velocity")
		var speed := Vector2(v.x, v.z).length() if v is Vector3 else 0.0
		var half := YAW_HALF_QUICK if quick else lerpf(YAW_HALF_SLOW, YAW_HALF_FAST, clampf(speed / TURN_FULL_SPEED, 0.0, 1.0))
		if walking:
			half = WALK_HALF
		elif on_foot and not quick:
			half = FOOT_HALF
		var want := gap * log(2.0) / half
		if absf(want) < YAW_RATE_MIN:
			want = signf(gap) * minf(YAW_RATE_MIN, absf(gap) / delta)
		var cap := WALK_RATE_MAX if walking else (YAW_RATE_QUICK if quick or on_foot else YAW_RATE_MAX)
		want = clampf(want, -cap, cap)
		# Braking into the goal no harder than accel_max allows, so the view
		# eases to a stop rather than overshooting it.
		var stop := sqrt(2.0 * accel_max * absf(gap))
		want = clampf(want, -stop, stop)
		_yaw_rate = move_toward(_yaw_rate, want, accel_max * delta)
		if absf(gap) < YAW_SETTLE and absf(_yaw_rate) < 0.05:
			# Landed: exactly on the goal, so north up is square to the pixels.
			_yaw_rate = 0.0
			yaw = _yaw_goal
			_yaw_chasing = false
			_yaw_forced = false
			_yaw_quick = false
	yaw = wrapf(yaw + _yaw_rate * delta, -PI, PI)
	# The stick's frame follows the view while it is let go or the player
	# drives, so getting out with the stick held walks the way the view faces.
	_yaw_node = node
	var stick := Controls.move_vector()
	if node != target:
		_input_yaw = yaw
		_input_dir = Vector2.ZERO
		_input_idle = INPUT_GRACE
	elif stick.length() < 0.2:
		_input_idle += delta
		if _input_idle >= INPUT_GRACE:
			_input_yaw = yaw
			_input_dir = Vector2.ZERO
	elif _input_dir == Vector2.ZERO or absf(stick.angle_to(_input_dir)) > INPUT_RECAPTURE:
		_input_idle = 0.0
		_input_yaw = yaw
		_input_dir = stick
	else:
		_input_idle = 0.0
		var drift := _input_dir.angle_to(stick)
		_input_dir = _input_dir.rotated(clampf(drift, -INPUT_TRAIL * delta, INPUT_TRAIL * delta))


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
	var node: Node3D = target.focus_node()
	if not turns():
		_yaw_goal = 0.0
	elif node != target:
		_yaw_goal = _square(_heading(-node.global_basis.z))
	else:
		_yaw_goal = _square(yaw)
	_step_time = 0.0
	_update_yaw(node, 0.0)
	_input_yaw = yaw
	_input_dir = Vector2.ZERO
	_input_idle = INPUT_GRACE
	_walked = false
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


## The lead, capped so the car stays on screen: across the screen to 0.6 of
## the half width, up and down to 0.75 of the ground behind the focus on that
## side (0.76 up the screen while the view turns with the car, so at speed
## the car sits low and the road ahead shows further).
func _cap_lead(lead: Vector3, frame: float, back_out := 0.0) -> Vector3:
	var e := ground_extents(frame, back_out)
	var axes := ground_axes()
	var across := clampf(lead.dot(axes[0]), -e[0] * 0.6, e[0] * 0.6)
	# Heading up the screen the focus moves up and the car toward the bottom.
	var up := clampf(lead.dot(axes[1]), -e[2] * 0.75, e[1] * (TURN_LEAD_CAP if turns() else 0.75))
	return axes[0] * across + axes[1] * up


## Sets Settings > Angle and Look down near towers, starting the pitch over from
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
	var out: Array[float] = [maxf(base_pitch - _flatten, ANGLES[0])]
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
		# Rooms are framed for 65 degrees; flatter shows past the back wall.
		_pitch_want = maxf(base_pitch, PITCH_LOW)
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


## The lowest of pitches() from which the player at `player` is in sight, and
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
		var eye := center + Basis.from_euler(Vector3(deg_to_rad(-pitch), yaw, 0.0)).z * base
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
		rotation = Vector3(deg_to_rad(-perspective_pitch), yaw, 0.0)
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
		# Flatter than 65 degrees the top of the screen sees further out.
		view_depth = back * maxf(1.0, sin(deg_to_rad(PITCH_LOW)) / sin(deg_to_rad(perspective_pitch)))
	else:
		rotation = Vector3(deg_to_rad(-PITCH), yaw, 0.0)
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
		if absf(m[1] - base) < 0.5 and absf(m[4] - perspective_pitch) < 2.0 and absf(wrapf(yaw - m[5], -PI, PI)) < 0.05 and from.distance_squared_to(m[0]) < 2.25 and frame - int(m[3]) < 30:
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
		_clear_memo[slot] = [from, base, back, frame, perspective_pitch, yaw]
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
