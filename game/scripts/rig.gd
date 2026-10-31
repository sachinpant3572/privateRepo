extends RefCounted
## Animates a CharacterKit skeleton in code. Each frame the owner fills a
## Rig.State; pose() turns it into target bone rotations, clamps them to the
## joint LIMITS and eases the skeleton toward them, so every move blends into
## the next. Upright poses are grounded: the hips sit as high as the lower
## foot allows, so crouches, kneels and the walk's double-support dip keep
## the feet on the ground.
##
## The library:
## - Locomotion: walk, jog, run and sprint cycles matched to ground speed
##   (stride length and cadence), knee swing, foot roll, pelvis twist and
##   drop, counter-swinging shoulders, a steady head. STYLES change the gait.
##   Starting leans in, stopping leans back, turning on the spot steps round,
##   running banks into turns.
## - Standing: a relaxed weight-on-one-leg stance that breathes, and IDLE_ACTS
##   it plays now and then when the owner has nothing else for it.
## - One-shot ACTIONS (startle, dodge, duck, stumble) and looping GESTURES.
## - Falling (backward or face down), lying hurt or dead, getting up.
## - Fighting: guard, punches, kick, flinch. Riding and sitting.

const CharacterKit = preload("res://scripts/kits/character_kit.gd")

## What the body is doing this frame.
class State:
	var speed := 0.0 # ground speed, m/s
	var run_speed := 5.0 # speed treated as a full run
	var punch := -1.0 # 0..1 progress of a punch, < 0 when not punching
	var punch_left := false
	var kick := -1.0 # 0..1 progress of a kick
	var flinch := 0.0 # 1 just hit, fading to 0
	var guard := false # fists up between punches
	var down := false # knocked down or dead: falls, then lies
	var dead := false # lying for good: limp, no breathing
	var face_down := false # falls forward onto the front instead of the back
	var getup := -1.0 # 0..1 getting up at the end of a knockdown, < 0 when not
	var ride := false # sitting astride a scooter or bike
	var pedal := -1.0 # crank angle (rad) while riding a pedal bike, < 0 when not
	var car := 0 # seated in an open car: 1 a passenger, 2 the driver (hands on the wheel)
	var sit := false # on a chair, stool or bench (gestures still apply)
	var gesture := "" # see GESTURES
	var texting := false # looking at a phone in the right hand while strolling
	var style := "" # gait, see STYLES
	var action := "" # one-shot, see ACTIONS
	var action_t := -1.0 # 0..1 progress of the action, < 0 when none
	var action_side := 1.0 # +1 toward the body's right, -1 its left
	var look_yaw := 0.0 # turn the head toward something: radians, + to the left
	var look_pitch := 0.0 # + up
	var look_amount := 0.0 # 0..1
	var turn := 0.0 # body yaw rate, rad/s, + to the left
	var accel := 0.0 # change of ground speed, m/s per s
	var idle := true # may play idle acts when standing with nothing to do
	var idle_seed := 0 # varies idle acts and dead poses between people

## Hip drop for sitting on a seat at InteriorKit.SEAT_Y, for hips that rest
## 0.92 m up (other bodies make up the difference, so the pelvis always
## lands on the seat).
const SIT_LIFT := -0.42
## Pedal bike geometry (VehicleKit builds its bicycle to it): the rider's
## hip joints sit PEDAL_HIP_Y over the ground at the bike's origin, the
## crank axle PEDAL_CRANK.x ahead of them and PEDAL_CRANK.y up, the cranks
## PEDAL_ARM long. PEDAL_RATE: crank turn (rad) per metre ridden.
const PEDAL_HIP_Y := 0.95
const PEDAL_CRANK := Vector2(0.15, 0.29)
const PEDAL_ARM := 0.17
const PEDAL_RATE := 1.13
## Seconds from standing to lying.
const FALL_TIME := 0.5
## Seconds to get up; the owner plays it inside the end of a knockdown.
const GETUP_TIME := 1.0
## One-shot actions and their length in seconds; the owner advances
## action_t by delta / ACTIONS[action].
## Stride frequency (full cycles a second) by ground speed, walking and
## running (gait studies; the run one rises slowly with speed).
const WALK_CADENCE := [Vector2(0.5, 0.65), Vector2(1.0, 0.8), Vector2(1.4, 0.92), Vector2(2.0, 1.0), Vector2(2.6, 1.08)]
const RUN_CADENCE := [Vector2(2.0, 1.3), Vector2(3.0, 1.35), Vector2(4.2, 1.42), Vector2(5.5, 1.5), Vector2(7.0, 1.65), Vector2(8.5, 1.8)]
## The foot about its ankle (rest units): the heel is behind it, the ball of
## the foot ahead, the sole below.
const FOOT_HEEL := 0.08
const FOOT_BALL := 0.15
const FOOT_UP := 0.107
const ACTIONS := {"startle": 0.6, "dodge": 0.7, "duck": 1.0, "stumble": 0.8}
const STYLES := ["", "jog", "sprint", "panic", "limp", "elderly", "patrol", "carry", "rain", "swagger", "pockets"]
const GESTURES := ["phone", "talk", "wave", "hands_up", "cower", "point", "eat", "browse", "work", "pay", "search",
	"smoke", "argue", "cheer", "film", "hail", "lean_wall", "listen", "shopkeeper", "kneel", "cover_head", "clap",
	"call", "arms_crossed", "shake_fist", "stretch", "wait"]
## Idle acts and their length in seconds.
const IDLE_ACTS := [["shift", 1.4], ["look_around", 3.2], ["check_watch", 2.2], ["stretch", 2.6],
	["scratch_head", 1.8], ["arms_crossed", 4.5], ["hands_hips", 3.5], ["phone_glance", 2.8]]

const HIPS := 0
const SPINE := 1
const CHEST := 2
const NECK := 3
const HEAD := 4
const L_ARM := 5
const L_FORE := 6
const L_HAND := 7
const R_ARM := 8
const R_FORE := 9
const R_HAND := 10
const L_LEG := 11
const L_SHIN := 12
const L_FOOT := 13
const R_LEG := 14
const R_SHIN := 15
const R_FOOT := 16

## Joint limits, [min, max] Euler angles (x, y, z) per bone. Limb +x swings
## forward; elbows flex +x, knees -x; the left arm lifts sideways with -z,
## the right with +z.
const LIMITS := [
	[Vector3(-0.7, -1.0, -0.45), Vector3(0.7, 1.0, 0.45)], # hips
	[Vector3(-1.2, -0.8, -0.5), Vector3(0.6, 0.8, 0.5)], # spine
	[Vector3(-0.7, -0.8, -0.4), Vector3(0.5, 0.8, 0.4)], # chest
	[Vector3(-0.6, -0.8, -0.4), Vector3(0.5, 0.8, 0.4)], # neck
	[Vector3(-0.8, -1.2, -0.5), Vector3(0.7, 1.2, 0.5)], # head
	[Vector3(-1.3, -1.2, -3.0), Vector3(3.1, 1.2, 0.9)], # left upper arm
	[Vector3(0.0, -1.2, -0.7), Vector3(2.6, 1.2, 0.7)], # left forearm
	[Vector3(-1.0, -1.0, -0.8), Vector3(1.0, 1.0, 0.8)], # left hand
	[Vector3(-1.3, -1.2, -0.9), Vector3(3.1, 1.2, 3.0)], # right upper arm
	[Vector3(0.0, -1.2, -0.7), Vector3(2.6, 1.2, 0.7)], # right forearm
	[Vector3(-1.0, -1.0, -0.8), Vector3(1.0, 1.0, 0.8)], # right hand
	[Vector3(-1.0, -0.6, -0.8), Vector3(2.2, 0.6, 0.5)], # left thigh
	[Vector3(-2.5, -0.2, -0.2), Vector3(0.0, 0.2, 0.2)], # left shin
	[Vector3(-1.0, -0.4, -0.4), Vector3(0.8, 0.4, 0.4)], # left foot
	[Vector3(-1.0, -0.6, -0.5), Vector3(2.2, 0.6, 0.8)], # right thigh
	[Vector3(-2.5, -0.2, -0.2), Vector3(0.0, 0.2, 0.2)], # right shin
	[Vector3(-1.0, -0.4, -0.4), Vector3(0.8, 0.4, 0.4)], # right foot
]

