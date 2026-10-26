extends RefCounted
## Low-poly cartoon buildings for Bellerive. Every builder works in local
## space: footprint centred on the origin, width along X, depth along Z, the
## street front facing -Z, ground at y = 0. The caller places the result with
## MeshBuilder.xform and turns the returned collision boxes into shapes.
## Collision boxes are [local_center, size] pairs.

const FLOOR := 3.4

const CREOLE := [
	Color(0.93, 0.68, 0.47), Color(0.96, 0.82, 0.5), Color(0.6, 0.79, 0.72),
	Color(0.74, 0.66, 0.86), Color(0.93, 0.6, 0.62), Color(0.68, 0.8, 0.58),
	Color(0.94, 0.9, 0.8), Color(0.62, 0.76, 0.88),
]
const SHUTTERS := [Color(0.16, 0.34, 0.24), Color(0.12, 0.22, 0.36), Color(0.2, 0.42, 0.42), Color(0.45, 0.2, 0.18)]
const WARDS := [
	Color(0.2, 0.68, 0.7), Color(0.97, 0.55, 0.42), Color(0.98, 0.83, 0.3), Color(0.6, 0.8, 0.35),
	Color(0.85, 0.45, 0.7), Color(0.4, 0.6, 0.9), Color(0.98, 0.95, 0.88),
]
const GLASS := [Color(0.42, 0.58, 0.68), Color(0.36, 0.5, 0.62), Color(0.5, 0.62, 0.66)]
const STONE := Color(0.62, 0.6, 0.58)
const IRON := Color(0.1, 0.12, 0.11)
const TRIM := Color(0.97, 0.96, 0.92)
const DARK := Color(0.1, 0.11, 0.13)
const WOOD := Color(0.42, 0.28, 0.18)
const ROOF_TAR := Color(0.32, 0.3, 0.3)
const GOLD := Color(0.9, 0.72, 0.25)


## Two- to four-storey Creole townhouse with a cast-iron gallery over the
## sidewalk, shuttered French doors and a flat roof (Lantern Quarter).
static func townhouse(mb, out: Array, w: float, d: float, floors: int, rng: RandomNumberGenerator) -> void:
	var body: Color = CREOLE[rng.randi() % CREOLE.size()]
	var shutter: Color = SHUTTERS[rng.randi() % SHUTTERS.size()]
	var h := floors * FLOOR + 0.6
	_solid(mb, out, Vector3(0, h * 0.5, 0), Vector3(w, h, d), body)
	mb.box(Vector3(0, h + 0.12, 0), Vector3(w + 0.3, 0.25, d + 0.3), body.darkened(0.25))
	mb.box(Vector3(0, h + 0.26, 0), Vector3(w - 0.6, 0.04, d - 0.6), ROOF_TAR)
	var bays := maxi(1, int(w / 2.6))
	var bay_w := w / bays
	var front := -d * 0.5 - 0.04
	for f in floors:
		var y := f * FLOOR
		for b in bays:
			var x := -w * 0.5 + bay_w * (b + 0.5)
			var is_door := f == 0 and b == bays / 2
			var open_h := 2.4 if (f > 0 or is_door) else 1.6
			var open_y := y + (0.2 if (f > 0 or is_door) else 0.9) + open_h * 0.5
			mb.box(Vector3(x, open_y, front), Vector3(bay_w * 0.45, open_h, 0.08), WOOD if is_door else DARK)
			for side in [-1.0, 1.0]:
				mb.box(Vector3(x + side * bay_w * 0.34, open_y, front - 0.02), Vector3(bay_w * 0.2, open_h, 0.06), shutter)
		mb.box(Vector3(0, y + FLOOR - 0.15, front), Vector3(w, 0.12, 0.08), TRIM)
	if floors > 1:
		_gallery(mb, w, d, floors, rng)
	# Back: a simple window band per floor (seen across courtyards).
	for f in floors:
		mb.box(Vector3(0, f * FLOOR + 1.8, d * 0.5 + 0.04), Vector3(w * 0.8, 1.2, 0.06), DARK)
	_roof_clutter(mb, w, d, h + 0.25, rng)


