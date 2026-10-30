extends Node3D
## Explosions (the Fx autoload's child, `Fx.boom`; call `Fx.explosion`):
## a flash (a white-hot sprite and one short OmniLight), a fireball of
## additive flame puffs that swells in about 0.4 s and goes dark, a rolling
## column of smoke with a cap that lingers for seconds, a dust ring racing
## across the ground, a shockwave ring, dark chunks, burning bits and sparks
## thrown out, and a scorch mark left under the wreck.
##
## Pooled: BLASTS sets of emitters are made once (on the first blast, and
## again if the graphics quality changes) and reused; a blast that has run its
## course switches everything off (emitters idle, light hidden, its _process
## stopped). Scorch marks are SCORCHES flat quads that fade out and hide
## after SCORCH_LIFE. The cost is a few draw calls and, on Medium and High,
## one OmniLight for 0.45 s (none on Low, see fire_fx.gd).

const FireFx = preload("res://scripts/fire_fx.gd")
const Terrain = preload("res://scripts/terrain.gd")

## Blasts that can run at once (a fourth restarts the one nearest its end).
const BLASTS := 3
## Burn marks kept at once, and how long one lasts (s).
const SCORCHES := 4
const SCORCH_LIFE := 50.0
## Share of its life a scorch mark is solid for.
const SCORCH_HOLD := 0.55
## Seconds a blast keeps its pieces going.
const BLAST_LIFE := 8.0
## Above the ground (m), over the skid marks (0.03) and blood (0.035).
const LIFT := 0.045

var _blasts: Array = []
var _built := ""
var _scorch: Array[MeshInstance3D] = []
var _scorch_start: Array[float] = []
var _scorch_next := 0
var _clock := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_rng.randomize()
	set_process(false)


## An explosion of size `s` (1 about a car) at `pos`. `ground`: the surface
## height under it, for the shockwave, dust and scorch (none of them if
## `pos` is high above it, a helicopter in the air).
func blast(pos: Vector3, s: float, ground: float) -> void:
	warm()
	var b = _blasts[0]
	for c in _blasts:
		if not c.active:
			b = c
			break
		if c.t > b.t:
			b = c
	b.go(pos, s, ground)
	if pos.y - ground < 5.0 * s:
		_scorch_at(Vector3(pos.x, ground, pos.z), s)


## Builds the pool for the current quality and real-lights setting if it is
## not built yet (Fx.set_quality calls it, so the first blast does not).
func warm() -> void:
	if _built != _key():
		_rebuild()


func _key() -> String:
	return "%s %s" % [FireFx.level, FireFx.real_lights]


func _rebuild() -> void:
	for b in _blasts:
		b.queue_free()
	_blasts.clear()
	_built = _key()
	for i in BLASTS:
		var b := Blast.new()
		b.name = "Blast%d" % i
		add_child(b)
		b.build(FireFx.cfg())
		_blasts.append(b)


## Ends every blast and scorch mark at once (a new game, tests).
func clear() -> void:
	for b in _blasts:
		b.stop()
	for m in _scorch:
		m.visible = false
	set_process(false)


## Blasts still going (tests).
func running() -> int:
	var n := 0
	for b in _blasts:
		if b.active:
			n += 1
	return n


## Pieces still switched on across all blasts: emitters emitting, lights and
## sprites shown (tests).
func pieces_on() -> int:
	var n := 0
	for b in _blasts:
		n += b.pieces_on()
	return n


## Scorch marks showing now (tests).
func scorches() -> int:
	var n := 0
	for m in _scorch:
		if m.visible:
			n += 1
	return n


## The most solid scorch mark showing (0 none), tests.
func scorch_alpha() -> float:
	var a := 0.0
	for m in _scorch:
		if m.visible:
			a = maxf(a, m.material_override.albedo_color.a)
	return a


## The blasts of the current pool (tests).
func blasts() -> Array:
	return _blasts


