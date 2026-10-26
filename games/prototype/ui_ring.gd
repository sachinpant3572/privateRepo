extends Control
## The Meteor Slam and Blitz Dash buttons: a round plate whose rim fills as
## the charge builds, then blazes and pulses when it is ready.

const UI := preload("res://ui_style.gd")

var charge := 0.0
var ready_glow := 0.0  # 0..1, follows readiness smoothly.
var label := "SLAM"
var cold := UI.AMBER  # Rim colour while charging
var hot := Color(1.0, 0.42, 0.12)  # and when ready.
var arcs := false  # Electric crackle around the rim when ready (the dash).
var t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	t += delta
	ready_glow = move_toward(ready_glow, 1.0 if charge >= 1.0 else 0.0, delta * 4.0)
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 6.0
	var rim := cold.lerp(hot, ready_glow)
	var pulse := 0.5 + 0.5 * sin(t * 7.0)
	if ready_glow > 0.0:
		for k in 4:
			draw_circle(c, r + 4.0 + k * 5.0 + pulse * 4.0, Color(rim.r, rim.g, rim.b, 0.09 * ready_glow * (4 - k)))
		if arcs:
			_crackle(c, r, rim)
	draw_circle(c, r, Color(0.04, 0.06, 0.08, 0.82))
	draw_arc(c, r - 3.0, 0.0, TAU, 64, Color(UI.LINE.r, UI.LINE.g, UI.LINE.b, 0.8), 3.0, true)
	if charge > 0.0:
		var a0 := -PI * 0.5
		draw_arc(c, r - 3.0, a0, a0 + TAU * clampf(charge, 0.0, 1.0), 64, rim, 9.0, true)
	var inner := Color(rim.r, rim.g, rim.b, 0.18 + 0.25 * ready_glow * pulse)
	draw_circle(c, r * 0.62, inner)
	var f := UI.font("title")
	var fs := int(r * 0.62)
	var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2(c.x - tw * 0.5, c.y + fs * 0.36)
	var txt := Color.WHITE if charge >= 1.0 else Color(0.75, 0.8, 0.85, 0.8)
	draw_string_outline(f, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, 0.9))
	draw_string(f, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, txt)


## Two flickering lightning arcs running round the rim, re-drawn every
## twentieth of a second.
func _crackle(c: Vector2, r: float, col: Color) -> void:
	var seed_t := int(t * 20.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_t
	for k in 2:
		var a := rng.randf() * TAU
		var pts := PackedVector2Array()
		for s in 7:
			var ang := a + s * 0.16
			pts.append(c + Vector2.from_angle(ang) * (r + rng.randf_range(-6.0, 10.0)))
		draw_polyline(pts, Color(col.r, col.g, col.b, 0.8 * ready_glow), 3.0)
		draw_polyline(pts, Color(1, 1, 1, 0.9 * ready_glow), 1.2)
