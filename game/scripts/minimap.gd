extends Control
## Round minimap in the top-left corner, north up like the camera: the baked
## city map around the player, landmark icons, mission blips (pinned to the
## rim when off the map), police while wanted, and the GPS line to the active
## target. Zooms out with speed. Tap it to open the full map.

const MapImage = preload("res://scripts/map_image.gd")

const SHADER := """
shader_type canvas_item;
uniform sampler2D map_tex : filter_linear;
uniform vec2 center_uv = vec2(0.5);
uniform vec2 extent_uv = vec2(0.1);

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	if (d > 1.0) {
		discard;
	}
	vec2 uv = center_uv + p * extent_uv;
	vec4 c = texture(map_tex, uv);
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		c = vec4(0.27, 0.5, 0.62, 1.0);
	}
	float rim = smoothstep(0.92, 0.95, d);
	COLOR = vec4(mix(c.rgb, vec3(0.06, 0.06, 0.08), rim), 0.93);
}
"""

signal opened

var game
var map: Dictionary # from MapImage.bake
## Metres from the centre to the rim.
var view_radius := 95.0

var _map_rect: ColorRect
var _overlay: Control
var _mat: ShaderMaterial
var _route := PackedVector3Array()
var _route_target = null
var _route_time := 0.0
var _blink := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(220, 220)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_mat = ShaderMaterial.new()
	_mat.shader = Shader.new()
	_mat.shader.code = SHADER
	_mat.set_shader_parameter("map_tex", map.texture)
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
	_update_route(pos, delta)
	_overlay.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and event.pressed)
	if tapped:
		accept_event()
		opened.emit()


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
	return size * 0.5 + Vector2(p.x - center.x, p.z - center.z) / view_radius * r


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
	MapImage.draw_arrow(_overlay, mid, Vector2(fwd.x, fwd.z), 10.0, Color(1.0, 0.85, 0.25))
	var font := ThemeDB.fallback_font
	_overlay.draw_circle(Vector2(mid.x, 12), 10.0, Color(0.06, 0.06, 0.08))
	_overlay.draw_string(font, Vector2(mid.x - 5, 18), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)


func _draw_blip(at: Vector2, m: Dictionary) -> void:
	var pulse := 1.0 + 0.25 * sin(_blink * 6.0)
	_overlay.draw_circle(at, 8.0 * pulse, Color(m.color, 0.35))
	_overlay.draw_circle(at, 6.0, Color(0.05, 0.05, 0.07))
	_overlay.draw_circle(at, 4.5, m.color)
