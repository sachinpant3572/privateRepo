extends RefCounted
## Bellerive homes by wealth (BX-4) for the streamed country layer: a T5
## residential tower, a T3-T4 mid-rise condo, a T0-T1 walk-up block, a T4
## executive house and an estate gatehouse. country_kit.gd's build()
## dispatches here; the lot frame, the collision format, Kit.wealth,
## Kit.reach and Kit.live_cars are country_kit's (see its header). Static
## functions only, everything drawn from `rng`, no text or brands.

const MeshBuilder = preload("res://scripts/mesh_builder.gd")
const Buildings = preload("res://scripts/kits/building_kit.gd")
const Props = preload("res://scripts/kits/prop_kit.gd")
const Civic = preload("res://scripts/kits/civic_kit.gd")
const Skyline = preload("res://scripts/kits/skyline_kit.gd")
const Shady = preload("res://scripts/kits/shady_kit.gd")
const Kit = preload("res://scripts/kits/country_kit.gd")

const WARM_LIT := Color(0.5, 0.44, 0.34)
const BRONZE := Color(0.42, 0.31, 0.2)
const STUCCO := Color(0.93, 0.9, 0.84)
const CARPET := Color(0.45, 0.08, 0.1)
const HAZARD := Color(0.95, 0.78, 0.15)


static func _g(c: Color, code: float) -> Color:
	return MeshBuilder.glow(c, code)


## Lit stone gate piers either side of a gate gx wide at x, z: a pier with
## a cap and a glowing lamp ball, each colliding.
static func _lit_piers(mb, out: Array, x: float, z: float, gw: float, h := 1.6) -> void:
	var stucco := _g(STUCCO, MeshBuilder.CONCRETE)
	for s: float in [-1.0, 1.0]:
		var p := Vector3(x + s * (gw * 0.5 + 0.35), 0, z)
		Kit._solid(mb, out, p + Vector3(0, h * 0.5, 0), Vector3(0.7, h, 0.7), stucco)
		mb.box(p + Vector3(0, h + 0.06, 0), Vector3(0.84, 0.12, 0.84), STUCCO.darkened(0.08))
		mb.ball(p + Vector3(0, h + 0.32, 0), Vector3(0.2, 0.2, 0.2), _g(Color(1.0, 0.9, 0.6), MeshBuilder.GLOW_LAMP), 6, 3)


## A sun lounger (0.65 x 1.7) at p, its head toward +Z.
static func _lounger(mb, p: Vector3, color := Kit.WHITE) -> void:
	mb.box(p + Vector3(0, 0.22, -0.2), Vector3(0.65, 0.12, 1.3), color)
	mb.box(p + Vector3(0, 0.42, 0.62), Vector3(0.65, 0.12, 0.55), color)


# --- res_tower ------------------------------------------------------------------

