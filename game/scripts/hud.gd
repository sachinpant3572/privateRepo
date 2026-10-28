extends CanvasLayer
## HUD: minimap (tap for the full map), health, wanted stars, cash and clock,
## the phone button, mission objective, dialogue box, title cards ("MISSION
## PASSED"), retry prompt, context prompts (missions, then doors and
## counters), the snack button, BUSTED/WASTED messages, an FPS and
## draw-call readout for the performance check, and touch controls.

const TouchControls = preload("res://scripts/touch_controls.gd")
const Minimap = preload("res://scripts/minimap.gd")
const StateMap = preload("res://scripts/state_map.gd")
const FullMap = preload("res://scripts/full_map.gd")
const MapImage = preload("res://scripts/map_image.gd")
const Phone = preload("res://scripts/phone.gd")

const SPEAKER_COLORS := {
	"Jules": Color(1.0, 0.85, 0.3), "Nia": Color(0.5, 0.9, 0.5), "Celeste": Color(0.95, 0.5, 0.65),
	"Marcel": Color(0.75, 0.6, 1.0), "Reyes": Color(0.5, 0.75, 1.0), "Remy": Color(0.6, 0.95, 0.9),
}

var game
var touch
var minimap
var full_map
var phone
var root: Control
## A mission's own prompt for the interact button: [text, button label].
var context_prompt := []
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
var _cash: Label
var _clock: Label
var _shown_cash := 0.0
var _objective: Label
var _dialogue: PanelContainer
var _speaker: Label
var _line: Label
var _dialogue_done := Callable()
var _dialogue_time := 0.0
var _card: Control
var _card_title: Label
var _card_sub: Label
var _card_tween: Tween
var _retry: PanelContainer
var _phone_button: Button
## Opens the phone straight to Settings; always shown, unlike PHONE.
var settings_button: Button
var _phone_pulse := false
var _snack: Button
## The vehicle the player last sat in (instance id) and how long its model
## name still shows beside the speed.
var _ride_id := 0
var _ride_name_time := 0.0


func _ready() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var map: Dictionary = MapImage.bake(game.city)
	var state: Dictionary = StateMap.bake(game.city.map_origin, game.city)
	minimap = Minimap.new()
	minimap.game = game
	minimap.map = map
	minimap.state = state
	minimap.position = Vector2(16, 16)
	minimap.size = Vector2(220, 220)
	root.add_child(minimap)

	_health = ProgressBar.new()
	_health.position = Vector2(26, 242)
	_health.size = Vector2(200, 14)
	_health.show_percentage = false
	_health.modulate = Color(0.4, 1.0, 0.45)
	root.add_child(_health)

	_perf = _label(root, 14)
	_perf.position = Vector2(26, 260)

	_stars = Control.new()
	_anchor(_stars, Vector2(1, 0), Rect2(-300, 12, 280, 50))
	_stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stars.draw.connect(_draw_stars)
	root.add_child(_stars)

	_cash = _label(root, 30)
	_anchor(_cash, Vector2(1, 0), Rect2(-300, 60, 280, 40))
	_cash.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_cash.add_theme_color_override("font_color", Color(0.55, 0.95, 0.5))
	_clock = _label(root, 20)
	_anchor(_clock, Vector2(1, 0), Rect2(-300, 96, 280, 28))
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_phone_button = Button.new()
	_phone_button.text = "PHONE"
	_phone_button.add_theme_font_size_override("font_size", 20)
	_anchor(_phone_button, Vector2(1, 0), Rect2(-130, 130, 110, 56))
	_phone_button.focus_mode = Control.FOCUS_NONE
	root.add_child(_phone_button)
	settings_button = Button.new()
	settings_button.tooltip_text = "Settings"
	_anchor(settings_button, Vector2(1, 0), Rect2(-196, 130, 56, 56))
	settings_button.focus_mode = Control.FOCUS_NONE
	settings_button.draw.connect(_draw_gear)
	root.add_child(settings_button)

	# Eat a snack from the bag (H).
	_snack = Button.new()
	_snack.add_theme_font_size_override("font_size", 18)
	_snack.position = Vector2(26, 284)
	_snack.size = Vector2(140, 48)
	_snack.focus_mode = Control.FOCUS_NONE
	_snack.pressed.connect(func(): game.eat_snack())
	root.add_child(_snack)

	_objective = _label(root, 24)
	_anchor(_objective, Vector2(0.5, 0), Rect2(-330, 14, 660, 64))
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_prompt = _label(root, 24)
	_anchor(_prompt, Vector2(0.5, 1), Rect2(-300, -70, 600, 40))
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_message = _label(root, 84)
	_message.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message.modulate.a = 0.0

	_district = _label(root, 30)
	_anchor(_district, Vector2(0.5, 0), Rect2(-300, 84, 600, 44))
	_district.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_district.modulate.a = 0.0

	_build_dialogue()
	_build_card()
	_build_retry()

	touch = TouchControls.new()
	touch.exclusions = [minimap, _dialogue, _phone_button, settings_button, _retry, _snack]
	if game.interiors:
		touch.exclusions.append(game.interiors.menu.frame)
	root.add_child(touch)
	touch.visible = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	if game.taxi:
		game.taxi.build_ui(root, touch)

	full_map = FullMap.new()
	full_map.game = game
	full_map.map = map
	full_map.state = state
	add_child(full_map)
	minimap.opened.connect(full_map.open)
	minimap.compass.connect(game.camera.recenter)

	phone = Phone.new()
	phone.game = game
	add_child(phone)
	_phone_button.pressed.connect(phone.open)
	settings_button.pressed.connect(phone.open_settings)
	_shown_cash = game.cash


