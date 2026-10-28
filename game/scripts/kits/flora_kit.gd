extends RefCounted
## Wild plants and the hills' ecology (Sachin, 0.23: "more variety of trees,
## in the mountains, bushes, shrubs etc too. And add greenary + dry land a
## mix of both. See gta Vs mountaineous region.").
##
## The Bellerive Hills read like GTA V's Vinewood Hills and Tataviam:
## Southern California chaparral and oak savanna. Sunny south faces are
## golden grass with scattered sage, yucca and a lone oak; north faces and
## canyons are dark scrub oak, chamise and live oak woodland; canyon floors
## carry sycamores and green grass; the cool upper north side has pines;
## ridges and steep faces show rock. Eucalyptus stands in planted groves.
##
## One moisture value (0 dry .. 1 wet) per point drives both the ground
## colour (country_tiles.gd _hill_shade) and which plant grows there, so
## green ground carries green plants. It is built from the face's aspect,
## how low and how sunk in a valley the point lies, and a world-space noise,
## so the patches run on unbroken across tiles.
##
## Static and free of the scene tree (tiles build on worker threads).
## Plants go into a MeshBuilder at p (its ground point) and add
## [center, size, yaw] boxes to `props` for the ones a car should stop at.

const MeshBuilder = preload("res://scripts/mesh_builder.gd")
const Terrain = preload("res://scripts/terrain.gd")

const DRY := Color(0.72, 0.6, 0.36)
const GREEN := Color(0.27, 0.37, 0.18)
const BARK := Color(0.38, 0.27, 0.19)
const PALE_BARK := Color(0.8, 0.77, 0.68)
const RED_BARK := Color(0.5, 0.2, 0.13)
const ROCK := Color(0.56, 0.53, 0.48)
const STRAW := Color(0.8, 0.68, 0.4)
const BLADE := Color(0.4, 0.52, 0.26)

## Every species, for the kit test and the shots.
const KINDS := ["live_oak", "scrub_oak", "sycamore", "eucalyptus", "pine", "manzanita", "toyon",
		"chaparral", "yucca", "prickly_pear", "dry_grass", "green_grass", "rock"]
## Kinds a car drives through (no collider); small rocks too.
const SOFT := ["scrub_oak", "toyon", "chaparral", "yucca", "dry_grass", "green_grass", "prickly_pear", "manzanita"]


# --- Ecology ----------------------------------------------------------------------

## Smooth value noise in 0..1 at world x, z with features about `scale` m
## across; `salt` picks an independent field.
static func noise(x: float, z: float, scale: float, salt: int) -> float:
	var u := x / scale
	var v := z / scale
	var i := floori(u)
	var j := floori(v)
	var fu := u - i
	var fv := v - j
	fu = fu * fu * (3.0 - 2.0 * fu)
	fv = fv * fv * (3.0 - 2.0 * fv)
	var a := lerpf(_lattice(i, j, salt), _lattice(i + 1, j, salt), fu)
	var b := lerpf(_lattice(i, j + 1, salt), _lattice(i + 1, j + 1, salt), fu)
	return lerpf(a, b, fv)


static func _lattice(i: int, j: int, salt: int) -> float:
	return MeshBuilder._hash(i * 7919 + j * 104729 + salt * 1299709)


## Moisture (0 dry .. 1 wet) at world x, z with ground height h and normal n
## (Terrain.normal; -z is north, so a north face has n.z < 0).
static func moisture(x: float, z: float, h: float, n: Vector3) -> float:
	var north := clampf(-n.z * 2.2, -1.0, 1.0)
	var low := clampf(1.0 - h / 45.0, 0.0, 1.0)
	# How far the point sits below the ground 20 m round it: canyon floors.
	var around: float = (Terrain.height(x + 20.0, z) + Terrain.height(x - 20.0, z) + Terrain.height(x, z + 20.0) + Terrain.height(x, z - 20.0)) * 0.25
	var sunk := clampf((around - h) / 6.0, 0.0, 1.0)
	var patch := noise(x, z, 120.0, 1) * 0.65 + noise(x, z, 40.0, 2) * 0.35
	return clampf(0.36 + 0.3 * north + 0.14 * low + 0.3 * sunk + 0.8 * (patch - 0.5), 0.0, 1.0)