var skeleton: Skeleton3D
var phase := 0.0
var _bones := PackedInt32Array()
var _rot: Array[Vector3] = []
var _target: Array[Vector3] = []
var _time := 0.0
var _lift := 0.0
var _ground := 0.0
var _tilt := 0.0
var _roll := 0.0
## Per-frame extras from gestures and actions.
var _add_lift := 0.0
var _add_tilt := 0.0
var _add_roll := 0.0
var _down_time := 0.0
## Rest hip height and leg bone lengths at height 1 (set from the skeleton).
var _hip := 0.92
var _thigh := 0.4
var _shin := 0.4
var _step_phase := 0.0
# The gait (see _locomotion): eased speed, hip height above rest (rest
# units) and this frame's stride numbers.
var _gv := 0.0
var _gait_h := 0.0
var _gt_ls := 0.0
var _gt_beta := 0.6
var _gt_c := 0.45
var _gt_p0 := 0.0
var _gt_p1 := 0.0
var _gt_g := 0.0
var _gt_f := 1.0
var _gt_sprint := 0.0
var _gt_tan := 0.0
var _gt_peak := 0.0
var _gt_rise := 0.4
var _gt_late := 0.4
## How much the body is walking (0 standing, 1 on the move).
var _moving := 0.0
## Standing weight: +1 on the left leg, -1 on the right.
var _weight := 1.0
var _weight_side := 1.0
var _idle_clock := 0.0
var _idle_next := 3.0
var _idle_act := -1
var _idle_start := 0.0
var _idle_count := 0


func _init(skel: Skeleton3D) -> void:
	skeleton = skel
	for b in CharacterKit.BONES:
		_bones.append(skel.find_bone(b[0]))
		_rot.append(Vector3.ZERO)
		_target.append(Vector3.ZERO)
	# Body meshes have their own joints: the seat and ride lifts and the
	# leg reach use the rest hip height and leg lengths (at height 1).
	_hip = skel.get_bone_rest(_bones[HIPS]).origin.y
	_thigh = skel.get_bone_rest(_bones[L_SHIN]).origin.length()
	_shin = skel.get_bone_rest(_bones[L_FOOT]).origin.length()


## The current eased rotation of bone `i` (Euler, radians).
func bone_rotation(i: int) -> Vector3:
	return _rot[i]


## The idle act playing now, or "" (tests and shots read it).
func idle_act() -> String:
	return "" if _idle_act < 0 else IDLE_ACTS[_idle_act][0]


func pose(s: State, delta: float) -> void:
	_time += delta
	for i in _target.size():
		_target[i] = Vector3.ZERO
	_add_lift = 0.0
	_add_tilt = 0.0
	_add_roll = 0.0
	var lift := 0.0
	var tilt := 0.0
	var rate := 16.0
	var grounded := true
	var direct := false
	var h := skeleton.scale.y
	if s.down:
		_down_time += delta
		_moving = 0.0
		_gv = 0.0
		grounded = false
		direct = true
		_idle(s, delta, false)
		if s.getup >= 0.0 and not s.dead:
			var g := _get_up(clampf(s.getup, 0.0, 1.0), s.face_down)
			tilt = g.x
			lift = g.y * h
			rate = 22.0
		else:
			var f := clampf(_down_time / FALL_TIME, 0.0, 1.0)
			_lying(s, f)
			tilt = (-1.0 if s.face_down else 1.0) * PI / 2.0 * f * f
			lift = (0.17 if s.face_down else 0.14) * h * f
			rate = 18.0 if f < 1.0 else 10.0
	else:
		_down_time = 0.0
		_moving = 0.0
		if s.ride:
			if s.pedal >= 0.0:
				_pedal(s.pedal, h)
				lift = PEDAL_HIP_Y + 0.02 * h - _hip * h
				rate = 60.0
			else:
				_ride()
				lift = -0.28 + 0.92 - _hip * h
			grounded = false
			_idle(s, delta, false)
		elif s.sit:
			_sit()
			if s.car > 0:
				_car_seat(s.car == 2)
			lift = SIT_LIFT + 0.92 - _hip * h
			grounded = false
			_idle(s, delta, false)
			if s.gesture != "":
				_gesture(s.gesture)
		else:
			lift = _locomotion(s, delta) * h
			var still := 1.0 - smoothstep(0.08, 0.7, s.speed)
			var busy := s.gesture != "" or s.texting or s.guard or s.punch >= 0.0 or s.kick >= 0.0 \
				or s.action_t >= 0.0 or s.flinch > 0.05 or s.look_amount > 0.3 or not s.idle
			_idle(s, delta, still > 0.95 and not busy)
			if s.texting and s.speed < 2.5:
				_texting()
			if s.guard and s.punch < 0.0 and s.kick < 0.0 and s.speed < 3.5:
				_guard()
			if s.punch >= 0.0:
				_punch(s.punch, s.punch_left)
				rate = 42.0
			if s.kick >= 0.0:
				_kick(s.kick)
				rate = 42.0
			if s.gesture != "":
				_gesture(s.gesture)
			if s.action_t >= 0.0 and ACTIONS.has(s.action):
				_action(s.action, clampf(s.action_t, 0.0, 1.0), s.action_side)
				rate = 26.0
			if s.flinch > 0.0:
				_target[SPINE].x += 0.4 * s.flinch
				_target[HEAD].x += 0.35 * s.flinch
				_target[L_ARM].z -= 0.4 * s.flinch
				_target[R_ARM].z += 0.4 * s.flinch
		if s.look_amount > 0.0:
			var y := clampf(s.look_yaw, -1.7, 1.7) * clampf(s.look_amount, 0.0, 1.0)
			_target[HEAD].y += y * 0.55
			_target[NECK].y += y * 0.25
			_target[CHEST].y += y * 0.2
			_target[HEAD].x += clampf(s.look_pitch, -0.5, 0.5) * s.look_amount
	for i in _target.size():
		_target[i] = _target[i].clamp(LIMITS[i][0], LIMITS[i][1])
	# While moving the legs and hips follow the gait almost directly (easing
	# would blur its curves and lag the feet behind the ground speed); the
	# upper body a little softer.
	var k := 1.0 - exp(-rate * delta)
	var k_legs := 1.0 - exp(-maxf(rate, lerpf(rate, 60.0, _moving)) * delta)
	var k_body := 1.0 - exp(-maxf(rate, lerpf(rate, 36.0, _moving)) * delta)
	for i in _rot.size():
		_rot[i] = _rot[i].lerp(_target[i], k if _moving <= 0.0 else (k_legs if i == HIPS or i >= L_LEG else k_body))
		skeleton.set_bone_pose_rotation(_bones[i], Quaternion.from_euler(_rot[i]))
	# Standing, the hips drop until the lower foot reaches the ground; moving,
	# they ride the gait's height (never letting a heel or toe sink).
	var ground := 0.0
	if grounded:
		ground = lerpf(-_ground_drop(), _gait_h, _moving) * h
	_ground = lerpf(_ground, ground, lerpf(1.0 - exp(-30.0 * delta), 1.0, _moving))
	if grounded and _moving > 0.0:
		_ground = maxf(_ground, -_foot_drop() * h)
	if direct:
		_lift = lift
		_tilt = tilt
	else:
		_lift = lerpf(_lift, lift + _add_lift * h, 1.0 - exp(-14.0 * delta))
		_tilt = lerpf(_tilt, _add_tilt, 1.0 - exp(-8.0 * delta))
	var roll := 0.0
	if not s.down and not s.ride and not s.sit:
		roll = clampf(s.turn * s.speed * 0.012, -0.2, 0.2) + _add_roll
	_roll = lerpf(_roll, roll, 1.0 - exp(-10.0 * delta))
	skeleton.position.y = _lift + _ground
	skeleton.rotation.x = _tilt
	skeleton.rotation.z = _roll


## How far the hips must drop for the lower foot to reach the ground, from
## the eased leg angles (the rest leg lengths, at height 1).
func _ground_drop() -> float:
	var dl := _leg_drop(_rot[HIPS].x + _rot[L_LEG].x, _rot[L_SHIN].x, _rot[HIPS].z + _rot[L_LEG].z)
	var dr := _leg_drop(_rot[HIPS].x + _rot[R_LEG].x, _rot[R_SHIN].x, _rot[HIPS].z + _rot[R_LEG].z)
	return maxf(minf(dl, dr), 0.0)


func _leg_drop(a: float, b: float, z: float) -> float:
	return _thigh + _shin - (_thigh * cos(a) + _shin * cos(a + b)) * cos(z)


## Like _ground_drop, but down to the lowest heel or ball of either foot
## (so a pointed or flexed foot counts).
func _foot_drop() -> float:
	var low := INF
	for side in 2:
		var leg := L_LEG if side == 0 else R_LEG
		var a := _rot[HIPS].x + _rot[leg].x
		var b := a + _rot[leg + 1].x
		var p := b + _rot[leg + 2].x
		var z := cos(_rot[HIPS].z + _rot[leg].z)
		var ankle := (_thigh * cos(a) + _shin * cos(b)) * z
		var heel := ankle + FOOT_UP * cos(p) + FOOT_HEEL * sin(p)
		var ball := ankle + FOOT_UP * cos(p) - FOOT_BALL * sin(p)
		low = minf(low, -maxf(heel, ball))
	return _thigh + _shin + FOOT_UP + low


