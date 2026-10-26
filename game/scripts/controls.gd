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
	"camera": [KEY_C],
}
const PAD_BUTTONS := {
	"sprint": JOY_BUTTON_A,
	"attack": JOY_BUTTON_X,
	"interact": JOY_BUTTON_Y,
	"camera": JOY_BUTTON_BACK,
}
const PAD_AXES := {
	"move_left": [JOY_AXIS_LEFT_X, -1.0],
	"move_right": [JOY_AXIS_LEFT_X, 1.0],
	"move_up": [JOY_AXIS_LEFT_Y, -1.0],
	"move_down": [JOY_AXIS_LEFT_Y, 1.0],
}

var camera: Camera3D
var touch_vector := Vector2.ZERO # written by the on-screen joystick
var override_vector = null # tests set a Vector2 here to steer the player

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
	var axes: Array[Vector3] = camera.ground_axes()
	return axes[0] * v.x - axes[1] * v.y
