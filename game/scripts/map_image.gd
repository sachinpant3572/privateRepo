extends RefCounted
## Bakes the demo map into one texture for the minimap and the full map:
## water, district-tinted blocks inside their sidewalks, roads, streetcar
## lines and landmark lots. Built once at start (a scanline fill per block).
## The bake returns where pixel (0, 0) sits in local metres; one pixel per
## PX_M metres.

const PX_M := 1.0
const WATER := Color(0.27, 0.5, 0.62)
const ROAD := Color(0.36, 0.37, 0.4)
const SIDEWALK := Color(0.78, 0.76, 0.72)
const RAIL := Color(0.55, 0.32, 0.2)
const MEDIAN := Color(0.4, 0.62, 0.36)
const LANE := Color(0.7, 0.55, 0.45)
const OUTSIDE := Color(0.55, 0.56, 0.55)
const STYLE_COLORS := {
	"quarter": Color(0.93, 0.74, 0.6),
	"wards": Color(0.7, 0.82, 0.55),
	"downtown": Color(0.66, 0.72, 0.82),
	"midtown": Color(0.62, 0.66, 0.8),
	"brownstone": Color(0.78, 0.66, 0.58),
	"docks": Color(0.72, 0.66, 0.58),
	"heights": Color(0.8, 0.85, 0.7),
	"bayou": Color(0.5, 0.62, 0.45),
	"painted": Color(0.86, 0.72, 0.78),
	"chinatown": Color(0.9, 0.58, 0.52),
	"havana": Color(0.95, 0.8, 0.6),
	"beach": Color(0.6, 0.85, 0.82),
}
const LANDMARK_COLORS := {
	"park": Color(0.45, 0.72, 0.4),
	"green": Color(0.45, 0.72, 0.4),
	"esplanade": Color(0.45, 0.72, 0.4),
	"circle": Color(0.45, 0.72, 0.4),
	"square": Color(0.45, 0.72, 0.4),
	"government": Color(0.86, 0.84, 0.78),
	"court": Color(0.85, 0.5, 0.35),
	"police": Color(0.5, 0.6, 0.85),
	"hospital": Color(0.95, 0.95, 0.97),
	"legend": Color(0.4, 0.5, 0.42),
}


## Map icon for a landmark type: [letter, colour].
const ICONS := {
	"station": ["T", Color(0.35, 0.6, 0.4)],
	"tower": ["A", Color(0.9, 0.72, 0.25)],
	"police": ["P", Color(0.25, 0.4, 0.85)],
	"government": ["G", Color(0.55, 0.5, 0.75)],
	"plaza": ["L", Color(0.85, 0.3, 0.7)],
	"hospital": ["+", Color(0.85, 0.2, 0.2)],
	"park": ["*", Color(0.3, 0.6, 0.3)],
	"court": ["B", Color(0.9, 0.5, 0.2)],
	"club": ["C", Color(0.2, 0.35, 0.8)],
	"safehouse": ["H", Color(0.2, 0.65, 0.35)],
	"story": ["?", Color(0.75, 0.6, 0.15)],
	"boxing": ["F", Color(0.75, 0.2, 0.2)],
	"legend": ["!", Color(0.45, 0.35, 0.6)],
	"monument": ["M", Color(0.75, 0.6, 0.15)],
	"viewpoint": ["V", Color(0.35, 0.5, 0.7)],
	# Places (places.gd).
	"corner_store": ["S", Color(0.15, 0.6, 0.55)],
	"diner": ["D", Color(0.85, 0.3, 0.3)],
}


static func icon(type: String) -> Array:
	return ICONS.get(type, ["o", Color(0.5, 0.5, 0.5)])


