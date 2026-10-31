extends MultiMeshInstance3D
## Exhaust and tyre smoke: soft puffs that drift, grow and fade, all in one
## MultiMesh (one draw call). Each puff is a camera-facing quad written
## straight into the MultiMesh buffer; the oldest is dropped when the pool
## is full. Owned by Fx (Fx.puff).

const MAX := 260
## Puffs alive at once (Fx.set_quality lowers it on Low and Medium).
var cap := MAX
## Puffs this far (m) from the camera's focus are not made at all.
const RANGE := 70.0

static var _tex: GradientTexture2D

var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _age := PackedFloat32Array()
var _life := PackedFloat32Array()
var _size := PackedFloat32Array()
var _grow := PackedFloat32Array()
var _col := PackedColorArray()
var _buf := PackedFloat32Array()
var _game
## Night darkens the puffs (they are unshaded): 1 by day; not to black,
## as street and car lights catch the smoke.
var _light := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = soft()
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	mm.mesh = q
	mm.instance_count = MAX
	mm.visible_instance_count = 0
	multimesh = mm
	_buf.resize(MAX * 16)


func count() -> int:
	return _pos.size()


## The colours of the puffs alive now (tests).
func colors() -> PackedColorArray:
	return _col


func clear() -> void:
	for i in range(_pos.size() - 1, -1, -1):
		_drop(i)


## A puff at `pos` moving at `vel`, `size` m across, growing by `grow` m a
## second, gone after `life` s; `color`'s alpha is its starting opacity.
func add(pos: Vector3, vel: Vector3, size: float, grow: float, life: float, color: Color) -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null and cam.global_position.distance_to(pos) > RANGE + cam.global_position.y:
		return
	while _pos.size() >= cap and not _pos.is_empty():
		_drop(_oldest())
	_pos.append(pos)
	_vel.append(vel)
	_age.append(0.0)
	_life.append(life)
	_size.append(size)
	_grow.append(grow)
	_col.append(color)


func _oldest() -> int:
	var best := 0
	var most := -1.0
	for i in _age.size():
		var f := _age[i] / _life[i]
		if f > most:
			most = f
			best = i
	return best


func _drop(i: int) -> void:
	var last := _pos.size() - 1
	_pos[i] = _pos[last]
	_vel[i] = _vel[last]
	_age[i] = _age[last]
	_life[i] = _life[last]
	_size[i] = _size[last]
	_grow[i] = _grow[last]
	_col[i] = _col[last]
	_pos.resize(last)
	_vel.resize(last)
	_age.resize(last)
	_life.resize(last)
	_size.resize(last)
	_grow.resize(last)
	_col.resize(last)


func _process(delta: float) -> void:
	if _pos.is_empty():
		multimesh.visible_instance_count = 0
		return
	if _game == null or not is_instance_valid(_game):
		_game = get_tree().get_first_node_in_group("game")
	if _game != null and _game.get("atmosphere") != null:
		_light = lerpf(1.0, 0.5, _game.atmosphere.night_amount())
	var i := 0
	while i < _pos.size():
		_age[i] += delta
		if _age[i] >= _life[i]:
			_drop(i)
			continue
		# Rises a little, slows in the air.
		var v := _vel[i]
		v *= maxf(1.0 - 1.6 * delta, 0.0)
		v.y += 0.25 * delta
		_vel[i] = v
		_pos[i] += v * delta
		i += 1
	var cam := get_viewport().get_camera_3d()
	var basis := cam.global_basis if cam != null else Basis()
	var n := _pos.size()
	for k in n:
		var f := _age[k] / _life[k]
		var s := _size[k] + _grow[k] * _age[k]
		var b := basis.scaled(Vector3(s, s, s))
		var o := k * 16
		var p := _pos[k]
		_buf[o] = b.x.x; _buf[o + 1] = b.y.x; _buf[o + 2] = b.z.x; _buf[o + 3] = p.x
		_buf[o + 4] = b.x.y; _buf[o + 5] = b.y.y; _buf[o + 6] = b.z.y; _buf[o + 7] = p.y
		_buf[o + 8] = b.x.z; _buf[o + 9] = b.y.z; _buf[o + 10] = b.z.z; _buf[o + 11] = p.z
		var c := _col[k]
		# Fades in over the first tenth, out over the rest.
		var a := c.a * minf(f * 10.0, 1.0) * (1.0 - f) * (1.0 - f)
		_buf[o + 12] = c.r * _light; _buf[o + 13] = c.g * _light; _buf[o + 14] = c.b * _light; _buf[o + 15] = a
	multimesh.buffer = _buf
	multimesh.visible_instance_count = n


## A round puff, soft at the edge.
static func soft() -> GradientTexture2D:
	if _tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
		_tex = GradientTexture2D.new()
		_tex.gradient = g
		_tex.fill = GradientTexture2D.FILL_RADIAL
		_tex.fill_from = Vector2(0.5, 0.5)
		_tex.fill_to = Vector2(1.0, 0.5)
		_tex.width = 64
		_tex.height = 64
	return _tex