func _mix(bone: int, v: Vector3, w: float) -> void:
	_target[bone] = _target[bone].lerp(v, w)


## Walk, jog, run and sprint, driven by the feet. Each foot is planted for
## the stance part of its cycle and slides back under the hips at exactly
## the ground speed (no skating), rolling from heel strike (or the ball, in
## a sprint) to toe-off; through the swing it follows an authored path
## (low in a walk, the heel kicked up under the hips in a run, high knees
## in a sprint). The hip height comes from an authored stance knee bend and
## a ballistic flight, and two-bone IK turns each foot into thigh, knee and
## ankle angles. Cadence and duty factor follow walking and running data.
## Returns extra hip lift (none: the height goes through _gait_h).
func _locomotion(s: State, delta: float) -> float:
	var st := s.style
	_gv = lerpf(_gv, s.speed, 1.0 - exp(-10.0 * delta))
	var speed := _gv
	var moving := smoothstep(0.08, 0.7, speed)
	_moving = moving
	var run := clampf((speed - 2.3) / maxf(s.run_speed - 2.3, 0.1), 0.0, 1.0)
	if st == "jog":
		run = maxf(run, 0.6 * moving)
	var sprint := clampf((speed - s.run_speed) / 1.5, 0.0, 1.0)
	if st == "sprint":
		sprint = maxf(sprint, run)
	var elderly := st == "elderly"
	var limp := st == "limp"
	# g: walking (0) to running (1) by speed, the way people switch near 2.3 m/s.
	var g := smoothstep(1.9, 2.8, speed)
	if st == "jog":
		g = maxf(g, moving)
	var v := speed / skeleton.scale.y # in rest units, like the bones
	var f := lerpf(_table(WALK_CADENCE, speed), _table(RUN_CADENCE, speed), g)
	if elderly:
		f *= 1.15
	if st == "swagger":
		f *= 0.94
	var beta := lerpf(0.62, 0.37, g) - 0.1 * sprint
	beta = minf(beta, lerpf(0.82, 0.9, g) * f / maxf(v, 0.01)) # the leg can reach
	_gt_ls = v * beta / f
	_gt_beta = beta
	_gt_c = lerpf(0.47, 0.38, g)
	_gt_p1 = lerpf(0.3, 0.12, g) - 0.3 * sprint
	_gt_p0 = -lerpf(0.55, 0.75, g) - 0.25 * sprint
	_gt_g = g
	_gt_f = f
	_gt_sprint = sprint
	_gt_tan = -v * (1.0 - beta) / f * lerpf(1.0, 0.88, g)
	_gt_peak = (lerpf(0.07, 0.38, g) + 0.08 * sprint) * moving
	_gt_rise = lerpf(0.4, 0.32, g)
	_gt_late = lerpf(0.4, 0.42, g) + 0.15 * sprint
	var warp := 1.0
	if limp:
		warp = 1.0 + 0.25 * cos(phase) # hurries off the bad leg
	phase = fmod(phase + delta * TAU * f * warp, TAU)
	# Left foot touches down at phase PI/2, when sin(phase) (which the styles
	# swing their arms by) peaks; the right half a cycle later.
	var feet: Array[Vector4] = []
	for side in 2:
		var ph := fposmod(phase / TAU - 0.25 + 0.5 * side, 1.0)
		var t := _foot(ph)
		if limp and side == 1 and ph >= beta: # the bad leg barely lifts
			var u := (ph - beta) / (1.0 - beta)
			t.y -= _gt_peak * 0.55 * _bump(u)
		feet.append(t)
	var hgt := _gait_height(feet)
	if elderly:
		hgt -= 0.035
	_gait_h = hgt - _hip
	# Pelvis drops on the swinging side and the spine evens it out.
	var drop := cos(phase) * 0.055 * moving * (1.0 - 0.6 * g)
	if limp:
		drop = cos(phase) * 0.1 * moving
	for side in 2:
		var leg := L_LEG if side == 0 else R_LEG
		var shin := L_SHIN if side == 0 else R_SHIN
		var foot := L_FOOT if side == 0 else R_FOOT
		var t := feet[side]
		var j := _leg_ik(t.x, t.y - hgt)
		_target[leg].x = j.x * moving
		_target[shin].x = -j.y * moving
		_target[foot].x = (t.z - (j.x - j.y)) * moving
		_target[leg].z -= drop
	_target[HIPS].z = drop
	_target[SPINE].z = -drop * 0.8
	# Arms swing against the legs, a beat behind them, mostly behind the
	# body; elbows bend more the faster he goes, more in front than behind.
	var aw := sin(phase - 0.2)
	var centre := (lerpf(-0.08, -0.26, g) + 0.08 * sprint) * moving
	var arm := (lerpf(0.27, 0.52, g) + 0.38 * sprint) * moving
	if elderly:
		arm *= 0.5
	var spread := 0.08 + 0.06 * g + (0.12 if st == "swagger" else 0.0)
	_target[L_ARM] = Vector3(centre - aw * arm, 0.0, -spread)
	_target[R_ARM] = Vector3(centre + aw * arm, 0.0, spread)
	var elbow := lerpf(0.18, lerpf(0.32, 1.7, g), moving)
	var bend := (lerpf(0.12, 0.3, g) + 0.1 * sprint) * moving
	_target[L_FORE].x = elbow - aw * bend
	_target[R_FORE].x = elbow + aw * bend
	# Running hands cross a little toward the middle in front.
	_target[L_FORE].y = 0.3 * g * moving
	_target[R_FORE].y = -0.3 * g * moving
	# Pelvis turns with the forward leg, shoulders against it.
	var tw := sin(phase) * moving * (1.4 if st == "swagger" else 1.0)
	_target[HIPS].y = -tw * lerpf(0.1, 0.15, g)
	_target[CHEST].y = tw * (lerpf(0.2, 0.28, g) + 0.08 * sprint)
	_target[SPINE].x = -(lerpf(0.05, 0.13, g) + 0.12 * sprint) * moving
	_target[HEAD].x = -_target[SPINE].x * 0.7
	_target[HEAD].y = -(_target[HIPS].y + _target[CHEST].y)
	# Starting leans in, stopping leans back.
	var acc := clampf(s.accel / 8.0, -1.0, 1.0)
	_target[SPINE].x += -0.2 * maxf(acc, 0.0) + 0.14 * maxf(-acc, 0.0) * (1.0 - g)
	var still := 1.0 - moving
	_stance(still, delta)
	_turn_in_place(s, still, delta)
	_style(s, moving, run)
	return 0.0


## Linear look-up in a [speed, value] table.
func _table(t: Array, x: float) -> float:
	if x <= t[0].x:
		return t[0].y
	for i in range(1, t.size()):
		if x <= t[i].x:
			return lerpf(t[i - 1].y, t[i].y, (x - t[i - 1].x) / (t[i].x - t[i - 1].x))
	return t[t.size() - 1].y


## The ankle (x forward of the hip, y up from the rest ground, in rest
## units) of a foot whose flat position is `gx`, pitched by `p` (toe up +)
## about the heel or, toe down, about the ball.
func _ankle(gx: float, p: float) -> Vector2:
	var sole := _hip - _thigh - _shin - FOOT_UP
	var pivot := gx - FOOT_HEEL if p >= 0.0 else gx + FOOT_BALL
	var o := Vector2(FOOT_HEEL if p >= 0.0 else -FOOT_BALL, FOOT_UP)
	return Vector2(pivot + o.x * cos(p) - o.y * sin(p), sole + o.x * sin(p) + o.y * cos(p))


## A foot at cycle point `ph` (0 touchdown, stance until _gt_beta, then
## swing): ankle x, y, ground pitch, and the knee bend that sets the hip
## height while it bears weight (w).
func _foot(ph: float) -> Vector4:
	var ls := _gt_ls
	if ph < _gt_beta:
		var sp := ph / _gt_beta
		var p := 0.0
		if sp < 0.15:
			p = lerpf(_gt_p1, 0.0, smoothstep(0.0, 0.15, sp))
		elif sp > 0.55:
			p = lerpf(0.0, _gt_p0, smoothstep(0.55, 1.0, sp))
		var a := _ankle(_gt_c * ls - ls * sp, p)
		return Vector4(a.x, a.y, p, _stance_knee(sp))
	var u := (ph - _gt_beta) / (1.0 - _gt_beta)
	var a0 := _ankle(_gt_c * ls - ls, _gt_p0)
	var a1 := _ankle(_gt_c * ls, _gt_p1)
	# Hermite: leaves moving back with the ground and lands moving back with
	# it (all of the ground speed in a walk, nine tenths in a run, where
	# the foot reaches a little past the contact point and paws back).
	var u2 := u * u
	var u3 := u2 * u
	var x := (2.0 * u3 - 3.0 * u2 + 1.0) * a0.x + (u3 - 2.0 * u2 + u) * _gt_tan \
		+ (3.0 * u2 - 2.0 * u3) * a1.x + (u3 - u2) * _gt_tan
	var y := lerpf(a0.y, a1.y, u) + _gt_peak * _bump(u)
	var p := lerpf(_gt_p0, _gt_p1, smoothstep(0.2, 0.9, u))
	return Vector4(x, y, p, lerpf(_stance_knee(1.0), _stance_knee(0.0), u))


