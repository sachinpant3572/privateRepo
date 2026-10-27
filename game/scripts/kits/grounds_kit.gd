extends RefCounted
## The grounds of country plots (HANDOFF-plots.md): estate gardens, cluster
## yards, farmyards and fields. tools/build_country.py lays every plot out
## as parts [kind, x, z, w, d, rot, variant] in the plot frame (x along the
## road, the road at -Z); this draws one part. A rect part spans w across and
## d along its own z; a line part (wall, hedge, fence, gate, trees) runs w
## along its own x and is d thick (trees: d apart). Static functions only,
## no scene tree, so a tile builds on a worker thread (like country_kit.gd).

const MeshBuilder = preload("res://scripts/mesh_builder.gd")
const Kit = preload("res://scripts/kits/country_kit.gd")
const Props = preload("res://scripts/kits/prop_kit.gd")

## Surfaces stack under the lots' own pads (country_kit _pad tops at 0.03):
## the plot's base, then gravel and tracks, then painted lines.
const BASE_Y := -0.005
const SURFACE_Y := 0.005
const LINE_Y := 0.03

const LAWN := Color(0.42, 0.6, 0.3)
const YARD := Color(0.48, 0.52, 0.3)
const WET_YARD := Color(0.36, 0.43, 0.26)
const DIRT := Color(0.55, 0.45, 0.33)
const GRAVEL := Color(0.68, 0.65, 0.58)
const STUCCO := Color(0.93, 0.9, 0.82)
const COPING := Color(0.82, 0.78, 0.7)
const WOOD := Color(0.45, 0.33, 0.22)
const WHITE_WOOD := Color(0.92, 0.91, 0.87)
const IRON := Color(0.14, 0.15, 0.16)
const COURT := Color(0.24, 0.45, 0.48)
const COURT_RUN := Color(0.32, 0.5, 0.38)
const STONE := Color(0.8, 0.78, 0.72)
const WATER := Color(0.3, 0.62, 0.72)
const SOIL := Color(0.4, 0.31, 0.22)
const FLOWERS := [Color(0.9, 0.35, 0.45), Color(0.95, 0.85, 0.4), Color(0.92, 0.92, 0.95), Color(0.7, 0.4, 0.75)]
## Crops: ground, rows, row height, rows lit like grass.
const CROPS := [
	[Color(0.8, 0.68, 0.34), Color(0.86, 0.74, 0.38), 0.5, false], # wheat
	[Color(0.36, 0.5, 0.22), Color(0.42, 0.58, 0.26), 0.7, true], # soy, cane
	[Color(0.44, 0.34, 0.24), Color(0.38, 0.29, 0.2), 0.12, false], # ploughed
	[Color(0.66, 0.62, 0.38), Color(0.6, 0.55, 0.3), 0.0, false], # stubble and bales
]