## A T5 residential tower (T4 at a pinch): a stone podium (lit lobby glass,
## a bronze louvre band, a garden deck with palms), a shaft of 11-17 floors
## in warm bronze glass with full-width balconies and glass rails, a
## set-back glass penthouse crown (lit after dark) under a floating lit
## roof slab with corner beacons and, at T5, a pool terrace in front; a
## doorman canopy with a carpet runner, a valet stand and planters over the
## drop-off; a garage ramp down at one side to a portal in the podium.
## Shaft roof 42-61 m, crown slab top under 70 m.
static func res_tower(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var t := Kit._wealth(4, 5, 5)
	var side := Kit._clear_side(-1.0 if rng.randf() < 0.5 else 1.0)  # the ramp's side
	const FH := 3.2
	const PH := 7.0
	var floors := rng.randi_range(11, 17) if t >= 5 else rng.randi_range(11, 14)
	var stone := Civic._stone(Color(0.86, 0.82, 0.74))
	var bronze := _g(BRONZE, MeshBuilder.METAL)
	var glass := _g(Color(0.46, 0.4, 0.31), MeshBuilder.GLASS)
	var rail := _g(Color(0.62, 0.68, 0.64), MeshBuilder.GLASS)
	var white := Color(0.93, 0.91, 0.86)
	var asphalt := _g(Kit.ASPHALT, MeshBuilder.ASPHALT)
	var concrete := _g(Kit.CONCRETE, MeshBuilder.CONCRETE)
	Kit._pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, _g(Color(0.84, 0.8, 0.72), MeshBuilder.PAVING))
	# Podium: two storeys of stone from fz back; the drop-off in front.
	var fz := -d * 0.5 + clampf(d * 0.22, 6.0, 8.0)
	var pw := w - 2.0
	var pz1 := minf(fz + maxf(d * 0.6, 14.0), d * 0.5 - 1.0)
	var pd := pz1 - fz
	var pcz := (fz + pz1) * 0.5
	Kit._solid(mb, out, Vector3(0, PH * 0.5, pcz), Vector3(pw, PH, pd), stone)
	mb.box(Vector3(0, PH + 0.15, pcz), Vector3(pw + 0.4, 0.3, pd + 0.4), white)
	# Door and ramp positions, in side-relative x (u; x = u * side).
	var lu := -clampf(w * 0.12, 2.5, 4.5)
	var ru := pw * 0.5 - 2.6
	var lx := lu * side
	var rc := ru * side
	# Front: lit lobby glass, the louvre band above, the garage portal.
	mb.box(Vector3(lx, 2.0, fz - 0.05), Vector3(minf(9.0, pw * 0.4), 3.6, 0.08), _g(WARM_LIT, MeshBuilder.GLOW_WINDOW))
	mb.box(Vector3(0, 5.1, fz - 0.05), Vector3(pw - 1.0, 2.4, 0.08), glass)
	var nf := maxi(4, int(pw / 2.6))
	for k in nf + 1:
		mb.box(Vector3(lerpf(-pw * 0.5 + 0.5, pw * 0.5 - 0.5, float(k) / nf), 5.1, fz - 0.2), Vector3(0.22, 2.8, 0.36), bronze)
	mb.box(Vector3(rc, 1.35, fz - 0.05), Vector3(3.6, 2.7, 0.08), Color(0.04, 0.04, 0.05))
	mb.box(Vector3(rc, 2.85, fz - 0.15), Vector3(4.2, 0.3, 0.3), HAZARD)
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(rc + s * 1.95, 1.35, fz - 0.15), Vector3(0.3, 2.7, 0.3), concrete)
	# The ramp: a lane down between low walls, darkening toward the portal.
	var zr0 := lerpf(-d * 0.5, fz, 0.3)
	Kit._pad(mb, rc - 1.8, rc + 1.8, -d * 0.5, zr0, asphalt, 0.04)
	Kit._route_out(mb, rc - 1.6, rc + 1.6, d, asphalt)
	for k in 4:
		var z0 := lerpf(zr0, fz, k / 4.0)
		var z1 := lerpf(zr0, fz, (k + 1) / 4.0)
		Kit._pad(mb, rc - 1.8, rc + 1.8, z0, z1, _g(Kit.ASPHALT.darkened(0.15 + k * 0.18), MeshBuilder.ASPHALT), 0.04)
	Kit._line(mb, Vector3(rc - 1.7, 0, zr0), Vector3(rc + 1.7, 0, zr0), 0.3, HAZARD)
	for s: float in [-1.0, 1.0]:
		Kit._solid(mb, out, Vector3(rc + s * 1.95, 0.45, (zr0 + fz) * 0.5), Vector3(0.3, 0.9, fz - zr0), concrete)
	# Drop-off, doorman canopy, carpet, valet stand, planters, the car.
	var dx0 := maxf(lu - 6.0, -w * 0.5 + 0.6)
	var dx1 := lu + 6.0
	Kit._pad(mb, minf(dx0 * side, dx1 * side), maxf(dx0 * side, dx1 * side), -d * 0.5, fz, asphalt, 0.04)
	Kit._route_out(mb, lx - 2.6, lx + 2.6, d, asphalt)
	var cz0 := fz - 5.0
	Kit._canopy(mb, out, lx - 3.2, lx + 3.2, cz0, fz, 4.4, 0.4, bronze, _g(Buildings.MEMBRANES[0], MeshBuilder.ROOF), [Vector3(lx - 3.0, 0, cz0 + 0.3), Vector3(lx + 3.0, 0, cz0 + 0.3)], bronze)
	mb.box(Vector3(lx, 4.2, cz0 - 0.03), Vector3(6.4, 0.12, 0.04), Skyline._lamp())
	for k in 3:
		mb.box(Vector3(lx + (k - 1) * 2.0, 3.98, (cz0 + fz) * 0.5), Vector3(0.5, 0.03, 0.5), Skyline._lamp())
	Kit._pad(mb, lx - 0.7, lx + 0.7, fz - 2.0, fz, CARPET, 0.06)
	mb.box(Vector3(lx, 1.5, fz - 0.1), Vector3(2.2, 3.0, 0.06), _g(Kit.GOLD.darkened(0.3), MeshBuilder.GLOSS))
	Kit._solid(mb, out, Vector3(lx + 2.2, 0.55, fz - 1.3), Vector3(0.6, 1.1, 0.45), bronze)
	for s: float in [-1.0, 1.0]:
		Props.planter(mb, out, Vector3(lx + s * 1.7, 0, fz - 0.8))
	Kit._wealth_car(mb, out, Vector3(lx, 0, fz - 3.0), PI * 0.5, t, rng)
	# Palms at the front: one on the open corner, one between drop-off and ramp.
	if dx0 > -w * 0.5 + 3.0:
		Props.palm(mb, out, Vector3(-(w * 0.5 - 2.0) * side, 0, -d * 0.5 + 2.2), rng)
	if (ru - 1.8) - dx1 > 3.0:
		Props.palm(mb, out, Vector3((dx1 + ru - 1.8) * 0.5 * side, 0, -d * 0.5 + 2.5), rng)
	Kit._lot_fence(mb, out, w, d, "hedge", Kit.LEAF, [], false)
	# Shaft.
	var sw := clampf(w * 0.56, 13.0, 20.0)
	var sd := clampf(pd * 0.75, 11.0, 17.0)
	var scz := pcz + (pd - sd) * 0.15
	var sf := scz - sd * 0.5
	var sb := scz + sd * 0.5
	var ct := PH + floors * FH
	Kit._solid(mb, out, Vector3(0, (PH + ct) * 0.5, scz), Vector3(sw, ct - PH, sd), white)
	var lit := _g(WARM_LIT, MeshBuilder.GLOW_WINDOW)
	for f in floors:
		var y := PH + f * FH
		for s: float in [-1.0, 1.0]:
			var z := scz + s * sd * 0.5
			mb.box(Vector3(0, y + 1.65, z + s * 0.04), Vector3(sw - 1.0, 2.5, 0.08), glass)
			if rng.randf() < 0.45:
				mb.box(Vector3(rng.randf_range(-sw * 0.33, sw * 0.33), y + 1.6, z + s * 0.1), Vector3(2.6, 2.3, 0.04), lit)
			if f > 0:
				mb.box(Vector3(0, y + 0.1, z + s * 0.9), Vector3(sw - 0.6, 0.2, 1.8), white)
				mb.box(Vector3(0, y + 0.7, z + s * 1.78), Vector3(sw - 0.6, 1.0, 0.04), rail)
		for s: float in [-1.0, 1.0]:
			mb.box(Vector3(s * (sw * 0.5 + 0.04), y + 1.65, scz), Vector3(0.08, 2.5, sd - 1.4), glass)
	# Balcony dividers, full height, front and back.
	for k in 4:
		var x := lerpf(-sw * 0.5 + 0.35, sw * 0.5 - 0.35, k / 3.0)
		for s: float in [-1.0, 1.0]:
			mb.box(Vector3(x, (PH + 0.3 + ct) * 0.5, scz + s * (sd * 0.5 + 0.9)), Vector3(0.3, ct - PH - 0.3, 1.8), white)
	# Podium garden deck round the shaft: a glass rail, lawn beds, palms.
	var deck := _g(Color(0.8, 0.76, 0.68), MeshBuilder.PAVING)
	mb.box(Vector3(0, PH + 0.32, pcz), Vector3(pw, 0.04, pd), deck)
	mb.box(Vector3(0, PH + 0.85, fz + 0.1), Vector3(pw, 1.1, 0.04), rail)
	for s: float in [-1.0, 1.0]:
		var bx := s * (sw * 0.5 + pw * 0.5) * 0.5
		var bwid := pw * 0.5 - sw * 0.5 - 1.0
		if bwid > 1.5:
			mb.box(Vector3(bx, PH + 0.36, pcz), Vector3(bwid, 0.04, pd - 2.0), Civic._grass())
			if sf - fz > 2.5 or bwid > 3.0:
				Props.palm(mb, out, Vector3(bx, PH + 0.35, fz + 2.0), rng)
	# Crown: the shaft's roof deck, the set-back glass penthouse, the floating
	# lit slab with its beacons, and the terrace in front.
	const CH := 6.4
	mb.box(Vector3(0, ct + 0.05, scz), Vector3(sw, 0.1, sd), _g(Buildings.DECK, MeshBuilder.SIDING))
	var cw := sw - 2.0
	var cd := sd - 5.0
	var ccz := scz + 1.5
	Kit._solid(mb, out, Vector3(0, ct + CH * 0.5, ccz), Vector3(cw, CH, cd), _g(Color(0.4, 0.38, 0.33), MeshBuilder.GLOW_WINDOW))
	mb.box(Vector3(0, ct + 3.2, ccz), Vector3(cw + 0.2, 0.3, cd + 0.2), white)
	for k in 6:
		mb.box(Vector3(lerpf(-cw * 0.5 + 0.1, cw * 0.5 - 0.1, k / 5.0), ct + CH * 0.5, ccz - cd * 0.5 - 0.06), Vector3(0.14, CH, 0.12), bronze)
	mb.box(Vector3(0, ct + CH + 0.2, ccz), Vector3(cw - 0.4, 0.4, cd - 0.4), Skyline._lamp(Color(1.0, 0.88, 0.62)))
	var st := ct + CH + 0.9
	# The slab overhangs the penthouse only, so the terrace stays open to the
	# sky (and to the camera); its top is a dark membrane inside a white rim.
	var slab_z0 := ccz - cd * 0.5 - 0.8
	var slab_z1 := minf(ccz + cd * 0.5 + 0.6, sb + 0.4)
	var slab_c := (slab_z0 + slab_z1) * 0.5
	var slab_w := cw + 1.6
	mb.box(Vector3(0, st - 0.25, slab_c), Vector3(slab_w, 0.5, slab_z1 - slab_z0), white)
	mb.box(Vector3(0, st + 0.01, slab_c), Vector3(slab_w - 1.0, 0.02, slab_z1 - slab_z0 - 1.0), _g(Color(0.3, 0.3, 0.32), MeshBuilder.ROOF))
	mb.box(Vector3(0, st - 0.52, slab_c), Vector3(slab_w - 0.4, 0.03, slab_z1 - slab_z0 - 0.4), Skyline._lamp(Color(1.0, 0.9, 0.7)))
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(s * (slab_w * 0.5 - 0.3), (ct + st - 0.5) * 0.5, slab_z0 + 0.3), Vector3(0.18, st - 0.5 - ct, 0.18), bronze)
	Skyline._corner_beacons(mb, 0.0, slab_c, slab_w, slab_z1 - slab_z0, st)
	mb.box(Vector3(0, ct + 0.65, sf + 0.1), Vector3(sw - 0.2, 1.1, 0.04), rail)
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(s * (sw * 0.5 - 0.1), ct + 0.65, sf + 2.0), Vector3(0.04, 1.1, 3.8), rail)
	if t >= 5:
		var px := -sw * 0.14
		mb.box(Vector3(px, ct + 0.1, sf + 2.1), Vector3(sw * 0.5 + 0.6, 0.2, 2.8), white)
		mb.box(Vector3(px, ct + 0.21, sf + 2.1), Vector3(sw * 0.5, 0.02, 2.2), Kit.POOL)
		for k in 3:
			_lounger(mb, Vector3(sw * 0.2 + k * 0.95, ct + 0.1, sf + 2.0))
	else:
		for k in 3:
			mb.box(Vector3((k - 1) * sw * 0.3, ct + 0.4, sf + 1.0), Vector3(1.2, 0.6, 0.8), Civic._stone(Color(0.7, 0.68, 0.64)))
			Kit._bush(mb, Vector3((k - 1) * sw * 0.3, ct + 0.7, sf + 1.0), 0.5, rng)


