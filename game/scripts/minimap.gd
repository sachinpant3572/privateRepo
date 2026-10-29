extends Control
## Round minimap in the top-left corner, turned the way the camera is (so up
## on it is up the screen; the N on the rim shows north): the baked city map
## around the player, landmark icons, mission blips (pinned to the rim when
## off the map), police while wanted, and the GPS line to the active target.
## Zooms out with speed. Tap it to open the full map; tap the N to swing the
## view behind the car, or north up on foot (HANDOFF-heading-camera.md H-6).

const MapImage = preload("res://scripts/map_image.gd")

const SHADER := """
shader_type canvas_item;
uniform sampler2D map_tex : filter_linear;
uniform vec2 center_uv = vec2(0.5);
uniform vec2 extent_uv = vec2(0.1);
// The ground directions (x, z) of the minimap's right and up.
uniform vec2 axis_r = vec2(1.0, 0.0);
uniform vec2 axis_u = vec2(0.0, -1.0);
// The playable window inside the bake (xy min, zw max); past it, and where
// the bake is clear (past a trimmed city's edge), the state.
uniform vec4 city_uv_rect = vec4(0.0, 0.0, 1.0, 1.0);
// Past the city's bake: the whole state (state_map.gd).
uniform sampler2D state_tex : filter_linear;
uniform vec2 state_center_uv = vec2(0.5);
uniform vec2 state_extent_uv = vec2(0.01);

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	if (d > 1.0) {
		discard;
	}
	vec2 g = axis_r * p.x - axis_u * p.y;
	vec2 uv = center_uv + g * extent_uv;
	vec4 c = texture(map_tex, uv);
	if (any(lessThan(uv, city_uv_rect.xy)) || any(greaterThan(uv, city_uv_rect.zw)) || c.a < 0.5) {
		c = texture(state_tex, state_center_uv + g * state_extent_uv);
	}
	float rim = smoothstep(0.92, 0.95, d);
	COLOR = vec4(mix(c.rgb, vec3(0.06, 0.06, 0.08), rim), 0.93);
}
"""

signal opened
signal compass

var game
var map: Dictionary # from MapImage.bake
var state: Dictionary # from StateMap.bake
## Metres from the centre to the rim.
var view_radius := 95.0

var _map_rect: ColorRect
var _overlay: Control
var _mat: ShaderMaterial
var _route := PackedVector3Array()
var _route_target = null
var _route_time := 0.0
var _blink := 0.0
## The minimap's right and up as ground directions (x, z): the camera's.
var _axis_r := Vector2(1.0, 0.0)
var _axis_u := Vector2(0.0, -1.0)


func _ready() -> void:
	custom_minimum_size = Vector2(220, 220)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_mat = ShaderMaterial.new()
	_mat.shader = Shader.new()
	_mat.shader.code = SHADER
	_mat.set_shader_parameter("map_tex", map.texture)
	_mat.set_shader_parameter("state_tex", state.texture)
	var win: Rect2 = game.city.window
	var lo: Vector2 = (win.position - map.origin) / MapImage.PX_M / map.size
	var hi: Vector2 = (win.end - map.origin) / MapImage.PX_M / map.size
	if not game.city.plan.outline.is_empty():
		lo = Vector2.ZERO
		hi = Vector2.ONE
	_mat.set_shader_parameter("city_uv_rect", Vector4(lo.x, lo.y, hi.x, hi.y))
	_map_rect = ColorRect.new()
	_map_rect.material = _mat
	_map_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_map_rect)
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)


func _process(delta: float) -> void:
	_blink += delta
	var yaw: float = game.camera.yaw
	_axis_r = Vector2(cos(yaw), -sin(yaw))
	_axis_u = Vector2(-sin(yaw), -cos(yaw))
	_mat.set_shader_parameter("axis_r", _axis_r)
	_mat.set_shader_parameter("axis_u", _axis_u)
	var focus: Node3D = game.player.focus_node()
	var pos: Vector3 = focus.global_position
	var speed := 0.0
	if focus != game.player:
		speed = focus.velocity.length()
	var want := lerpf(95.0, 170.0, clampf(speed / 22.0, 0.0, 1.0))
	view_radius = lerpf(view_radius, want, 1.0 - exp(-2.0 * delta))
	var center_uv: Vector2 = (Vector2(pos.x, pos.z) - map.origin) / MapImage.PX_M / map.size
	_mat.set_shader_parameter("center_uv", center_uv)
	_mat.set_shader_parameter("extent_uv", Vector2.ONE * view_radius / MapImage.PX_M / map.size)
	_mat.set_shader_parameter("state_center_uv", (Vector2(pos.x, pos.z) - state.origin) / state.px_m / state.size)
	_mat.set_shader_parameter("state_extent_uv", Vector2.ONE * view_radius / state.px_m / state.size)
	_update_route(pos, delta)
	_overlay.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and event.pressed)
	if tapped:
		accept_event()
		if event.position.distance_to(north_mark()) < 26.0:
			compass.emit()
		else:
			opened.emit()


