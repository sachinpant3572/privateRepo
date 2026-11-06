extends Node3D
## Character shots for art review: every kind of person, the hero, the gaits,
## gestures, one-shot actions, idle acts, falls and getting up. Needs a real
## renderer:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 \
##     --resolution 1280x720 res://tests/char_shots.tscn -- <out_dir> [pages...]
## Pages: crowd (street camera distance), kinds_a, kinds_b, hero, gaits,
## gestures, actions, faces, motion. Each saved shot prints "saved <file>".

const MeshBuilder = preload("res://scripts/mesh_builder.gd")
const CharacterKit = preload("res://scripts/kits/character_kit.gd")
const Rig = preload("res://scripts/rig.gd")
const Player = preload("res://scripts/player.gd")
const Cop = preload("res://scripts/cop.gd")

const PAGES := ["crowd", "kinds_a", "kinds_b", "hero", "gaits", "gestures", "actions", "faces", "motion"]
## The street camera's view height on foot (TopDownCamera.FOOT_SIZE).
const STREET_VIEW := 26.0

var out_dir := "user://"
var camera := Camera3D.new()
var rng := RandomNumberGenerator.new()
var _rigs: Array = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0]
	rng.seed = 5
	_setup_world()
	_run.call_deferred(args.slice(1) if args.size() > 1 else PAGES)


func _run(pages: Array) -> void:
	for p in pages:
		await call("_page_" + String(p))
	get_tree().quit()


## Every kind in a row at the street camera's distance: does each read?
func _page_crowd() -> void:
	var kinds: Array = CharacterKit.CATEGORIES.duplicate()
	for row in kinds.size():
		for i in 9:
			var look := CharacterKit.category_look(rng, kinds[row])
			_person(look, Vector3(-9.0 + i * 2.2, 0, -8.0 + row * 2.0), _street_pose(i), i % 3 == 2)
	_person(Player.JULES, Vector3(11.5, 0, -2.0), "walk")
	_person(Player.JULES, Vector3(11.5, 0, 2.0), "idle")
	var cop = Cop.new()
	_person(cop.look, Vector3(11.5, 0, 6.0), "patrol")
	cop.free()
	await _shoot(Vector3(1.5, 0, 0), STREET_VIEW, "char_1_crowd.png")


func _page_kinds_a() -> void:
	await _kinds(CharacterKit.CATEGORIES.slice(0, 5), "char_2_kinds_a.png")


func _page_kinds_b() -> void:
	var kinds: Array = CharacterKit.CATEGORIES.slice(5)
	await _kinds(kinds, "char_3_kinds_b.png", true)


## Close up: five people of each kind, the last from behind.
func _kinds(kinds: Array, file: String, with_cop := false) -> void:
	for row in kinds.size():
		for i in 6:
			var look := CharacterKit.category_look(rng, kinds[row])
			_person(look, Vector3(-4.5 + i * 1.6, 0, -3.6 + row * 1.9), "walk" if i == 4 else "idle", i == 5)
	if with_cop:
		var cop = Cop.new()
		for i in 3:
			_person(cop.look, Vector3(-4.5 + i * 1.6, 0, -3.6 + kinds.size() * 1.9), "patrol" if i == 1 else "idle", i == 2)
		cop.free()
	await _shoot(Vector3(-0.5, 0, 0.0), 9.5, file)


## The hero beside plain people: front, three-quarter, side, back, walking,
## running, and a plain look of the same outfit for comparison.
func _page_hero() -> void:
	var yaws := [PI, PI * 0.75, PI * 0.5, 0.0]
	for i in yaws.size():
		_person(Player.JULES, Vector3(-3.6 + i * 1.5, 0, -1.0), "idle", false, yaws[i])
	_person(Player.JULES, Vector3(2.4, 0, -1.0), "walk")
	_person(Player.JULES, Vector3(3.9, 0, -1.0), "run")
	var plain := Player.JULES.duplicate()
	plain.erase("hero")
	plain.erase("stripes")
	_person(plain, Vector3(-3.6, 0, 1.6), "idle")
	for i in 4:
		_person(CharacterKit.category_look(rng, "general"), Vector3(-2.1 + i * 1.5, 0, 1.6), "idle")
	await _shoot(Vector3(0.2, 0, 0.3), 5.5, "char_4_hero.png")


