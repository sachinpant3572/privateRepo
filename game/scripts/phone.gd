extends Control
## Jules's phone (unlocked by "Empty Rooms"). Opening it pauses the game.
## Apps: Messages and Contacts (filled in as the story goes), Map (the full
## map), Places (shops and diners, with a waypoint to each), Missions
## (progress and replays), Cab (call a taxi, taxi.gd) and Settings
## (graphics, weather, time, new game).

const Places = preload("res://scripts/places.gd")
const BG := Color(0.07, 0.08, 0.11)
const ACCENT := Color(1.0, 0.78, 0.25)

var game
## Times the phone has been opened (missions wait on it).
var open_count := 0

var _frame: PanelContainer
var _title: Label
var _body: VBoxContainer
var _back: Button
## The Camera steppers by name (Distance, Drive zoom-out, Angle), for tests.
var steppers := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_frame = PanelContainer.new()
	_frame.anchor_left = 0.5
	_frame.anchor_right = 0.5
	_frame.anchor_top = 0.5
	_frame.anchor_bottom = 0.5
	_frame.offset_left = -210
	_frame.offset_right = 210
	_frame.offset_top = -340
	_frame.offset_bottom = 340
	var style := StyleBoxFlat.new()
	style.bg_color = BG
	style.set_corner_radius_all(36)
	style.set_border_width_all(10)
	style.border_color = Color(0.02, 0.02, 0.03)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	_frame.add_theme_stylebox_override("panel", style)
	add_child(_frame)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	_frame.add_child(col)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", ACCENT)
	col.add_child(_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 10)
	scroll.add_child(_body)
	_back = _button("CLOSE", func(): _on_back())
	col.add_child(_back)


func open() -> void:
	if visible:
		return
	open_count += 1
	visible = true
	get_tree().paused = true
	_home()


## The HUD's gear: straight to Settings, and back closes (the phone's
## other apps stay locked until the story unlocks it).
func open_settings() -> void:
	if visible:
		return
	open_count += 1
	visible = true
	get_tree().paused = true
	_settings("CLOSE")


func close() -> void:
	visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.physical_keycode in [KEY_ESCAPE, KEY_P]:
		close()
		get_viewport().set_input_as_handled()


func _on_back() -> void:
	if _back.text == "CLOSE":
		close()
	else:
		_home()


func _clear(title: String, back := "BACK") -> void:
	_title.text = title
	_back.text = back
	for c in _body.get_children():
		c.queue_free()


func _home() -> void:
	_clear("%s   ·   $%d" % [game.atmosphere.clock_text(), game.cash], "CLOSE")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	_body.add_child(grid)
	for app in [["Messages", _messages], ["Contacts", _contacts], ["Map", _map], ["Places", _places], ["Missions", _missions], ["Cab", _cab], ["Settings", _settings]]:
		var b := _button(app[0], app[1])
		b.custom_minimum_size = Vector2(170, 110)
		grid.add_child(b)


# --- Apps ------------------------------------------------------------------------

func _done(id: String) -> bool:
	return game.missions.done.has(id)


func _messages() -> void:
	_clear("Messages")
	_thread("Teo", [
		"Jules, if you get this, I messed up. Big.",
		"Don't trust the man in gold.",
		"The river crates are the only thing keeping me alive.",
		"Tell Nia I'm sorry.",
	], "4 days ago")
	if _done("m02_empty_rooms"):
		_thread("Nia", ["Remy's scared but he'll live.", "We find Teo. Then you can leave again if you want."], "Today")
	if _done("m03_lantern_lights"):
		_thread("Celeste", ["Marcel plays tonight. First drink is on me.", "And Jules, Aurum doesn't forget a face. Neither do I."], "Tonight")


func _thread(who: String, lines: Array, when: String) -> void:
	_body.add_child(_text("%s   ·   %s" % [who.to_upper(), when], 18, ACCENT))
	for l in lines:
		var bubble := PanelContainer.new()
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.16, 0.18, 0.24)
		st.set_corner_radius_all(14)
		st.content_margin_left = 12
		st.content_margin_right = 12
		st.content_margin_top = 8
		st.content_margin_bottom = 8
		bubble.add_theme_stylebox_override("panel", st)
		bubble.add_child(_text(l, 19, Color.WHITE))
		_body.add_child(bubble)


func _contacts() -> void:
	_clear("Contacts")
	var list := [["Nia Batiste", "High Water"], ["Teo Moreau", "No signal for 4 days"]]
	if _done("m02_empty_rooms"):
		list.append(["Remy", "Floodline Clinic"])
	if game.missions.done.has("m02_empty_rooms") or game.missions.active != null and game.missions.active.id == "m03_lantern_lights":
		list.append(["Celeste Durand", "The Blue Lantern"])
	if _done("m03_lantern_lights"):
		list.append(["Capt. Dana Reyes", "Lantern Quarter Precinct"])
		list.append(["Marcel", "Bandleader, The Blue Lantern"])
	for c in list:
		_body.add_child(_text(c[0], 22, Color.WHITE))
		_body.add_child(_text(c[1], 16, Color(0.7, 0.72, 0.78)))


