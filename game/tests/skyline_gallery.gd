extends Node3D
## Skyline kit gallery: every skyline_kit kind on its default lot, for art
## review. Needs a real renderer:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 \
##     --resolution 1280x720 res://tests/skyline_gallery.tscn -- <out_dir> [mode] [kind filter]
## Modes: "all" (default) = the grid pages (by day and night) and per kind
## shots; "grid" = the pages only; "each" = the per-kind shots only. Per
## kind: 1 a whole-lot overview under the game's orthographic 60-degree
## camera, 2 a low three-quarter perspective view, 3 the game camera at
## game zoom (48 m of screen) on the roof, 4 the same on the street front,
## and for towers and the big monuments 5 the overview at night.

const MeshBuilder = preload("res://scripts/mesh_builder.gd")
const Skyline = preload("res://scripts/kits/skyline_kit.gd")

## Grid pages: [file stem, kinds, also at night].
const PAGES := [
	["skyline_grid_1_towers", ["skyscraper_glass", "skyscraper_crown", "skyscraper_helipad", "skyscraper_twin", "skyscraper_slab", "highrise_mid"], true],
	["skyline_grid_2_monuments", ["memorial_arch", "statue_plinth", "suspension_tower", "radio_mast", "observatory"], true],
	["skyline_grid_3_letters", ["hillside_letters"], false],
	["skyline_grid_4_coliseum", ["coliseum"], true],
]
const NIGHT_KINDS := ["skyscraper_glass", "skyscraper_crown", "skyscraper_helipad", "skyscraper_twin", "skyscraper_slab", "highrise_mid", "coliseum", "memorial_arch", "observatory", "suspension_tower", "radio_mast"]
## Game zoom: the game frames about 26 to 48 m of screen.
const GAME_VIEW := 48.0

const DAY := {
	"sky": Color(0.55, 0.7, 0.85), "ambient": Color(0.78, 0.8, 0.88), "ambient_energy": 0.35,
	"sun": Color(1.0, 0.97, 0.9), "sun_energy": 0.7, "night": 0.0,
}
const NIGHT := {
	"sky": Color(0.06, 0.08, 0.15), "ambient": Color(0.5, 0.52, 0.72), "ambient_energy": 0.62,
	"sun": Color(0.6, 0.68, 1.0), "sun_energy": 0.28, "night": 1.0,
}

var out_dir := "user://"
var camera := Camera3D.new()
var sun := DirectionalLight3D.new()
var env := Environment.new()


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var mode: String = args[1] if args.size() > 1 else "all"
	var only: String = args[2] if args.size() > 2 else ""
	_setup_world()
	_run.call_deferred(mode, only)


func _run(mode: String, only: String) -> void:
	if mode == "all" or mode == "grid":
		for page in PAGES:
			if only != "" and not (page[1] as Array).any(func(k): return k.contains(only)):
				continue
			await _grid(page[0], page[1], false)
			if page[2]:
				await _grid(page[0] + "_night", page[1], true)
	if mode == "all" or mode == "each":
		for kind: String in Skyline.kinds():
			if only != "" and not kind.contains(only):
				continue
			await _each(kind)
	get_tree().quit()


func _setup_world() -> void:
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 900.0
	add_child(sun)
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.85
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var ground := MeshBuilder.new()
	ground.box(Vector3(0, -0.1, 0), Vector3(2000, 0.2, 2000), Color(0.58, 0.56, 0.52))
	add_child(ground.make_instance())
	camera.near = 1.0
	camera.far = 2000.0
	add_child(camera)
	_light(DAY)


func _light(look: Dictionary) -> void:
	env.background_color = look.sky
	env.ambient_light_color = look.ambient
	env.ambient_light_energy = look.ambient_energy
	sun.light_color = look.sun
	sun.light_energy = look.sun_energy
	RenderingServer.global_shader_parameter_set("night", look.night)
	RenderingServer.global_shader_parameter_set("wet", 0.0)
	RenderingServer.global_shader_parameter_set("sky_tint", (look.sky as Color).lerp(Color(0.6, 0.7, 0.85), 0.4))


## Builds `kind` on its default lot, turned so its front faces the camera
## (+z), centred at `c`, with a dark outline pad. Returns the top height.
func _place(mb: MeshBuilder, kind: String, c: Vector3, seed: int) -> float:
	var size := Skyline.default_size(kind)
	mb.xform = Transform3D.IDENTITY
	mb.box(Vector3(c.x, 0.0, c.z), Vector3(size.x + 1.2, 0.02, size.y + 1.2), Color(0.25, 0.25, 0.27))
	var first := mb.verts.size()
	mb.xform = Transform3D(Basis(Vector3.UP, PI), c)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	Skyline.build(kind, mb, [], size, rng)
	mb.xform = Transform3D.IDENTITY
	var top := 0.0
	for i in range(first, mb.verts.size()):
		top = maxf(top, mb.verts[i].y)
	return top


