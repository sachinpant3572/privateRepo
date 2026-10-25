extends Node2D
## Stress test for low-end Android phones: hundreds of enemies, bullets and
## explosion particles at once.
##
## Each type is drawn with one MultiMesh (one draw call). Positions live in
## packed arrays, and bullet hits use a spatial hash grid instead of physics.
## Visual quality tiers (Low to Ultra) live in fx.gd.

const ENEMY_RADIUS := 11.0
const BULLET_RADIUS := 4.0
const PARTICLE_RADIUS := 3.0
const ENEMY_SPEED := 60.0
const ENEMY_HP := 3
const HIT_COOLDOWN := 0.08
const BULLET_SPEED := 560.0
const BULLET_LIFE := 1.5
const BULLET_STREAMS := 6
const PARTICLE_LIFE := 0.4
const PARTICLE_MAX := 8000
const RING_RADIUS := 14.0
const RING_LIFE := 0.35
const TRAIL_STRETCH := 3.0
const CELL := 48.0
const MARGIN := 40.0
const STRIDE := 12  # Floats per instance: 8 for the Transform2D, 4 for the color.

const RAMP_START := 100
const RAMP_GROWTH := 1.25  # Each level has 25% more enemies (at least 100 more).
const RAMP_STEP_TIME := 6.0
const RAMP_MEASURE_FROM := 2.0  # Skip the first seconds of each level.
const RAMP_MAX := 20000
const SOAK_ENEMIES := 500
const SOAK_BULLETS := 1000
const SOAK_TIME := 300.0
const SOAK_SAMPLE := 10.0
const HEAT_INTERVAL := 2.0
const HEAT_NAMES := ["none", "light", "moderate", "severe", "critical", "emergency", "shutdown"]

const ENEMY_COLOR := Color(1.0, 0.31, 0.55)
const BULLET_COLOR := Color(0.5, 0.9, 1.0)
const PARTICLE_COLOR := Color(1.0, 0.65, 0.25)
const RING_COLOR := Color(1.0, 0.85, 0.6)

const FX := preload("res://fx.gd")

enum Mode { MENU, FIXED, RAMP, SOAK }

var mode := Mode.MENU
var smoke := false
var quality := "Ultra"
var fps_cap := 60  # 0 means no cap: the screen's refresh rate.
var heat_on := true

var arena := Vector2(720, 1280)
var player := Vector2.ZERO
var manual_until := 0.0
var run_time := 0.0
var fire_accum := 0.0
var fire_angle := 0.0
var trauma := 0.0
var kills := 0
var enemy_target := 0
var bullet_target := 0

var e_pos := PackedVector2Array()
var e_hp := PackedInt32Array()
var e_cool := PackedFloat32Array()
var e_next := PackedInt32Array()
var e_count := 0

var b_pos := PackedVector2Array()
var b_vel := PackedVector2Array()
var b_life := PackedFloat32Array()
var b_count := 0

var p_pos := PackedVector2Array()
var p_vel := PackedVector2Array()
var p_life := PackedFloat32Array()
var p_count := 0
var p_cap := 0

var r_pos := PackedVector2Array()
var r_life := PackedFloat32Array()
var r_count := 0
var r_cap := 0

var grid_cols := 1
var grid_rows := 1
var cell_head := PackedInt32Array()

var world: Node2D
var player_sprite: Sprite2D
var enemy_mm: MultiMesh
var bullet_mm: MultiMesh
var particle_mm: MultiMesh
var ring_mm: MultiMesh
var e_buf := PackedFloat32Array()
var b_buf := PackedFloat32Array()
var p_buf := PackedFloat32Array()
var r_buf := PackedFloat32Array()
var noise := FastNoiseLite.new()
var glow_layers := []
var fx
var ui

# Frame stats for the current run.
var frame_ms := PackedFloat32Array()
var sim_ms := 0.0
var logic_sum := 0.0
var logic_worst := 0.0
var level_logic_sum := 0.0
var level_logic_worst := 0.0
var hud_timer := 0.0
var level_time := 0.0
var level_frames := 0
var level_measured := 0.0
var best_ramp := -1
var ramp_log := PackedStringArray()
var sample_time := 0.0
var sample_frames := 0
var soak_fps := PackedFloat32Array()
var soak_heat := PackedStringArray()
var last_results := ""