## Swing lift: up early (the heel kicks up in a run), down late.
func _bump(u: float) -> float:
	return smoothstep(0.0, _gt_rise, u) * (1.0 - smoothstep(_gt_late, 1.0, u))


## Authored knee bend through stance (sp 0..1): a walk loads a little and
## vaults over a nearly straight leg, a run compresses to about 43 degrees.
func _stance_knee(sp: float) -> float:
	var walk := 0.08 + 0.2 * sin(PI * minf(sp / 0.35, 1.0)) + 0.55 * smoothstep(0.6, 1.0, sp)
	var k0 := 0.25 + 0.05 * _gt_sprint
	var km := 0.75 + 0.05 * _gt_sprint
	var run := lerpf(k0, km, smoothstep(0.0, 0.45, sp)) if sp < 0.45 \
		else lerpf(km, 0.2, smoothstep(0.45, 1.0, sp))
	return lerpf(walk, run, _gt_g)


## How high the hips may be for a foot at (x, y) with the knee bent k.
func _reach(x: float, y: float, k: float) -> float:
	var d2 := _thigh * _thigh + _shin * _shin + 2.0 * _thigh * _shin * cos(k)
	return y + sqrt(maxf(d2 - x * x, 0.0))


## Hip height (rest units) for this point of the cycle: a walk takes the
## lowest the feet allow with their knee bends (it dips in double support
## and rises over the planted leg); a run sinks from touchdown to mid-stance,
## rises to toe-off and flies on a ballistic arc to the next touchdown.
## Never higher than nearly straight legs can reach the feet.
func _gait_height(feet: Array[Vector4]) -> float:
	var walk := INF
	var cap := INF
	for t in feet:
		walk = minf(walk, _reach(t.x, t.y, t.w))
		cap = minf(cap, _reach(t.x, t.y, 0.12))
	var hgt := walk
	if _gt_g > 0.0:
		var ls := _gt_ls
		var sig := minf(2.0 * _gt_beta, 1.0)
		var q := fposmod(phase / TAU - 0.25, 0.5) * 2.0
		var a0 := _ankle(_gt_c * ls - ls, _gt_p0)
		var a1 := _ankle(_gt_c * ls, _gt_p1)
		var am := _ankle(_gt_c * ls - ls * 0.45, 0.0)
		var h_off := _reach(a0.x, a0.y, _stance_knee(1.0))
		var h_on := _reach(a1.x, a1.y, _stance_knee(0.0))
		var h_mid := _reach(am.x, am.y, _stance_knee(0.45))
		var r := 0.0
		if q < sig:
			var sp := q / sig
			r = lerpf(h_on, h_mid, smoothstep(0.0, 0.45, sp)) if sp < 0.45 \
				else lerpf(h_mid, h_off, smoothstep(0.45, 1.0, sp))
		else:
			var u := (q - sig) / (1.0 - sig)
			var tf := (1.0 - sig) * 0.5 / _gt_f
			r = lerpf(h_off, h_on, smoothstep(0.0, 1.0, u)) + 9.8 / skeleton.scale.y * tf * tf * 0.5 * u * (1.0 - u)
		hgt = lerpf(walk, r, _gt_g)
	return minf(hgt, cap)


## Thigh angle (forward +) and knee bend for an ankle at (x, y) from the
## hip (y negative, down), by the law of cosines; the knee bends forward.
func _leg_ik(x: float, y: float) -> Vector2:
	var t := _thigh
	var sh := _shin
	var d := clampf(sqrt(x * x + y * y), absf(t - sh) + 0.01, (t + sh) * 0.999)
	var knee := acos(clampf((t * t + sh * sh - d * d) / (2.0 * t * sh), -1.0, 1.0))
	var inner := acos(clampf((t * t + d * d - sh * sh) / (2.0 * t * d), -1.0, 1.0))
	return Vector2(atan2(x, -y) + inner, PI - knee)


## Weight on one leg, the other knee easy, shoulders tilted against the
## hips, breathing.
func _stance(still: float, delta: float) -> void:
	_weight = lerpf(_weight, _weight_side, 1.0 - exp(-3.0 * delta))
	var w := _weight * still
	_target[HIPS].z += -0.06 * w
	_target[SPINE].z += 0.07 * w
	_target[HEAD].z += 0.04 * w
	var relaxed_leg := R_LEG if w > 0.0 else L_LEG
	var relaxed_shin := R_SHIN if w > 0.0 else L_SHIN
	var aw := absf(w)
	_target[relaxed_leg].x += 0.12 * aw
	_target[relaxed_shin].x -= 0.24 * aw
	_target[L_LEG].z += 0.06 * w - 0.03 * still
	_target[R_LEG].z += 0.06 * w + 0.03 * still
	_target[CHEST].x += sin(_time * 2.2) * 0.025 * still
	_target[L_ARM].z -= 0.06 * still
	_target[R_ARM].z += 0.06 * still
	_target[L_FORE].x += 0.12 * still
	_target[R_FORE].x += 0.12 * still


## Little steps round when the body turns on the spot.
func _turn_in_place(s: State, still: float, delta: float) -> void:
	var t := clampf((absf(s.turn) - 0.5) / 3.0, 0.0, 1.0) * still
	if t <= 0.0:
		return
	_step_phase = fmod(_step_phase + delta * 10.0, TAU)
	var sg := signf(s.turn)
	var l := maxf(0.0, sin(_step_phase))
	var r := maxf(0.0, -sin(_step_phase))
	_target[L_LEG].x += 0.3 * l * t
	_target[L_SHIN].x -= 0.6 * l * t
	_target[R_LEG].x += 0.3 * r * t
	_target[R_SHIN].x -= 0.6 * r * t
	_target[L_LEG].y += 0.25 * sg * l * t
	_target[R_LEG].y += 0.25 * sg * r * t
	_target[CHEST].y += 0.15 * sg * t
	_target[HEAD].y += 0.35 * sg * t


func _style(s: State, moving: float, run: float) -> void:
	var sw := sin(phase)
	match s.style:
		"elderly":
			_target[SPINE].x -= 0.3
			_target[NECK].x += 0.12
			_target[HEAD].x += 0.22
			_target[L_FORE].x += 0.2
			_target[R_FORE].x += 0.2
		"patrol":
			# Thumbs in the belt, chest up, eyes sweeping the street.
			_target[L_ARM] = Vector3(-0.05 - sw * 0.05 * moving, 0.0, -0.32)
			_target[R_ARM] = Vector3(-0.05 + sw * 0.05 * moving, 0.0, 0.32)
			_target[L_FORE] = Vector3(1.25, -0.55, 0.0)
			_target[R_FORE] = Vector3(1.25, 0.55, 0.0)
			_target[SPINE].x += 0.06
			_target[HEAD].y += sin(_time * 0.5) * 0.45
		"carry":
			# Bags in both hands: arms straight, held clear of the legs.
			_target[L_ARM] = Vector3(-sw * 0.08 * moving, 0.0, -0.2)
			_target[R_ARM] = Vector3(sw * 0.08 * moving, 0.0, 0.2)
			_target[L_FORE].x = 0.1
			_target[R_FORE].x = 0.1
			_target[SPINE].x += 0.04
		"rain":
			# Hurrying with a hand over the head, hunched.
			_target[R_ARM] = Vector3(2.35, 0.0, 0.55)
			_target[R_FORE] = Vector3(1.9, 0.0, 0.0)
			_target[SPINE].x -= 0.2
			_target[HEAD].x -= 0.15
		"pockets":
			_target[L_ARM] = Vector3(-0.15 - sw * 0.04 * moving, 0.0, -0.12)
			_target[R_ARM] = Vector3(-0.15 + sw * 0.04 * moving, 0.0, 0.12)
			_target[L_FORE] = Vector3(0.55, -0.3, 0.0)
			_target[R_FORE] = Vector3(0.55, 0.3, 0.0)
		"swagger":
			_target[SPINE].x += 0.07
			_target[HEAD].x += 0.05 * sin(2.0 * phase) * moving
			_target[L_FORE].x -= 0.08
			_target[R_FORE].x -= 0.08
		"panic":
			# Arms higher and looser, hunched, a look back now and then.
			_target[L_ARM].z -= 0.3 * moving
			_target[R_ARM].z += 0.3 * moving
			_target[L_FORE].x = 0.9 + 0.3 * maxf(0.0, -sw) * moving
			_target[R_FORE].x = 0.9 + 0.3 * maxf(0.0, sw) * moving
			_target[SPINE].x -= 0.1
			var back := smoothstep(0.7, 0.95, sin(_time * 2.1))
			_target[HEAD].y += 1.0 * back * (1.0 if fmod(floorf(_time * 2.1 / TAU), 2.0) == 0.0 else -1.0)
			_target[CHEST].y += 0.3 * back
		"limp":
			# Holding the bad right side, leaning off it.
			_target[R_ARM] = Vector3(0.15, 0.0, 0.25)
			_target[R_FORE].x = 1.1
			_target[L_ARM].z -= 0.12
			_target[SPINE].z -= 0.08 * moving
			_target[SPINE].x -= 0.08
		"sprint":
			_target[L_FORE].x = maxf(_target[L_FORE].x, 1.1)
			_target[R_FORE].x = maxf(_target[R_FORE].x, 1.1)
		"jog":
			_target[L_FORE].x = maxf(_target[L_FORE].x, 1.3)
			_target[R_FORE].x = maxf(_target[R_FORE].x, 1.3)
			_target[SPINE].x -= 0.04 * run


