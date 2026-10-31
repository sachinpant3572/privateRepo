extends SceneTree
## Headless check of the shady kit (shady places and run-down blocks). Builds every kind at its default lot,
## at 0.8x and at 1.3x, with a few seeds, prints the triangle and collider
## counts, and checks the kit's contract:
##   - triangles > 0 and within budget (the budget holds at the default lot
##     and smaller; at 1.3x it may grow with the scale, budget * 1.3);
##   - at least one collider for every building kind (props may have none),
##     every collider finite, with a positive size,
##     its centre inside the lot + 1.5 m;
##   - no NaN vertex, and every vertex inside the lot (1.05 m slack past the
##     front edge for pole signs, steps and awnings), none below the ground.
## Run: cd game && godot --headless -s res://tests/shady_check.gd
## Ends with "shady_check: N problems" and exits non-zero on problems.

const Shady = preload("res://scripts/kits/shady_kit.gd")
const MeshBuilder = preload("res://scripts/mesh_builder.gd")

const SCALES := [1.0, 0.8, 1.3]
const SEEDS := [1, 7, 42]
const EPS := 0.06


func _init() -> void:
	var problems := 0
	print("%-22s %6s %10s %10s %6s" % ["kind", "scale", "tris", "budget", "cols"])
	for kind in Shady.kinds():
		var base: Vector2 = Shady.default_size(kind)
		for s in SCALES:
			var size: Vector2 = base * s
			var worst_tris := 0
			var worst_cols := 0
			for seed in SEEDS:
				var mb = MeshBuilder.new()
				var out: Array = []
				var rng := RandomNumberGenerator.new()
				rng.seed = seed
				Shady.build(kind, mb, out, size, rng)
				var tris: int = mb.triangle_count()
				worst_tris = maxi(worst_tris, tris)
				worst_cols = maxi(worst_cols, out.size())
				var where := "%s @%.1f seed %d" % [kind, s, seed]
				var limit := Shady.budget(kind)
				if s > 1.0:
					limit = int(limit * s)
				if tris <= 0:
					print("  FAIL %s: no triangles" % where)
					problems += 1
				elif tris > limit:
					print("  FAIL %s: %d tris over %d" % [where, tris, limit])
					problems += 1
				if out.is_empty() and not (kind in Shady.PROPS):
					print("  FAIL %s: no colliders" % where)
					problems += 1
				if out.size() > 40:
					print("  FAIL %s: %d colliders (over 40)" % [where, out.size()])
					problems += 1
				problems += _check_colliders(out, size, where)
				problems += _check_verts(mb, size, where, -0.05)
			print("%-22s %6.1f %10d %10d %6d" % [kind, s, worst_tris, Shady.budget(kind), worst_cols])
	# Unknown kinds must not crash.
	var mb2 = MeshBuilder.new()
	var out2: Array = []
	Shady.build("no_such_kind", mb2, out2, Vector2(10, 10), RandomNumberGenerator.new())
	print("shady_check: %d problems" % problems)
	quit(1 if problems > 0 else 0)


func _check_colliders(out: Array, size: Vector2, where: String) -> int:
	var bad := 0
	var hx := size.x * 0.5 + 1.5
	var hz := size.y * 0.5 + 1.5
	for i in out.size():
		var c: Array = out[i]
		if c.size() < 2 or c.size() > 4 or (c.size() == 4 and not c[3] is Dictionary):
			print("  FAIL %s: collider %d has %d fields" % [where, i, c.size()])
			bad += 1
			continue
		var p: Vector3 = c[0]
		var sz: Vector3 = c[1]
		if not (p.is_finite() and sz.is_finite()):
			print("  FAIL %s: collider %d not finite" % [where, i])
			bad += 1
			continue
		if c.size() == 3 and not is_finite(float(c[2])):
			print("  FAIL %s: collider %d yaw not finite" % [where, i])
			bad += 1
		if sz.x <= 0.0 or sz.y <= 0.0 or sz.z <= 0.0:
			print("  FAIL %s: collider %d size %s" % [where, i, sz])
			bad += 1
		if absf(p.x) > hx or absf(p.z) > hz:
			print("  FAIL %s: collider %d centre %s outside lot+1.5" % [where, i, p])
			bad += 1
	return bad


func _check_verts(mb, size: Vector2, where: String, floor_y: float) -> int:
	var hx := size.x * 0.5 + EPS
	var front := -size.y * 0.5 - 1.0 - EPS
	var back := size.y * 0.5 + EPS
	var worst := Vector4.ZERO  # how far out: x, front, back, below ground
	var nan := false
	for v in mb.verts:
		if not v.is_finite():
			nan = true
			continue
		worst.x = maxf(worst.x, absf(v.x) - hx)
		worst.y = maxf(worst.y, front - v.z)
		worst.z = maxf(worst.z, v.z - back)
		worst.w = maxf(worst.w, floor_y - v.y)
	var bad := 0
	if nan:
		print("  FAIL %s: NaN or infinite vertex" % where)
		bad += 1
	if worst.x > 0.0 or worst.y > 0.0 or worst.z > 0.0 or worst.w > 0.0:
		print("  FAIL %s: verts outside lot by x %.3f front %.3f back %.3f below %.3f" % [where, worst.x, worst.y, worst.z, worst.w])
		bad += 1
	return bad