func _process(delta: float) -> void:
	var player = game.player
	_health.value = player.health / player.max_health * 100.0
	_perf.visible = game.settings.get("show_fps", true)
	_perf.text = "FPS %d  draws %d" % [Engine.get_frames_per_second(), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]
	_blink += delta
	var indoors: bool = game.interiors != null and game.interiors.state != game.interiors.State.OUTSIDE
	minimap.visible = not indoors
	if not indoors:
		_update_district(player.focus_node().global_position)
	var snacks: int = game.inventory.bag.size()
	_snack.visible = snacks > 0
	_snack.text = "SNACK x%d" % snacks
	_stars.queue_redraw()
	_shown_cash = move_toward(_shown_cash, game.cash, maxf(absf(game.cash - _shown_cash) * 3.0, 50.0) * delta)
	_cash.text = "$%d" % int(_shown_cash)
	_clock.text = game.atmosphere.clock_text()
	_phone_button.visible = game.missions != null and game.missions.phone_unlocked
	# The gear takes PHONE's slot until the story unlocks the phone.
	settings_button.offset_left = -196.0 if _phone_button.visible else -76.0
	settings_button.offset_right = settings_button.offset_left + 56.0
	_phone_button.modulate = Color(1.0, 0.85, 0.3) if _phone_pulse and int(_blink * 3.0) % 2 == 0 else Color.WHITE
	_update_dialogue(delta)
	touch.set_mode(player.vehicle != null and not player.passenger, Controls.scheme, player.passenger)
	var ride_id: int = player.vehicle.get_instance_id() if player.vehicle != null else 0
	if ride_id != _ride_id:
		_ride_id = ride_id
		_ride_name_time = 2.5
	_ride_name_time -= delta
	if player.passenger:
		_prompt.text = "" # the taxi's own panel and ride bar
	elif player.vehicle != null:
		_prompt.text = "%d km/h" % int(absf(player.vehicle.speed) * 3.6)
		if _ride_name_time > 0.0:
			_prompt.text = player.vehicle.model_name() + "   " + _prompt.text
		touch.set_label("interact", "EXIT")
		touch.set_label("sprint", "DRIFT")
	elif context_prompt.size() == 2:
		_prompt.text = context_prompt[0]
		touch.set_label("interact", context_prompt[1])
		touch.set_label("sprint", "RUN")
	elif game.taxi != null and not game.taxi.prompt().is_empty():
		var cab_prompt: Array = game.taxi.prompt()
		_prompt.text = cab_prompt[0]
		touch.set_label("interact", cab_prompt[1])
		touch.set_label("sprint", "RUN")
	elif game.interiors != null and not game.interiors.prompt().is_empty():
		var place_prompt: Array = game.interiors.prompt()
		_prompt.text = place_prompt[0]
		touch.set_label("interact", place_prompt[1])
		touch.set_label("sprint", "RUN")
	else:
		var near = player.nearest_vehicle()
		var verb := "Ride" if near != null and near.shows_rider else "Get in"
		_prompt.text = "" if near == null else ("Steal it: E / ENTER" if near.has_ai_driver() else verb + ": E / ENTER")
		touch.set_label("interact", "ENTER")
		touch.set_label("sprint", "RUN")


## A cog on the settings button (the default font has no gear glyph).
func _draw_gear() -> void:
	var c := settings_button.size * 0.5
	var points := PackedVector2Array()
	for i in 48:
		var a := TAU * i / 48.0
		# Eight teeth: the outline steps out for 3 points in every 6.
		var r := 19.0 if i % 6 < 3 else 14.0
		points.append(c + Vector2(cos(a), sin(a)) * r)
	var ink := Color(0.92, 0.92, 0.92)
	settings_button.draw_colored_polygon(points, ink)
	settings_button.draw_circle(c, 6.0, Color(0.16, 0.17, 0.2))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_TAB:
				touch.visible = not touch.visible
			KEY_P:
				if _phone_button.visible:
					phone.open()
			KEY_H:
				game.eat_snack()
			KEY_ENTER, KEY_KP_ENTER:
				if _dialogue.visible:
					_advance_dialogue()


func show_message(text: String) -> void:
	_message.text = text
	if _message_tween:
		_message_tween.kill()
	_message_tween = create_tween()
	_message.modulate.a = 1.0
	_message_tween.tween_interval(2.0)
	_message_tween.tween_property(_message, "modulate:a", 0.0, 0.6)


