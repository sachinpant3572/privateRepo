extends Node3D
## A car below Vehicle.FIRE_AT of its health burns from the engine: tongues of
## flame (a white-yellow core, an orange body, red tips) that grow from a small
## engine fire to the whole car, rising embers, thick smoke lit orange at its
## base, and a flickering light on the car and the road. The fire eats what
## is left of it in about BURN_TIME seconds, and then it explodes (Fx.explosion,
## wreck, blast, people near it knocked flat, cars near it shoved and dented).
## The wreck burns on for AFTER seconds and smokes a while longer. Made only
## while a car burns.

const GameLog = preload("res://scripts/game_log.gd")
const FireFx = preload("res://scripts/fire_fx.gd")
const Terrain = preload("res://scripts/terrain.gd")

const BURN_TIME := 7.0
## People within this (m) of the blast are hit; vehicles within BLAST + 1.
const BLAST := 6.0
## Flames keep going this long after the blast (dying down from half way).
const AFTER := 5.0
## Smoke goes on this much longer.
const SMOKE_AFTER := 3.5

var car
var exploded := false
var _core: CPUParticles3D
var _body: CPUParticles3D
var _wide: CPUParticles3D
var _embers: CPUParticles3D
var _smoke: CPUParticles3D
var _light: OmniLight3D
var _size := Vector3(1.8, 1.5, 4.4)
var _after := 0.0
var _time := 0.0
var _tick := 0.0
## 0 a small engine fire .. 1 the whole car alight.
var _k := 0.0
## How much of the fire is left (1 until the wreck's flames die down).
var _live := 1.0
var _night := 0.0
var _rng := RandomNumberGenerator.new()


static func ignite(vehicle) -> Node3D:
	var fire = load("res://scripts/car_fire.gd").new()
	fire.car = vehicle
	vehicle.add_child(fire)
	GameLog.event("car_fire", {"car": vehicle.kind, "hp": vehicle.health, "at": vehicle.global_position})
	return fire


func _ready() -> void:
	_rng.randomize()
	_size = car._size
	var c := FireFx.cfg()
	var flame := FireFx.flame()
	# Over the engine, at the front.
	position = Vector3(0.0, minf(_size.y * 0.7, 1.4), -_size.z * 0.3)
	var half := Vector3(_size.x * 0.3, 0.1, minf(_size.z * 0.15, 0.8))
	_core = _flames(c.core, 0.42, Vector2(0.55, 0.95), flame, half, [Color(1.0, 0.97, 0.7, 0.95), Color(1.0, 0.8, 0.3, 0.85), Color(1.0, 0.5, 0.1, 0.0)], 3)
	_body = _flames(c.body, 0.75, Vector2(1.0, 1.55), flame, half * 1.3, [Color(1.0, 0.72, 0.2, 0.85), Color(1.0, 0.4, 0.07, 0.8), Color(0.2, 0.03, 0.01, 0.0)], 2, [0.0, 0.4, 1.0])
	if c.wide > 0:
		# Late in the burn the cabin and the rest of the car burn too.
		_wide = _flames(c.wide, 0.7, Vector2(0.85, 1.3), flame, Vector3(_size.x * 0.42, 0.1, _size.z * 0.3), [Color(1.0, 0.65, 0.18, 0.8), Color(0.95, 0.32, 0.06, 0.75), Color(0.2, 0.03, 0.01, 0.0)], 2, [0.0, 0.45, 1.0])
		_wide.position = Vector3(0, -0.15, _size.z * 0.3)
		_wide.emitting = false
	if c.ember > 0:
		_embers = FireFx.emitter(c.ember, 1.7, FireFx.quad(Vector2(0.13, 0.13), FireFx.dot(), 1, true, 3))
		_embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		_embers.emission_box_extents = half * 1.5
		_embers.spread = 40.0
		_embers.initial_velocity_min = 1.5
		_embers.initial_velocity_max = 4.5
		_embers.gravity = Vector3(0, 0.9, 0)
		_embers.damping_min = 0.2
		_embers.damping_max = 0.6
		_embers.randomness = 0.6
		_embers.scale_amount_min = 0.5
		_embers.scale_amount_max = 1.5
		_embers.color_ramp = FireFx.ramp([0.0, 0.5, 1.0], [Color(1.0, 0.85, 0.4, 1.0), Color(1.0, 0.4, 0.06, 0.9), Color(0.4, 0.08, 0.0, 0.0)])
		_embers.emitting = false
		add_child(_embers)
	var smoke := FireFx.cloud()
	_smoke = FireFx.emitter(c.smoke, 2.7, FireFx.quad(Vector2(1.9, 1.9), smoke, 4, false, 0))
	FireFx.random_frame(_smoke)
	_smoke.position = Vector3(0, 0.6, 0)
	_smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_smoke.emission_box_extents = half
	_smoke.spread = 22.0
	_smoke.initial_velocity_min = 1.6
	_smoke.initial_velocity_max = 3.0
	_smoke.gravity = Vector3(0, 0.9, 0)
	_smoke.damping_min = 0.15
	_smoke.damping_max = 0.4
	_smoke.angle_min = -180.0
	_smoke.angle_max = 180.0
	_smoke.angular_velocity_min = -20.0
	_smoke.angular_velocity_max = 20.0
	_smoke.randomness = 0.4
	_smoke.scale_amount_curve = FireFx.curve([Vector2(0.0, 0.5), Vector2(0.3, 1.0), Vector2(1.0, 2.0)])
	# Lit orange by the fire at its base, then black, then grey and thin.
	_smoke.color_ramp = FireFx.ramp([0.0, 0.12, 0.32, 0.7, 1.0], [Color(0.5, 0.23, 0.07, 0.0), Color(0.36, 0.17, 0.06, 0.8), Color(0.08, 0.075, 0.07, 0.88), Color(0.12, 0.115, 0.11, 0.55), Color(0.18, 0.18, 0.18, 0.0)])
	add_child(_smoke)
	if FireFx.lights_used < c.lights:
		FireFx.lights_used += 1
		_light = OmniLight3D.new()
		_light.light_color = Color(1.0, 0.55, 0.22)
		_light.omni_attenuation = 1.4
		_light.light_specular = 0.3
		_light.shadow_enabled = false
		_light.position = Vector3(0, 0.9, _size.z * 0.15)
		add_child(_light)
	_update(true)


