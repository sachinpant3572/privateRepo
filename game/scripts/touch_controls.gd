extends Control
## Multi-touch controls drawn in code: a floating joystick on the left half of
## the screen and round buttons bottom-right that press Input actions.
## Raw touch events are used so the stick and a button work at the same time.
## In a car the right side becomes GAS and BRAKE pedals, and the left side
## follows the driving layout (Controls.SCHEMES): the stick, two arrow
## buttons, or nothing but a tilt gauge.

const STICK_RADIUS := 90.0
## On foot. Offsets are from the bottom-right corner.
const BUTTONS := [
	{"action": "attack", "label": "PUNCH", "offset": Vector2(-120, -130), "radius": 62.0},
	{"action": "sprint", "label": "RUN", "offset": Vector2(-265, -95), "radius": 52.0},
	{"action": "interact", "label": "ENTER", "offset": Vector2(-140, -285), "radius": 50.0},
]
## Driving, every layout: pedals (a `size` makes a pad) and round buttons.
const DRIVE_BUTTONS := [
	{"action": "gas", "label": "GAS", "offset": Vector2(-100, -150), "size": Vector2(120, 200)},
	{"action": "brake", "label": "BRAKE", "offset": Vector2(-250, -115), "size": Vector2(120, 130)},
	{"action": "sprint", "label": "DRIFT", "offset": Vector2(-255, -265), "radius": 46.0},
	{"action": "interact", "label": "EXIT", "offset": Vector2(-100, -330), "radius": 46.0},
]
## The arrows layout's wheel. Offsets are from the bottom-left corner.
const ARROWS := [
	{"action": "steer_left", "label": "", "offset": Vector2(120, -140), "size": Vector2(150, 170), "left": true, "arrow": -1.0},
	{"action": "steer_right", "label": "", "offset": Vector2(295, -140), "size": Vector2(150, 170), "left": true, "arrow": 1.0},
]
const TILT_GAUGE := Vector2(190, -150)

var labels := {}
## HUD controls (the minimap) whose taps the stick and buttons ignore.
var exclusions: Array = []
## Set by the HUD: in a car, and which driving layout.
var driving := false
var scheme := "stick"
## In the back of a cab: no stick or buttons (the taxi panel has its own).
var seated := false
var _stick_touch := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _button_touches := {}
var _pad := StyleBoxFlat.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	for b in BUTTONS + DRIVE_BUTTONS + ARROWS:
		if not labels.has(b.action):
			labels[b.action] = b.label
	_pad.set_corner_radius_all(18)
	_pad.set_border_width_all(3)
	_pad.border_color = Color(1, 1, 1, 0.6)


func _process(_delta: float) -> void:
	if visible and driving and scheme == "tilt":
		queue_redraw()


func set_label(action: String, text: String) -> void:
	if labels.get(action) != text:
		labels[action] = text
		queue_redraw()


## Switches the layout; lets go of buttons the new one hasn't got (GAS
## held while getting out) and of the stick if it is gone.
func set_mode(in_car: bool, layout: String, in_cab := false) -> void:
	if in_car == driving and layout == scheme and in_cab == seated:
		return
	driving = in_car
	scheme = layout
	seated = in_cab
	var keep: Array = buttons().map(func(b): return b.action)
	for index in _button_touches.keys():
		if not keep.has(_button_touches[index]):
			_release(index)
	if not stick_on() and _stick_touch != -1:
		_stick_touch = -1
		Controls.touch_vector = Vector2.ZERO
	queue_redraw()


func buttons() -> Array:
	if seated:
		return []
	if not driving:
		return BUTTONS
	return DRIVE_BUTTONS + ARROWS if scheme == "arrows" else DRIVE_BUTTONS


