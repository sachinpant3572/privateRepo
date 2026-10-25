extends Node2D
## World 1 prototype (milestone M1 in docs/game-design.md): one 5-minute stage
## of The Iron Dominion plus a boss, with placeholder art drawn in code.
##
## Same engine approach as games/stress-test: entities live in packed arrays,
## hits use a spatial hash grid, and each layer is one MultiMesh. Units use one
## MultiMesh per sprite (8 draw calls for every enemy on screen).
## Dead enemies are only marked during the frame and removed at the end, so
## grid lists stay valid while weapons are hitting things.

const Data := preload("res://data.gd")
const Art := preload("res://art.gd")
const FX := preload("res://fx.gd")
const Overlay := preload("res://overlay.gd")

const STRIDE := 12  # Floats per instance: 8 for the Transform2D, 4 for the color.
const CELL := 64.0
const GRID_PAD := 200.0
const WORLD_BOUNDS := 1.0e7  # Culling bounds for the MultiMesh layers; the world itself is endless.
const STAGE_TIME := 300.0
const BOSS_HP := 9000.0
const BOSS_RADIUS := 62.0
const BOSS_SCALE := 0.8
const BOSS_TURRETS := [Vector2(40, -34), Vector2(40, 34), Vector2(-36, 0)]
const PLAYER_RADIUS := 14.0
const PLAYER_HP := 120.0
const PICKUP := 120.0
const INVULN := 0.5
const MAX_SLOTS := 6
const MAX_LEVEL := 8
const SHOT_CAP := 2500
const ROCKET_CAP := 300
const EB_CAP := 700
const GEM_CAP := 600
const CHEST_CAP := 8
const SPARK_CAP := 5000
const BLADE_CAP := 16
const RING_SIZE := 14.0
const RING_LIFE := 0.35
const SPARK_LIFE := 0.4
const SHOT_COLOR := Color(0.55, 0.9, 1.0)
const ROCKET_COLOR := Color(1.0, 0.6, 0.25)
const SPARK_COLOR := Color(1.0, 0.65, 0.25)
const RING_COLOR := Color(1.0, 0.85, 0.6)
const BLADE_COLOR := Color(0.7, 0.95, 1.0)
const COIN_CAP := 400
const PICKUP_CAP := 6
const PICKUP_LIFE := 20.0
const PICKUP_CHANCE := 0.004
const COMBO_TIME := 2.0
const FREEZE_TIME := 5.0
const SAVE_PATH := "user://save.cfg"
# Most enemies at once (at 4:00), the same on every quality tier. Tiers that
# can't draw that many spawn fewer, tougher enemies worth more XP instead.
const GAME_PEAK := 320
const VFX_RADIUS := 16.0
const DECAL_CAP := 60
const DECAL_LIFE := 8.0
const RIFLE_COLOR := Color(0.55, 0.9, 1.0)
const STORM_COLOR := Color(0.75, 0.85, 1.0)
const SCATTER_COLOR := Color(1.0, 0.8, 0.35)
const GEM_BLUE := Color(0.45, 0.75, 1.0)
const GEM_GREEN := Color(0.4, 1.0, 0.55)
const GEM_RED := Color(1.0, 0.4, 0.4)

enum State { MENU, PLAYING, CARDS, DEAD, OVER, CHEST }

var state := State.MENU
var autoplay := false
var smoke := false
var god := false
var bot_cards := true
var bot_still := false
var quality := "Ultra"
var fps_cap := 0
var view := Vector2(720, 1280)

# Player and stage.
var t := 0.0
var player := Vector2.ZERO
var cam := Vector2.ZERO
var facing := Vector2.RIGHT
var move_vec := Vector2.ZERO
var hp := 100.0
var max_hp := 100.0
var armor := 0.0
var speed := 210.0
var pickup := 70.0
var magnet_all := false
var fire_rate := 1.0
var dmg_mult := 1.0
var bonus_dmg := 0.0
var crit_chance := 0.05
var crit_mult := 2.0
var explosive := 0
var invuln := 0.0
var level := 1
var xp := 0.0
var xp_need := 9.0
var pending_levels := 0
var kills := 0
var revived := false
var trauma := 0.0
var hitstop := 0.0
var gold := 0
var gold_doubled := false
var combo := 0
var combo_timer := 0.0
var combo_best := 0
var combo_step := 0
var freeze_t := 0.0
var events_done := 0
var hp_mult := 1.0
var chest_rewards: Array = []
var save := ConfigFile.new()

# Build.
var weapons := {}  # id -> level
var powers := {}  # id -> level
var evolved := {}  # weapon id -> true
var w_timer := {}
var w_stats := {}
var halo_angle := 0.0
var offers: Array = []
var chest_cards := false
var third_left := 3
var reroll_left := 1

# Joystick.
var joy_on := false
var joy_index := -1
var joy_origin := Vector2.ZERO
var joy_vec := Vector2.ZERO

# Enemy tables, copied into packed arrays for fast lookups.
var t_hp: PackedFloat32Array
var t_speed: PackedFloat32Array
var t_radius: PackedFloat32Array
var t_size: PackedFloat32Array
var t_touch: PackedFloat32Array
var t_fire: PackedFloat32Array
var t_range: PackedFloat32Array
var t_xp: PackedInt32Array
var t_capn: PackedInt32Array

# Enemies.
var e_type := PackedInt32Array()
var e_pos := PackedVector2Array()
var e_ang := PackedFloat32Array()
var e_hp := PackedFloat32Array()
var e_flash := PackedFloat32Array()
var e_timer := PackedFloat32Array()
var e_halo := PackedFloat32Array()
var e_next := PackedInt32Array()
var e_count := 0
var e_cap := 0
var type_alive := PackedInt32Array([0, 0, 0, 0, 0, 0])
var nearest := -1
var spawn_acc := 0.0
var elites_spawned := 0
# Troopers share a fire budget, so a big crowd can't fill the screen with bullets.
var shot_budget := 0.0

# Spatial hash grid around the camera.
var grid_origin := Vector2.ZERO
var grid_cols := 1
var grid_rows := 1
var cell_head := PackedInt32Array()

# Player shots (rifle and scatter).
var s_pos := PackedVector2Array()
var s_vel := PackedVector2Array()
var s_life := PackedFloat32Array()
var s_dmg := PackedFloat32Array()
var s_pierce := PackedInt32Array()
var s_last := PackedInt32Array()
var s_col := PackedColorArray()
var s_count := 0

# Rockets.
var k_pos := PackedVector2Array()
var k_vel := PackedVector2Array()
var k_aim := PackedVector2Array()
var k_life := PackedFloat32Array()
var k_dmg := PackedFloat32Array()
var k_rad := PackedFloat32Array()
var k_retarget := PackedFloat32Array()
var k_crit := PackedInt32Array()
var k_count := 0

# Enemy bullets.
var b_pos := PackedVector2Array()
var b_vel := PackedVector2Array()
var b_life := PackedFloat32Array()
var b_dmg := PackedFloat32Array()
var b_rad := PackedFloat32Array()
var b_count := 0

# Pickups.
var g_pos := PackedVector2Array()
var g_val := PackedInt32Array()
var g_mag := PackedInt32Array()
var g_count := 0
var c_pos := PackedVector2Array()
var c_count := 0
var co_pos := PackedVector2Array()
var co_mag := PackedInt32Array()
var co_count := 0
var pickups: Array = []  # [kind, position, time left, Sprite2D]
var pickup_textures := []

# Effects.
var p_pos := PackedVector2Array()
var p_vel := PackedVector2Array()
var p_life := PackedFloat32Array()
var p_count := 0
var p_cap := 0
var r_pos := PackedVector2Array()
var r_life := PackedFloat32Array()
var r_size := PackedFloat32Array()
var r_count := 0
var r_cap := 0
# Explosion particles: additive fire and alpha-blended smoke share one pool.
var v_pos := PackedVector2Array()
var v_vel := PackedVector2Array()
var v_life := PackedFloat32Array()
var v_max := PackedFloat32Array()
var v_s0 := PackedFloat32Array()
var v_s1 := PackedFloat32Array()
var v_c0 := PackedColorArray()
var v_c1 := PackedColorArray()
var v_fire := PackedInt32Array()
var v_count := 0
var v_cap := 0
var fire_n := 0
var smoke_n := 0
var d_pos := PackedVector2Array()
var d_life := PackedFloat32Array()
var d_size := PackedFloat32Array()
var d_count := 0
var bl_count := 0
var telegraphs: Array = []  # [kind, start, end or radius, time left, total, damage]
var bolts: Array = []  # [points, time left]
var bombs: Array = []  # [position, delay, radius, damage]
var blasts: Array = []  # Queued Explosive Rounds blasts: [position, radius, damage]

# Boss.
var boss_on := false
var boss_spawned := false
var boss_dead_t := -1.0
var boss_pos := Vector2.ZERO
var boss_hp := 0.0
var boss_ang := 0.0
var boss_mode := "move"
var boss_timer := 0.0
var boss_cycle := 0
var boss_dir := Vector2.RIGHT
var boss_flash := 0.0
var boss_halo_cd := 0.0

# Nodes and render buffers.
var world: Node2D
var ground: ColorRect
var ground_mat: ShaderMaterial
var hero: Sprite2D
var boss_node: Sprite2D
var boss_turret_nodes := []
var unit_mms := []  # One MultiMesh per unit sprite (Art cell order).
var unit_cap := PackedInt32Array()
var unit_off := PackedInt32Array()
var unit_n := PackedInt32Array()
var shot_mm: MultiMesh
var rocket_mm: MultiMesh
var eb_mm: MultiMesh
var gem_mm: MultiMesh
var chest_mm: MultiMesh
var spark_mm: MultiMesh
var ring_mm: MultiMesh
var blade_mm: MultiMesh
var coin_mm: MultiMesh
var co_buf := PackedFloat32Array()
var fire_mm: MultiMesh
var smoke_mm: MultiMesh
var decal_mm: MultiMesh
var fire_buf := PackedFloat32Array()
var smoke_buf := PackedFloat32Array()
var decal_buf := PackedFloat32Array()
var numbers
var sfx
var u_buf := PackedFloat32Array()
var s_buf := PackedFloat32Array()
var k_buf := PackedFloat32Array()
var b_buf := PackedFloat32Array()
var g_buf := PackedFloat32Array()
var c_buf := PackedFloat32Array()
var p_buf := PackedFloat32Array()
var r_buf := PackedFloat32Array()
var bl_buf := PackedFloat32Array()
var glow_layers := []
var noise := FastNoiseLite.new()
var fx
var hud

# Performance stats for the results screen.
var frame_ms := PackedFloat32Array()
var sim_ms := 0.0
var logic_sum := 0.0
var logic_worst := 0.0
var peak_enemies := 0
var hud_timer := 0.0
var last_results := ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var shots_dir := ""
	for arg in args:
		if arg.begins_with("--shots="):
			shots_dir = arg.trim_prefix("--shots=")
	smoke = "--smoke" in args or shots_dir != ""
	t_hp = PackedFloat32Array(Data.ENEMY_HP)
	t_speed = PackedFloat32Array(Data.ENEMY_SPEED)
	t_radius = PackedFloat32Array(Data.ENEMY_RADIUS)
	t_size = PackedFloat32Array(Data.ENEMY_SIZE)
	t_touch = PackedFloat32Array(Data.ENEMY_TOUCH)
	t_fire = PackedFloat32Array(Data.ENEMY_FIRE)
	t_range = PackedFloat32Array(Data.ENEMY_RANGE)
	t_xp = PackedInt32Array(Data.ENEMY_XP)
	t_capn = PackedInt32Array(Data.ENEMY_CAP)
	save.load(SAVE_PATH)
	_build_scene()
	get_viewport().size_changed.connect(_on_resized)
	_on_resized()
	_set_quality("Ultra" if DisplayServer.screen_get_refresh_rate() >= 90.0 else "Medium")
	_to_menu()
	if shots_dir != "":
		_run_shots(shots_dir)
	elif smoke:
		_run_smoke()