## Idle acts: now and then, when standing with nothing else to do.
func _idle(s: State, delta: float, eligible: bool) -> void:
	if not eligible:
		_idle_clock = 0.0
		_idle_act = -1
		_idle_next = 2.0 + float(s.idle_seed % 5) * 0.6
		return
	_idle_clock += delta
	if _idle_act < 0:
		if _idle_clock >= _idle_next:
			_idle_count += 1
			# A stride prime to the list's length walks through every act
			# before any comes round again; the seed sets where and which way.
			var stride := 3 if s.idle_seed % 2 == 0 else 5
			_idle_act = (s.idle_seed * 5 + _idle_count * stride) % IDLE_ACTS.size()
			_idle_start = _idle_clock
			if IDLE_ACTS[_idle_act][0] == "shift":
				_weight_side = -_weight_side
		return
	var dur: float = IDLE_ACTS[_idle_act][1]
	var t := (_idle_clock - _idle_start) / dur
	if t >= 1.0:
		_idle_act = -1
		_idle_next = _idle_clock + 2.5 + fmod(float(s.idle_seed) * 0.37 + float(_idle_count) * 1.7, 4.0)
		return
	var e := smoothstep(0.0, 0.18, t) * (1.0 - smoothstep(0.82, 1.0, t))
	match IDLE_ACTS[_idle_act][0]:
		"look_around":
			var y := sin(t * TAU) * e
			_target[HEAD].y += 0.7 * y
			_target[NECK].y += 0.2 * y
			_target[CHEST].y += 0.12 * y
		"check_watch":
			_mix(L_ARM, Vector3(0.95, 0.0, 0.35), e)
			_mix(L_FORE, Vector3(2.1, -0.3, 0.0), e)
			_target[HEAD].x -= 0.4 * e
			_target[HEAD].y += 0.2 * e
		"stretch":
			_mix(L_ARM, Vector3(0.2, 0.0, -2.8), e)
			_mix(R_ARM, Vector3(0.2, 0.0, 2.8), e)
			_mix(L_FORE, Vector3(0.3, 0.0, 0.0), e)
			_mix(R_FORE, Vector3(0.3, 0.0, 0.0), e)
			_target[SPINE].x += 0.15 * e
			_target[HEAD].x += 0.25 * e
		"scratch_head":
			_mix(R_ARM, Vector3(1.3, 0.0, 1.1), e)
			_mix(R_FORE, Vector3(2.3 + sin(_time * 40.0) * 0.08, 0.0, 0.0), e)
			_target[HEAD].z -= 0.15 * e
			_target[HEAD].x -= 0.1 * e
		"arms_crossed":
			_arms_crossed(e)
		"hands_hips":
			_mix(L_ARM, Vector3(-0.15, 0.0, -0.6), e)
			_mix(R_ARM, Vector3(-0.15, 0.0, 0.6), e)
			_mix(L_FORE, Vector3(1.4, -1.0, 0.0), e)
			_mix(R_FORE, Vector3(1.4, 1.0, 0.0), e)
		"phone_glance":
			_mix(R_ARM, Vector3(0.3, 0.0, -0.05), e)
			_mix(R_FORE, Vector3(1.3, 0.35, 0.0), e)
			_target[HEAD].x -= 0.35 * e


func _arms_crossed(e: float) -> void:
	_mix(L_ARM, Vector3(0.55, 0.0, 0.45), e)
	_mix(R_ARM, Vector3(0.6, 0.0, -0.45), e)
	_mix(L_FORE, Vector3(2.0, -0.9, 0.0), e)
	_mix(R_FORE, Vector3(2.05, 0.9, 0.0), e)


## Right forearm up with the phone screen facing the face, head bowed; the
## left arm keeps swinging.
func _texting() -> void:
	_target[R_ARM] = Vector3(0.3, 0.0, -0.05)
	_target[R_FORE] = Vector3(1.3, 0.35, 0.0)
	_target[HEAD].x -= 0.35


func _guard() -> void:
	# Orthodox stance: left side leads, fists at the chin, elbows in, knees
	# soft, bouncing on the balls of the feet like a boxer.
	var still := 1.0 - _moving
	_target[L_ARM] = Vector3(0.75, 0.0, 0.3)
	_target[R_ARM] = Vector3(0.5, 0.0, -0.3)
	_target[L_FORE] = Vector3(2.05, 0.35, 0.0)
	_target[R_FORE] = Vector3(2.25, -0.35, 0.0)
	_target[CHEST].y = -0.3
	_target[HIPS].y = lerpf(_target[HIPS].y, -0.2, still)
	_target[HEAD].y = 0.45
	_target[HEAD].x = 0.12 # chin down
	_target[SPINE].x -= 0.08
	if still <= 0.0:
		return
	var b := 0.5 + 0.5 * sin(_time * TAU * 2.2)
	_fight_legs(0.3 + 0.1 * b, 0.0, still)


## Feet apart in a fighting stance, left ahead, both knees bent by `flex`;
## `heel` lifts the rear heel (the pivot of a cross).
func _fight_legs(flex: float, heel: float, w: float) -> void:
	_mix(L_LEG, Vector3(0.22, 0.0, -0.06), w)
	_mix(R_LEG, Vector3(-0.22, 0.0, 0.06), w)
	_mix(L_SHIN, Vector3(-flex, 0.0, 0.0), w)
	_mix(R_SHIN, Vector3(-flex - 0.2 * heel, 0.0, 0.0), w)
	_mix(L_FOOT, Vector3(-(0.22 - flex), 0.0, 0.0), w)
	_mix(R_FOOT, Vector3(-(-0.22 - flex - 0.2 * heel) - 0.5 * heel, 0.0, 0.0), w)


## A punch from the guard, p 0..1: a short load (the fist draws back, the
## body coils), the strike thrown from the hips with the shoulders turning
## through and the weight going forward, a beat held, then back to guard.
## The right hand is a straight cross off a pivoting rear heel; the left
## (the second of a combo) a hook swung round by the trunk.
func _punch(p: float, left: bool) -> void:
	_guard()
	var a := sin(PI * clampf(p / 0.2, 0.0, 1.0)) # load
	var e := smoothstep(0.1, 0.36, p) * (1.0 - smoothstep(0.55, 1.0, p))
	if left:
		# Elbow out at shoulder height, the forearm twisted level so the
		# fist comes round across the chin.
		_target[L_ARM] = Vector3(lerpf(0.75, 1.4, e) - 0.15 * a, 0.0, lerpf(0.3, -0.5, e))
		_target[L_FORE] = Vector3(lerpf(2.05, 1.6, e), lerpf(0.35, 1.2, e), 0.0)
		_target[CHEST].y = -0.3 + 0.2 * a - 0.55 * e
		_target[HIPS].y = -0.2 + 0.1 * a - 0.35 * e
		_target[SPINE].z = -0.1 * e
		_target[SPINE].x -= 0.06 * e
	else:
		_target[R_ARM] = Vector3(lerpf(0.5, 1.5, e) - 0.2 * a, 0.0, lerpf(-0.3, -0.22, e))
		_target[R_FORE] = Vector3(lerpf(2.25, 0.08, e), lerpf(-0.35, 0.0, e), 0.0)
		_target[CHEST].y = -0.3 - 0.15 * a + 0.75 * e
		_target[HIPS].y = -0.2 - 0.05 * a + 0.4 * e
		_target[SPINE].x -= 0.16 * e
	_target[HEAD].y = -(_target[HIPS].y + _target[CHEST].y) * 0.9
	_fight_legs(0.3 + 0.08 * a, 0.0 if left else e, 1.0 - _moving)


