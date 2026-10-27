extends RefCounted
## Bakes the whole state of Solvera (res://data/world_map.json) into one
## small texture for the full map and the minimap's edges: land by region
## type, lakes, rivers and the sea, highways, roads and rail, and the four
## cities with their districts. The playable city's own, much finer bake
## (map_image.gd) is drawn on top of it. Also hands out the labels the full
## map writes on it: cities, regions, towns and the places worth a pin.

const MapImage = preload("res://scripts/map_image.gd")

## Metres per pixel: 12 x 9 km makes 2000 x 1500.
const PX_M := 6.0
const LAND := Color(0.72, 0.78, 0.62)
const REGION_COLORS := {
	"desert": Color(0.86, 0.77, 0.58),
	"military": Color(0.66, 0.65, 0.57),
	"mountains": Color(0.62, 0.58, 0.53),
	"forest": Color(0.45, 0.6, 0.4),
	"lakeside": Color(0.62, 0.76, 0.52),
	"hills": Color(0.6, 0.75, 0.5),
	"farmland": Color(0.82, 0.8, 0.55),
	"bayou": Color(0.42, 0.55, 0.42),
	"island": Color(0.88, 0.83, 0.62),
	"rustbelt": Color(0.66, 0.65, 0.55),
	"parkland": Color(0.58, 0.76, 0.52),
}
const CITY := Color(0.8, 0.8, 0.78)
const HIGHWAY := Color(0.98, 0.94, 0.82)
const HIGHWAY_EDGE := Color(0.5, 0.45, 0.35)
const ROAD := Color(0.93, 0.89, 0.78)
const RAIL := Color(0.38, 0.3, 0.24)
## Unpaved: dirt tracks are dashed, trails dotted.
const TRACK := Color(0.55, 0.36, 0.18)
const TRAIL := Color(0.42, 0.25, 0.12)
const DISTRICT_COLORS := {
	"civic": Color(0.95, 0.94, 0.88), "park": Color(0.5, 0.72, 0.42), "strip": Color(0.85, 0.4, 0.6),
	"prairie": Color(0.72, 0.74, 0.55), "industrial": Color(0.6, 0.55, 0.5), "beach": Color(0.95, 0.86, 0.6),
}
## Landmark types that get a pin on the state view: [letter(s), colour].
const PINS := {
	"airport": ["AP", Color(0.2, 0.45, 0.75)],
	"military": ["X", Color(0.35, 0.37, 0.35)],
	"station": ["T", Color(0.35, 0.6, 0.4)],
	"monument": ["M", Color(0.75, 0.6, 0.15)],
	"dam": ["D", Color(0.2, 0.45, 0.65)],
	"bridge": ["B", Color(0.75, 0.25, 0.2)],
	"gas": ["G", Color(0.95, 0.6, 0.1)],
	"camp": ["C", Color(0.15, 0.6, 0.35)],
}
## Texture over each kind of land, so it reads as terrain: [spacing m, colour].
const TERRAIN := {
	"forest": [34.0, Color(0.34, 0.5, 0.3)],
	"mountains": [80.0, Color(0.48, 0.44, 0.4)],
	"desert": [55.0, Color(0.76, 0.66, 0.46)],
	"farmland": [240.0, Color(0.74, 0.72, 0.46)],
	"bayou": [60.0, Color(0.27, 0.5, 0.62)],
	"hills": [70.0, Color(0.5, 0.66, 0.42)],
	"lakeside": [60.0, Color(0.52, 0.67, 0.43)],
	"parkland": [60.0, Color(0.5, 0.68, 0.45)],
	"rustbelt": [70.0, Color(0.58, 0.57, 0.48)],
}


