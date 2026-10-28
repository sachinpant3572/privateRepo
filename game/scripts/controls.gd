extends Node
## Input layer shared by keyboard, gamepad and the on-screen touch controls.
## Gameplay code asks this node for a world-space move direction and for
## per-physics-frame "just pressed" checks, so tests can drive it too.

const KEYS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"sprint": [KEY_SHIFT], # handbrake while driving
	"attack": [KEY_SPACE, KEY_J],
	"interact": [KEY_E, KEY_F],
	"hail": [KEY_T], # hail a taxi (taxi.gd; the HUD's TAXI button)
	# Pedals and steering buttons: the touch layouts and gamepad triggers.
	# On a keyboard, W/S and A/D double as them in the arrows and tilt
	# layouts (gas(), brake(), steer()).
	"gas": [],
	"brake": [],
	"steer_left": [],
	"steer_right": [],
}
const PAD_BUTTONS := {
	"sprint": JOY_BUTTON_A,
	"attack": JOY_BUTTON_X,
	"interact": JOY_BUTTON_Y,
	"hail": JOY_BUTTON_B,
}
const PAD_AXES := {
	"move_left": [JOY_AXIS_LEFT_X, -1.0],
	"move_right": [JOY_AXIS_LEFT_X, 1.0],
	"move_up": [JOY_AXIS_LEFT_Y, -1.0],
	"move_down": [JOY_AXIS_LEFT_Y, 1.0],
	"gas": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
	"brake": [JOY_AXIS_TRIGGER_LEFT, 1.0],
}
## Driving layouts (settings "controls"). stick: the car heads where the
## stick points, as on foot, with GAS and BRAKE pedals beside it. arrows:
## left and right buttons turn the wheel, the pedals drive. tilt: the phone
## is the wheel.
const SCHEMES := ["stick", "arrows", "tilt"]
const SCHEME_NAMES := {"stick": "Stick + pedals", "arrows": "Arrows + pedals", "tilt": "Tilt + pedals"}
## Tilt steering: no turn inside TILT_DEAD of level, full lock at
## TILT_FULL (both the sine of the roll angle: about 3 and 25 degrees).
const TILT_DEAD := 0.05
const TILT_FULL := 0.42

var camera: Camera3D
var touch_vector := Vector2.ZERO # written by the on-screen joystick
## Steer by stick: the wheel is fully over with the stick this many degrees
## off straight up; pulled back further than STICK_BACK it brakes.
const STICK_FULL := 60.0
const STICK_BACK := 110.0
var override_vector = null # tests set a Vector2 here to steer the player
var scheme := "stick"
var tilt_override = null # tests set a gravity Vector3 here to tilt the phone

var _was_pressed := {}
var _just_pressed := {}


func _ready() -> void:
	process_priority = -100
	process_physics_priority = -100
	for action in KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for key in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
		if PAD_BUTTONS.has(action):
			var btn := InputEventJoypadButton.new()
			btn.button_index = PAD_BUTTONS[action]
			InputMap.action_add_event(action, btn)
		if PAD_AXES.has(action):
			var axis := InputEventJoypadMotion.new()
			axis.axis = PAD_AXES[action][0]
			axis.axis_value = PAD_AXES[action][1]
			InputMap.action_add_event(action, axis)


func _physics_process(_delta: float) -> void:
	for action in KEYS:
		var pressed := Input.is_action_pressed(action)
		_just_pressed[action] = pressed and not _was_pressed.get(action, false)
		_was_pressed[action] = pressed


func just_pressed(action: String) -> bool:
	return _just_pressed.get(action, false)


## Screen-space stick direction, x right and y down, length 0..1.
func move_vector() -> Vector2:
	if override_vector != null:
		return override_vector
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if touch_vector.length() > v.length():
		v = touch_vector
	return v.limit_length(1.0)


## Inverse of world_move(): the stick vector that moves along `dir`.
func screen_from_world(dir: Vector3) -> Vector2:
	var axes: Array[Vector3] = camera.ground_axes()
	return Vector2(dir.dot(axes[0]), -dir.dot(axes[1])).limit_length(1.0)


## The stick direction mapped onto the ground plane as seen by the camera.
func world_move() -> Vector3:
	var v := move_vector()
	if camera == null:
		return Vector3(v.x, 0.0, v.y)
	var axes: Array[Vector3] = camera.input_axes()
	return axes[0] * v.x - axes[1] * v.y


## The car steers by the wheel (arrows, tilt) rather than by pointing.
func wheel_steering() -> bool:
	return scheme != "stick"


## Stick layout with the view turning behind the car: the stick drives the
## car the way it looks on screen, relative to the car (HANDOFF-heading-camera.md
## H-4). Pointing at a world direction instead would tie how fast the car
## turns to how fast the view catches up.
func stick_steers() -> bool:
	return scheme == "stick" and camera != null and camera.has_method("turns") and camera.turns()


## Steer by stick: [wheel -1..1, gas 0..1, brake 0..1]. Up the screen is
## straight on; leaning the stick turns the wheel, fully at STICK_FULL
## degrees; pulled back past STICK_BACK it brakes and, stopped, reverses.
func stick_wheel() -> Array[float]:
	var v := move_vector()
	var amount := v.length()
	if amount < 0.15:
		return [0.0, 0.0, 0.0]
	var angle := atan2(v.x, -v.y)
	if absf(angle) <= deg_to_rad(STICK_BACK):
		return [clampf(angle / deg_to_rad(STICK_FULL), -1.0, 1.0), amount, 0.0]
	# Backing up, leaning the stick swings the tail that way.
	var back := signf(angle) * (PI - absf(angle))
	return [clampf(back / deg_to_rad(STICK_FULL), -1.0, 1.0), 0.0, amount]


## Gas pedal, 0..1. W and the stick's up count in the wheel layouts.
func gas() -> float:
	var g := Input.get_action_strength("gas")
	if wheel_steering():
		g = maxf(g, Input.get_action_strength("move_up"))
	return g


## Brake pedal, 0..1 (held at a stop, it reverses).
func brake() -> float:
	var b := Input.get_action_strength("brake")
	if wheel_steering():
		b = maxf(b, Input.get_action_strength("move_down"))
	return b


## The wheel in the arrows and tilt layouts: -1 full left .. 1 full right.
func steer() -> float:
	var s := Input.get_axis("move_left", "move_right") + Input.get_axis("steer_left", "steer_right")
	if scheme == "tilt":
		s += tilt_steer()
	return clampf(s, -1.0, 1.0)


## Turning the phone like a wheel. Godot's sensors are turned to the screen
## (x right, y up) and point along gravity, so a right-side-down tilt gives
## +x (platform/android GodotInputHandler.onSensorChanged).
func tilt_steer() -> float:
	var g: Vector3 = tilt_override if tilt_override != null else Input.get_gravity()
	if g == Vector3.ZERO:
		g = Input.get_accelerometer()
	if g.length() < 1.0:
		return 0.0
	var roll := g.x / g.length()
	return signf(roll) * clampf((absf(roll) - TILT_DEAD) / (TILT_FULL - TILT_DEAD), 0.0, 1.0)