## A push kick with the rear (right) leg, p 0..1: the knee comes up to the
## chest, the foot drives out from the hip with the body leaning back and
## the arms out for balance, snaps back to the chamber, then down.
func _kick(p: float) -> void:
	var c := smoothstep(0.0, 0.3, p) * (1.0 - smoothstep(0.72, 1.0, p))
	var e := smoothstep(0.26, 0.46, p) * (1.0 - smoothstep(0.56, 0.78, p))
	var thigh := 1.45 * c - 0.1 * e
	var flex := lerpf(2.0, 0.12, e) * c
	_target[R_LEG] = Vector3(thigh, 0.0, 0.05 * c)
	_target[R_SHIN] = Vector3(-flex, 0.0, 0.0)
	_target[R_FOOT] = Vector3(lerpf(-0.35, 0.3, e) * c, 0.0, 0.0)
	# The standing leg bends a little and stays planted.
	var sf := 0.15 + 0.25 * c
	_target[L_LEG] = Vector3(0.1 * c, 0.0, -0.04)
	_target[L_SHIN] = Vector3(-sf, 0.0, 0.0)
	_target[L_FOOT] = Vector3(-(0.1 * c - sf), 0.0, 0.0)
	_target[SPINE].x = 0.12 * c + 0.3 * e
	_target[HEAD].x = -0.08 * c - 0.25 * e
	_target[CHEST].y = -0.15 * c
	_target[HIPS].y = 0.0
	_target[HEAD].y = 0.15 * c
	# Fists up in the chamber; the arms open out for balance on the thrust.
	_target[L_ARM] = Vector3(lerpf(0.75, 0.55, e), 0.0, lerpf(0.3, -0.55, e))
	_target[R_ARM] = Vector3(lerpf(0.5, -0.45, e), 0.0, lerpf(-0.3, 0.5, e))
	_target[L_FORE] = Vector3(lerpf(2.05, 1.3, e), 0.0, 0.0)
	_target[R_FORE] = Vector3(lerpf(2.25, 0.7, e), 0.0, 0.0)


## One-shot reactions, t 0..1.
func _action(a: String, t: float, side: float) -> void:
	match a:
		"startle":
			# Jump back from it: lean away, hands up, knees give, a hop.
			var e := smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.45, 1.0, t))
			_target[SPINE].x += 0.35 * e
			_target[HEAD].x += 0.2 * e
			_mix(L_ARM, Vector3(0.9, 0.0, -0.7), e)
			_mix(R_ARM, Vector3(0.9, 0.0, 0.7), e)
			_mix(L_FORE, Vector3(1.7, 0.0, 0.0), e)
			_mix(R_FORE, Vector3(1.7, 0.0, 0.0), e)
			_target[L_LEG].x += 0.35 * e
			_target[R_LEG].x += 0.25 * e
			_target[L_SHIN].x -= 0.6 * e
			_target[R_SHIN].x -= 0.5 * e
			_add_lift += 0.08 * sin(PI * clampf(t / 0.35, 0.0, 1.0))
		"dodge":
			# A sideways leap out of the way, arms flung out.
			var e := smoothstep(0.0, 0.1, t) * (1.0 - smoothstep(0.55, 1.0, t))
			var push_leg := L_LEG if side > 0.0 else R_LEG
			var lead_shin := R_SHIN if side > 0.0 else L_SHIN
			_target[push_leg].z += -side * 0.5 * e
			_target[lead_shin].x -= 0.7 * e
			_mix(L_ARM, Vector3(0.6, 0.0, -1.3), e)
			_mix(R_ARM, Vector3(0.6, 0.0, 1.3), e)
			_target[SPINE].x -= 0.25 * e
			_target[HEAD].y += side * 0.5 * e # eyes back on the car
			_add_roll += -side * 0.3 * e
			_add_lift += 0.12 * sin(PI * clampf(t / 0.5, 0.0, 1.0))
		"duck":
			var e := smoothstep(0.0, 0.1, t) * (1.0 - smoothstep(0.7, 1.0, t))
			_mix(L_LEG, Vector3(1.2, 0.0, -0.1), e)
			_mix(R_LEG, Vector3(1.2, 0.0, 0.1), e)
			_mix(L_SHIN, Vector3(-2.0, 0.0, 0.0), e)
			_mix(R_SHIN, Vector3(-2.0, 0.0, 0.0), e)
			_mix(L_FOOT, Vector3(0.6, 0.0, 0.0), e)
			_mix(R_FOOT, Vector3(0.6, 0.0, 0.0), e)
			_target[SPINE].x -= 0.6 * e
			_target[HEAD].x -= 0.3 * e
			_cover_head(e)
		"stumble":
			var e := smoothstep(0.0, 0.15, t) * (1.0 - smoothstep(0.5, 1.0, t))
			_target[SPINE].x -= 0.5 * e
			_target[HEAD].x += 0.3 * e
			_mix(L_ARM, Vector3(1.3, 0.0, -0.5), e)
			_mix(R_ARM, Vector3(1.3, 0.0, 0.5), e)
			_mix(L_FORE, Vector3(0.4, 0.0, 0.0), e)
			_mix(R_FORE, Vector3(0.4, 0.0, 0.0), e)
			_target[L_LEG].x += 0.5 * e
			_target[L_SHIN].x -= 0.4 * e


func _cover_head(e: float) -> void:
	_mix(L_ARM, Vector3(2.2, 0.0, -0.6), e)
	_mix(R_ARM, Vector3(2.2, 0.0, 0.6), e)
	_mix(L_FORE, Vector3(2.2, 0.0, 0.0), e)
	_mix(R_FORE, Vector3(2.2, 0.0, 0.0), e)


## Falling (f 0..1) then lying: on the back, or on the front when face_down.
## Alive, the chest heaves and a knee rocks; dead, a still splay that varies
## by idle_seed.
func _lying(s: State, f: float) -> void:
	var v := s.idle_seed % 3
	if s.face_down:
		_target[L_ARM] = Vector3(2.4, 0.0, -0.5 - 0.3 * v)
		_target[R_ARM] = Vector3(1.9 - 0.5 * v, 0.0, 0.7)
		_target[L_FORE].x = 0.9
		_target[R_FORE].x = 0.5 + 0.4 * v
		_target[HEAD].y = 1.0 if v != 1 else -1.0
		_target[R_LEG] = Vector3(0.45, 0.0, 0.35)
		_target[R_SHIN].x = -0.9
		_target[L_LEG].z = -0.12
	else:
		_target[L_ARM] = Vector3(0.2, 0.0, -1.2 + 0.4 * v)
		_target[R_ARM] = Vector3(0.2 + 0.3 * v, 0.0, 1.0)
		_target[L_FORE].x = 0.4
		_target[R_FORE].x = 0.9 - 0.3 * v
		_target[L_LEG].z = -0.15 - 0.1 * v
		_target[R_LEG] = Vector3(0.35 - 0.15 * v, 0.0, 0.15 + 0.1 * v)
		_target[R_SHIN].x = -0.7 + 0.25 * v
		_target[HEAD].y = 0.4 - 0.4 * v
	if f < 1.0:
		# On the way down: knees buckle, arms fling out to break the fall,
		# the head tucks.
		var e := 1.0 - f
		var buckle := sin(PI * f)
		_target[L_SHIN].x -= 0.9 * buckle
		_target[R_SHIN].x -= 1.0 * buckle
		_target[L_LEG].x += 0.5 * buckle
		_target[R_LEG].x += 0.4 * buckle
		if s.face_down:
			_mix(L_ARM, Vector3(1.5, 0.0, -0.3), e)
			_mix(R_ARM, Vector3(1.5, 0.0, 0.3), e)
			_mix(L_FORE, Vector3(0.2, 0.0, 0.0), e)
			_mix(R_FORE, Vector3(0.2, 0.0, 0.0), e)
			_target[HEAD].x += 0.4 * e
		else:
			_mix(L_ARM, Vector3(1.0, 0.0, -0.9), e)
			_mix(R_ARM, Vector3(1.0, 0.0, 0.9), e)
			_target[HEAD].x -= 0.4 * e
			_target[SPINE].x -= 0.3 * buckle
	elif not s.dead:
		_target[CHEST].x += sin(_time * 3.0) * 0.05
		_target[R_LEG].x += 0.15 * sin(_time * 1.3)
		_target[R_SHIN].x -= 0.15 * (1.0 + sin(_time * 1.3))
		_target[HEAD].x += 0.1 * sin(_time * 0.9)


