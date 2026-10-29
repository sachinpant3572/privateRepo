extends Control
## Settings, from the phone and the HUD gear: tabs along the top (Camera,
## Graphics, Controls, Game), the settings down the left with a line under
## each saying what it does, and a live preview of the game view on the
## right. The game stays paused; only its camera keeps running while the page
## is open, so a change eases in the preview exactly as it would in play.

const TouchControls = preload("res://scripts/touch_controls.gd")
const TABS := ["Camera", "Graphics", "Controls", "Game"]
const HINT := Color(0.62, 0.66, 0.74)

var phone
## The open tab (kept between visits).
var tab := "Camera"
## The sliders on the open tab by name (Distance, Drive zoom-out, Angle,
## Camera turn, Screen shake, Quality, FPS limit, Driving, Weather).
var sliders := {}
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
## The slider under the finger and the settings as they were when it went
## down (put back if the drag turns into a scroll).
var _held: HSlider = null
var _held_from := {}
var _grab_tex: Texture2D
var _grab_hi_tex: Texture2D
## Controls tab: a card per driving layout (by scheme), the chosen layout's
## controls drawn over the live preview, and the layout editor.
var cards := {}
var overlay: TouchControls
var editor: Control
var edit_touch: TouchControls
var _overlay_box: Control
var _edit_driving := false
var _edit_grab := Vector2.ZERO
var _edit_drag := false
var _edit_size: Label
var _edit_modes := {}


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
	_scroll.scroll_started.connect(_drop_held)
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
	# The Controls tab draws the chosen layout over the preview, at the
	# preview's scale.
	_overlay_box = Control.new()
	_overlay_box.clip_contents = true
	_overlay_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_box.visible = false
	_aspect.add_child(_overlay_box)
	overlay = _preview_controls(_overlay_box)
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
	_build_editor()


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
	close_editor()
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
	sliders.clear()
	_held = null
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_scroll.scroll_vertical = 0
	cards.clear()
	_overlay_box.visible = t == "Controls"
	match t:
		"Camera": _camera_tab()
		"Graphics": _graphics_tab()
		"Controls": _controls_tab()
		"Game": _game_tab()


# --- Tabs ------------------------------------------------------------------------

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
	_row(_slider("Distance", "zoom", cam.ZOOMS, func(): return cam.zoom, func(v): return "%d%%" % roundi(v * 100.0)),
		"How far away the camera sits. Higher shows more of the city.")
	var drive := _slider("Drive zoom-out", "drive_zoom", cam.DRIVE_ZOOMS, func(): return cam.drive_zoom, func(v): return "Off" if v == 0.0 else "%d%%" % roundi(v * 100.0))
	# Shown at speed: a change here switches the preview to driving.
	drive.get_meta("slider").value_changed.connect(func(_v): _preview_driving(true))
	_row(drive, "How far the camera backs out as a car speeds up. Off keeps the walking distance.")
	_row(_slider("Angle", "angle", cam.ANGLES, func(): return cam.base_pitch, func(v): return "%d°" % roundi(v)),
		"How steeply the camera looks down (perspective view). 90° is straight down.")
	var tilt_b: Button = phone._button(_tilt_label(), Callable())
	tilt_b.pressed.connect(func():
		s["auto_tilt"] = not cam.auto_tilt
		game.apply_settings()
		tilt_b.text = _tilt_label())
	_row(tilt_b, "Among tall buildings the camera tips further down (up to 85°) so towers don't hide you or the street, then goes back to your Angle. OFF keeps your Angle always. Shows among towers.")
	# From the most turning to none.
	_row(_slider("Camera turn", "camera_turn", ["car", "steps", "north"],
		func(): return "north" if not cam.turn_view else "steps" if cam.turn_steps else "car",
		func(v): return {"car": "Follow", "steps": "90° turns", "north": "North up"}[v]),
		"Follow: the view turns with the car and your walk. 90° turns: only when you turn a whole corner. North up: never turns. Shows once you move.")
	# Let go, the preview gives a bump at the new strength.
	_row(_slider("Screen shake", "shake", game.SHAKES, func(): return game.shake_percent(),
		func(v): return "Off" if v == 0 else "%d%%" % v, Callable(), func(): cam.shake(0.7)),
		"How hard hits, crashes and explosions shake the view. 100% is the full shake; Off holds it still. Let go and the preview shakes once.")
	var reset_b: Button = phone._button("Reset camera", Callable())
	reset_b.pressed.connect(func():
		s["angle"] = cam.PITCH_LOW
		s["auto_tilt"] = true
		s["zoom"] = 1.0
		s["drive_zoom"] = 1.0
		game.apply_settings()
		tilt_b.text = _tilt_label()
		for row in sliders.values():
			row.get_meta("refresh").call())
	_row(reset_b, "Back to 65°, look down near towers on, 100% distance and drive zoom-out.")


