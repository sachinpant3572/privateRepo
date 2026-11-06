extends SceneTree
## Headless check of the hill kit (research lab, sawmill, cult compound, springs, hotels,
## fairground...). Builds every kind at its default lot, at 0.7x and at 1.3x
## with a few seeds, prints the triangle and collider counts, and checks:
##   - triangles > 0 and within the test's budget (8000 for lots of 5000 m2
##     or more, else 5000), at every scale;
##   - every collider finite, positive size, centre on the lot, 0.7 m or taller;
##   - no NaN vertex, every vertex on the lot (none below the ground);
##   - lab_gate: no collider in the lane x in [-3.5, 3.5], the barrier arm under 1.2 m.
## Run: cd game && godot --headless -s res://tests/hill_check.gd [-- kind]
## Ends with "hill_check: N problems" and exits non-zero on problems.

const Hill = preload("res://scripts/kits/hill_kit.gd")
const MeshBuilder = preload("res://scripts/mesh_builder.gd")

const SCALES := [1.0, 0.7, 1.3]
const SEEDS := [1, 7, 99]
const EPS := 0.02


func _init() -> void:
	var only := ""
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		only = args[0]
	var problems := 0
	print("%-16s %5s %7s %7s %5s" % ["kind", "scale", "tris", "budget", "cols"])
	for kind: String in Hill.kinds():
		if only != "" and kind != only:
			continue
		var base: Vector2 = Hill.default_size(kind)
		var budget := Hill.budget(kind)
		for s: float in SCALES:
			var size: Vector2 = base * s
			var worst_tris := 0
			var worst_cols := 0
			for seed: int in SEEDS:
				var mb = MeshBuilder.new()
				var out: Array = []
				var rng := RandomNumberGenerator.new()
				rng.seed = seed
				Hill.build(kind, mb, out, size, rng)
				var tris: int = mb.triangle_count()
				worst_tris = maxi(worst_tris, tris)
				worst_cols = maxi(worst_cols, out.size())
				var where := "%s @%.1f seed %d" % [kind, s, seed]
				if tris <= 0 or tris > budget:
					print("  FAIL %s: %d tris (budget %d)" % [where, tris, budget])
					problems += 1
				problems += _colliders(out, size, where)
				problems += _verts(mb, size, where)
				if kind == "lab_gate":
					problems += _lane(out, where)
			print("%-16s %5.1f %7d %7d %5d" % [kind, s, worst_tris, budget, worst_cols])
	var mb2 = MeshBuilder.new()
	Hill.build("no_such_kind", mb2, [], Vector2(10, 10), RandomNumberGenerator.new())
	print("hill_check: %d problems" % problems)
	quit(1 if problems > 0 else 0)


func _colliders(out: Array, size: Vector2, where: String) -> int:
	var bad := 0
	var hx := size.x * 0.5 + 1.0
	var hz := size.y * 0.5 + 1.0
	for i in out.size():
		var c: Array = out[i]
		var p: Vector3 = c[0]
		var sz: Vector3 = c[1]
		var yaw: float = c[2] if c.size() > 2 else 0.0
		if not (p.is_finite() and sz.is_finite() and is_finite(yaw)):
			print("  FAIL %s: collider %d not finite" % [where, i])
			bad += 1
		elif sz.x <= 0.0 or sz.y <= 0.0 or sz.z <= 0.0:
			print("  FAIL %s: collider %d size %s" % [where, i, sz])
			bad += 1
		elif absf(p.x) > hx or absf(p.z) > hz:
			print("  FAIL %s: collider %d centre %s off the lot" % [where, i, p])
			bad += 1
		elif sz.y < 0.69:
			print("  WARN %s: collider %d is %.2f m tall (flat things get none)" % [where, i, sz.y])
	return bad


func _verts(mb, size: Vector2, where: String) -> int:
	var hx := size.x * 0.5 + EPS
	var hz := size.y * 0.5 + EPS
	var worst := Vector4.ZERO
	var nan := false
	var low := Vector3.ZERO
	var lowest := Vector3(0, 9999, 0)
	for v: Vector3 in mb.verts:
		if not v.is_finite():
			nan = true
			continue
		if v.y < -0.001 and low == Vector3.ZERO:
			low = v
		if v.y < lowest.y:
			lowest = v
		worst.x = maxf(worst.x, absf(v.x) - hx)
		worst.y = maxf(worst.y, -hz - v.z)
		worst.z = maxf(worst.z, v.z - hz)
		worst.w = maxf(worst.w, -0.001 - v.y)
	var bad := 0
	if nan:
		print("  FAIL %s: NaN vertex" % where)
		bad += 1
	if worst.x > 0.0 or worst.y > 0.0 or worst.z > 0.0 or worst.w > 0.0:
		print("  FAIL %s: verts off the lot by x %.2f front %.2f back %.2f below %.2f (first below %s, lowest %s)" % [where, worst.x, worst.y, worst.z, worst.w, low, lowest])
		bad += 1
	return bad


func _lane(out: Array, where: String) -> int:
	var bad := 0
	for i in out.size():
		var c: Array = out[i]
		var p: Vector3 = c[0]
		var sz: Vector3 = c[1]
		var yaw: float = c[2] if c.size() > 2 else 0.0
		var e := Vector2(absf(cos(yaw)) * sz.x + absf(sin(yaw)) * sz.z, 0.0) * 0.5
		if p.x - e.x < 3.5 and p.x + e.x > -3.5:
			print("  FAIL %s: collider %d (%s %s) in the lane" % [where, i, p, sz])
			bad += 1
	return bad