func set_objective(text: String) -> void:
	_objective.text = text


func pulse_phone(on: bool) -> void:
	_phone_pulse = on


# --- Dialogue ------------------------------------------------------------------

## Shows one line; `done` is called when it times out or the player taps it.
func show_dialogue(speaker: String, text: String, done := Callable()) -> void:
	_speaker.text = speaker.to_upper()
	_speaker.add_theme_color_override("font_color", SPEAKER_COLORS.get(speaker, Color(0.85, 0.85, 0.85)))
	_line.text = text
	_dialogue.visible = true
	_dialogue_done = done
	_dialogue_time = 1.6 + text.length() * 0.045


func hide_dialogue() -> void:
	_dialogue.visible = false
	_dialogue_done = Callable()


func _update_dialogue(delta: float) -> void:
	if not _dialogue.visible:
		return
	_dialogue_time -= delta
	if _dialogue_time <= 0.0:
		_advance_dialogue()


func _advance_dialogue() -> void:
	var done := _dialogue_done
	_dialogue_done = Callable()
	if done.is_valid():
		done.call()
	else:
		_dialogue.visible = false


func _build_dialogue() -> void:
	_dialogue = PanelContainer.new()
	_anchor(_dialogue, Vector2(0.5, 1), Rect2(-330, -230, 660, 120))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.08, 0.82)
	style.set_corner_radius_all(14)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	_dialogue.add_theme_stylebox_override("panel", style)
	_dialogue.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialogue.gui_input.connect(func(e):
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			_advance_dialogue())
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue.add_child(box)
	_speaker = Label.new()
	_speaker.add_theme_font_size_override("font_size", 18)
	box.add_child(_speaker)
	_line = Label.new()
	_line.add_theme_font_size_override("font_size", 22)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_line)
	_dialogue.visible = false
	root.add_child(_dialogue)


# --- Title cards -----------------------------------------------------------------

func show_card(title: String, sub := "", seconds := 2.5, color := Color.WHITE) -> void:
	_card_title.text = title
	_card_title.add_theme_color_override("font_color", color)
	_card_sub.text = sub
	if _card_tween:
		_card_tween.kill()
	_card.modulate.a = 0.0
	_card.visible = true
	_card_tween = create_tween()
	_card_tween.tween_property(_card, "modulate:a", 1.0, 0.25)
	_card_tween.tween_interval(seconds)
	_card_tween.tween_property(_card, "modulate:a", 0.0, 0.5)
	_card_tween.tween_callback(func(): _card.visible = false)


func card_text() -> String:
	return _card_title.text if _card.visible else ""


func _build_card() -> void:
	_card = VBoxContainer.new()
	_anchor(_card, Vector2(0.5, 0.5), Rect2(-500, -110, 1000, 220))
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.alignment = BoxContainer.ALIGNMENT_CENTER
	_card_title = _label(_card, 64)
	_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_sub = _label(_card, 26)
	_card_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.visible = false
	root.add_child(_card)


# --- Retry prompt ----------------------------------------------------------------

func ask_retry(on_retry: Callable, on_later: Callable) -> void:
	_retry.visible = true
	var buttons: HBoxContainer = _retry.get_node("Box/Buttons")
	for b in buttons.get_children():
		for c in b.pressed.get_connections():
			b.pressed.disconnect(c.callable)
	buttons.get_node("Retry").pressed.connect(func(): _retry.visible = false; on_retry.call())
	buttons.get_node("Later").pressed.connect(func(): _retry.visible = false; on_later.call())


func retry_visible() -> bool:
	return _retry.visible


func _build_retry() -> void:
	_retry = PanelContainer.new()
	_anchor(_retry, Vector2(0.5, 0.5), Rect2(-220, 60, 440, 130))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.08, 0.88)
	style.set_corner_radius_all(14)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	_retry.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.name = "Box"
	_retry.add_child(box)
	var q := Label.new()
	q.text = "Retry the mission?"
	q.add_theme_font_size_override("font_size", 24)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(q)
	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	box.add_child(buttons)
	for n in ["Retry", "Later"]:
		var b := Button.new()
		b.name = n
		b.text = n.to_upper()
		b.custom_minimum_size = Vector2(150, 56)
		b.add_theme_font_size_override("font_size", 22)
		b.focus_mode = Control.FOCUS_NONE
		buttons.add_child(b)
	_retry.visible = false
	root.add_child(_retry)


# --- Misc ------------------------------------------------------------------------

## Shows the district name for a few seconds whenever the player enters one.
func _update_district(pos: Vector3) -> void:
	var d: Dictionary = game.city.district_at(pos)
	if d.is_empty() or d.id == _district_id:
		return
	_district_id = d.id
	show_banner(d.name)


## A name across the top of the screen for a moment (districts, places).
func show_banner(text: String) -> void:
	_district.text = text
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
