extends Node3D
## Asset gallery: every kit piece lined up under the game's 3/4 camera, for
## art review. Needs a real renderer:
##   xvfb-run godot --rendering-driver opengl3 res://tests/gallery.tscn -- <out_dir>

const MeshBuilder = preload("res://scripts/mesh_builder.gd")
const Buildings = preload("res://scripts/kits/building_kit.gd")
const Props = preload("res://scripts/kits/prop_kit.gd")
const VehicleKit = preload("res://scripts/kits/vehicle_kit.gd")
const CharacterKit = preload("res://scripts/kits/character_kit.gd")
const Rig = preload("res://scripts/rig.gd")
const Player = preload("res://scripts/player.gd")
const Cop = preload("res://scripts/cop.gd")
const Cast = preload("res://scripts/missions/cast.gd")

var out_dir := "user://"
var rng := RandomNumberGenerator.new()
var camera := Camera3D.new()
## Paint and glass of the gallery cars (drawn glossy, as in the game).
var vehicle_gloss := MeshBuilder.new()


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0]
	rng.seed = 7
	_setup_world()
	_run.call_deferred()


func _run() -> void:
	await _shot(_buildings(), Vector3(0, 0, 0), 62.0, "gallery_1_buildings.png", true)
	await _shot(_landmarks(), Vector3(0, 0, 300), 108.0, "gallery_2_landmarks.png", true)
	var cars := _vehicles()
	var shell := vehicle_gloss.make_instance()
	shell.material_override = MeshBuilder.gloss_material()
	add_child(shell)
	await _shot(cars, Vector3(0, 0, 598), 22.0, "gallery_3_vehicles.png")
	await _people()
	await _shot(_props(), Vector3(0, 0, 897), 30.0, "gallery_5_props.png", true)
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


func _vehicles() -> MeshBuilder:
	var mb := MeshBuilder.new()
	var kinds := VehicleKit.KINDS.keys()
	for i in kinds.size():
		var row := i / 5
		mb.xform = Transform3D(Basis(Vector3.UP, PI * 0.15), Vector3(-12.0 + (i % 5) * 6.0, 0, 594 + row * 8.0))
		vehicle_gloss.xform = mb.xform
		VehicleKit.build(mb, kinds[i], VehicleKit.PAINTS[i % VehicleKit.PAINTS.size()], vehicle_gloss)
	mb.xform = Transform3D.IDENTITY
	return mb


## People under the game camera, close up. Shot 4: Jules showing the
## animation set, the named cast and police, then two rows of random
## civilians (alternately facing the camera and walking away, some texting).
## Shot 4b: every outfit, facing the camera and from behind.
func _people() -> void:
	var people_rng := RandomNumberGenerator.new()
	people_rng.seed = 11
	var rigs: Array = []
	var poses := ["idle", "walk", "run", "punch", "kick", "phone", "ride", "down"]
	for i in poses.size():
		rigs.append(_person(Player.JULES, poses[i], Vector3(-6.3 + i * 1.8, 0, 744.5)))
	var cop = Cop.new()
	var cast := [cop.look, Cast.REYES, Cast.NIA, Cast.CELESTE, Cast.MARCEL, Cast.REMY, Cast.THIEF, Cast.CREW[0], Cast.CREW[1], Cast.AURUM]
	for i in cast.size():
		rigs.append(_person(cast[i], "walk" if i == 0 else "idle", Vector3(-7.2 + i * 1.6, 0, 747.5)))
	cop.free()
	for row in 2:
		for i in 10:
			var look := CharacterKit.random_look(people_rng)
			var pose := "walk" if i % 3 == 0 else ("text" if look.has("phone") else "idle")
			rigs.append(_person(look, pose, Vector3(-7.2 + i * 1.6, 0, 750.5 + row * 3.0), i % 2 == 1))
	await _pose_and_shoot(rigs, Vector3(0, 0, 748.7), 11.0, "gallery_4_people.png")
	var outfits := ["tee", "hoodie", "polo", "jersey", "bomber", "denim", "puffer", "puffer_vest",
		"blazer", "suit", "jacket", "tank", "dress", "scrubs", "hivis", "delivery"]
	for i in outfits.size():
		var look := CharacterKit.random_look(people_rng, outfits[i])
		var z := 745.0 + (i / 8) * 6.0
		var x := -6.3 + (i % 8) * 1.8
		rigs.append(_person(look, "idle", Vector3(x, 0, z)))
		rigs.append(_person(look, "idle", Vector3(x, 0, z + 2.8), true))
	await _pose_and_shoot(rigs, Vector3(0, 0, 748.7), 11.0, "gallery_4b_outfits.png")


## Runs the rigs for 40 frames (punches and kicks frozen at full reach),
## shoots, then clears them away.
func _pose_and_shoot(rigs: Array, center: Vector3, view: float, file: String) -> void:
	for frame in 40:
		for r in rigs:
			var st = r[1]
			if r[2] == "punch":
				st.punch = clampf(frame / 12.0 * 0.35, 0.0, 0.35)
			if r[2] == "kick":
				st.kick = clampf(frame / 12.0 * 0.4, 0.0, 0.4)
			r[0].pose(st, 1.0 / 60.0)
	var floor_mb := MeshBuilder.new()
	floor_mb.box(center + Vector3(0, -0.5, 0), Vector3(1, 0.2, 1), Color.GRAY)
	await _shot(floor_mb, center, view, file)
	for r in rigs:
		r[0].skeleton.get_parent().queue_free()
	rigs.clear()


## `away` turns the person to walk away from the camera, showing the back.
func _person(look: Dictionary, pose: String, pos: Vector3, away := false) -> Array:
	var skel := CharacterKit.build_rig(look)
	skel.get_node("Body").material_override = MeshBuilder.material()
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = PI * 0.85 if not away else PI * -0.12
	add_child(holder)
	holder.add_child(skel)
	var st = Rig.State.new()
	match pose:
		"walk":
			st.speed = 1.6
			st.texting = look.has("phone")
		"run":
			st.speed = 6.0
			st.run_speed = 6.0
		"phone":
			st.gesture = "phone"
		"text":
			st.texting = true
		"ride":
			st.ride = true
		"down":
			st.down = true
	var rig = Rig.new(skel)
	rig.phase = 1.2
	return [rig, st, pose]


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
	# Present-day street kit.
	Props.bus_shelter(mb, out, Vector3(-14, 0, z - 6), rng)
	Props.ev_charger(mb, out, Vector3(-9, 0, z - 6))
	Props.bike_dock(mb, out, Vector3(-3, 0, z - 6), 4.8, rng)
	Props.scooter(mb, Vector3(3, 0, z - 6), 0.4, Props.SCOOTERS[0])
	Props.bins(mb, out, Vector3(6, 0, z - 6))
	Props.wayfinding(mb, out, Vector3(9, 0, z - 6))
	Props.pay_station(mb, out, Vector3(11.5, 0, z - 6))
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
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.85
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


## `city` draws with the city shader (surface patterns, glass) as streamed
## cells do; vehicles and people keep their own material.
func _shot(mb: MeshBuilder, center: Vector3, view: float, file: String, city := false) -> void:
	var inst := mb.make_instance()
	if city:
		inst.material_override = MeshBuilder.cutaway_material()
		inst.material_override.set_shader_parameter("cut_radius", 0.0) # no player to see
	add_child(inst)
	camera.size = view
	camera.global_position = center + camera.global_basis.z * 150.0
	print("%s: %d triangles" % [file, mb.triangle_count()])
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))