## Close up at eye level (the mission intro camera's view): faces and hands
## of the hero and three looks with a beard, glasses and long hair, then the
## shoes from low down.
func _page_faces() -> void:
	var looks := [Player.JULES,
		{"hair": "fade", "beard": true, "glasses": true, "skin": CharacterKit.SKIN[3], "outfit": "polo", "shirt": Color(0.2, 0.36, 0.6)},
		{"hair": "long", "skin": CharacterKit.SKIN[1], "hair_color": CharacterKit.HAIR[3], "outfit": "tee", "shirt": Color(0.9, 0.85, 0.75), "eyes": Color(0.15, 0.3, 0.25)},
		{"hair": "short", "hair_color": CharacterKit.GREYS[2], "skin": CharacterKit.SKIN[2], "outfit": "cardigan", "jacket": CharacterKit.KNITS[1], "headwear": "cap", "hat": Color(0.13, 0.17, 0.28)}]
	var styles := ["sneakers", "dress", "boots", "heels"]
	for shot in 2:
		for i in looks.size():
			var look: Dictionary = looks[i].duplicate()
			if shot == 1:
				look["shoe_style"] = styles[i]
				look["shoes"] = [Color(0.85, 0.2, 0.15), Color(0.2, 0.12, 0.08), Color(0.6, 0.42, 0.24), Color(0.09, 0.09, 0.1)][i]
			_person(look, Vector3(-1.08 + i * 0.72, 0, 0), "idle", false, PI * (1.0 if shot == 0 else 0.85))
		camera.rotation_degrees = Vector3(-8.0 if shot == 0 else -25.0, 0.0, 0.0)
		if shot == 0:
			await _shoot(Vector3(0, 1.32, 0), 1.6, "char_8_faces.png")
		else:
			await _shoot(Vector3(0, 0.12, 0), 1.7, "char_9_shoes.png")
	camera.rotation_degrees = Vector3(-60.0, 0.0, 0.0)


## Every gait (Rig.STYLES) at its natural speed, and texting: from the
## front in the top rows, in profile (walking left) below.
func _page_gaits() -> void:
	var speeds := {"": 1.5, "jog": 3.2, "sprint": 7.5, "panic": 5.5, "limp": 0.9, "elderly": 0.9, "patrol": 1.5,
		"carry": 1.3, "rain": 2.0, "swagger": 1.3, "pockets": 1.3}
	var styles: Array = Rig.STYLES.duplicate()
	styles.append("texting")
	for side in 2:
		for i in styles.size():
			var style: String = styles[i]
			var look: Dictionary = Player.JULES if style == "texting" else \
				CharacterKit.category_look(rng, "elderly" if style == "elderly" else ("athlete" if style == "jog" else "general"))
			var pos := Vector3(-5.0 + (i % 6) * 2.0, 0, -3.4 + (i / 6) * 2.4 + side * 4.8)
			var r := _person(look, pos, "walk", false, PI * 0.9 if side == 0 else -PI * 0.5)
			if style == "texting":
				r[1].texting = true
			else:
				r[1].style = style
				r[1].speed = speeds[style]
			r[1].run_speed = 6.0
			if side == 0:
				_label(pos + Vector3(0, 0, 0.9), style if style != "" else "walk")
	await _shoot(Vector3(0, 0, 0.2), 10.0, "char_5_gaits.png")


## Every gesture (Rig.GESTURES), labelled.
func _page_gestures() -> void:
	var cols := 9
	for i in Rig.GESTURES.size():
		var pos := Vector3(-7.2 + (i % cols) * 1.8, 0, -3.0 + (i / cols) * 2.6)
		var r := _person(CharacterKit.category_look(rng, "general"), pos, "idle")
		r[1].gesture = Rig.GESTURES[i]
		r[1].idle = false
		_label(pos + Vector3(0, 0, 0.9), Rig.GESTURES[i])
	await _shoot(Vector3(0, 0, -0.4), 9.0, "char_6_gestures.png")