## Getting up, g 0..1: roll up (or push up off the front) into a crouch,
## then stand. Returns the body tilt and the hip lift at height 1.
func _get_up(g: float, face_down: bool) -> Vector2:
	var a := smoothstep(0.0, 0.35, g) # off the ground
	var b := smoothstep(0.3, 0.7, g) # into a crouch
	var c := smoothstep(0.68, 1.0, g) # standing
	var squat := b * (1.0 - c)
	var tuck := a * (1.0 - c)
	var lying := PI / 2.0 * (-1.0 if face_down else 1.0)
	var tilt := lerpf(lying, lying * 0.6, a)
	tilt = lerpf(tilt, 0.1 * signf(lying), b)
	tilt = lerpf(tilt, 0.0, c)
	_target[L_LEG] = Vector3(lerpf(0.0, 1.45, tuck), 0.0, -0.1 * tuck)
	_target[R_LEG] = Vector3(lerpf(0.0, 1.35, tuck), 0.0, 0.1 * tuck)
	_target[L_SHIN].x = -2.2 * tuck
	_target[R_SHIN].x = -2.2 * tuck
	_target[L_FOOT].x = 0.6 * squat
	_target[R_FOOT].x = 0.6 * squat
	_target[SPINE].x = -0.7 * tuck + 0.2 * squat
	_target[HEAD].x = 0.2 * tuck
	if face_down:
		# Hands under the shoulders, pushing up.
		var push := a * (1.0 - b)
		_target[L_ARM] = Vector3(1.5 * push + 0.6 * squat, 0.0, -0.2)
		_target[R_ARM] = Vector3(1.5 * push + 0.6 * squat, 0.0, 0.2)
		_target[L_FORE].x = 1.2 * (1.0 - a) + 0.5 * squat
		_target[R_FORE].x = 1.2 * (1.0 - a) + 0.5 * squat
	else:
		# Hands behind, pushing off the ground, then forward for balance.
		var push := a * (1.0 - b)
		_target[L_ARM] = Vector3(-0.6 * push + 0.8 * squat, 0.0, -0.4 * push - 0.1)
		_target[R_ARM] = Vector3(-0.6 * push + 0.8 * squat, 0.0, 0.4 * push + 0.1)
		_target[L_FORE].x = 0.2 + 0.5 * squat
		_target[R_FORE].x = 0.2 + 0.5 * squat
	var lie_lift := 0.17 if face_down else 0.14
	var lift := lerpf(lie_lift, 0.0, a)
	lift = lerpf(lift, -0.47, b)
	lift = lerpf(lift, 0.0, c)
	return Vector2(tilt, lift)


func _ride() -> void:
	_target[L_LEG].x = 1.35
	_target[R_LEG].x = 1.35
	_target[L_LEG].z = -0.12
	_target[R_LEG].z = 0.12
	_target[L_SHIN].x = -1.25
	_target[R_SHIN].x = -1.25
	_target[SPINE].x = -0.2
	_target[L_ARM] = Vector3(1.1, 0.0, 0.1)
	_target[R_ARM] = Vector3(1.1, 0.0, -0.1)
	_target[L_FORE].x = 0.35
	_target[R_FORE].x = 0.35


## Feet on the pedals of a bike whose crank is at angle `a` (0: right
## pedal at the top, turning forward), by two-bone IK on the crank placed by
## PEDAL_*; leaning on the bars.
func _pedal(a: float, h: float) -> void:
	for leg in [[R_LEG, R_SHIN, R_FOOT, 0.0], [L_LEG, L_SHIN, L_FOOT, PI]]:
		var t: float = a + leg[3]
		var fwd := PEDAL_CRANK.x + sin(t) * PEDAL_ARM
		var down := PEDAL_HIP_Y - PEDAL_CRANK.y - cos(t) * PEDAL_ARM - 0.08 * h
		var span := (_thigh + _shin) * h
		var reach := minf(Vector2(fwd, down).length(), 0.99 * span)
		var bend := acos(reach / span)
		var thigh := atan2(fwd, down) + bend
		_target[leg[0]].x = thigh
		_target[leg[1]].x = -2.0 * bend
		_target[leg[2]].x = -0.7 * (thigh - 2.0 * bend)
	_target[SPINE].x = -0.3
	_target[HEAD].x = 0.25
	_target[L_ARM] = Vector3(0.45, 0.0, 0.05)
	_target[R_ARM] = Vector3(0.45, 0.0, -0.05)
	_target[L_FORE].x = 0.85
	_target[R_FORE].x = 0.85


## In an open car's seat (on top of _sit): legs out into the footwell, the
## back against the reclined seat and both hands on the wheel at ten to
## two (driving) or on the lap.
func _car_seat(driving: bool) -> void:
	_target[L_LEG] = Vector3(1.55, 0.0, -0.08)
	_target[R_LEG] = Vector3(1.55, 0.0, 0.08)
	_target[L_SHIN].x = -0.3
	_target[R_SHIN].x = -0.3
	_target[SPINE].x = 0.15
	var arm := Vector3(0.9, 0.0, 0.25) if driving else Vector3(0.4, 0.0, 0.15)
	var fore := 0.6 if driving else 0.4
	_target[L_ARM] = arm
	_target[R_ARM] = Vector3(arm.x, 0.0, -arm.z)
	_target[L_FORE].x = fore
	_target[R_FORE].x = fore


## Thighs level, shins down, hands resting on the table or knees.
func _sit() -> void:
	_target[L_LEG] = Vector3(1.5, 0.0, -0.06)
	_target[R_LEG] = Vector3(1.5, 0.0, 0.06)
	_target[L_SHIN].x = -1.5
	_target[R_SHIN].x = -1.5
	_target[SPINE].x = 0.05
	_target[L_ARM] = Vector3(0.45, 0.0, -0.1)
	_target[R_ARM] = Vector3(0.45, 0.0, 0.1)
	_target[L_FORE].x = 1.0
	_target[R_FORE].x = 1.0
	_target[CHEST].x = sin(_time * 2.0) * 0.02