func _graphics_tab() -> void:
	var game = phone.game
	var s: Dictionary = game.settings
	var G = game.Graphics
	# Picking a level sets every effect below it, which redraws them (once
	# the finger lets go).
	var q := _slider("Quality", "quality", G.QUALITIES, func(): return s.get("quality", "high"),
		func(v): return str(v).capitalize() + ("" if _matches_preset(s) else " *"),
		func(v): G.pick(s, v), func(): show_tab.call_deferred("Graphics"))
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
	_row(_slider("FPS limit", "fps_limit", game.FPS_LIMITS, func(): return game.fps_limit(), func(v): return str(v)),
		"The most frames a second the game draws. Lower saves battery and heat. 30, 60 and 120 run smoothest on a 120 Hz screen; 75 and 90 can judder there.")
	_row(phone._toggle("Show FPS", s.get("show_fps", true), func(on): s["show_fps"] = on; game.apply_settings()),
		"The frame counter in the corner.")


func _controls_tab() -> void:
	var game = phone.game
	var head: Label = phone._text("Driving", 20, Color.WHITE)
	head.set_meta("section", true)
	_list.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for scheme in Controls.SCHEMES:
		grid.add_child(_scheme_card(scheme))
	_row(grid, "Steering in a car: a stick, arrow buttons, arrows that appear wherever your thumb lands (floating), or tilting the phone. The pedals stay on the right. The preview shows the one picked.")
	var edit := HBoxContainer.new()
	edit.add_theme_constant_override("separation", 10)
	for m in [["Edit on-foot layout", false], ["Edit driving layout", true]]:
		var b: Button = phone._button(m[0], open_editor.bind(m[1]))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit.add_child(b)
	_row(edit, "Drag any button, pedal or the stick to where your thumbs want it, and make it bigger or smaller.")
	_row(phone._button("Reset all controls", func():
		game.settings["touch_layout"].clear()
		game.apply_settings()
		_show_overlay()), "Puts every control back where it started, at its first size.")
	_show_overlay()


## A layout's card: a small drawing of its controls over a dark screen and
## its name; pressed, it is the layout used.
func _scheme_card(scheme: String) -> Button:
	var card: Button = phone._button("", func():
		phone.game.settings["controls"] = scheme
		phone.game.apply_settings()
		for k in cards:
			cards[k].set_pressed_no_signal(k == scheme)
		_show_overlay())
	card.toggle_mode = true
	card.set_pressed_no_signal(Controls.scheme == scheme)
	card.custom_minimum_size = Vector2(225, 170)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var screen := ColorRect.new()
	screen.color = Color(0.2, 0.23, 0.26)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.clip_contents = true
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.offset_left = 8
	screen.offset_top = 8
	screen.offset_right = -8
	screen.offset_bottom = -40
	card.add_child(screen)
	var road := ColorRect.new()
	road.color = Color(0.13, 0.14, 0.16)
	road.mouse_filter = Control.MOUSE_FILTER_IGNORE
	road.anchor_left = 0.35
	road.anchor_right = 0.62
	road.anchor_bottom = 1.0
	screen.add_child(road)
	var mini := _preview_controls(screen)
	mini.show_mode(true, scheme)
	var name_l: Label = phone._text(Controls.SCHEME_NAMES[scheme], 17, Color.WHITE)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	name_l.offset_top = -38
	name_l.offset_bottom = -6
	card.add_child(name_l)
	cards[scheme] = card
	return card


## Touch controls that are only drawn, filling `box` at the game screen's
## proportions (box.size / screen size), with the player's layout.
func _preview_controls(box: Control) -> TouchControls:
	var t := TouchControls.new()
	t.preview = true
	t.layout = phone.game.settings.get("touch_layout", {})
	box.add_child(t)
	var fit := func():
		var screen := get_viewport().get_visible_rect().size
		t.size = screen
		t.scale = Vector2.ONE * box.size.x / maxf(screen.x, 1.0)
		t.position = Vector2(0, (box.size.y - screen.y * t.scale.y) * 0.5)
	box.resized.connect(fit)
	fit.call()
	return t


## The live preview shows the picked driving layout with the player's
## placements.
func _show_overlay() -> void:
	overlay.layout = phone.game.settings["touch_layout"]
	overlay.show_mode(true, Controls.scheme)
	overlay.queue_redraw()
	for c in cards.values():
		for t in c.find_children("*", "Control", true, false):
			if t is TouchControls:
				t.layout = overlay.layout
				t.queue_redraw()


