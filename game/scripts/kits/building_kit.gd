extends RefCounted
## Low-poly cartoon buildings for Bellerive. Every builder works in local
## space: footprint centred on the origin, width along X, depth along Z, the
## street front facing -Z, ground at y = 0. The caller places the result with
## MeshBuilder.xform and turns the returned collision boxes into shapes.
## Collision boxes are [local_center, size] pairs.

const MeshBuilder = preload("res://scripts/mesh_builder.gd")
const Props = preload("res://scripts/kits/prop_kit.gd")

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
const PANE := Color(0.16, 0.2, 0.24)
const WOOD := Color(0.42, 0.28, 0.18)
const ROOF_TAR := Color(0.32, 0.3, 0.3)
const GOLD := Color(0.9, 0.72, 0.25)
const SHOP_GLASS := Color(0.55, 0.68, 0.72)
const AWNINGS := [Color(0.75, 0.15, 0.2), Color(0.15, 0.4, 0.3), Color(0.2, 0.3, 0.6), Color(0.85, 0.55, 0.15)]
const NEONS := [Color(1.0, 0.3, 0.55), Color(0.3, 0.85, 1.0), Color(1.0, 0.75, 0.2), Color(0.55, 1.0, 0.45), Color(0.8, 0.4, 1.0)]
## Modern roofs: cool-roof membranes, sedum, rooftop plant and solar.
const MEMBRANES := [Color(0.8, 0.81, 0.82), Color(0.64, 0.66, 0.68), Color(0.72, 0.7, 0.66), Color(0.46, 0.48, 0.5)]
const SEDUM := Color(0.44, 0.52, 0.28)
const UNIT := Color(0.8, 0.82, 0.84)
const CHROME := Color(0.7, 0.72, 0.75)
const SOLAR_BLUE := Color(0.08, 0.12, 0.22)
const SKY_GLASS := Color(0.35, 0.45, 0.55)
const DECK := Color(0.58, 0.42, 0.3)
const PARASOLS := [Color(0.95, 0.93, 0.86), Color(0.2, 0.45, 0.5), Color(0.85, 0.4, 0.3), Color(0.3, 0.32, 0.35)]
const BRICKS := [Color(0.6, 0.32, 0.25), Color(0.52, 0.28, 0.22), Color(0.68, 0.44, 0.34)]


## A window opening that may light up at night (about `lit` of them do).
## Dark ones are plain glass (the shader still lights a few at night).
static func _window(rng: RandomNumberGenerator, lit := 0.55) -> Color:
	return MeshBuilder.glow(DARK, MeshBuilder.GLOW_WINDOW) if rng.randf() < lit else MeshBuilder.glow(PANE, MeshBuilder.GLASS)


## Two- to four-storey Creole townhouse with a cast-iron gallery over the
## sidewalk, shuttered French doors and a flat roof (Lantern Quarter).
## About a quarter are bare brick rather than painted stucco.
static func townhouse(mb, out: Array, w: float, d: float, floors: int, rng: RandomNumberGenerator) -> void:
	var body: Color = CREOLE[rng.randi() % CREOLE.size()]
	var shutter: Color = SHUTTERS[rng.randi() % SHUTTERS.size()]
	var cornice := body.darkened(0.25)
	if rng.randf() < 0.25:
		body = MeshBuilder.glow(BRICKS[rng.randi() % BRICKS.size()], MeshBuilder.BRICK)
		cornice = TRIM.darkened(0.12)
	var h := floors * FLOOR + 0.6
	_solid(mb, out, Vector3(0, h * 0.5, 0), Vector3(w, h, d), body)
	mb.box(Vector3(0, h + 0.12, 0), Vector3(w + 0.3, 0.25, d + 0.3), cornice)
	var bays := maxi(1, int(w / 2.6))
	var bay_w := w / bays
	var front := -d * 0.5 - 0.04
	var shop := floors >= 2 and w >= 5.5 and rng.randf() < 0.5
	for f in floors:
		var y := f * FLOOR
		if f == 0 and shop:
			_shopfront(mb, w, front, rng)
		else:
			for b in bays:
				var x := -w * 0.5 + bay_w * (b + 0.5)
				var is_door := f == 0 and b == bays / 2
				var open_h := 2.4 if (f > 0 or is_door) else 1.6
				var open_y := y + (0.2 if (f > 0 or is_door) else 0.9) + open_h * 0.5
				mb.box(Vector3(x, open_y, front), Vector3(bay_w * 0.45, open_h, 0.08), WOOD if is_door else _window(rng))
				if f > 0:
					mb.box(Vector3(x, open_y - open_h * 0.5 - 0.04, front - 0.1), Vector3(bay_w * 0.52, 0.06, 0.2), TRIM)
				for side in [-1.0, 1.0]:
					mb.box(Vector3(x + side * bay_w * 0.34, open_y, front - 0.02), Vector3(bay_w * 0.2, open_h, 0.06), shutter)
		mb.box(Vector3(0, y + FLOOR - 0.15, front), Vector3(w, 0.12, 0.08), TRIM)
	if floors > 1:
		_gallery(mb, w, d, floors, rng)
	# Back: a simple window band per floor (seen across courtyards).
	for f in floors:
		mb.box(Vector3(0, f * FLOOR + 1.8, d * 0.5 + 0.04), Vector3(w * 0.8, 1.2, 0.06), _window(rng, 0.4))
	# A mini-split condenser on a bracket at the back.
	mb.box(Vector3(w * 0.3, FLOOR + 0.5, d * 0.5 + 0.3), Vector3(0.8, 0.6, 0.5), MeshBuilder.glow(UNIT, MeshBuilder.METAL))
	_flat_roof(mb, w, d, h + 0.25, rng, cornice)