## {texture, origin (local metres at pixel 0,0), size (pixels), labels}.
## `map_origin` is the playable city's world origin (city.map_origin).
static func bake(map_origin: Vector2) -> Dictionary:
	var world: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world_map.json"))
	var world_size := Vector2(world.size[0], world.size[1])
	var px := Vector2i(ceili(world_size.x / PX_M), ceili(world_size.y / PX_M))
	var img := Image.create(px.x, px.y, false, Image.FORMAT_RGBA8)
	img.fill(LAND)
	var o := Vector2.ZERO # pixel (0, 0) in world metres
	var islands: Array = []
	for r in world.regions:
		if r.type == "island":
			islands.append(r)
		else:
			_fill(img, o, _poly(r.polygon), REGION_COLORS.get(r.type, LAND))
			_texture(img, _poly(r.polygon), r.type)
	for w in world.water:
		if w.has("polygon"):
			_fill(img, o, _poly(w.polygon), MapImage.WATER)
		else:
			_line(img, o, _poly(w.line), w.width, MapImage.WATER)
	for r in islands:
		_fill(img, o, _poly(r.polygon), REGION_COLORS.island)
	for c in world.cities:
		var rect := _rect(c.rect)
		_fill(img, o, _box(rect), CITY.lerp(LAND, 0.35))
		for d in c.districts:
			var col: Color = DISTRICT_COLORS.get(d.style, MapImage.STYLE_COLORS.get(d.style, CITY))
			_fill(img, o, _box(_rect(d.rect).grow(-12.0)), col.lerp(CITY, 0.3))
	for r in world.routes:
		match r.type:
			"highway":
				_line(img, o, _poly(r.line), 70.0, HIGHWAY_EDGE)
				_line(img, o, _poly(r.line), 42.0, HIGHWAY)
			"road":
				_line(img, o, _poly(r.line), 30.0, ROAD.darkened(0.15))
			"lane":
				_line(img, o, _poly(r.line), 22.0, ROAD.darkened(0.1))
			"track":
				_dashed(img, o, _poly(r.line), 14.0, TRACK, 70.0, 45.0)
			"trail":
				_dashed(img, o, _poly(r.line), 10.0, TRAIL, 20.0, 30.0)
			"rail":
				_line(img, o, _poly(r.line), 18.0, RAIL)
	var labels := {"cities": [], "regions": [], "towns": [], "pins": [], "water": [], "peaks": []}
	for c in world.cities:
		var rect := _rect(c.rect)
		labels.cities.append({"name": c.name, "note": "%s · %s" % [c.get("inspired_by", ""), c.get("condition", "")],
			"pos": _local(rect.get_center(), map_origin), "playable": c.has("demo_window")})
	for r in world.regions:
		if r.type != "island" or r.has("hook"):
			var at := Vector2(r.label_pos[0], r.label_pos[1]) if r.has("label_pos") else _centroid(_poly(r.polygon))
			labels.regions.append({"name": r.name, "pos": _local(at, map_origin)})
	for t in world.towns:
		labels.towns.append({"name": t.name, "kind": t.get("kind", "town"), "pos": _local(Vector2(t.pos[0], t.pos[1]), map_origin)})
	var playable := ""
	for c in world.cities:
		if c.has("demo_window"):
			playable = c.id
	for lm in world.landmarks:
		if lm.type == "peak":
			labels.peaks.append({"name": "%s  %d m" % [lm.name, int(lm.elev)], "pos": _local(Vector2(lm.pos[0], lm.pos[1]), map_origin)})
		# The playable city's planned places (phase above 1) stay off the map,
		# and so do the small bridges and fords where roads cross water.
		var planned: bool = lm.get("city", "") == playable and int(lm.get("phase", 1)) > 1
		if PINS.has(lm.type) and not planned and not lm.get("minor", false):
			labels.pins.append({"name": lm.name, "type": lm.type, "pos": _local(Vector2(lm.pos[0], lm.pos[1]), map_origin),
				"large": lm.get("size", "") == "large"})
	for w in world.water:
		if w.has("polygon") and w.type != "ocean":
			labels.water.append({"name": w.name, "pos": _local(_centroid(_poly(w.polygon)), map_origin)})
	labels.water.append({"name": "Gulf of Solvera", "pos": _local(Vector2(world_size.x * 0.3, world_size.y - 300.0), map_origin)})
	img.convert(Image.FORMAT_RGB8) # no alpha needed: a quarter less memory
	return {"texture": ImageTexture.create_from_image(img), "origin": -map_origin, "size": Vector2(px),
		"px_m": PX_M, "world_size": world_size, "labels": labels}


static func _local(p: Vector2, map_origin: Vector2) -> Vector3:
	return Vector3(p.x - map_origin.x, 0.0, p.y - map_origin.y)