## How steep the ground is: 0 flat, about 0.3 at 45 degrees.
static func steep(n: Vector3) -> float:
	return 1.0 - n.y


## The ground colour of wild hill ground: golden grass where dry, green
## where wet, rock on steep faces and near the tops.
static func ground(m: float, n: Vector3, h: float) -> Color:
	var c := DRY.lerp(GREEN, smoothstep(0.26, 0.64, m))
	c = c.lerp(ROCK, clampf((steep(n) - 0.14) * 3.5, 0.0, 0.55))
	return c.lerp(ROCK, clampf((h - 100.0) / 45.0, 0.0, 0.35))


## The plant (one of KINDS) for a wild hill point: weighted by moisture,
## height and steepness; a planted eucalyptus grove where its own noise is
## high on the lower slopes.
static func pick(x: float, z: float, h: float, n: Vector3, m: float, rng: RandomNumberGenerator) -> String:
	var s := steep(n)
	var dry := (1.0 - m) * (1.0 - m)
	var wet_low := clampf((m - 0.55) * 3.0, 0.0, 1.0) * clampf(1.0 - h / 35.0, 0.0, 1.0)
	var mid := maxf(0.0, 1.0 - absf(m - 0.45) * 2.4)
	var w := {
		"rock": 2.5 * clampf((s - 0.12) * 5.0, 0.0, 1.0) + 2.0 * clampf((h - 95.0) / 40.0, 0.0, 1.0),
		"pine": 5.0 * clampf((h - 65.0) / 30.0, 0.0, 1.0) * m,
		"eucalyptus": 6.0 if h < 55.0 and noise(x, z, 70.0, 3) > 0.74 else 0.0,
		"sycamore": 5.0 * wet_low,
		"live_oak": 0.4 + 2.6 * m,
		"scrub_oak": 2.6 * m,
		"toyon": 1.8 * m,
		"chaparral": 3.2 * mid + 1.2 * dry,
		"manzanita": 1.8 * mid,
		"yucca": 2.4 * dry,
		"prickly_pear": 1.4 * dry * (1.0 if h < 70.0 else 0.3),
		"dry_grass": 3.0 * dry,
		"green_grass": 1.2 * wet_low,
	}
	var total := 0.0
	for k in w:
		total += w[k]
	var roll := rng.randf() * total
	for k in w:
		roll -= w[k]
		if roll <= 0.0:
			return k
	return "chaparral"