# Phone heat (Android 10+), read through the Android runtime.
var power_manager = null
var heat_status := -1
var heat_headroom := NAN
var heat_timer := 0.0
var heat_worst := -1


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var shots_dir := ""
	for arg in args:
		if arg.begins_with("--shots="):
			shots_dir = arg.trim_prefix("--shots=")
	smoke = "--smoke" in args or shots_dir != ""
	world = Node2D.new()
	add_child(world)
	enemy_mm = _make_layer(_circle_texture(64, 0.62, 0.35), ENEMY_RADIUS, false, Color(0.35, 0.35, 0.35))
	bullet_mm = _make_layer(_circle_texture(32, 0.35, 0.0), BULLET_RADIUS, true, Color.WHITE)
	particle_mm = _make_layer(_circle_texture(16, 0.0, 0.0), PARTICLE_RADIUS, true, Color.WHITE)
	ring_mm = _make_layer(_ring_texture(64), RING_RADIUS, true, Color.WHITE)
	player_sprite = Sprite2D.new()
	player_sprite.texture = _circle_texture(48, 0.8, 0.0)
	player_sprite.modulate = Color(0.85, 1.0, 1.0)
	player_sprite.visible = false
	world.add_child(player_sprite)

	fx = FX.new()
	add_child(fx)
	fx.setup(glow_layers, player_sprite.texture)

	ui = preload("res://ui.gd").new()
	ui.layer = 10
	add_child(ui)
	ui.start_requested.connect(_on_start_requested)
	ui.stop_requested.connect(_finish)
	ui.option_toggled.connect(_on_option_toggled)

	get_viewport().size_changed.connect(_on_resized)
	_on_resized()
	# Fast screens get Ultra by default; others start at Medium.
	_set_quality("Ultra" if DisplayServer.screen_get_refresh_rate() >= 90.0 else "Medium")
	if shots_dir != "":
		_run_shots(shots_dir)
	elif smoke:
		_run_smoke()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if mode == Mode.MENU:
			get_tree().quit()
		else:
			_finish()


func _unhandled_input(event: InputEvent) -> void:
	if mode != Mode.MENU and event is InputEventScreenDrag:
		player = (player + event.relative).clamp(Vector2.ZERO, arena)
		manual_until = run_time + 2.0


func _on_resized() -> void:
	arena = get_viewport_rect().size
	grid_cols = int(ceil((arena.x + MARGIN * 2.0) / CELL)) + 1
	grid_rows = int(ceil((arena.y + MARGIN * 2.0) / CELL)) + 1
	cell_head.resize(grid_cols * grid_rows)
	if fx != null:
		fx.resize(arena)


func _on_start_requested(kind: String, enemies: int, bullets: int) -> void:
	match kind:
		"fixed":
			_start(Mode.FIXED, enemies, bullets)
		"ramp":
			_start(Mode.RAMP, RAMP_START, RAMP_START * 2)
		"soak":
			_start(Mode.SOAK, SOAK_ENEMIES, SOAK_BULLETS)


func _on_option_toggled(option: String) -> void:
	match option:
		"quality":
			_set_quality(FX.ORDER[(FX.ORDER.find(quality) + 1) % FX.ORDER.size()])
			return
		"cap":
			match fps_cap:
				60:
					fps_cap = 30
				30:
					fps_cap = 0
				_:
					fps_cap = 60
			Engine.max_fps = fps_cap
		"heat":
			heat_on = not heat_on
	ui.set_options(quality, fps_cap, heat_on)


func _set_quality(tier_name: String) -> void:
	quality = tier_name
	fx.apply(quality, arena)
	fps_cap = fx.tier["fps_cap"]
	Engine.max_fps = fps_cap
	ui.set_options(quality, fps_cap, heat_on)


