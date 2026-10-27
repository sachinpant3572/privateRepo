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

## Per type: label, the storefront's width and depth, opening hours (24
## means midnight) and shop names. Map icons are in map_image.gd.
const TYPES := {
	"corner_store": {
		"label": "Corner store", "size": Vector2(10.0, 12.0),
		"hours": [0, 24],
		"names": ["Dumaine Mart", "Lucky 7 Grocery", "Corner Pantry", "Crescent Grocery", "Levee Mart",
			"Joe's Market", "Quik Stop", "Bayou Mart", "Sunrise Grocery", "Night Owl Mart"],
	},
	"diner": {
		"label": "Diner", "size": Vector2(14.0, 13.0),
		"hours": [6, 24],
		"names": ["Rosie's Diner", "Blue Plate", "Starlite Diner", "Levee Diner", "Morning Call",
			"Ruby's", "The Griddle", "Dixie Diner"],
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
## Doors stay this far inside the playable window.
const EDGE := 15.0


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
			if not (city.window as Rect2).grow(-EDGE).has_point(ff * Vector2(r.get_center().x, r.end.y + DOOR_OUT)):
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
				if pick == null:
					break
				var place := _make(city, pick, type, district, rng, used_names)
				place["id"] = "%s_%d" % [type, places.size()]
				used_faces[pick[0]] = true
				places.append(place)
	return places


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