func _build_scene() -> void:
	world = Node2D.new()
	add_child(world)
	ground = ColorRect.new()
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground_mat = ShaderMaterial.new()
	ground_mat.shader = preload("res://ground.gdshader")
	var ground_tex := Art.sprite("ground")
	if ground_tex != null:
		ground_mat.set_shader_parameter("ground_tex", ground_tex)
		ground_mat.set_shader_parameter("use_tex", true)
	ground.material = ground_mat
	world.add_child(ground)
	var low := Overlay.new()
	low.game = self
	world.add_child(low)

	decal_mm = _layer(Art.scorch(64), 32.0, false, Color(0, 0, 0, 0))
	gem_mm = _layer(Art.gem(24), 8.0, true, Color(0.4, 0.4, 0.4))
	coin_mm = _layer(Art.coin(32), 9.0, false, Color(0.5, 0.4, 0.1))
	chest_mm = _layer(Art.chest(48), 22.0, false, Color(0.6, 0.6, 0.6))
	for kind in 4:
		pickup_textures.append(Art.pickup_icon(kind, 64))
	for tex in Art.cell_textures():
		unit_mms.append(_layer(tex, 0.5, false, Color(0.25, 0.25, 0.25)))
	shot_mm = _layer(Art.soft_disc(32, 0.35), 5.0, true, Color(0.6, 0.6, 0.6))
	rocket_mm = _layer(Art.soft_disc(32, 0.3), 7.0, true, Color.WHITE)
	blade_mm = _layer(Art.blade(64), 16.0, true, Color(0.8, 0.8, 0.8))
	smoke_mm = _layer(Art.soft_disc(32, 0.15), VFX_RADIUS, false, Color(0, 0, 0, 0))
	fire_mm = _layer(Art.soft_disc(32, 0.3), VFX_RADIUS, true, Color.WHITE)
	spark_mm = _layer(Art.soft_disc(16, 0.0), 3.0, true, Color.WHITE)
	ring_mm = _layer(Art.ring(64), RING_SIZE, true, Color.WHITE)

	boss_node = Sprite2D.new()
	boss_node.texture = Art.boss()
	boss_node.scale = Vector2(BOSS_SCALE, BOSS_SCALE)
	boss_node.visible = false
	world.add_child(boss_node)
	var turret_tex := Art.turret_texture()
	for offset in BOSS_TURRETS:
		var turret := Sprite2D.new()
		turret.texture = turret_tex
		turret.position = offset / BOSS_SCALE
		turret.scale = Vector2(1.1, 1.1)
		boss_node.add_child(turret)
		boss_turret_nodes.append(turret)

	hero = Sprite2D.new()
	hero.texture = Art.hero(64)
	hero.scale = Vector2(0.75, 0.75)
	world.add_child(hero)
	# Enemy bullets go on top so they are always readable.
	eb_mm = _layer(Art.enemy_bullet(32), 6.0, true, Color.WHITE)
	var top := Overlay.new()
	top.game = self
	top.top = true
	world.add_child(top)
	numbers = preload("res://numbers.gd").new()
	world.add_child(numbers)
	sfx = preload("res://sfx.gd").new()
	add_child(sfx)
	sfx.muted = smoke

	fx = FX.new()
	add_child(fx)
	fx.setup(glow_layers, hero.texture)

	hud = preload("res://hud.gd").new()
	hud.layer = 10
	add_child(hud)
	hud.start_pressed.connect(_start)
	hud.card_chosen.connect(_on_card)
	hud.third_pressed.connect(_on_third)
	hud.reroll_pressed.connect(_on_reroll)
	hud.revive_pressed.connect(_on_revive)
	hud.give_up_pressed.connect(_game_over.bind(false))
	hud.menu_pressed.connect(_to_menu)
	hud.option_toggled.connect(_on_option)
	hud.chest_collected.connect(_on_chest_collected)
	hud.double_gold_pressed.connect(_on_double_gold)


func _layer(tex: Texture2D, radius: float, additive: bool, glow_modulate: Color) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.mesh = _quad(radius)
	# The buffers are written straight to the RenderingServer, which never
	# recomputes the bounds, so without this the layer is culled once the
	# camera leaves the start area.
	mm.custom_aabb = AABB(Vector3(-WORLD_BOUNDS, -WORLD_BOUNDS, -1.0), Vector3(WORLD_BOUNDS * 2.0, WORLD_BOUNDS * 2.0, 2.0))
	var inst := MultiMeshInstance2D.new()
	inst.multimesh = mm
	inst.texture = tex
	if additive:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		inst.material = mat
	world.add_child(inst)
	glow_layers.append([mm, tex, additive, glow_modulate, null])
	return mm


func _quad(r: float) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(-r, -r), Vector2(r, -r), Vector2(r, r), Vector2(-r, r)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## A buffer for `count` instances with an identity transform and one color.
func _buffer(count: int, color: Color) -> PackedFloat32Array:
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


func _on_resized() -> void:
	view = get_viewport_rect().size
	grid_cols = int(ceil((view.x + GRID_PAD * 2.0) / CELL))
	grid_rows = int(ceil((view.y + GRID_PAD * 2.0) / CELL))
	cell_head.resize(grid_cols * grid_rows)
	ground.size = view + Vector2(400, 400)
	if fx != null:
		fx.resize(view)


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	match state:
		State.MENU:
			get_tree().quit()
		State.OVER:
			_to_menu()
		_:
			_game_over(false)


func _unhandled_input(event: InputEvent) -> void:
	if state != State.PLAYING or autoplay:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and not joy_on:
			joy_on = true
			joy_index = touch.index
			joy_origin = touch.position
			joy_vec = Vector2.ZERO
		elif not touch.pressed and touch.index == joy_index:
			joy_on = false
			joy_vec = Vector2.ZERO
		hud.set_joystick(joy_on, joy_origin, joy_origin)
	elif event is InputEventScreenDrag and joy_on:
		var drag := event as InputEventScreenDrag
		if drag.index != joy_index:
			return
		var d := drag.position - joy_origin
		if d.length() > 90.0:
			joy_origin = drag.position - d.normalized() * 90.0
			d = drag.position - joy_origin
		joy_vec = d / 90.0
		hud.set_joystick(true, joy_origin, joy_origin + d)


func _on_option(option: String) -> void:
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
	hud.set_options(quality, fps_cap)


func _set_quality(tier_name: String) -> void:
	quality = tier_name
	fx.apply(quality, view)
	fps_cap = fx.tier["fps_cap"]
	Engine.max_fps = fps_cap
	ground_mat.set_shader_parameter("detail", 0.4 + 0.6 * float(fx.tier["detail"]))
	hud.set_options(quality, fps_cap)


# --- Stage flow -------------------------------------------------------------

func _to_menu() -> void:
	state = State.MENU
	_clear_entities()
	hero.visible = false
	boss_node.visible = false
	hud.show_menu(_save_summary())


func _start(auto: bool) -> void:
	autoplay = auto
	state = State.PLAYING
	t = 0.0
	player = Vector2.ZERO
	cam = player
	facing = Vector2.RIGHT
	level = 1
	xp = 0.0
	xp_need = _xp_need(1)
	pending_levels = 0
	kills = 0
	revived = false
	trauma = 0.0
	hitstop = 0.0
	invuln = 0.0
	weapons = {"rifle": 1}
	powers = {}
	evolved = {}
	w_timer = {}
	bonus_dmg = 0.0
	third_left = 3
	reroll_left = 1
	joy_on = false
	joy_vec = Vector2.ZERO
	max_hp = PLAYER_HP
	_recalc()
	hp = max_hp
	_alloc()
	boss_on = false
	boss_spawned = false
	boss_dead_t = -1.0
	boss_node.visible = false
	elites_spawned = 0
	spawn_acc = 0.0
	shot_budget = 0.0
	gold = 0
	gold_doubled = false
	combo = 0
	combo_timer = 0.0
	combo_best = 0
	combo_step = 0
	freeze_t = 0.0
	events_done = 0
	hp_mult = 1.0
	numbers.clear()
	frame_ms = PackedFloat32Array()
	logic_sum = 0.0
	logic_worst = 0.0
	peak_enemies = 0
	hero.visible = true
	hud.set_boss(false, 0.0)
	hud.show_play()
	_update_hud()


## Sizes every pool for the current quality tier.
func _alloc() -> void:
	_clear_entities()
	e_cap = int(fx.tier["enemies"]) + 40
	e_type.resize(e_cap)
	e_pos.resize(e_cap)
	e_ang.resize(e_cap)
	e_hp.resize(e_cap)
	e_flash.resize(e_cap)
	e_timer.resize(e_cap)
	e_halo.resize(e_cap)
	e_next.resize(e_cap)
	# Every unit sprite gets a slice of one shared buffer.
	unit_cap = PackedInt32Array([e_cap, e_cap, e_cap, 8, 12, 12, 10, 10])
	unit_off.resize(unit_cap.size())
	unit_n.resize(unit_cap.size())
	var total := 0
	for c in unit_cap.size():
		unit_off[c] = total
		total += unit_cap[c]
		unit_mms[c].instance_count = unit_cap[c]
	u_buf = _buffer(total, Color.WHITE)
	s_pos.resize(SHOT_CAP)
	s_vel.resize(SHOT_CAP)
	s_life.resize(SHOT_CAP)
	s_dmg.resize(SHOT_CAP)
	s_pierce.resize(SHOT_CAP)
	s_last.resize(SHOT_CAP)
	s_col.resize(SHOT_CAP)
	shot_mm.instance_count = SHOT_CAP
	s_buf = _buffer(SHOT_CAP, SHOT_COLOR)
	k_pos.resize(ROCKET_CAP)
	k_vel.resize(ROCKET_CAP)
	k_aim.resize(ROCKET_CAP)
	k_life.resize(ROCKET_CAP)
	k_dmg.resize(ROCKET_CAP)
	k_rad.resize(ROCKET_CAP)
	k_retarget.resize(ROCKET_CAP)
	k_crit.resize(ROCKET_CAP)
	rocket_mm.instance_count = ROCKET_CAP
	k_buf = _buffer(ROCKET_CAP, ROCKET_COLOR)
	b_pos.resize(EB_CAP)
	b_vel.resize(EB_CAP)
	b_life.resize(EB_CAP)
	b_dmg.resize(EB_CAP)
	b_rad.resize(EB_CAP)
	eb_mm.instance_count = EB_CAP
	b_buf = _buffer(EB_CAP, Color.WHITE)
	g_pos.resize(GEM_CAP)
	g_val.resize(GEM_CAP)
	g_mag.resize(GEM_CAP)
	gem_mm.instance_count = GEM_CAP
	g_buf = _buffer(GEM_CAP, Color.WHITE)
	c_pos.resize(CHEST_CAP)
	chest_mm.instance_count = CHEST_CAP
	c_buf = _buffer(CHEST_CAP, Color.WHITE)
	co_pos.resize(COIN_CAP)
	co_mag.resize(COIN_CAP)
	coin_mm.instance_count = COIN_CAP
	co_buf = _buffer(COIN_CAP, Color.WHITE)
	p_cap = mini(SPARK_CAP, 600 + int(int(fx.tier["enemies"]) * int(fx.tier["sparks"]) / 2.0))
	p_pos.resize(p_cap)
	p_vel.resize(p_cap)
	p_life.resize(p_cap)
	spark_mm.instance_count = p_cap
	p_buf = _buffer(p_cap, SPARK_COLOR)
	r_cap = int(fx.tier["rings"])
	r_pos.resize(r_cap)
	r_life.resize(r_cap)
	r_size.resize(r_cap)
	ring_mm.instance_count = r_cap
	r_buf = _buffer(r_cap, RING_COLOR)
	blade_mm.instance_count = BLADE_CAP
	bl_buf = _buffer(BLADE_CAP, BLADE_COLOR)
	v_cap = int(fx.tier["vfx"])
	v_pos.resize(v_cap)
	v_vel.resize(v_cap)
	v_life.resize(v_cap)
	v_max.resize(v_cap)
	v_s0.resize(v_cap)
	v_s1.resize(v_cap)
	v_c0.resize(v_cap)
	v_c1.resize(v_cap)
	v_fire.resize(v_cap)
	fire_mm.instance_count = v_cap
	smoke_mm.instance_count = v_cap
	fire_buf = _buffer(v_cap, Color.WHITE)
	smoke_buf = _buffer(v_cap, Color.WHITE)
	d_pos.resize(DECAL_CAP)
	d_life.resize(DECAL_CAP)
	d_size.resize(DECAL_CAP)
	decal_mm.instance_count = DECAL_CAP
	decal_buf = _buffer(DECAL_CAP, Color.WHITE)


func _clear_entities() -> void:
	e_count = 0
	s_count = 0
	k_count = 0
	b_count = 0
	g_count = 0
	c_count = 0
	co_count = 0
	v_count = 0
	d_count = 0
	fire_n = 0
	smoke_n = 0
	p_count = 0
	r_count = 0
	bl_count = 0
	unit_n.fill(0)
	type_alive.fill(0)
	telegraphs.clear()
	bolts.clear()
	bombs.clear()
	blasts.clear()
	for pk in pickups:
		pk[3].queue_free()
	pickups.clear()
	if unit_cap.size() > 0:
		_upload()


func _game_over(victory: bool) -> void:
	if state == State.OVER or state == State.MENU:
		return
	state = State.OVER
	joy_on = false
	hud.set_joystick(false, Vector2.ZERO, Vector2.ZERO)
	if victory:
		gold += 100
	_record_run(victory)
	last_results = _results_text(victory)
	hud.show_results(victory, last_results, gold)
	sfx.play("fanfare" if victory else "hurt")
	if autoplay:
		print(last_results)


func _on_death() -> void:
	state = State.DEAD
	joy_on = false
	hud.set_joystick(false, Vector2.ZERO, Vector2.ZERO)
	hud.show_death(not revived)
	if autoplay:
		call_deferred("_on_revive" if not revived else "_give_up")


func _give_up() -> void:
	_game_over(false)


func _on_revive() -> void:
	if state != State.DEAD or revived:
		return
	revived = true
	hp = max_hp * 0.6
	invuln = 2.0
	b_count = 0
	telegraphs.clear()
	_damage_around(player, 260.0, 200.0)
	_power_moment(1.5, Color(0.5, 0.9, 1.0))
	state = State.PLAYING
	hud.show_play()