## Ground-floor shop: a lit display window, a glazed door, a striped awning
## and a neon blade sign hanging from the gallery.
static func _shopfront(mb, w: float, front: float, rng: RandomNumberGenerator) -> void:
	var glass := MeshBuilder.glow(SHOP_GLASS, MeshBuilder.GLOW_WINDOW)
	mb.box(Vector3(-w * 0.18, 1.45, front), Vector3(w * 0.5, 2.1, 0.08), glass)
	mb.box(Vector3(w * 0.28, 1.25, front), Vector3(1.1, 2.3, 0.08), WOOD.darkened(0.2))
	mb.box(Vector3(w * 0.28, 1.6, front - 0.02), Vector3(0.7, 1.0, 0.06), glass)
	mb.box(Vector3(0, 0.45, front - 0.01), Vector3(w * 0.96, 0.5, 0.08), TRIM.darkened(0.15))
	var awning: Color = AWNINGS[rng.randi() % AWNINGS.size()]
	var stripes := int(w / 0.6)
	for i in stripes:
		var x := -w * 0.5 + (i + 0.5) * w / stripes
		mb.box(Vector3(x, 2.85, front - 0.55), Vector3(w / stripes, 0.12, 1.1), awning if i % 2 == 0 else Color(0.95, 0.93, 0.88))
	var neon: Color = NEONS[rng.randi() % NEONS.size()]
	mb.box(Vector3(w * 0.42, 2.5, front - 1.05), Vector3(0.12, 0.9, 1.0), Color(0.1, 0.1, 0.12))
	mb.box(Vector3(w * 0.42, 2.5, front - 1.05), Vector3(0.16, 0.6, 0.75), MeshBuilder.glow(neon, MeshBuilder.GLOW_NEON))


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
	body = MeshBuilder.glow(body, MeshBuilder.SIDING)
	var pier := 0.6
	var wall := 3.2
	var porch := 2.2
	mb.box(Vector3(0, pier * 0.5, 0), Vector3(w, pier, d), MeshBuilder.glow(Color(0.5, 0.48, 0.46), MeshBuilder.CONCRETE))
	_solid(mb, out, Vector3(0, pier + wall * 0.5, porch * 0.5), Vector3(w, wall, d - porch), body)
	var front := -d * 0.5 + porch
	# Porch: floor, steps, posts and roof.
	mb.box(Vector3(0, pier, -d * 0.5 + porch * 0.5), Vector3(w, 0.12, porch), MeshBuilder.glow(WOOD.lightened(0.2), MeshBuilder.SIDING))
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
		mb.box(Vector3(win_x, pier + 1.5, front - 0.04), Vector3(1.0, 1.5, 0.08), _window(rng, 0.6))
		for side in [-1.0, 1.0]:
			mb.box(Vector3(win_x + side * 0.72, pier + 1.5, front - 0.06), Vector3(0.4, 1.5, 0.06), TRIM if body.v < 0.8 else SHUTTERS[0])
	# Front-facing gable roof (ridge runs front to back) in standing-seam
	# metal: from the top-down camera the roof is most of what shows. Some
	# carry a row of solar panels.
	var roofs := [Color(0.36, 0.33, 0.33), Color(0.55, 0.28, 0.22), Color(0.3, 0.45, 0.38), Color(0.38, 0.42, 0.5), Color(0.62, 0.62, 0.6)]
	var roof: Color = roofs[rng.randi() % roofs.size()] if not damaged else Color(0.42, 0.4, 0.38)
	var saved: Transform3D = mb.xform
	mb.xform = saved * Transform3D(Basis(Vector3.UP, PI / 2), Vector3.ZERO)
	var gable_c := Vector3(0, pier + wall + 0.9, 0)
	var gable_s := Vector3(d + 0.3, 1.8, w + 0.5)
	mb.gable(gable_c, gable_s, MeshBuilder.glow(roof, MeshBuilder.SEAM_ROOF), body.lightened(0.15))
	if not damaged and rng.randf() < 0.35:
		_slope_solar(mb, gable_c, gable_s, 1.6)
	mb.xform = saved
	if not damaged:
		mb.box(Vector3(-w * 0.2, 0.35, d * 0.5 + 0.35), Vector3(0.8, 0.6, 0.5), MeshBuilder.glow(UNIT, MeshBuilder.METAL))
	if damaged:
		mb.box(Vector3(w * 0.12, pier + wall + 1.0, 1.5), Vector3(w * 0.7, 0.1, d * 0.4), Color(0.2, 0.45, 0.85))


