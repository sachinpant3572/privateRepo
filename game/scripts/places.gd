extends RefCounted
## Places the player can walk into: corner stores and diners now, more
## types in later phases (INTERIORS_SERVICES_PLAN.md). The list is plain
## data, made once when the city is built: it walks the same front-row
## parcels the cell builder would (city_cells._land_block) and picks some
## with its own random stream, so the cells' layout rolls don't change. The
## cell builder then puts a storefront on each picked parcel; the interior
## manager (interiors.gd) opens the doors.

const StreetPlan = preload("res://scripts/street_plan.gd")
const Cells = preload("res://scripts/city_cells.gd")
const Terrain = preload("res://scripts/terrain.gd")

## Per type: label, the storefront's width and depth, opening hours (24
## means midnight) and shop names. Map icons are in map_image.gd.
const TYPES := {
	"corner_store": {
		"label": "Corner store", "size": Vector2(10.0, 12.0),
		"hours": [0, 24],
		"names": ["Dumaine Mart", "Lucky 7 Grocery", "Corner Pantry", "Crescent Grocery", "Levee Mart",
			"Joe's Market", "Quik Stop", "Bayou Mart", "Sunrise Grocery", "Night Owl Mart",
			"Palm Mart", "Gulf Pantry", "Sandpiper Market", "Two Oaks Grocery", "Shoreline Market",
			"Heights Grocery", "Corner Cupboard", "Pelican Pantry"],
	},
	"diner": {
		"label": "Diner", "size": Vector2(14.0, 13.0),
		"hours": [6, 24],
		"names": ["Rosie's Diner", "Blue Plate", "Starlite Diner", "Levee Diner", "Morning Call",
			"Ruby's", "The Griddle", "Dixie Diner", "Pelican Grill", "Shore Diner", "Hilltop Grill",
			"Cypress Cafe", "Sunset Diner", "The Skillet"],
	},
}
## How many of each type every district gets (district ids from the world
## map). Fewer when a district runs out of room. Ironwharf is mostly quay
## yards: some seeds leave it only two or three blocks that can take a shop.
const MIX := {
	"gilt_district": {"corner_store": 2, "diner": 2},
	"lantern_quarter": {"corner_store": 2},
	"floodline_wards": {"corner_store": 2},
	"ironwharf": {"corner_store": 2, "diner": 1},
	"morrow_point": {"corner_store": 2, "diner": 2},
}
## Places of the same type stand at least this far apart, any two places
## at least MIN_GAP.
const SPACING := 110.0
const MIN_GAP := 40.0
## The door point: this far out from the shop's front, on the sidewalk.
const DOOR_OUT := 1.2
## Suburb places (country lots round the city, HANDOFF-bellerive-expand
## BX-3): the country kinds that open as a place, and the zones they may
## stand in. At most SUBURB_MAX of them, spaced as in the city.
const SUBURB_TYPES := {"diner": "diner", "general_store": "corner_store", "shopfront": "corner_store", "strip_mall": "corner_store"}
const SUBURB_ZONES := ["heights", "bayou_town", "fringe", "eastside", "beach_town", "shore"]
const SUBURB_MAX := 16


## [{id, type, name, district, district_name, face, parcel, rect, door,
## yaw, seed, hours}]. `rect` is the shop's footprint in block f's front
## frame (x along the street, y out through it); `parcel` indexes
## front_parcels(); `door` is on the sidewalk in front of the shop and
## `yaw` faces into it.
static func build(city) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([city.seed_value, "places"])
	var candidates := {} # district id -> [[face, parcel index, Rect2]]
	for f in city.plan.faces.size():
		if not _eligible(city, f):
			continue
		var district: String = city.district_at(city.block_center(f)).get("id", "")
		if not MIX.has(district):
			continue
		var rect: Rect2 = city.plan.lot_rect(f)
		var ff: Transform2D = city.plan.front_frame2d(f)
		var parcels := front_parcels(city, f)
		for k in parcels.size():
			var p: Array = parcels[k]
			var r: Rect2 = p[0]
			if p[1] or r.end.y < rect.end.y - 0.5:
				continue
			if not city.plan.in_city(ff * Vector2(r.get_center().x, r.end.y + DOOR_OUT)):
				continue
			if not candidates.has(district):
				candidates[district] = []
			candidates[district].append([f, k, p[0]])
	var places: Array = []
	var used_names := {}
	var used_faces := {}
	var districts: Array = MIX.keys()
	districts.sort()
	for district in districts:
		# Bigger shops first: they fit fewer blocks.
		var types: Array = MIX[district].keys()
		types.sort_custom(func(a, b): return TYPES[a].size.x * TYPES[a].size.y > TYPES[b].size.x * TYPES[b].size.y)
		for type in types:
			for n in MIX[district][type]:
				var pick = _pick(city, candidates.get(district, []), type, places, used_faces, rng)
				# A district short of blocks (Ironwharf's yards and
				# landmarks) gets each type once on another parcel of a
				# block that already has a place, door MIN_GAP from it.
				if pick == null and n == 0:
					pick = _pick_shared(city, candidates.get(district, []), type, places)
				if pick == null:
					break
				var place := _make(city, pick, type, district, rng, used_names)
				place["id"] = "%s_%d" % [type, places.size()]
				used_faces[pick[0]] = true
				places.append(place)
	return places