# --- Frame ------------------------------------------------------------------

func _process(delta: float) -> void:
	if state != State.PLAYING:
		fx.update(world.position, player, hero.visible, 0.0)
		return
	var dt := 1.0 / 60.0 if smoke else minf(delta, 0.05)
	if hitstop > 0.0:
		hitstop -= dt
		return
	var t0 := Time.get_ticks_usec()
	t += dt
	freeze_t = maxf(freeze_t - dt, 0.0)
	if combo > 0:
		combo_timer -= dt
		if combo_timer <= 0.0:
			combo = 0
			combo_step = 0
	_run_events()
	_update_player(dt)
	grid_origin = cam - view * 0.5 - Vector2(GRID_PAD, GRID_PAD)
	_update_enemies(dt)
	_spawn_director(dt)
	_update_boss(dt)
	_fire_weapons(dt)
	_update_shots(dt)
	_update_rockets(dt)
	_update_halo(dt)
	_update_bombs(dt)
	_update_enemy_bullets(dt)
	_update_telegraphs(dt)
	_update_pickups(dt)
	_update_coins(dt)
	_update_powerups(dt)
	_compact_enemies()
	_update_sparks(dt)
	_update_rings(dt)
	_update_vfx(dt)
	_render_units()
	_upload()
	numbers.step(dt)
	_update_camera(dt)
	sim_ms = (Time.get_ticks_usec() - t0) / 1000.0
	logic_sum += sim_ms
	logic_worst = maxf(logic_worst, sim_ms)
	frame_ms.append((dt if smoke else delta) * 1000.0)
	hud.set_bars(hp / max_hp, xp / xp_need)
	hud_timer -= dt
	if hud_timer <= 0.0:
		hud_timer = 0.1
		_update_hud()
	if hp <= 0.0:
		_on_death()
	elif boss_dead_t >= 0.0 and t - boss_dead_t > 2.0:
		_game_over(true)
	elif pending_levels > 0 and state == State.PLAYING:
		_open_cards(false)


func _update_player(dt: float) -> void:
	var mv := Vector2.ZERO
	if autoplay:
		mv = _bot_move()
	else:
		mv = joy_vec
		var keys := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		if keys != Vector2.ZERO:
			mv = keys
	if mv.length() > 1.0:
		mv = mv.normalized()
	move_vec = mv
	player += mv * speed * dt
	if mv.length_squared() > 0.01:
		facing = mv.normalized()
	invuln = maxf(invuln - dt, 0.0)
	hero.position = player
	hero.rotation = facing.angle()
	hero.modulate.a = 0.35 if invuln > 0.0 and int(t * 20.0) % 2 == 0 else 1.0


func _update_camera(dt: float) -> void:
	cam = cam.lerp(player, minf(1.0, dt * 8.0))
	trauma = maxf(trauma - dt * 1.4, 0.0)
	var s := trauma * trauma * 16.0
	var shake := Vector2(noise.get_noise_2d(t * 60.0, 0.0), noise.get_noise_2d(0.0, t * 60.0)) * s
	world.position = -cam + view * 0.5 + shake
	ground.position = cam - view * 0.5 - Vector2(200, 200)
	ground_mat.set_shader_parameter("origin", ground.position)
	fx.update(world.position, player, hero.visible, trauma)


func _hurt(amount: float) -> void:
	if invuln > 0.0 or god or state != State.PLAYING:
		return
	hp -= maxf(1.0, amount - armor)
	invuln = INVULN
	trauma = minf(trauma + 0.35, 1.0)
	combo = int(combo / 2.0)
	hud.flash_damage()
	sfx.play("hurt")
	if not smoke:
		Input.vibrate_handheld(35)


# --- Enemies ----------------------------------------------------------------

func _spawn_point() -> Vector2:
	# Mostly ahead of the player when moving, so the fight comes to them.
	var a := randf() * TAU
	if move_vec.length_squared() > 0.1 and randf() < 0.6:
		a = facing.angle() + randf_range(-1.4, 1.4)
	return player + Vector2.from_angle(a) * (view.length() * 0.5 + 60.0)


func _spawn_enemy(ty: int) -> void:
	if e_count >= e_cap:
		return
	var i := e_count
	e_type[i] = ty
	e_pos[i] = _spawn_point()
	e_ang[i] = 0.0
	e_hp[i] = t_hp[ty] * (1.0 + 0.2 * t / 60.0) * hp_mult
	e_flash[i] = 0.0
	e_timer[i] = t_fire[ty] * randf()
	e_halo[i] = 0.0
	e_count += 1
	type_alive[ty] += 1
	peak_enemies = maxi(peak_enemies, e_count)


func _spawn_director(dt: float) -> void:
	if boss_dead_t >= 0.0:
		return
	if not boss_spawned and t >= STAGE_TIME:
		_spawn_boss()
	if (elites_spawned == 0 and t >= 120.0) or (elites_spawned == 1 and t >= 240.0):
		elites_spawned += 1
		_spawn_enemy(Data.ELITE)
		hud.show_banner("JUGGERNAUT INCOMING")
		sfx.play("alarm")
	var target := int(lerpf(18.0, GAME_PEAK, clampf(t / 240.0, 0.0, 1.0)))
	if boss_on:
		target = int(target * 0.35)
	# The same fight on every tier: if this tier draws fewer enemies, each one
	# is tougher and worth more XP.
	var cap := mini(target, int(int(fx.tier["enemies"]) * 0.9))
	hp_mult = maxf(1.0, float(target) / maxf(cap, 1.0))
	target = cap
	spawn_acc = minf(spawn_acc + dt * (12.0 + t * 0.25), 30.0)
	shot_budget = minf(shot_budget + dt * (1.5 + t / 60.0), 5.0)
	var weights := Data.spawn_weights(t)
	while spawn_acc >= 1.0 and e_count < target and e_count < e_cap:
		spawn_acc -= 1.0
		var ty := _pick(weights)
		if t_capn[ty] > 0 and type_alive[ty] >= t_capn[ty]:
			ty = Data.TROOPER
		_spawn_enemy(ty)


func _run_events() -> void:
	if events_done >= Data.EVENTS.size():
		return
	var ev: Array = Data.EVENTS[events_done]
	if t < float(ev[0]):
		return
	events_done += 1
	hud.show_banner(ev[1])
	sfx.play("alarm")
	var n: int = ev[3]
	var side := Vector2.from_angle(randf() * TAU)
	for k in n:
		_spawn_enemy(ev[2])
		var i := e_count - 1
		if i < 0:
			break
		if ev[4] == "ring":
			e_pos[i] = player + Vector2.from_angle(TAU * k / n) * 420.0
		else:
			e_pos[i] = player + side * 560.0 + side.orthogonal() * (k - n * 0.5) * 60.0


func _pick(weights: PackedFloat32Array) -> int:
	var total := 0.0
	for w in weights:
		total += w
	var r := randf() * total
	for i in weights.size():
		r -= weights[i]
		if r <= 0.0:
			return i
	return 0


func _update_enemies(dt: float) -> void:
	cell_head.fill(-1)
	nearest = -1
	var best := INF
	var gx0 := grid_origin.x
	var gy0 := grid_origin.y
	var despawn2 := pow(view.length() * 0.8, 2.0)
	for i in e_count:
		if e_hp[i] <= 0.0:
			continue
		var ty := e_type[i]
		var p := e_pos[i]
		var to := player - p
		var d2 := to.length_squared()
		if d2 > despawn2:
			# Stragglers far behind come back in ahead of the player.
			p = _spawn_point()
			to = player - p
			d2 = to.length_squared()
		var d := sqrt(d2)
		var dir := to / maxf(d, 0.001)
		var sp := 0.0 if freeze_t > 0.0 else t_speed[ty]
		var v := dir * sp
		match ty:
			Data.GRENADIER:
				if d < 220.0:
					v = -dir * sp
				elif d < 300.0:
					v = Vector2(-dir.y, dir.x) * sp * 0.5
			Data.TANK:
				if d < 240.0:
					v = Vector2.ZERO
			Data.HELI:
				v = Vector2(-dir.y, dir.x) * sp * 0.8 + dir * sp * clampf((d - 320.0) / 120.0, -1.0, 1.0)
		p += v * dt

		var rad := t_radius[ty]
		var cx := clampi(int((p.x - gx0) / CELL), 0, grid_cols - 1)
		var cy := clampi(int((p.y - gy0) / CELL), 0, grid_rows - 1)
		var c := cy * grid_cols + cx
		# Push apart from a few neighbors so crowds don't stack into one blob.
		var j := cell_head[c]
		var n := 0
		while j != -1 and n < 5:
			var dd := p - e_pos[j]
			var l2 := dd.length_squared()
			var rr := rad + t_radius[e_type[j]]
			if l2 < rr * rr and l2 > 0.0001:
				var l := sqrt(l2)
				p += dd / l * (rr - l) * 0.5
			j = e_next[j]
			n += 1
		e_pos[i] = p
		e_next[i] = cell_head[c]
		cell_head[c] = i

		if ty == Data.TANK:
			if v.length_squared() > 1.0:
				e_ang[i] = lerp_angle(e_ang[i], v.angle(), minf(1.0, dt * 3.0))
		elif freeze_t <= 0.0:
			e_ang[i] = dir.angle()
		if e_flash[i] > 0.0:
			e_flash[i] -= dt
		if e_halo[i] > 0.0:
			e_halo[i] -= dt
		if d < rad + PLAYER_RADIUS and freeze_t <= 0.0:
			_hurt(t_touch[ty])
		if d2 < best:
			best = d2
			nearest = i
		var fire := t_fire[ty]
		if fire > 0.0 and freeze_t <= 0.0:
			var tm := e_timer[i] - dt
			if tm <= 0.0:
				if d < t_range[ty]:
					_enemy_attack(ty, p, dir)
					tm = fire * randf_range(0.85, 1.15)
				else:
					tm = 0.5
			e_timer[i] = tm


func _enemy_attack(ty: int, p: Vector2, dir: Vector2) -> void:
	match ty:
		Data.TROOPER:
			if shot_budget >= 1.0:
				shot_budget -= 1.0
				_ebullet(p, dir * 230.0, 5.0, 5.0)
				_muzzle(p + dir * 18.0, dir, Color(1.0, 0.5, 0.2), 8.0)
		Data.GRENADIER:
			_telegraph(0, player + Vector2(randf_range(-30.0, 30.0), randf_range(-30.0, 30.0)), Vector2(58.0, 0.0), 1.0, 12.0)
			telegraphs[telegraphs.size() - 1].append(p)
		Data.ELITE:
			for k in 9:
				_ebullet(p, dir.rotated(deg_to_rad(-40.0 + k * 10.0)) * 260.0, 6.0, 6.0)
			_muzzle(p + dir * 30.0, dir, Color(1.0, 0.4, 0.15), 18.0)
		Data.TANK:
			_telegraph(1, p, p + dir * 760.0, 0.8, 16.0)
		Data.HELI:
			for k in 3:
				_ebullet(p, dir.rotated(deg_to_rad(-12.0 + k * 12.0)) * 300.0, 5.0, 6.0)
				_vfx(p, dir.rotated(randf_range(-0.6, 0.6)) * -40.0, 0.7, 5.0, 14.0, Color(0.6, 0.6, 0.6, 0.45), Color(0.3, 0.3, 0.3, 0.0), false)
			_muzzle(p + dir * 20.0, dir, Color(1.0, 0.6, 0.25), 12.0)


func _ebullet(p: Vector2, vel: Vector2, dmg: float, rad: float) -> void:
	if b_count >= EB_CAP:
		return
	b_pos[b_count] = p
	b_vel[b_count] = vel
	b_life[b_count] = 3.0
	b_dmg[b_count] = dmg
	b_rad[b_count] = rad
	b_count += 1


func _telegraph(kind: int, start: Vector2, end: Vector2, time: float, dmg: float) -> void:
	telegraphs.append([kind, start, end, time, time, dmg])


func _damage(j: int, amount: float, from: Vector2, force_crit: bool) -> void:
	var ty := e_type[j]
	var a := amount * dmg_mult
	var crit := force_crit or randf() < crit_chance
	if crit:
		a *= crit_mult
	if ty == Data.SHIELD and Vector2.from_angle(e_ang[j]).dot(from - e_pos[j]) > 0.0:
		a *= 0.25  # The shield blocks most damage from the front.
		if randf() < 0.3:
			_vfx(e_pos[j] + Vector2.from_angle(e_ang[j]) * 16.0, Vector2.ZERO, 0.1, 4.0, 14.0, Color(0.9, 0.95, 1.0, 0.9), Color(0.6, 0.8, 1.0, 0.0), true)
	var h := e_hp[j] - a
	e_hp[j] = h
	e_flash[j] = 0.06
	if ty <= Data.GRENADIER:
		# Light knockback for infantry, away from the hit.
		e_pos[j] += (e_pos[j] - from).normalized() * 5.0
	numbers.add(e_pos[j], a, crit)
	sfx.play("hit", randf_range(0.8, 1.3), -8.0)
	if h <= 0.0:
		_kill(j)


