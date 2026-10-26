extends Node3D
## Asset gallery: every kit piece lined up under the game's 3/4 camera, for
## art review. Needs a real renderer:
##   xvfb-run godot --rendering-driver opengl3 res://tests/gallery.tscn -- <out_dir>

const MeshBuilder = preload("res://scripts/mesh_builder.gd")
const Buildings = preload("res://scripts/kits/building_kit.gd")
const Props = preload("res://scripts/kits/prop_kit.gd")
const VehicleKit = preload("res://scripts/kits/vehicle_kit.gd")
const CharacterKit = preload("res://scripts/kits/character_kit.gd")

var out_dir := "user://"
var rng := RandomNumberGenerator.new()
var camera := Camera3D.new()


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0]
	rng.seed = 7
	_setup_world()
	_run.call_deferred()


func _run() -> void:
	await _shot(_buildings(), Vector3(0, 0, 0), 62.0, "gallery_1_buildings.png")
	await _shot(_landmarks(), Vector3(0, 0, 300), 108.0, "gallery_2_landmarks.png")
	await _shot(_vehicles_and_people(), Vector3(0, 0, 600), 22.0, "gallery_3_vehicles_people.png")
	await _shot(_props(), Vector3(0, 0, 900), 24.0, "gallery_4_props.png")
	get_tree().quit()


func _buildings() -> MeshBuilder:
	var mb := MeshBuilder.new()
	var out: Array = []
	var x := -48.0
	for item in [["townhouse2", 8.0], ["townhouse3", 9.0], ["shotgun", 5.4], ["damaged", 5.4], ["apartment", 12.0], ["tower", 16.0], ["warehouse", 24.0]]:
		var w: float = item[1]
		x += w * 0.5 + 2.0
		mb.xform = Transform3D(Basis(Vector3.UP, PI), Vector3(x, 0, 0))
		match item[0]:
			"townhouse2":
				Buildings.townhouse(mb, out, w, 10.0, 2, rng)
			"townhouse3":
				Buildings.townhouse(mb, out, w, 10.0, 3, rng)
			"shotgun":
				Buildings.shotgun(mb, out, w, 13.0, rng)
			"damaged":
				Buildings.shotgun(mb, out, w, 13.0, rng, true)
			"apartment":
				Buildings.ward_apartment(mb, out, w, 11.0, rng)
			"tower":
				Buildings.tower(mb, out, w, 16.0, 20.0, rng)
			"warehouse":
				Buildings.warehouse(mb, out, w, 14.0, 9.0, rng, 9)
		x += w * 0.5 + 2.0
	mb.xform = Transform3D.IDENTITY
	return mb


func _landmarks() -> MeshBuilder:
	var mb := MeshBuilder.new()
	var out: Array = []
	var spots := [Vector3(-75, 0, 275), Vector3(-25, 0, 275), Vector3(25, 0, 275), Vector3(75, 0, 275), Vector3(-75, 0, 325), Vector3(-25, 0, 325), Vector3(25, 0, 325), Vector3(75, 0, 325)]
	for i in spots.size():
		mb.xform = Transform3D(Basis(Vector3.UP, PI if i < 6 else 0.0), spots[i])
		match i:
			0: Buildings.union_station(mb, out)
			1: Buildings.aurum_tower(mb, out, rng)
			2: Buildings.blue_lantern(mb, out, rng)
			3: Buildings.precinct(mb, out)
			4: Buildings.clinic(mb, out)
			5:
				Buildings.streetcar_depot(mb, out)
				Props.streetcar(mb, out, Vector3(0, 0, 2), true)
			6: Buildings.lantern_square(mb, out, Props, rng)
			7: Buildings.courts(mb, out, Props)
	mb.xform = Transform3D.IDENTITY
	return mb