## Where the N sits on the rim, in the minimap's own coordinates.
func north_mark() -> Vector2:
	return size * 0.5 + turn(Vector2(0.0, -1.0)) * (size.x * 0.5 - 12.0)


## A ground direction (x, z) as a direction on the minimap.
func turn(d: Vector2) -> Vector2:
	return Vector2(d.dot(_axis_r), -d.dot(_axis_u))


## The active GPS target: the first marker that asks for one.
func gps_target():
	for m in game.map_markers():
		if m.get("gps", false):
			return m.pos
	return null


func route() -> PackedVector3Array:
	return _route


func _update_route(pos: Vector3, delta: float) -> void:
	var target = gps_target()
	_route_time -= delta
	if target == null:
		_route = PackedVector3Array()
		_route_target = null
		return
	if target != _route_target or _route_time <= 0.0:
		_route_target = target
		_route_time = 1.0
		_route = game.city.route(pos, target)


func _to_screen(p: Vector3, center: Vector3) -> Vector2:
	var r := size.x * 0.5
	return size * 0.5 + turn(Vector2(p.x - center.x, p.z - center.z)) / view_radius * r


func _draw_overlay() -> void:
	var focus: Node3D = game.player.focus_node()
	var center: Vector3 = focus.global_position
	var r := size.x * 0.5
	var mid := size * 0.5
	# GPS line, dense enough that clipping at the rim by points looks clean.
	if _route.size() > 1:
		var prev := _to_screen(_route[0], center)
		for k in range(1, _route.size()):
			var a := _route[k - 1]
			var b := _route[k]
			var steps := maxi(1, int(a.distance_to(b) / 4.0))
			for s in steps:
				var q := _to_screen(a.lerp(b, float(s + 1) / steps), center)
				if prev.distance_to(mid) < r * 0.9 and q.distance_to(mid) < r * 0.9:
					_overlay.draw_line(prev, q, Color(0.85, 0.4, 0.95), 4.0)
				prev = q
	for lm in game.city.landmarks():
		var at := _to_screen(lm.pos, center)
		if at.distance_to(mid) < r * 0.85:
			var ic: Array = MapImage.icon(lm.type)
			MapImage.draw_icon(_overlay, at, ic[0], ic[1], 7.0)
	for p in game.city.places:
		var at := _to_screen(p.door, center)
		if at.distance_to(mid) < r * 0.85:
			var ic: Array = MapImage.icon(p.type)
			MapImage.draw_icon(_overlay, at, ic[0], ic[1], 6.0)
	if Wanted.level > 0:
		var flash := int(_blink * 4.0) % 2 == 0
		for unit in game.police.cops + game.police.cars:
			if is_instance_valid(unit):
				var at := _to_screen(unit.global_position, center)
				if at.distance_to(mid) < r * 0.9:
					_overlay.draw_rect(Rect2(at - Vector2(3, 3), Vector2(6, 6)), Color(0.9, 0.15, 0.15) if flash else Color(0.2, 0.4, 1.0))
	for m in game.map_markers():
		var at := _to_screen(m.pos, center)
		var off := at - mid
		if off.length() > r * 0.82:
			# Off the map: an arrow on the rim pointing at it.
			var edge: Vector2 = mid + off.normalized() * r * 0.82
			MapImage.draw_arrow(_overlay, edge, off, 9.0, m.color)
		else:
			_draw_blip(at, m)
	# The player (or their car), pointing where they face.
	var fwd: Vector3 = -focus.global_basis.z
	MapImage.draw_arrow(_overlay, mid, turn(Vector2(fwd.x, fwd.z)), 10.0, Color(1.0, 0.85, 0.25))
	var font := ThemeDB.fallback_font
	var n := north_mark()
	_overlay.draw_circle(n, 10.0, Color(0.06, 0.06, 0.08))
	_overlay.draw_string(font, n + Vector2(-5, 6), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)


func _draw_blip(at: Vector2, m: Dictionary) -> void:
	var pulse := 1.0 + 0.25 * sin(_blink * 6.0)
	_overlay.draw_circle(at, 8.0 * pulse, Color(m.color, 0.35))
	_overlay.draw_circle(at, 6.0, Color(0.05, 0.05, 0.07))
	_overlay.draw_circle(at, 4.5, m.color)