func _map() -> void:
	close()
	game.hud.full_map.open()


## Shops and diners, nearest first; GO sets a waypoint to the door.
func _places() -> void:
	_clear("Places")
	var from: Vector3 = game.player.focus_node().global_position
	if not game.interiors.place.is_empty():
		from = game.interiors.place.door
	var list: Array = game.city.places.duplicate()
	list.sort_custom(func(a, b): return from.distance_to(a.door) < from.distance_to(b.door))
	for p in list:
		_body.add_child(_text(p.name, 22, Color.WHITE))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var open := Places.is_open(p, game.atmosphere.hour)
		var info := _text("%s · %s · %d m · %s" % [Places.TYPES[p.type].label, p.district_name, int(from.distance_to(p.door)), "Open" if open else "Closed"], 16, Color(0.7, 0.72, 0.78))
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var go := _button("GO", func():
			game.waypoint = game.city.node_pos(game.city.nearest_node(p.door))
			close())
		go.custom_minimum_size = Vector2(80, 48)
		row.add_child(go)
		_body.add_child(row)


func _missions() -> void:
	_clear("Missions · Act 1")
	var mm = game.missions
	var next: Dictionary = mm.next_mission()
	var n := 1
	for m in mm.MISSIONS:
		_body.add_child(_text("%d. %s" % [n, m.name], 22, Color.WHITE))
		if mm.done.has(m.id):
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 16)
			var passed := _text("Passed", 17, Color(0.5, 0.95, 0.5))
			passed.autowrap_mode = TextServer.AUTOWRAP_OFF
			passed.custom_minimum_size = Vector2(90, 0)
			row.add_child(passed)
			var b := _button("REPLAY", func(): close(); mm.start(m.id, true))
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(b)
			_body.add_child(row)
		elif mm.active != null and mm.active.id == m.id:
			_body.add_child(_text("In progress", 17, ACCENT))
		elif not next.is_empty() and next.id == m.id:
			_body.add_child(_text("Next: follow the yellow marker" + (" (" + m.giver + ")" if m.giver != "" else ""), 17, ACCENT))
		n += 1
	for name_ in mm.LATER:
		_body.add_child(_text("%d. %s" % [n, name_], 22, Color(0.5, 0.5, 0.55)))
		_body.add_child(_text("Not in this demo", 16, Color(0.45, 0.45, 0.5)))
		n += 1


## Calls a cab to the curb nearest you (or sends it away).
func _cab() -> void:
	_clear("Cab")
	var taxi = game.taxi
	_body.add_child(_text(taxi.phone_status(), 22, Color.WHITE))
	_body.add_child(_text(taxi.price_text(), 17, Color(0.7, 0.72, 0.78)))
	if taxi.state == taxi.State.PICKUP or taxi.state == taxi.State.WAITING:
		_body.add_child(_button("SEND IT AWAY", func(): taxi.cancel_cab(); _cab()))
		return
	var why: String = taxi.call_reason()
	if why != "":
		_body.add_child(_text(why, 19, ACCENT))
		return
	var status := _text("", 19, ACCENT)
	_body.add_child(_button("CALL A CAB", func():
		var reason: String = taxi.call_cab()
		if reason == "":
			close()
		else:
			status.text = reason))
	_body.add_child(status)


func _turn_label() -> String:
	return "Camera turn: " + ("Follow" if game.camera.turn_view else "North up")