## One-shot actions at their peak, every idle act mid-way, the falls,
## getting up and the fighting moves.
func _page_actions() -> void:
	var items: Array = []
	for a in Rig.ACTIONS:
		items.append(["action", a, 0.45])
	for act in Rig.IDLE_ACTS:
		items.append(["idle", act[0], 0.3 if act[0] == "look_around" else 0.5])
	items.append_array([["down", "fall back", 0.0], ["down_front", "fall front", 0.0], ["getup", "get up 0.3", 0.3],
		["getup", "get up 0.7", 0.7], ["dead", "dead", 0.0], ["sit", "sit", 0.0], ["ride", "ride", 0.0],
		["punch", "punch", 0.35], ["kick", "kick", 0.4], ["look", "look left", 1.2], ["flinch", "flinch", 1.0]])
	var cols := 9
	for i in items.size():
		var it: Array = items[i]
		var pos := Vector3(-7.2 + (i % cols) * 1.8, 0, -3.0 + (i / cols) * 2.6)
		var r := _person(CharacterKit.category_look(rng, "general"), pos, "idle")
		_label(pos + Vector3(0, 0, 0.9), String(it[1]))
		_prepare(r, it)
	await _shoot(Vector3(0, 0, -0.4), 9.0, "char_7_actions.png")


## Poses `r` (rig, state) into item `it` before the shot; the shot then runs
## 40 more frames, so the prepared ones are stepped to hold their moment.
func _prepare(r: Array, it: Array) -> void:
	var rig = r[0]
	var st = r[1]
	var step := 1.0 / 60.0
	match it[0]:
		"action":
			st.action = it[1]
			st.action_t = it[2]
		"idle":
			# A seed whose first idle act is this one, run until it is mid-way.
			for seed in 64:
				var stride := 3 if seed % 2 == 0 else 5
				if Rig.IDLE_ACTS[(seed * 5 + stride) % Rig.IDLE_ACTS.size()][0] == it[1]:
					st.idle_seed = seed
					break
			var dur := 0.0
			for a in Rig.IDLE_ACTS:
				if a[0] == it[1]:
					dur = a[1]
			for f in 600:
				rig.pose(st, step)
				if rig.idle_act() == it[1]:
					for g in int(dur * float(it[2]) / step) - 40:
						rig.pose(st, step)
					break
			r[2] = "idle_hold"
		"down", "down_front":
			st.down = true
			st.face_down = it[0] == "down_front"
		"getup":
			st.down = true
			st.getup = it[2]
			for f in 60:
				rig.pose(st, step)
		"dead":
			st.down = true
			st.dead = true
		"sit":
			st.sit = true
		"ride":
			st.ride = true
		"punch":
			st.punch = it[2]
		"kick":
			st.kick = it[2]
		"look":
			st.look_yaw = it[2]
			st.look_amount = 1.0
		"flinch":
			st.flinch = it[2]


## The hero from the side as filmstrips, eight frames a row: char_10 his
## walk, jog and sprint across one stride (rows top to bottom); char_11 a
## punch, a kick, setting off into a jog and pulling up from one, each
## stepped through in game time.
func _page_motion() -> void:
	var gaits := [[1.5, ""], [Player.JOG_SPEED, ""], [Player.SPRINT_SPEED, "sprint"]]
	for row in gaits.size():
		for col in 8:
			var r := _person(Player.JULES, _strip_pos(row, col), "idle", false, PI * 0.5)
			r[1].speed = gaits[row][0]
			r[1].style = gaits[row][1]
			r[1].idle = false
			r[0].phase = TAU * col / 8.0
	await _shoot_strip(gaits.size(), "char_10_gait.png", true)
	var step := 1.0 / 60.0
	var moves := [["punch", 0.33], ["hook", 0.33], ["kick", 0.5], ["start", 0.7], ["stop", 0.7]]
	for row in moves.size():
		for col in 8:
			var r := _person(Player.JULES, _strip_pos(row, col), "idle", false, PI * 0.5)
			var rig = r[0]
			var st = r[1]
			st.idle = false
			var t_end: float = moves[row][1] * col / 7.0
			var run_in: bool = moves[row][0] == "stop"
			st.speed = Player.JOG_SPEED if run_in else 0.0
			st.guard = moves[row][0] in ["punch", "hook", "kick"]
			st.punch_left = moves[row][0] == "hook"
			for f in 90:
				rig.pose(st, step)
			var t := 0.0
			while t < t_end - 0.001:
				match moves[row][0]:
					"punch", "hook":
						st.punch = t / 0.28 if t < 0.28 else -1.0
					"kick":
						st.kick = t / 0.45 if t < 0.45 else -1.0
					"start": # the hero's speed builds as in Player._think
						st.speed = minf(Player.JOG_SPEED, (t + step) * Player.ACCEL)
					"stop":
						st.speed = maxf(0.0, Player.JOG_SPEED - (t + step) * Player.DECEL)
				rig.pose(st, step)
				t += step
	await _shoot_strip(moves.size(), "char_11_moves.png", false)


