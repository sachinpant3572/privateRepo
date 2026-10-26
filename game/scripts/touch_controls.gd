extends Control
## Multi-touch controls drawn in code: a floating joystick on the left half of
## the screen and round buttons bottom-right that press Input actions.
## Raw touch events are used so the stick and a button work at the same time.

const STICK_RADIUS := 90.0
const BUTTONS := [
	{"action": "attack", "label": "PUNCH", "offset": Vector2(-120, -130), "radius": 62.0},
	{"action": "sprint", "label": "RUN", "offset": Vector2(-265, -95), "radius": 52.0},
	{"action": "interact", "label": "ENTER", "offset": Vector2(-140, -285), "radius": 50.0},
]

var labels := {}
var _stick_touch := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _button_touches := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	for b in BUTTONS:
		labels[b.action] = b.label


func set_label(action: String, text: String) -> void:
	if labels.get(action) != text:
		labels[action] = text
		queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			var action := _button_at(event.position)
			if action != "":
				_button_touches[event.index] = action
				Input.action_press(action)
			elif event.position.x < size.x * 0.5 and _stick_touch == -1:
				_stick_touch = event.index
				_stick_origin = event.position
				_stick_pos = event.position
		else:
			if _button_touches.has(event.index):
				Input.action_release(_button_touches[event.index])
				_button_touches.erase(event.index)
			if event.index == _stick_touch:
				_stick_touch = -1
				Controls.touch_vector = Vector2.ZERO
		queue_redraw()
	elif event is InputEventScreenDrag and event.index == _stick_touch:
		_stick_pos = event.position
		Controls.touch_vector = ((_stick_pos - _stick_origin) / STICK_RADIUS).limit_length(1.0)
		queue_redraw()


func _button_at(pos: Vector2) -> String:
	for b in BUTTONS:
		if pos.distance_to(_center(b)) <= b.radius * 1.15:
			return b.action
	return ""


func _center(b: Dictionary) -> Vector2:
	return size + b.offset


func _draw() -> void:
	var font := get_theme_default_font()
	var origin := _stick_origin if _stick_touch != -1 else Vector2(170, size.y - 170)
	var knob := _stick_pos if _stick_touch != -1 else origin
	draw_circle(origin, STICK_RADIUS, Color(1, 1, 1, 0.12))
	draw_arc(origin, STICK_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
	draw_circle(origin + (knob - origin).limit_length(STICK_RADIUS), 38.0, Color(1, 1, 1, 0.45))
	var held: Array = _button_touches.values()
	for b in BUTTONS:
		var c := _center(b)
		var alpha := 0.55 if held.has(b.action) else 0.25
		draw_circle(c, b.radius, Color(1, 1, 1, alpha))
		draw_arc(c, b.radius, 0, TAU, 40, Color(1, 1, 1, 0.6), 3.0)
		var text: String = labels[b.action]
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_string(font, c + Vector2(-w * 0.5, 7), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