# --- midrise_condo --------------------------------------------------------------

## A T3-T4 mid-rise condo: a 5-8 storey slab at the back of the lot with a
## balcony on every unit, a lit lobby under a canopy and a roof terrace.
## T3 (5-6 floors, 15-19 m): pastel stucco, metal balcony rails, residents
## parked nose-in on a surface lot behind a low brick wall, a pergola on
## the roof. T4 (6-8 floors, 19-25 m): on an open parking podium of
## columns with the cars under the building, glass rails, a paved motor
## court with a car at the door, a hedge with lit piers, a roof pool.
static func midrise_condo(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var t := Kit._wealth(3, 4, 4)
	const FH := 3.1
	var floors := rng.randi_range(5, 6) if t <= 3 else rng.randi_range(6, 8)
	var side := Kit._clear_side(-1.0 if rng.randf() < 0.5 else 1.0)
	var bl := clampf(w - 4.0, 12.0, 26.0)
	var bd := clampf(d * 0.42, 8.0, 11.0)
	var bz := d * 0.5 - 1.5
	var fz := bz - bd
	var cz := fz + bd * 0.5
	var ph := 3.0 if t >= 4 else 0.0
	var upper := floors - (1 if t >= 4 else 0)
	var H := ph + upper * FH
	var paint: Color = Kit._pick(Kit.PASTELS, rng) if t <= 3 else STUCCO
	var white := Kit.TRIM
	var accent: Color = Kit._pick(Kit.ACCENTS, rng)
	var asphalt := _g(Kit.ASPHALT, MeshBuilder.ASPHALT)
	var paving := _g(Color(0.84, 0.8, 0.72), MeshBuilder.PAVING)
	var concrete := _g(Kit.CONCRETE, MeshBuilder.CONCRETE)
	var lit := _g(WARM_LIT, MeshBuilder.GLOW_WINDOW)
	Kit._pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, Civic._grass())
	Kit._solid(mb, out, Vector3(0, (ph + H) * 0.5, cz), Vector3(bl, H - ph, bd), paint)
	mb.box(Vector3(0, H - 0.2, cz), Vector3(bl + 0.3, 0.4, bd + 0.3), white)
	Kit._all_windows(mb, -bl * 0.5, bl * 0.5, fz, bz, ph, upper, FH, 3.2 if t <= 3 else 2.9, Vector2(1.3, 1.6) if t <= 3 else Vector2(1.9, 2.2), rng, 0.5)
	# Balconies: a slab and a rail along the front of each floor above the
	# ground, split by fins into one per unit.
	var units := maxi(3, int(bl / 4.4))
	var rail := _g(Color(0.6, 0.72, 0.74), MeshBuilder.GLASS) if t >= 4 else Color(0.18, 0.18, 0.2)
	var b0 := 1 if t <= 3 else 0
	for f in range(b0, upper):
		var y := ph + f * FH
		mb.box(Vector3(0, y + 0.1, fz - 0.75), Vector3(bl - 0.8, 0.2, 1.5), white)
		if t >= 4:
			mb.box(Vector3(0, y + 0.7, fz - 1.48), Vector3(bl - 0.8, 1.0, 0.04), rail)
		else:
			mb.box(Vector3(0, y + 1.15, fz - 1.46), Vector3(bl - 0.8, 0.06, 0.06), rail)
			mb.box(Vector3(0, y + 0.6, fz - 1.46), Vector3(bl - 0.8, 0.9, 0.02), Color(0.3, 0.3, 0.32))
	for u in units + 1:
		var x := lerpf(-bl * 0.5 + 0.4, bl * 0.5 - 0.4, float(u) / units)
		mb.box(Vector3(x, (ph + b0 * FH + H) * 0.5, fz - 0.75), Vector3(0.1, H - ph - b0 * FH, 1.5), white)
	# Roof: parapet and plant, then the terrace.
	Kit._flat_roof(mb, 0, cz, bl, bd, H, rng, accent.darkened(0.2), true)
	var deck := _g(Buildings.DECK, MeshBuilder.SIDING)
	mb.box(Vector3(-bl * 0.18, H + 0.08, cz), Vector3(bl * 0.5, 0.1, bd - 2.0), deck)
	if t >= 4:
		mb.box(Vector3(-bl * 0.18, H + 0.15, cz - 0.3), Vector3(bl * 0.32, 0.04, bd * 0.36), Kit.POOL)
		for k in 3:
			_lounger(mb, Vector3(-bl * 0.18 - bl * 0.14 + k * bl * 0.14, H + 0.12, cz + bd * 0.3))
		mb.box(Vector3(-bl * 0.18, H + 0.7, cz - bd * 0.5 + 1.05), Vector3(bl * 0.5, 1.0, 0.04), rail)
	else:
		var pg := _g(Color(0.42, 0.3, 0.2), MeshBuilder.SIDING)
		var gx0 := -bl * 0.18 - bl * 0.2
		var gx1 := -bl * 0.18 + bl * 0.2
		for x: float in [gx0, gx1]:
			for z: float in [cz - bd * 0.25, cz + bd * 0.25]:
				mb.box(Vector3(x, H + 1.3, z), Vector3(0.16, 2.6, 0.16), pg)
		for k in 5:
			mb.box(Vector3(lerpf(gx0, gx1, k / 4.0), H + 2.65, cz), Vector3(0.12, 0.18, bd * 0.5 + 0.6), pg)
		for z: float in [cz - bd * 0.25, cz + bd * 0.25]:
			mb.box(Vector3(-bl * 0.18, H + 2.5, z), Vector3(bl * 0.4 + 0.4, 0.16, 0.16), pg)
		for k in 3:
			var p := Vector3(bl * 0.12 + k * 1.5, H, cz - bd * 0.5 + 1.4)
			mb.box(p + Vector3(0, 0.3, 0), Vector3(1.0, 0.5, 0.6), Kit.TERRACOTTA)
			Kit._bush(mb, p + Vector3(0, 0.5, 0), 0.4, rng)
	if t >= 4:
		# Open parking storey: columns front and back, a lit glass lobby core,
		# a soffit under the floors above, the residents' cars nose-in.
		mb.box(Vector3(0, ph - 0.02, cz), Vector3(bl, 0.04, bd), concrete)
		Kit._pad(mb, -bl * 0.5, bl * 0.5, fz, bz, concrete, 0.04)
		var bays := maxi(2, int(bl / 5.4))
		var bay := bl / bays
		var core := bays / 2
		for i in bays + 1:
			var x := -bl * 0.5 + 0.25 + (bl - 0.5) * i / bays
			for z: float in [fz + 0.25, bz - 0.25]:
				Kit._post(mb, out, Vector3(x, 0, z), ph, 0.45, white)
		var cx := -bl * 0.5 + bay * (core + 0.5)
		Kit._solid(mb, out, Vector3(cx, ph * 0.5, cz), Vector3(bay - 1.0, ph, bd - 1.0), lit)
		for i in bays:
			if i == core:
				continue
			var x0 := -bl * 0.5 + i * bay
			Kit._stalls(mb, x0 + (bay - 5.4) * 0.5, fz + 0.4, 2, 2.7, 5.4, 1.0)
			for k in 2:
				if rng.randf() < 0.7:
					Kit._wealth_car(mb, out, Vector3(x0 + (bay - 5.4) * 0.5 + 1.35 + k * 2.7, 0, fz + 3.0), PI, t, rng)
		# Motor court with a car at the door; lawn, palms, a hedge, lit piers.
		var cz0 := maxf(fz - 6.5, -d * 0.5 + 1.4)
		Kit._pad(mb, -bl * 0.5 + 1.0, bl * 0.5 - 1.0, cz0, fz, paving, 0.04)
		Kit._pad(mb, -2.6, 2.6, -d * 0.5, cz0, paving, 0.04)
		Kit._route_out(mb, -2.6, 2.6, d, paving)
		Kit._canopy(mb, out, cx - 2.4, cx + 2.4, fz - 3.0, fz, 2.85, 0.3, accent, _g(Buildings.MEMBRANES[0], MeshBuilder.ROOF), [Vector3(cx - 2.2, 0, fz - 2.8), Vector3(cx + 2.2, 0, fz - 2.8)], white)
		if fz - cz0 >= 4.0:
			Kit._wealth_car(mb, out, Vector3(cx + 3.6 * side, 0, fz - 3.4), PI * 0.5, t, rng)
		# A palm's fronds reach about 3.9 m from its foot: it stands 3 m in
		# from the side, clear of the motor court.
		var px := w * 0.5 - 3.0
		var pz := -d * 0.5 + 3.0
		for s: float in [-1.0, 1.0]:
			if px > bl * 0.5 - 0.5 or pz < cz0 - 0.6:
				Props.palm(mb, out, Vector3(s * px, 0, pz), rng)
			else:
				Kit._bush(mb, Vector3(s * (bl * 0.5 - 2.5), 0, -d * 0.5 + 2.4), 0.7, rng)
		Kit._lot_fence(mb, out, w, d, "hedge", Kit.LEAF, [[0.0, 6.4]], true, 1.2, false)
		_lit_piers(mb, out, 0.0, -d * 0.5 + 1.2, 6.4)
	else:
		# Ground-floor lobby and its canopy, a walk to the street, the lot.
		mb.box(Vector3(0, 1.3, fz - 0.05), Vector3(3.0, 2.6, 0.08), lit)
		Kit._canopy(mb, out, -2.2, 2.2, fz - 2.6, fz, 2.95, 0.25, accent, _g(Buildings.MEMBRANES[0], MeshBuilder.ROOF), [Vector3(-2.0, 0, fz - 2.4), Vector3(2.0, 0, fz - 2.4)], white)
		var kerb := fz - 2.0
		var front := -d * 0.5 + 0.6
		Kit._pad(mb, -w * 0.5 + 0.8, w * 0.5 - 0.8, front, kerb, asphalt, 0.04)
		Kit._pad(mb, -bl * 0.5, bl * 0.5, kerb, fz, paving, 0.05)
		var gx := side * (w * 0.5 - 3.4)
		Kit._route_out(mb, gx - 2.2, gx + 2.2, d, asphalt)
		Kit._route_out(mb, -0.8, 0.8, d, paving)
		var stall_d := minf(5.5, kerb - front - 3.0)
		if stall_d >= 4.6:
			var n := int((w - 4.0) / 2.7)
			var x0 := -n * 1.35
			Kit._stalls(mb, x0, kerb, n, 2.7, stall_d, -1.0)
			for i in n:
				var x := x0 + 1.35 + i * 2.7
				if absf(x) > 1.6 and rng.randf() < 0.6:
					Kit._wealth_car(mb, out, Vector3(x, 0, kerb - 2.4), PI, t, rng)
		for k in 4:
			var x := lerpf(-bl * 0.5 + 1.0, bl * 0.5 - 1.0, k / 3.0)
			if absf(x) > 3.0:
				Kit._bush(mb, Vector3(x, 0, fz - 1.0), 0.6, rng)
		var brick := _g(Kit._pick(Kit.BRICKS, rng), MeshBuilder.BRICK) if Kit.BRICKS.size() > 0 else Kit.TERRACOTTA
		Kit._lot_fence(mb, out, w, d, "low", brick, [[gx, 5.0], [0.0, 1.8]], true, 0.6, false)