## A weighted pick from {kind: weight}.
static func pick_from(table: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for k in table:
		total += float(table[k])
	var roll := rng.randf() * total
	for k in table:
		roll -= float(table[k])
		if roll <= 0.0:
			return k
	return table.keys()[0]


# --- Plants -----------------------------------------------------------------------

## Builds `kind` at p. Returns false for a kind this kit does not make.
static func plant(mb, props: Array, p: Vector3, kind: String, rng: RandomNumberGenerator) -> bool:
	match kind:
		"live_oak": live_oak(mb, props, p, rng)
		"scrub_oak": scrub_oak(mb, props, p, rng)
		"sycamore": sycamore(mb, props, p, rng)
		"eucalyptus": eucalyptus(mb, props, p, rng)
		"pine": pine(mb, props, p, rng)
		"manzanita": manzanita(mb, p, rng)
		"toyon": toyon(mb, p, rng)
		"chaparral": chaparral(mb, p, rng)
		"yucca": yucca(mb, props, p, rng)
		"prickly_pear": prickly_pear(mb, p, rng)
		"dry_grass": tufts(mb, p, rng, STRAW, rng.randi_range(3, 5))
		"green_grass": tufts(mb, p, rng, BLADE, rng.randi_range(3, 5))
		"rock": rock(mb, props, p, rng, rng.randf_range(0.8, 2.2))
		_: return false
	return true


static func _leaf(c: Color) -> Color:
	return MeshBuilder.glow(c, MeshBuilder.GRASS)


## Coast live oak: a short trunk splitting into three low limbs under a
## broad, flat, dark crown (wider than tall), as on GTA V's hillsides.
static func live_oak(mb, props: Array, p: Vector3, rng: RandomNumberGenerator) -> void:
	var s := rng.randf_range(0.8, 1.3)
	var seed := rng.randi()
	var leaf := _leaf(Color(0.22, 0.33, 0.17).lerp(Color(0.3, 0.4, 0.2), rng.randf()))
	var fork := p + Vector3(0, 1.6 * s, 0)
	mb.limb(p - Vector3(0, 0.5, 0), fork, 0.36 * s, 0.26 * s, BARK, 6, false)
	var turn := rng.randf() * TAU
	for i in 3:
		var a := turn + TAU * i / 3.0 + rng.randf_range(-0.3, 0.3)
		var d := Vector3(cos(a), 0, sin(a))
		var tip := fork + d * rng.randf_range(1.8, 2.6) * s + Vector3(0, rng.randf_range(0.8, 1.3) * s, 0)
		mb.limb(fork, tip, 0.18 * s, 0.08 * s, BARK, 5, false)
		mb.clump(tip + Vector3(0, 0.4 * s, 0), Vector3(1.9, 1.0, 1.9) * s * rng.randf_range(0.9, 1.1), leaf.lightened(0.05 * (i % 2)), seed + i, 8, 4, 0.26)
	mb.clump(fork + Vector3(0, 1.9, 0) * s, Vector3(2.2, 1.1, 2.2) * s, leaf.lightened(0.06), seed + 7, 9, 4, 0.26)
	props.append([p + Vector3(0, 1.5, 0), Vector3(0.7, 3.0, 0.7), 0.0])


## Scrub oak: a dense, dark, many-stemmed bush 2-4 m across.
static func scrub_oak(mb, _props: Array, p: Vector3, rng: RandomNumberGenerator) -> void:
	var r := rng.randf_range(1.0, 1.9)
	var seed := rng.randi()
	var leaf := _leaf(Color(0.24, 0.32, 0.17).lerp(Color(0.32, 0.38, 0.2), rng.randf()))
	mb.clump(p + Vector3(0, r * 0.7, 0), Vector3(r, r * 0.8, r * rng.randf_range(0.8, 1.0)), leaf, seed, 7, 4, 0.3)
	mb.clump(p + Vector3(r * 0.7, r * 0.55, r * 0.4), Vector3(r, r, r) * 0.6, leaf.darkened(0.08), seed + 1, 6, 3, 0.3)


## Western sycamore: a pale, mottled, leaning trunk and big light-green
## crowns, along the canyon floors.
static func sycamore(mb, props: Array, p: Vector3, rng: RandomNumberGenerator) -> void:
	var s := rng.randf_range(0.9, 1.25)
	var seed := rng.randi()
	var leaf := _leaf(Color(0.4, 0.52, 0.26).lerp(Color(0.48, 0.58, 0.3), rng.randf()))
	var a := rng.randf() * TAU
	var lean := Vector3(cos(a), 0, sin(a)) * 1.4 * s
	var top := p + Vector3(0, 6.5 * s, 0) + lean
	mb.limb(p - Vector3(0, 0.5, 0), top, 0.34 * s, 0.16 * s, PALE_BARK, 6, false)
	var side := p + Vector3(0, 3.0 * s, 0) + lean * 0.4
	mb.limb(side, side + Vector3(-lean.z, 2.6 * s, lean.x), 0.15 * s, 0.08 * s, PALE_BARK.darkened(0.08), 5, false)
	mb.clump(top + Vector3(0, 0.6, 0) * s, Vector3(2.6, 1.7, 2.6) * s, leaf, seed, 9, 4, 0.28)
	mb.clump(side + Vector3(-lean.z, 3.2 * s, lean.x), Vector3(2.0, 1.3, 2.0) * s, leaf.lightened(0.06), seed + 1, 8, 4, 0.28)
	props.append([p + Vector3(0, 1.5, 0), Vector3(0.7, 3.0, 0.7), 0.0])


## Blue gum eucalyptus: a tall, pale, straight trunk with thin, grey-green
## crowns high up (California's windbreaks and groves).
static func eucalyptus(mb, props: Array, p: Vector3, rng: RandomNumberGenerator) -> void:
	var h := rng.randf_range(14.0, 20.0)
	var seed := rng.randi()
	var leaf := _leaf(Color(0.4, 0.48, 0.38).lerp(Color(0.48, 0.54, 0.42), rng.randf()))
	var top := p + Vector3(rng.randf_range(-0.6, 0.6), h, rng.randf_range(-0.6, 0.6))
	mb.limb(p - Vector3(0, 0.5, 0), top, 0.32, 0.1, Color(0.74, 0.7, 0.62), 6, false)
	for i in 3:
		var t := 0.62 + i * 0.14
		var a := rng.randf() * TAU
		var at := p.lerp(top, t) + Vector3(cos(a), 0, sin(a)) * 1.2
		mb.clump(at, Vector3(1.8, 1.6, 1.4) * (1.1 - i * 0.15), leaf.lightened(0.04 * i), seed + i, 6, 4, 0.35)
	props.append([p + Vector3(0, 1.5, 0), Vector3(0.6, 3.0, 0.6), 0.0])


## Ponderosa pine on the cool upper slopes: a red-brown trunk and four
## dark tiers narrowing to a point.
static func pine(mb, props: Array, p: Vector3, rng: RandomNumberGenerator) -> void:
	var h := rng.randf_range(10.0, 16.0)
	var seed := rng.randi()
	var leaf := _leaf(Color(0.17, 0.28, 0.17).lerp(Color(0.23, 0.33, 0.2), rng.randf()))
	mb.limb(p - Vector3(0, 0.5, 0), p + Vector3(0, h * 0.85, 0), 0.32, 0.1, Color(0.45, 0.28, 0.2), 5, false)
	for i in 4:
		var t := 0.36 + i * 0.16
		var r := 2.6 - i * 0.55
		mb.clump(p + Vector3(0, h * t, 0), Vector3(r, 1.3, r), leaf.lightened(i * 0.035), seed + i, 7, 3, 0.25)
	mb.clump(p + Vector3(0, h * 0.97, 0), Vector3(0.5, 1.0, 0.5), leaf.lightened(0.15), seed + 9, 5, 3)
	props.append([p + Vector3(0, 1.5, 0), Vector3(0.6, 3.0, 0.6), 0.0])


## Manzanita: twisting deep-red stems under grey-green leaves.
static func manzanita(mb, p: Vector3, rng: RandomNumberGenerator) -> void:
	var seed := rng.randi()
	var leaf := _leaf(Color(0.42, 0.47, 0.33).lerp(Color(0.5, 0.53, 0.38), rng.randf()))
	var turn := rng.randf() * TAU
	for i in 3:
		var a := turn + TAU * i / 3.0
		var d := Vector3(cos(a), 0, sin(a))
		var tip := p + d * rng.randf_range(0.6, 1.0) + Vector3(0, rng.randf_range(1.2, 1.8), 0)
		mb.limb(p + d * 0.1, tip, 0.08, 0.04, RED_BARK, 4, false)
		mb.clump(tip + Vector3(0, 0.25, 0), Vector3(0.75, 0.5, 0.75), leaf.darkened(0.05 * i), seed + i, 6, 3, 0.3)


## Toyon (California holly): a rounded, glossy, bright-green bush with red
## berry clusters.
static func toyon(mb, p: Vector3, rng: RandomNumberGenerator) -> void:
	var seed := rng.randi()
	var r := rng.randf_range(0.9, 1.5)
	var leaf := _leaf(Color(0.26, 0.4, 0.2).lerp(Color(0.32, 0.47, 0.23), rng.randf()))
	mb.clump(p + Vector3(0, r * 0.75, 0), Vector3(r, r * 0.85, r), leaf, seed, 7, 4, 0.22)
	var berry := MeshBuilder.glow(Color(0.72, 0.14, 0.1), MeshBuilder.GLOSS)
	for i in 4:
		var a := TAU * i / 4.0 + rng.randf()
		mb.box(p + Vector3(cos(a) * r * 0.6, r * 1.3, sin(a) * r * 0.6), Vector3(0.3, 0.12, 0.3), berry)


## Chamise and sage: low, wide, dusty olive clumps.
static func chaparral(mb, p: Vector3, rng: RandomNumberGenerator) -> void:
	var seed := rng.randi()
	var leaf := _leaf(Color(0.33, 0.38, 0.22).lerp(Color(0.46, 0.47, 0.32), rng.randf()))
	var r := rng.randf_range(1.4, 2.6)
	mb.clump(p + Vector3(0, 0.6, 0), Vector3(r, 0.85, r * rng.randf_range(0.7, 1.0)), leaf, seed, 6, 3)
	if rng.randf() < 0.5:
		mb.clump(p + Vector3(r * 0.8, 0.45, rng.randf_range(-1.0, 1.0)), Vector3(r * 0.6, 0.6, r * 0.6), leaf.darkened(0.1), seed + 1, 5, 3)


## Yucca (Our Lord's candle): a ball of stiff grey-green blades, often with
## a tall cream flower spike.
static func yucca(mb, _props: Array, p: Vector3, rng: RandomNumberGenerator) -> void:
	var blade := Color(0.5, 0.56, 0.42)
	var turn := rng.randf() * TAU
	var base := p + Vector3(0, 0.15, 0)
	for i in 12:
		var a := turn + TAU * i / 12.0
		var d := Vector3(cos(a), 0, sin(a))
		var up := 0.4 + 0.6 * MeshBuilder._hash(i * 31 + int(p.x * 3.0))
		var tip := base + (d * (1.0 - up * 0.6) + Vector3(0, up, 0)).normalized() * 1.1
		var side := Vector3(-d.z, 0, d.x) * 0.07
		mb.tri(base - side, base + side, tip, (d + Vector3(0, 0.8, 0)).normalized(), blade.lerp(STRAW, 0.15 * (i % 3)))
	if rng.randf() < 0.55:
		var h := rng.randf_range(2.2, 3.6)
		mb.limb(base, base + Vector3(0, h, 0), 0.05, 0.03, Color(0.55, 0.5, 0.36), 4, false)
		mb.clump(base + Vector3(0, h * 0.85, 0), Vector3(0.28, h * 0.22, 0.28), Color(0.92, 0.9, 0.78), rng.randi(), 5, 3)


## Prickly pear: flat green pads in a low pile.
static func prickly_pear(mb, p: Vector3, rng: RandomNumberGenerator) -> void:
	var pad := Color(0.38, 0.5, 0.28).lerp(Color(0.46, 0.56, 0.32), rng.randf())
	var n := rng.randi_range(4, 7)
	for i in n:
		var a := rng.randf() * TAU
		var at := p + Vector3(cos(a) * rng.randf_range(0.0, 0.6), 0.35 + 0.3 * (i % 3), sin(a) * rng.randf_range(0.0, 0.6))
		var flat := Vector3(0.36, 0.42, 0.1) if i % 2 == 0 else Vector3(0.1, 0.42, 0.36)
		mb.clump(at, flat, pad.darkened(0.05 * (i % 2)), rng.randi(), 5, 3, 0.1)


## A patch of grass tufts in `color` (straw where dry, green where wet).
static func tufts(mb, p: Vector3, rng: RandomNumberGenerator, color: Color, count: int) -> void:
	for t in count:
		var at := p + Vector3(rng.randf_range(-1.6, 1.6), 0.0, rng.randf_range(-1.6, 1.6))
		var h := rng.randf_range(0.5, 0.9)
		var seed := rng.randi()
		for i in 5:
			var a := TAU * i / 5.0 + MeshBuilder._hash(seed + i) * 0.8
			var d := Vector3(cos(a), 0, sin(a))
			var side := Vector3(-d.z, 0, d.x) * 0.07
			var tip := at + d * h * 0.5 + Vector3(0, h, 0)
			mb.tri(at - side, at + side, tip, (d + Vector3(0, 0.6, 0)).normalized(), color.lerp(color.lightened(0.15), 0.5 * (i % 2)))


## A boulder (and on bigger ones a second leaning on it), `r` m across.
static func rock(mb, props: Array, p: Vector3, rng: RandomNumberGenerator, r: float) -> void:
	var c := MeshBuilder.glow(ROCK.lerp(Color(0.62, 0.55, 0.45), rng.randf()), MeshBuilder.CONCRETE)
	mb.clump(p + Vector3(0, r * 0.2, 0), Vector3(r, r * 0.6, r * rng.randf_range(0.7, 1.0)), c, rng.randi(), 6, 4, 0.3)
	if r > 1.4:
		mb.clump(p + Vector3(r * 0.8, r * 0.1, r * 0.3), Vector3(r, r * 0.8, r) * 0.5, c.darkened(0.08), rng.randi(), 5, 3, 0.3)
	if r > 1.0:
		props.append([p + Vector3(0, r * 0.4, 0), Vector3(r * 1.4, r * 0.8, r * 1.4), 0.0])
