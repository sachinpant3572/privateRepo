extends Control
## Full-screen map of the demo area, opened from the minimap (or M / the
## pad's Back button). Pauses the game. Drag to pan, pinch or scroll to zoom,
## tap a spot to set a waypoint (tap it again to clear). Shows districts,
## landmarks with names, mission markers, the GPS route and the player.

const MapImage = preload("res://scripts/map_image.gd")

var game
var map: Dictionary
## Map pixels per screen pixel is 1 / zoom.
var zoom := 1.0
var pan := Vector2.ZERO # map pixel at the screen centre

var _touches := {}
var _drag_dist := 0.0
var _pinch_start := 0.0
var _pinch_zoom := 1.0
var _close_rect := Rect2()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func open() -> void:
	var p: Vector3 = game.player.focus_node().global_position
	if game.interiors != null and not game.interiors.place.is_empty():
		p = game.interiors.place.door
	pan = (Vector2(p.x, p.z) - map.origin) / MapImage.PX_M
	zoom = clampf(size.y / map.size.y * 1.6, 0.3, 4.0)
	_touches.clear()
	visible = true
	get_tree().paused = true
	queue_redraw()


func close() -> void:
	visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M:
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif visible and event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
	elif visible and event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_BACK:
		close()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			_drag_dist = 0.0
			if _touches.size() == 2:
				_pinch_start = _pinch_span()
				_pinch_zoom = zoom
		else:
			_touches.erase(event.index)
			if _touches.is_empty() and _drag_dist < 12.0:
				_tap(event.position)
		accept_event()
	elif event is InputEventScreenDrag:
		var before: Vector2 = _touches.get(event.index, event.position)
		_touches[event.index] = event.position
		if _touches.size() >= 2:
			zoom = clampf(_pinch_zoom * _pinch_span() / maxf(_pinch_start, 1.0), 0.3, 4.0)
		else:
			pan -= (event.position - before) / zoom
			_drag_dist += (event.position - before).length()
		accept_event()
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = minf(zoom * 1.15, 4.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = maxf(zoom / 1.15, 0.3)
		queue_redraw()


func _pinch_span() -> float:
	var pts: Array = _touches.values()
	return (pts[0] as Vector2).distance_to(pts[1])


func _tap(at: Vector2) -> void:
	if _close_rect.has_point(at):
		close()
		return
	var local := _to_world(at)
	var wp = game.waypoint
	if wp != null and Vector2(wp.x, wp.z).distance_to(Vector2(local.x, local.z)) < 25.0:
		game.waypoint = null
	else:
		var n: int = game.city.nearest_node(local)
		if n >= 0:
			game.waypoint = game.city.node_pos(n)
	queue_redraw()


func _to_screen(p: Vector3) -> Vector2:
	var px: Vector2 = (Vector2(p.x, p.z) - map.origin) / MapImage.PX_M
	return size * 0.5 + (px - pan) * zoom


func _to_world(at: Vector2) -> Vector3:
	var px := pan + (at - size * 0.5) / zoom
	var m: Vector2 = map.origin + px * MapImage.PX_M
	return Vector3(m.x, 0.0, m.y)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.27, 0.5, 0.62))
	var tl := _to_screen(Vector3(map.origin.x, 0, map.origin.y))
	draw_texture_rect(map.texture, Rect2(tl, map.size * MapImage.PX_M * zoom / MapImage.PX_M), false)
	var font := ThemeDB.fallback_font
	# Playable area outline.
	var city = game.city
	var win: Rect2 = city.window
	var ring := PackedVector2Array()
	for c in [win.position, Vector2(win.end.x, win.position.y), win.end, Vector2(win.position.x, win.end.y), win.position]:
		ring.append(_to_screen(Vector3(c.x, 0, c.y)))
	draw_polyline(ring, Color(1, 1, 1, 0.8), 3.0)
	# District names.
	for d in city.districts:
		var r: Rect2 = d.rect
		var c: Vector2 = r.get_center() - city.map_origin
		var at := _to_screen(Vector3(c.x, 0, c.y))
		if Rect2(Vector2.ZERO, size).has_point(at):
			var fs := int(clampf(22.0 * zoom, 14.0, 34.0))
			var w := font.get_string_size(d.name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string_outline(font, at - Vector2(w * 0.5, 0), d.name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, 0.6))
			draw_string(font, at - Vector2(w * 0.5, 0), d.name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.85))
	# GPS route.
	var route: PackedVector3Array = game.hud.minimap.route()
	for k in range(1, route.size()):
		draw_line(_to_screen(route[k - 1]), _to_screen(route[k]), Color(0.85, 0.4, 0.95), 5.0)
	# Landmarks.
	for lm in city.landmarks():
		var at := _to_screen(lm.pos)
		var ic: Array = MapImage.icon(lm.type)
		MapImage.draw_icon(self, at, ic[0], ic[1], 12.0)
		if zoom > 0.6:
			draw_string_outline(font, at + Vector2(16, 6), lm.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 5, Color.BLACK)
			draw_string(font, at + Vector2(16, 6), lm.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	# Shops and diners.
	for p in city.places:
		var at := _to_screen(p.door)
		var ic: Array = MapImage.icon(p.type)
		MapImage.draw_icon(self, at, ic[0], ic[1], 9.0)
		if zoom > 1.2:
			draw_string_outline(font, at + Vector2(13, 5), p.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 5, Color.BLACK)
			draw_string(font, at + Vector2(13, 5), p.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.9, 0.9))
	# Markers and the player.
	for m in game.map_markers():
		var at := _to_screen(m.pos)
		draw_circle(at, 13.0, Color(0.05, 0.05, 0.07))
		draw_circle(at, 10.0, m.color)
		draw_string_outline(font, at + Vector2(16, -10), m.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 6, Color.BLACK)
		draw_string(font, at + Vector2(16, -10), m.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, m.color.lightened(0.3))
	var focus: Node3D = game.player.focus_node()
	var fwd: Vector3 = -focus.global_basis.z
	MapImage.draw_arrow(self, _to_screen(focus.global_position), Vector2(fwd.x, fwd.z), 14.0, Color(1.0, 0.85, 0.25))
	_draw_chrome(font)


## Title, legend, hint and the close button.
func _draw_chrome(font: Font) -> void:
	draw_rect(Rect2(0, 0, size.x, 56), Color(0.05, 0.06, 0.08, 0.85))
	draw_string(font, Vector2(24, 38), "BELLERIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
	draw_string(font, Vector2(200, 36), "Drag to move  ·  Pinch or scroll to zoom  ·  Tap to set a waypoint", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.7))
	_close_rect = Rect2(size.x - 64, 4, 56, 48)
	draw_rect(_close_rect, Color(0.8, 0.2, 0.2, 0.9))
	draw_string(font, _close_rect.position + Vector2(18, 35), "X", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
	var legend := [["You", Color(1.0, 0.85, 0.25)], ["Mission", Color(1.0, 0.75, 0.2)], ["Waypoint / GPS", Color(0.85, 0.4, 0.95)]]
	var y := size.y - 24.0 - legend.size() * 26.0
	draw_rect(Rect2(12, y - 12, 220, legend.size() * 26.0 + 20), Color(0.05, 0.06, 0.08, 0.8))
	for item in legend:
		draw_circle(Vector2(30, y + 8), 8.0, item[1])
		draw_string(font, Vector2(46, y + 14), item[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)
		y += 26.0
