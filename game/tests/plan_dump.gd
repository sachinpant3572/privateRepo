extends SceneTree
## Builds the street plan alone and writes it as JSON for a quick look
## (tools/plan_preview.py draws it). Run:
##   godot --headless -s res://tests/plan_dump.gd -- out.json

const StreetPlan = preload("res://scripts/street_plan.gd")


func _init() -> void:
	var out_path: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://plan.json"
	var world: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world_map.json"))
	var city: Dictionary = {}
	for c in world.cities:
		if c.id == "bellerive":
			city = c
	var win: Dictionary = city.demo_window
	var origin := Vector2(win.origin[0], win.origin[1])
	var rect := Rect2(Vector2.ZERO, Vector2(win.blocks[0], win.blocks[1]) * win.pitch)
	var river := PackedVector2Array()
	var half := 80.0
	for w in world.water:
		if w.id == "morrow":
			half = w.width * 0.5
			for p in w.line:
				river.append(Vector2(p[0], p[1]) - origin)
	var spots: Array = []
	var names: Array = []
	for lm in world.landmarks:
		if int(lm.get("phase", 1)) > 1:
			continue
		var local := Vector2(lm.pos[0], lm.pos[1]) - origin
		if rect.has_point(local):
			spots.append([lm.id, local])
			names.append(lm.id)
	var edge := PackedVector2Array()
	for q in city.get("core", []):
		edge.append(Vector2(q[0], q[1]) - origin)
	var t0 := Time.get_ticks_msec()
	var plan := StreetPlan.new()
	plan.build(rect, 110.0, 1234, river, half, spots, preload("res://scripts/city.gd").PARK_AT, edge)
	var ms := Time.get_ticks_msec() - t0
	var data := {"ms": ms, "window": [rect.position.x, rect.position.y, rect.size.x, rect.size.y], "nodes": [], "edges": [], "faces": [], "landmarks": [], "park": plan.park_face, "pieces": [], "outline": _arr(edge), "exits": [], "edge_loops": []}
	for x in plan.exits:
		data.exits.append([x.node, x.dir.x, x.dir.y, x.cls, x.road])
	for ring in plan.edge_loops:
		data.edge_loops.append(_arr(ring))
	for p in plan.node_pos:
		data.nodes.append([p.x, p.y])
	for e in plan.edge_count():
		data.edges.append([plan.edge_a[e], plan.edge_b[e], plan.edge_cls[e], plan.edge_road[e]])
	for f in plan.faces.size():
		var face: Dictionary = plan.faces[f]
		var rect_l := plan.lot_rect(f) if face.kind == "land" else Rect2()
		data.faces.append({"kind": face.kind, "poly": _arr(face.poly), "inner": _arr(face.inner), "lot": _arr(face.lot), "rect": [rect_l.size.x, rect_l.size.y]})
	for sp in plan.set_pieces:
		data.pieces.append([sp.id, sp.kind, sp.face])
	data["lakes"] = []
	for lk in plan.lakes:
		data.lakes.append(_arr(lk))
	for k in spots.size():
		data.landmarks.append([names[k], spots[k][1].x, spots[k][1].y, plan.face_of(spots[k][1])])
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	print("plan: %d nodes, %d edges, %d faces in %d ms %s" % [plan.node_count(), plan.edge_count(), plan.faces.size(), ms, plan.timings])
	quit()


func _arr(poly: PackedVector2Array) -> Array:
	var a: Array = []
	for p in poly:
		a.append([snappedf(p.x, 0.1), snappedf(p.y, 0.1)])
	return a