## Two-storey ward apartment with an outside stair (Teo's place).
static func ward_apartment(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var body: Color = WARDS[rng.randi() % WARDS.size()]
	if rng.randf() < 0.5:
		body = MeshBuilder.glow(body, MeshBuilder.SIDING)
	var h := FLOOR * 2 + 0.4
	_solid(mb, out, Vector3(0, h * 0.5, 0), Vector3(w, h, d), body)
	mb.box(Vector3(0, h + 0.1, 0), Vector3(w + 0.4, 0.2, d + 0.4), body.darkened(0.3))
	var front := -d * 0.5 - 0.04
	for f in 2:
		for b in 3:
			mb.box(Vector3(-w * 0.33 + b * w * 0.33, f * FLOOR + 1.8, front), Vector3(1.1, 1.4, 0.08), _window(rng))
	# Exterior stair up the right side, with a landing.
	for s in 8:
		mb.box(Vector3(w * 0.5 + 0.6, 0.2 + s * 0.42, -d * 0.3 + s * 0.45), Vector3(1.1, 0.12, 0.45), IRON)
	mb.box(Vector3(w * 0.5 + 0.6, FLOOR, d * 0.1), Vector3(1.2, 0.12, 1.6), IRON)
	_flat_roof(mb, w, d, h + 0.2, rng, body.darkened(0.3))


## Glass office tower: a curtain wall with mullions and spandrel bands over
## a glazed stone lobby, and a busy plant roof (Gilt District). `accent`
## trims the crown (gold for Aurum).
static func tower(mb, out: Array, w: float, d: float, h: float, rng: RandomNumberGenerator, accent := Color(0.75, 0.78, 0.82)) -> void:
	var glass: Color = MeshBuilder.glow(GLASS[rng.randi() % GLASS.size()], MeshBuilder.GLASS)
	var lobby := 4.6
	var gw := w - 0.8
	var gd := d - 0.8
	_solid(mb, out, Vector3(0, lobby * 0.5, 0), Vector3(w, lobby, d), MeshBuilder.glow(STONE, MeshBuilder.CONCRETE))
	_solid(mb, out, Vector3(0, lobby + (h - lobby) * 0.5, 0), Vector3(gw, h - lobby, gd), glass)
	var spandrel := MeshBuilder.glow(Color(0.5, 0.54, 0.58), MeshBuilder.METAL)
	var y := lobby + 3.5
	while y < h - 1.0:
		mb.box(Vector3(0, y, 0), Vector3(gw + 0.12, 0.4, gd + 0.12), spandrel)
		y += 3.5
	# Mullions on every face, about every 1.8 m.
	var mullion := MeshBuilder.glow(Color(0.42, 0.45, 0.5), MeshBuilder.METAL)
	var mh := h - lobby
	var my := lobby + mh * 0.5
	var nx := maxi(2, int(gw / 1.8))
	for i in range(1, nx):
		var x := -gw * 0.5 + gw * i / nx
		for side in [-1.0, 1.0]:
			mb.box(Vector3(x, my, side * (gd * 0.5 + 0.04)), Vector3(0.12, mh, 0.08), mullion)
	var nz := maxi(2, int(gd / 1.8))
	for i in range(1, nz):
		var z := -gd * 0.5 + gd * i / nz
		for side in [-1.0, 1.0]:
			mb.box(Vector3(side * (gw * 0.5 + 0.04), my, z), Vector3(0.08, mh, 0.12), mullion)
	# Lobby: full-height glazing and a steel entrance canopy.
	mb.box(Vector3(0, 2.0, -d * 0.5 - 0.04), Vector3(w * 0.8, 3.6, 0.08), MeshBuilder.glow(Color(0.3, 0.38, 0.45), MeshBuilder.GLOW_WINDOW))
	mb.box(Vector3(0, 4.0, -d * 0.5 - 1.2), Vector3(w * 0.5, 0.2, 2.4), MeshBuilder.glow(Color(0.3, 0.32, 0.35), MeshBuilder.METAL))
	mb.box(Vector3(0, 3.88, -d * 0.5 - 1.2), Vector3(w * 0.46, 0.04, 2.2), MeshBuilder.glow(Color(1.0, 0.95, 0.85), MeshBuilder.GLOW_LAMP))
	# The roof is what the top-down camera sees most: a membrane inside a
	# trimmed parapet with a gondola track round the edge, cooling plant,
	# and a helipad, a roof garden or solar rows.
	var deck: Color = MEMBRANES[rng.randi() % MEMBRANES.size()]
	mb.box(Vector3(0, h + 0.03, 0), Vector3(gw, 0.06, gd), MeshBuilder.glow(deck, MeshBuilder.ROOF))
	for side in [-1.0, 1.0]:
		mb.box(Vector3(side * (w * 0.5 - 0.25), h + 0.45, 0), Vector3(0.5, 0.9, d - 0.2), accent)
		mb.box(Vector3(0, h + 0.45, side * (d * 0.5 - 0.25)), Vector3(w - 1.2, 0.9, 0.5), accent)
		mb.box(Vector3(side * (gw * 0.5 - 0.7), h + 0.12, 0), Vector3(0.12, 0.08, gd - 1.2), MeshBuilder.glow(CHROME, MeshBuilder.METAL))
	# Building maintenance unit parked on its track.
	mb.box(Vector3(gw * 0.5 - 0.7, h + 0.7, gd * 0.3), Vector3(1.4, 1.2, 1.6), MeshBuilder.glow(UNIT, MeshBuilder.METAL))
	mb.box(Vector3(gw * 0.5 - 2.4, h + 1.4, gd * 0.3), Vector3(3.6, 0.3, 0.3), MeshBuilder.glow(Color(0.85, 0.75, 0.2), MeshBuilder.GLOSS))
	# Cooling towers at the back.
	var cw := minf(w * 0.45, 7.0)
	_hvac(mb, Vector3(-w * 0.12, h, gd * 0.5 - 1.8), Vector3(cw, 1.6, 2.2))
	var roll := rng.randf()
	if roll < 0.3 and w >= 14.0:
		# Helipad: concrete deck, white ring and H, perimeter lights.
		mb.box(Vector3(0, h + 0.3, -d * 0.08), Vector3(w * 0.6, 0.5, d * 0.5), MeshBuilder.glow(Color(0.5, 0.5, 0.5), MeshBuilder.CONCRETE))
		var hc := Vector3(0, h + 0.55, -d * 0.08)
		mb.cylinder(hc, w * 0.2, 0.01, Color(0.95, 0.95, 0.92), 12)
		mb.cylinder(hc, w * 0.18, 0.02, Color(0.32, 0.33, 0.34), 12)
		var yellow := Color(0.95, 0.85, 0.2)
		mb.box(hc + Vector3(-w * 0.06, 0.03, 0), Vector3(w * 0.03, 0.02, w * 0.18), yellow)
		mb.box(hc + Vector3(w * 0.06, 0.03, 0), Vector3(w * 0.03, 0.02, w * 0.18), yellow)
		mb.box(hc + Vector3(0, 0.03, 0), Vector3(w * 0.12, 0.02, w * 0.03), yellow)
		for k in 8:
			var ang := TAU * k / 8.0
			mb.box(hc + Vector3(cos(ang) * w * 0.22, 0.05, sin(ang) * w * 0.22), Vector3(0.2, 0.1, 0.2), MeshBuilder.glow(Color(0.4, 1.0, 0.5), MeshBuilder.GLOW_LAMP))
	elif roll < 0.55:
		# Roof garden: lawn, timber deck, planters and a pergola.
		mb.box(Vector3(-w * 0.12, h + 0.08, -d * 0.12), Vector3(w * 0.45, 0.06, d * 0.45), MeshBuilder.glow(Color(0.38, 0.6, 0.3), MeshBuilder.GRASS))
		mb.box(Vector3(w * 0.22, h + 0.08, -d * 0.12), Vector3(w * 0.25, 0.06, d * 0.45), MeshBuilder.glow(DECK, MeshBuilder.SIDING))
		for x in [-w * 0.3, -w * 0.12, w * 0.06]:
			mb.ball(Vector3(x, h + 0.7, -d * 0.36), Vector3(0.7, 0.6, 0.7), Color(0.28, 0.5, 0.26), 5, 2)
		mb.box(Vector3(w * 0.22, h + 2.4, -d * 0.12), Vector3(w * 0.25, 0.12, d * 0.3), WOOD)
		for k in 4:
			mb.cylinder(Vector3(w * 0.22 + (w * 0.11 if k % 2 == 0 else -w * 0.11), h + 0.1, -d * 0.12 + (d * 0.13 if k < 2 else -d * 0.13)), 0.06, 2.3, WOOD, 4)
	else:
		_solar(mb, -gw * 0.5 + 0.9, gw * 0.5 - 1.8, -gd * 0.5 + 0.9, gd * 0.5 - 4.0, h)
	# Telecom mast with an aircraft warning light.
	var mast := Vector3(-gw * 0.5 + 1.2, h, gd * 0.5 - 1.2)
	mb.cylinder(mast, 0.12, 6.0, Color(0.6, 0.6, 0.62), 4)
	for k in 3:
		var ang := TAU * k / 3.0
		mb.box(mast + Vector3(cos(ang) * 0.3, 4.6, sin(ang) * 0.3), Vector3(0.2, 1.2, 0.2), Color(0.9, 0.9, 0.9))
	mb.box(mast + Vector3(0, 6.05, 0), Vector3(0.25, 0.2, 0.25), MeshBuilder.glow(Color(1.0, 0.15, 0.1), MeshBuilder.GLOW_NEON))


## Corrugated dockside warehouse with roll-up doors and a loading dock
## (Ironwharf). `number` paints a big digit on the roof (Warehouse 9).
static func warehouse(mb, out: Array, w: float, d: float, h: float, rng: RandomNumberGenerator, number := -1) -> void:
	var colors := [Color(0.62, 0.3, 0.24), Color(0.5, 0.55, 0.58), Color(0.42, 0.52, 0.42), Color(0.7, 0.66, 0.58), Color(0.82, 0.83, 0.84)]
	var body: Color = MeshBuilder.glow(colors[rng.randi() % colors.size()], MeshBuilder.SEAM_ROOF)
	_solid(mb, out, Vector3(0, h * 0.5, 0), Vector3(w, h, d), body)
	mb.box(Vector3(0, 0.5, 0), Vector3(w + 0.06, 1.0, d + 0.06), MeshBuilder.glow(Color(0.55, 0.54, 0.52), MeshBuilder.CONCRETE))
	var doors := maxi(1, int(w / 9.0))
	var slats := MeshBuilder.glow(Color(0.6, 0.61, 0.63), MeshBuilder.SIDING)
	for i in doors:
		var dx := -w * 0.5 + w * (i + 0.5) / doors
		mb.box(Vector3(dx, 2.3, -d * 0.5 - 0.1), Vector3(4.0, 4.4, 0.1), slats)
		mb.box(Vector3(dx, 4.6, -d * 0.5 - 0.15), Vector3(4.3, 0.3, 0.15), Color(0.95, 0.75, 0.2))
		# LED wall pack over each door.
		mb.box(Vector3(dx, 5.2, -d * 0.5 - 0.2), Vector3(0.5, 0.25, 0.2), MeshBuilder.glow(Color(0.95, 0.97, 1.0), MeshBuilder.GLOW_LAMP))
		for side in [-1.0, 1.0]:
			mb.box(Vector3(dx + side * 1.6, 0.9, -d * 0.5 - 3.05), Vector3(0.3, 0.5, 0.15), Color(0.1, 0.1, 0.1))
	mb.box(Vector3(0, 0.6, -d * 0.5 - 1.5), Vector3(w * 0.9, 1.2, 3.0), MeshBuilder.glow(STONE.darkened(0.15), MeshBuilder.CONCRETE))
	for side in [-1.0, 1.0]:
		mb.cylinder(Vector3(side * w * 0.47, 0.0, -d * 0.5 - 3.4), 0.14, 1.1, MeshBuilder.glow(Color(0.95, 0.78, 0.15), MeshBuilder.GLOSS), 6)
	if rng.randf() < 0.6:
		Props.graffiti(mb, Vector3(rng.randf_range(-w * 0.3, w * 0.3), 6.0, -d * 0.5 - 0.12), rng.randf_range(2.5, 4.5), rng)
	_solid_only(out, Vector3(0, 0.6, -d * 0.5 - 1.5), Vector3(w * 0.9, 1.2, 3.0))
	var gable_c := Vector3(0, h + 0.6, 0)
	var gable_s := Vector3(w + 0.4, 1.2, d + 0.4)
	mb.gable(gable_c, gable_s, MeshBuilder.glow(Color(0.62, 0.64, 0.66) if rng.randf() < 0.5 else body.darkened(0.35), MeshBuilder.SEAM_ROOF), body)
	if number < 0 and rng.randf() < 0.5:
		_slope_solar(mb, gable_c, gable_s, 1.2)
		# The back slope, mirrored.
		var saved: Transform3D = mb.xform
		mb.xform = saved * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
		_slope_solar(mb, gable_c, gable_s, 1.2)
		mb.xform = saved
	else:
		# Skylight strips down the back slope.
		var saved: Transform3D = mb.xform
		mb.xform = saved * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
		for i in 3:
			var x := -w * 0.3 + i * w * 0.3
			_slope_quad(mb, gable_c, gable_s, x - 0.7, x + 0.7, 0.2, 0.8, MeshBuilder.glow(SKY_GLASS, MeshBuilder.GLASS))
		mb.xform = saved
	for i in 2:
		mb.cylinder(Vector3(-w * 0.15 + i * w * 0.3, h + 1.1, 0.0), 0.45, 0.6, MeshBuilder.glow(CHROME, MeshBuilder.METAL), 8)
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
	mb.box(Vector3(0, 3.0, -9.05), Vector3(6.0, 5.6, 0.1), MeshBuilder.glow(DARK, MeshBuilder.GLOW_WINDOW))
	mb.box(Vector3(13.0, 15.5, 5.4), Vector3(2.4, 2.4, 0.05), MeshBuilder.glow(Color(1.0, 0.95, 0.8), MeshBuilder.GLOW_LAMP))
	mb.gable(Vector3(0, 11.6, -7.0), Vector3(12.0, 2.0, 6.0), body.darkened(0.25), body)
	_solid(mb, out, Vector3(13.0, 9.0, 8.0), Vector3(5.0, 18.0, 5.0), body.darkened(0.08))
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
	mb.box(Vector3(0, 6.2, -7.1), Vector3(12.0, 1.2, 0.1), MeshBuilder.glow(Color(1.0, 0.85, 0.35), MeshBuilder.GLOW_NEON))
	mb.box(Vector3(9.5, 6.0, -7.4), Vector3(0.9, 1.4, 0.9), MeshBuilder.glow(Color(0.4, 0.75, 1.0), MeshBuilder.GLOW_NEON))
	mb.box(Vector3(-6.0, 1.6, -7.06), Vector3(5.0, 2.0, 0.08), MeshBuilder.glow(Color(0.6, 0.3, 0.7), MeshBuilder.GLOW_WINDOW))
	mb.box(Vector3(6.0, 1.6, -7.06), Vector3(5.0, 2.0, 0.08), MeshBuilder.glow(Color(0.6, 0.3, 0.7), MeshBuilder.GLOW_WINDOW))
	_gallery_front(mb, 24.0, 18.0)
	var saved: Transform3D = mb.xform
	mb.xform = saved * Transform3D(Basis(), Vector3(0, 0, 2.0))
	_flat_roof(mb, 24.0, 18.0, 8.3, rng, blue.darkened(0.3))
	mb.xform = saved


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
	var rng := RandomNumberGenerator.new()
	rng.seed = 911
	var saved: Transform3D = mb.xform
	mb.xform = saved * Transform3D(Basis(), Vector3(0, 0, 4.0))
	_flat_roof(mb, 28.0, 18.0, 9.3, rng, body.darkened(0.3))
	mb.xform = saved
	mb.box(Vector3(0, 1.6, -5.06), Vector3(4.0, 3.2, 0.1), MeshBuilder.glow(Color(0.25, 0.32, 0.4), MeshBuilder.GLOW_WINDOW))
	mb.box(Vector3(0, 4.2, -5.1), Vector3(5.0, 0.6, 0.06), MeshBuilder.glow(Color(0.35, 0.55, 1.0), MeshBuilder.GLOW_NEON))
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
	mb.box(Vector3(0, 7.95, 2.0), Vector3(8.0, 0.1, 2.4), MeshBuilder.glow(Color(0.85, 0.15, 0.15), MeshBuilder.GLOW_NEON))
	mb.box(Vector3(0, 7.95, 2.0), Vector3(2.4, 0.1, 8.0), MeshBuilder.glow(Color(0.85, 0.15, 0.15), MeshBuilder.GLOW_NEON))
	mb.box(Vector3(0, 3.4, -9.6), Vector3(8.0, 0.25, 3.0), Color(0.85, 0.15, 0.15))
	var clinic_glass := MeshBuilder.glow(Color(0.5, 0.7, 0.85), MeshBuilder.GLOW_WINDOW)
	mb.box(Vector3(0, 1.4, -8.05), Vector3(3.2, 2.8, 0.1), clinic_glass)
	for i in 6:
		mb.box(Vector3(-10.0 + i * 4.0, 4.6, -8.05), Vector3(2.2, 1.4, 0.08), clinic_glass)


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
static func lantern_square(mb, out: Array, props, rng: RandomNumberGenerator, glow = null) -> void:
	mb.box(Vector3(0, 0.17, 0), Vector3(34.0, 0.04, 34.0), Color(0.72, 0.66, 0.58))
	for corner in [Vector3(-11, 0, -11), Vector3(11, 0, -11), Vector3(-11, 0, 11), Vector3(11, 0, 11)]:
		mb.box(corner + Vector3(0, 0.2, 0), Vector3(9.0, 0.06, 9.0), Color(0.38, 0.62, 0.32))
		props.oak(mb, out, corner, rng)
	mb.cylinder(Vector3(0, 0.15, 0), 4.0, 0.5, STONE, 8)
	mb.cylinder(Vector3(0, 0.2, 0), 3.6, 0.5, Color(0.35, 0.6, 0.75), 8)
	mb.box(Vector3(0, 1.5, 0), Vector3(1.2, 3.0, 1.2), STONE.darkened(0.1))
	mb.box(Vector3(0, 3.4, 0), Vector3(1.0, 0.8, 1.0), MeshBuilder.glow(Color(1.0, 0.85, 0.35), MeshBuilder.GLOW_LAMP))
	mb.box(Vector3(0, 3.95, 0), Vector3(1.3, 0.25, 1.3), IRON)
	_solid_only(out, Vector3(0, 1.5, 0), Vector3(2.4, 3.0, 2.4))
	for p in [Vector3(-6, 0, -16), Vector3(6, 0, -16), Vector3(-6, 0, 16), Vector3(6, 0, 16)]:
		props.gas_lamp(mb, out, p, glow)
	if glow != null:
		glow.xform = mb.xform
		glow.light_pool(Vector3(0, 0.25, 0), Vector2(8.0, 8.0), Color(0.6, 0.45, 0.2))
		glow.xform = Transform3D.IDENTITY
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

## Modern flat roof inside a parapet, `top` being the roof surface: a
## membrane (now and then a sedum green roof) with HVAC units, vents and,
## on bigger roofs, a stair hut at the back; the front half gets solar rows,
## a roof terrace or skylights. `plain` keeps it to membrane, parapet and
## plant (roofs with a sign painted on them).
static func _flat_roof(mb, w: float, d: float, top: float, rng: RandomNumberGenerator, edge: Color, plain := false) -> void:
	var green := not plain and w * d > 60.0 and rng.randf() < 0.15
	var membrane: Color = MEMBRANES[rng.randi() % MEMBRANES.size()]
	mb.box(Vector3(0, top + 0.02, 0), Vector3(w - 0.3, 0.04, d - 0.3), MeshBuilder.glow(SEDUM, MeshBuilder.GRASS) if green else MeshBuilder.glow(membrane, MeshBuilder.ROOF))
	var t := 0.22
	var ph := 0.45
	var coping := MeshBuilder.glow(edge.lightened(0.25), MeshBuilder.CONCRETE)
	for side in [-1.0, 1.0]:
		mb.box(Vector3(side * (w * 0.5 - t * 0.5), top + ph * 0.5, 0), Vector3(t, ph, d), edge)
		mb.box(Vector3(0, top + ph * 0.5, side * (d * 0.5 - t * 0.5)), Vector3(w - t * 2.0, ph, t), edge)
		mb.box(Vector3(side * (w * 0.5 - t * 0.5), top + ph + 0.02, 0), Vector3(t + 0.06, 0.04, d + 0.06), coping)
		mb.box(Vector3(0, top + ph + 0.02, side * (d * 0.5 - t * 0.5)), Vector3(w, 0.04, t + 0.06), coping)
	var x0 := -w * 0.5 + 0.7
	var x1 := w * 0.5 - 0.7
	# Back half: plant, a stair hut on bigger roofs, vents and a dish.
	var hut := w * d > 70.0 and w > 6.0
	if hut:
		_stair_hut(mb, Vector3(x1 - 1.1, top, d * 0.5 - 1.9), edge)
	var plant_x1 := x1 - 2.6 if hut else x1
	if w > 6.0:
		_hvac(mb, Vector3(lerpf(x0, plant_x1, rng.randf_range(0.2, 0.5)), top, d * 0.18), Vector3(minf(2.4, w * 0.3), 1.0, 1.3))
	else:
		_hvac(mb, Vector3(x0 + 0.6, top, d * 0.22), Vector3(0.9, 0.7, 0.55))
	for i in rng.randi_range(1, 3):
		mb.cylinder(Vector3(rng.randf_range(x0, plant_x1), top, rng.randf_range(0.0, d * 0.5 - 0.7)), 0.08, 0.7, MeshBuilder.glow(CHROME, MeshBuilder.METAL), 5)
	if not plain and rng.randf() < 0.3:
		_dish(mb, Vector3(x0 + 0.4, top, d * 0.5 - 0.7))
	if plain:
		return
	# Front half.
	var z0 := -d * 0.5 + 0.6
	var z1 := -0.4
	var roll := rng.randf()
	if green:
		_terrace(mb, x0, x0 + (x1 - x0) * 0.45, z0, z1, top, rng)
	elif roll < 0.4 and z1 - z0 > 1.8:
		_solar(mb, x0, x1, z0, z1, top)
	elif roll < 0.62 and z1 - z0 > 2.2:
		_terrace(mb, x0, x1, z0, z1, top, rng)
	elif roll < 0.85:
		var n := maxi(1, int((x1 - x0) / 2.6))
		for i in n:
			var x := x0 + (x1 - x0) * (i + 0.5) / n
			mb.box(Vector3(x, top + 0.2, (z0 + z1) * 0.5), Vector3(1.1, 0.35, minf(1.8, z1 - z0)), MeshBuilder.glow(SKY_GLASS, MeshBuilder.GLASS))
	else:
		_hvac(mb, Vector3(lerpf(x0, x1, 0.6), top, (z0 + z1) * 0.5), Vector3(0.9, 0.7, 0.55))


## Rooftop air-handling unit with dark fan grilles on top.
static func _hvac(mb, base: Vector3, size: Vector3) -> void:
	mb.box(base + Vector3(0, size.y * 0.5 + 0.08, 0), size, MeshBuilder.glow(UNIT, MeshBuilder.METAL))
	var fans := maxi(1, int(size.x / 1.1))
	var r := minf(size.x / fans, size.z) * 0.36
	for i in fans:
		var x := base.x - size.x * 0.5 + (i + 0.5) * size.x / fans
		mb.cylinder(Vector3(x, base.y + size.y + 0.08, base.z), r, 0.03, Color(0.16, 0.17, 0.19), 7)


## Stair and lift bulkhead with a steel door facing the front.
static func _stair_hut(mb, base: Vector3, edge: Color) -> void:
	mb.box(base + Vector3(0, 1.25, 0), Vector3(2.2, 2.5, 2.6), edge)
	mb.box(base + Vector3(0, 2.52, 0), Vector3(2.4, 0.06, 2.8), MeshBuilder.glow(MEMBRANES[1], MeshBuilder.ROOF))
	mb.box(base + Vector3(0.35, 1.05, -1.32), Vector3(0.9, 2.1, 0.06), MeshBuilder.glow(Color(0.32, 0.36, 0.4), MeshBuilder.METAL))
	mb.box(base + Vector3(0.35, 2.25, -1.35), Vector3(0.3, 0.12, 0.06), MeshBuilder.glow(Color(1.0, 0.95, 0.85), MeshBuilder.GLOW_LAMP))


static func _dish(mb, base: Vector3) -> void:
	mb.cylinder(base, 0.04, 0.6, Color(0.5, 0.5, 0.52), 4)
	mb.ball(base + Vector3(0, 0.75, 0), Vector3(0.4, 0.12, 0.4), Color(0.88, 0.88, 0.86), 7, 2)


## Rows of solar panels on rails, tilted up toward the back so they face
## the front (-Z), filling x0..x1 by z0..z1 at roof height `y`.
static func _solar(mb, x0: float, x1: float, z0: float, z1: float, y: float) -> void:
	const DEPTH := 1.6
	const RISE := 0.4
	x0 = ceilf(x0)
	x1 = floorf(x1)
	if x1 - x0 < 1.0:
		return
	var panel := MeshBuilder.glow(SOLAR_BLUE, MeshBuilder.SOLAR)
	var z := z0
	while z + DEPTH <= z1:
		var lo := y + 0.25
		var a := Vector3(x0, lo, z)
		var b := Vector3(x1, lo, z)
		var c := Vector3(x1, lo + RISE, z + DEPTH)
		var e := Vector3(x0, lo + RISE, z + DEPTH)
		mb.quad(a, b, c, e, (e - a).cross(b - a).normalized(), panel)
		mb.quad(e, c, Vector3(x1, y, z + DEPTH), Vector3(x0, y, z + DEPTH), Vector3.BACK, Color(0.3, 0.32, 0.35))
		z += DEPTH + 0.7


## Solar panels laid on the front slope of a gable built by mb.gable with the
## same `center` and `size` (ridge along local X), set in from the edges.
static func _slope_solar(mb, center: Vector3, size: Vector3, inset: float) -> void:
	var x0 := ceilf(center.x - size.x * 0.5 + inset)
	var x1 := floorf(center.x + size.x * 0.5 - inset)
	if x1 - x0 >= 1.0:
		_slope_quad(mb, center, size, x0, x1, 0.18, 0.82, MeshBuilder.glow(SOLAR_BLUE, MeshBuilder.SOLAR))


## A panel lying just above the front slope of that gable, from x0 to x1
## and from f0 to f1 of the way up from the eave to the ridge.
static func _slope_quad(mb, center: Vector3, size: Vector3, x0: float, x1: float, f0: float, f1: float, color: Color) -> void:
	var h := size * 0.5
	var n := Vector3(0, h.z, -h.y).normalized()
	var y0 := center.y - h.y + n.y * 0.08
	var zf := center.z - h.z + n.z * 0.08
	var a := Vector3(0, y0 + size.y * f0, zf + h.z * f0)
	var b := Vector3(0, y0 + size.y * f1, zf + h.z * f1)
	mb.quad(Vector3(x0, a.y, a.z), Vector3(x1, a.y, a.z), Vector3(x1, b.y, b.z), Vector3(x0, b.y, b.z), n, color)


## Roof terrace: a timber deck with planters, loungers and a parasol.
static func _terrace(mb, x0: float, x1: float, z0: float, z1: float, y: float, rng: RandomNumberGenerator) -> void:
	var mid := Vector3((x0 + x1) * 0.5, y, (z0 + z1) * 0.5)
	mb.box(mid + Vector3(0, 0.07, 0), Vector3(x1 - x0, 0.06, z1 - z0), MeshBuilder.glow(DECK, MeshBuilder.SIDING))
	var planter := Color(0.3, 0.31, 0.33)
	mb.box(Vector3(mid.x, y + 0.3, z0 + 0.25), Vector3(x1 - x0, 0.5, 0.4), planter)
	var n := maxi(2, int((x1 - x0) / 1.4))
	for i in n:
		var x := x0 + (x1 - x0) * (i + 0.5) / n
		mb.ball(Vector3(x, y + 0.75, z0 + 0.25), Vector3(0.45, 0.35, 0.3), Color(0.26, 0.48, 0.24).lightened(rng.randf() * 0.15), 5, 2)
	var shade: Color = PARASOLS[rng.randi() % PARASOLS.size()]
	var px := lerpf(x0, x1, 0.65)
	var pz := lerpf(z0, z1, 0.6)
	mb.cylinder(Vector3(px, y + 0.1, pz), 0.04, 2.1, Color(0.85, 0.85, 0.85), 4)
	mb.ball(Vector3(px, y + 2.15, pz), Vector3(1.2, 0.28, 1.2), shade, 8, 2)
	for k in 2:
		var lx := lerpf(x0, x1, 0.2 + 0.18 * k)
		mb.box(Vector3(lx, y + 0.25, pz), Vector3(0.6, 0.18, 1.6), Color(0.94, 0.94, 0.92))


static func _solid(mb, out: Array, center: Vector3, size: Vector3, color: Color) -> void:
	mb.box(center, size, color)
	out.append([center, size])


static func _solid_only(out: Array, center: Vector3, size: Vector3) -> void:
	out.append([center, size])