func _scorch_at(at: Vector3, s: float) -> void:
	if _scorch.is_empty():
		var q := QuadMesh.new()
		q.size = Vector2.ONE
		q.orientation = PlaneMesh.FACE_Y
		for i in SCORCHES:
			var m := MeshInstance3D.new()
			m.mesh = q
			m.top_level = true
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.albedo_texture = FireFx.scorch()
			mat.albedo_color = Color(0.02, 0.018, 0.016, 0.0)
			mat.render_priority = 1
			m.material_override = mat
			m.visible = false
			add_child(m)
			_scorch.append(m)
			_scorch_start.append(0.0)
	var i := _scorch_next
	_scorch_next = (_scorch_next + 1) % SCORCHES
	var size := 6.5 * s * _rng.randf_range(0.9, 1.15)
	var up := Terrain.normal(at.x, at.z)
	var b := Basis(Quaternion(Vector3.UP, up)) * Basis(Vector3.UP, _rng.randf() * TAU) * Basis.from_scale(Vector3(size, 1.0, size * _rng.randf_range(0.85, 1.0)))
	_scorch[i].global_transform = Transform3D(b, Vector3(at.x, at.y + LIFT, at.z))
	_scorch[i].visible = true
	_scorch_start[i] = _clock
	set_process(true)


func _process(delta: float) -> void:
	_clock += delta
	var live := false
	for i in _scorch.size():
		var m := _scorch[i]
		if not m.visible:
			continue
		var age := _clock - _scorch_start[i]
		if age >= SCORCH_LIFE:
			m.visible = false
			continue
		live = true
		var a := smoothstep(0.0, 0.6, age) * (1.0 - smoothstep(SCORCH_HOLD * SCORCH_LIFE, SCORCH_LIFE, age))
		var mat: StandardMaterial3D = m.material_override
		mat.albedo_color.a = 0.82 * a
	if not live:
		set_process(false)


