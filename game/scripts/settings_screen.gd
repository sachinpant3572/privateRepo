extends Control
## Settings, from the phone and the HUD gear: tabs along the top (Camera,
## Graphics, Controls, Game), the settings down the left with a line under
## each saying what it does, and a live preview of the game view on the
## right. The game stays paused; only its camera keeps running while the page
## is open, so a change eases in the preview exactly as it would in play.

const TABS := ["Camera", "Graphics", "Controls", "Game"]
const HINT := Color(0.62, 0.66, 0.74)

var phone
## The open tab (kept between visits).
var tab := "Camera"
## The steppers on the open tab by name (Distance, Drive zoom-out, Angle,
## FPS limit), for tests.
var steppers := {}
var preview: SubViewport
var preview_cam: Camera3D
var _aspect: AspectRatioContainer
var _scroll: ScrollContainer
var _list: VBoxContainer
var _tabs := {}
var _back: Button
var _drive_b: Button
var _cam_mode := Node.PROCESS_MODE_INHERIT
var _world_tick := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var bg := ColorRect.new()
	bg.color = phone.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	col.add_child(top)
	var title: Label = phone._text("Settings", 26, phone.ACCENT)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.custom_minimum_size = Vector2(130, 0)
	top.add_child(title)
	for t in TABS:
		var b: Button = phone._button(t, show_tab.bind(t))
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(150, 56)
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		_tabs[t] = b
		top.add_child(b)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	_back = phone._button("BACK", func(): phone._on_back())
	_back.custom_minimum_size = Vector2(130, 56)
	_back.mouse_filter = Control.MOUSE_FILTER_STOP
	top.add_child(_back)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	col.add_child(body)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(500, 0)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	phone.touch_scroll(_scroll)
	body.add_child(_scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_right", 36)
	_scroll.add_child(pad)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	pad.add_child(_list)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	body.add_child(right)
	_aspect = AspectRatioContainer.new()
	_aspect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_aspect.alignment_vertical = AspectRatioContainer.ALIGNMENT_BEGIN
	right.add_child(_aspect)
	var holder := SubViewportContainer.new()
	holder.stretch = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aspect.add_child(holder)
	preview = SubViewport.new()
	preview.gui_disable_input = true
	preview.audio_listener_enable_3d = false
	preview.render_target_update_mode = SubViewport.UPDATE_DISABLED
	holder.add_child(preview)
	preview_cam = Camera3D.new()
	preview_cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	preview_cam.current = true
	preview.add_child(preview_cam)
	var under := HBoxContainer.new()
	under.add_theme_constant_override("separation", 12)
	right.add_child(under)
	_drive_b = phone._button("", func(): _preview_driving(not phone.game.camera.preview_drive))
	_drive_b.custom_minimum_size = Vector2(300, 56)
	_drive_b.mouse_filter = Control.MOUSE_FILTER_STOP
	under.add_child(_drive_b)
	var note: Label = phone._text("Game paused. The preview shows the view with these settings.", 16, HINT)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	under.add_child(note)


## Opens the page (the game is already paused by the phone). `back` is
## BACK (to the phone's apps) or CLOSE (from the gear).
func show_page(back := "BACK") -> void:
	_back.text = back
	if visible:
		return
	visible = true
	var cam = phone.game.camera
	if cam != null:
		_cam_mode = cam.process_mode
		cam.process_mode = Node.PROCESS_MODE_ALWAYS
	# Rain keeps falling in the preview.
	for p in _rain_nodes():
		p.process_mode = Node.PROCESS_MODE_ALWAYS
	var screen := get_viewport().get_visible_rect().size
	_aspect.ratio = screen.x / maxf(screen.y, 1.0)
	preview.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# The page covers the game view, so it isn't drawn twice.
	get_viewport().disable_3d = true
	_preview_driving(false)
	_follow()
	_refresh_world()
	show_tab(tab)


func hide_page() -> void:
	if not visible:
		return
	visible = false
	var cam = phone.game.camera
	if cam != null:
		cam.preview_drive = false
		cam.process_mode = _cam_mode
	for p in _rain_nodes():
		p.process_mode = Node.PROCESS_MODE_INHERIT
	preview.render_target_update_mode = SubViewport.UPDATE_DISABLED
	get_viewport().disable_3d = false


func _process(delta: float) -> void:
	if not visible:
		return
	_follow()
	# The city and country stream round the view with their own threaded
	# step (a cell at a time, no hitch), just as in play.
	var city = phone.game.city
	if city != null:
		city._process(delta)
		if city.country != null:
			city.country._process(delta)
	_world_tick -= delta
	if _world_tick <= 0.0:
		_world_tick = 0.25
		_refresh_world()


## The game is paused, so the page keeps up to date what the preview shows:
## the light after a clock skip, the shadows' reach and the headlights.
func _refresh_world() -> void:
	var game = phone.game
	if game.atmosphere != null:
		game.atmosphere._apply(0.0)
		game.atmosphere._fit_shadows()
	get_tree().call_group("vehicles", "update_beams")


## The preview camera copies the game camera, so it shows just what the
## screen will.
func _follow() -> void:
	var c: Camera3D = phone.game.camera
	if c == null:
		return
	preview_cam.projection = c.projection
	preview_cam.keep_aspect = c.keep_aspect
	preview_cam.fov = c.fov
	preview_cam.size = c.size
	preview_cam.near = c.near
	preview_cam.far = c.far
	preview_cam.h_offset = c.h_offset
	preview_cam.v_offset = c.v_offset
	preview_cam.frustum_offset = c.frustum_offset
	preview_cam.cull_mask = c.cull_mask
	preview_cam.environment = c.environment
	preview_cam.attributes = c.attributes
	preview_cam.global_transform = c.global_transform


## The rain and splash particles, which run while the page is open.
func _rain_nodes() -> Array:
	var atm = phone.game.atmosphere
	return [atm._rain, atm._splash] if atm != null and atm._rain != null else []


## "Driving fast" frames the view as the car at full speed would (Drive
## zoom-out shows even on foot); "As now" is the view as it stands.
func _preview_driving(on: bool) -> void:
	# Only while the page is open: the game must never drive a pretend car.
	on = on and visible
	var cam = phone.game.camera
	if cam != null:
		cam.preview_drive = on
	_drive_b.text = "Preview: Driving fast" if on else "Preview: As now"


func show_tab(t: String) -> void:
	tab = t
	for k in _tabs:
		_tabs[k].set_pressed_no_signal(k == t)
	steppers.clear()
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_scroll.scroll_vertical = 0
	match t:
		"Camera": _camera_tab()
		"Graphics": _graphics_tab()
		"Controls": _controls_tab()
		"Game": _game_tab()


# --- Tabs ------------------------------------------------------------------------

func _turn_label() -> String:
	var cam = phone.game.camera
	return "Camera turn: " + ("North up" if not cam.turn_view else "90° turns" if cam.turn_steps else "Follow")


func _tilt_label() -> String:
	return "Look down near towers: " + ("ON" if phone.game.camera.auto_tilt else "OFF")


func _camera_tab() -> void:
	var game = phone.game
	var s: Dictionary = game.settings
	var cam = game.camera
	var vb: Button = phone._button("View: " + ("CLASSIC" if str(s.get("view")) == "classic" else "PERSPECTIVE"), Callable())
	vb.pressed.connect(func():
		s["view"] = "perspective" if str(s.get("view")) == "classic" else "classic"
		game.apply_settings()
		vb.text = "View: " + s["view"].to_upper())
	_row(vb, "Perspective tips the city in 3D. Classic looks flat down on it like a map.")
	_row(_stepper("Distance", "zoom", cam.ZOOMS, func(): return cam.zoom, func(v): return "%d%%" % roundi(v * 100.0)),
		"How far away the camera sits. Higher shows more of the city.")
	var drive := _stepper("Drive zoom-out", "drive_zoom", cam.DRIVE_ZOOMS, func(): return cam.drive_zoom, func(v): return "Off" if v == 0.0 else "%d%%" % roundi(v * 100.0))
	# Shown at speed: a change here switches the preview to driving.
	for b in [drive.get_meta("less"), drive.get_meta("more")]:
		b.pressed.connect(_preview_driving.bind(true))
	_row(drive, "How far the camera backs out as a car speeds up. Off keeps the walking distance.")
	_row(_stepper("Angle", "angle", cam.ANGLES, func(): return cam.base_pitch, func(v): return "%d°" % roundi(v)),
		"How steeply the camera looks down (perspective view). 90° is straight down.")
	var tilt_b: Button = phone._button(_tilt_label(), Callable())
	tilt_b.pressed.connect(func():
		s["auto_tilt"] = not cam.auto_tilt
		game.apply_settings()
		tilt_b.text = _tilt_label())
	_row(tilt_b, "Among tall buildings the camera tips further down (up to 85°) so towers don't hide you or the street, then goes back to your Angle. OFF keeps your Angle always. Shows among towers.")
	var turn_b: Button = phone._button(_turn_label(), Callable())
	turn_b.pressed.connect(func():
		# Follow -> 90° turns -> North up -> Follow.
		s["camera_turn"] = "car" if not cam.turn_view else "north" if cam.turn_steps else "steps"
		game.apply_settings()
		turn_b.text = _turn_label())
	_row(turn_b, "Follow: the view turns with the car and your walk. 90° turns: only when you turn a whole corner. North up: never turns. Shows once you move.")
	var reset_b: Button = phone._button("Reset camera", Callable())
	reset_b.pressed.connect(func():
		s["angle"] = cam.PITCH_LOW
		s["auto_tilt"] = true
		s["zoom"] = 1.0
		s["drive_zoom"] = 1.0
		game.apply_settings()
		tilt_b.text = _tilt_label()
		for row in steppers.values():
			row.get_meta("refresh").call())
	_row(reset_b, "Back to 65°, look down near towers on, 100% distance and drive zoom-out.")


func _graphics_tab() -> void:
	var game = phone.game
	var s: Dictionary = game.settings
	var G = game.Graphics
	var q := _stepper("Quality", "quality", G.QUALITIES, func(): return s.get("quality", "high"),
		func(v): return str(v).capitalize() + ("" if _matches_preset(s) else " *"))
	for b in [q.get_meta("less"), q.get_meta("more")]:
		b.pressed.connect(func():
			G.pick(s, s["quality"])
			game.apply_settings()
			show_tab.call_deferred("Graphics"))
	_row(q, "Low runs fastest on older phones; Ultra looks best (smooth edges, shadows from your headlights). Picking one sets everything below; * means you changed something by hand.")
	var effect := func(label: String, key: String, hint: String):
		_row(phone._toggle(label, s.get(key, true), func(on):
			s[key] = on
			game.apply_settings()
			q.get_meta("refresh").call()), hint)
	effect.call("Bloom", "bloom", "Bright lights (lamps, neon, headlights) glow softly round the edges.")
	effect.call("Smooth edges", "aa", "Anti-aliasing (4x MSAA): no jagged edges. Costs speed on older phones.")
	effect.call("Vivid colour", "vivid", "A touch more colour and contrast.")
	effect.call("Real lights", "real_lights", "Headlights, street lamps and police lights light up the road, walls and people round them at night. OFF keeps only the painted glow on the ground.")
	var db: Button = phone._button("Detail: " + s.get("detail", "high").to_upper(), Callable())
	db.pressed.connect(func():
		s["detail"] = "low" if s.get("detail", "high") == "high" else "high"
		game.apply_settings()
		db.text = "Detail: " + s["detail"].to_upper()
		q.get_meta("refresh").call())
	_row(db, "Low: flat colours, no grain or puddles, lighter rain. Easier on older phones.")
	effect.call("Shadows", "shadows", "Sun shadows. OFF runs faster.")
	_row(_stepper("FPS limit", "fps_limit", game.FPS_LIMITS, func(): return game.fps_limit(), func(v): return str(v)),
		"The most frames a second the game draws. Lower saves battery and heat. 30, 60 and 120 run smoothest on a 120 Hz screen; 75 and 90 can judder there.")
	_row(phone._toggle("Show FPS", s.get("show_fps", true), func(on): s["show_fps"] = on; game.apply_settings()),
		"The frame counter in the corner.")


func _controls_tab() -> void:
	var game = phone.game
	var cb: Button = phone._button("Driving: " + Controls.SCHEME_NAMES[Controls.scheme], Callable())
	cb.pressed.connect(func():
		game.settings["controls"] = Controls.SCHEMES[(Controls.SCHEMES.find(Controls.scheme) + 1) % Controls.SCHEMES.size()]
		game.apply_settings()
		cb.text = "Driving: " + Controls.SCHEME_NAMES[Controls.scheme])
	_row(cb, "Steering in a car: a stick, left and right arrows, or tilting the phone. The pedals stay on the right.")


func _game_tab() -> void:
	var game = phone.game
	var s: Dictionary = game.settings
	var weathers := ["auto", "clear", "rain", "storm"]
	var wb: Button = phone._button("Weather: " + s.get("weather", "auto").to_upper(), Callable())
	wb.pressed.connect(func():
		var i := (weathers.find(s.get("weather", "auto")) + 1) % weathers.size()
		s["weather"] = weathers[i]
		game.apply_settings()
		wb.text = "Weather: " + weathers[i].to_upper())
	_row(wb, "AUTO changes through the day; or hold it clear, rain or storm.")
	var tb: Button = phone._button("Skip 3 hours (now %s)" % game.atmosphere.clock_text(), Callable())
	tb.pressed.connect(func():
		game.atmosphere.hour = fmod(game.atmosphere.hour + 3.0, 24.0)
		tb.text = "Skip 3 hours (now %s)" % game.atmosphere.clock_text())
	_row(tb, "Moves the clock on. The preview shows the new light and headlights.")
	var reset: Button = phone._button("New game (erase progress)", Callable())
	reset.pressed.connect(func():
		if reset.text.begins_with("Tap again"):
			game.missions.reset_progress()
			phone.close()
			game.restart_story()
		else:
			reset.text = "Tap again to erase everything")
	_row(reset, "Erases all progress and starts the story again. Tap twice.")
	_log_section()


## Log: on/off, the HUD's BUG button, Report issue, Export and Copy, and a
## line saying what the last of those did.
func _log_section() -> void:
	var game = phone.game
	var s: Dictionary = game.settings
	var lg = game.game_log
	var head: Label = phone._text("Log", 22, phone.ACCENT)
	head.set_meta("section", true)
	_list.add_child(head)
	var status: Label = phone._text(lg.last_status if lg.last_status != "" else "Nothing exported yet.", 16, Color(1.0, 0.85, 0.4))
	var say := func(): status.text = lg.last_status
	_row(phone._toggle("Log", s.get("log", true), func(on): s["log"] = on; game.apply_settings()),
		"Notes down every second (FPS, frame times, cars and people round you, where you are, weather, camera) and everything that happens, with every error, to share when something goes wrong.")
	_row(phone._toggle("BUG button", s.get("log_button", true), func(on): s["log_button"] = on; game.apply_settings()),
		"A small BUG button under SKY on the screen: tap it the moment something goes wrong to mark it in the log.")
	var rb: Button = phone._button("Report issue", Callable())
	rb.pressed.connect(func():
		if lg.report("settings") == 0:
			lg.last_status = "Turn the log on first"
			say.call()
			return
		lg.export(func(_ok, _where): say.call())
		say.call())
	_row(rb, "Marks this moment (everything now and the last minute) and saves the log for you to send.")
	var eb: Button = phone._button("Export log", Callable())
	eb.pressed.connect(func():
		lg.export(func(_ok, _where): say.call())
		say.call())
	_row(eb, "Saves the log as a text file: pick Downloads or Drive in the Save box, then share it.")
	var cb: Button = phone._button("Copy log", Callable())
	cb.pressed.connect(func():
		lg.copy_to_clipboard()
		say.call())
	_row(cb, "Copies the newest part (up to 200 KB) to paste into a chat.")
	status.set_meta("section", true)
	_list.add_child(status)


# --- Widgets ---------------------------------------------------------------------

## A setting and the line under it saying what it does.
## True while the effects are as the chosen quality preset sets them.
func _matches_preset(s: Dictionary) -> bool:
	var preset: Dictionary = phone.game.Graphics.PRESETS.get(s.get("quality", "high"), {})
	for k in phone.game.Graphics.KEYS:
		if preset.get(k) != s.get(k):
			return false
	return true


func _row(widget: Control, hint: String) -> void:
	_list.add_child(widget)
	_list.add_child(phone._text(hint, 16, HINT))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	_list.add_child(gap)


## A setting with - and + buttons either side of its value: `values` in
## order, `now` reads the current one, `shown` formats it. Steps stop at the
## ends rather than wrapping round.
func _stepper(label: String, key: String, values: Array, now: Callable, shown: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name_l: Label = phone._text(label, 20, Color.WHITE)
	name_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_l)
	var less: Button = phone._button("-", Callable())
	var more: Button = phone._button("+", Callable())
	var value: Label = phone._text("", 20, Color(1.0, 0.85, 0.4))
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
		phone.game.settings[key] = values[i]
		phone.game.apply_settings()
		refresh.call()
	less.pressed.connect(step.bind(-1))
	more.pressed.connect(step.bind(1))
	row.set_meta("refresh", refresh)
	row.set_meta("less", less)
	row.set_meta("more", more)
	row.set_meta("value", value)
	refresh.call()
	steppers[label] = row
	return row
