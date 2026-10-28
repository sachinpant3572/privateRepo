extends Node3D
## Game feel, shared by everything (autoload "Fx"): hit-stop and screen shake
## on punches and crashes, spark and debris bursts, tyre smoke, splashes and
## skid marks. Bursts come from small pools of one-shot particle emitters;
## skid marks are one MultiMesh ring buffer, so all of it costs a handful of
## draw calls.

const SKID_COUNT := 400

## Off in headless runs (tests), where slowing time would only slow tests.
var enabled := true
var camera: Node

var _pools := {}
var _skids: MultiMeshInstance3D
var _skid_next := 0
var _skid_total := 0
var _stop_until := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = DisplayServer.get_name() != "headless"
	_pools["spark"] = _pool(6, _spark_emitter)
	_pools["smoke"] = _pool(10, _smoke_emitter)
	_pools["splash"] = _pool(6, _splash_emitter)
	_pools["debris"] = _pool(4, _debris_emitter)
	_pools["leaves"] = _pool(3, _leaf_emitter)
	_pools["gush"] = _pool(3, _gush_emitter)
	_skids = _make_skids()
	add_child(_skids)


func _process(_delta: float) -> void:
	if _stop_until > 0 and Time.get_ticks_msec() >= _stop_until:
		_stop_until = 0
		Engine.time_scale = 1.0


## A punch or kick landed. Only fights involving the player freeze time.
func hit(pos: Vector3, strong: bool, involves_player: bool) -> void:
	_burst("spark", pos + Vector3(0, 1.2, 0), 1.6 if strong else 1.0)
	if involves_player:
		hit_stop(0.09 if strong else 0.05)
		shake(0.35 if strong else 0.15)


## A vehicle hit something at `impact` m/s.
func crash(pos: Vector3, impact: float, involves_player: bool) -> void:
	var strength := clampf(impact / 20.0, 0.2, 1.0)
	_burst("spark", pos + Vector3(0, 0.6, 0), 1.0 + strength)
	if impact > 9.0:
		_burst("debris", pos + Vector3(0, 0.6, 0), 1.0)
	if involves_player:
		shake(0.2 + 0.6 * strength)
		if impact > 14.0:
			hit_stop(0.06)


## A car knocked a roadside prop of `kind` down at `pos` (Breakables):
## debris, leaves off a tree, sparks off a lamp, a hydrant's gusher.
func knock(pos: Vector3, kind: String, involves_player: bool) -> void:
	_burst("debris", pos, 0.8)
	match kind:
		"street_tree", "crepe_myrtle":
			_burst("leaves", pos + Vector3(0, 1.5, 0), 1.0)
		"street_light", "gas_lamp", "traffic_light", "ev_charger":
			_burst("spark", pos + Vector3(0, 0.8, 0), 1.4)
		"hydrant":
			var p: CPUParticles3D = _pools["gush"].pop_front()
			_pools["gush"].push_back(p)
			p.global_position = pos
			p.one_shot = false
			p.emitting = true
			get_tree().create_timer(6.0, false).timeout.connect(func(): p.emitting = false)
	if involves_player:
		shake(0.12)


func smoke(pos: Vector3, scale := 1.0) -> void:
	_burst("smoke", pos, scale)


func splash(pos: Vector3) -> void:
	_burst("splash", pos, 1.0)


## A tyre mark at `pos` (on the ground), stretched along `dir`.
func skid(pos: Vector3, dir: Vector3) -> void:
	var basis := Basis.looking_at(Vector3(dir.x, 0.0, dir.z).normalized(), Vector3.UP) if Vector2(dir.x, dir.z).length() > 0.01 else Basis()
	_skids.multimesh.set_instance_transform(_skid_next, Transform3D(basis, Vector3(pos.x, 0.03, pos.z)))
	_skid_next = (_skid_next + 1) % SKID_COUNT
	_skid_total += 1
	_skids.multimesh.visible_instance_count = mini(_skid_total, SKID_COUNT)


func shake(amount: float) -> void:
	if enabled and is_instance_valid(camera) and camera.has_method("shake"):
		camera.shake(amount)