func _gesture(g: String) -> void:
	var wave := sin(_time * 9.0)
	match g:
		"phone", "call":
			# Phone at the ear; on a call the free hand talks too.
			_target[R_ARM] = Vector3(0.35, 0.0, 0.55)
			_target[R_FORE].x = 2.5
			_target[HEAD].z = 0.15
			if g == "call":
				_target[L_ARM] = Vector3(0.35 + 0.15 * sin(_time * 1.7), 0.0, -0.2)
				_target[L_FORE].x = 1.1 + sin(_time * 2.6) * 0.4
				_target[HEAD].y += sin(_time * 0.7) * 0.25
		"talk", "listen":
			if g == "talk":
				_target[L_ARM] = Vector3(0.35, 0.0, -0.2)
				_target[R_ARM] = Vector3(0.3, 0.0, 0.2)
				_target[L_FORE].x = 1.1 + sin(_time * 3.1) * 0.35
				_target[R_FORE].x = 1.0 + sin(_time * 2.3 + 1.0) * 0.4
				_target[HEAD].y = sin(_time * 1.3) * 0.15
			else:
				# Hands loosely together, nodding along.
				_target[L_ARM] = Vector3(0.3, 0.0, 0.2)
				_target[R_ARM] = Vector3(0.3, 0.0, -0.2)
				_target[L_FORE] = Vector3(1.0, -0.6, 0.0)
				_target[R_FORE] = Vector3(1.0, 0.6, 0.0)
				_target[HEAD].x = -0.05 + 0.1 * maxf(0.0, sin(_time * 3.4)) * maxf(0.0, sin(_time * 0.8))
				_target[HEAD].z = 0.06
		"wave":
			_target[R_ARM] = Vector3(0.2, 0.0, 2.5)
			_target[R_FORE].z = 0.4 * wave
		"hands_up":
			_target[L_ARM] = Vector3(0.0, 0.0, -2.6)
			_target[R_ARM] = Vector3(0.0, 0.0, 2.6)
			_target[L_FORE].z = 0.4
			_target[R_FORE].z = -0.4
		"cower":
			_target[SPINE].x = -0.55
			_target[HEAD].x = -0.3
			_target[L_ARM] = Vector3(2.3, 0.0, 0.3)
			_target[R_ARM] = Vector3(2.3, 0.0, -0.3)
			_target[L_FORE].x = 1.8
			_target[R_FORE].x = 1.8
			_target[L_LEG].x = 0.6
			_target[R_LEG].x = 0.6
			_target[L_SHIN].x = -1.1
			_target[R_SHIN].x = -1.1
			_target[L_FOOT].x = 0.5
			_target[R_FOOT].x = 0.5
			# Trembling.
			_target[CHEST].z = sin(_time * 23.0) * 0.03
		"point":
			_target[R_ARM] = Vector3(1.5, 0.0, 0.1)
			_target[R_FORE].x = 0.05
		"eat":
			# Fork to mouth every couple of seconds, the other hand on the table.
			var bite := smoothstep(0.55, 0.85, absf(sin(_time * 1.4)))
			_target[R_ARM] = Vector3(0.45 + 0.35 * bite, 0.0, 0.15)
			_target[R_FORE].x = 1.1 + 1.2 * bite
			_target[L_ARM] = Vector3(0.6, 0.0, -0.1)
			_target[L_FORE].x = 1.1
			_target[HEAD].x = -0.15 + 0.1 * bite
		"browse":
			# Looking along a shelf, now and then reaching for something.
			var reach := smoothstep(0.6, 0.9, sin(_time * 0.9))
			_target[HEAD].y = sin(_time * 0.6) * 0.35
			_target[HEAD].x = 0.05 - 0.1 * reach
			_target[R_ARM] = Vector3(0.3 + 1.0 * reach, 0.0, 0.1)
			_target[R_FORE].x = 0.9 - 0.6 * reach
			_target[L_ARM].x = 0.25
			_target[L_FORE].x = 1.4
		"work":
			# Hands busy at counter height: ringing up, wiping, cooking.
			_target[L_ARM] = Vector3(0.55 + sin(_time * 2.3) * 0.12, 0.0, -0.1)
			_target[R_ARM] = Vector3(0.6 + sin(_time * 3.1 + 1.0) * 0.15, 0.0, 0.1)
			_target[L_FORE].x = 0.9
			_target[R_FORE].x = 0.8 + sin(_time * 4.0) * 0.2
			_target[HEAD].x = -0.2
			_target[SPINE].x = -0.08
		"shopkeeper":
			# Hands on the counter, eyes on the shop, a wipe now and then.
			var wipe := smoothstep(0.5, 0.8, sin(_time * 0.6))
			_target[L_ARM] = Vector3(0.55, 0.0, -0.14)
			_target[R_ARM] = Vector3(0.55 + 0.1 * wipe, 0.0, 0.14 + 0.25 * wipe * sin(_time * 5.0))
			_target[L_FORE].x = 0.9
			_target[R_FORE].x = 0.9
			_target[HEAD].y = sin(_time * 0.45) * 0.45 * (1.0 - wipe)
			_target[HEAD].x = -0.25 * wipe
			_target[SPINE].x = -0.06
		"pay":
			_target[R_ARM] = Vector3(0.95, 0.0, 0.05)
			_target[R_FORE].x = 0.55
			_target[HEAD].x = -0.1
		"search":
			_target[SPINE].x = -0.6
			_target[HEAD].x = -0.3
			_target[L_ARM].x = 0.9 + wave * 0.15
			_target[R_ARM].x = 0.9 - wave * 0.15
			_target[L_FORE].x = 0.4
			_target[R_FORE].x = 0.4
		"smoke":
			# A drag every few seconds; the other arm folded under it.
			var puff := smoothstep(0.55, 0.9, sin(_time * 1.3))
			_target[R_ARM] = Vector3(0.35 + 0.6 * puff, 0.0, 0.1 + 0.3 * puff)
			_target[R_FORE].x = 1.3 + 1.0 * puff
			_target[L_ARM] = Vector3(0.45, 0.0, 0.35)
			_target[L_FORE] = Vector3(1.7, -0.8, 0.0)
			_target[HEAD].x = 0.12 * smoothstep(0.9, 0.2, sin(_time * 1.3 - 0.6)) * (1.0 - puff)
		"argue":
			# Leaning in, jabbing a finger, the other hand thrown out.
			_target[SPINE].x = -0.15
			_target[R_ARM] = Vector3(0.9 + 0.35 * sin(_time * 4.0), 0.0, 0.25)
			_target[R_FORE].x = 0.5 + 0.4 * maxf(0.0, sin(_time * 4.0 + 1.0))
			_target[L_ARM] = Vector3(0.5, 0.0, -0.5 - 0.3 * sin(_time * 3.0))
			_target[L_FORE].x = 1.2
			_target[HEAD].x = 0.1 + 0.08 * sin(_time * 7.0)
			_target[CHEST].y = 0.15 * sin(_time * 2.3)
		"shake_fist":
			_target[R_ARM] = Vector3(1.9, 0.0, 0.35)
			_target[R_FORE].x = 1.6 + 0.35 * sin(_time * 14.0)
			_target[L_ARM] = Vector3(0.1, 0.0, -0.3)
			_target[L_FORE].x = 0.6
			_target[SPINE].x = -0.1
			_target[HEAD].x = 0.15
		"cheer":
			var pump := sin(_time * 8.0)
			_target[L_ARM] = Vector3(0.3, 0.0, -2.5 + 0.3 * pump)
			_target[R_ARM] = Vector3(0.3, 0.0, 2.5 - 0.3 * sin(_time * 8.0 + 1.0))
			_target[L_FORE].x = 0.6 + 0.4 * maxf(0.0, pump)
			_target[R_FORE].x = 0.6 + 0.4 * maxf(0.0, -pump)
			_target[HEAD].x = 0.25
			_add_lift += 0.05 * maxf(0.0, sin(_time * 8.0))
		"clap":
			_target[L_ARM] = Vector3(0.7, 0.0, 0.3)
			_target[R_ARM] = Vector3(0.7, 0.0, -0.3)
			_target[L_FORE] = Vector3(1.4, -0.55 - 0.3 * sin(_time * 14.0), 0.0)
			_target[R_FORE] = Vector3(1.4, 0.55 + 0.3 * sin(_time * 14.0), 0.0)
			_target[HEAD].x = 0.1
		"film":
			# Phone held up at eye height, the left hand steadying it.
			_target[R_ARM] = Vector3(1.35, 0.0, 0.05)
			_target[R_FORE].x = 0.9
			_target[R_HAND].x = -0.3
			_target[L_ARM] = Vector3(1.2, 0.0, 0.4)
			_target[L_FORE] = Vector3(1.1, -0.4, 0.0)
			_target[HEAD].x = -0.05
		"hail":
			# Arm up high toward the street, hand flagging.
			_target[R_ARM] = Vector3(2.2, 0.0, 0.5)
			_target[R_FORE].x = 0.3 + 0.15 * sin(_time * 6.0)
			_target[R_HAND].z = 0.4 * sin(_time * 6.0)
			_target[HEAD].y = -0.3
			_target[CHEST].y = -0.15
			_target[SPINE].x = 0.05
		"lean_wall":
			# Back on the wall, a foot up against it, arms folded.
			_add_tilt += 0.1
			_target[SPINE].x = 0.08
			_target[L_LEG].x = 0.35
			_target[L_SHIN].x = -1.4
			_target[L_FOOT].x = 0.4
			_arms_crossed(1.0)
			_target[HEAD].y = sin(_time * 0.35) * 0.3
		"kneel":
			# Down on the right knee by someone, reaching to them.
			_target[L_LEG] = Vector3(1.6, 0.0, -0.08)
			_target[L_SHIN].x = -1.9
			_target[L_FOOT].x = 0.3
			_target[R_LEG] = Vector3(-0.25, 0.0, 0.08)
			_target[R_SHIN].x = -1.55
			_target[R_FOOT].x = -0.7
			_target[SPINE].x = -0.5
			_target[HEAD].x = -0.35
			_target[R_ARM] = Vector3(1.3 + 0.1 * sin(_time * 2.0), 0.0, 0.1)
			_target[R_FORE].x = 0.3
			_target[L_ARM] = Vector3(0.9, 0.0, 0.1)
			_target[L_FORE].x = 0.6
		"cover_head":
			_cover_head(1.0)
			_target[SPINE].x = -0.3
			_target[HEAD].x = -0.35
		"arms_crossed":
			_arms_crossed(1.0)
		"stretch":
			_target[L_ARM] = Vector3(0.2, 0.0, -2.8)
			_target[R_ARM] = Vector3(0.2, 0.0, 2.8)
			_target[L_FORE].x = 0.3
			_target[R_FORE].x = 0.3
			_target[SPINE].x = 0.15
			_target[HEAD].x = 0.25
		"wait":
			# Hands clasped behind the back.
			_target[L_ARM] = Vector3(-0.35, 0.0, 0.12)
			_target[R_ARM] = Vector3(-0.35, 0.0, -0.12)
			_target[L_FORE] = Vector3(0.7, 0.5, 0.0)
			_target[R_FORE] = Vector3(0.7, -0.5, 0.0)
			_target[HEAD].y = sin(_time * 0.4) * 0.3