func _kill(j: int) -> void:
	var ty := e_type[j]
	var p := e_pos[j]
	kills += 1
	type_alive[ty] -= 1
	_gem(p, int(round(t_xp[ty] * hp_mult)))
	_add_combo()
	var big := ty >= Data.ELITE
	var coins := 0
	match ty:
		Data.ELITE:
			coins = 15
			_drop_pickup(p, randi() % 4)
		Data.TANK, Data.HELI:
			coins = 2 + randi() % 3
		_:
			coins = 1 if randf() < 0.08 else 0
	for k in coins:
		_coin(p + Vector2(randf_range(-20.0, 20.0), randf_range(-20.0, 20.0)))
	if not big and randf() < PICKUP_CHANCE:
		_drop_pickup(p, randi() % 4)
	sfx.play("big_boom" if big else "boom", randf_range(0.85, 1.15), -2.0 if big else -10.0)
	_sparks(p, int(fx.tier["sparks"]) * (3 if big else 1))
	_ring(p, 3.5 if big else 1.8)
	if big:
		_explosion(p, 95.0 if ty == Data.ELITE else 70.0, 1.3)
	elif randf() < 0.3:
		_vfx(p, Vector2(0.0, -20.0), 0.6, 6.0, 16.0, Color(0.35, 0.33, 0.32, 0.4), Color(0.2, 0.2, 0.2, 0.0), false)
	trauma = minf(trauma + (0.25 if big else 0.01), 0.6)
	if ty == Data.ELITE:
		_chest(p)
		hitstop = 0.08
	if explosive > 0:
		blasts.append([p, 40.0 + 6.0 * explosive, 6.0 * explosive])


## Removes enemies marked dead this frame (after all hit checks are done).
func _compact_enemies() -> void:
	var i := 0
	while i < e_count:
		if e_hp[i] > 0.0:
			i += 1
			continue
		e_count -= 1
		var last := e_count
		if i != last:
			e_type[i] = e_type[last]
			e_pos[i] = e_pos[last]
			e_ang[i] = e_ang[last]
			e_hp[i] = e_hp[last]
			e_flash[i] = e_flash[last]
			e_timer[i] = e_timer[last]
			e_halo[i] = e_halo[last]


func _nearest_in_radius(p: Vector2, r: float, exclude: Dictionary) -> int:
	var best := r * r
	var found := -1
	var x0 := clampi(int((p.x - r - grid_origin.x) / CELL), 0, grid_cols - 1)
	var x1 := clampi(int((p.x + r - grid_origin.x) / CELL), 0, grid_cols - 1)
	var y0 := clampi(int((p.y - r - grid_origin.y) / CELL), 0, grid_rows - 1)
	var y1 := clampi(int((p.y + r - grid_origin.y) / CELL), 0, grid_rows - 1)
	for gy in range(y0, y1 + 1):
		for gx in range(x0, x1 + 1):
			var j := cell_head[gy * grid_cols + gx]
			while j != -1:
				if e_hp[j] > 0.0 and not exclude.has(j):
					var d2 := p.distance_squared_to(e_pos[j])
					if d2 < best:
						best = d2
						found = j
				j = e_next[j]
	return found


## Damages every enemy (and the boss) within `radius` of `p`.
func _blast(p: Vector2, radius: float, dmg: float, force_crit: bool) -> void:
	var x0 := clampi(int((p.x - radius - 30.0 - grid_origin.x) / CELL), 0, grid_cols - 1)
	var x1 := clampi(int((p.x + radius + 30.0 - grid_origin.x) / CELL), 0, grid_cols - 1)
	var y0 := clampi(int((p.y - radius - 30.0 - grid_origin.y) / CELL), 0, grid_rows - 1)
	var y1 := clampi(int((p.y + radius + 30.0 - grid_origin.y) / CELL), 0, grid_rows - 1)
	for gy in range(y0, y1 + 1):
		for gx in range(x0, x1 + 1):
			var j := cell_head[gy * grid_cols + gx]
			while j != -1:
				if e_hp[j] > 0.0:
					var rr := radius + t_radius[e_type[j]]
					if p.distance_squared_to(e_pos[j]) < rr * rr:
						_damage(j, dmg, p, force_crit)
				j = e_next[j]
	if boss_on and p.distance_to(boss_pos) < radius + BOSS_RADIUS:
		_damage_boss(dmg, force_crit)
	_ring(p, radius / RING_SIZE * 1.1)
	_sparks(p, int(fx.tier["sparks"]))
	_explosion(p, radius, clampf(radius / 90.0, 0.4, 1.4))
	trauma = minf(trauma + 0.03 + radius * 0.0004, 0.6)
	sfx.play("boom", randf_range(0.7, 1.0), -6.0)


func _enemy_blast(p: Vector2, radius: float, dmg: float) -> void:
	if player.distance_to(p) < radius + PLAYER_RADIUS:
		_hurt(dmg)
	_ring(p, radius / RING_SIZE * 1.1)
	_sparks(p, 6)
	_explosion(p, radius * 0.9, 0.6)
	sfx.play("boom", randf_range(0.9, 1.1), -8.0)


# --- Boss -------------------------------------------------------------------

func _spawn_boss() -> void:
	boss_spawned = true
	boss_on = true
	boss_hp = BOSS_HP
	boss_pos = player + Vector2(0.0, -view.y * 0.55)
	boss_ang = PI * 0.5
	boss_mode = "move"
	boss_timer = 2.5
	boss_cycle = 0
	boss_flash = 0.0
	boss_node.visible = true
	hud.show_banner("BOSS: COLOSSUS SIEGE TANK")
	hud.set_boss(true, 1.0)
	sfx.play("alarm")


func _update_boss(dt: float) -> void:
	if not boss_on:
		return
	var to := player - boss_pos
	var d := to.length()
	var dir := to / maxf(d, 0.001)
	var phase2 := boss_hp < BOSS_HP * 0.5
	boss_timer -= dt
	match boss_mode:
		"move":
			boss_pos += dir * 45.0 * dt
			boss_ang = lerp_angle(boss_ang, dir.angle(), minf(1.0, dt * 1.5))
			if boss_timer <= 0.0:
				boss_cycle += 1
				match boss_cycle % 3:
					1:
						_boss_sweep(phase2)
						boss_timer = 2.4 if phase2 else 3.2
					2:
						_boss_mines(phase2)
						boss_timer = 2.6 if phase2 else 3.4
					_:
						boss_mode = "aim"
						boss_dir = dir
						boss_timer = 1.0
						_telegraph(3, boss_pos, boss_pos + dir * 900.0, 1.0, 0.0)
		"aim":
			if boss_timer <= 0.0:
				boss_mode = "charge"
				boss_timer = 0.9
		"charge":
			boss_pos += boss_dir * 900.0 * dt
			boss_ang = boss_dir.angle()
			if boss_timer <= 0.0:
				boss_mode = "move"
				boss_timer = 1.6
	if d < BOSS_RADIUS + PLAYER_RADIUS:
		_hurt(30.0)
	boss_flash = maxf(boss_flash - dt, 0.0)
	boss_halo_cd -= dt
	boss_node.position = boss_pos
	boss_node.rotation = boss_ang
	boss_node.modulate = Color(2.0, 2.0, 2.0) if boss_flash > 0.0 else Color.WHITE
	for turret in boss_turret_nodes:
		turret.rotation = dir.angle() - boss_ang
	hud.set_boss(true, boss_hp / BOSS_HP)


func _boss_turret_pos(k: int) -> Vector2:
	return boss_pos + (BOSS_TURRETS[k] as Vector2).rotated(boss_ang)


func _boss_sweep(phase2: bool) -> void:
	var n := 7 if phase2 else 5
	for k in BOSS_TURRETS.size():
		var from := _boss_turret_pos(k)
		var dir := (player - from).normalized()
		for s in n:
			var a := deg_to_rad(-30.0 + 60.0 * s / (n - 1))
			_ebullet(from, dir.rotated(a) * 280.0, 10.0, 7.0)
	trauma = minf(trauma + 0.2, 0.6)


func _boss_mines(phase2: bool) -> void:
	var n := 10 if phase2 else 7
	for k in n:
		var spot := player + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 220.0)
		_telegraph(0, spot, Vector2(64.0, 0.0), 1.2, 16.0)


func _damage_boss(amount: float, force_crit: bool) -> void:
	if not boss_on:
		return
	var a := amount * dmg_mult
	if force_crit or randf() < crit_chance:
		a *= crit_mult
	boss_hp -= a
	boss_flash = 0.05
	if boss_hp <= 0.0:
		_boss_killed()


func _boss_killed() -> void:
	boss_on = false
	boss_dead_t = t
	boss_node.visible = false
	kills += 1
	b_count = 0
	telegraphs.clear()
	for k in 8:
		var p := boss_pos + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 90.0)
		_ring(p, randf_range(3.0, 8.0))
		_sparks(p, int(fx.tier["sparks"]) * 2)
		_explosion(p, randf_range(90.0, 160.0), 1.6)
	trauma = 1.0
	hitstop = 0.2
	hud.set_boss(false, 0.0)
	hud.show_banner("COLOSSUS DESTROYED")
	hud.flash(Color(1, 1, 1, 0.8))
	sfx.play("big_boom")
	for k in 60:
		_coin(boss_pos + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 140.0))


# --- Weapons ----------------------------------------------------------------

func _target() -> Vector2:
	var has := nearest >= 0 and e_hp[nearest] > 0.0
	var p := e_pos[nearest] if has else player + facing * 300.0
	if boss_on and (not has or boss_pos.distance_squared_to(player) < p.distance_squared_to(player)):
		p = boss_pos
	return p


func _has_target() -> bool:
	return nearest >= 0 or boss_on


func _fire_weapons(dt: float) -> void:
	for id in weapons:
		var st: Dictionary = w_stats[id]
		if not st.has("cd"):
			continue
		var tm: float = float(w_timer.get(id, 0.0)) - dt * fire_rate
		if tm <= 0.0:
			tm = tm + float(st["cd"]) if _fire(id, st) else 0.1
		w_timer[id] = tm


func _fire(id: String, st: Dictionary) -> bool:
	match id:
		"rifle":
			if not _has_target():
				return false
			var a0 := (_target() - player).angle()
			var n: int = st["count"]
			sfx.play("shot", randf_range(0.9, 1.1), -14.0)
			for k in n:
				var a: float = a0 + (k - (n - 1) * 0.5) * float(st["spread"])
				_shot(Vector2.from_angle(a) * float(st["speed"]), st["dmg"], st["pierce"], st["life"], STORM_COLOR if evolved.has("rifle") else RIFLE_COLOR)
			_muzzle(player + Vector2.from_angle(a0) * 18.0, Vector2.from_angle(a0), RIFLE_COLOR, 10.0)
		"scatter":
			if not _has_target():
				return false
			var a0 := (_target() - player).angle()
			var cone: float = st["spread"]
			for k in int(st["count"]):
				var a := a0 + randf_range(-cone * 0.5, cone * 0.5)
				_shot(Vector2.from_angle(a) * float(st["speed"]) * randf_range(0.85, 1.1), st["dmg"], st["pierce"], st["life"], SCATTER_COLOR)
			_muzzle(player + Vector2.from_angle(a0) * 20.0, Vector2.from_angle(a0), SCATTER_COLOR, 16.0)
			sfx.play("boom", 1.8, -12.0)
		"rockets":
			if not _has_target():
				return false
			for k in int(st["count"]):
				_rocket(facing.rotated(randf_range(-1.4, 1.4)) * 260.0, st["dmg"], st["radius"], st["crit"])
		"tesla":
			return _tesla(st)
		"airstrike":
			if not _has_target():
				return false
			_airstrike(st)
	return true


func _shot(vel: Vector2, dmg: float, pierce: int, life: float, color: Color) -> void:
	if s_count >= SHOT_CAP:
		return
	s_col[s_count] = color
	s_pos[s_count] = player
	s_vel[s_count] = vel
	s_life[s_count] = life
	s_dmg[s_count] = dmg
	s_pierce[s_count] = pierce
	s_last[s_count] = -1
	s_count += 1


func _remove_shot(i: int) -> void:
	s_count -= 1
	s_pos[i] = s_pos[s_count]
	s_vel[i] = s_vel[s_count]
	s_life[i] = s_life[s_count]
	s_dmg[i] = s_dmg[s_count]
	s_pierce[i] = s_pierce[s_count]
	s_last[i] = s_last[s_count]
	s_col[i] = s_col[s_count]