func stick_on() -> bool:
	return not seated and (not driving or scheme == "stick")


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if exclusions.any(func(c): return c.is_visible_in_tree() and c.get_global_rect().has_point(event.position)):
				return
			var action := _button_at(event.position)
			if action != "":
				_button_touches[event.index] = action
				Input.action_press(action)
			elif stick_on() and event.position.x < size.x * 0.5 and _stick_touch == -1:
				_stick_touch = event.index
				_stick_origin = event.position
				_stick_pos = event.position
		else:
			if _button_touches.has(event.index):
				_release(event.index)
			if event.index == _stick_touch:
				_stick_touch = -1
				Controls.touch_vector = Vector2.ZERO
		queue_redraw()
	elif event is InputEventScreenDrag:
		if event.index == _stick_touch:
			_stick_pos = event.position
			Controls.touch_vector = ((_stick_pos - _stick_origin) / STICK_RADIUS).limit_length(1.0)
			queue_redraw()
		elif _button_touches.has(event.index):
			# A thumb slid from one arrow or pedal onto the other.
			var action := _button_at(event.position)
			if action != "" and action != _button_touches[event.index]:
				_release(event.index)
				_button_touches[event.index] = action
				Input.action_press(action)
				queue_redraw()


func _release(index: int) -> void:
	var action: String = _button_touches[index]
	_button_touches.erase(index)
	if not _button_touches.values().has(action):
		Input.action_release(action)


func _button_at(pos: Vector2) -> String:
	for b in buttons():
		if b.has("size"):
			if Rect2(_center(b) - b.size * 0.5, b.size).grow(10.0).has_point(pos):
				return b.action
		elif pos.distance_to(_center(b)) <= b.radius * 1.15:
			return b.action
	return ""


func _center(b: Dictionary) -> Vector2:
	if b.get("left", false):
		return Vector2(0.0, size.y) + b.offset
	return size + b.offset


func _draw() -> void:
	var font := get_theme_default_font()
	if stick_on():
		var origin := _stick_origin if _stick_touch != -1 else Vector2(170, size.y - 170)
		var knob := _stick_pos if _stick_touch != -1 else origin
		draw_circle(origin, STICK_RADIUS, Color(1, 1, 1, 0.12))
		draw_arc(origin, STICK_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
		draw_circle(origin + (knob - origin).limit_length(STICK_RADIUS), 38.0, Color(1, 1, 1, 0.45))
	elif scheme == "tilt":
		_draw_tilt_gauge(font)
	var held: Array = _button_touches.values()
	for b in buttons():
		var c := _center(b)
		var alpha := 0.55 if held.has(b.action) else 0.25
		if b.has("size"):
			_pad.bg_color = Color(1, 1, 1, alpha)
			draw_style_box(_pad, Rect2(c - b.size * 0.5, b.size))
		else:
			draw_circle(c, b.radius, Color(1, 1, 1, alpha))
			draw_arc(c, b.radius, 0, TAU, 40, Color(1, 1, 1, 0.6), 3.0)
		if b.has("arrow"):
			var d: float = b.arrow
			var tri := PackedVector2Array([c + Vector2(34 * d, 0), c + Vector2(-22 * d, -36), c + Vector2(-22 * d, 36)])
			draw_colored_polygon(tri, Color.WHITE)
			tri.append(tri[0])
			draw_polyline(tri, Color(0, 0, 0, 0.45), 3.0)
			continue
		_label(font, c + Vector2(0, 7), labels[b.action], 20, Color.WHITE)


## Half a wheel with a needle at the current tilt.
func _draw_tilt_gauge(font: Font) -> void:
	var c := Vector2(0.0, size.y) + TILT_GAUGE
	draw_circle(c + Vector2(0, -20), 105.0, Color(0, 0, 0, 0.25))
	draw_arc(c, 80.0, PI, TAU, 32, Color(1, 1, 1, 0.5), 6.0)
	var a := -PI * 0.5 + Controls.steer() * PI * 0.5
	draw_line(c, c + Vector2(cos(a), sin(a)) * 80.0, Color(1, 1, 1, 0.8), 6.0)
	draw_circle(c, 10.0, Color(1, 1, 1, 0.6))
	_label(font, c + Vector2(0, 40), "TILT TO STEER", 18, Color(1, 1, 1, 0.85))


## Centred text with a dark edge, readable on pale roofs and pavement.
func _label(font: Font, at: Vector2, text: String, font_size: int, color: Color) -> void:
	var pos := at - Vector2(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * 0.5, 0)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color(0, 0, 0, 0.55))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