## Draws one part of a plot. mb.xform holds the plot's frame; colliders go
## to `out` in that frame ([centre, size, yaw]).
static func draw(kind: String, p: Array, tree_kinds: Array, mb, out: Array, rng: RandomNumberGenerator) -> void:
	var w: float = p[3]
	var d: float = p[4]
	var base: Transform3D = mb.xform
	var t := Transform3D(Basis(Vector3.UP, float(p[5])), Vector3(p[1], 0.0, p[2]))
	mb.xform = base * t
	var local: Array = []
	var v := int(p[6])
	match kind:
		"lawn":
			Kit._pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, MeshBuilder.glow(LAWN, MeshBuilder.GRASS), BASE_Y)
		"yard":
			_yard(mb, w, d, v == 1, rng)
		"gravel", "drive":
			var col := GRAVEL if kind == "gravel" else GRAVEL.lightened(0.12)
			Kit._pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, MeshBuilder.glow(col, MeshBuilder.CONCRETE), SURFACE_Y)
		"track":
			Kit._pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, MeshBuilder.glow(DIRT, MeshBuilder.CONCRETE), SURFACE_Y)
			for s: float in [-1.0, 1.0]:
				Kit._pad(mb, s * w * 0.25 - 0.25, s * w * 0.25 + 0.25, -d * 0.5, d * 0.5, DIRT.darkened(0.15), SURFACE_Y + 0.004)
		"wall":
			_wall(mb, local, w, d)
		"hedge":
			Kit._hedge(mb, local, Vector3(-w * 0.5, 0, 0), Vector3(w * 0.5, 0, 0), 1.8, true, maxf(d, 0.9))
		"fence":
			_fence(mb, local, w, v)
		"gate":
			_gate(mb, local, w)
		"trees":
			var n := 1 if w < 0.1 else int(w / maxf(d, 1.0)) + 1
			for i in n:
				var x := 0.0 if n == 1 else -w * 0.5 + w * i / (n - 1)
				_tree(mb, local, Vector3(x, 0, 0), tree_kinds[v] if v < tree_kinds.size() else "oak", rng)
		"court":
			_court(mb, local, w * 0.5, rng)
		"parterre":
			_parterre(mb, local, w, d, rng)
		"tennis":
			_tennis(mb, local, w, d)
		"orchard":
			var cols := maxi(1, int((w - 2.0) / 6.5))
			var rows := maxi(1, int((d - 2.0) / 6.5))
			for i in cols:
				for k in rows:
					var x := -w * 0.5 + (i + 0.5) * w / cols
					var z := -d * 0.5 + (k + 0.5) * d / rows
					_tree(mb, local, Vector3(x, 0, z), "fruit", rng)
		"crop":
			_crop(mb, w, d, v, rng)
		"vines":
			_vines(mb, w, d)
		"boat":
			_boat(mb, w, d, rng)
		"woodpile":
			for i in 5:
				var y := 0.2 + (i / 3) * 0.35
				var x := -0.6 + (i % 3) * 0.45 + (0.2 if i >= 3 else 0.0)
				mb.limb(Vector3(x, y, -w * 0.5), Vector3(x, y, w * 0.5), 0.18, 0.18, WOOD.lightened(rng.randf() * 0.15), 6)
		"garden":
			Kit._pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, SOIL, SURFACE_Y)
			var leaf := MeshBuilder.glow(Color(0.35, 0.55, 0.25), MeshBuilder.GRASS)
			for r in int(d / 1.2):
				mb.box(Vector3(0, 0.2, -d * 0.5 + 0.6 + r * 1.2), Vector3(w - 0.8, 0.4, 0.5), leaf)
	mb.xform = base
	for col in local:
		out.append([t * col[0], col[1], float(p[5]) + (col[2] if col.size() > 2 else 0.0)])


# --- Grounds ------------------------------------------------------------------------

static func _yard(mb, w: float, d: float, wet: bool, rng: RandomNumberGenerator) -> void:
	var col := WET_YARD if wet else YARD
	# Plain colour: the grass code's mowing stripes read as a crop field.
	Kit._pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, col, BASE_Y)
	# Worn patches.
	for i in rng.randi_range(3, 6):
		var c := Vector2(rng.randf_range(-w * 0.4, w * 0.4), rng.randf_range(-d * 0.4, d * 0.4))
		var r := rng.randf_range(2.0, 4.5)
		var poly := PackedVector2Array()
		for k in 10:
			var a := TAU * k / 10.0
			poly.append(c + Vector2(cos(a), sin(a)) * r * rng.randf_range(0.7, 1.1))
		mb.flat(poly, BASE_Y + 0.013, MeshBuilder.glow(DIRT.lerp(col, 0.35), MeshBuilder.CONCRETE))


## A stuccoed garden wall with piers and a coping, 1.8 m.
static func _wall(mb, out: Array, w: float, d: float) -> void:
	const H := 1.8
	var t := maxf(d, 0.4)
	mb.box(Vector3(0, H * 0.5, 0), Vector3(w, H, t), MeshBuilder.glow(STUCCO, MeshBuilder.CONCRETE))
	mb.box(Vector3(0, H + 0.06, 0), Vector3(w + 0.1, 0.12, t + 0.16), COPING)
	var n := maxi(1, int(w / 8.0))
	for i in n + 1:
		var x := -w * 0.5 + w * i / n
		mb.box(Vector3(x, (H + 0.3) * 0.5, 0), Vector3(0.7, H + 0.3, t + 0.3), MeshBuilder.glow(STUCCO.darkened(0.04), MeshBuilder.CONCRETE))
	out.append([Vector3(0, H * 0.5, 0), Vector3(w, H, t + 0.1)])


## A post-and-wire fence (variant 0) or a white board fence (1), 1.2 m.
static func _fence(mb, out: Array, w: float, v: int) -> void:
	var col := WHITE_WOOD if v == 1 else WOOD
	var n := maxi(1, int(w / 2.5))
	for i in n + 1:
		mb.box(Vector3(-w * 0.5 + w * i / n, 0.6, 0), Vector3(0.12, 1.2, 0.12), col)
	var rails := [0.45, 0.8, 1.1] if v == 1 else [0.55, 1.0]
	for y: float in rails:
		mb.box(Vector3(0, y, 0), Vector3(w, 0.12 if v == 1 else 0.03, 0.04), col if v == 1 else IRON.lightened(0.3))
	out.append([Vector3(0, 0.6, 0), Vector3(w, 1.2, 0.2)])


