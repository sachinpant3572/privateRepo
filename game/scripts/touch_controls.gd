extends Control
## Multi-touch controls drawn in code: a floating joystick on one half of the
## screen and round buttons on the other that press Input actions.
## Raw touch events are used so the stick and a button work at the same time.
## In a car the right side becomes GAS and BRAKE pedals, and the left side
## follows the driving layout (Controls.SCHEMES): the stick, two arrow
## buttons, floating arrows under the thumb, or nothing but a tilt gauge.
## Every control can be moved and resized (settings "touch_layout", the
## layout editor in Settings > Controls); `id` names it there.

const STICK_RADIUS := 90.0
## On foot. Offsets are from the bottom-right corner.
const BUTTONS := [
	{"id": "foot.attack", "action": "attack", "label": "PUNCH", "offset": Vector2(-120, -130), "radius": 62.0},
	{"id": "foot.sprint", "action": "sprint", "label": "RUN", "offset": Vector2(-265, -95), "radius": 52.0},
	{"id": "foot.interact", "action": "interact", "label": "ENTER", "offset": Vector2(-140, -285), "radius": 50.0},
]
## Driving, every layout: pedals (a `size` makes a pad) and round buttons.
const DRIVE_BUTTONS := [
	{"id": "drive.gas", "action": "gas", "label": "GAS", "offset": Vector2(-100, -150), "size": Vector2(120, 200)},
	{"id": "drive.brake", "action": "brake", "label": "BRAKE", "offset": Vector2(-250, -115), "size": Vector2(120, 130)},
	{"id": "drive.sprint", "action": "sprint", "label": "DRIFT", "offset": Vector2(-255, -265), "radius": 46.0},
	{"id": "drive.interact", "action": "interact", "label": "EXIT", "offset": Vector2(-100, -330), "radius": 46.0},
]
## The arrows layout's wheel. Offsets are from the bottom-left corner.
const ARROWS := [
	{"id": "drive.steer_left", "action": "steer_left", "label": "", "offset": Vector2(120, -140), "size": Vector2(150, 170), "left": true, "arrow": -1.0},
	{"id": "drive.steer_right", "action": "steer_right", "label": "", "offset": Vector2(295, -140), "size": Vector2(150, 170), "left": true, "arrow": 1.0},
]
## Where the stick rests (it floats to wherever the thumb lands on its half
## of the screen), the floating arrows' resting hint and the tilt gauge.
const FOOT_STICK := {"id": "foot.stick", "label": "STICK", "offset": Vector2(170, -170), "radius": STICK_RADIUS, "left": true}
const DRIVE_STICK := {"id": "drive.stick", "label": "STICK", "offset": Vector2(170, -170), "radius": STICK_RADIUS, "left": true}
const FLOAT_HOME := {"id": "drive.float", "label": "ARROWS", "offset": Vector2(190, -160), "radius": 80.0, "left": true}
const TILT_HOME := {"id": "drive.tilt", "label": "TILT", "offset": Vector2(190, -170), "radius": 105.0, "left": true}
## Floating arrows: the thumb this far (scaled) either side of where it
## landed turns the wheel that way; past FLOAT_REACH the landing point is
## dragged along, so turning back takes only a short slide.
const FLOAT_DEAD := 16.0
const FLOAT_REACH := 60.0
## A thumb that slides this far off a pedal or button lets go of it.
const SLIDE_OFF := 40.0
## Smallest and largest size the layout editor allows.
const MIN_SCALE := 0.6
const MAX_SCALE := 1.6

var labels := {}
## HUD controls (the minimap) whose taps the stick and buttons ignore.
var exclusions: Array = []
## The layout editor keeps placed controls below its top bar (and so clear
## of the HUD's top buttons).
var top_margin := 0.0
## Set by the HUD: in a car, and which driving layout.
var driving := false
var scheme := "stick"
## In the back of a cab: no stick or buttons (the taxi panel has its own).
var seated := false
## Settings "touch_layout": {id: {"x", "y" (offset from the control's
## corner), "s" (size)}}. Shared with the settings, so edits show at once.
var layout := {}
## Drawn only, never pressed (the settings page's previews).
var preview := false
## The layout editor's picked control (outlined).
var selected := ""
var _stick_touch := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
## Floating arrows: -1 left, 0 none, 1 right.
var _float_dir := 0
var _button_touches := {}
## Touches that slid off a button and are still down: sliding back onto one
## presses it again.
var _slid_off := {}
var _pad := StyleBoxFlat.new()


func _ready() -> void:
	if not preview:
		set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		# Lets go of what was held even while the game is paused (the phone,
		# settings): a release missed there left the stick or GAS on.
		process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = MOUSE_FILTER_IGNORE
	for b in BUTTONS + DRIVE_BUTTONS + ARROWS:
		if not labels.has(b.action):
			labels[b.action] = b.label
	_pad.set_corner_radius_all(18)
	_pad.set_border_width_all(3)
	_pad.border_color = Color(1, 1, 1, 0.6)