## One set of pieces for one explosion.
class Blast extends Node3D:
	var active := false
	var t := 0.0
	var s := 1.0
	var ground_y := 0.0
	var on_ground := false
	var peak := 9.0
	var cfg: Dictionary
	var ball: CPUParticles3D
	var ball2: CPUParticles3D
	var column: CPUParticles3D
	var cap: CPUParticles3D
	var dust: CPUParticles3D
	var chunks: CPUParticles3D
	var bits: CPUParticles3D
	var sparks: CPUParticles3D
	var light: OmniLight3D
	var flash: MeshInstance3D
	var flash_mat: StandardMaterial3D
	var ring: MeshInstance3D
	var ring_mat: StandardMaterial3D
	var tilt := Basis.IDENTITY
	var _ball2_due := false
	var _cap_due := false

	func build(c: Dictionary) -> void:
		cfg = c
		var smoke := FireFx.cloud()
		var hard := FireFx.cloud(true)
		var dot := FireFx.dot()
		# The fireball: additive puffs flung out and slowing, rising, then
		# fading to a dark red.
		ball = _fireball(c.ball, 0.8, hard)
		ball2 = _fireball(c.ball2, 0.6, hard) if c.ball2 > 0 else null
		# The column of smoke: lit orange at first, then dark, then grey.
		column = FireFx.emitter(c.column, 4.6, FireFx.quad(Vector2(3.4, 3.4), smoke, 4, false, 0))
		FireFx.random_frame(column)
		column.explosiveness = 0.3
		column.randomness = 0.4
		column.spread = 16.0
		column.damping_min = 0.8
		column.damping_max = 1.4
		column.gravity = Vector3(0, 0.7, 0)
		column.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		column.angle_min = -180.0
		column.angle_max = 180.0
		column.angular_velocity_min = -25.0
		column.angular_velocity_max = 25.0
		column.scale_amount_curve = FireFx.curve([Vector2(0.0, 0.5), Vector2(0.25, 1.1), Vector2(1.0, 1.6)])
		column.color_ramp = FireFx.ramp([0.0, 0.1, 0.3, 0.7, 1.0], [Color(0.55, 0.26, 0.08, 0.0), Color(0.4, 0.19, 0.07, 0.9), Color(0.1, 0.09, 0.085, 0.92), Color(0.15, 0.145, 0.14, 0.55), Color(0.2, 0.2, 0.2, 0.0)])
		_add(column)
		if c.cap > 0:
			cap = FireFx.emitter(c.cap, 4.2, FireFx.quad(Vector2(3.8, 3.8), smoke, 4, false, 0))
			FireFx.random_frame(cap)
			cap.explosiveness = 0.6
			cap.spread = 80.0
			cap.damping_min = 0.9
			cap.damping_max = 1.5
			cap.gravity = Vector3(0, 0.45, 0)
			cap.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			cap.angle_min = -180.0
			cap.angle_max = 180.0
			cap.scale_amount_curve = FireFx.curve([Vector2(0.0, 0.6), Vector2(0.3, 1.2), Vector2(1.0, 1.6)])
			cap.color_ramp = FireFx.ramp([0.0, 0.15, 0.6, 1.0], [Color(0.35, 0.17, 0.07, 0.0), Color(0.12, 0.105, 0.1, 0.85), Color(0.17, 0.165, 0.16, 0.5), Color(0.22, 0.22, 0.22, 0.0)])
			_add(cap)
		# Dust racing out along the ground.
		dust = FireFx.emitter(c.dust, 1.8, FireFx.quad(Vector2(2.2, 2.2), smoke, 4, false, 0))
		FireFx.random_frame(dust)
		dust.explosiveness = 0.9
		dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		dust.emission_ring_axis = Vector3.UP
		dust.emission_ring_height = 0.1
		dust.emission_ring_radius = 1.2
		dust.emission_ring_inner_radius = 0.6
		dust.direction = Vector3.UP
		dust.spread = 25.0
		dust.initial_velocity_min = 0.5
		dust.initial_velocity_max = 2.0
		dust.radial_accel_min = 9.0
		dust.radial_accel_max = 14.0
		dust.damping_min = 3.0
		dust.damping_max = 4.5
		dust.gravity = Vector3(0, 0.35, 0)
		dust.angle_min = -180.0
		dust.angle_max = 180.0
		dust.scale_amount_curve = FireFx.curve([Vector2(0.0, 0.5), Vector2(1.0, 2.0)])
		dust.color_ramp = FireFx.ramp([0.0, 0.2, 1.0], [Color(0.66, 0.58, 0.46, 0.0), Color(0.66, 0.58, 0.46, 0.5), Color(0.6, 0.55, 0.48, 0.0)])
		_add(dust)
		# Dark chunks, flung out and falling.
		chunks = FireFx.emitter(c.chunks, 1.3, FireFx.chunk_mesh(Vector2(0.3, 0.2)))
		_flung(chunks, 0.9)
		chunks.color_ramp = FireFx.ramp([0.0, 0.75, 1.0], [Color(0.16, 0.15, 0.14, 1.0), Color(0.1, 0.095, 0.09, 1.0), Color(0.08, 0.08, 0.08, 0.0)])
		_add(chunks)
		if c.bits > 0:
			bits = FireFx.emitter(c.bits, 1.2, FireFx.quad(Vector2(0.55, 0.55), dot, 1, true, 3))
			_flung(bits, 0.8)
			bits.color_ramp = FireFx.ramp([0.0, 0.35, 1.0], [Color(1.0, 0.85, 0.4, 1.0), Color(1.0, 0.42, 0.08, 0.9), Color(0.4, 0.06, 0.0, 0.0)])
			_add(bits)
		sparks = FireFx.emitter(c.sparks, 0.75, FireFx.quad(Vector2(0.2, 0.2), dot, 1, true, 3))
		_flung(sparks, 1.6)
		sparks.gravity = Vector3(0, -14.0, 0)
		sparks.initial_velocity_min = 8.0
		sparks.initial_velocity_max = 20.0
		sparks.spread = 120.0
		sparks.color_ramp = FireFx.ramp([0.0, 0.5, 1.0], [Color(1.0, 0.95, 0.65, 1.0), Color(1.0, 0.6, 0.15, 0.9), Color(0.8, 0.2, 0.02, 0.0)])
		_add(sparks)
		# The flash: a white-hot sprite and (Medium and up) a short light.
		flash_mat = StandardMaterial3D.new()
		flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		flash_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		flash_mat.billboard_keep_scale = true
		flash_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		flash_mat.albedo_texture = dot
		flash_mat.render_priority = 4
		var fq := QuadMesh.new()
		fq.size = Vector2.ONE
		flash = MeshInstance3D.new()
		flash.mesh = fq
		flash.material_override = flash_mat
		flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flash.visible = false
		add_child(flash)
		if c.flash and FireFx.real_lights:
			light = OmniLight3D.new()
			light.light_color = Color(1.0, 0.72, 0.4)
			light.omni_attenuation = 2.0
			light.light_specular = 0.2
			light.shadow_enabled = false
			light.visible = false
			add_child(light)
		# The shockwave over the ground.
		ring_mat = StandardMaterial3D.new()
		ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		ring_mat.albedo_texture = FireFx.ring()
		ring_mat.render_priority = 2
		var rq := QuadMesh.new()
		rq.size = Vector2.ONE
		rq.orientation = PlaneMesh.FACE_Y
		ring = MeshInstance3D.new()
		ring.mesh = rq
		ring.material_override = ring_mat
		ring.top_level = true
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.visible = false
		add_child(ring)
		set_process(false)

	func _add(p: CPUParticles3D) -> void:
		p.one_shot = true
		p.emitting = false
		add_child(p)

	## A burst thrown in every direction, slowing as it goes.
	func _fireball(n: int, size: float, tex: Texture2D) -> CPUParticles3D:
		var p := FireFx.emitter(n, 0.8, FireFx.quad(Vector2(3.8, 3.8) * size, tex, 4, true, 3))
		FireFx.random_frame(p)
		p.explosiveness = 0.92
		p.randomness = 0.3
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.spread = 180.0
		p.damping_min = 1.8
		p.damping_max = 2.6
		p.gravity = Vector3(0, 2.2, 0)
		p.angle_min = -180.0
		p.angle_max = 180.0
		p.angular_velocity_min = -60.0
		p.angular_velocity_max = 60.0
		p.scale_amount_curve = FireFx.curve([Vector2(0.0, 0.45), Vector2(0.4, 1.0), Vector2(1.0, 1.35)])
		p.color_ramp = FireFx.ramp([0.0, 0.2, 0.55, 1.0], [Color(1.0, 0.98, 0.8, 1.0), Color(1.0, 0.72, 0.22, 0.95), Color(0.9, 0.3, 0.06, 0.7), Color(0.25, 0.06, 0.02, 0.0)])
		_add(p)
		return p

	func _flung(p: CPUParticles3D, size: float) -> void:
		p.explosiveness = 1.0
		p.randomness = 0.5
		p.spread = 75.0
		p.gravity = Vector3(0, -22.0, 0)
		p.angle_min = -180.0
		p.angle_max = 180.0
		p.angular_velocity_min = -500.0
		p.angular_velocity_max = 500.0
		p.scale_amount_min = 0.6 * size
		p.scale_amount_max = 1.3 * size
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.initial_velocity_min = 6.0
		p.initial_velocity_max = 15.0

	## Sets off the blast of size `size` at `pos`.
	func go(pos: Vector3, size: float, ground: float) -> void:
		s = size
		t = 0.0
		active = true
		global_position = pos
		ground_y = ground
		on_ground = pos.y - ground < 5.0 * size
		var dim := FireFx.dim()
		ball.emission_sphere_radius = 0.5 * s
		ball.initial_velocity_min = 5.0 * s
		ball.initial_velocity_max = 14.0 * s
		ball.scale_amount_min = 0.8 * s
		ball.scale_amount_max = 1.3 * s
		ball.position = Vector3(0, 0.4 * s, 0)
		ball.restart()
		_ball2_due = ball2 != null
		if ball2 != null:
			ball2.emission_sphere_radius = 0.4 * s
			ball2.initial_velocity_min = 3.0 * s
			ball2.initial_velocity_max = 10.0 * s
			ball2.scale_amount_min = 0.7 * s
			ball2.scale_amount_max = 1.1 * s
			ball2.position = Vector3(0, 0.6 * s, 0)
		column.position = Vector3(0, 0.5 * s, 0)
		column.emission_sphere_radius = 0.7 * s
		column.initial_velocity_min = 3.0 * s
		column.initial_velocity_max = 7.0 * s
		column.scale_amount_min = 0.8 * s
		column.scale_amount_max = 1.2 * s
		column.color = dim
		column.restart()
		_cap_due = cap != null
		if cap != null:
			cap.position = Vector3(0, 3.0 * s, 0)
			cap.emission_sphere_radius = 0.8 * s
			cap.initial_velocity_min = 1.5 * s
			cap.initial_velocity_max = 3.5 * s
			cap.scale_amount_min = 0.9 * s
			cap.scale_amount_max = 1.3 * s
			cap.color = dim
		dust.visible = on_ground
		if on_ground:
			dust.position = Vector3(0, ground - pos.y + 0.35, 0)
			dust.emission_ring_radius = 1.2 * s
			dust.emission_ring_inner_radius = 0.6 * s
			dust.scale_amount_min = 0.8 * s
			dust.scale_amount_max = 1.3 * s
			dust.color = dim
			dust.restart()
		chunks.position = Vector3(0, 0.4 * s, 0)
		chunks.initial_velocity_min = 6.0 * s
		chunks.initial_velocity_max = 15.0 * s
		chunks.restart()
		if bits != null:
			bits.position = Vector3(0, 0.5 * s, 0)
			bits.initial_velocity_min = 5.0 * s
			bits.initial_velocity_max = 13.0 * s
			bits.restart()
		sparks.position = Vector3(0, 0.5 * s, 0)
		sparks.restart()
		flash.visible = true
		flash.position = Vector3(0, 0.8 * s, 0)
		if light != null:
			light.position = Vector3(0, 1.8 * s, 0)
			light.omni_range = 8.0 + 6.0 * s
			peak = 7.5 * sqrt(s)
			light.light_energy = peak
			light.visible = true
		if on_ground:
			tilt = Basis(Quaternion(Vector3.UP, Terrain.normal(pos.x, pos.z)))
			ring.visible = true
			_place_ring(1.0, 0.0)
		set_process(true)

	func _place_ring(width: float, alpha: float) -> void:
		ring.global_transform = Transform3D(tilt * Basis.from_scale(Vector3(width, 1.0, width)), Vector3(global_position.x, ground_y + LIFT + 0.01, global_position.z))
		ring_mat.albedo_color = Color(0.86, 0.78, 0.64, alpha)

	func _process(delta: float) -> void:
		t += delta
		if _ball2_due and t >= 0.1:
			_ball2_due = false
			ball2.restart()
		if _cap_due and t >= 0.45:
			_cap_due = false
			cap.restart()
		if flash.visible:
			var u := t / 0.24
			if u >= 1.0:
				flash.visible = false
			else:
				flash.scale = Vector3.ONE * s * lerpf(5.0, 12.0, u)
				var c := Color(1.0, 0.96, 0.75).lerp(Color(1.0, 0.55, 0.2), u)
				c.a = pow(1.0 - u, 1.4)
				flash_mat.albedo_color = c
		if light != null and light.visible:
			var k := clampf(1.0 - t / 0.45, 0.0, 1.0)
			light.light_energy = peak * k * k
			if k <= 0.0:
				light.visible = false
		if ring.visible:
			var u := t / 0.65
			if u >= 1.0:
				ring.visible = false
			else:
				_place_ring(2.0 + 15.0 * s * (1.0 - pow(1.0 - u, 2.2)), 0.5 * pow(1.0 - u, 1.4))
		if t > BLAST_LIFE:
			stop()

	## Everything off at once.
	func stop() -> void:
		active = false
		for p in [ball, ball2, column, cap, dust, chunks, bits, sparks]:
			if p != null:
				p.emitting = false
		flash.visible = false
		ring.visible = false
		if light != null:
			light.visible = false
		set_process(false)

	func pieces_on() -> int:
		var n := 0
		for p in [ball, ball2, column, cap, dust, chunks, bits, sparks]:
			if p != null and p.emitting:
				n += 1
		if flash.visible:
			n += 1
		if ring.visible:
			n += 1
		if light != null and light.visible:
			n += 1
		return n
