extends CanvasLayer
## Prototype HUD: health, wanted stars, prompts, BUSTED/WASTED messages,
## an FPS and draw-call readout for the performance check, and touch controls.

const TouchControls = preload("res://scripts/touch_controls.gd")

var game
var touch
var _health: ProgressBar
var _stars: Control
var _perf: Label
var _prompt: Label
var _message: Label
var _message_tween: Tween
var _district: Label
var _district_tween: Tween
var _district_id := ""
var _blink := 0.0


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_health = ProgressBar.new()
	_health.position = Vector2(20, 20)
	_health.size = Vector2(240, 20)
	_health.show_percentage = false
	_health.modulate = Color(0.4, 1.0, 0.45)
	root.add_child(_health)

	_perf = _label(root, 16)
	_perf.position = Vector2(20, 46)

	_stars = Control.new()
	_anchor(_stars, Vector2(1, 0), Rect2(-300, 12, 280, 50))
	_stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stars.draw.connect(_draw_stars)
	root.add_child(_stars)

	_prompt = _label(root, 24)
	_anchor(_prompt, Vector2(0.5, 1), Rect2(-300, -70, 600, 40))
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_message = _label(root, 84)
	_message.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message.modulate.a = 0.0

	_district = _label(root, 30)
	_anchor(_district, Vector2(0.5, 0), Rect2(-300, 70, 600, 44))
	_district.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_district.modulate.a = 0.0

	touch = TouchControls.new()
	root.add_child(touch)
	touch.visible = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")


func _process(delta: float) -> void:
	var player = game.player
	_health.value = player.health / player.max_health * 100.0
	_perf.text = "FPS %d  draws %d" % [Engine.get_frames_per_second(), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]
	_blink += delta
	_update_district(player.focus_node().global_position)
	_stars.queue_redraw()
	if player.vehicle != null:
		_prompt.text = "%d km/h" % int(absf(player.vehicle.speed) * 3.6)
		touch.set_label("interact", "EXIT")
		touch.set_label("sprint", "BRAKE")
	else:
		var near = player.nearest_vehicle()
		_prompt.text = "" if near == null else ("Steal car: E / ENTER" if near.has_ai_driver() else "Get in: E / ENTER")
		touch.set_label("interact", "ENTER")
		touch.set_label("sprint", "RUN")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_TAB:
		touch.visible = not touch.visible


func show_message(text: String) -> void:
	_message.text = text
	if _message_tween:
		_message_tween.kill()
	_message_tween = create_tween()
	_message.modulate.a = 1.0
	_message_tween.tween_interval(2.0)
	_message_tween.tween_property(_message, "modulate:a", 0.0, 0.6)


## Shows the district name for a few seconds whenever the player enters one.
func _update_district(pos: Vector3) -> void:
	var d: Dictionary = game.city.district_at(pos)
	if d.is_empty() or d.id == _district_id:
		return
	_district_id = d.id
	_district.text = d.name
	if _district_tween:
		_district_tween.kill()
	_district.modulate.a = 1.0
	_district_tween = create_tween()
	_district_tween.tween_interval(2.5)
	_district_tween.tween_property(_district, "modulate:a", 0.0, 0.8)


func _draw_stars() -> void:
	var hidden_flash := Wanted.unseen_time > 0.0 and int(_blink * 3.0) % 2 == 0
	for i in 5:
		var c := Vector2(_stars.size.x - 26 - i * 50, 25)
		var lit := (4 - i) < Wanted.level
		var color := Color(1.0, 0.82, 0.2) if lit and not hidden_flash else Color(1, 1, 1, 0.25)
		var points := PackedVector2Array()
		for k in 10:
			var r := 22.0 if k % 2 == 0 else 9.0
			var a := -PI / 2.0 + k * PI / 5.0
			points.append(c + Vector2(cos(a), sin(a)) * r)
		_stars.draw_colored_polygon(points, color)


## Pins a control to an anchor point of the screen, offset by `rect`.
func _anchor(control: Control, at: Vector2, rect: Rect2) -> void:
	control.anchor_left = at.x
	control.anchor_right = at.x
	control.anchor_top = at.y
	control.anchor_bottom = at.y
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.end.x
	control.offset_bottom = rect.end.y


func _label(parent: Control, font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label