## Cast-iron gallery: one balcony per upper floor on posts down to the street,
## with fern baskets now and then.
static func _gallery(mb, w: float, d: float, floors: int, rng: RandomNumberGenerator) -> void:
	var depth := 1.4
	var z := -d * 0.5 - depth * 0.5
	var posts := maxi(2, int(w / 2.6) + 1)
	for f in range(1, floors):
		var y := f * FLOOR
		mb.box(Vector3(0, y, z), Vector3(w, 0.14, depth), IRON)
		mb.box(Vector3(0, y + 1.0, z - depth * 0.5 + 0.04), Vector3(w, 0.07, 0.07), IRON)
		mb.box(Vector3(0, y + 0.5, z - depth * 0.5 + 0.04), Vector3(w, 0.04, 0.04), IRON)
		if rng.randf() < 0.5:
			mb.ball(Vector3(-w * 0.25, y + 1.6, z - depth * 0.4), Vector3(0.35, 0.3, 0.35), Color(0.25, 0.55, 0.25), 5, 2)
	mb.box(Vector3(0, floors * FLOOR - 0.1, z), Vector3(w, 0.12, depth), IRON)
	for i in posts:
		var x := -w * 0.5 + 0.1 + (w - 0.2) * i / (posts - 1)
		mb.box(Vector3(x, (floors * FLOOR) * 0.5, z - depth * 0.5 + 0.06), Vector3(0.1, floors * FLOOR, 0.1), IRON)


## Single-storey shotgun house on piers with a front porch and a front-facing
## gable (Floodline Wards). Storm-damaged ones have boarded windows and a
## blue tarp on the roof. `paint` (if opaque) overrides the random colour.
static func shotgun(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator, damaged := false, paint := Color(0, 0, 0, 0)) -> void:
	var body: Color = WARDS[rng.randi() % WARDS.size()]
	if paint.a > 0.0:
		body = paint
	if damaged:
		body = body.lerp(Color(0.6, 0.58, 0.55), 0.55)
	var pier := 0.6
	var wall := 3.2
	var porch := 2.2
	mb.box(Vector3(0, pier * 0.5, 0), Vector3(w, pier, d), Color(0.45, 0.42, 0.4))
	_solid(mb, out, Vector3(0, pier + wall * 0.5, porch * 0.5), Vector3(w, wall, d - porch), body)
	var front := -d * 0.5 + porch
	# Porch: floor, steps, posts and roof.
	mb.box(Vector3(0, pier, -d * 0.5 + porch * 0.5), Vector3(w, 0.12, porch), WOOD.lightened(0.2))
	mb.box(Vector3(w * 0.25, pier * 0.5, -d * 0.5 - 0.3), Vector3(1.2, pier, 0.6), STONE)
	for side in [-1.0, 1.0]:
		mb.box(Vector3(side * (w * 0.5 - 0.15), pier + wall * 0.5, -d * 0.5 + 0.15), Vector3(0.14, wall, 0.14), TRIM)
	mb.box(Vector3(0, pier + wall - 0.2, -d * 0.5 + 0.15), Vector3(w, 0.18, 0.1), TRIM)
	# Facade: door and one shuttered window.
	mb.box(Vector3(w * 0.25, pier + 1.1, front - 0.04), Vector3(0.9, 2.1, 0.08), WOOD)
	var win_x := -w * 0.22
	if damaged:
		mb.box(Vector3(win_x, pier + 1.5, front - 0.05), Vector3(1.3, 1.4, 0.08), WOOD.lightened(0.15))
		mb.box(Vector3(win_x, pier + 1.5, front - 0.1), Vector3(1.6, 0.18, 0.06), WOOD)
	else:
		mb.box(Vector3(win_x, pier + 1.5, front - 0.04), Vector3(1.0, 1.5, 0.08), DARK)
		for side in [-1.0, 1.0]:
			mb.box(Vector3(win_x + side * 0.72, pier + 1.5, front - 0.06), Vector3(0.4, 1.5, 0.06), TRIM if body.v < 0.8 else SHUTTERS[0])
	# Front-facing gable roof (ridge runs front to back).
	# Tin and shingle roofs in a few weathered colours: from the top-down
	# camera the roof is most of what shows.
	var roofs := [Color(0.36, 0.33, 0.33), Color(0.55, 0.28, 0.22), Color(0.3, 0.45, 0.38), Color(0.38, 0.42, 0.5), Color(0.6, 0.58, 0.52)]
	var roof: Color = roofs[rng.randi() % roofs.size()] if not damaged else Color(0.42, 0.4, 0.38)
	var saved: Transform3D = mb.xform
	mb.xform = saved * Transform3D(Basis(Vector3.UP, PI / 2), Vector3.ZERO)
	mb.gable(Vector3(0, pier + wall + 0.9, 0), Vector3(d + 0.3, 1.8, w + 0.5), roof, body.lightened(0.15))
	mb.xform = saved
	if damaged:
		mb.box(Vector3(w * 0.12, pier + wall + 1.0, 1.5), Vector3(w * 0.7, 0.1, d * 0.4), Color(0.2, 0.45, 0.85))


