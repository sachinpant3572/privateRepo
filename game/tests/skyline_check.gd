extends SceneTree
## Headless check of the skyline kit (skyscrapers and monuments). Builds
## every kind at its default lot, at 0.7x and at 1.3x, with four seeds, and
## prints worst triangles, colliders and the height reached. Checks:
##   - triangles > 0 and within budget (at 1.3x the budget may grow with
##     the scale, budget * 1.3);
##   - at least one collider and at most 40, each finite with a positive
##     size and its whole box (turned by its yaw) inside the lot + 0.5 m;
##     at least one standing on the ground (bottom at or below 0.5 m);
##   - no NaN vertex and every vertex inside the lot (no overhang allowed),
##     none below the ground, except hillside_letters, whose scaffold legs
##     reach 2 m down into the slope;
##   - tower heights: the main roof inside the kind's HEIGHTS range (the
##     highest vertex may rise up to 14 m more for masts and spires).
## Run: cd game && godot --headless -s res://tests/skyline_check.gd
## Ends with "skyline_check: N problems" and exits non-zero on problems.

const Skyline = preload("res://scripts/kits/skyline_kit.gd")
const MeshBuilder = preload("res://scripts/mesh_builder.gd")

const SCALES := [1.0, 0.7, 1.3]
const SEEDS := [1, 7, 42, 99]
const EPS := 0.06


func _init() -> void:
	var problems := 0
	print("%-20s %5s %8s %7s %5s %7s %7s" % ["kind", "scale", "tris", "budget", "cols", "top_m", "low_m"])
	for kind in Skyline.kinds():
		var base: Vector2 = Skyline.default_size(kind)
		for s in SCALES:
			var size: Vector2 = base * s
			var worst_tris := 0
			var worst_cols := 0
			var top := 0.0
			var low := 0.0
			for seed in SEEDS:
				var mb = MeshBuilder.new()
				var out: Array = []
				var rng := RandomNumberGenerator.new()
				rng.seed = seed
				Skyline.build(kind, mb, out, size, rng)
				var tris: int = mb.triangle_count()
				worst_tris = maxi(worst_tris, tris)
				worst_cols = maxi(worst_cols, out.size())
				var where := "%s @%.1f seed %d" % [kind, s, seed]
				var limit := Skyline.budget(kind)
				if s > 1.0:
					limit = int(limit * s)
				if tris <= 0:
					print("  FAIL %s: no triangles" % where)
					problems += 1
				elif tris > limit:
					print("  FAIL %s: %d tris over %d" % [where, tris, limit])
					problems += 1
				if out.is_empty():
					print("  FAIL %s: no colliders" % where)
					problems += 1
				if out.size() > 40:
					print("  FAIL %s: %d colliders (over 40)" % [where, out.size()])
					problems += 1
				problems += _check_colliders(out, size, where)
				var floor_y := -2.05 if kind == "hillside_letters" else -0.05
				var ext := _check_verts(mb, size, where, floor_y)
				problems += int(ext.x)
				top = maxf(top, ext.y)
				low = minf(low, ext.z)
				var hr: Vector2 = Skyline.height_range(kind)
				if hr.y > 0.0 and (ext.y < hr.x - 0.5 or ext.y > hr.y + 14.0):
					print("  FAIL %s: top %.1f m outside %s (+14 m for masts)" % [where, ext.y, hr])
					problems += 1
			print("%-20s %5.1f %8d %7d %5d %7.1f %7.2f" % [kind, s, worst_tris, Skyline.budget(kind), worst_cols, top, low])
	# Unknown kinds must not crash.
	var mb2 = MeshBuilder.new()
	var out2: Array = []
	Skyline.build("no_such_kind", mb2, out2, Vector2(10, 10), RandomNumberGenerator.new())
	if mb2.triangle_count() == 0:
		print("  FAIL unknown kind built nothing")
		problems += 1
	print("skyline_check: %d problems" % problems)
	quit(1 if problems > 0 else 0)


func _check_colliders(out: Array, size: Vector2, where: String) -> int:
	var bad := 0
	var hx := size.x * 0.5 + 0.5
	var hz := size.y * 0.5 + 0.5
	var grounded := false
	for i in out.size():
		var c: Array = out[i]
		if c.size() < 2 or c.size() > 4 or (c.size() == 4 and not c[3] is Dictionary):
			print("  FAIL %s: collider %d has %d fields" % [where, i, c.size()])
			bad += 1
			continue
		var p: Vector3 = c[0]
		var sz: Vector3 = c[1]
		var yaw := float(c[2]) if c.size() == 3 else 0.0
		if not (p.is_finite() and sz.is_finite() and is_finite(yaw)):
			print("  FAIL %s: collider %d not finite" % [where, i])
			bad += 1
			continue
		if sz.x <= 0.0 or sz.y <= 0.0 or sz.z <= 0.0:
			print("  FAIL %s: collider %d size %s" % [where, i, sz])
			bad += 1
		var ex := absf(cos(yaw)) * sz.x * 0.5 + absf(sin(yaw)) * sz.z * 0.5
		var ez := absf(sin(yaw)) * sz.x * 0.5 + absf(cos(yaw)) * sz.z * 0.5
		if absf(p.x) + ex > hx or absf(p.z) + ez > hz:
			print("  FAIL %s: collider %d at %s size %s yaw %.2f leaves the lot" % [where, i, p, sz, yaw])
			bad += 1
		if p.y - sz.y * 0.5 <= 0.5:
			grounded = true
	if not out.is_empty() and not grounded:
		print("  FAIL %s: no collider stands on the ground" % where)
		bad += 1
	return bad


## Returns (problems, highest y, lowest y).
func _check_verts(mb, size: Vector2, where: String, floor_y: float) -> Vector3:
	var hx := size.x * 0.5 + EPS
	var hz := size.y * 0.5 + EPS
	var worst := Vector4.ZERO  # how far out: x, front, back, below ground
	var nan := false
	var top := -INF
	var low := INF
	for v in mb.verts:
		if not v.is_finite():
			nan = true
			continue
		worst.x = maxf(worst.x, absf(v.x) - hx)
		worst.y = maxf(worst.y, -hz - v.z)
		worst.z = maxf(worst.z, v.z - hz)
		worst.w = maxf(worst.w, floor_y - v.y)
		top = maxf(top, v.y)
		low = minf(low, v.y)
	var bad := 0
	if nan:
		print("  FAIL %s: NaN or infinite vertex" % where)
		bad += 1
	if worst.x > 0.0 or worst.y > 0.0 or worst.z > 0.0 or worst.w > 0.0:
		print("  FAIL %s: verts outside lot by x %.3f front %.3f back %.3f below %.3f" % [where, worst.x, worst.y, worst.z, worst.w])
		bad += 1
	return Vector3(bad, top, low)
