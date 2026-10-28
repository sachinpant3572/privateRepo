extends Node3D
## A car below Vehicle.FIRE_AT of its health burns from the engine: flames
## and black smoke, the fire eats what is left of it in about BURN_TIME
## seconds, and then it explodes (wreck, blast, people near it knocked
## flat, cars near it shoved and dented). Made only while a car burns.

const GameLog = preload("res://scripts/game_log.gd")

const BURN_TIME := 7.0
## People within this (m) of the blast are hit; vehicles within BLAST + 1.
const BLAST := 6.0
## Flames keep going this long after the blast.
const AFTER := 5.0

var car
var exploded := false
var _flames: CPUParticles3D
var _smoke: CPUParticles3D
var _after := 0.0


static func ignite(vehicle) -> Node3D:
	var fire = load("res://scripts/car_fire.gd").new()
	fire.car = vehicle
	vehicle.add_child(fire)
	GameLog.event("car_fire", {"car": vehicle.kind, "hp": vehicle.health, "at": vehicle.global_position})
	return fire


func _ready() -> void:
	var size: Vector3 = car._size
	# Over the engine, at the front.
	position = Vector3(0.0, minf(size.y * 0.7, 1.4), -size.z * 0.3)
	_flames = CPUParticles3D.new()
	_flames.amount = 22
	_flames.lifetime = 0.55
	_flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_flames.emission_box_extents = Vector3(size.x * 0.3, 0.1, minf(size.z * 0.15, 0.8))
	_flames.direction = Vector3.UP
	_flames.spread = 15.0
	_flames.initial_velocity_min = 1.0
	_flames.initial_velocity_max = 2.4
	_flames.gravity = Vector3(0, 2.5, 0)
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.25))
	_flames.scale_amount_curve = shrink
	_flames.mesh = _quad(Vector2(0.6, 0.7), true)
	_flames.color_ramp = _ramp([Color(1.0, 0.95, 0.55, 1.0), Color(1.0, 0.5, 0.1, 0.9), Color(0.6, 0.1, 0.02, 0.0)])
	add_child(_flames)
	_smoke = CPUParticles3D.new()
	_smoke.amount = 10
	_smoke.lifetime = 1.6
	_smoke.position = Vector3(0, 0.6, 0)
	_smoke.direction = Vector3.UP
	_smoke.spread = 20.0
	_smoke.initial_velocity_min = 1.2
	_smoke.initial_velocity_max = 2.2
	_smoke.gravity = Vector3(0, 0.8, 0)
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.5))
	grow.add_point(Vector2(1.0, 2.0))
	_smoke.scale_amount_curve = grow
	_smoke.mesh = _quad(Vector2(1.0, 1.0), false)
	_smoke.color_ramp = _ramp([Color(0.08, 0.07, 0.07, 0.7), Color(0.15, 0.14, 0.14, 0.0)])
	add_child(_smoke)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(car):
		queue_free()
		return
	if exploded:
		_after += delta
		if _after > AFTER:
			_flames.emitting = false
			_smoke.emitting = false
		if _after > AFTER + 2.0:
			queue_free()
		return
	if car.wrecked:
		explode()
		return
	car._damage(car.max_health * car.FIRE_AT / BURN_TIME * delta, true)
	if car.wrecked:
		explode()


func explode() -> void:
	if exploded:
		return
	exploded = true
	var at: Vector3 = car.global_position + Vector3.UP
	GameLog.event("car_explode", {"car": car.kind, "at": at})
	Fx.crash(at, 30.0, false)
	Fx.smoke(at, 2.5)
	var player = get_tree().get_first_node_in_group("player")
	if player != null and player.global_position.distance_to(at) < 30.0:
		Fx.shake(clampf(1.2 - player.global_position.distance_to(at) / 30.0, 0.3, 1.0))
	for h in get_tree().get_nodes_in_group("humanoids"):
		if h.dead or (h.get("vehicle") != null):
			continue
		var away: Vector3 = h.global_position - car.global_position
		away.y = 0.0
		var d := away.length()
		if d >= BLAST:
			continue
		var push := away.normalized() * lerpf(8.0, 3.0, d / BLAST)
		h.take_hit(null, lerpf(70.0, 15.0, d / BLAST), Vector3.ZERO)
		if not h.dead:
			h.knock_down(2.5, push)
		h.velocity = push
	for v in get_tree().get_nodes_in_group("vehicles"):
		if v == car or not v.has_method("bump"):
			continue
		var away: Vector3 = v.global_position - car.global_position
		away.y = 0.0
		var d := away.length()
		if d >= BLAST + 1.0 or d < 0.01:
			continue
		var near: Vector3 = v.global_position - away.normalized() * minf(d, v._size.z * 0.5)
		v.bump(away.normalized() * lerpf(10.0, 3.0, d / (BLAST + 1.0)) / maxf(v.mass, 1.0), near + Vector3.UP * 0.6)
	_flames.amount = 30
	_flames.initial_velocity_max = 3.5


static func _quad(size: Vector2, glow: bool) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	if glow:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	q.material = mat
	return q


static func _ramp(colors: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0]) if colors.size() == 2 else PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray(colors)
	return g