static func _poly(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(Vector2(p[0], p[1]))
	return out


static func _rect(r: Array) -> Rect2:
	return Rect2(r[0], r[1], r[2], r[3])


static func _box(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


static func _centroid(poly: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for p in poly:
		sum += p
	return sum / poly.size()


static func _fill(img: Image, origin: Vector2, poly: PackedVector2Array, color: Color) -> void:
	MapImage.fill_poly(img, origin, poly, color, PX_M)


## A polyline `width` metres wide: a quad per segment and a square at each
## joint, enough at this scale.
static func _line(img: Image, origin: Vector2, line: PackedVector2Array, width: float, color: Color) -> void:
	var h := width * 0.5
	for k in line.size() - 1:
		var a := line[k]
		var b := line[k + 1]
		var side := (b - a).normalized().orthogonal() * h
		_fill(img, origin, PackedVector2Array([a - side, b - side, b + side, a + side]), color)
	for p in line:
		_fill(img, origin, _box(Rect2(p - Vector2(h, h), Vector2(width, width))), color)


## A dashed polyline: `dash` metres drawn, `gap` metres left, along its length.
static func _dashed(img: Image, origin: Vector2, line: PackedVector2Array, width: float, color: Color, dash: float, gap: float) -> void:
	var h := width * 0.5
	var phase := 0.0
	for k in line.size() - 1:
		var a := line[k]
		var b := line[k + 1]
		var length := a.distance_to(b)
		var dir := (b - a) / maxf(length, 0.001)
		var side := dir.orthogonal() * h
		var t := -phase
		while t < length:
			var t0 := maxf(t, 0.0)
			var t1 := minf(t + dash, length)
			if t1 > t0:
				var p := a + dir * t0
				var q := a + dir * t1
				_fill(img, origin, PackedVector2Array([p - side, q - side, q + side, p + side]), color)
			t += dash + gap
		phase = fmod(phase + length, dash + gap)


## Terrain texture inside `poly`: trees, ridges, specks of sand or swamp
## water, or field plots, on a jittered grid so it does not look ruled.
static func _texture(img: Image, poly: PackedVector2Array, type: String) -> void:
	if not TERRAIN.has(type):
		return
	var step: float = TERRAIN[type][0]
	var color: Color = TERRAIN[type][1]
	var box := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		box = box.expand(p)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(type)
	var limit := Rect2i(Vector2i.ZERO, img.get_size())
	var y := box.position.y + step * 0.5
	while y < box.end.y:
		var x := box.position.x + step * 0.5
		while x < box.end.x:
			var m := Vector2(x, y) + Vector2(rng.randf_range(-0.35, 0.35), rng.randf_range(-0.35, 0.35)) * step
			if type == "farmland":
				m = Vector2(x, y)
			if Geometry2D.is_point_in_polygon(m, poly):
				var c := Vector2i((m / PX_M).round())
				match type:
					"farmland":
						# A field: an inset square, light or dark by the dice.
						var half := Vector2(step * 0.42, step * 0.42)
						var corners_in := true
						for corner in [m - half, m + half, m + Vector2(half.x, -half.y), m + Vector2(-half.x, half.y)]:
							corners_in = corners_in and Geometry2D.is_point_in_polygon(corner, poly)
						if corners_in:
							var tint := color.lightened(0.15) if rng.randf() < 0.5 else color
							img.fill_rect(Rect2i(Vector2i(((m - half) / PX_M).round()), Vector2i((half * 2.0 / PX_M).round())).intersection(limit), tint)
					"mountains":
						# A small ridge: a chevron with a lit side.
						_px_line(img, c + Vector2i(-5, 4), c, color)
						_px_line(img, c, c + Vector2i(5, 4), color.lightened(0.35))
					_:
						var r := 1 if type in ["forest", "bayou"] else 0
						img.fill_rect(Rect2i(c - Vector2i(r, r), Vector2i(r * 2 + 1, r * 2 + 1)).intersection(limit), color)
			x += step
		y += step


static func _px_line(img: Image, a: Vector2i, b: Vector2i, color: Color) -> void:
	var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in n + 1:
		var q := Vector2i(Vector2(a).lerp(Vector2(b), float(i) / maxf(n, 1)).round())
		if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height():
			img.set_pixelv(q, color)