func _update_shots(dt: float) -> void:
	var trails: bool = fx.tier["trails"]
	var gx0 := grid_origin.x
	var gy0 := grid_origin.y
	var boss_r2 := (BOSS_RADIUS + 4.0) * (BOSS_RADIUS + 4.0)
	var i := 0
	while i < s_count:
		var life := s_life[i] - dt
		var p := s_pos[i] + s_vel[i] * dt
		if life <= 0.0:
			_remove_shot(i)
			continue
		s_pos[i] = p
		s_life[i] = life
		if boss_on and p.distance_squared_to(boss_pos) < boss_r2:
			_damage_boss(s_dmg[i], false)
			_remove_shot(i)
			continue
		var removed := false
		var cx := int((p.x - gx0) / CELL)
		var cy := int((p.y - gy0) / CELL)
		if cx >= 0 and cy >= 0 and cx < grid_cols and cy < grid_rows:
			for gy in range(maxi(cy - 1, 0), mini(cy + 2, grid_rows)):
				for gx in range(maxi(cx - 1, 0), mini(cx + 2, grid_cols)):
					var j := cell_head[gy * grid_cols + gx]
					while j != -1:
						if e_hp[j] > 0.0 and j != s_last[i]:
							var rr := t_radius[e_type[j]] + 4.0
							if p.distance_squared_to(e_pos[j]) < rr * rr:
								_damage(j, s_dmg[i], p, false)
								s_last[i] = j
								if s_pierce[i] <= 0:
									removed = true
									break
								s_pierce[i] -= 1
						j = e_next[j]
					if removed:
						break
				if removed:
					break
		if removed:
			_remove_shot(i)
			continue
		var o := i * STRIDE
		s_buf[o + 3] = p.x
		s_buf[o + 7] = p.y
		var sc := s_col[i]
		s_buf[o + 8] = sc.r
		s_buf[o + 9] = sc.g
		s_buf[o + 10] = sc.b
		if trails:
			var d := s_vel[i].normalized()
			s_buf[o] = d.x * 3.0
			s_buf[o + 1] = -d.y
			s_buf[o + 4] = d.y * 3.0
			s_buf[o + 5] = d.x
		i += 1


func _rocket(vel: Vector2, dmg: float, radius: float, crit: bool) -> void:
	if k_count >= ROCKET_CAP:
		return
	k_pos[k_count] = player
	k_vel[k_count] = vel
	k_aim[k_count] = _target()
	k_life[k_count] = 2.5
	k_dmg[k_count] = dmg
	k_rad[k_count] = radius
	k_retarget[k_count] = randf() * 0.15
	k_crit[k_count] = 1 if crit else 0
	k_count += 1


func _remove_rocket(i: int) -> void:
	k_count -= 1
	k_pos[i] = k_pos[k_count]
	k_vel[i] = k_vel[k_count]
	k_aim[i] = k_aim[k_count]
	k_life[i] = k_life[k_count]
	k_dmg[i] = k_dmg[k_count]
	k_rad[i] = k_rad[k_count]
	k_retarget[i] = k_retarget[k_count]
	k_crit[i] = k_crit[k_count]


## Nearest of a few random enemies to `p`: cheap homing that still spreads
## missiles across the crowd.
func _random_target_near(p: Vector2) -> Vector2:
	var best := INF
	var out := _target()
	if e_count > 0:
		for k in 16:
			var j := randi() % e_count
			if e_hp[j] <= 0.0:
				continue
			var d2 := p.distance_squared_to(e_pos[j])
			if d2 < best:
				best = d2
				out = e_pos[j]
	if boss_on and p.distance_squared_to(boss_pos) < best:
		out = boss_pos
	return out


func _update_rockets(dt: float) -> void:
	var gx0 := grid_origin.x
	var gy0 := grid_origin.y
	var i := 0
	while i < k_count:
		var life := k_life[i] - dt
		var p := k_pos[i]
		if life <= 0.0:
			_blast(p, k_rad[i], k_dmg[i], k_crit[i] == 1)
			_remove_rocket(i)
			continue
		k_life[i] = life
		var rt := k_retarget[i] - dt
		if rt <= 0.0:
			k_aim[i] = _random_target_near(p)
			rt = 0.15
		k_retarget[i] = rt
		var v := k_vel[i].lerp((k_aim[i] - p).normalized() * 470.0, minf(1.0, dt * 4.0))
		p += v * dt
		if randf() < 0.5:
			_vfx(p - v.normalized() * 8.0, -v * 0.05, 0.45, 3.0, 10.0, Color(0.7, 0.7, 0.7, 0.4), Color(0.4, 0.4, 0.4, 0.0), false)
		k_vel[i] = v
		k_pos[i] = p
		var hit := boss_on and p.distance_to(boss_pos) < BOSS_RADIUS + 7.0
		var cx := int((p.x - gx0) / CELL)
		var cy := int((p.y - gy0) / CELL)
		if not hit and cx >= 0 and cy >= 0 and cx < grid_cols and cy < grid_rows:
			for gy in range(maxi(cy - 1, 0), mini(cy + 2, grid_rows)):
				for gx in range(maxi(cx - 1, 0), mini(cx + 2, grid_cols)):
					var j := cell_head[gy * grid_cols + gx]
					while j != -1 and not hit:
						if e_hp[j] > 0.0:
							var rr := t_radius[e_type[j]] + 7.0
							hit = p.distance_squared_to(e_pos[j]) < rr * rr
						j = e_next[j]
		if hit:
			_blast(p, k_rad[i], k_dmg[i], k_crit[i] == 1)
			_remove_rocket(i)
			continue
		var o := i * STRIDE
		var d := v.normalized()
		k_buf[o] = d.x * 2.2
		k_buf[o + 1] = -d.y
		k_buf[o + 3] = p.x
		k_buf[o + 4] = d.y * 2.2
		k_buf[o + 5] = d.x
		k_buf[o + 7] = p.y
		i += 1


func _update_halo(dt: float) -> void:
	bl_count = 0
	if not weapons.has("halo"):
		return
	var st: Dictionary = w_stats["halo"]
	var spin: float = st["speed"]
	if st["evolved"]:
		spin *= 1.0 + move_vec.length() * 1.5
	halo_angle += spin * dt
	var n := mini(int(st["count"]), BLADE_CAP)
	var rad: float = st["radius"]
	var dmg: float = st["dmg"]
	for k in n:
		var p := player + Vector2.from_angle(halo_angle + TAU * k / n) * rad
		var cx := int((p.x - grid_origin.x) / CELL)
		var cy := int((p.y - grid_origin.y) / CELL)
		if cx >= 0 and cy >= 0 and cx < grid_cols and cy < grid_rows:
			for gy in range(maxi(cy - 1, 0), mini(cy + 2, grid_rows)):
				for gx in range(maxi(cx - 1, 0), mini(cx + 2, grid_cols)):
					var j := cell_head[gy * grid_cols + gx]
					while j != -1:
						if e_hp[j] > 0.0 and e_halo[j] <= 0.0:
							var rr := t_radius[e_type[j]] + 16.0
							if p.distance_squared_to(e_pos[j]) < rr * rr:
								_damage(j, dmg, player, false)
								e_halo[j] = 0.3
						j = e_next[j]
		if boss_on and boss_halo_cd <= 0.0 and p.distance_to(boss_pos) < BOSS_RADIUS + 16.0:
			_damage_boss(dmg, false)
			boss_halo_cd = 0.15
		var o := k * STRIDE
		var c := cos(t * 14.0)
		var s := sin(t * 14.0)
		bl_buf[o] = c
		bl_buf[o + 1] = -s
		bl_buf[o + 3] = p.x
		bl_buf[o + 4] = s
		bl_buf[o + 5] = c
		bl_buf[o + 7] = p.y
	bl_count = n


func _tesla(st: Dictionary) -> bool:
	var reach: float = st["range"]
	var points := PackedVector2Array([player])
	if nearest < 0 or e_pos[nearest].distance_to(player) > reach:
		if boss_on and boss_pos.distance_to(player) < reach + BOSS_RADIUS:
			_damage_boss(st["dmg"], false)
			points.append(boss_pos)
			_bolt(points)
			return true
		return false
	var hit := {}
	var cur := nearest
	for k in int(st["chains"]):
		var p := e_pos[cur]
		points.append(p)
		_damage(cur, st["dmg"], player, false)
		hit[cur] = true
		cur = _nearest_in_radius(p, st["jump"], hit)
		if cur < 0:
			break
	_bolt(points)
	return true


## Turns a path into a jagged lightning bolt.
func _bolt(points: PackedVector2Array) -> void:
	var jagged := PackedVector2Array()
	for k in points.size() - 1:
		var a := points[k]
		var b := points[k + 1]
		var side := (b - a).orthogonal().normalized()
		jagged.append(a)
		for s in range(1, 4):
			jagged.append(a.lerp(b, s / 4.0) + side * randf_range(-12.0, 12.0))
	jagged.append(points[points.size() - 1])
	bolts.append([jagged, 0.15])
	sfx.play("zap", randf_range(0.9, 1.2), -6.0)


func _airstrike(st: Dictionary) -> void:
	var center := _target()
	var dir := Vector2.from_angle(randf() * TAU)
	var length := 900.0
	var start := center - dir * length * 0.5
	var n: int = st["bombs"]
	_telegraph(2, start, start + dir * length, 0.5, 0.0)
	for k in n:
		bombs.append([start + dir * length * (k + 0.5) / n, 0.5 + 0.06 * k, st["radius"], st["dmg"]])


func _update_bombs(dt: float) -> void:
	var k := bombs.size() - 1
	while k >= 0:
		var bomb: Array = bombs[k]
		bomb[1] = float(bomb[1]) - dt
		if float(bomb[1]) <= 0.0:
			_blast(bomb[0], bomb[2], bomb[3], false)
			bombs.remove_at(k)
		k -= 1
	# Explosive Rounds blasts, capped per frame so chain reactions don't spike.
	var queued := blasts
	blasts = []
	for n in queued.size():
		if n < 30:
			var b: Array = queued[n]
			_blast(b[0], b[1], b[2], false)
		else:
			blasts.append(queued[n])
	var m := bolts.size() - 1
	while m >= 0:
		var bolt: Array = bolts[m]
		bolt[1] = float(bolt[1]) - dt
		if float(bolt[1]) <= 0.0:
			bolts.remove_at(m)
		m -= 1


func _update_enemy_bullets(dt: float) -> void:
	var i := 0
	while i < b_count:
		var life := b_life[i] - dt
		var p := b_pos[i] + b_vel[i] * dt
		var rr := b_rad[i] + PLAYER_RADIUS
		var hit := p.distance_squared_to(player) < rr * rr
		if life <= 0.0 or hit:
			if hit:
				_hurt(b_dmg[i])
			b_count -= 1
			b_pos[i] = b_pos[b_count]
			b_vel[i] = b_vel[b_count]
			b_life[i] = b_life[b_count]
			b_dmg[i] = b_dmg[b_count]
			b_rad[i] = b_rad[b_count]
			continue
		b_pos[i] = p
		b_life[i] = life
		var o := i * STRIDE
		var s := b_rad[i] / 6.0
		b_buf[o] = s
		b_buf[o + 5] = s
		b_buf[o + 3] = p.x
		b_buf[o + 7] = p.y
		i += 1


func _update_telegraphs(dt: float) -> void:
	var k := telegraphs.size() - 1
	while k >= 0:
		var tg: Array = telegraphs[k]
		tg[3] = float(tg[3]) - dt
		if float(tg[3]) <= 0.0:
			match int(tg[0]):
				0:
					_enemy_blast(tg[1], (tg[2] as Vector2).x, tg[5])
				1:
					var start: Vector2 = tg[1]
					var aim := ((tg[2] as Vector2) - start).normalized()
					_ebullet(start + aim * 40.0, aim * 650.0, tg[5], 9.0)
					_muzzle(start + aim * 44.0, aim, Color(1.0, 0.7, 0.3), 26.0)
					for _j in 4:
						_vfx(start + aim * 44.0, aim.rotated(randf_range(-0.8, 0.8)) * randf_range(20.0, 70.0), 0.9, 10.0, 26.0, Color(0.5, 0.48, 0.45, 0.5), Color(0.25, 0.25, 0.25, 0.0), false)
					sfx.play("boom", 1.4, -8.0)
			telegraphs.remove_at(k)
		k -= 1


# --- Pickups and progression -----------------------------------------------

func _gem(p: Vector2, value: int) -> void:
	if g_count < GEM_CAP:
		g_pos[g_count] = p
		g_val[g_count] = value
		g_mag[g_count] = 0
		g_count += 1
	elif g_count > 0:
		g_val[randi() % g_count] += value


func _chest(p: Vector2) -> void:
	if c_count < CHEST_CAP:
		c_pos[c_count] = p
		c_count += 1


