extends Control
## The Meteor Slam button: a round plate whose rim fills as the charge
## builds, then blazes and pulses when the slam is ready.

const UI := preload("res://ui_style.gd")

var charge := 0.0
var ready_glow := 0.0  # 0..1, follows readiness smoothly.
var label := "SLAM"
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
	var hot := UI.AMBER.lerp(Color(1.0, 0.42, 0.12), ready_glow)
	var pulse := 0.5 + 0.5 * sin(t * 7.0)
	if ready_glow > 0.0:
		for k in 4:
			draw_circle(c, r + 4.0 + k * 5.0 + pulse * 4.0, Color(hot.r, hot.g, hot.b, 0.09 * ready_glow * (4 - k)))
	draw_circle(c, r, Color(0.04, 0.06, 0.08, 0.82))
	draw_arc(c, r - 3.0, 0.0, TAU, 64, Color(UI.LINE.r, UI.LINE.g, UI.LINE.b, 0.8), 3.0, true)
	if charge > 0.0:
		var a0 := -PI * 0.5
		draw_arc(c, r - 3.0, a0, a0 + TAU * clampf(charge, 0.0, 1.0), 64, hot, 9.0, true)
	var inner := Color(hot.r, hot.g, hot.b, 0.18 + 0.25 * ready_glow * pulse)
	draw_circle(c, r * 0.62, inner)
	var f := UI.font("title")
	var fs := int(r * 0.62)
	var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2(c.x - tw * 0.5, c.y + fs * 0.36)
	var txt := Color.WHITE if charge >= 1.0 else Color(0.75, 0.8, 0.85, 0.8)
	draw_string_outline(f, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, 0.9))
	draw_string(f, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, txt)