func _exit_tree() -> void:
	if _light != null:
		FireFx.lights_used = maxi(FireFx.lights_used - 1, 0)
		_light = null


## A flame layer: tongues rising from a box. `ramp_colors` runs from the
## base (bright) to the tip (dark red, clear).
func _flames(n: int, life: float, size: Vector2, tex: Texture2D, half: Vector3, ramp_colors: Array, prio: int, offsets := [0.0, 0.5, 1.0]) -> CPUParticles3D:
	var p := FireFx.emitter(n, life, FireFx.quad(size, tex, 4, true, prio, true))
	FireFx.random_frame(p)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = half
	p.spread = 9.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.4
	p.gravity = Vector3(0, 1.6, 0)
	p.randomness = 0.5
	p.angle_min = -14.0
	p.angle_max = 14.0
	p.angular_velocity_min = -30.0
	p.angular_velocity_max = 30.0
	p.hue_variation_min = -0.025
	p.hue_variation_max = 0.025
	# Swells, flickers, then thins to a point.
	p.scale_amount_curve = FireFx.curve([Vector2(0.0, 0.55), Vector2(0.2, 1.0), Vector2(0.55, 0.85), Vector2(1.0, 0.2)])
	p.color_ramp = FireFx.ramp(offsets, ramp_colors)
	add_child(p)
	return p


## Sizes, speeds and the light for how far the burn has got (`_k`) and how
## much of the fire is left (`_live`).
func _update(first := false) -> void:
	var k := _k
	var live := _live
	_night = FireFx.night()
	_core.scale_amount_min = (0.3 + 0.8 * k) * live
	_core.scale_amount_max = (0.5 + 1.0 * k) * live
	_core.initial_velocity_max = 2.2 + 1.2 * k
	_body.scale_amount_min = (0.35 + 1.1 * k) * live
	_body.scale_amount_max = (0.55 + 1.5 * k) * live
	_body.initial_velocity_min = 1.2 + 0.6 * k
	_body.initial_velocity_max = 2.4 + 2.0 * k
	if _wide != null:
		_wide.emitting = k > 0.35 and live > 0.35
		_wide.scale_amount_min = (0.6 + 0.6 * k) * live
		_wide.scale_amount_max = (0.9 + 0.8 * k) * live
		_wide.initial_velocity_max = 1.8 + 1.4 * k
	if _embers != null:
		_embers.emitting = k > 0.12 and live > 0.2
		_embers.initial_velocity_max = 3.5 + 3.5 * k
	_smoke.scale_amount_min = 0.8 + 0.9 * k
	_smoke.scale_amount_max = 1.1 + 1.4 * k
	_smoke.initial_velocity_min = 1.4 + 0.6 * k
	_smoke.initial_velocity_max = 2.6 + 1.6 * k
	_smoke.spread = 20.0 + 14.0 * k
	_smoke.emission_box_extents.x = _size.x * (0.3 + 0.2 * k)
	_smoke.emission_box_extents.z = minf(_size.z * 0.15, 0.8) * (1.0 + 1.2 * k)
	_smoke.color = FireFx.dim()
	if _light != null:
		_light.omni_range = 5.0 + 6.0 * k
		_light.visible = live > 0.02


func _physics_process(delta: float) -> void:
	if not is_instance_valid(car):
		queue_free()
		return
	_time += delta
	_tick += delta
	if _light != null and _light.visible:
		# A flickering fire: two beating sines and a little noise.
		var f := 0.78 + 0.16 * sin(_time * 31.0) * sin(_time * 12.0 + 1.0) + 0.1 * sin(_time * 53.0) + 0.06 * _rng.randf()
		_light.light_energy = (0.9 + 2.2 * _k) * _live * f * (0.4 + 0.6 * _night)
	if _tick > 0.1:
		_tick = 0.0
		if not exploded:
			_k = clampf(1.0 - car.health / (car.max_health * car.FIRE_AT), 0.0, 1.0)
		_update()
	if exploded:
		_after += delta
		_live = 1.0 - smoothstep(AFTER * 0.4, AFTER, _after)
		if _after > AFTER:
			_core.emitting = false
			_body.emitting = false
			if _wide != null:
				_wide.emitting = false
			if _embers != null:
				_embers.emitting = false
		if _after > AFTER + SMOKE_AFTER:
			_smoke.emitting = false
			if _light != null:
				_light.visible = false
		if _after > AFTER + SMOKE_AFTER + 3.2:
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
	_k = 1.0
	var at: Vector3 = car.global_position + Vector3.UP
	GameLog.event("car_explode", {"car": car.kind, "at": at})
	# A bigger vehicle makes a bigger ball of fire (the blast it deals does not change).
	var ground: float = car.global_position.y
	if car._cls["class"] == "heli":
		ground = Terrain.height(at.x, at.z)
	Fx.explosion(at, clampf(sqrt(_size.x * _size.z / 7.9), 0.85, 1.35), ground)
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
	_update()