func _start(new_mode: Mode, enemies: int, bullets: int) -> void:
	mode = new_mode
	run_time = 0.0
	manual_until = 0.0
	fire_accum = 0.0
	trauma = 0.0
	kills = 0
	e_count = 0
	b_count = 0
	p_count = 0
	r_count = 0
	frame_ms = PackedFloat32Array()
	hud_timer = 0.0
	level_time = 0.0
	level_frames = 0
	level_measured = 0.0
	level_logic_sum = 0.0
	level_logic_worst = 0.0
	logic_sum = 0.0
	logic_worst = 0.0
	best_ramp = -1
	ramp_log = PackedStringArray()
	sample_time = 0.0
	sample_frames = 0
	soak_fps = PackedFloat32Array()
	soak_heat = PackedStringArray()
	heat_timer = 0.0
	heat_worst = -1
	player = arena * 0.5
	player_sprite.visible = true
	_init_heat()
	_set_load(enemies, bullets)
	ui.show_hud()


func _set_load(enemies: int, bullets: int) -> void:
	enemy_target = enemies
	bullet_target = bullets

	e_pos.resize(enemies)
	e_hp.resize(enemies)
	e_cool.resize(enemies)
	e_next.resize(enemies)
	enemy_mm.instance_count = enemies
	e_buf = _instance_buffer(enemies, ENEMY_COLOR)
	for i in range(e_count, enemies):
		_spawn_enemy(i, true)
	e_count = enemies

	var b_cap := int(bullets * 1.25) + 64
	b_pos.resize(b_cap)
	b_vel.resize(b_cap)
	b_life.resize(b_cap)
	b_count = mini(b_count, b_cap)
	bullet_mm.instance_count = b_cap
	b_buf = _instance_buffer(b_cap, BULLET_COLOR)

	p_cap = mini(PARTICLE_MAX, 200 + enemies * int(fx.tier["sparks"]) / 4)
	p_pos.resize(p_cap)
	p_vel.resize(p_cap)
	p_life.resize(p_cap)
	p_count = mini(p_count, p_cap)
	particle_mm.instance_count = p_cap
	p_buf = _instance_buffer(p_cap, PARTICLE_COLOR)

	r_cap = int(fx.tier["rings"])
	r_pos.resize(r_cap)
	r_life.resize(r_cap)
	r_count = mini(r_count, r_cap)
	ring_mm.instance_count = r_cap
	r_buf = _instance_buffer(r_cap, RING_COLOR)


func _instance_buffer(count: int, color: Color) -> PackedFloat32Array:
	# Layout per instance: basis.x.x, basis.y.x, pad, origin.x,
	# basis.x.y, basis.y.y, pad, origin.y, then r, g, b, a.
	# Only the origin (and the color or scale for some types) changes per frame.
	var buf := PackedFloat32Array()
	buf.resize(count * STRIDE)
	for i in count:
		var o := i * STRIDE
		buf[o] = 1.0
		buf[o + 5] = 1.0
		buf[o + 8] = color.r
		buf[o + 9] = color.g
		buf[o + 10] = color.b
		buf[o + 11] = color.a
	return buf


func _spawn_enemy(i: int, anywhere: bool) -> void:
	var p: Vector2
	if anywhere:
		# Fill the screen at once, but not right on top of the player.
		var a := randf() * TAU
		var r := randf_range(180.0, arena.length() * 0.6)
		p = (arena * 0.5 + Vector2.from_angle(a) * r).clamp(Vector2(-MARGIN, -MARGIN) * 0.5, arena + Vector2(MARGIN, MARGIN) * 0.5)
	else:
		match randi() % 4:
			0:
				p = Vector2(randf() * arena.x, -MARGIN * 0.5)
			1:
				p = Vector2(randf() * arena.x, arena.y + MARGIN * 0.5)
			2:
				p = Vector2(-MARGIN * 0.5, randf() * arena.y)
			_:
				p = Vector2(arena.x + MARGIN * 0.5, randf() * arena.y)
	e_pos[i] = p
	e_hp[i] = ENEMY_HP
	e_cool[i] = 0.0