# --- cheap_block ----------------------------------------------------------------

## A T0-T1 walk-up block: 3-5 storeys of flats along open walkway galleries
## reached by an open steel switchback stair at one end; window AC units on
## the back, clothes hung over the rails and on lines in the side yard, a
## shabby flat roof, worn paint; a cracked, stained asphalt lot behind
## chain-link with beaters nose-in and a dumpster. T0 is poorer: more
## boarded and broken windows, barred ground floor, a torn bay in the
## fence, a stripped car on blocks, tyres, a dumped couch or mattress,
## bags and a spray tag.
static func cheap_block(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var t := Kit._wealth(0, 1, 1)
	const FH := 2.9
	const GD := 1.5
	var floors := rng.randi_range(3, 5)
	var H := floors * FH
	var side := 1.0 if rng.randf() < 0.5 else -1.0  # the stair and yard end
	var bl := clampf(w - 9.0, 12.0, 26.0)
	var bd := clampf(d * 0.4, 6.0, 8.0)
	var bz := d * 0.5 - 1.0
	var fz := bz - bd
	var cz := fz + bd * 0.5
	var bx := -side * maxf(0.0, (w - bl) * 0.5 - 1.0)
	var paint := Kit._worn(Kit._pick(Shady.FADED if t >= 1 else Shady.STUCCOS, rng), t)
	var concrete := _g(Shady.CONCRETE.darkened(0.08 if t == 0 else 0.0), MeshBuilder.CONCRETE)
	var rail_c: Color = Kit._worn(Kit._pick(Shady.RAILS, rng), t)
	var weights := [0.5, 0.1, 0.22, 0.1, 0.08] if t == 0 else [0.78, 0.08, 0.04, 0.02, 0.08]
	var bars := 0.8 if t == 0 else 0.5
	# The lot: dirt under everything, cracked asphalt in front.
	Kit._pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, _g(Shady.DIRT, MeshBuilder.GRASS))
	var kerb := fz - GD - 0.3
	Kit._pad(mb, -w * 0.5 + 0.3, w * 0.5 - 0.3, -d * 0.5 + 0.3, kerb, _g(Shady.ASPHALT, MeshBuilder.ASPHALT), 0.04)
	Shady._cracks(mb, -w * 0.5 + 0.8, w * 0.5 - 0.8, -d * 0.5 + 0.8, kerb - 0.4, 7 if t == 0 else 4, rng)
	Shady._stains(mb, -w * 0.5 + 1.0, w * 0.5 - 1.0, -d * 0.5 + 1.0, kerb - 0.5, 6 if t == 0 else 3, rng)
	Shady._weeds(mb, -w * 0.5 + 0.4, w * 0.5 - 0.4, -d * 0.5 + 0.4, -d * 0.5 + 1.0, 8 if t == 0 else 4, rng)
	# The block, its roof, the walkway galleries and their posts.
	Kit._solid(mb, out, Vector3(bx, H * 0.5, cz), Vector3(bl, H, bd), paint)
	mb.box(Vector3(bx, 0.3, cz), Vector3(bl + 0.06, 0.6, bd + 0.06), paint.darkened(0.2))
	Shady._shabby_roof(mb, bx - bl * 0.5, bx + bl * 0.5, fz, bz, H, paint.darkened(0.15), rng, 0.6)
	var gx0 := minf(bx - bl * 0.5, bx + side * (bl * 0.5 + 2.4))
	var gx1 := maxf(bx + bl * 0.5, bx + side * (bl * 0.5 + 2.4))
	if side < 0.0:
		gx1 = bx + bl * 0.5
	else:
		gx0 = bx - bl * 0.5
	Kit._pad(mb, gx0, gx1, fz - GD, fz, concrete, 0.06)
	mb.box(Vector3((gx0 + gx1) * 0.5, H + 0.05, fz - GD * 0.5), Vector3(gx1 - gx0, 0.1, GD), concrete)
	for f in range(1, floors):
		var y := f * FH
		mb.box(Vector3((gx0 + gx1) * 0.5, y, fz - GD * 0.5), Vector3(gx1 - gx0, 0.18, GD), concrete)
		mb.box(Vector3((gx0 + gx1) * 0.5, y + 1.0, fz - GD + 0.04), Vector3(gx1 - gx0, 0.06, 0.06), rail_c)
		mb.box(Vector3((gx0 + gx1) * 0.5, y + 0.5, fz - GD + 0.04), Vector3(gx1 - gx0, 0.05, 0.05), rail_c)
	var units := maxi(3, int(bl / 4.2))
	var uw := bl / units
	for u in units + 1:
		Kit._post(mb, out, Vector3(bx - bl * 0.5 + 0.1 + (bl - 0.2) * u / units, 0, fz - GD + 0.08), H, 0.16, rail_c)
	# Flats: a door and a window on the gallery, a window and often an AC
	# unit on the back; clothes over the rail.
	var ac := _g(Color(0.8, 0.8, 0.76), MeshBuilder.METAL)
	for f in floors:
		var y := f * FH
		for u in units:
			var x := bx - bl * 0.5 + uw * (u + 0.5)
			mb.box(Vector3(x - uw * 0.22, y + 1.05, fz - 0.04), Vector3(0.9, 2.05, 0.08), Kit._worn(Kit._pick(Shady.DOORS, rng), t))
			var st := (1 if rng.randf() < bars else Shady._pick_state([0.8, 0.0, 0.12, 0.08, 0.0], rng)) if f == 0 else Shady._pick_state(weights, rng)
			Shady._win(mb, Vector3(x + uw * 0.2, y + 1.6, fz), Vector3.RIGHT, Vector3.FORWARD, Vector2(1.2, 1.1), st, rng, 0.35)
			var sb := (1 if rng.randf() < bars else 0) if f == 0 else Shady._pick_state(weights, rng)
			Shady._win(mb, Vector3(x, y + 1.6, bz), Vector3.RIGHT, Vector3.BACK, Vector2(1.3, 1.1), sb, rng, 0.35)
			if sb == 0 and rng.randf() < 0.45:
				mb.box(Vector3(x, y + 1.25, bz + 0.22), Vector3(0.65, 0.42, 0.44), ac)
			if f > 0 and rng.randf() < 0.3:
				mb.box(Vector3(x + rng.randf_range(-1.0, 1.0), y + 0.78, fz - GD - 0.0), Vector3(rng.randf_range(0.6, 1.2), 0.55, 0.03), Kit._pick(Shady.CLOTHES, rng))
	# Water streaks down the front under the roof edge.
	for k in 3 + (3 if t == 0 else 0):
		mb.box(Vector3(bx + rng.randf_range(-bl * 0.45, bl * 0.45), H - 1.2, bz + 0.04), Vector3(0.5, 2.2, 0.02), paint.darkened(0.3))
	# Open steel switchback stair at the yard end of the gallery.
	var sx := bx + side * (bl * 0.5 + 1.5)
	var sz0 := fz - GD + 0.1
	var sz1 := fz + 2.6
	var steel := _g(rail_c.darkened(0.15), MeshBuilder.METAL)
	for k in 4:
		var px := sx + (1.25 if k % 2 == 0 else -1.25)
		var pz := sz0 + 0.1 if k < 2 else sz1 - 0.1
		mb.box(Vector3(px, H * 0.5, pz), Vector3(0.12, H, 0.12), steel)
	for f in floors - 1:
		var y0 := f * FH
		var ym := y0 + FH * 0.5
		var xo := sx + side * 0.62
		var xi := sx - side * 0.62
		Kit._beam(mb, Vector3(xo, y0 + 0.1, sz0 + 0.4), Vector3(xo, ym, sz1 - 0.9), 0.14, steel, 1.1)
		Kit._beam(mb, Vector3(xi, ym, sz1 - 0.9), Vector3(xi, y0 + FH, sz0 + 0.4), 0.14, steel, 1.1)
		mb.box(Vector3(sx, ym, sz1 - 0.45), Vector3(2.5, 0.12, 0.9), steel)
		Kit._beam(mb, Vector3(xo + side * 0.55, y0 + 1.0, sz0 + 0.4), Vector3(xo + side * 0.55, ym + 1.0, sz1 - 0.9), 0.05, rail_c)
	Kit._col(out, Vector3(sx, H * 0.5, (sz0 + sz1) * 0.5), Vector3(2.6, H, sz1 - sz0))
	# Laundry lines in the side yard past the stair.
	var yu0 := absf(sx) + 1.6
	var yu1 := w * 0.5 - 0.9
	if yu1 - yu0 >= 1.2:
		var lx := side * (yu0 + yu1) * 0.5
		Shady._laundry(mb, out, Vector3(lx, 0, fz + 0.4), Vector3(lx, 0, bz - 0.4), rng)
	# Parking: stalls nose-in to the gallery, the drive at the far end.
	var gu := w * 0.5 - 3.4  # the drive gate, at -side
	var gate_x := -side * gu
	var front := -d * 0.5 + 0.6
	Kit._route_out(mb, gate_x - 2.2, gate_x + 2.2, d, _g(Shady.ASPHALT, MeshBuilder.ASPHALT))
	var stall_d := minf(5.0, kerb - front - 2.0)
	var u0 := -gu + 3.0
	var u1 := w * 0.5 - 3.2
	var n := clampi(int((u1 - u0) / 2.6), 0, 8)
	var shell_at := rng.randi() % maxi(1, n) if t == 0 else -1
	var cars := 0
	if stall_d >= 4.4 and n > 0:
		var xs := minf(side * u0, side * (u0 + n * 2.6))
		Kit._stalls(mb, xs, kerb, n, 2.6, stall_d, -1.0)
		for i in n:
			var p := Vector3(xs + 1.3 + i * 2.6, 0, kerb - 2.3)
			if i == shell_at:
				Shady._shell(mb, out, p, PI + rng.randf_range(-0.15, 0.15), rng)
				Shady._tyres(mb, out, p + Vector3(1.6 if i < n - 1 else -1.6, 0, -1.6), 3)
			elif cars < 4 and rng.randf() < (0.3 if t == 0 else 0.5):
				Kit._wealth_car(mb, out, p, PI, t, rng)
				cars += 1
	Shady._dumpster(mb, out, Vector3(side * (w * 0.5 - 1.5), 0, kerb - 1.2), PI * 0.5, rng)
	# Chain-link: the front with the drive gap (and at T0 a torn bay), the
	# sides and back.
	var fzc := -d * 0.5 + 0.4
	var g0 := gate_x - 2.5
	var g1 := gate_x + 2.5
	var lo := -w * 0.5 + 0.3
	var hi := w * 0.5 - 0.3
	Shady._chainlink(mb, out, Vector3(lo, 0, fzc), Vector3(g0, 0, fzc), 1.8, rng, false, t == 0 and side < 0.0, 1)
	Shady._chainlink(mb, out, Vector3(g1, 0, fzc), Vector3(hi, 0, fzc), 1.8, rng, false, t == 0 and side > 0.0, 1)
	Kit._lot_fence(mb, out, w, d, "chain", Color(0.62, 0.64, 0.66), [], false, 0.4)
	# T0: the dumped couch or mattress, bags, a tag on the end wall.
	if t == 0:
		var jp := Vector3(side * (w * 0.5 - 2.0), 0, kerb - 3.6)
		if rng.randf() < 0.5:
			Shady._couch(mb, jp, PI * 0.5 * side, Kit._worn(Kit._pick(Shady.FADED, rng), 0))
		else:
			Shady._mattress(mb, jp, rng.randf_range(-0.4, 0.4), rng)
		Shady._bags(mb, Vector3(side * (w * 0.5 - 1.5), 0, kerb - 2.5), 4, rng)
		var ex := bx - side * (bl * 0.5 + 0.03)
		Shady._tag(mb, Vector3(ex, 1.7, cz), Vector3(0, 0, 1), Vector3(-side, 0, 0), minf(bd - 1.5, 4.0), 1.6, rng)
	else:
		Shady._bags(mb, Vector3(side * (w * 0.5 - 1.5), 0, kerb - 2.4), 2, rng)


