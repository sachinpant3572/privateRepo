extends Node
## Shimmer and z-fighting probe (HANDOFF-shimmer.md): at each spot and zoom
## it shoots a frame, nudges the camera by a third of a pixel and shoots
## again, with the world paused and no people or traffic. What changes
## between the pair is what crawls or flickers as the camera moves:
## aliasing on thin lines and fine patterns, and coplanar layers fighting.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 \
##     --resolution 1280x720 res://tests/shimmer_shots.tscn -- <out_dir>
## Then e.g. `compare -fuzz 4% -metric AE a.png b.png diff.png`.
## AA=1 turns 4x MSAA on (Settings > Anti-aliasing); QUALITY=low|medium|high|ultra.
## ZPROBE=1 isolates z-fighting instead: shadows off, the pair is shot from
## the same place with the near plane at its usual value (or ZNEAR) and at
## 1.5 times that. Only depth precision differs, so any pixel that changes
## is two surfaces fighting. It also adds a zoomed-out "far" view.

const MainScene = preload("res://main.tscn")
const Terrain = preload("res://scripts/terrain.gd")
const GraphicsScript = preload("res://scripts/graphics.gd")

var out_dir := "user://"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0]
	_run.call_deferred()


func _run() -> void:
	var game = MainScene.instantiate()
	game.settings["camera_turn"] = "north"
	game.missions_enabled = false
	game.save_enabled = false
	game.population_enabled = false
	add_child(game)
	game.atmosphere.hour = 15.0
	game.atmosphere.minutes_per_second = 0.0
	game.atmosphere.weather_changes = false
	var q := OS.get_environment("QUALITY")
	if q != "":
		GraphicsScript.pick(game.settings, q)
	if OS.get_environment("AA") != "":
		game.settings["aa"] = OS.get_environment("AA") == "1"
	game.graphics.apply(game.settings)
	await _frames(120)
	var city = game.city
	var spots := []
	for lm in ["lantern_square", "aurum_tower", "moreau_house", "city_hall", "union_station"]:
		spots.append([lm, city.landmark_frame(lm) * Vector3.ZERO])
	for cls in ["boulevard", "avenue", "street", "quarter", "quay"]:
		spots.append([cls, _edge_of(city, cls)])
	spots.append_array(_country_spots(city.country))
	var zprobe := OS.get_environment("ZPROBE") == "1"
	if zprobe:
		game.atmosphere.sun.shadow_enabled = false
	var views := [["foot", 26.0], ["drive", 62.0]]
	if zprobe:
		views.append(["far", 80.0])
	var only := OS.get_environment("ONLY")
	for s: Array in spots:
		if only != "" and not str(s[0]) in only.split(","):
			continue
		var at: Vector3 = s[1]
		at.y = Terrain.height(at.x, at.z)
		city.stream_now(at)
		game.player.global_position = at + Vector3(0, 0.5, 0)
		game.player.reset_physics_interpolation()
		for view: Array in views:
			game.camera.fixed_focus = at
			game.camera.room_size = view[1]
			game.camera.snap()
			await _frames(90)
			get_tree().paused = true
			await _frames_idle(3)
			var name := "%s_%s" % [s[0], view[0]]
			var cam: Camera3D = game.camera
			var keep := cam.global_transform
			var keep_near := cam.near
			if zprobe:
				var z0 := float(OS.get_environment("ZNEAR")) if OS.get_environment("ZNEAR") != "" else cam.near
				cam.near = z0
				await _frames_idle(2)
				await _shot(name + "_a.png")
				print("near ", name, " ", z0)
				cam.near = z0 * 1.5
			else:
				await _shot(name + "_a.png")
				# A third of a pixel sideways and a little up.
				var px: float = view[1] / 720.0
				cam.global_position += cam.global_basis.x * px * 0.33 + cam.global_basis.y * px * 0.21
				cam.reset_physics_interpolation()
			await _frames_idle(2)
			await _shot(name + "_b.png")
			cam.global_transform = keep
			cam.near = keep_near
			cam.reset_physics_interpolation()
			get_tree().paused = false
	get_tree().quit()


## Country spots where thin layers meet: the two junctions nearest the city
## whose roads differ in surface (the pad lies 3 mm over the road strips),
## and the driveway nearest the first (2 mm over road and ground).
func _country_spots(c) -> Array:
	var found := []
	if c == null:
		return found
	var CT = load("res://scripts/country_tiles.gd")
	var cands := []
	for n in c.node_pos.size():
		if c.degree(n) < 3 or c.links.has(n):
			continue
		var kinds := {}
		for e in c.edges_of(n):
			kinds[CT.road_surface(c, e)] = true
		if kinds.size() > 1:
			cands.append([c.pos(n).distance_to(Vector2(600, 600)), c.pos(n)])
	cands.sort_custom(func(a, b): return a[0] < b[0])
	for i in mini(2, cands.size()):
		var p: Vector2 = cands[i][1]
		found.append(["junction%d" % (i + 1), Vector3(p.x, 0, p.y)])
	if not cands.is_empty() and not c.paths.is_empty():
		var j: Vector2 = cands[0][1]
		var best := Vector2.ZERO
		var best_d := INF
		for path: Array in c.paths:
			var a := Vector2(path[0][0], path[0][1])
			if a.distance_to(j) < best_d:
				best_d = a.distance_to(j)
				best = a
		found.append(["driveway", Vector3(best.x, 0, best.y)])
	return found


## The middle of the longest edge of class `cls` nearest the plan's middle.
func _edge_of(city, cls: String) -> Vector3:
	var plan = city.plan
	var best := Vector3.ZERO
	var best_d := INF
	for e in plan.edge_count():
		if plan.edge_class(e) != cls:
			continue
		var pa: Vector2 = plan.pos(plan.edge_a[e])
		var pb: Vector2 = plan.pos(plan.edge_b[e])
		if pa.distance_to(pb) < 60.0:
			continue
		var m := (pa + pb) * 0.5
		var d := m.distance_to(Vector2(600, 600))
		if d < best_d:
			best_d = d
			best = Vector3(m.x, 0, m.y)
	return best


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(file))
	print("saved ", file)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _frames_idle(n: int) -> void:
	for i in n:
		await RenderingServer.frame_post_draw