# --- Layout editor ---------------------------------------------------------------

## Full screen over the game view: the controls at their real size and
## place; drag one to move it, tap it and use - / + to resize it.
func _build_editor() -> void:
	editor = Control.new()
	editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	editor.mouse_filter = Control.MOUSE_FILTER_STOP
	editor.visible = false
	add_child(editor)
	var view := TextureRect.new()
	view.texture = preview.get_texture()
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	editor.add_child(view)
	edit_touch = TouchControls.new()
	edit_touch.preview = true
	editor.add_child(edit_touch)
	edit_touch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0, 0, 0, 0.6)
	bar_bg.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar_bg.offset_bottom = 120
	bar_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	editor.add_child(bar_bg)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 16
	col.offset_right = -16
	col.offset_top = 8
	col.add_theme_constant_override("separation", 4)
	bar_bg.add_child(col)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	col.add_child(bar)
	for m in [["On foot", false], ["Driving", true]]:
		var b: Button = phone._button(m[0], open_editor.bind(m[1]))
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(130, 56)
		_edit_modes[m[1]] = b
		bar.add_child(b)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(gap)
	for s in [["-", -0.1], ["+", 0.1]]:
		var b: Button = phone._button(s[0], _resize_picked.bind(s[1]))
		b.custom_minimum_size = Vector2(70, 56)
		b.add_theme_font_size_override("font_size", 28)
		bar.add_child(b)
	_edit_size = phone._text("", 20, Color(1.0, 0.85, 0.4))
	_edit_size.autowrap_mode = TextServer.AUTOWRAP_OFF
	_edit_size.custom_minimum_size = Vector2(150, 0)
	_edit_size.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(_edit_size)
	var reset: Button = phone._button("Reset", func():
		edit_touch.reset("drive." if _edit_driving else "foot.")
		edit_touch.selected = ""
		phone.game.apply_settings()
		_edit_refresh())
	reset.custom_minimum_size = Vector2(120, 56)
	bar.add_child(reset)
	var done: Button = phone._button("Done", close_editor)
	done.custom_minimum_size = Vector2(120, 56)
	bar.add_child(done)
	col.add_child(phone._text("Drag a control to move it. Tap one, then - / + to resize it. Reset puts this page back as it was.", 16, HINT))
	editor.gui_input.connect(_editor_input)


## Opens the editor on the on-foot or driving controls (the driving layout
## picked now).
func open_editor(driving: bool) -> void:
	_edit_driving = driving
	edit_touch.layout = phone.game.settings["touch_layout"]
	edit_touch.selected = ""
	edit_touch.show_mode(driving, Controls.scheme)
	editor.visible = true
	_edit_refresh()


## Saves the layout and goes back to the Controls tab.
func close_editor() -> void:
	if editor == null or not editor.visible:
		return
	editor.visible = false
	_edit_drag = false
	phone.game.apply_settings()
	if tab == "Controls":
		_show_overlay()


func _editor_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var b := edit_touch.item_at(event.position)
			edit_touch.selected = b.get("id", "")
			_edit_drag = not b.is_empty()
			if _edit_drag:
				_edit_grab = edit_touch._center(b) - event.position
		else:
			_edit_drag = false
		_edit_refresh()
	elif event is InputEventMouseMotion and _edit_drag:
		var b := edit_touch.find_item(edit_touch.selected)
		if not b.is_empty():
			edit_touch.place(b, event.position + _edit_grab)


func _resize_picked(step: float) -> void:
	var b := edit_touch.find_item(edit_touch.selected)
	if b.is_empty():
		return
	edit_touch.resize(b, step)
	_edit_refresh()


func _edit_refresh() -> void:
	for k in _edit_modes:
		_edit_modes[k].set_pressed_no_signal(k == _edit_driving)
	var b := edit_touch.find_item(edit_touch.selected)
	_edit_size.text = "Size %d%%" % edit_touch.size_percent(b) if not b.is_empty() else "Tap a control"
	edit_touch.queue_redraw()


func _game_tab() -> void:
	var game = phone.game
	var s: Dictionary = game.settings
	_row(_slider("Weather", "weather", ["auto", "clear", "rain", "storm"], func(): return s.get("weather", "auto"), func(v): return str(v).capitalize()),
		"Auto changes through the day; or hold it Clear, Rain or Storm.")
	var tb: Button = phone._button("Skip 3 hours (now %s)" % game.atmosphere.clock_text(), Callable())
	tb.pressed.connect(func():
		game.atmosphere.hour = fmod(game.atmosphere.hour + 3.0, 24.0)
		tb.text = "Skip 3 hours (now %s)" % game.atmosphere.clock_text())
	_row(tb, "Moves the clock on. The preview shows the new light and headlights.")
	_row(phone._toggle("Blood", s.get("blood", true), func(on): s["blood"] = on; game.apply_settings()),
		"Blood from fights and crashes: spatter, smears and pools on the ground. OFF shows none and clears what is there.")
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
	var say := func():
		if is_instance_valid(status): # the Save dialog can outlive the list
			status.text = lg.last_status
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


