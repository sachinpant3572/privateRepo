extends Node3D
## Game feel, shared by everything (autoload "Fx"): hit-stop and screen shake
## on punches and crashes, spark and debris bursts, tyre smoke, splashes,
## tyre marks, exhaust and tyre smoke (puffs.gd) and blood (blood.gd). Bursts
## come from small pools of one-shot particle emitters; tyre marks, puffs and
## blood marks are one MultiMesh each, so all of it costs a handful of draw
## calls.

## Tyre-mark strips kept on the ground (a ring buffer: the oldest goes).
const SKID_COUNT := 700
## Puffs alive at once by graphics quality.
const PUFFS := {"low": 90, "medium": 160, "high": 260, "ultra": 260}
## Loud bursts (crashes, knocked props, fights) startle nearby birds.
const Birds = preload("res://scripts/birds.gd")
const GameLog = preload("res://scripts/game_log.gd")
const Blood = preload("res://scripts/blood.gd")
const Puffs = preload("res://scripts/puffs.gd")
const Boom = preload("res://scripts/explosion.gd")
const FireFx = preload("res://scripts/fire_fx.gd")
const Terrain = preload("res://scripts/terrain.gd")

## Off in headless runs (tests), where slowing time would only slow tests.
var enabled := true
var camera: Node
## Spurts and marks on the ground (blood.gd; Settings > Game > Blood).
var bloodwork: Blood
## Exhaust and tyre smoke (Fx.puff).
var puffs: Puffs
## 0 by day .. 1 at night (the Atmosphere sets it each frame).
var night := 0.0
## Explosions: fireball, smoke column, shockwave, scorch (Fx.explosion).
var boom: Boom

var _pools := {}
var _skids: MultiMeshInstance3D
var _skid_next := 0
var _skid_total := 0
## Each strip's darkness, kept here too (the headless renderer keeps no
## instance colours).
var _skid_alpha := PackedFloat32Array()
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
	_skid_alpha.resize(SKID_COUNT)
	add_child(_skids)
	bloodwork = Blood.new()
	bloodwork.name = "Blood"
	add_child(bloodwork)
	puffs = Puffs.new()
	puffs.name = "Puffs"
	add_child(puffs)
	boom = Boom.new()
	boom.name = "Boom"
	add_child(boom)


func _process(_delta: float) -> void:
	if _stop_until > 0 and Time.get_ticks_msec() >= _stop_until:
		_stop_until = 0
		Engine.time_scale = 1.0


## A punch or kick landed. Only fights involving the player freeze time.
func hit(pos: Vector3, strong: bool, involves_player: bool) -> void:
	_burst("spark", pos + Vector3(0, 1.2, 0), 1.6 if strong else 1.0)
	Birds.startle(pos, 14.0 if strong else 9.0)
	if involves_player:
		hit_stop(0.09 if strong else 0.05)
		shake(0.35 if strong else 0.15)


## A vehicle hit something at `impact` m/s.
func crash(pos: Vector3, impact: float, involves_player: bool) -> void:
	if involves_player or impact > 9.0:
		GameLog.event("crash", {"impact": impact, "player": involves_player, "at": pos})
	var strength := clampf(impact / 20.0, 0.2, 1.0)
	preload("res://scripts/senses.gd").emit(get_tree(), "crash", pos, null, {"loud": 0.5 + strength}) # people react
	_burst("spark", pos + Vector3(0, 0.6, 0), 1.0 + strength)
	Birds.startle(pos, 20.0 + 30.0 * strength)
	if impact > 9.0:
		_burst("debris", pos + Vector3(0, 0.6, 0), 1.0)
	if involves_player:
		shake(0.2 + 0.6 * strength)
		if impact > 14.0:
			hit_stop(0.06)


## An explosion of size `scale` (1 about a car, a fuel tank or a gas bottle
## less) at `pos`: flash, fireball, smoke column, dust and shockwave on the
## ground, flung chunks and sparks, a scorch mark; people near it hear it, birds
## fly, and the view shakes by how far the player is. `ground` is the surface
## height under it (default: the terrain). It does no damage: the caller
## hurts what is near (car_fire.gd does).
func explosion(pos: Vector3, scale := 1.0, ground := NAN) -> void:
	if is_nan(ground):
		ground = Terrain.height(pos.x, pos.z)
	preload("res://scripts/senses.gd").emit(get_tree(), "crash", pos, null, {"loud": 1.5})
	Birds.startle(pos, 60.0 * scale)
	boom.blast(pos, scale, ground)
	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		var reach := 45.0 * scale
		var d: float = player.global_position.distance_to(pos)
		if d < reach:
			shake(lerpf(1.0, 0.25, d / reach))


## A car knocked a roadside prop of `kind` down at `pos` (Breakables):
## debris, leaves off a tree, sparks off a lamp, a hydrant's gusher.
func knock(pos: Vector3, kind: String, involves_player: bool) -> void:
	GameLog.event("prop_down", {"prop": kind, "player": involves_player, "at": pos})
	_burst("debris", pos, 0.8)
	Birds.startle(pos, 25.0)
	preload("res://scripts/senses.gd").emit(get_tree(), "crash", pos, null, {"loud": 0.6}) # people react
	match kind:
		"street_tree", "crepe_myrtle":
			_burst("leaves", pos + Vector3(0, 1.5, 0), 1.0)
		"street_light", "gas_lamp", "traffic_light", "ev_charger":
			_burst("spark", pos + Vector3(0, 0.8, 0), 1.4)
		"hydrant":
			_gush(pos, 6.0)
		"roadworks":
			_gush(pos, 0.8) # the water barriers burst
	if involves_player:
		shake(0.12)