## Freezes the action for a moment so a hit lands (classic hit-stop).
func hit_stop(seconds: float) -> void:
	if not enabled:
		return
	Engine.time_scale = 0.05
	_stop_until = Time.get_ticks_msec() + int(seconds * 1000.0)


func _burst(kind: String, pos: Vector3, scale: float) -> void:
	var pool: Array = _pools[kind]
	var p: CPUParticles3D = pool.pop_front()
	pool.push_back(p)
	p.global_position = pos
	p.scale_amount_min = 0.7 * scale
	p.scale_amount_max = 1.2 * scale
	p.restart()


func _pool(n: int, make: Callable) -> Array:
	var list: Array = []
	for i in n:
		var p: CPUParticles3D = make.call()
		p.one_shot = true
		p.emitting = false
		p.local_coords = false
		add_child(p)
		list.append(p)
	return list


static func _unshaded(color: Color, size: Vector2, flat := false) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = size
	if flat:
		q.orientation = PlaneMesh.FACE_Y
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED if not flat else BaseMaterial3D.BILLBOARD_DISABLED
	m.billboard_keep_scale = true
	q.material = m
	return q


static func _fade(a: Color, b: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, a)
	g.set_color(1, b)
	return g


func _spark_emitter() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 14
	p.lifetime = 0.28
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 9.0
	p.gravity = Vector3(0, -12, 0)
	p.mesh = _unshaded(Color.WHITE, Vector2(0.18, 0.18))
	p.color_ramp = _fade(Color(1.0, 0.95, 0.6), Color(1.0, 0.5, 0.1, 0.0))
	return p


func _smoke_emitter() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 6
	p.lifetime = 0.9
	p.explosiveness = 0.9
	p.direction = Vector3.UP
	p.spread = 40.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.6
	p.gravity = Vector3(0, 0.6, 0)
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.4))
	curve.add_point(Vector2(1.0, 1.6))
	p.scale_amount_curve = curve
	p.mesh = _unshaded(Color.WHITE, Vector2(1.0, 1.0))
	p.color_ramp = _fade(Color(0.85, 0.85, 0.85, 0.55), Color(0.85, 0.85, 0.85, 0.0))
	return p


func _splash_emitter() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 10
	p.lifetime = 0.4
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 35.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0, -14, 0)
	p.mesh = _unshaded(Color.WHITE, Vector2(0.14, 0.14))
	p.color_ramp = _fade(Color(0.8, 0.88, 1.0, 0.8), Color(0.8, 0.88, 1.0, 0.0))
	return p


func _debris_emitter() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 10
	p.lifetime = 0.8
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, -18, 0)
	p.angular_velocity_min = -400.0
	p.angular_velocity_max = 400.0
	p.mesh = _unshaded(Color.WHITE, Vector2(0.25, 0.15))
	p.color_ramp = _fade(Color(0.25, 0.25, 0.28), Color(0.15, 0.15, 0.17, 0.0))
	return p


func _leaf_emitter() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 16
	p.lifetime = 1.4
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0, -3.0, 0)
	p.damping_min = 1.5
	p.damping_max = 3.0
	p.angular_velocity_min = -300.0
	p.angular_velocity_max = 300.0
	p.mesh = _unshaded(Color.WHITE, Vector2(0.22, 0.16))
	p.color_ramp = _fade(Color(0.32, 0.48, 0.2), Color(0.38, 0.5, 0.22, 0.0))
	return p


## A burst hydrant's column of water (runs until Fx.knock stops it).
func _gush_emitter() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 70
	p.lifetime = 1.3
	p.direction = Vector3.UP
	p.spread = 16.0
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 11.0
	p.gravity = Vector3(0, -14, 0)
	p.mesh = _unshaded(Color.WHITE, Vector2(0.4, 0.4))
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.2
	p.color_ramp = _fade(Color(0.85, 0.92, 1.0, 0.85), Color(0.85, 0.92, 1.0, 0.0))
	return p


func _make_skids() -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var q := QuadMesh.new()
	q.size = Vector2(0.3, 0.75)
	q.orientation = PlaneMesh.FACE_Y
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.05, 0.05, 0.06, 0.5)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material = m
	mm.mesh = q
	mm.instance_count = SKID_COUNT
	mm.visible_instance_count = 0
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return inst