## Places on the suburbs' country lots: diners, general stores, shopfronts
## and strip malls in SUBURB_ZONES, appended after the city's (`places`
## holds those; names stay unique across both). These have no block:
## face and parcel are -1, rect is empty. The door is in front of the kit
## building's door (suburb_door) and `yaw` faces into it.
static func build_suburbs(city, places: Array) -> Array:
	var c = city.country
	if c == null:
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([city.seed_value, "suburb places"])
	var picks: Array = []
	for i in c.lots.size():
		var l: Array = c.lots[i]
		var kind: String = c.kinds[int(l[5])]
		if SUBURB_TYPES.has(kind) and str(l[7]) in SUBURB_ZONES:
			picks.append(i)
	# Shuffle with the seeded stream so the spread doesn't follow lot order.
	for k in range(picks.size() - 1, 0, -1):
		var j := rng.randi() % (k + 1)
		var t = picks[k]
		picks[k] = picks[j]
		picks[j] = t
	var used_names := {}
	for p in places:
		used_names[p.name] = true
	var out: Array = []
	for i in picks:
		if out.size() >= SUBURB_MAX:
			break
		var l: Array = c.lots[i]
		var type: String = SUBURB_TYPES[c.kinds[int(l[5])]]
		var xf := Transform3D(Basis(Vector3.UP, float(l[2])), Vector3(l[0], 0.0, l[1]))
		var d2 := suburb_door(c.kinds[int(l[5])], float(l[3]), float(l[4]))
		var door := xf * Vector3(d2.x, 0.0, d2.y)
		door.y = Terrain.height(float(l[0]), float(l[1]))
		var clash := false
		for q in places + out:
			var gap: float = Vector2(q.door.x, q.door.z).distance_to(Vector2(door.x, door.z))
			if gap < MIN_GAP or (q.type == type and gap < SPACING):
				clash = true
				break
		if clash:
			continue
		var names: Array = TYPES[type].names
		var name: String = names[rng.randi() % names.size()]
		for k in names.size():
			var candidate: String = names[(names.find(name) + k) % names.size()]
			if not used_names.has(candidate):
				name = candidate
				break
		used_names[name] = true
		# The lot's front is -z: the door faces +z, into the building.
		var inward := xf.basis * Vector3(0, 0, 1)
		var d: Dictionary = city.district_at(door)
		out.append({
			"id": "%s_%d" % [type, places.size() + out.size()], "type": type, "name": name,
			"district": d.get("id", ""), "district_name": d.get("name", ""),
			"face": -1, "parcel": -1, "rect": Rect2(), "lot": i, "door": door,
			"yaw": atan2(-inward.x, -inward.z), "seed": rng.randi(), "hours": TYPES[type].hours,
		})
	return out


## Where a country shop kind's door is, in its lot frame (x across, y back
## from the lot centre; the road is at -d/2): DOOR_OUT in front of the
## front. Mirrors the fronts in country_kit.gd (diner, general_store,
## shopfront, strip_mall: the middle unit).
static func suburb_door(kind: String, w: float, d: float) -> Vector2:
	var fz := 0.0
	var x := 0.0
	match kind:
		"diner":
			# The facade, less the vestibule in front of it (1.6 m).
			fz = d * 0.5 - 1.0 - 3.0 - clampf(d * 0.26, 5.0, 8.0) - 1.6
		"general_store":
			fz = -d * 0.5 + 3.2
		"shopfront":
			fz = -d * 0.5 + 1.6
		"strip_mall":
			fz = d * 0.5 - 1.0 - clampf(d * 0.32, 9.0, 18.0)
			var bl := w - 4.0
			var n := clampi(int(bl / 9.0), 3, 8)
			x = -bl * 0.5 + bl / n * (floori(n * 0.5) + 0.5)
	return Vector2(x, fz - DOOR_OUT)