func _process(delta: float) -> void:
	if mode == Mode.MENU:
		return
	var dt := 1.0 / 60.0 if smoke else minf(delta, 0.05)
	var t0 := Time.get_ticks_usec()
	run_time += dt
	_update_player(dt)
	_update_enemies(dt)
	_fire(dt)
	_update_bullets(dt)
	_update_particles(dt)
	_update_rings(dt)
	_upload()
	_shake(dt)
	sim_ms = (Time.get_ticks_usec() - t0) / 1000.0
	logic_sum += sim_ms
	logic_worst = maxf(logic_worst, sim_ms)
	_track(dt if smoke else delta)


func _update_player(dt: float) -> void:
	if run_time > manual_until:
		# Autopilot, so every run on every phone does the same work.
		var target := arena * 0.5 + Vector2(cos(run_time * 0.7) * arena.x * 0.25, sin(run_time * 1.1) * arena.y * 0.18)
		player = player.lerp(target, minf(1.0, dt * 3.0))
	player_sprite.position = player


func _update_enemies(dt: float) -> void:
	var step := ENEMY_SPEED * dt
	var touch_r2 := (ENEMY_RADIUS + 16.0) * (ENEMY_RADIUS + 16.0)
	cell_head.fill(-1)
	for i in e_count:
		var p := e_pos[i]
		var d := player - p
		var len2 := d.length_squared()
		if len2 < touch_r2:
			_spawn_enemy(i, false)
			p = e_pos[i]
		elif len2 > 1.0:
			p += d * (step / sqrt(len2))
			e_pos[i] = p
		var cool := e_cool[i]
		if cool > 0.0:
			cool -= dt
			e_cool[i] = cool

		var cx := clampi(int((p.x + MARGIN) / CELL), 0, grid_cols - 1)
		var cy := clampi(int((p.y + MARGIN) / CELL), 0, grid_rows - 1)
		var c := cy * grid_cols + cx
		e_next[i] = cell_head[c]
		cell_head[c] = i

		var o := i * STRIDE
		e_buf[o + 3] = p.x
		e_buf[o + 7] = p.y
		if cool > 0.0:
			e_buf[o + 9] = 1.0
			e_buf[o + 10] = 1.0
		else:
			e_buf[o + 9] = ENEMY_COLOR.g
			e_buf[o + 10] = ENEMY_COLOR.b


func _fire(dt: float) -> void:
	fire_accum += bullet_target / BULLET_LIFE * dt
	var n := int(fire_accum)
	fire_accum -= n
	var cap := b_pos.size()
	for k in n:
		if b_count >= cap:
			break
		fire_angle += 0.137
		var a := fire_angle + TAU * float(k % BULLET_STREAMS) / BULLET_STREAMS
		b_pos[b_count] = player
		b_vel[b_count] = Vector2.from_angle(a) * BULLET_SPEED
		b_life[b_count] = BULLET_LIFE
		b_count += 1


func _update_bullets(dt: float) -> void:
	var hit_r2 := (ENEMY_RADIUS + BULLET_RADIUS) * (ENEMY_RADIUS + BULLET_RADIUS)
	var lo := -MARGIN
	var hi := arena + Vector2(MARGIN, MARGIN)
	var trails: bool = fx.tier["trails"]
	var i := 0
	while i < b_count:
		var life := b_life[i] - dt
		var p := b_pos[i] + b_vel[i] * dt
		if life <= 0.0 or p.x < lo or p.y < lo or p.x > hi.x or p.y > hi.y:
			b_count -= 1
			b_pos[i] = b_pos[b_count]
			b_vel[i] = b_vel[b_count]
			b_life[i] = b_life[b_count]
			continue
		b_pos[i] = p
		b_life[i] = life

		# Bullets pierce, so the bullet count stays steady. Enemies get a short
		# cooldown after each hit instead.
		var cx := int((p.x + MARGIN) / CELL)
		var cy := int((p.y + MARGIN) / CELL)
		for gy in range(maxi(cy - 1, 0), mini(cy + 2, grid_rows)):
			for gx in range(maxi(cx - 1, 0), mini(cx + 2, grid_cols)):
				var j := cell_head[gy * grid_cols + gx]
				while j != -1:
					if e_cool[j] <= 0.0 and p.distance_squared_to(e_pos[j]) < hit_r2:
						_hit(j)
					j = e_next[j]

		var o := i * STRIDE
		b_buf[o + 3] = p.x
		b_buf[o + 7] = p.y
		if trails:
			# Stretch the bullet along its direction into a streak.
			var d := b_vel[i] / BULLET_SPEED
			b_buf[o] = d.x * TRAIL_STRETCH
			b_buf[o + 1] = -d.y
			b_buf[o + 4] = d.y * TRAIL_STRETCH
			b_buf[o + 5] = d.x
		i += 1


