extends Node
## Measures how much of the street the buildings hide, in the classic
## (orthographic) view and the perspective view, on a 20:9 phone screen:
##   godot --headless res://tests/occlusion_probe.tscn
## For street junctions across the city it reports how often the hero is
## hidden, and how much of the open ground on screen a 1 m tall person
## standing there would be hidden on, by screen third.

const MainScene = preload("res://main.tscn")
const L = preload("res://scripts/layers.gd")
const ASPECT := 20.0 / 9.0
const COLS := 24
const ROWS := 12
## Label, perspective, pitch, field of view.
const MODES := [["ortho60", false, 60.0, 0.0], ["persp60/35", true, 60.0, 35.0], ["persp65/35", true, 65.0, 35.0], ["persp70/35", true, 70.0, 35.0], ["persp60/28", true, 60.0, 28.0]]

var game


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	game = MainScene.instantiate()
	game.missions_enabled = false
	add_child(game)
	for i in 30:
		await get_tree().physics_frame
	var cam = game.camera
	cam.set_process(false)
	var city = game.city
	var win: Rect2 = city.window
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var samples: Array[Vector3] = []
	var groups: Array[String] = []
	var want := int(OS.get_environment("PROBE_N")) if OS.get_environment("PROBE_N") != "" else 160
	# Random open ground (streets, sidewalks, plazas, yards), half of it
	# downtown, where the towers are.
	var tries := 0
	while samples.size() < want and tries < 20000:
		tries += 1
		var p := Vector3(rng.randf_range(win.position.x, win.end.x), 0, rng.randf_range(win.position.y, win.end.y))
		var id := str(city.district_at(p).get("id", "?"))
		var downtown := id in ["gilt_district", "midtown"]
		if downtown != (samples.size() % 2 == 0):
			continue
		city.stream_now(p)
		for i in 2:
			await get_tree().physics_frame
		var space0: PhysicsDirectSpaceState3D = cam.get_world_3d().direct_space_state
		if not space0.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 200, 0), p + Vector3(0, 0.3, 0), L.WORLD)).is_empty():
			continue
		samples.append(p)
		groups.append(id)
	var tower: Vector3 = city.landmark_front("aurum_tower")
	city.stream_now(tower)
	for i in 2:
		await get_tree().physics_frame
	var hits := []
	for dx in range(-60, 61, 6):
		for dz in range(-60, 61, 6):
			var h: Dictionary = cam.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(tower + Vector3(dx, 400, dz), tower + Vector3(dx, -1, dz), L.WORLD))
			if not h.is_empty():
				hits.append(h.position.y)
	hits.sort()
	print("collider tops near the Aurum Tower: max %.0f m, %d hits" % [hits[-1] if hits else 0.0, hits.size()])
	# [mode][size] -> totals
	var stats := {}
	for k in samples.size():
		var p := samples[k]
		city.stream_now(p)
		for i in 3:
			await get_tree().physics_frame
		var space: PhysicsDirectSpaceState3D = cam.get_world_3d().direct_space_state
		for mode in MODES:
			var persp: bool = mode[1]
			cam.rotation_degrees = Vector3(-mode[2], 0, 0)
			for sz in [26.0, 48.0]:
				var key := "%s %d %s" % [mode[0], sz, "downtown" if groups[k] in ["gilt_district", "midtown"] else "other"]
				var s: Dictionary = stats.get(key, {"n": 0, "hero": 0, "seen": [0, 0, 0], "hid": [0, 0, 0]})
				s.n += 1
				var basis: Basis = cam.global_basis
				var back := 220.0
				var half := deg_to_rad(mode[3]) * 0.5
				if persp:
					back = sz * 0.5 / tan(half)
				var eye := p + basis.z * back
				if _hidden(space, p + Vector3(0, 1.0, 0), eye, basis, persp):
					s.hero += 1
				for r in ROWS:
					for c in COLS:
						var u := (c + 0.5) / COLS * 2.0 - 1.0
						var v := (r + 0.5) / ROWS * 2.0 - 1.0
						var o: Vector3
						var dir: Vector3
						if persp:
							o = eye
							dir = (-basis.z + basis.x * u * tan(half) * ASPECT + basis.y * v * tan(half)).normalized()
						else:
							o = eye + basis.x * u * sz * 0.5 * ASPECT + basis.y * v * sz * 0.5
							dir = -basis.z
						var g := o + dir * (-o.y / dir.y)
						# Skip ground under a roof (inside a building).
						if not space.intersect_ray(PhysicsRayQueryParameters3D.create(g + Vector3(0, 200, 0), g + Vector3(0, 1.5, 0), L.WORLD)).is_empty():
							continue
						var third := clampi(int((v + 1.0) / 2.0 * 3.0), 0, 2)
						s.seen[third] += 1
						if _hidden(space, g + Vector3(0, 1.0, 0), eye if persp else g + basis.z * 220.0, basis, persp):
							s.hid[third] += 1
				stats[key] = s
	for key in stats:
		var s: Dictionary = stats[key]
		var hid := 0
		var seen := 0
		var thirds := []
		for t in 3:
			hid += s.hid[t]
			seen += s.seen[t]
			thirds.append("%d%%" % roundi(100.0 * s.hid[t] / maxf(s.seen[t], 1)))
		print("%-22s n=%3d hero hidden %3d%%  street hidden %3d%%  by third (bottom, middle, top) %s" % [key, s.n, roundi(100.0 * s.hero / s.n), roundi(100.0 * hid / maxf(seen, 1)), " ".join(thirds)])
	print("samples %d (%d tries)" % [samples.size(), tries])
	print("probe done")
	get_tree().quit()


## Whether a building stands between `pt` and the eye.
func _hidden(space: PhysicsDirectSpaceState3D, pt: Vector3, eye: Vector3, basis: Basis, persp: bool) -> bool:
	var to := eye if persp else pt + basis.z * 220.0
	var q := PhysicsRayQueryParameters3D.create(pt, to, L.WORLD)
	return not space.intersect_ray(q).is_empty()