func _notification(what: int) -> void:
	if preview:
		return
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			release_all()
		NOTIFICATION_VISIBILITY_CHANGED:
			if not is_visible_in_tree():
				release_all()


func _process(_delta: float) -> void:
	if visible and driving and scheme == "tilt":
		queue_redraw()


func set_label(action: String, text: String) -> void:
	if labels.get(action) != text:
		labels[action] = text
		queue_redraw()


## Switches the layout; lets go of buttons the new one hasn't got (GAS
## held while getting out) and of the stick if it is gone.
func set_mode(in_car: bool, layout_name: String, in_cab := false) -> void:
	if in_car == driving and layout_name == scheme and in_cab == seated:
		return
	var was := _stick_item()
	driving = in_car
	scheme = layout_name
	seated = in_cab
	var keep: Array = buttons().map(func(b): return b.action)
	for index in _button_touches.keys():
		if not keep.has(_button_touches[index]):
			_release(index)
	if _stick_touch != -1 and _stick_item() != was:
		_let_go_stick()
	queue_redraw()


## Previews and the layout editor: a mode with its usual labels.
func show_mode(in_car: bool, layout_name: String) -> void:
	set_mode(in_car, layout_name)
	set_label("interact", "EXIT" if in_car else "ENTER")
	set_label("sprint", "DRIFT" if in_car else "RUN")


## Lets go of every touch: the stick, the floating arrows and all buttons.
func release_all() -> void:
	for index in _button_touches.keys():
		_release(index)
	_slid_off.clear()
	_let_go_stick()
	queue_redraw()


func buttons() -> Array:
	if seated:
		return []
	if not driving:
		return BUTTONS
	return DRIVE_BUTTONS + ARROWS if scheme == "arrows" else DRIVE_BUTTONS


func stick_on() -> bool:
	return not seated and (not driving or scheme == "stick")


func float_on() -> bool:
	return not seated and driving and scheme == "float"


## The stick, floating arrows or tilt gauge this mode shows, or {}.
func _stick_item() -> Dictionary:
	if seated:
		return {}
	if not driving:
		return FOOT_STICK
	match scheme:
		"stick": return DRIVE_STICK
		"float": return FLOAT_HOME
		"tilt": return TILT_HOME
	return {}


## Everything this mode draws, for the layout editor.
func items() -> Array:
	var s := _stick_item()
	return ([s] if not s.is_empty() else []) + buttons()


func _input(event: InputEvent) -> void:
	if preview or not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			# A press while paused belongs to the phone or settings page.
			if get_tree().paused:
				return
			# A release this layer never saw: let that touch go first.
			if _button_touches.has(event.index):
				_release(event.index)
			_slid_off.erase(event.index)
			if event.index == _stick_touch:
				_let_go_stick()
			if exclusions.any(func(c): return c.is_visible_in_tree() and c.get_global_rect().has_point(event.position)):
				return
			var action := _button_at(event.position)
			if action != "":
				_button_touches[event.index] = action
				Input.action_press(action)
			elif (stick_on() or float_on()) and _stick_touch == -1 and _in_stick_half(event.position):
				_stick_touch = event.index
				_stick_origin = event.position
				_stick_pos = event.position
		else:
			if _button_touches.has(event.index):
				_release(event.index)
			_slid_off.erase(event.index)
			if event.index == _stick_touch:
				_let_go_stick()
		queue_redraw()
	elif event is InputEventScreenDrag:
		if get_tree().paused:
			return
		if event.index == _stick_touch:
			_stick_pos = event.position
			if float_on():
				_float_drag()
			else:
				Controls.touch_vector = ((_stick_pos - _stick_origin) / _radius(_stick_item())).limit_length(1.0)
			queue_redraw()
		elif _button_touches.has(event.index):
			var action := _button_at(event.position)
			if action != "" and action != _button_touches[event.index]:
				# A thumb slid from one arrow or pedal onto the other.
				_release(event.index)
				_button_touches[event.index] = action
				Input.action_press(action)
				queue_redraw()
			elif action == "" and not _near(_button_touches[event.index], event.position):
				# Slid off onto empty screen: let go.
				_release(event.index)
				_slid_off[event.index] = true
				queue_redraw()
		elif _slid_off.has(event.index):
			var action := _button_at(event.position)
			if action != "":
				# The thumb came back onto a pedal or arrow.
				_slid_off.erase(event.index)
				_button_touches[event.index] = action
				Input.action_press(action)
				queue_redraw()