func _update_pickups(dt: float) -> void:
	var pr2 := pickup * pickup
	var i := 0
	while i < g_count:
		var p := g_pos[i]
		var to := player - p
		var d2 := to.length_squared()
		if g_mag[i] == 0 and (d2 < pr2 or magnet_all):
			g_mag[i] = 1
		if g_mag[i] == 1:
			var d := sqrt(d2)
			if d < PLAYER_RADIUS + 10.0:
				_gain_xp(g_val[i])
				sfx.play("gem", 1.0 + minf(combo, 500) / 500.0, -10.0)
				g_count -= 1
				g_pos[i] = g_pos[g_count]
				g_val[i] = g_val[g_count]
				g_mag[i] = g_mag[g_count]
				continue
			p += to / maxf(d, 0.001) * minf(d, 900.0 * dt)
			g_pos[i] = p
		var o := i * STRIDE
		g_buf[o + 3] = p.x
		g_buf[o + 7] = p.y
		var val := g_val[i]
		var col := GEM_RED if val >= 25 else (GEM_GREEN if val >= 5 else GEM_BLUE)
		var gs := 1.5 if val >= 25 else (1.2 if val >= 5 else 1.0)
		g_buf[o] = gs
		g_buf[o + 5] = gs
		g_buf[o + 8] = col.r
		g_buf[o + 9] = col.g
		g_buf[o + 10] = col.b
		i += 1
	var k := 0
	while k < c_count:
		if c_pos[k].distance_to(player) < 40.0:
			c_count -= 1
			c_pos[k] = c_pos[c_count]
			_open_chest()
			continue
		var o := k * STRIDE
		c_buf[o + 3] = c_pos[k].x
		c_buf[o + 7] = c_pos[k].y + sin(t * 4.0) * 4.0
		k += 1


func _xp_need(l: int) -> float:
	return 4.0 + 1.6 * pow(float(l), 1.3)


func _gain_xp(value: int) -> void:
	xp += value * (1.0 + minf(combo, 1000) / 2000.0)
	while xp >= xp_need:
		xp -= xp_need
		level += 1
		xp_need = _xp_need(level)
		pending_levels += 1


## Treasure chest: a slot-machine roll for 1, 3 or 5 rewards. An evolution
## that is ready always comes first.
func _open_chest() -> void:
	if state != State.PLAYING:
		return
	var size: int = Data.CHEST_SIZES[_pick(PackedFloat32Array(Data.CHEST_ODDS))]
	chest_rewards = []
	var taken := {}
	var ready := _evolution_ready()
	if ready != "":
		chest_rewards.append(["evolve", ready])
		taken[ready] = true
	while chest_rewards.size() < size:
		var pool := []
		for id in weapons:
			if int(weapons[id]) < MAX_LEVEL and not taken.has(id):
				pool.append(["weapon", id])
		for id in powers:
			if int(powers[id]) < MAX_LEVEL and not taken.has(id):
				pool.append(["power", id])
		if pool.is_empty():
			chest_rewards.append(["gold", "gold"])
		else:
			var pick: Array = pool[randi() % pool.size()]
			chest_rewards.append(pick)
			taken[pick[1]] = true
	var bonus := 25 * size
	gold += bonus
	state = State.CHEST
	joy_on = false
	joy_vec = Vector2.ZERO
	hud.set_joystick(false, Vector2.ZERO, Vector2.ZERO)
	var names := []
	for r in chest_rewards:
		names.append(_reward_name(r))
	var all_names := []
	for id in Data.NAMES:
		all_names.append(Data.NAMES[id])
	hud.show_chest(names, all_names, bonus)
	sfx.play("fanfare")
	if autoplay and bot_cards:
		call_deferred("_on_chest_collected")


func _reward_name(r: Array) -> String:
	match String(r[0]):
		"evolve":
			return "EVOLUTION: " + String(Data.EVOLUTIONS[r[1]]["name"])
		"gold":
			return "+50 Gold"
	var lvl: int = (weapons if r[0] == "weapon" else powers).get(r[1], 0)
	return "%s  Lv %d → %d" % [Data.NAMES[r[1]], lvl, lvl + 1]


func _on_chest_collected() -> void:
	if state != State.CHEST:
		return
	for r in chest_rewards:
		match String(r[0]):
			"evolve":
				_evolve(r[1])
			"weapon":
				weapons[r[1]] = mini(MAX_LEVEL, int(weapons[r[1]]) + 1)
			"power":
				powers[r[1]] = mini(MAX_LEVEL, int(powers[r[1]]) + 1)
			"gold":
				gold += 50
	chest_rewards = []
	_recalc()
	state = State.PLAYING
	hud.show_play()


func _evolution_ready() -> String:
	for id in Data.EVOLUTIONS:
		var pair: String = Data.EVOLUTIONS[id]["power"]
		if int(weapons.get(id, 0)) >= MAX_LEVEL and powers.has(pair) and not evolved.has(id):
			return id
	return ""


func _evolve(id: String) -> void:
	evolved[id] = true
	weapons[id] = MAX_LEVEL
	_recalc()
	hud.show_banner("EVOLUTION: " + String(Data.EVOLUTIONS[id]["name"]), Color(1.0, 0.8, 0.25))
	sfx.play("powerup")
	# The biggest moment in a run: a gold blast that clears the area.
	_power_moment(2.2, Color(1.0, 0.8, 0.25))
	_damage_around(player, 420.0, 600.0)
	for k in 6:
		_explosion(player + Vector2.from_angle(TAU * k / 6.0) * 180.0, 110.0, 1.5)
	trauma = minf(trauma + 0.5, 1.0)
	hitstop = 0.12
	_ring(player, 10.0)


func _recalc() -> void:
	var old_max := max_hp
	var titan: int = powers.get("titan", 0)
	var mag: int = powers.get("magnet", 0)
	var cr: int = powers.get("crit", 0)
	fire_rate = 1.0 + 0.08 * int(powers.get("overclock", 0))
	max_hp = PLAYER_HP + 20.0 * titan
	armor = titan
	if max_hp > old_max:
		hp += max_hp - old_max
	pickup = PICKUP * (1.0 + 0.3 * mag)
	magnet_all = mag >= MAX_LEVEL
	speed = 210.0 * (1.0 + 0.07 * int(powers.get("adrenaline", 0)))
	explosive = powers.get("explosive", 0)
	crit_chance = 0.05 + 0.05 * cr
	crit_mult = 2.0 + 0.1 * cr
	dmg_mult = 1.0 + bonus_dmg
	for id in weapons:
		w_stats[id] = Data.weapon_stats(id, weapons[id], evolved.has(id))
	hud.set_build(_build_text())


# --- Level-up cards ---------------------------------------------------------

func _open_cards(chest: bool) -> void:
	state = State.CARDS
	chest_cards = chest
	joy_on = false
	joy_vec = Vector2.ZERO
	hud.set_joystick(false, Vector2.ZERO, Vector2.ZERO)
	offers = _make_offers(2, chest, [])
	_show_cards()
	sfx.play("level")
	if autoplay and bot_cards:
		call_deferred("_bot_pick")


func _show_cards() -> void:
	var infos := []
	for o in offers:
		infos.append(_offer_info(o))
	hud.show_cards(infos, third_left, reroll_left, chest_cards)


func _make_offers(n: int, chest: bool, skip: Array) -> Array:
	var pool := []
	for id in Data.WEAPON_IDS:
		_add_candidate(pool, "weapon", id, int(weapons.get(id, 0)), weapons.size())
	for id in Data.POWER_IDS:
		_add_candidate(pool, "power", id, int(powers.get(id, 0)), powers.size())
	pool.shuffle()
	var out := []
	var used := {}
	for id in skip:
		used[id] = true
	# Once a build has started, one card always deepens something you own, so
	# runs don't end with nine items at level 2.
	if weapons.size() + powers.size() >= 3:
		for entry in pool:
			var owned: Dictionary = weapons if entry[0] == "weapon" else powers
			if owned.has(entry[1]) and not used.has(entry[1]):
				used[entry[1]] = true
				out.append(_offer(entry[0], entry[1], _roll_rarity(chest)))
				break
	for entry in pool:
		if out.size() >= n:
			break
		if used.has(entry[1]):
			continue
		used[entry[1]] = true
		out.append(_offer(entry[0], entry[1], _roll_rarity(chest)))
	out.shuffle()
	if out.size() < n:
		out.append({"kind": "heal", "id": "heal", "rarity": 0, "levels": 0, "evolve": false})
	while out.size() < n:
		out.append({"kind": "gold", "id": "gold", "rarity": 0, "levels": 0, "evolve": false})
	return out


func _add_candidate(pool: Array, kind: String, id: String, lvl: int, owned: int) -> void:
	if lvl >= MAX_LEVEL or (lvl == 0 and owned >= MAX_SLOTS):
		return
	pool.append([kind, id])
	if lvl >= 1:
		pool.append([kind, id])  # Owned items come up more often, so builds come together.
	if lvl >= 3:
		pool.append([kind, id])


func _roll_rarity(chest: bool) -> int:
	var w := Data.rarity_weights(t)
	if chest:
		w[0] = 0.0
		w[1] = 0.0
		w[2] = maxf(w[2], 1.0)
	return _pick(w)


func _offer(kind: String, id: String, rarity: int) -> Dictionary:
	var o := {"kind": kind, "id": id, "rarity": rarity, "levels": Data.RARITY_LEVELS[rarity], "evolve": false}
	if rarity == 3 and kind == "weapon" and Data.EVOLUTIONS.has(id):
		var pair: String = Data.EVOLUTIONS[id]["power"]
		if powers.has(pair) and not evolved.has(id):
			o["evolve"] = true
	return o


func _offer_info(o: Dictionary) -> Dictionary:
	var rarity: int = o["rarity"]
	var info := {"color": Data.RARITY_COLORS[rarity], "title": "", "tag": "", "desc": ""}
	var id: String = o["id"]
	match String(o["kind"]):
		"weapon", "power":
			var cur: int = (weapons if o["kind"] == "weapon" else powers).get(id, 0)
			if o["evolve"]:
				info["title"] = "EVOLVE: " + String(Data.EVOLUTIONS[id]["name"])
				info["tag"] = "Legendary"
				info["desc"] = Data.EVOLUTIONS[id]["desc"]
			else:
				var to := mini(MAX_LEVEL, cur + int(o["levels"]))
				info["title"] = Data.NAMES[id]
				info["tag"] = "%s · %s" % [Data.RARITY_NAMES[rarity], "NEW" if cur == 0 else "Lv %d → %d" % [cur, to]]
				var desc: String = Data.DESCS[id]
				if rarity == 1:
					desc += " Bonus: +4% damage to everything."
				if o["kind"] == "weapon" and Data.EVOLUTIONS.has(id):
					desc += " Evolves with %s." % Data.NAMES[Data.EVOLUTIONS[id]["power"]]
				info["desc"] = desc
		"heal":
			info["title"] = "Field Medkit"
			info["desc"] = "Restore 40% of your HP."
		"gold":
			info["title"] = "Supply Drop"
			info["desc"] = "+3% damage to everything."
	return info


func _on_card(index: int) -> void:
	if state != State.CARDS or index < 0 or index >= offers.size():
		return
	var o: Dictionary = offers[index]
	var id: String = o["id"]
	match String(o["kind"]):
		"weapon":
			if o["evolve"]:
				_evolve(id)
			else:
				weapons[id] = mini(MAX_LEVEL, int(weapons.get(id, 0)) + int(o["levels"]))
		"power":
			powers[id] = mini(MAX_LEVEL, int(powers.get(id, 0)) + int(o["levels"]))
		"heal":
			hp = minf(max_hp, hp + max_hp * 0.4)
		"gold":
			bonus_dmg += 0.03
	if int(o["rarity"]) == 1 and (o["kind"] == "weapon" or o["kind"] == "power"):
		bonus_dmg += Data.RARE_BONUS
	_recalc()
	var rarity: int = o["rarity"]
	if o["kind"] == "weapon" or o["kind"] == "power":
		var lvl: int = (weapons if o["kind"] == "weapon" else powers).get(id, 0)
		if not o["evolve"]:
			hud.show_banner("%s  Lv %d" % [Data.NAMES[id], lvl], Data.RARITY_COLORS[rarity])
		_power_moment([0.35, 0.6, 0.9, 1.3][rarity] + lvl * 0.05, Data.RARITY_COLORS[rarity])
	if chest_cards:
		chest_cards = false
	else:
		pending_levels -= 1
	if pending_levels > 0:
		offers = _make_offers(2, false, [])
		_show_cards()
		if autoplay and bot_cards:
			call_deferred("_bot_pick")
	else:
		state = State.PLAYING
		hud.show_play()


func _on_third() -> void:
	if state != State.CARDS or third_left <= 0 or offers.size() >= 3:
		return
	third_left -= 1
	var skip := []
	for o in offers:
		skip.append(o["id"])
	var extra := _make_offers(1, chest_cards, skip)
	offers.append(extra[0])
	_show_cards()


func _on_reroll() -> void:
	if state != State.CARDS or reroll_left <= 0:
		return
	reroll_left -= 1
	offers = _make_offers(offers.size(), chest_cards, [])
	_show_cards()


# --- Effects and rendering --------------------------------------------------

func _sparks(at: Vector2, n: int) -> void:
	for k in n:
		if p_count >= p_cap:
			return
		p_pos[p_count] = at
		p_vel[p_count] = Vector2.from_angle(randf() * TAU) * randf_range(80.0, 280.0)
		p_life[p_count] = SPARK_LIFE
		p_count += 1


func _ring(at: Vector2, size: float) -> void:
	if r_count < r_cap:
		r_pos[r_count] = at
		r_life[r_count] = RING_LIFE
		r_size[r_count] = size
		r_count += 1