## Gate piers with lamps at both ends of the gap, the leaves swung open.
static func _gate(mb, out: Array, w: float) -> void:
	var stone := MeshBuilder.glow(STUCCO.darkened(0.06), MeshBuilder.CONCRETE)
	var lamp := MeshBuilder.glow(Color(1.0, 0.9, 0.6), MeshBuilder.GLOW_LAMP)
	for s: float in [-1.0, 1.0]:
		var x := s * (w * 0.5 + 0.1)
		mb.box(Vector3(x, 1.2, 0), Vector3(1.0, 2.4, 1.0), stone)
		mb.box(Vector3(x, 2.45, 0), Vector3(1.2, 0.1, 1.2), COPING)
		mb.ball(Vector3(x, 2.75, 0), Vector3(0.28, 0.28, 0.28), lamp, 6, 3)
		out.append([Vector3(x, 1.2, 0), Vector3(1.0, 2.4, 1.0)])
		# A leaf of iron bars, swung in and back against the wall, clear of the drive.
		var hinge := Vector3(s * (w * 0.5 - 0.4), 0, 0.5)
		var leaf := w * 0.45
		var dir := Vector3(s * 0.26, 0, 0.97)
		var leaf_yaw := atan2(-dir.z, dir.x)
		out.append([hinge + dir * leaf * 0.5 + Vector3(0, 1.0, 0), Vector3(leaf, 2.0, 0.12), leaf_yaw])
		var saved: Transform3D = mb.xform
		mb.xform = saved * Transform3D(Basis(Vector3.UP, leaf_yaw), hinge)
		mb.box(Vector3(leaf * 0.5, 1.75, 0), Vector3(leaf, 0.08, 0.06), IRON)
		mb.box(Vector3(leaf * 0.5, 0.25, 0), Vector3(leaf, 0.08, 0.06), IRON)
		for k in int(leaf / 0.3):
			mb.box(Vector3(0.15 + k * 0.3, 1.0, 0), Vector3(0.04, 1.6, 0.04), IRON)
		mb.xform = saved


static func _tree(mb, out: Array, p: Vector3, kind: String, rng: RandomNumberGenerator) -> void:
	match kind:
		"palm":
			Props.palm(mb, out, p, rng)
		"cypress":
			Kit._cypress(mb, out, p, rng.randf_range(7.0, 10.0), rng)
		"fruit":
			var leaf := MeshBuilder.glow(Color(0.3, 0.48, 0.22).lerp(Color(0.4, 0.55, 0.26), rng.randf()), MeshBuilder.GRASS)
			mb.limb(p, p + Vector3(0, 1.2, 0), 0.14, 0.11, Props.BARK, 5, false)
			mb.clump(p + Vector3(0, 2.2, 0), Vector3(1.7, 1.3, 1.7), leaf, rng.randi(), 7, 3, 0.22)
			out.append([p + Vector3(0, 1.0, 0), Vector3(0.4, 2.0, 0.4)])
		_:
			Props.oak(mb, out, p, rng)


## A round gravel garden with a fountain in the middle and shrubs round it.
static func _court(mb, out: Array, r: float, rng: RandomNumberGenerator) -> void:
	var ring := PackedVector2Array()
	for k in 24:
		var a := TAU * k / 24.0
		ring.append(Vector2(cos(a), sin(a)) * r)
	mb.flat(ring, SURFACE_Y + 0.006, MeshBuilder.glow(GRAVEL.lightened(0.12), MeshBuilder.CONCRETE))
	_fountain(mb, out, Vector3.ZERO, minf(2.6, r * 0.35))
	var leaf := Kit.LEAF.lightened(0.08)
	for k in 8:
		var a := TAU * (k + 0.5) / 8.0
		Kit._bush(mb, Vector3(cos(a), 0, sin(a)) * (r - 1.4), 0.9, rng, leaf)


