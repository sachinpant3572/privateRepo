extends RefCounted
## The holo-military UI kit: palette, fonts, angled panels, buttons and the
## shared Theme. Panels have two cut corners (top-left and bottom-right),
## a thin holo edge and a soft glow. One accent per meaning: cyan for
## information, amber for the main action and rewards, red for danger.

const BG := Color(0.035, 0.05, 0.07)
const PANEL := Color(0.06, 0.085, 0.115, 0.94)
const PANEL_HI := Color(0.1, 0.14, 0.19, 0.96)
const LINE := Color(0.24, 0.36, 0.46)
const CYAN := Color(0.24, 0.91, 1.0)
const AMBER := Color(1.0, 0.71, 0.23)
const RED := Color(1.0, 0.3, 0.24)
const GREEN := Color(0.27, 1.0, 0.55)
const VIOLET := Color(0.72, 0.5, 1.0)
const TEXT := Color(0.87, 0.93, 0.97)
const DIM := Color(0.5, 0.6, 0.68)
const CUT := 18  # Size of a cut corner, in pixels.

static var _fonts := {}


static func font(kind: String) -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var path: String = {"title": "res://fonts/teko-600.woff2", "body": "res://fonts/rajdhani-600.woff2", "bold": "res://fonts/rajdhani-700.woff2"}[kind]
	var f: Font = ThemeDB.fallback_font
	if ResourceLoader.exists(path):
		var file: FontFile = load(path)
		# The web fonts carry Latin only; symbols (★ → ● ·) come from the
		# engine's default font.
		var fallbacks: Array[Font] = [ThemeDB.fallback_font]
		file.fallbacks = fallbacks
		f = file
	_fonts[kind] = f
	return f


## A panel with two cut corners, a holo edge and an optional glow.
static func panel(fill: Color = PANEL, edge: Color = LINE, border: int = 2, glow: float = 0.0, cut: int = CUT) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = edge
	sb.set_border_width_all(border)
	sb.corner_detail = 1  # One segment per corner: a straight 45-degree cut.
	sb.corner_radius_top_left = cut
	sb.corner_radius_bottom_right = cut
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.anti_aliasing = true
	if glow > 0.0:
		sb.shadow_color = Color(edge.r, edge.g, edge.b, 0.35 * glow)
		sb.shadow_size = int(10.0 * glow)
	sb.set_content_margin_all(16)
	return sb


static func button_styles(kind: String) -> Dictionary:
	var fill := PANEL
	var edge := CYAN
	match kind:
		"primary":
			fill = AMBER
			edge = Color(1.0, 0.86, 0.55)
		"danger":
			fill = Color(0.3, 0.06, 0.05, 0.95)
			edge = RED
		"ghost":
			fill = Color(0.04, 0.06, 0.08, 0.7)
			edge = LINE
	var normal := panel(fill, edge, 2, 0.6 if kind == "primary" else 0.0)
	var pressed := panel(fill.lightened(0.2), edge.lightened(0.3), 3, 1.0)
	var disabled := panel(Color(0.08, 0.09, 0.1, 0.8), Color(0.2, 0.24, 0.27), 2)
	for sb in [normal, pressed, disabled]:
		sb.content_margin_left = 22
		sb.content_margin_right = 22
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
	return {"normal": normal, "hover": normal, "focus": normal, "pressed": pressed, "disabled": disabled}


static func style_button(b: Button, kind: String) -> void:
	var styles := button_styles(kind)
	for k in styles:
		b.add_theme_stylebox_override(k, styles[k])
	var text_col := Color(0.08, 0.06, 0.02) if kind == "primary" else TEXT
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, text_col)
	b.add_theme_color_override("font_disabled_color", DIM)
	b.add_theme_font_override("font", font("title"))
	b.add_theme_font_size_override("font_size", 40 if kind == "primary" else 32)
	b.add_theme_constant_override("outline_size", 0)


## The shared theme: every Label, Button and bar in the HUD starts from it.
static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = font("body")
	t.default_font_size = 26
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0.0, 0.0, 0.0, 0.85))
	var styles := button_styles("secondary")
	for k in styles:
		t.set_stylebox(k, "Button", styles[k])
	t.set_font("font", "Button", font("title"))
	t.set_font_size("font_size", "Button", 32)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", DIM)
	t.set_stylebox("panel", "PanelContainer", panel())
	return t


## A label with the title font and a dark outline.
static func title(text: String, size: int, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font("title"))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Thin "// SECTION" header line used above panels.
static func tag(text: String, color: Color = CYAN) -> Label:
	var l := Label.new()
	l.text = "//  " + text
	l.add_theme_font_override("font", font("bold"))
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