func _hit(j: int) -> void:
	e_cool[j] = HIT_COOLDOWN
	e_hp[j] -= 1
	if e_hp[j] > 0:
		return
	kills += 1
	_burst(e_pos[j])
	trauma = minf(trauma + 0.004, 0.3)
	_spawn_enemy(j, false)


func _burst(at: Vector2) -> void:
	if r_count < r_cap:
		r_pos[r_count] = at
		r_life[r_count] = RING_LIFE
		r_count += 1
	for k in int(fx.tier["sparks"]):
		if p_count >= p_cap:
			return
		p_pos[p_count] = at
		p_vel[p_count] = Vector2.from_angle(randf() * TAU) * randf_range(80.0, 260.0)
		p_life[p_count] = PARTICLE_LIFE
		p_count += 1


func _update_particles(dt: float) -> void:
	var drag := maxf(0.0, 1.0 - 3.0 * dt)
	var sparks: bool = fx.tier["trails"]
	var i := 0
	while i < p_count:
		var life := p_life[i] - dt
		if life <= 0.0:
			p_count -= 1
			p_pos[i] = p_pos[p_count]
			p_vel[i] = p_vel[p_count]
			p_life[i] = p_life[p_count]
			continue
		var v := p_vel[i] * drag
		var p := p_pos[i] + v * dt
		p_vel[i] = v
		p_pos[i] = p
		p_life[i] = life
		var k := life / PARTICLE_LIFE
		var o := i * STRIDE
		if sparks:
			# Stretch along the direction of travel, longer when faster.
			var speed := v.length()
			var u := v / maxf(speed, 0.001)
			var stretch := k * (1.0 + speed * 0.012)
			var width := k * 0.7
			p_buf[o] = u.x * stretch
			p_buf[o + 1] = -u.y * width
			p_buf[o + 4] = u.y * stretch
			p_buf[o + 5] = u.x * width
		else:
			p_buf[o] = k
			p_buf[o + 5] = k
		p_buf[o + 3] = p.x
		p_buf[o + 7] = p.y
		p_buf[o + 11] = k
		i += 1


func _update_rings(dt: float) -> void:
	var i := 0
	while i < r_count:
		var life := r_life[i] - dt
		if life <= 0.0:
			r_count -= 1
			r_pos[i] = r_pos[r_count]
			r_life[i] = r_life[r_count]
			continue
		r_life[i] = life
		var k := life / RING_LIFE
		var s := lerpf(2.4, 0.4, k)
		var p := r_pos[i]
		var o := i * STRIDE
		r_buf[o] = s
		r_buf[o + 5] = s
		r_buf[o + 3] = p.x
		r_buf[o + 7] = p.y
		r_buf[o + 11] = k * 0.8
		i += 1


func _upload() -> void:
	enemy_mm.visible_instance_count = e_count
	RenderingServer.multimesh_set_buffer(enemy_mm.get_rid(), e_buf)
	bullet_mm.visible_instance_count = b_count
	RenderingServer.multimesh_set_buffer(bullet_mm.get_rid(), b_buf)
	particle_mm.visible_instance_count = p_count
	RenderingServer.multimesh_set_buffer(particle_mm.get_rid(), p_buf)
	ring_mm.visible_instance_count = r_count
	if r_cap > 0:
		RenderingServer.multimesh_set_buffer(ring_mm.get_rid(), r_buf)


func _shake(dt: float) -> void:
	trauma = maxf(trauma - dt * 1.2, 0.0)
	var s := trauma * trauma * 14.0
	world.position = Vector2(noise.get_noise_2d(run_time * 60.0, 0.0), noise.get_noise_2d(0.0, run_time * 60.0)) * s
	fx.update(world.position, player, true, trauma)