# --- exec_house -----------------------------------------------------------------

## A T4 executive house: a two-storey hip-roofed main block with a
## double-height portico and lamps at the door, a three-car garage wing (two
## on a narrow lot) behind a wide concrete drive with the luxury cars, a
## pool deck behind (a patio when the yard is short). T4 hedges the lot
## with lit piers at the drive; T5 walls it, piers lit the same.
static func exec_house(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var t := Kit._wealth(4, 5, 4)
	var side := Kit._clear_side(-1.0 if rng.randf() < 0.5 else 1.0)  # the garage's side
	const H := 6.4
	var bw := clampf(w * 0.5, 8.0, 13.0)
	var bd := clampf(d * 0.42, 7.0, 10.0)
	var gw := clampf(w - 2.4 - bw, 6.0, 9.6)
	var gd := minf(7.0, bd)
	var total := bw + gw
	var fz := -d * 0.5 + clampf(d * 0.3, 5.5, 7.5)
	var bz := fz + bd
	var mx := -side * (total * 0.5 - bw * 0.5)
	var gx := side * (total * 0.5 - gw * 0.5)
	var body: Color = Kit._pick([STUCCO, Color(0.9, 0.86, 0.78), Color(0.85, 0.82, 0.76), Color(0.94, 0.92, 0.9)], rng)
	var roof: Color = Kit._pick([Kit.TERRACOTTA, Color(0.3, 0.32, 0.36), Color(0.45, 0.4, 0.36)], rng)
	var trim := Kit.TRIM
	var drive := _g(Kit.CONCRETE.lightened(0.05), MeshBuilder.CONCRETE)
	var paving := _g(Color(0.88, 0.84, 0.76), MeshBuilder.PAVING)
	Kit._pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, Civic._grass())
	# Main block and garage wing.
	Kit._solid(mb, out, Vector3(mx, H * 0.5, fz + bd * 0.5), Vector3(bw, H, bd), body)
	mb.box(Vector3(mx, 3.2, fz + bd * 0.5), Vector3(bw + 0.12, 0.18, bd + 0.12), trim)
	Kit._hip(mb, Vector3(mx, H, fz + bd * 0.5), bw + 1.0, bd + 1.0, clampf(minf(bw, bd) * 0.24, 1.6, 2.6), roof)
	mb.box(Vector3(mx, H - 0.05, fz + bd * 0.5), Vector3(bw + 1.0, 0.15, bd + 1.0), trim)
	const GH := 3.4
	Kit._solid(mb, out, Vector3(gx, GH * 0.5, fz + 0.4 + gd * 0.5), Vector3(gw, GH, gd), body)
	Kit._hip(mb, Vector3(gx, GH, fz + 0.4 + gd * 0.5), gw + 0.8, gd + 0.8, 1.3, roof)
	mb.box(Vector3(gx, GH - 0.05, fz + 0.4 + gd * 0.5), Vector3(gw + 0.8, 0.15, gd + 0.8), trim)
	var nb := 3 if gw >= 8.4 else 2
	var bay := (gw - 0.6) / nb
	for i in nb:
		var x := gx - gw * 0.5 + 0.3 + bay * (i + 0.5)
		mb.box(Vector3(x, 1.2, fz + 0.36), Vector3(bay - 0.5, 2.3, 0.08), _g(Kit.WHITE, MeshBuilder.SIDING))
		mb.box(Vector3(x, 2.5, fz + 0.3), Vector3(0.3, 0.2, 0.12), Skyline._lamp())
	# Windows, the door and its double-height portico with lamps.
	Kit._all_windows(mb, mx - bw * 0.5, mx + bw * 0.5, fz, bz, 0.2, 2, 3.2, 2.8, Vector2(1.3, 1.6), rng, 0.5)
	var dx := mx + side * bw * 0.15
	mb.box(Vector3(dx, 1.45, fz - 0.06), Vector3(1.8, 2.7, 0.08), _g(Color(0.24, 0.16, 0.1), MeshBuilder.GLOSS))
	mb.box(Vector3(dx, 3.6, fz - 0.06), Vector3(1.8, 1.0, 0.08), _g(WARM_LIT, MeshBuilder.GLOW_WINDOW))
	for s: float in [-1.0, 1.0]:
		var cp := Vector3(dx + s * 1.7, 0, fz - 2.2)
		mb.cylinder(cp, 0.22, H - 0.5, trim, 8)
		Kit._col(out, cp + Vector3(0, (H - 0.5) * 0.5, 0), Vector3(0.45, H - 0.5, 0.45))
		mb.ball(Vector3(dx + s * 1.25, 2.2, fz - 0.15), Vector3(0.14, 0.2, 0.14), Skyline._lamp(Color(1.0, 0.9, 0.6)), 6, 3)
	mb.box(Vector3(dx, H - 0.2, fz - 1.25), Vector3(4.2, 0.4, 2.6), trim)
	Kit._pad(mb, dx - 2.2, dx + 2.2, fz - 2.6, fz, paving, 0.08)
	# Drive, the cars on it, the walk to the portico.
	var dz0 := -d * 0.5
	Kit._pad(mb, gx - gw * 0.5 + 0.2, gx + gw * 0.5 - 0.2, dz0, fz + 0.4, drive, 0.04)
	Kit._route_out(mb, gx - gw * 0.5 + 0.4, gx + gw * 0.5 - 0.4, d, drive)
	Kit._pad(mb, minf(dx, gx), maxf(dx, gx), fz - 2.0, fz - 0.8, paving, 0.05)
	var car_z := maxf(fz - 3.0, -d * 0.5 + 0.3 + 2.45)
	for i in nb:
		if i == 0 or rng.randf() < 0.5:
			Kit._wealth_car(mb, out, Vector3(gx - gw * 0.5 + 0.3 + bay * (i + 0.5), 0, car_z), 0.0, t, rng)
	# Planting along the front, a palm on the open corner.
	for k in 4:
		Kit._bush(mb, Vector3(lerpf(mx - bw * 0.5 + 0.6, dx - side * 2.4, k / 3.0), 0, fz - 0.6), 0.6, rng)
	Props.palm(mb, out, Vector3(-side * (w * 0.5 - 2.6), 0, -d * 0.5 + 2.6), rng)
	# Behind: a pool deck with loungers, or a patio.
	var room := d * 0.5 - bz
	if room >= 5.0:
		var px0 := mx - minf(bw, 10.0) * 0.5
		var px1 := mx + minf(bw, 10.0) * 0.5
		var pz1 := d * 0.5 - 1.2
		Kit._pad(mb, px0, px1, bz, pz1, paving, 0.05)
		mb.box(Vector3(mx, 0.08, (bz + pz1) * 0.5 + 0.3), Vector3(px1 - px0 - 3.0, 0.04, pz1 - bz - 2.2), Kit.POOL)
		for k in 2:
			_lounger(mb, Vector3(px0 + 0.7, 0.05, bz + 2.0 + k * 1.6), Kit.WHITE)
	elif room >= 3.0:
		Kit._pad(mb, mx - 3.0, mx + 3.0, bz, bz + 2.6, paving, 0.05)
		Props.cafe_table(mb, out, Vector3(mx, 0, bz + 1.4), Kit._pick(Buildings.PARASOLS, rng))
	# Privacy: a hedge (T4) or a rendered wall (T5) all round, lit piers at
	# the drive.
	var gate := [[gx, gw + (1.2 if t <= 4 else 0.4)]]
	if t >= 5:
		Kit._lot_fence(mb, out, w, d, "wall", STUCCO, gate, true, 1.2, false)
	else:
		Kit._lot_fence(mb, out, w, d, "hedge", Kit.LEAF, gate, true, 1.2, false)
	_lit_piers(mb, out, gx, -d * 0.5 + 1.2, gw + (0.4 if t <= 4 else -0.4))