## One page: the kinds in rows (each row up to 200 m wide), by day or night.
func _grid(stem: String, kinds: Array, night: bool) -> void:
	const GAP := 8.0
	const ROW := 200.0
	var rows: Array = [[]]
	var x := 0.0
	for kind: String in kinds:
		var s := Skyline.default_size(kind)
		if x > 0.0 and x + s.x > ROW:
			rows.append([])
			x = 0.0
		rows[-1].append(kind)
		x += s.x + GAP
	var mb := MeshBuilder.new()
	var depth := -GAP
	var widest := 0.0
	var top := 0.0
	for row: Array in rows:
		var d := 0.0
		var w := -GAP
		for kind: String in row:
			w += Skyline.default_size(kind).x + GAP
			d = maxf(d, Skyline.default_size(kind).y)
		widest = maxf(widest, w)
		depth += d + GAP
	var z := -depth * 0.5
	var n := 0
	for row: Array in rows:
		var d := 0.0
		var w := -GAP
		for kind: String in row:
			w += Skyline.default_size(kind).x + GAP
			d = maxf(d, Skyline.default_size(kind).y)
		x = -w * 0.5
		for kind: String in row:
			var s := Skyline.default_size(kind)
			top = maxf(top, _place(mb, kind, Vector3(x + s.x * 0.5, 0, z + d * 0.5), 11 + n * 17))
			x += s.x + GAP
			n += 1
		z += d + GAP
	var view := maxf(depth * 0.87 + top * 0.5 + 8.0, (widest + 8.0) / 1.78)
	_light(NIGHT if night else DAY)
	await _ortho(mb, Vector3(0, top * 0.25, 0), view, stem + ".png")
	_light(DAY)


## Per kind: overview, low three-quarter view, game-zoom roof and street
## shots by day, and a night overview for the lit kinds.
func _each(kind: String) -> void:
	var mb := MeshBuilder.new()
	var top := _place(mb, kind, Vector3.ZERO, 11)
	var s := Skyline.default_size(kind)
	var view := maxf(s.y * 0.87 + top * 0.5 + 6.0, (s.x + 6.0) / 1.78)
	_light(DAY)
	await _ortho(mb, Vector3(0, top * 0.25, 0), view, "skyline_%s_1_overview.png" % kind)
	await _close(mb, s, top, "skyline_%s_2_close.png" % kind)
	# The roof at game zoom: aim at the highest broad surface, about 0.93
	# of the top for towers (below masts and spires), the middle otherwise.
	var roof_y := top * 0.9 if top > 40.0 else top * 0.5
	await _ortho(mb, Vector3(0, roof_y, 0), GAME_VIEW, "skyline_%s_3_gameroof.png" % kind)
	# The street front (the lot's front faces +z here).
	await _ortho(mb, Vector3(0, 2.0, s.y * 0.5 - 6.0), GAME_VIEW, "skyline_%s_4_gamestreet.png" % kind)
	if kind in NIGHT_KINDS:
		_light(NIGHT)
		await _ortho(mb, Vector3(0, top * 0.25, 0), view, "skyline_%s_5_night.png" % kind)
		_light(DAY)


func _ortho(mb: MeshBuilder, center: Vector3, view: float, file: String) -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.rotation_degrees = Vector3(-60.0, 0.0, 0.0)
	camera.size = view
	camera.global_position = center + camera.global_basis.z * 600.0
	await _snap(mb, file)


## Perspective three-quarter view from the front-right, lower than the game
## camera, framing the whole lot.
func _close(mb: MeshBuilder, size: Vector2, top: float, file: String) -> void:
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 45.0
	camera.rotation_degrees = Vector3(-28.0, 28.0, 0.0)
	var reach := maxf(maxf(size.x, size.y) * 0.62, top * 0.75) + 4.0
	var aim := Vector3(0, top * 0.45, 0)
	camera.global_position = aim + camera.global_basis.z * reach * 1.6
	await _snap(mb, file)


func _snap(mb: MeshBuilder, file: String) -> void:
	var inst := mb.make_instance()
	inst.material_override = MeshBuilder.cutaway_material()
	inst.material_override.set_shader_parameter("cut_radius", 0.0) # no player to see
	add_child(inst)
	print("%s: %d triangles" % [file, mb.triangle_count()])
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))
	remove_child(inst)
	inst.free()