## Draws a round map icon with a letter, centred at `at`.
static func draw_icon(ci: CanvasItem, at: Vector2, letter: String, color: Color, radius := 9.0) -> void:
	ci.draw_circle(at, radius + 1.5, Color(0.05, 0.05, 0.07))
	ci.draw_circle(at, radius, color)
	var font := ThemeDB.fallback_font
	var fs := int(radius * 1.4)
	var w := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	ci.draw_string(font, at + Vector2(-w * 0.5, fs * 0.36), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


## Arrow pointing along `dir` (screen space), for the player and blips.
static func draw_arrow(ci: CanvasItem, at: Vector2, dir: Vector2, size: float, color: Color) -> void:
	var f := dir.normalized() * size
	var r := Vector2(-f.y, f.x) * 0.65
	var pts := PackedVector2Array([at + f, at - f * 0.6 + r, at - f * 0.25, at - f * 0.6 - r])
	ci.draw_colored_polygon(pts, Color(0.05, 0.05, 0.07))
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(at + (p - at) * 0.72)
	ci.draw_colored_polygon(inner, color)


## Returns {texture, origin (local metres at pixel 0,0), size (pixels)}.
static func bake(city) -> Dictionary:
	var plan = city.plan
	var bounds: Rect2 = plan.bounds.grow(40.0)
	var size := Vector2i(ceili(bounds.size.x / PX_M), ceili(bounds.size.y / PX_M))
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	# Past a trimmed city's edge the bake is clear, so the state map (its
	# country, river and coast) shows through; the maps draw it underneath.
	img.fill(WATER if plan.outline.is_empty() else Color(WATER, 0.0))
	var origin := bounds.position
	for f in plan.faces.size():
		var inside: bool = city.in_window(f)
		var road := ROAD if inside else ROAD.lerp(OUTSIDE, 0.4)
		_poly(img, origin, plan.face_poly(f), road)
		if not plan.is_land(f):
			continue
		var style: String = city.block_style(f)
		var color: Color = STYLE_COLORS.get(city.district_style(f), STYLE_COLORS.quarter)
		color = LANDMARK_COLORS.get(style, color)
		var walk := SIDEWALK
		if not inside:
			color = color.lerp(OUTSIDE, 0.55)
			walk = SIDEWALK.lerp(OUTSIDE, 0.5)
		_poly(img, origin, plan.inner(f), walk)
		_poly(img, origin, plan.lot(f), color)
	for e in plan.edge_count():
		var cls: String = plan.edge_class(e)
		var a: Vector2 = plan.pos(plan.edge_a[e])
		var b: Vector2 = plan.pos(plan.edge_b[e])
		var dir := (b - a).normalized()
		var side := Vector2(-dir.y, dir.x)
		var w: float = plan.edge_width(e) * 0.5
		# Halves of streets with water beside them, and the bridge.
		var mid := (a + b) * 0.5
		for sgn in [-1.0, 1.0]:
			if plan.face_of(mid + side * sgn * (w + 2.5)) < 0:
				var s: Vector2 = side * sgn * (w + 1.0)
				_poly(img, origin, PackedVector2Array([a, b, b + s, a + s]), ROAD)
		# Neutral grounds on the boulevards, pavers on pedestrian lanes.
		if cls == "boulevard" or cls == "lane":
			var half := 3.0 if cls == "boulevard" else 3.5
			var trim := dir * minf(7.0, a.distance_to(b) * 0.3)
			_poly(img, origin, PackedVector2Array([a + trim - side * half, b - trim - side * half, b - trim + side * half, a + trim + side * half]), MEDIAN if cls == "boulevard" else LANE)
	for line in city.rail_lines:
		var nodes: PackedInt32Array = line.nodes
		for k in nodes.size() - 1:
			var a: Vector2 = plan.pos(nodes[k])
			var b: Vector2 = plan.pos(nodes[k + 1])
			var side := (b - a).normalized().orthogonal()
			_poly(img, origin, PackedVector2Array([a - side, b - side, b + side, a + side]), RAIL if not line.rusty else RAIL.darkened(0.3))
	var tex := ImageTexture.create_from_image(img)
	return {"texture": tex, "origin": origin, "size": Vector2(size)}


## Fills a polygon (metres, convex or not) row by row, even-odd, at
## `px_m` metres per pixel with pixel (0, 0) at `origin`.
static func fill_poly(img: Image, origin: Vector2, poly: PackedVector2Array, color: Color, px_m := PX_M) -> void:
	_poly(img, origin, poly, color, px_m)


static func _poly(img: Image, origin: Vector2, poly: PackedVector2Array, color: Color, px_m := PX_M) -> void:
	var n := poly.size()
	if n < 3:
		return
	var pts := PackedVector2Array()
	var y0 := INF
	var y1 := -INF
	for p in poly:
		var q := (p - origin) / px_m
		pts.append(q)
		y0 = minf(y0, q.y)
		y1 = maxf(y1, q.y)
	var h := img.get_height()
	var w := img.get_width()
	var xs := PackedFloat32Array()
	for y in range(maxi(0, floori(y0)), mini(h, ceili(y1))):
		var yc := y + 0.5
		xs.clear()
		for k in n:
			var a := pts[k]
			var b := pts[(k + 1) % n]
			if (a.y <= yc and b.y > yc) or (b.y <= yc and a.y > yc):
				xs.append(a.x + (yc - a.y) / (b.y - a.y) * (b.x - a.x))
		xs.sort()
		for i in range(0, xs.size() - 1, 2):
			var x0 := clampi(roundi(xs[i]), 0, w)
			var x1 := clampi(roundi(xs[i + 1]), 0, w)
			if x1 > x0:
				img.fill_rect(Rect2i(x0, y, x1 - x0, 1), color)
