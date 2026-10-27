extends RefCounted
## Animates a CharacterKit skeleton in code: idle, walk and run cycles,
## punches, kicks, flinches, knockdowns, riding, sitting, gestures for
## cutscenes and things people do indoors (eat, browse, work, pay). Each frame the owner fills a Rig.State; pose() turns it into
## target bone rotations and eases the skeleton toward them, so every move
## blends into the next.

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
	var down := false # knocked down or dead, lying on the back
	var ride := false # sitting astride a scooter or bike
	var sit := false # on a chair, stool or bench (gestures still apply)
	var gesture := "" # phone, talk, wave, hands_up, cower, point, eat, browse, work, pay
	var texting := false # looking at a phone in the right hand while strolling

## Hip drop for sitting on a seat at InteriorKit.SEAT_Y.
const SIT_LIFT := -0.42

var skeleton: Skeleton3D
var phase := 0.0
var _bones := PackedInt32Array()
var _rot: Array[Vector3] = []
var _target: Array[Vector3] = []
var _time := 0.0
var _lift := 0.0
var _tilt := 0.0

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


func _init(skel: Skeleton3D) -> void:
	skeleton = skel
	for b in CharacterKit.BONES:
		_bones.append(skel.find_bone(b[0]))
		_rot.append(Vector3.ZERO)
		_target.append(Vector3.ZERO)


func pose(s: State, delta: float) -> void:
	_time += delta
	for i in _target.size():
		_target[i] = Vector3.ZERO
	var lift := 0.0
	var tilt := 0.0
	var rate := 16.0
	if s.down:
		_down()
		tilt = PI / 2.0
		lift = 0.14
		rate = 10.0
	elif s.ride:
		_ride()
		lift = -0.28
	elif s.sit:
		_sit()
		lift = SIT_LIFT
		if s.gesture != "":
			_gesture(s.gesture)
	else:
		lift = _locomotion(s, delta)
		if s.texting and s.speed < 2.5:
			_texting()
		if s.guard and s.punch < 0.0 and s.kick < 0.0 and s.speed < 3.5:
			_guard()
		if s.punch >= 0.0:
			_punch(s.punch, s.punch_left)
			rate = 30.0
		if s.kick >= 0.0:
			_kick(s.kick)
			rate = 30.0
		if s.gesture != "":
			_gesture(s.gesture)
		if s.flinch > 0.0:
			_target[SPINE].x += 0.4 * s.flinch
			_target[HEAD].x += 0.35 * s.flinch
			_target[L_ARM].z -= 0.4 * s.flinch
			_target[R_ARM].z += 0.4 * s.flinch
	var k := 1.0 - exp(-rate * delta)
	for i in _rot.size():
		_rot[i] = _rot[i].lerp(_target[i], k)
		skeleton.set_bone_pose_rotation(_bones[i], Quaternion.from_euler(_rot[i]))
	_lift = lerpf(_lift, lift, 1.0 - exp(-14.0 * delta))
	_tilt = lerpf(_tilt, tilt, 1.0 - exp(-(9.0 if s.down else 6.0) * delta))
	skeleton.position.y = _lift
	skeleton.rotation.x = _tilt


## Walk and run: legs and arms swing in opposition, knees and elbows bend
## more as the pace rises, the body leans in and bobs. Returns the hip lift.
func _locomotion(s: State, delta: float) -> float:
	var moving := clampf(s.speed / 1.2, 0.0, 1.0)
	var run := clampf((s.speed - 2.2) / maxf(s.run_speed - 2.2, 0.1), 0.0, 1.0)
	phase = fmod(phase + delta * (4.0 + s.speed * 1.6) * moving, TAU)
	var sw := sin(phase)
	var amp := lerpf(0.42, 0.85, run) * moving
	var knee := lerpf(0.35, 1.5, run) * moving
	_target[L_LEG].x = sw * amp
	_target[R_LEG].x = -sw * amp
	_target[L_SHIN].x = -knee * (1.0 - sw) * 0.5
	_target[R_SHIN].x = -knee * (1.0 + sw) * 0.5
	_target[L_FOOT].x = -(_target[L_LEG].x + _target[L_SHIN].x) * 0.6
	_target[R_FOOT].x = -(_target[R_LEG].x + _target[R_SHIN].x) * 0.6
	var arm := amp * lerpf(0.8, 1.0, run)
	_target[L_ARM] = Vector3(-sw * arm, 0.0, -0.08 - 0.06 * run)
	_target[R_ARM] = Vector3(sw * arm, 0.0, 0.08 + 0.06 * run)
	_target[L_FORE].x = lerpf(0.15, 1.5, run) + maxf(0.0, -sw) * 0.25 * moving
	_target[R_FORE].x = lerpf(0.15, 1.5, run) + maxf(0.0, sw) * 0.25 * moving
	_target[SPINE].x = -0.22 * run
	_target[HIPS].y = sw * 0.12 * moving
	_target[CHEST].y = -sw * 0.18 * moving
	_target[HEAD].x = 0.1 * run
	# Breathing when standing still.
	var still := 1.0 - moving
	_target[CHEST].x += sin(_time * 2.2) * 0.025 * still
	_target[L_ARM].z -= 0.05 * still
	_target[R_ARM].z += 0.05 * still
	return absf(cos(phase)) * lerpf(0.02, 0.07, run) * moving