func _strip_pos(row: int, col: int) -> Vector3:
	return Vector3(-5.95 + col * 1.7, 0.0, -row * 6.0)


## Side-on, a little from above, rows stacked up the frame; `settle` runs
## the rigs 40 frames first (steady gaits), else they hold where they are.
func _shoot_strip(rows: int, file: String, settle: bool) -> void:
	camera.rotation_degrees = Vector3(-20.0, 0.0, 0.0)
	await _shoot(Vector3(0.0, 0.9, -(rows - 1) * 3.0), maxf(2.1 * rows + 0.6, 7.8), file, settle)
	camera.rotation_degrees = Vector3(-60.0, 0.0, 0.0)


func _street_pose(i: int) -> String:
	return ["walk", "idle", "walk", "text", "idle", "walk", "idle", "walk", "idle"][i % 9]


## Adds a person at `pos` facing the camera (or away, or at `yaw`) and returns
## [rig, state, pose].
func _person(look: Dictionary, pos: Vector3, pose: String, away := false, yaw := INF) -> Array:
	var skel := CharacterKit.build_rig(look)
	skel.get_node("Body").material_override = MeshBuilder.material()
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = yaw if yaw != INF else (PI * 0.9 if not away else PI * -0.1)
	add_child(holder)
	holder.add_child(skel)
	var st = Rig.State.new()
	st.idle_seed = _rigs.size() * 7
	match pose:
		"walk":
			st.speed = 1.5
		"patrol":
			st.speed = 1.5
			st.style = "patrol"
		"run":
			st.speed = 5.5
			st.run_speed = 6.0
		"text":
			st.texting = true
	var rig = Rig.new(skel)
	rig.phase = 1.2 + _rigs.size() * 0.7
	var r := [rig, st, pose]
	_rigs.append(r)
	return r


func _label(pos: Vector3, text: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 40
	l.pixel_size = 0.004
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = Color(0.05, 0.05, 0.08)
	l.outline_size = 8
	l.outline_modulate = Color(1, 1, 1)
	l.position = pos + Vector3(0, 0.02, 0)
	l.add_to_group("char_shot_label")
	add_child(l)


## Runs the rigs 40 frames, shoots under the 60° camera, clears the page.
func _shoot(center: Vector3, view: float, file: String, settle := true) -> void:
	var tris := 0
	for r in _rigs:
		var body: MeshInstance3D = r[0].skeleton.get_node("Body")
		tris += body.mesh.get_faces().size() / 3
	for frame in (40 if settle else 0):
		for r in _rigs:
			r[0].pose(r[1], 1.0 / 60.0)
	camera.size = view
	camera.global_position = center + camera.global_basis.z * 60.0
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))
	print("saved %s (%d people, %d triangles)" % [file, _rigs.size(), tris])
	for r in _rigs:
		r[0].skeleton.get_parent().queue_free()
	_rigs.clear()
	for l in get_tree().get_nodes_in_group("char_shot_label"):
		l.queue_free()
	await get_tree().process_frame


func _setup_world() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.7, 0.85)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.8, 0.88)
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.85
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var ground := MeshBuilder.new()
	ground.box(Vector3(0, -0.1, 0), Vector3(80, 0.2, 60), Color(0.6, 0.59, 0.56))
	add_child(ground.make_instance())
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.rotation_degrees = Vector3(-60.0, 0.0, 0.0)
	camera.near = 1.0
	camera.far = 200.0
	add_child(camera)