# --- gatehouse ------------------------------------------------------------------

## An estate gatehouse: a drive lane through the lot with a stop line and a
## speed bump, a kerbed island with the boom barrier's post (it collides)
## and its striped arm across the lane (it does not, so a car is never
## locked out of an estate), a small glazed guard hut lit at night under an
## overhanging roof, lit stone piers at the lane mouth, a wall wing along
## the far side and a CCTV pole.
static func gatehouse(mb, out: Array, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var stone := Civic._stone(Color(0.8, 0.76, 0.68))
	var asphalt := _g(Kit.ASPHALT, MeshBuilder.ASPHALT)
	var lw := clampf(w * 0.52, 3.6, 5.2)
	var x0 := -w * 0.5 + 0.9
	var x1 := x0 + lw
	var lc := (x0 + x1) * 0.5
	var il0 := x1
	var il1 := x1 + 0.8
	var hs := clampf(w - lw - 2.4, 1.8, 3.2)
	var hx := il1 + 0.2 + hs * 0.5
	var hz := 0.0
	Kit._pad(mb, -w * 0.5, w * 0.5, -d * 0.5, d * 0.5, Civic._grass())
	# The lane, its markings, the bump.
	Kit._pad(mb, x0, x1, -d * 0.5, d * 0.5, asphalt, 0.04)
	Kit._route_out(mb, x0 + 0.2, x1 - 0.2, d, asphalt)
	Kit._line(mb, Vector3(x0 + 0.2, 0, -1.6), Vector3(x1 - 0.2, 0, -1.6), 0.35)
	mb.box(Vector3(lc, 0.06, -d * 0.5 + 1.6), Vector3(lw - 0.4, 0.08, 0.6), _g(Color(0.2, 0.2, 0.22), MeshBuilder.ASPHALT))
	for k in 3:
		mb.box(Vector3(lerpf(x0 + 0.8, x1 - 0.8, k / 2.0), 0.105, -d * 0.5 + 1.6), Vector3(0.35, 0.01, 0.6), HAZARD)
	# Island kerb, the boom post and arm, the CCTV pole.
	mb.box(Vector3((il0 + il1) * 0.5, 0.08, 0.0), Vector3(il1 - il0, 0.16, d - 1.2), _g(Kit.CONCRETE, MeshBuilder.CONCRETE))
	var bp := Vector3((il0 + il1) * 0.5, 0, -0.6)
	Kit._solid(mb, out, bp + Vector3(0, 0.6, 0), Vector3(0.45, 1.2, 0.45), _g(Color(0.85, 0.85, 0.82), MeshBuilder.METAL))
	mb.box(bp + Vector3(0, 1.28, 0), Vector3(0.5, 0.16, 0.5), HAZARD)
	var arm := lw - 0.3
	var segs := 6
	for k in segs:
		var ax := bp.x - 0.3 - arm * (k + 0.5) / segs
		mb.box(Vector3(ax, 1.05, bp.z), Vector3(arm / segs, 0.12, 0.12), Color(0.85, 0.12, 0.1) if k % 2 == 0 else Kit.WHITE)
	mb.box(Vector3(bp.x - 0.3 - arm + 0.06, 0.5, bp.z), Vector3(0.06, 1.0, 0.06), Kit.STEEL)
	var pole := Vector3((il0 + il1) * 0.5, 0, 1.4)
	mb.cylinder(pole, 0.08, 4.2, Kit.STEEL, 6)
	Kit._col(out, pole + Vector3(0, 1.0, 0), Vector3(0.25, 2.0, 0.25))
	mb.box(pole + Vector3(-0.3, 4.0, -0.1), Vector3(0.5, 0.2, 0.22), Kit.WHITE)
	mb.box(pole + Vector3(-0.56, 4.0, -0.1), Vector3(0.04, 0.12, 0.14), Kit.DARK)
	# Guard hut: glazed on all sides, lit, a door at the back, an
	# overhanging flat roof with a lit fascia.
	const HH := 2.8
	var hd := hs * 0.9
	Kit._solid(mb, out, Vector3(hx, HH * 0.5, hz), Vector3(hs, HH, hd), stone)
	var lit := _g(WARM_LIT, MeshBuilder.GLOW_WINDOW)
	mb.box(Vector3(hx, 1.75, hz - hd * 0.5 - 0.04), Vector3(hs - 0.5, 1.3, 0.08), lit)
	mb.box(Vector3(hx - hs * 0.5 - 0.04, 1.75, hz), Vector3(0.08, 1.3, hd - 0.5), lit)
	mb.box(Vector3(hx + hs * 0.5 + 0.04, 1.75, hz - hd * 0.15), Vector3(0.08, 1.3, hd * 0.5), lit)
	mb.box(Vector3(hx, 1.05, hz + hd * 0.5 + 0.04), Vector3(0.9, 2.1, 0.08), _g(Color(0.3, 0.3, 0.32), MeshBuilder.METAL))
	mb.box(Vector3(hx, HH + 0.15, hz), Vector3(hs + 1.2, 0.3, hd + 1.2), Kit.TRIM)
	mb.box(Vector3(hx, HH - 0.02, hz - hd * 0.5 - 0.6), Vector3(hs + 1.2, 0.04, 0.04), Skyline._lamp())
	mb.box(Vector3(hx, HH - 0.02, hz), Vector3(0.6, 0.03, 0.6), Skyline._lamp())
	# Lit piers at the lane mouth, a wall wing down the far side.
	var pz := -d * 0.5 + 0.6
	for px: float in [x0 - 0.4, il1 - 0.3]:
		Kit._solid(mb, out, Vector3(px, 1.1, pz), Vector3(0.7, 2.2, 0.7), stone)
		mb.box(Vector3(px, 2.26, pz), Vector3(0.86, 0.12, 0.86), Kit.TRIM)
		mb.ball(Vector3(px, 2.55, pz), Vector3(0.22, 0.22, 0.22), Skyline._lamp(Color(1.0, 0.9, 0.6)), 6, 3)
	Kit._solid(mb, out, Vector3(x0 - 0.4, 0.7, (pz + 0.35 + d * 0.5 - 0.3) * 0.5), Vector3(0.4, 1.4, d * 0.5 - 0.3 - pz - 0.35), stone)
	mb.box(Vector3(x0 - 0.4, 1.45, (pz + 0.35 + d * 0.5 - 0.3) * 0.5), Vector3(0.5, 0.1, d * 0.5 - 0.3 - pz - 0.35), Kit.TRIM)
	for k in 3:
		Kit._bush(mb, Vector3(minf(hx + hs * 0.5 + 0.3, w * 0.5 - 0.6) - k * 0.9, 0, d * 0.5 - 0.9), 0.45, rng)
