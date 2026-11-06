extends Node3D
## Country kit shots: chosen country_kit kinds at chosen household tiers,
## each from straight above and from a lower 3/4 perspective, for art review.
## Needs a real renderer:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 \
##     --resolution 1280x720 res://tests/kit_shots.tscn -- <out_dir> kind:tier [kind:tier ...]
## A tier of -1 (or none) builds the kind's usual tier; add "night" as a spec
## to also shoot each at night from the 3/4 angle.

const MeshBuilder = preload("res://scripts/mesh_builder.gd")
const Kit = preload("res://scripts/kits/country_kit.gd")

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
	_setup_world()
	_run.call_deferred(args.slice(1))


func _run(specs: Array) -> void:
	var night := specs.has("night")
	for spec: String in specs:
		if spec == "night":
			continue
		var parts := spec.split(":")
		var kind := parts[0]
		var tier := int(parts[1]) if parts.size() > 1 else -1
		await _shoot(kind, tier, night)
	get_tree().quit()


func _setup_world() -> void:
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 600.0
	add_child(sun)
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.85
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var ground := MeshBuilder.new()
	ground.box(Vector3(0, -0.1, 0), Vector3(1600, 0.2, 1600), Color(0.58, 0.56, 0.52))
	add_child(ground.make_instance())
	camera.near = 0.5
	camera.far = 1200.0
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


## Builds the kind on its footprint, turned so its street front faces the
## camera (+z), beside a dark street strip, and shoots it.
func _shoot(kind: String, tier: int, night: bool) -> void:
	var size: Vector2 = Kit.footprint(kind)
	var mb := MeshBuilder.new()
	mb.box(Vector3(0, 0.0, 0), Vector3(size.x + 1.2, 0.02, size.y + 1.2), Color(0.25, 0.25, 0.27))
	mb.box(Vector3(0, 0.0, size.y * 0.5 + 5.0), Vector3(size.x + 12.0, 0.02, 8.0), Color(0.2, 0.2, 0.22))
	var first := mb.verts.size()
	mb.xform = Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	Kit.wealth = tier
	Kit.build(kind, mb, [], size, rng)
	Kit.wealth = -1
	mb.xform = Transform3D.IDENTITY
	var top := 0.0
	for i in range(first, mb.verts.size()):
		top = maxf(top, mb.verts[i].y)
	var stem := "kit_%s_t%s" % [kind, str(tier) if tier >= 0 else "u"]
	_light(DAY)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.rotation_degrees = Vector3(-89.0, 0.0, 0.0)
	camera.size = maxf(size.y + 14.0, (size.x + 6.0) / 1.78)
	camera.global_position = Vector3(0, 0, 2.0) + camera.global_basis.z * 400.0
	await _snap(mb, stem + "_1_top.png")
	await _three_quarter(mb, size, top, stem + "_2_34.png")
	if night:
		_light(NIGHT)
		await _three_quarter(mb, size, top, stem + "_3_night.png")
		_light(DAY)


## Perspective 3/4 view from the front-right, lower than the game camera.
func _three_quarter(mb: MeshBuilder, size: Vector2, top: float, file: String) -> void:
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 45.0
	camera.rotation_degrees = Vector3(-28.0, 30.0, 0.0)
	var reach := maxf(maxf(size.x, size.y) * 0.62, top * 0.75) + 4.0
	var aim := Vector3(0, top * 0.42, 0)
	camera.global_position = aim + camera.global_basis.z * reach * 1.6
	await _snap(mb, file)


func _snap(mb: MeshBuilder, file: String) -> void:
	var inst := mb.make_instance()
	inst.material_override = MeshBuilder.cutaway_material()
	inst.material_override.set_shader_parameter("cut_radius", 0.0) # no player to see
	add_child(inst)
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))
	print("saved %s: %d triangles" % [file, mb.triangle_count()])
	remove_child(inst)
	inst.free()