## Right forearm up with the phone screen facing the face, head bowed; the
## left arm keeps swinging.
func _texting() -> void:
	_target[R_ARM] = Vector3(0.3, 0.0, -0.05)
	_target[R_FORE] = Vector3(1.3, 0.35, 0.0)
	_target[HEAD].x -= 0.35


func _guard() -> void:
	_target[L_ARM] = Vector3(0.85, 0.0, 0.15)
	_target[R_ARM] = Vector3(0.75, 0.0, -0.15)
	_target[L_FORE].x = 1.95
	_target[R_FORE].x = 1.95
	_target[CHEST].y = 0.25
	_target[L_LEG].x += 0.25
	_target[R_LEG].x -= 0.2
	_target[L_SHIN].x -= 0.25
	_target[R_SHIN].x -= 0.25


## A straight punch: the arm snaps out by 35% of the move and comes back,
## the shoulders turn into it, the other fist guards the chin.
func _punch(p: float, left: bool) -> void:
	var ext := clampf(p / 0.35, 0.0, 1.0) if p < 0.35 else clampf(1.0 - (p - 0.35) / 0.65, 0.0, 1.0)
	var arm := L_ARM if left else R_ARM
	var fore := L_FORE if left else R_FORE
	var guard_arm := R_ARM if left else L_ARM
	var guard_fore := R_FORE if left else L_FORE
	var sgn := -1.0 if left else 1.0
	_target[arm] = Vector3(lerpf(0.9, 1.55, ext), 0.0, -sgn * 0.25 * ext)
	_target[fore].x = lerpf(1.9, 0.05, ext)
	_target[guard_arm] = Vector3(0.85, 0.0, sgn * 0.1)
	_target[guard_fore].x = 2.0
	_target[CHEST].y = sgn * 0.5 * ext
	_target[SPINE].x = -0.15 * ext
	_target[L_LEG].x = 0.2
	_target[R_LEG].x = -0.2
	_target[L_SHIN].x = -0.2
	_target[R_SHIN].x = -0.3


## A front kick with the right leg: chamber, snap out, recover.
func _kick(p: float) -> void:
	var ext := clampf(p / 0.4, 0.0, 1.0) if p < 0.4 else clampf(1.0 - (p - 0.4) / 0.6, 0.0, 1.0)
	_target[R_LEG].x = 1.5 * ext
	_target[R_SHIN].x = -lerpf(1.6, 0.1, ext) * minf(1.0, p * 6.0)
	_target[R_FOOT].x = -0.5 * ext
	_target[L_SHIN].x = -0.2
	_target[SPINE].x = 0.3 * ext
	_target[L_ARM] = Vector3(0.6, 0.0, -0.5)
	_target[R_ARM] = Vector3(-0.3, 0.0, 0.6)
	_target[L_FORE].x = 1.6
	_target[R_FORE].x = 0.8


func _down() -> void:
	_target[L_ARM] = Vector3(0.2, 0.0, -1.2)
	_target[R_ARM] = Vector3(0.2, 0.0, 1.0)
	_target[L_FORE].x = 0.4
	_target[R_FORE].x = 0.9
	_target[L_LEG].z = -0.15
	_target[R_LEG] = Vector3(0.35, 0.0, 0.15)
	_target[R_SHIN].x = -0.7
	_target[HEAD].y = 0.4


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
		"phone":
			_target[R_ARM] = Vector3(0.35, 0.0, 0.55)
			_target[R_FORE].x = 2.5
			_target[HEAD].z = 0.15
		"talk":
			_target[L_ARM] = Vector3(0.35, 0.0, -0.2)
			_target[R_ARM] = Vector3(0.3, 0.0, 0.2)
			_target[L_FORE].x = 1.1 + sin(_time * 3.1) * 0.35
			_target[R_FORE].x = 1.0 + sin(_time * 2.3 + 1.0) * 0.4
			_target[HEAD].y = sin(_time * 1.3) * 0.15
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