static func _fountain(mb, out: Array, c: Vector3, r: float) -> void:
	var stone := MeshBuilder.glow(STONE, MeshBuilder.CONCRETE)
	mb.cylinder(c, r, 0.55, stone, 12)
	mb.cylinder(c + Vector3(0, 0.55, 0), r - 0.25, 0.01, MeshBuilder.glow(WATER, MeshBuilder.GLOSS), 12)
	mb.cylinder(c, 0.25, 1.6, stone, 6)
	mb.cylinder(c + Vector3(0, 1.6, 0), 0.7, 0.14, stone, 8)
	out.append([c + Vector3(0, 0.4, 0), Vector3(r * 1.6, 0.8, r * 1.6)])


## A formal garden: box hedges round four beds of flowers, gravel walks
## crossing in the middle at an urn. Mirror-symmetric both ways.
static func _parterre(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var walk := MeshBuilder.glow(GRAVEL.lightened(0.12), MeshBuilder.CONCRETE)
	Kit._pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, walk, SURFACE_Y)
	var flower: Color = FLOWERS[rng.randi() % FLOWERS.size()]
	var path := 2.0
	var bw := (w - path * 3.0) * 0.5
	var bd := (d - path * 3.0) * 0.5
	if bw < 1.5 or bd < 1.5:
		return
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var c := Vector3(sx * (path * 0.5 + bw * 0.5), 0, sz * (path * 0.5 + bd * 0.5))
			Kit._pad(mb, c.x - bw * 0.5, c.x + bw * 0.5, c.z - bd * 0.5, c.z + bd * 0.5, MeshBuilder.glow(LAWN.lightened(0.04), MeshBuilder.GRASS), SURFACE_Y + 0.006)
			for k: Array in [[Vector3(-bw * 0.5, 0, -bd * 0.5), Vector3(bw * 0.5, 0, -bd * 0.5)], [Vector3(-bw * 0.5, 0, bd * 0.5), Vector3(bw * 0.5, 0, bd * 0.5)],
					[Vector3(-bw * 0.5, 0, -bd * 0.5), Vector3(-bw * 0.5, 0, bd * 0.5)], [Vector3(bw * 0.5, 0, -bd * 0.5), Vector3(bw * 0.5, 0, bd * 0.5)]]:
				Kit._hedge(mb, out, c + k[0], c + k[1], 0.6, false, 0.5)
			if bw > 3.0 and bd > 3.0:
				mb.box(c + Vector3(0, 0.12, 0), Vector3(bw - 2.4, 0.24, bd - 2.4), flower)
	mb.cylinder(Vector3.ZERO, 0.7, 0.5, MeshBuilder.glow(STONE, MeshBuilder.CONCRETE), 8)
	mb.ball(Vector3(0, 0.9, 0), Vector3(0.55, 0.45, 0.55), MeshBuilder.glow(STONE, MeshBuilder.CONCRETE), 8, 3)
	out.append([Vector3(0, 0.5, 0), Vector3(1.2, 1.0, 1.2)])


## A tennis court (36.6 x 18.3 m fence to fence, its length along z) behind
## a chain-link fence.
static func _tennis(mb, out: Array, w: float, d: float) -> void:
	Kit._pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, MeshBuilder.glow(COURT_RUN, MeshBuilder.PAVING), SURFACE_Y)
	var cw := 10.97
	var cl := 23.77
	Kit._pad(mb, -cw * 0.5, cw * 0.5, -cl * 0.5, cl * 0.5, MeshBuilder.glow(COURT, MeshBuilder.PAVING), SURFACE_Y + 0.006)
	var white := Color(0.95, 0.95, 0.93)
	for x: float in [-cw * 0.5, -4.115, 4.115, cw * 0.5]:
		Kit._line(mb, Vector3(x, 0, -cl * 0.5), Vector3(x, 0, cl * 0.5), 0.08, white)
	for z: float in [-cl * 0.5, -6.4, 6.4, cl * 0.5]:
		var half := cw * 0.5 if absf(z) > 7.0 else 4.115
		Kit._line(mb, Vector3(-half, 0, z), Vector3(half, 0, z), 0.08, white)
	Kit._line(mb, Vector3(0, 0, -6.4), Vector3(0, 0, 6.4), 0.08, white)
	# Net and posts.
	mb.box(Vector3(0, 0.5, 0), Vector3(cw + 0.9, 0.9, 0.03), Color(0.12, 0.12, 0.13))
	mb.box(Vector3(0, 0.95, 0), Vector3(cw + 0.9, 0.06, 0.05), white)
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(s * (cw * 0.5 + 0.45), 0.55, 0), Vector3(0.1, 1.1, 0.1), IRON)
	# Fence: posts, rails and a dark mesh.
	const H := 3.0
	var mesh_col := Color(0.18, 0.24, 0.2)
	for side: Array in [[Vector3(-w * 0.5, 0, -d * 0.5), Vector3(w * 0.5, 0, -d * 0.5)], [Vector3(-w * 0.5, 0, d * 0.5), Vector3(w * 0.5, 0, d * 0.5)],
			[Vector3(-w * 0.5, 0, -d * 0.5), Vector3(-w * 0.5, 0, d * 0.5)], [Vector3(w * 0.5, 0, -d * 0.5), Vector3(w * 0.5, 0, d * 0.5)]]:
		var a: Vector3 = side[0]
		var b: Vector3 = side[1]
		var length := a.distance_to(b)
		var n := maxi(1, int(length / 3.0))
		for i in n + 1:
			var q := a.lerp(b, float(i) / n)
			mb.box(q + Vector3(0, H * 0.5, 0), Vector3(0.08, H, 0.08), IRON)
		var c := (a + b) * 0.5
		var size := Vector3(absf(b.x - a.x) + 0.05, H - 0.2, absf(b.z - a.z) + 0.05)
		mb.box(c + Vector3(0, H * 0.5, 0), size, mesh_col)
		mb.box(c + Vector3(0, H, 0), Vector3(size.x + 0.04, 0.06, size.z + 0.04), IRON)
		out.append([c + Vector3(0, H * 0.5, 0), Vector3(maxf(size.x, 0.2), H, maxf(size.z, 0.2))])