## A setting as a slider across the list that snaps to each of `values` (in
## order, a tick for each), with its name and the value now (`shown`) on the
## line above. `now` reads the current value. Moving it stores the value
## under `key` and applies it at once, so the preview follows the finger;
## `on_set` runs first with the value picked. `done` runs once the change is
## settled: at once for a tap, after the finger lets go for a drag.
func _slider(label: String, key: String, values: Array, now: Callable, shown: Callable, on_set := Callable(), done := Callable()) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	row.add_child(top)
	var name_l: Label = phone._text(label, 20, Color.WHITE)
	name_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_l)
	var value: Label = phone._text("", 20, Color(1.0, 0.85, 0.4))
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(value)
	var bar := HSlider.new()
	bar.min_value = 0
	bar.max_value = values.size() - 1
	bar.step = 1
	bar.rounded = true
	bar.tick_count = values.size()
	bar.ticks_on_borders = true
	bar.scrollable = false
	bar.focus_mode = Control.FOCUS_NONE
	# Drags reach the list too, so a swipe that starts on it still scrolls
	# (_drop_held then puts the setting back).
	bar.mouse_filter = Control.MOUSE_FILTER_PASS
	bar.custom_minimum_size = Vector2(0, 56)
	_style(bar)
	row.add_child(bar)
	var refresh := func():
		var v = now.call()
		bar.set_value_no_signal(maxi(values.find(v), 0))
		value.text = shown.call(v)
	bar.value_changed.connect(func(at: float):
		var v = values[clampi(roundi(at), 0, values.size() - 1)]
		phone.game.settings[key] = v
		if on_set.is_valid():
			on_set.call(v)
		phone.game.apply_settings()
		refresh.call()
		if done.is_valid():
			if _held == bar:
				row.set_meta("pending", true)
			else:
				done.call())
	# The press comes before the value jumps to the finger.
	bar.drag_started.connect(func():
		_held = bar
		_held_from = phone.game.settings.duplicate(true))
	bar.drag_ended.connect(func(_changed: bool):
		if _held == bar:
			_held = null
		if row.get_meta("pending", false):
			row.set_meta("pending", false)
			done.call())
	row.set_meta("refresh", refresh)
	row.set_meta("slider", bar)
	row.set_meta("value", value)
	row.set_meta("values", values)
	row.set_meta("key", key)
	refresh.call()
	sliders[label] = row
	return row


## A drag that began on a slider and turned into a scroll puts back the
## settings as they were before the finger went down, and lets go of the
## slider, so the rest of the swipe only scrolls.
func _drop_held() -> void:
	var bar := _held
	_held = null
	if bar == null or not is_instance_valid(bar):
		return
	phone.game.settings.merge(_held_from, true)
	phone.game.apply_settings()
	# Hiding a slider drops its grab and the press it was tracking.
	bar.visible = false
	bar.visible = true
	for row in sliders.values():
		row.set_meta("pending", false)
		row.get_meta("refresh").call()


## A thick track, the part up to the handle in the accent colour, and a
## round handle big enough to find under a thumb.
func _style(bar: HSlider) -> void:
	if _grab_tex == null:
		_grab_tex = _disc(40, Color.WHITE)
		_grab_hi_tex = _disc(40, Color(1.0, 0.85, 0.4))
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.16)
	track.set_corner_radius_all(6)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	bar.add_theme_stylebox_override("slider", track)
	var fill: StyleBoxFlat = track.duplicate()
	fill.bg_color = phone.ACCENT
	bar.add_theme_stylebox_override("grabber_area", fill)
	bar.add_theme_stylebox_override("grabber_area_highlight", fill)
	bar.add_theme_icon_override("grabber", _grab_tex)
	bar.add_theme_icon_override("grabber_highlight", _grab_hi_tex)


## A filled circle `d` pixels across with a soft edge.
static func _disc(d: int, fill: Color) -> ImageTexture:
	var img := Image.create_empty(d, d, false, Image.FORMAT_RGBA8)
	var r := d * 0.5
	for y in d:
		for x in d:
			var edge := clampf(r - 0.5 - Vector2(x + 0.5 - r, y + 0.5 - r).length(), 0.0, 1.0)
			img.set_pixel(x, y, Color(fill, fill.a * edge))
	return ImageTexture.create_from_image(img)