func _update_sparks(dt: float) -> void:
	var drag := maxf(0.0, 1.0 - 3.0 * dt)
	var stretch_on: bool = fx.tier["trails"]
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
		var k := life / SPARK_LIFE
		var o := i * STRIDE
		if stretch_on:
			var sp := v.length()
			var u := v / maxf(sp, 0.001)
			var len := k * (1.0 + sp * 0.012)
			var wid := k * 0.7
			p_buf[o] = u.x * len
			p_buf[o + 1] = -u.y * wid
			p_buf[o + 4] = u.y * len
			p_buf[o + 5] = u.x * wid
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
			r_size[i] = r_size[r_count]
			continue
		r_life[i] = life
		var k := life / RING_LIFE
		var s := lerpf(r_size[i], 0.3, k)
		var o := i * STRIDE
		r_buf[o] = s
		r_buf[o + 5] = s
		r_buf[o + 3] = r_pos[i].x
		r_buf[o + 7] = r_pos[i].y
		r_buf[o + 11] = k * 0.8
		i += 1


func _render_units() -> void:
	unit_n.fill(0)
	for i in e_count:
		var ty := e_type[i]
		var p := e_pos[i]
		var tint := Color(1.9, 1.9, 1.9) if e_flash[i] > 0.0 else (Color(0.55, 0.85, 1.4) if freeze_t > 0.0 else Color.WHITE)
		var spin := 0.0 if freeze_t > 0.0 else t * 25.0
		match ty:
			Data.TANK:
				_put_unit(Art.TANK, p, e_ang[i], t_size[ty], tint)
				_put_unit(Art.TURRET, p, (player - p).angle(), t_size[ty], tint)
			Data.HELI:
				_put_unit(Art.HELI, p, e_ang[i], t_size[ty], tint)
				_put_unit(Art.ROTOR, p, spin + i, t_size[ty] * 1.15, tint)
			_:
				_put_unit(ty, p, e_ang[i], t_size[ty], tint)


func _put_unit(cell: int, p: Vector2, ang: float, size: float, tint: Color) -> void:
	var n := unit_n[cell]
	if n >= unit_cap[cell]:
		return
	unit_n[cell] = n + 1
	var o := (unit_off[cell] + n) * STRIDE
	var c := cos(ang) * size
	var s := sin(ang) * size
	u_buf[o] = c
	u_buf[o + 1] = -s
	u_buf[o + 3] = p.x
	u_buf[o + 4] = s
	u_buf[o + 5] = c
	u_buf[o + 7] = p.y
	u_buf[o + 8] = tint.r
	u_buf[o + 9] = tint.g
	u_buf[o + 10] = tint.b


func _upload() -> void:
	for c in unit_mms.size():
		var mm: MultiMesh = unit_mms[c]
		mm.visible_instance_count = unit_n[c]
		var from := unit_off[c] * STRIDE
		RenderingServer.multimesh_set_buffer(mm.get_rid(), u_buf.slice(from, from + unit_cap[c] * STRIDE))
	shot_mm.visible_instance_count = s_count
	RenderingServer.multimesh_set_buffer(shot_mm.get_rid(), s_buf)
	rocket_mm.visible_instance_count = k_count
	RenderingServer.multimesh_set_buffer(rocket_mm.get_rid(), k_buf)
	eb_mm.visible_instance_count = b_count
	RenderingServer.multimesh_set_buffer(eb_mm.get_rid(), b_buf)
	gem_mm.visible_instance_count = g_count
	RenderingServer.multimesh_set_buffer(gem_mm.get_rid(), g_buf)
	chest_mm.visible_instance_count = c_count
	RenderingServer.multimesh_set_buffer(chest_mm.get_rid(), c_buf)
	spark_mm.visible_instance_count = p_count
	RenderingServer.multimesh_set_buffer(spark_mm.get_rid(), p_buf)
	ring_mm.visible_instance_count = r_count
	if r_cap > 0:
		RenderingServer.multimesh_set_buffer(ring_mm.get_rid(), r_buf)
	blade_mm.visible_instance_count = bl_count
	RenderingServer.multimesh_set_buffer(blade_mm.get_rid(), bl_buf)
	coin_mm.visible_instance_count = co_count
	RenderingServer.multimesh_set_buffer(coin_mm.get_rid(), co_buf)
	fire_mm.visible_instance_count = fire_n
	RenderingServer.multimesh_set_buffer(fire_mm.get_rid(), fire_buf)
	smoke_mm.visible_instance_count = smoke_n
	RenderingServer.multimesh_set_buffer(smoke_mm.get_rid(), smoke_buf)
	decal_mm.visible_instance_count = d_count
	RenderingServer.multimesh_set_buffer(decal_mm.get_rid(), decal_buf)


# --- Explosions and power moments ------------------------------------------

func _vfx(p: Vector2, vel: Vector2, life: float, s0: float, s1: float, c0: Color, c1: Color, fire: bool) -> void:
	if v_count >= v_cap:
		return
	var i := v_count
	v_pos[i] = p
	v_vel[i] = vel
	v_life[i] = life
	v_max[i] = life
	v_s0[i] = s0
	v_s1[i] = s1
	v_c0[i] = c0
	v_c1[i] = c1
	v_fire[i] = 1 if fire else 0
	v_count += 1


func _muzzle(p: Vector2, dir: Vector2, col: Color, size: float) -> void:
	if v_count > v_cap * 0.8:
		return  # Keep room for explosions when the screen is busy.
	_vfx(p, dir * 80.0, 0.07, size * 0.5, size, Color(col.r, col.g, col.b, 0.95), Color(col.r, col.g, col.b, 0.0), true)


## A layered explosion: white flash, rolling fireballs, rising smoke and a
## scorch mark. `power` scales the particle count and speed (about 0.4-1.6).
func _explosion(p: Vector2, radius: float, power: float) -> void:
	if v_count > v_cap * 0.9:
		return
	var q := clampf(float(v_cap) / 1600.0, 0.25, 1.0)  # Fewer particles on lower tiers.
	_vfx(p, Vector2.ZERO, 0.14, radius * 0.3, radius * 1.15, Color(1.0, 0.97, 0.85, 0.95), Color(1.0, 0.75, 0.35, 0.0), true)
	for k in int((3.0 + 6.0 * power) * q) + 1:
		var dir := Vector2.from_angle(randf() * TAU)
		_vfx(p + dir * radius * 0.2, dir * randf_range(20.0, 110.0) * power, randf_range(0.3, 0.55), radius * 0.25, radius * randf_range(0.5, 0.75), Color(1.0, 0.72, 0.28, 0.9), Color(0.75, 0.12, 0.04, 0.0), true)
	for k in int((2.0 + 5.0 * power) * q) + 1:
		var dir := Vector2.from_angle(randf() * TAU)
		_vfx(p + dir * radius * 0.3, dir * randf_range(10.0, 40.0) + Vector2(0.0, -25.0), randf_range(0.8, 1.6), radius * 0.3, radius * randf_range(0.8, 1.1), Color(0.24, 0.22, 0.21, 0.55), Color(0.12, 0.12, 0.12, 0.0), false)
	if power >= 0.5 and fx.tier["decals"]:
		_decal(p, radius * 0.9)


func _decal(p: Vector2, size: float) -> void:
	var i := d_count
	if d_count < DECAL_CAP:
		d_count += 1
	else:
		i = randi() % DECAL_CAP
	d_pos[i] = p
	d_life[i] = DECAL_LIFE
	d_size[i] = size


func _update_vfx(dt: float) -> void:
	var fn := 0
	var sn := 0
	var drag := maxf(0.0, 1.0 - 2.5 * dt)
	var i := 0
	while i < v_count:
		var life := v_life[i] - dt
		if life <= 0.0:
			v_count -= 1
			v_pos[i] = v_pos[v_count]
			v_vel[i] = v_vel[v_count]
			v_life[i] = v_life[v_count]
			v_max[i] = v_max[v_count]
			v_s0[i] = v_s0[v_count]
			v_s1[i] = v_s1[v_count]
			v_c0[i] = v_c0[v_count]
			v_c1[i] = v_c1[v_count]
			v_fire[i] = v_fire[v_count]
			continue
		v_life[i] = life
		var k := 1.0 - life / v_max[i]
		var vel := v_vel[i] * drag
		var p := v_pos[i] + vel * dt
		v_vel[i] = vel
		v_pos[i] = p
		var sc := lerpf(v_s0[i], v_s1[i], k) / VFX_RADIUS
		var c := v_c0[i].lerp(v_c1[i], k)
		if v_fire[i] == 1:
			var o := fn * STRIDE
			fn += 1
			fire_buf[o] = sc
			fire_buf[o + 5] = sc
			fire_buf[o + 3] = p.x
			fire_buf[o + 7] = p.y
			fire_buf[o + 8] = c.r
			fire_buf[o + 9] = c.g
			fire_buf[o + 10] = c.b
			fire_buf[o + 11] = c.a
		else:
			var o := sn * STRIDE
			sn += 1
			smoke_buf[o] = sc
			smoke_buf[o + 5] = sc
			smoke_buf[o + 3] = p.x
			smoke_buf[o + 7] = p.y
			smoke_buf[o + 8] = c.r
			smoke_buf[o + 9] = c.g
			smoke_buf[o + 10] = c.b
			smoke_buf[o + 11] = c.a
		i += 1
	fire_n = fn
	smoke_n = sn
	var j := 0
	while j < d_count:
		var dl := d_life[j] - dt
		if dl <= 0.0:
			d_count -= 1
			d_pos[j] = d_pos[d_count]
			d_life[j] = d_life[d_count]
			d_size[j] = d_size[d_count]
			continue
		d_life[j] = dl
		var o := j * STRIDE
		var ds := d_size[j] / 32.0
		decal_buf[o] = ds
		decal_buf[o + 5] = ds
		decal_buf[o + 3] = d_pos[j].x
		decal_buf[o + 7] = d_pos[j].y
		decal_buf[o + 11] = minf(1.0, dl / 2.0)
		j += 1


## A burst from the hero when you gain power: a colored flash, a ring of
## energy, enemies knocked back, and a short slow-down. Bigger for rarer cards
## and higher levels.
func _power_moment(strength: float, color: Color) -> void:
	hud.flash(Color(color.r, color.g, color.b, clampf(0.12 + 0.18 * strength, 0.0, 0.7)))
	_ring(player, 5.0 + 6.0 * strength)
	var reach := 160.0 + 140.0 * strength
	for j in e_count:
		if e_hp[j] <= 0.0 or e_type[j] >= Data.TANK:
			continue
		var d := e_pos[j] - player
		var l := d.length()
		if l < reach and l > 0.1:
			e_pos[j] += d / l * (reach - l) * 0.4
	var n := int(10.0 + 14.0 * strength)
	for k in n:
		var dir := Vector2.from_angle(TAU * k / n)
		_vfx(player + dir * 20.0, dir * (220.0 + 200.0 * strength), 0.4, 6.0, 18.0, Color(color.r, color.g, color.b, 0.9), Color(color.r, color.g, color.b, 0.0), true)
	hitstop = maxf(hitstop, 0.04 + 0.08 * strength)
	trauma = minf(trauma + 0.15 * strength, 0.8)
	sfx.play("powerup", 0.8 + 0.3 * minf(strength, 1.5))


## Damages enemies in a radius without the spatial grid, which is only valid
## during a frame (this runs between frames, from menus and cards).
func _damage_around(center: Vector2, radius: float, dmg: float) -> void:
	for j in e_count:
		if e_hp[j] > 0.0 and center.distance_to(e_pos[j]) < radius + t_radius[e_type[j]]:
			_damage(j, dmg, center, false)
	if boss_on and center.distance_to(boss_pos) < radius + BOSS_RADIUS:
		_damage_boss(dmg, false)


# --- Combo, coins and screen-clear pickups ---------------------------------

## Kills within COMBO_TIME of each other chain into a combo. It boosts XP
## (up to +50% at 1,000) and pays gold at each milestone.
func _add_combo() -> void:
	combo += 1
	combo_timer = COMBO_TIME
	combo_best = maxi(combo_best, combo)
	if combo_step < Data.COMBO_MILESTONES.size() and combo >= int(Data.COMBO_MILESTONES[combo_step][0]):
		var m: Array = Data.COMBO_MILESTONES[combo_step]
		combo_step += 1
		gold += int(m[2])
		hud.show_banner("%s  x%d  +%d gold" % [m[1], m[0], m[2]])
		sfx.play("fanfare")


func _coin(p: Vector2) -> void:
	if co_count >= COIN_CAP:
		gold += 1
		return
	co_pos[co_count] = p
	co_mag[co_count] = 0
	co_count += 1


func _update_coins(dt: float) -> void:
	var pr2 := pickup * pickup
	var i := 0
	while i < co_count:
		var p := co_pos[i]
		var to := player - p
		var d2 := to.length_squared()
		if co_mag[i] == 0 and d2 < pr2:
			co_mag[i] = 1
		if co_mag[i] == 1:
			var d := sqrt(d2)
			if d < PLAYER_RADIUS + 10.0:
				gold += 1
				sfx.play("coin", randf_range(0.95, 1.1), -8.0)
				co_count -= 1
				co_pos[i] = co_pos[co_count]
				co_mag[i] = co_mag[co_count]
				continue
			p += to / maxf(d, 0.001) * minf(d, 1000.0 * dt)
			co_pos[i] = p
		var o := i * STRIDE
		var spin := absf(cos(t * 5.0 + i))
		co_buf[o] = maxf(spin, 0.15)
		co_buf[o + 3] = p.x
		co_buf[o + 7] = p.y
		i += 1


