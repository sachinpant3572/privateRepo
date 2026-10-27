extends RefCounted
## Bakes the demo map into one texture for the minimap and the full map:
## water, district-tinted blocks inside their sidewalks, roads, streetcar
## lines and landmark lots. Built once at start (a few hundred fill_rects).
## Pixel (0, 0) is local (-MARGIN * PITCH, -MARGIN * PITCH); one pixel per
## PX_M metres.

const PX_M := 1.0
const WATER := Color(0.27, 0.5, 0.62)
const ROAD := Color(0.36, 0.37, 0.4)
const SIDEWALK := Color(0.78, 0.76, 0.72)
const RAIL := Color(0.55, 0.32, 0.2)
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
	var margin: int = city.MARGIN
	var pitch: float = city.PITCH
	var lo := -margin * pitch
	var span := Vector2((city.blocks.x + 2 * margin) * pitch, (city.blocks.y + 2 * margin) * pitch)
	var size := Vector2i(ceili(span.x / PX_M), ceili(span.y / PX_M))
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(WATER)
	var origin := Vector2(lo, lo)
	var half_road: float = city.ROAD * 0.5
	var block: float = city.BLOCK
	for i in range(-margin, city.blocks.x + margin):
		for j in range(-margin, city.blocks.y + margin):
			var b := Vector2i(i, j)
			if not city.block_land(b):
				continue
			var c: Vector3 = city.block_center(b)
			var inside: bool = city.in_window(b)
			var style: String = city.block_style(b)
			var color: Color = STYLE_COLORS.get(city.district_at(c).get("style", "quarter"), STYLE_COLORS.quarter)
			color = LANDMARK_COLORS.get(style, color)
			if not inside:
				color = color.lerp(OUTSIDE, 0.55)
			# Sidewalk, then the lot inside it.
			_rect(img, origin, Vector2(c.x, c.z), Vector2(block, block), SIDEWALK if inside else SIDEWALK.lerp(OUTSIDE, 0.5))
			_rect(img, origin, Vector2(c.x, c.z), Vector2(block - 6.0, block - 6.0), color)
	# Roads: every land node and the segments between land nodes.
	for i in range(-margin, city.blocks.x + margin + 1):
		for j in range(-margin, city.blocks.y + margin + 1):
			var n := Vector2i(i, j)
			if not city.node_ok(n):
				continue
			var p: Vector3 = city.node_pos(n)
			_rect(img, origin, Vector2(p.x, p.z), Vector2(city.ROAD, city.ROAD), ROAD)
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				if city.node_ok(n + d):
					var q: Vector3 = city.node_pos(n + d)
					var mid := (p + q) * 0.5
					var s := Vector2(absf(q.x - p.x) + city.ROAD, absf(q.z - p.z) + city.ROAD)
					_rect(img, origin, Vector2(mid.x, mid.z), s, ROAD)
	for line in city.rail_lines:
		var a: Vector3 = city.node_pos(line[0])
		var e: Vector3 = city.node_pos(line[1])
		var mid := (a + e) * 0.5
		_rect(img, origin, Vector2(mid.x, mid.z), Vector2(absf(e.x - a.x) + 2.0, absf(e.z - a.z) + 2.0), RAIL if not line[2] else RAIL.darkened(0.3))
	var tex := ImageTexture.create_from_image(img)
	return {"texture": tex, "origin": origin, "size": Vector2(size)}


static func _rect(img: Image, origin: Vector2, center: Vector2, size: Vector2, color: Color) -> void:
	var a := ((center - size * 0.5) - origin) / PX_M
	var r := Rect2i(Vector2i(a.round()), Vector2i((size / PX_M).round()))
	r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if r.size.x > 0 and r.size.y > 0:
		img.fill_rect(r, color)