## A crop field: ground in the crop's colour with rows along x, or stubble
## with round bales (variant 3).
static func _crop(mb, w: float, d: float, v: int, rng: RandomNumberGenerator) -> void:
	var crop: Array = CROPS[clampi(v, 0, CROPS.size() - 1)]
	mb.box(Vector3(0, 0.01, 0), Vector3(w, 0.02, d), crop[0])
	if float(crop[2]) > 0.0:
		var rows := int(d / 2.4)
		var col: Color = MeshBuilder.glow(crop[1], MeshBuilder.GRASS) if crop[3] else crop[1]
		for r in rows:
			var z := -d * 0.5 + (r + 0.5) * d / rows
			mb.box(Vector3(0, float(crop[2]) * 0.5, z), Vector3(w - 0.6, float(crop[2]), 1.0), col)
	else:
		for b in rng.randi_range(int(w * d / 160.0), int(w * d / 80.0)):
			var p := Vector3(rng.randf_range(-w * 0.45, w * 0.45), 0.0, rng.randf_range(-d * 0.45, d * 0.45))
			var a := rng.randf() * PI
			var axis := Vector3(cos(a), 0, sin(a)) * 0.6
			mb.limb(p + Vector3(0, 0.7, 0) - axis, p + Vector3(0, 0.7, 0) + axis, 0.7, 0.7, Color(0.78, 0.68, 0.4), 8)


## A vineyard block: trellised rows 2.8 m apart along x, posts at the ends.
static func _vines(mb, w: float, d: float) -> void:
	mb.box(Vector3(0, 0.01, 0), Vector3(w, 0.02, d), Color(0.5, 0.44, 0.32))
	var rows := int(d / 2.8)
	var leaf := MeshBuilder.glow(Color(0.3, 0.45, 0.2), MeshBuilder.GRASS)
	for r in rows:
		var z := -d * 0.5 + (r + 0.5) * d / rows
		mb.box(Vector3(0, 0.7, z), Vector3(w - 1.0, 1.1, 0.8), leaf)
		for x: float in [-w * 0.5 + 0.3, w * 0.5 - 0.3]:
			mb.box(Vector3(x, 0.75, z), Vector3(0.1, 1.5, 0.1), Props.BARK)


## A flat-bottomed skiff pulled up on the ground.
static func _boat(mb, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var hull: Color = [Color(0.9, 0.9, 0.86), Color(0.3, 0.45, 0.4), Color(0.55, 0.38, 0.25)][rng.randi() % 3]
	mb.box(Vector3(0, 0.12, 0), Vector3(w, 0.2, d), hull.darkened(0.2))
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(s * (w * 0.5 - 0.06), 0.4, 0), Vector3(0.1, 0.5, d), hull)
	mb.box(Vector3(0, 0.4, -d * 0.5 + 0.06), Vector3(w, 0.5, 0.1), hull)
	mb.box(Vector3(0, 0.45, d * 0.5 - 0.2), Vector3(w * 0.5, 0.06, 0.5), WOOD)
