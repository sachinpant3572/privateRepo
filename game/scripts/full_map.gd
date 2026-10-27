extends Control
## Full-screen map, opened from the minimap (or M / the pad's Back button).
## Pauses the game. Drag to pan, pinch or scroll to zoom, tap a spot to set
## a waypoint (tap it again to clear). Close in: the playable city with
## districts, landmarks, mission markers, the GPS route and the player.
## Zoomed out: the whole state (state_map.gd) with its four cities, regions,
## towns, airports and bases; places not open yet say so when tapped.

const MapImage = preload("res://scripts/map_image.gd")
const StateMap = preload("res://scripts/state_map.gd")

var game
var map: Dictionary
var state: Dictionary # from StateMap.bake
## Map pixels per screen pixel is 1 / zoom.
var zoom := 1.0
var pan := Vector2.ZERO # map pixel at the screen centre

var _touches := {}
var _drag_dist := 0.0
var _pinch_start := 0.0
var _pinch_zoom := 1.0
var _close_rect := Rect2()
## A line shown under the title for a few seconds (taps on closed places).
var _note := ""
var _note_until := 0
## Below this zoom the map shows the state rather than the city.
const STATE_ZOOM := 0.3
const MAX_ZOOM := 4.0


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
			zoom = clampf(_pinch_zoom * _pinch_span() / maxf(_pinch_start, 1.0), _min_zoom(), MAX_ZOOM)
		else:
			pan -= (event.position - before) / zoom
			_drag_dist += (event.position - before).length()
		accept_event()
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = minf(zoom * 1.15, MAX_ZOOM)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = maxf(zoom / 1.15, _min_zoom())
		queue_redraw()


## Zoomed all the way out, the whole state fits the screen.
func _min_zoom() -> float:
	if state.is_empty():
		return 0.3
	var px: Vector2 = state.world_size / MapImage.PX_M
	return minf(size.x / px.x, (size.y - 56.0) / px.y) * 0.95


func _pinch_span() -> float:
	var pts: Array = _touches.values()
	return (pts[0] as Vector2).distance_to(pts[1])


func _tap(at: Vector2) -> void:
	if _close_rect.has_point(at):
		close()
		return
	var local := _to_world(at)
	if not game.city.window.grow(60.0).has_point(Vector2(local.x, local.z)):
		var place := _nearest_label(local)
		var open_city: Array = state.labels.cities.filter(func(c): return c.playable) if not state.is_empty() else []
		if not open_city.is_empty() and place == open_city[0].name:
			_note = "This part of %s is not open yet" % place
		else:
			_note = "%s: not open yet" % place
		_note_until = Time.get_ticks_msec() + 2500
		queue_redraw()
		return
	var wp = game.waypoint
	if wp != null and Vector2(wp.x, wp.z).distance_to(Vector2(local.x, local.z)) < 25.0:
		game.waypoint = null
	else:
		var n: int = game.city.nearest_node(local)
		if n >= 0:
			game.waypoint = game.city.node_pos(n)
	queue_redraw()


## The closest city, town or region name to `local`, for the tap note.
func _nearest_label(local: Vector3) -> String:
	if state.is_empty():
		return "There"
	var best := "There"
	var best_d := INF
	for kind in ["cities", "towns", "regions"]:
		for l in state.labels[kind]:
			# Cities and regions are big: favour them over a town nearby.
			var d: float = (l.pos as Vector3).distance_to(local) * (0.5 if kind == "cities" else 1.0)
			if d < best_d:
				best_d = d
				best = l.name
	return best


func _to_screen(p: Vector3) -> Vector2:
	var px: Vector2 = (Vector2(p.x, p.z) - map.origin) / MapImage.PX_M
	return size * 0.5 + (px - pan) * zoom


func _to_world(at: Vector2) -> Vector3:
	var px := pan + (at - size * 0.5) / zoom
	var m: Vector2 = map.origin + px * MapImage.PX_M
	return Vector3(m.x, 0.0, m.y)