## Water from the pool of gush emitters for `secs`. An emitter reused while
## an earlier gush runs keeps going for its new time: the earlier timer
## only stops it if it was not taken again since.
func _gush(pos: Vector3, secs: float) -> void:
	var p: CPUParticles3D = _pools["gush"].pop_front()
	_pools["gush"].push_back(p)
	var turn: int = p.get_meta("turn", 0) + 1
	p.set_meta("turn", turn)
	p.global_position = pos
	p.one_shot = false
	p.emitting = true
	get_tree().create_timer(secs, false).timeout.connect(func():
		if p.get_meta("turn", 0) == turn:
			p.emitting = false)


func smoke(pos: Vector3, scale := 1.0) -> void:
	_burst("smoke", pos, scale)


func splash(pos: Vector3) -> void:
	_burst("splash", pos, 1.0)


## A short tyre mark at `pos` (on the ground), stretched along `dir`.
func skid(pos: Vector3, dir: Vector3) -> void:
	var d := Vector3(dir.x, 0.0, dir.z)
	d = d.normalized() * 0.375 if d.length() > 0.01 else Vector3(0, 0, 0.375)
	tyre_mark(pos - d, pos + d, 0.3, 0.5)


## A strip of rubber on the ground from `a` to `b`, `width` m wide, `alpha`
## dark (about 0.5 a locked or sliding tyre, 0.15 an ABS stop's faint mark).
## Consecutive strips from one wheel meet end to end into one track.
func tyre_mark(a: Vector3, b: Vector3, width: float, alpha: float) -> void:
	var d := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var length := d.length()
	if length < 0.01:
		return
	var along := d / length
	var side := along.cross(Vector3.UP)
	# Unit quad (FACE_Y): x across the tread, z along the track; a little
	# overlap hides the seams between strips.
	var basis := Basis(side * width, Vector3.UP, along * (length + 0.06))
	var mid := (a + b) * 0.5
	mid.y = maxf(a.y, b.y) + 0.03
	_skids.multimesh.set_instance_transform(_skid_next, Transform3D(basis, mid))
	_skid_alpha[_skid_next] = clampf(alpha, 0.0, 0.8)
	_skids.multimesh.set_instance_color(_skid_next, Color(0.04, 0.04, 0.045, _skid_alpha[_skid_next]))
	_skid_next = (_skid_next + 1) % SKID_COUNT
	_skid_total += 1
	_skids.multimesh.visible_instance_count = mini(_skid_total, SKID_COUNT)


## How many tyre-mark strips are on the ground.
func tyre_marks() -> int:
	return mini(_skid_total, SKID_COUNT)


## A puff of exhaust or tyre smoke (see puffs.gd).
func puff(pos: Vector3, vel: Vector3, size: float, grow: float, life: float, color: Color) -> void:
	puffs.add(pos, vel, size, grow, life, color)


## Graphics quality: fewer puffs alive at once on the lower presets.
func set_quality(level: String, real_lights := true) -> void:
	puffs.cap = PUFFS.get(level, PUFFS["high"])
	FireFx.set_level(level, real_lights)
	var t0 := Time.get_ticks_usec()
	FireFx.warm()
	boom.warm()
	GameLog.event("fire_warm", {"ms": (Time.get_ticks_usec() - t0) / 1000.0})
	prewarm_fire.call_deferred()


## Draws every fire and blast material for half a second, specks in front of
## the camera, so their shaders compile while the game loads and not at the
## first fire or blast (Android compiles a shader the first time it is
## drawn: a hitch). Particles draw through a MultiMesh, another shader
## variant than a plain mesh, so those go through a one-particle emitter
## (clear, alpha 0). Returns the holder (null with no camera), tests.
func prewarm_fire() -> Node3D:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return null
	var holder := Node3D.new()
	holder.name = "FireWarm"
	holder.position = Vector3(0.0, 0.0, -(cam.near + 0.5))
	cam.add_child(holder)
	for mat in FireFx._mats.values():
		var q := QuadMesh.new()
		q.size = Vector2.ONE * 0.002
		q.material = mat
		var p := FireFx.emitter(1, 0.5, q)
		p.color = Color(1.0, 1.0, 1.0, 0.0)
		holder.add_child(p)
	for mat in boom.mesh_materials():
		var speck := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3.ONE * 0.002
		speck.mesh = box
		speck.material_override = mat
		speck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(speck)
	get_tree().create_timer(0.5).timeout.connect(holder.queue_free)
	return holder


## Blood from a wound at `pos` spraying along `dir` (zero: any way), with
## drops on the ground ahead; `amount` about 0.4 a punch .. 2 a hard crash.
## People call it through Humanoid.bleed(). It adds no hit-stop or shake.
func blood(pos: Vector3, dir: Vector3, amount: float) -> void:
	bloodwork.spurt(pos, dir, amount)


## A blood smear at `pos` along `dir` (a body sliding), `width` m wide.
func blood_smear(pos: Vector3, dir: Vector3, width: float) -> void:
	bloodwork.smear(pos, dir, width)


## A pool of blood spreading from `pos` to about `size` m over `grow` s.
func blood_pool(pos: Vector3, size: float, grow := 5.0) -> void:
	bloodwork.pool(pos, size, grow)


## Settings > Game > Blood: off shows none and clears what is there.
func set_blood(on: bool) -> void:
	bloodwork.set_on(on)


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
	mm.use_colors = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	q.orientation = PlaneMesh.FACE_Y
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	q.material = m
	mm.mesh = q
	mm.instance_count = SKID_COUNT
	mm.visible_instance_count = 0
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return inst
