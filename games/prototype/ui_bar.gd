extends Control
## A segmented, slanted HUD bar. When the value drops, a white "damage trail"
## shows what was lost and drains after a moment; when it rises, the bar
## flashes. Optional text sits inside the bar.

const UI := preload("res://ui_style.gd")

var value := 1.0
var shown := 1.0  # Lags behind value going down: the damage trail.
var color := UI.GREEN
var segments := 10
var slant := 10.0
var text := ""
var flash := 0.0
var hold := 0.0
var text_size := 20


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_value(v: float) -> void:
	v = clampf(v, 0.0, 1.0)
	if v > value + 0.001:
		flash = 0.25
		shown = maxf(shown, v)
	elif v < value - 0.001:
		hold = 0.45
	value = v
	queue_redraw()


func _process(delta: float) -> void:
	var busy := false
	if hold > 0.0:
		hold -= delta
		busy = true
	elif shown > value:
		shown = maxf(value, shown - delta * 0.8)
		busy = true
	else:
		shown = value
	if flash > 0.0:
		flash -= delta
		busy = true
	if busy:
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	_slab(1.0, Color(0.0, 0.0, 0.0, 0.6), h)
	_slab(shown, Color(1.0, 1.0, 1.0, 0.75), h)
	_slab(value, color.lerp(Color.WHITE, clampf(flash * 3.0, 0.0, 0.6)), h)
	# Glassy highlight on the upper part of the fill.
	_slab(value, Color(1.0, 1.0, 1.0, 0.16), h * 0.4)
	var run := w - slant
	if segments > 1:
		for k in range(1, segments):
			var f := k / float(segments)
			draw_line(Vector2(slant + f * run, 0.0), Vector2(f * run, h), Color(0.0, 0.0, 0.0, 0.55), 2.0)
	var edge := PackedVector2Array([Vector2(slant, 0), Vector2(w, 0), Vector2(w - slant, h), Vector2(0, h), Vector2(slant, 0)])
	draw_polyline(edge, Color(color.r, color.g, color.b, 0.7), 1.5, true)
	if text != "":
		var fnt := UI.font("bold")
		var tw := fnt.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
		var pos := Vector2((w - tw) * 0.5, h * 0.5 + text_size * 0.35)
		draw_string_outline(fnt, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, 4, Color(0, 0, 0, 0.9))
		draw_string(fnt, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, Color.WHITE)


## The bar's slanted shape filled to fraction v, covering the top `depth`
## pixels (the full height for the fill, less for the highlight).
func _slab(v: float, col: Color, depth: float) -> void:
	if v <= 0.002:
		return
	var h := size.y
	var run := (size.x - slant) * v
	var inset := slant * (1.0 - depth / h)
	var pts := PackedVector2Array([
		Vector2(slant, 0.0),
		Vector2(slant + run, 0.0),
		Vector2(inset + run, depth),
		Vector2(inset, depth),
	])
	draw_colored_polygon(pts, col)