func _draw() -> void:
	if not state.is_empty():
		# Keep some of the state on screen however far it is dragged.
		var lo: Vector2 = (state.origin - map.origin) / MapImage.PX_M
		pan = pan.clamp(lo, lo + state.world_size / MapImage.PX_M)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.27, 0.5, 0.62))
	if not state.is_empty():
		var so := _to_screen(Vector3(state.origin.x, 0, state.origin.y))
		draw_texture_rect(state.texture, Rect2(so, state.world_size / MapImage.PX_M * zoom), false)
	# Only the playable window of the city's bake: past it the state shows.
	var win_px := Rect2((game.city.window.position - map.origin) / MapImage.PX_M, game.city.window.size / MapImage.PX_M)
	if state.is_empty():
		win_px = Rect2(Vector2.ZERO, map.size)
	var tl := _to_screen(Vector3(map.origin.x, 0, map.origin.y)) + win_px.position * zoom
	draw_texture_rect_region(map.texture, Rect2(tl, win_px.size * zoom), win_px)
	var font := ThemeDB.fallback_font
	# Playable area outline.
	var city = game.city
	var win: Rect2 = city.window
	var ring := PackedVector2Array()
	for c in [win.position, Vector2(win.end.x, win.position.y), win.end, Vector2(win.position.x, win.end.y), win.position]:
		ring.append(_to_screen(Vector3(c.x, 0, c.y)))
	draw_polyline(ring, Color(1, 1, 1, 0.8), 3.0)
	var far := zoom < STATE_ZOOM
	if far:
		_draw_state_labels(font)
	# District names.
	for d in ([] if far else city.districts):
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
	for lm in ([] if far else city.landmarks()):
		var at := _to_screen(lm.pos)
		var ic: Array = MapImage.icon(lm.type)
		MapImage.draw_icon(self, at, ic[0], ic[1], 12.0)
		if zoom > 0.6:
			draw_string_outline(font, at + Vector2(16, 6), lm.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 5, Color.BLACK)
			draw_string(font, at + Vector2(16, 6), lm.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	# Shops and diners.
	for p in ([] if far else city.places):
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


## The state view: town dots, peaks and pins first, then the names, most
## important first; a name that would overlap one already placed is left out
## (zoom in to see it).
func _draw_state_labels(font: Font) -> void:
	var labels: Dictionary = state.labels
	var close := zoom > STATE_ZOOM * 0.45
	for t in labels.towns:
		var at := _to_screen(t.pos)
		draw_circle(at, 5.0, Color(0.05, 0.05, 0.07))
		draw_circle(at, 3.5, Color(0.6, 0.57, 0.52) if t.kind == "ghost" else Color.WHITE)
	for pk in labels.peaks:
		var at := _to_screen(pk.pos)
		var tri := PackedVector2Array([at + Vector2(-9, 6), at + Vector2(0, -9), at + Vector2(9, 6)])
		draw_colored_polygon(tri, Color(0.36, 0.29, 0.23))
		tri.append(tri[0])
		draw_polyline(tri, Color.WHITE, 1.5)
	for pin in labels.pins:
		if _pin_shown(pin.type, close):
			var ic: Array = state_pin(pin.type)
			MapImage.draw_icon(self, _to_screen(pin.pos), ic[0], ic[1], 12.0 if pin.large else 9.0)
	var placed: Array[Rect2] = []
	for c in labels.cities:
		var at := _to_screen(c.pos)
		_label(font, at, c.name.to_upper(), 26, Color.WHITE if c.playable else Color(1, 1, 1, 0.8), 0.7, placed)
		_label(font, at + Vector2(0, 22), c.note if c.playable else c.note + " · coming later", 13, Color(1, 0.9, 0.6), 0.7, placed)
	for l in labels.regions:
		_label(font, _to_screen(l.pos), l.name.to_upper(), 14, Color(1, 1, 1, 0.75), 0.45, placed)
	for l in labels.water:
		_label(font, _to_screen(l.pos), l.name, 15, Color(0.85, 0.93, 1.0), 0.5, placed)
	for t in labels.towns:
		var ghost: bool = t.kind == "ghost"
		_label(font, _to_screen(t.pos) + Vector2(0, -9), t.name + (" (ghost town)" if ghost else ""), 13,
			Color(0.6, 0.57, 0.52) if ghost else Color.WHITE, 0.6, placed)
	for pin in labels.pins:
		if (close or pin.large) and _pin_shown(pin.type, close):
			_label(font, _to_screen(pin.pos) + Vector2(0, 26), pin.name, 12, Color.WHITE, 0.6, placed)
	if close:
		for pk in labels.peaks:
			_label(font, _to_screen(pk.pos) + Vector2(0, 22), pk.name, 12, Color(1, 0.95, 0.85), 0.6, placed)


## Zoomed right out, only the pins that matter on a state scale.
static func _pin_shown(type: String, close: bool) -> bool:
	return close or type in ["airport", "military", "gas", "camp"]


static func state_pin(type: String) -> Array:
	return StateMap.PINS.get(type, ["o", Color(0.5, 0.5, 0.5)])


## Centred text with a dark edge. With `placed`, skipped if it would
## overlap a label already there, else added to it.
func _label(font: Font, at: Vector2, text: String, fs: int, color: Color, edge: float, placed = null) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x := at.x - w * 0.5
	if placed != null:
		var box := Rect2(x - 2, at.y - fs, w + 4, fs * 1.25)
		for other in placed:
			if other.intersects(box):
				return
		placed.append(box)
	draw_string_outline(font, Vector2(x, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, edge))
	draw_string(font, Vector2(x, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)


## Title, legend, hint and the close button.
func _draw_chrome(font: Font) -> void:
	draw_rect(Rect2(0, 0, size.x, 56), Color(0.05, 0.06, 0.08, 0.85))
	var far := zoom < STATE_ZOOM
	draw_string(font, Vector2(24, 38), "SOLVERA" if far else "BELLERIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
	var hint := "Drag to move  ·  Pinch or scroll to zoom  ·  Tap to set a waypoint"
	if Time.get_ticks_msec() < _note_until:
		hint = _note
	elif far:
		hint = "The state of Solvera  ·  Bellerive is open now; the other cities come later  ·  Zoom in for the city"
	draw_string(font, Vector2(200, 36), hint, HORIZONTAL_ALIGNMENT_LEFT, size.x - 290, 16, Color(1, 0.9, 0.6) if hint == _note else Color(1, 1, 1, 0.7))
	_close_rect = Rect2(size.x - 64, 4, 56, 48)
	draw_rect(_close_rect, Color(0.8, 0.2, 0.2, 0.9))
	draw_string(font, _close_rect.position + Vector2(18, 35), "X", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
	var legend := [["You", Color(1.0, 0.85, 0.25)], ["Mission", Color(1.0, 0.75, 0.2)], ["Waypoint / GPS", Color(0.85, 0.4, 0.95)]]
	if far:
		# A third entry says how to draw the swatch: a dashed or dotted line.
		legend = [["You", Color(1.0, 0.85, 0.25)], ["AP  Airport", state_pin("airport")[1]], ["X  Military base", state_pin("military")[1]],
			["T  Station", state_pin("station")[1]], ["G  Gas    C  Campsite", state_pin("gas")[1]],
			["Dirt track", StateMap.TRACK, 12.0], ["Trail / 4x4", StateMap.TRAIL, 4.0]]
	var y := size.y - 24.0 - legend.size() * 26.0
	draw_rect(Rect2(12, y - 12, 250, legend.size() * 26.0 + 20), Color(0.05, 0.06, 0.08, 0.8))
	for item in legend:
		if item.size() > 2:
			var x := 20.0
			while x < 40.0:
				draw_line(Vector2(x, y + 8), Vector2(minf(x + item[2], 40.0), y + 8), item[1].lightened(0.25), 4.0)
				x += item[2] + 4.0
		else:
			draw_circle(Vector2(30, y + 8), 8.0, item[1])
		draw_string(font, Vector2(46, y + 14), item[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)
		y += 26.0