## The stick (and floating arrows) take touches on the half of the screen
## their resting place is on.
func _in_stick_half(pos: Vector2) -> bool:
	return (pos.x < size.x * 0.5) == (_center(_stick_item()).x < size.x * 0.5)


func _float_drag() -> void:
	var k := _scale(FLOAT_HOME)
	var reach := FLOAT_REACH * k
	var dx := _stick_pos.x - _stick_origin.x
	if dx > reach:
		_stick_origin.x = _stick_pos.x - reach
	elif dx < -reach:
		_stick_origin.x = _stick_pos.x + reach
	_stick_origin.y = _stick_pos.y
	dx = _stick_pos.x - _stick_origin.x
	var dir := 0
	if dx > FLOAT_DEAD * k:
		dir = 1
	elif dx < -FLOAT_DEAD * k:
		dir = -1
	_set_float(dir)


func _set_float(dir: int) -> void:
	if dir == _float_dir:
		return
	if _float_dir != 0:
		Input.action_release("steer_right" if _float_dir > 0 else "steer_left")
	_float_dir = dir
	if dir != 0:
		Input.action_press("steer_right" if dir > 0 else "steer_left")


func _let_go_stick() -> void:
	_stick_touch = -1
	Controls.touch_vector = Vector2.ZERO
	_set_float(0)


func _release(index: int) -> void:
	var action: String = _button_touches[index]
	_button_touches.erase(index)
	if not _button_touches.values().has(action):
		Input.action_release(action)


func _button_at(pos: Vector2) -> String:
	for b in buttons():
		if _hit(b, pos, 10.0):
			return b.action
	return ""


## Still within SLIDE_OFF of the held button.
func _near(action: String, pos: Vector2) -> bool:
	for b in buttons():
		if b.action == action and _hit(b, pos, SLIDE_OFF):
			return true
	return false


## On the control, its pad grown by `grow` pixels (a round one also by 15%).
func _hit(b: Dictionary, pos: Vector2, grow: float) -> bool:
	if b.has("size"):
		return Rect2(_center(b) - _size(b) * 0.5, _size(b)).grow(grow).has_point(pos)
	return pos.distance_to(_center(b)) <= _radius(b) * 1.15 + maxf(grow - 10.0, 0.0)


# --- Layout ---------------------------------------------------------------------

func _scale(b: Dictionary) -> float:
	var e = layout.get(b.id)
	return clampf(float(e.get("s", 1.0)), MIN_SCALE, MAX_SCALE) if e is Dictionary else 1.0


func _radius(b: Dictionary) -> float:
	return b.radius * _scale(b)


func _size(b: Dictionary) -> Vector2:
	return b.size * _scale(b)


## Half the control's width and height.
func _extent(b: Dictionary) -> Vector2:
	return _size(b) * 0.5 if b.has("size") else Vector2.ONE * _radius(b)


func _corner(b: Dictionary) -> Vector2:
	return Vector2(0.0, size.y) if b.get("left", false) else size


func _center(b: Dictionary) -> Vector2:
	var off: Vector2 = b.offset
	var e = layout.get(b.id)
	if e is Dictionary and e.has("x") and e.has("y"):
		off = Vector2(float(e.x), float(e.y))
	var half := _extent(b)
	var c := _corner(b) + off
	# Kept on screen however narrow it is.
	return Vector2(clampf(c.x, half.x, maxf(half.x, size.x - half.x)), clampf(c.y, half.y, maxf(half.y, size.y - half.y)))


## The layout editor: the control drawn under `pos` (this mode), or {}.
func item_at(pos: Vector2) -> Dictionary:
	var all := items()
	for i in range(all.size() - 1, -1, -1):
		if _hit(all[i], pos, 14.0):
			return all[i]
	return {}


func find_item(id: String) -> Dictionary:
	for b in items():
		if b.id == id:
			return b
	return {}


## Moves the control so its centre is at `pos` (kept on screen).
func place(b: Dictionary, pos: Vector2) -> void:
	var e: Dictionary = layout.get(b.id, {})
	var half := _extent(b)
	pos = Vector2(clampf(pos.x, half.x, size.x - half.x), clampf(pos.y, top_margin + half.y, size.y - half.y))
	var off := pos - _corner(b)
	e["x"] = off.x
	e["y"] = off.y
	layout[b.id] = e
	queue_redraw()


## Grows or shrinks the control by `step` (0.1 is 10% of its first size).
func resize(b: Dictionary, step: float) -> void:
	var e: Dictionary = layout.get(b.id, {})
	var c := _center(b)
	e["s"] = snappedf(clampf(_scale(b) + step, MIN_SCALE, MAX_SCALE), 0.01)
	layout[b.id] = e
	place(b, c)


func size_percent(b: Dictionary) -> int:
	return roundi(_scale(b) * 100.0)