## Block f can hold a place: playable land with a front lot on the
## sidewalk, not the park, a set piece, a landmark or a docks yard on the
## quay.
static func _eligible(city, f: int) -> bool:
	if not city.in_window(f) or not city.plan.is_land(f) or city.plan.is_park(f):
		return false
	# Set pieces (the Esplanade, Founders Circle, the squares) are lawns.
	if city.plan.set_piece(f) != "":
		return false
	if not city.landmark_at(f).is_empty():
		return false
	var lot: PackedVector2Array = city.plan.lot(f)
	var rect: Rect2 = city.plan.lot_rect(f)
	if lot.size() < 3 or rect.size.x < 9.0 or rect.size.y < 9.0:
		return false
	# The lot's front edge has to be the sidewalk's back edge.
	if rect.end.y < -StreetPlan.SIDEWALK - 1.5:
		return false
	return not (city.district_style(f) == "docks" and Cells.docks_frame(city.plan, f) != null)


## The parcels city_cells._land_block splits block f into (no landmark,
## not a docks yard): [[Rect2, flipped]] in the front frame.
static func front_parcels(city, f: int) -> Array:
	var rect: Rect2 = city.plan.lot_rect(f)
	var style: String = city.district_style(f)
	return Cells.split(rect, Cells.PARCEL_MAX.get(style, Cells.PARCEL_DEFAULT))


static func _pick(city, list: Array, type: String, places: Array, used_faces: Dictionary, rng: RandomNumberGenerator):
	var need: Vector2 = TYPES[type].size
	for spacing in [SPACING, SPACING * 0.5]:
		var ok: Array = []
		for c in list:
			var r: Rect2 = c[2]
			if used_faces.has(c[0]) or r.size.x < need.x + 1.0 or r.size.y < need.y + 2.0:
				continue
			var at: Vector3 = city.block_center(c[0])
			var clear := true
			for p in places:
				var d: float = (p.door as Vector3).distance_to(at)
				if d < MIN_GAP or (p.type == type and d < spacing):
					clear = false
					break
			if clear:
				ok.append(c)
		if not ok.is_empty():
			return ok[rng.randi() % ok.size()]
	return null


## The first candidate on a block that already has a place whose door
## is MIN_GAP from every place's door and that fits `type`, or null.
static func _pick_shared(city, list: Array, type: String, places: Array):
	var need: Vector2 = TYPES[type].size
	for c in list:
		var r: Rect2 = c[2]
		if r.size.x < need.x + 1.0 or r.size.y < need.y + 2.0:
			continue
		if places.any(func(p): return p.face == c[0] and p.parcel == c[1]):
			continue
		var door2: Vector2 = city.plan.front_frame2d(c[0]) * Vector2(r.get_center().x, r.end.y + DOOR_OUT)
		if places.all(func(p): return Vector2(p.door.x, p.door.z).distance_to(door2) >= MIN_GAP):
			return c
	return null


static func _make(city, pick: Array, type: String, district: String, rng: RandomNumberGenerator, used_names: Dictionary) -> Dictionary:
	var f: int = pick[0]
	var r: Rect2 = pick[2]
	var info: Dictionary = TYPES[type]
	var size: Vector2 = info.size
	var cx := r.get_center().x
	var shop := Rect2(cx - size.x * 0.5, r.end.y - size.y, size.x, size.y)
	var ff: Transform2D = city.plan.front_frame2d(f)
	var door2 := ff * Vector2(cx, r.end.y + DOOR_OUT)
	var inward := -Vector3(ff.y.x, 0, ff.y.y)
	var names: Array = info.names
	var name: String = names[rng.randi() % names.size()]
	for k in names.size():
		var candidate: String = names[(names.find(name) + k) % names.size()]
		if not used_names.has(candidate):
			name = candidate
			break
	used_names[name] = true
	var d: Dictionary = city.district_at(city.block_center(f))
	return {
		"type": type, "name": name, "district": district, "district_name": d.get("name", ""),
		"face": f, "parcel": pick[1], "rect": shop, "door": Vector3(door2.x, 0.0, door2.y),
		"yaw": atan2(-inward.x, -inward.z), "seed": rng.randi(), "hours": info.hours,
	}


## Whether a place is open at `hour` (0-24).
static func is_open(place: Dictionary, hour: float) -> bool:
	var h: Array = place.hours
	return hour >= h[0] and hour < h[1]

