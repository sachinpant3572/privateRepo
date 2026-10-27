extends RefCounted
## Bakes the demo map into one texture for the minimap and the full map:
## water, district-tinted blocks inside their sidewalks, roads, streetcar
## lines and landmark lots. Built once at start (a few hundred fill_rects).
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
	"docks": Color(0.72, 0.66, 0.58),
	"heights": Color(0.8, 0.85, 0.7),
	"bayou": Color(0.5, 0.62, 0.45),
}
const LANDMARK_COLORS := {
	"park": Color(0.45, 0.72, 0.4),
	"green": Color(0.45, 0.72, 0.4),
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
	"hospital": ["+", Color(0.85, 0.2, 0.2)],
	"park": ["*", Color(0.3, 0.6, 0.3)],
	"court": ["B", Color(0.9, 0.5, 0.2)],
	"club": ["C", Color(0.2, 0.35, 0.8)],
	"safehouse": ["H", Color(0.2, 0.65, 0.35)],
	"story": ["?", Color(0.75, 0.6, 0.15)],
	"boxing": ["F", Color(0.75, 0.2, 0.2)],
	"legend": ["!", Color(0.45, 0.35, 0.6)],
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
	var margin: int = city.MARGIN
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for i in range(-margin, city.blocks.x + margin + 1):
		for j in range(-margin, city.blocks.y + margin + 1):
			var p: Vector2 = plan.pos(Vector2i(i, j))
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	lo -= Vector2(40, 40)
	hi += Vector2(40, 40)
	var size := Vector2i(ceili((hi.x - lo.x) / PX_M), ceili((hi.y - lo.y) / PX_M))
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(WATER)
	var origin := lo
	for i in range(-margin, city.blocks.x + margin):
		for j in range(-margin, city.blocks.y + margin):
			var b := Vector2i(i, j)
			var inside: bool = city.in_window(b)
			if not city.block_land(b):
				# Halves of streets running along the water.
				var c: PackedVector2Array = plan.corners(b)
				for k in 4:
					var cls: String = plan.side_class(b, k)
					if cls == "closed":
						continue
					var a := c[k]
					var e := c[(k + 1) % 4]
					var dir := (e - a).normalized()
					var inward: Vector2 = Vector2(-dir.y, dir.x) * (plan.CLASSES[cls].width * 0.5 + 1.0)
					_poly(img, origin, PackedVector2Array([a, e, e + inward, a + inward]), ROAD)
				continue
			var style: String = city.block_style(b)
			var color: Color = STYLE_COLORS.get(city.district_at(city.block_center(b)).get("style", "quarter"), STYLE_COLORS.quarter)
			color = LANDMARK_COLORS.get(style, color)
			var road := ROAD
			var walk := SIDEWALK
			if not inside:
				color = color.lerp(OUTSIDE, 0.55)
				road = ROAD.lerp(OUTSIDE, 0.4)
				walk = SIDEWALK.lerp(OUTSIDE, 0.5)
			_poly(img, origin, plan.corners(b), road)
			_poly(img, origin, plan.inner(b), walk)
			_poly(img, origin, plan.lot(b), color)
	# Neutral grounds on the boulevards, pavers on pedestrian lanes.
	for i in range(-margin, city.blocks.x + margin + 1):
		for j in range(-margin, city.blocks.y + margin + 1):
			var n := Vector2i(i, j)
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var cls: String = plan.edge_class(n, d)
				if cls != "boulevard" and cls != "lane":
					continue
				var a: Vector2 = plan.pos(n)
				var e: Vector2 = plan.pos(n + d)
				var dir := (e - a).normalized()
				var side := Vector2(-dir.y, dir.x)
				var half := 3.0 if cls == "boulevard" else 3.5
				var trim := dir * 7.0
				_poly(img, origin, PackedVector2Array([a + trim - side * half, e - trim - side * half, e - trim + side * half, a + trim + side * half]), MEDIAN if cls == "boulevard" else LANE)
	for line in city.rail_lines:
		var from: Vector2i = line[0]
		var to: Vector2i = line[1]
		var step := (to - from).clamp(Vector2i(-1, -1), Vector2i(1, 1))
		var n := from
		while n != to:
			if not (city.node_ok(n) and city.node_ok(n + step)):
				n += step
				continue
			var a: Vector2 = plan.pos(n)
			var e: Vector2 = plan.pos(n + step)
			var dir := (e - a).normalized()
			var side := Vector2(-dir.y, dir.x) * 1.0
			_poly(img, origin, PackedVector2Array([a - side, e - side, e + side, a + side]), RAIL if not line[2] else RAIL.darkened(0.3))
			n += step
	var tex := ImageTexture.create_from_image(img)
	return {"texture": tex, "origin": origin, "size": Vector2(size)}


## Fills a convex polygon (local metres) row by row.
static func _poly(img: Image, origin: Vector2, poly: PackedVector2Array, color: Color) -> void:
	var pts := PackedVector2Array()
	var y0 := INF
	var y1 := -INF
	for p in poly:
		var q := (p - origin) / PX_M
		pts.append(q)
		y0 = minf(y0, q.y)
		y1 = maxf(y1, q.y)
	var n := pts.size()
	var h := img.get_height()
	var w := img.get_width()
	for y in range(maxi(0, floori(y0)), mini(h, ceili(y1))):
		var yc := y + 0.5
		var xa := INF
		var xb := -INF
		for k in n:
			var a := pts[k]
			var b := pts[(k + 1) % n]
			if (a.y <= yc and b.y > yc) or (b.y <= yc and a.y > yc):
				var x := a.x + (yc - a.y) / (b.y - a.y) * (b.x - a.x)
				xa = minf(xa, x)
				xb = maxf(xb, x)
		if xa < xb:
			var x0 := clampi(roundi(xa), 0, w)
			var x1 := clampi(roundi(xb), 0, w)
			if x1 > x0:
				img.fill_rect(Rect2i(x0, y, x1 - x0, 1), color)