func _settings(back := "BACK") -> void:
	_clear("Settings", back)
	steppers.clear()
	var s: Dictionary = game.settings
	var cam = game.camera
	_body.add_child(_text("Camera", 22, Color(0.75, 0.8, 0.9)))
	var vb := _button("View: " + ("CLASSIC" if str(s.get("view")) == "classic" else "PERSPECTIVE"), Callable())
	vb.pressed.connect(func():
		s["view"] = "perspective" if str(s.get("view")) == "classic" else "classic"
		game.apply_settings()
		vb.text = "View: " + s["view"].to_upper())
	_body.add_child(vb)
	_stepper("Distance", "zoom", cam.ZOOMS, func(): return cam.zoom, func(v): return "%d%%" % roundi(v * 100.0))
	_stepper("Drive zoom-out", "drive_zoom", cam.DRIVE_ZOOMS, func(): return cam.drive_zoom, func(v): return "Off" if v == 0.0 else "%d%%" % roundi(v * 100.0))
	# Camera angle (perspective view only).
	_stepper("Angle", "angle", cam.ANGLES, func(): return cam.base_pitch, func(v): return "%d°" % roundi(v))
	var tilt_b := _button("Tilt near towers: " + ("ON" if cam.auto_tilt else "OFF"), Callable())
	tilt_b.pressed.connect(func():
		s["auto_tilt"] = not cam.auto_tilt
		game.apply_settings()
		tilt_b.text = "Tilt near towers: " + ("ON" if cam.auto_tilt else "OFF"))
	_body.add_child(tilt_b)
	var turn_b := _button(_turn_label(), Callable())
	turn_b.pressed.connect(func():
		s["camera_turn"] = "north" if cam.turn_view else "car"
		game.apply_settings()
		turn_b.text = _turn_label())
	_body.add_child(turn_b)
	var reset_b := _button("Reset camera", Callable())
	reset_b.pressed.connect(func():
		s["angle"] = cam.PITCH_LOW
		s["auto_tilt"] = true
		s["zoom"] = 1.0
		s["drive_zoom"] = 1.0
		game.apply_settings()
		tilt_b.text = "Tilt near towers: ON"
		for row in steppers.values():
			row.get_meta("refresh").call())
	_body.add_child(reset_b)
	_body.add_child(_text("Game", 22, Color(0.75, 0.8, 0.9)))
	var db := _button("Detail: " + s.get("detail", "high").to_upper(), Callable())
	db.pressed.connect(func():
		s["detail"] = "low" if s.get("detail", "high") == "high" else "high"
		game.apply_settings()
		db.text = "Detail: " + s["detail"].to_upper())
	_body.add_child(db)
	_body.add_child(_toggle("Shadows", s.get("shadows", true), func(on): s["shadows"] = on; game.apply_settings()))
	_body.add_child(_toggle("Show FPS", s.get("show_fps", true), func(on): s["show_fps"] = on; game.apply_settings()))
	var weathers := ["auto", "clear", "rain", "storm"]
	var wb := _button("Weather: " + s.get("weather", "auto").to_upper(), Callable())
	wb.pressed.connect(func():
		var i := (weathers.find(s.get("weather", "auto")) + 1) % weathers.size()
		s["weather"] = weathers[i]
		game.apply_settings()
		wb.text = "Weather: " + weathers[i].to_upper())
	_body.add_child(wb)
	var cb := _button("Driving: " + Controls.SCHEME_NAMES[Controls.scheme], Callable())
	cb.pressed.connect(func():
		s["controls"] = Controls.SCHEMES[(Controls.SCHEMES.find(Controls.scheme) + 1) % Controls.SCHEMES.size()]
		game.apply_settings()
		cb.text = "Driving: " + Controls.SCHEME_NAMES[Controls.scheme])
	_body.add_child(cb)
	var tb := _button("Skip 3 hours (now %s)" % game.atmosphere.clock_text(), Callable())
	tb.pressed.connect(func():
		game.atmosphere.hour = fmod(game.atmosphere.hour + 3.0, 24.0)
		tb.text = "Skip 3 hours (now %s)" % game.atmosphere.clock_text())
	_body.add_child(tb)
	var reset := _button("New game (erase progress)", Callable())
	reset.pressed.connect(func():
		if reset.text.begins_with("Tap again"):
			game.missions.reset_progress()
			close()
			game.restart_story()
		else:
			reset.text = "Tap again to erase everything")
	_body.add_child(reset)


# --- Widgets ---------------------------------------------------------------------

func _button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 56)
	b.add_theme_font_size_override("font_size", 20)
	if on_press.is_valid():
		b.pressed.connect(on_press)
	return b


## A setting with - and + buttons either side of its value: `values` in
## order, `now` reads the camera's current one, `shown` formats it. Steps
## stop at the ends rather than wrapping round.
func _stepper(label: String, key: String, values: Array, now: Callable, shown: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name_l := _text(label, 20, Color.WHITE)
	name_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_l)
	var less := _button("-", Callable())
	var more := _button("+", Callable())
	var value := _text("", 20, Color(1.0, 0.85, 0.4))
	value.custom_minimum_size = Vector2(80, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for b in [less, more]:
		b.custom_minimum_size = Vector2(64, 56)
	row.add_child(less)
	row.add_child(value)
	row.add_child(more)
	var refresh := func():
		var i := values.find(now.call())
		value.text = shown.call(now.call())
		less.disabled = i <= 0
		more.disabled = i < 0 or i >= values.size() - 1
	var step := func(by: int):
		var i := clampi(values.find(now.call()) + by, 0, values.size() - 1)
		game.settings[key] = values[i]
		game.apply_settings()
		refresh.call()
	less.pressed.connect(step.bind(-1))
	more.pressed.connect(step.bind(1))
	row.set_meta("refresh", refresh)
	row.set_meta("less", less)
	row.set_meta("more", more)
	row.set_meta("value", value)
	refresh.call()
	steppers[label] = row
	_body.add_child(row)
	return row


func _toggle(label: String, on: bool, changed: Callable) -> Button:
	var b := _button("%s: %s" % [label, "ON" if on else "OFF"], Callable())
	var state := [on]
	b.pressed.connect(func():
		state[0] = not state[0]
		b.text = "%s: %s" % [label, "ON" if state[0] else "OFF"]
		changed.call(state[0]))
	return b


func _text(t: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