## Two-storey ward apartment with an outside stair (Teo's place).
static func ward_apartment(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var body: Color = WARDS[rng.randi() % WARDS.size()]
	var h := FLOOR * 2 + 0.4
	_solid(mb, out, Vector3(0, h * 0.5, 0), Vector3(w, h, d), body)
	mb.box(Vector3(0, h + 0.1, 0), Vector3(w + 0.4, 0.2, d + 0.4), body.darkened(0.3))
	var front := -d * 0.5 - 0.04
	for f in 2:
		for b in 3:
			mb.box(Vector3(-w * 0.33 + b * w * 0.33, f * FLOOR + 1.8, front), Vector3(1.1, 1.4, 0.08), DARK)
	# Exterior stair up the right side, with a landing.
	for s in 8:
		mb.box(Vector3(w * 0.5 + 0.6, 0.2 + s * 0.42, -d * 0.3 + s * 0.45), Vector3(1.1, 0.12, 0.45), IRON)
	mb.box(Vector3(w * 0.5 + 0.6, FLOOR, d * 0.1), Vector3(1.2, 0.12, 1.6), IRON)
	_roof_clutter(mb, w, d, h + 0.2, rng)


## Glass office tower with stone lobby, floor bands and roof gear (Gilt
## District). `accent` trims the crown (gold for Aurum).
static func tower(mb, out: Array, w: float, d: float, h: float, rng: RandomNumberGenerator, accent := Color(0.75, 0.78, 0.82)) -> void:
	var glass: Color = GLASS[rng.randi() % GLASS.size()]
	var lobby := 4.6
	_solid(mb, out, Vector3(0, lobby * 0.5, 0), Vector3(w, lobby, d), STONE)
	_solid(mb, out, Vector3(0, lobby + (h - lobby) * 0.5, 0), Vector3(w - 0.8, h - lobby, d - 0.8), glass)
	var y := lobby + 3.5
	while y < h - 1.0:
		mb.box(Vector3(0, y, 0), Vector3(w - 0.6, 0.3, d - 0.6), glass.lightened(0.35))
		y += 3.5
	for i in 5:
		var x := -w * 0.4 + i * w * 0.2
		mb.box(Vector3(x, lobby + (h - lobby) * 0.5, -d * 0.5 + 0.35), Vector3(0.16, h - lobby, 0.12), glass.darkened(0.25))
	# Entrance canopy and doors.
	mb.box(Vector3(0, 3.6, -d * 0.5 - 1.2), Vector3(w * 0.5, 0.25, 2.4), DARK)
	mb.box(Vector3(0, 1.5, -d * 0.5 - 0.04), Vector3(w * 0.35, 3.0, 0.08), Color(0.25, 0.32, 0.38))
	# The roof is what the top-down camera sees most: a dark deck inside a
	# trimmed parapet, with a helipad, a roof garden or plant and tanks.
	var deck: Color = [Color(0.36, 0.38, 0.41), Color(0.42, 0.4, 0.37), Color(0.33, 0.37, 0.36)][rng.randi() % 3]
	mb.box(Vector3(0, h + 0.03, 0), Vector3(w - 0.8, 0.06, d - 0.8), deck)
	for side in [-1.0, 1.0]:
		mb.box(Vector3(side * (w * 0.5 - 0.25), h + 0.45, 0), Vector3(0.5, 0.9, d - 0.2), accent)
		mb.box(Vector3(0, h + 0.45, side * (d * 0.5 - 0.25)), Vector3(w - 1.2, 0.9, 0.5), accent)
	var roll := rng.randf()
	if roll < 0.3 and w >= 14.0:
		# Helipad with a yellow H.
		mb.box(Vector3(0, h + 0.3, 0), Vector3(w * 0.6, 0.5, d * 0.6), DARK)
		mb.box(Vector3(-w * 0.1, h + 0.56, 0), Vector3(w * 0.05, 0.02, d * 0.3), Color(0.95, 0.85, 0.2))
		mb.box(Vector3(w * 0.1, h + 0.56, 0), Vector3(w * 0.05, 0.02, d * 0.3), Color(0.95, 0.85, 0.2))
		mb.box(Vector3(0, h + 0.56, 0), Vector3(w * 0.2, 0.02, d * 0.05), Color(0.95, 0.85, 0.2))
	elif roll < 0.55:
		# Roof garden: lawn, planters and a pergola.
		mb.box(Vector3(0, h + 0.08, d * 0.1), Vector3(w * 0.7, 0.06, d * 0.5), Color(0.38, 0.6, 0.3))
		for x in [-w * 0.25, 0.0, w * 0.25]:
			mb.ball(Vector3(x, h + 0.7, -d * 0.25), Vector3(0.7, 0.6, 0.7), Color(0.28, 0.5, 0.26), 5, 2)
		mb.box(Vector3(0, h + 2.4, d * 0.1), Vector3(w * 0.4, 0.12, d * 0.2), WOOD)
	else:
		mb.box(Vector3(w * 0.15, h + 0.9, d * 0.1), Vector3(w * 0.35, 1.8, d * 0.4), Color(0.55, 0.56, 0.58))
		mb.cylinder(Vector3(-w * 0.2, h, -d * 0.15), 0.12, 6.0, Color(0.6, 0.6, 0.62), 4)
	for i in rng.randi_range(1, 3):
		mb.box(Vector3(w * rng.randf_range(-0.35, 0.35), h + 0.5, d * rng.randf_range(0.2, 0.38)), Vector3(1.4, 1.0, 1.0), Color(0.72, 0.74, 0.76))
	if rng.randf() < 0.35:
		mb.cylinder(Vector3(-w * 0.3, h + 0.06, d * 0.28), 1.1, 2.6, WOOD.lightened(0.1), 7)
		mb.cylinder(Vector3(-w * 0.3, h + 2.66, d * 0.28), 1.2, 0.5, ROOF_TAR, 7)


## Corrugated dockside warehouse with roll-up doors and a loading dock
## (Ironwharf). `number` paints a big digit on the roof (Warehouse 9).
static func warehouse(mb, out: Array, w: float, d: float, h: float, rng: RandomNumberGenerator, number := -1) -> void:
	var colors := [Color(0.62, 0.3, 0.24), Color(0.5, 0.55, 0.58), Color(0.42, 0.52, 0.42), Color(0.7, 0.66, 0.58)]
	var body: Color = colors[rng.randi() % colors.size()]
	_solid(mb, out, Vector3(0, h * 0.5, 0), Vector3(w, h, d), body)
	var rib := 1.4
	var x := -w * 0.5 + rib * 0.5
	while x < w * 0.5:
		mb.box(Vector3(x, h * 0.5, -d * 0.5 - 0.05), Vector3(0.18, h, 0.1), body.darkened(0.2))
		x += rib
	var doors := maxi(1, int(w / 9.0))
	for i in doors:
		var dx := -w * 0.5 + w * (i + 0.5) / doors
		mb.box(Vector3(dx, 2.3, -d * 0.5 - 0.1), Vector3(4.0, 4.4, 0.1), Color(0.55, 0.56, 0.58))
		mb.box(Vector3(dx, 4.6, -d * 0.5 - 0.15), Vector3(4.3, 0.3, 0.15), Color(0.95, 0.75, 0.2))
	mb.box(Vector3(0, 0.6, -d * 0.5 - 1.5), Vector3(w * 0.9, 1.2, 3.0), STONE.darkened(0.15))
	_solid_only(out, Vector3(0, 0.6, -d * 0.5 - 1.5), Vector3(w * 0.9, 1.2, 3.0))
	mb.gable(Vector3(0, h + 0.6, 0), Vector3(w + 0.4, 1.2, d + 0.4), body.darkened(0.35), body)
	for i in 3:
		mb.box(Vector3(-w * 0.3 + i * w * 0.3, h + 0.95, d * 0.15), Vector3(1.4, 0.15, d * 0.3), Color(0.7, 0.85, 0.9))
	if number >= 0:
		_digit(mb, number, Vector3(0, h + 1.3, -d * 0.12), 3.0, Color(0.95, 0.95, 0.9))


## A digit drawn with seven-segment bars, lying flat and turned to read
## north-up on screen whichever way the building faces.
static func _digit(mb, n: int, center: Vector3, size: float, color: Color) -> void:
	const SEGMENTS := [
		[1, 1, 1, 0, 1, 1, 1], [0, 0, 1, 0, 0, 1, 0], [1, 0, 1, 1, 1, 0, 1], [1, 0, 1, 1, 0, 1, 1],
		[0, 1, 1, 1, 0, 1, 0], [1, 1, 0, 1, 0, 1, 1], [1, 1, 0, 1, 1, 1, 1], [1, 0, 1, 0, 0, 1, 0],
		[1, 1, 1, 1, 1, 1, 1], [1, 1, 1, 1, 0, 1, 1],
	]
	var s: Array = SEGMENTS[n % 10]
	var hw := size * 0.3
	var hh := size * 0.5
	var t := size * 0.12
	# Order: top, top-left, top-right, middle, bottom-left, bottom-right, bottom.
	var bars := [
		[Vector3(0, 0, -hh), Vector3(hw * 2, 0.05, t)], [Vector3(-hw, 0, -hh * 0.5), Vector3(t, 0.05, hh)],
		[Vector3(hw, 0, -hh * 0.5), Vector3(t, 0.05, hh)], [Vector3(0, 0, 0), Vector3(hw * 2, 0.05, t)],
		[Vector3(-hw, 0, hh * 0.5), Vector3(t, 0.05, hh)], [Vector3(hw, 0, hh * 0.5), Vector3(t, 0.05, hh)],
		[Vector3(0, 0, hh), Vector3(hw * 2, 0.05, t)],
	]
	var undo: Basis = mb.xform.basis.inverse()
	var swap := absf(undo.x.z) > 0.5
	for i in 7:
		if s[i] == 1:
			var size_i: Vector3 = bars[i][1]
			mb.box(center + undo * bars[i][0], Vector3(size_i.z, size_i.y, size_i.x) if swap else size_i, color)


# --- Landmarks ----------------------------------------------------------------

## Union Station: wide civic hall with columns, arched entrance and a clock
## tower. Fills most of a 40 m block.
static func union_station(mb, out: Array) -> void:
	var body := Color(0.86, 0.8, 0.68)
	_solid(mb, out, Vector3(0, 5.0, 2.0), Vector3(34.0, 10.0, 22.0), body)
	mb.box(Vector3(0, 10.3, 2.0), Vector3(35.0, 0.6, 23.0), body.darkened(0.2))
	for i in 8:
		var x := -14.0 + i * 4.0
		mb.cylinder(Vector3(x, 0.15, -9.6), 0.45, 8.5, TRIM, 6)
	mb.box(Vector3(0, 8.9, -9.6), Vector3(31.0, 1.0, 1.2), body.lightened(0.1))
	mb.box(Vector3(0, 3.0, -9.05), Vector3(6.0, 5.6, 0.1), DARK)
	mb.gable(Vector3(0, 11.6, -7.0), Vector3(12.0, 2.0, 6.0), body.darkened(0.25), body)
	_solid(mb, out, Vector3(13.0, 9.0, 8.0), Vector3(5.0, 18.0, 5.0), body.darkened(0.08))
	mb.box(Vector3(13.0, 15.5, 5.45), Vector3(2.6, 2.6, 0.1), TRIM)
	mb.box(Vector3(13.0, 15.5, 5.38), Vector3(0.12, 1.0, 0.06), DARK)
	mb.box(Vector3(13.3, 15.5, 5.38), Vector3(0.7, 0.12, 0.06), DARK)
	mb.gable(Vector3(13.0, 19.0, 8.0), Vector3(5.6, 2.0, 5.6), Color(0.35, 0.48, 0.42), body)


## Aurum Tower: the tallest building in the city, gold-trimmed crown.
static func aurum_tower(mb, out: Array, rng: RandomNumberGenerator) -> void:
	const H := 40.0
	tower(mb, out, 22.0, 22.0, H, rng, GOLD)
	mb.box(Vector3(0, H + 1.5, 0), Vector3(14.0, 3.0, 14.0), GOLD)
	mb.box(Vector3(0, H + 4.5, 0), Vector3(7.0, 3.0, 7.0), GOLD.darkened(0.15))
	mb.cylinder(Vector3(0, H + 6.0, 0), 0.25, 9.0, GOLD, 4)


## The Blue Lantern: jazz club with a deep blue front, a long awning and a
## glowing lantern sign.
static func blue_lantern(mb, out: Array, rng: RandomNumberGenerator) -> void:
	var blue := Color(0.15, 0.25, 0.55)
	_solid(mb, out, Vector3(0, 4.0, 2.0), Vector3(24.0, 8.0, 18.0), blue)
	mb.box(Vector3(0, 8.15, 2.0), Vector3(24.4, 0.3, 18.4), blue.darkened(0.3))
	mb.box(Vector3(0, 3.4, -8.6), Vector3(16.0, 0.2, 3.2), Color(0.85, 0.2, 0.25))
	mb.box(Vector3(0, 1.4, -7.04), Vector3(3.0, 2.8, 0.08), WOOD)
	mb.box(Vector3(0, 6.2, -7.1), Vector3(12.0, 1.2, 0.1), Color(1.0, 0.85, 0.35))
	mb.box(Vector3(9.5, 6.0, -7.4), Vector3(0.9, 1.4, 0.9), Color(0.4, 0.75, 1.0))
	_gallery_front(mb, 24.0, 18.0)
	_roof_clutter(mb, 24.0, 18.0, 8.3, rng)


static func _gallery_front(mb, w: float, d: float) -> void:
	mb.box(Vector3(0, FLOOR, -d * 0.5 + 1.0 - 0.7), Vector3(w, 0.14, 1.4), IRON)
	mb.box(Vector3(0, FLOOR + 1.0, -d * 0.5 + 1.0 - 1.36), Vector3(w, 0.07, 0.07), IRON)


## Lantern Quarter Precinct: Bellerive PD station with a blue stripe, flag
## pole and a few parking bays.
static func precinct(mb, out: Array) -> void:
	var body := Color(0.78, 0.8, 0.84)
	_solid(mb, out, Vector3(0, 4.5, 4.0), Vector3(28.0, 9.0, 18.0), body)
	mb.box(Vector3(0, 7.0, -5.06), Vector3(28.0, 1.0, 0.1), Color(0.15, 0.25, 0.6))
	mb.box(Vector3(0, 9.15, 4.0), Vector3(28.4, 0.3, 18.4), body.darkened(0.3))
	mb.box(Vector3(0, 1.6, -5.06), Vector3(4.0, 3.2, 0.1), Color(0.25, 0.32, 0.4))
	mb.box(Vector3(0, 3.6, -6.0), Vector3(6.0, 0.2, 2.0), Color(0.15, 0.25, 0.6))
	mb.cylinder(Vector3(-11.0, 0.15, -9.0), 0.1, 9.0, Color(0.85, 0.85, 0.85), 4)
	mb.box(Vector3(-10.2, 8.4, -9.0), Vector3(1.6, 1.0, 0.05), Color(0.8, 0.25, 0.25))
	for i in 4:
		mb.box(Vector3(5.0 + i * 3.0, 0.17, -11.0), Vector3(0.12, 0.02, 4.5), TRIM)


## Floodline Clinic: low white building with a red cross on the roof.
static func clinic(mb, out: Array) -> void:
	var body := Color(0.95, 0.95, 0.96)
	_solid(mb, out, Vector3(0, 3.8, 2.0), Vector3(26.0, 7.6, 20.0), body)
	mb.box(Vector3(0, 7.75, 2.0), Vector3(26.4, 0.3, 20.4), Color(0.75, 0.78, 0.8))
	mb.box(Vector3(0, 7.95, 2.0), Vector3(8.0, 0.1, 2.4), Color(0.85, 0.15, 0.15))
	mb.box(Vector3(0, 7.95, 2.0), Vector3(2.4, 0.1, 8.0), Color(0.85, 0.15, 0.15))
	mb.box(Vector3(0, 3.4, -9.6), Vector3(8.0, 0.25, 3.0), Color(0.85, 0.15, 0.15))
	mb.box(Vector3(0, 1.4, -8.05), Vector3(3.2, 2.8, 0.1), Color(0.5, 0.7, 0.85))
	for i in 6:
		mb.box(Vector3(-10.0 + i * 4.0, 4.6, -8.05), Vector3(2.2, 1.4, 0.08), Color(0.5, 0.7, 0.85))


## Old Streetcar Depot: open-fronted shed where the drowned line ends, with
## an abandoned green streetcar inside.
static func streetcar_depot(mb, out: Array) -> void:
	var brick := Color(0.6, 0.32, 0.26)
	_solid(mb, out, Vector3(-15.0, 4.0, 2.0), Vector3(2.0, 8.0, 26.0), brick)
	_solid(mb, out, Vector3(15.0, 4.0, 2.0), Vector3(2.0, 8.0, 26.0), brick)
	_solid(mb, out, Vector3(0, 4.0, 14.5), Vector3(32.0, 8.0, 1.0), brick)
	mb.gable(Vector3(0, 9.0, 2.0), Vector3(33.0, 2.0, 27.0), Color(0.3, 0.33, 0.32), brick)
	mb.box(Vector3(0, 7.2, -11.0), Vector3(30.0, 1.2, 0.4), brick.darkened(0.2))


## Lantern Square: paved square with a lantern monument, fountain ring,
## benches, lamps and oaks.
static func lantern_square(mb, out: Array, props, rng: RandomNumberGenerator) -> void:
	mb.box(Vector3(0, 0.17, 0), Vector3(34.0, 0.04, 34.0), Color(0.72, 0.66, 0.58))
	for corner in [Vector3(-11, 0, -11), Vector3(11, 0, -11), Vector3(-11, 0, 11), Vector3(11, 0, 11)]:
		mb.box(corner + Vector3(0, 0.2, 0), Vector3(9.0, 0.06, 9.0), Color(0.38, 0.62, 0.32))
		props.oak(mb, out, corner, rng)
	mb.cylinder(Vector3(0, 0.15, 0), 4.0, 0.5, STONE, 8)
	mb.cylinder(Vector3(0, 0.2, 0), 3.6, 0.5, Color(0.35, 0.6, 0.75), 8)
	mb.box(Vector3(0, 1.5, 0), Vector3(1.2, 3.0, 1.2), STONE.darkened(0.1))
	mb.box(Vector3(0, 3.4, 0), Vector3(1.0, 0.8, 1.0), Color(1.0, 0.85, 0.35))
	mb.box(Vector3(0, 3.95, 0), Vector3(1.3, 0.25, 1.3), IRON)
	_solid_only(out, Vector3(0, 1.5, 0), Vector3(2.4, 3.0, 2.4))
	for p in [Vector3(-6, 0, -16), Vector3(6, 0, -16), Vector3(-6, 0, 16), Vector3(6, 0, 16)]:
		props.gas_lamp(mb, out, p)
	for p in [Vector3(-4, 0, -6), Vector3(4, 0, -6), Vector3(-4, 0, 6), Vector3(4, 0, 6)]:
		props.bench(mb, out, p, 0.0)


## Wharfside Courts: fenced basketball court with stands.
static func courts(mb, out: Array, props) -> void:
	mb.box(Vector3(0, 0.17, 0), Vector3(34.0, 0.04, 34.0), Color(0.62, 0.35, 0.28))
	mb.box(Vector3(0, 0.2, 0), Vector3(16.0, 0.02, 28.0), Color(0.2, 0.42, 0.65))
	mb.box(Vector3(0, 0.21, 0), Vector3(16.0, 0.02, 0.2), Color.WHITE)
	mb.cylinder(Vector3(0, 0.21, 0), 2.0, 0.01, Color.WHITE, 10)
	for side in [-1.0, 1.0]:
		var post := Vector3(0, 0, side * 13.5)
		_solid(mb, out, post + Vector3(0, 1.6, 0), Vector3(0.25, 3.2, 0.25), Color(0.3, 0.3, 0.3))
		mb.box(post + Vector3(0, 3.3, -side * 0.4), Vector3(1.8, 1.1, 0.1), Color.WHITE)
		mb.box(post + Vector3(0, 3.0, -side * 0.75), Vector3(0.5, 0.05, 0.5), Color(0.95, 0.45, 0.15))
	props.fence(mb, out, Vector3(-17, 0, -17), Vector3(17, 0, -17), Color(0.55, 0.58, 0.6))
	props.fence(mb, out, Vector3(-17, 0, 17), Vector3(17, 0, 17), Color(0.55, 0.58, 0.6))
	mb.box(Vector3(-12.5, 0.6, 0), Vector3(3.0, 1.2, 14.0), Color(0.5, 0.5, 0.52))


# --- Helpers ------------------------------------------------------------------

static func _roof_clutter(mb, w: float, d: float, top: float, rng: RandomNumberGenerator) -> void:
	if rng.randf() < 0.6:
		mb.box(Vector3(w * rng.randf_range(-0.25, 0.25), top + 0.45, d * rng.randf_range(-0.2, 0.25)), Vector3(1.2, 0.9, 1.0), Color(0.72, 0.74, 0.76))
	if rng.randf() < 0.35:
		mb.box(Vector3(w * 0.3, top + 0.9, d * 0.3), Vector3(0.7, 1.8, 0.7), Color(0.55, 0.3, 0.25))


static func _solid(mb, out: Array, center: Vector3, size: Vector3, color: Color) -> void:
	mb.box(center, size, color)
	out.append([center, size])


static func _solid_only(out: Array, center: Vector3, size: Vector3) -> void:
	out.append([center, size])