func _track(delta: float) -> void:
	frame_ms.append(delta * 1000.0)
	_track_heat(delta)
	match mode:
		Mode.RAMP:
			_track_ramp(delta)
		Mode.SOAK:
			_track_soak(delta)
	if mode == Mode.MENU:
		return
	hud_timer -= delta
	if hud_timer <= 0.0:
		hud_timer = 0.25
		ui.set_hud_text(_hud_text())


func _track_ramp(delta: float) -> void:
	level_time += delta
	if level_time >= RAMP_MEASURE_FROM:
		level_frames += 1
		level_measured += delta
		level_logic_sum += sim_ms
		level_logic_worst = maxf(level_logic_worst, sim_ms)
	if level_time < RAMP_STEP_TIME:
		return
	var fps := level_frames / maxf(level_measured, 0.001)
	var held := fps >= _target_fps() * 0.92
	ramp_log.append("%d + %d: %.1f FPS, logic %.1f ms avg, %.1f worst%s" % [enemy_target, bullet_target, fps, level_logic_sum / maxi(level_frames, 1), level_logic_worst, "" if held else " (too slow)"])
	if held:
		best_ramp = enemy_target
	if not held or enemy_target >= RAMP_MAX:
		_finish()
		return
	level_time = 0.0
	level_frames = 0
	level_measured = 0.0
	level_logic_sum = 0.0
	level_logic_worst = 0.0
	var next := mini(RAMP_MAX, maxi(enemy_target + 100, int(enemy_target * RAMP_GROWTH / 50.0) * 50))
	_set_load(next, next * 2)


func _track_soak(delta: float) -> void:
	sample_time += delta
	sample_frames += 1
	if sample_time >= SOAK_SAMPLE:
		soak_fps.append(sample_frames / sample_time)
		soak_heat.append(_heat_name(heat_status))
		sample_time = 0.0
		sample_frames = 0
	if run_time >= SOAK_TIME:
		_finish()


func _finish() -> void:
	if mode == Mode.MENU:
		return
	var title := "Results"
	match mode:
		Mode.FIXED:
			title = "Fixed load: %d enemies + %d bullets" % [enemy_target, bullet_target]
		Mode.RAMP:
			title = "Auto ramp"
		Mode.SOAK:
			title = "5-minute heat soak: %d enemies + %d bullets" % [SOAK_ENEMIES, SOAK_BULLETS]
	last_results = _results_text(title)
	mode = Mode.MENU
	e_count = 0
	b_count = 0
	p_count = 0
	r_count = 0
	_upload()
	world.position = Vector2.ZERO
	player_sprite.visible = false
	fx.update(Vector2.ZERO, player, false, 0.0)
	ui.show_menu(last_results)