## Puts every control whose id starts with `prefix` ("foot." or "drive.";
## "" for all) back where it started.
func reset(prefix := "") -> void:
	for id in layout.keys():
		if String(id).begins_with(prefix):
			layout.erase(id)
	queue_redraw()


# --- Drawing --------------------------------------------------------------------

func _draw() -> void:
	var font := get_theme_default_font()
	if stick_on():
		var r := _radius(_stick_item())
		var origin := _stick_origin if _stick_touch != -1 else _center(_stick_item())
		var knob := _stick_pos if _stick_touch != -1 else origin
		draw_circle(origin, r, Color(1, 1, 1, 0.12))
		draw_arc(origin, r, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
		draw_circle(origin + (knob - origin).limit_length(r), r * 0.42, Color(1, 1, 1, 0.45))
	elif float_on():
		_draw_float(font)
	elif driving and scheme == "tilt" and not seated:
		_draw_tilt_gauge(font)
	var held: Array = _button_touches.values()
	for b in buttons():
		var c := _center(b)
		var k := _scale(b)
		var alpha := 0.55 if held.has(b.action) else 0.25
		if b.has("size"):
			_pad.bg_color = Color(1, 1, 1, alpha)
			draw_style_box(_pad, Rect2(c - _size(b) * 0.5, _size(b)))
		else:
			draw_circle(c, _radius(b), Color(1, 1, 1, alpha))
			draw_arc(c, _radius(b), 0, TAU, 40, Color(1, 1, 1, 0.6), 3.0)
		if b.has("arrow"):
			_arrow(c, b.arrow, k, Color.WHITE)
			continue
		_label(font, c + Vector2(0, 7 * k), labels[b.action], roundi(20 * k), Color.WHITE)
	if selected != "":
		var b := find_item(selected)
		if not b.is_empty():
			var half := _extent(b) + Vector2(10, 10)
			draw_rect(Rect2(_center(b) - half, half * 2.0), Color(1.0, 0.82, 0.25), false, 4.0)


## A solid arrow pointing `d` (-1 left, 1 right), `k` times the arrow
## buttons' size.
func _arrow(c: Vector2, d: float, k: float, fill: Color) -> void:
	var tri := PackedVector2Array([c + Vector2(34 * d, 0) * k, c + Vector2(-22 * d, -36) * k, c + Vector2(-22 * d, 36) * k])
	draw_colored_polygon(tri, fill)
	tri.append(tri[0])
	draw_polyline(tri, Color(0, 0, 0, 0.45), 3.0)


## The floating arrows: under the thumb while it is down, a faint hint at
## their resting place while it is not.
func _draw_float(font: Font) -> void:
	var k := _scale(FLOAT_HOME)
	var held := _stick_touch != -1
	var c := _stick_origin if held else _center(FLOAT_HOME)
	var gap := 62.0 * k
	draw_circle(c, _radius(FLOAT_HOME), Color(1, 1, 1, 0.1 if held else 0.07))
	for d: int in [-1, 1]:
		var on: bool = held and _float_dir == d
		draw_circle(c + Vector2(gap * d, 0), 44.0 * k, Color(1, 1, 1, 0.5 if on else 0.18))
		_arrow(c + Vector2(gap * d, 0), d, k * 0.7, Color(1, 1, 1, 1.0 if on else 0.75))
	if held:
		draw_circle(_stick_pos, 12.0 * k, Color(1, 1, 1, 0.6))
	else:
		_label(font, c + Vector2(0, 74 * k), "TOUCH TO STEER", roundi(16 * k), Color(1, 1, 1, 0.75))


## Half a wheel with a needle at the current tilt.
func _draw_tilt_gauge(font: Font) -> void:
	var k := _scale(TILT_HOME)
	var c := _center(TILT_HOME) + Vector2(0, 20 * k)
	draw_circle(c + Vector2(0, -20) * k, 105.0 * k, Color(0, 0, 0, 0.25))
	draw_arc(c, 80.0 * k, PI, TAU, 32, Color(1, 1, 1, 0.5), 6.0)
	var a := -PI * 0.5 + (0.0 if preview else Controls.steer()) * PI * 0.5
	draw_line(c, c + Vector2(cos(a), sin(a)) * 80.0 * k, Color(1, 1, 1, 0.8), 6.0)
	draw_circle(c, 10.0 * k, Color(1, 1, 1, 0.6))
	_label(font, c + Vector2(0, 40) * k, "TILT TO STEER", roundi(18 * k), Color(1, 1, 1, 0.85))


## Centred text with a dark edge, readable on pale roofs and pavement.
func _label(font: Font, at: Vector2, text: String, font_size: int, color: Color) -> void:
	var pos := at - Vector2(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * 0.5, 0)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color(0, 0, 0, 0.55))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