func _vehicles_and_people() -> MeshBuilder:
	var mb := MeshBuilder.new()
	var kinds := VehicleKit.KINDS.keys()
	for i in kinds.size():
		mb.xform = Transform3D(Basis(Vector3.UP, PI * 0.15), Vector3(-15.0 + i * 6.0, 0, 596))
		VehicleKit.build(mb, kinds[i], VehicleKit.PAINTS[i % VehicleKit.PAINTS.size()])
	var looks: Array = []
	for i in 9:
		looks.append(CharacterKit.random_look(rng))
	looks[0] = {"shirt": Color(0.85, 0.18, 0.2), "pants": Color(0.18, 0.3, 0.55), "skin": CharacterKit.SKIN[2], "hair": "short", "hair_color": CharacterKit.HAIR[0]}
	looks[1] = {"shirt": Color(0.2, 0.3, 0.6), "pants": Color(0.1, 0.12, 0.2), "hair": "police", "hat": Color(0.1, 0.14, 0.3), "skin": CharacterKit.SKIN[1]}
	for i in looks.size():
		mb.xform = Transform3D(Basis(Vector3.UP, PI), Vector3(-12.0 + i * 3.0, 0, 605))
		CharacterKit.build(mb, looks[i])
	mb.xform = Transform3D.IDENTITY
	return mb


func _props() -> MeshBuilder:
	var mb := MeshBuilder.new()
	var out: Array = []
	var z := 895.0
	Props.gas_lamp(mb, out, Vector3(-16, 0, z))
	Props.street_light(mb, out, Vector3(-13, 0, z), Vector3.BACK)
	Props.traffic_light(mb, out, Vector3(-10, 0, z), Vector3.BACK)
	Props.power_pole(mb, out, Vector3(-7, 0, z), Vector3(-1, 0, z))
	Props.power_pole(mb, out, Vector3(-1, 0, z))
	Props.oak(mb, out, Vector3(4, 0, z), rng)
	Props.crepe_myrtle(mb, out, Vector3(9, 0, z), rng)
	Props.planter(mb, out, Vector3(12, 0, z))
	Props.hydrant(mb, out, Vector3(-16, 0, z + 6))
	Props.bench(mb, out, Vector3(-13, 0, z + 6), PI)
	Props.trash_can(mb, out, Vector3(-10, 0, z + 6))
	Props.mailbox(mb, out, Vector3(-8, 0, z + 6))
	Props.crate(mb, out, Vector3(-5, 0, z + 6))
	Props.barrel(mb, out, Vector3(-3, 0, z + 6))
	Props.fence(mb, out, Vector3(0, 0, z + 6), Vector3(6, 0, z + 6), Color(0.62, 0.52, 0.4))
	Props.container(mb, out, Vector3(11, 0, z + 6), Props.CONTAINERS[0])
	mb.box(Vector3(0, -0.05, z + 12), Vector3(36, 0.1, 6), Color(0.2, 0.2, 0.23))
	Props.rails(mb, Vector3(-18, 0, z + 12), Vector3(18, 0, z + 12))
	Props.crosswalk(mb, Vector3(10, 0, z + 12), Vector3.RIGHT, 6.0)
	Props.manhole(mb, Vector3(-12, 0, z + 12))
	mb.xform = Transform3D(Basis(Vector3.UP, PI / 2), Vector3(-4, 0, z + 12))
	Props.streetcar(mb, out, Vector3.ZERO)
	mb.xform = Transform3D.IDENTITY
	return mb


func _setup_world() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	sun.light_energy = 0.7
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 200.0
	add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.7, 0.85)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.8, 0.88)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var ground := MeshBuilder.new()
	ground.box(Vector3(0, -0.1, 450), Vector3(400, 0.2, 1200), Color(0.58, 0.56, 0.52))
	add_child(ground.make_instance())
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.rotation_degrees = Vector3(-60.0, 0.0, 0.0)
	camera.near = 1.0
	camera.far = 400.0
	add_child(camera)


func _shot(mb: MeshBuilder, center: Vector3, view: float, file: String) -> void:
	var inst := mb.make_instance()
	add_child(inst)
	camera.size = view
	camera.global_position = center + camera.global_basis.z * 150.0
	print("%s: %d triangles" % [file, mb.triangle_count()])
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))