func _hud_text() -> String:
	var n := frame_ms.size()
	var from := maxi(0, n - 60)
	var sum := 0.0
	var worst := 0.0
	for i in range(from, n):
		sum += frame_ms[i]
		worst = maxf(worst, frame_ms[i])
	var fps := (n - from) * 1000.0 / maxf(sum, 0.001)
	var lines := PackedStringArray()
	lines.append("FPS %.0f   worst %.0f ms   game logic %.1f ms" % [fps, worst, sim_ms])
	lines.append("%s   Enemies %d   Bullets %d   Sparks %d" % [quality, e_count, b_count, p_count])
	lines.append("Kills %d   Draw calls %d" % [kills, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	match mode:
		Mode.RAMP:
			lines.append("Auto ramp: level %d, best so far %s" % [enemy_target, str(best_ramp) if best_ramp > 0 else "-"])
		Mode.SOAK:
			lines.append("Heat soak: %d s left" % int(SOAK_TIME - run_time))
	lines.append("Heat: %s" % _heat_text())
	return "\n".join(lines)


func _results_text(title: String) -> String:
	var sorted := frame_ms.duplicate()
	sorted.sort()
	var n := sorted.size()
	var total := 0.0
	for ms in sorted:
		total += ms
	var worst_count := maxi(1, int(n / 100.0))
	var worst_sum := 0.0
	for i in range(n - worst_count, n):
		worst_sum += sorted[i]
	var slow_limit := 1000.0 / _target_fps() * 1.5
	var slow := 0
	for ms in sorted:
		if ms > slow_limit:
			slow += 1

	var lines := PackedStringArray()
	lines.append(title)
	lines.append("Phone: %s, %s" % [OS.get_model_name(), _chip_name()])
	lines.append("GPU: %s (%s)" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_api_version()])
	var ram := _ram_gb()
	lines.append("RAM: %s   Screen: %.0f Hz   Android: %s" % ["%.1f GB usable" % ram if ram > 0.0 else "unknown", DisplayServer.screen_get_refresh_rate(), OS.get_version()])
	lines.append("Settings: quality %s, FPS cap %s" % [quality, str(fps_cap) if fps_cap > 0 else "none (%d Hz screen)" % _target_fps()])
	if n > 0 and total > 0.0:
		lines.append("Ran %.0f s, average %.1f FPS, worst 1%% %.1f FPS" % [total / 1000.0, n * 1000.0 / total, 1000.0 / (worst_sum / worst_count)])
		lines.append("Slow frames (over %.0f ms): %d of %d (%.1f%%)" % [slow_limit, slow, n, slow * 100.0 / n])
		lines.append("Game logic per frame: %.1f ms avg, %.1f ms worst (a 60 FPS frame is 16.7 ms in total)" % [logic_sum / n, logic_worst])
	lines.append("Kills: %d" % kills)
	if mode == Mode.RAMP:
		var limit: String = str(best_ramp) + " (with twice as many bullets)" if best_ramp > 0 else "below " + str(RAMP_START)
		if best_ramp >= RAMP_MAX:
			limit += ", the test's maximum"
		lines.append("Most enemies held at %d+ FPS: %s" % [int(_target_fps() * 0.92), limit])
		lines.append_array(ramp_log)
	if mode == Mode.SOAK:
		var parts := PackedStringArray()
		for v in soak_fps:
			parts.append("%.0f" % v)
		lines.append("FPS every 10 s: " + ", ".join(parts))
		lines.append("Heat every 10 s: " + ", ".join(soak_heat))
	lines.append("Worst heat level: %s" % _heat_name(heat_worst))
	return "\n".join(lines)


func _target_fps() -> int:
	if fps_cap > 0:
		return fps_cap
	var hz := roundi(DisplayServer.screen_get_refresh_rate())
	return hz if hz > 0 else 60


func _ram_gb() -> float:
	var ram: int = OS.get_memory_info().get("physical", -1)
	if ram > 0:
		return ram / 1073741824.0
	# Android often hides this from Godot, but /proc/meminfo is readable.
	var f := FileAccess.open("/proc/meminfo", FileAccess.READ)
	if f == null:
		return -1.0
	while not f.eof_reached():
		var line := f.get_line()
		if line.begins_with("MemTotal:"):
			return line.split(" ", false)[1].to_float() / 1048576.0
	return -1.0


func _chip_name() -> String:
	var chip := OS.get_processor_name()
	if chip == "":
		for path in ["/sys/devices/soc0/machine", "/sys/devices/soc0/soc_id"]:
			if not FileAccess.file_exists(path):
				continue
			var f := FileAccess.open(path, FileAccess.READ)
			if f != null:
				chip = f.get_line().strip_edges()
			if chip != "":
				break
	return "%s, %d cores" % [chip if chip != "" else "unknown chip", OS.get_processor_count()]


func _init_heat() -> void:
	power_manager = null
	heat_status = -1
	heat_headroom = NAN
	if not heat_on or OS.get_name() != "Android" or not Engine.has_singleton("AndroidRuntime"):
		return
	var runtime = Engine.get_singleton("AndroidRuntime")
	var activity = runtime.getActivity()
	if activity != null:
		power_manager = activity.getSystemService("power")


func _track_heat(delta: float) -> void:
	if power_manager == null:
		return
	heat_timer -= delta
	if heat_timer > 0.0:
		return
	heat_timer = HEAT_INTERVAL
	var s = power_manager.getCurrentThermalStatus()
	if typeof(s) == TYPE_INT:
		heat_status = s
		heat_worst = maxi(heat_worst, s)
	var h = power_manager.getThermalHeadroom(10)
	if typeof(h) == TYPE_FLOAT:
		heat_headroom = h


func _heat_name(status: int) -> String:
	if status < 0 or status >= HEAT_NAMES.size():
		return "n/a"
	return HEAT_NAMES[status]


func _heat_text() -> String:
	if power_manager == null:
		return "n/a"
	if is_nan(heat_headroom):
		return _heat_name(heat_status)
	# Headroom 1.0 means the phone is about to throttle.
	return "%s (headroom %.2f)" % [_heat_name(heat_status), heat_headroom]


func _make_layer(tex: Texture2D, radius: float, additive: bool, glow_modulate: Color) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.mesh = _quad_mesh(radius)
	var inst := MultiMeshInstance2D.new()
	inst.multimesh = mm
	inst.texture = tex
	if additive:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		inst.material = mat
	world.add_child(inst)
	glow_layers.append([mm, tex, additive, glow_modulate])
	return mm


func _quad_mesh(r: float) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(-r, -r), Vector2(r, -r), Vector2(r, r), Vector2(-r, r)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## A soft disc. "core" is the solid part (0-1 of the radius). "rim" darkens
## the middle so the edge reads as a bright outline (0 = no rim).
func _circle_texture(size: int, core: float, rim: float) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) * 0.5
	for y in size:
		for x in size:
			var d: float = Vector2(x - c, y - c).length() / (size * 0.5)
			var a: float = 0.0
			if d < core:
				a = 1.0
			elif d < 1.0:
				a = (1.0 - d) / maxf(1.0 - core, 0.001)
			var shade: float = 1.0 - rim * (1.0 - smoothstep(0.0, core, d))
			img.set_pixel(x, y, Color(shade, shade, shade, a))
	return ImageTexture.create_from_image(img)