func _drop_pickup(p: Vector2, kind: int) -> void:
	if pickups.size() >= PICKUP_CAP:
		return
	var icon := Sprite2D.new()
	icon.texture = pickup_textures[kind]
	icon.position = p
	icon.scale = Vector2(0.75, 0.75)
	world.add_child(icon)
	pickups.append([kind, p, PICKUP_LIFE, icon])


func _update_powerups(dt: float) -> void:
	var k := pickups.size() - 1
	while k >= 0:
		var pk: Array = pickups[k]
		pk[2] = float(pk[2]) - dt
		var icon: Sprite2D = pk[3]
		var pos: Vector2 = pk[1]
		icon.position = pos + Vector2(0.0, sin(t * 4.0 + k) * 5.0)
		icon.rotation = sin(t * 2.0 + k) * 0.2
		icon.visible = float(pk[2]) > 4.0 or int(t * 8.0) % 2 == 0
		if pos.distance_to(player) < 46.0:
			_apply_pickup(int(pk[0]))
			icon.queue_free()
			pickups.remove_at(k)
		elif float(pk[2]) <= 0.0:
			icon.queue_free()
			pickups.remove_at(k)
		k -= 1


func _apply_pickup(kind: int) -> void:
	hud.show_banner(Data.PICKUP_LABELS[kind])
	match kind:
		Data.NUKE:
			# Wipes every normal enemy near the screen; elites and the boss
			# lose a quarter of their health.
			var reach2 := pow(view.length() * 0.6, 2.0)
			for j in e_count:
				if e_hp[j] <= 0.0 or player.distance_squared_to(e_pos[j]) > reach2:
					continue
				if e_type[j] == Data.ELITE:
					_damage(j, t_hp[Data.ELITE] * 0.25, player, false)
				else:
					e_hp[j] = 0.0
					_kill(j)
			if boss_on:
				_damage_boss(BOSS_HP * 0.05, false)
			b_count = 0
			hud.flash(Color(1, 1, 1, 0.9))
			trauma = 1.0
			hitstop = 0.15
			sfx.play("big_boom")
		Data.FREEZE:
			freeze_t = FREEZE_TIME
			b_count = 0
			telegraphs.clear()
			hud.flash(Color(0.5, 0.85, 1.0, 0.5))
			sfx.play("freeze")
		Data.VACUUM:
			for i in g_count:
				g_mag[i] = 1
			for i in co_count:
				co_mag[i] = 1
			sfx.play("powerup")
		Data.MEDKIT:
			hp = minf(max_hp, hp + max_hp * 0.3)
			sfx.play("powerup")


# --- Saved progress ---------------------------------------------------------

func _record_run(victory: bool) -> void:
	save.set_value("stats", "gold", int(save.get_value("stats", "gold", 0)) + gold)
	save.set_value("stats", "runs", int(save.get_value("stats", "runs", 0)) + 1)
	save.set_value("stats", "wins", int(save.get_value("stats", "wins", 0)) + (1 if victory else 0))
	save.set_value("stats", "best_kills", maxi(int(save.get_value("stats", "best_kills", 0)), kills))
	save.set_value("stats", "best_combo", maxi(int(save.get_value("stats", "best_combo", 0)), combo_best))
	save.set_value("stats", "best_time", maxf(float(save.get_value("stats", "best_time", 0.0)), t))
	if not smoke:
		save.save(SAVE_PATH)


func _save_summary() -> String:
	var runs := int(save.get_value("stats", "runs", 0))
	if runs == 0:
		return ""
	var best := float(save.get_value("stats", "best_time", 0.0))
	return "Gold %d   Runs %d   Wins %d\nBest: %d:%02d survived, %d kills, x%d combo" % [
		int(save.get_value("stats", "gold", 0)), runs, int(save.get_value("stats", "wins", 0)),
		int(best) / 60, int(best) % 60, int(save.get_value("stats", "best_kills", 0)), int(save.get_value("stats", "best_combo", 0))]


## "Watch an ad to double your gold" (free in this build).
func _on_double_gold() -> void:
	if state != State.OVER or gold_doubled:
		return
	gold_doubled = true
	save.set_value("stats", "gold", int(save.get_value("stats", "gold", 0)) + gold)
	if not smoke:
		save.save(SAVE_PATH)
	gold *= 2
	hud.show_results_gold(gold)
	sfx.play("coin")


# --- HUD and results --------------------------------------------------------

func _update_hud() -> void:
	var left := maxf(0.0, STAGE_TIME - t)
	var clock := "BOSS" if boss_spawned else "%d:%02d" % [int(left) / 60, int(left) % 60]
	hud.set_info("Lv %d   Kills %d" % [level, kills], clock)
	hud.set_gold(gold)
	hud.set_combo(combo, combo_timer / COMBO_TIME)


func _build_text() -> String:
	var parts := PackedStringArray()
	for id in weapons:
		if evolved.has(id):
			parts.append("%s ★" % Data.EVOLUTIONS[id]["name"])
		else:
			parts.append("%s %d" % [Data.NAMES[id], weapons[id]])
	for id in powers:
		parts.append("%s %d" % [Data.NAMES[id], powers[id]])
	return " · ".join(parts)


func _results_text(victory: bool) -> String:
	var lines := PackedStringArray()
	lines.append("Stage 1: %s" % ("cleared" if victory else "failed"))
	lines.append("Time %d:%02d   Level %d   Kills %d%s" % [int(t) / 60, int(t) % 60, level, kills, "   (revived)" if revived else ""])
	lines.append("Gold %d   Best combo x%d" % [gold, combo_best])
	lines.append("Build: " + _build_text())
	var n := frame_ms.size()
	if n > 0:
		var sorted := frame_ms.duplicate()
		sorted.sort()
		var total := 0.0
		for ms in sorted:
			total += ms
		var worst_count := maxi(1, int(n / 100.0))
		var worst := 0.0
		for i in range(n - worst_count, n):
			worst += sorted[i]
		lines.append("Graphics %s, %.0f FPS average, worst 1%% %.0f FPS" % [quality, n * 1000.0 / maxf(total, 0.001), 1000.0 / maxf(worst / worst_count, 0.001)])
		lines.append("Game logic %.1f ms average, %.1f ms worst; most enemies at once %d" % [logic_sum / n, logic_worst, peak_enemies])
	lines.append("Phone: %s" % OS.get_model_name())
	return "\n".join(lines)


# --- Bot (auto-play, smoke test and screenshots) ---------------------------

func _bot_move() -> Vector2:
	if bot_still:
		return Vector2.ZERO
	var push := Vector2.ZERO
	for i in e_count:
		if e_hp[i] <= 0.0:
			continue
		var d := player - e_pos[i]
		var l2 := d.length_squared()
		if l2 < 48400.0 and l2 > 1.0:
			push += d / l2 * 3000.0
	for i in b_count:
		var d := player - b_pos[i]
		var l2 := d.length_squared()
		if l2 < 19600.0 and l2 > 1.0:
			push += d / l2 * 4000.0
	for tg in telegraphs:
		var start: Vector2 = tg[1]
		var end: Vector2 = tg[2]
		match int(tg[0]):
			0:
				var d := player - start
				if d.length() < end.x + 30.0:
					push += d.normalized() * 2.5
			1, 3:
				var closest := Geometry2D.get_closest_point_to_segment(player, start, end)
				var away := player - closest
				if away.length() < 70.0:
					push += away.normalized() * 2.5
	if boss_on:
		var d := player - boss_pos
		if d.length() < 320.0:
			push += d.normalized() * 2.0
	# Drift toward the nearest XP gem, like a player would.
	var gem_best := 250000.0
	var gem_dir := Vector2.ZERO
	for i in g_count:
		var d2 := player.distance_squared_to(g_pos[i])
		if d2 < gem_best:
			gem_best = d2
			gem_dir = (g_pos[i] - player).normalized()
	push += gem_dir * 1.5
	var mv := push + Vector2.from_angle(t * 0.3) * 0.35
	return mv.normalized() if mv.length() > 0.05 else Vector2.ZERO


func _bot_pick() -> void:
	if state != State.CARDS:
		return
	var best := 0
	var best_score := -INF
	for i in offers.size():
		var o: Dictionary = offers[i]
		var score := float(o["rarity"]) * 10.0
		if o["evolve"]:
			score += 100.0
		if o["kind"] == "weapon":
			score += 5.0 if weapons.has(o["id"]) or weapons.size() < 4 else -5.0
		if o["kind"] == "power" and Data.EVOLUTIONS.values().any(func(e): return e["power"] == o["id"]):
			score += 3.0
		score += randf()
		if score > best_score:
			best_score = score
			best = i
	_on_card(best)


func _grant(items: Dictionary) -> void:
	for id in items:
		if Data.WEAPON_IDS.has(id):
			weapons[id] = items[id]
		else:
			powers[id] = items[id]
	_recalc()
	hp = max_hp


func _run_smoke() -> void:
	print("SMOKE: start")
	_set_quality("Ultra")
	_start(true)
	var frames := 0
	while state != State.OVER and frames < 60 * 420:
		await get_tree().process_frame
		frames += 1
	print("SMOKE: stage run ended state=%d t=%.0f level=%d kills=%d boss_spawned=%s" % [state, t, level, kills, boss_spawned])
	print(_results_text(boss_dead_t >= 0.0))
	if not _check(t > 30.0 and kills > 0, "the bot played the stage"):
		return
	# Second run: every weapon and power maxed and evolved, near the boss.
	_start(true)
	_grant({"rifle": 8, "scatter": 8, "rockets": 8, "halo": 8, "tesla": 8, "airstrike": 8, "overclock": 8, "titan": 8, "magnet": 8, "adrenaline": 8, "explosive": 8, "crit": 8})
	for id in Data.EVOLUTIONS:
		evolved[id] = true
	_recalc()
	god = true
	t = 280.0
	await _frames(60 * 40)
	god = false
	print("SMOKE: all-items run t=%.0f state=%d enemies=%d kills=%d boss_on=%s boss_dead=%s logic_worst=%.1f" % [t, state, e_count, kills, boss_on, boss_dead_t >= 0.0, logic_worst])
	if not _check(kills > 100, "the all-items run killed enemies"):
		return
	print("SMOKE: passed")
	get_tree().quit(0)


func _run_shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	god = true
	await _frames(5)
	await _save_shot(dir, "menu")
	for tier_name in ["Ultra", "High", "Medium", "Low"]:
		_set_quality(tier_name)
		_start(true)
		_grant({"rifle": 5, "rockets": 4, "halo": 4, "tesla": 3, "airstrike": 3, "scatter": 2, "overclock": 3, "explosive": 2})
		t = 200.0
		await _frames(60 * 3)
		# A fixed ring of every enemy type around a still player, made tough so
		# it survives until the screenshot.
		bot_still = true
		_showcase()
		await _frames(30)
		await _save_shot(dir, "play_" + tier_name.to_lower())
		bot_still = false
		if tier_name == "Ultra":
			bot_cards = false
			pending_levels += 1
			await _frames(3)
			await _save_shot(dir, "cards")
			_bot_pick()
			_grant({"rifle": 8, "overclock": 3})
			_open_chest()
			await _frames(90)
			await _save_shot(dir, "chest")
			_on_chest_collected()
			bot_cards = true
			t = STAGE_TIME - 1.0
			await _frames(5)
			bot_still = true
			boss_pos = player + Vector2(0.0, -330.0)
			await _frames(90)
			await _save_shot(dir, "boss")
			bot_still = false
	print("SHOTS: done")
	get_tree().quit(0)


func _showcase() -> void:
	var kinds := [Data.TROOPER, Data.TROOPER, Data.SHIELD, Data.GRENADIER, Data.TROOPER, Data.TANK, Data.TROOPER, Data.HELI, Data.SHIELD, Data.TROOPER, Data.GRENADIER, Data.ELITE]
	for k in 36:
		var ty: int = kinds[k % kinds.size()]
		_spawn_enemy(ty)
		var i := e_count - 1
		e_pos[i] = player + Vector2.from_angle(TAU * k / 36.0) * (190.0 + (k % 3) * 80.0)
		e_hp[i] = 1.0e6


func _save_shot(dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := dir.path_join(name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	var units := 0
	for n in unit_n:
		units += n
	print("SHOTS: saved %s quality=%s state=%d enemies=%d unit_sprites=%d shots=%d rockets=%d enemy_bullets=%d gems=%d sparks=%d rings=%d boss=%s" % [path, quality, state, e_count, units, s_count, k_count, b_count, g_count, p_count, r_count, boss_on])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(ok: bool, what: String) -> bool:
	if not ok:
		printerr("SMOKE FAILED: " + what)
		get_tree().quit(1)
	return ok