func _ring_texture(size: int) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) * 0.5
	for y in size:
		for x in size:
			var d: float = Vector2(x - c, y - c).length() / (size * 0.5)
			var a: float = clampf(1.0 - absf(d - 0.8) / 0.12, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)


func _run_smoke() -> void:
	# Headless check for CI: runs each mode briefly with a fixed 1/60 s step.
	print("SMOKE: start")
	_set_quality("Ultra")
	_start(Mode.FIXED, 2000, 4000)
	await _frames(180)
	print("SMOKE: fixed enemies=%d bullets=%d particles=%d kills=%d logic_ms=%.2f" % [e_count, b_count, p_count, kills, sim_ms])
	if not _check(e_count == 2000 and b_count > 1000 and kills > 0, "fixed load is running"):
		return
	if not _check(r_count > 0, "Ultra shockwave rings are running"):
		return
	_finish()
	_set_quality("Low")
	_start(Mode.RAMP, RAMP_START, RAMP_START * 2)
	await _frames(int(RAMP_STEP_TIME * 60.0) + 30)
	if not _check(mode == Mode.MENU or enemy_target > RAMP_START, "ramp moved to the next level"):
		return
	_finish()
	_set_quality("High")
	_start(Mode.SOAK, SOAK_ENEMIES, SOAK_BULLETS)
	await _frames(int(SOAK_SAMPLE * 60.0) + 30)
	if not _check(soak_fps.size() >= 1, "soak recorded a sample"):
		return
	_finish()
	print(last_results)
	print("SMOKE: passed")
	get_tree().quit(0)


func _run_shots(dir: String) -> void:
	# Renders each tier with a real GPU driver (CI uses software OpenGL), so
	# shaders compile and the screenshots can be checked.
	DirAccess.make_dir_recursive_absolute(dir)
	for tier_name in FX.ORDER:
		_set_quality(tier_name)
		_start(Mode.FIXED, 1000, 2000)
		await _frames(150)
		await RenderingServer.frame_post_draw
		var path := dir.path_join("%s.png" % tier_name.to_lower())
		get_viewport().get_texture().get_image().save_png(path)
		print("SHOTS: saved %s (sparks=%d rings=%d)" % [path, p_count, r_count])
		_finish()
	print("SHOTS: done")
	get_tree().quit(0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(ok: bool, what: String) -> bool:
	if not ok:
		printerr("SMOKE FAILED: " + what)
		get_tree().quit(1)
	return ok
